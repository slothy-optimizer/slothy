#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author: Hanno Becker <hannobecker@posteo.de>
#

#
# Experimental and incomplete model capturing an approximation of the
# frontend limitations and latencies of the Cortex-A72 CPU.
#
# It might be surprising at first that an in-order optimizer such as Slothy could be
# used for an out of order core such as Cortex-A72.
#
# The key observation is that unless the frontend is much wider than the backend,
# a high overall throughput requires a high throughput in the frontend. Since the
# frontend is in-order and has documented dispatch constraints, we can model those
# constraints in SLOTHY.
#
# The consideration of latencies is less important, yet not irrelevant in this view:
# Instructions dispatched well before they are ready to execute will occupy the issue
# queue (IQ) for a long time, and once the IQs are full, the frontend will stall.
# It is therefore advisable to generally seek to obey latencies to reduce presssure
# on issue queues.
#
# This file thus tries to model basic aspects of the frontend of Cortex-A72
# alongside instruction latencies, both taken from the Cortex-A72 Software Optimization Guide.
#
# NOTE/WARNING
# We focus on a very small subset of AArch64, just enough to experiment with the
# optimization of the Kyber NTT.
#

import logging
import re
import inspect

from enum import Enum, auto
from .aarch64_neon import *

# From the A72 SWOG, Section "4.1 Dispatch Constraints"
# "The dispatch stage can process up to three µops per cycle"
# The name `issue_rate` is a slight misnomer here because we're
# modelling the frontend, not the backend, but `issue_width` is
# what SLOTHY expects.
issue_rate = 3

class ExecutionUnit(Enum):
    LOAD0=auto(),
    LOAD1=auto(),
    STORE0=auto(),
    STORE1=auto(),
    INT0=auto(),
    INT1=auto(),
    MINT0=auto(),
    MINT1=auto(),
    ASIMD0=auto(),
    ASIMD1=auto(),
    def __repr__(self):
        return self.name
    def ASIMD():
        return [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1]
    def LOAD():
        return [ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]
    def STORE():
        return [ExecutionUnit.STORE0, ExecutionUnit.STORE1]
    def INT():
        return [ExecutionUnit.INT0, ExecutionUnit.INT1]
    def MINT():
        return [ExecutionUnit.MINT0, ExecutionUnit.MINT1]
    def SCALAR():
        return ExecutionUnit.INT() + ExecutionUnit.MINT()

    def indentation(unit):
        return 0

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    # _add_slot_constraints(slothy)
    # _add_st_hazard(slothy)
    return

def _add_slot_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    slothy.restrict_slots_for_instructions_by_property(
        Instruction.is_Qform_vector_instruction, [0,1])

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False
def get_min_max_objective(slothy):
    return


def _gen_check_instr_dt(instr_class, dt):
    def _check_instr_dt(src):
        if _find_class(src) is instr_class:
            if dt in src.datatype:
                return True
        return False
    return _check_instr_dt


execution_units = {
    (vmul, vmul_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqrdmulh, vqrdmulh_lane,
     vqdmulh_lane)
    : [ExecutionUnit.ASIMD0],

    (vadd, vsub,
     trn1, trn2 )
    : [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],

    vins : [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    vext : ExecutionUnit.LOAD(),

    ( ldr_vo_wrapper, ldr_vi_wrapper, x_ldr )
    : ExecutionUnit.LOAD(),

    ( str_vi_wrapper, str_vo_wrapper, x_str )
    : ExecutionUnit.STORE(),

    (add, add_shifted) : ExecutionUnit.SCALAR(),

    vsrshr : [ExecutionUnit.ASIMD1],

    st4 : [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],

    ld4 : [[ExecutionUnit.ASIMD0, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1], [ExecutionUnit.ASIMD1, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]]
}

inverse_throughput = {
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqdmulh_lane)
    : 2,

    (vadd, vsub,
     trn1, trn2)
    : 1,

    vins : 1,
    vext : 1,

    (add, add_shifted) : 1,

    ( ldr_vo_wrapper, ldr_vi_wrapper,
      str_vi_wrapper, str_vo_wrapper,
      stack_vld1r, stack_vld2_lane, x_ldr, x_str )
      : 1,

    vsrshr : 1,

    st4 : 8,
    ld4 : 4
}

### REVISIT
default_latencies = {
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmls, vmls_lane,
     vmla, vmla_lane,
     vqdmulh_lane)
    : 5,

    (vadd, vsub,
     trn1, trn2 )
    : 3, # Approximation -- not necessary to get it exactly right, as mentioned above

    ( ldr_vo_wrapper, ldr_vi_wrapper,
      str_vi_wrapper, str_vo_wrapper,
      stack_vld1r, stack_vld2_lane, x_ldr, x_str )
      : 4, # approx

    vins : 6, # approx
    vext : 4, # approx

    (add, add_shifted) : 2,

    vsrshr : 3, # approx
    st4 : 8,
    ld4 : 4
}

def _find_class(src):
    cls_list  = [ c for c in Instruction.__subclasses__() if not c == AArch64Instruction ]
    cls_list += AArch64Instruction.__subclasses__()
    for inst_class in cls_list:
        if isinstance(src,inst_class):
            return inst_class
    raise Exception(f"Couldn't find instruction class for {src} (type {type(src)})")

def _lookup_multidict(d, inst, default=None):
    instclass = _find_class(inst)
    for l,v in d.items():
        # Multidict entries can be the following:
        # - An instruction class. It matches any instruction of that class.
        # - A callable. It matches any instruction returning `True` when passed
        #   to the callable.
        # - A tuple of instruction classes or callables. It matches any instruction
        #   which matches at least one element in the tuple.
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            assert callable(x)
            return x(inst)
        if not isinstance(l, tuple):
            l = [l]
        for lp in l:
            if match(lp):
                return v
    if default == None:
        raise Exception(f"Couldn't find instruction {inst} (class {instclass})")
    return default


def _check_instr_dt(src, instr_classes, dt=None):
    if not isinstance(instr_classes, list):
        instr_classes = list(instr_classes)
    for instr_class in instr_classes:
        if _find_class(src) == instr_class:
            if dt is None or len(set(dt + src.datatype)) > 0:
                return True
    return False


def get_latency(src, out_idx, dst):
    instclass_src = _find_class(src)
    instclass_dst = _find_class(dst)

    latency = _lookup_multidict(
        default_latencies, src)

    # Fast mul->mla forwarding
    if instclass_src in [vmul, vmul_lane] and \
       instclass_dst in [vmla, vmla_lane, vmls, vmls_lane] and \
       src.args_out[0] == dst.args_in_out[0]:
        return 1
    # Fast mla->mla forwarding
    if instclass_src in [vmla, vmla_lane, vmls, vmls_lane] and \
       instclass_dst in [vmla, vmla_lane, vmls, vmls_lane] and \
       src.args_in_out[0] == dst.args_in_out[0]:
        return 1

    return latency

def get_units(src):
    units = _lookup_multidict(execution_units, src)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    return _lookup_multidict(
        inverse_throughput, src)

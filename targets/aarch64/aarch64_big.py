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
# Experimental model capturing the frontend limitations and latencies of
# BIG A-profile cores such as Cortex-X1.
#
# It might be surprising at first that an in-order optimizer such as Slothy could be
# of any use for a highly out of order core such as the Arm Cortex-X1 CPU.
#
# The reason why instruction scheduling still matters here is that, as far as Neon instructions go,
# frontend and backend have the same maximum throughput of 4 instructions per cycle. Thus, to achieve
# this optimal rate at the backend, the frontend needs to constantly achieve 4 IPC as well -- but, the
# frontend being in-order, this becomes a scheduling sensitive problem.
#
# This file thus tries to model basic aspects of the frontend of Cortex-X1 alongside instruction latencies,
# both taken from the Cortex-X1 Software Optimization Guide.
#

import logging
import re

from enum import Enum, auto
from .aarch64_neon import *

# As mentioned above, we're not actually modelling the backend here, but the frontend,
# so it should rather be called dispatch rate.
issue_rate = 6

class ExecutionUnit(Enum):
    LOAD0=auto()
    LOAD1=auto()
    LOAD2=auto()
    STORE0=auto()
    STORE1=auto()
    VALU0=auto()
    VALU1=auto()
    VALU2=auto()
    VALU3=auto()
    ALUS0=auto()
    ALUS1=auto()
    ALUSM0=auto()
    ALUSM1=auto()
    def __repr__(self):
        return self.name

    def V0123():
        return [ExecutionUnit.VALU0,
                ExecutionUnit.VALU1,
                ExecutionUnit.VALU2,
                ExecutionUnit.VALU3]
    def V02():
        return [ExecutionUnit.VALU0,
                ExecutionUnit.VALU2]
    def V01():
        return [ExecutionUnit.VALU0,
                ExecutionUnit.VALU1]
    def V13():
        return [ExecutionUnit.VALU1,
                ExecutionUnit.VALU3]
    def L01():
        return [ExecutionUnit.LOAD0,
                ExecutionUnit.LOAD1]
    def L012():
        return [ExecutionUnit.LOAD0,
                ExecutionUnit.LOAD1,
                ExecutionUnit.LOAD2]
    def I():
        return [
            ExecutionUnit.ALUS0,
            ExecutionUnit.ALUS1,
            ExecutionUnit.ALUSM0,
            ExecutionUnit.ALUSM1,
        ]
    def S01():
        return [ExecutionUnit.STORE0,
                ExecutionUnit.STORE1]

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    # Try to shave off complexity by only allowing early _loads_
    # slothy.restrict_early_late_instructions(lambda i: _find_class(i) == vldr)
    _forbid_back_to_back_mul(slothy)
    _restrict_mul_slots(slothy)
    return

def _restrict_mul_slots(slothy):
    if slothy.config.constraints.functional_only:
        return
    for t in slothy._model._tree.nodes:
        if t.inst.is_vector_mul():
            slothy.restrict_slots_for_instruction(t,[0,2])
        if t.inst.is_vector_add_sub():
            slothy.restrict_slots_for_instruction(t,[0,1,2,3])
        if t.inst.is_vector_load():
            slothy.restrict_slots_for_instruction(t,[5,6,7])
        if t.inst.is_vector_store():
            slothy.restrict_slots_for_instruction(t,[0,1])

def _forbid_back_to_back_mul(slothy):
    if slothy.config.constraints.functional_only:
        return

    def is_mul_pair(instA, instB):
        if not instA.inst.is_vector_mul() or not instB.inst.is_vector_mul():
            return False
        return True
    for mul0, mul1 in slothy.get_inst_pairs(is_mul_pair):
        slothy._Add( mul0.program_start_var != mul1.program_start_var + 1 )

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False
def get_min_max_objective(slothy):
    return

execution_units = {
    ( vadd, vsub, trn1, trn2 ) : ExecutionUnit.V0123(),
    ( vmls, vmls_lane,
      vmul, vmul_lane,
      vqrdmulh, vqrdmulh_lane,
      vmul, vmul_lane,
      vmla, vmla_lane,
      vqrdmulh, vqrdmulh_lane,
      vqdmulh_lane ) : ExecutionUnit.V02(),
    ( vsrshr ) : ExecutionUnit.V13(),
    (vext) : ExecutionUnit.V01(),
    (vins) : [[ExecutionUnit.ALUSM0], ExecutionUnit.V0123()],
    ( vldr ) : ExecutionUnit.L012(),
    ( vstr ) : [ExecutionUnit.V01(), ExecutionUnit.S01()],
    (x_str) : [ExecutionUnit.L01(), ExecutionUnit.S01()],
    (str_vi_wrapper, str_vo_wrapper, st4) : [ExecutionUnit.L01(), ExecutionUnit.V0123()],
    (ld4) : [ExecutionUnit.L01(), ExecutionUnit.V0123()],
    (ldr_vi_wrapper, ldr_vo_wrapper, x_ldr) : [ExecutionUnit.L012(), ExecutionUnit.I()],
    (mov_imm, add, add_shifted, sub, subs) : ExecutionUnit.I(),
    (restore, qrestore) : [ExecutionUnit.L01(), ExecutionUnit.V0123(), ExecutionUnit.I()]
}

inverse_throughput = {
    ( vstr, mov_imm,
      trn1, trn2,
      str_vi_wrapper, str_vo_wrapper, ldr_vi_wrapper, ldr_vo_wrapper,
      vadd, vsub, st4, x_ldr, x_str) : 1,
    (add, add_shifted, sub) : 1,
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqdmulh_lane,
     vsrshr) : 1,
    (vext): 1,
    (vins) : 1,
    vldr : 1,
    (ld4) : 2,  # TODO: double check
    (qrestore) : 2,
    (restore) : 3
}

default_latencies = {
    # The true latencies are higher -- see below -- but we don't have to be
    # strict about them as we're optimizing for an OOO core. Still, we don't
    # want to completely disregard them, as otherwise we might risk overflowing
    # issue queues.
    ( vldr, ldr_vi_wrapper, ldr_vo_wrapper ) : 6//2,
    (x_ldr) : 4//2,
    (x_str) : 1,
    ( st4 ) : 5//2,
    ( ld4 ) : 9//2,
    ( vadd, vsub, vstr, str_vi_wrapper, str_vo_wrapper, trn1, trn2 ) : 2//2,
    ( vmul, vmul_lane,
      vmla, vmla_lane,
      vmls, vmls_lane,
      vqrdmulh, vqrdmulh_lane,
      vqdmulh_lane, vsrshr ) : 4//2,
    (add, add_shifted, sub, subs, mov_imm) : 1,
    (vext) : 2//2,
    (vins) : 5//2,
    (qrestore) : 9//2,
    (restore) : 13//2

    # True latencies
    # ( vldr, ldr_vi_wrapper, ldr_vo_wrapper ) : 6,
    # ( st4 ) : 5,
    # ( add, sub, vadd_wrapper, vsub_wrapper, vstr, str_vi_wrapper, str_vo_wrapper, trn1_d_wrapper, trn2_d_wrapper, trn1_s_wrapper, trn2_s_wrapper ) : 2,
    # ( mul, mla, sqrdmulh, vmul_wrapper, vmul_lane_wrapper, vmla_wrapper, vqrdmulh_wrapper, vqrdmulh_lane_wrapper, vqdmulh_lane_wrapper, vsrshr ) : 4,
    # (sub_wrapper, subs_wrapper, mov_imm_wrapper) : 1,
    # (qrestore) : 9,
    # (restore) : 13
}

def _find_class(src):
    cls_list  = [ c for c in Instruction.__subclasses__() if not c == AArch64Instruction ]
    cls_list += AArch64Instruction.__subclasses__()
    for inst_class in cls_list:
        if isinstance(src,inst_class):
            return inst_class
    raise Exception(f"Couldn't find instruction class for {src} (type {type(src)})")

def _lookup_multidict(d, k, default=None):
    for l,v in d.items():
        if k == l:
            return v
        if isinstance(l,tuple) and k in l:
            return v
    if default == None:
        raise Exception(f"Couldn't find {k}")
    return default

def get_latency(src, out_idx, dst):
    instclass_src = _find_class(src)
    instclass_dst = _find_class(dst)

    default_latency = _lookup_multidict(
        default_latencies, instclass_src)

    # Fast mul->mla forwarding
    # TODO: Need to take the input index into account here
    if instclass_src in [vmul, vmul_lane] and \
       instclass_dst in [vmla, vmla_lane]:
        return 1

    return default_latency

def get_units(src):
    instclass = _find_class(src)
    units = _lookup_multidict(execution_units, instclass)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    instclass = _find_class(src)
    return _lookup_multidict(
        inverse_throughput, instclass)

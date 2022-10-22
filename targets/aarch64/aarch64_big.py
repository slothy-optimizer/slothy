#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
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
issue_rate = 8

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
    def L012():
        return [ExecutionUnit.LOAD0,
                ExecutionUnit.LOAD1,
                ExecutionUnit.LOAD2]

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    # Try to shave off complexity by only allowing early _loads_
    # slothy.restrict_early_late_instructions(lambda i: _find_class(i) == vldr)
    # _forbid_back_to_back_mul(slothy)
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

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False
def get_min_max_objective(slothy):
    return

execution_units = {
    ( add, sub ) : ExecutionUnit.V0123(),
    ( mul, mla, sqrdmulh ) : ExecutionUnit.V02(),
    ( vldr ) : ExecutionUnit.L012(),
    ( vstr ) : ExecutionUnit.V01(), # TODO: Also occupy STORE
}

inverse_throughput = {
    ( add, sub, mul, mla, sqrdmulh, vstr ) : 1,
    vldr : 1,
}

default_latencies = {
    # The true latencies are higher -- see below -- but we don't have to be
    # strict about them as we're optimizing for an OOO core. Still, we don't
    # want to completely disregard them, as otherwise we might risk overflowing
    # issue queues.
    ( vldr) : 3,
    ( add, sub ) : 2,
    ( mul, mla, sqrdmulh ) : 2,

    # True latencies
    # ( vldr) : 6,
    # ( add, sub ) : 2,
    # ( mul, mla, sqrdmulh ) : 4,
}

def _find_class(src):
    for inst_class in Instruction.__subclasses__():
        if isinstance(src,inst_class):
            return inst_class
    raise Exception("Couldn't find instruction class")

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
    if instclass_src == mul and instclass_dst == mla:
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

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
# Experimental and highly incomplete model capturing an approximation of the
# frontend limitations and latencies of the Neoverse N1 CPU
#

from enum import Enum
from .aarch64_neon import *

issue_rate = 4

class ExecutionUnit(Enum):
    SCALAR_I0=0,
    SCALAR_I1=1,
    SCALAR_I2=2,
    SCALAR_M=2, # Overlaps with third I pipeline
    LSU0=3,
    LSU1=4,
    VEC0=5,
    VEC1=6,
    def __repr__(self):
        return self.name
    def I():
        return [ExecutionUnit.SCALAR_I0, ExecutionUnit.SCALAR_I1, ExecutionUnit.SCALAR_I2]
    def M():
        return [ExecutionUnit.SCALAR_M]
    def V():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1]
    def V0():
        return [ExecutionUnit.VEC0]
    def V1():
        return [ExecutionUnit.VEC1]
    def LSU():
        return [ExecutionUnit.LSU0, ExecutionUnit.LSU1]

# Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    slothy.restrict_slots_for_instructions_by_property(
        is_neon_instruction, [0,1])
    slothy.restrict_slots_for_instructions_by_property(
        lambda t: is_neon_instruction(t) == False, [1,2,3])

def has_min_max_objective(config):
    return False
def get_min_max_objective(slothy):
    return

execution_units = {
    (Ldp_X, Ldr_X,
     Str_X, Stp_X,
     Ldr_Q)                   : ExecutionUnit.LSU(),
    (vuzp1, vuzp2, vzip1,
     rev64, uaddlp)           : ExecutionUnit.V(),
    (vmov)                    : ExecutionUnit.V(),
    (vext)                    : ExecutionUnit.V(),
    (vmovi)                   : ExecutionUnit.V(),
    (vand, vadd)              : ExecutionUnit.V(),
    (vxtn)                    : ExecutionUnit.V(),
    (vshl, vshli, vshrn,
     mov_vtox)                : ExecutionUnit.V1(),
    vusra                     : ExecutionUnit.V1(),
    (vmul, vmlal, vmull)      : ExecutionUnit.V0(),
    (AArch64BasicArithmetic,
     AArch64ConditionalSelect,
     AArch64ConditionalCompare,
     AArch64Logical,
     AArch64Move)             : ExecutionUnit.I(),
    AArch64Shift              : ExecutionUnit.I(), # Is that correct? Can't find those in SWOG
    Tst                       : ExecutionUnit.I(),
    AArch64ShiftedArithmetic  : ExecutionUnit.M(),
    (AArch64HighMultiply,
     AArch64Multiply) : ExecutionUnit.M(),
    vdup                     : ExecutionUnit.M(),
}

inverse_throughput = {
    (Ldr_X, Str_X,
     Ldr_Q)                    : 1,
    (Ldp_X, Stp_X)             : 2,
    (vuzp1, vuzp2, vzip1,
     uaddlp, rev64)            : 1,
    (vext)                     : 1,
    (vand, vadd)               : 1,
    (vmov)                     : 1,
    (vmovi)                    : 1,
    (vxtn)                     : 1,
    (vshl, vshli, vshrn,
     mov_vtox)                 : 1,
    (vmul)                     : 2,
    vusra                      : 1,
    (vmlal, vmull)             : 1,
    (AArch64BasicArithmetic,
     AArch64ConditionalSelect,
     AArch64ConditionalCompare,
     AArch64Logical,
     AArch64Move)              : 1,
    AArch64Shift               : 1,
    AArch64ShiftedArithmetic   : 1,
    Tst                        : 1,
    (AArch64HighMultiply)      : 4,
    (AArch64Multiply)          : 3,
    (vdup)                     : 1,
}

default_latencies = {
    (Ldp_X,
     Ldr_X,
     Ldr_Q)                   : 4,
    (Stp_X, Str_X)            : 2,
    (vuzp1, vuzp2, vzip1,
     rev64, uaddlp)           : 2,
    (vext)                    : 2,
    (vxtn)                    : 2,
    (vand, vadd)              : 2,
    (vmov)                    : 2, # ???
    (vmovi)                   : 2,
    (vmul)                    : 5,
    vusra                     : 4, # TODO: Add fwd path
    (vmlal, vmull)            : 4, # TODO: Add fwd path
    (vshl, vshli, vshrn)      : 2,
    (AArch64BasicArithmetic,
     AArch64ConditionalSelect,
     AArch64ConditionalCompare,
     AArch64Logical,
     AArch64Move)             : 1,
    AArch64Shift              : 1,
    AArch64ShiftedArithmetic  : 2,
    Tst                       : 1,
    mov_vtox                  : 2,
    AArch64HighMultiply       : 5,
    AArch64Multiply           : 4,
    (vdup)                    : 3,
}

def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)
    latency = lookup_multidict(default_latencies, src)
    return latency

def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

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
# Experimental model for high-end A-profile cores with 4 SIMD units
#

from enum import Enum
from slothy.targets.aarch64.aarch64_neon import (
    is_neon_instruction,
    lookup_multidict,
    aese_x4,
    aesr_x4,
    Ldp_X,
    Ldr_X,
    Str_X,
    Stp_X,
    Ldr_Q,
    Str_Q,
    Ldp_Q,
    Stp_Q,
    vuzp1,
    vuzp2,
    vzip1,
    Vrev,
    uaddlp,
    vmov,
    vmovi,
    vand,
    vadd,
    vxtn,
    veor3,
    VShiftImmediateBasic,
    vshl_d,
    vshli,
    vshrn,
    vusra,
    vmul,
    vmlal,
    vmull,
    vdup,
    AESInstruction,
    Transpose,
    aesr_x2,
    AArch64NeonLogical,
    AArch64BasicArithmetic,
    AArch64ConditionalSelect,
    AArch64ConditionalCompare,
    AArch64Logical,
    AArch64LogicalShifted,
    AArch64Move,
    AArch64Shift,
    Tst,
    AArch64ShiftedArithmetic,
    Fmov,
    AArch64HighMultiply,
    AArch64Multiply,
    VecToGprMov,
)

issue_rate = 6


class ExecutionUnit(Enum):
    SCALAR_I0 = (0,)
    SCALAR_I1 = (1,)
    SCALAR_I2 = (2,)
    SCALAR_I3 = (3,)
    SCALAR_M0 = (2,)  # Overlaps with third I pipeline
    SCALAR_M1 = (3,)  # Overlaps with fourth I pipeline
    LSU0 = (4,)
    LSU1 = (5,)
    VEC0 = (6,)
    VEC1 = (7,)
    VEC2 = (8,)
    VEC3 = (9,)

    def __repr__(self):
        return self.name

    def I():  # noqa: E743
        return [
            ExecutionUnit.SCALAR_I0,
            ExecutionUnit.SCALAR_I1,
            ExecutionUnit.SCALAR_I2,
            ExecutionUnit.SCALAR_I3,
        ]

    def M():
        return [ExecutionUnit.SCALAR_M0, ExecutionUnit.SCALAR_M1]

    def V():
        return [
            ExecutionUnit.VEC0,
            ExecutionUnit.VEC1,
            ExecutionUnit.VEC2,
            ExecutionUnit.VEC3,
        ]

    def V0():
        return [ExecutionUnit.VEC0]

    def V1():
        return [ExecutionUnit.VEC1]

    def V13():
        return [ExecutionUnit.VEC1, ExecutionUnit.VEC3]

    def V01():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1]

    def V02():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC2]

    def LSU():
        return [ExecutionUnit.LSU0, ExecutionUnit.LSU1]


# Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    slothy.restrict_slots_for_instructions_by_property(
        is_neon_instruction, [0, 1, 2, 3]
    )
    slothy.restrict_slots_for_instructions_by_class([aesr_x4, aesr_x4], [0])


def has_min_max_objective(config):
    return False


def get_min_max_objective(slothy):
    return


# TODO: Copy-pasted from N1 model -- adjust


execution_units = {
    (Ldp_X, Ldr_X, Str_X, Stp_X, Ldr_Q, Str_Q, Ldp_Q, Stp_Q): ExecutionUnit.LSU(),
    (vuzp1, vuzp2, vzip1, Vrev, uaddlp): ExecutionUnit.V(),
    (vmov): ExecutionUnit.V(),
    VecToGprMov: ExecutionUnit.V(),
    (vmovi): ExecutionUnit.V(),
    (vand, vadd): ExecutionUnit.V(),
    (vxtn): ExecutionUnit.V(),
    veor3: ExecutionUnit.V(),
    (
        VShiftImmediateBasic,
        vshl_d,
        vshli,
        vshrn,
    ): ExecutionUnit.V1(),  # TODO: Should be V13?
    vusra: ExecutionUnit.V1(),
    AESInstruction: ExecutionUnit.V(),
    Transpose: ExecutionUnit.V(),
    aesr_x2: ExecutionUnit.V(),
    aesr_x4: [ExecutionUnit.V()],  # Use all V-pipes
    aese_x4: [ExecutionUnit.V()],  # Use all V-pipes
    (vmul, vmlal, vmull): ExecutionUnit.V0(),
    AArch64NeonLogical: ExecutionUnit.V(),
    (
        AArch64BasicArithmetic,
        AArch64ConditionalSelect,
        AArch64ConditionalCompare,
        AArch64Logical,
        AArch64LogicalShifted,
        AArch64Move,
    ): ExecutionUnit.I(),
    AArch64Shift: ExecutionUnit.I(),
    Tst: ExecutionUnit.I(),
    AArch64ShiftedArithmetic: ExecutionUnit.M(),
    Fmov: ExecutionUnit.M(),
    (AArch64HighMultiply, AArch64Multiply): ExecutionUnit.M(),
    vdup: ExecutionUnit.M(),
}

inverse_throughput = {
    (Ldr_X, Str_X, Ldr_Q, Str_Q): 1,
    (Ldp_X, Stp_X, Ldp_Q, Stp_Q): 2,
    (vuzp1, vuzp2, vzip1, uaddlp, Vrev): 1,
    VecToGprMov: 1,
    Transpose: 1,
    veor3: 2,
    (vand, vadd): 1,
    (vmov): 1,
    AESInstruction: 1,
    aesr_x4: 1,
    aese_x4: 1,
    AArch64NeonLogical: 1,
    (vmovi): 1,
    (vxtn): 1,
    (VShiftImmediateBasic, vshl_d, vshli, vshrn): 1,
    (vmul): 2,
    vusra: 1,
    (vmlal, vmull): 1,
    (
        AArch64BasicArithmetic,
        AArch64ConditionalSelect,
        AArch64ConditionalCompare,
        AArch64Logical,
        AArch64LogicalShifted,
        AArch64Move,
    ): 1,
    AArch64Shift: 1,
    AArch64ShiftedArithmetic: 1,
    Tst: 1,
    Fmov: 1,
    (AArch64HighMultiply): 4,
    (AArch64Multiply): 3,
    (vdup): 1,
}

default_latencies = {
    (Ldp_X, Ldr_X, Ldr_Q, Ldp_Q): 4,
    (Stp_X, Str_X, Str_Q, Stp_Q): 2,
    (vuzp1, vuzp2, vzip1, Vrev, uaddlp): 2,
    VecToGprMov: 2,
    veor3: 2,
    (vxtn): 2,
    Transpose: 2,
    AESInstruction: 2,
    (aesr_x4, aese_x4): 2,
    AArch64NeonLogical: 2,
    (vand, vadd): 2,
    (vmov): 2,  # ???
    (vmovi): 2,
    (vmul): 5,
    vusra: 4,  # TODO: Add fwd path
    (vmlal, vmull): 4,  # TODO: Add fwd path
    (VShiftImmediateBasic, vshl_d, vshli, vshrn): 2,
    (
        AArch64BasicArithmetic,
        AArch64ConditionalSelect,
        AArch64ConditionalCompare,
        AArch64Logical,
        AArch64LogicalShifted,
        AArch64Move,
    ): 1,
    AArch64Shift: 1,
    AArch64ShiftedArithmetic: 2,
    Tst: 1,
    Fmov: 3,
    AArch64HighMultiply: 5,
    AArch64Multiply: 4,
    (vdup): 3,
}


def get_latency(src, out_idx, dst):
    latency = lookup_multidict(default_latencies, src)
    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    else:
        return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

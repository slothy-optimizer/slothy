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

"""
Experimental and highly incomplete model capturing an approximation of the
frontend limitations and latencies of the Neoverse N1 CPU
"""

from enum import Enum
from slothy.targets.aarch64.aarch64_neon import (
    is_neon_instruction,
    lookup_multidict,
    find_class,
    all_subclass_leaves,
    Ldp_X,
    Ldr_X,
    Str_X,
    Stp_X,
    Ldr_Q,
    Str_Q,
    Stp_Q,
    Vrev,
    uaddlp,
    vmov,
    vmovi,
    vand,
    vadd,
    vxtn,
    vshl_d,
    vshli,
    vshrn,
    vsshr,
    vusra,
    vmul,
    vdup,
    AESInstruction,
    Transpose,
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
    St3,
    St4,
    Vzip,
    vsub,
    vuxtl,
    vshl,
    vsrshr,
    Vmul,
    Vmla,
    Vqdmulh,
    Vmull,
    Vmlal,
    umull_wform,
    vmul_lane,
    vmla,
    vmla_lane,
    vmls,
    vmls_lane,
)

issue_rate = 4
llvm_mca_target = "neoverse-n1"


class ExecutionUnit(Enum):
    """Enumeration of execution units in approximative Neoverse-N1 SLOTHY model"""

    SCALAR_I0 = 0
    SCALAR_I1 = 1
    SCALAR_I2 = 2
    SCALAR_M = 2  # Overlaps with third I pipeline
    LSU0 = 3
    LSU1 = 4
    VEC0 = 5
    VEC1 = 6

    def __repr__(self):
        return self.name

    @classmethod
    def I(cls):  # noqa: E743
        return [
            ExecutionUnit.SCALAR_I0,
            ExecutionUnit.SCALAR_I1,
            ExecutionUnit.SCALAR_I2,
        ]

    @classmethod
    def M(cls):
        return [ExecutionUnit.SCALAR_M]

    @classmethod
    def V(cls):
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1]

    @classmethod
    def V0(cls):
        return [ExecutionUnit.VEC0]

    @classmethod
    def V1(cls):
        return [ExecutionUnit.VEC1]

    @classmethod
    def LSU(cls):
        return [ExecutionUnit.LSU0, ExecutionUnit.LSU1]


# Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    slothy.restrict_slots_for_instructions_by_property(is_neon_instruction, [0, 1])
    slothy.restrict_slots_for_instructions_by_property(
        lambda t: is_neon_instruction(t) is False, [1, 2, 3]
    )


def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy


execution_units = {
    (Ldp_X, Ldr_X, Str_X, Stp_X, Ldr_Q, Str_Q, Stp_Q): ExecutionUnit.LSU(),
    # TODO: The following would be more accurate, but does not
    #       necessarily lead to better results, while making the
    #       optimization slower. Investigate...
    #
    # Ldr_Q)            : ExecutionUnit.LSU(),
    # Str_Q : [[ExecutionUnit.VEC0, ExecutionUnit.LSU0],
    #          [ExecutionUnit.VEC0, ExecutionUnit.LSU1],
    #          [ExecutionUnit.VEC1, ExecutionUnit.LSU0],
    #          [ExecutionUnit.VEC1, ExecutionUnit.LSU1]],
    # TODO: As above, this should somehow occupy both V and L
    St3: ExecutionUnit.V(),
    St4: ExecutionUnit.V(),
    (Vzip, Vrev, uaddlp): ExecutionUnit.V(),
    (vmov): ExecutionUnit.V(),
    VecToGprMov: ExecutionUnit.V(),
    Transpose: ExecutionUnit.V(),
    (vmovi): ExecutionUnit.V(),
    (vand, vadd, vsub): ExecutionUnit.V(),
    (vxtn): ExecutionUnit.V(),
    (vuxtl, vshl, vshl_d, vshli, vsrshr, vshrn, vsshr): ExecutionUnit.V1(),
    vusra: ExecutionUnit.V1(),
    AESInstruction: ExecutionUnit.V0(),
    (Vmul, Vmla, Vqdmulh, Vmull, Vmlal): ExecutionUnit.V0(),
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
    umull_wform: ExecutionUnit.M(),
    (AArch64HighMultiply, AArch64Multiply): ExecutionUnit.M(),
    vdup: ExecutionUnit.M(),
}

inverse_throughput = {
    (Ldr_X, Str_X, Ldr_Q, Str_Q): 1,
    (Ldp_X, Stp_X): 2,
    Stp_Q: 2,
    St3: 3,  # Multiple structures, Q form, storing bytes
    St4: 6,  # TODO: Really??
    (Vzip, uaddlp, Vrev): 1,
    VecToGprMov: 1,
    (vand, vadd, vsub): 1,
    (vmov): 1,
    Transpose: 1,
    AESInstruction: 1,
    AArch64NeonLogical: 1,
    (vmovi): 1,
    (vxtn): 1,
    (vuxtl, vshl, vshl_d, vshli, vsrshr, vshrn, vsshr): 1,
    (Vmul, Vmla, Vqdmulh): 2,
    vusra: 1,
    (Vmull, Vmlal): 1,
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
    umull_wform: 1,
}

default_latencies = {
    (Ldp_X, Ldr_X, Ldr_Q, Stp_Q): 4,
    (Stp_X, Str_X, Str_Q): 2,
    St3: 6,  # Multiple structures, Q form, storing bytes
    St4: 4,
    (Vzip, Vrev, uaddlp): 2,
    VecToGprMov: 2,
    (vxtn): 2,
    AESInstruction: 2,
    AArch64NeonLogical: 2,
    Transpose: 2,
    (vand, vadd, vsub): 2,
    (vmov): 2,  # ???
    (vmovi): 2,
    (Vmul, Vmla, Vqdmulh): 5,
    vusra: 4,  # TODO: Add fwd path
    (Vmull, Vmlal): 4,
    (vuxtl, vshl, vshl_d, vshli, vshrn, vsshr): 2,
    (vsrshr): 4,
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
    umull_wform: 2,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    # Fast mul->mla forwarding
    if (
        instclass_src in [vmul, vmul_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 2
    # Fast mla->mla forwarding
    if (
        instclass_src in [vmla, vmla_lane, vmls, vmls_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 2
    # Fast mull->mlal forwarding
    if (
        instclass_src in all_subclass_leaves(Vmull)
        and instclass_dst in all_subclass_leaves(Vmlal)
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mlal->mlal forwarding
    if (
        instclass_src in all_subclass_leaves(Vmlal)
        and instclass_dst in all_subclass_leaves(Vmlal)
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 1

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

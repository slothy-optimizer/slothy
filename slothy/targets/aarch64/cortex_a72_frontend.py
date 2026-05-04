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
Experimental and incomplete model capturing an approximation of the
frontend limitations and latencies of the Cortex-A72 CPU.

It might be surprising at first that an in-order optimizer such as Slothy could be
used for an out of order core such as Cortex-A72.

The key observation is that unless the frontend is much wider than the backend,
a high overall throughput requires a high throughput in the frontend. Since the
frontend is in-order and has documented dispatch constraints, we can model those
constraints in SLOTHY.

The consideration of latencies is less important, yet not irrelevant in this view:
Instructions dispatched well before they are ready to execute will occupy the issue
queue (IQ) for a long time, and once the IQs are full, the frontend will stall.
It is therefore advisable to generally seek to obey latencies to reduce presssure
on issue queues.

This file thus tries to model basic aspects of the frontend of Cortex-A72
alongside instruction latencies, both taken from the Cortex-A72 Software Optimization
Guide.

.. note::

    We focus on a very small subset of AArch64, just enough to experiment with the
    optimization of the Kyber and Dilithium NTT.
"""

from enum import Enum, auto
from slothy.helper import lookup_multidict
from slothy.targets.aarch64.aarch64_neon import (
    find_class,
    all_subclass_leaves,
    AArch64ConditionalCompare,
    AArch64Logical,
    Ldr_X,
    Str_X,
    Ldr_Q,
    Ldr_D,
    Str_Q,
    Stp_W,
    vadd,
    vmul,
    St4,
    Vzip,
    vsub,
    Vmull,
    Vmlal,
    vmul_lane,
    vmla,
    vmla_lane,
    vmls,
    vmls_lane,
    vqrdmulh,
    vqrdmulh_lane,
    vqdmulh_lane,
    vqdmulh_vector,
    trn1,
    trn2,
    ASimdCompare,
    Vins,
    umov_d,
    AArch64Move,
    add,
    add_imm,
    add_shifted,
    VShiftImmediateRounding,
    VShiftImmediateBasic,
    St3,
    St2,
    Ld2,
    Ld3,
    Ld4,
    AESInstruction,
    vext,
    AArch64NeonCount,
    AArch64NeonLogical,
    AArch64NeonShiftInsert,
    vtbl,
    sub_imm,
    vuaddlv_sform,
    fmov_s_form,  # from vec to gen reg
    fcsel,
    eor_shifted,
    bic_shifted,
    vusra,
    q_ldr1_stack,
    mov_vtov_d,
    Q_Ld2_Lane_Post_Inc,
    vdup_w,
    mov_wtov_s,
    lsr_imm,
    lsr,
    movk_imm_lsl,
    q_ld2_lane_s,
    Ldp_W,
    cmp,
    cmp_imm,
    csel,
    q_ldp_with_inc,
    uaddl,
    uaddl2,
    uaddw,
    uaddw2,
    saddl,
    saddl2,
    urhadd,
    rshrn,
    rshrn2,
    sqxtun,
    sqrshrun,
    q_ld1_2,
    q_ld1_4,
    q_ld1_2_with_postinc,
    q_ld1_4_with_postinc,
    q_ld1_2_with_reg_postinc,
    q_ld1_1_with_reg_postinc,
    q_ld1_lane_with_reg_postinc,
    q_st1_1_with_reg_postinc,
    q_st1_lane_with_reg_postinc,
    q_st1_4_with_postinc,
    q_stp_with_inc,
    sub_shifted,
    subs_imm,
    subs_wform,
    fadd_vec,
    fsub_vec,
    fmul_vec,
    faddp_vec,
    faddp_scalar,
    fmla,
    fmls_vec,
    fmla_lane,
    fmul_lane,
    vmovi,
    vdup_lane,
    rev64,
    mov_vtov_s,
    vins_d_from_v,
)

# From the A72 SWOG, Section "4.1 Dispatch Constraints"
# "The dispatch stage can process up to three µops per cycle"
# The name `issue_rate` is a slight misnomer here because we're
# modelling the frontend, not the backend, but `issue_width` is
# what SLOTHY expects.
issue_rate = 3
llvm_mca_target = "cortex-a72"


class ExecutionUnit(Enum):
    """Enumeration of execution units in approximative Cortex-A72 SLOTHY model"""

    LOAD0 = auto()
    LOAD1 = auto()
    STORE0 = auto()
    STORE1 = auto()
    INT0 = auto()
    INT1 = auto()
    MINT0 = auto()
    MINT1 = auto()
    ASIMD0 = auto()
    ASIMD1 = auto()

    def __repr__(self):
        return self.name

    @classmethod
    def ASIMD(cls):
        return [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1]

    @classmethod
    def LOAD(cls):
        return [ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]

    @classmethod
    def STORE(cls):
        return [ExecutionUnit.STORE0, ExecutionUnit.STORE1]

    @classmethod
    def INT(cls):
        return [ExecutionUnit.INT0, ExecutionUnit.INT1]

    @classmethod
    def MINT(cls):
        return [ExecutionUnit.MINT0, ExecutionUnit.MINT1]

    @classmethod
    def SCALAR(cls):
        return ExecutionUnit.INT() + ExecutionUnit.MINT()


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    _ = slothy


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    _ = slothy
    return False


def get_min_max_objective(slothy):
    _ = slothy


execution_units = {
    (
        vmul,
        vmul_lane,
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        vqdmulh_vector,
        Vmlal,
        Vmull,
    ): [ExecutionUnit.ASIMD0],
    (vadd, vsub, Vzip, trn1, trn2, ASimdCompare, vext, vtbl): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    (AArch64NeonLogical): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    (AArch64NeonCount): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    vdup_w: [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    mov_wtov_s: [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    mov_vtov_d: [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    (AArch64NeonShiftInsert, vusra): [ExecutionUnit.ASIMD1],
    fcsel: ExecutionUnit.ASIMD(),
    csel: ExecutionUnit.INT(),
    AArch64ConditionalCompare: ExecutionUnit.INT(),
    AArch64Logical: [ExecutionUnit.INT()],
    # 8B/8H occupies both F0, F1
    vuaddlv_sform: [[ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1]],
    Vins: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    umov_d: ExecutionUnit.LOAD(),  # ???
    (Ldr_D, Ldr_Q, Ldr_X): ExecutionUnit.LOAD(),
    (Str_Q, Str_X): ExecutionUnit.STORE(),
    AArch64Move: ExecutionUnit.SCALAR(),
    (add, add_imm, add_shifted): ExecutionUnit.SCALAR(),
    (VShiftImmediateRounding, VShiftImmediateBasic): [ExecutionUnit.ASIMD1],
    (St4, St3, St2): [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    (Ld2, Ld3, Ld4, q_ldr1_stack, Q_Ld2_Lane_Post_Inc, q_ld2_lane_s): [
        [ExecutionUnit.ASIMD0, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
        [ExecutionUnit.ASIMD1, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
    ],
    AESInstruction: [ExecutionUnit.ASIMD0],
    fmov_s_form: ExecutionUnit.LOAD(),  # from vec to gen reg
    eor_shifted: ExecutionUnit.SCALAR(),
    bic_shifted: ExecutionUnit.SCALAR(),
    sub_shifted: ExecutionUnit.SCALAR(),
    (subs_wform, subs_imm): ExecutionUnit.INT(),
    lsr_imm: ExecutionUnit.INT(),
    lsr: ExecutionUnit.INT(),
    movk_imm_lsl: ExecutionUnit.INT(),
    (sub_imm, cmp, cmp_imm): ExecutionUnit.INT(),
    Ldp_W: ExecutionUnit.LOAD(),
    q_ldp_with_inc: ExecutionUnit.LOAD(),
    Stp_W: ExecutionUnit.STORE(),
    q_stp_with_inc: [
        ExecutionUnit.STORE() + [ExecutionUnit.INT0],
        ExecutionUnit.STORE() + [ExecutionUnit.INT1],
    ],
    (uaddl, uaddl2, uaddw, uaddw2, saddl, saddl2, urhadd): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    (rshrn, rshrn2, sqxtun, sqrshrun): [ExecutionUnit.ASIMD1],
    (fadd_vec, fsub_vec, fmul_vec, faddp_vec, fmla, fmls_vec): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    faddp_scalar: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    (fmla_lane, fmul_lane): [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    vmovi: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    vdup_lane: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    rev64: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    mov_vtov_s: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    vins_d_from_v: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    (
        q_ld1_2,
        q_ld1_2_with_postinc,
        q_ld1_2_with_reg_postinc,
        q_ld1_4,
        q_ld1_4_with_postinc,
        q_ld1_1_with_reg_postinc,
    ): ExecutionUnit.LOAD(),
    q_ld1_lane_with_reg_postinc: [
        [ExecutionUnit.ASIMD0, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
        [ExecutionUnit.ASIMD1, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
    ],
    q_st1_lane_with_reg_postinc: [
        [ExecutionUnit.ASIMD0, ExecutionUnit.STORE0, ExecutionUnit.STORE1],
        [ExecutionUnit.ASIMD1, ExecutionUnit.STORE0, ExecutionUnit.STORE1],
    ],
    (q_st1_1_with_reg_postinc, q_st1_4_with_postinc): [ExecutionUnit.STORE()],
}

inverse_throughput = {
    (
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        vqdmulh_lane,
        vqdmulh_vector,
    ): 2,
    AArch64Move: 1,
    (Vmull, Vmlal): 1,
    AArch64NeonCount: 1,
    Vzip: 1,
    ASimdCompare: 1,
    (vadd, vsub, trn1, trn2, vext): 1,
    AArch64NeonLogical: 1,
    (AArch64NeonShiftInsert, vusra): 1,
    fcsel: 1,
    csel: 1,
    AArch64ConditionalCompare: 1,
    AArch64Logical: 1,
    Vins: 1,
    umov_d: 1,
    (add, add_imm, add_shifted): 1,
    (Ldr_D, Ldr_Q, Str_Q, Ldr_X, Str_X): 1,
    q_stp_with_inc: 4,
    (VShiftImmediateRounding, VShiftImmediateBasic): 1,
    # TODO: this seems in accurate; revisiting may improve performance
    St2: 4,
    St3: 6,
    St4: 8,
    Ld2: 2,
    Ld3: 3,
    Ld4: 4,
    q_ldp_with_inc: 4,
    q_ldr1_stack: 1,
    Q_Ld2_Lane_Post_Inc: 2,
    q_ld2_lane_s: 1,
    vtbl: 1,  # SWOG contains a blank throughput (approximating from AArch32)
    AESInstruction: 1,
    (sub_imm, cmp, cmp_imm): 1,
    vuaddlv_sform: 1,
    fmov_s_form: 1,  # from vec to gen reg
    eor_shifted: 1,
    bic_shifted: 1,
    sub_shifted: 1,
    (subs_wform, subs_imm): 1,
    (fadd_vec, fsub_vec, fmul_vec, faddp_vec, faddp_scalar, fmla, fmls_vec): 1,
    (fmla_lane, fmul_lane): 1,
    vmovi: 1,
    vdup_lane: 1,
    rev64: 1,
    mov_vtov_s: 1,
    vins_d_from_v: 1,
    vdup_w: 1,
    mov_wtov_s: 1,
    mov_vtov_d: 1,
    lsr_imm: 1,
    lsr: 1,
    movk_imm_lsl: 1,
    Ldp_W: 1,
    Stp_W: 1,
    (uaddl, uaddl2, uaddw, uaddw2, saddl, saddl2, urhadd): 1,
    (rshrn, rshrn2, sqxtun, sqrshrun): 1,
    (q_ld1_2, q_ld1_2_with_postinc, q_ld1_2_with_reg_postinc): 2,
    (q_ld1_4, q_ld1_4_with_postinc): 4,
    (q_ld1_1_with_reg_postinc, q_ld1_lane_with_reg_postinc): 1,
    q_st1_1_with_reg_postinc: 2,
    q_st1_lane_with_reg_postinc: 1,
    q_st1_4_with_postinc: 8,
}

# REVISIT
default_latencies = {
    (
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vmls,
        vmls_lane,
        vmla,
        vmla_lane,
        vqdmulh_lane,
        vqdmulh_vector,
    ): 5,
    (Vmull, Vmlal): 1,
    AArch64NeonCount: 3,
    (
        vadd,
        vsub,
        Vzip,
        trn1,
        trn2,
        ASimdCompare,
        vext,
    ): 3,  # Approximation -- not necessary to get it exactly right, as mentioned above
    AArch64NeonLogical: 3,
    AArch64NeonShiftInsert: 3,
    vusra: 4,
    fcsel: 3,
    csel: 1,
    AArch64ConditionalCompare: 1,
    AArch64Logical: 1,
    (Ldr_D, Ldr_Q, Ldr_X, Str_Q, Str_X, q_stp_with_inc): 4,  # approx
    Vins: 6,  # approx
    umov_d: 4,  # approx
    (add, add_imm, add_shifted): 2,
    VShiftImmediateRounding: 3,  # approx
    VShiftImmediateBasic: 3,
    AArch64Move: 1,
    # TODO: this seems in accurate; revisiting may improve performance
    St2: 4,
    St3: 6,
    St4: 8,
    Ld2: 9,
    Ld3: 3,
    Ld4: 4,
    q_ldp_with_inc: 6,
    q_ldr1_stack: 8,
    Q_Ld2_Lane_Post_Inc: 9,
    q_ld2_lane_s: 8,
    vtbl: 6,  # q-form: 3*N+3 cycles (N = number of registers in the table)
    AESInstruction: 3,
    (sub_imm, cmp, cmp_imm): 1,
    vuaddlv_sform: 6,  # 8B/8H
    fmov_s_form: 5,  # from vec to gen reg
    eor_shifted: 2,
    bic_shifted: 2,
    sub_shifted: 2,
    (subs_wform, subs_imm): 1,
    (fadd_vec, fsub_vec, faddp_vec, faddp_scalar): 4,
    fmul_vec: 4,
    (fmla, fmls_vec, fmla_lane): 7,
    fmul_lane: 5,
    vmovi: 3,
    vdup_lane: 3,
    rev64: 3,
    mov_vtov_s: 3,
    vins_d_from_v: 3,
    vdup_w: 8,
    mov_wtov_s: 8,
    mov_vtov_d: 3,
    lsr_imm: 1,
    lsr: 1,
    movk_imm_lsl: 1,
    Ldp_W: 4,
    Stp_W: 1,
    (uaddl, uaddl2, uaddw, uaddw2, saddl, saddl2, urhadd): 3,
    (rshrn, rshrn2, sqrshrun, sqxtun): 4,
    # Multi-register ld1 (SWOG: Q-form latencies)
    q_ld1_1_with_reg_postinc: 5,
    (q_ld1_2, q_ld1_2_with_postinc, q_ld1_2_with_reg_postinc): 6,
    (q_ld1_4, q_ld1_4_with_postinc): 8,
    # Single-lane ld1 B/H/S (SWOG: 8 cycles)
    q_ld1_lane_with_reg_postinc: 8,
    # Single-lane st1 B/H/S (SWOG: 3 cycles)
    q_st1_lane_with_reg_postinc: 3,
    q_st1_1_with_reg_postinc: 2,
    q_st1_4_with_postinc: 8,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src, instclass_src)

    # Fast mul->mla forwarding
    if (
        instclass_src in [vmul, vmul_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mla->mla forwarding
    if (
        instclass_src in [vmla, vmla_lane, vmls, vmls_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 1
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
    # Fast fmul->fmla forwarding (accumulate_latency=3)
    if (
        instclass_src in [fmul_vec, fmul_lane]
        and instclass_dst in [fmla, fmls_vec, fmla_lane]
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 3
    # Fast fmla->fmla forwarding (accumulate_latency=3)
    if (
        instclass_src in [fmla, fmls_vec, fmla_lane]
        and instclass_dst in [fmla, fmls_vec, fmla_lane]
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 3

    return latency


def get_units(src):
    instclass_src = find_class(src)
    units = lookup_multidict(execution_units, src, instclass_src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    instclass_src = find_class(src)
    return lookup_multidict(inverse_throughput, src, instclass_src)

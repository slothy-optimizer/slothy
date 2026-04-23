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
Experimental Cortex-A55 microarchitecture model for SLOTHY

Most data in this model is derived from the Cortex-A55 software optimization guide.
Some latency exceptions were manually identified through microbenchmarks.

.. warning::

    The data in this module is approximate and may contain errors.
"""

# ################################ NOTE ############################################ #
#                                                                                    #
#  WARNING: The data in this module is approximate and may contain errors.           #
#           They are _NOT_ an official software optimization guide for Cortex-A55.   #
#                                                                                    #
# ################################################################################## #

from enum import Enum
from slothy.helper import lookup_multidict
from slothy.targets.aarch64.aarch64_neon import (
    find_class,
    AArch64ConditionalCompare,
    Ldp_W,
    Ldp_X,
    q_ldp_with_inc,
    Ldr_X,
    Str_X,
    Stp_X,
    Stp_W,
    Ldr_Q,
    Ldr_D,
    Str_Q,
    Stp_Q,
    vmov,
    vmovi,
    vadd,
    vxtn,
    vshrn,
    vusra,
    vmul,
    Instruction,
    csel,
    fcsel,
    Q_Ld2_Lane_Post_Inc,
    q_ld2_lane_s,
    vmla,
    vmla_lane,
    vmls,
    vmls_lane,
    fmla,
    faddp_vec,
    faddp_scalar,
    fadd_vec,
    fsub_vec,
    fmul_vec,
    vmul_lane,
    vqrdmulh,
    vqrdmulh_lane,
    vqdmulh_lane,
    vqdmulh_vector,
    vbic,
    vbic_imm_shifted,
    q_ldr1_stack,
    q_ldr1_post_inc,
    Vmull,
    Vmlal,
    vushr,
    vsshr,
    vuxtl,
    vshl_d,
    vshl,
    VShiftImmediateRounding,
    St4,
    Ld4,
    St3,
    Ld3,
    St2,
    Ld2,
    sxtb,
    uxtb,
    umov_d,
    mov_d01,
    mov_b00,
    mov_vtov_d,
    VecToGprMov,
    Mov_xtov_d,
    mov_wtov_s,
    d_stp_stack_with_inc,
    d_str_stack_with_inc,
    b_ldr_stack_with_inc,
    d_ldr_stack_with_inc,
    is_qform_form_of,
    is_dform_form_of,
    trn1,
    trn2,
    vzip1,
    vzip2,
    vuzp1,
    vext,
    vuzp2,
    vsub,
    w_stp_with_imm_sp,
    ldr_const,
    ldr_sxtw_wform,
    umull_wform,
    mul_wform,
    umaddl_wform,
    lsr_imm,
    bic,
    bic_reg,
    eor,
    eon,
    ror,
    eor_shifted,
    bic_shifted,
    bfi,
    add,
    add_imm,
    add_sp_imm,
    add2,
    add_shifted,
    adcs_to_zero,
    adcs_zero_r_to_zero,
    adcs_zero2,
    cmn,
    and_imm,
    nop,
    Vins,
    tst_wform,
    movk_imm,
    movk_imm_lsl,
    movz_imm,
    movz_imm_lsl,
    movw_imm,
    mov_imm,
    mov_xform,
    sub,
    sbcs_zero_to_zero,
    cmp_xzr2,
    cmp_imm,
    mov,
    ngc_zero,
    subs_wform,
    subs_imm,
    asr_wform,
    and_imm_wform,
    eor_wform,
    eon_wform,
    lsr_wform,
    lsr,
    lsl_wform,
    sub_wform,
    ASimdCompare,
    and_twoarg,
    VShiftImmediateBasic,
    ubfx,
    AESInstruction,
    AArch64NeonCount,
    AArch64NeonLogical,
    AArch64NeonShiftInsert,
    vtbl,
    sub_imm,
    vuaddlv_sform,
    fmov_s_form,  # from double/single to gen reg
    cmp,
    vdup_w,
    vdup_lane,
    fmla_lane,
    fmls_vec,
    fmul_lane,
    mov_vtov_s,
    Vrev,
    uaddl,
    uaddl2,
    uaddw,
    uaddw2,
    saddl,
    saddl2,
    rshrn,
    rshrn2,
    sqxtun,
    sqrshrun,
    urhadd,
    sub_shifted,
    sxtw,
    q_ld1_2,
    q_ld1_2_with_postinc,
    q_ld1_2_with_reg_postinc,
    q_ld1_4,
    q_ld1_4_with_postinc,
    q_ld1_1_with_reg_postinc,
    q_ld1_lane_with_reg_postinc,
    q_st1_1_with_reg_postinc,
    q_st1_lane_with_reg_postinc,
    q_st1_4_with_postinc,
    vins_d_from_v,
)

issue_rate = 2
llvm_mca_target = "cortex-a55"


class ExecutionUnit(Enum):
    """Enumeration of execution units in Cortex-A55 model"""

    SCALAR_ALU0 = 1
    SCALAR_ALU1 = 2
    SCALAR_MAC = 3
    SCALAR_LOAD = 4
    SCALAR_STORE = 5
    VEC0 = 6
    VEC1 = 7

    def __repr__(self):
        return self.name

    @classmethod
    def SCALAR(cls):
        """All scalar execution units"""
        return [ExecutionUnit.SCALAR_ALU0, ExecutionUnit.SCALAR_ALU1]

    @classmethod
    def SCALAR_MUL(cls):
        """All multiply-capable scalar execution units"""
        return [ExecutionUnit.SCALAR_MAC]


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    add_slot_constraints(slothy)
    add_st_hazard(slothy)


def add_slot_constraints(slothy):
    # Q-Form vector instructions are on slot 0 only
    slothy.restrict_slots_for_instructions_by_property(
        Instruction.is_q_form_vector_instruction, [0]
    )
    # fcsel and vld2 on slot 0 only
    slothy.restrict_slots_for_instructions_by_class([fcsel, Q_Ld2_Lane_Post_Inc], [0])


def add_st_hazard(slothy):
    def is_vec_st_st_pair(inst_a, inst_b):
        return inst_a.inst.is_vector_store() and inst_b.inst.is_vector_store()

    for t0, t1 in slothy.get_inst_pairs(cond=is_vec_st_st_pair):
        if t0.is_locked and t1.is_locked:
            continue
        slothy._Add(t0.cycle_start_var != t1.cycle_start_var + 1)


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    """Adds Cortex-"""
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    # q-form vector instructions
    (
        vmla_lane,
        vmls_lane,
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        vqdmulh_vector,
        Ldr_Q,
        Str_Q,
        Stp_Q,
        q_ldr1_stack,
        q_ldr1_post_inc,
        Q_Ld2_Lane_Post_Inc,
        q_ld2_lane_s,
        Vmull,
        Vmlal,
        vusra,
        vshrn,
        vxtn,
        vtbl,
        VShiftImmediateRounding,
        AArch64NeonLogical,
        vuaddlv_sform,
        uaddl,
        uaddl2,
        uaddw,
        uaddw2,
        saddl,
        saddl2,
        rshrn2,
        q_ld1_2,
        q_ld1_2_with_postinc,
        q_ld1_2_with_reg_postinc,
        q_ld1_4,
        q_ld1_4_with_postinc,
        # TODO: revisit -- lane load might also needs SCALAR_LOAD; placed here
        # following the Ldr_Q convention which also omits a load unit.
        q_ld1_1_with_reg_postinc,
        q_ld1_lane_with_reg_postinc,
        q_st1_lane_with_reg_postinc,
        q_st1_4_with_postinc,
        vmovi,
    ): [
        [ExecutionUnit.VEC0, ExecutionUnit.VEC1]
    ],  # these instructions use both VEC0 and VEC1
    St4: [
        [
            ExecutionUnit.VEC0,
            ExecutionUnit.VEC1,
            ExecutionUnit.SCALAR_LOAD,
            ExecutionUnit.SCALAR_STORE,
        ]
        + ExecutionUnit.SCALAR()
    ],
    Ld4: [
        [ExecutionUnit.VEC0, ExecutionUnit.VEC1, ExecutionUnit.SCALAR_LOAD]
        + ExecutionUnit.SCALAR()
    ],
    St3: [
        [
            ExecutionUnit.VEC0,
            ExecutionUnit.VEC1,
            ExecutionUnit.SCALAR_LOAD,
            ExecutionUnit.SCALAR_STORE,
        ]
        + ExecutionUnit.SCALAR()
    ],
    Ld3: [
        [ExecutionUnit.VEC0, ExecutionUnit.VEC1, ExecutionUnit.SCALAR_LOAD]
        + ExecutionUnit.SCALAR()
    ],
    St2: [
        [
            ExecutionUnit.VEC0,
            ExecutionUnit.VEC1,
            ExecutionUnit.SCALAR_LOAD,
            ExecutionUnit.SCALAR_STORE,
        ]
        + ExecutionUnit.SCALAR()
    ],
    Ld2: [
        [ExecutionUnit.VEC0, ExecutionUnit.VEC1, ExecutionUnit.SCALAR_LOAD]
        + ExecutionUnit.SCALAR()
    ],
    # non-q-form vector instructions
    (
        Ldr_D,
        umov_d,
        mov_d01,
        mov_b00,
        mov_vtov_d,
        mov_vtov_s,
        mov_vtov_s,
        fcsel,
        VecToGprMov,
        Mov_xtov_d,
        mov_wtov_s,
        d_stp_stack_with_inc,
        d_str_stack_with_inc,
        b_ldr_stack_with_inc,
        d_ldr_stack_with_inc,
        fmov_s_form,  # from double/single to gen reg
        vdup_w,
        is_dform_form_of(sqrshrun),
        is_dform_form_of(rshrn),
        is_dform_form_of(sqxtun),
        is_dform_form_of(urhadd),
        vins_d_from_v,
        q_st1_1_with_reg_postinc,
    ): [
        ExecutionUnit.VEC0,
        ExecutionUnit.VEC1,
    ],  # these instructions use VEC0 or VEC1
    is_qform_form_of(urhadd): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_qform_form_of(vmov): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vmov): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(trn1): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(trn1): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(trn2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(trn2): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(ASimdCompare): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(ASimdCompare): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vzip1): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_qform_form_of(AArch64NeonCount): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(AArch64NeonCount): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_dform_form_of(vzip1): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vzip2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vzip2): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vext): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vext): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vdup_lane): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vdup_lane): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(Vrev): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(Vrev): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vuzp1): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vuzp1): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vuzp2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vuzp2): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vsub): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vsub): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vadd): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vadd): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vshl): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vshl): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vshrn): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vshrn): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vushr): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vushr): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vsshr): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vsshr): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vmla): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vmla): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vmls): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vmls): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fmla): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fmla): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fmla_lane): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fmla_lane): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_qform_form_of(faddp_vec): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(faddp_vec): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    faddp_scalar: [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fadd_vec): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fadd_vec): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fsub_vec): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fsub_vec): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fmul_vec): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fmul_vec): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fmls_vec): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fmls_vec): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(fmul_lane): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(fmul_lane): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    vshl_d: [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    vuxtl: [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_qform_form_of(AArch64NeonShiftInsert): [
        [ExecutionUnit.VEC0, ExecutionUnit.VEC1]
    ],
    is_dform_form_of(AArch64NeonShiftInsert): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    (Stp_X, Stp_W, w_stp_with_imm_sp, Str_X): ExecutionUnit.SCALAR_STORE,
    (
        ldr_const,
        ldr_sxtw_wform,
        Ldr_X,
        Ldp_W,
        Ldp_X,
        q_ldp_with_inc,
    ): ExecutionUnit.SCALAR_LOAD,
    (umull_wform, mul_wform, umaddl_wform): ExecutionUnit.SCALAR_MUL(),
    (
        lsr_imm,
        bic,
        bic_reg,
        bfi,
        ubfx,
        add,
        mov_imm,
        mov_xform,
        movw_imm,
        cmp_imm,
        eor,
        eon,
        eor_shifted,
        bic_shifted,
        ror,
        add_imm,
        add_sp_imm,
        add2,
        add_shifted,
        adcs_to_zero,
        adcs_zero_r_to_zero,
        adcs_zero2,
        cmn,
        and_imm,
        nop,
        Vins,
        tst_wform,
        movk_imm,
        movk_imm_lsl,
        movz_imm,
        movz_imm_lsl,
        sub,
        sub_shifted,
        sub_imm,
        sxtw,
        cmp,
        sbcs_zero_to_zero,
        cmp_xzr2,
        mov,
        ngc_zero,
        subs_wform,
        subs_imm,
        asr_wform,
        and_imm_wform,
        lsr_wform,
        lsr,
        lsl_wform,
        sub_wform,
        eor_wform,
        eon_wform,
        sxtb,
        uxtb,
    ): ExecutionUnit.SCALAR(),
    AArch64ConditionalCompare: ExecutionUnit.SCALAR(),
    # NOTE: AESE/AESMC and AESD/AESIMC pairs can be dual-issued on A55 but this
    # is not modeled
    AESInstruction: [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    csel: ExecutionUnit.SCALAR(),
}

inverse_throughput = {
    (
        vadd,
        vsub,
        vmov,
        vmovi,
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        vqdmulh_vector,
        Vmull,
        Vmlal,
        umov_d,
        vuaddlv_sform,
    ): 1,
    (sub_imm, cmp): 1,
    (
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        fmla,
        fmla_lane,
        fmls_vec,
        fmul_lane,
        fmls_vec,
        fmul_lane,
        faddp_vec,
        faddp_scalar,
        fadd_vec,
        fsub_vec,
        fmul_vec,
    ): 1,
    (vshl, vshl_d, vsshr, vushr, vuxtl): 1,
    (trn2, trn1, ASimdCompare): 1,
    (Ldr_D): 1,
    (Ldr_Q, q_ld1_1_with_reg_postinc): 2,
    (AArch64NeonCount): 1,
    (Str_Q, Stp_Q, q_st1_1_with_reg_postinc): 1,
    q_st1_4_with_postinc: 4,
    (tst_wform): 1,
    (nop, Vins, Ldr_X, Str_X): 1,
    Ldp_X: 2,
    Ldp_W: 1,
    St4: 5,
    St3: 3,
    St2: 2,
    Ld4: 9,
    Ld3: 6,
    Ld2: 4,
    q_ldp_with_inc: 4,
    vxtn: 1,
    vshrn: 2,
    vtbl: 1,  # N cycles (N = number of registers in the table)
    (fcsel): 1,
    csel: 1,
    (VecToGprMov, Mov_xtov_d, mov_wtov_s): 1,
    (
        movk_imm,
        movk_imm_lsl,
        movz_imm,
        movz_imm_lsl,
        mov,
        mov_imm,
        mov_xform,
        movw_imm,
    ): 1,
    (d_stp_stack_with_inc, d_str_stack_with_inc): 1,
    (Stp_X, Stp_W, w_stp_with_imm_sp): 1,
    (ldr_const): 1,
    (ldr_sxtw_wform): 3,
    (lsr_imm, ror): 1,
    (lsr, lsr_wform, lsl_wform): 2,
    (umull_wform, mul_wform, umaddl_wform): 1,
    (and_twoarg, and_imm, and_imm_wform): 1,
    (
        add,
        add_imm,
        add2,
        add_shifted,
        add_sp_imm,
        adcs_to_zero,
        adcs_zero2,
        adcs_zero_r_to_zero,
        cmn,
    ): 1,
    (
        cmp_xzr2,
        cmp_imm,
        sub,
        sub_wform,
        sub_shifted,
        subs_wform,
        subs_imm,
        asr_wform,
        sbcs_zero_to_zero,
        ngc_zero,
    ): 1,
    (bfi, ubfx): 1,
    VShiftImmediateRounding: 1,
    AArch64NeonShiftInsert: 1,
    (vusra): 1,
    (uaddl, uaddl2): 1,
    (uaddw, uaddw2): 1,
    (saddl, saddl2): 1,
    (rshrn, rshrn2, sqxtun): 1,
    (q_ld1_2, q_ld1_2_with_postinc, q_ld1_2_with_reg_postinc): 4,
    (q_ld1_4, q_ld1_4_with_postinc): 8,
    q_ld1_lane_with_reg_postinc: 1,
    q_st1_lane_with_reg_postinc: 1,
    vins_d_from_v: 1,
    sxtw: 1,
    sqrshrun: 1,
    urhadd: 1,
    AArch64NeonLogical: 1,
    vext: 1,
    Vrev: 1,
    vdup_lane: 1,
    (vuzp1, vuzp2): 1,
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc, q_ldr1_post_inc, q_ld2_lane_s): 1,
    (b_ldr_stack_with_inc, d_ldr_stack_with_inc): 1,
    (mov_d01, mov_b00, mov_vtov_d, mov_vtov_s): 1,
    (mov_d01, mov_b00, mov_vtov_d, mov_vtov_s): 1,
    (vzip1, vzip2): 1,
    (eor_wform, eon_wform): 1,
    (eon, eor, bic, bic_reg, eor_shifted, bic_shifted): 1,
    AArch64ConditionalCompare: 1,
    AESInstruction: 1,
    fmov_s_form: 1,  # from double/single to gen reg
    vdup_w: 1,
    (sxtb, uxtb): 1,
}

default_latencies = {
    vdup_w: 3,
    vmov: 2,
    vmovi: 1,
    is_qform_form_of([vadd, vsub]): 3,
    is_dform_form_of([vadd, vsub]): 2,
    (trn1, trn2, ASimdCompare): 2,
    (
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        vqdmulh_vector,
        Vmull,
        Vmlal,
    ): 4,
    (
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        fmla,
        fmla_lane,
        fmls_vec,
        fmul_lane,
        fmls_vec,
        fmul_lane,
        fadd_vec,
        fsub_vec,
        fmul_vec,
    ): 4,
    (Ldr_D): 3,
    (
        faddp_vec,
        faddp_scalar,
    ): 4,
    (
        Ldr_Q,
        Str_Q,
        Stp_Q,
        q_ld1_1_with_reg_postinc,
        q_st1_1_with_reg_postinc,
        q_st1_4_with_postinc,
    ): 4,
    (sub_imm, cmp): 2,
    AArch64NeonCount: 2,
    St4: 5,
    St3: 3,
    St2: 2,
    # TODO: Add distinction between Q/D and B/H vs. D/S
    Ld2: 6,
    Ld3: 8,
    Ld4: 11,
    vxtn: 2,
    vshrn: 2,
    vtbl: 2,  # 2+N-1 cycles (N = number of registers in the table)
    (Str_X, Ldr_X): 4,
    Ldp_X: 4,
    Ldp_W: 3,
    q_ldp_with_inc: 6,
    (Vins, umov_d, vins_d_from_v): 2,
    (tst_wform): 1,
    (fcsel): 2,
    csel: 1,
    (VecToGprMov, Mov_xtov_d, mov_wtov_s): 2,
    (
        movk_imm,
        movk_imm_lsl,
        movz_imm,
        movz_imm_lsl,
        mov,
        mov_imm,
        mov_xform,
        movw_imm,
    ): 1,
    (d_stp_stack_with_inc, d_str_stack_with_inc): 1,
    (Stp_X, Stp_W, w_stp_with_imm_sp): 1,
    (ldr_const): 3,
    (ldr_sxtw_wform): 5,
    (lsr, lsr_wform, lsl_wform, sub_wform): 1,
    lsr_imm: 2,
    (umull_wform, mul_wform, umaddl_wform): 3,
    (vuaddlv_sform): 3,
    (and_imm, and_imm_wform): 1,
    (add2, add_shifted, sub_shifted, add_sp_imm): 2,
    (
        add,
        add_imm,
        adcs_to_zero,
        adcs_zero_r_to_zero,
        adcs_zero2,
        cmn,
        sub,
        sub_wform,
        subs_wform,
        subs_imm,
        asr_wform,
        sbcs_zero_to_zero,
        cmp_xzr2,
        ngc_zero,
        cmp_imm,
    ): 1,
    (bfi, ubfx): 2,
    VShiftImmediateRounding: 3,
    VShiftImmediateBasic: 2,
    AArch64NeonShiftInsert: 2,
    (vusra): 3,
    (uaddl, uaddl2): 3,
    (uaddw, uaddw2): 3,
    # LD1 multi-reg Q-form latencies (SWOG section 4.18)
    (q_ld1_2, q_ld1_2_with_postinc, q_ld1_2_with_reg_postinc): 6,
    (q_ld1_4, q_ld1_4_with_postinc): 10,
    q_ld1_lane_with_reg_postinc: 3,
    q_st1_lane_with_reg_postinc: 1,
    sxtw: 2,
    (saddl, saddl2): 3,
    (rshrn, rshrn2): 3,
    sqxtun: 4,
    sqrshrun: 4,
    urhadd: 2,
    AArch64NeonLogical: 1,
    vext: 2,
    Vrev: 2,
    vdup_lane: 2,
    (vuzp1, vuzp2): 2,
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc, q_ldr1_post_inc): 3,
    q_ld2_lane_s: 3,
    (b_ldr_stack_with_inc, d_ldr_stack_with_inc): 3,
    (mov_d01, mov_b00, mov_vtov_d, mov_vtov_s): 2,
    (mov_d01, mov_b00, mov_vtov_d, mov_vtov_s): 2,
    (vzip1, vzip2): 2,
    (eor_wform, eon_wform): 1,
    # According to SWOG, this is 2 cycles, byt if the output is used as a
    # _non-shifted_ input to the next instruction, the effective latency
    # seems to be 1 cycle. See https://eprint.iacr.org/2022/1243.pdf
    (eor_shifted, bic_shifted): 1,
    (eon, ror, eor, bic, bic_reg): 1,
    AArch64ConditionalCompare: 1,
    # NOTE: AESE/AESMC and AESD/AESIMC pairs can be dual-issued on A55 but this
    # is not modeled
    AESInstruction: 2,
    fmov_s_form: 1,  # from double/single to gen reg
    (sxtb, uxtb): 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src, instclass_src)

    if instclass_dst in [trn1, trn2, vzip1, vzip2, vuzp1, vuzp2, fcsel] and latency < 3:
        latency += 1

    if [instclass_src, instclass_dst] in [
        [lsr_imm, mul_wform],
        [lsr_imm, umaddl_wform],
        [vbic, vusra],
        [vbic_imm_shifted, vusra],
    ]:
        latency += 1

    if (
        isinstance(src, Vmlal)
        and isinstance(dst, Vmlal)
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return (
            4,
            lambda t_src, t_dst: t_dst.program_start_var == t_src.program_start_var + 2,
        )

    if (
        instclass_src == umaddl_wform
        and instclass_dst == umaddl_wform
        and src.args_out[0] == dst.args_out[0]
    ):
        return (
            3,
            lambda t_src, t_dst: t_dst.program_start_var == t_src.program_start_var + 1,
        )

    # Fast mul->mla forwarding (accumulate_latency=1)
    if (
        instclass_src in [vmul, vmul_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mla->mla forwarding (accumulate_latency=1)
    if (
        instclass_src in [vmla, vmla_lane, vmls, vmls_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mull->mlal forwarding (accumulate_latency=1)
    if (
        isinstance(src, Vmull)
        and isinstance(dst, Vmlal)
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1

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

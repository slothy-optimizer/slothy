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
from slothy.targets.aarch64.aarch64_neon import (
    lookup_multidict,
    find_class,
    Ldp_X,
    Ldr_X,
    Str_X,
    Stp_X,
    Ldr_Q,
    Str_Q,
    vmov,
    vand,
    vadd,
    vxtn,
    vshli,
    vshrn,
    vusra,
    vmul,
    Instruction,
    fcsel_dform,
    Q_Ld2_Lane_Post_Inc,
    vmls,
    vmls_lane,
    vmul_lane,
    vmla,
    vmla_lane,
    vqrdmulh,
    vqrdmulh_lane,
    vqdmulh_lane,
    vbic,
    q_ldr1_stack,
    q_ldr1_post_inc,
    Vmull,
    Vmlal,
    vushr,
    vsshr,
    VShiftImmediateRounding,
    St4,
    Ld4,
    St3,
    Ld3,
    St2,
    Ld2,
    umov_d,
    mov_d01,
    mov_b00,
    VecToGprMov,
    Mov_xtov_d,
    d_stp_stack_with_inc,
    d_str_stack_with_inc,
    b_ldr_stack_with_inc,
    d_ldr_stack_with_inc,
    is_qform_form_of,
    is_dform_form_of,
    trn1,
    trn2,
    cmge,
    vzip1,
    vzip2,
    vuzp1,
    vsri,
    veor,
    vuzp2,
    vsub,
    vshl,
    w_stp_with_imm_sp,
    x_str_sp_imm,
    x_ldr_stack_imm,
    ldr_const,
    ldr_sxtw_wform,
    umull_wform,
    mul_wform,
    umaddl_wform,
    lsr,
    bic,
    eor,
    ror,
    eor_ror,
    bic_ror,
    bfi,
    add,
    add_imm,
    add_sp_imm,
    add2,
    add_lsr,
    add_lsl,
    adcs_to_zero,
    adcs_zero_r_to_zero,
    adcs_zero2,
    cmn,
    and_imm,
    nop,
    Vins,
    tst_wform,
    movk_imm,
    movw_imm,
    mov_imm,
    sub,
    sbcs_zero_to_zero,
    cmp_xzr2,
    cmp_imm,
    mov,
    ngc_zero,
    subs_wform,
    asr_wform,
    and_imm_wform,
    eor_wform,
    lsr_wform,
    ASimdCompare,
    and_twoarg,
    VShiftImmediateBasic,
    vmlal,
    ubfx,
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
    slothy.restrict_slots_for_instructions_by_class(
        [fcsel_dform, Q_Ld2_Lane_Post_Inc], [0]
    )


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
        vmls,
        vmls_lane,
        vmul,
        vmul_lane,
        vmla,
        vmla_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        vand,
        vbic,
        vsri,
        veor,
        Ldr_Q,
        Str_Q,
        q_ldr1_stack,
        q_ldr1_post_inc,
        Q_Ld2_Lane_Post_Inc,
        Vmull,
        Vmlal,
        vusra,
        vushr,
        vsshr,
        vshrn,
        vshli,
        vxtn,
        VShiftImmediateRounding,
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
        umov_d,
        mov_d01,
        mov_b00,
        fcsel_dform,
        VecToGprMov,
        Mov_xtov_d,
        d_stp_stack_with_inc,
        d_str_stack_with_inc,
        b_ldr_stack_with_inc,
        d_ldr_stack_with_inc,
        q_ldr1_stack,
        Q_Ld2_Lane_Post_Inc,
    ): [
        ExecutionUnit.VEC0,
        ExecutionUnit.VEC1,
    ],  # these instructions use VEC0 or VEC1
    is_qform_form_of(vmov): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vmov): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(trn1): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(trn1): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(trn2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_qform_form_of(trn2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(trn2): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(cmge): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(cmge): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vzip1): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vzip1): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    is_qform_form_of(vzip2): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    is_dform_form_of(vzip2): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
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
    (Stp_X, w_stp_with_imm_sp, x_str_sp_imm, Str_X): ExecutionUnit.SCALAR_STORE,
    (
        x_ldr_stack_imm,
        ldr_const,
        ldr_sxtw_wform,
        Ldr_X,
        Ldp_X,
    ): ExecutionUnit.SCALAR_LOAD,
    (umull_wform, mul_wform, umaddl_wform): ExecutionUnit.SCALAR_MUL(),
    (
        lsr,
        bic,
        bfi,
        ubfx,
        add,
        mov_imm,
        movw_imm,
        cmp_imm,
        eor,
        eor_ror,
        bic_ror,
        ror,
        add_imm,
        add_sp_imm,
        add2,
        add_lsr,
        add_lsl,
        adcs_to_zero,
        adcs_zero_r_to_zero,
        adcs_zero2,
        cmn,
        and_imm,
        nop,
        Vins,
        tst_wform,
        movk_imm,
        sub,
        sbcs_zero_to_zero,
        cmp_xzr2,
        mov,
        ngc_zero,
        subs_wform,
        asr_wform,
        and_imm_wform,
        lsr_wform,
        eor_wform,
    ): ExecutionUnit.SCALAR(),
}

inverse_throughput = {
    (
        vadd,
        vsub,
        vmov,
        vmul,
        vmul_lane,
        vmls,
        vmls_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        Vmull,
        Vmlal,
        umov_d,
    ): 1,
    (trn2, trn1, ASimdCompare): 1,
    (Ldr_Q): 2,
    (Str_Q): 1,
    (tst_wform): 1,
    (nop, Vins, Ldr_X, Str_X): 1,
    Ldp_X: 2,
    St4: 5,
    St3: 3,
    St2: 2,
    Ld4: 9,
    Ld3: 6,
    Ld2: 4,
    vxtn: 1,
    vshrn: 2,
    vshli: 2,
    (fcsel_dform): 1,
    (VecToGprMov, Mov_xtov_d): 1,
    (movk_imm, mov, mov_imm, movw_imm): 1,
    (d_stp_stack_with_inc, d_str_stack_with_inc): 1,
    (Stp_X, w_stp_with_imm_sp, x_str_sp_imm): 1,
    (x_ldr_stack_imm, ldr_const): 1,
    (ldr_sxtw_wform): 3,
    (lsr, lsr_wform, ror): 1,
    (umull_wform, mul_wform, umaddl_wform): 1,
    (and_twoarg, and_imm, and_imm_wform): 1,
    (
        add,
        add_imm,
        add2,
        add_lsr,
        add_lsl,
        add_sp_imm,
        adcs_to_zero,
        adcs_zero2,
        adcs_zero_r_to_zero,
        cmn,
    ): 1,
    (cmp_xzr2, cmp_imm, sub, subs_wform, asr_wform, sbcs_zero_to_zero, ngc_zero): 1,
    (bfi, ubfx): 1,
    VShiftImmediateRounding: 1,
    VShiftImmediateBasic: 1,
    (vsri): 1,
    (vusra): 1,
    (vand, vbic, veor): 1,
    (vuzp1, vuzp2): 1,
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc, q_ldr1_post_inc): 1,
    (b_ldr_stack_with_inc, d_ldr_stack_with_inc): 1,
    (mov_d01, mov_b00): 1,
    (vzip1, vzip2): 1,
    (eor_wform): 1,
    (eor, bic, eor_ror, bic_ror): 1,
}

default_latencies = {
    vmov: 2,
    is_qform_form_of([vadd, vsub]): 3,
    is_dform_form_of([vadd, vsub]): 2,
    (trn1, trn2, ASimdCompare): 2,
    (
        vmul,
        vmul_lane,
        vmls,
        vmls_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        Vmull,
        Vmlal,
    ): 4,
    (Ldr_Q, Str_Q): 4,
    St4: 5,
    St3: 3,
    St2: 2,
    # TODO: Add distinction between Q/D and B/H vs. D/S
    Ld2: 6,
    Ld3: 8,
    Ld4: 11,
    vxtn: 2,
    vshrn: 2,
    vshli: 2,
    (Str_X, Ldr_X): 4,
    Ldp_X: 4,
    (Vins, umov_d): 2,
    (tst_wform): 1,
    (fcsel_dform): 2,
    (VecToGprMov, Mov_xtov_d): 2,
    (movk_imm, mov, mov_imm, movw_imm): 1,
    (d_stp_stack_with_inc, d_str_stack_with_inc): 1,
    (Stp_X, w_stp_with_imm_sp, x_str_sp_imm): 1,
    (x_ldr_stack_imm, ldr_const): 3,
    (ldr_sxtw_wform): 5,
    (lsr, lsr_wform): 1,
    (umull_wform, mul_wform, umaddl_wform): 3,
    (and_imm, and_imm_wform): 1,
    (add2, add_lsr, add_lsl, add_sp_imm): 2,
    (
        add,
        add_imm,
        adcs_to_zero,
        adcs_zero_r_to_zero,
        adcs_zero2,
        cmn,
        sub,
        subs_wform,
        asr_wform,
        sbcs_zero_to_zero,
        cmp_xzr2,
        ngc_zero,
        cmp_imm,
    ): 1,
    (bfi, ubfx): 2,
    VShiftImmediateRounding: 3,
    VShiftImmediateBasic: 2,
    (vsri): 2,
    (vusra): 3,
    (vand, vbic, veor): 1,
    (vuzp1, vuzp2): 2,
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc, q_ldr1_post_inc): 3,
    (b_ldr_stack_with_inc, d_ldr_stack_with_inc): 3,
    (mov_d01, mov_b00): 2,
    (vzip1, vzip2): 2,
    (eor_wform): 1,
    # According to SWOG, this is 2 cycles, byt if the output is used as a
    # _non-shifted_ input to the next instruction, the effective latency
    # seems to be 1 cycle. See https://eprint.iacr.org/2022/1243.pdf
    (eor_ror, bic_ror): 1,
    (ror, eor, bic): 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    if (
        instclass_dst in [trn1, trn2, vzip1, vzip2, vuzp1, vuzp2, fcsel_dform]
        and latency < 3
    ):
        latency += 1

    if [instclass_src, instclass_dst] in [
        [lsr, mul_wform],
        [lsr, umaddl_wform],
        [vbic, vusra],
    ]:
        latency += 1

    if (
        instclass_src == vmlal
        and instclass_dst == vmlal
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

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

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
# Experimental model for high-end Apple M1 CPU
# Based on data by https://dougallj.github.io/applecpu/firestorm.html
#

from enum import Enum
from itertools import combinations, product


from slothy.targets.aarch64.aarch64_neon import (
    lookup_multidict,
    find_class,
    Ldr_X,
    Str_X,
    Ldr_Q,
    Str_Q,
    vuzp1,
    vuzp2,
    vzip1,
    vmov,
    vand,
    vadd,
    VShiftImmediateBasic,
    vusra,
    vmul,
    vmlal,
    vmull,
    vmla,
    vmla_lane,
    vmls,
    vmls_lane,
    vqrdmulh,
    vqrdmulh_lane,
    vqdmulh_lane,
    ASimdCompare,
    umov_d,
    mov_d,
    mov_d01,
    mov_b00,
    fcsel_dform,
    St4,
    Ld4,
    St3,
    Ld3,
    q_ldr1_stack,
    Q_Ld2_Lane_Post_Inc,
    Mov_xtov_d,
    d_stp_stack_with_inc,
    d_str_stack_with_inc,
    b_ldr_stack_with_inc,
    d_ldr_stack_with_inc,
    is_qform_form_of,
    is_dform_form_of,
    add,
    add_imm,
    add_lsl,
    add_lsr,
    add2,
    umull_wform,
    mul_wform,
    umaddl_wform,
    lsr,
    bic,
    add_sp_imm,
    and_imm,
    movk_imm,
    sub,
    mov,
    asr_wform,
    and_imm_wform,
    lsr_wform,
    eor_wform,
    bfi,
    nop,
    tst_wform,
    subs_wform,
    x_stp_with_imm_sp,
    w_stp_with_imm_sp,
    ldr_const,
    ldr_sxtw_wform,
    vmul_lane,
    vbic,
    VShiftImmediateRounding,
    vsub,
    trn1,
    trn2,
    Vins,
    vzip2,
    x_ldr_stack_imm,
    x_str_sp_imm,
    vsrshr,
    ubfx,
)

issue_rate = 8


class ExecutionUnit(Enum):
    SCALAR_I0 = (0,)
    SCALAR_I1 = (1,)
    SCALAR_I2 = (2,)
    SCALAR_I3 = (3,)
    SCALAR_I4 = (4,)
    SCALAR_I5 = (5,)
    SCALAR_M0 = (4,)  # Overlaps with fifth I pipeline
    SCALAR_M1 = (5,)  # Overlaps with sixth I pipeline
    SU0 = (6,)
    LSU0 = (7,)
    LU0 = (8,)
    LU1 = (9,)
    VEC0 = (10,)
    VEC1 = (11,)
    VEC2 = (12,)
    VEC3 = (13,)

    def __repr__(self):
        return self.name

    def I():  # noqa: E743
        return [
            ExecutionUnit.SCALAR_I0,
            ExecutionUnit.SCALAR_I1,
            ExecutionUnit.SCALAR_I2,
            ExecutionUnit.SCALAR_I3,
            ExecutionUnit.SCALAR_I4,
            ExecutionUnit.SCALAR_I5,
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
        return [ExecutionUnit.LSU0]

    def LOAD():
        return [ExecutionUnit.LSU0, ExecutionUnit.LU0, ExecutionUnit.LU1]

    def STORE():
        return [ExecutionUnit.LSU0, ExecutionUnit.SU0]


#  Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.


def add_further_constraints(slothy):
    _ = slothy


def has_min_max_objective(config):
    return False


def get_min_max_objective(slothy):
    return


execution_units = {
    # Neon Arithmetic
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
        vmull,
        vmlal,
        vsrshr,
        vusra,
        vand,
        vbic,
        ASimdCompare,
        VShiftImmediateBasic,
        VShiftImmediateRounding,
    ): ExecutionUnit.V(),
    (vadd, vsub, trn1, trn2): ExecutionUnit.V(),
    Vins: ExecutionUnit.V(),  # guessed
    (umov_d, mov_d): ExecutionUnit.V(),  # guessed
    (mov_d01, mov_b00): ExecutionUnit.V(),  # guessed
    fcsel_dform: [ExecutionUnit.VEC2, ExecutionUnit.VEC3],
    # Neon Load/Store
    St4: list(map(list, product(ExecutionUnit.STORE(), ExecutionUnit.V()))),
    Ld4: [
        list(ll[0] + (ll[1],))
        for ll in map(
            list, (product(combinations(ExecutionUnit.LOAD(), 2), ExecutionUnit.V()))
        )
    ],
    St3: list(map(list, product(ExecutionUnit.STORE(), ExecutionUnit.V()))),
    Ld3: [
        list(ll[0] + (ll[1],))
        for ll in map(
            list, (product(combinations(ExecutionUnit.LOAD(), 2), ExecutionUnit.V()))
        )
    ],
    (Ldr_Q): ExecutionUnit.LOAD(),
    (Str_Q): ExecutionUnit.STORE(),
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc): list(
        map(list, product(ExecutionUnit.V(), ExecutionUnit.LOAD()))
    ),  # ?
    Mov_xtov_d: ExecutionUnit.LOAD(),  # based on FMOV
    # guessed
    d_stp_stack_with_inc: list(map(list, combinations(ExecutionUnit.STORE(), 2))),
    d_str_stack_with_inc: [
        list(ll[0] + (ll[1],))
        for ll in map(
            list, (product(combinations(ExecutionUnit.STORE(), 2), ExecutionUnit.I()))
        )
    ],
    b_ldr_stack_with_inc: ExecutionUnit.LOAD(),  # for LDR (unsigned offset, S)
    d_ldr_stack_with_inc: ExecutionUnit.LOAD(),  # for LDR (unsigned offset, S)
    is_qform_form_of(vmov): [],  # TODO: Can this be empty?
    is_dform_form_of(vmov): ExecutionUnit.V(),
    (vzip1, vzip2, vuzp1, vuzp2): ExecutionUnit.V(),
    # Arithmetic
    (add, add_imm): ExecutionUnit.I(),
    (add_lsl, add_lsr, add2): list(map(list, combinations(ExecutionUnit.I(), 2))),
    (umull_wform, mul_wform): ExecutionUnit.M(),
    (umaddl_wform): ExecutionUnit.SCALAR_I5,
    (
        lsr,
        bic,
        ubfx,
        add_sp_imm,
        and_imm,
        movk_imm,
        sub,
        mov,
        asr_wform,
        and_imm_wform,
        lsr_wform,
        eor_wform,
    ): ExecutionUnit.I(),
    (bfi): ExecutionUnit.SCALAR_I5,
    (nop): [],
    (tst_wform, subs_wform): [
        ExecutionUnit.SCALAR_I0,
        ExecutionUnit.SCALAR_I1,
        ExecutionUnit.SCALAR_I2,
    ],
    # Load/Store
    (Ldr_X, x_ldr_stack_imm, ldr_sxtw_wform, ldr_const): ExecutionUnit.LOAD(),
    (Str_X, x_str_sp_imm): ExecutionUnit.STORE(),
    (x_stp_with_imm_sp, w_stp_with_imm_sp): ExecutionUnit.STORE(),
}

# NOTE: Throughput as defined in https://dougallj.github.io/applecpu/firestorm.html
# refers to "cycles per instruction", as opposed to "instructions per cycle"
# from the Arm SWOGs.
# Based on the data from https://dougallj.github.io/applecpu/firestorm.html, the
# inverse throughput can be obtained by multiplying the throughput `TP` given in
# the tables by the number of execution units able to execute the given instruction.

inverse_throughput = {
    # Neon Arithmetic
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
        vmull,
        vmlal,
        vusra,
        vand,
        vbic,
        ASimdCompare,
        VShiftImmediateRounding,
        VShiftImmediateBasic,
    ): 1,
    (vadd, vsub, trn1, trn2): 1,
    Vins: 1,
    (umov_d, mov_d): 2,  # guessed
    (mov_d01, mov_b00): 1,  # guessed
    fcsel_dform: 1,
    # Neon Load/Store
    (Ldr_Q, Str_Q): 1,
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc): 3,  # guessed
    St4: 5,  # guessed
    Ld4: 5,  # guessed
    St3: 4,  # guessed
    Ld3: 4,  # guessed
    Mov_xtov_d: 1,  # based on FMOV
    d_stp_stack_with_inc: 2,  # guessed
    d_str_stack_with_inc: 1,
    b_ldr_stack_with_inc: 1,  # for LDR (unsigned offset, S)
    d_ldr_stack_with_inc: 1,  # for LDR (unsigned offset, S)
    is_qform_form_of(vmov): 1,  # guessed
    is_dform_form_of(vmov): 1,
    (vzip1, vzip2, vuzp1, vuzp2): 1,
    # Arithmetic
    (add, add_imm): 1,
    (add_lsl, add_lsr, add2): 1,
    (umull_wform, mul_wform): 1,
    (umaddl_wform): 1,
    (
        lsr,
        bic,
        ubfx,
        add_sp_imm,
        and_imm,
        movk_imm,
        sub,
        mov,
        asr_wform,
        and_imm_wform,
        lsr_wform,
        eor_wform,
    ): 1,
    (bfi): 1,
    (nop): 1,  # guessed
    (tst_wform, subs_wform): 1,
    # Load/Store
    (Ldr_X, x_ldr_stack_imm, ldr_sxtw_wform, ldr_const): 1,
    (Str_X, x_str_sp_imm): 1,
    (x_stp_with_imm_sp, w_stp_with_imm_sp): 1,
}


default_latencies = {
    # Neon Arithmetic
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
        vmull,
        vmlal,
        vusra,
    ): 3,
    VShiftImmediateRounding: 3,
    (vand, vbic, ASimdCompare, VShiftImmediateBasic): 2,
    (vadd, vsub, trn1, trn2): 2,
    Vins: 2,  # or something less than 13
    (umov_d, mov_d): 5,  # <= 10
    (mov_d01, mov_b00): 2,  # guessed
    fcsel_dform: 2,
    # Neon Load/Store
    (Ldr_Q): 4,  # probably something less than 10
    (Str_Q): 4,  # guessed
    St4: 4,  # guessed
    Ld4: 6,  # guessed
    St3: 3,  # guessed
    Ld3: 5,  # guessed
    (q_ldr1_stack, Q_Ld2_Lane_Post_Inc): 4,  # guessed
    Mov_xtov_d: 5,  # <=10, based on FMOV
    d_stp_stack_with_inc: 4,  # guessed
    d_str_stack_with_inc: 4,  # guessed
    b_ldr_stack_with_inc: 4,  # <=9, for LDR (unsigned offset, S)
    d_ldr_stack_with_inc: 4,  # <=9, for LDR (unsigned offset, S)
    is_qform_form_of(vmov): 0,
    is_dform_form_of(vmov): 2,
    (vzip1, vzip2, vuzp1, vuzp2): 2,
    # Arithmetic
    (add, add_imm): 1,
    (add_lsl, add_lsr, add2): 2,
    (umull_wform, mul_wform): 3,
    (umaddl_wform): 3,
    (
        lsr,
        bic,
        ubfx,
        add_sp_imm,
        and_imm,
        movk_imm,
        sub,
        mov,
        asr_wform,
        and_imm_wform,
        lsr_wform,
        eor_wform,
    ): 1,
    (bfi): 1,
    (nop): 0,  # TODO: Does this work?
    (tst_wform, subs_wform): 1,
    # Load/Store
    (Ldr_X, x_ldr_stack_imm): 3,  # something less than 5
    (Str_X, x_str_sp_imm): 4,  # guessed
    (x_stp_with_imm_sp, w_stp_with_imm_sp): 4,  # guessed
    (ldr_const): 3,  # guessed
    (ldr_sxtw_wform): 3,  # <= 4
}


def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    if (
        instclass_src == umaddl_wform
        and instclass_dst == umaddl_wform
        and src.args_out[0] == dst.args_in[2]
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
    else:
        return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

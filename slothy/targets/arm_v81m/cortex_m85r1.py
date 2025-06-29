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

# ##################################################################################
# ################################ NOTE ############################################
# ##################################################################################
#                                                                                  #
# WARNING: The data in this module is approximate and may contain errors.          #
#          They are _NOT_ an official software optimization guide for Cortex-M85.  #
#                                                                                  #
# ##################################################################################
# ##################################################################################
# ##################################################################################

from enum import Enum
from slothy.targets.arm_v81m.arch_v81m import (
    find_class,
    lookup_multidict,
    nop,
    ldr,
    ldr_with_writeback,
    ldr_with_post,
    mov_imm,
    mvn_imm,
    mov,
    add,
    sub,
    pkhbt,
    add_imm,
    sub_imm,
    vshrnb,
    vshrnt,
    vrshr,
    vrshl,
    vshr,
    vshl,
    vshl_T3,
    vshlc,
    vshllb,
    vshllt,
    vsli,
    vmovlb,
    vmovlt,
    vrev16,
    vrev32,
    vrev64,
    vdup,
    vmov_imm,
    vmov_double_v2r,
    vadd_sv,
    vadd_vv,
    vsub,
    vsub_T2,
    vhadd,
    vhsub,
    vhcadd,
    vand,
    vbic,
    vbic_nodt,
    vorr,
    veor,
    veor_nodt,
    vmulh,
    vmul_T1,
    vmul_T2,
    vmullb,
    vmullt,
    vqrdmulh_T1,
    vqrdmulh_T2,
    vqdmlah,
    vqrdmlah,
    vqdmladhx,
    vqdmlsdh,
    vqdmulh_vv,
    vqdmulh_sv,
    vmla,
    vfma,
    vmulf_T1,
    vmulf_T2,
    ldrd,
    ldrd_no_imm,
    ldrd_with_writeback,
    ldrd_with_post,
    strd,
    strd_with_writeback,
    strd_with_post,
    restored,
    restore,
    saved,
    save,
    qsave,
    qrestore,
    vldrb,
    vldrb_no_imm,
    vldrb_with_writeback,
    vldrb_with_post,
    vldrh,
    vldrh_no_imm,
    vldrh_with_writeback,
    vldrh_with_post,
    vldrw,
    vldrw_no_imm,
    vldrw_with_writeback,
    vldrw_with_post,
    vldrw_gather,
    vldrw_gather_uxtw,
    vldrb_gather,
    vldrb_gather_uxtw,
    vldrh_gather,
    vldrh_gather_uxtw,
    vld20,
    vld21,
    vld20_with_writeback,
    vld21_with_writeback,
    vld40,
    vld41,
    vld42,
    vld43,
    vld40_with_writeback,
    vld41_with_writeback,
    vld42_with_writeback,
    vld43_with_writeback,
    vstrw,
    vstrw_no_imm,
    vstrw_with_writeback,
    vstrw_with_post,
    vstrw_scatter,
    vstrw_scatter_uxtw,
    vst20,
    vst21,
    vst20_with_writeback,
    vst21_with_writeback,
    vst40,
    vst41,
    vst42,
    vst43,
    vst40_with_writeback,
    vst41_with_writeback,
    vst42_with_writeback,
    vst43_with_writeback,
    vcmul,
    vcmla,
    vcadd,
    vaddf,
    vsubf,
    vsubf_T2,
    vcaddf,
)

issue_rate = 1
llvm_mca_target = "cortex-m85"


class ExecutionUnit(Enum):
    SCALAR = (0,)
    # LSU : load / store can overlap
    LOAD = (1,)
    STORE = (2,)
    STACK_LD = (1,)
    STACK_ST = (2,)
    # Pipe A
    VEC_INT = (3,)
    VEC_FPADD = (3,)
    VEC_IVMINMAX = (3,)
    VEC_SHFT = (3,)
    VEC_VMOVLN = (3,)
    # VMOV + Bitwise can go pipe A or B
    VEC_VMOVA = (3,)
    VEC_BITWA = (3,)
    # Pipe B
    VEC_MUL = (4,)
    VEC_FPU = (4,)
    VEC_FPMUL = (4,)
    VEC_FPCNV = (4,)
    VEC_FPCMP = (4,)
    # VMOV + Bitwise can go pipe A or B
    VEC_VMOVB = (4,)
    VEC_BITWB = (4,)
    # Pipe C
    VEC_PREDIC = (5,)
    VEC_CMP = (5,)

    def __repr__(self):
        return self.name


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    t0_t1 = slothy.get_inst_pairs(
        cond_fst=lambda t: not t.inst.is_load_store_instruction(),
        cond_snd=lambda t: t.inst.is_vector_load(),
    )
    t2_t3 = slothy.get_inst_pairs(
        cond_fst=lambda t: t.inst.is_vector_store(),
        cond_snd=lambda t: t.inst.is_vector_load(),
    )
    for t0, t1 in t0_t1:
        for t2, t3 in t2_t3:
            b = [slothy._NewBoolVar("") for _ in range(0, 3)]
            slothy._AddAtLeastOne(b)
            slothy._Add(t1.program_start_var != t0.program_start_var + 1).OnlyEnforceIf(
                b[0]
            )
            slothy._Add(t2.program_start_var != t1.program_start_var + 1).OnlyEnforceIf(
                b[1]
            )
            slothy._Add(t3.program_start_var != t2.program_start_var + 1).OnlyEnforceIf(
                b[2]
            )

    for t0, t1 in slothy.get_inst_pairs():
        c0 = find_class(t0.inst)
        c1 = find_class(t1.inst)
        # The intent is to have the 1st line capture VFMA-like instructions
        # blocking the MAC pipe, while the second should capture instructions of
        # different kind using this pipe, too.
        if execution_units[c0] == [
            [ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]
        ] and (
            execution_units[c1] != [[ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]]
            and (
                execution_units[c1] == ExecutionUnit.VEC_FPMUL
                or execution_units[c1] == ExecutionUnit.VEC_FPADD
            )
        ):
            b0 = slothy._NewBoolVar("")
            b1 = slothy._NewBoolVar("")
            slothy._AddAtLeastOne(
                [b0, b1]
            )  # Create vars distinguishing t1 < t0 and t1 >= t0
            slothy._Add(t1.program_start_var >= t0.program_start_var + 4).OnlyEnforceIf(
                [b0]
            )
            slothy._Add(t1.program_start_var < t0.program_start_var).OnlyEnforceIf([b1])


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False


def get_min_max_objective(slothy):
    # to be completed
    return


execution_units = {
    nop: ExecutionUnit.SCALAR,
    ldr: ExecutionUnit.LOAD,
    ldr_with_writeback: ExecutionUnit.LOAD,
    ldr_with_post: ExecutionUnit.LOAD,
    mov_imm: ExecutionUnit.SCALAR,
    mvn_imm: ExecutionUnit.SCALAR,
    mov: ExecutionUnit.SCALAR,
    add: ExecutionUnit.SCALAR,
    sub: ExecutionUnit.SCALAR,
    pkhbt: ExecutionUnit.SCALAR,
    add_imm: ExecutionUnit.SCALAR,
    sub_imm: ExecutionUnit.SCALAR,
    vshrnb: ExecutionUnit.VEC_SHFT,
    vshrnt: ExecutionUnit.VEC_SHFT,
    vrshr: ExecutionUnit.VEC_SHFT,
    vrshl: ExecutionUnit.VEC_SHFT,
    vshr: ExecutionUnit.VEC_SHFT,
    vshl: ExecutionUnit.VEC_SHFT,
    vshl_T3: ExecutionUnit.VEC_SHFT,
    vshlc: ExecutionUnit.VEC_SHFT,
    vshllb: ExecutionUnit.VEC_SHFT,
    vshllt: ExecutionUnit.VEC_SHFT,
    vsli: ExecutionUnit.VEC_SHFT,
    vmovlb: ExecutionUnit.VEC_VMOVLN,
    vmovlt: ExecutionUnit.VEC_VMOVLN,
    vrev16: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vrev32: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vrev64: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vdup: ExecutionUnit.VEC_INT,
    vmov_imm: [ExecutionUnit.VEC_VMOVA, ExecutionUnit.VEC_VMOVB],
    vmov_double_v2r: [ExecutionUnit.VEC_VMOVA, ExecutionUnit.VEC_VMOVB],
    vadd_sv: ExecutionUnit.VEC_INT,
    vadd_vv: ExecutionUnit.VEC_INT,
    vsub: ExecutionUnit.VEC_INT,
    vsub_T2: ExecutionUnit.VEC_INT,
    vhadd: ExecutionUnit.VEC_INT,
    vhsub: ExecutionUnit.VEC_INT,
    vhcadd: ExecutionUnit.VEC_INT,
    vand: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vbic: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vbic_nodt: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vorr: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    veor: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    veor_nodt: [ExecutionUnit.VEC_BITWA, ExecutionUnit.VEC_BITWB],
    vmulh: ExecutionUnit.VEC_MUL,
    vmul_T1: ExecutionUnit.VEC_MUL,
    vmul_T2: ExecutionUnit.VEC_MUL,
    vmullb: ExecutionUnit.VEC_MUL,
    vmullt: ExecutionUnit.VEC_MUL,
    vqrdmulh_T1: ExecutionUnit.VEC_MUL,
    vqrdmulh_T2: ExecutionUnit.VEC_MUL,
    vqdmlah: ExecutionUnit.VEC_MUL,
    vqrdmlah: ExecutionUnit.VEC_MUL,
    vqdmladhx: ExecutionUnit.VEC_MUL,
    vqdmlsdh: ExecutionUnit.VEC_MUL,
    vqdmulh_vv: ExecutionUnit.VEC_MUL,
    vqdmulh_sv: ExecutionUnit.VEC_MUL,
    vmla: ExecutionUnit.VEC_MUL,
    vfma: [  # uses both MUL/ADD pipes
        [ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]
    ],
    vmulf_T1: ExecutionUnit.VEC_FPMUL,
    vmulf_T2: ExecutionUnit.VEC_FPMUL,
    ldrd: ExecutionUnit.LOAD,
    ldrd_no_imm: ExecutionUnit.LOAD,
    ldrd_with_writeback: ExecutionUnit.LOAD,
    ldrd_with_post: ExecutionUnit.LOAD,
    strd: ExecutionUnit.STORE,
    strd_with_writeback: ExecutionUnit.STORE,
    strd_with_post: ExecutionUnit.STORE,
    restored: ExecutionUnit.STACK_LD,
    restore: ExecutionUnit.STACK_LD,
    saved: ExecutionUnit.STACK_ST,
    save: ExecutionUnit.STACK_ST,
    qsave: ExecutionUnit.STACK_ST,
    qrestore: ExecutionUnit.STACK_LD,
    vldrb: ExecutionUnit.LOAD,
    vldrb_no_imm: ExecutionUnit.LOAD,
    vldrb_with_writeback: ExecutionUnit.LOAD,
    vldrb_with_post: ExecutionUnit.LOAD,
    vldrh: ExecutionUnit.LOAD,
    vldrh_no_imm: ExecutionUnit.LOAD,
    vldrh_with_writeback: ExecutionUnit.LOAD,
    vldrh_with_post: ExecutionUnit.LOAD,
    vldrw: ExecutionUnit.LOAD,
    vldrw_no_imm: ExecutionUnit.LOAD,
    vldrw_with_writeback: ExecutionUnit.LOAD,
    vldrw_with_post: ExecutionUnit.LOAD,
    vldrw_gather: ExecutionUnit.LOAD,
    vldrw_gather_uxtw: ExecutionUnit.LOAD,
    vldrb_gather: ExecutionUnit.LOAD,
    vldrb_gather_uxtw: ExecutionUnit.LOAD,
    vldrh_gather: ExecutionUnit.LOAD,
    vldrh_gather_uxtw: ExecutionUnit.LOAD,
    vld20: ExecutionUnit.LOAD,
    vld21: ExecutionUnit.LOAD,
    vld20_with_writeback: ExecutionUnit.LOAD,
    vld21_with_writeback: ExecutionUnit.LOAD,
    vld40: ExecutionUnit.LOAD,
    vld41: ExecutionUnit.LOAD,
    vld42: ExecutionUnit.LOAD,
    vld43: ExecutionUnit.LOAD,
    vld40_with_writeback: ExecutionUnit.LOAD,
    vld41_with_writeback: ExecutionUnit.LOAD,
    vld42_with_writeback: ExecutionUnit.LOAD,
    vld43_with_writeback: ExecutionUnit.LOAD,
    vstrw: ExecutionUnit.STORE,
    vstrw_no_imm: ExecutionUnit.STORE,
    vstrw_with_writeback: ExecutionUnit.STORE,
    vstrw_with_post: ExecutionUnit.STORE,
    vstrw_scatter: ExecutionUnit.STORE,
    vstrw_scatter_uxtw: ExecutionUnit.STORE,
    vst20: ExecutionUnit.STORE,
    vst21: ExecutionUnit.STORE,
    vst20_with_writeback: ExecutionUnit.STORE,
    vst21_with_writeback: ExecutionUnit.STORE,
    vst40: ExecutionUnit.STORE,
    vst41: ExecutionUnit.STORE,
    vst42: ExecutionUnit.STORE,
    vst43: ExecutionUnit.STORE,
    vst40_with_writeback: ExecutionUnit.STORE,
    vst41_with_writeback: ExecutionUnit.STORE,
    vst42_with_writeback: ExecutionUnit.STORE,
    vst43_with_writeback: ExecutionUnit.STORE,
    vcmul: ExecutionUnit.VEC_FPMUL,
    vcmla: [  # uses both MUL/ADD pipes
        [ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]
    ],
    vaddf: ExecutionUnit.VEC_FPADD,
    vsubf: ExecutionUnit.VEC_FPADD,
    vsubf_T2: ExecutionUnit.VEC_FPADD,
    vcaddf: ExecutionUnit.VEC_FPADD,
}

inverse_throughput = {
    (
        nop,
        mov_imm,
        mvn_imm,
        mov,
        add,
        sub,
        pkhbt,
        add_imm,
        sub_imm,
        vmov_imm,
        vmov_double_v2r,
        ldr,
        ldr_with_writeback,
        ldr_with_post,
        ldrd,
        ldrd_no_imm,
        ldrd_with_writeback,
        ldrd_with_post,
        strd,
        strd_with_writeback,
        strd_with_post,
        restored,
        restore,
        saved,
        save,
    ): 1,
    (
        vrshr,
        vrshl,
        vshrnb,
        vshrnt,
        vdup,
        vshr,
        vshl,
        vshl_T3,
        vshlc,
        vshllb,
        vshllt,
        vsli,
        vmovlb,
        vmovlt,
        vrev16,
        vrev32,
        vrev64,
        vadd_sv,
        vadd_vv,
        vsub,
        vsub_T2,
        vhadd,
        vhsub,
        vhcadd,
        vand,
        vbic,
        vbic_nodt,
        vorr,
        veor,
        veor_nodt,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullb,
        vmullt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_sv,
        vqdmulh_vv,
        vqdmladhx,
        vqdmlsdh,
        vmla,
        vstrw,
        vstrw_no_imm,
        vstrw_with_writeback,
        vstrw_with_post,
        vstrw_scatter,
        vstrw_scatter_uxtw,
        qsave,
        qrestore,
        vldrb,
        vldrb_no_imm,
        vldrb_with_writeback,
        vldrb_with_post,
        vldrh,
        vldrh_no_imm,
        vldrh_with_writeback,
        vldrh_with_post,
        vldrw,
        vldrw_no_imm,
        vldrw_with_writeback,
        vldrw_with_post,
        vldrw_gather,
        vldrw_gather_uxtw,
        vldrb_gather,
        vldrb_gather_uxtw,
        vldrh_gather,
        vldrh_gather_uxtw,
        vld20,
        vld21,
        vld20_with_writeback,
        vld21_with_writeback,
        vld40,
        vld41,
        vld42,
        vld43,
        vld40_with_writeback,
        vld41_with_writeback,
        vld42_with_writeback,
        vld43_with_writeback,
        vst20,
        vst21,
        vst20_with_writeback,
        vst21_with_writeback,
        vst40,
        vst41,
        vst42,
        vst43,
        vst40_with_writeback,
        vst41_with_writeback,
        vst42_with_writeback,
        vst43_with_writeback,
        vcmul,
        vcadd,
        vaddf,
        vcaddf,
        vsubf,
        vsubf_T2,
        vhcadd,
    ): 2,
    (vmulf_T1, vmulf_T2): 2,
    # MACs
    (vfma, vcmla): 2,
}

default_latencies = {
    (
        ldrd,
        ldrd_no_imm,
        ldrd_with_post,
        ldrd_with_writeback,
    ): 2,
    restored: 2,
    (
        ldr,
        ldr_with_writeback,
        ldr_with_post,
        mov_imm,
        mvn_imm,
        mov,
        add,
        sub,
        pkhbt,
        add_imm,
        sub_imm,
        vshr,
        vshl,
        vshl_T3,
        vshlc,
        vrev16,
        vrev32,
        vrev64,
        vdup,
        vmov_imm,
        vmov_double_v2r,
        vadd_vv,
        vadd_sv,
        vsub,
        vsub_T2,
        vhadd,
        vhsub,
        vhcadd,
        vand,
        vbic,
        vbic_nodt,
        vorr,
        veor,
        veor_nodt,
        qsave,
        save,
        qrestore,
        restore,
        vldrb,
        vldrb_no_imm,
        vldrb_with_writeback,
        vldrb_with_post,
        vldrh,
        vldrh_no_imm,
        vldrh_with_writeback,
        vldrh_with_post,
        vldrw,
        vldrw_no_imm,
        vldrw_with_writeback,
        vldrw_with_post,
        vldrw_gather,
        vldrw_gather_uxtw,
        vldrb_gather,
        vldrb_gather_uxtw,
        vldrh_gather,
        vldrh_gather_uxtw,
        vst20,
        vst21,
        vst20_with_writeback,
        vst21_with_writeback,
        vst40,
        vst41,
        vst42,
        vst43,
        vst40_with_writeback,
        vst41_with_writeback,
        vst42_with_writeback,
        vst43_with_writeback,
    ): 1,
    (
        vrshr,
        vrshl,
        vshrnb,
        vshrnt,
        vshllb,
        vshllt,
        vsli,
        vmovlb,
        vmovlt,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullb,
        vmullt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_sv,
        vqdmulh_vv,
        vqdmladhx,
        vqdmlsdh,
        vmla,
        vcadd,
        vaddf,
        vcaddf,
        vsubf,
        vsubf_T2,
        vhcadd,
    ): 2,
    (vmulf_T1, vmulf_T2, vcmul): 3,
    (vld20, vld21): 4,
    (vld20_with_writeback, vld21_with_writeback): 4,
    (vld40, vld41, vld42, vld43): 4,
    (
        vld40_with_writeback,
        vld41_with_writeback,
        vld42_with_writeback,
        vld43_with_writeback,
    ): 4,
    (vfma, vcmla): 4,
}


def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    default_latency = lookup_multidict(default_latencies, src)

    #
    # Check for latency exceptions
    #

    # VMULx -> VSTR has single cycle latency
    if instclass_dst in [
        vstrw,
        vstrw_no_imm,
        vstrw_with_writeback,
        vstrw_with_post,
        vstrw_scatter,
        vstrw_scatter_uxtw,
        qsave,
    ] and instclass_src in [
        vmul_T1,
        vmul_T2,
        vmullb,
        vmullt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_vv,
        vqdmulh_sv,
        vmla,
        vqdmladhx,
        vqdmlsdh,
        vcadd,
        vaddf,
        vsubf,
        vsubf_T2,
        vmulf_T1,
        vmulf_T2,
        vcaddf,
    ]:
        return 1

    # VFMA -> VSTR has 2 cycle latency
    if instclass_dst in [
        vstrw,
        vstrw_no_imm,
        vstrw_with_writeback,
        vstrw_with_post,
        vstrw_scatter,
        vstrw_scatter_uxtw,
        qsave,
    ] and instclass_src in [vcmul, vcmla, vfma]:
        return 2

    if instclass_dst in [vld21, vld21_with_writeback] and instclass_src in [
        vld20,
        vld20_with_writeback,
    ]:
        return 2

    if instclass_dst in [
        vld41,
        vld41_with_writeback,
        vld42,
        vld42_with_writeback,
        vld43,
        vld43_with_writeback,
    ] and instclass_src in [vld40, vld40_with_writeback]:
        return 2

    # Inputs to VST4x seem to have higher latency
    # Use 3 cycles as an upper bound here.
    if (
        instclass_dst
        in [
            vst40,
            vst40_with_writeback,
            vst41,
            vst41_with_writeback,
            vst42,
            vst42_with_writeback,
        ]
        or instclass_dst in [vst20, vst20_with_writeback]
    ) and instclass_src in [
        vshr,
        vshl,
        vshl_T3,
        vshlc,
        vrev16,
        vrev32,
        vrev64,
        vdup,
        vmov_imm,
        vadd_vv,
        vadd_sv,
        vsub,
        vsub_T2,
        vhadd,
        vhsub,
        vhcadd,
        vand,
        vbic,
        vbic_nodt,
        vorr,
        veor,
        veor_nodt,
        vrshr,
        vshrnb,
        vshrnt,
        vrshl,
        vshllb,
        vshllt,
        vsli,
        vmovlb,
        vmovlt,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullb,
        vmullt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_sv,
        vqdmulh_vv,
        vqdmladhx,
        vqdmlsdh,
        vmla,
        vfma,
        vmulf_T1,
        vmulf_T2,
        vcmul,
        vcmla,
        vcadd,
        vaddf,
        vsubf,
        vsubf_T2,
        vhcadd,
    ]:
        return 3

    return default_latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    else:
        return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

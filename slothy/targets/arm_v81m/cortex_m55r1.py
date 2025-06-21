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

# ################################ NOTE ########################################### #
# ################################################################################# #
# ################################################################################# #
#                                                                                   #
# WARNING: The data in this module is approximate and may contain errors.           #
#          They are _NOT_ an official software optimization guide for Cortex-M55.   #
#                                                                                   #
# ################################################################################# #
# ################################################################################# #
# ################################################################################# #

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
    vshrnt,
    vshrnb,
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
    vaddva,
    vmlaldava,
)

issue_rate = 1
llvm_mca_target = "cortex-m55"


class ExecutionUnit(Enum):
    SCALAR = (0,)
    LOAD = (1,)
    STORE = (1,)
    VEC_INT = (2,)
    VEC_MUL = (3,)
    VEC_FPU = (3,)
    STACK = (1,)

    def __repr__(self):
        return self.name


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    _add_st_ld_hazard(slothy)


# ===============================================================#
#                   CONSTRAINT (Performance)                     #
# ----------------------------------------------------------------#
# Prevent ST-LD hazards by forbidding VSTR; XXX; VLDR            #
# This is a strict overapproximation of the hazard: there are    #
# cases where the above pattern does not stall, depending on     #
# the addresses being loaded/stored from/to                      #
# ===============================================================#
def _add_st_ld_hazard(slothy):
    if slothy.config.constraints.functional_only:
        return

    def is_st_ld_pair(instA, instB):
        if not instA.inst.is_vector_store() or not instB.inst.is_load():
            return False
        if slothy.config.constraints.st_ld_hazard_ignore_scattergather and (
            isinstance(instA, vst20)
            or isinstance(instA, vst21)
            or isinstance(instA, vst20_with_writeback)
            or isinstance(instA, vst21_with_writeback)
            or isinstance(instA, vld20)
            or isinstance(instA, vld21)
            or isinstance(instA, vld20_with_writeback)
            or isinstance(instA, vld21_with_writeback)
            or isinstance(instA, vst40)
            or isinstance(instA, vst41)
            or isinstance(instA, vst42)
            or isinstance(instA, vst43)
            or isinstance(instA, vst40_with_writeback)
            or isinstance(instA, vst41_with_writeback)
            or isinstance(instA, vst42_with_writeback)
            or isinstance(instA, vst43_with_writeback)
            or isinstance(instB, vld40)
            or isinstance(instB, vld41)
            or isinstance(instB, vld42)
            or isinstance(instB, vld43)
            or isinstance(instB, vld40_with_writeback)
            or isinstance(instB, vld41_with_writeback)
            or isinstance(instB, vld42_with_writeback)
            or isinstance(instB, vld43_with_writeback)
        ):
            return False
        if slothy.config.constraints.st_ld_hazard_ignore_stack and (
            instB.inst.is_stack_load() or instA.inst.is_stack_store()
        ):
            return False
        return True

    slothy._model.st_ld_hazard_vars = {}
    for t_st, t_ld in slothy.get_inst_pairs(cond=is_st_ld_pair):
        if t_st.is_locked and t_ld.is_locked:
            continue
        if slothy.config.constraints.st_ld_hazard:
            slothy._model.st_ld_hazard_vars[t_st, t_ld] = slothy._NewConstant(True)
        else:
            slothy._model.st_ld_hazard_vars[t_st, t_ld] = slothy._NewBoolVar("")

        slothy.logger.debug(
            f"ST-LD hazard for {t_st.inst.mnemonic} "
            f"({t_st.id}) -> {t_ld.inst.mnemonic} ({t_ld.id})"
        )

        slothy._Add(t_ld.cycle_start_var != t_st.cycle_start_var + 2).OnlyEnforceIf(
            slothy._model.st_ld_hazard_vars[t_st, t_ld]
        )


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    return all(
        [not config.constraints.st_ld_hazard, config.constraints.minimize_st_ld_hazards]
    )


def get_min_max_objective(slothy):
    if not has_min_max_objective(slothy.config):
        return
    return (slothy._model.st_ld_hazard_vars, "minimize", "ST-LD hazard risks")


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
    vshrnt: ExecutionUnit.VEC_INT,
    vshrnb: ExecutionUnit.VEC_INT,
    vrshr: ExecutionUnit.VEC_INT,
    vrshl: ExecutionUnit.VEC_INT,
    vshr: ExecutionUnit.VEC_INT,
    vshl: ExecutionUnit.VEC_INT,
    vshl_T3: ExecutionUnit.VEC_INT,
    vshlc: ExecutionUnit.VEC_INT,
    vshllb: ExecutionUnit.VEC_INT,
    vshllt: ExecutionUnit.VEC_INT,
    vsli: ExecutionUnit.VEC_INT,
    vmovlb: ExecutionUnit.VEC_INT,
    vmovlt: ExecutionUnit.VEC_INT,
    vrev16: ExecutionUnit.VEC_INT,
    vrev32: ExecutionUnit.VEC_INT,
    vrev64: ExecutionUnit.VEC_INT,
    vdup: ExecutionUnit.VEC_INT,
    vmov_imm: [ExecutionUnit.VEC_INT, ExecutionUnit.VEC_MUL],
    vmov_double_v2r: [ExecutionUnit.VEC_INT, ExecutionUnit.VEC_MUL],
    vadd_sv: ExecutionUnit.VEC_INT,
    vadd_vv: ExecutionUnit.VEC_INT,
    vsub: ExecutionUnit.VEC_INT,
    vsub_T2: ExecutionUnit.VEC_INT,
    vaddva: ExecutionUnit.VEC_INT,
    vhadd: ExecutionUnit.VEC_INT,
    vhsub: ExecutionUnit.VEC_INT,
    vhcadd: ExecutionUnit.VEC_INT,
    vand: ExecutionUnit.VEC_INT,
    vbic: ExecutionUnit.VEC_INT,
    vbic_nodt: ExecutionUnit.VEC_INT,
    vorr: ExecutionUnit.VEC_INT,
    veor: ExecutionUnit.VEC_INT,
    veor_nodt: ExecutionUnit.VEC_INT,
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
    vmlaldava: ExecutionUnit.VEC_MUL,
    vfma: ExecutionUnit.VEC_FPU,
    vmulf_T1: ExecutionUnit.VEC_FPU,
    vmulf_T2: ExecutionUnit.VEC_FPU,
    ldrd: ExecutionUnit.LOAD,
    ldrd_no_imm: ExecutionUnit.LOAD,
    ldrd_with_writeback: ExecutionUnit.LOAD,
    ldrd_with_post: ExecutionUnit.LOAD,
    strd: ExecutionUnit.STORE,
    strd_with_writeback: ExecutionUnit.STORE,
    strd_with_post: ExecutionUnit.STORE,
    restored: ExecutionUnit.STACK,
    restore: ExecutionUnit.STACK,
    saved: ExecutionUnit.STACK,
    save: ExecutionUnit.STACK,
    qsave: ExecutionUnit.STACK,
    qrestore: ExecutionUnit.STACK,
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
    vcmul: ExecutionUnit.VEC_FPU,
    vcmla: ExecutionUnit.VEC_FPU,
    vcadd: ExecutionUnit.VEC_FPU,
    vaddf: ExecutionUnit.VEC_FPU,
    vsubf: ExecutionUnit.VEC_FPU,
    vsubf_T2: ExecutionUnit.VEC_FPU,
    vcaddf: ExecutionUnit.VEC_FPU,
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
        vmlaldava,
        vaddva,
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
        vcmla,
        vcadd,
        vcaddf,
        vaddf,
        vsubf,
        vsubf_T2,
        vhcadd,
        vmulf_T1,
        vmulf_T2,
        vfma,
    ): 2,
}

default_latencies = {
    (
        ldrd,
        ldrd_no_imm,
        ldrd_with_writeback,
        ldrd_with_post,
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
        vaddva,
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
    (vld20, vld21): 2,
    (vld20_with_writeback, vld21_with_writeback): 2,
    (vld40, vld41, vld42, vld43): 2,
    (
        vld40_with_writeback,
        vld41_with_writeback,
        vld42_with_writeback,
        vld43_with_writeback,
    ): 2,
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
        vmlaldava,
        vcmul,
        vcmla,
        vcadd,
        vcaddf,
        vaddf,
        vsubf,
        vhcadd,
        vmulf_T1,
        vmulf_T2,
        vfma,
    ): 2,
    vmlaldava: 3,
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
        vcmul,
        vcmla,
        vcadd,
        vaddf,
        vsubf,
        vsubf_T2,
        vfma,
        vmulf_T1,
        vmulf_T2,
        vcaddf,
    ]:
        return 1

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

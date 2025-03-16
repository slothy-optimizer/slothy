#
# Copyright (c) 2022 Arm Limited
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
# Playground for local microarchitectural explorations
#
# The baseline is just a copy of the Cortex-M55 model without ST-LD hazard
#

from enum import Enum

from slothy.targets.arm_v81m.arch_v81m import *

issue_rate = 1


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
    # See ST-LD hazard in M55 model for an example
    return


def has_min_max_objective(slothy):
    # See minimization of ST-LD hazards in M55 model for an example
    return False


def get_min_max_objective(slothy):
    return


execution_units = {
    nop: ExecutionUnit.SCALAR,
    ldr: ExecutionUnit.LOAD,
    mov_imm: ExecutionUnit.SCALAR,
    mvn_imm: ExecutionUnit.SCALAR,
    mov: ExecutionUnit.SCALAR,
    add: ExecutionUnit.SCALAR,
    sub: ExecutionUnit.SCALAR,
    pkhbt: ExecutionUnit.SCALAR,
    add_imm: ExecutionUnit.SCALAR,
    sub_imm: ExecutionUnit.SCALAR,
    vshrnbt: ExecutionUnit.VEC_INT,
    vrshr: ExecutionUnit.VEC_INT,
    vrshl: ExecutionUnit.VEC_INT,
    vshr: ExecutionUnit.VEC_INT,
    vshl: ExecutionUnit.VEC_INT,
    vshl_T3: ExecutionUnit.VEC_INT,
    vshlc: ExecutionUnit.VEC_INT,
    vshllbt: ExecutionUnit.VEC_INT,
    vmovlbt: ExecutionUnit.VEC_INT,
    vrev: ExecutionUnit.VEC_INT,
    vdup: ExecutionUnit.VEC_INT,
    vmov_imm: [ExecutionUnit.VEC_INT, ExecutionUnit.VEC_MUL],
    vmov_double_v2r: [ExecutionUnit.VEC_INT, ExecutionUnit.VEC_MUL],
    vadd_sv: ExecutionUnit.VEC_INT,
    vadd_vv: ExecutionUnit.VEC_INT,
    vsub: ExecutionUnit.VEC_INT,
    vhadd: ExecutionUnit.VEC_INT,
    vhsub: ExecutionUnit.VEC_INT,
    vhcadd: ExecutionUnit.VEC_INT,
    vhcsub: ExecutionUnit.VEC_INT,
    vand: ExecutionUnit.VEC_INT,
    vorr: ExecutionUnit.VEC_INT,
    vmulh: ExecutionUnit.VEC_MUL,
    vmul_T1: ExecutionUnit.VEC_MUL,
    vmul_T2: ExecutionUnit.VEC_MUL,
    vmullbt: ExecutionUnit.VEC_MUL,
    vqrdmulh_T1: ExecutionUnit.VEC_MUL,
    vqrdmulh_T2: ExecutionUnit.VEC_MUL,
    vqdmlah: ExecutionUnit.VEC_MUL,
    vqrdmlah: ExecutionUnit.VEC_MUL,
    vqdmladhx: ExecutionUnit.VEC_MUL,
    vqdmlsdh: ExecutionUnit.VEC_MUL,
    vqdmulh_vv: ExecutionUnit.VEC_MUL,
    vqdmulh_sv: ExecutionUnit.VEC_MUL,
    vmla: ExecutionUnit.VEC_MUL,
    vfma: ExecutionUnit.VEC_FPU,
    vmulf_T1: ExecutionUnit.VEC_FPU,
    vmulf_T2: ExecutionUnit.VEC_FPU,
    ldrd: ExecutionUnit.LOAD,
    strd: ExecutionUnit.STORE,
    restored: ExecutionUnit.STACK,
    restore: ExecutionUnit.STACK,
    saved: ExecutionUnit.STACK,
    save: ExecutionUnit.STACK,
    qsave: ExecutionUnit.STACK,
    qrestore: ExecutionUnit.STACK,
    vldr: ExecutionUnit.LOAD,
    vldr_gather: ExecutionUnit.LOAD,
    vld2: ExecutionUnit.LOAD,
    vld4: ExecutionUnit.LOAD,
    vstr: ExecutionUnit.STORE,
    vst2: ExecutionUnit.STORE,
    vst4: ExecutionUnit.STORE,
    vcmul: ExecutionUnit.VEC_FPU,
    vcmla: ExecutionUnit.VEC_FPU,
    vcadd: ExecutionUnit.VEC_FPU,
    vaddf: ExecutionUnit.VEC_FPU,
    vsubf: ExecutionUnit.VEC_FPU,
    vcaddf: ExecutionUnit.VEC_FPU,
    vcsubf: ExecutionUnit.VEC_FPU,
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
        ldrd,
        strd,
        restored,
        restore,
        saved,
        save,
    ): 1,
    (
        vrshr,
        vrshl,
        vshrnbt,
        vdup,
        vshr,
        vshl,
        vshl_T3,
        vshlc,
        vshllbt,
        vmovlbt,
        vrev,
        vadd_sv,
        vadd_vv,
        vsub,
        vhadd,
        vhsub,
        vhcadd,
        vhcsub,
        vand,
        vorr,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullbt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_sv,
        vqdmulh_vv,
        vqdmladhx,
        vqdmlsdh,
        vmla,
        vstr,
        qsave,
        qrestore,
        vldr,
        vldr_gather,
        vld2,
        vld4,
        vst2,
        vst4,
        vcmul,
        vcmla,
        vcadd,
        vaddf,
        vsubf,
        vhcadd,
        vhcsub,
        vmulf_T1,
        vmulf_T2,
        vfma,
    ): 2,
}

default_latencies = {
    ldrd: 2,
    restored: 2,
    (
        ldr,
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
        vrev,
        vdup,
        vmov_imm,
        vmov_double_v2r,
        vadd_vv,
        vadd_sv,
        vsub,
        vhadd,
        vhsub,
        vhcadd,
        vhcsub,
        vand,
        vorr,
        qsave,
        save,
        qrestore,
        restore,
        vldr,
        vldr_gather,
        vld2,
        vld4,
        vst2,
        vst4,
    ): 1,
    (
        vrshr,
        vrshl,
        vshrnbt,
        vshllbt,
        vmovlbt,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullbt,
        vqrdmulh_T1,
        vqrdmulh_T2,
        vqdmlah,
        vqrdmlah,
        vqdmulh_sv,
        vqdmulh_vv,
        vqdmladhx,
        vqdmlsdh,
        vmla,
        vcmul,
        vcmla,
        vcadd,
        vaddf,
        vsubf,
        vhcadd,
        vhcsub,
        vmulf_T1,
        vmulf_T2,
        vfma,
    ): 2,
}


def find_class(src):
    for inst_class in Instruction.__subclasses__():
        if isinstance(src, inst_class):
            return inst_class
    raise Exception("Couldn't find instruction class")


def lookup_multidict(d, k, default=None):
    for l, v in d.items():
        if k == l:
            return v
        if isinstance(l, tuple) and k in l:
            return v
    if default is None:
        raise Exception(f"Couldn't find {k}")
    return default


def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    default_latency = lookup_multidict(default_latencies, instclass_src)

    #
    # Check for latency exceptions
    #

    # VMULx -> VSTR has single cycle latency
    if instclass_dst in [vstr, qsave] and instclass_src in [
        vmul_T1,
        vmul_T2,
        vmullbt,
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
        vfma,
        vmulf_T1,
        vmulf_T2,
        vcaddf,
    ]:
        return 1

    # Inputs to VST4x seem to have higher latency
    # Use 3 cycles as an upper bound here.
    if (instclass_dst == vst4 or instclass_dst == vst2) and instclass_src in [
        vshr,
        vshl,
        vshl_T3,
        vshlc,
        vrev,
        vdup,
        vmov_imm,
        vadd_vv,
        vadd_sv,
        vsub,
        vhadd,
        vhsub,
        vhcadd,
        vhcsub,
        vand,
        vorr,
        vrshr,
        vshrnbt,
        vrshl,
        vshllbt,
        vmovlbt,
        vmulh,
        vmul_T1,
        vmul_T2,
        vmullbt,
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
        vhcadd,
        vhcsub,
    ]:
        return 3

    return default_latency


def get_units(src):
    instclass = find_class(src)
    units = execution_units[instclass]
    if isinstance(units, list):
        return units
    else:
        return [units]


def get_inverse_throughput(src):
    instclass = find_class(src)
    return lookup_multidict(inverse_throughput, instclass)

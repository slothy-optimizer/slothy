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

########################################################################################
################################### NOTE ###############################################
########################################################################################
###                                                                                  ###
### WARNING: The data in this module is approximate and may contain errors.          ###
###          They are _NOT_ an official software optimization guide for Cortex-M85.  ###
###                                                                                  ###
########################################################################################
########################################################################################
########################################################################################

from enum import Enum
from slothy.targets.arm_v81m.arch_v81m import *

issue_rate = 1
llvm_mca_target = "cortex-m85"

class ExecutionUnit(Enum):
    SCALAR=0,
    # LSU : load / store can overlap
    LOAD=1,
    STORE=2,
    STACK_LD=1,
    STACK_ST=2,
    # Pipe A
    VEC_INT=3,
    VEC_FPADD=3,
    VEC_IVMINMAX=3,
    VEC_SHFT=3,
    VEC_VMOVLN=3,
    # VMOV + Bitwise can go pipe A or B
    VEC_VMOVA=3,
    VEC_BITWA=3,
    # Pipe B
    VEC_MUL=4,
    VEC_FPU=4,
    VEC_FPMUL=4,
    VEC_FPCNV=4,
    VEC_FPCMP=4,
    # VMOV + Bitwise can go pipe A or B
    VEC_VMOVB=4,
    VEC_BITWB=4,
    # Pipe C
    VEC_PREDIC=5,
    VEC_CMP=5,

    def __repr__(self):
        return self.name

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    for t0, t1 in slothy.get_inst_pairs():
        for t2, t3 in slothy.get_inst_pairs():
            if (not t0.inst.is_load_store_instruction() and
                t1.inst.is_vector_load()                and
                t2.inst.is_vector_store()               and
                t3.inst.is_vector_load()):
                b = [ slothy._NewBoolVar("") for _ in range(0,3) ]
                slothy._AddAtLeastOne(b)
                slothy._Add(t1.program_start_var != t0.program_start_var + 1).OnlyEnforceIf(b[0])
                slothy._Add(t2.program_start_var != t1.program_start_var + 1).OnlyEnforceIf(b[1])
                slothy._Add(t3.program_start_var != t2.program_start_var + 1).OnlyEnforceIf(b[2])


    for t0, t1 in slothy.get_inst_pairs():
        c0 = find_class(t0.inst)
        c1 = find_class(t1.inst)
        ## The intent is to have the 1st line capture VFMA-like instructions
        ## blocking the MAC pipe, while the second should capture instructions of different kind using this pipe, too.
        if execution_units[c0] == [[ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]] and \
           (execution_units[c1] != [[ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]] and
            (execution_units[c1] == ExecutionUnit.VEC_FPMUL or execution_units[c1] == ExecutionUnit.VEC_FPADD)):
            b0 = slothy._NewBoolVar("")
            b1 = slothy._NewBoolVar("")
            slothy._AddAtLeastOne([b0,b1]) # Create vars distinguishing t1 < t0 and t1 >= t0
            slothy._Add(t1.program_start_var >= t0.program_start_var + 4).OnlyEnforceIf([b0])
            slothy._Add(t1.program_start_var < t0.program_start_var).OnlyEnforceIf([b1])


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False

def get_min_max_objective(slothy):
    # to be completed
    return


execution_units = {
    nop         : ExecutionUnit.SCALAR,
    ldr         : ExecutionUnit.LOAD,
    mov_imm     : ExecutionUnit.SCALAR,
    mvn_imm     : ExecutionUnit.SCALAR,
    mov         : ExecutionUnit.SCALAR,
    add         : ExecutionUnit.SCALAR,
    sub         : ExecutionUnit.SCALAR,
    pkhbt       : ExecutionUnit.SCALAR,
    add_imm     : ExecutionUnit.SCALAR,
    sub_imm     : ExecutionUnit.SCALAR,
    vshrnbt     : ExecutionUnit.VEC_SHFT,
    vrshr       : ExecutionUnit.VEC_SHFT,
    vrshl       : ExecutionUnit.VEC_SHFT,
    vshr        : ExecutionUnit.VEC_SHFT,
    vshl        : ExecutionUnit.VEC_SHFT,
    vshl_T3     : ExecutionUnit.VEC_SHFT,
    vshlc       : ExecutionUnit.VEC_SHFT,
    vshllbt     : ExecutionUnit.VEC_SHFT,
    vmovlbt     : ExecutionUnit.VEC_VMOVLN,
    vrev        : [ ExecutionUnit.VEC_BITWA,
                        ExecutionUnit.VEC_BITWB ],
    vdup        : ExecutionUnit.VEC_INT,
    vmov_imm    : [ ExecutionUnit.VEC_VMOVA,
                    ExecutionUnit.VEC_VMOVB ],
    vmov_double_v2r : [ ExecutionUnit.VEC_VMOVA,
                        ExecutionUnit.VEC_VMOVB ],
    vadd_sv     : ExecutionUnit.VEC_INT,
    vadd_vv     : ExecutionUnit.VEC_INT,
    vsub        : ExecutionUnit.VEC_INT,
    vhadd       : ExecutionUnit.VEC_INT,
    vhsub       : ExecutionUnit.VEC_INT,
    vhcadd      : ExecutionUnit.VEC_INT,
    vhcsub      : ExecutionUnit.VEC_INT,
    vand        : [ ExecutionUnit.VEC_BITWA,
                        ExecutionUnit.VEC_BITWB ],
    vorr        : [ ExecutionUnit.VEC_BITWA,
                        ExecutionUnit.VEC_BITWB ],
    vmulh       : ExecutionUnit.VEC_MUL,
    vmul_T1     : ExecutionUnit.VEC_MUL,
    vmul_T2     : ExecutionUnit.VEC_MUL,
    vmullbt     : ExecutionUnit.VEC_MUL,
    vqrdmulh_T1 : ExecutionUnit.VEC_MUL,
    vqrdmulh_T2 : ExecutionUnit.VEC_MUL,
    vqdmlah     : ExecutionUnit.VEC_MUL,
    vqrdmlah    : ExecutionUnit.VEC_MUL,
    vqdmladhx   : ExecutionUnit.VEC_MUL,
    vqdmlsdh    : ExecutionUnit.VEC_MUL,
    vqdmulh_vv  : ExecutionUnit.VEC_MUL,
    vqdmulh_sv  : ExecutionUnit.VEC_MUL,
    vmla        : ExecutionUnit.VEC_MUL,
    vfma        : [# uses both MUL/ADD pipes
                   [ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]],
    vmulf_T1    : ExecutionUnit.VEC_FPMUL,
    vmulf_T2    : ExecutionUnit.VEC_FPMUL,
    ldrd        : ExecutionUnit.LOAD,
    strd        : ExecutionUnit.STORE,
    restored    : ExecutionUnit.STACK_LD,
    restore     : ExecutionUnit.STACK_LD,
    saved       : ExecutionUnit.STACK_ST,
    save        : ExecutionUnit.STACK_ST,
    qsave       : ExecutionUnit.STACK_ST,
    qrestore    : ExecutionUnit.STACK_LD,
    vldr        : ExecutionUnit.LOAD,
    vldr_gather : ExecutionUnit.LOAD,
    vld2        : ExecutionUnit.LOAD,
    vld4        : ExecutionUnit.LOAD,
    vstr        : ExecutionUnit.STORE,
    vst2        : ExecutionUnit.STORE,
    vst4        : ExecutionUnit.STORE,
    vcmul       : ExecutionUnit.VEC_FPMUL,
    vcmla       : [# uses both MUL/ADD pipes
                   [ExecutionUnit.VEC_FPMUL, ExecutionUnit.VEC_FPADD]],
    vaddf       : ExecutionUnit.VEC_FPADD,
    vsubf       : ExecutionUnit.VEC_FPADD,
    vcaddf      : ExecutionUnit.VEC_FPADD,
    vcsubf      : ExecutionUnit.VEC_FPADD,
}

inverse_throughput = {
    ( nop,
      mov_imm,
      mvn_imm,
      mov,
      add, sub,
      pkhbt,
      add_imm,
      sub_imm,
      vmov_imm,
      vmov_double_v2r,
      ldr, ldrd, strd,
      restored, restore,
      saved, save )    : 1,
    ( vrshr,
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
      vcadd,
      vaddf,
      vcaddf,
      vsubf,
      vhcadd,
      vhcsub )   : 2,
     ( vmulf_T1,
       vmulf_T2) : 2,
     # MACs
     ( vfma,
       vcmla)    : 2,
}

default_latencies = {
      ldrd : 2,
      restored : 2,
    ( ldr,
      mov_imm,
      mvn_imm,
      mov,
      add, sub,
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

      vst2,
      vst4 )           : 1,
    ( vrshr,
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
      vcadd,
      vaddf,
      vcaddf,
      vsubf,
      vhcadd,
      vhcsub )    : 2,
      ( vmulf_T1,
        vmulf_T2,
        vcmul)    : 3,
      ( vld2,
        vld4,
        vfma,
        vcmla)    : 4,
}

def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    default_latency = lookup_multidict(
        default_latencies, src)

    #
    # Check for latency exceptions
    #

    # VMULx -> VSTR has single cycle latency
    if instclass_dst in [vstr,qsave]            and \
       instclass_src in [ vmul_T1,
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
                          vcadd,
                          vaddf,
                          vsubf,
                          vmulf_T1,
                          vmulf_T2,
                          vcaddf ]:
        return 1

    # VFMA -> VSTR has 2 cycle latency
    if instclass_dst in [vstr,qsave]            and \
       instclass_src in [ vcmul, vcmla, vfma ]:
        return 2

    if instclass_dst == vld2 and instclass_src == vld2 and \
       {src.idx, dst.idx} == {0,1}:
        return 2

    if instclass_dst == vld4 and instclass_src == vld4 and \
       dst.idx != src.idx:
        return 2

    # Inputs to VST4x seem to have higher latency
    # Use 3 cycles as an upper bound here.
    if (instclass_dst == vst4 or instclass_dst == vst2)     and \
       instclass_src in [ vshr,
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
                          vhcsub  ]:
        return 3

    return default_latency

def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    return lookup_multidict(
        inverse_throughput, src)

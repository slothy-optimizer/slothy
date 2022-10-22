#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
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
###          They are _NOT_ an official software optimization guide for Cortex-M55.  ###
###                                                                                  ###
########################################################################################
########################################################################################
########################################################################################

import logging
import re

from enum import Enum
from .arch_v81m import *

issue_rate = 1

class ExecutionUnit(Enum):
    SCALAR=0,
    LOAD=1,
    STORE=1,
    VEC_INT=2,
    VEC_MUL=3,
    VEC_FPU=3,
    STACK=1,
    def __repr__(self):
        return self.name

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    _add_st_ld_hazard(slothy)

# ===============================================================#
#                   CONSTRAINT (Performance)                     #
#----------------------------------------------------------------#
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
        if slothy.config.constraints.st_ld_hazard_ignore_scattergather and \
           ( isinstance(instA, vst4) or isinstance(instB, vld4) ):
            return False
        if slothy.config.constraints.st_ld_hazard_ignore_stack and \
           (instB.inst.is_stack_load() or instA.inst.is_stack_store()):
           return False
        return True

    slothy._model.st_ld_hazard_vars = {}
    for t_st, t_ld in slothy.get_inst_pairs(is_st_ld_pair):
        if t_st.is_locked and t_ld.is_locked:
            continue
        if slothy.config.constraints.st_ld_hazard:
            slothy._model.st_ld_hazard_vars[t_st,t_ld] = slothy._NewConstant(True)
        else:
            slothy._model.st_ld_hazard_vars[t_st,t_ld] = slothy._NewBoolVar("")

        slothy.logger.debug(f"ST-LD hazard for {t_st.inst.mnemonic} "\
                            f"({t_st.id}) -> {t_ld.inst.mnemonic} ({t_ld.id})")

        slothy._Add( t_ld.cycle_start_var != t_st.cycle_start_var + 2 ).OnlyEnforceIf(
            slothy._model.st_ld_hazard_vars[t_st,t_ld] )

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return all([ not slothy.config.constraints.st_ld_hazard,
                 slothy.config.constraints.minimize_st_ld_hazards ])

def get_min_max_objective(slothy):
    if not has_min_max_objective(slothy):
        return
    return (slothy._model.st_ld_hazard_vars, "minimize", "ST-LD hazard risks")

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
    vrshr       : ExecutionUnit.VEC_INT,
    vrshl       : ExecutionUnit.VEC_INT,
    vshr        : ExecutionUnit.VEC_INT,
    vshl        : ExecutionUnit.VEC_INT,
    vshlc       : ExecutionUnit.VEC_INT,
    vdup        : ExecutionUnit.VEC_INT,
    vmov_imm    : [ ExecutionUnit.VEC_INT,
                    ExecutionUnit.VEC_MUL ],
    vmov_double_v2r : [ ExecutionUnit.VEC_INT,
                        ExecutionUnit.VEC_MUL ],
    vadd_sv     : ExecutionUnit.VEC_INT,
    vadd_vv     : ExecutionUnit.VEC_INT,
    vsub        : ExecutionUnit.VEC_INT,
    vhadd       : ExecutionUnit.VEC_INT,
    vhsub       : ExecutionUnit.VEC_INT,
    vhcadd      : ExecutionUnit.VEC_INT,
    vhcsub      : ExecutionUnit.VEC_INT,
    vand        : ExecutionUnit.VEC_INT,
    vorr        : ExecutionUnit.VEC_INT,
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
    ldrd        : ExecutionUnit.LOAD,
    strd        : ExecutionUnit.STORE,
    restored    : ExecutionUnit.STACK,
    restore     : ExecutionUnit.STACK,
    saved       : ExecutionUnit.STACK,
    save        : ExecutionUnit.STACK,
    qsave       : ExecutionUnit.STACK,
    qrestore    : ExecutionUnit.STACK,
    vldr        : ExecutionUnit.LOAD,
    vldr_gather : ExecutionUnit.LOAD,
    vld4        : ExecutionUnit.LOAD,
    vstr        : ExecutionUnit.STORE,
    vst4        : ExecutionUnit.STORE,
    vcmul       : ExecutionUnit.VEC_FPU,
    vcmla       : ExecutionUnit.VEC_FPU,
    vcadd       : ExecutionUnit.VEC_FPU,
    vaddf       : ExecutionUnit.VEC_FPU,
    vsubf       : ExecutionUnit.VEC_FPU,
    vhcaddf     : ExecutionUnit.VEC_FPU,
    vhcsubf     : ExecutionUnit.VEC_FPU,
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
      vdup,
      vshr,
      vshl,
      vshlc,
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
      vld4,
      vst4,
      vcmul,
      vcmla,
      vcadd,
      vaddf,
      vsubf,
      vhcadd,
      vhcsub )            : 2
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
      vshlc,
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
      vld4,
      vst4 )           : 1,
    ( vrshr,
      vrshl,
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
      vhcsub )         : 2,
}

def _find_class(src):
    for inst_class in Instruction.__subclasses__():
        if isinstance(src,inst_class):
            return inst_class
    raise Exception("Couldn't find instruction class")

def _lookup_multidict(d, k, default=None):
    for l,v in d.items():
        if k == l:
            return v
        if isinstance(l,tuple) and k in l:
            return v
    if default == None:
        raise Exception(f"Couldn't find {k}")
    return default

def get_latency(src, out_idx, dst):
    instclass_src = _find_class(src)
    instclass_dst = _find_class(dst)

    default_latency = _lookup_multidict(
        default_latencies, instclass_src)

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
                          vcmul,
                          vcmla,
                          vcadd,
                          vaddf,
                          vsubf,
                          vhcaddf ]:
        return 1

    # Inputs to VST4x seem to have higher latency
    # Use 3 cycles as an upper bound here.
    if instclass_dst == vst4            and \
       instclass_src in [ vshr,
                          vshl,
                          vshlc,
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
                          vrshl,
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
                          vhcsub  ]:
        return 3

    return default_latency

def get_units(src):
    instclass = _find_class(src)
    units = execution_units[instclass]
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    instclass = _find_class(src)
    return _lookup_multidict(
        inverse_throughput, instclass)

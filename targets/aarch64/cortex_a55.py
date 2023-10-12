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
###          They are _NOT_ an official software optimization guide for Cortex-A55.  ###
###                                                                                  ###
########################################################################################
########################################################################################
########################################################################################

import logging
import re
import inspect

from enum import Enum
from .aarch64_neon import *

issue_rate = 2

class ExecutionUnit(Enum):
    SCALAR_ALU0=1,
    SCALAR_ALU1=2,
    SCALAR_MAC=3,
    SCALAR_LOAD=4,
    SCALAR_STORE=5,
    VEC0=6,
    VEC1=7,
    def __repr__(self):
        return self.name
    def SCALAR():
        return [ExecutionUnit.SCALAR_ALU0, ExecutionUnit.SCALAR_ALU1]
    def SCALAR_MUL():
        return [ExecutionUnit.SCALAR_MAC]

    def indentation(unit):
        if unit in ExecutionUnit.SCALAR():
            return 100
        else:
            return 0

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    _add_slot_constraints(slothy)
    _add_st_hazard(slothy)

def _add_slot_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return

    # Q-Form vector instructions are on slot 0 only
    slothy.restrict_slots_for_instructions_by_property(
        Instruction.is_Qform_vector_instruction,
        [0])

    # fcsel and vld2 on slot 0 only
    slothy.restrict_slots_for_instructions_by_class(
        [fcsel_dform, stack_vld2_lane],
        [0])

def _add_st_hazard(slothy):
    if slothy.config.constraints.functional_only:
        return

    def is_vec_st_st_pair(instA, instB):
        if not instA.inst.is_vector_store() or not instB.inst.is_vector_store():
            return False
        return True

    for t0, t1 in slothy.get_inst_pairs(is_vec_st_st_pair):
        if t0.is_locked and t1.is_locked:
            continue
        slothy._Add( t0.cycle_start_var != t1.cycle_start_var + 1 )

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    return False
def get_min_max_objective(slothy):
    return

def _is_dt_version_of(instr_class, dts=None):
    if not isinstance(instr_class, list):
        instr_class = [instr_class]
    def _intersects(lsA,lsB):
        return len([a for a in lsA if a in lsB]) > 0
    def _check_instr_dt(src):
        if _find_class(src) in instr_class:
            if dts is None or _intersects(src.datatype, dts):
                return True
        return False
    return _check_instr_dt

def _is_dform_version_of(instr_class):
    return _is_dt_version_of(instr_class, ["1d","2s","4h","8b"])
def _is_qform_version_of(instr_class):
    return _is_dt_version_of(instr_class, ["2d","4s","8h","16b"])

execution_units = {
    # q-form vector instructions
        (vmls, vmls_lane,
        vmul, vmul_lane,
        vmla, vmla_lane,
        vqrdmulh, vqrdmulh_lane,
        vqdmulh_lane,
        vsrshr, vand, vbic,
        ldr_vo_wrapper, ldr_vi_wrapper,
        str_vi_wrapper, str_vo_wrapper,
        stack_vld1r, stack_vld2_lane,
        vmull, vmlal, vushr, vusra
    ): [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],  # these instructions use both VEC0 and VEC1

    st4 : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1, ExecutionUnit.SCALAR_LOAD, ExecutionUnit.SCALAR_STORE] + ExecutionUnit.SCALAR()],


    # non-q-form vector instructions
    ( vext, mov_d01, mov_b00,
      fcsel_dform,
      mov_vtox, mov_xtov,
      stack_vstp_dform, stack_vstr_dform, stack_vldr_bform, stack_vldr_dform,
      stack_vld1r, stack_vld2_lane,
    ): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],  # these instructions use VEC0 or VEC1

    _is_qform_version_of(trn1) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(trn1) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(trn2) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_qform_version_of(trn2) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(trn2) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vzip1) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vzip1) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vzip2) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vzip2) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vuzp1) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vuzp1) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vuzp2) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vuzp2) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vsub) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vsub) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vadd) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vadd) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    _is_qform_version_of(vshl) : [[ExecutionUnit.VEC0, ExecutionUnit.VEC1]],
    _is_dform_version_of(vshl) : [ExecutionUnit.VEC0, ExecutionUnit.VEC1],

    # TODO: double check these new instructions:
    (stack_stp, stack_stp_wform, stack_str, x_str) : ExecutionUnit.SCALAR_STORE,
    (stack_ldr, ldr_const, ldr_sxtw_wform, x_ldr) : ExecutionUnit.SCALAR_LOAD,
    (umull_wform, mul_wform, umaddl_wform ): ExecutionUnit.SCALAR_MUL(),
    ( lsr, bic, bfi, add, add_shifted, add_sp_imm, add2, add_lsr,
      and_imm, nop, vins, tst_wform, movk_imm, sub, mov,
      subs_wform, asr_wform, and_imm_wform, lsr_wform, eor_wform) : ExecutionUnit.SCALAR(),
}

inverse_throughput = {
    ( vadd, vsub,
      vmul, vmul_lane, vmls, vmls_lane,
      vqrdmulh, vqrdmulh_lane, vqdmulh_lane, vmull,
      vmlal,
      vsrshr, vext ) : 1,
    (trn2, trn1) : 1,
    ( vldr, ldr_vo_wrapper, ldr_vi_wrapper ) : 2,
    ( vstr, str_vo_wrapper, str_vi_wrapper ) : 1,
    ( tst_wform ) : 1,
    ( nop, vins, x_ldr, x_str ) : 1,
    st4 : 5,
    (fcsel_dform) : 1,
    (mov_vtox, mov_xtov) : 1,
    (movk_imm, mov) : 1,
    (stack_vstp_dform, stack_vstr_dform) : 1,
    (stack_stp, stack_stp_wform, stack_str) : 1,
    (stack_ldr, ldr_const) : 1,
    (ldr_sxtw_wform) : 3,
    (lsr, lsr_wform) : 1,
    (umull_wform, mul_wform, umaddl_wform) : 1,
    (and_twoarg, and_imm, and_imm_wform, ) : 1,
    (add, add2, add_lsr, add_shifted, add_sp_imm) : 1,
    (sub, subs_wform, asr_wform) : 1,
    (bfi) : 1,
    (vshl, vshl, vushr) : 1,
    (vusra) : 1,
    (vand, vbic) : 1,
    (vuzp1, vuzp2) : 1,
    (stack_vld1r, stack_vld2_lane) : 1,
    (stack_vldr_bform, stack_vldr_dform) : 1,
    (mov_d01, mov_b00) : 1,
    (vzip1, vzip2) : 1,
    (eor_wform) : 1,
    (bic) : 1
}

default_latencies = {
    _is_qform_version_of([vadd, vsub]) : 3,
    _is_dform_version_of([vadd, vsub]) : 2,

    ( trn1, trn2) : 2,
    ( vsrshr ) : 3,
    ( vmul, vmul_lane, vmls, vmls_lane,
      vqrdmulh, vqrdmulh_lane, vqdmulh_lane, vmull,
      vmlal) : 4,
    ( ldr_vo_wrapper, ldr_vi_wrapper,
      str_vo_wrapper, str_vi_wrapper ) : 4,
    st4 : 5,
    ( x_str, x_ldr ) : 4,
    ( vins, vext ) : 2,
    ( tst_wform) : 1,
    (fcsel_dform) : 2,
    (mov_vtox, mov_xtov) : 2,
    (movk_imm, mov) : 1,
    (stack_vstp_dform, stack_vstr_dform) : 1,
    (stack_stp, stack_stp_wform, stack_str) : 1,
    (stack_ldr, ldr_const) : 3,
    (ldr_sxtw_wform) : 5,
    (lsr, lsr_wform) : 1,
    (umull_wform, mul_wform, umaddl_wform) : 3,
    (and_imm, and_imm_wform) : 1,
    (add2, add_lsr, add_shifted, add_sp_imm) : 2,
    (add, sub, subs_wform, asr_wform) : 1,
    (bfi) : 2,
    (vshl, vushr) : 2,
    (vusra) : 3,
    (vand, vbic) : 1,
    (vuzp1, vuzp2) : 2,
    (stack_vld1r, stack_vld2_lane) : 3,
    (stack_vldr_bform, stack_vldr_dform) : 3,
    (mov_d01, mov_b00) : 2,
    (vzip1, vzip2) : 2,
    (eor_wform) : 1,
    (bic) : 1
}

def _find_class(src):
    for inst_class in iter_aarch64_instructions():
        if isinstance(src,inst_class):
            return inst_class
    raise Exception(f"Couldn't find instruction class for {src} (type {type(src)})")

def _lookup_multidict(d, inst, default=None):
    instclass = _find_class(inst)
    for l,v in d.items():
        # Multidict entries can be the following:
        # - An instruction class. It matches any instruction of that class.
        # - A callable. It matches any instruction returning `True` when passed
        #   to the callable.
        # - A tuple of instruction classes or callables. It matches any instruction
        #   which matches at least one element in the tuple.
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            assert callable(x)
            return x(inst)
        if not isinstance(l, tuple):
            l = [l]
        for lp in l:
            if match(lp):
                return v
    if default == None:
        raise Exception(f"Couldn't find {instclass} for {inst}")
    return default


def _check_instr_dt(src, instr_classes, dt=None):
    if not isinstance(instr_classes, list):
        instr_classes = list(instr_classes)
    for instr_class in instr_classes:
        if _find_class(src) == instr_class:
            if dt is None or len(set(dt + src.datatype)) > 0:
                return True
    return False


def get_latency(src, out_idx, dst):
    instclass_src = _find_class(src)
    instclass_dst = _find_class(dst)

    latency = _lookup_multidict(
        default_latencies, src)

    if instclass_dst in [trn1, trn2, vzip1, vzip2, vuzp1, vuzp2, fcsel_dform] \
       and latency < 3:
        latency += 1

    if [instclass_src, instclass_dst] in   \
       [
            [lsr, mul_wform],
            [lsr, umaddl_wform],
            [vbic, vusra]
       ]:
        latency += 1

    if instclass_src == vmlal and instclass_dst == vmlal and \
       src.args_in_out[0] == dst.args_in_out[0]:
        return (4, lambda t_src,t_dst: t_dst.program_start_var == t_src.program_start_var + 2)

    if instclass_src == umaddl_wform and instclass_dst == umaddl_wform and \
       src.args_out[0] == dst.args_out[0]:
        return (3, lambda t_src,t_dst: t_dst.program_start_var == t_src.program_start_var + 1)

    return latency

def get_units(src):
    units = _lookup_multidict(execution_units, src)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    return _lookup_multidict(
        inverse_throughput, src)

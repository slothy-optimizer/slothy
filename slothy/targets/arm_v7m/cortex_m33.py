"""
Experimental Cortex-M33 microarchitecture model for SLOTHY

.. warning::

    The data in this module is approximate and may contain errors.
"""

# ################################## NOTE ################################## #
# WARNING: The data in this module is approximate and may contain errors.    #
#          They are _NOT_ an official software optimization guide for        #
#          Cortex-M33.                                                       #
#                                                                            #
# Every number in this module was measured on silicon rather than taken      #
# from a manual. Latencies and inverse throughputs come from ~110            #
# generated microbenchmarks run on a Raspberry Pi Pico 2 (RP2350,            #
# Cortex-M33) at 150 MHz, executing from SRAM: 100 straight-line copies of   #
# each instruction in two variants -- independent operands for throughput,   #
# chained for latency -- median of 33 samples, with the cost of the call     #
# subtracted using an empty function measured the same way.                  #
#                                                                            #
# This model describes a Cortex-M33 WITH the DSP extension and an FPU,       #
# which is the RP2350 configuration. Both are optional in the                #
# architecture, and the presence of DSP was confirmed on the chip            #
# (ID_ISAR3.SIMD = 3) rather than assumed from compiler flags.               #
#                                                                            #
# VALIDATION                                                                 #
#                                                                            #
# Predicted cycles were compared against measured cycles for eight kernels   #
# scheduled with this model. Criterion fixed before measuring: 5%. Seven     #
# of eight are within it:                                                    #
#                                                                            #
#   keccakf1600 (Adomnicai M4)  +0.7%      ntt_kyber        +3.1%            #
#   fromplant_kyber             +0.4%      intt_kyber       +3.3%            #
#   add_kyber                   -0.7%      basemul_kyber    +4.1%            #
#   sub_kyber                   -0.8%      barrett_reduce   +6.2%  (*)       #
#                                                                            #
# (*) The one open case. Every instruction in that loop has been measured    #
#     individually and each matches this model, so the ~5 cycles per         #
#     iteration are not a per-instruction property.                          #
#                                                                            #
# MEASURE THE CORE, NOT THE BOARD                                            #
#                                                                            #
# On this board a load can cost more than the 1.00 cycles this model         #
# charges, but only when the code is executing from SRAM as well. Then       #
# instruction fetch and data access contend for the same banks, every load   #
# costs 1.10 to 1.24 cycles depending on stride, and the eight kernels come  #
# out 5.8% to 8.0% above this model.                                         #
#                                                                            #
# Two independent interventions remove it, which is what identifies the      #
# mechanism. Move the data to a bank nothing else uses, leaving the code in  #
# SRAM, and the penalty goes. Move the code to flash instead, leaving the    #
# data in the contended region, and it goes too: there the two regions       #
# measure identically, 9184 cycles either way for Keccak, +0.4% against this #
# model.                                                                     #
#                                                                            #
# Running from flash, every entry in this model is confirmed. Across the 93  #
# instructions measured in both configurations, only the memory throughputs  #
# change, and they change towards what the model already charges. Latencies, #
# ALU and DSP throughputs and the taken-branch cost are identical.           #
#                                                                            #
# So the cost is the board's, not the core's. Modelling it here would make   #
# the model wrong on any other Cortex-M33 part, and wrong on this one too as #
# soon as the code runs from flash.                                          #
#                                                                            #
# DELIBERATELY LEFT OUT, FOR THE SAME REASON                                 #
#                                                                            #
# - `str` inverse throughput on this chip depends on the address: 1.0 at     #
#   most alignments and ~1.5 at one in four, with a 16-byte period. The      #
#   floor, 1 cycle, is what this model charges.                              #
# - The Cortex-M7 model's `add_st_hazard` constraint is NOT copied here.     #
#   Store-then-load at the same address, at distant addresses, and in both   #
#   orders all measured 1.19 cycles per instruction. There is no address     #
#   conflict on this core -- that is a measurement, not an omission.         #
#                                                                            #
# CONTRIBUTED BY                                                             #
#                                                                            #
# The UFCG team of the CISSA project, "Otimização de Algoritmos              #
# Pós-Quânticos para Plataformas Restritas" (Optimization of Post-Quantum    #
# Algorithms for Constrained Platforms), at the Universidade Federal de      #
# Campina Grande, Brazil, with the EMBRAPII CESAR Competence Centre in       #
# Cybersecurity: Edmar Candeia Gurjão, Leocarlos Bezerra da Silva Lima,      #
# Bruno Ribeiro de Almeida, Fernando Luiz Florência Barros, João Mateus      #
# Alves Felinto, Marcus Vinícius Almeida Filho.                              #
##############################################################################


from enum import Enum

from slothy.helper import lookup_multidict

# NOTE: the seven names marked below are added by the companion commit that
# extends arch_v7m. Without it this import fails, which is deliberate: a
# missing class should show up here rather than silently change a result.
from slothy.targets.arm_v7m.arch_v7m import (
    find_class,
    # added to arch_v7m by the companion commit. Keccak's bit-interleaving
    # conversions are made almost entirely of these. Measured on silicon:
    # latency 1 and inverse throughput 1 for all of them.
    log_and_imm,
    log_and_imm_short,
    lsr,
    bfi,
    bfc,
    mov,
    movs,
    # memory
    ldr,
    ldr_with_imm,
    ldr_with_imm_stack,
    ldr_with_inc_writeback,
    ldr_with_postinc,
    Ldrd,
    ldrb_with_imm,
    ldrh_with_imm,
    ldrh_with_postinc,
    ldrb_with_postinc,
    vldr_with_imm,
    vldr_with_postinc,
    ldm_interval,
    ldm_interval_inc_writeback,
    vldm_interval_inc_writeback,
    str_with_imm,
    str_with_imm_stack,
    str_with_postinc,
    str_no_off,
    strh_with_imm,
    strh_with_postinc,
    stm_interval_inc_writeback,
    # immediates and register moves
    movw_imm,
    movt_imm,
    vmov_gpr,
    vmov_gpr2,
    vmov_gpr2_dual,
    # basic arithmetic
    adds,
    add,
    add_short,
    add_imm,
    add_imm_short,
    sub,
    subs_imm,
    subs_imm_short,
    sub_imm_short,
    neg_short,
    cmp,
    cmp_imm,
    bne,
    # logical
    log_and,
    log_or,
    eor,
    eor_short,
    eors,
    eors_short,
    bic,
    bics,
    # standalone shifts
    ror,
    ror_short,
    rors_short,
    lsl,
    asr,
    asrs,
    ubfx_imm,
    # ALU with barrel-shifted operand
    add_shifted,
    sub_shifted,
    log_and_shifted,
    log_or_shifted,
    eor_shifted,
    bic_shifted,
    pkhbt_shifted,
    # multiplication
    mul,
    mul_short,
    smull,
    smlal,
    mla,
    mls,
    smulwb,
    smulwt,
    smultb,
    smultt,
    smulbb,
    smlabt,
    smlabb,
    smlatt,
    smlatb,
    smlad,
    smladx,
    smuad,
    smuadx,
    smmulr,
    # DSP / SIMD
    pkhbt,
    pkhtb,
    uadd16,
    usub16,
    sadd16,
    ssub16,
)

# The Cortex-M33 is SINGLE-ISSUE. That is the most important difference from
# the Cortex-M7, which is dual-issue, and the reason the M7 model's slot
# constraints have no counterpart here.
#
# Measured: an inverse throughput of 1.00 cycles on nearly every instruction
# tested, which is exactly what single issue predicts.
issue_rate = 1
llvm_mca_target = "cortex-m33"


class ExecutionUnit(Enum):
    """
    A single unit.

    The Cortex-M7 model has six (STORE, ALU0, ALU1, MAC, LOAD0, LOAD1) because
    it has to say which pairs of instructions fit together in one cycle. With
    single issue there are no pairs: at most one instruction starts per cycle,
    and the issue rate already enforces that. Inventing units here would add
    structure that corresponds to nothing measured.
    """

    UNIT = 0

    def __repr__(self):
        return self.name


def add_further_constraints(slothy):
    """
    No extra constraints.

    The Cortex-M7 model adds three:
      - `add_dsp_slot_constraint` and `add_mac_slot_constraint`, which say
        which of the two issue slots each instruction may enter. Meaningless
        here: there is only one slot.
      - `add_st_hazard`, which separates `ldr` and `str` at nearby addresses.
        We measured it and it does NOT exist on the M33: 1.19 cycles per
        instruction for the same address, for distant addresses, and in both
        orders.
    """
    _ = slothy


def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


# ---------------------------------------------------------------------------
# Groupings, by measured cost
# ---------------------------------------------------------------------------

# Latency 1: the result is available to the next instruction.
_LATENCY_1 = (
    adds,
    add,
    add_short,
    add_imm,
    add_imm_short,
    sub,
    subs_imm,
    subs_imm_short,
    sub_imm_short,
    neg_short,
    log_and,
    log_or,
    eor,
    eor_short,
    eors,
    eors_short,
    bic,
    bics,
    ror,
    ror_short,
    rors_short,
    lsl,
    asr,
    asrs,
    ubfx_imm,
    lsr,
    bfi,
    bfc,
    log_and_imm,
    log_and_imm_short,
    movw_imm,
    movt_imm,
    mov,
    movs,
    vmov_gpr,
    vmov_gpr2,
    vmov_gpr2_dual,
    cmp,
    cmp_imm,
)

# TAKEN branch: 3 cycles. This is not result latency -- `bne` writes no
# register -- but occupancy: the pipeline has to refill.
#
# This number was put in after the model FAILED validation. The first version
# grouped `bne` with the 1-cycle instructions, on our assumption, and the
# prediction for a pointwise-multiply kernel came out 17% below the measured
# value: a loop of 85 iterations multiplies a single branch's error by 85. We
# then measured two loops, one empty and one with eight adds, and both give 3
# cycles for the taken branch.
_BRANCH = (bne,)

# Latency 2, multiplication. Measured: `smull` chained through a multiplier
# operand costs 2. The ACCUMULATOR path is shorter -- 1 cycle -- and that is
# handled in get_latency(), not here, because it depends on which input of the
# next instruction the dependency enters through.
#
# The half-word forms (`smulbb`, `smultb`, `smulwb`) were measured separately
# rather than left to inherit from this group: latency 1.99, inverse
# throughput 1.00, matching the word forms.
_LATENCY_2_MUL = (
    mul,
    mul_short,
    smull,
    smlal,
    mla,
    mls,
    smulwb,
    smulwt,
    smultb,
    smultt,
    smulbb,
    smlabt,
    smlabb,
    smlatt,
    smlatb,
    smlad,
    smladx,
    smuad,
    smuadx,
    smmulr,
)

# Latency 2, 16-bit SIMD and packing. Measured: uadd16, usub16 and pkhbt cost
# 2 cycles when chained.
_LATENCY_2_DSP = (pkhbt, pkhtb, uadd16, usub16, sadd16, ssub16)

# Latency 2, loads. First measured by pointer chasing (`ldr r0, [r0]`), where
# the loaded value feeds the ADDRESS of the next load. Because latency on this
# core can depend on the input port -- see the accumulator case above -- the
# ALU path was measured too, with a distance ladder: a load followed at
# distance 1 by an ALU consumer costs 1.49 cycles per instruction, the same as
# the address path, and the bubble disappears at distance 2 in both. Latency 2
# holds for both ports.
_LOAD = (
    ldr,
    ldr_with_imm,
    ldr_with_imm_stack,
    ldr_with_inc_writeback,
    ldr_with_postinc,
    ldrb_with_imm,
    ldrh_with_imm,
    ldrh_with_postinc,
    ldrb_with_postinc,
    vldr_with_imm,
    vldr_with_postinc,
)

# Register-pair load: two words, ~2.2 cycles measured.
_LOAD_PAIR = (Ldrd,)

# Stores: they produce no register value, so latency is never queried.
# Inverse throughput 1 -- see the header note on what is left out.
_STORE = (
    str_with_imm,
    str_with_imm_stack,
    str_with_postinc,
    str_no_off,
    strh_with_imm,
    strh_with_postinc,
)

# Multiple accesses: roughly one cycle per word transferred. Measured:
# ldrd/strd (two words) at 2.2 cycles.
_MULTIPLE = (
    ldm_interval,
    ldm_interval_inc_writeback,
    vldm_interval_inc_writeback,
    stm_interval_inc_writeback,
) + _LOAD_PAIR

# ALU with a barrel-shifted operand. Latency depends on the KIND of shift --
# see get_latency(). The table holds the expensive case; LSL takes 1 off.
_SHIFTED = (
    add_shifted,
    sub_shifted,
    log_and_shifted,
    log_or_shifted,
    eor_shifted,
    bic_shifted,
    pkhbt_shifted,
)

# Instructions whose accumulator reaches the adder late and therefore has a
# forwarding path: a dependency entering through the accumulator costs 1
# instead of 2.
_ACC_THIRD = (mla, mls, smlabb, smlabt, smlatt, smlatb, smlad, smladx)

_ALL = (
    _LATENCY_1
    + _LATENCY_2_MUL
    + _LATENCY_2_DSP
    + _LOAD
    + _STORE
    + _MULTIPLE
    + _SHIFTED
    + _BRANCH
)

execution_units = {_ALL: ExecutionUnit.UNIT}

inverse_throughput = {
    _LATENCY_1 + _LATENCY_2_MUL + _LATENCY_2_DSP + _LOAD + _STORE + _SHIFTED: 1,
    _MULTIPLE: 2,
    _BRANCH: 3,
}

default_latencies = {
    _LATENCY_1: 1,
    _LATENCY_2_MUL: 2,
    _LATENCY_2_DSP: 2,
    _LOAD: 2,
    _STORE: 1,
    _MULTIPLE: 2,
    _SHIFTED: 2,  # caso caro; o LSL desconta em get_latency()
    _BRANCH: 1,  # writes no register; the cost is in the throughput
}


def get_latency(src, out_idx, dst):
    """
    Latency from `src` to `dst`, in cycles.

    Two corrections on top of the table, both measured.

    1. BARREL SHIFTER -- only LSL is free. We measured 1 cycle for
       `add rd, rn, rm, lsl #n` and 2 for `lsr`, `asr` and `ror`, at any shift
       amount and with any ALU operation. Isolated with four discriminating
       tests: `eor` with no shift gives 1 (it is not the EOR), `eor` with LSL
       gives 1 (it is not the shifter in general), `add` with ROR gives 2 (it
       is the kind of shift), and chaining through the LSL shifter itself also
       gives 1 (LSL does not charge even on the critical path).

       This explains Keccak, whose round loop is built from
       `eor rd, rn, rm, ror #n` -- exactly the combination that pays the extra
       cycle.

    2. EARLY ACCUMULATOR -- in a multiply-accumulate chain, accumulating is
       free and multiplying costs. We measured `smull` chained through a
       multiplier operand at 2 cycles and `smlal` chained through the
       accumulator at 1; the same pair shows up in `mla` (2, through Rn)
       against `smlad`/`smlabb` (1, through Ra).
    """
    _ = out_idx

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src, instclass_src)

    # (1) the barrel shifter is free only for LSL
    if instclass_src in _SHIFTED:
        barrel = getattr(src, "barrel", None)
        if barrel is not None and str(barrel).strip().lower() == "lsl":
            latency = 1

    # (2) accumulator forwarding for three-operand multiplies: the value
    # enters through the third operand (Ra) and arrives in time.
    if instclass_dst in _ACC_THIRD and len(dst.args_in) > 2:
        if dst.args_in[2] in (src.args_out + src.args_in_out):
            latency = latency - 1

    # (2b) the same for long multiplies, whose accumulator is the in-out pair
    # (RdLo, RdHi) rather than an input operand.
    if instclass_dst in (smlal,) and len(dst.args_in_out) > 1:
        acc = dst.args_in_out[:2]
        if any(r in acc for r in (src.args_out + src.args_in_out)):
            latency = latency - 1

    return max(latency, 1)


def get_units(src):
    units = lookup_multidict(execution_units, src, find_class(src))
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src, find_class(src))

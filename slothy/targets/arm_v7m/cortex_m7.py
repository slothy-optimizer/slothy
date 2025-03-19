"""
Experimental Cortex-M7 microarchitecture model for SLOTHY

.. warning::

    The data in this module is approximate and may contain errors.
"""

# ################################ NOTE ########################################## #
#                                                                                  #
# WARNING: The data in this module is approximate and may contain errors.          #
#          They are _NOT_ an official software optimization guide for Cortex-M7.   #
#                                                                                  #
# Sources used in constructing this model:                                         #
# - ARMv7-M Architecture Reference Manual (ARM DDI 0403E.e)                        #
# - https://github.com/jnk0le/random/tree/master/pipeline%20cycle%20test#cortex-m7 #
# - https://www.quinapalus.com/cm7cycles.html                                      #
####################################################################################

from enum import Enum
from itertools import product
from slothy.targets.arm_v7m.arch_v7m import (
    find_class,
    lookup_multidict,
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
    Ldrd,
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
    movw_imm,
    movt_imm,
    adds,
    add,
    add_short,
    add_imm,
    add_imm_short,
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
    neg_short,
    log_and,
    log_or,
    eor,
    eor_short,
    eors,
    eors_short,
    bic,
    bics,
    cmp,
    cmp_imm,
    bne,
    vmov_gpr,
    vmov_gpr2,
    vmov_gpr2_dual,
    pkhbt,
    pkhtb,
    pkhbt_shifted,
    ubfx_imm,
    uadd16,
    usub16,
    sadd16,
    ssub16,
    sub,
    subs_imm,
    subs_imm_short,
    sub_imm_short,
    ror,
    ror_short,
    rors_short,
    lsl,
    asr,
    asrs,
    add_shifted,
    sub_shifted,
    log_and_shifted,
    log_or_shifted,
    eor_shifted,
    bic_shifted,
    Armv7mShiftedArithmetic,
    Armv7mShiftedLogical,
    Armv7mBasicArithmetic,
    Armv7mLogical,
)

from sympy import simplify

issue_rate = 2
llvm_mca_target = "cortex-m7"


class ExecutionUnit(Enum):
    """Enumeration of execution units in Cortex-M7 model"""

    STORE = 0
    ALU0 = 1
    ALU1 = 2
    MAC = 5
    FPU = 6
    LOAD0 = 7
    LOAD1 = 8
    SIMD = 9

    def __repr__(self):
        return self.name

    def ALU():
        return [ExecutionUnit.ALU0, ExecutionUnit.ALU1]

    def SHIFT():
        return [ExecutionUnit.SHIFT0, ExecutionUnit.SHIFT1]

    def LOAD():
        return [ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    add_st_hazard(slothy)

    add_dsp_slot_constraint(slothy)
    add_mac_slot_constraint(slothy)


def add_dsp_slot_constraint(slothy):
    slothy.restrict_slots_for_instructions_by_class(
        [pkhbt, pkhtb, pkhbt_shifted, ubfx_imm, uadd16, usub16, sadd16, ssub16], [0]
    )


def add_mac_slot_constraint(slothy):
    slothy.restrict_slots_for_instructions_by_class(
        [
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
        ],
        [1],
    )


def add_st_hazard(slothy):
    def is_st_ld_pair(inst_a, inst_b):
        return (
            isinstance(inst_a.inst, ldr_with_imm)
            or isinstance(inst_a.inst, ldr_with_imm_stack)
        ) and (
            isinstance(inst_b.inst, str_with_imm)
            or isinstance(inst_b.inst, str_with_imm_stack)
        )

    def evaluate_immediate(string_expr):
        if string_expr is None:
            return 0
        string_expr = str(string_expr)
        return int(simplify(string_expr))

    for t_load, t_store in slothy.get_inst_pairs(cond=is_st_ld_pair):
        if t_load.is_locked and t_store.is_locked:
            continue

        ldr_imm = evaluate_immediate(t_load.inst.immediate)
        str_imm = evaluate_immediate(t_store.inst.immediate)

        if abs(ldr_imm - str_imm) >= 8:
            continue

        ldr_before_str = slothy._NewBoolVar("")
        ldr_after_str = slothy._NewBoolVar("")
        slothy._AddExactlyOne([ldr_before_str, ldr_after_str])
        slothy._Add(t_load.program_start_var < t_store.program_start_var).OnlyEnforceIf(
            ldr_before_str
        )
        slothy._Add(
            t_load.program_start_var >= t_store.program_start_var + 8
        ).OnlyEnforceIf(ldr_after_str)


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    (
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
        vldr_with_postinc,  # TODO: also FPU?
    ): ExecutionUnit.LOAD(),
    (Ldrd, ldm_interval, ldm_interval_inc_writeback, vldm_interval_inc_writeback): [
        ExecutionUnit.LOAD()
    ],
    (
        str_with_imm,
        str_with_imm_stack,
        str_with_postinc,
        str_no_off,
        strh_with_imm,
        strh_with_postinc,
        stm_interval_inc_writeback,
    ): [[ExecutionUnit.STORE, ExecutionUnit.MAC]],
    (
        movw_imm,
        movt_imm,
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
        cmp,
        cmp_imm,
        bne,
    ): ExecutionUnit.ALU(),
    (ror, ror_short, rors_short, lsl, asr, asrs): [
        [ExecutionUnit.ALU0],
        [ExecutionUnit.ALU1],
    ],
    (
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
    ): [ExecutionUnit.MAC],
    (vmov_gpr, vmov_gpr2, vmov_gpr2_dual): [ExecutionUnit.FPU],
    (uadd16, sadd16, usub16, ssub16): list(
        map(list, product(ExecutionUnit.ALU(), [ExecutionUnit.SIMD]))
    ),
    (pkhbt, pkhtb, pkhbt_shifted, ubfx_imm): [[ExecutionUnit.ALU0, ExecutionUnit.SIMD]],
    (Armv7mShiftedArithmetic): [[ExecutionUnit.ALU0]],
    (Armv7mShiftedLogical): [[ExecutionUnit.ALU0]],
}
inverse_throughput = {
    (
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
        vldr_with_postinc,  # TODO: double-check
        # actually not, just placeholder
        ldm_interval,
        ldm_interval_inc_writeback,
        vldm_interval_inc_writeback,
        movw_imm,
        movt_imm,
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        add_shifted,
        sub_shifted,
        sub_imm_short,
        subs_imm,
        subs_imm_short,
        uadd16,
        sadd16,
        usub16,
        ssub16,
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
        neg_short,
        log_and,
        log_and_shifted,
        log_or,
        log_or_shifted,
        eor,
        eor_short,
        eors,
        eors_short,
        eor_shifted,
        bic,
        bics,
        bic_shifted,
        ror,
        ror_short,
        rors_short,
        lsl,
        asr,
        asrs,
        cmp,
        cmp_imm,
        vmov_gpr,
        vmov_gpr2,
        vmov_gpr2_dual,  # verify for dual
        pkhbt,
        pkhtb,
        pkhbt_shifted,
        ubfx_imm,
        str_with_imm,
        str_with_imm_stack,
        str_with_postinc,
        str_no_off,
        strh_with_imm,
        strh_with_postinc,
        bne,
    ): 1,
    (stm_interval_inc_writeback, vmov_gpr2_dual): 2,  # actually not, just placeholder
}

default_latencies = {
    (
        movw_imm,
        movt_imm,
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        add_shifted,
        sub_shifted,
        sub_imm_short,
        subs_imm,
        subs_imm_short,
        uadd16,
        sadd16,
        usub16,
        ssub16,
        neg_short,
        log_and,
        log_and_shifted,
        log_or,
        log_or_shifted,
        eor,
        eor_short,
        eors,
        eors_short,
        bic,
        bics,
        bic_shifted,
        ror,
        ror_short,
        rors_short,
        lsl,
        asr,
        asrs,
        cmp,
        cmp_imm,
        pkhbt,
        pkhtb,
        pkhbt_shifted,
        ubfx_imm,
        vldr_with_imm,
        vldr_with_postinc,  # according to Jan
        # actually not, just placeholder
        ldm_interval,
        ldm_interval_inc_writeback,
        vldm_interval_inc_writeback,
        str_with_imm,
        str_with_imm_stack,
        str_with_postinc,
        str_no_off,
        strh_with_imm,
        strh_with_postinc,
        bne,
    ): 1,
    (
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
        # TODO: Verify load latency
        stm_interval_inc_writeback,  # actually not, just placeholder
        ldr,
        ldr_with_imm,
        ldr_with_imm_stack,
        ldr_with_inc_writeback,
        ldr_with_postinc,
        ldrb_with_imm,
        ldrh_with_imm,
        ldrh_with_postinc,
        ldrb_with_postinc,
        ldrb_with_postinc,
        eor_shifted,
    ): 2,
    (Ldrd): 3,
    (vmov_gpr2, vmov_gpr2_dual): 3,
    (vmov_gpr): 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    # Forwarding path to MAC instructions
    if instclass_dst in [mla, mls, smlabb, smlabt, smlatt, smlatb] and dst.args_in[
        2
    ] in (src.args_out + src.args_in_out):
        latency = latency - 1

    if instclass_dst in [smlal]:
        if len(src.args_out) > 1:
            if (
                src.args_out[0] == dst.args_in_out[0]
                or src.args_out[0] == dst.args_in_out[1]
            ):
                latency = latency - 1
        elif len(src.args_in_out) > 1:
            if (
                src.args_in_out[0] == dst.args_in_out[0]
                or src.args_in_out[0] == dst.args_in_out[1]
            ):
                latency = latency - 1

    # Multiply accumulate chain latency is 1
    if (
        instclass_src in [smlal]
        and instclass_dst in [smlal]
        and src.args_in_out[0] == dst.args_in_out[0]
        and src.args_in_out[1] == dst.args_in_out[1]
    ):
        return 1

    # Load latency is 1 cycle if the destination is an arithmetic/logical instruction
    if (
        instclass_src in [ldr_with_imm, ldr_with_imm_stack, ldr_with_inc_writeback]
        and sum(
            [
                issubclass(instclass_dst, pc)
                for pc in [Armv7mBasicArithmetic, Armv7mLogical]
            ]
        )
        and src.args_out[0] in dst.args_in
    ):
        latency = latency - 1

    # Shifted operand needs to be available one cycle early
    # TODO: verify how this applies to ubfx with imm
    if (
        sum(
            [
                issubclass(instclass_dst, pc)
                for pc in [
                    Armv7mShiftedLogical,
                    Armv7mShiftedArithmetic,
                    pkhbt,
                    pkhtb,
                    pkhbt_shifted,
                ]
            ]
        )
        and dst.args_in[1] in src.args_out
        or sum([issubclass(instclass_dst, pc) for pc in [ubfx_imm]])
        and dst.args_in[0] in src.args_out
    ):
        return latency + 1

    # Load and store multiples take a long time to complete
    if instclass_src in [
        ldm_interval,
        ldm_interval_inc_writeback,
        stm_interval_inc_writeback,
        vldm_interval_inc_writeback,
    ]:
        latency = src.num_out

    # Flag setting -> branch has at least 3 latency
    if (
        instclass_src in [subs_imm, subs_imm_short, cmp, cmp_imm]
        and instclass_dst == bne
    ):
        latency = 2

    # Can always store result in the same cycle
    # TODO: double-check this
    if dst.is_store():
        return 0

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)

    def evaluate_immediate(string_expr):
        if string_expr is None:
            return 0
        string_expr = str(string_expr)
        return int(simplify(string_expr))

    # The Cortex-M7 has two memory banks
    # If two loads use the same memory bank, they cannot dual issue
    # There are no constraints which load can go to which issue slot
    # Approximiation: Only look at immediates, i.e., assume all pointers are
    # aligned to 8 bytes
    if src.is_ldr():
        imm = evaluate_immediate(src.immediate)

        if (imm % 8) // 4 == 0:
            return [ExecutionUnit.LOAD0]
        else:
            return [ExecutionUnit.LOAD1]

    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    itp = lookup_multidict(inverse_throughput, src)
    if find_class(src) in [
        ldm_interval,
        ldm_interval_inc_writeback,
        stm_interval_inc_writeback,
        vldm_interval_inc_writeback,
    ]:
        itp = src.num_out

    return itp

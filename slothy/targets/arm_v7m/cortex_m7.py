"""
Experimental Cortex-M7 microarchitecture model for SLOTHY

WARNING: The data in this module is approximate and may contain errors.
"""

################################### NOTE ###############################################
###                                                                                  ###
### WARNING: The data in this module is approximate and may contain errors.          ###
###          They are _NOT_ an official software optimization guide for Cortex-M4.  ###
###                                                                                  ###
########################################################################################

from enum import Enum
from itertools import product
from slothy.targets.arm_v7m.arch_v7m import *

issue_rate = 2
llvm_mca_target = "cortex-m7"


class ExecutionUnit(Enum):
    """Enumeration of execution units in Cortex-M7 model"""

    STORE = 0
    ALU0 = 1
    ALU1 = 2
    SHIFT0 = 3
    SHIFT1 = 4
    MAC = 5
    FPU = 6
    LOAD0 = 7
    LOAD1 = 8

    def __repr__(self):
        return self.name
    def ALU(): # pylint: disable=invalid-name
        return [ExecutionUnit.ALU0, ExecutionUnit.ALU1]
    def SHIFT(): # pylint: disable=invalid-name
        return [ExecutionUnit.SHIFT0, ExecutionUnit.SHIFT1]
    def LOAD(): # pylint: disable=invalid-name
        return [ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    add_slot_constraints(slothy)


def add_slot_constraints(slothy):
    pass

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
        ldr_with_inc_writeback): ExecutionUnit.LOAD(),
    (
        str_with_imm,
        str_with_imm_stack,
        str_with_postinc
    ): [ExecutionUnit.STORE],
    (
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        sub_imm_short,
        log_and,
        log_or,
        eor, eors, eors_short,
        bic, bics,
        cmp, cmp_imm,
    ): ExecutionUnit.ALU(),
    (ror, ror_short, rors_short): [[ExecutionUnit.ALU0, ExecutionUnit.SHIFT0]],
    (Armv7mShiftedArithmetic): list(map(list, product(ExecutionUnit.ALU(), [ExecutionUnit.SHIFT0]))),
    (Armv7mShiftedLogical): list(map(list, product(ExecutionUnit.ALU(), [ExecutionUnit.SHIFT0]))),
    (mul, smull, smlal): [ExecutionUnit.MAC],
    (vmov_gpr): [ExecutionUnit.FPU],
}

inverse_throughput = {
    (
        ldr,
        ldr_with_imm,
        ldr_with_imm_stack,
        ldr_with_inc_writeback,
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        add_shifted,
        sub_shifted,
        sub_imm_short,
        mul,
        smull,
        smlal,
        log_and,
        log_or,
        eor, eors, eors_short,
        eor_shifted,
        bic, bics,
        bic_shifted,
        ror, ror_short, rors_short,
        cmp, cmp_imm,
        vmov_gpr,
    ): 1,
    (str_with_imm,
        str_with_imm_stack,
        str_with_postinc): 2
}

default_latencies = {
    (
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        add_shifted,
        sub_shifted,
        sub_imm_short,
        log_and,
        log_or,
        eor, eors, eors_short,
        bic, bics,
        bic_shifted,
        ror, ror_short, rors_short,
        cmp, cmp_imm,
        vmov_gpr,
    ): 1,
    (
        mul,
        smull,
        smlal,
        # TODO: Verify load latency
        str_with_imm,
        str_with_imm_stack,
        str_with_postinc,
        ldr,
        ldr_with_imm,
        ldr_with_imm_stack,
        ldr_with_inc_writeback,
        eor_shifted
    ): 2,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    # Load latency is 1 cycle if the destination is an arithmetic/logical instruction
    if instclass_src in [ldr_with_imm, ldr_with_imm_stack, ldr_with_inc_writeback] and \
    sum([issubclass(instclass_dst, pc) for pc in [Armv7mBasicArithmetic, Armv7mLogical]]) and \
       src.args_out[0] in dst.args_in:
        return (1, lambda t_src,t_dst: t_dst.cycle_start_var == t_src.cycle_start_var + 1)
    
    # Shifted operand needs to be available one cycle early
    if sum([issubclass(instclass_dst, pc) for pc in [Armv7mShiftedLogical, Armv7mShiftedArithmetic]]) and \
       dst.args_in[1] in src.args_out:
        return 2

    # Multiply accumulate chain latency is 1
    if instclass_src in [smlal] and instclass_dst in [smlal] and \
            src.args_in_out[0] == dst.args_in_out[0]:
        return 1

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

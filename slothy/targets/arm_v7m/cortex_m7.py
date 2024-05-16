"""
Experimental Cortex-M4 microarchitecture model for SLOTHY

WARNING: The data in this module is approximate and may contain errors.
"""

################################### NOTE ###############################################
###                                                                                  ###
### WARNING: The data in this module is approximate and may contain errors.          ###
###          They are _NOT_ an official software optimization guide for Cortex-M4.  ###
###                                                                                  ###
########################################################################################

from enum import Enum
from slothy.targets.arm_v7m.arch_v7m import *

issue_rate = 2
llvm_mca_target = "cortex-m7"


class ExecutionUnit(Enum):
    """Enumeration of execution units in Cortex-M7 model"""

    LSU = 0
    ALU0 = 1
    ALU1 = 2
    ALU_SHIFT = 3
    MAC = 4
    FPU = 5

    def __repr__(self):
        return self.name


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
    """Adds Cortex-"""
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    # q-form vector instructions
    (
        ldr_with_imm,
        str_with_imm,
    ): [ExecutionUnit.LSU],
    (
        adds,
        add,
        add_short,
        add_imm,
        add_imm_short,
        sub_imm_short,
        log_and,
        log_or,
        eor,
        bic,
        ror,
    ): [ExecutionUnit.ALU0, ExecutionUnit.ALU1],
    (Armv7mShiftedArithmetic): [ExecutionUnit.ALU_SHIFT],
    (Armv7mShiftedLogical): [ExecutionUnit.ALU_SHIFT],
    (mul, smull, smlal): [ExecutionUnit.MAC],
}

inverse_throughput = {
    (
        ldr_with_imm,
        str_with_imm,
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
        eor,
        eor_shifted,
        bic,
        bic_shifted,
        ror,
    ): 1
}

default_latencies = {
    (
        ldr_with_imm,
        str_with_imm,
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
        eor,
        eor_shifted,
        bic,
        bic_shifted,
        ror,
    ): 1,
    (
        mul,
        smull,
        smlal,
    ): 2,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

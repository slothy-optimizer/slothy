#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
# Copyright (c) 2024 Justus Bergermann
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
# Authors: Hanno Becker <hannobecker@posteo.de>
#          Justus Bergermann <mail@justus-bergermann.de>
#

"""
Experimental Xuantie-C908 microarchitecture model for SLOTHY

WARNING: The data in this module is approximate and may contain errors. They are _NOT_ an official software optimization guide for Xuantie-C908.
"""

from slothy.targets.riscv.riscv import *
from slothy.targets.riscv.rv32_64_i_instructions import *
from slothy.targets.riscv.rv32_64_m_instructions import *

issue_rate = 2
llvm_mca_target = "cortex-a55"


class ExecutionUnit(Enum):
    """Enumeration of execution units in C908 model"""

    SCALAR_ALU0 = 1
    SCALAR_ALU1 = 2
    SCALAR_MUL = 3
    LSU = 4
    VEC0 = 5
    VEC1 = 6

    def __repr__(self):
        return self.name

    @classmethod
    def SCALAR(cls):  # pylint: disable=invalid-name
        """All scalar execution units"""
        return [ExecutionUnit.SCALAR_ALU0, ExecutionUnit.SCALAR_ALU1]


#  Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    add_slot_constraints(slothy)
    add_st_hazard(slothy)


def add_slot_constraints(slothy):
    pass
    # Q-Form vector instructions are on slot 0 only
    # slothy.restrict_slots_for_instructions_by_property()
    # Instruction.is_q_form_vector_instruction, [0])
    # fcsel and vld2 on slot 0 only
    # slothy.restrict_slots_for_instructions_by_class(
    #   [fcsel_dform, Q_Ld2_Lane_Post_Inc], [0])


def add_st_hazard(slothy):
    def is_vec_st_st_pair(inst_a, inst_b):
        return inst_a.inst.is_vector_store() and inst_b.inst.is_vector_store()

    for t0, t1 in slothy.get_inst_pairs(cond=is_vec_st_st_pair):
        if t0.is_locked and t1.is_locked:
            continue
        slothy._Add(t0.cycle_start_var != t1.cycle_start_var + 1)


#  Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    (  # this could be more convenient, maybe use existing instructions list or superclass?
        RISCVInstruction.classes_by_names["addi"],
        RISCVInstruction.classes_by_names["slti"],
        RISCVInstruction.classes_by_names["sltiu"],
        RISCVInstruction.classes_by_names["andi"],
        RISCVInstruction.classes_by_names["ori"],
        RISCVInstruction.classes_by_names["xori"],
        RISCVInstruction.classes_by_names["slli"],
        RISCVInstruction.classes_by_names["srli"],
        RISCVInstruction.classes_by_names["srai"],
        RISCVInstruction.classes_by_names["andcls"],
        RISCVInstruction.classes_by_names["orcls"],
        RISCVInstruction.classes_by_names["xor"],
        RISCVInstruction.classes_by_names["add"],
        RISCVInstruction.classes_by_names["slt"],
        RISCVInstruction.classes_by_names["sltu"],
        RISCVInstruction.classes_by_names["sll"],
        RISCVInstruction.classes_by_names["srl"],
        RISCVInstruction.classes_by_names["sub"],
        RISCVInstruction.classes_by_names["sra"],
        RISCVInstruction.classes_by_names["lui"],
        RISCVInstruction.classes_by_names["auipc"],

    ): ExecutionUnit.SCALAR(),

    (
        RISCVInstruction.classes_by_names["lb"],
        RISCVInstruction.classes_by_names["lbu"],
        RISCVInstruction.classes_by_names["lh"],
        RISCVInstruction.classes_by_names["lhu"],
        RISCVInstruction.classes_by_names["lw"],
        RISCVInstruction.classes_by_names["lwu"],
        RISCVInstruction.classes_by_names["ld"],
        RISCVInstruction.classes_by_names["sb"],
        RISCVInstruction.classes_by_names["sh"],
        RISCVInstruction.classes_by_names["sw"],
        RISCVInstruction.classes_by_names["sd"],
    ): ExecutionUnit.LSU,

    (
        RISCVInstruction.classes_by_names["mul"],
        RISCVInstruction.classes_by_names["mulh"],
        RISCVInstruction.classes_by_names["mulhsu"],
        RISCVInstruction.classes_by_names["mulhu"],
        RISCVInstruction.classes_by_names["div"],
        RISCVInstruction.classes_by_names["divu"],
        RISCVInstruction.classes_by_names["rem"],
        RISCVInstruction.classes_by_names["remu"]
    ): ExecutionUnit.SCALAR_MUL
}

inverse_throughput = {
    (
        RISCVInstruction.classes_by_names["addi"],
        RISCVInstruction.classes_by_names["slti"],
        RISCVInstruction.classes_by_names["sltiu"],
        RISCVInstruction.classes_by_names["andi"],
        RISCVInstruction.classes_by_names["ori"],
        RISCVInstruction.classes_by_names["xori"],
        RISCVInstruction.classes_by_names["slli"],
        RISCVInstruction.classes_by_names["srli"],
        RISCVInstruction.classes_by_names["srai"],
        RISCVInstruction.classes_by_names["andcls"],
        RISCVInstruction.classes_by_names["orcls"],
        RISCVInstruction.classes_by_names["xor"],
        RISCVInstruction.classes_by_names["add"],
        RISCVInstruction.classes_by_names["slt"],
        RISCVInstruction.classes_by_names["sltu"],
        RISCVInstruction.classes_by_names["sll"],
        RISCVInstruction.classes_by_names["srl"],
        RISCVInstruction.classes_by_names["sub"],
        RISCVInstruction.classes_by_names["sra"],
        RISCVInstruction.classes_by_names["lui"],
        RISCVInstruction.classes_by_names["auipc"],
    ): 1,
    (
        RISCVInstruction.classes_by_names["lb"],
        RISCVInstruction.classes_by_names["lbu"],
        RISCVInstruction.classes_by_names["lh"],
        RISCVInstruction.classes_by_names["lhu"],
        RISCVInstruction.classes_by_names["lw"],
        RISCVInstruction.classes_by_names["lwu"],
        RISCVInstruction.classes_by_names["ld"],
        RISCVInstruction.classes_by_names["sb"],
        RISCVInstruction.classes_by_names["sh"],
        RISCVInstruction.classes_by_names["sw"],
        RISCVInstruction.classes_by_names["sd"],
    ): 1,

    (
        RISCVInstruction.classes_by_names["mul"],
        RISCVInstruction.classes_by_names["mulh"],
        RISCVInstruction.classes_by_names["mulhsu"],
        RISCVInstruction.classes_by_names["mulhu"],
        RISCVInstruction.classes_by_names["div"],
        RISCVInstruction.classes_by_names["divu"],
        RISCVInstruction.classes_by_names["rem"],
        RISCVInstruction.classes_by_names["remu"]
    ): 2

}

default_latencies = {
    RISCVIntegerRegisterRegister: 1,
    RISCVIntegerRegisterImmediate: 1,
    RISCVUType: 1,
    #RISCVLoad: 3,
    RISCVInstruction.classes_by_names["lb"]: 3,
    RISCVInstruction.classes_by_names["lbu"]: 3,
    RISCVInstruction.classes_by_names["lh"]: 3,
    RISCVInstruction.classes_by_names["lhu"]: 3,
    RISCVInstruction.classes_by_names["lw"]: 2,
    RISCVInstruction.classes_by_names["lwu"]: 2,
    RISCVInstruction.classes_by_names["ld"]: 2,

    RISCVStore: 1,
    #RISCVIntegerRegisterRegisterMul: 4  # not correct for div, rem
    RISCVInstruction.classes_by_names["mul"]: 4,
    RISCVInstruction.classes_by_names["mulh"]: 4,
    RISCVInstruction.classes_by_names["mulhsu"]: 4,
    RISCVInstruction.classes_by_names["mulhu"]: 4,
    RISCVInstruction.classes_by_names["div"]: 4,
    RISCVInstruction.classes_by_names["divu"]: 4,
    RISCVInstruction.classes_by_names["rem"]: 4,
    RISCVInstruction.classes_by_names["remu"]: 4
}


def get_latency(src, out_idx, dst):
    _ = out_idx  #  out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(
        default_latencies, src)

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(
        inverse_throughput, src)

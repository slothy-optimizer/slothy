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

WARNING: The data in this module is approximate and may contain errors.
They are _NOT_ an official software optimization guide for Xuantie-C908.
"""

from slothy.targets.riscv.riscv import *  # noqa: F403
from slothy.targets.riscv.rv32_64_i_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_m_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_v_instructions import *  # noqa: F403

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
    pass


def add_slot_constraints(slothy):
    pass


def add_st_hazard(slothy):
    pass


#  Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
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
        RISCVInstruction.classes_by_names["li"],
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
        RISCVInstruction.classes_by_names["remu"],
    ): [
        [ExecutionUnit.SCALAR_MUL, ExecutionUnit.SCALAR_ALU0],
        [ExecutionUnit.SCALAR_MUL, ExecutionUnit.SCALAR_ALU1],
    ],
    (
        RISCVInstruction.classes_by_names["vle"],
        RISCVInstruction.classes_by_names["vlse"],
        RISCVInstruction.classes_by_names["vluxei"],
        RISCVInstruction.classes_by_names["vloxei"],
        RISCVInstruction.classes_by_names["vse"],
        RISCVInstruction.classes_by_names["vsse"],
        RISCVInstruction.classes_by_names["vsuxei"],
        RISCVInstruction.classes_by_names["vsoxei"],
        RISCVInstruction.classes_by_names["vadd.vv"],
        RISCVInstruction.classes_by_names["vsub.vv"],
        RISCVInstruction.classes_by_names["vrsub.vv"],
        RISCVInstruction.classes_by_names["vand.vv"],
        RISCVInstruction.classes_by_names["vor.vv"],
        RISCVInstruction.classes_by_names["vxor.vv"],
        RISCVInstruction.classes_by_names["vsll.vv"],
        RISCVInstruction.classes_by_names["vsrl.vv"],
        RISCVInstruction.classes_by_names["vmseq.vv"],
        RISCVInstruction.classes_by_names["vmsne.vv"],
        RISCVInstruction.classes_by_names["vmsltu.vv"],
        RISCVInstruction.classes_by_names["vmslt.vv"],
        RISCVInstruction.classes_by_names["vmsleu.vv"],
        RISCVInstruction.classes_by_names["vmsle.vv"],
        RISCVInstruction.classes_by_names["vminu.vv"],
        RISCVInstruction.classes_by_names["vmin.vv"],
        RISCVInstruction.classes_by_names["vmaxu.vv"],
        RISCVInstruction.classes_by_names["vmax.vv"],
        RISCVInstruction.classes_by_names["vmul.vv"],
        RISCVInstruction.classes_by_names["vmulh.vv"],
        RISCVInstruction.classes_by_names["vmulhu.vv"],
        RISCVInstruction.classes_by_names["vmulhsu.vv"],
        RISCVInstruction.classes_by_names["vdivu.vv"],
        RISCVInstruction.classes_by_names["vdiv.vv"],
        RISCVInstruction.classes_by_names["vremu.vv"],
        RISCVInstruction.classes_by_names["vrem.vv"],
        RISCVInstruction.classes_by_names["vmacc.vv"],
        RISCVInstruction.classes_by_names["vnmsac.vv"],
        RISCVInstruction.classes_by_names["vmadd.vv"],
        RISCVInstruction.classes_by_names["vnmsub.vv"],
        RISCVInstruction.classes_by_names["vadd.vx"],
        RISCVInstruction.classes_by_names["vsub.vx"],
        RISCVInstruction.classes_by_names["vrsub.vx"],
        RISCVInstruction.classes_by_names["vand.vx"],
        RISCVInstruction.classes_by_names["vor.vx"],
        RISCVInstruction.classes_by_names["vxor.vx"],
        RISCVInstruction.classes_by_names["vsll.vx"],
        RISCVInstruction.classes_by_names["vsrl.vx"],
        RISCVInstruction.classes_by_names["vmseq.vx"],
        RISCVInstruction.classes_by_names["vmsne.vx"],
        RISCVInstruction.classes_by_names["vmsltu.vx"],
        RISCVInstruction.classes_by_names["vmslt.vx"],
        RISCVInstruction.classes_by_names["vmsleu.vx"],
        RISCVInstruction.classes_by_names["vmsle.vx"],
        RISCVInstruction.classes_by_names["vmsgtu.vx"],
        RISCVInstruction.classes_by_names["vmsgt.vx"],
        RISCVInstruction.classes_by_names["vmsgeu.vx"],
        RISCVInstruction.classes_by_names["vmsge.vx"],
        RISCVInstruction.classes_by_names["vminu.vx"],
        RISCVInstruction.classes_by_names["vmin.vx"],
        RISCVInstruction.classes_by_names["vmaxu.vx"],
        RISCVInstruction.classes_by_names["vmax.vx"],
        RISCVInstruction.classes_by_names["vmul.vx"],
        RISCVInstruction.classes_by_names["vmulh.vx"],
        RISCVInstruction.classes_by_names["vmulhu.vx"],
        RISCVInstruction.classes_by_names["vmulhsu.vx"],
        RISCVInstruction.classes_by_names["vdivu.vx"],
        RISCVInstruction.classes_by_names["vdiv.vx"],
        RISCVInstruction.classes_by_names["vremu.vx"],
        RISCVInstruction.classes_by_names["vrem.vx"],
        RISCVInstruction.classes_by_names["vmacc.vx"],
        RISCVInstruction.classes_by_names["vnmsac.vx"],
        RISCVInstruction.classes_by_names["vmadd.vx"],
        RISCVInstruction.classes_by_names["vnmsub.vx"],
        RISCVInstruction.classes_by_names["vadd.vi"],
        RISCVInstruction.classes_by_names["vrsub.vi"],
        RISCVInstruction.classes_by_names["vand.vi"],
        RISCVInstruction.classes_by_names["vor.vi"],
        RISCVInstruction.classes_by_names["vxor.vi"],
        RISCVInstruction.classes_by_names["vsll.vi"],
        RISCVInstruction.classes_by_names["vsrl.vi"],
        RISCVInstruction.classes_by_names["vsra.vi"],
        RISCVInstruction.classes_by_names["vmseq.vi"],
        RISCVInstruction.classes_by_names["vmsne.vi"],
        RISCVInstruction.classes_by_names["vmsleu.vi"],
        RISCVInstruction.classes_by_names["vmsle.vi"],
        RISCVInstruction.classes_by_names["vmsgtu.vi"],
        RISCVInstruction.classes_by_names["vmsgt.vi"],
        RISCVInstruction.classes_by_names["vmerge.vvm"],
        RISCVInstruction.classes_by_names["vmerge.vxm"],
        RISCVInstruction.classes_by_names["vmerge.vim"],
        RISCVInstruction.classes_by_names["vrgather.vv"],
        RISCVInstruction.classes_by_names["vrgatherei16.vv"],
        RISCVInstruction.classes_by_names["vrgather.vx"],
        RISCVInstruction.classes_by_names["vrgather.vi"],
    ): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
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
        RISCVInstruction.classes_by_names["remu"],
        RISCVInstruction.classes_by_names["li"],
    ): 2,
    (
        RISCVInstruction.classes_by_names["vle"],
        RISCVInstruction.classes_by_names["vlse"],
        RISCVInstruction.classes_by_names["vluxei"],
        RISCVInstruction.classes_by_names["vloxei"],
        RISCVInstruction.classes_by_names["vse"],
        RISCVInstruction.classes_by_names["vsse"],
        RISCVInstruction.classes_by_names["vsuxei"],
        RISCVInstruction.classes_by_names["vsoxei"],
        RISCVVectorIntegerVectorImmediate,
        RISCVVectorIntegerVectorScalar,
        RISCVVectorIntegerVectorVector,
        RISCVVectorIntegerVectorVectorMasked,
        RISCVVectorIntegerVectorScalarMasked,
        RISCVVectorIntegerVectorImmediateMasked,
    ): 2,
}

rv32_inverse_throughput = {
    RISCVInstruction.classes_by_names["addi"]: 1,
    RISCVInstruction.classes_by_names["srli"]: 1,
    RISCVInstruction.classes_by_names["srai"]: 1,
    RISCVInstruction.classes_by_names["add"]: 1,
    RISCVInstruction.classes_by_names["sll"]: 1,
    RISCVInstruction.classes_by_names["srl"]: 1,
    RISCVInstruction.classes_by_names["sub"]: 1,
    RISCVInstruction.classes_by_names["sra"]: 1,
    RISCVInstruction.classes_by_names["mul"]: 1,
    RISCVInstruction.classes_by_names["div"]: 2,
    RISCVInstruction.classes_by_names["divu"]: 2,
    RISCVInstruction.classes_by_names["rem"]: 2,
    RISCVInstruction.classes_by_names["remu"]: 2,
}

default_latencies = {
    RISCVIntegerRegisterRegister: 1,
    RISCVIntegerRegisterImmediate: 1,
    RISCVUType: 1,
    # RISCVLoad: 3,
    RISCVInstruction.classes_by_names["lb"]: 3,
    RISCVInstruction.classes_by_names["lbu"]: 3,
    RISCVInstruction.classes_by_names["lh"]: 3,
    RISCVInstruction.classes_by_names["lhu"]: 3,
    RISCVInstruction.classes_by_names["lw"]: 2,
    RISCVInstruction.classes_by_names["lwu"]: 2,
    RISCVInstruction.classes_by_names["ld"]: 2,
    RISCVInstruction.classes_by_names["li"]: 2,
    RISCVStore: 1,
    # RISCVIntegerRegisterRegisterMul: 4  # not correct for div, rem
    RISCVInstruction.classes_by_names["mul"]: 4,
    RISCVInstruction.classes_by_names["mulh"]: 4,
    RISCVInstruction.classes_by_names["mulhsu"]: 4,
    RISCVInstruction.classes_by_names["mulhu"]: 4,
    RISCVInstruction.classes_by_names["div"]: 4,
    RISCVInstruction.classes_by_names["divu"]: 4,
    RISCVInstruction.classes_by_names["rem"]: 4,
    RISCVInstruction.classes_by_names["remu"]: 4,
    RISCVInstruction.classes_by_names["vle"]: 2,
    RISCVInstruction.classes_by_names["vlse"]: 2,
    RISCVInstruction.classes_by_names["vluxei"]: 2,
    RISCVInstruction.classes_by_names["vloxei"]: 2,
    RISCVInstruction.classes_by_names["vse"]: 2,
    RISCVInstruction.classes_by_names["vsse"]: 2,
    RISCVInstruction.classes_by_names["vsuxei"]: 2,
    RISCVInstruction.classes_by_names["vsoxei"]: 2,
    RISCVVectorIntegerVectorImmediate: 2,
    RISCVVectorIntegerVectorScalar: 2,
    RISCVVectorIntegerVectorVector: 2,
    RISCVVectorIntegerVectorScalarMasked: 2,
    RISCVVectorIntegerVectorVectorMasked: 2,
    RISCVVectorIntegerVectorImmediateMasked: 2,
}

rv32_latencies = {
    RISCVInstruction.classes_by_names["addi"]: 1,
    RISCVInstruction.classes_by_names["srli"]: 1,
    RISCVInstruction.classes_by_names["srai"]: 1,
    RISCVInstruction.classes_by_names["add"]: 1,
    RISCVInstruction.classes_by_names["sll"]: 1,
    RISCVInstruction.classes_by_names["srl"]: 1,
    RISCVInstruction.classes_by_names["sub"]: 1,
    RISCVInstruction.classes_by_names["sra"]: 1,
    RISCVInstruction.classes_by_names["mul"]: 3,
    RISCVInstruction.classes_by_names["div"]: 4,
    RISCVInstruction.classes_by_names["divu"]: 4,
    RISCVInstruction.classes_by_names["rem"]: 4,
    RISCVInstruction.classes_by_names["remu"]: 4,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    # instclass_src = find_class(src)
    # instclass_dst = find_class(dst)

    if src.is_32_bit():
        latency = lookup_multidict(rv32_latencies, src)
        return latency
    latency = lookup_multidict(default_latencies, src)

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    if src.is_32_bit():
        return lookup_multidict(rv32_inverse_throughput, src)
    return lookup_multidict(inverse_throughput, src)

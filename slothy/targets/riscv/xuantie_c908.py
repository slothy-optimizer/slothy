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
instrs = RISCVInstruction.classes_by_names


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
        instrs["addi"],
        instrs["slti"],
        instrs["sltiu"],
        instrs["andi"],
        instrs["ori"],
        instrs["xori"],
        instrs["slli"],
        instrs["srli"],
        instrs["srai"],
        instrs["andcls"],
        instrs["orcls"],
        instrs["xor"],
        instrs["add"],
        instrs["slt"],
        instrs["sltu"],
        instrs["sll"],
        instrs["srl"],
        instrs["sub"],
        instrs["neg"],
        instrs["sra"],
        instrs["lui"],
        instrs["auipc"],
        instrs["li"],
    ): ExecutionUnit.SCALAR(),
    (
        instrs["lb"],
        instrs["lbu"],
        instrs["lh"],
        instrs["lhu"],
        instrs["lw"],
        instrs["lwu"],
        instrs["ld"],
        instrs["sb"],
        instrs["sh"],
        instrs["sw"],
        instrs["sd"],
    ): ExecutionUnit.LSU,
    (
        instrs["mul"],
        instrs["mulh"],
        instrs["mulhsu"],
        instrs["mulhu"],
        instrs["div"],
        instrs["divu"],
        instrs["rem"],
        instrs["remu"],
    ): [
        [ExecutionUnit.SCALAR_MUL, ExecutionUnit.SCALAR_ALU0],
        [ExecutionUnit.SCALAR_MUL, ExecutionUnit.SCALAR_ALU1],
    ],
    (
        instrs["vadd.vv"],
        instrs["vsub.vv"],
        instrs["vrsub.vv"],
        instrs["vminu.vv"],
        instrs["vmin.vv"],
        instrs["vmaxu.vv"],
        instrs["vmax.vv"],
        instrs["vmul.vv"],
        instrs["vmulh.vv"],
        instrs["vmulhu.vv"],
        instrs["vmulhsu.vv"],
        instrs["vmacc.vv"],
        instrs["vnmsac.vv"],
        instrs["vmadd.vv"],
        instrs["vnmsub.vv"],
        instrs["vadd.vx"],
        instrs["vsub.vx"],
        instrs["vrsub.vx"],
        instrs["vmsgeu.vx"],
        instrs["vmsge.vx"],
        instrs["vminu.vx"],
        instrs["vmin.vx"],
        instrs["vmaxu.vx"],
        instrs["vmax.vx"],
        instrs["vmul.vx"],
        instrs["vmulh.vx"],
        instrs["vmulhu.vx"],
        instrs["vmulhsu.vx"],
        instrs["vmacc.vx"],
        instrs["vnmsac.vx"],
        instrs["vmadd.vx"],
        instrs["vnmsub.vx"],
        instrs["vadd.vi"],
        instrs["vrsub.vi"],
        instrs["vsetvli"],
        instrs["vsetivli"],
        instrs["vsetvl"],
        instrs["vmv.x.s"],
    ): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    (
        instrs["vle"],
        instrs["vlse"],
        instrs["vluxei"],
        instrs["vloxei"],
        instrs["vse"],
        instrs["vsse"],
        instrs["vsuxei"],
        instrs["vsoxei"],
        instrs["vrgatherei16.vv"],
        instrs["vrgather.vv"],
        instrs["vrem.vx"],
        instrs["vremu.vx"],
        instrs["vdiv.vx"],
        instrs["vdivu.vx"],
        instrs["vrem.vv"],
        instrs["vremu.vv"],
        instrs["vdiv.vv"],
        instrs["vdivu.vv"],
        instrs["vand.vv"],
        instrs["vor.vv"],
        instrs["vxor.vv"],
        instrs["vsll.vv"],
        instrs["vsrl.vv"],
        instrs["vmseq.vv"],
        instrs["vmsne.vv"],
        instrs["vmsltu.vv"],
        instrs["vmslt.vv"],
        instrs["vmsleu.vv"],
        instrs["vmsle.vv"],
        instrs["vand.vx"],
        instrs["vor.vx"],
        instrs["vxor.vx"],
        instrs["vsll.vx"],
        instrs["vsrl.vx"],
        instrs["vmseq.vx"],
        instrs["vmsne.vx"],
        instrs["vmsltu.vx"],
        instrs["vmslt.vx"],
        instrs["vmsleu.vx"],
        instrs["vmsle.vx"],
        instrs["vmsgtu.vx"],
        instrs["vmsgt.vx"],
        instrs["vand.vi"],
        instrs["vor.vi"],
        instrs["vxor.vi"],
        instrs["vsll.vi"],
        instrs["vsrl.vi"],
        instrs["vsra.vi"],
        instrs["vmseq.vi"],
        instrs["vmsne.vi"],
        instrs["vmsleu.vi"],
        instrs["vmsle.vi"],
        instrs["vmsgtu.vi"],
        instrs["vmsgt.vi"],
        instrs["vmerge.vvm"],
        instrs["vmerge.vxm"],
        instrs["vmerge.vim"],
        instrs["vrgather.vx"],
        instrs["vrgather.vi"],
        instrs["vmv.s.x"],
        instrs["vl<nf>re<ew>.v"],
        instrs["vl<nf>r.v"],
        instrs["vs<nf>re<ew>.v"],
        instrs["vs<nf>r.v"],
    ): [ExecutionUnit.VEC0],
}

inverse_throughput = {
    (
        instrs["addi"],
        instrs["slti"],
        instrs["sltiu"],
        instrs["andi"],
        instrs["ori"],
        instrs["xori"],
        instrs["slli"],
        instrs["srli"],
        instrs["srai"],
        instrs["andcls"],
        instrs["orcls"],
        instrs["xor"],
        instrs["add"],
        instrs["slt"],
        instrs["sltu"],
        instrs["sll"],
        instrs["srl"],
        instrs["sub"],
        instrs["neg"],
        instrs["sra"],
        instrs["lui"],
        instrs["auipc"],
    ): 1,
    (
        instrs["lb"],
        instrs["lbu"],
        instrs["lh"],
        instrs["lhu"],
        instrs["lw"],
        instrs["lwu"],
        instrs["ld"],
        instrs["sb"],
        instrs["sh"],
        instrs["sw"],
        instrs["sd"],
    ): 1,
    (
        instrs["mul"],
        instrs["mulh"],
        instrs["mulhsu"],
        instrs["mulhu"],
        instrs["div"],
        instrs["divu"],
        instrs["rem"],
        instrs["remu"],
        instrs["li"],
    ): 2,
    (
        instrs["vle"],
        instrs["vlse"],
        instrs["vluxei"],
        instrs["vloxei"],
        instrs["vse"],
        instrs["vsse"],
        instrs["vsuxei"],
        instrs["vsoxei"],  # TODO: some of the above values are estimated
        instrs["vadd.vv"],
        instrs["vsub.vv"],
        instrs["vrsub.vv"],
        instrs["vminu.vv"],
        instrs["vmin.vv"],
        instrs["vmaxu.vv"],
        instrs["vmax.vv"],
        instrs["vmul.vv"],
        instrs["vmulh.vv"],
        instrs["vmulhu.vv"],
        instrs["vmulhsu.vv"],
        instrs["vmacc.vv"],
        instrs["vnmsac.vv"],
        instrs["vmadd.vv"],
        instrs["vnmsub.vv"],
        instrs["vadd.vx"],
        instrs["vsub.vx"],
        instrs["vrsub.vx"],
        instrs["vmsgeu.vx"],
        instrs["vmsge.vx"],
        instrs["vminu.vx"],
        instrs["vmin.vx"],
        instrs["vmaxu.vx"],
        instrs["vmax.vx"],
        instrs["vmul.vx"],
        instrs["vmulh.vx"],
        instrs["vmulhu.vx"],
        instrs["vmulhsu.vx"],
        instrs["vmacc.vx"],
        instrs["vnmsac.vx"],
        instrs["vmadd.vx"],
        instrs["vnmsub.vx"],
        instrs["vadd.vi"],
        instrs["vrsub.vi"],
        instrs["vs<nf>re<ew>.v"],
        instrs["vs<nf>r.v"],
        instrs["vl<nf>re<ew>.v"],
        instrs["vl<nf>r.v"],
    ): 2,
    (
        instrs["vand.vv"],
        instrs["vor.vv"],
        instrs["vxor.vv"],
        instrs["vsll.vv"],
        instrs["vsrl.vv"],
        instrs["vmseq.vv"],
        instrs["vmsne.vv"],
        instrs["vmsltu.vv"],
        instrs["vmslt.vv"],
        instrs["vmsleu.vv"],
        instrs["vmsle.vv"],
        instrs["vand.vx"],
        instrs["vor.vx"],
        instrs["vxor.vx"],
        instrs["vsll.vx"],
        instrs["vsrl.vx"],
        instrs["vmseq.vx"],
        instrs["vmsne.vx"],
        instrs["vmsltu.vx"],
        instrs["vmslt.vx"],
        instrs["vmsleu.vx"],
        instrs["vmsle.vx"],
        instrs["vmsgtu.vx"],
        instrs["vmsgt.vx"],
        instrs["vand.vi"],
        instrs["vor.vi"],
        instrs["vxor.vi"],
        instrs["vsll.vi"],
        instrs["vsrl.vi"],
        instrs["vsra.vi"],
        instrs["vmseq.vi"],
        instrs["vmsne.vi"],
        instrs["vmsleu.vi"],
        instrs["vmsle.vi"],
        instrs["vmsgtu.vi"],
        instrs["vmsgt.vi"],
        instrs["vmerge.vvm"],
        instrs["vmerge.vxm"],
        instrs["vmerge.vim"],
        instrs["vrgather.vx"],
        instrs["vrgather.vi"],
        instrs["vmv.x.s"],
    ): 1,
    instrs["vdivu.vv"]: 21,
    instrs["vdiv.vv"]: 23,
    instrs["vremu.vv"]: 23,
    instrs["vrem.vv"]: 25,
    instrs["vdivu.vx"]: 21,
    instrs["vdiv.vx"]: 23,
    instrs["vremu.vx"]: 23,
    instrs["vrem.vx"]: 25,
    instrs["vrgather.vv"]: 4,
    instrs["vrgatherei16.vv"]: 4,
    instrs["vsetvli"]: 2,  # TODO: estimated
    instrs["vsetivli"]: 2,  # TODO: estimated
    instrs["vsetvl"]: 2,  # TODO: estimated
    instrs["vmv.s.x"]: 6,
    instrs["vl<nf>re<ew>.v"]: 2,  # TODO: estimated
    instrs["vl<nf>r.v"]: 2,  # TODO: estimated
    instrs["vs<nf>re<ew>.v"]: 2,  # TODO: estimated
    instrs["vs<nf>r.v"]: 2,  # TODO: estimated
}

rv32_inverse_throughput = {
    instrs["addi"]: 1,
    instrs["srli"]: 1,
    instrs["srai"]: 1,
    instrs["add"]: 1,
    instrs["sll"]: 1,
    instrs["srl"]: 1,
    instrs["sub"]: 1,
    instrs["neg"]: 1,
    instrs["sra"]: 1,
    instrs["mul"]: 1,
    instrs["div"]: 2,
    instrs["divu"]: 2,
    instrs["rem"]: 2,
    instrs["remu"]: 2,
}

default_latencies = {
    RISCVIntegerRegister: 1,
    RISCVIntegerRegisterRegister: 1,
    RISCVIntegerRegisterImmediate: 1,
    RISCVUType: 1,
    # RISCVLoad: 3,
    instrs["lb"]: 3,
    instrs["lbu"]: 3,
    instrs["lh"]: 3,
    instrs["lhu"]: 3,
    instrs["lw"]: 2,
    instrs["lwu"]: 2,
    instrs["ld"]: 2,
    instrs["li"]: 2,
    RISCVStore: 1,
    # RISCVIntegerRegisterRegisterMul: 4  # not correct for div, rem
    instrs["mul"]: 4,
    instrs["mulh"]: 4,
    instrs["mulhsu"]: 4,
    instrs["mulhu"]: 4,
    instrs["div"]: 4,
    instrs["divu"]: 4,
    instrs["rem"]: 4,
    instrs["remu"]: 4,
    RISCVVectorIntegerVectorImmediate: 4,
    RISCVVectorIntegerVectorScalar: 4,
    RISCVVectorIntegerVectorVector: 4,
    RISCVVectorIntegerVectorScalarMasked: 4,
    RISCVVectorIntegerVectorVectorMasked: 4,
    RISCVVectorIntegerVectorImmediateMasked: 4,
    RISCVVectorLoadUnitStride: 3,  # TODO: estimated
    RISCVVectorLoadStrided: 3,  # TODO: estimated
    RISCVVectorLoadIndexed: 3,  # TODO: estimated
    RISCVVectorLoadWholeRegister: 3,  # TODO: estimated
    RISCVVectorStoreUnitStride: 1,  # TODO: estimated
    RISCVVectorStoreStrided: 1,  # TODO: estimated
    RISCVVectorStoreIndexed: 1,  # TODO: estimated
    RISCVVectorStoreWholeRegister: 1,  # TODO: estimated
    instrs["vsetvli"]: 4,  # TODO: estimated
    instrs["vsetivli"]: 4,  # TODO: estimated
    instrs["vsetvl"]: 4,  # TODO: estimated
    RISCVScalarVector: 4,  # TODO: estimated
    RISCVVectorScalar: 4,  # TODO: estimated
}

rv32_latencies = {
    instrs["addi"]: 1,
    instrs["srli"]: 1,
    instrs["srai"]: 1,
    instrs["add"]: 1,
    instrs["sll"]: 1,
    instrs["srl"]: 1,
    instrs["sub"]: 1,
    instrs["sra"]: 1,
    instrs["mul"]: 3,
    instrs["div"]: 4,
    instrs["divu"]: 4,
    instrs["rem"]: 4,
    instrs["remu"]: 4,
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

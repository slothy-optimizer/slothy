# flake8: noqa: F405
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
Experimental XuanTie C908 microarchitecture model for SLOTHY

Some data in this model is derived from the XuanTie C908 manual, other is derived from microbenchmarks.

WARNING: The data in this module is approximate and may contain errors.
"""

################################### NOTE ###############################################  # noqa: E266
###                                                                                  ###  # noqa: E266
### WARNING: The data in this module is approximate and may contain errors.          ###  # noqa: E266
###          They are _NOT_ an official software optimization guide for C908.        ###  # noqa: E266
###                                                                                  ###  # noqa: E266
########################################################################################  # noqa: E266

from enum import Enum
from slothy.targets.riscv.riscv import *  # noqa: F403
from slothy.targets.riscv.rv32_64_i_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_m_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_b_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_v_instructions import *  # noqa: F403
from slothy.targets.riscv.rv32_64_pseudo_instructions import *  # noqa: F403

# XuanTie C908 can issue up to 2 instructions per cycle (dual-issue)
issue_rate = 2
llvm_mca_target = ""
instrs = RISCVInstruction.classes_by_names
lmul = None
sew = None
tpol = None
mpol = None


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


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(config):
    """Adds C908-"""
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    (  # TODO: use existing instructions list or superclass
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
        # Zbkb extension - Bit manipulation for cryptography
        # TODO: Verify performance characteristics for C908
        RISCVInstruction.classes_by_names["rol"],
        RISCVInstruction.classes_by_names["ror"],
        RISCVInstruction.classes_by_names["rori"],
        RISCVInstruction.classes_by_names["andn"],
        RISCVInstruction.classes_by_names["orn"],
        RISCVInstruction.classes_by_names["xnor"],
        RISCVInstruction.classes_by_names["pack"],
        RISCVInstruction.classes_by_names["packh"],
        RISCVInstruction.classes_by_names["brev8"],
        RISCVInstruction.classes_by_names["rev8"],
        RISCVInstruction.classes_by_names["zip"],
        RISCVInstruction.classes_by_names["unzip"],
        # Branch-instructions
        instrs["beq"],  # guessed but also not important
        instrs["bne"],  # guessed but also not important
        instrs["blt"],  # guessed but also not important
        instrs["bge"],  # guessed but also not important
        instrs["bltu"],  # guessed but also not important
        instrs["bgeu"],  # guessed but also not important
        instrs["bnez"],  # guessed but also not important
        instrs["beqz"],  # guessed but also not important
        # Pseudo-instructions
        RISCVInstruction.classes_by_names["li"],
        RISCVInstruction.classes_by_names["mv"],
        RISCVInstruction.classes_by_names["neg"],
        RISCVInstruction.classes_by_names["not"],
        RISCVInstruction.classes_by_names["la"],
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
    ): ExecutionUnit.SCALAR_MUL,
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
        instrs["vmv.s.x"],
        instrs["vmv.x.s"],
        instrs["vmv.v.v"],
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
        instrs["vnot.v"],
    ): [ExecutionUnit.VEC0],
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
        # Zbkb extension - Bit manipulation for cryptography
        # TODO: Verify performance characteristics for C908
        RISCVInstruction.classes_by_names["rol"],
        RISCVInstruction.classes_by_names["ror"],
        RISCVInstruction.classes_by_names["rori"],
        RISCVInstruction.classes_by_names["andn"],
        RISCVInstruction.classes_by_names["orn"],
        RISCVInstruction.classes_by_names["xnor"],
        RISCVInstruction.classes_by_names["pack"],
        RISCVInstruction.classes_by_names["packh"],
        RISCVInstruction.classes_by_names["brev8"],
        RISCVInstruction.classes_by_names["rev8"],
        RISCVInstruction.classes_by_names["zip"],
        RISCVInstruction.classes_by_names["unzip"],
        # Pseudo-instructions
        RISCVInstruction.classes_by_names["li"],
        RISCVInstruction.classes_by_names["mv"],
        RISCVInstruction.classes_by_names["neg"],
        RISCVInstruction.classes_by_names["not"],
        RISCVInstruction.classes_by_names["la"],
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
        # branch instructions
        instrs["beq"],  # guessed but also not important
        instrs["bne"],  # guessed but also not important
        instrs["blt"],  # guessed but also not important
        instrs["bge"],  # guessed but also not important
        instrs["bltu"],  # guessed but also not important
        instrs["bgeu"],  # guessed but also not important
        instrs["bnez"],  # guessed but also not important
        instrs["beqz"],  # guessed but also not important
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
        instrs["vnot.v"],
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
    instrs["vmv.v.v"]: 2,
    instrs["vl<nf>re<ew>.v"]: 2,  # TODO: estimated
    instrs["vl<nf>r.v"]: 2,  # TODO: estimated
    instrs["vs<nf>re<ew>.v"]: 2,  # TODO: estimated
    instrs["vs<nf>r.v"]: 2,  # TODO: estimated
}

rv32_inverse_throughput = {
    RISCVInstruction.classes_by_names["addi"]: 1,
    RISCVInstruction.classes_by_names["srli"]: 1,
    RISCVInstruction.classes_by_names["slli"]: 1,
    RISCVInstruction.classes_by_names["srai"]: 1,
    RISCVInstruction.classes_by_names["add"]: 1,
    RISCVInstruction.classes_by_names["sll"]: 1,
    RISCVInstruction.classes_by_names["srl"]: 1,
    RISCVInstruction.classes_by_names["sub"]: 1,
    RISCVInstruction.classes_by_names["neg"]: 1,
    RISCVInstruction.classes_by_names["sra"]: 1,
    RISCVInstruction.classes_by_names["mul"]: 1,
    RISCVInstruction.classes_by_names["div"]: 2,
    RISCVInstruction.classes_by_names["divu"]: 2,
    RISCVInstruction.classes_by_names["rem"]: 2,
    RISCVInstruction.classes_by_names["remu"]: 2,
    RISCVInstruction.classes_by_names["rol"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["ror"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["rori"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["pack"]: 1,  # TODO: estimated
}

default_latencies = {
    RISCVIntegerRegisterRegister: 1,
    RISCVIntegerRegisterImmediate: 1,
    RISCVIntegerRegister: 1,  # For Zbkb and pseudo-instructions
    RISCVUType: 1,
    RISCVLoad: 3,
    RISCVStore: 1,
    # TODO: Split mul and div/rem instructions into separate entries with correct latencies
    # Current value is approximation for mul; div/rem may have different latencies
    RISCVIntegerRegisterRegisterMul: 4,
    RISCVLiPseudo: 1,  # Pseudo-instruction
    RISCVULaPseudo: 1,  # Pseudo-instruction
    RISCVBranch: 3,  # guessed but also not important
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
    instrs["vmv.s.x"]: 3,  # TODO: estimated
    instrs["vmv.x.s"]: 3,  # TODO: estimated
    instrs["vmv.v.v"]: 3,  # TODO: estimated
    instrs["vnot.v"]: 4,
    instrs["vnmsac.vx"]: 4,  # TODO: estimated
}

rv32_latencies = {
    RISCVInstruction.classes_by_names["addi"]: 1,
    RISCVInstruction.classes_by_names["srli"]: 1,
    RISCVInstruction.classes_by_names["slli"]: 1,
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
    RISCVInstruction.classes_by_names["rol"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["ror"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["rori"]: 1,  # TODO: estimated
    RISCVInstruction.classes_by_names["pack"]: 1,  # TODO: estimated
}


def get_latency(src, out_idx: int, dst) -> int:
    """Get instruction latency for XuanTie C908.

    :param src: Source instruction
    :param out_idx: Output index (unused)
    :type out_idx: int
    :param dst: Destination instruction (unused)

    :return: Latency in cycles
    :rtype: int
    """
    _ = out_idx  # out_idx unused
    _ = dst  # dst is unused

    if src.is_32_bit():
        latency = lookup_multidict(rv32_latencies, src)
        return latency
    latency = lookup_multidict(default_latencies, src)

    return latency


def get_units(src) -> list:
    """Get execution units that can execute this instruction.

    :param src: Source instruction

    :return: List of execution units
    :rtype: list
    """
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src) -> int:
    """Get inverse throughput (cycles between issuing same instruction type).

    :param src: Source instruction

    :return: Inverse throughput in cycles
    :rtype: int
    """
    if src.is_32_bit():
        return lookup_multidict(rv32_inverse_throughput, src)
    return lookup_multidict(inverse_throughput, src)

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
        RISCVInstruction.classes_by_names["beq"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bne"],  # guessed but also not important
        RISCVInstruction.classes_by_names["blt"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bge"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bltu"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bgeu"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bnez"],  # guessed but also not important
        RISCVInstruction.classes_by_names["beqz"],  # guessed but also not important
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
        RISCVInstruction.classes_by_names["vadd.vv"],
        RISCVInstruction.classes_by_names["vsub.vv"],
        RISCVInstruction.classes_by_names["vrsub.vv"],
        RISCVInstruction.classes_by_names["vminu.vv"],
        RISCVInstruction.classes_by_names["vmin.vv"],
        RISCVInstruction.classes_by_names["vmaxu.vv"],
        RISCVInstruction.classes_by_names["vmax.vv"],
        RISCVInstruction.classes_by_names["vmul.vv"],
        RISCVInstruction.classes_by_names["vmulh.vv"],
        RISCVInstruction.classes_by_names["vmulhu.vv"],
        RISCVInstruction.classes_by_names["vmulhsu.vv"],
        RISCVInstruction.classes_by_names["vmacc.vv"],
        RISCVInstruction.classes_by_names["vnmsac.vv"],
        RISCVInstruction.classes_by_names["vmadd.vv"],
        RISCVInstruction.classes_by_names["vnmsub.vv"],
        RISCVInstruction.classes_by_names["vadd.vx"],
        RISCVInstruction.classes_by_names["vsub.vx"],
        RISCVInstruction.classes_by_names["vrsub.vx"],
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
        RISCVInstruction.classes_by_names["vmacc.vx"],
        RISCVInstruction.classes_by_names["vnmsac.vx"],
        RISCVInstruction.classes_by_names["vmadd.vx"],
        RISCVInstruction.classes_by_names["vnmsub.vx"],
        RISCVInstruction.classes_by_names["vadd.vi"],
        RISCVInstruction.classes_by_names["vrsub.vi"],
        RISCVInstruction.classes_by_names["vsetvli"],
        RISCVInstruction.classes_by_names["vsetivli"],
        RISCVInstruction.classes_by_names["vsetvl"],
        RISCVInstruction.classes_by_names["vmv.s.x"],
        RISCVInstruction.classes_by_names["vmv.x.s"],
        RISCVInstruction.classes_by_names["vmv.v.v"],
    ): [ExecutionUnit.VEC0, ExecutionUnit.VEC1],
    (
        RISCVInstruction.classes_by_names["vle"],
        RISCVInstruction.classes_by_names["vlse"],
        RISCVInstruction.classes_by_names["vluxei"],
        RISCVInstruction.classes_by_names["vloxei"],
        RISCVInstruction.classes_by_names["vse"],
        RISCVInstruction.classes_by_names["vsse"],
        RISCVInstruction.classes_by_names["vsuxei"],
        RISCVInstruction.classes_by_names["vsoxei"],
        RISCVInstruction.classes_by_names["vrgatherei16.vv"],
        RISCVInstruction.classes_by_names["vrgather.vv"],
        RISCVInstruction.classes_by_names["vrem.vx"],
        RISCVInstruction.classes_by_names["vremu.vx"],
        RISCVInstruction.classes_by_names["vdiv.vx"],
        RISCVInstruction.classes_by_names["vdivu.vx"],
        RISCVInstruction.classes_by_names["vrem.vv"],
        RISCVInstruction.classes_by_names["vremu.vv"],
        RISCVInstruction.classes_by_names["vdiv.vv"],
        RISCVInstruction.classes_by_names["vdivu.vv"],
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
        RISCVInstruction.classes_by_names["vrgather.vx"],
        RISCVInstruction.classes_by_names["vrgather.vi"],
        RISCVInstruction.classes_by_names["vmv.s.x"],
        RISCVInstruction.classes_by_names["vl<nf>re<ew>.v"],
        RISCVInstruction.classes_by_names["vl<nf>r.v"],
        RISCVInstruction.classes_by_names["vs<nf>re<ew>.v"],
        RISCVInstruction.classes_by_names["vs<nf>r.v"],
        RISCVInstruction.classes_by_names["vnot.v"],
        RISCVInstruction.classes_by_names["vssrl.vv"],  # guessed
        RISCVInstruction.classes_by_names["vssra.vv"],  # guessed
        RISCVInstruction.classes_by_names["vssrl.vi"],  # guessed
        RISCVInstruction.classes_by_names["vssra.vi"],  # guessed
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
        RISCVInstruction.classes_by_names["beq"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bne"],  # guessed but also not important
        RISCVInstruction.classes_by_names["blt"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bge"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bltu"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bgeu"],  # guessed but also not important
        RISCVInstruction.classes_by_names["bnez"],  # guessed but also not important
        RISCVInstruction.classes_by_names["beqz"],  # guessed but also not important
    ): 2,
    (
        RISCVInstruction.classes_by_names["vle"],
        RISCVInstruction.classes_by_names["vlse"],
        RISCVInstruction.classes_by_names["vluxei"],
        RISCVInstruction.classes_by_names["vloxei"],
        RISCVInstruction.classes_by_names["vse"],
        RISCVInstruction.classes_by_names["vsse"],
        RISCVInstruction.classes_by_names["vsuxei"],
        RISCVInstruction.classes_by_names[
            "vsoxei"
        ],  # TODO: some of the above values are estimated
        RISCVInstruction.classes_by_names["vadd.vv"],
        RISCVInstruction.classes_by_names["vsub.vv"],
        RISCVInstruction.classes_by_names["vrsub.vv"],
        RISCVInstruction.classes_by_names["vminu.vv"],
        RISCVInstruction.classes_by_names["vmin.vv"],
        RISCVInstruction.classes_by_names["vmaxu.vv"],
        RISCVInstruction.classes_by_names["vmax.vv"],
        RISCVInstruction.classes_by_names["vmul.vv"],
        RISCVInstruction.classes_by_names["vmulh.vv"],
        RISCVInstruction.classes_by_names["vmulhu.vv"],
        RISCVInstruction.classes_by_names["vmulhsu.vv"],
        RISCVInstruction.classes_by_names["vmacc.vv"],
        RISCVInstruction.classes_by_names["vnmsac.vv"],
        RISCVInstruction.classes_by_names["vmadd.vv"],
        RISCVInstruction.classes_by_names["vnmsub.vv"],
        RISCVInstruction.classes_by_names["vadd.vx"],
        RISCVInstruction.classes_by_names["vsub.vx"],
        RISCVInstruction.classes_by_names["vrsub.vx"],
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
        RISCVInstruction.classes_by_names["vmacc.vx"],
        RISCVInstruction.classes_by_names["vnmsac.vx"],
        RISCVInstruction.classes_by_names["vmadd.vx"],
        RISCVInstruction.classes_by_names["vnmsub.vx"],
        RISCVInstruction.classes_by_names["vadd.vi"],
        RISCVInstruction.classes_by_names["vrsub.vi"],
        RISCVInstruction.classes_by_names["vs<nf>re<ew>.v"],
        RISCVInstruction.classes_by_names["vs<nf>r.v"],
        RISCVInstruction.classes_by_names["vl<nf>re<ew>.v"],
        RISCVInstruction.classes_by_names["vl<nf>r.v"],
    ): 2,
    (
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
        RISCVInstruction.classes_by_names["vrgather.vx"],
        RISCVInstruction.classes_by_names["vrgather.vi"],
        RISCVInstruction.classes_by_names["vmv.x.s"],
        RISCVInstruction.classes_by_names["vnot.v"],
        RISCVInstruction.classes_by_names["vssrl.vv"],  # guessed
        RISCVInstruction.classes_by_names["vssra.vv"],  # guessed
        RISCVInstruction.classes_by_names["vssrl.vi"],  # guessed
        RISCVInstruction.classes_by_names["vssra.vi"],  # guessed

    ): 1,
    RISCVInstruction.classes_by_names["vdivu.vv"]: 21,
    RISCVInstruction.classes_by_names["vdiv.vv"]: 23,
    RISCVInstruction.classes_by_names["vremu.vv"]: 23,
    RISCVInstruction.classes_by_names["vrem.vv"]: 25,
    RISCVInstruction.classes_by_names["vdivu.vx"]: 21,
    RISCVInstruction.classes_by_names["vdiv.vx"]: 23,
    RISCVInstruction.classes_by_names["vremu.vx"]: 23,
    RISCVInstruction.classes_by_names["vrem.vx"]: 25,
    RISCVInstruction.classes_by_names["vrgather.vv"]: 4,
    RISCVInstruction.classes_by_names["vrgatherei16.vv"]: 4,
    RISCVInstruction.classes_by_names["vsetvli"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vsetivli"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vsetvl"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vmv.s.x"]: 6,
    RISCVInstruction.classes_by_names["vmv.v.v"]: 2,
    RISCVInstruction.classes_by_names["vl<nf>re<ew>.v"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vl<nf>r.v"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vs<nf>re<ew>.v"]: 2,  # TODO: estimated
    RISCVInstruction.classes_by_names["vs<nf>r.v"]: 2,  # TODO: estimated
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
    RISCVInstruction.classes_by_names["vsetvli"]: 4,  # TODO: estimated
    RISCVInstruction.classes_by_names["vsetivli"]: 4,  # TODO: estimated
    RISCVInstruction.classes_by_names["vsetvl"]: 4,  # TODO: estimated
    RISCVScalarVector: 4,  # TODO: estimated
    RISCVVectorScalar: 4,  # TODO: estimated
    RISCVInstruction.classes_by_names["vmv.s.x"]: 3,  # TODO: estimated
    RISCVInstruction.classes_by_names["vmv.x.s"]: 3,  # TODO: estimated
    RISCVInstruction.classes_by_names["vmv.v.v"]: 3,  # TODO: estimated
    RISCVInstruction.classes_by_names["vnot.v"]: 4,
    RISCVInstruction.classes_by_names["vnmsac.vx"]: 4,  # TODO: estimated
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

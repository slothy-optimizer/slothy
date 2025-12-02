#
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
# Author: Justus Bergermann <mail@justus-bergermann.de>
#

"""This module creates the RV3264 pseudo instructions"""

from slothy.targets.riscv.riscv_super_instructions import RISCVIntegerRegister
from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction


class RISCVLiPseudo(RISCVInstruction):
    pattern = "li <Xd>, <imm>"
    inputs = []
    outputs = ["Xd"]


class RISCVULaPseudo(RISCVInstruction):
    pattern = "mnemonic <Xd>, <imm>"
    outputs = ["Xd"]


pseudo_instrs = [
    (["li"], RISCVLiPseudo),
    (["neg", "not", "mv"], RISCVIntegerRegister),
    (["la"], RISCVULaPseudo),
    # translates to auipc + addi instruction; uses information
    # during compilation that are not easily
    # available during parsing. Thus, latency, inverse
    # throughput etc. are estimated
]


def generate_rv32_64_pseudo_instructions():
    """
    Generates all instruction classes for the rv32_64 pseudo instructions
    """

    for elem in pseudo_instrs:
        RISCVInstruction.instr_factory(elem[0], elem[1])

    RISCVInstruction.classes_by_names.update(
        {cls.__name__: cls for cls in RISCVInstruction.dynamic_instr_classes}
    )
    return RISCVInstruction.dynamic_instr_classes


generate_rv32_64_pseudo_instructions()

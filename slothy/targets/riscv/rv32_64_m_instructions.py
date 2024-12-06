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

"""This module creates the RV3264-M extension set instructions"""

from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.riscv_super_instructions import *
from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction

# the following lists maybe could be encapsulated somehow
IntegerRegisterRegisterInstructions = ["mul<w>", "mulh", "mulhsu", "mulhu", "div<w>", "divu<w>", "rem<w>", "remu<w>"]


def generate_rv32_64_m_instructions():
    """
    Generates all instruction classes for the rv32_64_m extension set
    """

    RISCVInstruction.instr_factory(IntegerRegisterRegisterInstructions, RISCVIntegerRegisterRegisterMul)
    RISCVInstruction.classes_by_names.update({cls.__name__: cls for cls in RISCVInstruction.dynamic_instr_classes})
    return RISCVInstruction.dynamic_instr_classes


generate_rv32_64_m_instructions()

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
from slothy.helper import SourceLine
from slothy.targets.riscv.riscv_super_instructions import *  # noqa: F403
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
    (["neg"], RISCVIntegerRegister),
    (["vnot.v"], RISCVectorVectorMasked),
    (["la"], RISCVULaPseudo),
]


def li_pseudo_split_cb():
    def core(inst, t, log=None):
        out_reg = inst.args_out[0]
        imm = int(eval(inst.immediate))
        insts = []
        # if imm fits in signed 12-bit immediate, just use addi
        if -2048 <= imm <= 2047:
            addi = RISCVInstruction.build(
                RISCVInstruction.classes_by_names["addi"],
                {"Xd": out_reg, "Xa": out_reg, "imm": imm, "is32bit": None},
            )
            print(addi)
            insts.append(addi)
        else:
            lower_12 = imm & 0xFFF  # lower 12 bits (0-11)
            upper_20 = imm >> 12  # upper 20 bits (12-31)

            # If sign bit of lower 12 bits is set (bit 11)
            if lower_12 & 0x800:
                upper_20 += 1  # compensate by incrementing upper part
                lower_12 -= 0x1000  # convert lower 12 bits to signed negative number
            lui = RISCVInstruction.build(
                RISCVInstruction.classes_by_names["lui"],
                {"Xd": out_reg, "imm": upper_20},
            )
            addi = RISCVInstruction.build(
                RISCVInstruction.classes_by_names["addi"],
                {"Xd": out_reg, "Xa": out_reg, "imm": lower_12, "is32bit": None},
            )
            insts.append(lui)
            insts.append(addi)

        for i in insts:
            i_src = (
                SourceLine(i.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            i.source_line = i_src

        t.changed = True
        t.inst = insts
        return True

    return core


def la_pseudo_split_cb():
    pass


RISCVLiPseudo.global_fusion_cb = li_pseudo_split_cb()


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

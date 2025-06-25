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

"""This module contains abstract RISC-V instruction types to represent
instructions which share the same pattern"""

from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction


class RISCVStore(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    pattern = "mnemonic <Xb>, <imm>(<Xa>)"
    inputs = ["Xb", "Xa"]


# Scalar instructions


class RISCVIntegerRegister(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVIntegerRegisterImmediate(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVIntegerRegisterRegister(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class RISCVLoad(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVUType(RISCVInstruction):
    pattern = "mnemonic <Xd>, <imm>"
    outputs = ["Xd"]


class RISCVIntegerRegisterRegisterMul(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


# Vector instructions ####

# Load Instructions ##


class RISCVVectorLoadUnitStride(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>)<vm>"
    inputs = ["Xa"]
    outputs = ["Vd"]


class RISCVVectorLoadStrided(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>), <Xb><vm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Vd"]


class RISCVVectorLoadIndexed(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>), <Ve><vm>"
    inputs = ["Xa", "Ve"]
    outputs = ["Vd"]


class RISCVVectorLoadWholeRegister(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>)"
    inputs = ["Xa"]
    outputs = ["Vd"]


# Store Instructions ##


class RISCVVectorStoreUnitStride(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Va>, (<Xa>)<vm>"
    inputs = ["Xa", "Va"]
    outputs = []


class RISCVVectorStoreStrided(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>), <Xb><vm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Vd"]


class RISCVVectorStoreIndexed(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>), <Ve><vm>"
    inputs = ["Xa", "Ve"]
    outputs = ["Vd"]


class RISCVVectorStoreWholeRegister(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Vd>, (<Xa>)"
    inputs = ["Xa"]
    outputs = ["Vd"]


# Vector Integer Instructions ##


class RISCVVectorIntegerVectorVector(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Vf><vm>"
    inputs = ["Ve", "Vf"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorVectorMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Vf>, v0"
    inputs = ["Ve", "Vf"]
    outputs = ["Vd"]


class RISCVVectorIntegerVectorScalar(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Xa><vm>"
    inputs = ["Ve", "Xa"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorScalarMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Xa>, v0"
    inputs = ["Ve", "Xa"]
    outputs = ["Vd"]


class RISCVVectorIntegerVectorImmediate(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <imm><vm>"
    inputs = ["Ve"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorImmediateMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <imm>, v0"
    inputs = ["Ve"]
    outputs = ["Vd"]


# Vector Permutation Instructions


class RISCVScalarVector(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Ve>"
    inputs = ["Ve"]
    outputs = ["Xd"]


class RISCVVectorScalar(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]

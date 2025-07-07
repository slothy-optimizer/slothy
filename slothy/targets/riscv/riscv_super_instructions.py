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
from slothy.targets.riscv.riscv import RegisterType
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
    def write(self):
        out = self.pattern
        l = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )

        for arg, (s, ty) in l[:2]:
            out = RISCVInstruction._instantiate_pattern(s, ty, arg, out)

        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x

            if t is None:
                t = t_default

            a = getattr(self, attr_name)
            if a is None and attr_name == "is32bit":
                return txt.replace("<w>", "")
            if a is None:
                return txt
            if not isinstance(a, list):
                txt = txt.replace(f"<{mnemonic_key}>", t(a))
                return txt
            for i, v in enumerate(a):
                txt = txt.replace(f"<{mnemonic_key}{i}>", t(v))
            return txt

        out = replace_pattern(out, "immediate", "imm", lambda x: f"{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "is32bit", "w", lambda x: x.lower())
        out = replace_pattern(out, "len", "len")
        out = replace_pattern(out, "vm", "vm")
        out = replace_pattern(out, "vtype", "vtype")
        out = replace_pattern(out, "sew", "sew")
        out = replace_pattern(out, "lmul", "lmul")
        out = replace_pattern(out, "tpol", "tpol")
        out = replace_pattern(out, "mpol", "mpol")
        out = replace_pattern(out, "nf", "nf")
        out = replace_pattern(out, "ew", "ew")

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        regs_types, expanded_regs = RISCVInstruction._expand_reg(
            obj.args_out[0], obj.nf, "load"
        )
        obj.args_out = expanded_regs
        obj.num_out = len(obj.args_out)
        obj.arg_types_out = regs_types
        available_regs = RegisterType.list_registers(RegisterType.VECT)
        obj.args_out_combinations = [
            (
                list(range(0, int(obj.num_out))),
                [
                    [available_regs[i + j] for i in range(0, int(obj.nf))]  # +[mem_reg]
                    for j in range(0, len(available_regs) - int(obj.nf))
                ],
            )
        ]
        obj.args_out_restrictions = [None for _ in range(obj.num_out)]
        vlist = [
            "V" + chr(i) for i in range(ord("d"), ord("z") + 1)
        ]  # list of all V registers names
        obj.outputs = vlist[: int(obj.nf)]
        obj.pattern_outputs = list(zip(obj.outputs, obj.arg_types_out))
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


class RISCVVectorStoreWholeRegister(RISCVInstruction):
    def write(self):
        out = self.pattern
        l = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )

        for arg, (s, ty) in [l[-1], l[0]]:
            out = RISCVInstruction._instantiate_pattern(s, ty, arg, out)

        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x

            if t is None:
                t = t_default

            a = getattr(self, attr_name)
            if a is None and attr_name == "is32bit":
                return txt.replace("<w>", "")
            if a is None:
                return txt
            if not isinstance(a, list):
                txt = txt.replace(f"<{mnemonic_key}>", t(a))
                return txt
            for i, v in enumerate(a):
                txt = txt.replace(f"<{mnemonic_key}{i}>", t(v))
            return txt

        out = replace_pattern(out, "immediate", "imm", lambda x: f"{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "is32bit", "w", lambda x: x.lower())
        out = replace_pattern(out, "len", "len")
        out = replace_pattern(out, "vm", "vm")
        out = replace_pattern(out, "vtype", "vtype")
        out = replace_pattern(out, "sew", "sew")
        out = replace_pattern(out, "lmul", "lmul")
        out = replace_pattern(out, "tpol", "tpol")
        out = replace_pattern(out, "mpol", "mpol")
        out = replace_pattern(out, "nf", "nf")
        out = replace_pattern(out, "ew", "ew")

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        # obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        regs_types, expanded_regs = RISCVInstruction._expand_reg(
            obj.args_in[0], obj.nf, "store"
        )
        mem_reg = obj.args_in[1]
        obj.args_in = expanded_regs + [
            mem_reg
        ]  # add the register holding the memory address
        obj.num_in = len(obj.args_in)
        obj.arg_types_in = regs_types
        available_regs = RegisterType.list_registers(RegisterType.VECT)
        obj.args_in_combinations = [
            (
                list(range(0, int(obj.num_in - 1))),
                [
                    [available_regs[i + j] for i in range(0, int(obj.nf))]
                    for j in range(0, len(available_regs) - int(obj.nf))
                ],
            )
        ]
        obj.args_in_restrictions = [None for _ in range(obj.num_in)]

        vlist = [
            "V" + chr(i) for i in range(ord("d"), ord("z") + 1)
        ]  # list of all V registers names
        obj.inputs = vlist[: int(obj.nf)] + ["Xa"]
        obj.pattern_inputs = list(zip(obj.inputs, obj.arg_types_in))

        return obj

    pattern = "mnemonic <Vd>, (<Xa>)"
    inputs = ["Vd", "Xa"]


# Vector Integer Instructions ##


class RISCVVectorIntegerVectorVector(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Vf><vm>"
    inputs = ["Ve", "Vf"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorVectorMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Vf>, <Vg>"  # Vg == v0
    inputs = ["Ve", "Vf", "Vg"]
    outputs = ["Vd"]


class RISCVVectorIntegerVectorScalar(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Xa><vm>"
    inputs = ["Ve", "Xa"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorScalarMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <Xa>, <Vg>"  # Vg == v0
    inputs = ["Ve", "Xa", "Vg"]
    outputs = ["Vd"]


class RISCVVectorIntegerVectorImmediate(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <imm><vm>"
    inputs = ["Ve"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorImmediateMasked(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Ve>, <imm>, <Vg>"
    inputs = ["Ve", "Vg"]
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


class RISCVVectorVector(RISCVInstruction):
    pattern = "mnemonic <Vd>, <Va>"
    inputs = ["Va"]
    outputs = ["Vd"]

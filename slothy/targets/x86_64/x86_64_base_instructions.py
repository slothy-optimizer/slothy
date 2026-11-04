#
# Copyright (c) 2026 Maggie Simmons
# Copyright (c) 2026 Hayden Parsons
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

"""This module defines the x86_64 base integer instructions"""

from sympy import simplify

from slothy.helper import SourceLine
from slothy.targets.x86_64.instruction_core import (
    Instruction,
    all_subclass_leaves,
)
from slothy.targets.x86_64.x86_64_instruction_core import x86_64Instruction
from slothy.targets.x86_64.x86_64 import RegisterType


# ADD immediate to register
# Byte register
class add_hi(x86_64Instruction):
    pattern = "add <imm>, <HWd>"
    in_outs = ["HWd"]


# ADD immediate to register
# Word register
class add_si(x86_64Instruction):
    pattern = "add <imm>, <SWd>"
    in_outs = ["SWd"]


# ADD immediate to register
# Doubleword register
class add_di(x86_64Instruction):
    pattern = "add <imm>, <DWd>"
    in_outs = ["DWd"]


# ADD immediate to register
# Quadword register
class add_qi(x86_64Instruction):
    pattern = "add <imm>, <QWd>"
    in_outs = ["QWd"]


# ADD byte register to byte register
class add_hh(x86_64Instruction):
    pattern = "add <HWs>, <HWd>"
    inputs = ["HWs"]
    in_outs = ["HWd"]


# ADD word register to word register
class add_ss(x86_64Instruction):
    pattern = "add <SWs>, <SWd>"
    inputs = ["SWs"]
    in_outs = ["SWd"]


# ADD doubleword register to doubleword register
class add_dd(x86_64Instruction):
    pattern = "add <DWs>, <DWd>"
    inputs = ["DWs"]
    in_outs = ["DWd"]


# ADD quadword register to quadword register
class add_qq(x86_64Instruction):
    pattern = "add <QWs>, <QWd>"
    inputs = ["QWs"]
    in_outs = ["QWd"]


# AND quadword register to quadword register
class and_qq(x86_64Instruction):
    pattern = "and <QWs>, <QWd>"
    inputs = ["QWs"]
    in_outs = ["QWd"]


# JUMP if zero flag
# WARNING: flag writes are only partially modelled, so loops ending in jz/jnz are
# currently unsafe to optimize (see BranchLoop in x86_64.py); being fixed.
class jz(x86_64Instruction):
    pattern = "jz <label>"
    inputs = ["ZF"]


# JUMP if non zero flag
class jnz(x86_64Instruction):
    pattern = "jnz <label>"
    inputs = ["ZF"]


# MOV immediate to quadword register
class mov_qi(x86_64Instruction):
    pattern = "mov <imm>, <QWd>"
    outputs = ["QWd"]


# MOV quadword register to quadword register
class mov_qq(x86_64Instruction):
    pattern = "mov <QWs>, <QWd>"
    inputs = ["QWs"]
    outputs = ["QWd"]


# MOV quadword register to quadword register with movq mnemonic
class movq(x86_64Instruction):
    pattern = "movq <QWs>, <QWd>"
    inputs = ["QWs"]
    outputs = ["QWd"]


# MOV immediate to quadword register with movq mnemonic
class movq_i(x86_64Instruction):
    pattern = "movq <imm>, <QWd>"
    outputs = ["QWd"]


# Move from memory pointed to by register
class mov_from_mem(x86_64Instruction):
    pattern = "mov (<QWa>), <QWd>"
    inputs = ["QWa"]
    outputs = ["QWd"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index is None
        return super().write()


# Move from memory pointed to by register
class mov_from_mem_offset(x86_64Instruction):
    pattern = "mov <offset>(<QWa>), <QWd>"
    inputs = ["QWa"]
    outputs = ["QWd"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.offset
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.offset = simplify(self.pre_index)
        return super().write()


# Move to memory pointed to by register
class mov_to_mem(x86_64Instruction):
    pattern = "mov <QWs>, (<QWa>)"
    inputs = ["QWs", "QWa"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index is None
        return super().write()


# Move from memory pointed to by register
class mov_to_mem_offset(x86_64Instruction):
    pattern = "mov <QWs>, <offset>(<QWa>)"
    inputs = ["QWs", "QWa"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.offset
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.offset = simplify(self.pre_index)
        return super().write()


# Bitwise NOT of quadword register
class not_q(x86_64Instruction):
    pattern = "not <QWd>"
    in_outs = ["QWd"]


# OR quadword register to quadword register
class or_qq(x86_64Instruction):
    pattern = "or <QWs>, <QWd>"
    inputs = ["QWs"]
    in_outs = ["QWd"]


# Pop from stack
class pop(x86_64Instruction):
    pattern = "pop <QWd>"
    outputs = ["QWd"]
    implicitInOuts = [("rsp", RegisterType.GPR_Q)]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "rsp"
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index is None
        return super().write()


# Push to stack
class push(x86_64Instruction):
    pattern = "push <QWs>"
    inputs = ["QWs"]
    implicitInOuts = [("rsp", RegisterType.GPR_Q)]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "rsp"
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index is None
        return super().write()


# Dummy instruction for returns
class ret(x86_64Instruction):
    pattern = "ret"


# ROL quadword register by immediate shift
class rol_qi(x86_64Instruction):
    pattern = "rol <imm>, <QWd>"
    in_outs = ["QWd"]


# ROL quadword register by implicit shift by 1
class rol1(x86_64Instruction):
    pattern = "rol <QWd>"
    in_outs = ["QWd"]


# SHR quadword register by immediate
class shr_qi(x86_64Instruction):
    pattern = "shr <imm>, <QWd>"
    in_outs = ["QWd"]


# SUB immediate to register
# Quadword register
class sub_qi(x86_64Instruction):
    pattern = "sub <imm>, <QWd>"
    in_outs = ["QWd"]


# Test immediate against 64 bit register
# Writes SF/ZF/PF; other flag-writing instructions don't declare their flag writes
# yet, which makes loop optimization unsafe (see BranchLoop in x86_64.py).
class test_qi(x86_64Instruction):
    pattern = "test <imm>, <QWs>"
    inputs = ["QWs"]
    outputs = ["SF", "ZF", "PF"]
    # modifiesFlags = True


# Exchange between two quadword registers
class xchg_q(x86_64Instruction):
    pattern = "xchg <QWa>, <QWb>"
    in_outs = ["QWa", "QWb"]


# XOR immediate to quadword register
class xor_qi(x86_64Instruction):
    pattern = "xor <imm>, <QWd>"
    in_outs = ["QWd"]


# XOR quadword register to quadword register
class xor_qq(x86_64Instruction):
    pattern = "xor <QWs>, <QWd>"
    inputs = ["QWs"]
    in_outs = ["QWd"]


# XOR quadword register from memory address with offset
class xor_from_mem_offset(x86_64Instruction):
    pattern = "xor <offset>(<QWa>), <QWd>"
    inputs = ["QWa"]
    in_outs = ["QWd"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.offset
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.offset = simplify(self.pre_index)
        return super().write()


# XOR quadword register to memory address with offset
class xor_to_mem_offset(x86_64Instruction):
    pattern = "xor <QWs>, <offset>(<QWa>)"
    inputs = ["QWs", "QWa"]

    @classmethod
    def make(cls, src):
        obj = x86_64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.offset
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.offset = simplify(self.pre_index)
        return super().write()


def xor_from_mem_offset_splitting_cb():
    """
    Split a xor with a memory source into a mov from memory and xor from regs
    """

    def core(inst, t, log=None):

        a = RegisterType.reg_to_id(inst.args_in[0])
        b = RegisterType.reg_to_id(inst.args_in_out[0])

        # Define a symbolic register to hold the contents of memory address
        aux_reg = f"aux_{t.id}"

        mov = mov_from_mem_offset.make(
            {
                "QWd": aux_reg,
                "QWa": a,
                "offset": t.inst.offset,
            }
        )

        xor = xor_qq.make(
            {
                "QWd": b,
                "QWs": aux_reg,
            }
        )

        mov_src = (
            SourceLine(mov.write())
            .add_tags(inst.source_line.tags)
            .add_comments(inst.source_line.comments)
        )
        xor_src = (
            SourceLine(xor.write())
            .add_tags(inst.source_line.tags)
            .add_comments(inst.source_line.comments)
        )

        mov.source_line = mov_src
        xor.source_line = xor_src

        if log is not None:
            log(f"EOR3 splitting: {t.inst}; {mov} + {xor}")

        t.changed = True
        t.inst = [mov, xor]
        return True

    return core


# Enable splitting of xors from memory with offset
xor_from_mem_offset.global_fusion_cb = xor_from_mem_offset_splitting_cb()


Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)

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

"""This module defines the x86_64 SSE instructions"""

from sympy import simplify

from slothy.targets.x86_64.instruction_core import (
    Instruction,
    all_subclass_leaves,
)
from slothy.targets.x86_64.x86_64_instruction_core import x86_64Instruction


# Move unaligned packed from memory pointed to by register to XMM register
class movdqu_x_from_mem_offset(x86_64Instruction):
    pattern = "movdqu <offset>(<QWa>), <XMMd>"
    inputs = ["QWa"]
    outputs = ["XMMd"]

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


# Move unaligned packed from XMM register to memory pointed to by register
class movdqu_x_to_mem_offset(x86_64Instruction):
    pattern = "movdqu <XMMs>, <offset>(<QWa>)"
    inputs = ["XMMs", "QWa"]

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


# Packed XOR XMM register with memory pointed to by a register
class pxor_x_from_mem_offset(x86_64Instruction):
    pattern = "pxor <offset>(<QWa>), <XMMd>"
    inputs = ["QWa"]
    in_outs = ["XMMd"]

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


# Packed XOR XMM register to XMM register
class pxor_xx(x86_64Instruction):
    pattern = "pxor <XMMs>, <XMMd>"
    inputs = ["XMMs"]
    in_outs = ["XMMd"]


Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)

#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
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
# Author: Hanno Becker <hannobecker@posteo.de>
#

"""
Partial SLOTHY architecture model for RISCV

Various arithmetic and LSU scalar and Neon instructions are included,
but many are still missing. The model is lazily growing with the workloads
that SLOTHY is being used for.

Adding new instructions is simple thanks to the generic AArch64Instruction
class which generates instruction parsers and writers from instruction templates
similar to those used in the Arm ARM.
"""

import logging
import inspect
import re
import math
from enum import Enum
from functools import cache
from os import replace

from sympy import simplify

from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.exceptions import UnknownInstruction

llvm_mca_arch = "aarch64"

class RegisterType(Enum):
    """
    Enum of all register types
    """
    BASE_INT = 1  # 32 x-registers, 32-bit width + additional pc register

    def __str__(self):
        return self.name
    def __repr__(self):
        return self.name

    @cache
    @staticmethod
    def spillable(reg_type):  # done
        #return reg_type in [RegisterType.BASE_INT, RegisterType.NEON]
        return

    @cache
    @staticmethod
    def list_registers(reg_type, only_extra=False, only_normal=False, with_variants=False):  # done
        """Return the list of all registers of a given type"""

        base_int  = [ f"x{i}" for i in range(31) ] + ["pc"]


        return { RegisterType.BASE_INT : base_int,
                 }[reg_type]


    @staticmethod
    def find_type(r):  # done
        """Find type of architectural register"""

        #if r.startswith("hint_"):
        #    return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty
        return None

    @staticmethod
    def is_renamed(ty):  # done
        """Indicate if register type should be subject to renaming"""
        #if ty == RegisterType.HINT:
        #    return False
        return True

    @staticmethod
    def from_string(string):  # done
        """Find register type from string"""
        string = string.lower()
        return { "base_int"    : RegisterType.BASE_INT}.get(string,None)

    @staticmethod
    def default_reserved():  # done
        """Return the list of registers that should be reserved by default"""
        #return set(["flags", "sp"] + RegisterType.list_registers(RegisterType.HINT))
        return []

    @staticmethod
    def default_aliases():  # done
        "Register aliases used by the architecture"
        return {}

# class Branch:
#     """Helper for emitting branches"""
#
#     @staticmethod
#     def if_equal(cnt, val, lbl):
#         """Emit assembly for a branch-if-equal sequence"""
#         yield f"cmp {cnt}, #{val}"
#         yield f"b.eq {lbl}"
#
#     @staticmethod
#     def if_greater_equal(cnt, val, lbl):
#         """Emit assembly for a branch-if-greater-equal sequence"""
#         yield f"cmp {cnt}, #{val}"
#         yield f"b.ge {lbl}"
#
#     @staticmethod
#     def unconditional(lbl):
#         """Emit unconditional branch"""
#         yield f"b {lbl}"

# class Loop:
#     """Helper functions for parsing and writing simple loops in AArch64
#
#     TODO: Generalize; current implementation too specific about shape of loop"""
#
#     def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr"):
#         self.lbl_start = lbl_start
#         self.lbl_end   = lbl_end
#         self.loop_init = loop_init
#
#     def start(self, loop_cnt, indentation=0, fixup=0, unroll=1, jump_if_empty=None):
#         """Emit starting instruction(s) and jump label for loop"""
#         indent = ' ' * indentation
#         if unroll > 1:
#             assert unroll in [1,2,4,8,16,32]
#             yield f"{indent}lsr {loop_cnt}, {loop_cnt}, #{int(math.log2(unroll))}"
#         if fixup != 0:
#             yield f"{indent}sub {loop_cnt}, {loop_cnt}, #{fixup}"
#         if jump_if_empty is not None:
#             yield f"cbz {loop_cnt}, {jump_if_empty}"
#         yield f"{self.lbl_start}:"
#
#     def end(self, other, indentation=0):
#         """Emit compare-and-branch at the end of the loop"""
#         (reg0, reg1, imm) = other
#         indent = ' ' * indentation
#         lbl_start = self.lbl_start
#         if lbl_start.isdigit():
#             lbl_start += "b"
#
#         yield f"{indent}sub {reg0}, {reg1}, {imm}"
#         yield f"{indent}cbnz {reg0}, {lbl_start}"
#
#     @staticmethod
#     def extract(source, lbl):
#         """Locate a loop with start label `lbl` in `source`.
#
#         We currently only support the following loop forms:
#
#            ```
#            loop_lbl:
#                {code}
#                sub[s] <cnt>, <cnt>, #1
#                (cbnz|bnz|bne) <cnt>, loop_lbl
#            ```
#
#         """
#         assert isinstance(source, list)
#
#         pre  = []
#         body = []
#         post = []
#         loop_lbl_regexp_txt = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
#         loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)
#
#         # TODO: Allow other forms of looping
#
#         loop_end_regexp_txt = (r"^\s*sub[s]?\s+(?P<reg0>\w+),\s*(?P<reg1>\w+),\s*(?P<imm>#1)",
#                                rf"^\s*(cbnz|bnz|bne)\s+(?P<reg0>\w+),\s*{lbl}")
#         loop_end_regexp = [re.compile(txt) for txt in loop_end_regexp_txt]
#         lines = iter(source)
#         l = None
#         keep = False
#         state = 0 # 0: haven't found loop yet, 1: extracting loop, 2: after loop
#         while True:
#             if not keep:
#                 l = next(lines, None)
#             keep = False
#             if l is None:
#                 break
#             l_str = l.text
#             assert isinstance(l, str) is False
#             if state == 0:
#                 p = loop_lbl_regexp.match(l_str)
#                 if p is not None and p.group("label") == lbl:
#                     l = l.copy().set_text(p.group("remainder"))
#                     keep = True
#                     state = 1
#                 else:
#                     pre.append(l)
#                 continue
#             if state == 1:
#                 p = loop_end_regexp[0].match(l_str)
#                 if p is not None:
#                     reg0 = p.group("reg0")
#                     reg1 = p.group("reg1")
#                     imm = p.group("imm")
#                     state = 2
#                     continue
#                 body.append(l)
#                 continue
#             if state == 2:
#                 p = loop_end_regexp[1].match(l_str)
#                 if p is not None:
#                     state = 3
#                     continue
#                 body.append(l)
#                 continue
#             if state == 3:
#                 post.append(l)
#                 continue
#         if state < 3:
#             raise FatalParsingException(f"Couldn't identify loop {lbl}")
#         return pre, body, post, lbl, (reg0, reg1, imm)







####################################################################################
#                                                                                  #
# Virtual instruction to model pushing to stack locations without modelling memory #
#                                                                                  #
####################################################################################

# class qsave(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="qsave",
#                                arg_types_in=[RegisterType.NEON],
#                                arg_types_out=[RegisterType.STACK_NEON])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class qrestore(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="qrestore",
#                                arg_types_in=[RegisterType.STACK_NEON],
#                                arg_types_out=[RegisterType.NEON])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class save(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="save",
#                                arg_types_in=[RegisterType.BASE_INT],
#                                arg_types_out=[RegisterType.STACK_BASE_INT])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class restore(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="restore",
#                                arg_types_in=[RegisterType.STACK_BASE_INT],
#                                arg_types_out=[RegisterType.BASE_INT])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class nop(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "nop"
#
# class vadd(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "add <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
#     inputs = ["Vb", "Vc"]
#     outputs = ["Va"]
#
# class vsub(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "sub <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
#     inputs = ["Vb", "Vc"]
#     outputs = ["Va"]

############################
#                          #
# Some LSU instructions    #
#                          #
############################

#class Ldr_Q(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
#    pass

#class Ldp_Q(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
#    pass

# class d_ldp_sp_imm(Ldr_Q): # pylint: disable=missing-docstring,invalid-name
#     pattern = "ldp <Da>, <Db>, [sp, <imm>]"
#     outputs = ["Da", "Db"]
#     @classmethod
#     def make(cls, src):
#         obj = RISCVInstruction.build(cls, src)
#         obj.increment = None
#         obj.pre_index = obj.immediate
#         obj.addr = "sp"
#         return obj
#
# class q_ldr(Ldr_Q): # pylint: disable=missing-docstring,invalid-name
#     pattern = "ldr <Qa>, [<Xc>]"
#     inputs = ["Xc"]
#     outputs = ["Qa"]
#     @classmethod
#     def make(cls, src):
#         obj = RISCVInstruction.build(cls, src)
#         obj.increment = None
#         obj.pre_index = None
#         obj.addr = obj.args_in[0]
#         return obj


def iter_riscv_instructions():
    yield from Instruction.all_subclass_leaves(Instruction)

def find_class(src):
    for inst_class in iter_riscv_instructions():
        if isinstance(src,inst_class):
            return inst_class
    raise UnknownInstruction(f"Couldn't find instruction class for {src} (type {type(src)})")


def lookup_multidict(d, inst, default=None):
    instclass = find_class(inst)
    for l,v in d.items():
        # Multidict entries can be the following:
        # - An instruction class. It matches any instruction of that class.
        # - A callable. It matches any instruction returning `True` when passed
        #   to the callable.
        # - A tuple of instruction classes or callables. It matches any instruction
        #   which matches at least one element in the tuple.
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            #assert callable(x)
            return x(inst)
        if not isinstance(l, tuple):
            l = [l]
        for lp in l:
            if match(lp):
                return v
    if default is None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

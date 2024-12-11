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
Partial SLOTHY architecture model for RISCV
"""

import inspect
from enum import Enum
from functools import cache
from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.exceptions import UnknownInstruction

llvm_mca_arch = "aarch64"


class RegisterType(Enum):
    """
    Enum of all register types
    """
    BASE_INT = 1,  # 32 scalar x-registers, 32-bit width + additional pc register
    VECT = 2, # 32 vector v-registers, VLEN width
    CSR = 3

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    @cache
    @staticmethod
    def spillable(reg_type):
        # return reg_type in [RegisterType.BASE_INT, RegisterType.NEON]
        return

    @cache
    @staticmethod
    def list_registers(reg_type, only_extra=False, only_normal=False, with_variants=False):
        """Return the list of all registers of a given type"""

        base_int = [f"x{i}" for i in range(32)]
        # TODO: check for reserved regs
        vector_regs = [f"v{i}" for i in range(32)]
        csr = [
            "vstart",
            "vxsat",
            "vxrm",
            "vcsr",
            "vtype",
            "vl",
            "vlenb"
        ]
        return {RegisterType.BASE_INT: base_int,
                RegisterType.VECT: vector_regs,
                RegisterType.CSR: csr
                }[reg_type]

    @staticmethod
    def find_type(r):
        """Find type of architectural register"""

        # if r.startswith("hint_"):
        #    return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty
        return None

    @staticmethod
    def is_renamed(ty):
        """Indicate if register type should be subject to renaming"""

        # if ty == RegisterType.HINT:
        #    return False
        return True

    @staticmethod
    def from_string(string):
        """Find register type from string"""

        string = string.lower()
        return {"base_int": RegisterType.BASE_INT}.get(string, None)

    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""

        # return set(["flags", "sp"] + RegisterType.list_registers(RegisterType.HINT))
        return ['x2', 'x0']

    @staticmethod
    def default_aliases():
        "Register aliases used by the architecture"

        return {
            # RISC-V ABI default aliases
            "zero": "x0",  # Hardwired zero register
            "ra": "x1",  # Return address
            "sp": "x2",  # Stack pointer
            "gp": "x3",  # Global pointer
            "tp": "x4",  # Thread pointer
            "t0": "x5",  # Temporary register 0
            "t1": "x6",  # Temporary register 1
            "t2": "x7",  # Temporary register 2
            "s0": "x8",  # Saved register / frame pointer
            "fp": "x8",  # Alias for frame pointer (same as s0)
            "s1": "x9",  # Saved register 1
            "a0": "x10",  # Function argument / return value 0
            "a1": "x11",  # Function argument / return value 1
            "a2": "x12",  # Function argument 2
            "a3": "x13",  # Function argument 3
            "a4": "x14",  # Function argument 4
            "a5": "x15",  # Function argument 5
            "a6": "x16",  # Function argument 6
            "a7": "x17",  # Function argument 7
            "s2": "x18",  # Saved register 2
            "s3": "x19",  # Saved register 3
            "s4": "x20",  # Saved register 4
            "s5": "x21",  # Saved register 5
            "s6": "x22",  # Saved register 6
            "s7": "x23",  # Saved register 7
            "s8": "x24",  # Saved register 8
            "s9": "x25",  # Saved register 9
            "s10": "x26",  # Saved register 10
            "s11": "x27",  # Saved register 11
            "t3": "x28",  # Temporary register 3
            "t4": "x29",  # Temporary register 4
            "t5": "x30",  # Temporary register 5
            "t6": "x31",  # Temporary register 6
        }


def iter_riscv_instructions():
    yield from Instruction.all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_riscv_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise UnknownInstruction(f"Couldn't find instruction class for {src} (type {type(src)})")


def lookup_multidict(d, inst, default=None):
    """Multidict lookup

     Multidict entries can be the following:
       - An instruction class. It matches any instruction of that class.
       - A callable. It matches any instruction returning `True` when passed
         to the callable.
       - A tuple of instruction classes or callables. It matches any instruction
         which matches at least one element in the tuple.

    :param d:
    :param inst:
    :param default:
    :return:
    """
    instclass = find_class(inst)
    for l, v in d.items():
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            # assert callable(x)
            return x(inst)

        if not isinstance(l, tuple):
            l = [l]
        for lp in l:
            if match(lp):
                return v
    if default is None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

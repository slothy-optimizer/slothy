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

"""
Partial SLOTHY architecture model for x86_64
"""

import logging
import re
from enum import Enum
from functools import cache
from sympy import simplify

from unicorn import (
    UC_ARCH_X86,
    UC_MODE_64,
)


from unicorn.x86_const import (
    UC_X86_REG_AH,
    UC_X86_REG_AL,
    UC_X86_REG_AX,
    UC_X86_REG_BH,
    UC_X86_REG_BL,
    UC_X86_REG_BP,
    UC_X86_REG_BPL,
    UC_X86_REG_BX,
    UC_X86_REG_CH,
    UC_X86_REG_CL,
    UC_X86_REG_CS,
    UC_X86_REG_CX,
    UC_X86_REG_DH,
    UC_X86_REG_DI,
    UC_X86_REG_DIL,
    UC_X86_REG_DL,
    UC_X86_REG_DS,
    UC_X86_REG_DX,
    UC_X86_REG_EAX,
    UC_X86_REG_EBP,
    UC_X86_REG_EBX,
    UC_X86_REG_ECX,
    UC_X86_REG_EDI,
    UC_X86_REG_EDX,
    UC_X86_REG_ES,
    UC_X86_REG_ESI,
    UC_X86_REG_ESP,
    UC_X86_REG_IP,
    UC_X86_REG_RAX,
    UC_X86_REG_RBP,
    UC_X86_REG_RBX,
    UC_X86_REG_RCX,
    UC_X86_REG_RDI,
    UC_X86_REG_RDX,
    UC_X86_REG_RIP,
    UC_X86_REG_RSI,
    UC_X86_REG_RSP,
    UC_X86_REG_SI,
    UC_X86_REG_SIL,
    UC_X86_REG_SP,
    UC_X86_REG_SPL,
    UC_X86_REG_MM0,
    UC_X86_REG_MM1,
    UC_X86_REG_MM2,
    UC_X86_REG_MM3,
    UC_X86_REG_MM4,
    UC_X86_REG_MM5,
    UC_X86_REG_MM6,
    UC_X86_REG_MM7,
    UC_X86_REG_R8,
    UC_X86_REG_R9,
    UC_X86_REG_R10,
    UC_X86_REG_R11,
    UC_X86_REG_R12,
    UC_X86_REG_R13,
    UC_X86_REG_R14,
    UC_X86_REG_R15,
    UC_X86_REG_XMM0,
    UC_X86_REG_XMM1,
    UC_X86_REG_XMM2,
    UC_X86_REG_XMM3,
    UC_X86_REG_XMM4,
    UC_X86_REG_XMM5,
    UC_X86_REG_XMM6,
    UC_X86_REG_XMM7,
    UC_X86_REG_XMM8,
    UC_X86_REG_XMM9,
    UC_X86_REG_XMM10,
    UC_X86_REG_XMM11,
    UC_X86_REG_XMM12,
    UC_X86_REG_XMM13,
    UC_X86_REG_XMM14,
    UC_X86_REG_XMM15,
    UC_X86_REG_XMM16,
    UC_X86_REG_XMM17,
    UC_X86_REG_XMM18,
    UC_X86_REG_XMM19,
    UC_X86_REG_XMM20,
    UC_X86_REG_XMM21,
    UC_X86_REG_XMM22,
    UC_X86_REG_XMM23,
    UC_X86_REG_XMM24,
    UC_X86_REG_XMM25,
    UC_X86_REG_XMM26,
    UC_X86_REG_XMM27,
    UC_X86_REG_XMM28,
    UC_X86_REG_XMM29,
    UC_X86_REG_XMM30,
    UC_X86_REG_XMM31,
    UC_X86_REG_YMM0,
    UC_X86_REG_YMM1,
    UC_X86_REG_YMM2,
    UC_X86_REG_YMM3,
    UC_X86_REG_YMM4,
    UC_X86_REG_YMM5,
    UC_X86_REG_YMM6,
    UC_X86_REG_YMM7,
    UC_X86_REG_YMM8,
    UC_X86_REG_YMM9,
    UC_X86_REG_YMM10,
    UC_X86_REG_YMM11,
    UC_X86_REG_YMM12,
    UC_X86_REG_YMM13,
    UC_X86_REG_YMM14,
    UC_X86_REG_YMM15,
    UC_X86_REG_YMM16,
    UC_X86_REG_YMM17,
    UC_X86_REG_YMM18,
    UC_X86_REG_YMM19,
    UC_X86_REG_YMM20,
    UC_X86_REG_YMM21,
    UC_X86_REG_YMM22,
    UC_X86_REG_YMM23,
    UC_X86_REG_YMM24,
    UC_X86_REG_YMM25,
    UC_X86_REG_YMM26,
    UC_X86_REG_YMM27,
    UC_X86_REG_YMM28,
    UC_X86_REG_YMM29,
    UC_X86_REG_YMM30,
    UC_X86_REG_YMM31,
    UC_X86_REG_ZMM0,
    UC_X86_REG_ZMM1,
    UC_X86_REG_ZMM2,
    UC_X86_REG_ZMM3,
    UC_X86_REG_ZMM4,
    UC_X86_REG_ZMM5,
    UC_X86_REG_ZMM6,
    UC_X86_REG_ZMM7,
    UC_X86_REG_ZMM8,
    UC_X86_REG_ZMM9,
    UC_X86_REG_ZMM10,
    UC_X86_REG_ZMM11,
    UC_X86_REG_ZMM12,
    UC_X86_REG_ZMM13,
    UC_X86_REG_ZMM14,
    UC_X86_REG_ZMM15,
    UC_X86_REG_ZMM16,
    UC_X86_REG_ZMM17,
    UC_X86_REG_ZMM18,
    UC_X86_REG_ZMM19,
    UC_X86_REG_ZMM20,
    UC_X86_REG_ZMM21,
    UC_X86_REG_ZMM22,
    UC_X86_REG_ZMM23,
    UC_X86_REG_ZMM24,
    UC_X86_REG_ZMM25,
    UC_X86_REG_ZMM26,
    UC_X86_REG_ZMM27,
    UC_X86_REG_ZMM28,
    UC_X86_REG_ZMM29,
    UC_X86_REG_ZMM30,
    UC_X86_REG_ZMM31,
    UC_X86_REG_R8B,
    UC_X86_REG_R9B,
    UC_X86_REG_R10B,
    UC_X86_REG_R11B,
    UC_X86_REG_R12B,
    UC_X86_REG_R13B,
    UC_X86_REG_R14B,
    UC_X86_REG_R15B,
    UC_X86_REG_R8D,
    UC_X86_REG_R9D,
    UC_X86_REG_R10D,
    UC_X86_REG_R11D,
    UC_X86_REG_R12D,
    UC_X86_REG_R13D,
    UC_X86_REG_R14D,
    UC_X86_REG_R15D,
    UC_X86_REG_R8W,
    UC_X86_REG_R9W,
    UC_X86_REG_R10W,
    UC_X86_REG_R11W,
    UC_X86_REG_R12W,
    UC_X86_REG_R13W,
    UC_X86_REG_R14W,
    UC_X86_REG_R15W,
    UC_X86_REG_FLAGS,
)

from slothy.targets.exceptions import (
    FatalParsingException,
    UnknownInstruction,
)
from slothy.helper import Loop
from slothy.targets.x86_64.instruction_core import Instruction, all_subclass_leaves

unicorn_arch = UC_ARCH_X86
unicorn_mode = UC_MODE_64

arch_name = "x86_64"

llvm_mca_arch = "x86-64"
llvm_mc_arch = "x86-64"
llvm_mc_attr = ""


class SymbolicRegister(str):
    """Name of a symbolic register, e.g. 'state' for QW<state>.

    Kept distinct from plain register IDs ('a' for rax, '8' for r8, ...) so that
    symbolic names which look like IDs are not turned into physical registers."""


class RegisterType(Enum):
    GPR_H = 1
    GPR_S = 2
    GPR_D = 3
    GPR_Q = 4

    XMM = 5
    YMM = 6

    FLAGS = 7

    # Pseudo-registers for memory dependencies declared via reads=/writes= tags
    HINT = 8

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    @staticmethod
    @cache
    def spillable(reg_type):
        return reg_type in [RegisterType.GPR]  # For now, only GPRs

    @staticmethod
    def callee_saved_registers():
        return [f"x{i}" for i in range(18, 31)] + [f"v{i}" for i in range(8, 16)]

    @staticmethod
    def unicorn_link_register():
        return None

    @staticmethod
    def unicorn_stack_pointer():
        return UC_X86_REG_SP

    @staticmethod
    def unicorn_program_counter():
        return UC_X86_REG_IP

    @staticmethod
    @cache
    def unicorn_reg_by_name(reg):
        """Converts string name of register into numerical identifiers used
        within the unicorn engine"""

        d = {
            "ah": UC_X86_REG_AH,
            "al": UC_X86_REG_AL,
            "ax": UC_X86_REG_AX,
            "bh": UC_X86_REG_BH,
            "bl": UC_X86_REG_BL,
            "bp": UC_X86_REG_BP,
            "bpl": UC_X86_REG_BPL,
            "bx": UC_X86_REG_BX,
            "ch": UC_X86_REG_CH,
            "cl": UC_X86_REG_CL,
            "cs": UC_X86_REG_CS,
            "cx": UC_X86_REG_CX,
            "dh": UC_X86_REG_DH,
            "di": UC_X86_REG_DI,
            "dil": UC_X86_REG_DIL,
            "dl": UC_X86_REG_DL,
            "ds": UC_X86_REG_DS,
            "dx": UC_X86_REG_DX,
            "eax": UC_X86_REG_EAX,
            "ebp": UC_X86_REG_EBP,
            "ebx": UC_X86_REG_EBX,
            "ecx": UC_X86_REG_ECX,
            "edi": UC_X86_REG_EDI,
            "edx": UC_X86_REG_EDX,
            "es": UC_X86_REG_ES,
            "esi": UC_X86_REG_ESI,
            "esp": UC_X86_REG_ESP,
            "ip": UC_X86_REG_IP,
            "rax": UC_X86_REG_RAX,
            "rbp": UC_X86_REG_RBP,
            "rbx": UC_X86_REG_RBX,
            "rcx": UC_X86_REG_RCX,
            "rdi": UC_X86_REG_RDI,
            "rdx": UC_X86_REG_RDX,
            "rip": UC_X86_REG_RIP,
            "rsi": UC_X86_REG_RSI,
            "rsp": UC_X86_REG_RSP,
            "si": UC_X86_REG_SI,
            "sil": UC_X86_REG_SIL,
            "sp": UC_X86_REG_SP,
            "spl": UC_X86_REG_SPL,
            "mm0": UC_X86_REG_MM0,
            "mm1": UC_X86_REG_MM1,
            "mm2": UC_X86_REG_MM2,
            "mm3": UC_X86_REG_MM3,
            "mm4": UC_X86_REG_MM4,
            "mm5": UC_X86_REG_MM5,
            "mm6": UC_X86_REG_MM6,
            "mm7": UC_X86_REG_MM7,
            "r8": UC_X86_REG_R8,
            "r9": UC_X86_REG_R9,
            "r10": UC_X86_REG_R10,
            "r11": UC_X86_REG_R11,
            "r12": UC_X86_REG_R12,
            "r13": UC_X86_REG_R13,
            "r14": UC_X86_REG_R14,
            "r15": UC_X86_REG_R15,
            "xmm0": UC_X86_REG_XMM0,
            "xmm1": UC_X86_REG_XMM1,
            "xmm2": UC_X86_REG_XMM2,
            "xmm3": UC_X86_REG_XMM3,
            "xmm4": UC_X86_REG_XMM4,
            "xmm5": UC_X86_REG_XMM5,
            "xmm6": UC_X86_REG_XMM6,
            "xmm7": UC_X86_REG_XMM7,
            "xmm8": UC_X86_REG_XMM8,
            "xmm9": UC_X86_REG_XMM9,
            "xmm10": UC_X86_REG_XMM10,
            "xmm11": UC_X86_REG_XMM11,
            "xmm12": UC_X86_REG_XMM12,
            "xmm13": UC_X86_REG_XMM13,
            "xmm14": UC_X86_REG_XMM14,
            "xmm15": UC_X86_REG_XMM15,
            "xmm16": UC_X86_REG_XMM16,
            "xmm17": UC_X86_REG_XMM17,
            "xmm18": UC_X86_REG_XMM18,
            "xmm19": UC_X86_REG_XMM19,
            "xmm20": UC_X86_REG_XMM20,
            "xmm21": UC_X86_REG_XMM21,
            "xmm22": UC_X86_REG_XMM22,
            "xmm23": UC_X86_REG_XMM23,
            "xmm24": UC_X86_REG_XMM24,
            "xmm25": UC_X86_REG_XMM25,
            "xmm26": UC_X86_REG_XMM26,
            "xmm27": UC_X86_REG_XMM27,
            "xmm28": UC_X86_REG_XMM28,
            "xmm29": UC_X86_REG_XMM29,
            "xmm30": UC_X86_REG_XMM30,
            "xmm31": UC_X86_REG_XMM31,
            "ymm0": UC_X86_REG_YMM0,
            "ymm1": UC_X86_REG_YMM1,
            "ymm2": UC_X86_REG_YMM2,
            "ymm3": UC_X86_REG_YMM3,
            "ymm4": UC_X86_REG_YMM4,
            "ymm5": UC_X86_REG_YMM5,
            "ymm6": UC_X86_REG_YMM6,
            "ymm7": UC_X86_REG_YMM7,
            "ymm8": UC_X86_REG_YMM8,
            "ymm9": UC_X86_REG_YMM9,
            "ymm10": UC_X86_REG_YMM10,
            "ymm11": UC_X86_REG_YMM11,
            "ymm12": UC_X86_REG_YMM12,
            "ymm13": UC_X86_REG_YMM13,
            "ymm14": UC_X86_REG_YMM14,
            "ymm15": UC_X86_REG_YMM15,
            "ymm16": UC_X86_REG_YMM16,
            "ymm17": UC_X86_REG_YMM17,
            "ymm18": UC_X86_REG_YMM18,
            "ymm19": UC_X86_REG_YMM19,
            "ymm20": UC_X86_REG_YMM20,
            "ymm21": UC_X86_REG_YMM21,
            "ymm22": UC_X86_REG_YMM22,
            "ymm23": UC_X86_REG_YMM23,
            "ymm24": UC_X86_REG_YMM24,
            "ymm25": UC_X86_REG_YMM25,
            "ymm26": UC_X86_REG_YMM26,
            "ymm27": UC_X86_REG_YMM27,
            "ymm28": UC_X86_REG_YMM28,
            "ymm29": UC_X86_REG_YMM29,
            "ymm30": UC_X86_REG_YMM30,
            "ymm31": UC_X86_REG_YMM31,
            "zmm0": UC_X86_REG_ZMM0,
            "zmm1": UC_X86_REG_ZMM1,
            "zmm2": UC_X86_REG_ZMM2,
            "zmm3": UC_X86_REG_ZMM3,
            "zmm4": UC_X86_REG_ZMM4,
            "zmm5": UC_X86_REG_ZMM5,
            "zmm6": UC_X86_REG_ZMM6,
            "zmm7": UC_X86_REG_ZMM7,
            "zmm8": UC_X86_REG_ZMM8,
            "zmm9": UC_X86_REG_ZMM9,
            "zmm10": UC_X86_REG_ZMM10,
            "zmm11": UC_X86_REG_ZMM11,
            "zmm12": UC_X86_REG_ZMM12,
            "zmm13": UC_X86_REG_ZMM13,
            "zmm14": UC_X86_REG_ZMM14,
            "zmm15": UC_X86_REG_ZMM15,
            "zmm16": UC_X86_REG_ZMM16,
            "zmm17": UC_X86_REG_ZMM17,
            "zmm18": UC_X86_REG_ZMM18,
            "zmm19": UC_X86_REG_ZMM19,
            "zmm20": UC_X86_REG_ZMM20,
            "zmm21": UC_X86_REG_ZMM21,
            "zmm22": UC_X86_REG_ZMM22,
            "zmm23": UC_X86_REG_ZMM23,
            "zmm24": UC_X86_REG_ZMM24,
            "zmm25": UC_X86_REG_ZMM25,
            "zmm26": UC_X86_REG_ZMM26,
            "zmm27": UC_X86_REG_ZMM27,
            "zmm28": UC_X86_REG_ZMM28,
            "zmm29": UC_X86_REG_ZMM29,
            "zmm30": UC_X86_REG_ZMM30,
            "zmm31": UC_X86_REG_ZMM31,
            "r8b": UC_X86_REG_R8B,
            "r9b": UC_X86_REG_R9B,
            "r10b": UC_X86_REG_R10B,
            "r11b": UC_X86_REG_R11B,
            "r12b": UC_X86_REG_R12B,
            "r13b": UC_X86_REG_R13B,
            "r14b": UC_X86_REG_R14B,
            "r15b": UC_X86_REG_R15B,
            "r8d": UC_X86_REG_R8D,
            "r9d": UC_X86_REG_R9D,
            "r10d": UC_X86_REG_R10D,
            "r11d": UC_X86_REG_R11D,
            "r12d": UC_X86_REG_R12D,
            "r13d": UC_X86_REG_R13D,
            "r14d": UC_X86_REG_R14D,
            "r15d": UC_X86_REG_R15D,
            "r8w": UC_X86_REG_R8W,
            "r9w": UC_X86_REG_R9W,
            "r10w": UC_X86_REG_R10W,
            "r11w": UC_X86_REG_R11W,
            "r12w": UC_X86_REG_R12W,
            "r13w": UC_X86_REG_R13W,
            "r14w": UC_X86_REG_R14W,
            "r15w": UC_X86_REG_R15W,
            "flags": UC_X86_REG_FLAGS,
        }
        return d.get(reg, None)

    @staticmethod
    @cache
    def list_byte_gprs():
        letter_labels = ["a", "b", "c", "d"]
        return (
            [f"{p}l" for p in letter_labels]
            + ["dil", "sil"]
            + ["spl", "bpl"]
            + [f"r{n}l" for n in range(8, 16)]
        )

    @staticmethod
    @cache
    def list_word_gprs():
        letter_labels = ["a", "b", "c", "d"]
        return (
            [f"{p}x" for p in letter_labels]
            + ["di", "si"]
            + ["sp", "bp"]
            + [f"r{n}w" for n in range(8, 16)]
        )

    @staticmethod
    @cache
    def list_dblword_gprs():
        letter_labels = ["a", "b", "c", "d"]
        return (
            [f"e{p}x" for p in letter_labels]
            + ["edi", "esi"]
            + ["esp", "ebp"]
            + [f"r{n}d" for n in range(8, 16)]
        )

    @staticmethod
    @cache
    def list_qdword_gprs():
        letter_labels = ["a", "b", "c", "d"]
        return (
            [f"r{p}x" for p in letter_labels]
            + ["rdi", "rsi"]
            + ["rsp", "rbp"]
            + [f"r{n}" for n in range(8, 16)]
        )

    @staticmethod
    @cache
    def list_xmm():
        return [f"xmm{n}" for n in range(16)]

    @staticmethod
    @cache
    def list_ymm():
        return [f"ymm{n}" for n in range(16)]

    @staticmethod
    @cache
    def list_flags():
        return ["SF", "ZF", "PF"]

    @staticmethod
    @cache
    def list_hints():
        return (
            [f"t{i}" for i in range(100)]
            + [f"t{i}{j}" for i in range(8) for j in range(8)]
            + [f"t{i}_{j}" for i in range(16) for j in range(16)]
        )

    @staticmethod
    @cache
    def list_registers(
        reg_type, only_extra=False, only_normal=False, with_variants=False
    ):
        """Return the list of all registers of a given type"""

        return {
            RegisterType.GPR_H: RegisterType.list_byte_gprs(),
            RegisterType.GPR_S: RegisterType.list_word_gprs(),
            RegisterType.GPR_D: RegisterType.list_dblword_gprs(),
            RegisterType.GPR_Q: RegisterType.list_qdword_gprs(),
            RegisterType.XMM: RegisterType.list_xmm(),
            RegisterType.YMM: RegisterType.list_ymm(),
            RegisterType.FLAGS: RegisterType.list_flags(),
            RegisterType.HINT: RegisterType.list_hints(),
        }[reg_type]

    @staticmethod
    def find_type(r):
        """Find type of architectural register"""

        if r.startswith("hint_"):
            return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty

        return None

    def reg_to_id(name):
        # Anchored, so that e.g. rdi gives "di" rather than "d" (rdx)
        regexp_text = (
            "(?:([eErR]|ymm|YMM|xmm|XMM)?"
            "(?P<raw_ID>([abcdABCD]|[sbSB][pP]|[sSdD][iI]|\\d[0-5]?))[lLwWdDxX]?"
            "|\\w+<(?P<symbol_ID>\\w[\\w\\d_]*)>)\\Z"
        )
        regexp = re.compile(regexp_text)
        match = regexp.match(name)
        if match is None:
            raise FatalParsingException(
                f"Cannot extract identifier from register name {name}!"
            )
        if match.group("raw_ID") is not None:
            return match.group("raw_ID")
        elif match.group("symbol_ID") is not None:
            return SymbolicRegister(match.group("symbol_ID"))
        else:
            raise FatalParsingException(
                f"Cannot extract identifier from register name {name}!"
            )

    def type_to_pattern(ty, label):
        s = ""
        if ty == RegisterType.GPR_H:
            s += "HW"
        elif ty == RegisterType.GPR_S:
            s += "SW"
        elif ty == RegisterType.GPR_D:
            s += "DW"
        elif ty == RegisterType.GPR_Q:
            s += "QW"
        elif ty == RegisterType.XMM:
            s += "XMM"
        elif ty == RegisterType.YMM:
            s += "YMM"
        else:
            raise FatalParsingException(
                f"Type {ty.name} cannot be converted to pattern symbol"
            )

        s += label
        return s

    @staticmethod
    def is_renamed(ty):
        """Indicate if register type should be subject to renaming"""
        if ty == RegisterType.HINT:
            return False
        return True

    @staticmethod
    def from_string(string):
        """Find register type from string"""
        string = string.lower()
        return {
            "gpr_h": RegisterType.GPR_H,
            "gpr_s": RegisterType.GPR_S,
            "gpr_d": RegisterType.GPR_D,
            "gpr_q": RegisterType.GPR_Q,
            "xmm": RegisterType.XMM,
            "ymm": RegisterType.YMM,
            "flags": RegisterType.FLAGS,
            "hint": RegisterType.HINT,
        }.get(string, None)

    # TODO: fill this in
    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(
            ["spl", "sp", "esp", "rsp", "bpl", "bp", "ebp", "rbp"]
            + RegisterType.list_registers(RegisterType.HINT)
        )

    @staticmethod
    def default_aliases():
        "Register aliases used by the architecture"
        return {}


class BranchLoop(Loop):
    """
    More general loop type that just considers the branch instruction as part
    of the boundary.
    This can help to improve performance as the instructions that belong to
    handling the loop can be considered by SLOTHY as well.

    .. note::

        This loop type is still rather experimental. It has a lot of logics
        inside as it needs to be able to "understand" a variety of different
        ways to express loops, e.g., how counters get incremented, how
        registers marking the end of the
        loop need to be modified in case of software pipelining etc.

    .. warning::

        Loop optimization on x86_64 is currently UNSAFE and is being fixed.
        Flag writes are only partially modelled: ``test`` writes SF/ZF/PF and
        ``jz``/``jnz`` read ZF, but other flag-writing instructions (``add``,
        ``sub``, ``and``, ``or``, ``xor``, ``shr``) don't declare their flag
        writes. SLOTHY can therefore schedule one of them between the ``test``
        and the branch, which overwrites ZF on hardware and changes the loop's
        control flow. The selftest does not catch this (it doesn't compare flags).
        Straight-line code that doesn't read flags is not affected.

    """

    def __init__(self, lbl="lbl") -> None:
        super().__init__()
        # The group naming in the regex should be consistent; give same group
        # names to the same registers
        self.lbl = lbl
        self.lbl_regex = r"^\s*(?P<label>[\w\.]+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            (
                rf"^\s*j(?P<br_type>" rf"[\.]?(n?z))" rf"\s+{lbl}",
                False,
            ),
        )

    def start(
        self,
        loop_cnt,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        """Emit starting instruction(s) and jump label for loop"""
        from slothy.targets.x86_64.x86_64_base_instructions import test_qi

        indent = " " * indentation
        if body_code is None:
            logging.debug("No body code in loop start: Just printing label.")
            yield f"{self.lbl}:"
            return
        # Identify the register that is used as a loop counter
        body_code = [line for line in body_code if line.text != ""]
        loop_cnt_reg = None
        for idx, line in enumerate(body_code):
            inst = Instruction.parser(line)
            # Flags are set through cmp
            # LIMITATION: By convention, we require the first argument to be the
            # "counter" and the second the one marking the iteration end.
            # TODO: make this work for more instructions after added
            if isinstance(inst[0], test_qi):
                # Assume this mapping
                loop_cnt_reg = inst[0].args_in[0]
                loop_end_reg = inst[0].immediate[0]
                body_code[idx].add_tag("id", "test_qi")
                logging.debug(
                    f"Assuming {loop_cnt_reg} as counter register and {loop_end_reg} "
                    "as immediate value for end."
                )
                break
        if loop_cnt_reg is None:
            raise FatalParsingException("No flag-setting instruction found!")

        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            inst[0].immediate[0] *= unroll

        inc_per_iter = 0
        for idx, line in enumerate(body_code):
            inst = Instruction.parser(line)
            modifies_counter = False
            # Increment happens through pointer modification
            if loop_cnt_reg.lower() == inst[0].addr and inst[0].increment is not None:
                inc_per_iter = inc_per_iter + simplify(inst[0].increment)
                modifies_counter = True
            # Increment through explicit modification
            elif (
                loop_cnt_reg.lower() in (inst[0].args_out + inst[0].args_in_out)
                and inst[0].immediate is not None
            ):
                # TODO: subtract if we have a subtraction
                inc_per_iter = inc_per_iter + simplify(inst[0].immediate)
                modifies_counter = True
            if modifies_counter:
                body_code[idx].add_tags({"before": "cmp", "core": "True"})
        logging.debug(
            f"Loop counter {loop_cnt_reg} is incremented by {inc_per_iter} per iteration."
        )

        if fixup != 0:
            yield f"{indent}sub {loop_end_reg}, {loop_end_reg}, #{fixup*inc_per_iter}"

        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl}:"

    def end(self, other, indentation=0):
        """Nothing to do here"""
        yield f"{' ' * indentation}j{self.additional_data['br_type']} {self.lbl}"


def iter_x86_64_instructions():
    yield from all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_x86_64_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise UnknownInstruction(
        f"Couldn't find instruction class for {src} (type {type(src)})"
    )


# Load the instruction model. These modules import RegisterType from this module,
# so they are imported last, once it is defined.
from slothy.targets.x86_64 import x86_64_base_instructions  # noqa: E402, F401
from slothy.targets.x86_64 import x86_64_sse_instructions  # noqa: E402, F401
from slothy.targets.x86_64 import x86_64_avx_instructions  # noqa: E402, F401

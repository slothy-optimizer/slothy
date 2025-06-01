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
Partial SLOTHY architecture model for AArch64

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
from sympy import simplify

from unicorn import (
    UC_ARCH_ARM64,
    UC_MODE_ARM,
)
from unicorn.arm64_const import (
    UC_ARM64_REG_X0,
    UC_ARM64_REG_X1,
    UC_ARM64_REG_X2,
    UC_ARM64_REG_X3,
    UC_ARM64_REG_X4,
    UC_ARM64_REG_X5,
    UC_ARM64_REG_X6,
    UC_ARM64_REG_X7,
    UC_ARM64_REG_X8,
    UC_ARM64_REG_X9,
    UC_ARM64_REG_X10,
    UC_ARM64_REG_X11,
    UC_ARM64_REG_X12,
    UC_ARM64_REG_X13,
    UC_ARM64_REG_X14,
    UC_ARM64_REG_X15,
    UC_ARM64_REG_X16,
    UC_ARM64_REG_X17,
    UC_ARM64_REG_X18,
    UC_ARM64_REG_X19,
    UC_ARM64_REG_X20,
    UC_ARM64_REG_X21,
    UC_ARM64_REG_X22,
    UC_ARM64_REG_X23,
    UC_ARM64_REG_X24,
    UC_ARM64_REG_X25,
    UC_ARM64_REG_X26,
    UC_ARM64_REG_X27,
    UC_ARM64_REG_X28,
    UC_ARM64_REG_X29,
    UC_ARM64_REG_X30,
    UC_ARM64_REG_SP,
    UC_ARM64_REG_PC,
    UC_ARM64_REG_V0,
    UC_ARM64_REG_V1,
    UC_ARM64_REG_V2,
    UC_ARM64_REG_V3,
    UC_ARM64_REG_V4,
    UC_ARM64_REG_V5,
    UC_ARM64_REG_V6,
    UC_ARM64_REG_V7,
    UC_ARM64_REG_V8,
    UC_ARM64_REG_V9,
    UC_ARM64_REG_V10,
    UC_ARM64_REG_V11,
    UC_ARM64_REG_V12,
    UC_ARM64_REG_V13,
    UC_ARM64_REG_V14,
    UC_ARM64_REG_V15,
    UC_ARM64_REG_V16,
    UC_ARM64_REG_V17,
    UC_ARM64_REG_V18,
    UC_ARM64_REG_V19,
    UC_ARM64_REG_V20,
    UC_ARM64_REG_V21,
    UC_ARM64_REG_V22,
    UC_ARM64_REG_V23,
    UC_ARM64_REG_V24,
    UC_ARM64_REG_V25,
    UC_ARM64_REG_V26,
    UC_ARM64_REG_V27,
    UC_ARM64_REG_V28,
    UC_ARM64_REG_V29,
    UC_ARM64_REG_V30,
    UC_ARM64_REG_V31,
)


from slothy.targets.common import FatalParsingException, UnknownInstruction
from slothy.helper import Loop, SourceLine

arch_name = "Arm_AArch64"

llvm_mca_arch = "aarch64"
llvm_mc_arch = "aarch64"
# Always add aes flag for llvm-mc assembly -- assuming that the user will not
# use aes instructions on CPUs that do not support it
llvm_mc_attr = "aes"

unicorn_arch = UC_ARCH_ARM64
unicorn_mode = UC_MODE_ARM


class RegisterType(Enum):
    GPR = 1
    NEON = 2
    STACK_NEON = 3
    STACK_GPR = 4
    FLAGS = 5
    HINT = 6

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    @cache
    def _spillable(reg_type):
        return reg_type in [RegisterType.GPR]  # For now, only GPRs

    # TODO: remove workaround (needed for Python 3.9)
    spillable = staticmethod(_spillable)

    @staticmethod
    def callee_saved_registers():
        return [f"x{i}" for i in range(18, 31)] + [f"v{i}" for i in range(8, 16)]

    @staticmethod
    def unicorn_link_register():
        return UC_ARM64_REG_X30

    @staticmethod
    def unicorn_stack_pointer():
        return UC_ARM64_REG_SP

    @staticmethod
    def unicorn_program_counter():
        return UC_ARM64_REG_PC

    @cache
    def _unicorn_reg_by_name(reg):
        """Converts string name of register into numerical identifiers used
        within the unicorn engine"""

        d = {
            "x0": UC_ARM64_REG_X0,
            "x1": UC_ARM64_REG_X1,
            "x2": UC_ARM64_REG_X2,
            "x3": UC_ARM64_REG_X3,
            "x4": UC_ARM64_REG_X4,
            "x5": UC_ARM64_REG_X5,
            "x6": UC_ARM64_REG_X6,
            "x7": UC_ARM64_REG_X7,
            "x8": UC_ARM64_REG_X8,
            "x9": UC_ARM64_REG_X9,
            "x10": UC_ARM64_REG_X10,
            "x11": UC_ARM64_REG_X11,
            "x12": UC_ARM64_REG_X12,
            "x13": UC_ARM64_REG_X13,
            "x14": UC_ARM64_REG_X14,
            "x15": UC_ARM64_REG_X15,
            "x16": UC_ARM64_REG_X16,
            "x17": UC_ARM64_REG_X17,
            "x18": UC_ARM64_REG_X18,
            "x19": UC_ARM64_REG_X19,
            "x20": UC_ARM64_REG_X20,
            "x21": UC_ARM64_REG_X21,
            "x22": UC_ARM64_REG_X22,
            "x23": UC_ARM64_REG_X23,
            "x24": UC_ARM64_REG_X24,
            "x25": UC_ARM64_REG_X25,
            "x26": UC_ARM64_REG_X26,
            "x27": UC_ARM64_REG_X27,
            "x28": UC_ARM64_REG_X28,
            "x29": UC_ARM64_REG_X29,
            "x30": UC_ARM64_REG_X30,
            "v0": UC_ARM64_REG_V0,
            "v1": UC_ARM64_REG_V1,
            "v2": UC_ARM64_REG_V2,
            "v3": UC_ARM64_REG_V3,
            "v4": UC_ARM64_REG_V4,
            "v5": UC_ARM64_REG_V5,
            "v6": UC_ARM64_REG_V6,
            "v7": UC_ARM64_REG_V7,
            "v8": UC_ARM64_REG_V8,
            "v9": UC_ARM64_REG_V9,
            "v10": UC_ARM64_REG_V10,
            "v11": UC_ARM64_REG_V11,
            "v12": UC_ARM64_REG_V12,
            "v13": UC_ARM64_REG_V13,
            "v14": UC_ARM64_REG_V14,
            "v15": UC_ARM64_REG_V15,
            "v16": UC_ARM64_REG_V16,
            "v17": UC_ARM64_REG_V17,
            "v18": UC_ARM64_REG_V18,
            "v19": UC_ARM64_REG_V19,
            "v20": UC_ARM64_REG_V20,
            "v21": UC_ARM64_REG_V21,
            "v22": UC_ARM64_REG_V22,
            "v23": UC_ARM64_REG_V23,
            "v24": UC_ARM64_REG_V24,
            "v25": UC_ARM64_REG_V25,
            "v26": UC_ARM64_REG_V26,
            "v27": UC_ARM64_REG_V27,
            "v28": UC_ARM64_REG_V28,
            "v29": UC_ARM64_REG_V29,
            "v30": UC_ARM64_REG_V30,
            "v31": UC_ARM64_REG_V31,
        }
        return d.get(reg, None)

    # TODO: remove workaround (needed for Python 3.9)
    unicorn_reg_by_name = staticmethod(_unicorn_reg_by_name)

    @cache
    def _list_registers(
        reg_type, only_extra=False, only_normal=False, with_variants=False
    ):
        """Return the list of all registers of a given type"""

        qstack_locations = [f"QSTACK{i}" for i in range(8)]
        stack_locations = [f"STACK{i}" for i in range(8)]

        gprs_normal = [f"x{i}" for i in range(31)] + ["sp"]
        vregs_normal = [f"v{i}" for i in range(32)]

        gprs_extra = []
        vregs_extra = []

        gprs_variants = [f"w{i}" for i in range(31)]
        vregs_variants = [f"q{i}" for i in range(32)]

        gprs = []
        vregs = []
        hints = (
            [f"t{i}" for i in range(100)]
            + [f"t{i}{j}" for i in range(8) for j in range(8)]
            + [f"t{i}_{j}" for i in range(16) for j in range(16)]
        )

        flags = ["flags"]
        if not only_extra:
            gprs += gprs_normal
            vregs += vregs_normal
        if not only_normal:
            gprs += gprs_extra
            vregs += vregs_extra
        if with_variants:
            gprs += gprs_variants
            vregs += vregs_variants

        return {
            RegisterType.GPR: gprs,
            RegisterType.STACK_GPR: stack_locations,
            RegisterType.STACK_NEON: qstack_locations,
            RegisterType.NEON: vregs,
            RegisterType.HINT: hints,
            RegisterType.FLAGS: flags,
        }[reg_type]

    # TODO: remove workaround (needed for Python 3.9)
    list_registers = staticmethod(_list_registers)

    @staticmethod
    def find_type(r):
        """Find type of architectural register"""

        if r.startswith("hint_"):
            return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty

        return None

    @staticmethod
    def is_renamed(ty):
        """Indicate if register type should be subject to renaming"""
        if ty == RegisterType.HINT:
            return False
        return True

    @staticmethod
    def from_string(string):
        """Find registe type from string"""
        string = string.lower()
        return {
            "qstack": RegisterType.STACK_NEON,
            "stack": RegisterType.STACK_GPR,
            "neon": RegisterType.NEON,
            "gpr": RegisterType.GPR,
            "hint": RegisterType.HINT,
            "flags": RegisterType.FLAGS,
        }.get(string, None)

    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(["flags", "sp"] + RegisterType.list_registers(RegisterType.HINT))

    @staticmethod
    def default_aliases():
        "Register aliases used by the architecture"
        return {}


class Branch:
    """Helper for emitting branches"""

    @staticmethod
    def if_equal(cnt, val, lbl):
        """Emit assembly for a branch-if-equal sequence"""
        yield f"cmp {cnt}, #{val}"
        yield f"b.eq {lbl}"

    @staticmethod
    def if_greater_equal(cnt, val, lbl):
        """Emit assembly for a branch-if-greater-equal sequence"""
        yield f"cmp {cnt}, #{val}"
        yield f"b.ge {lbl}"

    @staticmethod
    def unconditional(lbl):
        """Emit unconditional branch"""
        yield f"b {lbl}"


class SubLoop(Loop):
    """
    Loop ending in a (optionally flag setting) subtraction and a branch.

    Example:

    .. code-block:: asm

        loop_lbl:
           {code}
           sub[s] <cnt>, <cnt>, #<imm>
           (cbnz|cbz) <cnt>, loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl="lbl") -> None:
        super().__init__()
        # The group naming in the regex should be consistent; give same group
        # names to the same registers
        self.lbl = lbl
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            r"^\s*(?P<sub_type>sub[s]?)\s+(?P<cnt>\w+),\s*(?P<reg1>\w+),\s*#(?P<imm>\d+)",
            rf"^\s*(?P<br_type>(cbnz|cbz))\s+(?P<cnt>\w+),\s*{lbl}",
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
        indent = " " * indentation
        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield f"{indent}lsr {loop_cnt}, {loop_cnt}, #{int(math.log2(unroll))}"
        if fixup != 0:
            # In case the immediate is >1, we need to scale the fixup. This
            # allows for loops that do not use an increment of 1
            assert isinstance(fixup, int)
            fixup = simplify(f"{fixup} * ({self.additional_data['imm']})")
            yield f"{indent}sub {loop_cnt}, {loop_cnt}, #{fixup}"
        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        indent = " " * indentation
        lbl_start = self.lbl
        if lbl_start.isdigit():
            lbl_start += "b"

        yield (
            f"{indent}{other['sub_type']} {other['cnt']}, {other['cnt']}"
            f", {other['imm']}"
        )
        yield f"{indent}{other['br_type']} {other['cnt']}, {lbl_start}"


class SubsLoop(Loop):
    """
    Loop ending in a (optionally flag setting) subtraction and a branch.

    Example:

    .. code-block:: asm

        loop_lbl:
           {code}
           subs   <cnt>, <cnt>, #<imm>
           b[.](cond) loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl="lbl") -> None:
        super().__init__()
        # The group naming in the regex should be consistent; give same group
        # names to the same registers
        self.lbl = lbl
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            r"^\s*(?P<sub_type>subs)\s+(?P<cnt>\w+),\s*(?P<reg1>\w+),\s*#(?P<imm>\w+)",
            rf"^\s*b(?P<br_type>"
            rf"[\.]?(eq|ne|cs|hs|cc|lo|mi|pl|vs|vc|hi|ls|ge|lt|gt|le|al))"
            rf"\s+{lbl}",
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
        indent = " " * indentation
        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield f"{indent}lsr {loop_cnt}, {loop_cnt}, #{int(math.log2(unroll))}"
        if fixup != 0:
            # In case the immediate is >1, we need to scale the fixup. This
            # allows for loops that do not use an increment of 1
            assert isinstance(fixup, int)
            fixup = simplify(f"{fixup} * ({self.additional_data['imm']})")
            yield f"{indent}sub {loop_cnt}, {loop_cnt}, #{fixup}"
        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        indent = " " * indentation
        lbl_start = self.lbl
        if lbl_start.isdigit():
            lbl_start += "b"

        # Set flag in subtraction
        yield (f"{indent}subs {other['cnt']}, {other['cnt']}" f", #{other['imm']}")
        # Conditional branch based on flag
        yield f"{indent}b{other['br_type']} {lbl_start}"


class Instruction:

    class ParsingException(Exception):
        """An attempt to parse an assembly line as a specific instruction failed

        This is a frequently encountered exception since assembly lines are parsed by
        trial and error, iterating over all instruction parsers."""

        def __init__(self, err=None):
            super().__init__(err)

    def __init__(
        self, *, mnemonic, arg_types_in=None, arg_types_in_out=None, arg_types_out=None
    ):

        if arg_types_in is None:
            arg_types_in = []
        if arg_types_out is None:
            arg_types_out = []
        if arg_types_in_out is None:
            arg_types_in_out = []

        self.mnemonic = mnemonic

        self.args_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_combinations = None
        self.args_in_out_different = None
        self.args_in_inout_different = None

        self.arg_types_in = arg_types_in
        self.arg_types_out = arg_types_out
        self.arg_types_in_out = arg_types_in_out
        self.num_in = len(arg_types_in)
        self.num_out = len(arg_types_out)
        self.num_in_out = len(arg_types_in_out)

        self.args_out_restrictions = [None for _ in range(self.num_out)]
        self.args_in_restrictions = [None for _ in range(self.num_in)]
        self.args_in_out_restrictions = [None for _ in range(self.num_in_out)]

        self.args_in = []
        self.args_out = []
        self.args_in_out = []

        self.addr = None
        self.increment = None
        self.pre_index = None
        self.offset_adjustable = True

        self.immediate = None
        self.datatype = None
        self.index = None
        self.flag = None

    def extract_read_writes(self):
        """Extracts 'reads'/'writes' clauses from the source line of the instruction"""

        src_line = self.source_line

        def hint_register_name(tag):
            return f"hint_{tag}"

        # Check if the source line is tagged as reading/writing from memory
        def add_memory_write(tag):
            self.num_out += 1
            self.args_out_restrictions.append(None)
            self.args_out.append(hint_register_name(tag))
            self.arg_types_out.append(RegisterType.HINT)

        def add_memory_read(tag):
            self.num_in += 1
            self.args_in_restrictions.append(None)
            self.args_in.append(hint_register_name(tag))
            self.arg_types_in.append(RegisterType.HINT)

        write_tags = src_line.tags.get("writes", [])
        read_tags = src_line.tags.get("reads", [])

        if not isinstance(write_tags, list):
            write_tags = [write_tags]

        if not isinstance(read_tags, list):
            read_tags = [read_tags]

        for w in write_tags:
            add_memory_write(w)

        for r in read_tags:
            add_memory_read(r)

        return self

    def global_parsing_cb(self, a, log=None):
        """Parsing callback triggered after DataFlowGraph parsing which allows
        modification of the instruction in the context of the overall computation.

        This is primarily used to remodel input-outputs as outputs in jointly destructive
        instruction patterns (See Section 4.4, https://eprint.iacr.org/2022/1303.pdf).
        """
        _ = log  # log is not used
        return False

    def global_fusion_cb(self, a, log=None):
        """Fusion callback triggered after DataFlowGraph parsing which allows fusing
        of the instruction in the context of the overall computation.

        This can be used e.g. to detect eor-eor pairs and replace them by eor3."""
        _ = log  # log is not used
        return False

    def write(self):
        """Write the instruction"""
        args = self.args_out + self.args_in_out + self.args_in
        return self.mnemonic + " " + ", ".join(args)

    @staticmethod
    def unfold_abbrevs(mnemonic):
        if mnemonic.count("<dt") > 1:
            for i in range(mnemonic.count("<dt")):
                mnemonic = re.sub(
                    f"<dt{i}>",
                    f"(?P<datatype{i}>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))",
                    mnemonic,
                )
        else:
            mnemonic = re.sub(
                "<dt>", "(?P<datatype>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))", mnemonic
            )
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self, inst):
                return True
        return False

    # vector
    def is_q_form_vector_instruction(self):
        """Indicates whether an instruction is Neon instruction operating on
        a 128-bit vector"""

        # For most instructions, we infer their operating size from explicit
        # datatype annotations. Others need listing explicitly.

        if self.datatype is None:
            return self._is_instance_of([Str_Q, Ldr_Q])

        # Operations on specific lanes are not counted as Q-form instructions
        if self._is_instance_of([Q_Ld2_Lane_Post_Inc]):
            return False

        dt = self.datatype
        if isinstance(dt, list):
            dt = dt[0]

        if dt.lower() in ["2d", "4s", "8h", "16b"]:
            return True
        if dt.lower() in ["1d", "2s", "4h", "8b"]:
            return False
        raise FatalParsingException(f"unknown datatype '{dt}' in {self}")

    def is_vector_load(self):
        """Indicates if an instruction is a Neon load instruction"""
        return self._is_instance_of([Ldr_Q, Ldp_Q, Ld2, Ld3, Ld4, Q_Ld2_Lane_Post_Inc])

    def is_vector_store(self):
        """Indicates if an instruction is a Neon store instruction"""
        return self._is_instance_of(
            [Str_Q, Stp_Q, St2, St3, St4, d_stp_stack_with_inc, d_str_stack_with_inc]
        )

    # scalar
    def is_scalar_load(self):
        """Indicates if an instruction is a scalar load instruction"""
        return self._is_instance_of([Ldr_X, Ldp_X])

    def is_scalar_store(self):
        """Indicates if an instruction is a scalar store instruction"""
        return self._is_instance_of([Stp_X, Str_X])

    # scalar or vector
    def is_load(self):
        """Indicates if an instruction is a scalar or Neon load instruction"""
        return self.is_vector_load() or self.is_scalar_load()

    def is_store(self):
        """Indicates if an instruction is a scalar or Neon store instruction"""
        return self.is_vector_store() or self.is_scalar_store()

    def is_load_store_instruction(self):
        """Indicates if an instruction is a scalar or Neon load or store instruction"""
        return self.is_load() or self.is_store()

    @classmethod
    def make(cls, src):
        """Abstract factory method parsing a string into an instruction instance."""

    @staticmethod
    def build(c: any, src: str, mnemonic: str, **kwargs: list) -> "Instruction":
        """Attempt to parse a string as an instance of an instruction.

        :param c: The target instruction the string should be attempted to be parsed as.
        :type c: any
        :param src: The string to parse.
        :type src: str
        :param mnemonic: The mnemonic of instruction c
        :type mnemonic: str
        :param **kwargs: Additional arguments to pass to the constructor of c.
        :type **kwargs: list

        :return: Upon success, the result of parsing src as an instance of c.
        :rtype: Instruction

        :raises Instruction.ParsingException: The str argument cannot be parsed as an
                instance of c.
        :raises FatalParsingException: A fatal error during parsing happened
                that's likely a bug in the model.
        """

        if src.split(" ")[0] != mnemonic:
            raise Instruction.ParsingException("Mnemonic does not match")

        obj = c(mnemonic=mnemonic, **kwargs)

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(obj.mnemonic)

        expected_args = obj.num_in + obj.num_out + obj.num_in_out
        regexp_txt = rf"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += r"\s+"
        regexp_txt += ",".join([r"\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(
                f"Doesn't match basic instruction template {regexp_txt}"
            )

        operands = list(p.groups())

        if obj.num_out > 0:
            obj.args_out = operands[: obj.num_out]
            idx_args_in = obj.num_out
        elif obj.num_in_out > 0:
            obj.args_in_out = operands[: obj.num_in_out]
            idx_args_in = obj.num_in_out
        else:
            idx_args_in = 0

        obj.args_in = operands[idx_args_in:]

        if not len(obj.args_in) == obj.num_in:
            raise FatalParsingException(
                f"Something wrong parsing {src}: Expect {obj.num_in} input,"
                f" but got {len(obj.args_in)} ({obj.args_in})"
            )

        return obj

    @staticmethod
    def parser(src_line):
        """Global factory method parsing an assembly line into an instance
        of a subclass of Instruction."""
        insts = []
        exceptions = {}
        instnames = []

        src = src_line.text.strip()

        # Iterate through all derived classes and call their parser
        # until one of them hopefully succeeds
        for inst_class in Instruction.all_subclass_leaves:
            try:
                inst = inst_class.make(src)
                instnames = [inst_class.__name__]
                insts = [inst]
                break
            except Instruction.ParsingException as e:
                exceptions[inst_class.__name__] = e

        for i in insts:
            i.source_line = src_line
            i.extract_read_writes()

        if len(insts) == 0:
            logging.error("Failed to parse instruction %s", src)
            logging.error("A list of attempted parsers and their exceptions follows.")
            for i, e in exceptions.items():
                msg = f"* {i + ':':20s} {e}"
                logging.error(msg)
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support "
                "for a new instruction (variant)?"
            )

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()


class AArch64Instruction(Instruction):
    """Abstract class representing AArch64 instructions"""

    PARSERS = {}

    @staticmethod
    def _unfold_pattern(src):

        # Those replacements may look pointless, but they replace
        # actual whitespaces before/after '.,[]' in the instruction
        # pattern by regular expressions allowing flexible whitespacing.
        flexible_spacing = [
            (r"\s*,\s*", r"\\s*,\\s*"),
            (r"\s*<imm>\s*", r"\\s*<imm>\\s*"),
            (r"\s*\[\s*", r"\\s*\\[\\s*"),
            (r"\s*\]\s*", r"\\s*\\]\\s*"),
            (r"\s*\.\s*", r"\\s*\\.\\s*"),
            (r"\s+", r"\\s+"),
            (r"\\s\*\\s\\+", r"\\s+"),
            (r"\\s\+\\s\\*", r"\\s+"),
            (r"(\\s\*)+", r"\\s*"),
        ]
        for c, cp in flexible_spacing:
            src = re.sub(c, cp, src)

        def pattern_transform(g):
            return (
                f"([{g.group(1).lower()}{g.group(1)}]"
                f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|"
                f"([{g.group(1).lower()}{g.group(1)}]"
                f"<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"
            )

        src = re.sub(r"<([BHWXVQTD])(\w+)>", pattern_transform, src)

        # Replace <key> or <key0>, <key1>, ... with pattern
        def replace_placeholders(src, mnemonic_key, regexp, group_name):
            prefix = f"<{mnemonic_key}"
            pattern = f"<{mnemonic_key}>"

            def pattern_i(i):
                return f"<{mnemonic_key}{i}>"

            cnt = src.count(prefix)
            if cnt > 1:
                for i in range(cnt):
                    src = re.sub(pattern_i(i), f"(?P<{group_name}{i}>{regexp})", src)
            else:
                src = re.sub(pattern, f"(?P<{group_name}>{regexp})", src)

            return src

        flaglist = [
            "eq",
            "ne",
            "cs",
            "hs",
            "cc",
            "lo",
            "mi",
            "pl",
            "vs",
            "vc",
            "hi",
            "ls",
            "ge",
            "lt",
            "gt",
            "le",
        ]

        flag_pattern = "|".join(flaglist)
        dt_pattern = "(?:|2|4|8|16)(?:B|H|S|D|b|h|s|d)"
        imm_pattern = "#(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"

        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = replace_placeholders(src, "dt", dt_pattern, "datatype")
        src = replace_placeholders(src, "index", index_pattern, "index")
        src = replace_placeholders(src, "flag", flag_pattern, "flag")

        src = r"\s*" + src + r"\s*(//.*)?\Z"
        return src

    @staticmethod
    def _build_parser(src):
        regexp_txt = AArch64Instruction._unfold_pattern(src)
        regexp = re.compile(regexp_txt)

        def _parse(line):
            regexp_result = regexp.match(line)
            if regexp_result is None:
                raise Instruction.ParsingException(
                    f"Does not match instruction pattern {src}" f"[regex: {regexp_txt}]"
                )
            res = regexp.match(line).groupdict()
            items = list(res.items())
            for k, v in items:
                for prefix in ["symbol_", "raw_"]:
                    if k.startswith(prefix):
                        del res[k]
                        if v is None:
                            continue
                        k = k[len(prefix) :]
                        res[k] = v
            return res

        return _parse

    @staticmethod
    def get_parser(pattern):
        """Build parser for given AArch64 instruction pattern"""
        if pattern in AArch64Instruction.PARSERS:
            return AArch64Instruction.PARSERS[pattern]
        parser = AArch64Instruction._build_parser(pattern)
        AArch64Instruction.PARSERS[pattern] = parser
        return parser

    @cache
    def __infer_register_type(ptrn):
        if ptrn[0].upper() in ["X", "W"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["V", "Q", "D", "B"]:
            return RegisterType.NEON
        if ptrn[0].upper() in ["T"]:
            return RegisterType.HINT
        raise FatalParsingException(f"Unknown pattern: {ptrn}")

    # TODO: remove workaround (needed for Python 3.9)
    _infer_register_type = staticmethod(__infer_register_type)

    def __init__(
        self,
        pattern,
        *,
        inputs=None,
        outputs=None,
        in_outs=None,
        modifiesFlags=False,
        dependsOnFlags=False,
    ):

        self.mnemonic = pattern.split(" ")[0]

        if inputs is None:
            inputs = []
        if outputs is None:
            outputs = []
        if in_outs is None:
            in_outs = []
        arg_types_in = [AArch64Instruction._infer_register_type(r) for r in inputs]
        arg_types_out = [AArch64Instruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [AArch64Instruction._infer_register_type(r) for r in in_outs]

        if modifiesFlags:
            arg_types_out += [RegisterType.FLAGS]
            outputs += ["flags"]

        if dependsOnFlags:
            arg_types_in += [RegisterType.FLAGS]
            inputs += ["flags"]

        super().__init__(
            mnemonic=pattern,
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.inputs = inputs
        self.outputs = outputs
        self.in_outs = in_outs

        self.pattern = pattern
        assert len(inputs) == len(arg_types_in)
        self.pattern_inputs = list(zip(inputs, arg_types_in))
        assert len(outputs) == len(arg_types_out)
        self.pattern_outputs = list(zip(outputs, arg_types_out))
        assert len(in_outs) == len(arg_types_in_out)
        self.pattern_in_outs = list(zip(in_outs, arg_types_in_out))

    @staticmethod
    def _to_reg(ty, s):
        if ty == RegisterType.GPR:
            c = "x"
        elif ty == RegisterType.NEON:
            c = "v"
        elif ty == RegisterType.HINT:
            c = "t"
        else:
            assert False
        if s.replace("_", "").isdigit():
            return f"{c}{s}"
        return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        if ty == RegisterType.GPR:
            if arg[0] != "x":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.NEON:
            if arg[0] != "v":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.HINT:
            if arg[0] != "t":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        if ty == RegisterType.FLAGS:
            return out
        rep = AArch64Instruction._build_pattern_replacement(s, ty, arg)
        res = out.replace(f"<{s}>", rep)
        if res == out:
            raise FatalParsingException(f"Failed to replace <{s}> by {rep} in {out}!")
        return res

    @staticmethod
    def build_core(obj, res):

        def group_to_attribute(group_name, attr_name, f=None):
            def f_default(x):
                return x

            def group_name_i(i):
                return f"{group_name}{i}"

            if f is None:
                f = f_default
            if group_name in res.keys():
                setattr(obj, attr_name, f(res[group_name]))
            else:
                idxs = [i for i in range(4) if group_name_i(i) in res.keys()]
                if len(idxs) == 0:
                    return
                assert idxs == list(range(len(idxs)))
                setattr(
                    obj, attr_name, list(map(lambda i: f(res[group_name_i(i)]), idxs))
                )

        group_to_attribute("datatype", "datatype", lambda x: x.lower())
        group_to_attribute("imm", "immediate", lambda x: x[1:])  # Strip '#'
        group_to_attribute("index", "index", int)
        group_to_attribute("flag", "flag")

        for s, ty in obj.pattern_inputs:
            if ty == RegisterType.FLAGS:
                obj.args_in.append("flags")
            else:
                obj.args_in.append(AArch64Instruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            if ty == RegisterType.FLAGS:
                obj.args_out.append("flags")
            else:
                obj.args_out.append(AArch64Instruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(AArch64Instruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c, "modifiesFlags", False)
        depends_on_flags = getattr(c, "dependsOnFlags", False)

        if isinstance(src, str):
            if src.split(" ")[0] != pattern.split(" ")[0]:
                raise Instruction.ParsingException("Mnemonic does not match")
            res = AArch64Instruction.get_parser(pattern)(src)
        else:
            assert isinstance(src, dict)
            res = src

        obj = c(
            pattern,
            inputs=inputs,
            outputs=outputs,
            in_outs=in_outs,
            modifiesFlags=modifies_flags,
            dependsOnFlags=depends_on_flags,
        )

        AArch64Instruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return AArch64Instruction.build(cls, src)

    def write(self):
        out = self.pattern
        ll = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )
        for arg, (s, ty) in ll:
            out = AArch64Instruction._instantiate_pattern(s, ty, arg, out)

        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x

            if t is None:
                t = t_default

            a = getattr(self, attr_name)
            if a is None:
                return txt
            if not isinstance(a, list):
                txt = txt.replace(f"<{mnemonic_key}>", t(a))
                return txt
            for i, v in enumerate(a):
                txt = txt.replace(f"<{mnemonic_key}{i}>", t(v))
            return txt

        out = replace_pattern(out, "immediate", "imm", lambda x: f"#{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out


####################################################################################
#                                                                                  #
# Virtual instruction to model pushing to stack locations without modelling memory #
#                                                                                  #
####################################################################################


class qsave(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="qsave",
            arg_types_in=[RegisterType.NEON],
            arg_types_out=[RegisterType.STACK_NEON],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class qrestore(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="qrestore",
            arg_types_in=[RegisterType.STACK_NEON],
            arg_types_out=[RegisterType.NEON],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class save(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="save",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.STACK_GPR],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class restore(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="restore",
            arg_types_in=[RegisterType.STACK_GPR],
            arg_types_out=[RegisterType.GPR],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class nop(AArch64Instruction):
    pattern = "nop"


class vadd(AArch64Instruction):
    pattern = "add <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
    inputs = ["Vb", "Vc"]
    outputs = ["Va"]


class vsub(AArch64Instruction):
    pattern = "sub <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
    inputs = ["Vb", "Vc"]
    outputs = ["Va"]


############################
#                          #
# Some LSU instructions    #
#                          #
############################


class Ldr_Q(AArch64Instruction):
    pass


class Ldp_Q(AArch64Instruction):
    pass


class d_ldp_sp_imm(Ldr_Q):
    pattern = "ldp <Da>, <Db>, [sp, <imm>]"
    outputs = ["Da", "Db"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj


class q_ldr(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class q_ld1(Ldr_Q):
    pattern = "ld1 {<Va>.<dt>}, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Va"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class prefetch(Ldr_Q):
    pattern = "prfm pld1lkeep, [<Xc>, <imm>]"
    inputs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj


class q_ldr_with_imm_hint(Ldr_Q):
    pattern = "ldrh <Qa>, <Xc>, <imm>, <Th>"
    inputs = ["Xc", "Th"]
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class b_ldr_stack_with_inc(AArch64Instruction):
    pattern = "ldr <Ba>, [sp, <imm>]"
    # TODO: Model sp dependency
    outputs = ["Ba"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class d_ldr_stack_with_inc(AArch64Instruction):
    pattern = "ldr <Da>, [sp, <imm>]"
    # TODO: Model sp dependency
    outputs = ["Da"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class Q_Ld2_Lane_Post_Inc(AArch64Instruction):
    pass


class q_ld2_lane_post_inc(Q_Ld2_Lane_Post_Inc):
    pattern = "ld2 { <Va>.<dt0>, <Vb>.<dt1> }[<index>], [<Xa>], <imm>"
    in_outs = ["Va", "Vb", "Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.detected_q_ld2_lane_post_inc_pair = False
        obj.args_in_out_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 30)])
        ]
        return obj

    def write(self):
        return super().write()


class q_ld2_lane_post_inc_force_output(Q_Ld2_Lane_Post_Inc):
    pattern = "ld2 { <Va>.<dt0>, <Vb>.<dt1> }[<index>], [<Xa>], <imm>"
    # TODO: Model sp dependency
    in_outs = ["Xa"]
    outputs = ["Va", "Vb"]

    @classmethod
    def make(cls, src, force=False):
        if force is False:
            raise Instruction.ParsingException("Instruction ignored")

        obj = AArch64Instruction.build(cls, src)
        obj.args_out_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 30)])
        ]
        return obj

    def write(self):
        return super().write()


class q_ldr1_stack(AArch64Instruction):
    pattern = "ld1r {<Va>.<dt>}, [sp]"
    # TODO: Model sp dependency
    outputs = ["Va"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "sp"
        return obj

    def write(self):
        return super().write()


class q_ldr1_post_inc(AArch64Instruction):
    pattern = "ld1r {<Va>.<dt>}, [<Xa>], <imm>"
    outputs = ["Va"]
    in_outs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        return obj

    def write(self):
        return super().write()


class q_ldr_stack_with_inc(Ldr_Q):
    pattern = "ldr <Qa>, [sp, <imm>]"
    # TODO: Model sp dependency
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_ldr_with_inc(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>, <imm>]"
    inputs = ["Xc"]
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_ld1_with_inc(Ldr_Q):
    pattern = "ld1 {<Va>.<dt>}, [<Xc>, <imm>]"
    inputs = ["Xc"]
    outputs = ["Va"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_ldp_with_inc(Ldp_Q):
    pattern = "ldp <Qa>, <Qb>, [<Xc>, <imm>]"
    inputs = ["Xc"]
    outputs = ["Qa", "Qb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_ldr_with_inc_writeback(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>, <imm>]!"
    in_outs = ["Xc"]
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_ldr_with_postinc(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_ld1_with_postinc(Ldr_Q):
    pattern = "ld1 {<Va>.<dt>}, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Va"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_ldp_with_postinc(Ldp_Q):
    pattern = "ldp <Qa>, <Qb>, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Qa", "Qb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class Str_Q(AArch64Instruction):
    pass


class Stp_Q(AArch64Instruction):
    pass


class q_str(Str_Q):
    pattern = "str <Qa>, [<Xc>]"
    inputs = ["Qa", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class q_str_with_imm_hint(Str_Q):
    pattern = "strh <Qa>, <Xc>, <imm>, <Th>"
    inputs = ["Qa", "Xc"]
    outputs = ["Th"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_str_with_inc(Str_Q):
    pattern = "str <Qa>, [<Xc>, <imm>]"
    inputs = ["Qa", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class d_str_stack_with_inc(AArch64Instruction):
    pattern = "str <Da>, [sp, <imm>]"
    inputs = ["Da"]  # TODO: Model sp dependency

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_str_stack_with_inc(Str_Q):
    pattern = "str <Qa>, [sp, <imm>]"
    inputs = ["Qa"]  # TODO: Model sp dependency

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class d_stp_stack_with_inc(AArch64Instruction):
    pattern = "stp <Da>, <Db>, [sp, <imm>]"
    inputs = ["Da", "Db"]  # TODO: Model sp dependency

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_stp_stack_with_inc(AArch64Instruction):
    pattern = "stp <Qa>, <Qb>, [sp, <imm>]"
    inputs = ["Qa", "Qb"]  # TODO: Model sp dependency

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_stp_with_inc(Stp_Q):
    pattern = "stp <Qa>, <Qb>, [<Xc>, <imm>]"
    inputs = ["Qa", "Qb", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[2]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class q_str_with_inc_writeback(Str_Q):
    pattern = "str <Qa>, [<Xc>, <imm>]!"
    in_outs = ["Xc"]
    inputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_str_with_postinc(Str_Q):
    pattern = "str <Qa>, [<Xc>], <imm>"
    in_outs = ["Xc"]
    inputs = ["Qa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_st1_with_postinc(Str_Q):
    pattern = "st1 {<Va>.<dt>}, [<Xc>], <imm>"
    in_outs = ["Xc"]
    inputs = ["Va"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_stp_with_postinc(Stp_Q):
    pattern = "stp <Qa>, <Qb>, [<Xc>], <imm>"
    inputs = ["Qa", "Qb"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class q_st1_2_with_postinc(Stp_Q):
    pattern = "st1 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>], <imm>"
    inputs = ["Va", "Vb"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]

        obj.args_in_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 31)])
        ]
        return obj


class Ldr_X(AArch64Instruction):
    pass


class x_ldr(Ldr_X):
    pattern = "ldr <Xa>, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
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


class x_ldr_with_imm(Ldr_X):
    pattern = "ldr <Xa>, [<Xc>, <imm>]"
    inputs = ["Xc"]
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldr_with_imm_uxtw(Ldr_X):
    pattern = "ldr <Xd>, [<Xa>, <Xb>, UXTW <imm>]"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldr_with_imm_lsl(Ldr_X):
    pattern = "ldr <Xd>, [<Xa>, <Xb>, LSL <imm>]"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldr_with_postinc(Ldr_X):
    pattern = "ldr <Xa>, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class x_ldr_stack(Ldr_X):
    pattern = "ldr <Xa>, [sp]"
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "sp"
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index is None
        return super().write()


class x_ldr_stack_imm(Ldr_X):
    pattern = "ldr <Xa>, [sp, <imm>]"
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldr_stack_imm_with_hint(Ldr_X):
    pattern = "ldrh <Xa>, sp, <imm>, <Th>"
    inputs = ["Th"]
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldr_imm_with_hint(Ldr_X):
    pattern = "ldrh <Xa>, <Xb>, <imm>, <Th>"
    inputs = ["Xb", "Th"]
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class Ldp_X(AArch64Instruction):
    pass


class x_ldp(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
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


class x_ldp_with_imm_sp_xzr(Ldp_X):
    pattern = "ldp <Xa>, xzr, [sp, <imm>]"
    outputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_with_imm_sp(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [sp, <imm>]"
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_with_sp(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [sp]"
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "sp"
        return obj

    def write(self):
        return super().write()


class x_ldp_with_inc(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [<Xc>, <imm>]"
    inputs = ["Xc"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_with_inc_writeback(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [<Xc>, <imm>]!"
    in_outs = ["Xc"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class x_ldp_with_postinc_writeback(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class x_ldp_with_imm_hint(Ldp_X):
    pattern = "ldph <Xa>, <Xb>, <Xc>, <imm>, <Th>"
    inputs = ["Xc", "Th"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_sp_with_imm_hint(Ldp_X):
    pattern = "ldph <Xa>, <Xb>, sp, <imm>, <Th>"
    inputs = ["Th"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_sp_with_imm_hint2(Ldp_X):
    pattern = "ldphp <Xa>, <Xb>, sp, <imm>, <Th0>, <Th1>"
    inputs = ["Th0", "Th1"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_ldp_with_imm_hint2(Ldp_X):
    pattern = "ldphp <Xa>, <Xb>, <Xc>, <imm>, <Th0>, <Th1>"
    inputs = ["Xc", "Th0", "Th1"]
    outputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldr_sxtw_wform(AArch64Instruction):
    pattern = "ldr <Wd>, [<Xa>, <Wb>, SXTW <imm>]"
    inputs = ["Xa", "Wb"]
    outputs = ["Wd"]


############################
#                          #
# Some scalar instructions #
#                          #
############################


class lsr_wform(AArch64Instruction):
    pattern = "lsr <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


class asr_wform(AArch64Instruction):
    pattern = "asr <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class eor_wform(AArch64Instruction):
    pattern = "eor <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


class AArch64BasicArithmetic(AArch64Instruction):
    pass


class subs_wform(AArch64BasicArithmetic):
    pattern = "subs <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd"]
    modifiesFlags = True


class subs_imm(AArch64BasicArithmetic):
    pattern = "subs <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True


class sub_imm(AArch64BasicArithmetic):
    pattern = "sub <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class add_imm(AArch64BasicArithmetic):
    pattern = "add <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class add_sp_imm(AArch64BasicArithmetic):
    pattern = "add <Xd>, sp, <imm>"
    outputs = ["Xd"]


class neg(AArch64BasicArithmetic):
    pattern = "neg <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class negs(AArch64BasicArithmetic):
    pattern = "negs <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True


class ngc_zero(AArch64BasicArithmetic):
    pattern = "ngc <Xd>, xzr"
    inputs = []
    outputs = ["Xd"]
    dependsOnFlags = True


class ngcs(AArch64BasicArithmetic):
    pattern = "ngcs <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class ngcs_zero(AArch64BasicArithmetic):
    pattern = "ngcs <Xd>, xzr"
    inputs = []
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class adds(AArch64BasicArithmetic):
    pattern = "adds <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True


class adds_to_zero(AArch64BasicArithmetic):
    pattern = "adds xzr, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    modifiesFlags = True


class adds_imm_to_zero(AArch64BasicArithmetic):
    pattern = "adds xzr, <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags = True


class subs_twoarg(AArch64BasicArithmetic):
    pattern = "subs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True


class adds_twoarg(AArch64BasicArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True


class adcs(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class sbcs(AArch64BasicArithmetic):
    pattern = "sbcs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class sbcs_zero(AArch64BasicArithmetic):
    pattern = "sbcs <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class sbcs_to_zero(AArch64BasicArithmetic):
    pattern = "sbcs xzr, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = []
    modifiesFlags = True
    dependsOnFlags = True


class sbcs_zero_to_zero(AArch64BasicArithmetic):
    pattern = "sbcs xzr, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = []
    modifiesFlags = True
    dependsOnFlags = True


class sbc(AArch64BasicArithmetic):
    pattern = "sbc <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    dependsOnFlags = True


class sbc_zero_r(AArch64BasicArithmetic):
    pattern = "sbc <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags = True


class adcs_zero_r(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class adcs_zero_l(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, xzr, <Xb>"
    inputs = ["Xb"]
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class adcs_zero2(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, xzr, xzr"
    outputs = ["Xd"]
    modifiesFlags = True
    dependsOnFlags = True


class adcs_to_zero(AArch64BasicArithmetic):
    pattern = "adcs xzr, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    modifiesFlags = True
    dependsOnFlags = True


class adcs_zero_r_to_zero(AArch64BasicArithmetic):
    pattern = "adcs xzr, <Xa>, xzr"
    inputs = ["Xa"]
    modifiesFlags = True
    dependsOnFlags = True


class adc(AArch64BasicArithmetic):
    pattern = "adc <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    dependsOnFlags = True


class adc_zero2(AArch64BasicArithmetic):
    pattern = "adc <Xd>, xzr, xzr"
    outputs = ["Xd"]
    dependsOnFlags = True


class adc_zero_r(AArch64BasicArithmetic):
    pattern = "adc <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags = True


class adc_zero_l(AArch64BasicArithmetic):
    pattern = "adc <Xd>, xzr, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags = True


class add(AArch64BasicArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class add2(AArch64BasicArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class add_w_imm(AArch64BasicArithmetic):
    pattern = "add <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class sub(AArch64BasicArithmetic):
    pattern = "sub <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class AArch64ShiftedArithmetic(AArch64Instruction):
    pass


class eor_ror(AArch64ShiftedArithmetic):
    pattern = "eor <Xd>, <Xa>, <Xb>, ror <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class bic_ror(AArch64ShiftedArithmetic):
    pattern = "bic <Xd>, <Xa>, <Xb>, ror <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class add_lsl(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class add_lsr(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, lsr <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class adds_lsl(AArch64ShiftedArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True


class adds_lsr(AArch64ShiftedArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>, lsr <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags = True


class add_asr(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, asr <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class add_imm_lsl(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <imm0>, lsl <imm1>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class AArch64Shift(AArch64Instruction):
    pass


class lsr(AArch64Shift):
    pattern = "lsr <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


# TODO: This likely has different perf characteristics!
class lsr_variable(AArch64Shift):
    pattern = "lsr <Xd>, <Xa>, <Xc>"
    inputs = ["Xa", "Xc"]
    outputs = ["Xd"]


class lsl(AArch64Shift):
    pattern = "lsl <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class ror(AArch64Shift):
    pattern = "ror <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class asr(AArch64Shift):
    pattern = "asr <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class AArch64Logical(AArch64Instruction):
    pass


class rev_w(AArch64Logical):
    pattern = "rev <Wd>, <Wa>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class eor(AArch64Logical):
    pattern = "eor <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class orr(AArch64Logical):
    pattern = "orr <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class orr_w(AArch64Logical):
    pattern = "orr <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


class bfi(AArch64Logical):
    pattern = "bfi <Xd>, <Xa>, <imm0>, <imm1>"
    inputs = ["Xa"]
    in_outs = ["Xd"]


class and_imm(AArch64Logical):
    pattern = "and <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class ands_imm(AArch64Logical):
    pattern = "ands <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags = True


class ands_xzr_imm(AArch64Logical):
    pattern = "ands xzr, <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags = True


class and_twoarg(AArch64Logical):
    pattern = "and <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class bic(AArch64Logical):
    pattern = "bic <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class orr_imm(AArch64Logical):
    pattern = "orr <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class sbfx(AArch64Logical):
    pattern = "sbfx <Xd>, <Xa>, <imm0>, <imm1>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class ubfx(AArch64Logical):
    pattern = "ubfx <Xd>, <Xa>, <imm0>, <imm1>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class extr(AArch64Logical):  # TODO! Review this...
    pattern = "extr <Xd>, <Xa>, <Xb>, <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class AArch64LogicalShifted(AArch64Instruction):
    pass


class orr_shifted(AArch64LogicalShifted):
    pattern = "orr <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class orr_shifted_asr_w(AArch64LogicalShifted):
    pattern = "and <Wd>, <Wa>, <Wb>, asr <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


class orr_shifted_asr(AArch64LogicalShifted):
    pattern = "orr <Xd>, <Xa>, <Xb>, asr <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class eor_shifted_lsl(AArch64LogicalShifted):
    pattern = "eor <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class AArch64ConditionalCompare(AArch64Instruction):
    pass


class ccmp_xzr(AArch64ConditionalCompare):
    pattern = "ccmp <Xa>, xzr, <imm>, <flag>"
    inputs = ["Xa"]
    modifiesFlags = True
    dependsOnFlags = True


class ccmp(AArch64ConditionalCompare):
    pattern = "ccmp <Xa>, <Xb>, <imm>, <flag>"
    inputs = ["Xa", "Xb"]
    modifiesFlags = True
    dependsOnFlags = True


class AArch64ConditionalSelect(AArch64Instruction):
    pass


class cneg(AArch64ConditionalSelect):
    pattern = "cneg <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags = True


class csel_xzr_ne(AArch64ConditionalSelect):
    pattern = "csel <Xd>, <Xe>, xzr, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags = True


class csel_xzr2_ne(AArch64ConditionalSelect):
    pattern = "csel <Xd>, xzr, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags = True


class csel_ne(AArch64ConditionalSelect):
    pattern = "csel <Xd>, <Xe>, <Xf>, <flag>"
    inputs = ["Xe", "Xf"]
    outputs = ["Xd"]
    dependsOnFlags = True


class cinv(AArch64ConditionalSelect):
    pattern = "cinv <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags = True


class cinc(AArch64ConditionalSelect):
    pattern = "cinc <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags = True


class csetm(AArch64ConditionalSelect):
    pattern = "csetm <Xd>, <flag>"
    outputs = ["Xd"]
    dependsOnFlags = True


class cset(AArch64ConditionalSelect):
    pattern = "cset <Xd>, <flag>"
    outputs = ["Xd"]
    dependsOnFlags = True


class cmn(AArch64ConditionalSelect):
    pattern = "cmn <Xd>, <Xe>"
    inputs = ["Xd", "Xe"]
    modifiesFlags = True


class cmn_imm(AArch64ConditionalSelect):
    pattern = "cmn <Xd>, <imm>"
    inputs = ["Xd"]
    modifiesFlags = True


class ldr_const(AArch64Instruction):
    pattern = "ldr <Xd>, <imm>"
    inputs = []
    outputs = ["Xd"]


class movk_imm(AArch64Instruction):
    pattern = "movk <Xd>, <imm>"
    inputs = []
    in_outs = ["Xd"]


class mov(AArch64Instruction):
    pattern = "mov <Wd>, <Wa>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class AArch64Move(AArch64Instruction):
    pass


class mov_imm(AArch64Move):
    pattern = "mov <Xd>, <imm>"
    inputs = []
    outputs = ["Xd"]


class movw_imm(AArch64Move):
    pattern = "mov <Wd>, <imm>"
    inputs = []
    outputs = ["Wd"]


class mvn_xzr(AArch64Move):
    pattern = "mvn <Xd>, xzr"
    inputs = []
    outputs = ["Xd"]


class mov_xform(AArch64Move):
    pattern = "mov <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class umull_wform(AArch64Instruction):
    pattern = "umull <Xd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Xd"]


class umaddl_wform(AArch64Instruction):
    pattern = "umaddl <Xn>, <Wa>, <Wb>, <Xacc>"
    inputs = ["Wa", "Wb", "Xacc"]
    outputs = ["Xn"]


class mul_wform(AArch64Instruction):
    pattern = "mul <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


class AArch64HighMultiply(AArch64Instruction):
    pass


class umulh_xform(AArch64HighMultiply):
    pattern = "umulh <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class smulh_xform(AArch64HighMultiply):
    pattern = "smulh <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class AArch64Multiply(AArch64Instruction):
    pass


class mul_xform(AArch64Multiply):
    pattern = "mul <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class madd_xform(AArch64Multiply):
    pattern = "madd <Xd>, <Xacc>, <Xa>, <Xb>"
    inputs = ["Xacc", "Xa", "Xb"]
    outputs = ["Xd"]


class mneg_xform(AArch64Multiply):
    pattern = "mneg <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class msub_xform(AArch64Multiply):
    pattern = "msub <Xd>, <Xacc>, <Xa>, <Xb>"
    inputs = ["Xacc", "Xa", "Xb"]
    outputs = ["Xd"]


class and_imm_wform(AArch64Instruction):
    pattern = "and <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class Tst(AArch64Instruction):
    pass


class tst_wform(Tst):
    pattern = "tst <Wa>, <imm>"
    inputs = ["Wa"]
    modifiesFlags = True


class tst_imm_xform(Tst):
    pattern = "tst <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags = True


class tst_xform(Tst):
    pattern = "tst <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    modifiesFlags = True


class cmp(Tst):
    pattern = "cmp <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    modifiesFlags = True


class cmp_xzr(Tst):
    pattern = "cmp <Xa>, xzr"
    inputs = ["Xa"]
    modifiesFlags = True


class cmp_xzr2(Tst):
    pattern = "cmp xzr, xzr"
    inputs = []
    modifiesFlags = True


class cmp_imm(Tst):
    pattern = "cmp <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags = True


######################################################
#                                                    #
# Some 'wrappers' around AArch64 Neon instructions   #
#                                                    #
######################################################


class vmov(AArch64Instruction):
    pattern = "mov <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vmovi(AArch64Instruction):
    pattern = "movi <Vd>.<dt>, <imm>"
    outputs = ["Vd"]


class vxtn(AArch64Instruction):
    pattern = "xtn <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class Vrev(AArch64Instruction):
    pass


class rev64(Vrev):
    pattern = "rev64 <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class rev32(Vrev):
    pattern = "rev32 <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class uaddlp(AArch64Instruction):
    pattern = "uaddlp <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vand(AArch64Instruction):
    pattern = "and <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vbic(AArch64Instruction):
    pattern = "bic <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class Vzip(AArch64Instruction):
    pass


class vzip1(Vzip):
    pattern = "zip1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vzip2(Vzip):
    pattern = "zip2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vuzp1(Vzip):
    pattern = "uzp1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vuzp2(Vzip):
    pattern = "uzp2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vuxtl(AArch64Instruction):
    pattern = "uxtl <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]


class Vqdmulh(AArch64Instruction):
    pass


class vqrdmulh(Vqdmulh):
    pattern = "sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vqrdmulh_lane(Vqdmulh):
    pattern = "sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [
                [f"v{i}" for i in range(0, 32)],
                [f"v{i}" for i in range(0, 16)],
            ]
        return obj


class vqdmulh_lane(Vqdmulh):
    pattern = "sqdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [
                [f"v{i}" for i in range(0, 32)],
                [f"v{i}" for i in range(0, 16)],
            ]

        return obj


class fcsel_dform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="fcsel_dform",
            arg_types_in=[RegisterType.NEON, RegisterType.NEON, RegisterType.FLAGS],
            arg_types_out=[RegisterType.NEON],
        )

        regexp_txt = (
            r"fcsel_dform\s+(?P<dst>\w+)\s*,\s*(?P<src1>\w+)\s*,"
            r"\s*(?P<src2>\w+)\s*,\s*eq"
        )
        regexp_txt = Instruction.unfold_abbrevs(regexp_txt)
        regexp = re.compile(regexp_txt)
        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        obj.args_in = [p.group("src1"), p.group("src2"), "flags"]
        obj.args_out = [p.group("dst")]
        obj.args_in_out = []

        return obj

    def write(self):
        return (
            f"fcsel_dform {self.args_out[0]}, {self.args_in[0]}, {self.args_in[1]}, eq"
        )


class Vins(AArch64Instruction):
    pass


class vins_d(Vins):
    pattern = "ins <Vd>.d[<index>], <Xa>"
    inputs = ["Xa"]
    in_outs = ["Vd"]


class vins_d_force_output(Vins):
    pattern = "ins <Vd>.d[<index>], <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]

    @classmethod
    def make(cls, src, force=False):
        if force is False:
            raise Instruction.ParsingException("Instruction ignored")
        return AArch64Instruction.build(cls, src)


class Mov_xtov_d(AArch64Instruction):
    pass


class mov_xtov_d(Mov_xtov_d):
    pattern = "mov <Vd>.d[<index>], <Xa>"
    inputs = ["Xa"]
    in_outs = ["Vd"]


class mov_xtov_d_xzr(Mov_xtov_d):
    pattern = "mov <Vd>.d[<index>], xzr"
    in_outs = ["Vd"]


class mov_b00(AArch64Instruction):
    pattern = "mov <Vd>.b[0], <Va>.b[0]"
    inputs = ["Va"]
    in_outs = ["Vd"]


class mov_d01(AArch64Instruction):
    pattern = "mov <Vd>.d[0], <Va>.d[1]"
    inputs = ["Va"]
    in_outs = ["Vd"]


class SHA3Instruction(
    AArch64Instruction
):  # pylint: disable=missing-docstring,invalid-name
    pass


class vrax1(SHA3Instruction):  # pylint: disable=missing-docstring,invalid-name
    pattern = "rax1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class veor3(SHA3Instruction):  # pylint: disable=missing-docstring,invalid-name
    pattern = "eor3 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <Vc>.<dt3>"
    inputs = ["Va", "Vb", "Vc"]
    outputs = ["Vd"]


class vbcax(SHA3Instruction):  # pylint: disable=missing-docstring,invalid-name
    pattern = "bcax <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <Vc>.<dt3>"
    inputs = ["Va", "Vb", "Vc"]
    outputs = ["Vd"]


class vxar(SHA3Instruction):  # pylint: disable=missing-docstring,invalid-name
    pattern = "xar <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <imm>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class AArch64NeonLogical(AArch64Instruction):
    pass


class veor(AArch64NeonLogical):
    pattern = "eor <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vbif(AArch64NeonLogical):
    pattern = "bif <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


# Not sure about the classification as logical... couldn't find it in SWOG
class vmov_d(AArch64NeonLogical):
    pattern = "mov <Dd>, <Va>.d[1]"
    inputs = ["Va"]
    outputs = ["Dd"]


class vext(AArch64NeonLogical):
    pattern = "ext <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <imm>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vsri(AArch64NeonLogical):
    pattern = "sri <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    in_outs = ["Vd"]


class Vmul(AArch64Instruction):
    pass


class vmul(Vmul):
    pattern = "mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vmul_lane(Vmul):
    pattern = "mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [
                [f"v{i}" for i in range(0, 32)],
                [f"v{i}" for i in range(0, 16)],
            ]

        return obj


class Vmla(AArch64Instruction):
    pass


class vmla(Vmla):
    pattern = "mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


class vmla_lane(Vmla):
    pattern = "mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [
                [f"v{i}" for i in range(0, 32)],
                [f"v{i}" for i in range(0, 16)],
            ]
        return obj


class vmls(Vmla):
    pattern = "mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


class vmls_lane(Vmla):
    pattern = "mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [
                [f"v{i}" for i in range(0, 32)],
                [f"v{i}" for i in range(0, 16)],
            ]
        return obj


class vdup(AArch64Instruction):
    pattern = "dup <Vd>.<dt>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]


class Vmull(AArch64Instruction):
    pass


class vmull(Vmull):
    pattern = "umull <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vmull2(Vmull):
    pattern = "umull2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vsmull(Vmull):
    pattern = "smull <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class vsmull2(Vmull):
    pattern = "smull2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class Vmlal(AArch64Instruction):
    pass


class vmlal(Vmlal):
    pattern = "umlal <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


class vsmlal(Vmlal):
    pattern = "smlal <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


class vsmlal2(Vmlal):
    pattern = "smlal2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]


class VShiftImmediateBasic(AArch64Instruction):
    pass


class VShiftImmediateRounding(AArch64Instruction):
    pass


class vsrshr(VShiftImmediateRounding):
    pattern = "srshr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vurshr(VShiftImmediateRounding):
    pattern = "urshr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vsshr(VShiftImmediateBasic):
    pattern = "sshr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vushr(VShiftImmediateBasic):
    pattern = "ushr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vshl(VShiftImmediateBasic):
    pattern = "shl <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class vshl_d(AArch64Instruction):
    pattern = "shl <Dd>, <Da>, <imm>"
    inputs = ["Da"]
    outputs = ["Dd"]


class vshli(AArch64Instruction):
    pattern = "sli <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    in_outs = ["Vd"]


class vusra(AArch64Instruction):
    pattern = "usra <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    in_outs = ["Vd"]


class vshrn(AArch64Instruction):
    pattern = "shrn <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]


class VecToGprMov(AArch64Instruction):
    pass


class umov_d(VecToGprMov):
    pattern = "umov <Xd>, <Va>.d[<index>]"
    inputs = ["Va"]
    outputs = ["Xd"]


class mov_d(VecToGprMov):
    pattern = "mov <Xd>, <Va>.d[<index>]"
    inputs = ["Va"]
    outputs = ["Xd"]


class Fmov(AArch64Instruction):
    pass


class fmov_0(Fmov):
    pattern = "fmov <Dd>, <Xa>"
    inputs = ["Xa"]
    in_outs = ["Dd"]


class fmov_0_force_output(Fmov):
    pattern = "fmov <Dd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Dd"]

    @classmethod
    def make(cls, src, force=False):
        if force is False:
            raise Instruction.ParsingException("Instruction ignored")
        return AArch64Instruction.build(cls, src)


class fmov_1(Fmov):
    pattern = "fmov <Vd>.d[1], <Xa>"
    inputs = ["Xa"]
    in_outs = ["Vd"]


class fmov_1_force_output(Fmov):
    pattern = "fmov <Vd>.d[1], <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]

    @classmethod
    def make(cls, src, force=False):
        if force is False:
            raise Instruction.ParsingException("Instruction ignored")
        return AArch64Instruction.build(cls, src)


class Transpose(AArch64Instruction):
    pass


class trn1(Transpose):
    pattern = "trn1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class trn2(Transpose):
    pattern = "trn2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


# Wrapper around AESE+AESMC, treated as one instructions in SLOTHY
# so as to prevent pulling them apart and hindering instruction fusion.
class AESInstruction(AArch64Instruction):
    pass


class aesr(AESInstruction):
    pattern = "aesr <Vd>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs = ["Vd"]


class aesr_x2(AArch64Instruction):
    pattern = "aesr_x2 <Vd0>.16b, <Vd1>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs = ["Vd0", "Vd1"]


class aesr_x4(AArch64Instruction):
    pattern = "aesr_x4 <Vd0>.16b, <Vd1>.16b, <Vd2>.16b, <Vd3>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs = ["Vd0", "Vd1", "Vd2", "Vd3"]


class aese_x4(AArch64Instruction):
    pattern = "aese_x4 <Vd0>.16b, <Vd1>.16b, <Vd2>.16b, <Vd3>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs = ["Vd0", "Vd1", "Vd2", "Vd3"]


class aese(AESInstruction):
    pattern = "aese <Vd>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs = ["Vd"]


class aesmc(AESInstruction):
    pattern = "aesmc <Vd>.16b, <Va>.16b"
    inputs = ["Va"]
    outputs = ["Vd"]


class pmull1_q(AESInstruction):
    pattern = "pmull <Vd>.1q, <Va>.1d, <Vb>.1d"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class pmull2_q(AESInstruction):
    pattern = "pmull2 <Vd>.1q, <Va>.2d, <Vb>.2d"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class Str_X(AArch64Instruction):
    pass


class x_str(Str_X):
    pattern = "str <Xa>, [<Xc>]"
    inputs = ["Xa", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
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


class x_str_imm(Str_X):
    pattern = "str <Xa>, [<Xc>, <imm>]"
    inputs = ["Xa", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class w_str_imm(Str_X):
    pattern = "str <Wa>, [<Xc>, <imm>]"
    inputs = ["Wa", "Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class w_str_sp_imm(Str_X):
    pattern = "str <Wa>, [sp, <imm>]"
    inputs = ["Wa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_str_postinc(Str_X):
    pattern = "str <Xa>, [<Xc>], <imm>"
    inputs = ["Xa"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class x_str_sp_imm(Str_X):
    pattern = "str <Xa>, [sp, <imm>]"
    inputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_str_sp_imm_hint(Str_X):
    pattern = "strh <Xa>, sp, <imm>, <Th>"
    inputs = ["Xa"]
    outputs = ["Th"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_str_imm_hint(Str_X):
    pattern = "strh <Xa>, <Xb>, <imm>, <Th>"
    inputs = ["Xa", "Xb"]
    outputs = ["Th"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class Stp_X(AArch64Instruction):
    pass


class x_stp(Stp_X):
    pattern = "stp <Xa>, <Xb>, [<Xc>]"
    inputs = ["Xc", "Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the STP with increment.
        assert self.pre_index is None
        return super().write()


class x_stp_with_imm_xzr_sp(Stp_X):
    pattern = "stp <Xa>, xzr, [sp, <imm>]"
    inputs = ["Xa"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class w_stp_with_imm_sp(AArch64Instruction):
    pattern = "stp <Wa>, <Wb>, [sp, <imm>]"
    inputs = ["Wa", "Wb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_with_sp(Stp_X):
    pattern = "stp <Xa>, <Xb>, [sp]"
    inputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = "sp"
        return obj

    def write(self):
        return super().write()


class x_stp_with_imm_sp(Stp_X):
    pattern = "stp <Xa>, <Xb>, [sp, <imm>]"
    inputs = ["Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_with_inc(Stp_X):
    pattern = "stp <Xa>, <Xb>, [<Xc>, <imm>]"
    inputs = ["Xc", "Xa", "Xb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_with_inc_writeback(Stp_X):
    pattern = "stp <Xa>, <Xb>, [<Xc>, <imm>]!"
    inputs = ["Xa", "Xb"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class x_stp_with_imm_hint(Stp_X):
    pattern = "stph <Xa>, <Xb>, <Xc>, <imm>, <Th>"
    inputs = ["Xc", "Xa", "Xb"]
    outputs = ["Th"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_sp_with_imm_hint(Stp_X):
    pattern = "stph <Xa>, <Xb>, sp, <imm>, <Th>"
    inputs = ["Xa", "Xb"]
    outputs = ["Th"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_sp_with_imm_hint2(Stp_X):
    pattern = "stphp <Xa>, <Xb>, sp, <imm>, <Th0>, <Th1>"
    inputs = ["Xa", "Xb"]
    outputs = ["Th0", "Th1"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_with_imm_hint2(Stp_X):
    pattern = "stphp <Xa>, <Xb>, <Xc>, <imm>, <Th0>, <Th1>"
    inputs = ["Xa", "Xb", "Xc"]
    outputs = ["Th0", "Th1"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[2]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class St4(AArch64Instruction):
    pass


class st4_base(St4):
    pattern = "st4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>]"
    inputs = ["Xc", "Va", "Vb", "Vc", "Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_in_combinations = [
            (
                [1, 2, 3, 4],
                [[f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}"] for i in range(0, 29)],
            )
        ]
        return obj


class st4_with_inc(St4):
    pattern = "st4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>], <imm>"
    inputs = ["Va", "Vb", "Vc", "Vd"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_in_combinations = [
            (
                [0, 1, 2, 3],
                [[f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}"] for i in range(0, 29)],
            )
        ]
        return obj


class St3(AArch64Instruction):
    pass


class st3_base(St3):
    pattern = "st3 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>}, [<Xc>]"
    inputs = ["Xc", "Va", "Vb", "Vc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_in_combinations = [
            ([1, 2, 3], [[f"v{i}", f"v{i+1}", f"v{i+2}"] for i in range(0, 30)])
        ]
        return obj


class st3_with_inc(St3):
    pattern = "st3 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>}, [<Xc>], <imm>"
    inputs = ["Va", "Vb", "Vc"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_in_combinations = [
            ([0, 1, 2], [[f"v{i}", f"v{i+1}", f"v{i+2}"] for i in range(0, 30)])
        ]
        return obj


class St2(AArch64Instruction):
    pass


class st2_base(St2):
    pattern = "st2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>]"
    inputs = ["Xc", "Va", "Vb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_in_combinations = [
            ([1, 2], [[f"v{i}", f"v{i+1}"] for i in range(0, 31)])
        ]
        return obj


class st2_with_inc(St2):
    pattern = "st2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>], <imm>"
    inputs = ["Va", "Vb"]
    in_outs = ["Xc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_in_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 31)])
        ]
        return obj


class Ld4(AArch64Instruction):
    pass


class ld4_base(Ld4):
    pattern = "ld4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Va", "Vb", "Vc", "Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_out_combinations = [
            (
                [0, 1, 2, 3],
                [[f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}"] for i in range(0, 29)],
            )
        ]
        return obj


class ld4_with_inc(Ld4):
    pattern = "ld4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Va", "Vb", "Vc", "Vd"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_out_combinations = [
            (
                [0, 1, 2, 3],
                [[f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}"] for i in range(0, 29)],
            )
        ]
        return obj


class Ld3(AArch64Instruction):
    pass


class ld3_base(Ld3):
    pattern = "ld3 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>}, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Va", "Vb", "Vc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_out_combinations = [
            ([0, 1, 2], [[f"v{i}", f"v{i+1}", f"v{i+2}"] for i in range(0, 30)])
        ]
        return obj


class ld3_with_inc(Ld3):
    pattern = "ld3 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>}, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Va", "Vb", "Vc"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_out_combinations = [
            ([0, 1, 2], [[f"v{i}", f"v{i+1}", f"v{i+2}"] for i in range(0, 30)])
        ]
        return obj


class Ld2(AArch64Instruction):
    pass


class ld2_base(Ld2):
    pattern = "ld2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>]"
    inputs = ["Xc"]
    outputs = ["Va", "Vb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.offset_adjustable = False
        obj.addr = obj.args_in[0]
        obj.args_out_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 31)])
        ]
        return obj


class ld2_with_inc(Ld2):
    pattern = "ld2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>], <imm>"
    in_outs = ["Xc"]
    outputs = ["Va", "Vb"]

    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in_out[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_out_combinations = [
            ([0, 1], [[f"v{i}", f"v{i+1}"] for i in range(0, 31)])
        ]
        return obj


class ASimdCompare(AArch64Instruction):
    """Parent class for ASIMD compare instructions"""


class cmge(ASimdCompare):
    pattern = "cmge <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]


class Spill:
    def spill(reg, loc):
        return f"str {reg}, [sp, #STACK_LOC_{loc}]"

    def restore(reg, loc):
        return f"ldr {reg}, [sp, #STACK_LOC_{loc}]"


# In a pair of vins writing both 64-bit lanes of a vector, mark the
# target vector as output rather than input/output. This enables further
# renaming opportunities.
def vins_d_parsing_cb():
    def core(inst, t, log=None):
        _ = log  # log is not used
        succ = None
        # Check if this is the first in a pair of vins+vins
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, vins_d):
                if r.inst.args_in_out == inst.args_in_out and {
                    r.inst.index,
                    inst.index,
                } == {0, 1}:
                    succ = r
        if succ is None:
            return False

        # Reparse as instruction-variant treating the input/output as an output
        old_src = t.inst.source_line.copy()
        inst_txt = old_src.to_string(indentation=False)
        t.inst = vins_d_force_output.make(inst_txt, force=True)
        t.inst.source_line = old_src
        t.changed = True
        return True

    return core


vins_d.global_parsing_cb = vins_d_parsing_cb()


# In a pair of fmov writing both 64-bit lanes of a vector, mark the
# target vector as output rather than input/output. This enables further
# renaming opportunities.
def fmov_0_parsing_cb():
    def core(inst, t, log=None):
        _ = log  # log is not used
        succ = None
        r = None
        # Check if this is the first in a pair of fmov's
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, fmov_1):
                if r.inst.args_in_out == inst.args_in_out:
                    succ = r
        if succ is None:
            return False

        # Reparse as instruction-variant treating the input/output as an output
        old_src = t.inst.source_line.copy()
        inst_txt = old_src.to_string(indentation=False)
        t.inst = fmov_0_force_output.make(inst_txt, force=True)
        t.inst.source_line = old_src
        t.changed = True
        return True

    return core


fmov_0.global_parsing_cb = fmov_0_parsing_cb()


def fmov_1_parsing_cb():
    def core(inst, t, log=None):
        _ = log  # log is not used
        succ = None
        r = None
        # Check if this is the first in a pair of fmov's
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, fmov_0):
                if r.inst.args_in_out == inst.args_in_out:
                    succ = r
        if succ is None:
            return False

        # Reparse as instruction-variant treating the input/output as an output
        old_src = t.inst.source_line.copy()
        inst_txt = old_src.to_string(indentation=False)
        t.inst = fmov_1_force_output.make(inst_txt, force=True)
        t.inst.source_line = old_src
        t.changed = True
        return True

    return core


fmov_1.global_parsing_cb = fmov_1_parsing_cb()


def q_ld2_lane_post_inc_parsing_cb():
    def core(inst, t, log=None):
        _ = log  # log is not used

        succ = None

        # Check if this is the first in a pair of q_ld2_lane_post_inc+q_ld2_lane_post_inc
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, q_ld2_lane_post_inc):
                if r.inst.args_in_out[:2] == inst.args_in_out[:2] and {
                    r.inst.index,
                    inst.index,
                } == {0, 1}:
                    succ = r

        if succ is None:
            return False

        # Reparse as instruction-variant treating input/output as output

        old_src = t.inst.source_line.copy()
        inst_txt = old_src.to_string(indentation=False)
        t.inst = q_ld2_lane_post_inc_force_output.make(inst_txt, force=True)
        t.inst.source_line = old_src
        t.changed = True
        t.inst.extract_read_writes()
        return True

    return core


q_ld2_lane_post_inc.global_parsing_cb = q_ld2_lane_post_inc_parsing_cb()


def eor3_fusion_cb():
    """
    Example for a fusion call back. Allows to merge two eor instruction with
    two inputs into one eor with three inputs. Such technique can help perform
    transformations in case of differences between uArchs.

    .. note::

        This is not used in any real (crypto) example. This is merely a PoC.
    """

    def core(inst, t, log=None):
        succ = None

        # Check if this is the first in a fusable pair of eor3
        if len(t.dst_out[0]) == 1:
            r = t.dst_out[0][0]
            if isinstance(r.inst, veor) and r.src_in[0].src == t:
                if r.inst.args_in[0] == t.inst.args_out[0]:
                    succ = r

        if succ is None:
            return False

        d = r.inst.args_out[0]
        a = inst.args_in[0]
        b = inst.args_in[1]
        c = r.inst.args_in[1]

        # Check if the a,b inputs are overwritten between the
        # first and second eor.
        if r.reg_state[a] != t.reg_state[a] and not (
            r.reg_state[a].src == t and t.reg_state[a].idx == 0
        ):
            if log is not None:
                log(
                    f"NOTE: Skipping potential EOR3 fusion for ({t}:{r}) "
                    f"because {a} is modified by {r.reg_state[a]} in the interim."
                )
            return False
        if r.reg_state[b] != t.reg_state[b] and not (
            r.reg_state[b].src == t and t.reg_state[b].idx == 0
        ):
            if log is not None:
                log(
                    f"NOTE: Skipping potential EOR3 fusion for ({t}:{r}) "
                    f"because {b} is modified by {r.reg_state[b]} in the interim."
                )
            return False

        new_inst = AArch64Instruction.build(
            veor3,
            {
                "Vd": d,
                "Va": a,
                "Vb": b,
                "Vc": c,
                "datatype0": "16b",
                "datatype1": "16b",
                "datatype2": "16b",
                "datatype3": "16b",
            },
        )

        # TODO: Hoist this merging logic into a separate function
        src = r.inst.source_line.copy()
        src.add_tags(inst.source_line.tags)
        src.add_comments(inst.source_line.comments)
        new_inst.source_line = src

        if log is not None:
            log(f"EOR3 fusion: {t.inst}; {r.inst} ~> {new_inst}")

        # If so, delete first note, and reparse second as eor3
        t.delete = True
        r.changed = True
        r.inst = new_inst
        return True

    return core


def eor3_splitting_cb():
    """
    Example for a splitting call back. Allows to split one eor instruction with
    three inputs into two eors with two inputs. Such technique can help perform
    transformations in case of differences between uArchs.

    .. note::

        This is not used in any real (crypto) example. This is merely a PoC.
    """

    def core(inst, t, log=None):

        d = inst.args_out[0]
        a = inst.args_in[0]
        b = inst.args_in[1]
        c = inst.args_in[2]

        # Check if we can use the output as a temporary
        if d in [a, b, c]:
            return False

        eor0 = AArch64Instruction.build(
            veor,
            {
                "Vd": d,
                "Va": a,
                "Vb": b,
                "datatype0": "16b",
                "datatype1": "16b",
                "datatype2": "16b",
            },
        )
        eor1 = AArch64Instruction.build(
            veor,
            {
                "Vd": d,
                "Va": d,
                "Vb": c,
                "datatype0": "16b",
                "datatype1": "16b",
                "datatype2": "16b",
            },
        )

        eor0_src = (
            SourceLine(eor0.write())
            .add_tags(inst.source_line.tags)
            .add_comments(inst.source_line.comments)
        )
        eor1_src = (
            SourceLine(eor1.write())
            .add_tags(inst.source_line.tags)
            .add_comments(inst.source_line.comments)
        )

        eor0.source_line = eor0_src
        eor1.source_line = eor1_src

        if log is not None:
            log(f"EOR3 splitting: {t.inst}; {eor0} + {eor1}")

        t.changed = True
        t.inst = [eor0, eor1]
        return True

    return core


# Can alternatively set veor3.global_fusion_cb to eor3_fusion_cb() here
veor3.global_fusion_cb = eor3_splitting_cb()


def iter_aarch64_instructions():
    yield from all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_aarch64_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise UnknownInstruction(
        f"Couldn't find instruction class for {src} (type {type(src)})"
    )


def is_dt_form_of(instr_class, dts=None):
    if not isinstance(instr_class, list):
        instr_class = [instr_class]

    def _intersects(ls_a, ls_b):
        return len([a for a in ls_a if a in ls_b]) > 0

    def _check_instr_dt(src):
        if find_class(src) in instr_class:
            if dts is None or _intersects(src.datatype, dts):
                return True
        return False

    return _check_instr_dt


def is_dform_form_of(instr_class):
    return is_dt_form_of(instr_class, ["1d", "2s", "4h", "8b"])


def is_qform_form_of(instr_class):
    return is_dt_form_of(instr_class, ["2d", "4s", "8h", "16b"])


def check_instr_dt(src, instr_classes, dt=None):
    if not isinstance(instr_classes, list):
        instr_classes = list(instr_classes)
    for instr_class in instr_classes:
        if find_class(src) == instr_class:
            if dt is None or len(set(dt + src.datatype)) > 0:
                return True
    return False


def is_neon_instruction(inst):
    args = inst.arg_types_in + inst.arg_types_out + inst.arg_types_in_out
    return RegisterType.NEON in args


# Returns the list of all subclasses of a class which don't have
# subclasses themselves
def all_subclass_leaves(c):

    def has_subclasses(cl):
        return len(cl.__subclasses__()) > 0

    def is_leaf(c):
        return not has_subclasses(c)

    def all_subclass_leaves_core(leaf_lst, todo_lst):
        leaf_lst += filter(is_leaf, todo_lst)
        todo_lst = [
            csub
            for c in filter(has_subclasses, todo_lst)
            for csub in c.__subclasses__()
        ]
        if len(todo_lst) == 0:
            return leaf_lst
        return all_subclass_leaves_core(leaf_lst, todo_lst)

    return all_subclass_leaves_core([], [c])


Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)


def lookup_multidict(d, inst, default=None):
    instclass = find_class(inst)
    for ll, v in d.items():
        # Multidict entries can be the following:
        # - An instruction class. It matches any instruction of that class.
        # - A callable. It matches any instruction returning `True` when passed
        #   to the callable.
        # - A tuple of instruction classes or callables. It matches any instruction
        #   which matches at least one element in the tuple.
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            assert callable(x)
            return x(inst)

        if not isinstance(ll, tuple):
            ll = [ll]
        for lp in ll:
            if match(lp):
                return v
    if default is None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

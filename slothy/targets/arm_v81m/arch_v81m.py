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

#
# WARNING: This module is highly incomplete and does not constitute a complete
#          parser for the Armv8.1-M instruction set. So far, it merelly supports
#          a minimal amount of Helium instructions to run HeLight in some chosen
#          examples of interest.
#

import logging
import inspect
import re
import math

from sympy import simplify
from functools import cache
from enum import Enum

from slothy.helper import Loop

arch_name = "Arm_v81M"
llvm_mca_arch = "arm"

llvm_mc_arch = None
llvm_mc_attr = None
unicorn_arch = None
unicorn_mode = None


class RegisterType(Enum):
    GPR = (1,)
    MVE = (2,)
    StackMVE = (3,)
    StackGPR = (4,)

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    @staticmethod
    def is_renamed(ty):
        """Indicate if register type should be subject to renaming"""
        return True

    @staticmethod
    def list_registers(
        reg_type, only_extra=False, only_normal=False, with_variants=False
    ):
        """Return the list of all registers of a given type"""

        qstack_locations = [f"QSTACK{i}" for i in range(8)]
        stack_locations = [f"STACK{i}" for i in range(8)] + [
            "ROOT0_STACK",
            "ROOT1_STACK",
            "ROOT4_STACK",
            "RPTR_STACK",
        ]

        gprs_normal = [f"r{i}" for i in range(13)] + ["r14"]
        vregs_normal = [f"q{i}" for i in range(8)]

        gprs_extra = [f"r{i}_EXT" for i in range(16)]
        vregs_extra = [f"q{i}_EXT" for i in range(16)]

        gprs = []
        vregs = []
        if not only_extra:
            gprs += gprs_normal
            vregs += vregs_normal
        if not only_normal:
            gprs += gprs_extra
            vregs += vregs_extra

        return {
            RegisterType.GPR: gprs,
            RegisterType.StackGPR: stack_locations,
            RegisterType.StackMVE: qstack_locations,
            RegisterType.MVE: vregs,
        }[reg_type]

    @staticmethod
    def find_type(r):
        """Find type of architectural register"""
        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty
        return None

    def from_string(string):
        string = string.lower()
        return {
            "qstack": RegisterType.StackMVE,
            "stack": RegisterType.StackGPR,
            "mve": RegisterType.MVE,
            "gpr": RegisterType.GPR,
        }.get(string, None)

    def default_aliases():
        return {"lr": "r14"}

    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(["r14"])


class LeLoop(Loop):
    """
    Loop ending in a le instruction.

    Example:

    .. code-block::

       loop_lbl:
           {code}
           le <cnt>, loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl_start="1", lbl_end="2"):
        super().__init__(lbl_start=lbl_start, lbl_end=lbl_end)
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (rf"^\s*le\s+((?P<cnt>\w+)|r14)\s*,\s*{lbl_start}",)

    def start(
        self,
        reg,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        assert reg == "lr"
        indent = " " * indentation
        if unroll > 1:
            if unroll not in [1, 2, 4, 8, 16, 32]:
                raise Exception("unsupported unrolling")
            yield f"{indent}lsr lr, lr, #{int(math.log2(unroll))}"
        if fixup != 0:
            yield f"{indent}sub lr, lr, #{fixup}"
        yield ".p2align 2"
        yield f"{self.lbl_start}:"

    def end(self, unused, indentation=0):
        indent = " " * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"
        yield f"{indent}le lr, {lbl_start}"


class FatalParsingException(Exception):
    """A fatal error happened during instruction parsing"""


class InstructionNew:
    class ParsingException(Exception):
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
        mnemonic = re.sub("<dt>", "(?P<datatype>(?:|i|u|s)(?:8|16|32|64))", mnemonic)
        mnemonic = re.sub("<fdt>", "(?P<datatype>(?:f)(?:8|16|32))", mnemonic)
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self, inst):
                return True
        return False

    def is_load_store_instruction(self):
        return self._is_instance_of(
            [
                vldr,
                vstr,
                vld2,
                vld4,
                vst2,
                vst4,
                ldrd,
                strd,
                qsave,
                qrestore,
                save,
                restore,
                saved,
                restored,
            ]
        )

    def is_vector_load(self):
        return self._is_instance_of([vldr, vld2, vld4, qrestore])

    def is_scalar_load(self):
        return self._is_instance_of([ldrd, ldr, restore, restored])

    def is_load(self):
        return self.is_vector_load() or self.is_scalar_load()

    def is_vector_store(self):
        return self._is_instance_of([vstr, vst2, vst4, qsave])

    def is_stack_store(self):
        return self._is_instance_of([qsave, saved, save])

    def is_stack_load(self):
        return self._is_instance_of([qrestore, restored, restore])

    # def parse(self, src):
    #     """Assumes format 'mnemonic [in]out0, .., [in]outN, in0, .., inM"""
    #     src = re.sub("//.*$", "", src)

    #     have_dt = ("<dt>" in self.mnemonic) or ("<fdt>" in self.mnemonic)

    #     # Replace <dt> by list of all possible datatypes
    #     mnemonic = InstructionNew.unfold_abbrevs(self.mnemonic)

    #     expected_args = self.num_in + self.num_out + self.num_in_out
    #     regexp_txt = rf"^\s*{mnemonic}"
    #     if expected_args > 0:
    #         regexp_txt += r"\s+"
    #     regexp_txt += ",".join([r"\s*(\w+)\s*" for _ in range(expected_args)])
    #     regexp = re.compile(regexp_txt)

    #     p = regexp.match(src)
    #     if p is None:
    #         raise InstructionNew.ParsingException(
    #             f"Doesn't match basic instruction template {regexp_txt}"
    #         )

    #     operands = list(p.groups())
    #     if have_dt:
    #         operands = operands[1:]

    #     self.args_in = []
    #     self.args_out = []
    #     self.args_in_out = []

    #     self.datatype = ""
    #     if have_dt:
    #         self.datatype = p.group("datatype")

    #     idx_args_in = 0

    #     if self.num_out > 0:
    #         self.args_out = operands[: self.num_out]
    #         idx_args_in = self.num_out
    #     elif self.num_in_out > 0:
    #         self.args_in_out = operands[: self.num_in_out]
    #         idx_args_in = self.num_in_out

    #     self.args_in = operands[idx_args_in:]

    #     if not len(self.args_in) == self.num_in:
    #         raise Exception(
    #             f"Something wrong parsing {src}: Expect {self.num_in} \
    #                         input, but got {len(self.args_in)} ({self.args_in})"
    #         )

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

        :raises InstructionNew.ParsingException: The str argument cannot be parsed as an
                instance of c.
        :raises FatalParsingException: A fatal error during parsing happened
                that's likely a bug in the model.
        """

        if src.split(" ")[0] != mnemonic:
            raise InstructionNew.ParsingException("Mnemonic does not match")

        obj = c(mnemonic=mnemonic, **kwargs)

        # Replace <dt> by list of all possible datatypes
        mnemonic = InstructionNew.unfold_abbrevs(obj.mnemonic)

        expected_args = obj.num_in + obj.num_out + obj.num_in_out
        regexp_txt = rf"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += r"\s+"
        regexp_txt += ",".join([r"\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise InstructionNew.ParsingException(
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
        for inst_class in InstructionNew.all_subclass_leaves:
            try:
                inst = inst_class.make(src)
                instnames = [inst_class.__name__]
                insts = [inst]
                break
            except InstructionNew.ParsingException as e:
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
            raise InstructionNew.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support "
                "for a new instruction (variant)?"
            )

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()


class Instruction:
    class ParsingException(Exception):
        def __init__(self, err=None):
            super().__init__(err)

    def __init__(
        self, *, mnemonic, arg_types_in=None, arg_types_in_out=None, arg_types_out=None
    ):

        if not arg_types_in:
            arg_types_in = []
        if not arg_types_out:
            arg_types_out = []
        if not arg_types_in_out:
            arg_types_in_out = []

        arg_types_all = arg_types_in + arg_types_in_out + arg_types_out

        def isinstancelist(ll, c):
            return all(map(lambda e: isinstance(e, c), ll))

        assert isinstancelist(arg_types_all, RegisterType)

        self.mnemonic = mnemonic

        self.arg_types_in = arg_types_in
        self.arg_types_out = arg_types_out
        self.arg_types_in_out = arg_types_in_out
        self.num_in = len(arg_types_in)
        self.num_out = len(arg_types_out)
        self.num_in_out = len(arg_types_in_out)

        self.args_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_different = None
        self.args_in_inout_different = None

        self.args_out_restrictions = [None for _ in range(self.num_out)]
        self.args_in_restrictions = [None for _ in range(self.num_in)]
        self.args_in_out_restrictions = [None for _ in range(self.num_in_out)]

        self.args_out_combinations = None
        self.args_in_out_combinations = None
        self.args_in_combinations = None

        self.offset_adjustable = True

    def global_parsing_cb(self, a, log=None):
        return False

    def write(self):
        args = self.args_out + self.args_in_out + self.args_in
        mnemonic = re.sub("<dt>", self.datatype, self.mnemonic)
        return mnemonic + " " + ", ".join(args)

    def unfold_abbrevs(mnemonic):
        mnemonic = re.sub(
            "<dt>", "(?P<datatype>(?:|i|u|s|I|U|S)(?:8|16|32|64))", mnemonic
        )
        mnemonic = re.sub("<fdt>", "(?P<datatype>(?:f|F)(?:8|16|32))", mnemonic)
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self, inst):
                return True
        return False

    def is_load_store_instruction(self):
        return self._is_instance_of(
            [
                vldr,
                vstr,
                vld2,
                vld4,
                vst2,
                vst4,
                ldrd,
                strd,
                qsave,
                qrestore,
                save,
                restore,
                saved,
                restored,
            ]
        )

    def is_vector_load(self):
        return self._is_instance_of([vldr, vld2, vld4, qrestore])

    def is_scalar_load(self):
        return self._is_instance_of([ldrd, ldr, restore, restored])

    def is_load(self):
        return self.is_vector_load() or self.is_scalar_load()

    def is_vector_store(self):
        return self._is_instance_of([vstr, vst2, vst4, qsave])

    def is_stack_store(self):
        return self._is_instance_of([qsave, saved, save])

    def is_stack_load(self):
        return self._is_instance_of([qrestore, restored, restore])

    def parse(self, src):
        """Assumes format 'mnemonic [in]out0, .., [in]outN, in0, .., inM"""
        src = re.sub("//.*$", "", src)

        have_dt = ("<dt>" in self.mnemonic) or ("<fdt>" in self.mnemonic)

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
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
        if have_dt:
            operands = operands[1:]

        self.args_in = []
        self.args_out = []
        self.args_in_out = []

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype")

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[: self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[: self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:]

        if not len(self.args_in) == self.num_in:
            raise Exception(
                f"Something wrong parsing {src}: Expect {self.num_in} \
                            input, but got {len(self.args_in)} ({self.args_in})"
            )

    @staticmethod
    def parser(src_line):
        insts = []
        exceptions = {}
        instnames = []

        src = src_line.text.strip()

        # Iterate through all derived classes and call their parser
        # until one of them hopefully succeeds
        for inst_class in Instruction.__subclasses__():
            inst = inst_class()
            try:
                inst.parse(src)
                instnames.append(inst_class.__name__)
                insts.append(inst)
            except Instruction.ParsingException as e:
                exceptions[inst_class.__name__] = e
        if len(insts) == 0:
            logging.error("Failed to parse instruction %s", src)
            logging.error("A list of attempted parsers and their exceptions follows.")
            for i, e in exceptions.items():
                logging.error("* %s %s", f"{i + ':':20s}", e)
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support for a new "
                f"instruction (variant)?"
            )

        logging.debug("Parsing result for %s: %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()


class MVEInstruction(InstructionNew):
    """Abstract class representing MVE instructions"""

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

        src = re.sub(r"<([QR])(\w+)>", pattern_transform, src)

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

        dt_pattern = "(?:|u|s|f|i|U|S|F|I)(?:8|16|32|64)"
        imm_pattern = "#(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"

        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = replace_placeholders(src, "dt", dt_pattern, "datatype")
        src = replace_placeholders(src, "index", index_pattern, "index")

        src = r"\s*" + src + r"\s*(//.*)?\Z"
        return src

    @staticmethod
    def _build_parser(src):
        regexp_txt = MVEInstruction._unfold_pattern(src)
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
        """Build parser for given MVE instruction pattern"""
        if pattern in MVEInstruction.PARSERS:
            return MVEInstruction.PARSERS[pattern]
        parser = MVEInstruction._build_parser(pattern)
        MVEInstruction.PARSERS[pattern] = parser
        return parser

    @cache
    def __infer_register_type(ptrn):
        if ptrn[0].upper() in ["R"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["Q"]:
            return RegisterType.MVE
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
        arg_types_in = [MVEInstruction._infer_register_type(r) for r in inputs]
        arg_types_out = [MVEInstruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [MVEInstruction._infer_register_type(r) for r in in_outs]

        # TODO: add flags
        # if modifiesFlags:
        #     arg_types_out += [RegisterType.FLAGS]
        #     outputs += ["flags"]

        # if dependsOnFlags:
        #     arg_types_in += [RegisterType.FLAGS]
        #     inputs += ["flags"]

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
            c = "r"
        elif ty == RegisterType.MVE:
            c = "q"
        else:
            assert False
        if s.replace("_", "").isdigit():
            return f"{c}{s}"
        return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        if ty == RegisterType.GPR:
            if arg[0] != "r":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.MVE:
            if arg[0] != "q":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        # if ty == RegisterType.FLAGS:
        #   return out
        rep = MVEInstruction._build_pattern_replacement(s, ty, arg)
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

        for s, ty in obj.pattern_inputs:
            # if ty == RegisterType.FLAGS:
            #     obj.args_in.append("flags")
            # else:
            obj.args_in.append(MVEInstruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            # if ty == RegisterType.FLAGS:
            #     obj.args_out.append("flags")
            # else:
            obj.args_out.append(MVEInstruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(MVEInstruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c, "modifiesFlags", False)
        depends_on_flags = getattr(c, "dependsOnFlags", False)

        if isinstance(src, str):
            if src.split(".")[0] != pattern.split(".")[0]:
                raise InstructionNew.ParsingException("Mnemonic does not match")
            res = MVEInstruction.get_parser(pattern)(src)
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

        MVEInstruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return MVEInstruction.build(cls, src)

    def write(self):
        out = self.pattern
        ll = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )
        for arg, (s, ty) in ll:
            out = MVEInstruction._instantiate_pattern(s, ty, arg, out)

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
        out = replace_pattern(out, "index", "index", str)

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out


# Virtual instruction to model pushing to stack locations without modelling memory


class qsave(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="qsave",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.StackMVE],
        )
        self.addr = "sp"
        self.increment = None


class qrestore(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="qrestore",
            arg_types_in=[RegisterType.StackMVE],
            arg_types_out=[RegisterType.MVE],
        )
        self.addr = "sp"
        self.increment = None


class save(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="save",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.StackGPR],
        )
        self.addr = "sp"
        self.increment = None


class restore(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="restore",
            arg_types_in=[RegisterType.StackGPR],
            arg_types_out=[RegisterType.GPR],
        )
        self.addr = "sp"
        self.increment = None


class saved(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="saved",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR],
            arg_types_out=[RegisterType.StackGPR],
        )
        self.addr = "sp"
        self.increment = None


class restored(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="restored",
            arg_types_in=[RegisterType.StackGPR],
            arg_types_out=[RegisterType.GPR, RegisterType.GPR],
        )
        self.addr = "sp"
        self.increment = None


class add(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="add",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )


class sub(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="sub",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )


class vmulh(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmulh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vmul_T2(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmul.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )


class vmul_T1(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmul.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vmulf_T2(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmul.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )

    def write(self):
        return (
            f"vmul.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vmulf_T1(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmul.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def write(self):
        return (
            f"vmul.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vqrdmulh_T1(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqrdmulh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vqrdmulh_T2(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqrdmulh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )


class vqdmlah(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqdmlah.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_in_out=[RegisterType.MVE],
        )


class vqdmlsdh(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqdmlsdh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )
        self.detected_vqdmlsdh_vqdmladhx_pair = False


class vqdmladhx(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqdmladhx.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )
        self.detected_vqdmlsdh_vqdmladhx_pair = False


class vqrdmlah(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqrdmlah.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_in_out=[RegisterType.MVE],
        )


class vqdmulh_sv(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqdmulh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )


class vqdmulh_vv(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vqdmulh.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class ldrd(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="ldrd",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.GPR, RegisterType.GPR],
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):

        addr_regexp_txt = (
            r"\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        )
        postinc_regexp_txt = r"\s*(?:,\s*#(?P<postinc>.*))?"

        ldrd_regexp_txt = r"\s*ldrd\s+"
        ldrd_regexp_txt += r"(?P<dest0>\w+),\s*(?P<dest1>\w+),\s*"
        ldrd_regexp_txt += addr_regexp_txt
        ldrd_regexp_txt += postinc_regexp_txt
        ldrd_regexp_txt = Instruction.unfold_abbrevs(ldrd_regexp_txt)
        ldrd_regexp = re.compile(ldrd_regexp_txt)

        p = ldrd_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        dst0, dst1, addr = p.group("dest0"), p.group("dest1"), p.group("addr")
        self.writeback = p.group("writeback") == "!"
        self.pre_index = p.group("addroffset")
        self.post_index = p.group("postinc")

        self.addr = addr

        if self.writeback:
            self.increment = self.pre_index
        elif self.post_index:
            self.increment = self.post_index
        else:
            self.increment = None

        self._simplify()

        # NOTE: We currently don't model post-increment loads/stores as changing
        #       the address register, allowing the tool to freely rearrange
        #       loads/stores from the same base register.
        self.args_in = [addr]
        self.args_out = [dst0, dst1]
        self.args_in_out = []

    def write(self):

        self._simplify()

        inc = ""
        if self.writeback:
            inc = "!"
        if self.pre_index is not None:
            addr = f"[{self.args_in[0]}, #{self.pre_index}]"
        else:
            addr = f"[{self.args_in[0]}]"
        if self.post_index is not None:
            post = f", #{self.post_index}"
        else:
            post = ""
        return (
            f"{self.mnemonic} {self.args_out[0]}, {self.args_out[1]}, "
            f"{addr}{inc} {post}"
        )


class ldr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="ldr",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):

        addr_regexp_txt = (
            r"\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        )
        postinc_regexp_txt = r"\s*(?:,\s*#(?P<postinc>.*))?"

        ldr_regexp_txt = r"\s*ldr\s+"
        ldr_regexp_txt += r"(?P<dest>\w+),\s*"
        ldr_regexp_txt += addr_regexp_txt
        ldr_regexp_txt += postinc_regexp_txt
        ldr_regexp_txt = Instruction.unfold_abbrevs(ldr_regexp_txt)
        ldr_regexp = re.compile(ldr_regexp_txt)

        p = ldr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        dst, addr = p.group("dest"), p.group("addr")
        self.writeback = p.group("writeback") == "!"
        self.pre_index = p.group("addroffset")
        self.post_index = p.group("postinc")

        self.addr = addr

        if self.writeback:
            self.increment = self.pre_index
        elif self.post_index:
            self.increment = self.post_index
        else:
            self.increment = None

        self._simplify()

        # NOTE: We currently don't model post-increment loads/stores as changing
        #       the address register, allowing the tool to freely rearrange
        #       loads/stores from the same base register.
        self.args_in = [addr]
        self.args_out = [dst]
        self.args_in_out = []

    def write(self):

        self._simplify()

        inc = ""
        if self.writeback:
            inc = "!"
        if self.pre_index is not None:
            addr = f"[{self.args_in[0]}, #{self.pre_index}]"
        else:
            addr = f"[{self.args_in[0]}]"
        if self.post_index is not None:
            post = f", #{self.post_index}"
        else:
            post = ""
        return f"{self.mnemonic} {self.args_out[0]}, {addr}{inc} {post}"


class strd(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="strd",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR, RegisterType.GPR],
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):

        addr_regexp_txt = (
            r"\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        )
        postinc_regexp_txt = r"\s*(?:,\s*#(?P<postinc>.*))?"

        strd_regexp_txt = r"\s*strd\s+"
        strd_regexp_txt += r"(?P<dest0>\w+),\s*(?P<dest1>\w+),\s*"
        strd_regexp_txt += addr_regexp_txt
        strd_regexp_txt += postinc_regexp_txt
        strd_regexp_txt = Instruction.unfold_abbrevs(strd_regexp_txt)
        strd_regexp = re.compile(strd_regexp_txt)

        p = strd_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        dst0, dst1, addr = p.group("dest0"), p.group("dest1"), p.group("addr")
        self.writeback = p.group("writeback") == "!"
        self.pre_index = p.group("addroffset")
        self.post_index = p.group("postinc")

        self.addr = addr

        if self.writeback:
            self.increment = self.pre_index
        elif self.post_index:
            self.increment = self.post_index
        else:
            self.increment = None

        self._simplify()

        # NOTE: We currently don't model post-increment loads/stores as changing
        #       the address register, allowing the tool to freely rearrange
        #       loads/stores from the same base register.
        self.args_in = [addr, dst0, dst1]
        self.args_out = []
        self.args_in_out = []

    def write(self):

        self._simplify()

        inc = ""
        if self.writeback:
            inc = "!"
        if self.pre_index is not None:
            addr = f"[{self.args_in[0]}, #{self.pre_index}]"
        else:
            addr = f"[{self.args_in[0]}]"
        if self.post_index is not None:
            post = f", #{self.post_index}"
        else:
            post = ""
        return (
            f"{self.mnemonic} {self.args_in[1]}, {self.args_in[2]}, {addr}{inc} {post}"
        )


class vrshr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vrshr.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vrshr_regexp_txt = (
            r"vrshr\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*(?P<shift>#.*)"
        )
        vrshr_regexp_txt = Instruction.unfold_abbrevs(vrshr_regexp_txt)
        vrshr_regexp = re.compile(vrshr_regexp_txt)
        p = vrshr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []
        self.datatype = p.group("datatype")
        self.shift = p.group("shift")

    def write(self):
        return (
            f"vrshr.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, {self.shift}"
        )


class vrshl(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vrshl.<dt>",
            arg_types_in_out=[RegisterType.MVE],
            arg_types_in=[RegisterType.GPR],
        )

    def parse(self, src):
        vrshl_regexp_txt = r"vrshl\.<dt>\s+(?P<vec>\w+)\s*,\s*(?P<src>\w+)"
        vrshl_regexp_txt = Instruction.unfold_abbrevs(vrshl_regexp_txt)
        vrshl_regexp = re.compile(vrshl_regexp_txt)
        p = vrshl_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = []
        self.args_in_out = [p.group("vec")]
        self.args_in = [p.group("src")]
        self.datatype = p.group("datatype")

    def write(self):
        return f"vrshl.{self.datatype} {self.args_in_out[0]}, {self.args_in[0]}"


class vshlc(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vshlc", arg_types_in_out=[RegisterType.MVE, RegisterType.GPR]
        )

    def parse(self, src):
        vshlc_regexp_txt = (
            r"vshlc\s+(?P<vec>\w+)\s*,\s*(?P<gpr>\w+)\s*,\s*(?P<shift>#.*)"
        )
        vshlc_regexp_txt = Instruction.unfold_abbrevs(vshlc_regexp_txt)
        vshlc_regexp = re.compile(vshlc_regexp_txt)
        p = vshlc_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in_out = [p.group("vec"), p.group("gpr")]
        self.args_out = []
        self.args_in = []

        self.shift = p.group("shift")

    def write(self):
        return f"vshlc {self.args_in_out[0]}, {self.args_in_out[1]}, {self.shift}"


class vmov_imm(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmov.<dt>", arg_types_in=[], arg_types_out=[RegisterType.MVE]
        )

    def parse(self, src):
        vmov_regexp_txt = r"vmov\.<dt>\s+(?P<dst>\w+)\s*,\s*#(?P<immediate>\w*)"
        vmov_regexp_txt = Instruction.unfold_abbrevs(vmov_regexp_txt)
        vmov_regexp = re.compile(vmov_regexp_txt)
        p = vmov_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = [p.group("dst")]
        self.args_in = []
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.immediate = p.group("immediate")

    def write(self):
        return f"vmov.{self.datatype} {self.args_out[0]}, #{self.immediate}"


class vmullbt(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmull.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vmullbt_regexp_txt = (
            r"vmull(?P<bt>\w+)\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+),"
            r"\s*(?P<src1>\w*)"
        )
        vmullbt_regexp_txt = Instruction.unfold_abbrevs(vmullbt_regexp_txt)
        vmullbt_regexp = re.compile(vmullbt_regexp_txt)
        p = vmullbt_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = [p.group("dst")]
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.bt = p.group("bt")

    def write(self):
        return (
            f"vmull{self.bt}.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vdup(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vdup.<dt>",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vdup_regexp_txt = r"vdup\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<gpr0>\w*)"
        vdup_regexp_txt = Instruction.unfold_abbrevs(vdup_regexp_txt)
        vdup_regexp = re.compile(vdup_regexp_txt)
        p = vdup_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = [p.group("dst")]
        self.args_in = [p.group("gpr0")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        # self.immediate = p.group("immediate")

    def write(self):
        return f"vdup.{self.datatype} {self.args_out[0]}, {self.args_in[0]}"


class vmov_double_v2r(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmov",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.GPR, RegisterType.GPR],
        )

    def parse(self, src):
        vmov_regexp_txt = (
            r"vmov\s+(?P<gpr0>\w+)\s*,\s*(?P<gpr1>\w+)\s*,\s*(?P<vec0>\w+)\s*"
            r"\[\s*(?P<idx0>[23])\s*\]\s*,\s*(?P<vec1>\w+)\s*\[\s*(?P<idx1>[01])\s*\]\s*"
        )
        vmov_regexp_txt = Instruction.unfold_abbrevs(vmov_regexp_txt)
        vmov_regexp = re.compile(vmov_regexp_txt)
        p = vmov_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")

        idx0 = p.group("idx0")
        idx1 = p.group("idx1")
        if (idx1, idx0) not in [("0", "2"), ("1", "3")]:
            raise Instruction.ParsingException("Invalid lane indices")

        vec = p.group("vec0")
        vecp = p.group("vec1")
        if vec != vecp:
            raise Instruction.ParsingException("Input vectors must be equal")

        self.args_out = [p.group("gpr0"), p.group("gpr1")]
        self.args_in = [vec]
        self.args_in_out = []
        self.idxs = (idx0, idx1)

    def write(self):
        return (
            f"vmov {self.args_out[0]}, {self.args_out[1]}, "
            f"{self.args_in[0]}[{self.idxs[0]}], "
            f"{self.args_in[0]}[{self.idxs[1]}]"
        )


class mov_imm(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="mov", arg_types_in=[], arg_types_out=[RegisterType.GPR]
        )

    def parse(self, src):
        mov_regexp_txt = r"mov\s+(?P<dst>\w+)\s*,\s*#(?P<immediate>\w*)"
        mov_regexp = re.compile(mov_regexp_txt)
        p = mov_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = [p.group("dst")]
        self.args_in = []
        self.args_in_out = []
        self.immediate = p.group("immediate")

    def write(self):
        return f"mov {self.args_out[0]}, #{self.immediate}"


class mvn_imm(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="mvn", arg_types_in=[], arg_types_out=[RegisterType.GPR]
        )

    def parse(self, src):
        mvn_regexp_txt = r"mvn\s+(?P<dst>\w+)\s*,\s*#(?P<immediate>\w*)"
        mvn_regexp = re.compile(mvn_regexp_txt)
        p = mvn_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = [p.group("dst")]
        self.args_in = []
        self.args_in_out = []
        self.immediate = p.group("immediate")

    def write(self):
        return f"mvn {self.args_out[0]}, #{self.immediate}"


class pkhbt(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="pkhbt",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )

    def parse(self, src):
        pkhbt_regexp_txt = (
            r"pkhbt\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,\s*(?P<src1>\w+)\s*,"
            r"\s*lsl\s*#(?P<shift>.*)"
        )
        pkhbt_regexp_txt = Instruction.unfold_abbrevs(pkhbt_regexp_txt)
        pkhbt_regexp = re.compile(pkhbt_regexp_txt)
        p = pkhbt_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.shift = p.group("shift")

    def write(self):
        return (
            f"pkhbt {self.args_out[0]}, {self.args_in[0]}, {self.args_in[1]}, "
            f"lsl #{self.shift}"
        )


class mov(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="mov",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )


class add_imm(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="add",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )

    def parse(self, src):
        add_imm_regexp_txt = (
            r"add\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*#(?P<shift>.*)"
        )
        add_imm_regexp_txt = Instruction.unfold_abbrevs(add_imm_regexp_txt)
        add_imm_regexp = re.compile(add_imm_regexp_txt)
        p = add_imm_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.shift = p.group("shift")

    def write(self):
        return f"add {self.args_out[0]}, {self.args_in[0]}, #{self.shift}"


class sub_imm(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="sub",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.GPR],
        )

    def parse(self, src):
        sub_imm_regexp_txt = (
            r"sub\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*#(?P<shift>.*)"
        )
        sub_imm_regexp_txt = Instruction.unfold_abbrevs(sub_imm_regexp_txt)
        sub_imm_regexp = re.compile(sub_imm_regexp_txt)
        p = sub_imm_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.shift = p.group("shift")

    def write(self):
        return f"sub {self.args_out[0]}, {self.args_in[0]}, #{self.shift}"


class vshr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vshr.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vshr_regexp_txt = (
            r"vshr\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*(?P<shift>#.*)"
        )
        vshr_regexp_txt = Instruction.unfold_abbrevs(vshr_regexp_txt)
        vshr_regexp = re.compile(vshr_regexp_txt)
        p = vshr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.shift = p.group("shift")

    def write(self):
        return (
            f"vshr.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, {self.shift}"
        )


class vshrnbt(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vshrnbt.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vshrn_regexp_txt = (
            r"v(?P<round>r)?shrn(?P<bt>\w+)\.<dt>\s+(?P<vec>\w+)\s*,"
            r"\s*(?P<src>\w+)\s*,\s*(?P<shift>#.*)"
        )
        vshrn_regexp_txt = Instruction.unfold_abbrevs(vshrn_regexp_txt)
        vshrn_regexp = re.compile(vshrn_regexp_txt)
        p = vshrn_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = []
        self.args_in_out = [p.group("vec")]
        self.args_in = [p.group("src")]

        self.datatype = p.group("datatype")
        self.shift = p.group("shift")
        self.bt = p.group("bt")
        self.round = p.group("round") if p.group("round") else ""

    def write(self):
        return (
            f"v{self.round}shrn{self.bt}.{self.datatype} {self.args_in_out[0]}, "
            f"{self.args_in[0]}, {self.shift}"
        )


class vshllb(MVEInstruction):
    pattern = "vshllb.<dt> <Qd>, <Qa>, <imm>"
    inputs = ["Qa"]
    in_outs = ["Qd"]


class vshllt(MVEInstruction):
    pattern = "vshllt.<dt> <Qd>, <Qa>, <imm>"
    inputs = ["Qa"]
    in_outs = ["Qd"]


class vsli(MVEInstruction):
    pattern = "vsli.<dt> <Qd>, <Qa>, <imm>"
    inputs = ["Qa"]
    in_outs = ["Qd"]


class vmovlbt(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmovl.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vmovl_regexp_txt = (
            r"vmovl(?P<bt>\w+)\.<dt>\s+(?P<vec>\w+)\s*,\s*(?P<src>\w+)\s*"
        )
        vmovl_regexp_txt = Instruction.unfold_abbrevs(vmovl_regexp_txt)
        vmovl_regexp = re.compile(vmovl_regexp_txt)
        p = vmovl_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out = []
        self.args_in_out = [p.group("vec")]
        self.args_in = [p.group("src")]

        self.datatype = p.group("datatype")
        self.bt = p.group("bt")

    def write(self):
        return (
            f"vmovl{self.bt}.{self.datatype} {self.args_in_out[0]}, {self.args_in[0]}"
        )


class vrev(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vrev.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vrev_regexp_txt = (
            r"vrev(?P<dt0>\w+)\.(?P<dt1>\w+)\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)"
        )
        vrev_regexp_txt = Instruction.unfold_abbrevs(vrev_regexp_txt)
        vrev_regexp = re.compile(vrev_regexp_txt)
        p = vrev_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatypes = [p.group("dt0"), p.group("dt1")]

    def write(self):
        return (
            f"vrev{self.datatypes[0]}.{self.datatypes[1]} {self.args_out[0]}, "
            f"{self.args_in[0]}"
        )


class vshl(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vshl.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vshl_regexp_txt = (
            r"vshl\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*(?P<shift>#.*)"
        )
        vshl_regexp_txt = Instruction.unfold_abbrevs(vshl_regexp_txt)
        vshl_regexp = re.compile(vshl_regexp_txt)
        p = vshl_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.shift = p.group("shift")

    def write(self):
        return (
            f"vshl.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, {self.shift}"
        )


class vshl_T3(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vshl.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vshl_regexp_txt = (
            r"vshl\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,\s*(?P<src1>\w+)"
        )
        vshl_regexp_txt = Instruction.unfold_abbrevs(vshl_regexp_txt)
        vshl_regexp = re.compile(vshl_regexp_txt)
        p = vshl_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")

    def write(self):
        return (
            f"vshl.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vfma(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vfma.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vfma_regexp_txt = (
            r"vfma\.<fdt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,\s*(?P<src1>\w+)"
        )
        vfma_regexp_txt = Instruction.unfold_abbrevs(vfma_regexp_txt)
        vfma_regexp = re.compile(vfma_regexp_txt)
        p = vfma_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")

        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_in_out = [p.group("dst")]
        self.args_out = []
        self.datatype = p.group("datatype")

    def write(self):
        return (
            f"vfma.{self.datatype} {self.args_in_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vmla(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmla.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_in_out=[RegisterType.MVE],
        )


class vmlaldava(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vmlaldava.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_in_out=[RegisterType.GPR, RegisterType.GPR],
        )


class vaddva(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vaddva.<dt>",
            arg_types_in=[RegisterType.MVE],
            arg_types_in_out=[RegisterType.GPR],
        )


class vadd_vv(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vadd.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vadd_sv(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vadd.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )


class vhadd(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vhadd.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vsub(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vsub.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vhsub(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vhsub.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vand(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vand.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vbic(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vbic.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class vorr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vorr.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class veor(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="veor.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )


class nop(Instruction):
    def __init__(self):
        super().__init__(mnemonic="nop")


class vstr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vstrw.u32", arg_types_in=[RegisterType.MVE, RegisterType.GPR]
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$", "", src)

        addr_regexp_txt = (
            r"\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        )
        postinc_regexp_txt = r"\s*(?:,\s*#(?P<postinc>.*))?"

        vldr_regexp_txt = r"\s*vstr(?P<width>[bB]|[hH]|[wW])\.<dt>\s+"
        vldr_regexp_txt += r"(?P<dest>\w+),\s*"
        vldr_regexp_txt += addr_regexp_txt
        vldr_regexp_txt += postinc_regexp_txt
        vldr_regexp_txt = Instruction.unfold_abbrevs(vldr_regexp_txt)

        vldr_regexp = re.compile(vldr_regexp_txt)

        p = vldr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        vec = p.group("dest")
        self.addr = p.group("addr")
        self.writeback = p.group("writeback") == "!"
        self.datatype = p.group("datatype")
        self.width = p.group("width")

        self.pre_index = p.group("addroffset")
        self.post_index = p.group("postinc")

        if self.writeback:
            self.increment = self.pre_index
        elif self.post_index:
            self.increment = self.post_index
        else:
            self.increment = None

        self._simplify()

        # NOTE: We currently don't model post-increment loads/stores
        #       as changing the address register, allowing the tool to
        #       freely rearrange loads/stores from the same base register.
        #       We correct the indices afterwards.

        self.args_in = [vec, self.addr]
        self.args_out = []
        self.args_in_out = []

    def write(self):

        self._simplify()

        inc = ""
        if self.writeback:
            inc = "!"

        warn = False

        if self.pre_index is not None:
            warn = True
            addr = f"[{self.args_in[1]}, #{self.pre_index}]"
        else:
            addr = f"[{self.args_in[1]}]"

        if self.post_index is not None:
            warn = True
            post = f", #{self.post_index}"
        else:
            post = ""

        if warn:
            warning = ""
        else:
            warning = ""

        return f"{self.mnemonic} {self.args_in[0]}, {addr}{inc} {post}{warning}"


class vldr(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vldr",
            arg_types_in=[RegisterType.GPR],
            arg_types_out=[RegisterType.MVE],
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$", "", src)

        addr_regexp_txt = (
            r"\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        )
        postinc_regexp_txt = r"\s*(?:,\s*#(?P<postinc>.*))?"

        vldr_regexp_txt = r"\s*vldr(?P<width>[bB]|[hH]|[wW])\.<dt>\s+"
        vldr_regexp_txt += r"(?P<dest>\w+),\s*"
        vldr_regexp_txt += addr_regexp_txt
        vldr_regexp_txt += postinc_regexp_txt
        vldr_regexp_txt = Instruction.unfold_abbrevs(vldr_regexp_txt)

        vldr_regexp = re.compile(vldr_regexp_txt)

        p = vldr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        vec = p.group("dest")
        self.addr = p.group("addr")
        self.writeback = p.group("writeback") == "!"
        self.datatype = p.group("datatype")
        self.width = p.group("width")

        self.pre_index = p.group("addroffset")
        self.post_index = p.group("postinc")

        if self.writeback:
            self.increment = self.pre_index
        elif self.post_index:
            self.increment = self.post_index
        else:
            self.increment = None

        self._simplify()

        # NOTE: We currently don't model post-increment loads/stores
        #       as changing the address register, allowing the tool to
        #       freely rearrange loads/stores from the same base register.
        #       We correct the indices afterwards.

        self.args_in = [self.addr]
        self.args_out = [vec]
        self.args_in_out = []

    def write(self):

        self._simplify()

        inc = ""
        if self.writeback:
            inc = "!"

        warn = False
        if self.pre_index is not None:
            warn = True
            addr = f"[{self.args_in[0]}, #{self.pre_index}]"
        else:
            addr = f"[{self.args_in[0]}]"

        if self.post_index is not None:
            warn = True
            post = f", #{self.post_index}"
        else:
            post = ""

        if warn:
            warning = ""
        else:
            warning = ""

        return (
            f"vldr{self.width}.{self.datatype} {self.args_out[0]}, "
            f"{addr}{inc} {post}{warning}"
        )


class vldr_gather(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vldrw.<dt>",
            arg_types_in=[RegisterType.GPR, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def _simplify(self):
        if self.increment is not None:
            self.increment = simplify(self.increment)
        if self.post_index is not None:
            self.post_index = simplify(self.post_index)
        if self.pre_index is not None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$", "", src).strip()

        dest = r"(?P<dest>\w+),\s*"
        adrgpr = r"(?P<addr>\w+)"
        ofsvec = r",\s*(?P<addrvec>\w+)?"
        uxtw = r"(?:,\s*(?:uxtw|UXTW)\s+#(?P<uxtw>\w+))?"
        addr_regexp_txt = rf"\[\s*{adrgpr}\s*{ofsvec}\s*{uxtw}\]"

        vldr_regexp_txt = r"\s*vldr(?P<width>[bB]|[hH]|[wW])\.<dt>\s+"
        vldr_regexp_txt += dest
        vldr_regexp_txt += addr_regexp_txt
        vldr_regexp_txt += "$"
        vldr_regexp_txt = Instruction.unfold_abbrevs(vldr_regexp_txt)

        vldr_regexp = re.compile(vldr_regexp_txt)

        p = vldr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        vec = p.group("dest")
        self.addrgpr = p.group("addr")
        self.addrvec = p.group("addrvec")
        self.datatype = p.group("datatype")
        self.width = p.group("width")
        self.uxtw = p.group("uxtw")

        self.pre_index = None
        self.post_index = None
        self.increment = None

        # NOTE: We currently don't model post-increment loads/stores
        #       as changing the address register, allowing the tool to
        #       freely rearrange loads/stores from the same base register.
        #       We correct the indices afterwards.

        self.args_in = [self.addrgpr, self.addrvec]
        self.args_out = [vec]
        self.args_in_out = []

    def write(self):
        uxtw = ""
        if self.uxtw is not None:
            uxtw = f", UXTW #{self.uxtw}"
        addr = f"[{self.args_in[0]}, {self.args_in[1]}{uxtw}]"

        return f"vldr{self.width}.{self.datatype} {self.args_out[0]}, {addr}"


class vld2(Instruction):
    def __init__(self):
        pass

    def parse(self, src):

        regexp = (
            r"\s*(?P<variant>vld2(?P<idx>[0-1])\.<dt>)\s+"
            r"{\s*(?P<out0>\w+)\s*,"
            r"\s*(?P<out1>\w+)\s*}"
            r"\s*,\s*\[\s*(?P<reg>\w+)\s*\](?P<writeback>!?)\s*"
        )
        regexp = Instruction.unfold_abbrevs(regexp)

        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException("Didn't match regexp")

        arg_types_in = [RegisterType.GPR]
        idx = int(p.group("idx"))

        # NOTE: The output registers in all variants of VLD2 are input/output
        #       because they're only partially overwritten. However, as a whole,
        #       a block of VLD2{0-1} completely overwrites the output registers
        #       and should therefore be allowed to perform register renaming.
        #
        #       We model this by treading the output registers as pure outputs
        #       for VLD20, and as input/outputs for VLD21.
        #
        #       WARNING/TODO This only works for code using VLD2{0-1} in ascending order.
        if idx == 0:
            arg_types_out = [RegisterType.MVE, RegisterType.MVE]
            arg_types_in_out = []

        else:
            arg_types_out = []
            arg_types_in_out = [RegisterType.MVE, RegisterType.MVE]

        super().__init__(
            mnemonic="vld2",
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.idx = int(p.group("idx"))
        self.variant = p.group("variant")
        self.writeback = p.group("writeback") != ""
        self.addr = p.group("reg")
        self.args_in = [self.addr]

        self.pre_index = None
        self.post_index = None
        self.increment = None

        if self.writeback:
            self.post_index = "32"
            self.increment = "32"

        if self.idx == 0:
            self.args_out_combinations = [
                ([0, 1], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
            ]
            self.args_out_restrictions = [
                [f"q{i}" for i in range(0, 7)],
                [f"q{i}" for i in range(1, 8)],
            ]
            self.args_out = [p.group("out0"), p.group("out1")]
            self.args_in_out = []
        else:
            self.args_in_out = [p.group("out0"), p.group("out1")]
            self.args_out = []

    def write(self):
        inc = ""
        if self.writeback:
            inc = "!"

        addr = f"[{self.args_in[0]}]"

        if self.idx == 0:
            return f"{self.variant} {{{','.join(self.args_out)}}}, {addr}{inc}"
        else:
            return f"{self.variant} {{{','.join(self.args_in_out)}}}, {addr}{inc}"


class vld4(Instruction):
    def __init__(self):
        pass

    def parse(self, src):

        regexp = (
            r"\s*(?P<variant>vld4(?P<idx>[0-3])\.<dt>)\s+"
            r"{\s*(?P<out0>\w+)\s*,"
            r"\s*(?P<out1>\w+)\s*,"
            r"\s*(?P<out2>\w+)\s*,"
            r"\s*(?P<out3>\w+)\s*}"
            r"\s*,\s*\[\s*(?P<reg>\w+)\s*\](?P<writeback>!?)\s*"
        )
        regexp = Instruction.unfold_abbrevs(regexp)

        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException("Didn't match regexp")

        arg_types_in = [RegisterType.GPR]
        idx = int(p.group("idx"))

        # NOTE: The output registers in all variants of VLD4 are input/output
        #       because they're only partially overwritten. However, as a whole,
        #       a block of VLD4{0-3} completely overwrites the output registers
        #       and should therefore be allowed to perform register renaming.
        #
        #       We model this by treading the output registers as pure outputs
        #       for VLD40, and as input/outputs for VLD4{1,2,3}.
        #
        #       WARNING/TODO This only works for code using VLD4{0-3} in ascending order.
        if idx == 0:
            arg_types_out = [
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
            ]
            arg_types_in_out = []

        else:
            arg_types_out = []
            arg_types_in_out = [
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
            ]

        super().__init__(
            mnemonic="vld4",
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.idx = int(p.group("idx"))
        self.variant = p.group("variant")
        self.writeback = p.group("writeback") != ""
        self.addr = p.group("reg")
        self.args_in = [self.addr]

        self.pre_index = None
        self.post_index = None
        self.increment = None

        if self.writeback:
            self.post_index = "64"
            self.increment = "64"

        if self.idx == 0:
            self.args_out_combinations = [
                (
                    [0, 1, 2, 3],
                    [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
                )
            ]
            self.args_out_restrictions = [
                [f"q{i}" for i in range(0, 5)],
                [f"q{i}" for i in range(1, 6)],
                [f"q{i}" for i in range(2, 7)],
                [f"q{i}" for i in range(3, 8)],
            ]
            self.args_out = [
                p.group("out0"),
                p.group("out1"),
                p.group("out2"),
                p.group("out3"),
            ]
            self.args_in_out = []
        else:
            self.args_in_out = [
                p.group("out0"),
                p.group("out1"),
                p.group("out2"),
                p.group("out3"),
            ]
            self.args_out = []

    def write(self):
        inc = ""
        if self.writeback:
            inc = "!"

        addr = f"[{self.args_in[0]}]"

        if self.idx == 0:
            return f"{self.variant} {{{','.join(self.args_out)}}}, {addr}{inc}"
        else:
            return f"{self.variant} {{{','.join(self.args_in_out)}}}, {addr}{inc}"


class vst2(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vst2",
            arg_types_in=[RegisterType.GPR, RegisterType.MVE, RegisterType.MVE],
        )

    def parse(self, src):

        regexp = (
            r"\s*(?P<variant>vst2(?P<idx>[0-1])\.<dt>)\s+"
            r"{\s*(?P<out0>\w+)\s*,"
            r"\s*(?P<out1>\w+)\s*}"
            r"\s*,\s*\[\s*(?P<reg>\w+)\s*\](?P<writeback>!?)\s*"
        )
        regexp = Instruction.unfold_abbrevs(regexp)

        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException("Didn't match regexp")
        idx = int(p.group("idx"))

        if idx == 1:
            arg_types_in = [RegisterType.GPR, RegisterType.MVE, RegisterType.MVE]
            arg_types_in_out = []
            arg_types_out = []
        else:
            # NOTE: We model VST20 as modifying the input vectors solely to enforce
            #       the ordering VST2{0,1} -- they of course don't actually modify
            #       the contents
            arg_types_in = [RegisterType.GPR]
            arg_types_out = []
            arg_types_in_out = [RegisterType.MVE, RegisterType.MVE]

        super().__init__(
            mnemonic="vst2",
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.idx = idx
        self.pre_index = None
        self.post_index = None
        self.increment = None

        self.addr = p.group("reg")
        if self.idx == 1:
            self.args_in = [self.addr, p.group("out0"), p.group("out1")]
            self.args_in_out = []
            self.args_out = []
            self.args_in_combinations = [
                ([1, 2], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
            ]
        else:
            self.args_in = [self.addr]
            self.args_in_out = [p.group("out0"), p.group("out1")]
            self.args_out = []

        self.variant = p.group("variant")
        self.writeback = p.group("writeback") != ""

        if self.writeback:
            self.post_index = "32"
            self.increment = "32"

    def write(self):
        inc = ""
        if self.writeback:
            inc = "!"

        addr = f"[{self.args_in[0]}]"

        if self.idx == 1:
            return f"{self.variant} {{{','.join(self.args_in[1:])}}}, {addr}{inc}"
        else:
            return f"{self.variant} {{{','.join(self.args_in_out)}}}, {addr}{inc}"


class vst4(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vst4",
            arg_types_in=[
                RegisterType.GPR,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
            ],
        )

    def parse(self, src):

        regexp = (
            r"\s*(?P<variant>vst4(?P<idx>[0-3])\.<dt>)\s+"
            r"{\s*(?P<out0>\w+)\s*,"
            r"\s*(?P<out1>\w+)\s*,"
            r"\s*(?P<out2>\w+)\s*,"
            r"\s*(?P<out3>\w+)\s*}"
            r"\s*,\s*\[\s*(?P<reg>\w+)\s*\](?P<writeback>!?)\s*"
        )
        regexp = Instruction.unfold_abbrevs(regexp)

        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException("Didn't match regexp")
        idx = int(p.group("idx"))

        if idx == 3:
            arg_types_in = [
                RegisterType.GPR,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
            ]
            arg_types_in_out = []
            arg_types_out = []
        else:
            # NOTE: We model VST4{0,1,2} as modifying the input vectors solely to enforce
            #       the ordering VST4{0,1,2,3} -- they of course don't actually modify
            #       the contents
            arg_types_in = [RegisterType.GPR]
            arg_types_out = []
            arg_types_in_out = [
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
                RegisterType.MVE,
            ]

        super().__init__(
            mnemonic="vst4",
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.idx = idx
        self.pre_index = None
        self.post_index = None
        self.increment = None

        self.addr = p.group("reg")
        if self.idx == 3:
            self.args_in = [
                self.addr,
                p.group("out0"),
                p.group("out1"),
                p.group("out2"),
                p.group("out3"),
            ]
            self.args_in_out = []
            self.args_out = []
            self.args_in_combinations = [
                (
                    [1, 2, 3, 4],
                    [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
                )
            ]
        else:
            self.args_in = [self.addr]
            self.args_in_out = [
                p.group("out0"),
                p.group("out1"),
                p.group("out2"),
                p.group("out3"),
            ]
            self.args_out = []

        self.variant = p.group("variant")
        self.writeback = p.group("writeback") != ""

        if self.writeback:
            self.post_index = "64"
            self.increment = "64"

    def write(self):
        inc = ""
        if self.writeback:
            inc = "!"

        addr = f"[{self.args_in[0]}]"

        if self.idx == 3:
            return f"{self.variant} {{{','.join(self.args_in[1:])}}}, {addr}{inc}"
        else:
            return f"{self.variant} {{{','.join(self.args_in_out)}}}, {addr}{inc}"


class vsubf(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vsub.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def write(self):
        return (
            f"vsub.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vaddf(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vadd.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def write(self):
        return (
            f"vadd.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}"
        )


class vcmla(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vcmla.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_in_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vcmla_regexp_txt = (
            r"vcmla\.<fdt>\s+(?P<dst>\w+)\s*,"
            r"\s*(?P<src0>\w+)\s*,\s*(?P<src1>\w+)\s*,\s*(?P<rotation>#.*)"
        )
        vcmla_regexp_txt = Instruction.unfold_abbrevs(vcmla_regexp_txt)
        vcmla_regexp = re.compile(vcmla_regexp_txt)
        p = vcmla_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_in_out = [p.group("dst")]
        self.args_out = []

        self.datatype = p.group("datatype")
        self.rotation = p.group("rotation")

        if self.datatype == "f32":
            self.args_in_inout_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

    def write(self):
        return (
            f"vcmla.{self.datatype} {self.args_in_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}, {self.rotation}"
        )


class vcmul(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vcmul.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vcmul_regexp_txt = (
            r"vcmul\.<fdt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,"
            r"\s*(?P<src1>\w+)\s*,\s*(?P<rotation>#.*)"
        )
        vcmul_regexp_txt = Instruction.unfold_abbrevs(vcmul_regexp_txt)
        vcmul_regexp = re.compile(vcmul_regexp_txt)
        p = vcmul_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.rotation = p.group("rotation")

        if self.datatype == "f32":
            # First index: output, Second index: Input
            self.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

    def write(self):
        return (
            f"vcmul.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}, {self.rotation}"
        )


class vcadd(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vcadd.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vcadd_regexp_txt = (
            r"vcadd\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,\s*(?P<src1>\w+)\s*,"
            r"\s*(?P<rotation>#.*)"
        )
        vcadd_regexp_txt = Instruction.unfold_abbrevs(vcadd_regexp_txt)
        vcadd_regexp = re.compile(vcadd_regexp_txt)
        p = vcadd_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.rotation = p.group("rotation")

        if "32" in self.datatype:
            # First index: output, Second index: Input
            self.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

    def write(self):
        return (
            f"vcadd.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}, {self.rotation}"
        )


class vhcadd(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vhcadd.<dt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vhcadd_regexp_txt = (
            r"vhcadd\.<dt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,"
            r"\s*(?P<src1>\w+)\s*,\s*(?P<rotation>#.*)"
        )
        vhcadd_regexp_txt = Instruction.unfold_abbrevs(vhcadd_regexp_txt)
        vhcadd_regexp = re.compile(vhcadd_regexp_txt)
        p = vhcadd_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.rotation = p.group("rotation")

        if "32" in self.datatype:
            # First index: output, Second index: Input
            self.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

    def write(self):
        return (
            f"vhcadd.{self.datatype} {self.args_out[0]}, {self.args_in[0]}, "
            f"{self.args_in[1]}, {self.rotation}"
        )


class vcaddf(Instruction):
    def __init__(self):
        super().__init__(
            mnemonic="vcaddf.<fdt>",
            arg_types_in=[RegisterType.MVE, RegisterType.MVE],
            arg_types_out=[RegisterType.MVE],
        )

    def parse(self, src):
        vcaddf_regexp_txt = (
            r"vcadd\.<fdt>\s+(?P<dst>\w+)\s*,\s*(?P<src0>\w+)\s*,"
            r"\s*(?P<src1>\w+)\s*,\s*(?P<rotation>#.*)"
        )
        vcaddf_regexp_txt = Instruction.unfold_abbrevs(vcaddf_regexp_txt)
        vcaddf_regexp = re.compile(vcaddf_regexp_txt)
        p = vcaddf_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in = [p.group("src0"), p.group("src1")]
        self.args_out = [p.group("dst")]
        self.args_in_out = []

        self.datatype = p.group("datatype")
        self.rotation = p.group("rotation")

        if self.datatype == "f32":
            # First index: output, Second index: Input
            self.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

    def write(self):
        return (
            f"vcadd.{self.datatype} {self.args_out[0]}, "
            f"{self.args_in[0]}, {self.args_in[1]}, {self.rotation}"
        )


# ###########################################################
#
#  Postprocessing callbacks
#
#  TODO: Move those into the instruction class definitions
#
# ###########################################################


# Called after a code snippet has been parsed which contains instances
# of the instruction. We used this to detect the common pattern
#
# > vqdmlsdh  out, a, b
# > vqdmladhx out, a, b
#
# And change out to an output argument in this case (rather than input/output)
def vqdmlsdh_vqdmladhx_parsing_cb(this_class, other_class):
    def core(inst, t, log=None):
        assert isinstance(inst, this_class)
        succ = None

        if inst.detected_vqdmlsdh_vqdmladhx_pair:
            return False

        # Check if this is the first in a pair of vqdmlsdh/vqdmladhx
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, other_class):
                if (
                    r.inst.args_in_out == inst.args_in_out
                    and r.inst.args_in == inst.args_in
                ):
                    succ = r

        if succ is None:
            return False

        # If so, mark in/out as output only, and signal the need for re-building
        # the dataflow graph

        inst.num_out = 1
        inst.args_out = [inst.args_in_out[0]]
        inst.arg_types_out = [RegisterType.MVE]
        inst.args_out_restrictions = inst.args_in_out_restrictions

        inst.num_in_out = 0
        inst.args_in_out = []
        inst.arg_types_in_out = []
        inst.args_in_out_restrictions = []

        inst.detected_vqdmlsdh_vqdmladhx_pair = True
        return True

    return core


vqdmlsdh.global_parsing_cb = vqdmlsdh_vqdmladhx_parsing_cb(vqdmlsdh, vqdmladhx)
vqdmladhx.global_parsing_cb = vqdmlsdh_vqdmladhx_parsing_cb(vqdmladhx, vqdmlsdh)


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


InstructionNew.all_subclass_leaves = all_subclass_leaves(InstructionNew)


def lookup_multidict(d, inst, default=None):
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
        raise Exception(f"Couldn't find {inst}")
    return default


def find_class(src):
    for inst_class in Instruction.__subclasses__():
        if isinstance(src, inst_class):
            return inst_class

    raise Exception("Couldn't find instruction class")

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

from functools import cache
from enum import Enum
from sympy import simplify

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

        gprs_normal = [f"r{i}" for i in range(15)]
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
        return {"lr": "r14", "sp": "r13"}

    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(["r13", "r14"])


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


class Instruction:
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
                vldrb,
                vldrb_no_imm,
                vldrb_with_writeback,
                vldrb_with_post,
                vldrh,
                vldrh_no_imm,
                vldrh_with_writeback,
                vldrh_with_post,
                vldrw,
                vldrw_no_imm,
                vldrw_with_writeback,
                vldrw_with_post,
                vstrw,
                vstrw_no_imm,
                vstrw_with_writeback,
                vstrw_with_post,
                vstrw_scatter,
                vstrw_scatter_uxtw,
                vld20,
                vld21,
                vld20_with_writeback,
                vld21_with_writeback,
                vld40,
                vld41,
                vld42,
                vld43,
                vld40_with_writeback,
                vld41_with_writeback,
                vld42_with_writeback,
                vld43_with_writeback,
                vst20,
                vst21,
                vst20_with_writeback,
                vst21_with_writeback,
                vst40,
                vst41,
                vst42,
                vst43,
                vst40_with_writeback,
                vst41_with_writeback,
                vst42_with_writeback,
                vst43_with_writeback,
                ldrd,
                ldrd_no_imm,
                ldrd_with_writeback,
                ldrd_with_post,
                strd,
                strd_with_writeback,
                strd_with_post,
                qsave,
                qrestore,
                save,
                restore,
                saved,
                restored,
            ]
        )

    def is_vector_load(self):
        return self._is_instance_of(
            [
                vldrb,
                vldrb_no_imm,
                vldrb_with_writeback,
                vldrb_with_post,
                vldrh,
                vldrh_no_imm,
                vldrh_with_writeback,
                vldrh_with_post,
                vldrw,
                vldrw_no_imm,
                vldrw_with_writeback,
                vldrw_with_post,
                vld20,
                vld21,
                vld20_with_writeback,
                vld21_with_writeback,
                vld40,
                vld41,
                vld42,
                vld43,
                vld40_with_writeback,
                vld41_with_writeback,
                vld42_with_writeback,
                vld43_with_writeback,
                qrestore,
            ]
        )

    def is_scalar_load(self):
        return self._is_instance_of(
            [
                ldrd,
                ldrd_no_imm,
                ldrd_with_writeback,
                ldrd_with_post,
                ldr,
                ldr_with_writeback,
                ldr_with_post,
                restore,
                restored,
            ]
        )

    def is_load(self):
        return self.is_vector_load() or self.is_scalar_load()

    def is_vector_store(self):
        return self._is_instance_of(
            [
                vstrw,
                vstrw_no_imm,
                vstrw_with_writeback,
                vstrw_with_post,
                vstrw_scatter,
                vstrw_scatter_uxtw,
                vst20,
                vst21,
                vst20_with_writeback,
                vst21_with_writeback,
                vst40,
                vst41,
                vst42,
                vst43,
                vst40_with_writeback,
                vst41_with_writeback,
                vst42_with_writeback,
                vst43_with_writeback,
                qsave,
            ]
        )

    def is_stack_store(self):
        return self._is_instance_of([qsave, saved, save])

    def is_stack_load(self):
        return self._is_instance_of([qrestore, restored, restore])

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


class MVEInstruction(Instruction):
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

        dt_pattern = "(?:|u|s|i|U|S|I)(?:8|16|32|64)"
        fdt_pattern = "(?:|f|F)(?:16|32)"
        imm_pattern = "#(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"
        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = replace_placeholders(src, "dt", dt_pattern, "datatype")
        src = replace_placeholders(src, "fdt", fdt_pattern, "datatype")
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
            if (
                src.split(".")[0] != pattern.split(".")[0]
                and src.split(" ")[0] != pattern.split(" ")[0]
            ):
                raise Instruction.ParsingException("Mnemonic does not match")
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
        out = replace_pattern(out, "datatype", "fdt", lambda x: x.upper())
        out = replace_pattern(out, "index", "index", str)

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out


# Virtual instruction to model pushing to stack locations without modelling memory


class qsave(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="qsave",
            arg_types_in=[RegisterType.MVE],
            arg_types_out=[RegisterType.StackMVE],
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
            arg_types_in=[RegisterType.StackMVE],
            arg_types_out=[RegisterType.MVE],
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
            arg_types_out=[RegisterType.StackGPR],
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
            arg_types_in=[RegisterType.StackGPR],
            arg_types_out=[RegisterType.GPR],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class saved(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="saved",
            arg_types_in=[RegisterType.GPR, RegisterType.GPR],
            arg_types_out=[RegisterType.StackGPR],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class restored(Instruction):

    @classmethod
    def make(cls, src):
        obj = Instruction.build(
            cls,
            src,
            mnemonic="restored",
            arg_types_in=[RegisterType.StackGPR],
            arg_types_out=[RegisterType.GPR, RegisterType.GPR],
        )
        obj.addr = "sp"
        obj.increment = None
        return obj


class add(MVEInstruction):
    pattern = "add <Rd>, <Rn>, <Rm>"
    inputs = ["Rn", "Rm"]
    outputs = ["Rd"]


class sub(MVEInstruction):
    pattern = "sub <Rd>, <Rn>, <Rm>"
    inputs = ["Rn", "Rm"]
    outputs = ["Rd"]


class vmulh(MVEInstruction):
    pattern = "vmulh.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vmul_T2(MVEInstruction):
    pattern = "vmul.<dt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vmul_T1(MVEInstruction):
    pattern = "vmul.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vmulf_T2(MVEInstruction):
    pattern = "vmul.<fdt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vmulf_T1(MVEInstruction):
    pattern = "vmul.<fdt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vqrdmulh_T1(MVEInstruction):
    pattern = "vqrdmulh.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vqrdmulh_T2(MVEInstruction):
    pattern = "vqrdmulh.<dt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vqdmlah(MVEInstruction):
    pattern = "vqdmlah.<dt> <Qda>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    in_outs = ["Qda"]


class vqdmlsdh(MVEInstruction):
    pattern = "vqdmlsdh.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    in_outs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.detected_vqdmlsdh_vqdmladhx_pair = False
        return obj


class vqdmladhx(MVEInstruction):
    pattern = "vqdmladhx.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    in_outs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.detected_vqdmlsdh_vqdmladhx_pair = False
        return obj


class vqrdmlah(MVEInstruction):
    pattern = "vqrdmlah.<dt> <Qda>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    in_outs = ["Qda"]


class vqdmulh_sv(MVEInstruction):
    pattern = "vqdmulh.<dt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vqdmulh_vv(MVEInstruction):
    pattern = "vqdmulh.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class ldrd(MVEInstruction):
    pattern = "ldrd <Rt0>, <Rt1>, [<Rn>, <imm>]"
    inputs = ["Rn"]
    outputs = ["Rt0", "Rt1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldrd_no_imm(MVEInstruction):
    pattern = "ldrd <Rt0>, <Rt1>, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Rt0", "Rt1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = 0
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)

        if int(self.immediate) != 0:
            self.pattern = ldrd.pattern
        return super().write()


class ldrd_with_writeback(MVEInstruction):
    pattern = "ldrd <Rt0>, <Rt1>, [<Rn>, <imm>]!"
    inputs = ["Rn"]
    outputs = ["Rt0", "Rt1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class ldrd_with_post(MVEInstruction):
    pattern = "ldrd <Rt0>, <Rt1>, [<Rn>], <imm>"
    inputs = ["Rn"]
    outputs = ["Rt0", "Rt1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class ldr(MVEInstruction):
    pattern = "ldr <Rt>, [<Rn>, <imm>]"
    inputs = ["Rn"]
    outputs = ["Rt"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldr_with_writeback(MVEInstruction):
    pattern = "ldr <Rt>, [<Rn>, <imm>]!"
    inputs = ["Rn"]
    outputs = ["Rt"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class ldr_with_post(MVEInstruction):
    pattern = "ldr <Rt>, [<Rn>], <imm>"
    inputs = ["Rn"]
    outputs = ["Rt"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class strd(MVEInstruction):
    pattern = "strd <Rt0>, <Rt1>, [<Rn>, <imm>]"
    inputs = ["Rt0", "Rt1", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[2]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class strd_with_writeback(MVEInstruction):
    pattern = "strd <Rt0>, <Rt1>, [<Rn>, <imm>]!"
    inputs = ["Rt0", "Rt1", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[2]
        return obj


class strd_with_post(MVEInstruction):
    pattern = "strd <Rt0>, <Rt1>, [<Rn>], <imm>"
    inputs = ["Rt0", "Rt1", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[2]
        return obj


class vrshr(MVEInstruction):
    pattern = "vrshr.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vrshl(MVEInstruction):
    pattern = "vrshl.<dt> <Qda>, <Rm>"
    inputs = ["Rm"]
    in_outs = ["Qda"]


class vshlc(MVEInstruction):
    pattern = "vshlc <Qda>, <Rdm>, <imm>"
    in_outs = ["Qda", "Rdm"]


class vmov_imm(MVEInstruction):
    pattern = "vmov.<dt> <Qd>, <imm>"
    inputs = []
    outputs = ["Qd"]


class vmullb(MVEInstruction):
    pattern = "vmullb.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vmullt(MVEInstruction):
    pattern = "vmullt.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vdup(MVEInstruction):
    pattern = "vdup.<dt> <Qd>, <Rt>"
    inputs = ["Rt"]
    outputs = ["Qd"]


class vmov_double_v2r(MVEInstruction):
    pattern = "vmov <Rt0>, <Rt1>, <Qd>[<index0>], <Qa>[<index1>]"
    inputs = ["Qd", "Qa"]
    outputs = ["Rt0", "Rt1"]


class mov(MVEInstruction):
    pattern = "mov <Rd>, <Rm>"
    inputs = ["Rm"]
    outputs = ["Rd"]


class mov_imm(MVEInstruction):
    pattern = "mov <Rd>, <imm>"
    inputs = []
    outputs = ["Rd"]


class mvn_imm(MVEInstruction):
    pattern = "mvn <Rd>, <imm>"
    inputs = []
    outputs = ["Rd"]


class pkhbt(MVEInstruction):
    pattern = "pkhbt <Rd>, <Rn>, <Rm>, lsl <imm>"
    inputs = ["Rn", "Rm"]
    outputs = ["Rd"]


class add_imm(MVEInstruction):
    pattern = "add <Rd>, <Rn>, <imm>"
    inputs = ["Rn"]
    outputs = ["Rd"]


class sub_imm(MVEInstruction):
    pattern = "sub <Rd>, <Rn>, <imm>"
    inputs = ["Rn"]
    outputs = ["Rd"]


class vshr(MVEInstruction):
    pattern = "vshr.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vshrnb(MVEInstruction):
    pattern = "vshrnb.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vshrnt(MVEInstruction):
    pattern = "vshrnt.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vshllb(MVEInstruction):
    pattern = "vshllb.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vshllt(MVEInstruction):
    pattern = "vshllt.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vsli(MVEInstruction):
    pattern = "vsli.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vmovlb(MVEInstruction):
    pattern = "vmovlb.<dt> <Qd>, <Qm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vmovlt(MVEInstruction):
    pattern = "vmovlt.<dt> <Qd>, <Qm>"
    inputs = ["Qm"]
    in_outs = ["Qd"]


class vrev16(MVEInstruction):
    pattern = "vrev16.<dt> <Qd>, <Qm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vrev32(MVEInstruction):
    pattern = "vrev32.<dt> <Qd>, <Qm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vrev64(MVEInstruction):
    pattern = "vrev64.<dt> <Qd>, <Qm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vshl(MVEInstruction):
    pattern = "vshl.<dt> <Qd>, <Qm>, <imm>"
    inputs = ["Qm"]
    outputs = ["Qd"]


class vshl_T3(MVEInstruction):
    pattern = "vshl.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vfma(MVEInstruction):
    pattern = "vfma.<fdt> <Qda>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    in_outs = ["Qda"]


class vmla(MVEInstruction):
    pattern = "vmla.<dt> <Qda>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    in_outs = ["Qda"]


class vmlaldava(MVEInstruction):
    pattern = "vmlaldava.<dt> <Rd>, <Ra>, <Qa>, <Qd>"
    inputs = ["Qd", "Qa"]
    in_outs = ["Rd", "Ra"]


class vaddva(MVEInstruction):
    pattern = "vaddva.<dt> <Rda>, <Qm>"
    inputs = ["Qm"]
    in_outs = ["Rda"]


class vadd_vv(MVEInstruction):
    pattern = "vadd.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vadd_sv(MVEInstruction):
    pattern = "vadd.<dt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vhadd(MVEInstruction):
    pattern = "vhadd.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vsub(MVEInstruction):
    pattern = "vsub.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vsub_T2(MVEInstruction):
    pattern = "vsub.<dt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vhsub(MVEInstruction):
    pattern = "vhsub.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vand(MVEInstruction):
    pattern = "vand.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vbic(MVEInstruction):
    pattern = "vbic.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vbic_nodt(MVEInstruction):
    pattern = "vbic <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vorr(MVEInstruction):
    pattern = "vorr.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class veor(MVEInstruction):
    pattern = "veor.<dt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class veor_nodt(MVEInstruction):
    pattern = "veor <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class nop(MVEInstruction):
    pattern = "nop"


class vstrw(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>, <imm>]"
    inputs = ["Qd", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class vstrw_no_imm(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>]"
    inputs = ["Qd", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.addr = obj.args_in[1]
        obj.pre_index = 0
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        if int(self.immediate) != 0:
            self.pattern = vstrw.pattern
        return super().write()


class vstrw_with_writeback(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>, <imm>]!"
    inputs = ["Qd", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vstrw_with_post(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>], <imm>"
    inputs = ["Qd", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.addr = obj.args_in[1]
        obj.pre_index = None
        return obj


class vstrw_scatter(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>, <Qm>]"
    inputs = ["Qd", "Qm", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vstrw_scatter_uxtw(MVEInstruction):
    pattern = "vstrw.<dt> <Qd>, [<Rn>, <Qm>, UXTW <imm>]"
    inputs = ["Qd", "Qm", "Rn"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrb(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>, <imm>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class vldrb_no_imm(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.addr = obj.args_in[0]
        obj.pre_index = 0
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        if int(self.immediate) != 0:
            self.pattern = vldrb.pattern
        return super().write()


class vldrb_with_writeback(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>, <imm>]!"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrb_with_post(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>], <imm>"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrh(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>, <imm>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class vldrh_no_imm(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.addr = obj.args_in[0]
        obj.pre_index = 0
        return obj

    def write(self):
        if int(self.pre_index) != 0:
            self.immediate = simplify(self.pre_index)
            self.pattern = vldrh.pattern
        return super().write()


class vldrh_with_writeback(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>, <imm>]!"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrh_with_post(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>], <imm>"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrw(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>, <imm>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class vldrw_no_imm(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.addr = obj.args_in[0]
        obj.pre_index = 0
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        if int(self.immediate) != 0:
            self.pattern = vldrw.pattern
        return super().write()


class vldrw_with_writeback(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>, <imm>]!"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrw_with_post(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>], <imm>"
    inputs = ["Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj


class vldrw_gather(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>, <Qm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrw_gather_uxtw(MVEInstruction):
    pattern = "vldrw.<dt> <Qd>, [<Rn>, <Qm>, UXTW <imm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrb_gather(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>, <Qm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrb_gather_uxtw(MVEInstruction):
    pattern = "vldrb.<dt> <Qd>, [<Rn>, <Qm>, UXTW <imm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrh_gather(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>, <Qm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


class vldrh_gather_uxtw(MVEInstruction):
    pattern = "vldrh.<dt> <Qd>, [<Rn>, <Qm>, UXTW <imm>]"
    inputs = ["Qm", "Rn"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj


# NOTE: The output registers in all variants of VLD2 are input/output
#       because they're only partially overwritten. However, as a whole,
#       a block of VLD2{0-1} completely overwrites the output registers
#       and should therefore be allowed to perform register renaming.
#
#       We model this by treading the output registers as pure outputs
#       for VLD20, and as input/outputs for VLD21.
#
#       WARNING/TODO This only works for code using VLD2{0-1} in ascending order.


class vld20(MVEInstruction):
    pattern = "vld20.<dt> {<Qd0>, <Qd1>}, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_out_combinations = [
            ([0, 1], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
        ]
        obj.addr = obj.args_in[0]
        return obj


class vld21(MVEInstruction):
    pattern = "vld21.<dt> {<Qd0>, <Qd1>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        return obj


class vld20_with_writeback(MVEInstruction):
    pattern = "vld20.<dt> {<Qd0>, <Qd1>}, [<Rn>]!"
    inputs = ["Rn"]
    outputs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_out_combinations = [
            ([0, 1], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
        ]
        obj.addr = obj.args_in[0]
        obj.increment = 32
        return obj


class vld21_with_writeback(MVEInstruction):
    pattern = "vld21.<dt> {<Qd0>, <Qd1>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 32
        return obj


# NOTE: The output registers in all variants of VLD4 are input/output
#       because they're only partially overwritten. However, as a whole,
#       a block of VLD4{0-3} completely overwrites the output registers
#       and should therefore be allowed to perform register renaming.
#
#       We model this by treading the output registers as pure outputs
#       for VLD40, and as input/outputs for VLD4{1,2,3}.
#
#       WARNING/TODO This only works for code using VLD4{0-3} in ascending order.


class vld40(MVEInstruction):
    pattern = "vld40.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    outputs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_out_combinations = [
            (
                [0, 1, 2, 3],
                [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
            )
        ]
        obj.addr = obj.args_in[0]

        return obj


class vld41(MVEInstruction):
    pattern = "vld41.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vld42(MVEInstruction):
    pattern = "vld42.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vld43(MVEInstruction):
    pattern = "vld43.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vld40_with_writeback(MVEInstruction):
    pattern = "vld40.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    outputs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_out_combinations = [
            (
                [0, 1, 2, 3],
                [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
            )
        ]
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vld41_with_writeback(MVEInstruction):
    pattern = "vld41.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vld42_with_writeback(MVEInstruction):
    pattern = "vld42.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vld43_with_writeback(MVEInstruction):
    pattern = "vld43.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


# NOTE: We model VST20 as modifying the input vectors solely to enforce
#       the ordering VST2{0,1} -- they of course don't actually modify
#       the contents


class vst20(MVEInstruction):
    pattern = "vst20.<dt> {<Qd0>, <Qd1>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vst21(MVEInstruction):
    pattern = "vst21.<dt> {<Qd0>, <Qd1>}, [<Rn>]"
    inputs = ["Rn", "Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_in_combinations = [
            ([1, 2], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
        ]
        obj.addr = obj.args_in[0]

        return obj


class vst20_with_writeback(MVEInstruction):
    pattern = "vst20.<dt> {<Qd0>, <Qd1>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 32
        return obj


class vst21_with_writeback(MVEInstruction):
    pattern = "vst21.<dt> {<Qd0>, <Qd1>}, [<Rn>]!"
    inputs = ["Rn", "Qd0", "Qd1"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_in_combinations = [
            ([1, 2], [[f"q{i}", f"q{i+1}"] for i in range(0, 7)])
        ]
        obj.addr = obj.args_in[0]
        obj.increment = 32

        return obj


# NOTE: We model VST4{0,1,2} as modifying the input vectors solely to enforce
#       the ordering VST4{0,1,2,3} -- they of course don't actually modify
#       the contents


class vst40(MVEInstruction):
    pattern = "vst40.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vst41(MVEInstruction):
    pattern = "vst41.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vst42(MVEInstruction):
    pattern = "vst42.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]

        return obj


class vst43(MVEInstruction):
    pattern = "vst43.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]"
    inputs = ["Rn", "Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_in_combinations = [
            (
                [1, 2, 3, 4],
                [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
            )
        ]
        obj.addr = obj.args_in[0]

        return obj


class vst40_with_writeback(MVEInstruction):
    pattern = "vst40.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vst41_with_writeback(MVEInstruction):
    pattern = "vst41.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vst42_with_writeback(MVEInstruction):
    pattern = "vst42.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn"]
    in_outs = ["Qd0", "Qd1", "Qd2", "Qd3"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vst43_with_writeback(MVEInstruction):
    pattern = "vst43.<dt> {<Qd0>, <Qd1>, <Qd2>, <Qd3>}, [<Rn>]!"
    inputs = ["Rn", "Qd0", "Qd1", "Qd2", "Qd3"]
    outputs = []
    in_outs = []

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        obj.args_in_combinations = [
            (
                [1, 2, 3, 4],
                [[f"q{i}", f"q{i+1}", f"q{i+2}", f"q{i+3}"] for i in range(0, 5)],
            )
        ]
        obj.addr = obj.args_in[0]
        obj.increment = 64

        return obj


class vsubf(MVEInstruction):
    pattern = "vsub.<fdt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vsubf_T2(MVEInstruction):
    pattern = "vsub.<fdt> <Qd>, <Qn>, <Rm>"
    inputs = ["Qn", "Rm"]
    outputs = ["Qd"]


class vaddf(MVEInstruction):
    pattern = "vadd.<fdt> <Qd>, <Qn>, <Qm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]


class vcmla(MVEInstruction):
    pattern = "vcmla.<fdt> <Qd>, <Qn>, <Qm>, <imm>"
    inputs = ["Qn", "Qm"]
    in_outs = ["Qd"]


class vcmul(MVEInstruction):
    pattern = "vcmul.<fdt> <Qd>, <Qn>, <Qm>, <imm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        if obj.datatype == "f32":
            # First index: output, Second index: Input
            obj.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

        return obj


class vcadd(MVEInstruction):
    pattern = "vcadd.<dt> <Qd>, <Qn>, <Qm>, <imm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        if "32" in obj.datatype:
            # First index: output, Second index: Input
            obj.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

        return obj


class vhcadd(MVEInstruction):
    pattern = "vhcadd.<dt> <Qd>, <Qn>, <Qm>, <imm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        if "32" in obj.datatype:
            # First index: output, Second index: Input
            obj.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

        return obj


class vcaddf(MVEInstruction):
    pattern = "vcadd.<fdt> <Qd>, <Qn>, <Qm>, <imm>"
    inputs = ["Qn", "Qm"]
    outputs = ["Qd"]

    @classmethod
    def make(cls, src):
        obj = MVEInstruction.build(cls, src)
        if obj.datatype == "f32":
            # First index: output, Second index: Input
            obj.args_in_out_different = [
                (0, 0),
                (0, 1),
            ]  # Output must not be the same as any of the inputs

        return obj


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
        inst.outputs = inst.in_outs
        inst.pattern_outputs = inst.pattern_in_outs

        inst.num_in_out = 0
        inst.args_in_out = []
        inst.in_outs = []
        inst.pattern_in_outs = []
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


Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)


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


def iter_MVE_instructions():
    yield from all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_MVE_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise Exception("Couldn't find instruction class")

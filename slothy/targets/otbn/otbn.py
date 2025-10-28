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
Partial SLOTHY architecture model for OTBN
"""

import logging
import re
import math
from enum import Enum
from functools import cache
from sympy import simplify


from slothy.targets.common import FatalParsingException, UnknownInstruction
from slothy.helper import Loop, SourceLine

arch_name = "OTBN"

llvm_mca_arch = ""
llvm_mc_arch = ""


class RegisterType(Enum):
    GPR = 1
    WDR = 2
    STACK_WDR = 3
    STACK_GPR = 4
    FLAGS = 5
    ACC = 6
    MOD = 7
    HINT = 8

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

    @cache
    def _list_registers(
        reg_type, only_extra=False, only_normal=False, with_variants=False
    ):
        """Return the list of all registers of a given type"""

        qstack_locations = [f"QSTACK{i}" for i in range(8)]
        stack_locations = [f"STACK{i}" for i in range(8)]

        gprs_normal = [f"x{i}" for i in range(31)] + ["sp"]
        wregs_normal = [f"w{i}" for i in range(32)]

        gprs_extra = []
        vregs_extra = []

        gprs = []
        vregs = []
        hints = (
            [f"t{i}" for i in range(100)]
            + [f"t{i}{j}" for i in range(8) for j in range(8)]
            + [f"t{i}_{j}" for i in range(16) for j in range(16)]
        )

        flags = ["FG0", "FG1"]
        acc = ["ACC"]
        mod = ["MOD"]
        if not only_extra:
            gprs += gprs_normal
            vregs += wregs_normal
        if not only_normal:
            gprs += gprs_extra
            vregs += vregs_extra
        # if with_variants:
        #     gprs += gprs_variants
        #     vregs += vregs_variants

        return {
            RegisterType.GPR: gprs,
            RegisterType.STACK_GPR: stack_locations,
            RegisterType.STACK_WDR: qstack_locations,
            RegisterType.WDR: vregs,
            RegisterType.HINT: hints,
            RegisterType.FLAGS: flags,
            RegisterType.ACC: acc,
            RegisterType.MOD: mod,
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
        if ty in [RegisterType.HINT, RegisterType.ACC, RegisterType.MOD]:
            return False
        return True

    @staticmethod
    def from_string(string):
        """Find registe type from string"""
        string = string.lower()
        return {
            "qstack": RegisterType.STACK_WDR,
            "stack": RegisterType.STACK_GPR,
            "neon": RegisterType.WDR,
            "gpr": RegisterType.GPR,
            "hint": RegisterType.HINT,
            "flags": RegisterType.FLAGS,
        }.get(string, None)

    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(
            ["flags", "sp"]
            + RegisterType.list_registers(RegisterType.HINT)
            + RegisterType.list_registers(RegisterType.FLAGS)
        )

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
        self.barrel = None

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
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self, inst):
                return True
        return False

    def is_vector_load(self):
        """Indicates if an instruction is a Neon load instruction"""
        return self._is_instance_of([])

    def is_vector_store(self):
        """Indicates if an instruction is a Neon store instruction"""
        return self._is_instance_of([])

    # scalar
    def is_scalar_load(self):
        """Indicates if an instruction is a scalar load instruction"""
        return self._is_instance_of([])

    def is_scalar_store(self):
        """Indicates if an instruction is a scalar store instruction"""
        return self._is_instance_of([])

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

    def declassifies_output(self, output_idx):
        """Check if this instruction declassifies (produces public value) for a given output.

        Returns True if the output at output_idx is guaranteed to be public,
        regardless of input masking.

        Architecture-specific implementations should override this.

        Args:
            output_idx: Index of the output to check

        Returns:
            bool: True if the output is declassified to public
        """
        return False

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


class OTBNInstruction(Instruction):
    """Abstract class representing OTBN instructions"""

    PARSERS = {}

    @staticmethod
    def _replace_duplicate_datatypes(src, mnemonic_key):
        pattern = re.compile(rf"<{re.escape(mnemonic_key)}\d*>")

        matches = list(pattern.finditer(src))

        if len(matches) > 1:
            for i, match in enumerate(reversed(matches)):
                start, end = match.span()
                src = src[:start] + f"<{mnemonic_key}{len(matches)-1-i}>" + src[end:]

        return src

    @staticmethod
    def _unfold_pattern(src):

        # Those replacements may look pointless, but they replace
        # actual whitespaces before/after '.,[]()' in the instruction
        # pattern by regular expressions allowing flexible whitespacing.
        flexible_spacing = [
            (r"\s*,\s*", r"\\s*,\\s*"),
            (r"\s*<imm>\s*", r"\\s*<imm>\\s*"),
            (r"\s*\[\s*", r"\\s*\\[\\s*"),
            (r"\s*\]\s*", r"\\s*\\]\\s*"),
            (r"\s*\(\s*", r"\\s*\\(\\s*"),  # Handle ( for load/store
            (r"\s*\)\s*", r"\\s*\\)\\s*"),  # Handle ) for load/store
            (r"\s*\.\s*", r"\\s*\\.\\s*"),
            (r"\s*\+\+\s*", r"\\s*\\+\\+\\s*"),  # Handle ++ for increment
            (r"\s+", r"\\s+"),
            (r"\\s\*\\s\\+", r"\\s+"),
            (r"\\s\+\\s\\*", r"\\s+"),
            (r"(\\s\*)+", r"\\s*"),
        ]
        for c, cp in flexible_spacing:
            src = re.sub(c, cp, src)

        def pattern_transform(g):
            return (
                f"(({g.group(1).lower()}|{g.group(1)})"
                f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|"
                f"(({g.group(1).lower()}|{g.group(1)})"
                f"<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"
            )

        src = re.sub(r"<([XW]|FG)(\w+)>", pattern_transform, src)

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
            "C",
            "Z",
            "M",
            "L",
        ]

        flag_pattern = "|".join(flaglist)
        barrel_pattern = "<<|>>"  # Barrel shift operators
        imm_pattern = (
            "((\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|<<|>>)+)"
            "|"
            "(((0[xbw])?[0-9a-fA-F]+|/| |-|\\*|\\+|\\(|\\)|=|<<|>>)+)"
        )
        index_pattern = "[0-9]+"

        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = OTBNInstruction._replace_duplicate_datatypes(src, "dt")
        src = replace_placeholders(src, "index", index_pattern, "index")
        src = replace_placeholders(src, "flag", flag_pattern, "flag")
        src = replace_placeholders(src, "barrel", barrel_pattern, "barrel")

        src = r"\s*" + src + r"\s*(//.*)?\Z"
        return src

    @staticmethod
    def _build_parser(src):
        regexp_txt = OTBNInstruction._unfold_pattern(src)
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
        """Build parser for given OTBN instruction pattern"""
        if pattern in OTBNInstruction.PARSERS:
            return OTBNInstruction.PARSERS[pattern]
        parser = OTBNInstruction._build_parser(pattern)
        OTBNInstruction.PARSERS[pattern] = parser
        return parser

    @cache
    def __infer_register_type(ptrn):
        # Check for special registers first
        if ptrn == "ACC":
            return RegisterType.ACC
        if ptrn == "MOD":
            return RegisterType.MOD
        # Then check by prefix
        if ptrn[0].upper() in ["X"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["W"]:
            return RegisterType.WDR
        if ptrn[0].upper() in ["T"]:
            return RegisterType.HINT
        if ptrn[:2].upper() in ["FG"]:
            return RegisterType.FLAGS
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
    ):

        self.mnemonic = pattern.split(" ")[0]

        if inputs is None:
            inputs = []
        if outputs is None:
            outputs = []
        if in_outs is None:
            in_outs = []

        arg_types_in = [OTBNInstruction._infer_register_type(r) for r in inputs]
        arg_types_out = [OTBNInstruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [OTBNInstruction._infer_register_type(r) for r in in_outs]

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
        elif ty == RegisterType.WDR:
            c = "w"
        elif ty == RegisterType.HINT:
            c = "t"
        elif ty == RegisterType.FLAGS:
            c = "FG"
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
        if ty == RegisterType.WDR:
            if arg[0] != "w":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.HINT:
            if arg[0] != "t":
                return f"{s[0].upper()}<{arg}>"
        if ty == RegisterType.FLAGS:
            if arg[:2] != "FG":
                return f"{s[0].upper()}<{arg}>"
            return s[0].upper() + arg[1:]
        if ty in [RegisterType.ACC, RegisterType.MOD]:
            # ACC and MOD are special registers - return as-is
            return arg
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        if ty in [RegisterType.ACC, RegisterType.MOD]:
            # Special registers don't appear in the pattern - they're implicit
            return out
        if ty == RegisterType.FLAGS and s in ["FG0", "FG1"]:
            # Implicit FLAGS registers don't appear in the pattern
            return out
        rep = OTBNInstruction._build_pattern_replacement(s, ty, arg)
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
        group_to_attribute(
            "imm", "immediate", lambda x: x.replace("#", "")
        )  # Strip '#'
        group_to_attribute("index", "index", int)
        group_to_attribute("flag", "flag")
        group_to_attribute("barrel", "barrel")

        for s, ty in obj.pattern_inputs:
            if ty == RegisterType.ACC:
                obj.args_in.append("ACC")
            elif ty == RegisterType.MOD:
                obj.args_in.append("MOD")
            elif ty == RegisterType.FLAGS and s in ["FG0", "FG1"]:
                # Implicit FLAGS registers (FG0, FG1) - not in pattern
                obj.args_in.append(s)
            else:
                obj.args_in.append(OTBNInstruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            if ty == RegisterType.ACC:
                obj.args_out.append("ACC")
            elif ty == RegisterType.MOD:
                obj.args_out.append("MOD")
            elif ty == RegisterType.FLAGS and s in ["FG0", "FG1"]:
                # Implicit FLAGS registers (FG0, FG1) - not in pattern
                obj.args_out.append(s)
            else:
                obj.args_out.append(OTBNInstruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            if ty == RegisterType.ACC:
                obj.args_in_out.append("ACC")
            elif ty == RegisterType.MOD:
                obj.args_in_out.append("MOD")
            elif ty == RegisterType.FLAGS and s in ["FG0", "FG1"]:
                # Implicit FLAGS registers (FG0, FG1) - not in pattern
                obj.args_in_out.append(s)
            else:
                obj.args_in_out.append(OTBNInstruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()

        if isinstance(src, str):
            if src.split(" ")[0] != pattern.split(" ")[0]:
                raise Instruction.ParsingException("Mnemonic does not match")
            res = OTBNInstruction.get_parser(pattern)(src)
        else:
            assert isinstance(src, dict)
            res = src

        obj = c(
            pattern,
            inputs=inputs,
            outputs=outputs,
            in_outs=in_outs,
        )

        OTBNInstruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return OTBNInstruction.build(cls, src)

    def write(self):
        out = self.pattern
        ll = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )

        for arg, (s, ty) in ll:
            out = OTBNInstruction._instantiate_pattern(s, ty, arg, out)

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

        out = replace_pattern(out, "immediate", "imm", lambda x: x)
        out = OTBNInstruction._replace_duplicate_datatypes(out, "dt")
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "barrel", "barrel")

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        out = out.replace("\\(", "(")
        out = out.replace("\\)", ")")
        return out


# Instructions
class add_imm(OTBNInstruction):
    pattern = "addi <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


# Arithmetic instructions
class bn_add(OTBNInstruction):
    pattern = "bn.add <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_add_shift(OTBNInstruction):
    pattern = "bn.add <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_add_fg(OTBNInstruction):
    pattern = "bn.add <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_add_shift_fg(OTBNInstruction):
    pattern = "bn.add <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_addc(OTBNInstruction):
    pattern = "bn.addc <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_addc_shift(OTBNInstruction):
    pattern = "bn.addc <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_addc_fg(OTBNInstruction):
    pattern = "bn.addc <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_addc_shift_fg(OTBNInstruction):
    pattern = "bn.addc <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_add_imm(OTBNInstruction):
    pattern = "bn.addi <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_add_imm_fg(OTBNInstruction):
    pattern = "bn.addi <Wd>, <Wa>, <imm>, <FGa>"
    inputs = ["Wa"]
    outputs = ["Wd", "FGa"]


class bn_addm(OTBNInstruction):
    pattern = "bn.addm <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb", "MOD"]
    outputs = ["Wd"]


class bn_sub(OTBNInstruction):
    pattern = "bn.sub <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default

    def declassifies_output(self, output_idx):
        """SUB of a register from itself always produces 0 (public)"""
        if output_idx == 0 and len(self.args_in) >= 2:
            return self.args_in[0] == self.args_in[1]
        return False


class bn_sub_shift(OTBNInstruction):
    pattern = "bn.sub <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_sub_fg(OTBNInstruction):
    pattern = "bn.sub <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_sub_shift_fg(OTBNInstruction):
    pattern = "bn.sub <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_subb(OTBNInstruction):
    pattern = "bn.subb <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_subb_shift(OTBNInstruction):
    pattern = "bn.subb <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_subb_fg(OTBNInstruction):
    pattern = "bn.subb <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_subb_shift_fg(OTBNInstruction):
    pattern = "bn.subb <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_sub_imm(OTBNInstruction):
    pattern = "bn.subi <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_sub_imm_fg(OTBNInstruction):
    pattern = "bn.subi <Wd>, <Wa>, <imm>, <FGa>"
    inputs = ["Wa"]
    outputs = ["Wd", "FGa"]


class bn_subm(OTBNInstruction):
    pattern = "bn.subm <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb", "MOD"]
    outputs = ["Wd"]


# Logical instructions
class bn_and(OTBNInstruction):
    pattern = "bn.and <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_and_shift(OTBNInstruction):
    pattern = "bn.and <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_and_fg(OTBNInstruction):
    pattern = "bn.and <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_and_shift_fg(OTBNInstruction):
    pattern = "bn.and <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_or(OTBNInstruction):
    pattern = "bn.or <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_or_shift(OTBNInstruction):
    pattern = "bn.or <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_or_fg(OTBNInstruction):
    pattern = "bn.or <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_or_shift_fg(OTBNInstruction):
    pattern = "bn.or <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_not(OTBNInstruction):
    pattern = "bn.not <Wd>, <Wa>"
    inputs = ["Wa"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_not_shift(OTBNInstruction):
    pattern = "bn.not <Wd>, <Wa> <barrel> <imm>"
    inputs = ["Wa"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_not_fg(OTBNInstruction):
    pattern = "bn.not <Wd>, <Wa>, <FGa>"
    inputs = ["Wa"]
    outputs = ["Wd", "FGa"]


class bn_not_shift_fg(OTBNInstruction):
    pattern = "bn.not <Wd>, <Wa> <barrel> <imm>, <FGa>"
    inputs = ["Wa"]
    outputs = ["Wd", "FGa"]


class bn_xor(OTBNInstruction):
    pattern = "bn.xor <Wd>, <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default

    def declassifies_output(self, output_idx):
        """XOR of a register with itself always produces 0 (public)"""
        if output_idx == 0 and len(self.args_in) >= 2:
            return self.args_in[0] == self.args_in[1]
        return False


class bn_xor_shift(OTBNInstruction):
    pattern = "bn.xor <Wd>, <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FG0"]  # Writes to FG0 by default


class bn_xor_fg(OTBNInstruction):
    pattern = "bn.xor <Wd>, <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


class bn_xor_shift_fg(OTBNInstruction):
    pattern = "bn.xor <Wd>, <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]


# Shift instructions
class bn_rshi(OTBNInstruction):
    pattern = "bn.rshi <Wd>, <Wa>, <Wb> >> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


# Comparison instructions
class bn_cmp(OTBNInstruction):
    pattern = "bn.cmp <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["FG0"]  # Writes to FG0 by default


class bn_cmp_shift(OTBNInstruction):
    pattern = "bn.cmp <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["FG0"]  # Writes to FG0 by default


class bn_cmp_fg(OTBNInstruction):
    pattern = "bn.cmp <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa"]


class bn_cmp_shift_fg(OTBNInstruction):
    pattern = "bn.cmp <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa"]


class bn_cmpb(OTBNInstruction):
    pattern = "bn.cmpb <Wa>, <Wb>"
    inputs = ["Wa", "Wb"]
    outputs = ["FG0"]  # Writes to FG0 by default


class bn_cmpb_shift(OTBNInstruction):
    pattern = "bn.cmpb <Wa>, <Wb> <barrel> <imm>"
    inputs = ["Wa", "Wb"]
    outputs = ["FG0"]  # Writes to FG0 by default


class bn_cmpb_fg(OTBNInstruction):
    pattern = "bn.cmpb <Wa>, <Wb>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa"]


class bn_cmpb_shift_fg(OTBNInstruction):
    pattern = "bn.cmpb <Wa>, <Wb> <barrel> <imm>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa"]


# Move instructions
class bn_mov(OTBNInstruction):
    pattern = "bn.mov <Wd>, <Wa>"
    inputs = ["Wa"]
    outputs = ["Wd"]


class bn_movr(OTBNInstruction):
    pattern = "bn.movr <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class bn_movr_inc_src(OTBNInstruction):
    pattern = "bn.movr <Xd>, <Xa>++"
    inputs = []
    in_outs = ["Xa"]
    outputs = ["Xd"]


class bn_movr_inc_dst(OTBNInstruction):
    pattern = "bn.movr <Xd>++, <Xa>"
    inputs = ["Xa"]
    in_outs = ["Xd"]
    outputs = []


class bn_movr_inc_both(OTBNInstruction):
    pattern = "bn.movr <Xd>++, <Xa>++"
    inputs = []
    in_outs = ["Xd", "Xa"]
    outputs = []


# Conditional select
class bn_sel(OTBNInstruction):
    pattern = "bn.sel <Wd>, <Wa>, <Wb>, <FGa>.<flag>"
    inputs = ["Wa", "Wb", "FGa"]
    outputs = ["Wd"]


class bn_sel_no_fg(OTBNInstruction):
    pattern = "bn.sel <Wd>, <Wa>, <Wb>, <flag>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd"]


# Memory load/store instructions
class bn_lid(OTBNInstruction):
    pattern = "bn.lid <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class bn_lid_inc(OTBNInstruction):
    pattern = "bn.lid <Xd>, <imm>(<Xa>++)"
    inputs = ["Xa"]
    in_outs = ["Xa"]
    outputs = ["Xd"]


class bn_sid(OTBNInstruction):
    pattern = "bn.sid <Xa>, <imm>(<Xb>)"
    inputs = ["Xa", "Xb"]
    outputs = []


class bn_sid_inc(OTBNInstruction):
    pattern = "bn.sid <Xa>, <imm>(<Xb>++)"
    inputs = ["Xa", "Xb"]
    in_outs = ["Xb"]
    outputs = []


# Wide special register access
class bn_wsrr(OTBNInstruction):
    pattern = "bn.wsrr <Wd>, <imm>"
    inputs = []
    outputs = ["Wd"]


class bn_wsrr_URND(OTBNInstruction):
    pattern = "bn.wsrr <Wd>, URND"
    inputs = []
    outputs = ["Wd"]


class bn_wsrr_RND(OTBNInstruction):
    pattern = "bn.wsrr <Wd>, RND"
    inputs = []
    outputs = ["Wd"]


class bn_wsrr_ACC(OTBNInstruction):
    pattern = "bn.wsrr <Wd>, ACC"
    inputs = ["ACC"]
    outputs = ["Wd"]


class bn_wsrr_MOD(OTBNInstruction):
    pattern = "bn.wsrr <Wd>, MOD"
    inputs = ["MOD"]
    outputs = ["Wd"]


class bn_wsrw(OTBNInstruction):
    pattern = "bn.wsrw <imm>, <Wa>"
    inputs = ["Wa"]
    outputs = []


class bn_wsrw_MOD(OTBNInstruction):
    pattern = "bn.wsrw MOD, <Wa>"
    inputs = ["Wa"]
    outputs = ["MOD"]


class bn_wsrw_RND(OTBNInstruction):
    pattern = "bn.wsrw RND, <Wa>"
    inputs = ["Wa"]
    outputs = []


class bn_wsrw_ACC(OTBNInstruction):
    pattern = "bn.wsrw ACC, <Wa>"
    inputs = ["Wa"]
    outputs = ["ACC"]


class bn_wsrw_URND(OTBNInstruction):
    pattern = "bn.wsrw URND, <Wa>"
    inputs = ["Wa"]
    outputs = []


# Multiply-accumulate instructions
class bn_mulqacc(OTBNInstruction):
    pattern = "bn.mulqacc <Wa>.<imm0>, <Wb>.<imm1>, <imm2>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa"]
    in_outs = ["ACC"]


class bn_mulqacc_z(OTBNInstruction):
    pattern = "bn.mulqacc.z <Wa>.<imm0>, <Wb>.<imm1>, <imm2>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["FGa", "ACC"]  # .z zeros ACC first, so no dependency


class bn_mulqacc_so(OTBNInstruction):
    pattern = "bn.mulqacc.so <Wd>, <Wa>.<imm0>, <Wb>.<imm1>, <imm2>, <FGa>"
    inputs = ["Wa", "Wb"]
    in_outs = ["Wd", "ACC"]
    outputs = ["FGa"]


class bn_mulqacc_wo(OTBNInstruction):
    pattern = "bn.mulqacc.wo <Wd>, <Wa>.<imm0>, <Wb>.<imm1>, <imm2>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa"]
    in_outs = ["ACC"]


class bn_mulqacc_wo_z(OTBNInstruction):
    pattern = "bn.mulqacc.wo.z <Wd>, <Wa>.<imm0>, <Wb>.<imm1>, <imm2>, <FGa>"
    inputs = ["Wa", "Wb"]
    outputs = ["Wd", "FGa", "ACC"]  # .z zeros ACC first, so no dependency


def iter_otbn_instructions():
    yield from all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_otbn_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise UnknownInstruction(
        f"Couldn't find instruction class for {src} (type {type(src)})"
    )


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

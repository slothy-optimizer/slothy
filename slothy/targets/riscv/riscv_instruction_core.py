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

from slothy.targets.riscv.instruction_core import Instruction
import re as re
from slothy.targets.riscv.riscv import RegisterType
from slothy.targets.riscv.exceptions import FatalParsingException, ParsingException
from functools import cache


class RISCVInstruction(Instruction):
    """Abstract class representing RISCV instructions"""

    dynamic_instr_classes = []  # list of all rv32_64_i instruction classes
    classes_by_names = {}  # dict of all classes where keys are the class names
    PARSERS = {}
    is32bit_pattern = "w?"  # pattern to enable specific 32bit instructions (e.g. add/ addw)

    @staticmethod
    def _unfold_pattern(src):
        src = re.sub(r"\.", "\\\\s*\\\\.\\\\s*", src)
        # src = re.sub(r"\[", "\\\\s*\\\\[\\\\s*", src)
        # src = re.sub(r"\]", "\\\\s*\\\\]\\\\s*", src)
        src = re.sub(r"\(", "\\\\s*\\\\(\\\\s*", src)
        src = re.sub(r"\)", "\\\\s*\\\\)\\\\s*", src)

        def pattern_transform(g):
            return \
                    f"([{g.group(1).lower()}{g.group(1)}]" + \
                    f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|" + \
                    f"([{g.group(1).lower()}{g.group(1)}]<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"

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

        flaglist = ["eq", "ne", "cs", "hs", "cc", "lo", "mi", "pl", "vs", "vc", "hi", "ls", "ge", "lt", "gt", "le"]

        flag_pattern = '|'.join(flaglist)
        dt_pattern = "(?:|2|4|8|16)(?:B|H|S|D|b|h|s|d)"
        imm_pattern = "(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"

        src = re.sub(" ", "\\\\s+", src)
        src = re.sub(",", "\\\\s*,\\\\s*", src)

        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = replace_placeholders(src, "dt", dt_pattern, "datatype")
        src = replace_placeholders(src, "index", index_pattern, "index")
        src = replace_placeholders(src, "flag", flag_pattern, "flag")
        src = replace_placeholders(src, "w", RISCVInstruction.is32bit_pattern, "is32bit")

        src = r"\s*" + src + r"\s*(//.*)?\Z"
        return src

    @staticmethod
    def _build_parser(src):
        regexp_txt = RISCVInstruction._unfold_pattern(src)
        regexp = re.compile(regexp_txt)

        def _parse(line):
            regexp_result = regexp.match(line)
            if regexp_result is None:
                raise ParsingException(f"Does not match instruction pattern {src}" \
                                       f"[regex: {regexp_txt}]")
            res = regexp.match(line).groupdict()
            items = list(res.items())
            for k, v in items:
                for l in ["symbol_", "raw_"]:
                    if k.startswith(l):
                        del res[k]
                        if v is None:
                            continue
                        k = k[len(l):]
                        res[k] = v
            return res

        return _parse

    @staticmethod
    def get_parser(pattern):
        """Build parser for given AArch64 instruction pattern"""

        if pattern in RISCVInstruction.PARSERS:
            return RISCVInstruction.PARSERS[pattern]
        parser = RISCVInstruction._build_parser(pattern)
        RISCVInstruction.PARSERS[pattern] = parser
        return parser

    @cache
    @staticmethod
    def _infer_register_type(ptrn):
        if ptrn[0].upper() in ["X"]:
            return RegisterType.BASE_INT
        raise FatalParsingException(f"Unknown pattern: {ptrn}")

    def __init__(self, pattern, *, inputs=None, outputs=None, in_outs=None, modifiesFlags=False,
                 dependsOnFlags=False):

        self.mnemonic = pattern.split(" ")[0]

        if inputs is None:
            inputs = []
        if outputs is None:
            outputs = []
        if in_outs is None:
            in_outs = []
        arg_types_in = [RISCVInstruction._infer_register_type(r) for r in inputs]
        arg_types_out = [RISCVInstruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [RISCVInstruction._infer_register_type(r) for r in in_outs]

        # if modifiesFlags:
        #    arg_types_out += [RegisterType.FLAGS]
        #    outputs       += ["flags"]

        # if dependsOnFlags:
        #    arg_types_in += [RegisterType.FLAGS]
        #    inputs += ["flags"]

        super().__init__(mnemonic=pattern,
                         arg_types_in=arg_types_in,
                         arg_types_out=arg_types_out,
                         arg_types_in_out=arg_types_in_out)

        self.inputs = inputs
        self.outputs = outputs
        self.in_outs = in_outs

        self.pattern = pattern
        self.pattern_inputs = list(zip(inputs, arg_types_in, strict=True))
        self.pattern_outputs = list(zip(outputs, arg_types_out, strict=True))
        self.pattern_in_outs = list(zip(in_outs, arg_types_in_out, strict=True))

    @staticmethod
    def _to_reg(ty, s):
        if ty == RegisterType.BASE_INT:
            c = "x"
        else:
            assert False
        if s.replace('_', '').isdigit():
            return f"{c}{s}"
        return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        if ty == RegisterType.BASE_INT:
            if arg[0] != "x":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        # if ty == RegisterType.FLAGS:
        #    return out
        rep = RISCVInstruction._build_pattern_replacement(s, ty, arg)
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
                setattr(obj, attr_name,
                        list(map(lambda i: f(res[group_name_i(i)]), idxs)))

        group_to_attribute('datatype', 'datatype', lambda x: x.lower())
        group_to_attribute('imm', 'immediate')
        group_to_attribute('index', 'index', int)
        group_to_attribute('flag', 'flag')
        group_to_attribute('is32bit', 'is32bit')

        for s, ty in obj.pattern_inputs:
            # if ty == RegisterType.FLAGS:
            #    obj.args_in.append("flags")
            # else:
            obj.args_in.append(RISCVInstruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            # if ty == RegisterType.FLAGS:
            #    obj.args_out.append("flags")
            # else:
            obj.args_out.append(RISCVInstruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(RISCVInstruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c, "modifiesFlags", False)
        depends_on_flags = getattr(c, "dependsOnFlags", False)

        if isinstance(src, str):
            if not re.match(src.split(' ')[0], pattern.replace('<w>', RISCVInstruction.is32bit_pattern).split(' ')[0]):
                raise ParsingException("Mnemonic does not match")
            res = RISCVInstruction.get_parser(pattern)(src)
        else:
            assert isinstance(src, dict)
            res = src

        obj = c(pattern, inputs=inputs, outputs=outputs, in_outs=in_outs,
                modifiesFlags=modifies_flags, dependsOnFlags=depends_on_flags)

        RISCVInstruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return RISCVInstruction.build(cls, src)

    def write(self):
        out = self.pattern
        l = list(zip(self.args_in, self.pattern_inputs)) + \
            list(zip(self.args_out, self.pattern_outputs)) + \
            list(zip(self.args_in_out, self.pattern_in_outs))
        for arg, (s, ty) in l:
            out = RISCVInstruction._instantiate_pattern(s, ty, arg, out)

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

        out = replace_pattern(out, "immediate", "imm", lambda x: f"{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "is32bit", "w", lambda x: x.lower())

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

    @classmethod
    def instr_factory(self, instr_list, baseclass):
        """
        Dynamically creates instruction classes from a list, inheriting from a given super class. This method allows
        to create classes for instructions with common pattern, inputs and outputs at one go. Usually, a lot of instructions
        share the same structure.

        :param instr_list: List of instructions with a common pattern etc. to create classes of
        :param baseclass: Baseclass which describes the common pattern and other properties of the instruction type
        :return: A list with the dynamically created classes
        """

        PythonKeywords = ["and", "or"]  # not allowed as class names

        for instr in instr_list:
            classname = instr
            if "<w>" in instr:
                classname = instr.split("<")[0]
            if instr in PythonKeywords:
                classname = classname + "cls"
            RISCVInstruction.dynamic_instr_classes.append(type(classname, (baseclass, Instruction),
                                                               {'pattern': baseclass.pattern.replace("mnemonic",
                                                                                                     instr)}))
        return RISCVInstruction.dynamic_instr_classes

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
Pattern-based abstract x86_64 instruction class
"""

import re
from functools import cache

from slothy.targets.exceptions import FatalParsingException, ParsingException
from slothy.targets.x86_64.instruction_core import Instruction
from slothy.targets.x86_64.x86_64 import RegisterType, SymbolicRegister


class x86_64Instruction(Instruction):
    """Abstract class representing x86_64 instructions"""

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
        # actual whitespaces before/after '.,[]' in the instruction
        # pattern by regular expressions allowing flexible whitespacing.
        flexible_spacing = [
            (r"\s*,\s*", r"\\s*,\\s*"),
            (r"\s*<imm>\s*", r"\\s*<imm>\\s*"),
            (r"\s*<offset>\s*", r"\\s*<offset>\\s*"),
            (r"\s*<literal>\s*", r"\\s*<literal>\\s*"),
            (r"\s*\[\s*", r"\\s*\\[\\s*"),
            (r"\s*\]\s*", r"\\s*\\]\\s*"),
            (r"\s*\(\s*", r"\\s*\\(\\s*"),
            (r"\s*\)\s*", r"\\s*\\)\\s*"),
            (r"\s*\{\s*", r"\\s*\\{\\s*"),
            (r"\s*\}\s*", r"\\s*\\}\\s*"),
            (r"\s*\.\s*", r"\\s*\\.\\s*"),
            (r"\s+", r"\\s+"),
            (r"\\s\*\\s\\+", r"\\s+"),
            (r"\\s\+\\s\\*", r"\\s+"),
            (r"(\\s\*)+", r"\\s*"),
        ]
        for c, cp in flexible_spacing:
            src = re.sub(c, cp, src)

        def idx_pattern_transform(g):
            return (
                f"%(([eErR]|ymm|YMM|xmm|XMM)?"
                f"(?P<raw_{g.group(1)}>([abcdABCD]|[sbSB][pP]|[sSdD][iI]|\\d[0-5]?))"
                f"[lLwWdDxX]?"
                f"|{g.group(1)[:-1]}<(?P<symbol_{g.group(1)}>\\w[\\w\\d_]*)>)"
            )

        def sz_pattern_transform(g):
            return (
                f"%((?P<raw_{g.group(1)}>"
                f"([eErR]?([a-dA-D][lLxX]|([sSdD][iI]|[sSbB][pP])[lL]?)"
                f"|[rR](8|9|1[0-5])[wWlLdD]?"
                f"|([xX]|[yY])[mM][mM](1[0-5]|[0-9])))"
                f"|(?P<symbol_{g.group(1)}>{g.group(1)[:-1]}<\\w[\\w\\d_]*>))"
            )

        idx_re = re.sub(r"<(\w(W|(MM))\w)>", idx_pattern_transform, src)
        sz_re = re.sub(r"<(\w(W|(MM))\w)>", sz_pattern_transform, src)

        # Replace <key> or <key0>, <key1>, ... with pattern
        def replace_placeholders(src, mnemonic_key, regexp, group_name, pre_capture=""):
            prefix = f"<{mnemonic_key}"
            pattern = f"<{mnemonic_key}>"

            def pattern_i(i):
                return f"<{mnemonic_key}{i}>"

            cnt = src.count(prefix)
            if cnt > 1:
                for i in range(cnt):
                    src = re.sub(
                        pattern_i(i), f"{pre_capture}(?P<{group_name}{i}>{regexp})", src
                    )
            else:
                src = re.sub(pattern, f"{pre_capture}(?P<{group_name}>{regexp})", src)

            return src

        imm_pattern = (
            "((\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|<<|>>)+)"
            "|"
            "(((0[xb])?[0-9a-fA-F]+|/| |-|\\*|\\+|\\(|\\)|<<|>>)+)"
        )
        # An offset must not be empty or whitespace: "(%rsi)" has no offset
        offset_pattern = "(?=\\\\S)(?:" + imm_pattern + ")"

        idx_re = replace_placeholders(idx_re, "imm", imm_pattern, "imm", "\\$")
        sz_re = replace_placeholders(sz_re, "imm", imm_pattern, "imm", "\\$")
        idx_re = replace_placeholders(idx_re, "offset", offset_pattern, "offset")
        sz_re = replace_placeholders(sz_re, "offset", offset_pattern, "offset")
        # Branch targets (removed with the <addr> placeholder in b357de7, which
        # left jz/jnz unparseable)
        label_pattern = r"(?:[\\w.]+)"
        idx_re = replace_placeholders(idx_re, "label", label_pattern, "label")
        sz_re = replace_placeholders(sz_re, "label", label_pattern, "label")

        idx_re = r"\s*" + idx_re + r"\s*(//.*)?\Z"
        sz_re = r"\s*" + sz_re + r"\s*(//.*)?\Z"
        return idx_re, sz_re

    @staticmethod
    def check_reg_sizes(sz_re_match):
        sz_dict = sz_re_match.groupdict()
        sz_dict_pruned = {}
        # Construct a dictionary of only non-empty architectural register items to check
        # We ignore anything that is not a register
        for sz_sym, reg in sz_dict.items():
            if "raw_" in sz_sym:
                if reg is not None:
                    sz_dict_pruned[sz_sym[4:]] = reg
                elif sz_dict.get("symbol_" + sz_sym[4:]) is None:
                    # I don't think this is possible without previous failure but
                    # just in case
                    raise FatalParsingException(
                        "Register value matches neither architectural or symbolic "
                        f"format for position {sz_sym[4:]} in pattern!"
                    )

        for sz_sym, reg in sz_dict_pruned.items():
            reg = reg.lower()
            if any(tag in sz_sym for tag in ["imm", "offset"]):
                continue
            elif "H" in sz_sym:
                if reg in RegisterType.list_byte_gprs():
                    continue
            elif "S" in sz_sym:
                if reg in RegisterType.list_word_gprs():
                    continue
            elif "D" in sz_sym:
                if reg in RegisterType.list_dblword_gprs():
                    continue
            elif "Q" in sz_sym:
                if reg in RegisterType.list_qdword_gprs():
                    continue
            elif "X" in sz_sym:
                if reg in RegisterType.list_xmm():
                    continue
            elif "Y" in sz_sym:
                if reg in RegisterType.list_ymm():
                    continue
            return False
        return True

    @staticmethod
    def _build_parser(src):
        idx_regexp_txt, sz_regexp_txt = x86_64Instruction._unfold_pattern(src)
        idx_regexp = re.compile(idx_regexp_txt)
        sz_regexp = re.compile(sz_regexp_txt)

        def _parse(line):
            idx_regexp_result = idx_regexp.match(line)
            sz_regexp_result = sz_regexp.match(line)
            if (
                idx_regexp_result is None
                or sz_regexp_result is None
                or not x86_64Instruction.check_reg_sizes(sz_regexp_result)
            ):
                raise ParsingException(
                    f"Does not match instruction pattern {src}"
                    f"[indexing regex: {idx_regexp_txt}]"
                    f"[size regex: {sz_regexp_txt}]"
                )
            res = idx_regexp_result.groupdict()
            res_pruned = {}
            # Construct a dictionary with only the entry which is not None for each
            # element in the pattern
            for sz_sym, reg in res.items():
                # Treat only registers here
                if "raw_" in sz_sym:
                    # If raw version not None then use
                    if reg is not None:
                        res_pruned[sz_sym[4:]] = reg
                    # Otherwise try to use symbolic
                    elif res.get("symbol_" + sz_sym[4:]) is not None:
                        res_pruned[sz_sym[4:]] = SymbolicRegister(
                            res["symbol_" + sz_sym[4:]]
                        )
                    else:
                        # I don't think this is possible without previous failure but
                        # just in case
                        raise FatalParsingException(
                            "Register value matches neither architectural or symbolic "
                            f"format for position {sz_sym[4:]} in pattern!"
                        )
                # Leave everything else in the dictionary
                elif "symbol_" not in sz_sym:
                    res_pruned[sz_sym] = reg

            return res_pruned

        return _parse

    @staticmethod
    def get_parser(pattern):
        """Build parser for given x86_64 instruction pattern"""
        if pattern in x86_64Instruction.PARSERS:
            return x86_64Instruction.PARSERS[pattern]
        parser = x86_64Instruction._build_parser(pattern)
        x86_64Instruction.PARSERS[pattern] = parser
        return parser

    @staticmethod
    @cache
    def _infer_register_type(ptrn):
        if ptrn[0:2].upper() == "HW":
            return RegisterType.GPR_H
        if ptrn[0:2].upper() == "SW":
            return RegisterType.GPR_S
        if ptrn[0:2].upper() == "DW":
            return RegisterType.GPR_D
        if ptrn[0:2].upper() == "QW":
            return RegisterType.GPR_Q

        if ptrn[0:3].upper() == "XMM":
            return RegisterType.XMM
        if ptrn[0:3].upper() == "YMM":
            return RegisterType.YMM

        if ptrn[-1].upper() == "F":
            return RegisterType.FLAGS
        raise FatalParsingException(f"Unknown pattern: {ptrn}")

    def __init__(
        self,
        pattern,
        *,
        inputs=None,
        outputs=None,
        in_outs=None,
        modifiesFlags=False,
        dependsOnFlags=False,
        implicit_in_outs=None,
    ):

        self.mnemonic = pattern.split(" ")[0]

        if inputs is None:
            inputs = []
        if outputs is None:
            outputs = []
        if in_outs is None:
            in_outs = []
        arg_types_in = [x86_64Instruction._infer_register_type(r) for r in inputs]
        arg_types_out = [x86_64Instruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [x86_64Instruction._infer_register_type(r) for r in in_outs]

        if modifiesFlags:
            arg_types_out += [RegisterType.FLAGS]
            outputs += ["flags"]

        if dependsOnFlags:
            arg_types_in += [RegisterType.FLAGS]
            inputs += ["flags"]

        # Registers read and written without appearing in the textual pattern, e.g.
        # rsp for push/pop. They are pinned to that register during allocation.
        if implicit_in_outs is None:
            implicit_in_outs = []
        arg_types_in_out += [ty for _, ty in implicit_in_outs]
        in_outs += [reg for reg, _ in implicit_in_outs]

        super().__init__(
            mnemonic=pattern,
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.inputs = inputs
        self.outputs = outputs
        self.in_outs = in_outs

        self.implicit_in_outs = [reg for reg, _ in implicit_in_outs]
        for i, reg in enumerate(in_outs):
            if reg in self.implicit_in_outs:
                self.args_in_out_restrictions[i] = [reg]

        self.pattern = pattern
        assert len(inputs) == len(arg_types_in)
        self.pattern_inputs = list(zip(inputs, arg_types_in))
        assert len(outputs) == len(arg_types_out)
        self.pattern_outputs = list(zip(outputs, arg_types_out))
        assert len(in_outs) == len(arg_types_in_out)
        self.pattern_in_outs = list(zip(in_outs, arg_types_in_out))

    @staticmethod
    def _to_reg(ty, s):
        if isinstance(s, SymbolicRegister):
            prefix = {
                RegisterType.GPR_H: "HW",
                RegisterType.GPR_S: "SW",
                RegisterType.GPR_D: "DW",
                RegisterType.GPR_Q: "QW",
                RegisterType.XMM: "XMM",
                RegisterType.YMM: "YMM",
            }[ty]
            return f"{prefix}<{s}>"
        if ty == RegisterType.GPR_H:
            if s.isnumeric():
                return f"r{s}l"
            if s.lower() in ["a", "b", "c", "d"]:
                return f"{s.lower()}l"
            if s.lower() in ["si", "di", "bp", "sp"]:
                return f"{s.lower()}l"
            return f"HW<{s}>"
        if ty == RegisterType.GPR_S:
            if s.isnumeric():
                return f"r{s}w"
            if s.lower() in ["a", "b", "c", "d"]:
                return f"{s.lower()}x"
            if s.lower() in ["si", "di", "bp", "sp"]:
                return s.lower()
            return f"SW<{s}>"
        if ty == RegisterType.GPR_D:
            if s.isnumeric():
                return f"r{s}d"
            if s.lower() in ["a", "b", "c", "d"]:
                return f"e{s.lower()}x"
            if s.lower() in ["si", "di", "bp", "sp"]:
                return f"e{s.lower()}"
            return f"DW<{s}>"
        if ty == RegisterType.GPR_Q:
            if s.isnumeric():
                return f"r{s}"
            if s.lower() in ["a", "b", "c", "d"]:
                return f"r{s.lower()}x"
            if s.lower() in ["si", "di", "bp", "sp"]:
                return f"r{s.lower()}"
            return f"QW<{s}>"

        if ty == RegisterType.XMM:
            if s.isnumeric():
                return f"xmm{s}"
            return f"XMM<{s}>"
        if ty == RegisterType.YMM:
            if s.isnumeric():
                return f"ymm{s}"
            return f"YMM<{s}>"

        if ty == RegisterType.FLAGS:
            return s

        return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        _ = s
        if ty in [
            RegisterType.GPR_H,
            RegisterType.GPR_S,
            RegisterType.GPR_D,
            RegisterType.GPR_Q,
            RegisterType.XMM,
            RegisterType.YMM,
        ]:
            return f"%{arg}"
        if ty in [RegisterType.list_flags]:
            return arg
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        if ty == RegisterType.FLAGS:
            return out
        rep = x86_64Instruction._build_pattern_replacement(s, ty, arg)
        res = out.replace(f"<{s}>", rep)
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

        group_to_attribute(
            "imm", "immediate", lambda x: x.replace("#", "")
        )  # Strip '#'
        group_to_attribute("offset", "offset")
        group_to_attribute(
            "literal", "immediate", lambda x: x.replace("#", "")
        )  # Strip '#'
        group_to_attribute("index", "index", int)
        group_to_attribute("label", "label")

        for s, ty in obj.pattern_inputs:
            if ty == RegisterType.FLAGS:
                obj.args_in.append(obj._to_reg(ty, s))
            else:
                obj.args_in.append(obj._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            if ty == RegisterType.FLAGS:
                obj.args_out.append(obj._to_reg(ty, s))
            else:
                obj.args_out.append(obj._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            if s in obj.implicit_in_outs:
                obj.args_in_out.append(s)
            else:
                obj.args_in_out.append(obj._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c, "modifiesFlags", False)
        depends_on_flags = getattr(c, "dependsOnFlags", False)
        implicit_in_outs = getattr(c, "implicitInOuts", [])

        if isinstance(src, str):
            if src.split(" ")[0] != pattern.split(" ")[0]:
                raise ParsingException("Mnemonic does not match")
            res = x86_64Instruction.get_parser(pattern)(src)
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
            implicit_in_outs=implicit_in_outs,
        )

        x86_64Instruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return x86_64Instruction.build(cls, src)

    def write(self):
        out = self.pattern
        ll = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
            + list(zip(self.args_out, self.pattern_outputs))
        )
        for arg, (s, ty) in ll:
            out = x86_64Instruction._instantiate_pattern(s, ty, arg, out)

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

        out = replace_pattern(out, "immediate", "imm", lambda x: f"${x}")
        out = replace_pattern(out, "offset", "offset", lambda x: f"{x}")
        out = replace_pattern(out, "label", "label")

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

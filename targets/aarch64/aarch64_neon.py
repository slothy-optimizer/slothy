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

###
### WARNING: This module is highly incomplete and does not constitute a complete
###          parser for AArch64 -- in fact, so far, only a handful instructions are
###          modelled, with a strongly simplified syntax. For now, this is only to
###          allow experimentation to get an idea of performance of SLOTHY for AArch64.
###

import logging
import inspect
import re
import math

from sympy import simplify
from enum import Enum
from functools import cache

class RegisterType(Enum):
    GPR = 1,
    Neon = 2,
    StackNeon = 3,
    StackGPR = 4,
    StackAny = 5,
    Flags = 6,
    Hint = 7,

    def __str__(self):
        return self.name
    def __repr__(self):
        return self.name

    @cache
    @staticmethod
    def list_registers(reg_type, only_extra=False, only_normal=False, with_variants=False):
        """Return the list of all registers of a given type"""

        qstack_locations = [ f"QSTACK{i}" for i in range(8) ]
        stack_locations  = [ f"STACK{i}"  for i in range(8) ]

        # TODO: this is needed for X25519; as we use the same stack space
        # for Neon and GPR; It would be great to unify. Ideally, one should
        # be able to just use STACK_ without having to define it here
        stackany_locations = [
            "STACK_MASK1",
            "STACK_MASK2",
            "STACK_A_0",
            "STACK_A_8",
            "STACK_A_16",
            "STACK_A_24",
            "STACK_A_32",
            "STACK_B_0",
            "STACK_B_8",
            "STACK_B_16",
            "STACK_B_24",
            "STACK_B_32",
            "STACK_CTR",
            "STACK_LASTBIT",
            "STACK_SCALAR",
            "STACK_X_0",
            "STACK_X_8",
            "STACK_X_16",
            "STACK_X_24",
            "STACK_X_32"
        ]


        gprs_normal  = [ f"x{i}" for i in range(31) ] + ["sp"]
        vregs_normal = [ f"v{i}" for i in range(32) ]

        gprs_extra  = []
        vregs_extra = []

        gprs_variants = [ f"w{i}" for i in range(31) ]
        vregs_variants = [ f"q{i}" for i in range(32) ]

        gprs  = []
        vregs = []
        hints = [ f"t{i}" for i in range(100) ] + \
                [ f"t{i}{j}" for i in range(8) for j in range(8) ] + \
                [ f"t{i}_{j}" for i in range(16) for j in range(16) ]

        flags = ["flags"]
        if not only_extra:
            gprs  += gprs_normal
            vregs += vregs_normal
        if not only_normal:
            gprs  += gprs_extra
            vregs += vregs_extra
        if with_variants:
            gprs += gprs_variants
            vregs += vregs_variants

        return { RegisterType.GPR      : gprs,
                 RegisterType.StackGPR : stack_locations,
                 RegisterType.StackNeon : qstack_locations,
                 RegisterType.StackAny  : stackany_locations,
                 RegisterType.Neon      : vregs,
                 RegisterType.Hint      : hints,
                 RegisterType.Flags     : flags}[reg_type]

    @staticmethod
    def find_type(r):
        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty
        raise UnknownRegister(f"Unknown architectural register {r}")

    @staticmethod
    def from_string(string):
        string = string.lower()
        return { "qstack"   : RegisterType.StackNeon,
                 "stack"    : RegisterType.StackGPR,
                 "stackany" : RegisterType.StackAny,
                 "neon"     : RegisterType.Neon,
                 "gpr"      : RegisterType.GPR,
                 "hint"     : RegisterType.Hint,
                 "flags"    : RegisterType.Flags}.get(string,None)

    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set(["flags", "sp",
            "STACK_MASK1",
            "STACK_MASK2",
            "STACK_A_0",
            "STACK_A_8",
            "STACK_A_16",
            "STACK_A_24",
            "STACK_A_32",
            "STACK_B_0",
            "STACK_B_8",
            "STACK_B_16",
            "STACK_B_24",
            "STACK_B_32",
            "STACK_CTR",
            "STACK_LASTBIT",
            "STACK_SCALAR",
            "STACK_X_0",
            "STACK_X_8",
            "STACK_X_16",
            "STACK_X_24",
            "STACK_X_32"
                    ] + RegisterType.list_registers(RegisterType.Hint))

    @staticmethod
    def default_aliases():
        return {}

class Branch:
    """Helper for emitting branches"""

    @staticmethod
    def if_equal(val, lbl):
        """Emit assembly for a branch-if-equal sequence"""
        reg = "count"
        yield f"cmp {reg}, #{val}"
        yield f"b.eq {lbl}"

    @staticmethod
    def if_greater_equal(val, lbl):
        """Emit assembly for a branch-if-greater-equal sequence"""
        reg = "count"
        yield f"cmp {reg}, #{val}"
        yield f"b.ge {lbl}"

    @staticmethod
    def unconditional(lbl):
        """Emit unconditional branch"""
        yield f"b {lbl}"

class Loop:
    """Helper functions for parsing and writing simple loops in AArch64

    TODO: Generalize; current implementation too specific about shape of loop"""

    def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr"):
        self.lbl_start = lbl_start
        self.lbl_end   = lbl_end
        self.loop_init = loop_init

    def start(self, indentation=0, fixup=0, unroll=1, jump_if_empty=None):
        """Emit starting instruction(s) and jump label for loop"""
        indent = ' ' * indentation
        if unroll > 1:
            assert unroll in [1,2,4,8,16,32]
            yield f"{indent}lsr count, count, #{int(math.log2(unroll))}"
        if fixup != 0:
            yield f"{indent}sub count, count, #{fixup}"
        if jump_if_empty is not None:
            yield f"cbz count, {jump_if_empty}"
        yield f"{self.lbl_start}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        (reg0, reg1, imm) = other
        indent = ' ' * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"

        yield f"{indent}sub {reg0}, {reg1}, {imm}"
        yield f"{indent}cbnz {reg0}, {lbl_start}"

    @staticmethod
    def extract(source, lbl):
        """Locate a loop with start label `lbl` in `source`.

        We currently only support the following loop forms:

           ```
           loop_lbl:
               {code}
               sub[s] <cnt>, <cnt>, #1
               (cbnz|bnz|bne) <cnt>, loop_lbl
           ```

        """

        pre  = []
        body = []
        post = []
        loop_lbl_regexp_txt = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)

        # TODO: Allow other forms of looping

        loop_end_regexp_txt = (r"^\s*sub[s]?\s+(?P<reg0>\w+),\s*(?P<reg1>\w+),\s*(?P<imm>#1)",
                               rf"^\s*(cbnz|bnz|bne)\s+(?P<reg0>\w+),\s*{lbl}")
        loop_end_regexp = [re.compile(txt) for txt in loop_end_regexp_txt]
        lines = iter(source.splitlines())
        l = None
        keep = False
        state = 0 # 0: haven't found loop yet, 1: extracting loop, 2: after loop
        while True:
            if not keep:
                l = next(lines, None)
            keep = False
            if l is None:
                break
            if state == 0:
                p = loop_lbl_regexp.match(l)
                if p is not None and p.group("label") == lbl:
                    l = p.group("remainder")
                    keep = True
                    state = 1
                else:
                    pre.append(l)
                continue
            if state == 1:
                p = loop_end_regexp[0].match(l)
                if p is not None:
                    reg0 = p.group("reg0")
                    reg1 = p.group("reg1")
                    imm = p.group("imm")
                    state = 2
                    continue
                body.append(l)
                continue
            if state == 2:
                p = loop_end_regexp[1].match(l)
                if p is not None:
                    state = 3
                    continue
                body.append(l)
                continue
            if state == 3:
                post.append(l)
                continue
        if state < 3:
            raise FatalParsingException(f"Couldn't identify loop {lbl}")
        return pre, body, post, lbl, (reg0, reg1, imm)

class FatalParsingException(Exception):
    """A fatal error happened during instruction parsing"""

class UnknownInstruction(Exception):
    """The parent instruction class for the given object could not be found"""

class UnknownRegister(Exception):
    """The register could not be found"""

class Instruction:

    class ParsingException(Exception):
        """An attempt to parse an assembly line as a specific instruction failed

        This is a frequently encountered exception since assembly lines are parsed by
        trial and error, iterating over all instruction parsers."""
        def __init__(self, err=None):
            super().__init__(err)

    def __init__(self, *, mnemonic,
                 arg_types_in= None, arg_types_in_out = None, arg_types_out = None):

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

        self.arg_types_in     = arg_types_in
        self.arg_types_out    = arg_types_out
        self.arg_types_in_out = arg_types_in_out
        self.num_in           = len(arg_types_in)
        self.num_out          = len(arg_types_out)
        self.num_in_out       = len(arg_types_in_out)

        self.args_out_restrictions    = [ None for _ in range(self.num_out)    ]
        self.args_in_restrictions     = [ None for _ in range(self.num_in)     ]
        self.args_in_out_restrictions = [ None for _ in range(self.num_in_out) ]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.addr = None
        self.increment = None
        self.pre_index = None
        self.immediate = None

    def global_parsing_cb(self, a, log=None):
        """Parsing callback triggered after DataFlowGraph parsing which allows modification
        of the instruction in the context of the overall computation.

        This is primarily used to remodel input-outputs as outputs in jointly destructive
        instruction patterns (See Section 4.4, https://eprint.iacr.org/2022/1303.pdf)."""
        return False

    def global_fusion_cb(self, a, log=None):
        """Fusion callback triggered after DataFlowGraph parsing which allows fusing
        of the instruction in the context of the overall computation.

        This can be used e.g. to detect eor-eor pairs and replace them by eor3."""
        return False

    def write(self):
        """Write the instruction"""
        args = self.args_out + self.args_in_out + self.args_in
        return self.mnemonic + ' ' + ', '.join(args)

    @staticmethod
    def unfold_abbrevs(mnemonic):
        if mnemonic.count("<dt") > 1:
            for i in range(mnemonic.count("<dt")):
                mnemonic = re.sub(f"<dt{i}>",  f"(?P<datatype{i}>(?:2|4|8|16)(?:B|H|S|D))", mnemonic)
        else:
            mnemonic = re.sub("<dt>",  "(?P<datatype>(?:|i|u|s)(?:8|16|32|64))", mnemonic)
            mnemonic = re.sub("<fdt>", "(?P<datatype>(?:f)(?:8|16|32))", mnemonic)
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self,inst):
                return True
        return False

    # vector
    def is_Qform_vector_instruction(self):
        if not hasattr(self, "datatype"):
            return self._is_instance_of([
                                      vmul, vmul_lane,
                                      vmla, vmla_lane,
                                      vmls, vmls_lane,
                                      vqrdmulh, vqrdmulh_lane,
                                      vqdmulh_lane,
                                      vsrshr,
                                      Str_Q, Ldr_Q,
                                      stack_vld1r])
        dt = getattr(self, "datatype")
        if dt == "":
            return False
        if dt[0].lower() in ["2d", "4s", "8h", "16b"]:
            return True
        if dt[0].lower() in ["1d", "2s", "4h", "8b"]:
            return False
        raise FatalParsingException(f"unknown datatype {dt}")

    def is_vector_mul(self):
        return self._is_instance_of([ vmul, vmul_lane,
                                      vmla, vmls_lane, vmls,
                                      vqrdmulh, vqrdmulh_lane, vqdmulh_lane,
                                      vmull, vmlal ])
    def is_vector_add_sub(self):
        return self._is_instance_of([ vadd, vsub ])
    def is_vector_load(self):
        return self._is_instance_of([ Ldr_Q ]) # TODO: Ld4 missing?
    def is_vector_store(self):
        return self._is_instance_of([ Str_Q, St4, stack_vstp_dform, stack_vstr_dform])
    def is_vector_stack_load(self):
        return self._is_instance_of([stack_vld1r, stack_vldr_bform, stack_vldr_dform,
        stack_vld2_lane])
    def is_vector_stack_store(self):
        return self._is_instance_of([])

    # scalar
    def is_scalar_load(self):
        return self._is_instance_of([ Ldr_X, Ldp_X ])
    def is_scalar_store(self):
        return  self._is_instance_of([ Stp_X, Str_X ])
    def is_scalar_stack_store(self):
        return self._is_instance_of([save, qsave, stack_stp, stack_stp_wform, stack_str])
    def is_scalar_stack_load(self):
        return self._is_instance_of([restore, qrestore, stack_ldr])

    # scalar or vector
    def is_load(self):
        return self.is_vector_load() or self.is_scalar_load()
    def is_store(self):
        return self.is_vector_store() or self.is_scalar_store()
    def is_stack_load(self):
        return self.is_vector_stack_load() or self.is_scalar_stack_load()
    def is_stack_store(self):
        return self.is_vector_stack_store() or self.is_scalar_stack_store()
    def is_load_store_instruction(self):
        return self.is_load() or self.is_store()

    @classmethod
    def make(cls, src):
        """Abstract factory method parsing a string into an instruction instance."""

    @staticmethod
    def build(c, src, mnemonic, **kwargs):
        if src.split(' ')[0] != mnemonic:
            raise Instruction.ParsingException("Mnemonic does not match")

        obj = c(mnemonic=mnemonic, **kwargs)

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(obj.mnemonic)

        expected_args = obj.num_in + obj.num_out + obj.num_in_out
        regexp_txt  = rf"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += r"\s+"
        regexp_txt += ','.join([r"\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(
                f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())
        obj.datatype = ""

        if obj.num_out > 0:
            obj.args_out = operands[:obj.num_out]
            idx_args_in = obj.num_out
        elif obj.num_in_out > 0:
            obj.args_in_out = operands[:obj.num_in_out]
            idx_args_in = obj.num_in_out
        else:
            idx_args_in = 0

        obj.args_in = operands[idx_args_in:]

        if not len(obj.args_in) == obj.num_in:
            raise FatalParsingException(f"Something wrong parsing {src}: Expect {obj.num_in} input,"
                f" but got {len(obj.args_in)} ({obj.args_in})")

        return obj

    @staticmethod
    def parser(src):
        """Global factory method parsing an assembly line into an instance
        of a subclass of Instance"""
        insts = []
        exceptions = {}
        instnames = []

        src = src.strip()

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

        if len(insts) == 0:
            logging.error("Failed to parse instruction %s", src)
            logging.error("A list of attempted parsers and their exceptions follows.")
            for i,e in exceptions.items():
                msg = f"* {i + ':':20s} {e}"
                logging.error(msg)
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support for a new instruction (variant)?")

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()

class AArch64Instruction(Instruction):

    PARSERS = {}

    @staticmethod
    def _unfold_pattern(src):

        src = re.sub(r"\.",  "\\\\s*\\\\.\\\\s*", src)
        src = re.sub(r"\[", "\\\\s*\\\\[\\\\s*", src)
        src = re.sub(r"\]", "\\\\s*\\\\]\\\\s*", src)

        def pattern_transform(g):
            return \
                f"([{g.group(1).lower()}{g.group(1)}]" +\
                f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|" +\
                f"([{g.group(1).lower()}{g.group(1)}]<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"
        src = re.sub("<([BHWXVQTD])(\w+)>", pattern_transform, src)

        # Replace <key> or <key0>, <key1>, ... with pattern
        def replace_placeholders(src, mnemonic_key, regexp, group_name):
            prefix = f"<{mnemonic_key}"
            pattern = f"<{mnemonic_key}>"
            def pattern_i(i):
                return f"<{mnemonic_key}{i}>"

            cnt = src.count(prefix)
            if cnt > 1:
                for i in range(cnt):
                    src = re.sub(pattern_i(i),  f"(?P<{group_name}{i}>{regexp})", src)
            else:
                src = re.sub(pattern, f"(?P<{group_name}>{regexp})", src)

            return src

        flaglist = ["eq","ne","cs","hs","cc","lo","mi","pl","vs","vc","hi","ls","ge","lt","gt","le"]

        flag_pattern = '|'.join(flaglist)
        dt_pattern = "(?:|2|4|8|16)(?:B|H|S|D|b|h|s|d)"
        imm_pattern = "#(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"

        src = re.sub(" ", "\\\\s+", src)
        src = re.sub(",", "\\\\s*,\\\\s*", src)

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
                raise Instruction.ParsingException(f"Does not match instruction pattern {src}"\
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
        if pattern in AArch64Instruction.PARSERS:
            return AArch64Instruction.PARSERS[pattern]
        parser = AArch64Instruction._build_parser(pattern)
        AArch64Instruction.PARSERS[pattern] = parser
        return parser

    @cache
    @staticmethod
    def _infer_register_type(ptrn):
        if ptrn[0].upper() in ["X","W"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["V","Q","D"]:
            return RegisterType.Neon
        if ptrn[0].upper() in ["T"]:
            return RegisterType.Hint
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
        arg_types_in     = [AArch64Instruction._infer_register_type(r) for r in inputs]
        arg_types_out    = [AArch64Instruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [AArch64Instruction._infer_register_type(r) for r in in_outs]

        if modifiesFlags:
            arg_types_out += [RegisterType.Flags]
            outputs       += ["flags"]

        if dependsOnFlags:
            arg_types_in += [RegisterType.Flags]
            inputs += ["flags"]

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
        if ty == RegisterType.GPR:
            c = "x"
        elif ty == RegisterType.Neon:
            c = "v"
        elif ty == RegisterType.Hint:
            c = "t"
        else:
            assert False
        if s.replace('_','').isdigit():
            return f"{c}{s}"
        else:
            return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        if ty == RegisterType.GPR:
            if arg[0] != "x":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.Neon:
            if arg[0] != "v":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.Hint:
            if arg[0] != "t":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        if ty == RegisterType.Flags:
            return out
        rep = AArch64Instruction._build_pattern_replacement(s, ty, arg)
        res = out.replace(f"<{s}>", rep)
        if res == out:
            raise FatalParsingException(f"Failed to replace <{s}> by {rep} in {out}!")
        return res

    @staticmethod
    def build_core(obj, res):
        obj.args_in = []
        obj.args_in_out = []
        obj.args_out = []

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
                idxs = [ i for i in range(4) if group_name_i(i) in res.keys() ]
                if len(idxs) == 0:
                    return
                assert idxs == list(range(len(idxs)))
                setattr(obj, attr_name,
                        list(map(lambda i: f(res[group_name_i(i)]), idxs)))

        group_to_attribute('datatype', 'datatype', lambda x: x.lower())
        group_to_attribute('imm', 'immediate', lambda x:x[1:]) # Strip '#'
        group_to_attribute('index', 'index', int)
        group_to_attribute('flag', 'flag')

        for s, ty in obj.pattern_inputs:
            if ty == RegisterType.Flags:
                obj.args_in.append("flags")
            else:
                obj.args_in.append(AArch64Instruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            if ty == RegisterType.Flags:
                obj.args_out.append("flags")
            else:
                obj.args_out.append(AArch64Instruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(AArch64Instruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", [])
        outputs = getattr(c, "outputs", [])
        in_outs = getattr(c, "in_outs", [])
        modifies_flags = getattr(c,"modifiesFlags", False)
        depends_on_flags = getattr(c,"dependsOnFlags", False)

        if isinstance(src, str):
            if src.split(' ')[0] != pattern.split(' ')[0]:
                raise Instruction.ParsingException("Mnemonic does not match")
            res = AArch64Instruction.get_parser(pattern)(src)
        else:
            assert isinstance(src, dict)
            res = src

        obj = c(pattern, inputs=inputs, outputs=outputs, in_outs=in_outs,
                modifiesFlags=modifies_flags, dependsOnFlags=depends_on_flags)

        AArch64Instruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return AArch64Instruction.build(cls, src)

    def write(self):
        out = self.pattern
        l = list(zip(self.args_in, self.pattern_inputs))     + \
            list(zip(self.args_out, self.pattern_outputs))   + \
            list(zip(self.args_in_out, self.pattern_in_outs))
        for arg, (s, ty) in l:
            out = AArch64Instruction._instantiate_pattern(s, ty, arg, out)

        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x
            if t is None:
                t = t_default
            if not hasattr(self, attr_name):
                return txt
            a = getattr(self, attr_name)
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
        obj = Instruction.build(cls, src, mnemonic="qsave",
                               arg_types_in=[RegisterType.Neon],
                               arg_types_out=[RegisterType.StackNeon])
        obj.addr = "sp"
        obj.increment = None
        return obj

class qrestore(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="qrestore",
                               arg_types_in=[RegisterType.StackNeon],
                               arg_types_out=[RegisterType.Neon])
        obj.addr = "sp"
        obj.increment = None
        return obj

class save(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="save",
                               arg_types_in=[RegisterType.GPR],
                               arg_types_out=[RegisterType.StackGPR])
        obj.addr = "sp"
        obj.increment = None
        return obj

class restore(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="restore",
                               arg_types_in=[RegisterType.StackGPR],
                               arg_types_out=[RegisterType.GPR])
        obj.addr = "sp"
        obj.increment = None
        return obj

# TODO: Need to unify these
class stack_vstp_dform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vstp_dform",
                               arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                               arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_vstr_dform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vstr_dform",
                               arg_types_in=[RegisterType.Neon],
                               arg_types_out=[RegisterType.StackAny])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_stp(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_stp",
                               arg_types_in=[RegisterType.GPR, RegisterType.GPR],
                               arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_stp_wform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_stp_wform",
                               arg_types_in=[RegisterType.GPR, RegisterType.GPR],
                               arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_str(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_str",
                               arg_types_in=[RegisterType.GPR],
                               arg_types_out=[RegisterType.StackAny])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_ldr(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_ldr",
                               arg_types_in=[RegisterType.StackAny],
                               arg_types_out=[RegisterType.GPR])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_vld1r(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vld1r",
                               arg_types_in=[RegisterType.StackAny],
                               arg_types_out=[RegisterType.Neon])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_vldr_bform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vldr_bform",
                               arg_types_in=[RegisterType.StackAny],
                               arg_types_out=[RegisterType.Neon])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_vldr_dform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vldr_dform",
                               arg_types_in=[RegisterType.StackAny],
                               arg_types_out=[RegisterType.Neon])
        obj.addr = "sp"
        obj.increment = None
        return obj

class stack_vld2_lane(Instruction):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.detected_stack_vld2_lane_pair = None
        self.lane = None

    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="stack_vld2_lane",
                               arg_types_in=[RegisterType.StackAny],
                               arg_types_in_out=[RegisterType.Neon, RegisterType.Neon, RegisterType.GPR])

        regexp_txt = r"stack_vld2_lane\s+(?P<dst1>\w+)\s*,\s*(?P<dst2>\w+)\s*,\s*(?P<src1>\w+)\s*,\s*"\
            r"(?P<src2>\w+)\s*,\s*(?P<lane>.*),\s*(?P<immediate>.*)"
        regexp_txt = Instruction.unfold_abbrevs(regexp_txt)
        regexp = re.compile(regexp_txt)
        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        obj.args_in     = [p.group("src2")]
        obj.args_in_out = [p.group("dst1"), p.group("dst2"), p.group("src1")]
        obj.args_out = []

        obj.lane = p.group("lane")
        obj.immediate = p.group("immediate")

        obj.args_in_out_combinations = [
                ( [0,1], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,31) ] )
            ]

        obj.addr = p.group("src1")
        obj.increment = obj.immediate
        obj.detected_stack_vld2_lane_pair = False
        return obj

    def write(self):
        if not self.detected_stack_vld2_lane_pair:
            return f"stack_vld2_lane {self.args_in_out[0]}, {self.args_in_out[1]}, {self.args_in_out[2]}, {self.args_in[0]}, {self.lane}, {self.immediate}"
        else:
            return f"stack_vld2_lane {self.args_out[0]}, {self.args_out[1]}, {self.args_in_out[0]}, {self.args_in[0]}, {self.lane}, {self.immediate}"

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

class q_ldr_with_inc_hint(Ldr_Q):
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

class q_ldr_with_inc_writeback(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>, <imm>]!"
    inputs = ["Xc"]
    outputs = ["Qa"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

class q_ldr_with_postinc(Ldr_Q):
    pattern = "ldr <Qa>, [<Xc>], <imm>"
    inputs = ["Xc"]
    outputs = ["Qa"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

class Str_Q(AArch64Instruction):
    pass

class d_stp_sp_imm(Str_Q):
    pattern = "stp <Da>, <Db>, [sp, <imm>]"
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

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

class q_str_with_inc_hint(Str_Q):
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

class q_str_with_inc_writeback(Str_Q):
    pattern = "str <Qa>, [<Xc>, <imm>]!"
    inputs = ["Qa", "Xc"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj

class q_str_with_postinc(Str_Q):
    pattern = "str <Qa>, [<Xc>], <imm>"
    inputs = ["Qa", "Xc"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[1]
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
        assert self.pre_index == None
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

class x_ldr_with_postinc(Ldr_X):
    pattern = "ldr <Xa>, [<Xc>], <imm>"
    inputs = ["Xc"]
    outputs = ["Xa"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
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
        assert self.pre_index == None
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
    inputs = ["Xb","Th"]
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
        assert self.pre_index == None
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
    inputs = ["Xc"]
    outputs = ["Xa", "Xb"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

class x_ldp_with_postinc_writeback(Ldp_X):
    pattern = "ldp <Xa>, <Xb>, [<Xc>], <imm>"
    inputs = ["Xc"]
    outputs = ["Xa", "Xb"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

class x_ldp_with_inc_hint(Ldp_X):
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

class x_ldp_sp_with_inc_hint(Ldp_X):
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

class x_ldp_sp_with_inc_hint2(Ldp_X):
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

class x_ldp_with_inc_hint2(Ldp_X):
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
    modifiesFlags=True

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

class adds(AArch64BasicArithmetic):
    pattern = "adds <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags=True

class adds_to_zero(AArch64BasicArithmetic):
    pattern = "adds xzr, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    modifiesFlags=True

class adds_imm_to_zero(AArch64BasicArithmetic):
    pattern = "adds xzr, <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags=True

class subs_twoarg(AArch64BasicArithmetic):
    pattern = "subs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags=True

class adds_twoarg(AArch64BasicArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags=True

class adcs(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags=True
    dependsOnFlags=True

class sbcs(AArch64BasicArithmetic):
    pattern = "sbcs <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    modifiesFlags=True
    dependsOnFlags=True

class sbcs_zero(AArch64BasicArithmetic):
    pattern = "sbcs <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags=True
    dependsOnFlags=True

class sbc(AArch64BasicArithmetic):
    pattern = "sbc <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    dependsOnFlags=True

class sbc_zero_r(AArch64BasicArithmetic):
    pattern = "sbc <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags=True

class adcs_zero_r(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags=True
    dependsOnFlags=True

class adcs_zero_l(AArch64BasicArithmetic):
    pattern = "adcs <Xd>, xzr, <Xb>"
    inputs = ["Xb"]
    outputs = ["Xd"]
    modifiesFlags=True
    dependsOnFlags=True

class adc(AArch64BasicArithmetic):
    pattern = "adc <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
    dependsOnFlags=True

class adc_zero2(AArch64BasicArithmetic):
    pattern = "adc <Xd>, xzr, xzr"
    outputs = ["Xd"]
    dependsOnFlags=True

class adc_zero_r(AArch64BasicArithmetic):
    pattern = "adc <Xd>, <Xa>, xzr"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags=True

class adc_zero_l(AArch64BasicArithmetic):
    pattern = "adc <Xd>, xzr, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    dependsOnFlags=True

class add(AArch64BasicArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class add2(AArch64BasicArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class add_w_imm(AArch64BasicArithmetic):
    pattern = "add <Wd>, <Wa>, <imm>"
    inputs = ["Wa"]
    outputs = ["Wd"]

class sub(AArch64BasicArithmetic):
    pattern = "sub <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class AArch64ShiftedArithmetic(AArch64Instruction):
    pass

class add_lsl(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class add_lsr(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, lsr <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class adds_lsl(AArch64ShiftedArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]
    modifiesFlags=True

class adds_lsr(AArch64ShiftedArithmetic):
    pattern = "adds <Xd>, <Xa>, <Xb>, lsr <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]
    modifiesFlags=True

class add_asr(AArch64ShiftedArithmetic):
    pattern = "add <Xd>, <Xa>, <Xb>, asr <imm>"
    inputs = ["Xa","Xb"]
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
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class orr(AArch64Logical):
    pattern = "orr <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class orr_w(AArch64Logical):
    pattern = "orr <Wd>, <Wa>, <Wb>"
    inputs = ["Wa","Wb"]
    outputs = ["Wd"]

class bfi(AArch64Logical):
    pattern = "bfi <Xd>, <Xa>, <imm0>, <imm1>"
    inputs = ["Xa"]
    in_outs=["Xd"]

class and_imm(AArch64Logical):
    pattern = "and <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class ands_imm(AArch64Logical):
    pattern = "ands <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]
    modifiesFlags=True

class ands_xzr_imm(AArch64Logical):
    pattern = "ands xzr, <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags=True

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

class extr(AArch64Logical): ### TODO! Review this...
    pattern = "extr <Xd>, <Xa>, <Xb>, <imm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class AArch64LogicalShifted(AArch64Instruction):
    pass

class orr_shifted(AArch64LogicalShifted):
    pattern = "orr <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class AArch64ConditionalCompare(AArch64Instruction):
    pass

class ccmp_xzr(AArch64ConditionalCompare):
    pattern = "ccmp <Xa>, xzr, <imm>, <flag>"
    inputs = ["Xa"]
    modifiesFlags=True
    dependsOnFlags=True

class ccmp(AArch64ConditionalCompare):
    pattern = "ccmp <Xa>, <Xb>, <imm>, <flag>"
    inputs = ["Xa", "Xb"]
    modifiesFlags=True
    dependsOnFlags=True

class AArch64ConditionalSelect(AArch64Instruction):
    pass

class cneg(AArch64ConditionalSelect):
    pattern = "cneg <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags=True

class csel_xzr_ne(AArch64ConditionalSelect):
    pattern = "csel <Xd>, <Xe>, xzr, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags=True

class csel_ne(AArch64ConditionalSelect):
    pattern = "csel <Xd>, <Xe>, <Xf>, <flag>"
    inputs = ["Xe", "Xf"]
    outputs = ["Xd"]
    dependsOnFlags=True

class cinv(AArch64ConditionalSelect):
    pattern = "cinv <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags=True

class cinc(AArch64ConditionalSelect):
    pattern = "cinc <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags=True

class csetm(AArch64ConditionalSelect):
    pattern = "csetm <Xd>, <flag>"
    outputs = ["Xd"]
    dependsOnFlags=True

class cset(AArch64ConditionalSelect):
    pattern = "cset <Xd>, <flag>"
    outputs = ["Xd"]
    dependsOnFlags=True

class cmn_imm(AArch64ConditionalSelect):
    pattern = "cmn <Xd>, <imm>"
    inputs = ["Xd"]
    modifiesFlags=True

class ldr_const(AArch64Instruction):
    pattern = "ldr <Xd>, <imm>"
    inputs = []
    outputs = ["Xd"]

class movk_imm(AArch64Instruction):
    pattern = "movk <Xd>, <imm>"
    inputs = []
    in_outs=["Xd"]

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
    inputs = ["Wa","Wb"]
    outputs = ["Xd"]

class umaddl_wform(AArch64Instruction):
    pattern = "umaddl <Xn>, <Wa>, <Wb>, <Xacc>"
    inputs = ["Wa","Wb","Xacc"]
    outputs = ["Xn"]

class mul_wform(AArch64Instruction):
    pattern = "mul <Wd>, <Wa>, <Wb>"
    inputs = ["Wa","Wb"]
    outputs = ["Wd"]

class AArch64HighMultiply(AArch64Instruction):
    pass

class umulh_xform(AArch64HighMultiply):
    pattern = "umulh <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class smulh_xform(AArch64HighMultiply):
    pattern = "smulh <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class AArch64Multiply(AArch64Instruction):
    pass

class mul_xform(AArch64Multiply):
    pattern = "mul <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class madd_xform(AArch64Multiply):
    pattern = "madd <Xd>, <Xacc>, <Xa>, <Xb>"
    inputs = ["Xacc", "Xa","Xb"]
    outputs = ["Xd"]

class mneg_xform(AArch64Multiply):
    pattern = "mneg <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class msub_xform(AArch64Multiply):
    pattern = "msub <Xd>, <Xacc>, <Xa>, <Xb>"
    inputs = ["Xacc", "Xa","Xb"]
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
    modifiesFlags=True

class tst_imm_xform(Tst):
    pattern = "tst <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags=True

class tst_xform(Tst):
    pattern = "tst <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    modifiesFlags=True

class cmp_xzr(Tst):
    pattern = "cmp <Xa>, xzr"
    inputs = ["Xa"]
    modifiesFlags=True

class cmp_imm(Tst):
    pattern = "cmp <Xa>, <imm>"
    inputs = ["Xa"]
    modifiesFlags=True

######################################################
#                                                    #
# Some 'wrappers' around AArch64 Neon instructions   #
#                                                    #
######################################################

# We don't model the sometimes complex syntax of AArch64 Neon instructions here,
# but instead use simpler syntax forms which are translated into the actual AArch64
# instructions through assembly `.macro`s.
#
# We use the Helium/AArch32 Neon naming for those wrappers.

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

class vzip1(AArch64Instruction):
    pattern = "zip1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vzip2(AArch64Instruction):
    pattern = "zip2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vuzp1(AArch64Instruction):
    pattern = "uzp1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vuzp2(AArch64Instruction):
    pattern = "uzp2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vqrdmulh(AArch64Instruction):
    pattern = "sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vqrdmulh_lane(AArch64Instruction):
    pattern = "sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]
        return obj

class vqdmulh_lane(AArch64Instruction):
    pattern = "sqdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

        return obj

class vmul_lane(AArch64Instruction):
    pattern = "mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

        return obj

class fcsel_dform(Instruction):
    @classmethod
    def make(cls, src):
        obj = Instruction.build(cls, src, mnemonic="fcsel_dform",
                         arg_types_in=[RegisterType.Neon, RegisterType.Neon, RegisterType.Flags],
                         arg_types_out=[RegisterType.Neon])

        regexp_txt = r"fcsel_dform\s+(?P<dst>\w+)\s*,\s*(?P<src1>\w+)\s*,\s*(?P<src2>\w+)\s*,\s*eq"
        regexp_txt = Instruction.unfold_abbrevs(regexp_txt)
        regexp = re.compile(regexp_txt)
        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        obj.args_in     = [ p.group("src1"), p.group("src2"), "flags" ]
        obj.args_out    = [ p.group("dst") ]
        obj.args_in_out = []

        return obj

    def write(self):
        return f"fcsel_dform {self.args_out[0]}, {self.args_in[0]}, {self.args_in[1]}, eq"

class Vins(AArch64Instruction):
    pass

class vins_d(Vins):
    pattern = "ins <Vd>.d[<index>], <Xa>"
    inputs = ["Xa"]
    in_outs=["Vd"]

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
    in_outs=["Vd"]

class mov_xtov_d_xzr(Mov_xtov_d):
    pattern = "mov <Vd>.d[<index>], xzr"
    in_outs=["Vd"]

class mov_b00(AArch64Instruction): # TODO: Generalize
    pattern = "mov <Vd>.b[0], <Va>.b[0]"
    inputs = ["Va"]
    in_outs=["Vd"]

class mov_d01(AArch64Instruction): # TODO: Generalize
    pattern = "mov <Vd>.d[0], <Va>.d[1]"
    inputs = ["Va"]
    in_outs=["Vd"]

class AArch64NeonLogical(AArch64Instruction):
    pass

class veor(AArch64NeonLogical):
    pattern = "eor <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class veor3(AArch64Instruction):
    pattern = "eor3 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <Vc>.<dt3>"
    inputs = ["Va", "Vb", "Vc"]
    outputs = ["Vd"]

class vbif(AArch64NeonLogical):
    pattern = "bif <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs=["Vd"]

# Not sure about the classification as logical... couldn't find it in SWOG
class vmov_d(AArch64NeonLogical):
    pattern = "mov <Dd>, <Va>.d[1]"
    inputs = ["Va"]
    outputs = ["Dd"]

class vext(AArch64NeonLogical):
    pattern = "ext <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <imm>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vmul(AArch64Instruction):
    pattern = "mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vmla(AArch64Instruction):
    pattern = "mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs=["Vd"]

class vmla_lane(AArch64Instruction):
    pattern = "mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    in_outs=["Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]
        return obj

class vmls(AArch64Instruction):
    pattern = "mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs = ["Vd"]

class vmls_lane(AArch64Instruction):
    pattern = "mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]"
    inputs = ["Va", "Vb"]
    in_outs=["Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        if obj.datatype[0] == "8h":
            obj.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]
        return obj

class vdup(AArch64Instruction):
    pattern = "dup <Vd>.<dt>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]

class vmull(AArch64Instruction):
    pattern = "umull <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class vmlal(AArch64Instruction):
    pattern = "umlal <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    in_outs=["Vd"]

class vsrshr(AArch64Instruction):
    pattern = "srshr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]

class vshl(AArch64Instruction):
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
    in_outs=["Vd"]

class vusra(AArch64Instruction):
    pattern = "usra <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    in_outs=["Vd"]

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
    in_outs=["Dd"]

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
    in_outs=["Vd"]

class fmov_1_force_output(Fmov):
    pattern = "fmov <Vd>.d[1], <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]
    @classmethod
    def make(cls, src, force=False):
        if force is False:
            raise Instruction.ParsingException("Instruction ignored")
        return AArch64Instruction.build(cls, src)

class vushr(AArch64Instruction):
    pattern = "ushr <Vd>.<dt0>, <Va>.<dt1>, <imm>"
    inputs = ["Va"]
    outputs = ["Vd"]

class trn1(AArch64Instruction):
    pattern = "trn1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>"
    inputs = ["Va", "Vb"]
    outputs = ["Vd"]

class trn2(AArch64Instruction):
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
    in_outs=["Vd"]

class aese(AESInstruction):
    pattern = "aese <Vd>.16b, <Va>.16b"
    inputs = ["Va"]
    in_outs=["Vd"]

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
        assert self.pre_index == None
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

class x_str_postinc(Str_X):
    pattern = "str <Xa>, [<Xc>], <imm>"
    inputs = ["Xa", "Xc"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj

class x_str_sp_imm(Str_X):
    pattern = "str <Xa>, [sp, <imm>]"
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

class x_str_sp_imm_hint(Str_X):
    pattern = "strh <Xa>, sp, <imm>, <Th>"
    inputs = ["Xa"],
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
        return

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the STP with increment.
        assert self.pre_index == None
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
    inputs = ["Xc", "Xa", "Xb"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in[0]
        return obj

class x_stp_with_inc_hint(Stp_X):
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

class x_stp_sp_with_inc_hint(Stp_X):
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

class x_stp_sp_with_inc_hint2(Stp_X):
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

class x_stp_with_inc_hint2(Stp_X):
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
        obj.addr = obj.args_in[0]
        obj.args_in_combinations = [
                ( [1,2,3,4], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
            ]
        return obj

class st4_with_inc(St4):
    pattern = "st4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>], <imm>"
    inputs = ["Xc", "Va", "Vb", "Vc", "Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_in_combinations = [
                ( [1,2,3,4], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
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
        obj.addr = obj.args_in[0]
        obj.args_in_combinations = [
                ( [1,2,3,4], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,30) ] )
            ]
        return obj

class st2_with_inc(St2):
    pattern = "st2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>], <imm>"
    inputs = ["Xc", "Va", "Vb"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_in_combinations = [
                ( [1,2,3,4], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,30) ] )
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
        obj.addr = obj.args_in[0]
        obj.args_out_combinations = [
                ( [0,1,2,3], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
            ]
        return obj

class ld4_with_inc(Ld4):
    pattern = "ld4 {<Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>, <Vd>.<dt3>}, [<Xc>], <imm>"
    inputs = ["Xc"]
    outputs = ["Va", "Vb", "Vc", "Vd"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_out_combinations = [
                ( [0,1,2,3], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
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
        obj.addr = obj.args_in[0]
        obj.args_out_combinations = [
                ( [0,1,2,3], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,30) ] )
            ]
        return obj

class ld2_with_inc(Ld2):
    pattern = "ld2 {<Va>.<dt0>, <Vb>.<dt1>}, [<Xc>], <imm>"
    inputs = ["Xc"]
    outputs = ["Va", "Vb"]
    @classmethod
    def make(cls, src):
        obj = AArch64Instruction.build(cls, src)
        obj.addr = obj.args_in[0]
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_out_combinations = [
                ( [0,1,2,3], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,30) ] )
            ]

        return obj

# In a pair of vins writing both 64-bit lanes of a vector, mark the
# target vector as output rather than input/output. This enables further
# renaming opportunities.
def vins_d_parsing_cb():
    def core(inst, t, log=None):
        succ = None
        # Check if this is the first in a pair of vins+vins
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, vins_d):
                if r.inst.args_in_out == inst.args_in_out and \
                   {r.inst.index, inst.index} == {0,1}:
                    succ = r
        if succ is None:
            return False
        # Reparse as instruction-variant treating the input/output as an output
        inst_txt = t.inst.write()
        t.inst = vins_d_force_output.make(inst_txt, force=True)
        t.changed = True
        return True
    return core
vins_d.global_parsing_cb = vins_d_parsing_cb()

# In a pair of fmov writing both 64-bit lanes of a vector, mark the
# target vector as output rather than input/output. This enables further
# renaming opportunities.
def fmov_0_parsing_cb():
    def core(inst, t, log=None):
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
        inst_txt = t.inst.write()
        t.inst = fmov_0_force_output.make(inst_txt, force=True)
        t.changed = True
        return True
    return core
fmov_0.global_parsing_cb = fmov_0_parsing_cb()

def fmov_1_parsing_cb():
    def core(inst, t, log=None):
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
        inst_txt = t.inst.write()
        t.inst = fmov_1_force_output.make(inst_txt, force=True)

        t.changed = True
        return True
    return core
fmov_1.global_parsing_cb = fmov_1_parsing_cb()

def stack_vld2_lane_parsing_cb():
    def core(inst,t, log=None):
        succ = None

        if inst.detected_stack_vld2_lane_pair:
            return False

        # Check if this is the first in a pair of stack_vld2_lane+stack_vld2_lane
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, stack_vld2_lane):
                if r.inst.args_in_out[:2] == inst.args_in_out[:2] and \
                   {r.inst.lane, inst.lane} == {'0','1'}:
                    succ = r

        if succ is None:
            return False

        # If so, mark in/out as output only, and signal the need for re-building
        # the dataflow graph

        inst.num_out = 2
        inst.args_out = [ inst.args_in_out[0], inst.args_in_out[1] ]
        inst.arg_types_out = [ RegisterType.Neon, RegisterType.Neon ]
        inst.args_out_restrictions = inst.args_in_out_restrictions[:2]
        inst.args_out_combinations = inst.args_in_out_combinations[:2]

        inst.num_in_out = 1
        inst.args_in_out = [ inst.args_in_out[2] ]
        inst.arg_types_in_out = [ RegisterType.GPR ]
        inst.args_in_out_restrictions = [None]
        inst.args_in_out_combinations = None

        inst.detected_stack_vld2_lane_pair = True

        t.changed = True
        return True

    return core

stack_vld2_lane.global_parsing_cb  = stack_vld2_lane_parsing_cb()

def eor3_fusion_cb():
    def core(inst,t,log=None):
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
        if r.reg_state[a] != t.reg_state[a] and not \
            (r.reg_state[a].src == t and t.reg_state[a].idx == 0):
            if log is not None:
                log(f"NOTE: Skipping potential EOR3 fusion for ({t}:{r}) because {a} is modified by {r.reg_state[a]} in the interim.")
            return False
        if r.reg_state[b] != t.reg_state[b] and not \
            (r.reg_state[b].src == t and t.reg_state[b].idx == 0):
            if log is not None:
                log(f"NOTE: Skipping potential EOR3 fusion for ({t}:{r}) because {b} is modified by {r.reg_state[b]} in the interim.")
            return False

        new_inst = AArch64Instruction.build(veor3, { "Vd": d, "Va" : a, "Vb" : b, "Vc" : c,
                                                     "datatype0":"16b",
                                                     "datatype1":"16b",
                                                     "datatype2":"16b",
                                                     "datatype3":"16b" })

        if log is not None:
            log(f"EOR3 fusion: {t.inst}; {r.inst} ~> {new_inst}")

        # If so, delete first note, and reparse second as eor3
        t.delete = True
        r.changed = True
        r.inst = new_inst
        return True

    return core

veor.global_fusion_cb  = eor3_fusion_cb()

def iter_aarch64_instructions():
    yield from all_subclass_leaves(Instruction)

def find_class(src):
    for inst_class in iter_aarch64_instructions():
        if isinstance(src,inst_class):
            return inst_class
    raise UnknownInstruction(f"Couldn't find instruction class for {src} (type {type(src)})")

def is_dt_form_of(instr_class, dts=None):
    if not isinstance(instr_class, list):
        instr_class = [instr_class]
    def _intersects(lsA,lsB):
        return len([a for a in lsA if a in lsB]) > 0
    def _check_instr_dt(src):
        if find_class(src) in instr_class:
            if dts is None or _intersects(src.datatype, dts):
                return True
        return False
    return _check_instr_dt

def is_dform_form_of(instr_class):
    return is_dt_form_of(instr_class, ["1d","2s","4h","8b"])
def is_qform_form_of(instr_class):
    return is_dt_form_of(instr_class, ["2d","4s","8h","16b"])

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
    return RegisterType.Neon in args


# Returns the list of all subclasses of a class which don't have
# subclasses themselves
def all_subclass_leaves(c):

    def has_subclasses(cl):
        return len(cl.__subclasses__()) > 0
    def is_leaf(c):
        return not has_subclasses(c)

    def all_subclass_leaves_core(leaf_lst, todo_lst):
        leaf_lst += filter(is_leaf, todo_lst)
        todo_lst = [ csub
                     for c in filter(has_subclasses, todo_lst)
                     for csub in c.__subclasses__() ]
        if len(todo_lst) == 0:
            return leaf_lst
        return all_subclass_leaves_core(leaf_lst, todo_lst)

    return all_subclass_leaves_core([], [c])

Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)

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
            assert callable(x)
            return x(inst)
        if not isinstance(l, tuple):
            l = [l]
        for lp in l:
            if match(lp):
                return v
    if default == None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

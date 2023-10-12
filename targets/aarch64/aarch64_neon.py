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
import re
import math

from sympy import simplify
from enum import Enum

no_simplify = False

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

    def from_string(string):
        string = string.lower()
        return { "qstack"   : RegisterType.StackNeon,
                 "stack"    : RegisterType.StackGPR,
                 "stackany" : RegisterType.StackAny,
                 "neon"     : RegisterType.Neon,
                 "gpr"      : RegisterType.GPR,
                 "hint"     : RegisterType.Hint,
                 "flags"    : RegisterType.Flags}.get(string,None)

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

    def default_aliases():
        return {}

class Loop:

    def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr"):
        self.lbl_start = lbl_start
        self.lbl_end   = lbl_end
        self.loop_init = loop_init
        pass

    ### FIXME This is very adhoc
    def start(self,indentation=0, fixup=0, unroll=1):
        indent = ' ' * indentation
        if unroll > 1:
            if not unroll in [1,2,4,8,16,32]:
                raise Exception("unsupported unrolling")
            yield f"{indent}lsr count, count, #{int(math.log2(unroll))}"
        if fixup != 0:
            yield f"{indent}sub count, count, #{fixup}"
        yield f".p2align 2"
        yield f"{self.lbl_start}:"

    def end(self,other, indentation=0):
        (reg0, reg1, imm) = other
        indent = ' ' * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"

        yield f"{indent}sub {reg0}, {reg1}, {imm}"
        yield f"{indent}cbnz {reg0}, {lbl_start}"

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
        loop_lbl_regexp_txt = f"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)

        # TODO: Allow other forms of looping

        loop_end_regexp_txt = (f"^\s*sub[s]?\s+(?P<reg0>\w+),\s*(?P<reg1>\w+),\s*(?P<imm>#1)",
                               f"^\s*(cbnz|bnz|bne)\s+(?P<reg0>\w+),\s*{lbl}")
        loop_end_regexp = [re.compile(txt) for txt in loop_end_regexp_txt]
        lines = iter(source.splitlines())
        l = None
        keep = False
        state = 0 # 0: haven't found loop yet, 1: extracting loop, 2: after loop
        while True:
            if not keep:
                l = next(lines, None)
            keep = False
            if l == None:
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
            raise Exception(f"Couldn't identify loop {lbl}")
        return pre, body, post, lbl, (reg0, reg1, imm)

class Instruction:

    class ParsingException(Exception):
        def __init__(self, err=None):
            super().__init__(err)

    def __init__(self, *, mnemonic,
                 arg_types_in= None, arg_types_in_out = None, arg_types_out = None):

        if not arg_types_in:
            arg_types_in = []
        if not arg_types_out:
            arg_types_out = []
        if not arg_types_in_out:
            arg_types_in_out = []

        arg_types_all = arg_types_in + arg_types_in_out + arg_types_out
        def isinstancelist(l, c):
            return all( map( lambda e: isinstance(e,c), l ) )
        assert isinstancelist(arg_types_all, RegisterType)

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

    def global_parsing_cb(self,a,b):
        return False

    def write(self):
        args = self.args_out + self.args_in_out + self.args_in
        mnemonic = re.sub("<dt>", self.datatype, self.mnemonic)
        return mnemonic + ' ' + ', '.join(args)

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
                                      ldr_vo_wrapper, ldr_vi_wrapper,
                                      str_vi_wrapper, str_vo_wrapper,
                                      stack_vld1r])
        if self.datatype == "":
            return False
        if self.datatype[0].lower() in ["2d", "4s", "8h", "16b"]:
            return True
        if self.datatype[0].lower() in ["1d", "2s", "4h", "8b"]:
            return False
        raise Exception(f"unknown datatype {self.datatype}")

    def is_vector_mul(self):
        return self._is_instance_of([ vmul, vmul_lane,
                                      vmla, vmls_lane, vmls,
                                      vqrdmulh, vqrdmulh_lane, vqdmulh_lane,
                                      vmull, vmlal ])
    def is_vector_add_sub(self):
        return self._is_instance_of([ vadd, vsub ])
    def is_vector_load(self):
        return self._is_instance_of([ vldr, ldr_vi_wrapper, ldr_vo_wrapper,
                                      v_ldr, v_ldr_with_inc,
                                      v_ldr_with_inc_hint, v_ldr_with_inc_writeback])
    def is_vector_store(self):
        return self._is_instance_of([ vstr, str_vi_wrapper, str_vo_wrapper, st4,
         stack_vstp_dform, stack_vstr_dform])
    def is_vector_stack_load(self):
        return self._is_instance_of([stack_vld1r, stack_vldr_bform, stack_vldr_dform,
        stack_vld2_lane])
    def is_vector_stack_store(self):
        return self._is_instance_of([])

    # scalar
    def is_scalar_load(self):
        return self._is_instance_of([ Ldr_X, Ldp_X,
                                      ldr_idx_wform ])
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

    def parse(self, src):
        """Assumes format 'mnemonic [in]out0, .., [in]outN, in0, .., inM"""
        src = re.sub("//.*$","",src)

        have_dt = ( "<dt>" in self.mnemonic ) or ( "<fdt>" in self.mnemonic )

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
        regexp_txt  = f"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += "\s+"
        regexp_txt += ','.join(["\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())
        if have_dt:
            operands = operands[1:]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype").lower()

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[:self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[:self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:]

        if not len(self.args_in) == self.num_in:
            raise Exception(f"Something wrong parsing {src}: Expect {self.num_in} input, but got {len(self.args_in)} ({self.args_in})")

    def parser(src):
        insts = []
        exceptions = {}
        instnames = []

        # Iterate through all derived classes and call their parser
        # until one of them hopefully succeeds
        for inst_class in all_subclass_leaves(Instruction):
            inst = inst_class()
            try:
                inst.parse(src)
                instnames.append(inst_class.__name__)
                insts.append(inst)
            except Instruction.ParsingException as e:
                exceptions[inst_class.__name__] = e
        if len(insts) == 0:
            logging.error(f"Failed to parse instruction {src}")
            logging.error("A list of attempted parsers and their exceptions follows.")
            for i,e in exceptions.items():
                logging.error(f"* {i + ':':20s} {e}")
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support for a new instruction (variant)?")

        logging.debug(f"Parsing result for '{src}': {instnames}")
        return insts

    def __repr__(self):
        return self.write()

class AArch64Instruction(Instruction):

    PARSERS = {}

    def _unfold_pattern(src):

        src = re.sub("\.",  "\\\\s*\\\\.\\\\s*", src)
        src = re.sub("\[", "\\\\s*\\\\[\\\\s*", src)
        src = re.sub("\]", "\\\\s*\\\\]\\\\s*", src)

        def pattern_transform(g):
            return \
                f"([{g.group(1).lower()}{g.group(1)}]" +\
                f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|" +\
                f"([{g.group(1).lower()}{g.group(1)}]<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"
        src = re.sub("<([BHWXVQT])(\w+)>", pattern_transform, src)

        if src.count("<dt") > 1:
            for i in range(src.count("<dt")):
                src = re.sub(f"<dt{i}>",  f"(?P<datatype{i}>(?:|2|4|8|16)(?:B|H|S|D|b|h|s|d))", src)
        else:
            src = re.sub(f"<dt>",  f"(?P<datatype>(?:2|4|8|16)(?:B|H|S|D|b|h|s|d))", src)

        flaglist = ["eq","ne","cs","hs","cc","lo","mi","pl","vs","vc","hi","ls","ge","lt","gt","le"]
        imm_pattern = "(\\\\w|\\\\s|-|\*|\+|\(|\)|=|,)+"

        src = re.sub(" ", "\\\\s+", src)
        src = re.sub(",", "\\\\s*,\\\\s*", src)
        src = re.sub("<imm>",  f"#(?P<imm>{imm_pattern})",  src)
        src = re.sub("<imm0>", f"#(?P<imm0>{imm_pattern})", src)
        src = re.sub("<imm1>", f"#(?P<imm1>{imm_pattern})", src)
        src = re.sub("<flag>", f"(?P<flag>{'|'.join(flaglist)})", src)
        src = re.sub("<index>", "(?P<index>[0-9]+)", src)
        src = "\\s*" + src + "\\s*(//.*)?\Z"

        return src

    def _build_parser(src):
        regexp_txt = AArch64Instruction._unfold_pattern(src)
        regexp = re.compile(regexp_txt)
        # print(f"Pattern: {src}")
        # print(f"Regexp: {regexp_txt}")
        # print(f"Compiled...")
        def _parse(line):
            regexp_result = regexp.match(line)
            if regexp_result == None:
                raise Instruction.ParsingException(f"Does not match instruction pattern {src}"\
                                                   f"[regex: {regexp_txt}]")
            res = regexp.match(line).groupdict()
            items = list(res.items())
            for k, v in items:
                for l in ["symbol_", "raw_"]:
                    if k.startswith(l):
                        del res[k]
                        if v == None:
                            continue
                        k = k[len(l):]
                        res[k] = v
            return res
        return _parse

    def get_parser(pattern):
        if pattern in AArch64Instruction.PARSERS.keys():
            return AArch64Instruction.PARSERS[pattern]
        parser = AArch64Instruction._build_parser(pattern)
        AArch64Instruction.PARSERS[pattern] = parser
        return parser

    def infer_register_type(ptrn):
        if ptrn[0].upper() in ["X","W"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["V","Q"]:
            return RegisterType.Neon
        if ptrn[0].upper() in ["T"]:
            return RegisterType.Hint
        raise Exception(f"Unknown pattern: {ptrn}")

    def __init__(self, pattern, *, inputs=None, outputs=None, in_outs=None, modifiesFlags=False,
                 dependsOnFlags=False, force_equal=None):
        if force_equal == None:
            force_equal = []
        if not inputs:
            inputs = []
        if not outputs:
            outputs = []
        if not in_outs:
            in_outs = []
        arg_types_in     = [AArch64Instruction.infer_register_type(r) for r in inputs]
        arg_types_out    = [AArch64Instruction.infer_register_type(r) for r in outputs]
        arg_types_in_out = [AArch64Instruction.infer_register_type(r) for r in in_outs]

        assert len(arg_types_in) == len(inputs)
        assert len(arg_types_out) == len(outputs)
        assert len(arg_types_in_out) == len(in_outs)

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

        self._force_equal = force_equal

        self.pattern = pattern
        self.pattern_inputs = list(zip(inputs, arg_types_in))
        self.pattern_outputs = list(zip(outputs, arg_types_out))
        self.pattern_in_outs = list(zip(in_outs, arg_types_in_out))

        assert len(self.pattern_inputs) == len(inputs)
        assert len(self.pattern_outputs) == len(outputs)
        assert len(self.pattern_in_outs) == len(in_outs)

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
        raise Exception(f"Unknown register type ({s}, {ty}, {arg})")

    def _instantiate_pattern(s, ty, arg, out):
        if ty == RegisterType.Flags:
            return out
        rep = AArch64Instruction._build_pattern_replacement(s, ty, arg)
        res = out.replace(f"<{s}>", rep)
        if res == out:
            raise Exception(f"Failed to replace <{s}> by {rep} in {out}!")
        return res

    def parse(self, src):
        res = AArch64Instruction.get_parser(self.pattern)(src)
        self.args_in = []
        self.args_in_out = []
        self.args_out = []

        for (r0, r1) in self._force_equal:
            if res[r0] != res[r1]:
                raise Instruction.ParsingException(f"Arguments {r0} and {r1} must be equal")

        if 'datatype' in res:
            self.datatype = res['datatype'].lower()
        else:
            if 'datatype0' in res:
                self.datatype = [res['datatype0'].lower()]
            if 'datatype1' in res:
                self.datatype += [res['datatype1'].lower()]
            if 'datatype2' in res:
                self.datatype += [res['datatype2'].lower()]

        if 'index' in res:
            self.index = int(res['index'])

        if 'imm' in res:
            self.immediate = res['imm']
        if 'imm0' in res:
            self.immediate0 = res['imm0']
        if 'imm1' in res:
            self.immediate1 = res['imm1']
        if 'flag' in res:
            self.flag = res['flag']
        for s, ty in self.pattern_inputs:
            if ty == RegisterType.Flags:
                self.args_in.append("flags")
            else:
                self.args_in.append(AArch64Instruction._to_reg(ty, res[s]))
        for s, ty in self.pattern_outputs:
            if ty == RegisterType.Flags:
                self.args_out.append("flags")
            else:
                self.args_out.append(AArch64Instruction._to_reg(ty, res[s]))
        for s, ty in self.pattern_in_outs:
            self.args_in_out.append(AArch64Instruction._to_reg(ty, res[s]))

    def write(self):
        out = self.pattern
        l = list(zip(self.args_in, self.pattern_inputs))     + \
            list(zip(self.args_out, self.pattern_outputs))   + \
            list(zip(self.args_in_out, self.pattern_in_outs))
        if len(l) == 0:
            print("SOMETHING WRONG!")
            print(self.pattern)
            print(f"Inputs: {self.inputs}")
            print(f"Inputs: {self.outputs}")
            print(f"Inputs: {self.in_outs}")
            print(f"pattern Inputs: {list(self.pattern_inputs)}")
            print(f"pattern Inputs: {list(self.pattern_outputs)}")
            print(f"pattern Inputs: {list(self.pattern_in_outs)}")
            assert False
        for arg, (s, ty) in l:
            out = AArch64Instruction._instantiate_pattern(s, ty, arg, out)
        if hasattr(self, "immediate"):
            out = out.replace("<imm>", f"#{self.immediate}")
        if hasattr(self, "immediate0"):
            out = out.replace("<imm0>", f"#{self.immediate0}")
        if hasattr(self, "immediate1"):
            out = out.replace("<imm1>", f"#{self.immediate1}")
        if hasattr(self, "flag"):
            out = out.replace("<flag>", f"{self.flag}")

        if hasattr(self, "datatype"):
            if isinstance(self.datatype, list):
                for i in range(len(self.datatype)):
                    out = out.replace(f"<dt{i}>", self.datatype[i].upper())
            else:
                out = out.replace("<dt>", self.datatype.upper())

        if hasattr(self,"index"):
            out = out.replace("<index>", str(self.index))

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

####################################################################################
#                                                                                  #
# Virtual instruction to model pushing to stack locations without modelling memory #
#                                                                                  #
####################################################################################

class qsave(Instruction):
    def __init__(self):
        super().__init__(mnemonic="qsave",
                         arg_types_in=[RegisterType.Neon],
                         arg_types_out=[RegisterType.StackNeon])
        self.addr = "sp"
        self.increment = None

class qrestore(Instruction):
    def __init__(self):
        super().__init__(mnemonic="qrestore",
                         arg_types_in=[RegisterType.StackNeon],
                         arg_types_out=[RegisterType.Neon])
        self.addr = "sp"
        self.increment = None
class save(Instruction):
    def __init__(self):
        super().__init__(mnemonic="save",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_out=[RegisterType.StackGPR])
        self.addr = "sp"
        self.increment = None
class restore(Instruction):
    def __init__(self):
        super().__init__(mnemonic="restore",
                         arg_types_in=[RegisterType.StackGPR],
                         arg_types_out=[RegisterType.GPR])
        self.addr = "sp"
        self.increment = None

# TODO: Need to unify these
class stack_vstp_dform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vstp_dform",
                         arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                         arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        self.addr = "sp"
        self.increment = None

class stack_vstr_dform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vstr_dform",
                         arg_types_in=[RegisterType.Neon],
                         arg_types_out=[RegisterType.StackAny])
        self.addr = "sp"
        self.increment = None

class stack_stp(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_stp",
                         arg_types_in=[RegisterType.GPR, RegisterType.GPR],
                         arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        self.addr = "sp"
        self.increment = None

class stack_stp_wform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_stp_wform",
                         arg_types_in=[RegisterType.GPR, RegisterType.GPR],
                         arg_types_out=[RegisterType.StackAny, RegisterType.StackAny])
        self.addr = "sp"
        self.increment = None


class stack_str(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_str",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_out=[RegisterType.StackAny])
        self.addr = "sp"
        self.increment = None

class stack_ldr(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_ldr",
                         arg_types_in=[RegisterType.StackAny],
                         arg_types_out=[RegisterType.GPR])
        self.addr = "sp"
        self.increment = None

class stack_vld1r(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vld1r",
                         arg_types_in=[RegisterType.StackAny],
                         arg_types_out=[RegisterType.Neon])
        self.addr = "sp"
        self.increment = None

class stack_vldr_bform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vldr_bform",
                         arg_types_in=[RegisterType.StackAny],
                         arg_types_out=[RegisterType.Neon])
        self.addr = "sp"
        self.increment = None

class stack_vldr_dform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vldr_dform",
                         arg_types_in=[RegisterType.StackAny],
                         arg_types_out=[RegisterType.Neon])
        self.addr = "sp"
        self.increment = None



class stack_vld2_lane(Instruction):
    def __init__(self):
        super().__init__(mnemonic="stack_vld2_lane",
                         arg_types_in=[RegisterType.StackAny],
                         arg_types_in_out=[RegisterType.Neon, RegisterType.Neon, RegisterType.GPR])

    def parse(self, src):
        regexp_txt = "stack_vld2_lane\s+(?P<dst1>\w+)\s*,\s*(?P<dst2>\w+)\s*,\s*(?P<src1>\w+)\s*,\s*(?P<src2>\w+)\s*,\s*(?P<lane>.*),\s*(?P<immediate>.*)"
        regexp_txt = Instruction.unfold_abbrevs(regexp_txt)
        regexp = re.compile(regexp_txt)
        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in     = [p.group("src2")]
        self.args_in_out = [p.group("dst1"), p.group("dst2"), p.group("src1")]
        self.args_out = []

        self.lane = p.group("lane")
        self.immediate = p.group("immediate")

        self.args_in_out_combinations = [
                ( [0,1], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,31) ] )
            ]

        self.addr = p.group("src1")
        self.increment = self.immediate
        self.detected_stack_vld2_lane_pair = False

    def write(self):
        if not self.detected_stack_vld2_lane_pair:
            return f"stack_vld2_lane {self.args_in_out[0]}, {self.args_in_out[1]}, {self.args_in_out[2]}, {self.args_in[0]}, {self.lane}, {self.immediate}"
        else:
            return f"stack_vld2_lane {self.args_out[0]}, {self.args_out[1]}, {self.args_in_out[0]}, {self.args_in[0]}, {self.lane}, {self.immediate}"

####################################################################################
#                                                                                  #
# WORK IN PROGRESS                                                                 #
# The instructions below are meant to directly model AArch64 instructions, but     #
# they don't really because various details are not modelled, such as q-form vs.   #
# v-form, or width specifiers.                                                     #
#                                                                                  #
####################################################################################


class nop(Instruction):
    def __init__(self):
        super().__init__(mnemonic="nop")

class vadd(AArch64Instruction):
    def __init__(self):
        super().__init__("add <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>",
                         inputs=["Vb", "Vc"],
                         outputs=["Va"])

class vsub(AArch64Instruction):
    def __init__(self):
        super().__init__("sub <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>",
                         inputs=["Vb", "Vc"],
                         outputs=["Va"])

############################
#                          #
# Some LSU instructions    #
#                          #
############################

class v_ldr(AArch64Instruction):
    def __init__(self):
        super().__init__("ldr <Qa>, [<Xc>]",
                         inputs=["Xc"],
                         outputs=["Qa"])

class v_ldr_with_inc_hint(AArch64Instruction):
    def __init__(self):
        super().__init__("ldrh <Qa>, <Xc>, <imm>, <Th>",
                         inputs=["Xc", "Th"],
                         outputs=["Qa"])

    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class v_ldr_with_inc(AArch64Instruction):
    def __init__(self):
        super().__init__("ldr <Qa>, [<Xc>, <imm>]",
                         inputs=["Xc"],
                         outputs=["Qa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class v_ldr_with_inc_writeback(AArch64Instruction):
    def __init__(self):
        super().__init__("ldr <Qa>, [<Xc>, <imm>]!",
                         inputs=["Xc"],
                         outputs=["Qa"])
    def parse(self,src):
        super().parse(src)
        self.increment = self.immediate
        self.pre_index = None
        self.addr = self.args_in[0]

class Ldr_X(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class x_ldr(Ldr_X):
    def __init__(self):
        super().__init__("ldr <Xa>, [<Xc>]",
                         inputs=["Xc"],
                         outputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = None
        self.addr = self.args_in[0]

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index == None
        return super().write()

class x_ldr_stack(Ldr_X):
    def __init__(self):
        super().__init__("ldr <Xa>, [sp]", # TODO: Model sp dependency
                         outputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = None
        self.addr = "sp"

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index == None
        return super().write()

class x_ldr_stack_imm(Ldr_X):
    def __init__(self):
        super().__init__("ldr <Xa>, [sp, <imm>]",
                         outputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldr_stack_imm_with_hint(Ldr_X):
    def __init__(self):
        super().__init__("ldrh <Xa>, sp, <imm>, <Th>", # TODO: Model sp dependency
                         outputs=["Xa"], inputs=["Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldr_imm_with_hint(Ldr_X):
    def __init__(self):
        super().__init__("ldrh <Xa>, <Xb>, <imm>, <Th>",
                         outputs=["Xa"], inputs=["Xb","Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class Ldp_X(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class x_ldp(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, <Xb>, [<Xc>]",
                         inputs=["Xc"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = None
        self.addr = self.args_in[0]

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index == None
        return super().write()

class x_ldp_with_imm_sp_xzr(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, xzr, [sp, <imm>]",
                         outputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_with_imm_sp(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, <Xb>, [sp, <imm>]",
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_with_inc(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, <Xb>, [<Xc>, <imm>]",
                         inputs=["Xc"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_with_inc_writeback(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, <Xb>, [<Xc>, <imm>]!",
                         inputs=["Xc"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = self.immediate
        self.pre_index = None
        # self.pre_index = self.immediate
        self.addr = self.args_in[0]

class x_ldp_with_postinc_writeback(Ldp_X):
    def __init__(self):
        super().__init__("ldp <Xa>, <Xb>, [<Xc>], <imm>",
                         inputs=["Xc"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = self.immediate
        self.pre_index = None
        # self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_with_inc_hint(Ldp_X):
    def __init__(self):
        super().__init__("ldph <Xa>, <Xb>, <Xc>, <imm>, <Th>",
                         inputs=["Xc", "Th"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_sp_with_inc_hint(Ldp_X):
    def __init__(self):
        super().__init__("ldph <Xa>, <Xb>, sp, <imm>, <Th>",
                         inputs=["Th"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_sp_with_inc_hint2(Ldp_X):
    def __init__(self):
        super().__init__("ldphp <Xa>, <Xb>, sp, <imm>, <Th0>, <Th1>",
                         inputs=["Th0", "Th1"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_ldp_with_inc_hint2(Ldp_X):
    def __init__(self):
        super().__init__("ldphp <Xa>, <Xb>, <Xc>, <imm>, <Th0>, <Th1>",
                         inputs=["Xc", "Th0", "Th1"],
                         outputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

############################
#                          #
# Some scalar instructions #
#                          #
############################

class lsr_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("lsr <Wd>, <Wa>, <Wb>",
                         inputs=["Wa", "Wb"],
                         outputs=["Wd"])

class asr_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("asr <Wd>, <Wa>, <imm>",
                         inputs=["Wa"],
                         outputs=["Wd"])

class eor_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("eor <Wd>, <Wa>, <Wb>",
                         inputs=["Wa", "Wb"],
                         outputs=["Wd"])

class AArch64BasicArithmetic(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class subs_wform(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("subs <Wd>, <Wa>, <imm>",
                         inputs=["Wa"],
                         outputs=["Wd"],
                         modifiesFlags=True)

class subs_imm(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("subs <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class sub_imm(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sub <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class add_imm(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class add_sp_imm(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, sp, <imm>", # TODO Model dependency on sp
                         outputs=["Xd"])

class neg(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("neg <Xd>, <Xa>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class adds(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adds <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class adds_to_zero(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adds xzr, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         modifiesFlags=True)

class adds_imm_to_zero(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adds xzr, <Xa>, <imm>",
                         inputs=["Xa"],
                         modifiesFlags=True)

class subs_twoarg(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("subs <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class adds_twoarg(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adds <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class adcs(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adcs <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class sbcs(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sbcs <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class sbcs_zero(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sbcs <Xd>, <Xa>, xzr",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class sbc(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sbc <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         dependsOnFlags=True)

class sbc_zero_r(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sbc <Xd>, <Xa>, xzr",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         dependsOnFlags=True)

class adcs_zero_r(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adcs <Xd>, <Xa>, xzr",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class adcs_zero_l(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adcs <Xd>, xzr, <Xb>",
                         inputs=["Xb"],
                         outputs=["Xd"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class adc(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adc <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"],
                         dependsOnFlags=True)

class adc_zero2(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adc <Xd>, xzr, xzr",
                         outputs=["Xd"],
                         dependsOnFlags=True)

class adc_zero_r(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adc <Xd>, <Xa>, xzr",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         dependsOnFlags=True)

class adc_zero_l(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("adc <Xd>, xzr, <Xa>",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         dependsOnFlags=True)

class add(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class add2(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <Xb>, <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class sub(AArch64BasicArithmetic):
    def __init__(self):
        super().__init__("sub <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class AArch64ShiftedArithmetic(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class add_lsl(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <Xb>, lsl <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class add_lsr(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <Xb>, lsr <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class adds_lsl(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("adds <Xd>, <Xa>, <Xb>, lsl <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class adds_lsr(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("adds <Xd>, <Xa>, <Xb>, lsr <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class add_asr(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <Xb>, asr <imm>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class add_imm_lsl(AArch64ShiftedArithmetic):
    def __init__(self):
        super().__init__("add <Xd>, <Xa>, <imm0>, lsl <imm1>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class AArch64Shift(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class lsr(AArch64Shift):
    def __init__(self):
        super().__init__("lsr <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class lsl(AArch64Shift):
    def __init__(self):
        super().__init__("lsl <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class asr(AArch64Shift):
    def __init__(self):
        super().__init__("asr <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class AArch64Logical(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class eor(AArch64Logical):
    def __init__(self):
        super().__init__("eor <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class orr(AArch64Logical):
    def __init__(self):
        super().__init__("orr <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class bfi(AArch64Logical):
    def __init__(self):
        super().__init__("bfi <Xd>, <Xa>, <imm0>, <imm1>",
                         inputs=["Xa"],
                         in_outs=["Xd"])

class and_imm(AArch64Logical):
    def __init__(self):
        super().__init__("and <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class ands_imm(AArch64Logical):
    def __init__(self):
        super().__init__("ands <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"],
                         modifiesFlags=True)

class ands_xzr_imm(AArch64Logical):
    def __init__(self):
        super().__init__("ands xzr, <Xa>, <imm>",
                         inputs=["Xa"],
                         modifiesFlags=True)

class and_twoarg(AArch64Logical):
    def __init__(self):
        super().__init__("and <Xd>, <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"])

class bic(AArch64Logical):
    def __init__(self):
        super().__init__("bic <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class orr_imm(AArch64Logical):
    def __init__(self):
        super().__init__("orr <Xd>, <Xa>, <imm>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class sbfx(AArch64Logical):
    def __init__(self):
        super().__init__("sbfx <Xd>, <Xa>, <imm0>, <imm1>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class extr(AArch64Logical): ### TODO! Review this...
    def __init__(self):
        super().__init__("extr <Xd>, <Xa>, <Xb>, <imm>",
                         inputs=["Xa", "Xb"],
                         outputs=["Xd"])

class AArch64ConditionalCompare(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class ccmp_xzr(AArch64ConditionalCompare):
    def __init__(self):
        super().__init__("ccmp <Xa>, xzr, <imm>, <flag>",
                         inputs=["Xa"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class ccmp(AArch64ConditionalCompare):
    def __init__(self):
        super().__init__("ccmp <Xa>, <Xb>, <imm>, <flag>",
                         inputs=["Xa", "Xb"],
                         dependsOnFlags=True,
                         modifiesFlags=True)

class AArch64ConditionalSelect(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class cneg(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("cneg <Xd>, <Xe>, <flag>",
                         outputs=["Xd"],
                         inputs=["Xe"],
                         dependsOnFlags=True)

class csel_xzr_ne(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("csel <Xd>, <Xe>, xzr, <flag>",
                         outputs=["Xd"],
                         inputs=["Xe"],
                         dependsOnFlags=True)

class csel_ne(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("csel <Xd>, <Xe>, <Xf>, <flag>",
                         outputs=["Xd"],
                         inputs=["Xe", "Xf"],
                         dependsOnFlags=True)

class cinv(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("cinv <Xd>, <Xe>, <flag>",
                         outputs=["Xd"],
                         inputs=["Xe"],
                         dependsOnFlags=True)

class cinc(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("cinc <Xd>, <Xe>, <flag>",
                         outputs=["Xd"],
                         inputs=["Xe"],
                         dependsOnFlags=True)

class csetm(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("csetm <Xd>, <flag>",
                         outputs=["Xd"],
                         dependsOnFlags=True)

class cset(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("cset <Xd>, <flag>",
                         outputs=["Xd"],
                         dependsOnFlags=True)

class cmn_imm(AArch64ConditionalSelect):
    def __init__(self):
        super().__init__("cmn <Xd>, <imm>",
                         inputs=["Xd"],
                         modifiesFlags=True)

class ldr_const(AArch64Instruction):
    def __init__(self):
        super().__init__("ldr <Xd>, <imm>",
                         inputs=[],
                         outputs=["Xd"])

class movk_imm(AArch64Instruction):
    def __init__(self):
        super().__init__("movk <Xd>, <imm>",
                         inputs=[],
                         in_outs=["Xd"])

class mov(AArch64Instruction):
    def __init__(self):
        super().__init__("mov <Wd>, <Wa>",
                         inputs=["Wa"],
                         outputs=["Wd"])

class AArch64Move(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class mov_imm(AArch64Move):
    def __init__(self):
        super().__init__("mov <Xd>, <imm>",
                         inputs=[],
                         outputs=["Xd"])

class mov_xform(AArch64Move):
    def __init__(self):
        super().__init__("mov <Xd>, <Xa>",
                         inputs=["Xa"],
                         outputs=["Xd"])

class umull_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("umull <Xd>, <Wa>, <Wb>",
                         inputs=["Wa","Wb"],
                         outputs=["Xd"])

class umaddl_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("umaddl <Xn>, <Wa>, <Wb>, <Xacc>",
                         inputs=["Wa","Wb","Xacc"],
                         outputs=["Xn"])

class mul_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("mul <Wd>, <Wa>, <Wb>",
                         inputs=["Wa","Wb"],
                         outputs=["Wd"])

class AArch64HighMultiply(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class umulh_xform(AArch64HighMultiply):
    def __init__(self):
        super().__init__("umulh <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class smulh_xform(AArch64HighMultiply):
    def __init__(self):
        super().__init__("smulh <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class AArch64Multiply(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class mul_xform(AArch64Multiply):
    def __init__(self):
        super().__init__("mul <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class madd_xform(AArch64Multiply):
    def __init__(self):
        super().__init__("madd <Xd>, <Xacc>, <Xa>, <Xb>",
                         inputs=["Xacc", "Xa","Xb"],
                         outputs=["Xd"])

class mneg_xform(AArch64Multiply):
    def __init__(self):
        super().__init__("mneg <Xd>, <Xa>, <Xb>",
                         inputs=["Xa","Xb"],
                         outputs=["Xd"])

class msub_xform(AArch64Multiply):
    def __init__(self):
        super().__init__("msub <Xd>, <Xacc>, <Xa>, <Xb>",
                         inputs=["Xacc", "Xa","Xb"],
                         outputs=["Xd"])

class andi_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("and <Wd>, <Wa>, <imm>",
                         inputs=["Wa"],
                         outputs=["Wd"])

class sub_shifted(Instruction):
    def __init__(self):
        super().__init__(mnemonic="sub",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_out=[RegisterType.GPR])

    def parse(self, src):
        raise Instruction.ParsingException("Does not match pattern")

        sub_imm_regexp_txt = "sub\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*#(?P<shift>.*)"
        sub_imm_regexp_txt = Instruction.unfold_abbrevs(sub_imm_regexp_txt)
        sub_imm_regexp = re.compile(sub_imm_regexp_txt)
        p = sub_imm_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in     = [ p.group("src") ]
        self.args_out    = [ p.group("dst") ]
        self.args_in_out = []

        self.shift = p.group("shift")

    def write(self):
        return f"sub {self.args_out[0]}, {self.args_in[0]}, #{self.shift}"

class add_shifted(Instruction):
    def __init__(self):
        super().__init__(mnemonic="add",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_out=[RegisterType.GPR])

    def parse(self, src):
        raise Instruction.ParsingException("Does not match pattern")

        add_imm_regexp_txt = "add\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*,\s*#(?P<shift>.*)"
        add_imm_regexp_txt = Instruction.unfold_abbrevs(add_imm_regexp_txt)
        add_imm_regexp = re.compile(add_imm_regexp_txt)
        p = add_imm_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in     = [ p.group("src") ]
        self.args_out    = [ p.group("dst") ]
        self.args_in_out = []

        self.shift = p.group("shift")

    def write(self):
        return f"add {self.args_out[0]}, {self.args_in[0]}, #{self.shift}"

class Tst(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class tst_wform(Tst):
    def __init__(self):
        super().__init__("tst <Wa>, <imm>",
                         inputs=["Wa"],
                         modifiesFlags=True)

class tst_imm_xform(Tst):
    def __init__(self):
        super().__init__("tst <Xa>, <imm>",
                         inputs=["Xa"],
                         modifiesFlags=True)

class tst_xform(Tst):
    def __init__(self):
        super().__init__("tst <Xa>, <Xb>",
                         inputs=["Xa", "Xb"],
                         modifiesFlags=True)

class cmp_xzr(Tst):
    def __init__(self):
        super().__init__("cmp <Xa>, xzr",
                         inputs=["Xa"],
                         modifiesFlags=True)

class cbnz(Instruction):
    def __init__(self):
        super().__init__(mnemonic="cbnz",
                arg_types_in=[RegisterType.GPR],
                arg_types_in_out=[])

# class mov_imm(Instruction):
#     def __init__(self):
#         super().__init__(mnemonic="mov",
#                 arg_types_in=[],
#                 arg_types_out=[RegisterType.GPR])
#     def parse(self, src):
#         mov_regexp_txt = "mov\s+(?P<dst>\w+)\s*,\s*#(?P<immediate>\w*)"
#         mov_regexp = re.compile(mov_regexp_txt)
#         p = mov_regexp.match(src)
#         if p is None:
#             raise Instruction.ParsingException("Does not match pattern")
#         self.args_out    = [ p.group("dst") ]
#         self.args_in     = []
#         self.args_in_out = []
#         self.immediate = p.group("immediate")

#     def write(self):
#         return f"mov {self.args_out[0]}, #{self.immediate}"

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
    def __init__(self):
        super().__init__("mov <Vd>.<dt0>, <Va>.<dt1>",
                         inputs=["Va"],
                         outputs=["Vd"])

class vmovi(AArch64Instruction):
    def __init__(self):
        super().__init__("movi <Vd>.<dt>, <imm>",
                         outputs=["Vd"])

class vxtn(AArch64Instruction):
    def __init__(self):
        super().__init__("xtn <Vd>.<dt0>, <Va>.<dt1>",
                         inputs=["Va"],
                         outputs=["Vd"])

class rev64(AArch64Instruction):
    def __init__(self):
        super().__init__("rev64 <Vd>.<dt0>, <Va>.<dt1>",
                         inputs=["Va"],
                         outputs=["Vd"])

class uaddlp(AArch64Instruction):
    def __init__(self):
        super().__init__("uaddlp <Vd>.<dt0>, <Va>.<dt1>",
                         inputs=["Va"],
                         outputs=["Vd"])

class vand(AArch64Instruction):
    def __init__(self):
        super().__init__("and <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vbic(AArch64Instruction):
    def __init__(self):
        super().__init__("bic <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vzip1(AArch64Instruction):
    def __init__(self):
        super().__init__("zip1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])


class vzip2(AArch64Instruction):
    def __init__(self):
        super().__init__("zip2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vuzp1(AArch64Instruction):
    def __init__(self):
        super().__init__("uzp1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])


class vuzp2(AArch64Instruction):
    def __init__(self):
        super().__init__("uzp2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vqrdmulh(AArch64Instruction):
    def __init__(self):
        super().__init__("sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class mov_vtox(AArch64Instruction):
    def __init__(self):
        super().__init__("mov <Xd>, <Va>.d[<index>]",
                         inputs=["Va"],
                         outputs=["Xd"])

class vqrdmulh_lane(AArch64Instruction):
    def __init__(self):
        super().__init__("sqrdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

    def parse(self,src):
        super().parse(src)
        if self.datatype[0] == "8h":
            self.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

class vqdmulh_lane(AArch64Instruction):
    def __init__(self):
        super().__init__("sqdmulh <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

    def parse(self,src):
        super().parse(src)
        if self.datatype[0] == "8h":
            self.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

class vmul_lane(AArch64Instruction):
    def __init__(self):
        super().__init__("mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

    def parse(self,src):
        super().parse(src)
        if self.datatype[0] == "8h":
            self.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

class fcsel_dform(Instruction):
    def __init__(self):
        super().__init__(mnemonic="fcsel_dform",
                         arg_types_in=[RegisterType.Neon, RegisterType.Neon, RegisterType.Flags],
                         arg_types_out=[RegisterType.Neon])

    def parse(self, src):
        regexp_txt = "fcsel_dform\s+(?P<dst>\w+)\s*,\s*(?P<src1>\w+)\s*,\s*(?P<src2>\w+)\s*,\s*eq"
        regexp_txt = Instruction.unfold_abbrevs(regexp_txt)
        regexp = re.compile(regexp_txt)
        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_in     = [ p.group("src1"), p.group("src2"), "flags" ]
        self.args_out    = [ p.group("dst") ]
        self.args_in_out = []

    def write(self):
        return f"fcsel_dform {self.args_out[0]}, {self.args_in[0]}, {self.args_in[1]}, eq"

class mov_d01(AArch64Instruction):
    def __init__(self):
        super().__init__("mov_d01 <Vd>, <Va>",
                         inputs=["Va"],
                         in_outs=["Vd"])
class mov_b00(AArch64Instruction):
    def __init__(self):
        super().__init__("mov_b00 <Vd>, <Va>",
                         inputs=["Va"],
                         in_outs=["Vd"])


# class mov_vtox(Instruction):
#     def __init__(self):
#         super().__init__(mnemonic="mov",
#                          arg_types_in=[RegisterType.Neon],
#                          arg_types_out=[RegisterType.GPR])
#     def parse(self, src):
#         mov_regexp_txt = "mov\s+(?P<dst>\w+)\s*,\s*(?P<src>\w+)\s*\.d\s*\[\s*(?P<immediate>\w*)\s*\]"
#         mov_regexp = re.compile(mov_regexp_txt)
#         p = mov_regexp.match(src)
#         if p is None:
#             raise Instruction.ParsingException("Does not match pattern")
#         self.args_out    = [ p.group("dst") ]
#         self.args_in     = [ p.group("src") ]
#         self.args_in_out = []
#         self.immediate = p.group("immediate")

#     def write(self):
#         return f"mov {self.args_out[0]}, {self.args_in[0]}.d[{self.immediate}]"

class mov_xtov(Instruction):
    def __init__(self):
        super().__init__(mnemonic="mov",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_in_out=[RegisterType.Neon])
    def parse(self, src):
        mov_regexp_txt = "mov\s+\s*(?P<dst>\w+)\s*\.d\s*\[\s*(?P<immediate>\w*)\s*\]\s*,\s*(?P<src>\w+)\s*"
        mov_regexp = re.compile(mov_regexp_txt)
        p = mov_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out    = []
        self.args_in     = [ p.group("src") ]
        self.args_in_out = [ p.group("dst") ]
        self.immediate = p.group("immediate")

    def write(self):
        return f"mov {self.args_in_out[0]}.d[{self.immediate}], {self.args_in[0]}"

class vmul(AArch64Instruction):
    def __init__(self):
        super().__init__("mul <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vmla(AArch64Instruction):
    def __init__(self):
        super().__init__("mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         in_outs=["Vd"])

class vmla_lane(AArch64Instruction):
    def __init__(self):
        super().__init__("mla <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]",
                         inputs=["Va", "Vb"],
                         in_outs=["Vd"])
    def parse(self,src):
        super().parse(src)
        if self.datatype[0] == "8h":
            self.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

class vmls(AArch64Instruction):
    def __init__(self):
        super().__init__("mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         in_outs=["Vd"])

class vmls_lane(AArch64Instruction):
    def __init__(self):
        super().__init__("mls <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>[<index>]",
                         inputs=["Va", "Vb"],
                         in_outs=["Vd"])
    def parse(self,src):
        super().parse(src)
        if self.datatype[0] == "8h":
            self.args_in_restrictions = [ [ f"v{i}" for i in range(0,32) ],
                                          [ f"v{i}" for i in range(0,16) ]]

class vdup(AArch64Instruction):
    def __init__(self):
        super().__init__("dup <Vd>.<dt>, <Xa>",
                         inputs=["Xa"],
                         outputs=["Vd"])

class vmull(AArch64Instruction):
    def __init__(self):
        super().__init__("umull <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vmlal(AArch64Instruction):
    def __init__(self):
        super().__init__("umlal <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         in_outs=["Vd"])

class vsrshr(AArch64Instruction):
    def __init__(self):
        super().__init__("srshr <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         outputs=["Vd"])

class vshl(AArch64Instruction):
    def __init__(self):
        super().__init__("shl <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         outputs=["Vd"])

class vshli(AArch64Instruction):
    def __init__(self):
        super().__init__("sli <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         in_outs=["Vd"])

class vusra(AArch64Instruction):
    def __init__(self):
        super().__init__("usra <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         in_outs=["Vd"])

class vshrn(AArch64Instruction):
    def __init__(self):
        super().__init__("shrn <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         outputs=["Vd"])

class vext(AArch64Instruction):
    def __init__(self):
        super().__init__("ext <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>, <imm>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class vushr(AArch64Instruction):
    def __init__(self):
        super().__init__("ushr <Vd>.<dt0>, <Va>.<dt1>, <imm>",
                         inputs=["Va"],
                         outputs=["Vd"])

#
# Transposition wrappers
#

class trn1(AArch64Instruction):
    def __init__(self):
        super().__init__("trn1 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

class trn2(AArch64Instruction):
    def __init__(self):
        super().__init__("trn2 <Vd>.<dt0>, <Va>.<dt1>, <Vb>.<dt2>",
                         inputs=["Va", "Vb"],
                         outputs=["Vd"])

#
# Wrappers around vector load and store instructions
#
class ldr_idx_wform(AArch64Instruction):
    def __init__(self):
        super().__init__("ldr <Wd>, [<Xa>, <Wb>, <imm>]",
                         inputs=["Xa", "Wb"],
                         outputs=["Wd"])
        self.addr = "sp"

class ldr_vo_wrapper(Instruction):
    def __init__(self):
        super().__init__(mnemonic="ldr_vo",
                arg_types_in=[RegisterType.GPR],
                arg_types_out=[RegisterType.Neon])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$","",src)

        have_dt = ( "<dt>" in self.mnemonic ) or ( "<fdt>" in self.mnemonic )

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
        regexp_txt  = f"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += "\s+"
        regexp_txt += ','.join(["\s*(\w+)\s*" for _ in range(expected_args)])
        regexp_txt += ",\s*(?P<immediate>[\(\)\+\-\*\/0-9 ]+)"
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())

        if have_dt:
            operands = operands[1:]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.pre_index = operands[-1]

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype").lower()

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[:self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[:self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:(self.num_in_out+self.num_out+self.num_in)]

        self.addr = self.args_in[0]
        self.increment = None

        if not len(self.args_in) == self.num_in:
            raise Exception(f"Something wrong parsing {src}: Expect {self.num_in} input, but got {len(self.args_in)} ({self.args_in})")

    def write(self):
        self._simplify()
        return f"ldr_vo {self.args_out[0]}, {self.args_in[0]}, {self.pre_index}"

class ldr_vi_wrapper(Instruction):
    def __init__(self):
        super().__init__(mnemonic="ldr_vi",
                arg_types_in=[RegisterType.GPR],
                arg_types_out=[RegisterType.Neon])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$","",src)

        have_dt = ( "<dt>" in self.mnemonic ) or ( "<fdt>" in self.mnemonic )

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
        regexp_txt  = f"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += "\s+"
        regexp_txt += ','.join(["\s*(\w+)\s*" for _ in range(expected_args)])
        regexp_txt += ",\s*(?P<immediate>[\(\)\+\-\*\/0-9 ]+)"
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())

        if have_dt:
            operands = operands[1:]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.pre_index = None
        self.increment = operands[-1]

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype").lower()

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[:self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[:self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:(self.num_in_out+self.num_out+self.num_in)]

        self.addr = self.args_in[0]

        if not len(self.args_in) == self.num_in:
            raise Exception(f"Something wrong parsing {src}: Expect {self.num_in} input, but got {len(self.args_in)} ({self.args_in})")

    def write(self):
        self._simplify()
        return f"ldr_vi {self.args_out[0]}, {self.args_in[0]}, {self.increment}"

class str_vo_wrapper(Instruction):
    def __init__(self):
        super().__init__(mnemonic="str_vo",
                arg_types_in=[RegisterType.Neon, RegisterType.GPR],
                arg_types_out=[])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$","",src)

        have_dt = ( "<dt>" in self.mnemonic ) or ( "<fdt>" in self.mnemonic )

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
        regexp_txt  = f"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += "\s+"
        regexp_txt += ','.join(["\s*(\w+)\s*" for _ in range(expected_args)])
        regexp_txt += ",\s*(?P<immediate>[\(\)\+\-\*\/0-9 ]+)"
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())

        if have_dt:
            operands = operands[1:]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.pre_index = operands[-1]
        self.increment = None

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype").lower()

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[:self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[:self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:(self.num_in_out+self.num_out+self.num_in)]
        self.addr = self.args_in[1]

        if not len(self.args_in) == self.num_in:
            raise Exception(f"Something wrong parsing {src}: Expect {self.num_in} input, but got {len(self.args_in)} ({self.args_in})")

    def write(self):
        self._simplify()
        return f"str_vo {self.args_in[0]}, {self.args_in[1]}, {self.pre_index}"

class str_vi_wrapper(Instruction):
    def __init__(self):
        super().__init__(mnemonic="str_vi",
                arg_types_in=[RegisterType.Neon, RegisterType.GPR],
                arg_types_out=[])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$","",src)

        have_dt = ( "<dt>" in self.mnemonic ) or ( "<fdt>" in self.mnemonic )

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(self.mnemonic)

        expected_args = self.num_in + self.num_out + self.num_in_out
        regexp_txt  = f"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += "\s+"
        regexp_txt += ','.join(["\s*(\w+)\s*" for _ in range(expected_args)])
        regexp_txt += ",\s*(?P<immediate>[\(\)\+\-\*\/0-9 ]+)"
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(f"Doesn't match basic instruction template {regexp_txt}")

        operands = list(p.groups())

        if have_dt:
            operands = operands[1:]

        self.args_in     = []
        self.args_out    = []
        self.args_in_out = []

        self.pre_index = None
        self.increment = operands[-1]

        self.datatype = ""
        if have_dt:
            self.datatype = p.group("datatype").lower()

        idx_args_in = 0

        if self.num_out > 0:
            self.args_out = operands[:self.num_out]
            idx_args_in = self.num_out
        elif self.num_in_out > 0:
            self.args_in_out = operands[:self.num_in_out]
            idx_args_in = self.num_in_out

        self.args_in = operands[idx_args_in:(self.num_in_out+self.num_out+self.num_in)]
        self.addr = self.args_in[1]

        if not len(self.args_in) == self.num_in:
            raise Exception(f"Something wrong parsing {src}: Expect {self.num_in} input, but got {len(self.args_in)} ({self.args_in})")

    def write(self):
        self._simplify()
        return f"str_vi {self.args_in[0]}, {self.args_in[1]}, {self.increment}"

class Str_X(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class x_str(Str_X):
    def __init__(self):
        super().__init__("str <Xa>, [<Xc>]",
                         inputs=["Xa", "Xc"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = None
        self.addr = self.args_in[0]

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the LDP with increment.
        assert self.pre_index == None
        return super().write()

class x_str_imm(Str_X):
    def __init__(self):
        super().__init__("str <Xa>, [<Xc>, <imm>]",
                         inputs=["Xa", "Xc"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_str_sp_imm(Str_X):
    def __init__(self):
        super().__init__("str <Xa>, [sp, <imm>]",
                         inputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_str_sp_imm_hint(Str_X):
    def __init__(self):
        super().__init__("strh <Xa>, sp, <imm>, <Th>",
                         inputs=["Xa"], outputs=["Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_str_imm_hint(Str_X):
    def __init__(self):
        super().__init__("strh <Xa>, <Xb>, <imm>, <Th>",
                         inputs=["Xa", "Xb"], outputs=["Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[1]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class Stp_X(AArch64Instruction):
    def __init__(self, pattern, *args, **kwargs):
        super().__init__(pattern, *args, **kwargs)

class x_stp(Stp_X):
    def __init__(self):
        super().__init__("stp <Xa>, <Xb>, [<Xc>]",
                         inputs=["Xc", "Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = None
        self.addr = self.args_in[0]

    def write(self):
        # For now, assert that no fixup has happened
        # Eventually, this instruction should be merged
        # into the STP with increment.
        assert self.pre_index == None
        return super().write()

class x_stp_with_imm_xzr_sp(Stp_X):
    def __init__(self):
        super().__init__("stp <Xa>, xzr, [sp, <imm>]",
                         inputs=["Xa"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_stp_with_imm_sp(Stp_X):
    def __init__(self):
        super().__init__("stp <Xa>, <Xb>, [sp, <imm>]",
                         inputs=["Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_stp_with_inc(Stp_X):
    def __init__(self):
        super().__init__("stp <Xa>, <Xb>, [<Xc>, <imm>]",
                         inputs=["Xc", "Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_stp_with_inc_writeback(Stp_X):
    def __init__(self):
        super().__init__("stp <Xa>, <Xb>, [<Xc>, <imm>]!",
                         inputs=["Xc", "Xa", "Xb"])
    def parse(self,src):
        super().parse(src)
        self.increment = self.immediate
        self.pre_index = None
        # self.pre_index = self.immediate
        self.addr = self.args_in[0]

class x_stp_with_inc_hint(Stp_X):
    def __init__(self):
        super().__init__("stph <Xa>, <Xb>, <Xc>, <imm>, <Th>",
                         inputs=["Xc", "Xa", "Xb"],
                         outputs=["Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[0]
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class x_stp_sp_with_inc_hint(Stp_X):
    def __init__(self):
        super().__init__("stph <Xa>, <Xb>, sp, <imm>, <Th>",
                         inputs=["Xa", "Xb"],
                         outputs=["Th"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_stp_sp_with_inc_hint2(Stp_X):
    def __init__(self):
        super().__init__("stphp <Xa>, <Xb>, sp, <imm>, <Th0>, <Th1>",
                         inputs=["Xa", "Xb"],
                         outputs=["Th0", "Th1"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = "sp"
    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()

class x_stp_with_inc_hint2(Stp_X):
    def __init__(self):
        super().__init__("stphp <Xa>, <Xb>, <Xc>, <imm>, <Th0>, <Th1>",
                         inputs=["Xa", "Xb", "Xc"],
                         outputs=["Th0", "Th1"])
    def parse(self,src):
        super().parse(src)
        self.increment = None
        self.pre_index = self.immediate
        self.addr = self.args_in[2]

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


# class x_str(Instruction):
#     def __init__(self):
#         super().__init__(mnemonic="str",
#                 arg_types_in=[RegisterType.GPR, RegisterType.GPR])

#     def _simplify(self):
#         if no_simplify:
#             return
#         if self.increment != None:
#             self.increment = simplify(self.increment)
#         if self.post_index != None:
#             self.post_index = simplify(self.post_index)
#         if self.pre_index != None:
#             self.pre_index = simplify(self.pre_index)

#     def parse(self, src):
#         src = re.sub("//.*$","",src)

#         addr_regexp_txt = "\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
#         postinc_regexp_txt = "\s*(?:,\s*#(?P<postinc>.*))?"

#         str_regexp_txt  = "\s*str\s+"
#         str_regexp_txt += "(?P<dest>\w+),\s*"
#         str_regexp_txt += addr_regexp_txt
#         str_regexp_txt += postinc_regexp_txt
#         str_regexp_txt = Instruction.unfold_abbrevs(str_regexp_txt)

#         str_regexp = re.compile(str_regexp_txt)

#         p = str_regexp.match(src)
#         if p is None:
#             raise Instruction.ParsingException("Doesn't match pattern")

#         gpr  = p.group("dest")
#         self.addr = p.group("addr")
#         self.writeback = ( p.group("writeback") == "!" )

#         self.pre_index = p.group("addroffset")
#         self.post_index = p.group("postinc")

#         if self.writeback:
#             self.increment = self.pre_index
#         elif self.post_index:
#             self.increment = self.post_index
#         else:
#             self.increment = None

#         self._simplify()

#         # NOTE: We currently don't model post-increment loads/stores
#         #       as changing the address register, allowing the tool to
#         #       freely rearrange loads/stores from the same base register.
#         #       We correct the indices afterwards.

#         self.args_in     = [ gpr, self.addr ]
#         self.args_out    = []
#         self.args_in_out = []

#     def write(self):

#         self._simplify()

#         inc = ""
#         if self.writeback:
#             inc = "!"

#         warn = False

#         if self.pre_index is not None:
#             warn = True
#             addr = f"[{self.args_in[1]}, #{self.pre_index}]"
#         else:
#             addr = f"[{self.args_in[1]}]"

#         if self.post_index is not None:
#             warn = True
#             post = f", #{self.post_index}"
#         else:
#             post = ""

#         return f"{self.mnemonic} {self.args_in[0]}, {addr}{inc} {post}"

class vstr(Instruction):
    def __init__(self):
        super().__init__(mnemonic="str",
                arg_types_in=[RegisterType.Neon, RegisterType.GPR])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.post_index != None:
            self.post_index = simplify(self.post_index)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        raise Instruction.ParsingException("Disabled for now")
        src = re.sub("//.*$","",src)

        addr_regexp_txt = "\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        postinc_regexp_txt = "\s*(?:,\s*#(?P<postinc>.*))?"

        str_regexp_txt  = "\s*str\s+"
        str_regexp_txt += "(?P<dest>\w+),\s*"
        str_regexp_txt += addr_regexp_txt
        str_regexp_txt += postinc_regexp_txt
        str_regexp_txt = Instruction.unfold_abbrevs(str_regexp_txt)

        str_regexp = re.compile(str_regexp_txt)

        p = str_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        gpr  = p.group("dest")
        self.addr = p.group("addr")
        self.writeback = ( p.group("writeback") == "!" )

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

        self.args_in     = [ gpr, self.addr ]
        self.args_out    = []
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

        return f"{self.mnemonic} {self.args_in[0]}, {addr}{inc} {post}"

class vldr(Instruction):
    def __init__(self):
        super().__init__(mnemonic="XXXldr",
                ## TODO This is wrong?! The _output_ is a Neon register
                arg_types_in=[RegisterType.Neon],
                arg_types_out=[RegisterType.GPR])

    def _simplify(self):
        if no_simplify:
            return
        if self.increment != None:
            self.increment = simplify(self.increment)
        if self.post_index != None:
            self.post_index = simplify(self.post_index)
        if self.pre_index != None:
            self.pre_index = simplify(self.pre_index)

    def parse(self, src):
        src = re.sub("//.*$","",src)

        addr_regexp_txt = "\[\s*(?P<addr>\w+)\s*(?:,\s*#(?P<addroffset>[^\]]*))?\](?P<writeback>!?)"
        postinc_regexp_txt = "\s*(?:,\s*#(?P<postinc>.*))?"

        ldr_regexp_txt  = "\s*XXXldr\s+"
        ldr_regexp_txt += "(?P<dest>\w+),\s*"
        ldr_regexp_txt += addr_regexp_txt
        ldr_regexp_txt += postinc_regexp_txt
        ldr_regexp_txt = Instruction.unfold_abbrevs(ldr_regexp_txt)

        ldr_regexp = re.compile(ldr_regexp_txt)

        p = ldr_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Doesn't match pattern")

        vec  = p.group("dest")
        self.addr = p.group("addr")
        self.writeback = ( p.group("writeback") == "!" )

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

        self.args_in     = [ self.addr ]
        self.args_out    = [ vec ]
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

        return f"ldr {self.args_out[0]}, {addr}{inc} {post}"

class vins(Instruction):
    def __init__(self):
        super().__init__(mnemonic="vins",
                         arg_types_in=[RegisterType.GPR],
                         arg_types_in_out=[RegisterType.Neon],
                         arg_types_out=[])

    def parse(self, src):
        vins_regexp_txt = "vins\s+(?P<dst>\w+)\s*, (?P<src>\w+)\s*,\s*(?P<lane>\w*)"
        vins_regexp_txt = Instruction.unfold_abbrevs(vins_regexp_txt)
        vins_regexp = re.compile(vins_regexp_txt)
        p = vins_regexp.match(src)
        if p is None:
            raise Instruction.ParsingException("Does not match pattern")
        self.args_out    = []
        self.args_in     = [ p.group("src") ]
        self.args_in_out = [ p.group("dst") ]

        self.lane = p.group("lane")
        self.detected_vins_pair = False

    def write(self):
        if not self.detected_vins_pair:
            return f"vins {self.args_in_out[0]}, {self.args_in[0]}, {self.lane}"
        else:
            return f"vins {self.args_out[0]}, {self.args_in[0]}, {self.lane}"

# class vext(Instruction):
#     def __init__(self):
#         super().__init__(mnemonic="vext",
#                          arg_types_in=[RegisterType.Neon],
#                          arg_types_in_out=[RegisterType.GPR],
#                          arg_types_out=[])

#     def parse(self, src):
#         vext_regexp_txt = "vext\s+(?P<dst>\w+)\s*, (?P<src>\w+)\s*,\s*(?P<lane>\w*)"
#         vext_regexp_txt = Instruction.unfold_abbrevs(vext_regexp_txt)
#         vext_regexp = re.compile(vext_regexp_txt)
#         p = vext_regexp.match(src)
#         if p is None:
#             raise Instruction.ParsingException("Does not match pattern")
#         self.args_out    = []
#         self.args_in     = [ p.group("src") ]
#         self.args_in_out = [ p.group("dst") ]

#         self.lane = p.group("lane")

#     def write(self):
#         return f"vext {self.args_in_out[0]}, {self.args_in[0]}, {self.lane}"

class st4(Instruction):
    def __init__(self):
        super().__init__(mnemonic="st4",
                arg_types_in=[RegisterType.GPR, RegisterType.Neon, RegisterType.Neon,
                RegisterType.Neon, RegisterType.Neon])
    def parse(self, src):
        regexp = "\s*(st4)\s+{"\
            "\s*(?P<out0>\w+)\.<dt0>\s*,"\
            "\s*(?P<out1>\w+)\s*\.<dt1>,"\
            "\s*(?P<out2>\w+)\s*\.<dt2>,"\
            "\s*(?P<out3>\w+)\s*\.<dt3>}"\
            "\s*,\s*\[\s*(?P<reg>\w+)\s*\],\s*#(?P<increment>.*)"

        regexp = Instruction.unfold_abbrevs(regexp)
        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException( "Didn't match regexp" )
        self.addr = p.group("reg")
        self.args_in = [ self.addr,
                             p.group("out0"),
                             p.group("out1"),
                             p.group("out2"),
                             p.group("out3") ]
        self.datatypes = [p.group("datatype0"),
                             p.group("datatype1"),
                             p.group("datatype2"),
                             p.group("datatype3")]
        self.args_in_out = []
        self.args_out = []
        self.increment = p.group("increment")
        self.pre_index = None


        self.args_in_combinations = [
                ( [1,2,3,4], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
            ]


    def write(self):
        addr = f"[{self.args_in[0]}]"
        return f"st4 {{{','.join([f'{a}.{b}' for a,b in zip(self.args_in[1:],self.datatypes)])}}}, {addr}, #{self.increment}"

class ld4(Instruction):
    def __init__(self):
        super().__init__(mnemonic="ld4",
                arg_types_in_out=[RegisterType.GPR],
                arg_types_out=[RegisterType.Neon, RegisterType.Neon,
                RegisterType.Neon, RegisterType.Neon])
    def parse(self, src):
        regexp = "\s*(ld4)\s+{"\
            "\s*(?P<out0>\w+)\.<dt0>\s*,"\
            "\s*(?P<out1>\w+)\s*\.<dt1>,"\
            "\s*(?P<out2>\w+)\s*\.<dt2>,"\
            "\s*(?P<out3>\w+)\s*\.<dt3>}"\
            "\s*,\s*\[\s*(?P<reg>\w+)\s*\]"
        postinc_regexp_txt = "\s*(?:,\s*#(?P<increment>.*))?"
        regexp += postinc_regexp_txt
        regexp = Instruction.unfold_abbrevs(regexp)
        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException( "Didn't match regexp" )
        self.addr = p.group("reg")
        self.args_in = []
        self.args_out = [ p.group("out0"),
                             p.group("out1"),
                             p.group("out2"),
                             p.group("out3") ]
        self.datatypes = [p.group("datatype0"),
                             p.group("datatype1"),
                             p.group("datatype2"),
                             p.group("datatype3")]
        self.args_in_out = [ self.addr ]
        self.increment = p.group("increment")
        self.pre_index = None

        self.args_out_combinations = [
                ( [0,1,2,3], [ [ f"v{i}", f"v{i+1}", f"v{i+2}", f"v{i+3}" ] for i in range(0,28) ] )
            ]


    def write(self):
        addr = f"[{self.args_in_out[0]}]"
        increment = ""
        if self.increment != None:
            increment = f", #{self.increment}"
        return f"ld4 {{{','.join([f'{a}.{b}' for a,b in zip(self.args_out,self.datatypes)])}}}, {addr}{increment}"

class ld2(Instruction):
    def __init__(self):
        super().__init__(mnemonic="ld2",
                arg_types_in=[RegisterType.GPR],
                arg_types_out=[RegisterType.Neon, RegisterType.Neon])
    def parse(self, src):
        regexp = "\s*(ld2)\s+{"\
            "\s*(?P<out0>\w+)\.<dt0>\s*,"\
            "\s*(?P<out1>\w+)\s*\.<dt1>}"\
            "\s*,\s*\[\s*(?P<reg>\w+)\s*\],\s*#(?P<increment>.*)"

        regexp = Instruction.unfold_abbrevs(regexp)
        p = re.compile(regexp).match(src)
        if p is None:
            raise Instruction.ParsingException( "Didn't match regexp" )
        self.addr = p.group("reg")
        self.args_in = [ self.addr ]
        self.args_out = [ p.group("out0"),
                             p.group("out1") ]
        self.datatypes = [p.group("datatype0"),
                             p.group("datatype1")]
        self.args_in_out = []
        self.increment = p.group("increment")
        self.pre_index = None

        self.args_out_combinations = [
                ( [0,1], [ [ f"v{i}", f"v{i+1}" ] for i in range(0,30) ] )
            ]


    def write(self):
        addr = f"[{self.args_in[0]}]"
        increment = ""
        if self.increment != None:
            increment = f", #{self.increment}"
        return f"ld2 {{{','.join([f'{a}.{b}' for a,b in zip(self.args_out,self.datatypes)])}}}, {addr}{increment}"

# In a pair of vins writing both 64-bit lanes of a vector, mark the
# target vector as output rather than input/output. This enables further
# renaming opportunities.
def vins_parsing_cb():
    def core(inst,t, delete_list):
        succ = None

        if inst.detected_vins_pair:
            return False

        # Check if this is the first in a pair of vins+vins
        if len(t.dst_in_out[0]) == 1:
            r = t.dst_in_out[0][0]
            if isinstance(r.inst, vins):
                if r.inst.args_in_out == inst.args_in_out and \
                   {r.inst.lane, inst.lane} == {'0','1'}:
                    succ = r

        if succ is None:
            return False

        # If so, mark in/out as output only, and signal the need for re-building
        # the dataflow graph

        inst.num_out = 1
        inst.args_out = [ inst.args_in_out[0] ]
        inst.arg_types_out = [ RegisterType.Neon ]
        inst.args_out_restrictions = inst.args_in_out_restrictions

        inst.num_in_out = 0
        inst.args_in_out = []
        inst.arg_types_in_out = []
        inst.args_in_out_restrictions = []

        inst.detected_vins_pair = True
        return True

    return core

vins.global_parsing_cb  = vins_parsing_cb()

def stack_vld2_lane_parsing_cb():
    def core(inst,t, delete_list):
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
        return True

    return core

stack_vld2_lane.global_parsing_cb  = stack_vld2_lane_parsing_cb()

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

def iter_aarch64_instructions():
    yield from all_subclass_leaves(Instruction)

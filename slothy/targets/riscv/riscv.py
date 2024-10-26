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
Partial SLOTHY architecture model for RISCV

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

llvm_mca_arch = "aarch64"

class RegisterType(Enum):
    """
    Enum of all register types
    """
    BASE_INT = 1  # 32 x-registers, 32-bit width + additional pc register

    def __str__(self):
        return self.name
    def __repr__(self):
        return self.name

    @cache
    @staticmethod
    def spillable(reg_type):  # done
        #return reg_type in [RegisterType.BASE_INT, RegisterType.NEON]
        return

    @cache
    @staticmethod
    def list_registers(reg_type, only_extra=False, only_normal=False, with_variants=False):  # done
        """Return the list of all registers of a given type"""

        base_int  = [ f"x{i}" for i in range(31) ] + ["pc"]


        return { RegisterType.BASE_INT : base_int,
                 }[reg_type]


    @staticmethod
    def find_type(r):  # done
        """Find type of architectural register"""

        #if r.startswith("hint_"):
        #    return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty
        return None

    @staticmethod
    def is_renamed(ty):  # done
        """Indicate if register type should be subject to renaming"""
        #if ty == RegisterType.HINT:
        #    return False
        return True

    @staticmethod
    def from_string(string):  # done
        """Find register type from string"""
        string = string.lower()
        return { "base_int"    : RegisterType.BASE_INT}.get(string,None)

    @staticmethod
    def default_reserved():  # done
        """Return the list of registers that should be reserved by default"""
        #return set(["flags", "sp"] + RegisterType.list_registers(RegisterType.HINT))
        return []

    @staticmethod
    def default_aliases():  # done
        "Register aliases used by the architecture"
        return {}

# class Branch:
#     """Helper for emitting branches"""
#
#     @staticmethod
#     def if_equal(cnt, val, lbl):
#         """Emit assembly for a branch-if-equal sequence"""
#         yield f"cmp {cnt}, #{val}"
#         yield f"b.eq {lbl}"
#
#     @staticmethod
#     def if_greater_equal(cnt, val, lbl):
#         """Emit assembly for a branch-if-greater-equal sequence"""
#         yield f"cmp {cnt}, #{val}"
#         yield f"b.ge {lbl}"
#
#     @staticmethod
#     def unconditional(lbl):
#         """Emit unconditional branch"""
#         yield f"b {lbl}"

# class Loop:
#     """Helper functions for parsing and writing simple loops in AArch64
#
#     TODO: Generalize; current implementation too specific about shape of loop"""
#
#     def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr"):
#         self.lbl_start = lbl_start
#         self.lbl_end   = lbl_end
#         self.loop_init = loop_init
#
#     def start(self, loop_cnt, indentation=0, fixup=0, unroll=1, jump_if_empty=None):
#         """Emit starting instruction(s) and jump label for loop"""
#         indent = ' ' * indentation
#         if unroll > 1:
#             assert unroll in [1,2,4,8,16,32]
#             yield f"{indent}lsr {loop_cnt}, {loop_cnt}, #{int(math.log2(unroll))}"
#         if fixup != 0:
#             yield f"{indent}sub {loop_cnt}, {loop_cnt}, #{fixup}"
#         if jump_if_empty is not None:
#             yield f"cbz {loop_cnt}, {jump_if_empty}"
#         yield f"{self.lbl_start}:"
#
#     def end(self, other, indentation=0):
#         """Emit compare-and-branch at the end of the loop"""
#         (reg0, reg1, imm) = other
#         indent = ' ' * indentation
#         lbl_start = self.lbl_start
#         if lbl_start.isdigit():
#             lbl_start += "b"
#
#         yield f"{indent}sub {reg0}, {reg1}, {imm}"
#         yield f"{indent}cbnz {reg0}, {lbl_start}"
#
#     @staticmethod
#     def extract(source, lbl):
#         """Locate a loop with start label `lbl` in `source`.
#
#         We currently only support the following loop forms:
#
#            ```
#            loop_lbl:
#                {code}
#                sub[s] <cnt>, <cnt>, #1
#                (cbnz|bnz|bne) <cnt>, loop_lbl
#            ```
#
#         """
#         assert isinstance(source, list)
#
#         pre  = []
#         body = []
#         post = []
#         loop_lbl_regexp_txt = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
#         loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)
#
#         # TODO: Allow other forms of looping
#
#         loop_end_regexp_txt = (r"^\s*sub[s]?\s+(?P<reg0>\w+),\s*(?P<reg1>\w+),\s*(?P<imm>#1)",
#                                rf"^\s*(cbnz|bnz|bne)\s+(?P<reg0>\w+),\s*{lbl}")
#         loop_end_regexp = [re.compile(txt) for txt in loop_end_regexp_txt]
#         lines = iter(source)
#         l = None
#         keep = False
#         state = 0 # 0: haven't found loop yet, 1: extracting loop, 2: after loop
#         while True:
#             if not keep:
#                 l = next(lines, None)
#             keep = False
#             if l is None:
#                 break
#             l_str = l.text
#             assert isinstance(l, str) is False
#             if state == 0:
#                 p = loop_lbl_regexp.match(l_str)
#                 if p is not None and p.group("label") == lbl:
#                     l = l.copy().set_text(p.group("remainder"))
#                     keep = True
#                     state = 1
#                 else:
#                     pre.append(l)
#                 continue
#             if state == 1:
#                 p = loop_end_regexp[0].match(l_str)
#                 if p is not None:
#                     reg0 = p.group("reg0")
#                     reg1 = p.group("reg1")
#                     imm = p.group("imm")
#                     state = 2
#                     continue
#                 body.append(l)
#                 continue
#             if state == 2:
#                 p = loop_end_regexp[1].match(l_str)
#                 if p is not None:
#                     state = 3
#                     continue
#                 body.append(l)
#                 continue
#             if state == 3:
#                 post.append(l)
#                 continue
#         if state < 3:
#             raise FatalParsingException(f"Couldn't identify loop {lbl}")
#         return pre, body, post, lbl, (reg0, reg1, imm)

class FatalParsingException(Exception):  # done
    """A fatal error happened during instruction parsing"""

class UnknownInstruction(Exception):  # done
    """The parent instruction class for the given object could not be found"""

class UnknownRegister(Exception):  # done
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
        self.offset_adjustable = True

        self.immediate = None
        self.datatype = None
        self.index = None
        self.flag = None

    def extract_read_writes(self):  # what does this do?
        """Extracts 'reads'/'writes' clauses from the source line of the instruction"""

        src_line = self.source_line

        def hint_register_name(tag):
            return f"hint_{tag}"

        # Check if the source line is tagged as reading/writing from memory
        def add_memory_write(tag):
            self.num_out += 1
            self.args_out_restrictions.append(None)
            self.args_out.append(hint_register_name(tag))
            #self.arg_types_out.append(RegisterType.HINT)

        def add_memory_read(tag):
            self.num_in += 1
            self.args_in_restrictions.append(None)
            self.args_in.append(hint_register_name(tag))
            #self.arg_types_in.append(RegisterType.HINT)

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

    def global_parsing_cb(self, a, log=None): # done
        """Parsing callback triggered after DataFlowGraph parsing which allows modification
        of the instruction in the context of the overall computation.

        This is primarily used to remodel input-outputs as outputs in jointly destructive
        instruction patterns (See Section 4.4, https://eprint.iacr.org/2022/1303.pdf)."""
        _ = log # log is not used
        return False

    def global_fusion_cb(self, a, log=None):  # done
        """Fusion callback triggered after DataFlowGraph parsing which allows fusing
        of the instruction in the context of the overall computation.

        This can be used e.g. to detect eor-eor pairs and replace them by eor3."""
        _ = log # log is not used
        return False

    def write(self):  # done
        """Write the instruction"""
        args = self.args_out + self.args_in_out + self.args_in
        return self.mnemonic + ' ' + ', '.join(args)

    @staticmethod
    def unfold_abbrevs(mnemonic):  # NOT done
        if mnemonic.count("<dt") > 1:
            for i in range(mnemonic.count("<dt")):
                mnemonic = re.sub(f"<dt{i}>", f"(?P<datatype{i}>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))",
                                  mnemonic)
        else:
            mnemonic = re.sub("<dt>",  f"(?P<datatype>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))", mnemonic)
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self,inst):
                return True
        return False

    # vector
    def is_q_form_vector_instruction(self):
        """Indicates whether an instruction is Neon instruction operating on
        a 128-bit vector"""

        # For most instructions, we infer their operating size from explicit
        # datatype annotations. Others need listing explicitly.

        #if self.datatype is None:
        #    return self._is_instance_of([Str_Q, Ldr_Q])

        # Operations on specific lanes are not counted as Q-form instructions
        #if self._is_instance_of([Q_Ld2_Lane_Post_Inc]):
        #    return False

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
        #return self._is_instance_of([ Ldr_Q, Ldp_Q, Ld2, Ld4, Q_Ld2_Lane_Post_Inc ])
        return False
    def is_vector_store(self):
        """Indicates if an instruction is a Neon store instruction"""
    #    return self._is_instance_of([ Str_Q, Stp_Q, St2, St4,
    #                                  d_stp_stack_with_inc, d_str_stack_with_inc])
        return False
    # scalar
    def is_scalar_load(self):
         """Indicates if an instruction is a scalar load instruction"""
         #return self._is_instance_of([ Ldr_X, Ldp_X ])
         return False
    def is_scalar_store(self):
         """Indicates if an instruction is a scalar store instruction"""
         #return  self._is_instance_of([ Stp_X, Str_X ])
         return False

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
    def build(c, src, mnemonic, **kwargs):  # done
        """Attempt to parse a string as an instance of an instruction.

        Args:
            c: The target instruction the string should be attempted to be parsed as.
            src: The string to parse.
            mnemonic: The mnemonic of instruction c

        Returns:
            Upon success, the result of parsing src as an instance of c.

        Raises:
            ParsingException: The str argument cannot be parsed as an
                instance of c.
            FatalParsingException: A fatal error during parsing happened
                that's likely a bug in the model.
        """

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
    def parser(src_line):  # done
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
            for i,e in exceptions.items():
                msg = f"* {i + ':':20s} {e}"
                logging.error(msg)
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support "\
                  "for a new instruction (variant)?")

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()

class RISCVInstruction(Instruction):  # NOT done
    """Abstract class representing RISCV instructions"""

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
        regexp_txt = RISCVInstruction._unfold_pattern(src)
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
        arg_types_in     = [RISCVInstruction._infer_register_type(r) for r in inputs]
        arg_types_out    = [RISCVInstruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [RISCVInstruction._infer_register_type(r) for r in in_outs]

        #if modifiesFlags:
        #    arg_types_out += [RegisterType.FLAGS]
        #    outputs       += ["flags"]

        #if dependsOnFlags:
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
        if s.replace('_','').isdigit():
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
        #if ty == RegisterType.FLAGS:
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
            #if ty == RegisterType.FLAGS:
            #    obj.args_in.append("flags")
            #else:
            obj.args_in.append(RISCVInstruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            #if ty == RegisterType.FLAGS:
            #    obj.args_out.append("flags")
            #else:
            obj.args_out.append(RISCVInstruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(RISCVInstruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c,"modifiesFlags", False)
        depends_on_flags = getattr(c,"dependsOnFlags", False)

        if isinstance(src, str):
            if src.split(' ')[0] != pattern.split(' ')[0]:
                raise Instruction.ParsingException("Mnemonic does not match")
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
        l = list(zip(self.args_in, self.pattern_inputs))     + \
            list(zip(self.args_out, self.pattern_outputs))   + \
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

# class qsave(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="qsave",
#                                arg_types_in=[RegisterType.NEON],
#                                arg_types_out=[RegisterType.STACK_NEON])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class qrestore(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="qrestore",
#                                arg_types_in=[RegisterType.STACK_NEON],
#                                arg_types_out=[RegisterType.NEON])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class save(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="save",
#                                arg_types_in=[RegisterType.BASE_INT],
#                                arg_types_out=[RegisterType.STACK_BASE_INT])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class restore(Instruction): # pylint: disable=missing-docstring,invalid-name
#     @classmethod
#     def make(cls, src):
#         obj = Instruction.build(cls, src, mnemonic="restore",
#                                arg_types_in=[RegisterType.STACK_BASE_INT],
#                                arg_types_out=[RegisterType.BASE_INT])
#         obj.addr = "sp"
#         obj.increment = None
#         return obj
#
# class nop(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "nop"
#
# class vadd(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "add <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
#     inputs = ["Vb", "Vc"]
#     outputs = ["Va"]
#
# class vsub(AArch64Instruction): # pylint: disable=missing-docstring,invalid-name
#     pattern = "sub <Va>.<dt0>, <Vb>.<dt1>, <Vc>.<dt2>"
#     inputs = ["Vb", "Vc"]
#     outputs = ["Va"]

############################
#                          #
# Some LSU instructions    #
#                          #
############################

#class Ldr_Q(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
#    pass

#class Ldp_Q(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
#    pass

# class d_ldp_sp_imm(Ldr_Q): # pylint: disable=missing-docstring,invalid-name
#     pattern = "ldp <Da>, <Db>, [sp, <imm>]"
#     outputs = ["Da", "Db"]
#     @classmethod
#     def make(cls, src):
#         obj = RISCVInstruction.build(cls, src)
#         obj.increment = None
#         obj.pre_index = obj.immediate
#         obj.addr = "sp"
#         return obj
#
# class q_ldr(Ldr_Q): # pylint: disable=missing-docstring,invalid-name
#     pattern = "ldr <Qa>, [<Xc>]"
#     inputs = ["Xc"]
#     outputs = ["Qa"]
#     @classmethod
#     def make(cls, src):
#         obj = RISCVInstruction.build(cls, src)
#         obj.increment = None
#         obj.pre_index = None
#         obj.addr = obj.args_in[0]
#         return obj



###########################################
# Integer Register-Immediate Instructions #
###########################################

##########
# I-Type #
##########
class RISCVBasicArithmetic(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class addi(RISCVInstruction):
    """
    Add immediate

    Adds the sign-extended 12-bit immediate to register rs1. Arithmetic overflow is ignored and the result is simply the
    low XLEN bits of the result. ADDI rd, rs1, 0 is used to implement the MV rd, rs1 assembler pseudo-instruction.
    """

    pattern = "addi <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class slti(RISCVInstruction):
    """
    Set less than immediate
    
    Place the value 1 in register Xd if register Xa is less than the signextended immediate when both are treated as
    signed numbers, else 0 is written to rd.
    """

    pattern = "slti <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class andi(RISCVInstruction):
    """
    AND immediate

    Performs bitwise AND on register Xa and the sign-extended 12-bit immediate and place the result in Xd
    """

    pattern = "andi <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class ori(RISCVInstruction):
    """
    OR immediate

    Performs bitwise OR on register Xa and the sign-extended 12-bit immediate and place the result in Xd
    """

    pattern = "ori <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class xori(RISCVInstruction):
    """
    XOR immediate

    Performs bitwise XOR on register Xa and the sign-extended 12-bit immediate and place the result in Xd.
    Note, XORI Xa, Xb, -1 performs a bitwise logical inversion of register Xa
    """

    pattern = "xori <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

##################
# Special I-Type #
##################
"""
Shifts by a constant are encoded as a specialization of the I-type format. The operand to be shifted is in rs1,
and the shift amount is encoded in the lower 5 bits of the I-immediate field. The right shift type is encoded
in bit 30.
"""

class slli(RISCVInstruction):
    """
    Logical left shift by immediate

    Performs logical left shift on the value in register Xa by the shift amount held in the lower 5 bits of the immediate.
    In RV64, bit-25 is used to shamt[5].
    """

    pattern = "slli <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class srli(RISCVInstruction):
    """
    Logical right shift by immediate

    Performs logical right shift on the value in register Xa by the shift amount held in the lower 5 bits of the immediate.
    In RV64, bit-25 is used to shamt[5].
    """

    pattern = "srli <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class srai(RISCVInstruction):
    """
    Arithmetic right shift by immediate

    Performs arithmetic right shift on the value in register Xa by the shift amount held in the lower 5 bits of the
    immediate. In RV64, bit-25 is used to shamt[5].
    """

    pattern = "srai <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

##########
# U-Type #
##########

class lui(RISCVInstruction):
    # is the input/ output register special here?
    """
    Load upper immediate

    Build 32-bit constants and uses the U-type format. LUI places the U-immediate value in the top 20 bits of the
    destination register Xd, filling in the lowest 12 bits with zeros.
    """

    pattern = "lui <Xd>, <imm>"
    outputs = ["Xd"]

class auipc(RISCVInstruction):
    # is the input/ output register special here?
    """
    Load upper immediate to pc

    Build pc-relative addresses and uses the U-type format. AUIPC forms a 32-bit offset from the 20-bit U-immediate,
    filling in the lowest 12 bits with zeros, adds this offset to the pc, then places the result in register Xd.
    """

    pattern = "auipc <Xd>, <imm>"
    outputs = ["Xd"]


###########################################
# Integer Register-Register Instructions #
###########################################

##########
# R-Type #
##########

class add(RISCVInstruction):
    """
    Add two registers

    Adds the registers Xa and Xb and stores the result in Xd.
    Arithmetic overflow is ignored and the result is simply the low XLEN bits of the result.
    """

    pattern = "add <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class slt(RISCVInstruction):
    """
    Set less than

    Place the value 1 in register Xd if register Xa is less than register Xb when both are treated as signed numbers,
    else 0 is written to Xd.
    """

    pattern = "slt <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class sltu(RISCVInstruction):
    """
    Set less than (unsigned numbers)

    Place the value 1 in register Xd if register Xa is less than register Xb when both are treated as unsigned numbers,
    else 0 is written to Xd.
    """

    pattern = "sltu <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class and_reg(RISCVInstruction):
    """
    AND two register

    Performs bitwise AND on registers Xa and Xb and place the result in Xd
    """

    pattern = "and <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class or_reg(RISCVInstruction):
    """
    OR two register

    Performs bitwise OR on registers Xa and Xb and place the result in Xd
    """

    pattern = "or <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class xor_reg(RISCVInstruction):
    """
    XOR two register

    Performs bitwise XOR on registers Xa and Xb and place the result in Xd
    """

    pattern = "xor <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class sll(RISCVInstruction):
    """
    Logical left shift by register

    Performs logical left shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "sll <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class slr(RISCVInstruction):
    """
    Logical right shift by register

    Performs logical right shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "slr <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class sub(RISCVInstruction):
    """
    Sub two register

    Subs the register Xb from Xa and stores the result in Xd.
    Arithmetic overflow is ignored and the result is simply the low XLEN bits of the result.
    """

    pattern = "sub <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class sra(RISCVInstruction):
    """
    Arithmetic right shift by register

    Performs arithmetic right shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "sra <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]
#######################################################################################################################
# Old ARM stuff from here
#######################################################################################################################

class add(RISCVBasicArithmetic): # pylint: disable=missing-docstring,invalid-name
    pattern = "add <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class RISCVShiftedArithmetic(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class add_lsl(RISCVShiftedArithmetic): # pylint: disable=missing-docstring,invalid-name
    pattern = "add <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class RISCVShift(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class lsr(RISCVShift): # pylint: disable=missing-docstring,invalid-name
    pattern = "lsr <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class RISCVLogical(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class and_imm(RISCVLogical): # pylint: disable=missing-docstring,invalid-name
    pattern = "and <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class RISCVLogicalShifted(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class orr_shifted(RISCVLogicalShifted): # pylint: disable=missing-docstring,invalid-name
    pattern = "orr <Xd>, <Xa>, <Xb>, lsl <imm>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class RISCVConditionalCompare(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class ccmp_xzr(RISCVConditionalCompare): # pylint: disable=missing-docstring,invalid-name
    pattern = "ccmp <Xa>, xzr, <imm>, <flag>"
    inputs = ["Xa"]
    modifiesFlags=True
    dependsOnFlags=True


class RISCVConditionalSelect(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class cneg(RISCVConditionalSelect): # pylint: disable=missing-docstring,invalid-name
    pattern = "cneg <Xd>, <Xe>, <flag>"
    inputs = ["Xe"]
    outputs = ["Xd"]
    dependsOnFlags=True



class RISCVMove(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class mov_imm(RISCVMove): # pylint: disable=missing-docstring,invalid-name
    pattern = "mov <Xd>, <imm>"
    inputs = []
    outputs = ["Xd"]


class RISCVHighMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class umulh_xform(RISCVHighMultiply): # pylint: disable=missing-docstring,invalid-name
    pattern = "umulh <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class RISCVMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class mul_xform(RISCVMultiply): # pylint: disable=missing-docstring,invalid-name
    pattern = "mul <Xd>, <Xa>, <Xb>"
    inputs = ["Xa","Xb"]
    outputs = ["Xd"]

class Tst(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class tst_wform(Tst): # pylint: disable=missing-docstring,invalid-name
    pattern = "tst <Wa>, <imm>"
    inputs = ["Wa"]
    modifiesFlags=True


######################################################
#                                                    #
# Some 'wrappers' around AArch64 Neon instructions   #
#                                                    #
######################################################

class vmov(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = "mov <Vd>.<dt0>, <Va>.<dt1>"
    inputs = ["Va"]
    outputs = ["Vd"]

def iter_riscv_instructions():
    yield from all_subclass_leaves(Instruction)

def find_class(src):
    for inst_class in iter_riscv_instructions():
        if isinstance(src,inst_class):
            return inst_class
    raise UnknownInstruction(f"Couldn't find instruction class for {src} (type {type(src)})")


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
    if default is None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

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
#

import re
from slothy.targets.riscv.exceptions import FatalParsingException, ParsingException
import logging


class Instruction:
    """Represents an abstract instruction"""

    def __init__(self, *, mnemonic,
                 arg_types_in=None, arg_types_in_out=None, arg_types_out=None):

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
        self.is32bit = None

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

        # self.arg_types_out.append(RegisterType.HINT)

        def add_memory_read(tag):
            self.num_in += 1
            self.args_in_restrictions.append(None)
            self.args_in.append(hint_register_name(tag))

        # self.arg_types_in.append(RegisterType.HINT)

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
        """Parsing callback triggered after DataFlowGraph parsing which allows modification
        of the instruction in the context of the overall computation.

        This is primarily used to remodel input-outputs as outputs in jointly destructive
        instruction patterns (See Section 4.4, https://eprint.iacr.org/2022/1303.pdf)."""

        _ = log  # log is not used
        return False

    def global_fusion_cb(self, a, log=None):
        """Fusion callback triggered after DataFlowGraph parsing which allows fusing
        of the instruction in the context of the overall computation.

        This can be used e.g. to detect eor-eor pairs and replace them by eor3."""

        _ = log  # log is not used
        return False

    def write(self):  # done
        """Write the instruction"""

        args = self.args_out + self.args_in_out + self.args_in
        return self.mnemonic + ' ' + ', '.join(args)

    @staticmethod
    def unfold_abbrevs(mnemonic):
        if mnemonic.count("<dt") > 1:
            for i in range(mnemonic.count("<dt")):
                mnemonic = re.sub(f"<dt{i}>", f"(?P<datatype{i}>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))",
                                  mnemonic)
        else:
            mnemonic = re.sub("<dt>", f"(?P<datatype>(?:2|4|8|16)(?:b|B|h|H|s|S|d|D))", mnemonic)
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

        # if self.datatype is None:
        #    return self._is_instance_of([Str_Q, Ldr_Q])

        # Operations on specific lanes are not counted as Q-form instructions
        # if self._is_instance_of([Q_Ld2_Lane_Post_Inc]):
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

        # return self._is_instance_of([ Ldr_Q, Ldp_Q, Ld2, Ld4, Q_Ld2_Lane_Post_Inc ])
        return False

    def is_vector_store(self):
        """Indicates if an instruction is a Neon store instruction"""

        #    return self._is_instance_of([ Str_Q, Stp_Q, St2, St4,
        #                                  d_stp_stack_with_inc, d_str_stack_with_inc])
        return False

    # scalar
    def is_scalar_load(self):
        """Indicates if an instruction is a scalar load instruction"""

        # return self._is_instance_of([ Ldr_X, Ldp_X ])
        return False

    def is_scalar_store(self):
        """Indicates if an instruction is a scalar store instruction"""

        # return  self._is_instance_of([ Stp_X, Str_X ])
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
    def build(c, src, mnemonic, **kwargs):
        """Attempt to parse a string as an instance of an instruction.

        :param c: The target instruction the string should be attempted to be parsed as.
        :param src: The string to parse.
        :param mnemonic: The mnemonic of instruction c
        :raises ParsingException: The str argument cannot be parsed as an
                instance of c.
        :raises FatalParsingException: A fatal error during parsing happened
                that's likely a bug in the model.
        :return: Upon success, the result of parsing src as an instance of c.
        """

        if src.split(' ')[0] != mnemonic:
            raise ParsingException("Mnemonic does not match")

        obj = c(mnemonic=mnemonic, **kwargs)

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(obj.mnemonic)

        expected_args = obj.num_in + obj.num_out + obj.num_in_out
        regexp_txt = rf"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += r"\s+"
        regexp_txt += ','.join([r"\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise ParsingException(
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
    def parser(src_line):
        """Global factory method parsing an assembly line into an instance
        of a subclass of Instruction."""

        insts = []
        exceptions = {}
        instnames = []

        src = src_line.text.strip()

        # Iterate through all derived classes and call their parser
        # until one of them hopefully succeeds
        for inst_class in Instruction.all_subclass_leaves(Instruction):
            try:
                inst = inst_class.make(src)
                instnames = [inst_class.__name__]
                insts = [inst]
                break
            except ParsingException as e:
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
            raise ParsingException(
                f"Couldn't parse {src}\nYou may need to add support " \
                "for a new instruction (variant)?")

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()

    def all_subclass_leaves(c):
        """Returns the list of all subclasses of a class which don't have subclasses themselves"""

        def has_subclasses(cl):
            return len(cl.__subclasses__()) > 0

        def is_leaf(c):
            return not has_subclasses(c)

        def all_subclass_leaves_core(leaf_lst, todo_lst):
            leaf_lst += filter(is_leaf, todo_lst)
            todo_lst = [csub
                        for c in filter(has_subclasses, todo_lst)
                        for csub in c.__subclasses__()]
            if len(todo_lst) == 0:
                return leaf_lst
            return all_subclass_leaves_core(leaf_lst, todo_lst)

        return all_subclass_leaves_core([], [c])

#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
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

from sympy import simplify
from enum import Enum

class RegisterType(Enum):
    GPR = 1,
    Neon = 2,
    StackNeon = 3,
    StackGPR = 4,

    def __str__(self):
        return self.name
    def __repr__(self):
        return self.name

    def list_registers(reg_type, only_extra=False, only_normal=False):
        """Return the list of all registers of a given type"""

        qstack_locations = [ f"QSTACK{i}" for i in range(8) ]
        stack_locations  = [ f"STACK{i}"  for i in range(8) ]

        gprs_normal  = [ f"x{i}" for i in range(31) ]
        vregs_normal = [ f"v{i}" for i in range(32) ]

        gprs_extra  = []
        vregs_extra = []

        gprs  = []
        vregs = []
        if not only_extra:
            gprs  += gprs_normal
            vregs += vregs_normal
        if not only_normal:
            gprs  += gprs_extra
            vregs += vregs_extra

        return { RegisterType.GPR      : gprs,
                 RegisterType.StackGPR : stack_locations,
                 RegisterType.StackNeon : qstack_locations,
                 RegisterType.Neon      : vregs }[reg_type]

    def from_string(string):
        string = string.lower()
        return { "qstack" : RegisterType.StackNeon,
                 "stack"  : RegisterType.StackGPR,
                 "neon"   : RegisterType.Neon,
                 "gpr"    : RegisterType.GPR }.get(string,None)

    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        return set()

    def default_aliases():
        return {}

class Loop:

    def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr"):
        self.lbl_start = lbl_start
        self.lbl_end   = lbl_end
        self.loop_init = loop_init
        pass

    def start(self,indentation=0, fixup=0):
        indent = ' ' * indentation
        if fixup != 0:
            yield f"{indent}sub count, count, #{fixup}"
        yield f".p2align 2"
        yield f"{self.lbl_start}:"

    def end(self,indentation=0):
        indent = ' ' * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"
        yield f"{indent}sub count, count, #1"
        yield f"{indent}cbnz {lbl_start}"

    def extract(source, lbl):
        pre  = []
        body = []
        post = []
        loop_lbl_regexp_txt = f"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)
        loop_end_regexp_txt = f"^\s*bnz\s+{lbl}" # TODO: Allow other forms of looping
        loop_end_regexp = re.compile(loop_end_regexp_txt)
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
                p = loop_end_regexp.match(l)
                if p is not None:
                    state = 2
                    continue
                body.append(l)
                continue
            if state == 2:
                post.append(l)
                continue
        if state < 2:
            raise Exception(f"Couldn't identify loop {lbl}")
        return pre, body, post, lbl

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

    def is_vector_mul(self):
        return self._is_instance_of([ mul, mla, sqrdmulh ])
    def is_vector_add_sub(self):
        return self._is_instance_of([ add, sub ])
    def is_vector_load(self):
        return self._is_instance_of([ ldr ])
    def is_vector_store(self):
        return self._is_instance_of([ str ])

    def write(self):
        args = self.args_out + self.args_in_out + self.args_in
        mnemonic = re.sub("<dt>", self.datatype, self.mnemonic)
        return mnemonic + ' ' + ', '.join(args)

    def unfold_abbrevs(mnemonic):
        mnemonic = re.sub("<dt>",  "(?P<datatype>(?:|i|u|s)(?:8|16|32|64))", mnemonic)
        mnemonic = re.sub("<fdt>", "(?P<datatype>(?:f)(?:8|16|32))", mnemonic)
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self,inst):
                return True
        return False

    def is_load_store_instruction(self):
        return self._is_instance_of([ vldr, vstr ])
    def is_vector_load(self):
        return self._is_instance_of([ vldr ])
    def is_scalar_load(self):
        return self._is_instance_of([])
    def is_load(self):
        return self.is_vector_load() or self.is_scalar_load()
    def is_vector_store(self):
        return self._is_instance_of([ vstr ])
    def is_stack_store(self):
        return self._is_instance_of([])
    def is_stack_load(self):
        return self._is_instance_of([])

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
            self.datatype = p.group("datatype")

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
        for inst_class in Instruction.__subclasses__():
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

# Virtual instruction to model pushing to stack locations without modelling memory
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

class mul(Instruction):
    def __init__(self):
        super().__init__(mnemonic="mul",
                         arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                         arg_types_out=[RegisterType.Neon])

class sqrdmulh(Instruction):
    def __init__(self):
        super().__init__(mnemonic="sqrdmulh",
                         arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                         arg_types_out=[RegisterType.Neon])

class mla(Instruction):
    def __init__(self):
        super().__init__(mnemonic="mla",
                arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                arg_types_in_out=[RegisterType.Neon])

class nop(Instruction):
    def __init__(self):
        super().__init__(mnemonic="nop")

class add(Instruction):
    def __init__(self):
        super().__init__(mnemonic="add",
                arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                arg_types_out=[RegisterType.Neon])

class sub(Instruction):
    def __init__(self):
        super().__init__(mnemonic="sub",
                arg_types_in=[RegisterType.Neon, RegisterType.Neon],
                arg_types_out=[RegisterType.Neon])

class vstr(Instruction):
    def __init__(self):
        super().__init__(mnemonic="str",
                arg_types_in=[RegisterType.Neon, RegisterType.GPR])

    def _simplify(self):
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

        str_regexp_txt  = "\s*str\s+"
        str_regexp_txt += "(?P<dest>\w+),\s*"
        str_regexp_txt += addr_regexp_txt
        str_regexp_txt += postinc_regexp_txt
        str_regexp_txt = Instruction.unfold_abbrevs(str_regexp_txt)

        str_regexp = re.compile(str_regexp_txt)

        p = str_regexp.match(src)
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

        self.args_in     = [ vec, self.addr ]
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
        super().__init__(mnemonic="ldr",
                arg_types_in=[RegisterType.GPR],
                arg_types_out=[RegisterType.Neon])

    def _simplify(self):
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

        ldr_regexp_txt  = "\s*ldr\s+"
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

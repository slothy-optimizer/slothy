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

import re

class NestedPrint():
    def __str__(self):
        top = [ self.__class__.__name__ + ":" ]
        res = []
        indent = ' ' * 8
        for name, value in vars(self).items():
            res += f"{name}: {value}".splitlines()
        res = top + [ indent + r for r in res ]
        return '\n'.join(res)
    def log(self, fun):
        [ fun(l) for l in str(self).splitlines() ]

class LockAttributes(object):
    """Base class adding support for 'locking' the set of attributes, that is,
       preventing the creation of any further attributes. Note that the modification
       of already existing attributes remains possible.

       Our primary use case is for configurations, where this class is used to catch typos
       in the user configuration."""
    def __init__(self):
        self.__dict__["_locked"] = False
    def lock(self):
        self._locked = True
    def __setattr__(self, attr, val):
        if self._locked and attr not in dir(self):
            varlist = [v for v in dir(self) if not v.startswith("_") ]
            varlist = '\n'.join(map(lambda x: '* ' + x, varlist))
            raise TypeError(f"Unknown attribute {attr}. \nValid attributes are:\n{varlist}")
        elif self._locked and attr == "_locked":
            raise TypeError("Can't unlock an object")
        object.__setattr__(self,attr,val)

class AsmMacro():

    def __init__(self, name, args, body):
        self.name = name
        self.args = args
        self.body = body

    def __call__(self,args_dict):
        output = []
        for l in self.body:
            for arg in self.args:
                l = re.sub(f"\\\\{arg}(\W|$)",args_dict[arg] + "\\1",l)
            l = re.sub(f"\\\\\(\)","",l)
            output.append(l)
        return output

    def __repr__(self):
        return self.name

    def unfold_in(self, source, change_callback=None):

        macro_regexp_txt = f"^\s*{self.name}\s+"
        arg_regexps = []
        for arg in self.args:
            arg_regexps.append(f"\s*(?P<{arg}>\w+)\s*")
        macro_regexp_txt += ','.join(arg_regexps)
        macro_regexp = re.compile(macro_regexp_txt)

        output = []

        indentation_regexp_txt = "^(?P<whitespace>\s*)($|\S)"
        indentation_regexp = re.compile(indentation_regexp_txt)

        # Go through source line by line and check if there's a macro invocation
        for l in source:
            p = macro_regexp.match(l)
            if p is None:
                output.append(l)
                continue
            if change_callback:
                change_callback()
            # Try to keep indentation
            indentation = indentation_regexp.match(l).group("whitespace")
            repl = [ indentation + s.strip() for s in self(p.groupdict())]
            output += repl

        return output

    def unfold_all(macros, source):

        def list_of_instances(l,c):
            return isinstance(l,list) and all(map(lambda m: isinstance(m,c), l))
        def dict_of_instances(l,c):
            return isinstance(l,dict) and list_of_instances(list(l.values()), c)
        if isinstance(macros,str):
            macros = macros.splitlines()
        if list_of_instances(macros, str):
            macros = AsmMacro.extract(macros)
        if not dict_of_instances(macros, AsmMacro):
            raise Exception(f"Invalid argument: {macros}")

        change = True
        while change:
            change = False
            def cb():
                nonlocal change
                change = True
            for m in macros.values():
                source = m.unfold_in(source, change_callback=cb)
        return source

    def extract(source):

        macros = {}

        state = 0 # 0: Not in a macro 1: In a macro
        current_macro = None
        current_args = None
        current_body = None

        macro_start_regexp_txt = "^\s*\.macro\s+(?P<name>\w+)(?:\b|(?P<args>.*))$"
        macro_start_regexp = re.compile(macro_start_regexp_txt)

        slothy_no_unfold_regexp_txt = ".*//\s*slothy:\s*no-unfold\s*$"
        slothy_no_unfold_regexp = re.compile(slothy_no_unfold_regexp_txt)

        macro_end_regexp_txt = "^\s*\.endm\s*$"
        macro_end_regexp = re.compile(macro_end_regexp_txt)

        for cur in source:

            if state == 0:

                p = macro_start_regexp.match(cur)
                if p is None:
                    continue

                # Ignore macros with "// slothy:no-unfold" annotation
                if slothy_no_unfold_regexp.match(cur) is not None:
                    continue

                current_args = [ a.strip() for a in p.group("args").split(',') ]
                current_macro = p.group("name")
                current_body = []

                state = 1
                continue

            if state == 1:
                p = macro_end_regexp.match(cur)
                if p is None:
                    current_body.append(cur)
                    continue

                macros[current_macro] = AsmMacro(current_macro, current_args, current_body)

                current_macro = None
                current_body = None
                current_args = None

                state = 0
                continue

        return macros

    def extract_from_file(filename):
        f = open(filename,"r")
        return AsmMacro.extract(f.read().splitlines())

class AsmHelper():

    def rename_function(source, old_funcname, new_funcname):
        # For now, just replace function names line by line
        def change_funcname(s):
            s = re.sub( f"{old_funcname}:", f"{new_funcname}:", s)
            s = re.sub( f"\.global(\s+){old_funcname}", f".global\\1{new_funcname}", s)
            s = re.sub( f"\.type(\s+){old_funcname}", f".type\\1{new_funcname}", s)
            return s
        return '\n'.join([ change_funcname(s) for s in source.splitlines() ])

    def remove_noncode(source):
        if isinstance(source,str):
            source = source.splitlines()

    def reduce_source_line(line):
        regexp_align_txt = f"^\s*\.(?:p2)?align"
        regexp_req_txt   = f"\s*(?P<alias>\w+)\s+\.req\s+(?P<reg>\w+)"
        regexp_unreq_txt = f"\s*\.unreq\s+(?P<alias>\w+)"
        regexp_align = re.compile(regexp_align_txt)
        regexp_req   = re.compile(regexp_req_txt)
        regexp_unreq = re.compile(regexp_unreq_txt)

        def strip_comment(s):
            s = s.split("//")[0]
            s = re.sub("/\*[^*]*\*/","",s)
            return s.strip()
        def is_empty(s):
            return s == ""
        def is_asm_directive(s):
            # We only accept (and ignore) .req and .unreqs in code so far
            return sum([ regexp_req.match(s)   is not None,
                         regexp_unreq.match(s) is not None,
                         regexp_align.match(s) is not None ]) > 0

        line = strip_comment(line)
        if is_empty(line):
            return
        if is_asm_directive(line):
            return
        return line

    def reduce_source(src, allow_nops=True):
        if isinstance(src,str):
            src = src.splitlines()
        def filter_nop(src):
            if allow_nops:
                return True
            return src != "nop"
        src = map(AsmHelper.reduce_source_line, src)
        src = filter(lambda x: x != None, src)
        src = filter(filter_nop, src)
        src = list(src)
        return src

    def extract(source, lbl_start=None, lbl_end=None):
        """Extract code between two labels from an assembly source"""
        pre, body, post = AsmHelper._extract_core(source, lbl_start, lbl_end)
        body = AsmHelper.reduce_source(body, allow_nops=False)
        return pre, body, post

    def _extract_core(source, lbl_start=None, lbl_end=None):

        pre  = []
        body = []
        post = []

        lines = iter(source.splitlines())
        source = source.splitlines()
        if lbl_start == None and lbl_end == None:
            body = source
            return pre, body, post

        loop_lbl_regexp_txt = f"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)
        l = None
        keep = False
        state = 0 # 0: haven't found initial label yet, 1: between labels, 2: after snd label

        # If no start label is provided, scan from the start to the end label
        if lbl_start == None:
            state = 1

        idx=0
        while True:
            idx += 1
            if not keep:
                l = next(lines, None)
            if l == None:
                break
            keep = False
            if state == 2:
                post.append(l)
                continue
            expect_label = [ lbl_start, lbl_end ][state]
            cur_buf = [ pre, body ][state]
            p = loop_lbl_regexp.match(l)
            if p is not None and p.group("label") == expect_label:
                l = p.group("remainder")
                keep = True
                state += 1
                continue
            cur_buf.append(l)
            continue

        if state < 2:
            if lbl_start != None and lbl_end != None:
                raise Exception(f"Failed to identify region {lbl_start}-{lbl_end}")
            if state == 0:
                if lbl_start != none:
                    lbl = lbl_start
                else:
                    lbl = lbl_end
                raise Exception(f"Couldn't find label {lbl}")

        return pre, body, post

class AsmAllocation():

    def __init__(self, Arch):
        self.Arch = Arch
        self.allocations = {}
        self.regexp_req_txt   = f"\s*(?P<alias>\w+)\s+\.req\s+(?P<reg>\w+)"
        self.regexp_unreq_txt = f"\s*\.unreq\s+(?P<alias>\w+)"
        self.regexp_req   = re.compile(self.regexp_req_txt)
        self.regexp_unreq = re.compile(self.regexp_unreq_txt)

    def _add_allocation(self, alias, reg):
        if alias in self.allocations.keys():
            raise Exception(f"Double definition of alias {alias}")
        if reg in self.allocations.keys():
            reg_name = self.allocations[reg]
        else:
            reg_name = reg
        self.allocations[alias] = reg_name

    def _remove_allocation(self, alias):
        if not alias in self.allocations.keys():
            raise Exception(f"Couldn't find alias {alias} -- .unreq without .req in your source?")
        del self.allocations[alias]
        return

    def parse_line(self, line):

        # Check if it's an allocation
        p = self.regexp_req.match(line)
        if p is not None:
            alias = p.group("alias")
            reg = p.group("reg")
            self._add_allocation(alias,reg)
            return

        # Regular expression for a definition removal
        p = self.regexp_unreq.match(line)
        if p is not None:
            alias = p.group("alias")
            self._remove_allocation(alias)
            return

        # We ignore everything else

    def parse(self, src):
        for s in src:
            self.parse_line(s)

    def parse_allocs(arch, src):
        allocs = AsmAllocation(arch)
        allocs.parse(src)
        return allocs.allocations

class BinarySearchLimitException(Exception):
    pass

def binary_search(func, threshold=64, minimum=-1, start=0, precision=1):
    start = max(start,minimum)
    last_failure = minimum
    val = start
    # Find _some_ version that works
    while True:
        if val > threshold:
            raise BinarySearchLimitException
        def double_val(val):
            if val == 0:
                return 1
            return 2*val
        success, result = func(val)
        if success:
            last_success = val
            last_success_core = result
            break
        last_failure = val
        val = double_val(val)
    # Find _first_ version that works
    while last_success - last_failure > precision:
        val = last_failure + ( last_success - last_failure ) // 2
        success, result = func(val)
        if success:
            last_success = val
            last_success_core = result
        else:
            last_failure = val
    return last_success_core

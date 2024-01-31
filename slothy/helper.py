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

import re
import subprocess
import logging

class SourceLine:
    """Representation of a single line of source code"""

    def _extract_comments_from_text(self):
        if not "//" in self._raw:
            return
        s = list(map(str.strip, self._raw.split("//")))
        self._raw = s[0]
        self._comments += s[1:]
        self._trim_comments()

    def _extract_indentation_from_text(self):
        old = self._raw
        new = old.lstrip()
        self._indentation = len(old) - len(new)
        self._raw = new

    @staticmethod
    def _parse_tags_in_string(s, tags):
        def parse_value(v):
            if v.lower() == "true":
                return True
            if v.lower() == "false":
                return False
            if v.isnumeric():
                return int(v)
            return v

        def tag_value_callback(g):
            tag = g.group("tag")
            value = parse_value(g.group("value"))
            tags[tag] = value
            return ""

        def tag_callback(g):
            tag = g.group("tag")
            tags[tag] = True
            return ""

        tag_value_regexp_txt = r"@slothy:(?P<tag>(\w|-)+)=(?P<value>\w+)"
        tag_regexp_txt = r"@slothy:(?P<tag>(\w|-)+)"
        s = re.sub(tag_value_regexp_txt, tag_value_callback, s)
        s = re.sub(tag_regexp_txt, tag_callback, s)
        return s

    def _strip_comments(self):
        self._comments = list(map(str.strip, self._comments))

    def _trim_comments(self):
        self._strip_comments()
        self._comments = list(filter(lambda s: s != "", self._comments))

    def _extract_tags_from_comments(self):
        tags = {}
        self._comments = list(map(lambda c: SourceLine._parse_tags_in_string(c, tags),
            self._comments))
        self._trim_comments()
        self.add_tags(tags)

    def reduce(self):
        """Extract metadata (tags, comments, indentation) from raw text

        The extracted components get retracted from the text."""
        self._extract_indentation_from_text()
        self._extract_comments_from_text()
        self._extract_tags_from_comments()
        return self

    def add_comment(self, comment):
        """Add a comment to the metadata of a source line"""
        self._comments.append(comment)
        return self

    def add_comments(self, comments):
        """Add one or more comments to the metadata of a source line"""
        for c in comments:
            self.add_comment(c)
        return self

    def set_comments(self, comments):
        """Set comments for source line.

        Overwrites existing comments."""
        self._comments = comments
        return self

    def set_comment(self, comment):
        """Set single comment for source line.

        Overwrites existing comments."""
        self.set_comments([comment])
        return self

    def __init__(self, s, reduce=True):
        """Create source line from string"""
        assert isinstance(s, str)

        self._raw = s
        self._tags = {}
        self._indentation = 0
        self._fixlength = None
        self._comments = []

        if reduce is True:
            self.reduce()

    def set_tag(self, tag, value=True):
        """Set source line tag"""
        self._tags[tag] = value
        return self

    def set_length(self, length):
        """Set the padded length of the text component of the source line

        When printing the source line with to_string(), the source text will be
        whitespace padded to the specified length before adding comments and tags.
        This allows to print multiple commented source lines with a uniform
        indentation for the comments, improving readability."""
        self._fixlength = length
        return self

    @property
    def tags(self):
        """Return the list of tags for the source line

        Tags are source annotations of the form @slothy:(tag[=value]?).
        """
        return self._tags
    @tags.setter
    def tags(self, v):
        self._tags = v

    @property
    def comments(self):
        """Return the list of comments for the source line"""
        return self._comments
    @comments.setter
    def comments(self, v):
        self._comments = v

    def has_text(self):
        """Indicates if the source line constaints some text"""
        return self._raw.strip() != ""

    @property
    def text(self):
        """Returns the (non-metadata) text in the source line"""
        return self._raw

    def to_string(self, indentation=False, comments=False, tags=False):
        """Convert source line to a string

        This includes formatting the metadata in a way reversing the
        parsing done in the _extract_xxx() routines."""
        if self._fixlength is None:
            core = self._raw
        else:
            core = f"{self._raw:{self._fixlength}s}"

        indentation = ' ' * self._indentation \
            if indentation is True else ""

        double_comments = filter(lambda t: not t.startswith("/"), self._comments)
        triple_comments = map(lambda s: (" " + s[1:].strip()).rstrip(),
                              filter(lambda t: t.startswith("/"), self._comments))

        additional = []

        if comments is True:
            additional += list(map(lambda s: f"// {s}", double_comments))
            additional += list(map(lambda s: f"///{s}", triple_comments))

        if tags is True:
            additional += list(map(lambda tv: f"// @slothy:{tv[0]}={tv[1]}", self._tags.items()))

        add_str = ' '.join(additional)

        return f"{indentation}{core}{add_str}".rstrip()

    def __str__(self):
        return self.to_string()

    @staticmethod
    def reduce_source(src):
        """Extract metadata (e.g. indentation, tags, comments) from source lines"""
        assert SourceLine.is_source(src)
        for l in src:
            l.reduce()
        return [ l for l in src if l.has_text() and not AsmHelper.is_alignment_directive(l) ]

    @staticmethod
    def log(name, s, logger=None, err=False):
        """Send source to logger"""
        assert isinstance(s, list)
        if err:
            fun = logger.error
        else:
            fun = logger.debug
        if len(s) == 0:
            return
        fun(f"Dump: {name}")
        for l in s:
            fun(f"> {l}")

    def set_text(self, s):
        """Set the text of the source line

        This only affects the instruction text of the source line, but leaves
        metadata (such as comments, indentation or tags) unmodified."""
        self._raw = s
        return self

    def add_text(self, s):
        """Add text to a source line

        This only affects the instruction text of the source line, but leaves
        metadata (such as comments, indentation or tags) unmodified."""
        self._raw += " " + s
        return self

    @property
    def is_escaped(self):
        """Indicates if line text ends with a backslash"""
        return self.text.endswith("\\")

    def remove_escaping(self):
        """Remove escape character at end of line, if present"""
        if not self.is_escaped:
            return self
        self._raw = self._raw[:-1]
        return self

    def __len__(self):
        return len(self._raw)

    def copy(self):
        """Create a copy of a source line"""
        return SourceLine(self._raw)                \
                .add_tags(self._tags.copy())        \
                .set_indentation(self._indentation) \
                .add_comments(self._comments.copy())\
                .set_length(self._fixlength)

    @staticmethod
    def read_multiline(s, reduce=True):
        """Parse multi-line string or array of strings into list of SourceLine instances"""
        if isinstance(s, str):
            s = s.splitlines()
        return SourceLine.merge_escaped_lines([ SourceLine(l, reduce=reduce) for l in s ])

    @staticmethod
    def merge_escaped_lines(s):
        """Merge lines ending in a backslash with subsequent line(s)"""
        assert SourceLine.is_source(s)
        res = []
        cur = None
        for l in s:
            if cur is not None:
                cur.add_text(l.text)
            else:
                cur = l.copy()
            if cur.is_escaped:
                cur.remove_escaping()
            else:
                res.append(cur)
                cur = None
        assert cur is None
        return res

    @staticmethod
    def copy_source(s):
        """Create a copy of a list of source lines"""
        assert SourceLine.is_source(s)
        return [ l.copy() for l in s ]

    @staticmethod
    def write_multiline(s, comments=True, indentation=True, tags=True):
        """Write source as multiline string"""
        return '\n'.join(map(lambda t: t.to_string(
            comments=comments, tags=tags, indentation=indentation), s))

    def set_indentation(self, indentation):
        """Set the indentation (in number of spaces) to be used in to_string()"""
        self._indentation = indentation
        return self

    def add_tags(self, tags):
        """Add one or more tags to the metadata of the source line

        tags must be a tag:value dictionary."""
        self._tags = {**self._tags, **tags}
        return self

    def add_tag(self, tag, value):
        """Add a single tag-value pair to the metadata of the source line

        If a tag is already specified, it is overwritten."""
        return self.add_tags({ tag: value })

    def inherit_tags(self, l):
        """Inhertis the tags from another source line

        In case of overlapping tags, source line l takes precedence."""
        assert SourceLine.is_source_line(l)
        self.add_tags(l.tags)
        return self

    def inherit_comments(self, l):
        """Inhertis the comments from another source line"""
        assert SourceLine.is_source_line(l)
        self.add_comments(l.comments)
        return self

    @staticmethod
    def apply_indentation(source, indentation):
        """Apply consistent indentation to assembly source"""
        assert SourceLine.is_source(source)
        if indentation is None:
            return source
        assert isinstance(indentation, int)
        return [ l.copy().set_indentation(indentation) for l in source ]

    @staticmethod
    def drop_tags(source):
        """Drop all tags from a source"""
        assert SourceLine.is_source(source)
        for l in source:
            l.tags = {}
        return source

    @staticmethod
    def split_semicolons(s):
        """"Split the text of a source line at semicolons

        The resulting source lines inherit their metadata from the caller."""
        assert SourceLine.is_source(s)
        res = []
        for line in s:
            for l in str(line).split(';'):
                t = line.copy()
                t.set_text(l)
                res.append(t)
        return res

    @staticmethod
    def is_source(s):
        """Check if parameter is a list of SourceLine instances"""
        if isinstance(s, list) is False:
            return False
        for t in s:
            if isinstance(t, SourceLine) is False:
                return False
        return True

    @staticmethod
    def is_source_line(s):
        """Checks if the parameter is a SourceLine instance"""
        return isinstance(s, SourceLine)

class NestedPrint():
    """Helper for recursive printing of structures"""
    def __str__(self):
        top = [ self.__class__.__name__ + ":" ]
        res = []
        indent = ' ' * 8
        for name, value in vars(self).items():
            res += f"{name}: {value}".splitlines()
        res = top + [ indent + r for r in res ]
        return '\n'.join(res)
    def log(self, fun):
        """Pass self-description line-by-line to logging function"""
        for l in str(self).splitlines():
            fun(l)

class LockAttributes:
    """Base class adding support for 'locking' the set of attributes, that is,
       preventing the creation of any further attributes. Note that the modification
       of already existing attributes remains possible.

       Our primary use case is for configurations, where this class is used to catch typos
       in the user configuration."""
    def __init__(self):
        self.__dict__["_locked"] = False
        self._locked = False
    def lock(self):
        """Lock set of attributes"""
        self._locked = True
    def __setattr__(self, attr, val):
        if self._locked and attr not in dir(self):
            varlist = [v for v in dir(self) if not v.startswith("_") ]
            varlist = '\n'.join(map(lambda x: '* ' + x, varlist))
            raise TypeError(f"Unknown attribute {attr}. \nValid attributes are:\n{varlist}")
        if self._locked and attr == "_locked":
            raise TypeError("Can't unlock an object")
        object.__setattr__(self,attr,val)

class AsmHelperException(Exception):
    """An exception encountered during an assembly helper"""

class AsmHelper():
    """Some helper functions for dealing with assembly"""

    _REGEXP_ALIGN_TXT = r"^\s*\.(?:p2)?align"
    _REGEXP_ALIGN = re.compile(_REGEXP_ALIGN_TXT)

    @staticmethod
    def find_indentation(source):
        """Attempts to find the prevailing indentation in a piece of assembly"""

        def get_indentation(l):
            return len(l) - len(l.lstrip())

        source = map(str, source)
        # Remove empty lines
        source = list(filter(lambda t: t.strip() != "", source))
        l = len(source)

        if l == 0:
            return None

        indentations = list(map(get_indentation, source))

        # Some labels may use a different indentation -- here, we just check if
        # there's a dominant indentation
        top_start = (3 * l) // 4
        indentations.sort()
        indentations = indentations[top_start:]

        if indentations[0] == indentations[-1]:
            return indentations[0]

        return None

    @staticmethod
    def rename_function(source, old_funcname, new_funcname):
        """Rename function in assembly snippet"""

        # For now, just replace function names line by line
        def change_funcname(line):
            s = str(line)
            s = re.sub( f"{old_funcname}:", f"{new_funcname}:", s)
            s = re.sub( f"\\.global(\\s+){old_funcname}", f".global\\1{new_funcname}", s)
            s = re.sub( f"\\.type(\\s+){old_funcname}", f".type\\1{new_funcname}", s)
            return line.copy().set_text(s)
        return [ change_funcname(s) for s in source ]

    @staticmethod
    def is_alignment_directive(line):
        """Checks is source line is an alignment directive `.[p2]align _`"""
        assert SourceLine.is_source_line(line)
        return AsmHelper._REGEXP_ALIGN.match(line.text) is not None

    @staticmethod
    def extract(source, lbl_start=None, lbl_end=None):
        """Extract code between two labels from an assembly source"""
        pre, body, post = AsmHelper._extract_core(source, lbl_start, lbl_end)
        body = SourceLine.reduce_source(body)
        return pre, body, post

    @staticmethod
    def _extract_core(source, lbl_start=None, lbl_end=None):
        pre  = []
        body = []
        post = []

        lines = iter(source)
        if lbl_start is None and lbl_end is None:
            body = source
            return pre, body, post

        loop_lbl_regexp_txt = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        loop_lbl_regexp = re.compile(loop_lbl_regexp_txt)
        l = None
        keep = False
        state = 0 # 0: haven't found initial label yet, 1: between labels, 2: after snd label

        # If no start label is provided, scan from the start to the end label
        if lbl_start is None:
            state = 1

        idx=0
        while True:
            idx += 1
            if not keep:
                l = next(lines, None)
                l_str = str(l)
            if l is None:
                break
            keep = False
            if state == 2:
                post.append(l)
                continue
            expect_label = [ lbl_start, lbl_end ][state]
            cur_buf = [ pre, body ][state]
            p = loop_lbl_regexp.match(l_str)
            if p is not None and p.group("label") == expect_label:
                l = l.copy().set_text(p.group("remainder"))
                keep = True
                state += 1
                continue
            cur_buf.append(l)
            continue

        if state < 2:
            if lbl_start is not None and lbl_end is not None:
                raise AsmHelperException(f"Failed to identify region {lbl_start}-{lbl_end}")
            if state == 0:
                if lbl_start is not None:
                    lbl = lbl_start
                else:
                    lbl = lbl_end
                raise AsmHelperException(f"Couldn't find label {lbl}")

        return pre, body, post

class AsmAllocation():
    """Helper for tracking register aliases via .req and .unreq"""

    _REGEXP_REQ_TXT = r"\s*(?P<alias>\w+)\s+\.req\s+(?P<reg>\w+)"
    _REGEXP_UNREQ_TXT = r"\s*\.unreq\s+(?P<alias>\w+)"

    _REGEXP_REQ   = re.compile(_REGEXP_REQ_TXT)
    _REGEXP_UNREQ = re.compile(_REGEXP_UNREQ_TXT)

    def __init__(self):
        self.allocations = {}

    def _add_allocation(self, alias, reg):
        if alias in self.allocations:
            raise AsmHelperException(f"Double definition of alias {alias}")
        if reg in self.allocations:
            reg_name = self.allocations[reg]
        else:
            reg_name = reg
        self.allocations[alias] = reg_name

    def _remove_allocation(self, alias):
        if not alias in self.allocations:
            raise AsmHelperException(f"Couldn't find alias {alias} --"
                                     " .unreq without .req in your source?")
        del self.allocations[alias]

    @staticmethod
    def check_allocation(line):
        """Check if an assembly line is a .req directive. Return the pair
        of alias and register, if so. Otherwise, return None."""
        assert SourceLine.is_source_line(line)

        p = AsmAllocation._REGEXP_REQ.match(line.text)
        if p is not None:
            alias = p.group("alias")
            reg = p.group("reg")
            return alias, reg

        return None

    @staticmethod
    def check_deallocation(line):
        """Check if an assembly line is an .unreq directive. Return
        the deallocated alias, if so. Otherwise, return None."""
        assert SourceLine.is_source_line(line)

        p = AsmAllocation._REGEXP_UNREQ.match(line.text)
        if p is not None:
            alias = p.group("alias")
            return alias

        return None

    @staticmethod
    def is_allocation(line):
        return AsmAllocation.check_allocation(line) is not None

    @staticmethod
    def is_deallocation(line):
        return AsmAllocation.check_deallocation(line) is not None

    def parse_line(self, line):
        """Check if an assembly line is a .req .unreq directive, and update the
        alias dictionary accordingly. Otherwise, do nothing."""
        assert SourceLine.is_source_line(line)

        r = AsmAllocation.check_allocation(line)
        if r is not None:
            alias, reg = r
            self._add_allocation(alias,reg)
            return

        r = AsmAllocation.check_deallocation(line)
        if r is not None:
            alias = r
            self._remove_allocation(alias)
            return

        # We ignore everything else

    def parse(self, src):
        """Build register alias dictionary from assembly source"""
        for s in src:
            self.parse_line(s)

    @staticmethod
    def parse_allocs(src):
        """"Parse register aliases in assembly source into AsmAllocation object."""
        allocs = AsmAllocation()
        allocs.parse(src)
        return allocs.allocations

    @staticmethod
    def unfold_all_aliases(aliases, src):
        """Unfold aliases in assembly source"""
        def _apply_single_alias_to_line(alias_from, alias_to, src):
            return re.sub(f"(\\W){alias_from}(\\W|\\Z)", f"\\1{alias_to}\\2", src)
        def _apply_multiple_aliases_to_line(line):
            for (alias_from, alias_to) in aliases.items():
                line = _apply_single_alias_to_line(alias_from, alias_to, line)
            return line
        res = []
        for line in src:
            l = str(line)
            t = line.copy()
            t.set_text(_apply_multiple_aliases_to_line(l))
            res.append(t)
        return res

class BinarySearchLimitException(Exception):
    """Binary search has exceeded its limit without finding a solution"""

def binary_search(func, threshold=256, minimum=-1, start=0, precision=1,
                  timeout_below_precision=None):
    """Conduct a binary search"""
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
    while last_success - last_failure > 1:
        timeout = None
        if last_success - last_failure <= precision:
            if timeout_below_precision is None:
                break
            timeout = timeout_below_precision
        val = last_failure + ( last_success - last_failure ) // 2
        success, result = func(val, timeout=timeout)
        if success:
            last_success = val
            last_success_core = result
        else:
            last_failure = val
    return last_success, last_success_core

class AsmMacro():
    """Helper class for parsing and applying assembly macros"""

    def __init__(self, name, args, body):
        self.name = name
        self.args = args
        self.body = body

    def __call__(self,args_dict):
        output = []
        for line in self.body:
            l = str(line)
            for arg in self.args:
                l = re.sub(f"\\\\{arg}(\\W|$)",args_dict[arg] + "\\1",l)
            l = re.sub("\\\\\\(\\)","",l)
            t = line.copy()
            t.set_text(l)
            output.append(t)
        return output

    def __repr__(self):
        return self.name

    def unfold_in(self, source, change_callback=None, inherit_comments=False):
        """Unfold all applications of macro in assembly source"""
        assert SourceLine.is_source(source)

        macro_regexp_txt = rf"^\s*{self.name}"
        arg_regexps = []
        if self.args == [""]:
            while True:
                continue

        if len(self.args) > 0:
            macro_regexp_txt = macro_regexp_txt + "\\s+"

        for arg in self.args:
            arg_regexps.append(rf"\s*(?P<{arg}>[^,]+)\s*")

        macro_regexp_txt += ','.join(arg_regexps)
        macro_regexp = re.compile(macro_regexp_txt)

        output = []

        indentation_regexp_txt = r"^(?P<whitespace>\s*)($|\S)"
        indentation_regexp = re.compile(indentation_regexp_txt)

        # Go through source line by line and check if there's a macro invocation
        for l in SourceLine.reduce_source(source):
            assert SourceLine.is_source_line(l)

            if l.has_text():
                p = macro_regexp.match(l.text)
            else:
                p = None

            if p is None:
                output.append(l)
                continue
            if change_callback:
                change_callback()
            # Try to keep indentation
            indentation = len(indentation_regexp.match(l.text).group("whitespace"))
            repl = self(p.groupdict())
            for l0 in repl:
                l0.set_indentation(indentation)
                l0.inherit_tags(l)
                if inherit_comments is True:
                    l0.inherit_comments(l)
            output += repl

        return output

    @staticmethod
    def unfold_all_macros(macros, source, **kwargs):
        """Unfold list of macros in assembly source"""
        assert isinstance(macros, list)
        assert SourceLine.is_source(source)
        def list_of_instances(l,c):
            return isinstance(l,list) and all(map(lambda m: isinstance(m,c), l))
        def dict_of_instances(l,c):
            return isinstance(l,dict) and list_of_instances(list(l.values()), c)
        if SourceLine.is_source(macros):
            macros = AsmMacro.extract(macros)
        if not dict_of_instances(macros, AsmMacro):
            raise AsmHelperException(f"Invalid argument: {macros}")

        change = True
        while change:
            change = False
            def cb():
                nonlocal change
                change = True
            for m in macros.values():
                source = m.unfold_in(source, change_callback=cb, **kwargs)
        return source

    @staticmethod
    def extract(source):
        """Parse all macro definitions in assembly source file"""

        macros = {}

        state = 0 # 0: Not in a macro 1: In a macro
        current_macro = None
        current_args = None
        current_body = None

        macro_start_regexp_txt = r"^\s*\.macro\s+(?P<name>\w+)(?P<args>.*)$"
        macro_start_regexp = re.compile(macro_start_regexp_txt)

        macro_end_regexp_txt = r"^\s*\.endm\s*$"
        macro_end_regexp = re.compile(macro_end_regexp_txt)

        for cur in source:
            cur_str = str(cur)

            if state == 0:

                p = macro_start_regexp.match(cur_str)
                if p is None:
                    continue

                if cur.tags.get("no-unfold", None) is not None:
                    continue

                current_args = [ a.strip() for a in p.group("args").split(',') ]
                current_macro = p.group("name")
                current_body = []

                if current_args == ['']:
                    current_args = []

                state = 1
                continue

            if state == 1:
                p = macro_end_regexp.match(cur_str)
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

    @staticmethod
    def extract_from_file(filename):
        """Parse all macro definitions in assembly file"""
        with open(filename,"r",encoding="utf-8") as f:
            res = AsmMacro.extract(f.read().splitlines())
        return res

class CPreprocessor():
    """Helper class for the application of the C preprocessor"""

    magic_string = "SLOTHY_PREPROCESSED_REGION"

    @staticmethod
    def unfold(header, body, gcc):
        """Runs the concatenation of header and body through the preprocessor"""

        assert SourceLine.is_source(body)
        assert SourceLine.is_source(header)

        body_txt = SourceLine.write_multiline(body)
        header_txt = SourceLine.write_multiline(header)

        code_txt = '\n'.join([header_txt, CPreprocessor.magic_string, body_txt])

        # Pass -CC to keep comments
        r = subprocess.run([gcc, "-E", "-CC", "-x", "assembler-with-cpp","-"],
                           input=code_txt, text=True, capture_output=True, check=True)

        unfolded_code = r.stdout.split('\n')
        magic_idx = unfolded_code.index(CPreprocessor.magic_string)
        unfolded_code = unfolded_code[magic_idx+1:]

        return unfolded_code

class Permutation():
    """Helper class for manipulating permutations"""

    @staticmethod
    def is_permutation(perm, sz):
        """Checks whether dictionary perm is a permutation of size sz."""
        err = False
        k = list(perm.keys())
        k.sort()
        v = list(perm.values())
        v.sort()
        if k != list(range(sz)):
            err = True
        if v != list(range(sz)):
            err = True
        if err:
            print(f"Keys:   {k}")
            print(f"Values: {v}")
        return err is False

    @staticmethod
    def permutation_id(sz):
        """Return the identity permutation of size sz."""
        return { i:i for i in range(sz) }

    @staticmethod
    def permutation_comp(p_b, p_a):
        """Compose two permutations.

        This computes 'p_b o p_a', that is, 'p_a first, then p_b'."""
        l_a = len(p_a.values())
        l_b = len(p_b.values())
        assert l_a == l_b
        return { i:p_b[p_a[i]] for i in range(l_a) }

    @staticmethod
    def permutation_pad(perm,pre,post):
        """Pad permutation with identity permutation at front and back"""
        s = len(perm.values())
        r = {}
        r = r | { pre + i : pre + j for (i,j) in perm.items() if isinstance(i, int) }
        r = r | { i:i for i in range(pre) }
        r = r | { i:i for i in map(lambda i: i + s + pre, range(post)) }
        return r

    @staticmethod
    def permutation_move_entry_forward(l, idx_from, idx_to):
        """Create transposition permutation"""
        assert idx_to <= idx_from
        res = {}
        res = res | { i:i for i in range(idx_to) }
        res = res | { i:i+1 for i in range(idx_to,  idx_from) }
        res = res | { idx_from : idx_to }
        res = res | { i:i for i in range (idx_from + 1, l) }
        return res

    @staticmethod
    def iter_swaps(p, n):
        """Iterate over all inputs that have their order reversed by
        the permutation."""
        return ((i,j,p[i],p[j]) for i in range(n) for j in range(n) \
            if i < j and p[j] < p[i])


class DeferHandler(logging.Handler):
    """Handler collecting all records produced by a logger and relaying
    them to the same or different logger later."""
    def __init__(self):
        super().__init__()
        self._records = []
    def emit(self, record):
        self._records.append(record)
    def forward(self, logger):
        """Send all captured records to the given logger"""
        for r in self._records:
            logger.handle(r)
        self._records = []

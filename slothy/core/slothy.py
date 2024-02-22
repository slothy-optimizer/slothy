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

"""SLOTHY optimizer

SLOTHY - Super Lazy Optimization of Tricky Handwritten assemblY - is a
fixed-instruction assembly superoptimizer based on constraint solving.
It takes handwritten assembly as input and simultaneously super-optimizes:

- Instruction scheduling
- Register allocation
- Software pipelining

SLOTHY enables a development workflow where developers write 'clean' assembly by hand,
emphasizing the logic of the computation, while SLOTHY automates microarchitecture-specific
micro-optimizations. Since SLOTHY does not change instructions, and scheduling/allocation
optimizations are tightly controlled through configurable and extensible constraints, the
developer keeps close control over the final assembly, while being freed from the most tedious
and readability- and verifiability-impeding micro-optimizations.

This module provides the Slothy class, which is a stateful interface to both
one-shot and heuristic optimiations using SLOTHY."""

import logging
from types import SimpleNamespace

from slothy.core.dataflow import DataFlowGraph as DFG
from slothy.core.dataflow import Config as DFGConfig, ComputationNode
from slothy.core.core import Config
from slothy.core.heuristics import Heuristics
from slothy.helper import AsmAllocation, AsmMacro, AsmHelper, CPreprocessor, SourceLine

class Slothy:
    """SLOTHY optimizer

    This class provides a stateful interface to both one-shot and heuristic
    optimizations using SLOTHY.

    The basic flow of operation is the following:
    - Initialize an instance, providing models to the target architecture
      and microarchitecture as arguments.
    - Load source code from file or raw string.
    - Repeat: Adjust configuration and conduct an optimization of a loop body or
        straightline block of code, using optimize() or optimize_loop().
    - Write source code to file or raw string.

    The use of heuristics is controlled through the configuration.
    """

    # Quick convenience access to architecture and target from the config
    def _get_arch(self):
        return self.config.arch
    def _get_target(self):
        return self.config.target
    arch = property(_get_arch)
    target = property(_get_target)

    def __init__(self, arch, target, logger=None):
        self.config = Config(arch, target)
        self.logger = logger if logger is not None else logging.getLogger("slothy")

        # The source, once loaded, is represented as a list of strings
        self._source = None
        self.results = None

        self.last_result = None
        self.success = None

    @property
    def source(self):
        """Returns the current source code as an array of SourceLine objects

        If you want the current source code as a multiline string, use get_source_as_string()."""
        return self._source

    @source.setter
    def source(self, val):
        assert SourceLine.is_source(val)
        self._source = val

    def get_source_as_string(self, comments=True, indentation=True, tags=True):
        """Retrieve current source code as multi-line string"""
        return SourceLine.write_multiline(self.source, comments=comments,
            indentation=indentation, tags=tags)

    def set_source_as_string(self, s):
        """Provide input source code as multi-line string"""
        assert isinstance(s, str)
        reduce = not self.config.ignore_tags
        self.source = SourceLine.read_multiline(s, reduce=reduce)

    def load_source_raw(self, source):
        """Load source code from multi-line string"""
        self.set_source_as_string(source)
        self.results = []

    def load_source_from_file(self, filename):
        """Load source code from file"""
        if self.source is not None:
            self.logger.warning("Overwriting previous source code")
        with open(filename,"r", encoding="utf8") as f:
            self.load_source_raw(f.read())

    def write_source_to_file(self, filename):
        """Write current source code to file"""
        with open(filename,"w", encoding="utf8") as f:
            f.write(self.get_source_as_string())

    def rename_function(self, old_funcname, new_funcname):
        """Rename a function in the current source code"""
        self.source = AsmHelper.rename_function(self.source, old_funcname, new_funcname)

    @staticmethod
    def _dump(name, s, logger, err=False):
        assert isinstance(s, list)
        fun = logger.debug if not err else logger.error
        fun(f"Dump: {name}")
        for l in s:
            fun(f"> {l}")

    #
    # Stateful wrappers around heuristics
    #

    def unfold(self, start=None, end=None, macros=True, aliases=False):
        """Unfold macros and/or register aliases in specified region"""

        logger = self.logger

        pre, body, post = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(pre, body, c.compiler_binary)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)

        # Unfold macros
        if macros is True:
            body = AsmMacro.unfold_all_macros(pre, body, inherit_comments=c.inherit_macro_comments)

        # Unfold register aliases
        if aliases is True:
            body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)

        # Add labels again
        if start is not None:
            body = [SourceLine(f"{start}:")] + body
        if end is not None:
            body = body + [SourceLine(f"{end}:")]

        self.source = pre + body + post

    def optimize(self, start=None, end=None, loop_synthesis_cb=None, logname=None):
        """Optimize all or part of the currently loaded source code

        Note: It is OK to use this in software pipelining mode. In this case, the
        tool will output preamble, kernel, and postamble separately, while the looping
        code itself needs to be introduced by the user. Alternatively, a callback can be
        provided which will be given preamble, kernel, postamble, and the number of exceptional
        iterations, and piece together a list of source code lines from that.

        Args:
           start: The label marking the beginning of the part of the code to optimize.
                  This cannot be used together with the 'loop' argument.
             end: The label marking the end of the part of the code to optimize.
                  This cannot be used together with the 'loop' argument.
             loop_synthesis_cb: Optional (None by default) callback synthesis final source code
                  from tuple of (preamble, kernel, postamble, # exceptional iterations).
        """
        # pylint:disable=too-many-locals

        if logname is None and start is not None:
            logname = start
        if logname is None and end is not None:
            logname = end

        logger = self.logger.getChild(logname) if logname is not None else self.logger
        pre, body, post = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)

        # Check if the body has a dominant indentation
        indentation = AsmHelper.find_indentation(body)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(pre, body, c.compiler_binary)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)
        body = AsmMacro.unfold_all_macros(pre, body, inherit_comments=c.inherit_macro_comments)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        body = SourceLine.apply_indentation(body, indentation)
        self.logger.info("Instructions in body: %d", len(list(filter(None, body))))
        early, core, late, num_exceptional = Heuristics.periodic(body, logger, c)

        def indented(code):
            return [ SourceLine(l).set_indentation(indentation) for l in code]

        if start is not None:
            core = [SourceLine(f"{start}:")] + core
        if end is not None:
            core += [SourceLine(f"{end}:")]

        if not self.config.sw_pipelining.enabled:
            assert early == []
            assert late == []
            assert num_exceptional == 0
            optimized_source = core
        elif loop_synthesis_cb is not None:
            optimized_source = loop_synthesis_cb( pre, core, post, num_exceptional)
        else:
            optimized_source = []
            optimized_source += indented([f"// Exceptional iterations: {num_exceptional}",
                                          "// Preamble"])
            optimized_source += early
            optimized_source += indented(["// Kernel"])
            optimized_source += core
            optimized_source += indented(["// Postamble"])
            optimized_source += late

        self.source = pre + optimized_source + post
        assert SourceLine.is_source(self.source)

    def get_loop_input_output(self, loop_lbl):
        """Find all registers that a loop body depends on"""
        logger = self.logger.getChild(loop_lbl)
        _, body, _, _, _ = self.arch.Loop.extract(self.source, loop_lbl)

        c = self.config.copy()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        return list(DFG(body, logger.getChild("dfg_kernel_deps"), dfgc).inputs)

    def get_input_from_output(self, start, end, outputs=None):
        """For the piece of straightline code, infer which input registers affect its output"""
        if outputs is None:
            outputs = {}
        logger = self.logger.getChild(f"{start}_{end}_infer_input")
        pre, body, _ = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)
        c.outputs = outputs

        body = AsmMacro.unfold_all_macros(pre, body, inherit_comments=c.inherit_macro_comments)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)
        return list(DFG(body, logger.getChild("dfg_find_deps"), dfgc).inputs)

    def _fusion_core(self, pre, body, logger):
        c = self.config.copy()

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(pre, body, c.compiler_binary)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)
        body = SourceLine.split_semicolons(body)

        aliases = AsmAllocation.parse_allocs(pre)
        c.add_aliases(aliases)

        body = AsmMacro.unfold_all_macros(pre, body, inherit_comments=c.inherit_macro_comments)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)

        dfg = DFG(body, logger.getChild("ssa"), dfgc, parsing_cb=False)
        dfg.ssa()
        body = [ ComputationNode.to_source_line(t) for t in dfg.nodes ]

        dfg = DFG(body, logger.getChild("fusion"), dfgc, parsing_cb=False)
        dfg.apply_fusion_cbs()
        body = [ ComputationNode.to_source_line(t) for t in dfg.nodes ]

        return body

    def fusion_region(self, start, end):
        """Run fusion callbacks on straightline code"""
        logger = self.logger.getChild(f"ssa_{start}_{end}")
        pre, body, post = AsmHelper.extract(self.source, start, end)

        body_ssa = [ SourceLine(f"{start}:") ] +\
             self._fusion_core(pre, body, logger) + \
            [ SourceLine(f"{end}:") ]
        self.source = pre + body_ssa + post
        assert SourceLine.is_source(self.source)

    def fusion_loop(self, loop_lbl):
        """Run fusion callbacks on loop body"""
        logger = self.logger.getChild(f"ssa_loop_{loop_lbl}")

        pre , body, post, _, other_data = \
            self.arch.Loop.extract(self.source, loop_lbl)

        indentation = AsmHelper.find_indentation(body)

        loop = self.arch.Loop(lbl_start=loop_lbl)
        body_ssa = SourceLine.read_multiline(loop.start()) + \
            SourceLine.apply_indentation(self._fusion_core(pre, body, logger), indentation) + \
            SourceLine.read_multiline(loop.end(other_data))

        self.source = pre + body_ssa + post
        assert SourceLine.is_source(self.source)

        c = self.config.copy()
        self.config.keep_tags = True
        self.config.constraints.functional_only = True
        self.config.constraints.allow_reordering = False
        self.config.sw_pipelining.enabled = False
        self.config.split_heuristic = False
        self.config.inputs_are_outputs = True
        self.config.sw_pipelining.unknown_iteration_count = False
        self.optimize_loop(loop_lbl)
        self.config = c

        assert SourceLine.is_source(self.source)

    def optimize_loop(self, loop_lbl, postamble_label=None):
        """Optimize the loop starting at a given label"""

        logger = self.logger.getChild(loop_lbl)

        early, body, late, _, other_data = \
            self.arch.Loop.extract(self.source, loop_lbl)

        aliases = AsmAllocation.parse_allocs(early)
        c = self.config.copy()
        c.add_aliases(aliases)

        # Check if the body has a dominant indentation
        indentation = AsmHelper.find_indentation(body)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(early, body, c.compiler_binary)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)
        body = AsmMacro.unfold_all_macros(early, body, inherit_comments=c.inherit_macro_comments)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        body = SourceLine.apply_indentation(body, indentation)

        self.logger.info("Optimizing loop %s (%d instructions) ...",
            loop_lbl, len(body))

        preamble_code, kernel_code, postamble_code, num_exceptional = \
            Heuristics.periodic(body, logger, c)

        def indented(code):
            if not SourceLine.is_source(code):
                code = SourceLine.read_multiline(code)
            return SourceLine.apply_indentation(code, self.config.indentation)

        loop_lbl_end = f"{loop_lbl}_end"
        def loop_lbl_iter(i):
            return SourceLine(f"{loop_lbl}_iter_{i}")

        optimized_code = []

        if self.config.sw_pipelining.unknown_iteration_count:
            for i in range(1, num_exceptional):
                optimized_code += indented(self.arch.Branch.if_equal(i, loop_lbl_iter(i)))

        loop = self.arch.Loop(lbl_start=loop_lbl)
        optimized_code += indented(preamble_code)

        if self.config.sw_pipelining.unknown_iteration_count:
            if postamble_label is None:
                postamble_label = f"{loop_lbl}_postamble"
            jump_if_empty = postamble_label
        else:
            jump_if_empty = None

        optimized_code += SourceLine.read_multiline(loop.start(
            indentation=self.config.indentation,
            fixup=num_exceptional,
            unroll=self.config.sw_pipelining.unroll,
            jump_if_empty=jump_if_empty))
        optimized_code += indented(kernel_code)
        optimized_code += SourceLine.read_multiline(loop.end(other_data,
            indentation=self.config.indentation))
        if postamble_label is not None:
            optimized_code += [ SourceLine(f"{postamble_label}:")
                .add_comment("end of loop kernel") ]
        optimized_code += indented(postamble_code)

        if self.config.sw_pipelining.unknown_iteration_count:
            optimized_code += indented(self.arch.Branch.unconditional(loop_lbl_end))
            for i in range(1, num_exceptional):
                optimized_code += [SourceLine(f"{loop_lbl_iter(i)}:")]
                optimized_code += i * indented(body)
                optimized_code += [SourceLine(f"{loop_lbl_iter(i)}_end:")]
                if i != num_exceptional - 1:
                    optimized_code += indented(self.arch.Branch.unconditional(loop_lbl_end))
            optimized_code += [SourceLine(f"{loop_lbl_end}:")]

        self.last_result = SimpleNamespace()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        self.last_result.kernel_input_output = \
            list(DFG(kernel_code, logger.getChild("dfg_kernel_deps"), dfgc).inputs)

        self.source = early + optimized_code + late
        self.success = True

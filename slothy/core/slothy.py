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

* Instruction scheduling
* Register allocation
* Software pipelining

SLOTHY enables a development workflow where developers write 'clean' assembly by hand,
emphasizing the logic of the computation, while SLOTHY automates
microarchitecture-specific micro-optimizations. Since SLOTHY does not change instructions,
and scheduling/allocation optimizations are tightly controlled through configurable and
extensible constraints, the developer keeps close control over the final assembly, while
being freed from the most tedious and readability- and verifiability-impeding
micro-optimizations.

This module provides the Slothy class, which is a stateful interface to both
one-shot and heuristic optimizations using SLOTHY.
"""

import logging
from types import SimpleNamespace

from slothy.core.dataflow import DataFlowGraph as DFG
from slothy.core.dataflow import Config as DFGConfig, ComputationNode
from slothy.core.core import Config
from slothy.core.heuristics import Heuristics
from slothy.helper import (
    AsmAllocation,
    AsmMacro,
    AsmHelper,
    AsmIfElse,
    CPreprocessor,
    SourceLine,
    LLVM_Mca,
    LLVM_Mca_Error,
    SelfTest,
)


class Slothy:
    """SLOTHY optimizer

    This class provides a stateful interface to both one-shot and heuristic
    optimizations using SLOTHY.

    The basic flow of operation is the following:

    * Initialize an instance, providing models to the target architecture
      and microarchitecture as arguments.
    * Load source code from file or raw string.
    * Repeat: Adjust configuration and conduct an optimization of a loop body or
      straightline block of code, using optimize() or optimize_loop().
    * Write source code to file or raw string.

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
        self._original_source = None
        self.results = None

        self.last_result = None
        self.success = None

    def _get_version(self):
        try:
            from importlib.metadata import version

            return version("slothy")
        except Exception:
            return "unknown"

    @property
    def source(self):
        """Returns the current source code as an array of SourceLine objects.

        If you want the current source code as a multiline string, use
        get_source_as_string().
        """
        return self._source

    @property
    def original_source(self):
        """Returns the original source code as an array of SourceLine objects

        If you want the current source code as a multiline string, use
        get_original_source_as_string().
        """
        return self._original_source

    @source.setter
    def source(self, val):
        assert SourceLine.is_source(val)
        self._source = val

    @original_source.setter
    def original_source(self, val):
        assert SourceLine.is_source(val)
        self._original_source = val

    def get_source_as_string(self, comments=True, indentation=True, tags=True):
        """Retrieve current source code as multi-line string"""
        return SourceLine.write_multiline(
            self.source, comments=comments, indentation=indentation, tags=tags
        )

    def get_original_source_as_string(self, comments=True, indentation=True, tags=True):
        """Retrieve original source code as multi-line string"""
        return SourceLine.write_multiline(
            self.original_source, comments=comments, indentation=indentation, tags=tags
        )

    def set_source_as_string(self, s):
        """Provide input source code as multi-line string"""
        assert isinstance(s, str)
        reduce = not self.config.ignore_tags
        self.source = SourceLine.read_multiline(s, reduce=reduce)
        if self.original_source is None:
            self.original_source = self.source

    def load_source_raw(self, source):
        """Load source code from multi-line string"""
        self.set_source_as_string(source)
        self.results = []

    def load_source_from_file(self, filename):
        """Load source code from file"""
        if self.source is not None:
            self.logger.warning("Overwriting previous source code")
        with open(filename, "r", encoding="utf8") as f:
            self.load_source_raw(f.read())

    def write_source_to_file(self, filename):
        """Write current source code to file"""
        with open(filename, "w", encoding="utf8") as f:
            f.write(self.get_source_as_string())

    def rename_function(self, old_funcname, new_funcname):
        """Rename a function in the current source code"""
        self.source = AsmHelper.rename_function(self.source, old_funcname, new_funcname)
        self.source = AsmHelper.rename_function(
            self.source, "_" + old_funcname, "_" + new_funcname
        )

    @staticmethod
    def _dump(name, s, logger, err=False):
        assert isinstance(s, list)
        fun = logger.debug if not err else logger.error
        fun(f"Dump: {name}")
        for line in s:
            fun(f"> {line}")

    def global_selftest(
        self, funcname: str, address_registers: any, iterations: int = 5
    ) -> None:
        """Conduct a function-level selftest
            .. important::

            To run this, you need `llvm-nm`, `llvm-readobj`, `llvm-mc`
            in your PATH. Those are part of a standard LLVM setup.

        :param funcname: Name of function to be called. Must be exposed as a symbol
        :type funcname: str
        :param address_registers: Dictionary indicating which GPRs are pointers to
            buffers of which size.
            For example, `{ "x0": 1024, "x4": 1024 }` would indicate that both x0 and x4
            point to buffers of size 1024 bytes. The global selftest needs to know this to
            setup valid calls to the assembly routine.
        :type address_registers: any
        :param iterations: Number of iterations to run the selftest for.
        :type iterations: int
        :return: Returns early of target architecture of not supported.
        :rtype: None
        """

        log = self.logger.getChild(f"global_selftest_{funcname}")

        if (
            self.config.arch.unicorn_arch is None
            or self.config.arch.llvm_mc_arch is None
        ):
            log.warning("Selftest not supported on target architecture")
            return

        old_source = self.original_source
        new_source = self.source

        SelfTest.run(
            self.config,
            log,
            old_source,
            new_source,
            address_registers,
            self.config.arch.RegisterType.callee_saved_registers(),
            iterations,
            fnsym=funcname,
        )

    #
    # Stateful wrappers around heuristics
    #

    def unfold(self, start=None, end=None, macros=True, aliases=False):
        """Unfold macros and/or register aliases in specified region"""
        pre, body, post = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(
                pre, body, post, c.compiler_binary, include=c.compiler_include_paths
            )
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)

        # Unfold macros
        if macros is True:
            body = AsmMacro.unfold_all_macros(
                pre, body, inherit_comments=c.inherit_macro_comments
            )

        # Unfold register aliases
        if aliases is True:
            body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)

        # Add labels again
        if start is not None:
            body = [SourceLine(f"{start}:")] + body
        if end is not None:
            body = body + [SourceLine(f"{end}:")]

        self.source = pre + body + post

    def _make_llvm_mca_stats(self, pre, code, post, txt, indentation):
        try:
            code = CPreprocessor.unfold(
                pre,
                code,
                post,
                self.config.compiler_binary,
                include=self.config.compiler_include_paths,
            )
            if self.config.llvm_mca_issue_width_overwrite is True:
                issue_width = self.config.target.issue_rate
            else:
                issue_width = None
            stats = LLVM_Mca.run(
                pre,
                code,
                self.config.arch.llvm_mca_arch,
                self.config.target.llvm_mca_target,
                self.logger,
                full=self.config.llvm_mca_full,
                issue_width=issue_width,
            )
            stats = (
                ["", f"LLVM MCA STATISTICS ({txt}) BEGIN", ""]
                + stats
                + ["", f"ORIGINAL LLVM MCA STATISTICS ({txt}) END", ""]
            )
            stats = [SourceLine("").add_comment(r) for r in stats]
            stats = SourceLine.apply_indentation(stats, indentation)
        except LLVM_Mca_Error:
            self.logger.warning("Failed to run LLVM-MCA -- ignoring")
            stats = []
        return stats

    def optimize(
        self,
        start: str = None,
        end: str = None,
        loop_synthesis_cb: any = None,
        logname: str = None,
    ):
        """Optimize all or part of the currently loaded source code

        .. note::

            It is OK to use this in software pipelining mode. In this case, the
            tool will output preamble, kernel, and postamble separately, while the looping
            code itself needs to be introduced by the user. Alternatively, a callback can
            be provided which will be given preamble, kernel, postamble, and the number
            of exceptional iterations, and piece together a list of source code lines
            from that.


        :param start: The label marking the beginning of the part of the code to optimize.
              This cannot be used together with the 'loop' argument.
        :type start: str
        :param end: The label marking the end of the part of the code to optimize.
              This cannot be used together with the 'loop' argument.
        :type end: str
        :param loop_synthesis_cb: Optional (None by default) callback synthesis final
               source code from tuple of (preamble, kernel, postamble, # exceptional
               iterations).
        :type loop_synthesis_cb: any
        :param logname: Optional name of the logger.
        :type logname: str
        """
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
            body = CPreprocessor.unfold(
                pre, body, post, c.compiler_binary, include=c.compiler_include_paths
            )
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)
        body = AsmMacro.unfold_all_macros(
            pre, body, inherit_comments=c.inherit_macro_comments
        )
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        body = AsmIfElse.process_instructions(body)
        body = SourceLine.apply_indentation(body, indentation)
        logger.info("SLOTHY version: %s", self._get_version())
        self.logger.info("Instructions in body: %d", len(list(filter(None, body))))

        if self.config.with_llvm_mca_before is True:
            orig_stats = self._make_llvm_mca_stats(
                pre, body, post, "ORIGINAL", indentation
            )

        early, core, late, num_exceptional = Heuristics.periodic(body, logger, c)

        if self.config.with_llvm_mca_before is True:
            core = core + orig_stats

        if self.config.with_llvm_mca_after is True:
            new_stats_kernel = self._make_llvm_mca_stats(
                pre, core, post, "OPTIMIZED", indentation
            )

            core = core + new_stats_kernel

        def indented(code):
            return [SourceLine(line).set_indentation(indentation) for line in code]

        if start is not None:
            core = [SourceLine(f"{start}:")] + core
        if end is not None:
            core += [SourceLine(f"{end}:")]

        core = SourceLine.apply_indentation(core, self.config.indentation)
        if not self.config.sw_pipelining.enabled:
            assert early == []
            assert late == []
            assert num_exceptional == 0
            optimized_source = core
        elif loop_synthesis_cb is not None:
            optimized_source = loop_synthesis_cb(pre, core, post, num_exceptional)
        else:
            optimized_source = []
            optimized_source += indented(
                [f"// Exceptional iterations: {num_exceptional}", "// Preamble"]
            )
            optimized_source += early
            optimized_source += indented(["// Kernel"])
            optimized_source += core
            optimized_source += indented(["// Postamble"])
            optimized_source += late

        self.source = pre + optimized_source + post
        assert SourceLine.is_source(self.source)

    def get_loop_input_output(
        self, loop_lbl: str, forced_loop_type: any = None
    ) -> list:
        """Find all registers that a loop body depends on

        :param loop_lbl: Label of loop to process.
        :type loop_lbl: str
        :param forced_loop_type: Forces the loop to be parsed as a certain type.
        :type forced_loop_type: any
        :return: list all inputs of the loop.
        :rtype: list
        """
        logger = self.logger.getChild(loop_lbl)
        _, body, _, _, _ = self.arch.Loop.extract(
            self.source, loop_lbl, forced_loop_type=forced_loop_type
        )

        c = self.config.copy()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        return list(DFG(body, logger.getChild("dfg_kernel_deps"), dfgc).inputs)

    def get_input_from_output(self, start, end, outputs=None):
        """For the piece of straightline code, infer which input registers affect its
        output"""
        if outputs is None:
            outputs = {}
        logger = self.logger.getChild(f"{start}_{end}_infer_input")
        pre, body, _ = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)
        c.outputs = outputs

        body = AsmMacro.unfold_all_macros(
            pre, body, inherit_comments=c.inherit_macro_comments
        )
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)
        return list(DFG(body, logger.getChild("dfg_find_deps"), dfgc).inputs)

    def _fusion_core(self, pre, body, post, logger, ssa=True):
        c = self.config.copy()

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(
                pre, body, post, c.compiler_binary, include=c.compiler_include_paths
            )
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)
        body = SourceLine.split_semicolons(body)

        aliases = AsmAllocation.parse_allocs(pre)
        c.add_aliases(aliases)

        body = AsmMacro.unfold_all_macros(
            pre, body, inherit_comments=c.inherit_macro_comments
        )
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)

        if ssa is True:
            dfg = DFG(body, logger.getChild("ssa"), dfgc, parsing_cb=False)
            dfg.ssa()
            body = [ComputationNode.to_source_line(t) for t in dfg.nodes]

        dfg = DFG(body, logger.getChild("fusion"), dfgc, parsing_cb=False)
        dfg.apply_fusion_cbs()
        body = [ComputationNode.to_source_line(t) for t in dfg.nodes]

        return body

    def fusion_region(self, start: str, end: str, **kwargs: any):
        """Run fusion callbacks on straightline code replacing certain
        instruction (sequences) with an alternative. These replacements are
        defined in the architectural model by setting an instruction class'
        global_fusion_cb.

        :param start: The label marking the beginning of the part of the code to
              apply fusion to.
        :type start: str
        :param end: The label marking the end of the part of the code to apply
              fusion to.
        :type end: str
        :param **kwargs: Additional arguments to pass to the fusion callbacks.
        :type **kwargs: any
        """
        logger = self.logger.getChild(f"ssa_{start}_{end}")
        pre, body, post = AsmHelper.extract(self.source, start, end)

        body_ssa = (
            [SourceLine(f"{start}:")]
            + self._fusion_core(pre, body, post, logger, **kwargs)
            + [SourceLine(f"{end}:")]
        )
        self.source = pre + body_ssa + post
        assert SourceLine.is_source(self.source)

    def fusion_loop(self, loop_lbl: str, forced_loop_type: any = None, **kwargs: any):
        """Run fusion callbacks on loop body replacing certain instruction
        (sequences) with an alternative. These replacements are defined in the
        architectural model by setting an instruction class' global_fusion_cb.

        :param loop_lbl: Label of loop to which the fusions are applied to.
        :type loop_lbl: str
        :param forced_loop_type: Forces the loop to be parsed as a certain type.
        :type forced_loop_type: any
        :param **kwargs: Additional arguments to pass to the fusion callbacks.
        :type **kwargs: any
        """
        logger = self.logger.getChild(f"ssa_loop_{loop_lbl}")

        pre, body, post, _, other_data, loop = self.arch.Loop.extract(
            self.source, loop_lbl, forced_loop_type=forced_loop_type
        )

        try:
            loop_cnt = other_data["cnt"]
        except KeyError:
            loop_cnt = None

        indentation = AsmHelper.find_indentation(body)

        body_ssa = (
            SourceLine.read_multiline(loop.start(loop_cnt))
            + SourceLine.apply_indentation(
                self._fusion_core(pre, body, post, logger, **kwargs), indentation
            )
            + SourceLine.read_multiline(loop.end(other_data))
        )

        self.source = pre + body_ssa + post
        assert SourceLine.is_source(self.source)

    def optimize_loop(
        self, loop_lbl: str, postamble_label: str = None, forced_loop_type: any = None
    ):
        """Optimize the loop starting at a given label

        :param loop_lbl: Label of loop to optimize.
        :type loop_lbl: str
        :param postamble_label: Marks end of loop kernel.
        :type postamble_label: str
        :param forced_loop_type: Forces the loop to be parsed as a certain type.
        :type forced_loop_type: any
        """

        logger = self.logger.getChild(loop_lbl)

        early, body, late, _, other_data, loop = self.arch.Loop.extract(
            self.source, loop_lbl, forced_loop_type=forced_loop_type
        )

        try:
            loop_cnt = other_data["cnt"]
        except KeyError:
            loop_cnt = None

        # Check if the body has a dominant indentation
        indentation = AsmHelper.find_indentation(body)

        aliases = AsmAllocation.parse_allocs(early)
        c = self.config.copy()
        c.add_aliases(aliases)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(
                early, body, late, c.compiler_binary, include=c.compiler_include_paths
            )
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = SourceLine.split_semicolons(body)
        body = AsmMacro.unfold_all_macros(
            early, body, inherit_comments=c.inherit_macro_comments
        )
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        body = SourceLine.apply_indentation(body, indentation)
        logger.info("SLOTHY version: %s", self._get_version())
        self.logger.info(
            "Optimizing loop %s (%d instructions) ...", loop_lbl, len(body)
        )

        if self.config.with_llvm_mca_before is True:
            orig_stats = self._make_llvm_mca_stats(
                early, body, late, "ORIGINAL", indentation
            )

        preamble_code, kernel_code, postamble_code, num_exceptional = (
            Heuristics.periodic(body, logger, c)
        )

        # Remove branch instructions from preamble and postamble
        postamble_code = [
            line for line in postamble_code if not line.tags.get("branch")
        ]
        postamble_code = [
            line for line in postamble_code if not line.tags.get("branch")
        ]

        if self.config.with_llvm_mca_before is True:
            kernel_code = kernel_code + orig_stats

        if self.config.with_llvm_mca_after is True:
            new_stats_kernel = self._make_llvm_mca_stats(
                early, kernel_code, late, "OPTIMIZED", indentation
            )
            kernel_code = kernel_code + new_stats_kernel

            if (
                self.config.sw_pipelining.optimize_preamble is True
                and len(preamble_code) > 0
            ):
                new_stats_preamble = self._make_llvm_mca_stats(
                    early, preamble_code, late, "PREAMBLE", indentation
                )
                preamble_code = preamble_code + new_stats_preamble

            if (
                self.config.sw_pipelining.optimize_postamble is True
                and len(postamble_code) > 0
            ):
                new_stats_postamble = self._make_llvm_mca_stats(
                    early, postamble_code, late, "POSTAMBLE", indentation
                )
                postamble_code = postamble_code + new_stats_postamble

        def indented(code):
            if not SourceLine.is_source(code):
                code = SourceLine.read_multiline(code)
            return SourceLine.apply_indentation(code, self.config.indentation)

        loop_lbl_end = f"{loop_lbl}_end"

        def loop_lbl_iter(i):
            return f"{loop_lbl}_iter_{i}"

        optimized_code = []

        if self.config.sw_pipelining.unknown_iteration_count:
            for i in range(1, num_exceptional):
                optimized_code += indented(
                    self.arch.Branch.if_equal(loop_cnt, i, loop_lbl_iter(i))
                )

        optimized_code += indented(preamble_code)

        if self.config.sw_pipelining.unknown_iteration_count:
            if postamble_label is None:
                postamble_label = f"{loop_lbl}_postamble"
            jump_if_empty = postamble_label
        else:
            jump_if_empty = None

        optimized_code += SourceLine.read_multiline(
            loop.start(
                loop_cnt,
                indentation=self.config.indentation,
                fixup=num_exceptional,
                unroll=self.config.sw_pipelining.unroll,
                jump_if_empty=jump_if_empty,
                preamble_code=preamble_code,
                body_code=kernel_code,
                postamble_code=postamble_code,
                register_aliases=c.register_aliases,
            )
        )
        optimized_code += indented(kernel_code)
        optimized_code += SourceLine.read_multiline(
            loop.end(other_data, indentation=self.config.indentation)
        )
        if postamble_label is not None:
            optimized_code += [
                SourceLine(f"{postamble_label}:").add_comment("end of loop kernel")
            ]
        optimized_code += indented(postamble_code)

        if self.config.sw_pipelining.unknown_iteration_count:
            optimized_code += indented(self.arch.Branch.unconditional(loop_lbl_end))
            for i in range(1, num_exceptional):
                exceptional = i * body
                c2 = c.copy()
                c2.sw_pipelining.enabled = False
                res = Heuristics.linear(
                    exceptional, logger.getChild(f"exceptional_{i}"), c2
                )
                optimized_code += [SourceLine(f"{loop_lbl_iter(i)}:")]
                optimized_code += indented(res.code)
                optimized_code += [SourceLine(f"{loop_lbl_iter(i)}_end:")]
                if i != num_exceptional - 1:
                    optimized_code += indented(
                        self.arch.Branch.unconditional(loop_lbl_end)
                    )
            optimized_code += [SourceLine(f"{loop_lbl_end}:")]

        self.last_result = SimpleNamespace()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        self.last_result.kernel_input_output = list(
            DFG(kernel_code, logger.getChild("dfg_kernel_deps"), dfgc).inputs
        )

        self.source = early + optimized_code + late
        self.success = True

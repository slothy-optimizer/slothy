
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

import logging, copy, math

from types import SimpleNamespace

from slothy.dataflow import DataFlowGraph as DFG
from slothy.dataflow import Config as DFGConfig
from slothy.core import SlothyBase, Config
from slothy.heuristics import Heuristics
from slothy.helper import AsmAllocation, AsmMacro, AsmHelper, CPreprocessor

class Slothy():

    # Quick convenience access to architecture and target from the config
    def _get_arch(self):
        return self.config.Arch
    def _get_target(self):
        return self.config.Target
    Arch = property(_get_arch)
    Target = property(_get_target)

    def __init__(self, Arch, Target, debug=False, logger=None):
        lvl = logging.DEBUG if debug else logging.INFO
        logging.basicConfig(level = lvl)
        self.config = Config(Arch, Target)
        self.logger = logger if logger != None else logging.getLogger("slothy")
        self.source = None

    def load_source_raw(self, source):
        self.source = source.replace("\\\n", "")
        self.results = []

    def load_source_from_file(self, filename):
        if self.source is not None:
            self.logger.warning("Overwriting previous source code")
        f = open(filename,"r")
        self.load_source_raw(f.read())
        f.close()

    def write_source_to_file(self, filename):
        f = open(filename,"w")
        f.write(self.source)
        f.close()

    def print_code(self):
        print(self.source)

    def rename_function(self, old_funcname, new_funcname):
        self.source = AsmHelper.rename_function(self.source, old_funcname, new_funcname)

    def _dump(name, s, logger, err=False):
        fun = logger.debug if not err else logger.error
        fun(f"Dump: {name}")
        if isinstance(s, str):
          s = s.splitlines()
        for l in s:
            fun(f"> {l}")

    #
    # Stateful wrappers around heuristics
    #

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

        if logname is None and start != None:
            logname = start
        if logname is None and end != None:
            logname = end

        logger = self.logger.getChild(logname) if logname != None else self.logger
        pre, body, post = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)

        # Check if the body has a dominant indentation
        indentation = AsmHelper.find_indentation(body)

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(pre, body)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)

        body = AsmHelper.split_semicolons(body)
        body = AsmMacro.unfold_all_macros(pre, body)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        body = AsmHelper.apply_indentation(body, indentation)
        self.logger.info(f"Instructions in body: {len(list(filter(None, body)))}")
        early, core, late, num_exceptional = Heuristics.periodic(body, logger, c)

        def indented(code):
            indent = ' ' * self.config.indentation
            return [ indent + s for s in code ]

        if start != None:
            core = [f"{start}:"] + core
        if end != None:
            core += [f"{end}:"]

        if not self.config.sw_pipelining.enabled:
            assert early == []
            assert late == []
            assert num_exceptional == 0
            optimized_source = indented(core)
        elif loop_synthesis_cb != None:
            optimized_source = indented(loop_synthesis_cb( pre, core, post, num_exceptional))
        else:
            optimized_source = []
            optimized_source += indented([f"// Exceptional iterations: {num_exceptional}",
                                          "// Preamble"])
            optimized_source += indented(early)
            optimized_source += indented(["// Kernel"])
            optimized_source += indented(core)
            optimized_source += indented(["// Postamble"])
            optimized_source += indented(late)

        self.source = '\n'.join(pre + optimized_source + post)

    def get_loop_input_output(self, loop_lbl):
        logger = self.logger.getChild(loop_lbl)
        _, body, _, _, _ = self.Arch.Loop.extract(self.source, loop_lbl)

        c = self.config.copy()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        return list(DFG(body, logger.getChild("dfg_kernel_deps"), dfgc).inputs)

    def get_input_from_output(self, start, end, outputs=None):
        if outputs == None:
            outputs = {}
        logger = self.logger.getChild(f"{start}_{end}_infer_input")
        pre, body, _ = AsmHelper.extract(self.source, start, end)

        aliases = AsmAllocation.parse_allocs(pre)
        c = self.config.copy()
        c.add_aliases(aliases)
        c.outputs = outputs

        body = AsmMacro.unfold_all_macros(pre, body)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)
        return list(DFG(body, logger.getChild("dfg_find_deps"), dfgc).inputs)

    def ssa_region(self, start, end, outputs=None):
        if outputs == None:
            outputs = {}
        logger = self.logger.getChild(f"{start}_{end}_infer_input")
        pre, body, post = AsmHelper.extract(self.source, start, end)
        c = self.config.copy()

        if c.with_preprocessor:
            self.logger.info("Apply C preprocessor...")
            body = CPreprocessor.unfold(pre, body)
            self.logger.debug("Code after preprocessor:")
            Slothy._dump("preprocessed", body, self.logger, err=False)
        body = AsmHelper.split_semicolons(body)

        aliases = AsmAllocation.parse_allocs(pre)
        c.add_aliases(aliases)
        c.outputs = outputs

        body = AsmMacro.unfold_all_macros(pre, body)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        dfgc = DFGConfig(c)
        dfg = DFG(body, logger.getChild("dfg_find_deps"), dfgc)
        dfg.ssa()

        body_ssa = [ f"{start}:" ] + [ str(t.inst) for t in dfg.nodes ] + [ f"{end}:" ]
        self.source = '\n'.join(pre + body_ssa + post)

    def optimize_loop(self, loop_lbl, end_of_loop_label=None):
        """Optimize the loop starting at a given label"""

        logger = self.logger.getChild(loop_lbl)

        early, body, late, loop_start_lbl, other_data = \
            self.Arch.Loop.extract(self.source, loop_lbl)

        aliases = AsmAllocation.parse_allocs(early)
        c = self.config.copy()
        c.add_aliases(aliases)

        body = AsmMacro.unfold_all_macros(early, body)
        body = AsmAllocation.unfold_all_aliases(c.register_aliases, body)
        self.logger.info(f"Instructions in loop body: {len(list(filter(None, body)))}")

        preamble_code, kernel_code, postamble_code, num_exceptional = \
            Heuristics.periodic(body, logger, c)
        def indented(code):
            indent = ' ' * self.config.indentation
            return [ indent + s for s in code ]

        loop = self.Arch.Loop(lbl_start=loop_lbl)
        optimized_code = []
        optimized_code += indented(preamble_code)
        optimized_code += list(loop.start(indentation=self.config.indentation,
                                          fixup=num_exceptional,
                                          unroll=self.config.sw_pipelining.unroll))
        optimized_code += indented(kernel_code)
        optimized_code += list(loop.end(other_data, indentation=self.config.indentation))
        if end_of_loop_label != None:
            optimized_code += [ f"{end_of_loop_label}: // end of loop kernel" ]
        optimized_code += indented(postamble_code)

        self.last_result = SimpleNamespace()
        dfgc = DFGConfig(c)
        dfgc.inputs_are_outputs = True
        self.last_result.kernel_input_output = \
            list(DFG(kernel_code, logger.getChild("dfg_kernel_deps"), dfgc).inputs)

        self.source = '\n'.join(early + optimized_code + late)
        self.success = True

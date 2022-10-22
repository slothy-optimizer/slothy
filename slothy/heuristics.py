
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

import logging, copy, math

from types import SimpleNamespace

from slothy.dataflow import DataFlowGraph as DFG
from slothy.dataflow import Config as DFGConfig
from slothy.core import SlothyBase, Config
from slothy.helper import AsmAllocation, AsmMacro, AsmHelper
from slothy.helper import binary_search, BinarySearchLimitException

class Heuristics():

    def optimize_binsearch(source, logger, conf, flexible=True):
        """Shim wrapper around Slothy performing a binary search for the
        minimization of stalls"""

        logger_name = logger.name.replace(".","_")

        if not flexible:
            core = SlothyBase(conf.Arch, conf.Target, logger=logger,config=conf)
            if not core.optimize(source):
                raise Exception("Optimization failed")
            return core.result
        def try_with_stalls(stalls):
            logger.info(f"Attempt optimization with max {stalls} stalls...")
            c = conf.copy()
            c.constraints.stalls_allowed = stalls
            core = SlothyBase(conf.Arch, conf.Target, logger=logger, config=c)
            success = core.optimize(source, log_model=f"{logger_name}_{stalls}_stalls.txt")
            return success, core.result

        try:
            return binary_search(try_with_stalls,
                                 minimum= conf.constraints.stalls_minimum_attempt - 1,
                                 start=conf.constraints.stalls_first_attempt,
                                 threshold=conf.constraints.stalls_maximum_attempt,
                                 precision=conf.constraints.stalls_precision)
        except BinarySearchLimitException:
            logger.error("Exceeded stall limit without finding a working solution")
            logger.error("Here's what you asked me to optimize:")
            Heuristics._dump("Original source code", source, logger=logger, err=True)
            logger.error("Configuration")
            conf.log(logger.error)

            err_file = self.config.log_dir + f"/{logger_name}_ERROR.s"
            f = open(err_file, "w")
            conf.log(lambda l: f.write("// " + l + "\n"))
            f.write('\n'.join(source))
            f.close()
            self.logger.error(f"Stored this information in {err_file}")

    def periodic(body, logger, conf):
        """Heuristics for the optimization of large loops

        Can be called if software pipelining is diabled. In this case, it just
        forwards to the linear heuristic."""

        # If we're not asked to do software pipelining, just forward to
        # the heurstics for linear optimization.
        if not conf.sw_pipelining.enabled:
            core = Heuristics.linear( body, logger=logger, conf=conf)
            return [], core, [], 0

        if conf.sw_pipelining.halving_heuristic:
            return Heuristics._periodic_halving( body, logger, conf)

        # 'Normal' software pipelining
        #
        # We first perform the core periodic optimization of the loop kernel,
        # and then separate passes for the optimization for the preamble and postamble

        # First step: Optimize loop kernel

        logger.info("Optimize loop kernel...")
        c = conf.copy()
        c.inputs_are_outputs = True
        result = Heuristics.optimize_binsearch(body,logger.getChild("slothy"),c)

        num_exceptional_iterations = result.num_exceptional_iterations
        kernel = result.code

        # Second step: Separately optimize preamble and postamble

        preamble = result.preamble
        if conf.sw_pipelining.optimize_preamble:
            logger.debug("Optimize preamble...")
            Heuristics._dump("Preamble", preamble, logger)
            logger.debug(f"Dependencies within kernel: "\
                         f"{result.kernel_input_output}")
            c = conf.copy()
            c.outputs = result.kernel_input_output
            c.sw_pipelining.enabled=False
            preamble = Heuristics.linear(preamble,conf=c, logger=logger.getChild("preamble"))

        postamble = result.postamble
        if conf.sw_pipelining.optimize_postamble:
            logger.debug("Optimize postamble...")
            Heuristics._dump("Preamble", postamble, logger)
            c = conf.copy()
            c.sw_pipelining.enabled=False
            postamble = Heuristics.linear(postamble, conf=c, logger=logger.getChild("postamble"))

        return preamble, kernel, postamble, num_exceptional_iterations

    def linear(body, logger, conf, visualize_stalls=True):
        """Heuristic for the optimization of large linear chunks of code.

        Must only be called if software pipelining is disabled."""
        if conf.sw_pipelining.enabled:
            raise Exception("Linear heuristic should only be called with SW pipelining disabled")

        Heuristics._dump("Starting linear optimization...", body, logger)

        # So far, we only implement one heuristic: The splitting heuristic --
        # If that's disabled, just forward to the core optimization
        if not conf.split_heuristic:
            result = Heuristics.optimize_binsearch(body,logger.getChild("slothy"), conf)
            return result.code

        return Heuristics._split( body, logger, conf, visualize_stalls)

    def _split(body, logger, conf, visualize_stalls=True):
        logger.warning("The split heuristic hasn't been tested much yet -- be careful...")

        # For very large snippets, allow to proceed in steps
        split_factor = conf.split_heuristic_factor
        l = len(body)
        log = logger.getChild("split")

        # First, let's make sure that everything's written without symbolic registers
        log.debug("Functional-only optimization to remove symbolics...")
        c = conf.copy()
        c.constraints.allow_reordering = False
        c.constraints.functional_only = True
        body = AsmHelper.reduce_source(body)
        result = Heuristics.optimize_binsearch(body, log.getChild("remove_symbolics"),conf=c)
        body = result.code
        body = AsmHelper.reduce_source(body)
        Heuristics._dump("Source code without symbolic registers", body, log)

        conf.outputs = result.outputs

        def optimize_sequence_of_aligned_chunks(start_idx_lst, body):
            """Splits the input source code into disjoint chunks, delimited by the provided
            index list, and optimizes them separately. Renaming of inputs&outputs allowed."""
            start_idx_lst.sort()
            start_idx_lst.reverse()
            next_end_idx = len(body)
            cur_output = conf.outputs
            cur_output_renaming = copy.copy(conf.rename_outputs)
            new_body = []
            for i, start_idx in enumerate(start_idx_lst):
                i = len(start_idx_lst) - i
                end_idx = next_end_idx

                cur_pre  = body[:start_idx]
                cur_body = body[start_idx:end_idx]
                cur_post = body[end_idx:]

                Heuristics._dump(f"Chunk {i}", cur_body, log)
                Heuristics._dump(f"Cur post {i}", cur_post, log)

                log.debug("Current output: {cur_output}")
                c = conf.copy()
                c.rename_inputs = { "other" : "any" }
                c.rename_outputs = cur_output_renaming
                c.inputs_are_outputs = False
                c.outputs = cur_output
                result = Heuristics.optimize_binsearch(cur_body, log.getChild(f"{i}_{split_factor}"), c)
                new_body = result.code + new_body
                Heuristics._dump(f"New chunk {i}", result.code, log)

                cur_output = result.orig_inputs.copy()
                cur_output_renaming = result.input_renamings.copy()

                next_end_idx = start_idx

            return new_body

        def idxs_from_fractions(fraction_lst, body):
            return [ round(f * len(body)) for f in fraction_lst ]

        def optimize_chunk(start_idx, end_idx, body):
            """Optimizes a sub-chunks of the given snippet, delimited by pairs
            of start and end indices provided as arguments. Input/output register
            names stay intact -- in particular, overlapping chunks are allowed."""

            cur_pre  = body[:start_idx]
            cur_body = body[start_idx:end_idx]
            cur_post = body[end_idx:]

            Heuristics._dump(f"Optimizing chunk [{start_idx}:{end_idx}]", cur_body, log)

            # Find dependencies of rest of body
            dfgc = DFGConfig(conf.copy())
            dfgc.outputs += conf.outputs
            cur_outputs = DFG(cur_post, log.getChild("dfg_infer_outputs"),dfgc).inputs

            c = conf.copy()
            c.rename_inputs  = { "other" : "static" } # No renaming
            c.rename_outputs = { "other" : "static" } # No renaming
            c.inputs_are_outputs = False
            c.outputs = cur_outputs

            result = Heuristics.optimize_binsearch(cur_body, log.getChild(f"{start_idx}_{end_idx}"), c)
            Heuristics._dump(f"New chunk [{start_idx}:{end_idx}]", result.code, log)
            new_body = cur_pre + AsmHelper.reduce_source(result.code) + cur_post
            return new_body

        def optimize_chunks_many(start_end_idx_lst, body):
            for start_idx, end_idx in start_end_idx_lst:
                body = optimize_chunk(start_idx, end_idx, body)
            return body

        cur_body = body

        # Version 1: Optimize in aligned chunks
        # Pro: Allow register renaming
        # Con: No movement of instructions between chunks
        # pos = [ i / split_factor for i in range(split_factor) ]
        # cur_body = optimize_sequence_of_aligned_chunks(idxs_from_fractions(pos, cur_body),
        #                                                cur_body)
        # cur_body = AsmHelper.reduce_source(cur_body)

        # Version 2: Optimize in overlapping chunks
        # Pro: Movement of instructions between chunks
        # Con: No register renaming
        start_pos = [ i / (2*split_factor) for i in range(2*split_factor-1) ]
        end_pos   = [ (i + 2) / (2*split_factor) for i in range(2*split_factor-1) ]

        def not_empty(x):
            return x[0] != x[1]

        idx_lst = zip(idxs_from_fractions(start_pos, cur_body),
                      idxs_from_fractions(end_pos, cur_body))
        idx_lst = list(filter(not_empty, idx_lst))

        for _ in range(conf.split_heuristic_repeat):
            cur_body = optimize_chunks_many(idx_lst, cur_body)

        # Visualize model violations
        if visualize_stalls:
            c = conf.copy()
            c.constraints.allow_reordering = False
            c.constraints.allow_renaming = False
            c.visualize_reordering = False
            cur_body = Heuristics.optimize_binsearch( cur_body, log.getChild("visualize_stalls"), c).code

        return cur_body

    def _dump(name, s, logger, err=False):
        fun = logger.debug if not err else logger.error
        fun(f"Dump: {name}")
        if isinstance(s, str):
          s = s.splitlines()
        for l in s:
            fun(f"> {l}")

    def _periodic_halving(body, logger, conf):

        assert conf != None
        assert conf.sw_pipelining.enabled
        assert conf.sw_pipelining.halving_heuristic

        # Find kernel dependencies
        kernel_deps = DFG(body, logger.getChild("dfg_kernel_deps"),
                          DFGConfig(conf.copy())).inputs

        # First step: Optimize loop kernel, but without software pipelining
        c = conf.copy()
        c.sw_pipelining.enabled = False
        c.inputs_are_outputs = True
        c.outputs += kernel_deps
        kernel = Heuristics.linear(body,logger.getChild("slothy"),conf=c,
                                   visualize_stalls=False)

        #
        # Second step:
        # Optimize the loop body _again_, but  swap the two loop halves to that
        # successive iterations can be interleaved somewhat.
        #
        # The benefit of this approach is that we never call SLOTHY with generic SW pipelining,
        # which is computationally significantly more complex than 'normal' optimization.
        # We do still enable SW pipelining in SLOTHY if `halving_heuristic_periodic` is set, but
        # this is only to make SLOTHY consider the 'seam' between iterations -- since we unset
        # `allow_pre/post`, SLOTHY does not consider any loop interleaving.
        #

        # If the optimized loop body is [A;B], we now optimize [B;A], that is, the late half of one
        # iteration followed by the early half of the successive iteration. The hope is that this
        # enables good interleaving even without calling SLOTHY in SW pipelining mode.

        kernel = AsmHelper.reduce_source(kernel)
        kernel_len  = len(kernel)
        kernel_lenh = kernel_len // 2
        kernel_low  = kernel[:kernel_lenh]
        kernel_high = kernel[kernel_lenh:]
        kernel = kernel_high.copy() + kernel_low.copy()

        preamble, postamble = kernel_low, kernel_high

        dfgc = DFGConfig(conf.copy())
        dfgc.inputs_are_outputs = True
        kernel_deps = DFG(kernel, logger.getChild("dfg_kernel_deps"),dfgc).inputs

        logger.info("Apply halving heuristic to optimize two halves of consecutive loop kernels...")

        # The 'periodic' version considers the 'seam' between loop iterations; otherwise, we consider
        # [B;A] as a non-periodic snippet, which may still lead to stalls at the loop boundary.

        if conf.sw_pipelining.halving_heuristic_periodic:
            c = conf.copy()
            c.inputs_are_outputs = True
            c.sw_pipelining.minimize_overlapping = False
            c.sw_pipelining.enabled=True      # SW pipelining enabled, but ...
            c.sw_pipelining.allow_pre=False   # - no early instructions
            c.sw_pipelining.allow_post=False  # - no late instructions
                                              # Just make sure to consider loop boundary
            kernel = Heuristics.optimize_binsearch( kernel, logger.
                                                    getChild("periodic heuristic"), conf=c).code
        else:
            c = conf.copy()
            c.outputs = kernel_deps
            c.sw_pipelining.enabled=False
            kernel = Heuristics.linear( kernel, logger.getChild("heuristic"), conf=c)

        num_exceptional_iterations = 1
        return preamble, kernel, postamble, num_exceptional_iterations

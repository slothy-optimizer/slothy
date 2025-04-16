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

"""SLOTHY heuristics

The one-shot SLOTHY approach tends to become computationally infeasible above
200 assembly instructions. To optimize kernels beyond that threshold, this
module provides heuristics to split the optimization problem into several
smaller-sizes problems amenable to one-shot SLOTHY.
"""

import math

from slothy.core.dataflow import DataFlowGraph as DFG
from slothy.core.dataflow import Config as DFGConfig, ComputationNode
from slothy.core.core import SlothyBase, Result, SlothyException
from slothy.helper import Permutation, SourceLine
from slothy.helper import binary_search, BinarySearchLimitException


class Heuristics:
    """Break down large optimization problems into smaller ones.

    The one-shot SLOTHY approach tends to become computationally infeasible above
    200 assembly instructions. To optimize kernels beyond that threshold, this
    class provides heuristics to split the optimization problem into several
    smaller-sizes problems amenable to one-shot SLOTHY.
    """

    @staticmethod
    def _optimize_binsearch_core(source, logger, conf, **kwargs):

        logger_name = logger.name.replace(".", "_")
        last_successful = None

        def try_with_stalls(stalls, timeout=None):
            nonlocal last_successful

            logger.info(f"Attempt optimization with max {stalls} stalls...")
            c = conf.copy()
            c.constraints.stalls_allowed = stalls

            if c.hints.ext_bsearch_remember_successes:
                c.hints.rename_hint_orig_rename = True
                c.hints.order_hint_orig_order = True

            if timeout is not None:
                c.timeout = timeout
            core = SlothyBase(conf.arch, conf.target, logger=logger, config=c)

            if last_successful is not None:
                src = last_successful
            else:
                src = source
            success = core.optimize(src, **kwargs)

            if success and c.hints.ext_bsearch_remember_successes:
                last_successful = core.result.code

            return success, core

        try:
            return binary_search(
                try_with_stalls,
                minimum=conf.constraints.stalls_minimum_attempt - 1,
                start=conf.constraints.stalls_first_attempt,
                threshold=conf.constraints.stalls_maximum_attempt,
                precision=conf.constraints.stalls_precision,
                timeout_below_precision=conf.constraints.stalls_timeout_below_precision,
            )

        except BinarySearchLimitException:
            logger.error("Exceeded stall limit without finding a working solution")
            logger.error("Here's what you asked me to optimize:")

            Heuristics._dump(
                "Original source code",
                source,
                logger=logger,
                err=True,
                no_comments=True,
            )
            logger.error("Configuration:")
            conf.log(logger.error)

            err_file = conf.log_dir + f"/{logger_name}_ERROR.s"
            with open(err_file, "w", encoding="utf-8") as f:
                conf.log(lambda line: f.write("// " + line + "\n"))
                f.write("\n".join(source))

            logger.error(f"Stored this information in {err_file}")

    @staticmethod
    def optimize_binsearch(source: list, logger: any, conf: any, **kwargs: any) -> any:
        """Optimize for minimum number of stalls, and potentially a secondary objective.

        The `variable_size` configuration option determines whether the minimiation of
        stalls happens internally or externally. Internal minimization means that the
        number of stalls is part of the model, and its minimization registered as the
        objective to the underlying solver. External minimization means that the number
        of stalls is statically fixed per one-shot SLOTHY optimization, and that an
        external binary search is used to minimize it.

        :param source: The source code to be optimized. Must be a list of
            SourceLine instances.
        :type source: list
        :param logger: The logger to be used
        :type logger: any
        :param conf: The configuration to apply. This fixed for all one-shot SLOTHY
            runs invoked by this call, except for the variation of the stall count.
        :type conf: any
        :param **kwargs: An optional list of parameters to the core optimize routine
        :type **kwargs: any
        :returns: The Result object for the succeeding optimization with the smallest
                  number of stalls.
        :rtype: any
        """
        flexible = not conf.constraints.functional_only

        if conf.variable_size:
            return Heuristics.optimize_binsearch_internal(
                source, logger, conf, flexible=flexible, **kwargs
            )

        return Heuristics.optimize_binsearch_external(
            source, logger, conf, flexible=flexible, **kwargs
        )

    @staticmethod
    def _log_reoptimization_failure(log):
        log.warning(
            "Re-optimization with objective at minimum number of stalls failed. "
            "By the non-deterministic nature of the optimization, this can happen. "
            "Will just pick previous result..."
        )

    @staticmethod
    def _log_input_output_warning(log):
        log.warning(
            "You are using SW pipelining without setting inputs_are_outputs=True."
            "This means that the last iteration of the loop may overwrite inputs "
            "to the loop (such as address registers), unless they are marked as "
            "reserved registers. If this is intended, ignore this warning. "
            "Otherwise, consider setting inputs_are_outputs=True to ensure that "
            "nothing that is used as an input to the loop is overwritten, "
            "not even in the last iteration."
        )

    @staticmethod
    def optimize_binsearch_external(
        source: list, logger: any, conf: any, flexible: bool = True, **kwargs: any
    ) -> any:
        """Externally optimize for minimum number of stalls, and potentially a secondary
        objective.

        This function uses an external binary search to find the minimum number of stalls
        for which a one-shot SLOTHY optimization succeeds. If the provided configuration
        has a secondary objective, it then re-optimizes the result for that secondary
        objective, fixing the minimal number of stalls.


        :param source: The source code to be optimized. Must be a list of SourceLine
            instances.
        :type source: list
        :param logger: The logger to be used.
        :type logger: any
        :param conf: The configuration to apply. This is fixed for all one-shot SLOTHY
            runs invoked by this call, except for variation of stall count.
        :type conf: any
        :param flexible: Indicates whether the number of stalls should be minimized
            through a binary search, or whether a single one-shot SLOTHY optimization
            for a fixed number of stalls (encoded in the configuration) should be
            conducted.
        :type flexible: bool
        :param **kwargs: An optional list of parameters to the core optimize routine
        :type **kwargs: any
        :return: A Result object representing the final optimization result.
        :rtype: any
        :raises SlothyException: If optimization fails.
        """

        if not flexible:
            core = SlothyBase(conf.arch, conf.target, logger=logger, config=conf)
            if not core.optimize(source):
                raise SlothyException("Optimization failed")
            return core.result

        logger.info("Perform external binary search for minimal number of stalls...")

        c = conf.copy()
        c.ignore_objective = True
        min_stalls, core = Heuristics._optimize_binsearch_core(
            source, logger, c, **kwargs
        )

        if conf.has_objective is False:
            return core.result

        logger.info(
            "Optimize again with minimal number of %d stalls, with objective...",
            min_stalls,
        )
        first_result = core.result

        core.config.ignore_objective = False
        success = core.retry()

        if not success:
            Heuristics._log_reoptimization_failure(logger)
            return first_result

        return core.result

    @staticmethod
    def optimize_binsearch_internal(
        source: list, logger: any, conf: any, flexible: bool = True, **kwargs: any
    ) -> any:
        """Internally optimize for minimum number of stalls, and potentially a secondary
        objective.

        This finds the minimum number of stalls for which a one-shot SLOTHY optimization
        succeeds.
        If the provided configuration has a secondary objective, it then re-optimizes the
        result for that secondary objective, fixing the minimal number of stalls.


        :param source: The source code to be optimized. Must be a list of SourceLine
            instances.
        :type source: list
        :param  logger: The logger to be used.
        :type logger: any
        :param conf: The configuration to apply. This is fixed for all one-shot SLOTHY
            runs invoked by this call, except for variation of stall count.
        :type conf: any
        :param flexible: Indicates whether the number of stalls should be minimized
            through a binary search, or whether a single one-shot SLOTHY optimization
            for a fixed number of stalls (encoded in the configuration) should be
            conducted.
        :type flexible: bool
        :param **kwargs: An optional list of parameters to the core optimize routine
        :type **kwargs: any
        :return: A Result object representing the final optimization result.
        :rtype: any
        : raises SlothyException: If optimization fails.
        """

        if not flexible:
            core = SlothyBase(conf.arch, conf.target, logger=logger, config=conf)
            if not core.optimize(source):
                raise SlothyException("Optimization failed")
            return core.result

        logger.info("Perform internal binary search for minimal number of stalls...")

        start_attempt = conf.constraints.stalls_first_attempt
        cur_attempt = start_attempt

        while True:
            c = conf.copy()
            c.variable_size = True
            c.constraints.stalls_allowed = cur_attempt

            logger.info("Attempt optimization with max %d stalls...", cur_attempt)

            core = SlothyBase(c.arch, c.target, logger=logger, config=c)
            success = core.optimize(source, **kwargs)

            if success:
                min_stalls = core.result.stalls
                break

            cur_attempt = max(1, cur_attempt * 2)
            if cur_attempt > conf.constraints.stalls_maximum_attempt:
                logger.error("Exceeded stall limit without finding a working solution")
                raise SlothyException("No solution found")

        logger.info(f"Minimum number of stalls: {min_stalls}")

        # Spill minimization is integrated into the stall minimization objective
        if conf.has_objective is False or conf.constraints.minimize_spills is True:
            return core.result

        logger.info(
            "Optimize again with minimal number of %d stalls, with objective...",
            min_stalls,
        )
        first_result = core.result

        success = core.retry(fix_stalls=min_stalls)
        if not success:
            Heuristics._log_reoptimization_failure(logger)
            return first_result

        return core.result

    @staticmethod
    def periodic(body: list, logger: any, conf: any) -> any:
        """Entrypoint for optimization of loops.

        If software pipelining is disabled, this function forwards to
        the straightline optimization via Heuristics.linear().

        If software pipelining is enabled but the halving heuristic
        is disabled, this function performs a one-shot SLOTHY optimization
        without heuristics.

        If software pipelining is enabled and the halving heuristic is
        enabled, this function optimizes the loop body via straightline
        optimization first, splits result as `[A;B]`, and optimizes
        `[B;A]` again via straightline optimizations. The optimized loop
        is then given by the preamble `A`, kernel `opt(B;A)`, and postamble
        `B`. The straightline optimizations applied in this heuristics are
        done via Heuristics.linear() and thus themselves subject to the
        splitting heuristic, if enabled.


        :param body: The loop body to be optimized. This must be a list of
            SourceLine instances.
        :type body: list
        :param logger: The logger to be used.
        :type logger: any
        :param conf: The configuration to be applied.
        :type conf: any

        :return: Tuple (preamble, kernel, postamble, num_exceptional_iterations)
            of preamble, kernel and postamble (each as a list of SourceLine
            objects), plus the number of iterations jointly accounted for by
            the preamble and postamble (the caller will need this to adjust the
            loop counter).
        :rtype: any
        """

        if conf.sw_pipelining.enabled and not conf.inputs_are_outputs:
            Heuristics._log_input_output_warning(logger)

        if conf.sw_pipelining.enabled:
            body = body * conf.sw_pipelining.unroll

        if conf.inputs_are_outputs:
            dfg = DFG(
                body, logger.getChild("dfg_generate_outputs"), DFGConfig(conf.copy())
            )
            conf.outputs = dfg.outputs
            conf.inputs_are_outputs = False

        # If we're not asked to do software pipelining, just forward to
        # the heuristics for linear optimization.
        if not conf.sw_pipelining.enabled:
            res = Heuristics.linear(body, logger=logger, conf=conf)
            return [], res.code, [], 0

        if conf.sw_pipelining.halving_heuristic:
            return Heuristics._periodic_halving(body, logger, conf)

        # 'Normal' software pipelining
        #
        # We first perform the core periodic optimization of the loop kernel,
        # and then separate passes for the optimization for the preamble and postamble

        # First step: Optimize loop kernel

        logger.debug("Optimize loop kernel...")
        c = conf.copy()
        c.inputs_are_outputs = True
        result = Heuristics.optimize_binsearch(body, logger.getChild("slothy"), c)

        conf.outputs = list(
            map(lambda o: result.output_renamings.get(o, o), conf.outputs)
        )

        num_exceptional_iterations = result.num_exceptional_iterations
        kernel = result.code
        assert SourceLine.is_source(kernel)

        # Second step: Separately optimize preamble and postamble

        preamble = result.preamble
        if conf.sw_pipelining.optimize_preamble:
            logger.debug("Optimize preamble...")
            Heuristics._dump("Preamble", preamble, logger)
            logger.debug("Dependencies within kernel: %s", result.kernel_input_output)
            c = conf.copy()
            c.outputs = result.kernel_input_output
            c.sw_pipelining.enabled = False
            res_preamble = Heuristics.linear(
                preamble, conf=c, logger=logger.getChild("preamble")
            )
            preamble = res_preamble.code

        postamble = result.postamble
        if conf.sw_pipelining.optimize_postamble:
            logger.debug("Optimize postamble...")
            Heuristics._dump("Preamble", postamble, logger)
            c = conf.copy()
            c.sw_pipelining.enabled = False
            res_postamble = Heuristics.linear(
                postamble, conf=c, logger=logger.getChild("postamble")
            )
            postamble = res_postamble.code

        return preamble, kernel, postamble, num_exceptional_iterations

    @staticmethod
    def linear(body: list, logger: any, conf: any) -> any:
        """Entrypoint for straightline optimization.

        If the split heuristic is disabled, this forwards to a one-shot optimization.

        If the split heuristic is enabled (conf.split_heuristic == True), the assembly
        input is optimized by successively applying one-shot optimizations to a
        'sliding window' of code.

        :param body: The assembly input to be optimized. This must be a list of
            SourceLine objects.
        :type body: list
        :param logger: The logger to be used.
        :type logger: any
        :param conf: The configuration to be applied. Software pipelining must be
            disabled.
        :type conf: any
        :return: A Result object representing the final optimization result.
        :rtype: any
        :raises SlothyException: If software pipelining is enabled.
        """
        assert SourceLine.is_source(body)
        if conf.sw_pipelining.enabled:
            raise SlothyException(
                "Linear heuristic should only be called " "with SW pipelining disabled"
            )

        Heuristics._dump("Starting linear optimization...", body, logger)

        # So far, we only implement one heuristic: The splitting heuristic --
        # If that's disabled, just forward to the core optimization
        if not conf.split_heuristic:
            return Heuristics.optimize_binsearch(body, logger.getChild("slothy"), conf)

        return Heuristics._split(body, logger, conf)

    @staticmethod
    def _naive_reordering(body, logger, conf, use_latency_depth=False):

        if use_latency_depth:
            depth_str = "latency depth"
        else:
            depth_str = "depth"

        logger.info(f"Perform naive interleaving by {depth_str}... ")
        old = body.copy()
        le = len(body)
        dfg = DFG(body, logger.getChild("dfg"), DFGConfig(conf.copy()), parsing_cb=True)
        insts = [dfg.nodes[i] for i in range(le)]

        if use_latency_depth is True:
            # Calculate latency-depth of instruction nodes
            nodes_by_depth = dfg.nodes.copy()
            nodes_by_depth.sort(key=lambda t: t.depth)
            for t in dfg.nodes_all:
                t.latency_depth = 0

            def get_latency(tp, t):
                if tp.src.is_virtual:
                    return 0
                return conf.target.get_latency(tp.src.inst, tp.idx, t.inst)

            for t in nodes_by_depth:
                srcs = t.src_in + t.src_in_out
                t.latency_depth = max(
                    map(
                        lambda tp, t=t: tp.src.latency_depth + get_latency(tp, t), srcs
                    ),
                    default=0,
                )

        def get_depth(t):
            if use_latency_depth is False:
                pre_depth = t.depth
            else:
                pre_depth = t.latency_depth
            scale = float(t.inst.source_line.tags.get("naive_interleaving_scale", 1.0))
            return int(pre_depth * scale)

        depths = [get_depth(dfg.nodes_by_id[i]) for i in range(le)]

        inputs = dfg.inputs.copy()
        outputs = conf.outputs.copy()

        perm = Permutation.permutation_id(le)

        def get_inputs(inst):
            return set(inst.args_in + inst.args_in_out)

        def get_outputs(inst):
            return set(inst.args_out + inst.args_in_out)

        joint_prev_inputs = {}
        joint_prev_outputs = {}

        strategy = conf.split_heuristic_preprocess_naive_interleaving_strategy

        def get_interleaving_class(j):
            return int(insts[j].inst.source_line.tags.get("interleaving_class", 0))

        if strategy == "alternate":
            # Compute target ratio between code classes
            sz_0 = max(
                len(list(filter(lambda j: get_interleaving_class(j) == 0, range(le)))),
                1,
            )
            sz_1 = max(
                len(list(filter(lambda j: get_interleaving_class(j) == 1, range(le)))),
                1,
            )
            target_ratio = sz_0 / sz_1

        for i in range(le):
            cur_joint_prev_inputs = set()
            cur_joint_prev_outputs = set()
            for j in range(i, le):
                joint_prev_inputs[j] = cur_joint_prev_inputs
                cur_joint_prev_inputs = cur_joint_prev_inputs.union(
                    get_inputs(insts[j].inst)
                )

                joint_prev_outputs[j] = cur_joint_prev_outputs
                cur_joint_prev_outputs = cur_joint_prev_outputs.union(
                    get_outputs(insts[j].inst)
                )

            # Find instructions which could, in principle, come next, without
            # any renaming
            def could_come_next(j):
                cur_outputs = get_outputs(insts[j].inst)
                prev_inputs = joint_prev_inputs[j]

                cur_inputs = get_inputs(insts[j].inst)
                prev_outputs = joint_prev_outputs[j]

                ok = (
                    len(cur_outputs.intersection(prev_inputs)) == 0
                    and len(cur_inputs.intersection(prev_outputs)) == 0
                )

                return ok

            candidate_idxs = list(filter(could_come_next, range(i, le)))
            logger.debug(f"Potential next candidates: {candidate_idxs}")

            def pick_candidate(candidate_idxs):

                if strategy == "depth":
                    candidate_depths = list(map(lambda j: depths[j], candidate_idxs))
                    logger.debug("Candidate %s: %s", depth_str, candidate_depths)
                    choice_idx = candidate_idxs[
                        candidate_depths.index(min(candidate_depths))
                    ]

                else:
                    assert strategy == "alternate"

                    sz_0 = max(
                        len(
                            list(
                                filter(
                                    lambda j: get_interleaving_class(j) == 0, range(i)
                                )
                            )
                        ),
                        1,
                    )
                    sz_1 = max(
                        len(
                            list(
                                filter(
                                    lambda j: get_interleaving_class(j) == 1, range(i)
                                )
                            )
                        ),
                        1,
                    )

                    candidates_0 = filter(
                        lambda j: get_interleaving_class(j) == 0, candidate_idxs
                    )
                    candidates_1 = filter(
                        lambda j: get_interleaving_class(j) == 1, candidate_idxs
                    )

                    current_ratio = sz_0 / sz_1

                    c0 = next(candidates_0, None)
                    c1 = next(candidates_1, None)

                    if current_ratio > target_ratio and c1 is not None:
                        choice_idx = c1
                    elif c0 is not None:
                        choice_idx = c0
                    else:
                        choice_idx = candidate_idxs[0]

                return choice_idx

            def move_entry_forward(lst, idx_from, idx_to):
                entry = lst[idx_from]
                del lst[idx_from]
                return lst[:idx_to] + [entry] + lst[idx_to:]

            choice_idx = None
            while choice_idx is None:
                choice_idx = pick_candidate(candidate_idxs)
                insts = move_entry_forward(insts, choice_idx, i)

            local_perm = Permutation.permutation_move_entry_forward(le, choice_idx, i)
            perm = Permutation.permutation_comp(local_perm, perm)

            body = list(map(ComputationNode.to_source_line, insts))
            depths = move_entry_forward(depths, choice_idx, i)
            body[i].set_length(100).set_comment(f"{depth_str} {depths[i]}")
            Heuristics._dump("New code", body, logger)

        # Selfcheck
        res = Result(conf)
        res.orig_code = old
        res.code = body.copy()
        res.codesize_with_bubbles = le
        res.success = True
        res.reordering_with_bubbles = perm
        res.input_renamings = {s: s for s in inputs}
        res.output_renamings = {s: s for s in outputs}
        res.valid = True
        res.selfcheck(logger.getChild("naive_interleaving_selfcheck"))

        res.offset_fixup(logger.getChild("naive_interleaving_fixup"))
        body = res.code_raw

        Heuristics._dump("Before naive interleaving", old, logger)
        Heuristics._dump("After naive interleaving", body, logger)
        return body, perm

    @staticmethod
    def _idxs_from_fractions(fraction_lst, body):
        return [round(f * len(body)) for f in fraction_lst]

    @staticmethod
    def _get_ssa_form(body, logger, conf):
        logger.info("Transform DFG into SSA...")
        dfg = DFG(
            body, logger.getChild("dfg_ssa"), DFGConfig(conf.copy()), parsing_cb=True
        )
        dfg.ssa()
        ssa = [ComputationNode.to_source_line(t) for t in dfg.nodes]
        return ssa

    @staticmethod
    def _split_inner(body, logger, conf, ssa=False):

        le = len(body)
        if le == 0:
            return body
        log = logger.getChild("split")

        # Allow to proceed in steps
        split_factor = conf.split_heuristic_factor

        orig_body = body.copy()

        if conf.split_heuristic_preprocess_naive_interleaving:

            if ssa:
                body = Heuristics._get_ssa_form(body, logger, conf)
                Heuristics._dump("Code in SSA form:", body, logger, err=True)

            body, perm = Heuristics._naive_reordering(
                body,
                log,
                conf,
                use_latency_depth=(
                    conf.split_heuristic_preprocess_naive_interleaving_by_latency
                ),
            )

            if ssa:
                log.debug("Remove symbolics after SSA...")
                c = conf.copy()
                c.constraints.allow_reordering = False
                c.constraints.functional_only = True
                body = SourceLine.reduce_source(body)
                result = Heuristics.optimize_binsearch(
                    body, log.getChild("remove_symbolics"), conf=c
                )
                body = result.code
                body = SourceLine.reduce_source(body)
        else:
            perm = Permutation.permutation_id(le)

        def print_intarr(arr, ll, vals=50):
            m = max(10, max(arr))
            start_idxs = [(ll * i) // vals for i in range(vals)]
            end_idxs = [(ll * (i + 1)) // vals for i in range(vals)]
            avgs = []
            for s, e in zip(start_idxs, end_idxs):
                if s == e:
                    continue
                avg = sum(arr[s:e]) // (e - s)
                avgs.append(avg)
                log.info(f"[{s:3d}-{e:3d}]: {'*'*avg}{'.'*(m-avg)} ({avg})")

        def print_stalls(stalls, le):
            chunk_len = int(le // split_factor)
            # Convert stalls into 01 valued function
            stalls_arr = [i in stalls for i in range(le)]
            for v in stalls_arr:
                assert v in {0, 1}
            stalls_cumulative = [
                sum(
                    stalls_arr[
                        max(0, i - math.floor(chunk_len / 2)) : i
                        + math.ceil(chunk_len / 2)
                    ]
                )
                for i in range(le)
            ]
            print_intarr(stalls_cumulative, le)

        def optimize_chunk(start_idx, end_idx, body, stalls, show_stalls=True):
            """Optimizes a sub-chunks of the given snippet, delimited by pairs
            of start and end indices provided as arguments. Input/output register
            names stay intact -- in particular, overlapping chunks are allowed."""

            cur_pre = body[:start_idx]
            cur_body = body[start_idx:end_idx]
            cur_post = body[end_idx:]

            if not conf.split_heuristic_optimize_seam:
                prefix_len = 0
                suffix_len = 0
            else:
                prefix_len = min(len(cur_pre), conf.split_heuristic_optimize_seam)
                suffix_len = min(len(cur_post), conf.split_heuristic_optimize_seam)
                cur_prefix = cur_pre[-prefix_len:] if prefix_len > 0 else []
                cur_suffix = cur_post[:suffix_len]
                cur_body = cur_prefix + cur_body + cur_suffix
                cur_pre = cur_pre[:-prefix_len] if prefix_len > 0 else cur_pre
                cur_post = cur_post[suffix_len:]

            pre_pad = len(cur_pre)
            post_pad = len(cur_post)

            Heuristics._dump(
                f"Optimizing chunk [{start_idx}-{prefix_len}:{end_idx}+{suffix_len}]",
                cur_body,
                log,
            )
            if prefix_len > 0:
                Heuristics._dump("Using prefix", cur_prefix, log)
            if suffix_len > 0:
                Heuristics._dump("Using suffix", cur_suffix, log)

            # Find dependencies of rest of body

            dfgc = DFGConfig(conf.copy())
            dfgc.outputs = set(dfgc.outputs).union(conf.outputs)
            cur_outputs = DFG(cur_post, log.getChild("dfg_infer_outputs"), dfgc).inputs

            c = conf.copy()
            c.rename_inputs = {"other": "static"}  # No renaming
            c.rename_outputs = {"other": "static"}  # No renaming
            c.inputs_are_outputs = False
            c.outputs = cur_outputs

            result = Heuristics.optimize_binsearch(
                cur_body,
                log.getChild(f"{start_idx}_{end_idx}"),
                c,
                prefix_len=prefix_len,
                suffix_len=suffix_len,
            )
            Heuristics._dump(f"New chunk [{start_idx}:{end_idx}]", result.code, log)
            new_body = cur_pre + SourceLine.reduce_source(result.code) + cur_post

            perm = Permutation.permutation_pad(result.reordering, pre_pad, post_pad)

            keep_stalls = {
                i
                for i in stalls
                if i < start_idx - prefix_len or i >= end_idx + suffix_len
            }
            new_stalls = keep_stalls.union(
                map(lambda i: i + start_idx - prefix_len, result.stall_positions)
            )

            if show_stalls:
                print_stalls(new_stalls, le)

            return new_body, new_stalls, len(result.stall_positions), perm

        def optimize_chunks_many(
            start_end_idx_lst,
            body,
            stalls,
            abort_stall_threshold_high=None,
            abort_stall_threshold_low=None,
            **kwargs,
        ):
            perm = Permutation.permutation_id(len(body))
            for start_idx, end_idx in start_end_idx_lst:
                body, stalls, cur_stalls, local_perm = optimize_chunk(
                    start_idx, end_idx, body, stalls, **kwargs
                )
                perm = Permutation.permutation_comp(local_perm, perm)
                if (
                    abort_stall_threshold_high is not None
                    and cur_stalls > abort_stall_threshold_high
                ):
                    break
                if (
                    abort_stall_threshold_low is not None
                    and cur_stalls < abort_stall_threshold_low
                ):
                    break
            return body, stalls, perm

        cur_body = body

        def make_idx_list_consecutive(factor, increment):
            chunk_len = 1 / factor
            cur_start = 0
            cur_end = 0
            start_pos = []
            end_pos = []
            while cur_end < 1.0:
                cur_end = cur_start + chunk_len
                cur_end = min(cur_end, 1.0)
                start_pos.append(cur_start)
                end_pos.append(cur_end)

                cur_start += increment

            def not_empty(x):
                return x[0] != x[1]

            idx_lst = zip(
                Heuristics._idxs_from_fractions(start_pos, cur_body),
                Heuristics._idxs_from_fractions(end_pos, cur_body),
            )
            idx_lst = list(filter(not_empty, idx_lst))
            return idx_lst

        stalls = set()
        increment = 1 / split_factor

        # First, do a 'dry run' solely for finding the initial 'stall map'
        if conf.split_heuristic_repeat > 0:
            orig_conf = conf.copy()
            conf.constraints.allow_reordering = False
            conf.constraints.allow_renaming = False
            idx_lst = make_idx_list_consecutive(split_factor, increment)
            cur_body, stalls, _ = optimize_chunks_many(
                idx_lst, cur_body, stalls, show_stalls=False
            )
            conf = orig_conf.copy()

            log.info("Initial stalls")
            print_stalls(stalls, le)

        if conf.split_heuristic_stepsize is None:
            increment = 1 / (2 * split_factor)
        else:
            increment = conf.split_heuristic_stepsize

        # Remember inputs and outputs
        dfgc = DFGConfig(conf.copy())
        outputs = conf.outputs.copy()
        inputs = DFG(orig_body, log.getChild("dfg_infer_inputs"), dfgc).inputs.copy()

        for _ in range(conf.split_heuristic_repeat):

            cur_body = SourceLine.reduce_source(cur_body)

            if conf.split_heuristic_chunks:
                start_pos = [x[0] for x in conf.split_heuristic_chunks]
                end_pos = [x[1] for x in conf.split_heuristic_chunks]
                idx_lst = zip(
                    Heuristics._idxs_from_fractions(start_pos, cur_body),
                    Heuristics._idxs_from_fractions(end_pos, cur_body),
                )

                def not_empty(x):
                    return x[0] != x[1]

                idx_lst = list(filter(not_empty, idx_lst))
            else:
                idx_lst = make_idx_list_consecutive(split_factor, increment)
                if conf.split_heuristic_bottom_to_top is True:
                    idx_lst.reverse()

            cur_body, stalls, local_perm = optimize_chunks_many(
                idx_lst,
                cur_body,
                stalls,
                abort_stall_threshold_high=conf.split_heuristic_abort_cycle_at_high,
                abort_stall_threshold_low=conf.split_heuristic_abort_cycle_at_low,
            )
            perm = Permutation.permutation_comp(local_perm, perm)

        # Check complete result
        res = Result(conf)
        res.orig_code = orig_body
        res.code = SourceLine.reduce_source(cur_body).copy()
        res.codesize_with_bubbles = res.codesize
        res.success = True
        res.reordering_with_bubbles = perm
        res.input_renamings = {s: s for s in inputs}
        res.output_renamings = {s: s for s in outputs}
        res.valid = True
        res.selfcheck(log.getChild("split_heuristic_full"))

        # Estimate performance of final code
        if conf.split_heuristic_estimate_performance:
            conf2 = conf.copy()
            conf2.constraints.allow_renaming = False
            conf2.constraints.allow_reordering = False
            conf2.variable_size = True
            stall_res = Heuristics.optimize_binsearch(
                res.code, logger.getChild("split_estimtate_perf"), conf2
            )
            if stall_res.success is False:
                log.error(
                    "Stall-estimate for final code after split heuristic failed"
                    " -- should not happen? Maybe increase timeout?"
                    " Just returning the result without stall-estimate."
                )
            else:
                res2 = Result(conf2)
                res2.orig_code = orig_body
                res2.code = res.code_raw
                res2.codesize_with_bubbles = stall_res.codesize_with_bubbles
                res2.success = True
                # Compose actual code reordering from split heuristic with
                # bubble-introducing (order-preserving) map
                res2.reordering_with_bubbles = {
                    i: stall_res.reordering_with_bubbles[res.reordering_with_bubbles[i]]
                    for i in range(res.codesize)
                }
                res2.input_renamings = {s: s for s in inputs}
                res2.output_renamings = {s: s for s in outputs}
                res2.valid = True
                res2.selfcheck(log.getChild("split_heuristic_full_with_stalls"))

                res = res2

        return res

    @staticmethod
    def _split(body, logger, conf):
        c = conf.copy()

        # Focus on the chosen subregion
        body = SourceLine.reduce_source(body)

        if c.split_heuristic_region == [0.0, 1.0]:
            return Heuristics._split_inner(body, logger, c)

        inputs = DFG(body, logger.getChild("dfg_generate_inputs"), DFGConfig(c)).inputs

        start_end_idxs = Heuristics._idxs_from_fractions(c.split_heuristic_region, body)
        start_idx = start_end_idxs[0]
        end_idx = start_end_idxs[1]

        pre = body[:start_idx]
        partial_body = body[start_idx:end_idx]
        post = body[end_idx:]

        # Adjust the outputs
        c.outputs = DFG(
            post, logger.getChild("dfg_generate_outputs"), DFGConfig(c)
        ).inputs
        c.inputs_are_outputs = False

        res = Heuristics._split_inner(partial_body, logger, c)
        new_partial_body = res.code

        pre_pad = len(pre)
        post_pad = len(post)
        perm = Permutation.permutation_pad(res.reordering, pre_pad, post_pad)

        new_body = SourceLine.reduce_source(pre + new_partial_body + post)

        res2 = Result(conf)
        res2.orig_code = body.copy()
        res2.code = new_body
        res2.codesize_with_bubbles = pre_pad + post_pad + res.codesize_with_bubbles
        res2.success = True
        res2.reordering_with_bubbles = perm
        res2.input_renamings = {s: s for s in inputs}
        res2.output_renamings = {s: s for s in conf.outputs}
        res2.valid = True
        res2.selfcheck(logger.getChild("split"))

        return res2

    @staticmethod
    def _dump(name, s, logger, err=False, no_comments=False):
        assert SourceLine.is_source(s)
        s = [line.to_string() for line in s]

        def strip_comments(sl):
            return [s.split("//")[0].strip() for s in sl]

        fun = logger.debug if not err else logger.error
        fun(f"Dump: {name} (size {len(s)})")
        if no_comments:
            s = strip_comments(s)
        for line in s:
            fun(f"> {line}")

    @staticmethod
    def _periodic_halving(body, logger, conf):

        assert conf is not None
        assert conf.sw_pipelining.enabled
        assert conf.sw_pipelining.halving_heuristic

        body = SourceLine.reduce_source(body)

        # Find kernel dependencies
        kernel_deps = DFG(
            body, logger.getChild("dfg_kernel_deps"), DFGConfig(conf.copy())
        ).inputs

        # First step: Optimize loop kernel, but without software pipelining
        c = conf.copy()
        c.sw_pipelining.enabled = False
        c.inputs_are_outputs = True
        c.outputs = c.outputs.union(kernel_deps)

        if not conf.sw_pipelining.halving_heuristic_split_only:
            res_halving_0 = Heuristics.linear(body, logger.getChild("slothy"), conf=c)

            # Split resulting kernel as [A;B] and synthesize result structure
            # as if SW pipelining has been used and the result would have been
            # [B;A], with preamble A and postamble B.
            #
            # Run the normal SW-pipelining selfcheck on this result.
            #
            # The overall goal here is to produce a result structure that's structurally
            # the same as for normal SW pipelining, including checks and visualization.
            #
            # TODO: The 2nd optimization step below does not yet produce a Result
            # structure.
            reordering = res_halving_0.reordering
            codesize = res_halving_0.codesize

            def rotate_pos(p):
                return p - (codesize // 2)

            def is_pre(i):
                return rotate_pos(reordering[i]) < 0

            kernel = SourceLine.reduce_source(res_halving_0.code)
            preamble = kernel[: codesize // 2]
            postamble = kernel[codesize // 2 :]

            # Swap halves around and consider new kernel [B;A]
            kernel = postamble + preamble

            dfgc = DFGConfig(c.copy())
            dfgc.inputs_are_outputs = False
            core_out = DFG(postamble, logger.getChild("dfg_kernel_deps"), dfgc).inputs

            dfgc = DFGConfig(conf.copy())
            dfgc.inputs_are_outputs = True
            dfgc.outputs = core_out
            new_kernel_deps = DFG(
                kernel, logger.getChild("dfg_kernel_deps"), dfgc
            ).inputs

            c2 = c.copy()
            c2.sw_pipelining.enabled = True

            reordering1 = {i: rotate_pos(reordering[i]) for i in range(codesize)}
            pre_core_post_dict1 = {
                i: (is_pre(i), not is_pre(i), False) for i in range(codesize)
            }

            res = Result(c2)
            res.orig_code = body
            res.code = kernel
            res.preamble = preamble
            res.postamble = postamble
            res.kernel_input_output = new_kernel_deps
            res.codesize_with_bubbles = res_halving_0.codesize_with_bubbles
            res.reordering_with_bubbles = reordering1
            res.pre_core_post_dict = pre_core_post_dict1
            res.input_renamings = {s: s for s in kernel_deps}
            res.output_renamings = {s: s for s in c.outputs}
            res.success = True
            res.valid = True

            # Check result as if it has been produced by SW pipelining run
            res.selfcheck(logger.getChild("halving_heuristic_1"))

        else:
            logger.info("Halving heuristic: Split-only -- no optimization")
            codesize = len(body)
            preamble = body[: codesize // 2]
            postamble = body[codesize // 2 :]
            kernel = postamble + preamble

            dfgc = DFGConfig(c.copy())
            dfgc.inputs_are_outputs = False
            kernel_deps = DFG(
                postamble, logger.getChild("dfg_kernel_deps"), dfgc
            ).inputs

            dfgc = DFGConfig(conf.copy())
            dfgc.inputs_are_outputs = True
            kernel_deps = DFG(kernel, logger.getChild("dfg_kernel_deps"), dfgc).inputs

        #
        # Second step:
        # Optimize the loop body _again_, but  swap the two loop halves to that
        # successive iterations can be interleaved somewhat.
        #
        # The benefit of this approach is that we never call SLOTHY with generic SW
        # pipelining, which is computationally significantly more complex than 'normal'
        # optimization. We do still enable SW pipelining in SLOTHY if
        # `halving_heuristic_periodic` is set, but this is only to make SLOTHY consider
        # the 'seam' between iterations -- since we unset `allow_pre/post`, SLOTHY does
        # not consider any loop interleaving.
        #

        # If the optimized loop body is [A;B], we now optimize [B;A], that is, the late
        # half of one iteration followed by the early half of the successive iteration.
        # The hope is that this enables good interleaving even without calling SLOTHY in
        # SW pipelining mode.

        logger.info(
            "Apply halving heuristic to optimize two halves "
            "of consecutive loop kernels..."
        )

        # The 'periodic' version considers the 'seam' between iterations; otherwise, we
        # consider [B;A] as a non-periodic snippet, which may still lead to stalls at the
        # loop boundary.

        if conf.sw_pipelining.halving_heuristic_periodic:
            c = conf.copy()
            c.inputs_are_outputs = True
            c.sw_pipelining.minimize_overlapping = False
            c.sw_pipelining.enabled = True  # SW pipelining enabled, but ...
            c.sw_pipelining.allow_pre = False  # - no early instructions
            c.sw_pipelining.allow_post = False  # - no late instructions
            # Just make sure to consider loop boundary
            kernel = Heuristics.optimize_binsearch(
                kernel, logger.getChild("periodic heuristic"), conf=c
            ).code
        elif not conf.sw_pipelining.halving_heuristic_split_only:
            c = conf.copy()
            c.outputs = new_kernel_deps
            c.inputs_are_outputs = True
            c.sw_pipelining.enabled = False

            res_halving_1 = Heuristics.linear(
                kernel, logger.getChild("heuristic"), conf=c
            )
            final_kernel = res_halving_1.code

            reordering2 = res_halving_1.reordering_with_bubbles

            c2 = conf.copy()

            def get_reordering2(i):
                is_pre = res.pre_core_post_dict[i][0]
                p = reordering2[res.periodic_reordering[i]]
                if is_pre:
                    p -= res_halving_1.codesize_with_bubbles
                return p

            reordering2 = {i: get_reordering2(i) for i in range(codesize)}

            res2 = Result(c2)
            res2.orig_code = body
            res2.code = SourceLine.reduce_source(final_kernel)
            res2.kernel_input_output = new_kernel_deps
            res2.codesize_with_bubbles = res_halving_1.codesize_with_bubbles
            res2.reordering_with_bubbles = reordering2
            res2.pre_core_post_dict = pre_core_post_dict1
            res2.input_renamings = res.input_renamings
            res2.output_renamings = res.output_renamings

            new_preamble = [
                final_kernel[i]
                for i in range(res2.codesize)
                if res2.is_pre(i, original_program_order=False) is True
            ]
            new_postamble = [
                final_kernel[i]
                for i in range(res2.codesize)
                if res2.is_pre(i, original_program_order=False) is False
            ]

            res2.preamble = new_preamble
            res2.postamble = new_postamble
            res2.success = True
            res2.valid = True

            # TODO: This does not yet work since there can be renaming at the boundary
            # between preamble and postamble that we don't account for in the selfcheck.
            # res2.selfcheck(logger.getChild("halving_heuristic_2"))

            kernel = final_kernel

        num_exceptional_iterations = 1
        return preamble, kernel, postamble, num_exceptional_iterations

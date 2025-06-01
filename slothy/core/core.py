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

import logging
import math
import time

from types import SimpleNamespace
from copy import deepcopy
from functools import cached_property
from sympy import simplify

import ortools
from ortools.sat.python import cp_model

from slothy.core.config import Config
from slothy.helper import (
    LockAttributes,
    Permutation,
    DeferHandler,
    SourceLine,
    SelfTest,
)

from slothy.core.dataflow import DataFlowGraph as DFG
from slothy.core.dataflow import Config as DFGConfig
from slothy.core.dataflow import InstructionOutput, InstructionInOut, ComputationNode
from slothy.core.dataflow import SlothyUselessInstructionException


class SlothyException(Exception):
    """Generic exception thrown by SLOTHY"""


class SlothySelfCheckException(SlothyException):
    """Exception thrown by SLOTHY during tht selfcheck"""


class Result(LockAttributes):
    """The results of a one-shot SLOTHY optimization run"""

    @property
    def orig_code(self):
        """Optimization input: Source code"""
        return self._orig_code

    @orig_code.setter
    def orig_code(self, val):
        assert self._orig_code is None
        self._orig_code = val

    def _gen_orig_code_visualized_perf(self):
        early_char = self.config.early_char
        late_char = self.config.late_char
        core_char = self.config.core_char
        d = self.config.placeholder_char

        mirror_char = self.config.mirror_char

        fixlen = max(map(len, self.orig_code)) + 8

        def arr_width(arr):
            mi = min(arr)
            ma = max(0, max(arr))
            return mi, ma - mi

        def center_str_fixlen(txt, fixlen, char="-"):
            txt = " " + txt + " "
            le = min(len(txt), fixlen)
            lpad = (fixlen - le) // 2
            rpad = (fixlen - le) - lpad
            return char * lpad + txt + char * rpad

        block_size = 25

        min_pos, width = arr_width(self.cycle_position_with_bubbles.values())
        width = max(width, block_size + 5)

        cycles = width
        cycle_blocks = math.ceil(cycles / block_size)
        cycle_remainder = cycles % block_size

        legend0 = center_str_fixlen("cycle (expected)", cycles, "-") + ">"
        legend1 = "".join(
            [str(i * block_size).ljust(block_size) for i in range(cycle_blocks)]
        )
        legend2 = (("|" + "-" * (block_size - 1))) * (cycle_blocks - 1)
        legend2 = (
            legend2
            + "|"
            + "-" * (cycle_remainder if cycle_remainder != 0 else block_size)
        )
        yield SourceLine("")
        yield SourceLine("").set_comment(legend0).set_length(fixlen + 1)
        yield SourceLine("").set_comment(legend1).set_length(fixlen + 1)
        yield SourceLine("").set_comment(legend2).set_length(fixlen + 1)
        for i in range(self.codesize):
            pos = self.cycle_position_with_bubbles[i] - min_pos
            c = core_char
            if self.config.sw_pipelining.enabled and self.is_pre(i):
                c = early_char
            elif self.config.sw_pipelining.enabled and self.is_post(i):
                c = late_char

            # String of the form "...{e,*,l}...", with e/l/* in position pos
            t_comment = [d for _ in range(width + 1)]
            if self.config.sw_pipelining.enabled is True:
                if min_pos < 0:
                    t_comment[-min_pos] = "'"
                c_pos = max(-min_pos, 0) + self.cycles
                while c_pos < width:
                    t_comment[c_pos] = "'"
                    c_pos += self.cycles

            c_pos = pos
            t_comment[c_pos] = c

            if self.config.sw_pipelining.enabled is True:
                # Also display sibling of instruction in other iterations
                c = mirror_char
                c_pos = pos - self.cycles
                while c_pos >= 0:
                    t_comment[c_pos] = c
                    c_pos -= self.cycles
                c_pos = pos + self.cycles
                while c_pos < width:
                    t_comment[c_pos] = c
                    c_pos += self.cycles

            t_comment = "".join(t_comment)

            yield SourceLine("").set_comment(
                f"{self.orig_code[i].text:{fixlen-3}s}"
            ).add_comment(t_comment)

        yield SourceLine("")

    def _gen_orig_code_visualized_perm(self):
        early_char = self.config.early_char
        late_char = self.config.late_char
        core_char = self.config.core_char
        mirror_char = self.config.mirror_char
        d = self.config.placeholder_char

        fixlen = max(map(len, self.orig_code)) + 8

        def arr_width(arr):
            mi = min(arr)
            ma = max(0, max(arr))
            return mi, ma - mi

        def center_str_fixlen(txt, fixlen, char="-"):
            txt = " " + txt + " "
            le = min(len(txt), fixlen)
            lpad = (fixlen - le) // 2
            rpad = (fixlen - le) - lpad
            return char * lpad + txt + char * rpad

        min_pos, width = arr_width(self.reordering.values())

        block_size = 25
        width = max(width, block_size + 5)

        cycles = width
        cycle_blocks = math.ceil(cycles / block_size)
        cycle_remainder = cycles % block_size

        legend0 = center_str_fixlen("new position", cycles, "-") + ">"
        legend1 = "".join(
            [str(i * block_size).ljust(block_size) for i in range(cycle_blocks)]
        )
        legend2 = (("|" + "-" * (block_size - 1))) * (cycle_blocks - 1)
        legend2 = (
            legend2
            + "|"
            + "-" * (cycle_remainder if cycle_remainder != 0 else block_size)
        )
        yield SourceLine("")
        yield SourceLine("").set_comment(legend0).set_length(fixlen + 1)
        yield SourceLine("").set_comment(legend1).set_length(fixlen + 1)
        yield SourceLine("").set_comment(legend2).set_length(fixlen + 1)
        for i in range(self.codesize):
            pos = self.reordering[i] - min_pos
            c = core_char
            if self.config.sw_pipelining.enabled and self.is_pre(i):
                c = early_char
            elif self.config.sw_pipelining.enabled and self.is_post(i):
                c = late_char

            # String of the form "...{e,*,l}...", with e/l/* in position pos
            t_comment = [d for _ in range(width + 1)]
            if self.config.sw_pipelining.enabled is True:
                if min_pos < 0:
                    t_comment[-min_pos] = "'"
                c_pos = max(-min_pos, 0) + self.codesize
                while c_pos < width:
                    t_comment[c_pos] = "'"
                    c_pos += self.codesize

            c_pos = pos
            t_comment[c_pos] = c

            if self.config.sw_pipelining.enabled is True:
                # Also display sibling of instruction in other iterations
                c = mirror_char
                c_pos = pos - self.codesize
                while c_pos >= 0:
                    t_comment[c_pos] = c
                    c_pos -= self.codesize
                c_pos = pos + self.codesize
                while c_pos < width:
                    t_comment[c_pos] = c
                    c_pos += self.codesize

            t_comment = "".join(t_comment)

            yield SourceLine("").set_comment(
                f"{self.orig_code[i].text:{fixlen-3}s}"
            ).add_comment(t_comment)

        yield SourceLine("")

    def _gen_orig_code_visualized(self):
        if self.codesize == 0:
            return

        if self.config.visualize_expected_performance:
            yield from self._gen_orig_code_visualized_perf()
        else:
            yield from self._gen_orig_code_visualized_perm()

    @property
    def cycles(self):
        """The number of cycles that SLOTHY thinks the code will take.

        If software pipelining is enabled, this is the expected average cycle
        count per iteration."""
        return self.codesize_with_bubbles // self.config.target.issue_rate

    @property
    def cycles_bound(self):
        """A lower bound for the number of cycles obtained during optimization.

        This may be lower than the estimated cycle count of the result itself if
        optimization terminated prematurely, e.g. because of a timeout."""
        return self._cycles_bound

    @property
    def ipc_bound(self):
        """An upper bound on the instruction/cycle (IPC) count obtained during
        optimization.

        This may be lower than the IPC value of the result itself if optimization
        terminated prematurely, e.g. because of a timeout."""
        cc = self.cycles_bound
        if cc is None or cc == 0:
            return None
        return self.codesize / cc

    @property
    def optimization_wall_time(self):
        """Returns the amount of wall clock time in seconds the optimization has taken"""
        return self._optimization_wall_time

    @property
    def optimization_user_time(self):
        """Returns the amount of CPU time in seconds the optimization has taken"""
        return self._optimization_user_time

    @property
    def ipc(self):
        """The instruction/cycle (IPC) count that SLOTHY thinks the code will have."""
        cc = self.cycles
        if cc == 0:
            return 0
        return self.codesize / cc

    @property
    def orig_code_visualized(self):
        """Optimization input: Source code, including visualization of reordering"""
        return list(self._gen_orig_code_visualized())

    @property
    def orig_inputs(self):
        """The list of input registers in the _original_ source code."""
        return list(self.input_renamings.keys())

    @property
    def orig_outputs(self):
        """The list of output registers in the _original_ source code."""
        return list(self.output_renamings.keys())

    @property
    def codesize(self):
        """The number of instructions in the (original and optimized) source code."""
        return len(self.orig_code)

    @property
    def codesize_with_bubbles(self):
        """Performance-measure for the optimized source code.

        This is the number of issue slots used by the optimized code.
        Equivalently, after division by the target's issue width, it is
        SLOTHY's expectation of the performance of the code in cycles.

        It is also the codomain of the xxx_with_bubbles dictionaries.
        """
        return self._codesize_with_bubbles

    @codesize_with_bubbles.setter
    def codesize_with_bubbles(self, v):
        assert self._codesize_with_bubbles is None
        self._codesize_with_bubbles = v

    @optimization_user_time.setter
    def optimization_user_time(self, v):
        assert self._optimization_user_time is None
        self._optimization_user_time = v

    @optimization_wall_time.setter
    def optimization_wall_time(self, v):
        assert self._optimization_wall_time is None
        self._optimization_wall_time = v

    @property
    def pre_core_post_dict(self):
        """Dictionary indicating interleaving of iterations.

        This dictionary consists of items (i, (pre, core, post)), where
        i is the original program order position of an instruction, and
        pre, core, post indicate whether that instruction is an early,
        core or late instruction in the optimized source code.

        An early instruction is one which is pulled into the previous iteration.
        A late instruction is one which is deferred until the next iteration.
        A core instruction is one which is left in its original iteration.

        This property is only meaningful when software pipelining is enabled.

        See also is_pre, is_core, is_post.
        """
        self._require_sw_pipelining()
        return self._pre_core_post_dict

    @pre_core_post_dict.setter
    def pre_core_post_dict(self, v):
        self._require_sw_pipelining()
        assert self._pre_core_post_dict is None
        self._pre_core_post_dict = v

    def is_pre(self, i, original_program_order=True):
        """Indicates if the instruction in original program order position i
        (starting at 0) was marked 'early' and thereby pulled into the previous iteration.

        If original_program_order is False, the index instead refers to the _new_ program
        order position with in the kernel of the optimized loop.

        This only makes sense when software pipelining was enabled."""
        if not self.config.sw_pipelining.enabled:
            return False

        if not original_program_order:
            i = self.periodic_reordering_inv[i]

        return self.pre_core_post_dict[i][0]

    def is_core(self, i, original_program_order=True):
        """Indicates if the instruction in original program order position i
        (starting at 0) was neither marked 'early' nor 'late', so stayed in its original
        iteration.

        If original_program_order is False, the index instead refers to the _new_ program
        order position with in the kernel of the optimized loop.

        This only makes sense when software pipelining was enabled."""
        if not self.config.sw_pipelining.enabled:
            return True

        if not original_program_order:
            i = self.periodic_reordering_inv[i]

        return self.pre_core_post_dict[i][1]

    def is_post(self, i, original_program_order=True):
        """Indicates if the instruction in original program order position i
        (starting at 0) was marked 'late' and thereby pulled into the next iteration.

        This only makes sense when software pipelining was enabled."""
        if not self.config.sw_pipelining.enabled:
            return False

        if not original_program_order:
            i = self.periodic_reordering_inv[i]

        return self.pre_core_post_dict[i][2]

    @cached_property
    def num_pre(self):
        """In a software pipelining result, the number of 'early' instructions."""
        self._require_sw_pipelining()
        return sum(pre for (pre, _, _) in self.pre_core_post_dict.values())

    @cached_property
    def num_core(self):
        """In a software pipelining result, the number of 'late' instructions."""
        self._require_sw_pipelining()
        return sum(core for (_, core, _) in self.pre_core_post_dict.values())

    @cached_property
    def num_post(self):
        """In a software pipelining result, the number of 'core' instructions
        (neither early nor late)."""
        self._require_sw_pipelining()
        return sum(post for (_, _, post) in self.pre_core_post_dict.values())

    @cached_property
    def num_prepost(self):
        """In a software pipelining result, the number of early or late instructions.
        This can be seen as a measure for the amount of interleaving across iterations
        that has happened."""
        self._require_sw_pipelining()
        return sum(pre + post for (pre, _, post) in self.pre_core_post_dict.values())

    @cached_property
    def num_exceptional_iterations(self):
        """The number of loop iterations jointly covered by the loop preamble and
        postamble. In other words, the amount by which the iteration count for the
        optimized loop kernel is lower than the original iteration count."""
        self._require_sw_pipelining()
        # If there are either (a) only early instructions, or (b) only late instructions,
        # the loop preamble and postamble make up for 1 full loop iteration. If there are
        # both early and late instructions, then the preamble and postamble make up for
        # 2 full loop iterations.
        return sum(
            [
                (self.num_pre > 0) or (self.num_post > 0),
                (self.num_pre > 0) and (self.num_post > 0),
            ]
        )

    @property
    def reordering_with_bubbles(self):
        """The reordering map linking original and optimized source code.

        The output ordering includes 'bubbles' reflecting where SLOTHY thinks
        that the target microarchitecture would stall.

        This is a map from [0,...,codesize) to [0,...,codesize_with_bubbles).
        """
        # TODO: Clarify how early and late instructions are treated in the case
        # of software pipelining
        return self._reordering_with_bubbles

    @reordering_with_bubbles.setter
    def reordering_with_bubbles(self, v):
        assert self._reordering_with_bubbles is None
        self._reordering_with_bubbles = v

    @cached_property
    def cycle_position_with_bubbles(self):
        """Maps the original program order position of an instruction to the cycle number
        in which SLOTHY thinks (according to its microarchitecture model) the instruction
        would execute."""
        return {
            k: v // self.config.target.issue_rate
            for (k, v) in self.reordering_with_bubbles.items()
        }

    @cached_property
    def reordering_with_bubbles_inv(self):
        """The inverse reordering permutation linking optimized and original source
        code"""
        return {v: k for k, v in self.reordering_with_bubbles.items()}

    def get_reordering_with_bubbles(self, copies):
        """The reordering permutation linking original and optimized source code after
        unrolling `copies` times.
        The output ordering includes 'bubbles' reflecting where SLOTHY thinks
        that the target microarchitecture would stall."""
        res = {
            orig_pos + k * self.codesize: k * self.codesize_with_bubbles + new_pos
            for (orig_pos, new_pos) in self.reordering_with_bubbles.items()
            for k in range(copies)
        }
        return res

    def get_periodic_reordering_with_bubbles(self, copies):
        tmp = self.get_reordering_with_bubbles(copies)
        if not self.config.sw_pipelining.enabled:
            return tmp

        for i, (pre, _, post) in self.pre_core_post_dict.items():
            if pre:
                tmp[i] += copies * self.codesize_with_bubbles
            if post:
                tmp[(copies - 1) * self.codesize + i] -= (
                    copies * self.codesize_with_bubbles
                )
        return tmp

    def get_periodic_reordering_with_bubbles_inv(self, copies):
        """The inverse permutation of get_periodic_reordering_with_bubbles()"""
        tmp = self.get_periodic_reordering_with_bubbles(copies)
        tmpr = {v: k for (k, v) in tmp.items()}
        return tmpr

    def get_periodic_reordering(self, copies):
        t = self.get_periodic_reordering_with_bubbles(copies)
        vals = list(t.values())
        vals.sort()
        res = {i: vals.index(v) for (i, v) in t.items()}
        assert Permutation.is_permutation(res, copies * self.codesize)
        return res

    def get_periodic_reordering_inv(self, copies):
        tmp = self.get_periodic_reordering(copies)
        tmpr = {v: k for (k, v) in tmp.items()}
        assert Permutation.is_permutation(tmpr, copies * self.codesize)
        return tmpr

    def get_reordering(self, copies, no_gaps):

        tmp = self.get_periodic_reordering(copies)
        if not self.config.sw_pipelining.enabled:
            return tmp

        for i, (pre, _, post) in self.pre_core_post_dict.items():
            if pre:
                tmp[i] -= copies * self.codesize
            if post:
                tmp[(copies - 1) * self.codesize + i] += copies * self.codesize

        if no_gaps:
            tmp_sorted = list(tmp.items())
            tmp_sorted.sort(key=lambda x: x[1])
            tmp_sorted = [x[0] for x in tmp_sorted]
            tmp = {i: pos for (pos, i) in enumerate(tmp_sorted)}

        return tmp

    def get_fully_unrolled_loop(self, iterations):
        self._require_sw_pipelining()
        assert iterations > self.num_exceptional_iterations
        kernel_copies = iterations - self.num_exceptional_iterations
        new_source = self._preamble + (self._code * kernel_copies) + self._postamble
        old_source = self._orig_code * iterations
        return old_source, new_source

    def get_unrolled_kernel(self, iterations):
        self._require_sw_pipelining()
        return self._code * iterations

    @cached_property
    def reordering(self):
        """The reordering permutation linking original and optimized source code"""
        return self.get_reordering(1, no_gaps=False)

    @cached_property
    def periodic_reordering_with_bubbles(self):
        return self.get_periodic_reordering_with_bubbles(1)

    @cached_property
    def periodic_reordering_with_bubbles_inv(self):
        """The inverse dictionary to periodic_reordering_with_bubbles"""
        return self.get_periodic_reordering_with_bubbles_inv(1)

    @cached_property
    def periodic_reordering(self):
        return self.get_periodic_reordering(1)

    @cached_property
    def periodic_reordering_inv(self):
        """The inverse permutation to periodic_reordering"""
        res = self.get_periodic_reordering_inv(1)
        assert Permutation.is_permutation(res, self.codesize)
        return res

    @cached_property
    def reordering_inv(self):
        """The inverse reordering permutation linking optimized and original source
        code"""
        return {v: k for k, v in self.reordering.items()}

    @property
    def fixlen(self):
        return max(map(len, self.code_raw), default=0) + 8

    @property
    def code_raw(self):
        """Optimized code, without annotations"""
        return self._code

    def _get_code(self, visualize_reordering):
        code = self._code
        assert SourceLine.is_source(code)
        ri = self.periodic_reordering_with_bubbles_inv

        fixlen = self.fixlen
        for line in code:
            line.set_length(fixlen)

        if visualize_reordering is False:
            return code

        early_char = self.config.early_char
        late_char = self.config.late_char
        core_char = self.config.core_char
        d = self.config.placeholder_char

        def gen_restore(reg, loc, vis):
            args = self.config.constraints.spill_type
            yield SourceLine(
                self.config.arch.Spill.restore(reg, loc, **args)
            ).set_length(self.fixlen).set_comment(vis).add_tag(
                "is_restore", True
            ).add_tag(
                "reads", f"stack_{loc}"
            )

        def gen_spill(reg, loc, vis):
            args = self.config.constraints.spill_type
            yield SourceLine(self.config.arch.Spill.spill(reg, loc, **args)).set_length(
                self.fixlen
            ).set_comment(vis).add_tag("is_spill", True).add_tag(
                "writes", f"stack_{loc}"
            )

        def center_str_fixlen(txt, fixlen, char="-"):
            txt = " " + txt + " "
            le = min(len(txt), fixlen)
            lpad = (fixlen - le) // 2
            rpad = (fixlen - le) - lpad
            return char * lpad + txt + char * rpad

        def gen_visualized_code_perm():
            cs = self.codesize_with_bubbles
            if cs == 0:
                return
            block_size = 25
            width = max(self.codesize, block_size + 5)
            blocks = math.ceil(width / block_size)

            def gen_vis(p, c):
                return d * p + c + d * (width - p - 1)

            legend0 = center_str_fixlen("original position", width - 1, "-") + ">"
            legend1 = "".join(
                [str(i * block_size).ljust(block_size) for i in range(blocks)]
            )
            legend2 = (("|" + "-" * (block_size - 1))) * (blocks - 1)
            legend2 = legend2 + "|" + "-" * max(width % block_size - 1, 0)
            yield SourceLine("").set_comment(legend0).set_length(fixlen)
            yield SourceLine("").set_comment(legend1).set_length(fixlen)
            yield SourceLine("").set_comment(legend2).set_length(fixlen)
            for i in range(self.codesize_with_bubbles):
                p = ri.get(i, None)
                spills = self._spills.get(i, [])
                restores = self._restores.get(i, [])
                if p is not None:
                    c = core_char
                    if self.is_pre(p):
                        c = early_char
                    elif self.is_post(p):
                        c = late_char
                    s = code[self.periodic_reordering[p]]
                    yield s.copy().set_length(fixlen).set_comment(gen_vis(p, c))
                for reg, loc in restores:
                    yield from gen_restore(reg, loc, gen_vis(0, d))
                for reg, loc in spills:
                    yield from gen_spill(reg, loc, gen_vis(0, d))
                if p is None and len(spills) == 0 and len(restores) == 0:
                    gap_str = "gap"
                    yield SourceLine("").set_comment(
                        f"{gap_str:{fixlen-4}s}"
                    ).add_comment(d * width)

        def gen_visualized_code_perf():
            cs = self.codesize_with_bubbles
            if cs == 0:
                return
            block_size = 25
            cycles = max(self.cycles, block_size + 5)
            cycle_blocks = math.ceil(cycles / block_size)

            def gen_vis(cc, c):
                return d * cc + c + d * (cycles - cc - 1)

            legend0 = center_str_fixlen("cycle (expected)", cycles - 1, "-") + ">"
            legend1 = "".join(
                [str(i * block_size).ljust(block_size) for i in range(cycle_blocks)]
            )
            legend2 = (("|" + "-" * (block_size - 1))) * (cycle_blocks - 1)
            legend2 = legend2 + "|" + "-" * max(cycles % block_size - 1, 0)
            yield SourceLine("").set_comment(legend0).set_length(fixlen)
            yield SourceLine("").set_comment(legend1).set_length(fixlen)
            yield SourceLine("").set_comment(legend2).set_length(fixlen)
            for i in range(cs):
                p = ri.get(i, None)
                spills = self._spills.get(i, [])
                restores = self._restores.get(i, [])
                cc = i // self.config.target.issue_rate
                if p is not None:
                    c = core_char
                    if self.is_pre(p):
                        c = early_char
                    elif self.is_post(p):
                        c = late_char
                    s = code[self.periodic_reordering[p]]
                    yield s.copy().set_length(fixlen).set_comment(gen_vis(cc, c))
                for reg, loc in restores:
                    yield from gen_restore(reg, loc, gen_vis(cc, "r"))
                for reg, loc in spills:
                    yield from gen_spill(reg, loc, gen_vis(cc, "s"))

        def gen_visualized_code_with_old():
            orig_code = self._orig_code
            cs = self.codesize_with_bubbles
            if cs == 0:
                return

            old_code = []
            old_maxlen = 0
            for i in range(self.codesize_with_bubbles):
                p = ri.get(i, None)
                if p is None:
                    old_code.append(None)
                    continue
                t = orig_code[p].text
                old_code.append(t)
                old_maxlen = max(old_maxlen, len(t))

            for i in range(self.codesize_with_bubbles):
                p = ri.get(i, None)
                spills = self._spills.get(i, [])
                restores = self._restores.get(i, [])
                if p is not None:
                    s = code[self.periodic_reordering[p]]
                    yield s.copy().set_length(fixlen).set_comment(
                        f"{old_code[i]:{old_maxlen + 8}s}"
                    )
                for reg, loc in restores:
                    yield from gen_restore(reg, loc, f"{'-':{old_maxlen+8}s}")
                for reg, loc in spills:
                    yield from gen_spill(reg, loc, f"{'-':{old_maxlen+8}s}")

        def gen_visualized_code():
            if self.config.visualize_expected_performance is True:
                yield from gen_visualized_code_perf()
            elif self.config.visualize_show_old_code is True:
                yield from gen_visualized_code_with_old()
            else:
                yield from gen_visualized_code_perm()

        res = []
        res.append(
            SourceLine("")
            .set_comment(f"Instructions:    {self.codesize}")
            .set_length(fixlen)
        )
        res.append(
            SourceLine("")
            .set_comment(f"Expected cycles: {self.cycles}")
            .set_length(fixlen)
        )
        res.append(
            SourceLine("")
            .set_comment(f"Expected IPC:    {self.ipc:.2f}")
            .set_length(fixlen)
        )
        if self.cycles_bound is not None:
            res.append(SourceLine("").set_comment("").set_length(fixlen))
            res.append(
                SourceLine("")
                .set_comment(f"Cycle bound:     {self.cycles_bound}")
                .set_length(fixlen)
            )
            res.append(
                SourceLine("")
                .set_comment(f"IPC bound:       {self.ipc_bound:.2f}")
                .set_length(fixlen)
            )
        if self.optimization_wall_time is not None:
            res.append(SourceLine("").set_comment("").set_length(fixlen))
            res.append(
                SourceLine("")
                .set_comment(f"Wall time:     {self.optimization_wall_time:.2f}s")
                .set_length(fixlen)
            )
            res.append(
                SourceLine("")
                .set_comment(f"User time:     {self.optimization_user_time:.2f}s")
                .set_length(fixlen)
            )
        res.append(SourceLine("").set_comment("").set_length(fixlen))

        res += list(gen_visualized_code())
        res += self.orig_code_visualized
        return res

    @property
    def code(self):
        """The optimized source code"""
        c = self._get_code(self.config.visualize_reordering)
        return c

    @code.setter
    def code(self, val):
        assert SourceLine.is_source(val)
        # We should only pass reduced source code here
        pre_reduce_len = len(val)
        val = SourceLine.reduce_source(val)
        post_reduce_len = len(val)
        assert pre_reduce_len == post_reduce_len
        self._code = val

    def _get_full_code(self, log):
        if self.config.sw_pipelining.enabled:
            # Unroll the loop a fixed number of times
            iterations = 5
            old_source, new_source = self.get_fully_unrolled_loop(iterations)
            reordering = self.get_reordering(iterations, no_gaps=True)
        else:
            old_source = self.orig_code
            new_source = self.code
            reordering = self.reordering.copy()
            iterations = 1

        n = iterations * self.codesize
        assert Permutation.is_permutation(reordering, n)

        dfg_old_log = log.getChild("dfg_old")
        dfg_new_log = log.getChild("dfg_new")
        SourceLine.log(f"Old code ({iterations} copies)", old_source, dfg_old_log)
        SourceLine.log(f"New code ({iterations} copies)", new_source, dfg_new_log)

        tree_old = DFG(
            old_source, dfg_old_log, DFGConfig(self.config, outputs=self.orig_outputs)
        )
        tree_new = DFG(
            new_source, dfg_new_log, DFGConfig(self.config, outputs=self.outputs)
        )

        return n, old_source, new_source, tree_old, tree_new, reordering

    def selfcheck(self, log):
        """Checks that the original and optimized source code have isomorphic DFGs.
        More specifically, that the reordering permutation stored in Result object
        yields an isomorphism between DFGs.

        When software pipelining is used, this is a bounded check for a fixed number
        of iterations."""
        try:
            res = self._selfcheck_core(log)
        except SlothyUselessInstructionException as exc:
            raise SlothySelfCheckException(
                "Useless instruction detected during selfcheck: FAIL!"
            ) from exc
        if self.config.selfcheck and not res:
            raise SlothySelfCheckException(
                "Isomorphism between computation flow graphs: FAIL!"
            )
        return res

    def selftest(self, log):
        """Run empirical self test, if it exists for the target architecture"""
        if self._config.selftest is False:
            return

        if (
            self._config.arch.unicorn_arch is None
            or self._config.arch.llvm_mc_arch is None
        ):
            log.warning("Selftest not supported on target architecture")
            return

        tree = DFG(self._orig_code, log, DFGConfig(self.config, outputs=self.outputs))

        if tree.has_symbolic_registers():
            log.info("Skipping selftest as input contains symbolic registers.")
            return

        log.info(f"Running selftest ({self._config.selftest_iterations} iterations)...")

        address_registers = self._config.selftest_address_registers
        if address_registers is None:
            # Try to infer which registes need to be pointers
            # Look for load/store instructions and remember addresses
            addresses = set()
            for t in tree.nodes:
                addr = getattr(t.inst, "addr", None)
                if addr is None:
                    continue
                addresses = addresses.union(
                    tree.find_all_predecessors_input_registers(t, addr)
                )

            # For now, we don't look into increments and immedate offsets
            # to gauge the amount of memory we actually need. Instaed, we
            # just allocate a buffer of a configurable default size.
            log.info(
                f"Inferred that the following registers seem to act as pointers: "
                f"{addresses}"
            )
            log.info(
                f"Using default buffer size of "
                f"{self._config.selftest_default_memory_size} bytes. "
                "If you want different buffer sizes, set selftest_address_registers "
                "manually."
            )
            address_registers = {
                a: self._config.selftest_default_memory_size for a in addresses
            }

        # This produces _unrolled_ code, the same that is checked in the selfcheck.
        # The selftest should instead use the rolled form of the loop.
        iterations = 7
        if self.config.sw_pipelining.enabled is True:
            old_source, new_source = self.get_fully_unrolled_loop(iterations)

            dfgc_preamble = DFGConfig(self.config, outputs=self.kernel_input_output)
            dfgc_preamble.inputs_are_outputs = False
            preamble_dfg = DFG(self.preamble, log, dfgc_preamble)

            if preamble_dfg.has_symbolic_registers():
                log.info("Skipping selftest as preamble contains symbolic registers.")
                return

            dfgc_postamble = DFGConfig(self.config, outputs=self.orig_outputs)
            postamble_dfg = DFG(
                self.postamble, log.getChild("new_postamble"), dfgc_postamble
            )

            if postamble_dfg.has_symbolic_registers():
                log.info("Skipping selftest as postamble contains symbolic registers.")
                return
        else:
            old_source, new_source = self.orig_code, self.code

        # Check if register contents are the same
        regs_expected = set(self.config.outputs).union(self.config.reserved_regs)
        # Ignore hint registers, flags and sp for now
        regs_expected = set(
            filter(
                lambda t: t.startswith("t") is False and t != "sp" and t != "flags",
                regs_expected,
            )
        )

        # filter out branches
        old_source = [line for line in old_source if not line.tags.get("branch")]
        new_source = [line for line in new_source if not line.tags.get("branch")]

        SelfTest.run(
            self.config,
            log,
            old_source,
            new_source,
            address_registers,
            regs_expected,
            self.config.selftest_iterations,
        )

    def selfcheck_with_fixup(self, log):
        """Do selfcheck, and consider preamble/postamble fixup in case of SW pipelining

        In the presence of cross iteration dependencies, the preamble and postamble
        may be functionally incorrect and need fixup."""

        # We gather the log output of the initial selfcheck and only release
        # it (a) on success, or (b) when even the selfcheck after fixup fails.

        defer_handler = DeferHandler()
        log.propagate = False
        log.addHandler(defer_handler)

        exception = None
        try:
            self.selfcheck(log)
        except SlothySelfCheckException as e:
            exception = e

        log.propagate = True
        log.removeHandler(defer_handler)

        if exception is not None and self.config.sw_pipelining.enabled:
            retry = True
        elif exception is not None:
            # We don't expect a failure if there are no cross-iteration dependencies
            if self.config.selfcheck_failure_logfile is not None:
                defer_handler.forward_to_file(
                    "selfcheck", self.config.selfcheck_failure_logfile
                )
            defer_handler.forward(log)
            raise exception
        else:
            retry = False

        if retry is False:
            # Show the log output
            defer_handler.forward(log)
        else:
            log.info(
                "Selfcheck failed! This sometimes happens in the presence "
                "of cross-iteration dependencies. Try fixup..."
            )
            self.fixup_preamble_postamble(log.getChild("fixup_preamble_postamble"))

            try:
                self.selfcheck(log.getChild("after_fixup"))
            except SlothySelfCheckException as e:
                log.error("Here is the output of the original selfcheck before fixup")
                if self.config.selfcheck_failure_logfile is not None:
                    defer_handler.forward_to_file(
                        "selfcheck", self.config.selfcheck_failure_logfile
                    )
                defer_handler.forward(log)
                raise e

    def _selfcheck_core(self, log):
        _, old_source, new_source, tree_old, tree_new, reordering = self._get_full_code(
            log
        )
        edges_old = tree_old.edges()
        edges_new = tree_new.edges()

        # Add renaming for inputs and outputs to permutation
        for old, new in self.input_renamings.items():
            reordering[f"input_{old}"] = f"input_{new}"
        for old, new in self.output_renamings.items():
            reordering[f"output_{old}"] = f"output_{new}"

        # The DFG isomorphism check is, perhaps surprisingly, very simple:
        # We take the set of labelled edges of source and destination graph, apply
        # the node permutation, and assert equality of sets.

        def apply_reordering(x):
            src, dst, lbl = x
            if src not in reordering.keys():
                raise SlothyException(
                    f"Source ID {src} not in remapping {reordering.items()}"
                )
            if dst not in reordering:
                raise SlothyException(
                    f"Destination ID {dst} not in remapping {reordering.items()}"
                )
            return (reordering[src], reordering[dst], lbl)

        edges_old_remapped = set(map(apply_reordering, edges_old))
        reordering_inv = {j: i for (i, j) in reordering.items()}

        # DFG isomorphism as set-equality between remapped edge sets
        if edges_old_remapped == edges_new:
            log.debug("Isomophism between computation flow graphs: OK!")
            log.info("OK!")
            return True

        log.error("Isomophism between computation flow graphs: FAIL!")

        log.error("Input/Output renaming")
        log.error(reordering)

        SourceLine.log("old code", old_source, log, err=True)
        SourceLine.log("new code", new_source, log, err=True)

        new_not_old = [e for e in edges_new if e not in edges_old_remapped]
        old_not_new = [e for e in edges_old_remapped if e not in edges_new]

        log.error("Old graph")
        tree_old.describe(error=True)
        log.error("New graph")
        tree_new.describe(error=True)

        # In the remainder, we try to give some indication of where the purpoted
        # isomorphism failed by listing edges present in one DFG but not the other.

        for src_idx, dst_idx, lbl in new_not_old:
            src = tree_new.nodes_by_id[src_idx]
            dst = tree_new.nodes_by_id[dst_idx]
            log.error(
                f"New ({src_idx}:{src})"
                f"---{lbl}--->({dst_idx}:{dst}) not present in old graph"
            )

        for src_idx, dst_idx, lbl in old_not_new:
            src_idx_old = reordering_inv[src_idx]
            dst_idx_old = reordering_inv[dst_idx]
            src_old = tree_old.nodes_by_id[src_idx_old]
            dst_old = tree_old.nodes_by_id[dst_idx_old]
            log.error(
                f"Old ({src_old})[id:{src_idx_old}]"
                f"---{lbl}--->{dst_old}[id:{dst_idx_old}] not present in new graph"
            )

        log.error("Isomorphism between computation flow graphs: FAIL!")
        return False

    @property
    def inputs(self):
        """The list of input registers in the _optimized_ source code. This is a list
        of architectural registers, and relates to the inputs of the original source
        code via Result.input_renaming. For the list of original input register names,
        use Result.orig_inputs."""
        return list(self.input_renamings.values())

    @property
    def outputs(self):
        """The list of output registers in the _optimized_ source code. This is a list
        of architectural registers, and relates to the outputs of the original source
        code via Result.output_renaming. For the list of original output register names,
        use Result.orig_outputs."""
        return list(self.output_renamings.values())

    @property
    def input_renamings(self):
        """Dictionary mapping original input names to architectural register names
        used in the optimized source code. See also Config.rename_inputs."""
        return self._input_renamings

    @input_renamings.setter
    def input_renamings(self, v):
        assert self._input_renamings is None
        self._input_renamings = v

    @property
    def output_renamings(self):
        """Dictionary mapping original output names to architectural register names
        used in the optimized source code. See also Config.rename_outputs."""
        return self._output_renamings

    @output_renamings.setter
    def output_renamings(self, v):
        assert self._output_renamings is None
        self._output_renamings = v

    @property
    def stalls(self):
        """The number of stalls in the optimization result.

        More precisely: The number of cycles c such that optimization succeeded with
        up to c * issue_width unused issue slots."""
        return self._stalls

    @stalls.setter
    def stalls(self, v):
        assert self._stalls is None
        self._stalls = v

    @cycles_bound.setter
    def cycles_bound(self, v):
        assert self._cycles_bound is None
        self._cycles_bound = v

    def _build_stalls_idxs(self):
        self._stalls_idxs = {
            j
            for (i, j) in self.reordering.items()
            if self.reordering_with_bubbles[i] + 1
            not in self.reordering_with_bubbles.values()
        }

    @property
    def stall_positions(self):
        """The positions of instructions in the optimized assembly where SLOTHY
        expects a stall or unused issue slot."""
        if self._stalls_idxs is None:
            self._build_stalls_idxs()
        return self._stalls_idxs

    @property
    def kernel(self):
        """When using software pipelining, the loop kernel of the optimized loop."""
        self._require_sw_pipelining()
        return self.code

    @property
    def kernel_input_output(self):
        """When using software pipelining, the dependencies between successive loop
        iterations.

        This is useful if you want to further optimize the preamble (and perhaps some code
        preceeding it), because the kernel dependencies are the output of the preamble.
        """
        self._require_sw_pipelining()
        return self._kernel_input_output

    @kernel_input_output.setter
    def kernel_input_output(self, val):
        assert self._kernel_input_output is None
        self._kernel_input_output = val

    @property
    def preamble(self):
        """When using software pipelining, the preamble of the optimized loop."""
        self._require_sw_pipelining()
        return self._preamble

    @preamble.setter
    def preamble(self, val):
        self._preamble = val

    @property
    def postamble(self):
        """When using software pipelining, the postamble of the optimized loop."""
        self._require_sw_pipelining()
        return self._postamble

    @postamble.setter
    def postamble(self, val):
        self._postamble = val

    @property
    def config(self):
        """The configuration that was used for the optimization."""
        return self._config

    @property
    def success(self):
        """Whether the optimization was successful"""
        if not self._valid:
            raise SlothyException("Querying not-yet-populated result object")
        return self._success

    def __bool__(self):
        return self.success

    @success.setter
    def success(self, val):
        assert self._success is None
        self._success = val

    @property
    def valid(self):
        """Indicates whether the result object is valid."""
        return self._valid

    @valid.setter
    def valid(self, val):
        self._valid = val

    def _require_sw_pipelining(self):
        if not self.config.sw_pipelining.enabled:
            raise SlothyException(
                "Asking for SW-pipelining attribute in result "
                "of SLOTHY run without SW pipelining"
            )

    @staticmethod
    def _fixup_reordered_pair(t0, t1, logger):

        def inst_changes_addr(inst):
            return inst.increment is not None

        if not t0.inst.is_load_store_instruction():
            return
        if not t1.inst.is_load_store_instruction():
            return
        if not t0.inst.addr == t1.inst.addr:
            return
        if inst_changes_addr(t0.inst) and inst_changes_addr(t1.inst):
            logger.error(
                "=======================   ERROR   ==============================="
            )
            logger.error(
                f"    Cannot handle reordering of two instructions ({t0} and {t1}) "
            )
            logger.error(
                "           which both want to modify the same address            "
            )
            logger.error(
                "================================================================="
            )
            raise SlothyException("Address fixup failure")

        if inst_changes_addr(t0.inst):
            # t1 gets reordered before t0, which changes the address
            # Adjust t1's address accordingly
            logger.debug(
                f"{t0} moved after {t1}, bumping {t1.fixup} by {t0.inst.increment}, "
                f"to {t1.fixup + int(simplify(t0.inst.increment))}"
            )
            t1.fixup += int(simplify(t0.inst.increment))
        elif inst_changes_addr(t1.inst):
            # t0 gets reordered after t1, which changes the address
            # Adjust t0's address accordingly
            logger.debug(
                f"{t1} moved before {t0}, lowering {t0.fixup} by {t1.inst.increment}, "
                f"to {t0.fixup - int(simplify(t1.inst.increment))}"
            )
            t0.fixup -= int(simplify(t1.inst.increment))

    @staticmethod
    def _fixup_reset(nodes):
        for t in nodes:
            t.fixup = 0

    @staticmethod
    def _fixup_finish(nodes, logger):
        def inst_changes_addr(inst):
            return inst.increment is not None

        for t in nodes:
            if not t.inst.is_load_store_instruction():
                continue
            if inst_changes_addr(t.inst):
                continue
            if t.fixup == 0:
                continue
            if t.inst.pre_index:
                t.inst.pre_index = f"(({t.inst.pre_index}) + ({t.fixup}))"
            else:
                t.inst.pre_index = f"{t.fixup}"
            logger.debug(f"Fixed up instruction {t.inst} by {t.fixup}, to {t.inst}")

    def _offset_fixup_sw(self, log):
        n, _, _, _, tree_new, reordering = self._get_full_code(log)
        iterations = n // self.codesize

        Result._fixup_reset(tree_new.nodes)
        for _, _, ni, nj in Permutation.iter_swaps(reordering, n):
            Result._fixup_reordered_pair(tree_new.nodes[ni], tree_new.nodes[nj], log)
        Result._fixup_finish(tree_new.nodes, log)

        preamble_len = len(self.preamble)
        postamble_len = len(self.postamble)

        assert n // iterations == self.codesize

        preamble_new = list(
            map(ComputationNode.to_source_line, tree_new.nodes[:preamble_len])
        )
        postamble_new = (
            [ComputationNode.to_source_line(t) for t in tree_new.nodes[-postamble_len:]]
            if postamble_len > 0
            else []
        )

        code_new = []
        for i in range(iterations - self.num_exceptional_iterations):
            code_new.append(
                [
                    ComputationNode.to_source_line(t)
                    for t in tree_new.nodes[
                        preamble_len
                        + i * self.codesize : preamble_len
                        + (i + 1) * self.codesize
                    ]
                ]
            )

        # Flag if address fixup makes the kernel instable. In this case, we'd have to
        # widen preamble and postamble, but this is not yet implemented.
        count = 0
        for i, (kcur, knext) in enumerate(zip(code_new, code_new[1:])):
            if SourceLine.write_multiline(kcur) != SourceLine.write_multiline(knext):
                count += 1
        if count != 0:
            raise SlothyException(
                "Instable loop kernel after post-optimization address fixup"
            )
        code_new = code_new[0]

        self.preamble = preamble_new
        self.postamble = postamble_new
        self.code = code_new

    def _offset_fixup_straightline(self, log):
        n, _, _, _, tree_new, reordering = self._get_full_code(log)

        Result._fixup_reset(tree_new.nodes)
        for _, _, ni, nj in Permutation.iter_swaps(reordering, n):
            Result._fixup_reordered_pair(tree_new.nodes[ni], tree_new.nodes[nj], log)
        Result._fixup_finish(tree_new.nodes, log)

        self.code = [ComputationNode.to_source_line(t) for t in tree_new.nodes]

    def offset_fixup(self, log):
        """Fixup address offsets after optimization"""
        if self.config.sw_pipelining.enabled:
            self._offset_fixup_sw(log)
        else:
            self._offset_fixup_straightline(log)

    def fixup_preamble_postamble(self, log):
        """Potentially fix up the preamble and postamble

        When software pipelining is used in the context of a loop with cross-iteration
        dependencies, the core optimization step might lead to functionally incorrect
        preamble and postamble. This function checks if this is the case and fixes
        preamble and postamble, if necessary.
        """

        # if not self._has_cross_iteration_dependencies():
        if not self.config.sw_pipelining.enabled:
            return

        iterations = self.num_exceptional_iterations
        assert iterations in [1, 2]

        kernel = self.get_unrolled_kernel(iterations=iterations)

        perm = self.periodic_reordering_inv
        assert Permutation.is_permutation(perm, self.codesize)

        dfgc_orig = DFGConfig(self.config, outputs=self.orig_outputs)
        dfgc_kernel = DFGConfig(self.config, outputs=self.kernel_input_output)

        tree_orig = DFG(self.orig_code, log.getChild("orig"), dfgc_orig)

        def is_in_preamble(t):
            if t.orig_pos is None:
                return False
            if iterations == 1:
                return self.is_pre(t.orig_pos, original_program_order=False)
            assert iterations == 2
            if t.orig_pos < self.codesize:
                return self.is_pre(t.orig_pos, original_program_order=False)
            return not self.is_post(
                t.orig_pos % self.codesize, original_program_order=False
            )

        def is_in_postamble(t):
            if t.orig_pos is None:
                return False
            if iterations == 1:
                return not self.is_pre(t.orig_pos, original_program_order=False)
            assert iterations == 2
            if t.orig_pos < self.codesize:
                return not self.is_pre(t.orig_pos, original_program_order=False)
            return self.is_post(
                t.orig_pos % self.codesize, original_program_order=False
            )

        tree_kernel = DFG(kernel, log.getChild("ssa"), dfgc_kernel)
        tree_kernel.ssa()

        # Go through early instructions that depend on an instruction from
        # the previous iteration. Remap those dependencies as input dependencies.
        for consumer, producer, _, _ in tree_kernel.iter_dependencies():
            producer = producer.reduce()
            if not (is_in_preamble(consumer) and not is_in_preamble(producer.src)):
                continue
            if producer.src.is_virtual:
                continue
            orig_pos = perm[producer.src.orig_pos % self.codesize]
            assert isinstance(producer, InstructionOutput)
            producer.src.inst.args_out[producer.idx] = tree_orig.nodes[
                orig_pos
            ].inst.args_out[producer.idx]

        # Update input and in-out register names
        for t in tree_kernel.nodes_all:
            for i, v in enumerate(t.src_in):
                t.inst.args_in[i] = v.name()
            for i, v in enumerate(t.src_in_out):
                t.inst.args_in_out[i] = v.name()

        new_preamble = [
            ComputationNode.to_source_line(t)
            for t in tree_kernel.nodes
            if is_in_preamble(t)
        ]
        self.preamble = new_preamble
        SourceLine.log("New preamble", self.preamble, log)

        dfgc_preamble = DFGConfig(self.config, outputs=self.kernel_input_output)
        dfgc_preamble.inputs_are_outputs = False
        DFG(self.preamble, log.getChild("new_preamble"), dfgc_preamble)

        tree_kernel = DFG(kernel, log.getChild("ssa"), dfgc_kernel)
        tree_kernel.ssa()

        # Go through non-early instructions that feed into an instruction from
        # the next iteration. Remap those dependencies as input dependencies.
        for consumer, producer, _, _ in tree_kernel.iter_dependencies():
            producer = producer.reduce()
            if not (is_in_postamble(producer.src) and not is_in_postamble(consumer)):
                continue
            orig_pos = perm[producer.src.orig_pos % self.codesize]
            assert isinstance(producer, InstructionOutput)
            producer.src.inst.args_out[producer.idx] = tree_orig.nodes[
                orig_pos
            ].inst.args_out[producer.idx]

        # Update input and in-out register names
        for t in tree_kernel.nodes_all:
            for i, v in enumerate(t.src_in):
                t.inst.args_in[i] = v.reduce().name()
            for i, v in enumerate(t.src_in_out):
                t.inst.args_in_out[i] = v.reduce().name()

        new_postamble = [
            ComputationNode.to_source_line(t)
            for t in tree_kernel.nodes
            if is_in_postamble(t)
        ]
        self.postamble = new_postamble
        SourceLine.log("New postamble", self.postamble, log)

        dfgc_postamble = DFGConfig(self.config, outputs=self.orig_outputs)
        DFG(self.postamble, log.getChild("new_postamble"), dfgc_postamble)

    def __init__(self, config):
        super().__init__()

        self._config = config.copy()

        self._orig_code = None
        self._code = None
        self._input_renamings = None
        self._output_renamings = None
        self._preamble = None
        self._postamble = None
        self._reordering_with_bubbles = None
        self._valid = False
        self._success = None
        self._cycles_bound = None
        self._stalls = None
        self._stalls_idxs = None
        self._input = None
        self._kernel_input_output = None
        self._pre_core_post_dict = None
        self._codesize_with_bubbles = None
        self._optimization_wall_time = None
        self._optimization_user_time = None
        self._spills = {}
        self._restores = {}

        self.lock()


class SlothyBase(LockAttributes):
    """Stateless core of SLOTHY.

    This class is the technical heart of the package: It implements the
    conversion of a software optimization problem into a constraint solving
    problem which can then be passed to an external constraint solver.
    We use Google OR-Tools.

    SlothyBase is agnostic of the target architecture and microarchitecture,
    which are specified at construction time.

    :param Arch:  A model of the underlying architecture.
    :type Arch: any
    :param Target: A model of the underlying microarchitecture.
    :type Target: any
    :param logger: The logger to be used.
                   If omitted, a child of the root logger will be used.
    :type logger: any
    :param config: The configuration to use.
                 If omitted, the default configuration will be used.
    :type config: any
    """

    # In contrast to its more convenient descendant Slothy, SlothyBase is largely
    # _stateless_:
    # It optimizes one piece of source code a time via SlothyBase.optimize()

    @property
    def arch(self):
        """The underlying architecture used by SLOTHY, as a read-only reference
        to the corresponding field in the configuration."""
        return self.config.arch

    @property
    def target(self):
        """The underlying microarchitecture used by SLOTHY, as a read-only reference
        to the corresponding field in the configuration."""
        return self.config.target

    @property
    def result(self):
        """The result object of the last optimization."""
        return self._result

    @property
    def success(self):
        """Indicates whether the last optimiation succeeded."""
        return self._result.success

    def __init__(
        self, Arch: any, Target: any, *, logger: any = None, config: any = None
    ):
        super().__init__()
        self.config = config if config is not None else Config(Arch, Target)
        self.logger = logger if logger is not None else logging.getLogger("slothy")
        self.logger.input = self.logger.getChild("input")
        self.logger.config = self.logger.getChild("config")
        self.logger.result = self.logger.getChild("result")

        self._num_optimization_passes = 0
        self._model = SimpleNamespace()
        self._result = None
        self._orig_code = None

        self.lock()  # Can't do this yet, there are still lots of temporaries being used

    def _reset(self):
        self._num_optimization_passes = 0
        self._model = SimpleNamespace()
        self._result = None
        self._orig_code = None

    def _set_timeout(self, timeout):
        if timeout is None:
            return
        self.logger.info("Setting timeout of %d seconds...", timeout)
        self._model.cp_solver.parameters.max_time_in_seconds = timeout

    def optimize(self, source, prefix_len=0, suffix_len=0, log_model=None, retry=False):
        self._reset()
        self._usage_check()

        self.config.log(self.logger.getChild("config").debug)

        # Setup
        self._load_source(source, prefix_len=prefix_len, suffix_len=suffix_len)
        self._init_external_model_and_solver()
        self._init_model_internals()

        self._set_timeout(self.config.timeout)

        if self.config.variable_size:
            pfactor = 2 if self.config.sw_pipelining.enabled else 1
            pfactor = self.target.issue_rate * pfactor
            min_cycles = math.ceil(self._model.tree.num_nodes / pfactor)
            min_slots = pfactor * min_cycles

            max_stalls = self.config.constraints.stalls_allowed
            min_stalls = 0
            self._model.stalls = self._NewIntVar(min_stalls, max_stalls, "stalls")
            self._model.min_slots = min_slots
            self._model.pfactor = pfactor

            pad_min = min_slots + min_stalls * pfactor
            pad_max = min_slots + max_stalls * pfactor
            self._model.program_padded_size = self._NewIntVar(pad_min, pad_max)
            self._model.program_padded_size_half = self._NewIntVar(
                pad_min // 2, pad_max // 2
            )

            self._model.program_horizon = pad_max + 10

            if not self.config.constraints.functional_only:
                cpad_min = pad_min // self.target.issue_rate
                cpad_max = pad_max // self.target.issue_rate
                self._model.cpad_max = cpad_max
                self._model.cycle_padded_size = self._NewIntVar(cpad_min, cpad_max)
                self._model.cycle_horizon = cpad_max + 10

        else:
            pfactor = 2 if self.config.sw_pipelining.enabled else 1
            pfactor = self.target.issue_rate * pfactor

            p_pad = pfactor * (
                math.ceil(self._model.tree.num_nodes / pfactor)
                + self.config.constraints.stalls_allowed
            )

            self._model.program_padded_size_const = p_pad
            self._model.program_padded_size = self._NewConstant(p_pad)
            self._model.program_padded_size_half = self._NewConstant(p_pad // 2)

            self._model.program_horizon = p_pad + 10

            if not self.config.constraints.functional_only:
                c_pad = p_pad // self.target.issue_rate
                self._model.cycle_padded_size = self._NewConstant(c_pad)
                self._model.cycle_horizon = c_pad + 10

        # Build constraint model
        self.logger.debug("Creating constraint model...")
        # - Variables
        self._add_variables_scheduling()
        self._add_variables_functional_units()
        self._add_variables_loop_rolling()
        self._add_variables_dependencies()
        self._add_variables_register_renaming()
        # - Constraints
        self._add_constraints_scheduling()
        self._add_constraints_lifetime_bounds()
        self._add_constraints_loop_optimization()
        self._add_constraints_n_issue()
        self._add_constraints_dependency_order()
        self._add_constraints_latencies()
        self._add_constraints_register_renaming()
        self._add_constraints_register_usage()
        self._add_constraints_functional_units()
        self._add_constraints_loop_periodic()
        self._add_constraints_locked_ordering()
        self._add_constraints_misc()

        # - Objective
        self._add_objective()
        self._result = Result(self.config)

        # Do the actual work
        self.logger.info(
            "Invoking external constraint solver (%s) ...", self._describe_solver()
        )
        self.result.success = self._solve()
        self.result.valid = True

        if not retry and self.success:
            self.logger.info(
                "Booleans in result: %d", self._model.cp_solver.NumBooleans()
            )

        if not self.success:
            return False

        self._extract_result()
        return True

    def _load_source(self, source, prefix_len=0, suffix_len=0):
        assert SourceLine.is_source(source)

        # TODO: This does not belong here
        if self.config.sw_pipelining.enabled and (prefix_len > 0 or suffix_len > 0):
            raise SlothyException("Invalid arguments")

        source = SourceLine.reduce_source(source)
        SourceLine.log("Source code", source, self.logger.input)

        self._orig_code = source.copy()

        # Convert source code to computational flow graph
        if self.config.sw_pipelining.enabled:
            source = source + source

        self._model.tree = DFG(
            source, self.logger.getChild("dataflow"), DFGConfig(self.config)
        )

        def lock_instruction(t):
            t.is_locked = True

        if prefix_len > 0:
            for t in self._get_nodes()[:prefix_len]:
                lock_instruction(t)
        if suffix_len > 0:
            for t in self._get_nodes()[-suffix_len:]:
                lock_instruction(t)

        self._mark_loop_siblings()
        self._set_avail_renaming_registers()
        self._restrict_input_output_renaming()
        self._backup_original_code()

    def _mark_loop_siblings(self):
        """When using SW pipelining, we internally use two loop iterations.
        Add references between corresponding instructions in both iterations."""
        if not self.config.sw_pipelining.enabled:
            return

        assert len(self._model.tree.nodes_low) == len(self._model.tree.nodes_high)
        for tlow, thigh in zip(self._model.tree.nodes_low, self._model.tree.nodes_high):
            tlow.sibling = thigh
            thigh.sibling = tlow

    def _init_model_internals(self):
        self._model.intervals_for_unit = {k: [] for k in self.target.ExecutionUnit}
        self._model.register_usages = {}
        self._model.register_usage_vars = {}
        self._model.spill_vars = []
        self._model.variables = []

    def _usage_check(self):
        if self._num_optimization_passes > 0:
            raise SlothyException(
                "SlothyBase should be used for one-shot optimizations"
            )
        self._num_optimization_passes += 1

    def _reg_is_architectural(self, reg, ty):
        return reg in self._model.architectural_registers[ty]

    def _restrict_input_output_renaming(self):
        # In principle, inputs and outputs can be arbitrarily renamed thanks to the
        # virtual instructions introduced for them. Disabling input/output renaming
        # fits into this framework nicely in the form of input/output argument
        # restrictions, which we have for 'real' instructions anyhow.

        # We might need to assign some fixed registers to global inputs/outputs which
        # haven't been given an architectural register name. We use the following array
        # to track which onces remain available
        avail_renaming_regs = deepcopy(self._model.avail_renaming_regs)

        def static_renaming(conf_val, t):
            """Checks whether a register should be statically renamed at model
            construction time. If so, and if a static assignment has already been
            made, it will return the assignment as the second return value.
            Otherwise, the second return value is None, and the static assignment
            will be picked afterwards (we can't do it immediately because we try
            to avoid collisions with fixed static assignments)."""
            reg, ty = t.inst.orig_reg, t.inst.orig_ty
            is_arch = self._reg_is_architectural(reg, ty)
            arch_str = "arch" if is_arch else "symbolic"

            # If the register type does not participate in renaming, always
            # keep original register assignment
            if self.arch.RegisterType.is_renamed(ty) is False:
                return True, reg

            if not isinstance(conf_val, dict):
                raise SlothyException(
                    f"Couldn't make sense of renaming configuration {conf_val}"
                )

            # Try to look up register in dictionary. There are three ways
            # it can be specified: Directly by name, via the "arch/symbolic"
            # group, or via the "any" group.

            val = None
            val = val if val is not None else conf_val.get(reg, None)
            val = val if val is not None else conf_val.get(arch_str, None)
            val = val if val is not None else conf_val.get("other", None)

            if val is None:
                raise SlothyException(
                    f"Register {reg} not present in renaming config {conf_val}"
                )

            # There are three choices for the value:
            # - "static" for static assignment, which will statically assign a value
            #   for symbolic register names, and keep the name of architectural registers.
            # - "any" for dynamic, unrestricted assignment
            # - an architectural register name
            if val == "static":
                canonical_static_assignment = reg if is_arch else None
                return True, canonical_static_assignment
            if val == "any":
                return False, None

            if not self._reg_is_architectural(val, ty):
                raise SlothyException(f"Invalid renaming configuration {val} for {reg}")
            return True, val

        def tag_input(t):
            static, val = static_renaming(self.config.rename_inputs, t)
            return SimpleNamespace(
                **{
                    "node": t,
                    "static": static,
                    "reg": val,
                    "name": t.inst.orig_reg,
                    "ty": t.inst.orig_ty,
                }
            )

        def tag_output(t):
            static, val = static_renaming(self.config.rename_outputs, t)
            return SimpleNamespace(
                **{
                    "node": t,
                    "static": static,
                    "reg": val,
                    "name": t.inst.orig_reg,
                    "ty": t.inst.orig_ty,
                }
            )

        inputs_tagged = list(map(tag_input, self._model.tree.nodes_input))
        outputs_tagged = list(map(tag_output, self._model.tree.nodes_output))

        for ty in self.arch.RegisterType:
            regs_assigned = set(
                v.reg
                for v in inputs_tagged + outputs_tagged
                if v.ty == ty and v.static is True and v.reg is not None
            )
            regs = regs_assigned.intersection(avail_renaming_regs[ty])
            for r in regs:
                avail_renaming_regs[ty].remove(r)

        class OutOfRegisters(Exception):
            pass

        def get_fresh_renaming_reg(ty):
            if len(avail_renaming_regs[ty]) == 0:
                raise OutOfRegisters
            return avail_renaming_regs[ty].pop(-1)

        try:
            # Iterate statically renamed inputs/outputs which have not yet been assigned
            for v in inputs_tagged + outputs_tagged:
                if v.static is False or v.reg is not None:
                    continue
                v.reg = get_fresh_renaming_reg(v.ty)
        except OutOfRegisters as e:
            self.logger.error(
                """Ran out of registers trying to _statically_ assign architectural
                registers for input and outputs of the snippet. You should consider
                enabling register renaming for input and output, by setting
                config.rename_{inputs,outputs}.
                Alternatively, you may fix input and output registers by hand yourself."""
            )
            raise e

        # Now actually enforce renamings
        for t in inputs_tagged:
            if not t.static:
                continue
            self.logger.input.debug(
                f"Statically assign global input {t.name} to register {t.reg}"
            )
            t.node.inst.args_out_restrictions = [[t.reg]]
        for t in outputs_tagged:
            if not t.static:
                continue
            self.logger.input.debug(
                f"Statically assign global output {t.name} to register {t.reg}"
            )
            t.node.inst.args_in_restrictions = [[t.reg]]

    def _set_avail_renaming_registers(self):
        self._model.avail_renaming_regs = {}
        self._model.architectural_registers = {}
        for ty in self.arch.RegisterType:
            regs = self.arch.RegisterType.list_registers(ty, only_normal=True)
            regs += self.arch.RegisterType.list_registers(ty, only_extra=True)[
                : self.config.constraints.allow_extra_registers.get(ty, 0)
            ]
            self._model.architectural_registers[ty] = regs
            self._model.avail_renaming_regs[ty] = [
                r for r in regs if r not in self.config.reserved_regs
            ]

        self._dump_avail_renaming_registers()

    def _dump_avail_renaming_registers(self):
        self.logger.input.debug("Registers available for renaming")
        for ty in self.arch.RegisterType:
            self.logger.input.debug(
                f"- {ty} available: {self._model.avail_renaming_regs[ty]}"
            )

    def _add_register_usage(
        self, t, reg, reg_ty, var, start_var, dur_var, end_var, spill_var
    ):

        spill_ival_active = self._NewBoolVar("")
        self._AddMultiplicationEquality([var, spill_var], spill_ival_active)
        spill_point_start = self._NewOptionalIntervalVar(
            t.program_start_var, 1, t.program_start_var + 1, spill_ival_active, ""
        )

        interval = self._NewOptionalIntervalVar(
            start_var, dur_var, end_var, var, f"Usage({t.inst})({reg})<{var}>"
        )

        if self.arch.RegisterType.is_renamed(reg_ty):
            # At this stage, we should only operate with _architectural_ register names
            assert reg in self.arch.RegisterType.list_registers(reg_ty)

        self._model.register_usages.setdefault(reg, [])
        self._model.register_usages[reg].append(interval)
        self._model.register_usages[reg].append(spill_point_start)

        if var is None:
            return

        self._model.register_usage_vars.setdefault(reg, [])
        self._model.register_usage_vars[reg].append(var)

    def _backup_original_code(self):
        for t in self._get_nodes():
            t.inst_orig = deepcopy(t.inst)

    class CpSatSolutionCb(cp_model.CpSolverSolutionCallback):
        """A solution callback class represents objects that are alive during CP-SAT
        operation and equipped with a callback that is triggered every time CP-SAT finds
        a new solution.

        This callback counts the solutions found so far, and aborts the search when the
        solution is sufficiently close to the optimum."""

        def __init__(
            self,
            logger,
            objective_description,
            max_solutions=32,
            is_good_enough=None,
            printer=None,
            variables=None,
        ):
            cp_model.CpSolverSolutionCallback.__init__(self)
            self.__solution_count = 0
            self.__logger = logger
            self.__max_solutions = max_solutions
            self.__is_good_enough = is_good_enough
            self.__printer = printer
            self.__objective_desc = objective_description
            self.variables = variables

        def on_solution_callback(self):
            """Triggered when OR-Tools finds a solution to the current constraint
            problem"""
            self.__solution_count += 1
            if self.__objective_desc:
                cur = self.ObjectiveValue()
                bound = self.BestObjectiveBound()
                time = self.WallTime()
                if self.__printer is not None:
                    if self.variables is not None:
                        variables = {
                            k: self.Value(v) for k, v in self.variables.items()
                        }
                        cur_str = self.__printer(cur, variables)
                        bound_str = self.__printer(bound, {})
                    else:
                        cur_str = self.__printer(cur)
                        bound_str = self.__printer(bound)
                else:
                    cur_str = str(cur)
                    bound_str = str(bound)
                self.__logger.info(
                    f"[{time:.4f}s]: Found {self.__solution_count} solutions so far... "
                    f"objective ({self.__objective_desc}): currently {cur_str}, "
                    f"bound {bound_str}"
                )
                if self.__is_good_enough and self.__is_good_enough(cur, bound):
                    self.StopSearch()
            if self.__solution_count >= self.__max_solutions:
                self.StopSearch()

        def solution_count(self):
            """The number of solutions found so far"""
            return self.__solution_count

    def fixup_preamble_postamble(self):
        """Potentially fix up the preamble and postamble

        When software pipelining is used in the context of a loop with cross-iteration
        dependencies, the core optimization step might lead to functionally incorrect
        preamble and postamble.
        This function checks if this is the case and fixes preamble and postamble, if
        necessary.
        """

        # if not self._has_cross_iteration_dependencies():
        if not self.config.sw_pipelining.enabled:
            return

        log = self.logger.getChild("fixup_preamble_postamble")

        iterations = self._result.num_exceptional_iterations
        assert iterations in [1, 2]

        kernel = self._result.get_unrolled_kernel(iterations=iterations)

        perm = self._result.periodic_reordering_inv
        assert Permutation.is_permutation(perm, self._result.codesize)

        dfgc_orig = DFGConfig(self.config, outputs=self._result.orig_outputs)
        dfgc_kernel = DFGConfig(self.config, outputs=self._result.kernel_input_output)

        tree_orig = DFG(self._result.orig_code, log.getChild("orig"), dfgc_orig)

        def is_in_preamble(t):
            if t.orig_pos is None:
                return False
            if iterations == 1:
                return self._result.is_pre(t.orig_pos, original_program_order=False)

            assert iterations == 2
            if t.orig_pos < self._result.codesize:
                return self._result.is_pre(t.orig_pos, original_program_order=False)

            return not self._result.is_post(
                t.orig_pos % self._result.codesize, original_program_order=False
            )

        def is_in_postamble(t):
            if t.orig_pos is None:
                return False
            if iterations == 1:
                return not self._result.is_pre(t.orig_pos, original_program_order=False)

            assert iterations == 2
            if t.orig_pos < self._result.codesize:
                return not self._result.is_pre(t.orig_pos, original_program_order=False)

            return self._result.is_post(
                t.orig_pos % self._result.codesize, original_program_order=False
            )

        tree_kernel = DFG(kernel, log.getChild("ssa"), dfgc_kernel)
        tree_kernel.ssa()

        # Go through early instructions that depend on an instruction from
        # the previous iteration. Remap those dependencies as input dependencies.
        for consumer, producer, _, _ in tree_kernel.iter_dependencies():
            producer = producer.reduce()
            if not (is_in_preamble(consumer) and not is_in_preamble(producer.src)):
                continue
            if producer.src.is_virtual:
                continue
            orig_pos = perm[producer.src.orig_pos % self._result.codesize]
            assert isinstance(producer, InstructionOutput)
            producer.src.inst.args_out[producer.idx] = tree_orig.nodes[
                orig_pos
            ].inst.args_out[producer.idx]

        # Update input and in-out register names
        for t in tree_kernel.nodes_all:
            for i, v in enumerate(t.src_in):
                t.inst.args_in[i] = v.name()
            for i, v in enumerate(t.src_in_out):
                t.inst.args_in_out[i] = v.name()

        new_preamble = [
            ComputationNode.to_source_line(t)
            for t in tree_kernel.nodes
            if is_in_preamble(t)
        ]
        self._result.preamble = new_preamble
        SourceLine.log("New preamble", self._result.preamble, log)

        dfgc_preamble = DFGConfig(self.config, outputs=self._result.kernel_input_output)
        dfgc_preamble.inputs_are_outputs = False
        DFG(self._result.preamble, log.getChild("new_preamble"), dfgc_preamble)

        tree_kernel = DFG(kernel, log.getChild("ssa"), dfgc_kernel)
        tree_kernel.ssa()

        # Go through non-early instructions that feed into an instruction from
        # the next iteration. Remap those dependencies as input dependencies.
        for consumer, producer, _, _ in tree_kernel.iter_dependencies():
            producer = producer.reduce()
            if not (is_in_postamble(producer.src) and not is_in_postamble(consumer)):
                continue
            orig_pos = perm[producer.src.orig_pos % self._result.codesize]
            assert isinstance(producer, InstructionOutput)
            producer.src.inst.args_out[producer.idx] = tree_orig.nodes[
                orig_pos
            ].inst.args_out[producer.idx]

        # Update input and in-out register names
        for t in tree_kernel.nodes_all:
            for i, v in enumerate(t.src_in):
                t.inst.args_in[i] = v.reduce().name()
            for i, v in enumerate(t.src_in_out):
                t.inst.args_in_out[i] = v.reduce().name()

        new_postamble = [
            ComputationNode.to_source_line(t)
            for t in tree_kernel.nodes
            if is_in_postamble(t)
        ]
        self._result.postamble = new_postamble
        SourceLine.log("New postamble", self._result.postamble, log)

        dfgc_postamble = DFGConfig(self.config, outputs=self._result.orig_outputs)
        DFG(self._result.postamble, log.getChild("new_postamble"), dfgc_postamble)

    def _extract_result(self):

        self._result.orig_code = self._orig_code

        get_value = self._model.cp_solver.Value

        self._extract_positions(get_value)
        self._extract_register_renamings(get_value)
        self._extract_input_output_renaming()

        self._extract_spills()
        self._extract_code()
        self._result.selfcheck_with_fixup(self.logger.getChild("selfcheck"))
        self._result.offset_fixup(self.logger.getChild("fixup"))

        self._result.selftest(self.logger.getChild("selftest"))

    def _extract_positions(self, get_value):

        if self.config.variable_size:
            self._result.stalls = get_value(self._model.stalls)
            stalls_bound = self._model.cp_solver.BestObjectiveBound()
            stats = self._stalls_to_stats(stalls_bound)
            if stats is not None:
                cycles_bound, _ = stats
                self._result.cycles_bound = cycles_bound

        self._result.optimization_wall_time = self._model.cp_solver.WallTime()
        self._result.optimization_user_time = self._model.cp_solver.UserTime()

        nodes = self._model.tree.nodes
        if self.config.sw_pipelining.enabled:
            nodes_low = self._model.tree.nodes_low

        # Extract length and instructions positions program order
        if self.config.sw_pipelining.enabled:
            self._result.codesize_with_bubbles = get_value(
                self._model.program_padded_size_half
            )
        else:
            self._result.codesize_with_bubbles = get_value(
                self._model.program_padded_size
            )

        for t in nodes:
            t.real_pos_program = get_value(t.program_start_var)
            if self.config.sw_pipelining.enabled:
                t.pre = get_value(t.pre_var)
                t.post = get_value(t.post_var)
                t.core = get_value(t.core_var)
                if t.pre and t.orig_pos < len(nodes_low):
                    t.real_pos_program -= 2 * self._result.codesize_with_bubbles
                if t.post and t.orig_pos >= len(nodes_low):
                    t.real_pos_program += 2 * self._result.codesize_with_bubbles
            if not self.config.constraints.functional_only:
                t.real_pos_cycle = t.real_pos_program // self.target.issue_rate

        if self.config.sw_pipelining.enabled:
            self._result.reordering_with_bubbles = {
                t.orig_pos: t.real_pos_program for t in nodes_low
            }
            self._result.pre_core_post_dict = {
                t.orig_pos: (t.pre, t.core, t.post) for t in nodes_low
            }
        else:
            self._result.reordering_with_bubbles = {
                t.orig_pos: t.real_pos_program for t in nodes
            }

        copies = 2 if self.config.sw_pipelining.enabled else 1
        reordering = self.result.get_reordering(copies, no_gaps=False)
        self.logger.debug("Reordering (without bubbles, %d copies)", copies)
        self.logger.debug(reordering)

        for t in nodes:
            t.real_pos = reordering[t.orig_pos]

        if self.config.sw_pipelining.enabled:
            if self._result.num_pre > 0:
                self.logger.info(
                    "Number of early instructions: %d", self._result.num_pre
                )
            if self._result.num_post > 0:
                self.logger.info(
                    "Number of late instructions: %d", self._result.num_post
                )
            self.logger.debug(
                "Number of exceptional iterations: %d",
                self._result.num_exceptional_iterations,
            )

    def _extract_input_output_renaming(self):
        self._result.input_renamings = {
            n.inst.orig_reg: n.inst.args_out[0] for n in self._model.tree.nodes_input
        }
        self._result.output_renamings = {
            n.inst.orig_reg: n.inst.args_in[0] for n in self._model.tree.nodes_output
        }

        def _dump_renaming(name, dic):
            for k, v in ((k, v) for k, v in dic.items() if k != v):
                self.logger.debug("%s %s renamed to %s", name, k, v)

        _dump_renaming("Input", self._result.input_renamings)
        _dump_renaming("Output", self._result.output_renamings)

    def _extract_register_renamings(self, get_value):
        # From a dictionary with Boolean variables as values, extract the single
        # key for whose variable is set to True by the solver.
        def _extract_true_key(var_dict):
            true_keys = [k for k, v in var_dict.items() if get_value(v)]
            assert len(true_keys) == 1
            return true_keys[0]

        # Extract register renamings and modify instructions accordingly
        for t in self._get_nodes(allnodes=True):
            t.inst.args_out = [_extract_true_key(vars) for vars in t.alloc_out_var]
            t.inst.args_in = [_extract_true_key(vars) for vars in t.alloc_in_var]
            t.inst.args_in_out = [
                _extract_true_key(vars) for vars in t.alloc_in_out_var
            ]
            t.out_spills = [(get_value(v) == 1) for v in t.out_spill_vars]
            t.in_out_spills = [(get_value(v) == 1) for v in t.in_out_spill_vars]
            t.out_lifetime_start = list(map(get_value, t.out_lifetime_start))
            t.inout_lifetime_start = list(map(get_value, t.inout_lifetime_start))

            def _dump_renaming(name, lst, inst):
                for idx, reg in enumerate(lst):
                    self.logger.debug(
                        "%s %s of '%s' renamed to %s", name, idx, inst, reg
                    )

            _dump_renaming("Output", t.inst.args_out, t.inst)
            _dump_renaming("Input", t.inst.args_in, t.inst)
            _dump_renaming("Input/Output", t.inst.args_in_out, t.inst)
            self.logger.debug("New instruction: %s", t.inst)

    def _extract_kernel_input_output(self):
        dfg_log = self.logger.getChild("kernel_input_output")

        conf = self.config.copy()
        conf.outputs = list(
            map(lambda o: self._result.output_renamings.get(o, o), conf.outputs)
        )

        self._result.kernel_input_output = list(
            DFG(
                self._result.code_raw, dfg_log, DFGConfig(conf, inputs_are_outputs=True)
            ).inputs
        )

    def _extract_spills(self):
        if self.config.constraints.allow_spills is None:
            return
        # Extract spills and restores with textual spill identifiers
        spills = self._result._spills
        restores = self._result._restores
        for t in self._model.tree.nodes:
            p = t.real_pos_program

            def remember_spill(i, spilled, restore, arg, txt):
                if spilled is True:
                    spills.setdefault(p, [])
                    restores.setdefault(restore, [])
                    spill_id = f"{txt}_{p}_{i}"
                    spills[p].append((arg, spill_id))
                    restores[restore].append((arg, spill_id))

            assert len(t.out_spills) == len(t.out_lifetime_start)
            assert len(t.out_spills) == len(t.inst.args_out)
            for i, (spilled, restore, arg) in enumerate(
                zip(t.out_spills, t.out_lifetime_start, t.inst.args_out)
            ):
                remember_spill(i, spilled, restore, arg, "out")

            assert len(t.in_out_spills) == len(t.inout_lifetime_start)
            assert len(t.in_out_spills) == len(t.inst.args_in_out)
            for i, (spilled, restore, arg) in enumerate(
                zip(
                    t.in_out_spills,
                    t.inout_lifetime_start,
                    t.inst.args_in_out,
                )
            ):
                remember_spill(i, spilled, restore, arg, "inout")
        # Map textual spill identifiers to numerical locations
        free_locs = set(range(64))
        spill_id_to_loc = {}
        m = max(list(spills.keys()) + list(restores.keys()), default=0) + 1
        for i in range(m):
            s = spills.get(i, [])
            r = restores.get(i, [])
            for j in range(len(r)):
                (reg, spill_id) = r[j]
                loc = spill_id_to_loc[spill_id]
                free_locs.add(loc)
                r[j] = (reg, loc)
            for j in range(len(s)):
                (reg, spill_id) = s[j]
                loc = min(free_locs)
                free_locs.remove(loc)
                spill_id_to_loc[spill_id] = loc
                s[j] = (reg, loc)

    def _extract_code(self):

        def get_code(filter_func=None, top=False):
            if len(self._model.tree.nodes) == 0:
                return
            copies = 1 if not self.config.sw_pipelining.enabled else 2
            periodic_reordering_with_bubbles_inv = (
                self._result.get_periodic_reordering_with_bubbles_inv(copies)
            )

            def get_code_line(line_no):
                if line_no not in periodic_reordering_with_bubbles_inv.keys():
                    return
                t = self._model.tree.nodes[
                    periodic_reordering_with_bubbles_inv[line_no]
                ]
                if filter_func and not filter_func(t):
                    return
                yield ComputationNode.to_source_line(t)

            base = 0
            lines = self._result.codesize_with_bubbles
            if top:
                base = self._result.codesize_with_bubbles
            for i in range(base, base + lines):
                yield from get_code_line(i)

        if self.config.sw_pipelining.enabled:

            preamble = []
            if self._result.num_pre > 0:
                preamble += list(get_code(filter_func=lambda t: t.pre, top=True))
            if self._result.num_post > 0:
                preamble += list(get_code(filter_func=lambda t: not t.post))

            postamble = []
            if self._result.num_pre > 0:
                postamble += list(get_code(filter_func=lambda t: not t.pre, top=True))
            if self._result.num_post > 0:
                postamble += list(get_code(filter_func=lambda t: t.post))

            kernel = list(get_code())

            log = self.logger.result.getChild("sw_pipelining")
            log.debug("Kernel dependencies: %s", self._result.kernel_input_output)

            SourceLine.log("Preamble", preamble, log)
            SourceLine.log("Kernel", kernel, log)
            SourceLine.log("Postamble", postamble, log)

            preamble = SourceLine.apply_indentation(preamble, self.config.indentation)
            postamble = SourceLine.apply_indentation(postamble, self.config.indentation)
            kernel = SourceLine.apply_indentation(kernel, self.config.indentation)

            if self.config.keep_tags is False:
                SourceLine.drop_tags(preamble)
                SourceLine.drop_tags(postamble)
                SourceLine.drop_tags(kernel)

            self._result.preamble = preamble
            self._result.postamble = postamble
            self._result.code = kernel

            self._extract_kernel_input_output()

        else:
            code = list(get_code())
            code = SourceLine.apply_indentation(code, self.config.indentation)

            if self.config.keep_tags is False:
                SourceLine.drop_tags(code)

            self._result.code = code

            self.logger.result.debug("Optimized code")
            for s in self._result.code:
                self.logger.result.debug("> " + s.to_string())

    def _add_path_constraint(self, consumer, producer, cb):
        """Add model constraint cb() relating to the pair of producer-consumer
        instructions
        Outside of loop mode, this ignores producer and consumer, and just adds cb().
        In loop mode, however, the condition has to be omitted in two cases:

        - The producer belongs to the early part of the first iteration,
          but the consumer doesn't.

          In this case, the early part of the first iteration is actually the
          early part of the third iteration.

        - The consumer belongs to the late part of the second iteration,
          but the producer doesn't.
        """
        if not self.config.sw_pipelining.enabled:
            cb()
            return

        if self._is_low(consumer) and self._is_high(producer):
            ct = cb()
            ct.OnlyEnforceIf([consumer.pre_var, producer.pre_var])
            ct = cb()
            ct.OnlyEnforceIf([consumer.post_var, producer.post_var])
            return

        if self._is_input(producer) and self._is_low(consumer):
            return
        if self._is_output(consumer) and self._is_high(producer):
            return

        # In all other cases, we add the constraint, but condition it suitably
        ct = cb()
        constraints = []

        if self._is_low(consumer):
            constraints.append(consumer.pre_var.Not())
        if self._is_low(producer):
            constraints.append(producer.pre_var.Not())

        if self._is_high(producer):
            constraints.append(producer.post_var.Not())
        if self._is_high(consumer):
            constraints.append(consumer.post_var.Not())
        ct.OnlyEnforceIf(constraints)

    def _add_path_constraint_from(self, consumer, producer, cb_lst):
        # Similar to `add_path_constraint()`, but here we accept a list of
        # constraints of whch exactly one should be enforced (the others
        # _may_ hold as well, but we don't care).
        bvars = [self._NewBoolVar("") for _ in cb_lst]
        self._AddExactlyOne(bvars)

        if (
            self.config.sw_pipelining.enabled is True
            and self._is_low(consumer)
            and self._is_high(producer)
        ):
            raise Exception("Not yet implemented")

        if (
            not self.config.sw_pipelining.enabled
            or producer.is_virtual
            or consumer.is_virtual
        ):
            assert len(cb_lst) == len(bvars)
            for cb, bvar in zip(cb_lst, bvars):
                cb().OnlyEnforceIf(bvar)
            return

        assert len(cb_lst) == len(vars)
        for cb, bvar in zip(cb_lst, bvars):
            constraints = [bvar]
            if self._is_low(producer):
                constraints.append(producer.pre_var.Not())
            if self._is_high(consumer):
                constraints.append(consumer.post_var.Not())
            cb().OnlyEnforceIf([producer.pre_var, consumer.pre_var, bvar])

    def _get_nodes_by_program_order(
        self, low=False, high=False, allnodes=False, inputs=False, outputs=False
    ):
        if low:
            return self._model.tree.nodes_low
        if high:
            return self._model.tree.nodes_high
        if allnodes:
            return self._model.tree.nodes_all
        if inputs:
            return self._model.tree.nodes_input
        if outputs:
            return self._model.tree.nodes_output
        return self._model.tree.nodes

    def _get_nodes_by_depth(self, **kwargs):
        return sorted(self._get_nodes_by_program_order(**kwargs), key=lambda t: t.depth)

    def _get_nodes(self, by_depth=False, **kwargs):
        if by_depth:
            return self._get_nodes_by_depth(**kwargs)
        return self._get_nodes_by_program_order(**kwargs)

    # ================================================================
    #                  VARIABLES (Instruction scheduling)            #
    # ================================================================

    def _add_variables_scheduling(self):
        """Create variables for start, end and duration of every instruction,
        and assign the duration intervals to the units that run the instructions"""

        for t in self._get_nodes(inputs=True):
            t.program_start_var = self._NewConstant(-1)
            # xxx_end_var is only used to model the occupancy of functional units;
            # since virtual instructions don't occupy those, we don't need the an end var
        for t in self._get_nodes(outputs=True):
            t.program_start_var = self._model.program_padded_size
            # as above: no xxx_end_var needed

        # Add variables for positions in program order
        for t in self._get_nodes():
            t.program_start_var = self._NewIntVar(
                0, self._model.program_horizon, f"{t.varname()}_program_start"
            )

            if self.config.hints.order_hint_orig_order:
                self._AddHint(t.program_start_var, int(t.id))

            if (
                self.config.sw_pipelining.enabled is False
                and self.config.constraints.max_displacement < 1.0
            ):
                # We also measure the displacement of an instruction relative to its
                # original position (scaled to the padded program length).
                # By default, no constraints are associated with this, but the amount
                # of displacement is an interesting measure for how much reordering was
                # still necessary, and may perhaps drive heuristics.
                rel_pos = t.orig_pos / len(self._model.tree.nodes)
                t.orig_pos_scaled = int(rel_pos * self._model.program_padded_size_const)
                t.program_displacement = self._NewIntVar(
                    0,
                    self._model.program_horizon,
                    f"{t.varname()}_program_displacement",
                )

        if self.config.constraints.functional_only:
            return

        # Add variables for positions in cycles, and "issue slots"
        # E.g. if we're modeling dual-issuing, we have program_pos = cycle_pos * 2 + slot,
        # and slot is in either 0 or 1.
        for t in self._get_nodes():
            t.cycle_start_var = self._NewIntVar(
                0, self._model.cycle_horizon, f"{t.varname()}_cycle_start"
            )
            t.cycle_end_var = self._NewIntVar(
                0, self._model.cycle_horizon, f"{t.varname()}_cycle_end"
            )
            t.slot_var = self._NewIntVar(0, self.target.issue_rate - 1)

    # ================================================================
    #                  VARIABLES (Functional units)                  #
    # ================================================================

    def _add_variables_functional_units(self):
        if not self.config.constraints.model_functional_units:
            return

        for t in self._get_nodes():
            cycles_unit_occupied = self.target.get_inverse_throughput(t.inst)
            units = self.target.get_units(t.inst)
            if len(units) == 1:
                if isinstance(units[0], list):
                    # multiple execution units in use
                    for unit in units[0]:
                        t.exec_unit_choices = None
                        t.exec = self._NewIntervalVar(
                            t.cycle_start_var, cycles_unit_occupied, t.cycle_end_var, ""
                        )
                        self._model.intervals_for_unit[unit].append(t.exec)
                else:
                    t.exec_unit_choices = None
                    unit = units[0]
                    t.exec = self._NewIntervalVar(
                        t.cycle_start_var, cycles_unit_occupied, t.cycle_end_var, ""
                    )
                    self._model.intervals_for_unit[unit].append(t.exec)
            else:
                t.unique_unit = False
                t.exec_unit_choices = {}
                for unit_choices in units:
                    if not isinstance(unit_choices, list):
                        unit_choices = [unit_choices]
                    for unit in unit_choices:
                        unit_var = self._NewBoolVar(f"[{t.inst}].unit_choice.{unit}")
                        t.exec_unit_choices[unit] = unit_var
                        t.exec = self._NewOptionalIntervalVar(
                            t.cycle_start_var,
                            cycles_unit_occupied,
                            t.cycle_end_var,
                            unit_var,
                            f"{t.varname}_usage_{unit}",
                        )
                        self._model.intervals_for_unit[unit].append(t.exec)

    # ================================================================
    #                  VARIABLES (Dependency tracking)               #
    # ================================================================

    def _add_variables_dependencies(self):

        def make_var(name=""):
            return self._NewIntVar(0, self._model.program_horizon, name)

        def make_start_var(name=""):
            return self._NewIntVar(-1, self._model.program_horizon, name)

        for t in self._get_nodes(allnodes=True):
            # When we optimize for longest register lifetimes, we allow the starting time
            # of the usage interval to be smaller than the program order position of the
            # instruction.
            t.out_lifetime_start = [
                make_start_var(f"{t.varname()}_out_{i}_lifetime_start")
                for i in range(t.inst.num_out)
            ]
            t.inout_lifetime_start = [
                make_start_var(f"{t.varname()}_inout_{i}_lifetime_start")
                for i in range(t.inst.num_in_out)
            ]

            t.out_lifetime_end = [
                make_var(f"{t.varname()}_out_{i}_lifetime_end")
                for i in range(t.inst.num_out)
            ]
            t.out_lifetime_duration = [
                make_var(f"{t.varname()}_out_{i}_lifetime_dur")
                for i in range(t.inst.num_out)
            ]
            t.inout_lifetime_end = [
                make_var(f"{t.varname()}_inout_{i}_lifetime_end")
                for i in range(t.inst.num_in_out)
            ]
            t.inout_lifetime_duration = [
                make_var(f"{t.varname()}_inout_{i}_lifetime_dur")
                for i in range(t.inst.num_in_out)
            ]

    # ================================================================
    #                  VARIABLES (Register allocation)               #
    # ================================================================

    def _add_variables_register_renaming(self):
        """Add boolean variables indicating if an instruction uses a certain output
        register"""

        def _allow_renaming(_):
            if not self.config.constraints.allow_renaming:
                return False
            return True

        self.logger.debug("Adding variables for register allocation...")

        if self.config.constraints.minimize_register_usage is not None:
            ty = self.config.constraints.minimize_register_usage
            regs = self.arch.RegisterType.list_registers(ty)
            self._model._register_used = {
                reg: self._NewBoolVar(f"reg_used[{reg}]") for reg in regs
            }

        # Create variables for register renaming

        for t in self._get_nodes(allnodes=True):
            t.alloc_out_var = []
            self.logger.debug("Create register renaming variables for %s", t)

            # Iterate through output registers of current instruction
            assert len(t.inst.arg_types_out) == len(t.inst.args_out)
            assert len(t.inst.arg_types_out) == len(t.inst.args_out_restrictions)
            for arg_ty, arg_out, restrictions in zip(
                t.inst.arg_types_out,
                t.inst.args_out,
                t.inst.args_out_restrictions,
            ):

                self.logger.debug("- Output %s (%s)", arg_out, arg_ty)

                # Locked output register aren't renamed, and neither are
                # outputs of locked instructions.
                self.logger.debug("Locked registers: %s", self.config.locked_registers)
                is_locked = arg_out in self.config.locked_registers

                locked = False
                reason = None
                if self.arch.RegisterType.is_renamed(arg_ty) is False:
                    locked, reason = True, "Register type is not renamed"
                elif self._reg_is_architectural(arg_out, arg_ty):
                    if t.is_locked:
                        locked, reason = True, "Instruction is locked"
                    elif is_locked:
                        locked, reason = True, "Register is locked"
                    elif not _allow_renaming(t):
                        locked, reason = (
                            True,
                            "Register renaming disabled for this instruction",
                        )

                if locked is True:
                    self.logger.input.debug(
                        f"Instruction {t.inst.write()} has its output locked"
                    )
                    self.logger.input.debug(f"Reason: {reason}")
                    candidates = [arg_out]
                else:
                    candidates = list(set(self._model.avail_renaming_regs[arg_ty]))

                if restrictions is not None:
                    self.logger.debug(
                        "%s (%s): Output restriction %s", t.id, t.inst, restrictions
                    )
                    candidates_restricted = [c for c in candidates if c in restrictions]
                else:
                    candidates_restricted = candidates
                if len(candidates_restricted) == 0:
                    self.logger.error(
                        "No suitable output registers exist for %s?", t.inst
                    )
                    self.logger.error("Original candidates: %s", candidates)
                    self.logger.error(
                        "Restricted candidates: %s", candidates_restricted
                    )
                    self.logger.error("Restrictions: %s", restrictions)
                    raise SlothyException()

                self.logger.input.debug(
                    "Registers available for renaming of "
                    f"[{t.inst}].{arg_out} ({t.orig_pos})"
                )
                self.logger.input.debug(candidates_restricted)

                var_dict = {
                    out_reg: self._NewBoolVar(f"ALLOC({t.inst})({out_reg})")
                    for out_reg in candidates_restricted
                }
                t.alloc_out_var.append(var_dict)

                if self.config.hints.rename_hint_orig_rename:
                    if arg_out in candidates_restricted:
                        self._AddHint(var_dict[arg_out], True)

        # For convenience, also add references to the variables governing the
        # register renaming for input and input/output arguments.
        for t in self._get_nodes(allnodes=True):

            t.alloc_in_var = []
            for arg_in in t.src_in:
                arg_in = arg_in.reduce()
                t.alloc_in_var.append(arg_in.src.alloc_out_var[arg_in.idx])

            t.alloc_in_out_var = []
            for arg_in_out in t.src_in_out:
                arg_in_out = arg_in_out.reduce()
                t.alloc_in_out_var.append(arg_in_out.src.alloc_out_var[arg_in_out.idx])

        # We may have constraints on allowed configurations of input/output arguments,
        # such as VST4{0-3} requiring consecutive input registers.
        # Here we add variables for those constraints

        for t in self._get_nodes(allnodes=True):
            t.alloc_in_combinations_vars = []
            t.alloc_out_combinations_vars = []
            t.alloc_in_out_combinations_vars = []

            def add_arg_combination_vars(combinations, vs, name, t=t):
                if combinations is None:
                    return
                for idx_lst, valid_combinations in combinations:
                    self.logger.debug(
                        "%s (%s): Adding variables for %s (%s, %s)",
                        t.orig_pos,
                        t.inst.mnemonic,
                        name,
                        idx_lst,
                        valid_combinations,
                    )
                    vs.append([])
                    for combination in valid_combinations:
                        self.logger.debug(
                            "%s (%s): Adding variable for combination %s",
                            t.orig_pos,
                            t.inst.mnemonic,
                            combination,
                        )
                        vs[-1].append(self._NewBoolVar(""))

            add_arg_combination_vars(
                t.inst.args_in_combinations, t.alloc_in_combinations_vars, "input"
            )
            add_arg_combination_vars(
                t.inst.args_in_out_combinations,
                t.alloc_in_out_combinations_vars,
                "inout",
            )
            add_arg_combination_vars(
                t.inst.args_out_combinations, t.alloc_out_combinations_vars, "output"
            )

        # Create intervals tracking the usage of registers

        for t in self._get_nodes(allnodes=True):
            self.logger.debug("Create register usage intervals for %s", t)
            t.out_spill_vars = [self._NewBoolVar("") for _ in t.inst.arg_types_out]
            t.in_out_spill_vars = [
                self._NewBoolVar("") for _ in t.inst.arg_types_in_out
            ]
            ivals = []

            assert len(t.inst.arg_types_out) == len(t.alloc_out_var)
            assert len(t.inst.arg_types_out) == len(t.out_lifetime_start)
            assert len(t.inst.arg_types_out) == len(t.out_lifetime_duration)
            assert len(t.inst.arg_types_out) == len(t.out_lifetime_end)
            assert len(t.inst.arg_types_out) == len(t.out_spill_vars)
            ivals += list(
                zip(
                    t.inst.arg_types_out,
                    t.alloc_out_var,
                    t.out_lifetime_start,
                    t.out_lifetime_duration,
                    t.out_lifetime_end,
                    t.out_spill_vars,
                )
            )
            assert len(t.inst.arg_types_in_out) == len(t.alloc_in_out_var)
            assert len(t.inst.arg_types_in_out) == len(t.inout_lifetime_start)
            assert len(t.inst.arg_types_in_out) == len(t.inout_lifetime_duration)
            assert len(t.inst.arg_types_in_out) == len(t.inout_lifetime_end)
            assert len(t.inst.arg_types_in_out) == len(t.in_out_spill_vars)
            ivals += list(
                zip(
                    t.inst.arg_types_in_out,
                    t.alloc_in_out_var,
                    t.inout_lifetime_start,
                    t.inout_lifetime_duration,
                    t.inout_lifetime_end,
                    t.in_out_spill_vars,
                )
            )

            for arg_ty, var_dict, start_var, dur_var, end_var, spill_var in ivals:
                self._model.spill_vars.append(spill_var)
                self._Add(start_var == t.program_start_var).OnlyEnforceIf(
                    spill_var.Not()
                )
                for reg, var in var_dict.items():
                    self._add_register_usage(
                        t, reg, arg_ty, var, start_var, dur_var, end_var, spill_var
                    )

    # ================================================================
    #                  VARIABLES (Loop rolling)                      #
    # ================================================================

    def _add_variables_loop_rolling(self):
        if not self.config.sw_pipelining.enabled:
            return

        for t in self._get_nodes():
            # In loop mode, every instruction is marked as pre, core, or post,
            # depending on whether it's executed already in the previous iteration
            # (e.g. an early load), in the original iteration, or the following
            # iteration (e.g. a late store).
            t.pre_var = self._NewBoolVar(f"{t.varname()}_pre")
            t.core_var = self._NewBoolVar(f"{t.varname()}_core")
            t.post_var = self._NewBoolVar(f"{t.varname()}_post")

    # ================================================================
    #                  CONSTRAINTS (Lifetime bounds)                 #
    # ================================================================

    def _is_low(self, t):
        assert isinstance(t, ComputationNode)
        return t in self._model.tree.nodes_low

    def _is_high(self, t):
        assert isinstance(t, ComputationNode)
        return t in self._model.tree.nodes_high

    def _is_input(self, t):
        assert isinstance(t, ComputationNode)
        return t.is_virtual_input

    def _is_output(self, t):
        assert isinstance(t, ComputationNode)
        return t.is_virtual_output

    def _iter_dependencies(self, with_virt=True, with_duals=True):
        def check_dep(t):
            (consumer, producer, _, _) = t
            if with_virt:
                yield t
            elif consumer in self._get_nodes() and producer.src in self._get_nodes():
                yield t

        def is_cross_iteration_dependency(producer, consumer):
            if self.config.sw_pipelining.enabled is not True:
                return False
            return self._is_low(producer.src) and self._is_high(consumer)

        for t in self._model.tree.iter_dependencies():
            yield from check_dep(t)

            if with_duals is False:
                continue

            (consumer, producer, a, b) = t
            if is_cross_iteration_dependency(producer, consumer):
                yield from check_dep((consumer.sibling, producer.sibling(), a, b))

    def _iter_dependencies_with_lifetime(self):

        def _get_lifetime_start(src):
            if isinstance(src, InstructionOutput):
                return src.src.out_lifetime_start[src.idx]
            if isinstance(src, InstructionInOut):
                return src.src.inout_lifetime_start[src.idx]
            raise SlothyException(f"Unknown register source {src}")

        def _get_lifetime_end(src):
            if isinstance(src, InstructionOutput):
                return src.src.out_lifetime_end[src.idx]
            if isinstance(src, InstructionInOut):
                return src.src.inout_lifetime_end[src.idx]
            raise SlothyException("Unknown register source")

        for consumer, producer, ty, idx in self._iter_dependencies():
            producer_start_var = _get_lifetime_start(producer)
            producer_end_var = _get_lifetime_end(producer)
            yield (
                consumer,
                producer,
                ty,
                idx,
                producer_start_var,
                producer_end_var,
                producer.alloc(),
            )

    def _iter_cross_iteration_dependencies(self):
        def is_cross_iteration_dependency(dep):
            (consumer, producer, _, _, _, _, _) = dep
            return self._is_low(producer.src) and self._is_high(consumer)

        yield from filter(
            is_cross_iteration_dependency, self._iter_dependencies_with_lifetime()
        )

    def _has_cross_iteration_dependencies(self):
        if not self.config.sw_pipelining.enabled:
            return False
        return next(self._iter_cross_iteration_dependencies(), None) is not None

    def _add_constraints_lifetime_bounds_single(self, t):

        def _add_basic_constraints(start_list, end_list):
            assert len(start_list) == len(end_list)
            for start_var, end_var in zip(start_list, end_list):
                # Make sure the output argument is considered 'used' for at least
                # one instruction. Otherwise, instructions producing outputs that
                # are never used would be able to overwrite life registers.
                self._Add(end_var > t.program_start_var)

        _add_basic_constraints(t.out_lifetime_start, t.out_lifetime_end)
        _add_basic_constraints(t.inout_lifetime_start, t.inout_lifetime_end)

    def _add_constraints_lifetime_bounds(self):

        for t in self._get_nodes(allnodes=True):
            self._add_constraints_lifetime_bounds_single(t)

        # For every instruction depending on the output, add a lifetime bound
        for (
            consumer,
            producer,
            _,
            _,
            start_var,
            end_var,
            _,
        ) in self._iter_dependencies_with_lifetime():
            self._add_path_constraint(
                consumer,
                producer.src,
                lambda end_var=end_var, consumer=consumer: self._Add(
                    end_var >= consumer.program_start_var
                ),
            )
            self._add_path_constraint(
                consumer,
                producer.src,
                lambda start_var=start_var, consumer=consumer: self._Add(
                    start_var < consumer.program_start_var
                ),
            )

    # ================================================================
    #                  CONSTRAINTS (Register allocation)             #
    # ================================================================

    # Some helpers
    def _force_allocation_variant(self, alloc_dict, combinations, combination_vars):
        if combinations is None:
            return
        assert len(combinations) == len(combination_vars)
        for (idx_lst, valid_combinations), vs in zip(combinations, combination_vars):
            self._AddExactlyOne(vs)
            assert len(valid_combinations) == len(vs)
            for combination, var in zip(valid_combinations, vs):
                assert len(idx_lst) == len(combination)
                for idx, reg in zip(idx_lst, combination):
                    self._AddImplication(var, alloc_dict[idx].get(reg, False))

    def _forbid_renaming_collision_single(self, var_dic_a, var_dic_b, condition=None):
        for reg, var_a in var_dic_a.items():
            var_b = var_dic_b.get(reg, None)
            if var_b is None:
                continue
            c = self._AddImplication(var_a, var_b.Not())
            if condition is not None:
                c.OnlyEnforceIf(condition)

    def _forbid_renaming_collision_many(self, idx_pairs, var_dic_a, var_dic_b):
        if idx_pairs is None:
            return
        for idx_a, idx_b in idx_pairs:
            self._forbid_renaming_collision_single(
                var_dic_a[idx_a], var_dic_b[idx_b], condition=None
            )

    def _force_renaming_collision(self, var_dic_a, var_dic_b):
        for reg, var_a in var_dic_a.items():
            var_b = var_dic_b.get(reg, None)
            if var_b is None:
                continue
            self._AddImplication(var_a, var_b)

    def _force_allocation_restriction_single(self, valid_allocs, var_dict):
        for k, v in var_dict.items():
            if k not in valid_allocs:
                self._Add(v == False)  # noqa: E712

    def _force_allocation_restriction_many(self, restriction_lst, var_dict_lst):
        assert len(restriction_lst) == len(var_dict_lst)
        for r, v in zip(restriction_lst, var_dict_lst):
            if r is None:
                continue
            self._force_allocation_restriction_single(r, v)

    def _add_constraints_register_renaming(self):

        if self.config.constraints.minimize_register_usage is not None:
            ty = self.config.constraints.minimize_register_usage
            for reg in self.arch.RegisterType.list_registers(ty):
                arr = self._model.register_usage_vars.get(reg, [])
                if len(arr) > 0:
                    self._AddMaxEquality(self._model._register_used[reg], arr)
                else:
                    self._Add(self._model._register_used[reg] == False)  # noqa: E712

        for t in self._get_nodes(allnodes=True):
            can_spill = True
            if t.is_virtual is True:
                can_spill = False
            if self.config.constraints.allow_spills is False:
                can_spill = False

            if can_spill is False:
                for v in t.out_spill_vars + t.in_out_spill_vars:
                    self._Add(v == False)  # noqa: E712
                continue

            for ty, v in list(zip(t.inst.arg_types_out, t.out_spill_vars)) + list(
                zip(t.inst.arg_types_in_out, t.in_out_spill_vars)
            ):
                if self.arch.RegisterType.spillable(ty) is False:
                    self._Add(v == False)  # noqa: E712

        # Ensure that outputs are unambiguous
        for t in self._get_nodes(allnodes=True):
            self.logger.debug(
                "Ensure unambiguous register renaming for %s", str(t.inst)
            )
            for dic in t.alloc_out_var:
                self._AddExactlyOne(dic.values())

        for t in self._get_nodes(allnodes=True):
            # Enforce input and output _combination_ restrictions
            self._force_allocation_variant(
                t.alloc_out_var,
                t.inst.args_out_combinations,
                t.alloc_out_combinations_vars,
            )
            self._force_allocation_variant(
                t.alloc_in_var,
                t.inst.args_in_combinations,
                t.alloc_in_combinations_vars,
            )
            self._force_allocation_variant(
                t.alloc_in_out_var,
                t.inst.args_in_out_combinations,
                t.alloc_in_out_combinations_vars,
            )
            # Enforce individual input argument restrictions (for outputs this has already
            # been done at the time when we created the allocation variables).
            self._force_allocation_restriction_many(
                t.inst.args_in_restrictions, t.alloc_in_var
            )
            self._force_allocation_restriction_many(
                t.inst.args_in_out_restrictions, t.alloc_in_out_var
            )
            # Enforce exclusivity of arguments
            self._forbid_renaming_collision_many(
                t.inst.args_in_out_different, t.alloc_out_var, t.alloc_in_var
            )
            self._forbid_renaming_collision_many(
                t.inst.args_in_inout_different, t.alloc_in_out_var, t.alloc_in_var
            )

        if self.config.inputs_are_outputs:

            def find_out_node(t_in):
                c = list(
                    filter(
                        lambda t: t.inst.orig_reg == t_in.inst.orig_reg,
                        self._model.tree.nodes_output,
                    )
                )
                if len(c) == 0:
                    raise SlothyException(
                        "Could not find matching output for input:" + t_in.inst.orig_reg
                    )
                if len(c) > 1:
                    raise SlothyException(
                        "Found multiple matching output nodes for input: "
                        + f"{t_in.inst.orig_reg}: {c}"
                    )
                return c[0]

            for t_in in self._model.tree.nodes_input:
                t_out = find_out_node(t_in)
                self._force_renaming_collision(
                    t_in.alloc_out_var[0], t_out.alloc_in_var[0]
                )

    # ================================================================
    #                 CONSTRAINTS (Software pipelining)              #
    # ================================================================

    def _add_constraints_loop_optimization(self):

        if not self.config.sw_pipelining.enabled:
            # Also if sw_pipelining is not enabled, we need to ensure that the
            # "branch" is always the last instruction
            for t in self._get_nodes():
                if t.inst.source_line.tags.get("branch", []):
                    self._Add(
                        t.program_start_var == self._model.program_padded_size - 1
                    )
            return

        if self.config.sw_pipelining.max_overlapping is not None:
            prepostlist = [t.core_var.Not() for t in self._get_nodes(low=True)]
            self._Add(
                cp_model.LinearExpr.Sum(prepostlist)
                <= self.config.sw_pipelining.max_overlapping
            )

        if self.config.sw_pipelining.min_overlapping is not None:
            prepostlist = [t.core_var.Not() for t in self._get_nodes(low=True)]
            self._Add(
                cp_model.LinearExpr.Sum(prepostlist)
                >= self.config.sw_pipelining.min_overlapping
            )

        for t in self._get_nodes():
            # If there is a instruction tagged with "branch" in the kernel, we
            # must ensure that it gets placed at the very end of the loop.
            if self._is_low(t):
                if t.inst.source_line.tags.get("branch", []):
                    self._Add(
                        t.program_start_var == self._model.program_padded_size_half - 1
                    )

            self._AddExactlyOne([t.pre_var, t.post_var, t.core_var])

            # Check if source line was tagged pre/core/post
            force_pre = t.inst.source_line.tags.get("pre", None)
            force_core = t.inst.source_line.tags.get("core", None)
            force_post = t.inst.source_line.tags.get("post", None)
            if force_pre is not None:
                assert force_pre is True or force_pre is False
                self._Add(t.pre_var == force_pre)
                self.logger.debug("Force pre=%s instruction for %s", force_pre, t.inst)
            if force_core is not None:
                assert force_core is True or force_core is False
                self._Add(t.core_var == force_core)
                self.logger.debug(
                    "Force core=%s instruction for %s", force_core, t.inst
                )
            if force_post is not None:
                assert force_post is True or force_post is False
                self._Add(t.post_var == force_post)
                self.logger.debug(
                    "Force post=%s instruction for %s", force_post, t.inst
                )

            if not self.config.sw_pipelining.allow_pre:

                self._Add(t.pre_var == False)  # noqa: E712
            if not self.config.sw_pipelining.allow_post:

                self._Add(t.post_var == False)  # noqa: E712

            if self.config.hints.all_core:
                self._AddHint(t.core_var, True)
                self._AddHint(t.pre_var, False)
                self._AddHint(t.post_var, False)

            # Allow early instructions only in a certain range
            if self.config.sw_pipelining.max_pre < 1.0 and self._is_low(t):
                relpos = t.orig_pos / len(self._get_nodes(low=True))
                if self.config.sw_pipelining.max_pre < relpos < 1:

                    self._Add(t.pre_var == False)  # noqa: E712

        if self.config.sw_pipelining.pre_before_post:
            for t, s in [
                (t, s)
                for t in self._get_nodes(low=True)
                for s in self._get_nodes(low=True)
            ]:
                self._Add(t.program_start_var > s.program_start_var).OnlyEnforceIf(
                    t.pre_var, s.post_var
                )

        for consumer, producer, _, _ in self._iter_dependencies(with_virt=False):
            if self._is_low(consumer) and self._is_low(producer.src):
                self._AddImplication(producer.src.post_var, consumer.post_var)
                self._AddImplication(consumer.pre_var, producer.src.pre_var)
                self._AddImplication(producer.src.pre_var, consumer.post_var.Not())
            elif self._is_low(producer.src) and self._is_high(consumer):
                self._AddImplication(producer.src.pre_var, consumer.pre_var)
                self._AddImplication(consumer.post_var, producer.src.post_var)
            #     self._AddImplication(producer.src.pre_var
            #     pass

            # An instruction with forward dependency to the next iteration
            # cannot be an early instruction, and an instruction depending
            # on an instruction from a previous iteration cannot be late.

            #  self._Add(producer.src.pre_var == False)

            # self._Add(consumer.post_var == False)

    # ================================================================
    #                  CONSTRAINTS (Single issuing)                  #
    # ================================================================

    def _add_constraints_n_issue(self):
        self._AddAllDifferent([t.program_start_var for t in self._get_nodes()])

        if self.config.variable_size:
            self._Add(
                self._model.program_padded_size
                == self._model.min_slots + self._model.pfactor * self._model.stalls
            )

        if self.config.constraints.functional_only:
            return
        for t in self._get_nodes():
            self._Add(
                t.program_start_var
                == t.cycle_start_var * self.target.issue_rate + t.slot_var
            )

    def _add_constraints_locked_ordering(self):

        def inst_changes_addr(inst):
            return inst.increment is not None

        def should_forbid_reordering(t0, t1):
            if not t0.inst.is_load_store_instruction():
                return False
            if not t1.inst.is_load_store_instruction():
                return False
            if t0.inst.addr != t1.inst.addr:
                return False
            if inst_changes_addr(t0.inst) and inst_changes_addr(t1.inst):
                return True
            if inst_changes_addr(t0.inst) and not t1.inst.offset_adjustable:
                return True
            if inst_changes_addr(t1.inst) and not t0.inst.offset_adjustable:
                return True
            return False

        def force_stays_before(t0, t1):
            if self.config.sw_pipelining.enabled:
                self._AddImplication(t0.post_var, t1.post_var)
                self._AddImplication(t1.pre_var, t0.pre_var)
                self._AddImplication(t0.pre_var, t1.post_var.Not())
            if should_forbid_reordering(t0, t1):
                self.logger.debug(
                    "Forbid reordering of (%s,%s) to avoid address fixup issues", t0, t1
                )
            self._add_path_constraint(
                t1,
                t0,
                lambda t0=t0, t1=t1: self._Add(
                    t0.program_start_var < t1.program_start_var
                ),
            )

        def comes_before(t0, t1):
            return t0.orig_pos < t1.orig_pos

        if self.config.constraints.allow_reordering is False:
            for t0, t1 in self.get_inst_pairs(cond=comes_before):
                force_stays_before(t0, t1)
        else:
            for t0, t1 in self.get_inst_pairs(
                cond_fst=lambda t: t.is_locked,
                cond_snd=lambda t: t.is_locked,
                cond=comes_before,
            ):
                force_stays_before(t0, t1)

            for t0, t1 in self.get_inst_pairs(
                cond_fst=lambda t: t.inst.is_load_store_instruction(),
                cond_snd=lambda t: t.inst.is_load_store_instruction(),
                cond=comes_before,
            ):
                if should_forbid_reordering(t0, t1):
                    force_stays_before(t0, t1)

        if self.config.sw_pipelining.enabled is True:
            nodes = self._get_nodes(low=True)
        else:
            nodes = self._get_nodes()

        def find_node_by_source_id(src_id):
            for t in nodes:
                cur_id = t.inst.source_line.tags.get("id", None)
                if cur_id == src_id:
                    return t
            raise SlothyException(f"Could not find node with source ID {src_id}")

        for i, t1 in enumerate(nodes):
            force_after = t1.inst.source_line.tags.get("after", [])
            if not isinstance(force_after, list):
                force_after = [force_after]
            t0s = []
            for fa in force_after:
                # In case the split heuristic is used, only instructions in the
                # current "window" are considered here. The instruction that is
                # being referred to using the id may not be present in this
                # snippet of code. Thus, no constraint needs to be added because
                # it does not affect this step right now, therefore we continue
                # despite the exception.
                try:
                    t0 = find_node_by_source_id(fa)
                    t0s.append(t0)
                except SlothyException as e:
                    if self.config.split_heuristic:
                        self.logger.info(
                            (
                                "%s < %s by source annotation NOT enforced because of "
                                "split heuristic"
                            ),
                            t0,
                            t1,
                        )
                        continue
                    else:
                        raise e

            force_after_last = t1.inst.source_line.tags.get("after_last", False)
            if force_after_last is True:
                if i == 0:
                    # Ignore after_last tag for first instruction
                    continue
                t0s.append(nodes[i - 1])
            for t0 in t0s:
                self.logger.info("Force %s < %s by source annotation", t0, t1)
                self._add_path_constraint(
                    t1,
                    t0,
                    lambda t0=t0, t1=t1: self._Add(
                        t0.program_start_var < t1.program_start_var
                    ),
                )

        for t0 in nodes:
            force_before = t0.inst.source_line.tags.get("before", [])
            if not isinstance(force_before, list):
                force_before = [force_before]
            for t1_id in force_before:
                # In case the split heuristic is used, only instructions in the
                # current "window" are considered here. The instruction that is
                # being referred to using the id may not be present in this
                # snippet of code. Thus, no constraint needs to be added because
                # it does not affect this step right now, therefore we continue
                # despite the exception.
                try:
                    t1 = find_node_by_source_id(t1_id)
                except SlothyException as e:
                    if self.config.split_heuristic:
                        self.logger.info(
                            (
                                "%s < %s by source annotation NOT enforced because of "
                                "split heuristic"
                            ),
                            t0,
                            t1,
                        )
                        continue
                    else:
                        raise e
                self.logger.info("Force %s < %s by source annotation", t0, t1)
                self._add_path_constraint(
                    t1,
                    t0,
                    lambda t0=t0, t1=t1: self._Add(
                        t0.program_start_var < t1.program_start_var
                    ),
                )

    # ================================================================
    #                  CONSTRAINTS (Single issuing)                  #
    # ================================================================

    def _add_constraints_scheduling(self):

        if self.config.sw_pipelining.enabled:
            self._Add(
                self._model.program_padded_size
                == 2 * self._model.program_padded_size_half
            )

        self.logger.debug(
            "Add positional constraints for %d instructions",
            len(self._model.tree.nodes),
        )

        for t in self._get_nodes():
            self.logger.debug("Add positional constraints for %s", t)
            self._Add(t.program_start_var <= self._model.program_padded_size - 1)
            for s in t.out_lifetime_end + t.out_lifetime_duration:
                self._Add(s <= self._model.program_padded_size)
            for s in t.inout_lifetime_end + t.inout_lifetime_duration:
                self._Add(s <= self._model.program_padded_size)

            if self.config.constraints.max_displacement < 1.0:
                self._AddAbsEq(
                    t.program_displacement, t.program_start_var - t.orig_pos_scaled
                )
                max_disp = int(
                    self.config.constraints.max_displacement
                    * self._model.program_padded_size_const
                )
                self._Add(t.program_displacement < max_disp)

            if self.config.constraints.functional_only:
                continue

            self._Add(t.cycle_start_var <= self._model.cycle_padded_size - 1)
            self._Add(t.cycle_end_var <= self._model.cycle_padded_size + 1)

    # ================================================================
    #               CONSTRAINTS (Functional correctness)             #
    # ----------------------------------------------------------------#
    #    A source line ('consumer') comes after the source lines     #
    #    ('producers') corresponding to its inputs                   #
    # ================================================================

    def _add_constraints_dependency_order(self):
        # If we model latencies, this constraint is automatic
        if self.config.constraints.model_latencies:
            return
        for consumer, producer, _, _ in self._iter_dependencies():
            self.logger.debug(
                "Program order constraint: [%s] > [%s]", consumer, producer.src
            )
            self._add_path_constraint(
                consumer,
                producer.src,
                lambda producer=producer, consumer=consumer: self._Add(
                    consumer.program_start_var > producer.src.program_start_var
                ),
            )

    # ================================================================
    #               CONSTRAINTS (Functional correctness)             #
    # ----------------------------------------------------------------#
    #    Obey instruction latencies                                  #
    # ================================================================

    def _add_constraints_latencies(self):
        if not self.config.constraints.model_latencies:
            return
        for t, i, _, _ in self._iter_dependencies(with_virt=False):
            latency = self.target.get_latency(i.src.inst, i.idx, t.inst)
            if isinstance(latency, int):
                self.logger.debug(
                    "General latency constraint: [%s] >= [%s] + %d", t, i.src, latency
                )
                # Some microarchitectures have instructions with 0-cycle latency, i.e.,
                # the can forward the result to an instruction in the same cycle
                # (e.g., X+str on Cortex-M7)
                # If that is the case we need to make sure that the consumer is after the
                # producer in the output.
                if latency == 0:
                    self._add_path_constraint(
                        t,
                        i.src,
                        lambda i=i, t=t: self._Add(
                            t.program_start_var > i.src.program_start_var
                        ),
                    )
                else:
                    self._add_path_constraint(
                        t,
                        i.src,
                        lambda t=t, i=i, latency=latency: self._Add(
                            t.cycle_start_var >= i.src.cycle_start_var + latency
                        ),
                    )
            else:
                # We allow `get_latency()` to return a pair (latency, exception),
                # where `exception` is a callback generating a constraint that _may_
                # be used as an alternative to the latency constraint.
                #
                # This mechanism is e.g. used to model very constrained forwarding paths
                exception = latency[1]
                latency = latency[0]
                self._add_path_constraint_from(
                    t,
                    i.src,
                    [
                        lambda t=t, i=i, latency=latency: self._Add(
                            t.cycle_start_var >= i.src.cycle_start_var + latency
                        ),
                        lambda t=t, i=i, exception=exception: self._Add(
                            exception(i.src, t)
                        ),
                    ],
                )

    # ================================================================#
    #               CONSTRAINTS (Functional correctness)              #
    # -----------------------------------------------------------------#
    # Between producer and consumer, noone overwrites output register #
    # ================================================================#

    def _add_constraints_register_usage(self):
        for usage_intervals in self._model.register_usages.values():
            self._AddNoOverlap(usage_intervals)

    # ================================================================#
    #                     CONSTRAINT (Performance)                    #
    # -----------------------------------------------------------------#
    # Further microarchitecture dependent positional constraints      #
    # ================================================================#

    def _add_constraints_misc(self):
        self.target.add_further_constraints(self)

    def get_inst_pairs(self, cond_fst=None, cond_snd=None, cond=None):
        """Yields all instruction pairs satisfying the provided predicate."""

        if cond_fst is None:

            def cond_fst(_):
                return True

        if cond_snd is None:

            def cond_snd(_):
                return True

        if cond is None:

            def cond(_x, _y):
                return True

        fst = list(filter(cond_fst, self._model.tree.nodes))
        snd = list(filter(cond_snd, self._model.tree.nodes))
        for t0 in fst:
            for t1 in snd:
                if cond(t0, t1):
                    yield (t0, t1)

    # ================================================================#
    #                     CONSTRAINT (Performance)                    #
    # -----------------------------------------------------------------#
    # Don't overload execution units                                  #
    # (avoid back-to-back vector instructions of the same kind)       #
    # ================================================================#

    def _add_constraints_functional_units(self):
        if not self.config.constraints.model_functional_units:
            return
        for unit in self.target.ExecutionUnit:
            self._AddNoOverlap(self._model.intervals_for_unit[unit])
        for t in self._get_nodes():
            if t.exec_unit_choices is None:
                continue
            self._AddExactlyOne(t.exec_unit_choices.values())

    # ==============================================================#
    #                      CONSTRAINT (Code size)                   #
    # --------------------------------------------------------------#
    # Use same register allocation iterations, to allow rolling     #
    # ==============================================================#

    def _add_constraints_loop_periodic(self):
        if not self.config.sw_pipelining.enabled:
            return

        # First iteration
        # `tt1.late -> tt0.core -> tt1.early``
        #
        # Second iteration
        # `tt0.late -> tt1.core ->tt0.early``
        #
        # So we're matching..
        # - `tt0.late  == tt1.late  + size`
        # - `tt1.core  == tt0.core  + size`
        # - `tt0.early == tt1.early + size`
        #
        # Additionally, they should use exactly the same registers, so we can roll the
        # loop again

        assert len(self._model.tree.nodes_low) == len(self._model.tree.nodes_high)
        for t0, t1 in zip(self._model.tree.nodes_low, self._model.tree.nodes_high):
            self._Add(t0.pre_var == t1.pre_var)
            self._Add(t0.post_var == t1.post_var)
            self._Add(t0.core_var == t1.core_var)
            # Early
            self._Add(
                t0.program_start_var
                == t1.program_start_var + self._model.program_padded_size_half
            ).OnlyEnforceIf(t0.pre_var)
            # Core
            self._Add(
                t1.program_start_var
                == t0.program_start_var + self._model.program_padded_size_half
            ).OnlyEnforceIf(t0.core_var)
            # Late
            self._Add(
                t0.program_start_var
                == t1.program_start_var + self._model.program_padded_size_half
            ).OnlyEnforceIf(t0.post_var)
            # Register allocations must be the same
            assert t0.inst.arg_types_out == t1.inst.arg_types_out
            for o, _ in enumerate(t0.inst.arg_types_out):
                t0_vars = set(t0.alloc_out_var[o].keys())
                t1_vars = set(t1.alloc_out_var[o].keys())
                # TODO: This might still fail in the case where we write to a global
                # output which hasn't been assigned an architectural register name.
                if not t1_vars.issubset(t0_vars):
                    self.logger.input.error(
                        "Instruction siblings %d:%s and %d:%s have incompatible"
                        " register renaming options:",
                        t1.orig_pos,
                        t1.inst,
                        t0.orig_pos,
                        t0.inst,
                    )
                    self.logger.input.error(
                        f"- {t1.orig_pos}:{t1.inst} has options {t1_vars}"
                    )
                    self.logger.input.error(
                        f"- {t0.orig_pos}:{t0.inst} has options {t0_vars}"
                    )
                assert t1_vars.issubset(t0_vars)
                for reg in t1_vars:
                    v0 = t0.alloc_out_var[o][reg]
                    v1 = t1.alloc_out_var[o][reg]
                    self._Add(v0 == v1)

    def restrict_early_late_instructions(self, filter_func):
        """Forces all instructions not passing the filter_func to be `core`, that is,
        neither early nor late instructions.

        This is only meaningful if software pipelining is enabled."""
        if not self.config.sw_pipelining.enabled:
            raise SlothyException(
                "restrict_early_late_instructions() only in SW pipelining mode"
            )

        for t in self._get_nodes():
            if filter_func(t.inst):
                continue
            self._Add(t.core_var == True)  # noqa: E712

    def force_early(self, filter_func, early=True):
        """Forces all instructions passing the filter_func to be `early`, that is,
        neither early nor late instructions.

        This is only meaningful if software pipelining is enabled."""
        if not self.config.sw_pipelining.enabled:
            raise SlothyException("force_early() only useful in SW pipelining mode")

        invalid_pre = early and not self.config.sw_pipelining.allow_pre
        invalid_post = not early and not self.config.sw_pipelining.allow_post
        if invalid_pre or invalid_post:
            raise SlothyException(
                "Invalid SW pipelining configuration in force_early()"
            )

        for t in self._get_nodes():
            if filter_func(t.inst):
                continue
            if early:
                self.logger.debug("Forcing instruction %s to be early", t)
                self._Add(t.pre_var == True)  # noqa: E712
            else:
                self.logger.debug("Forcing instruction %s to be late", t)
                self._Add(t.post_var == True)  # noqa: E712

    def restrict_slots_for_instruction(self, t, slots):
        """This forces the given instruction to be assigned precisely one of the slots
        in the provided slot list.

        This is only useful for microarchitecture models with multi-issuing
        (otherwise, there's only slot 0 anyway).

        For microarchitectures where functional units have a throughput of 1 instruction
        per cycle, this option can be an alternative way to model the occupancy of
        functional units: Rather than assigning length-1 intervals for the occupance of
        functional units and demanding that they're disjoint -- the default operation of
        Slothy, which works for multi-cycle instructions -- one can identify the slot
        number with the functional unit that an instruction runs on, and then the
        non-overlapping constraint is subsumed by the mutual distinctiveness of the
        program order positions.
        Note, though, that this approach 'overwrites' the actual microarchitectural
        meaning of the slot number -- if there are uarch constraints regarding the slot
        number (e.g. "instruction XYZ can only be issued on slot 0") then it should not
        be used.
        """
        slot_vars = {s: self._NewBoolVar("") for s in slots}
        self._AddExactlyOne(slot_vars.values())
        for s, var in slot_vars.items():
            self._Add(t.slot_var == s).OnlyEnforceIf(var)

    def restrict_slots_for_instructions(self, ts, slots):
        """Restrict issue slots for a list of instructions"""
        for t in ts:
            self.restrict_slots_for_instruction(t, slots)

    def filter_instructions_by_property(self, filter_func):
        """Returns all nodes for instructions passing the filter"""
        return [t for t in self._get_nodes() if filter_func(t.inst)]

    def filter_instructions_by_class(self, cls_lst):
        """Returns all nodes for instructions belonging the
        provided list of instruction classes."""
        return self.filter_instructions_by_property(lambda i: type(i) in cls_lst)

    def restrict_slots_for_instructions_by_class(self, cls_lst: list, slots: list):
        """Restrict issue slots for all instructions belonging to the
        provided list of instruction classes.

        :param cls_lst: A list of instruction classes
        :type cls_lst: list
        :param slots: A list of issue slots represented as integers.
        :type slots: list
        """
        self.restrict_slots_for_instructions(
            self.filter_instructions_by_class(cls_lst), slots
        )

    def restrict_slots_for_instructions_by_property(
        self, filter_func: any, slots: list
    ):
        """Restrict issue slots for all instructions passing the given
        filter function.

        :param filter_func: A predicate on instructions
        :type filter_func: any
        :param slots: A list of issue slots represented as integers.
        :type slots: list
        """
        self.restrict_slots_for_instructions(
            self.filter_instructions_by_property(filter_func), slots
        )

    # ==============================================================#
    #                         OBJECTIVES                            #
    # ==============================================================#

    def _stalls_to_stats(self, stalls):
        psize = self._model.min_slots + self._model.pfactor * stalls
        cc = psize // self.config.target.issue_rate
        cs = self._model.tree.num_nodes
        if cc == 0:
            return None
        cycles = psize // self._model.pfactor
        ipc = cs / cc
        return (cycles, ipc)

    def _print_stalls(self, stalls):
        r = self._stalls_to_stats(stalls)
        if r is None:
            return " (?)"
        (cycles, ipc) = r
        return f" (Cycles ~ {cycles}, IPC ~ {ipc:.2f})"

    def _print_stalls_and_spills(self, bound, variables):

        if "stalls" in variables.keys():
            stalls = variables["stalls"]
            # TODO: This needs fixing once the objective measure is no longer
            # stalls + spills
            spills = bound - stalls
        else:
            stalls = bound
            spills = None

        r = self._stalls_to_stats(stalls)
        if r is None:
            return " (?)"
        (cycles, ipc) = r

        if spills is not None:
            return f" (Cycles ~ {cycles}, IPC ~ {ipc:.2f}, Spills {spills})"
        else:
            return f" (Cycles ~ {cycles}, IPC ~ {ipc:.2f})"

    def _add_objective(self, force_objective=False):
        minlist = []
        maxlist = []
        name = None
        printer = None
        objective_vars = None

        # If the number of stalls is variable, its minimization is our objective
        if force_objective is False and self.config.variable_size:
            name = "minimize cycles"
            if self.config.constraints.functional_only is False:
                if self.config.constraints.minimize_spills is False:
                    printer = self._print_stalls
                else:
                    printer = self._print_stalls_and_spills
                    objective_vars = {"stalls": self._model.stalls}
            minlist = [self._model.stalls]

            # Spill minimization is integrated into the variable-size optimization,
            # currently by counting every spill as 1 stall
            #
            # TODO: This needs refining!
            if self.config.constraints.minimize_spills:
                minlist += self._model.spill_vars
        elif self.config.has_objective and not self.config.ignore_objective:
            if (
                self.config.sw_pipelining.enabled is True
                and self.config.sw_pipelining.minimize_overlapping is True
            ):
                # Minimize the amount of iteration interleaving
                corevars = [t.core_var.Not() for t in self._get_nodes(low=True)]
                minlist = corevars
                name = "minimize iteration overlapping"
            elif self.config.constraints.minimize_spills:
                name = "minimize spills"
                minlist = self._model.spill_vars
            elif self.config.constraints.maximize_register_lifetimes:
                name = "maximize register lifetimes"
                maxlist = [
                    v
                    for t in self._get_nodes(allnodes=True)
                    for v in t.out_lifetime_duration
                ]
            elif self.config.constraints.move_stalls_to_bottom is True:
                minlist = [t.program_start_var for t in self._get_nodes()]
                name = "move stalls to bottom"
            elif self.config.constraints.move_stalls_to_top is True:
                maxlist = [t.program_start_var for t in self._get_nodes()]
                name = "move stalls to top"
            elif self.config.constraints.minimize_register_usage is not None:
                minlist = list(self._model._register_used.values())
                name = "minimize number of registers used"
            elif self.config.constraints.minimize_use_of_extra_registers is not None:
                ty = self.config.constraints.minimize_use_of_extra_registers
                minlist = []
                for r in self.arch.RegisterType.list_registers(ty, only_extra=True):
                    minlist += self._model.register_usage_vars.get(r, [])
            elif self.target.has_min_max_objective(self.config):
                # Check if there's some target-specific objective
                lst, ty, name = self.target.get_min_max_objective(self.config)
                if ty == "minimize":
                    minlist = lst
                else:
                    maxlist = lst

        self._model.objective_printer = printer
        self._model.objective_vars = objective_vars

        if name is not None:
            assert not (len(minlist) > 0 and len(maxlist) > 0)
            if len(minlist) > 0:
                self._model.cp_model.Minimize(cp_model.LinearExpr.Sum(minlist))
            if len(maxlist) > 0:
                self._model.cp_model.Maximize(cp_model.LinearExpr.Sum(maxlist))
            self.logger.info("Objective: %s", name)
            self._model.objective_name = name
        else:
            self.logger.info("Objective: None (any satisfying solution is fine)")
            self._model.objective_name = "no objective"

    #
    # Dummy wrappers around CP-SAT
    #
    # Introduced so one can easily log model building calls, or use a different solver.
    #

    def _describe_solver(self):
        workers = self._model.cp_solver.parameters.num_workers
        if workers > 0:
            return f"OR-Tools CP-SAT v{ortools.__version__}, {workers} threads"
        return f"OR-Tools CP-SAT v{ortools.__version__}"

    def _init_external_model_and_solver(self):
        self._model.cp_model = cp_model.CpModel()
        self._model.cp_solver = cp_model.CpSolver()
        self._model.cp_solver.random_seed = self.config.solver_random_seed

    def _NewIntVar(self, minval, maxval, name=""):
        r = self._model.cp_model.NewIntVar(minval, maxval, name)
        self._model.variables.append(r)
        return r

    def _NewIntervalVar(self, base, dur, end, name=""):
        return self._model.cp_model.NewIntervalVar(base, dur, end, name)

    def _NewOptionalIntervalVar(self, base, dur, end, cond, name=""):
        return self._model.cp_model.NewOptionalIntervalVar(base, dur, end, cond, name)

    def _NewBoolVar(self, name=""):
        r = self._model.cp_model.NewBoolVar(name)
        self._model.variables.append(r)
        return r

    def _NewConstant(self, val):
        r = self._model.cp_model.NewConstant(val)
        return r

    def _Add(self, c):
        return self._model.cp_model.Add(c)

    def _AddNoOverlap(self, lst):
        return self._model.cp_model.AddNoOverlap(lst)

    def _AddExactlyOne(self, lst):
        return self._model.cp_model.AddExactlyOne(lst)

    def _AddMultiplicationEquality(self, lst, res):
        return self._model.cp_model.AddMultiplicationEquality(res, lst)

    def _AddImplication(self, a, b):
        return self._model.cp_model.AddImplication(a, b)

    def _AddAtLeastOne(self, lst):
        return self._model.cp_model.AddAtLeastOne(lst)

    def _AddAbsEq(self, dst, expr):
        return self._model.cp_model.AddAbsEquality(dst, expr)

    def _AddAllDifferent(self, lst):
        return self._model.cp_model.AddAllDifferent(lst)

    def _AddHint(self, var, val):
        return self._model.cp_model.AddHint(var, val)

    def _AddMaxEquality(self, varlist, var):
        return self._model.cp_model.AddMaxEquality(varlist, var)

    def _export_model(self):
        if self.config.log_model is None:
            return

        if self.config.log_model is True:
            model_file = "slothy_model"
        else:
            model_file = self.config.log_model
            assert isinstance(model_file, str)

        # Always append a timestamp
        model_file += f"_{int(time.time()*1000)}.txt"

        log_file = self.config.log_model_dir + "/" + model_file
        self.logger.info("Writing model to %s ...", log_file)
        assert self._model.cp_model.ExportToFile(log_file)

        if self.config.log_model_log_results is True:
            results_file = (
                self.config.log_model_dir + "/" + self.config.log_model_results_file
            )
            result = []
            result.append(f'Model: "{model_file}"')
            result.append(f'Version: "{ortools.__version__}"')
            result.append(f"Time (seconds): {self._model.cp_solver.WallTime():.4f}")
            result.append(
                f"Status: "
                f'"{self._model.cp_solver.StatusName(self._model.cp_model.status)}"'
            )
            result.append("")
            result.append("")
            with open(results_file, "a") as f:
                f.write("\n".join(result))

    def _solve(self):

        # Determines whether the best solution found so far is close enough to the optimum
        # that we should stop.
        def is_good_enough(cur, bound):
            if self._model.objective_name == "minimize cycles":
                prec = self.config.constraints.stalls_precision
                if cur - bound <= self.config.constraints.stalls_precision:
                    self.logger.info(
                        "Closer than %d stalls to theoretical optimum... stop", prec
                    )
                    return True
                if (
                    self.config.objective_lower_bound is not None
                    and cur <= self.config.objective_lower_bound
                ):
                    self.logger.info(
                        "Reached user-defined objective_lower_bound ... stop"
                    )
                    return True
            elif self._model.objective_name != "no objective":
                prec = self.config.objective_precision
                if bound > 0 and abs(1 - (cur / bound)) < prec:
                    self.logger.info(
                        "Closer than %d%% to theoretical optimum... stop",
                        int(prec * 100),
                    )
                    return True
                if (
                    self.config.objective_lower_bound is not None
                    and cur <= self.config.objective_lower_bound
                ):
                    self.logger.info(
                        "Reached user-defined objective_lower_bound ... stop"
                    )
                    return True
            return False

        solution_cb = SlothyBase.CpSatSolutionCb(
            self.logger,
            self._model.objective_name,
            self.config.max_solutions,
            is_good_enough=is_good_enough,
            printer=self._model.objective_printer,
            variables=self._model.objective_vars,
        )
        self._model.cp_model.status = self._model.cp_solver.Solve(
            self._model.cp_model, solution_cb
        )

        status_str = self._model.cp_solver.StatusName(self._model.cp_model.status)
        self.logger.info(
            "%s, wall time: %4f s", status_str, self._model.cp_solver.WallTime()
        )

        ok = self._model.cp_model.status in [cp_model.FEASIBLE, cp_model.OPTIMAL]

        # - Export (optional)
        self._export_model()

        if ok:
            # Remember solution in case we want to retry with an(other) objective
            self._model.cp_model.ClearHints()
            for v in self._model.variables:
                self._AddHint(v, self._model.cp_solver.Value(v))

        return ok

    def retry(self, fix_stalls=None):
        self._result = Result(self.config)

        if fix_stalls is not None:
            assert self.config.variable_size
            self._Add(self._model.stalls == fix_stalls)

        self._set_timeout(self.config.retry_timeout)

        # - Objective
        self._add_objective(force_objective=fix_stalls is not None)

        # Do the actual work
        self.logger.info("Invoking external constraint solver...")
        self.result.success = self._solve()
        self.result.valid = True
        if not self.success:
            return False

        self._extract_result()
        return True

    def _dump_model_statistics(self):
        # Extract and report results
        SourceLine.log(
            "Statistics", self._model.cp_model.cp_solver.ResponseStats(), self.logger
        )

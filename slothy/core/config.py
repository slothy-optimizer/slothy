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

"""
SLOTHY configuration
"""


from copy import deepcopy
import os

from slothy.helper import LockAttributes, NestedPrint


class InvalidConfig(Exception):
    """Exception raised when an invalid SLOTHY configuration is detected"""


class Config(NestedPrint, LockAttributes):
    """Configuration for Slothy.

    This configuration object is used both for one-shot optimizations using
    SlothyBase, as well as stateful multi-pass optimizations using Slothy.
    """

    @property
    def arch(self):
        """The module defining the underlying architecture used by Slothy.

        TODO: Add details on what exactly is assumed about this module.
        """
        return self._arch

    @property
    def target(self):
        """The module defining the target microarchitecture used by Slothy.

        TODO: Add details on what exactly is assumed about this module.
        """
        return self._target

    @property
    def outputs(self):
        """List defining of architectural or symbolic registers that should
        be considered as outputs of the input snippet.
        """
        return self._outputs

    @property
    def reserved_regs(self):
        """Set of architectural registers _not_ available for register renaming.
        May be unset (None) to pick the default reserved registers for the target
        architecture.

        In the lingo of inline assembly, this can be seen as the complement of
        the clobber list.

        .. note::

            Reserved registers are, by default, considered  "locked": They
            will not be _introduced_ during renaming, but existing uses will not
            be touched. If you want to remove existing uses of reserved registers
            through renaming, you should disable `reserved_regs_are_locked`.

        .. warning::

            When this is set, it _overwrites_ the default reserved registers for
            the target architecture. If you still want the default reserved
            registers to remain reserved, you have to explicitly list them!
        """
        if self._reserved_regs is not None:
            return self._reserved_regs
        return self._arch.RegisterType.default_reserved()

    @property
    def reserved_regs_are_locked(self):
        """Indicates whether reserved registers should be locked by default.

        Reserved registers are not introduced during renaming. However, where
        they are already used by the input assembly, their use will not be
        eliminated or altered -- that is, reserved registers are 'locked' by
        default.

        Disable this configuration option to allow (in fact, force) renaming
        of existing uses of reserved registers. This can be useful when trying
        to eliminate uses of particular registers from some piece of assembly.
        """
        return self._reserved_regs_are_locked

    @property
    def selftest(self):
        """
        Indicates whether SLOTHY performs an empirical equivalence-test on the
        optimization results.

        When this is set, and if the target architecture and host platform support it,
        this will run an empirical equivalence checker trying to confirm that the
        input and output of SLOTHY are likely functionally equivalent.

        The primary purpose of this checker is to detect issue that would presently
        be overlooked by the selfcheck:

        * The selfcheck is currently blind to address offset fixup. If something goes
          wrong, the input and output will not be functionally equivalent, but we would
          only notice once we actually compile and run the code. The selftest will
          likely catch issues.

        * When using software pipelining, the selfcheck reduces to a straightline check
          for a bounded unrolling of the loop. An unbounded selfcheck is currently not
          implemented. With the selftest, you still need to fix a loop bound, but at
          least you can equivalence-check the loop-form (including the compare+branch
          instructions at the loop boundary) rather than the unrolled code.

        .. important::

            To run this, you need `llvm-nm`, `llvm-readobj`, `llvm-mc`
            in your PATH. Those are part of a standard LLVM setup.

        .. note::

            This is so far implemented as a repeated randomized test -- nothing clever.
        """
        return self._selftest

    @property
    def selftest_iterations(self):
        """If selftest is set, indicates the number of random selftest to conduct"""
        return self._selftest_iterations

    @property
    def selftest_address_registers(self):
        """Dictionary of (reg, sz) items indicating which registers are assumed to be
        pointers to memory, and if so, of what size.
        """
        return self._selftest_address_registers

    @property
    def selftest_default_memory_size(self):
        """Default buffer size to use for registers which are automatically inferred to be
        used as pointers and for which no memory size has been configured via
        `address_registers`.
        """
        return self._selftest_default_memory_size

    @property
    def selfcheck(self):
        """Indicates whether SLOTHY performs a self-check on the optimization result.

        The selfcheck confirms that the scheduling permutation found by SLOTHY yields
        an isomorphism between the data flow graphs of the original and optimized code.

        .. warning::

            Do not unset this option unless you know what you are doing.
            It is vital in catching bugs in the model generation early.

        .. warning::

            The selfcheck is not a formal verification of SLOTHY's output!
            There are at least two classes of bugs uncaught by the selfcheck:

            * User configuration issues: The selfcheck validates SLOTHY's optimization
              in the context of the provided configuration. Validation of the
              configuration is the user's responsibility. Two common pitfalls include
              missing reserved registers (allowing SLOTHY to clobber more registers than
              intended), or missing output registers (allowing SLOTHY to overwrite an
              output register in subsequent instructions).

              This is the most common source of issues for code passing the selfcheck
              but remaining functionally incorrect.

            * Bugs in address offset fixup: SLOTHY's modelling of post-load/store address
              increments is deliberately inaccurate to allow for reordering of such
              instructions leveraging commutativity relations such as

            .. code-block:: asm

                LDR X,[A],#imm;  STR Y,[A]    ===     STR Y,[A, #imm];  LDR X,[A],#imm


            .. hint::

                See also section "Address offset rewrites" in the SLOTHY paper

            Bugs in SLOTHY's address fixup logic would not be caught by the selfcheck.
            If your code doesn't work and you are sure to have configured SLOTHY
            correctly, you may therefore want to double-check that address offsets have
            been adjusted correctly by SLOTHY.
        """
        return self._selfcheck

    @property
    def selfcheck_failure_logfile(self):
        """The filename for the log of a failing selfcheck.

        This is printed in the terminal as well, but difficult to analyze for its
        sheer size.
        """
        return self._selfcheck_failure_logfile

    @property
    def unsafe_address_offset_fixup(self):
        """Whether address offset fixup is enabled

        Address offset fixup is a feature which leverages commutativity relations
        such as

        .. code-block:: asm

            ldr X, [A], #immA;
            str Y, [A, #immB]
            ==
            str Y, [A, #(immB+immA)]
            ldr X, [A], #immA

        to achieve greater instruction scheduling flexibility in SLOTHY.

        .. important::

            When you enable this feature, you MUST ensure that registers which are
            used for addresses are not used in any other instruction than load and
            stores. OTHERWISE, THE USE OF THIS FEATURE IS UNSOUND (you may see ldr/
            str instructions with increment reordered with instructions depending
            on the address register).

        By default, this is enabled for backwards compatibility.

        .. note::

            For historical reason, this feature cannot be disabled for
            the Armv8.1-M architecture model. A refactoring of that model is needed
            to make address offset fixup configurable.

        .. note::

            The user-imposed safety constraint is not a necessity -- in principle,
            SLOTHY could detect when it is safe to reorder ldr/str instructions with
            increment.
            It just hasn't been implemented yet.
        """
        return self._unsafe_address_offset_fixup

    @property
    def allow_useless_instructions(self):
        """Indicates whether SLOTHY should abort upon encountering unused instructions.

        SLOTHY requires explicit knowledge of the intended output registers of its
        input assembly. If this option is set, and an instruction is encountered which
        writes to a register which (a) is not an output register, (b) is not used by
        any later instruction, then SLOTHY will flag this instruction and abort.

        The reason for this behaviour is that such unused instructions are usually
        a sign of a buggy configuration, which would likely lead to intended output
        registers being clobbered by later instructions.

        .. warning::

            Don't disable this option unless you know what you are doing!
            Disabling this option makes it much easier to overlook configuration
            issues in SLOTHY and can lead to hard-to-debug optimization failures.
        """
        return self._allow_useless_instructions

    @property
    def variable_size(self):
        """Model number of stalls as a parameter in the constraint model.

        If this is set, one-shot SLOTHY optimization will make the number of stalls
        flexible in the model and, by default, task the underlying constraint solver
        to minimize it.

        If this is not set, one-shot SLOTHY optimizations will search for solutions
        with a fixed number of stalls, and an external binary search be used to
        find the minimum number of stalls.

        For small-to-medium sizes assembly input, this option should be set, and will
        lead to faster optimization. For large assembly input, the user should experiment
        and consider unsetting it to reduce model complexity.
        """
        return self._variable_size

    @property
    def keep_tags(self):
        """Indicates whether tags in the input source should be kept or removed.

        Tags include pre/core/post or ordering annotations that usually become meaningless
        post-optimization. However, for preprocessing runs that do not reorder code, it
        makes sense to keep them.
        """
        return self._keep_tags

    @property
    def inherit_macro_comments(self):
        """Indicates whether comments at macro invocations should be inherited to
        instructions in the macro body.
        """
        return self._inherit_macro_comments

    @property
    def ignore_tags(self):
        """Indicates whether tags in the input source should be ignored."""
        return self._ignore_tags

    @property
    def register_aliases(self):
        """Dictionary mapping symbolic register names to architectural register names.
        When using Slothy, this can be indirectly populated by placing `.req` expressions
        in the input assembly. When using SlothyBase directly, this needs to be filled
        in by hand.

        This is always joined with a list of default aliases (such as lr mapping to r14)
        specified in the target architecture.
        """
        return {**self._register_aliases, **self._arch.RegisterType.default_aliases()}

    def add_aliases(self, new_aliases):
        """Add further register aliases to the configuration"""
        self._register_aliases = {**self._register_aliases, **new_aliases}

    @property
    def rename_inputs(self):
        """A dictionary mapping input register names (symbolic or architectural) to their
        renaming configuration.

        There are three supported renaming configurations per input: "static", "any", or
        a fixed architectural register. The configuration "any" means that the input may
        be freely renamed, and that the renaming is chosen at model solving time. This is
        the most flexible, but also the most demanding option. The configuration "static"
        means that the renaming is chosen at model construction time, as follows: If the
        input does already have an architectural name, it will keep it. If, otherwise, it
        is a symbolic input, it will be statically assigned an architectural name at model
        construction time. Finally, if the input is explicitly assigned an architectural
        register name, this name will be enforced. Note that this even applies to inputs
        which already have an architectural name -- that is, you can use this option to
        change the architectural allocation of inputs.

        The special keys "symbolic", "arch" apply to all symbolic and architectural
        inputs, respectively. The key "other" applies to all inputs for which no other
        key matches.

        The default value is { "symbolic": "any", "arch" : "static" } -- that is,
        architectural inputs are not renamed, while symbolic inputs are dynamically
        renamed.

        Examples:

        * Generally, unless you are prepared to modify surrounding code, you should
          have "arch" : "static", which will not rename inputs which already have
          architectural register names.
        * Config.rename_inputs = { "other" : "any" }
          This would rename _all_ inputs, regardless of whether they're symbolic or not.
          Thus, you'd likely need to modify surrounding code.
        * Config.rename_inputs = { "in" : "r0", "arch" : "static", "symbolic" : "any" }
          This would rename the symbolic input GPR 'in' to 'r0', keep all other inputs
          which already have an architectural name, while dynamically assigning suitable
          registers for symbolic inputs.

        In case of a successful optimization, the assignment of input registers to
        architectural registers is given by the dictionary Result.input_renaming.
        """
        self._check_rename_config(self._rename_inputs)
        return self._rename_inputs

    @property
    def rename_outputs(self):
        """A dictionary mapping output register names (symbolic or architectural) to their
        renaming configuration.

        Analogous to Config.rename_inputs.

        The default value is { "symbolic": "any", "arch" : "static" } -- that is,
        architectural outputs are not renamed, while symbolic outputs are dynamically
        renamed.

        In case of a successful optimization, the assignment of input registers to
        architectural registers is given by the dictionary Result.input_renaming.
        """
        self._check_rename_config(self._rename_outputs)
        return self._rename_outputs

    @property
    def inputs_are_outputs(self):
        """If set, any input in the assembly to be optimized (that is, every register
        that is used as an input before it has been written to) is treated as an output.
        _Moreover_, such simultaneous input-outputs are forced to reside in the same
        architectural register at the beginning and end of the snippet.

        This should usually be set when optimizing loops.
        """
        return self._inputs_are_outputs

    @property
    def locked_registers(self):
        """List of architectural registers that should not be renamed when they are
        used as output registers. Reserved registers are treated as locked if
        the option `reserved_regs_are_locked` is set.
        """
        if self.reserved_regs_are_locked:
            return set(self.reserved_regs).union(self._locked_registers)
        else:
            return set(self._locked_registers)

    @property
    def sw_pipelining(self):
        """Subconfiguration for software pipelining. Enabled/Disabled
        via the sub-field sw_pipelining.enabled. See Config.SoftwarePipelining
        for more information.
        """
        return self._sw_pipelining

    @property
    def constraints(self):
        """Subconfiguration for constraints to be considered by SLOTHY,
        e.g. whether latencies or functional units are modelled.
        See Config.Constraints for more information.
        """
        return self._constraints

    @property
    def hints(self):
        """Subconfiguration for hints to be considered by SLOTHY.
        See Config.Hints for more information.
        """
        return self._hints

    @property
    def max_solutions(self):
        """The maximum number of solution found by the underlying constraint
        solver before it stops the search.
        """
        return self._max_solutions

    @property
    def with_preprocessor(self):
        """Indicates whether the C preprocessor is run prior to optimization."""
        return self._with_preprocessor

    @property
    def with_llvm_mca(self):
        """Indicates whether LLVM MCA should be run prior and after optimization
        to obtain approximate performance data based on LLVM's scheduling models.

        If this is set, Config.compiler_binary need to be set, and llcm-mca in
        your PATH.
        """
        return self._with_llvm_mca_before and self._with_llvm_mca_after

    @property
    def llvm_mca_full(self):
        """Indicates whether all available statistics from LLVM MCA should be printed."""
        return self._llvm_mca_full

    @property
    def llvm_mca_issue_width_overwrite(self):
        """Overwrite LLVM MCA's in-built issue width with the one SLOTHY uses"""
        return self._llvm_mca_issue_width_overwrite

    @property
    def with_llvm_mca_before(self):
        """Indicates whether LLVM MCA should be run prior to optimization
        to obtain approximate performance data based on LLVM's scheduling models.

        If this is set, Config.compiler_binary need to be set, and llcm-mca in
        your PATH.
        """
        return self._with_llvm_mca_before

    @property
    def with_llvm_mca_after(self):
        """Indicates whether LLVM MCA should be run after optimization
        to obtain approximate performance data based on LLVM's scheduling models.

        If this is set, Config.compiler_binary need to be set, and llcm-mca in
        your PATH.
        """
        return self._with_llvm_mca_after

    @property
    def compiler_binary(self):
        """The compiler binary to be used.

        This is only relevant if `with_preprocessor` or `with_llvm_mca_before`
        or `with_llvm_mca_after` are set."""
        return self._compiler_binary

    @property
    def compiler_include_paths(self):
        """Include path to add to compiler invocations

        This is only relevant if `with_preprocessor` or `with_llvm_mca_before`
        or `with_llvm_mca_after` are set."""
        return self._compiler_include_paths

    @property
    def timeout(self):
        """The timeout in seconds after which each invocation of the underlying
        constraint solver stops its search. A positive integer."""
        return self._timeout

    @property
    def retry_timeout(self):
        """The timeout in seconds after which the underlying constraint solver stops
        its search, in case of secondary optimization passes for other objectives than
        performance optimization (e.g., minimization of iteration overlapping)."""
        return self._retry_timeout

    @property
    def do_address_fixup(self):
        """Indicates whether post-optimization address fixup should be conducted.

        SLOTHY's modelling of post-load/store address increments is deliberately
        inaccurate to allow for reordering of such instructions leveraging commutativity
        relations such as:

        ```
        LDR X,[A],#imm;  STR Y,[A]    ===     STR Y,[A, #imm];  LDR X,[A],#imm
        ```

        When such reordering happens, a "post-optimization address fixup" of immediate
        load/store offsets is necessary. See also section "Address offset rewrites" in
        the SLOTHY paper.

        Disabling this option will skip post-optimization address fixup and put the
        burden of post-optimization address fixup on the user.
        Disabling this option does NOT tighten the constraint model to forbid reorderings
        such as the above.

        WARNING: Don't disable this option unless you know what you are doing!
            Disabling this will likely lead to optimized code that is functionally
            incorrect and needing manual address offset fixup!
        """
        return self._do_address_fixup

    @property
    def ignore_objective(self):
        """Indicates whether the secondary objective (such as minimization of iteration
        overlapping) should be ignored."""
        return self._ignore_objective

    @property
    def objective_precision(self):
        """The proximity to the estimated optimum solution at which the solver will
        stop its search.

        For example, a value of 0.05 means that the solver will stop when the current
        solution is within 5% of the current estimate for the optimal solution."""
        return self._objective_precision

    @property
    def objective_lower_bound(self):
        """A lower bound for the objective at which to stop the search."""
        return self._objective_lower_bound

    @property
    def has_objective(self):
        """Indicates whether a different objective than minimization of stalls
        has been registered."""
        objectives = sum(
            [
                self.sw_pipelining.enabled
                and self.sw_pipelining.minimize_overlapping is True,
                self.constraints.maximize_register_lifetimes is True,
                self.constraints.minimize_spills is True,
                self.constraints.move_stalls_to_top is True,
                self.constraints.move_stalls_to_bottom is True,
                self.constraints.minimize_register_usage is not None,
                self.constraints.minimize_use_of_extra_registers is not None,
                self.target.has_min_max_objective(self),
            ]
        )
        if objectives > 1:
            raise InvalidConfig("Can only pick one optimization objective")

        return objectives == 1

    @property
    def absorb_spills(self):
        return self._absorb_spills

    @property
    def split_heuristic(self):
        """Trade-off between runtime and optimality: Split each code block
        to be optimized into a fixed number of subchunks and optimize them
        one by one, rather than attempting a single large optimization.

        If enabled, the numeric option split_heuristic_factor determines the
        number of factors to split each block of code into.
        """
        return self._split_heuristic

    @property
    def split_heuristic_factor(self):
        """If split_heuristic is enabled, the number of factors to split each
        code block into prior to passing it to the core of Slothy.

        The value of this option is irrelevant if split_heuristic is False.
        """
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_factor otherwise."
            )
        return self._split_heuristic_factor

    @property
    def split_heuristic_abort_cycle_at_high(self):
        """During the split heuristic, a threshold for the number of stalls in the current
        optimization window above which the current pass of the split heuristic should
        stop.
        """
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_abort_cycle_at otherwise."
            )
        return self._split_heuristic_abort_cycle_at_high

    @property
    def split_heuristic_abort_cycle_at_low(self):
        """During the split heuristic, a threshold for the number of stalls in the current
        optimization window below which the current pass of the split heuristic should
        stop.
        """
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_abort_cycle_at otherwise."
            )
        return self._split_heuristic_abort_cycle_at_low

    @property
    def split_heuristic_stepsize(self):
        """If split heuristic is used, the increment for the sliding window. By default,
        this is twice the split factor. For example, a split factor of 5 means that the
        window size is 0.2 of the overall code size, and the default step size of 0.1
        means that the sliding windows will be [0,0.2], [0.1,0.3], ..."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_stepsize otherwise."
            )
        return self._split_heuristic_stepsize

    @property
    def split_heuristic_optimize_seam(self):
        """If the split heuristic is used, the number of instructions above and beyond
        the current sliding window that should be fixed but taken into account during
        optimization."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_optimize_seam otherwise."
            )
        return self._split_heuristic_optimize_seam

    @property
    def split_heuristic_chunks(self):
        """If split heuristic is used, explicitly lists the optimization windows to be
        used. If unset, a sliding or adaptive optimization window will be used."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_chunks otherwise."
            )
        return self._split_heuristic_chunks

    @property
    def split_heuristic_bottom_to_top(self):
        """If the split heuristic is used, move the sliding window from bottom to top
        rather than from top to bottom."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_bottom_to_top otherwise."
            )
        return self._split_heuristic_bottom_to_top

    @property
    def split_heuristic_region(self):
        """Restrict the split heuristic to a sub-region of the code.

        For example, if this is set to [0.25,0.75], only the middle half of the input will
        be optimized through the split heuristic.

        This option can be combined with other options such as the split factor.
        For example, if the split region is set fo [0.25, 0.75] and the split factor is
        5, then optimization windows of size .1 will be considered within [0.25, 0.75].

        Note that even if this option is used, the specification of inputs and outputs is
        still with respect to the entire code; SLOTHY will automatically derive the
        outputs of the subregion configured here."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_region otherwise."
            )
        return self._split_heuristic_region

    @property
    def split_heuristic_preprocess_naive_interleaving(self):
        """Prior to applying the split heuristic, interleave instructions according
        to lowest depth, without applying register renaming.

        This can be useful if the code to be optimized is comprised of independent
        computations operating on different architectural state (e.g. scalar vs. SIMD);
        in this case, the naive preprocessing will 'zip' the different computations prior
        to applying the core optimization."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_preprocess_naive_interleaving "
                "otherwise."
            )
        return self._split_heuristic_preprocess_naive_interleaving

    @property
    def split_heuristic_preprocess_naive_interleaving_by_latency(self):
        """If split heuristic with naive preprocessing is used, this option causes
        the naive interleaving to be by latency-depth rather than latency."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? Shouldn't"
                "read config.split_heuristic_preprocess_naive_interleaving_by_latency "
                "otherwise."
            )
        return self._split_heuristic_preprocess_naive_interleaving_by_latency

    @property
    def split_heuristic_estimate_performance(self):
        """After applying the split heuristic, run SLOTHY again on the entire code to
        estimate the performance and display un-used issue slots in the output."""
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? Shouldn't"
                "read config.split_heuristic_estimate_performance otherwise."
            )
        return self._split_heuristic_estimate_performance

    @property
    def split_heuristic_repeat(self):
        """If split_heuristic is enabled, the number of times the splitting heuristic
        should be repeated.

        Note: This is an experimental option the practical value of which has not yet
        been thoroughly studied. Try if you like, but beware the bump in runtime for
        the optimization.

        The value of this option is irrelevant if split_heuristic is False.
        """
        if not self.split_heuristic:
            raise InvalidConfig(
                "Did you forget to set config.split_heuristic=True? "
                "Shouldn't read config.split_heuristic_repeat otherwise."
            )
        return self._split_heuristic_repeat

    @property
    def split_heuristic_preprocess_naive_interleaving_strategy(self):
        """Strategy for naive interleaving preprocessing step

        Supported values are:

        * "depth": Always pick the instruction with the lower possible
          depth in the DFG first.
        * "alternate": Try to evenly alternate between instructions tagged with
          "interleaving_class=0/1".

        """
        return self._split_heuristic_preprocess_naive_interleaving_strategy

    def copy(self):
        """Make a deep copy of the configuration"""
        # Temporarily unset references to Arch and Target for deepcopy
        arch, target = self.arch, self.target
        self.arch = self.target = None
        res = deepcopy(self)
        res.arch, res.target = arch, target
        self.arch, self.target = arch, target
        return res

    class SoftwarePipelining(NestedPrint, LockAttributes):
        """Subconfiguration for software pipelining"""

        @property
        def enabled(self):
            """Determines whether software pipelining should be enabled."""
            return self._enabled

        @property
        def unroll(self):
            """The number of times the loop body should be unrolled."""
            return self._unroll

        @property
        def pre_before_post(self):
            """If both early and late instructions are allowed, force late instructions
            of iteration N to come _before_ early instructions of iteration N+2."""
            return self._pre_before_post

        @property
        def allow_pre(self):
            """Allow 'early' instructions, that is, instructions that are pulled forward
            from iteration N+1 to iteration N. A typical example would be an early load.
            """
            return self._allow_pre

        @property
        def allow_post(self):
            """Allow 'late' instructions, that is, instructions that are deferred from
            iteration N to iteration N+1. A typical example would be a late store."""
            return self._allow_post

        @property
        def unknown_iteration_count(self):
            """Determines whether the number of iterations is statically known and larger
            than the number of exceptional iterations hoisted out by SLOTHY (at most 2).

            Set this to `True` if the loop can have any number of iterations."""
            return self._unknown_iteration_count

        @property
        def minimize_overlapping(self):
            """Set the objective to minimize the amount of iteration overlapping"""
            return self._minimize_overlapping

        @property
        def optimize_preamble(self):
            """Perform a separate optimization pass for the loop preamble."""
            return self._optimize_preamble

        @property
        def optimize_postamble(self):
            """Perform a separate optimization pass for the loop postamble."""
            return self._optimize_postamble

        @property
        def max_overlapping(self):
            """The maximum number of early or late instructions.
            `None` means that any number of early/late instructions is allowed."""
            return self._max_overlapping

        @property
        def min_overlapping(self):
            """The minimum number of early or late instructions.
            `None` means that any number of early/late instructions is allowed."""
            return self._min_overlapping

        @property
        def halving_heuristic(self):
            """Performance improvement heuristic: Rather than running a
            general software pipelining optimization, proceed in two steps:
            First, optimize loop body _without_ software pipelining. Then,
            split it as [A;B] and optimize [B;A]. The final result is then
            `A; optimized([B;A]); B`, with `A` being the preamble, `B` the
            postamble, and `optimized([B;A])` the loop kernel."""
            return self._halving_heuristic

        @property
        def halving_heuristic_periodic(self):
            """Variant of the halving heuristic: Consider loop boundary when
            optimizing [B;A] in the second step of the halving heuristic.
            This is computationally more expensive but avoids bottlenecks
            at the loop boundary that could otherwise ensue.

            This is only meaningful is the halving heuristic is enabled."""
            return self._halving_heuristic_periodic

        @property
        def halving_heuristic_split_only(self):
            """Cut-down version of halving-heuristic which only splits the loop
            `[A;B]` into `A; [B;A]; B` but does not perform optimizations."""
            return self._halving_heuristic_split_only

        @property
        def max_pre(self):
            """The maximum relative position (between 0 and 1) of an instruction
            that should be considered as a potential early instruction.
            For example, a value of 0.5 means that only instruction in the
            first half of the original loop body are considered as potential
            early instructions."""
            return self._max_pre

        def __init__(self):
            super().__init__()

            self.enabled = False
            self.unroll = 1
            self.pre_before_post = False
            self.allow_pre = True
            self.allow_post = False
            self.unknown_iteration_count = False
            self.minimize_overlapping = True
            self.optimize_preamble = True
            self.optimize_postamble = True
            self.max_overlapping = None
            self.min_overlapping = None
            self.halving_heuristic = False
            self.halving_heuristic_periodic = False
            self.halving_heuristic_split_only = False
            self.max_pre = 1.0

            self.lock()

        @enabled.setter
        def enabled(self, val):
            self._enabled = val

        @unroll.setter
        def unroll(self, val):
            self._unroll = val

        @pre_before_post.setter
        def pre_before_post(self, val):
            self._pre_before_post = val

        @allow_pre.setter
        def allow_pre(self, val):
            self._allow_pre = val

        @allow_post.setter
        def allow_post(self, val):
            self._allow_post = val

        @unknown_iteration_count.setter
        def unknown_iteration_count(self, val):
            self._unknown_iteration_count = val

        @minimize_overlapping.setter
        def minimize_overlapping(self, val):
            self._minimize_overlapping = val

        @optimize_preamble.setter
        def optimize_preamble(self, val):
            self._optimize_preamble = val

        @optimize_postamble.setter
        def optimize_postamble(self, val):
            self._optimize_postamble = val

        @max_overlapping.setter
        def max_overlapping(self, val):
            self._max_overlapping = val

        @min_overlapping.setter
        def min_overlapping(self, val):
            self._min_overlapping = val

        @halving_heuristic.setter
        def halving_heuristic(self, val):
            self._halving_heuristic = val

        @halving_heuristic_periodic.setter
        def halving_heuristic_periodic(self, val):
            self._halving_heuristic_periodic = val

        @halving_heuristic_split_only.setter
        def halving_heuristic_split_only(self, val):
            self._halving_heuristic_split_only = val

        @max_pre.setter
        def max_pre(self, val):
            self._max_pre = val

    class Constraints(NestedPrint, LockAttributes):
        """Subconfiguration for performance constraints"""

        @property
        def stalls_allowed(self):
            """The number of stalls allowed. Internally, this is the number of NOP
            instructions that SLOTHY introduces before attempting to find a stall-free
            version of the code (or, more precisely: a version matching all constraints,
            which may be weaker than stall-free).

            This is only meaningful for direct invocations to SlothyBase. You should not
            set this field when interfacing with Slothy."""
            if self.functional_only:
                return 0
            return self._stalls_allowed

        @property
        def stalls_maximum_attempt(self):
            """The maximum number of stalls to attempt before aborting the optimization
            and reporting it as infeasible.

            Note that since SLOTHY does not (yet?) introduce stack spills, a symbolic
            assembly snippet may be impossible to even concretize with architectural
            register names, regardless of the number of stalls one allows."""
            if self.functional_only:
                return 0
            return self._stalls_maximum_attempt

        @property
        def stalls_minimum_attempt(self):
            """The minimum number of stalls to attempt.

            This may be useful if it's known for external reasons that searching for
            optimiztions with less stalls is infeasible."""
            if self.functional_only:
                return 0
            return self._stalls_minimum_attempt

        @property
        def stalls_first_attempt(self):
            """The first number of stalls to attempt.

            This may be useful if it's known for external reasons that searching for
            optimization with less stalls is infeasible."""
            if self.functional_only:
                return 0
            return self._stalls_first_attempt

        @property
        def stalls_precision(self):
            """The precision of the binary search for the minimum number of stalls

            SLOTHY will stop searching if it can narrow down the minimum number
            of stalls to an interval of the length provided by this variable.
            In particular, a value of 1 means the true minimum if searched for."""
            if self.functional_only:
                return 1
            return self._stalls_precision

        @property
        def stalls_timeout_below_precision(self):
            """If this variable is set to a non-None value, SLOTHY does not abort
            optimization once binary search is operating on an interval smaller than
            the stall precision, but instead sets a different (typically smaller) timeout.
            """
            return self._stalls_timeout_below_precision

        @property
        def model_latencies(self):
            """Determines whether instruction latencies should be modelled.

            When set, SLOTHY will enforce that instructions are placed in accordance
            with the latency of the instructions that they depend on."""
            return self._model_latencies

        @property
        def model_functional_units(self):
            """Determines whether functional units should be modelled.

            When set, SLOTHY will enforce that instructions are placed in accordance
            with the presence and throughput of functional units that they depend on."""
            return self._model_functional_units

        @property
        def functional_only(self):
            """Limit Slothy to register renaming"""
            return (
                self.model_functional_units is False and self.model_latencies is False
            )

        @property
        def allow_reordering(self):
            """Allow Slothy to reorder instructions

            Disabling this may be useful to e.g. reassign register names
            in code that has already been scheduled properly."""
            return self._allow_reordering

        @property
        def allow_renaming(self):
            """Allow Slothy to rename registers

            Disabling this may be useful in conjunction with !allow_reordering
            in order to find the number of model violations in a piece of code."""
            return self._allow_renaming

        @property
        def allow_spills(self):
            """Allow Slothy to introduce stack spills

            When this option is enabled, Slothy will consider the introduction
            of stack spills to reduce register pressure.

            This option should only be disabled if it is known that the input
            assembly suffers from high register pressure. For example, this can
            be the case for symbolic input assembly."""
            return self._allow_spills

        @property
        def spill_type(self):
            """The type of spills to generate

            This is usually spilling to the stack, but other options may exist.
            For example, on Armv7-M microcontrollers it can be useful to spill
            from the GPR file to the FPR file.

            It is expected that this option is set as a dictionary, for example,
            with the key determining whether the spills are supposed to be to
            the stack or to the FPR file, and the value defining a starting
            index for the FPRs in the latter case.

            The exact influence of this option is architecture dependent. You
            should consult the `Spill` class in the target architecture model to
            understand the options."""
            if self._spill_type is None:
                return {}
            else:
                return self._spill_type

        @property
        def minimize_spills(self):
            """Minimize number of stack spills

            When this option is enabled, the Slothy will pass minimization of
            stack spills as the optimization objective to the solver.
            """
            return self._minimize_spills

        @property
        def max_displacement(self):
            """The maximum relative displacement of an instruction.

            Examples:

            * If set to 1, instructions can be reordered freely.
            * If set to 0, no reordering will happen.
            * If set to 0.5, an instruction will not move by more than N/2
              places between original and re-scheduled source code.

            This is an experimental feature for the purpose of speeding
            up otherwise intractable optimization tasks.

            .. warning::

                This only takes effect in straightline optimization (no software
                pipelining).
            """
            return self._max_displacement

        def __init__(self):
            super().__init__()

            # TODO: Move those to target specific configuration
            self.st_ld_hazard = True
            self.st_ld_hazard_ignore_scattergather = False
            self.st_ld_hazard_ignore_stack = False
            self.minimize_st_ld_hazards = False

            self._max_displacement = 1.0

            self.maximize_register_lifetimes = False
            self.minimize_spills = False
            self.move_stalls_to_top = False
            self.move_stalls_to_bottom = False
            self.minimize_register_usage = None
            self.minimize_use_of_extra_registers = None
            self.allow_extra_registers = {}

            self._stalls_allowed = 0
            self._stalls_maximum_attempt = 512
            self._stalls_minimum_attempt = 0
            self._stalls_precision = 0
            self._stalls_timeout_below_precision = None
            self._stalls_first_attempt = 0

            self._model_latencies = True
            self._model_functional_units = True
            self._allow_reordering = True
            self._allow_renaming = True
            self._allow_spills = False
            self._spill_type = None

            self.lock()

        @max_displacement.setter
        def max_displacement(self, val):
            self._max_displacement = val

        @stalls_allowed.setter
        def stalls_allowed(self, val):
            self._stalls_allowed = val

        @stalls_maximum_attempt.setter
        def stalls_maximum_attempt(self, val):
            self._stalls_maximum_attempt = val

        @stalls_minimum_attempt.setter
        def stalls_minimum_attempt(self, val):
            self._stalls_minimum_attempt = val

        @stalls_first_attempt.setter
        def stalls_first_attempt(self, val):
            self._stalls_first_attempt = val

        @stalls_precision.setter
        def stalls_precision(self, val):
            self._stalls_precision = val

        @stalls_timeout_below_precision.setter
        def stalls_timeout_below_precision(self, val):
            self._stalls_timeout_below_precision = val

        @model_latencies.setter
        def model_latencies(self, val):
            self._model_latencies = val

        @model_functional_units.setter
        def model_functional_units(self, val):
            self._model_functional_units = val

        @allow_reordering.setter
        def allow_reordering(self, val):
            self._allow_reordering = val

        @allow_renaming.setter
        def allow_renaming(self, val):
            self._allow_renaming = val

        @allow_spills.setter
        def allow_spills(self, val):
            self._allow_spills = val

        @spill_type.setter
        def spill_type(self, val):
            self._spill_type = val

        @minimize_spills.setter
        def minimize_spills(self, val):
            self._minimize_spills = val

        @functional_only.setter
        def functional_only(self, val):
            self._model_latencies = val is False
            self._model_functional_units = val is False

    class Hints(NestedPrint, LockAttributes):
        """Subconfiguration for solver hints"""

        @property
        def all_core(self):
            """When SW pipelining is used, hint that all instructions
            should be 'core' instructions (not early/late)."""
            return self._all_core

        @property
        def order_hint_orig_order(self):
            """Hint at using the initial program order for the
            program order variables."""
            return self._order_hint_orig_order

        @property
        def rename_hint_orig_rename(self):
            """Hint at using the initial program order for the
            program order variables."""
            return self._rename_hint_orig_rename

        @property
        def ext_bsearch_remember_successes(self):
            """When using an external binary search, hint previous successful
            optimization.

            See also Config.variable_size."""
            return self._ext_bsearch_remember_successes

        def __init__(self):
            super().__init__()

            self._all_core = True
            self._order_hint_orig_order = False
            self._rename_hint_orig_rename = False
            self._ext_bsearch_remember_successes = False

            self.lock()

        @all_core.setter
        def all_core(self, val):
            self._all_core = val

        @rename_hint_orig_rename.setter
        def rename_hint_orig_rename(self, val):
            self._rename_hint_orig_rename = val

        @order_hint_orig_order.setter
        def order_hint_orig_order(self, val):
            self._order_hint_orig_order = val

    def __init__(self, Arch, Target):
        super().__init__()

        self._arch = Arch
        self._target = Target

        self._sw_pipelining = Config.SoftwarePipelining()
        self._constraints = Config.Constraints()
        self._hints = Config.Hints()

        self._variable_size = False

        self._register_aliases = {}
        self._outputs = set()

        self._inputs_are_outputs = False
        self._rename_inputs = {"arch": "static", "symbolic": "any"}
        self._rename_outputs = {"arch": "static", "symbolic": "any"}

        self._locked_registers = []
        self._reserved_regs = None
        self._reserved_regs_are_locked = True

        self._selftest = True
        self._selftest_iterations = 10
        self._selftest_address_registers = None
        self._selftest_default_memory_size = 1024
        self._selfcheck = True
        self._selfcheck_failure_logfile = None
        self._allow_useless_instructions = False

        # TODO: This should be False by default, but this is a breaking
        # change that requires a lot of examples (where it _is_ safe to
        # apply address offset fixup) to be changed.
        self._unsafe_address_offset_fixup = True

        self._absorb_spills = True

        self._split_heuristic = False
        self._split_heuristic_region = [0.0, 1.0]
        self._split_heuristic_chunks = False
        self._split_heuristic_optimize_seam = 0
        self._split_heuristic_bottom_to_top = False
        self._split_heuristic_factor = 2
        self._split_heuristic_abort_cycle_at_high = None
        self._split_heuristic_abort_cycle_at_low = None
        self._split_heuristic_stepsize = None
        self._split_heuristic_repeat = 1
        self._split_heuristic_preprocess_naive_interleaving = False
        self._split_heuristic_preprocess_naive_interleaving_by_latency = False
        self._split_heuristic_preprocess_naive_interleaving_strategy = "depth"
        self._split_heuristic_estimate_performance = True

        self._compiler_binary = "gcc"
        self._compiler_include_paths = None

        self.keep_tags = True
        self.inherit_macro_comments = False
        self.ignore_tags = False

        self._do_address_fixup = True

        self._with_preprocessor = False
        self._llvm_mca_full = False
        self._llvm_mca_issue_width_overwrite = False
        self._with_llvm_mca_before = False
        self._with_llvm_mca_after = False
        self._max_solutions = 64
        self._timeout = None
        self._retry_timeout = None
        self._ignore_objective = False
        self._objective_precision = 0
        self._objective_lower_bound = None

        # Visualization
        self.indentation = 8
        self.visualize_reordering = True
        self.visualize_expected_performance = True
        self.visualize_show_old_code = False

        self.placeholder_char = "."
        self.early_char = "e"
        self.late_char = "l"
        self.core_char = "*"

        self.mirror_char = "~"

        self.solver_random_seed = 42

        # TODO: Document log_dir and log_model
        self.log_model = None
        self.log_model_only_on_success = True
        self.log_model_dir = "models"

        self.log_model_log_results = True
        self.log_model_results_file = "results.txt"
        if not os.path.exists(self.log_model_dir):
            os.makedirs(self.log_model_dir)

        self.lock()

    @arch.setter
    def arch(self, val):
        self._arch = val

    @target.setter
    def target(self, val):
        self._target = val

    @sw_pipelining.setter
    def sw_pipelining(self, val):
        self._sw_pipelining = val

    @constraints.setter
    def constraints(self, val):
        self._constraints = val

    @register_aliases.setter
    def register_aliases(self, val):
        self._register_aliases = val

    @outputs.setter
    def outputs(self, val):
        self._outputs = val

    @inputs_are_outputs.setter
    def inputs_are_outputs(self, val):
        self._inputs_are_outputs = val

    @rename_inputs.setter
    def rename_inputs(self, val):
        self._rename_inputs = val
        self._check_rename_config(self._rename_inputs)

    @rename_outputs.setter
    def rename_outputs(self, val):
        self._rename_outputs = val
        self._check_rename_config(self._rename_outputs)

    def _check_rename_config(self, lst):
        assert isinstance(lst, dict)

    @reserved_regs.setter
    def reserved_regs(self, val):
        self._reserved_regs = val

    @reserved_regs_are_locked.setter
    def reserved_regs_are_locked(self, val):
        self._reserved_regs_are_locked = val

    @variable_size.setter
    def variable_size(self, val):
        self._variable_size = val

    @selftest.setter
    def selftest(self, val):
        self._selftest = val

    @selftest_iterations.setter
    def selftest_iterations(self, val):
        self._selftest_iterations = val

    @selftest_address_registers.setter
    def selftest_address_registers(self, val):
        self._selftest_address_registers = val

    @selftest_default_memory_size.setter
    def selftest_default_memory_size(self, val):
        self._selftest_default_memory_size = val

    @selfcheck.setter
    def selfcheck(self, val):
        self._selfcheck = val

    @selfcheck_failure_logfile.setter
    def selfcheck_failure_logfile(self, val):
        self._selfcheck_failure_logfile = val

    @allow_useless_instructions.setter
    def allow_useless_instructions(self, val):
        self._allow_useless_instructions = val

    @unsafe_address_offset_fixup.setter
    def unsafe_address_offset_fixup(self, val):
        if val is False and self.arch.arch_name == "Arm_v81M":
            raise InvalidConfig("unsafe address offset fixup must be set for Armv8.1-M")
        self._unsafe_address_offset_fixup = val

    @locked_registers.setter
    def locked_registers(self, val):
        self._locked_registers = val

    @max_solutions.setter
    def max_solutions(self, val):
        self._max_solutions = val

    @with_preprocessor.setter
    def with_preprocessor(self, val):
        self._with_preprocessor = val

    @llvm_mca_issue_width_overwrite.setter
    def llvm_mca_issue_width_overwrite(self, val):
        self._llvm_mca_issue_width_overwrite = val

    @llvm_mca_full.setter
    def llvm_mca_full(self, val):
        self._llvm_mca_full = val

    @with_llvm_mca.setter
    def with_llvm_mca(self, val):
        self._with_llvm_mca_before = val
        self._with_llvm_mca_after = val

    @with_llvm_mca_after.setter
    def with_llvm_mca_after(self, val):
        self._with_llvm_mca_after = val

    @with_llvm_mca_before.setter
    def with_llvm_mca_before(self, val):
        self._with_llvm_mca_before = val

    @compiler_binary.setter
    def compiler_binary(self, val):
        self._compiler_binary = val

    @compiler_include_paths.setter
    def compiler_include_paths(self, val):
        self._compiler_include_paths = val

    @timeout.setter
    def timeout(self, val):
        self._timeout = val

    @retry_timeout.setter
    def retry_timeout(self, val):
        self._retry_timeout = val

    @keep_tags.setter
    def keep_tags(self, val):
        self._keep_tags = val

    @inherit_macro_comments.setter
    def inherit_macro_comments(self, val):
        self._inherit_macro_comments = val

    @ignore_tags.setter
    def ignore_tags(self, val):
        self._ignore_tags = val

    @do_address_fixup.setter
    def do_address_fixup(self, val):
        self._do_address_fixup = val

    @ignore_objective.setter
    def ignore_objective(self, val):
        self._ignore_objective = val

    @objective_precision.setter
    def objective_precision(self, val):
        self._objective_precision = val

    @objective_lower_bound.setter
    def objective_lower_bound(self, val):
        self._objective_lower_bound = val

    @absorb_spills.setter
    def absorb_spills(self, val):
        self._absorb_spills = val

    @split_heuristic.setter
    def split_heuristic(self, val):
        self._split_heuristic = val

    @split_heuristic_factor.setter
    def split_heuristic_factor(self, val):
        self._split_heuristic_factor = float(val)

    @split_heuristic_abort_cycle_at_high.setter
    def split_heuristic_abort_cycle_at_high(self, val):
        self._split_heuristic_abort_cycle_at_high = val

    @split_heuristic_abort_cycle_at_low.setter
    def split_heuristic_abort_cycle_at_low(self, val):
        self._split_heuristic_abort_cycle_at_low = val

    @split_heuristic_stepsize.setter
    def split_heuristic_stepsize(self, val):
        self._split_heuristic_stepsize = float(val)

    @split_heuristic_chunks.setter
    def split_heuristic_chunks(self, val):
        self._split_heuristic_chunks = val

    @split_heuristic_optimize_seam.setter
    def split_heuristic_optimize_seam(self, val):
        self._split_heuristic_optimize_seam = val

    @split_heuristic_bottom_to_top.setter
    def split_heuristic_bottom_to_top(self, val):
        self._split_heuristic_bottom_to_top = val

    @split_heuristic_region.setter
    def split_heuristic_region(self, val):
        self._split_heuristic_region = val

    @split_heuristic_preprocess_naive_interleaving.setter
    def split_heuristic_preprocess_naive_interleaving(self, val):
        self._split_heuristic_preprocess_naive_interleaving = val

    @split_heuristic_preprocess_naive_interleaving_by_latency.setter
    def split_heuristic_preprocess_naive_interleaving_by_latency(self, val):
        self._split_heuristic_preprocess_naive_interleaving_by_latency = val

    @split_heuristic_preprocess_naive_interleaving_strategy.setter
    def split_heuristic_preprocess_naive_interleaving_strategy(self, val):
        self._split_heuristic_preprocess_naive_interleaving_strategy = val

    @split_heuristic_estimate_performance.setter
    def split_heuristic_estimate_performance(self, val):
        self._split_heuristic_estimate_performance = val

    @split_heuristic_repeat.setter
    def split_heuristic_repeat(self, val):
        self._split_heuristic_repeat = val

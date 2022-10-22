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

from slothy.helper import LockAttributes, NestedPrint
from copy import deepcopy
import os

class Config(NestedPrint, LockAttributes):
    """Configuration for Slothy.

    This configuration object is used both for one-shot optimizations using
    SlothyBase, as well as stateful multi-pass optimizations using Slothy."""

    _default_split_heuristic = False
    _default_split_heuristic_factor = 2
    _default_split_heuristic_repeat = 1

    @property
    def Arch(self):
        """The module defining the underlying architecture used by Slothy.

        TODO: Add details on what exactly is assumed about this module."""
        return self._Arch

    @property
    def Target(self):
        """The module defining the target microarchitecture used by Slothy.

        TODO: Add details on what exactly is assumed about this module."""
        return self._Target

    @property
    def outputs(self):
        """List defining of architectural or symbolic registers that should
        be considered as outputs of the input snippet."""
        return self._outputs

    @property
    def reserved_regs(self):
        """Set of architectural registers _not_ available for register renaming.
        May be unset (None) to pick the default reserved registers for the target
        architecture. If set, it _overwrites_ the default reserved registers for
        the target architecture -- that is, if you still want the default reserved
        registers to remain reserved, you have to explicitly list them.

        In the lingo of inline assembly, this can be seen as the complement of
        the clobber list."""
        if self._reserved_regs != None:
            return self._reserved_regs
        return self._Arch.RegisterType.default_reserved()

    @property
    def register_aliases(self):
        """Dictionary mapping symbolic register names to architectural register names.
           When using Slothy, this can be indirectly populated by placing `.req` expressions
           in the input assembly. When using SlothyBase directly, this needs to be filled
           in by hand.

           This is always joined with a list of default aliases (such as lr mapping to r14)
           specified in the target architecture."""
        return { **self._register_aliases, **self._Arch.RegisterType.default_aliases() }

    def add_aliases(self, new_aliases):
        self._register_aliases = { **self._register_aliases, **new_aliases }

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

        The default value is { "symbolic": "any", "arch" : "static" } -- that is, architectural
        inputs are not renamed, while symbolic inputs are dynamically renamed.

        Examples:
        - Generally, unless you are prepared to modify surrounding code, you should have "arch" : "static",
          which will not rename inputs which already have architectural register names.
        - Config.rename_inputs = { "other" : "any" }
          This would rename _all_ inputs, regardless of whether they're symbolic or not. Thus, you'd likely
          need to modify surrounding code.
        - Config.rename_inputs = { "in" : "r0", "arch" : "static", "symbolic" : "any" }
          This would rename the symbolic input GPR 'in' to 'r0', keep all other inputs which already
          have an architectural name, while dynamically assigning suitable registers for symbolic inputs.

        In case of a successful optimization, the assignment of input registers to architectural
        registers is given by the dictionary Result.input_renaming.
        """
        self._check_rename_config(self._rename_inputs)
        return self._rename_inputs

    @property
    def rename_outputs(self):
        """A dictionary mapping output register names (symbolic or architectural) to their
        renaming configuration.

        Analogous to Config.rename_inputs.

        The default value is { "symbolic": "any", "arch" : "static" } -- that is, architectural
        outputs are not renamed, while symbolic outputs are dynamically renamed.

        In case of a successful optimization, the assignment of input registers to architectural
        registers is given by the dictionary Result.input_renaming.
        """
        self._check_rename_config(self._rename_outputs)
        return self._rename_outputs

    @property
    def inputs_are_outputs(self):
        """If set, any input in the assembly to be optimized (that is, every register
           that is used as an input before it has been written to) is treated as an output.
           _Moreover_, such simultaneous input-outputs are forced to reside in the same
           architectural register at the beginning and end of the snippet.

           This should usually be set when optimizing loops."""
        return self._inputs_are_outputs

    @property
    def locked_registers(self):
        """List of architectural registers that should not be renamed when they are
           used as output registers. Reserved registers are always treated as locked."""
        return self.reserved_regs.union(self._locked_registers)

    @property
    def sw_pipelining(self):
        """Subconfiguration for software pipelining. Enabled/Disabled
        via the sub-field sw_pipelining.enabled. See Config.SoftwarePipelining
        for more information."""
        return self._sw_pipelining

    @property
    def constraints(self):
        """Subconfiguration for constraints to be considered by SLOTHY,
        e.g. whether latencies or functional units are modelled.
        See Config.Constraints for more information."""
        return self._constraints

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
            raise Exception("Did you forget to set config.split_heuristic=True? "\
                            "Shouldn't read config.split_heuristic_factor otherwise.")
        return self._split_heuristic_factor

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
            raise Exception("Did you forget to set config.split_heuristic=True? "\
                            "Shouldn't read config.split_heuristic_repeat otherwise.")
        return self._split_heuristic_repeat

    def copy(self):
        """Make a deep copy of the configuration"""
        # Temporarily unset references to Arch and Target for deepcopy
        Arch, Target = self.Arch, self.Target
        self.Arch = self.Target = None
        res = deepcopy(self)
        res.Arch, res.Target   = Arch, Target
        self.Arch, self.Target = Arch, Target
        return res

    class SoftwarePipelining(NestedPrint, LockAttributes):
        """Subconfiguration for software pipelining"""

        _default_enabled = False
        _default_unroll = 1
        _default_pre_before_post = True
        _default_allow_pre = True
        _default_allow_post = False
        _default_minimize_overlapping = True
        _default_optimize_preamble = True
        _default_optimize_postamble = True
        _default_max_overlapping = None
        _default_min_overlapping = None
        _default_halving_heuristic = False
        _default_halving_heuristic_periodic = False
        _default_max_pre = 1.0

        @property
        def enabled(self):
            f"""Determines whether software pipelining should be enabled.
                Default: {Config.SoftwarePipelining._default_enabled}"""
            return self._enabled

        @property
        def unroll(self):
            f"""The number of times the loop body should be unrolled.
                Default: {Config.SoftwarePipelining._default_unroll}"""
            return self._unroll

        @property
        def pre_before_post(self):
            f"""If both early and late instructions are allowed, force late instructions of iteration N
                to come _before_ early instructions of iteration N+2.
                Default: {Config.SoftwarePipelining._default_pre_before_post}"""
            return self._pre_before_post

        @property
        def allow_pre(self):
            f"""Allow 'early' instructions, that is, instructions that are pulled forward from iteration N+1
                to iteration N. A typical example would be an early load.
                Default: {Config.SoftwarePipelining._default_allow_pre}"""
            return self._allow_pre

        @property
        def allow_post(self):
            f"""Allow 'late' instructions, that is, instructions that are deferred from iteration N
                to iteration N+1. A typical example would be a late store.
                Default: {Config.SoftwarePipelining._default_allow_post}"""
            return self._allow_post

        @property
        def minimize_overlapping(self):
            f"""Set the objective to minimize the amount of iteration overlapping
                Default: {Config.SoftwarePipelining._default_minimize_overlapping}"""
            return self._minimize_overlapping

        @property
        def optimize_preamble(self):
            f"""Perform a separate optimization pass for the loop preamble.
                Default: {Config.SoftwarePipelining._default_optimize_preamble}"""
            return self._optimize_preamble

        @property
        def optimize_postamble(self):
            f"""Perform a separate optimization pass for the loop postamble.
                Default: {Config.SoftwarePipelining._default_optimize_postamble}"""
            return self._optimize_postamble

        @property
        def max_overlapping(self):
            f"""The maximum number of early or late instructions.
                `None` means that any number of early/late instructions is allowed.
                Default: {Config.SoftwarePipelining._default_max_overlapping}"""
            return self._max_overlapping

        @property
        def min_overlapping(self):
            f"""The minimum number of early or late instructions.
                `None` means that any number of early/late instructions is allowed.
                Default: {Config.SoftwarePipelining._default_min_overlapping}"""
            return self._min_overlapping

        @property
        def halving_heuristic(self):
            f"""Performance improvement heuristic: Rather than running a
                general software pipelining optimization, proceed in two steps:
                First, optimize loop body _without_ software pipelining. Then,
                split it as [A;B] and optimize [B;A]. The final result is then
                `A; optimized([B;A]); B`, with `A` being the preamble, `B` the
                postamble, and `optimized([B;A])` the loop kernel.

                Default: {Config.SoftwarePipelining._default_halving_heuristic}"""
            return self._halving_heuristic

        @property
        def halving_heuristic_periodic(self):
            f"""Variant of the halving heuristic: Consider loop boundary when
                optimizing [B;A] in the second step of the halving heuristic.
                This is computationally more expensive but avoids bottlenecks
                at the loop boundary that could otherwise ensue.

                This is only meaningful is the halving heuristic is enabled.

                Default: {Config.SoftwarePipelining._default_halving_heuristic_periodic}"""
            return self._halving_heuristic_periodic

        @property
        def max_pre(self):
            f"""The maximum relative position (between 0 and 1) of an instruction
                that should be considered as a potential early instruction.
                For example, a value of 0.5 means that only instruction in the
                first half of the original loop body are considered as potential
                early instructions.

                Default: {Config.SoftwarePipelining._default_max_pre}"""
            return self._max_pre

        def __init__(self):
            super().__init__()

            self._enabled = Config.SoftwarePipelining._default_enabled
            self._unroll = Config.SoftwarePipelining._default_unroll
            self._pre_before_post = Config.SoftwarePipelining._default_pre_before_post
            self._allow_pre  = Config.SoftwarePipelining._default_allow_pre
            self._allow_post = Config.SoftwarePipelining._default_allow_post
            self._minimize_overlapping = Config.SoftwarePipelining._default_minimize_overlapping
            self._optimize_preamble = Config.SoftwarePipelining._default_optimize_preamble
            self._optimize_postamble = Config.SoftwarePipelining._default_optimize_postamble
            self._max_overlapping = Config.SoftwarePipelining._default_max_overlapping
            self._min_overlapping = Config.SoftwarePipelining._default_min_overlapping
            self._halving_heuristic = Config.SoftwarePipelining._default_halving_heuristic
            self._halving_heuristic_periodic = Config.SoftwarePipelining._default_halving_heuristic_periodic
            self._max_pre = Config.SoftwarePipelining._default_max_pre

            self.lock()

        @enabled.setter
        def enabled(self,val):
            self._enabled = val
        @unroll.setter
        def unroll(self,val):
            self._unroll = val
        @pre_before_post.setter
        def pre_before_post(self,val):
            self._pre_before_post = val
        @allow_pre.setter
        def allow_pre(self,val):
            self._allow_pre = val
        @allow_post.setter
        def allow_post(self,val):
            self._allow_post = val
        @minimize_overlapping.setter
        def minimize_overlapping(self,val):
            self._minimize_overlapping = val
        @optimize_preamble.setter
        def optimize_preamble(self,val):
            self._optimize_preamble = val
        @optimize_postamble.setter
        def optimize_postamble(self,val):
            self._optimize_postamble = val
        @max_overlapping.setter
        def max_overlapping(self,val):
            self._max_overlapping = val
        @min_overlapping.setter
        def min_overlapping(self,val):
            self._min_overlapping = val
        @halving_heuristic.setter
        def halving_heuristic(self,val):
            self._halving_heuristic = val
        @halving_heuristic_periodic.setter
        def halving_heuristic_periodic(self,val):
            self._halving_heuristic_periodic = val
        @max_pre.setter
        def max_pre(self,val):
            self._max_pre = val

    class Constraints(NestedPrint, LockAttributes):
        """Subconfiguration for performance constraints"""

        _default_stalls_allowed = 0
        _default_stalls_maximum_attempt = 128
        _default_stalls_minimum_attempt = 0
        _default_stalls_precision = 1
        _default_stalls_first_attempt = 0

        _default_max_relative_displacement = 1.0

        _default_model_latencies = True
        _default_model_functional_units = True
        _default_allow_reordering = True
        _default_allow_renaming = True

        @property
        def stalls_allowed(self):
            f"""The number of stalls allowed. Internally, this is the number of NOP
                instructions that SLOTHY introduces before attempting to find a stall-free
                version of the code (or, more precisely: a version matching all constraints,
                which may be weaker than stall-free).

                This is only meaningful for direct invocations to SlothyBase. You should not
                set this field when interfacing with Slothy.

                Default: {Config.Constraints._default_stalls_allowed}"""
            if self.functional_only:
                return 0
            return self._stalls_allowed

        @property
        def stalls_maximum_attempt(self):
            f"""The maximum number of stalls to attempt before aborting the optimization
                and reporting it as infeasible.

                Note that since SLOTHY does not (yet?) introduce stack spills, a symbolic
                assembly snippet may be impossible to even concretize with architectural
                register names, regardless of the number of stalls one allows.

                Default: {Config.Constraints._default_stalls_maximum_attempt}"""
            if self.functional_only:
                return 0
            return self._stalls_maximum_attempt

        @property
        def stalls_minimum_attempt(self):
            f"""The minimum number of stalls to attempt.

                This may be useful if it's known for external reasons that searching for
                optimiztions with less stalls is infeasible.

                Default: {Config.Constraints._default_stalls_minimum_attempt}"""
            if self.functional_only:
                return 0
            return self._stalls_minimum_attempt

        @property
        def stalls_first_attempt(self):
            f"""The first number of stalls to attempt.

                This may be useful if it's known for external reasons that searching for
                optimization with less stalls is infeasible.

                Default: {Config.Constraints._default_stalls_first_attempt}"""
            if self.functional_only:
                return 0
            return self._stalls_first_attempt

        @property
        def stalls_precision(self):
            f"""The precision of the binary search for the minimum number of stalls

                Slothy will stop searching if it can narrow down the minimum number
                of stalls to an interval of the length provided by this variable.
                In particular, a value of 1 means the true minimum if searched for.

                Default: {Config.Constraints._default_stalls_precision}"""
            if self.functional_only:
                return 1
            return self._stalls_precision

        @property
        def model_latencies(self):
            f"""Determines whether instruction latencies should be modelled.

                When set, SLOTHY will enforce that instructions are placed in accordance
                with the latency of the instructions that they depend on.

                Default: {Config.Constraints._default_model_latencies}"""
            return self._model_latencies

        @property
        def model_functional_units(self):
            f"""Determines whether functional units should be modelled.

                When set, SLOTHY will enforce that instructions are placed in accordance
                with the presence and throughput of functional units that they depend on.

                Default: {Config.Constraints._default_model_functional_units}"""
            return self._model_functional_units

        @property
        def functional_only(self):
            f"""Limit Slothy to register renaming

            Default: {(Config.Constraints._default_model_functional_units == False and
                       Config.Constraints._default_latencies == False)}"""
            return (self.model_functional_units == False and
                    self.model_latencies == False)

        @property
        def allow_reordering(self):
            f"""Allow Slothy to reorder instructions

            Disabling this may be useful to e.g. reassign register names
            in code that has already been scheduled properly.

            Default: {Config.Constraints._default_allow_reordering}"""
            return self._allow_reordering

        @property
        def allow_renaming(self):
            f"""Allow Slothy to rename registers

            Disabling this may be useful in conjunction with !allow_reordering
            in order to find the number of model violations in a piece of code.

            Default: {Config.Constraints._default_allow_renaming}"""
            return self._allow_renaming

        @property
        def max_relative_displacement(self):
            f"""The maximum relative displacement for instructions

            This is calculated relative to the instruction's original position,
            scaled according to the amount of gaps that are allowed in the code.

            NOTE: If software pipelining is enabled, this variable is only effective
                  for instructions that remain in their original iteration. In particular,
                  it does not block very far moving early instructions. This is not really
                  a deliberate choice but merely an implementation limitation for now.

            A value of None means that any relative displacement is allowed.

            Default: {Config.Constraints._default_max_relative_displacement}"""
            return self._max_relative_displacement

        def __init__(self):
            super().__init__()

            # TODO: Move those to target specific configuration
            self.st_ld_hazard = True
            self.st_ld_hazard_ignore_scattergather = True
            self.st_ld_hazard_ignore_stack = False
            self.minimize_st_ld_hazards = False

            self.minimize_register_usage = None
            self.minimize_use_of_extra_registers = None
            self.allow_extra_registers = {}

            self._max_relative_displacement = Config.Constraints._default_max_relative_displacement

            self._model_latencies = Config.Constraints._default_model_latencies
            self._model_functional_units = Config.Constraints._default_model_functional_units
            self._allow_reordering = Config.Constraints._default_allow_reordering
            self._allow_renaming = Config.Constraints._default_allow_renaming

            self._stalls_allowed = Config.Constraints._default_stalls_allowed
            self._stalls_maximum_attempt = Config.Constraints._default_stalls_maximum_attempt
            self._stalls_minimum_attempt = Config.Constraints._default_stalls_minimum_attempt
            self._stalls_first_attempt = Config.Constraints._default_stalls_first_attempt
            self._stalls_precision = Config.Constraints._default_stalls_precision

            self.lock()

        @stalls_allowed.setter
        def stalls_allowed(self,val):
            self._stalls_allowed = val
        @stalls_maximum_attempt.setter
        def stalls_maximum_attempt(self,val):
            self._stalls_maximum_attempt = val
        @stalls_minimum_attempt.setter
        def stalls_minimum_attempt(self,val):
            self._stalls_minimum_attempt = val
        @stalls_first_attempt.setter
        def stalls_first_attempt(self,val):
            self._stalls_first_attempt = val
        @stalls_precision.setter
        def stalls_precision(self,val):
            self._stalls_precision = val
        @max_relative_displacement.setter
        def max_relative_displacement(self,val):
            self._max_relative_displacement = val
        @model_latencies.setter
        def model_latencies(self,val):
            self._model_latencies = val
        @model_functional_units.setter
        def model_functional_units(self,val):
            self._model_functional_units = val
        @allow_reordering.setter
        def allow_reordering(self,val):
            self._allow_reordering = val
        @allow_renaming.setter
        def allow_renaming(self,val):
            self._allow_renaming = val
        @functional_only.setter
        def functional_only(self,val):
            if not val:
                return
            self._model_latencies = False
            self._model_functional_units = False

    def __init__(self, Arch, Target):
        super().__init__()

        self._Arch = Arch
        self._Target = Target

        self._sw_pipelining = Config.SoftwarePipelining()
        self._constraints = Config.Constraints()

        # NOTE: - This saves us from having to do a binary search for the minimum
        #         number of stalls ourselves, but it seems to slow down the tool
        #         significantly!
        #       - It also disables the minimization of instruction overlapping
        #         in loop mode.
        #
        # Rather keep it off for now...
        self.variable_size = False

        self._register_aliases = {}
        self._outputs = []

        self._inputs_are_outputs = False
        self._rename_inputs  = { "arch" : "static", "symbolic" : "any" }
        self._rename_outputs = { "arch" : "static", "symbolic" : "any" }

        self._locked_registers = []
        self._reserved_regs = None

        self.selfcheck = True # Check that that resulting code reordering constitutes an isomorphism of computation flow graphs

        self.allow_useless_instructions = False

        self._split_heuristic = Config._default_split_heuristic
        self._split_heuristic_factor = Config._default_split_heuristic_factor
        self._split_heuristic_repeat = Config._default_split_heuristic_repeat

        # Visualization
        self.indentation = 8
        self.visualize_reordering = True
        self.placeholder_char = '.'

        self.typing_hints = {} # Dictionary of 'typing hints', assigning symbolic names to register types
                               # in case the register type is ambiguous.

        self.solver_random_seed = 42

        self.log_dir = "logs/"
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir)

        self.lock()

    @Arch.setter
    def Arch(self,val):
        self._Arch = val
    @Target.setter
    def Target(self,val):
        self._Target = val
    @sw_pipelining.setter
    def sw_pipelining(self,val):
        self._sw_pipelining = val
    @constraints.setter
    def constraints(self,val):
        self._constraints = val
    @register_aliases.setter
    def register_aliases(self,val):
        self._register_aliases = val
    @outputs.setter
    def outputs(self,val):
        self._outputs = val
    @inputs_are_outputs.setter
    def inputs_are_outputs(self,val):
        self._inputs_are_outputs = val
    @rename_inputs.setter
    def rename_inputs(self,val):
        self._rename_inputs = val
        self._check_rename_config(self._rename_inputs)
    @rename_outputs.setter
    def rename_outputs(self,val):
        self._rename_outputs = val
        self._check_rename_config(self._rename_outputs)
    def _check_rename_config(self, lst):
        assert isinstance(lst,dict)
    @reserved_regs.setter
    def reserved_regs(self,val):
        self._reserved_regs = val
    @locked_registers.setter
    def locked_registers(self,val):
        self._locked_registers = val
    @split_heuristic.setter
    def split_heuristic(self, val):
        self._split_heuristic = val
    @split_heuristic_factor.setter
    def split_heuristic_factor(self, val):
        self._split_heuristic_factor = val
    @split_heuristic_repeat.setter
    def split_heuristic_repeat(self, val):
        self._split_heuristic_repeat = val

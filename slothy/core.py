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

import logging, re, ortools, math
from ortools.sat.python import cp_model
from types import SimpleNamespace
from copy import deepcopy

from slothy.config import Config
from slothy.helper import LockAttributes, NestedPrint

from slothy.dataflow import DataFlowGraph as DFG
from slothy.dataflow import Config as DFGConfig
from slothy.dataflow import InstructionOutput, InstructionInOut
from slothy.dataflow import VirtualOutputInstruction, VirtualInputInstruction

class Result(LockAttributes):
    """The results of a one-shot SLOTHY optimization run"""

    @property
    def orig_code(self):
        """Optimization input: Source code"""
        return self._orig_code
    @property
    def orig_inputs(self):
        """The list of input registers in the _original_ source code."""
        return list(self.input_renamings.keys())
    @property
    def orig_outputs(self):
        """The list of output registers in the _original_ source code."""
        return list(self.output_renamings.keys())

    @property
    def reordering(self):
        """The reordering permutation linking original and optimized source code"""
        return self._reordering
    @property
    def reordering_inv(self):
        """The inverse reordering permutation linking optimized and original source code"""
        return self._reordering_inv

    @property
    def code(self):
        """The optimized source code"""
        return self._code
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
    @property
    def output_renamings(self):
        """Dictionary mapping original output names to architectural register names
        used in the optimized source code. See also Config.rename_outputs."""
        return self._output_renamings
    @property
    def kernel(self):
        """When using software pipelining, the loop kernel of the optimized loop."""
        self._require_sw_pipelining()
        return self._kernel
    @property
    def kernel_input_output(self):
        """When using software pipelining, the dependencies between successive loop iterations.

        This is useful if you want to further optimize the preamble (and perhaps some code preceding it),
        because the kernel dependencies are the output of the preamble."""
        self._require_sw_pipelining()
        return self._kernel_input_output
    @property
    def preamble(self):
        """When using software pipelining, the preamble to the loop kernel of the optimized loop."""
        self._require_sw_pipelining()
        return self._preamble
    @property
    def postamble(self):
        """When using software pipelining, the postamble to the loop kernel of the optimized loop."""
        self._require_sw_pipelining()
        return self._postamble
    @property
    def num_exceptional_iterations(self):
        """The number of loop iterations jointly covered by the loop preamble and postamble. In other words,
        the amount by which the iteration count for the optimized loop kernel is lower than the original
        iteration count."""
        self._require_sw_pipelining()
        return self._num_exceptional_iterations

    @property
    def config(self):
        """The configuration that was used for the optimization."""
        return self._config

    @property
    def success(self):
        """Whether the optimization was successful"""
        self._require_valid()
        return self._success
    def __bool__(self):
        return self.success

    def _require_sw_pipelining(self):
        if not self.config.sw_pipelining.enabled:
            raise Exception("Asking for preamble in result of SLOTHY run without SW pipelining")
    def _require_valid(self):
        if not self._valid:
            raise Exception("Querying not-yet-populated result object")

    def __init__(self, config):
        super().__init__()

        self._config = config.copy()

        self._orig_code = None
        self._code = None
        self._input_renamings = None
        self._output_renamings = None
        self._kernel = None
        self._preamble = []
        self._postamble = []
        self._reordering = None
        self._reordering_inv = None
        self._reordering_with_bubbles = None
        self._reordering_with_bubbles_inv = None
        self._program_padded_size = None
        self._program_padded_size_half = None
        self._cycle_padded_size = None

        self._valid = False
        self._success = False

        self._input = None
        self._kernel_input_output = None

        self._num_pre = self._num_post = self._num_prepost = None
        self._num_exceptional_iterations = None

        self.orig_code_visualized = None

        self.lock()

class SlothyBase(LockAttributes):
    """Stateless core of SLOTHY --
    [S]uper ([L]azy) [O]ptimization of [T]ricky [H]andwritten assembl[Y]

    This class is the technical heart of the package: It implements the
    conversion of a software optimization problem into a constraint solving
    problem which can then be passed to an external constraint solver.
    We use Google OR-Tools.

    SlothyBase is agnostic of the target architecture and microarchitecture,
    which are specified at construction time."""

    # In contrast to its more convenient descendant Slothy, SlothyBase is _stateless_:
    # It optimizes one piece of source code a time via SlothyBase.optimize()

    @property
    def Arch(self):
        """The underlying architecture used by SLOTHY, as a read-only reference
        to the corresponding field in the configuration."""
        return self.config.Arch
    @property
    def Target(self):
        """The underlying microarchitecture used by SLOTHY, as a read-only reference
        to the corresponding field in the configuration."""
        return self.config.Target

    @property
    def result(self):
        return self._result

    @property
    def success(self):
        return self._result.success

    def __init__(self, Arch, Target, *, logger=None, config=None):
        """Create a stateless SLOTHY instance

           args:
               Arch: A model of the underlying architecture.
             Target: A model of the underlying microarchitecture.
             logger: The logger to be used.
                     If omitted, a child of the root logger will be used.
             config: The configuration to use.
                     If omitted, the default configuration will be used.
        """
        super().__init__()
        self.config = config if config != None else Config(Arch, Target)
        self.logger = logger if logger != None else logging.getLogger("slothy")
        self.logger.input  = self.logger.getChild("input")
        self.logger.config = self.logger.getChild("config")
        self.logger.result = self.logger.getChild("result")
        self._reset()
        self.lock() # Can't do this yet, there are still lots of temporaries being used

    def _reset(self):
        self._num_optimization_passes = 0
        self._result = Result(self.config)
        self._model = SimpleNamespace()

    def optimize(self, source, prefix=None, suffix=None, log_model=None):
        self._reset()
        self._usage_check()

        self.config.log(self.logger.getChild("config").debug)
        if self.config.variable_size:
            self.logger.warning("Consider disabling config.variable_size for better performance?")

        # Setup
        self._load_source(source, prefix=prefix, suffix=suffix)
        self._init_external_model_and_solver()
        self._init_model_internals()

        if not self.config.constraints.functional_only:
            self._model.cycle_horizon = 2 * (self._model._tree.num_nodes + 10)
            self._model.program_horizon = self._model.cycle_horizon * self.config.Target.issue_rate
        else:
            self._model.program_horizon = 2 * (self._model._tree.num_nodes + 10)

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
        self._add_constraints_N_issue()
        self._add_constraints_dependency_order()
        self._add_constraints_latencies()
        self._add_constraints_register_renaming()
        self._add_constraints_register_usage()
        self._add_constraints_functional_units()
        self._add_constraints_loop_periodic()
        self._add_constraints_locked_positions()
        self._add_constraints_misc()
        # - Objective
        self._add_objective()
        # - Export (optional)
        self._export_model(log_model)

        # Do the actual work
        self.logger.info("Invoking external constraint solver...")
        self.result._success = self._solve()
        self.result._valid = True
        if not self.success:
            return False

        self._extract_result()
        return True

    def _load_source(self, source, prefix=None, suffix=None):

        if self.config.sw_pipelining.enabled and \
           ( prefix != None or suffix != None ):
            raise Exception("Invalid arguments")

        def split_if_str(s):
            s = s if s != None else []
            if isinstance(s,str):
                return s.splitlines()
            return s
        def strip_comments(sl):
            return [ s.split("//")[0].strip() for s in sl ]
        def unroll_and_pad(source):
            if self.config.sw_pipelining.enabled:
                source = source * self.config.sw_pipelining.unroll
            source = prefix + source + suffix
            source = '\n'.join(source)
            return source

        source = strip_comments(split_if_str(source))
        prefix = strip_comments(split_if_str(prefix))
        suffix = strip_comments(split_if_str(suffix))
        prefix_len = len(prefix)
        suffix_len = len(suffix)

        self._dump("Source code", source, self.logger.input)
        self._dump("Prefix", prefix, self.logger.input)
        self._dump("Prefix", suffix, self.logger.input)

        source = unroll_and_pad(source)
        self._result._orig_code = source.splitlines()

        # Convert source code to computational flow graph
        if self.config.sw_pipelining.enabled:
            source = source + '\n' + source

        self._model._tree = DFG(source, self.logger.getChild("dataflow"),
                                DFGConfig(self.config))

        def lock_instruction(t):
            t.is_locked = True
        [ lock_instruction(t) for t in self._model._tree.nodes[:prefix_len]  if prefix_len > 0 ]
        [ lock_instruction(t) for t in self._model._tree.nodes[-suffix_len:] if suffix_len > 0 ]

        self._set_avail_renaming_registers()
        self._restrict_input_output_renaming()
        self._backup_original_code()

    def _init_model_internals(self):
        self._model.intervals_for_unit = { k : [] for k in self.Target.ExecutionUnit }
        self._model.register_usages = {}
        self._model.register_usage_vars = {}

    def _usage_check(self):
        if self._num_optimization_passes > 0:
            raise Exception("At the moment, SlothyBase should be used for one-shot optimizations")
        self._num_optimization_passes += 1

    def _restrict_input_output_renaming(self):
        # In principle, inputs and outputs can be arbitrarily renamed thanks to the
        # virtual instructions introduced for them. Disabling input/output renaming
        # fits into this framework nicely in the form of input/output argument restrictions,
        # which we have for 'real' instructions anyhow.

        # We might need to assign some fixed registers to global inputs/outputs which haven't
        # been given an architectural register name. We use the following array to track which
        # onces remain available
        avail_renaming_regs = deepcopy(self._model.avail_renaming_regs)

        def is_architectural(reg,ty):
            return reg in self._model.architectural_registers[ty]

        def static_renaming(conf_val, t):
            """Checks whether a register should be statically renamed at model
            construction time. If so, and if a static assignment has already been
            made, it will return the assignment as the second return value.
            Otherwise, the second return value is None, and the static assignment
            will be picked afterwards (we can't do it immediately because we try
            to avoid collisions with fixed static assignments)."""
            reg, ty = t.inst.orig_reg, t.inst.orig_ty
            is_arch = is_architectural(reg, ty)
            arch_str = "arch" if is_arch else "symbolic"

            if not isinstance(conf_val, dict):
                raise Exception(f"Couldn't make sense of renaming configuration {conf_val}")

            # Try to look up register in dictionary. There are three ways
            # it can be specified: Directly by name, via the "arch/symbolic"
            # group, or via the "any" group.

            val = None
            val = val if val != None else conf_val.get( reg,       None )
            val = val if val != None else conf_val.get( arch_str , None )
            val = val if val != None else conf_val.get( "other"  , None )

            if val == None:
                raise Exception( f"Register {reg} not present in renaming config {conf_val}")

            # There are three choices for the value:
            # - "static" for static assignment, which will statically assign a value
            #   for symbolic register names, and keep the name of architectural registers.
            # - "any" for dynamic, unrestricted assignment
            # - an architectural register name
            if val == "static":
                canonical_static_assignment = reg if is_arch else None
                return True, canonical_static_assignment
            elif val == "any":
                return False, None
            else:
                if not is_architectural(val,ty):
                    raise Exception(f"Invalid renaming configuration {val} for {reg}")
                return True, val

        def tag_input(t):
            static, val = static_renaming(self.config.rename_inputs, t)
            return SimpleNamespace(**{"node": t, "static" : static, "reg" : val,
                                      "name" : t.inst.orig_reg, "ty" : t.inst.orig_ty })
        def tag_output(t):
            static, val = static_renaming(self.config.rename_outputs, t)
            return SimpleNamespace(**{"node": t, "static" : static, "reg" : val,
                                      "name" : t.inst.orig_reg, "ty" : t.inst.orig_ty })

        inputs_tagged  = list(map(tag_input, self._model._tree.nodes_input))
        outputs_tagged = list(map(tag_output, self._model._tree.nodes_output))

        for ty in self.Arch.RegisterType:
            regs_assigned = set(v.reg for v in inputs_tagged + outputs_tagged
                                if v.ty == ty and v.static == True and v.reg != None)
            regs = regs_assigned.intersection(avail_renaming_regs[ty])
            [ avail_renaming_regs[ty].remove(r) for r in regs ]

        class OutOfRegisters(Exception):
            pass
        def get_fresh_renaming_reg(ty):
            if len(avail_renaming_regs[ty]) == 0:
                raise OutOfRegisters
            return avail_renaming_regs[ty].pop(-1)

        try:
            # Now go through all statically renamed inputs and outputs which have not yet been assigned
            for v in inputs_tagged + outputs_tagged:
                if v.static == False or v.reg != None:
                    continue
                v.reg = get_fresh_renaming_reg(v.ty)
        except OutOfRegisters as e:
            self.logger.error(
                """Ran out of registers trying to _statically_ assign architectural registers
                for input and outputs of the snippet. You should consider enabling register
                renaming for input and output, by setting config.rename_{inputs,outputs}.
                Alternatively, you may fix input and output registers by hand yourself.""")
            raise e

        # Now actually enforce renamings
        for t in inputs_tagged:
            if not t.static:
                continue
            self.logger.input.debug(f"Statically assign global input {t.name} to register {t.reg}")
            t.node.inst.args_out_restrictions = [[t.reg]]
        for t in outputs_tagged:
            if not t.static:
                continue
            self.logger.input.debug(f"Statically assign global output {t.name} to register {t.reg}")
            t.node.inst.args_in_restrictions = [[t.reg]]

    def _resolve_aliases(self, rl, allocs=None):
        if allocs == None:
            allocs = self.config.register_aliases
        if not isinstance(rl,list):
            return allocs.get(rl,rl)
        else:
            return [ allocs.get(r,r) for r in rl ]

    def _set_avail_renaming_registers(self):
        self._model.avail_renaming_regs = {}
        self._model.architectural_registers = {}
        for ty in self.Arch.RegisterType:
            regs  = self.Arch.RegisterType.list_registers(ty, only_normal=True)
            regs += self.Arch.RegisterType.list_registers(ty, only_extra=True)\
                              [:self.config.constraints.allow_extra_registers.get(ty,0)]
            self._model.architectural_registers[ty] = regs
            self._model.avail_renaming_regs[ty] = [ r for r in regs
                                                    if r not in self.config.reserved_regs]

        self._dump_avail_renaming_registers()

    def _dump_avail_renaming_registers(self):
        self.logger.input.debug("Registers available for renaming")
        for ty in self.Arch.RegisterType:
            self.logger.input.debug(f"- {ty} available: {self._model.avail_renaming_regs[ty]}")

    def _add_register_usage(self, reg_name, reg_ty, var, interval):

        def dic_set_default(dic, key, default):
            if key not in dic.keys():
                dic[key] = default

        reg_name = self._resolve_aliases(reg_name)
        # At this stage, we should only operate with _architectural_ register names
        assert reg_name in self.Arch.RegisterType.list_registers(reg_ty)

        dic_set_default( self._model.register_usages, reg_name, [])
        self._model.register_usages[reg_name].append(interval)

        if var == None:
            return

        dic_set_default( self._model.register_usage_vars, reg_name, [])
        self._model.register_usage_vars[reg_name].append(var)

    def _backup_original_code(self):
        for t in self._model._tree.nodes:
            t.inst_orig = deepcopy(t.inst)

    def _dump(self, name, s, logger=None):
        logger = logger if logger else self.logger
        if isinstance(s,str):
            s = s.splitlines()
        if len(s) == 0:
            return
        logger.debug(f"Dump: {name}")
        for l in s:
            logger.debug(f"> {l}")

    class _cp_sat_solution_cb(cp_model.CpSolverSolutionCallback):
        def __init__(self, logger, objective_description):
            cp_model.CpSolverSolutionCallback.__init__(self)
            self.__solution_count = 0
            self.__logger = logger
            self.__objective_desc = objective_description
        def on_solution_callback(self):
            self.__solution_count += 1
            if self.__objective_desc:
                self.__logger.info(f"Found {self.__solution_count} solutions so far... objective value = {self.ObjectiveValue()} ({self.__objective_desc})")
        def solution_count(self):
            return self.__solution_count

    def _extract_result(self):
        self._extract_positions()
        self._extract_register_renamings()
        self._extract_input_output_renaming()

        self._post_optimize_fixup()

        # We implement post-only = pre-only, but need to rename [e,*] -> [*,l]
        if self.config.sw_pipelining.enabled            and \
           self.config.sw_pipelining.allow_post == True and \
           self.config.sw_pipelining.allow_pre  == False:
            for t in self._model._tree.nodes:
                t.pre, t.core, t.post = False, t.pre, t.core

        status_str = self._model.cp_solver.StatusName(self._model.cp_model.status)
        self.logger.info(f"{status_str}, wall time: {self._model.cp_solver.WallTime()}")

        self._extract_code()
        self._selfcheck()

    def _extract_positions(self):
        Value = self._model.cp_solver.Value

        nodes = self._model._tree.nodes
        if self.config.sw_pipelining.enabled:
            nodes_low = self._model._tree.nodes_low

        # Extract length and instructions positions program order
        self._result._program_padded_size = Value(self._model.program_padded_size)
        if self.config.sw_pipelining.enabled:
            self._result._program_padded_size_half = Value(self._model.program_padded_size_half)

        reordering_with_bubbles = { t.orig_pos : Value(t.program_start_var) for t in nodes }
        reordering_with_bubbles_inv = { v : k for k,v in reordering_with_bubbles.items() }

        self.logger.debug("Preliminary reordering (including bubbles)")
        self.logger.debug(reordering_with_bubbles)

        # Detect and remove bubbles
        reordering_pre_arr = list(reordering_with_bubbles.values())
        reordering_pre_arr.sort()

        reordering = { i : reordering_pre_arr.index(reordering_with_bubbles[i])
                       for i in reordering_with_bubbles.keys() }
        reordering_inv = { v : k for k,v in reordering.items() }

        self.result._reordering_with_bubbles = reordering_with_bubbles
        self.result._reordering_with_bubbles_inv = reordering_with_bubbles_inv
        self.result._reordering_inv = reordering_inv
        self.result._reordering = reordering

        assert set(reordering.values())     == set(range(len(nodes)))
        assert set(reordering.keys())       == set(range(len(nodes)))
        assert set(reordering_inv.values()) == set(range(len(nodes)))
        assert set(reordering_inv.keys())   == set(range(len(nodes)))

        self.logger.debug("Code reordering (without bubbles)")
        self.logger.debug(reordering)

        for t in nodes:
            t.real_pos         = reordering[t.orig_pos]
            t.real_pos_program = reordering_with_bubbles[t.orig_pos]
            t.displacement     = abs(t.real_pos_program - t.orig_pos_scaled)
            t.relative_displacement = t.displacement / self._result._program_padded_size

        # Extract length and instruction positions in cycles (according to the model)
        if not self.config.constraints.functional_only:
            self._result._cycle_padded_size = Value(self._model.cycle_padded_size)
            for t in nodes:
                t.real_pos_cycle = t.real_pos_program // self.Target.issue_rate

        if self.config.sw_pipelining.enabled:

            # When doing SW pipelining, adjust positions for early and late instructions
            for t in nodes:

                t.pre  = Value(t.pre_var)
                t.post = Value(t.post_var)
                t.core = Value(t.core_var)
                if t.pre and t.orig_pos < len(self._model._tree.nodes_low):
                    t.real_pos         -= len(self._model._tree.nodes)
                    t.real_pos_program -= self._result._program_padded_size
                if t.post and t.orig_pos >= len(self._model._tree.nodes_low):
                    t.real_pos         += len(self._model._tree.nodes)
                    t.real_pos_program += self._result._program_padded_size

                t.displacement     = abs(t.real_pos_program - t.orig_pos_scaled)
                t.relative_displacement = t.displacement / self._result._program_padded_size_half

                if not self.config.constraints.functional_only:
                    t.real_pos_cycle   = t.real_pos_program // self.Target.issue_rate

            self.result._num_pre     = sum([t.pre  for t in nodes_low])
            self.result._num_post    = sum([t.post for t in nodes_low])
            self.result._num_prepost = self.result._num_pre + self.result._num_post

            if self.config.sw_pipelining.allow_pre:
                self.logger.info(f"Number of early instructions: {self._result._num_pre}")
            if self.config.sw_pipelining.allow_post:
                self.logger.info(f"Number of late instructions: {self._result._num_post}")

            # If there are either (a) only early instructions, or (b) only late instructions,
            # the loop preamble and postamble make up for 1 full loop iteration. If there are
            # both early and late instructions, then the preamble and postamble make up for
            # 2 full loop iterations.
            self._result._num_exceptional_iterations = sum(
                [ ( self._result._num_pre > 0 ) or  ( self._result._num_post > 0 ),
                  ( self._result._num_pre > 0 ) and ( self._result._num_post > 0 ) ])
            self.logger.debug(f"Number of exceptional iterations: "\
                              "{self._result.num_exceptional_iterations}")

        if len(nodes) == 0:
            return

        # Print information about displacement
        relative_displacements_all = [t.relative_displacement for t in nodes]
        max_relative_displacement_all = max(relative_displacements_all,default=0)
        total_relative_displacement_all = sum(relative_displacements_all)
        avg_relative_displacement_all = total_relative_displacement_all / len(nodes)

        self.logger.info("Statistics about instruction displacement:")
        self.logger.info(f"* Average relative displacement (all): {avg_relative_displacement_all}")
        self.logger.info(f"* Maximum relative displacement (all): "
                         f"{max_relative_displacement_all}")

        if self.config.sw_pipelining.enabled:
            relative_displacements_core = [t.relative_displacement for t in nodes if t.core]
            max_relative_displacement_core = max(relative_displacements_core,default=0)
            total_relative_displacement_core = sum(relative_displacements_core)
            avg_relative_displacement_core = total_relative_displacement_core / len(nodes)
            self.logger.info(f"* Average relative displacement (core): {avg_relative_displacement_core}")
            self.logger.info(f"* Maximum relative displacement (core): "
                             f"{max_relative_displacement_core}")

    def _extract_input_output_renaming(self):
        self._result._input_renamings  = { n.inst.orig_reg : n.inst.args_out[0] \
                                           for n in self._model._tree.nodes_input }
        self._result._output_renamings = { n.inst.orig_reg : n.inst.args_in[0]  \
                                           for n in self._model._tree.nodes_output }
        def _dump_renaming(name,dic):
            for k,v in ((k,v) for k,v in dic.items() if k != v):
                self.logger.debug(f"{name} {k} renamed to {v}")
        _dump_renaming("Input",  self._result.input_renamings)
        _dump_renaming("Output", self._result.output_renamings)

        self._result._input = list(self._model._tree.inputs)

    def _extract_register_renamings(self):
        # From a dictionary with Boolean variables as values, extract the single
        # key for whose variable is set to True by the solver.
        def _extract_true_key(var_dict):
            true_keys = [ k for k,v in var_dict.items() if self._model.cp_solver.Value(v) ]
            assert len(true_keys) == 1
            return true_keys[0]

        # Extract register renamings and modify instructions accordingly
        for t in self._model._tree.nodes_all:
            t.inst.args_out    = [ _extract_true_key(vars) for vars in t.alloc_out_var    ]
            t.inst.args_in     = [ _extract_true_key(vars) for vars in t.alloc_in_var     ]
            t.inst.args_in_out = [ _extract_true_key(vars) for vars in t.alloc_in_out_var ]
            def _dump_renaming(name,lst):
                for idx, reg in enumerate(lst):
                    self.logger.debug(f"{name} {idx} of '{t.inst}' renamed to {reg}")
            _dump_renaming("Output",       t.inst.args_out)
            _dump_renaming("Input",        t.inst.args_in)
            _dump_renaming("Input/Output", t.inst.args_in_out)
            self.logger.debug(f"New instruction: {t.inst}")

    def _selfcheck(self):
        ### TODO: Rewrite this so it only depends on the result object
        if not self.config.selfcheck:
            self.logger.warning("Skipping self check!")
            return

        result = self._result
        log = self.logger.getChild("selfcheck")

        # Check that the computation flow graphs for input and output are indeed isomorphic
        # via the instruction ordering found by the tool.
        if self.config.sw_pipelining.enabled:
            iterations = 3
            old_source = '\n'.join(result.orig_code * iterations)

            assert iterations > result.num_exceptional_iterations
            kernel_copies = iterations - result.num_exceptional_iterations

            new_source = '\n'.join(result.preamble                 +
                                   ( result.code * kernel_copies ) +
                                   result.postamble )

            # Extract reordering for fixed number of iterations from periodic reordering
            num_lines = len(self._model._tree.nodes_low)
            reordering = { t.orig_pos + k * num_lines : k * num_lines + t.real_pos \
                           for t in self._model._tree.nodes_low for k in range(iterations) }
            # For the first and last iteration, there will be gaps in the positioning -- remove those
            reordering_sorted = list(reordering.items())
            reordering_sorted.sort(key=lambda x: x[1])
            reordering_sorted = [ x[0] for x in reordering_sorted ]
            reordering = { i : pos for (pos,i) in enumerate(reordering_sorted) }
        else:
            old_source = '\n'.join(result.orig_code)
            new_source = '\n'.join(result.code)
            reordering = result.reordering
            iterations = 1

        # Add renaming for inputs and outputs to permutation
        for old, new in result.input_renamings.items():
            reordering[f"input_{old}"] = f"input_{new}"
        for old, new in result.output_renamings.items():
            reordering[f"output_{old}"] = f"output_{new}"

        reordering_inv = { j : i for (i,j) in reordering.items() }

        def apply_reordering(x):
            src,dst,lbl=x
            if not src in reordering.keys():
                raise Exception(f"Source ID {src} not in remapping {reordering.items()}")
            if not dst in reordering:
                raise Exception(f"Destination ID {dst} not in remapping {reordering.items()}")
            return (reordering[src], reordering[dst], lbl)

        dfg_old_log = log.getChild("dfg_old")
        dfg_new_log = log.getChild("dfg_new")
        self._dump(f"Old code ({iterations} copies)", old_source, dfg_old_log)
        self._dump(f"New code ({iterations} copies)", new_source, dfg_new_log)

        tree_old = DFG(old_source, dfg_old_log,
                       DFGConfig(self.config, outputs=result.orig_outputs))
        tree_new = DFG(new_source, dfg_new_log,
                       DFGConfig(self.config, outputs=result.outputs))
        edges_old = tree_old.edges()
        edges_new = tree_new.edges()

        edges_old_remapped = set(map(apply_reordering, edges_old))
        if edges_old_remapped != edges_new:
            log.error("Isomophism between computation flow graphs: FAIL!")

            self._dump("old code", old_source, log)
            self._dump("new code", new_source, log)

            new_not_old = edges_new.difference(edges_old_remapped)
            old_not_new = edges_old_remapped.difference(edges_new)

            for (src_idx,dst_idx,lbl) in new_not_old:
                src = tree_new.nodes_by_id[src_idx]
                dst = tree_new.nodes_by_id[dst_idx]
                log.error(f"New ({src})---{lbl}--->{dst} not present in old graph")

            for (src_idx,dst_idx,lbl) in old_not_new:
                src = tree_old.nodes_by_id[src_idx]
                dst = tree_old.nodes_by_id[dst_idx]
                log.error(f"Old ({src})---{lbl}--->{dst} not present in new graph")

            log.error("Isomorphism between computation flow graphs: FAIL!")
            raise Exception("Isomorphism between computation flow graphs: FAIL!")

        log.debug("Isomophism between computation flow graphs: OK!")
        log.info("OK!")

    def _extract_kernel_input_output(self):
        dfg_log = self.logger.getChild("kernel_input_output")
        self._result._kernel_input_output = list(\
            DFG(self._result.code, dfg_log,
                DFGConfig(self.config,inputs_are_outputs=True)).inputs)

    def _get_reordered_instructions(self, filter_func=None):
        """Finds pairs of instructions passing filter_func which have been swapped."""

        if filter_func == None:
            filter_func = lambda _: True

        # Find instances where t0 came _after_ t1 initially, but now it comes before
        for t0 in self._model._tree.nodes:
            for t1 in self._model._tree.nodes:
                if not filter_func(t0) or not filter_func(t1):
                    continue
                if t0.orig_pos < t1.orig_pos and t0.real_pos > t1.real_pos:
                    self.logger.debug(f"Instructions {t0.orig_pos} ({t0.inst}) and {t1.orig_pos} ({t1.inst}) got reordered")
                    yield t0,t1

    def _post_optimize_fixup(self):
        """Adjusts immediate offsets for reordered load/store instructions.

        We don't model load/store instructions with address increments as modifying the address register; doing so would
        severely limit the ability to perform software pipelining, which often requires load instructions for one iteration
        to be moved propr to store instructions in the previous iteration. Instead, we model them as keeping the address
        register unmodified, thereby allowing free reordering, and adjust address offsets afterwards.

        See section "Address modifications in "Towards perfect CRYSTALS in Helium", https://eprint.iacr.org/2022/1303"""

        for t in self._model._tree.nodes:
            t.inst_tmp = deepcopy(t.inst)
        if self.config.sw_pipelining.enabled    and \
           self.config.sw_pipelining.allow_post and \
           self.config.sw_pipelining.allow_pre:
            self.logger.warning("============================================   WARNING   ============================================")
            self.logger.warning("Post-optimization fixup of address offsets is only implemented if config.sw_pipelining.post is set!")
            self.logger.warning("Skipping this -- you have to fix the address offsets manually")
            self.logger.warning("=====================================================================================================")
            return
        def inst_changes_addr(inst):
            return inst.increment is not None
        # Search for instances of VLDR,VSTR that have been swapped
        for t0,t1 in self._get_reordered_instructions():
            if not t0.inst_tmp.is_load_store_instruction():
                continue
            if not t1.inst_tmp.is_load_store_instruction():
                continue
            if not t0.inst_tmp.addr == t1.inst_tmp.addr:
                continue
            if inst_changes_addr(t0.inst_tmp) and inst_changes_addr(t1.inst_tmp):
                self.logger.warning("============================================   WARNING   ============================================")
                self.logger.warning(f"Cannot handle reordering of two instructions ({t0.inst_tmp} and {t1.inst_tmp}) ")
                self.logger.warning( "which both want to modify the same address")
                self.logger.warning( "Skipping this -- you have to fix the address offsets manually")
                self.logger.warning("=====================================================================================================")
                return
            if not inst_changes_addr(t0.inst_tmp) and not inst_changes_addr(t1.inst_tmp):
                continue
            if inst_changes_addr(t0.inst_tmp):
                # t1 gets reordered before t0, which changes the address
                # Adjust t1's address accordingly
                if t1.inst_tmp.pre_index:
                    t1.inst_tmp.pre_index = f"(({t1.inst_tmp.pre_index}) + ({t0.inst_tmp.increment}))"
                else:
                    t1.inst_tmp.pre_index = f"{t0.inst_tmp.increment}"
            else:
                # t0 gets reordered after t1, which changes the address
                # Adjust t0's address accordingly
                if t0.inst_tmp.pre_index:
                    t0.inst_tmp.pre_index = f"(({t0.inst_tmp.pre_index}) - ({t1.inst_tmp.increment}))"
                else:
                    t0.inst_tmp.pre_index = f"-({t1.inst_tmp.increment})"

    def _extract_code(self):

        def visualize_reordering():
            max_early = max_late = 0
            if self.config.sw_pipelining.enabled:
                num_lines = self._result._program_padded_size_half
                nodes = self._model._tree.nodes_low
            else:
                num_lines = self._result._program_padded_size
                nodes = self._model._tree.nodes
            if num_lines == 0:
                return

            fixlen = max(map(lambda t: len(str(t.inst_orig)),nodes)) + 8
            min_pos = min([t.real_pos            for t in nodes])
            width   = max([t.real_pos - min_pos  for t in nodes])

            if not self.config.constraints.functional_only:
                min_pos_cycle = min([t.real_pos_cycle                  for t in nodes])
                width_cycle   = max([t.real_pos_cycle - min_pos_cycle  for t in nodes])

            yield ""
            yield "// original source code"
            for t_pos, t in enumerate(nodes):
                pos = t.real_pos - min_pos
                assert t.orig_pos == t_pos
                c = '*'
                if self.config.sw_pipelining.enabled and t.pre:
                    c = 'e'
                elif self.config.sw_pipelining.enabled and t.post:
                    c = 'l'
                else:
                    c = '*'

                d = self.config.placeholder_char
                t_comment       = d * pos + c + d * (width - pos)

                if not self.config.constraints.functional_only and self.Target.issue_rate > 1:
                    cycle_pos = t.real_pos_cycle - min_pos_cycle
                    t_comment_cycle = "|| " + (d * cycle_pos + c + d * (width_cycle - cycle_pos))
                else:
                    t_comment_cycle = ""

                yield f"// {str(t.inst_orig):{fixlen-3}s} // {t_comment} {t_comment_cycle}"

            yield ""

        self._result.orig_code_visualized = list(visualize_reordering())

        def add_indentation(src):
            indentation = ' ' * self.config.indentation
            src = [ indentation + s for s in src ]

        def get_code(filter_func=None, pre=False, post=False):

            if len(self._model._tree.nodes) == 0:
                return

            fixlen = max(map(lambda t: len(str(t.inst_tmp)),self._model._tree.nodes)) + 8

            def get_code_line(line_no, lines, nodes):
                d = self.config.placeholder_char

                if line_no not in self._result._reordering_with_bubbles_inv.keys():
                    inst_str = "// gap"
                    if self.config.visualize_reordering:
                        yield f"{inst_str:{fixlen}s} // {d * nodes}"
                    else:
                        yield f"{inst_str}"
                    return

                t = self._model._tree.nodes[self._result._reordering_with_bubbles_inv[line_no]]
                if filter_func and not filter_func(t):
                    return
                inst_str = str(t.inst_tmp)

                if self.config.visualize_reordering:
                    t_pos = t.orig_pos
                    if t_pos >= nodes:
                        t_pos -= nodes
                    c = "*"
                    if self.config.sw_pipelining.enabled:
                        if t.pre:
                            c = 'e'
                        elif t.post:
                            c = 'l'
                    t_comment = d * (t_pos) + c + d * (nodes - t_pos - 1)
                    yield f"{inst_str:{fixlen}s} // {t_comment}"
                else:
                    yield f"{inst_str}"

            base  = 0
            if self.config.sw_pipelining.enabled:
                lines = self._result._program_padded_size_half
                nodes = len(self._model._tree.nodes_low)
            else:
                lines = self._result._program_padded_size
                nodes = len(self._model._tree.nodes)

            if pre or post:
                base = self._result._program_padded_size_half

            for i in range(base,base+lines):
                yield from get_code_line(i, lines, nodes)

        if self.config.sw_pipelining.enabled:
            # Preamble for first iteration
            if self._result._num_pre > 0:
                self._result._preamble = list(get_code(filter_func=lambda t: t.pre,
                                                                   pre=True))
            # First iteration -- no late instructions yet
            if self._result._num_post > 0:
                self._result._preamble  += list(get_code(lambda t: not t.post))
            # Last iteration -- no early instructions anymore
            if self._result._num_pre > 0:
                self._result._postamble += list(get_code(lambda t: not t.pre,
                                                                     post=True))
            # Postamble for last iteration
            if self._result._num_post > 0:
                self._result._postamble += list(get_code(lambda t: t.post, post=True))

            # All other iterations
            self._result._kernel = list(get_code())
            self._result._code = self._result._kernel
            self._extract_kernel_input_output()

            log = self.logger.result.getChild("sw_pipelining")
            log.debug(f"Kernel dependencies: {self._result._kernel_input_output}")

            self._dump("Preamble",  self._result.preamble, log)
            self._dump("Kernel",    self._result.kernel, log)
            self._dump("Postamble", self._result.postamble, log)

            add_indentation(self._result.preamble)
            add_indentation(self._result.kernel)
            add_indentation(self._result.postamble)

        else:
            self._result._code = list(get_code())

            self.logger.result.debug("Optimized code")
            for s in self._result.code:
                self.logger.result.debug("> " + s.strip())

            add_indentation(self._result.code)

        if self.config.visualize_reordering:
            self._result._code += self._result.orig_code_visualized

    def _list_dependencies(self, include_virtual_instructions=True ):
        self.logger.debug("Iterating over node dependencies")
        yield from filter( lambda cp: include_virtual_instructions or \
                                      (cp[0] in self._model._tree.nodes and cp[1].src in self._model._tree.nodes),
                           self._model._tree.iter_dependencies() )

    def _add_path_constraint( self, consumer, producer, cb ):
        """Add model constraint cb() relating to the pair of producer-consumer instructions
           Outside of loop mode, this ignores producer and consumer, and just adds cb().
           In loop mode, however, the condition has to be omitted in two cases:

           - The producer belongs to the early part of the first iteration,
             but the consumer doesn't.

             In this case, the early part of the first iteration is actually the
             early part of the third iteration.

           - The consumer belongs to the late part of the second iteration,
             but the producer doesn't.
        """

        # This is a bit fiddly to implement since ortools doesn't seem to allow
        # conditioning a constraint on a disjunction.
        #
        # We circumvent the problem by just adding two copies of the same constraint,
        # constraining each on one of the clauses of the disjunction:

        # We ignore constraints in fixed parts of the code (but not at the boundary)
        if consumer.is_locked and producer.is_locked:
            return

        ct0 = cb()
        if not self.config.sw_pipelining.enabled or \
           producer.is_virtual() or consumer.is_virtual():
            return
        ct1 = cb()
        if producer in self._model._tree.nodes_low:
            ct0.OnlyEnforceIf([producer.pre_var, consumer.pre_var])
            ct1.OnlyEnforceIf([producer.pre_var.Not(), consumer.pre_var.Not()])
        elif producer in self._model._tree.nodes_high:
            ct0.OnlyEnforceIf([producer.post_var, consumer.post_var])
            ct1.OnlyEnforceIf([producer.post_var.Not(), consumer.post_var.Not()])

    # ================================================================
    #                  VARIABLES (Instruction scheduling)            #
    # ================================================================

    def _add_variables_scheduling(self):
        """Create variables for start, end and duration of every instruction,
           and assign the duration intervals to the units that run the instructions"""

        if self.config.variable_size:
            raise Exception("This feature is broken")
            if self.config.Target.issue_rate > 1:
                raise Exception("This isn't yet implemented")
            excess = min(10,self._model._tree.num_nodes // 4)
            self._model.program_padded_size = self._NewIntVar(self._model._tree.num_nodes,
                                                              self._model._tree.num_nodes + excess,
                                                              "padded size")
        else:
            pfactor = 2 if self.config.sw_pipelining.enabled else 1
            pfactor = self.Target.issue_rate * pfactor

            p_pad = pfactor * ( math.ceil(self._model._tree.num_nodes / pfactor) +
                                 self.config.constraints.stalls_allowed )

            self._model.program_padded_size_const = p_pad
            self._model.program_padded_size = self._NewConstant(p_pad)
            self._model.program_padded_size_half = self._NewConstant(p_pad//2)

            if not self.config.constraints.functional_only:
                c_pad = p_pad // self.Target.issue_rate
                self._model.cycle_padded_size = self._NewConstant(c_pad)

        for t in self._model._tree.nodes_input:
            t.program_start_var = self._NewConstant(-1)
            # xxx_end_var is only used to model the occupancy of functional units;
            # since virtual instructions don't occupy those, we don't need the an end var
        for t in self._model._tree.nodes_output:
            t.program_start_var = self._model.program_padded_size
            # as above: no xxx_end_var needed

        # Add variables for positions in program order
        for t in self._model._tree.nodes:
            t.program_start_var = self._NewIntVar(0,self._model.program_horizon,
                                                  f"{t.varname()}_program_start")

            # We also measure the displacement of an instruction relative to its
            # original position (scaled to the padded program length).
            # By default, no constraints are associated with this, but the amount
            # of displacement is an interesting measure for how much reordering was
            # still necessary, and may perhaps drive heuristics.
            rel_pos = t.orig_pos / len(self._model._tree.nodes)
            t.orig_pos_scaled = int( rel_pos * self._model.program_padded_size_const)
            t.program_displacement = self._NewIntVar(0,self._model.program_horizon,
                                                     f"{t.varname()}_program_displacement")

        if self.config.constraints.functional_only:
            return

        # Add variables for positions in cycles, and "issue slots"
        # E.g. if we're modeling dual-issuing, we have program_pos = cycle_pos * 2 + slot,
        # and slot is in either 0 or 1.
        for t in self._model._tree.nodes:
            t.cycle_start_var = self._NewIntVar(0,self._model.cycle_horizon,
                                                f"{t.varname()}_cycle_start")
            t.cycle_end_var   = self._NewIntVar(0,self._model.cycle_horizon,
                                                f"{t.varname()}_cycle_end")
            t.slot_var = self._NewIntVar(0, self.Target.issue_rate-1)

    # ================================================================
    #                  VARIABLES (Functional units)                  #
    # ================================================================

    def _add_variables_functional_units(self):
        if not self.config.constraints.model_functional_units:
            return

        for t in self._model._tree.nodes:
            cycles_unit_occupied = self.Target.get_inverse_throughput(t.inst)
            units = self.Target.get_units(t.inst)
            if len(units) == 1:
                t.exec_unit_choices = None
                unit = units[0]
                t.exec = self._NewIntervalVar(t.cycle_start_var, cycles_unit_occupied,
                                              t.cycle_end_var, "")
                self._model.intervals_for_unit[unit].append(t.exec)
            else:
                t.unique_unit = False
                t.exec_unit_choices = {}
                for unit in units:
                    unit_var = self._NewBoolVar("[{t.inst}].unit_choice.{unit}")
                    t.exec_unit_choices[unit] = unit_var
                    t.exec = self._NewOptionalIntervalVar(t.cycle_start_var,
                                                          cycles_unit_occupied,
                                                          t.cycle_end_var,
                                                          unit_var,
                                                          f"{t.varname}_usage_{unit}")
                    self._model.intervals_for_unit[unit].append(t.exec)

    # ================================================================
    #                  VARIABLES (Dependency tracking)               #
    # ================================================================

    def _add_variables_dependencies(self):

        def make_var(name=""):
            return self._NewIntVar(0,self._model.program_horizon, name)

        for t in self._model._tree.nodes_all:
            t.out_lifetime_end        = [ make_var(f"{t.varname()}_out_{i}_lifetime_end") for i in range(t.inst.num_out) ]
            t.out_lifetime_duration   = [ make_var(f"{t.varname()}_out_{i}_lifetime_dur") for i in range(t.inst.num_out) ]
            t.inout_lifetime_end      = [ make_var(f"{t.varname()}_inout_{i}_lifetime_end") for i in range(t.inst.num_in_out) ]
            t.inout_lifetime_duration = [ make_var(f"{t.varname()}_inout_{i}_lifetime_dur") for i in range(t.inst.num_in_out) ]

    # ================================================================
    #                  VARIABLES (Register allocation)               #
    # ================================================================

    def _add_variables_register_renaming(self):
        """Add boolean variables indicating if an instruction uses a certain output register"""

        self.logger.debug("Adding variables for register allocation...")

        if self.config.constraints.minimize_register_usage is not None:
            ty = self.config.constraints.minimize_register_usage
            regs = self.Arch.RegisterType.list_registers(ty)
            self._register_used = { reg : self._NewBoolVar(f"reg_used[reg]") for reg in regs }

        outputs = { ty : [] for ty in self.Arch.RegisterType }

        # Create variables for register renaming

        for t in self._model._tree.nodes_all:
            t.alloc_out_var = []
            self.logger.debug(f"Create register renaming variables for {t}")

            # Iterate through output registers of current instruction
            for arg_ty, arg_out, restrictions in zip(t.inst.arg_types_out, t.inst.args_out,
                                                     t.inst.args_out_restrictions):

                self.logger.debug( f"- Output {arg_out} ({arg_ty})")

                # Locked output register aren't renamed, and neither are outputs of locked instructions.
                self.logger.debug( f"Locked registers: {self.config.locked_registers}")
                is_locked = arg_out in self.config.locked_registers
                if t.is_locked or is_locked or not self.config.constraints.allow_renaming:
                    self.logger.input.debug(f"Instruction {t.inst.write()} has its output locked")
                    if is_locked:
                        self.logger.input.debug(f"Reason: Register is locked")
                    if not self.config.constraints.allow_renaming:
                        self.logger.input.debug(f"Reason: Register renaming has been disabled")
                    if t.is_locked:
                        self.logger.input.debug(f"Reason: Instruction is locked")
                    candidates = [arg_out]
                else:
                    candidates = list(set(self._model.avail_renaming_regs[arg_ty]))

                if restrictions is not None:
                    self.logger.debug(f"{t.id} ({t.inst}): Output restriction {restrictions}")
                    candidates_restricted = [ c for c in candidates if c in restrictions ]
                else:
                    candidates_restricted = candidates
                if len(candidates_restricted) == 0:
                    self.logger.error(f"No suitable output registers exist for {t.inst}?")
                    self.logger.error(f"Original candidates: {candidates}")
                    self.logger.error(f"Restricted candidates: {candidates_restricted}")
                    self.logger.error(f"Restrictions: {restrictions}")
                    raise Exception()

                self.logger.input.debug(f"Registers available for renaming of [{t.inst}].{arg_out} ({t.orig_pos})")
                self.logger.input.debug(candidates_restricted)

                var_dict = { out_reg : self._NewBoolVar(f"ALLOC({t.inst})({out_reg})")
                             for out_reg in candidates_restricted }
                t.alloc_out_var.append(var_dict)

        # Create intervals tracking the usage of registers
        for t in self._model._tree.nodes_all:
            self.logger.debug(f"Create register usage intervals for {t}")
            for arg_ty, arg_out, var_dict, dur_var, end_var in zip(t.inst.arg_types_out,
                                                                   t.inst.args_out,
                                                                   t.alloc_out_var,
                                                                   t.out_lifetime_duration,
                                                                   t.out_lifetime_end):
                for reg, var in var_dict.items():
                    usage_interval = self._NewOptionalIntervalVar(t.program_start_var, dur_var, end_var,
                                                                  var, f"USAGE({t.inst})({reg})<{var}>")
                    self._add_register_usage(reg, arg_ty, var, usage_interval)

        # Input and InOut arguments
        # This has to come _after_ the previous loop establishing register renaming variables.
        for t in self._model._tree.nodes_all:

            # For outputs that are also inputs, we cannot perform register
            # renaming, but are bound by the choice of register when the
            # input was originally created.
            #
            # Trace back input to its origin and store a reference to the
            # register renaming variables used therein.

            t.alloc_in_out_var = []
            for arg_ty, inout, dur_var, end_var in zip(t.inst.arg_types_in_out,
                                                       t.src_in_out,
                                                       t.inout_lifetime_duration,
                                                       t.inout_lifetime_end):
                inout = inout.reduce()
                t.alloc_in_out_var.append(inout.src.alloc_out_var[inout.idx])

                for out_reg, usage_var in t.alloc_in_out_var[-1].items():
                    ival = self._NewOptionalIntervalVar(t.program_start_var,
                                                        dur_var, end_var,
                                                        usage_var, "")
                    self._add_register_usage(out_reg, arg_ty, usage_var, ival)

            # For convenience, also add references to the variables governing the
            # register renaming for input arguments.
            t.alloc_in_var = []
            for arg_in in t.src_in:
                arg_in = arg_in.reduce()
                t.alloc_in_var.append(arg_in.src.alloc_out_var[arg_in.idx])

        # Input/Output arguments
        # We may have constraints on allowed configurations of input/output arguments,
        # such as VST4{0-3} requiring consecutive input registers.
        # Here we add variables for those constraints

        for t in self._model._tree.nodes_all:
            t.alloc_in_combinations_vars  = []
            t.alloc_out_combinations_vars = []

            def add_arg_combination_vars( combinations, vars, name ):
                if combinations == None:
                    return
                for idx_lst, valid_combinations in combinations:
                    self.logger.debug(f"{t.orig_pos} ({t.inst.mnemonic}): Adding variables for {name} "\
                                      f"{idx_lst, valid_combinations}")
                    vars.append([])
                    for combination in valid_combinations:
                        self.logger.debug(f"{t.orig_pos} ({t.inst.mnemonic}): Adding variable for combination "\
                                          f"{combination}")
                        vars[-1].append(self._NewBoolVar(""))

            add_arg_combination_vars( t.inst.args_in_combinations,
                                      t.alloc_in_combinations_vars,
                                      "input" )
            add_arg_combination_vars( t.inst.args_out_combinations,
                                      t.alloc_out_combinations_vars,
                                      "output" )

    # ================================================================
    #                  VARIABLES (Loop rolling)                      #
    # ================================================================

    def _add_variables_loop_rolling(self):
        if not self.config.sw_pipelining.enabled:
            return

        for t in self._model._tree.nodes:
            # In loop mode, every instruction is marked as pre, core, or post,
            # depending on whether it's executed already in the previous iteration
            # (e.g. an early load), in the original iteration, or the following
            # iteration (e.g. a late store).
            t.pre_var  = self._NewBoolVar("")
            t.core_var = self._NewBoolVar("")
            t.post_var = self._NewBoolVar("")

    # ================================================================
    #                  CONSTRAINTS (Lifetime bounds)                 #
    # ================================================================

    def _add_constraints_lifetime_bounds(self):
        count = 0
        for t in self._model._tree.nodes_all:
            # if count == 0:
            #     continue
            self.logger.debug(f"Adding lifetime constraints for {t.id}({t.inst})")
            # Add lifetime constraints for outputs and inouts
            self._add_constraints_lifetime_bounds_single(t)
            count += 1

    def _add_constraints_lifetime_bounds_single(self, t):
        def _add_lifetime_constraints(deps_list, end_list, dur_list):
            for deps, end_var, dur_var in zip(deps_list, end_list, dur_list):
                # Make sure the output argument is considered 'used' for at least
                # one instruction. Otherwise, instructions producing outputs that
                # are never used would be able to overwrite life registers.
                self._Add( end_var > t.program_start_var )

                # For every instruction depending on the output, add a lifetime bound
                for d in deps:
                    self._add_path_constraint( d, t, lambda: self._Add( end_var >= d.program_start_var ) )
        # Add bounds for all output and inout arguments
        _add_lifetime_constraints(t.dst_out, t.out_lifetime_end, t.out_lifetime_duration)
        _add_lifetime_constraints(t.dst_in_out, t.inout_lifetime_end, t.inout_lifetime_duration)

    # ================================================================
    #                  CONSTRAINTS (Register allocation)             #
    # ================================================================

    def _add_constraints_register_renaming(self):

        if self.config.constraints.minimize_register_usage is not None:
            ty = self.config.constraints.minimize_register_usage
            for reg in self.Arch.RegisterType.list_registers(ty):
                arr = self._model.register_usage_vars.get(reg,[])
                if len(arr) > 0:
                    self._model.AddMaxEquality(self._register_used[reg], arr)
                else:
                    self._Add(self._register_used[reg] == False)

        # Ensure that outputs are unambiguous
        for t in self._model._tree.nodes_all:
            self.logger.debug(f"Ensure unambiguous register renaming for {t.inst}")
            for dic in t.alloc_out_var:
                self._AddExactlyOne(dic.values())

        def force_allocation_variant( alloc_dict, combinations, combination_vars, name ):
            if combinations == None:
                return
            for (idx_lst, valid_combinations), vars in zip(combinations, combination_vars):
                self.logger.debug(f"{t.orig_pos} ({t.inst.mnemonic}): Enforcing {name} restriction "\
                                  f"{idx_lst, valid_combinations}")
                self._AddExactlyOne(vars)
                for combination, var in zip(valid_combinations, vars):
                    self.logger.debug(f"{t.orig_pos} ({t.inst.mnemonic}): Consider combination {combination}")
                    for idx, reg in zip(idx_lst, combination):
                        self._AddImplication(var,alloc_dict[idx].get(reg,False))

        def forbid_renaming_collision_single( var_dicA, var_dicB ):
            for (reg,varA) in var_dicA.items():
                varB = var_dicB.get(reg,None)
                if var is None:
                    continue
                self._AddImplication(varA,varB.Not())

        def forbid_renaming_collision_many( idx_pairs, var_dicA, var_dicB ):
            if idx_pairs == None:
                return
            for (idxA, idxB) in idx_pairs:
                forbid_renaming_collision_single( var_dicA[idxA], var_dicB[idxB] )

        def force_renaming_collision( var_dicA, var_dicB ):
            for (reg,varA) in var_dicA.items():
                varB = var_dicB.get(reg,None)
                if varB is None:
                    continue
                self._AddImplication(varA,varB)

        def force_allocation_restriction_single(valid_allocs, var_dict):
            for k,v in var_dict.items():
                if k not in valid_allocs:
                    self._Add(v == False)

        def force_allocation_restriction_many(restriction_lst, var_dict_lst):
            for r, v in zip(restriction_lst, var_dict_lst):
                if r == None:
                    continue
                force_allocation_restriction_single(r,v)

        for t in self._model._tree.nodes_all:
            # Enforce input and output _combination_ restrictions
            force_allocation_variant( t.alloc_out_var, t.inst.args_out_combinations,
                                      t.alloc_out_combinations_vars, "output" )
            force_allocation_variant( t.alloc_in_var,  t.inst.args_in_combinations,
                                      t.alloc_in_combinations_vars, "input" )
            # Enforce individual input argument restrictions (for outputs this has already
            # been done at the time when we created the allocation variables).
            force_allocation_restriction_many(t.inst.args_in_restrictions, t.alloc_in_var)
            # Enforce exclusivity of arguments
            forbid_renaming_collision_many( t.inst.args_in_out_different,
                                            t.alloc_out_var,
                                            t.alloc_in_var )
            forbid_renaming_collision_many( t.inst.args_in_inout_different,
                                            t.alloc_in_out_var,
                                            t.alloc_in_var )

        if self.config.inputs_are_outputs:
            def find_out_node(t_in):
                c = list(filter(lambda t: t.inst.orig_reg == t_in.inst.orig_reg,
                                self._model._tree.nodes_output))
                if len(c) == 0:
                    raise Exception(f"Could not find matching output for input {t_in.inst.orig_reg}")
                elif len(c) > 1:
                    raise Exception(f"Found multiple matching output nodes for input {t_in.inst.orig_reg}: {c}")
                return c[0]
            for t_in in self._model._tree.nodes_input:
                t_out = find_out_node(t_in)
                force_renaming_collision( t_in.alloc_out_var[0], t_out.alloc_in_var[0] )

    # ================================================================
    #                 CONSTRAINTS (Software pipelining)              #
    # ================================================================

    def _add_constraints_loop_optimization(self):

        if not self.config.sw_pipelining.enabled:
            return

        if self.config.sw_pipelining.max_overlapping != None:
            prepostlist = [ t.core_var.Not() for t in self._model._tree.nodes_low ]
            self._Add( cp_model.LinearExpr.Sum(prepostlist) <=
                             self.config.sw_pipelining.max_overlapping )

        if self.config.sw_pipelining.min_overlapping != None:
            prepostlist = [ t.core_var.Not() for t in self._model._tree.nodes_low ]
            self._Add( cp_model.LinearExpr.Sum(prepostlist) >=
                             self.config.sw_pipelining.min_overlapping )

        for t in self._model._tree.nodes:

            self._AddExactlyOne([t.pre_var, t.post_var, t.core_var])

            # Not sure if those hints are any helpful
            self._AddHint(t.core_var,True)
            self._AddHint(t.pre_var, False)
            self._AddHint(t.post_var,False)

            # Allow early instructions only in a certain range
            num = len(self._model._tree.nodes_low)
            pos = t.orig_pos if t.orig_pos < num else t.orig_pos - num
            relpos = pos / num
            if relpos < 1 and relpos > self.config.sw_pipelining.max_pre:
                self._Add( t.pre_var == False )

            if not self.config.sw_pipelining.allow_pre and \
               not self.config.sw_pipelining.allow_post:
                self._Add(t.post_var == False)
                self._Add(t.pre_var  == False)
            elif not self.config.sw_pipelining.allow_pre:
                # Post-only is the same as pre-only after renaming.
                self._Add(t.post_var == False)
            elif not self.config.sw_pipelining.allow_post:
                self._Add(t.post_var == False)

        if self.config.sw_pipelining.pre_before_post:
            for t, s in [(t,s) for t in self._model._tree.nodes_low for s in self._model._tree.nodes_low ]:
                self._Add(
                    t.program_start_var > s.program_start_var ).OnlyEnforceIf(t.pre_var, s.post_var )

        for consumer, producer in self._list_dependencies(include_virtual_instructions=False):
            self._AddImplication( producer.src.post_var, consumer.post_var )
            self._AddImplication( consumer.pre_var, producer.src.pre_var )
            self._AddImplication( producer.src.pre_var, consumer.post_var.Not() )

    # ================================================================
    #                  CONSTRAINTS (Single issuing)                  #
    # ================================================================

    def _add_constraints_N_issue(self):
        self._AddAllDifferent([ t.program_start_var for t in self._model._tree.nodes ] )
        if self.config.constraints.functional_only:
            return
        for t in self._model._tree.nodes:
            self._Add( t.program_start_var ==
                       t.cycle_start_var * self.Target.issue_rate + t.slot_var )

    def _add_constraints_locked_positions(self):
        for t in self._model._tree.nodes:
            if t.is_locked:
                self._Add(t.program_start_var == t.orig_pos)
        if self.config.constraints.allow_reordering:
            return
        # If !allow_reordering, we still want to allow the insertion of gaps to indicate
        # the presence of model violations. Thus, we don't fix the position of instructions,
        # but only their relative order.
        for t0, t1 in self.get_inst_pairs():
            if t0.orig_pos < t1.orig_pos:
                self._Add(t0.program_start_var < t1.program_start_var)

    # ================================================================
    #                  CONSTRAINTS (Single issuing)                  #
    # ================================================================

    def _add_constraints_scheduling(self):

        if self.config.sw_pipelining.enabled:
            self._Add( self._model.program_padded_size ==
                       2 * self._model.program_padded_size_half )

        self.logger.debug(f"Add positional constraints for "
                          f"{len(self._model._tree.nodes)} instructions")

        for t in self._model._tree.nodes:
            self.logger.debug(f"Add positional constraints for {t}")
            self._Add( t.program_start_var <= self._model.program_padded_size - 1)
            for s in t.out_lifetime_end + t.out_lifetime_duration:
                self._Add( s <= self._model.program_padded_size)
            for s in t.inout_lifetime_end + t.inout_lifetime_duration:
                self._Add( s <= self._model.program_padded_size)

            self._AddAbsEq( t.program_displacement,
                            t.program_start_var - t.orig_pos_scaled )

            if self.config.constraints.max_relative_displacement < 1.0:
                max_disp = int(self.config.constraints.max_relative_displacement *
                               self._model.program_padded_size_const)
                c = self._Add( t.program_displacement < max_disp )
                if self.config.sw_pipelining.enabled:
                    c.OnlyEnforceIf(t.core_var)

            if self.config.constraints.functional_only:
                continue

            self._Add( t.cycle_start_var <= self._model.cycle_padded_size - 1)
            self._Add( t.cycle_end_var   <= self._model.cycle_padded_size + 1)

    # ================================================================
    #               CONSTRAINTS (Functional correctness)             #
    #----------------------------------------------------------------#
    #    A source line ('consumer') comes after the source lines     #
    #    ('producers') corresponding to its inputs                   #
    # ================================================================

    def _add_constraints_dependency_order(self):
        # If we model latencies, this constraint is automatic
        if self.config.constraints.model_latencies:
            return
        for t, i in self._list_dependencies():
            self.logger.debug(f"Program order constraint: [{t}] > [{i.src}]")
            self._add_path_constraint( t, i.src,
                 lambda: self._Add( t.program_start_var >
                                    i.src.program_start_var ) )

    # ================================================================
    #               CONSTRAINTS (Functional correctness)             #
    #----------------------------------------------------------------#
    #    Obey instruction latencies                                  #
    # ================================================================

    def _add_constraints_latencies(self):
        if not self.config.constraints.model_latencies:
            return
        for t,i in self._list_dependencies(include_virtual_instructions=False):
            latency = self.Target.get_latency(i.src.inst, i.idx, t.inst)
            self.logger.debug(f"Latency constraint: [{t}] >= [{i.src}] + {latency}")
            self._add_path_constraint( t, i.src,
                 lambda: self._Add( t.cycle_start_var >= i.src.cycle_start_var + latency ) )

    # ================================================================#
    #               CONSTRAINTS (Functional correctness)              #
    #-----------------------------------------------------------------#
    # Between producer and consumer, noone overwrites output register #
    # ================================================================#

    def _add_constraints_register_usage(self):
        for usage_intervals in self._model.register_usages.values():
            self._AddNoOverlap(usage_intervals)

    # ================================================================#
    #                     CONSTRAINT (Performance)                    #
    #-----------------------------------------------------------------#
    # Further microarchitecture dependent positional constraints      #
    # ================================================================#

    def _add_constraints_misc(self):
        self.Target.add_further_constraints(self)

    def get_inst_pairs(self, cond=None):
        if cond == None:
            cond = lambda a,b: True
        for t0 in self._model._tree.nodes:
            for t1 in self._model._tree.nodes:
                if cond(t0,t1):
                    yield (t0,t1)

    # ================================================================#
    #                     CONSTRAINT (Performance)                    #
    #-----------------------------------------------------------------#
    # Don't overload execution units                                  #
    # (avoid back-to-back vector instructions of the same kind)       #
    # ================================================================#

    def _add_constraints_functional_units(self):
        if not self.config.constraints.model_functional_units:
            return
        for unit in self.Target.ExecutionUnit:
            self._AddNoOverlap(self._model.intervals_for_unit[unit])
        for t in self._model._tree.nodes:
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

        ## First iteration
        # tt1.late -> tt0.core -> tt1.early
        #
        ## Second iteration
        # tt0.late -> tt1.core ->tt0.early
        #
        # So we're matching..
        # - tt0.late  == tt1.late  + size
        # - tt1.core  == tt0.core  + size
        # - tt0.early == tt1.early + size
        #
        # Additionally, they should use exactly the same registers, so we can roll the loop again

        for (t0,t1) in zip(self._model._tree.nodes_low, self._model._tree.nodes_high):
            self._Add( t0.pre_var  == t1.pre_var  )
            self._Add( t0.post_var == t1.post_var )
            self._Add( t0.core_var == t1.core_var )
            # Early
            self._Add( t0.program_start_var == t1.program_start_var + self._model.program_padded_size_half )\
                       .OnlyEnforceIf(t0.pre_var)
            # Core
            self._Add( t1.program_start_var == t0.program_start_var + self._model.program_padded_size_half )\
                       .OnlyEnforceIf(t0.core_var)
            # Late
            self._Add( t0.program_start_var == t1.program_start_var + self._model.program_padded_size_half )\
                       .OnlyEnforceIf(t0.post_var)
            ## Register allocations must be the same
            assert t0.inst.arg_types_out == t1.inst.arg_types_out
            for o, arg_ty in enumerate(t0.inst.arg_types_out):
                t0_vars = set(t0.alloc_out_var[o].keys())
                t1_vars = set(t1.alloc_out_var[o].keys())
                # TODO: This might still fail in the case where we write to a global output
                #       which hasn't been assigned an architectural register name.
                if not t1_vars.issubset(t0_vars):
                    self.logger.input.error( f"Instruction siblings {t1.orig_pos}:{t1.inst} and {t0.orig_pos}:{t0.inst} have incompatible register renaming options:")
                    self.logger.input.error(f"- {t1.orig_pos}:{t1.inst} has options {t1_vars}")
                    self.logger.input.error(f"- {t0.orig_pos}:{t0.inst} has options {t0_vars}")
                assert t1_vars.issubset(t0_vars)
                for reg in t1_vars:
                    v0 = t0.alloc_out_var[o][reg]
                    v1 = t1.alloc_out_var[o][reg]
                    self._Add( v0 == v1 )

    def restrict_early_late_instructions(self, filter_func):
        """Forces all instructions not passing the filter_func to be `core`, that is,
        neither early nor late instructions.

        This is only meaningful if software pipelining is enabled."""
        if not self.config.sw_pipelining.enabled:
            return

        for t in self._model._tree.nodes:
            if filter_func(t.inst):
                continue
            self._Add(t.core_var == True)

    def restrict_slots_for_instruction( self, t, slots ):
        """This forces the given instruction to be assigned precisely one of the slots
        in the provided slot list.

        This is only useful for microarchitecture models with multi-issuing
        (otherwise, there's only slot 0 anyway).

        For microarchitectures where functional units have a throughput of 1 instruction
        per cycle, this option can be an alternative way to model the occupancy of
        functional units: Rather than assigning length-1 intervals for the occupance of
        functional units and demanding that they're disjoint -- the default operation of
        Slothy, which works for multi-cycle instructions -- one can identify the slot number
        with the functional unit that an instruction runs on, and then the non-overlapping
        constraint is subsumed by the mutual distinctiveness of the program order positions.
        Note, though, that this approach 'overwrites' the actual microarchitectural meaning
        of the slot number -- if there are uarch constraints regarding the slot number
        (e.g. "instruction XYZ can only be issued on slot 0") then it should not be used."""
        slot_vars = { s : self._NewBoolVar("") for s in slots }
        self._AddExactlyOne(slot_vars.values())
        for s, var in slot_vars.items():
            self._Add( t.slot_var == s ).OnlyEnforceIf(var)

    # ==============================================================#
    #                         OBJECTIVES                            #
    # ==============================================================#

    def _add_objective(self):
        minlist = []
        maxlist = []
        name = None

        # We only support objectives of the form: Maximize/Minimize the sum of a set of variables.

        # If the number of stalls is variable, its minimization is our objective
        if self.config.variable_size:
            name = "minimize number of stalls"
            minlist = [self._model.padded_size]
        else:
            # Otherwise, we check that only one other configurable objective is enabled,
            # and use it.
            if sum([self.config.sw_pipelining.enabled and
                    self.config.sw_pipelining.minimize_overlapping,
                    self.config.constraints.minimize_register_usage != None,
                    self.config.constraints.minimize_use_of_extra_registers != None,
                    self.Target.has_min_max_objective(self)]) > 1:
                raise Exception("Can only pick one optimization objective")

            if self.config.sw_pipelining.enabled and \
               self.config.sw_pipelining.minimize_overlapping:
                # Minimize the amount of iteration interleaving
                corevars = [ t.core_var.Not() for t in self._model._tree.nodes_low ]

                if self.config.sw_pipelining.allow_post == True and \
                   self.config.sw_pipelining.allow_pre  == True:
                    # Loops with only early/late instructions, but not both,
                    # are essentially the same. Concretely, a loop with post-only
                    # can be mapped to a loop with pre-only via [*,l] -> [e,*].
                    # In this case, minimal overlapping for the post-only configuration
                    # converts to maximal overlapping for the pre-only configuration
                    maxlist = corevars
                else:
                    minlist = corevars
                name = "minimize iteration overlapping"
            elif self.config.constraints.minimize_register_usage is not None:
                # Minimize the number of registers used
                minlist = list(self._register_used.values())
            elif self.config.constraints.minimize_use_of_extra_registers is not None:
                ty = self.config.constraints.minimize_use_of_extra_registers
                minlist = []
                for r in self.Arch.RegisterType.list_registers(ty, only_extra=True):
                    minlist += self._model.register_usage_vars.get(r,[])
            elif self.Target.has_min_max_objective(self):
                # Check if there's some target-specific objective
                lst, ty, name = self.Target.get_min_max_objective(self)
                if ty == "minimize":
                    minlist = lst
                else:
                    maxlist = lst

        if name != None:
            assert not (len(minlist) > 0 and len(maxlist) > 0)
            if len(minlist) > 0:
                self._model.cp_model.Minimize(cp_model.LinearExpr.Sum(minlist))
            if len(maxlist) > 0:
                self._model.cp_model.Maximize(cp_model.LinearExpr.Sum(maxlist))
            self.logger.info(f"Set objective: {name}")
            self._model.objective_name = name
        else:
            self.logger.info("No objective -- any satisfying solution is fine")
            self._model.objective_name = "no objective"

    #
    # Dummy wrappers around CP-SAT
    #
    # Introduced so one can easily log model building calls, or use a different solver.
    #

    def _init_external_model_and_solver(self):
        self._model.cp_model  = cp_model.CpModel()
        self._model.cp_solver = cp_model.CpSolver()
        self._model.cp_solver.random_seed = self.config.solver_random_seed

        # There is a bug in OR-Tools, https://github.com/google/or-tools/issues/3483,
        # that causes models to be incorrectly classes as INFEASIBLE at times.
        # The following turns of the buggy parts of the code:
        if ortools.__version__ < "9.5.2040":
            self.logger.warning("Please consider upgrading OR-Tools to version >= 9.5.2040")
            self._model.cp_solver.parameters.symmetry_level = 1

    def _NewIntVar(self, minval, maxval, name=""):
        r = self._model.cp_model.NewIntVar(minval,maxval, name)
        return r
    def _NewIntervalVar(self, base, dur, end, name=""):
        r = self._model.cp_model.NewIntervalVar(base,dur,end,name)
        return r
    def _NewOptionalIntervalVar(self, base, dur, end, cond,name=""):
        r = self._model.cp_model.NewOptionalIntervalVar(base,dur,end,cond,name)
        return r
    def _NewBoolVar(self, name=""):
        r = self._model.cp_model.NewBoolVar(name)
        return r
    def _NewConstant(self, val):
        r = self._model.cp_model.NewConstant(val)
        return r
    def _Add(self,c):
        return self._model.cp_model.Add(c)
    def _AddNoOverlap(self,lst):
        return self._model.cp_model.AddNoOverlap(lst)
    def _AddExactlyOne(self,lst):
        return self._model.cp_model.AddExactlyOne(lst)
    def _AddImplication(self,a,b):
        return self._model.cp_model.AddImplication(a,b)
    def _AddAtLeastOne(self,lst):
        return self._model.cp_model.AddAtLeastOne(lst)
    def _AddAbsEq(self,dst,expr):
        return self._model.cp_model.AddAbsEquality(dst,expr)
    def _AddAllDifferent(self,lst):
        if len(lst) < 2:
            return
        return self._model.cp_model.AddAllDifferent(lst)
    def _AddHint(self,var,val):
        return self._model.cp_model.AddHint(var,val)
    def _AddNoOverlap(self,interval_list):
        if len(interval_list) < 2:
            return
        return self._model.cp_model.AddNoOverlap(interval_list)

    def _export_model(self, log_model):
        if log_model == None:
            return
        self.logger.info(f"Writing model to {log_model}...")
        assert self._model.cp_model.ExportToFile(self.config.log_dir + "/" + log_model)

    def _solve(self):
        solution_cb = SlothyBase._cp_sat_solution_cb(self.logger,self._model.objective_name)
        self._model.cp_model.status = self._model.cp_solver.Solve(self._model.cp_model, solution_cb)
        return self._model.cp_model.status != cp_model.INFEASIBLE

    def _dump_model_statistics(self):
        # Extract and report results
        self._dump(f"Statistics", self._model.cp_model.cp_solver.ResponseStats())

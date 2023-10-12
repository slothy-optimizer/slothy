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
from enum import Enum

from .helper import AsmHelper

class RegisterSource:
    pass

class VirtualInstruction:
    def __init__(self, reg, ty):
        self.orig_reg = reg
        self.orig_ty = ty

class VirtualOutputInstruction(VirtualInstruction):
    def __init__(self, reg, reg_ty):
        super().__init__(reg, reg_ty)
        self.num_in_out = 0
        self.args_in_out = []
        self.arg_types_in_out = []
        self.num_out = 0
        self.args_out = []
        self.arg_types_out = []
        self.num_in = 1
        self.args_in = [reg]
        self.arg_types_in = [reg_ty]

        self.args_out_combinations = None
        self.args_in_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_different = None
        self.args_in_inout_different = None

        self.args_out_restrictions    = [ None for _ in range(self.num_out)    ]
        self.args_in_restrictions     = [ None for _ in range(self.num_in)     ]
        self.args_in_out_restrictions = [ None for _ in range(self.num_in_out) ]

        self.args_out_combinations = None
        self.args_in_combinations = None

    def write(self):
        return f"// output renaming: {self.orig_reg} -> {self.args_in_out[0]}"

    def __repr__(self):
        return f"<output:{self.orig_reg}:{self.arg_types_in[0]}>"

class VirtualInputInstruction(VirtualInstruction):
    def __init__(self, reg, reg_ty):
        super().__init__(reg, reg_ty)
        self.num_in = 0
        self.args_in = []
        self.arg_types_in = []
        self.num_out = 1
        self.args_out = [reg]
        self.arg_types_out = [reg_ty]
        self.num_in_out = 0
        self.args_in_out = []
        self.arg_types_in_out = []

        self.args_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_combinations = None
        self.args_in_out_different = None
        self.args_in_inout_different = None

        self.args_out_restrictions    = [ None for _ in range(self.num_out)    ]
        self.args_in_restrictions     = [ None for _ in range(self.num_in)     ]
        self.args_in_out_restrictions = [ None for _ in range(self.num_in_out) ]

    def write(self):
        return f"// input renaming: {self.orig_reg} -> {self.args_out[0]}"

    def __repr__(self):
        return f"<input:{self.orig_reg}:{self.arg_types_out[0]}>"

class ComputationNode:

    def __init__(self, *, id, inst, orig_pos=None, src_in=None, src_in_out=None):
        """A node in a data flow graph

           Args:
              id:     A unique identifier for the node
              inst:   The instruction which the node represents
                      Must be an instance of Instruction
              src_in: A list of RegisterSource instances representing
                      the inputs to the instruction. Inputs which are
                      also written to should not be listed here, but in
                      the separate src_in_out argument.
              src_in_out: A list of RegisterSource instances representing
                          the inputs to the instruction which are also
                          written to.
        """

        def isinstancelist(l, c):
            return all( map( lambda e: isinstance(e,c), l ) )

        if src_in == None:
            src_in = []
        if src_in_out == None:
            src_in_out = []

        assert isinstancelist(src_in,     RegisterSource)
        assert isinstancelist(src_in_out, RegisterSource)

        assert id != None
        assert len(src_in)     == inst.num_in
        assert len(src_in_out) == inst.num_in_out

        self.orig_pos = orig_pos
        self.id   = id
        self.inst = inst

        self.src_in     = src_in
        self.src_in_out = src_in_out

        self.is_locked = False

        src_in_all = src_in + src_in_out

        # Track the current node as dependent on the nodes that produced its inputs.
        depth = 0
        for s in src_in_all:
            if isinstance(s, InstructionOutput):
                depth = max(depth, s.src.depth+1)
                s.src.dst_out[s.idx].append(self)
            if isinstance(s, InstructionInOut):
                depth = max(depth, s.src.depth+1)
                s.src.dst_in_out[s.idx].append(self)

        self.depth = depth

        # Track instructions relying on the outputs of the computation step
        self.dst_out    = [ [] for _ in range(inst.num_out)    ]
        self.dst_in_out = [ [] for _ in range(inst.num_in_out) ]

    def is_virtual_input(self):
        return isinstance(self.inst,VirtualInputInstruction)
    def is_virtual_output(self):
        return isinstance(self.inst,VirtualOutputInstruction)
    def is_virtual(self):
        return self.is_virtual_input() or self.is_virtual_output()
    def is_not_virtual(self):
        return not self.is_virtual()

    def varname(self):
        return ''.join([ e for e in str(self.inst) if e.isalnum() ])

    def __repr__(self):
        return f"{self.id}:'{self.inst}' (type {self.inst.__class__.__name__})"

    def describe(self):
        ret = []

        def _append_src( name, src_lst ):
            if len(src_lst) == 0:
                return
            ret.append(f"* {name}")
            for idx, src in enumerate(src_lst):
                ret.append(f" + {idx}: {src}")
        def _append_deps( name, dep_lst ):
            if len(dep_lst) == 0:
                return
            ret.append(f"* {name}")
            for idx, deps in enumerate(dep_lst):
                ret.append(f" + {idx}")
                for d in deps:
                    ret.append(f"    - {d}")

        ret.append(f"ComputationNode")
        ret.append(f"* ID:  {self.id}")
        ret.append(f"* Pos: {self.orig_pos}")
        ret.append(f"* ASM: {self.inst}")
        ret.append(f"  + Outputs: {list(zip(self.inst.args_out,self.inst.arg_types_out))}")
        ret.append(f"  + Inputs:  {list(zip(self.inst.args_in,self.inst.arg_types_in))}")
        ret.append(f"  + In/Outs: {list(zip(self.inst.args_in_out,self.inst.arg_types_in_out))}")
        ret.append(f"* TYPE: {self.inst.__class__.__name__}")
        _append_src("Input sources", self.src_in)
        _append_src("In/Outs sources", self.src_in_out)
        _append_deps("Output dependants", self.dst_out)
        _append_deps("In/Out dependants", self.dst_in_out)
        return ret

class InstructionOutput(RegisterSource):
    def __init__(self,src,idx):
        assert isinstance(src,ComputationNode)
        self.src = src
        self.idx = idx
    def __repr__(self):
        return f"({self.src}).out[{self.idx}]"
    def get_type(self):
        return self.src.inst.arg_types_out[self.idx]
    def name(self):
        return self.src.inst.args_out[self.idx]
    def alloc(self):
        return self.src.alloc_out_var[self.idx]
    def reduce(self):
        return self

class InstructionInOut(RegisterSource):
    def __init__(self,src,idx):
        assert isinstance(src,ComputationNode)
        self.src = src
        self.idx = idx
    def __repr__(self):
        return f"({self.src}).inout[{self.idx}]"
    def get_type(self):
        return self.src.inst.arg_types_in_out[self.idx]
    def name(self):
        return self.src.inst.args_in_out[self.idx]
    def alloc(self):
        return self.src.alloc_in_out_var[self.idx]
    def reduce(self):
        return self.src.src_in_out[self.idx].reduce()

class Config:

    @property
    def Arch(self):
        return self._Arch
    @property
    def typing_hints(self):
        typing_hints = { name : ty for ty in self.Arch.RegisterType \
               for name in self.Arch.RegisterType.list_registers(ty, with_variants=True) }
        return { **self._typing_hints, **typing_hints }
    @property
    def outputs(self):
        return self._outputs
    @property
    def inputs_are_outputs(self):
        return self._inputs_are_outputs
    @property
    def allow_useless_instructions(self):
        return self._allow_useless_instructions

    @typing_hints.setter
    def typing_hints(self,val):
        self._typing_hints = val
    @outputs.setter
    def outputs(self,val):
        self._outputs = val
    @inputs_are_outputs.setter
    def inputs_are_outputs(self,val):
        self._inputs_are_outputs = val
    @allow_useless_instructions.setter
    def allow_useless_instructions(self,val):
        self._allow_useless_instructions = val

    def __init__(self, slothy_config=None, **kwargs):
        """Create a DataFlowGraph config from a Slothy config

        Args:
            slothy_config: The Slothy configuration to reference.
                   kwargs: An optional list of modifications of the Slothy config
        """
        self._Arch = None
        self._typing_hints = None
        self._outputs = None
        self._inputs_are_outputs = None
        self._allow_useless_instructions = None
        self._load_slothy_config(slothy_config)
        for k,v in kwargs.items():
            setattr(self,k,v)

    def _load_slothy_config(self, slothy_config):
        if slothy_config == None:
            return
        self._slothy_config = slothy_config
        self._Arch = slothy_config.Arch
        self._typing_hints = self._slothy_config.typing_hints
        self._outputs = self._slothy_config.outputs
        self._inputs_are_outputs = self._slothy_config.inputs_are_outputs
        self._allow_useless_instructions = self._slothy_config.allow_useless_instructions

class DataFlowGraph:

    @property
    def nodes_all(self):
        """The list of all ComputationNodes contained in the DataFlowGraph.

        This includes "virtual" computation nodes for inputs and outputs.
        Those nose are added for each input and output, respectively, to
        (a) make the graph self-contained in the sense that there are no
        external inputs to the graph, (b) makes it easier to track where
        outputs are written, (c) automatically creates input nodes for
        outputs which are never written to."""
        return self._nodes_all

    @property
    def nodes(self):
        """The list of all ComputationNodes corresonding to instructions in
        the original source code. Compared to DataFlowGraph.nodes_all, this
        omits "virtual" computation nodes."""
        return list(filter(ComputationNode.is_not_virtual, self.nodes_all))

    @property
    def num_nodes(self):
        return len(self.nodes)

    @property
    def nodes_input(self):
        """The list of all virtual input ComputationNodes"""
        return [ t for t in self.nodes_all if t.is_virtual_input() ]
    @property
    def nodes_output(self):
        """The list of all virtual output ComputationNodes"""
        return [ t for t in self.nodes_all if t.is_virtual_output() ]
    @property
    def inputs_typed(self):
        """The type-indexed dictionary of input registers"""
        res = { ty : [] for ty in self.Arch.RegisterType }
        for t in self.nodes_input:
            ty  = t.inst.arg_types_out[0]
            reg = t.inst.args_out[0]
            res[ty].append(reg)
        return res
    @property
    def outputs_typed(self):
        """The type-indexed dictionary of output registers"""
        res = {}
        for t in self.nodes_output:
            ty  = t.inst.arg_types_in[0]
            reg = t.inst.args_in[0]
            if ty not in res.keys():
                res[ty] = []
            res[ty].append(reg)
        return res
    @property
    def input_by_name(self):
        """Dictionary mapping input names to their virtual input ComputationNode"""
        return { t.inst.args_out[0] : t for t in self.nodes_input }
    @property
    def output_by_name(self):
        """Dictionary mapping output names to their virtual output ComputationNode"""
        return { t.inst.args_in[0] : t for t in self.nodes_output }
    @property
    def inputs(self):
        """The (untyped) set of input registers."""
        return set(self.input_by_name.keys())
    @property
    def outputs(self):
        """The (untyped) set of output registers."""
        return set(self.output_by_name.keys())

    @property
    def nodes_by_id(self):
        """Dictionary mapping ComputationNode IDs to computation nodes"""
        return { t.id : t for t in self.nodes_all }

    @property
    def nodes_low(self):
        """For a source with an even number of instructions, the lower half of the
        data flow graph, excluding virtual instructions."""
        num_nodes = len(self.nodes)
        assert num_nodes % 2 == 0
        return self.nodes[:num_nodes//2]
    @property
    def nodes_high(self):
        """For a source with an even number of instructions, the upper half of the
        data flow graph, excluding virtual instructions."""
        num_nodes = len(self.nodes)
        assert num_nodes % 2 == 0
        return self.nodes[num_nodes//2:]

    @property
    def type_dict(self):
        return { **self._typing_dict, **self.config.typing_hints }

    def _remember_type(self, reg, ty):
        if not reg in self._typing_dict.keys():
            self._typing_dict[reg] = ty
            return

        if not self._typing_dict[reg] == ty:
            self.logger.warning(f"You're using the same variable {reg} for registers of different types -- this may confuse the tool...")

    def edges(self):
        """Return the set of labelled edges in the data flow graph.
        Each labelled edge is represented as a triple of (src_id, dst_id, label).

        The ID of a virtual input/output node is "input/output_{name}" (as a string),
        while the ID of computation nodes corresponding to instructions in the input
        source is their original position, as an integer."""
        def _iter_edges_with_label():
            for t in self.nodes_all:
                for out_idx, deps in enumerate(t.dst_out):
                    for d in deps:
                        yield (t.id, d.id, f"out{out_idx}")
                for in_out_idx, deps in enumerate(t.dst_in_out):
                    for d in deps:
                        yield (t.id, d.id, f"inout{in_out_idx}")
        return set(_iter_edges_with_label())

    def depth(self):
        if self.nodes == None or len(self.nodes) == 0:
            return 1
        return max([t.depth for t in self.nodes])

    def dump_instructions(self, txt, error=False):
        log_func = self.logger.debug if not error else self.logger.error
        log_func(txt)
        for idx, l in enumerate(self.src):
            log_func(f" * {idx}: {l[0]}")

    @property
    def Arch(self):
        return self.config.Arch

    def __init__(self, src, logger, config, parsing_cb=True):
        """Compute a data flow graph from a source code snippet.

        Args:
            arch: The underlying architecture.
             src: The source code to be converted into a data flow graph.
          logger: The logger to be used.
           typing_hints: String-indexed dictionary mapping symbolic register names
                         to types. Types are members of the RegisterType enum from the
                         arch module.
           outputs: The symbolic or architectural registers that the code produces.
                    Dictionary indexed by the RegisterType enum from the the arch module.
        """

        self.logger = logger
        self.config = config

        def check_make_default_dict(d, default_val):
            if d != None:
                return d
            return { ty : default_val() for ty in self.Arch.RegisterType }

        self.src = self._parse_source(src)

        # Typically, we only build the computation flow graph once. However, sometimes we make
        # retrospective modifications to instructions afterwards, and then need to reparse.
        #
        # An example for this are jointly destructive instruction patterns: A sequence of
        # instructions where each instruction individually overwrites only part of a register,
        # but jointly they overwrite the register as a whole. In this case, we can remove the
        # output register as an input dependency for the first instruction in the sequence,
        # thereby creating more reordering and renaming flexibility. In this case, we change
        # the instruction and then rebuild the computation flow graph.
        count = 0
        while True:
            count += 1
            assert count < 10 # There shouldn't be many repeated modifications to the CFG

            self._build_graph()
            delete_list = []

            if not parsing_cb:
                break

            changes = 0
            for t in self.nodes:
                changed = t.inst.global_parsing_cb(t, delete_list)
                if changed: # remember to build the dataflow graph again
                    changes += 1
            # If no instruction was modified, we're done
            if changes == 0:
                break

            for inst in delete_list:
                new_src = list(filter(lambda x: inst not in x[0], self.src))
                assert len(new_src) == len(self.src) - 1
                self.src = new_src

            # Otherwise, parse again
            logger.info(f"{changes} instructions changed -- need to build dataflow graph again...")

        if not self.config.allow_useless_instructions:
            self._selfcheck_outputs()

    def _selfcheck_outputs(self):
        """Checks whether there are instructions whose output(s) are never used, but also
        not declared as outputs."""

        def flatten(llst):
            return [x for y in llst for x in y]
        def outputs_unused(t):
            has_outputs = ( t.inst.num_out + t.inst.num_in_out > 0 )
            outputs_unused = ( len(flatten(t.dst_out + t.dst_in_out)) == 0 )
            return has_outputs and outputs_unused
        useless_nodes = filter(outputs_unused, self.nodes)
        t = next(useless_nodes, None)
        if t != None:
            self.logger.error(f"The output(s) of instruction {t.id}({t.inst}) are not used but also not declared as outputs.")
            self.logger.error(f"Instruction details: {t}, {t.inst.inputs}")
            self.dump_instructions("Source code", error=True)
            raise Exception("Useless instruction detected -- probably you missed an output declaration?")

    def _parse_source(self, src):
        return [ (self.Arch.Instruction.parser(l),l) for l in AsmHelper.reduce_source(src) ]

    def iter_dependencies(self):
        for consumer in self.nodes_all:
            for producer in consumer.src_in + consumer.src_in_out:
                yield (consumer,producer)

    def _typecheck_node(self, s):
        # We maintain a typing dictionary capturing what we think the type
        # of certain (symbolic) registers should be. Here, we check whether
        # an instruction signature typechecks with respect to this dictionary.
        #
        # For example, in MVE, if we believe that `const` is a GPR, then only
        # only the only way to parse `vmul q0, q0, const` is via the scalar-vector
        # variant of vmul, while attempting to parse it as an instance of the
        # vector-vector variant would fail the type check.
        self.logger.debug(f"Typecheck instruction {s}")
        def _check_list(txt, types,names):
            for ty, name in zip(types,names):
                self.logger.debug(f" - argument {name} of type {ty}")
                expectations = []
                # Check if we know the type from the dictionary
                if name in self.reg_state.keys():
                    exp_ty = self.reg_state[name].get_type()
                    self.logger.debug(f"   + type of {name} in state dictionary: {exp_ty}")
                    expectations.append((f"State dictionary: {exp_ty}", exp_ty))
                else:
                    self.logger.debug(f"    + {name} not in state dictionary")
                    self.logger.debug(f"      Current dictionary:")
                    self.logger.debug(self.reg_state)
                # Check if we've been given a type hind
                if name in self.config.typing_hints.keys():
                    exp_ty = self.config.typing_hints[name]
                    self.logger.debug(f"   + type of {name} according to typing hints: {exp_ty}")
                    expectations.append((f"Typing hint: {exp_ty}", exp_ty))
                # Check if all our expectations match the type recorded in the
                # instruction signature. Note that this also works in the case
                # where we don't have any type expectation, as all([]) == True.
                for fail in [ msg for (msg,exp) in expectations if exp != ty ]:
                    self.logger.debug(f"Typecheck for {name} failed -- mismatch: {fail}")
                    return False
            return True
        return _check_list("input", s.arg_types_in, s.args_in) and \
               _check_list("in/out", s.arg_types_in_out, s.args_in_out)

    def _describe(self, *, error=False):
        log_func = self.logger.error if error else self.logger.debug
        [log_func(d) for t in self.nodes_all for d in t.describe()]

    def ssa(self):

        # Go through non-virtual instruction nodes and assign unique names to
        # output registers which are not global outputs.
        out_cnt = 0
        def get_fresh_reg():
            nonlocal out_cnt
            res = f"ssa_{out_cnt}"
            out_cnt += 1
            return res

        for t in self.nodes:
            for i in range(len(t.inst.args_out)):
                # If the output is global, skip renaming
                output_is_global = False
                for d in t.dst_out[i]:
                    if d.is_virtual():
                        output_is_global = True
                if output_is_global:
                    continue
                # Otherwise, assign a fresh variable
                t.inst.args_out[i] = get_fresh_reg()

        # Update input and in-out register names
        for t in self.nodes_all:
            for i in range(len(t.inst.args_in)):
                t.inst.args_in[i] = t.src_in[i].reduce().name()
            for i in range(len(t.inst.args_in_out)):
                t.inst.args_in_out[i] = t.src_in_out[i].reduce().name()

    def _build_graph(self):
        self.reg_state = {}
        self._typing_dict = {}
        self._nodes_all = []

        # Process source and add one instruction a time to the data flow graph
        for c,s in self.src:
            self._add_node_from_candidates(c,s)

        # Mark inputs as outputs if desired
        outputs = set(self.config.outputs.copy())
        if self.config.inputs_are_outputs:
            outputs.update(self.inputs)

        # Add virtual computation nodes for outputs
        for out in outputs:
            self._add_node_from_candidates([ VirtualOutputInstruction(out, ty)
                                             for ty in self.Arch.RegisterType],
                                           f"<output:{out}>")

        self.logger.debug("Dumping computational flow graph")
        self._describe()

    def _add_node_from_candidates(self, candidates, sourceline):
        valid_candidates = list(filter(self._typecheck_node, candidates))
        num_valid_candidates = len(valid_candidates)
        if num_valid_candidates == 0:
            raise Exception(f"None of the candidate parsings for {sourceline} type checks!"\
                            f"\nCandidates\n{candidates}")
        # If we have more than one instruction passing the type check,
        # then we need more typing information from the user.
        #
        # An example from MVE would be `vmul q0, q0, const` if we do _not_ have any
        # information on the type of `const` -- it could be either a GPR or a vector.
        if num_valid_candidates > 1:
            cnames = list(map(lambda c: type(c).__name__,candidates))
            raise Exception(f"Cannot unambiguously choose between {cnames} "\
                            f"in {candidates} -- need typing information")
        # Add the single valid candidate parsing to the CFG
        self._add_node(valid_candidates[0])

    def _add_node(self, s):
        """Add a node to the data flow graph

           Args:
               s: Instruction to be added to the graph. This may be a single
                  instruction of a list of candidate instructions, in case the
                  parsing wasn't unambiguous.
        """

        if not isinstance(s, VirtualInstruction):
            self.logger.debug(f"Adding instruction to CFG: {s}")
        elif isinstance(s, VirtualInputInstruction):
            self.logger.debug(f"Adding virtual instruction for input {s.orig_reg}")
        elif isinstance(s, VirtualOutputInstruction):
            self.logger.debug(f"Adding virtual instruction for output {s.orig_reg}")

        def find_source_single(ty,name):
            self.logger.debug(f"Finding source of register {name} of type {ty}")

            # Check if the inputs have been produced by the data flow graph
            if name not in self.reg_state.keys():
                # If not, treat them as a global input
                self.logger.debug(f"-> {name} is a global input")
                # Create a virtual instruction producing the output add that first
                # Since the virtual instruction does not have any inputs, there is
                # no risk of infinite recursion here
                self._add_node(VirtualInputInstruction(name, ty))
                # Fall through

            # At this point, the source _must_ be produced by an instruction in the graph
            assert name in self.reg_state.keys()

            # Return a reference to the node producing the input
            origin = self.reg_state[name]
            self.logger.debug(f"-> {name} has been produced by {origin}")

            if origin.get_type() != ty:
                warnstr = f"Type mismatch: Output {name} of {type(origin.src.inst).__name__} has "\
                    f"type {origin.get_type()} but {type(s).__name__} expects it to have type {ty}"
                self.logger.debug(warnstr)
                raise Exception(warnstr)

            return self.reg_state[name]

        def find_sources(types,names):
            return [ find_source_single(t,n) for t,n in zip(types,names) ]

        # Lookup computation nodes for inputs
        src_in     = find_sources(s.arg_types_in, s.args_in)
        src_in_out = find_sources(s.arg_types_in_out, s.args_in_out)

        if isinstance(s, VirtualInputInstruction):
            s_id = f"input_{s.orig_reg}"
            orig_pos = None
        elif isinstance(s, VirtualOutputInstruction):
            s_id = f"output_{s.orig_reg}"
            orig_pos = None
        else:
            s_id = len(self.nodes)
            orig_pos = s_id

        step = ComputationNode(id=s_id, orig_pos=orig_pos, inst=s,
                               src_in=src_in, src_in_out=src_in_out)

        def change_reg_ref(reg, ref):
            self._remember_type(reg, ref.get_type())
            self.reg_state[o] = ref

        for i, o in enumerate(s.args_out):
            change_reg_ref(o, InstructionOutput(step, i))
        for i, o in enumerate(s.args_in_out):
            change_reg_ref(o, InstructionInOut(step, i))

        self.nodes_all.append(step)

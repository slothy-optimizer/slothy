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

from functools import cached_property
from slothy.helper import SourceLine


class SlothyUselessInstructionException(Exception):
    """An instruction was found whose outputs are neither used by a subsequent instruction
    nor declared as global outputs of the code under consideration. The instruction is
    therefore useless according to the architecture model given to SLOTHY. Consider
    removing the instructions or refining the architecture model.
    """


class RegisterSource:
    """Representation of the output of an instruction

    This is used when iterating over dependencies in the data flow graph.
    This class is abstract and implemented by InstructionOutput and
    InstructionInOut below, represention outputs and input/outputs,
    respectively.
    """

    def __init__(self, src, idx):
        assert isinstance(src, ComputationNode)
        self.src = src
        self.idx = idx

    def get_type(self):
        """The register type of the dependency"""

    def name(self):
        """The name of the register used to carry the dependency."""

    def alloc(self):
        # TODO: This does not belong here
        """The variable governing the choice of register renaming for this output."""

    def reduce(self):
        """In case of input/output arguments, the transitively computed RegisterSource
        producing the register as a pure _output_."""


class InstructionOutput(RegisterSource):
    """Represents an output of a node in the data flow graph"""

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

    def sibling(self):
        return InstructionOutput(self.src.sibling, self.idx)


class InstructionInOut(RegisterSource):
    """Represents an input/output of a node in the data flow graph"""

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

    def sibling(self):
        return InstructionInOut(self.src.sibling, self.idx)


class VirtualInstruction:
    """A 'virtual' instruction node for inputs and outputs."""

    def __init__(self, reg, ty):
        self.orig_reg = reg
        self.orig_ty = ty

        self.num_in_out = 0
        self.args_in_out = []
        self.arg_types_in_out = []
        self.num_out = 0
        self.args_out = []
        self.arg_types_out = []
        self.num_in = 0
        self.args_in = []
        self.arg_types_in = []

        self.args_out_combinations = None
        self.args_in_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_different = None
        self.args_in_inout_different = None

        self.args_out_restrictions = [None for _ in range(self.num_out)]
        self.args_in_restrictions = [None for _ in range(self.num_in)]
        self.args_in_out_restrictions = [None for _ in range(self.num_in_out)]

        self.args_out_combinations = None
        self.args_in_combinations = None

    def write(self):
        """Provide a string description of the virtual instruction"""


class VirtualOutputInstruction(VirtualInstruction):
    """A virtual instruction node for outputs."""

    def __init__(self, reg, reg_ty):
        super().__init__(reg, reg_ty)
        self.num_in = 1
        self.args_in = [reg]
        self.arg_types_in = [reg_ty]
        self.args_in_restrictions = [None]

    def write(self):
        return f"// output renaming: {self.orig_reg} -> {self.args_in_out[0]}"

    def __repr__(self):
        return f"<output:{self.orig_reg}:{self.arg_types_in[0]}>"


class VirtualInputInstruction(VirtualInstruction):
    """A virtual instruction node for inputs."""

    def __init__(self, reg, reg_ty):
        super().__init__(reg, reg_ty)
        self.num_out = 1
        self.args_out = [reg]
        self.arg_types_out = [reg_ty]
        self.args_out_restrictions = [None]

    def write(self):
        return f"// input renaming: {self.orig_reg} -> {self.args_out[0]}"

    def __repr__(self):
        return f"<input:{self.orig_reg}:{self.arg_types_out[0]}>"


class ComputationNode:
    """A node in a data flow graph

    :param node_id: A unique identifier for the node
    :type node_id: str
    :param inst: The instruction which the node represents
        Must be an instance of Instruction
    :type inst: any
    :param orig_pos: Position in the input code.
    :type orig_pos: int
    :param src_in: A list of RegisterSource instances representing
        the inputs to the instruction. Inputs which are
        also written to should not be listed here, but in
        the separate src_in_out argument.
    :type src_in: list
    :param src_in_out: A list of RegisterSource instances representing the inputs to the
        instruction which are also written to.
    :type src_in_out: list

    """

    def __init__(
        self,
        *,
        node_id: str,
        inst: any,
        orig_pos: int = None,
        src_in: list = None,
        src_in_out: list = None,
    ):

        def isinstancelist(ll, c):
            return all(map(lambda e: isinstance(e, c), ll))

        if src_in is None:
            src_in = []
        if src_in_out is None:
            src_in_out = []

        assert isinstancelist(src_in, RegisterSource)
        assert isinstancelist(src_in_out, RegisterSource)

        assert node_id is not None
        assert len(src_in) == inst.num_in
        assert len(src_in_out) == inst.num_in_out

        self.orig_pos = orig_pos
        self.id = node_id
        self.inst = inst

        self.src_in = src_in
        self.src_in_out = src_in_out

        self.is_locked = False

        src_in_all = src_in + src_in_out

        # Track the current node as dependent on the nodes that produced its inputs.
        depth = 0
        for s in src_in_all:
            if isinstance(s, InstructionOutput):
                depth = max(depth, s.src.depth + 1)
                s.src.dst_out[s.idx].append(self)
            if isinstance(s, InstructionInOut):
                depth = max(depth, s.src.depth + 1)
                s.src.dst_in_out[s.idx].append(self)

        self.depth = depth

        # Track instructions relying on the outputs of the computation step
        self.dst_out = [[] for _ in range(inst.num_out)]
        self.dst_in_out = [[] for _ in range(inst.num_in_out)]

    def to_source_line(self):
        """Convert node in data flor graph to source line.

        This keeps original tags and comments from the source line that
        gave rise to the node, but updates the text with the stringification
        of the instruction underlying the node.
        """
        line = self.inst.source_line.copy()
        inst_txt = str(self.inst)
        return line.set_text(inst_txt)

    @cached_property
    def is_virtual_input(self):
        """Indicates whether the node is an input node."""
        return isinstance(self.inst, VirtualInputInstruction)

    @cached_property
    def is_virtual_output(self):
        """Indicates whether the node is an output node."""
        return isinstance(self.inst, VirtualOutputInstruction)

    @cached_property
    def is_virtual(self):
        """Indicates whether the node is an input or output node."""
        return self.is_virtual_input or self.is_virtual_output

    @cached_property
    def is_not_virtual(self):
        """Indicates whether the node is neither an input nor an output node."""
        return not self.is_virtual

    def varname(self):
        return "".join([e for e in str(self.inst) if e.isalnum()])

    def __repr__(self):
        return f"{self.id}:'{self.inst}' (type {self.inst.__class__.__name__})"

    def describe(self):
        ret = []

        def _append_src(name, src_lst):
            if len(src_lst) == 0:
                return
            ret.append(f"* {name}")
            for idx, src in enumerate(src_lst):
                ret.append(f" + {idx}: {src}")

        def _append_deps(name, dep_lst):
            if len(dep_lst) == 0:
                return
            ret.append(f"* {name}")
            for idx, deps in enumerate(dep_lst):
                ret.append(f" + {idx}")
                for d in deps:
                    ret.append(f"    - {d}")

        ret.append("ComputationNode")
        ret.append(f"* ID:  {self.id}")
        ret.append(f"* Pos: {self.orig_pos}")
        ret.append(f"* ASM: {self.inst}")
        ret.append(
            f"  + Outputs: {list(zip(self.inst.args_out,self.inst.arg_types_out))}"
        )
        ret.append(
            f"  + Inputs:  {list(zip(self.inst.args_in,self.inst.arg_types_in))}"
        )
        ret.append(
            f"  + In/Outs: {list(zip(self.inst.args_in_out,self.inst.arg_types_in_out))}"
        )
        ret.append(f"* TYPE: {self.inst.__class__.__name__}")
        _append_src("Input sources", self.src_in)
        _append_src("In/Outs sources", self.src_in_out)
        _append_deps("Output dependants", self.dst_out)
        _append_deps("In/Out dependants", self.dst_in_out)
        return ret


class Config:
    """Configuration for parsing of data flow graphs

    :param slothy_config: The Slothy configuration to reference.
    :type slothy_config: any
    :param **kwargs: An optional list of modifications of the Slothy config
    :type **kwargs: any
    """

    @property
    def arch(self):
        """The underlying architecture model"""
        return self._arch

    @property
    def outputs(self):
        """The global outputs of the data flow graph."""
        return self._outputs

    @property
    def inputs_are_outputs(self):
        """Every input is automatically treated as an output.
        This is typically set for loop kernels.
        """
        return self._inputs_are_outputs

    @property
    def allow_useless_instructions(self):
        """Indicates whether data flow creation should raise
        SlothyUselessInstructionException when a useless instruction is detected.
        """
        return self._allow_useless_instructions

    @outputs.setter
    def outputs(self, val):
        self._outputs = val

    @inputs_are_outputs.setter
    def inputs_are_outputs(self, val):
        self._inputs_are_outputs = val

    @allow_useless_instructions.setter
    def allow_useless_instructions(self, val):
        self._allow_useless_instructions = val

    def __init__(self, slothy_config: any = None, **kwargs: any):
        self._arch = None
        self._outputs = None
        self._inputs_are_outputs = None
        self._allow_useless_instructions = None
        self._locked_registers = None
        self._load_slothy_config(slothy_config)

        for k, v in kwargs.items():
            setattr(self, k, v)

    def _load_slothy_config(self, slothy_config):
        if slothy_config is None:
            return
        self._slothy_config = slothy_config
        self._arch = slothy_config.arch
        self._locked_registers = slothy_config.locked_registers
        self._outputs = self._slothy_config.outputs
        self._inputs_are_outputs = self._slothy_config.inputs_are_outputs
        self._allow_useless_instructions = (
            self._slothy_config.allow_useless_instructions
        )
        self._absorb_spills = self._slothy_config.absorb_spills
        self._unsafe_address_offset_fixup = (
            self._slothy_config.unsafe_address_offset_fixup
        )


class DataFlowGraphException(Exception):
    """An exception triggered during parsing a data flow graph"""


class DataFlowGraph:
    """The data flow graph associated with a piece of assembly.


    :param src: The source code to be converted into a data flow graph.
    :type src: any
    :param logger: The logger to be used.
    :type logger: any
    :param config: Configuration object.
    :type config: any
    :param parsing_cb: Boolean indicating whether or not the parsing call back
                       should be called
    :type parsing_cb: bool

    """

    @property
    def nodes_all(self):
        """The list of all ComputationNodes contained in the DataFlowGraph.

        This includes "virtual" computation nodes for inputs and outputs.
        Those nose are added for each input and output, respectively, to
        (a) make the graph self-contained in the sense that there are no
        external inputs to the graph, (b) makes it easier to track where
        outputs are written, (c) automatically creates input nodes for
        outputs which are never written to.
        """
        return self._nodes_all

    @property
    def nodes(self):
        """The list of all ComputationNodes corresonding to instructions in
        the original source code. Compared to DataFlowGraph.nodes_all, this
        omits "virtual" computation nodes.
        """
        return list(filter(lambda x: x.is_not_virtual, self.nodes_all))

    @property
    def num_nodes(self):
        """The number of nodes in the data flow graph."""
        return len(self.nodes)

    @property
    def nodes_input(self):
        """The list of all virtual input ComputationNodes"""
        return [t for t in self.nodes_all if t.is_virtual_input]

    @property
    def nodes_output(self):
        """The list of all virtual output ComputationNodes"""
        return [t for t in self.nodes_all if t.is_virtual_output]

    @property
    def inputs_typed(self):
        """The type-indexed dictionary of input registers"""
        res = {ty: [] for ty in self.arch.RegisterType}
        for t in self.nodes_input:
            ty = t.inst.arg_types_out[0]
            reg = t.inst.args_out[0]
            res[ty].append(reg)
        return res

    @property
    def outputs_typed(self):
        """The type-indexed dictionary of output registers"""
        res = {}
        for t in self.nodes_output:
            ty = t.inst.arg_types_in[0]
            reg = t.inst.args_in[0]
            if ty not in res:
                res[ty] = []
            res[ty].append(reg)
        return res

    @property
    def input_by_name(self):
        """Dictionary mapping input names to their virtual input ComputationNode"""
        return {t.inst.args_out[0]: t for t in self.nodes_input}

    @property
    def output_by_name(self):
        """Dictionary mapping output names to their virtual output ComputationNode"""
        return {t.inst.args_in[0]: t for t in self.nodes_output}

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
        return {t.id: t for t in self.nodes_all}

    @property
    def nodes_low(self):
        """For a source with an even number of instructions, the lower half of the
        data flow graph, excluding virtual instructions.
        """
        num_nodes = len(self.nodes)
        assert num_nodes % 2 == 0
        return self.nodes[: num_nodes // 2]

    @property
    def nodes_high(self):
        """For a source with an even number of instructions, the upper half of the
        data flow graph, excluding virtual instructions.
        """
        num_nodes = len(self.nodes)
        assert num_nodes % 2 == 0
        return self.nodes[num_nodes // 2 :]

    def _remember_type(self, reg, ty):
        if reg not in self._typing_dict:
            self._typing_dict[reg] = ty
            return

        if not self._typing_dict[reg] == ty:
            self.logger.warning(
                "You're using the same variable %s for registers of "
                "different types -- this may confuse the tool...",
                reg,
            )

    def edges(self):
        """Return the set of labelled edges in the data flow graph.
        Each labelled edge is represented as a triple of (src_id, dst_id, label).

        The ID of a virtual input/output node is "input/output_{name}" (as a string),
        while the ID of computation nodes corresponding to instructions in the input
        source is their original position, as an integer.
        """

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
        """The depth of the data flow graph.

        Equivalently, the maximum length of a dependency chain in the assembly source
        represented by the graph.
        """
        if self.nodes is None or len(self.nodes) == 0:
            return 1
        return max(t.depth for t in self.nodes)

    def _dump_instructions(self, txt, error=False):
        log_func = self.logger.debug if not error else self.logger.error
        log_func(txt)
        for idx, l in enumerate(self.src):
            log_func(" * %s: %s", idx, l[0][0].source_line.to_string())

    @property
    def arch(self):
        """The underlying architecturel model"""
        return self.config.arch

    def apply_cbs(self, cb, logger, one_a_time=False):
        """Apply callback to all nodes in the graph"""

        count = 0
        while True:
            count += 1
            assert (
                count < 100
            )  # There shouldn't be many repeated modifications to the CFG

            some_change = False

            for t in self.nodes:
                t.delete = False
                t.changed = False

            for t in self.nodes:
                if cb(t):
                    some_change = True
                    if one_a_time is True:
                        break

            if some_change is False:
                break

            z = filter(lambda x: x.delete is False, self.nodes)

            def pair_with_source(i):
                return ([i], i.source_line)

            def map_node(t):
                s = t.inst
                if not isinstance(t.inst, list):
                    s = [s]
                return map(pair_with_source, s)

            def flatten(llst):
                return [x for y in llst for x in y]

            z = flatten(map(map_node, z))

            self.src = list(z)

            # Otherwise, parse again
            changed = [t for t in self.nodes if t.changed is True]
            deleted = [t for t in self.nodes if t.delete is True]

            logger.debug(
                "Some instruction changed in callback -- need to build dataflow graph "
                "again..."
            )

            for t in deleted:
                logger.debug("* %s was deleted", t)
            for t in changed:
                logger.debug("* %s was changed", t)

            self._build_graph()

    def apply_parsing_cbs(self):
        """Apply parsing callbacks to all nodes in the graph.

        Typically, we only build the computation flow graph once. However, sometimes we
        make retrospective modifications to instructions afterwards, and then need to
        reparse.

        An example for this are jointly destructive instruction patterns: A sequence of
        instructions where each instruction individually overwrites only part of a
        register, but jointly they overwrite the register as a whole. In this case, we
        can remove the output register as an input dependency for the first instruction
        in the sequence, thereby creating more reordering and renaming flexibility.
        In this case, we change the instruction and then rebuild the computation flow
        graph.
        """
        logger = self.logger.getChild("parsing_cbs")

        def parsing_cb(t):
            return t.inst.global_parsing_cb(t, log=logger.info)

        return self.apply_cbs(parsing_cb, logger)

    def apply_fusion_cbs(self):
        """Apply fusion callbacks to nodes in the graph"""
        logger = self.logger.getChild("fusion_cbs")

        def fusion_cb(t):
            return t.inst.global_fusion_cb(t, log=logger.info)

        return self.apply_cbs(fusion_cb, logger, one_a_time=True)

    def _address_offset_fixup_cbs(self):
        logger = self.logger.getChild("address_fixup_cbs")

        def address_offset_cb(t, log=None):
            # Address offset fixup relaxes scheduling constraints
            # for load/store instructions with increment.
            if t.inst.is_load_store_instruction() is False:
                return False
            inc = getattr(t.inst, "increment", None)
            addr = getattr(t.inst, "addr", None)
            if inc is None or addr is None:
                return False

            # If the address is already marked as input-only,
            # don't do anything.
            #
            # TODO: This is only to gracefully deal with the case
            # of architecture models where address offset fixup is
            # still the default and ldr/str instructions with increment
            # unconditionally model their address registers as
            # input-only.
            if addr not in t.inst.args_in_out:
                return False

            idx = t.inst.args_in_out.index(addr)

            t.inst.args_in.append(addr)
            t.inst.arg_types_in.append(t.inst.arg_types_in_out[idx])
            t.inst.args_in_restrictions.append(t.inst.args_in_out_restrictions[idx])
            # TODO: Architecture-model-specific code does not belong here.
            if hasattr(t.inst, "pattern_inputs"):
                t.inst.pattern_inputs.append(t.inst.pattern_in_outs[idx])
            t.inst.num_in += 1

            del t.inst.args_in_out[idx]
            del t.inst.arg_types_in_out[idx]
            del t.inst.args_in_out_restrictions[idx]
            if hasattr(t.inst, "pattern_inputs"):
                del t.inst.pattern_in_outs[idx]
            t.inst.num_in_out -= 1

            if log is not None:
                log.info(f"Relaxed input-output argument {addr} of {t} to input-only")

            # Signal that something changed
            return True

        return self.apply_cbs(address_offset_cb, logger)

    def __init__(self, src: any, logger: any, config: any, parsing_cb: bool = True):
        self.logger = logger
        self.config = config
        self.src = self._parse_source(src)

        self._build_graph()

        if parsing_cb is True:
            self.apply_parsing_cbs()

        if config._unsafe_address_offset_fixup is True:
            self._address_offset_fixup_cbs()

        self._selfcheck_outputs()

    def _selfcheck_outputs(self):
        """Checks whether there are instructions whose output(s) are never used, but also
        not declared as outputs.
        """

        def flatten(llst):
            return [x for y in llst for x in y]

        def outputs_unused(t):
            has_outputs = t.inst.num_out + t.inst.num_in_out > 0
            outputs_unused = len(flatten(t.dst_out + t.dst_in_out)) == 0
            return has_outputs and outputs_unused

        useless_nodes = filter(outputs_unused, self.nodes)
        t = next(useless_nodes, None)
        if t is not None:
            ignore_useless_output = t.inst.source_line.tags.get(
                "ignore_useless_output", False
            )
            if (
                not self.config.allow_useless_instructions
                and ignore_useless_output is False
            ):
                self._dump_instructions("Source code", error=True)
                self.logger.error(
                    f"The result registers {t.inst.args_out + t.inst.args_in_out} "
                    f"of instruction {t.id}:[{t.inst}] are neither used "
                    "nor declared as global outputs."
                )
                self.logger.error(
                    "This is often a configuration error. Did you miss an output "
                    "declaration?"
                )
                self.logger.error(
                    "Currently configured outputs: %s", list(self.outputs)
                )
                raise SlothyUselessInstructionException("Useless instruction detected")

            self.logger.warning(
                f"The result registers {t.inst.args_out + t.inst.args_in_out} "
                f"of instruction {t.id}:[{t.inst}] are neither used "
                "nor declared as global outputs."
            )
            self.logger.warning(
                "Ignoring this as requested by `config.allow_useless_instructions`!"
            )

    def _parse_line(self, line):
        assert SourceLine.is_source_line(line)
        insts = self.arch.Instruction.parser(line)
        # Remember options from source line
        # TODO: Might not be the right place to remember options
        for inst in insts:
            inst.source_line = line
        return (insts, line)

    def _parse_source(self, src):
        # prepare source lines for parsing
        src_lines = SourceLine.reduce_source(src)
        src_lines = SourceLine.unify_source(src_lines)
        return list(map(self._parse_line, src_lines))

    def iter_dependencies(self):
        """Returns an iterator over all dependencies in the data flow graph.

        Each returned element has the form (consumer, producer, ty, idx), representing a
        dependency from output producer to the idx-th input (if ty=="in") or input/output
        (if ty=="inout") of consumer. The producer field is an instance of RegisterSource
        and contains the output index and source instruction as producer.idx and
        producer.src, respectively.
        """
        for consumer in self.nodes_all:
            for idx, producer in enumerate(consumer.src_in):
                yield (consumer, producer, "in", idx)
            for idx, producer in enumerate(consumer.src_in_out):
                yield (consumer, producer, "inout", idx)

    def _typecheck_node(self, s):
        # We maintain a typing dictionary capturing what we think the type
        # of certain (symbolic) registers should be. Here, we check whether
        # an instruction signature typechecks with respect to this dictionary.
        #
        # For example, in MVE, if we believe that `const` is a GPR, then only
        # only the only way to parse `vmul q0, q0, const` is via the scalar-vector
        # variant of vmul, while attempting to parse it as an instance of the
        # vector-vector variant would fail the type check.
        self.logger.debug("Typecheck instruction %s", s)

        def _check_list(types, names):
            for ty, name in zip(types, names):
                self.logger.debug(" - argument %s of type %s", name, ty)
                expectations = []
                # Check if we know the type from the dictionary
                if name in self.reg_state:
                    exp_ty = self.reg_state[name].get_type()
                    self.logger.debug(
                        "   + type of %s in state dictionary: %s", name, exp_ty
                    )
                    expectations.append((f"State dictionary: {exp_ty}", exp_ty))
                else:
                    self.logger.debug("    + %s not in state dictionary", name)
                exp_ty = self.arch.RegisterType.find_type(name)
                if exp_ty is not None:
                    self.logger.debug(
                        f"   + type of {name} according to model: {exp_ty}"
                    )
                    expectations.append((f"Model: {exp_ty}", exp_ty))

                # Check if all our expectations match the type recorded in the
                # instruction signature. Note that this also works in the case
                # where we don't have any type expectation, as all([]) == True.
                for fail in [msg for (msg, exp) in expectations if exp != ty]:
                    self.logger.debug(
                        "Typecheck for %s failed -- mismatch: %s", name, fail
                    )
                    return False
            return True

        return _check_list(s.arg_types_in, s.args_in) and _check_list(
            s.arg_types_in_out, s.args_in_out
        )

    def describe(self, *, error=False):
        """Send a description of the data flow graph to the logger"""
        log_func = self.logger.error if error else self.logger.debug
        for t in self.nodes_all:
            for d in t.describe():
                log_func(d)

    def update_inputs(self):
        """After change to output registers of some nodes, update all
        dependent nodes"""
        for t in self.nodes_all:
            for i, v in enumerate(t.src_in):
                t.inst.args_in[i] = v.reduce().name()
            for i, v in enumerate(t.src_in_out):
                t.inst.args_in_out[i] = v.reduce().name()

    def has_symbolic_registers(self):
        rt = self.config._arch.RegisterType
        for i in self.nodes:
            instr = i.inst
            for out, ty in zip(instr.args_out, instr.arg_types_out):
                if out not in rt.list_registers(ty):
                    return True
            for inout, ty in zip(instr.args_in_out, instr.arg_types_in_out):
                if inout not in rt.list_registers(ty):
                    return True
        return False

    def find_all_predecessors_input_registers(self, consumer, register_name):
        """recursively finds the set of input registers registers that a certain value
        depends on."""
        # ignore the stack pointer
        if register_name == "sp":
            return set()

        producer = consumer.reg_state[register_name].src
        # if this is a virtual input instruction this is an actual input
        # otherwise this is computed from other inputs
        if isinstance(producer.inst, VirtualInputInstruction):
            return set(producer.inst.args_out)
        else:
            # go through all predecessors and recursively call this function
            # Note that we only care about inputs (i.e., produced by a
            # VirtualInputInstruction)
            regs = []
            if hasattr(producer.inst, "args_in"):
                regs += producer.inst.args_in
            if hasattr(producer.inst, "args_in_out"):
                regs += producer.inst.args_in_out
            predecessors = set()
            for reg in regs:
                predecessors = predecessors.union(
                    self.find_all_predecessors_input_registers(producer, reg)
                )
            return set(predecessors)

    def ssa(self, filter_func=None):
        """Transform data flow graph into single static assignment (SSA) form."""
        # Go through non-virtual instruction nodes and assign unique names to
        # output registers which are not global outputs.
        out_cnt = 0

        def get_fresh_reg():
            nonlocal out_cnt
            res = f"ssa_{out_cnt}"
            out_cnt += 1
            return res

        # List all instructions producing global outputs
        outputs = self.nodes_output
        no_ssa = []
        for out in outputs:
            producer = out.src_in[0].reduce()
            if producer.src.is_virtual_input:
                continue
            no_ssa.append((producer.src, producer.idx))

        for idx, t in enumerate(self.nodes):
            for i, c in enumerate(t.inst.args_out):
                if c in self.config._locked_registers or (t, i) in no_ssa:
                    continue
                if filter_func is not None and filter_func(t, i) is False:
                    continue
                t.inst.args_out[i] = get_fresh_reg()

        # Propagate change in register allocation to all dependent nodes
        self.update_inputs()

    def _build_graph(self):
        self.reg_state = {}
        self.spilled_reg_state = {}
        self._typing_dict = {}
        self._nodes_all = []

        # Process source and add one instruction a time to the data flow graph
        for c, s in self.src:
            self._add_node_from_candidates(c, s)

        # Mark inputs as outputs if desired
        outputs = set(self.config.outputs.copy())
        if self.config.inputs_are_outputs:
            outputs.update(self.inputs)

        # Add virtual computation nodes for outputs
        for out in outputs:
            self._add_node_from_candidates(
                [VirtualOutputInstruction(out, ty) for ty in self.arch.RegisterType],
                f"<output:{out}>",
            )

        self.logger.debug("Dumping computational flow graph")
        self.describe()

    def _add_node_from_candidates(self, candidates, sourceline):
        valid_candidates = list(filter(self._typecheck_node, candidates))
        num_valid_candidates = len(valid_candidates)
        if num_valid_candidates == 0:
            raise DataFlowGraphException(
                f"None of the candidate parsings for {sourceline} type checks!"
                f"\nCandidates\n{candidates}"
            )
        # If we have more than one instruction passing the type check,
        # then we need more typing information from the user.
        #
        # An example from MVE would be `vmul q0, q0, const` if we do _not_ have any
        # information on the type of `const` -- it could be either a GPR or a vector.
        if num_valid_candidates > 1:
            self.logger.error(
                "Source line %s can be parsed in multiple ways:", sourceline
            )
            for c in candidates:
                self.logger.error("* %s", c)
            raise DataFlowGraphException("Parsing failure during type checking")
        # Add the single valid candidate parsing to the CFG
        self._add_node(valid_candidates[0])

    def _find_source_single(self, ty, name):
        self.logger.debug("Finding source of register %s of type %s", name, ty)

        # Check if the inputs have been produced by the data flow graph
        if name not in self.reg_state:
            # If not, treat them as a global input
            self.logger.debug("-> %s is a global input", name)
            # Create a virtual instruction producing the output add that first
            # Since the virtual instruction does not have any inputs, there is
            # no risk of infinite recursion here
            self._add_node(VirtualInputInstruction(name, ty))
            # Fall through

        # At this point, the source _must_ be produced by an instruction in the graph
        assert name in self.reg_state

        # Return a reference to the node producing the input
        origin = self.reg_state[name]
        self.logger.debug(f"-> {name} has been produced by {origin}")

        if origin.get_type() != ty:
            warnstr = (
                f"Type mismatch: Output {name} of {type(origin.src.inst).__name__} has "
                f"type {origin.get_type()} but {type(self).__name__} expects it to have"
                f"type {ty}"
            )
            self.logger.debug(warnstr)
            raise DataFlowGraphException(warnstr)

        return self.reg_state[name]

    def _process_restore_instruction(self, reg, loc):
        assert loc in self.spilled_reg_state.keys()
        self.reg_state[reg] = self.spilled_reg_state.pop(loc)

    def _process_spill_instruction(self, reg, loc, ty):
        assert loc not in self.spilled_reg_state.keys()
        self.spilled_reg_state[loc] = self._find_source_single(ty, reg)

    def _add_node(self, s: any):
        """
        Add a node to the dataflow graph

        :param s: Instruction to be added to the graph. This may be a single
            instruction of a list of candidate instructions, in case the
            parsing wasn't unambiguous.
        :type s: any
        """

        if not isinstance(s, VirtualInstruction):
            # Check if the instruction is tagged as a spill or restore instruction
            # Those instructions are not inserted into the DFG but merely interpreted
            # as redirections
            if (
                self.config._absorb_spills is True
                and s.source_line.tags.get("is_spill", False) is True
            ):
                self.logger.debug("Handling spill instruction: %s", s)
                reg = s.args_in[0]
                loc = s.args_out[0]
                ty = s.arg_types_in[0]
                self._process_spill_instruction(reg, loc, ty)
                return
            if (
                self.config._absorb_spills is True
                and s.source_line.tags.get("is_restore", False) is True
            ):
                self.logger.debug("Handling restore instruction: %s", s)
                loc = s.args_in[0]
                reg = s.args_out[0]
                self._process_restore_instruction(reg, loc)
                return

            self.logger.debug("Adding instruction to CFG: %s", s)

        elif isinstance(s, VirtualInputInstruction):
            self.logger.debug("Adding virtual instruction for input %s", s.orig_reg)
        elif isinstance(s, VirtualOutputInstruction):
            self.logger.debug("Adding virtual instruction for output %s", s.orig_reg)

        def find_sources(types, names):
            return [self._find_source_single(t, n) for t, n in zip(types, names)]

        # Lookup computation nodes for inputs
        src_in = find_sources(s.arg_types_in, s.args_in)
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

        step = ComputationNode(
            node_id=s_id,
            orig_pos=orig_pos,
            inst=s,
            src_in=src_in,
            src_in_out=src_in_out,
        )
        step.reg_state = self.reg_state.copy()

        def change_reg_ref(reg, ref):
            self._remember_type(reg, ref.get_type())
            self.reg_state[o] = ref

        for i, o in enumerate(s.args_out):
            change_reg_ref(o, InstructionOutput(step, i))
        for i, o in enumerate(s.args_in_out):
            change_reg_ref(o, InstructionInOut(step, i))

        self.nodes_all.append(step)

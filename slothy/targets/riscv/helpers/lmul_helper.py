"""This module contains helper functions to deal with LMUL"""

import itertools
from slothy.targets.riscv.riscv import RegisterType
from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction

def _get_lmul_value(obj=None):
    """Get LMUL value from instruction object or any loaded RISC-V target module"""
    import sys

    # Try to get from instruction object first
    if obj is not None:
        lmul = getattr(obj, "lmul", None)
        if lmul is not None:
            return _parse_lmul_string(lmul)

    # Try to get from any loaded RISC-V target module
    for module_name, module in sys.modules.items():
        if (
            module_name.startswith("slothy.targets.riscv.")
            and hasattr(module, "lmul")
            and module.lmul is not None
        ):
            return _parse_lmul_string(module.lmul)

    return 1  # Default


def _parse_lmul_string(lmul):
    """Parse LMUL string (e.g., 'm2', 'm4', 'm8', 'mf2', 'mf4', 'mf8') to integer"""
    if isinstance(lmul, str):
        if lmul.startswith("m") and not lmul.startswith("mf"):
            lmul = int(lmul[1:])  # e.g., "m2" -> 2
        elif lmul.startswith("mf"):
            lmul = 1  # Fractional LMUL, treat as 1 for now
        else:
            lmul = 1

    # Ensure LMUL is valid
    if lmul not in [1, 2, 4, 8]:
        lmul = 1

    return lmul


def _expand_vector_registers_generic(
    obj: any,
    expansion_factor: int,
    expand_output_indices: list = None,
    expand_input_indices: list = None,
) -> any:
    """
    Expand vector registers based on expansion factor for vector instructions.

    Groups consecutive vector registers together based on the expansion factor
    (LMUL or NF value):

      - With expansion=2: ``v8`` becomes [``v8, v9``], ``v4`` becomes [``v4, v5``]
      - With expansion=4: ``v8`` becomes [``v8, v9, v10, v11``]

    This function:

    #. Automatically detects which operands are vector registers
    #. Expands vector operands into register groups
    #. Preserves scalar/immediate operands unchanged
    #. Sets up constraint combinations for SLOTHY's register allocator
    #. Allows selective expansion of specific operands (useful for masked instructions)

    :param obj: Instruction object to modify
    :type obj: any
    :param expansion_factor: Expansion value (LMUL or NF value)
    :type expansion_factor: int
    :param expand_output_indices: Indices of outputs to expand (None = expand all vector outputs)
    :type expand_output_indices: list
    :param expand_input_indices: Indices of inputs to expand (None = expand all vector inputs)
    :type expand_input_indices: list
    :return: modified obj
    :rtype: any
    """

    if expansion_factor <= 1:
        return obj

    available_regs = RegisterType.list_registers(RegisterType.VECT)

    def is_vector_register(reg):
        """Check if a register is a vector register."""
        return reg in available_regs

    def expand_vector_register(reg):
        """Expand a vector register into a group of consecutive registers."""
        if not is_vector_register(reg):
            return [reg]  # Not a vector register, keep as-is

        start_idx = available_regs.index(reg)
        if start_idx + expansion_factor > len(available_regs):
            return [reg]  # Not enough consecutive registers, keep original

        return [available_regs[start_idx + i] for i in range(expansion_factor)]

    def expand_register_list(orig_args, orig_arg_types, expand_indices):
        """Expand a list of registers, tracking expansion info for constraints.

        :param expand_indices: Indices to expand (None = expand all vectors)
        """
        expanded_args = []
        new_arg_types = []
        constraint_indices = []
        num_vectors = 0
        expanded_idx = 0

        for i, reg in enumerate(orig_args):
            should_expand = (
                is_vector_register(reg) and
                (expand_indices is None or i in expand_indices)
            )

            if should_expand:
                expanded_regs = expand_vector_register(reg)
                expanded_args.extend(expanded_regs)
                new_arg_types.extend([RegisterType.VECT] * len(expanded_regs))
                constraint_indices.extend(
                    range(expanded_idx, expanded_idx + len(expanded_regs))
                )
                expanded_idx += len(expanded_regs)
                num_vectors += 1
            else:
                expanded_args.append(reg)
                new_arg_types.append(orig_arg_types[i])
                expanded_idx += 1

        return expanded_args, new_arg_types, constraint_indices, num_vectors

    def generate_combinations():
        """Generate all possible register group combinations (aligned groups)."""
        return [
            [available_regs[i + j] for j in range(expansion_factor)]
            for i in range(0, len(available_regs), expansion_factor)
            if i + expansion_factor <= len(available_regs)
        ]

    # Expand outputs and inputs
    expanded_outputs, new_arg_types_out, output_constraint_indices, _ = (
        expand_register_list(obj.args_out, obj.arg_types_out, expand_output_indices)
    )
    expanded_inputs, new_arg_types_in, input_constraint_indices, num_vector_inputs = (
        expand_register_list(obj.args_in, obj.arg_types_in, expand_input_indices)
    )

    # Update instruction object
    obj.args_out = expanded_outputs
    obj.args_in = expanded_inputs
    obj.num_out = len(expanded_outputs)
    obj.num_in = len(expanded_inputs)
    obj.arg_types_out = new_arg_types_out
    obj.arg_types_in = new_arg_types_in

    # Set up register allocation constraints
    valid_combinations = generate_combinations()

    if output_constraint_indices:
        obj.args_out_combinations = [(output_constraint_indices, valid_combinations)]

    if input_constraint_indices:
        # Generate combinations for multiple vector inputs using Cartesian product
        multi_combinations = [
            [reg for combo in combination for reg in combo]
            for combination in itertools.product(
                valid_combinations, repeat=num_vector_inputs
            )
        ]
        obj.args_in_combinations = [(input_constraint_indices, multi_combinations)]

    # Set up empty restrictions
    obj.args_out_restrictions = [None] * obj.num_out
    obj.args_in_restrictions = [None] * obj.num_in

    return obj


def _extract_base_registers(
    args_list: list, expansion_factor: int, num_expandable: int
) -> list:
    """Extract base registers from expanded register groups.

    :param args_list: List of register arguments
    :type args_list: list
    :param expansion_factor: LMUL or NF expansion factor
    :type expansion_factor: int
    :param num_expandable: Number of expandable register groups
    :type num_expandable: int
    :returns: List of base registers for display
    :rtype: list
    """
    if not args_list or expansion_factor == 1:
        return args_list.copy()

    display_args = []
    idx = 0

    # Extract first register from each expandable group
    for _ in range(num_expandable):
        if idx < len(args_list):
            display_args.append(args_list[idx])
            idx += expansion_factor

    # Add remaining non-expandable registers
    display_args.extend(args_list[idx:])
    return display_args


def _write_expanded_instruction(
    self: any,
    expansion_factor: int,
    num_expandable_vector_inputs: int,
) -> any:
    """Custom write method for expanded instructions that shows only base registers.

    Works for both LMUL and NF expansion, handles cases with:

    - Only expanded outputs (load instructions)
    - Only expanded inputs (store instructions)
    - Both expanded inputs and outputs

    :param self: self
    :type self: any
    :param expansion_factor: The LMUL or NF expansion factor
    :type expansion_factor: int
    :param num_expandable_vector_inputs:
      Number of vector inputs that get expanded
      (excludes mask registers and other non-expandable vectors)
    :type num_expandable_vector_inputs: int
    :returns: Formatted instruction string with base registers only
    :rtype: any
    """
    # Early return for simple case
    if expansion_factor <= 1:
        return RISCVInstruction.write(self)

    # Check if we have expansion (either inputs or outputs)
    has_expansion = expansion_factor > 1
    has_expanded_inputs = (
        has_expansion
        and num_expandable_vector_inputs > 0
        and len(self.args_in) > num_expandable_vector_inputs
    )
    has_expanded_outputs = has_expansion and len(self.args_out) > 1

    if has_expanded_inputs or has_expanded_outputs:
        out = self.pattern

        # Extract base registers for display
        display_args_out = _extract_base_registers(
            self.args_out, expansion_factor if has_expanded_outputs else 1, 1
        )
        display_args_in = _extract_base_registers(
            self.args_in,
            expansion_factor if has_expanded_inputs else 1,
            num_expandable_vector_inputs,
        )

        l = (
            list(zip(display_args_in, self.pattern_inputs))
            + list(zip(display_args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )

        for arg, (s, ty) in l:
            out = RISCVInstruction._instantiate_pattern(s, ty, arg, out)

        # Handle other pattern replacements
        # TODO: split default write method and use parts here
        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x

            if t is None:
                t = t_default
            a = getattr(self, attr_name)
            if a is None and attr_name == "is32bit":
                return txt.replace("<w>", "")
            if a is None:
                return txt
            if not isinstance(a, list):
                txt = txt.replace(f"<{mnemonic_key}>", t(a))
                return txt
            for i, v in enumerate(a):
                txt = txt.replace(f"<{mnemonic_key}{i}>", t(v))
            return txt

        out = replace_pattern(out, "immediate", "imm", lambda x: f"{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "is32bit", "w", lambda x: x.lower())
        out = replace_pattern(out, "len", "len")
        out = replace_pattern(out, "vm", "vm")
        out = replace_pattern(out, "vtype", "vtype")
        out = replace_pattern(out, "sew", "sew")
        out = replace_pattern(out, "lmul", "lmul")
        out = replace_pattern(out, "tpol", "tpol")
        out = replace_pattern(out, "mpol", "mpol")
        out = replace_pattern(out, "nf", "nf")
        out = replace_pattern(out, "ew", "ew")

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out

    # Should not reach here, but fallback to default behavior
    return RISCVInstruction.write(self)


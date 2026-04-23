#
# Copyright (c) 2024 Justus Bergermann
# Copyright (c) 2024 Amin Abdulrahman
#
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
# Authors: Justus Bergermann <mail@justus-bergermann.de>
#          Amin Abdulrahman <amin@abdulrahman.de>
#

"""This module contains abstract RISC-V instruction types to represent
instructions which share the same pattern"""

from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction
from slothy.targets.riscv.helpers.lmul_helper import (
    _get_lmul_value,
    _write_expanded_instruction,
    _expand_vector_registers_generic,
)


def _add_vtype_input(obj):
    """Append an implicit vtype CSR input dependency to a vector instruction."""
    #obj.args_in.append("vtype")
    #obj.arg_types_in.append(RISCVInstruction._infer_register_type("Cvtype"))
    #obj.num_in += 1
    #obj.args_in_restrictions.append(None)
    return obj


class RISCVScalarInstruction(RISCVInstruction):
    pass


class RISCVStore(RISCVScalarInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[1]
        return obj

    pattern = "mnemonic <Xb>, <imm>(<Xa>)"
    inputs = ["Xb", "Xa"]


# Scalar instructions


class RISCVIntegerRegister(RISCVScalarInstruction):
    pattern = "mnemonic <Xd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVIntegerRegisterImmediate(RISCVScalarInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVIntegerRegisterRegister(RISCVScalarInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class RISCVLoad(RISCVScalarInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    pattern = "mnemonic <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVUType(RISCVScalarInstruction):
    pattern = "mnemonic <Xd>, <imm>"
    outputs = ["Xd"]


class RISCVIntegerRegisterRegisterMul(RISCVScalarInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class RISCVBranch(RISCVScalarInstruction):
    """RISC-V branch instructions with two register operands and a label"""

    pattern = "mnemonic <Xa>, <Xb>, <label>"
    inputs = ["Xa", "Xb"]
    outputs = []

    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.immediate = None
        # Initialize label attribute to avoid AttributeError
        if not hasattr(obj, "label"):
            obj.label = None
        return obj


# =============================================================================
# Vector instructions ####
# =============================================================================

# Load Instructions ##


class RISCVVectorInstruction(RISCVInstruction):
    def write(self, nf=False, _num_expandable_vector_inputs=0):
        if nf:
            expansion_factor = int(self.nf)
        else:
            # Use the factor stored at parse/expand time; fall back to global if missing.
            expansion_factor = getattr(self, "_expansion_factor", None)
            if expansion_factor is None:
                expansion_factor = _get_lmul_value(self)
        return _write_expanded_instruction(
            self, expansion_factor, _num_expandable_vector_inputs
        )

    @classmethod
    def make(cls, src, nf=False):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.addr = obj.args_in[0]
        if nf:
            expansion_factor = int(obj.nf)
        else:
            expansion_factor = _get_lmul_value(obj)

        return _add_vtype_input(_expand_vector_registers_generic(obj, expansion_factor))


class RISCVVectorFixedMaskedIstruction(RISCVVectorInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        lmul = _get_lmul_value(obj)

        # Note: mask register (Vg) is not expanded, only vector operands
        obj = _expand_vector_registers_generic(
            obj, lmul, expand_input_indices=[i for i in range(len(obj.args_in) - 1)]
        )
        # Fix Vg to v0 manually

        if lmul > 1:
            obj.args_in_combinations[0][0].append(
                len(obj.args_in) - 1
            )  # extend indice by one for v0
            for comb in obj.args_in_combinations[0][1]:
                comb.append("v0")  # add fixed v0 to all combinations at the very end
        else:
            # No expansion: Vg is the 3rd input (index 2); restrict it to v0
            obj.args_in_restrictions[len(obj.args_in) - 1] = ["v0"]
            # TODO: May v0 be used in the other input/output registers? Potentially
            # filter here.
        return _add_vtype_input(obj)


class RISCVVectorLoadUnitStride(RISCVVectorInstruction):  # done
    pattern = "mnemonic <Vd>, (<Xa>)<vm>"
    inputs = ["Xa"]
    outputs = ["Vd"]
    # TODO: declare input register if vm (mask) is used


class RISCVVectorLoadStrided(RISCVVectorInstruction):  # done
    pattern = "mnemonic <Vd>, (<Xa>), <Xb><vm>"
    inputs = ["Xa", "Xb"]
    outputs = ["Vd"]
    # TODO: declare input register if vm (mask) is used


class RISCVVectorLoadIndexed(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, (<Xa>), <Ve><vm>"
    inputs = ["Xa", "Ve"]
    outputs = ["Vd"]
    # TODO: declare input register if vm (mask) is used


class RISCVVectorLoadWholeRegister(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(nf=True)

    @classmethod
    def make(cls, src):
        return super().make(src, nf=True)

    pattern = "mnemonic <Vd>, (<Xa>)"
    inputs = ["Xa"]
    outputs = ["Vd"]


# Store Instructions ##


class RISCVVectorStoreUnitStride(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Va>, (<Xa>)<vm>"
    inputs = ["Xa", "Va"]
    outputs = []


class RISCVVectorStoreStrided(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Va>, (<Xa>), <Xb><vm>"
    inputs = ["Xa", "Xb", "Va"]


class RISCVVectorStoreIndexed(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=2)

    pattern = "mnemonic <Va>, (<Xa>), <Ve><vm>"
    inputs = ["Xa", "Ve", "Va"]


class RISCVVectorStoreWholeRegister(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(nf=True, _num_expandable_vector_inputs=1)

    @classmethod
    def make(cls, src):
        return super().make(src, nf=True)

    pattern = "mnemonic <Vd>, (<Xa>)"
    inputs = ["Vd", "Xa"]


# Vector Integer Instructions ##


class RISCVVectorIntegerVectorVector(RISCVVectorInstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=2)

    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        if "gather" in src:
            obj.args_in_out_different = [(0, 0), (0, 1)]  # Can't have Rd==Ra
        lmul = _get_lmul_value(obj)
        return _add_vtype_input(_expand_vector_registers_generic(obj, lmul))

    pattern = "mnemonic <Vd>, <Ve>, <Vf><vm>"
    inputs = ["Ve", "Vf"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorVectorMasked(RISCVVectorFixedMaskedIstruction):  # done
    def write(self):
        return super().write(_num_expandable_vector_inputs=2)

    pattern = "mnemonic <Vd>, <Ve>, <Vf>, <Vg>"  # Vg == v0
    inputs = ["Ve", "Vf", "Vg"]  # mask register MUST be the very last one
    outputs = ["Vd"]


class RISCVVectorIntegerVectorScalar(RISCVVectorInstruction):  # maybe done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    # TODO: make method here?

    pattern = "mnemonic <Vd>, <Ve>, <Xa><vm>"
    inputs = ["Ve", "Xa"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorScalarMasked(
    RISCVVectorFixedMaskedIstruction
):  # maybe done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Ve>, <Xa>, <Vg>"  # Vg == v0
    inputs = ["Ve", "Xa", "Vg"]
    outputs = ["Vd"]


class RISCVVectorIntegerVectorImmediate(RISCVVectorInstruction):  # maybe done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Ve>, <imm><vm>"
    inputs = ["Ve"]
    outputs = ["Vd"]


# mask is fixed to v0
class RISCVVectorIntegerVectorImmediateMasked(
    RISCVVectorFixedMaskedIstruction
):  # maybe done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Ve>, <imm>, <Vg>"
    inputs = ["Ve", "Vg"]
    outputs = ["Vd"]


# Vector Permutation Instructions


class RISCVScalarVector(RISCVVectorInstruction):  # maybe done
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Xd>, <Ve>"
    inputs = ["Ve"]
    outputs = ["Xd"]


class RISCVVectorScalar(RISCVVectorInstruction):  # maybe done
    pattern = "mnemonic <Vd>, <Xa>"
    inputs = ["Xa"]
    outputs = ["Vd"]


class RISCVVectorVector(RISCVVectorInstruction):
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Va>"
    inputs = ["Va"]
    outputs = ["Vd"]


class RISCVectorVectorMasked(RISCVVectorInstruction):
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Va><vm>"
    inputs = ["Va"]
    outputs = ["Vd"]


# Vector Integer Multiply-Add


class RISCVVectorScalarVector(RISCVVectorInstruction):
    def write(self):
        return super().write(_num_expandable_vector_inputs=1)

    pattern = "mnemonic <Vd>, <Xa>, <Va>"
    inputs = ["Xa", "Va"]
    in_outs = ["Vd"]

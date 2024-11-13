from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction

class RISCVStoreInstruction(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj

    inputs = ["Xa", "Xb"]

class RISCVShift(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVLogical(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVLogicalShifted(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVConditionalCompare(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVConditionalSelect(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVMove(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVHighMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class RISCVMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""

class Tst(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pattern = ""
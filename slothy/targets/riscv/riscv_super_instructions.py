from slothy.targets.riscv.abstract_riscv_instruction import RISCVInstruction

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
    pass

class RISCVLogical(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVLogicalShifted(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVConditionalCompare(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVConditionalSelect(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVMove(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVHighMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class RISCVMultiply(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass

class Tst(RISCVInstruction): # pylint: disable=missing-docstring,invalid-name
    pass
from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction

class RISCVStore(RISCVInstruction):
    @classmethod
    def make(cls, src):
        obj = RISCVInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = None
        obj.addr = obj.args_in[1]
        return obj
    pattern = "mnemonic <Xb>, <imm>(<Xa>)"
    inputs = ["Xa", "Xb"]

class RISCVIntegerRegisterImmediate(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]

class RISCVIntegerRegisterRegister(RISCVInstruction):
    pattern = "mnemonic <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]

class RISCVLoad(RISCVInstruction):
    pattern = "mnemonic <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]

class RISCVUType(RISCVInstruction):
    pattern = "mnemonic <Xd>, <imm>"
    outputs = ["Xd"]
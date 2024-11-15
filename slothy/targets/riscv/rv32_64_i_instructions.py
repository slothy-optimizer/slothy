from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.riscv_super_instructions import *

dynamic_instr_classes = []  # list of all rv32_64_i instruction classes
classes_by_names = {}  # dict of all classes with keys = class names

IntegerRegisterImmediateInstructions = ["addi<w>", "slti", "sltiu", "andi", "ori", "xori", "slli<w>", "srli<w>", "srai<w>"]
IntegerRegisterRegisterInstructions = ["and", "or", "xor", "add<w>", "slt", "sltu", "sll<w>", "srl<w>", "sub<w>", "sra<w>"]
LoadInstructions = ["lb", "lbu", "lh", "lhu", "lw", "lwu", "ld"]
StoreInstructions = ["sb", "sh", "sw", "sd"]
UTypeInstructions = ["lui", "auipc"]

PythonKeywords = ["and", "or"]  # not allowed as class names

def instr_factory(instr_list, baseclass, inputs=[], outputs=[]):
    """
    Dynamically creates instruction classes from a list, inheriting from a given super class. This method allows
    to create classes for instructions with common pattern, inputs and outputs at one go. Usually, a lot of instructions
    share the same structure.
    """
    for instr in instr_list:
        classname = instr
        if "<w>" in instr:
            classname = instr.split("<")[0]
        if instr in PythonKeywords:
            classname = classname + "cls"
        dynamic_instr_classes.append(type(classname, (baseclass, Instruction),
                                          {'pattern': baseclass.pattern.replace("mnemonic", instr)}))
    return dynamic_instr_classes

def generate_rv32_64_i_instructions():
    """
    Generates all instruction classes for the rv32_64_i extension set
    """
    instr_factory(IntegerRegisterImmediateInstructions, RISCVIntegerRegisterImmediate)
    instr_factory(IntegerRegisterRegisterInstructions, RISCVIntegerRegisterRegister)
    instr_factory(LoadInstructions, RISCVLoad)
    instr_factory(StoreInstructions, RISCVStore)
    instr_factory(UTypeInstructions, RISCVUType)
    classes_by_names.update({cls.__name__: cls for cls in dynamic_instr_classes})
    return dynamic_instr_classes

generate_rv32_64_i_instructions()
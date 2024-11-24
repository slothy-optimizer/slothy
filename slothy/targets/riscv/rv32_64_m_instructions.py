from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.riscv_super_instructions import *


# the following lists maybe could be encapsulated somehow
IntegerRegisterRegisterInstructions = ["mul<w>", "mulh", "mulhsu", "mulhu", "div<w>", "divu<w>", "rem<w>", "remu<w>"]

PythonKeywords = ["and", "or"]  # not allowed as class names

# TODO: Move to Instruction class?
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
        RISCVInstruction.dynamic_instr_classes.append(type(classname, (baseclass, Instruction),
                                          {'pattern': baseclass.pattern.replace("mnemonic", instr)}))
    return RISCVInstruction.dynamic_instr_classes

def generate_rv32_64_m_instructions():
    """
    Generates all instruction classes for the rv32_64_i extension set
    """
    instr_factory(IntegerRegisterRegisterInstructions, RISCVIntegerRegisterRegisterMul)
    RISCVInstruction.classes_by_names.update({cls.__name__: cls for cls in RISCVInstruction.dynamic_instr_classes})
    return RISCVInstruction.dynamic_instr_classes

generate_rv32_64_m_instructions()
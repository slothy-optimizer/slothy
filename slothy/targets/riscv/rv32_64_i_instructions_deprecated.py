from slothy.targets.riscv.instruction_core import Instruction
from slothy.targets.riscv.riscv_super_instructions import *

###########################################
# Integer Register-Immediate Instructions #
###########################################

##########
# I-Type #
##########
dynamic_instr_classes = []
#class addi(RISCVInstruction):
#    """
#    Add immediate

#    Adds the sign-extended 12-bit immediate to register rs1. Arithmetic overflow is ignored and the result is simply the
#    low XLEN bits of the result. ADDI rd, rs1, 0 is used to implement the MV rd, rs1 assembler pseudo-instruction.
#    """

#    pattern = "addi<w> <Xd>, <Xa>, <imm>"
#    inputs = ["Xa"]
#    outputs = ["Xd"]


class slti(RISCVInstruction):
    """
    Set less than immediate

    Place the value 1 in register Xd if register Xa is less than the signextended immediate when both are treated as
    signed numbers, else 0 is written to rd.
    """

    pattern = "slti <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class sltiu(RISCVInstruction):
    """
    Set less than immediate unsigned

    Place the value 1 in register Xd if register Xa is less than the signextended immediate when both are treated as
    unsigned numbers, else 0 is written to rd.
    """

    pattern = "sltiu <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class andi(RISCVInstruction):
    """
    AND immediate

    Performs bitwise AND on register Xa and the sign-extended 12-bit immediate and place the result in Xd
    """

    pattern = "andi <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class ori(RISCVInstruction):
    """
    OR immediate

    Performs bitwise OR on register Xa and the sign-extended 12-bit immediate and place the result in Xd
    """

    pattern = "ori <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class xori(RISCVInstruction):
    """
    XOR immediate

    Performs bitwise XOR on register Xa and the sign-extended 12-bit immediate and place the result in Xd.
    Note, XORI Xa, Xb, -1 performs a bitwise logical inversion of register Xa
    """

    pattern = "xori <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


##################
# Special I-Type #
##################
"""
Shifts by a constant are encoded as a specialization of the I-type format. The operand to be shifted is in rs1,
and the shift amount is encoded in the lower 5 bits of the I-immediate field. The right shift type is encoded
in bit 30.
"""


class slli(RISCVInstruction):
    """
    Logical left shift by immediate

    Performs logical left shift on the value in register Xa by the shift amount held in the lower 5 bits of the immediate.
    In RV64, bit-25 is used to shamt[5].
    """

    pattern = "slli<w> <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class srli(RISCVInstruction):
    """
    Logical right shift by immediate

    Performs logical right shift on the value in register Xa by the shift amount held in the lower 5 bits of the immediate.
    In RV64, bit-25 is used to shamt[5].
    """

    pattern = "srli<w> <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class srai(RISCVInstruction):
    """
    Arithmetic right shift by immediate

    Performs arithmetic right shift on the value in register Xa by the shift amount held in the lower 5 bits of the
    immediate. In RV64, bit-25 is used to shamt[5].
    """

    pattern = "srai<w> <Xd>, <Xa>, <imm>"
    inputs = ["Xa"]
    outputs = ["Xd"]


##########
# U-Type #
##########

class lui(RISCVInstruction):
    # is the input/ output register special here?
    """
    Load upper immediate

    Build 32-bit constants and uses the U-type format. LUI places the U-immediate value in the top 20 bits of the
    destination register Xd, filling in the lowest 12 bits with zeros.
    """

    pattern = "lui <Xd>, <imm>"
    outputs = ["Xd"]


class auipc(RISCVInstruction):
    # is the input/ output register special here?
    """
    Load upper immediate to pc

    Build pc-relative addresses and uses the U-type format. AUIPC forms a 32-bit offset from the 20-bit U-immediate,
    filling in the lowest 12 bits with zeros, adds this offset to the pc, then places the result in register Xd.
    """

    pattern = "auipc <Xd>, <imm>"
    outputs = ["Xd"]


###########################################
# Integer Register-Register Instructions #
###########################################

##########
# R-Type #
##########

class add(RISCVInstruction):
    """
    Add two registers

    Adds the registers Xa and Xb and stores the result in Xd.
    Arithmetic overflow is ignored and the result is simply the low XLEN bits of the result.
    """

    pattern = "add<w> <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class slt(RISCVInstruction):
    """
    Set less than

    Place the value 1 in register Xd if register Xa is less than register Xb when both are treated as signed numbers,
    else 0 is written to Xd.
    """

    pattern = "slt <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class sltu(RISCVInstruction):
    """
    Set less than (unsigned numbers)

    Place the value 1 in register Xd if register Xa is less than register Xb when both are treated as unsigned numbers,
    else 0 is written to Xd.
    """

    pattern = "sltu <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class and_reg(RISCVInstruction):
    """
    AND two register

    Performs bitwise AND on registers Xa and Xb and place the result in Xd
    """

    pattern = "and <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class or_reg(RISCVInstruction):
    """
    OR two register

    Performs bitwise OR on registers Xa and Xb and place the result in Xd
    """

    pattern = "or <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class xor_reg(RISCVInstruction):
    """
    XOR two register

    Performs bitwise XOR on registers Xa and Xb and place the result in Xd
    """

    pattern = "xor <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class sll(RISCVInstruction):
    """
    Logical left shift by register

    Performs logical left shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "sll<w> <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class srl(RISCVInstruction):
    """
    Logical right shift by register

    Performs logical right shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "srl<w> <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class sub(RISCVInstruction):
    """
    Sub two register

    Subs the register Xb from Xa and stores the result in Xd.
    Arithmetic overflow is ignored and the result is simply the low XLEN bits of the result.
    """

    pattern = "sub<w> <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


class sra(RISCVInstruction):
    """
    Arithmetic right shift by register

    Performs arithmetic right shift on the value in register Xa by the shift amount held in the lower 5 bits of register
    Xb.
    """

    pattern = "sra<w> <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


############################
# load/ store instructions #
############################

class lb(RISCVInstruction):
    """
    Load byte

    Loads a 8-bit value from memory and sign-extends this to XLEN bits before storing it in register Xd.
    """

    pattern = "lb <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class lbu(RISCVInstruction):
    """
    Load byte unsigned

    Loads a 8-bit value from memory and zero-extends this to XLEN bits before storing it in register Xd.
    """
    pattern = "lbu <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class lh(RISCVInstruction):
    """
    Load half word

    Loads a 16-bit value from memory and sign-extends this to XLEN bits before storing it in register Xd.
    """
    pattern = "lh <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class lhu(RISCVInstruction):
    """
    Load half word unsigned

    Loads a 16-bit value from memory and zero-extends this to XLEN bits before storing it in register Xd.
    """
    pattern = "lhu <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class lw(RISCVInstruction):
    """
    Load word

    Loads a 32-bit value from memory and sign-extends this to XLEN bits before storing it in register Xd.
    """
    pattern = "lw <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class lwu(RISCVInstruction):
    """
    Load word

    Loads a 32-bit value from memory and zero-extends this to XLEN bits before storing it in register Xd.
    """
    pattern = "lwu <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class ld(RISCVInstruction):
    """
    Load double word

    Loads a 64-bit value from memory into register Xd for RV64I.
    """
    pattern = "ld <Xd>, <imm>(<Xa>)"
    inputs = ["Xa"]
    outputs = ["Xd"]


class sb(RISCVStore):
    """
    Store byte

    Store 8-bit, values from the low bits of register Xb to memory.
    """
    pattern = "sb <Xb>, <imm>(<Xa>)"


class sh(RISCVStore):
    """
    Store half word

    Store 16-bit, values from the low bits of register Xb to memory.
    """
    pattern = "sh <Xb>, <imm>(<Xa>)"


class sw(RISCVStore):
    """
    Store word

    Store 32-bit, values from the low bits of register Xb to memory.
    """
    pattern = "sw <Xb>, <imm>(<Xa>)"


class sd(RISCVStore):
    """
    Store double word

    Store 64-bit, values from the low bits of register Xb to memory.
    """
    pattern = "sd <Xb>, <imm>(<Xa>)"

IRIInstructions = ["addi<w>", "slti", "sltiu", "andi", "ori", "xori", "slli<w>", "srli<w>", "srai<w>"]

def instr_factory(instr_list, baseclass, inputs=[], outputs=[]):
    for instr in instr_list:
        dynamic_instr_classes.append(type(instr, (baseclass, Instruction), {'pattern': instr + " <Xd>, <Xa>, <imm>"}))
    return dynamic_instr_classes

def getIRIInstructions():
    classes = instr_factory(IRIInstructions, RISCVIntegerRegisterImmediate)
    #print(Instruction.__subclasses__())
    return classes

getIRIInstructions()
# TODO

- common RISC-V naming
- provide documentation for adding a new architecture
- think about a method to parse instructions like vmul.xx or fence.tso
and also for ADDW (32 bit version)
- restructure instructions by extension
- add vector instruction set
  - https://eupilot.eu/wp-content/uploads/2022/11/RISC-V-VectorExtension-1-1.pdf
  - https://fprox.substack.com/p/risc-v-vector-in-a-nutshell
  - https://riscv.org/wp-content/uploads/2018/05/15.20-15.55-18.05.06.VEXT-bcn-v1.pdf
  - Testcode: https://github.com/Ji-Peng/PQRV/blob/master/ntt/dilithium/ntt_8l_singleissue_mont_rv32im.S
- CSR Registers?
  - CRS instructions are no longer part of standard base ISA, mostly used for privileged stuff
- width-specifier for load/ store instructions?
- factory method for instructions with same pattern/ inputs/ outputs using a dict 

# RISC-V 

## Base Integer ISA
- Base Integer ISA, characterized by their width (XLEN) of integer registers (two's complement) and corresponding size 
of the address space:
  - RV32I (32 bit Integer base ISA)
    - RV32E (reduced version for microcontroller, only 16 integer registers)
  - RV64I (64 bit Integer base ISA)
    - RV64E (reduced version for microcontroller, only 16 integer registers)
  - (RV128I, future variant supporting 128 bit integers)
- Base RISC-V ISa has fixed-length 32-bit instructions that must be naturally aligned on 32-bit boundaries
- There is no dedicated stack pointer or subroutine return address link register in the Base
Integer ISA; the instruction encoding allows any x register to be used for these purposes.
However, the standard software calling convention uses register x1 to hold the return address
for a call, with register x5 available as an alternate link register. The standard calling
convention uses register x2 as the stack pointer

### Base Integer Instructions

#### Integer Register-Immediate Instructions

I-Type:
- ADDI #
- SLTI #
- ANDI #
- ORI #
- XORI # 
Special I-Type:
- SLLI #
- SRLI #
- SRAI #
U-Type:
- LUI #
- AUIPC #

#### Integer Register-Register Operations

R-Type:
- ADD #
- SLT #
- SLTU #
- AND #
- OR #
- XOR #
- SLL #
- SRL # 
- SUB #
- SRA #

### NOP Instruction
- NOP = ADDI x0, x0, 0

### Control Transfer Instructions (not scope of SLOTHY)
  #### Unconditional Jumps

  J-Type:
  - JAL
  I-Type:
  - JALR
  #### Conditional Branches
  B-Type:
  - BEQ
  - BNE
  - BLT
  - BLTU
  - BGE
  - BGEU

### Load and Store Instructions

  I-Type:
  - LD (64-bit value)
  - LW (32-bit value)
  - LWU (32-bit value)
  - LH (16-bit values)
  - LHU (16-bit values)
  - LB (8-bit values)
  - LBU (8-bit values)

  S-Type:
  - SD (64-bit value)
  - SW (32-bit value)
  - SH (16-bit values)
  - SB (8-bit values)

### Memory Ordering Instructions
  - FENCE
    - pred + succ argument are combinations of R,W,I,O
  - FENCE.TSO
### Environment Call and Breakpoints
  I-Type:
  - ECALL
  - EBREAK
### HINT Instructions

RV32I reserves a large encoding space for HINT instructions, which are usually used to communicate
performance hints to the microarchitecture. Like the NOP instruction, HINTs do not change any
architecturally visible state, except for advancing the pc and any applicable performance counters.
Implementations are always allowed to ignore the encoded hints.

## ISA Extensions

![img.png](img.png)

## Memory

- A RISC-V hart has a single byte-addressable address space of 2^XLEN
bytes for all memory accesses. A word of
memory is defined as 32 bits (4 bytes). Correspondingly, a halfword is 16 bits (2 bytes), a doubleword is
64 bits (8 bytes), and a quadword is 128 bits (16 bytes).
- A component is termed a core if it contains an independent instruction fetch unit. A RISC-V-compatible
core might support multiple RISC-V-compatible hardware threads, or harts, through multithreading.

# C908 Overview

- Supports RISC-V 64GCB[V] ISA 

# Instruction Structure

- 32/64/128 bit
- Extension set (M, A, F, D, G, Q, L, C, B, J, T, P, V, N, H, S)
- Instruction encoding type (I-Type, R-Type, U-Type ...)
- Privileged/ Unprivileged

- One file per instruction extension set
- Superclasses for semantic related instructions (own file)


# Questions

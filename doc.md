# TODO

- common RISC-V naming
- provide documentation for adding a new architecture
- add vector instruction set
  - https://eupilot.eu/wp-content/uploads/2022/11/RISC-V-VectorExtension-1-1.pdf
  - https://fprox.substack.com/p/risc-v-vector-in-a-nutshell
  - https://riscv.org/wp-content/uploads/2018/05/15.20-15.55-18.05.06.VEXT-bcn-v1.pdf
  - Testcode: https://github.com/Ji-Peng/PQRV/blob/master/ntt/dilithium/ntt_8l_singleissue_mont_rv32im.S
- CSR Registers?
  - CRS instructions are no longer part of standard base ISA, mostly used for privileged stuff
- add proper license/ copyright notices for all new files
- uArch Model
  - https://github.com/Ji-Peng/PQRV/tree/ches2025/cpi (CPI benchmark tool)
  - https://zulip.mpi-sp.org/user_uploads/2/35/pti_jvEdy5Egd_GawmsgcVL8/XuanTie-C908-UserManual.pdf (XuanTie-C908 manual)
  - https://camel-cdr.github.io/rvv-bench-results/canmv_k230/index.html (Benchmarks)
  - https://www.reddit.com/r/RISCV/comments/1cybkrv/xuantie_c908_and_spacemit_x60_vector/  (Benchmarks)
- Benchmark new results
- Try out profiling
- clean up ntt dilithium asm

# Xuan-Tie C908

## Execution Units

From XuanTie-C908 Manual, Chapter 2.2:
  - IFU (instruction fetch unit)
  - IEU (instruction execution Unit)
    - **ALU -> used for 32-bit and 64-bit integers and bit-extension operations**
    - MULT
    - DIV
    - BJU
  - FPU (floating-point units)
    - FALU (floating-point arithmetic logic unit)
      - add, sub, comparison, conversion, register data transmission, sign injection and classification
    - FMAU (floating-point fused multiply-add unit)
      - common multiplication and fused multiply-add operations
    - FDSU (floating-point divide and square root unit)
      - floating-point divisions and square root operations

  - "On the basis of the original scalar floating-point
    computation, floating-point units can be extended to vector floating-point units", so the following units are
    physically the same (?) as the FPUs, but extended to vector

  - VFPU (vector floating-point units)
    - VFALU (vector floating-point arithmetic logic unit)
    - VFMAU (vector floating-point fused multiply-add unit)
    - VFDSU (vector floating-point divide and square root unit)
    
  - Vector integer units:
    - VALU (vector arithmetic logic unit)
    - VSHIFT (vector shift unit)
    - VMUL (vector multiplication unit)
    - VDIVU (vector division unit)
    - VPERM (vector permutation unit)
    - VREDU (vector reduction unit)
    - VMISC (vector logical operation unit)
  - LSU (load/ store unit)
  - MMU (memory management unit)
  - PMP (physical memory protection unit)

## Further information
- Two 64-bit Vector execution units
- inverse throughput = How long is one execution unit kept busy by one instruction
- provide mechanism to specify comment-character depending on arch -> Hardcoded in helper.py l. 36 ff.
- test file for all implemented instructions…-

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


# How to PQRV

- Slothy submodule updaten
- Symlink asm ordner to optimized asm
- ntt-dilithium.mk add assembly file
- optional: add wrapper for assembly fct
- pqrv.h: extern void asm fct 
- main.c: copy make test ntt + make bench
- main.c call test in main file

- idea: build tests with PQRV, then run them on RISC-V machine
Build:
- nix develop --extra-experimental-features flakes --extra-experimental-features nix-command
- make build-cross-rv64im_ntt-dilithium will build the elf and put it into envs/cross-rv64im
- make run-cross-rv64im_ntt-dilithium will build the elf and put it into envs/cross-rv64im and run it using qemu

## Profiler

- tests/profiling/asm.txt -> here my asm code
- execute profiler.py
- in nix: make build profiling platform ...
- binary is in env directory
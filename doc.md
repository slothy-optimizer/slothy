# TODO

- Example file with simple RISC-V source code
- adjust example.py (instance of example, class of example)
- try with --dry-run option, add microarchitecture at the end of name
- Add template file for C908
- common RISC-V naming

- start with implementation of RISC-V architecture
- copy whole file, adjust stack specifications etc., look for architecture-specific things
- implement first instructions at the end of file

# RISC-V 

## RISC-V ISA Overview

### Base Integer ISA
- Base Integer ISA, characterized by their width (XLEN) of integer registers (two's complement) and corresponding size 
of the address space:
  - RV32I (32 bit Integer base ISA)
    - RV32E (reduced version for microcontroller, only 16 integer registers)
  - RV64I (64 bit Integer base ISA)
    - RV64E (reduced version for microcontroller, only 16 integer registers)
  - (RV128I, future variant supporting 128 bit integers)

### ISA Extensions

![img.png](img.png)

## Memory

- A RISC-V hart has a single byte-addressable address space of 2^XLEN
bytes for all memory accesses. A word of
memory is defined as 32 bits (4 bytes). Correspondingly, a halfword is 16 bits (2 bytes), a doubleword is
64 bits (8 bytes), and a quadword is 128 bits (16 bytes).

# C908 Overview

- Supports RISC-V 64GCB[V] ISA 
.data
.align 2
constants_keccak:
.quad 0x0000000000000001
.quad 0x0000000000008082
.quad 0x800000000000808a
.quad 0x8000000080008000
.quad 0x000000000000808b
.quad 0x0000000080000001
.quad 0x8000000080008081
.quad 0x8000000000008009
.quad 0x000000000000008a
.quad 0x0000000000000088
.quad 0x0000000080008009
.quad 0x000000008000000a
.quad 0x000000008000808b
.quad 0x800000000000008b
.quad 0x8000000000008089
.quad 0x8000000000008003
.quad 0x8000000000008002
.quad 0x8000000000000080
.quad 0x000000000000800a
.quad 0x800000008000000a
.quad 0x8000000080008081
.quad 0x8000000000008080
.quad 0x0000000080000001
.quad 0x8000000080008008

.text

.macro SaveRegs
    sd s0,  0*8(sp)
    sd s1,  1*8(sp)
    sd s2,  2*8(sp)
    sd s3,  3*8(sp)
    sd s4,  4*8(sp)
    sd s5,  5*8(sp)
    sd s6,  6*8(sp)
    sd s7,  7*8(sp)
    sd s8,  8*8(sp)
    sd s9,  9*8(sp)
    sd s10, 10*8(sp)
    sd s11, 11*8(sp)
    sd gp,  12*8(sp)
    sd tp,  13*8(sp)
    sd ra,  14*8(sp)
.endm

.macro RestoreRegs
    ld s0,  0*8(sp)
    ld s1,  1*8(sp)
    ld s2,  2*8(sp)
    ld s3,  3*8(sp)
    ld s4,  4*8(sp)
    ld s5,  5*8(sp)
    ld s6,  6*8(sp)
    ld s7,  7*8(sp)
    ld s8,  8*8(sp)
    ld s9,  9*8(sp)
    ld s10, 10*8(sp)
    ld s11, 11*8(sp)
    ld gp,  12*8(sp)
    ld tp,  13*8(sp)
    ld ra,  14*8(sp)
.endm

.macro LoadStates S00_s, S01_s, S02_s, S03_s, S04_s, \
                  S05_s, S06_s, S07_s, S08_s, S09_s, \
                  S10_s, S11_s, S12_s, S13_s, S14_s, \
                  S15_s, S16_s, S17_s, S18_s, S19_s, \
                  S20_s, S21_s, S22_s, S23_s, S24_s
    ld \S00_s, 0*8(a0)
    ld \S01_s, 1*8(a0)
    ld \S02_s, 2*8(a0)
    ld \S03_s, 3*8(a0)
    ld \S04_s, 4*8(a0)
    ld \S05_s, 5*8(a0)
    ld \S06_s, 6*8(a0)
    ld \S07_s, 7*8(a0)
    ld \S08_s, 8*8(a0)
    ld \S09_s, 9*8(a0)
    ld \S10_s, 10*8(a0)
    ld \S11_s, 11*8(a0)
    ld \S12_s, 12*8(a0)
    ld \S13_s, 13*8(a0)
    ld \S14_s, 14*8(a0)
    ld \S15_s, 15*8(a0)
    ld \S16_s, 16*8(a0)
    ld \S17_s, 17*8(a0)
    ld \S18_s, 18*8(a0)
    ld \S19_s, 19*8(a0)
    ld \S20_s, 20*8(a0)
    ld \S21_s, 21*8(a0)
    ld \S22_s, 22*8(a0)
    ld \S23_s, 23*8(a0)
    ld \S24_s, 24*8(a0)
.endm

.macro StoreStates S00_s, S01_s, S02_s, S03_s, S04_s, \
                   S05_s, S06_s, S07_s, S08_s, S09_s, \
                   S10_s, S11_s, S12_s, S13_s, S14_s, \
                   S15_s, S16_s, S17_s, S18_s, S19_s, \
                   S20_s, S21_s, S22_s, S23_s, S24_s
    sd \S00_s, 0*8(a0)
    sd \S01_s, 1*8(a0)
    sd \S02_s, 2*8(a0)
    sd \S03_s, 3*8(a0)
    sd \S04_s, 4*8(a0)
    sd \S05_s, 5*8(a0)
    sd \S06_s, 6*8(a0)
    sd \S07_s, 7*8(a0)
    sd \S08_s, 8*8(a0)
    sd \S09_s, 9*8(a0)
    sd \S10_s, 10*8(a0)
    sd \S11_s, 11*8(a0)
    sd \S12_s, 12*8(a0)
    sd \S13_s, 13*8(a0)
    sd \S14_s, 14*8(a0)
    sd \S15_s, 15*8(a0)
    sd \S16_s, 16*8(a0)
    sd \S17_s, 17*8(a0)
    sd \S18_s, 18*8(a0)
    sd \S19_s, 19*8(a0)
    sd \S20_s, 20*8(a0)
    sd \S21_s, 21*8(a0)
    sd \S22_s, 22*8(a0)
    sd \S23_s, 23*8(a0)
    sd \S24_s, 24*8(a0)
.endm

.macro ARoundInPlace    S00_s, S01_s, S02_s, S03_s, S04_s, S05_s, S06_s, S07_s, S08_s, S09_s, \
                        S10_s, S11_s, S12_s, S13_s, S14_s, S15_s, S16_s, S17_s, S18_s, S19_s, \
                        S20_s, S21_s, S22_s, S23_s, S24_s, T00_s, T01_s, T02_s, T03_s, T04_s
    xor \T00_s, \S00_s, \S05_s
    xor \T00_s, \T00_s, \S10_s
    xor \T00_s, \T00_s, \S15_s
    xor \T00_s, \T00_s, \S20_s
    xor \T01_s, \S02_s, \S07_s
    xor \T01_s, \T01_s, \S12_s
    xor \T01_s, \T01_s, \S17_s
    xor \T01_s, \T01_s, \S22_s
    rori \T02_s, \T01_s, 64-1
    xor  \T02_s, \T02_s, \T00_s
    xor \T03_s, \S01_s, \S06_s
    xor \T03_s, \T03_s, \S11_s
    xor \T03_s, \T03_s, \S16_s
    xor \T03_s, \T03_s, \S21_s
    xor \S01_s, \S01_s, \T02_s
    xor \S06_s, \S06_s, \T02_s
    xor \S11_s, \S11_s, \T02_s
    xor \S16_s, \S16_s, \T02_s
    xor \S21_s, \S21_s, \T02_s
    xor \T02_s, \S04_s, \S09_s
    xor \T02_s, \T02_s, \S14_s
    xor \T02_s, \T02_s, \S19_s
    xor \T02_s, \T02_s, \S24_s
    rori \T04_s, \T02_s, 63
    xor  \T01_s, \T01_s, \T04_s
    xor \T04_s, \S03_s, \S08_s
    xor \T04_s, \T04_s, \S13_s
    xor \T04_s, \T04_s, \S18_s
    xor \T04_s, \T04_s, \S23_s
    xor \S03_s, \S03_s, \T01_s
    xor \S08_s, \S08_s, \T01_s
    xor \S13_s, \S13_s, \T01_s
    xor \S18_s, \S18_s, \T01_s
    xor \S23_s, \S23_s, \T01_s
    rori \T00_s, \T00_s, 64-1
    xor  \T00_s, \T00_s, \T04_s
    xor \S04_s, \S04_s, \T00_s
    xor \S09_s, \S09_s, \T00_s
    xor \S14_s, \S14_s, \T00_s
    xor \S19_s, \S19_s, \T00_s
    xor \S24_s, \S24_s, \T00_s
    rori \T04_s, \T04_s, 64-1
    xor  \T04_s, \T04_s, \T03_s
    xor \S02_s, \S02_s, \T04_s
    xor \S07_s, \S07_s, \T04_s
    xor \S12_s, \S12_s, \T04_s
    xor \S17_s, \S17_s, \T04_s
    xor \S22_s, \S22_s, \T04_s
    rori \T03_s, \T03_s, 64-1
    xor  \T03_s, \T03_s, \T02_s
    xor \S05_s, \S05_s, \T03_s
    xor \S10_s, \S10_s, \T03_s
    xor \S15_s, \S15_s, \T03_s
    xor \S20_s, \S20_s, \T03_s
    xor \T00_s, \S00_s, \T03_s
    rori \T01_s, \S06_s, 64-44
    rori \S00_s, \S02_s, 64-62
    rori \S02_s, \S12_s, 64-43
    rori \S12_s, \S13_s, 64-25
    rori \S13_s, \S19_s, 64-8
    rori \S19_s, \S23_s, 64-56
    rori \S23_s, \S15_s, 64-41
    rori \S15_s, \S01_s, 64-1
    rori \S01_s, \S08_s, 64-55
    rori \S08_s, \S16_s, 64-45
    rori \S16_s, \S07_s, 64-6
    rori \S07_s, \S10_s, 64-3
    rori \S10_s, \S03_s, 64-28
    rori \S03_s, \S18_s, 64-21
    rori \S18_s, \S17_s, 64-15
    rori \S17_s, \S11_s, 64-10
    rori \S11_s, \S09_s, 64-20
    rori \S09_s, \S22_s, 64-61
    rori \S22_s, \S14_s, 64-39
    rori \S14_s, \S20_s, 64-18
    rori \S20_s, \S04_s, 64-27
    rori \S04_s, \S24_s, 64-14
    rori \S24_s, \S21_s, 64-2
    rori \S21_s, \S05_s, 64-36
    andn \T02_s, \S07_s, \S11_s
    xor \S05_s, \T02_s, \S10_s
    andn \T03_s, \S08_s, \S07_s
    xor \S06_s, \T03_s, \S11_s
    andn \T02_s, \S09_s, \S08_s
    xor \S07_s, \T02_s, \S07_s
    andn \T03_s, \S10_s, \S09_s
    xor \S08_s, \T03_s, \S08_s
    andn \T02_s, \S11_s, \S10_s
    xor \S09_s, \T02_s, \S09_s
    andn \T03_s, \S12_s, \S16_s
    xor \S10_s, \T03_s, \S15_s
    andn \T02_s, \S13_s, \S12_s
    xor \S11_s, \T02_s, \S16_s
    andn \T03_s, \S14_s, \S13_s
    xor \S12_s, \T03_s, \S12_s
    andn \T02_s, \S15_s, \S14_s
    xor \S13_s, \T02_s, \S13_s
    andn \T03_s, \S16_s, \S15_s
    xor \S14_s, \T03_s, \S14_s
    andn \T02_s, \S17_s, \S21_s
    xor \S15_s, \T02_s, \S20_s
    andn \T03_s, \S18_s, \S17_s
    xor \S16_s, \T03_s, \S21_s
    andn \T02_s, \S19_s, \S18_s
    xor \S17_s, \T02_s, \S17_s
    andn \T03_s, \S20_s, \S19_s
    xor \S18_s, \T03_s, \S18_s
    andn \T02_s, \S21_s, \S20_s
    xor \S19_s, \T02_s, \S19_s
    andn \T03_s, \S22_s, \S01_s
    xor \S20_s, \T03_s, \S00_s
    andn \T02_s, \S23_s, \S22_s
    xor \S21_s, \T02_s, \S01_s
    andn \T03_s, \S24_s, \S23_s
    xor \S22_s, \T03_s, \S22_s
    andn \T02_s, \S00_s, \S24_s
    xor \S23_s, \T02_s, \S23_s
    andn \T03_s, \S01_s, \S00_s
    xor \S24_s, \T03_s, \S24_s
    andn \T02_s, \S02_s, \T01_s
    xor \S00_s, \T02_s, \T00_s
    andn \T03_s, \S03_s, \S02_s
    xor \S01_s, \T03_s, \T01_s
    andn \T02_s, \S04_s, \S03_s
    xor \S02_s, \T02_s, \S02_s
    andn \T03_s, \T00_s, \S04_s
    xor \S03_s, \T03_s, \S03_s
    andn \T02_s, \T01_s, \T00_s
    xor \S04_s, \T02_s, \S04_s
    ld   \T04_s, 17*8(sp)
    ld   \T03_s, 0(\T04_s)
    xor  \S00_s, \S00_s, \T03_s
    addi \T04_s, \T04_s, 8
    sd   \T04_s, 17*8(sp)
.endm

.globl KeccakF1600_StatePermute_RV64ASM
.align 2
KeccakF1600_StatePermute_RV64ASM:
    addi sp, sp, -8*18
    SaveRegs
    sd a0, 15*8(sp)

    la a1, constants_keccak
    sd a1, 17*8(sp)

    LoadStates \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10
    # 16*8(sp): loop control variable i
    # 17*8(sp): table index
    li a0, 24
    
rounds1_loop_start:
    sd a0, 16*8(sp)
    ARoundInPlace       a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
                        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
                        s6, s7, s8, s9, s10,s11,ra, gp, tp, a0
    ld a0, 16*8(sp)
    addi a0, a0, -1
    bnez a0, rounds1_loop_start

    ld a0, 15*8(sp)
    StoreStates \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10
    RestoreRegs
    addi sp, sp, 8*18
    ret

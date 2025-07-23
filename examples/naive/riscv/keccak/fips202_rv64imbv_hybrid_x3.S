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
    sd s0,   0*8(sp)
    sd s1,   1*8(sp)
    sd s2,   2*8(sp)
    sd s3,   3*8(sp)
    sd s4,   4*8(sp)
    sd s5,   5*8(sp)
    sd s6,   6*8(sp)
    sd s7,   7*8(sp)
    sd s8,   8*8(sp)
    sd s9,   9*8(sp)
    sd s10, 10*8(sp)
    sd s11, 11*8(sp)
    sd gp,  12*8(sp)
    sd tp,  13*8(sp)
    sd ra,  14*8(sp)
.endm

.macro RestoreRegs
    ld s0,   0*8(sp)
    ld s1,   1*8(sp)
    ld s2,   2*8(sp)
    ld s3,   3*8(sp)
    ld s4,   4*8(sp)
    ld s5,   5*8(sp)
    ld s6,   6*8(sp)
    ld s7,   7*8(sp)
    ld s8,   8*8(sp)
    ld s9,   9*8(sp)
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
    # load states for vector impl
    # lane complement: 1,2,8,12,17,20
#ifdef V0p7
    vle.v v0, (a0)
    addi a0, a0, 16
    vle.v v1, (a0)
    addi a0, a0, 16
    vle.v v2, (a0)
    addi a0, a0, 16
    vle.v v3, (a0)
    addi a0, a0, 16
    vle.v v4, (a0)
    addi a0, a0, 16
    vle.v v5, (a0)
    addi a0, a0, 16
    vle.v v6, (a0)
    addi a0, a0, 16
    vle.v v7, (a0)
    addi a0, a0, 16
    vle.v v8, (a0)
    addi a0, a0, 16
    vle.v v9, (a0)
    addi a0, a0, 16
    vle.v v10, (a0)
    addi a0, a0, 16
    vle.v v11, (a0)
    addi a0, a0, 16
    vle.v v12, (a0)
    addi a0, a0, 16
    vle.v v13, (a0)
    addi a0, a0, 16
    vle.v v14, (a0)
    addi a0, a0, 16
    vle.v v15, (a0)
    addi a0, a0, 16
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vle.v v16, (a0)
    addi a0, a0, 16
    vle.v v17, (a0)
    addi a0, a0, 16
    vle.v v18, (a0)
    addi a0, a0, 16
    vle.v v19, (a0)
    addi a0, a0, 16
    vle.v v20, (a0)
    addi a0, a0, 16
    vle.v v21, (a0)
    addi a0, a0, 16
    vle.v v22, (a0)
    addi a0, a0, 16
    vle.v v23, (a0)
    addi a0, a0, 16
    vnot.v v17, v17
    vnot.v v20, v20
    vle.v v24, (a0)
    addi a0, a0, 1*16
#else
    vl8re64.v v0, (a0)
    addi a0, a0, 8*16
    vl8re64.v v8, (a0)
    addi a0, a0, 8*16
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vl8re64.v v16, (a0)
    addi a0, a0, 8*16
    vnot.v v17, v17
    vnot.v v20, v20
    vle64.v v24, (a0)
    addi a0, a0, 1*16
#endif
    # load states for scalar impl
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

.macro LoadStates_v
    # load states for vector impl
    # lane complement: 1,2,8,12,17,20
#ifdef V0p7
    vle.v v0, (a0)
    addi a0, a0, 16
    vle.v v1, (a0)
    addi a0, a0, 16
    vle.v v2, (a0)
    addi a0, a0, 16
    vle.v v3, (a0)
    addi a0, a0, 16
    vle.v v4, (a0)
    addi a0, a0, 16
    vle.v v5, (a0)
    addi a0, a0, 16
    vle.v v6, (a0)
    addi a0, a0, 16
    vle.v v7, (a0)
    addi a0, a0, 16
    vle.v v8, (a0)
    addi a0, a0, 16
    vle.v v9, (a0)
    addi a0, a0, 16
    vle.v v10, (a0)
    addi a0, a0, 16
    vle.v v11, (a0)
    addi a0, a0, 16
    vle.v v12, (a0)
    addi a0, a0, 16
    vle.v v13, (a0)
    addi a0, a0, 16
    vle.v v14, (a0)
    addi a0, a0, 16
    vle.v v15, (a0)
    addi a0, a0, 16
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vle.v v16, (a0)
    addi a0, a0, 16
    vle.v v17, (a0)
    addi a0, a0, 16
    vle.v v18, (a0)
    addi a0, a0, 16
    vle.v v19, (a0)
    addi a0, a0, 16
    vle.v v20, (a0)
    addi a0, a0, 16
    vle.v v21, (a0)
    addi a0, a0, 16
    vle.v v22, (a0)
    addi a0, a0, 16
    vle.v v23, (a0)
    addi a0, a0, 16
    vnot.v v17, v17
    vnot.v v20, v20
    vle.v v24, (a0)
    addi a0, a0, 1*16
#else
    vl8re64.v v0, (a0)
    addi a0, a0, 8*16
    vl8re64.v v8, (a0)
    addi a0, a0, 8*16
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vl8re64.v v16, (a0)
    addi a0, a0, 8*16
    vnot.v v17, v17
    vnot.v v20, v20
    vle64.v v24, (a0)
    addi a0, a0, 1*16
#endif
.endm

.macro LoadStates_s \
        S00, S01, S02, S03, S04, \
        S05, S06, S07, S08, S09, \
        S10, S11, S12, S13, S14, \
        S15, S16, S17, S18, S19, \
        S20, S21, S22, S23, S24
    # lane complement: 1,2,8,12,17,20
    # load states for scalar impl
    ld \S00, 0*8(a0)
    ld \S01, 1*8(a0)
    ld \S02, 2*8(a0)
    ld \S03, 3*8(a0)
    ld \S04, 4*8(a0)
    ld \S05, 5*8(a0)
    ld \S06, 6*8(a0)
    ld \S07, 7*8(a0)
    ld \S08, 8*8(a0)
    ld \S09, 9*8(a0)
    ld \S10, 10*8(a0)
    ld \S11, 11*8(a0)
    ld \S12, 12*8(a0)
    ld \S13, 13*8(a0)
    ld \S14, 14*8(a0)
    ld \S15, 15*8(a0)
    ld \S16, 16*8(a0)
    ld \S17, 17*8(a0)
    ld \S18, 18*8(a0)
    ld \S19, 19*8(a0)
    ld \S20, 20*8(a0)
    ld \S21, 21*8(a0)
    ld \S22, 22*8(a0)
    ld \S23, 23*8(a0)
    ld \S24, 24*8(a0)
.endm

.macro StoreStates S00_s, S01_s, S02_s, S03_s, S04_s, \
                   S05_s, S06_s, S07_s, S08_s, S09_s, \
                   S10_s, S11_s, S12_s, S13_s, S14_s, \
                   S15_s, S16_s, S17_s, S18_s, S19_s, \
                   S20_s, S21_s, S22_s, S23_s, S24_s
    # store states for vector impl
    # lane complement: 1,2,8,12,17,20
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vnot.v v17, v17
    vnot.v v20, v20

#ifdef V0p7
    vse.v v0, (a0)
    addi a0, a0, 16
    vse.v v1, (a0)
    addi a0, a0, 16
    vse.v v2, (a0)
    addi a0, a0, 16
    vse.v v3, (a0)
    addi a0, a0, 16
    vse.v v4, (a0)
    addi a0, a0, 16
    vse.v v5, (a0)
    addi a0, a0, 16
    vse.v v6, (a0)
    addi a0, a0, 16
    vse.v v7, (a0)
    addi a0, a0, 16
    vse.v v8, (a0)
    addi a0, a0, 16
    vse.v v9, (a0)
    addi a0, a0, 16
    vse.v v10, (a0)
    addi a0, a0, 16
    vse.v v11, (a0)
    addi a0, a0, 16
    vse.v v12, (a0)
    addi a0, a0, 16
    vse.v v13, (a0)
    addi a0, a0, 16
    vse.v v14, (a0)
    addi a0, a0, 16
    vse.v v15, (a0)
    addi a0, a0, 16
    vse.v v16, (a0)
    addi a0, a0, 16
    vse.v v17, (a0)
    addi a0, a0, 16
    vse.v v18, (a0)
    addi a0, a0, 16
    vse.v v19, (a0)
    addi a0, a0, 16
    vse.v v20, (a0)
    addi a0, a0, 16
    vse.v v21, (a0)
    addi a0, a0, 16
    vse.v v22, (a0)
    addi a0, a0, 16
    vse.v v23, (a0)
    addi a0, a0, 16
    vse.v v24, (a0)
    addi a0, a0, 1*16
#else
    vs8r.v v0, (a0)
    addi a0, a0, 8*16
    vs8r.v v8, (a0)
    addi a0, a0, 8*16
    vs8r.v v16, (a0)
    addi a0, a0, 8*16
    vse64.v v24, (a0)
    addi a0, a0, 1*16
#endif
    # store states for scalar impl
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

.macro StoreStates_v
    # store states for vector impl
    # lane complement: 1,2,8,12,17,20
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vnot.v v17, v17
    vnot.v v20, v20
#ifdef V0p7
    vse.v v0, (a0)
    addi a0, a0, 16
    vse.v v1, (a0)
    addi a0, a0, 16
    vse.v v2, (a0)
    addi a0, a0, 16
    vse.v v3, (a0)
    addi a0, a0, 16
    vse.v v4, (a0)
    addi a0, a0, 16
    vse.v v5, (a0)
    addi a0, a0, 16
    vse.v v6, (a0)
    addi a0, a0, 16
    vse.v v7, (a0)
    addi a0, a0, 16
    vse.v v8, (a0)
    addi a0, a0, 16
    vse.v v9, (a0)
    addi a0, a0, 16
    vse.v v10, (a0)
    addi a0, a0, 16
    vse.v v11, (a0)
    addi a0, a0, 16
    vse.v v12, (a0)
    addi a0, a0, 16
    vse.v v13, (a0)
    addi a0, a0, 16
    vse.v v14, (a0)
    addi a0, a0, 16
    vse.v v15, (a0)
    addi a0, a0, 16
    vse.v v16, (a0)
    addi a0, a0, 16
    vse.v v17, (a0)
    addi a0, a0, 16
    vse.v v18, (a0)
    addi a0, a0, 16
    vse.v v19, (a0)
    addi a0, a0, 16
    vse.v v20, (a0)
    addi a0, a0, 16
    vse.v v21, (a0)
    addi a0, a0, 16
    vse.v v22, (a0)
    addi a0, a0, 16
    vse.v v23, (a0)
    addi a0, a0, 16
    vse.v v24, (a0)
    addi a0, a0, 1*16
#else
    vs8r.v v0, (a0)
    addi a0, a0, 8*16
    vs8r.v v8, (a0)
    addi a0, a0, 8*16
    vs8r.v v16, (a0)
    addi a0, a0, 8*16
    vse64.v v24, (a0)
    addi a0, a0, 1*16
#endif
.endm

.macro StoreStates_s \
        S00, S01, S02, S03, S04, \
        S05, S06, S07, S08, S09, \
        S10, S11, S12, S13, S14, \
        S15, S16, S17, S18, S19, \
        S20, S21, S22, S23, S24
    # store states for scalar impl
    sd \S00, 0*8(a0)
    sd \S01, 1*8(a0)
    sd \S02, 2*8(a0)
    sd \S03, 3*8(a0)
    sd \S04, 4*8(a0)
    sd \S05, 5*8(a0)
    sd \S06, 6*8(a0)
    sd \S07, 7*8(a0)
    sd \S08, 8*8(a0)
    sd \S09, 9*8(a0)
    sd \S10, 10*8(a0)
    sd \S11, 11*8(a0)
    sd \S12, 12*8(a0)
    sd \S13, 13*8(a0)
    sd \S14, 14*8(a0)
    sd \S15, 15*8(a0)
    sd \S16, 16*8(a0)
    sd \S17, 17*8(a0)
    sd \S18, 18*8(a0)
    sd \S19, 19*8(a0)
    sd \S20, 20*8(a0)
    sd \S21, 21*8(a0)
    sd \S22, 22*8(a0)
    sd \S23, 23*8(a0)
    sd \S24, 24*8(a0)
.endm

.macro ARoundInPlace  \
        S00_v, S01_v, S02_v, S03_v, S04_v, S05_v, S06_v, S07_v, S08_v, S09_v, \
        S10_v, S11_v, S12_v, S13_v, S14_v, S15_v, S16_v, S17_v, S18_v, S19_v, \
        S20_v, S21_v, S22_v, S23_v, S24_v, T00_v, T01_v, T02_v, T03_v, T04_v, \
        S00_s, S01_s, S02_s, S03_s, S04_s, S05_s, S06_s, S07_s, S08_s, S09_s, \
        S10_s, S11_s, S12_s, S13_s, S14_s, S15_s, S16_s, S17_s, S18_s, S19_s, \
        S20_s, S21_s, S22_s, S23_s, S24_s, T00_s, T01_s, T02_s, T03_s, T04_s
    xor \T00_s, \S00_s, \S05_s;             vxor.vv \T00_v, \S00_v, \S05_v
    xor \T00_s, \T00_s, \S10_s;             vxor.vv \T00_v, \T00_v, \S10_v
    xor \T00_s, \T00_s, \S15_s;             vxor.vv \T00_v, \T00_v, \S15_v
    xor \T00_s, \T00_s, \S20_s;             vxor.vv \T00_v, \T00_v, \S20_v
    xor \T01_s, \S02_s, \S07_s;             vxor.vv \T01_v, \S02_v, \S07_v
    xor \T01_s, \T01_s, \S12_s;             vxor.vv \T01_v, \T01_v, \S12_v
    xor \T01_s, \T01_s, \S17_s;             vxor.vv \T01_v, \T01_v, \S17_v
    xor \T01_s, \T01_s, \S22_s;             vxor.vv \T01_v, \T01_v, \S22_v
    rori \T02_s, \T01_s, 64-1;              li \T04_s, 64-1
    xor  \T02_s, \T02_s, \T00_s;            vsll.vi \T03_v, \T01_v, 1
    xor \T03_s, \S01_s, \S06_s;             vsrl.vx \T02_v, \T01_v, \T04_s
    xor \T03_s, \T03_s, \S11_s;             vxor.vv \T02_v, \T02_v, \T03_v
    xor \T03_s, \T03_s, \S16_s;             vxor.vv  \T02_v, \T02_v, \T00_v
    xor \T03_s, \T03_s, \S21_s;             vxor.vv \T03_v, \S01_v, \S06_v
    xor \S01_s, \S01_s, \T02_s;             vxor.vv \T03_v, \T03_v, \S11_v
    xor \S06_s, \S06_s, \T02_s;             vxor.vv \T03_v, \T03_v, \S16_v;             sd \S01_s, 18*8(sp)
    xor \S11_s, \S11_s, \T02_s;             vxor.vv \T03_v, \T03_v, \S21_v
    xor \S16_s, \S16_s, \T02_s;             vxor.vv \S01_v, \S01_v, \T02_v
    xor \S21_s, \S21_s, \T02_s;             vxor.vv \S06_v, \S06_v, \T02_v
    xor \T02_s, \S04_s, \S09_s;             vxor.vv \S11_v, \S11_v, \T02_v
    xor \T02_s, \T02_s, \S14_s;             vxor.vv \S16_v, \S16_v, \T02_v
    xor \T02_s, \T02_s, \S19_s;             vxor.vv \S21_v, \S21_v, \T02_v
    xor \T02_s, \T02_s, \S24_s;             vxor.vv \T02_v, \S04_v, \S09_v
    rori \T04_s, \T02_s, 63;                vxor.vv \T02_v, \T02_v, \S14_v
    xor  \T01_s, \T01_s, \T04_s;            vxor.vv \T02_v, \T02_v, \S19_v
    xor \T04_s, \S03_s, \S08_s;             vxor.vv \T02_v, \T02_v, \S24_v
    xor \T04_s, \T04_s, \S13_s;             vsll.vi \T04_v, \T02_v, 1
    xor \T04_s, \T04_s, \S18_s;             vxor.vv \T01_v, \T01_v, \T04_v
    xor \T04_s, \T04_s, \S23_s;             li \S01_s, 63
    xor \S03_s, \S03_s, \T01_s;             vsrl.vx \T04_v, \T02_v, \S01_s
    xor \S08_s, \S08_s, \T01_s;             vxor.vv \T01_v, \T01_v, \T04_v
    xor \S13_s, \S13_s, \T01_s;             vxor.vv \T04_v, \S03_v, \S08_v
    xor \S18_s, \S18_s, \T01_s;             vxor.vv \T04_v, \T04_v, \S13_v
    xor \S23_s, \S23_s, \T01_s;             vxor.vv \T04_v, \T04_v, \S18_v
    rori \T00_s, \T00_s, 64-1;              vxor.vv \T04_v, \T04_v, \S23_v
    xor  \T00_s, \T00_s, \T04_s;            vxor.vv \S03_v, \S03_v, \T01_v
    xor \S04_s, \S04_s, \T00_s;             vxor.vv \S08_v, \S08_v, \T01_v
    xor \S09_s, \S09_s, \T00_s;             vxor.vv \S13_v, \S13_v, \T01_v
    xor \S14_s, \S14_s, \T00_s;             vxor.vv \S18_v, \S18_v, \T01_v
    xor \S19_s, \S19_s, \T00_s;             vxor.vv \S23_v, \S23_v, \T01_v
    xor \S24_s, \S24_s, \T00_s;             li \S01_s, 64-1
    rori \T04_s, \T04_s, 64-1;              vsll.vi \T01_v, \T00_v, 1
    xor  \T04_s, \T04_s, \T03_s;            vsrl.vx \T00_v, \T00_v, \S01_s
    xor \S02_s, \S02_s, \T04_s;             vxor.vv \T00_v, \T00_v, \T01_v
    xor \S07_s, \S07_s, \T04_s;             vxor.vv \T00_v, \T00_v, \T04_v
    xor \S12_s, \S12_s, \T04_s;             vxor.vv \S04_v, \S04_v, \T00_v
    xor \S17_s, \S17_s, \T04_s;             vxor.vv \S09_v, \S09_v, \T00_v
    xor \S22_s, \S22_s, \T04_s;             vxor.vv \S14_v, \S14_v, \T00_v
    rori \T03_s, \T03_s, 64-1;              vxor.vv \S19_v, \S19_v, \T00_v
    xor  \T03_s, \T03_s, \T02_s;            vxor.vv \S24_v, \S24_v, \T00_v
    xor \S05_s, \S05_s, \T03_s;             li \S01_s, 64-1
    xor \S10_s, \S10_s, \T03_s;             vsll.vi \T01_v, \T04_v, 1
    xor \S15_s, \S15_s, \T03_s;             vsrl.vx \T04_v, \T04_v, \S01_s
    xor \S20_s, \S20_s, \T03_s;             vxor.vv \T04_v, \T04_v, \T01_v
    xor \T00_s, \S00_s, \T03_s;             vxor.vv  \T04_v, \T04_v, \T03_v
    rori \T01_s, \S06_s, 64-44;             vxor.vv \S02_v, \S02_v, \T04_v
    rori \S00_s, \S02_s, 64-62;             vxor.vv \S07_v, \S07_v, \T04_v;             ld \S01_s, 18*8(sp)
    rori \S02_s, \S12_s, 64-43;             vxor.vv \S12_v, \S12_v, \T04_v
    rori \S12_s, \S13_s, 64-25;             vxor.vv \S17_v, \S17_v, \T04_v
    rori \S13_s, \S19_s, 64-8;              vxor.vv \S22_v, \S22_v, \T04_v
    rori \S19_s, \S23_s, 64-56;             li \T04_s, 64-1
    rori \S23_s, \S15_s, 64-41;             vsll.vi \T01_v, \T03_v, 1
    rori \S15_s, \S01_s, 64-1;              vsrl.vx \T03_v, \T03_v, \T04_s
    rori \S01_s, \S08_s, 64-55;             vxor.vv \T03_v, \T03_v, \T01_v
    rori \S08_s, \S16_s, 64-45;             vxor.vv  \T03_v, \T03_v, \T02_v
    rori \S16_s, \S07_s, 64-6;              vxor.vv \S05_v, \S05_v, \T03_v
    rori \S07_s, \S10_s, 64-3;              vxor.vv \S10_v, \S10_v, \T03_v
    rori \S10_s, \S03_s, 64-28;             vxor.vv \S15_v, \S15_v, \T03_v;             vxor.vv \S20_v, \S20_v, \T03_v
    rori \S03_s, \S18_s, 64-21;             vxor.vv \T00_v, \S00_v, \T03_v;             li \T04_s, 44;                              vsll.vx \T02_v, \S06_v, \T04_s
    rori \S18_s, \S17_s, 64-15;             vsrl.vi \T01_v, \S06_v, 64-44;              vxor.vv \T01_v, \T01_v, \T02_v
    rori \S17_s, \S11_s, 64-10;             li \T04_s, 62;                              vsll.vx \T03_v, \S02_v, \T04_s;             vsrl.vi \S00_v, \S02_v, 64-62
    rori \S11_s, \S09_s, 64-20;             vxor.vv \S00_v, \S00_v, \T03_v;             li \T04_s, 43;                              vsll.vx \T02_v, \S12_v, \T04_s
    rori \S09_s, \S22_s, 64-61;             vsrl.vi \S02_v, \S12_v, 64-43;              vxor.vv \S02_v, \S02_v, \T02_v
    rori \S22_s, \S14_s, 64-39;             li \T04_s, 64-25;                           vsll.vi \T03_v, \S13_v, 25;                 vsrl.vx \S12_v, \S13_v, \T04_s
    rori \S14_s, \S20_s, 64-18;             vxor.vv \S12_v, \S12_v, \T03_v;             li \T04_s, 64-8;                            vsll.vi \T02_v, \S19_v, 8
    rori \S20_s, \S04_s, 64-27;             vsrl.vx \S13_v, \S19_v, \T04_s;             vxor.vv \S13_v, \S13_v, \T02_v
    rori \S04_s, \S24_s, 64-14;             li \T04_s, 56;                              vsll.vx \T03_v, \S23_v, \T04_s;             vsrl.vi \S19_v, \S23_v, 64-56
    rori \S24_s, \S21_s, 64-2;              vxor.vv \S19_v, \S19_v, \T03_v;             li \T04_s, 41;                              vsll.vx \T02_v, \S15_v, \T04_s
    rori \S21_s, \S05_s, 64-36;             vsrl.vi \S23_v, \S15_v, 64-41;              vxor.vv \S23_v, \S23_v, \T02_v
    andn \T02_s, \S07_s, \S11_s;            li \T04_s, 64-1;                            vsll.vi \T03_v, \S01_v, 1;                  vsrl.vx \S15_v, \S01_v, \T04_s
    xor \S05_s, \T02_s, \S10_s;             vxor.vv \S15_v, \S15_v, \T03_v;             li \T04_s, 55;                              vsll.vx \T02_v, \S08_v, \T04_s
    andn \T03_s, \S08_s, \S07_s;            vsrl.vi \S01_v, \S08_v, 64-55;              vxor.vv \S01_v, \S01_v, \T02_v
    xor \S06_s, \T03_s, \S11_s;             li \T04_s, 45;                              vsll.vx \T03_v, \S16_v, \T04_s;             vsrl.vi \S08_v, \S16_v, 64-45
    andn \T02_s, \S09_s, \S08_s;            vxor.vv \S08_v, \S08_v, \T03_v;             li \T04_s, 64-6;                            vsll.vi \T02_v, \S07_v, 6
    xor \S07_s, \T02_s, \S07_s;             vsrl.vx \S16_v, \S07_v, \T04_s;             vxor.vv \S16_v, \S16_v, \T02_v
    andn \T03_s, \S10_s, \S09_s;            li \T04_s, 64-3;                            vsll.vi \T03_v, \S10_v, 3;                  vsrl.vx \S07_v, \S10_v, \T04_s
    xor \S08_s, \T03_s, \S08_s;             vxor.vv \S07_v, \S07_v, \T03_v;             li \T04_s, 64-28;                           vsll.vi \T02_v, \S03_v, 28
    andn \T02_s, \S11_s, \S10_s;            vsrl.vx \S10_v, \S03_v, \T04_s;             vxor.vv \S10_v, \S10_v, \T02_v
    xor \S09_s, \T02_s, \S09_s;             li \T04_s, 64-21;                           vsll.vi \T03_v, \S18_v, 21;                 vsrl.vx \S03_v, \S18_v, \T04_s
    andn \T03_s, \S12_s, \S16_s;            vxor.vv \S03_v, \S03_v, \T03_v;             li \T04_s, 64-15;                           vsll.vi \T02_v, \S17_v, 15
    xor \S10_s, \T03_s, \S15_s;             vsrl.vx \S18_v, \S17_v, \T04_s;             vxor.vv \S18_v, \S18_v, \T02_v
    andn \T02_s, \S13_s, \S12_s;            li \T04_s, 64-10;                           vsll.vi \T03_v, \S11_v, 10;                 vsrl.vx \S17_v, \S11_v, \T04_s
    xor \S11_s, \T02_s, \S16_s;             vxor.vv \S17_v, \S17_v, \T03_v;             li \T04_s, 64-20;                           vsll.vi \T02_v, \S09_v, 20
    andn \T03_s, \S14_s, \S13_s;            vsrl.vx \S11_v, \S09_v, \T04_s;             vxor.vv \S11_v, \S11_v, \T02_v
    xor \S12_s, \T03_s, \S12_s;             li \T04_s, 61;                              vsll.vx \T03_v, \S22_v, \T04_s;             vsrl.vi \S09_v, \S22_v, 64-61
    andn \T02_s, \S15_s, \S14_s;            vxor.vv \S09_v, \S09_v, \T03_v;             li \T04_s, 39;                              vsll.vx \T02_v, \S14_v, \T04_s
    xor \S13_s, \T02_s, \S13_s;             vsrl.vi \S22_v, \S14_v, 64-39;              vxor.vv \S22_v, \S22_v, \T02_v
    andn \T03_s, \S16_s, \S15_s;            li \T04_s, 64-18;                           vsll.vi \T03_v, \S20_v, 18;                 vsrl.vx \S14_v, \S20_v, \T04_s
    xor \S14_s, \T03_s, \S14_s;             vxor.vv \S14_v, \S14_v, \T03_v;             li \T04_s, 64-27;                           vsll.vi \T02_v, \S04_v, 27
    andn \T02_s, \S17_s, \S21_s;            vsrl.vx \S20_v, \S04_v, \T04_s;             vxor.vv \S20_v, \S20_v, \T02_v
    xor \S15_s, \T02_s, \S20_s;             li \T04_s, 64-14;                           vsll.vi \T03_v, \S24_v, 14;                 vsrl.vx \S04_v, \S24_v, \T04_s
    andn \T03_s, \S18_s, \S17_s;            vxor.vv \S04_v, \S04_v, \T03_v;             li \T04_s, 64-2;                            vsll.vi \T02_v, \S21_v, 2
    xor \S16_s, \T03_s, \S21_s;             vsrl.vx \S24_v, \S21_v, \T04_s;             vxor.vv \S24_v, \S24_v, \T02_v
    andn \T02_s, \S19_s, \S18_s;            li \T04_s, 36;                              vsll.vx \T03_v, \S05_v, \T04_s;             vsrl.vi \S21_v, \S05_v, 64-36
    xor \S17_s, \T02_s, \S17_s;             vxor.vv \S21_v, \S21_v, \T03_v;             vor.vv \T02_v, \S11_v, \S07_v
    andn \T03_s, \S20_s, \S19_s;            vxor.vv \S05_v, \S10_v, \T02_v;             vand.vv \T03_v, \S07_v, \S08_v
    xor \S18_s, \T03_s, \S18_s;             vxor.vv \S06_v, \S11_v, \T03_v;             vnot.v \T02_v, \S09_v
    andn \T02_s, \S21_s, \S20_s;            vor.vv  \T02_v, \T02_v, \S08_v;             vxor.vv \S07_v, \S07_v, \T02_v
    xor \S19_s, \T02_s, \S19_s;             vor.vv \T03_v, \S09_v, \S10_v;              vxor.vv \S08_v, \S08_v, \T03_v
    andn \T03_s, \S22_s, \S01_s;            vand.vv \T02_v, \S10_v, \S11_v;             vxor.vv \S09_v, \S09_v, \T02_v
    xor \S20_s, \T03_s, \S00_s;             vor.vv \T03_v, \S16_v, \S12_v;              vxor.vv \S10_v, \S15_v, \T03_v
    andn \T02_s, \S23_s, \S22_s;            vand.vv \T02_v, \S12_v, \S13_v;             vxor.vv \S11_v, \S16_v, \T02_v
    xor \S21_s, \T02_s, \S01_s;             vnot.v \T03_v, \S13_v;                      vand.vv \T03_v, \T03_v, \S14_v
    andn \T03_s, \S24_s, \S23_s;            vxor.vv \S12_v, \S12_v, \T03_v;             vnot.v \T03_v, \S13_v
    xor \S22_s, \T03_s, \S22_s;             vor.vv  \T02_v, \S14_v, \S15_v;             vxor.vv \S13_v, \T03_v, \T02_v
    andn \T02_s, \S00_s, \S24_s;            vand.vv \T03_v, \S15_v, \S16_v;             vxor.vv \S14_v, \S14_v, \T03_v
    xor \S23_s, \T02_s, \S23_s;             vand.vv \T02_v, \S21_v, \S17_v;             vxor.vv \S15_v, \S20_v, \T02_v
    andn \T03_s, \S01_s, \S00_s;            vor.vv \T03_v, \S17_v, \S18_v;              vxor.vv \S16_v, \S21_v, \T03_v
    xor \S24_s, \T03_s, \S24_s;             vnot.v \T02_v, \S18_v;                      vor.vv  \T02_v, \T02_v, \S19_v
    andn \T02_s, \S02_s, \T01_s;            vxor.vv \S17_v, \S17_v, \T02_v;             vnot.v \T02_v, \S18_v
    xor \S00_s, \T02_s, \T00_s;             vand.vv \T03_v, \S19_v, \S20_v;             vxor.vv \S18_v, \T02_v, \T03_v
    andn \T03_s, \S03_s, \S02_s;            vor.vv \T02_v, \S20_v, \S21_v;              vxor.vv \S19_v, \S19_v, \T02_v
    xor \S01_s, \T03_s, \T01_s;             vnot.v \T03_v, \S01_v;                      vand.vv \T03_v, \T03_v, \S22_v
    andn \T02_s, \S04_s, \S03_s;            vxor.vv \S20_v, \S00_v, \T03_v;             vnot.v \T03_v, \S01_v
    xor \S02_s, \T02_s, \S02_s;             vor.vv  \T02_v, \S22_v, \S23_v;             vxor.vv \S21_v, \T03_v, \T02_v
    andn \T03_s, \T00_s, \S04_s;            vand.vv \T03_v, \S23_v, \S24_v;             vxor.vv \S22_v, \S22_v, \T03_v
    xor \S03_s, \T03_s, \S03_s;             vor.vv \T02_v, \S24_v, \S00_v;              vxor.vv \S23_v, \S23_v, \T02_v
    andn \T02_s, \T01_s, \T00_s;            vand.vv \T03_v, \S00_v, \S01_v;             vxor.vv \S24_v, \S24_v, \T03_v
    xor \S04_s, \T02_s, \S04_s;             vor.vv \T02_v, \T01_v, \S02_v;              vxor.vv \S00_v, \T00_v, \T02_v
    ld   \T04_s, 17*8(sp);                  vnot.v \T03_v, \S02_v;                      vor.vv \T03_v, \T03_v, \S03_v
    ld   \T03_s, 0(\T04_s);                 vxor.vv \S01_v, \T01_v, \T03_v;             vand.vv \T02_v, \S03_v, \S04_v
    xor  \S00_s, \S00_s, \T03_s;            vxor.vv \S02_v, \S02_v, \T02_v;             vor.vv \T03_v, \S04_v, \T00_v
    addi \T04_s, \T04_s, 8;                 vxor.vv \S03_v, \S03_v, \T03_v;             vand.vv \T02_v, \T00_v, \T01_v
    sd   \T04_s, 17*8(sp);                  vxor.vv \S04_v, \S04_v, \T02_v
    vxor.vx \S00_v, \S00_v, \T03_s
.endm

# 15*8(sp): a0
# 16*8(sp): loop control variable i
# 17*8(sp): table index
# 18*8(sp): temp
.globl KeccakF1600_StatePermute_RV64V_3x
.align 2
KeccakF1600_StatePermute_RV64V_3x:
    addi sp, sp, -8*19
    SaveRegs
    sd a0, 15*8(sp)
    # set VPU
    li a1, 128
vsetivli a2, 2, e64, m1, tu, mu

    la a1, constants_keccak
    sd a1, 17*8(sp)

    LoadStates \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10
    
    li a0, 24

loop:
    sd a0, 16*8(sp)
    ARoundInPlace \
        v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,  v8,  v9,    \
        v10, v11, v12, v13, v14, v15, v16, v17, v18, v19,   \
        v20, v21, v22, v23, v24, v25, v26, v27, v28, v29,   \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp, a0
    ld a0, 16*8(sp)
    addi a0, a0, -1
    bnez a0, loop

    ld a0, 15*8(sp)
    StoreStates \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10

    RestoreRegs
    addi sp, sp, 8*19
    ret

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
    not \S01_s, \S01_s
    not \S02_s, \S02_s
    not \S08_s, \S08_s
    not \S12_s, \S12_s
    not \S17_s, \S17_s
    ld \S18_s, 18*8(a0)
    ld \S19_s, 19*8(a0)
    ld \S20_s, 20*8(a0)
    ld \S21_s, 21*8(a0)
    ld \S22_s, 22*8(a0)
    ld \S23_s, 23*8(a0)
    not \S20_s, \S20_s
    ld \S24_s, 24*8(a0)
.endm

.macro StoreStates S00_s, S01_s, S02_s, S03_s, S04_s, \
                   S05_s, S06_s, S07_s, S08_s, S09_s, \
                   S10_s, S11_s, S12_s, S13_s, S14_s, \
                   S15_s, S16_s, S17_s, S18_s, S19_s, \
                   S20_s, S21_s, S22_s, S23_s, S24_s
    # store states for vector impl
    # lane complement: 1,2,8,12,17,20
    not \S01_s, \S01_s
    vnot.v v1, v1
    not \S02_s, \S02_s
    vnot.v v2, v2
    not \S08_s, \S08_s
    vnot.v v8, v8
    not \S12_s, \S12_s
    vnot.v v12, v12
    not \S17_s, \S17_s
    vnot.v v17, v17
    not \S20_s, \S20_s
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

.macro XOR5 \
        out_v, S00_v, S01_v, S02_v, S03_v, S04_v, \
        out_s, S00_s, S01_s, S02_s, S03_s, S04_s
    xor     \out_s, \S00_s, \S01_s;             vxor.vv \out_v, \S00_v, \S01_v
    xor     \out_s, \out_s, \S02_s;             vxor.vv \out_v, \out_v, \S02_v
    xor     \out_s, \out_s, \S03_s;             vxor.vv \out_v, \out_v, \S03_v
    xor     \out_s, \out_s, \S04_s;             vxor.vv \out_v, \out_v, \S04_v
.endm

.macro ROLn \
        out_v, in_v, tmp_v, \
        out_s, in_s, tmp_s, tmp1_s, n
.if \n < 32
    li      \tmp1_s, 64-\n
    slli    \tmp_s, \in_s, \n;                  vsll.vi \tmp_v, \in_v, \n
    srli    \out_s, \in_s, 64-\n;               vsrl.vx \out_v, \in_v, \tmp1_s
    xor     \out_s, \out_s, \tmp_s;             vxor.vv \out_v, \out_v, \tmp_v
.else
    li      \tmp1_s, \n
    slli    \tmp_s, \in_s, \n;                  vsll.vx \tmp_v, \in_v, \tmp1_s
    srli    \out_s, \in_s, 64-\n;               vsrl.vi \out_v, \in_v, 64-\n
    xor     \out_s, \out_s, \tmp_s;             vxor.vv \out_v, \out_v, \tmp_v
.endif

.endm

.macro ROL1 \
        out_v, in_v, tmp_v, \
        out_s, in_s, tmp_s, tmp1_s
    ROLn \out_v, \in_v, \tmp_v, \out_s, \in_s, \tmp_s, \tmp1_s, 1
.endm

.macro EachXOR \
        S00_v, S01_v, S02_v, S03_v, S04_v, D_v, \
        S00_s, S01_s, S02_s, S03_s, S04_s, D_s
    xor     \S00_s, \S00_s, \D_s;               vxor.vv \S00_v, \S00_v, \D_v
    xor     \S01_s, \S01_s, \D_s;               vxor.vv \S01_v, \S01_v, \D_v
    xor     \S02_s, \S02_s, \D_s;               vxor.vv \S02_v, \S02_v, \D_v
    xor     \S03_s, \S03_s, \D_s;               vxor.vv \S03_v, \S03_v, \D_v
    xor     \S04_s, \S04_s, \D_s;               vxor.vv \S04_v, \S04_v, \D_v
.endm

.macro ChiOp \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    not     \T_s, \S01_s;                       vnot.v  \T_v, \S01_v
    and     \T_s, \T_s, \S02_s;                 vand.vv \T_v, \T_v, \S02_v
    xor     \out_s, \T_s, \S00_s;               vxor.vv \out_v, \T_v, \S00_v
.endm

.macro xoror \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    or      \T_s, \S01_s, \S02_s;               vor.vv  \T_v, \S01_v, \S02_v
    xor     \out_s, \S00_s, \T_s;               vxor.vv \out_v, \S00_v, \T_v
.endm

.macro xornotor \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    not     \T_s, \S01_s;                       vnot.v  \T_v, \S01_v
    or      \T_s, \T_s, \S02_s;                 vor.vv  \T_v, \T_v, \S02_v
    xor     \out_s, \S00_s, \T_s;               vxor.vv \out_v, \S00_v, \T_v
.endm

.macro xorand \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    and     \T_s, \S01_s, \S02_s;               vand.vv \T_v, \S01_v, \S02_v
    xor     \out_s, \S00_s, \T_s;               vxor.vv \out_v, \S00_v, \T_v
.endm

.macro xorornot \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    not     \T_s, \S02_s;                       vnot.v  \T_v, \S02_v
    or      \T_s, \T_s, \S01_s;                 vor.vv  \T_v, \T_v, \S01_v
    xor     \out_s, \S00_s, \T_s;               vxor.vv \out_v, \S00_v, \T_v
.endm

.macro xornotand \
        out_v, S00_v, S01_v, S02_v, T_v, \
        out_s, S00_s, S01_s, S02_s, T_s
    not     \T_s, \S01_s;                       vnot.v  \T_v, \S01_v
    and     \T_s, \T_s, \S02_s;                 vand.vv \T_v, \T_v, \S02_v
    xor     \out_s, \S00_s, \T_s;               vxor.vv \out_v, \S00_v, \T_v
.endm

.macro notxoror \
        out_v, S00_v, S01_v, S02_v, T_v, T_v0, \
        out_s, S00_s, S01_s, S02_s, T_s, T0_s
    not     \T0_s, \S00_s;                      vnot.v  \T_v0, \S00_v
    or      \T_s, \S01_s, \S02_s;               vor.vv  \T_v, \S01_v, \S02_v
    xor     \out_s, \T0_s, \T_s;                vxor.vv \out_v, \T_v0, \T_v
.endm

.macro notxorand \
        out_v, S00_v, S01_v, S02_v, T_v, T_v0, \
        out_s, S00_s, S01_s, S02_s, T_s, T0_s
    not     \T0_s, \S00_s;                      vnot.v  \T_v0, \S00_v
    and     \T_s, \S01_s, \S02_s;               vand.vv \T_v, \S01_v, \S02_v
    xor     \out_s, \T0_s, \T_s;                vxor.vv \out_v, \T_v0, \T_v
.endm

.macro ARoundInPlace  \
        S00_v, S01_v, S02_v, S03_v, S04_v, S05_v, S06_v, S07_v, S08_v, S09_v, \
        S10_v, S11_v, S12_v, S13_v, S14_v, S15_v, S16_v, S17_v, S18_v, S19_v, \
        S20_v, S21_v, S22_v, S23_v, S24_v, T00_v, T01_v, T02_v, T03_v, T04_v, \
        S00_s, S01_s, S02_s, S03_s, S04_s, S05_s, S06_s, S07_s, S08_s, S09_s, \
        S10_s, S11_s, S12_s, S13_s, S14_s, S15_s, S16_s, S17_s, S18_s, S19_s, \
        S20_s, S21_s, S22_s, S23_s, S24_s, T00_s, T01_s, T02_s, T03_s, T04_s
    # theta - start
    # C0 = S00_v ^ S05_v ^ S10_v ^ S15_v ^ S20_v
    XOR5 \T00_v, \S00_v, \S05_v, \S10_v, \S15_v, \S20_v, \
         \T00_s, \S00_s, \S05_s, \S10_s, \S15_s, \S20_s
    # C2 = S02_v ^ S07_v ^ S12_v ^ S17_v ^ S22_v
    XOR5 \T01_v, \S02_v, \S07_v, \S12_v, \S17_v, \S22_v, \
         \T01_s, \S02_s, \S07_s, \S12_s, \S17_s, \S22_s
    # D1 = C0 ^ ROL(C2, 1)
    ROL1 \T02_v, \T01_v, \T03_v, \
         \T02_s, \T01_s, \T03_s, \T04_s
    xor  \T02_s, \T02_s, \T00_s;              vxor.vv  \T02_v, \T02_v, \T00_v
    # T00_s=C0 T01_s=C2 T02_s=D1

    # C1 = S01_v ^ S06_v ^ S11_v ^ S16_v ^ S21_v
    XOR5 \T03_v, \S01_v, \S06_v, \S11_v, \S16_v, \S21_v, \
         \T03_s, \S01_s, \S06_s, \S11_s, \S16_s, \S21_s
    # S06_v ^= D1; S16_v ^= D1; S01_v ^= D1; S11_v ^= D1; S21_v ^= D1
    EachXOR \S01_v, \S06_v, \S11_v, \S16_v, \S21_v, \T02_v, \
            \S01_s, \S06_s, \S11_s, \S16_s, \S21_s, \T02_s

    # store S01_s into stack for temporary usage
    sd \S01_s, 18*8(sp)

    # C4 = S04_v ^ S09_v ^ S14_v ^ S19_v ^ S24_v
    XOR5 \T02_v, \S04_v, \S09_v, \S14_v, \S19_v, \S24_v, \
         \T02_s, \S04_s, \S09_s, \S14_s, \S19_s, \S24_s
    # D3 = C2 ^ ROL(C4, 1); C2 can be overwritten
    # T00_s=C0 T01_s=D3 T03_s=C1 T02_s=C4
    slli \T04_s, \T02_s, 1;                 vsll.vi \T04_v, \T02_v, 1
    xor  \T01_s, \T01_s, \T04_s;            vxor.vv \T01_v, \T01_v, \T04_v
    li \S01_s, 63
    srli \T04_s, \T02_s, 63;                vsrl.vx \T04_v, \T02_v, \S01_s
    xor  \T01_s, \T01_s, \T04_s;            vxor.vv \T01_v, \T01_v, \T04_v

    # C3 = S03_v ^ S08_v ^ S13_v ^ S18_v ^ S23_v
    XOR5 \T04_v, \S03_v, \S08_v, \S13_v, \S18_v, \S23_v, \
         \T04_s, \S03_s, \S08_s, \S13_s, \S18_s, \S23_s
    # S18_v ^= D3; S03_v ^= D3; S13_v ^= D3; S23_v ^= D3; S08_v ^= D3
    EachXOR \S03_v, \S08_v, \S13_v, \S18_v, \S23_v, \T01_v, \
            \S03_s, \S08_s, \S13_s, \S18_s, \S23_s, \T01_s
    # T00_s=C0 T03_s=C1 T02_s=C4 T04_s=C3

    # D4 = C3 ^ ROL(C0, 1); C0 can be overwritten
    ROL1 \T00_v, \T00_v, \T01_v, \
         \T00_s, \T00_s, \T01_s, \S01_s
    xor  \T00_s, \T00_s, \T04_s;              vxor.vv \T00_v, \T00_v, \T04_v
    # S24_v ^= D4; S09_v ^= D4; S19_v ^= D4; S04_v ^= D4; S14_v ^= D4
    EachXOR \S04_v, \S09_v, \S14_v, \S19_v, \S24_v, \T00_v, \
            \S04_s, \S09_s, \S14_s, \S19_s, \S24_s, \T00_s

    # D2 = C1 ^ ROL(C3, 1)
    ROL1 \T04_v, \T04_v, \T01_v, \
         \T04_s, \T04_s, \T01_s, \S01_s
    xor  \T04_s, \T04_s, \T03_s;              vxor.vv  \T04_v, \T04_v, \T03_v
    # S12_v ^= D2; S22_v ^= D2; S07_v ^= D2; S17_v ^= D2; S02_v ^= D2
    EachXOR \S02_v, \S07_v, \S12_v, \S17_v, \S22_v, \T04_v, \
            \S02_s, \S07_s, \S12_s, \S17_s, \S22_s, \T04_s

    # D0 = C4 ^ ROL(C1, 1)
    ROL1 \T03_v, \T03_v, \T01_v, \
         \T03_s, \T03_s, \T01_s, \S01_s
    xor  \T03_s, \T03_s, \T02_s;              vxor.vv  \T03_v, \T03_v, \T02_v
    # S00_v ^= D0; S05_v ^= D0; S10_v ^= D0; S15_v ^= D0; S20_v ^= D0
    # EachXOR \S00_v, \S05_v, \S10_v, \S15_v, \S20_v, \T03_v
    xor \S05_s, \S05_s, \T03_s;               vxor.vv \S05_v, \S05_v, \T03_v
    xor \S10_s, \S10_s, \T03_s;               vxor.vv \S10_v, \S10_v, \T03_v
    xor \S15_s, \S15_s, \T03_s;               vxor.vv \S15_v, \S15_v, \T03_v
    xor \S20_s, \S20_s, \T03_s;               vxor.vv \S20_v, \S20_v, \T03_v
    xor \T00_s, \S00_s, \T03_s;               vxor.vv \T00_v, \S00_v, \T03_v
    # theta - end

    # restore S01_s from stack
    ld \S01_s, 18*8(sp)

    # Rho & Pi & Chi - start
    ROLn \T01_v, \S06_v, \T02_v, \T01_s, \S06_s, \T02_s, \T03_s, 44
    ROLn \S00_v, \S02_v, \T03_v, \S00_s, \S02_s, \T02_s, \T03_s, 62
    ROLn \S02_v, \S12_v, \T02_v, \S02_s, \S12_s, \T02_s, \T03_s, 43
    ROLn \S12_v, \S13_v, \T03_v, \S12_s, \S13_s, \T02_s, \T03_s, 25
    ROLn \S13_v, \S19_v, \T02_v, \S13_s, \S19_s, \T02_s, \T03_s, 8
    ROLn \S19_v, \S23_v, \T03_v, \S19_s, \S23_s, \T02_s, \T03_s, 56
    ROLn \S23_v, \S15_v, \T02_v, \S23_s, \S15_s, \T02_s, \T03_s, 41
    ROLn \S15_v, \S01_v, \T03_v, \S15_s, \S01_s, \T02_s, \T03_s, 1
    ROLn \S01_v, \S08_v, \T02_v, \S01_s, \S08_s, \T02_s, \T03_s, 55
    ROLn \S08_v, \S16_v, \T03_v, \S08_s, \S16_s, \T02_s, \T03_s, 45
    ROLn \S16_v, \S07_v, \T02_v, \S16_s, \S07_s, \T02_s, \T03_s, 6
    ROLn \S07_v, \S10_v, \T03_v, \S07_s, \S10_s, \T02_s, \T03_s, 3
    ROLn \S10_v, \S03_v, \T02_v, \S10_s, \S03_s, \T02_s, \T03_s, 28
    ROLn \S03_v, \S18_v, \T03_v, \S03_s, \S18_s, \T02_s, \T03_s, 21
    ROLn \S18_v, \S17_v, \T02_v, \S18_s, \S17_s, \T02_s, \T03_s, 15
    ROLn \S17_v, \S11_v, \T03_v, \S17_s, \S11_s, \T02_s, \T03_s, 10
    ROLn \S11_v, \S09_v, \T02_v, \S11_s, \S09_s, \T02_s, \T03_s, 20
    ROLn \S09_v, \S22_v, \T03_v, \S09_s, \S22_s, \T02_s, \T03_s, 61
    ROLn \S22_v, \S14_v, \T02_v, \S22_s, \S14_s, \T02_s, \T03_s, 39
    ROLn \S14_v, \S20_v, \T03_v, \S14_s, \S20_s, \T02_s, \T03_s, 18
    ROLn \S20_v, \S04_v, \T02_v, \S20_s, \S04_s, \T02_s, \T03_s, 27
    ROLn \S04_v, \S24_v, \T03_v, \S04_s, \S24_s, \T02_s, \T03_s, 14
    ROLn \S24_v, \S21_v, \T02_v, \S24_s, \S21_s, \T02_s, \T03_s, 2
    ROLn \S21_v, \S05_v, \T03_v, \S21_s, \S05_s, \T02_s, \T03_s, 36

    xoror    \S05_v, \S10_v, \S11_v, \S07_v, \T02_v, \S05_s, \S10_s, \S11_s, \S07_s, \T02_s
    xorand   \S06_v, \S11_v, \S07_v, \S08_v, \T03_v, \S06_s, \S11_s, \S07_s, \S08_s, \T03_s
    xorornot \S07_v, \S07_v, \S08_v, \S09_v, \T02_v, \S07_s, \S07_s, \S08_s, \S09_s, \T02_s
    xoror    \S08_v, \S08_v, \S09_v, \S10_v, \T03_v, \S08_s, \S08_s, \S09_s, \S10_s, \T03_s
    xorand   \S09_v, \S09_v, \S10_v, \S11_v, \T02_v, \S09_s, \S09_s, \S10_s, \S11_s, \T02_s

    xoror       \S10_v, \S15_v, \S16_v, \S12_v, \T03_v, \S10_s, \S15_s, \S16_s, \S12_s, \T03_s
    xorand      \S11_v, \S16_v, \S12_v, \S13_v, \T02_v, \S11_s, \S16_s, \S12_s, \S13_s, \T02_s
    xornotand   \S12_v, \S12_v, \S13_v, \S14_v, \T03_v, \S12_s, \S12_s, \S13_s, \S14_s, \T03_s
    notxoror    \S13_v, \S13_v, \S14_v, \S15_v, \T02_v, \T03_v, \S13_s, \S13_s, \S14_s, \S15_s, \T02_s, \T03_s
    xorand      \S14_v, \S14_v, \S15_v, \S16_v, \T03_v, \S14_s, \S14_s, \S15_s, \S16_s, \T03_s

    xorand      \S15_v, \S20_v, \S21_v, \S17_v, \T02_v, \S15_s, \S20_s, \S21_s, \S17_s, \T02_s
    xoror       \S16_v, \S21_v, \S17_v, \S18_v, \T03_v, \S16_s, \S21_s, \S17_s, \S18_s, \T03_s
    xornotor    \S17_v, \S17_v, \S18_v, \S19_v, \T02_v, \S17_s, \S17_s, \S18_s, \S19_s, \T02_s
    notxorand   \S18_v, \S18_v, \S19_v, \S20_v, \T03_v, \T02_v, \S18_s, \S18_s, \S19_s, \S20_s, \T03_s, \T02_s
    xoror       \S19_v, \S19_v, \S20_v, \S21_v, \T02_v, \S19_s, \S19_s, \S20_s, \S21_s, \T02_s

    xornotand   \S20_v, \S00_v, \S01_v, \S22_v, \T03_v, \S20_s, \S00_s, \S01_s, \S22_s, \T03_s
    notxoror    \S21_v, \S01_v, \S22_v, \S23_v, \T02_v, \T03_v, \S21_s, \S01_s, \S22_s, \S23_s, \T02_s, \T03_s
    xorand      \S22_v, \S22_v, \S23_v, \S24_v, \T03_v, \S22_s, \S22_s, \S23_s, \S24_s, \T03_s
    xoror       \S23_v, \S23_v, \S24_v, \S00_v, \T02_v, \S23_s, \S23_s, \S24_s, \S00_s, \T02_s
    xorand      \S24_v, \S24_v, \S00_v, \S01_v, \T03_v, \S24_s, \S24_s, \S00_s, \S01_s, \T03_s

    xoror       \S00_v, \T00_v, \T01_v, \S02_v, \T02_v, \S00_s, \T00_s, \T01_s, \S02_s, \T02_s
    xornotor    \S01_v, \T01_v, \S02_v, \S03_v, \T03_v, \S01_s, \T01_s, \S02_s, \S03_s, \T03_s
    xorand      \S02_v, \S02_v, \S03_v, \S04_v, \T02_v, \S02_s, \S02_s, \S03_s, \S04_s, \T02_s
    xoror       \S03_v, \S03_v, \S04_v, \T00_v, \T03_v, \S03_s, \S03_s, \S04_s, \T00_s, \T03_s
    xorand      \S04_v, \S04_v, \T00_v, \T01_v, \T02_v, \S04_s, \S04_s, \T00_s, \T01_s, \T02_s

    # Iota
    ld   \T04_s, 17*8(sp)
    ld   \T03_s, 0(\T04_s)
    xor  \S00_s, \S00_s, \T03_s;              vxor.vx \S00_v, \S00_v, \T03_s
    addi \T04_s, \T04_s, 8
    sd   \T04_s, 17*8(sp)
    # Rho & Pi & Chi - end
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

    la a1, constants_keccak
    sd a1, 17*8(sp)

    li a1, 128
vsetivli a2, 2, e64, m1, tu, mu

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

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

.macro LoadStates
    # lane complement: 1,2,8,12,17,20
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
    addi a0, a0, -24*16
.endm

.macro StoreStates
    # lane complement: 1,2,8,12,17,20
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vnot.v v17, v17
    vnot.v v20, v20
    vs8r.v v0, (a0)
    addi a0, a0, 8*16
    vs8r.v v8, (a0)
    addi a0, a0, 8*16
    vs8r.v v16, (a0)
    addi a0, a0, 8*16
    vse64.v v24, (a0)
.endm

.macro XOR5_x2 \
    out_0_v, S0_00_v, S0_01_v, S0_02_v, S0_03_v, S0_04_v, \
    out_1_v, S1_00_v, S1_01_v, S1_02_v, S1_03_v, S1_04_v
    vxor.vv \out_0_v, \S0_00_v, \S0_01_v
    vxor.vv \out_1_v, \S1_00_v, \S1_01_v
    vxor.vv \out_0_v, \out_0_v, \S0_02_v
    vxor.vv \out_1_v, \out_1_v, \S1_02_v
    vxor.vv \out_0_v, \out_0_v, \S0_03_v
    vxor.vv \out_1_v, \out_1_v, \S1_03_v
    vxor.vv \out_0_v, \out_0_v, \S0_04_v
    vxor.vv \out_1_v, \out_1_v, \S1_04_v
.endm

.macro XOR5_x3 \
    out_0_v, S0_00_v, S0_01_v, S0_02_v, S0_03_v, S0_04_v, \
    out_1_v, S1_00_v, S1_01_v, S1_02_v, S1_03_v, S1_04_v, \
    out_2_v, S2_00_v, S2_01_v, S2_02_v, S2_03_v, S2_04_v
    vxor.vv \out_0_v, \S0_00_v, \S0_01_v
    vxor.vv \out_1_v, \S1_00_v, \S1_01_v
    vxor.vv \out_2_v, \S2_00_v, \S2_01_v
    vxor.vv \out_0_v, \out_0_v, \S0_02_v
    vxor.vv \out_1_v, \out_1_v, \S1_02_v
    vxor.vv \out_2_v, \out_2_v, \S2_02_v
    vxor.vv \out_0_v, \out_0_v, \S0_03_v
    vxor.vv \out_1_v, \out_1_v, \S1_03_v
    vxor.vv \out_2_v, \out_2_v, \S2_03_v
    vxor.vv \out_0_v, \out_0_v, \S0_04_v
    vxor.vv \out_1_v, \out_1_v, \S1_04_v
    vxor.vv \out_2_v, \out_2_v, \S2_04_v
.endm

.macro ROLn_li out_0_v, in_0_v, tmp_0_v, n, tmp_0_s
.if \n < 32
    li \tmp_0_s, 64-\n
    vsll.vi \tmp_0_v, \in_0_v, \n
    vsrl.vx \out_0_v, \in_0_v, \tmp_0_s
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
.else
    li \tmp_0_s, \n
    vsll.vx \tmp_0_v, \in_0_v, \tmp_0_s
    vsrl.vi \out_0_v, \in_0_v, 64-\n
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
.endif
.endm

# tmp_0_s is ready for using; if n<32: tmp_0_s=64-n; else: tmp_0_s=n
.macro ROLn out_0_v, in_0_v, tmp_0_v, n, tmp_0_s
.if \n < 32
    vsll.vi \tmp_0_v, \in_0_v, \n
    vsrl.vx \out_0_v, \in_0_v, \tmp_0_s
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
.else
    vsll.vx \tmp_0_v, \in_0_v, \tmp_0_s
    vsrl.vi \out_0_v, \in_0_v, 64-\n
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
.endif
.endm

# out = in0 ^ ROL(in1, 1); tmp_0_s=64-1 is ready for using
.macro ROL1_XOR out_0_v, in_0_0_v, in_0_1_v, tmp_0_v, tmp_0_s
    vsll.vi \tmp_0_v, \in_0_1_v, 1
    vsrl.vx \out_0_v, \in_0_1_v, \tmp_0_s
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
    vxor.vv \out_0_v, \out_0_v, \in_0_0_v
.endm

.macro ROL1_XOR_x2 \
    out_0_v, in_0_0_v, in_0_1_v, tmp_0_v, \
    out_1_v, in_1_0_v, in_1_1_v, tmp_1_v, \
    tmp_0_s
    vsll.vi \tmp_0_v, \in_0_1_v, 1
    vsll.vi \tmp_1_v, \in_1_1_v, 1
    vsrl.vx \out_0_v, \in_0_1_v, \tmp_0_s
    vsrl.vx \out_1_v, \in_1_1_v, \tmp_0_s
    vxor.vv \out_0_v, \out_0_v, \tmp_0_v
    vxor.vv \out_1_v, \out_1_v, \tmp_1_v
    vxor.vv \out_0_v, \out_0_v, \in_0_0_v
    vxor.vv \out_1_v, \out_1_v, \in_1_0_v
.endm

.macro EachXOR S0_00_v, S0_01_v, S0_02_v, S0_03_v, S0_04_v, D_v
    vxor.vv \S0_00_v, \S0_00_v, \D_v
    vxor.vv \S0_01_v, \S0_01_v, \D_v
    vxor.vv \S0_02_v, \S0_02_v, \D_v
    vxor.vv \S0_03_v, \S0_03_v, \D_v
    vxor.vv \S0_04_v, \S0_04_v, \D_v
.endm

.macro ARoundInPlace \
    S00_v, S01_v, S02_v, S03_v, S04_v, S05_v, S06_v, S07_v, S08_v, S09_v, \
    S10_v, S11_v, S12_v, S13_v, S14_v, S15_v, S16_v, S17_v, S18_v, S19_v, \
    S20_v, S21_v, S22_v, S23_v, S24_v, T00_v, T01_v, T02_v, T03_v, T04_v, \
    T05_v, T06_v, T07_s
    # theta - start
    # T00,T01,T02=C1,C4,C3
    XOR5_x3 \
        \T00_v, \S01_v, \S06_v, \S11_v, \S16_v, \S21_v, \
        \T01_v, \S04_v, \S09_v, \S14_v, \S19_v, \S24_v, \
        \T02_v, \S03_v, \S08_v, \S13_v, \S18_v, \S23_v
    # T03,T04=D0,D2
    li \T07_s, 64-1
    ROL1_XOR_x2 \
        \T03_v, \T01_v, \T00_v, \T05_v, \
        \T04_v, \T00_v, \T02_v, \T06_v, \T07_s
    # T01,T02,T05,T06=C4,C3,C0,C2; T03,T04=D0,D2; T00: empty
    XOR5_x2 \
        \T05_v, \S00_v, \S05_v, \S10_v, \S15_v, \S20_v, \
        \T06_v, \S02_v, \S07_v, \S12_v, \S17_v, \S22_v
    EachXOR \S00_v, \S05_v, \S10_v, \S15_v, \S20_v, \T03_v
    vxor.vv \S02_v, \S02_v, \T04_v
    vxor.vv \S07_v, \S07_v, \T04_v
    vxor.vv \S12_v, \S12_v, \T04_v
    vsll.vi \T03_v, \T01_v, 1
    vsrl.vx \T00_v, \T01_v, \T07_s
    vxor.vv \S17_v, \S17_v, \T04_v
    vxor.vv \S22_v, \S22_v, \T04_v
    vxor.vv \T00_v, \T00_v, \T03_v
    vxor.vv \T00_v, \T00_v, \T06_v
    # T02,T05,T06=C3,C0,C2; T00:D3; T01,T03,T04: empty
    EachXOR \S03_v, \S08_v, \S13_v, \S18_v, \S23_v, \T00_v
    # T01,T04=D1,D4
    ROL1_XOR_x2 \
        \T01_v, \T05_v, \T06_v, \T00_v \
        \T04_v, \T02_v, \T05_v, \T03_v, \T07_s
    EachXOR \S01_v, \S06_v, \S11_v, \S16_v, \S21_v, \T01_v
    EachXOR \S04_v, \S09_v, \S14_v, \S19_v, \S24_v, \T04_v
    vmv.v.v \T00_v, \S00_v
    # theta - end
    # Rho & Pi & Chi - start
    li \T07_s, 44
    vsrl.vi \T01_v, \S06_v, 20
    vsll.vx \T02_v, \S06_v, \T07_s
    li \T07_s, 62
    vsrl.vi \S00_v, \S02_v, 2
    vsll.vx \T03_v, \S02_v, \T07_s
    vxor.vv \T01_v, \T01_v, \T02_v
    vxor.vv \S00_v, \S00_v, \T03_v
    li \T07_s, 43
    vsrl.vi \S02_v, \S12_v, 21
    vsll.vx \T02_v, \S12_v, \T07_s
    li \T07_s, 39
    vsll.vi \T03_v, \S13_v, 25
    vsrl.vx \S12_v, \S13_v, \T07_s
    vxor.vv \S02_v, \S02_v, \T02_v
    vxor.vv \S12_v, \S12_v, \T03_v
    li \T07_s, 56
    vsll.vi \T02_v, \S19_v, 8
    vsrl.vx \S13_v, \S19_v, \T07_s
    li \T07_s, 56
    vsrl.vi \S19_v, \S23_v, 8
    vsll.vx \T03_v, \S23_v, \T07_s
    vxor.vv \S13_v, \S13_v, \T02_v
    vxor.vv \S19_v, \S19_v, \T03_v
    li \T07_s, 41
    vsrl.vi \S23_v, \S15_v, 23
    vsll.vx \T02_v, \S15_v, \T07_s
    li \T07_s, 63
    vsll.vi \T03_v, \S01_v, 1
    vsrl.vx \S15_v, \S01_v, \T07_s
    vxor.vv \S23_v, \S23_v, \T02_v
    vxor.vv \S15_v, \S15_v, \T03_v
    li \T07_s, 55
    vsrl.vi \S01_v, \S08_v, 9
    vsll.vx \T02_v, \S08_v, \T07_s
    li \T07_s, 45
    vsrl.vi \S08_v, \S16_v, 19
    vsll.vx \T03_v, \S16_v, \T07_s
    vxor.vv \S01_v, \S01_v, \T02_v
    vxor.vv \S08_v, \S08_v, \T03_v
    li \T07_s, 58
    vsll.vi \T02_v, \S07_v, 6
    vsrl.vx \S16_v, \S07_v, \T07_s
    li \T07_s, 61
    vsll.vi \T03_v, \S10_v, 3
    vsrl.vx \S07_v, \S10_v, \T07_s
    vxor.vv \S16_v, \S16_v, \T02_v
    vxor.vv \S07_v, \S07_v, \T03_v
    li \T07_s, 36
    vsll.vi \T02_v, \S03_v, 28
    vsrl.vx \S10_v, \S03_v, \T07_s
    li \T07_s, 43
    vsll.vi \T03_v, \S18_v, 21
    vsrl.vx \S03_v, \S18_v, \T07_s
    vxor.vv \S10_v, \S10_v, \T02_v
    vxor.vv \S03_v, \S03_v, \T03_v
    li \T07_s, 49
    vsll.vi \T02_v, \S17_v, 15
    vsrl.vx \S18_v, \S17_v, \T07_s
    li \T07_s, 54
    vsll.vi \T03_v, \S11_v, 10
    vsrl.vx \S17_v, \S11_v, \T07_s
    vxor.vv \S18_v, \S18_v, \T02_v
    vxor.vv \S17_v, \S17_v, \T03_v
    li \T07_s, 44
    vsll.vi \T02_v, \S09_v, 20
    vsrl.vx \S11_v, \S09_v, \T07_s
    li \T07_s, 61
    vsrl.vi \S09_v, \S22_v, 3
    vsll.vx \T03_v, \S22_v, \T07_s
    vxor.vv \S11_v, \S11_v, \T02_v
    vxor.vv \S09_v, \S09_v, \T03_v
    li \T07_s, 39
    vsrl.vi \S22_v, \S14_v, 25
    vsll.vx \T02_v, \S14_v, \T07_s
    li \T07_s, 46
    vsll.vi \T03_v, \S20_v, 18
    vsrl.vx \S14_v, \S20_v, \T07_s
    vxor.vv \S22_v, \S22_v, \T02_v
    vxor.vv \S14_v, \S14_v, \T03_v
    li \T07_s, 37
    vsll.vi \T02_v, \S04_v, 27
    vsrl.vx \S20_v, \S04_v, \T07_s
    li \T07_s, 50
    vsll.vi \T03_v, \S24_v, 14
    vsrl.vx \S04_v, \S24_v, \T07_s
    vxor.vv \S20_v, \S20_v, \T02_v
    vxor.vv \S04_v, \S04_v, \T03_v
    li \T07_s, 62
    vsll.vi \T02_v, \S21_v, 2
    vsrl.vx \S24_v, \S21_v, \T07_s
    li \T07_s, 36
    vsrl.vi \S21_v, \S05_v, 28
    vsll.vx \T03_v, \S05_v, \T07_s
    vxor.vv \S24_v, \S24_v, \T02_v
    vxor.vv \S21_v, \S21_v, \T03_v
    vor.vv \T02_v, \S11_v, \S07_v
    vand.vv \T03_v, \S07_v, \S08_v
    vnot.v \T04_v, \S09_v
    vor.vv \T05_v, \S09_v, \S10_v
    vxor.vv \S05_v, \S10_v, \T02_v
    vor.vv \T04_v, \T04_v, \S08_v
    vxor.vv \S06_v, \S11_v, \T03_v
    vxor.vv \S07_v, \S07_v, \T04_v
    vxor.vv \S08_v, \S08_v, \T05_v
    vand.vv \T02_v, \S10_v, \S11_v
    vor.vv \T03_v, \S16_v, \S12_v
    vnot.v \T05_v, \S13_v
    vand.vv \T04_v, \S12_v, \S13_v
    vxor.vv \S09_v, \S09_v, \T02_v
    vand.vv \T05_v, \T05_v, \S14_v
    vxor.vv \S10_v, \S15_v, \T03_v
    vxor.vv \S11_v, \S16_v, \T04_v
    vxor.vv \S12_v, \S12_v, \T05_v
    vnot.v \T03_v, \S13_v
    vand.vv \T04_v, \S15_v, \S16_v
    vand.vv \T05_v, \S21_v, \S17_v
    vor.vv \T02_v, \S14_v, \S15_v
    vxor.vv \S14_v, \S14_v, \T04_v
    vxor.vv \S15_v, \S20_v, \T05_v
    vxor.vv \S13_v, \T03_v, \T02_v
    vnot.v \T03_v, \S18_v
    vnot.v \T05_v, \S18_v
    vor.vv \T02_v, \S17_v, \S18_v
    vor.vv \T03_v, \T03_v, \S19_v
    vand.vv \T04_v, \S19_v, \S20_v
    vxor.vv \S16_v, \S21_v, \T02_v
    vxor.vv \S17_v, \S17_v, \T03_v
    vxor.vv \S18_v, \T05_v, \T04_v
    vnot.v \T03_v, \S01_v
    vnot.v \T05_v, \S01_v
    vor.vv \T02_v, \S20_v, \S21_v
    vand.vv \T03_v, \T03_v, \S22_v
    vor.vv \T04_v, \S22_v, \S23_v
    vxor.vv \S19_v, \S19_v, \T02_v
    vxor.vv \S20_v, \S00_v, \T03_v
    vxor.vv \S21_v, \T05_v, \T04_v
    vand.vv \T02_v, \S23_v, \S24_v
    vor.vv \T03_v, \S24_v, \S00_v
    vand.vv \T04_v, \S00_v, \S01_v
    vor.vv \T05_v, \T01_v, \S02_v
    vxor.vv \S22_v, \S22_v, \T02_v
    vxor.vv \S23_v, \S23_v, \T03_v
    vxor.vv \S24_v, \S24_v, \T04_v
    vxor.vv \S00_v, \T00_v, \T05_v
    vnot.v \T02_v, \S02_v
    vor.vv \T04_v, \S04_v, \T00_v
    vand.vv \T03_v, \S03_v, \S04_v
    vand.vv \T05_v, \T00_v, \T01_v
    vor.vv \T02_v, \T02_v, \S03_v
    ld   \T07_s, 0(a3)
    vxor.vv \S02_v, \S02_v, \T03_v
    vxor.vv \S03_v, \S03_v, \T04_v
    vxor.vv \S01_v, \T01_v, \T02_v
    vxor.vv \S04_v, \S04_v, \T05_v
    vxor.vx \S00_v, \S00_v, \T07_s
    addi a3, a3, 8
.endm

.globl KeccakF1600_StatePermute_RV64V_2x
.align 2
KeccakF1600_StatePermute_RV64V_2x:

    vsetivli a2, 2, e64, m1, tu, mu

    LoadStates

    # a2: loop control variable i
    # a3: table index
    li a2, 24
    la a3, constants_keccak

loop:
    ARoundInPlace \
        v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,  v8,  v9,    \
        v10, v11, v12, v13, v14, v15, v16, v17, v18, v19,   \
        v20, v21, v22, v23, v24, v25, v26, v27, v28, v29,   \
        v30, v31, a4
    addi a2, a2, -1
    bnez a2, loop

    StoreStates

    ret

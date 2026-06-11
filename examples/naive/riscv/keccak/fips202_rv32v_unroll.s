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

#ifdef V0p7
.macro LoadStates
    # lane complement: 1,2,8,12,17,20
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
    addi a0, a0, -24*16
.endm
#else
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
#endif

#ifdef V0p7
.macro StoreStates
    # lane complement: 1,2,8,12,17,20
    vnot.v v1, v1
    vnot.v v2, v2
    vnot.v v8, v8
    vnot.v v12, v12
    vnot.v v17, v17
    vnot.v v20, v20
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
.endm
#else
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
#endif

.macro ARoundInPlace    S00_v, S01_v, S02_v, S03_v, S04_v, S05_v, S06_v, S07_v, S08_v, S09_v, \
                        S10_v, S11_v, S12_v, S13_v, S14_v, S15_v, S16_v, S17_v, S18_v, S19_v, \
                        S20_v, S21_v, S22_v, S23_v, S24_v, T00_v, T01_v, T02_v, T03_v, T04_v, \
                        Ts0, Ts1
    vxor.vv \T00_v, \S00_v, \S05_v
    vxor.vv \T00_v, \T00_v, \S10_v
    vxor.vv \T00_v, \T00_v, \S15_v
    vxor.vv \T00_v, \T00_v, \S20_v
    vxor.vv \T01_v, \S02_v, \S07_v
    vxor.vv \T01_v, \T01_v, \S12_v
    vxor.vv \T01_v, \T01_v, \S17_v
    vxor.vv \T01_v, \T01_v, \S22_v
    li \Ts0, 64-1
    vsll.vi \T03_v, \T01_v, 1
    vsrl.vx \T02_v, \T01_v, \Ts0
    vxor.vv \T02_v, \T02_v, \T03_v
    vxor.vv  \T02_v, \T02_v, \T00_v
    vxor.vv \T03_v, \S01_v, \S06_v
    vxor.vv \T03_v, \T03_v, \S11_v
    vxor.vv \T03_v, \T03_v, \S16_v
    vxor.vv \T03_v, \T03_v, \S21_v
    vxor.vv \S01_v, \S01_v, \T02_v
    vxor.vv \S06_v, \S06_v, \T02_v
    vxor.vv \S11_v, \S11_v, \T02_v
    vxor.vv \S16_v, \S16_v, \T02_v
    vxor.vv \S21_v, \S21_v, \T02_v
    vxor.vv \T02_v, \S04_v, \S09_v
    vxor.vv \T02_v, \T02_v, \S14_v
    vxor.vv \T02_v, \T02_v, \S19_v
    vxor.vv \T02_v, \T02_v, \S24_v
    vsll.vi \T04_v, \T02_v, 1
    vxor.vv \T01_v, \T01_v, \T04_v
    li \Ts0, 63
    vsrl.vx \T04_v, \T02_v, \Ts0
    vxor.vv \T01_v, \T01_v, \T04_v
    vxor.vv \T04_v, \S03_v, \S08_v
    vxor.vv \T04_v, \T04_v, \S13_v
    vxor.vv \T04_v, \T04_v, \S18_v
    vxor.vv \T04_v, \T04_v, \S23_v
    vxor.vv \S03_v, \S03_v, \T01_v
    vxor.vv \S08_v, \S08_v, \T01_v
    vxor.vv \S13_v, \S13_v, \T01_v
    vxor.vv \S18_v, \S18_v, \T01_v
    vxor.vv \S23_v, \S23_v, \T01_v
    li \Ts0, 64-1
    vsll.vi \T01_v, \T00_v, 1
    vsrl.vx \T00_v, \T00_v, \Ts0
    vxor.vv \T00_v, \T00_v, \T01_v
    vxor.vv \T00_v, \T00_v, \T04_v
    vxor.vv \S04_v, \S04_v, \T00_v
    vxor.vv \S09_v, \S09_v, \T00_v
    vxor.vv \S14_v, \S14_v, \T00_v
    vxor.vv \S19_v, \S19_v, \T00_v
    vxor.vv \S24_v, \S24_v, \T00_v
    li \Ts0, 64-1
    vsll.vi \T01_v, \T04_v, 1
    vsrl.vx \T04_v, \T04_v, \Ts0
    vxor.vv \T04_v, \T04_v, \T01_v
    vxor.vv  \T04_v, \T04_v, \T03_v
    vxor.vv \S02_v, \S02_v, \T04_v
    vxor.vv \S07_v, \S07_v, \T04_v
    vxor.vv \S12_v, \S12_v, \T04_v
    vxor.vv \S17_v, \S17_v, \T04_v
    vxor.vv \S22_v, \S22_v, \T04_v
    li \Ts0, 64-1
    vsll.vi \T01_v, \T03_v, 1
    vsrl.vx \T03_v, \T03_v, \Ts0
    vxor.vv \T03_v, \T03_v, \T01_v
    vxor.vv  \T03_v, \T03_v, \T02_v
    vxor.vv \S05_v, \S05_v, \T03_v
    vxor.vv \S10_v, \S10_v, \T03_v
    vxor.vv \S15_v, \S15_v, \T03_v
    vxor.vv \S20_v, \S20_v, \T03_v
    vxor.vv \T00_v, \S00_v, \T03_v
    li \Ts0, 44
    vsll.vx \T02_v, \S06_v, \Ts0
    vsrl.vi \T01_v, \S06_v, 64-44
    vxor.vv \T01_v, \T01_v, \T02_v
    li \Ts0, 62
    vsll.vx \T03_v, \S02_v, \Ts0
    vsrl.vi \S00_v, \S02_v, 64-62
    vxor.vv \S00_v, \S00_v, \T03_v
    li \Ts0, 43
    vsll.vx \T02_v, \S12_v, \Ts0
    vsrl.vi \S02_v, \S12_v, 64-43
    vxor.vv \S02_v, \S02_v, \T02_v
    li \Ts0, 64-25
    vsll.vi \T03_v, \S13_v, 25
    vsrl.vx \S12_v, \S13_v, \Ts0
    vxor.vv \S12_v, \S12_v, \T03_v
    li \Ts0, 64-8
    vsll.vi \T02_v, \S19_v, 8
    vsrl.vx \S13_v, \S19_v, \Ts0
    vxor.vv \S13_v, \S13_v, \T02_v
    li \Ts0, 56
    vsll.vx \T03_v, \S23_v, \Ts0
    vsrl.vi \S19_v, \S23_v, 64-56
    vxor.vv \S19_v, \S19_v, \T03_v
    li \Ts0, 41
    vsll.vx \T02_v, \S15_v, \Ts0
    vsrl.vi \S23_v, \S15_v, 64-41
    vxor.vv \S23_v, \S23_v, \T02_v
    li \Ts0, 64-1
    vsll.vi \T03_v, \S01_v, 1
    vsrl.vx \S15_v, \S01_v, \Ts0
    vxor.vv \S15_v, \S15_v, \T03_v
    li \Ts0, 55
    vsll.vx \T02_v, \S08_v, \Ts0
    vsrl.vi \S01_v, \S08_v, 64-55
    vxor.vv \S01_v, \S01_v, \T02_v
    li \Ts0, 45
    vsll.vx \T03_v, \S16_v, \Ts0
    vsrl.vi \S08_v, \S16_v, 64-45
    vxor.vv \S08_v, \S08_v, \T03_v
    li \Ts0, 64-6
    vsll.vi \T02_v, \S07_v, 6
    vsrl.vx \S16_v, \S07_v, \Ts0
    vxor.vv \S16_v, \S16_v, \T02_v
    li \Ts0, 64-3
    vsll.vi \T03_v, \S10_v, 3
    vsrl.vx \S07_v, \S10_v, \Ts0
    vxor.vv \S07_v, \S07_v, \T03_v
    li \Ts0, 64-28
    vsll.vi \T02_v, \S03_v, 28
    vsrl.vx \S10_v, \S03_v, \Ts0
    vxor.vv \S10_v, \S10_v, \T02_v
    li \Ts0, 64-21
    vsll.vi \T03_v, \S18_v, 21
    vsrl.vx \S03_v, \S18_v, \Ts0
    vxor.vv \S03_v, \S03_v, \T03_v
    li \Ts0, 64-15
    vsll.vi \T02_v, \S17_v, 15
    vsrl.vx \S18_v, \S17_v, \Ts0
    vxor.vv \S18_v, \S18_v, \T02_v
    li \Ts0, 64-10
    vsll.vi \T03_v, \S11_v, 10
    vsrl.vx \S17_v, \S11_v, \Ts0
    vxor.vv \S17_v, \S17_v, \T03_v
    li \Ts0, 64-20
    vsll.vi \T02_v, \S09_v, 20
    vsrl.vx \S11_v, \S09_v, \Ts0
    vxor.vv \S11_v, \S11_v, \T02_v
    li \Ts0, 61
    vsll.vx \T03_v, \S22_v, \Ts0
    vsrl.vi \S09_v, \S22_v, 64-61
    vxor.vv \S09_v, \S09_v, \T03_v
    li \Ts0, 39
    vsll.vx \T02_v, \S14_v, \Ts0
    vsrl.vi \S22_v, \S14_v, 64-39
    vxor.vv \S22_v, \S22_v, \T02_v
    li \Ts0, 64-18
    vsll.vi \T03_v, \S20_v, 18
    vsrl.vx \S14_v, \S20_v, \Ts0
    vxor.vv \S14_v, \S14_v, \T03_v
    li \Ts0, 64-27
    vsll.vi \T02_v, \S04_v, 27
    vsrl.vx \S20_v, \S04_v, \Ts0
    vxor.vv \S20_v, \S20_v, \T02_v
    li \Ts0, 64-14
    vsll.vi \T03_v, \S24_v, 14
    vsrl.vx \S04_v, \S24_v, \Ts0
    vxor.vv \S04_v, \S04_v, \T03_v
    li \Ts0, 64-2
    vsll.vi \T02_v, \S21_v, 2
    vsrl.vx \S24_v, \S21_v, \Ts0
    vxor.vv \S24_v, \S24_v, \T02_v
    li \Ts0, 36
    vsll.vx \T03_v, \S05_v, \Ts0
    vsrl.vi \S21_v, \S05_v, 64-36
    vxor.vv \S21_v, \S21_v, \T03_v
    vor.vv \T02_v, \S11_v, \S07_v
    vxor.vv \S05_v, \S10_v, \T02_v
    vand.vv \T03_v, \S07_v, \S08_v
    vxor.vv \S06_v, \S11_v, \T03_v
    vnot.v \T02_v, \S09_v
    vor.vv  \T02_v, \T02_v, \S08_v
    vxor.vv \S07_v, \S07_v, \T02_v
    vor.vv \T03_v, \S09_v, \S10_v
    vxor.vv \S08_v, \S08_v, \T03_v
    vand.vv \T02_v, \S10_v, \S11_v
    vxor.vv \S09_v, \S09_v, \T02_v
    vor.vv \T03_v, \S16_v, \S12_v
    vxor.vv \S10_v, \S15_v, \T03_v
    vand.vv \T02_v, \S12_v, \S13_v
    vxor.vv \S11_v, \S16_v, \T02_v
    vnot.v \T03_v, \S13_v
    vand.vv \T03_v, \T03_v, \S14_v
    vxor.vv \S12_v, \S12_v, \T03_v
    vnot.v \T03_v, \S13_v
    vor.vv  \T02_v, \S14_v, \S15_v
    vxor.vv \S13_v, \T03_v, \T02_v
    vand.vv \T03_v, \S15_v, \S16_v
    vxor.vv \S14_v, \S14_v, \T03_v
    vand.vv \T02_v, \S21_v, \S17_v
    vxor.vv \S15_v, \S20_v, \T02_v
    vor.vv \T03_v, \S17_v, \S18_v
    vxor.vv \S16_v, \S21_v, \T03_v
    vnot.v \T02_v, \S18_v
    vor.vv  \T02_v, \T02_v, \S19_v
    vxor.vv \S17_v, \S17_v, \T02_v
    vnot.v \T02_v, \S18_v
    vand.vv \T03_v, \S19_v, \S20_v
    vxor.vv \S18_v, \T02_v, \T03_v
    vor.vv \T02_v, \S20_v, \S21_v
    vxor.vv \S19_v, \S19_v, \T02_v
    vnot.v \T03_v, \S01_v
    vand.vv \T03_v, \T03_v, \S22_v
    vxor.vv \S20_v, \S00_v, \T03_v
    vnot.v \T03_v, \S01_v
    vor.vv  \T02_v, \S22_v, \S23_v
    vxor.vv \S21_v, \T03_v, \T02_v
    vand.vv \T03_v, \S23_v, \S24_v
    vxor.vv \S22_v, \S22_v, \T03_v
    vor.vv \T02_v, \S24_v, \S00_v
    vxor.vv \S23_v, \S23_v, \T02_v
    vand.vv \T03_v, \S00_v, \S01_v
    vxor.vv \S24_v, \S24_v, \T03_v
    vor.vv \T02_v, \T01_v, \S02_v
    vxor.vv \S00_v, \T00_v, \T02_v
    vnot.v \T03_v, \S02_v
    vor.vv \T03_v, \T03_v, \S03_v
    vxor.vv \S01_v, \T01_v, \T03_v
    vand.vv \T02_v, \S03_v, \S04_v
    vxor.vv \S02_v, \S02_v, \T02_v
    vor.vv \T03_v, \S04_v, \T00_v
    vxor.vv \S03_v, \S03_v, \T03_v
    vand.vv \T02_v, \T00_v, \T01_v
    vxor.vv \S04_v, \S04_v, \T02_v
    vle64.v  \T00_v, 0(\Ts1)
    vxor.vv  \S00_v, \S00_v, \T00_v
    addi \Ts1, \Ts1, 16
.endm

.globl KeccakF1600_StatePermute_RV64V_2x
.align 2
KeccakF1600_StatePermute_RV64V_2x:

    li a1, 128
vsetivli a2, 2, e64, m1, tu, mu

    # LoadStates
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

    # a2: loop control variable i
    # a3: table index
    li a2, 24
    la a3, constants_keccak

loop:
    ARoundInPlace \
        v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,  v8,  v9,    \
        v10, v11, v12, v13, v14, v15, v16, v17, v18, v19,   \
        v20, v21, v22, v23, v24, v25, v26, v27, v28, v29,   \
        a4, a3
    addi a2, a2, -1
    bnez a2, loop

    # StoreStates
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

    ret

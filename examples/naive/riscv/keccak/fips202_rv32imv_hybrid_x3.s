.data
.align 2
constants_keccak:
.quad 0x0000000000000001
.quad 0x0000000000000001
.quad 0x0000000000008082
.quad 0x0000000000008082
.quad 0x800000000000808a
.quad 0x800000000000808a
.quad 0x8000000080008000
.quad 0x8000000080008000
.quad 0x000000000000808b
.quad 0x000000000000808b
.quad 0x0000000080000001
.quad 0x0000000080000001
.quad 0x8000000080008081
.quad 0x8000000080008081
.quad 0x8000000000008009
.quad 0x8000000000008009
.quad 0x000000000000008a
.quad 0x000000000000008a
.quad 0x0000000000000088
.quad 0x0000000000000088
.quad 0x0000000080008009
.quad 0x0000000080008009
.quad 0x000000008000000a
.quad 0x000000008000000a
.quad 0x000000008000808b
.quad 0x000000008000808b
.quad 0x800000000000008b
.quad 0x800000000000008b
.quad 0x8000000000008089
.quad 0x8000000000008089
.quad 0x8000000000008003
.quad 0x8000000000008003
.quad 0x8000000000008002
.quad 0x8000000000008002
.quad 0x8000000000000080
.quad 0x8000000000000080
.quad 0x000000000000800a
.quad 0x000000000000800a
.quad 0x800000008000000a
.quad 0x800000008000000a
.quad 0x8000000080008081
.quad 0x8000000080008081
.quad 0x8000000000008080
.quad 0x8000000000008080
.quad 0x0000000080000001
.quad 0x0000000080000001
.quad 0x8000000080008008
.quad 0x8000000080008008

.text

.macro SaveRegs
    sw s0,  0*4(sp)
    sw s1,  1*4(sp)
    sw s2,  2*4(sp)
    sw s3,  3*4(sp)
    sw s4,  4*4(sp)
    sw s5,  5*4(sp)
    sw s6,  6*4(sp)
    sw s7,  7*4(sp)
    sw s8,  8*4(sp)
    sw s9,  9*4(sp)
    sw s10, 10*4(sp)
    sw s11, 11*4(sp)
    sw gp,  12*4(sp)
    sw tp,  13*4(sp)
    sw ra,  14*4(sp)
.endm

.macro RestoreRegs
    lw s0,  0*4(sp)
    lw s1,  1*4(sp)
    lw s2,  2*4(sp)
    lw s3,  3*4(sp)
    lw s4,  4*4(sp)
    lw s5,  5*4(sp)
    lw s6,  6*4(sp)
    lw s7,  7*4(sp)
    lw s8,  8*4(sp)
    lw s9,  9*4(sp)
    lw s10, 10*4(sp)
    lw s11, 11*4(sp)
    lw gp,  12*4(sp)
    lw tp,  13*4(sp)
    lw ra,  14*4(sp)
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

.macro LoadStates_s \
        S02h_s, S02l_s, S04h_s, S04l_s, S05h_s, S05l_s, S08h_s, S08l_s, S10h_s, S10l_s, \
        S14h_s, S14l_s, S16h_s, S16l_s, S17h_s, S17l_s, S21h_s, S21l_s, S23h_s, S23l_s, \
        T00h_s, T00l_s, T01h_s, T01l_s, T02h_s, T02l_s, T03h_s, T03l_s, T04_s
    lw \S02l_s, 2*8(a0)
    lw \S02h_s, 2*8+4(a0)
    lw \S04l_s, 4*8(a0)
    lw \S04h_s, 4*8+4(a0)
    lw \S05l_s, 5*8(a0)
    lw \S05h_s, 5*8+4(a0)
    lw \S08l_s, 8*8(a0)
    lw \S08h_s, 8*8+4(a0)
    lw \S10l_s, 10*8(a0)
    lw \S10h_s, 10*8+4(a0)
    lw \S14l_s, 14*8(a0)
    lw \S14h_s, 14*8+4(a0)
    lw \S16l_s, 16*8(a0)
    lw \S16h_s, 16*8+4(a0)
    lw \S17l_s, 17*8(a0)
    lw \S17h_s, 17*8+4(a0)
    lw \S21l_s, 21*8(a0)
    lw \S21h_s, 21*8+4(a0)
    # lane complement: 1,2,8,12,17,20
    lw \T00l_s, 1*8(a0)
    lw \T00h_s, 1*8+4(a0)
    lw \S23l_s, 23*8(a0)
    lw \S23h_s, 23*8+4(a0)
    not \T00l_s, \T00l_s
    not \T00h_s, \T00h_s
    lw \T01l_s, 12*8(a0)
    lw \T01h_s, 12*8+4(a0)
    sw \T00l_s, 1*8(a0)
    sw \T00h_s, 1*8+4(a0)
    not \T01l_s, \T01l_s
    not \T01h_s, \T01h_s
    lw \T00l_s, 20*8(a0)
    lw \T00h_s, 20*8+4(a0)
    sw \T01l_s, 12*8(a0)
    sw \T01h_s, 12*8+4(a0)
    not \T00l_s, \T00l_s
    not \T00h_s, \T00h_s
    not \S02l_s, \S02l_s
    not \S02h_s, \S02h_s
    sw \T00l_s, 20*8(a0)
    sw \T00h_s, 20*8+4(a0)
    not \S08l_s, \S08l_s
    not \S08h_s, \S08h_s
    not \S17l_s, \S17l_s
    not \S17h_s, \S17h_s
.endm

.macro StoreStates_s \
        S02h_s, S02l_s, S04h_s, S04l_s, S05h_s, S05l_s, S08h_s, S08l_s, S10h_s, S10l_s, \
        S14h_s, S14l_s, S16h_s, S16l_s, S17h_s, S17l_s, S21h_s, S21l_s, S23h_s, S23l_s, \
        T00h_s, T00l_s, T01h_s, T01l_s, T02h_s, T02l_s, T03h_s, T03l_s, T04_s
    # lane complement: 1,2,8,12,17,20
    lw \T00l_s, 1*8(a0)
    lw \T00h_s, 1*8+4(a0)
    not \S02l_s, \S02l_s
    not \S02h_s, \S02h_s
    not \T00l_s, \T00l_s
    not \T00h_s, \T00h_s
    sw \T00l_s, 1*8(a0)
    sw \T00h_s, 1*8+4(a0)
    lw \T01l_s, 12*8(a0)
    lw \T01h_s, 12*8+4(a0)
    not \S08l_s, \S08l_s
    not \S08h_s, \S08h_s
    not \T01l_s, \T01l_s
    not \T01h_s, \T01h_s
    sw \T01l_s, 12*8(a0)
    sw \T01h_s, 12*8+4(a0)
    lw \T00l_s, 20*8(a0)
    lw \T00h_s, 20*8+4(a0)
    not \S17l_s, \S17l_s
    not \S17h_s, \S17h_s
    not \T00l_s, \T00l_s
    not \T00h_s, \T00h_s
    sw \T00l_s, 20*8(a0)
    sw \T00h_s, 20*8+4(a0)
    sw \S02l_s, 2*8(a0)
    sw \S02h_s, 2*8+4(a0)
    sw \S04l_s, 4*8(a0)
    sw \S04h_s, 4*8+4(a0)
    sw \S05l_s, 5*8(a0)
    sw \S05h_s, 5*8+4(a0)
    sw \S08l_s, 8*8(a0)
    sw \S08h_s, 8*8+4(a0)
    sw \S10l_s, 10*8(a0)
    sw \S10h_s, 10*8+4(a0)
    sw \S14l_s, 14*8(a0)
    sw \S14h_s, 14*8+4(a0)
    sw \S16l_s, 16*8(a0)
    sw \S16h_s, 16*8+4(a0)
    sw \S17l_s, 17*8(a0)
    sw \S17h_s, 17*8+4(a0)
    sw \S21l_s, 21*8(a0)
    sw \S21h_s, 21*8+4(a0)
    sw \S23l_s, 23*8(a0)
    sw \S23h_s, 23*8+4(a0)
.endm

.macro ARound  \
        S00_v, S01_v, S02_v, S03_v, S04_v, S05_v, S06_v, S07_v, S08_v, S09_v, \
        S10_v, S11_v, S12_v, S13_v, S14_v, S15_v, S16_v, S17_v, S18_v, S19_v, \
        S20_v, S21_v, S22_v, S23_v, S24_v, T00_v, T01_v, T02_v, T03_v, T04_v, \
        T05_v, T06_v, \
        S02h_s, S02l_s, S04h_s, S04l_s, S05h_s, S05l_s, S08h_s, S08l_s, S10h_s, S10l_s, \
        S14h_s, S14l_s, S16h_s, S16l_s, S17h_s, S17l_s, S21h_s, S21l_s, S23h_s, S23l_s, \
        T00h_s, T00l_s, T01h_s, T01l_s, T02h_s, T02l_s, T03h_s, T03l_s, T04_s
    lw \T03l_s, 0*8(a0)
    lw \T03h_s, 0*8+4(a0)
    xor \T00l_s, \S05l_s, \S10l_s
    xor \T00h_s, \S05h_s, \S10h_s
    vxor.vv \T00_v, \S01_v, \S06_v
    lw \T02l_s, 15*8(a0)
    lw \T02h_s, 15*8+4(a0)
    xor \T00l_s, \T00l_s, \T03l_s
    vxor.vv \T01_v, \S04_v, \S09_v
    xor \T00h_s, \T00h_s, \T03h_s
    lw \T03l_s, 20*8(a0)
    lw \T03h_s, 20*8+4(a0)
    vxor.vv \T02_v, \S03_v, \S08_v
    xor \T00l_s, \T00l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T02h_s
    xor \T00l_s, \T00l_s, \T03l_s
    vxor.vv \T00_v, \T00_v, \S11_v
    xor \T00h_s, \T00h_s, \T03h_s
    lw \T03l_s, 3*8(a0)
    lw \T03h_s, 3*8+4(a0)
    vxor.vv \T01_v, \T01_v, \S14_v
    sw \T00l_s, 18*4(sp)
    sw \T00h_s, 19*4(sp)
    xor \T01l_s, \S08l_s, \S23l_s
    vxor.vv \T02_v, \T02_v, \S13_v
    xor \T01h_s, \S08h_s, \S23h_s
    lw \T02l_s, 13*8(a0)
    lw \T02h_s, 13*8+4(a0)
    vxor.vv \T00_v, \T00_v, \S16_v
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T01h_s, \T01h_s, \T03h_s
    lw \T03l_s, 18*8(a0)
    vxor.vv \T01_v, \T01_v, \S19_v
    lw \T03h_s, 18*8+4(a0)
    xor \T01l_s, \T01l_s, \T02l_s
    xor \T01h_s, \T01h_s, \T02h_s
    vxor.vv \T02_v, \T02_v, \S18_v
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T01h_s, \T01h_s, \T03h_s
    srli \T03h_s,   \T00l_s, 31
    vxor.vv \T00_v, \T00_v, \S21_v
    slli \T00l_s, \T00l_s, 1
    srli \T03l_s,   \T00h_s, 31
    slli \T00h_s, \T00h_s, 1
    xor  \T00l_s, \T00l_s, \T03l_s
    vxor.vv \T01_v, \T01_v, \S24_v
    xor  \T00h_s, \T00h_s, \T03h_s
    sw \T01l_s, 24*4(sp)
    sw \T01h_s, 25*4(sp)
    vxor.vv \T02_v, \T02_v, \S23_v
    li \T04_s, 64-1
    xor \T00l_s, \T00l_s, \T01l_s
    xor \T00h_s, \T00h_s, \T01h_s
    lw \T03l_s, 9*8(a0)
    vsll.vi \T05_v, \T00_v, 1
    lw \T03h_s, 9*8+4(a0)
    xor \T01l_s, \S04l_s, \S14l_s
    xor \T01h_s, \S04h_s, \S14h_s
    vsll.vi \T06_v, \T02_v, 1
    xor \S04l_s, \S04l_s, \T00l_s
    xor \S04h_s, \S04h_s, \T00h_s
    xor \S14l_s, \S14l_s, \T00l_s
    vsrl.vx \T03_v, \T00_v, \T04_s
    xor \S14h_s, \S14h_s, \T00h_s
    lw \T02l_s, 19*8(a0)
    lw \T02h_s, 19*8+4(a0)
    vsrl.vx \T04_v, \T02_v, \T04_s
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T03l_s, \T03l_s, \T00l_s
    vxor.vv \T03_v, \T03_v, \T05_v
    xor \T03h_s, \T03h_s, \T00h_s
    sw \T03l_s, 9*8(a0)
    sw \T03h_s, 9*8+4(a0)
    vxor.vv \T04_v, \T04_v, \T06_v
    lw \T03l_s, 24*8(a0)
    lw \T03h_s, 24*8+4(a0)
    xor \T01l_s, \T01l_s, \T02l_s
    vxor.vv \T03_v, \T03_v, \T01_v
    xor \T01h_s, \T01h_s, \T02h_s
    xor \T02l_s, \T02l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T00h_s
    vxor.vv \T04_v, \T04_v, \T00_v
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T01h_s, \T01h_s, \T03h_s
    sw \T02l_s, 19*8(a0)
    sw \T02h_s, 19*8+4(a0)
    vxor.vv \T05_v, \S00_v, \S05_v
    xor \T03l_s, \T03l_s, \T00l_s
    xor \T03h_s, \T03h_s, \T00h_s
    sw \T01l_s, 26*4(sp)
    vxor.vv \T06_v, \S02_v, \S07_v
    sw \T01h_s, 27*4(sp)
    sw \T03l_s, 24*8(a0)
    sw \T03h_s, 24*8+4(a0)
    vxor.vv \T05_v, \T05_v, \S10_v
    lw \T03l_s, 1*8(a0)
    lw \T03h_s, 1*8+4(a0)
    xor \T00l_s, \S16l_s, \S21l_s
    vxor.vv \T06_v, \T06_v, \S12_v
    xor \T00h_s, \S16h_s, \S21h_s
    lw \T02l_s, 6*8(a0)
    lw \T02h_s, 6*8+4(a0)
    vxor.vv \T05_v, \T05_v, \S15_v
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    lw \T03l_s, 11*8(a0)
    vxor.vv \T06_v, \T06_v, \S17_v
    lw \T03h_s, 11*8+4(a0)
    xor \T00l_s, \T00l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T02h_s
    vxor.vv \T05_v, \T05_v, \S20_v
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    sw \T00l_s, 20*4(sp)
    vxor.vv \T06_v, \T06_v, \S22_v
    sw \T00h_s, 21*4(sp)
    srli \T03h_s,   \T00l_s, 31
    slli \T00l_s, \T00l_s, 1
    vxor.vv \S00_v, \S00_v, \T03_v
    srli \T03l_s,   \T00h_s, 31
    slli \T00h_s, \T00h_s, 1
    xor  \T00l_s, \T00l_s, \T03l_s
    vxor.vv \S05_v, \S05_v, \T03_v
    xor  \T00h_s, \T00h_s, \T03h_s
    lw \T02l_s, 0*8(a0)
    lw \T02h_s, 0*8+4(a0)
    xor \T00l_s, \T00l_s, \T01l_s
    vxor.vv \S10_v, \S10_v, \T03_v
    xor \T00h_s, \T00h_s, \T01h_s
    xor \S05l_s, \S05l_s, \T00l_s
    xor \S05h_s, \S05h_s, \T00h_s
    vxor.vv \S15_v, \S15_v, \T03_v
    lw \T03l_s, 20*8(a0)
    lw \T03h_s, 20*8+4(a0)
    xor \T02l_s, \T02l_s, \T00l_s
    vxor.vv \S20_v, \S20_v, \T03_v
    xor \T02h_s, \T02h_s, \T00h_s
    sw \T02l_s, 0*8(a0)
    sw \T02h_s, 0*8+4(a0)
    vxor.vv \S02_v, \S02_v, \T04_v
    lw \T02l_s, 15*8(a0)
    lw \T02h_s, 15*8+4(a0)
    xor \S10l_s, \S10l_s, \T00l_s
    vxor.vv \S07_v, \S07_v, \T04_v
    xor \S10h_s, \S10h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T00h_s
    vxor.vv \S12_v, \S12_v, \T04_v
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    xor \T03l_s, \T03l_s, \T00l_s
    vsll.vi \T03_v, \T01_v, 1
    xor \T03h_s, \T03h_s, \T00h_s
    lw \T02l_s, 24*4(sp)
    lw \T02h_s, 25*4(sp)
    vsrl.vx \T00_v, \T01_v, \T04_s
    lw \T00l_s, 20*4(sp)
    lw \T00h_s, 21*4(sp)
    sw \T03l_s, 20*8(a0)
    vxor.vv \S17_v, \S17_v, \T04_v
    sw \T03h_s, 20*8+4(a0)
    srli \T03h_s,   \T02l_s, 31
    slli \T02l_s, \T02l_s, 1
    vxor.vv \S22_v, \S22_v, \T04_v
    srli \T03l_s,   \T02h_s, 31
    slli \T02h_s, \T02h_s, 1
    xor  \T02l_s, \T02l_s, \T03l_s
    xor  \T02h_s, \T02h_s, \T03h_s
    vxor.vv \T00_v, \T00_v, \T03_v
    lw \T03l_s, 7*8(a0)
    lw \T03h_s, 7*8+4(a0)
    xor \T02l_s, \T02l_s, \T00l_s
    vxor.vv \T00_v, \T00_v, \T06_v
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T00l_s, \S02l_s, \S17l_s
    xor \T00h_s, \S02h_s, \S17h_s
    vxor.vv \S03_v, \S03_v, \T00_v
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T03l_s, \T02l_s
    vxor.vv \S08_v, \S08_v, \T00_v
    xor \T03h_s, \T03h_s, \T02h_s
    xor \S02l_s, \S02l_s, \T02l_s
    xor \S02h_s, \S02h_s, \T02h_s
    vxor.vv \S13_v, \S13_v, \T00_v
    sw \T03l_s, 7*8(a0)
    sw \T03h_s, 7*8+4(a0)
    lw \T03l_s, 12*8(a0)
    vxor.vv \S18_v, \S18_v, \T00_v
    lw \T03h_s, 12*8+4(a0)
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    vxor.vv \S23_v, \S23_v, \T00_v
    xor \T03l_s, \T03l_s, \T02l_s
    xor \T03h_s, \T03h_s, \T02h_s
    xor \S17l_s, \S17l_s, \T02l_s
    vsll.vi \T00_v, \T06_v, 1
    xor \S17h_s, \S17h_s, \T02h_s
    sw \T03l_s, 12*8(a0)
    sw \T03h_s, 12*8+4(a0)
    vsll.vi \T03_v, \T05_v, 1
    lw \T03l_s, 22*8(a0)
    lw \T03h_s, 22*8+4(a0)
    xor \T00l_s, \T00l_s, \T03l_s
    vsrl.vx \T01_v, \T06_v, \T04_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T03l_s, \T02l_s
    xor \T03h_s, \T03h_s, \T02h_s
    sw \T00l_s, 22*4(sp)
    vsrl.vx \T04_v, \T05_v, \T04_s
    sw \T00h_s, 23*4(sp)
    sw \T03l_s, 22*8(a0)
    sw \T03h_s, 22*8+4(a0)
    vxor.vv \T01_v, \T01_v, \T00_v
    srli \T03h_s,   \T01l_s, 31
    slli \T01l_s, \T01l_s, 1
    srli \T03l_s,   \T01h_s, 31
    vxor.vv \T04_v, \T04_v, \T03_v
    slli \T01h_s, \T01h_s, 1
    xor  \T01l_s, \T01l_s, \T03l_s
    xor  \T01h_s, \T01h_s, \T03h_s
    vxor.vv \T01_v, \T01_v, \T05_v
    lw \T03l_s, 3*8(a0)
    lw \T03h_s, 3*8+4(a0)
    xor \T01l_s, \T01l_s, \T00l_s
    vxor.vv \T04_v, \T04_v, \T02_v
    xor \T01h_s, \T01h_s, \T00h_s
    xor \S08l_s, \S08l_s, \T01l_s
    xor \S08h_s, \S08h_s, \T01h_s
    vxor.vv \S01_v, \S01_v, \T01_v
    xor \T03l_s, \T03l_s, \T01l_s
    xor \T03h_s, \T03h_s, \T01h_s
    lw \T02l_s, 13*8(a0)
    vxor.vv \S06_v, \S06_v, \T01_v
    lw \T02h_s, 13*8+4(a0)
    sw \T03l_s, 3*8(a0)
    sw \T03h_s, 3*8+4(a0)
    vxor.vv \S11_v, \S11_v, \T01_v
    lw \T03l_s, 18*8(a0)
    lw \T03h_s, 18*8+4(a0)
    xor \T02l_s, \T02l_s, \T01l_s
    vxor.vv \S16_v, \S16_v, \T01_v
    xor \T02h_s, \T02h_s, \T01h_s
    xor \S23l_s, \S23l_s, \T01l_s
    xor \S23h_s, \S23h_s, \T01h_s
    vxor.vv \S21_v, \S21_v, \T01_v
    sw \T02l_s, 13*8(a0)
    sw \T02h_s, 13*8+4(a0)
    xor \T03l_s, \T03l_s, \T01l_s
    xor \T03h_s, \T03h_s, \T01h_s
    vxor.vv \S04_v, \S04_v, \T04_v
    lw \T01l_s, 18*4(sp)
    lw \T01h_s, 19*4(sp)
    sw \T03l_s, 18*8(a0)
    vxor.vv \S09_v, \S09_v, \T04_v
    sw \T03h_s, 18*8+4(a0)
    srli \T03h_s,   \T00l_s, 31
    slli \T00l_s, \T00l_s, 1
    vxor.vv \S14_v, \S14_v, \T04_v
    srli \T03l_s,   \T00h_s, 31
    slli \T00h_s, \T00h_s, 1
    xor  \T00l_s, \T00l_s, \T03l_s
    vxor.vv \S19_v, \S19_v, \T04_v
    xor  \T00h_s, \T00h_s, \T03h_s
    lw \T02l_s, 1*8(a0)
    lw \T02h_s, 1*8+4(a0)
    vxor.vv \S24_v, \S24_v, \T04_v
    xor \T00l_s, \T00l_s, \T01l_s
    xor \T00h_s, \T00h_s, \T01h_s
    lw \T03l_s, 6*8(a0)
    vmv.v.v \T00_v, \S00_v
    li \T04_s, 44
    lw \T03h_s, 6*8+4(a0)
    xor \S16l_s, \S16l_s, \T00l_s
    xor \S16h_s, \S16h_s, \T00h_s
    vsrl.vi \T01_v, \S06_v, 20
    xor \S21l_s, \S21l_s, \T00l_s
    xor \S21h_s, \S21h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    vsll.vx \T02_v, \S06_v, \T04_s
    li \T04_s, 62
    xor \T02h_s, \T02h_s, \T00h_s
    sw \T02l_s, 1*8(a0)
    sw \T02h_s, 1*8+4(a0)
    vsrl.vi \S00_v, \S02_v, 2
    xor \T03l_s, \T03l_s, \T00l_s
    xor \T03h_s, \T03h_s, \T00h_s
    lw \T02l_s, 11*8(a0)
    vsll.vx \T03_v, \S02_v, \T04_s
    lw \T02h_s, 11*8+4(a0)
    sw \T03l_s, 6*8(a0)
    sw \T03h_s, 6*8+4(a0)
    xor \T02l_s, \T02l_s, \T00l_s
    vxor.vv \T01_v, \T01_v, \T02_v
    xor \T02h_s, \T02h_s, \T00h_s
    mv \T01l_s, \T03l_s
    mv \T01h_s, \T03h_s
    vxor.vv \S00_v, \S00_v, \T03_v
    li \T04_s, 43
    sw \T02l_s, 11*8(a0)
    sw \T02h_s, 11*8+4(a0)
    slli \T03l_s, \S21l_s, 2
    vsrl.vi \S02_v, \S12_v, 21
    srli \S21l_s, \S21l_s, 30
    srli \T03h_s, \S21h_s, 30
    slli \S21h_s, \S21h_s, 2
    vsll.vx \T02_v, \S12_v, \T04_s
    li \T04_s, 39
    xor  \T03l_s, \T03l_s, \T03h_s
    xor  \T03h_s, \S21h_s, \S21l_s
    slli \T02h_s,  \T01l_s, 12
    vsll.vi \T03_v, \S13_v, 25
    srli \T01l_s, \T01l_s, 20
    slli \T02l_s,  \T01h_s, 12
    srli \T01h_s, \T01h_s, 20
    vsrl.vx \S12_v, \S13_v, \T04_s
    xor  \T01l_s, \T01l_s, \T02l_s
    xor  \T01h_s, \T01h_s, \T02h_s
    lw \T00l_s, 0*8(a0)
    vxor.vv \S02_v, \S02_v, \T02_v
    lw \T00h_s, 0*8+4(a0)
    slli \S21l_s, \S08h_s, 23
    srli \S08h_s, \S08h_s, 9
    vxor.vv \S12_v, \S12_v, \T03_v
    li \T04_s, 56
    srli \S21h_s, \S08l_s, 9
    slli \S08l_s, \S08l_s, 23
    xor  \S21l_s, \S21l_s, \S21h_s
    vsll.vi \T02_v, \S19_v, 8
    xor  \S21h_s, \S08l_s, \S08h_s
    sw \T03l_s, 0*8(a0)
    sw \T03h_s, 0*8+4(a0)
    vsrl.vx \S13_v, \S19_v, \T04_s
    li \T04_s, 56
    slli \S08l_s, \S16h_s, 13
    srli \S16h_s, \S16h_s, 19
    srli \S08h_s, \S16l_s, 19
    slli \S16l_s, \S16l_s, 13
    vsrl.vi \S19_v, \S23_v, 8
    xor  \S08l_s, \S08l_s, \S08h_s
    xor  \S08h_s, \S16l_s, \S16h_s
    lw \T02l_s, 3*8(a0)
    vsll.vx \T03_v, \S23_v, \T04_s
    lw \T02h_s, 3*8+4(a0)
    slli \S16l_s, \S05h_s, 4
    srli \S05h_s, \S05h_s, 28
    vxor.vv \S13_v, \S13_v, \T02_v
    srli \S16h_s, \S05l_s, 28
    slli \S05l_s, \S05l_s, 4
    xor  \S16l_s, \S16l_s, \S16h_s
    vxor.vv \S19_v, \S19_v, \T03_v
    li \T04_s, 41
    xor  \S16h_s, \S05l_s, \S05h_s
    lw \T03l_s, 18*8(a0)
    lw \T03h_s, 18*8+4(a0)
    vsrl.vi \S23_v, \S15_v, 23
    slli \S05l_s, \T02l_s, 28
    srli \T02l_s, \T02l_s, 4
    srli \S05h_s, \T02h_s, 4
    vsll.vx \T02_v, \S15_v, \T04_s
    li \T04_s, 63
    slli \T02h_s, \T02h_s, 28
    xor  \S05l_s, \S05l_s, \S05h_s
    xor  \S05h_s, \T02h_s, \T02l_s
    vsll.vi \T03_v, \S01_v, 1
    slli \T02l_s, \T03l_s, 21
    srli \T03l_s, \T03l_s, 11
    srli \T02h_s, \T03h_s, 11
    vsrl.vx \S15_v, \S01_v, \T04_s
    slli \T03h_s, \T03h_s, 21
    xor  \T02l_s, \T02l_s, \T02h_s
    xor  \T02h_s, \T03h_s, \T03l_s
    vxor.vv \S23_v, \S23_v, \T02_v
    lw \T03l_s, 13*8(a0)
    lw \T03h_s, 13*8+4(a0)
    sw \T02l_s, 3*8(a0)
    vxor.vv \S15_v, \S15_v, \T03_v
    li \T04_s, 55
    sw \T02h_s, 3*8+4(a0)
    srli \T02h_s,   \T03l_s, 7
    slli \T03l_s, \T03l_s, 25
    srli \T02l_s,   \T03h_s, 7
    vsrl.vi \S01_v, \S08_v, 9
    slli \T03h_s, \T03h_s, 25
    xor  \T03l_s, \T03l_s, \T02l_s
    xor  \T03h_s, \T03h_s, \T02h_s
    vsll.vx \T02_v, \S08_v, \T04_s
    li \T04_s, 45
    sw \T03l_s, 18*8(a0)
    sw \T03h_s, 18*8+4(a0)
    slli \T02l_s, \S10l_s, 3
    vsrl.vi \S08_v, \S16_v, 19
    srli \S10l_s, \S10l_s, 29
    srli \T02h_s, \S10h_s, 29
    slli \S10h_s, \S10h_s, 3
    vsll.vx \T03_v, \S16_v, \T04_s
    xor  \T02l_s, \T02l_s, \T02h_s
    xor  \T02h_s, \S10h_s, \S10l_s
    lw \T03l_s, 1*8(a0)
    vxor.vv \S01_v, \S01_v, \T02_v
    lw \T03h_s, 1*8+4(a0)
    sw \T02l_s, 13*8(a0)
    sw \T02h_s, 13*8+4(a0)
    vxor.vv \S08_v, \S08_v, \T03_v
    li \T04_s, 58
    slli \S10l_s, \T03l_s, 1
    srli \T03l_s, \T03l_s, 31
    srli \S10h_s, \T03h_s, 31
    vsll.vi \T02_v, \S07_v, 6
    slli \T03h_s, \T03h_s, 1
    xor  \S10l_s, \S10l_s, \S10h_s
    xor  \S10h_s, \T03h_s, \T03l_s
    vsrl.vx \S16_v, \S07_v, \T04_s
    li \T04_s, 61
    lw \T03l_s, 12*8(a0)
    lw \T03h_s, 12*8+4(a0)
    slli \T02l_s, \S02h_s, 30
    vsll.vi \T03_v, \S10_v, 3
    srli \S02h_s, \S02h_s, 2
    srli \T02h_s, \S02l_s, 2
    slli \S02l_s, \S02l_s, 30
    vsrl.vx \S07_v, \S10_v, \T04_s
    xor  \T02l_s, \T02l_s, \T02h_s
    xor  \T02h_s, \S02l_s, \S02h_s
    sw \T02l_s, 1*8(a0)
    sw \T02h_s, 1*8+4(a0)
    vxor.vv \S16_v, \S16_v, \T02_v
    lw \T02l_s, 9*8(a0)
    lw \T02h_s, 9*8+4(a0)
    slli \S02l_s, \T03h_s, 11
    vxor.vv \S07_v, \S07_v, \T03_v
    li \T04_s, 36
    srli \T03h_s, \T03h_s, 21
    srli \S02h_s, \T03l_s, 21
    slli \T03l_s, \T03l_s, 11
    vsll.vi \T02_v, \S03_v, 28
    xor  \S02l_s, \S02l_s, \S02h_s
    xor  \S02h_s, \T03l_s, \T03h_s
    slli \T03l_s, \T02l_s, 20
    vsrl.vx \S10_v, \S03_v, \T04_s
    li \T04_s, 43
    srli \T02l_s, \T02l_s, 12
    srli \T03h_s, \T02h_s, 12
    slli \T02h_s, \T02h_s, 20
    vsll.vi \T03_v, \S18_v, 21
    xor  \T03l_s, \T03l_s, \T03h_s
    xor  \T03h_s, \T02h_s, \T02l_s
    lw \T02l_s, 22*8(a0)
    vsrl.vx \S03_v, \S18_v, \T04_s
    lw \T02h_s, 22*8+4(a0)
    sw \T03l_s, 12*8(a0)
    sw \T03h_s, 12*8+4(a0)
    vxor.vv \S10_v, \S10_v, \T02_v
    slli \T03h_s,  \T02l_s, 29
    srli \T02l_s, \T02l_s, 3
    slli \T03l_s,  \T02h_s, 29
    vxor.vv \S03_v, \S03_v, \T03_v
    li \T04_s, 49
    srli \T02h_s, \T02h_s, 3
    xor  \T02l_s, \T02l_s, \T03l_s
    xor  \T02h_s, \T02h_s, \T03h_s
    vsll.vi \T02_v, \S17_v, 15
    sw \T02l_s, 9*8(a0)
    sw \T02h_s, 9*8+4(a0)
    slli \T03l_s, \S14h_s, 7
    vsrl.vx \S18_v, \S17_v, \T04_s
    li \T04_s, 54
    srli \S14h_s, \S14h_s, 25
    srli \T03h_s, \S14l_s, 25
    slli \S14l_s, \S14l_s, 7
    xor  \T03l_s, \T03l_s, \T03h_s
    vsll.vi \T03_v, \S11_v, 10
    xor  \T03h_s, \S14l_s, \S14h_s
    lw \T02l_s, 20*8(a0)
    lw \T02h_s, 20*8+4(a0)
    vsrl.vx \S17_v, \S11_v, \T04_s
    sw \T03l_s, 22*8(a0)
    sw \T03h_s, 22*8+4(a0)
    slli \S14l_s, \T02l_s, 18
    vxor.vv \S18_v, \S18_v, \T02_v
    srli \T02l_s, \T02l_s, 14
    srli \S14h_s, \T02h_s, 14
    slli \T02h_s, \T02h_s, 18
    vxor.vv \S17_v, \S17_v, \T03_v
    li \T04_s, 44
    xor  \S14l_s, \S14l_s, \S14h_s
    xor  \S14h_s, \T02h_s, \T02l_s
    lw \T03l_s, 15*8(a0)
    vsll.vi \T02_v, \S09_v, 20
    lw \T03h_s, 15*8+4(a0)
    slli \T02l_s, \S23h_s, 24
    srli \S23h_s, \S23h_s, 8
    vsrl.vx \S11_v, \S09_v, \T04_s
    li \T04_s, 61
    srli \T02h_s, \S23l_s, 8
    slli \S23l_s, \S23l_s, 24
    xor  \T02l_s, \T02l_s, \T02h_s
    vsrl.vi \S09_v, \S22_v, 3
    xor  \T02h_s, \S23l_s, \S23h_s
    slli \S23l_s, \T03h_s, 9
    srli \T03h_s, \T03h_s, 23
    vsll.vx \T03_v, \S22_v, \T04_s
    srli \S23h_s, \T03l_s, 23
    slli \T03l_s, \T03l_s, 9
    xor  \S23l_s, \S23l_s, \S23h_s
    vxor.vv \S11_v, \S11_v, \T02_v
    xor  \S23h_s, \T03l_s, \T03h_s
    sw \T02l_s, 20*8(a0)
    sw \T02h_s, 20*8+4(a0)
    vxor.vv \S09_v, \S09_v, \T03_v
    li \T04_s, 39
    slli \T02l_s, \S04l_s, 27
    srli \S04l_s, \S04l_s, 5
    srli \T02h_s, \S04h_s, 5
    slli \S04h_s, \S04h_s, 27
    vsrl.vi \S22_v, \S14_v, 25
    xor  \T02l_s, \T02l_s, \T02h_s
    xor  \T02h_s, \S04h_s, \S04l_s
    lw \T03l_s, 24*8(a0)
    vsll.vx \T02_v, \S14_v, \T04_s
    li \T04_s, 46
    lw \T03h_s, 24*8+4(a0)
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    vsll.vi \T03_v, \S20_v, 18
    slli \S04l_s, \T03l_s, 14
    srli \T03l_s, \T03l_s, 18
    srli \S04h_s, \T03h_s, 18
    vsrl.vx \S14_v, \S20_v, \T04_s
    slli \T03h_s, \T03h_s, 14
    xor  \S04l_s, \S04l_s, \S04h_s
    xor  \S04h_s, \T03h_s, \T03l_s
    vxor.vv \S22_v, \S22_v, \T02_v
    slli \T02l_s, \S17l_s, 15
    srli \S17l_s, \S17l_s, 17
    srli \T02h_s, \S17h_s, 17
    vxor.vv \S14_v, \S14_v, \T03_v
    li \T04_s, 37
    slli \S17h_s, \S17h_s, 15
    xor  \T02l_s, \T02l_s, \T02h_s
    xor  \T02h_s, \S17h_s, \S17l_s
    vsll.vi \T02_v, \S04_v, 27
    lw \T03l_s, 11*8(a0)
    lw \T03h_s, 11*8+4(a0)
    sw \T02l_s, 24*8(a0)
    vsrl.vx \S20_v, \S04_v, \T04_s
    li \T04_s, 50
    sw \T02h_s, 24*8+4(a0)
    lw \T02h_s, 7*8(a0)
    lw \T02l_s, 7*8+4(a0)
    vsll.vi \T03_v, \S24_v, 14
    slli \S17l_s, \T03l_s, 10
    srli \T03l_s, \T03l_s, 22
    srli \S17h_s, \T03h_s, 22
    vsrl.vx \S04_v, \S24_v, \T04_s
    slli \T03h_s, \T03h_s, 10
    xor  \S17l_s, \S17l_s, \S17h_s
    xor  \S17h_s, \T03h_s, \T03l_s
    srli \T03h_s,   \T02h_s, 26
    vxor.vv \S20_v, \S20_v, \T02_v
    slli \T02h_s, \T02h_s, 6
    srli \T03l_s,   \T02l_s, 26
    slli \T02l_s, \T02l_s, 6
    vxor.vv \S04_v, \S04_v, \T03_v
    li \T04_s, 62
    xor  \T02h_s, \T02h_s, \T03l_s
    xor  \T02l_s, \T02l_s, \T03h_s
    lw \T03l_s, 19*8(a0)
    vsll.vi \T02_v, \S21_v, 2
    lw \T03h_s, 19*8+4(a0)
    sw \T02h_s, 11*8(a0)
    sw \T02l_s, 11*8+4(a0)
    vsrl.vx \S24_v, \S21_v, \T04_s
    li \T04_s, 36
    sw \T00l_s, 18*4(sp)
    sw \T00h_s, 19*4(sp)
    srli \T02h_s,   \T03l_s, 24
    vsrl.vi \S21_v, \S05_v, 28
    slli \T03l_s, \T03l_s, 8
    srli \T02l_s,   \T03h_s, 24
    slli \T03h_s, \T03h_s, 8
    vsll.vx \T03_v, \S05_v, \T04_s
    xor  \T03l_s, \T03l_s, \T02l_s
    xor  \T03h_s, \T03h_s, \T02h_s
    lw \T00l_s, 12*8(a0)
    vxor.vv \S24_v, \S24_v, \T02_v
    lw \T00h_s, 12*8+4(a0)
    sw \T01l_s, 20*4(sp)
    sw \T01h_s, 21*4(sp)
    vxor.vv \S21_v, \S21_v, \T03_v
    lw \T01l_s, 13*8(a0)
    lw \T01h_s, 13*8+4(a0)
    sw \T03l_s, 19*8(a0)
    vor.vv \T02_v, \S11_v, \S07_v
    sw \T03h_s, 19*8+4(a0)
    and \T03l_s, \T01l_s, \S08l_s
    and \T03h_s, \T01h_s, \S08h_s
    vand.vv \T03_v, \S07_v, \S08_v
    xor \T03l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T00h_s, \T03h_s
    lw \T02l_s, 9*8(a0)
    lw \T02h_s, 9*8+4(a0)
    vnot.v \T04_v, \S09_v
    sw \T03l_s, 6*8(a0)
    sw \T03h_s, 6*8+4(a0)
    not \T03l_s, \T02l_s
    vor.vv \T05_v, \S09_v, \S10_v
    not \T03h_s, \T02h_s
    or \T03l_s, \T03l_s, \S08l_s
    or \T03h_s, \T03h_s, \S08h_s
    vxor.vv \S05_v, \S10_v, \T02_v
    xor \T03l_s, \T01l_s, \T03l_s
    xor \T03h_s, \T01h_s, \T03h_s
    sw \T03l_s, 7*8(a0)
    vor.vv \T04_v, \T04_v, \S08_v
    sw \T03h_s, 7*8+4(a0)
    or \T03l_s, \T02l_s, \S05l_s
    or \T03h_s, \T02h_s, \S05h_s
    vxor.vv \S06_v, \S11_v, \T03_v
    xor \S08l_s, \S08l_s, \T03l_s
    xor \S08h_s, \S08h_s, \T03h_s
    and \T03l_s, \S05l_s, \T00l_s
    vxor.vv \S07_v, \S07_v, \T04_v
    and \T03h_s, \S05h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T03l_s
    xor \T02h_s, \T02h_s, \T03h_s
    vxor.vv \S08_v, \S08_v, \T05_v
    or  \T03l_s, \T00l_s, \T01l_s
    or  \T03h_s, \T00h_s, \T01h_s
    lw \T01l_s, 19*8(a0)
    vand.vv \T02_v, \S10_v, \S11_v
    lw \T01h_s, 19*8+4(a0)
    sw \T02l_s, 9*8(a0)
    sw \T02h_s, 9*8+4(a0)
    vor.vv \T03_v, \S16_v, \S12_v
    lw \T00l_s, 18*8(a0)
    lw \T00h_s, 18*8+4(a0)
    xor \S05h_s, \S05h_s, \T03h_s
    vnot.v \T05_v, \S13_v
    xor \S05l_s, \S05l_s, \T03l_s
    not \T03l_s, \T01l_s
    not \T03h_s, \T01h_s
    and \T03l_s, \T03l_s, \S14l_s
    vand.vv \T04_v, \S12_v, \S13_v
    and \T03h_s, \T03h_s, \S14h_s
    xor \T03l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T00h_s, \T03h_s
    vxor.vv \S09_v, \S09_v, \T02_v
    lw \T02l_s, 11*8(a0)
    lw \T02h_s, 11*8+4(a0)
    sw \T03l_s, 12*8(a0)
    vand.vv \T05_v, \T05_v, \S14_v
    sw \T03h_s, 12*8+4(a0)
    not \T04_s, \T01h_s
    or  \T03h_s, \S14h_s, \S10h_s
    vxor.vv \S10_v, \S15_v, \T03_v
    or  \T03l_s, \S14l_s, \S10l_s
    xor \T03h_s, \T03h_s, \T04_s
    not \T04_s, \T01l_s
    vxor.vv \S11_v, \S16_v, \T04_v
    xor \T03l_s, \T03l_s, \T04_s
    sw \T03l_s, 13*8(a0)
    sw \T03h_s, 13*8+4(a0)
    vxor.vv \S12_v, \S12_v, \T05_v
    and \T03l_s, \S10l_s, \T02l_s
    and \T03h_s, \S10h_s, \T02h_s
    xor \S14l_s, \S14l_s, \T03l_s
    vnot.v \T03_v, \S13_v
    xor \S14h_s, \S14h_s, \T03h_s
    or \T03l_s, \T02l_s, \T00l_s
    or \T03h_s, \T02h_s, \T00h_s
    vand.vv \T04_v, \S15_v, \S16_v
    xor \S10l_s, \S10l_s, \T03l_s
    xor \S10h_s, \S10h_s, \T03h_s
    and \T03l_s, \T00l_s, \T01l_s
    vand.vv \T05_v, \S21_v, \S17_v
    and \T03h_s, \T00h_s, \T01h_s
    xor \T02l_s, \T02l_s, \T03l_s
    xor \T02h_s, \T02h_s, \T03h_s
    vor.vv \T02_v, \S14_v, \S15_v
    lw \T00h_s, 24*8+4(a0)
    lw \T01h_s, 20*8+4(a0)
    sw \T02h_s, 11*8+4(a0)
    sw \T02l_s, 11*8(a0)
    vxor.vv \S14_v, \S14_v, \T04_v
    lw \T02h_s, 15*8+4(a0)
    lw \T01l_s, 20*8(a0)
    lw \T02l_s, 15*8(a0)
    vxor.vv \S15_v, \S20_v, \T05_v
    lw \T00l_s, 24*8(a0)
    not \T04_s, \T00h_s
    and \T03h_s, \T01h_s, \T02h_s
    vxor.vv \S13_v, \T03_v, \T02_v
    and \T03l_s, \T01l_s, \T02l_s
    xor \T03h_s, \T03h_s, \T04_s
    not \T04_s, \T00l_s
    vnot.v \T03_v, \S18_v
    xor \T03l_s, \T03l_s, \T04_s
    sw \T03l_s, 18*8(a0)
    sw \T03h_s, 18*8+4(a0)
    vnot.v \T05_v, \S18_v
    or \T03l_s, \T02l_s, \S16l_s
    or \T03h_s, \T02h_s, \S16h_s
    xor \T03l_s, \T01l_s, \T03l_s
    vor.vv \T02_v, \S17_v, \S18_v
    xor \T03h_s, \T01h_s, \T03h_s
    sw \T03l_s, 19*8(a0)
    sw \T03h_s, 19*8+4(a0)
    vor.vv \T03_v, \T03_v, \S19_v
    and \T03l_s, \S16l_s, \S17l_s
    and \T03h_s, \S16h_s, \S17h_s
    xor \T02l_s, \T02l_s, \T03l_s
    vand.vv \T04_v, \S19_v, \S20_v
    xor \T02h_s, \T02h_s, \T03h_s
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    vxor.vv \S16_v, \S21_v, \T02_v
    or \T03l_s, \S17l_s, \T00l_s
    or \T03h_s, \S17h_s, \T00h_s
    xor \S16l_s, \S16l_s, \T03l_s
    vxor.vv \S17_v, \S17_v, \T03_v
    xor \S16h_s, \S16h_s, \T03h_s
    lw \T02l_s, 22*8(a0)
    lw \T02h_s, 22*8+4(a0)
    not \T03l_s, \T00l_s
    vxor.vv \S18_v, \T05_v, \T04_v
    not \T03h_s, \T00h_s
    lw \T00l_s, 0*8(a0)
    lw \T00h_s, 0*8+4(a0)
    vnot.v \T03_v, \S01_v
    or  \T03l_s, \T03l_s, \T01l_s
    or  \T03h_s, \T03h_s, \T01h_s
    lw \T01l_s, 1*8(a0)
    vnot.v \T05_v, \S01_v
    lw \T01h_s, 1*8+4(a0)
    xor \S17l_s, \S17l_s, \T03l_s
    xor \S17h_s, \S17h_s, \T03h_s
    vor.vv \T02_v, \S20_v, \S21_v
    and \T03l_s, \T01l_s, \S21l_s
    and \T03h_s, \T01h_s, \S21h_s
    xor \T03l_s, \T00l_s, \T03l_s
    vand.vv \T03_v, \T03_v, \S22_v
    xor \T03h_s, \T00h_s, \T03h_s
    sw \T03l_s, 24*8(a0)
    sw \T03h_s, 24*8+4(a0)
    vor.vv \T04_v, \S22_v, \S23_v
    not \T03l_s, \S21l_s
    not \T03h_s, \S21h_s
    and \T03l_s, \T03l_s, \T02l_s
    vxor.vv \S19_v, \S19_v, \T02_v
    and \T03h_s, \T03h_s, \T02h_s
    xor \T03l_s, \T01l_s, \T03l_s
    xor \T03h_s, \T01h_s, \T03h_s
    vxor.vv \S20_v, \S00_v, \T03_v
    sw \T03l_s, 20*8(a0)
    sw \T03h_s, 20*8+4(a0)
    not \T04_s, \S21h_s
    vxor.vv \S21_v, \T05_v, \T04_v
    or  \T03h_s, \T02h_s, \S23h_s
    or  \T03l_s, \T02l_s, \S23l_s
    xor \S21h_s, \T03h_s, \T04_s
    vand.vv \T02_v, \S23_v, \S24_v
    not \T04_s, \S21l_s
    xor \S21l_s, \T03l_s, \T04_s
    and \T03l_s, \S23l_s, \T00l_s
    and \T03h_s, \S23h_s, \T00h_s
    vor.vv \T03_v, \S24_v, \S00_v
    xor \T02l_s, \T02l_s, \T03l_s
    xor \T02h_s, \T02h_s, \T03h_s
    lw \T04_s, 17*4(sp)
    vand.vv \T04_v, \S00_v, \S01_v
    or  \T03l_s, \T00l_s, \T01l_s
    or  \T03h_s, \T00h_s, \T01h_s
    lw \T00l_s, 18*4(sp)
    vor.vv \T05_v, \T01_v, \S02_v
    lw \T00h_s, 19*4(sp)
    sw \T02l_s, 22*8(a0)
    sw \T02h_s, 22*8+4(a0)
    vxor.vv \S22_v, \S22_v, \T02_v
    lw \T01l_s, 20*4(sp)
    lw \T01h_s, 21*4(sp)
    xor \S23h_s, \S23h_s, \T03h_s
    vxor.vv \S23_v, \S23_v, \T03_v
    xor \S23l_s, \S23l_s, \T03l_s
    lw \T02l_s, 0(\T04_s)
    lw \T02h_s, 4(\T04_s)
    vxor.vv \S24_v, \S24_v, \T04_v
    or \T03l_s, \T01l_s, \S02l_s
    or \T03h_s, \T01h_s, \S02h_s
    vxor.vv \S00_v, \T00_v, \T05_v
    xor \T03l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T00h_s, \T03h_s
    vnot.v \T02_v, \S02_v
    xor \T03l_s, \T03l_s, \T02l_s
    xor \T03h_s, \T03h_s, \T02h_s
    lw \T02l_s, 3*8(a0)
    vor.vv \T04_v, \S04_v, \T00_v
    lw \T02h_s, 3*8+4(a0)
    sw \T03l_s, 0*8(a0)
    sw \T03h_s, 0*8+4(a0)
    vand.vv \T03_v, \S03_v, \S04_v
    not \T03l_s, \S02l_s
    not \T03h_s, \S02h_s
    or \T03l_s, \T03l_s, \T02l_s
    or \T03h_s, \T03h_s, \T02h_s
    vand.vv \T05_v, \T00_v, \T01_v
    xor \T03l_s, \T01l_s, \T03l_s
    xor \T03h_s, \T01h_s, \T03h_s
    sw \T03l_s, 1*8(a0)
    vor.vv \T02_v, \T02_v, \S03_v
    sw \T03h_s, 1*8+4(a0)
    and \T03l_s, \T02l_s, \S04l_s
    and \T03h_s, \T02h_s, \S04h_s
    vxor.vv \S02_v, \S02_v, \T03_v
    vle64.v \T00_v, (\T04_s)
    xor \S02l_s, \S02l_s, \T03l_s
    xor \S02h_s, \S02h_s, \T03h_s
    or \T03l_s, \S04l_s, \T00l_s
    vxor.vv \S03_v, \S03_v, \T04_v
    or \T03h_s, \S04h_s, \T00h_s
    xor \T03l_s, \T02l_s, \T03l_s
    xor \T03h_s, \T02h_s, \T03h_s
    vxor.vv \S01_v, \T01_v, \T02_v
    addi \T04_s, \T04_s, 16
    sw \T03l_s, 3*8(a0)
    sw \T03h_s, 3*8+4(a0)
    and \T03l_s, \T00l_s, \T01l_s
    vxor.vv \S04_v, \S04_v, \T05_v
    sw  \T04_s, 17*4(sp)
    and \T03h_s, \T00h_s, \T01h_s
    xor \S04l_s, \S04l_s, \T03l_s
    xor \S04h_s, \S04h_s, \T03h_s
    vxor.vv \S00_v, \S00_v, \T00_v
.endm

# stack: 
# 0*4-14*4 for saving registers
# 15*4 for saving a0
# 16*4 for loop control
# 17*4 for table index
# 18*4,19*4 for C0
# 20*4,21*4 for C1
# 22*4,23*4 for C2
# 24*4,25*4 for C3
# 26*4,27*4 for C4
.globl KeccakF1600_StatePermute_RV32V_3x
.align 2
KeccakF1600_StatePermute_RV32V_3x:
    addi sp, sp, -4*28
    SaveRegs

    li a1, 128
vsetivli a2, 2, e64, m1, tu, mu

    la tp, constants_keccak
    sw tp, 17*4(sp)

    LoadStates_v
    LoadStates_s \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp

    li tp, 24

loop_start:
    sw tp, 16*4(sp)
    ARound \
        v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,  v8,  v9,    \
        v10, v11, v12, v13, v14, v15, v16, v17, v18, v19,   \
        v20, v21, v22, v23, v24, v25, v26, v27, v28, v29,   \
        v30, v31, \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp
    
    lw tp, 16*4(sp)
    addi tp, tp, -1
    bnez tp, loop_start

    addi a0, a0, -25*16
    StoreStates_v
    StoreStates_s \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp

    RestoreRegs
    addi sp, sp, 4*28
    ret

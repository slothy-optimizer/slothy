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

.macro XOR1Init outh, outl, in0h, in0l, in1h, in1l
    xor \outl, \in0l, \in1l
    xor \outh, \in0h, \in1h
.endm

.macro XOR1 outh, outl, inh, inl
    xor \outl, \outl, \inl
    xor \outh, \outh, \inh
.endm

.macro XOREach                 \
        S00h, S00l, S01h, S01l,\
        S02h, S02l, S03h, S03l,\
        S04h, S04l, Dh,   Dl
    XOR1 \S00h, \S00l, \Dh, \Dl
    XOR1 \S01h, \S01l, \Dh, \Dl
    XOR1 \S02h, \S02l, \Dh, \Dl
    XOR1 \S03h, \S03l, \Dh, \Dl
    XOR1 \S04h, \S04l, \Dh, \Dl
.endm

.macro ROLn outh, outl, S00h, S00l, n
.if \n < 32
    slli \outl, \S00l, \n
    srli \S00l, \S00l, 32-\n
    srli \outh, \S00h, 32-\n
    slli \S00h, \S00h, \n
    xor  \outl, \outl, \outh
    xor  \outh, \S00h, \S00l
.else
    slli \outl, \S00h, \n-32
    srli \S00h, \S00h, 64-\n
    srli \outh, \S00l, 64-\n
    slli \S00l, \S00l, \n-32
    xor  \outl, \outl, \outh
    xor  \outh, \S00l, \S00h
.endif
.endm

.macro ROLnInplace S00h, S00l, T0, T1, n
.if \n < 32
    srli \T0,   \S00l, 32-\n
    slli \S00l, \S00l, \n
    srli \T1,   \S00h, 32-\n
    slli \S00h, \S00h, \n
    xor  \S00l, \S00l, \T1
    xor  \S00h, \S00h, \T0
.else
    slli \T0,  \S00l, \n-32
    srli \S00l,\S00l, 64-\n
    slli \T1,  \S00h, \n-32
    srli \S00h,\S00h, 64-\n
    xor  \S00l,\S00l, \T1
    xor  \S00h,\S00h, \T0
.endif
.endm

.macro xoror outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl
    or \Tl, \S01l, \S02l
    or \Th, \S01h, \S02h
    xor \outl, \S00l, \Tl
    xor \outh, \S00h, \Th
.endm

.macro xornotor outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl
    not \Tl, \S01l
    not \Th, \S01h
    or \Tl, \Tl, \S02l
    or \Th, \Th, \S02h
    xor \outl, \S00l, \Tl
    xor \outh, \S00h, \Th
.endm

.macro xorand outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl
    and \Tl, \S01l, \S02l
    and \Th, \S01h, \S02h
    xor \outl, \S00l, \Tl
    xor \outh, \S00h, \Th
.endm

.macro xorornot outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl
    not \Tl, \S02l
    not \Th, \S02h
    or \Tl, \Tl, \S01l
    or \Th, \Th, \S01h
    xor \outl, \S00l, \Tl
    xor \outh, \S00h, \Th
.endm

.macro xornotand outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl
    not \Tl, \S01l
    not \Th, \S01h
    and \Tl, \Tl, \S02l
    and \Th, \Th, \S02h
    xor \outl, \S00l, \Tl
    xor \outh, \S00h, \Th
.endm

.macro notxoror outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl, T0
    not \T0, \S00h
    or  \Th, \S01h, \S02h
    or  \Tl, \S01l, \S02l
    xor \outh, \Th, \T0
    not \T0, \S00l
    xor \outl, \Tl, \T0
.endm

.macro notxorand outh, outl, S00h, S00l, S01h, S01l, S02h, S02l, Th, Tl, T0
    not \T0, \S00h
    and \Th, \S01h, \S02h
    and \Tl, \S01l, \S02l
    xor \outh, \Th, \T0
    not \T0, \S00l
    xor \outl, \Tl, \T0
.endm

.macro InitLoad \
        S02h, S02l, S04h, S04l, S05h, S05l, S08h, S08l, S10h, S10l, \
        S14h, S14l, S16h, S16l, S17h, S17l, S21h, S21l, S23h, S23l, \
        T00h, T00l, T01h, T01l, T02h, T02l, T03h, T03l, T04
    # lane complement: 1,2,8,12,17,20
    lw \T00l, 1*8(a0)
    lw \T00h, 1*8+4(a0)
    lw \T01l, 12*8(a0)
    lw \T01h, 12*8+4(a0)
    lw \S02l, 2*8(a0)
    lw \S02h, 2*8+4(a0)
    lw \S04l, 4*8(a0)
    lw \S04h, 4*8+4(a0)
    lw \S05l, 5*8(a0)
    lw \S05h, 5*8+4(a0)
    not \T00l, \T00l
    not \T00h, \T00h
    not \T01l, \T01l
    not \T01h, \T01h
    sw \T00l, 1*8(a0)
    sw \T00h, 1*8+4(a0)
    lw \S08l, 8*8(a0)
    lw \S08h, 8*8+4(a0)
    sw \T01l, 12*8(a0)
    sw \T01h, 12*8+4(a0)
    lw \S10l, 10*8(a0)
    lw \S10h, 10*8+4(a0)
    lw \T00l, 20*8(a0)
    lw \T00h, 20*8+4(a0)
    not \S02l, \S02l
    not \S02h, \S02h
    not \S08l, \S08l
    not \S08h, \S08h
    lw \S14l, 14*8(a0)
    lw \S14h, 14*8+4(a0)
    lw \S16l, 16*8(a0)
    lw \S16h, 16*8+4(a0)
    lw \S17l, 17*8(a0)
    lw \S17h, 17*8+4(a0)
    not \T00l, \T00l
    not \T00h, \T00h
    lw \S21l, 21*8(a0)
    lw \S21h, 21*8+4(a0)
    sw \T00l, 20*8(a0)
    sw \T00h, 20*8+4(a0)
    not \S17l, \S17l
    not \S17h, \S17h
    lw \S23l, 23*8(a0)
    lw \S23h, 23*8+4(a0)
.endm

.macro FinalStore \
        S02h, S02l, S04h, S04l, S05h, S05l, S08h, S08l, S10h, S10l, \
        S14h, S14l, S16h, S16l, S17h, S17l, S21h, S21l, S23h, S23l, \
        T00h, T00l, T01h, T01l, T02h, T02l, T03h, T03l, T04
    # lane complement: 1,2,8,12,17,20
    lw \T00l, 1*8(a0)
    lw \T00h, 1*8+4(a0)
    lw \T01l, 12*8(a0)
    lw \T01h, 12*8+4(a0)
    not \S02l, \S02l
    not \S02h, \S02h
    not \S08l, \S08l
    not \S08h, \S08h
    sw \S02l, 2*8(a0)
    sw \S02h, 2*8+4(a0)
    sw \S04l, 4*8(a0)
    sw \S04h, 4*8+4(a0)
    not \T00l, \T00l
    not \T00h, \T00h
    not \T01l, \T01l
    not \T01h, \T01h
    sw \T00l, 1*8(a0)
    sw \T00h, 1*8+4(a0)
    sw \T01l, 12*8(a0)
    sw \T01h, 12*8+4(a0)
    lw \T00l, 20*8(a0)
    lw \T00h, 20*8+4(a0)
    not \S17l, \S17l
    not \S17h, \S17h
    sw \S05l, 5*8(a0)
    sw \S05h, 5*8+4(a0)
    sw \S08l, 8*8(a0)
    sw \S08h, 8*8+4(a0)
    sw \S10l, 10*8(a0)
    sw \S10h, 10*8+4(a0)
    not \T00l, \T00l
    not \T00h, \T00h
    sw \S14l, 14*8(a0)
    sw \S14h, 14*8+4(a0)
    sw \T00l, 20*8(a0)
    sw \T00h, 20*8+4(a0)
    sw \S16l, 16*8(a0)
    sw \S16h, 16*8+4(a0)
    sw \S17l, 17*8(a0)
    sw \S17h, 17*8+4(a0)
    sw \S21l, 21*8(a0)
    sw \S21h, 21*8+4(a0)
    sw \S23l, 23*8(a0)
    sw \S23h, 23*8+4(a0)
.endm

.macro ARound \
        S02h, S02l, S04h, S04l, S05h, S05l, S08h, S08l, S10h, S10l, \
        S14h, S14l, S16h, S16l, S17h, S17l, S21h, S21l, S23h, S23l, \
        T00h, T00l, T01h, T01l, T02h, T02l, T03h, T03l, T04
    # C0=S00+S05+S10+S15+S20
    lw \T03l, 0*8(a0)
    lw \T03h, 0*8+4(a0)
    XOR1Init \T00h, \T00l, \S05h, \S05l, \S10h, \S10l
    lw \T02l, 15*8(a0)
    lw \T02h, 15*8+4(a0)
    XOR1 \T00h, \T00l, \T03h, \T03l
    lw \T03l, 20*8(a0)
    lw \T03h, 20*8+4(a0)
    XOR1 \T00h, \T00l, \T02h, \T02l
    XOR1 \T00h, \T00l, \T03h, \T03l
    lw \T03l, 3*8(a0)
    lw \T03h, 3*8+4(a0)
    # save C0
    sw \T00l, 18*4(sp)
    sw \T00h, 19*4(sp)
    # T00=C0
    # C3=S03+S08+S13+S18+S23
    XOR1Init \T01h, \T01l, \S08h, \S08l, \S23h, \S23l
    lw \T02l, 13*8(a0)
    lw \T02h, 13*8+4(a0)
    XOR1 \T01h, \T01l, \T03h, \T03l
    lw \T03l, 18*8(a0)
    lw \T03h, 18*8+4(a0)
    XOR1 \T01h, \T01l, \T02h, \T02l
    XOR1 \T01h, \T01l, \T03h, \T03l
    # T00=C0, T01=C3
    # D4=C3^ROL(C0,1);
    ROLnInplace \T00h, \T00l, \T03h, \T03l, 1
    # save C3
    sw \T01l, 24*4(sp)
    sw \T01h, 25*4(sp)
    XOR1 \T00h, \T00l, \T01h, \T01l
    # T00=D4
    # C4=S04+S09+S14+S19+S24
    # S04,S09,S14,S19,S24 += D4
    lw \T03l, 9*8(a0)
    lw \T03h, 9*8+4(a0)
    XOR1Init \T01h, \T01l, \S04h, \S04l, \S14h, \S14l
    XOR1 \S04h, \S04l, \T00h, \T00l
    XOR1 \S14h, \S14l, \T00h, \T00l
    lw \T02l, 19*8(a0)
    lw \T02h, 19*8+4(a0)
    XOR1 \T01h, \T01l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T00h, \T00l
    sw \T03l, 9*8(a0)
    sw \T03h, 9*8+4(a0)
    lw \T03l, 24*8(a0)
    lw \T03h, 24*8+4(a0)
    XOR1 \T01h, \T01l, \T02h, \T02l
    XOR1 \T02h, \T02l, \T00h, \T00l
    XOR1 \T01h, \T01l, \T03h, \T03l
    sw \T02l, 19*8(a0)
    sw \T02h, 19*8+4(a0)
    XOR1 \T03h, \T03l, \T00h, \T00l
    sw \T01l, 26*4(sp)
    sw \T01h, 27*4(sp)
    sw \T03l, 24*8(a0)
    sw \T03h, 24*8+4(a0)
    # T01=C4
    lw \T03l, 1*8(a0)
    lw \T03h, 1*8+4(a0)
    # C1=S01+S06+S11+S16+S21
    XOR1Init \T00h, \T00l, \S16h, \S16l, \S21h, \S21l
    lw \T02l, 6*8(a0)
    lw \T02h, 6*8+4(a0)
    XOR1 \T00h, \T00l, \T03h, \T03l
    lw \T03l, 11*8(a0)
    lw \T03h, 11*8+4(a0)
    XOR1 \T00h, \T00l, \T02h, \T02l
    XOR1 \T00h, \T00l, \T03h, \T03l
    # save C1
    sw \T00l, 20*4(sp)
    sw \T00h, 21*4(sp)
    # T01=C4,T00=C1
    # D0=C4^ROL(C1,1)
    ROLnInplace \T00h, \T00l, \T03h, \T03l, 1
    lw \T02l, 0*8(a0)
    lw \T02h, 0*8+4(a0)
    XOR1 \T00h, \T00l, \T01h, \T01l
    # T01=C4,T00=D0
    # S00,S05,S10,S15,S20 += D0
    XOR1 \S05h, \S05l, \T00h, \T00l
    lw \T03l, 20*8(a0)
    lw \T03h, 20*8+4(a0)
    XOR1 \T02h, \T02l, \T00h, \T00l
    sw \T02l, 0*8(a0)
    sw \T02h, 0*8+4(a0)
    lw \T02l, 15*8(a0)
    lw \T02h, 15*8+4(a0)
    XOR1 \S10h, \S10l, \T00h, \T00l
    XOR1 \T02h, \T02l, \T00h, \T00l
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    XOR1 \T03h, \T03l, \T00h, \T00l
    lw \T02l, 24*4(sp)
    lw \T02h, 25*4(sp)
    lw \T00l, 20*4(sp)
    lw \T00h, 21*4(sp)
    sw \T03l, 20*8(a0)
    sw \T03h, 20*8+4(a0)
    # T01=C4
    # D2=C1^ROL(C3,1)
    ROLnInplace \T02h, \T02l, \T03h, \T03l, 1
    lw \T03l, 7*8(a0)
    lw \T03h, 7*8+4(a0)
    XOR1 \T02h, \T02l, \T00h, \T00l
    # T01=C4,T02=D2
    # C2=S02+S07+S12+S17+S22
    # S02,S07,S12,S17,S22 += D2
    XOR1Init \T00h, \T00l, \S02h, \S02l, \S17h, \S17l
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    XOR1 \S02h, \S02l, \T02h, \T02l
    sw \T03l, 7*8(a0)
    sw \T03h, 7*8+4(a0)
    lw \T03l, 12*8(a0)
    lw \T03h, 12*8+4(a0)
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    XOR1 \S17h, \S17l, \T02h, \T02l
    sw \T03l, 12*8(a0)
    sw \T03h, 12*8+4(a0)
    lw \T03l, 22*8(a0)
    lw \T03h, 22*8+4(a0)
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    # save C2
    sw \T00l, 22*4(sp)
    sw \T00h, 23*4(sp)
    sw \T03l, 22*8(a0)
    sw \T03h, 22*8+4(a0)
    # T01=C4,T00=C2
    # D3=C2^ROL(C4,1)
    ROLnInplace \T01h, \T01l, \T03h, \T03l, 1
    lw \T03l, 3*8(a0)
    lw \T03h, 3*8+4(a0)
    XOR1 \T01h, \T01l, \T00h, \T00l
    # T01=D3
    # S03,S08,S13,S18,S23 += D3
    XOR1 \S08h, \S08l, \T01h, \T01l
    XOR1 \T03h, \T03l, \T01h, \T01l
    lw \T02l, 13*8(a0)
    lw \T02h, 13*8+4(a0)
    sw \T03l, 3*8(a0)
    sw \T03h, 3*8+4(a0)
    lw \T03l, 18*8(a0)
    lw \T03h, 18*8+4(a0)
    XOR1 \T02h, \T02l, \T01h, \T01l
    XOR1 \S23h, \S23l, \T01h, \T01l
    sw \T02l, 13*8(a0)
    sw \T02h, 13*8+4(a0)
    XOR1 \T03h, \T03l, \T01h, \T01l
    lw \T01l, 18*4(sp)
    lw \T01h, 19*4(sp)
    sw \T03l, 18*8(a0)
    sw \T03h, 18*8+4(a0)
    # T00=C2
    # D1=C0^ROL(C2,1)
    ROLnInplace \T00h, \T00l, \T03h, \T03l, 1
    lw \T02l, 1*8(a0)
    lw \T02h, 1*8+4(a0)
    XOR1 \T00h, \T00l, \T01h, \T01l
    # T00=D1
    # S01,S06,S11,S16,S21 += D1
    lw \T03l, 6*8(a0)
    lw \T03h, 6*8+4(a0)
    XOR1 \S16h, \S16l, \T00h, \T00l
    XOR1 \S21h, \S21l, \T00h, \T00l
    XOR1 \T02h, \T02l, \T00h, \T00l
    sw \T02l, 1*8(a0)
    sw \T02h, 1*8+4(a0)
    XOR1 \T03h, \T03l, \T00h, \T00l
    lw \T02l, 11*8(a0)
    lw \T02h, 11*8+4(a0)
    sw \T03l, 6*8(a0)
    sw \T03h, 6*8+4(a0)
    XOR1 \T02h, \T02l, \T00h, \T00l
    mv \T01l, \T03l
    mv \T01h, \T03h
    sw \T02l, 11*8(a0)
    sw \T02h, 11*8+4(a0)
    ROLn \T03h, \T03l, \S21h, \S21l, 2
    ROLnInplace \T01h, \T01l, \T02h, \T02l, 44
    lw \T00l, 0*8(a0)
    lw \T00h, 0*8+4(a0)
    ROLn \S21h, \S21l, \S08h, \S08l, 55
    sw \T03l, 0*8(a0)
    sw \T03h, 0*8+4(a0)
    ROLn \S08h, \S08l, \S16h, \S16l, 45
    lw \T02l, 3*8(a0)
    lw \T02h, 3*8+4(a0)
    ROLn \S16h, \S16l, \S05h, \S05l, 36
    lw \T03l, 18*8(a0)
    lw \T03h, 18*8+4(a0)
    ROLn \S05h, \S05l, \T02h, \T02l, 28
    ROLn \T02h, \T02l, \T03h, \T03l, 21
    lw \T03l, 13*8(a0)
    lw \T03h, 13*8+4(a0)
    sw \T02l, 3*8(a0)
    sw \T02h, 3*8+4(a0)
    ROLnInplace \T03h, \T03l, \T04, \T02l, 25
    sw \T03l, 18*8(a0)
    sw \T03h, 18*8+4(a0)
    ROLn \T02h, \T02l, \S10h, \S10l, 3
    lw \T03l, 1*8(a0)
    lw \T03h, 1*8+4(a0)
    sw \T02l, 13*8(a0)
    sw \T02h, 13*8+4(a0)
    ROLn \S10h, \S10l, \T03h, \T03l, 1
    lw \T03l, 12*8(a0)
    lw \T03h, 12*8+4(a0)
    ROLn \T02h, \T02l, \S02h, \S02l, 62
    sw \T02l, 1*8(a0)
    sw \T02h, 1*8+4(a0)
    lw \T02l, 9*8(a0)
    lw \T02h, 9*8+4(a0)
    ROLn \S02h, \S02l, \T03h, \T03l, 43
    ROLn \T03h, \T03l, \T02h, \T02l, 20
    lw \T02l, 22*8(a0)
    lw \T02h, 22*8+4(a0)
    sw \T03l, 12*8(a0)
    sw \T03h, 12*8+4(a0)
    ROLnInplace \T02h, \T02l, \T04, \T03l, 61
    sw \T02l, 9*8(a0)
    sw \T02h, 9*8+4(a0)
    ROLn \T03h, \T03l, \S14h, \S14l, 39
    lw \T02l, 20*8(a0)
    lw \T02h, 20*8+4(a0)
    sw \T03l, 22*8(a0)
    sw \T03h, 22*8+4(a0)
    ROLn \S14h, \S14l, \T02h, \T02l, 18
    lw \T03l, 15*8(a0)
    lw \T03h, 15*8+4(a0)
    ROLn \T02h, \T02l, \S23h, \S23l, 56
    ROLn \S23h, \S23l, \T03h, \T03l, 41
    sw \T02l, 20*8(a0)
    sw \T02h, 20*8+4(a0)
    ROLn \T02h, \T02l, \S04h, \S04l, 27
    lw \T03l, 24*8(a0)
    lw \T03h, 24*8+4(a0)
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    ROLn \S04h, \S04l, \T03h, \T03l, 14
    ROLn \T02h, \T02l, \S17h, \S17l, 15
    lw \T03l, 11*8(a0)
    lw \T03h, 11*8+4(a0)
    sw \T02l, 24*8(a0)
    sw \T02h, 24*8+4(a0)
    lw \T04, 7*8(a0)
    lw \T02l, 7*8+4(a0)
    ROLn \S17h, \S17l, \T03h, \T03l, 10
    ROLnInplace \T02l, \T04, \T03h, \T03l, 6
    lw \T03l, 19*8(a0)
    lw \T03h, 19*8+4(a0)
    sw \T04, 11*8(a0)
    sw \T02l, 11*8+4(a0)
    sw \T00l, 18*4(sp)
    sw \T00h, 19*4(sp)
    ROLnInplace \T03h, \T03l, \T02h, \T04, 8
    lw \T00l, 12*8(a0)
    lw \T00h, 12*8+4(a0)
    sw \T01l, 20*4(sp)
    sw \T01h, 21*4(sp)
    lw \T01l, 13*8(a0)
    lw \T01h, 13*8+4(a0)
    sw \T03l, 19*8(a0)
    sw \T03h, 19*8+4(a0)
    xorand \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S08h, \S08l, \T03h, \T03l
    lw \T02l, 9*8(a0)
    lw \T02h, 9*8+4(a0)
    sw \T03l, 6*8(a0)
    sw \T03h, 6*8+4(a0)
    xorornot \T03h, \T03l, \T01h, \T01l, \S08h, \S08l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 7*8(a0)
    sw \T03h, 7*8+4(a0)
    xoror \S08h, \S08l, \S08h, \S08l, \T02h, \T02l, \S05h, \S05l, \T03h, \T03l
    xorand \T02h, \T02l, \T02h, \T02l, \S05h, \S05l, \T00h, \T00l, \T03h, \T03l
    or  \T03l, \T00l, \T01l
    or  \T03h, \T00h, \T01h
    lw \T01l, 19*8(a0)
    lw \T01h, 19*8+4(a0)
    sw \T02l, 9*8(a0)
    sw \T02h, 9*8+4(a0)
    lw \T00l, 18*8(a0)
    lw \T00h, 18*8+4(a0)
    xor \S05h, \S05h, \T03h
    xor \S05l, \S05l, \T03l
    # T00,T01,S14,S10,T02=S'12,S'13,S'14,S'10,S'11
    xornotand \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S14h, \S14l, \T03h, \T03l
    lw \T02l, 11*8(a0)
    lw \T02h, 11*8+4(a0)
    sw \T03l, 12*8(a0)
    sw \T03h, 12*8+4(a0)
    notxoror \T03h, \T03l, \T01h, \T01l, \S14h, \S14l, \S10h, \S10l, \T03h, \T03l, \T04
    sw \T03l, 13*8(a0)
    sw \T03h, 13*8+4(a0)
    xorand \S14h, \S14l, \S14h, \S14l, \S10h, \S10l, \T02h, \T02l, \T03h, \T03l
    xoror \S10h, \S10l, \S10h, \S10l, \T02h, \T02l, \T00h, \T00l, \T03h, \T03l
    xorand \T02h, \T02l, \T02h, \T02l, \T00h, \T00l, \T01h, \T01l, \T03h, \T03l
    lw \T00h, 24*8+4(a0)
    lw \T01h, 20*8+4(a0)
    sw \T02h, 11*8+4(a0)
    sw \T02l, 11*8(a0)
    # T00,T01,T02,S16,S17=S'18,S'19,S'15,S'16,S'17
    lw \T02h, 15*8+4(a0)
    lw \T01l, 20*8(a0)
    lw \T02l, 15*8(a0)
    lw \T00l, 24*8(a0)
    notxorand \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \T02h, \T02l, \T03h, \T03l, \T04
    sw \T03l, 18*8(a0)
    sw \T03h, 18*8+4(a0)
    xoror \T03h, \T03l, \T01h, \T01l, \T02h, \T02l, \S16h, \S16l, \T03h, \T03l
    sw \T03l, 19*8(a0)
    sw \T03h, 19*8+4(a0)
    xorand \T02h, \T02l, \T02h, \T02l, \S16h, \S16l, \S17h, \S17l, \T03h, \T03l
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    xoror \S16h, \S16l, \S16h, \S16l, \S17h, \S17l, \T00h, \T00l, \T03h, \T03l
    lw \T02l, 22*8(a0)
    lw \T02h, 22*8+4(a0)
    not \T03l, \T00l
    not \T03h, \T00h
    lw \T00l, 0*8(a0)
    lw \T00h, 0*8+4(a0)
    or  \T03l, \T03l, \T01l
    or  \T03h, \T03h, \T01h
    lw \T01l, 1*8(a0)
    lw \T01h, 1*8+4(a0)
    xor \S17l, \S17l, \T03l
    xor \S17h, \S17h, \T03h
    # T00,T01,S21,T02,S23=S'24,S'20,S'21,S'22,S'23
    xorand \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S21h, \S21l, \T03h, \T03l
    sw \T03l, 24*8(a0)
    sw \T03h, 24*8+4(a0)
    xornotand \T03h, \T03l, \T01h, \T01l, \S21h, \S21l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 20*8(a0)
    sw \T03h, 20*8+4(a0)
    notxoror \S21h, \S21l, \S21h, \S21l, \T02h, \T02l, \S23h, \S23l, \T03h, \T03l, \T04
    xorand \T02h, \T02l, \T02h, \T02l, \S23h, \S23l, \T00h, \T00l, \T03h, \T03l
    lw \T04, 17*4(sp)
    or  \T03l, \T00l, \T01l
    or  \T03h, \T00h, \T01h
    lw \T00l, 18*4(sp)
    lw \T00h, 19*4(sp)
    sw \T02l, 22*8(a0)
    sw \T02h, 22*8+4(a0)
    lw \T01l, 20*4(sp)
    lw \T01h, 21*4(sp)
    xor \S23h, \S23h, \T03h
    xor \S23l, \S23l, \T03l
    # T00,T01,S02,T02,S04=S'00-S'04
    lw \T02l, 0(\T04)
    lw \T02h, 4(\T04)
    addi \T04, \T04, 8
    xoror \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S02h, \S02l, \T03h, \T03l
    # Itoa
    sw  \T04, 17*4(sp)
    XOR1 \T03h, \T03l, \T02h, \T02l
    lw \T02l, 3*8(a0)
    lw \T02h, 3*8+4(a0)
    sw \T03l, 0*8(a0)
    sw \T03h, 0*8+4(a0)
    xornotor \T03h, \T03l, \T01h, \T01l, \S02h, \S02l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 1*8(a0)
    sw \T03h, 1*8+4(a0)
    xorand \S02h, \S02l, \S02h, \S02l, \T02h, \T02l, \S04h, \S04l, \T03h, \T03l
    # loop control
    lw \T04, 16*4(sp)
    xoror \T03h, \T03l, \T02h, \T02l, \S04h, \S04l, \T00h, \T00l, \T03h, \T03l
    sw \T03l, 3*8(a0)
    sw \T03h, 3*8+4(a0)
    addi \T04, \T04, -1
    xorand \S04h, \S04l, \S04h, \S04l, \T00h, \T00l, \T01h, \T01l, \T03h, \T03l
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
.globl KeccakF1600_StatePermute_RV32ASM
.align 2
KeccakF1600_StatePermute_RV32ASM:
    addi sp, sp, -4*28
    la t0, constants_keccak
    SaveRegs
    sw t0, 17*4(sp)

    InitLoad \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp

    li tp, 24

loop_start:
    sw tp, 16*4(sp)
    ARound \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp
    
    # lw tp, 16*4(sp)
    # addi tp, tp, -1
    bnez tp, loop_start

    FinalStore \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp

    RestoreRegs
    addi sp, sp, 4*28
    ret
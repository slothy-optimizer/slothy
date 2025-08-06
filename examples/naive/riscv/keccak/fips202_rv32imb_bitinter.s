.data
.align 2
constants_keccak:
.word 0x00000001
.word 0x00000000
.word 0x00000000
.word 0x00000089
.word 0x00000000
.word 0x8000008b
.word 0x00000000
.word 0x80008080
.word 0x00000001
.word 0x0000008b
.word 0x00000001
.word 0x00008000
.word 0x00000001
.word 0x80008088
.word 0x00000001
.word 0x80000082
.word 0x00000000
.word 0x0000000b
.word 0x00000000
.word 0x0000000a
.word 0x00000001
.word 0x00008082
.word 0x00000000
.word 0x00008003
.word 0x00000001
.word 0x0000808b
.word 0x00000001
.word 0x8000000b
.word 0x00000001
.word 0x8000008a
.word 0x00000001
.word 0x80000081
.word 0x00000000
.word 0x80000081
.word 0x00000000
.word 0x80000008
.word 0x00000000
.word 0x00000083
.word 0x00000000
.word 0x80008003
.word 0x00000001
.word 0x80008088
.word 0x00000000
.word 0x80000088
.word 0x00000001
.word 0x00008000
.word 0x00000000
.word 0x80008082

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

.macro ROLn_e outh, outl, inh, inl, n
    rori \outl, \inl, 32-\n
    rori \outh, \inh, 32-\n
.endm

.macro ROLn_o outh, outl, inh, inl, n
    rori \outh, \inl, 32-\n
    rori \outl, \inh, 32-(\n+1)
.endm

.macro ROL1 outh, outl, inh, inl
    mv \outh, \inl
    rori \outl, \inh, 32-1
.endm

# ROL1 for outh,outl and then xor with inh,inl
.macro ROL1XORInplace outh, outl, inh, inl, T
    # ROL1(outh,outl) = (outl,ROL1_32b(outh,1))
    rori \T, \outh, 32-1
    xor  \outh, \outl, \inh
    xor  \outl, \T, \inl
.endm

.macro ChiOp \
        outh, outl, \
        S00h, S00l, S01h, S01l, S02h, S02l, \
        Th, Tl
    andn \Tl, \S02l, \S01l
    andn \Th, \S02h, \S01h
    xor \outl, \Tl, \S00l
    xor \outh, \Th, \S00h
.endm

.macro InitLoad \
        S02h, S02l, S04h, S04l, S05h, S05l, S08h, S08l, S10h, S10l, \
        S14h, S14l, S16h, S16l, S17h, S17l, S21h, S21l, S23h, S23l
    lw \S02l, 2*8(a0)
    lw \S02h, 2*8+4(a0)
    lw \S04l, 4*8(a0)
    lw \S04h, 4*8+4(a0)
    lw \S05l, 5*8(a0)
    lw \S05h, 5*8+4(a0)
    lw \S08l, 8*8(a0)
    lw \S08h, 8*8+4(a0)
    lw \S10l, 10*8(a0)
    lw \S10h, 10*8+4(a0)
    lw \S14l, 14*8(a0)
    lw \S14h, 14*8+4(a0)
    lw \S16l, 16*8(a0)
    lw \S16h, 16*8+4(a0)
    lw \S17l, 17*8(a0)
    lw \S17h, 17*8+4(a0)
    lw \S21l, 21*8(a0)
    lw \S21h, 21*8+4(a0)
    lw \S23l, 23*8(a0)
    lw \S23h, 23*8+4(a0)
.endm

.macro FinalStore \
        S02h, S02l, S04h, S04l, S05h, S05l, S08h, S08l, S10h, S10l, \
        S14h, S14l, S16h, S16l, S17h, S17l, S21h, S21l, S23h, S23l
    sw \S02l, 2*8(a0)
    sw \S02h, 2*8+4(a0)
    sw \S04l, 4*8(a0)
    sw \S04h, 4*8+4(a0)
    sw \S05l, 5*8(a0)
    sw \S05h, 5*8+4(a0)
    sw \S08l, 8*8(a0)
    sw \S08h, 8*8+4(a0)
    sw \S10l, 10*8(a0)
    sw \S10h, 10*8+4(a0)
    sw \S14l, 14*8(a0)
    sw \S14h, 14*8+4(a0)
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
    # save C3
    sw \T01l, 24*4(sp)
    sw \T01h, 25*4(sp)
    # T00=C0, T01=C3
    # D4=C3^ROL(C0,1);
    ROL1XORInplace \T00h, \T00l, \T01h, \T01l, \T03h
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
    # save C4
    sw \T01l, 26*4(sp)
    sw \T01h, 27*4(sp)
    sw \T03l, 24*8(a0)
    sw \T03h, 24*8+4(a0)
    # T01=C4
    # C1=S01+S06+S11+S16+S21
    lw \T03l, 1*8(a0)
    lw \T03h, 1*8+4(a0)
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
    ROL1XORInplace \T00h, \T00l, \T01h, \T01l, \T03h
    # T01=C4,T00=D0
    # S00,S05,S10,S15,S20 += D0
    lw \T02l, 0*8(a0)
    lw \T02h, 0*8+4(a0)
    XOR1 \S05h, \S05l, \T00h, \T00l
    XOR1 \T02h, \T02l, \T00h, \T00l
    sw \T02l, 0*8(a0)
    sw \T02h, 0*8+4(a0)
    lw \T02l, 15*8(a0)
    lw \T02h, 15*8+4(a0)
    XOR1 \S10h, \S10l, \T00h, \T00l
    XOR1 \T02h, \T02l, \T00h, \T00l
    lw \T03l, 20*8(a0)
    lw \T03h, 20*8+4(a0)
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    lw \T02h, 25*4(sp)
    lw \T02l, 24*4(sp)
    XOR1 \T03h, \T03l, \T00h, \T00l
    sw \T03l, 20*8(a0)
    sw \T03h, 20*8+4(a0)
    # T01=C4
    # D2=C1^ROL(C3,1)
    lw \T00h, 21*4(sp)
    lw \T00l, 20*4(sp)
    ROL1XORInplace \T02h, \T02l, \T00h, \T00l, \T03h
    # T01=C4,T02=D2
    # C2=S02+S07+S12+S17+S22
    # S02,S07,S12,S17,S22 += D2
    lw \T03l, 7*8(a0)
    lw \T03h, 7*8+4(a0)
    XOR1Init \T00h, \T00l, \S02h, \S02l, \S17h, \S17l
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    sw \T03l, 7*8(a0)
    sw \T03h, 7*8+4(a0)
    lw \T03l, 12*8(a0)
    lw \T03h, 12*8+4(a0)
    XOR1 \S02h, \S02l, \T02h, \T02l
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    sw \T03l, 12*8(a0)
    sw \T03h, 12*8+4(a0)
    lw \T03l, 22*8(a0)
    lw \T03h, 22*8+4(a0)
    XOR1 \S17h, \S17l, \T02h, \T02l
    XOR1 \T00h, \T00l, \T03h, \T03l
    XOR1 \T03h, \T03l, \T02h, \T02l
    # save C2
    sw \T00l, 22*4(sp)
    sw \T00h, 23*4(sp)
    sw \T03l, 22*8(a0)
    sw \T03h, 22*8+4(a0)
    # T01=C4,T00=C2
    # D3=C2^ROL(C4,1)
    ROL1XORInplace \T01h, \T01l, \T00h, \T00l, \T03h
    # T01=D3
    # S03,S08,S13,S18,S23 += D3
    lw \T03l, 3*8(a0)
    lw \T03h, 3*8+4(a0)
    XOR1 \S08h, \S08l, \T01h, \T01l
    XOR1 \T03h, \T03l, \T01h, \T01l
    lw \T02l, 13*8(a0)
    lw \T02h, 13*8+4(a0)
    sw \T03l, 3*8(a0)
    sw \T03h, 3*8+4(a0)
    XOR1 \T02h, \T02l, \T01h, \T01l
    lw \T03l, 18*8(a0)
    lw \T03h, 18*8+4(a0)
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
    ROL1XORInplace \T00h, \T00l, \T01h, \T01l, \T03h
    # T00=D1
    # S01,S06,S11,S16,S21 += D1
    lw \T02l, 1*8(a0)
    lw \T02h, 1*8+4(a0)
    XOR1 \S16h, \S16l, \T00h, \T00l
    XOR1 \T02h, \T02l, \T00h, \T00l
    lw \T03l, 6*8(a0)
    lw \T03h, 6*8+4(a0)
    sw \T02l, 1*8(a0)
    sw \T02h, 1*8+4(a0)
    XOR1 \T03h, \T03l, \T00h, \T00l
    lw \T02l, 11*8(a0)
    lw \T02h, 11*8+4(a0)
    XOR1 \S21h, \S21l, \T00h, \T00l
    sw \T03l, 6*8(a0)
    sw \T03h, 6*8+4(a0)
    XOR1 \T02h, \T02l, \T00h, \T00l
    sw \T02l, 11*8(a0)
    sw \T02h, 11*8+4(a0)
    mv \T02l, \T03l
    mv \T02h, \T03h
    ROLn_e \T03h, \T03l, \S21h, \S21l, 1
    lw \T00l, 0*8(a0)
    lw \T00h, 0*8+4(a0)
    ROLn_e \T01h, \T01l, \T02h, \T02l, 22
    sw \T03l, 0*8(a0)
    sw \T03h, 0*8+4(a0)
    ROLn_o \S21h, \S21l, \S08h, \S08l, 27
    lw \T02l, 3*8(a0)    
    lw \T02h, 3*8+4(a0)
    ROLn_o \S08h, \S08l, \S16h, \S16l, 22
    lw \T03l, 18*8(a0)
    lw \T03h, 18*8+4(a0)
    ROLn_e \S16h, \S16l, \S05h, \S05l, 18
    sw \T00l, 18*4(sp)
    sw \T00h, 19*4(sp)
    ROLn_e \S05h, \S05l, \T02h, \T02l, 14
    ROLn_o \T02h, \T02l, \T03h, \T03l, 10
    lw \T04, 13*8(a0)
    sw \T02l, 3*8(a0)
    lw \T02l, 13*8+4(a0)
    sw \T02h, 3*8+4(a0)
    ROLn_o \T03h, \T03l, \T02l, \T04, 12
    sw \T03l, 18*8(a0)
    sw \T03h, 18*8+4(a0)
    ROLn_o \T02h, \T02l, \S10h, \S10l, 1
    lw \T03l, 1*8(a0)
    lw \T03h, 1*8+4(a0)
    sw \T02l, 13*8(a0)
    sw \T02h, 13*8+4(a0)
    ROL1 \S10h, \S10l, \T03h, \T03l
    sw \T01l, 20*4(sp)
    sw \T01h, 21*4(sp)
    ROLn_e \T02h, \T02l, \S02h, \S02l, 31
    lw \T03l, 12*8(a0)
    lw \T03h, 12*8+4(a0)
    sw \T02l, 1*8(a0)
    sw \T02h, 1*8+4(a0)
    lw \T02l, 9*8(a0)
    lw \T02h, 9*8+4(a0)
    ROLn_o \S02h, \S02l, \T03h, \T03l, 21
    ROLn_e \T03h, \T03l, \T02h, \T02l, 10
    lw \T04,  22*8(a0)
    sw \T03h, 12*8+4(a0)
    lw \T03h, 22*8+4(a0)
    sw \T03l, 12*8(a0)
    ROLn_o \T02h, \T02l, \T03h, \T04, 30
    sw \T02l, 9*8(a0)
    sw \T02h, 9*8+4(a0)
    ROLn_o \T03h, \T03l, \S14h, \S14l, 19
    lw \T02l, 20*8(a0)
    lw \T02h, 20*8+4(a0)
    sw \T03l, 22*8(a0)
    sw \T03h, 22*8+4(a0)
    ROLn_e \S14h, \S14l, \T02h, \T02l, 9
    ROLn_e \T02h, \T02l, \S23h, \S23l, 28
    lw \T03l, 15*8(a0)
    lw \T03h, 15*8+4(a0)
    sw \T02l, 20*8(a0)
    sw \T02h, 20*8+4(a0)
    ROLn_o \S23h, \S23l, \T03h, \T03l, 20
    ROLn_o \T02h, \T02l, \S04h, \S04l, 13
    lw \T03l, 24*8(a0)
    lw \T03h, 24*8+4(a0)
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    ROLn_e \S04h, \S04l, \T03h, \T03l, 7
    ROLn_o \T02h, \T02l, \S17h, \S17l, 7
    lw \T03l, 11*8(a0)
    lw \T03h, 11*8+4(a0)
    sw \T02l, 24*8(a0)
    sw \T02h, 24*8+4(a0)
    lw \T04, 7*8(a0)
    lw \T02l, 7*8+4(a0)
    ROLn_e \S17h, \S17l, \T03h, \T03l, 5
    ROLn_e \T03h, \T03l, \T02l, \T04, 3
    lw \T04, 19*8(a0)
    lw \T02h, 19*8+4(a0)
    sw \T03l, 11*8(a0)
    sw \T03h, 11*8+4(a0)
    ROLn_e \T03h, \T03l, \T02h, \T04, 4
    lw \T01l, 13*8(a0)
    lw \T01h, 13*8+4(a0)
    sw \T03l, 19*8(a0)
    sw \T03h, 19*8+4(a0)
    # chi - start
    # T00,T01,S08,T02,S05=S'06,S'07,S'08,S'09,S'05
    lw \T00l, 12*8(a0)
    lw \T00h, 12*8+4(a0)
    ChiOp \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S08h, \S08l, \T03h, \T03l
    lw \T02l, 9*8(a0)
    lw \T02h, 9*8+4(a0)
    sw \T03l, 6*8(a0)
    sw \T03h, 6*8+4(a0)
    ChiOp \T03h, \T03l, \T01h, \T01l, \S08h, \S08l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 7*8(a0)
    sw \T03h, 7*8+4(a0)
    ChiOp \S08h, \S08l, \S08h, \S08l, \T02h, \T02l, \S05h, \S05l, \T03h, \T03l
    ChiOp \T02h, \T02l, \T02h, \T02l, \S05h, \S05l, \T00h, \T00l, \T03h, \T03l
    sw \T02l, 9*8(a0)
    sw \T02h, 9*8+4(a0)
    andn \T03l, \T01l, \T00l
    andn \T03h, \T01h, \T00h
    lw \T01l, 19*8(a0)
    lw \T01h, 19*8+4(a0)
    xor \S05h, \T03h, \S05h
    xor \S05l, \T03l, \S05l
    lw \T00l, 18*8(a0)
    lw \T00h, 18*8+4(a0)
    # T00,T01,S14,S10,T02=S'12,S'13,S'14,S'10,S'11
    andn \T03l, \S14l, \T01l
    andn \T03h, \S14h, \T01h
    lw \T02l, 11*8(a0)
    lw \T02h, 11*8+4(a0)
    xor  \T03l, \T03l, \T00l
    xor  \T03h, \T03h, \T00h
    sw \T03l, 12*8(a0)
    sw \T03h, 12*8+4(a0)
    ChiOp \T03h, \T03l, \T01h, \T01l, \S14h, \S14l, \S10h, \S10l, \T03h, \T03l
    sw \T03l, 13*8(a0)
    sw \T03h, 13*8+4(a0)
    ChiOp \S14h, \S14l, \S14h, \S14l, \S10h, \S10l, \T02h, \T02l, \T03h, \T03l
    ChiOp \S10h, \S10l, \S10h, \S10l, \T02h, \T02l, \T00h, \T00l, \T03h, \T03l
    ChiOp \T02h, \T02l, \T02h, \T02l, \T00h, \T00l, \T01h, \T01l, \T03h, \T03l
    lw \T01l, 20*8(a0)
    lw \T01h, 20*8+4(a0)
    sw \T02l, 11*8(a0)
    sw \T02h, 11*8+4(a0)
    # T00,T01,T02,S16,S17=S'18,S'19,S'15,S'16,S'17
    lw \T02l, 15*8(a0)
    lw \T02h, 15*8+4(a0)
    lw \T00l, 24*8(a0)
    lw \T00h, 24*8+4(a0)
    ChiOp \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 18*8(a0)
    sw \T03h, 18*8+4(a0)
    ChiOp \T03h, \T03l, \T01h, \T01l, \T02h, \T02l, \S16h, \S16l, \T03h, \T03l
    sw \T03l, 19*8(a0)
    sw \T03h, 19*8+4(a0)
    ChiOp \T02h, \T02l, \T02h, \T02l, \S16h, \S16l, \S17h, \S17l, \T03h, \T03l
    sw \T02l, 15*8(a0)
    sw \T02h, 15*8+4(a0)
    ChiOp \S16h, \S16l, \S16h, \S16l, \S17h, \S17l, \T00h, \T00l, \T03h, \T03l
    andn \T03l, \T01l, \T00l
    andn \T03h, \T01h, \T00h
    lw \T00l, 0*8(a0)
    lw \T00h, 0*8+4(a0)
    xor \S17h, \S17h, \T03h
    xor \S17l, \S17l, \T03l
    lw \T01l, 1*8(a0)
    lw \T01h, 1*8+4(a0)
    # T00,T01,S21,T02,S23=S'24,S'20,S'21,S'22,S'23
    lw \T02l, 22*8(a0)
    lw \T02h, 22*8+4(a0)
    ChiOp \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S21h, \S21l, \T03h, \T03l
    sw \T03l, 24*8(a0)
    sw \T03h, 24*8+4(a0)
    ChiOp \T03h, \T03l, \T01h, \T01l, \S21h, \S21l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 20*8(a0)
    sw \T03h, 20*8+4(a0)
    ChiOp \S21h, \S21l, \S21h, \S21l, \T02h, \T02l, \S23h, \S23l, \T03h, \T03l
    lw \T04, 17*4(sp)
    ChiOp \T02h, \T02l, \T02h, \T02l, \S23h, \S23l, \T00h, \T00l, \T03h, \T03l
    sw \T02l, 22*8(a0)
    sw \T02h, 22*8+4(a0)
    andn \T03l, \T01l, \T00l
    andn \T03h, \T01h, \T00h
    # restore T00,T01 from stack
    lw \T00l, 18*4(sp)
    lw \T00h, 19*4(sp)
    xor \S23h, \S23h, \T03h
    xor \S23l, \S23l, \T03l
    lw \T01l, 20*4(sp)
    lw \T01h, 21*4(sp)
    # T00,T01,S02,T02,S04=S'00-S'04
    lw \T02l, 0(\T04)
    lw \T02h, 4(\T04)
    addi \T04, \T04, 8
    ChiOp \T03h, \T03l, \T00h, \T00l, \T01h, \T01l, \S02h, \S02l, \T03h, \T03l
    # Itoa
    sw   \T04, 17*4(sp)
    XOR1 \T03h, \T03l, \T02h, \T02l
    lw \T02l, 3*8(a0)
    lw \T02h, 3*8+4(a0)
    sw \T03l, 0*8(a0)
    sw \T03h, 0*8+4(a0)
    ChiOp \T03h, \T03l, \T01h, \T01l, \S02h, \S02l, \T02h, \T02l, \T03h, \T03l
    sw \T03l, 1*8(a0)
    sw \T03h, 1*8+4(a0)
    ChiOp \T03h, \T03l, \T02h, \T02l, \S04h, \S04l, \T00h, \T00l, \T03h, \T03l
    sw \T03l, 3*8(a0)
    sw \T03h, 3*8+4(a0)
    ChiOp \S02h, \S02l, \S02h, \S02l, \T02h, \T02l, \S04h, \S04l, \T03h, \T03l
    # loop control
    lw  \T04, 16*4(sp)
    ChiOp \S04h, \S04l, \S04h, \S04l, \T00h, \T00l, \T01h, \T01l, \T03h, \T03l
    addi \T04, \T04, -1
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
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5

    li tp, 24

loop_start:
    sw tp, 16*4(sp)
    ARound \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp
    bnez tp, loop_start

    FinalStore \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5

    RestoreRegs
    addi sp, sp, 4*28
    ret
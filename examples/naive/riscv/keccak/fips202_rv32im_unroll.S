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

.macro InitLoad \
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

.macro FinalStore \
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

.macro ARound \
        S02h_s, S02l_s, S04h_s, S04l_s, S05h_s, S05l_s, S08h_s, S08l_s, S10h_s, S10l_s, \
        S14h_s, S14l_s, S16h_s, S16l_s, S17h_s, S17l_s, S21h_s, S21l_s, S23h_s, S23l_s, \
        T00h_s, T00l_s, T01h_s, T01l_s, T02h_s, T02l_s, T03h_s, T03l_s, T04_s
    lw \T03l_s, 0*8(a0)
    lw \T03h_s, 0*8+4(a0)
    xor \T00h_s, \S05h_s, \S10h_s
    xor \T00l_s, \S05l_s, \S10l_s
    lw \T02l_s, 15*8(a0)
    lw \T02h_s, 15*8+4(a0)
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    lw \T03l_s, 20*8(a0)
    lw \T03h_s, 20*8+4(a0)
    xor \T00h_s, \T00h_s, \T02h_s
    xor \T00l_s, \T00l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    sw \T00l_s, 18*4(sp)
    sw \T00h_s, 19*4(sp)
    lw \T03l_s, 3*8(a0)
    lw \T03h_s, 3*8+4(a0)
    xor \T01h_s, \S08h_s, \S23h_s
    xor \T01l_s, \S08l_s, \S23l_s
    lw \T02l_s, 13*8(a0)
    lw \T02h_s, 13*8+4(a0)
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T01l_s, \T01l_s, \T03l_s
    lw \T03l_s, 18*8(a0)
    lw \T03h_s, 18*8+4(a0)
    xor \T01h_s, \T01h_s, \T02h_s
    xor \T01l_s, \T01l_s, \T02l_s
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T01l_s, \T01l_s, \T03l_s
    sw \T01l_s, 24*4(sp)
    sw \T01h_s, 25*4(sp)
    srli \T03h_s, \T00l_s, 31
    slli \T00l_s, \T00l_s, 1
    srli \T03l_s, \T00h_s, 31
    slli \T00h_s, \T00h_s, 1
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00h_s, \T00h_s, \T01h_s
    xor \T00l_s, \T00l_s, \T01l_s
    lw \T03l_s, 9*8(a0)
    lw \T03h_s, 9*8+4(a0)
    xor \T01h_s, \S04h_s, \S14h_s
    xor \T01l_s, \S04l_s, \S14l_s
    xor \S04h_s, \S04h_s, \T00h_s
    xor \S04l_s, \S04l_s, \T00l_s
    xor \S14h_s, \S14h_s, \T00h_s
    xor \S14l_s, \S14l_s, \T00l_s
    lw \T02l_s, 19*8(a0)
    lw \T02h_s, 19*8+4(a0)
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T03h_s, \T03h_s, \T00h_s
    xor \T03l_s, \T03l_s, \T00l_s
    sw \T03l_s, 9*8(a0)
    sw \T03h_s, 9*8+4(a0)
    lw \T03l_s, 24*8(a0)
    lw \T03h_s, 24*8+4(a0)
    xor \T01h_s, \T01h_s, \T02h_s
    xor \T01l_s, \T01l_s, \T02l_s
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    sw \T02l_s, 19*8(a0)
    sw \T02h_s, 19*8+4(a0)
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T03h_s, \T03h_s, \T00h_s
    xor \T03l_s, \T03l_s, \T00l_s
    sw \T03l_s, 24*8(a0)
    sw \T03h_s, 24*8+4(a0)
    sw \T01l_s, 26*4(sp)
    sw \T01h_s, 27*4(sp)
    lw \T03l_s, 1*8(a0)
    lw \T03h_s, 1*8+4(a0)
    xor \T00h_s, \S16h_s, \S21h_s
    xor \T00l_s, \S16l_s, \S21l_s
    lw \T02l_s, 6*8(a0)
    lw \T02h_s, 6*8+4(a0)
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    lw \T03l_s, 11*8(a0)
    lw \T03h_s, 11*8+4(a0)
    xor \T00h_s, \T00h_s, \T02h_s
    xor \T00l_s, \T00l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    sw \T00l_s, 20*4(sp)
    sw \T00h_s, 21*4(sp)
    srli \T03h_s, \T00l_s, 32-1
    slli \T00l_s, \T00l_s, 1
    srli \T03l_s, \T00h_s, 32-1
    slli \T00h_s, \T00h_s, 1
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00h_s, \T00h_s, \T01h_s
    xor \T00l_s, \T00l_s, \T01l_s
    lw \T02l_s, 0*8(a0)
    lw \T02h_s, 0*8+4(a0)
    xor \S05h_s, \S05h_s, \T00h_s
    xor \S05l_s, \S05l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    sw \T02l_s, 0*8(a0)
    sw \T02h_s, 0*8+4(a0)
    lw \T02l_s, 15*8(a0)
    lw \T02h_s, 15*8+4(a0)
    xor \S10h_s, \S10h_s, \T00h_s
    xor \S10l_s, \S10l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    lw \T03l_s, 20*8(a0)
    lw \T03h_s, 20*8+4(a0)
    xor \T03h_s, \T03h_s, \T00h_s
    xor \T03l_s, \T03l_s, \T00l_s
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    sw \T03l_s, 20*8(a0)
    sw \T03h_s, 20*8+4(a0)
    lw \T02l_s, 24*4(sp)
    lw \T02h_s, 25*4(sp)
    lw \T00l_s, 20*4(sp)
    lw \T00h_s, 21*4(sp)
    srli \T03h_s, \T02l_s, 32-1
    slli \T02l_s, \T02l_s, 1
    srli \T03l_s, \T02h_s, 32-1
    slli \T02h_s, \T02h_s, 1
    xor \T02l_s, \T02l_s, \T03l_s
    xor \T02h_s, \T02h_s, \T03h_s
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    lw \T03l_s, 7*8(a0)
    lw \T03h_s, 7*8+4(a0)
    xor \T00h_s, \S02h_s, \S17h_s
    xor \T00l_s, \S02l_s, \S17l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T03h_s, \T02h_s
    xor \T03l_s, \T03l_s, \T02l_s
    sw \T03l_s, 7*8(a0)
    sw \T03h_s, 7*8+4(a0)
    lw \T03l_s, 12*8(a0)
    lw \T03h_s, 12*8+4(a0)
    xor \S02h_s, \S02h_s, \T02h_s
    xor \S02l_s, \S02l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T03h_s, \T02h_s
    xor \T03l_s, \T03l_s, \T02l_s
    sw \T03l_s, 12*8(a0)
    sw \T03h_s, 12*8+4(a0)
    lw \T03l_s, 22*8(a0)
    lw \T03h_s, 22*8+4(a0)
    xor \S17h_s, \S17h_s, \T02h_s
    xor \S17l_s, \S17l_s, \T02l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T03h_s, \T03h_s, \T02h_s
    xor \T03l_s, \T03l_s, \T02l_s
    sw \T03l_s, 22*8(a0)
    sw \T03h_s, 22*8+4(a0)
    sw \T00l_s, 22*4(sp)
    sw \T00h_s, 23*4(sp)
    srli \T03h_s, \T01l_s, 32-1
    slli \T01l_s, \T01l_s, 1
    srli \T03l_s, \T01h_s, 32-1
    slli \T01h_s, \T01h_s, 1
    xor \T01l_s, \T01l_s, \T03l_s
    xor \T01h_s, \T01h_s, \T03h_s
    xor \T01h_s, \T01h_s, \T00h_s
    xor \T01l_s, \T01l_s, \T00l_s
    lw \T03l_s, 3*8(a0)
    lw \T03h_s, 3*8+4(a0)
    xor \S08h_s, \S08h_s, \T01h_s
    xor \S08l_s, \S08l_s, \T01l_s
    xor \T03h_s, \T03h_s, \T01h_s
    xor \T03l_s, \T03l_s, \T01l_s
    sw \T03l_s, 3*8(a0)
    sw \T03h_s, 3*8+4(a0)
    lw \T02l_s, 13*8(a0)
    lw \T02h_s, 13*8+4(a0)
    xor \S23h_s, \S23h_s, \T01h_s
    xor \S23l_s, \S23l_s, \T01l_s
    xor \T02h_s, \T02h_s, \T01h_s
    xor \T02l_s, \T02l_s, \T01l_s
    sw \T02l_s, 13*8(a0)
    sw \T02h_s, 13*8+4(a0)
    lw \T03l_s, 18*8(a0)
    lw \T03h_s, 18*8+4(a0)
    xor \T03h_s, \T03h_s, \T01h_s
    xor \T03l_s, \T03l_s, \T01l_s
    sw \T02l_s, 13*8(a0)
    sw \T02h_s, 13*8+4(a0)
    sw \T03l_s, 18*8(a0)
    sw \T03h_s, 18*8+4(a0)
    lw \T01l_s, 18*4(sp)
    lw \T01h_s, 19*4(sp)
    srli \T03h_s, \T00l_s, 32-1
    slli \T00l_s, \T00l_s, 1
    srli \T03l_s, \T00h_s, 32-1
    slli \T00h_s, \T00h_s, 1
    xor \T00l_s, \T00l_s, \T03l_s
    xor \T00h_s, \T00h_s, \T03h_s
    xor \T00h_s, \T00h_s, \T01h_s
    xor \T00l_s, \T00l_s, \T01l_s
    lw \T02l_s, 1*8(a0)
    lw \T02h_s, 1*8+4(a0)
    xor \S16h_s, \S16h_s, \T00h_s
    xor \S16l_s, \S16l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    sw \T02l_s, 1*8(a0)
    sw \T02h_s, 1*8+4(a0)
    lw \T03l_s, 6*8(a0)
    lw \T03h_s, 6*8+4(a0)
    xor \S21h_s, \S21h_s, \T00h_s
    xor \S21l_s, \S21l_s, \T00l_s
    xor \T03h_s, \T03h_s, \T00h_s
    xor \T03l_s, \T03l_s, \T00l_s
    lw \T02l_s, 11*8(a0)
    lw \T02h_s, 11*8+4(a0)
    sw \T03l_s, 6*8(a0)
    sw \T03h_s, 6*8+4(a0)
    xor \T02h_s, \T02h_s, \T00h_s
    xor \T02l_s, \T02l_s, \T00l_s
    sw \T02l_s, 11*8(a0)
    sw \T02h_s, 11*8+4(a0)
    lw \T00l_s, 0*8(a0)
    lw \T00h_s, 0*8+4(a0)
    lw \T01l_s, 6*8(a0)
    lw \T01h_s, 6*8+4(a0)
    slli \T03l_s, \S21l_s, 2
    srli \S21l_s, \S21l_s, 32-2
    srli \T03h_s, \S21h_s, 32-2
    xor  \T03l_s, \T03l_s, \T03h_s
    slli \T03h_s, \S21h_s, 2
    xor  \T03h_s, \T03h_s, \S21l_s
    slli \T02h_s,  \T01l_s, 44-32
    srli \T01l_s, \T01l_s, 64-44
    slli \T02l_s,  \T01h_s, 44-32
    xor  \T01l_s, \T01l_s, \T02l_s
    srli \T01h_s, \T01h_s, 64-44
    xor  \T01h_s, \T01h_s, \T02h_s
    sw \T03l_s, 0*8(a0)
    sw \T03h_s, 0*8+4(a0)
    slli \S21h_s, \S08l_s, 55-32
    srli \S08l_s, \S08l_s, 64-55
    srli \S21l_s, \S08h_s, 64-55
    xor  \S21h_s, \S21h_s, \S21l_s
    slli \S21l_s, \S08h_s, 55-32
    xor  \S21l_s, \S21l_s, \S08l_s
    slli \S08h_s, \S16l_s, 45-32
    srli \S16l_s, \S16l_s, 64-45
    srli \S08l_s, \S16h_s, 64-45
    xor  \S08h_s, \S08h_s, \S08l_s
    slli \S08l_s, \S16h_s, 45-32
    xor  \S08l_s, \S08l_s, \S16l_s
    lw \T02l_s, 3*8(a0)
    lw \T02h_s, 3*8+4(a0)
    slli \S16h_s, \S05l_s, 36-32
    srli \S05l_s, \S05l_s, 64-36
    srli \S16l_s, \S05h_s, 64-36
    xor  \S16h_s, \S16h_s, \S16l_s
    slli \S16l_s, \S05h_s, 36-32
    xor  \S16l_s, \S16l_s, \S05l_s
    lw \T03l_s, 18*8(a0)
    lw \T03h_s, 18*8+4(a0)
    slli \S05l_s, \T02l_s, 28
    srli \T02l_s, \T02l_s, 32-28
    srli \S05h_s, \T02h_s, 32-28
    xor  \S05l_s, \S05l_s, \S05h_s
    slli \S05h_s, \T02h_s, 28
    xor  \S05h_s, \S05h_s, \T02l_s
    slli \T02l_s, \T03l_s, 21
    srli \T03l_s, \T03l_s, 32-21
    srli \T02h_s, \T03h_s, 32-21
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \T03h_s, 21
    xor  \T02h_s, \T02h_s, \T03l_s
    lw \T03l_s, 13*8(a0)
    lw \T03h_s, 13*8+4(a0)
    sw \T02l_s, 3*8(a0)
    sw \T02h_s, 3*8+4(a0)
    srli \T02h_s,  \T03l_s, 32-25
    slli \T03l_s, \T03l_s, 25
    srli \T02l_s,   \T03h_s, 32-25
    slli \T03h_s, \T03h_s, 25
    xor  \T03l_s, \T03l_s, \T02l_s
    xor  \T03h_s, \T03h_s, \T02h_s
    sw \T03l_s, 18*8(a0)
    sw \T03h_s, 18*8+4(a0)
    slli \T02l_s, \S10l_s, 3
    srli \S10l_s, \S10l_s, 32-3
    srli \T02h_s, \S10h_s, 32-3
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \S10h_s, 3
    xor  \T02h_s, \T02h_s, \S10l_s
    lw \T03l_s, 1*8(a0)
    lw \T03h_s, 1*8+4(a0)
    sw \T02l_s, 13*8(a0)
    sw \T02h_s, 13*8+4(a0)
    slli \S10l_s, \T03l_s, 1
    srli \T03l_s, \T03l_s, 32-1
    srli \S10h_s, \T03h_s, 32-1
    xor  \S10l_s, \S10l_s, \S10h_s
    slli \S10h_s, \T03h_s, 1
    xor  \S10h_s, \S10h_s, \T03l_s
    slli \T02l_s, \S02h_s, 62-32
    srli \S02h_s, \S02h_s, 64-62
    srli \T02h_s, \S02l_s, 64-62
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \S02l_s, 62-32
    xor  \T02h_s, \T02h_s, \S02h_s
    lw \T03l_s, 12*8(a0)
    lw \T03h_s, 12*8+4(a0)
    sw \T02l_s, 1*8(a0)
    sw \T02h_s, 1*8+4(a0)
    lw \T02l_s, 9*8(a0)
    lw \T02h_s, 9*8+4(a0)
    slli \S02l_s, \T03h_s, 43-32
    srli \T03h_s, \T03h_s, 64-43
    srli \S02h_s, \T03l_s, 64-43
    xor  \S02l_s, \S02l_s, \S02h_s
    slli \S02h_s, \T03l_s, 43-32
    xor  \S02h_s, \S02h_s, \T03h_s
    slli \T03l_s, \T02l_s, 20
    srli \T02l_s, \T02l_s, 32-20
    srli \T03h_s, \T02h_s, 32-20
    xor  \T03l_s, \T03l_s, \T03h_s
    slli \T03h_s, \T02h_s, 20
    xor  \T03h_s, \T03h_s, \T02l_s
    lw \T02l_s, 22*8(a0)
    lw \T02h_s, 22*8+4(a0)
    sw \T03l_s, 12*8(a0)
    sw \T03h_s, 12*8+4(a0)
    slli \T03h_s,  \T02l_s, 61-32
    srli \T02l_s, \T02l_s, 64-61
    slli \T03l_s, \T02h_s, 61-32
    xor  \T02l_s, \T02l_s, \T03l_s
    srli \T02h_s, \T02h_s, 64-61
    xor  \T02h_s, \T02h_s, \T03h_s
    sw \T02l_s, 9*8(a0)
    sw \T02h_s, 9*8+4(a0)
    slli \T03l_s, \S14h_s, 39-32
    srli \S14h_s, \S14h_s, 64-39
    srli \T03h_s, \S14l_s, 64-39
    xor  \T03l_s, \T03l_s, \T03h_s
    slli \T03h_s, \S14l_s, 39-32
    xor  \T03h_s, \T03h_s, \S14h_s
    lw \T02l_s, 20*8(a0)
    lw \T02h_s, 20*8+4(a0)
    sw \T03l_s, 22*8(a0)
    sw \T03h_s, 22*8+4(a0)
    slli \S14l_s, \T02l_s, 18
    srli \T02l_s, \T02l_s, 32-18
    srli \S14h_s, \T02h_s, 32-18
    xor  \S14l_s, \S14l_s, \S14h_s
    slli \S14h_s, \T02h_s, 18
    xor  \S14h_s, \S14h_s, \T02l_s
    slli \T02l_s, \S23h_s, 56-32
    srli \S23h_s, \S23h_s, 64-56
    srli \T02h_s, \S23l_s, 64-56
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \S23l_s, 56-32
    xor  \T02h_s, \T02h_s, \S23h_s
    lw \T03l_s, 15*8(a0)
    lw \T03h_s, 15*8+4(a0)
    sw \T02l_s, 20*8(a0)
    sw \T02h_s, 20*8+4(a0)
    slli \S23l_s, \T03h_s, 41-32
    srli \T03h_s, \T03h_s, 64-41
    srli \S23h_s, \T03l_s, 64-41
    xor  \S23l_s, \S23l_s, \S23h_s
    slli \S23h_s, \T03l_s, 41-32
    xor  \S23h_s, \S23h_s, \T03h_s  
    slli \T02l_s, \S04l_s, 27
    srli \S04l_s, \S04l_s, 32-27
    srli \T02h_s, \S04h_s, 32-27
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \S04h_s, 27
    xor  \T02h_s, \T02h_s, \S04l_s    
    lw \T03l_s, 24*8(a0)
    lw \T03h_s, 24*8+4(a0)
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    slli \S04l_s, \T03l_s, 14
    srli \T03l_s, \T03l_s, 32-14
    srli \S04h_s, \T03h_s, 32-14
    xor  \S04l_s, \S04l_s, \S04h_s
    slli \S04h_s, \T03h_s, 14
    xor  \S04h_s, \S04h_s, \T03l_s
    slli \T02l_s, \S17l_s, 15
    srli \S17l_s, \S17l_s, 32-15
    srli \T02h_s, \S17h_s, 32-15
    xor  \T02l_s, \T02l_s, \T02h_s
    slli \T02h_s, \S17h_s, 15
    xor  \T02h_s, \T02h_s, \S17l_s
    lw \T03l_s, 11*8(a0)
    lw \T03h_s, 11*8+4(a0)
    sw \T02l_s, 24*8(a0)
    sw \T02h_s, 24*8+4(a0)
    lw \T02h_s, 7*8(a0)
    lw \T02l_s, 7*8+4(a0)
    slli \S17l_s, \T03l_s, 10
    srli \T03l_s, \T03l_s, 32-10
    srli \S17h_s, \T03h_s, 32-10
    xor  \S17l_s, \S17l_s, \S17h_s
    slli \S17h_s, \T03h_s, 10
    xor  \S17h_s, \S17h_s, \T03l_s
    srli \T03h_s,   \T02h_s, 32-6
    slli \T02h_s, \T02h_s, 6
    srli \T03l_s,   \T02l_s, 32-6
    slli \T02l_s, \T02l_s, 6
    xor  \T02h_s, \T02h_s, \T03l_s
    xor  \T02l_s, \T02l_s, \T03h_s    
    lw \T03l_s, 19*8(a0)
    lw \T03h_s, 19*8+4(a0)
    sw \T02h_s, 11*8(a0)
    sw \T02l_s, 11*8+4(a0)
    srli \T02h_s,   \T03l_s, 32-8
    slli \T03l_s, \T03l_s, 8
    srli \T02l_s,   \T03h_s, 32-8
    slli \T03h_s, \T03h_s, 8
    xor  \T03l_s, \T03l_s, \T02l_s
    xor  \T03h_s, \T03h_s, \T02h_s    
    sw \T00l_s, 18*4(sp)
    sw \T00h_s, 19*4(sp)
    sw \T01l_s, 20*4(sp)
    sw \T01h_s, 21*4(sp)
    sw \T03l_s, 19*8(a0)
    sw \T03h_s, 19*8+4(a0)
    lw \T01l_s, 13*8(a0)
    lw \T01h_s, 13*8+4(a0)
    lw \T00l_s, 12*8(a0)
    lw \T00h_s, 12*8+4(a0)
    and \T03h_s, \T01h_s, \S08h_s
    and \T03l_s, \T01l_s, \S08l_s
    xor \T03h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T00l_s, \T03l_s
    lw \T02l_s, 9*8(a0)
    lw \T02h_s, 9*8+4(a0)
    sw \T03l_s, 6*8(a0)
    sw \T03h_s, 6*8+4(a0)
    not \T03h_s, \T02h_s
    not \T03l_s, \T02l_s
    or \T03h_s, \T03h_s, \S08h_s
    or \T03l_s, \T03l_s, \S08l_s
    xor \T03h_s, \T01h_s, \T03h_s
    xor \T03l_s, \T01l_s, \T03l_s
    sw \T03l_s, 7*8(a0)
    sw \T03h_s, 7*8+4(a0)
    or \T03h_s, \T02h_s, \S05h_s
    or \T03l_s, \T02l_s, \S05l_s
    xor \S08h_s, \S08h_s, \T03h_s
    xor \S08l_s, \S08l_s, \T03l_s
    and \T03h_s, \S05h_s, \T00h_s
    and \T03l_s, \S05l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T03h_s
    xor \T02l_s, \T02l_s, \T03l_s
    sw \T02l_s, 9*8(a0)
    or  \T03l_s, \T00l_s, \T01l_s
    sw \T02h_s, 9*8+4(a0)
    or  \T03h_s, \T00h_s, \T01h_s
    lw \T01l_s, 19*8(a0)
    xor \S05h_s, \S05h_s, \T03h_s
    lw \T01h_s, 19*8+4(a0)
    xor \S05l_s, \S05l_s, \T03l_s
    lw \T02l_s, 11*8(a0)
    lw \T02h_s, 11*8+4(a0)
    lw \T00l_s, 18*8(a0)
    lw \T00h_s, 18*8+4(a0)
    not \T03h_s, \T01h_s
    not \T03l_s, \T01l_s
    and \T03h_s, \T03h_s, \S14h_s
    and \T03l_s, \T03l_s, \S14l_s
    xor \T03h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T00l_s, \T03l_s
    sw \T03l_s, 12*8(a0)
    sw \T03h_s, 12*8+4(a0)
    not \T04_s, \T01h_s
    or  \T03h_s, \S14h_s, \S10h_s
    xor \T03h_s, \T03h_s, \T04_s
    not \T04_s, \T01l_s
    or  \T03l_s, \S14l_s, \S10l_s
    xor \T03l_s, \T03l_s, \T04_s
    sw \T03l_s, 13*8(a0)
    sw \T03h_s, 13*8+4(a0)
    and \T03h_s, \S10h_s, \T02h_s
    and \T03l_s, \S10l_s, \T02l_s
    xor \S14h_s, \S14h_s, \T03h_s
    xor \S14l_s, \S14l_s, \T03l_s
    or \T03h_s, \T02h_s, \T00h_s
    or \T03l_s, \T02l_s, \T00l_s
    xor \S10h_s, \S10h_s, \T03h_s
    xor \S10l_s, \S10l_s, \T03l_s
    and \T03h_s, \T00h_s, \T01h_s
    and \T03l_s, \T00l_s, \T01l_s
    xor \T02h_s, \T02h_s, \T03h_s
    xor \T02l_s, \T02l_s, \T03l_s
    lw \T01l_s, 20*8(a0)
    lw \T01h_s, 20*8+4(a0)
    sw \T02l_s, 11*8(a0)
    sw \T02h_s, 11*8+4(a0)
    lw \T00l_s, 24*8(a0)
    lw \T00h_s, 24*8+4(a0)
    lw \T02l_s, 15*8(a0)
    lw \T02h_s, 15*8+4(a0)
    not \T04_s, \T00h_s
    and \T03h_s, \T01h_s, \T02h_s
    xor \T03h_s, \T03h_s, \T04_s
    not \T04_s, \T00l_s
    and \T03l_s, \T01l_s, \T02l_s
    xor \T03l_s, \T03l_s, \T04_s
    sw \T03l_s, 18*8(a0)
    sw \T03h_s, 18*8+4(a0)
    or \T03h_s, \T02h_s, \S16h_s
    or \T03l_s, \T02l_s, \S16l_s
    xor \T03h_s, \T01h_s, \T03h_s
    xor \T03l_s, \T01l_s, \T03l_s
    sw \T03l_s, 19*8(a0)
    sw \T03h_s, 19*8+4(a0)
    and \T03h_s, \S16h_s, \S17h_s
    and \T03l_s, \S16l_s, \S17l_s
    xor \T02h_s, \T02h_s, \T03h_s
    xor \T02l_s, \T02l_s, \T03l_s
    sw \T02l_s, 15*8(a0)
    sw \T02h_s, 15*8+4(a0)
    or  \T03h_s, \S17h_s, \T00h_s
    or  \T03l_s, \S17l_s, \T00l_s
    xor \S16h_s, \S16h_s, \T03h_s
    xor \S16l_s, \S16l_s, \T03l_s
    lw \T02l_s, 22*8(a0)
    not \T03h_s, \T00h_s
    lw \T02h_s, 22*8+4(a0)
    not \T03l_s, \T00l_s
    lw \T00l_s, 0*8(a0)
    or  \T03h_s, \T03h_s, \T01h_s
    lw \T00h_s, 0*8+4(a0)
    or  \T03l_s, \T03l_s, \T01l_s
    lw \T01l_s, 1*8(a0)
    xor \S17h_s, \S17h_s, \T03h_s
    lw \T01h_s, 1*8+4(a0)
    xor \S17l_s, \S17l_s, \T03l_s
    and \T03h_s, \T01h_s, \S21h_s
    and \T03l_s, \T01l_s, \S21l_s
    xor \T03h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T00l_s, \T03l_s
    sw \T03l_s, 24*8(a0)
    sw \T03h_s, 24*8+4(a0)
    not \T03h_s, \S21h_s
    not \T03l_s, \S21l_s
    and \T03h_s, \T03h_s, \T02h_s
    and \T03l_s, \T03l_s, \T02l_s
    xor \T03h_s, \T01h_s, \T03h_s
    xor \T03l_s, \T01l_s, \T03l_s
    sw \T03l_s, 20*8(a0)
    sw \T03h_s, 20*8+4(a0)
    not \T04_s, \S21h_s
    or  \T03h_s, \T02h_s, \S23h_s
    xor \S21h_s, \T03h_s, \T04_s
    not \T04_s, \S21l_s
    or  \T03l_s, \T02l_s, \S23l_s
    xor \S21l_s, \T03l_s, \T04_s
    and \T03h_s, \S23h_s, \T00h_s
    and \T03l_s, \S23l_s, \T00l_s
    xor \T02h_s, \T02h_s, \T03h_s
    xor \T02l_s, \T02l_s, \T03l_s
    sw \T02l_s, 22*8(a0)
    or  \T03l_s, \T00l_s, \T01l_s
    sw \T02h_s, 22*8+4(a0)
    or  \T03h_s, \T00h_s, \T01h_s
    lw \T00l_s, 18*4(sp)
    xor \S23h_s, \S23h_s, \T03h_s
    lw \T00h_s, 19*4(sp)
    xor \S23l_s, \S23l_s, \T03l_s
    lw \T01l_s, 20*4(sp)
    lw \T01h_s, 21*4(sp)
    or  \T03h_s, \T01h_s, \S02h_s
    or  \T03l_s, \T01l_s, \S02l_s
    xor \T03h_s, \T00h_s, \T03h_s
    xor \T03l_s, \T00l_s, \T03l_s
    lw \T04_s, 17*4(sp)
    lw \T02l_s, 0(\T04_s)
    lw \T02h_s, 4(\T04_s)
    addi \T04_s, \T04_s, 8
    sw  \T04_s, 17*4(sp)
    xor \T03h_s, \T03h_s, \T02h_s
    xor \T03l_s, \T03l_s, \T02l_s
    lw \T02l_s, 3*8(a0)
    lw \T02h_s, 3*8+4(a0)
    sw \T03l_s, 0*8(a0)
    sw \T03h_s, 0*8+4(a0)
    not \T03h_s, \S02h_s
    not \T03l_s, \S02l_s
    or \T03h_s, \T03h_s, \T02h_s
    or \T03l_s, \T03l_s, \T02l_s
    xor \T03h_s, \T01h_s, \T03h_s
    xor \T03l_s, \T01l_s, \T03l_s
    sw \T03l_s, 1*8(a0)
    sw \T03h_s, 1*8+4(a0)
    and \T03h_s, \T02h_s, \S04h_s
    and \T03l_s, \T02l_s, \S04l_s
    xor \S02h_s, \S02h_s, \T03h_s
    xor \S02l_s, \S02l_s, \T03l_s
    or  \T03h_s, \S04h_s, \T00h_s
    or  \T03l_s, \S04l_s, \T00l_s
    xor \T03h_s, \T02h_s, \T03h_s
    xor \T03l_s, \T02l_s, \T03l_s
    sw \T03l_s, 3*8(a0)
    sw \T03h_s, 3*8+4(a0)
    and \T03h_s, \T00h_s, \T01h_s
    and \T03l_s, \T00l_s, \T01l_s
    xor \S04h_s, \S04h_s, \T03h_s
    xor \S04l_s, \S04l_s, \T03l_s
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
    SaveRegs
    la tp, constants_keccak
    sw tp, 17*4(sp)

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
    
    lw tp, 16*4(sp)
    addi tp, tp, -1
    bnez tp, loop_start

    FinalStore \
        a1, a2, a3, a4, a5, a6, a7, t0, t1, t2, \
        t3, t4, t5, t6, s0, s1, s2, s3, s4, s5, \
        s6, s7, s8, s9, s10,s11,ra, gp, tp

    RestoreRegs
    addi sp, sp, 4*28
    ret
// Bit-interleaving helpers from Alexandre Adomnicai's Armv7-M Keccak
// (https://github.com/aadomn/keccak_armv7m, CC0-1.0), with the macro
// parameters instantiated so the blocks can be scheduled directly.
//
// These turn a 64-bit lane into the two 32-bit words a bit-interleaved
// Keccak state keeps, and back. They exercise `and` with an immediate,
// `lsr`, `bfi`, `bfc` and register-to-register `movs`.
//
// Contributed by the UFCG team of the CISSA project, at the Universidade
// Federal de Campina Grande, Brazil, with the EMBRAPII CESAR Competence
// Centre in Cybersecurity.

.syntax unified
.thumb

.global to_bit_interleaving
.type to_bit_interleaving, %function
.align 2
to_bit_interleaving:
slothy_start_to:
        and     r4, r0, #0x55555555
        orr     r4, r4, r4, lsr #1
        and     r4, r4, #0x33333333
        orr     r4, r4, r4, lsr #2
        and     r4, r4, #0x0F0F0F0F
        orr     r4, r4, r4, lsr #4
        and     r4, r4, #0x00FF00FF
        bfi     r4, r4, #8, #8
        eor     r2, r2, r4, lsr #8
        and     r4, r1, #0x55555555
        orr     r4, r4, r4, lsr #1
        and     r4, r4, #0x33333333
        orr     r4, r4, r4, lsr #2
        and     r4, r4, #0x0F0F0F0F
        orr     r4, r4, r4, lsr #4
        and     r4, r4, #0x00FF00FF
        orr     r4, r4, r4, lsr #8
        eor     r2, r2, r4, lsl #16
        and     r4, r0, #0xAAAAAAAA
        orr     r4, r4, r4, lsl #1
        and     r4, r4, #0xCCCCCCCC
        orr     r4, r4, r4, lsl #2
        and     r4, r4, #0xF0F0F0F0
        orr     r4, r4, r4, lsl #4
        and     r4, r4, #0xFF00FF00
        orr     r4, r4, r4, lsl #8
        eor     r3, r3, r4, lsr #16
        and     r4, r1, #0xAAAAAAAA
        orr     r4, r4, r4, lsl #1
        and     r4, r4, #0xCCCCCCCC
        orr     r4, r4, r4, lsl #2
        and     r4, r4, #0xF0F0F0F0
        orr     r4, r4, r4, lsl #4
        and     r4, r4, #0xFF00FF00
        orr     r4, r4, r4, lsl #8
        bfc     r4, #0, #16
        eors    r3, r3, r4
slothy_end_to:
        bx lr
.size to_bit_interleaving, .-to_bit_interleaving

.global from_bit_interleaving
.type from_bit_interleaving, %function
.align 2
from_bit_interleaving:
slothy_start_from:
        movs r2, r0
        bfi  r0, r1, #16, #16
        bfc  r1, #0, #16
        orr  r1, r1, r2, lsr #16
        eor  r2, r0, r0, lsr #8
        and  r2, #0x0000FF00
        eors r0, r0, r2
        eor  r0, r0, r2, lsl #8
        eor  r2, r0, r0, lsr #4
        and  r2, #0x00F000F0
        eors r0, r0, r2
        eor  r0, r0, r2, lsl #4
        eor  r2, r0, r0, lsr #2
        and  r2, #0x0C0C0C0C
        eors r0, r0, r2
        eor  r0, r0, r2, lsl #2
        eor  r2, r0, r0, lsr #1
        and  r2, #0x22222222
        eors r0, r0, r2
        eor  r0, r0, r2, lsl #1
        eor  r2, r1, r1, lsr #8
        and  r2, #0x0000FF00
        eors r1, r1, r2
        eor  r1, r1, r2, lsl #8
        eor  r2, r1, r1, lsr #4
        and  r2, #0x00F000F0
        eors r1, r1, r2
        eor  r1, r1, r2, lsl #4
        eor  r2, r1, r1, lsr #2
        and  r2, #0x0C0C0C0C
        eors r1, r1, r2
        eor  r1, r1, r2, lsl #2
        eor  r2, r1, r1, lsr #1
        and  r2, #0x22222222
        eors r1, r1, r2
        eor  r1, r1, r2, lsl #1
slothy_end_from:
        bx lr
.size from_bit_interleaving, .-from_bit_interleaving


 .syntax unified
 .thumb
// Curve25519 scalar multiplication
// Copyright (c) 2017, Emil Lenngren

// All rights reserved.

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// 1. Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.

// 2. Redistributions in binary form, except as embedded into a Nordic
// Semiconductor ASA or Dialog Semiconductor PLC integrated circuit in a product
// or a software update for such product, must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



// This is an armv7 implementation of X25519.
// It follows the reference implementation where the representation of
// a field element [0..2^255-19) is represented by a 256-bit little ian integer,
// reduced modulo 2^256-38, and may possibly be in the range [2^256-38..2^256).
// The scalar is a 256-bit integer where certain bits are hardcoded per specification.

// The implementation runs in constant time (548 873 cycles on ARM Cortex-M4,
// assuming no wait states), and no conditional branches or memory access
// pattern dep on secret data.

 .text
 .align 2

// input: *r8=a, *r9=b
// output: r0-r7
// clobbers all other registers
// cycles: 45
 .type fe25519_add_opt_m7, %function
 .global fe25519_add_opt_m7
fe25519_add_opt_m7:

slothy_start:
 ldr r0, [r8, #28]
 ldr r4, [r9, #28]
 adds r0, r0, r4
 mov r11,#0
 adc r11,r11,r11
 lsl r11, r11, #1
 add r11, r11, r0, lsr #31
 movs r7,#19
 mul r11, r11, r7
 bic r7,r0,#0x80000000
ldr r3, [r8, #12]
ldr r2, [r8, #8]
ldr r1, [r8, #4]
ldr r0, [r8], #16
ldr r10, [r9, #12]
ldr r6, [r9, #8]
ldr r5, [r9, #4]
ldr r4, [r9], #16
 mov r12,#1
 umaal r0,r11,r12,r4
 umaal r1,r11,r12,r5
 umaal r2,r11,r12,r6
 umaal r3,r11,r12,r10
ldr r4, [r9, #0]
ldr r5, [r9, #4]
ldr r6, [r9, #8]
ldr r9, [r8, #4]
ldr r10, [r8, #8]
ldr r8, [r8, #0]
 umaal r4,r11,r12,r8
 umaal r5,r11,r12,r9
 umaal r6,r11,r12,r10
 add r7, r7, r11
slothy_end:

 bx lr



// void fe25519_add_wrap(uint32_t *out, uint32_t *a, uint32_t *b)
// out = r0, a=r1, b=r2
 .align 2
 .type fe25519_add_opt_m7_wrap, %function
 .global fe25519_add_opt_m7_wrap
fe25519_add_opt_m7_wrap:
    push {r4-r11, lr}
    push {r0}

 mov r8, r1
 mov r9, r2

 bl fe25519_add
 pop {r8}

 str r0, [r8, #0]
 str r1, [r8, #4]
 str r2, [r8, #8]
 str r3, [r8, #12]
 str r4, [r8, #16]
 str r5, [r8, #20]
 str r6, [r8, #24]
 str r7, [r8, #28]

    pop {r4-r11, lr}
 bx lr
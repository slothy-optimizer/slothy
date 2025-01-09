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
// cycles: 173
 .type fe25519_mul_opt_m7, %function
fe25519_mul_opt_m7:
 .global fe25519_mul_opt_m7

 push {r2,lr}

 // frame push {lr}
 // frame address sp,8

 sub sp,#28

slothy_start:
ldr r3, [r2, #4]
ldr r4, [r2, #8]
ldr r5, [r2, #12]
ldr r2, [r2, #0]
ldr r14, [r1, #8]
ldr r10, [r1, #4]
ldr r0, [r1], #12
 umull r6,r11,r2,r0
 umull r7,r12,r3,r0
 umaal r7,r11,r2,r10
 push {r6,r7}// @slothy:writes=['stack1', 'stack2']
 umull r8,r6,r4,r0
 umaal r8,r11,r3,r10
 umull r9,r7,r5,r0
 umaal r9,r11,r4,r10
 umaal r11,r7,r5,r10
 umaal r8,r12,r2,r14
 umaal r9,r12,r3,r14
 umaal r11,r12,r4,r14
 umaal r12,r7,r5,r14
ldr r14, [r1, #8]
ldr r10, [r1, #4]
ldr r0, [r1], #12
 umaal r9,r6,r2,r0
 umaal r11,r6,r3,r0
 umaal r12,r6,r4,r0
 umaal r6,r7,r5,r0
 strd r8,r9,[sp,#8]// @slothy:writes=['stack3', 'stack4']
 mov r9,#0
 umaal r11,r9,r2,r10
 umaal r12,r9,r3,r10
 umaal r6,r9,r4,r10
 umaal r7,r9,r5,r10
 mov r10,#0
 umaal r12,r10,r2,r14
 umaal r6,r10,r3,r14
 umaal r7,r10,r4,r14
 umaal r9,r10,r5,r14
 ldr r8, [r1], #4
 mov r14,#0
 umaal r14,r6,r2,r8
 umaal r7,r6,r3,r8
 umaal r9,r6,r4,r8
 umaal r10,r6,r5,r8
 ldr r8, [r1], #-28
 mov r0,#0
 umaal r7,r0,r2,r8
 umaal r9,r0,r3,r8
 umaal r10,r0,r4,r8
 umaal r6,r0,r5,r8
 push {r0}// @slothy:writes=['stack0']
 ldr r2, [sp, #40]
 adds r2,r2,#16
ldr r3, [r2, #4]
ldr r4, [r2, #8]
ldr r5, [r2, #12]
ldr r2, [r2, #0]
 ldr r8, [r1], #4
 mov r0,#0
 umaal r11,r0,r2,r8
 str r11, [sp, #20]// @slothy:writes=['stack5']
 umaal r12,r0,r3,r8
 umaal r14,r0,r4,r8
 umaal r0,r7,r5,r8// 7=carry for 9
 ldr r8, [r1], #4
 mov r11,#0
 umaal r12,r11,r2,r8
 str r12, [sp, #24]// @slothy:writes=['stack6']
 umaal r14,r11,r3,r8
 umaal r0,r11,r4,r8
 umaal r11,r7,r5,r8// 7=carry for 10
 ldr r8, [r1], #4
 mov r12,#0
 umaal r14,r12,r2,r8
 str r14, [sp, #28]// @slothy:writes=['stack7']
 umaal r0,r12,r3,r8
 umaal r11,r12,r4,r8
 umaal r10,r12,r5,r8// 12=carry for 6
 ldr r8, [r1], #4
 mov r14,#0
 umaal r0,r14,r2,r8
 str r0, [sp, #32]// @slothy:writes=['stack8']
 umaal r11,r14,r3,r8
 umaal r10,r14,r4,r8
 umaal r6,r14,r5,r8// lr=carry for saved
ldr r8, [r1, #4]
ldr r0, [r1], #8
 umaal r11,r9,r2,r0
 str r11, [sp, #36]// @slothy:writes=['stack9']
 umaal r9,r10,r3,r0
 umaal r10,r6,r4,r0
 pop {r11}// @slothy:reads=['stack0']
 umaal r11,r6,r5,r0// 6=carry for next
 umaal r9,r7,r2,r8
 umaal r10,r7,r3,r8
 umaal r11,r7,r4,r8
 umaal r6,r7,r5,r8
ldr r8, [r1, #4]
ldr r0, [r1], #8
 umaal r10,r12,r2,r0
 umaal r11,r12,r3,r0
 umaal r6,r12,r4,r0
 umaal r7,r12,r5,r0
 umaal r11,r14,r2,r8
 umaal r6,r14,r3,r8
 umaal r14,r7,r4,r8
 umaal r7,r12,r5,r8
 ldrd r4,r5,[sp,#28]// @slothy:reads=['stack8', 'stack9']
 movs r3,#38
 mov r8,#0
 umaal r4,r8,r3,r12
 lsl r8, r8, #1
 orr r8, r8, r4, lsr #31
 and r12,r4,#0x7fffffff
 movs r4,#19
 mul r8, r8, r4
 pop {r0,r1,r2}// @slothy:reads=['stack1', 'stack2', 'stack3']
 umaal r0,r8,r3,r5
 umaal r1,r8,r3,r9
 umaal r2,r8,r3,r10
 mov r9,#38
 pop {r3,r4}// @slothy:reads=['stack4', 'stack5']
 umaal r3,r8,r9,r11
 umaal r4,r8,r9,r6
 pop {r5,r6}// @slothy:reads=['stack6', 'stack7']
 umaal r5,r8,r9,r14
 umaal r6,r8,r9,r7
 add r7, r8, r12
slothy_end:

 add sp,#12
 // frame address sp,4

 pop {pc}



// void fe25519_mul_wrap(uint32_t *out, uint32_t *a, uint32_t *b)
// out = r0, a=r1, b=r2
 .align 2
 .type fe25519_mul_opt_m7_wrap, %function
 .global fe25519_mul_opt_m7_wrap
fe25519_mul_opt_m7_wrap:
    push {r4-r11, lr}
    push {r0}

 mov r8, r1
 mov r9, r2

 bl fe25519_mul
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
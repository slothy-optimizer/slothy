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


 .text
 .align 2


fe25519_sub_opt_m7:
 .type fe25519_sub_opt_m7, %function
 .global fe25519_sub_opt_m7
slothy_start:
ldr r0, [r8, #0]
ldr r1, [r8, #4]
ldr r2, [r8, #8]
ldr r3, [r8, #12]
ldr r4, [r8, #16]
ldr r5, [r8, #20]
ldr r6, [r8, #24]
ldr r7, [r8, #28]
ldr r12, [r9, #12]
ldr r11, [r9, #8]
ldr r10, [r9, #4]
ldr r8, [r9], #16
 subs r0,r8
 sbcs r1,r10
 sbcs r2,r11
 sbcs r3,r12
ldr r8, [r9, #0]
ldr r10, [r9, #8]
ldr r11, [r9, #12]
ldr r9, [r9, #4]
 sbcs r4,r8
 sbcs r5,r9
 sbcs r6,r10
 sbcs r7,r11
 sbc r8,r8
 and r9,r8,#-38
 adds r0,r9
 adcs r1,r8
 adcs r2,r8
 adcs r3,r8
 adcs r4,r8
 adcs r5,r8
 adcs r6,r8
 adcs r7,r8
 adcs r8,#0
 and r9,r8,#-38
 adds r0,r9
slothy_end:

 bx lr



// void fe25519_sub_wrap(uint32_t *out, uint32_t *a, uint32_t *b)
// out = r0, a=r1, b=r2
 .align 2
 .type fe25519_sub_opt_m7_wrap, %function
 .global fe25519_sub_opt_m7_wrap
fe25519_sub_opt_m7_wrap:
    push {r4-r11, lr}
    push {r0}

 mov r8, r1
 mov r9, r2

 bl fe25519_sub
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
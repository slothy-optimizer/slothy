	.syntax unified
	.thumb
// Curve25519 scalar multiplication
// Copyright (c) 2017, Emil Lenngren
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form, except as embedded into a Nordic
//    Semiconductor ASA or Dialog Semiconductor PLC integrated circuit in a product
//    or a software update for such product, must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
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


fe25519_sub:
	.type fe25519_sub, %function
	.global fe25519_sub
slothy_start:
	ldm r8, {r0-r7}
	ldm r9!,{r8,r10-r12}
	subs r0,r8
	sbcs r1,r10
	sbcs r2,r11
	sbcs r3,r12
	ldm r9,{r8-r11}
	sbcs r4,r8
	sbcs r5,r9
	sbcs r6,r10
	sbcs r7,r11

	// if subtraction goes below 0, set r8 to -1 and r9 to -38, else set both to 0s
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

	// if the subtraction did not go below 0, we are done and (r8,r9) are set to 0
	// if the subtraction went below 0 and the addition overflowed, we are done, so set (r8,r9) to 0
	// if the subtraction went below 0 and the addition did not overflow, we need to add once more
	// (r8,r9) will be correctly set to (-1,-38) only when r8 was -1 and we don't have a carry,
	// note that the carry will always be 0 in case (r8,r9) was (0,0) since then there was no real addition
	// also note that it is extremely unlikely we will need an extra addition:
	//   that can only happen if input1 was slightly >= 0 and input2 was > 2^256-38 (really input2-input1 > 2^256-38)
	//   in that case we currently have 2^256-38 < (r0...r7) < 2^256, so adding -38 will only affect r0
	adcs r8,#0
	and r9,r8,#-38

	adds r0,r9
slothy_end:
	bx lr



// void fe25519_sub_wrap(uint32_t *out, uint32_t *a, uint32_t *b)
// out = r0, a=r1, b=r2
	.align 2
	.type fe25519_sub_wrap, %function
	.global fe25519_sub_wrap
fe25519_sub_wrap:
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
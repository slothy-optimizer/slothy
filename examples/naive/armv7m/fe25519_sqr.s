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


// This is an armv7 implementation of X25519.
// It follows the reference implementation where the representation of
// a field element [0..2^255-19) is represented by a 256-bit little ian integer,
// reduced modulo 2^256-38, and may possibly be in the range [2^256-38..2^256).
// The scalar is a 256-bit integer where certain bits are hardcoded per specification.
//
// The implementation runs in constant time (548 873 cycles on ARM Cortex-M4,
// assuming no wait states), and no conditional branches or memory access
// pattern dep on secret data.

	.text
	.align 2

// input/result in (r0-r7)
// clobbers all other registers
// cycles: 115
	.type fe25519_sqr, %function
fe25519_sqr:
	.global fe25519_sqr
	push {lr}

	//frame push {lr}
	sub sp,#20 
	//frame address sp,24
slothy_start:	
	//mul 01, 00
	umull r9,r10,r0,r0
	umull r11,r12,r0,r1
	adds r11,r11,r11
	mov lr,#0
	umaal r10,r11,lr,lr
	
	//r9 r10 done
	//r12 carry for 3rd before col
	//r11+C carry for 3rd final col
	
	push {r9,r10} //@slothy:writes=[stack0,stack1]
	//frame address sp,32
	
	//mul 02, 11
	mov r8,#0
	umaal r8,r12,r0,r2
	adcs r8,r8,r8
	umaal r8,r11,r1,r1
	
	//r8 done (3rd col)
	//r12 carry for 4th before col
	//r11+C carry for 4th final col
	
	//mul 03, 12
	umull r9,r10,r0,r3
	umaal r9,r12,r1,r2
	adcs r9,r9,r9
	umaal r9,r11,lr,lr
	
	//r9 done (4th col)
	//r10+r12 carry for 5th before col
	//r11+C carry for 5th final col
	
	strd r8,r9,[sp,#8] //@slothy:writes=[stack2,stack3]
	
	//mul 04, 13, 22
	mov r9,#0
	umaal r9,r10,r0,r4
	umaal r9,r12,r1,r3
	adcs r9,r9,r9
	umaal r9,r11,r2,r2
	
	//r9 done (5th col)
	//r10+r12 carry for 6th before col
	//r11+C carry for 6th final col
	
	str r9,[sp,#16] //@slothy:writes=[stack4]
	
	//mul 05, 14, 23
	umull r9,r8,r0,r5
	umaal r9,r10,r1,r4
	umaal r9,r12,r2,r3
	adcs r9,r9,r9
	umaal r9,r11,lr,lr
	
	//r9 done (6th col)
	//r10+r12+r8 carry for 7th before col
	//r11+C carry for 7th final col
	
	str r9,[sp,#20] //@slothy:writes=[stack5]
	
	//mul 06, 15, 24, 33
	mov r9,#0
	umaal r9,r8,r1,r5
	umaal r9,r12,r2,r4
	umaal r9,r10,r0,r6
	adcs r9,r9,r9
	umaal r9,r11,r3,r3
	
	//r9 done (7th col)
	//r8+r10+r12 carry for 8th before col
	//r11+C carry for 8th final col
	
	str r9,[sp,#24] //@slothy:writes=[stack6]
	
	//mul 07, 16, 25, 34
	umull r0,r9,r0,r7
	umaal r0,r10,r1,r6
	umaal r0,r12,r2,r5
	umaal r0,r8,r3,r4
	adcs r0,r0,r0
	umaal r0,r11,lr,lr
	
	//r0 done (8th col)
	//r9+r8+r10+r12 carry for 9th before col
	//r11+C carry for 9th final col
	
	//mul 17, 26, 35, 44
	umaal r9,r8,r1,r7 //r1 is now dead
	umaal r9,r10,r2,r6
	umaal r12,r9,r3,r5
	adcs r12,r12,r12
	umaal r11,r12,r4,r4
	
	//r11 done (9th col)
	//r8+r10+r9 carry for 10th before col
	//r12+C carry for 10th final col
	
	//mul 27, 36, 45
	umaal r9,r8,r2,r7 //r2 is now dead
	umaal r10,r9,r3,r6
	movs r2,#0
	umaal r10,r2,r4,r5
	adcs r10,r10,r10
	umaal r12,r10,lr,lr
	
	//r12 done (10th col)
	//r8+r9+r2 carry for 11th before col
	//r10+C carry for 11th final col
	
	//mul 37, 46, 55
	umaal r2,r8,r3,r7 //r3 is now dead
	umaal r9,r2,r4,r6
	adcs r9,r9,r9
	umaal r10,r9,r5,r5
	
	//r10 done (11th col)
	//r8+r2 carry for 12th before col
	//r9+C carry for 12th final col
	
	//mul 47, 56
	movs r3,#0
	umaal r3,r8,r4,r7 //r4 is now dead
	umaal r3,r2,r5,r6
	adcs r3,r3,r3
	umaal r9,r3,lr,lr
	
	//r9 done (12th col)
	//r8+r2 carry for 13th before col
	//r3+C carry for 13th final col
	
	//mul 57, 66
	umaal r8,r2,r5,r7 //r5 is now dead
	adcs r8,r8,r8
	umaal r3,r8,r6,r6
	
	//r3 done (13th col)
	//r2 carry for 14th before col
	//r8+C carry for 14th final col
	
	//mul 67
	umull r4,r5,lr,lr // set 0
	umaal r4,r2,r6,r7
	adcs r4,r4,r4
	umaal r4,r8,lr,lr
	
	//r4 done (14th col)
	//r2 carry for 15th before col
	//r8+C carry for 15th final col
	
	//mul 77
	adcs r2,r2,r2
	umaal r8,r2,r7,r7
	adcs r2,r2,lr
	
	//r8 done (15th col)
	//r2 done (16th col)
	
	//msb -> lsb: r2 r8 r4 r3 r9 r10 r12 r11 r0 sp+24 sp+20 sp+16 sp+12 sp+8 sp+4 sp
	//lr: 0
	//now do reduction
	
	mov r6,#38
	umaal r0,lr,r6,r2
	lsl lr,lr,#1
	orr lr,lr,r0, lsr #31
	and r7,r0,#0x7fffffff
	movs r5,#19
	mul lr,lr,r5
	
	pop {r0,r1} //@slothy:reads=[stack0,stack1]
	//frame address sp,24
	umaal r0,lr,r6,r11
	umaal r1,lr,r6,r12
	
	mov r11,r3
	mov r12,r4
	
	pop {r2,r3,r4,r5} //@slothy:reads=[stack2,stack3,stack4,stack5] 
	//frame address sp,8
	umaal r2,lr,r6,r10
	umaal r3,lr,r6,r9
	
	umaal r4,lr,r6,r11
	umaal r5,lr,r6,r12
	
	pop {r6} //@slothy:reads=[stack6]
	//frame address sp,4
	mov r12,#38
	umaal r6,lr,r12,r8
	add r7,r7,lr
slothy_end:	
	pop {pc}
	


// void fe25519_sqr_wrap(uint32_t *out)
	.align 2
	.type fe25519_sqr_wrap, %function
	.global fe25519_sqr_wrap
fe25519_sqr_wrap:
    push {r4-r11, lr}
    push {r0}
	
	ldr r1, [r0, #4] 
	ldr r2, [r0, #8]
	ldr r3, [r0, #12]
	ldr r4, [r0, #16]
	ldr r5, [r0, #20]
	ldr r6, [r0, #24]
	ldr r7, [r0, #28]
	ldr r0, [r0] 

	bl fe25519_sqr
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
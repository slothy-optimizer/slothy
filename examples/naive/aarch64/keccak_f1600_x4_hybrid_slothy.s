/*
 * Copyright (c) 2021-2022 Arm Limited
 * Copyright (c) 2022 Matthias Kannwischer
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
#include <hal_env.h>

//
// Author: Hanno Becker <hanno.becker@arm.com>
// Author: Matthias Kannwischer <matthias@kannwischer.eu>
//

.macro asm_load dst // @slothy:no-unfold
    ASM_LOAD(\dst, round_constants)
.endm

/********************** CONSTANTS *************************/
    .data
    .align(8)
round_constants:
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

/****************** REGISTER ALLOCATIONS *******************/

    input_addr     .req x0
    const_addr     .req x29
    count          .req w27
    cur_const      .req x26

    /* Mapping of Kecck-f1600 SIMD state to vector registers
     * at the beginning and end of each round. */

    vAba     .req v0
    vAbe     .req v1
    vAbi     .req v2
    vAbo     .req v3
    vAbu     .req v4
    vAga     .req v5
    vAge     .req v6
    vAgi     .req v7
    vAgo     .req v8
    vAgu     .req v9
    vAka     .req v10
    vAke     .req v11
    vAki     .req v12
    vAko     .req v13
    vAku     .req v14
    vAma     .req v15
    vAme     .req v16
    vAmi     .req v17
    vAmo     .req v18
    vAmu     .req v19
    vAsa     .req v20
    vAse     .req v21
    vAsi     .req v22
    vAso     .req v23
    vAsu     .req v24

    /* q-form of the above mapping */
    vAbaq    .req q0
    vAbeq    .req q1
    vAbiq    .req q2
    vAboq    .req q3
    vAbuq    .req q4
    vAgaq    .req q5
    vAgeq    .req q6
    vAgiq    .req q7
    vAgoq    .req q8
    vAguq    .req q9
    vAkaq    .req q10
    vAkeq    .req q11
    vAkiq    .req q12
    vAkoq    .req q13
    vAkuq    .req q14
    vAmaq    .req q15
    vAmeq    .req q16
    vAmiq    .req q17
    vAmoq    .req q18
    vAmuq    .req q19
    vAsaq    .req q20
    vAseq    .req q21
    vAsiq    .req q22
    vAsoq    .req q23
    vAsuq    .req q24

    /* C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4],   for x in 0..4 */
    C0 .req v30
    C1 .req v29
    C2 .req v28
    C3 .req v27
    C4 .req v26

    /* E[x] = C[x-1] xor rot(C[x+1],1), for x in 0..4 */
    E0 .req v26
    E1 .req v25
    E2 .req v29
    E3 .req v28
    E4 .req v27

    /* A_[y,2*x+3*y] = rot(A[x,y]) */
    vAbi_ .req v2
    vAbo_ .req v3
    vAbu_ .req v4
    vAga_ .req v10
    vAge_ .req v11
    vAgi_ .req v7
    vAgo_ .req v8
    vAgu_ .req v9
    vAka_ .req v15
    vAke_ .req v16
    vAki_ .req v12
    vAko_ .req v13
    vAku_ .req v14
    vAma_ .req v20
    vAme_ .req v21
    vAmi_ .req v17
    vAmo_ .req v18
    vAmu_ .req v19
    vAsa_ .req v0
    vAse_ .req v1
    vAsi_ .req v22
    vAso_ .req v23
    vAsu_ .req v24
    vAba_ .req v30
    vAbe_ .req v27

    /* Unused temporary */
    vtmp .req v31

    /* Mapping of Kecck-f1600 state to scalar registers
     * at the beginning and end of each round. */
    s_Aba     .req x1
    sAbe     .req x6
    sAbi     .req x11
    sAbo     .req x16
    sAbu     .req x21
    sAga     .req x2
    sAge     .req x7
    sAgi     .req x12
    sAgo     .req x17
    sAgu     .req x22
    sAka     .req x3
    sAke     .req x8
    sAki     .req x13
    sAko     .req x18
    sAku     .req x23
    sAma     .req x4
    sAme     .req x9
    sAmi     .req x14
    sAmo     .req x19
    sAmu     .req x24
    sAsa     .req x5
    sAse     .req x10
    sAsi     .req x15
    sAso     .req x20
    sAsu     .req x25

    /* sA_[y,2*x+3*y] = rot(A[x,y]) */
    s_Aba_ .req x0
    sAbe_ .req x28
    sAbi_ .req x11
    sAbo_ .req x16
    sAbu_ .req x21
    sAga_ .req x3
    sAge_ .req x8
    sAgi_ .req x12
    sAgo_ .req x17
    sAgu_ .req x22
    sAka_ .req x4
    sAke_ .req x9
    sAki_ .req x13
    sAko_ .req x18
    sAku_ .req x23
    sAma_ .req x5
    sAme_ .req x10
    sAmi_ .req x14
    sAmo_ .req x19
    sAmu_ .req x24
    sAsa_ .req x1
    sAse_ .req x6
    sAsi_ .req x15
    sAso_ .req x20
    sAsu_ .req x25

    /* sC[x] = sA[x,0] xor sA[x,1] xor sA[x,2] xor sA[x,3] xor sA[x,4],   for x in 0..4 */
    /* sE[x] = sC[x-1] xor rot(C[x+1],1), for x in 0..4 */
    sC0 .req x0
    sE0 .req x29
    sC1 .req x26
    sE1 .req x30
    sC2 .req x27
    sE2 .req x26
    sC3 .req x28
    sE3 .req x27
    sC4 .req x29
    sE4 .req x28

    tmp .req x30

/************************ MACROS ****************************/

/* Macros using v8.4-A SHA-3 instructions */

.macro eor3_m1 d s0 s1 s2
	eor \d\().16b, \s0\().16b, \s1\().16b
	eor \d\().16b, \d\().16b,  \s2\().16b
.endm

.macro rax1_m1 d s0 s1
   add vtmp.2d, \s1\().2d, \s1\().2d
   sri vtmp.2d, \s1\().2d, #63
   eor \d\().16b, vtmp.16b, \s0\().16b
.endm

.macro xar_m1 d s0 s1 imm
   eor vtmp.16b, \s0\().16b, \s1\().16b
   shl \d\().2d, vtmp.2d, #(64-\imm)
   sri \d\().2d, vtmp.2d, #(\imm)
.endm

.macro bcax_m1 d s0 s1 s2
    bic vtmp.16b, \s1\().16b, \s2\().16b
    eor \d\().16b, vtmp.16b, \s0\().16b
.endm

.macro load_input_vector num idx
    ldr vAbaq, [input_addr, #(16*(\num*0+\idx))]
    ldr vAbeq, [input_addr, #(16*(\num*1+\idx))]
    ldr vAbiq, [input_addr, #(16*(\num*2+\idx))]
    ldr vAboq, [input_addr, #(16*(\num*3+\idx))]
    ldr vAbuq, [input_addr, #(16*(\num*4+\idx))]
    ldr vAgaq, [input_addr, #(16*(\num*5+\idx))]
    ldr vAgeq, [input_addr, #(16*(\num*6+\idx))]
    ldr vAgiq, [input_addr, #(16*(\num*7+\idx))]
    ldr vAgoq, [input_addr, #(16*(\num*8+\idx))]
    ldr vAguq, [input_addr, #(16*(\num*9+\idx))]
    ldr vAkaq, [input_addr, #(16*(\num*10+\idx))]
    ldr vAkeq, [input_addr, #(16*(\num*11+\idx))]
    ldr vAkiq, [input_addr, #(16*(\num*12+\idx))]
    ldr vAkoq, [input_addr, #(16*(\num*13+\idx))]
    ldr vAkuq, [input_addr, #(16*(\num*14+\idx))]
    ldr vAmaq, [input_addr, #(16*(\num*15+\idx))]
    ldr vAmeq, [input_addr, #(16*(\num*16+\idx))]
    ldr vAmiq, [input_addr, #(16*(\num*17+\idx))]
    ldr vAmoq, [input_addr, #(16*(\num*18+\idx))]
    ldr vAmuq, [input_addr, #(16*(\num*19+\idx))]
    ldr vAsaq, [input_addr, #(16*(\num*20+\idx))]
    ldr vAseq, [input_addr, #(16*(\num*21+\idx))]
    ldr vAsiq, [input_addr, #(16*(\num*22+\idx))]
    ldr vAsoq, [input_addr, #(16*(\num*23+\idx))]
    ldr vAsuq, [input_addr, #(16*(\num*24+\idx))]
.endm

.macro store_input_vector num idx
    str vAbaq, [input_addr, #(16*(\num*0+\idx))]
    str vAbeq, [input_addr, #(16*(\num*1+\idx))]
    str vAbiq, [input_addr, #(16*(\num*2+\idx))]
    str vAboq, [input_addr, #(16*(\num*3+\idx))]
    str vAbuq, [input_addr, #(16*(\num*4+\idx))]
    str vAgaq, [input_addr, #(16*(\num*5+\idx))]
    str vAgeq, [input_addr, #(16*(\num*6+\idx))]
    str vAgiq, [input_addr, #(16*(\num*7+\idx))]
    str vAgoq, [input_addr, #(16*(\num*8+\idx))]
    str vAguq, [input_addr, #(16*(\num*9+\idx))]
    str vAkaq, [input_addr, #(16*(\num*10+\idx))]
    str vAkeq, [input_addr, #(16*(\num*11+\idx))]
    str vAkiq, [input_addr, #(16*(\num*12+\idx))]
    str vAkoq, [input_addr, #(16*(\num*13+\idx))]
    str vAkuq, [input_addr, #(16*(\num*14+\idx))]
    str vAmaq, [input_addr, #(16*(\num*15+\idx))]
    str vAmeq, [input_addr, #(16*(\num*16+\idx))]
    str vAmiq, [input_addr, #(16*(\num*17+\idx))]
    str vAmoq, [input_addr, #(16*(\num*18+\idx))]
    str vAmuq, [input_addr, #(16*(\num*19+\idx))]
    str vAsaq, [input_addr, #(16*(\num*20+\idx))]
    str vAseq, [input_addr, #(16*(\num*21+\idx))]
    str vAsiq, [input_addr, #(16*(\num*22+\idx))]
    str vAsoq, [input_addr, #(16*(\num*23+\idx))]
    str vAsuq, [input_addr, #(16*(\num*24+\idx))]
.endm

.macro store_input_scalar num idx
    str s_Aba, [input_addr, 8*(\num*(0)  +\idx)]
    str sAbe, [input_addr, 8*(\num*(0+1) +\idx)]
    str sAbi, [input_addr, 8*(\num*(2)+   \idx)]
    str sAbo, [input_addr, 8*(\num*(2+1) +\idx)]
    str sAbu, [input_addr, 8*(\num*(4)+   \idx)]
    str sAga, [input_addr, 8*(\num*(4+1) +\idx)]
    str sAge, [input_addr, 8*(\num*(6)+   \idx)]
    str sAgi, [input_addr, 8*(\num*(6+1) +\idx)]
    str sAgo, [input_addr, 8*(\num*(8)+   \idx)]
    str sAgu, [input_addr, 8*(\num*(8+1) +\idx)]
    str sAka, [input_addr, 8*(\num*(10)  +\idx)]
    str sAke, [input_addr, 8*(\num*(10+1)+\idx)]
    str sAki, [input_addr, 8*(\num*(12)  +\idx)]
    str sAko, [input_addr, 8*(\num*(12+1)+\idx)]
    str sAku, [input_addr, 8*(\num*(14)  +\idx)]
    str sAma, [input_addr, 8*(\num*(14+1)+\idx)]
    str sAme, [input_addr, 8*(\num*(16)  +\idx)]
    str sAmi, [input_addr, 8*(\num*(16+1)+\idx)]
    str sAmo, [input_addr, 8*(\num*(18)  +\idx)]
    str sAmu, [input_addr, 8*(\num*(18+1)+\idx)]
    str sAsa, [input_addr, 8*(\num*(20)  +\idx)]
    str sAse, [input_addr, 8*(\num*(20+1)+\idx)]
    str sAsi, [input_addr, 8*(\num*(22)  +\idx)]
    str sAso, [input_addr, 8*(\num*(22+1)+\idx)]
    str sAsu, [input_addr, 8*(\num*(24)  +\idx)]
.endm

.macro load_input_scalar num idx
    ldr s_Aba, [input_addr, 8*(\num*(0)  +\idx)]
    ldr sAbe, [input_addr, 8*(\num*(0+1) +\idx)]
    ldr sAbi, [input_addr, 8*(\num*(2)+   \idx)]
    ldr sAbo, [input_addr, 8*(\num*(2+1) +\idx)]
    ldr sAbu, [input_addr, 8*(\num*(4)+   \idx)]
    ldr sAga, [input_addr, 8*(\num*(4+1) +\idx)]
    ldr sAge, [input_addr, 8*(\num*(6)+   \idx)]
    ldr sAgi, [input_addr, 8*(\num*(6+1) +\idx)]
    ldr sAgo, [input_addr, 8*(\num*(8)+   \idx)]
    ldr sAgu, [input_addr, 8*(\num*(8+1) +\idx)]
    ldr sAka, [input_addr, 8*(\num*(10)  +\idx)]
    ldr sAke, [input_addr, 8*(\num*(10+1)+\idx)]
    ldr sAki, [input_addr, 8*(\num*(12)  +\idx)]
    ldr sAko, [input_addr, 8*(\num*(12+1)+\idx)]
    ldr sAku, [input_addr, 8*(\num*(14)  +\idx)]
    ldr sAma, [input_addr, 8*(\num*(14+1)+\idx)]
    ldr sAme, [input_addr, 8*(\num*(16)  +\idx)]
    ldr sAmi, [input_addr, 8*(\num*(16+1)+\idx)]
    ldr sAmo, [input_addr, 8*(\num*(18)  +\idx)]
    ldr sAmu, [input_addr, 8*(\num*(18+1)+\idx)]
    ldr sAsa, [input_addr, 8*(\num*(20)  +\idx)]
    ldr sAse, [input_addr, 8*(\num*(20+1)+\idx)]
    ldr sAsi, [input_addr, 8*(\num*(22)  +\idx)]
    ldr sAso, [input_addr, 8*(\num*(22+1)+\idx)]
    ldr sAsu, [input_addr, 8*(\num*(24)  +\idx)]
.endm

#define STACK_SIZE (8*8 + 16*6 + 3*8 + 8) // VREGS (8*8), GPRs (16*6), count (8), const (8), input (8), padding (8)
#define STACK_BASE_GPRS  (3*8+8)
#define STACK_BASE_VREGS (3*8+8+16*6)
#define STACK_OFFSET_INPUT (0*8)
#define STACK_OFFSET_CONST (1*8)
#define STACK_OFFSET_COUNT (2*8)

.macro save_gprs
    stp x19, x20, [sp, #(STACK_BASE_GPRS + 16*0)]
    stp x21, x22, [sp, #(STACK_BASE_GPRS + 16*1)]
    stp x23, x24, [sp, #(STACK_BASE_GPRS + 16*2)]
    stp x25, x26, [sp, #(STACK_BASE_GPRS + 16*3)]
    stp x27, x28, [sp, #(STACK_BASE_GPRS + 16*4)]
    stp x29, x30, [sp, #(STACK_BASE_GPRS + 16*5)]
.endm

.macro restore_gprs
    ldp x19, x20, [sp, #(STACK_BASE_GPRS + 16*0)]
    ldp x21, x22, [sp, #(STACK_BASE_GPRS + 16*1)]
    ldp x23, x24, [sp, #(STACK_BASE_GPRS + 16*2)]
    ldp x25, x26, [sp, #(STACK_BASE_GPRS + 16*3)]
    ldp x27, x28, [sp, #(STACK_BASE_GPRS + 16*4)]
    ldp x29, x30, [sp, #(STACK_BASE_GPRS + 16*5)]
.endm

.macro save_vregs
    stp d8,  d9,  [sp,#(STACK_BASE_VREGS+0*16)]
    stp d10, d11, [sp,#(STACK_BASE_VREGS+1*16)]
    stp d12, d13, [sp,#(STACK_BASE_VREGS+2*16)]
    stp d14, d15, [sp,#(STACK_BASE_VREGS+3*16)]
.endm

.macro restore_vregs
    ldp d14, d15, [sp,#(STACK_BASE_VREGS+3*16)]
    ldp d12, d13, [sp,#(STACK_BASE_VREGS+2*16)]
    ldp d10, d11, [sp,#(STACK_BASE_VREGS+1*16)]
    ldp d8,  d9,  [sp,#(STACK_BASE_VREGS+0*16)]
.endm

.macro alloc_stack
    sub sp, sp, #(STACK_SIZE)
.endm

.macro free_stack
    add sp, sp, #(STACK_SIZE)
.endm

.macro eor5 dst, src0, src1, src2, src3, src4
    eor \dst, \src0, \src1
    eor \dst, \dst,  \src2
    eor \dst, \dst,  \src3
    eor \dst, \dst,  \src4
.endm

.macro xor_rol dst, src1, src0, imm
    eor \dst, \src0, \src1, ror  #(64-\imm)
.endm

.macro bic_rol dst, src1, src0, imm
    bic \dst, \src0, \src1, ror  #(64-\imm)
.endm

.macro rotate dst, src, imm
    ror \dst, \src, #(64-\imm)
.endm

.macro hybrid_round_initial
    scalar_round_initial
    vector_round_initial
.endm

.macro scalar_round_initial
   eor sC0, sAma, sAsa
   eor sC1, sAme, sAse
   eor sC2, sAmi, sAsi
   eor sC3, sAmo, sAso
   eor sC4, sAmu, sAsu
   eor sC0, sAka, sC0
   eor sC1, sAke, sC1
   eor sC2, sAki, sC2
   eor sC3, sAko, sC3
   eor sC4, sAku, sC4
   eor sC0, sAga, sC0
   eor sC1, sAge, sC1
   eor sC2, sAgi, sC2
   eor sC3, sAgo, sC3
   eor sC4, sAgu, sC4
   eor sC0, s_Aba, sC0
   eor sC1, sAbe, sC1
   eor sC2, sAbi, sC2
   eor sC3, sAbo, sC3
   eor sC4, sAbu, sC4

   eor sE1, sC0, sC2, ror #63
   eor sE3, sC2, sC4, ror #63
   eor sE0, sC4, sC1, ror #63
   eor sE2, sC1, sC3, ror #63
   eor sE4, sC3, sC0, ror #63

   eor s_Aba_, s_Aba, sE0
   eor sAsa_, sAbi, sE2
   eor sAbi_, sAki, sE2
   eor sAki_, sAko, sE3
   eor sAko_, sAmu, sE4
   eor sAmu_, sAso, sE3
   eor sAso_, sAma, sE0
   eor sAka_, sAbe, sE1
   eor sAse_, sAgo, sE3
   eor sAgo_, sAme, sE1
   eor sAke_, sAgi, sE2
   eor sAgi_, sAka, sE0
   eor sAga_, sAbo, sE3
   eor sAbo_, sAmo, sE3
   eor sAmo_, sAmi, sE2
   eor sAmi_, sAke, sE1
   eor sAge_, sAgu, sE4
   eor sAgu_, sAsi, sE2
   eor sAsi_, sAku, sE4
   eor sAku_, sAsa, sE0
   eor sAma_, sAbu, sE4
   eor sAbu_, sAsu, sE4
   eor sAsu_, sAse, sE1
   eor sAme_, sAga, sE0
   eor sAbe_, sAge, sE1

   asm_load const_addr

   bic tmp, sAgi_, sAge_, ror #47
   eor sAga, tmp,  sAga_, ror #39
   bic tmp, sAgo_, sAgi_, ror #42
   eor sAge, tmp,  sAge_, ror #25
   bic tmp, sAgu_, sAgo_, ror #16
   eor sAgi, tmp,  sAgi_, ror #58
   bic tmp, sAga_, sAgu_, ror #31
   eor sAgo, tmp,  sAgo_, ror #47
   bic tmp, sAge_, sAga_, ror #56
   eor sAgu, tmp,  sAgu_, ror #23
   bic tmp, sAki_, sAke_, ror #19
   eor sAka, tmp,  sAka_, ror #24
   bic tmp, sAko_, sAki_, ror #47
   eor sAke, tmp,  sAke_, ror #2
   bic tmp, sAku_, sAko_, ror #10
   eor sAki, tmp,  sAki_, ror #57
   bic tmp, sAka_, sAku_, ror #47
   eor sAko, tmp,  sAko_, ror #57
   bic tmp, sAke_, sAka_, ror #5
   eor sAku, tmp,  sAku_, ror #52
   bic tmp, sAmi_, sAme_, ror #38
   eor sAma, tmp,  sAma_, ror #47
   bic tmp, sAmo_, sAmi_, ror #5
   eor sAme, tmp,  sAme_, ror #43
   bic tmp, sAmu_, sAmo_, ror #41
   eor sAmi, tmp,  sAmi_, ror #46

   ldr cur_const, [const_addr]
   mov count, #1

   bic tmp, sAma_, sAmu_, ror #35
   eor sAmo, tmp,  sAmo_, ror #12
   bic tmp, sAme_, sAma_, ror #9
   eor sAmu, tmp,  sAmu_, ror #44
   bic tmp, sAsi_, sAse_, ror #48
   eor sAsa, tmp,  sAsa_, ror #41
   bic tmp, sAso_, sAsi_, ror #2
   eor sAse, tmp,  sAse_, ror #50
   bic tmp, sAsu_, sAso_, ror #25
   eor sAsi, tmp,  sAsi_, ror #27
   bic tmp, sAsa_, sAsu_, ror #60
   eor sAso, tmp,  sAso_, ror #21
   bic tmp, sAse_, sAsa_, ror #57
   eor sAsu, tmp,  sAsu_, ror #53
   bic tmp, sAbi_, sAbe_, ror #63
   eor s_Aba, s_Aba_, tmp,  ror #21
   bic tmp, sAbo_, sAbi_, ror #42
   eor sAbe, tmp,  sAbe_, ror #41
   bic tmp, sAbu_, sAbo_, ror #57
   eor sAbi, tmp,  sAbi_, ror #35
   bic tmp, s_Aba_, sAbu_, ror #50
   eor sAbo, tmp,  sAbo_, ror #43
   bic tmp, sAbe_, s_Aba_, ror #44
   eor sAbu, tmp,  sAbu_, ror #30

   eor s_Aba, s_Aba, cur_const

   str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

   eor sC0, sAka, sAsa, ror #50
   eor sC1, sAse, sAge, ror #60
   eor sC2, sAmi, sAgi, ror #59
   eor sC3, sAgo, sAso, ror #30
   eor sC4, sAbu, sAsu, ror #53
   eor sC0, sAma, sC0, ror #49
   eor sC1, sAbe, sC1, ror #44
   eor sC2, sAki, sC2, ror #26
   eor sC3, sAmo, sC3, ror #63
   eor sC4, sAmu, sC4, ror #56
   eor sC0, sAga, sC0, ror #57
   eor sC1, sAme, sC1, ror #58
   eor sC2, sAbi, sC2, ror #60
   eor sC3, sAko, sC3, ror #38
   eor sC4, sAgu, sC4, ror #48
   eor sC0, s_Aba, sC0, ror #61
   eor sC1, sAke, sC1, ror #57
   eor sC2, sAsi, sC2, ror #52
   eor sC3, sAbo, sC3, ror #63
   eor sC4, sAku, sC4, ror #50
   ror sC1, sC1, #56
   ror sC4, sC4, #58
   ror sC2, sC2, #62

   eor sE1, sC0, sC2, ror #63
   eor sE3, sC2, sC4, ror #63
   eor sE0, sC4, sC1, ror #63
   eor sE2, sC1, sC3, ror #63
   eor sE4, sC3, sC0, ror #63

   eor s_Aba_, sE0, s_Aba
   eor sAsa_, sE2, sAbi, ror #50
   eor sAbi_, sE2, sAki, ror #46
   eor sAki_, sE3, sAko, ror #63
   eor sAko_, sE4, sAmu, ror #28
   eor sAmu_, sE3, sAso, ror #2
   eor sAso_, sE0, sAma, ror #54
   eor sAka_, sE1, sAbe, ror #43
   eor sAse_, sE3, sAgo, ror #36
   eor sAgo_, sE1, sAme, ror #49
   eor sAke_, sE2, sAgi, ror #3
   eor sAgi_, sE0, sAka, ror #39
   eor sAga_, sE3, sAbo
   eor sAbo_, sE3, sAmo, ror #37
   eor sAmo_, sE2, sAmi, ror #8
   eor sAmi_, sE1, sAke, ror #56
   eor sAge_, sE4, sAgu, ror #44
   eor sAgu_, sE2, sAsi, ror #62
   eor sAsi_, sE4, sAku, ror #58
   eor sAku_, sE0, sAsa, ror #25
   eor sAma_, sE4, sAbu, ror #20
   eor sAbu_, sE4, sAsu, ror #9
   eor sAsu_, sE1, sAse, ror #23
   eor sAme_, sE0, sAga, ror #61
   eor sAbe_, sE1, sAge, ror #19

   asm_load const_addr
   ldr count, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT

   bic tmp, sAgi_, sAge_, ror #47
   eor sAga, tmp,  sAga_, ror #39
   bic tmp, sAgo_, sAgi_, ror #42
   eor sAge, tmp,  sAge_, ror #25
   bic tmp, sAgu_, sAgo_, ror #16
   eor sAgi, tmp,  sAgi_, ror #58
   bic tmp, sAga_, sAgu_, ror #31
   eor sAgo, tmp,  sAgo_, ror #47
   bic tmp, sAge_, sAga_, ror #56
   eor sAgu, tmp,  sAgu_, ror #23
   bic tmp, sAki_, sAke_, ror #19
   eor sAka, tmp,  sAka_, ror #24
   bic tmp, sAko_, sAki_, ror #47
   eor sAke, tmp,  sAke_, ror #2
   bic tmp, sAku_, sAko_, ror #10
   eor sAki, tmp,  sAki_, ror #57
   bic tmp, sAka_, sAku_, ror #47
   eor sAko, tmp,  sAko_, ror #57
   bic tmp, sAke_, sAka_, ror #5
   eor sAku, tmp,  sAku_, ror #52
   bic tmp, sAmi_, sAme_, ror #38
   eor sAma, tmp,  sAma_, ror #47
   bic tmp, sAmo_, sAmi_, ror #5
   eor sAme, tmp,  sAme_, ror #43
   bic tmp, sAmu_, sAmo_, ror #41
   eor sAmi, tmp,  sAmi_, ror #46
   bic tmp, sAma_, sAmu_, ror #35

   ldr cur_const, [const_addr, count, UXTW #3]

   eor sAmo, tmp,  sAmo_, ror #12
   bic tmp, sAme_, sAma_, ror #9
   eor sAmu, tmp,  sAmu_, ror #44
   bic tmp, sAsi_, sAse_, ror #48
   eor sAsa, tmp,  sAsa_, ror #41
   bic tmp, sAso_, sAsi_, ror #2
   eor sAse, tmp,  sAse_, ror #50
   bic tmp, sAsu_, sAso_, ror #25
   eor sAsi, tmp,  sAsi_, ror #27
   bic tmp, sAsa_, sAsu_, ror #60
   eor sAso, tmp,  sAso_, ror #21
   bic tmp, sAse_, sAsa_, ror #57
   eor sAsu, tmp,  sAsu_, ror #53
   bic tmp, sAbi_, sAbe_, ror #63
   eor s_Aba, s_Aba_, tmp,  ror #21
   bic tmp, sAbo_, sAbi_, ror #42
   eor sAbe, tmp,  sAbe_, ror #41
   bic tmp, sAbu_, sAbo_, ror #57
   eor sAbi, tmp,  sAbi_, ror #35
   bic tmp, s_Aba_, sAbu_, ror #50
   eor sAbo, tmp,  sAbo_, ror #43
   bic tmp, sAbe_, s_Aba_, ror #44
   eor sAbu, tmp,  sAbu_, ror #30
   add count, count, #1
   eor s_Aba, s_Aba, cur_const
.endm


.macro vector_round_initial
   eor3_m1 C0, vAba, vAga, vAka
   eor3_m1 C0, C0, vAma,  vAsa
   eor3_m1 C1, vAbe, vAge, vAke
   eor3_m1 C1, C1, vAme,  vAse
   eor3_m1 C2, vAbi, vAgi, vAki
   eor3_m1 C2, C2, vAmi,  vAsi
   eor3_m1 C3, vAbo, vAgo, vAko
   eor3_m1 C3, C3, vAmo,  vAso
   eor3_m1 C4, vAbu, vAgu, vAku
   eor3_m1 C4, C4, vAmu,  vAsu
   rax1_m1 E1, C0, C2
   rax1_m1 E3, C2, C4
   rax1_m1 E0, C4, C1
   rax1_m1 E2, C1, C3
   rax1_m1 E4, C3, C0
   eor vAba_.16b, vAba.16b, E0.16b
   xar_m1 vAsa_, vAbi, E2, 2
   xar_m1 vAbi_, vAki, E2, 21
   xar_m1 vAki_, vAko, E3, 39
   xar_m1 vAko_, vAmu, E4, 56
   xar_m1 vAmu_, vAso, E3, 8
   xar_m1 vAso_, vAma, E0, 23
   xar_m1 vAka_, vAbe, E1, 63
   xar_m1 vAse_, vAgo, E3, 9
   xar_m1 vAgo_, vAme, E1, 19
   xar_m1 vAke_, vAgi, E2, 58
   xar_m1 vAgi_, vAka, E0, 61
   xar_m1 vAga_, vAbo, E3, 36
   xar_m1 vAbo_, vAmo, E3, 43
   xar_m1 vAmo_, vAmi, E2, 49
   xar_m1 vAmi_, vAke, E1, 54
   xar_m1 vAge_, vAgu, E4, 44
   xar_m1 vAgu_, vAsi, E2, 3
   xar_m1 vAsi_, vAku, E4, 25
   xar_m1 vAku_, vAsa, E0, 46
   xar_m1 vAma_, vAbu, E4, 37
   xar_m1 vAbu_, vAsu, E4, 50
   xar_m1 vAsu_, vAse, E1, 62
   xar_m1 vAme_, vAga, E0, 28
   xar_m1 vAbe_, vAge, E1, 20
   ldr sE1, [sp, #STACK_OFFSET_CONST] // @slothy:reads=STACK_OFFSET_CONST
   ld1r {v28.2d}, [sE1], #8
   str sE1, [sp, #STACK_OFFSET_CONST] // @slothy:writes=STACK_OFFSET_CONST
   bcax_m1 vAga, vAga_, vAgi_, vAge_
   bcax_m1 vAge, vAge_, vAgo_, vAgi_
   bcax_m1 vAgi, vAgi_, vAgu_, vAgo_
   bcax_m1 vAgo, vAgo_, vAga_, vAgu_
   bcax_m1 vAgu, vAgu_, vAge_, vAga_
   bcax_m1 vAka, vAka_, vAki_, vAke_
   bcax_m1 vAke, vAke_, vAko_, vAki_
   bcax_m1 vAki, vAki_, vAku_, vAko_
   bcax_m1 vAko, vAko_, vAka_, vAku_
   bcax_m1 vAku, vAku_, vAke_, vAka_
   bcax_m1 vAma, vAma_, vAmi_, vAme_
   bcax_m1 vAme, vAme_, vAmo_, vAmi_
   bcax_m1 vAmi, vAmi_, vAmu_, vAmo_
   bcax_m1 vAmo, vAmo_, vAma_, vAmu_
   bcax_m1 vAmu, vAmu_, vAme_, vAma_
   bcax_m1 vAsa, vAsa_, vAsi_, vAse_
   bcax_m1 vAse, vAse_, vAso_, vAsi_
   bcax_m1 vAsi, vAsi_, vAsu_, vAso_
   bcax_m1 vAso, vAso_, vAsa_, vAsu_
   bcax_m1 vAsu, vAsu_, vAse_, vAsa_
   bcax_m1 vAba, vAba_, vAbi_, vAbe_
   bcax_m1 vAbe, vAbe_, vAbo_, vAbi_
   bcax_m1 vAbi, vAbi_, vAbu_, vAbo_
   bcax_m1 vAbo, vAbo_, vAba_, vAbu_
   bcax_m1 vAbu, vAbu_, vAbe_, vAba_
   eor vAba.16b, vAba.16b, v28.16b
.endm

.macro  hybrid_round_noninitial
    scalar_round_noninitial
    vector_round_noninitial
.endm

.macro  scalar_round_noninitial
    str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

    eor sC0, sAka, sAsa, ror #50
    eor sC1, sAse, sAge, ror #60
    eor sC2, sAmi, sAgi, ror #59
    eor sC3, sAgo, sAso, ror #30
    eor sC4, sAbu, sAsu, ror #53
    eor sC0, sAma, sC0, ror #49
    eor sC1, sAbe, sC1, ror #44
    eor sC2, sAki, sC2, ror #26
    eor sC3, sAmo, sC3, ror #63
    eor sC4, sAmu, sC4, ror #56
    eor sC0, sAga, sC0, ror #57
    eor sC1, sAme, sC1, ror #58
    eor sC2, sAbi, sC2, ror #60
    eor sC3, sAko, sC3, ror #38
    eor sC4, sAgu, sC4, ror #48
    eor sC0, s_Aba, sC0, ror #61
    eor sC1, sAke, sC1, ror #57
    eor sC2, sAsi, sC2, ror #52
    eor sC3, sAbo, sC3, ror #63
    eor sC4, sAku, sC4, ror #50
    ror sC1, sC1, #56
    ror sC4, sC4, #58
    ror sC2, sC2, #62

    eor sE1, sC0, sC2, ror #63
    eor sE3, sC2, sC4, ror #63
    eor sE0, sC4, sC1, ror #63
    eor sE2, sC1, sC3, ror #63
    eor sE4, sC3, sC0, ror #63

    eor s_Aba_, sE0, s_Aba
    eor sAsa_, sE2, sAbi, ror #50
    eor sAbi_, sE2, sAki, ror #46
    eor sAki_, sE3, sAko, ror #63
    eor sAko_, sE4, sAmu, ror #28
    eor sAmu_, sE3, sAso, ror #2
    eor sAso_, sE0, sAma, ror #54
    eor sAka_, sE1, sAbe, ror #43
    eor sAse_, sE3, sAgo, ror #36
    eor sAgo_, sE1, sAme, ror #49
    eor sAke_, sE2, sAgi, ror #3
    eor sAgi_, sE0, sAka, ror #39
    eor sAga_, sE3, sAbo
    eor sAbo_, sE3, sAmo, ror #37
    eor sAmo_, sE2, sAmi, ror #8
    eor sAmi_, sE1, sAke, ror #56
    eor sAge_, sE4, sAgu, ror #44
    eor sAgu_, sE2, sAsi, ror #62
    eor sAsi_, sE4, sAku, ror #58
    eor sAku_, sE0, sAsa, ror #25
    eor sAma_, sE4, sAbu, ror #20
    eor sAbu_, sE4, sAsu, ror #9
    eor sAsu_, sE1, sAse, ror #23
    eor sAme_, sE0, sAga, ror #61
    eor sAbe_, sE1, sAge, ror #19

    asm_load const_addr
    ldr count, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT

    bic tmp, sAgi_, sAge_, ror #47
    eor sAga, tmp,  sAga_, ror #39
    bic tmp, sAgo_, sAgi_, ror #42
    eor sAge, tmp,  sAge_, ror #25
    bic tmp, sAgu_, sAgo_, ror #16
    eor sAgi, tmp,  sAgi_, ror #58
    bic tmp, sAga_, sAgu_, ror #31
    eor sAgo, tmp,  sAgo_, ror #47
    bic tmp, sAge_, sAga_, ror #56
    eor sAgu, tmp,  sAgu_, ror #23
    bic tmp, sAki_, sAke_, ror #19
    eor sAka, tmp,  sAka_, ror #24
    bic tmp, sAko_, sAki_, ror #47
    eor sAke, tmp,  sAke_, ror #2
    bic tmp, sAku_, sAko_, ror #10
    eor sAki, tmp,  sAki_, ror #57
    bic tmp, sAka_, sAku_, ror #47
    eor sAko, tmp,  sAko_, ror #57
    bic tmp, sAke_, sAka_, ror #5
    eor sAku, tmp,  sAku_, ror #52
    bic tmp, sAmi_, sAme_, ror #38
    eor sAma, tmp,  sAma_, ror #47
    bic tmp, sAmo_, sAmi_, ror #5
    eor sAme, tmp,  sAme_, ror #43
    bic tmp, sAmu_, sAmo_, ror #41
    eor sAmi, tmp,  sAmi_, ror #46
    bic tmp, sAma_, sAmu_, ror #35

    ldr cur_const, [const_addr, count, UXTW #3]
    add count, count, #1

    eor sAmo, tmp,  sAmo_, ror #12
    bic tmp, sAme_, sAma_, ror #9
    eor sAmu, tmp,  sAmu_, ror #44
    bic tmp, sAsi_, sAse_, ror #48
    eor sAsa, tmp,  sAsa_, ror #41
    bic tmp, sAso_, sAsi_, ror #2
    eor sAse, tmp,  sAse_, ror #50
    bic tmp, sAsu_, sAso_, ror #25
    eor sAsi, tmp,  sAsi_, ror #27
    bic tmp, sAsa_, sAsu_, ror #60
    eor sAso, tmp,  sAso_, ror #21
    bic tmp, sAse_, sAsa_, ror #57
    eor sAsu, tmp,  sAsu_, ror #53
    bic tmp, sAbi_, sAbe_, ror #63
    eor s_Aba, s_Aba_, tmp,  ror #21
    bic tmp, sAbo_, sAbi_, ror #42
    eor sAbe, tmp,  sAbe_, ror #41
    bic tmp, sAbu_, sAbo_, ror #57
    eor sAbi, tmp,  sAbi_, ror #35
    bic tmp, s_Aba_, sAbu_, ror #50
    eor sAbo, tmp,  sAbo_, ror #43
    bic tmp, sAbe_, s_Aba_, ror #44
    eor sAbu, tmp,  sAbu_, ror #30

    eor s_Aba, s_Aba, cur_const
    str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

    eor sC0, sAka, sAsa, ror #50
    eor sC1, sAse, sAge, ror #60
    eor sC2, sAmi, sAgi, ror #59
    eor sC3, sAgo, sAso, ror #30
    eor sC4, sAbu, sAsu, ror #53
    eor sC0, sAma, sC0, ror #49
    eor sC1, sAbe, sC1, ror #44
    eor sC2, sAki, sC2, ror #26
    eor sC3, sAmo, sC3, ror #63
    eor sC4, sAmu, sC4, ror #56
    eor sC0, sAga, sC0, ror #57
    eor sC1, sAme, sC1, ror #58
    eor sC2, sAbi, sC2, ror #60
    eor sC3, sAko, sC3, ror #38
    eor sC4, sAgu, sC4, ror #48
    eor sC0, s_Aba, sC0, ror #61
    eor sC1, sAke, sC1, ror #57
    eor sC2, sAsi, sC2, ror #52
    eor sC3, sAbo, sC3, ror #63
    eor sC4, sAku, sC4, ror #50
    ror sC1, sC1, #56
    ror sC4, sC4, #58
    ror sC2, sC2, #62

    eor sE1, sC0, sC2, ror #63
    eor sE3, sC2, sC4, ror #63
    eor sE0, sC4, sC1, ror #63
    eor sE2, sC1, sC3, ror #63
    eor sE4, sC3, sC0, ror #63

    eor s_Aba_, sE0, s_Aba
    eor sAsa_, sE2, sAbi, ror #50
    eor sAbi_, sE2, sAki, ror #46
    eor sAki_, sE3, sAko, ror #63
    eor sAko_, sE4, sAmu, ror #28
    eor sAmu_, sE3, sAso, ror #2
    eor sAso_, sE0, sAma, ror #54
    eor sAka_, sE1, sAbe, ror #43
    eor sAse_, sE3, sAgo, ror #36
    eor sAgo_, sE1, sAme, ror #49
    eor sAke_, sE2, sAgi, ror #3
    eor sAgi_, sE0, sAka, ror #39
    eor sAga_, sE3, sAbo
    eor sAbo_, sE3, sAmo, ror #37
    eor sAmo_, sE2, sAmi, ror #8
    eor sAmi_, sE1, sAke, ror #56
    eor sAge_, sE4, sAgu, ror #44
    eor sAgu_, sE2, sAsi, ror #62
    eor sAsi_, sE4, sAku, ror #58
    eor sAku_, sE0, sAsa, ror #25
    eor sAma_, sE4, sAbu, ror #20
    eor sAbu_, sE4, sAsu, ror #9
    eor sAsu_, sE1, sAse, ror #23
    eor sAme_, sE0, sAga, ror #61
    eor sAbe_, sE1, sAge, ror #19

    asm_load const_addr
    ldr count, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT

    bic tmp, sAgi_, sAge_, ror #47
    eor sAga, tmp,  sAga_, ror #39
    bic tmp, sAgo_, sAgi_, ror #42
    eor sAge, tmp,  sAge_, ror #25
    bic tmp, sAgu_, sAgo_, ror #16
    eor sAgi, tmp,  sAgi_, ror #58
    bic tmp, sAga_, sAgu_, ror #31
    eor sAgo, tmp,  sAgo_, ror #47
    bic tmp, sAge_, sAga_, ror #56
    eor sAgu, tmp,  sAgu_, ror #23
    bic tmp, sAki_, sAke_, ror #19
    eor sAka, tmp,  sAka_, ror #24
    bic tmp, sAko_, sAki_, ror #47
    eor sAke, tmp,  sAke_, ror #2
    bic tmp, sAku_, sAko_, ror #10
    eor sAki, tmp,  sAki_, ror #57
    bic tmp, sAka_, sAku_, ror #47
    eor sAko, tmp,  sAko_, ror #57
    bic tmp, sAke_, sAka_, ror #5
    eor sAku, tmp,  sAku_, ror #52
    bic tmp, sAmi_, sAme_, ror #38
    eor sAma, tmp,  sAma_, ror #47
    bic tmp, sAmo_, sAmi_, ror #5
    eor sAme, tmp,  sAme_, ror #43
    bic tmp, sAmu_, sAmo_, ror #41
    eor sAmi, tmp,  sAmi_, ror #46
    bic tmp, sAma_, sAmu_, ror #35

    ldr cur_const, [const_addr, count, UXTW #3]
    add count, count, #1

    eor sAmo, tmp,  sAmo_, ror #12
    bic tmp, sAme_, sAma_, ror #9
    eor sAmu, tmp,  sAmu_, ror #44
    bic tmp, sAsi_, sAse_, ror #48
    eor sAsa, tmp,  sAsa_, ror #41
    bic tmp, sAso_, sAsi_, ror #2
    eor sAse, tmp,  sAse_, ror #50
    bic tmp, sAsu_, sAso_, ror #25
    eor sAsi, tmp,  sAsi_, ror #27
    bic tmp, sAsa_, sAsu_, ror #60
    eor sAso, tmp,  sAso_, ror #21
    bic tmp, sAse_, sAsa_, ror #57
    eor sAsu, tmp,  sAsu_, ror #53
    bic tmp, sAbi_, sAbe_, ror #63
    eor s_Aba, s_Aba_, tmp,  ror #21
    bic tmp, sAbo_, sAbi_, ror #42
    eor sAbe, tmp,  sAbe_, ror #41
    bic tmp, sAbu_, sAbo_, ror #57
    eor sAbi, tmp,  sAbi_, ror #35
    bic tmp, s_Aba_, sAbu_, ror #50
    eor sAbo, tmp,  sAbo_, ror #43
    bic tmp, sAbe_, s_Aba_, ror #44
    eor sAbu, tmp,  sAbu_, ror #30

    eor s_Aba, s_Aba, cur_const

.endm


.macro  vector_round_noninitial
   eor3_m1 C0, vAba, vAga, vAka
   eor3_m1 C0, C0, vAma,  vAsa
   eor3_m1 C1, vAbe, vAge, vAke
   eor3_m1 C1, C1, vAme,  vAse
   eor3_m1 C2, vAbi, vAgi, vAki
   eor3_m1 C2, C2, vAmi,  vAsi
   eor3_m1 C3, vAbo, vAgo, vAko
   eor3_m1 C3, C3, vAmo,  vAso
   eor3_m1 C4, vAbu, vAgu, vAku
   eor3_m1 C4, C4, vAmu,  vAsu
   rax1_m1 E1, C0, C2
   rax1_m1 E3, C2, C4
   rax1_m1 E0, C4, C1
   rax1_m1 E2, C1, C3
   rax1_m1 E4, C3, C0
   eor vAba_.16b, vAba.16b, E0.16b
   xar_m1 vAsa_, vAbi, E2, 2
   xar_m1 vAbi_, vAki, E2, 21
   xar_m1 vAki_, vAko, E3, 39
   xar_m1 vAko_, vAmu, E4, 56
   xar_m1 vAmu_, vAso, E3, 8
   xar_m1 vAso_, vAma, E0, 23
   xar_m1 vAka_, vAbe, E1, 63
   xar_m1 vAse_, vAgo, E3, 9
   xar_m1 vAgo_, vAme, E1, 19
   xar_m1 vAke_, vAgi, E2, 58
   xar_m1 vAgi_, vAka, E0, 61
   xar_m1 vAga_, vAbo, E3, 36
   xar_m1 vAbo_, vAmo, E3, 43
   xar_m1 vAmo_, vAmi, E2, 49
   xar_m1 vAmi_, vAke, E1, 54
   xar_m1 vAge_, vAgu, E4, 44
   xar_m1 vAgu_, vAsi, E2, 3
   xar_m1 vAsi_, vAku, E4, 25
   xar_m1 vAku_, vAsa, E0, 46
   xar_m1 vAma_, vAbu, E4, 37
   xar_m1 vAbu_, vAsu, E4, 50
   xar_m1 vAsu_, vAse, E1, 62
   xar_m1 vAme_, vAga, E0, 28
   xar_m1 vAbe_, vAge, E1, 20
   ldr sE1, [sp, #STACK_OFFSET_CONST] // @slothy:reads=STACK_OFFSET_CONST
   ld1r {v28.2d}, [sE1], #8
   str sE1, [sp, #STACK_OFFSET_CONST] // @slothy:writes=STACK_OFFSET_CONST
   bcax_m1 vAga, vAga_, vAgi_, vAge_
   bcax_m1 vAge, vAge_, vAgo_, vAgi_
   bcax_m1 vAgi, vAgi_, vAgu_, vAgo_
   bcax_m1 vAgo, vAgo_, vAga_, vAgu_
   bcax_m1 vAgu, vAgu_, vAge_, vAga_
   bcax_m1 vAka, vAka_, vAki_, vAke_
   bcax_m1 vAke, vAke_, vAko_, vAki_
   bcax_m1 vAki, vAki_, vAku_, vAko_
   bcax_m1 vAko, vAko_, vAka_, vAku_
   bcax_m1 vAku, vAku_, vAke_, vAka_
   bcax_m1 vAma, vAma_, vAmi_, vAme_
   bcax_m1 vAme, vAme_, vAmo_, vAmi_
   bcax_m1 vAmi, vAmi_, vAmu_, vAmo_
   bcax_m1 vAmo, vAmo_, vAma_, vAmu_
   bcax_m1 vAmu, vAmu_, vAme_, vAma_
   bcax_m1 vAsa, vAsa_, vAsi_, vAse_
   bcax_m1 vAse, vAse_, vAso_, vAsi_
   bcax_m1 vAsi, vAsi_, vAsu_, vAso_
   bcax_m1 vAso, vAso_, vAsa_, vAsu_
   bcax_m1 vAsu, vAsu_, vAse_, vAsa_
   bcax_m1 vAba, vAba_, vAbi_, vAbe_
   bcax_m1 vAbe, vAbe_, vAbo_, vAbi_
   bcax_m1 vAbi, vAbi_, vAbu_, vAbo_
   bcax_m1 vAbo, vAbo_, vAba_, vAbu_
   bcax_m1 vAbu, vAbu_, vAbe_, vAba_
   eor vAba.16b, vAba.16b, v28.16b
.endm


.macro final_rotate
    ror sAga, sAga,#(64-3)
    ror sAka, sAka,#(64-25)
    ror sAma, sAma,#(64-10)
    ror sAsa, sAsa,#(64-39)
    ror sAbe, sAbe,#(64-21)
    ror sAge, sAge,#(64-45)
    ror sAke, sAke,#(64-8)
    ror sAme, sAme,#(64-15)
    ror sAse, sAse,#(64-41)
    ror sAbi, sAbi,#(64-14)
    ror sAgi, sAgi,#(64-61)
    ror sAki, sAki,#(64-18)
    ror sAmi, sAmi,#(64-56)
    ror sAsi, sAsi,#(64-2)
    ror sAgo, sAgo,#(64-28)
    ror sAko, sAko,#(64-1)
    ror sAmo, sAmo,#(64-27)
    ror sAso, sAso,#(64-62)
    ror sAbu, sAbu,#(64-44)
    ror sAgu, sAgu,#(64-20)
    ror sAku, sAku,#(64-6)
    ror sAmu, sAmu,#(64-36)
    ror sAsu, sAsu,#(64-55)
.endm

#define KECCAK_F1600_ROUNDS 24

.global keccak_f1600_x4_hybrid_slothy
.global _keccak_f1600_x4_hybrid_slothy
.text
.align 4

keccak_f1600_x4_hybrid_slothy:
_keccak_f1600_x4_hybrid_slothy:
    alloc_stack
    save_gprs
    save_vregs
    str input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:writes=STACK_OFFSET_INPUT

    load_input_vector 2,1

    asm_load const_addr
    str const_addr, [sp, #STACK_OFFSET_CONST] // @slothy:writes=STACK_OFFSET_CONST

    // First scalar Keccak computation alongside first half of SIMD computation
    load_input_scalar 4,0
 initial:
    hybrid_round_initial
 end_initial:
 loop_0:
     hybrid_round_noninitial
 end_loop_0:
     cmp count, #(KECCAK_F1600_ROUNDS-1)
     ble loop_0
     final_rotate
     ldr input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:reads=STACK_OFFSET_INPUT
     store_input_scalar 4,0

     // Second scalar Keccak computation alongsie second half of SIMD computation
     load_input_scalar 4,1
 initial2:
     hybrid_round_initial
 end_initial2:
 loop_1:
     hybrid_round_noninitial
 end_loop_1:
     cmp count, #(KECCAK_F1600_ROUNDS-1)
     ble loop_1
     final_rotate
     ldr input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:reads=STACK_OFFSET_INPUT
     store_input_scalar 4, 1

     store_input_vector 2,1

    restore_vregs
    restore_gprs
    free_stack
    ret
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

#define KECCAK_F1600_ROUNDS 24

//
// Author: Hanno Becker <hanno.becker@arm.com>
// Author: Matthias Kannwischer <matthias@kannwischer.eu>
//

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
    outer          .req x30
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
    sAba     .req x1
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
    sAko     .req x28
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

    tmp .req x30

/************************ MACROS ****************************/

.macro eor3_m0 d s0 s1 s2
    eor3 \d\().16b, \s0\().16b, \s1\().16b, \s2\().16b
.endm

.macro rax1_m0 d s0 s1
    rax1 \d\().2d, \s0\().2d, \s1\().2d
.endm

.macro xar_m0 d s0 s1 imm
    xar \d\().2d, \s0\().2d, \s1\().2d, #\imm
.endm

.macro bcax_m0 d s0 s1 s2
    bcax \d\().16b, \s0\().16b, \s1\().16b, \s2\().16b
.endm

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
    str sAba, [input_addr, 8*(\num*(0)  +\idx)]
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
    ldr sAba, [input_addr, 8*(\num*(0)  +\idx)]
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

#define STACK_LOCS 40

#define STACK_SIZE (16*6 + 8*8 + 6*8 + (STACK_LOCS) * 8)
#define STACK_BASE_GPRS (6*8)
#define STACK_BASE_VREGS (6*8 + 16*6)
#define STACK_OFFSET_LOCS (16*6 + 8*8 + 6*8)

#define STACK_OFFSET_INPUT (0*8)
#define STACK_OFFSET_CONST_SCALAR (1*8)
#define STACK_OFFSET_CONST_VECTOR (2*8)
#define STACK_OFFSET_COUNT (3*8)
#define STACK_OFFSET_OUTER (4*8)

#define STACK_LOC_0 ((STACK_OFFSET_LOCS) + 0*8)
#define STACK_LOC_1 ((STACK_OFFSET_LOCS) + 1*8)
#define STACK_LOC_2 ((STACK_OFFSET_LOCS) + 2*8)
#define STACK_LOC_3 ((STACK_OFFSET_LOCS) + 3*8)
#define STACK_LOC_4 ((STACK_OFFSET_LOCS) + 4*8)
#define STACK_LOC_5 ((STACK_OFFSET_LOCS) + 5*8)
#define STACK_LOC_6 ((STACK_OFFSET_LOCS) + 6*8)
#define STACK_LOC_7 ((STACK_OFFSET_LOCS) + 7*8)
#define STACK_LOC_8 ((STACK_OFFSET_LOCS) + 8*8)
#define STACK_LOC_9 ((STACK_OFFSET_LOCS) + 9*8)
#define STACK_LOC_10 ((STACK_OFFSET_LOCS) + 10*8)
#define STACK_LOC_11 ((STACK_OFFSET_LOCS) + 11*8)
#define STACK_LOC_12 ((STACK_OFFSET_LOCS) + 12*8)
#define STACK_LOC_13 ((STACK_OFFSET_LOCS) + 13*8)
#define STACK_LOC_14 ((STACK_OFFSET_LOCS) + 14*8)
#define STACK_LOC_15 ((STACK_OFFSET_LOCS) + 15*8)
#define STACK_LOC_16 ((STACK_OFFSET_LOCS) + 16*8)
#define STACK_LOC_17 ((STACK_OFFSET_LOCS) + 17*8)
#define STACK_LOC_18 ((STACK_OFFSET_LOCS) + 18*8)
#define STACK_LOC_19 ((STACK_OFFSET_LOCS) + 19*8)
#define STACK_LOC_20 ((STACK_OFFSET_LOCS) + 20*8)
#define STACK_LOC_21 ((STACK_OFFSET_LOCS) + 21*8)
#define STACK_LOC_22 ((STACK_OFFSET_LOCS) + 22*8)
#define STACK_LOC_23 ((STACK_OFFSET_LOCS) + 23*8)
#define STACK_LOC_24 ((STACK_OFFSET_LOCS) + 24*8)
#define STACK_LOC_25 ((STACK_OFFSET_LOCS) + 25*8)
#define STACK_LOC_26 ((STACK_OFFSET_LOCS) + 26*8)
#define STACK_LOC_27 ((STACK_OFFSET_LOCS) + 27*8)
#define STACK_LOC_28 ((STACK_OFFSET_LOCS) + 28*8)
#define STACK_LOC_29 ((STACK_OFFSET_LOCS) + 29*8)
#define STACK_LOC_30 ((STACK_OFFSET_LOCS) + 30*8)
#define STACK_LOC_31 ((STACK_OFFSET_LOCS) + 31*8)
#define STACK_LOC_32 ((STACK_OFFSET_LOCS) + 32*8)
#define STACK_LOC_33 ((STACK_OFFSET_LOCS) + 33*8)
#define STACK_LOC_34 ((STACK_OFFSET_LOCS) + 34*8)
#define STACK_LOC_35 ((STACK_OFFSET_LOCS) + 35*8)
#define STACK_LOC_36 ((STACK_OFFSET_LOCS) + 36*8)
#define STACK_LOC_37 ((STACK_OFFSET_LOCS) + 37*8)
#define STACK_LOC_38 ((STACK_OFFSET_LOCS) + 38*8)
#define STACK_LOC_39 ((STACK_OFFSET_LOCS) + 39*8)

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

.macro  chi_step_ror out, a, b, c, r1, r2
    bic X<tmp>, \b\(), \c\(), ror #\r1
    eor \out\(), X<tmp>, \a\(), ror #\r2
.endm

.macro  chi_step_ror2 out, a, b, c, r1, r2
    bic X<tmp>, \b\(), \c\(), ror #\r1
    eor \out\(), \a\(), X<tmp>, ror #\r2
.endm

.macro scalar_round_initial
    eor5 X<sC0>, sAma, sAsa, sAba, sAga, sAka
    eor5 X<sC1>, sAme, sAse, sAbe, sAge, sAke
    eor5 X<sC2>, sAmi, sAsi, sAbi, sAgi, sAki
    eor5 X<sC3>, sAmo, sAso, sAbo, sAgo, sAko
    eor5 X<sC4>, sAmu, sAsu, sAbu, sAgu, sAku

    eor X<sE1>, X<sC0>, X<sC2>, ror #63
    eor X<sE3>, X<sC2>, X<sC4>, ror #63
    eor X<sE0>, X<sC4>, X<sC1>, ror #63
    eor X<sE2>, X<sC1>, X<sC3>, ror #63
    eor X<sE4>, X<sC3>, X<sC0>, ror #63

    eor X<sBba>, sAba, X<sE0>
    eor X<sBsa>, sAbi, X<sE2>
    eor X<sBbi>, sAki, X<sE2>
    eor X<sBki>, sAko, X<sE3>
    eor X<sBko>, sAmu, X<sE4>
    eor X<sBmu>, sAso, X<sE3>
    eor X<sBso>, sAma, X<sE0>
    eor X<sBka>, sAbe, X<sE1>
    eor X<sBse>, sAgo, X<sE3>
    eor X<sBgo>, sAme, X<sE1>
    eor X<sBke>, sAgi, X<sE2>
    eor X<sBgi>, sAka, X<sE0>
    eor X<sBga>, sAbo, X<sE3>
    eor X<sBbo>, sAmo, X<sE3>
    eor X<sBmo>, sAmi, X<sE2>
    eor X<sBmi>, sAke, X<sE1>
    eor X<sBge>, sAgu, X<sE4>
    eor X<sBgu>, sAsi, X<sE2>
    eor X<sBsi>, sAku, X<sE4>
    eor X<sBku>, sAsa, X<sE0>
    eor X<sBma>, sAbu, X<sE4>
    eor X<sBbu>, sAsu, X<sE4>
    eor X<sBsu>, sAse, X<sE1>
    eor X<sBme>, sAga, X<sE0>
    eor X<sBbe>, sAge, X<sE1>

    ldr X<caddr>, [sp, #STACK_OFFSET_CONST_SCALAR]
    ldr X<cur_const>, [X<caddr>]
    mov X<count>, #1
    str X<count>, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

    chi_step_ror sAga, X<sBga>, X<sBgi>, X<sBge>, 47, 39
    chi_step_ror sAge, X<sBge>, X<sBgo>, X<sBgi>, 42, 25
    chi_step_ror sAgi, X<sBgi>, X<sBgu>, X<sBgo>, 16, 58
    chi_step_ror sAgo, X<sBgo>, X<sBga>, X<sBgu>, 31, 47
    chi_step_ror sAgu, X<sBgu>, X<sBge>, X<sBga>, 56, 23
    chi_step_ror sAka, X<sBka>, X<sBki>, X<sBke>, 19, 24
    chi_step_ror sAke, X<sBke>, X<sBko>, X<sBki>, 47, 2
    chi_step_ror sAki, X<sBki>, X<sBku>, X<sBko>, 10, 57
    chi_step_ror sAko, X<sBko>, X<sBka>, X<sBku>, 47, 57
    chi_step_ror sAku, X<sBku>, X<sBke>, X<sBka>, 5,  52
    chi_step_ror sAma, X<sBma>, X<sBmi>, X<sBme>, 38, 47
    chi_step_ror sAme, X<sBme>, X<sBmo>, X<sBmi>, 5,  43
    chi_step_ror sAmi, X<sBmi>, X<sBmu>, X<sBmo>, 41, 46
    chi_step_ror sAmo, X<sBmo>, X<sBma>, X<sBmu>, 35, 12
    chi_step_ror sAmu, X<sBmu>, X<sBme>, X<sBma>, 9,  44
    chi_step_ror sAsa, X<sBsa>, X<sBsi>, X<sBse>, 48, 41
    chi_step_ror sAse, X<sBse>, X<sBso>, X<sBsi>, 2,  50
    chi_step_ror sAsi, X<sBsi>, X<sBsu>, X<sBso>, 25, 27
    chi_step_ror sAso, X<sBso>, X<sBsa>, X<sBsu>, 60, 21
    chi_step_ror sAsu, X<sBsu>, X<sBse>, X<sBsa>, 57, 53
    chi_step_ror2 sAba, X<sBba>, X<sBbi>, X<sBbe>, 63, 21
    chi_step_ror sAbe, X<sBbe>, X<sBbo>, X<sBbi>, 42, 41
    chi_step_ror sAbi, X<sBbi>, X<sBbu>, X<sBbo>, 57, 35
    chi_step_ror sAbo, X<sBbo>, X<sBba>, X<sBbu>, 50, 43
    chi_step_ror sAbu, X<sBbu>, X<sBbe>, X<sBba>, 44, 30

    eor sAba, sAba, X<cur_const>
.endm

.macro vector_round
   eor3_m0 C0, vAba, vAga, vAka
   eor3_m0 C0, C0, vAma,  vAsa
   eor3_m0 C1, vAbe, vAge, vAke
   eor3_m0 C1, C1, vAme,  vAse
   eor3_m0 C2, vAbi, vAgi, vAki
   eor3_m0 C2, C2, vAmi,  vAsi
   eor3_m0 C3, vAbo, vAgo, vAko
   eor3_m0 C3, C3, vAmo,  vAso
   eor3_m0 C4, vAbu, vAgu, vAku
   eor3_m0 C4, C4, vAmu,  vAsu
   rax1_m0 E1, C0, C2
   rax1_m0 E3, C2, C4
   rax1_m0 E0, C4, C1
   rax1_m0 E2, C1, C3
   rax1_m0 E4, C3, C0
   eor vAba_.16b, vAba.16b, E0.16b
   xar_m0 vAsa_, vAbi, E2, 2
   xar_m0 vAbi_, vAki, E2, 21
   xar_m0 vAki_, vAko, E3, 39
   xar_m0 vAko_, vAmu, E4, 56
   xar_m0 vAmu_, vAso, E3, 8
   xar_m0 vAso_, vAma, E0, 23
   xar_m0 vAka_, vAbe, E1, 63
   xar_m0 vAse_, vAgo, E3, 9
   xar_m0 vAgo_, vAme, E1, 19
   xar_m0 vAke_, vAgi, E2, 58
   xar_m0 vAgi_, vAka, E0, 61
   xar_m0 vAga_, vAbo, E3, 36
   xar_m0 vAbo_, vAmo, E3, 43
   xar_m0 vAmo_, vAmi, E2, 49
   xar_m0 vAmi_, vAke, E1, 54
   xar_m0 vAge_, vAgu, E4, 44
   xar_m0 vAgu_, vAsi, E2, 3
   xar_m0 vAsi_, vAku, E4, 25
   xar_m0 vAku_, vAsa, E0, 46
   xar_m0 vAma_, vAbu, E4, 37
   xar_m0 vAbu_, vAsu, E4, 50
   xar_m0 vAsu_, vAse, E1, 62
   xar_m0 vAme_, vAga, E0, 28
   xar_m0 vAbe_, vAge, E1, 20
   ldr tmp, [sp, #STACK_OFFSET_CONST_VECTOR] // @slothy:reads=STACK_OFFSET_CONST_VECTOR
   ld1r {v28.2d}, [tmp], #8
   str tmp, [sp, #STACK_OFFSET_CONST_VECTOR] // @slothy:writes=STACK_OFFSET_CONST_VECTOR
   bcax_m0 vAga, vAga_, vAgi_, vAge_
   bcax_m0 vAge, vAge_, vAgo_, vAgi_
   bcax_m0 vAgi, vAgi_, vAgu_, vAgo_
   bcax_m0 vAgo, vAgo_, vAga_, vAgu_
   bcax_m0 vAgu, vAgu_, vAge_, vAga_
   bcax_m0 vAka, vAka_, vAki_, vAke_
   bcax_m0 vAke, vAke_, vAko_, vAki_
   bcax_m0 vAki, vAki_, vAku_, vAko_
   bcax_m0 vAko, vAko_, vAka_, vAku_
   bcax_m0 vAku, vAku_, vAke_, vAka_
   bcax_m0 vAma, vAma_, vAmi_, vAme_
   bcax_m0 vAme, vAme_, vAmo_, vAmi_
   bcax_m0 vAmi, vAmi_, vAmu_, vAmo_
   bcax_m0 vAmo, vAmo_, vAma_, vAmu_
   bcax_m0 vAmu, vAmu_, vAme_, vAma_
   bcax_m0 vAsa, vAsa_, vAsi_, vAse_
   bcax_m0 vAse, vAse_, vAso_, vAsi_
   bcax_m0 vAsi, vAsi_, vAsu_, vAso_
   bcax_m0 vAso, vAso_, vAsa_, vAsu_
   bcax_m0 vAsu, vAsu_, vAse_, vAsa_
   bcax_m0 vAba, vAba_, vAbi_, vAbe_
   bcax_m0 vAbe, vAbe_, vAbo_, vAbi_
   bcax_m0 vAbi, vAbi_, vAbu_, vAbo_
   bcax_m0 vAbo, vAbo_, vAba_, vAbu_
   bcax_m0 vAbu, vAbu_, vAbe_, vAba_
   eor vAba.16b, vAba.16b, v28.16b
.endm

.macro scalar_round_noninitial

    eor X<sC0>, sAba,   sAga, ror #61
    eor X<sC0>, X<sC0>, sAma, ror #54
    eor X<sC0>, X<sC0>, sAka, ror #39
    eor X<sC0>, X<sC0>, sAsa, ror #25

    eor X<sC1>, sAke,   sAme, ror #57
    eor X<sC1>, X<sC1>, sAbe, ror #51
    eor X<sC1>, X<sC1>, sAse, ror #31
    eor X<sC1>, X<sC1>, sAge, ror #27

    eor X<sC2>, sAsi,   sAbi, ror #52
    eor X<sC2>, X<sC2>, sAki, ror #48
    eor X<sC2>, X<sC2>, sAmi, ror #10
    eor X<sC2>, X<sC2>, sAgi, ror #5

    eor X<sC3>, sAbo,   sAko, ror #63
    eor X<sC3>, X<sC3>, sAmo, ror #37
    eor X<sC3>, X<sC3>, sAgo, ror #36
    eor X<sC3>, X<sC3>, sAso, ror #2

    eor X<sC4>, sAku,   sAgu, ror #50
    eor X<sC4>, X<sC4>, sAmu, ror #34
    eor X<sC4>, X<sC4>, sAbu, ror #26
    eor X<sC4>, X<sC4>, sAsu, ror #15

    eor X<sE1>, X<sC0>, X<sC2>, ror #61
    ror X<sC2>, X<sC2>, #62
    eor X<sE3>, X<sC2>, X<sC4>, ror #57
    ror X<sC4>, X<sC4>, #58
    eor X<sE0>, X<sC4>, X<sC1>, ror #55
    ror X<sC1>, X<sC1>, #56
    eor X<sE2>, X<sC1>, X<sC3>, ror #63
    eor X<sE4>, X<sC3>, X<sC0>, ror #63

    eor X<sBba>, X<sE0>, sAba
    eor X<sBsa>, X<sE2>, sAbi, ror #50
    eor X<sBbi>, X<sE2>, sAki, ror #46
    eor X<sBki>, X<sE3>, sAko, ror #63
    eor X<sBko>, X<sE4>, sAmu, ror #28
    eor X<sBmu>, X<sE3>, sAso, ror #2
    eor X<sBso>, X<sE0>, sAma, ror #54
    eor X<sBka>, X<sE1>, sAbe, ror #43
    eor X<sBse>, X<sE3>, sAgo, ror #36
    eor X<sBgo>, X<sE1>, sAme, ror #49
    eor X<sBke>, X<sE2>, sAgi, ror #3
    eor X<sBgi>, X<sE0>, sAka, ror #39
    eor X<sBga>, X<sE3>, sAbo
    eor X<sBbo>, X<sE3>, sAmo, ror #37
    eor X<sBmo>, X<sE2>, sAmi, ror #8
    eor X<sBmi>, X<sE1>, sAke, ror #56
    eor X<sBge>, X<sE4>, sAgu, ror #44
    eor X<sBgu>, X<sE2>, sAsi, ror #62
    eor X<sBsi>, X<sE4>, sAku, ror #58
    eor X<sBku>, X<sE0>, sAsa, ror #25
    eor X<sBma>, X<sE4>, sAbu, ror #20
    eor X<sBbu>, X<sE4>, sAsu, ror #9
    eor X<sBsu>, X<sE1>, sAse, ror #23
    eor X<sBme>, X<sE0>, sAga, ror #61
    eor X<sBbe>, X<sE1>, sAge, ror #19

    ldr X<caddr>, [sp, #STACK_OFFSET_CONST_SCALAR]
    ldr X<count>, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT
    ldr X<cur_const>, [X<caddr>, W<count>, UXTW #3]
    add X<count>, X<count>, #1
    cmp X<count>, #(KECCAK_F1600_ROUNDS-1)  // @slothy:ignore_useless_output
    str X<count>, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

    chi_step_ror sAga, X<sBga>, X<sBgi>, X<sBge>, 47, 39
    chi_step_ror sAge, X<sBge>, X<sBgo>, X<sBgi>, 42, 25
    chi_step_ror sAgi, X<sBgi>, X<sBgu>, X<sBgo>, 16, 58
    chi_step_ror sAgo, X<sBgo>, X<sBga>, X<sBgu>, 31, 47
    chi_step_ror sAgu, X<sBgu>, X<sBge>, X<sBga>, 56, 23
    chi_step_ror sAka, X<sBka>, X<sBki>, X<sBke>, 19, 24
    chi_step_ror sAke, X<sBke>, X<sBko>, X<sBki>, 47, 2
    chi_step_ror sAki, X<sBki>, X<sBku>, X<sBko>, 10, 57
    chi_step_ror sAko, X<sBko>, X<sBka>, X<sBku>, 47, 57
    chi_step_ror sAku, X<sBku>, X<sBke>, X<sBka>, 5,  52
    chi_step_ror sAma, X<sBma>, X<sBmi>, X<sBme>, 38, 47
    chi_step_ror sAme, X<sBme>, X<sBmo>, X<sBmi>, 5,  43
    chi_step_ror sAmi, X<sBmi>, X<sBmu>, X<sBmo>, 41, 46
    chi_step_ror sAmo, X<sBmo>, X<sBma>, X<sBmu>, 35, 12
    chi_step_ror sAmu, X<sBmu>, X<sBme>, X<sBma>, 9,  44
    chi_step_ror sAsa, X<sBsa>, X<sBsi>, X<sBse>, 48, 41
    chi_step_ror sAse, X<sBse>, X<sBso>, X<sBsi>, 2,  50
    chi_step_ror sAsi, X<sBsi>, X<sBsu>, X<sBso>, 25, 27
    chi_step_ror sAso, X<sBso>, X<sBsa>, X<sBsu>, 60, 21
    chi_step_ror sAsu, X<sBsu>, X<sBse>, X<sBsa>, 57, 53
    chi_step_ror2 sAba, X<sBba>, X<sBbi>, X<sBbe>, 63, 21
    chi_step_ror sAbe, X<sBbe>, X<sBbo>, X<sBbi>, 42, 41
    chi_step_ror sAbi, X<sBbi>, X<sBbu>, X<sBbo>, 57, 35
    chi_step_ror sAbo, X<sBbo>, X<sBba>, X<sBbu>, 50, 43
    chi_step_ror sAbu, X<sBbu>, X<sBbe>, X<sBba>, 44, 30

    eor sAba, sAba, X<cur_const>
.endm

.macro final_scalar_rotate
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

.global keccak_f1600_x4_v84a_hybrid_slothy_symbolic
.global _keccak_f1600_x4_v84a_hybrid_slothy_symbolic
.text
.align 4

keccak_f1600_x4_v84a_hybrid_slothy_symbolic:
_keccak_f1600_x4_v84a_hybrid_slothy_symbolic:
    alloc_stack
    save_gprs
    save_vregs

    ASM_LOAD(const_addr, round_constants)

    mov outer, #0
    str outer,      [sp, #STACK_OFFSET_OUTER]        // @slothy:writes=STACK_OFFSET_OUTER
    str const_addr, [sp, #STACK_OFFSET_CONST_SCALAR] // @slothy:writes=STACK_OFFSET_CONST_SCALAR
    str const_addr, [sp, #STACK_OFFSET_CONST_VECTOR] // @slothy:writes=STACK_OFFSET_CONST_VECTOR
    str input_addr, [sp, #STACK_OFFSET_INPUT]        // @slothy:writes=STACK_OFFSET_INPUT

    load_input_vector 2,1 // Vector input
    load_input_scalar 4,0 // First scalar input

 initial:
    scalar_round_initial    // @slothy:interleaving_class=0
    scalar_round_noninitial // @slothy:interleaving_class=0
    vector_round            // @slothy:interleaving_class=1
 loop:
    scalar_round_noninitial // @slothy:interleaving_class=0
    scalar_round_noninitial // @slothy:interleaving_class=0
    vector_round            // @slothy:interleaving_class=1
 loop_end:
    ble loop
    final_scalar_rotate

    // Read outer loop flag: We repeat the above twice
    ldr outer, [sp, #STACK_OFFSET_OUTER]      // @slothy:reads=STACK_OFFSET_OUTER
    cmp outer, #1
    beq done

    // Update outer loop flag
    mov outer, #1
    str outer, [sp, #STACK_OFFSET_OUTER]      // @slothy:writes=STACK_OFFSET_OUTER

    ldr input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:reads=STACK_OFFSET_INPUT
    store_input_scalar 4,0 // Store first scalar data
    load_input_scalar  4,1 // Load second scalar input

    b initial
done:

    ldr input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:reads=STACK_OFFSET_INPUT
    store_input_scalar 4,1
    store_input_vector 2,1

    restore_vregs
    restore_gprs
    free_stack
    ret

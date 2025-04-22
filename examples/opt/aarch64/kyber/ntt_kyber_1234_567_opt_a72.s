///
/// Copyright (c) 2022 Arm Limited
/// Copyright (c) 2022 Hanno Becker
/// Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
/// SPDX-License-Identifier: MIT
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///

// Needed to provide ASM_LOAD directive
#include <hal_env.h>

// NOTE
// We use a lot of trivial macros to simplify the parsing burden for Slothy
// The macros are not unfolded by Slothy and thus interpreted as instructions,
// which are easier to parse due to e.g. the lack of size specifiers and simpler
// syntax for pre and post increment for loads and stores.
//
// Eventually, NeLight should include a proper parser for AArch64,
// but for initial investigations, the below is enough.

.macro ldr_vo vec, base, offset                    // slothy:no-unfold
        ldr qform_\vec, [\base, \offset]
.endm
.macro ldr_vi vec, base, inc                        // slothy:no-unfold
        ldr qform_\vec, [\base], \inc
.endm
.macro str_vo vec, base, offset                     // slothy:no-unfold
        str qform_\vec, [\base, \offset]
.endm
.macro str_vi vec, base, inc                        // slothy:no-unfold
        str qform_\vec, [\base], \inc
.endm
.macro vqrdmulh d,a,b
        sqrdmulh \d\().8h, \a\().8h, \b\().8h
.endm
.macro vmla d,a,b
        mla \d\().8h, \a\().8h, \b\().8h
.endm
.macro vqrdmulhq d,a,b,i
        sqrdmulh \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro vqdmulhq d,a,b,i
        sqdmulh \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro vmulq d,a,b,i
        mul \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro vmlaq d,a,b,i
        mla \d\().8h, \a\().8h, \b\().h[\i]
.endm

.macro mulmodq dst, src, const, idx0, idx1
        vmulq       \dst,  \src, \const, \idx0
        vqrdmulhq   \src,  \src, \const, \idx1
        vmla        \dst,  \src, modulus
.endm

.macro mulmod dst, src, const, const_twisted
        mul        \dst\().8h,  \src\().8h, \const\().8h
        vqrdmulh   \src,  \src, \const_twisted
        vmlsq      \dst,  \src, consts, 0
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq  tmp, \b, \root, \idx0, \idx1
        sub     \b\().8h,    \a\().8h, tmp.8h
        add     \a\().8h,    \a\().8h, tmp.8h
.endm

.macro mulmod_v dst, src, const, const_twisted
        vmul        \dst,  \src, \const
        vqrdmulh    \src,  \src, \const_twisted
        vmla        \dst,  \src, modulus
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod  tmp, \b, \root, \root_twisted
        sub    \b\().8h,    \a\().8h, tmp.8h
        add    \a\().8h,    \a\().8h, tmp.8h
.endm

.macro barrett_reduce a, barrett_const, barrett_const_idx
        vqdmulhq t0, \a, \barrett_const, \barrett_const_idx
        srshr    t0.8H, t0.8H, #11
        vmla     \a, t0, modulus
.endm

.macro load_roots_123
        ldr_vi root0, r_ptr0, 32
        ldr_vo root1, r_ptr0, -16
.endm

.macro load_next_roots_45 root0, r_ptr0
        ldr_vi \root0, \r_ptr0, 16
.endm

.macro load_next_roots_67 root0, root0_tw, root1, root1_tw, root2, root2_tw, r_ptr1
        ldr_vi \root0,    \r_ptr1, (6*16)
        ldr_vo \root0_tw, \r_ptr1, (-6*16 + 1*16)
        ldr_vo \root1,    \r_ptr1, (-6*16 + 2*16)
        ldr_vo \root1_tw, \r_ptr1, (-6*16 + 3*16)
        ldr_vo \root2,    \r_ptr1, (-6*16 + 4*16)
        ldr_vo \root2_tw, \r_ptr1, (-6*16 + 5*16)
.endm

.macro transpose4 data
        trn1 t0.4s, \data\()0\().4s, \data\()1\().4s
        trn2 t1.4s, \data\()0\().4s, \data\()1\().4s
        trn1 t2.4s, \data\()2\().4s, \data\()3\().4s
        trn2 t3.4s, \data\()2\().4s, \data\()3\().4s

        trn2 \data\()2\().2d, t0.2d, t2.2d
        trn2 \data\()3\().2d, t1.2d, t3.2d
        trn1 \data\()0\().2d, t0.2d, t2.2d
        trn1 \data\()1\().2d, t1.2d, t3.2d
.endm

.macro save_gprs // slothy:no-unfold
        sub sp, sp, #(16*6)
        stp x19, x20, [sp, #16*0]
        stp x19, x20, [sp, #16*0]
        stp x21, x22, [sp, #16*1]
        stp x23, x24, [sp, #16*2]
        stp x25, x26, [sp, #16*3]
        stp x27, x28, [sp, #16*4]
        str x29, [sp, #16*5]
.endm

.macro restore_gprs // slothy:no-unfold
        ldp x19, x20, [sp, #16*0]
        ldp x21, x22, [sp, #16*1]
        ldp x23, x24, [sp, #16*2]
        ldp x25, x26, [sp, #16*3]
        ldp x27, x28, [sp, #16*4]
        ldr x29, [sp, #16*5]
        add sp, sp, #(16*6)
.endm

.macro save_vregs // slothy:no-unfold
        sub sp, sp, #(16*4)
        stp  d8,  d9, [sp, #16*0]
        stp d10, d11, [sp, #16*1]
        stp d12, d13, [sp, #16*2]
        stp d14, d15, [sp, #16*3]
.endm

.macro restore_vregs // slothy:no-unfold
        ldp  d8,  d9, [sp, #16*0]
        ldp d10, d11, [sp, #16*1]
        ldp d12, d13, [sp, #16*2]
        ldp d14, d15, [sp, #16*3]
        add sp, sp, #(16*4)
.endm

#define STACK_SIZE 16
#define STACK0 0

.macro restore a, loc     // slothy:no-unfold
        ldr \a, [sp, #\loc\()]
.endm
.macro save loc, a        // slothy:no-unfold
        str \a, [sp, #\loc\()]
.endm
.macro push_stack // slothy:no-unfold
        save_gprs
        save_vregs
        sub sp, sp, #STACK_SIZE
.endm

.macro pop_stack // slothy:no-unfold
        add sp, sp, #STACK_SIZE
        restore_vregs
        restore_gprs
.endm

.data
.p2align 4
roots:
#include "ntt_kyber_1234_567_twiddles.s"
.text

        .global ntt_kyber_1234_567_opt_a72
        .global _ntt_kyber_1234_567_opt_a72

.p2align 4
modulus_addr:       .quad -3329
barrett_const_addr: .quad 20159
ntt_kyber_1234_567_opt_a72:
_ntt_kyber_1234_567_opt_a72:
        push_stack

        in      .req x0
        inp     .req x1
        count   .req x2
        r_ptr0  .req x3
        r_ptr1  .req x4
        xtmp    .req x5

        src0      .req x6
        src1      .req x7
        src2      .req x8
        src3      .req x9
        src4      .req x10
        src5      .req x11
        src6      .req x12
        src7      .req x13
        src8      .req x14
        src9      .req x15
        src10     .req x16
        src11     .req x17
        src12     .req x18
        src13     .req x19
        src14     .req x20
        src15     .req x21

        qform_v0  .req q0
        qform_v1  .req q1
        qform_v2  .req q2
        qform_v3  .req q3
        qform_v4  .req q4
        qform_v5  .req q5
        qform_v6  .req q6
        qform_v7  .req q7
        qform_v8  .req q8
        qform_v9  .req q9
        qform_v10 .req q10
        qform_v11 .req q11
        qform_v12 .req q12
        qform_v13 .req q13
        qform_v14 .req q14
        qform_v15 .req q15
        qform_v16 .req q16
        qform_v17 .req q17
        qform_v18 .req q18
        qform_v19 .req q19
        qform_v20 .req q20
        qform_v21 .req q21
        qform_v22 .req q22
        qform_v23 .req q23
        qform_v24 .req q24
        qform_v25 .req q25
        qform_v26 .req q26
        qform_v27 .req q27
        qform_v28 .req q28
        qform_v29 .req q29
        qform_v30 .req q30
        qform_v31 .req q31

        data0  .req v9
        data1  .req v10
        data2  .req v11
        data3  .req v12
        data4  .req v13
        data5  .req v14
        data6  .req v15
        data7  .req v16
        data8  .req v17
        data9  .req v18
        data10 .req v19
        data11 .req v20
        data12 .req v21
        data13 .req v22
        data14 .req v23
        data15 .req v24

        qform_data0  .req q9
        qform_data1  .req q10
        qform_data2  .req q11
        qform_data3  .req q12
        qform_data4  .req q13
        qform_data5  .req q14
        qform_data6  .req q15
        qform_data7  .req q16
        qform_data8  .req q17
        qform_data9  .req q18
        qform_data10 .req q19
        qform_data11 .req q20
        qform_data12 .req q21
        qform_data13 .req q22
        qform_data14 .req q23
        qform_data15 .req q24

        root0    .req v0
        root1    .req v1
        root2    .req v2
        root3    .req v3
        root0_tw .req v4
        root1_tw .req v5
        root2_tw .req v6
        root3_tw .req v7

        qform_root0    .req q0
        qform_root1    .req q1
        qform_root2    .req q2
        qform_root3    .req q3
        qform_root0_tw .req q4
        qform_root1_tw .req q5
        qform_root2_tw .req q6
        qform_root3_tw .req q7

        tmp .req v25
        t0  .req v26
        t1  .req v27
        t2  .req v28
        t3  .req v29

        barrett_const .req v8
        modulus .req v30

        ASM_LOAD(r_ptr0, roots)

        ASM_LOAD(xtmp, modulus_addr)
        ld1r {modulus.8h}, [xtmp]

        save STACK0, in

        add  src0, x0,  #32*0
        add  src8, x0,  #32*8

        ld1 { root0.8H,  root1.8H,  root2.8H,  root3.8H}, [r_ptr0], #64

        mov count, #2

        .p2align 2
        ldr_vo v26, x6, 0
        ldr_vo v4, x14, 0
        ldr_vo v16, x6, 64
        ldr_vo v21, x6, 32
        ldr_vo v31, x6, 96
        ldr_vo v7, x6, 128
        ldr_vo v9, x6, 192
        ldr_vo v17, x6, 160
        ldr_vo v19, x6, 224
        sqrdmulh v24.8H, v4.8H, v0.H[1]
        ldr_vo v28, x14, 32
        ldr_vo v15, x14, 64
        ldr_vo v5, x14, 96
        mul v4.8H, v4.8H, v0.H[0]
        ldr_vo v18, x14, 128
        ldr_vo v8, x14, 160
        ldr_vo v20, x14, 192
        mla v4.8H, v24.8H, v30.8H
        sqrdmulh v24.8H, v15.8H, v0.H[1]
        mul v10.8H, v18.8H, v0.H[0]
        ldr_vo v25, x14, 224
        sqrdmulh v18.8H, v18.8H, v0.H[1]
        mul v29.8H, v15.8H, v0.H[0]
        mla v29.8H, v24.8H, v30.8H
        sqrdmulh v6.8H, v20.8H, v0.H[1]
        mul v20.8H, v20.8H, v0.H[0]
        mla v20.8H, v6.8H, v30.8H
        mla v10.8H, v18.8H, v30.8H
        sub v15.8H, v9.8H, v20.8H
        sqrdmulh v6.8H, v8.8H, v0.H[1]
        mul v24.8H, v8.8H, v0.H[0]
        add v22.8H, v7.8H, v10.8H
        sub v11.8H, v7.8H, v10.8H
        add v8.8H, v9.8H, v20.8H
        mla v24.8H, v6.8H, v30.8H
        sub v27.8H, v26.8H, v4.8H
        sqrdmulh v10.8H, v25.8H, v0.H[1]
        mul v25.8H, v25.8H, v0.H[0]
        mla v25.8H, v10.8H, v30.8H
        add v4.8H, v26.8H, v4.8H
        sub v26.8H, v17.8H, v24.8H
        add v9.8H, v17.8H, v24.8H
        mul v24.8H, v15.8H, v0.H[4]
        sub v12.8H, v16.8H, v29.8H
        sqrdmulh v15.8H, v15.8H, v0.H[5]
        add v16.8H, v16.8H, v29.8H
        add v18.8H, v19.8H, v25.8H
        sub v19.8H, v19.8H, v25.8H
        sqrdmulh v7.8H, v28.8H, v0.H[1]
        mul v17.8H, v28.8H, v0.H[0]
        sqrdmulh v28.8H, v8.8H, v0.H[3]
        mul v8.8H, v8.8H, v0.H[2]
        sqrdmulh v20.8H, v5.8H, v0.H[1]
        mul v5.8H, v5.8H, v0.H[0]
        sqrdmulh v6.8H, v22.8H, v0.H[3]
        mul v22.8H, v22.8H, v0.H[2]
        sqrdmulh v14.8H, v11.8H, v0.H[5]
        mul v29.8H, v11.8H, v0.H[4]
        mla v17.8H, v7.8H, v30.8H
        mla v5.8H, v20.8H, v30.8H
        mla v29.8H, v14.8H, v30.8H
        add v7.8H, v21.8H, v17.8H
        sub v21.8H, v21.8H, v17.8H
        mla v22.8H, v6.8H, v30.8H
        sub v20.8H, v31.8H, v5.8H
        add v31.8H, v31.8H, v5.8H
        mla v24.8H, v15.8H, v30.8H
        sub v17.8H, v27.8H, v29.8H
        add v15.8H, v27.8H, v29.8H
        mla v8.8H, v28.8H, v30.8H
        add v28.8H, v4.8H, v22.8H
        sub v4.8H, v4.8H, v22.8H
        mul v5.8H, v9.8H, v0.H[2]
        add v22.8H, v12.8H, v24.8H
        sub v24.8H, v12.8H, v24.8H
        sqrdmulh v9.8H, v9.8H, v0.H[3]
        add v12.8H, v16.8H, v8.8H
        sub v27.8H, v16.8H, v8.8H
        sqrdmulh v23.8H, v12.8H, v0.H[7]
        mul v29.8H, v12.8H, v0.H[6]
        mla v29.8H, v23.8H, v30.8H
        sqrdmulh v16.8H, v18.8H, v0.H[3]
        sub v13.8H, v28.8H, v29.8H
        mul v23.8H, v18.8H, v0.H[2]
        add v10.8H, v28.8H, v29.8H
        mla v23.8H, v16.8H, v30.8H
        mul v16.8H, v19.8H, v0.H[4]
        add v11.8H, v31.8H, v23.8H
        mla v5.8H, v9.8H, v30.8H
        mul v14.8H, v26.8H, v0.H[4]
        sqrdmulh v28.8H, v11.8H, v0.H[7]
        sub v29.8H, v7.8H, v5.8H
        mul v25.8H, v11.8H, v0.H[6]
        add v7.8H, v7.8H, v5.8H
        mla v25.8H, v28.8H, v30.8H
        sqrdmulh v26.8H, v26.8H, v0.H[5]
        sub count, count, #1
.p2align 2
layer1234_start:
        ldr_vo v18, x14, 112
        sub v8.8H, v7.8H, v25.8H
        sqrdmulh v11.8H, v24.8H, v1.H[5]
        sub v12.8H, v31.8H, v23.8H
        ldr_vo v9, x14, 208                      // gap(s) to follow
        sqrdmulh v23.8H, v22.8H, v1.H[3]         // gap(s) to follow
        sqrdmulh v31.8H, v8.8H, v2.H[1]          // gap(s) to follow
        mul v6.8H, v8.8H, v2.H[0]                // gap(s) to follow
        mla v6.8H, v31.8H, v30.8H                // gap(s) to follow
        mul v31.8H, v22.8H, v1.H[2]              // gap(s) to follow
        mla v31.8H, v23.8H, v30.8H               // gap(s) to follow
        mul v23.8H, v24.8H, v1.H[4]
        add v24.8H, v7.8H, v25.8H                // gap(s) to follow
        sqrdmulh v7.8H, v9.8H, v0.H[1]           // gap(s) to follow
        sqrdmulh v8.8H, v24.8H, v1.H[7]          // gap(s) to follow
        mul v5.8H, v9.8H, v0.H[0]                // gap(s) to follow
        mla v5.8H, v7.8H, v30.8H                 // gap(s) to follow
        mla v23.8H, v11.8H, v30.8H               // gap(s) to follow
        mla v14.8H, v26.8H, v30.8H               // gap(s) to follow
        sqrdmulh v7.8H, v18.8H, v0.H[1]
        add v26.8H, v17.8H, v23.8H               // gap(s) to follow
        sub v28.8H, v17.8H, v23.8H               // gap(s) to follow
        add v25.8H, v21.8H, v14.8H
        sqrdmulh v19.8H, v19.8H, v0.H[5]         // gap(s) to follow
        sub v23.8H, v21.8H, v14.8H               // gap(s) to follow
        mul v21.8H, v18.8H, v0.H[0]              // gap(s) to follow
        mla v21.8H, v7.8H, v30.8H                // gap(s) to follow
        mla v16.8H, v19.8H, v30.8H
        sub v19.8H, v15.8H, v31.8H               // gap(s) to follow
        sqrdmulh v7.8H, v27.8H, v1.H[1]          // gap(s) to follow
        mul v22.8H, v27.8H, v1.H[0]
        sub v14.8H, v20.8H, v16.8H               // gap(s) to follow
        add v17.8H, v20.8H, v16.8H               // gap(s) to follow
        add v27.8H, v15.8H, v31.8H
        mul v9.8H, v24.8H, v1.H[6]               // gap(s) to follow
        sub v11.8H, v13.8H, v6.8H                // gap(s) to follow
        mla v9.8H, v8.8H, v30.8H
        add v31.8H, v13.8H, v6.8H                // gap(s) to follow
        ldr_vo v6, x14, 144
        sqrdmulh v18.8H, v17.8H, v1.H[3]
        sub v24.8H, v10.8H, v9.8H
        add v16.8H, v10.8H, v9.8H
        ldr_vo v20, x6, 112
        str_vo v11, x6, 96
        mul v13.8H, v17.8H, v1.H[2]
        str_vo v31, x6, 64
        ldr_vo v15, x6, 208
        str_vo v24, x6, 32                       // gap(s) to follow
        mla v13.8H, v18.8H, v30.8H
        str_vi v16, x6, 16                       // gap(s) to follow
        mla v22.8H, v7.8H, v30.8H
        add v24.8H, v15.8H, v5.8H                // gap(s) to follow
        sub v16.8H, v15.8H, v5.8H                // gap(s) to follow
        mul v10.8H, v12.8H, v1.H[0]
        add v11.8H, v25.8H, v13.8H               // gap(s) to follow
        sub v8.8H, v25.8H, v13.8H                // gap(s) to follow
        add v18.8H, v4.8H, v22.8H
        sqrdmulh v31.8H, v14.8H, v1.H[5]         // gap(s) to follow
        sub v15.8H, v4.8H, v22.8H
        ldr_vo v22, x14, 48
        mul v13.8H, v14.8H, v1.H[4]              // gap(s) to follow
        mla v13.8H, v31.8H, v30.8H
        add v31.8H, v20.8H, v21.8H               // gap(s) to follow
        sqrdmulh v25.8H, v12.8H, v1.H[1]
        ldr_vo v12, x14, 176
        sub v20.8H, v20.8H, v21.8H               // gap(s) to follow
        add v4.8H, v23.8H, v13.8H
        mul v17.8H, v8.8H, v3.H[0]               // gap(s) to follow
        sub v13.8H, v23.8H, v13.8H               // gap(s) to follow
        mla v10.8H, v25.8H, v30.8H               // gap(s) to follow
        sqrdmulh v23.8H, v4.8H, v3.H[3]          // gap(s) to follow
        sqrdmulh v7.8H, v11.8H, v2.H[7]          // gap(s) to follow
        sub v21.8H, v29.8H, v10.8H
        add v9.8H, v29.8H, v10.8H                // gap(s) to follow
        mul v10.8H, v4.8H, v3.H[2]               // gap(s) to follow
        mla v10.8H, v23.8H, v30.8H               // gap(s) to follow
        ldr_vo v23, x14, 80
        ldr_vo v5, x14, 240
        add v14.8H, v26.8H, v10.8H
        mul v29.8H, v22.8H, v0.H[0]              // gap(s) to follow
        sub v10.8H, v26.8H, v10.8H
        sqrdmulh v25.8H, v22.8H, v0.H[1]         // gap(s) to follow
        mul v22.8H, v5.8H, v0.H[0]
        str_vo v14, x14, 128                     // gap(s) to follow
        str_vo v10, x14, 160                     // gap(s) to follow
        sqrdmulh v10.8H, v23.8H, v0.H[1]         // gap(s) to follow
        sqrdmulh v4.8H, v12.8H, v0.H[1]          // gap(s) to follow
        sqrdmulh v14.8H, v8.8H, v3.H[1]          // gap(s) to follow
        sqrdmulh v26.8H, v13.8H, v3.H[5]         // gap(s) to follow
        mul v8.8H, v23.8H, v0.H[0]               // gap(s) to follow
        mla v8.8H, v10.8H, v30.8H                // gap(s) to follow
        mla v17.8H, v14.8H, v30.8H               // gap(s) to follow
        mul v10.8H, v11.8H, v2.H[6]              // gap(s) to follow
        sub v14.8H, v19.8H, v17.8H               // gap(s) to follow
        mla v10.8H, v7.8H, v30.8H
        add v17.8H, v19.8H, v17.8H               // gap(s) to follow
        mla v29.8H, v25.8H, v30.8H
        str_vo v14, x14, 96
        sub v7.8H, v27.8H, v10.8H
        add v23.8H, v27.8H, v10.8H
        str_vo v17, x14, 64                      // gap(s) to follow
        sqrdmulh v19.8H, v5.8H, v0.H[1]
        ldr_vo v5, x14, 16                       // gap(s) to follow
        str_vo v7, x14, 32                       // gap(s) to follow
        mul v17.8H, v12.8H, v0.H[0]
        str_vi v23, x14, 16                      // gap(s) to follow
        sqrdmulh v10.8H, v5.8H, v0.H[1]          // gap(s) to follow
        mul v25.8H, v5.8H, v0.H[0]               // gap(s) to follow
        sqrdmulh v7.8H, v9.8H, v2.H[3]           // gap(s) to follow
        mul v23.8H, v9.8H, v2.H[2]               // gap(s) to follow
        mla v23.8H, v7.8H, v30.8H                // gap(s) to follow
        mla v17.8H, v4.8H, v30.8H                // gap(s) to follow
        sqrdmulh v4.8H, v21.8H, v2.H[5]          // gap(s) to follow
        ldr_vo v7, x6, 160                       // gap(s) to follow
        sqrdmulh v11.8H, v6.8H, v0.H[1]          // gap(s) to follow
        ldr_vo v9, x6, 224                       // gap(s) to follow
        mla v22.8H, v19.8H, v30.8H               // gap(s) to follow
        sub v12.8H, v18.8H, v23.8H               // gap(s) to follow
        add v5.8H, v18.8H, v23.8H                // gap(s) to follow
        mul v27.8H, v6.8H, v0.H[0]
        sub v6.8H, v7.8H, v17.8H                 // gap(s) to follow
        str_vo v12, x6, 144                      // gap(s) to follow
        mla v27.8H, v11.8H, v30.8H
        str_vo v5, x6, 112
        ldr_vo v12, x6, 32                       // gap(s) to follow
        mul v21.8H, v21.8H, v2.H[4]              // gap(s) to follow
        ldr_vo v23, x6, 0                        // gap(s) to follow
        mla v21.8H, v4.8H, v30.8H
        ldr_vo v4, x6, 128                       // gap(s) to follow
        ldr_vo v5, x6, 64                        // gap(s) to follow
        mla v25.8H, v10.8H, v30.8H               // gap(s) to follow
        mul v13.8H, v13.8H, v3.H[4]
        add v18.8H, v15.8H, v21.8H
        add v11.8H, v4.8H, v27.8H                // gap(s) to follow
        sub v15.8H, v15.8H, v21.8H
        mla v13.8H, v26.8H, v30.8H               // gap(s) to follow
        add v21.8H, v7.8H, v17.8H
        str_vo v18, x6, 176                      // gap(s) to follow
        mul v18.8H, v11.8H, v0.H[2]
        add v7.8H, v9.8H, v22.8H                 // gap(s) to follow
        str_vo v15, x6, 208                      // gap(s) to follow
        sub v19.8H, v28.8H, v13.8H
        sqrdmulh v17.8H, v21.8H, v0.H[3]         // gap(s) to follow
        mul v15.8H, v21.8H, v0.H[2]
        sub v21.8H, v12.8H, v29.8H               // gap(s) to follow
        str_vo v19, x14, 208
        sub v19.8H, v9.8H, v22.8H                // gap(s) to follow
        mla v15.8H, v17.8H, v30.8H
        sub v9.8H, v4.8H, v27.8H                 // gap(s) to follow
        sub v10.8H, v23.8H, v25.8H
        add v14.8H, v23.8H, v25.8H
        sqrdmulh v25.8H, v7.8H, v0.H[3]          // gap(s) to follow
        add v4.8H, v5.8H, v8.8H                  // gap(s) to follow
        mul v23.8H, v7.8H, v0.H[2]
        add v7.8H, v28.8H, v13.8H                // gap(s) to follow
        sqrdmulh v22.8H, v24.8H, v0.H[3]
        sub v8.8H, v5.8H, v8.8H                  // gap(s) to follow
        str_vo v7, x14, 176                      // gap(s) to follow
        mul v26.8H, v24.8H, v0.H[2]              // gap(s) to follow
        mla v26.8H, v22.8H, v30.8H               // gap(s) to follow
        sqrdmulh v24.8H, v16.8H, v0.H[5]         // gap(s) to follow
        mul v22.8H, v16.8H, v0.H[4]              // gap(s) to follow
        sub v27.8H, v4.8H, v26.8H                // gap(s) to follow
        add v4.8H, v4.8H, v26.8H
        mla v22.8H, v24.8H, v30.8H               // gap(s) to follow
        add v26.8H, v12.8H, v29.8H               // gap(s) to follow
        mla v23.8H, v25.8H, v30.8H               // gap(s) to follow
        sqrdmulh v17.8H, v4.8H, v0.H[7]
        add v7.8H, v26.8H, v15.8H                // gap(s) to follow
        sub v29.8H, v26.8H, v15.8H               // gap(s) to follow
        sqrdmulh v12.8H, v11.8H, v0.H[3]         // gap(s) to follow
        mul v13.8H, v4.8H, v0.H[6]               // gap(s) to follow
        add v16.8H, v31.8H, v23.8H               // gap(s) to follow
        sqrdmulh v28.8H, v9.8H, v0.H[5]          // gap(s) to follow
        sqrdmulh v4.8H, v16.8H, v0.H[7]          // gap(s) to follow
        mul v25.8H, v16.8H, v0.H[6]              // gap(s) to follow
        mul v5.8H, v9.8H, v0.H[4]                // gap(s) to follow
        mla v5.8H, v28.8H, v30.8H                // gap(s) to follow
        mla v18.8H, v12.8H, v30.8H               // gap(s) to follow
        mla v13.8H, v17.8H, v30.8H
        sub v17.8H, v10.8H, v5.8H                // gap(s) to follow
        add v15.8H, v10.8H, v5.8H                // gap(s) to follow
        add v5.8H, v14.8H, v18.8H                // gap(s) to follow
        mul v16.8H, v19.8H, v0.H[4]
        sub v24.8H, v8.8H, v22.8H                // gap(s) to follow
        mla v25.8H, v4.8H, v30.8H                // gap(s) to follow
        add v10.8H, v5.8H, v13.8H                // gap(s) to follow
        sqrdmulh v26.8H, v6.8H, v0.H[5]
        sub v4.8H, v14.8H, v18.8H                // gap(s) to follow
        sub v13.8H, v5.8H, v13.8H                // gap(s) to follow
        add v22.8H, v8.8H, v22.8H                // gap(s) to follow
        mul v14.8H, v6.8H, v0.H[4]               // gap(s) to follow
        subs count, count, #1
        cbnz count, layer1234_start
        add v5.8H, v7.8H, v25.8H
        sqrdmulh v19.8H, v19.8H, v0.H[5]
        sub v18.8H, v31.8H, v23.8H
        sub v8.8H, v7.8H, v25.8H
        mul v6.8H, v22.8H, v1.H[2]
        sqrdmulh v9.8H, v5.8H, v1.H[7]
        sqrdmulh v28.8H, v8.8H, v2.H[1]
        mul v7.8H, v8.8H, v2.H[0]
        mla v16.8H, v19.8H, v30.8H
        mla v7.8H, v28.8H, v30.8H
        mul v11.8H, v5.8H, v1.H[6]
        mla v11.8H, v9.8H, v30.8H
        add v31.8H, v13.8H, v7.8H
        sub v5.8H, v13.8H, v7.8H
        sqrdmulh v28.8H, v22.8H, v1.H[3]
        str_vo v31, x6, 64
        mla v14.8H, v26.8H, v30.8H
        str_vo v5, x6, 96
        add v7.8H, v10.8H, v11.8H
        sub v26.8H, v10.8H, v11.8H
        add v31.8H, v20.8H, v16.8H
        sqrdmulh v25.8H, v27.8H, v1.H[1]
        str_vo v26, x6, 32
        sub v8.8H, v20.8H, v16.8H
        mul v16.8H, v27.8H, v1.H[0]
        str_vi v7, x6, 16
        sub v12.8H, v21.8H, v14.8H
        sqrdmulh v26.8H, v24.8H, v1.H[5]
        mul v27.8H, v24.8H, v1.H[4]
        mla v27.8H, v26.8H, v30.8H
        mla v16.8H, v25.8H, v30.8H
        mul v20.8H, v8.8H, v1.H[4]
        add v22.8H, v17.8H, v27.8H
        sub v9.8H, v17.8H, v27.8H
        sub v25.8H, v4.8H, v16.8H
        sqrdmulh v26.8H, v8.8H, v1.H[5]
        add v11.8H, v4.8H, v16.8H
        sqrdmulh v19.8H, v31.8H, v1.H[3]
        mla v20.8H, v26.8H, v30.8H
        mul v23.8H, v31.8H, v1.H[2]
        mla v23.8H, v19.8H, v30.8H
        mla v6.8H, v28.8H, v30.8H
        add v4.8H, v21.8H, v14.8H
        sub v28.8H, v12.8H, v20.8H
        add v8.8H, v12.8H, v20.8H
        sqrdmulh v21.8H, v18.8H, v1.H[1]
        sub v20.8H, v4.8H, v23.8H
        add v26.8H, v4.8H, v23.8H
        mul v27.8H, v18.8H, v1.H[0]
        sub v7.8H, v15.8H, v6.8H
        add v23.8H, v15.8H, v6.8H
        mla v27.8H, v21.8H, v30.8H
        sqrdmulh v4.8H, v26.8H, v2.H[7]
        mul v16.8H, v26.8H, v2.H[6]
        mla v16.8H, v4.8H, v30.8H
        sqrdmulh v4.8H, v20.8H, v3.H[1]
        sub v6.8H, v29.8H, v27.8H
        sqrdmulh v17.8H, v8.8H, v3.H[3]
        mul v24.8H, v20.8H, v3.H[0]
        add v21.8H, v29.8H, v27.8H
        mla v24.8H, v4.8H, v30.8H
        sqrdmulh v5.8H, v6.8H, v2.H[5]
        sub v4.8H, v7.8H, v24.8H
        mul v13.8H, v6.8H, v2.H[4]
        add v27.8H, v23.8H, v16.8H
        sqrdmulh v26.8H, v21.8H, v2.H[3]
        str_vo v4, x14, 96
        sub v6.8H, v23.8H, v16.8H
        str_vi v27, x14, 16
        sqrdmulh v31.8H, v28.8H, v3.H[5]
        mul v23.8H, v21.8H, v2.H[2]
        mla v23.8H, v26.8H, v30.8H
        mul v26.8H, v8.8H, v3.H[2]
        mla v13.8H, v5.8H, v30.8H
        sub v12.8H, v11.8H, v23.8H
        mla v26.8H, v17.8H, v30.8H
        str_vo v12, x6, 144
        mul v4.8H, v28.8H, v3.H[4]
        add v10.8H, v25.8H, v13.8H
        str_vo v6, x14, 16
        sub v6.8H, v25.8H, v13.8H
        mla v4.8H, v31.8H, v30.8H
        sub v16.8H, v22.8H, v26.8H
        str_vo v10, x6, 176
        add v21.8H, v11.8H, v23.8H
        add v11.8H, v22.8H, v26.8H
        add v7.8H, v7.8H, v24.8H
        str_vo v6, x6, 208
        str_vo v16, x14, 144
        sub v23.8H, v9.8H, v4.8H
        add v26.8H, v9.8H, v4.8H
        str_vo v11, x14, 112
        str_vo v21, x6, 112
        str_vo v7, x14, 48
        str_vo v23, x14, 208
        str_vo v26, x14, 176

        restore inp, STACK0
        mov count, #4

        ASM_LOAD(xtmp, barrett_const_addr)
        ld1r {barrett_const.8h}, [xtmp]
        ASM_LOAD(r_ptr1, roots_l456)

        add src0, inp, #256*0
        add src1, inp, #256*1

        .p2align 2
layer567_start:

        ld4 {data8.4S, data9.4S, data10.4S, data11.4S}, [src0]
        ld4 {data12.4S, data13.4S, data14.4S, data15.4S}, [src1]

        trn1_s data0, data8, data12
        trn2_s data4, data8, data12
        trn1_s data1, data9, data13
        trn2_s data5, data9, data13
        trn1_s data2, data10, data14
        trn2_s data6, data10, data14
        trn1_s data3, data11, data15
        trn2_s data7, data11, data15

        // load twiddle factors
        ldr_vi root0,    r_ptr1, 16*14
        ldr_vo root0_tw, r_ptr1, -16*14+16*1
        ldr_vo root1,    r_ptr1, -16*14+16*2
        ldr_vo root1_tw, r_ptr1, -16*14+16*3
        ldr_vo root2,    r_ptr1, -16*14+16*4
        ldr_vo root2_tw, r_ptr1, -16*14+16*5
        ldr_vo root3,    r_ptr1, -16*14+16*6
        ldr_vo root3_tw, r_ptr1, -16*14+16*7

        ldr_vo data8,    r_ptr1, -16*14+16*8
        ldr_vo data9,    r_ptr1, -16*14+16*9
        ldr_vo data10,   r_ptr1, -16*14+16*10
        ldr_vo data11,   r_ptr1, -16*14+16*11
        ldr_vo data12,   r_ptr1, -16*14+16*12
        ldr_vo data13,   r_ptr1, -16*14+16*13

        // butterflies
        ct_butterfly_v data0, data4, root0, root0_tw
        ct_butterfly_v data1, data5, root0, root0_tw
        ct_butterfly_v data2, data6, root0, root0_tw
        ct_butterfly_v data3, data7, root0, root0_tw

        ct_butterfly_v data0, data2, root1, root1_tw
        ct_butterfly_v data1, data3, root1, root1_tw
        ct_butterfly_v data4, data6, root2, root2_tw
        ct_butterfly_v data5, data7, root2, root2_tw

        ct_butterfly_v data0, data1, root3, root3_tw
        ct_butterfly_v data2, data3, data8,  data9
        ct_butterfly_v data4, data5, data10, data11
        ct_butterfly_v data6, data7, data12, data13

        // transpose back
        trn1_s  data8, data0, data4
        trn2_s data12, data0, data4
        trn1_s  data9, data1, data5
        trn2_s data13, data1, data5
        trn1_s data10, data2, data6
        trn2_s data14, data2, data6
        trn1_s data11, data3, data7
        trn2_s data15, data3, data7

        // reduce
        barrett_reduce  data8, barrett_const, 0
        barrett_reduce  data9, barrett_const, 0
        barrett_reduce data10, barrett_const, 0
        barrett_reduce data11, barrett_const, 0
        barrett_reduce data12, barrett_const, 0
        barrett_reduce data13, barrett_const, 0
        barrett_reduce data14, barrett_const, 0
        barrett_reduce data15, barrett_const, 0

        st4 {data8.4S, data9.4S, data10.4S, data11.4S}, [src0], #64
        st4 {data12.4S, data13.4S, data14.4S, data15.4S}, [src1], #64

        subs count, count, #1
        cbnz count, layer567_start

       pop_stack
       ret
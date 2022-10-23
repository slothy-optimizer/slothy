///
/// Copyright (c) 2022 Arm Limited
/// Copyright (c) 2022 Hanno Becker
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
.macro vsub d,a,b                                   // slothy:no-unfold
        sub \d\().8h, \a\().8h, \b\().8h
.endm
.macro vadd d,a,b                                   // slothy:no-unfold
        add \d\().8h, \a\().8h, \b\().8h
.endm
.macro vqrdmulh d,a,b                               // slothy:no-unfold
        sqrdmulh \d\().8h, \a\().8h, \b\().8h
.endm
.macro vmul d,a,b                                   // slothy:no-unfold
        mul \d\().8h, \a\().8h, \b\().8h
.endm
.macro vmla d,a,b                                   // slothy:no-unfold
        mla \d\().8h, \a\().8h, \b\().8h
.endm
.macro vqrdmulhq d,a,b,i                            // slothy:no-unfold
        sqrdmulh \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro vmulq d,a,b,i                                // slothy:no-unfold
        mul \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro vmlaq d,a,b,i                                // slothy:no-unfold
        mla \d\().8h, \a\().8h, \b\().h[\i]
.endm
.macro trn1_d d,a,b                                 // slothy:no-unfold
        trn1 \d\().2d, \a\().2d, \b\().2d
.endm
.macro trn2_d d,a,b                                 // slothy:no-unfold
        trn2 \d\().2d, \a\().2d, \b\().2d
.endm
.macro trn1_s d,a,b                                 // slothy:no-unfold
        trn1 \d\().4s, \a\().4s, \b\().4s
.endm
.macro trn2_s d,a,b                                 // slothy:no-unfold
        trn2 \d\().4s, \a\().4s, \b\().4s
.endm

.macro mulmodq dst, src, const, idx0, idx1
        vmulq       \dst,  \src, \const, \idx0
        vqrdmulhq   \src,  \src, \const, \idx1
        vmla        \dst,  \src, modulus
.endm

.macro mulmod dst, src, const, const_twisted
        vmul       \dst,  \src, \const
        vqrdmulh   \src,  \src, \const_twisted
        vmla       \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq  tmp, \b, \root, \idx0, \idx1
        vsub     \b,    \a, tmp
        vadd     \a,    \a, tmp
.endm

.macro mulmod_v dst, src, const, const_twisted
        vmul        \dst,  \src, \const
        vqrdmulh    \src,  \src, \const_twisted
        vmla        \dst,  \src, modulus
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod  tmp, \b, \root, \root_twisted
        vsub    \b,    \a, tmp
        vadd    \a,    \a, tmp
.endm

.macro load_roots_123
        ldr_vi root0, r_ptr0, #32
        ldr_vo root1, r_ptr0, #-16
.endm

.macro load_next_roots_45
        ldr_vi root0, r_ptr0, #16
.endm

.macro load_next_roots_67
        ldr_vi root0,    r_ptr1, #(6*16)
        ldr_vo root0_tw, r_ptr1, #(-6*16 + 1*16)
        ldr_vo root1,    r_ptr1, #(-6*16 + 2*16)
        ldr_vo root1_tw, r_ptr1, #(-6*16 + 3*16)
        ldr_vo root2,    r_ptr1, #(-6*16 + 4*16)
        ldr_vo root2_tw, r_ptr1, #(-6*16 + 5*16)
.endm

.macro transpose4 data
        trn1_s t0, \data\()0, \data\()1
        trn2_s t1, \data\()0, \data\()1
        trn1_s t2, \data\()2, \data\()3
        trn2_s t3, \data\()2, \data\()3

        trn2_d \data\()2, t0, t2
        trn2_d \data\()3, t1, t3
        trn1_d \data\()0, t0, t2
        trn1_d \data\()1, t1, t3
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
#include "ntt_kyber_123_45_67_twiddles.s"
.text

        .global ntt_kyber_123_4567
        .global _ntt_kyber_123_4567

.p2align 4
modulus_addr:   .quad 3329
ntt_kyber_123_4567:
_ntt_kyber_123_4567:
        push_stack

        in      .req x0
        inp     .req x1
        count   .req x2
        r_ptr0  .req x3
        r_ptr1  .req x4
        xtmp    .req x5

        data0  .req v8
        data1  .req v9
        data2  .req v10
        data3  .req v11
        data4  .req v12
        data5  .req v13
        data6  .req v14
        data7  .req v15
        data8  .req v16
        data9  .req v17
        data10 .req v18
        data11 .req v19
        data12 .req v20
        data13 .req v21
        data14 .req v22
        data15 .req v23

        qform_data0  .req q8
        qform_data1  .req q9
        qform_data2  .req q10
        qform_data3  .req q11
        qform_data4  .req q12
        qform_data5  .req q13
        qform_data6  .req q14
        qform_data7  .req q15
        qform_data8  .req q16
        qform_data9  .req q17
        qform_data10 .req q18
        qform_data11 .req q19
        qform_data12 .req q20
        qform_data13 .req q21
        qform_data14 .req q22
        qform_data15 .req q23

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

        tmp .req v24
        t0  .req v25
        t1  .req v26
        t2  .req v27
        t3  .req v28

        modulus .req v29

        ASM_LOAD(r_ptr0, roots)
        ASM_LOAD(r_ptr1, roots_l56)

        ASM_LOAD(xtmp, modulus_addr)
        ld1r {modulus.8h}, [xtmp]

        save STACK0, in
        mov count, #4

        load_roots_123

        .p2align 2
layer123_start:
        ldr_vo data0, in, #0
        ldr_vo data1, in, #(1*(512/8))
        ldr_vo data2, in, #(2*(512/8))
        ldr_vo data3, in, #(3*(512/8))
        ldr_vo data4, in, #(4*(512/8))
        ldr_vo data5, in, #(5*(512/8))
        ldr_vo data6, in, #(6*(512/8))
        ldr_vo data7, in, #(7*(512/8))

        ct_butterfly data0, data4, root0, 0, 1
        ct_butterfly data1, data5, root0, 0, 1
        ct_butterfly data2, data6, root0, 0, 1
        ct_butterfly data3, data7, root0, 0, 1

        ct_butterfly data0, data2, root0, 2, 3
        ct_butterfly data1, data3, root0, 2, 3
        ct_butterfly data4, data6, root0, 4, 5
        ct_butterfly data5, data7, root0, 4, 5

        ct_butterfly data0, data1, root0, 6, 7
        ct_butterfly data2, data3, root1, 0, 1
        ct_butterfly data4, data5, root1, 2, 3
        ct_butterfly data6, data7, root1, 4, 5

        str_vi data0, in, #(16)
        str_vo data1, in, #(-16 + 1*(512/8))
        str_vo data2, in, #(-16 + 2*(512/8))
        str_vo data3, in, #(-16 + 3*(512/8))
        str_vo data4, in, #(-16 + 4*(512/8))
        str_vo data5, in, #(-16 + 5*(512/8))
        str_vo data6, in, #(-16 + 6*(512/8))
        str_vo data7, in, #(-16 + 7*(512/8))
layer123_end:
        subs count, count, #1
        cbnz count, layer123_start

        restore inp, STACK0
        mov count, #8

        .p2align 2
layer4567_start:
        ldr_vo data0, inp, #(16*0)
        ldr_vo data1, inp, #(16*1)
        ldr_vo data2, inp, #(16*2)
        ldr_vo data3, inp, #(16*3)

        load_next_roots_45

        ct_butterfly data0, data2, root0, 0, 1
        ct_butterfly data1, data3, root0, 0, 1
        ct_butterfly data0, data1, root0, 2, 3
        ct_butterfly data2, data3, root0, 4, 5

        transpose4 data
        load_next_roots_67

        ct_butterfly_v data0, data2, root0, root0_tw
        ct_butterfly_v data1, data3, root0, root0_tw
        ct_butterfly_v data0, data1, root1, root1_tw
        ct_butterfly_v data2, data3, root2, root2_tw

        str_vi  data0, inp, #(16*4)
        str_vo  data1, inp, #(-16*4 +  1*16)
        str_vo  data2, inp, #(-16*4 +  2*16)
        str_vo  data3, inp, #(-16*4 +  3*16)
layer4567_end:
        subs count, count, #1
        cbnz count, layer4567_start

       pop_stack
       ret

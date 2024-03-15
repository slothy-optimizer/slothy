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

.macro vsub d,a,b
        sub \d\().4s, \a\().4s, \b\().4s
.endm
.macro vadd d,a,b
        add \d\().4s, \a\().4s, \b\().4s
.endm
.macro vqrdmulh d,a,b
        sqrdmulh \d\().4s, \a\().4s, \b\().4s
.endm
.macro vmul d,a,b
        mul \d\().4s, \a\().4s, \b\().4s
.endm
.macro vmls d,a,b
        mls \d\().4s, \a\().4s, \b\().4s
.endm
.macro vqrdmulhq d,a,b,i
        sqrdmulh \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmulq d,a,b,i
        mul \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmlsq d,a,b,i
        mls \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro trn1_d d,a,b
        trn1 \d\().2d, \a\().2d, \b\().2d
.endm
.macro trn2_d d,a,b
        trn2 \d\().2d, \a\().2d, \b\().2d
.endm
.macro trn1_s d,a,b
        trn1 \d\().4s, \a\().4s, \b\().4s
.endm
.macro trn2_s d,a,b
        trn2 \d\().4s, \a\().4s, \b\().4s
.endm

.macro mulmodq dst, src, const, idx0, idx1
        vmulq       \dst,  \src, \const, \idx0
        vqrdmulhq   \src,  \src, \const, \idx1
        vmls        \dst,  \src, modulus
.endm

.macro mulmod dst, src, const, const_twisted
        vmul       \dst,  \src, \const
        vqrdmulh   \src,  \src, \const_twisted
        vmls       \dst,  \src, modulus
.endm

.macro montg_reduce a
        srshr tmp.4S,  \a\().4S, #23
        vmls   \a, tmp, modulus
.endm

.macro canonical_reduce a, modulus_half, neg_modulus_half, tmp1, tmp2
        cmge \tmp1\().4s, \neg_modulus_half\().4s, \a\().4s
        cmge \tmp2\().4s, \a\().4s, \modulus_half\().4s
        sub \tmp2\().4s, \tmp1\().4s, \tmp2\().4s
        vmls \a, \tmp2, modulus
.endm

.macro gs_butterfly a, b, root, idx0, idx1
        vsub     tmp,    \a, \b
        vadd     \a,    \a, \b
        mulmodq  \b, tmp, \root, \idx0, \idx1
.endm

.macro mulmod_v dst, src, const, const_twisted
        vmul        \dst,  \src, \const
        vqrdmulh    \src,  \src, \const_twisted
        vmls        \dst,  \src, modulus
.endm

.macro gs_butterfly_v a, b, root, root_twisted
        vsub    tmp,    \a, \b
        vadd    \a,    \a, \b
        mulmod  \b, tmp, \root, \root_twisted
.endm

.macro mul_ninv dst0, dst1, dst2, dst3, dst4, dst5, dst6, dst7, src0, src1, src2, src3, src4, src5, src6, src7
        mulmod \dst0, \src0, ninv, ninv_tw
        mulmod \dst1, \src1, ninv, ninv_tw
        mulmod \dst2, \src2, ninv, ninv_tw
        mulmod \dst3, \src3, ninv, ninv_tw
        mulmod \dst4, \src4, ninv, ninv_tw
        mulmod \dst5, \src5, ninv, ninv_tw
        mulmod \dst6, \src6, ninv, ninv_tw
        mulmod \dst7, \src7, ninv, ninv_tw
.endm

.macro load_roots_1234 r_ptr
        ldr qform_root0, [\r_ptr], #(8*16)
        ldr qform_root1, [\r_ptr, #(-8*16 + 1*16)]
        ldr qform_root2, [\r_ptr, #(-8*16 + 2*16)]
        ldr qform_root3, [\r_ptr, #(-8*16 + 3*16)]
        ldr qform_root4, [\r_ptr, #(-8*16 + 4*16)]
        ldr qform_root5, [\r_ptr, #(-8*16 + 5*16)]
        ldr qform_root6, [\r_ptr, #(-8*16 + 6*16)]
        ldr qform_root7, [\r_ptr, #(-8*16 + 7*16)]
.endm

.macro load_next_roots_56 root0, r_ptr0
        ldr qform_\root0, [\r_ptr0], #16
.endm

.macro load_next_roots_6 root0, r_ptr0
        ldr qform_\root0, [\r_ptr0], #8
.endm

.macro load_next_roots_78 root0, root0_tw, root1, root1_tw, root2, root2_tw, r_ptr1
        ldr qform_\root0, [   \r_ptr1], #(6*16)
        ldr qform_\root0_tw, [\r_ptr1, #(-6*16 + 1*16)]
        ldr qform_\root1, [   \r_ptr1, #(-6*16 + 2*16)]
        ldr qform_\root1_tw, [\r_ptr1, #(-6*16 + 3*16)]
        ldr qform_\root2, [   \r_ptr1, #(-6*16 + 4*16)]
        ldr qform_\root2_tw, [\r_ptr1, #(-6*16 + 5*16)]
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
#include "intt_dilithium_1234_5678_twiddles.s"
.text

        .global intt_dilithium_1234_5678
        .global _intt_dilithium_1234_5678

.p2align 4
modulus_addr:   .quad 8380417
ninv_addr:      .quad 16382
ninv_tw_addr:   .quad 4197891
intt_dilithium_1234_5678:
_intt_dilithium_1234_5678:
        push_stack

        inp     .req x0
        in      .req x1
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
        qform_tmp .req q24
        t0  .req v25
        t1  .req v26
        t2  .req v27
        t3  .req v28

        modulus .req v29

        ASM_LOAD(r_ptr0, roots)
        ASM_LOAD(r_ptr1, roots_l45)

        ASM_LOAD(xtmp, modulus_addr)
        ld1r {modulus.4s}, [xtmp]

        save STACK0, inp

        mov count, #16

        .p2align 2
layer5678_start:
        ldr qform_data0, [inp, #(16*0)]
        ldr qform_data1, [inp, #(16*1)]
        ldr qform_data2, [inp, #(16*2)]
        ldr qform_data3, [inp, #(16*3)]

        load_next_roots_78 root0, root0_tw, root1, root1_tw, root2, root2_tw, r_ptr0

        gs_butterfly_v data0, data1, root1, root1_tw
        gs_butterfly_v data2, data3, root2, root2_tw
        gs_butterfly_v data0, data2, root0, root0_tw
        gs_butterfly_v data1, data3, root0, root0_tw

        transpose4 data

        load_next_roots_6  root1, r_ptr1
        load_next_roots_56 root0, r_ptr1

        gs_butterfly data0, data1, root0, 0, 1
        gs_butterfly data2, data3, root0, 2, 3
        gs_butterfly data0, data2, root1, 0, 1
        gs_butterfly data1, data3, root1, 0, 1

        montg_reduce data0
        montg_reduce data1

        str qform_data0, [inp], #(16*4)
        str qform_data1, [inp, #(-16*4 +  1*16)]
        str qform_data2, [inp, #(-16*4 +  2*16)]
        str qform_data3, [inp, #(-16*4 +  3*16)]
// layer5678_end:
        subs count, count, #1
        cbnz count, layer5678_start

        .unreq root0_tw
        .unreq root1_tw
        .unreq root2_tw
        .unreq root3_tw
        .unreq qform_root0_tw
        .unreq qform_root1_tw
        .unreq qform_root2_tw
        .unreq qform_root3_tw
        .unreq t0
        .unreq t1

        root4            .req v4
        root5            .req v5
        root6            .req v6
        root7            .req v7
        qform_root4      .req q4
        qform_root5      .req q5
        qform_root6      .req q6
        qform_root7      .req q7
        ninv             .req v25
        ninv_tw          .req v26
        modulus_half     .req v30
        neg_modulus_half .req v31


        restore in, STACK0
        mov count, #4

        ASM_LOAD(xtmp, ninv_addr)
        ld1r {ninv.4s}, [xtmp]
        ASM_LOAD(xtmp, ninv_tw_addr)
        ld1r {ninv_tw.4s}, [xtmp]

        ushr modulus_half.4S, modulus.4S, #1
        neg neg_modulus_half.4S, modulus_half.4S

        load_roots_1234 r_ptr1

        .p2align 2
layer1234_start:
        ldr qform_data0, [in, #0]
        ldr qform_data1, [in, #(1*(512/8))]
        ldr qform_data2, [in, #(2*(512/8))]
        ldr qform_data3, [in, #(3*(512/8))]
        ldr qform_data4, [in, #(4*(512/8))]
        ldr qform_data5, [in, #(5*(512/8))]
        ldr qform_data6, [in, #(6*(512/8))]
        ldr qform_data7, [in, #(7*(512/8))]
        ldr qform_data8, [in, #(8*(512/8))]
        ldr qform_data9, [in, #(9*(512/8))]
        ldr qform_data10, [in, #(10*(512/8))]
        ldr qform_data11, [in, #(11*(512/8))]
        ldr qform_data12, [in, #(12*(512/8))]
        ldr qform_data13, [in, #(13*(512/8))]
        ldr qform_data14, [in, #(14*(512/8))]
        ldr qform_data15, [in, #(15*(512/8))]

        // layer4
        gs_butterfly data0, data1, root3, 2, 3
        gs_butterfly data2, data3, root4, 0, 1
        gs_butterfly data4, data5, root4, 2, 3
        gs_butterfly data6, data7, root5, 0, 1
        gs_butterfly data8, data9, root5, 2, 3
        gs_butterfly data10, data11, root6, 0, 1
        gs_butterfly data12, data13, root6, 2, 3
        gs_butterfly data14, data15, root7, 0, 1

        // layer3
        gs_butterfly data0, data2, root1, 2, 3
        gs_butterfly data1, data3, root1, 2, 3
        gs_butterfly data4, data6, root2, 0, 1
        gs_butterfly data5, data7, root2, 0, 1
        gs_butterfly data8, data10, root2, 2, 3
        gs_butterfly data9, data11, root2, 2, 3
        gs_butterfly data12, data14, root3, 0, 1
        gs_butterfly data13, data15, root3, 0, 1

        // layer2
        gs_butterfly data0, data4, root0, 2, 3
        gs_butterfly data1, data5, root0, 2, 3
        gs_butterfly data2, data6, root0, 2, 3
        gs_butterfly data3, data7, root0, 2, 3
        gs_butterfly data8, data12, root1, 0, 1
        gs_butterfly data9, data13, root1, 0, 1
        gs_butterfly data10, data14, root1, 0, 1
        gs_butterfly data11, data15, root1, 0, 1

        // layer 1
        gs_butterfly data0, data8, root0, 0, 1
        gs_butterfly data1, data9, root0, 0, 1
        gs_butterfly data2, data10, root0, 0, 1
        gs_butterfly data3, data11, root0, 0, 1
        gs_butterfly data4, data12, root0, 0, 1
        gs_butterfly data5, data13, root0, 0, 1
        gs_butterfly data6, data14, root0, 0, 1
        gs_butterfly data7, data15, root0, 0, 1

        canonical_reduce data8,  modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data9,  modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data10, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data11, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data12, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data13, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data14, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data15, modulus_half, neg_modulus_half, t2, t3

        str qform_data8, [in, # (8*(512/8))]
        str qform_data9, [in, # (9*(512/8))]
        str qform_data10, [in, #(10*(512/8))]
        str qform_data11, [in, #(11*(512/8))]
        str qform_data12, [in, #(12*(512/8))]
        str qform_data13, [in, #(13*(512/8))]
        str qform_data14, [in, #(14*(512/8))]
        str qform_data15, [in, #(15*(512/8))]

        mul_ninv data8, data9, data10, data11, data12, data13, data14, data15, data0, data1, data2, data3, data4, data5, data6, data7

        canonical_reduce data8,  modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data9,  modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data10, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data11, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data12, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data13, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data14, modulus_half, neg_modulus_half, t2, t3
        canonical_reduce data15, modulus_half, neg_modulus_half, t2, t3

        str qform_data8, [in], #(16)
        str qform_data9, [in, #(-16 + 1*(512/8))]
        str qform_data10, [in, #(-16 + 2*(512/8))]
        str qform_data11, [in, #(-16 + 3*(512/8))]
        str qform_data12, [in, #(-16 + 4*(512/8))]
        str qform_data13, [in, #(-16 + 5*(512/8))]
        str qform_data14, [in, #(-16 + 6*(512/8))]
        str qform_data15, [in, #(-16 + 7*(512/8))]

// layer1234_end:
        subs count, count, #1
        cbnz count, layer1234_start

        pop_stack
        ret

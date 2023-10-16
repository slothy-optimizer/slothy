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

.macro trn1_s d,a,b
        trn1 \d\().4s, \a\().4s, \b\().4s
.endm
.macro trn2_s d,a,b
        trn2 \d\().4s, \a\().4s, \b\().4s
.endm
.macro ldr_vo vec, base, offset
        ldr qform_\vec, [\base, \offset]
.endm
.macro ldr_vi vec, base, inc
        ldr qform_\vec, [\base], \inc
.endm
.macro str_vo vec, base, offset
        str qform_\vec, [\base, \offset]
.endm
.macro str_vi vec, base, inc
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
        vmlaq        \dst,  \src, consts, 0
.endm

.macro mulmod dst, src, const, const_twisted
        mul        \dst\().8h,  \src\().8h, \const\().8h
        vqrdmulh   \src,  \src, \const_twisted
        vmlaq      \dst,  \src, consts, 0
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq  tmp, \b, \root, \idx0, \idx1
        sub     \b\().8h,    \a\().8h, tmp.8h
        add     \a\().8h,    \a\().8h, tmp.8h
.endm

.macro mulmod_v dst, src, const, const_twisted
        vmul        \dst,  \src, \const
        vqrdmulh    \src,  \src, \const_twisted
        vmla        \dst,  \src, consts
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod  tmp, \b, \root, \root_twisted
        sub    \b\().8h,    \a\().8h, tmp.8h
        add    \a\().8h,    \a\().8h, tmp.8h
.endm

.macro barrett_reduce a
        vqdmulhq t0, \a, consts, 1
        srshr    t0.8h, t0.8h, #11
        vmlaq    \a, t0, consts, 0
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

        .global ntt_kyber_1234_567
        .global _ntt_kyber_1234_567

.p2align 4
const_addr:     .short -3329
                .short 20159
                .short 0
                .short 0
                .short 0
                .short 0
                .short 0
                .short 0

ntt_kyber_1234_567:
_ntt_kyber_1234_567:
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

        consts .req v8

        ASM_LOAD(r_ptr0, roots)

        ASM_LOAD(xtmp, const_addr)
        ld1 {consts.8h}, [xtmp]

        save STACK0, in

        add  src0, x0,  #32*0
        add  src8, x0,  #32*8

        ld1 { root0.8h,  root1.8h,  root2.8h,  root3.8h}, [r_ptr0], #64

        mov count, #2

        .p2align 2
layer1234_start:

        ldr_vo data0, src0, 0
        ldr_vo data1, src0, 1*32
        ldr_vo data2, src0, 2*32
        ldr_vo data3, src0, 3*32
        ldr_vo data4, src0, 4*32
        ldr_vo data5, src0, 5*32
        ldr_vo data6, src0, 6*32
        ldr_vo data7, src0, 7*32

        ldr_vo data8, src8, 0
        ldr_vo data9, src8, 1*32
        ldr_vo data10, src8, 2*32
        ldr_vo data11, src8, 3*32
        ldr_vo data12, src8, 4*32
        ldr_vo data13, src8, 5*32
        ldr_vo data14, src8, 6*32
        ldr_vo data15, src8, 7*32

        ct_butterfly data0,  data8, root0, 0, 1
        ct_butterfly data1,  data9, root0, 0, 1
        ct_butterfly data2, data10, root0, 0, 1
        ct_butterfly data3, data11, root0, 0, 1
        ct_butterfly data4, data12, root0, 0, 1
        ct_butterfly data5, data13, root0, 0, 1
        ct_butterfly data6, data14, root0, 0, 1
        ct_butterfly data7, data15, root0, 0, 1

        ct_butterfly  data0,  data4, root0, 2, 3
        ct_butterfly  data1,  data5, root0, 2, 3
        ct_butterfly  data2,  data6, root0, 2, 3
        ct_butterfly  data3,  data7, root0, 2, 3
        ct_butterfly  data8, data12, root0, 4, 5
        ct_butterfly  data9, data13, root0, 4, 5
        ct_butterfly data10, data14, root0, 4, 5
        ct_butterfly data11, data15, root0, 4, 5

        ct_butterfly  data0,  data2, root0, 6, 7
        ct_butterfly  data1,  data3, root0, 6, 7
        ct_butterfly  data4,  data6, root1, 0, 1
        ct_butterfly  data5,  data7, root1, 0, 1
        ct_butterfly  data8, data10, root1, 2, 3
        ct_butterfly  data9, data11, root1, 2, 3
        ct_butterfly data12, data14, root1, 4, 5
        ct_butterfly data13, data15, root1, 4, 5

        ct_butterfly  data0,  data1, root1, 6, 7
        ct_butterfly  data2,  data3, root2, 0, 1
        ct_butterfly  data4,  data5, root2, 2, 3
        ct_butterfly  data6,  data7, root2, 4, 5
        ct_butterfly  data8,  data9, root2, 6, 7
        ct_butterfly data10, data11, root3, 0, 1
        ct_butterfly data12, data13, root3, 2, 3
        ct_butterfly data14, data15, root3, 4, 5

        str_vi data0, src0, 16
        str_vo data1, src0, -16+1*32
        str_vo data2, src0, -16+2*32
        str_vo data3, src0, -16+3*32
        str_vo data4, src0, -16+4*32
        str_vo data5, src0, -16+5*32
        str_vo data6, src0, -16+6*32
        str_vo data7, src0, -16+7*32

        str_vi data8, src8, 16
        str_vo data9, src8, -16+1*32
        str_vo data10, src8, -16+2*32
        str_vo data11, src8, -16+3*32
        str_vo data12, src8, -16+4*32
        str_vo data13, src8, -16+5*32
        str_vo data14, src8, -16+6*32
        str_vo data15, src8, -16+7*32

        subs count, count, #1
        cbnz count, layer1234_start

        restore inp, STACK0
        mov count, #4

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

        // reduce
        barrett_reduce data0
        barrett_reduce data1
        barrett_reduce data2
        barrett_reduce data3
        barrett_reduce data4
        barrett_reduce data5
        barrett_reduce data6
        barrett_reduce data7

        // transpose back
        trn1_s  data8, data0, data4
        trn2_s data12, data0, data4
        trn1_s  data9, data1, data5
        trn2_s data13, data1, data5
        trn1_s data10, data2, data6
        trn2_s data14, data2, data6
        trn1_s data11, data3, data7
        trn2_s data15, data3, data7

        st4 {data8.4S, data9.4S, data10.4S, data11.4S}, [src0], #64
        st4 {data12.4S, data13.4S, data14.4S, data15.4S}, [src1], #64

        subs count, count, #1
        cbnz count, layer567_start

       pop_stack
       ret

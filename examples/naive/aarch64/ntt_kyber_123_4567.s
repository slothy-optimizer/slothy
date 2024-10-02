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

.macro mulmodq dst, src, const, idx0, idx1
        sqrdmulh t2.8h,   \src\().8h, \const\().h[\idx1]
        mul      \dst\().8h, \src\().8h, \const\().h[\idx0]
        mls      \dst\().8h, t2.8h,   consts.h[0]
.endm

.macro mulmod dst, src, const, const_twisted
        sqrdmulh t2.8h,   \src\().8h, \const_twisted\().8h
        mul      \dst\().8h, \src\().8h, \const\().8h
        mls      \dst\().8h, t2.8h,   consts.h[0]
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq tmp, \b, \root, \idx0, \idx1
        sub \b\().8h, \a\().8h, tmp.8h
        add \a\().8h, \a\().8h, tmp.8h
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod tmp, \b, \root, \root_twisted
        sub \b\().8h, \a\().8h, tmp.8h
        add \a\().8h, \a\().8h, tmp.8h
.endm

.macro barrett_reduce a
        sqdmulh t0.8h, \a\().8h, consts.h[1]
        srshr   t0.8h, t0.8h, #11
        mls     \a\().8h, t0.8h, consts.h[0]
.endm

.macro load_roots_123
        ldr q_root0, [r_ptr0], #32
        ldr q_root1, [r_ptr0, #-16]
.endm

.macro load_next_roots_45
        ldr q_root0, [r_ptr0], #16
.endm

.macro load_next_roots_67
        ldr q_root0,    [r_ptr1], #(6*16)
        ldr q_root0_tw, [r_ptr1, #(-6*16 + 1*16)]
        ldr q_root1,    [r_ptr1, #(-6*16 + 2*16)]
        ldr q_root1_tw, [r_ptr1, #(-6*16 + 3*16)]
        ldr q_root2,    [r_ptr1, #(-6*16 + 4*16)]
        ldr q_root2_tw, [r_ptr1, #(-6*16 + 5*16)]
.endm

.macro transpose4 data
        trn1 t0.4s, \data\()0.4s, \data\()1.4s
        trn2 t1.4s, \data\()0.4s, \data\()1.4s
        trn1 t2.4s, \data\()2.4s, \data\()3.4s
        trn2 t3.4s, \data\()2.4s, \data\()3.4s

        trn2 \data\()2.2d, t0.2d, t2.2d
        trn2 \data\()3.2d, t1.2d, t3.2d
        trn1 \data\()0.2d, t0.2d, t2.2d
        trn1 \data\()1.2d, t1.2d, t3.2d
.endm

.macro transpose_single data_out, data_in
        trn1 \data_out\()0.4s, \data_in\()0.4s, \data_in\()1.4s
        trn2 \data_out\()1.4s, \data_in\()0.4s, \data_in\()1.4s
        trn1 \data_out\()2.4s, \data_in\()2.4s, \data_in\()3.4s
        trn2 \data_out\()3.4s, \data_in\()2.4s, \data_in\()3.4s
.endm

.macro save_gprs
        sub sp, sp, #(16*6)
        stp x19, x20, [sp, #16*0]
        stp x19, x20, [sp, #16*0]
        stp x21, x22, [sp, #16*1]
        stp x23, x24, [sp, #16*2]
        stp x25, x26, [sp, #16*3]
        stp x27, x28, [sp, #16*4]
        str x29, [sp, #16*5]
.endm

.macro restore_gprs
        ldp x19, x20, [sp, #16*0]
        ldp x21, x22, [sp, #16*1]
        ldp x23, x24, [sp, #16*2]
        ldp x25, x26, [sp, #16*3]
        ldp x27, x28, [sp, #16*4]
        ldr x29, [sp, #16*5]
        add sp, sp, #(16*6)
.endm

.macro save_vregs
        sub sp, sp, #(16*4)
        stp  d8,  d9, [sp, #16*0]
        stp d10, d11, [sp, #16*1]
        stp d12, d13, [sp, #16*2]
        stp d14, d15, [sp, #16*3]
.endm

.macro restore_vregs
        ldp  d8,  d9, [sp, #16*0]
        ldp d10, d11, [sp, #16*1]
        ldp d12, d13, [sp, #16*2]
        ldp d14, d15, [sp, #16*3]
        add sp, sp, #(16*4)
.endm

#define STACK_SIZE 16
#define STACK0 0

.macro restore a, loc
        ldr \a, [sp, #\loc]
.endm
.macro save loc, a
        str \a, [sp, #\loc]
.endm
.macro push_stack
        save_gprs
        save_vregs
        sub sp, sp, #STACK_SIZE
.endm

.macro pop_stack
        add sp, sp, #STACK_SIZE
        restore_vregs
        restore_gprs
.endm

.data
.p2align 4
roots:
        #include "ntt_kyber_123_45_67_twiddles.s"

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

        q_data0  .req q8
        q_data1  .req q9
        q_data2  .req q10
        q_data3  .req q11
        q_data4  .req q12
        q_data5  .req q13
        q_data6  .req q14
        q_data7  .req q15

        root0    .req v0
        root1    .req v1
        root2    .req v2
        root0_tw .req v4
        root1_tw .req v5
        root2_tw .req v6

        q_root0    .req q0
        q_root1    .req q1
        q_root2    .req q2
        q_root0_tw .req q4
        q_root1_tw .req q5
        q_root2_tw .req q6

        consts    .req v7
        q_consts  .req q7

        tmp .req v24
        t0  .req v25
        t1  .req v26
        t2  .req v27
        t3  .req v28

        .text
        .global ntt_kyber_123_4567
        .global _ntt_kyber_123_4567

.p2align 4
const_addr:
        .short 3329
        .short 20159
        .short 0
        .short 0
        .short 0
        .short 0
        .short 0
        .short 0

ntt_kyber_123_4567:
_ntt_kyber_123_4567:
        push_stack

        ASM_LOAD(r_ptr0, roots)
        ASM_LOAD(r_ptr1, roots_l56)
        ASM_LOAD(xtmp, const_addr)

        ld1 {consts.8h}, [xtmp]

        str in, [sp, #STACK0] // @slothy:writes=STACK0
        mov count, #4

        load_roots_123

        .p2align 2
layer123_start:

        ldr q_data0, [in, #0]
        ldr q_data1, [in, #(1*(512/8))]
        ldr q_data2, [in, #(2*(512/8))]
        ldr q_data3, [in, #(3*(512/8))]
        ldr q_data4, [in, #(4*(512/8))]
        ldr q_data5, [in, #(5*(512/8))]
        ldr q_data6, [in, #(6*(512/8))]
        ldr q_data7, [in, #(7*(512/8))]

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

        str q_data0, [in], #(16)
        str q_data1, [in, #(-16 + 1*(512/8))]
        str q_data2, [in, #(-16 + 2*(512/8))]
        str q_data3, [in, #(-16 + 3*(512/8))]
        str q_data4, [in, #(-16 + 4*(512/8))]
        str q_data5, [in, #(-16 + 5*(512/8))]
        str q_data6, [in, #(-16 + 6*(512/8))]
        str q_data7, [in, #(-16 + 7*(512/8))]

        subs count, count, #1
        cbnz count, layer123_start

        ldr inp, [sp, #STACK0] // @slothy:reads=STACK0
        mov count, #8

        .p2align 2
layer4567_start:

        ldr q_data0, [inp, #(16*0)]
        ldr q_data1, [inp, #(16*1)]
        ldr q_data2, [inp, #(16*2)]
        ldr q_data3, [inp, #(16*3)]

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

        barrett_reduce data0
        barrett_reduce data1
        barrett_reduce data2
        barrett_reduce data3

        st4 {data0.4S, data1.4S, data2.4S, data3.4S}, [inp], #64

        subs count, count, #1
        cbnz count, layer4567_start

        pop_stack
        ret

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

.macro vqrdmulh d,a,b
        sqrdmulh \d\().4s, \a\().4s, \b\().4s
.endm
.macro vmla d,a,b
        mla \d\().4s, \a\().4s, \b\().4s
.endm
.macro vqrdmulhq d,a,b,i
        sqrdmulh \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmulq d,a,b,i
        mul \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmlaq d,a,b,i
        mla \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmlsq d,a,b,i
        mls \d\().4s, \a\().4s, \b\().s[\i]
.endm

.macro mulmodq dst, src, const, idx0, idx1
        vqrdmulhq   t2,  \src, \const, \idx1
        vmulq       \dst,  \src, \const, \idx0
        vmla       \dst,  t2, modulus
.endm

.macro mulmod dst, src, const, const_twisted
        vqrdmulh   t2,  \src, \const_twisted
        mul        \dst\().4s,  \src\().4s, \const\().4s
        vmla       \dst,  t2, modulus
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq  tmp, \b, \root, \idx0, \idx1
        sub     \b\().4s,    \a\().4s, tmp.4s
        add     \a\().4s,    \a\().4s, tmp.4s
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod  tmp, \b, \root, \root_twisted
        sub    \b\().4s,    \a\().4s, tmp.4s
        add    \a\().4s,    \a\().4s, tmp.4s
.endm

.macro load_roots_1234
        ldr qform_root0, [r_ptr0], #(8*16)
        ldr qform_root1, [r_ptr0, #(-8*16 + 1*16)]
        ldr qform_root2, [r_ptr0, #(-8*16 + 2*16)]
        ldr qform_root3, [r_ptr0, #(-8*16 + 3*16)]
        ldr qform_root4, [r_ptr0, #(-8*16 + 4*16)]
        ldr qform_root5, [r_ptr0, #(-8*16 + 5*16)]
        ldr qform_root6, [r_ptr0, #(-8*16 + 6*16)]
        ldr qform_root7, [r_ptr0, #(-8*16 + 7*16)]
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

.macro store_vectors_with_inc a0, a1, a2, a3, addr, inc
        str qform_\a0, [\addr], #\inc
        str qform_\a1, [\addr, #(-(\inc) + 16*1)]
        str qform_\a2, [\addr, #(-(\inc) + 16*2)]
        str qform_\a3, [\addr, #(-(\inc) + 16*3)]
.endm

.macro transpose4 data0, data1, data2, data3
        trn1 t0.4s, \data0\().4s, \data1\().4s
        trn2 t1.4s, \data0\().4s, \data1\().4s
        trn1 t2.4s, \data2\().4s, \data3\().4s
        trn2 t3.4s, \data2\().4s, \data3\().4s

        trn2 \data2\().2d, t0.2d, t2.2d
        trn2 \data3\().2d, t1.2d, t3.2d
        trn1 \data0\().2d, t0.2d, t2.2d
        trn1 \data1\().2d, t1.2d, t3.2d
.endm

.macro save_gprs // @slothy:no-unfold
        sub sp, sp, #(16*6)
        stp x19, x20, [sp, #16*0]
        stp x19, x20, [sp, #16*0]
        stp x21, x22, [sp, #16*1]
        stp x23, x24, [sp, #16*2]
        stp x25, x26, [sp, #16*3]
        stp x27, x28, [sp, #16*4]
        str x29, [sp, #16*5]
.endm

.macro restore_gprs // @slothy:no-unfold
        ldp x19, x20, [sp, #16*0]
        ldp x21, x22, [sp, #16*1]
        ldp x23, x24, [sp, #16*2]
        ldp x25, x26, [sp, #16*3]
        ldp x27, x28, [sp, #16*4]
        ldr x29, [sp, #16*5]
        add sp, sp, #(16*6)
.endm

.macro save_vregs // @slothy:no-unfold
        sub sp, sp, #(16*4)
        stp  d8,  d9, [sp, #16*0]
        stp d10, d11, [sp, #16*1]
        stp d12, d13, [sp, #16*2]
        stp d14, d15, [sp, #16*3]
.endm

.macro restore_vregs // @slothy:no-unfold
        ldp  d8,  d9, [sp, #16*0]
        ldp d10, d11, [sp, #16*1]
        ldp d12, d13, [sp, #16*2]
        ldp d14, d15, [sp, #16*3]
        add sp, sp, #(16*4)
.endm

#define STACK_SIZE 16
#define STACK0 0

.macro restore a, loc     // @slothy:no-unfold
        ldr \a, [sp, #\loc\()]
.endm
.macro save loc, a        // @slothy:no-unfold
        str \a, [sp, #\loc\()]
.endm
.macro push_stack // @slothy:no-unfold
        save_gprs
        save_vregs
        sub sp, sp, #STACK_SIZE
.endm

.macro pop_stack // @slothy:no-unfold
        add sp, sp, #STACK_SIZE
        restore_vregs
        restore_gprs
.endm

.data
.p2align 4
roots:
#include "ntt_dilithium_1234_5678_twiddles.s"
.text

        .global ntt_dilithium_1234_5678_manual_st4
        .global _ntt_dilithium_1234_5678_manual_st4

.p2align 4
modulus_addr:   .quad -8380417
ntt_dilithium_1234_5678_manual_st4:
_ntt_dilithium_1234_5678_manual_st4:
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
        root4 .req v4
        root5 .req v5
        root6 .req v6
        root7 .req v7

        qform_root0    .req q0
        qform_root1    .req q1
        qform_root2    .req q2
        qform_root3    .req q3
        qform_root4    .req q4
        qform_root5    .req q5
        qform_root6    .req q6
        qform_root7    .req q7


        tmp .req v24
        t0  .req v25
        t1  .req v26
        t2  .req v27
        t3  .req v28

        modulus .req v29

        ASM_LOAD(r_ptr0, roots)
        ASM_LOAD(r_ptr1, roots_l67)

        ASM_LOAD(xtmp, modulus_addr)
        ld1r {modulus.4s}, [xtmp]

        save STACK0, in
        mov count, #4

        load_roots_1234

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

        // layer 1
        ct_butterfly data0, data8, root0, 0, 1
        ct_butterfly data1, data9, root0, 0, 1
        ct_butterfly data2, data10, root0, 0, 1
        ct_butterfly data3, data11, root0, 0, 1
        ct_butterfly data4, data12, root0, 0, 1
        ct_butterfly data5, data13, root0, 0, 1
        ct_butterfly data6, data14, root0, 0, 1
        ct_butterfly data7, data15, root0, 0, 1

        // layer2
        ct_butterfly data0, data4, root0, 2, 3
        ct_butterfly data1, data5, root0, 2, 3
        ct_butterfly data2, data6, root0, 2, 3
        ct_butterfly data3, data7, root0, 2, 3
        ct_butterfly data8, data12, root1, 0, 1
        ct_butterfly data9, data13, root1, 0, 1
        ct_butterfly data10, data14, root1, 0, 1
        ct_butterfly data11, data15, root1, 0, 1

        // layer3
        ct_butterfly data0, data2, root1, 2, 3
        ct_butterfly data1, data3, root1, 2, 3
        ct_butterfly data4, data6, root2, 0, 1
        ct_butterfly data5, data7, root2, 0, 1
        ct_butterfly data8, data10, root2, 2, 3
        ct_butterfly data9, data11, root2, 2, 3
        ct_butterfly data12, data14, root3, 0, 1
        ct_butterfly data13, data15, root3, 0, 1

        // layer4
        ct_butterfly data0, data1, root3, 2, 3
        ct_butterfly data2, data3, root4, 0, 1
        ct_butterfly data4, data5, root4, 2, 3
        ct_butterfly data6, data7, root5, 0, 1
        ct_butterfly data8, data9, root5, 2, 3
        ct_butterfly data10, data11, root6, 0, 1
        ct_butterfly data12, data13, root6, 2, 3
        ct_butterfly data14, data15, root7, 0, 1

        str qform_data0, [in], #(16)
        str qform_data1, [in, #(-16 + 1*(512/8))]
        str qform_data2, [in, #(-16 + 2*(512/8))]
        str qform_data3, [in, #(-16 + 3*(512/8))]
        str qform_data4, [in, #(-16 + 4*(512/8))]
        str qform_data5, [in, #(-16 + 5*(512/8))]
        str qform_data6, [in, #(-16 + 6*(512/8))]
        str qform_data7, [in, #(-16 + 7*(512/8))]
        str qform_data8, [in, #(-16 + 8*(512/8))]
        str qform_data9, [in, #(-16 + 9*(512/8))]
        str qform_data10, [in, #(-16 + 10*(512/8))]
        str qform_data11, [in, #(-16 + 11*(512/8))]
        str qform_data12, [in, #(-16 + 12*(512/8))]
        str qform_data13, [in, #(-16 + 13*(512/8))]
        str qform_data14, [in, #(-16 + 14*(512/8))]
        str qform_data15, [in, #(-16 + 15*(512/8))]
// layer1234_end:
        subs count, count, #1
        cbnz count, layer1234_start

        restore inp, STACK0
        mov count, #16

        .unreq root4
        .unreq root5
        .unreq root6
        .unreq root7
        .unreq qform_root4
        .unreq qform_root5
        .unreq qform_root6
        .unreq qform_root7
        root0_tw .req v4
        root1_tw .req v5
        root2_tw .req v6
        root3_tw .req v7
        qform_root0_tw .req q4
        qform_root1_tw .req q5
        qform_root2_tw .req q6
        qform_root3_tw .req q7

        .p2align 2
layer5678_start:
        ldr qform_data0, [inp, #(16*0)]
        ldr qform_data1, [inp, #(16*1)]
        ldr qform_data2, [inp, #(16*2)]
        ldr qform_data3, [inp, #(16*3)]

        load_next_roots_56 root0, r_ptr0
        load_next_roots_6  root1, r_ptr0

        ct_butterfly data0, data2, root0, 0, 1
        ct_butterfly data1, data3, root0, 0, 1
        ct_butterfly data0, data1, root0, 2, 3
        ct_butterfly data2, data3, root1, 0, 1

        transpose4 data0, data1, data2, data3
        load_next_roots_78 root0, root0_tw, root1, root1_tw, root2, root2_tw, r_ptr1

        ct_butterfly_v data0, data2, root0, root0_tw
        ct_butterfly_v data1, data3, root0, root0_tw
        ct_butterfly_v data0, data1, root1, root1_tw
        ct_butterfly_v data2, data3, root2, root2_tw

        // st4 {data0.4S, data1.4S, data2.4S, data3.4S}, [inp], #64
        transpose4 data0, data1, data2, data3
        store_vectors_with_inc data0, data1, data2, data3, inp, 64
// layer5678_end:
        subs count, count, #1
        cbnz count, layer5678_start

       pop_stack
       ret

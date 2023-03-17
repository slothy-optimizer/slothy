
///
/// Copyright (c) 2021 Arm Limited
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

.data
.p2align 4
roots:
#include "ntt_kyber_12_345_67_twiddles.s"
.text

#define QSTACK4   (0*16)
#define QSTACK5   (1*16)
#define QSTACK6   (2*16)
#define STACK0 (3*16)

#define POS_ROOT_1   1
#define POS_ROOT_2   2
#define POS_ROOT_3   3
#define POS_ROOT_4   4
#define POS_ROOT_5   5
#define POS_ROOT_6   6

#define STACK_SIZE (3*16 + 8)

.macro qsave loc, a       // slothy:no-unfold
        vstrw.32 \a, [sp, #\loc\()]
.endm
.macro qrestore a, loc    // slothy:no-unfold
        vldrw.32 \a, [sp, #\loc\()]
.endm
.macro restored a, b, loc // slothy:no-unfold
        ldrd \a, \b, [sp, #\loc\()]
.endm
.macro saved loc, a, b    // slothy:no-unfold
        strd \a, \b, [sp, #\loc\()]
.endm
.macro restore a, loc     // slothy:no-unfold
        ldr \a, [sp, #\loc\()]
.endm
.macro save loc, a        // slothy:no-unfold
        str \a, [sp, #\loc\()]
.endm

// Barrett multiplication
.macro mulmod dst, src, const, const_tw
        vmul.s16       \dst,  \src, \const
        vqrdmulh.s16   \src,  \src, \const_tw
        vmla.s16       \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, root_tw
        mulmod tmp, \b, \root, \root_tw
        vsub.u16       \b,    \a, tmp
        vadd.u16       \a,    \a, tmp
.endm

// Aligns stack =0 mod 16
.macro align_stack_do // slothy:no-unfold
        mov r11, sp
        and r12, r11, #0xC
        sub sp, sp, r12      // Align stack to 16 byte
        sub sp, sp, #16
        str r12, [sp]
.endm

// Reverts initial stack correction
.macro align_stack_undo // slothy:no-unfold
        ldr r12, [sp]
        add sp, sp, #16
        add sp, sp, r12
.endm

.align 4
roots_addr: .word roots
.syntax unified
.type ntt_kyber_12_345_67, %function
.global ntt_kyber_12_345_67

        modulus  .req r12
        r_ptr .req r11
        .equ modulus_const, -3329

        in           .req r0
        inp          .req r1
        in_low       .req r0
        in_high      .req r1

        root0    .req r2
        root0_tw .req r3
        root1    .req r4
        root1_tw .req r5
        root2    .req r6
        root2_tw .req r7

        data0 .req q0
        data1 .req q1
        data2 .req q2
        data3 .req q3
        data4 .req q1
        data5 .req q2
        data6 .req q3
        data7 .req q4

        tmp     .req q7

        rtmp    .req r3
        rtmp_tw .req r4

        qtmp    .req q5
        qtmp_tw .req q6

ntt_kyber_12_345_67:

        push {r4-r11,lr}
        // Save MVE vector registers
        vpush {d8-d15}
        align_stack_do

        sub sp, sp, #STACK_SIZE
        movw modulus, #:lower16:modulus_const
        ldr  r_ptr, roots_addr

        /* Layers 1,2 */

        save STACK0, in
        add in_high, in_low, #(2*128)
        ldrd root0, root0_tw, [r_ptr], #+24
        ldrd root1, root1_tw, [r_ptr, #-16]
        ldrd root2, root2_tw, [r_ptr, #-8]

        mov lr, #8
        .p2align 2
layer12_loop:
        vldrw.32 data0, [in_low]
        vldrw.32 data1, [in_low, #(2*64)]
        vldrw.32 data2, [in_high]
        vldrw.32 data3, [in_high, #(2*64)]
        ct_butterfly data0, data2, root0, root0_tw
        ct_butterfly data1, data3, root0, root0_tw
        ct_butterfly data0, data1, root1, root1_tw
        ct_butterfly data2, data3, root2, root2_tw
        vstrw.u32 data0, [in_low], #16
        vstrw.u32 data1, [in_low, #(2*64 - 16)]
        vstrw.u32 data2, [in_high], #16
        vstrw.u32 data3, [in_high, #(2*64 - 16)]
        le lr, layer12_loop

        /* Layers 3,4,5 */

        restore in, STACK0
        mov lr, #4
        .p2align 2
layer345_loop:
        ldrd rtmp, rtmp_tw, [r_ptr], #(7*8)
        vldrw.32 data0, [in]
        vldrw.32 data4, [in, #64]
        ct_butterfly data0, data4, rtmp, rtmp_tw
        qsave QSTACK4, data4
        vldrw.32 data1, [in, #16]
        vldrw.32 data5, [in, #80]
        ct_butterfly data1, data5, rtmp, rtmp_tw
        qsave QSTACK5, data5
        vldrw.32 data2, [in, #32]
        vldrw.32 data6, [in, #96]
        ct_butterfly data2, data6, rtmp, rtmp_tw
        qsave QSTACK6, data6
        vldrw.32 data3, [in, #48]
        vldrw.32 data7, [in, #112]
        ct_butterfly data3, data7, rtmp, rtmp_tw

        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_1)*8)]
        ct_butterfly data0, data2, rtmp, rtmp_tw
        ct_butterfly data1, data3, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_2)*8)]
        ct_butterfly data0, data1, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_3)*8)]
        ct_butterfly data2, data3, rtmp, rtmp_tw
        vstrw.u32 data0, [in], #128
        vstrw.u32 data1, [in, #(-128+16)]
        vstrw.u32 data2, [in, #(-128+32)]
        vstrw.u32 data3, [in, #(-128+48)]

        qrestore data4, QSTACK4
        qrestore data5, QSTACK5
        qrestore data6, QSTACK6

        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_4)*8)]
        ct_butterfly data4, data6, rtmp, rtmp_tw
        ct_butterfly data5, data7, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_5)*8)]
        ct_butterfly data4, data5, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + POS_ROOT_6)*8)]
        ct_butterfly data6, data7, rtmp, rtmp_tw

        vstrw.u32 data4, [in, #(-128+64)]
        vstrw.u32 data5, [in, #(-128+80)]
        vstrw.u32 data6, [in, #(-128+96)]
        vstrw.u32 data7, [in, #(-128+112)]
        le lr, layer345_loop

        // Layer 67

        // Use a different base register to facilitate Helight being able to
        // overlap the first iteration of L67 with the last iteration of L345.
        restore inp, STACK0
        mov lr, #8
        .p2align 2
layer67_loop:
        vld40.32 {data0, data1, data2, data3}, [inp]
        vld41.32 {data0, data1, data2, data3}, [inp]
        vld42.32 {data0, data1, data2, data3}, [inp]
        vld43.32 {data0, data1, data2, data3}, [inp]!
        vldrh.16 qtmp,    [r_ptr], #+96
        vldrh.16 qtmp_tw, [r_ptr, #(+16-96)]
        ct_butterfly data0, data2, qtmp, qtmp_tw
        ct_butterfly data1, data3, qtmp, qtmp_tw
        vldrh.16 qtmp,    [r_ptr, #(32 - 96)]
        vldrh.16 qtmp_tw, [r_ptr, #(48 - 96)]
        ct_butterfly data0, data1, qtmp, qtmp_tw
        vldrh.16 qtmp,    [r_ptr, #(64-96)]
        vldrh.16 qtmp_tw, [r_ptr, #(80-96)]
        ct_butterfly data2, data3, qtmp, qtmp_tw
        vstrw.u32 data0, [inp, #-64]
        vstrw.u32 data1, [inp, #-48]
        vstrw.u32 data2, [inp, #-32]
        vstrw.u32 data3, [inp, #-16]
        le lr, layer67_loop

        add sp, sp, #STACK_SIZE

        align_stack_undo
        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr

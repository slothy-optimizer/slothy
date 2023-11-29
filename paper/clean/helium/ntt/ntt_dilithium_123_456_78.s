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

.data
.p2align 4
roots:
#include "ntt_dilithium_123_456_78_twiddles.s"
.text

// Barrett multiplication
.macro mulmod dst, src, const, const_twisted
        vmul.s32       \dst,  \src, \const
        vqrdmulh.s32   \src,  \src, \const_twisted
        vmla.s32       \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, root_twisted
        mulmod tmp, \b, \root, \root_twisted
        vsub.u32       \b,    \a, tmp
        vadd.u32       \a,    \a, tmp
.endm

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

// Aligns stack =0 mod 16
.macro align_stack_do // slothy:no-unfold
        mov r11, sp
        and r12, r11, #0xC   // 8 of ==8 mod 16, 0 otherwise
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

#define STACK_SIZE (5*16+8)    // +8 is for alignment
#define QSTACK4 (0*16)
#define QSTACK5 (1*16)
#define QSTACK6 (2*16)

#define ROOT0_STACK (3*16)
#define ROOT1_STACK (3*16 + 8)
#define ROOT4_STACK (4*16)
#define RPTR_STACK  (4*16 + 8)

.align 4
roots_addr: .word roots
.syntax unified
.type ntt_dilithium_123_456_78, %function
.global ntt_dilithium_123_456_78
ntt_dilithium_123_456_78:

        push {r4-r11,lr}
        // Save MVE vector registers
        vpush {d8-d15}

        align_stack_do
        sub sp, sp, #STACK_SIZE

        modulus .req r12
        r_ptr   .req r11

        .equ modulus_const, -8380417
        movw modulus, #:lower16:modulus_const
        movt modulus, #:upper16:modulus_const
        ldr  r_ptr, roots_addr

        in           .req r0
        in_low       .req in
        in_high      .req r1

        add in_high, in, #(4*128)

        root2    .req r2
        root2_tw .req r3
        root3    .req r4
        root3_tw .req r5
        root5    .req r6
        root5_tw .req r7
        root6    .req r8
        root6_tw .req r9

        data0 .req q0
        data1 .req q1
        data2 .req q2
        data3 .req q3
        data4 .req q1
        data5 .req q2
        data6 .req q3
        data7 .req q4

        tmp .req q7

        /* Layers 1-3 */

        rtmp    .req root6
        rtmp_tw .req root6_tw

        ldrd rtmp, rtmp_tw, [r_ptr], #(7*8)
        saved ROOT0_STACK, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #(1*8 - 7*8)]
        saved ROOT1_STACK, rtmp, rtmp_tw
        ldrd root2, root2_tw, [r_ptr, #(2*8 - 7*8)]
        ldrd root3, root3_tw, [r_ptr, #(3*8 - 7*8)]
        ldrd rtmp, rtmp_tw, [r_ptr, #(4*8 - 7*8)]
        saved ROOT4_STACK, rtmp, rtmp_tw
        ldrd root5, root5_tw, [r_ptr, #(5*8 - 7*8)]
        ldrd root6, root6_tw, [r_ptr, #(6*8 - 7*8)]
        save RPTR_STACK, r_ptr

        .unreq rtmp
        .unreq rtmp_tw
        rtmp    .req r10
        rtmp_tw .req r11

        mov lr, #8
        .p2align 2
layer123_loop:
        vldrw.32 data0, [in_low]
        vldrw.32 data4, [in_high]
        restored rtmp, rtmp_tw, ROOT0_STACK
        ct_butterfly data0, data4, rtmp, rtmp_tw
        qsave QSTACK4, data4
        vldrw.32 data1, [in_low,  #128]
        vldrw.32 data5, [in_high, #128]
        ct_butterfly data1, data5, rtmp, rtmp_tw
        qsave QSTACK5, data5
        vldrw.32 data2, [in_low, #256]
        vldrw.32 data6, [in_high, #256]
        ct_butterfly data2, data6, rtmp, rtmp_tw
        qsave QSTACK6, data6
        vldrw.32 data3, [in_low,  #384]
        vldrw.32 data7, [in_high, #384]
        ct_butterfly data3, data7, rtmp, rtmp_tw

        restored rtmp, rtmp_tw, ROOT1_STACK
        ct_butterfly data0, data2, rtmp, rtmp_tw
        ct_butterfly data1, data3, rtmp, rtmp_tw
        ct_butterfly data0, data1, root2, root2_tw
        ct_butterfly data2, data3, root3, root3_tw
        vstrw.32 data0, [in_low], #16
        vstrw.32 data1, [in_low, #(128-16)]
        vstrw.32 data2, [in_low, #(256-16)]
        vstrw.32 data3, [in_low, #(384-16)]

        qrestore data4, QSTACK4
        qrestore data5, QSTACK5
        qrestore data6, QSTACK6

        restored rtmp, rtmp_tw, ROOT4_STACK
        ct_butterfly data4, data6, rtmp, rtmp_tw
        ct_butterfly data5, data7, rtmp, rtmp_tw
        ct_butterfly data4, data5, root5, root5_tw
        ct_butterfly data6, data7, root6, root6_tw

        vstrw.32 data4, [in_high], #16
        vstrw.32 data5, [in_high, #(128-16)]
        vstrw.32 data6, [in_high, #(256-16)]
        vstrw.32 data7, [in_high, #(384-16)]

        le lr, layer123_loop
        .unreq in_high
        .unreq in_low

        sub in, in, #(128)
        restore r_ptr, RPTR_STACK

        /* Layers 4,5,6 */

        .unreq rtmp
        .unreq rtmp_tw
        rtmp    .req r3
        rtmp_tw .req r4

        mov lr, #8
        .p2align 2
layer456_loop:
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

        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 1)*8)]
        ct_butterfly data0, data2, rtmp, rtmp_tw
        ct_butterfly data1, data3, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 2)*8)]
        ct_butterfly data0, data1, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 3)*8)]
        ct_butterfly data2, data3, rtmp, rtmp_tw

        vstrw.32 data0, [in], #128
        vstrw.32 data1, [in, #(-128+16)]
        vstrw.32 data2, [in, #(-128+32)]
        vstrw.32 data3, [in, #(-128+48)]

        qrestore data4, QSTACK4
        qrestore data5, QSTACK5
        qrestore data6, QSTACK6

        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 4)*8)]
        ct_butterfly data4, data6, rtmp, rtmp_tw
        ct_butterfly data5, data7, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 5)*8)]
        ct_butterfly data4, data5, rtmp, rtmp_tw
        ldrd rtmp, rtmp_tw, [r_ptr, #((-7 + 6)*8)]
        ct_butterfly data6, data7, rtmp, rtmp_tw

        vstrw.32 data4, [in, #(-128+64)]
        vstrw.32 data5, [in, #(-128+80)]
        vstrw.32 data6, [in, #(-128+96)]
        vstrw.32 data7, [in, #(-128+112)]

        le lr, layer456_loop

        sub in, in, #(4*256)

        .unreq rtmp
        .unreq rtmp_tw
        .unreq root2
        .unreq root2_tw

        /* Layers 7,8 */

        root0         .req q5
        root0_tw .req q6
        root1         .req q5
        root1_tw .req q6
        root2         .req q5
        root2_tw .req q6

        mov lr, #16
        .p2align 2
layer78_loop:
        vld40.32 {data0, data1, data2, data3}, [in]
        vld41.32 {data0, data1, data2, data3}, [in]
        vld42.32 {data0, data1, data2, data3}, [in]
        vld43.32 {data0, data1, data2, data3}, [in]!

        vldrw.32 root0,    [r_ptr], #+96
        vldrw.32 root0_tw, [r_ptr, #(+16-96)]
        ct_butterfly data0, data2, root0, root0_tw
        ct_butterfly data1, data3, root0, root0_tw

        vldrw.32 root1,         [r_ptr, #(32 - 96)]
        vldrw.32 root1_tw, [r_ptr, #(48 - 96)]
        ct_butterfly data0, data1, root1, root1_tw

        vldrw.32 root2,         [r_ptr, #(64-96)]
        vldrw.32 root2_tw, [r_ptr, #(80-96)]
        ct_butterfly data2, data3, root2, root2_tw

        vstrw.32 data0, [in, #( 0 - 64)]
        vstrw.32 data1, [in, #(16 - 64)]
        vstrw.32 data2, [in, #(32 - 64)]
        vstrw.32 data3, [in, #(48 - 64)]
        le lr, layer78_loop

        add sp, sp, #STACK_SIZE
        align_stack_undo

        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr

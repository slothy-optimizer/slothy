
///
/// Copyright (c) 2021 Arm Limited
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

.data
roots:
#include "ntt_kyber_1_23_45_67_twiddles.s"
.text

// Barrett multiplication
.macro mulmod dst, src, const, const_twisted
        vmul.s16       \dst,  \src, \const
        vqrdmulh.s16   \src,  \src, \const_twisted
        vmla.s16       \dst,  \src, modulus
.endm

.macro ct_butterfly a, b, root, root_twisted
        mulmod tmp, \b, \root, \root_twisted
        vsub.u16       \b,    \a, tmp
        vadd.u16       \a,    \a, tmp
.endm

.macro load_first_root root0, root0_twisted
        ldrd root0, root0_twisted, [root_ptr], #+8
.endm

.macro load_next_roots root0, root0_twisted, root1, root1_twisted, root2, root2_twisted
        ldrd root0, root0_twisted, [root_ptr], #+24
        ldrd root1, root1_twisted, [root_ptr, #(-16)]
        ldrd root2, root2_twisted, [root_ptr, #(-8)]
.endm

.align 4
roots_addr: .word roots
.syntax unified
.type ntt_kyber_1_23_45_67_opt, %function
.global ntt_kyber_1_23_45_67_opt
ntt_kyber_1_23_45_67_opt:

        push {r4-r11,lr}
        // Save MVE vector registers
        vpush {d8-d15}

        modulus  .req r12
        root_ptr .req r11

        .equ modulus_const, -3329
        movw modulus, #:lower16:modulus_const
        ldr  root_ptr, roots_addr

        in_low       .req r0
        in_high      .req r1

        add in_high, in_low, #(4*64)

        root0         .req r2
        root0_twisted .req r3
        root1         .req r4
        root1_twisted .req r5
        root2         .req r6
        root2_twisted .req r7

        data0 .req q0
        data1 .req q1
        data2 .req q2
        data3 .req q3

        tmp .req q4

        /* Layers 1 */

        load_first_root root0, root0_twisted

        mov lr, #16
        vldrw.u32 q6, [r1]
        vldrw.u32 q4, [r0]
        vqrdmulh.s16 q5, q6, r3
        vmul.s16 q6, q6, r2
        sub lr, lr, #1
.p2align 2
layer1_loop:
        vmla.s16 q6, q5, r12
        vadd.u16 q2, q4, q6
        vldrw.u32 q1, [r1, #16]
        vsub.u16 q7, q4, q6
        vmul.s16 q6, q1, r2
        vstrw.u32 q2, [r0] , #16
        vqrdmulh.s16 q5, q1, r3
        vldrw.u32 q4, [r0]
        vstrw.u32 q7, [r1] , #16
        le lr, layer1_loop
        vmla.s16 q6, q5, r12
        vsub.u16 q2, q4, q6
        vadd.u16 q4, q4, q6
        vstrw.u32 q4, [r0] , #16
        vstrw.u32 q2, [r1] , #16
        .unreq in_high
        .unreq in_low

        in .req r0
        sub in, in, #(4*64)

        /* Layers 2,3 */

        count .req r1
        mov count, #2

out_start:
        load_next_roots root0, root0_twisted, root1, root1_twisted, root2, root2_twisted

        mov lr, #4
        vldrw.u32 q2, [r0, #192]
        vqrdmulh.s16 q5, q2, r3
        vmul.s16 q4, q2, r2
        vmla.s16 q4, q5, r12
        vldrw.u32 q1, [r0, #64]
        vsub.u16 q3, q1, q4
        vmul.s16 q5, q3, r6
        vqrdmulh.s16 q3, q3, r7
        vldrw.u32 q0, [r0, #128]
        vmul.s16 q6, q0, r2
        vqrdmulh.s16 q7, q0, r3
        vadd.u16 q0, q1, q4
        vmla.s16 q6, q7, r12
        vmul.s16 q4, q0, r4
        sub lr, lr, #1
.p2align 2
layer23_loop:
        vmla.s16 q5, q3, r12
        vldrw.u32 q7, [r0]
        vsub.u16 q3, q7, q6
        vadd.u16 q2, q3, q5
        vsub.u16 q3, q3, q5
        vadd.u16 q5, q7, q6
        vldrw.u32 q1, [r0, #144]
        vmul.s16 q6, q1, r2
        vqrdmulh.s16 q0, q0, r5
        vmla.s16 q4, q0, r12
        vsub.u16 q0, q5, q4
        vadd.u16 q7, q5, q4
        vstrw.u32 q7, [r0] , #16
        vldrw.u32 q4, [r0, #192]
        vstrw.u32 q3, [r0, #176]
        vmul.s16 q7, q4, r2
        vqrdmulh.s16 q3, q4, r3
        vmla.s16 q7, q3, r12
        vstrw.u32 q2, [r0, #112]
        vstrw.u32 q0, [r0, #48]
        vqrdmulh.s16 q2, q1, r3
        vldrw.u32 q0, [r0, #64]
        vsub.u16 q4, q0, q7
        vqrdmulh.s16 q3, q4, r7
        vmul.s16 q5, q4, r6
        vmla.s16 q6, q2, r12
        vadd.u16 q0, q0, q7
        vmul.s16 q4, q0, r4
        le lr, layer23_loop
        vldrw.u32 q2, [r0]
        vqrdmulh.s16 q1, q0, r5
        vmla.s16 q4, q1, r12
        vadd.u16 q7, q2, q6
        vsub.u16 q6, q2, q6
        vmla.s16 q5, q3, r12
        vsub.u16 q0, q6, q5
        vstrw.u32 q0, [r0, #192]
        vadd.u16 q2, q6, q5
        vstrw.u32 q2, [r0, #128]
        vsub.u16 q6, q7, q4
        vadd.u16 q4, q7, q4
        vstrw.u32 q6, [r0, #64]
        vstrw.u32 q4, [r0] , #16

        add in, in, #(4*64 - 4*16)
        subs count, count, #1
        bne out_start

        sub in, in, #(4*128)

        /* Layers 4,5 */

        mov lr, #8
        ldrd r8, r6, [r11] , #24
        vldrw.u32 q4, [r0, #48]
        vmul.s16 q0, q4, r8
        vldrw.u32 q5, [r0, #32]
        vldrw.u32 q2, [r0]
        vmul.s16 q1, q5, r8
        vqrdmulh.s16 q6, q5, r6
        vmla.s16 q1, q6, r12
        ldrd r9, r3, [r11, #-8]
        vqrdmulh.s16 q4, q4, r6
        vmla.s16 q0, q4, r12
        vldrw.u32 q5, [r0, #16]
        vsub.u16 q6, q5, q0
        vmul.s16 q4, q6, r9
        vqrdmulh.s16 q6, q6, r3
        sub lr, lr, #1
.p2align 2
layer45_loop:
        vadd.u16 q0, q5, q0
        ldrd r3, r2, [r11] , #24
        vmla.s16 q4, q6, r12
        vsub.u16 q7, q2, q1
        vadd.u16 q3, q7, q4
        ldrd r8, r6, [r11, #-40]
        vmul.s16 q6, q0, r8
        vqrdmulh.s16 q0, q0, r6
        vmla.s16 q6, q0, r12
        vadd.u16 q5, q2, q1
        vadd.u16 q1, q5, q6
        vldrw.u32 q0, [r0, #112]
        vqrdmulh.s16 q2, q0, r2
        vmul.s16 q0, q0, r3
        vsub.u16 q4, q7, q4
        vmla.s16 q0, q2, r12
        vsub.u16 q2, q5, q6
        vst40.u32 {q1,q2,q3,q4}, [r0]
        vst41.u32 {q1,q2,q3,q4}, [r0]
        vst42.u32 {q1,q2,q3,q4}, [r0]
        vst43.u32 {q1,q2,q3,q4}, [r0]!
        vldrw.u32 q4, [r0, #32]
        vmul.s16 q1, q4, r3
        vqrdmulh.s16 q6, q4, r2
        ldrd r6, r2, [r11, #-8]
        vldrw.u32 q2, [r0]
        vldrw.u32 q5, [r0, #16]
        vmla.s16 q1, q6, r12
        vsub.u16 q7, q5, q0
        vmul.s16 q4, q7, r6
        vqrdmulh.s16 q6, q7, r2
        le lr, layer45_loop
        vsub.u16 q3, q2, q1
        vmla.s16 q4, q6, r12
        vsub.u16 q6, q3, q4
        ldrd r3, r2, [r11, #-16]
        vadd.u16 q7, q5, q0
        vadd.u16 q2, q2, q1
        vmul.s16 q0, q7, r3
        vadd.u16 q5, q3, q4
        vqrdmulh.s16 q7, q7, r2
        vmla.s16 q0, q7, r12
        vadd.u16 q3, q2, q0
        vsub.u16 q4, q2, q0
        vst40.u32 {q3,q4,q5,q6}, [r0]
        vst41.u32 {q3,q4,q5,q6}, [r0]
        vst42.u32 {q3,q4,q5,q6}, [r0]
        vst43.u32 {q3,q4,q5,q6}, [r0]!

        sub in, in, #(4*128)

        /* Layers 6,7 */

        .unreq root0
        .unreq root0_twisted
        .unreq root1
        .unreq root1_twisted
        .unreq root2
        .unreq root2_twisted

        root0         .req q5
        root0_twisted .req q6
        root1         .req q5
        root1_twisted .req q6
        root2         .req q5
        root2_twisted .req q6

        mov lr, #8
        vldrw.u32 q7, [r0]
        vldrw.u32 q4, [r0, #32]
        vldrw.u32 q6, [r0, #16]
        vldrh.u16 q1, [r11] , #96
        vldrh.u16 q2, [r11, #-80]
        vldrw.u32 q3, [r0, #48]
        vmul.s16 q5, q4, q1
        vqrdmulh.s16 q4, q4, q2
        vmla.s16 q5, q4, r12
        vadd.u16 q0, q7, q5
        vsub.u16 q7, q7, q5
        vqrdmulh.s16 q4, q3, q2
        vmul.s16 q5, q3, q1
        vmla.s16 q5, q4, r12
        vsub.u16 q3, q6, q5
        vadd.u16 q2, q6, q5
        vldrh.u16 q4, [r11, #-48]
        sub lr, lr, #1
.p2align 2
layer67_loop:
        vldrh.u16 q6, [r11, #-64]
        vmul.s16 q1, q2, q6
        vqrdmulh.s16 q4, q2, q4
        vmla.s16 q1, q4, r12
        vsub.u16 q2, q0, q1
        vldrh.u16 q4, [r11, #-16]
        vadd.u16 q1, q0, q1
        vldrh.u16 q5, [r11, #-32]
        vqrdmulh.s16 q4, q3, q4
        vmul.s16 q5, q3, q5
        vmla.s16 q5, q4, r12
        vsub.u16 q4, q7, q5
        vadd.u16 q3, q7, q5
        vst40.u32 {q1,q2,q3,q4}, [r0]
        vst41.u32 {q1,q2,q3,q4}, [r0]
        vst42.u32 {q1,q2,q3,q4}, [r0]
        vst43.u32 {q1,q2,q3,q4}, [r0]!
        vldrw.u32 q7, [r0, #32]
        vldrw.u32 q1, [r0, #16]
        vldrw.u32 q0, [r0]
        vldrh.u16 q4, [r11, #16]
        vldrh.u16 q3, [r11] , #96
        vldrw.u32 q5, [r0, #48]
        vqrdmulh.s16 q2, q7, q4
        vmul.s16 q6, q7, q3
        vmla.s16 q6, q2, r12
        vsub.u16 q7, q0, q6
        vqrdmulh.s16 q4, q5, q4
        vmul.s16 q5, q5, q3
        vmla.s16 q5, q4, r12
        vsub.u16 q3, q1, q5
        vadd.u16 q0, q0, q6
        vadd.u16 q2, q1, q5
        vldrh.u16 q4, [r11, #-48]
        le lr, layer67_loop
        vldrh.u16 q6, [r11, #-64]
        vmul.s16 q1, q2, q6
        vqrdmulh.s16 q5, q2, q4
        vmla.s16 q1, q5, r12
        vldrh.u16 q4, [r11, #-16]
        vsub.u16 q2, q0, q1
        vadd.u16 q1, q0, q1
        vldrh.u16 q6, [r11, #-32]
        vmul.s16 q5, q3, q6
        vqrdmulh.s16 q0, q3, q4
        vmla.s16 q5, q0, r12
        vadd.u16 q3, q7, q5
        vsub.u16 q4, q7, q5
        vst40.u32 {q1,q2,q3,q4}, [r0]
        vst41.u32 {q1,q2,q3,q4}, [r0]
        vst42.u32 {q1,q2,q3,q4}, [r0]
        vst43.u32 {q1,q2,q3,q4}, [r0]!

        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr
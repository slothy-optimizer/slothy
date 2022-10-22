
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
.type ntt_kyber_1_23_45_67, %function
.global ntt_kyber_1_23_45_67
ntt_kyber_1_23_45_67:

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
layer1_loop:
        vldrw.u32 data0, [in_low]
        vldrw.u32 data1, [in_high]

        ct_butterfly data0, data1, root0, root0_twisted

        vstrw.u32 data0, [in_low], #16
        vstrw.u32 data1, [in_high], #16

        le lr, layer1_loop
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
layer23_loop:
        vldrw.u32 data0, [in]
        vldrw.u32 data1, [in, #(4*1*16)]
        vldrw.u32 data2, [in, #(4*2*16)]
        vldrw.u32 data3, [in, #(4*3*16)]

        ct_butterfly data0, data2, root0, root0_twisted
        ct_butterfly data1, data3, root0, root0_twisted
        ct_butterfly data0, data1, root1, root1_twisted
        ct_butterfly data2, data3, root2, root2_twisted

        vstrw.u32 data0, [in], #16
        vstrw.u32 data1, [in, #(4*1*16 - 16)]
        vstrw.u32 data2, [in, #(4*2*16 - 16)]
        vstrw.u32 data3, [in, #(4*3*16 - 16)]

        le lr, layer23_loop

        add in, in, #(4*64 - 4*16)
        subs count, count, #1
        bne out_start

        sub in, in, #(4*128)

        /* Layers 4,5 */

        mov lr, #8
layer45_loop:
        load_next_roots root0, root0_twisted, root1, root1_twisted, root2, root2_twisted

        vldrw.u32 data0, [in]
        vldrw.u32 data1, [in, #16]
        vldrw.u32 data2, [in, #32]
        vldrw.u32 data3, [in, #48]

        ct_butterfly data0, data2, root0, root0_twisted
        ct_butterfly data1, data3, root0, root0_twisted
        ct_butterfly data0, data1, root1, root1_twisted
        ct_butterfly data2, data3, root2, root2_twisted

        vst40.u32 {data0, data1, data2, data3}, [in]
        vst41.u32 {data0, data1, data2, data3}, [in]
        vst42.u32 {data0, data1, data2, data3}, [in]
        vst43.u32 {data0, data1, data2, data3}, [in]!

        le lr, layer45_loop

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
layer67_loop:
        vldrw.u32 data0, [in]
        vldrw.u32 data1, [in, #16]
        vldrw.u32 data2, [in, #32]
        vldrw.u32 data3, [in, #48]

        vldrh.u16 root0,         [root_ptr], #+96
        vldrh.u16 root0_twisted, [root_ptr, #(+16-96)]
        ct_butterfly data0, data2, root0, root0_twisted
        ct_butterfly data1, data3, root0, root0_twisted

        vldrh.u16 root1,         [root_ptr, #(32 - 96)]
        vldrh.u16 root1_twisted, [root_ptr, #(48 - 96)]
        ct_butterfly data0, data1, root1, root1_twisted

        vldrh.u16 root2,         [root_ptr, #(64-96)]
        vldrh.u16 root2_twisted, [root_ptr, #(80-96)]
        ct_butterfly data2, data3, root2, root2_twisted

        vst40.u32 {data0, data1, data2, data3}, [in]
        vst41.u32 {data0, data1, data2, data3}, [in]
        vst42.u32 {data0, data1, data2, data3}, [in]
        vst43.u32 {data0, data1, data2, data3}, [in]!
        le lr, layer67_loop

        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr

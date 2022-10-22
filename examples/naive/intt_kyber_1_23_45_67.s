
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
roots_inv:
#include "intt_kyber_1_23_45_67_twiddles.s"
.text

// Barrett multiplication
.macro mulmod dst, src, const, const_twisted
        vmul.s16       \dst,  \src, \const
        vqrdmulh.s16   \src,  \src, \const_twisted
        vmla.s16       \dst,  \src, modulus
.endm

.macro gs_butterfly a, b, root, root_twisted
        vsub.u16       tmp, \a,  \b
        vadd.u16       \a,  \a,  \b
        mulmod         \b,  tmp, \root, \root_twisted
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
roots_addr: .word roots_inv
.syntax unified
.type intt_kyber_1_23_45_67, %function
.global intt_kyber_1_23_45_67
intt_kyber_1_23_45_67:

        push {r4-r11,lr}
        // Save MVE vector registers
        vpush {d8-d15}

        modulus     .req r12
        root_ptr    .req r11

        .equ modulus_const, -3329
        movw modulus, #:lower16:modulus_const
        ldr  root_ptr, roots_addr

        in .req r0

        data0 .req q0
        data1 .req q1
        data2 .req q2
        data3 .req q3

        root0         .req q5
        root0_twisted .req q6
        root1         .req q5
        root1_twisted .req q6
        root2         .req q5
        root2_twisted .req q6

        tmp .req q4

        /* Layers 6,7 */

        mov lr, #8
layer67_loop:
        vldrw.u32 data0, [in]
        vldrw.u32 data1, [in, #(4*4*1)]
        vldrw.u32 data2, [in, #(4*4*2)]
        vldrw.u32 data3, [in, #(4*4*3)]

        vldrw.u32 root1,         [root_ptr, #(32)]
        vldrw.u32 root1_twisted, [root_ptr, #(32+16)]
        gs_butterfly data0, data1, root1, root1_twisted

        vldrw.u32 root2,         [root_ptr, #(64)]
        vldrw.u32 root2_twisted, [root_ptr, #(64+16)]
        gs_butterfly data2, data3, root2, root2_twisted

        vldrw.u32 root0,         [root_ptr], #(3*32)
        vldrw.u32 root0_twisted, [root_ptr, #(16 - 3*32)]
        gs_butterfly data0, data2, root0, root0_twisted
        gs_butterfly data1, data3, root0, root0_twisted

        vstrw.u32 data0, [in], #64
        vstrw.u32 data1, [in, #(4*4*1 - 64)]
        vstrw.u32 data2, [in, #(4*4*2 - 64)]
        vstrw.u32 data3, [in, #(4*4*3 - 64)]

        le lr, layer67_loop

        sub in, in, #(4*128)

        .unreq root0
        .unreq root0_twisted
        .unreq root1
        .unreq root1_twisted
        .unreq root2
        .unreq root2_twisted

        root0         .req r2
        root0_twisted .req r3
        root1         .req r4
        root1_twisted .req r5
        root2         .req r6
        root2_twisted .req r7

        .equ const_barrett, 10079
        .equ barrett_shift, 10

        // TEMPORARY: Barrett reduction
        //
        // This is grossly inefficient and largely unnecessary, but it's just outside
        // the scope of our work to optimize this: We only want to demonstrate the
        // ability of Helight to optimize the core loops.
        barrett_const .req r1
        movw barrett_const, #:lower16:const_barrett
        mov lr, #32
1:
        vldrh.u16 data0, [in]
        vqdmulh.s16 tmp, data0, barrett_const
        vrshr.s16 tmp, tmp, barrett_shift
        vmla.s16 data0, tmp, modulus
        vstrh.u16 data0, [in], #16
        le lr, 1b
2:
        sub in, in, #(4*128)
        .unreq barrett_const

        /* Layers 4,5 */

        mov lr, #8
layer45_loop:
        load_next_roots root0, root0_twisted, root1, root1_twisted, root2, root2_twisted

        vld40.u32 {data0, data1, data2, data3}, [in]
        vld41.u32 {data0, data1, data2, data3}, [in]
        vld42.u32 {data0, data1, data2, data3}, [in]
        vld43.u32 {data0, data1, data2, data3}, [in]!

        gs_butterfly data0, data1, root1, root1_twisted
        gs_butterfly data2, data3, root2, root2_twisted
        gs_butterfly data0, data2, root0, root0_twisted
        gs_butterfly data1, data3, root0, root0_twisted

        vstrw.u32 data0, [in, #(4*4*0 - 64)]
        vstrw.u32 data1, [in, #(4*4*1 - 64)]
        vstrw.u32 data2, [in, #(4*4*2 - 64)]
        vstrw.u32 data3, [in, #(4*4*3 - 64)]

        le lr, layer45_loop

        sub in, in, #(4*128)

        // TEMPORARY: Barrett reduction
        //
        // This is grossly inefficient and largely unnecessary, but it's just outside
        // the scope of our work to optimize this: We only want to demonstrate the
        // ability of Helight to optimize the core loops.

        barrett_const .req r1
        movw barrett_const, #:lower16:const_barrett
        mov lr, #32
1:
        vldrh.u16 data0, [in]
        vqdmulh.s16 tmp, data0, barrett_const
        vrshr.s16 tmp, tmp, barrett_shift
        vmla.s16 data0, tmp, modulus
        vstrh.u16 data0, [in], #16
        le lr, 1b
2:
        sub in, in, #(4*128)
        .unreq barrett_const

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

        gs_butterfly data0, data1, root1, root1_twisted
        gs_butterfly data2, data3, root2, root2_twisted
        gs_butterfly data0, data2, root0, root0_twisted
        gs_butterfly data1, data3, root0, root0_twisted

        vstrw.u32 data0, [in], #(16)
        vstrw.u32 data1, [in, #(4*16*1 - 16)]
        vstrw.u32 data2, [in, #(4*16*2 - 16)]
        vstrw.u32 data3, [in, #(4*16*3 - 16)]

        le lr, layer23_loop
        add in, in, #(4*64 - 4*16)
        subs count, count, #1
        bne out_start

        sub in, in, #(4*128)

        // TEMPORARY: Barrett reduction
        //
        // This is grossly inefficient and largely unnecessary, but it's just outside
        // the scope of our work to optimize this: We only want to demonstrate the
        // ability of Helight to optimize the core loops.
        barrett_const .req r1
        movw barrett_const, #:lower16:const_barrett
        mov lr, #32
1:
        vldrh.u16 data0, [in]
        vqdmulh.s16 tmp, data0, barrett_const
        vrshr.s16 tmp, tmp, barrett_shift
        vmla.s16 data0, tmp, modulus
        vstrh.u16 data0, [in], #16
        le lr, 1b
2:
        sub in, in, #(4*128)
        .unreq barrett_const

        in_low       .req r0
        in_high      .req r1
        add in_high, in_low, #(4*64)

        /* Layers 1 */

        load_first_root root0, root0_twisted

        mov lr, #16
layer1_loop:

        vldrw.u32 data0, [in_low]
        vldrw.u32 data1, [in_high]

        gs_butterfly data0, data1, root0, root0_twisted

        vstrw.u32 data0, [in_low], #16
        vstrw.u32 data1, [in_high], #16

        le lr, layer1_loop

        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr

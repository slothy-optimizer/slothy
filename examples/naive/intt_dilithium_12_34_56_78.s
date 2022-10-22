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

.data
roots_inv:
#include "intt_dilithium_12_34_56_78_twiddles.s"
.text

// Barrett multiplication
.macro mulmod dst, src, const, const_twisted
        vmul.s32       \dst,  \src, \const
        vqrdmulh.s32   \src,  \src, \const_twisted
        vmla.s32       \dst,  \src, modulus
.endm

.macro gs_butterfly a, b, root, root_twisted
        vsub.u32       tmp, \a,  \b
        vadd.u32       \a,  \a,  \b
        mulmod         \b,  tmp, \root, \root_twisted
.endm

.align 4
roots_addr: .word roots_inv
.syntax unified
.type intt_dilithium_12_34_56_78, %function
.global intt_dilithium_12_34_56_78
intt_dilithium_12_34_56_78:

        push {r4-r11,lr}
        // Save MVE vector registers
        vpush {d8-d15}

        modulus     .req r12
        root_ptr    .req r11

        .equ modulus_const, -8380417
        movw modulus, #:lower16:modulus_const
        movt modulus, #:upper16:modulus_const
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

        /* Layers 7,8 */

        mov lr, #16
layer78_loop:
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

        le lr, layer78_loop

        sub in, in, #(4*256)

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

        /* Layers 5,6 */

        mov lr, #16
layer56_loop:
        ldrd root0, root0_twisted, [root_ptr], #24
        ldrd root1, root1_twisted, [root_ptr, #-16]
        ldrd root2, root2_twisted, [root_ptr, #-8]

        vld40.u32 {data0, data1, data2, data3}, [in]
        vld41.u32 {data0, data1, data2, data3}, [in]
        vld42.u32 {data0, data1, data2, data3}, [in]
        vld43.u32 {data0, data1, data2, data3}, [in]

        gs_butterfly data0, data1, root1, root1_twisted
        gs_butterfly data2, data3, root2, root2_twisted
        gs_butterfly data0, data2, root0, root0_twisted
        gs_butterfly data1, data3, root0, root0_twisted

        vstrw.u32 data0, [in], #(64)
        vstrw.u32 data1, [in, #(4*4*1 - 64)]
        vstrw.u32 data2, [in, #(4*4*2 - 64)]
        vstrw.u32 data3, [in, #(4*4*3 - 64)]

        le lr, layer56_loop

        sub in, in, #(4*256)

        // TEMPORARY: Barrett reduction
        //
        // This is grossly inefficient and largely unnecessary, but it's just outside
        // the scope of our work to optimize this: We only want to demonstrate the
        // ability of Helight to optimize the core loops.
        barrett_const .req r1
        .equ const_barrett, 63
        movw barrett_const, #:lower16:const_barrett
        movt barrett_const, #:upper16:const_barrett
        mov lr, #64
1:
        vldrw.u32 data0, [in]
        vqrdmulh.s32 tmp, data0, barrett_const
        vmla.s32 data0, tmp, modulus
        vstrw.u32 data0, [in], #16
        le lr, 1b
2:
        sub in, in, #(4*256)
        .unreq barrett_const

        /* Layers 3,4 */

        // 4 butterfly blocks per root config, 4 root configs
        // loop over root configs

        count .req r1
        mov count, #4

out_start:
        ldrd root0, root0_twisted, [root_ptr], #+8
        ldrd root1, root1_twisted, [root_ptr], #+8
        ldrd root2, root2_twisted, [root_ptr], #+8

        mov lr, #4
layer34_loop:
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

        le lr, layer34_loop
        add in, in, #(4*64 - 4*16)

        subs count, count, #1
        bne out_start

        sub in, in, #(4*256)

        // TEMPORARY: Barrett reduction
        //
        // This is grossly inefficient and largely unnecessary, but it's just outside
        // the scope of our work to optimize this: We only want to demonstrate the
        // ability of Helight to optimize the core loops.
        barrett_const .req r1
        .equ const_barrett, 63
        movw barrett_const, #:lower16:const_barrett
        movt barrett_const, #:upper16:const_barrett
        mov lr, #64
1:
        vldrw.u32 data0, [in]
        vqrdmulh.s32 tmp, data0, barrett_const
        vmla.s32 data0, tmp, modulus
        vstrw.u32 data0, [in], #16
        le lr, 1b
2:
        sub in, in, #(4*256)
        .unreq barrett_const

        in_low       .req r0
        in_high      .req r1
        add in_high, in_low, #(4*128)

        /* Layers 1,2 */

        ldrd root0, root0_twisted, [root_ptr], #+8
        ldrd root1, root1_twisted, [root_ptr], #+8
        ldrd root2, root2_twisted, [root_ptr], #+8

        mov lr, #16
layer12_loop:

        vldrw.u32 data0, [in_low]
        vldrw.u32 data1, [in_low,  #(4*64)]
        vldrw.u32 data2, [in_high]
        vldrw.u32 data3, [in_high, #(4*64)]

        gs_butterfly data0, data1, root1, root1_twisted
        gs_butterfly data2, data3, root2, root2_twisted
        gs_butterfly data0, data2, root0, root0_twisted
        gs_butterfly data1, data3, root0, root0_twisted

        vstrw.u32 data0, [in_low], #16
        vstrw.u32 data1, [in_low, #(4*64 - 16)]
        vstrw.u32 data2, [in_high], #16
        vstrw.u32 data3, [in_high, #(4*64 - 16)]

        le lr, layer12_loop

        // Restore MVE vector registers
        vpop {d8-d15}
        // Restore GPRs
        pop {r4-r11,lr}
        bx lr

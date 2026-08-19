///
/// Copyright (c) 2025 Justus Bergermann
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

    #define in       x10
    // == a0, first function arg
    //#define gp    x3
    #define modulus  x4
    #define root_ptr x5
    #define xtmp     x6

    #define data0  v0
    #define data1  v1
    #define data2  v2
    #define data3  v3
    #define data4  v4
    #define data5  v5
    #define data6  v6
    #define data7  v7
    #define data8  v8
    #define data9  v9
    #define data10 v10
    #define data11 v11
    #define data12 v12
    #define data13 v13
    #define data14 v14
    #define data15 v15

    // load first 5 roots only on demand due to limited number of registers
    #define barretc_1  x7
    // root1 = \psi^bitinverse(1), root2 = \psi^bitinverse(2) ...
    #define barretc_2  x8
    // barretc_1 = floor((root1 << k)\modulus) ...
    #define barretc_3  x9
    #define barretc_4  x1
    #define barretc_5  x11
    #define root6      x12
    #define barretc_6  x13
    #define root7      x14
    #define barretc_7  x15
    #define root8      x16
    #define barretc_8  x17
    #define root9      x18
    #define barretc_9  x19
    #define root10     x20
    #define barretc_10 x21
    #define root11     x22
    #define barretc_11 x23
    #define root12     x24
    #define barretc_12 x25
    #define root13     x26
    #define barretc_13 x27
    #define root14     x28
    #define barretc_14 x29
    #define root15     x30
    #define barretc_15 x31

    #define vtmp0    v16
    // used by barret_mul
    #define vtmp1    v17
    // used by ct_butterfly
    #define vtmp2    v18
    // free to use
    #define vmodulus v19
    // vectorized modulus

.macro barret_mul dst, a, b, barret_const
    vmul.vx \dst, \a, \b                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, \a, \barret_const               // t = (a * barret_const) >> k, signed: a may be negative
    vnmsac.vx \dst, modulus, vtmp0                  // z = z - n * t
.endm

.macro ct_butterfly a, b, root, barret_const
    barret_mul vtmp1, \b, \root, \barret_const         // vtmp1 = root * b mod modulus
    vsub.vv \b, \a, vtmp1                           // b = b - vtmp1
    vadd.vv \a, \a, vtmp1                           // a = a + vtmp1
.endm

.macro barret_mul_v vdst, va, vb, vbarret_const
    vmul.vv \vdst, \va, \vb                         // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vv vtmp0, \va, \vbarret_const             // t = (a * barret_const) >> k, signed: a may be negative
    vnmsac.vx \vdst, modulus, vtmp0                // z = z - n * t
.endm

.macro ct_butterfly_v va, vb, vroot, vbarret_const
    barret_mul_v vtmp1, \vb, \vroot, \vbarret_const    // vtmp1 = vroot * vb mod modulus
    vsub.vv \vb, \va, vtmp1                         // b = b - vtmp1
    vadd.vv \va, \va, vtmp1                         // a = a + vtmp1
.endm

.macro transpose4 data, ptr
    vsseg4e32.v \data, (\ptr)   // @slothy:writes=[transpose_buf]
    vl4re32.v   \data, (\ptr)   // @slothy:reads=[transpose_buf]
    // alternative:
    // vle32.v data0, ptr
    // vle32.v data1, ptr+1 etc.
.endm

.macro load_roots_1234  root_ptr, barretc_1, barretc_2, barretc_3, barretc_4, barretc_5,        \
                        root6, barretc_6, root7, barretc_7, root8, barretc_8, root9, barretc_9, \
                        root10, barretc_10, root11, barretc_11, root12, barretc_12, root13,     \
                        barretc_13, root14, barretc_14, root15, barretc_15
    lw \barretc_1,  (0*8+4)(\root_ptr)
    lw \barretc_2,  (1*8+4)(\root_ptr)
    lw \barretc_3,  (2*8+4)(\root_ptr)
    lw \barretc_4,  (3*8+4)(\root_ptr)
    lw \barretc_5,  (4*8+4)(\root_ptr)
    lw \root6,      (5*8)(\root_ptr)
    lw \barretc_6,  (5*8+4)(\root_ptr)
    lw \root7,      (6*8)(\root_ptr)
    lw \barretc_7,  (6*8+4)(\root_ptr)
    lw \root8,      (7*8)(\root_ptr)
    lw \barretc_8,  (7*8+4)(\root_ptr)
    lw \root9,      (8*8)(\root_ptr)
    lw \barretc_9,  (8*8+4)(\root_ptr)
    lw \root10,     (9*8)(\root_ptr)
    lw \barretc_10, (9*8+4)(\root_ptr)
    lw \root11,     (10*8)(\root_ptr)
    lw \barretc_11, (10*8+4)(\root_ptr)
    lw \root12,     (11*8)(\root_ptr)
    lw \barretc_12, (11*8+4)(\root_ptr)
    lw \root13,     (12*8)(\root_ptr)
    lw \barretc_13, (12*8+4)(\root_ptr)
    lw \root14,     (13*8)(\root_ptr)
    lw \barretc_14, (13*8+4)(\root_ptr)
    lw \root15,     (14*8)(\root_ptr)
    lw \barretc_15, (14*8+4)(\root_ptr)
.endm


.macro load_roots_5678  xroot1, xbarretc_1, xroot2, xbarretc_2, xroot3, xbarretc_3, \
                        vroot1, vbarretc_1, vroot2, vbarretc_2,  vroot3, vbarretc_3,\
                        root_ptr
    lw \xroot1,     (0*8)(\root_ptr)
    lw \xbarretc_1, (0*8+4)(\root_ptr)
    lw \xroot2,     (1*8)(\root_ptr)
    lw \xbarretc_2, (1*8+4)(\root_ptr)
    lw \xroot3,     (2*8)(\root_ptr)
    lw \xbarretc_3,  (2*8+4)(\root_ptr)
    addi \root_ptr, \root_ptr, 3*8  // increment root_ptr manually here, bc vle32 does not allow offsets
    vle32.v \vroot1, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
    vle32.v \vbarretc_1, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
    vle32.v \vroot2, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
    vle32.v \vbarretc_2, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
    vle32.v \vroot3, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
    vle32.v \vbarretc_3, (\root_ptr)
    addi \root_ptr, \root_ptr, 16
.endm

.macro load16 in, stride
    .irp r, data0,data1,data2,data3,data4,data5,data6,data7,\
            data8,data9,data10,data11,data12,data13,data14
        vle32.v \r, (\in)
        addi \in, \in, \stride
    .endr
    vle32.v data15, (\in)
.endm

.macro store16 in, stride
    .irp r, data0,data1,data2,data3,data4,data5,data6,data7,\
            data8,data9,data10,data11,data12,data13,data14
        vse32.v \r, (\in)
        addi \in, \in, \stride
    .endr
    vse32.v data15, (\in)
.endm

.macro push_stack
    addi sp, sp, -8*15
    sd s0,  0*8(sp)
    sd s1,  1*8(sp)
    sd s2,  2*8(sp)
    sd s3,  3*8(sp)
    sd s4,  4*8(sp)
    sd s5,  5*8(sp)
    sd s6,  6*8(sp)
    sd s7,  7*8(sp)
    sd s8,  8*8(sp)
    sd s9,  9*8(sp)
    sd s10, 10*8(sp)
    sd s11, 11*8(sp)
    sd gp,  12*8(sp)
    sd tp,  13*8(sp)
    sd ra,  14*8(sp)
.endm

.macro pop_stack
    ld s0,  0*8(sp)
    ld s1,  1*8(sp)
    ld s2,  2*8(sp)
    ld s3,  3*8(sp)
    ld s4,  4*8(sp)
    ld s5,  5*8(sp)
    ld s6,  6*8(sp)
    ld s7,  7*8(sp)
    ld s8,  8*8(sp)
    ld s9,  9*8(sp)
    ld s10, 10*8(sp)
    ld s11, 11*8(sp)
    ld gp,  12*8(sp)
    ld tp,  13*8(sp)
    ld ra,  14*8(sp)
    addi sp, sp, 8*15
.endm

.data

.p2align 4
roots:
#include "ntt_dilithium_1234_5678_twiddles_barret_mul.s"
.text
    .global ntt_dilithium_1234_5678
    .global _ntt_dilithium_1234_5678
.p2align 4

.globl ntt_rvv_vlen128_barret_mul
ntt_rvv_vlen128_barret_mul:
_ntt_rvv_vlen128_barret_mul:
    push_stack // save scalar regs here
    vsetivli zero, 4, e32, m1   // configure vector unit, 4*32 bit elements per vector @ VLEN=128
    start:
    li modulus, 8380417         // load dilithium modulus
    vmv.v.x vmodulus, modulus   // copy modulus into vector register

    .equ L_STRIDE, 64           // Load Stride = distance between coefficients pairs of four
    .equ S_STRIDE, 16           // Shift Stride = distance of coefficients between two iterations

    la root_ptr, roots          // load address of roots in memory into root_ptr

    load_roots_1234 root_ptr, barretc_1, barretc_2, barretc_3, barretc_4, barretc_5, \
    root6, barretc_6, root7, barretc_7, root8, barretc_8, root9, barretc_9, root10, barretc_10, \
    root11, barretc_11, root12, barretc_12, root13, barretc_13, root14, barretc_14, root15, barretc_15

    li gp, 4

    .p2align 2
layer1234_start:
    // Load 64 coefficients. For VLEN = 128 each register holds 4* 4 byte = 32 bit coefficients. Hence, 16 regs required
    // Base register must be incremented by L_STRIDE = 64 byte to load the correct coefficient pairs.

    load16 in, L_STRIDE
    addi in, in, -15*L_STRIDE   // decrement pointer to original value

    lw xtmp, 0*8(root_ptr)  // xtmp = root1

    // Merge 4 layers (interleaved)
    // level 1 - Stride = 128*4 byte -> BF(a0,a128), BF(a16, a144) ...
    ct_butterfly data0, data8, xtmp, barretc_1
    ct_butterfly data1, data9, xtmp, barretc_1
    ct_butterfly data2, data10, xtmp, barretc_1
    ct_butterfly data3, data11, xtmp, barretc_1
    ct_butterfly data4, data12, xtmp, barretc_1
    ct_butterfly data5, data13, xtmp, barretc_1
    ct_butterfly data6, data14, xtmp, barretc_1
    ct_butterfly data7, data15, xtmp, barretc_1

    lw xtmp, 1*8(root_ptr)  // xtmp = root2

    // level 2 - Stride = 64*4 byte -> BF(a0, a64), BF(16, 80) ...
    ct_butterfly data0, data4, xtmp, barretc_2
    ct_butterfly data1, data5, xtmp, barretc_2
    ct_butterfly data2, data6, xtmp, barretc_2
    ct_butterfly data3, data7, xtmp, barretc_2

    lw xtmp, 2*8(root_ptr)  // xtmp = root3

    ct_butterfly data8, data12, xtmp, barretc_3
    ct_butterfly data9, data13, xtmp, barretc_3
    ct_butterfly data10, data14, xtmp, barretc_3
    ct_butterfly data11, data15, xtmp, barretc_3

    lw xtmp, 3*8(root_ptr)  // xtmp = root4

    // level 3 - Stride = 32*4 byte -> BF(a0, a32), BF(a16, a48) ...
    ct_butterfly data0, data2, xtmp, barretc_4
    ct_butterfly data1, data3, xtmp, barretc_4

    lw xtmp, 4*8(root_ptr)  // xtmp = root5

    ct_butterfly data4, data6, xtmp, barretc_5
    ct_butterfly data5, data7, xtmp, barretc_5
    ct_butterfly data8, data10, root6, barretc_6
    ct_butterfly data9, data11, root6, barretc_6
    ct_butterfly data12, data14, root7, barretc_7
    ct_butterfly data13, data15, root7, barretc_7

    // level 4 - Stride = 16*4 byte -> BF(a0, a16), BF(a32, a48) ...
    ct_butterfly data0, data1, root8, barretc_8
    ct_butterfly data2, data3, root9, barretc_9
    ct_butterfly data4, data5, root10, barretc_10
    ct_butterfly data6, data7, root11, barretc_11
    ct_butterfly data8, data9, root12, barretc_12
    ct_butterfly data10, data11, root13, barretc_13
    ct_butterfly data12, data13, root14, barretc_14
    ct_butterfly data14, data15, root15, barretc_15


    store16 in, L_STRIDE        // store results
    addi in, in, -15*L_STRIDE   // decrement pointer to original value

    addi in, in, S_STRIDE       // load next coeffient pairs, all shifted by 16 bytes
//layer1234_end:
    addi gp, gp, -1
    bnez gp, layer1234_start

    #undef barretc_1
    #undef barretc_2
    #undef barretc_3
    #undef barretc_4
    #undef barretc_5
    #undef root6

    #define xroot1      x7
    #define xbarretc_1  x8
    #define xroot2      x9
    #define xbarretc_2  x1
    #define xroot3      x11
    #define xbarretc_3  x12

    #define vroot1      v19
    #define vbarretc_1  v20
    #define vroot2      v21
    #define vbarretc_2   v22
    #define vroot3      v23
    #define vbarretc_3  v24
    addi in, in, -4*S_STRIDE    // reset in pointer to original value, has been updated 4 x S_STRIDE in the previous loop
                                // other implementation saved original in to stack, maybe consider that ...
    li gp, 16
    addi root_ptr, root_ptr, 16*8 // point to twiddles for layer5678, starting with root16
                                  // 16*8: skip 15 root/barretc pairs + 1 padding pair (pad=[0] in twiddle gen)

    .equ L_STRIDE_2, 16
    .equ S_STRIDE_2, 64  // check again

    .p2align 2
layer5678_start:
    vle32.v data0, (in)
    addi in, in, L_STRIDE_2
    vle32.v data1, (in)
    addi in, in, L_STRIDE_2
    vle32.v data2, (in)
    addi in, in, L_STRIDE_2
    vle32.v data3, (in)

    addi in, in, -3*L_STRIDE_2  // decrement pointer to original value

    load_roots_5678 xroot1, xbarretc_1, xroot2, xbarretc_2, xroot3, xbarretc_3,\
                         vroot1, vbarretc_1, vroot2, vbarretc_2, vroot3, vbarretc_3,\
                         root_ptr

    // level 5+6
    ct_butterfly data0, data2, xroot1, xbarretc_1  // Stride = 8*4 byte -> BF(a0, a8), BF(a4, a12) ...
    ct_butterfly data1, data3, xroot1, xbarretc_1
    ct_butterfly data0, data1, xroot2, xbarretc_2  // Stride = 4*4 byte -> BF(a0, a4), BF(a8, a12) ...
    ct_butterfly data2, data3, xroot3, xbarretc_3

    addi sp, sp, -64  // allocate 64 byte of memory for 4 vector registers
    transpose4 data0, sp  // necessary bc coefficients required for ct_butterfly would be in same regs otherwise
    addi sp, sp, 64  // free memory

    // level 7+8
    ct_butterfly_v data0, data2, vroot1, vbarretc_1  // Stride = 2*4 byte -> BF(a0, a2), BF(a4, a6) ...
    ct_butterfly_v data1, data3, vroot1, vbarretc_1
    ct_butterfly_v data0, data1, vroot2, vbarretc_2  // Stride = 1*4 byte -> BF(a0, a1), BF(a2, a3) ...
    ct_butterfly_v data2, data3, vroot3, vbarretc_3

    // store results, transpose back before. Corresponds to https://fprox.substack.com/i/139455473/x-matrix-transpose-using-strided-vector-stores
    vsseg4e32.v data0, (in)  // Store packed vector of 4*4-byte segments from data0, data1, data2, data3 to memory

    // alternative store, might be faster. Corresponds to https://fprox.substack.com/i/139455473/x-matrix-transpose-using-segmented-vector-stores
    // Benchmarks: https://pastebin.com/gQB76kgy
    //li vtmp2, L_STRIDE
    //vsse32.v data0, (in), vtmp2
    //addi in, in, L_STRIDE
    //vsse32.v data1, (in), vtmp2
    //addi in, in, L_STRIDE
    //vsse32.v data2, (in), vtmp2
    //addi in, in, L_STRIDE
    //vsse32.v data3, (in), vtmp2
    // addi in, in, -3*L_STRIDE  // decrement pointer to original value

    addi in, in, S_STRIDE_2  // load next coeffient pairs, all shifted by 64 bytes
    addi gp, gp, -1
    bnez gp, layer5678_start
    end:
    pop_stack
    ret

// TODOs:
// - check pointer inc/ decr and move right after
// documentation
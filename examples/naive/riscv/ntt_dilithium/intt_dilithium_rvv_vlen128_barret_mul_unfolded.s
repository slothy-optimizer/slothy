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

// Inverse NTT for Dilithium (VLEN = 128) with Barrett multiplication, the counterpart of
// ntt_rvv_vlen128_barret_mul (ntt_dilithium_rvv_vlen128_barret_mul.s). Input in the order of that
// NTT (= upstream's NTT order), output as upstream's invntt_tomont: multiplied by 2^32, in (-q, q).
// Gentleman-Sande butterflies with plain roots (include/intt_dilithium_1234_5678_twiddles_barret_mul.s).
//   layer8765: 16 blocks of 16 coefficients; levels 8, 7 (len 1, 2) on the transposed block
//              (vlseg4e32), then levels 6, 5 (len 4, 8).
//   layer4321: 4 x 64 coefficients (as layer1234 of the NTT); levels 4, 3, 2 (len 16, 32, 64) and
//              level 1 (len 128) merged with the scaling by 2^32 / 256, then x >= q ? x - q : x.
// Bounds: as in upstream's invntt_tomont the sums are not reduced (|input| < q rules out overflow);
// Barrett products are in (-q/4, 5q/4).
// Uses only caller-saved scalar registers, so nothing is saved. The SLOTHY config reserves the
// callee-saved ones (CALLEE_SAVED in _example.py), so the opt version keeps this. Loop counter:
// t2 (an ABI name, as SLOTHY's loop detection requires).

    #define in        x10
    // == a0, first function arg (a1, the twiddle pointer, is not used)
    #define root_ptr  x5
    #define modulus   x6

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

    #define vtmp0  v16
    // used by barret_mul
    #define vtmp1  v17
    // used by gs_butterfly, gs_butterfly_scale, csubq
    #define vtmp2  v18
    // used by gs_butterfly_scale, csubq

    // layer8765: twiddles of one block
    #define vroot1      v19
    #define vbarretc_1  v20
    #define vroot2      v21
    #define vbarretc_2  v22
    #define vroot3      v23
    #define vbarretc_3  v24
    #define xroot1      x12
    #define xbarretc_1  x13
    #define xroot2      x14
    #define xbarretc_2  x15
    #define xroot3      x16
    #define xbarretc_3  x17

    // layer4321: twiddles, loaded on demand
    #define xroot       x28
    #define xbarretc    x29
    #define xroot_f     x30
    #define xbarretc_f  x31

.macro barret_mul dst, a, b, barret_const
    vmul.vx \dst, \a, \b                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, \a, \barret_const               // t = (a * barret_const) >> 32
    vnmsac.vx \dst, modulus, vtmp0                  // z = z - n * t
.endm

.macro barret_mul_v vdst, va, vb, vbarret_const
    vmul.vv \vdst, \va, \vb                         // z = a*b = coefficient (vect) * root (vect)
    vmulh.vv vtmp0, \va, \vbarret_const             // t = (a * barret_const) >> 32
    vnmsac.vx \vdst, modulus, vtmp0                 // z = z - n * t
.endm

.macro gs_butterfly a, b, root, barret_const
    vsub.vv vtmp1, \a, \b                           // vtmp1 = a - b
    vadd.vv \a, \a, \b                              // a = a + b
    barret_mul \b, vtmp1, \root, \barret_const      // b = (a - b) * root mod modulus
.endm

.macro gs_butterfly_v va, vb, vroot, vbarret_const
    vsub.vv vtmp1, \va, \vb                         // vtmp1 = a - b
    vadd.vv \va, \va, \vb                           // a = a + b
    barret_mul_v \vb, vtmp1, \vroot, \vbarret_const // b = (a - b) * root mod modulus
.endm

// last level, merged with the final scaling: a = (a + b) * f, b = (a - b) * root * f
.macro gs_butterfly_scale a, b, root_f, barret_const, f, barret_const_f
    vadd.vv vtmp1, \a, \b                           // vtmp1 = a + b
    vsub.vv vtmp2, \a, \b                           // vtmp2 = a - b
    barret_mul \a, vtmp1, \f, \barret_const_f
    barret_mul \b, vtmp2, \root_f, \barret_const
.endm

// a = a >= modulus ? a - modulus : a, for a in (-q/4, 5q/4)
.macro csubq a
    vsub.vx vtmp1, \a, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv \a, vtmp1, vtmp2
.endm

.macro transpose4 data, ptr
    vsseg4e32.v \data, (\ptr)   // @slothy:writes=['transpose_buf']
    vl4re32.v   \data, (\ptr)   // @slothy:reads=['transpose_buf']
.endm

.macro load16 in, stride
    vle32.v data0, (\in)
    addi \in, \in, \stride
    vle32.v data1, (\in)
    addi \in, \in, \stride
    vle32.v data2, (\in)
    addi \in, \in, \stride
    vle32.v data3, (\in)
    addi \in, \in, \stride
    vle32.v data4, (\in)
    addi \in, \in, \stride
    vle32.v data5, (\in)
    addi \in, \in, \stride
    vle32.v data6, (\in)
    addi \in, \in, \stride
    vle32.v data7, (\in)
    addi \in, \in, \stride
    vle32.v data8, (\in)
    addi \in, \in, \stride
    vle32.v data9, (\in)
    addi \in, \in, \stride
    vle32.v data10, (\in)
    addi \in, \in, \stride
    vle32.v data11, (\in)
    addi \in, \in, \stride
    vle32.v data12, (\in)
    addi \in, \in, \stride
    vle32.v data13, (\in)
    addi \in, \in, \stride
    vle32.v data14, (\in)
    addi \in, \in, \stride
    vle32.v data15, (\in)
.endm

.macro store16 in, stride
    vse32.v data0, (\in)
    addi \in, \in, \stride
    vse32.v data1, (\in)
    addi \in, \in, \stride
    vse32.v data2, (\in)
    addi \in, \in, \stride
    vse32.v data3, (\in)
    addi \in, \in, \stride
    vse32.v data4, (\in)
    addi \in, \in, \stride
    vse32.v data5, (\in)
    addi \in, \in, \stride
    vse32.v data6, (\in)
    addi \in, \in, \stride
    vse32.v data7, (\in)
    addi \in, \in, \stride
    vse32.v data8, (\in)
    addi \in, \in, \stride
    vse32.v data9, (\in)
    addi \in, \in, \stride
    vse32.v data10, (\in)
    addi \in, \in, \stride
    vse32.v data11, (\in)
    addi \in, \in, \stride
    vse32.v data12, (\in)
    addi \in, \in, \stride
    vse32.v data13, (\in)
    addi \in, \in, \stride
    vse32.v data14, (\in)
    addi \in, \in, \stride
    vse32.v data15, (\in)
.endm

.data

.p2align 4
roots:
#include "intt_dilithium_1234_5678_twiddles_barret_mul.s"
.text
.p2align 4

.globl intt_rvv_vlen128_barret_mul
intt_rvv_vlen128_barret_mul:
_intt_rvv_vlen128_barret_mul:
    vsetivli zero, 4, e32, m1   // configure vector unit, 4*32 bit elements per vector @ VLEN=128
    start:
    li modulus, 8380417         // load dilithium modulus

    .equ L_STRIDE_1, 16         // layer8765: distance between the four registers of a block
    .equ L_STRIDE_2, 64         // layer4321: distance between the 16 registers
    .equ S_STRIDE_2, 16         // layer4321: shift between two iterations

    la root_ptr, roots          // load address of roots in memory into root_ptr

    li t2, 16

    .p2align 2
layer8765_start:
    // Load a block of 16 coefficients transposed: data_m[l] = coefficient 4*l + m of the block
    vlseg4e32.v data0, (in)

    vle32.v vroot1, (root_ptr)
    addi root_ptr, root_ptr, 16
    vle32.v vbarretc_1, (root_ptr)
    addi root_ptr, root_ptr, 16
    vle32.v vroot2, (root_ptr)
    addi root_ptr, root_ptr, 16
    vle32.v vbarretc_2, (root_ptr)
    addi root_ptr, root_ptr, 16
    vle32.v vroot3, (root_ptr)
    addi root_ptr, root_ptr, 16
    vle32.v vbarretc_3, (root_ptr)
    addi root_ptr, root_ptr, 16
    lw xroot1,     (0*8)(root_ptr)
    lw xbarretc_1, (0*8+4)(root_ptr)
    lw xroot2,     (1*8)(root_ptr)
    lw xbarretc_2, (1*8+4)(root_ptr)
    lw xroot3,     (2*8)(root_ptr)
    lw xbarretc_3, (2*8+4)(root_ptr)
    addi root_ptr, root_ptr, 3*8

    // level 8 - Stride = 1*4 byte -> BF(a0, a1), BF(a2, a3) ...
    vsub.vv vtmp1, data0, data1                         // vtmp1 = a - b
    vadd.vv data0, data0, data1                           // a = a + b
    vmul.vv data1, vtmp1, vroot1                         // z = a*b = coefficient (vect) * root (vect)
    vmulh.vv vtmp0, vtmp1, vbarretc_1             // t = (a * barret_const) >> 32
    vnmsac.vx data1, modulus, vtmp0                 // z = z - n * t
    vsub.vv vtmp1, data2, data3                         // vtmp1 = a - b
    vadd.vv data2, data2, data3                           // a = a + b
    vmul.vv data3, vtmp1, vroot2                         // z = a*b = coefficient (vect) * root (vect)
    vmulh.vv vtmp0, vtmp1, vbarretc_2             // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                 // z = z - n * t
    // level 7 - Stride = 2*4 byte -> BF(a0, a2), BF(a1, a3) ...
    vsub.vv vtmp1, data0, data2                         // vtmp1 = a - b
    vadd.vv data0, data0, data2                           // a = a + b
    vmul.vv data2, vtmp1, vroot3                         // z = a*b = coefficient (vect) * root (vect)
    vmulh.vv vtmp0, vtmp1, vbarretc_3             // t = (a * barret_const) >> 32
    vnmsac.vx data2, modulus, vtmp0                 // z = z - n * t
    vsub.vv vtmp1, data1, data3                         // vtmp1 = a - b
    vadd.vv data1, data1, data3                           // a = a + b
    vmul.vv data3, vtmp1, vroot3                         // z = a*b = coefficient (vect) * root (vect)
    vmulh.vv vtmp0, vtmp1, vbarretc_3             // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                 // z = z - n * t

    addi sp, sp, -64  // allocate 64 byte of memory for 4 vector registers
    vsseg4e32.v data0, (sp)   // @slothy:writes=['transpose_buf']
    vl4re32.v   data0, (sp)   // @slothy:reads=['transpose_buf']
    addi sp, sp, 64  // free memory

    // level 6 - Stride = 4*4 byte -> BF(a0, a4), BF(a8, a12) ...
    vsub.vv vtmp1, data0, data1                           // vtmp1 = a - b
    vadd.vv data0, data0, data1                              // a = a + b
    vmul.vx data1, vtmp1, xroot1                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_1               // t = (a * barret_const) >> 32
    vnmsac.vx data1, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data2, data3                           // vtmp1 = a - b
    vadd.vv data2, data2, data3                              // a = a + b
    vmul.vx data3, vtmp1, xroot2                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_2               // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                  // z = z - n * t
    // level 5 - Stride = 8*4 byte -> BF(a0, a8), BF(a4, a12) ...
    vsub.vv vtmp1, data0, data2                           // vtmp1 = a - b
    vadd.vv data0, data0, data2                              // a = a + b
    vmul.vx data2, vtmp1, xroot3                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_3               // t = (a * barret_const) >> 32
    vnmsac.vx data2, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data1, data3                           // vtmp1 = a - b
    vadd.vv data1, data1, data3                              // a = a + b
    vmul.vx data3, vtmp1, xroot3                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_3               // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                  // z = z - n * t

    vse32.v data0, (in)
    addi in, in, L_STRIDE_1
    vse32.v data1, (in)
    addi in, in, L_STRIDE_1
    vse32.v data2, (in)
    addi in, in, L_STRIDE_1
    vse32.v data3, (in)
    addi in, in, L_STRIDE_1     // next block

    addi t2, t2, -1
    bnez t2, layer8765_start

    addi in, in, -16*4*L_STRIDE_1   // reset in pointer (16 blocks of 64 bytes)
    li t2, 4                  // root_ptr now points to roots_l3210

    .p2align 2
layer4321_start:
    // Load 64 coefficients, data_k[l] = coefficient 16*k + 4*i + l in iteration i
    vle32.v data0, (in)
    addi in, in, L_STRIDE_2
    vle32.v data1, (in)
    addi in, in, L_STRIDE_2
    vle32.v data2, (in)
    addi in, in, L_STRIDE_2
    vle32.v data3, (in)
    addi in, in, L_STRIDE_2
    vle32.v data4, (in)
    addi in, in, L_STRIDE_2
    vle32.v data5, (in)
    addi in, in, L_STRIDE_2
    vle32.v data6, (in)
    addi in, in, L_STRIDE_2
    vle32.v data7, (in)
    addi in, in, L_STRIDE_2
    vle32.v data8, (in)
    addi in, in, L_STRIDE_2
    vle32.v data9, (in)
    addi in, in, L_STRIDE_2
    vle32.v data10, (in)
    addi in, in, L_STRIDE_2
    vle32.v data11, (in)
    addi in, in, L_STRIDE_2
    vle32.v data12, (in)
    addi in, in, L_STRIDE_2
    vle32.v data13, (in)
    addi in, in, L_STRIDE_2
    vle32.v data14, (in)
    addi in, in, L_STRIDE_2
    vle32.v data15, (in)
    addi in, in, -15*L_STRIDE_2     // decrement pointer to original value

    // level 4 - Stride = 16*4 byte -> BF(a0, a16), BF(a32, a48) ...
    lw xroot,    (0*8)(root_ptr)
    lw xbarretc, (0*8+4)(root_ptr)
    vsub.vv vtmp1, data0, data1                           // vtmp1 = a - b
    vadd.vv data0, data0, data1                              // a = a + b
    vmul.vx data1, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data1, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (1*8)(root_ptr)
    lw xbarretc, (1*8+4)(root_ptr)
    vsub.vv vtmp1, data2, data3                           // vtmp1 = a - b
    vadd.vv data2, data2, data3                              // a = a + b
    vmul.vx data3, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (2*8)(root_ptr)
    lw xbarretc, (2*8+4)(root_ptr)
    vsub.vv vtmp1, data4, data5                           // vtmp1 = a - b
    vadd.vv data4, data4, data5                              // a = a + b
    vmul.vx data5, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data5, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (3*8)(root_ptr)
    lw xbarretc, (3*8+4)(root_ptr)
    vsub.vv vtmp1, data6, data7                           // vtmp1 = a - b
    vadd.vv data6, data6, data7                              // a = a + b
    vmul.vx data7, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data7, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (4*8)(root_ptr)
    lw xbarretc, (4*8+4)(root_ptr)
    vsub.vv vtmp1, data8, data9                           // vtmp1 = a - b
    vadd.vv data8, data8, data9                              // a = a + b
    vmul.vx data9, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data9, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (5*8)(root_ptr)
    lw xbarretc, (5*8+4)(root_ptr)
    vsub.vv vtmp1, data10, data11                           // vtmp1 = a - b
    vadd.vv data10, data10, data11                              // a = a + b
    vmul.vx data11, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data11, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (6*8)(root_ptr)
    lw xbarretc, (6*8+4)(root_ptr)
    vsub.vv vtmp1, data12, data13                           // vtmp1 = a - b
    vadd.vv data12, data12, data13                              // a = a + b
    vmul.vx data13, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data13, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (7*8)(root_ptr)
    lw xbarretc, (7*8+4)(root_ptr)
    vsub.vv vtmp1, data14, data15                           // vtmp1 = a - b
    vadd.vv data14, data14, data15                              // a = a + b
    vmul.vx data15, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data15, modulus, vtmp0                  // z = z - n * t

    // level 3 - Stride = 32*4 byte -> BF(a0, a32), BF(a16, a48) ...
    lw xroot,    (8*8)(root_ptr)
    lw xbarretc, (8*8+4)(root_ptr)
    vsub.vv vtmp1, data0, data2                           // vtmp1 = a - b
    vadd.vv data0, data0, data2                              // a = a + b
    vmul.vx data2, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data2, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data1, data3                           // vtmp1 = a - b
    vadd.vv data1, data1, data3                              // a = a + b
    vmul.vx data3, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (9*8)(root_ptr)
    lw xbarretc, (9*8+4)(root_ptr)
    vsub.vv vtmp1, data4, data6                           // vtmp1 = a - b
    vadd.vv data4, data4, data6                              // a = a + b
    vmul.vx data6, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data6, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data5, data7                           // vtmp1 = a - b
    vadd.vv data5, data5, data7                              // a = a + b
    vmul.vx data7, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data7, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (10*8)(root_ptr)
    lw xbarretc, (10*8+4)(root_ptr)
    vsub.vv vtmp1, data8, data10                           // vtmp1 = a - b
    vadd.vv data8, data8, data10                              // a = a + b
    vmul.vx data10, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data10, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data9, data11                           // vtmp1 = a - b
    vadd.vv data9, data9, data11                              // a = a + b
    vmul.vx data11, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data11, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (11*8)(root_ptr)
    lw xbarretc, (11*8+4)(root_ptr)
    vsub.vv vtmp1, data12, data14                           // vtmp1 = a - b
    vadd.vv data12, data12, data14                              // a = a + b
    vmul.vx data14, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data14, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data13, data15                           // vtmp1 = a - b
    vadd.vv data13, data13, data15                              // a = a + b
    vmul.vx data15, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data15, modulus, vtmp0                  // z = z - n * t

    // level 2 - Stride = 64*4 byte -> BF(a0, a64), BF(a16, a80) ...
    lw xroot,    (12*8)(root_ptr)
    lw xbarretc, (12*8+4)(root_ptr)
    vsub.vv vtmp1, data0, data4                           // vtmp1 = a - b
    vadd.vv data0, data0, data4                              // a = a + b
    vmul.vx data4, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data4, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data1, data5                           // vtmp1 = a - b
    vadd.vv data1, data1, data5                              // a = a + b
    vmul.vx data5, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data5, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data2, data6                           // vtmp1 = a - b
    vadd.vv data2, data2, data6                              // a = a + b
    vmul.vx data6, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data6, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data3, data7                           // vtmp1 = a - b
    vadd.vv data3, data3, data7                              // a = a + b
    vmul.vx data7, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data7, modulus, vtmp0                  // z = z - n * t
    lw xroot,    (13*8)(root_ptr)
    lw xbarretc, (13*8+4)(root_ptr)
    vsub.vv vtmp1, data8, data12                           // vtmp1 = a - b
    vadd.vv data8, data8, data12                              // a = a + b
    vmul.vx data12, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data12, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data9, data13                           // vtmp1 = a - b
    vadd.vv data9, data9, data13                              // a = a + b
    vmul.vx data13, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data13, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data10, data14                           // vtmp1 = a - b
    vadd.vv data10, data10, data14                              // a = a + b
    vmul.vx data14, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data14, modulus, vtmp0                  // z = z - n * t
    vsub.vv vtmp1, data11, data15                           // vtmp1 = a - b
    vadd.vv data11, data11, data15                              // a = a + b
    vmul.vx data15, vtmp1, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data15, modulus, vtmp0                  // z = z - n * t

    // level 1 - Stride = 128*4 byte -> BF(a0, a128), BF(a16, a144) ..., merged with the scaling
    lw xroot,      (14*8)(root_ptr)     // root * f
    lw xbarretc,   (14*8+4)(root_ptr)
    lw xroot_f,    (15*8)(root_ptr)     // f = 2^32 / 256 mod q
    lw xbarretc_f, (15*8+4)(root_ptr)
    vadd.vv vtmp1, data0, data8                           // vtmp1 = a + b
    vsub.vv vtmp2, data0, data8                           // vtmp2 = a - b
    vmul.vx data0, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data0, modulus, vtmp0                  // z = z - n * t
    vmul.vx data8, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data8, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data1, data9                           // vtmp1 = a + b
    vsub.vv vtmp2, data1, data9                           // vtmp2 = a - b
    vmul.vx data1, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data1, modulus, vtmp0                  // z = z - n * t
    vmul.vx data9, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data9, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data2, data10                           // vtmp1 = a + b
    vsub.vv vtmp2, data2, data10                           // vtmp2 = a - b
    vmul.vx data2, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data2, modulus, vtmp0                  // z = z - n * t
    vmul.vx data10, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data10, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data3, data11                           // vtmp1 = a + b
    vsub.vv vtmp2, data3, data11                           // vtmp2 = a - b
    vmul.vx data3, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data3, modulus, vtmp0                  // z = z - n * t
    vmul.vx data11, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data11, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data4, data12                           // vtmp1 = a + b
    vsub.vv vtmp2, data4, data12                           // vtmp2 = a - b
    vmul.vx data4, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data4, modulus, vtmp0                  // z = z - n * t
    vmul.vx data12, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data12, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data5, data13                           // vtmp1 = a + b
    vsub.vv vtmp2, data5, data13                           // vtmp2 = a - b
    vmul.vx data5, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data5, modulus, vtmp0                  // z = z - n * t
    vmul.vx data13, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data13, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data6, data14                           // vtmp1 = a + b
    vsub.vv vtmp2, data6, data14                           // vtmp2 = a - b
    vmul.vx data6, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data6, modulus, vtmp0                  // z = z - n * t
    vmul.vx data14, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data14, modulus, vtmp0                  // z = z - n * t
    vadd.vv vtmp1, data7, data15                           // vtmp1 = a + b
    vsub.vv vtmp2, data7, data15                           // vtmp2 = a - b
    vmul.vx data7, vtmp1, xroot_f                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp1, xbarretc_f               // t = (a * barret_const) >> 32
    vnmsac.vx data7, modulus, vtmp0                  // z = z - n * t
    vmul.vx data15, vtmp2, xroot                            // z = a*b = coefficient (vect) * root (scalar)
    vmulh.vx vtmp0, vtmp2, xbarretc               // t = (a * barret_const) >> 32
    vnmsac.vx data15, modulus, vtmp0                  // z = z - n * t

    // (-q/4, 5q/4) -> (-q, q), as upstream's invntt_tomont
    vsub.vx vtmp1, data0, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data0, vtmp1, vtmp2
    vsub.vx vtmp1, data1, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data1, vtmp1, vtmp2
    vsub.vx vtmp1, data2, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data2, vtmp1, vtmp2
    vsub.vx vtmp1, data3, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data3, vtmp1, vtmp2
    vsub.vx vtmp1, data4, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data4, vtmp1, vtmp2
    vsub.vx vtmp1, data5, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data5, vtmp1, vtmp2
    vsub.vx vtmp1, data6, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data6, vtmp1, vtmp2
    vsub.vx vtmp1, data7, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data7, vtmp1, vtmp2
    vsub.vx vtmp1, data8, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data8, vtmp1, vtmp2
    vsub.vx vtmp1, data9, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data9, vtmp1, vtmp2
    vsub.vx vtmp1, data10, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data10, vtmp1, vtmp2
    vsub.vx vtmp1, data11, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data11, vtmp1, vtmp2
    vsub.vx vtmp1, data12, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data12, vtmp1, vtmp2
    vsub.vx vtmp1, data13, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data13, vtmp1, vtmp2
    vsub.vx vtmp1, data14, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data14, vtmp1, vtmp2
    vsub.vx vtmp1, data15, modulus                      // vtmp1 = a - q
    vsra.vi vtmp2, vtmp1, 31                        // vtmp2 = a - q < 0 ? -1 : 0
    vand.vx vtmp2, vtmp2, modulus                   // vtmp2 = a - q < 0 ? q : 0
    vadd.vv data15, vtmp1, vtmp2

    vse32.v data0, (in)
    addi in, in, L_STRIDE_2
    vse32.v data1, (in)
    addi in, in, L_STRIDE_2
    vse32.v data2, (in)
    addi in, in, L_STRIDE_2
    vse32.v data3, (in)
    addi in, in, L_STRIDE_2
    vse32.v data4, (in)
    addi in, in, L_STRIDE_2
    vse32.v data5, (in)
    addi in, in, L_STRIDE_2
    vse32.v data6, (in)
    addi in, in, L_STRIDE_2
    vse32.v data7, (in)
    addi in, in, L_STRIDE_2
    vse32.v data8, (in)
    addi in, in, L_STRIDE_2
    vse32.v data9, (in)
    addi in, in, L_STRIDE_2
    vse32.v data10, (in)
    addi in, in, L_STRIDE_2
    vse32.v data11, (in)
    addi in, in, L_STRIDE_2
    vse32.v data12, (in)
    addi in, in, L_STRIDE_2
    vse32.v data13, (in)
    addi in, in, L_STRIDE_2
    vse32.v data14, (in)
    addi in, in, L_STRIDE_2
    vse32.v data15, (in)
    addi in, in, -15*L_STRIDE_2     // decrement pointer to original value
    addi in, in, S_STRIDE_2         // next 4 coefficients of each register, shifted by 16 bytes

    addi t2, t2, -1
    bnez t2, layer4321_start
    end:
    ret

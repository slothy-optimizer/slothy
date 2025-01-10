// 
// Code from https://github.com/Ji-Peng/PQRV/blob/2463d15ba6c49d05d45ff427b72646e038c860da/ntt/dilithium/ntt_8l_singleissue_plant_rv64im.S
// 
// The MIT license, the text of which is below, applies to PQRV in general.
// We have reused public-domain code from the following repositories: https://github.com/pq-crystals/kyber and https://github.com/pq-crystals/dilithium.
// 
// Copyright (c) 2024 Jipeng Zhang (jp-zhang@outlook.com)
// SPDX-License-Identifier: MIT
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 


.macro load_coeffs poly, len, wordLen
  lw s0,  \len*\wordLen*0(\poly)
  lw s1,  \len*\wordLen*1(\poly)
  lw s2,  \len*\wordLen*2(\poly)
  lw s3,  \len*\wordLen*3(\poly)
  lw s4,  \len*\wordLen*4(\poly)
  lw s5,  \len*\wordLen*5(\poly)
  lw s6,  \len*\wordLen*6(\poly)
  lw s7,  \len*\wordLen*7(\poly)
  lw s8,  \len*\wordLen*8(\poly)
  lw s9,  \len*\wordLen*9(\poly)
  lw s10, \len*\wordLen*10(\poly)
  lw s11, \len*\wordLen*11(\poly)
  lw a2,  \len*\wordLen*12(\poly)
  lw a3,  \len*\wordLen*13(\poly)
  lw a4,  \len*\wordLen*14(\poly)
  lw a5,  \len*\wordLen*15(\poly)
.endm

.macro store_coeffs poly, len, wordLen
  sw s0,  \len*\wordLen*0(\poly)
  sw s1,  \len*\wordLen*1(\poly)
  sw s2,  \len*\wordLen*2(\poly)
  sw s3,  \len*\wordLen*3(\poly)
  sw s4,  \len*\wordLen*4(\poly)
  sw s5,  \len*\wordLen*5(\poly)
  sw s6,  \len*\wordLen*6(\poly)
  sw s7,  \len*\wordLen*7(\poly)
  sw s8,  \len*\wordLen*8(\poly)
  sw s9,  \len*\wordLen*9(\poly)
  sw s10, \len*\wordLen*10(\poly)
  sw s11, \len*\wordLen*11(\poly)
  sw a2,  \len*\wordLen*12(\poly)
  sw a3,  \len*\wordLen*13(\poly)
  sw a4,  \len*\wordLen*14(\poly)
  sw a5,  \len*\wordLen*15(\poly)
.endm

.macro save_regs
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

.macro restore_regs
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
.endm



// a <- a*b*(-2^{-64}) mod+- q
// q32: q<<32; bqinv: b*qinv
.macro plant_mul_const_inplace q32, bqinv, a
  mul  \a, \a, \bqinv
  srai \a, \a, 32
  addi \a, \a, 256
  mulh \a, \a, \q32
.endm

// r <- a*b*(-2^{-64}) mod+- q
// q32: q<<32; bqinv: b*qinv
.macro plant_mul_const q32, bqinv, a, r
    mul  \r, \a, \bqinv
    srai \r, \r, 32
    addi \r, \r, 256
    mulh \r, \r, \q32
.endm

// each layer increases coefficients by 0.5q; In ct_bfu, twiddle and tmp can be reused because each twiddle is only used once. The gs_bfu cannot.
.macro ct_bfu coeff0, coeff1, twiddle, q, tmp
  plant_mul_const \q, \twiddle, \coeff1, \tmp
  sub \coeff1, \coeff0, \tmp
  add \coeff0, \coeff0, \tmp
.endm

.macro gs_bfu coeff0, coeff1, twiddle, q, tmp
  sub \tmp, \coeff0, \coeff1
  add \coeff0, \coeff0, \coeff1
  plant_mul_const \q, \twiddle, \tmp, \coeff1
.endm

// in-place plantard reduction to a
// output \in (-0.5q, 0.5q); q32: q<<32
.macro plant_red q32, qinv, a
  mul  \a, \a, \qinv
  srai \a, \a, 32
  addi \a, \a, 256
  mulh \a, \a, \q32
.endm

.macro plant_red_x4 q32, qinv, a_0, a_1, a_2, a_3
  mul  \a_0, \a_0, \qinv
  mul  \a_1, \a_1, \qinv
  mul  \a_2, \a_2, \qinv
  mul  \a_3, \a_3, \qinv
  srai \a_0, \a_0, 32
  srai \a_1, \a_1, 32
  srai \a_2, \a_2, 32
  srai \a_3, \a_3, 32
  addi \a_0, \a_0, 256
  addi \a_1, \a_1, 256
  addi \a_2, \a_2, 256
  addi \a_3, \a_3, 256
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
  mulh \a_2, \a_2, \q32
  mulh \a_3, \a_3, \q32
.endm

.equ q,    8380417
.equ q32,  0x7fe00100000000               // q << 32
.equ qinv, 0x180a406003802001             // q^-1 mod 2^64
.equ plantconst, 0x200801c0602            // (((-2**64) % q) * qinv) % (2**64)
.equ plantconst2, 0xb7b9f10ccf939804      // (((-2**64) % q) * ((-2**64) % q) * qinv) % (2**64)

// |input| < 0.5q; |output| < 4q
// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp, variable twiddle factors; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 9 twiddle factors: can be preloaded; t0-t6, tp, ra.
.global ntt_8l_rv64im
.align 2
ntt_8l_rv64im:
  addi sp, sp, -8*15
  save_regs
  li a6, q32          // q<<32
  addi a0, a0, 16*4   // poly[16]
  addi gp, x0, 15     // loop
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  ld tp, 7*8(a1)
  ld ra, 8*8(a1)

  //// LAYER 1+2+3+4
  ntt_8l_rv64im_loop1:
    // main_loop_1:
    addi a0, a0, -4
    load_coeffs a0, 16, 4
    // layer 1

    ct_bfu s0, s8,  t0, a6, a7
    ct_bfu s1, s9,  t0, a6, a7
    ct_bfu s2, s10, t0, a6, a7
    ct_bfu s3, s11, t0, a6, a7
    ct_bfu s4, a2,  t0, a6, a7
    ct_bfu s5, a3,  t0, a6, a7
    ct_bfu s6, a4,  t0, a6, a7
    ct_bfu s7, a5,  t0, a6, a7

    // layer 2
    ct_bfu s0,  s4, t1, a6, a7
    ct_bfu s1,  s5, t1, a6, a7
    ct_bfu s2,  s6, t1, a6, a7
    ct_bfu s3,  s7, t1, a6, a7
    ct_bfu s8,  a2, t2, a6, a7
    ct_bfu s9,  a3, t2, a6, a7
    ct_bfu s10, a4, t2, a6, a7
    ct_bfu s11, a5, t2, a6, a7

    // layer 3
    ct_bfu s0, s2,  t3, a6, a7
    ct_bfu s1, s3,  t3, a6, a7
    ct_bfu s4, s6,  t4, a6, a7
    ct_bfu s5, s7,  t4, a6, a7
    ct_bfu s8, s10, t5, a6, a7
    ct_bfu s9, s11, t5, a6, a7
    ct_bfu a2, a4,  t6, a6, a7
    ct_bfu a3, a5,  t6, a6, a7

    // layer 4
    ct_bfu s0,  s1,  tp, a6, a7
    ct_bfu s2,  s3,  ra, a6, a7 
    ld a7, 9*8(a1)
    ct_bfu s4,  s5,  a7, a6, a7
    ld a7, 10*8(a1)


    ct_bfu s6,  s7,  a7, a6, a7
    ld a7, 11*8(a1)
    ct_bfu s8,  s9,  a7, a6, a7
    ld a7, 12*8(a1)
    ct_bfu s10, s11, a7, a6, a7
    ld a7, 13*8(a1)
    ct_bfu a2,  a3,  a7, a6, a7
    ld a7, 14*8(a1)
    ct_bfu a4,  a5,  a7, a6, a7

    store_coeffs a0, 16, 4
    //end_loop_1:
  addi gp, gp, -1
  bge gp, zero, ntt_8l_rv64im_loop1
  addi a1, a1, 15*8
  //// LAYER 5+6+7+8
  addi gp, x0, 16
  ntt_8l_rv64im_loop2:
    //main_loop_2:
    load_coeffs a0, 1, 4
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    ld tp, 7*8(a1)
    ld ra, 8*8(a1)
    // layer 5
    ct_bfu s0, s8,  t0, a6, a7
    ct_bfu s1, s9,  t0, a6, a7
    ct_bfu s2, s10, t0, a6, a7
    ct_bfu s3, s11, t0, a6, a7
    ct_bfu s4, a2,  t0, a6, a7
    ct_bfu s5, a3,  t0, a6, a7
    ct_bfu s6, a4,  t0, a6, a7
    ct_bfu s7, a5,  t0, a6, a7
    // layer 6
    ct_bfu s0,  s4, t1, a6, a7
    ct_bfu s1,  s5, t1, a6, a7
    ct_bfu s2,  s6, t1, a6, a7
    ct_bfu s3,  s7, t1, a6, a7
    ct_bfu s8,  a2, t2, a6, a7
    ct_bfu s9,  a3, t2, a6, a7
    ct_bfu s10, a4, t2, a6, a7
    ct_bfu s11, a5, t2, a6, a7
    // layer 7
    ct_bfu s0, s2,  t3, a6, a7
    ct_bfu s1, s3,  t3, a6, a7
    ct_bfu s4, s6,  t4, a6, a7
    ct_bfu s5, s7,  t4, a6, a7
    ct_bfu s8, s10, t5, a6, a7
    ct_bfu s9, s11, t5, a6, a7
    ct_bfu a2, a4,  t6, a6, a7
    ct_bfu a3, a5,  t6, a6, a7
    // layer 8
    ct_bfu s0,  s1,  tp, a6, a7
    ct_bfu s2,  s3,  ra, a6, a7 
    ld a7, 9*8(a1)
    ct_bfu s4,  s5,  a7, a6, a7
    ld a7, 10*8(a1)
    ct_bfu s6,  s7,  a7, a6, a7
    ld a7, 11*8(a1)
    ct_bfu s8,  s9,  a7, a6, a7
    ld a7, 12*8(a1)
    ct_bfu s10, s11, a7, a6, a7
    ld a7, 13*8(a1)
    ct_bfu a2,  a3,  a7, a6, a7
    ld a7, 14*8(a1)
    ct_bfu a4,  a5,  a7, a6, a7
    store_coeffs a0, 1, 4
    addi a0, a0, 16*4
    addi a1, a1, 15*8
    //end_loop_2:
  addi gp, gp, -1
  bne gp, zero, ntt_8l_rv64im_loop2
  restore_regs
  addi sp, sp, 8*15
  ret



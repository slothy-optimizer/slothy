/// Copyright (c) 2024 Jipeng Zhang (jp-zhang@outlook.com) (Original Code)
/// Copyright (c) 2026 Amin Abdulrahman (amin@abdulrahman.de) (Modifications)
/// Copyright (c) 2026 Justus Bergermann (mail@justus-bergermann.de) (Modifications)
///
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

.macro load_coeffs poly, len, wordLen
  lh s0,  \len*\wordLen*0(\poly)
  lh s1,  \len*\wordLen*1(\poly)
  lh s2,  \len*\wordLen*2(\poly)
  lh s3,  \len*\wordLen*3(\poly)
  lh s4,  \len*\wordLen*4(\poly)
  lh s5,  \len*\wordLen*5(\poly)
  lh s6,  \len*\wordLen*6(\poly)
  lh s7,  \len*\wordLen*7(\poly)
  lh s8,  \len*\wordLen*8(\poly)
  lh s9,  \len*\wordLen*9(\poly)
  lh s10, \len*\wordLen*10(\poly)
  lh s11, \len*\wordLen*11(\poly)
  lh a2,  \len*\wordLen*12(\poly)
  lh a3,  \len*\wordLen*13(\poly)
  lh a4,  \len*\wordLen*14(\poly)
  lh a5,  \len*\wordLen*15(\poly)
.endm

.macro store_coeffs poly, len, wordLen
  sh s0,  \len*\wordLen*0(\poly)
  sh s1,  \len*\wordLen*1(\poly)
  sh s2,  \len*\wordLen*2(\poly)
  sh s3,  \len*\wordLen*3(\poly)
  sh s4,  \len*\wordLen*4(\poly)
  sh s5,  \len*\wordLen*5(\poly)
  sh s6,  \len*\wordLen*6(\poly)
  sh s7,  \len*\wordLen*7(\poly)
  sh s8,  \len*\wordLen*8(\poly)
  sh s9,  \len*\wordLen*9(\poly)
  sh s10, \len*\wordLen*10(\poly)
  sh s11, \len*\wordLen*11(\poly)
  sh a2,  \len*\wordLen*12(\poly)
  sh a3,  \len*\wordLen*13(\poly)
  sh a4,  \len*\wordLen*14(\poly)
  sh a5,  \len*\wordLen*15(\poly)
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
  addi \a, \a, 8
  mulh \a, \a, \q32
.endm

// r <- a*b*(-2^{-64}) mod+- q
// q32: q<<32; bqinv: b*qinv
.macro plant_mul_const q32, bqinv, a, r
    mul  \r, \a, \bqinv
    srai \r, \r, 32
    addi \r, \r, 8
    mulh \r, \r, \q32
.endm

// each layer increases coefficients by 0.5q; In ct_butterfly, twiddle and tmp can be reused because each twiddle is only used once. The gs_butterfly cannot.
.macro ct_butterfly coeff0, coeff1, twiddle, q, tmp
  plant_mul_const \q, \twiddle, \coeff1, \tmp
  sub \coeff1, \coeff0, \tmp
  add \coeff0, \coeff0, \tmp
.endm

.macro gs_butterfly coeff0, coeff1, twiddle, q, tmp
  sub \tmp, \coeff0, \coeff1
  add \coeff0, \coeff0, \coeff1
  plant_mul_const \q, \twiddle, \tmp, \coeff1
.endm

// in-place plantard reduction to a
// output \in (-0.5q, 0.5q); q32: q<<32
.macro plant_red q32, qinv, a
  mul  \a, \a, \qinv
  srai \a, \a, 32
  addi \a, \a, 8
  mulh \a, \a, \q32
.endm

.equ q,    3329
.equ q32,  0xd0100000000                // q << 32
.equ qinv, 0x3c0f12886ba8f301           // q^-1 mod 2^64
.equ plantconst, 0x13afb7680bb055       // (((-2**64) % q) * qinv) % (2**64)
.equ plantconst2, 0x1a390f4d9791e139    // (((-2**64) % q) * ((-2**64) % q) * qinv) % (2**64)

// void poly_basemul_acc_cache_init_rv64im(int32_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, uint64_t *zetas)
// compute basemul, cache bzeta into b_cache, and accumulate the 32-bit results into r
// a0: r, a1: a, a2: b, a3: b_cache, a4: zetas
// a5: q<<32, a6: loop control, a7: accumulated value
// t0-t3: a[2i,2i+1],b[2i,2i+1]
// t4: zeta, t5-t6: temp
.global poly_basemul_acc_cache_init_rv64im
.align 2
poly_basemul_acc_cache_init_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a5, q32
    li a6, 64
poly_basemul_acc_cache_init_rv64im_loop:
    lh t2, 2*0(a2) // b[0]
    lh t3, 2*1(a2) // b[1]
    ld t4, 8*0(a4) // zeta
    lh t0, 2*0(a1) // a[0]
    lh t1, 2*1(a1) // a[1]
    // r[0]=a[0]b[0]+a[1](b[1]zeta), r[1]=a[0]b[1]+a[1]b[0]
    plant_mul_const a5, t4, t3, t5
    sh  t5, 2*0(a3)  // store b[1]zeta for later usage
    lw  a7, 4*0(a0)
    mul t5, t1, t5
    mul t6, t0, t2
    add t5, t5, t6  // r[0]
    add t5, t5, a7
    sw  t5, 4*0(a0)
    lw  a7, 4*1(a0)
    mul t5, t0, t3
    mul t6, t1, t2
    add t5, t5, t6  // r[1]
    add t5, t5, a7
    sw  t5, 4*1(a0)
    neg t4, t4      // -zeta
    // r[2], r[3]
    lh t2, 2*2(a2)
    lh t3, 2*3(a2)
    lh t0, 2*2(a1)
    lh t1, 2*3(a1)
    plant_mul_const a5, t4, t3, t5
    sh  t5, 2*1(a3)
    lw  a7, 4*2(a0)
    mul t5, t1, t5
    mul t6, t0, t2
    add t5, t5, t6
    add t5, t5, a7
    sw  t5, 4*2(a0)
    lw  a7, 4*3(a0)
    mul t5, t0, t3
    mul t6, t1, t2
    add t5, t5, t6
    add t5, t5, a7
    sw  t5, 4*3(a0)
    // loop control
    addi a0, a0, 4*4
    addi a1, a1, 2*4
    addi a2, a2, 2*4
    addi a3, a3, 2*2
    addi a4, a4, 8*1
    addi a6, a6, -1
    bne a6, zero, poly_basemul_acc_cache_init_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret
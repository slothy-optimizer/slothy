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

.macro plant_mul_const_inplace_x2 q32, zeta, a_0, a_1
  mul \a_0, \a_0, \zeta
  mul \a_1, \a_1, \zeta
  srai \a_0, \a_0, 32
  srai \a_1, \a_1, 32
  addi \a_0, \a_0, 256
  addi \a_1, \a_1, 256
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
.endm

.macro plant_mul_const_inplace_x4 q32,  \
      zeta_0, zeta_1, zeta_2, zeta_3,   \
      a_0, a_1, a_2, a_3
  mul \a_0, \a_0, \zeta_0
  mul \a_1, \a_1, \zeta_1
  mul \a_2, \a_2, \zeta_2
  mul \a_3, \a_3, \zeta_3
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

.macro plant_mul_const_inplace_x8 \
        q32, zeta, \
        a_0, a_1, a_2, a_3, \
        a_4, a_5, a_6, a_7
  mul \a_0, \a_0, \zeta
  mul \a_1, \a_1, \zeta
  mul \a_2, \a_2, \zeta
  mul \a_3, \a_3, \zeta
  srai \a_0, \a_0, 32
  srai \a_1, \a_1, 32
  addi \a_0, \a_0, 256
  addi \a_1, \a_1, 256
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
  srai \a_2, \a_2, 32
  srai \a_3, \a_3, 32
  mul \a_4, \a_4, \zeta
  mul \a_5, \a_5, \zeta
  addi \a_2, \a_2, 256
  addi \a_3, \a_3, 256
  mulh \a_2, \a_2, \q32
  mulh \a_3, \a_3, \q32
  srai \a_4, \a_4, 32
  srai \a_5, \a_5, 32
  mul \a_6, \a_6, \zeta
  mul \a_7, \a_7, \zeta
  addi \a_4, \a_4, 256
  addi \a_5, \a_5, 256
  mulh \a_4, \a_4, \q32
  mulh \a_5, \a_5, \q32
  srai \a_6, \a_6, 32
  addi \a_6, \a_6, 256
  mulh \a_6, \a_6, \q32
  srai \a_7, \a_7, 32
  addi \a_7, \a_7, 256
  mulh \a_7, \a_7, \q32
.endm

// r <- a*b*(-2^{-64}) mod+- q
// q32: q<<32; bqinv: b*qinv
.macro plant_mul_const q32, bqinv, a, r
    mul  \r, \a, \bqinv
    srai \r, \r, 32
    addi \r, \r, 256
    mulh \r, \r, \q32
.endm

.macro plant_mul_const_x2 q32, zeta_0, zeta_1, a_0, a_1, r_0, r_1
  mul \r_0, \a_0, \zeta_0
  mul \r_1, \a_1, \zeta_1
  srai \r_0, \r_0, 32
  srai \r_1, \r_1, 32
  addi \r_0, \r_0, 256
  addi \r_1, \r_1, 256
  mulh \r_0, \r_0, \q32
  mulh \r_1, \r_1, \q32
.endm

.macro plant_mul_const_x4   \
        q32, zeta_0, zeta_1,\
        zeta_2, zeta_3,     \
        a_0, a_1, a_2, a_3, \
        r_0, r_1, r_2, r_3
  mul \r_0, \a_0, \zeta_0
  mul \r_1, \a_1, \zeta_1
  mul \r_2, \a_2, \zeta_2
  mul \r_3, \a_3, \zeta_3
  srai \r_0, \r_0, 32
  srai \r_1, \r_1, 32
  srai \r_2, \r_2, 32
  srai \r_3, \r_3, 32
  addi \r_0, \r_0, 256
  addi \r_1, \r_1, 256
  addi \r_2, \r_2, 256
  addi \r_3, \r_3, 256
  mulh \r_0, \r_0, \q32
  mulh \r_1, \r_1, \q32
  mulh \r_2, \r_2, \q32
  mulh \r_3, \r_3, \q32
.endm

// each layer increases coefficients by 0.5q; In ct_bfu, twiddle and tmp can be reused because each twiddle is only used once. The gs_bfu cannot.
.macro ct_bfu coeff0, coeff1, twiddle, q, tmp
  plant_mul_const \q, \twiddle, \coeff1, \tmp
  sub \coeff1, \coeff0, \tmp
  add \coeff0, \coeff0, \tmp
.endm

.macro ct_bfu_x2 \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        zeta_0, zeta_1, \
        q32, \
        t_0, t_1
  mul  \t_0, \a_0_1, \zeta_0
  mul  \t_1, \a_1_1, \zeta_1
  srai \t_0, \t_0, 32
  srai \t_1, \t_1, 32
  addi \t_0, \t_0, 256
  addi \t_1, \t_1, 256
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  sub  \a_0_1, \a_0_0, \t_0
  sub  \a_1_1, \a_1_0, \t_1
  add  \a_0_0, \a_0_0, \t_0
  add  \a_1_0, \a_1_0, \t_1
.endm

.macro ct_bfu_x8 \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        zeta_2, zeta_3, \
        zeta_4, zeta_5, \
        zeta_6, zeta_7, \
        q32, \
        t_0, t_1, t_2, t_3
  mul  \t_0, \a_0_1, \zeta_0
  mul  \t_1, \a_1_1, \zeta_1
  mul  \t_2, \a_2_1, \zeta_2
  mul  \t_3, \a_3_1, \zeta_3
  srai \t_0, \t_0, 32
  srai \t_1, \t_1, 32
  addi \t_0, \t_0, 256
  addi \t_1, \t_1, 256
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 256
  addi \t_3, \t_3, 256
  mulh \t_2, \t_2, \q32
  mulh \t_3, \t_3, \q32
  sub  \a_0_1, \a_0_0, \t_0
  sub  \a_1_1, \a_1_0, \t_1
  add  \a_0_0, \a_0_0, \t_0
  add  \a_1_0, \a_1_0, \t_1
  mul  \t_0, \a_4_1, \zeta_4
  mul  \t_1, \a_5_1, \zeta_5
  sub  \a_2_1, \a_2_0, \t_2
  sub  \a_3_1, \a_3_0, \t_3
  add  \a_2_0, \a_2_0, \t_2
  add  \a_3_0, \a_3_0, \t_3
  mul  \t_2, \a_6_1, \zeta_6
  mul  \t_3, \a_7_1, \zeta_7
  srai \t_0, \t_0, 32
  srai \t_1, \t_1, 32
  addi \t_0, \t_0, 256
  addi \t_1, \t_1, 256
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 256
  addi \t_3, \t_3, 256
  mulh \t_2, \t_2, \q32
  mulh \t_3, \t_3, \q32
  sub  \a_4_1, \a_4_0, \t_0
  sub  \a_5_1, \a_5_0, \t_1
  add  \a_4_0, \a_4_0, \t_0
  add  \a_5_0, \a_5_0, \t_1
  sub  \a_6_1, \a_6_0, \t_2
  sub  \a_7_1, \a_7_0, \t_3
  add  \a_6_0, \a_6_0, \t_2
  add  \a_7_0, \a_7_0, \t_3
.endm

.macro ct_bfu_x8_loadzetas \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        zeta_2, zeta_3, \
        zeta_4, zeta_5, \
        zeta_6, zeta_7, \
        q32, \
        t_0, t_1, t_2, t_3
  ld   \t_0, \zeta_0(a1)
  ld   \t_1, \zeta_1(a1)
  ld   \t_2, \zeta_2(a1)
  ld   \t_3, \zeta_3(a1)
  mul  \t_0, \a_0_1, \t_0
  mul  \t_1, \a_1_1, \t_1
  mul  \t_2, \a_2_1, \t_2
  mul  \t_3, \a_3_1, \t_3
  srai \t_0, \t_0, 32
  srai \t_1, \t_1, 32
  addi \t_0, \t_0, 256
  addi \t_1, \t_1, 256
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 256
  addi \t_3, \t_3, 256
  mulh \t_2, \t_2, \q32
  mulh \t_3, \t_3, \q32
  sub  \a_0_1, \a_0_0, \t_0
  sub  \a_1_1, \a_1_0, \t_1
  add  \a_0_0, \a_0_0, \t_0
  ld   \t_0, \zeta_4(a1)
  add  \a_1_0, \a_1_0, \t_1
  ld   \t_1, \zeta_5(a1)
  mul  \t_0, \a_4_1, \t_0
  mul  \t_1, \a_5_1, \t_1
  sub  \a_2_1, \a_2_0, \t_2
  sub  \a_3_1, \a_3_0, \t_3
  add  \a_2_0, \a_2_0, \t_2
  ld   \t_2, \zeta_6(a1)
  add  \a_3_0, \a_3_0, \t_3
  ld   \t_3, \zeta_7(a1)
  mul  \t_2, \a_6_1, \t_2
  mul  \t_3, \a_7_1, \t_3
  srai \t_0, \t_0, 32
  srai \t_1, \t_1, 32
  addi \t_0, \t_0, 256
  addi \t_1, \t_1, 256
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 256
  addi \t_3, \t_3, 256
  mulh \t_2, \t_2, \q32
  mulh \t_3, \t_3, \q32
  sub  \a_4_1, \a_4_0, \t_0
  sub  \a_5_1, \a_5_0, \t_1
  add  \a_4_0, \a_4_0, \t_0
  add  \a_5_0, \a_5_0, \t_1
  sub  \a_6_1, \a_6_0, \t_2
  sub  \a_7_1, \a_7_0, \t_3
  add  \a_6_0, \a_6_0, \t_2
  add  \a_7_0, \a_7_0, \t_3
.endm

.macro gs_bfu coeff0, coeff1, twiddle, q, tmp
  sub \tmp, \coeff0, \coeff1
  add \coeff0, \coeff0, \coeff1
  plant_mul_const \q, \twiddle, \tmp, \coeff1
.endm

.macro gs_bfu_x2 a_0_0, a_0_1, a_1_0, a_1_1, \
        zeta_0, zeta_1, q32, t_0, t_1
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mul \a_0_1, \t_0, \zeta_0
  mul \a_1_1, \t_1, \zeta_1
  srai \a_0_1, \a_0_1, 32
  srai \a_1_1, \a_1_1, 32
  addi \a_0_1, \a_0_1, 256
  addi \a_1_1, \a_1_1, 256
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
.endm

.macro gs_bfu_x8 \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        zeta_2, zeta_3, \
        zeta_4, zeta_5, \
        zeta_6, zeta_7, \
        q32, t_0, t_1, t_2, t_3
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mul \a_0_1, \t_0, \zeta_0
  mul \a_1_1, \t_1, \zeta_1
  sub \t_2, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mul \a_2_1, \t_2, \zeta_2
  mul \a_3_1, \t_3, \zeta_3
  srai \a_0_1, \a_0_1, 32
  srai \a_1_1, \a_1_1, 32
  addi \a_0_1, \a_0_1, 256
  addi \a_1_1, \a_1_1, 256
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 256
  addi \a_3_1, \a_3_1, 256
  mulh \a_2_1, \a_2_1, \q32
  mulh \a_3_1, \a_3_1, \q32
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mul \a_4_1, \t_0, \zeta_4
  mul \a_5_1, \t_1, \zeta_5
  sub \t_2, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mul \a_6_1, \t_2, \zeta_6
  mul \a_7_1, \t_3, \zeta_7
  srai \a_4_1, \a_4_1, 32
  srai \a_5_1, \a_5_1, 32
  addi \a_4_1, \a_4_1, 256
  addi \a_5_1, \a_5_1, 256
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 256
  addi \a_7_1, \a_7_1, 256
  mulh \a_6_1, \a_6_1, \q32
  mulh \a_7_1, \a_7_1, \q32
.endm

.macro gs_bfu_x8_load_4zetas \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        zeta_2, zeta_3, \
        q32, t_0, t_1, t_2, t_3
  ld  \t_2, \zeta_0(a1)
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mul \a_0_1, \t_0, \t_2
  mul \a_1_1, \t_1, \t_2
  sub \t_0, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  ld  \t_2, \zeta_1(a1)
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mul \a_2_1, \t_0, \t_2
  mul \a_3_1, \t_3, \t_2
  srai \a_0_1, \a_0_1, 32
  srai \a_1_1, \a_1_1, 32
  addi \a_0_1, \a_0_1, 256
  addi \a_1_1, \a_1_1, 256
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 256
  addi \a_3_1, \a_3_1, 256
  mulh \a_2_1, \a_2_1, \q32
  mulh \a_3_1, \a_3_1, \q32
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  ld  \t_2, \zeta_2(a1)
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mul \a_4_1, \t_0, \t_2
  mul \a_5_1, \t_1, \t_2
  sub \t_0, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  ld  \t_2, \zeta_3(a1)
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mul \a_6_1, \t_0, \t_2
  mul \a_7_1, \t_3, \t_2
  srai \a_4_1, \a_4_1, 32
  srai \a_5_1, \a_5_1, 32
  addi \a_4_1, \a_4_1, 256
  addi \a_5_1, \a_5_1, 256
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 256
  addi \a_7_1, \a_7_1, 256
  mulh \a_6_1, \a_6_1, \q32
  mulh \a_7_1, \a_7_1, \q32
.endm

.macro gs_bfu_x8_load_2zetas \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        q32, t_0, t_1, t_2, t_3
  ld  \t_2, \zeta_0(a1)
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mul \a_0_1, \t_0, \t_2
  mul \a_1_1, \t_1, \t_2
  sub \t_0, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mul \a_2_1, \t_0, \t_2
  mul \a_3_1, \t_3, \t_2
  srai \a_0_1, \a_0_1, 32
  srai \a_1_1, \a_1_1, 32
  addi \a_0_1, \a_0_1, 256
  addi \a_1_1, \a_1_1, 256
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 256
  addi \a_3_1, \a_3_1, 256
  mulh \a_2_1, \a_2_1, \q32
  mulh \a_3_1, \a_3_1, \q32
  ld  \t_2, \zeta_1(a1)
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mul \a_4_1, \t_0, \t_2
  mul \a_5_1, \t_1, \t_2
  sub \t_0, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mul \a_6_1, \t_0, \t_2
  mul \a_7_1, \t_3, \t_2
  srai \a_4_1, \a_4_1, 32
  srai \a_5_1, \a_5_1, 32
  addi \a_4_1, \a_4_1, 256
  addi \a_5_1, \a_5_1, 256
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 256
  addi \a_7_1, \a_7_1, 256
  mulh \a_6_1, \a_6_1, \q32
  mulh \a_7_1, \a_7_1, \q32
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

// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 8 twiddle factors: can be preloaded; t0-t6, tp; ra: tmp zeta.
.global intt_dilithium_8l_plant_rv64im_dual
.align 2
intt_dilithium_8l_plant_rv64im_dual:
  addi sp, sp, -8*16
  save_regs
  li a6, q32
  ### LAYER 8+7+6+5
  addi gp, x0, 16
  sd gp, 8*15(sp)
  intt_rv64im_loop1:
    load_coeffs a0, 1, 4
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    // layer 8
    ld tp, 7*8(a1)
    gs_bfu_x8 \
      s0,  s1, s2,  s3, \
      s4,  s5, s6,  s7, \
      s8,  s9, s10, s11,\
      a2,  a3, a4,  a5, \
      t0, t1, t2, t3,   \
      t4, t5, t6, tp,   \
      a6, a7, gp, a7, ra
    // layer 7
    gs_bfu_x8_load_4zetas \
      s0, s2, s1, s3,   \
      s4, s6, s5, s7,   \
      s8, s10, s9, s11, \
      a2, a4, a3, a5,   \
      8*8, 9*8, 10*8, 11*8, \
      a6, a7, gp, tp, ra
    // layer 6
    gs_bfu_x8_load_2zetas \
      s0,  s4, s1,  s5, \
      s2,  s6, s3,  s7, \
      s8,  a2, s9,  a3, \
      s10, a4, s11, a5, \
      12*8, 13*8,  \
      a6, a7, gp, tp, ra
    // layer 5
    ld ra, 14*8(a1)
    gs_bfu_x8 \
      s0, s8, s1, s9,   \
      s2, s10, s3, s11, \
      s4, a2, s5, a3,   \
      s6, a4, s7, a5,   \
      ra, ra, ra, ra,   \
      ra, ra, ra, ra,   \
      a6, a7, gp, a7, tp
    store_coeffs a0, 1, 4
    addi a0, a0, 16*4
    addi a1, a1, 8*15
  ld gp, 8*15(sp) // @slothy:reads=[sp-ctr]
  addi gp, gp, -1
  sd gp, 8*15(sp) // @slothy:writes=[sp-ctr]
  bne gp, zero, intt_rv64im_loop1
  addi a0, a0, -256*4
  ### LAYER 4+3+2+1
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  addi a0, a0, 16*4
  addi gp, x0, 15
  sd gp, 8*15(sp)
  intt_rv64im_loop2:
    addi a0, a0, -4
    load_coeffs a0, 16, 4
    // layer 4
    ld tp, 7*8(a1)
    gs_bfu_x8 \
      s0,  s1, s2,  s3, \
      s4,  s5, s6,  s7, \
      s8,  s9, s10, s11,\
      a2,  a3, a4,  a5, \
      t0, t1, t2, t3,   \
      t4, t5, t6, tp,   \
      a6, a7, gp, a7, ra
    // layer 3
    gs_bfu_x8_load_4zetas \
      s0, s2, s1, s3,   \
      s4, s6, s5, s7,   \
      s8, s10, s9, s11, \
      a2, a4, a3, a5,   \
      8*8, 9*8, 10*8, 11*8, \
      a6, a7, gp, tp, ra
    // layer 2
    gs_bfu_x8_load_2zetas \
      s0,  s4, s1,  s5, \
      s2,  s6, s3,  s7, \
      s8,  a2, s9,  a3, \
      s10, a4, s11, a5, \
      12*8, 13*8,  \
      a6, a7, gp, tp, ra
    // layer 1
    ld ra, 14*8(a1)
    gs_bfu_x8 \
      s0, s8, s1, s9,   \
      s2, s10, s3, s11, \
      s4, a2, s5, a3,   \
      s6, a4, s7, a5,   \
      ra, ra, ra, ra,   \
      ra, ra, ra, ra,   \
      a6, a7, gp, a7, tp
    ld ra, 15*8(a1)
    plant_mul_const_inplace_x8  \
      a6, ra, \
      s0, s1, s2, s3, s4, s5, s6, s7
    store_coeffs a0, 16, 4
  ld gp, 8*15(sp) // @slothy:reads=[sp-ctr]
  addi gp, gp, -1
  sd gp, 8*15(sp) // @slothy:writes=[sp-ctr]
  bge gp, zero, intt_rv64im_loop2
  restore_regs
  addi sp, sp, 8*16
  ret
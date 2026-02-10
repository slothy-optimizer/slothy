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

// Plantard based NTT implementation with l=16

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

// a <- a*b*(-2^{-32}) mod+- q
// q48: q<<48; bqinv: b*qinv
.macro plant_mul_const_inplace q48, zeta, a
  mulw \a, \a, \zeta
  srai \a, \a, 16
  addi \a, \a, 8
  mulh \a, \a, \q48
.endm

.macro plant_mul_const_inplace_x2 q48, zeta, a_0, a_1
  mulw \a_0, \a_0, \zeta
  mulw \a_1, \a_1, \zeta
  srai \a_0, \a_0, 16
  srai \a_1, \a_1, 16
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  mulh \a_0, \a_0, \q48
  mulh \a_1, \a_1, \q48
.endm

.macro plant_mul_const_inplace_x4 q48,  \
      zeta_0, zeta_1, zeta_2, zeta_3,   \
      a_0, a_1, a_2, a_3
  mulw \a_0, \a_0, \zeta_0
  mulw \a_1, \a_1, \zeta_1
  mulw \a_2, \a_2, \zeta_2
  mulw \a_3, \a_3, \zeta_3
  srai \a_0, \a_0, 16
  srai \a_1, \a_1, 16
  srai \a_2, \a_2, 16
  srai \a_3, \a_3, 16
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_0, \a_0, \q48
  mulh \a_1, \a_1, \q48
  mulh \a_2, \a_2, \q48
  mulh \a_3, \a_3, \q48
.endm

// r <- a*b*(-2^{-32}) mod+- q
// q48: q<<48; zeta: b*qinv
.macro plant_mul_const q48, zeta, a, r
  mulw \r, \a, \zeta
  srai \r, \r, 16
  addi \r, \r, 8
  mulh \r, \r, \q48
.endm

.macro plant_mul_const_x2 q48, zeta_0, zeta_1, a_0, a_1, r_0, r_1
  mulw \r_0, \a_0, \zeta_0
  mulw \r_1, \a_1, \zeta_1
  srai \r_0, \r_0, 16
  srai \r_1, \r_1, 16
  addi \r_0, \r_0, 8
  addi \r_1, \r_1, 8
  mulh \r_0, \r_0, \q48
  mulh \r_1, \r_1, \q48
.endm

.macro plant_mul_const_x4   \
        q48, zeta_0, zeta_1,\
        zeta_2, zeta_3,     \
        a_0, a_1, a_2, a_3, \
        r_0, r_1, r_2, r_3
  mulw \r_0, \a_0, \zeta_0
  mulw \r_1, \a_1, \zeta_1
  mulw \r_2, \a_2, \zeta_2
  mulw \r_3, \a_3, \zeta_3
  srai \r_0, \r_0, 16
  srai \r_1, \r_1, 16
  srai \r_2, \r_2, 16
  srai \r_3, \r_3, 16
  addi \r_0, \r_0, 8
  addi \r_1, \r_1, 8
  addi \r_2, \r_2, 8
  addi \r_3, \r_3, 8
  mulh \r_0, \r_0, \q48
  mulh \r_1, \r_1, \q48
  mulh \r_2, \r_2, \q48
  mulh \r_3, \r_3, \q48
.endm

// each layer increases coefficients by 0.5q; In ct_bfu, zeta and tmp can be reused because each zeta is only used once. The gs_bfu cannot.
// .macro ct_bfu a_0, a_1, zeta, q48, tmp
//   plant_mul_const \q48, \zeta, \a_1, \tmp
//   sub \a_1, \a_0, \tmp
//   add \a_0, \a_0, \tmp
// .endm
.macro ct_bfu a_0, a_1, zeta, q48, tmp
  mulw \tmp, \a_1, \zeta
  srai \tmp, \tmp, 16
  addi \tmp, \tmp, 8
  mulh \tmp, \tmp, \q48
  sub \a_1, \a_0, \tmp
  add \a_0, \a_0, \tmp
.endm

.macro ct_bfu_x2 \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        zeta_0, zeta_1, \
        q48, \
        t_0, t_1
  mulw  \t_0, \a_0_1, \zeta_0
  mulw  \t_1, \a_1_1, \zeta_1
  srai \t_0, \t_0, 16
  srai \t_1, \t_1, 16
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q48
  mulh \t_1, \t_1, \q48
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
        q48, \
        t_0, t_1, t_2, t_3
  mulw \t_0, \a_0_1, \zeta_0
  mulw \t_1, \a_1_1, \zeta_1
  mulw \t_2, \a_2_1, \zeta_2
  mulw \t_3, \a_3_1, \zeta_3
  srai \t_0, \t_0, 16
  srai \t_1, \t_1, 16
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q48
  mulh \t_1, \t_1, \q48
  srai \t_2, \t_2, 16
  srai \t_3, \t_3, 16
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
  mulh \t_2, \t_2, \q48
  mulh \t_3, \t_3, \q48
  sub  \a_0_1, \a_0_0, \t_0
  sub  \a_1_1, \a_1_0, \t_1
  add  \a_0_0, \a_0_0, \t_0
  add  \a_1_0, \a_1_0, \t_1
  mulw \t_0, \a_4_1, \zeta_4
  mulw \t_1, \a_5_1, \zeta_5
  sub  \a_2_1, \a_2_0, \t_2
  sub  \a_3_1, \a_3_0, \t_3
  add  \a_2_0, \a_2_0, \t_2
  add  \a_3_0, \a_3_0, \t_3
  mulw \t_2, \a_6_1, \zeta_6
  mulw \t_3, \a_7_1, \zeta_7
  srai \t_0, \t_0, 16
  srai \t_1, \t_1, 16
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q48
  mulh \t_1, \t_1, \q48
  srai \t_2, \t_2, 16
  srai \t_3, \t_3, 16
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
  mulh \t_2, \t_2, \q48
  mulh \t_3, \t_3, \q48
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
        q48, \
        t_0, t_1, t_2, t_3
  lw   \t_0, \zeta_0(a1)
  lw   \t_1, \zeta_1(a1)
  lw   \t_2, \zeta_2(a1)
  lw   \t_3, \zeta_3(a1)
  mulw \t_0, \a_0_1, \t_0
  mulw \t_1, \a_1_1, \t_1
  mulw \t_2, \a_2_1, \t_2
  mulw \t_3, \a_3_1, \t_3
  srai \t_0, \t_0, 16
  srai \t_1, \t_1, 16
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q48
  mulh \t_1, \t_1, \q48
  srai \t_2, \t_2, 16
  srai \t_3, \t_3, 16
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
  mulh \t_2, \t_2, \q48
  mulh \t_3, \t_3, \q48
  sub  \a_0_1, \a_0_0, \t_0
  sub  \a_1_1, \a_1_0, \t_1
  add  \a_0_0, \a_0_0, \t_0
  lw   \t_0, \zeta_4(a1)
  add  \a_1_0, \a_1_0, \t_1
  lw   \t_1, \zeta_5(a1)
  mulw \t_0, \a_4_1, \t_0
  mulw \t_1, \a_5_1, \t_1
  sub  \a_2_1, \a_2_0, \t_2
  sub  \a_3_1, \a_3_0, \t_3
  add  \a_2_0, \a_2_0, \t_2
  lw   \t_2, \zeta_6(a1)
  add  \a_3_0, \a_3_0, \t_3
  lw   \t_3, \zeta_7(a1)
  mulw \t_2, \a_6_1, \t_2
  mulw \t_3, \a_7_1, \t_3
  srai \t_0, \t_0, 16
  srai \t_1, \t_1, 16
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q48
  mulh \t_1, \t_1, \q48
  srai \t_2, \t_2, 16
  srai \t_3, \t_3, 16
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
  mulh \t_2, \t_2, \q48
  mulh \t_3, \t_3, \q48
  sub  \a_4_1, \a_4_0, \t_0
  sub  \a_5_1, \a_5_0, \t_1
  add  \a_4_0, \a_4_0, \t_0
  add  \a_5_0, \a_5_0, \t_1
  sub  \a_6_1, \a_6_0, \t_2
  sub  \a_7_1, \a_7_0, \t_3
  add  \a_6_0, \a_6_0, \t_2
  add  \a_7_0, \a_7_0, \t_3
.endm

.macro gs_bfu a_0, a_1, zeta, q48, tmp
  sub \tmp, \a_0, \a_1
  add \a_0, \a_0, \a_1
  mulw \a_1, \tmp, \zeta
  srai \a_1, \a_1, 16
  addi \a_1, \a_1, 8
  mulh \a_1, \a_1, \q48
.endm

.macro gs_bfu_x2 a_0_0, a_0_1, a_1_0, a_1_1, \
        zeta_0, zeta_1, q48, t_0, t_1
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mulw \a_0_1, \t_0, \zeta_0
  mulw \a_1_1, \t_1, \zeta_1
  srai \a_0_1, \a_0_1, 16
  srai \a_1_1, \a_1_1, 16
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q48
  mulh \a_1_1, \a_1_1, \q48
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
        q48, t_0, t_1, t_2, t_3
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mulw \a_0_1, \t_0, \zeta_0
  mulw \a_1_1, \t_1, \zeta_1
  sub \t_2, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mulw \a_2_1, \t_2, \zeta_2
  mulw \a_3_1, \t_3, \zeta_3
  srai \a_0_1, \a_0_1, 16
  srai \a_1_1, \a_1_1, 16
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q48
  mulh \a_1_1, \a_1_1, \q48
  srai \a_2_1, \a_2_1, 16
  srai \a_3_1, \a_3_1, 16
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
  mulh \a_2_1, \a_2_1, \q48
  mulh \a_3_1, \a_3_1, \q48
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mulw \a_4_1, \t_0, \zeta_4
  mulw \a_5_1, \t_1, \zeta_5
  sub \t_2, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mulw \a_6_1, \t_2, \zeta_6
  mulw \a_7_1, \t_3, \zeta_7
  srai \a_4_1, \a_4_1, 16
  srai \a_5_1, \a_5_1, 16
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q48
  mulh \a_5_1, \a_5_1, \q48
  srai \a_6_1, \a_6_1, 16
  srai \a_7_1, \a_7_1, 16
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
  mulh \a_6_1, \a_6_1, \q48
  mulh \a_7_1, \a_7_1, \q48
.endm

.macro gs_bfu_x8_load_4zetas \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        zeta_2, zeta_3, \
        q48, t_0, t_1, t_2, t_3
  lw  \t_2, \zeta_0(a1)
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mulw \a_0_1, \t_0, \t_2
  mulw \a_1_1, \t_1, \t_2
  sub \t_0, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  lw  \t_2, \zeta_1(a1)
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mulw \a_2_1, \t_0, \t_2
  mulw \a_3_1, \t_3, \t_2
  srai \a_0_1, \a_0_1, 16
  srai \a_1_1, \a_1_1, 16
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q48
  mulh \a_1_1, \a_1_1, \q48
  srai \a_2_1, \a_2_1, 16
  srai \a_3_1, \a_3_1, 16
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
  mulh \a_2_1, \a_2_1, \q48
  mulh \a_3_1, \a_3_1, \q48
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  lw  \t_2, \zeta_2(a1)
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mulw \a_4_1, \t_0, \t_2
  mulw \a_5_1, \t_1, \t_2
  sub \t_0, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  lw  \t_2, \zeta_3(a1)
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mulw \a_6_1, \t_0, \t_2
  mulw \a_7_1, \t_3, \t_2
  srai \a_4_1, \a_4_1, 16
  srai \a_5_1, \a_5_1, 16
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q48
  mulh \a_5_1, \a_5_1, \q48
  srai \a_6_1, \a_6_1, 16
  srai \a_7_1, \a_7_1, 16
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
  mulh \a_6_1, \a_6_1, \q48
  mulh \a_7_1, \a_7_1, \q48
.endm

.macro gs_bfu_x8_load_2zetas \
        a_0_0, a_0_1, a_1_0, a_1_1, \
        a_2_0, a_2_1, a_3_0, a_3_1, \
        a_4_0, a_4_1, a_5_0, a_5_1, \
        a_6_0, a_6_1, a_7_0, a_7_1, \
        zeta_0, zeta_1, \
        q48, t_0, t_1, t_2, t_3
  lw  \t_2, \zeta_0(a1)
  sub \t_0, \a_0_0, \a_0_1
  sub \t_1, \a_1_0, \a_1_1
  add \a_0_0, \a_0_0, \a_0_1
  add \a_1_0, \a_1_0, \a_1_1
  mulw \a_0_1, \t_0, \t_2
  mulw \a_1_1, \t_1, \t_2
  sub \t_0, \a_2_0, \a_2_1
  sub \t_3, \a_3_0, \a_3_1
  add \a_2_0, \a_2_0, \a_2_1
  add \a_3_0, \a_3_0, \a_3_1
  mulw \a_2_1, \t_0, \t_2
  mulw \a_3_1, \t_3, \t_2
  srai \a_0_1, \a_0_1, 16
  srai \a_1_1, \a_1_1, 16
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q48
  mulh \a_1_1, \a_1_1, \q48
  srai \a_2_1, \a_2_1, 16
  srai \a_3_1, \a_3_1, 16
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
  mulh \a_2_1, \a_2_1, \q48
  mulh \a_3_1, \a_3_1, \q48
  lw  \t_2, \zeta_1(a1)
  sub \t_0, \a_4_0, \a_4_1
  sub \t_1, \a_5_0, \a_5_1
  add \a_4_0, \a_4_0, \a_4_1
  add \a_5_0, \a_5_0, \a_5_1
  mulw \a_4_1, \t_0, \t_2
  mulw \a_5_1, \t_1, \t_2
  sub \t_0, \a_6_0, \a_6_1
  sub \t_3, \a_7_0, \a_7_1
  add \a_6_0, \a_6_0, \a_6_1
  add \a_7_0, \a_7_0, \a_7_1
  mulw \a_6_1, \t_0, \t_2
  mulw \a_7_1, \t_3, \t_2
  srai \a_4_1, \a_4_1, 16
  srai \a_5_1, \a_5_1, 16
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q48
  mulh \a_5_1, \a_5_1, \q48
  srai \a_6_1, \a_6_1, 16
  srai \a_7_1, \a_7_1, 16
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
  mulh \a_6_1, \a_6_1, \q48
  mulh \a_7_1, \a_7_1, \q48
.endm

.macro plant_mul_const_inplace_x8 \
        q48, zeta, \
        a_0, a_1, a_2, a_3, \
        a_4, a_5, a_6, a_7
  mulw \a_0, \a_0, \zeta
  mulw \a_1, \a_1, \zeta
  mulw \a_2, \a_2, \zeta
  mulw \a_3, \a_3, \zeta
  srai \a_0, \a_0, 16
  srai \a_1, \a_1, 16
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  mulh \a_0, \a_0, \q48
  mulh \a_1, \a_1, \q48
  srai \a_2, \a_2, 16
  srai \a_3, \a_3, 16
  mulw \a_4, \a_4, \zeta
  mulw \a_5, \a_5, \zeta
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_2, \a_2, \q48
  mulh \a_3, \a_3, \q48
  srai \a_4, \a_4, 16
  srai \a_5, \a_5, 16
  mulw \a_6, \a_6, \zeta
  mulw \a_7, \a_7, \zeta
  addi \a_4, \a_4, 8
  addi \a_5, \a_5, 8
  mulh \a_4, \a_4, \q48
  mulh \a_5, \a_5, \q48
  srai \a_6, \a_6, 16
  addi \a_6, \a_6, 8
  mulh \a_6, \a_6, \q48
  srai \a_7, \a_7, 16
  addi \a_7, \a_7, 8
  mulh \a_7, \a_7, \q48
.endm

// in-place plantard reduction to a
// output \in (-0.5q, 0.5q); q48: q<<48
.macro plant_red q48, qinv, a
  mulw \a, \a, \qinv
  srai \a, \a, 16
  addi \a, \a, 8
  mulh \a, \a, \q48
.endm

.macro plant_red_x4 \
        q48, qinv,  \
        a_0, a_1, a_2, a_3
  mulw \a_0, \a_0, \qinv
  mulw \a_1, \a_1, \qinv
  mulw \a_2, \a_2, \qinv
  mulw \a_3, \a_3, \qinv
  srai \a_0, \a_0, 16
  srai \a_1, \a_1, 16
  srai \a_2, \a_2, 16
  srai \a_3, \a_3, 16
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_0, \a_0, \q48
  mulh \a_1, \a_1, \q48
  mulh \a_2, \a_2, \q48
  mulh \a_3, \a_3, \q48
.endm

.equ q, 3329
.equ q48, 0xd01000000000000     // q<<48
.equ qinv, 0x6ba8f301           // q^-1 mod+- 2^32
.equ plantconst, 0x13afb8       // (-2^{32} mod q)*qinv mod 2^32
.equ plantconst2, 0x97f44fac    // (2^{64} mod q)*qinv mod 2^32

// void poly_basemul_acc_cache_init_rv64im(int32_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, uint32_t *zetas)
// compute basemul, cache bzeta into b_cache, and accumulate the 32-bit results into r
// a0: r, a1: a, a2: b, a3: b_cache, a4: zetas
// a5: q<<48, a6: loop control
.global poly_basemul_acc_cache_init_rv64im_dual
.align 2
poly_basemul_acc_cache_init_rv64im_dual:
    addi sp, sp, -8*15
    save_regs
    li a5, q48
    li a6, 32
poly_basemul_acc_cache_init_rv64im_loop:
    // b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    // 4 zetas: a7, gp, tp, ra
    lw  a7, 4*0(a4)
    lw  tp, 4*1(a4)
    // a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    neg gp, a7
    neg ra, tp
    // available regs: s2, s4, s6, t2-t6
    // t2,t3,t4,t5 <- b[1,3,5,7]zeta
    plant_mul_const_x4    \
      a5, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    // s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a0)
    lw  s9, 4*1(a0)
    lw  s10,4*2(a0)
    lw  s11,4*3(a0)
    // a[1](b[1]zeta)
    mul s4, t1, t2
    // a[0]b[0]
    mul s2, t0, s0
    // a[0]b[1]
    mul s6, t0, s1
    // a[1]b[0]
    mul t6, t1, s0
    sh  t2, 2*0(a3)
    sh  t3, 2*1(a3)
    sh  t4, 2*2(a3)
    sh  t5, 2*3(a3)
    // r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    // r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    // t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    // s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    // store r[0,1]
    sw  s8, 4*0(a0)
    sw  s9, 4*1(a0)
    // available regs: s0, s1, s8, s9, a7, t6
    // a[3](b[3]zeta)
    mul s1, t1, t3
    // a[2]b[2]
    mul s0, t0, s2
    // a[2]b[3]
    mul s8, t0, s3
    // a[3]b[2]
    mul s9, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    // r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    // r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, s8
    add s11, s11, s9
    // store r[2,3]
    sw  s10, 4*2(a0)
    sw  s11, 4*3(a0)
    // r[4,5,6,7]
    lw  s8, 4*4(a0)
    lw  s9, 4*5(a0)
    lw  s10,4*6(a0)
    lw  s11,4*7(a0)
    // a[5](b[5]zeta)
    mul s1, tp, t4
    // a[4]b[4]
    mul s0, t2, s4
    // a[4]b[5]
    mul t0, t2, s5
    // a[5]b[4]
    mul t1, tp, s4
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    // r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    // r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    // store r[4,5]
    sw  s8, 4*4(a0)
    sw  s9, 4*5(a0)
    // a[6]b[6]
    mul s0, gp, s6
    // a[7](b[7]zeta)
    mul s1, ra, t5
    // a[6]b[7]
    mul t0, gp, s7
    // a[7]b[6]
    mul t1, ra, s6
    // r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    // r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    // store r[6,7]
    sw  s10,4*6(a0)
    sw  s11,4*7(a0)
    // loop control
    addi a0, a0, 4*8
    addi a1, a1, 2*8
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a4, a4, 4*2
    addi a6, a6, -1
    bne a6, zero, poly_basemul_acc_cache_init_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret
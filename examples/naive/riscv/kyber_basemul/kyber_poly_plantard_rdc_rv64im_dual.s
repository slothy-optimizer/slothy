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

// plantard reduction to a poly
.global poly_plantard_rdc_rv64im_dual
.align 2
poly_plantard_rdc_rv64im_dual:
  addi sp, sp, -8*1
  sd   s0, 0(sp)
  li t6, plantconst
  li t5, q48
  addi t4, x0, 16
  poly_plantard_rdc_rv64im_loop:
    lh a1,  2*0(a0)
    lh a2,  2*1(a0)
    lh a3,  2*2(a0)
    lh a4,  2*3(a0)
    lh t0,  2*4(a0)
    lh t1,  2*5(a0)
    lh t2,  2*6(a0)
    lh t3,  2*7(a0)
    plant_red_x4  \
      t5, t6,     \
      a1, a2, a3, a4
    lh a5,  2*8(a0)
    lh a6,  2*9(a0)
    lh a7, 2*10(a0)
    lh s0, 2*11(a0)
    sh a1,  2*0(a0)
    sh a2,  2*1(a0)
    sh a3,  2*2(a0)
    sh a4,  2*3(a0)
    plant_red_x4  \
      t5, t6,     \
      t0, t1, t2, t3
    lh a1,  2*12(a0)
    lh a2,  2*13(a0)
    lh a3,  2*14(a0)
    lh a4,  2*15(a0)
    sh t0,  2*4(a0)
    sh t1,  2*5(a0)
    sh t2,  2*6(a0)
    sh t3,  2*7(a0)
    plant_red_x4  \
      t5, t6,     \
      a5, a6, a7, s0
    sh a5,  2*8(a0)
    sh a6,  2*9(a0)
    sh a7,  2*10(a0)
    sh s0,  2*11(a0)
    plant_red_x4  \
      t5, t6,     \
      a1, a2, a3, a4
    sh a1,  2*12(a0)
    sh a2,  2*13(a0)
    sh a3,  2*14(a0)
    sh a4,  2*15(a0)
    addi a0, a0, 2*16
    addi t4, t4, -1
  bne t4, zero, poly_plantard_rdc_rv64im_loop
  ld   s0, 0(sp)
  addi sp, sp, 8*1
  ret
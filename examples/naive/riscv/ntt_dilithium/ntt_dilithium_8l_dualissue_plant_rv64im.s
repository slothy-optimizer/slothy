/// 
/// Code from https://github.com/Ji-Peng/PQRV/blob/2463d15ba6c49d05d45ff427b72646e038c860da/ntt/dilithium/ntt_8l_dualissue_plant_rv64im.S
/// 
/// The MIT license, the text of which is below, applies to PQRV in general.
/// We have reused public-domain code from the following repositories: https://github.com/pq-crystals/kyber and https://github.com/pq-crystals/dilithium.
/// 
/// Copyright (c) 2024 Jipeng Zhang (jp-zhang@outlook.com)
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

// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp, variable twiddle factors; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 9 twiddle factors: can be preloaded; t0-t6, tp, ra.
.global ntt_8l_dual_rv64im
.align 2
ntt_8l_dual_rv64im:
  addi sp, sp, -8*16
  save_regs
  li a6, q32          // q<<32
  addi a0, a0, 16*4   // poly[16]
  addi gp, x0, 15     // loop
  sd gp, 8*15(sp)
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  ////// LAYER 1+2+3+4
  ntt_8l_rv64im_loop1:
    addi a0, a0, -4
    load_coeffs a0, 16, 4
    // layer 1
    ct_bfu_x8 \
      s0, s8, s1, s9,   \
      s2, s10, s3, s11, \
      s4, a2, s5, a3,   \
      s6, a4, s7, a5,   \
      t0, t0, t0, t0,   \
      t0, t0, t0, t0,   \
      a6, a7, gp, tp, ra
    // layer 2
    ct_bfu_x8 \
      s0, s4, s1, s5,   \
      s2, s6, s3,s7,    \
      s8,  a2, s9, a3,  \
      s10, a4, s11, a5, \
      t1, t1, t1, t1,   \
      t2, t2, t2, t2,   \
      a6, a7, gp, tp, ra
    // layer 3
    ct_bfu_x8 \
      s0, s2, s1, s3,   \
      s4, s6, s5, s7,   \
      s8, s10, s9, s11, \
      a2, a4, a3, a5,   \
      t3, t3, t4, t4,   \
      t5, t5, t6, t6,   \
      a6, a7, gp, tp, ra
    // layer 4
    ct_bfu_x8_loadzetas \
      s0,  s1, s2,  s3, \
      s4,  s5, s6,  s7, \
      s8,  s9, s10, s11,\
      a2,  a3, a4,  a5, \
      7*8, 8*8, 9*8, 10*8, \
      11*8,12*8,13*8,14*8, \
      a6, a7, gp, tp, ra
    store_coeffs a0, 16, 4
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bge gp, zero, ntt_8l_rv64im_loop1
  addi a1, a1, 15*8
  ////// LAYER 5+6+7+8
  addi gp, x0, 16
  sd gp, 8*15(sp)
  ntt_8l_rv64im_loop2:
    load_coeffs a0, 1, 4
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    // layer 5
    ct_bfu_x8 \
      s0, s8, s1, s9,   \
      s2, s10, s3, s11, \
      s4, a2, s5, a3,   \
      s6, a4, s7, a5,   \
      t0, t0, t0, t0,   \
      t0, t0, t0, t0,   \
      a6, a7, gp, tp, ra
    // layer 6
    ct_bfu_x8 \
      s0, s4, s1, s5,   \
      s2, s6, s3,s7,    \
      s8,  a2, s9, a3,  \
      s10, a4, s11, a5, \
      t1, t1, t1, t1,   \
      t2, t2, t2, t2,   \
      a6, a7, gp, tp, ra
    // layer 7
    ct_bfu_x8 \
      s0, s2, s1, s3,   \
      s4, s6, s5, s7,   \
      s8, s10, s9, s11, \
      a2, a4, a3, a5,   \
      t3, t3, t4, t4,   \
      t5, t5, t6, t6,   \
      a6, a7, gp, tp, ra
    // layer 8
    ct_bfu_x8_loadzetas \
      s0,  s1, s2,  s3, \
      s4,  s5, s6,  s7, \
      s8,  s9, s10, s11,\
      a2,  a3, a4,  a5, \
      7*8, 8*8, 9*8, 10*8, \
      11*8,12*8,13*8,14*8, \
      a6, a7, gp, tp, ra
    store_coeffs a0, 1, 4
    addi a0, a0, 16*4
    addi a1, a1, 15*8
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bne gp, zero, ntt_8l_rv64im_loop2
  restore_regs
  addi sp, sp, 8*16
  ret

// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 8 twiddle factors: can be preloaded; t0-t6, tp; ra: tmp zeta.
.global intt_8l_dual_rv64im
.align 2
intt_8l_dual_rv64im:
  addi sp, sp, -8*16
  save_regs
  li a6, q32
  ////// LAYER 8+7+6+5
  addi gp, x0, 16
  sd gp, 8*15(sp)
  intt_8l_rv64im_loop1:
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
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bne gp, zero, intt_8l_rv64im_loop1
  addi a0, a0, -256*4
  ////// LAYER 4+3+2+1
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
  intt_8l_rv64im_loop2:
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
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bge gp, zero, intt_8l_rv64im_loop2
  restore_regs
  addi sp, sp, 8*16
  ret

// void poly_basemul_8l_init_dual_rv64im(int64_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_init_dual_rv64im
.align 2
poly_basemul_8l_init_dual_rv64im:
    addi sp, sp, -8*15
    save_regs
    // loop control
    li gp, 32*8*8
    add gp, gp, a0
poly_basemul_8l_init_rv64im_looper:
    lw t0,  0*4(a1) // a0
    lw t1,  1*4(a1) // a1
    lw s0,  0*4(a2) // b0
    lw s1,  1*4(a2) // b1
    lw t2,  2*4(a1) // a2
    lw t3,  3*4(a1) // a3
    lw s2,  2*4(a2) // b2
    lw s3,  3*4(a2) // b3
    mul s8, t0, s0
    mul s9, t1, s1
    lw t4,  4*4(a1) // a4
    lw t5,  5*4(a1) // a5
    mul s10,t2, s2
    mul s11,t3, s3
    lw s4,  4*4(a2) // b4
    lw s5,  5*4(a2) // b5
    lw t6,  6*4(a1) // a6
    lw tp,  7*4(a1) // a7
    lw s6,  6*4(a2) // b6
    lw s7,  7*4(a2) // b7
    mul a3, t4, s4
    mul a4, t5, s5
    sd s8,  0*8(a0)
    sd s9,  1*8(a0)
    mul a5, t6, s6
    mul a6, tp, s7
    sd s10, 2*8(a0)
    sd s11, 3*8(a0)
    sd a3,  4*8(a0)
    sd a4,  5*8(a0)
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    sd a5,  6*8(a0)
    sd a6,  7*8(a0)
    addi a0, a0, 8*8
    bne gp, a0, poly_basemul_8l_init_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_basemul_8l_acc_dual_rv64im(int64_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_acc_dual_rv64im
.align 2
poly_basemul_8l_acc_dual_rv64im:
    addi sp, sp, -8*15
    save_regs
    // loop control
    li  gp, 32*8*8
    add gp, gp, a0
poly_basemul_8l_acc_rv64im_looper:
    lw t0, 0*4(a1) // a0
    lw t1, 1*4(a1) // a1
    lw s0, 0*4(a2) // b0
    lw s1, 1*4(a2) // b1
    ld a3, 0*8(a0)
    ld a4, 1*8(a0)
    lw t2, 2*4(a1) // a2
    lw t3, 3*4(a1) // a3
    lw s2, 2*4(a2) // b2
    lw s3, 3*4(a2) // b3
    ld a5, 2*8(a0)
    ld a6, 3*8(a0)
    mul s8, t0, s0
    mul s9, t1, s1
    lw t4, 4*4(a1) // a4
    lw t5, 5*4(a1) // a5
    mul s10,t2, s2
    mul s11,t3, s3
    lw s4, 4*4(a2) // b4
    lw s5, 5*4(a2) // b5
    add s8, s8, a3
    add s9, s9, a4
    lw t6, 6*4(a1) // a6
    lw tp, 7*4(a1) // a7
    add s10,s10,a5
    add s11,s11,a6
    sd s8, 0*8(a0)
    sd s9, 1*8(a0)
    lw s6, 6*4(a2) // b6
    lw s7, 7*4(a2) // b7
    ld a3, 4*8(a0)
    ld a4, 5*8(a0)
    sd s10,2*8(a0)
    sd s11,3*8(a0)
    mul s8, t4, s4
    mul s9, t5, s5
    ld a5, 6*8(a0)
    ld a6, 7*8(a0)
    mul s10,t6, s6
    mul s11,tp, s7
    add s8, s8, a3
    add s9, s9, a4
    sd s8, 4*8(a0)
    sd s9, 5*8(a0)
    add s10,s10,a5
    add s11,s11,a6
    sd s10,6*8(a0)
    sd s11,7*8(a0)
    addi a0, a0, 8*8
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    bne gp, a0, poly_basemul_8l_acc_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_basemul_8l_acc_end_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256], int64_t r_double[256])
.globl poly_basemul_8l_acc_end_dual_rv64im
.align 2
poly_basemul_8l_acc_end_dual_rv64im:
    addi sp, sp, -8*16
    save_regs
    li a4, q32
    li a5, qinv
    // loop control
    li  gp, 32*8*4
    add gp, gp, a0
    sd  gp, 8*15(sp)
poly_basemul_8l_acc_end_rv64im_looper:
    lw t0, 0*4(a1) // a0
    lw t1, 1*4(a1) // a1
    lw s0, 0*4(a2) // b0
    lw s1, 1*4(a2) // b1
    ld a6, 0*8(a3)
    ld a7, 1*8(a3)
    lw t2, 2*4(a1) // a2
    lw t3, 3*4(a1) // a3
    lw s2, 2*4(a2) // b2
    lw s3, 3*4(a2) // b3
    mul s8, t0, s0
    mul s9, t1, s1
    ld gp, 2*8(a3)
    ld ra, 3*8(a3)
    lw t4, 4*4(a1) // a4
    lw t5, 5*4(a1) // a5
    mul s10,t2, s2
    mul s11,t3, s3
    lw s4, 4*4(a2) // b4
    lw s5, 5*4(a2) // b5
    add s8, s8, a6
    add s9, s9, a7
    lw t6, 6*4(a1) // a6
    lw tp, 7*4(a1) // a7
    add s10,s10,gp
    add s11,s11,ra
    lw s6, 6*4(a2) // b6
    lw s7, 7*4(a2) // b7
    plant_red_x4 a4, a5, s8, s9, s10, s11
    ld a6, 4*8(a3)
    ld a7, 5*8(a3)
    sw s8, 0*4(a0)
    sw s9, 1*4(a0)
    mul s8, t4, s4
    mul s9, t5, s5
    sw s10,2*4(a0)
    sw s11,3*4(a0)
    ld gp, 6*8(a3)
    ld ra, 7*8(a3)
    mul s10,t6, s6
    mul s11,tp, s7
    add s8, s8, a6
    add s9, s9, a7
    add s10,s10,gp
    add s11,s11,ra
    plant_red_x4 a4, a5, s8, s9, s10, s11
    ld  gp, 8*15(sp)
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    addi a3, a3, 8*8
    sw s8, 4*4(a0)
    sw s9, 5*4(a0)
    sw s10,6*4(a0)
    sw s11,7*4(a0)
    addi a0, a0, 4*8
    bne gp, a0, poly_basemul_8l_acc_end_rv64im_looper
    restore_regs
    addi sp, sp, 8*16
    ret

// void poly_basemul_8l_dual_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_dual_rv64im
.align 2
poly_basemul_8l_dual_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a4, q32
    li a5, qinv
    // loop control
    li gp, 32*8*4
    add gp, gp, a0
poly_basemul_8l_rv64im_looper:
    lw t0, 0*4(a1) // a0
    lw t1, 1*4(a1) // a1
    lw s0, 0*4(a2) // b0
    lw s1, 1*4(a2) // b1
    lw t2, 2*4(a1) // a2
    lw t3, 3*4(a1) // a3
    lw s2, 2*4(a2) // b2
    lw s3, 3*4(a2) // b3
    mul s8, s0, t0
    mul s9, s1, t1
    lw t4, 4*4(a1) // a4
    lw t5, 5*4(a1) // a5
    mul s10,s2, t2
    mul s11,s3, t3
    lw s4, 4*4(a2) // b4
    lw s5, 5*4(a2) // b5
    plant_red_x4 a4, a5, s8, s9, s10, s11
    lw t6, 6*4(a1) // a6
    lw tp, 7*4(a1) // a7
    lw s6, 6*4(a2) // b6
    lw s7, 7*4(a2) // b7
    mul s0, s4, t4
    mul s1, s5, t5
    sw s8, 0*4(a0)
    sw s9, 1*4(a0)
    mul s2, s6, t6
    mul s3, s7, tp
    sw s10,2*4(a0)
    sw s11,3*4(a0)
    plant_red_x4 a4, a5, s0, s1, s2, s3
    sw s0, 4*4(a0)
    sw s1, 5*4(a0)
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    sw s2, 6*4(a0)
    sw s3, 7*4(a0)
    addi a0, a0, 4*8
    bne gp, a0, poly_basemul_8l_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_reduce_dual_rv64im(int32_t in[256]);
.globl poly_reduce_dual_rv64im
.align 2
poly_reduce_dual_rv64im:
    li a1, 4194304  // 1<<22
    li a2, q
    addi a3, a0, 64*4*4
poly_reduce_rv64im_loop:
    lw a4, 0*4(a0)
    lw a5, 1*4(a0)
    lw a6, 2*4(a0)
    lw a7, 3*4(a0)
    add  t0, a4, a1
    add  t1, a5, a1
    add  t2, a6, a1
    add  t3, a7, a1
    srai t0, t0, 23
    srai t1, t1, 23
    srai t2, t2, 23
    srai t3, t3, 23
    mul  t0, t0, a2
    mul  t1, t1, a2
    mul  t2, t2, a2
    mul  t3, t3, a2
    sub  a4, a4, t0
    sub  a5, a5, t1
    sub  a6, a6, t2
    sub  a7, a7, t3
    sw a4, 0*4(a0)
    sw a5, 1*4(a0)
    sw a6, 2*4(a0)
    sw a7, 3*4(a0)
    addi a0, a0, 4*4
    bne a3, a0, poly_reduce_rv64im_loop
    ret

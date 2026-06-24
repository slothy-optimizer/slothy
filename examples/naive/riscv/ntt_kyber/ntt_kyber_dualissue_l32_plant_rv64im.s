# Plantard based NTT implementation with l=32

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

.macro plant_mul_const_inplace_x2 q32, zeta, a_0, a_1
  mul \a_0, \a_0, \zeta
  mul \a_1, \a_1, \zeta
  srai \a_0, \a_0, 32
  srai \a_1, \a_1, 32
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
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
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
  mulh \a_2, \a_2, \q32
  mulh \a_3, \a_3, \q32
.endm

// r <- a*b*(-2^{-64}) mod+- q
// q32: q<<32; bqinv: b*qinv
.macro plant_mul_const q32, bqinv, a, r
    mul  \r, \a, \bqinv
    srai \r, \r, 32
    addi \r, \r, 8
    mulh \r, \r, \q32
.endm

.macro plant_mul_const_x2 q32, zeta_0, zeta_1, a_0, a_1, r_0, r_1
  mul \r_0, \a_0, \zeta_0
  mul \r_1, \a_1, \zeta_1
  srai \r_0, \r_0, 32
  srai \r_1, \r_1, 32
  addi \r_0, \r_0, 8
  addi \r_1, \r_1, 8
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
  addi \r_0, \r_0, 8
  addi \r_1, \r_1, 8
  addi \r_2, \r_2, 8
  addi \r_3, \r_3, 8
  mulh \r_0, \r_0, \q32
  mulh \r_1, \r_1, \q32
  mulh \r_2, \r_2, \q32
  mulh \r_3, \r_3, \q32
.endm

// each layer increases coefficients by 0.5q; In ct_butterfly, twiddle and tmp can be reused because each twiddle is only used once. The gs_butterfly cannot.
.macro ct_butterfly coeff0, coeff1, twiddle, q, tmp
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
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
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
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
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
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
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
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
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
  addi \t_0, \t_0, 8
  addi \t_1, \t_1, 8
  mulh \t_0, \t_0, \q32
  mulh \t_1, \t_1, \q32
  srai \t_2, \t_2, 32
  srai \t_3, \t_3, 32
  addi \t_2, \t_2, 8
  addi \t_3, \t_3, 8
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

.macro gs_bfu a_0, a_1, zeta, q32, tmp
  sub \tmp, \a_0, \a_1
  add \a_0, \a_0, \a_1
  mul \a_1, \tmp, \zeta
  srai \a_1, \a_1, 32
  addi \a_1, \a_1, 8
  mulh \a_1, \a_1, \q32
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
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
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
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
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
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
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
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
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
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
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
  addi \a_0_1, \a_0_1, 8
  addi \a_1_1, \a_1_1, 8
  mulh \a_0_1, \a_0_1, \q32
  mulh \a_1_1, \a_1_1, \q32
  srai \a_2_1, \a_2_1, 32
  srai \a_3_1, \a_3_1, 32
  addi \a_2_1, \a_2_1, 8
  addi \a_3_1, \a_3_1, 8
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
  addi \a_4_1, \a_4_1, 8
  addi \a_5_1, \a_5_1, 8
  mulh \a_4_1, \a_4_1, \q32
  mulh \a_5_1, \a_5_1, \q32
  srai \a_6_1, \a_6_1, 32
  srai \a_7_1, \a_7_1, 32
  addi \a_6_1, \a_6_1, 8
  addi \a_7_1, \a_7_1, 8
  mulh \a_6_1, \a_6_1, \q32
  mulh \a_7_1, \a_7_1, \q32
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
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
  srai \a_2, \a_2, 32
  srai \a_3, \a_3, 32
  mul \a_4, \a_4, \zeta
  mul \a_5, \a_5, \zeta
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_2, \a_2, \q32
  mulh \a_3, \a_3, \q32
  srai \a_4, \a_4, 32
  srai \a_5, \a_5, 32
  mul \a_6, \a_6, \zeta
  mul \a_7, \a_7, \zeta
  addi \a_4, \a_4, 8
  addi \a_5, \a_5, 8
  mulh \a_4, \a_4, \q32
  mulh \a_5, \a_5, \q32
  srai \a_6, \a_6, 32
  addi \a_6, \a_6, 8
  mulh \a_6, \a_6, \q32
  srai \a_7, \a_7, 32
  addi \a_7, \a_7, 8
  mulh \a_7, \a_7, \q32
.endm

// in-place plantard reduction
// output \in (-0.5q, 0.5q); q32: q<<32
.macro plant_red q32, qinv, a
  mul  \a, \a, \qinv
  srai \a, \a, 32
  addi \a, \a, 8
  mulh \a, \a, \q32
.endm

.macro plant_red_x4 \
        q32, qinv,  \
        a_0, a_1, a_2, a_3
  mul  \a_0, \a_0, \qinv
  mul  \a_1, \a_1, \qinv
  mul  \a_2, \a_2, \qinv
  mul  \a_3, \a_3, \qinv
  srai \a_0, \a_0, 32
  srai \a_1, \a_1, 32
  srai \a_2, \a_2, 32
  srai \a_3, \a_3, 32
  addi \a_0, \a_0, 8
  addi \a_1, \a_1, 8
  addi \a_2, \a_2, 8
  addi \a_3, \a_3, 8
  mulh \a_0, \a_0, \q32
  mulh \a_1, \a_1, \q32
  mulh \a_2, \a_2, \q32
  mulh \a_3, \a_3, \q32
.endm

.equ q,    3329
.equ q32,  0xd0100000000                // q << 32
.equ qinv, 0x3c0f12886ba8f301           // q^-1 mod 2^64
.equ plantconst, 0x13afb7680bb055       // (((-2**64) % q) * qinv) % (2**64)
.equ plantconst2, 0x1a390f4d9791e139    // (((-2**64) % q) * ((-2**64) % q) * qinv) % (2**64)

// |input| < 0.5q; |output| < 3.5q
// a0: poly, a1: 64-bit twiddle ptr; a6: q<<32;
// a7/gp/tp/ra: tmp; 
// 4*15(sp): loop;
// s0-s11, a2-a5: 16 coeffs; 
// 7 twiddle factors: t0-t6
.global ntt_rv64im
.align 2
ntt_rv64im:
  addi sp, sp, -8*16
  save_regs
  li a6, q32        // q<<32
  addi a0, a0, 32   // poly[16]
  addi gp, x0, 15   // loop
  sd gp, 8*15(sp)
  // load twiddle factors
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  ### LAYER 1+2+3+4
  ntt_rv64im_loop1:
    addi a0, a0, -2
    // 16*i, i \in [0-15]
    load_coeffs a0, 16, 2
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
    // The following 8 twiddle factors have to be loaded at each iteration
    // In ct_bfu, twiddle and tmp can be reused because each twiddle is only used once. The gs_bfu cannot.
    ct_bfu_x8_loadzetas \
      s0,  s1, s2,  s3, \
      s4,  s5, s6,  s7, \
      s8,  s9, s10, s11,\
      a2,  a3, a4,  a5, \
      7*8, 8*8, 9*8, 10*8, \
      11*8,12*8,13*8,14*8, \
      a6, a7, gp, tp, ra
    // store 16 coeffs
    store_coeffs a0, 16, 2
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bge gp, zero, ntt_rv64im_loop1 # 16 loops
  addi a1, a1, 15*8
  ### LAYER 5-6-7
  addi gp, x0, 16
  sd gp, 8*15(sp)
  ntt_rv64im_loop2:
    // load coefficients
    load_coeffs a0, 1, 2
    // load twiddle factors
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
      s0,  s4, s1,  s5,   \
      s2,  s6, s3,  s7,   \
      s8,  a2, s9,  a3,   \
      s10, a4, s11, a5,   \
      t1, t1, t1, t1,     \
      t2, t2, t2, t2,     \
      a6, a7, gp, tp, ra
    // layer 7
    ct_bfu_x8 \
      s0, s2, s1, s3,     \
      s4, s6, s5, s7,     \
      s8, s10, s9, s11,   \
      a2, a4, a3, a5,     \
      t3, t3, t4, t4,     \
      t5, t5, t6, t6,     \
      a6, a7, gp, tp, ra
    store_coeffs a0, 1, 2
    addi a0, a0, 32 // poly+=16
    addi a1, a1, 7*8 // zeta
  ld gp, 8*15(sp)
  addi gp, gp, -1 // loop
  sd gp, 8*15(sp)
  bne gp, zero, ntt_rv64im_loop2
  restore_regs
  addi sp, sp, 8*16
  ret

// |input| < kq; |output| < 0.5q
// a0: poly, a1: 64-bit twiddle ptr; a6: q<<32;
// a7/gp/tp/ra: tmp;
// 4*15(sp): loop;
// s0-s11, a2-a5: 16 coeffs; 
// 7 twiddle factors: t0-t6
.global intt_rv64im
.align 2
intt_rv64im:
  addi sp, sp, -8*16
  save_regs
  li a6, q32 // q<<32
  ### LAYER 7+6+5
  addi gp, x0, 16
  sd gp, 8*15(sp)
  intt_rv64im_loop1:
    // load coefficients
    load_coeffs a0, 1, 2
    // load twiddle factors
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    // layer 7
    gs_bfu_x8 \
      s0, s2, s1, s3, \
      s4, s6, s5, s7, \
      s8, s10,s9, s11,\
      a2, a4, a3, a5, \
      t0, t0, t1, t1, \
      t2, t2, t3, t3, \
      a6, a7, gp, tp, ra
    // layer 6
    gs_bfu_x8 \
      s0,  s4, s1,  s5, \
      s2,  s6, s3,  s7, \
      s8,  a2, s9,  a3, \
      s10, a4, s11, a5, \
      t4, t4, t4, t4, \
      t5, t5, t5, t5, \
      a6, a7, gp, tp, ra
    // layer 5
    gs_bfu_x8 \
      s0, s8, s1, s9,   \
      s2, s10, s3, s11, \
      s4, a2, s5, a3,   \
      s6, a4, s7, a5,   \
      t6, t6, t6, t6, \
      t6, t6, t6, t6, \
      a6, a7, gp, tp, ra
    store_coeffs a0, 1, 2
    addi a0, a0, 32
    addi a1, a1, 8*7
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bne gp, zero, intt_rv64im_loop1
  addi a0, a0, -512
  ### LAYER 4+3+2+1
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  addi a0, a0, 32
  addi gp, x0, 15
  sd gp, 8*15(sp)
  intt_rv64im_loop2:
    addi a0, a0, -2
    load_coeffs a0, 16, 2
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
    // The following twiddle factors have to be loaded at each iteration
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
    store_coeffs a0, 16, 2
  ld gp, 8*15(sp)
  addi gp, gp, -1
  sd gp, 8*15(sp)
  bge gp, zero, intt_rv64im_loop2
  restore_regs
  addi sp, sp, 8*16
  ret

// void poly_basemul_acc_rv64im(int32_t *r, const int16_t *a, const int16_t *b, uint64_t *zetas)
// compute basemul and accumulate the 32-bit results into r
// a0: r, a1: a, a2: b, a3: zetas
// a5: q<<32, a6: loop control
.global poly_basemul_acc_rv64im
.align 2
poly_basemul_acc_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a5, q32
    li a6, 32
poly_basemul_acc_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # 4 zetas: a7, gp, tp, ra
    ld  a7, 8*0(a3)
    ld  tp, 8*1(a3)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    neg gp, a7
    neg ra, tp
    # available regs: a4, s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    plant_mul_const_x4    \
      a5, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a0)
    lw  s9, 4*1(a0)
    # a[0]b[0]
    mul s2, t0, s0
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    lw  s10, 4*2(a0)
    lw  s11, 4*3(a0)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # store r[0,1]
    sw  s8, 4*0(a0)
    sw  s9, 4*1(a0)
    # available regs: s0, s1, s8, s9, a7, t6
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[2]
    mul s0, t0, s2
    # a[2]b[3]
    mul s8, t0, s3
    # a[3]b[2]
    mul s9, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, s8
    add s11, s11, s9
    # store r[2,3]
    sw  s10, 4*2(a0)
    sw  s11, 4*3(a0)
    # r[4,5,6,7]
    lw  s8, 4*4(a0)
    lw  s9, 4*5(a0)
    lw  s10,4*6(a0)
    lw  s11,4*7(a0)
    # a[4]b[4]
    mul s0, t2, s4
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # store r[4,5]
    sw  s8, 4*4(a0)
    sw  s9, 4*5(a0)
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    # store r[6,7]
    sw  s10,4*6(a0)
    sw  s11,4*7(a0)
    // loop control
    addi a0, a0, 4*8
    addi a1, a1, 2*8
    addi a2, a2, 2*8
    addi a3, a3, 8*2
    addi a6, a6, -1
    bne a6, zero, poly_basemul_acc_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret

// void poly_basemul_acc_end_rv64im(int16_t *r, const int16_t *a, const int16_t *b, uint64_t *zetas, int32_t *r_double)
// compute basemul, accumulate the 32-bit results into r_double, and reduce r_double to r
// a0: r, a1: a, a2: b, a3: zetas, a4: r_double
.global poly_basemul_acc_end_rv64im
.align 2
poly_basemul_acc_end_rv64im:
    addi sp, sp, -8*16
    save_regs
    li a5, q32
    li a6, qinv
    li a7, 32
    sd a7, 8*15(sp)
poly_basemul_acc_end_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # 4 zetas: a7, gp, tp, ra
    ld  a7, 8*0(a3)
    ld  tp, 8*1(a3)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    neg gp, a7
    neg ra, tp
    # available regs: s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    plant_mul_const_x4    \
      a5, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a4)
    lw  s9, 4*1(a4)
    # a[0]b[0]
    mul s2, t0, s0
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    lw  s10,4*2(a4)
    lw  s11,4*3(a4)
    # available regs: s0, s1, a7, t6
    # a[2]b[2]
    mul s0, t0, s2
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[3]
    mul a7, t0, s3
    # a[3]b[2]
    mul t6, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, a7
    add s11, s11, t6
    plant_red_x4 \
      a5, a6,    \
      s8, s9, s10, s11
    # store r[0,1,2,3]
    sh  s8, 2*0(a0)
    sh  s9, 2*1(a0)
    sh  s10,2*2(a0)
    sh  s11,2*3(a0)
    # a[4]b[4]
    mul s0, t2, s4
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # r[4,5]
    lw  s8, 4*4(a4)
    lw  s9, 4*5(a4)
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  s6, 2*6(a2)
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[6,7]
    lw  s10,4*6(a4)
    lw  s11,4*7(a4)
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    plant_red_x4 \
      a5, a6,    \
      s8, s9, s10, s11
    # store r[0,1,2,3]
    sh  s8, 2*4(a0)
    sh  s9, 2*5(a0)
    sh  s10,2*6(a0)
    sh  s11,2*7(a0)
    // loop control
    addi a0, a0, 2*8
    addi a1, a1, 2*8
    ld   a7, 8*15(sp)
    addi a2, a2, 2*8
    addi a3, a3, 8*2
    addi a4, a4, 4*8
    addi a7, a7, -1
    sd   a7, 8*15(sp)
    bne a7, zero, poly_basemul_acc_end_rv64im_loop
    restore_regs
    addi sp, sp, 8*16
ret

// void poly_basemul_cache_init_rv64im(int32_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, uint64_t *zetas)
// compute basemul, cache bzeta into b_cache, and store the 32-bit results into r
// a0: r, a1: a, a2: b, a3: b_cache, a4: zetas
// a5: q<<32, a6: loop control
.global poly_basemul_cache_init_rv64im
.align 2
poly_basemul_cache_init_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a5, q32
    li a6, 32
poly_basemul_cache_init_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # 4 zetas: a7, gp, tp, ra
    ld  a7, 8*0(a4)
    ld  tp, 8*1(a4)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    neg gp, a7
    neg ra, tp
    # available regs: s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    plant_mul_const_x4    \
      a5, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[0]
    mul s2, t0, s0
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    sh  t2, 2*0(a3)
    sh  t3, 2*1(a3)
    # r[0]=a[0]b[0]+a[1](b[1]zeta)
    add s2, s2, s4
    # r[1]=a[0]b[1]+a[1]b[0]
    add s6, s6, t6
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # store r[0,1]
    sw  s2, 4*0(a0)
    sw  s6, 4*1(a0)
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    lh  s4, 2*4(a2)
    sh  t4, 2*2(a3)
    sh  t5, 2*3(a3)
    # available regs: s0, s1, s8, s9, a7, t6
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[2]
    mul s0, t0, s2
    # a[2]b[3]
    mul s8, t0, s3
    # a[3]b[2]
    mul s9, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    # r[2]=a[2]b[2]+a[3](b[3]zeta)
    add s0, s0, s1
    # r[3]=a[2]b[3]+a[3]b[2]
    add s8, s8, s9
    # store r[2,3]
    sw  s0, 4*2(a0)
    sw  s8, 4*3(a0)
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # a[4]b[4]
    mul s0, t2, s4
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    # r[4]=a[4]b[4]+a[5](b[5]zeta)
    add s0, s0, s1
    # r[5]=a[4]b[5]+a[5]b[4]
    add t0, t0, t1
    # store r[4,5]
    sw  s0, 4*4(a0)
    sw  t0, 4*5(a0)
    # a[7](b[7]zeta)
    mul s9, ra, t5
    # a[6]b[6]
    mul s8, gp, s6
    # a[6]b[7]
    mul s10, gp, s7
    # a[7]b[6]
    mul s11, ra, s6
    # r[6]=a[6]b[6]+a[7](b[7]zeta)
    add s8, s8, s9
    # r[7]=a[6]b[7]+a[7]b[6]
    add s10, s10, s11
    # store r[6,7]
    sw  s8, 4*6(a0)
    sw  s10,4*7(a0)
    // loop control
    addi a0, a0, 4*8
    addi a1, a1, 2*8
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a4, a4, 8*2
    addi a6, a6, -1
    bne a6, zero, poly_basemul_cache_init_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret

// void poly_basemul_acc_cache_init_rv64im(int32_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, uint64_t *zetas)
// compute basemul, cache bzeta into b_cache, and accumulate the 32-bit results into r
// a0: r, a1: a, a2: b, a3: b_cache, a4: zetas
// a5: q<<32, a6: loop control, a7: accumulated value
.global poly_basemul_acc_cache_init_rv64im
.align 2
poly_basemul_acc_cache_init_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a5, q32
    li a6, 32
poly_basemul_acc_cache_init_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # 4 zetas: a7, gp, tp, ra
    ld  a7, 8*0(a4)
    ld  tp, 8*1(a4)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    neg gp, a7
    neg ra, tp
    # available regs: s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    plant_mul_const_x4    \
      a5, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a0)
    lw  s9, 4*1(a0)
    lw  s10,4*2(a0)
    lw  s11,4*3(a0)
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[0]
    mul s2, t0, s0
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    sh  t2, 2*0(a3)
    sh  t3, 2*1(a3)
    sh  t4, 2*2(a3)
    sh  t5, 2*3(a3)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # store r[0,1]
    sw  s8, 4*0(a0)
    sw  s9, 4*1(a0)
    # available regs: s0, s1, s8, s9, a7, t6
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[2]
    mul s0, t0, s2
    # a[2]b[3]
    mul s8, t0, s3
    # a[3]b[2]
    mul s9, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, s8
    add s11, s11, s9
    # store r[2,3]
    sw  s10, 4*2(a0)
    sw  s11, 4*3(a0)
    # r[4,5,6,7]
    lw  s8, 4*4(a0)
    lw  s9, 4*5(a0)
    lw  s10,4*6(a0)
    lw  s11,4*7(a0)
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # a[4]b[4]
    mul s0, t2, s4
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # store r[4,5]
    sw  s8, 4*4(a0)
    sw  s9, 4*5(a0)
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    # store r[6,7]
    sw  s10,4*6(a0)
    sw  s11,4*7(a0)
    // loop control
    addi a0, a0, 4*8
    addi a1, a1, 2*8
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a4, a4, 8*2
    addi a6, a6, -1
    bne a6, zero, poly_basemul_acc_cache_init_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret

// void poly_basemul_acc_cache_init_end_rv64im(int16_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, uint64_t *zetas, int32_t *r_double)
// compute basemul, cache bzeta into b_cache, accumulate the 32-bit results into r_double, and reduce r_double to r
// a0: r, a1: a, a2: b, a3: b_cache, a4: zetas, a5: r_double
// a6: loop control
.global poly_basemul_acc_cache_init_end_rv64im
.align 2
poly_basemul_acc_cache_init_end_rv64im:
    addi sp, sp, -8*16
    save_regs
    li a6, qinv
    li a7, 32
    sd a7, 8*15(sp)
poly_basemul_acc_cache_init_end_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # 4 zetas: a7, gp, tp, ra
    ld  a7, 8*0(a4)
    ld  tp, 8*1(a4)
    neg gp, a7
    neg ra, tp
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    # available regs: s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    li  t6, q32
    plant_mul_const_x4    \
      t6, a7, gp, tp, ra, \
      s1, s3, s5, s7,     \
      t2, t3, t4, t5
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a5)
    lw  s9, 4*1(a5)
    lw  s10,4*2(a5)
    lw  s11,4*3(a5)
    # a[0]b[0]
    mul s2, t0, s0
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    sh  t2, 2*0(a3)
    sh  t3, 2*1(a3)
    sh  t4, 2*2(a3)
    sh  t5, 2*3(a3)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    # available regs: s0, s1, a7, t6
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # a[2]b[2]
    mul s0, t0, s2
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[3]
    mul a7, t0, s3
    # a[3]b[2]
    mul t6, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, a7
    add s11, s11, t6
    li s0, q32
    plant_red_x4 \
      s0, a6,    \
      s8, s9, s10, s11
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    # store r[0,1,2,3]
    sh  s8, 2*0(a0)
    sh  s9, 2*1(a0)
    sh  s10,2*2(a0)
    sh  s11,2*3(a0)
    # a[4]b[4]
    mul s0, t2, s4
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # r[4,5]
    lw  s8, 4*4(a5)
    lw  s9, 4*5(a5)
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # r[6,7]
    lw  s10,4*6(a5)
    lw  s11,4*7(a5)
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    li  s0, q32
    plant_red_x4 \
      s0, a6,    \
      s8, s9, s10, s11
    # store r[0,1,2,3]
    sh  s8, 2*4(a0)
    sh  s9, 2*5(a0)
    sh  s10,2*6(a0)
    sh  s11,2*7(a0)
    // loop control
    addi a0, a0, 2*8
    addi a1, a1, 2*8
    ld   a7, 8*15(sp)
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a4, a4, 8*2
    addi a5, a5, 4*8
    addi a7, a7, -1
    sd   a7, 8*15(sp)
    bne a7, zero, poly_basemul_acc_cache_init_end_rv64im_loop
    restore_regs
    addi sp, sp, 8*16
ret

// void poly_basemul_acc_cached_rv64im(int32_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache)
// compute basemul using cached b_cache and accumulate the 32-bit results into r
// a0: r, a1: a, a2: b, a3: b_cache
// a5: q<<32, a6: loop control
.global poly_basemul_acc_cached_rv64im
.align 2
poly_basemul_acc_cached_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a5, q32
    li a6, 32
poly_basemul_acc_cached_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    lh  t2, 2*0(a3)
    lh  t3, 2*1(a3)
    lh  t4, 2*2(a3)
    lh  t5, 2*3(a3)
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a0)
    lw  s9, 4*1(a0)
    # a[0]b[0]
    mul s2, t0, s0
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    lw  s10, 4*2(a0)
    lw  s11, 4*3(a0)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # store r[0,1]
    sw  s8, 4*0(a0)
    sw  s9, 4*1(a0)
    # available regs: s0, s1, s8, s9, a7, t6
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[2]
    mul s0, t0, s2
    # a[2]b[3]
    mul s8, t0, s3
    # a[3]b[2]
    mul s9, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, s8
    add s11, s11, s9
    # store r[2,3]
    sw  s10, 4*2(a0)
    sw  s11, 4*3(a0)
    # r[4,5,6,7]
    lw  s8, 4*4(a0)
    lw  s9, 4*5(a0)
    lw  s10,4*6(a0)
    lw  s11,4*7(a0)
    # a[4]b[4]
    mul s0, t2, s4
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    lh  s6, 2*6(a2)
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # store r[4,5]
    sw  s8, 4*4(a0)
    sw  s9, 4*5(a0)
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    # store r[6,7]
    sw  s10,4*6(a0)
    sw  s11,4*7(a0)
    // loop control
    addi a0, a0, 4*8
    addi a1, a1, 2*8
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a6, a6, -1
    bne a6, zero, poly_basemul_acc_cached_rv64im_loop
    restore_regs
    addi sp, sp, 8*15
ret

// void poly_basemul_acc_cache_end_rv64im(int16_t *r, const int16_t *a, const int16_t *b, int16_t *b_cache, int32_t *r_double)
// compute basemul using cached b_cache, accumulate the 32-bit results into r_double, and reduce r_double to r
// a0: r, a1: a, a2: b, a3: b_cache, a4: r_double
// a5: q<<32, a6: loop control
.global poly_basemul_acc_cache_end_rv64im
.align 2
poly_basemul_acc_cache_end_rv64im:
    addi sp, sp, -8*16
    save_regs
    li a5, q32
    li a6, qinv
    li a7, 32
    sd a7, 8*15(sp)
poly_basemul_acc_cached_end_rv64im_loop:
    # b[0,1,3,5,7]
    lh s0, 2*0(a2)
    lh s1, 2*1(a2)
    lh s3, 2*3(a2)
    lh s5, 2*5(a2)
    lh s7, 2*7(a2)
    # a[0,1]
    lh  t0, 2*0(a1)
    lh  t1, 2*1(a1)
    # available regs: s2, s4, s6, t2-t6
    # t2,t3,t4,t5 <- b[1,3,5,7]zeta
    lh  t2,  2*0(a3)
    lh  t3,  2*1(a3)
    lh  t4,  2*2(a3)
    lh  t5,  2*3(a3)
    # s8,s9,s10,s11 <- r[0,1,2,3]
    lw  s8, 4*0(a4)
    lw  s9, 4*1(a4)
    # a[0]b[0]
    mul s2, t0, s0
    # a[1](b[1]zeta)
    mul s4, t1, t2
    # a[0]b[1]
    mul s6, t0, s1
    # a[1]b[0]
    mul t6, t1, s0
    # t0,t1,t2,tp,gp,ra <- a[2,3,4,5,6,7]
    lh  t0, 2*2(a1)
    lh  t1, 2*3(a1)
    # r[0]+=a[0]b[0]+a[1](b[1]zeta)
    add s8, s8, s2
    add s8, s8, s4
    # s2,s4,s6 <- b[2,4,6]
    lh  s2, 2*2(a2)
    # r[1]+=a[0]b[1]+a[1]b[0]
    add s9, s9, s6
    add s9, s9, t6
    lw  s10,4*2(a4)
    lw  s11,4*3(a4)
    # available regs: s0, s1, a7, t6
    # a[2]b[2]
    mul s0, t0, s2
    # a[3](b[3]zeta)
    mul s1, t1, t3
    # a[2]b[3]
    mul a7, t0, s3
    # a[3]b[2]
    mul t6, t1, s2
    lh  t2, 2*4(a1)
    lh  tp, 2*5(a1)
    lh  s4, 2*4(a2)
    # r[2]+=a[2]b[2]+a[3](b[3]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[3]+=a[2]b[3]+a[3]b[2]
    add s11, s11, a7
    add s11, s11, t6
    plant_red_x4 \
      a5, a6,    \
      s8, s9, s10, s11
    # store r[0,1,2,3]
    sh  s8, 2*0(a0)
    sh  s9, 2*1(a0)
    sh  s10,2*2(a0)
    sh  s11,2*3(a0)
    # a[4]b[4]
    mul s0, t2, s4
    # a[5](b[5]zeta)
    mul s1, tp, t4
    # r[4,5]
    lw  s8, 4*4(a4)
    lw  s9, 4*5(a4)
    # a[4]b[5]
    mul t0, t2, s5
    # a[5]b[4]
    mul t1, tp, s4
    lh  s6, 2*6(a2)
    lh  gp, 2*6(a1)
    lh  ra, 2*7(a1)
    # r[4]+=a[4]b[4]+a[5](b[5]zeta)
    add s8, s8, s0
    add s8, s8, s1
    # r[6,7]
    lw  s10,4*6(a4)
    lw  s11,4*7(a4)
    # r[5]+=a[4]b[5]+a[5]b[4]
    add s9, s9, t0
    add s9, s9, t1
    # a[6]b[6]
    mul s0, gp, s6
    # a[7](b[7]zeta)
    mul s1, ra, t5
    # a[6]b[7]
    mul t0, gp, s7
    # a[7]b[6]
    mul t1, ra, s6
    # r[6]+=a[6]b[6]+a[7](b[7]zeta)
    add s10, s10, s0
    add s10, s10, s1
    # r[7]+=a[6]b[7]+a[7]b[6]
    add s11, s11, t0
    add s11, s11, t1
    plant_red_x4 \
      a5, a6,    \
      s8, s9, s10, s11
    # store r[0,1,2,3]
    sh  s8, 2*4(a0)
    sh  s9, 2*5(a0)
    sh  s10,2*6(a0)
    sh  s11,2*7(a0)
    // loop control
    addi a0, a0, 2*8
    addi a1, a1, 2*8
    ld   a7, 8*15(sp)
    addi a2, a2, 2*8
    addi a3, a3, 2*4
    addi a4, a4, 4*8
    addi a7, a7, -1
    sd   a7, 8*15(sp)
    bne a7, zero, poly_basemul_acc_cached_end_rv64im_loop
    restore_regs
    addi sp, sp, 8*16
ret

// each coeff is multiplied by plantconst2 using plantard multiplication
.global poly_plantard_rdc_rv64im
.align 2
poly_plantard_rdc_rv64im:
  addi sp, sp, -8*1
  sd   s0, 0(sp)
  li t6, plantconst
  li t5, q32
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

// plantard reduction to a poly
.global poly_toplant_rv64im
.align 2
poly_toplant_rv64im:
  addi sp, sp, -8*1
  sd   s0, 0(sp)
  li t6, plantconst2
  li t5, q32
  addi t4, x0, 16
  poly_toplant_rv64im_loop:
    lh a1,  2*0(a0)
    lh a2,  2*1(a0)
    lh a3,  2*2(a0)
    lh a4,  2*3(a0)
    lh t0,  2*4(a0)
    lh t1,  2*5(a0)
    lh t2,  2*6(a0)
    lh t3,  2*7(a0)
    plant_mul_const_inplace_x4 \
      t5, t6, t6, t6, t6, \
      a1, a2, a3, a4
    lh a5,  2*8(a0)
    lh a6,  2*9(a0)
    lh a7, 2*10(a0)
    lh s0, 2*11(a0)
    sh a1,  2*0(a0)
    sh a2,  2*1(a0)
    sh a3,  2*2(a0)
    sh a4,  2*3(a0)
    plant_mul_const_inplace_x4 \
      t5, t6, t6, t6, t6, \
      t0, t1, t2, t3
    lh a1,  2*12(a0)
    lh a2,  2*13(a0)
    lh a3,  2*14(a0)
    lh a4,  2*15(a0)
    sh t0,  2*4(a0)
    sh t1,  2*5(a0)
    sh t2,  2*6(a0)
    sh t3,  2*7(a0)
    plant_mul_const_inplace_x4 \
      t5, t6, t6, t6, t6, \
      a5, a6, a7, s0
    sh a5,  2*8(a0)
    sh a6,  2*9(a0)
    sh a7,  2*10(a0)
    sh s0,  2*11(a0)
    plant_mul_const_inplace_x4 \
      t5, t6, t6, t6, t6, \
      a1, a2, a3, a4
    sh a1,  2*12(a0)
    sh a2,  2*13(a0)
    sh a3,  2*14(a0)
    sh a4,  2*15(a0)
    addi a0, a0, 2*16
    addi t4, t4, -1
  bne t4, zero, poly_toplant_rv64im_loop
  ld   s0, 0(sp)
  addi sp, sp, 8*1
  ret

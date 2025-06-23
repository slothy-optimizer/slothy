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

# todo: range analysis
// |input| < kq; |output| < 0.5q
// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 8 twiddle factors: can be preloaded; t0-t6, tp; ra: tmp zeta.
.global intt_rv64im
.align 2
intt_rv64im:
  addi sp, sp, -8*15
  save_regs
  li a6, q32
  ### LAYER 8+7+6+5
  addi gp, x0, 16
  intt_rv64im_loop1:
    load_coeffs a0, 1, 4
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    ld tp, 7*8(a1)
    // layer 8
    gs_bfu s0,  s1, t0, a6, a7
    gs_bfu s2,  s3, t1, a6, a7
    gs_bfu s4,  s5, t2, a6, a7
    gs_bfu s6,  s7, t3, a6, a7
    gs_bfu s8,  s9, t4, a6, a7
    gs_bfu s10,s11, t5, a6, a7
    gs_bfu a2,  a3, t6, a6, a7
    gs_bfu a4,  a5, tp, a6, a7
    // layer 7
    ld ra, 8*8(a1)
    gs_bfu s0, s2,  ra, a6, a7
    gs_bfu s1, s3,  ra, a6, a7
    ld ra, 9*8(a1)
    gs_bfu s4, s6,  ra, a6, a7
    gs_bfu s5, s7,  ra, a6, a7
    ld ra, 10*8(a1)
    gs_bfu s8, s10, ra, a6, a7
    gs_bfu s9, s11, ra, a6, a7
    ld ra, 11*8(a1)
    gs_bfu a2, a4,  ra, a6, a7
    gs_bfu a3, a5,  ra, a6, a7
    // layer 6
    ld ra, 12*8(a1)
    gs_bfu s0,  s4, ra, a6, a7
    gs_bfu s1,  s5, ra, a6, a7
    gs_bfu s2,  s6, ra, a6, a7
    gs_bfu s3,  s7, ra, a6, a7
    ld ra, 13*8(a1)
    gs_bfu s8,  a2, ra, a6, a7
    gs_bfu s9,  a3, ra, a6, a7
    gs_bfu s10, a4, ra, a6, a7
    gs_bfu s11, a5, ra, a6, a7
    // layer 5
    ld ra, 14*8(a1)
    gs_bfu s0, s8,  ra, a6, a7
    gs_bfu s1, s9,  ra, a6, a7
    gs_bfu s2, s10, ra, a6, a7
    gs_bfu s3, s11, ra, a6, a7
    gs_bfu s4, a2,  ra, a6, a7
    gs_bfu s5, a3,  ra, a6, a7
    gs_bfu s6, a4,  ra, a6, a7
    gs_bfu s7, a5,  ra, a6, a7
    store_coeffs a0, 1, 4
    addi a0, a0, 16*4
    addi a1, a1, 8*15
  addi gp, gp, -1
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
  ld tp, 7*8(a1)
  addi a0, a0, 16*4
  addi gp, x0, 15
  intt_rv64im_loop2:
    addi a0, a0, -4
    load_coeffs a0, 16, 4
    // layer 4
    gs_bfu s0,  s1,  t0, a6, a7
    gs_bfu s2,  s3,  t1, a6, a7 
    gs_bfu s4,  s5,  t2, a6, a7
    gs_bfu s6,  s7,  t3, a6, a7
    gs_bfu s8,  s9,  t4, a6, a7
    gs_bfu s10, s11, t5, a6, a7
    gs_bfu a2,  a3,  t6, a6, a7
    gs_bfu a4,  a5,  tp, a6, a7
    // layer 3
    ld ra, 8*8(a1)
    gs_bfu s0, s2,  ra, a6, a7
    gs_bfu s1, s3,  ra, a6, a7
    ld ra, 9*8(a1)
    gs_bfu s4, s6,  ra, a6, a7
    gs_bfu s5, s7,  ra, a6, a7
    ld ra, 10*8(a1)
    gs_bfu s8, s10, ra, a6, a7
    gs_bfu s9, s11, ra, a6, a7
    ld ra, 11*8(a1)
    gs_bfu a2, a4,  ra, a6, a7
    gs_bfu a3, a5,  ra, a6, a7
    // layer 2
    ld ra, 12*8(a1)
    gs_bfu s0,  s4, ra, a6, a7
    gs_bfu s1,  s5, ra, a6, a7
    gs_bfu s2,  s6, ra, a6, a7
    gs_bfu s3,  s7, ra, a6, a7
    ld ra, 13*8(a1)
    gs_bfu s8,  a2, ra, a6, a7
    gs_bfu s9,  a3, ra, a6, a7
    gs_bfu s10, a4, ra, a6, a7
    gs_bfu s11, a5, ra, a6, a7
    // layer 1
    ld ra, 14*8(a1)
    gs_bfu s0, s8,  ra, a6, a7
    gs_bfu s1, s9,  ra, a6, a7
    gs_bfu s2, s10, ra, a6, a7
    gs_bfu s3, s11, ra, a6, a7
    gs_bfu s4, a2,  ra, a6, a7
    gs_bfu s5, a3,  ra, a6, a7
    gs_bfu s6, a4,  ra, a6, a7
    gs_bfu s7, a5,  ra, a6, a7
    ld ra, 15*8(a1)
    plant_mul_const_inplace a6, ra, s0
    plant_mul_const_inplace a6, ra, s1
    plant_mul_const_inplace a6, ra, s2
    plant_mul_const_inplace a6, ra, s3
    plant_mul_const_inplace a6, ra, s4
    plant_mul_const_inplace a6, ra, s5
    plant_mul_const_inplace a6, ra, s6
    plant_mul_const_inplace a6, ra, s7
    store_coeffs a0, 16, 4
  addi gp, gp, -1
  bge gp, zero, intt_rv64im_loop2
  restore_regs
  addi sp, sp, 8*15
  ret
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

// |input| < 0.5q; |output| < 3.5q
// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp, variable twiddle factors; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 9 twiddle factors: can be preloaded; t0-t6, tp, ra.
.global ntt_rv64im
.align 2
ntt_rv64im:
  addi sp, sp, -8*15
  save_regs
  li a6, q32        // q<<32
  addi a0, a0, 32   // poly[16]
  addi gp, x0, 15   // loop
  // load 9 twiddle factors
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  ld tp, 7*8(a1)
  ld ra, 8*8(a1)
  ### LAYER 1+2+3+4
  ntt_rv64im_loop1:
    addi a0, a0, -2
    // 16*i, i \in [0-15]
    load_coeffs a0, 16, 2
    // layer 1
    ct_butterfly s0, s8,  t0, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1, s9,  t0, a6, a7
    ct_butterfly s2, s10, t0, a6, a7
    ct_butterfly s3, s11, t0, a6, a7
    ct_butterfly s4, a2,  t0, a6, a7
    ct_butterfly s5, a3,  t0, a6, a7
    ct_butterfly s6, a4,  t0, a6, a7
    ct_butterfly s7, a5,  t0, a6, a7
    // layer 2
    ct_butterfly s0,  s4, t1, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1,  s5, t1, a6, a7
    ct_butterfly s2,  s6, t1, a6, a7
    ct_butterfly s3,  s7, t1, a6, a7
    ct_butterfly s8,  a2, t2, a6, a7
    ct_butterfly s9,  a3, t2, a6, a7
    ct_butterfly s10, a4, t2, a6, a7
    ct_butterfly s11, a5, t2, a6, a7
    // layer 3
    ct_butterfly s0, s2,  t3, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1, s3,  t3, a6, a7
    ct_butterfly s4, s6,  t4, a6, a7
    ct_butterfly s5, s7,  t4, a6, a7
    ct_butterfly s8, s10, t5, a6, a7
    ct_butterfly s9, s11, t5, a6, a7
    ct_butterfly a2, a4,  t6, a6, a7
    ct_butterfly a3, a5,  t6, a6, a7
    // layer 4
    ct_butterfly s0,  s1,  tp, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s2,  s3,  ra, a6, a7 
    // The following 6 twiddle factors have to be loaded at each iteration
    ld a7, 9*8(a1)
    ct_butterfly s4,  s5,  a7, a6, a7 // In ct_butterfly, twiddle and tmp can be reused because each twiddle is only used once. The gs_butterfly cannot.
    ld a7, 10*8(a1)
    ct_butterfly s6,  s7,  a7, a6, a7
    ld a7, 11*8(a1)
    ct_butterfly s8,  s9,  a7, a6, a7
    ld a7, 12*8(a1)
    ct_butterfly s10, s11, a7, a6, a7
    ld a7, 13*8(a1)
    ct_butterfly a2,  a3,  a7, a6, a7
    ld a7, 14*8(a1)
    ct_butterfly a4,  a5,  a7, a6, a7
    // store 16 coeffs
    store_coeffs a0, 16, 2
  addi gp, gp, -1
  bge gp, zero, ntt_rv64im_loop1 # 16 loops
  addi a1, a1, 15*8
  ### LAYER 5-6-7
  addi gp, x0, 16
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
    ct_butterfly s0, s8,  t0, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1, s9,  t0, a6, a7
    ct_butterfly s2, s10, t0, a6, a7
    ct_butterfly s3, s11, t0, a6, a7
    ct_butterfly s4, a2,  t0, a6, a7
    ct_butterfly s5, a3,  t0, a6, a7
    ct_butterfly s6, a4,  t0, a6, a7
    ct_butterfly s7, a5,  t0, a6, a7
    // layer 6
    ct_butterfly s0,  s4, t1, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1,  s5, t1, a6, a7
    ct_butterfly s2,  s6, t1, a6, a7
    ct_butterfly s3,  s7, t1, a6, a7
    ct_butterfly s8,  a2, t2, a6, a7
    ct_butterfly s9,  a3, t2, a6, a7
    ct_butterfly s10, a4, t2, a6, a7
    ct_butterfly s11, a5, t2, a6, a7
    // layer 7
    ct_butterfly s0, s2,  t3, a6, a7 // coeff0, coeff1, twiddle, q, tmp
    ct_butterfly s1, s3,  t3, a6, a7
    ct_butterfly s4, s6,  t4, a6, a7
    ct_butterfly s5, s7,  t4, a6, a7
    ct_butterfly s8, s10, t5, a6, a7
    ct_butterfly s9, s11, t5, a6, a7
    ct_butterfly a2, a4,  t6, a6, a7
    ct_butterfly a3, a5,  t6, a6, a7
    store_coeffs a0, 1, 2
    addi a0, a0, 32 // poly+=16
    addi a1, a1, 7*8 // zeta
  addi gp, gp, -1 // loop
  bne gp, zero, ntt_rv64im_loop2
  restore_regs
  addi sp, sp, 8*15
  ret
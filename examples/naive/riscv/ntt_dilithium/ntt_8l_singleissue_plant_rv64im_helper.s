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

// todo: range analysis
// |input| < kq; |output| < 0.5q
// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp; gp: loop;
// s0-s11, a2-a5: 16 coeffs;
// 16+2+1+1=20 regs;
// 8 twiddle factors: can be preloaded; t0-t6, tp; ra: tmp zeta.
.global intt_8l_rv64im
.align 2
intt_8l_rv64im:
  addi sp, sp, -8*15
  save_regs
  li a6, q32
  ////// LAYER 8+7+6+5
  addi gp, x0, 16
  intt_8l_rv64im_loop1:
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
  ld tp, 7*8(a1)
  addi a0, a0, 16*4
  addi gp, x0, 15
  intt_8l_rv64im_loop2:
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
  bge gp, zero, intt_8l_rv64im_loop2
  restore_regs
  addi sp, sp, 8*15
  ret

// void poly_basemul_8l_init_rv64im(int64_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_init_rv64im
.align 2
poly_basemul_8l_init_rv64im:
    addi sp, sp, -8*15
    save_regs
    // loop control
    li gp, 32*8*8
    add gp, gp, a0
poly_basemul_8l_init_rv64im_looper:
    lw t0, 0*4(a1) // a0
    lw s0, 0*4(a2) // b0
    lw t1, 1*4(a1) // a1
    lw s1, 1*4(a2) // b1
    lw t2, 2*4(a1) // a2
    lw s2, 2*4(a2) // b2
    lw t3, 3*4(a1) // a3
    lw s3, 3*4(a2) // b3
    mul s8, t0, s0
    mul s10,t1, s1
    mul a3, t2, s2
    mul a5, t3, s3
    sd s8, 0*8(a0)
    sd s10,1*8(a0)
    sd a3, 2*8(a0)
    sd a5, 3*8(a0)
    lw t4, 4*4(a1) // a4
    lw s4, 4*4(a2) // b4
    lw t5, 5*4(a1) // a5
    lw s5, 5*4(a2) // b5
    lw t6, 6*4(a1) // a6
    lw s6, 6*4(a2) // b6
    lw tp, 7*4(a1) // a7
    lw s7, 7*4(a2) // b7
    mul s8, t4, s4
    mul s10,t5, s5
    mul a3, t6, s6
    mul a5, tp, s7
    sd s8, 4*8(a0)
    sd s10,5*8(a0)
    sd a3, 6*8(a0)
    sd a5, 7*8(a0)
    // loop control
    addi a0, a0, 8*8
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    bne gp, a0, poly_basemul_8l_init_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_basemul_8l_acc_rv64im(int64_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_acc_rv64im
.align 2
poly_basemul_8l_acc_rv64im:
    addi sp, sp, -8*15
    save_regs
    // loop control
    li gp, 32*8*8
    add gp, gp, a0
poly_basemul_8l_acc_rv64im_looper:
    lw t0, 0*4(a1) // a0
    lw s0, 0*4(a2) // b0
    lw t1, 1*4(a1) // a1
    lw s1, 1*4(a2) // b1
    lw t2, 2*4(a1) // a2
    lw s2, 2*4(a2) // b2
    lw t3, 3*4(a1) // a3
    lw s3, 3*4(a2) // b3
    ld s9, 0*8(a0)
    ld s11,1*8(a0)
    ld a4, 2*8(a0)
    ld a6, 3*8(a0)
    mul s8, t0, s0
    mul s10,t1, s1
    mul a3, t2, s2
    mul a5, t3, s3
    add s8, s8, s9
    add s10,s10,s11
    add a3, a3, a4
    add a5, a5, a6
    sd s8, 0*8(a0)
    sd s10,1*8(a0)
    sd a3, 2*8(a0)
    sd a5, 3*8(a0)
    lw t4, 4*4(a1) // a4
    lw s4, 4*4(a2) // b4
    lw t5, 5*4(a1) // a5
    lw s5, 5*4(a2) // b5
    lw t6, 6*4(a1) // a6
    lw s6, 6*4(a2) // b6
    lw tp, 7*4(a1) // a7
    lw s7, 7*4(a2) // b7
    ld s9, 4*8(a0)
    ld s11,5*8(a0)
    ld a4, 6*8(a0)
    ld a6, 7*8(a0)
    mul s8, t4, s4
    mul s10,t5, s5
    mul a3, t6, s6
    mul a5, tp, s7
    add s8, s8, s9
    add s10,s10,s11
    add a3, a3, a4
    add a5, a5, a6
    sd s8, 4*8(a0)
    sd s10,5*8(a0)
    sd a3, 6*8(a0)
    sd a5, 7*8(a0)
    // loop control
    addi a0, a0, 8*8
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    bne gp, a0, poly_basemul_8l_acc_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_basemul_8l_acc_end_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256], int64_t r_double[256])
.globl poly_basemul_8l_acc_end_rv64im
.align 2
poly_basemul_8l_acc_end_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a4, q32
    li a5, qinv
    // loop control
    li gp, 64*4*4
    add gp, gp, a0
poly_basemul_8l_acc_end_rv64im_looper:
    // a0-a3
    lw s0, 0*4(a1)
    lw s1, 1*4(a1)
    lw s2, 2*4(a1)
    lw s3, 3*4(a1)
    // b0-b4
    lw t0, 0*4(a2)
    lw t1, 1*4(a2)
    lw t2, 2*4(a2)
    lw t3, 3*4(a2)
    // r_double[0-3]
    ld s4, 0*8(a3)
    ld s6, 1*8(a3)
    ld s8, 2*8(a3)
    ld s10,3*8(a3)
    // a0b0-a3b3
    mul t4, s0, t0
    mul a6, s1, t1
    mul t6, s2, t2
    mul a7, s3, t3
    // accumulate
    add s4, s4, t4
    add s6, s6, a6
    add s8, s8, t6
    add s10,s10,a7
    // rdc
    plant_red_x4 a4, a5, s4, s6, s8, s10
    // store results
    sw s4, 0*4(a0)
    sw s6, 1*4(a0)
    sw s8, 2*4(a0)
    sw s10,3*4(a0)
    // loop control
    addi a0, a0, 4*4
    addi a1, a1, 4*4
    addi a2, a2, 4*4
    addi a3, a3, 8*4
    bne gp, a0, poly_basemul_8l_acc_end_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_basemul_8l_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_rv64im
.align 2
poly_basemul_8l_rv64im:
    addi sp, sp, -8*15
    save_regs
    li a4, q32
    li a5, qinv
    // loop control
    li gp, 64*4*4
    add gp, gp, a0
poly_basemul_8l_rv64im_looper:
    // a0-a3
    lw s0, 0*4(a1)
    lw s1, 1*4(a1)
    lw s2, 2*4(a1)
    lw s3, 3*4(a1)
    // b0-b4
    lw t0, 0*4(a2)
    lw t1, 1*4(a2)
    lw t2, 2*4(a2)
    lw t3, 3*4(a2)
    // a0b0-a3b3
    mul s4, s0, t0
    mul s6, s1, t1
    mul s8, s2, t2
    mul s10,s3, t3
    plant_red_x4 a4, a5, s4, s6, s8, s10
    // store results
    sw s4, 0*4(a0)
    sw s6, 1*4(a0)
    sw s8, 2*4(a0)
    sw s10,3*4(a0)
    // loop control
    addi a0, a0, 4*4
    addi a1, a1, 4*4
    addi a2, a2, 4*4
    bne gp, a0, poly_basemul_8l_rv64im_looper
    restore_regs
    addi sp, sp, 8*15
    ret

// void poly_reduce_rv64im(int32_t in[256]);
.globl poly_reduce_rv64im
.align 2
poly_reduce_rv64im:
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
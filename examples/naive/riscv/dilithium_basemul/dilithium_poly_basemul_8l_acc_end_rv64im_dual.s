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

# void poly_basemul_8l_acc_end_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256], int64_t r_double[256])
.globl poly_basemul_8l_acc_end_rv64im_dual
.align 2
poly_basemul_8l_acc_end_rv64im_dual:
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
    mul s10, t2, s2
    mul s11, t3, s3
    lw s4, 4*4(a2) // b4
    lw s5, 5*4(a2) // b5
    add s8, s8, a6
    add s9, s9, a7
    lw t6, 6*4(a1) // a6
    lw tp, 7*4(a1) // a7
    add s10, s10, gp
    add s11, s11, ra
    lw s6, 6*4(a2) // b6
    lw s7, 7*4(a2) // b7
    plant_red_x4 a4, a5, s8, s9, s10, s11
    ld a6, 4*8(a3)
    ld a7, 5*8(a3)
    sw s8, 0*4(a0)
    sw s9, 1*4(a0)
    mul s8, t4, s4
    mul s9, t5, s5
    sw s10, 2*4(a0)
    sw s11, 3*4(a0)
    ld gp, 6*8(a3)
    ld ra, 7*8(a3)
    mul s10, t6, s6
    mul s11, tp, s7
    add s8, s8, a6
    add s9, s9, a7
    add s10, s10, gp
    add s11, s11, ra
    plant_red_x4 a4, a5, s8, s9, s10, s11
    ld  gp, 8*15(sp) // @slothy:ignore_useless_output
    addi a1, a1, 4*8
    addi a2, a2, 4*8
    addi a3, a3, 8*8
    sw s8, 4*4(a0)
    sw s9, 5*4(a0)
    sw s10, 6*4(a0)
    sw s11, 7*4(a0)
    addi a0, a0, 4*8
    bne a0, gp, poly_basemul_8l_acc_end_rv64im_looper
    restore_regs
    addi sp, sp, 8*16
    ret
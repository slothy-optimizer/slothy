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

# void poly_basemul_8l_rv64im(int32_t r[256], const int32_t a[256], const int32_t b[256])
.globl poly_basemul_8l_rv64im_dual
.align 2
poly_basemul_8l_rv64im_dual:
    addi sp, sp, -8*15
    save_regs
    li a4, q32
    li a5, qinv
    # loop control
    li gp, 32*8*4
    add gp, gp, a0
poly_basemul_8l_rv64im_looper:
    lw t0, 0*4(a1)
    lw t1, 1*4(a1)
    lw s0, 0*4(a2)
    lw s1, 1*4(a2)
    lw t2, 2*4(a1)
    lw t3, 3*4(a1)
    lw s2, 2*4(a2)
    lw s3, 3*4(a2)
    mul s8, s0, t0
    mul s9, s1, t1
    lw t4, 4*4(a1)
    lw t5, 5*4(a1)
    mul s10, s2, t2
    mul s11, s3, t3
    lw s4, 4*4(a2)
    lw s5, 5*4(a2)
    plant_red_x4 a4, a5, s8, s9, s10, s11
    lw t6, 6*4(a1)
    lw tp, 7*4(a1)
    lw s6, 6*4(a2)
    lw s7, 7*4(a2)
    mul s0, s4, t4
    mul s1, s5, t5
    sw s8, 0*4(a0)
    sw s9, 1*4(a0)
    mul s2, s6, t6
    mul s3, s7, tp
    sw s10, 2*4(a0)
    sw s11, 3*4(a0)
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
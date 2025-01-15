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
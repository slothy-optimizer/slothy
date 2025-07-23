.macro montmul_const vr0, va0, xzeta, xzetaqinv, xq, vt0
    vmul.vx  \vr0, \va0, \xzetaqinv
    vmulh.vx \vt0, \va0, \xzeta
    vmulh.vx \vr0, \vr0, \xq
    vsub.vv  \vr0, \vt0, \vr0
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

.globl poly_tomont_rvv_vlen128
.align 2
poly_tomont_rvv_vlen128:
    addi sp, sp, -8*15
    save_regs
    li a7, 16*8
    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    // mont^2 and qinv*mont^2
    li t1, 1353
    li t2, 20553
    slli t3, a7, 2
    slli a7, a7, 1
    add  t4, a0, 256*2
poly_tomont_rvv_vlen128_loop:
    add a1, a0, a7
    vle16.v v0,  (a0)
    vle16.v v8,  (a1)
    montmul_const v16, v0, t1, t2, t0, v24
    montmul_const v24, v8, t1, t2, t0, v0
    vse16.v v16, (a0)
    vse16.v v24, (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_tomont_rvv_vlen128_loop
    restore_regs
    addi sp, sp, 8*15
ret
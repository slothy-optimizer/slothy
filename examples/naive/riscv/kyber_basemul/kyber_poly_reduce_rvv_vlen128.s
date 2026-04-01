.macro barrettRdc in, vt0, const_v, const_q
    vmulh.vx \vt0, \in, \const_v
    vssra.vi \vt0, \vt0, 10
    vmul.vx  \vt0, \vt0, \const_q
    vsub.vv  \in,  \in, \vt0
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

.globl poly_reduce_rvv_vlen128
.align 2
poly_reduce_rvv_vlen128:
    addi sp, sp, -8*15
    save_regs
    li a7, 16*8
    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    csrwi vxrm, 0   // round-to-nearest-up (add +0.5 LSB)
    li a6, 20159
    add  t4, a0, 256*2  
    slli t3, a7, 2
    slli a7, a7, 1
poly_reduce_rvv_vlen128_loop:
    add a1, a0, a7
    vle16.v v0,  (a0)
    vle16.v v8,  (a1)
    barrettRdc v0, v16, a6, t0
    barrettRdc v8, v24, a6, t0
    vse16.v v0,  (a0)
    vse16.v v8,  (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_reduce_rvv_vlen128_loop
    restore_regs
    addi sp, sp, 8*15
ret
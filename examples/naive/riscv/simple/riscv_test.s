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

.globl test
.align 2
test:
    // raw boilerplate code: 38 cycles
    addi sp, sp, -8*15
    save_regs
    nop
    nop
    nop
    nop
    .rept 100
        start_label:
        vmul.vx  v1, v2, a0  // step 1
        vmul.vx  v3, v4, a1
        vmul.vx  v5, v6, a2
        vmul.vx  v7, v8, a3
        vmul.vx  v9, v10, a4
        vmul.vx  v11, v12, a5
        vmul.vx  v13, v14, a6
        vmul.vx  v15, v16, a7

        vmulh.vx v17, v2, t0  // step 4
        vmulh.vx v18, v4, t1
        vmulh.vx v19, v6, t2
        vmulh.vx v20, v8, t2
        vmulh.vx v21, v10, t2
        vmulh.vx v22, v12, t2
        vmulh.vx v23, v14, t2
        vmulh.vx v24, v16, t2

        vmulh.vx v1, v1, t2  // step 3
        vmulh.vx v3, v3, t2
        vmulh.vx v5, v5, t2
        vmulh.vx v7, v7, t2
        vmulh.vx v9, v9, t2
        vmulh.vx v11, v11, t2
        vmulh.vx v13, v13, t2
        vmulh.vx v15, v15, t2

        vsub.vv  v1, v17, v1  // step 5
        vsub.vv  v3, v18, v3
        vsub.vv  v5, v19, v5
        vsub.vv  v7, v20, v7
        vsub.vv  v9, v21, v9
        vsub.vv  v11, v22, v11
        vsub.vv  v13, v23, v13
        vsub.vv  v15, v24, v15

        vsub.vv  v2, v25, v1
        vsub.vv  v4, v26, v3
        vsub.vv  v6, v27, v5
        vsub.vv  v8, v28, v7
        vsub.vv  v10, v29, v9
        vsub.vv  v12, v30, v11
        vsub.vv  v14, v31, v13
        vsub.vv  v16, v0, v15
        vadd.vv  v25, v25, v1
        vadd.vv  v26, v26, v3
        vadd.vv  v27, v27, v5
        vadd.vv  v28, v28, v7
        vadd.vv  v29, v29, v9
        vadd.vv  v30, v30, v11
        vadd.vv  v31, v31, v13
        vadd.vv  v0, v0, v15
        end_label:
    .endr
    nop
    nop
    nop
    nop
    restore_regs
    addi sp, sp, 8*15
    ret
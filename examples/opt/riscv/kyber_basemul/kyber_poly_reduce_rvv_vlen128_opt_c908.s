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

.globl poly_reduce_rvv_vlen128_opt_c908
.align 2
poly_reduce_rvv_vlen128_opt_c908:
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
                                     // Instructions:    13
                                     // Expected cycles: 23
                                     // Expected IPC:    0.57
                                     //
                                     // Cycle bound:     23.0
                                     // IPC bound:       0.57
                                     //
                                     // Wall time:     0.17s
                                     // User time:     0.17s
                                     //
                                     // ----- cycle (expected) ------>
                                     // 0                        25
                                     // |------------------------|----
        add x24, x10, x17            // *.............................
        vle16.v v24, (x10)           // *............................. // @slothy:lmul=8
        vle16.v v0, (x24)            // ..*........................... // @slothy:lmul=8
        vmulh.vx v8, v24, x16        // ....*......................... // @slothy:lmul=8
        vmulh.vx v16, v0, x16        // ......*....................... // @slothy:lmul=8
        vssra.vi v8, v8, 10          // ........*..................... // @slothy:lmul=8
        vssra.vi v16, v16, 10        // ..........*................... // @slothy:lmul=8
        vmul.vx v8, v8, x5           // ............*................. // @slothy:lmul=8
        vmul.vx v16, v16, x5         // ..............*............... // @slothy:lmul=8
        vsub.vv v24, v24, v8         // ................*............. // @slothy:lmul=8
        vsub.vv v8, v0, v16          // ..................*........... // @slothy:lmul=8
        vse16.v v24, (x10)           // ....................*......... // @slothy:lmul=8
        vse16.v v8, (x24)            // ......................*....... // @slothy:lmul=8

                                      // ------ cycle (expected) ------>
                                      // 0                        25
                                      // |------------------------|-----
        // add x11, x10, x17          // *..............................
        // vle16.v v0,  (x10)         // *..............................
        // vle16.v v8,  (x11)         // ..*............................
        // vmulh.vx v16, v0, x16      // ....*..........................
        // vssra.vi v16, v16, 10      // ........*......................
        // vmul.vx  v16, v16, x5      // ............*..................
        // vsub.vv  v0,  v0, v16      // ................*..............
        // vmulh.vx v24, v8, x16      // ......*........................
        // vssra.vi v24, v24, 10      // ..........*....................
        // vmul.vx  v24, v24, x5      // ..............*................
        // vsub.vv  v8,  v8, v24      // ..................*............
        // vse16.v v0,  (x10)         // ....................*..........
        // vse16.v v8,  (x11)         // ......................*........

        addi a0, a0, 256
        bltu a0, t4, poly_reduce_rvv_vlen128_loop
    restore_regs
    addi sp, sp, 8*15
ret
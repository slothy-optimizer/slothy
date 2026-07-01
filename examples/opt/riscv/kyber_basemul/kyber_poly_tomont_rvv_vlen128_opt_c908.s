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

.globl poly_tomont_rvv_vlen128_opt_c908
.align 2
poly_tomont_rvv_vlen128_opt_c908:
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
    addi  t4, a0, 256*2
                                  // Instructions:    1
                                  // Expected cycles: 1
                                  // Expected IPC:    1.00
                                  //
                                  // Cycle bound:     1.0
                                  // IPC bound:       1.00
                                  //
                                  // Wall time:     4.51s
                                  // User time:     4.51s
                                  //
                                  // ----- cycle (expected) ------>
                                  // 0                        25
                                  // |------------------------|----
        vle16.v v24, (x10)        // *............................. // @slothy:lmul=8

                                   // ------ cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|-----
        // vle16.v v24, (x10)      // *..............................

        sub t4, t4, t3
poly_tomont_rvv_vlen128_loop:
                                                           // Instructions:    15
                                                           // Expected cycles: 23
                                                           // Expected IPC:    0.65
                                                           //
                                                           // Cycle bound:     9.0
                                                           // IPC bound:       1.67
                                                           //
                                                           // Wall time:     5.06s
                                                           // User time:     5.06s
                                                           //
                                                           // ----- cycle (expected) ------>
                                                           // 0                        25
                                                           // |------------------------|----
        add x31, x10, x17                                  // *.............................
        vmulh.vx v16, v24, x6                              // *............................. // @slothy:lmul=8
        vle16.v v0, (x31)                                  // .*............................ // @slothy:lmul=8
        vmul.vx v8, v0, x7                                 // ....*......................... // @slothy:lmul=8
        vmul.vx v24, v24, x7                               // ......*....................... // @slothy:lmul=8
        vmulh.vx v8, v8, x5                                // ........*..................... // @slothy:lmul=8
        vmulh.vx v24, v24, x5                              // ..........*................... // @slothy:lmul=8
        vmulh.vx v0, v0, x6                                // ............*................. // @slothy:lmul=8
        vsub.vv v16, v16, v24                              // ..............*............... // @slothy:lmul=8
        vsub.vv v0, v0, v8                                 // ................*............. // @slothy:lmul=8
        vse16.v v16, (x10)                                 // ..................*........... // @slothy:lmul=8
        add x10, x10, x28                                  // ..................*...........
        vle16.v v24, (x10)                                 // ....................e......... // @slothy:lmul=8
        vse16.v v0, (x31)                                  // ......................*....... // @slothy:lmul=8
        bltu x10, x29, poly_tomont_rvv_vlen128_loop        // ......................*....... // @slothy:branch

                                                            // ------ cycle (expected) ------>
                                                            // 0                        25
                                                            // |------------------------|-----
        // add x11, x10, x17                                // ...*......................~....
        // vle16.v v0,  (x10)                               // e..'...................~..'....
        // vle16.v v8,  (x11)                               // ...'*.....................'~...
        // vmul.vx  v16, v0, x7                             // ...'.....*................'....
        // vmulh.vx v24, v0, x6                             // ...*......................~....
        // vmulh.vx v16, v16, x5                            // ...'.........*............'....
        // vsub.vv  v16, v24, v16                           // ...'.............*........'....
        // vmul.vx  v24, v8, x7                             // ...'...*..................'....
        // vmulh.vx v0, v8, x6                              // ...'...........*..........'....
        // vmulh.vx v24, v24, x5                            // ...'.......*..............'....
        // vsub.vv  v24, v0, v24                            // ...'...............*......'....
        // vse16.v v16, (x10)                               // ...'.................*....'....
        // vse16.v v24, (x11)                               // ..~'.....................*'....
        // add  x10, x10, x28                               // ...'.................*....'....
        // bltu x10, x29, poly_tomont_rvv_vlen128_loop      // ..~'.....................*'....


                                                           // Instructions:    14
                                                           // Expected cycles: 21
                                                           // Expected IPC:    0.67
                                                           //
                                                           // Cycle bound:     21.0
                                                           // IPC bound:       0.67
                                                           //
                                                           // Wall time:     6.26s
                                                           // User time:     6.26s
                                                           //
                                                           // ----- cycle (expected) ------>
                                                           // 0                        25
                                                           // |------------------------|----
        vmulh.vx v8, v24, x6                               // *............................. // @slothy:lmul=8
        add x30, x10, x17                                  // *.............................
        vmul.vx v24, v24, x7                               // ..*........................... // @slothy:lmul=8
        vle16.v v0, (x30)                                  // ...*.......................... // @slothy:lmul=8
        vmulh.vx v16, v0, x6                               // ......*....................... // @slothy:lmul=8
        vmul.vx v0, v0, x7                                 // ........*..................... // @slothy:lmul=8
        vmulh.vx v24, v24, x5                              // ..........*................... // @slothy:lmul=8
        vmulh.vx v0, v0, x5                                // ............*................. // @slothy:lmul=8
        vsub.vv v24, v8, v24                               // ..............*............... // @slothy:lmul=8
        vsub.vv v8, v16, v0                                // ................*............. // @slothy:lmul=8
        vse16.v v24, (x10)                                 // ..................*........... // @slothy:lmul=8
        add x10, x10, x28                                  // ...................*..........
        vse16.v v8, (x30)                                  // ....................*......... // @slothy:lmul=8

                                                            // ------ cycle (expected) ------>
                                                            // 0                        25
                                                            // |------------------------|-----
        // add x31, x10, x17                                // *..............................
        // vmulh.vx v16, v24, x6                            // *..............................
        // vle16.v v0, (x31)                                // ...*...........................
        // vmul.vx v8, v0, x7                               // ........*......................
        // vmul.vx v24, v24, x7                             // ..*............................
        // vmulh.vx v8, v8, x5                              // ............*..................
        // vmulh.vx v24, v24, x5                            // ..........*....................
        // vmulh.vx v0, v0, x6                              // ......*........................
        // vsub.vv v16, v16, v24                            // ..............*................
        // vsub.vv v0, v0, v8                               // ................*..............
        // vse16.v v16, (x10)                               // ..................*............
        // add x10, x10, x28                                // ...................*...........
        // vse16.v v0, (x31)                                // ....................*..........
        // bltu x10, x29, poly_tomont_rvv_vlen128_loop      // ....................*..........

    restore_regs
    addi sp, sp, 8*15
ret
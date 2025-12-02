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
test_opt_c908:
    // raw boilerplate code: 38 cycles
    addi sp, sp, -8*15
    save_regs
    nop
    nop
    nop
    nop
    .rept 100
        start_label:
                              // Instructions:    1
                              // Expected cycles: 1
                              // Expected IPC:    1.00
                              //
                              // Cycle bound:     1.0
                              // IPC bound:       1.00
                              //
                              // Wall time:     0.00s
                              // User time:     0.00s
                              //
                              // ----- cycle (expected) ------>
                              // 0                        25
                              // |------------------------|----
        add x0, x0, x0        // *.............................

                               // ------ cycle (expected) ------>
                               // 0                        25
                               // |------------------------|-----
        // add x0, x0, x0      // *..............................

        end_label:

    .endr
    nop
    nop
    nop
    nop
    restore_regs
    addi sp, sp, 8*15
    ret
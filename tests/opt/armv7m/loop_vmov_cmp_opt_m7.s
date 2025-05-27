/* For example, r5 represents an address where we will stop iterating and r6 is
the actual pointer which is incremented inside the loop. */

mov.w r6, #0
add.w r5, r6, #64
vmov s0, r5

start:
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
        add r6, r6, #4        // *.............................

                               // ------ cycle (expected) ------>
                               // 0                        25
                               // |------------------------|-----
        // add r6, r6, #4      // *..............................

        vmov r5, s0
        cmp r6, r5
        bne start
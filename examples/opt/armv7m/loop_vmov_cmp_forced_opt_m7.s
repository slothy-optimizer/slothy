/* For example, r5 represents an address where we will stop iterating and r6 is
the actual pointer which is incremented inside the loop.

In this specific example, the vmov shall not be accounted towards the loop
boundary but rather the body. */

mov.w r6, #0
add.w r5, r6, #64
vmov s0, r5

1:
                              // Instructions:    2
                              // Expected cycles: 1
                              // Expected IPC:    2.00
                              //
                              // Cycle bound:     1.0
                              // IPC bound:       2.00
                              //
                              // Wall time:     0.00s
                              // User time:     0.00s
                              //
                              // ----- cycle (expected) ------>
                              // 0                        25
                              // |------------------------|----
        add r6, r6, #4        // *.............................
        vmov r5, s0           // *.............................

                               // ------ cycle (expected) ------>
                               // 0                        25
                               // |------------------------|-----
        // add r6, r6, #4      // *..............................
        // vmov r5, s0         // *..............................

        cmp r6, r5
        bne 1b
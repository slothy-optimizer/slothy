count .req x2

mov count, #16
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
        nop        // *.............................

                    // ------ cycle (expected) ------>
                    // 0                        25
                    // |------------------------|-----
        // nop      // *..............................

        subs count, count, 1
        cbnz count, start

/* start2-loop is semantically incorrect */
start2:

    nop

    subs count, count, #1
    cbz count, start2

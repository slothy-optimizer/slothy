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
                   // Wall time:     0.01s
                   // User time:     0.01s
                   //
                   // ----- cycle (expected) ------>
                   // 0                        25
                   // |------------------------|----
        nop        // *.............................

                    // ------ cycle (expected) ------>
                    // 0                        25
                    // |------------------------|-----
        // nop      // *..............................

        sub count, count, 1
        cbnz count, start

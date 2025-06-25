        start:
                                               // Instructions:    3
                                               // Expected cycles: 3
                                               // Expected IPC:    1.00
                                               //
                                               // Cycle bound:     3.0
                                               // IPC bound:       1.00
                                               //
                                               // Wall time:     0.01s
                                               // User time:     0.01s
                                               //
                                               // ----- cycle (expected) ------>
                                               // 0                        25
                                               // |------------------------|----
        vsetvli x1, x2, e32, m1, tu, mu        // *.............................
        vsetivli x2, 4, e32, m1, tu, mu        // *.............................
        vsetvl x3, x4, x5                      // ..*...........................

                                                // ------ cycle (expected) ------>
                                                // 0                        25
                                                // |------------------------|-----
        // vsetvli x1, x2, e32, m1, tu, mu      // *..............................
        // vsetivli x2, 4, e32, m1, tu, mu      // *..............................
        // vsetvl x3, x4, x5                    // ..*............................

        end:

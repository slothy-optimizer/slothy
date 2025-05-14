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
        vle16.v v0, 0(x0), v0.t        // *.............................

                                        // ------ cycle (expected) ------>
                                        // 0                        25
                                        // |------------------------|-----
        // vle16.v v0, 0(x0), v0.t      // *..............................

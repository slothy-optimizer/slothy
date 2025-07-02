        start:
                                  // Instructions:    1
                                  // Expected cycles: 1
                                  // Expected IPC:    1.00
                                  //
                                  // Cycle bound:     1.0
                                  // IPC bound:       1.00
                                  //
                                  // Wall time:     0.04s
                                  // User time:     0.04s
                                  //
                                  // ----- cycle (expected) ------>
                                  // 0                        25
                                  // |------------------------|----
        vs8r.v v4, (X<v5>)        // *.............................

                                 // ------ cycle (expected) ------>
                                 // 0                        25
                                 // |------------------------|-----
        // vs8r.v v4, (x16)      // *..............................

        end:

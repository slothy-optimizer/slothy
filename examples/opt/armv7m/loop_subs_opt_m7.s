movw r5, #16
start:
                // Instructions:    0
                // Expected cycles: 0
                // Expected IPC:    0.00
                //
                // Wall time:     0.02s
                // User time:     0.02s
                //
        subs r5, #1
        bne start

movw r5, #16
                // Instructions:    0
                // Expected cycles: 0
                // Expected IPC:    0.00
                //
                // Wall time:     0.00s
                // User time:     0.00s
                //
start2:
                                 // Instructions:    4
                                 // Expected cycles: 4
                                 // Expected IPC:    1.00
                                 //
                                 // Cycle bound:     2.0
                                 // IPC bound:       2.00
                                 //
                                 // Wall time:     0.03s
                                 // User time:     0.03s
                                 //
                                 // ----- cycle (expected) ------>
                                 // 0                        25
                                 // |------------------------|----
        subs.w r5, r5, #1        // *.............................
        eor.w r0, r0, r7         // *.............................
        mul r1, r0, r8           // .*............................
        eor.w r0, r1, r4         // ...*..........................

                                  // ------ cycle (expected) ------>
                                  // 0                        25
                                  // |------------------------|-----
        // eor.w r0, r0, r7       // *...~...~...~...~...~...~...~..
        // mul r1, r0, r8         // .*..'~..'~..'~..'~..'~..'~..'~.
        // eor.w r0, r1, r4       // ...*'..~'..~'..~'..~'..~'..~'..
        // subs.w r5, r5, #1      // *...~...~...~...~...~...~...~..

        bne start2
                // Instructions:    0
                // Expected cycles: 0
                // Expected IPC:    0.00
                //
                // Wall time:     0.00s
                // User time:     0.00s
                //
                // Instructions:    0
                // Expected cycles: 0
                // Expected IPC:    0.00
                //
                // Wall time:     0.00s
                // User time:     0.00s
                //
.p2align 2
start:
                                   // Instructions:    4
                                   // Expected cycles: 7
                                   // Expected IPC:    0.57
                                   //
                                   // Wall time:     0.10s
                                   // User time:     0.10s
                                   //
                                   // ----- cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|----
        vldrw.u32 q2, [r0]         // ..*...........................
        vmla.s32 q2, q1, r9        // ...*..........................
        vmla.s32 q2, q1, r9        // .....*........................
        vstrw.u32 q2, [r1]         // ......*.......................

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // vldrw.u32  q0, [r0]           // *......~......~......~......~..
        // vmla.s32   q0, q1, const      // .*.....'~.....'~.....'~.....'~.
        // vmla.s32   q0, q1, const      // ...*...'..~...'..~...'..~...'..
        // vstrw.u32  q0, [r1]           // ....*..'...~..'...~..'...~..'..

        le lr, start
                // Instructions:    0
                // Expected cycles: 0
                // Expected IPC:    0.00
                //
                // Wall time:     0.00s
                // User time:     0.00s
                //

 .equ dist, 16

        start:
                                                // Instructions:    20
                                                // Expected cycles: 28
                                                // Expected IPC:    0.71
                                                //
                                                // Cycle bound:     28.0
                                                // IPC bound:       0.71
                                                //
                                                // Wall time:     0.25s
                                                // User time:     0.25s
                                                //
                                                // ----- cycle (expected) ------>
                                                // 0                        25
                                                // |------------------------|----
        ldr q0, [x1, #0]                        // *.............................
        ldr q7, [x0, #16]                       // ..*...........................
        ldr q13, [x2, #0]                       // ....*.........................
        ldr q24, [x0, #48]                      // ......*.......................
        mul v30.8H, v7.8H, v0.H[0]              // ........*.....................
        sqrdmulh v14.8H, v7.8H, v0.H[1]         // .........*....................
        sqrdmulh v27.8H, v24.8H, v0.H[1]        // ..........*...................
        mul v20.8H, v24.8H, v0.H[0]             // ...........*..................
        ldr q17, [x0]                           // ............*.................
        mls v30.8H, v14.8H, v13.H[0]            // ..............*...............
        mls v20.8H, v27.8H, v13.H[0]            // ...............*..............
        ldr q13, [x0, #32]                      // ................*.............
        sub v10.8H, v17.8H, v30.8H              // ..................*...........
        add v27.8H, v17.8H, v30.8H              // ...................*..........
        sub v0.8H, v13.8H, v20.8H               // ....................*.........
        str q10, [x0, #16]                      // .....................*........
        add v8.8H, v13.8H, v20.8H               // ......................*.......
        str q0, [x0, #48]                       // .......................*......
        str q27, [x0], #4*16                    // .........................*....
        str q8, [x0, #-32]                      // ...........................*..

                                                  // ------ cycle (expected) ------>
                                                  // 0                        25
                                                  // |------------------------|-----
        // ldr q0, [x1, #0]                       // *..............................
        // ldr q1, [x2, #0]                       // ....*..........................
        // ldr q8,  [x0]                          // ............*..................
        // ldr q9,  [x0, #1*16]                   // ..*............................
        // ldr q10, [x0, #2*16]                   // ................*..............
        // ldr q11, [x0, #3*16]                   // ......*........................
        // mul v24.8h, v9.8h, v0.h[0]             // ........*......................
        // sqrdmulh v9.8h, v9.8h, v0.h[1]         // .........*.....................
        // mls v24.8h, v9.8h, v1.h[0]             // ..............*................
        // sub     v9.8h,    v8.8h, v24.8h        // ..................*............
        // add     v8.8h,    v8.8h, v24.8h        // ...................*...........
        // mul v24.8h, v11.8h, v0.h[0]            // ...........*...................
        // sqrdmulh v11.8h, v11.8h, v0.h[1]       // ..........*....................
        // mls v24.8h, v11.8h, v1.h[0]            // ...............*...............
        // sub     v11.8h,    v10.8h, v24.8h      // ....................*..........
        // add     v10.8h,    v10.8h, v24.8h      // ......................*........
        // str q8,  [x0], #4*16                   // .........................*.....
        // str q9,  [x0, #-3*16]                  // .....................*.........
        // str q10, [x0, #-2*16]                  // ...........................*...
        // str q11, [x0, #-1*16]                  // .......................*.......

        end:

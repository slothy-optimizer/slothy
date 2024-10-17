.syntax unified
.thumb

.macro caddq a, tmp, q
    and     \tmp, \q, \a, asr #31
    add     \a, \a, \tmp
.endm

// void asm_caddq(int32_t a[N]);
.global pqcrystals_dilithium_asm_caddq_opt_m7
.type pqcrystals_dilithium_asm_caddq_opt_m7, %function
.align 2
pqcrystals_dilithium_asm_caddq_opt_m7:
    push {r4-r11}

    movw r12,#:lower16:8380417
    movt r12,#:upper16:8380417

    movw r10, #32
    1:
        caddq_start:
                                         // Instructions:    33
                                         // Expected cycles: 20
                                         // Expected IPC:    1.65
                                         //
                                         // Wall time:     0.36s
                                         // User time:     0.36s
                                         //
                                         // ----- cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|----
        ldr.w r11, [r0, #7*4]            // *.............................
        ldr.w r6, [r0, #1*4]             // *.............................
        ldr.w r1, [r0, #3*4]             // .*............................
        ldr.w r5, [r0, #2*4]             // .*............................
        ldr.w r4, [r0, #6*4]             // ..*...........................
        ldr.w r3, [r0, #4*4]             // ..*...........................
        and r2, r12, r6, asr #31         // ...*..........................
        and r8, r12, r11, asr #31        // ...*..........................
        add r9, r6, r2                   // ....*.........................
        and r2, r12, r5, asr #31         // ....*.........................
        add r5, r5, r2                   // .....*........................
        str.w r9, [r0, #1*4]             // .....*........................
        and r2, r12, r1, asr #31         // ......*.......................
        add r8, r11, r8                  // ......*.......................
        ldr.w r6, [r0, #5*4]             // .......*......................
        str.w r5, [r0, #2*4]             // .......*......................
        and r11, r12, r3, asr #31        // ........*.....................
        add r2, r1, r2                   // ........*.....................
        and r5, r12, r4, asr #31         // .........*....................
        str.w r2, [r0, #3*4]             // .........*....................
        and r1, r12, r6, asr #31         // ..........*...................
        add r3, r3, r11                  // ..........*...................
        add r11, r6, r1                  // ...........*..................
        str.w r3, [r0, #4*4]             // ...........*..................
        ldr.w r6, [r0]                   // ............*.................
        add r5, r4, r5                   // ............*.................
        str.w r11, [r0, #5*4]            // .............*................
        and r1, r12, r6, asr #31         // ...............*..............
        str.w r8, [r0, #7*4]             // ...............*..............
        str.w r5, [r0, #6*4]             // .................*............
        add r8, r6, r1                   // ..................*...........
        subs r10, #1                     // ...................*..........
        str r8, [r0], #8*4               // ...................*..........

                                             // ------ cycle (expected) ------>
                                             // 0                        25
                                             // |------------------------|-----
        // ldr.w r1, [r0]                    // ............*..................
        // ldr.w r2, [r0, #1*4]              // *..............................
        // ldr.w r3, [r0, #2*4]              // .*.............................
        // ldr.w r4, [r0, #3*4]              // .*.............................
        // ldr.w r5, [r0, #4*4]              // ..*............................
        // ldr.w r6, [r0, #5*4]              // .......*.......................
        // ldr.w r7, [r0, #6*4]              // ..*............................
        // ldr.w r8, [r0, #7*4]              // *..............................
        // and     r9, r12, r1, asr #31      // ...............*...............
        // add     r1, r1, r9                // ..................*............
        // and     r9, r12, r2, asr #31      // ...*...........................
        // add     r2, r2, r9                // ....*..........................
        // and     r9, r12, r3, asr #31      // ....*..........................
        // add     r3, r3, r9                // .....*.........................
        // and     r9, r12, r4, asr #31      // ......*........................
        // add     r4, r4, r9                // ........*......................
        // and     r9, r12, r5, asr #31      // ........*......................
        // add     r5, r5, r9                // ..........*....................
        // and     r9, r12, r6, asr #31      // ..........*....................
        // add     r6, r6, r9                // ...........*...................
        // and     r9, r12, r7, asr #31      // .........*.....................
        // add     r7, r7, r9                // ............*..................
        // and     r9, r12, r8, asr #31      // ...*...........................
        // add     r8, r8, r9                // ......*........................
        // str.w r2, [r0, #1*4]              // .....*.........................
        // str.w r3, [r0, #2*4]              // .......*.......................
        // str.w r4, [r0, #3*4]              // .........*.....................
        // str.w r5, [r0, #4*4]              // ...........*...................
        // str.w r6, [r0, #5*4]              // .............*.................
        // str.w r7, [r0, #6*4]              // .................*.............
        // str.w r8, [r0, #7*4]              // ...............*...............
        // str r1, [r0], #8*4                // ...................*...........
        // subs r10, #1                      // ...................*...........

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      3300
        // Total Cycles:      2201
        // Total uOps:        3300
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.50
        // IPC:               1.50
        // Block RThroughput: 16.5
        //
        //
        // Cycles with backend pressure increase [ 31.80% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 27.26% ]
        //   Data Dependencies:      [ 4.54% ]
        //   - Register Dependencies [ 4.54% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r1, [r0]
        //  1      2     0.50    *                   ldr.w	r2, [r0, #4]
        //  1      2     0.50    *                   ldr.w	r3, [r0, #8]
        //  1      2     0.50    *                   ldr.w	r4, [r0, #12]
        //  1      2     0.50    *                   ldr.w	r5, [r0, #16]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #20]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #28]
        //  1      1     1.00                        and.w	r9, r12, r1, asr #31
        //  1      1     0.50                        add	r1, r9
        //  1      1     1.00                        and.w	r9, r12, r2, asr #31
        //  1      1     0.50                        add	r2, r9
        //  1      1     1.00                        and.w	r9, r12, r3, asr #31
        //  1      1     0.50                        add	r3, r9
        //  1      1     1.00                        and.w	r9, r12, r4, asr #31
        //  1      1     0.50                        add	r4, r9
        //  1      1     1.00                        and.w	r9, r12, r5, asr #31
        //  1      1     0.50                        add	r5, r9
        //  1      1     1.00                        and.w	r9, r12, r6, asr #31
        //  1      1     0.50                        add	r6, r9
        //  1      1     1.00                        and.w	r9, r12, r7, asr #31
        //  1      1     0.50                        add	r7, r9
        //  1      1     1.00                        and.w	r9, r12, r8, asr #31
        //  1      1     0.50                        add	r8, r9
        //  1      3     1.00           *            str.w	r2, [r0, #4]
        //  1      3     1.00           *            str.w	r3, [r0, #8]
        //  1      3     1.00           *            str.w	r4, [r0, #12]
        //  1      3     1.00           *            str.w	r5, [r0, #16]
        //  1      3     1.00           *            str.w	r6, [r0, #20]
        //  1      3     1.00           *            str.w	r7, [r0, #24]
        //  1      3     1.00           *            str.w	r8, [r0, #28]
        //  1      3     1.00           *            str	r1, [r0], #32
        //  1      1     0.50                        subs.w	r10, r10, #1
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      100  (4.5%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 600  (27.3%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              200  (9.1%)
        //  1,              702  (31.9%)
        //  2,              1299  (59.0%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          200  (9.1%)
        //  1,          702  (31.9%)
        //  2,          1299  (59.0%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    2700
        // Max number of mappings used:         4
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 8.50   8.50    -     4.00   4.00    -      -     8.00    -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r1, [r0]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r2, [r0, #4]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r3, [r0, #8]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #12]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #16]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #20]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #24]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #28]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r1, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r1, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r2, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r2, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r3, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r3, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r4, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r4, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r5, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r5, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r6, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r6, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r7, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r7, r9
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r9, r12, r8, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r8, r9
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r2, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r3, [r0, #8]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r4, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #16]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #20]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r7, [r0, #24]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #28]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0], #32
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     subs.w	r10, r10, #1
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #4]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r3, [r0, #8]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #12]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #16]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #20]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #24]
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #28]
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r1, asr #31
        // [0,9]     .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   add	r1, r9
        // [0,10]    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r2, asr #31
        // [0,11]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   add	r2, r9
        // [0,12]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r3, asr #31
        // [0,13]    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   add	r3, r9
        // [0,14]    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r4, asr #31
        // [0,15]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   add	r4, r9
        // [0,16]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r5, asr #31
        // [0,17]    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r9
        // [0,18]    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r6, asr #31
        // [0,19]    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   add	r6, r9
        // [0,20]    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r7, asr #31
        // [0,21]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   add	r7, r9
        // [0,22]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   and.w	r9, r12, r8, asr #31
        // [0,23]    .    .    . DE .    .    .    .    .    .    .    .    .    .    ..   add	r8, r9
        // [0,24]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    ..   str.w	r2, [r0, #4]
        // [0,25]    .    .    .  DeE    .    .    .    .    .    .    .    .    .    ..   str.w	r3, [r0, #8]
        // [0,26]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    ..   str.w	r4, [r0, #12]
        // [0,27]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    ..   str.w	r5, [r0, #16]
        // [0,28]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    ..   str.w	r6, [r0, #20]
        // [0,29]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    ..   str.w	r7, [r0, #24]
        // [0,30]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    ..   str.w	r8, [r0, #28]
        // [0,31]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    ..   str	r1, [r0], #32
        // [0,32]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   subs.w	r10, r10, #1
        // [1,0]     .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0]
        // [1,1]     .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #4]
        // [1,2]     .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr.w	r3, [r0, #8]
        // [1,3]     .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #12]
        // [1,4]     .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #16]
        // [1,5]     .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #20]
        // [1,6]     .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #24]
        // [1,7]     .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #28]
        // [1,8]     .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   and.w	r9, r12, r1, asr #31
        // [1,9]     .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   add	r1, r9
        // [1,10]    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   and.w	r9, r12, r2, asr #31
        // [1,11]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   add	r2, r9
        // [1,12]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   and.w	r9, r12, r3, asr #31
        // [1,13]    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   add	r3, r9
        // [1,14]    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   and.w	r9, r12, r4, asr #31
        // [1,15]    .    .    .    .    .    .    DE   .    .    .    .    .    .    ..   add	r4, r9
        // [1,16]    .    .    .    .    .    .    DE   .    .    .    .    .    .    ..   and.w	r9, r12, r5, asr #31
        // [1,17]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   add	r5, r9
        // [1,18]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   and.w	r9, r12, r6, asr #31
        // [1,19]    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   add	r6, r9
        // [1,20]    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   and.w	r9, r12, r7, asr #31
        // [1,21]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   add	r7, r9
        // [1,22]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   and.w	r9, r12, r8, asr #31
        // [1,23]    .    .    .    .    .    .    .   DE    .    .    .    .    .    ..   add	r8, r9
        // [1,24]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    ..   str.w	r2, [r0, #4]
        // [1,25]    .    .    .    .    .    .    .    DeE  .    .    .    .    .    ..   str.w	r3, [r0, #8]
        // [1,26]    .    .    .    .    .    .    .    .DeE .    .    .    .    .    ..   str.w	r4, [r0, #12]
        // [1,27]    .    .    .    .    .    .    .    . DeE.    .    .    .    .    ..   str.w	r5, [r0, #16]
        // [1,28]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    ..   str.w	r6, [r0, #20]
        // [1,29]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    ..   str.w	r7, [r0, #24]
        // [1,30]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    ..   str.w	r8, [r0, #28]
        // [1,31]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    ..   str	r1, [r0], #32
        // [1,32]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    ..   subs.w	r10, r10, #1
        // [2,0]     .    .    .    .    .    .    .    .    .  DE.    .    .    .    ..   ldr.w	r1, [r0]
        // [2,1]     .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   ldr.w	r2, [r0, #4]
        // [2,2]     .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   ldr.w	r3, [r0, #8]
        // [2,3]     .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r4, [r0, #12]
        // [2,4]     .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r5, [r0, #16]
        // [2,5]     .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr.w	r6, [r0, #20]
        // [2,6]     .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr.w	r7, [r0, #24]
        // [2,7]     .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   ldr.w	r8, [r0, #28]
        // [2,8]     .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   and.w	r9, r12, r1, asr #31
        // [2,9]     .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   add	r1, r9
        // [2,10]    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   and.w	r9, r12, r2, asr #31
        // [2,11]    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   add	r2, r9
        // [2,12]    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   and.w	r9, r12, r3, asr #31
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   add	r3, r9
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   and.w	r9, r12, r4, asr #31
        // [2,15]    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   add	r4, r9
        // [2,16]    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   and.w	r9, r12, r5, asr #31
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   add	r5, r9
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   and.w	r9, r12, r6, asr #31
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   add	r6, r9
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   and.w	r9, r12, r7, asr #31
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   add	r7, r9
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   and.w	r9, r12, r8, asr #31
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    ..   add	r8, r9
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    ..   str.w	r2, [r0, #4]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    ..   str.w	r3, [r0, #8]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .  DeE    ..   str.w	r4, [r0, #12]
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .   DeE   ..   str.w	r5, [r0, #16]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  ..   str.w	r6, [r0, #20]
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE ..   str.w	r7, [r0, #24]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE..   str.w	r8, [r0, #28]
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   str	r1, [r0], #32
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   subs.w	r10, r10, #1
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r1, [r0]
        // 1.     3     0.0    0.0    0.0       ldr.w	r2, [r0, #4]
        // 2.     3     0.0    0.0    0.0       ldr.w	r3, [r0, #8]
        // 3.     3     0.0    0.0    0.0       ldr.w	r4, [r0, #12]
        // 4.     3     0.0    0.0    0.0       ldr.w	r5, [r0, #16]
        // 5.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #20]
        // 6.     3     0.0    0.0    0.0       ldr.w	r7, [r0, #24]
        // 7.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #28]
        // 8.     3     0.0    0.0    0.0       and.w	r9, r12, r1, asr #31
        // 9.     3     0.0    0.0    0.0       add	r1, r9
        // 10.    3     0.0    0.0    0.0       and.w	r9, r12, r2, asr #31
        // 11.    3     0.0    0.0    0.0       add	r2, r9
        // 12.    3     0.0    0.0    0.0       and.w	r9, r12, r3, asr #31
        // 13.    3     0.0    0.0    0.0       add	r3, r9
        // 14.    3     0.0    0.0    0.0       and.w	r9, r12, r4, asr #31
        // 15.    3     0.0    0.0    0.0       add	r4, r9
        // 16.    3     0.0    0.0    0.0       and.w	r9, r12, r5, asr #31
        // 17.    3     0.0    0.0    0.0       add	r5, r9
        // 18.    3     0.0    0.0    0.0       and.w	r9, r12, r6, asr #31
        // 19.    3     0.0    0.0    0.0       add	r6, r9
        // 20.    3     0.0    0.0    0.0       and.w	r9, r12, r7, asr #31
        // 21.    3     0.0    0.0    0.0       add	r7, r9
        // 22.    3     0.0    0.0    0.0       and.w	r9, r12, r8, asr #31
        // 23.    3     0.0    0.0    0.0       add	r8, r9
        // 24.    3     0.0    0.0    0.0       str.w	r2, [r0, #4]
        // 25.    3     0.0    0.0    0.0       str.w	r3, [r0, #8]
        // 26.    3     0.0    0.0    0.0       str.w	r4, [r0, #12]
        // 27.    3     0.0    0.0    0.0       str.w	r5, [r0, #16]
        // 28.    3     0.0    0.0    0.0       str.w	r6, [r0, #20]
        // 29.    3     0.0    0.0    0.0       str.w	r7, [r0, #24]
        // 30.    3     0.0    0.0    0.0       str.w	r8, [r0, #28]
        // 31.    3     0.0    0.0    0.0       str	r1, [r0], #32
        // 32.    3     0.0    0.0    0.0       subs.w	r10, r10, #1
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (ORIGINAL) END
        //
        //
        // LLVM MCA STATISTICS (OPTIMIZED) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      3300
        // Total Cycles:      2001
        // Total uOps:        3300
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.65
        // IPC:               1.65
        // Block RThroughput: 16.5
        //
        //
        // Cycles with backend pressure increase [ 19.89% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 5.00% ]
        //   Data Dependencies:      [ 14.89% ]
        //   - Register Dependencies [ 14.89% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r11, [r0, #28]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #4]
        //  1      2     0.50    *                   ldr.w	r1, [r0, #12]
        //  1      2     0.50    *                   ldr.w	r5, [r0, #8]
        //  1      2     0.50    *                   ldr.w	r4, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r3, [r0, #16]
        //  1      1     1.00                        and.w	r2, r12, r6, asr #31
        //  1      1     1.00                        and.w	r8, r12, r11, asr #31
        //  1      1     0.50                        add.w	r9, r6, r2
        //  1      1     1.00                        and.w	r2, r12, r5, asr #31
        //  1      1     0.50                        add	r5, r2
        //  1      3     1.00           *            str.w	r9, [r0, #4]
        //  1      1     1.00                        and.w	r2, r12, r1, asr #31
        //  1      1     0.50                        add	r8, r11
        //  1      2     0.50    *                   ldr.w	r6, [r0, #20]
        //  1      3     1.00           *            str.w	r5, [r0, #8]
        //  1      1     1.00                        and.w	r11, r12, r3, asr #31
        //  1      1     0.50                        add	r2, r1
        //  1      1     1.00                        and.w	r5, r12, r4, asr #31
        //  1      3     1.00           *            str.w	r2, [r0, #12]
        //  1      1     1.00                        and.w	r1, r12, r6, asr #31
        //  1      1     0.50                        add	r3, r11
        //  1      1     0.50                        add.w	r11, r6, r1
        //  1      3     1.00           *            str.w	r3, [r0, #16]
        //  1      2     0.50    *                   ldr.w	r6, [r0]
        //  1      1     0.50                        add	r5, r4
        //  1      3     1.00           *            str.w	r11, [r0, #20]
        //  1      1     1.00                        and.w	r1, r12, r6, asr #31
        //  1      3     1.00           *            str.w	r8, [r0, #28]
        //  1      3     1.00           *            str.w	r5, [r0, #24]
        //  1      1     0.50                        add.w	r8, r6, r1
        //  1      1     0.50                        subs.w	r10, r10, #1
        //  1      3     1.00           *            str	r8, [r0], #32
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      298  (14.9%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 100  (5.0%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              101  (5.0%)
        //  1,              500  (25.0%)
        //  2,              1400  (70.0%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          101  (5.0%)
        //  1,          500  (25.0%)
        //  2,          1400  (70.0%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    2700
        // Max number of mappings used:         3
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 8.50   8.50    -     4.00   4.00    -      -     8.00    -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #28]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #4]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #12]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #8]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #24]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r3, [r0, #16]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r2, r12, r6, asr #31
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r8, r12, r11, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add.w	r9, r6, r2
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r2, r12, r5, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r5, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r9, [r0, #4]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r2, r12, r1, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r8, r11
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #20]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #8]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r11, r12, r3, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r2, r1
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r5, r12, r4, asr #31
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r2, [r0, #12]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r1, r12, r6, asr #31
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r3, r11
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add.w	r11, r6, r1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r3, [r0, #16]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0]
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add	r5, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r11, [r0, #20]
        // 0.50   0.50    -      -      -      -      -     1.00    -      -      -      -      -     and.w	r1, r12, r6, asr #31
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #28]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #24]
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     add.w	r8, r6, r1
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     subs.w	r10, r10, #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r8, [r0], #32
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r11, [r0, #28]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r6, [r0, #4]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r1, [r0, #12]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r5, [r0, #8]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r4, [r0, #24]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r3, [r0, #16]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .   and.w	r2, r12, r6, asr #31
        // [0,7]     .   DE    .    .    .    .    .    .    .    .    .    .    .   and.w	r8, r12, r11, asr #31
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .   add.w	r9, r6, r2
        // [0,9]     .    DE   .    .    .    .    .    .    .    .    .    .    .   and.w	r2, r12, r5, asr #31
        // [0,10]    .    .DE  .    .    .    .    .    .    .    .    .    .    .   add	r5, r2
        // [0,11]    .    .DeE .    .    .    .    .    .    .    .    .    .    .   str.w	r9, [r0, #4]
        // [0,12]    .    . DE .    .    .    .    .    .    .    .    .    .    .   and.w	r2, r12, r1, asr #31
        // [0,13]    .    . DE .    .    .    .    .    .    .    .    .    .    .   add	r8, r11
        // [0,14]    .    .  DE.    .    .    .    .    .    .    .    .    .    .   ldr.w	r6, [r0, #20]
        // [0,15]    .    .  DeE    .    .    .    .    .    .    .    .    .    .   str.w	r5, [r0, #8]
        // [0,16]    .    .   DE    .    .    .    .    .    .    .    .    .    .   and.w	r11, r12, r3, asr #31
        // [0,17]    .    .   DE    .    .    .    .    .    .    .    .    .    .   add	r2, r1
        // [0,18]    .    .    DE   .    .    .    .    .    .    .    .    .    .   and.w	r5, r12, r4, asr #31
        // [0,19]    .    .    DeE  .    .    .    .    .    .    .    .    .    .   str.w	r2, [r0, #12]
        // [0,20]    .    .    .DE  .    .    .    .    .    .    .    .    .    .   and.w	r1, r12, r6, asr #31
        // [0,21]    .    .    .DE  .    .    .    .    .    .    .    .    .    .   add	r3, r11
        // [0,22]    .    .    . DE .    .    .    .    .    .    .    .    .    .   add.w	r11, r6, r1
        // [0,23]    .    .    . DeE.    .    .    .    .    .    .    .    .    .   str.w	r3, [r0, #16]
        // [0,24]    .    .    .  DE.    .    .    .    .    .    .    .    .    .   ldr.w	r6, [r0]
        // [0,25]    .    .    .  DE.    .    .    .    .    .    .    .    .    .   add	r5, r4
        // [0,26]    .    .    .   DeE   .    .    .    .    .    .    .    .    .   str.w	r11, [r0, #20]
        // [0,27]    .    .    .    DE   .    .    .    .    .    .    .    .    .   and.w	r1, r12, r6, asr #31
        // [0,28]    .    .    .    DeE  .    .    .    .    .    .    .    .    .   str.w	r8, [r0, #28]
        // [0,29]    .    .    .    .DeE .    .    .    .    .    .    .    .    .   str.w	r5, [r0, #24]
        // [0,30]    .    .    .    . DE .    .    .    .    .    .    .    .    .   add.w	r8, r6, r1
        // [0,31]    .    .    .    . DE .    .    .    .    .    .    .    .    .   subs.w	r10, r10, #1
        // [0,32]    .    .    .    .  DeE    .    .    .    .    .    .    .    .   str	r8, [r0], #32
        // [1,0]     .    .    .    .   DE    .    .    .    .    .    .    .    .   ldr.w	r11, [r0, #28]
        // [1,1]     .    .    .    .   DE    .    .    .    .    .    .    .    .   ldr.w	r6, [r0, #4]
        // [1,2]     .    .    .    .    .DE  .    .    .    .    .    .    .    .   ldr.w	r1, [r0, #12]
        // [1,3]     .    .    .    .    .DE  .    .    .    .    .    .    .    .   ldr.w	r5, [r0, #8]
        // [1,4]     .    .    .    .    . DE .    .    .    .    .    .    .    .   ldr.w	r4, [r0, #24]
        // [1,5]     .    .    .    .    . DE .    .    .    .    .    .    .    .   ldr.w	r3, [r0, #16]
        // [1,6]     .    .    .    .    .  DE.    .    .    .    .    .    .    .   and.w	r2, r12, r6, asr #31
        // [1,7]     .    .    .    .    .   DE    .    .    .    .    .    .    .   and.w	r8, r12, r11, asr #31
        // [1,8]     .    .    .    .    .   DE    .    .    .    .    .    .    .   add.w	r9, r6, r2
        // [1,9]     .    .    .    .    .    DE   .    .    .    .    .    .    .   and.w	r2, r12, r5, asr #31
        // [1,10]    .    .    .    .    .    .DE  .    .    .    .    .    .    .   add	r5, r2
        // [1,11]    .    .    .    .    .    .DeE .    .    .    .    .    .    .   str.w	r9, [r0, #4]
        // [1,12]    .    .    .    .    .    . DE .    .    .    .    .    .    .   and.w	r2, r12, r1, asr #31
        // [1,13]    .    .    .    .    .    . DE .    .    .    .    .    .    .   add	r8, r11
        // [1,14]    .    .    .    .    .    .  DE.    .    .    .    .    .    .   ldr.w	r6, [r0, #20]
        // [1,15]    .    .    .    .    .    .  DeE    .    .    .    .    .    .   str.w	r5, [r0, #8]
        // [1,16]    .    .    .    .    .    .   DE    .    .    .    .    .    .   and.w	r11, r12, r3, asr #31
        // [1,17]    .    .    .    .    .    .   DE    .    .    .    .    .    .   add	r2, r1
        // [1,18]    .    .    .    .    .    .    DE   .    .    .    .    .    .   and.w	r5, r12, r4, asr #31
        // [1,19]    .    .    .    .    .    .    DeE  .    .    .    .    .    .   str.w	r2, [r0, #12]
        // [1,20]    .    .    .    .    .    .    .DE  .    .    .    .    .    .   and.w	r1, r12, r6, asr #31
        // [1,21]    .    .    .    .    .    .    .DE  .    .    .    .    .    .   add	r3, r11
        // [1,22]    .    .    .    .    .    .    . DE .    .    .    .    .    .   add.w	r11, r6, r1
        // [1,23]    .    .    .    .    .    .    . DeE.    .    .    .    .    .   str.w	r3, [r0, #16]
        // [1,24]    .    .    .    .    .    .    .  DE.    .    .    .    .    .   ldr.w	r6, [r0]
        // [1,25]    .    .    .    .    .    .    .  DE.    .    .    .    .    .   add	r5, r4
        // [1,26]    .    .    .    .    .    .    .   DeE   .    .    .    .    .   str.w	r11, [r0, #20]
        // [1,27]    .    .    .    .    .    .    .    DE   .    .    .    .    .   and.w	r1, r12, r6, asr #31
        // [1,28]    .    .    .    .    .    .    .    DeE  .    .    .    .    .   str.w	r8, [r0, #28]
        // [1,29]    .    .    .    .    .    .    .    .DeE .    .    .    .    .   str.w	r5, [r0, #24]
        // [1,30]    .    .    .    .    .    .    .    . DE .    .    .    .    .   add.w	r8, r6, r1
        // [1,31]    .    .    .    .    .    .    .    . DE .    .    .    .    .   subs.w	r10, r10, #1
        // [1,32]    .    .    .    .    .    .    .    .  DeE    .    .    .    .   str	r8, [r0], #32
        // [2,0]     .    .    .    .    .    .    .    .   DE    .    .    .    .   ldr.w	r11, [r0, #28]
        // [2,1]     .    .    .    .    .    .    .    .   DE    .    .    .    .   ldr.w	r6, [r0, #4]
        // [2,2]     .    .    .    .    .    .    .    .    .DE  .    .    .    .   ldr.w	r1, [r0, #12]
        // [2,3]     .    .    .    .    .    .    .    .    .DE  .    .    .    .   ldr.w	r5, [r0, #8]
        // [2,4]     .    .    .    .    .    .    .    .    . DE .    .    .    .   ldr.w	r4, [r0, #24]
        // [2,5]     .    .    .    .    .    .    .    .    . DE .    .    .    .   ldr.w	r3, [r0, #16]
        // [2,6]     .    .    .    .    .    .    .    .    .  DE.    .    .    .   and.w	r2, r12, r6, asr #31
        // [2,7]     .    .    .    .    .    .    .    .    .   DE    .    .    .   and.w	r8, r12, r11, asr #31
        // [2,8]     .    .    .    .    .    .    .    .    .   DE    .    .    .   add.w	r9, r6, r2
        // [2,9]     .    .    .    .    .    .    .    .    .    DE   .    .    .   and.w	r2, r12, r5, asr #31
        // [2,10]    .    .    .    .    .    .    .    .    .    .DE  .    .    .   add	r5, r2
        // [2,11]    .    .    .    .    .    .    .    .    .    .DeE .    .    .   str.w	r9, [r0, #4]
        // [2,12]    .    .    .    .    .    .    .    .    .    . DE .    .    .   and.w	r2, r12, r1, asr #31
        // [2,13]    .    .    .    .    .    .    .    .    .    . DE .    .    .   add	r8, r11
        // [2,14]    .    .    .    .    .    .    .    .    .    .  DE.    .    .   ldr.w	r6, [r0, #20]
        // [2,15]    .    .    .    .    .    .    .    .    .    .  DeE    .    .   str.w	r5, [r0, #8]
        // [2,16]    .    .    .    .    .    .    .    .    .    .   DE    .    .   and.w	r11, r12, r3, asr #31
        // [2,17]    .    .    .    .    .    .    .    .    .    .   DE    .    .   add	r2, r1
        // [2,18]    .    .    .    .    .    .    .    .    .    .    DE   .    .   and.w	r5, r12, r4, asr #31
        // [2,19]    .    .    .    .    .    .    .    .    .    .    DeE  .    .   str.w	r2, [r0, #12]
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .DE  .    .   and.w	r1, r12, r6, asr #31
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .DE  .    .   add	r3, r11
        // [2,22]    .    .    .    .    .    .    .    .    .    .    . DE .    .   add.w	r11, r6, r1
        // [2,23]    .    .    .    .    .    .    .    .    .    .    . DeE.    .   str.w	r3, [r0, #16]
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .  DE.    .   ldr.w	r6, [r0]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .  DE.    .   add	r5, r4
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .   DeE   .   str.w	r11, [r0, #20]
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    DE   .   and.w	r1, r12, r6, asr #31
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    DeE  .   str.w	r8, [r0, #28]
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .DeE .   str.w	r5, [r0, #24]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    . DE .   add.w	r8, r6, r1
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    . DE .   subs.w	r10, r10, #1
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .  DeE   str	r8, [r0], #32
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #28]
        // 1.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #4]
        // 2.     3     0.0    0.0    0.0       ldr.w	r1, [r0, #12]
        // 3.     3     0.0    0.0    0.0       ldr.w	r5, [r0, #8]
        // 4.     3     0.0    0.0    0.0       ldr.w	r4, [r0, #24]
        // 5.     3     0.0    0.0    0.0       ldr.w	r3, [r0, #16]
        // 6.     3     0.0    0.0    0.0       and.w	r2, r12, r6, asr #31
        // 7.     3     0.0    0.0    0.0       and.w	r8, r12, r11, asr #31
        // 8.     3     0.0    0.0    0.0       add.w	r9, r6, r2
        // 9.     3     0.0    0.0    0.0       and.w	r2, r12, r5, asr #31
        // 10.    3     0.0    0.0    0.0       add	r5, r2
        // 11.    3     0.0    0.0    0.0       str.w	r9, [r0, #4]
        // 12.    3     0.0    0.0    0.0       and.w	r2, r12, r1, asr #31
        // 13.    3     0.0    0.0    0.0       add	r8, r11
        // 14.    3     0.0    0.0    0.0       ldr.w	r6, [r0, #20]
        // 15.    3     0.0    0.0    0.0       str.w	r5, [r0, #8]
        // 16.    3     0.0    0.0    0.0       and.w	r11, r12, r3, asr #31
        // 17.    3     0.0    0.0    0.0       add	r2, r1
        // 18.    3     0.0    0.0    0.0       and.w	r5, r12, r4, asr #31
        // 19.    3     0.0    0.0    0.0       str.w	r2, [r0, #12]
        // 20.    3     0.0    0.0    0.0       and.w	r1, r12, r6, asr #31
        // 21.    3     0.0    0.0    0.0       add	r3, r11
        // 22.    3     0.0    0.0    0.0       add.w	r11, r6, r1
        // 23.    3     0.0    0.0    0.0       str.w	r3, [r0, #16]
        // 24.    3     0.0    0.0    0.0       ldr.w	r6, [r0]
        // 25.    3     0.0    0.0    0.0       add	r5, r4
        // 26.    3     0.0    0.0    0.0       str.w	r11, [r0, #20]
        // 27.    3     0.0    0.0    0.0       and.w	r1, r12, r6, asr #31
        // 28.    3     0.0    0.0    0.0       str.w	r8, [r0, #28]
        // 29.    3     0.0    0.0    0.0       str.w	r5, [r0, #24]
        // 30.    3     0.0    0.0    0.0       add.w	r8, r6, r1
        // 31.    3     0.0    0.0    0.0       subs.w	r10, r10, #1
        // 32.    3     0.0    0.0    0.0       str	r8, [r0], #32
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        caddq_end:

        bne.w 1b

    pop {r4-r11}
    bx lr

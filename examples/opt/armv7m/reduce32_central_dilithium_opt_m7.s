.syntax unified
.thumb

.macro barrett_32 a, Qbar, Q, tmp
    smmulr.w \tmp, \a, \Qbar
    mls.w \a, \tmp, \Q, \a
.endm

// void asm_reduce32(int32_t a[N]);
.global pqcrystals_dilithium_small_asm_reduce32_central_opt_m7
.type pqcrystals_dilithium_small_asm_reduce32_central_opt_m7, %function
.align 2
pqcrystals_dilithium_small_asm_reduce32_central_opt_m7:
    push {r4-r12, lr}


    movw r9, #:lower16:5585133
    movt r9, #:upper16:5585133
    mov.w r10,#769

    movw r12, #32
    1:
        reduce32_central_start:
                                       // Instructions:    33
                                       // Expected cycles: 21
                                       // Expected IPC:    1.57
                                       //
                                       // Wall time:     0.32s
                                       // User time:     0.32s
                                       //
                                       // ----- cycle (expected) ------>
                                       // 0                        25
                                       // |------------------------|----
        subs r12, #1                   // *.............................
        ldr.w r4, [r0, #7*4]           // *.............................
        ldr.w r6, [r0, #6*4]           // .*............................
        ldr.w r11, [r0, #5*4]          // .*............................
        ldr.w r3, [r0, #4*4]           // ..*...........................
        smmulr.w r8, r4, r9            // ..*...........................
        smmulr.w r2, r6, r9            // ...*..........................
        ldr.w r1, [r0, #3*4]           // ...*..........................
        ldr.w r5, [r0, #2*4]           // ....*.........................
        mls.w r4, r8, r10, r4          // ....*.........................
        mls.w r2, r2, r10, r6          // .....*........................
        ldr.w r8, [r0, #1*4]           // .....*........................
        smmulr.w r7, r11, r9           // ......*.......................
        str.w r4, [r0, #7*4]           // ......*.......................
        smmulr.w r4, r3, r9            // .......*......................
        ldr.w r6, [r0]                 // .......*......................
        mls.w r11, r7, r10, r11        // ........*.....................
        str.w r2, [r0, #6*4]           // ........*.....................
        mls.w r3, r4, r10, r3          // .........*....................
        smmulr.w r4, r1, r9            // ..........*...................
        str.w r11, [r0, #5*4]          // ..........*...................
        smmulr.w r11, r5, r9           // ...........*..................
        mls.w r1, r4, r10, r1          // ............*.................
        str.w r3, [r0, #4*4]           // ............*.................
        mls.w r5, r11, r10, r5         // .............*................
        smmulr.w r3, r8, r9            // ..............*...............
        str.w r1, [r0, #3*4]           // ..............*...............
        smmulr.w r1, r6, r9            // ...............*..............
        mls.w r8, r3, r10, r8          // ................*.............
        str.w r5, [r0, #2*4]           // ................*.............
        mls.w r5, r1, r10, r6          // .................*............
        str.w r8, [r0, #1*4]           // ..................*...........
        str r5, [r0], #8*4             // ....................*.........

                                       // ------ cycle (expected) ------>
                                       // 0                        25
                                       // |------------------------|-----
        // ldr.w r1, [r0]              // .......*.......................
        // ldr.w r2, [r0, #1*4]        // .....*.........................
        // ldr.w r3, [r0, #2*4]        // ....*..........................
        // ldr.w r4, [r0, #3*4]        // ...*...........................
        // ldr.w r5, [r0, #4*4]        // ..*............................
        // ldr.w r6, [r0, #5*4]        // .*.............................
        // ldr.w r7, [r0, #6*4]        // .*.............................
        // ldr.w r8, [r0, #7*4]        // *..............................
        // smmulr.w r11, r1, r9        // ...............*...............
        // mls.w r1, r11, r10, r1      // .................*.............
        // smmulr.w r11, r2, r9        // ..............*................
        // mls.w r2, r11, r10, r2      // ................*..............
        // smmulr.w r11, r3, r9        // ...........*...................
        // mls.w r3, r11, r10, r3      // .............*.................
        // smmulr.w r11, r4, r9        // ..........*....................
        // mls.w r4, r11, r10, r4      // ............*..................
        // smmulr.w r11, r5, r9        // .......*.......................
        // mls.w r5, r11, r10, r5      // .........*.....................
        // smmulr.w r11, r6, r9        // ......*........................
        // mls.w r6, r11, r10, r6      // ........*......................
        // smmulr.w r11, r7, r9        // ...*...........................
        // mls.w r7, r11, r10, r7      // .....*.........................
        // smmulr.w r11, r8, r9        // ..*............................
        // mls.w r8, r11, r10, r8      // ....*..........................
        // str.w r2, [r0, #1*4]        // ..................*............
        // str.w r3, [r0, #2*4]        // ................*..............
        // str.w r4, [r0, #3*4]        // ..............*................
        // str.w r5, [r0, #4*4]        // ............*..................
        // str.w r6, [r0, #5*4]        // ..........*....................
        // str.w r7, [r0, #6*4]        // ........*......................
        // str.w r8, [r0, #7*4]        // ......*........................
        // str r1, [r0], #8*4          // ....................*..........
        // subs r12, #1                // *..............................

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      1700
        // Total Cycles:      1401
        // Total uOps:        1700
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.21
        // IPC:               1.21
        // Block RThroughput: 8.5
        //
        //
        // Cycles with backend pressure increase [ 49.96% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 42.90% ]
        //   Data Dependencies:      [ 7.07% ]
        //   - Register Dependencies [ 7.07% ]
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
        //  1      3     1.00           *            str.w	r2, [r0, #4]
        //  1      3     1.00           *            str.w	r3, [r0, #8]
        //  1      3     1.00           *            str.w	r4, [r0, #12]
        //  1      3     1.00           *            str.w	r5, [r0, #16]
        //  1      3     1.00           *            str.w	r6, [r0, #20]
        //  1      3     1.00           *            str.w	r7, [r0, #24]
        //  1      3     1.00           *            str.w	r8, [r0, #28]
        //  1      3     1.00           *            str	r1, [r0], #32
        //  1      1     0.50                        subs.w	r12, r12, #1
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      99  (7.1%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 601  (42.9%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              200  (14.3%)
        //  1,              702  (50.1%)
        //  2,              499  (35.6%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          200  (14.3%)
        //  1,          702  (50.1%)
        //  2,          499  (35.6%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    1100
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
        // 0.50   0.50    -     4.00   4.00    -      -      -      -     8.00    -      -      -
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
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r2, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r3, [r0, #8]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r4, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #16]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #20]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r7, [r0, #24]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #28]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0], #32
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     subs.w	r12, r12, #1
        //
        //
        // Timeline view:
        //                     0123456789          0123456789
        // Index     0123456789          0123456789          012
        //
        // [0,0]     DE   .    .    .    .    .    .    .    . .   ldr.w	r1, [r0]
        // [0,1]     DE   .    .    .    .    .    .    .    . .   ldr.w	r2, [r0, #4]
        // [0,2]     .DE  .    .    .    .    .    .    .    . .   ldr.w	r3, [r0, #8]
        // [0,3]     .DE  .    .    .    .    .    .    .    . .   ldr.w	r4, [r0, #12]
        // [0,4]     . DE .    .    .    .    .    .    .    . .   ldr.w	r5, [r0, #16]
        // [0,5]     . DE .    .    .    .    .    .    .    . .   ldr.w	r6, [r0, #20]
        // [0,6]     .  DE.    .    .    .    .    .    .    . .   ldr.w	r7, [r0, #24]
        // [0,7]     .  DE.    .    .    .    .    .    .    . .   ldr.w	r8, [r0, #28]
        // [0,8]     .   DeE   .    .    .    .    .    .    . .   str.w	r2, [r0, #4]
        // [0,9]     .    DeE  .    .    .    .    .    .    . .   str.w	r3, [r0, #8]
        // [0,10]    .    .DeE .    .    .    .    .    .    . .   str.w	r4, [r0, #12]
        // [0,11]    .    . DeE.    .    .    .    .    .    . .   str.w	r5, [r0, #16]
        // [0,12]    .    .  DeE    .    .    .    .    .    . .   str.w	r6, [r0, #20]
        // [0,13]    .    .   DeE   .    .    .    .    .    . .   str.w	r7, [r0, #24]
        // [0,14]    .    .    DeE  .    .    .    .    .    . .   str.w	r8, [r0, #28]
        // [0,15]    .    .    . DeE.    .    .    .    .    . .   str	r1, [r0], #32
        // [0,16]    .    .    .  DE.    .    .    .    .    . .   subs.w	r12, r12, #1
        // [1,0]     .    .    .  DE.    .    .    .    .    . .   ldr.w	r1, [r0]
        // [1,1]     .    .    .    DE   .    .    .    .    . .   ldr.w	r2, [r0, #4]
        // [1,2]     .    .    .    DE   .    .    .    .    . .   ldr.w	r3, [r0, #8]
        // [1,3]     .    .    .    .DE  .    .    .    .    . .   ldr.w	r4, [r0, #12]
        // [1,4]     .    .    .    .DE  .    .    .    .    . .   ldr.w	r5, [r0, #16]
        // [1,5]     .    .    .    . DE .    .    .    .    . .   ldr.w	r6, [r0, #20]
        // [1,6]     .    .    .    . DE .    .    .    .    . .   ldr.w	r7, [r0, #24]
        // [1,7]     .    .    .    .  DE.    .    .    .    . .   ldr.w	r8, [r0, #28]
        // [1,8]     .    .    .    .  DeE    .    .    .    . .   str.w	r2, [r0, #4]
        // [1,9]     .    .    .    .   DeE   .    .    .    . .   str.w	r3, [r0, #8]
        // [1,10]    .    .    .    .    DeE  .    .    .    . .   str.w	r4, [r0, #12]
        // [1,11]    .    .    .    .    .DeE .    .    .    . .   str.w	r5, [r0, #16]
        // [1,12]    .    .    .    .    . DeE.    .    .    . .   str.w	r6, [r0, #20]
        // [1,13]    .    .    .    .    .  DeE    .    .    . .   str.w	r7, [r0, #24]
        // [1,14]    .    .    .    .    .   DeE   .    .    . .   str.w	r8, [r0, #28]
        // [1,15]    .    .    .    .    .    .DeE .    .    . .   str	r1, [r0], #32
        // [1,16]    .    .    .    .    .    . DE .    .    . .   subs.w	r12, r12, #1
        // [2,0]     .    .    .    .    .    . DE .    .    . .   ldr.w	r1, [r0]
        // [2,1]     .    .    .    .    .    .   DE    .    . .   ldr.w	r2, [r0, #4]
        // [2,2]     .    .    .    .    .    .   DE    .    . .   ldr.w	r3, [r0, #8]
        // [2,3]     .    .    .    .    .    .    DE   .    . .   ldr.w	r4, [r0, #12]
        // [2,4]     .    .    .    .    .    .    DE   .    . .   ldr.w	r5, [r0, #16]
        // [2,5]     .    .    .    .    .    .    .DE  .    . .   ldr.w	r6, [r0, #20]
        // [2,6]     .    .    .    .    .    .    .DE  .    . .   ldr.w	r7, [r0, #24]
        // [2,7]     .    .    .    .    .    .    . DE .    . .   ldr.w	r8, [r0, #28]
        // [2,8]     .    .    .    .    .    .    . DeE.    . .   str.w	r2, [r0, #4]
        // [2,9]     .    .    .    .    .    .    .  DeE    . .   str.w	r3, [r0, #8]
        // [2,10]    .    .    .    .    .    .    .   DeE   . .   str.w	r4, [r0, #12]
        // [2,11]    .    .    .    .    .    .    .    DeE  . .   str.w	r5, [r0, #16]
        // [2,12]    .    .    .    .    .    .    .    .DeE . .   str.w	r6, [r0, #20]
        // [2,13]    .    .    .    .    .    .    .    . DeE. .   str.w	r7, [r0, #24]
        // [2,14]    .    .    .    .    .    .    .    .  DeE .   str.w	r8, [r0, #28]
        // [2,15]    .    .    .    .    .    .    .    .    DeE   str	r1, [r0], #32
        // [2,16]    .    .    .    .    .    .    .    .    .DE   subs.w	r12, r12, #1
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
        // 8.     3     0.0    0.0    0.0       str.w	r2, [r0, #4]
        // 9.     3     0.0    0.0    0.0       str.w	r3, [r0, #8]
        // 10.    3     0.0    0.0    0.0       str.w	r4, [r0, #12]
        // 11.    3     0.0    0.0    0.0       str.w	r5, [r0, #16]
        // 12.    3     0.0    0.0    0.0       str.w	r6, [r0, #20]
        // 13.    3     0.0    0.0    0.0       str.w	r7, [r0, #24]
        // 14.    3     0.0    0.0    0.0       str.w	r8, [r0, #28]
        // 15.    3     0.0    0.0    0.0       str	r1, [r0], #32
        // 16.    3     0.0    0.0    0.0       subs.w	r12, r12, #1
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
        // Instructions:      1700
        // Total Cycles:      1401
        // Total uOps:        1700
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.21
        // IPC:               1.21
        // Block RThroughput: 8.5
        //
        //
        // Cycles with backend pressure increase [ 42.76% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 35.69% ]
        //   Data Dependencies:      [ 7.07% ]
        //   - Register Dependencies [ 7.07% ]
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
        //  1      1     0.50                        subs.w	r12, r12, #1
        //  1      2     0.50    *                   ldr.w	r4, [r0, #28]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #20]
        //  1      2     0.50    *                   ldr.w	r3, [r0, #16]
        //  1      2     0.50    *                   ldr.w	r1, [r0, #12]
        //  1      2     0.50    *                   ldr.w	r5, [r0, #8]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #4]
        //  1      3     1.00           *            str.w	r4, [r0, #28]
        //  1      2     0.50    *                   ldr.w	r6, [r0]
        //  1      3     1.00           *            str.w	r2, [r0, #24]
        //  1      3     1.00           *            str.w	r11, [r0, #20]
        //  1      3     1.00           *            str.w	r3, [r0, #16]
        //  1      3     1.00           *            str.w	r1, [r0, #12]
        //  1      3     1.00           *            str.w	r5, [r0, #8]
        //  1      3     1.00           *            str.w	r8, [r0, #4]
        //  1      3     1.00           *            str	r5, [r0], #32
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      99  (7.1%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 500  (35.7%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              201  (14.3%)
        //  1,              700  (50.0%)
        //  2,              500  (35.7%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          201  (14.3%)
        //  1,          700  (50.0%)
        //  2,          500  (35.7%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    1100
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
        // 0.50   0.50    -     4.00   4.00    -      -      -      -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        // 0.50   0.50    -      -      -      -      -      -      -      -      -      -      -     subs.w	r12, r12, #1
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #28]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #24]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #20]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r3, [r0, #16]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #12]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #8]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r4, [r0, #28]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r2, [r0, #24]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r11, [r0, #20]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r3, [r0, #16]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r1, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #8]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0], #32
        //
        //
        // Timeline view:
        //                     0123456789          0123456789
        // Index     0123456789          0123456789          012
        //
        // [0,0]     DE   .    .    .    .    .    .    .    . .   subs.w	r12, r12, #1
        // [0,1]     DE   .    .    .    .    .    .    .    . .   ldr.w	r4, [r0, #28]
        // [0,2]     .DE  .    .    .    .    .    .    .    . .   ldr.w	r6, [r0, #24]
        // [0,3]     .DE  .    .    .    .    .    .    .    . .   ldr.w	r11, [r0, #20]
        // [0,4]     . DE .    .    .    .    .    .    .    . .   ldr.w	r3, [r0, #16]
        // [0,5]     . DE .    .    .    .    .    .    .    . .   ldr.w	r1, [r0, #12]
        // [0,6]     .  DE.    .    .    .    .    .    .    . .   ldr.w	r5, [r0, #8]
        // [0,7]     .  DE.    .    .    .    .    .    .    . .   ldr.w	r8, [r0, #4]
        // [0,8]     .   DeE   .    .    .    .    .    .    . .   str.w	r4, [r0, #28]
        // [0,9]     .    DE   .    .    .    .    .    .    . .   ldr.w	r6, [r0]
        // [0,10]    .    DeE  .    .    .    .    .    .    . .   str.w	r2, [r0, #24]
        // [0,11]    .    .DeE .    .    .    .    .    .    . .   str.w	r11, [r0, #20]
        // [0,12]    .    . DeE.    .    .    .    .    .    . .   str.w	r3, [r0, #16]
        // [0,13]    .    .  DeE    .    .    .    .    .    . .   str.w	r1, [r0, #12]
        // [0,14]    .    .   DeE   .    .    .    .    .    . .   str.w	r5, [r0, #8]
        // [0,15]    .    .    DeE  .    .    .    .    .    . .   str.w	r8, [r0, #4]
        // [0,16]    .    .    . DeE.    .    .    .    .    . .   str	r5, [r0], #32
        // [1,0]     .    .    .  DE.    .    .    .    .    . .   subs.w	r12, r12, #1
        // [1,1]     .    .    .  DE.    .    .    .    .    . .   ldr.w	r4, [r0, #28]
        // [1,2]     .    .    .    DE   .    .    .    .    . .   ldr.w	r6, [r0, #24]
        // [1,3]     .    .    .    DE   .    .    .    .    . .   ldr.w	r11, [r0, #20]
        // [1,4]     .    .    .    .DE  .    .    .    .    . .   ldr.w	r3, [r0, #16]
        // [1,5]     .    .    .    .DE  .    .    .    .    . .   ldr.w	r1, [r0, #12]
        // [1,6]     .    .    .    . DE .    .    .    .    . .   ldr.w	r5, [r0, #8]
        // [1,7]     .    .    .    . DE .    .    .    .    . .   ldr.w	r8, [r0, #4]
        // [1,8]     .    .    .    .  DeE    .    .    .    . .   str.w	r4, [r0, #28]
        // [1,9]     .    .    .    .   DE    .    .    .    . .   ldr.w	r6, [r0]
        // [1,10]    .    .    .    .   DeE   .    .    .    . .   str.w	r2, [r0, #24]
        // [1,11]    .    .    .    .    DeE  .    .    .    . .   str.w	r11, [r0, #20]
        // [1,12]    .    .    .    .    .DeE .    .    .    . .   str.w	r3, [r0, #16]
        // [1,13]    .    .    .    .    . DeE.    .    .    . .   str.w	r1, [r0, #12]
        // [1,14]    .    .    .    .    .  DeE    .    .    . .   str.w	r5, [r0, #8]
        // [1,15]    .    .    .    .    .   DeE   .    .    . .   str.w	r8, [r0, #4]
        // [1,16]    .    .    .    .    .    .DeE .    .    . .   str	r5, [r0], #32
        // [2,0]     .    .    .    .    .    . DE .    .    . .   subs.w	r12, r12, #1
        // [2,1]     .    .    .    .    .    . DE .    .    . .   ldr.w	r4, [r0, #28]
        // [2,2]     .    .    .    .    .    .   DE    .    . .   ldr.w	r6, [r0, #24]
        // [2,3]     .    .    .    .    .    .   DE    .    . .   ldr.w	r11, [r0, #20]
        // [2,4]     .    .    .    .    .    .    DE   .    . .   ldr.w	r3, [r0, #16]
        // [2,5]     .    .    .    .    .    .    DE   .    . .   ldr.w	r1, [r0, #12]
        // [2,6]     .    .    .    .    .    .    .DE  .    . .   ldr.w	r5, [r0, #8]
        // [2,7]     .    .    .    .    .    .    .DE  .    . .   ldr.w	r8, [r0, #4]
        // [2,8]     .    .    .    .    .    .    . DeE.    . .   str.w	r4, [r0, #28]
        // [2,9]     .    .    .    .    .    .    .  DE.    . .   ldr.w	r6, [r0]
        // [2,10]    .    .    .    .    .    .    .  DeE    . .   str.w	r2, [r0, #24]
        // [2,11]    .    .    .    .    .    .    .   DeE   . .   str.w	r11, [r0, #20]
        // [2,12]    .    .    .    .    .    .    .    DeE  . .   str.w	r3, [r0, #16]
        // [2,13]    .    .    .    .    .    .    .    .DeE . .   str.w	r1, [r0, #12]
        // [2,14]    .    .    .    .    .    .    .    . DeE. .   str.w	r5, [r0, #8]
        // [2,15]    .    .    .    .    .    .    .    .  DeE .   str.w	r8, [r0, #4]
        // [2,16]    .    .    .    .    .    .    .    .    DeE   str	r5, [r0], #32
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       subs.w	r12, r12, #1
        // 1.     3     0.0    0.0    0.0       ldr.w	r4, [r0, #28]
        // 2.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #24]
        // 3.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #20]
        // 4.     3     0.0    0.0    0.0       ldr.w	r3, [r0, #16]
        // 5.     3     0.0    0.0    0.0       ldr.w	r1, [r0, #12]
        // 6.     3     0.0    0.0    0.0       ldr.w	r5, [r0, #8]
        // 7.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #4]
        // 8.     3     0.0    0.0    0.0       str.w	r4, [r0, #28]
        // 9.     3     0.0    0.0    0.0       ldr.w	r6, [r0]
        // 10.    3     0.0    0.0    0.0       str.w	r2, [r0, #24]
        // 11.    3     0.0    0.0    0.0       str.w	r11, [r0, #20]
        // 12.    3     0.0    0.0    0.0       str.w	r3, [r0, #16]
        // 13.    3     0.0    0.0    0.0       str.w	r1, [r0, #12]
        // 14.    3     0.0    0.0    0.0       str.w	r5, [r0, #8]
        // 15.    3     0.0    0.0    0.0       str.w	r8, [r0, #4]
        // 16.    3     0.0    0.0    0.0       str	r5, [r0], #32
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        reduce32_central_end:

        bne.w 1b

    pop {r4-r12, pc}

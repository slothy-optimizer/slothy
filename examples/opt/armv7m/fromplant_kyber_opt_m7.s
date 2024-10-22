/******************************************************************************
* Integrating the improved Plantard arithmetic into Kyber.
*
* Efficient Plantard arithmetic enables a faster Kyber implementation with the
* same stack usage.
*
* See the paper at https:// eprint.iacr.org/2022/956.pdf for more details.
*
* @author   Junhao Huang, BNU-HKBU United International College, Zhuhai, China
*           jhhuang_nuaa@126.com
*
* @date     September 2022
******************************************************************************/

.macro doubleplant a, tmp, q, qa, plantconst
 smulwb \tmp, \plantconst, \a
 smulwt \a, \plantconst, \a
 smlabt \tmp, \tmp, \q, \qa
 smlabt \a, \a, \q, \qa
 pkhtb \a, \a, \tmp, asr #16
.endm

.syntax unified
.cpu cortex-m4
.thumb

.global asm_fromplant_opt_m7
.type asm_fromplant_opt_m7,%function
.align 2
asm_fromplant_opt_m7:
 push    {r4-r11, r14}

 poly        .req r0
 poly0       .req r1
 poly1       .req r2
 poly2       .req r3
 poly3       .req r4
 poly4       .req r5
 poly5       .req r6
 poly6       .req r7
 poly7       .req r8
 loop        .req r9
 plantconst  .req r10
 q           .req r11
 qa          .req r12
 tmp         .req r14

 movw qa, #26632
 movt q, #3329

 ### movt qinv, #3327
 ### plant_constant=(Plant_const^2%M)*(p^-1) % 2^32
 movw plantconst, #20396
 movt plantconst, #38900
 movw loop, #16
                                   // Instructions:    5
                                   // Expected cycles: 5
                                   // Expected IPC:    1.00
                                   //
                                   // Cycle bound:     5.0
                                   // IPC bound:       1.00
                                   //
                                   // Wall time:     0.02s
                                   // User time:     0.02s
                                   //
                                   // ----- cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|----
        ldr r2, [r0, #28]          // *.............................
        ldr r14, [r0, #4]          // .*............................
        smulwt r1, r10, r2         // ..*...........................
        smulwb r7, r10, r14        // ...*..........................
        smulwt r3, r10, r14        // ....*.........................

                                    // ------ cycle (expected) ------>
                                    // 0                        25
                                    // |------------------------|-----
        // ldr r2, [r0, #28]        // *..............................
        // ldr r14, [r0, #4]        // .*.............................
        // smulwb r7, r10, r14      // ...*...........................
        // smulwt r1, r10, r2       // ..*............................
        // smulwt r3, r10, r14      // ....*..........................

        //
        // LLVM MCA STATISTICS (PREAMBLE) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      500
        // Total Cycles:      402
        // Total uOps:        500
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.24
        // IPC:               1.24
        // Block RThroughput: 3.0
        //
        //
        // Cycles with backend pressure increase [ 49.75% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 49.75% ]
        //   Data Dependencies:      [ 0.00% ]
        //   - Register Dependencies [ 0.00% ]
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
        //  1      2     0.50    *                   ldr	r2, [r0, #28]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #4]
        //  1      2     1.00                        smulwt	r1, r10, r2
        //  1      2     1.00                        smulwb	r7, r10, lr
        //  1      2     1.00                        smulwt	r3, r10, lr
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      0
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 200  (49.8%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              2  (0.5%)
        //  1,              300  (74.6%)
        //  2,              100  (24.9%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          2  (0.5%)
        //  1,          300  (74.6%)
        //  2,          100  (24.9%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    500
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
        //  -      -      -     1.00   1.00   3.00    -      -      -      -      -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r2, [r0, #28]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #4]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r1, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r7, r10, lr
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r3, r10, lr
        //
        //
        // Timeline view:
        //                     0123
        // Index     0123456789
        //
        // [0,0]     DE   .    .  .   ldr	r2, [r0, #28]
        // [0,1]     DE   .    .  .   ldr.w	lr, [r0, #4]
        // [0,2]     .DeE .    .  .   smulwt	r1, r10, r2
        // [0,3]     . DeE.    .  .   smulwb	r7, r10, lr
        // [0,4]     .  DeE    .  .   smulwt	r3, r10, lr
        // [1,0]     .   DE    .  .   ldr	r2, [r0, #28]
        // [1,1]     .   DE    .  .   ldr.w	lr, [r0, #4]
        // [1,2]     .    DeE  .  .   smulwt	r1, r10, r2
        // [1,3]     .    .DeE .  .   smulwb	r7, r10, lr
        // [1,4]     .    . DeE.  .   smulwt	r3, r10, lr
        // [2,0]     .    .  DE.  .   ldr	r2, [r0, #28]
        // [2,1]     .    .  DE.  .   ldr.w	lr, [r0, #4]
        // [2,2]     .    .   DeE .   smulwt	r1, r10, r2
        // [2,3]     .    .    DeE.   smulwb	r7, r10, lr
        // [2,4]     .    .    .DeE   smulwt	r3, r10, lr
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r2, [r0, #28]
        // 1.     3     0.0    0.0    0.0       ldr.w	lr, [r0, #4]
        // 2.     3     0.0    0.0    0.0       smulwt	r1, r10, r2
        // 3.     3     0.0    0.0    0.0       smulwb	r7, r10, lr
        // 4.     3     0.0    0.0    0.0       smulwt	r3, r10, lr
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (PREAMBLE) END
        //
        sub loop, loop, #1
1:
                                           // Instructions:    56
                                           // Expected cycles: 32
                                           // Expected IPC:    1.75
                                           //
                                           // Cycle bound:     33.0
                                           // IPC bound:       1.70
                                           //
                                           // Wall time:     27.63s
                                           // User time:     27.63s
                                           //
                                           // ------ cycle (expected) ------->
                                           // 0                        25
                                           // |------------------------|------
        ldr r8, [r0, #0]                   // *...............................
        smlabt r4, r7, r11, r12            // *...............................
        smlabt r5, r3, r11, r12            // .*..............................
        ldr r6, [r0, #20]                  // ..*.............................
        smulwb r14, r10, r2                // ..*.............................
        pkhtb r7, r5, r4, asr #16          // ...*............................
        smulwb r4, r10, r8                 // ...*............................
        ldr r2, [r0, #24]                  // ....*...........................
        smlabt r5, r14, r11, r12           // ....*...........................
        str r7, [r0, #4]                   // .....*..........................
        smulwt r7, r10, r8                 // .....*..........................
        ldr r8, [r0, #16]                  // ......*.........................
        smlabt r3, r4, r11, r12            // ......*.........................
        smlabt r4, r7, r11, r12            // .......*........................
        smulwt r14, r10, r8                // ........*.......................
        pkhtb r3, r4, r3, asr #16          // .........*......................
        smulwb r7, r10, r2                 // .........*......................
        str r3, [r0], #32                  // ..........*.....................
        smlabt r1, r1, r11, r12            // ..........*.....................
        smulwt r3, r10, r6                 // ...........*....................
        pkhtb r4, r1, r5, asr #16          // ............*...................
        smulwb r5, r10, r6                 // ............*...................
        str r4, [r0, #-4]                  // .............*..................
        smlabt r1, r14, r11, r12           // .............*..................
        ldr r4, [r0, #-20]                 // ..............*.................
        smulwt r6, r10, r2                 // ..............*.................
        smlabt r14, r7, r11, r12           // ...............*................
        ldr r2, [r0, #28]                  // ................e...............
        smlabt r6, r6, r11, r12            // ................*...............
        smulwb r8, r10, r8                 // .................*..............
        pkhtb r14, r6, r14, asr #16        // ..................*.............
        smlabt r6, r5, r11, r12            // ..................*.............
        str r14, [r0, #-8]                 // ...................*............
        smlabt r3, r3, r11, r12            // ...................*............
        ldr r14, [r0, #4]                  // ....................e...........
        smulwb r5, r10, r4                 // ....................*...........
        pkhtb r3, r3, r6, asr #16          // .....................*..........
        smulwt r7, r10, r4                 // .....................*..........
        str r3, [r0, #-12]                 // ......................*.........
        smlabt r6, r5, r11, r12            // ......................*.........
        ldr r4, [r0, #-24]                 // .......................*........
        smlabt r3, r8, r11, r12            // .......................*........
        smlabt r7, r7, r11, r12            // ........................*.......
        smulwb r8, r10, r4                 // .........................*......
        pkhtb r7, r7, r6, asr #16          // ..........................*.....
        smulwt r4, r10, r4                 // ..........................*.....
        str r7, [r0, #-20]                 // ...........................*....
        smlabt r8, r8, r11, r12            // ...........................*....
        pkhtb r5, r1, r3, asr #16          // ............................*...
        smlabt r4, r4, r11, r12            // ............................*...
        str r5, [r0, #-16]                 // .............................*..
        smulwb r7, r10, r14                // .............................e..
        pkhtb r5, r4, r8, asr #16          // ..............................*.
        smulwt r1, r10, r2                 // ..............................e.
        str r5, [r0, #-24]                 // ...............................*
        smulwt r3, r10, r14                // ...............................e

                                           // -------------- cycle (expected) --------------->
                                           // 0                        25
                                           // |------------------------|----------------------
        // ldr r1, [r0, #0]                // ................*...............................
        // ldr r2, [r0, #4]                // ....e...........'...................~...........
        // ldr r3, [r0, #8]                // .......~........'......................*........
        // ldr r4, [r0, #12]               // ................'.............*.................
        // ldr r5, [r0, #16]               // ................'.....*.........................
        // ldr r6, [r0, #20]               // ................'.*.............................
        // ldr r7, [r0, #24]               // ................'...*...........................
        // ldr r8, [r0, #28]               // e...............'...............~...............
        // smulwb r14, r10, r1             // ................'..*............................
        // smulwt r1, r10, r1              // ................'....*..........................
        // smlabt r14, r14, r11, r12       // ................'.....*.........................
        // smlabt r1, r1, r11, r12         // ................'......*........................
        // pkhtb r1, r1, r14, asr #16      // ................'........*......................
        // smulwb r14, r10, r2             // .............e..'............................~..
        // smulwt r2, r10, r2              // ...............e'...............................
        // smlabt r14, r14, r11, r12       // ................*...............................
        // smlabt r2, r2, r11, r12         // ................'*..............................
        // pkhtb r2, r2, r14, asr #16      // ................'..*............................
        // smulwb r14, r10, r3             // .........~......'........................*......
        // smulwt r3, r10, r3              // ..........~.....'.........................*.....
        // smlabt r14, r14, r11, r12       // ...........~....'..........................*....
        // smlabt r3, r3, r11, r12         // ............~...'...........................*...
        // pkhtb r3, r3, r14, asr #16      // ..............~.'.............................*.
        // smulwb r14, r10, r4             // ....~...........'...................*...........
        // smulwt r4, r10, r4              // .....~..........'....................*..........
        // smlabt r14, r14, r11, r12       // ......~.........'.....................*.........
        // smlabt r4, r4, r11, r12         // ........~.......'.......................*.......
        // pkhtb r4, r4, r14, asr #16      // ..........~.....'.........................*.....
        // smulwb r14, r10, r5             // .~..............'................*..............
        // smulwt r5, r10, r5              // ................'.......*.......................
        // smlabt r14, r14, r11, r12       // .......~........'......................*........
        // smlabt r5, r5, r11, r12         // ................'............*..................
        // pkhtb r5, r5, r14, asr #16      // ............~...'...........................*...
        // smulwb r14, r10, r6             // ................'...........*...................
        // smulwt r6, r10, r6              // ................'..........*....................
        // smlabt r14, r14, r11, r12       // ..~.............'.................*.............
        // smlabt r6, r6, r11, r12         // ...~............'..................*............
        // pkhtb r6, r6, r14, asr #16      // .....~..........'....................*..........
        // smulwb r14, r10, r7             // ................'........*......................
        // smulwt r7, r10, r7              // ................'.............*.................
        // smlabt r14, r14, r11, r12       // ................'..............*................
        // smlabt r7, r7, r11, r12         // ~...............'...............*...............
        // pkhtb r7, r7, r14, asr #16      // ..~.............'.................*.............
        // smulwb r14, r10, r8             // ................'.*.............................
        // smulwt r8, r10, r8              // ..............e.'.............................~.
        // smlabt r14, r14, r11, r12       // ................'...*...........................
        // smlabt r8, r8, r11, r12         // ................'.........*.....................
        // pkhtb r8, r8, r14, asr #16      // ................'...........*...................
        // str r8, [r0, #28]               // ................'............*..................
        // str r7, [r0, #24]               // ...~............'..................*............
        // str r6, [r0, #20]               // ......~.........'.....................*.........
        // str r5, [r0, #16]               // .............~..'............................*..
        // str r4, [r0, #12]               // ...........~....'..........................*....
        // str r3, [r0, #8]                // ...............~'..............................*
        // str r2, [r0, #4]                // ................'....*..........................
        // str r1, [r0], #32               // ................'.........*.....................

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      5600
        // Total Cycles:      5401
        // Total uOps:        5600
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.04
        // IPC:               1.04
        // Block RThroughput: 32.0
        //
        //
        // Cycles with backend pressure increase [ 61.06% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 12.96% ]
        //   Data Dependencies:      [ 48.10% ]
        //   - Register Dependencies [ 48.10% ]
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
        //  1      2     0.50    *                   ldr	r1, [r0]
        //  1      2     0.50    *                   ldr	r2, [r0, #4]
        //  1      2     0.50    *                   ldr	r3, [r0, #8]
        //  1      2     0.50    *                   ldr	r4, [r0, #12]
        //  1      2     0.50    *                   ldr	r5, [r0, #16]
        //  1      2     0.50    *                   ldr	r6, [r0, #20]
        //  1      2     0.50    *                   ldr	r7, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #28]
        //  1      2     1.00                        smulwb	lr, r10, r1
        //  1      2     1.00                        smulwt	r1, r10, r1
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r1, r1, r11, r12
        //  1      2     1.00                        pkhtb	r1, r1, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r2
        //  1      2     1.00                        smulwt	r2, r10, r2
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r2, r2, r11, r12
        //  1      2     1.00                        pkhtb	r2, r2, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r3
        //  1      2     1.00                        smulwt	r3, r10, r3
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r3, r3, r11, r12
        //  1      2     1.00                        pkhtb	r3, r3, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r4
        //  1      2     1.00                        smulwt	r4, r10, r4
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r4, r4, r11, r12
        //  1      2     1.00                        pkhtb	r4, r4, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r5
        //  1      2     1.00                        smulwt	r5, r10, r5
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r5, r5, r11, r12
        //  1      2     1.00                        pkhtb	r5, r5, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r6
        //  1      2     1.00                        smulwt	r6, r10, r6
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r6, r6, r11, r12
        //  1      2     1.00                        pkhtb	r6, r6, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r7
        //  1      2     1.00                        smulwt	r7, r10, r7
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r7, r7, r11, r12
        //  1      2     1.00                        pkhtb	r7, r7, lr, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r8
        //  1      2     1.00                        smulwt	r8, r10, r8
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      2     1.00                        smlabt	r8, r8, r11, r12
        //  1      2     1.00                        pkhtb	r8, r8, lr, asr #16
        //  1      3     1.00           *            str.w	r8, [r0, #28]
        //  1      3     1.00           *            str	r7, [r0, #24]
        //  1      3     1.00           *            str	r6, [r0, #20]
        //  1      3     1.00           *            str	r5, [r0, #16]
        //  1      3     1.00           *            str	r4, [r0, #12]
        //  1      3     1.00           *            str	r3, [r0, #8]
        //  1      3     1.00           *            str	r2, [r0, #4]
        //  1      3     1.00           *            str	r1, [r0], #32
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      2598  (48.1%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 700  (13.0%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              1001  (18.5%)
        //  1,              3200  (59.2%)
        //  2,              1200  (22.2%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          1001  (18.5%)
        //  1,          3200  (59.2%)
        //  2,          1200  (22.2%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    4900
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
        // 4.00   4.00    -     4.00   4.00   32.00  8.00   8.00    -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r1, [r0]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r2, [r0, #4]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r3, [r0, #8]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r4, [r0, #12]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r5, [r0, #16]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r6, [r0, #20]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r7, [r0, #24]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #28]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r1, r10, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r1, r1, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r1, r1, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r2, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r2, r2, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r2, r2, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r3, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r3, r3, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, r3, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r4, r10, r4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r4, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r4, r4, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r5, r10, r5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r5, r5, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r5, r5, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r6
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r6, r10, r6
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, r6, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r6, r6, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r7, r10, r7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r7, r7, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r7, r7, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r8
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r8, r10, r8
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r8, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r8, r8, lr, asr #16
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #28]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r7, [r0, #24]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r6, [r0, #20]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0, #16]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #8]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r2, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0], #32
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          012
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r1, [r0]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r2, [r0, #4]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r3, [r0, #8]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r4, [r0, #12]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r5, [r0, #16]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r6, [r0, #20]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r7, [r0, #24]
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r8, [r0, #28]
        // [0,8]     .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r1
        // [0,9]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r1, r10, r1
        // [0,10]    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,11]    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r1, r1, r11, r12
        // [0,12]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r1, r1, lr, asr #16
        // [0,13]    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r2
        // [0,14]    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r2, r10, r2
        // [0,15]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,16]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r2, r2, r11, r12
        // [0,17]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r2, r2, lr, asr #16
        // [0,18]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r3
        // [0,19]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r3, r10, r3
        // [0,20]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,21]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r3, r3, r11, r12
        // [0,22]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r3, r3, lr, asr #16
        // [0,23]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r4
        // [0,24]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r4, r10, r4
        // [0,25]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,26]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r4, r4, r11, r12
        // [0,27]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r4, r4, lr, asr #16
        // [0,28]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r5
        // [0,29]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r5, r10, r5
        // [0,30]    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,31]    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r5, r5, r11, r12
        // [0,32]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r5, r5, lr, asr #16
        // [0,33]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r6
        // [0,34]    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r6, r10, r6
        // [0,35]    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,36]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r6, r6, r11, r12
        // [0,37]    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r6, r6, lr, asr #16
        // [0,38]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r7
        // [0,39]    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r7, r10, r7
        // [0,40]    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,41]    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r7, r7, r11, r12
        // [0,42]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r7, r7, lr, asr #16
        // [0,43]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r8
        // [0,44]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r8, r10, r8
        // [0,45]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [0,46]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r8, r8, r11, r12
        // [0,47]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r8, r8, lr, asr #16
        // [0,48]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str.w	r8, [r0, #28]
        // [0,49]    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r7, [r0, #24]
        // [0,50]    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r6, [r0, #20]
        // [0,51]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r5, [r0, #16]
        // [0,52]    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r4, [r0, #12]
        // [0,53]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r3, [r0, #8]
        // [0,54]    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r2, [r0, #4]
        // [0,55]    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   str	r1, [r0], #32
        // [1,0]     .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r1, [r0]
        // [1,1]     .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r2, [r0, #4]
        // [1,2]     .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r3, [r0, #8]
        // [1,3]     .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r4, [r0, #12]
        // [1,4]     .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r5, [r0, #16]
        // [1,5]     .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r6, [r0, #20]
        // [1,6]     .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r7, [r0, #24]
        // [1,7]     .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r8, [r0, #28]
        // [1,8]     .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r1
        // [1,9]     .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r1, r10, r1
        // [1,10]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r1, r1, r11, r12
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r1, r1, lr, asr #16
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r2
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r2, r10, r2
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r2, r2, r11, r12
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r2, r2, lr, asr #16
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r3
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r3, r10, r3
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r3, r3, r11, r12
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r3, r3, lr, asr #16
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r4
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r4, r10, r4
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r4, r4, r11, r12
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r4, r4, lr, asr #16
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r5
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r5, r10, r5
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r5, r5, r11, r12
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r5, r5, lr, asr #16
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r6
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r6, r10, r6
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r6, r6, r11, r12
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r6, r6, lr, asr #16
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r7
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r7, r10, r7
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r7, r7, r11, r12
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r7, r7, lr, asr #16
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r8
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    . .   smulwt	r8, r10, r8
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    . .   smlabt	r8, r8, r11, r12
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    . .   pkhtb	r8, r8, lr, asr #16
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    . .   str.w	r8, [r0, #28]
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    . .   str	r7, [r0, #24]
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    . .   str	r6, [r0, #20]
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    . .   str	r5, [r0, #16]
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    . .   str	r4, [r0, #12]
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    . .   str	r3, [r0, #8]
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    . .   str	r2, [r0, #4]
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    . .   str	r1, [r0], #32
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    . .   ldr	r1, [r0]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    . .   ldr	r2, [r0, #4]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    . .   ldr	r3, [r0, #8]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    . .   ldr	r4, [r0, #12]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    . .   ldr	r5, [r0, #16]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    . .   ldr	r6, [r0, #20]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    . .   ldr	r7, [r0, #24]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    . .   ldr.w	r8, [r0, #28]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r1
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    . .   smulwt	r1, r10, r1
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    . .   smlabt	r1, r1, r11, r12
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    . .   pkhtb	r1, r1, lr, asr #16
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    . .   smulwb	lr, r10, r2
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    . .   smulwt	r2, r10, r2
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    . .   smlabt	r2, r2, r11, r12
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    . .   pkhtb	r2, r2, lr, asr #16
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    . .   smulwb	lr, r10, r3
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    . .   smulwt	r3, r10, r3
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    . .   smlabt	r3, r3, r11, r12
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    . .   pkhtb	r3, r3, lr, asr #16
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    . .   smulwb	lr, r10, r4
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    . .   smulwt	r4, r10, r4
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    . .   smlabt	r4, r4, r11, r12
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    . .   pkhtb	r4, r4, lr, asr #16
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    . .   smulwb	lr, r10, r5
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    . .   smulwt	r5, r10, r5
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    . .   smlabt	r5, r5, r11, r12
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    . .   pkhtb	r5, r5, lr, asr #16
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    . .   smulwb	lr, r10, r6
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    . .   smulwt	r6, r10, r6
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    . .   smlabt	lr, lr, r11, r12
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    . .   smlabt	r6, r6, r11, r12
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    . .   pkhtb	r6, r6, lr, asr #16
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    . .   smulwb	lr, r10, r7
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    . .   smulwt	r7, r10, r7
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    . .   smlabt	lr, lr, r11, r12
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    . .   smlabt	r7, r7, r11, r12
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    . .   pkhtb	r7, r7, lr, asr #16
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    . .   smulwb	lr, r10, r8
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    . .   smulwt	r8, r10, r8
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    . .   smlabt	lr, lr, r11, r12
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    . .   smlabt	r8, r8, r11, r12
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    . .   pkhtb	r8, r8, lr, asr #16
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    . .   str.w	r8, [r0, #28]
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    . .   str	r7, [r0, #24]
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   . .   str	r6, [r0, #20]
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  . .   str	r5, [r0, #16]
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE . .   str	r4, [r0, #12]
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE. .   str	r3, [r0, #8]
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE .   str	r2, [r0, #4]
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE   str	r1, [r0], #32
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r1, [r0]
        // 1.     3     0.0    0.0    0.0       ldr	r2, [r0, #4]
        // 2.     3     0.0    0.0    0.0       ldr	r3, [r0, #8]
        // 3.     3     0.0    0.0    0.0       ldr	r4, [r0, #12]
        // 4.     3     0.0    0.0    0.0       ldr	r5, [r0, #16]
        // 5.     3     0.0    0.0    0.0       ldr	r6, [r0, #20]
        // 6.     3     0.0    0.0    0.0       ldr	r7, [r0, #24]
        // 7.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #28]
        // 8.     3     0.0    0.0    0.0       smulwb	lr, r10, r1
        // 9.     3     0.0    0.0    0.0       smulwt	r1, r10, r1
        // 10.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 11.    3     0.0    0.0    0.0       smlabt	r1, r1, r11, r12
        // 12.    3     0.0    0.0    0.0       pkhtb	r1, r1, lr, asr #16
        // 13.    3     0.0    0.0    0.0       smulwb	lr, r10, r2
        // 14.    3     0.0    0.0    0.0       smulwt	r2, r10, r2
        // 15.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 16.    3     0.0    0.0    0.0       smlabt	r2, r2, r11, r12
        // 17.    3     0.0    0.0    0.0       pkhtb	r2, r2, lr, asr #16
        // 18.    3     0.0    0.0    0.0       smulwb	lr, r10, r3
        // 19.    3     0.0    0.0    0.0       smulwt	r3, r10, r3
        // 20.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 21.    3     0.0    0.0    0.0       smlabt	r3, r3, r11, r12
        // 22.    3     0.0    0.0    0.0       pkhtb	r3, r3, lr, asr #16
        // 23.    3     0.0    0.0    0.0       smulwb	lr, r10, r4
        // 24.    3     0.0    0.0    0.0       smulwt	r4, r10, r4
        // 25.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 26.    3     0.0    0.0    0.0       smlabt	r4, r4, r11, r12
        // 27.    3     0.0    0.0    0.0       pkhtb	r4, r4, lr, asr #16
        // 28.    3     0.0    0.0    0.0       smulwb	lr, r10, r5
        // 29.    3     0.0    0.0    0.0       smulwt	r5, r10, r5
        // 30.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 31.    3     0.0    0.0    0.0       smlabt	r5, r5, r11, r12
        // 32.    3     0.0    0.0    0.0       pkhtb	r5, r5, lr, asr #16
        // 33.    3     0.0    0.0    0.0       smulwb	lr, r10, r6
        // 34.    3     0.0    0.0    0.0       smulwt	r6, r10, r6
        // 35.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 36.    3     0.0    0.0    0.0       smlabt	r6, r6, r11, r12
        // 37.    3     0.0    0.0    0.0       pkhtb	r6, r6, lr, asr #16
        // 38.    3     0.0    0.0    0.0       smulwb	lr, r10, r7
        // 39.    3     0.0    0.0    0.0       smulwt	r7, r10, r7
        // 40.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 41.    3     0.0    0.0    0.0       smlabt	r7, r7, r11, r12
        // 42.    3     0.0    0.0    0.0       pkhtb	r7, r7, lr, asr #16
        // 43.    3     0.0    0.0    0.0       smulwb	lr, r10, r8
        // 44.    3     0.0    0.0    0.0       smulwt	r8, r10, r8
        // 45.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 46.    3     0.0    0.0    0.0       smlabt	r8, r8, r11, r12
        // 47.    3     0.0    0.0    0.0       pkhtb	r8, r8, lr, asr #16
        // 48.    3     0.0    0.0    0.0       str.w	r8, [r0, #28]
        // 49.    3     0.0    0.0    0.0       str	r7, [r0, #24]
        // 50.    3     0.0    0.0    0.0       str	r6, [r0, #20]
        // 51.    3     0.0    0.0    0.0       str	r5, [r0, #16]
        // 52.    3     0.0    0.0    0.0       str	r4, [r0, #12]
        // 53.    3     0.0    0.0    0.0       str	r3, [r0, #8]
        // 54.    3     0.0    0.0    0.0       str	r2, [r0, #4]
        // 55.    3     0.0    0.0    0.0       str	r1, [r0], #32
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
        // Instructions:      5600
        // Total Cycles:      3302
        // Total uOps:        5600
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.70
        // IPC:               1.70
        // Block RThroughput: 32.0
        //
        //
        // Cycles with backend pressure increase [ 6.06% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 6.06% ]
        //   Data Dependencies:      [ 0.00% ]
        //   - Register Dependencies [ 0.00% ]
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
        //  1      2     0.50    *                   ldr.w	r8, [r0]
        //  1      2     1.00                        smlabt	r4, r7, r11, r12
        //  1      2     1.00                        smlabt	r5, r3, r11, r12
        //  1      2     0.50    *                   ldr	r6, [r0, #20]
        //  1      2     1.00                        smulwb	lr, r10, r2
        //  1      2     1.00                        pkhtb	r7, r5, r4, asr #16
        //  1      2     1.00                        smulwb	r4, r10, r8
        //  1      2     0.50    *                   ldr	r2, [r0, #24]
        //  1      2     1.00                        smlabt	r5, lr, r11, r12
        //  1      3     1.00           *            str	r7, [r0, #4]
        //  1      2     1.00                        smulwt	r7, r10, r8
        //  1      2     0.50    *                   ldr.w	r8, [r0, #16]
        //  1      2     1.00                        smlabt	r3, r4, r11, r12
        //  1      2     1.00                        smlabt	r4, r7, r11, r12
        //  1      2     1.00                        smulwt	lr, r10, r8
        //  1      2     1.00                        pkhtb	r3, r4, r3, asr #16
        //  1      2     1.00                        smulwb	r7, r10, r2
        //  1      3     1.00           *            str	r3, [r0], #32
        //  1      2     1.00                        smlabt	r1, r1, r11, r12
        //  1      2     1.00                        smulwt	r3, r10, r6
        //  1      2     1.00                        pkhtb	r4, r1, r5, asr #16
        //  1      2     1.00                        smulwb	r5, r10, r6
        //  1      3     1.00           *            str	r4, [r0, #-4]
        //  1      2     1.00                        smlabt	r1, lr, r11, r12
        //  1      2     0.50    *                   ldr	r4, [r0, #-20]
        //  1      2     1.00                        smulwt	r6, r10, r2
        //  1      2     1.00                        smlabt	lr, r7, r11, r12
        //  1      2     0.50    *                   ldr	r2, [r0, #28]
        //  1      2     1.00                        smlabt	r6, r6, r11, r12
        //  1      2     1.00                        smulwb	r8, r10, r8
        //  1      2     1.00                        pkhtb	lr, r6, lr, asr #16
        //  1      2     1.00                        smlabt	r6, r5, r11, r12
        //  1      3     1.00           *            str	lr, [r0, #-8]
        //  1      2     1.00                        smlabt	r3, r3, r11, r12
        //  1      2     0.50    *                   ldr.w	lr, [r0, #4]
        //  1      2     1.00                        smulwb	r5, r10, r4
        //  1      2     1.00                        pkhtb	r3, r3, r6, asr #16
        //  1      2     1.00                        smulwt	r7, r10, r4
        //  1      3     1.00           *            str	r3, [r0, #-12]
        //  1      2     1.00                        smlabt	r6, r5, r11, r12
        //  1      2     0.50    *                   ldr	r4, [r0, #-24]
        //  1      2     1.00                        smlabt	r3, r8, r11, r12
        //  1      2     1.00                        smlabt	r7, r7, r11, r12
        //  1      2     1.00                        smulwb	r8, r10, r4
        //  1      2     1.00                        pkhtb	r7, r7, r6, asr #16
        //  1      2     1.00                        smulwt	r4, r10, r4
        //  1      3     1.00           *            str	r7, [r0, #-20]
        //  1      2     1.00                        smlabt	r8, r8, r11, r12
        //  1      2     1.00                        pkhtb	r5, r1, r3, asr #16
        //  1      2     1.00                        smlabt	r4, r4, r11, r12
        //  1      3     1.00           *            str	r5, [r0, #-16]
        //  1      2     1.00                        smulwb	r7, r10, lr
        //  1      2     1.00                        pkhtb	r5, r4, r8, asr #16
        //  1      2     1.00                        smulwt	r1, r10, r2
        //  1      3     1.00           *            str	r5, [r0, #-24]
        //  1      2     1.00                        smulwt	r3, r10, lr
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      0
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 200  (6.1%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              102  (3.1%)
        //  1,              800  (24.2%)
        //  2,              2400  (72.7%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          102  (3.1%)
        //  1,          800  (24.2%)
        //  2,          2400  (72.7%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    4900
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
        // 4.00   4.00    -     4.00   4.00   32.00  8.00   8.00    -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r8, [r0]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r7, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r5, r3, r11, r12
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r6, [r0, #20]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r2
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r7, r5, r4, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r4, r10, r8
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r2, [r0, #24]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r5, lr, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r7, [r0, #4]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r7, r10, r8
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #16]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r3, r4, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r7, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	lr, r10, r8
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, r4, r3, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r7, r10, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0], #32
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r1, r1, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r3, r10, r6
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r4, r1, r5, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r5, r10, r6
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [r0, #-4]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r1, lr, r11, r12
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r4, [r0, #-20]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r6, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, r7, r11, r12
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r2, [r0, #28]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, r6, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r8, r10, r8
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	lr, r6, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, r5, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	lr, [r0, #-8]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r3, r3, r11, r12
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #4]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r5, r10, r4
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, r3, r6, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r7, r10, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #-12]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, r5, r11, r12
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r4, [r0, #-24]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r3, r8, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r7, r7, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r8, r10, r4
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r7, r7, r6, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r4, r10, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r7, [r0, #-20]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r8, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r5, r1, r3, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r4, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0, #-16]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r7, r10, lr
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r5, r4, r8, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r1, r10, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0, #-24]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r3, r10, lr
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0]
        // [0,1]     DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [0,2]     .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r5, r3, r11, r12
        // [0,3]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r6, [r0, #20]
        // [0,4]     . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r2
        // [0,5]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r7, r5, r4, asr #16
        // [0,6]     .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r4, r10, r8
        // [0,7]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #24]
        // [0,8]     .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r5, lr, r11, r12
        // [0,9]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r7, [r0, #4]
        // [0,10]    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r7, r10, r8
        // [0,11]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0, #16]
        // [0,12]    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r3, r4, r11, r12
        // [0,13]    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [0,14]    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	lr, r10, r8
        // [0,15]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, r4, r3, asr #16
        // [0,16]    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r7, r10, r2
        // [0,17]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0], #32
        // [0,18]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r1, r11, r12
        // [0,19]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r3, r10, r6
        // [0,20]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r4, r1, r5, asr #16
        // [0,21]    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r6
        // [0,22]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r4, [r0, #-4]
        // [0,23]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, lr, r11, r12
        // [0,24]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #-20]
        // [0,25]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r2
        // [0,26]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	lr, r7, r11, r12
        // [0,27]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #28]
        // [0,28]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, r6, r11, r12
        // [0,29]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r8, r10, r8
        // [0,30]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	lr, r6, lr, asr #16
        // [0,31]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, r5, r11, r12
        // [0,32]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	lr, [r0, #-8]
        // [0,33]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r3, r3, r11, r12
        // [0,34]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	lr, [r0, #4]
        // [0,35]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r4
        // [0,36]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, r3, r6, asr #16
        // [0,37]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r7, r10, r4
        // [0,38]    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0, #-12]
        // [0,39]    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, r5, r11, r12
        // [0,40]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #-24]
        // [0,41]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r3, r8, r11, r12
        // [0,42]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r7, r7, r11, r12
        // [0,43]    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r8, r10, r4
        // [0,44]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r7, r7, r6, asr #16
        // [0,45]    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r4
        // [0,46]    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r7, [r0, #-20]
        // [0,47]    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r8, r11, r12
        // [0,48]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r5, r1, r3, asr #16
        // [0,49]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [0,50]    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r5, [r0, #-16]
        // [0,51]    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r7, r10, lr
        // [0,52]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r5, r4, r8, asr #16
        // [0,53]    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r1, r10, r2
        // [0,54]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r5, [r0, #-24]
        // [0,55]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r3, r10, lr
        // [1,0]     .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0]
        // [1,1]     .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [1,2]     .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r5, r3, r11, r12
        // [1,3]     .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r6, [r0, #20]
        // [1,4]     .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r2
        // [1,5]     .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r7, r5, r4, asr #16
        // [1,6]     .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r4, r10, r8
        // [1,7]     .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #24]
        // [1,8]     .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r5, lr, r11, r12
        // [1,9]     .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .   str	r7, [r0, #4]
        // [1,10]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r7, r10, r8
        // [1,11]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0, #16]
        // [1,12]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r3, r4, r11, r12
        // [1,13]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [1,14]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .   smulwt	lr, r10, r8
        // [1,15]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, r4, r3, asr #16
        // [1,16]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .   smulwb	r7, r10, r2
        // [1,17]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0], #32
        // [1,18]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r1, r11, r12
        // [1,19]    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .   smulwt	r3, r10, r6
        // [1,20]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .   pkhtb	r4, r1, r5, asr #16
        // [1,21]    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r6
        // [1,22]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .   str	r4, [r0, #-4]
        // [1,23]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .   smlabt	r1, lr, r11, r12
        // [1,24]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #-20]
        // [1,25]    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r2
        // [1,26]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .   smlabt	lr, r7, r11, r12
        // [1,27]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #28]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .   smlabt	r6, r6, r11, r12
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .   smulwb	r8, r10, r8
        // [1,30]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .   pkhtb	lr, r6, lr, asr #16
        // [1,31]    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .   smlabt	r6, r5, r11, r12
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .   str	lr, [r0, #-8]
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .   smlabt	r3, r3, r11, r12
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .   ldr.w	lr, [r0, #4]
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r4
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .   pkhtb	r3, r3, r6, asr #16
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .   smulwt	r7, r10, r4
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .   str	r3, [r0, #-12]
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .   smlabt	r6, r5, r11, r12
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #-24]
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .   smlabt	r3, r8, r11, r12
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .   smlabt	r7, r7, r11, r12
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .   smulwb	r8, r10, r4
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .   pkhtb	r7, r7, r6, asr #16
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .   smulwt	r4, r10, r4
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .   str	r7, [r0, #-20]
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .   smlabt	r8, r8, r11, r12
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .   pkhtb	r5, r1, r3, asr #16
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .   str	r5, [r0, #-16]
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .   smulwb	r7, r10, lr
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .   pkhtb	r5, r4, r8, asr #16
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .   smulwt	r1, r10, r2
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .   str	r5, [r0, #-24]
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .   smulwt	r3, r10, lr
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .   ldr.w	r8, [r0]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .   smlabt	r5, r3, r11, r12
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .   ldr	r6, [r0, #20]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .   smulwb	lr, r10, r2
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .   pkhtb	r7, r5, r4, asr #16
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .   smulwb	r4, r10, r8
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .   ldr	r2, [r0, #24]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .   smlabt	r5, lr, r11, r12
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .   str	r7, [r0, #4]
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .   smulwt	r7, r10, r8
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .   ldr.w	r8, [r0, #16]
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .   smlabt	r3, r4, r11, r12
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .   smlabt	r4, r7, r11, r12
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .   smulwt	lr, r10, r8
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .   pkhtb	r3, r4, r3, asr #16
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .   smulwb	r7, r10, r2
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .   str	r3, [r0], #32
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .   smlabt	r1, r1, r11, r12
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .   smulwt	r3, r10, r6
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .   pkhtb	r4, r1, r5, asr #16
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .   smulwb	r5, r10, r6
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .   str	r4, [r0, #-4]
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .   smlabt	r1, lr, r11, r12
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .   ldr	r4, [r0, #-20]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .   smulwt	r6, r10, r2
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .   smlabt	lr, r7, r11, r12
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .   ldr	r2, [r0, #28]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .   smlabt	r6, r6, r11, r12
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .   smulwb	r8, r10, r8
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .   pkhtb	lr, r6, lr, asr #16
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .   smlabt	r6, r5, r11, r12
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .   str	lr, [r0, #-8]
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .   smlabt	r3, r3, r11, r12
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .   ldr.w	lr, [r0, #4]
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .   smulwb	r5, r10, r4
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .   pkhtb	r3, r3, r6, asr #16
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .   smulwt	r7, r10, r4
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .   str	r3, [r0, #-12]
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .   smlabt	r6, r5, r11, r12
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .   ldr	r4, [r0, #-24]
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .   smlabt	r3, r8, r11, r12
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .   smlabt	r7, r7, r11, r12
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .   smulwb	r8, r10, r4
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .   pkhtb	r7, r7, r6, asr #16
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .   smulwt	r4, r10, r4
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .   str	r7, [r0, #-20]
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .   smlabt	r8, r8, r11, r12
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .   pkhtb	r5, r1, r3, asr #16
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .   smlabt	r4, r4, r11, r12
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .   str	r5, [r0, #-16]
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .   smulwb	r7, r10, lr
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .   pkhtb	r5, r4, r8, asr #16
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.   smulwt	r1, r10, r2
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE   str	r5, [r0, #-24]
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE   smulwt	r3, r10, lr
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r8, [r0]
        // 1.     3     0.0    0.0    0.0       smlabt	r4, r7, r11, r12
        // 2.     3     0.0    0.0    0.0       smlabt	r5, r3, r11, r12
        // 3.     3     0.0    0.0    0.0       ldr	r6, [r0, #20]
        // 4.     3     0.0    0.0    0.0       smulwb	lr, r10, r2
        // 5.     3     0.0    0.0    0.0       pkhtb	r7, r5, r4, asr #16
        // 6.     3     0.0    0.0    0.0       smulwb	r4, r10, r8
        // 7.     3     0.0    0.0    0.0       ldr	r2, [r0, #24]
        // 8.     3     0.0    0.0    0.0       smlabt	r5, lr, r11, r12
        // 9.     3     0.0    0.0    0.0       str	r7, [r0, #4]
        // 10.    3     0.0    0.0    0.0       smulwt	r7, r10, r8
        // 11.    3     0.0    0.0    0.0       ldr.w	r8, [r0, #16]
        // 12.    3     0.0    0.0    0.0       smlabt	r3, r4, r11, r12
        // 13.    3     0.0    0.0    0.0       smlabt	r4, r7, r11, r12
        // 14.    3     0.0    0.0    0.0       smulwt	lr, r10, r8
        // 15.    3     0.0    0.0    0.0       pkhtb	r3, r4, r3, asr #16
        // 16.    3     0.0    0.0    0.0       smulwb	r7, r10, r2
        // 17.    3     0.0    0.0    0.0       str	r3, [r0], #32
        // 18.    3     0.0    0.0    0.0       smlabt	r1, r1, r11, r12
        // 19.    3     0.0    0.0    0.0       smulwt	r3, r10, r6
        // 20.    3     0.0    0.0    0.0       pkhtb	r4, r1, r5, asr #16
        // 21.    3     0.0    0.0    0.0       smulwb	r5, r10, r6
        // 22.    3     0.0    0.0    0.0       str	r4, [r0, #-4]
        // 23.    3     0.0    0.0    0.0       smlabt	r1, lr, r11, r12
        // 24.    3     0.0    0.0    0.0       ldr	r4, [r0, #-20]
        // 25.    3     0.0    0.0    0.0       smulwt	r6, r10, r2
        // 26.    3     0.0    0.0    0.0       smlabt	lr, r7, r11, r12
        // 27.    3     0.0    0.0    0.0       ldr	r2, [r0, #28]
        // 28.    3     0.0    0.0    0.0       smlabt	r6, r6, r11, r12
        // 29.    3     0.0    0.0    0.0       smulwb	r8, r10, r8
        // 30.    3     0.0    0.0    0.0       pkhtb	lr, r6, lr, asr #16
        // 31.    3     0.0    0.0    0.0       smlabt	r6, r5, r11, r12
        // 32.    3     0.0    0.0    0.0       str	lr, [r0, #-8]
        // 33.    3     0.0    0.0    0.0       smlabt	r3, r3, r11, r12
        // 34.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #4]
        // 35.    3     0.0    0.0    0.0       smulwb	r5, r10, r4
        // 36.    3     0.0    0.0    0.0       pkhtb	r3, r3, r6, asr #16
        // 37.    3     0.0    0.0    0.0       smulwt	r7, r10, r4
        // 38.    3     0.0    0.0    0.0       str	r3, [r0, #-12]
        // 39.    3     0.0    0.0    0.0       smlabt	r6, r5, r11, r12
        // 40.    3     0.0    0.0    0.0       ldr	r4, [r0, #-24]
        // 41.    3     0.0    0.0    0.0       smlabt	r3, r8, r11, r12
        // 42.    3     0.0    0.0    0.0       smlabt	r7, r7, r11, r12
        // 43.    3     0.0    0.0    0.0       smulwb	r8, r10, r4
        // 44.    3     0.0    0.0    0.0       pkhtb	r7, r7, r6, asr #16
        // 45.    3     0.0    0.0    0.0       smulwt	r4, r10, r4
        // 46.    3     0.0    0.0    0.0       str	r7, [r0, #-20]
        // 47.    3     0.0    0.0    0.0       smlabt	r8, r8, r11, r12
        // 48.    3     0.0    0.0    0.0       pkhtb	r5, r1, r3, asr #16
        // 49.    3     0.0    0.0    0.0       smlabt	r4, r4, r11, r12
        // 50.    3     0.0    0.0    0.0       str	r5, [r0, #-16]
        // 51.    3     0.0    0.0    0.0       smulwb	r7, r10, lr
        // 52.    3     0.0    0.0    0.0       pkhtb	r5, r4, r8, asr #16
        // 53.    3     0.0    0.0    0.0       smulwt	r1, r10, r2
        // 54.    3     0.0    0.0    0.0       str	r5, [r0, #-24]
        // 55.    3     0.0    0.0    0.0       smulwt	r3, r10, lr
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        subs loop, #1
        bne 1b
                                          // Instructions:    51
                                          // Expected cycles: 31
                                          // Expected IPC:    1.65
                                          //
                                          // Cycle bound:     31.0
                                          // IPC bound:       1.65
                                          //
                                          // Wall time:     3.64s
                                          // User time:     3.64s
                                          //
                                          // ------ cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|-----
        ldr r4, [r0, #24]                 // *..............................
        smlabt r14, r1, r11, r12          // *..............................
        ldr r8, [r0, #20]                 // .*.............................
        smulwb r5, r10, r2                // .*.............................
        ldr r2, [r0, #12]                 // ..*............................
        smulwb r6, r10, r4                // ..*............................
        smulwt r4, r10, r4                // ...*...........................
        smlabt r6, r6, r11, r12           // ....*..........................
        smlabt r1, r4, r11, r12           // .....*.........................
        smulwt r4, r10, r8                // ......*........................
        pkhtb r6, r1, r6, asr #16         // .......*.......................
        smulwb r1, r10, r8                // .......*.......................
        str r6, [r0, #24]                 // ........*......................
        smlabt r4, r4, r11, r12           // ........*......................
        smulwt r6, r10, r2                // .........*.....................
        smlabt r8, r1, r11, r12           // ..........*....................
        smlabt r1, r5, r11, r12           // ...........*...................
        ldr r5, [r0, #8]                  // ............*..................
        smlabt r7, r7, r11, r12           // ............*..................
        pkhtb r4, r4, r8, asr #16         // .............*.................
        smlabt r8, r3, r11, r12           // .............*.................
        pkhtb r3, r14, r1, asr #16        // ..............*................
        smulwb r2, r10, r2                // ..............*................
        pkhtb r1, r8, r7, asr #16         // ...............*...............
        smulwb r14, r10, r5               // ...............*...............
        str r3, [r0, #28]                 // ................*..............
        smulwt r8, r10, r5                // ................*..............
        ldr r7, [r0, #0]                  // .................*.............
        smlabt r14, r14, r11, r12         // .................*.............
        str r4, [r0, #20]                 // ..................*............
        smlabt r8, r8, r11, r12           // ..................*............
        smlabt r5, r2, r11, r12           // ...................*...........
        pkhtb r4, r8, r14, asr #16        // ....................*..........
        smlabt r3, r6, r11, r12           // ....................*..........
        str r1, [r0, #4]                  // .....................*.........
        smulwt r6, r10, r7                // .....................*.........
        pkhtb r3, r3, r5, asr #16         // ......................*........
        smulwb r14, r10, r7               // ......................*........
        ldr r1, [r0, #16]                 // .......................*.......
        smlabt r8, r6, r11, r12           // .......................*.......
        str r3, [r0, #12]                 // ........................*......
        smlabt r6, r14, r11, r12          // ........................*......
        smulwb r14, r10, r1               // .........................*.....
        str r4, [r0, #8]                  // ..........................*....
        smulwt r4, r10, r1                // ..........................*....
        pkhtb r3, r8, r6, asr #16         // ...........................*...
        smlabt r14, r14, r11, r12         // ...........................*...
        str r3, [r0], #32                 // ............................*..
        smlabt r4, r4, r11, r12           // ............................*..
        pkhtb r6, r4, r14, asr #16        // ..............................*
        str r6, [r0, #-16]                // ..............................*

                                            // ------ cycle (expected) ------>
                                            // 0                        25
                                            // |------------------------|-----
        // ldr r8, [r0, #0]                 // .................*.............
        // smlabt r4, r7, r11, r12          // ............*..................
        // smlabt r5, r3, r11, r12          // .............*.................
        // ldr r6, [r0, #20]                // .*.............................
        // smulwb r14, r10, r2              // .*.............................
        // pkhtb r7, r5, r4, asr #16        // ...............*...............
        // smulwb r4, r10, r8               // ......................*........
        // ldr r2, [r0, #24]                // *..............................
        // smlabt r5, r14, r11, r12         // ...........*...................
        // str r7, [r0, #4]                 // .....................*.........
        // smulwt r7, r10, r8               // .....................*.........
        // ldr r8, [r0, #16]                // .......................*.......
        // smlabt r3, r4, r11, r12          // ........................*......
        // smlabt r4, r7, r11, r12          // .......................*.......
        // smulwt r14, r10, r8              // ..........................*....
        // pkhtb r3, r4, r3, asr #16        // ...........................*...
        // smulwb r7, r10, r2               // ..*............................
        // str r3, [r0], #32                // ............................*..
        // smlabt r1, r1, r11, r12          // *..............................
        // smulwt r3, r10, r6               // ......*........................
        // pkhtb r4, r1, r5, asr #16        // ..............*................
        // smulwb r5, r10, r6               // .......*.......................
        // str r4, [r0, #-4]                // ................*..............
        // smlabt r1, r14, r11, r12         // ............................*..
        // ldr r4, [r0, #-20]               // ..*............................
        // smulwt r6, r10, r2               // ...*...........................
        // smlabt r14, r7, r11, r12         // ....*..........................
        // smlabt r6, r6, r11, r12          // .....*.........................
        // smulwb r8, r10, r8               // .........................*.....
        // pkhtb r14, r6, r14, asr #16      // .......*.......................
        // smlabt r6, r5, r11, r12          // ..........*....................
        // str r14, [r0, #-8]               // ........*......................
        // smlabt r3, r3, r11, r12          // ........*......................
        // smulwb r5, r10, r4               // ..............*................
        // pkhtb r3, r3, r6, asr #16        // .............*.................
        // smulwt r7, r10, r4               // .........*.....................
        // str r3, [r0, #-12]               // ..................*............
        // smlabt r6, r5, r11, r12          // ...................*...........
        // ldr r4, [r0, #-24]               // ............*..................
        // smlabt r3, r8, r11, r12          // ...........................*...
        // smlabt r7, r7, r11, r12          // ....................*..........
        // smulwb r8, r10, r4               // ...............*...............
        // pkhtb r7, r7, r6, asr #16        // ......................*........
        // smulwt r4, r10, r4               // ................*..............
        // str r7, [r0, #-20]               // ........................*......
        // smlabt r8, r8, r11, r12          // .................*.............
        // pkhtb r5, r1, r3, asr #16        // ..............................*
        // smlabt r4, r4, r11, r12          // ..................*............
        // str r5, [r0, #-16]               // ..............................*
        // pkhtb r5, r4, r8, asr #16        // ....................*..........
        // str r5, [r0, #-24]               // ..........................*....

        //
        // LLVM MCA STATISTICS (POSTAMBLE) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      5100
        // Total Cycles:      3302
        // Total uOps:        5100
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.54
        // IPC:               1.54
        // Block RThroughput: 29.0
        //
        //
        // Cycles with backend pressure increase [ 21.20% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 9.09% ]
        //   Data Dependencies:      [ 12.11% ]
        //   - Register Dependencies [ 12.11% ]
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
        //  1      2     0.50    *                   ldr	r4, [r0, #24]
        //  1      2     1.00                        smlabt	lr, r1, r11, r12
        //  1      2     0.50    *                   ldr.w	r8, [r0, #20]
        //  1      2     1.00                        smulwb	r5, r10, r2
        //  1      2     0.50    *                   ldr	r2, [r0, #12]
        //  1      2     1.00                        smulwb	r6, r10, r4
        //  1      2     1.00                        smulwt	r4, r10, r4
        //  1      2     1.00                        smlabt	r6, r6, r11, r12
        //  1      2     1.00                        smlabt	r1, r4, r11, r12
        //  1      2     1.00                        smulwt	r4, r10, r8
        //  1      2     1.00                        pkhtb	r6, r1, r6, asr #16
        //  1      2     1.00                        smulwb	r1, r10, r8
        //  1      3     1.00           *            str	r6, [r0, #24]
        //  1      2     1.00                        smlabt	r4, r4, r11, r12
        //  1      2     1.00                        smulwt	r6, r10, r2
        //  1      2     1.00                        smlabt	r8, r1, r11, r12
        //  1      2     1.00                        smlabt	r1, r5, r11, r12
        //  1      2     0.50    *                   ldr	r5, [r0, #8]
        //  1      2     1.00                        smlabt	r7, r7, r11, r12
        //  1      2     1.00                        pkhtb	r4, r4, r8, asr #16
        //  1      2     1.00                        smlabt	r8, r3, r11, r12
        //  1      2     1.00                        pkhtb	r3, lr, r1, asr #16
        //  1      2     1.00                        smulwb	r2, r10, r2
        //  1      2     1.00                        pkhtb	r1, r8, r7, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r5
        //  1      3     1.00           *            str	r3, [r0, #28]
        //  1      2     1.00                        smulwt	r8, r10, r5
        //  1      2     0.50    *                   ldr	r7, [r0]
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      3     1.00           *            str	r4, [r0, #20]
        //  1      2     1.00                        smlabt	r8, r8, r11, r12
        //  1      2     1.00                        smlabt	r5, r2, r11, r12
        //  1      2     1.00                        pkhtb	r4, r8, lr, asr #16
        //  1      2     1.00                        smlabt	r3, r6, r11, r12
        //  1      3     1.00           *            str	r1, [r0, #4]
        //  1      2     1.00                        smulwt	r6, r10, r7
        //  1      2     1.00                        pkhtb	r3, r3, r5, asr #16
        //  1      2     1.00                        smulwb	lr, r10, r7
        //  1      2     0.50    *                   ldr	r1, [r0, #16]
        //  1      2     1.00                        smlabt	r8, r6, r11, r12
        //  1      3     1.00           *            str	r3, [r0, #12]
        //  1      2     1.00                        smlabt	r6, lr, r11, r12
        //  1      2     1.00                        smulwb	lr, r10, r1
        //  1      3     1.00           *            str	r4, [r0, #8]
        //  1      2     1.00                        smulwt	r4, r10, r1
        //  1      2     1.00                        pkhtb	r3, r8, r6, asr #16
        //  1      2     1.00                        smlabt	lr, lr, r11, r12
        //  1      3     1.00           *            str	r3, [r0], #32
        //  1      2     1.00                        smlabt	r4, r4, r11, r12
        //  1      2     1.00                        pkhtb	r6, r4, lr, asr #16
        //  1      3     1.00           *            str	r6, [r0, #-16]
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      400  (12.1%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 300  (9.1%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              202  (6.1%)
        //  1,              1100  (33.3%)
        //  2,              2000  (60.6%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          202  (6.1%)
        //  1,          1100  (33.3%)
        //  2,          2000  (60.6%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    4400
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
        // 4.00   4.00    -     3.00   3.00   29.00  8.00   8.00    -     8.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r4, [r0, #24]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, r1, r11, r12
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #20]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r5, r10, r2
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r2, [r0, #12]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r6, r10, r4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r4, r10, r4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, r6, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r1, r4, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r4, r10, r8
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r6, r1, r6, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r1, r10, r8
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r6, [r0, #24]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r4, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r6, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r1, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r1, r5, r11, r12
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r5, [r0, #8]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r7, r7, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r4, r4, r8, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r3, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, lr, r1, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	r2, r10, r2
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r1, r8, r7, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r5
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #28]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r8, r10, r5
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr	r7, [r0]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [r0, #20]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r8, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r5, r2, r11, r12
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r4, r8, lr, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r3, r6, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0, #4]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r6, r10, r7
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, r3, r5, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r7
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr	r1, [r0, #16]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r8, r6, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #12]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r6, lr, r11, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwb	lr, r10, r1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [r0, #8]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smulwt	r4, r10, r1
        //  -     1.00    -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r3, r8, r6, asr #16
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	lr, lr, r11, r12
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0], #32
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlabt	r4, r4, r11, r12
        // 1.00    -      -      -      -      -     1.00   1.00    -      -      -      -      -     pkhtb	r6, r4, lr, asr #16
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r6, [r0, #-16]
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #24]
        // [0,1]     DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	lr, r1, r11, r12
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0, #20]
        // [0,3]     .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r2
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #12]
        // [0,5]     . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r6, r10, r4
        // [0,6]     .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r4
        // [0,7]     .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, r6, r11, r12
        // [0,8]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r4, r11, r12
        // [0,9]     .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r8
        // [0,10]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r6, r1, r6, asr #16
        // [0,11]    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r1, r10, r8
        // [0,12]    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r6, [r0, #24]
        // [0,13]    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [0,14]    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r2
        // [0,15]    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r1, r11, r12
        // [0,16]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r5, r11, r12
        // [0,17]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r5, [r0, #8]
        // [0,18]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r7, r7, r11, r12
        // [0,19]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r4, r4, r8, asr #16
        // [0,20]    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r3, r11, r12
        // [0,21]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, lr, r1, asr #16
        // [0,22]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r2, r10, r2
        // [0,23]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r1, r8, r7, asr #16
        // [0,24]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r5
        // [0,25]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0, #28]
        // [0,26]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r8, r10, r5
        // [0,27]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r7, [r0]
        // [0,28]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	lr, lr, r11, r12
        // [0,29]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r4, [r0, #20]
        // [0,30]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r8, r11, r12
        // [0,31]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r5, r2, r11, r12
        // [0,32]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r4, r8, lr, asr #16
        // [0,33]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r3, r6, r11, r12
        // [0,34]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r1, [r0, #4]
        // [0,35]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r7
        // [0,36]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, r3, r5, asr #16
        // [0,37]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r7
        // [0,38]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r1, [r0, #16]
        // [0,39]    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r6, r11, r12
        // [0,40]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0, #12]
        // [0,41]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, lr, r11, r12
        // [0,42]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r1
        // [0,43]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r4, [r0, #8]
        // [0,44]    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r1
        // [0,45]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, r8, r6, asr #16
        // [0,46]    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	lr, lr, r11, r12
        // [0,47]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r3, [r0], #32
        // [0,48]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [0,49]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r6, r4, lr, asr #16
        // [0,50]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .   str	r6, [r0, #-16]
        // [1,0]     .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r4, [r0, #24]
        // [1,1]     .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	lr, r1, r11, r12
        // [1,2]     .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .   ldr.w	r8, [r0, #20]
        // [1,3]     .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r5, r10, r2
        // [1,4]     .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .   ldr	r2, [r0, #12]
        // [1,5]     .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r6, r10, r4
        // [1,6]     .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r4
        // [1,7]     .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r6, r6, r11, r12
        // [1,8]     .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r4, r11, r12
        // [1,9]     .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .   smulwt	r4, r10, r8
        // [1,10]    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .   pkhtb	r6, r1, r6, asr #16
        // [1,11]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .   smulwb	r1, r10, r8
        // [1,12]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .   str	r6, [r0, #24]
        // [1,13]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [1,14]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r2
        // [1,15]    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r1, r11, r12
        // [1,16]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .   smlabt	r1, r5, r11, r12
        // [1,17]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .   ldr	r5, [r0, #8]
        // [1,18]    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .   smlabt	r7, r7, r11, r12
        // [1,19]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .   pkhtb	r4, r4, r8, asr #16
        // [1,20]    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .   smlabt	r8, r3, r11, r12
        // [1,21]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .   pkhtb	r3, lr, r1, asr #16
        // [1,22]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .   smulwb	r2, r10, r2
        // [1,23]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .   pkhtb	r1, r8, r7, asr #16
        // [1,24]    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r5
        // [1,25]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .   str	r3, [r0, #28]
        // [1,26]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .   smulwt	r8, r10, r5
        // [1,27]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .   ldr	r7, [r0]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .   smlabt	lr, lr, r11, r12
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .   str	r4, [r0, #20]
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .   smlabt	r8, r8, r11, r12
        // [1,31]    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .   smlabt	r5, r2, r11, r12
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .   pkhtb	r4, r8, lr, asr #16
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .   smlabt	r3, r6, r11, r12
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .   str	r1, [r0, #4]
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .   smulwt	r6, r10, r7
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .   pkhtb	r3, r3, r5, asr #16
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .   smulwb	lr, r10, r7
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .   ldr	r1, [r0, #16]
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .   smlabt	r8, r6, r11, r12
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .   str	r3, [r0, #12]
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .   smlabt	r6, lr, r11, r12
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .   smulwb	lr, r10, r1
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .   str	r4, [r0, #8]
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .   smulwt	r4, r10, r1
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .   pkhtb	r3, r8, r6, asr #16
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .   smlabt	lr, lr, r11, r12
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .   str	r3, [r0], #32
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .   pkhtb	r6, r4, lr, asr #16
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .   str	r6, [r0, #-16]
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .   ldr	r4, [r0, #24]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .   smlabt	lr, r1, r11, r12
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .   ldr.w	r8, [r0, #20]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .   smulwb	r5, r10, r2
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .   ldr	r2, [r0, #12]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .   smulwb	r6, r10, r4
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .   smulwt	r4, r10, r4
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .   smlabt	r6, r6, r11, r12
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .   smlabt	r1, r4, r11, r12
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .   smulwt	r4, r10, r8
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .   pkhtb	r6, r1, r6, asr #16
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .   smulwb	r1, r10, r8
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .   str	r6, [r0, #24]
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .   smlabt	r4, r4, r11, r12
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .   smulwt	r6, r10, r2
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .   smlabt	r8, r1, r11, r12
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .   smlabt	r1, r5, r11, r12
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .   ldr	r5, [r0, #8]
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .   smlabt	r7, r7, r11, r12
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .   pkhtb	r4, r4, r8, asr #16
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .   smlabt	r8, r3, r11, r12
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .   pkhtb	r3, lr, r1, asr #16
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .   smulwb	r2, r10, r2
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .   pkhtb	r1, r8, r7, asr #16
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .   smulwb	lr, r10, r5
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .   str	r3, [r0, #28]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .   smulwt	r8, r10, r5
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .   ldr	r7, [r0]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .   smlabt	lr, lr, r11, r12
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .   str	r4, [r0, #20]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .   smlabt	r8, r8, r11, r12
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .   smlabt	r5, r2, r11, r12
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .   pkhtb	r4, r8, lr, asr #16
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .   smlabt	r3, r6, r11, r12
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .   str	r1, [r0, #4]
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .   smulwt	r6, r10, r7
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .   pkhtb	r3, r3, r5, asr #16
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .   smulwb	lr, r10, r7
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .   ldr	r1, [r0, #16]
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .   smlabt	r8, r6, r11, r12
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .   str	r3, [r0, #12]
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .   smlabt	r6, lr, r11, r12
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .   smulwb	lr, r10, r1
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .   str	r4, [r0, #8]
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .   smulwt	r4, r10, r1
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .   pkhtb	r3, r8, r6, asr #16
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .   smlabt	lr, lr, r11, r12
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .   str	r3, [r0], #32
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .   smlabt	r4, r4, r11, r12
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .   pkhtb	r6, r4, lr, asr #16
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE   str	r6, [r0, #-16]
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r4, [r0, #24]
        // 1.     3     0.0    0.0    0.0       smlabt	lr, r1, r11, r12
        // 2.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #20]
        // 3.     3     0.0    0.0    0.0       smulwb	r5, r10, r2
        // 4.     3     0.0    0.0    0.0       ldr	r2, [r0, #12]
        // 5.     3     0.0    0.0    0.0       smulwb	r6, r10, r4
        // 6.     3     0.0    0.0    0.0       smulwt	r4, r10, r4
        // 7.     3     0.0    0.0    0.0       smlabt	r6, r6, r11, r12
        // 8.     3     0.0    0.0    0.0       smlabt	r1, r4, r11, r12
        // 9.     3     0.0    0.0    0.0       smulwt	r4, r10, r8
        // 10.    3     0.0    0.0    0.0       pkhtb	r6, r1, r6, asr #16
        // 11.    3     0.0    0.0    0.0       smulwb	r1, r10, r8
        // 12.    3     0.0    0.0    0.0       str	r6, [r0, #24]
        // 13.    3     0.0    0.0    0.0       smlabt	r4, r4, r11, r12
        // 14.    3     0.0    0.0    0.0       smulwt	r6, r10, r2
        // 15.    3     0.0    0.0    0.0       smlabt	r8, r1, r11, r12
        // 16.    3     0.0    0.0    0.0       smlabt	r1, r5, r11, r12
        // 17.    3     0.0    0.0    0.0       ldr	r5, [r0, #8]
        // 18.    3     0.0    0.0    0.0       smlabt	r7, r7, r11, r12
        // 19.    3     0.0    0.0    0.0       pkhtb	r4, r4, r8, asr #16
        // 20.    3     0.0    0.0    0.0       smlabt	r8, r3, r11, r12
        // 21.    3     0.0    0.0    0.0       pkhtb	r3, lr, r1, asr #16
        // 22.    3     0.0    0.0    0.0       smulwb	r2, r10, r2
        // 23.    3     0.0    0.0    0.0       pkhtb	r1, r8, r7, asr #16
        // 24.    3     0.0    0.0    0.0       smulwb	lr, r10, r5
        // 25.    3     0.0    0.0    0.0       str	r3, [r0, #28]
        // 26.    3     0.0    0.0    0.0       smulwt	r8, r10, r5
        // 27.    3     0.0    0.0    0.0       ldr	r7, [r0]
        // 28.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 29.    3     0.0    0.0    0.0       str	r4, [r0, #20]
        // 30.    3     0.0    0.0    0.0       smlabt	r8, r8, r11, r12
        // 31.    3     0.0    0.0    0.0       smlabt	r5, r2, r11, r12
        // 32.    3     0.0    0.0    0.0       pkhtb	r4, r8, lr, asr #16
        // 33.    3     0.0    0.0    0.0       smlabt	r3, r6, r11, r12
        // 34.    3     0.0    0.0    0.0       str	r1, [r0, #4]
        // 35.    3     0.0    0.0    0.0       smulwt	r6, r10, r7
        // 36.    3     0.0    0.0    0.0       pkhtb	r3, r3, r5, asr #16
        // 37.    3     0.0    0.0    0.0       smulwb	lr, r10, r7
        // 38.    3     0.0    0.0    0.0       ldr	r1, [r0, #16]
        // 39.    3     0.0    0.0    0.0       smlabt	r8, r6, r11, r12
        // 40.    3     0.0    0.0    0.0       str	r3, [r0, #12]
        // 41.    3     0.0    0.0    0.0       smlabt	r6, lr, r11, r12
        // 42.    3     0.0    0.0    0.0       smulwb	lr, r10, r1
        // 43.    3     0.0    0.0    0.0       str	r4, [r0, #8]
        // 44.    3     0.0    0.0    0.0       smulwt	r4, r10, r1
        // 45.    3     0.0    0.0    0.0       pkhtb	r3, r8, r6, asr #16
        // 46.    3     0.0    0.0    0.0       smlabt	lr, lr, r11, r12
        // 47.    3     0.0    0.0    0.0       str	r3, [r0], #32
        // 48.    3     0.0    0.0    0.0       smlabt	r4, r4, r11, r12
        // 49.    3     0.0    0.0    0.0       pkhtb	r6, r4, lr, asr #16
        // 50.    3     0.0    0.0    0.0       str	r6, [r0, #-16]
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (POSTAMBLE) END
        //

 .unreq poly
 .unreq poly0
 .unreq poly1
 .unreq poly2
 .unreq poly3
 .unreq poly4
 .unreq poly5
 .unreq poly6
 .unreq poly7
 .unreq loop
 .unreq plantconst
 .unreq q
 .unreq qa
 .unreq tmp
 pop     {r4-r11, pc}

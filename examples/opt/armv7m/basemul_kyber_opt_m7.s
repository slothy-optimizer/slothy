.syntax unified
.cpu cortex-m4
.thumb

// q locate in the top half of the register
.macro plant_red q, qa, qinv, tmp
 mul \tmp, \tmp, \qinv
 // tmp*qinv mod 2^2n/ 2^n; in high half
 smlatt \tmp, \tmp, \q, \qa
 // result in high half
.endm

.global basemul_asm_opt_m7
.type basemul_asm_opt_m7, %function
.align 2
basemul_asm_opt_m7:
 push {r4-r11, lr}

 rptr    .req r0
 aptr    .req r1
 bptr    .req r2
 zetaptr .req r3
 poly0   .req r4
 poly1   .req r6
 poly2   .req r5
 poly3   .req r7
 q       .req r8
 qa      .req r14
 qinv    .req r9
 tmp     .req r10
 tmp2    .req r11
 zeta    .req r12
 loop    .req r14

 // movw qa, #26632
 movt  q, #3329
 ### qinv=0x6ba8f301
 movw qinv, #62209
 movt qinv, #27560

 movw loop, #64
                                  // Instructions:    3
                                  // Expected cycles: 2
                                  // Expected IPC:    1.50
                                  //
                                  // Cycle bound:     2.0
                                  // IPC bound:       1.50
                                  //
                                  // Wall time:     0.00s
                                  // User time:     0.00s
                                  //
                                  // ----- cycle (expected) ------>
                                  // 0                        25
                                  // |------------------------|----
        ldr r10, [r1], #8         // *.............................
        ldr.w r4, [r3], #4        // *.............................
        ldr r12, [r2], #8         // .*............................

                                   // ------ cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|-----
        // ldr r10, [r1], #8       // *..............................
        // ldr.w r4, [r3], #4      // *..............................
        // ldr r12, [r2], #8       // .*.............................

        push {r14}
        vmov r14, s25
        sub r14, r14, #1
        vmov s25, r14
        pop {r14}
1:
                                           // Instructions:    32
                                           // Expected cycles: 20
                                           // Expected IPC:    1.60
                                           //
                                           // Cycle bound:     19.0
                                           // IPC bound:       1.68
                                           //
                                           // Wall time:     3.03s
                                           // User time:     3.03s
                                           //
                                           // ----- cycle (expected) ------>
                                           // 0                        25
                                           // |------------------------|----
        ldr r11, [r1, #-4]                 // *.............................
        smuadx r7, r10, r12                // *.............................
        movw r6, #26632                    // .*............................
        smulwt r5, r4, r12                 // .*............................
        vmov s25, r14                    // ..*...........................
        mul r14, r7, r9                    // ..*...........................
        ldr r7, [r2, #-4]                  // ...*..........................
        smlabt r5, r5, r8, r6              // ...*..........................
        neg r4, r4                         // ....*.........................
        smlatt r14, r14, r8, r6            // ....*.........................
        smulwt r4, r4, r7                  // .....*........................
        smultt r5, r10, r5                 // ......*.......................
        smlabt r4, r4, r8, r6              // .......*......................
        smlabb r12, r10, r12, r5           // ........*.....................
        ldr r10, [r1], #8                  // .........e....................
        smultt r5, r11, r4                 // .........*....................
        ldr.w r4, [r3], #4                 // ..........e...................
        mul r12, r12, r9                   // ..........*...................
        smlabb r5, r11, r7, r5             // ...........*..................
        smlatt r12, r12, r8, r6            // ............*.................
        smuadx r11, r11, r7                // .............*................
        mul r5, r5, r9                     // ..............*...............
        pkhtb r7, r14, r12, asr #16        // ...............*..............
        mul r12, r11, r9                   // ...............*..............
        vmov r14, s25                    // ................*.............
        smlatt r5, r5, r8, r6              // ................*.............
        subs.w r14, #1                     // .................*............
        smlatt r6, r12, r8, r6             // .................*............
        str r7, [r0], #4                   // ..................*...........
        ldr r12, [r2], #8                  // ..................e...........
        pkhtb r11, r6, r5, asr #16         // ...................*..........
        str r11, [r0], #4                  // ...................*..........

                                             // ------ cycle (expected) ------>
                                             // 0                        25
                                             // |------------------------|-----
        // vmov s0, r14                    // ...........'.*.................
        // movw r14, #26632                  // ...........'*..................
        // ldr r5, [r1, #4]                  // ...........*...................
        // ldr r4, [r1], #8                  // e..........'........~..........
        // ldr r7, [r2, #4]                  // ...........'..*................
        // ldr r6, [r2], #8                  // .........e.'.................~.
        // ldr.w r12, [r3], #4               // .e.........'.........~.........
        // smulwt r10, r12, r6               // ...........'*..................
        // smlabt r10, r10, r8, r14          // ...........'..*................
        // smultt r10, r4, r10               // ...........'.....*.............
        // smlabb r10, r4, r6, r10           // ...........'.......*...........
        // mul r10, r10, r9                  // .~.........'.........*.........
        // smlatt r10, r10, r8, r14          // ...~.......'...........*.......
        // smuadx r11, r4, r6                // ...........*...................
        // mul r11, r11, r9                  // ...........'.*.................
        // smlatt r11, r11, r8, r14          // ...........'...*...............
        // pkhtb r10, r11, r10, asr #16      // ......~....'..............*....
        // str r10, [r0], #4                 // .........~.'.................*.
        // neg r12, r12                      // ...........'...*...............
        // smulwt r10, r12, r7               // ...........'....*..............
        // smlabt r10, r10, r8, r14          // ...........'......*............
        // smultt r10, r5, r10               // ~..........'........*..........
        // smlabb r10, r5, r7, r10           // ..~........'..........*........
        // mul r10, r10, r9                  // .....~.....'.............*.....
        // smlatt r10, r10, r8, r14          // .......~...'...............*...
        // smuadx r11, r5, r7                // ....~......'............*......
        // mul r11, r11, r9                  // ......~....'..............*....
        // smlatt r11, r11, r8, r14          // ........~..'................*..
        // pkhtb r10, r11, r10, asr #16      // ..........~'..................*
        // str r10, [r0], #4                 // ..........~'..................*
        // vmov r14, s0                    // .......~...'...............*...
        // subs.w r14, #1                    // ........~..'................*..

        bne 1b
                                           // Instructions:    29
                                           // Expected cycles: 20
                                           // Expected IPC:    1.45
                                           //
                                           // Cycle bound:     20.0
                                           // IPC bound:       1.45
                                           //
                                           // Wall time:     0.13s
                                           // User time:     0.13s
                                           //
                                           // ----- cycle (expected) ------>
                                           // 0                        25
                                           // |------------------------|----
        vmov s5, r14                     // *.............................
        smulwt r6, r4, r12                 // *.............................
        neg r4, r4                         // .*............................
        smuadx r11, r10, r12               // .*............................
        movw r5, #26632                    // ..*...........................
        smlabt r6, r6, r8, r5              // ..*...........................
        ldr r14, [r1, #-4]                 // ...*..........................
        mul r11, r11, r9                   // ...*..........................
        ldr r7, [r2, #-4]                  // ....*.........................
        smultt r6, r10, r6                 // ....*.........................
        smlabb r12, r10, r12, r6           // .....*........................
        smulwt r4, r4, r7                  // ......*.......................
        smlatt r6, r11, r8, r5             // .......*......................
        smlabt r4, r4, r8, r5              // ........*.....................
        smuadx r11, r14, r7                // .........*....................
        smultt r4, r14, r4                 // ..........*...................
        smlabb r4, r14, r7, r4             // ...........*..................
        vmov r14, s5                     // ............*.................
        mul r12, r12, r9                   // ............*.................
        subs.w r14, #1                     // .............*................
        mul r4, r4, r9                     // .............*................
        smlatt r12, r12, r8, r5            // ..............*...............
        mul r11, r11, r9                   // ...............*..............
        smlatt r4, r4, r8, r5              // ................*.............
        pkhtb r12, r6, r12, asr #16        // .................*............
        smlatt r6, r11, r8, r5             // .................*............
        str r12, [r0], #4                  // ..................*...........
        pkhtb r12, r6, r4, asr #16         // ...................*..........
        str r12, [r0], #4                  // ...................*..........

                                            // ------ cycle (expected) ------>
                                            // 0                        25
                                            // |------------------------|-----
        // ldr r11, [r1, #-4]               // ...*...........................
        // smuadx r7, r10, r12              // .*.............................
        // movw r6, #26632                  // ..*............................
        // smulwt r5, r4, r12               // *..............................
        // vmov s25, r14                  // *..............................
        // mul r14, r7, r9                  // ...*...........................
        // ldr r7, [r2, #-4]                // ....*..........................
        // smlabt r5, r5, r8, r6            // ..*............................
        // neg r4, r4                       // .*.............................
        // smlatt r14, r14, r8, r6          // .......*.......................
        // smulwt r4, r4, r7                // ......*........................
        // smultt r5, r10, r5               // ....*..........................
        // smlabt r4, r4, r8, r6            // ........*......................
        // smlabb r12, r10, r12, r5         // .....*.........................
        // smultt r5, r11, r4               // ..........*....................
        // mul r12, r12, r9                 // ............*..................
        // smlabb r5, r11, r7, r5           // ...........*...................
        // smlatt r12, r12, r8, r6          // ..............*................
        // smuadx r11, r11, r7              // .........*.....................
        // mul r5, r5, r9                   // .............*.................
        // pkhtb r7, r14, r12, asr #16      // .................*.............
        // mul r12, r11, r9                 // ...............*...............
        // vmov r14, s25                  // ............*..................
        // smlatt r5, r5, r8, r6            // ................*..............
        // subs.w r14, #1                   // .............*.................
        // smlatt r6, r12, r8, r6           // .................*.............
        // str r7, [r0], #4                 // ..................*............
        // pkhtb r11, r6, r5, asr #16       // ...................*...........
        // str r11, [r0], #4                // ...................*...........

    pop {r4-r11, pc}
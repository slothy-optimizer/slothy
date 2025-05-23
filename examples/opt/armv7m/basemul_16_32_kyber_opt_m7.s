.syntax unified
.cpu cortex-m4
.thumb

// void basemul_asm_opt_16_32(int32_t *, const int16_t *, const int16_t *, const int16_t *)
.global basemul_asm_opt_16_32_opt_m7
.type basemul_asm_opt_16_32_opt_m7, %function
.align 2
basemul_asm_opt_16_32_opt_m7:
  push {r4-r11, lr}

  rptr_tmp  .req r0
  aptr      .req r1
  bptr      .req r2
  aprimeptr .req r3
  poly0     .req r4
  poly1     .req r6
  poly2     .req r5
  poly3     .req r7
  q         .req r8
  qa        .req r9
  qinv      .req r10
  tmp       .req r11
  tmp2      .req r12
  loop      .req r14

  // movw qa, #26632
 // movt  q, #3329
 ### qinv=0x6ba8f301
 // movw qinv, #62209
 // movt qinv, #27560

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
        ldr r6, [r3], #8         // *.............................
        ldr r4, [r2], #4         // *.............................
        ldr r11, [r2], #4        // .*............................

                                  // ------ cycle (expected) ------>
                                  // 0                        25
                                  // |------------------------|-----
        // ldr r6, [r3], #8       // *..............................
        // ldr r4, [r2], #4       // *..............................
        // ldr r11, [r2], #4      // .*.............................

        sub r14, r14, #1
1:
                                   // Instructions:    15
                                   // Expected cycles: 8
                                   // Expected IPC:    1.88
                                   //
                                   // Cycle bound:     11.0
                                   // IPC bound:       1.36
                                   //
                                   // Wall time:     0.12s
                                   // User time:     0.12s
                                   //
                                   // ----- cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|----
        smuad r12, r6, r4          // *.............................
        ldr r8, [r1], #4           // *.............................
        str r12, [r0], #4          // .*............................
        ldr r6, [r3], #8           // .e............................
        smuadx r10, r8, r4         // ..*...........................
        ldr r8, [r1], #4           // ..*...........................
        str r10, [r0], #4          // ...*..........................
        ldr r10, [r3, #-12]        // ...*..........................
        smuadx r8, r8, r11         // ....*.........................
        subs.w r14, r14, #1        // ....*.........................
        smuad r10, r10, r11        // .....*........................
        ldr r4, [r2], #4           // .....e........................
        str r10, [r0], #4          // ......*.......................
        ldr r11, [r2], #4          // ......e.......................
        str r8, [r0], #4           // .......*......................

                                    // ------ cycle (expected) ------>
                                    // 0                        25
                                    // |------------------------|-----
        // ldr r4, [r1], #4         // .......*.......~.......~.......
        // ldr r6, [r2], #4         // ....e..'....~..'....~..'....~..
        // ldr r5, [r1], #4         // .~.....'.*.....'.~.....'.~.....
        // ldr r7, [r2], #4         // .....e.'.....~.'.....~.'.....~.
        // ldr.w r11, [r3, #4]      // ..~....'..*....'..~....'..~....
        // ldr r12, [r3], #8        // e......'~......'~......'~......
        // smuad r12, r12, r6       // .......*.......~.......~.......
        // str r12, [r0], #4        // ~......'*......'~......'~......
        // smuadx r12, r4, r6       // .~.....'.*.....'.~.....'.~.....
        // str r12, [r0], #4        // ..~....'..*....'..~....'..~....
        // smuad r12, r11, r7       // ....~..'....*..'....~..'....~..
        // str r12, [r0], #4        // .....~.'.....*.'.....~.'.....~.
        // smuadx r12, r5, r7       // ...~...'...*...'...~...'...~...
        // str r12, [r0], #4        // ......~'......*'......~'.......
        // subs.w r14, r14, #1      // ...~...'...*...'...~...'...~...

        bne 1b
                                    // Instructions:    12
                                    // Expected cycles: 8
                                    // Expected IPC:    1.50
                                    //
                                    // Cycle bound:     8.0
                                    // IPC bound:       1.50
                                    //
                                    // Wall time:     0.01s
                                    // User time:     0.01s
                                    //
                                    // ----- cycle (expected) ------>
                                    // 0                        25
                                    // |------------------------|----
        smuad r10, r6, r4           // *.............................
        ldr r9, [r1], #4            // *.............................
        subs.w r14, r14, #1         // .*............................
        str r10, [r0], #4           // .*............................
        smuadx r4, r9, r4           // ..*...........................
        ldr r10, [r1], #4           // ..*...........................
        str r4, [r0], #4            // ...*..........................
        ldr r4, [r3, #-4]           // ...*..........................
        smuadx r10, r10, r11        // ....*.........................
        smuad r4, r4, r11           // .....*........................
        str r4, [r0], #4            // ......*.......................
        str r10, [r0], #4           // .......*......................

                                    // ------ cycle (expected) ------>
                                    // 0                        25
                                    // |------------------------|-----
        // smuad r12, r6, r4        // *..............................
        // ldr r8, [r1], #4         // *..............................
        // str r12, [r0], #4        // .*.............................
        // smuadx r10, r8, r4       // ..*............................
        // ldr r8, [r1], #4         // ..*............................
        // str r10, [r0], #4        // ...*...........................
        // ldr r10, [r3, #-4]       // ...*...........................
        // smuadx r8, r8, r11       // ....*..........................
        // subs.w r14, r14, #1      // .*.............................
        // smuad r10, r10, r11      // .....*.........................
        // str r10, [r0], #4        // ......*........................
        // str r8, [r0], #4         // .......*.......................


  pop {r4-r11, pc}

.size basemul_asm_opt_16_32_opt_m7, .-basemul_asm_opt_16_32_opt_m7
.syntax unified
.cpu cortex-m4
.thumb

.macro doublebasemul_frombytes_asm_16_32 rptr_tmp, bptr, zeta, poly0, poly2, poly1, poly3, tmp, q, qa, qinv
  ldr \poly0, [\bptr], #4
  ldr \poly2, [\bptr], #4

  smulwt \tmp, \zeta, \poly1
 smlabt \tmp, \tmp, \q, \qa
 smultt \tmp, \poly0, \tmp
 smlabb \tmp, \poly0, \poly1, \tmp
  str \tmp, [\rptr_tmp], #4

  smuadx \tmp, \poly0, \poly1
  str \tmp, [\rptr_tmp], #4

  neg \zeta, \zeta

  smulwt \tmp, \zeta, \poly3
 smlabt \tmp, \tmp, \q, \qa
 smultt \tmp, \poly2, \tmp
 smlabb \tmp, \poly2, \poly3, \tmp
  str \tmp, [\rptr_tmp], #4

  smuadx \tmp, \poly2, \poly3
  str \tmp, [\rptr_tmp], #4
.endm

// reduce 2 registers
.macro deserialize aptr, tmp, tmp2, tmp3, t0, t1
 ldrb.w \tmp, [\aptr, #2]
 ldrh.w \tmp2, [\aptr, #3]
 ldrb.w \tmp3, [\aptr, #5]
 ldrh.w \t0, [\aptr], #6

 ubfx.w \t1, \t0, #12, #4
 ubfx.w \t0, \t0, #0, #12
 orr \t1, \t1, \tmp, lsl #4
 orr \t0, \t0, \t1, lsl #16
 // tmp is free now
 ubfx.w \t1, \tmp2, #12, #4
 ubfx.w \tmp, \tmp2, #0, #12
 orr \t1, \t1, \tmp3, lsl #4
 orr \t1, \tmp, \t1, lsl #16
.endm

// void frombytes_mul_asm_16_32(int32_t *r_tmp, const int16_t *b, const unsigned char *c, const int32_t zetas[64])
.global frombytes_mul_asm_16_32_opt_m7
.type frombytes_mul_asm_16_32_opt_m7, %function
.align 2
frombytes_mul_asm_16_32_opt_m7:
  push {r4-r11, r14}

  rptr_tmp .req r0
  bptr     .req r1
  aptr     .req r2
  zetaptr  .req r3
  t0       .req r4
 t1       .req r5
 tmp      .req r6
 tmp2     .req r7
 tmp3     .req r8
 q        .req r9
 qa       .req r10
 qinv     .req r11
 zeta     .req r12
 ctr      .req r14

  movw qa, #26632
 movt  q, #3329
 ### qinv=0x6ba8f301
 movw qinv, #62209
 movt qinv, #27560

  add ctr, rptr_tmp, #64*4*4
                                       // Instructions:    20
                                       // Expected cycles: 12
                                       // Expected IPC:    1.67
                                       //
                                       // Cycle bound:     12.0
                                       // IPC bound:       1.67
                                       //
                                       // Wall time:     0.32s
                                       // User time:     0.32s
                                       //
                                       // ----- cycle (expected) ------>
                                       // 0                        25
                                       // |------------------------|----
        ldrb.w r5, [r2, #5]            // *.............................
        ldrh.w r12, [r2, #3]           // *.............................
        ldrb.w r8, [r2, #2]            // .*............................
        ldrh.w r6, [r2], #6            // .*............................
        ubfx.w r4, r12, #0, #12        // ..*...........................
        ubfx.w r7, r12, #12, #4        // ..*...........................
        orr r5, r7, r5, lsl #4         // ...*..........................
        ubfx.w r7, r6, #12, #4         // ...*..........................
        ldr.w r12, [r3], #4            // ....*.........................
        orr r7, r7, r8, lsl #4         // ....*.........................
        ubfx.w r6, r6, #0, #12         // .....*........................
        ldr r11, [r1], #4              // .....*........................
        orr r6, r6, r7, lsl #16        // ......*.......................
        smulwt r7, r12, r6             // .......*......................
        neg r12, r12                   // .......*......................
        ldr r8, [r1], #4               // ........*.....................
        smlabt r7, r7, r9, r10         // .........*....................
        orr r4, r4, r5, lsl #16        // .........*....................
        smulwt r5, r12, r4             // ..........*...................
        smultt r12, r11, r7            // ...........*..................

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // ldrb.w r7, [r2, #2]           // .*.............................
        // ldrh.w r12, [r2, #3]          // *..............................
        // ldrb.w r5, [r2, #5]           // *..............................
        // ldrh.w r11, [r2], #6          // .*.............................
        // ubfx.w r6, r11, #12, #4       // ...*...........................
        // orr r6, r6, r7, lsl #4        // ....*..........................
        // ldr.w r7, [r3], #4            // ....*..........................
        // ubfx.w r4, r11, #0, #12       // .....*.........................
        // ldr r11, [r1], #4             // .....*.........................
        // orr r6, r4, r6, lsl #16       // ......*........................
        // ubfx.w r4, r12, #12, #4       // ..*............................
        // orr r4, r4, r5, lsl #4        // ...*...........................
        // smulwt r5, r7, r6             // .......*.......................
        // neg r7, r7                    // .......*.......................
        // ubfx.w r12, r12, #0, #12      // ..*............................
        // orr r4, r12, r4, lsl #16      // .........*.....................
        // smlabt r12, r5, r9, r10       // .........*.....................
        // smulwt r5, r7, r4             // ..........*....................
        // smultt r12, r11, r12          // ...........*...................
        // ldr r8, [r1], #4              // ........*......................

1:
                                        // Instructions:    30
                                        // Expected cycles: 15
                                        // Expected IPC:    2.00
                                        //
                                        // Cycle bound:     35.0
                                        // IPC bound:       0.86
                                        //
                                        // Wall time:     1557.76s
                                        // User time:     1557.76s
                                        //
                                        // ----- cycle (expected) ------>
                                        // 0                        25
                                        // |------------------------|----
        ldrb.w r7, [r2, #2]             // e.............................
        smlabt r5, r5, r9, r10          // *.............................
        smlabb r12, r11, r6, r12        // .*............................
        str r12, [r0], #4               // .*............................
        smuadx r11, r11, r6             // ..*...........................
        ldrh.w r12, [r2, #3]            // ..e...........................
        smultt r6, r8, r5               // ...*..........................
        str r11, [r0], #4               // ...*..........................
        ldrb.w r5, [r2, #5]             // ....e.........................
        ldrh.w r11, [r2], #6            // ....e.........................
        smlabb r6, r8, r4, r6           // .....*........................
        str r6, [r0], #4                // .....*........................
        ubfx.w r6, r11, #12, #4         // ......e.......................
        smuadx r8, r8, r4               // ......*.......................
        orr r6, r6, r7, lsl #4          // .......e......................
        ldr.w r7, [r3], #4              // .......e......................
        ubfx.w r4, r11, #0, #12         // ........e.....................
        ldr r11, [r1], #4               // ........e.....................
        orr r6, r4, r6, lsl #16         // .........e....................
        ubfx.w r4, r12, #12, #4         // .........e....................
        orr r4, r4, r5, lsl #4          // ..........e...................
        smulwt r5, r7, r6               // ..........e...................
        neg r7, r7                      // ...........e..................
        ubfx.w r12, r12, #0, #12        // ...........e..................
        orr r4, r12, r4, lsl #16        // ............e.................
        smlabt r12, r5, r9, r10         // ............e.................
        smulwt r5, r7, r4               // .............e................
        str r8, [r0], #4                // .............*................
        smultt r12, r11, r12            // ..............e...............
        ldr r8, [r1], #4                // ..............e...............

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // ldr.w r12, [r3], #4           // .......e.......'......~........
        // ldrb.w r6, [r2, #2]           // e..............~...............
        // ldrh.w r7, [r2, #3]           // ..e............'.~.............
        // ldrb.w r8, [r2, #5]           // ....e..........'...~...........
        // ldrh.w r4, [r2], #6           // ....e..........'...~...........
        // ubfx.w r5, r4, #12, #4        // ......e........'.....~.........
        // ubfx.w r4, r4, #0, #12        // ........e......'.......~.......
        // orr r5, r5, r6, lsl #4        // .......e.......'......~........
        // orr r4, r4, r5, lsl #16       // .........e.....'........~......
        // ubfx.w r5, r7, #12, #4        // .........e.....'........~......
        // ubfx.w r6, r7, #0, #12        // ...........e...'..........~....
        // orr r5, r5, r8, lsl #4        // ..........e....'.........~.....
        // orr r5, r6, r5, lsl #16       // ............e..'...........~...
        // ldr r6, [r1], #4              // ........e......'.......~.......
        // ldr r7, [r1], #4              // ..............e'.............~.
        // smulwt r8, r12, r4            // ..........e....'.........~.....
        // smlabt r8, r8, r9, r10        // ............e..'...........~...
        // smultt r8, r6, r8             // ..............e'.............~.
        // smlabb r8, r6, r4, r8         // .~.............'*..............
        // str r8, [r0], #4              // .~.............'*..............
        // smuadx r8, r6, r4             // ..~............'.*.............
        // str r8, [r0], #4              // ...~...........'..*............
        // neg r12, r12                  // ...........e...'..........~....
        // smulwt r8, r12, r5            // .............e.'............~..
        // smlabt r8, r8, r9, r10        // ~..............*...............
        // smultt r8, r7, r8             // ...~...........'..*............
        // smlabb r8, r7, r5, r8         // .....~.........'....*..........
        // str r8, [r0], #4              // .....~.........'....*..........
        // smuadx r8, r7, r5             // ......~........'.....*.........
        // str r8, [r0], #4              // .............~.'............*..

        cmp rptr_tmp, ctr
        bne 1b
                                        // Instructions:    10
                                        // Expected cycles: 8
                                        // Expected IPC:    1.25
                                        //
                                        // Cycle bound:     8.0
                                        // IPC bound:       1.25
                                        //
                                        // Wall time:     0.12s
                                        // User time:     0.12s
                                        //
                                        // ----- cycle (expected) ------>
                                        // 0                        25
                                        // |------------------------|----
        smlabt r5, r5, r9, r10          // *.............................
        smlabb r12, r11, r6, r12        // .*............................
        str r12, [r0], #4               // .*............................
        smuadx r11, r11, r6             // ..*...........................
        smultt r12, r8, r5              // ...*..........................
        str r11, [r0], #4               // ...*..........................
        smuadx r11, r8, r4              // ....*.........................
        smlabb r12, r8, r4, r12         // .....*........................
        str r12, [r0], #4               // .....*........................
        str r11, [r0], #4               // .......*......................

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // smlabt r5, r5, r9, r10        // *..............................
        // smlabb r12, r11, r6, r12      // .*.............................
        // str r12, [r0], #4             // .*.............................
        // smuadx r11, r11, r6           // ..*............................
        // smultt r6, r8, r5             // ...*...........................
        // str r11, [r0], #4             // ...*...........................
        // smlabb r6, r8, r4, r6         // .....*.........................
        // str r6, [r0], #4              // .....*.........................
        // smuadx r8, r8, r4             // ....*..........................
        // str r8, [r0], #4              // .......*.......................


pop {r4-r11, pc}
// 2
.macro barrett_32 a, Qbar, Q, tmp
    smmulr.w \tmp, \a, \Qbar
    mls.w \a, \tmp, \Q, \a
.endm

.syntax unified
.cpu cortex-m4

.align 2
.global __asm_asymmetric_mul_257_16_opt_m7
.type __asm_asymmetric_mul_257_16_opt_m7, %function
__asm_asymmetric_mul_257_16_opt_m7:
    push.w {r4-r11, lr}

    .equ width, 4

    add.w r12, r0, #256*width
                                     // Instructions:    4
                                     // Expected cycles: 2
                                     // Expected IPC:    2.00
                                     //
                                     // Wall time:     0.07s
                                     // User time:     0.07s
                                     //
                                     // ----- cycle (expected) ------>
                                     // 0                        25
                                     // |------------------------|----
        ldr.w r7, [r1, #4]           // *.............................
        ldr.w r11, [r1], #2*4        // *.............................
        ldr.w r10, [r2, #4]          // .*............................
        ldr.w r5, [r2], #2*4         // .*............................

                                      // ------ cycle (expected) ------>
                                      // 0                        25
                                      // |------------------------|-----
        // ldr.w r7, [r1, #4]         // *..............................
        // ldr.w r11, [r1], #2*4      // *..............................
        // ldr.w r10, [r2, #4]        // .*.............................
        // ldr.w r5, [r2], #2*4       // .*.............................

        sub r12, r12, #16
1:
                                     // Instructions:    14
                                     // Expected cycles: 8
                                     // Expected IPC:    1.75
                                     //
                                     // Wall time:     1.31s
                                     // User time:     1.31s
                                     //
                                     // ----- cycle (expected) ------>
                                     // 0                        25
                                     // |------------------------|----
        ldr.w r9, [r3, #4]           // *.............................
        ldr.w r6, [r3], #2*4         // *.............................
        smuadx r5, r11, r5           // .*............................
        str.w r5, [r0, #4]           // .*............................
        smuadx r4, r7, r10           // ..*...........................
        smuad r11, r11, r6           // ...*..........................
        str.w r11, [r0], #2*4        // ...*..........................
        smuad r8, r7, r9             // ....*.........................
        ldr.w r7, [r1, #4]           // ....e.........................
        ldr.w r11, [r1], #2*4        // .....e........................
        str.w r4, [r0, #4]           // .....*........................
        ldr.w r10, [r2, #4]          // ......e.......................
        ldr.w r5, [r2], #2*4         // ......e.......................
        str.w r8, [r0], #2*4         // .......*......................

                                      // ------ cycle (expected) ------>
                                      // 0                        25
                                      // |------------------------|-----
        // ldr.w r7, [r1, #4]         // e...'...~...'...~...'...~...'..
        // ldr.w r4, [r1], #2*4       // .e..'....~..'....~..'....~..'..
        // ldr.w r8, [r2, #4]         // ..e.'.....~.'.....~.'.....~.'..
        // ldr.w r5, [r2], #2*4       // ..e.'.....~.'.....~.'.....~.'..
        // ldr.w r9, [r3, #4]         // ....*.......~.......~.......~..
        // ldr.w r6, [r3], #2*4       // ....*.......~.......~.......~..
        // smuad r10, r4, r6          // ....'..*....'..~....'..~....'..
        // smuadx r11, r4, r5         // ....'*......'~......'~......'~.
        // str.w r11, [r0, #4]        // ....'*......'~......'~......'~.
        // str.w r10, [r0], #2*4      // ....'..*....'..~....'..~....'..
        // smuad r10, r7, r9          // ~...'...*...'...~...'...~...'..
        // smuadx r11, r7, r8         // ....'.*.....'.~.....'.~.....'..
        // str.w r11, [r0, #4]        // .~..'....*..'....~..'....~..'..
        // str.w r10, [r0], #2*4      // ...~'......*'......~'......~'..

        cmp r0, r12
        bne 1b
                                     // Instructions:    10
                                     // Expected cycles: 8
                                     // Expected IPC:    1.25
                                     //
                                     // Wall time:     0.10s
                                     // User time:     0.10s
                                     //
                                     // ----- cycle (expected) ------>
                                     // 0                        25
                                     // |------------------------|----
        ldr.w r8, [r3, #4]           // *.............................
        ldr.w r9, [r3], #2*4         // *.............................
        smuadx r5, r11, r5           // .*............................
        str.w r5, [r0, #4]           // .*............................
        smuad r5, r7, r8             // ..*...........................
        smuad r11, r11, r9           // ...*..........................
        str.w r11, [r0], #2*4        // ...*..........................
        smuadx r11, r7, r10          // ....*.........................
        str.w r11, [r0, #4]          // .....*........................
        str.w r5, [r0], #2*4         // .......*......................

                                      // ------ cycle (expected) ------>
                                      // 0                        25
                                      // |------------------------|-----
        // ldr.w r9, [r3, #4]         // *..............................
        // ldr.w r6, [r3], #2*4       // *..............................
        // smuadx r5, r11, r5         // .*.............................
        // str.w r5, [r0, #4]         // .*.............................
        // smuadx r4, r7, r10         // ....*..........................
        // smuad r11, r11, r6         // ...*...........................
        // str.w r11, [r0], #2*4      // ...*...........................
        // smuad r8, r7, r9           // ..*............................
        // str.w r4, [r0, #4]         // .....*.........................
        // str.w r8, [r0], #2*4       // .......*.......................


    pop.w {r4-r11, pc}
/**
 * Copyright (c) 2023 Junhao Huang (jhhuang_nuaa@126.com)
 *
 * Licensed under the Apache License, Version 2.0(the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:// www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
.syntax unified
.cpu cortex-m4
.thumb

###################################
#### small point-multiplication####
#### r0: out; r1: in; r2: zetas####
###################################
.align 2
.global small_pointmul_asm_769_opt_m7
.type small_pointmul_asm_769_opt_m7, %function
small_pointmul_asm_769_opt_m7:
    push.w {r4-r11, lr}

    movw r14, #24608 // qa
    movt r12, #769  // q
    .equ width, 4


    add.w r3, r2, #64*width
                                       // Instructions:    8
                                       // Expected cycles: 5
                                       // Expected IPC:    1.60
                                       //
                                       // Wall time:     0.14s
                                       // User time:     0.14s
                                       //
                                       // ----- cycle (expected) ------>
                                       // 0                        25
                                       // |------------------------|----
        ldr.w r10, [r1, #2*4]          // *.............................
        ldr.w r7, [r2, #1*4]           // *.............................
        ldr.w r11, [r2], #2*4          // .*............................
        ldr.w r9, [r1, #1*4]           // .*............................
        smulwt r8, r7, r10             // ..*...........................
        ldr.w r5, [r1, #3*4]           // ..*...........................
        ldr.w r6, [r1], #4*4           // ...*..........................
        smlabt r8, r8, r12, r14        // ....*.........................

                                        // ------ cycle (expected) ------>
                                        // 0                        25
                                        // |------------------------|-----
        // ldr.w r10, [r1, #2*4]        // *..............................
        // ldr.w r7, [r2, #1*4]         // *..............................
        // ldr.w r11, [r2], #2*4        // .*.............................
        // ldr.w r9, [r1, #1*4]         // .*.............................
        // smulwt r4, r7, r10           // ..*............................
        // ldr.w r5, [r1, #3*4]         // ..*............................
        // ldr.w r6, [r1], #4*4         // ...*...........................
        // smlabt r8, r4, r12, r14      // ....*..........................

1:
                                         // Instructions:    24
                                         // Expected cycles: 12
                                         // Expected IPC:    2.00
                                         //
                                         // Wall time:     3.32s
                                         // User time:     3.32s
                                         //
                                         // ----- cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|----
        smulwt r4, r11, r6               // *.............................
        neg.w r11, r11                   // *.............................
        smulwt r11, r11, r9              // .*............................
        pkhbt r8, r10, r8                // .*............................
        neg.w r7, r7                     // ..*...........................
        smlabt r4, r4, r12, r14          // ..*...........................
        ldr.w r10, [r1, #2*4]            // ...e..........................
        smlabt r11, r11, r12, r14        // ...*..........................
        pkhbt r6, r6, r4                 // ....*.........................
        smulwt r4, r7, r5                // ....*.........................
        pkhbt r11, r9, r11               // .....*........................
        str.w r11, [r0, #1*4]            // .....*........................
        ldr.w r7, [r2, #1*4]             // ......e.......................
        ldr.w r11, [r2], #2*4            // ......e.......................
        str.w r6, [r0], #2*4             // .......*......................
        smlabt r6, r4, r12, r14          // .......*......................
        ldr.w r9, [r1, #1*4]             // ........e.....................
        smulwt r4, r7, r10               // ........e.....................
        pkhbt r5, r5, r6                 // .........*....................
        str.w r5, [r0, #1*4]             // .........*....................
        ldr.w r5, [r1, #3*4]             // ..........e...................
        ldr.w r6, [r1], #4*4             // ..........e...................
        str.w r8, [r0], #2*4             // ...........*..................
        smlabt r8, r4, r12, r14          // ...........e..................

                                          // ------ cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|-----
        // ldr.w r7, [r1, #2*4]           // e........'..~........'..~......
        // ldr.w r8, [r1, #3*4]           // .......e.'.........~.'.........
        // ldr.w r9, [r2, #1*4]           // ...e.....'.....~.....'.....~...
        // ldr.w r5, [r1, #1*4]           // .....e...'.......~...'.......~.
        // ldr.w r4, [r1], #4*4           // .......e.'.........~.'.........
        // ldr.w r6, [r2], #2*4           // ...e.....'.....~.....'.....~...
        // smulwt r10, r6, r4             // .........*...........~.........
        // smlabt r10, r10, r12, r14      // .........'.*.........'.~.......
        // pkhbt r4, r4, r10              // .~.......'...*.......'...~.....
        // neg.w r6, r6                   // .........*...........~.........
        // smulwt r10, r6, r5             // .........'*..........'~........
        // smlabt r10, r10, r12, r14      // ~........'..*........'..~......
        // pkhbt r5, r5, r10              // ..~......'....*......'....~....
        // str.w r5, [r0, #1*4]           // ..~......'....*......'....~....
        // str.w r4, [r0], #2*4           // ....~....'......*....'......~..
        // smulwt r10, r9, r7             // .....e...'.......~...'.......~.
        // smlabt r10, r10, r12, r14      // ........e'..........~'.........
        // pkhbt r7, r7, r10              // .........'*..........'~........
        // neg.w r9, r9                   // .........'.*.........'.~.......
        // smulwt r10, r9, r8             // .~.......'...*.......'...~.....
        // smlabt r10, r10, r12, r14      // ....~....'......*....'......~..
        // pkhbt r8, r8, r10              // ......~..'........*..'.........
        // str.w r8, [r0, #1*4]           // ......~..'........*..'.........
        // str.w r7, [r0], #2*4           // ........~'..........*'.........

        cmp r2, r3
        bne 1b
                                         // Instructions:    16
                                         // Expected cycles: 12
                                         // Expected IPC:    1.33
                                         //
                                         // Wall time:     0.24s
                                         // User time:     0.24s
                                         //
                                         // ----- cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|----
        smulwt r4, r11, r6               // *.............................
        neg.w r11, r11                   // *.............................
        pkhbt r8, r10, r8                // .*............................
        smulwt r10, r11, r9              // .*............................
        neg.w r7, r7                     // ..*...........................
        smlabt r4, r4, r12, r14          // ..*...........................
        smlabt r11, r10, r12, r14        // ...*..........................
        pkhbt r6, r6, r4                 // ....*.........................
        smulwt r10, r7, r5               // ....*.........................
        pkhbt r9, r9, r11                // .....*........................
        str.w r9, [r0, #1*4]             // .....*........................
        smlabt r9, r10, r12, r14         // ......*.......................
        str.w r6, [r0], #2*4             // .......*......................
        pkhbt r9, r5, r9                 // ........*.....................
        str.w r9, [r0, #1*4]             // .........*....................
        str.w r8, [r0], #2*4             // ...........*..................

                                          // ------ cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|-----
        // smulwt r4, r11, r6             // *..............................
        // neg.w r11, r11                 // *..............................
        // smulwt r11, r11, r9            // .*.............................
        // pkhbt r8, r10, r8              // .*.............................
        // neg.w r7, r7                   // ..*............................
        // smlabt r4, r4, r12, r14        // ..*............................
        // smlabt r11, r11, r12, r14      // ...*...........................
        // pkhbt r6, r6, r4               // ....*..........................
        // smulwt r4, r7, r5              // ....*..........................
        // pkhbt r11, r9, r11             // .....*.........................
        // str.w r11, [r0, #1*4]          // .....*.........................
        // str.w r6, [r0], #2*4           // .......*.......................
        // smlabt r6, r4, r12, r14        // ......*........................
        // pkhbt r5, r5, r6               // ........*......................
        // str.w r5, [r0, #1*4]           // .........*.....................
        // str.w r8, [r0], #2*4           // ...........*...................


    pop.w {r4-r11, pc}
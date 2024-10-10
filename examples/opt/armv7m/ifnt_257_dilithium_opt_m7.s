// 4
.macro ldrstr4 ldrstr, target, c0, c1, c2, c3, mem0, mem1, mem2, mem3
    \ldrstr \c0, [\target, \mem0]
    \ldrstr \c1, [\target, \mem1]
    \ldrstr \c2, [\target, \mem2]
    \ldrstr \c3, [\target, \mem3]
.endm

// 4
.macro ldrstr4jump ldrstr, target, c0, c1, c2, c3, mem1, mem2, mem3, jump
    \ldrstr \c1, [\target, \mem1]
    \ldrstr \c2, [\target, \mem2]
    \ldrstr \c3, [\target, \mem3]
    \ldrstr \c0, [\target], \jump
.endm

// 8
.macro ldrstrvec ldrstr, target, c0, c1, c2, c3, c4, c5, c6, c7, mem0, mem1, mem2, mem3, mem4, mem5, mem6, mem7
    ldrstr4 \ldrstr, \target, \c0, \c1, \c2, \c3, \mem0, \mem1, \mem2, \mem3
    ldrstr4 \ldrstr, \target, \c4, \c5, \c6, \c7, \mem4, \mem5, \mem6, \mem7
.endm

// 8
.macro ldrstrvecjump ldrstr, target, c0, c1, c2, c3, c4, c5, c6, c7, mem1, mem2, mem3, mem4, mem5, mem6, mem7, jump
    ldrstr4 \ldrstr, \target, \c4, \c5, \c6, \c7, \mem4, \mem5, \mem6, \mem7
    ldrstr4jump \ldrstr, \target, \c0, \c1, \c2, \c3, \mem1, \mem2, \mem3, \jump
.endm

.macro addSub1 c0, c1
    add.w \c0, \c1
    sub.w \c1, \c0, \c1, lsl #1
.endm

.macro addSub2 c0, c1, c2, c3
    add \c0, \c1
    add \c2, \c3
    sub.w \c1, \c0, \c1, lsl #1
    sub.w \c3, \c2, \c3, lsl #1
.endm

.macro addSub4 c0, c1, c2, c3, c4, c5, c6, c7
    add \c0, \c1
    add \c2, \c3
    add \c4, \c5
    add \c6, \c7
    sub.w \c1, \c0, \c1, lsl #1
    sub.w \c3, \c2, \c3, lsl #1
    sub.w \c5, \c4, \c5, lsl #1
    sub.w \c7, \c6, \c7, lsl #1
.endm

// 2
.macro barrett_32 a, Qbar, Q, tmp
    smmulr.w \tmp, \a, \Qbar
    mls.w \a, \tmp, \Q, \a
.endm

.macro shift_subAdd c0, c1, shlv
    sub.w \c0, \c0, \c1, lsl #(\shlv)
    add.w \c1, \c0, \c1, lsl #(\shlv+1)
.endm

.macro FNT_CT_ibutterfly c0, c1, shlv
    shift_subAdd \c0, \c1, \shlv
.endm

.macro final_butterfly c0, c1, c1f, twiddle
    vmov.w \c1, \c1f
    add.w \c0, \c1
    sub.w \c1, \c0, \c1, lsl #1
    mul.w \c1, \twiddle
.endm

.macro final_butterfly2 c0, c0out, c1, c1f, twiddle, twiddle2
    vmov.w \c1, \c1f
    mla.w \c0out, \twiddle2, \c1, \c0
    mls.w \c1, \twiddle2, \c1, \c0
    mul.w \c1, \twiddle
.endm

.syntax unified
.cpu cortex-m4
.align 2
.global __asm_ifnt_257_opt_m7
.type __asm_ifnt_257_opt_m7, %function
__asm_ifnt_257_opt_m7:
    push.w {r4-r11, lr}
    vpush.w {s16-s24}

    .equ width, 4

    add.w r12, r0, #256*width
    vmov.w s1, r12
    _ifnt_7_6_5_4:
    _ifnt_7_6_5_4_start:

        vldm.w r1!, {s2-s16}

// ================

            ldrstrvec ldr.w, r0, r4, r5, r6, r7, r8, r9, r10, r11, #(2*8*width), #(2*9*width), #(2*10*width), #(2*11*width), #(2*12*width), #(2*13*width), #(2*14*width), #(2*15*width)

            addSub4 r4, r5, r6, r7, r8, r9, r10, r11
            vmov.w r14, s6
            mul.w r5, r5, r14
            vmov.w r14, s8
            mul.w r9, r9, r14
            addSub2 r4, r6, r8, r10
            vmov.w r14, s7
            mla.w r12, r7, r14, r5
            mls.w r7, r7, r14, r5
            vmov.w r14, s9
            mla.w r5, r11, r14, r9
            mls.w r11, r11, r14, r9

            // r4, r12, r6, r7, r8, r5, r10, r11

            vmov.w r14, s12
            mul.w r6, r6, r14
            mul.w r7, r7, r14
            vmov.w r14, s13
            mul.w r10, r10, r14
            mul.w r11, r11, r14

    barrett_32 r4, r2, r3, r14
    barrett_32 r12, r2, r3, r14
    barrett_32 r6, r2, r3, r14
    barrett_32 r7, r2, r3, r14
    barrett_32 r8, r2, r3, r14
    barrett_32 r5, r2, r3, r14
    barrett_32 r10, r2, r3, r14
    barrett_32 r11, r2, r3, r14

            addSub4 r4, r8, r6, r10, r12, r5, r7, r11

            vmov.w s17, s18, r4, r12
            vmov.w s19, s20, r6, r7
            vmov.w s21, s22, r8, r5
            vmov.w s23, s24, r10, r11

            ldrstrvec ldr.w, r0, r4, r5, r6, r7, r8, r9, r10, r11, #(2*0*width), #(2*1*width), #(2*2*width), #(2*3*width), #(2*4*width), #(2*5*width), #(2*6*width), #(2*7*width)

            addSub4 r4, r5, r6, r7, r8, r9, r10, r11
            vmov.w r14, s2
            mul.w r5, r5, r14
            vmov.w r14, s4
            mul.w r9, r9, r14
            addSub2 r4, r6, r8, r10
            vmov.w r14, s3
            mla.w r12, r7, r14, r5
            mls.w r7, r7, r14, r5
            vmov.w r14, s5
            mla.w r5, r11, r14, r9
            mls.w r11, r11, r14, r9

            // r4, r12, r6, r7, r8, r5, r10, r11

            vmov.w r14, s10
            mul.w r6, r6, r14
            mul.w r7, r7, r14
            vmov.w r14, s11
            mul.w r10, r10, r14
            mul.w r11, r11, r14

    barrett_32 r4, r2, r3, r14
    barrett_32 r12, r2, r3, r14
    barrett_32 r6, r2, r3, r14
    barrett_32 r7, r2, r3, r14
    barrett_32 r8, r2, r3, r14
    barrett_32 r5, r2, r3, r14
    barrett_32 r10, r2, r3, r14
    barrett_32 r11, r2, r3, r14

            addSub4 r4, r8, r6, r10, r12, r5, r7, r11
            vmov.w r14, s14
            mul.w r8, r8, r14
            mul.w r5, r5, r14
            mul.w r10, r10, r14
            mul.w r11, r11, r14
            vmov.w r14, s16
            final_butterfly r12, r9, s18, r14
            str.w r12, [r0, #(2*1*width)]
            str.w r9, [r0, #(2*9*width)]
            final_butterfly r6, r9, s19, r14
            str.w r6, [r0, #(2*2*width)]
            str.w r9, [r0, #(2*10*width)]
            final_butterfly r7, r9, s20, r14
            str.w r7, [r0, #(2*3*width)]
            str.w r9, [r0, #(2*11*width)]
            vmov.w r12, s15
            final_butterfly2 r8, r6, r9, s21, r14, r12
            str.w r6, [r0, #(2*4*width)]
            str.w r9, [r0, #(2*12*width)]
            final_butterfly2 r5, r6, r9, s22, r14, r12
            str.w r6, [r0, #(2*5*width)]
            str.w r9, [r0, #(2*13*width)]
            final_butterfly2 r10, r6, r9, s23, r14, r12
            str.w r6, [r0, #(2*6*width)]
            str.w r9, [r0, #(2*14*width)]
            final_butterfly2 r11, r6, r9, s24, r14, r12
            str.w r6, [r0, #(2*7*width)]
            str.w r9, [r0, #(2*15*width)]
            final_butterfly r4, r9, s17, r14
            str.w r9, [r0, #(2*8*width)]
            str.w r4, [r0], #width

// ================

            ldrstrvec ldr.w, r0, r4, r5, r6, r7, r8, r9, r10, r11, #(2*8*width), #(2*9*width), #(2*10*width), #(2*11*width), #(2*12*width), #(2*13*width), #(2*14*width), #(2*15*width)

            addSub4 r4, r5, r6, r7, r8, r9, r10, r11
            vmov.w r14, s6
            mul.w r5, r5, r14
            vmov.w r14, s8
            mul.w r9, r9, r14
            addSub2 r4, r6, r8, r10
            vmov.w r14, s7
            mla.w r12, r7, r14, r5
            mls.w r7, r7, r14, r5
            vmov.w r14, s9
            mla.w r5, r11, r14, r9
            mls.w r11, r11, r14, r9

            // r4, r12, r6, r7, r8, r5, r10, r11

            vmov.w r14, s12
            mul.w r6, r6, r14
            mul.w r7, r7, r14
            vmov.w r14, s13
            mul.w r10, r10, r14
            mul.w r11, r11, r14

    barrett_32 r4, r2, r3, r14
    barrett_32 r12, r2, r3, r14
    barrett_32 r6, r2, r3, r14
    barrett_32 r7, r2, r3, r14
    barrett_32 r8, r2, r3, r14
    barrett_32 r5, r2, r3, r14
    barrett_32 r10, r2, r3, r14
    barrett_32 r11, r2, r3, r14

            addSub4 r4, r8, r6, r10, r12, r5, r7, r11

            vmov.w s17, s18, r4, r12
            vmov.w s19, s20, r6, r7
            vmov.w s21, s22, r8, r5
            vmov.w s23, s24, r10, r11

            ldrstrvec ldr.w, r0, r4, r5, r6, r7, r8, r9, r10, r11, #(2*0*width), #(2*1*width), #(2*2*width), #(2*3*width), #(2*4*width), #(2*5*width), #(2*6*width), #(2*7*width)

            addSub4 r4, r5, r6, r7, r8, r9, r10, r11
            vmov.w r14, s2
            mul.w r5, r5, r14
            vmov.w r14, s4
            mul.w r9, r9, r14
            addSub2 r4, r6, r8, r10
            vmov.w r14, s3
            mla.w r12, r7, r14, r5
            mls.w r7, r7, r14, r5
            vmov.w r14, s5
            mla.w r5, r11, r14, r9
            mls.w r11, r11, r14, r9

            // r4, r12, r6, r7, r8, r5, r10, r11

            vmov.w r14, s10
            mul.w r6, r6, r14
            mul.w r7, r7, r14
            vmov.w r14, s11
            mul.w r10, r10, r14
            mul.w r11, r11, r14

    barrett_32 r4, r2, r3, r14
    barrett_32 r12, r2, r3, r14
    barrett_32 r6, r2, r3, r14
    barrett_32 r7, r2, r3, r14
    barrett_32 r8, r2, r3, r14
    barrett_32 r5, r2, r3, r14
    barrett_32 r10, r2, r3, r14
    barrett_32 r11, r2, r3, r14

            addSub4 r4, r8, r6, r10, r12, r5, r7, r11
            vmov.w r14, s14
            mul.w r8, r8, r14
            mul.w r5, r5, r14
            mul.w r10, r10, r14
            mul.w r11, r11, r14
            vmov.w r14, s16

            final_butterfly r12, r9, s18, r14
            str.w r12, [r0, #(2*1*width)]
            str.w r9, [r0, #(2*9*width)]
            final_butterfly r6, r9, s19, r14
            str.w r6, [r0, #(2*2*width)]
            str.w r9, [r0, #(2*10*width)]
            final_butterfly r7, r9, s20, r14
            str.w r7, [r0, #(2*3*width)]
            str.w r9, [r0, #(2*11*width)]
            vmov.w r12, s15
            final_butterfly2 r8, r6, r9, s21, r14, r12
            str.w r6, [r0, #(2*4*width)]
            str.w r9, [r0, #(2*12*width)]
            final_butterfly2 r5, r6, r9, s22, r14, r12
            str.w r6, [r0, #(2*5*width)]
            str.w r9, [r0, #(2*13*width)]
            final_butterfly2 r10, r6, r9, s23, r14, r12
            str.w r6, [r0, #(2*6*width)]
            str.w r9, [r0, #(2*14*width)]
            final_butterfly2 r11, r6, r9, s24, r14, r12
            str.w r6, [r0, #(2*7*width)]
            str.w r9, [r0, #(2*15*width)]
            final_butterfly r4, r9, s17, r14
            str.w r9, [r0, #(2*8*width)]
            str.w r4, [r0], #31*width

// ================

    vmov.w r12, s1
    _ifnt_7_6_5_4_end:
    cmp.w r0, r12
    bne.w _ifnt_7_6_5_4

    sub.w r0, r0, #256*width

    mov.w r14, #0

    add.w r1, r0, #32*width
    _ifnt_0_1_2:
.rept 2
        // _ifnt_0_1_2_start:
                                              // Instructions:    70
                                              // Expected cycles: 37
                                              // Expected IPC:    1.89
                                              //
                                              // Wall time:     8.10s
                                              // User time:     8.10s
                                              //
                                              // --------- cycle (expected) --------->
                                              // 0                        25
                                              // |------------------------|-----------
        ldr.w r6, [r0, #(32*6*width)]         // *....................................
        ldr.w r10, [r0, #(32*7*width)]        // *....................................
        ldr.w r8, [r0, #(32*5*width)]         // .*...................................
        ldr.w r9, [r0, #(32*4*width)]         // .*...................................
        ldr.w r12, [r0, #(32*2*width)]        // ..*..................................
        add r6, r10                           // ..*..................................
        sub.w r5, r6, r10, lsl #1             // ...*.................................
        add r9, r8                            // ...*.................................
        ldr.w r10, [r0, #(32*0*width)]        // ....*................................
        sub.w r8, r9, r8, lsl #1              // ....*................................
        ldr.w r4, [r0, #(32*3*width)]         // .....*...............................
        sub.w r7, r8, r5, lsl #(4)            // .....*...............................
        ldr.w r8, [r0, #(32*1*width)]         // ......*..............................
        smmulr.w r11, r7, r2                  // ......*..............................
        add r10, r8                           // .......*.............................
        add r12, r4                           // .......*.............................
        mls.w r11, r11, r3, r7                // ........*............................
        sub.w r4, r12, r4, lsl #1             // ........*............................
        sub.w r8, r10, r8, lsl #1             // .........*...........................
        add r10, r12                          // .........*...........................
        sub.w r8, r8, r4, lsl #(4)            // ..........*..........................
        sub.w r12, r10, r12, lsl #1           // ..........*..........................
        add.w r7, r7, r5, lsl #(4+1)          // ...........*.........................
        sub.w r5, r8, r11, lsl #(6)           // ...........*.........................
        add.w r11, r5, r11, lsl #(6+1)        // ............*........................
        neg.w r5, r5                          // ............*........................
        add.w r8, r8, r4, lsl #(4+1)          // .............*.......................
        smmulr.w r4, r5, r2                   // .............*.......................
        add r9, r6                            // ..............*......................
        sub.w r8, r8, r7, lsl #(2)            // ..............*......................
        mls.w r5, r4, r3, r5                  // ...............*.....................
        add.w r4, r8, r7, lsl #(2+1)          // ...............*.....................
        sub.w r6, r9, r6, lsl #1              // ................*....................
        add.w r10, r9                         // ................*....................
        str.w r5, [r0, #(32*1*width)]         // .................*...................
        lsl.w r5, r4, #2                      // .................*...................
        sub.w r7, r12, r6, lsl #(4)           // ..................*..................
        smmulr.w r12, r5, r2                  // ..................*..................
        smmulr.w r4, r7, r2                   // ...................*.................
        add.w r6, r7, r6, lsl #(4+1)          // ...................*.................
        mls.w r12, r12, r3, r5                // ....................*................
        lsl.w r5, r6, #3                      // ....................*................
        smmulr.w r6, r5, r2                   // .....................*...............
        str.w r12, [r0, #(32*7*width)]        // .....................*...............
        mls.w r7, r4, r3, r7                  // ......................*..............
        sub.w r12, r10, r9, lsl #1            // ......................*..............
        mls.w r9, r6, r3, r5                  // .......................*.............
        sub.w r5, r14, r10, lsl #1            // .......................*.............
        lsl.w r4, r11, #4                     // ........................*............
        smmulr.w r11, r8, r2                  // ........................*............
        smmulr.w r10, r4, r2                  // .........................*...........
        lsl.w r6, r7, #7                      // .........................*...........
        str.w r9, [r0, #(32*6*width)]         // ..........................*..........
        smmulr.w r7, r6, r2                   // ..........................*..........
        lsl.w r9, r12, #5                     // ...........................*.........
        mls.w r12, r10, r3, r4                // ...........................*.........
        smmulr.w r4, r9, r2                   // ............................*........
        str.w r12, [r0, #(32*5*width)]        // ............................*........
        mls.w r8, r11, r3, r8                 // .............................*.......
        mls.w r10, r4, r3, r9                 // ..............................*......
        str.w r10, [r0, #(32*4*width)]        // ..............................*......
        lsl.w r11, r8, #6                     // ...............................*.....
        mls.w r8, r7, r3, r6                  // ...............................*.....
        str.w r8, [r0, #(32*2*width)]         // ................................*....
        smmulr.w r9, r11, r2                  // ................................*....
        smmulr.w r12, r5, r2                  // .................................*...
        mls.w r6, r9, r3, r11                 // ..................................*..
        str.w r6, [r0, #(32*3*width)]         // ..................................*..
        mls.w r10, r12, r3, r5                // ...................................*.
        str.w r10, [r0], #width               // ....................................*

                                               // --------- cycle (expected) --------->
                                               // 0                        25
                                               // |------------------------|-----------
        // ldr.w r4, [r0, #(32*0*width)]       // ....*................................
        // ldr.w r5, [r0, #(32*1*width)]       // ......*..............................
        // ldr.w r6, [r0, #(32*2*width)]       // ..*..................................
        // ldr.w r7, [r0, #(32*3*width)]       // .....*...............................
        // ldr.w r8, [r0, #(32*4*width)]       // .*...................................
        // ldr.w r9, [r0, #(32*5*width)]       // .*...................................
        // ldr.w r10, [r0, #(32*6*width)]      // *....................................
        // ldr.w r11, [r0, #(32*7*width)]      // *....................................
        // add r4, r5                          // .......*.............................
        // add r6, r7                          // .......*.............................
        // add r8, r9                          // ...*.................................
        // add r10, r11                        // ..*..................................
        // sub.w r5, r4, r5, lsl #1            // .........*...........................
        // sub.w r7, r6, r7, lsl #1            // ........*............................
        // sub.w r9, r8, r9, lsl #1            // ....*................................
        // sub.w r11, r10, r11, lsl #1         // ...*.................................
        // add r4, r6                          // .........*...........................
        // add r8, r10                         // ..............*......................
        // sub.w r6, r4, r6, lsl #1            // ..........*..........................
        // sub.w r10, r8, r10, lsl #1          // ................*....................
        // sub.w r5, r5, r7, lsl #(4)          // ..........*..........................
        // add.w r7, r5, r7, lsl #(4+1)        // .............*.......................
        // sub.w r9, r9, r11, lsl #(4)         // .....*...............................
        // add.w r11, r9, r11, lsl #(4+1)      // ...........*.........................
        // add.w r4, r8                        // ................*....................
        // sub.w r8, r4, r8, lsl #1            // ......................*..............
        // smmulr.w r12, r9, r2                // ......*..............................
        // mls.w r9, r12, r3, r9               // ........*............................
        // sub.w r5, r5, r9, lsl #(6)          // ...........*.........................
        // add.w r9, r5, r9, lsl #(6+1)        // ............*........................
        // sub.w r6, r6, r10, lsl #(4)         // ..................*..................
        // add.w r10, r6, r10, lsl #(4+1)      // ...................*.................
        // sub.w r7, r7, r11, lsl #(2)         // ..............*......................
        // add.w r11, r7, r11, lsl #(2+1)      // ...............*.....................
        // smmulr.w r12, r6, r2                // ...................*.................
        // mls.w r6, r12, r3, r6               // ......................*..............
        // smmulr.w r12, r7, r2                // ........................*............
        // mls.w r7, r12, r3, r7               // .............................*.......
        // sub.w r4, r14, r4, lsl #1           // .......................*.............
        // neg.w r5, r5                        // ............*........................
        // lsl.w r6, r6, #7                    // .........................*...........
        // lsl.w r7, r7, #6                    // ...............................*.....
        // lsl.w r8, r8, #5                    // ...........................*.........
        // lsl.w r9, r9, #4                    // ........................*............
        // lsl.w r10, r10, #3                  // ....................*................
        // lsl.w r11, r11, #2                  // .................*...................
        // smmulr.w r12, r4, r2                // .................................*...
        // mls.w r4, r12, r3, r4               // ...................................*.
        // smmulr.w r12, r5, r2                // .............*.......................
        // mls.w r5, r12, r3, r5               // ...............*.....................
        // smmulr.w r12, r6, r2                // ..........................*..........
        // mls.w r6, r12, r3, r6               // ...............................*.....
        // smmulr.w r12, r7, r2                // ................................*....
        // mls.w r7, r12, r3, r7               // ..................................*..
        // smmulr.w r12, r8, r2                // ............................*........
        // mls.w r8, r12, r3, r8               // ..............................*......
        // smmulr.w r12, r9, r2                // .........................*...........
        // mls.w r9, r12, r3, r9               // ...........................*.........
        // smmulr.w r12, r10, r2               // .....................*...............
        // mls.w r10, r12, r3, r10             // .......................*.............
        // smmulr.w r12, r11, r2               // ..................*..................
        // mls.w r11, r12, r3, r11             // ....................*................
        // str.w r8, [r0, #(32*4*width)]       // ..............................*......
        // str.w r9, [r0, #(32*5*width)]       // ............................*........
        // str.w r10, [r0, #(32*6*width)]      // ..........................*..........
        // str.w r11, [r0, #(32*7*width)]      // .....................*...............
        // str.w r5, [r0, #(32*1*width)]       // .................*...................
        // str.w r6, [r0, #(32*2*width)]       // ................................*....
        // str.w r7, [r0, #(32*3*width)]       // ..................................*..
        // str.w r4, [r0], #width              // ....................................*

        // _ifnt_0_1_2_end:

.endr

    cmp.w r0, r1
    bne.w _ifnt_0_1_2
    vpop.w {s16-s24}
    pop.w {r4-r11, pc}

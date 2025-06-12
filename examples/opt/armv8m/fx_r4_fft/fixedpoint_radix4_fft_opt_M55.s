        .syntax unified
        .type   fixedpoint_radix4_fft_symbolic, %function
        .global fixedpoint_radix4_fft_symbolic


        inA .req r0
        pW0 .req r1 // Use the same twiddle data for TESTING ONLY
        sz  .req r2

        inB .req r3
        inC .req r4
        inD .req r5

        pW1 .req r6
        pW2 .req r7
        pW3 .req r8

.macro load_data
        vldrw.s32   q<qA>, [inA]
        vldrw.s32   q<qB>, [inB]
        vldrw.s32   q<qC>, [inC]
        vldrw.s32   q<qD>, [inD]
.endm

.macro load_twiddles
        vldrw.s32  q<qTw1>, [pW1], #16
        vldrw.s32  q<qTw2>, [pW2], #16
        vldrw.s32  q<qTw3>, [pW3], #16
.endm

.macro store_data
        vstrw.32   q<qA>, [inA], #16
        vstrw.32   q<qB>, [inB], #16
        vstrw.32   q<qC>, [inC], #16
        vstrw.32   q<qD>, [inD], #16
.endm

.macro cmul_fx out, in0, in1
        vqdmlsdh.s32 \out, \in0, \in1
        vqdmladhx.s32  \out, \in0, \in1
.endm

        .text
        .align 4
fixedpoint_radix4_fft_symbolic:
        push    {r4-r12,lr}
        vpush   {d0-d15}

        add     inB, inA, sz
        add     inC, inB, sz
        add     inD, inC, sz

        add     pW1, pW0, sz
        add     pW2, pW1, sz
        add     pW3, pW2, sz

        lsr     lr, sz, #4
        wls     lr, lr, end

        vldrw.S32 q5, [r0]
        vldrw.S32 q0, [r4]
        vhsub.S32 q7, q5, q0// a-c
        vldrw.S32 q3, [r6], #16
        vldrw.S32 q2, [r5]
        vhadd.S32 q4, q5, q0// a+c
        vldrw.S32 q5, [r3]
        vhadd.S32 q0, q5, q2// b+d
        vhsub.S32 q2, q5, q2// b-d
        vhsub.S32 q5, q4, q0// a-b+c-d
        vqdmlsdh.S32 q1, q3, q5
        vldrw.S32 q6, [r7], #16
        vqdmladhx.S32 q1, q3, q5
        vstrw.32 q1, [r3], #16
        vhcadd.S32 q3, q7, q2, #270// a-ib-c+id
        sub lr, lr, #1
.p2align 2
fixedpoint_radix4_fft_loop_start:
                                           // Instructions:    25
                                           // Expected cycles: 25
                                           // Expected IPC:    1.00
                                           //
                                           // Wall time:     1.71s
                                           // User time:     1.71s
                                           //
                                           // ----- cycle (expected) ------>
                                           // 0                        25
                                           // |------------------------|----
        vqdmlsdh.S32 q1, q6, q3            // *.............................
        vldrw.S32 q5, [r0]                 // .e............................
        vhadd.S32 q4, q4, q0               // ..*...........................
        vldrw.S32 q0, [r4]                 // ...e..........................
        vhcadd.S32 q2, q7, q2, #90         // ....*.........................
        vstrw.32 q4, [r0], #16             // .....*........................
        vqdmladhx.S32 q1, q6, q3           // ......*.......................
        vhsub.S32 q7, q5, q0               // .......e......................
        vldrw.S32 q4, [r8], #16            // ........*.....................
        vqdmlsdh.S32 q6, q4, q2            // .........*....................
        vldrw.S32 q3, [r6], #16            // ..........e...................
        vqdmladhx.S32 q6, q4, q2           // ...........*..................
        vldrw.S32 q2, [r5]                 // ............e.................
        vhadd.S32 q4, q5, q0               // .............e................
        vldrw.S32 q5, [r3]                 // ..............e...............
        vhadd.S32 q0, q5, q2               // ...............e..............
        vstrw.32 q6, [r5], #16             // ................*.............
        vhsub.S32 q2, q5, q2               // .................e............
        vstrw.32 q1, [r4], #16             // ..................*...........
        vhsub.S32 q5, q4, q0               // ...................e..........
        vqdmlsdh.S32 q1, q3, q5            // ....................e.........
        vldrw.S32 q6, [r7], #16            // .....................e........
        vqdmladhx.S32 q1, q3, q5           // ......................e.......
        vstrw.32 q1, [r3], #16             // .......................e......
        vhcadd.S32 q3, q7, q2, #270        // ........................e.....

                                                            // ------------ cycle (expected) ------------>
                                                            // 0                        25
                                                            // |------------------------|-----------------
        // vldrw.s32   q<qA>, [r0]                          // e.......................'~.................
        // vldrw.s32   q<qB>, [r3]                          // .............e..........'.............~....
        // vldrw.s32   q<qC>, [r4]                          // ..e.....................'..~...............
        // vldrw.s32   q<qD>, [r5]                          // ...........e............'...........~......
        // vldrw.s32  q<qTw1>, [r6], #16                    // .........e..............'.........~........
        // vldrw.s32  q<qTw2>, [r7], #16                    // ....................e...'..................
        // vldrw.s32  q<qTw3>, [r8], #16                    // .......~................'.......*..........
        // vhadd.s32  q<qSm0>, q<qA>,   q<qC>               // ............e...........'............~.....
        // vhadd.s32  q<qSm1>, q<qB>,   q<qD>               // ..............e.........'..............~...
        // vhsub.s32  q<qDf0>, q<qA>,   q<qC>               // ......e.................'......~...........
        // vhsub.s32  q<qDf1>, q<qB>,   q<qD>               // ................e.......'................~.
        // vhadd.s32  q<qA>,   q<qSm0>, q<qSm1>             // .~......................'.*................
        // vhsub.s32  q<qBp>,  q<qSm0>, q<qSm1>             // ..................e.....'..................
        // vhcadd.s32 q<qCp>,  q<qDf0>, q<qDf1>, #270       // .......................e'..................
        // vhcadd.s32 q<qDp>,  q<qDf0>, q<qDf1>, #90        // ...~....................'...*..............
        // vqdmlsdh.s32 q<qB>, q<qTw1>, q<qBp>              // ...................e....'..................
        // vqdmladhx.s32  q<qB>, q<qTw1>, q<qBp>            // .....................e..'..................
        // vqdmlsdh.s32 q<qC>, q<qTw2>, q<qCp>              // ........................*..................
        // vqdmladhx.s32  q<qC>, q<qTw2>, q<qCp>            // .....~..................'.....*............
        // vqdmlsdh.s32 q<qD>, q<qTw3>, q<qDp>              // ........~...............'........*.........
        // vqdmladhx.s32  q<qD>, q<qTw3>, q<qDp>            // ..........~.............'..........*.......
        // vstrw.32   q<qA>, [r0], #16                      // ....~...................'....*.............
        // vstrw.32   q<qB>, [r3], #16                      // ......................e.'..................
        // vstrw.32   q<qC>, [r4], #16                      // .................~......'.................*
        // vstrw.32   q<qD>, [r5], #16                      // ...............~........'...............*..

        le lr, fixedpoint_radix4_fft_loop_start
        vqdmlsdh.S32 q1, q6, q3
        vhadd.S32 q4, q4, q0// a+b+c+d
        vhcadd.S32 q2, q7, q2, #90// a+ib-c-id
        vstrw.32 q4, [r0], #16
        vqdmladhx.S32 q1, q6, q3
        vldrw.S32 q4, [r8], #16
        vqdmlsdh.S32 q6, q4, q2
        vqdmladhx.S32 q6, q4, q2
        vstrw.32 q6, [r5], #16
        vstrw.32 q1, [r4], #16

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

        .syntax unified
        .type   fixedpoint_radix4_fft_opt_M55, %function
        .global fixedpoint_radix4_fft_opt_M55


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
fixedpoint_radix4_fft_opt_M55:
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

        vldrw.S32 q2, [r4]
        vldrw.S32 q1, [r5]
        vldrw.S32 q5, [r0]
        vhsub.S32 q3, q5, q2// a-c
        vldrw.S32 q6, [r3]
        vhadd.S32 q5, q5, q2// a+c
        vldrw.S32 q2, [r7], #16
        vhadd.S32 q0, q6, q1// b+d
        vhsub.S32 q1, q6, q1// b-d
        sub lr, lr, #1
.p2align 2
fixedpoint_radix4_fft_loop_start:
                                           // Instructions:    25
                                           // Expected cycles: 25
                                           // Expected IPC:    1.00
                                           //
                                           // Wall time:     1.38s
                                           // User time:     1.38s
                                           //
                                           // ----- cycle (expected) ------>
                                           // 0                        25
                                           // |------------------------|----
        vhcadd.S32 q4, q3, q1, #270        // *.............................
        vqdmlsdh.S32 q6, q2, q4            // .*............................
        vldrw.S32 q7, [r6], #16            // ..*...........................
        vqdmladhx.S32 q6, q2, q4           // ...*..........................
        vldrw.S32 q2, [r4, #16]            // ....e.........................
        vhcadd.S32 q4, q3, q1, #90         // .....*........................
        vstrw.32 q6, [r4], #16             // ......*.......................
        vhsub.S32 q1, q5, q0               // .......*......................
        vqdmlsdh.S32 q3, q7, q1            // ........*.....................
        vldrw.S32 q6, [r8], #16            // .........*....................
        vqdmladhx.S32 q3, q7, q1           // ..........*...................
        vldrw.S32 q1, [r5, #16]            // ...........e..................
        vqdmlsdh.S32 q7, q6, q4            // ............*.................
        vstrw.32 q3, [r3], #16             // .............*................
        vqdmladhx.S32 q7, q6, q4           // ..............*...............
        vhadd.S32 q4, q5, q0               // ...............*..............
        vldrw.S32 q5, [r0, #16]            // ................e.............
        vhsub.S32 q3, q5, q2               // .................e............
        vldrw.S32 q6, [r3]                 // ..................e...........
        vhadd.S32 q5, q5, q2               // ...................e..........
        vldrw.S32 q2, [r7], #16            // ....................e.........
        vhadd.S32 q0, q6, q1               // .....................e........
        vstrw.32 q4, [r0], #16             // ......................*.......
        vhsub.S32 q1, q6, q1               // .......................e......
        vstrw.32 q7, [r5], #16             // ........................*.....

                                                            // ------------- cycle (expected) -------------->
                                                            // 0                        25
                                                            // |------------------------|--------------------
        // vldrw.s32   q<qA>, [r0]                          // ............e........'...............~........
        // vldrw.s32   q<qB>, [r3]                          // ..............e......'.................~......
        // vldrw.s32   q<qC>, [r4]                          // e....................'...~....................
        // vldrw.s32   q<qD>, [r5]                          // .......e.............'..........~.............
        // vldrw.s32  q<qTw1>, [r6], #16                    // .....................'.*......................
        // vldrw.s32  q<qTw2>, [r7], #16                    // ................e....'...................~....
        // vldrw.s32  q<qTw3>, [r8], #16                    // .....~...............'........*...............
        // vhadd.s32  q<qSm0>, q<qA>,   q<qC>               // ...............e.....'..................~.....
        // vhadd.s32  q<qSm1>, q<qB>,   q<qD>               // .................e...'....................~...
        // vhsub.s32  q<qDf0>, q<qA>,   q<qC>               // .............e.......'................~.......
        // vhsub.s32  q<qDf1>, q<qB>,   q<qD>               // ...................e.'......................~.
        // vhadd.s32  q<qA>,   q<qSm0>, q<qSm1>             // ...........~.........'..............*.........
        // vhsub.s32  q<qBp>,  q<qSm0>, q<qSm1>             // ...~.................'......*.................
        // vhcadd.s32 q<qCp>,  q<qDf0>, q<qDf1>, #270       // .....................*........................
        // vhcadd.s32 q<qDp>,  q<qDf0>, q<qDf1>, #90        // .~...................'....*...................
        // vqdmlsdh.s32 q<qB>, q<qTw1>, q<qBp>              // ....~................'.......*................
        // vqdmladhx.s32  q<qB>, q<qTw1>, q<qBp>            // ......~..............'.........*..............
        // vqdmlsdh.s32 q<qC>, q<qTw2>, q<qCp>              // .....................'*.......................
        // vqdmladhx.s32  q<qC>, q<qTw2>, q<qCp>            // .....................'..*.....................
        // vqdmlsdh.s32 q<qD>, q<qTw3>, q<qDp>              // ........~............'...........*............
        // vqdmladhx.s32  q<qD>, q<qTw3>, q<qDp>            // ..........~..........'.............*..........
        // vstrw.32   q<qA>, [r0], #16                      // ..................~..'.....................*..
        // vstrw.32   q<qB>, [r3], #16                      // .........~...........'............*...........
        // vstrw.32   q<qC>, [r4], #16                      // ..~..................'.....*..................
        // vstrw.32   q<qD>, [r5], #16                      // ....................~'.......................*

        le lr, fixedpoint_radix4_fft_loop_start
        vhcadd.S32 q4, q3, q1, #270// a-ib-c+id
        vqdmlsdh.S32 q6, q2, q4
        vldrw.S32 q7, [r6], #16
        vqdmladhx.S32 q6, q2, q4
        vhcadd.S32 q4, q3, q1, #90// a+ib-c-id
        vstrw.32 q6, [r4], #16
        vhsub.S32 q1, q5, q0// a-b+c-d
        vqdmlsdh.S32 q3, q7, q1
        vldrw.S32 q6, [r8], #16
        vqdmladhx.S32 q3, q7, q1
        vqdmlsdh.S32 q7, q6, q4
        vstrw.32 q3, [r3], #16
        vqdmladhx.S32 q7, q6, q4
        vhadd.S32 q4, q5, q0// a+b+c+d
        vstrw.32 q4, [r0], #16
        vstrw.32 q7, [r5], #16

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

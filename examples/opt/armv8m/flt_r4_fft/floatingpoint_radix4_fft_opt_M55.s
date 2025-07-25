        .syntax unified
        .type   floatingpoint_radix4_fft_opt_M55, %function
        .global floatingpoint_radix4_fft_opt_M55


        inA .req r0
        pW0 .req r1 // Use the same twiddle data for TESTING ONLY
        sz  .req r2

        inB .req r3
        inC .req r4
        inD .req r5

        pW1 .req r6
        pW2 .req r7
        pW3 .req r8

        // NOTE:
        // We deliberately leave some aliases undefined
        // SLOTHY will fill them in as part of a 'dry-run'
        // merely concretizing symbolic registers, but not
        // yet reordering.

        .text
        .align 4
floatingpoint_radix4_fft_opt_M55:
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

.macro load_data
        vldrw.32   q<qA>, [inA]
        vldrw.32   q<qB>, [inB]
        vldrw.32   q<qC>, [inC]
        vldrw.32   q<qD>, [inD]
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

.macro cmul_flt out, in0, in1
        vcmul.f32  \out, \in0, \in1, #0
        vcmla.f32  \out, \in0, \in1, #270
.endm

        vldrw.32 q1, [r5]
        vldrw.32 q5, [r4]
        vldrw.32 q3, [r3]
        vadd.F32 q4, q3, q1// b+d
        vldrw.32 q2, [r0]
        vadd.F32 q0, q2, q5// a+c
        vsub.F32 q1, q3, q1// b-d
        vadd.F32 q3, q0, q4// a+b+c+d
        vsub.F32 q7, q2, q5// a-c
        vldrw.S32 q5, [r6], #16
        vcadd.F32 q2, q7, q1, #90// a+ib-c-id
        vstrw.32 q3, [r0], #16
        vsub.F32 q3, q0, q4// a-b+c-d
        vcmul.F32 q4, q5, q3, #0
        vldrw.S32 q0, [r7], #16
        vcmla.F32 q4, q5, q3, #270
        vldrw.S32 q3, [r8], #16
        vcmul.F32 q6, q3, q2, #0
        vstrw.32 q4, [r3], #16
        vcmla.F32 q6, q3, q2, #270
        sub lr, lr, #1
.p2align 2
flt_radix4_fft_loop_start:
                                          // Instructions:    25
                                          // Expected cycles: 28
                                          // Expected IPC:    0.89
                                          //
                                          // Cycle bound:     28.0
                                          // IPC bound:       0.89
                                          //
                                          // Wall time:     1.89s
                                          // User time:     1.89s
                                          //
                                          // ----- cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|----
        vcadd.F32 q4, q7, q1, #270        // *.............................
        vldrw.32 q1, [r5, #16]            // .e............................
        vcmul.F32 q7, q0, q4, #0          // ..*...........................
        vldrw.32 q5, [r4, #16]            // ...e..........................
        vcmla.F32 q7, q0, q4, #270        // ....*.........................
        vldrw.32 q3, [r3]                 // .....e........................
        vadd.F32 q4, q3, q1               // ......e.......................
        vldrw.32 q2, [r0]                 // .......e......................
        vadd.F32 q0, q2, q5               // ........e.....................
        vstrw.32 q6, [r5], #16            // .........*....................
        vsub.F32 q1, q3, q1               // ..........e...................
        vstrw.32 q7, [r4], #16            // ...........*..................
        vadd.F32 q3, q0, q4               // ............e.................
        vsub.F32 q7, q2, q5               // ..............e...............
        vldrw.S32 q5, [r6], #16           // ...............e..............
        vcadd.F32 q2, q7, q1, #90         // ................e.............
        vstrw.32 q3, [r0], #16            // .................e............
        vsub.F32 q3, q0, q4               // ..................e...........
        vcmul.F32 q4, q5, q3, #0          // ....................e.........
        vldrw.S32 q0, [r7], #16           // .....................e........
        vcmla.F32 q4, q5, q3, #270        // ......................e.......
        vldrw.S32 q3, [r8], #16           // .......................e......
        vcmul.F32 q6, q3, q2, #0          // ........................e.....
        vstrw.32 q4, [r3], #16            // .........................e....
        vcmla.F32 q6, q3, q2, #270        // ..........................e...

                                                           // ---------- cycle (expected) ---------->
                                                           // 0                        25
                                                           // |------------------------|-------------
        // vldrw.32   q<qA>, [r0]                          // ......e....................'......~....
        // vldrw.32   q<qB>, [r3]                          // ....e......................'....~......
        // vldrw.32   q<qC>, [r4]                          // ..e........................'..~........
        // vldrw.32   q<qD>, [r5]                          // e..........................'~..........
        // vldrw.s32  q<qTw1>, [r6], #16                   // ..............e............'...........
        // vldrw.s32  q<qTw2>, [r7], #16                   // ....................e......'...........
        // vldrw.s32  q<qTw3>, [r8], #16                   // ......................e....'...........
        // vadd.f32  q<qSm0>,  q<qA>,   q<qC>              // .......e...................'.......~...
        // vadd.f32  q<qSm1>,  q<qB>,   q<qD>              // .....e.....................'.....~.....
        // vsub.f32  q<qDf0>, q<qA>,   q<qC>               // .............e.............'...........
        // vsub.f32  q<qDf1>, q<qB>,   q<qD>               // .........e.................'.........~.
        // vadd.f32  q<qA>,   q<qSm0>,  q<qSm1>            // ...........e...............'...........
        // vsub.f32  q<qBp>,  q<qSm0>,  q<qSm1>            // .................e.........'...........
        // vcadd.f32 q<qCp>,  q<qDf0>, q<qDf1>, #270       // ...........................*...........
        // vcadd.f32 q<qDp>,  q<qDf0>, q<qDf1>, #90        // ...............e...........'...........
        // vcmul.f32  q<qB>, q<qTw1>, q<qBp>, #0           // ...................e.......'...........
        // vcmla.f32  q<qB>, q<qTw1>, q<qBp>, #270         // .....................e.....'...........
        // vcmul.f32  q<qC>, q<qTw2>, q<qCp>, #0           // .~.........................'.*.........
        // vcmla.f32  q<qC>, q<qTw2>, q<qCp>, #270         // ...~.......................'...*.......
        // vcmul.f32  q<qD>, q<qTw3>, q<qDp>, #0           // .......................e...'...........
        // vcmla.f32  q<qD>, q<qTw3>, q<qDp>, #270         // .........................e.'...........
        // vstrw.32   q<qA>, [r0], #16                     // ................e..........'...........
        // vstrw.32   q<qB>, [r3], #16                     // ........................e..'...........
        // vstrw.32   q<qC>, [r4], #16                     // ..........~................'..........*
        // vstrw.32   q<qD>, [r5], #16                     // ........~..................'........*..

        le lr, flt_radix4_fft_loop_start
        vcadd.F32 q4, q7, q1, #270// a-ib-c+id
        vcmul.F32 q7, q0, q4, #0
        vcmla.F32 q7, q0, q4, #270
        vstrw.32 q6, [r5], #16
        vstrw.32 q7, [r4], #16

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

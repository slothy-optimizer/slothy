        .syntax unified
        .type   floatingpoint_radix4_fft_symbolic, %function
        .global floatingpoint_radix4_fft_symbolic


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
floatingpoint_radix4_fft_symbolic:
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

        vldrw.32 q2, [r4]
        vldrw.32 q5, [r0]
        vldrw.32 q3, [r5]
        vadd.F32 q6, q5, q2// a+c
        vsub.F32 q4, q5, q2// a-c
        sub lr, lr, #1
.p2align 2
flt_radix4_fft_loop_start:
                                          // Instructions:    25
                                          // Expected cycles: 28
                                          // Expected IPC:    0.89
                                          //
                                          // Wall time:     1.40s
                                          // User time:     1.40s
                                          //
                                          // ----- cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|----
        vldrw.32 q0, [r3]                 // *.............................
        vsub.F32 q7, q0, q3               // .*............................
        vadd.F32 q0, q0, q3               // ...*..........................
        vldrw.32 q2, [r4]                 // ....e.........................
        vadd.F32 q3, q6, q0               // .....*........................
        vldrw.32 q5, [r0]                 // ......e.......................
        vsub.F32 q0, q6, q0               // .......*......................
        vldrw.S32 q6, [r6], #16           // ........*.....................
        vcmul.F32 q1, q6, q0, #0          // .........*....................
        vstrw.32 q3, [r0], #16            // ..........*...................
        vcmla.F32 q1, q6, q0, #270        // ...........*..................
        vstrw.32 q1, [r3], #16            // ............*.................
        vcadd.F32 q6, q4, q7, #90         // .............*................
        vcadd.F32 q0, q4, q7, #270        // ...............*..............
        vldrw.S32 q4, [r7], #16           // ................*.............
        vcmul.F32 q1, q4, q0, #0          // .................*............
        vldrw.32 q3, [r5]                 // ..................e...........
        vcmla.F32 q1, q4, q0, #270        // ...................*..........
        vldrw.S32 q7, [r8], #16           // ....................*.........
        vcmul.F32 q0, q7, q6, #0          // .....................*........
        vstrw.32 q1, [r4], #16            // ......................*.......
        vcmla.F32 q0, q7, q6, #270        // .......................*......
        vstrw.32 q0, [r5], #16            // ........................*.....
        vadd.F32 q6, q5, q2               // .........................e....
        vsub.F32 q4, q5, q2               // ...........................e..

                                                           // --------------- cycle (expected) --------------->
                                                           // 0                        25
                                                           // |------------------------|-----------------------
        // vldrw.32   q<qA>, [r0]                          // ..e.....................'.....~..................
        // vldrw.32   q<qB>, [r3]                          // ........................*........................
        // vldrw.32   q<qC>, [r4]                          // e.......................'...~....................
        // vldrw.32   q<qD>, [r5]                          // ..............e.........'.................~......
        // vldrw.s32  q<qTw1>, [r6], #16                   // ....~...................'.......*................
        // vldrw.s32  q<qTw2>, [r7], #16                   // ............~...........'...............*........
        // vldrw.s32  q<qTw3>, [r8], #16                   // ................~.......'...................*....
        // vadd.f32  q<qSm0>,  q<qA>,   q<qC>              // .....................e..'........................
        // vadd.f32  q<qSm1>,  q<qB>,   q<qD>              // ........................'..*.....................
        // vsub.f32  q<qDf0>, q<qA>,   q<qC>               // .......................e'........................
        // vsub.f32  q<qDf1>, q<qB>,   q<qD>               // ........................'*.......................
        // vadd.f32  q<qA>,   q<qSm0>,  q<qSm1>            // .~......................'....*...................
        // vsub.f32  q<qBp>,  q<qSm0>,  q<qSm1>            // ...~....................'......*.................
        // vcadd.f32 q<qCp>,  q<qDf0>, q<qDf1>, #270       // ...........~............'..............*.........
        // vcadd.f32 q<qDp>,  q<qDf0>, q<qDf1>, #90        // .........~..............'............*...........
        // vcmul.f32  q<qB>, q<qTw1>, q<qBp>, #0           // .....~..................'........*...............
        // vcmla.f32  q<qB>, q<qTw1>, q<qBp>, #270         // .......~................'..........*.............
        // vcmul.f32  q<qC>, q<qTw2>, q<qCp>, #0           // .............~..........'................*.......
        // vcmla.f32  q<qC>, q<qTw2>, q<qCp>, #270         // ...............~........'..................*.....
        // vcmul.f32  q<qD>, q<qTw3>, q<qDp>, #0           // .................~......'....................*...
        // vcmla.f32  q<qD>, q<qTw3>, q<qDp>, #270         // ...................~....'......................*.
        // vstrw.32   q<qA>, [r0], #16                     // ......~.................'.........*..............
        // vstrw.32   q<qB>, [r3], #16                     // ........~...............'...........*............
        // vstrw.32   q<qC>, [r4], #16                     // ..................~.....'.....................*..
        // vstrw.32   q<qD>, [r5], #16                     // ....................~...'.......................*

        le lr, flt_radix4_fft_loop_start
        vldrw.32 q0, [r3]
        vsub.F32 q7, q0, q3// b-d
        vadd.F32 q0, q0, q3// b+d
        vadd.F32 q3, q6, q0// a+b+c+d
        vsub.F32 q0, q6, q0// a-b+c-d
        vldrw.S32 q6, [r6], #16
        vcmul.F32 q1, q6, q0, #0
        vstrw.32 q3, [r0], #16
        vcmla.F32 q1, q6, q0, #270
        vstrw.32 q1, [r3], #16
        vcadd.F32 q6, q4, q7, #90// a+ib-c-id
        vcadd.F32 q0, q4, q7, #270// a-ib-c+id
        vldrw.S32 q4, [r7], #16
        vcmul.F32 q1, q4, q0, #0
        vcmla.F32 q1, q4, q0, #270
        vldrw.S32 q7, [r8], #16
        vcmul.F32 q0, q7, q6, #0
        vstrw.32 q1, [r4], #16
        vcmla.F32 q0, q7, q6, #270
        vstrw.32 q0, [r5], #16

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

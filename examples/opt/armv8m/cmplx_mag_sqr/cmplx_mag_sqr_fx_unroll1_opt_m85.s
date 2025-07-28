        .syntax unified
        .type   cmplx_mag_sqr_fx_unroll1_opt_M85, %function
        .global cmplx_mag_sqr_fx_unroll1_opt_M85

        .text
        .align 4
cmplx_mag_sqr_fx_unroll1_opt_M85:
        push {r4-r12,lr}
        vpush {d0-d15}

        out   .req r0
        in    .req r1
        sz    .req r2

        lsr lr, sz, #2
        wls lr, lr, end
.p2align 2
        vld20.32 {q2, q3}, [r1]
        vld21.32 {q2, q3}, [r1]!
        sub lr, lr, #1
.p2align 2
start:
                                        // Instructions:    6
                                        // Expected cycles: 9
                                        // Expected IPC:    0.67
                                        //
                                        // Wall time:     0.02s
                                        // User time:     0.02s
                                        //
                                        // ----- cycle (expected) ------>
                                        // 0                        25
                                        // |------------------------|----
        vmulh.S32 q0, q3, q3            // *.............................
        vmulh.S32 q1, q2, q2            // ..*...........................
        vld20.32 {q2, q3}, [r1]         // ...e..........................
        vld21.32 {q2, q3}, [r1]!        // .....e........................
        vhadd.S32 q5, q0, q1            // ......*.......................
        vstrw.U32 q5, [r0], #16         // .......*......................

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // vld20.32 {q4,q5}, [r1]        // e.....'..~.....'..~.....'..~...
        // vld21.32 {q4,q5}, [r1]!       // ..e...'....~...'....~...'....~.
        // vmulh.s32 q2, q4, q4          // ......'.*......'.~......'.~....
        // vmulh.s32 q4, q5, q5          // ......*........~........~......
        // vhadd.s32 q4, q4, q2          // ...~..'.....*..'.....~..'......
        // vstrw.u32 q4, [r0] , #16      // ....~.'......*.'......~.'......

        le lr, start
        vmulh.S32 q0, q3, q3
        vmulh.S32 q1, q2, q2
        vhadd.S32 q5, q0, q1
        vstrw.U32 q5, [r0], #16
end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
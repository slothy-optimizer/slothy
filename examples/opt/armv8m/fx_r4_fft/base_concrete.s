        .syntax unified
        .type   fixedpoint_radix4_fft_base, %function
        .global fixedpoint_radix4_fft_base


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
        // merely concretizing ref registers, but not
        // yet reordering.

        .text
        .align 4
fixedpoint_radix4_fft_base:
        push {r4-r12,lr}
        vpush {d0-d15}

        add inB, inA, sz
        add inC, inB, sz
        add inD, inC, sz

        add pW1, pw0, sz
        add pW2, pW1, sz
        add pW3, pW2, sz

        lsr lr, sz, #4
        wls lr, lr, end

.p2align 2
fixedpoint_radix4_fft_loop_start:
        vldrw.s32 q1, [r0] 
        vldrw.s32 q4, [r4] 
        vldrw.s32 q3, [r3] 
        vldrw.s32 q6, [r5] 
        vhadd.s32 q2, q1, q4
        vhsub.s32 q0, q1, q4
        vhadd.s32 q4, q3, q6
        vhsub.s32 q6, q3, q6
        vhadd.s32 q3, q2, q4
        vstrw.u32 q3, [r0] , #16
        vhsub.s32 q2, q2, q4
        vldrw.s32 q4, [r6] , #16
        vqdmlsdh.s32 q3, q4, q2
        vqdmladhx.s32 q3, q4, q2
        vstrw.u32 q3, [r3] , #16
        vhcadd.s32 q4, q0, q6, #270
        vldrw.s32 q2, [r7] , #16
        vqdmlsdh.s32 q3, q2, q4
        vqdmladhx.s32 q3, q2, q4
        vstrw.u32 q3, [r4] , #16
        vhcadd.s32 q4, q0, q6, #90
        vldrw.s32 q3, [r8] , #16
        vqdmlsdh.s32 q6, q3, q4
        vqdmladhx.s32 q6, q3, q4
        vstrw.u32 q6, [r5] , #16
        le lr, fixedpoint_radix4_fft_loop_start

end:
        vpop {d0-d15}
        pop {r4-r12,lr}
        bx lr
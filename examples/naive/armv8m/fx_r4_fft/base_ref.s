        .syntax unified
        .type   fixedpoint_radix4_fft_ref, %function
        .global fixedpoint_radix4_fft_ref


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
fixedpoint_radix4_fft_ref:
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

fixedpoint_radix4_fft_loop_start:
        vldrw.s32     vA,   [inA]
        vldrw.s32     vC,   [inC]
        vldrw.s32     vB,   [inB]
        vldrw.s32     vD,   [inD]
        vhadd.s32     q<vSm0>, q<vA>,    q<vC>
        vhsub.s32     q<vDf0>, q<vA>,    q<vC>
        vhadd.s32     q<vSm1>, q<vB>,    q<vD>
        vhsub.s32     q<vDf1>, q<vB>,    q<vD>
        vhadd.s32     q<vT0>,  q<vSm0>,  q<vSm1>
        vstrw.s32     q<vT0>,  [inA], #16
        vhsub.s32     q<vT0>,  q<vSm0>,  q<vSm1>
        vldrw.s32     vW,   [pW1], #16
        vqdmlsdh.s32  vT1,  vW,    vT0
        vqdmladhx.s32 vT1,  vW,    vT0
        vstrw.s32     q<vT1>,  [inB], #16
        vhcadd.s32    vT0, vDf0, vDf1, #270
        vldrw.s32     vW,   [pW2], #16
        vqdmlsdh.s32  vT1,  vW,    vT0
        vqdmladhx.s32 vT1,  vW,    vT0
        vstrw.s32     q<vT1>,  [inC], #16
        vhcadd.s32    vT0, vDf0, vDf1, #90
        vldrw.s32     vW,   [pW3], #16
        vqdmlsdh.s32  vT1,  vW,    vT0
        vqdmladhx.s32 vT1,  vW,    vT0
        vstrw.s32     q<vT1>,  [inD], #16
        le lr, fixedpoint_radix4_fft_loop_start

end:
        vpop {d0-d15}
        pop {r4-r12,lr}
        bx lr

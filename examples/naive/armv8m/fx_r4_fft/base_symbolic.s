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
        vldrw.s32   qA, [inA]
        vldrw.s32   qB, [inB]
        vldrw.s32   qC, [inC]
        vldrw.s32   qD, [inD]
.endm

.macro load_twiddles
        vldrw.s32  qTw1, [pW1], #16
        vldrw.s32  qTw2, [pW2], #16
        vldrw.s32  qTw3, [pW3], #16
.endm

.macro store_data
        vstrw.32   qA, [inA], #16
        vstrw.32   qB, [inB], #16
        vstrw.32   qC, [inC], #16
        vstrw.32   qD, [inD], #16
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

fixedpoint_radix4_fft_loop_start:
        load_data
        load_twiddles
        vhadd.s32  qSm0, qA,   qC         // a+c
        vhadd.s32  qSm1, qB,   qD         // b+d
        vhsub.s32  qDf0, qA,   qC         // a-c
        vhsub.s32  qDf1, qB,   qD         // b-d
        vhadd.s32  qA,   qSm0, qSm1       // a+b+c+d
        vhsub.s32  qBp,  qSm0, qSm1       // a-b+c-d
        vhcadd.s32 qCp,  qDf0, qDf1, #270 // a-ib-c+id
        vhcadd.s32 qDp,  qDf0, qDf1, #90  // a+ib-c-id
        cmul_fx    qB,   qTw1, qBp        // Tw1*(a-b+c-d)
        cmul_fx    qC,   qTw2, qCp        // Tw2*(a-ib-c+id)
        cmul_fx    qD,   qTw3, qDp        // Tw3*(a+ib-c-id)
        store_data
        le         lr, fixedpoint_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

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
        vldrw.32   qA, [inA]
        vldrw.32   qB, [inB]
        vldrw.32   qC, [inC]
        vldrw.32   qD, [inD]
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

.macro cmul_flt out, in0, in1
        vcmul.f32  \out, \in0, \in1, #0
        vcmla.f32  \out, \in0, \in1, #270
.endm

flt_radix4_fft_loop_start:
        load_data
        load_twiddles
        vadd.f32  q<qSm0>,  q<qA>,   q<qC>        // a+c
        vadd.f32  q<qSm1>,  q<qB>,   q<qD>        // b+d
        vsub.f32  qDf0, qA,   qC         // a-c
        vsub.f32  qDf1, qB,   qD         // b-d
        vadd.f32  q<qA>,   q<qSm0>,  q<qSm1>      // a+b+c+d
        vsub.f32  qBp,  qSm0,  qSm1      // a-b+c-d
        vcadd.f32 qCp,  qDf0, qDf1, #270 // a-ib-c+id
        vcadd.f32 qDp,  qDf0, qDf1, #90  // a+ib-c-id
        cmul_flt  qB,   qTw1, qBp        // Tw1*(a-b+c-d)
        cmul_flt  qC,   qTw2, qCp        // Tw2*(a-ib-c+id)
        cmul_flt  qD,   qTw3, qDp        // Tw3*(a+ib-c-id)
        store_data
        le         lr, flt_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

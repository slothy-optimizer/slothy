        .syntax unified
        .type   floatingpoint_radix4_fft_ref, %function
        .global floatingpoint_radix4_fft_ref


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
floatingpoint_radix4_fft_ref:
        push    {r4-r12,lr}
        vpush   {d0-d15}

        add     inB, inA, sz
        add     inC, inB, sz
        add     inD, inC, sz

        add     pW1, pw0, sz
        add     pW2, pW1, sz
        add     pW3, pW2, sz

        lsr     lr, sz, #4
        wls     lr, lr, end

flt_radix4_fft_loop_start:
        vldrw.32   q1, [inA]
        vldrw.32   q6, [inC]
        vadd.f32   q0, q1, q6
        vldrw.32   q4, [inB]
        vsub.f32   q2, q1, q6
        vldrw.32   q5, [inD]
        vadd.f32   q1, q4, q5
        vsub.f32   q3, q4, q5
        vadd.f32   q4, q0, q1
        vstrw.32   q4, [inA], #16
        vsub.f32   q4, q0, q1
        vldrw.32   q5, [pW1], #16
        vcmul.f32  q0, q5, q4, #0
        vcmla.f32  q0, q5, q4, #270
        vstrw.32   q0, [inB], #16
        vcadd.f32  q4, q2, q3, #270
        vldrw.32   q5, [pW2], #16
        vcmul.f32  q0, q5, q4, #0
        vcmla.f32  q0, q5, q4, #270
        vstrw.u32  q0, [inC], #16
        vcadd.f32  q4, q2, q3, #90
        vldrw.32   q5, [pW3], #16
        vcmul.f32  q0, q5, q4, #0
        vcmla.f32  q0, q5, q4, #270
        vstrw.32   q0, [inD], #16
        le         lr, flt_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr

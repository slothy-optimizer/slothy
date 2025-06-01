        .syntax unified
        .type   floatingpoint_radix4_fft_base, %function
        .global floatingpoint_radix4_fft_base


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
floatingpoint_radix4_fft_base:
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

.p2align 2
flt_radix4_fft_loop_start:
        vldrw.32 q2, [r0] 
        vldrw.32 q3, [r4] 
        vadd.f32 q4, q2, q3
        vldrw.32 q1, [r3] 
        vsub.f32 q6, q2, q3
        vldrw.32 q7, [r5] 
        vadd.f32 q0, q1, q7
        vsub.f32 q2, q1, q7
        vadd.f32 q5, q4, q0
        vstrw.u32 q5, [r0] , #16
        vsub.f32 q0, q4, q0
        vldrw.32 q3, [r6] , #16
        vcmul.f32 q5, q3, q0, #0
        vcmla.f32 q5, q3, q0, #270
        vstrw.u32 q5, [r3] , #16
        vcadd.f32 q7, q6, q2, #270
        vldrw.32 q4, [r7] , #16
        vcmul.f32 q0, q4, q7, #0
        vcmla.f32 q0, q4, q7, #270
        vstrw.u32 q0, [r4] , #16
        vcadd.f32 q7, q6, q2, #90
        vldrw.32 q1, [r8] , #16
        vcmul.f32 q5, q1, q7, #0
        vcmla.f32 q5, q1, q7, #270
        vstrw.u32 q5, [r5] , #16
        le lr, flt_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr
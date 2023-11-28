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
        vldrw.32 q1, [r0] 
        vldrw.32 q0, [r4] 
        vadd.f32 q3, q1, q0
        vldrw.32 q5, [r3] 
        vsub.f32 q2, q1, q0
        vldrw.32 q0, [r5] 
        vadd.f32 q1, q5, q0
        vsub.f32 q6, q5, q0
        vadd.f32 q0, q3, q1
        vstrw.u32 q0, [r0] , #16
        vsub.f32 q1, q3, q1
        vldrw.32 q0, [r6] , #16
        vcmul.f32 q4, q0, q1, #0
        vcmla.f32 q4, q0, q1, #270
        vstrw.u32 q4, [r3] , #16
        vcadd.f32 q1, q2, q6, #270
        vldrw.32 q0, [r7] , #16
        vcmul.f32 q4, q0, q1, #0
        vcmla.f32 q4, q0, q1, #270
        vstrw.u32 q4, [r4] , #16
        vcadd.f32 q5, q2, q6, #90
        vldrw.32 q1, [r8] , #16
        vcmul.f32 q0, q1, q5, #0
        vcmla.f32 q0, q1, q5, #270
        vstrw.u32 q0, [r5] , #16
        le lr, flt_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr
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

.p2align 2
fixedpoint_radix4_fft_loop_start:
        vldrw.s32 q1, [r0] 
        vldrw.s32 q5, [r3] 
        vldrw.s32 q4, [r4] 
        vldrw.s32 q6, [r5] 
        vhadd.s32 q0, q1, q4
        vhadd.s32 q7, q5, q6
        vhsub.s32 q2, q1, q4
        vhsub.s32 q6, q5, q6
        vhadd.s32 q1, q0, q7
        vhsub.s32 q4, q0, q7
        vldrw.s32 q0, [r7] , #16
        vqdmlsdh.s32 q7, q0, q4
        vqdmladhx.s32 q7, q0, q4
        vhcadd.s32 q0, q2, q6, #270
        vldrw.s32 q5, [r6] , #16
        vqdmlsdh.s32 q4, q5, q0
        vqdmladhx.s32 q4, q5, q0
        vhcadd.s32 q5, q2, q6, #90
        vldrw.s32 q0, [r8] , #16
        vqdmlsdh.s32 q6, q0, q5
        vqdmladhx.s32 q6, q0, q5
        vstrw.u32 q1, [r0] , #16
        vstrw.u32 q7, [r3] , #16
        vstrw.u32 q4, [r4] , #16
        vstrw.u32 q6, [r5] , #16
        le lr, fixedpoint_radix4_fft_loop_start

end:
        vpop    {d0-d15}
        pop     {r4-r12,lr}
        bx      lr
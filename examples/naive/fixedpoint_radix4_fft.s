fixedpoint_radix4_fft_loop_start:
        vldrw.32      q1, [src0]
        vldrw.32      q6, [src2]
        vhadd.s32     q0, q1, q6
        vldrw.32      q4, [src1]
        vhsub.s32     q2, q1, q6
        vldrw.32      q5, [src3]
        vhadd.s32     q1, q4, q5
        vhsub.s32     q3, q4, q5
        vldrw.32      q7, [twiddle1], #16
        vhadd.s32     q4, q0, q1
        vstrw.32      q4, [src0], #16
        vhsub.s32     q4, q0, q1
        vldrw.32      q5, [twiddle0], #16
        vqdmlsdh.s32  q0, q4, q5
        vhcadd.s32    q6, q2, q3, #270
        vqdmladhx.s32 q0, q4, q5
        vstrw.32      q0, [src1], #16
        vqdmlsdh.s32  q0, q6, q7
        vqdmladhx.s32 q0, q6, q7
        vstrw.32      q0, [src2], #16
        vhcadd.s32    q4, q2, q3, #90
        vldrw.32      q5, [twiddle2], #16
        vqdmlsdh.s32  q0, q4, q5
        vqdmladhx.s32 q0, q4, q5
        vstrw.32      q0, [src3], #16
        le lr, fixedpoint_radix4_fft_loop_start

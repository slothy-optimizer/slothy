fixedpoint_radix4_fft_loop_start:
        vldrw.s32     vA,   [inA]
        vldrw.s32     vC,   [inC]
        vldrw.s32     vB,   [inB]
        vldrw.s32     vD,   [inD]
        vhadd.s32     vSm0, vA,    vC
        vhsub.s32     vDf0, vA,    vC
        vhadd.s32     vSm1, vB,    vD
        vhsub.s32     vDf1, vB,    vD
        vhadd.s32     vT0,  vSm0,  vSm1
        vstrw.s32     vT0,  [inA], #16
        vhsub.s32     vT0,  vSm0,  vSm1
        vldrw.s32     vW,   [pW2], #16
        vqdmladhx.s32 vT1,  vW,    vT0
        vqdmlsdh.s32  vT1,  vW,    vT0
        vstrw.s32     vT1,  [inB], #16
        vhcadd.s32 vT0, vDf0, vDf1, #270
        vldrw.s32     vW,   [pW1], #16
        vqdmladhx.s32 vT1,  vW,    vT0
        vqdmlsdh.s32  vT1,  vW,    vT0
        vstrw.s32     vT1,  [inC], #16
        vhcadd.s32 vT0, vDf0, vDf1, #90
        vldrw.s32     vW,   [pW3], #16
        vqdmladhx.s32 vT1,  vW,    vT0
        vqdmlsdh.s32  vT1,  vW,    vT0
        vstrw.s32     vT1,  [inD], #16
        le lr, fixedpoint_radix4_fft_loop_start

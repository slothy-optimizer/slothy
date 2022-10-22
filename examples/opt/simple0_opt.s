        vldrw.u32 q5, [r10] , #16
        vldrw.u32 q6, [r2]
        vmulh.u32 q4, q6, q5
        vldrw.u32 q6, [r2, #32]
        vldrw.u32 q2, [r2, #16]
        vmulh.u32 q1, q6, q5
        vadd.u32 q7, q4, q4
        vadd.u32 q3, q7, q5
        vmulh.u32 q4, q2, q5
        vadd.u32 q2, q1, q1
        vadd.u32 q6, q4, q4
        vstrw.u32 q3, [r2] , #48
        vadd.u32 q0, q2, q5
        vstrw.u32 q0, [r2, #-16]
        vadd.u32 q6, q6, q5
        vstrw.u32 q6, [r2, #-32]
        vldrw.u32 q4, [r0]
        vmla.s32 q4, q1, r9
        sub lr, lr, #1
.p2align 2
start:
        vmla.s32 q4, q1, r9
        vstrw.u32 q4, [r1]
        vldrw.u32 q4, [r0]
        vmla.s32 q4, q1, r9
        le lr, start
        vmla.s32 q4, q1, r9
        vstrw.u32 q4, [r1]
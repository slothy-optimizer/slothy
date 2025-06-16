start:
    vldrw.u32  q0, [r<inA>]
    vldrw.u32  q1, [r<inA>, #16]
    vldrw.u32  q2, [r<inA>, #32]
    vldrw.u32  q7, [r<inB>], #16
    vmulh.u32  q0, q0, q7
    vmulh.u32  q1, q1, q7
    vmulh.u32  q2, q2, q7
    vadd.u32   q0, q0, q0
    vadd.u32   q0, q0, q7
    vadd.u32   q1, q1, q1
    vadd.u32   q1, q1, q7
    vadd.u32   q2, q2, q2
    vadd.u32   q2, q2, q7
    vstrw.u32  q1, [r<inA>, #16]
    vstrw.u32  q2, [r<inA>, #32]
    vstrw.u32  q0, [r<inA>], #48
    le lr, start

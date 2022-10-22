vldrw.32   q1, [src0]
vldrw.32   q6, [src2]
vadd.f32   q0, q1, q6
vldrw.32   q4, [src1]
vsub.f32   q2, q1, q6
vldrw.32   q5, [src3]
vadd.f32   q1, q4, q5
vsub.f32   q3, q4, q5
vadd.f32   q4, q0, q1
vstrw.32   q4, [src0], #16
vsub.f32   q4, q0, q1
vldrw.32   q5, [t0], #16
vcmul.f32  q0, q5, q4, #0
vcmla.f32  q0, q5, q4, #270
vstrw.32   q0, [src1], #16
vcadd.f32  q4, q2, q3, #270
vldrw.32   q5, [t1], #16
vcmul.f32  q0, q5, q4, #0
vcmla.f32  q0, q5, q4, #270
vstrw.u32  q0, [src2], #16
vcadd.f32  q4, q2, q3, #90
vldrw.32   q5, [t2], #16
vcmul.f32  q0, q5, q4, #0
vcmla.f32  q0, q5, q4, #270
vstrw.32   q0, [src3], #16

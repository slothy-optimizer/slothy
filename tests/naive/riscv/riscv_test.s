//start_label:
//    vsetvli a7, a7, e16, m4, tu, mu
//    vmul.vx  v0, v24, t3
//    vmulh.vx v4, v8, x10
//    vsetivli a3, 8, e16, m1, tu, mu
//    vmulh.vx v1, v2, x10
//end_label:

start_label:
    vsetvli a7, a7, e16, m1, tu, mu
    vmul.vx  v1, v24, t3
    vmulh.vx v4, v8, x10
    vsetivli a3, 8, e16, m8, tu, mu
    vmulh.vx v8, v16, x10
end_label:
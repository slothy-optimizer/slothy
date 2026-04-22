start_label:
    //vsetvli a7, a7, e16, m8, tu, mu
    vmul.vx  v0, v24, t3
    //vsetvli a2, a7, e16, m4, tu, mu
    vmulh.vx v1, v1, t0
    vsetivli a3, 8, e16, m1, tu, mu
    vrgather.vv v9, v24, v1
end_label:
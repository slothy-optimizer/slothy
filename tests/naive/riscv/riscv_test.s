start_label:
    li t0, 3329
    li t1, -3327
    li a7, 8*8
    addi a6, a1, _ZETAS_EXP*2

    vsetvli a7, a7, e16, m8, tu, mu
    lh t3, 0*2(a6)
    lh t2, 1*2(a6)
    // a[0-63] & a[128-191]
    addi a5, a0, 128*2
    vle16.v v16, (a0)
    vle16.v v24, (a5)
    vmul.vx  v0, v24, t3
    vmulh.vx v8, v24, t2
    vmulh.vx v0, v0, t0
    vsub.vv  v0, v8, v0
    vsub.vv  v24, v16, v0
    vadd.vv  v16, v16, v0
    vse16.v v16, (a0)
    vse16.v v24, (a5)
    addi a4, a0, 64*2
    addi a5, a5, 64*2
    vle16.v v16, (a4)
    vle16.v v24, (a5)
    vmul.vx  v0, v24, t3
    vmulh.vx v8, v24, t2
    vmulh.vx v0, v0, t0
    vsub.vv  v0, v8, v0
    vsub.vv  v24, v16, v0
    vadd.vv  v16, v16, v0
    vse16.v v16, (a4)
    vse16.v v24, (a5)
    li a7, 8*8
    addi a6, a1, _ZETAS_EXP_1TO6_P0_L1*2

    vsetvli a7, a7, e16, m8, tu, mu
    addi a4, a0, (0*128)*2
    addi a5, a0, (64+0*128)*2
    lh t3, 0*2(a6)
    lh t2, 1*2(a6)
    // a[0-63] & a[64-127] or a[128-191] & a[192-255]
    vle16.v v16, (a4)
    vle16.v v24, (a5)
    // level 1
    vmul.vx  v0, v24, t3
    vmulh.vx v8, v24, t2
    vmulh.vx v0, v0, t0
    vsub.vv  v0, v8, v0
    vsub.vv  v24, v16, v0
    vadd.vv  v16, v16, v0
    // level 2
    li a7, 8*4
    lh t3, 2*2(a6)
    lh t2, 3*2(a6)

    vsetvli a7, a7, e16, m4, tu, mu
    lh t5, 4*2(a6)
    lh t4, 5*2(a6)
    vmul.vx  v0, v20, t3
    vmul.vx  v8, v28, t5
    vmulh.vx v4, v20, t2
    vmulh.vx v12, v28, t4
    vmulh.vx v0, v0, t0
    vmulh.vx v8, v8, t0
    vsub.vv  v0, v4, v0
    vsub.vv  v8, v12, v8
    vsub.vv  v20, v16, v0
    vsub.vv  v28, v24, v8
    vadd.vv  v16, v16, v0
    vadd.vv  v24, v24, v8
end_label:
start_label:
    //lh t3, 0*2(a6)
    //lh t2, 1*2(a6)
    //addi a5, a0, 128*2
    //vle16.v v16, (a0)
    //vle16.v v24, (a5)
    //vmul.vx  v0, v24, t3
    //vmulh.vx v8, v24, t2
    //vmulh.vx v0, v0, t0
    //vsub.vv  v0, v8, v0
    //vsub.vv  v24, v16, v0
    //vadd.vv  v16, v16, v0
    //vse16.v v16, (a0)
    //vse16.v v24, (a5)
    //addi a4, a0, 64*2
    //addi a5, a5, 64*2
    //vle16.v v16, (a4)
    //vle16.v v24, (a5)
    //vmul.vx  v0, v24, t3
    //vmulh.vx v8, v24, t2
    //vmulh.vx v0, v0, t0
    //vsub.vv  v0, v8, v0
    //vsub.vv  v24, v16, v0
    //vadd.vv  v16, v16, v0
    //vse16.v v16, (a4)
    vse16.v v24, (a5)
    li a7, 8*8
end_label:
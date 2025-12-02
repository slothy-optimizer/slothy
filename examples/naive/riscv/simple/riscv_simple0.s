start:
    vmul.vv    v0,  v1,  v2
    vmul.vv    v3,  v4,  v5
    vmul.vv    v6,  v7,  v8
    vmul.vv    v9,  v10, v11
    vmul.vv    v12, v13, v14
    vmul.vv    v15, v16, v17
    vmul.vv    v18, v19, v20
    vmul.vv    v21, v22, v23

    vmulhu.vv  v2,  v1,  v24
    vmulhu.vv  v5,  v4,  v25
    vmulhu.vv  v8,  v7,  v26
    vmulhu.vv  v11, v10, v27
    vmulhu.vv  v14, v13, v28
    vmulhu.vv  v17, v16, v29
    vmulhu.vv  v20, v19, v30
    vmulhu.vv  v23, v22, v31

    vnmsac.vx  v0,  a2, v2
    vnmsac.vx  v3,  a2, v5
    vnmsac.vx  v6,  a2, v8
    vnmsac.vx  v9,  a2, v11
    vnmsac.vx  v12, a2, v14
    vnmsac.vx  v15, a2, v17
    vnmsac.vx  v18, a2, v20
    vnmsac.vx  v21, a2, v23

    vsub.vv  v0,  v1,  v0     // f_{n+i}' = f_i - t
    vsub.vv  v3,  v4,  v3
    vadd.vv  v1,  v1,  v0     // f_i'     = f_i + t
    vsub.vv  v6,  v7,  v6
    vadd.vv  v4,  v4,  v3
    vsub.vv  v9,  v10, v9
    vadd.vv  v7,  v7,  v6
    vsub.vv  v12, v13, v12
    vadd.vv  v10, v10, v9
    vsub.vv  v15, v16, v15
    vadd.vv  v13, v13, v12
    vsub.vv  v18, v19, v18
    vadd.vv  v16, v16, v15
    vsub.vv  v21, v22, v21
    vadd.vv  v19, v19, v18
    vadd.vv  v22, v22, v21
end:
.globl normal2ntt_order_rvv_vlen128
.align 2
normal2ntt_order_rvv_vlen128:
    li a2, 2
normal2ntt_order_rvv_vlen128_loop:
    addi a5, a0, 64*2
    vsetivli a7, 8, e16, m1, tu, mu
    vl8re16.v v16, (a0)
    vl8re16.v v24, (a5)
    # shuffle4
    addi t2, a1, _MASK_01230123*2
    addi t3, a1, _MASK_45674567*2
    li t6, 0x0f
    vle16.v v1, (t2)
    vle16.v v2, (t3)
    vmv.s.x v0, t6
    shuffle_x2 v16, v24, v17, v25, v8, v9, v10, v11, v1, v2
    shuffle_x2 v18, v26, v19, v27, v8, v9, v10, v11, v1, v2
    shuffle_x2 v20, v28, v21, v29, v8, v9, v10, v11, v1, v2
    shuffle_x2 v22, v30, v23, v31, v8, v9, v10, v11, v1, v2
    # shuffle2
    addi t2, a1, _MASK_01014545*2
    addi t3, a1, _MASK_23236767*2
    li t6, 0x33
    vle16.v v1, (t2)
    vle16.v v2, (t3)
    vmv.s.x v0, t6
    shuffle_x2 v16, v20, v24, v28, v8, v9, v10, v11, v1, v2
    shuffle_x2 v17, v21, v25, v29, v8, v9, v10, v11, v1, v2
    shuffle_x2 v18, v22, v26, v30, v8, v9, v10, v11, v1, v2
    shuffle_x2 v19, v23, v27, v31, v8, v9, v10, v11, v1, v2
    # shuffle1
    addi t2, a1, _MASK_10325476*2
    li t6, 0x55
    vle16.v v1, (t2)
    vmv.s.x v0, t6
    addi a5, a0, 4*8*2
    shuffle_o_x2 v8,  v9,  v10, v11, v16, v18, v20, v22, v1, v1
    vs4r.v v8,  (a0)
    addi a0, a0, 8*8*2
    shuffle_o_x2 v12, v13, v14, v15, v24, v26, v28, v30, v1, v1
    vs4r.v v12, (a5)
    addi a5, a5, 8*8*2
    shuffle_o_x2 v8,  v9,  v10, v11, v17, v19, v21, v23, v1, v1
    vs4r.v v8,  (a0)
    addi a0, a0, 8*8*2
    shuffle_o_x2 v12, v13, v14, v15, v25, v27, v29, v31, v1, v1
    vs4r.v v12, (a5)
    addi a2, a2, -1
    bnez a2, normal2ntt_order_rvv_vlen128_loop
ret
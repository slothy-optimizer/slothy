.globl ntt2normal_order_rvv_vlen128
.align 2
ntt2normal_order_rvv_vlen128:
    li a2, 2
ntt2normal_order_rvv_vlen128_loop:
    addi a5, a0, 64*2
    vsetivli a7, 8, e16, m1, tu, mu
    vl8re16.v v16, (a0)
    # shuffle1
    addi t2, a1, _MASK_10325476*2
    li t6, 0x55
    vle16.v v1, (t2)
    vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8, v9, v10, v11, v1, v1
    vl8re16.v v24, (a5)
    shuffle_x2 v20, v21, v22, v23, v8, v9, v10, v11, v1, v1
    shuffle_x2 v24, v25, v26, v27, v8, v9, v10, v11, v1, v1
    shuffle_x2 v28, v29, v30, v31, v8, v9, v10, v11, v1, v1
    # shuffle2
    addi t2, a1, _MASK_01014545*2
    addi t3, a1, _MASK_23236767*2
    li t6, 0x33
    vle16.v v1, (t2)
    vle16.v v2, (t3)
    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v20, v22, v8, v9, v10, v11, v1, v2
    shuffle_x2 v24, v26, v28, v30, v8, v9, v10, v11, v1, v2
    shuffle_x2 v17, v19, v21, v23, v8, v9, v10, v11, v1, v2
    shuffle_x2 v25, v27, v29, v31, v8, v9, v10, v11, v1, v2
    # shuffle4
    addi t2, a1, _MASK_01230123*2
    addi t3, a1, _MASK_45674567*2
    li t6, 0x0f
    vle16.v v1, (t2)
    vle16.v v2, (t3)
    vmv.s.x v0, t6
    addi a5, a0, 8*8*2
    shuffle_o_x2 v8,  v12, v9,  v13, v16, v20, v24, v28, v1, v2
    shuffle_o_x2 v10, v14, v11, v15, v17, v21, v25, v29, v1, v2
    vs4r.v v8, (a0)
    vs4r.v v12, (a5)
    addi a0, a0, 4*8*2
    addi a5, a5, 4*8*2
    shuffle_o_x2 v8,  v12, v9,  v13, v18, v22, v26, v30, v1, v2
    shuffle_o_x2 v10, v14, v11, v15, v19, v23, v27, v31, v1, v2
    vs4r.v v8, (a0)
    vs4r.v v12, (a5)
    addi a2, a2, -1
    addi a0, a5, 4*8*2
    bnez a2, ntt2normal_order_rvv_vlen128_loop
ret
// void poly_basemul_acc_rvv_vlen128(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table)
.globl poly_basemul_acc_rvv_vlen128
.align 2
poly_basemul_acc_rvv_vlen128:
    li a7, 32;  li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  a3, a3, t3; add  t3, a6, a7; addi t2, a1, 256*2
poly_basemul_acc_rvv_vlen128_loop:
    vle16.v v0, (a1); vle16.v v8,  (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v4, (a1); vle16.v v12, (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v1, (a1); vle16.v v9,  (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v5, (a1); vle16.v v13, (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v2, (a1); vle16.v v10, (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v6, (a1); vle16.v v14, (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v3, (a1); vle16.v v11, (a2); add a1, a1, a7; add a2, a2, a7
    vle16.v v7, (a1); vle16.v v15, (a2); add a1, a1, a7; add a2, a2, a7
    montmul_x4 v16, v17, v18, v19, v0, v1, v2, v3, \
        v12, v13, v14, v15, t0, t1, v24, v25, v26, v27
    montmul_x4 v20, v21, v22, v23, v4, v5, v6, v7, \
        v8,  v9,  v10, v11, t0, t1, v24, v25, v26, v27
    add a4, a0, a7;   add a5, a0, t3;   vle16.v v24, (a4); vle16.v v25, (a5)
    add a4, a4, t5;   add a5, a5, t5;   vle16.v v26, (a4); vle16.v v27, (a5)
    # a0b1 + a1b0; then accumulate
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
    vadd.vv v16, v16, v24;  vadd.vv v17, v17, v25
    vadd.vv v18, v18, v26;  vadd.vv v19, v19, v27
    add a4, a0, a7;   add a5, a0, t3;   vse16.v v16, (a4); vse16.v v17, (a5)
    add a4, a4, t5;   add a5, a5, t5;   vse16.v v18, (a4); vse16.v v19, (a5)
    # load zetas
    addi a4, a3, 0;   add  a5, a3, a7;  vle16.v v16, (a4); vle16.v v17, (a5)
    add  a4, a4, a6;  add  a5, a5, a6;  vle16.v v18, (a4); vle16.v v19, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v24, v25, v26, v27, v4, v5, v6, v7, \
        v16, v17, v18, v19, t0, t1, v28, v29, v30, v31
    montmul_x4 v0, v1, v2, v3, v12, v13, v14, v15, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    addi a4, a0, 0*2;  add a5, a0, a6;  vle16.v v28, (a4); vle16.v v29, (a5)
    add  a4, a4, t5;   add a5, a5, t5;  vle16.v v30, (a4); vle16.v v31, (a5)
    # a0b0 + b1 * (a1zeta mod q); then accumulate
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    vadd.vv v20, v20, v28; vadd.vv v21, v21, v29
    vadd.vv v22, v22, v30; vadd.vv v23, v23, v31
    addi a4, a0, 0;    add a5, a0, a6;  vse16.v v20, (a4); vse16.v v21, (a5)
    add  a4, a4, t5;   add a5, a5, t5;  vse16.v v22, (a4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a3, a3, t5;  add a0, a0, t5
    bltu a1, t2, poly_basemul_acc_rvv_vlen128_loop
ret
.globl poly_tomont_rvv_vlen128
.align 2
poly_tomont_rvv_vlen128:
    li a7, 16*8;    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    # mont^2 and qinv*mont^2
    li t1, 1353;    li t2, 20553
    slli t3, a7, 2; slli a7, a7, 1
    add  t4, a0, 256*2
poly_tomont_rvv_vlen128_loop:
    add a1, a0, a7
    vle16.v v0,  (a0);  vle16.v v8,  (a1)
    montmul_const v16, v0, t1, t2, t0, v24
    montmul_const v24, v8, t1, t2, t0, v0
    vse16.v v16, (a0);  vse16.v v24, (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_tomont_rvv_vlen128_loop
ret
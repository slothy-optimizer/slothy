.macro barrettRdc in, vt0, const_v, const_q
    vmulh.vx \vt0, \in, \const_v
    vssra.vi \vt0, \vt0, 10
    vmul.vx  \vt0, \vt0, \const_q
    vsub.vv  \in,  \in, \vt0
.endm

.globl poly_reduce_rvv_vlen128
.align 2
poly_reduce_rvv_vlen128:
    li a7, 16*8
    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    csrwi vxrm, 0   // round-to-nearest-up (add +0.5 LSB)
    li a6, 20159
    add  t4, a0, 256*2  
    slli t3, a7, 2
    slli a7, a7, 1
poly_reduce_rvv_vlen128_loop:
    add a1, a0, a7
    vle16.v v0,  (a0)
    vle16.v v8,  (a1)
    barrettRdc v0, v16, a6, t0
    barrettRdc v8, v24, a6, t0
    vse16.v v0,  (a0)
    vse16.v v8,  (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_reduce_rvv_vlen128_loop
ret
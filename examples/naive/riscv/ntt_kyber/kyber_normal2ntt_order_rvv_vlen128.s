/ shuffle4
// [a0~a3, a4~a7],[a8~a11, a12~a15] ->
// [a0~a3, a8~a11],[a4~a7,  a12~a15]
// shuffle2
// [a0~a1,a2~a3,a8~a9,a10~a11],[a4~a5,a6~a7,a12~a13,a14~a15] ->
// [a0~a1,a4~a5,a8~a9,a12~a13],[a2~a3,a6~a7,a10~a11,a14~a15]
// shuffle1
// [a0~a1,a4~a5,a8~a9,a12~a13],[a2~a3,a6~a7,a10~a11,a14~a15] ->
// [a0,a2,a4,a6,a8,a10,a12,a14],[a1,a3,a5,a7,a9,a11,a13,a15]
.macro shuffle_x2 in0_0, in0_1, in1_0, in1_1,  tm0_0, tm0_1, tm1_0, tm1_1, vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm1
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm1
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
.endm

.macro shuffle_o_x2 ou0_0, ou0_1, ou1_0, ou1_1,  in0_0, in0_1, in1_0, in1_1, vm0, vm1
    vrgather.vv \ou0_0, \in0_1, \vm0
    vrgather.vv \ou1_0, \in1_1, \vm0
    vrgather.vv \ou0_1, \in0_0, \vm1
    vrgather.vv \ou1_1, \in1_0, \vm1
    vmerge.vvm  \ou0_0, \ou0_0, \in0_0, v0
    vmerge.vvm  \ou1_0, \ou1_0, \in1_0, v0
    vmerge.vvm  \ou0_1, \in0_1, \ou0_1, v0
    vmerge.vvm  \ou1_1, \in1_1, \ou1_1, v0
.endm

.globl normal2ntt_order_rvv_vlen128
.align 2
normal2ntt_order_rvv_vlen128:
    li a2, 2
normal2ntt_order_rvv_vlen128_loop:
    addi a5, a0, 64*2
    vsetivli a7, 8, e16, m1, tu, mu
    vl8re16.v v16, (a0)
    vl8re16.v v24, (a5)
    // shuffle4
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
    // shuffle2
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
    // shuffle1
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
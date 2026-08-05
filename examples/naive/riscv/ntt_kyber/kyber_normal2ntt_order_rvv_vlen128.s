#ifndef KYBER_NTT_RVV_VLEN128_CONSTS_H
#define KYBER_NTT_RVV_VLEN128_CONSTS_H

#define _MASK_45674567 0
#define _MASK_01230123 8
#define _MASK_01014545 16
#define _MASK_23236767 24
#define _MASK_10325476 32
#define _REJ_UNIFORM_IDX8 40
#define _REJ_UNIFORM_MASK_01 48
#define _CBD2_MASK_E8_01 56
#define _CBD2_IDX8_LOW 64
#define _CBD2_IDX8_HIGH 72
#define _CBD3_MASK_E8_0122 80
#define _CBD3_IDX16_HIGH 88
#define _CBD3_MASK_E16_1100 96
#define _CBD3_IDX16_LOW 104
#define _ZETAS_EXP 112
#define _ZETAS_EXP_1TO6_P0_L1 114
#define _ZETAS_EXP_1TO6_P0_L2 116
#define _ZETAS_EXP_1TO6_P0_L3 120
#define _ZETAS_EXP_1TO6_P0_L4 136
#define _ZETAS_EXP_1TO6_P0_L5 152
#define _ZETAS_EXP_1TO6_P0_L6 184
#define _ZETAS_EXP_1TO6_P1_L1 216
#define _ZETAS_EXP_1TO6_P1_L2 218
#define _ZETAS_EXP_1TO6_P1_L3 224
#define _ZETAS_EXP_1TO6_P1_L4 240
#define _ZETAS_EXP_1TO6_P1_L5 256
#define _ZETAS_EXP_1TO6_P1_L6 288
#define _ZETAS_BASEMUL 320
#define _ZETA_EXP_INTT_0TO5_P0_L0 448
#define _ZETA_EXP_INTT_0TO5_P0_L1 480
#define _ZETA_EXP_INTT_0TO5_P0_L2 512
#define _ZETA_EXP_INTT_0TO5_P0_L3 528
#define _ZETA_EXP_INTT_0TO5_P0_L4 544
#define _ZETA_EXP_INTT_0TO5_P0_L5 560
#define _ZETA_EXP_INTT_0TO5_P1_L0 568
#define _ZETA_EXP_INTT_0TO5_P1_L1 600
#define _ZETA_EXP_INTT_0TO5_P1_L2 632
#define _ZETA_EXP_INTT_0TO5_P1_L3 648
#define _ZETA_EXP_INTT_0TO5_P1_L4 664
#define _ZETA_EXP_INTT_0TO5_P1_L5 680
#define _ZETA_EXP_INTT_L6 682

#endif

// shuffle4
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

.macro save_regs
  addi sp, sp, -8*15
  sd s0,  0*8(sp)
  sd s1,  1*8(sp)
  sd s2,  2*8(sp)
  sd s3,  3*8(sp)
  sd s4,  4*8(sp)
  sd s5,  5*8(sp)
  sd s6,  6*8(sp)
  sd s7,  7*8(sp)
  sd s8,  8*8(sp)
  sd s9,  9*8(sp)
  sd s10, 10*8(sp)
  sd s11, 11*8(sp)
  sd gp,  12*8(sp)
  sd tp,  13*8(sp)
  sd ra,  14*8(sp)
.endm

.macro restore_regs
  ld s0,  0*8(sp)
  ld s1,  1*8(sp)
  ld s2,  2*8(sp)
  ld s3,  3*8(sp)
  ld s4,  4*8(sp)
  ld s5,  5*8(sp)
  ld s6,  6*8(sp)
  ld s7,  7*8(sp)
  ld s8,  8*8(sp)
  ld s9,  9*8(sp)
  ld s10, 10*8(sp)
  ld s11, 11*8(sp)
  ld gp,  12*8(sp)
  ld tp,  13*8(sp)
  ld ra,  14*8(sp)
  addi sp, sp, 8*15
.endm

.globl normal2ntt_order_rvv_vlen128
.align 2
normal2ntt_order_rvv_vlen128:
    save_regs
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
    restore_regs
ret
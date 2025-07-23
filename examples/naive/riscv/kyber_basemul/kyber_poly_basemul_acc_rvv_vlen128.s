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
#define _ZETAS_BASEMUL 0
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
.macro shuffle_x2 in0_0, in0_1, in1_0, in1_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm1
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm1
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
.endm

.macro shuffle_o_x2 ou0_0, ou0_1, ou1_0, ou1_1, \
        in0_0, in0_1, in1_0, in1_1, vm0, vm1
    vrgather.vv \ou0_0, \in0_1, \vm0
    vrgather.vv \ou1_0, \in1_1, \vm0
    vrgather.vv \ou0_1, \in0_0, \vm1
    vrgather.vv \ou1_1, \in1_0, \vm1
    vmerge.vvm  \ou0_0, \ou0_0, \in0_0, v0
    vmerge.vvm  \ou1_0, \ou1_0, \in1_0, v0
    vmerge.vvm  \ou0_1, \in0_1, \ou0_1, v0
    vmerge.vvm  \ou1_1, \in1_1, \ou1_1, v0
.endm

.macro barrettRdc in, vt0, const_v, const_q
    vmulh.vx \vt0, \in, \const_v
    vssra.vi \vt0, \vt0, 10
    vmul.vx  \vt0, \vt0, \const_q
    vsub.vv  \in,  \in, \vt0
.endm

.macro barrettRdcX2 in0, in1, vt0, vt1, const_v, const_q
    vmulh.vx \vt0, \in0, \const_v
    vmulh.vx \vt1, \in1, \const_v
    vssra.vi \vt0, \vt0, 10
    vssra.vi \vt1, \vt1, 10
    vmul.vx  \vt0, \vt0, \const_q
    vmul.vx  \vt1, \vt1, \const_q
    vsub.vv  \in0, \in0, \vt0
    vsub.vv  \in1, \in1, \vt1
.endm

.macro ct_bfu_vx va0_0, va0_1, xzeta0, xzetaqinv0, xq, vt0_0, vt0_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0
    vmulh.vx \vt0_1, \va0_1, \xzeta0
    vmulh.vx \vt0_0, \vt0_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
.endm

.macro ct_bfu_vx_x2 va0_0, va0_1, va1_0, va1_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xq, vt0_0, vt0_1, vt1_0, vt1_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0
    vmul.vx  \vt1_0, \va1_1, \xzetaqinv1
    vmulh.vx \vt0_1, \va0_1, \xzeta0
    vmulh.vx \vt1_1, \va1_1, \xzeta1
    vmulh.vx \vt0_0, \vt0_0, \xq
    vmulh.vx \vt1_0, \vt1_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vsub.vv  \va1_1, \va1_0, \vt1_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
    vadd.vv  \va1_0, \va1_0, \vt1_0
.endm

.macro ct_bfu_vv_ref_x4 \
        vo0_0, vo0_1, vo1_0, vo1_1, vo2_0, vo2_1, vo3_0, vo3_1, \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzeta1, vzeta2, vzeta3, xq, xqinv
    vmul.vv  \vo0_0, \va0_1, \vzeta0
    vmul.vv  \vo1_0, \va1_1, \vzeta1
    vmul.vv  \vo2_0, \va2_1, \vzeta2
    vmul.vv  \vo3_0, \va3_1, \vzeta3
    vmul.vx  \vo0_0, \vo0_0, \xqinv
    vmul.vx  \vo1_0, \vo1_0, \xqinv
    vmul.vx  \vo2_0, \vo2_0, \xqinv
    vmul.vx  \vo3_0, \vo3_0, \xqinv
    vmulh.vv \va0_1, \va0_1, \vzeta0
    vmulh.vv \va1_1, \va1_1, \vzeta1
    vmulh.vv \va2_1, \va2_1, \vzeta2
    vmulh.vv \va3_1, \va3_1, \vzeta3
    vmulh.vx \vo0_0, \vo0_0, \xq
    vmulh.vx \vo1_0, \vo1_0, \xq
    vmulh.vx \vo2_0, \vo2_0, \xq
    vmulh.vx \vo3_0, \vo3_0, \xq
    vsub.vv  \vo0_0, \va0_1, \vo0_0
    vsub.vv  \vo1_0, \va1_1, \vo1_0
    vsub.vv  \vo2_0, \va2_1, \vo2_0
    vsub.vv  \vo3_0, \va3_1, \vo3_0
    vsub.vv  \vo0_1, \va0_0, \vo0_0
    vsub.vv  \vo1_1, \va1_0, \vo1_0
    vsub.vv  \vo2_1, \va2_0, \vo2_0
    vsub.vv  \vo3_1, \va3_0, \vo3_0
    vadd.vv  \vo0_0, \va0_0, \vo0_0
    vadd.vv  \vo1_0, \va1_0, \vo1_0
    vadd.vv  \vo2_0, \va2_0, \vo2_0
    vadd.vv  \vo3_0, \va3_0, \vo3_0
.endm

.macro ct_bfu_vv_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        vzeta4, vzetaqinv4, vzeta5, vzetaqinv5, vzeta6, vzetaqinv6, vzeta7, vzetaqinv7, xq, \
        vt0_0, vt1_0, vt2_0, vt3_0, vt4_0, vt5_0, vt6_0, vt7_0 
    vmul.vv  \vt0_0, \va0_1, \vzetaqinv0
    vmul.vv  \vt1_0, \va1_1, \vzetaqinv1
    vmul.vv  \vt2_0, \va2_1, \vzetaqinv2
    vmul.vv  \vt3_0, \va3_1, \vzetaqinv3
    vmul.vv  \vt4_0, \va4_1, \vzetaqinv4
    vmul.vv  \vt5_0, \va5_1, \vzetaqinv5
    vmul.vv  \vt6_0, \va6_1, \vzetaqinv6
    vmul.vv  \vt7_0, \va7_1, \vzetaqinv7
    vmulh.vv \va0_1, \va0_1, \vzeta0
    vmulh.vv \va1_1, \va1_1, \vzeta1
    vmulh.vv \va2_1, \va2_1, \vzeta2
    vmulh.vv \va3_1, \va3_1, \vzeta3
    vmulh.vv \va4_1, \va4_1, \vzeta4
    vmulh.vv \va5_1, \va5_1, \vzeta5
    vmulh.vv \va6_1, \va6_1, \vzeta6
    vmulh.vv \va7_1, \va7_1, \vzeta7
    vmulh.vx \vt0_0, \vt0_0, \xq
    vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq
    vmulh.vx \vt3_0, \vt3_0, \xq
    vmulh.vx \vt4_0, \vt4_0, \xq
    vmulh.vx \vt5_0, \vt5_0, \xq
    vmulh.vx \vt6_0, \vt6_0, \xq
    vmulh.vx \vt7_0, \vt7_0, \xq
    vsub.vv  \vt0_0, \va0_1, \vt0_0
    vsub.vv  \vt1_0, \va1_1, \vt1_0
    vsub.vv  \vt2_0, \va2_1, \vt2_0
    vsub.vv  \vt3_0, \va3_1, \vt3_0
    vsub.vv  \vt4_0, \va4_1, \vt4_0
    vsub.vv  \vt5_0, \va5_1, \vt5_0
    vsub.vv  \vt6_0, \va6_1, \vt6_0
    vsub.vv  \vt7_0, \va7_1, \vt7_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0
    vsub.vv  \va3_1, \va3_0, \vt3_0
    vsub.vv  \va4_1, \va4_0, \vt4_0
    vsub.vv  \va5_1, \va5_0, \vt5_0
    vsub.vv  \va6_1, \va6_0, \vt6_0
    vsub.vv  \va7_1, \va7_0, \vt7_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
    vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0
    vadd.vv  \va3_0, \va3_0, \vt3_0
    vadd.vv  \va4_0, \va4_0, \vt4_0
    vadd.vv  \va5_0, \va5_0, \vt5_0
    vadd.vv  \va6_0, \va6_0, \vt6_0
    vadd.vv  \va7_0, \va7_0, \vt7_0
.endm

.macro gs_bfu_vx va0_0, va0_1, xzeta0, xzetaqinv0, xq, vt0_0, vt0_1
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0
    vmulh.vx \vt0_1, \vt0_0, \xzeta0
    vmulh.vx \va0_1, \va0_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
.endm

.macro gs_bfu_vx_x8 \
        vo0_0, vo0_1, vo1_0, vo1_1, vo2_0, vo2_1, vo3_0, vo3_1, \
        vo4_0, vo4_1, vo5_0, vo5_1, vo6_0, vo6_1, vo7_0, vo7_1, \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xzeta4, xzetaqinv4, xzeta5, xzetaqinv5, \
        xzeta6, xzetaqinv6, xzeta7, xzetaqinv7, xq
    vsub.vv  \vo0_1, \va0_0, \va0_1
    vsub.vv  \vo1_1, \va1_0, \va1_1
    vsub.vv  \vo2_1, \va2_0, \va2_1
    vsub.vv  \vo3_1, \va3_0, \va3_1
    vsub.vv  \vo4_1, \va4_0, \va4_1
    vsub.vv  \vo5_1, \va5_0, \va5_1
    vsub.vv  \vo6_1, \va6_0, \va6_1
    vsub.vv  \vo7_1, \va7_0, \va7_1
    vadd.vv  \vo0_0, \va0_0, \va0_1
    vadd.vv  \vo1_0, \va1_0, \va1_1
    vadd.vv  \vo2_0, \va2_0, \va2_1
    vadd.vv  \vo3_0, \va3_0, \va3_1
    vadd.vv  \vo4_0, \va4_0, \va4_1
    vadd.vv  \vo5_0, \va5_0, \va5_1
    vadd.vv  \vo6_0, \va6_0, \va6_1
    vadd.vv  \vo7_0, \va7_0, \va7_1
    vmul.vx  \va0_1, \vo0_1, \xzetaqinv0
    vmul.vx  \va1_1, \vo1_1, \xzetaqinv1
    vmul.vx  \va2_1, \vo2_1, \xzetaqinv2
    vmul.vx  \va3_1, \vo3_1, \xzetaqinv3
    vmul.vx  \va4_1, \vo4_1, \xzetaqinv4
    vmul.vx  \va5_1, \vo5_1, \xzetaqinv5
    vmul.vx  \va6_1, \vo6_1, \xzetaqinv6
    vmul.vx  \va7_1, \vo7_1, \xzetaqinv7
    vmulh.vx \vo0_1, \vo0_1, \xzeta0
    vmulh.vx \vo1_1, \vo1_1, \xzeta1
    vmulh.vx \vo2_1, \vo2_1, \xzeta2
    vmulh.vx \vo3_1, \vo3_1, \xzeta3
    vmulh.vx \vo4_1, \vo4_1, \xzeta4
    vmulh.vx \vo5_1, \vo5_1, \xzeta5
    vmulh.vx \vo6_1, \vo6_1, \xzeta6
    vmulh.vx \vo7_1, \vo7_1, \xzeta7
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vmulh.vx \va4_1, \va4_1, \xq
    vmulh.vx \va5_1, \va5_1, \xq
    vmulh.vx \va6_1, \va6_1, \xq
    vmulh.vx \va7_1, \va7_1, \xq
    vsub.vv  \vo0_1, \vo0_1, \va0_1
    vsub.vv  \vo1_1, \vo1_1, \va1_1
    vsub.vv  \vo2_1, \vo2_1, \va2_1
    vsub.vv  \vo3_1, \vo3_1, \va3_1
    vsub.vv  \vo4_1, \vo4_1, \va4_1
    vsub.vv  \vo5_1, \vo5_1, \va5_1
    vsub.vv  \vo6_1, \vo6_1, \va6_1
    vsub.vv  \vo7_1, \vo7_1, \va7_1
.endm

.macro gs_bfu_vv_ref_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        vzeta0, vzeta1, vzeta2, vzeta3, \
        vzeta4, vzeta5, vzeta6, vzeta7, xq, xqinv, \
        vt0_0, vt1_0, vt2_0, vt3_0, vt4_0, vt5_0, vt6_0, vt7_0
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1
    vsub.vv  \vt3_0, \va3_0, \va3_1
    vsub.vv  \vt4_0, \va4_0, \va4_1
    vsub.vv  \vt5_0, \va5_0, \va5_1
    vsub.vv  \vt6_0, \va6_0, \va6_1
    vsub.vv  \vt7_0, \va7_0, \va7_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1
    vadd.vv  \va3_0, \va3_0, \va3_1
    vadd.vv  \va4_0, \va4_0, \va4_1
    vadd.vv  \va5_0, \va5_0, \va5_1
    vadd.vv  \va6_0, \va6_0, \va6_1
    vadd.vv  \va7_0, \va7_0, \va7_1
    vmul.vv  \va0_1, \vt0_0, \vzeta0
    vmul.vv  \va1_1, \vt1_0, \vzeta1
    vmul.vv  \va2_1, \vt2_0, \vzeta2
    vmul.vv  \va3_1, \vt3_0, \vzeta3
    vmul.vv  \va4_1, \vt4_0, \vzeta4
    vmul.vv  \va5_1, \vt5_0, \vzeta5
    vmul.vv  \va6_1, \vt6_0, \vzeta6
    vmul.vv  \va7_1, \vt7_0, \vzeta7
    vmul.vx  \va0_1, \va0_1, \xqinv
    vmul.vx  \va1_1, \va1_1, \xqinv
    vmul.vx  \va2_1, \va2_1, \xqinv
    vmul.vx  \va3_1, \va3_1, \xqinv
    vmul.vx  \va4_1, \va4_1, \xqinv
    vmul.vx  \va5_1, \va5_1, \xqinv
    vmul.vx  \va6_1, \va6_1, \xqinv
    vmul.vx  \va7_1, \va7_1, \xqinv
    vmulh.vv \vt0_0, \vt0_0, \vzeta0
    vmulh.vv \vt1_0, \vt1_0, \vzeta1
    vmulh.vv \vt2_0, \vt2_0, \vzeta2
    vmulh.vv \vt3_0, \vt3_0, \vzeta3
    vmulh.vv \vt4_0, \vt4_0, \vzeta4
    vmulh.vv \vt5_0, \vt5_0, \vzeta5
    vmulh.vv \vt6_0, \vt6_0, \vzeta6
    vmulh.vv \vt7_0, \vt7_0, \vzeta7
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vmulh.vx \va4_1, \va4_1, \xq
    vmulh.vx \va5_1, \va5_1, \xq
    vmulh.vx \va6_1, \va6_1, \xq
    vmulh.vx \va7_1, \va7_1, \xq
    vsub.vv  \va0_1, \vt0_0, \va0_1
    vsub.vv  \va1_1, \vt1_0, \va1_1
    vsub.vv  \va2_1, \vt2_0, \va2_1
    vsub.vv  \va3_1, \vt3_0, \va3_1
    vsub.vv  \va4_1, \vt4_0, \va4_1
    vsub.vv  \va5_1, \vt5_0, \va5_1
    vsub.vv  \va6_1, \vt6_0, \va6_1
    vsub.vv  \va7_1, \vt7_0, \va7_1
.endm

.macro gs_bfu_vv_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        vzeta4, vzetaqinv4, vzeta5, vzetaqinv5, vzeta6, vzetaqinv6, vzeta7, vzetaqinv7, xq, \
        vt0_0, vt1_0, vt2_0, vt3_0, vt4_0, vt5_0, vt6_0, vt7_0
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1
    vsub.vv  \vt3_0, \va3_0, \va3_1
    vsub.vv  \vt4_0, \va4_0, \va4_1
    vsub.vv  \vt5_0, \va5_0, \va5_1
    vsub.vv  \vt6_0, \va6_0, \va6_1
    vsub.vv  \vt7_0, \va7_0, \va7_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1
    vadd.vv  \va3_0, \va3_0, \va3_1
    vadd.vv  \va4_0, \va4_0, \va4_1
    vadd.vv  \va5_0, \va5_0, \va5_1
    vadd.vv  \va6_0, \va6_0, \va6_1
    vadd.vv  \va7_0, \va7_0, \va7_1
    vmul.vv  \va0_1, \vt0_0, \vzetaqinv0
    vmul.vv  \va1_1, \vt1_0, \vzetaqinv1
    vmul.vv  \va2_1, \vt2_0, \vzetaqinv2
    vmul.vv  \va3_1, \vt3_0, \vzetaqinv3
    vmul.vv  \va4_1, \vt4_0, \vzetaqinv4
    vmul.vv  \va5_1, \vt5_0, \vzetaqinv5
    vmul.vv  \va6_1, \vt6_0, \vzetaqinv6
    vmul.vv  \va7_1, \vt7_0, \vzetaqinv7
    vmulh.vv \vt0_0, \vt0_0, \vzeta0
    vmulh.vv \vt1_0, \vt1_0, \vzeta1
    vmulh.vv \vt2_0, \vt2_0, \vzeta2
    vmulh.vv \vt3_0, \vt3_0, \vzeta3
    vmulh.vv \vt4_0, \vt4_0, \vzeta4
    vmulh.vv \vt5_0, \vt5_0, \vzeta5
    vmulh.vv \vt6_0, \vt6_0, \vzeta6
    vmulh.vv \vt7_0, \vt7_0, \vzeta7
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vmulh.vx \va4_1, \va4_1, \xq
    vmulh.vx \va5_1, \va5_1, \xq
    vmulh.vx \va6_1, \va6_1, \xq
    vmulh.vx \va7_1, \va7_1, \xq
    vsub.vv  \va0_1, \vt0_0, \va0_1
    vsub.vv  \va1_1, \vt1_0, \va1_1
    vsub.vv  \va2_1, \vt2_0, \va2_1
    vsub.vv  \va3_1, \vt3_0, \va3_1
    vsub.vv  \va4_1, \vt4_0, \va4_1
    vsub.vv  \va5_1, \vt5_0, \va5_1
    vsub.vv  \va6_1, \vt6_0, \va6_1
    vsub.vv  \va7_1, \vt7_0, \va7_1
.endm

.macro montmul_const vr0, va0, xzeta, xzetaqinv, xq, vt0
    vmul.vx  \vr0, \va0, \xzetaqinv
    vmulh.vx \vt0, \va0, \xzeta
    vmulh.vx \vr0, \vr0, \xq
    vsub.vv  \vr0, \vt0, \vr0
.endm

.macro montmul_x4 vr0, vr1, vr2, vr3, \
        va0, va1, va2, va3, \
        vb0, vb1, vb2, vb3, \
        xq, xqinv, vt0, vt1, vt2, vt3
    vmul.vv  \vr0, \va0, \vb0
    vmul.vv  \vr1, \va1, \vb1
    vmul.vv  \vr2, \va2, \vb2
    vmul.vv  \vr3, \va3, \vb3
    vmul.vx  \vr0, \vr0, \xqinv
    vmul.vx  \vr1, \vr1, \xqinv
    vmul.vx  \vr2, \vr2, \xqinv
    vmul.vx  \vr3, \vr3, \xqinv
    vmulh.vv \vt0, \va0, \vb0
    vmulh.vv \vt1, \va1, \vb1
    vmulh.vv \vt2, \va2, \vb2
    vmulh.vv \vt3, \va3, \vb3
    vmulh.vx \vr0, \vr0, \xq
    vmulh.vx \vr1, \vr1, \xq
    vmulh.vx \vr2, \vr2, \xq
    vmulh.vx \vr3, \vr3, \xq
    vsub.vv  \vr0, \vt0, \vr0
    vsub.vv  \vr1, \vt1, \vr1
    vsub.vv  \vr2, \vt2, \vr2
    vsub.vv  \vr3, \vt3, \vr3
.endm

.macro ntt_rvv_level0
    li a7, 8*8
    addi a6, a1, _ZETAS_EXP*2
    vsetvli a7, a7, e16, m8, tu, mu
    lh t3, 0*2(a6)
    lh t2, 1*2(a6)
// a[0-63] & a[128-191]
    addi a5, a0, 128*2
    vle16.v v16, (a0)
    vle16.v v24, (a5)
    ct_bfu_vx v16, v24, t2, t3, t0, v0, v8
    vse16.v v16, (a0)
    vse16.v v24, (a5)
    addi a4, a0, 64*2
    addi a5, a5, 64*2
    vle16.v v16, (a4)
    vle16.v v24, (a5)
    ct_bfu_vx v16, v24, t2, t3, t0, v0, v8
    vse16.v v16, (a4)
    vse16.v v24, (a5)
.endm

.macro ntt_rvv_level1to6 off, ZETAS_EXP_1TO6_L1, ZETAS_EXP_1TO6_L3
    li a7, 8*8
    addi a6, a1, \ZETAS_EXP_1TO6_L1*2
    vsetvli a7, a7, e16, m8, tu, mu
    addi a4, a0, (\off*128)*2
    addi a5, a0, (64+\off*128)*2
    lh t3, 0*2(a6)
    lh t2, 1*2(a6)
// a[0-63] & a[64-127] or a[128-191] & a[192-255]
    vle16.v v16, (a4)
    vle16.v v24, (a5)
// level 1
    ct_bfu_vx v16, v24, t2, t3, t0, v0, v8
// level 2
    li a7, 8*4
    lh t3, 2*2(a6)
    lh t2, 3*2(a6)
    vsetvli a7, a7, e16, m4, tu, mu
    lh t5, 4*2(a6)
    lh t4, 5*2(a6)
    ct_bfu_vx_x2 v16, v20, v24, v28, t2, t3, t4, t5, t0, v0, v4, v8, v12
    vsetivli a7, 8, e16, m1, tu, mu
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
    addi a6, a1, \ZETAS_EXP_1TO6_L3*2
    shuffle_x2 v18, v22, v26, v30, v8, v9, v10, v11, v1, v2
    vl2re16.v v4, (a6)
    addi a6, a6, 8*2*2
    shuffle_x2 v19, v23, v27, v31, v8, v9, v10, v11, v1, v2
// level 3
    ct_bfu_vv_x8 \
        v16, v18, v20, v22, v24, v26, v28, v30, \
        v17, v19, v21, v23, v25, v27, v29, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  t0, \
        v8,  v9, v10, v11, v12, v13, v14, v15
// shuffle1
    addi t2, a1, _MASK_10325476*2
    li t6, 0x55
    vle16.v v1, (t2)
    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v24, v26, v8, v9, v10, v11, v1, v1
    shuffle_x2 v17, v19, v25, v27, v8, v9, v10, v11, v1, v1
    vl2re16.v v4, (a6)
    addi a6, a6, 8*2*2
    shuffle_x2 v20, v22, v28, v30, v8, v9, v10, v11, v1, v1
    shuffle_x2 v21, v23, v29, v31, v8, v9, v10, v11, v1, v1
// level 4
    ct_bfu_vv_x8 \
        v16, v17, v18, v19, v20, v21, v22, v23, \
        v24, v25, v26, v27, v28, v29, v30, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  t0, \
        v8,  v9, v10, v11, v12, v13, v14, v15
    vl4re16.v v0, (a6)
    addi a6, a6, 8*4*2
// level 5
    ct_bfu_vv_x8 \
        v16, v24, v18, v26, v20, v28, v22, v30, \
        v17, v25, v19, v27, v21, v29, v23, v31, \
        v1,  v0,  v1,  v0,  v1,  v0,  v1,  v0,  \
        v3,  v2,  v3,  v2,  v3,  v2,  v3,  v2,  t0, \
        v8,  v9, v10, v11, v12, v13, v14, v15
// level 6
    vl4re16.v v4, (a6)
    addi a4, a0, (\off*128)*2
    addi a5, a0, (64+\off*128)*2
// polynomial coefficients will be redirected to v8-v15
    ct_bfu_vv_ref_x4 \
        v8,  v10, v9,  v11, v12, v14, v13, v15, \
        v16, v20, v18, v22, v24, v28, v26, v30, \
        v4,  v4,  v5,  v5,  t0, t1
    vs8r.v v8, (a4)
    ct_bfu_vv_ref_x4 \
        v8,  v10, v9,  v11, v12, v14, v13, v15, \
        v17, v21, v19, v23, v25, v29, v27, v31, \
        v6,  v6,  v7,  v7, t0, t1
    vs8r.v v8, (a5)
.endm

.macro rej_core vr0, vf0, vt0, vidx, x0xfff, xq
    vsetivli a7, 16, e8, m1, tu, mu
    vle8.v  \vf0, (a1)
    addi a1, a1, 12
    vrgather.vv \vt0, \vf0, \vidx
    vsetivli a7, 8, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq
    vcpop.m   t2, \vf0
    vcompress.vm \vr0, \vt0, \vf0
    vse16.v \vr0, (a0)
    add t2, t2, t2
    add a0, a0, t2
.endm

.macro rej_core_x2 vr0, vr1, vf0, vf1, vt0, vt1, vidx, x0xfff, xq
    addi t2, a1, 12
    vsetivli a7, 16, e8, m1, tu, mu
    vle8.v \vf0, (a1)
    vle8.v \vf1, (t2)
    addi a1, a1, 12*2
    vrgather.vv \vt0, \vf0, \vidx
    vrgather.vv \vt1, \vf1, \vidx
    vsetivli a7, 8, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t
    vsrl.vi   \vt1, \vt1, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff
    vand.vx   \vt1, \vt1, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq
    vmsltu.vx \vf1, \vt1, \xq
    vcpop.m   t2, \vf0
    vcpop.m   t3, \vf1
    vcompress.vm \vr0, \vt0, \vf0
    vcompress.vm \vr1, \vt1, \vf1
    vse16.v \vr0, (a0)
    add t2, t2, t2
    add t3, t3, t3
    add a0, a0, t2
    vse16.v \vr1, (a0)
    add a0, a0, t3
.endm

.macro rej_core_x4 vr0, vr1, vr2, vr3, vf0, vf1, vf2, vf3, \
        vt0, vt1, vt2, vt3, vidx, x0xfff, xq
    addi t2, a1, 12
    addi t3, a1, 24
    addi t4, a1, 36
    vsetivli a7, 16, e8, m1, tu, mu
    vle8.v \vf0, (a1)
    vle8.v \vf1, (t2)
    vle8.v \vf2, (t3)
    vle8.v \vf3, (t4)
    addi a1, a1, 12*4
    vrgather.vv \vt0, \vf0, \vidx
    vrgather.vv \vt1, \vf1, \vidx
    vrgather.vv \vt2, \vf2, \vidx
    vrgather.vv \vt3, \vf3, \vidx
    vsetivli a7, 8, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t
    vsrl.vi   \vt1, \vt1, 4, v0.t
    vsrl.vi   \vt2, \vt2, 4, v0.t
    vsrl.vi   \vt3, \vt3, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff
    vand.vx   \vt1, \vt1, \x0xfff
    vand.vx   \vt2, \vt2, \x0xfff
    vand.vx   \vt3, \vt3, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq
    vmsltu.vx \vf1, \vt1, \xq
    vmsltu.vx \vf2, \vt2, \xq
    vmsltu.vx \vf3, \vt3, \xq
    vcpop.m   t2, \vf0
    vcpop.m   t3, \vf1
    vcpop.m   t4, \vf2
    vcpop.m   t5, \vf3
    vcompress.vm \vr0, \vt0, \vf0
    vcompress.vm \vr1, \vt1, \vf1
    vcompress.vm \vr2, \vt2, \vf2
    vcompress.vm \vr3, \vt3, \vf3
    vse16.v \vr0, (a0)
    add t2, t2, t2
    add t3, t3, t3
    add a0, a0, t2
    add t4, t4, t4
    vse16.v \vr1, (a0)
    add a0, a0, t3
    vse16.v \vr2, (a0)
    add a0, a0, t4
    add t5, t5, t5
    vse16.v \vr3, (a0)
    add a0, a0, t5
.endm

.macro cbd2_core_x4 vf0_0, vf0_1, vf1_0, vf1_1, vf2_0, vf2_1, vf3_0, vf3_1, \
        vt0_0, vt0_1, vt0_2, vt0_3, vt1_0, vt1_1, vt1_2, vt1_3, \
        vt2_0, vt2_1, vt2_2, vt2_3, vt3_0, vt3_1, vt3_2, vt3_3, \
        vidx_low, vidx_high, x0x55, x0x33
    vsetivli a7, 16, e8, m1, tu, mu
    addi t2, a1, 16
    addi t3, a1, 16*2
    addi t4, a1, 16*3
    vle8.v \vf0_0, (a1)
    vle8.v \vf1_0, (t2)
    vle8.v \vf2_0, (t3)
    vle8.v \vf3_0, (t4)
    addi a1, a1, 16*4
    vsrl.vi \vf0_1, \vf0_0, 1
    vsrl.vi \vf1_1, \vf1_0, 1
    vsrl.vi \vf2_1, \vf2_0, 1
    vsrl.vi \vf3_1, \vf3_0, 1
    vand.vx \vf0_0, \vf0_0, \x0x55
    vand.vx \vf0_1, \vf0_1, \x0x55
    vand.vx \vf1_0, \vf1_0, \x0x55
    vand.vx \vf1_1, \vf1_1, \x0x55
    vand.vx \vf2_0, \vf2_0, \x0x55
    vand.vx \vf2_1, \vf2_1, \x0x55
    vand.vx \vf3_0, \vf3_0, \x0x55
    vand.vx \vf3_1, \vf3_1, \x0x55
    vadd.vv \vf0_0, \vf0_0, \vf0_1
    vadd.vv \vf1_0, \vf1_0, \vf1_1
    vadd.vv \vf2_0, \vf2_0, \vf2_1
    vadd.vv \vf3_0, \vf3_0, \vf3_1
    vsrl.vi \vf0_1, \vf0_0, 2
    vsrl.vi \vf1_1, \vf1_0, 2
    vsrl.vi \vf2_1, \vf2_0, 2
    vsrl.vi \vf3_1, \vf3_0, 2
    vand.vx \vf0_0, \vf0_0, \x0x33
    vand.vx \vf1_0, \vf1_0, \x0x33
    vand.vx \vf2_0, \vf2_0, \x0x33
    vand.vx \vf3_0, \vf3_0, \x0x33
    vand.vx \vf0_1, \vf0_1, \x0x33
    vand.vx \vf1_1, \vf1_1, \x0x33
    vand.vx \vf2_1, \vf2_1, \x0x33
    vand.vx \vf3_1, \vf3_1, \x0x33
    vadd.vx \vf0_0, \vf0_0, \x0x33
    vadd.vx \vf1_0, \vf1_0, \x0x33
    vadd.vx \vf2_0, \vf2_0, \x0x33
    vadd.vx \vf3_0, \vf3_0, \x0x33
    vsub.vv \vf0_0, \vf0_0, \vf0_1
    vsub.vv \vf1_0, \vf1_0, \vf1_1
    vsub.vv \vf2_0, \vf2_0, \vf2_1
    vsub.vv \vf3_0, \vf3_0, \vf3_1
    vsrl.vi \vf0_1, \vf0_0, 4
    vsrl.vi \vf1_1, \vf1_0, 4
    vsrl.vi \vf2_1, \vf2_0, 4
    vsrl.vi \vf3_1, \vf3_0, 4
    vand.vi \vf0_0, \vf0_0, 0xf
    vand.vi \vf1_0, \vf1_0, 0xf
    vand.vi \vf2_0, \vf2_0, 0xf
    vand.vi \vf3_0, \vf3_0, 0xf
    vadd.vi \vf0_1, \vf0_1, -3
    vadd.vi \vf1_1, \vf1_1, -3
    vadd.vi \vf2_1, \vf2_1, -3
    vadd.vi \vf3_1, \vf3_1, -3
    vadd.vi \vf0_0, \vf0_0, -3
    vadd.vi \vf1_0, \vf1_0, -3 
    vadd.vi \vf2_0, \vf2_0, -3
    vadd.vi \vf3_0, \vf3_0, -3 
    vrgather.vv \vt0_0, \vf0_0, \vidx_low
    vrgather.vv \vt0_1, \vf0_1, \vidx_low
    vrgather.vv \vt0_2, \vf0_0, \vidx_high
    vrgather.vv \vt0_3, \vf0_1, \vidx_high
    vrgather.vv \vt1_0, \vf1_0, \vidx_low
    vrgather.vv \vt1_1, \vf1_1, \vidx_low
    vrgather.vv \vt1_2, \vf1_0, \vidx_high
    vrgather.vv \vt1_3, \vf1_1, \vidx_high
    vrgather.vv \vt2_0, \vf2_0, \vidx_low
    vrgather.vv \vt2_1, \vf2_1, \vidx_low
    vrgather.vv \vt2_2, \vf2_0, \vidx_high
    vrgather.vv \vt2_3, \vf2_1, \vidx_high
    vrgather.vv \vt3_0, \vf3_0, \vidx_low
    vrgather.vv \vt3_1, \vf3_1, \vidx_low
    vrgather.vv \vt3_2, \vf3_0, \vidx_high
    vrgather.vv \vt3_3, \vf3_1, \vidx_high
    vmerge.vvm  \vf0_0, \vt0_0, \vt0_1, v0
    vmerge.vvm  \vf0_1, \vt0_2, \vt0_3, v0
    vmerge.vvm  \vf1_0, \vt1_0, \vt1_1, v0
    vmerge.vvm  \vf1_1, \vt1_2, \vt1_3, v0
    vmerge.vvm  \vf2_0, \vt2_0, \vt2_1, v0
    vmerge.vvm  \vf2_1, \vt2_2, \vt2_3, v0
    vmerge.vvm  \vf3_0, \vt3_0, \vt3_1, v0
    vmerge.vvm  \vf3_1, \vt3_2, \vt3_3, v0
    vsetivli a7, 16, e16, m2, tu, mu
    vsext.vf2 \vt0_0, \vf0_0
    vsext.vf2 \vt0_2, \vf0_1
    vsext.vf2 \vt1_0, \vf1_0
    vsext.vf2 \vt1_2, \vf1_1
    vsext.vf2 \vt2_0, \vf2_0
    vsext.vf2 \vt2_2, \vf2_1
    vsext.vf2 \vt3_0, \vf3_0
    vsext.vf2 \vt3_2, \vf3_1
    addi t2, a0, 16*2
    addi t3, a0, 16*4
    addi t4, a0, 16*6
    vse16.v \vt0_0, (a0)
    vse16.v \vt0_2, (t2)
    vse16.v \vt1_0, (t3)
    vse16.v \vt1_2, (t4)
    addi t2, a0, 16*8
    addi t3, a0, 16*10
    addi t4, a0, 16*12
    addi t5, a0, 16*14
    vse16.v \vt2_0, (t2)
    vse16.v \vt2_2, (t3)
    vse16.v \vt3_0, (t4)
    vse16.v \vt3_2, (t5)
    addi a0, a0, 16*16
.endm

.macro cbd3_core_x4 \
        vf0_0, vf0_1, vf0_2, vf0_3, vt0_0, vt0_1, \
        vf1_0, vf1_1, vf1_2, vf1_3, vt1_0, vt1_1, \
        vf2_0, vf2_1, vf2_2, vf2_3, vt2_0, vt2_1, \
        vf3_0, vf3_1, vf3_2, vf3_3, vt3_0, vt3_1, \
        vidx8_0122, vidx_low, vidx_high, \
        x0x249, x0x6DB, x0x70000
    vsetivli a7, 16, e8, m1, tu, mu
    addi t2, a1, 12
    addi t3, a1, 12*2
    addi t4, a1, 12*3
    vle8.v \vf0_1, (a1)
    vle8.v \vf1_1, (t2)
    vle8.v \vf2_1, (t3)
    vle8.v \vf3_1, (t4)
    addi a1, a1, 12*4
    vrgather.vv \vf0_0, \vf0_1, \vidx8_0122
    vrgather.vv \vf1_0, \vf1_1, \vidx8_0122
    vrgather.vv \vf2_0, \vf2_1, \vidx8_0122
    vrgather.vv \vf3_0, \vf3_1, \vidx8_0122
    vsetivli a7, 4, e32, m1, tu, mu
    vsrl.vi \vf0_1, \vf0_0, 1
    vsrl.vi \vf0_2, \vf0_0, 2
    vsrl.vi \vf1_1, \vf1_0, 1
    vsrl.vi \vf1_2, \vf1_0, 2
    vsrl.vi \vf2_1, \vf2_0, 1
    vsrl.vi \vf2_2, \vf2_0, 2
    vsrl.vi \vf3_1, \vf3_0, 1
    vsrl.vi \vf3_2, \vf3_0, 2
    vand.vx \vf0_0, \vf0_0, \x0x249
    vand.vx \vf0_1, \vf0_1, \x0x249
    vand.vx \vf0_2, \vf0_2, \x0x249
    vand.vx \vf1_0, \vf1_0, \x0x249
    vand.vx \vf1_1, \vf1_1, \x0x249
    vand.vx \vf1_2, \vf1_2, \x0x249
    vand.vx \vf2_0, \vf2_0, \x0x249
    vand.vx \vf2_1, \vf2_1, \x0x249
    vand.vx \vf2_2, \vf2_2, \x0x249
    vand.vx \vf3_0, \vf3_0, \x0x249
    vand.vx \vf3_1, \vf3_1, \x0x249
    vand.vx \vf3_2, \vf3_2, \x0x249
    vadd.vv \vf0_0, \vf0_0, \vf0_1
    vadd.vv \vf1_0, \vf1_0, \vf1_1
    vadd.vv \vf2_0, \vf2_0, \vf2_1
    vadd.vv \vf3_0, \vf3_0, \vf3_1
    vadd.vv \vf0_0, \vf0_0, \vf0_2
    vadd.vv \vf1_0, \vf1_0, \vf1_2
    vadd.vv \vf2_0, \vf2_0, \vf2_2
    vadd.vv \vf3_0, \vf3_0, \vf3_2
    vsrl.vi \vf0_1, \vf0_0, 3
    vsrl.vi \vf1_1, \vf1_0, 3
    vsrl.vi \vf2_1, \vf2_0, 3
    vsrl.vi \vf3_1, \vf3_0, 3
    vadd.vx \vf0_0, \vf0_0, \x0x6DB
    vadd.vx \vf1_0, \vf1_0, \x0x6DB
    vadd.vx \vf2_0, \vf2_0, \x0x6DB
    vadd.vx \vf3_0, \vf3_0, \x0x6DB
    vsub.vv \vf0_0, \vf0_0, \vf0_1
    vsub.vv \vf1_0, \vf1_0, \vf1_1
    vsub.vv \vf2_0, \vf2_0, \vf2_1
    vsub.vv \vf3_0, \vf3_0, \vf3_1
    vsll.vi \vf0_1, \vf0_0, 10
    vsrl.vi \vf0_2, \vf0_0, 12
    vsrl.vi \vf0_3, \vf0_0, 2
    vsll.vi \vf1_1, \vf1_0, 10
    vsrl.vi \vf1_2, \vf1_0, 12
    vsrl.vi \vf1_3, \vf1_0, 2
    vsll.vi \vf2_1, \vf2_0, 10
    vsrl.vi \vf2_2, \vf2_0, 12
    vsrl.vi \vf2_3, \vf2_0, 2
    vsll.vi \vf3_1, \vf3_0, 10
    vsrl.vi \vf3_2, \vf3_0, 12
    vsrl.vi \vf3_3, \vf3_0, 2
    vand.vi \vf0_0, \vf0_0, 7
    vand.vx \vf0_1, \vf0_1, \x0x70000
    vand.vi \vf0_2, \vf0_2, 7
    vand.vx \vf0_3, \vf0_3, \x0x70000
    vand.vi \vf1_0, \vf1_0, 7
    vand.vx \vf1_1, \vf1_1, \x0x70000
    vand.vi \vf1_2, \vf1_2, 7
    vand.vx \vf1_3, \vf1_3, \x0x70000
    vand.vi \vf2_0, \vf2_0, 7
    vand.vx \vf2_1, \vf2_1, \x0x70000
    vand.vi \vf2_2, \vf2_2, 7
    vand.vx \vf2_3, \vf2_3, \x0x70000
    vand.vi \vf3_0, \vf3_0, 7
    vand.vx \vf3_1, \vf3_1, \x0x70000
    vand.vi \vf3_2, \vf3_2, 7
    vand.vx \vf3_3, \vf3_3, \x0x70000
    vadd.vv \vf0_0, \vf0_0, \vf0_1
    vadd.vv \vf0_1, \vf0_2, \vf0_3
    vadd.vv \vf1_0, \vf1_0, \vf1_1
    vadd.vv \vf1_1, \vf1_2, \vf1_3
    vadd.vv \vf2_0, \vf2_0, \vf2_1
    vadd.vv \vf2_1, \vf2_2, \vf2_3
    vadd.vv \vf3_0, \vf3_0, \vf3_1
    vadd.vv \vf3_1, \vf3_2, \vf3_3
    vsetivli a7, 8, e16, m1, tu, mu
    vadd.vi \vf0_0, \vf0_0, -3
    vadd.vi \vf0_1, \vf0_1, -3
    vadd.vi \vf1_0, \vf1_0, -3
    vadd.vi \vf1_1, \vf1_1, -3
    vadd.vi \vf2_0, \vf2_0, -3
    vadd.vi \vf2_1, \vf2_1, -3
    vadd.vi \vf3_0, \vf3_0, -3
    vadd.vi \vf3_1, \vf3_1, -3
    vrgather.vv \vf0_2, \vf0_0, \vidx_low
    vrgather.vv \vf0_3, \vf0_1, \vidx_low
    vrgather.vv \vt0_0, \vf0_0, \vidx_high
    vrgather.vv \vt0_1, \vf0_1, \vidx_high
    vrgather.vv \vf1_2, \vf1_0, \vidx_low
    vrgather.vv \vf1_3, \vf1_1, \vidx_low
    vrgather.vv \vt1_0, \vf1_0, \vidx_high
    vrgather.vv \vt1_1, \vf1_1, \vidx_high
    vrgather.vv \vf2_2, \vf2_0, \vidx_low
    vrgather.vv \vf2_3, \vf2_1, \vidx_low
    vrgather.vv \vt2_0, \vf2_0, \vidx_high
    vrgather.vv \vt2_1, \vf2_1, \vidx_high
    vrgather.vv \vf3_2, \vf3_0, \vidx_low
    vrgather.vv \vf3_3, \vf3_1, \vidx_low
    vrgather.vv \vt3_0, \vf3_0, \vidx_high
    vrgather.vv \vt3_1, \vf3_1, \vidx_high
    vmerge.vvm  \vf0_0, \vf0_3, \vf0_2, v0
    vmerge.vvm  \vf0_1, \vt0_1, \vt0_0, v0
    vmerge.vvm  \vf1_0, \vf1_3, \vf1_2, v0
    vmerge.vvm  \vf1_1, \vt1_1, \vt1_0, v0
    vmerge.vvm  \vf2_0, \vf2_3, \vf2_2, v0
    vmerge.vvm  \vf2_1, \vt2_1, \vt2_0, v0
    vmerge.vvm  \vf3_0, \vf3_3, \vf3_2, v0
    vmerge.vvm  \vf3_1, \vt3_1, \vt3_0, v0
    addi t2, a0, 8*2
    addi t3, a0, 8*4
    addi t4, a0, 8*6
    vse16.v \vf0_0, (a0)
    vse16.v \vf0_1, (t2)
    vse16.v \vf1_0, (t3)
    vse16.v \vf1_1, (t4)
    addi t2, a0, 8*8
    addi t3, a0, 8*10
    addi t4, a0, 8*12
    addi t5, a0, 8*14
    vse16.v \vf2_0, (t2)
    vse16.v \vf2_1, (t3)
    vse16.v \vf3_0, (t4)
    vse16.v \vf3_1, (t5)
    addi a0, a0, 8*16
.endm

// void poly_basemul_acc_rvv_vlen128(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table)

.macro save_regs
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
.endm

.globl poly_basemul_acc_rvv_vlen128
.align 2
poly_basemul_acc_rvv_vlen128:
    addi sp, sp, -8*15
    save_regs
    li a7, 32
    li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu
    li t0, 3329
    li t1, -3327
    slli t5, a7, 3
    slli a6, a7, 2
    slli a7, a7, 1
    add  a3, a3, t3
    add  t3, a6, a7
    addi t2, a1, 256*2
poly_basemul_acc_rvv_vlen128_loop:
    vle16.v v0, (a1)
    vle16.v v8,  (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v4, (a1)
    vle16.v v12, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v1, (a1)
    vle16.v v9,  (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v5, (a1)
    vle16.v v13, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v2, (a1)
    vle16.v v10, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v6, (a1)
    vle16.v v14, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v3, (a1)
    vle16.v v11, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    vle16.v v7, (a1)
    vle16.v v15, (a2)
    addi a1, a1, 32
    add a2, a2, a7
    montmul_x4 v16, v17, v18, v19, v0, v1, v2, v3, \
        v12, v13, v14, v15, t0, t1, v24, v25, v26, v27
    montmul_x4 v20, v21, v22, v23, v4, v5, v6, v7, \
        v8,  v9,  v10, v11, t0, t1, v24, v25, v26, v27
    add a4, a0, a7
    add a5, a0, t3
    vle16.v v24, (a4)
    vle16.v v25, (a5)
    add a4, a4, t5
    add a5, a5, t5
    vle16.v v26, (a4)
    vle16.v v27, (a5)
    // a0b1 + a1b0
    // then accumulate
    vadd.vv v16, v16, v20
    vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22
    vadd.vv v19, v19, v23
    vadd.vv v16, v16, v24
    vadd.vv v17, v17, v25
    vadd.vv v18, v18, v26
    vadd.vv v19, v19, v27
    add a4, a0, a7
    add a5, a0, t3
    vse16.v v16, (a4)
    vse16.v v17, (a5)
    add a4, a4, t5
    add a5, a5, t5
    vse16.v v18, (a4)
    vse16.v v19, (a5)
    // load zetas
    addi a4, a3, 0
    add  a5, a3, a7
    vle16.v v16, (a4)
    vle16.v v17, (a5)
    add  a4, a4, a6
    add  a5, a5, a6
    vle16.v v18, (a4)
    vle16.v v19, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v24, v25, v26, v27, v4, v5, v6, v7, \
        v16, v17, v18, v19, t0, t1, v28, v29, v30, v31
    montmul_x4 v0, v1, v2, v3, v12, v13, v14, v15, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    addi a4, a0, 0*2
    add a5, a0, a6
    vle16.v v28, (a4)
    vle16.v v29, (a5)
    add  a4, a4, t5
    add a5, a5, t5
    vle16.v v30, (a4)
    vle16.v v31, (a5)
    // a0b0 + b1 * (a1zeta mod q)
    // then accumulate
    vadd.vv v20, v20, v0
    vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2
    vadd.vv v23, v23, v3
    vadd.vv v20, v20, v28
    vadd.vv v21, v21, v29
    vadd.vv v22, v22, v30
    vadd.vv v23, v23, v31
    addi a4, a0, 0
    add a5, a0, a6
    vse16.v v20, (a4)
    vse16.v v21, (a5)
    add  a4, a4, t5
    add a5, a5, t5
    vse16.v v22, (a4)
    vse16.v v23, (a5)
    add  a0, a0, t5
    add a3, a3, t5
    add a0, a0, t5
    bltu a1, t2, poly_basemul_acc_rvv_vlen128_loop
    restore_regs
    addi sp, sp, 8*15
ret
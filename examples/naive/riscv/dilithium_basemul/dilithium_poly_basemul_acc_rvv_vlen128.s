// [a0,a1,a2,a3]+[a4,a5,a6,a7] -> [a0,a1,a4,a5]+[a2,a3,a6,a7]
// related masks are ready for using
// v0: _MASK_1100, vm0/vm1: _MASK_0101/_MASK_2323
.macro shuffle2_x4 \
        in0_0, in0_1, in1_0, in1_1, in2_0, in2_1, in3_0, in3_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, tm2_0, tm2_1, tm3_0, tm3_1, vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm1
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm1
    vrgather.vv \tm2_0, \in2_1, \vm0
    vrgather.vv \tm2_1, \in2_0, \vm1
    vrgather.vv \tm3_0, \in3_1, \vm0
    vrgather.vv \tm3_1, \in3_0, \vm1
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
    vmerge.vvm  \in2_0, \tm2_0, \in2_0, v0
    vmerge.vvm  \in2_1, \in2_1, \tm2_1, v0
    vmerge.vvm  \in3_0, \tm3_0, \in3_0, v0
    vmerge.vvm  \in3_1, \in3_1, \tm3_1, v0
.endm

// [a0,a1,a4,a5]+[a2,a3,a6,a7] -> [a0,a2,a4,a6]+[a1,a3,a5,a7]
// related masks are ready for using
// v0: _MASK_1010, vm0: _MASK_1032
.macro shuffle1_x4 \
        in0_0, in0_1, in1_0, in1_1, in2_0, in2_1, in3_0, in3_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, tm2_0, tm2_1, tm3_0, tm3_1, vm0
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm0
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm0
    vrgather.vv \tm2_0, \in2_1, \vm0
    vrgather.vv \tm2_1, \in2_0, \vm0
    vrgather.vv \tm3_0, \in3_1, \vm0
    vrgather.vv \tm3_1, \in3_0, \vm0
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
    vmerge.vvm  \in2_0, \tm2_0, \in2_0, v0
    vmerge.vvm  \in2_1, \in2_1, \tm2_1, v0
    vmerge.vvm  \in3_0, \tm3_0, \in3_0, v0
    vmerge.vvm  \in3_1, \in3_1, \tm3_1, v0
.endm

.macro tomont_x8 \
        va0, va1, va2, va3, va4, va5, va6, va7, \
        xb, xbqinv, xq, \
        vt0, vt1, vt2, vt3, vt4, vt5, vt6, vt7
    vmul.vx  \vt0, \va0, \xbqinv
    vmul.vx  \vt1, \va1, \xbqinv
    vmul.vx  \vt2, \va2, \xbqinv
    vmul.vx  \vt3, \va3, \xbqinv
    vmul.vx  \vt4, \va4, \xbqinv
    vmul.vx  \vt5, \va5, \xbqinv
    vmul.vx  \vt6, \va6, \xbqinv
    vmul.vx  \vt7, \va7, \xbqinv
    vmulh.vx \va0, \va0, \xb
    vmulh.vx \va1, \va1, \xb
    vmulh.vx \va2, \va2, \xb
    vmulh.vx \va3, \va3, \xb
    vmulh.vx \va4, \va4, \xb
    vmulh.vx \va5, \va5, \xb
    vmulh.vx \va6, \va6, \xb
    vmulh.vx \va7, \va7, \xb
    vmulh.vx \vt0, \vt0, \xq
    vmulh.vx \vt1, \vt1, \xq
    vmulh.vx \vt2, \vt2, \xq
    vmulh.vx \vt3, \vt3, \xq
    vmulh.vx \vt4, \vt4, \xq
    vmulh.vx \vt5, \vt5, \xq
    vmulh.vx \vt6, \vt6, \xq
    vmulh.vx \vt7, \vt7, \xq
    vsub.vv  \va0, \va0, \vt0
    vsub.vv  \va1, \va1, \vt1
    vsub.vv  \va2, \va2, \vt2
    vsub.vv  \va3, \va3, \vt3
    vsub.vv  \va4, \va4, \vt4
    vsub.vv  \va5, \va5, \vt5
    vsub.vv  \va6, \va6, \vt6
    vsub.vv  \va7, \va7, \vt7
.endm

.macro montmul_ref vr0, va0, vb0, xq, xqinv, vt0
    vmul.vv  \vr0, \va0, \vb0
    vmul.vx  \vr0, \vr0, \xqinv
    vmulh.vx \vr0, \vr0, \xq
    vmulh.vv \vt0, \va0, \vb0
    vsub.vv  \vr0, \vt0, \vr0
.endm

.macro ct_bfu_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0
    vmul.vx  \vt1_0, \va1_1, \xzetaqinv1
    vmul.vx  \vt2_0, \va2_1, \xzetaqinv2
    vmul.vx  \vt3_0, \va3_1, \xzetaqinv3
    vmulh.vx \vt0_1, \va0_1, \xzeta0
    vmulh.vx \vt1_1, \va1_1, \xzeta1
    vmulh.vx \vt2_1, \va2_1, \xzeta2
    vmulh.vx \vt3_1, \va3_1, \xzeta3
    vmulh.vx \vt0_0, \vt0_0, \xq
    vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq
    vmulh.vx \vt3_0, \vt3_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \vt2_0, \vt2_1, \vt2_0
    vsub.vv  \vt3_0, \vt3_1, \vt3_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0
    vsub.vv  \va3_1, \va3_0, \vt3_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
    vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0
    vadd.vv  \va3_0, \va3_0, \vt3_0
.endm

.macro ct_bfu_vv_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, \
        vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vmul.vv  \vt0_0, \va0_1, \vzetaqinv0
    vmul.vv  \vt1_0, \va1_1, \vzetaqinv1
    vmul.vv  \vt2_0, \va2_1, \vzetaqinv2
    vmul.vv  \vt3_0, \va3_1, \vzetaqinv3
    vmulh.vv \vt0_1, \va0_1, \vzeta0
    vmulh.vv \vt1_1, \va1_1, \vzeta1
    vmulh.vv \vt2_1, \va2_1, \vzeta2
    vmulh.vv \vt3_1, \va3_1, \vzeta3
    vmulh.vx \vt0_0, \vt0_0, \xq
    vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq
    vmulh.vx \vt3_0, \vt3_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \vt2_0, \vt2_1, \vt2_0
    vsub.vv  \vt3_0, \vt3_1, \vt3_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0
    vsub.vv  \va3_1, \va3_0, \vt3_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
    vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0
    vadd.vv  \va3_0, \va3_0, \vt3_0
.endm

.macro ct_bfu_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xzeta4, xzetaqinv4, xzeta5, xzetaqinv5, \
        xzeta6, xzetaqinv6, xzeta7, xzetaqinv7, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1, \
        vt4_0, vt4_1, vt5_0, vt5_1, vt6_0, vt6_1, vt7_0, vt7_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0
    vmul.vx  \vt1_0, \va1_1, \xzetaqinv1
    vmul.vx  \vt2_0, \va2_1, \xzetaqinv2
    vmul.vx  \vt3_0, \va3_1, \xzetaqinv3
    vmul.vx  \vt4_0, \va4_1, \xzetaqinv4
    vmul.vx  \vt5_0, \va5_1, \xzetaqinv5
    vmul.vx  \vt6_0, \va6_1, \xzetaqinv6
    vmul.vx  \vt7_0, \va7_1, \xzetaqinv7
    vmulh.vx \vt0_1, \va0_1, \xzeta0
    vmulh.vx \vt1_1, \va1_1, \xzeta1
    vmulh.vx \vt2_1, \va2_1, \xzeta2
    vmulh.vx \vt3_1, \va3_1, \xzeta3
    vmulh.vx \vt4_1, \va4_1, \xzeta4
    vmulh.vx \vt5_1, \va5_1, \xzeta5
    vmulh.vx \vt6_1, \va6_1, \xzeta6
    vmulh.vx \vt7_1, \va7_1, \xzeta7
    vmulh.vx \vt0_0, \vt0_0, \xq
    vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq
    vmulh.vx \vt3_0, \vt3_0, \xq
    vmulh.vx \vt4_0, \vt4_0, \xq
    vmulh.vx \vt5_0, \vt5_0, \xq
    vmulh.vx \vt6_0, \vt6_0, \xq
    vmulh.vx \vt7_0, \vt7_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \vt2_0, \vt2_1, \vt2_0
    vsub.vv  \vt3_0, \vt3_1, \vt3_0
    vsub.vv  \vt4_0, \vt4_1, \vt4_0
    vsub.vv  \vt5_0, \vt5_1, \vt5_0
    vsub.vv  \vt6_0, \vt6_1, \vt6_0
    vsub.vv  \vt7_0, \vt7_1, \vt7_0
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

.macro gs_bfu_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1
    vsub.vv  \vt3_0, \va3_0, \va3_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1
    vadd.vv  \va3_0, \va3_0, \va3_1
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0
    vmul.vx  \va1_1, \vt1_0, \xzetaqinv1
    vmul.vx  \va2_1, \vt2_0, \xzetaqinv2
    vmul.vx  \va3_1, \vt3_0, \xzetaqinv3
    vmulh.vx \vt0_1, \vt0_0, \xzeta0
    vmulh.vx \vt1_1, \vt1_0, \xzeta1
    vmulh.vx \vt2_1, \vt2_0, \xzeta2
    vmulh.vx \vt3_1, \vt3_0, \xzeta3
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
    vsub.vv  \va1_1, \vt1_1, \va1_1
    vsub.vv  \va2_1, \vt2_1, \va2_1
    vsub.vv  \va3_1, \vt3_1, \va3_1
.endm

.macro gs_bfu_vv_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, \
        vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1
    vsub.vv  \vt3_0, \va3_0, \va3_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1
    vadd.vv  \va3_0, \va3_0, \va3_1
    vmul.vv  \va0_1, \vt0_0, \vzetaqinv0
    vmul.vv  \va1_1, \vt1_0, \vzetaqinv1
    vmul.vv  \va2_1, \vt2_0, \vzetaqinv2
    vmul.vv  \va3_1, \vt3_0, \vzetaqinv3
    vmulh.vv \vt0_1, \vt0_0, \vzeta0
    vmulh.vv \vt1_1, \vt1_0, \vzeta1
    vmulh.vv \vt2_1, \vt2_0, \vzeta2
    vmulh.vv \vt3_1, \vt3_0, \vzeta3
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
    vsub.vv  \va1_1, \vt1_1, \va1_1
    vsub.vv  \va2_1, \vt2_1, \va2_1
    vsub.vv  \va3_1, \vt3_1, \va3_1
.endm

.macro gs_bfu_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xzeta4, xzetaqinv4, xzeta5, xzetaqinv5, \
        xzeta6, xzetaqinv6, xzeta7, xzetaqinv7, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1, \
        vt4_0, vt4_1, vt5_0, vt5_1, vt6_0, vt6_1, vt7_0, vt7_1
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
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0
    vmul.vx  \va1_1, \vt1_0, \xzetaqinv1
    vmul.vx  \va2_1, \vt2_0, \xzetaqinv2
    vmul.vx  \va3_1, \vt3_0, \xzetaqinv3
    vmul.vx  \va4_1, \vt4_0, \xzetaqinv4
    vmul.vx  \va5_1, \vt5_0, \xzetaqinv5
    vmul.vx  \va6_1, \vt6_0, \xzetaqinv6
    vmul.vx  \va7_1, \vt7_0, \xzetaqinv7
    vmulh.vx \vt0_1, \vt0_0, \xzeta0
    vmulh.vx \vt1_1, \vt1_0, \xzeta1
    vmulh.vx \vt2_1, \vt2_0, \xzeta2
    vmulh.vx \vt3_1, \vt3_0, \xzeta3
    vmulh.vx \vt4_1, \vt4_0, \xzeta4
    vmulh.vx \vt5_1, \vt5_0, \xzeta5
    vmulh.vx \vt6_1, \vt6_0, \xzeta6
    vmulh.vx \vt7_1, \vt7_0, \xzeta7
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq
    vmulh.vx \va3_1, \va3_1, \xq
    vmulh.vx \va4_1, \va4_1, \xq
    vmulh.vx \va5_1, \va5_1, \xq
    vmulh.vx \va6_1, \va6_1, \xq
    vmulh.vx \va7_1, \va7_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
    vsub.vv  \va1_1, \vt1_1, \va1_1
    vsub.vv  \va2_1, \vt2_1, \va2_1
    vsub.vv  \va3_1, \vt3_1, \va3_1
    vsub.vv  \va4_1, \vt4_1, \va4_1
    vsub.vv  \va5_1, \vt5_1, \va5_1
    vsub.vv  \va6_1, \vt6_1, \va6_1
    vsub.vv  \va7_1, \vt7_1, \va7_1
.endm

.macro ntt_level0to3_rvv off
    lw   t2, (_ZETA_EXP_0TO3_L0+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L0+1)*4(a1)
    addi a2, a0, (4*\off)*4
    addi a3, a0, (4*\off+16)*4
    vle32.v v16, (a2)
    vle32.v v17, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v18, (a2)
    vle32.v v19, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v20, (a2)
    vle32.v v21, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v22, (a2)
    vle32.v v23, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v24, (a2)
    vle32.v v25, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v26, (a2)
    vle32.v v27, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v28, (a2)
    vle32.v v29, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v30, (a2)
    vle32.v v31, (a3)
    # level0
    ct_bfu_x8 \
        v16,v24,v17,v25,v18,v26,v19,v27,\
        v20,v28,v21,v29,v22,v30,v23,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t1, t2, t1, t2, t1, t2, t1, t2, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    # level1
    lw t2, (_ZETA_EXP_0TO3_L1+0)*4(a1)
    lw t1, (_ZETA_EXP_0TO3_L1+1)*4(a1)
    lw t4, (_ZETA_EXP_0TO3_L1+2)*4(a1)
    lw t3, (_ZETA_EXP_0TO3_L1+3)*4(a1)
    ct_bfu_x8 \
        v16,v20,v17,v21,v18,v22,v19,v23,\
        v24,v28,v25,v29,v26,v30,v27,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t3, t4, t3, t4, t3, t4, t3, t4, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    # level2
    lw t2, (_ZETA_EXP_0TO3_L2+0)*4(a1)
    lw t1, (_ZETA_EXP_0TO3_L2+1)*4(a1)
    lw t4, (_ZETA_EXP_0TO3_L2+2)*4(a1)
    lw t3, (_ZETA_EXP_0TO3_L2+3)*4(a1)
    lw t6, (_ZETA_EXP_0TO3_L2+4)*4(a1)
    lw t5, (_ZETA_EXP_0TO3_L2+5)*4(a1)
    lw a6, (_ZETA_EXP_0TO3_L2+6)*4(a1)
    lw a5, (_ZETA_EXP_0TO3_L2+7)*4(a1)
    ct_bfu_x8 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    # level3
    lw t2, (_ZETA_EXP_0TO3_L3+0)*4(a1)
    lw t1, (_ZETA_EXP_0TO3_L3+1)*4(a1)
    lw t4, (_ZETA_EXP_0TO3_L3+2)*4(a1)
    lw t3, (_ZETA_EXP_0TO3_L3+3)*4(a1)
    lw t6, (_ZETA_EXP_0TO3_L3+4)*4(a1)
    lw t5, (_ZETA_EXP_0TO3_L3+5)*4(a1)
    lw a6, (_ZETA_EXP_0TO3_L3+6)*4(a1)
    lw a5, (_ZETA_EXP_0TO3_L3+7)*4(a1)
    ct_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    lw t2, (_ZETA_EXP_0TO3_L3+8+0)*4(a1)
    lw t1, (_ZETA_EXP_0TO3_L3+8+1)*4(a1)
    lw t4, (_ZETA_EXP_0TO3_L3+8+2)*4(a1)
    lw t3, (_ZETA_EXP_0TO3_L3+8+3)*4(a1)
    lw t6, (_ZETA_EXP_0TO3_L3+8+4)*4(a1)
    lw t5, (_ZETA_EXP_0TO3_L3+8+5)*4(a1)
    lw a6, (_ZETA_EXP_0TO3_L3+8+6)*4(a1)
    lw a5, (_ZETA_EXP_0TO3_L3+8+7)*4(a1)
    addi a2, a0, (4*\off)*4
    addi a3, a0, (4*\off+16)*4
    vse32.v v16, (a2)
    vse32.v v17, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v18, (a2)
    vse32.v v19, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v20, (a2)
    vse32.v v21, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v22, (a2)
    vse32.v v23, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    ct_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    vse32.v v24, (a2)
    vse32.v v25, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v26, (a2)
    vse32.v v27, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v28, (a2)
    vse32.v v29, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v30, (a2)
    vse32.v v31, (a3)
.endm

.macro ntt_level4to7_rvv off, ZETA_EXP_4TO7_L4, ZETA_EXP_4TO7_L5, ZETA_EXP_4TO7_L6, ZETA_EXP_4TO7_L7
    li   a4, \ZETA_EXP_4TO7_L4*4
    addi a2, a0, (64*\off)*4
    add  a4, a4, a1
    addi a3, a0, (64*\off+4*8)*4
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    vl8re32.v v16, (a2)
    li   a4, \ZETA_EXP_4TO7_L5*4
    vl8re32.v v24, (a3)
    add  a4, a4, a1
    # level4
    ct_bfu_x8 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    # level5
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    ct_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    lw t2, (8+0)*4(a4)
    lw t1, (8+1)*4(a4)
    lw t4, (8+2)*4(a4)
    lw t3, (8+3)*4(a4)
    lw t6, (8+4)*4(a4)
    lw t5, (8+5)*4(a4)
    lw a6, (8+6)*4(a4)
    lw a5, (8+7)*4(a4)
    ct_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    # level6
    li t4, _MASK_1100*4
    li t5, _MASK_0101*4
    li t6, _MASK_2323*4
    add  t4, t4, a1
    add  t5, t5, a1
    add  t6, t6, a1
    vle32.v v0, (t4)
    vle32.v v1, (t5)
    vle32.v v2, (t6)
    li   t4, \ZETA_EXP_4TO7_L6*4
    shuffle2_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1, v2
    add  t4, t4, a1
    shuffle2_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1, v2
    vl8re32.v v8, (t4)
    addi t4, t4, 8*4*4
    ct_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v9, v8, v11,v10,v13,v12,v15,v14,t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    vl8re32.v v8, (t4)
    ct_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v9, v8, v11,v10,v13,v12,v15,v14,t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    # level7
    li t4, _MASK_1010*4
    li t5, _MASK_1032*4
    add t4, t4, a1
    add t5, t5, a1
    vle32.v v0, (t4)
    vle32.v v1, (t5)
    li   t4, \ZETA_EXP_4TO7_L7*4
    shuffle1_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1
    add  t4, t4, a1
    shuffle1_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1
    vl8re32.v v8, (t4)
    addi t4, t4, 8*4*4
    ct_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v9, v8, v11,v10,v13,v12,v15,v14,t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    vl8re32.v v8, (t4)
    vs8r.v v16, (a2)
    ct_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v9, v8, v11,v10,v13,v12,v15,v14,t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    vs8r.v v24, (a3)
.endm

.macro intt_level0to3_rvv off, ZETA_INTT_0TO3_L0, ZETA_INTT_0TO3_L1, ZETA_INTT_0TO3_L2, ZETA_INTT_0TO3_L3
    addi a2, a0, (64*\off)*4
    addi a3, a0, (64*\off+8*4)*4
    li   t4, \ZETA_INTT_0TO3_L0*4
    vl8re32.v v16, (a2)
    add  t4, t4, a1
    vl8re32.v v24, (a3)
    # level0
    vl8re32.v v0, (t4)
    addi t4, t4, 8*4*4
    gs_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v1, v0, v3, v2, v5, v4, v7, v6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    vl8re32.v v0, (t4)
    gs_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v1, v0, v3, v2, v5, v4, v7, v6, t0,\
        v8,v9,v10,v11,v12,v13,v14,v15
    # shuffle1 for level1
    li t4, _MASK_1010*4
    li t5, _MASK_1032*4
    add t4, t4, a1
    add t5, t5, a1
    vle32.v v0, (t4)
    vle32.v v1, (t5)
    li   t4, \ZETA_INTT_0TO3_L1*4
    shuffle1_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23, \
        v8, v9, v10,v11,v12,v13,v14,v15, v1
    add  t4, t4, a1
    shuffle1_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15, v1
    # level1
    vl8re32.v v0, (t4)
    addi t4, t4, 8*4*4
    gs_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v1, v0, v3, v2, v5, v4, v7, v6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    vl8re32.v v0, (t4)
    gs_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v1, v0, v3, v2, v5, v4, v7, v6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    # shuffle2 for level2
    li t4, _MASK_1100*4
    li t5, _MASK_0101*4
    li t6, _MASK_2323*4
    add t4, t4, a1
    add t5, t5, a1
    add t6, t6, a1
    vle32.v v0, (t4)
    vle32.v v1, (t5)
    vle32.v v2, (t6)
    li   a4, \ZETA_INTT_0TO3_L2*4
    shuffle2_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1,v2
    add  a4, a4, a1
    shuffle2_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,v1,v2
    # level2
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    gs_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    lw t2, (8+0)*4(a4)
    lw t1, (8+1)*4(a4)
    lw t4, (8+2)*4(a4)
    lw t3, (8+3)*4(a4)
    lw t6, (8+4)*4(a4)
    lw t5, (8+5)*4(a4)
    lw a6, (8+6)*4(a4)
    lw a5, (8+7)*4(a4)
    li a4, \ZETA_INTT_0TO3_L3*4
    gs_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    # level3
    add  a4, a4, a1
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    gs_bfu_x4 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        t1, t2, t1, t2, t3, t4, t3, t4, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7
    vs8r.v v16, (a2)
    gs_bfu_x4 \
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t5, t6, t5, t6, a5, a6, a5, a6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    vs8r.v v24, (a3)
.endm

.macro intt_level4to7_rvv off
    addi a2, a0, (4*\off)*4
    addi a3, a0, (4*\off+16)*4
    vle32.v v16, (a2)
    vle32.v v17, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v18, (a2)
    vle32.v v19, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v20, (a2)
    vle32.v v21, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v22, (a2)
    vle32.v v23, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v24, (a2)
    vle32.v v25, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vle32.v v26, (a2)
    vle32.v v27, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    li   a4, _ZETA_EXP_INTT_4TO7_L4*4
    vle32.v v28, (a2)
    vle32.v v29, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    add  a4, a4, a1
    vle32.v v30, (a2)
    vle32.v v31, (a3)
    # level4
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    gs_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    lw t2, (8+0)*4(a4)
    lw t1, (8+1)*4(a4)
    lw t4, (8+2)*4(a4)
    lw t3, (8+3)*4(a4)
    lw t6, (8+4)*4(a4)
    lw t5, (8+5)*4(a4)
    lw a6, (8+6)*4(a4)
    lw a5, (8+7)*4(a4)
    li a4, _ZETA_EXP_INTT_4TO7_L5*4
    gs_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, t0,\
        v8, v9, v10,v11,v12,v13,v14,v15
    # level5
    add  a4, a4, a1
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    lw t6, 4*4(a4)
    lw t5, 5*4(a4)
    lw a6, 6*4(a4)
    lw a5, 7*4(a4)
    li a4, _ZETA_EXP_INTT_4TO7_L6*4
    gs_bfu_x8 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7,\
        v8, v9, v10,v11,v12,v13,v14,v15
    # level6
    add  a4, a4, a1
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    lw t4, 2*4(a4)
    lw t3, 3*4(a4)
    li a4, _ZETA_EXP_INTT_4TO7_L7*4
    gs_bfu_x8 \
        v16,v20,v17,v21,v18,v22,v19,v23,\
        v24,v28,v25,v29,v26,v30,v27,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t3, t4, t3, t4, t3, t4, t3, t4, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7,\
        v8, v9, v10,v11,v12,v13,v14,v15
    # level7
    add  a4, a4, a1
    lw t2, 0*4(a4)
    lw t1, 1*4(a4)
    gs_bfu_x8 \
        v16,v24,v17,v25,v18,v26,v19,v27,\
        v20,v28,v21,v29,v22,v30,v23,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t1, t2, t1, t2, t1, t2, t1, t2, t0,\
        v0, v1, v2, v3, v4, v5, v6, v7,\
        v8, v9, v10,v11,v12,v13,v14,v15
    li t2, inv256
    li t3, inv256qinv
    tomont_x8 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t2, t3, t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    addi a2, a0, (4*\off)*4
    addi a3, a0, (4*\off+16)*4
    vse32.v v16, (a2)
    vse32.v v17, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v18, (a2)
    vse32.v v19, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v20, (a2)
    vse32.v v21, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v22, (a2)
    vse32.v v23, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v24, (a2)
    vse32.v v25, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v26, (a2)
    vse32.v v27, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v28, (a2)
    vse32.v v29, (a3)
    addi a2, a2, 32*4
    addi a3, a3, 32*4
    vse32.v v30, (a2)
    vse32.v v31, (a3)
.endm

# q * qinv = 1 mod 2^32, used for Montgomery arithmetic
.equ q, 8380417
.equ qinv, 58728449
# inv256 = 2^64 * (1/256) mod q is used for reverting standard domain
.equ inv256, 41978
# inv256qinv <- low(inv256*qinv)
.equ inv256qinv, 4286571514

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
    addi sp, sp, -8*15    # Allocate stack space
    save_regs             # Save all callee-saved registers
    
    li a7, 4*8
    li t2, 8
    vsetvli a7, a7, e32, m8, tu, mu
    li t0, q
    li t1, qinv
poly_basemul_acc_rvv_vlen128_loop:
    vle32.v v0,  (a1)
    addi a1, a1, 4*4*8
    vle32.v v8,  (a2)
    addi a2, a2, 4*4*8
    montmul_ref v16, v0, v8, t0, t1, v24
    vle32.v v24, (a0)
    vadd.vv v24, v24, v16
    vse32.v v24, (a0)
    addi a0, a0, 4*4*8
    addi t2, t2, -1
    bnez t2, poly_basemul_acc_rvv_vlen128_loop
    
    restore_regs          # Restore all saved registers
    addi sp, sp, 8*15     # Deallocate stack space
ret
include "consts.h"

// [a0,a1,a2,a3]+[a4,a5,a6,a7] -> [a0,a1,a4,a5]+[a2,a3,a6,a7]
// related masks are ready for using
// v0: _MASK_1100, vm0/vm1: _MASK_0101/_MASK_2323
.macro shuffle2 in0_0, in0_1, tm0_0, tm0_1, vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0      // [a4,a5,a4,a5]
    vrgather.vv \tm0_1, \in0_0, \vm1      // [a2,a3,a2,a3]
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
.endm

.macro shuffle2_x2 \
        in0_0, in0_1, in1_0, in1_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, \
        vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm1
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm1
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
.endm

.macro shuffle2_x4 \
        in0_0, in0_1, in1_0, in1_1, \
        in2_0, in2_1, in3_0, in3_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, \
        tm2_0, tm2_1, tm3_0, tm3_1, \
        vm0, vm1
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
.macro shuffle1 in0_0, in0_1, tm0_0, tm0_1, vm0
    vrgather.vv \tm0_0, \in0_1, \vm0      // [a3,a2,a7,a6]
    vrgather.vv \tm0_1, \in0_0, \vm0      // [a1,a0,a5,a4]
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
.endm

.macro shuffle1_x2 \
        in0_0, in0_1, in1_0, in1_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, \
        vm0
    vrgather.vv \tm0_0, \in0_1, \vm0
    vrgather.vv \tm0_1, \in0_0, \vm0
    vrgather.vv \tm1_0, \in1_1, \vm0
    vrgather.vv \tm1_1, \in1_0, \vm0
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0
    vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0
    vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
.endm

.macro shuffle1_x4 \
        in0_0, in0_1, in1_0, in1_1, \
        in2_0, in2_1, in3_0, in3_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, \
        tm2_0, tm2_1, tm3_0, tm3_1, \
        vm0
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

.macro tomont va0, xb, xbqinv, xq, vt0
    vmul.vx  \vt0, \va0, \xbqinv
    vmulh.vx \va0, \va0, \xb
    vmulh.vx \vt0, \vt0, \xq
    vsub.vv  \va0, \va0, \vt0
.endm

.macro tomont_x2 \
        va0, va1, \
        xb, xbqinv, xq, \
        vt0, vt1
    vmul.vx  \vt0, \va0, \xbqinv
    vmul.vx  \vt1, \va1, \xbqinv
    vmulh.vx \va0, \va0, \xb
    vmulh.vx \va1, \va1, \xb
    vmulh.vx \vt0, \vt0, \xq
    vmulh.vx \vt1, \vt1, \xq
    vsub.vv  \va0, \va0, \vt0
    vsub.vv  \va1, \va1, \vt1
.endm

.macro tomont_x4 \
        va0, va1, va2, va3, \
        xb, xbqinv, xq, \
        vt0, vt1, vt2, vt3
    vmul.vx  \vt0, \va0, \xbqinv
    vmul.vx  \vt1, \va1, \xbqinv
    vmul.vx  \vt2, \va2, \xbqinv
    vmul.vx  \vt3, \va3, \xbqinv
    vmulh.vx \va0, \va0, \xb
    vmulh.vx \va1, \va1, \xb
    vmulh.vx \va2, \va2, \xb
    vmulh.vx \va3, \va3, \xb
    vmulh.vx \vt0, \vt0, \xq
    vmulh.vx \vt1, \vt1, \xq
    vmulh.vx \vt2, \vt2, \xq
    vmulh.vx \vt3, \vt3, \xq
    vsub.vv  \va0, \va0, \vt0
    vsub.vv  \va1, \va1, \vt1
    vsub.vv  \va2, \va2, \vt2
    vsub.vv  \va3, \va3, \vt3
.endm

.macro tomont_x8 \
        va0, va1, va2, va3, \
        va4, va5, va6, va7, \
        xb, xbqinv, xq, \
        vt0, vt1, vt2, vt3, \
        vt4, vt5, vt6, vt7
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

.macro montmul_ref_x2 \
        vr0, vr1, \
        va0, va1, \
        vb0, vb1, \
        xq, xqinv, \
        vt0, vt1
    vmul.vv  \vr0, \va0, \vb0
    vmul.vv  \vr1, \va1, \vb1
    vmul.vx  \vr0, \vr0, \xqinv
    vmul.vx  \vr1, \vr1, \xqinv
    vmulh.vx \vr0, \vr0, \xq
    vmulh.vx \vr1, \vr1, \xq
    vmulh.vv \vt0, \va0, \vb0
    vmulh.vv \vt1, \va1, \vb1
    vsub.vv  \vr0, \vt0, \vr0
    vsub.vv  \vr1, \vt1, \vr1
.endm

.macro montmul_ref_x4 \
        vr0, vr1, vr2, vr3, \
        va0, va1, va2, va3, \
        vb0, vb1, vb2, vb3, \
        xq, xqinv, \
        vt0, vt1, vt2, vt3
    vmul.vv  \vr0, \va0, \vb0
    vmul.vv  \vr1, \va1, \vb1
    vmul.vv  \vr2, \va2, \vb2
    vmul.vv  \vr3, \va3, \vb3
    vmul.vx  \vr0, \vr0, \xqinv
    vmul.vx  \vr1, \vr1, \xqinv
    vmul.vx  \vr2, \vr2, \xqinv
    vmul.vx  \vr3, \vr3, \xqinv
    vmulh.vx \vr0, \vr0, \xq
    vmulh.vx \vr1, \vr1, \xq
    vmulh.vx \vr2, \vr2, \xq
    vmulh.vx \vr3, \vr3, \xq
    vmulh.vv \vt0, \va0, \vb0
    vmulh.vv \vt1, \va1, \vb1
    vmulh.vv \vt2, \va2, \vb2
    vmulh.vv \vt3, \va3, \vb3
    vsub.vv  \vr0, \vt0, \vr0
    vsub.vv  \vr1, \vt1, \vr1
    vsub.vv  \vr2, \vt2, \vr2
    vsub.vv  \vr3, \vt3, \vr3
.endm

.macro montmul_ref_x8 \
        vr0, vr1, vr2, vr3, vr4, vr5, vr6, vr7,  \
        va0, va1, va2, va3, va4, va5, va6, va7,  \
        vb0, vb1, vb2, vb3, vb4, vb5, vb6, vb7,  \
        xq, xqinv, \
        vt0, vt1, vt2, vt3, vt4, vt5, vt6, vt7
    vmul.vv  \vr0, \va0, \vb0
    vmul.vv  \vr1, \va1, \vb1
    vmul.vv  \vr2, \va2, \vb2
    vmul.vv  \vr3, \va3, \vb3
    vmul.vv  \vr4, \va4, \vb4
    vmul.vv  \vr5, \va5, \vb5
    vmul.vv  \vr6, \va6, \vb6
    vmul.vv  \vr7, \va7, \vb7
    vmul.vx  \vr0, \vr0, \xqinv
    vmul.vx  \vr1, \vr1, \xqinv
    vmul.vx  \vr2, \vr2, \xqinv
    vmul.vx  \vr3, \vr3, \xqinv
    vmul.vx  \vr4, \vr4, \xqinv
    vmul.vx  \vr5, \vr5, \xqinv
    vmul.vx  \vr6, \vr6, \xqinv
    vmul.vx  \vr7, \vr7, \xqinv
    vmulh.vx \vr0, \vr0, \xq
    vmulh.vx \vr1, \vr1, \xq
    vmulh.vx \vr2, \vr2, \xq
    vmulh.vx \vr3, \vr3, \xq
    vmulh.vx \vr4, \vr4, \xq
    vmulh.vx \vr5, \vr5, \xq
    vmulh.vx \vr6, \vr6, \xq
    vmulh.vx \vr7, \vr7, \xq
    vmulh.vv \vt0, \va0, \vb0
    vmulh.vv \vt1, \va1, \vb1
    vmulh.vv \vt2, \va2, \vb2
    vmulh.vv \vt3, \va3, \vb3
    vmulh.vv \vt4, \va4, \vb4
    vmulh.vv \vt5, \va5, \vb5
    vmulh.vv \vt6, \va6, \vb6
    vmulh.vv \vt7, \va7, \vb7
    vsub.vv  \vr0, \vt0, \vr0
    vsub.vv  \vr1, \vt1, \vr1
    vsub.vv  \vr2, \vt2, \vr2
    vsub.vv  \vr3, \vt3, \vr3
    vsub.vv  \vr4, \vt4, \vr4
    vsub.vv  \vr5, \vt5, \vr5
    vsub.vv  \vr6, \vt6, \vr6
    vsub.vv  \vr7, \vt7, \vr7
.endm

.macro ct_bfu \
        va0_0, va0_1, \
        xzeta0, xzetaqinv0, \
        xq, vt0_0, vt0_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0
    vmulh.vx \vt0_1, \va0_1, \xzeta0
    vmulh.vx \vt0_0, \vt0_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0
    vsub.vv  \va0_1, \va0_0, \vt0_0
    vadd.vv  \va0_0, \va0_0, \vt0_0
.endm

.macro ct_bfu_x2 \
        va0_0, va0_1, va1_0, va1_1, \
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

.macro ct_bfu_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1
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
        vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1
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
        xzeta6, xzetaqinv6, xzeta7, xzetaqinv7, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1, \
        vt4_0, vt4_1, vt5_0, vt5_1, \
        vt6_0, vt6_1, vt7_0, vt7_1
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

.macro gs_bfu \
        va0_0, va0_1, \
        xzeta0, xzetaqinv0, \
        xq, vt0_0, vt0_1
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0
    vmulh.vx \vt0_1, \vt0_0, \xzeta0
    vmulh.vx \va0_1, \va0_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
.endm

.macro gs_bfu_x2 \
        va0_0, va0_1, va1_0, va1_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1
    vsub.vv  \vt0_0, \va0_0, \va0_1
    vsub.vv  \vt1_0, \va1_0, \va1_1
    vadd.vv  \va0_0, \va0_0, \va0_1
    vadd.vv  \va1_0, \va1_0, \va1_1
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0
    vmul.vx  \va1_1, \vt1_0, \xzetaqinv1
    vmulh.vx \vt0_1, \vt0_0, \xzeta0
    vmulh.vx \vt1_1, \vt1_0, \xzeta1
    vmulh.vx \va0_1, \va0_1, \xq
    vmulh.vx \va1_1, \va1_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1
    vsub.vv  \va1_1, \vt1_1, \va1_1
.endm

.macro gs_bfu_x4 \
        va0_0, va0_1, va1_0, va1_1, \
        va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1
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
        va0_0, va0_1, va1_0, va1_1, \
        va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, \
        vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1
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
        va0_0, va0_1, va1_0, va1_1, \
        va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, \
        va6_0, va6_1, va7_0, va7_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, \
        xzeta4, xzetaqinv4, xzeta5, xzetaqinv5, \
        xzeta6, xzetaqinv6, xzeta7, xzetaqinv7, \
        xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, \
        vt2_0, vt2_1, vt3_0, vt3_1, \
        vt4_0, vt4_1, vt5_0, vt5_1, \
        vt6_0, vt6_1, vt7_0, vt7_1
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

// Do not use the vlse instruction to implement NTT, as its latency is higher than that of the vle instruction.
// This is a version using vector-grouping. The performance is slightly slower than normal version
// .macro ntt_8l_level0to3_rvv off
//     vsetivli t2, 4, e32, m1, tu, mu
//     lw   t2, (_ZETA_EXP_0TO3_L0+0)*4(a1)
//     lw   t1, (_ZETA_EXP_0TO3_L0+1)*4(a1)
//     addi a0, a0, (4*\off)*4
//     vle32.v v16, (a0)//          addi a0, a0, 16*4
//     vle32.v v17, (a0)//          addi a0, a0, 16*4
//     vle32.v v18, (a0)//          addi a0, a0, 16*4
//     vle32.v v19, (a0)//          addi a0, a0, 16*4
//     vle32.v v20, (a0)//          addi a0, a0, 16*4
//     vle32.v v21, (a0)//          addi a0, a0, 16*4
//     vle32.v v22, (a0)//          addi a0, a0, 16*4
//     vle32.v v23, (a0)//          addi a0, a0, 16*4
//     vle32.v v24, (a0)//          addi a0, a0, 16*4
//     vle32.v v25, (a0)//          addi a0, a0, 16*4
//     vle32.v v26, (a0)//          addi a0, a0, 16*4
//     vle32.v v27, (a0)//          addi a0, a0, 16*4
//     vle32.v v28, (a0)//          addi a0, a0, 16*4
//     vle32.v v29, (a0)//          addi a0, a0, 16*4
//     vle32.v v30, (a0)//          addi a0, a0, 16*4
//     vle32.v v31, (a0)//          addi a0, a0, -(16*15)*4
//     // level0
//     li t1, 32
//     vsetvli t2, t1, e32, m8, tu, mu
//     ct_bfu v16, v24, t1, t2, t0, v0, v8
//     // level1
//     lw   t2, (_ZETA_EXP_0TO3_L1+0)*4(a1)
//     lw   t1, (_ZETA_EXP_0TO3_L1+1)*4(a1)
//     lw   t4, (_ZETA_EXP_0TO3_L1+2)*4(a1)
//     lw   t3, (_ZETA_EXP_0TO3_L1+3)*4(a1)
//     vsetivli t2, 16, e32, m4, tu, mu
//     ct_bfu_x2 \
//         v16,v20,v24,v28, \
//         t1, t2, t3, t4, \
//         t0, v0, v4, v8, v12
//     // level2
//     lw   t2, (_ZETA_EXP_0TO3_L2+0)*4(a1)
//     lw   t1, (_ZETA_EXP_0TO3_L2+1)*4(a1)
//     lw   t4, (_ZETA_EXP_0TO3_L2+2)*4(a1)
//     lw   t3, (_ZETA_EXP_0TO3_L2+3)*4(a1)
//     lw   t6, (_ZETA_EXP_0TO3_L2+4)*4(a1)
//     lw   t5, (_ZETA_EXP_0TO3_L2+5)*4(a1)
//     lw   a6, (_ZETA_EXP_0TO3_L2+6)*4(a1)
//     lw   a5, (_ZETA_EXP_0TO3_L2+7)*4(a1)
//     vsetivli t2, 8, e32, m2, tu, mu
//     ct_bfu_x4 \
//         v16,v18,v20,v22,v24,v26,v28,v30,\
//         t1, t2, t3, t4, t5, t6, a5, a6, \
//         t0, v0, v2, v4, v6, v8, v10,v12,v14
//     // level3
//     lw   t2, (_ZETA_EXP_0TO3_L3+0)*4(a1)
//     lw   t1, (_ZETA_EXP_0TO3_L3+1)*4(a1)
//     lw   t4, (_ZETA_EXP_0TO3_L3+2)*4(a1)
//     lw   t3, (_ZETA_EXP_0TO3_L3+3)*4(a1)
//     lw   t6, (_ZETA_EXP_0TO3_L3+4)*4(a1)
//     lw   t5, (_ZETA_EXP_0TO3_L3+5)*4(a1)
//     lw   a6, (_ZETA_EXP_0TO3_L3+6)*4(a1)
//     lw   a5, (_ZETA_EXP_0TO3_L3+7)*4(a1)
//     vsetivli t2, 4, e32, m1, tu, mu
//     ct_bfu_x4 \
//         v16,v17,v18,v19,v20,v21,v22,v23,\
//         t1, t2, t3, t4, t5, t6, a5, a6, \
//         t0, \
//         v0, v1, v2, v3, v4, v5, v6, v7
//     lw   t2, (_ZETA_EXP_0TO3_L3+8+0)*4(a1)
//     lw   t1, (_ZETA_EXP_0TO3_L3+8+1)*4(a1)
//     lw   t4, (_ZETA_EXP_0TO3_L3+8+2)*4(a1)
//     lw   t3, (_ZETA_EXP_0TO3_L3+8+3)*4(a1)
//     lw   t6, (_ZETA_EXP_0TO3_L3+8+4)*4(a1)
//     lw   t5, (_ZETA_EXP_0TO3_L3+8+5)*4(a1)
//     lw   a6, (_ZETA_EXP_0TO3_L3+8+6)*4(a1)
//     lw   a5, (_ZETA_EXP_0TO3_L3+8+7)*4(a1)
//     ct_bfu_x4 \
//         v24,v25,v26,v27,v28,v29,v30,v31,\
//         t1, t2, t3, t4, t5, t6, a5, a6, \
//         t0, \
//         v0, v1, v2, v3, v4, v5, v6, v7
//     vse32.v v16, (a0)//          addi a0, a0, 16*4
//     vse32.v v17, (a0)//          addi a0, a0, 16*4
//     vse32.v v18, (a0)//          addi a0, a0, 16*4
//     vse32.v v19, (a0)//          addi a0, a0, 16*4
//     vse32.v v20, (a0)//          addi a0, a0, 16*4
//     vse32.v v21, (a0)//          addi a0, a0, 16*4
//     vse32.v v22, (a0)//          addi a0, a0, 16*4
//     vse32.v v23, (a0)//          addi a0, a0, 16*4
//     vse32.v v24, (a0)//          addi a0, a0, 16*4
//     vse32.v v25, (a0)//          addi a0, a0, 16*4
//     vse32.v v26, (a0)//          addi a0, a0, 16*4
//     vse32.v v27, (a0)//          addi a0, a0, 16*4
//     vse32.v v28, (a0)//          addi a0, a0, 16*4
//     vse32.v v29, (a0)//          addi a0, a0, 16*4
//     vse32.v v30, (a0)//          addi a0, a0, 16*4
//     vse32.v v31, (a0)//          addi a0, a0, -(4*\off+16*15)*4
// .endm

.macro ntt_8l_level0to3_rvv off
    lw   t2, (_ZETA_EXP_0TO3_L0+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L0+1)*4(a1)
    addi a0, a0, (4*\off)*4
    vle32.v v16, (a0)//          addi a0, a0, 16*4
    vle32.v v17, (a0)//          addi a0, a0, 16*4
    vle32.v v18, (a0)//          addi a0, a0, 16*4
    vle32.v v19, (a0)//          addi a0, a0, 16*4
    vle32.v v20, (a0)//          addi a0, a0, 16*4
    vle32.v v21, (a0)//          addi a0, a0, 16*4
    vle32.v v22, (a0)//          addi a0, a0, 16*4
    vle32.v v23, (a0)//          addi a0, a0, 16*4
    vle32.v v24, (a0)//          addi a0, a0, 16*4
    vle32.v v25, (a0)//          addi a0, a0, 16*4
    vle32.v v26, (a0)//          addi a0, a0, 16*4
    vle32.v v27, (a0)//          addi a0, a0, 16*4
    vle32.v v28, (a0)//          addi a0, a0, 16*4
    vle32.v v29, (a0)//          addi a0, a0, 16*4
    vle32.v v30, (a0)//          addi a0, a0, 16*4
    vle32.v v31, (a0)//          addi a0, a0, -(16*15)*4
    // level0
    ct_bfu_x8 \
        v16,v24,v17,v25,v18,v26,v19,v27,\
        v20,v28,v21,v29,v22,v30,v23,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    // level1
    lw   t2, (_ZETA_EXP_0TO3_L1+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L1+1)*4(a1)
    lw   t4, (_ZETA_EXP_0TO3_L1+2)*4(a1)
    lw   t3, (_ZETA_EXP_0TO3_L1+3)*4(a1)
    ct_bfu_x8 \
        v16,v20,v17,v21,v18,v22,v19,v23,\
        v24,v28,v25,v29,v26,v30,v27,v31,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t3, t4, t3, t4, t3, t4, t3, t4, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    // level2
    lw   t2, (_ZETA_EXP_0TO3_L2+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L2+1)*4(a1)
    lw   t4, (_ZETA_EXP_0TO3_L2+2)*4(a1)
    lw   t3, (_ZETA_EXP_0TO3_L2+3)*4(a1)
    lw   t6, (_ZETA_EXP_0TO3_L2+4)*4(a1)
    lw   t5, (_ZETA_EXP_0TO3_L2+5)*4(a1)
    lw   a6, (_ZETA_EXP_0TO3_L2+6)*4(a1)
    lw   a5, (_ZETA_EXP_0TO3_L2+7)*4(a1)
    ct_bfu_x8 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    // level3
    lw   t2, (_ZETA_EXP_0TO3_L3+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L3+1)*4(a1)
    lw   t4, (_ZETA_EXP_0TO3_L3+2)*4(a1)
    lw   t3, (_ZETA_EXP_0TO3_L3+3)*4(a1)
    lw   t6, (_ZETA_EXP_0TO3_L3+4)*4(a1)
    lw   t5, (_ZETA_EXP_0TO3_L3+5)*4(a1)
    lw   a6, (_ZETA_EXP_0TO3_L3+6)*4(a1)
    lw   a5, (_ZETA_EXP_0TO3_L3+7)*4(a1)
    ct_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    lw   t2, (_ZETA_EXP_0TO3_L3+8+0)*4(a1)
    lw   t1, (_ZETA_EXP_0TO3_L3+8+1)*4(a1)
    lw   t4, (_ZETA_EXP_0TO3_L3+8+2)*4(a1)
    lw   t3, (_ZETA_EXP_0TO3_L3+8+3)*4(a1)
    lw   t6, (_ZETA_EXP_0TO3_L3+8+4)*4(a1)
    lw   t5, (_ZETA_EXP_0TO3_L3+8+5)*4(a1)
    lw   a6, (_ZETA_EXP_0TO3_L3+8+6)*4(a1)
    lw   a5, (_ZETA_EXP_0TO3_L3+8+7)*4(a1)
    ct_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    vse32.v v16, (a0)//          addi a0, a0, 16*4
    vse32.v v17, (a0)//          addi a0, a0, 16*4
    vse32.v v18, (a0)//          addi a0, a0, 16*4
    vse32.v v19, (a0)//          addi a0, a0, 16*4
    vse32.v v20, (a0)//          addi a0, a0, 16*4
    vse32.v v21, (a0)//          addi a0, a0, 16*4
    vse32.v v22, (a0)//          addi a0, a0, 16*4
    vse32.v v23, (a0)//          addi a0, a0, 16*4
    vse32.v v24, (a0)//          addi a0, a0, 16*4
    vse32.v v25, (a0)//          addi a0, a0, 16*4
    vse32.v v26, (a0)//          addi a0, a0, 16*4
    vse32.v v27, (a0)//          addi a0, a0, 16*4
    vse32.v v28, (a0)//          addi a0, a0, 16*4
    vse32.v v29, (a0)//          addi a0, a0, 16*4
    vse32.v v30, (a0)//          addi a0, a0, 16*4
    vse32.v v31, (a0)//          addi a0, a0, -(4*\off+16*15)*4
.endm

.macro ntt_8l_level4to7_rvv off, ZETA_EXP_4TO7_L4, ZETA_EXP_4TO7_L5, ZETA_EXP_4TO7_L6, ZETA_EXP_4TO7_L7
    li   a4, \ZETA_EXP_4TO7_L4*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    addi a0, a0, (64*\off)*4
    vle32.v v16, (a0)//          addi a0, a0, 4*4
    vle32.v v17, (a0)//          addi a0, a0, 4*4
    vle32.v v18, (a0)//          addi a0, a0, 4*4
    vle32.v v19, (a0)//          addi a0, a0, 4*4
    vle32.v v20, (a0)//          addi a0, a0, 4*4
    vle32.v v21, (a0)//          addi a0, a0, 4*4
    vle32.v v22, (a0)//          addi a0, a0, 4*4
    vle32.v v23, (a0)//          addi a0, a0, 4*4
    vle32.v v24, (a0)//          addi a0, a0, 4*4
    vle32.v v25, (a0)//          addi a0, a0, 4*4
    vle32.v v26, (a0)//          addi a0, a0, 4*4
    vle32.v v27, (a0)//          addi a0, a0, 4*4
    vle32.v v28, (a0)//          addi a0, a0, 4*4
    vle32.v v29, (a0)//          addi a0, a0, 4*4
    vle32.v v30, (a0)//          addi a0, a0, 4*4
    vle32.v v31, (a0)//          addi a0, a0, -(4*15)*4
    // level4
    ct_bfu_x8 \
        v16,v18,v17,v19,v20,v22,v21,v23,\
        v24,v26,v25,v27,v28,v30,v29,v31,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,v14,v15
    // level5
    li   a4, \ZETA_EXP_4TO7_L5*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    ct_bfu_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    lw   t2, (8+0)*4(a4)
    lw   t1, (8+1)*4(a4)
    lw   t4, (8+2)*4(a4)
    lw   t3, (8+3)*4(a4)
    lw   t6, (8+4)*4(a4)
    lw   t5, (8+5)*4(a4)
    lw   a6, (8+6)*4(a4)
    lw   a5, (8+7)*4(a4)
    ct_bfu_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    // level6
    li   t4, _MASK_1100*4
    add  t4, t4, a1
    vle32.v v0,  (t4)
    li   t4, _MASK_0101*4
    add  t4, t4, a1
    vle32.v v1, (t4)
    li   t4, _MASK_2323*4
    add  t4, t4, a1
    vle32.v v2, (t4)
    shuffle2_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        v1, v2
    shuffle2_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        v1, v2
    li   t4, \ZETA_EXP_4TO7_L6*4
    add  t4, t4, a1
    vle32.v v9,  (t4)//      addi t4, t4, 4*4
    vle32.v v8,  (t4)//      addi t4, t4, 4*4
    vle32.v v11, (t4)//      addi t4, t4, 4*4
    vle32.v v10, (t4)//      addi t4, t4, 4*4
    vle32.v v13, (t4)//      addi t4, t4, 4*4
    vle32.v v12, (t4)//      addi t4, t4, 4*4
    vle32.v v15, (t4)//      addi t4, t4, 4*4
    vle32.v v14, (t4)//      addi t4, t4, 4*4
    ct_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    vle32.v v9,  (t4)//      addi t4, t4, 4*4
    vle32.v v8,  (t4)//      addi t4, t4, 4*4
    vle32.v v11, (t4)//      addi t4, t4, 4*4
    vle32.v v10, (t4)//      addi t4, t4, 4*4
    vle32.v v13, (t4)//      addi t4, t4, 4*4
    vle32.v v12, (t4)//      addi t4, t4, 4*4
    vle32.v v15, (t4)//      addi t4, t4, 4*4
    vle32.v v14, (t4)
    ct_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    // level7
    li   t4, _MASK_1010*4
    add  t4, t4, a1
    vle32.v v0,  (t4)
    li   t4, _MASK_1032*4
    add  t4, t4, a1
    vle32.v v1, (t4)
    shuffle1_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        v1
    shuffle1_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        v1
    li   t4, \ZETA_EXP_4TO7_L7*4
    add  t4, t4, a1
    vle32.v v9,  (t4)//      addi t4, t4, 4*4
    vle32.v v8,  (t4)//      addi t4, t4, 4*4
    vle32.v v11, (t4)//      addi t4, t4, 4*4
    vle32.v v10, (t4)//      addi t4, t4, 4*4
    vle32.v v13, (t4)//      addi t4, t4, 4*4
    vle32.v v12, (t4)//      addi t4, t4, 4*4
    vle32.v v15, (t4)//      addi t4, t4, 4*4
    vle32.v v14, (t4)//      addi t4, t4, 4*4
    ct_bfu_vv_x4 \
        v16,v17,v18,v19,v20,v21,v22,v23,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    vle32.v v9,  (t4)//      addi t4, t4, 4*4
    vle32.v v8,  (t4)//      addi t4, t4, 4*4
    vle32.v v11, (t4)//      addi t4, t4, 4*4
    vle32.v v10, (t4)//      addi t4, t4, 4*4
    vle32.v v13, (t4)//      addi t4, t4, 4*4
    vle32.v v12, (t4)//      addi t4, t4, 4*4
    vle32.v v15, (t4)//      addi t4, t4, 4*4
    vle32.v v14, (t4)
    ct_bfu_vv_x4 \
        v24,v25,v26,v27,v28,v29,v30,v31,\
        v8, v9, v10,v11,v12,v13,v14,v15,\
        t0, \
        v0, v1, v2, v3, v4, v5, v6, v7
    vse32.v v16, (a0)//          addi a0, a0, 4*4
    vse32.v v17, (a0)//          addi a0, a0, 4*4
    vse32.v v18, (a0)//          addi a0, a0, 4*4
    vse32.v v19, (a0)//          addi a0, a0, 4*4
    vse32.v v20, (a0)//          addi a0, a0, 4*4
    vse32.v v21, (a0)//          addi a0, a0, 4*4
    vse32.v v22, (a0)//          addi a0, a0, 4*4
    vse32.v v23, (a0)//          addi a0, a0, 4*4
    vse32.v v24, (a0)//          addi a0, a0, 4*4
    vse32.v v25, (a0)//          addi a0, a0, 4*4
    vse32.v v26, (a0)//          addi a0, a0, 4*4
    vse32.v v27, (a0)//          addi a0, a0, 4*4
    vse32.v v28, (a0)//          addi a0, a0, 4*4
    vse32.v v29, (a0)//          addi a0, a0, 4*4
    vse32.v v30, (a0)//          addi a0, a0, 4*4
    vse32.v v31, (a0)//          addi a0, a0, -(64*\off+4*15)*4
.endm

.macro intt_8l_level0to3_rvv off, ZETA_INTT_0TO3_L0, ZETA_INTT_0TO3_L1, ZETA_INTT_0TO3_L2, ZETA_INTT_0TO3_L3
    addi a0, a0, (64*\off)*4
    vle32.v v1,  (a0)//          addi a0, a0, 4*4
    vle32.v v2,  (a0)//          addi a0, a0, 4*4
    vle32.v v3,  (a0)//          addi a0, a0, 4*4
    vle32.v v4,  (a0)//          addi a0, a0, 4*4
    vle32.v v5,  (a0)//          addi a0, a0, 4*4
    vle32.v v6,  (a0)//          addi a0, a0, 4*4
    vle32.v v7,  (a0)//          addi a0, a0, 4*4
    vle32.v v8,  (a0)//          addi a0, a0, 4*4
    vle32.v v9,  (a0)//          addi a0, a0, 4*4
    vle32.v v10, (a0)//          addi a0, a0, 4*4
    vle32.v v11, (a0)//          addi a0, a0, 4*4
    vle32.v v12, (a0)//          addi a0, a0, 4*4
    vle32.v v13, (a0)//          addi a0, a0, 4*4
    vle32.v v14, (a0)//          addi a0, a0, 4*4
    vle32.v v15, (a0)//          addi a0, a0, 4*4
    vle32.v v16, (a0)//          addi a0, a0, -(4*15)*4
    // level0
    li   t4, \ZETA_INTT_0TO3_L0*4
    add  t4, t4, a1
    vle32.v v31, (t4)//      addi t4, t4, 4*4
    vle32.v v30, (t4)//      addi t4, t4, 4*4
    vle32.v v29, (t4)//      addi t4, t4, 4*4
    vle32.v v28, (t4)//      addi t4, t4, 4*4
    vle32.v v27, (t4)//      addi t4, t4, 4*4
    vle32.v v26, (t4)//      addi t4, t4, 4*4
    vle32.v v25, (t4)//      addi t4, t4, 4*4
    vle32.v v24, (t4)//      addi t4, t4, 4*4
    gs_bfu_vv_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v30,v31,v28,v29,v26,v27,v24,v25,\
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v0
    vle32.v v31, (t4)//      addi t4, t4, 4*4
    vle32.v v30, (t4)//      addi t4, t4, 4*4
    vle32.v v29, (t4)//      addi t4, t4, 4*4
    vle32.v v28, (t4)//      addi t4, t4, 4*4
    vle32.v v27, (t4)//      addi t4, t4, 4*4
    vle32.v v26, (t4)//      addi t4, t4, 4*4
    vle32.v v25, (t4)//      addi t4, t4, 4*4
    vle32.v v24, (t4)
    gs_bfu_vv_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v30,v31,v28,v29,v26,v27,v24,v25,\
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v0
    // shuffle1 for level1
    li   t4, _MASK_1010*4
    add  t4, t4, a1
    vle32.v v0,  (t4)
    li   t4, _MASK_1032*4
    add  t4, t4, a1
    vle32.v v31, (t4)
    shuffle1_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31
    shuffle1_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31
    // level1
    li   t4, \ZETA_INTT_0TO3_L1*4
    add  t4, t4, a1
    vle32.v v31, (t4)//      addi t4, t4, 4*4
    vle32.v v30, (t4)//      addi t4, t4, 4*4
    vle32.v v29, (t4)//      addi t4, t4, 4*4
    vle32.v v28, (t4)//      addi t4, t4, 4*4
    vle32.v v27, (t4)//      addi t4, t4, 4*4
    vle32.v v26, (t4)//      addi t4, t4, 4*4
    vle32.v v25, (t4)//      addi t4, t4, 4*4
    vle32.v v24, (t4)//      addi t4, t4, 4*4
    gs_bfu_vv_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v30,v31,v28,v29,v26,v27,v24,v25,\
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v0
    vle32.v v31, (t4)//      addi t4, t4, 4*4
    vle32.v v30, (t4)//      addi t4, t4, 4*4
    vle32.v v29, (t4)//      addi t4, t4, 4*4
    vle32.v v28, (t4)//      addi t4, t4, 4*4
    vle32.v v27, (t4)//      addi t4, t4, 4*4
    vle32.v v26, (t4)//      addi t4, t4, 4*4
    vle32.v v25, (t4)//      addi t4, t4, 4*4
    vle32.v v24, (t4)
    gs_bfu_vv_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v30,v31,v28,v29,v26,v27,v24,v25,\
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v0
    // shuffle2 for level2
    li   t4, _MASK_1100*4
    add  t4, t4, a1
    vle32.v v0,  (t4)
    li   t4, _MASK_0101*4
    add  t4, t4, a1
    vle32.v v31, (t4)
    li   t4, _MASK_2323*4
    add  t4, t4, a1
    vle32.v v30, (t4)
    shuffle2_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    shuffle2_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    // level2
    li   a4, \ZETA_INTT_0TO3_L2*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    gs_bfu_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24
    lw   t2, (8+0)*4(a4)
    lw   t1, (8+1)*4(a4)
    lw   t4, (8+2)*4(a4)
    lw   t3, (8+3)*4(a4)
    lw   t6, (8+4)*4(a4)
    lw   t5, (8+5)*4(a4)
    lw   a6, (8+6)*4(a4)
    lw   a5, (8+7)*4(a4)
    gs_bfu_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24
    // level3
    li   a4, \ZETA_INTT_0TO3_L3*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    gs_bfu_x8 \
        v1, v3, v2, v4, v5, v7, v6, v8, \
        v9, v11,v10,v12,v13,v15,v14,v16,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v25,v26,v27,v28,v29,v30,v31,v0
    vse32.v v1,  (a0)//          addi a0, a0, 4*4
    vse32.v v2,  (a0)//          addi a0, a0, 4*4
    vse32.v v3,  (a0)//          addi a0, a0, 4*4
    vse32.v v4,  (a0)//          addi a0, a0, 4*4
    vse32.v v5,  (a0)//          addi a0, a0, 4*4
    vse32.v v6,  (a0)//          addi a0, a0, 4*4
    vse32.v v7,  (a0)//          addi a0, a0, 4*4
    vse32.v v8,  (a0)//          addi a0, a0, 4*4
    vse32.v v9,  (a0)//          addi a0, a0, 4*4
    vse32.v v10, (a0)//          addi a0, a0, 4*4
    vse32.v v11, (a0)//          addi a0, a0, 4*4
    vse32.v v12, (a0)//          addi a0, a0, 4*4
    vse32.v v13, (a0)//          addi a0, a0, 4*4
    vse32.v v14, (a0)//          addi a0, a0, 4*4
    vse32.v v15, (a0)//          addi a0, a0, 4*4
    vse32.v v16, (a0)//          addi a0, a0, -(64*\off+4*15)*4
.endm

.macro intt_8l_level4to7_rvv off
    addi a0, a0, (4*\off)*4
    vle32.v v1,  (a0)//          addi a0, a0, 16*4
    vle32.v v2,  (a0)//          addi a0, a0, 16*4
    vle32.v v3,  (a0)//          addi a0, a0, 16*4
    vle32.v v4,  (a0)//          addi a0, a0, 16*4
    vle32.v v5,  (a0)//          addi a0, a0, 16*4
    vle32.v v6,  (a0)//          addi a0, a0, 16*4
    vle32.v v7,  (a0)//          addi a0, a0, 16*4
    vle32.v v8,  (a0)//          addi a0, a0, 16*4
    vle32.v v9,  (a0)//          addi a0, a0, 16*4
    vle32.v v10, (a0)//          addi a0, a0, 16*4
    vle32.v v11, (a0)//          addi a0, a0, 16*4
    vle32.v v12, (a0)//          addi a0, a0, 16*4
    vle32.v v13, (a0)//          addi a0, a0, 16*4
    vle32.v v14, (a0)//          addi a0, a0, 16*4
    vle32.v v15, (a0)//          addi a0, a0, 16*4
    vle32.v v16, (a0)//          addi a0, a0, -(16*15)*4
    // level4
    li   a4, _ZETA_EXP_INTT_4TO7_L4*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    gs_bfu_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24
    lw   t2, (8+0)*4(a4)
    lw   t1, (8+1)*4(a4)
    lw   t4, (8+2)*4(a4)
    lw   t3, (8+3)*4(a4)
    lw   t6, (8+4)*4(a4)
    lw   t5, (8+5)*4(a4)
    lw   a6, (8+6)*4(a4)
    lw   a5, (8+7)*4(a4)
    gs_bfu_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        t1, t2, t3, t4, t5, t6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24
    // level5
    li   a4, _ZETA_EXP_INTT_4TO7_L5*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    lw   t6, 4*4(a4)
    lw   t5, 5*4(a4)
    lw   a6, 6*4(a4)
    lw   a5, 7*4(a4)
    gs_bfu_x8 \
        v1, v3, v2, v4, v5, v7, v6, v8, \
        v9, v11,v10,v12,v13,v15,v14,v16,\
        t1, t2, t1, t2, t3, t4, t3, t4, \
        t5, t6, t5, t6, a5, a6, a5, a6, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v25,v26,v27,v28,v29,v30,v31,v0
    // level6
    li   a4, _ZETA_EXP_INTT_4TO7_L6*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    lw   t4, 2*4(a4)
    lw   t3, 3*4(a4)
    gs_bfu_x8 \
        v1, v5, v2, v6, v3, v7, v4, v8, \
        v9, v13,v10,v14,v11,v15,v12,v16,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t3, t4, t3, t4, t3, t4, t3, t4, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v25,v26,v27,v28,v29,v30,v31,v0
    // level7
    li   a4, _ZETA_EXP_INTT_4TO7_L7*4
    add  a4, a4, a1
    lw   t2, 0*4(a4)
    lw   t1, 1*4(a4)
    gs_bfu_x8 \
        v1, v9, v2, v10,v3, v11,v4, v12,\
        v5, v13,v6, v14,v7, v15,v8, v16,\
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t1, t2, t1, t2, t1, t2, t1, t2, \
        t0, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v25,v26,v27,v28,v29,v30,v31,v0
    li  t2, inv256
    li  t3, inv256qinv
    tomont_x8 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        t2, t3, t0, \
        v17,v18,v19,v20,v21,v22,v23,v24
    vse32.v v1,  (a0)//          addi a0, a0, 16*4
    vse32.v v2,  (a0)//          addi a0, a0, 16*4
    vse32.v v3,  (a0)//          addi a0, a0, 16*4
    vse32.v v4,  (a0)//          addi a0, a0, 16*4
    vse32.v v5,  (a0)//          addi a0, a0, 16*4
    vse32.v v6,  (a0)//          addi a0, a0, 16*4
    vse32.v v7,  (a0)//          addi a0, a0, 16*4
    vse32.v v8,  (a0)//          addi a0, a0, 16*4
    vse32.v v9,  (a0)//          addi a0, a0, 16*4
    vse32.v v10, (a0)//          addi a0, a0, 16*4
    vse32.v v11, (a0)//          addi a0, a0, 16*4
    vse32.v v12, (a0)//          addi a0, a0, 16*4
    vse32.v v13, (a0)//          addi a0, a0, 16*4
    vse32.v v14, (a0)//          addi a0, a0, 16*4
    vse32.v v15, (a0)//          addi a0, a0, 16*4
    vse32.v v16, (a0)//          addi a0, a0, -(4*\off+16*15)*4
.endm

// q * qinv = 1 mod 2^32, used for Montgomery arithmetic
.equ q, 8380417
.equ qinv, 58728449
// inv256 = 2^64 * (1/256) mod q is used for reverting standard domain
.equ inv256, 41978
// inv256qinv <- low(inv256*qinv)
.equ inv256qinv, 4286571514

.globl ntt_8l_rvv
.align 2
ntt_8l_rvv:
    vsetivli t2, 4, e32, m1, tu, mu
    start:
    li t0, q
    ntt_8l_level0to3_rvv 0
    end:
    ntt_8l_level0to3_rvv 1

    ntt_8l_level0to3_rvv 2
    ntt_8l_level0to3_rvv 3
    ntt_8l_level4to7_rvv 0, \
        _ZETA_EXP_4TO7_P0_L4, _ZETA_EXP_4TO7_P0_L5, \
        _ZETA_EXP_4TO7_P0_L6, _ZETA_EXP_4TO7_P0_L7
    ntt_8l_level4to7_rvv 1, \
        _ZETA_EXP_4TO7_P1_L4, _ZETA_EXP_4TO7_P1_L5, \
        _ZETA_EXP_4TO7_P1_L6, _ZETA_EXP_4TO7_P1_L7
    ntt_8l_level4to7_rvv 2, \
        _ZETA_EXP_4TO7_P2_L4, _ZETA_EXP_4TO7_P2_L5, \
        _ZETA_EXP_4TO7_P2_L6, _ZETA_EXP_4TO7_P2_L7
    ntt_8l_level4to7_rvv 3, \
        _ZETA_EXP_4TO7_P3_L4, _ZETA_EXP_4TO7_P3_L5, \
        _ZETA_EXP_4TO7_P3_L6, _ZETA_EXP_4TO7_P3_L7

ret

.globl intt_8l_rvv
.align 2
intt_8l_rvv:
    vsetivli t2, 4, e32, m1, tu, mu
    li t0, q
    intt_8l_level0to3_rvv 0, \
        _ZETA_EXP_INTT_0TO3_P0_L0, _ZETA_EXP_INTT_0TO3_P0_L1, \
        _ZETA_EXP_INTT_0TO3_P0_L2, _ZETA_EXP_INTT_0TO3_P0_L3
    intt_8l_level0to3_rvv 1, \
        _ZETA_EXP_INTT_0TO3_P1_L0, _ZETA_EXP_INTT_0TO3_P1_L1, \
        _ZETA_EXP_INTT_0TO3_P1_L2, _ZETA_EXP_INTT_0TO3_P1_L3
    intt_8l_level0to3_rvv 2, \
        _ZETA_EXP_INTT_0TO3_P2_L0, _ZETA_EXP_INTT_0TO3_P2_L1, \
        _ZETA_EXP_INTT_0TO3_P2_L2, _ZETA_EXP_INTT_0TO3_P2_L3
    intt_8l_level0to3_rvv 3, \
        _ZETA_EXP_INTT_0TO3_P3_L0, _ZETA_EXP_INTT_0TO3_P3_L1, \
        _ZETA_EXP_INTT_0TO3_P3_L2, _ZETA_EXP_INTT_0TO3_P3_L3
    intt_8l_level4to7_rvv 0
    intt_8l_level4to7_rvv 1
    intt_8l_level4to7_rvv 2
    intt_8l_level4to7_rvv 3
ret

.globl poly_basemul_8l_rvv
.align 2
poly_basemul_8l_rvv:
    li t2, 32
    vsetvli t2, t2, e32, m8, tu, mu
    li t0, q
    li t1, qinv
    li t2, 8
poly_basemul_8l_rvv_loop:
    vle32.v v0,  (a1)//          addi a1, a1, 4*4*8
    vle32.v v8,  (a2)//          addi a2, a2, 4*4*8
    montmul_ref v16, v0, v8, t0, t1, v24
    vse32.v v16, (a0)//          addi a0, a0, 4*4*8
    addi t2, t2, -1
    bnez t2, poly_basemul_8l_rvv_loop
ret

.globl poly_basemul_acc_8l_rvv
.align 2
poly_basemul_acc_8l_rvv:
    li t2, 32
    vsetvli t2, t2, e32, m8, tu, mu
    li t0, q
    li t1, qinv
    li t2, 8
poly_basemul_acc_8l_rvv_loop:
    vle32.v v0,  (a1)//      addi a1, a1, 4*4*8
    vle32.v v8,  (a2)//      addi a2, a2, 4*4*8
    montmul_ref v16, v0, v8, t0, t1, v24
    vle32.v v24, (a0)
    vadd.vv v24, v24, v16
    vse32.v v24, (a0)//      addi a0, a0, 4*4*8
    addi t2, t2, -1
    bnez t2, poly_basemul_acc_8l_rvv_loop
ret

.globl ntt2normal_order_8l_rvv
.align 2
ntt2normal_order_8l_rvv:
    vsetivli t2, 4, e32, m1, tu, mu
    // for vgather
    li   t4, _MASK_0101*4
    add  t4, t4, a1
    vle32.v v31, (t4)
    li   t4, _MASK_2323*4
    add  t4, t4, a1
    vle32.v v30, (t4)
    li   t4, _MASK_1032*4
    add  t4, t4, a1
    vle32.v v29, (t4)
    // for vmerge
    li   t4, _MASK_1100*4
    add  t4, t4, a1
    vle32.v v28,  (t4)
    li   t4, _MASK_1010*4
    add  t4, t4, a1
    vle32.v v27,  (t4)
    li a2, 4
ntt2normal_order_8l_rvv_loop:
    vle32.v v1,  (a0)//          addi a0, a0, 4*4
    vle32.v v2,  (a0)//          addi a0, a0, 4*4
    vle32.v v3,  (a0)//          addi a0, a0, 4*4
    vle32.v v4,  (a0)//          addi a0, a0, 4*4
    vle32.v v5,  (a0)//          addi a0, a0, 4*4
    vle32.v v6,  (a0)//          addi a0, a0, 4*4
    vle32.v v7,  (a0)//          addi a0, a0, 4*4
    vle32.v v8,  (a0)//          addi a0, a0, 4*4
    vle32.v v9,  (a0)//          addi a0, a0, 4*4
    vle32.v v10, (a0)//          addi a0, a0, 4*4
    vle32.v v11, (a0)//          addi a0, a0, 4*4
    vle32.v v12, (a0)//          addi a0, a0, 4*4
    vle32.v v13, (a0)//          addi a0, a0, 4*4
    vle32.v v14, (a0)//          addi a0, a0, 4*4
    vle32.v v15, (a0)//          addi a0, a0, 4*4
    vle32.v v16, (a0)//          addi a0, a0, -(4*15)*4
    vmv.v.v v0, v27
    shuffle1_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v29
    shuffle1_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v29
    vmv.v.v v0, v28
    shuffle2_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    shuffle2_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    vse32.v v1,  (a0)//          addi a0, a0, 4*4
    vse32.v v2,  (a0)//          addi a0, a0, 4*4
    vse32.v v3,  (a0)//          addi a0, a0, 4*4
    vse32.v v4,  (a0)//          addi a0, a0, 4*4
    vse32.v v5,  (a0)//          addi a0, a0, 4*4
    vse32.v v6,  (a0)//          addi a0, a0, 4*4
    vse32.v v7,  (a0)//          addi a0, a0, 4*4
    vse32.v v8,  (a0)//          addi a0, a0, 4*4
    vse32.v v9,  (a0)//          addi a0, a0, 4*4
    vse32.v v10, (a0)//          addi a0, a0, 4*4
    vse32.v v11, (a0)//          addi a0, a0, 4*4
    vse32.v v12, (a0)//          addi a0, a0, 4*4
    vse32.v v13, (a0)//          addi a0, a0, 4*4
    vse32.v v14, (a0)//          addi a0, a0, 4*4
    vse32.v v15, (a0)//          addi a0, a0, 4*4
    vse32.v v16, (a0)//          addi a0, a0, 4*4
    addi a2, a2, -1
    bnez a2, ntt2normal_order_8l_rvv_loop
ret

.globl normal2ntt_order_8l_rvv
.align 2
normal2ntt_order_8l_rvv:
    vsetivli t2, 4, e32, m1, tu, mu
    // for vgather
    li   t4, _MASK_0101*4
    add  t4, t4, a1
    vle32.v v31, (t4)
    li   t4, _MASK_2323*4
    add  t4, t4, a1
    vle32.v v30, (t4)
    li   t4, _MASK_1032*4
    add  t4, t4, a1
    vle32.v v29, (t4)
    // for vmerge
    li   t4, _MASK_1100*4
    add  t4, t4, a1
    vle32.v v28,  (t4)
    li   t4, _MASK_1010*4
    add  t4, t4, a1
    vle32.v v27,  (t4)
    li a2, 4
normal2ntt_order_8l_rvv_loop:
    vle32.v v1,  (a0)//          addi a0, a0, 4*4
    vle32.v v2,  (a0)//          addi a0, a0, 4*4
    vle32.v v3,  (a0)//          addi a0, a0, 4*4
    vle32.v v4,  (a0)//          addi a0, a0, 4*4
    vle32.v v5,  (a0)//          addi a0, a0, 4*4
    vle32.v v6,  (a0)//          addi a0, a0, 4*4
    vle32.v v7,  (a0)//          addi a0, a0, 4*4
    vle32.v v8,  (a0)//          addi a0, a0, 4*4
    vle32.v v9,  (a0)//          addi a0, a0, 4*4
    vle32.v v10, (a0)//          addi a0, a0, 4*4
    vle32.v v11, (a0)//          addi a0, a0, 4*4
    vle32.v v12, (a0)//          addi a0, a0, 4*4
    vle32.v v13, (a0)//          addi a0, a0, 4*4
    vle32.v v14, (a0)//          addi a0, a0, 4*4
    vle32.v v15, (a0)//          addi a0, a0, 4*4
    vle32.v v16, (a0)//          addi a0, a0, -(4*15)*4
    vmv.v.v v0, v28
    shuffle2_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    shuffle2_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v31,v30
    vmv.v.v v0, v27
    shuffle1_x4 \
        v1, v2, v3, v4, v5, v6, v7, v8, \
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v29
    shuffle1_x4 \
        v9, v10,v11,v12,v13,v14,v15,v16,\
        v17,v18,v19,v20,v21,v22,v23,v24,\
        v29
    vse32.v v1,  (a0)//          addi a0, a0, 4*4
    vse32.v v2,  (a0)//          addi a0, a0, 4*4
    vse32.v v3,  (a0)//          addi a0, a0, 4*4
    vse32.v v4,  (a0)//          addi a0, a0, 4*4
    vse32.v v5,  (a0)//          addi a0, a0, 4*4
    vse32.v v6,  (a0)//          addi a0, a0, 4*4
    vse32.v v7,  (a0)//          addi a0, a0, 4*4
    vse32.v v8,  (a0)//          addi a0, a0, 4*4
    vse32.v v9,  (a0)//          addi a0, a0, 4*4
    vse32.v v10, (a0)//          addi a0, a0, 4*4
    vse32.v v11, (a0)//          addi a0, a0, 4*4
    vse32.v v12, (a0)//          addi a0, a0, 4*4
    vse32.v v13, (a0)//          addi a0, a0, 4*4
    vse32.v v14, (a0)//          addi a0, a0, 4*4
    vse32.v v15, (a0)//          addi a0, a0, 4*4
    vse32.v v16, (a0)//          addi a0, a0, 4*4
    addi a2, a2, -1
    bnez a2, normal2ntt_order_8l_rvv_loop
ret

.globl poly_reduce_rvv
.align 2
poly_reduce_rvv:
    li t2, 32
    vsetvli t2, t2, e32, m8, tu, mu
    li a1, 4194304  // 1<<22
    li a2, q
    li a3, 4
    addi a4, a0, 0
poly_reduce_rvv_loop:
    vle32.v v0,  (a0)//          addi a0, a0, 4*4*8
    vle32.v v8,  (a0)//          addi a0, a0, 4*4*8
    vadd.vx v16, v0,  a1
    vadd.vx v24, v8,  a1
    vsra.vi v16, v16, 23
    vsra.vi v24, v24, 23
    vmul.vx v16, v16, a2
    vmul.vx v24, v24, a2
    vsub.vv v0,  v0, v16
    vsub.vv v8,  v8, v24
    vse32.v v0,  (a4)//          addi a4, a4, 4*4*8
    vse32.v v8,  (a4)//          addi a4, a4, 4*4*8
    addi a3, a3, -1
    bnez a3, poly_reduce_rvv_loop
ret
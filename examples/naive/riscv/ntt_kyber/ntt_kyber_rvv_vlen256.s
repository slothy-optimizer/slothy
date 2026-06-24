#include "consts_vlen256.h"

// shuffle8
# a[0-7,8-15],a[16-23,24-31] -> a[0-7,16-23],a[8-15,24-31]
# vm0/vm1: _MASK_0_7x2/_MASK_8_15x2
# v0: _MASK_V0_1x8_0x8
// shuffle4
# a[0-7,16-23],a[8-15,24-31] ->
# a[0-3,8-11,16-19,24-27],a[4-7,12-15,20-23,28-31]
# vm0/vm1: _MASK_0_3x2_8_11x2/_MASK_4_7x2_12_15x2
# v0: _MASK_V0_1x4_0x4_1x4_0x4
// shuffle2
# a[0-3,8-11,16-19,24-27],a[4-7,12-15,20-23,28-31] ->
# a[0,1,4,5,...],a[2,3,6,7,...]
# vm0/vm1: _MASK_01014545/_MASK_23236767
# v0: _MASK_V0_1100x4
// shuffle1
# a[0,1,4,5,...],a[2,3,6,7,...] ->
# a[0,2,4,6,...],a[1,3,5,7,...]
# vm0/vm1: _MASK_10325476
# v0: _MASK_V0_10x8
.macro shuffle_x2 in0_0, in0_1, in1_0, in1_1, \
        tm0_0, tm0_1, tm1_0, tm1_1, vm0, vm1
    vrgather.vv \tm0_0, \in0_1, \vm0;       vrgather.vv \tm0_1, \in0_0, \vm1
    vrgather.vv \tm1_0, \in1_1, \vm0;       vrgather.vv \tm1_1, \in1_0, \vm1
    vmerge.vvm  \in0_0, \tm0_0, \in0_0, v0; vmerge.vvm  \in0_1, \in0_1, \tm0_1, v0
    vmerge.vvm  \in1_0, \tm1_0, \in1_0, v0; vmerge.vvm  \in1_1, \in1_1, \tm1_1, v0
.endm

.macro shuffle_o_x2 ou0_0, ou0_1, ou1_0, ou1_1, \
        in0_0, in0_1, in1_0, in1_1, vm0, vm1
    vrgather.vv \ou0_0, \in0_1, \vm0;       vrgather.vv \ou1_0, \in1_1, \vm0
    vrgather.vv \ou0_1, \in0_0, \vm1;       vrgather.vv \ou1_1, \in1_0, \vm1
    vmerge.vvm  \ou0_0, \ou0_0, \in0_0, v0; vmerge.vvm  \ou1_0, \ou1_0, \in1_0, v0
    vmerge.vvm  \ou0_1, \in0_1, \ou0_1, v0; vmerge.vvm  \ou1_1, \in1_1, \ou1_1, v0
.endm

.macro barrettRdc in, vt0, const_v, const_q
    vmulh.vx \vt0, \in, \const_v
    vssra.vi \vt0, \vt0, 10
    vmul.vx  \vt0, \vt0, \const_q
    vsub.vv  \in,  \in, \vt0
.endm

.macro barrettRdcX2 in0, in1, vt0, vt1, const_v, const_q
    vmulh.vx \vt0, \in0, \const_v;  vmulh.vx \vt1, \in1, \const_v
    vssra.vi \vt0, \vt0, 10;        vssra.vi \vt1, \vt1, 10
    vmul.vx  \vt0, \vt0, \const_q;  vmul.vx  \vt1, \vt1, \const_q
    vsub.vv  \in0, \in0, \vt0;      vsub.vv  \in1, \in1, \vt1
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
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0;   vmul.vx  \vt1_0, \va1_1, \xzetaqinv1
    vmulh.vx \vt0_1, \va0_1, \xzeta0;       vmulh.vx \vt1_1, \va1_1, \xzeta1
    vmulh.vx \vt0_0, \vt0_0, \xq;           vmulh.vx \vt1_0, \vt1_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0;        vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \va0_1, \va0_0, \vt0_0;        vsub.vv  \va1_1, \va1_0, \vt1_0
    vadd.vv  \va0_0, \va0_0, \vt0_0;        vadd.vv  \va1_0, \va1_0, \vt1_0
.endm

.macro ct_bfu_vx_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vmul.vx  \vt0_0, \va0_1, \xzetaqinv0;   vmul.vx  \vt1_0, \va1_1, \xzetaqinv1
    vmul.vx  \vt2_0, \va2_1, \xzetaqinv2;   vmul.vx  \vt3_0, \va3_1, \xzetaqinv3
    vmulh.vx \vt0_1, \va0_1, \xzeta0;       vmulh.vx \vt1_1, \va1_1, \xzeta1
    vmulh.vx \vt2_1, \va2_1, \xzeta2;       vmulh.vx \vt3_1, \va3_1, \xzeta3
    vmulh.vx \vt0_0, \vt0_0, \xq;           vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq;           vmulh.vx \vt3_0, \vt3_0, \xq
    vsub.vv  \vt0_0, \vt0_1, \vt0_0;        vsub.vv  \vt1_0, \vt1_1, \vt1_0
    vsub.vv  \vt2_0, \vt2_1, \vt2_0;        vsub.vv  \vt3_0, \vt3_1, \vt3_0
    vsub.vv  \va0_1, \va0_0, \vt0_0;        vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0;        vsub.vv  \va3_1, \va3_0, \vt3_0
    vadd.vv  \va0_0, \va0_0, \vt0_0;        vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0;        vadd.vv  \va3_0, \va3_0, \vt3_0
.endm

.macro ct_bfu_vv_o_x4 \
        vo0_0, vo0_1, vo1_0, vo1_1, vo2_0, vo2_1, vo3_0, vo3_1, \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, xq
    vmul.vv  \vo0_0, \va0_1, \vzetaqinv0;   vmul.vv  \vo1_0, \va1_1, \vzetaqinv1
    vmul.vv  \vo2_0, \va2_1, \vzetaqinv2;   vmul.vv  \vo3_0, \va3_1, \vzetaqinv3
    vmulh.vv \va0_1, \va0_1, \vzeta0;       vmulh.vv \va1_1, \va1_1, \vzeta1
    vmulh.vv \va2_1, \va2_1, \vzeta2;       vmulh.vv \va3_1, \va3_1, \vzeta3
    vmulh.vx \vo0_0, \vo0_0, \xq;           vmulh.vx \vo1_0, \vo1_0, \xq
    vmulh.vx \vo2_0, \vo2_0, \xq;           vmulh.vx \vo3_0, \vo3_0, \xq
    vsub.vv  \vo0_0, \va0_1, \vo0_0;        vsub.vv  \vo1_0, \va1_1, \vo1_0
    vsub.vv  \vo2_0, \va2_1, \vo2_0;        vsub.vv  \vo3_0, \va3_1, \vo3_0
    vsub.vv  \vo0_1, \va0_0, \vo0_0;        vsub.vv  \vo1_1, \va1_0, \vo1_0
    vsub.vv  \vo2_1, \va2_0, \vo2_0;        vsub.vv  \vo3_1, \va3_0, \vo3_0
    vadd.vv  \vo0_0, \va0_0, \vo0_0;        vadd.vv  \vo1_0, \va1_0, \vo1_0
    vadd.vv  \vo2_0, \va2_0, \vo2_0;        vadd.vv  \vo3_0, \va3_0, \vo3_0
.endm

.macro ct_bfu_vv_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, xq, \
        vt0_0, vt1_0, vt2_0, vt3_0
    vmul.vv  \vt0_0, \va0_1, \vzetaqinv0;   vmul.vv  \vt1_0, \va1_1, \vzetaqinv1
    vmul.vv  \vt2_0, \va2_1, \vzetaqinv2;   vmul.vv  \vt3_0, \va3_1, \vzetaqinv3
    vmulh.vv \va0_1, \va0_1, \vzeta0;       vmulh.vv \va1_1, \va1_1, \vzeta1
    vmulh.vv \va2_1, \va2_1, \vzeta2;       vmulh.vv \va3_1, \va3_1, \vzeta3
    vmulh.vx \vt0_0, \vt0_0, \xq;           vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq;           vmulh.vx \vt3_0, \vt3_0, \xq
    vsub.vv  \vt0_0, \va0_1, \vt0_0;        vsub.vv  \vt1_0, \va1_1, \vt1_0
    vsub.vv  \vt2_0, \va2_1, \vt2_0;        vsub.vv  \vt3_0, \va3_1, \vt3_0
    vsub.vv  \va0_1, \va0_0, \vt0_0;        vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0;        vsub.vv  \va3_1, \va3_0, \vt3_0
    vadd.vv  \va0_0, \va0_0, \vt0_0;        vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0;        vadd.vv  \va3_0, \va3_0, \vt3_0
.endm

.macro ct_bfu_vv_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        vzeta4, vzetaqinv4, vzeta5, vzetaqinv5, vzeta6, vzetaqinv6, vzeta7, vzetaqinv7, xq, \
        vt0_0, vt1_0, vt2_0, vt3_0, vt4_0, vt5_0, vt6_0, vt7_0 
    vmul.vv  \vt0_0, \va0_1, \vzetaqinv0;   vmul.vv  \vt1_0, \va1_1, \vzetaqinv1
    vmul.vv  \vt2_0, \va2_1, \vzetaqinv2;   vmul.vv  \vt3_0, \va3_1, \vzetaqinv3
    vmul.vv  \vt4_0, \va4_1, \vzetaqinv4;   vmul.vv  \vt5_0, \va5_1, \vzetaqinv5
    vmul.vv  \vt6_0, \va6_1, \vzetaqinv6;   vmul.vv  \vt7_0, \va7_1, \vzetaqinv7
    vmulh.vv \va0_1, \va0_1, \vzeta0;       vmulh.vv \va1_1, \va1_1, \vzeta1
    vmulh.vv \va2_1, \va2_1, \vzeta2;       vmulh.vv \va3_1, \va3_1, \vzeta3
    vmulh.vv \va4_1, \va4_1, \vzeta4;       vmulh.vv \va5_1, \va5_1, \vzeta5
    vmulh.vv \va6_1, \va6_1, \vzeta6;       vmulh.vv \va7_1, \va7_1, \vzeta7
    vmulh.vx \vt0_0, \vt0_0, \xq;           vmulh.vx \vt1_0, \vt1_0, \xq
    vmulh.vx \vt2_0, \vt2_0, \xq;           vmulh.vx \vt3_0, \vt3_0, \xq
    vmulh.vx \vt4_0, \vt4_0, \xq;           vmulh.vx \vt5_0, \vt5_0, \xq
    vmulh.vx \vt6_0, \vt6_0, \xq;           vmulh.vx \vt7_0, \vt7_0, \xq
    vsub.vv  \vt0_0, \va0_1, \vt0_0;        vsub.vv  \vt1_0, \va1_1, \vt1_0
    vsub.vv  \vt2_0, \va2_1, \vt2_0;        vsub.vv  \vt3_0, \va3_1, \vt3_0
    vsub.vv  \vt4_0, \va4_1, \vt4_0;        vsub.vv  \vt5_0, \va5_1, \vt5_0
    vsub.vv  \vt6_0, \va6_1, \vt6_0;        vsub.vv  \vt7_0, \va7_1, \vt7_0
    vsub.vv  \va0_1, \va0_0, \vt0_0;        vsub.vv  \va1_1, \va1_0, \vt1_0
    vsub.vv  \va2_1, \va2_0, \vt2_0;        vsub.vv  \va3_1, \va3_0, \vt3_0
    vsub.vv  \va4_1, \va4_0, \vt4_0;        vsub.vv  \va5_1, \va5_0, \vt5_0
    vsub.vv  \va6_1, \va6_0, \vt6_0;        vsub.vv  \va7_1, \va7_0, \vt7_0
    vadd.vv  \va0_0, \va0_0, \vt0_0;        vadd.vv  \va1_0, \va1_0, \vt1_0
    vadd.vv  \va2_0, \va2_0, \vt2_0;        vadd.vv  \va3_0, \va3_0, \vt3_0
    vadd.vv  \va4_0, \va4_0, \vt4_0;        vadd.vv  \va5_0, \va5_0, \vt5_0
    vadd.vv  \va6_0, \va6_0, \vt6_0;        vadd.vv  \va7_0, \va7_0, \vt7_0
.endm

.macro gs_bfu_vx_x4 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, xq, \
        vt0_0, vt0_1, vt1_0, vt1_1, vt2_0, vt2_1, vt3_0, vt3_1
    vsub.vv  \vt0_0, \va0_0, \va0_1;        vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1;        vsub.vv  \vt3_0, \va3_0, \va3_1
    vadd.vv  \va0_0, \va0_0, \va0_1;        vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1;        vadd.vv  \va3_0, \va3_0, \va3_1
    vmul.vx  \va0_1, \vt0_0, \xzetaqinv0;   vmul.vx  \va1_1, \vt1_0, \xzetaqinv1
    vmul.vx  \va2_1, \vt2_0, \xzetaqinv2;   vmul.vx  \va3_1, \vt3_0, \xzetaqinv3
    vmulh.vx \vt0_1, \vt0_0, \xzeta0;       vmulh.vx \vt1_1, \vt1_0, \xzeta1
    vmulh.vx \vt2_1, \vt2_0, \xzeta2;       vmulh.vx \vt3_1, \vt3_0, \xzeta3
    vmulh.vx \va0_1, \va0_1, \xq;           vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq;           vmulh.vx \va3_1, \va3_1, \xq
    vsub.vv  \va0_1, \vt0_1, \va0_1;        vsub.vv  \va1_1, \vt1_1, \va1_1
    vsub.vv  \va2_1, \vt2_1, \va2_1;        vsub.vv  \va3_1, \vt3_1, \va3_1
.endm

.macro gs_bfu_vx_o_x4 \
        vo0_0, vo0_1, vo1_0, vo1_1, vo2_0, vo2_1, vo3_0, vo3_1, \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        xzeta0, xzetaqinv0, xzeta1, xzetaqinv1, \
        xzeta2, xzetaqinv2, xzeta3, xzetaqinv3, xq
    vsub.vv  \vo0_1, \va0_0, \va0_1;        vsub.vv  \vo1_1, \va1_0, \va1_1
    vsub.vv  \vo2_1, \va2_0, \va2_1;        vsub.vv  \vo3_1, \va3_0, \va3_1
    vadd.vv  \vo0_0, \va0_0, \va0_1;        vadd.vv  \vo1_0, \va1_0, \va1_1
    vadd.vv  \vo2_0, \va2_0, \va2_1;        vadd.vv  \vo3_0, \va3_0, \va3_1
    vmul.vx  \va0_1, \vo0_1, \xzetaqinv0;   vmul.vx  \va1_1, \vo1_1, \xzetaqinv1
    vmul.vx  \va2_1, \vo2_1, \xzetaqinv2;   vmul.vx  \va3_1, \vo3_1, \xzetaqinv3
    vmulh.vx \vo0_1, \vo0_1, \xzeta0;       vmulh.vx \vo1_1, \vo1_1, \xzeta1
    vmulh.vx \vo2_1, \vo2_1, \xzeta2;       vmulh.vx \vo3_1, \vo3_1, \xzeta3
    vmulh.vx \va0_1, \va0_1, \xq;           vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq;           vmulh.vx \va3_1, \va3_1, \xq
    vsub.vv  \vo0_1, \vo0_1, \va0_1;        vsub.vv  \vo1_1, \vo1_1, \va1_1
    vsub.vv  \vo2_1, \vo2_1, \va2_1;        vsub.vv  \vo3_1, \vo3_1, \va3_1
.endm

.macro gs_bfu_vv_x8 \
        va0_0, va0_1, va1_0, va1_1, va2_0, va2_1, va3_0, va3_1, \
        va4_0, va4_1, va5_0, va5_1, va6_0, va6_1, va7_0, va7_1, \
        vzeta0, vzetaqinv0, vzeta1, vzetaqinv1, vzeta2, vzetaqinv2, vzeta3, vzetaqinv3, \
        vzeta4, vzetaqinv4, vzeta5, vzetaqinv5, vzeta6, vzetaqinv6, vzeta7, vzetaqinv7, xq, \
        vt0_0, vt1_0, vt2_0, vt3_0, vt4_0, vt5_0, vt6_0, vt7_0
    vsub.vv  \vt0_0, \va0_0, \va0_1;        vsub.vv  \vt1_0, \va1_0, \va1_1
    vsub.vv  \vt2_0, \va2_0, \va2_1;        vsub.vv  \vt3_0, \va3_0, \va3_1
    vsub.vv  \vt4_0, \va4_0, \va4_1;        vsub.vv  \vt5_0, \va5_0, \va5_1
    vsub.vv  \vt6_0, \va6_0, \va6_1;        vsub.vv  \vt7_0, \va7_0, \va7_1
    vadd.vv  \va0_0, \va0_0, \va0_1;        vadd.vv  \va1_0, \va1_0, \va1_1
    vadd.vv  \va2_0, \va2_0, \va2_1;        vadd.vv  \va3_0, \va3_0, \va3_1
    vadd.vv  \va4_0, \va4_0, \va4_1;        vadd.vv  \va5_0, \va5_0, \va5_1
    vadd.vv  \va6_0, \va6_0, \va6_1;        vadd.vv  \va7_0, \va7_0, \va7_1
    vmul.vv  \va0_1, \vt0_0, \vzetaqinv0;   vmul.vv  \va1_1, \vt1_0, \vzetaqinv1
    vmul.vv  \va2_1, \vt2_0, \vzetaqinv2;   vmul.vv  \va3_1, \vt3_0, \vzetaqinv3
    vmul.vv  \va4_1, \vt4_0, \vzetaqinv4;   vmul.vv  \va5_1, \vt5_0, \vzetaqinv5
    vmul.vv  \va6_1, \vt6_0, \vzetaqinv6;   vmul.vv  \va7_1, \vt7_0, \vzetaqinv7
    vmulh.vv \vt0_0, \vt0_0, \vzeta0;       vmulh.vv \vt1_0, \vt1_0, \vzeta1
    vmulh.vv \vt2_0, \vt2_0, \vzeta2;       vmulh.vv \vt3_0, \vt3_0, \vzeta3
    vmulh.vv \vt4_0, \vt4_0, \vzeta4;       vmulh.vv \vt5_0, \vt5_0, \vzeta5
    vmulh.vv \vt6_0, \vt6_0, \vzeta6;       vmulh.vv \vt7_0, \vt7_0, \vzeta7
    vmulh.vx \va0_1, \va0_1, \xq;           vmulh.vx \va1_1, \va1_1, \xq
    vmulh.vx \va2_1, \va2_1, \xq;           vmulh.vx \va3_1, \va3_1, \xq
    vmulh.vx \va4_1, \va4_1, \xq;           vmulh.vx \va5_1, \va5_1, \xq
    vmulh.vx \va6_1, \va6_1, \xq;           vmulh.vx \va7_1, \va7_1, \xq
    vsub.vv  \va0_1, \vt0_0, \va0_1;        vsub.vv  \va1_1, \vt1_0, \va1_1
    vsub.vv  \va2_1, \vt2_0, \va2_1;        vsub.vv  \va3_1, \vt3_0, \va3_1
    vsub.vv  \va4_1, \vt4_0, \va4_1;        vsub.vv  \va5_1, \vt5_0, \va5_1
    vsub.vv  \va6_1, \vt6_0, \va6_1;        vsub.vv  \va7_1, \vt7_0, \va7_1
.endm

.macro montmul_const vr0, va0, xzeta, xzetaqinv, xq, vt0
    vmul.vx  \vr0, \va0, \xzetaqinv;    vmulh.vx \vt0, \va0, \xzeta
    vmulh.vx \vr0, \vr0, \xq;           vsub.vv  \vr0, \vt0, \vr0
.endm

.macro montmul_x4 vr0, vr1, vr2, vr3, \
        va0, va1, va2, va3, \
        vb0, vb1, vb2, vb3, \
        xq, xqinv, vt0, vt1, vt2, vt3
    vmul.vv  \vr0, \va0, \vb0;      vmul.vv  \vr1, \va1, \vb1
    vmul.vv  \vr2, \va2, \vb2;      vmul.vv  \vr3, \va3, \vb3
    vmul.vx  \vr0, \vr0, \xqinv;    vmul.vx  \vr1, \vr1, \xqinv
    vmul.vx  \vr2, \vr2, \xqinv;    vmul.vx  \vr3, \vr3, \xqinv
    vmulh.vv \vt0, \va0, \vb0;      vmulh.vv \vt1, \va1, \vb1
    vmulh.vv \vt2, \va2, \vb2;      vmulh.vv \vt3, \va3, \vb3
    vmulh.vx \vr0, \vr0, \xq;       vmulh.vx \vr1, \vr1, \xq
    vmulh.vx \vr2, \vr2, \xq;       vmulh.vx \vr3, \vr3, \xq
    vsub.vv  \vr0, \vt0, \vr0;      vsub.vv  \vr1, \vt1, \vr1
    vsub.vv  \vr2, \vt2, \vr2;      vsub.vv  \vr3, \vt3, \vr3
.endm

.macro rej_core vr0, vf0, vt0, vidx, x0xfff, xq
    li a7, 32
    vsetvli a7, a7, e8, m1, tu, mu
    vle8.v  \vf0, (a1); addi a1, a1, 24
    vrgather.vv \vt0, \vf0, \vidx
    vsetivli a7, 16, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq
    vcpop.m   t2, \vf0
    vcompress.vm \vr0, \vt0, \vf0
    vse16.v \vr0, (a0); add t2, t2, t2; add a0, a0, t2
.endm

.macro rej_core_x2 vr0, vr1, vf0, vf1, vt0, vt1, vidx, x0xfff, xq
    li a7, 32;  addi t2, a1, 24
    vsetvli a7, a7, e8, m1, tu, mu
    vle8.v \vf0, (a1); vle8.v \vf1, (t2); addi a1, a1, 48
    vrgather.vv \vt0, \vf0, \vidx;  vrgather.vv \vt1, \vf1, \vidx
    vsetivli a7, 16, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t;  vsrl.vi   \vt1, \vt1, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff;  vand.vx   \vt1, \vt1, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq;      vmsltu.vx \vf1, \vt1, \xq
    vcpop.m   t2, \vf0;             vcpop.m   t3, \vf1
    vcompress.vm \vr0, \vt0, \vf0;  vcompress.vm \vr1, \vt1, \vf1
    vse16.v \vr0, (a0)
    add t2, t2, t2; add t3, t3, t3; 
    add a0, a0, t2; vse16.v \vr1, (a0)
    add a0, a0, t3
.endm

.macro rej_core_x4 vr0, vr1, vr2, vr3, vf0, vf1, vf2, vf3, \
        vt0, vt1, vt2, vt3, vidx, x0xfff, xq
    li a7, 32;  addi t2, a1, 24; addi t3, a1, 48; addi t4, a1, 72
    vsetvli a7, a7, e8, m1, tu, mu
    vle8.v \vf0, (a1); vle8.v \vf1, (t2)
    vle8.v \vf2, (t3); vle8.v \vf3, (t4); addi a1, a1, 24*4
    vrgather.vv \vt0, \vf0, \vidx;  vrgather.vv \vt1, \vf1, \vidx
    vrgather.vv \vt2, \vf2, \vidx;  vrgather.vv \vt3, \vf3, \vidx
    vsetivli a7, 16, e16, m1, tu, mu
    vsrl.vi   \vt0, \vt0, 4, v0.t;  vsrl.vi   \vt1, \vt1, 4, v0.t
    vsrl.vi   \vt2, \vt2, 4, v0.t;  vsrl.vi   \vt3, \vt3, 4, v0.t
    vand.vx   \vt0, \vt0, \x0xfff;  vand.vx   \vt1, \vt1, \x0xfff
    vand.vx   \vt2, \vt2, \x0xfff;  vand.vx   \vt3, \vt3, \x0xfff
    vmsltu.vx \vf0, \vt0, \xq;      vmsltu.vx \vf1, \vt1, \xq
    vmsltu.vx \vf2, \vt2, \xq;      vmsltu.vx \vf3, \vt3, \xq
    vcpop.m   t2, \vf0;             vcpop.m   t3, \vf1
    vcpop.m   t4, \vf2;             vcpop.m   t5, \vf3
    vcompress.vm \vr0, \vt0, \vf0;  vcompress.vm \vr1, \vt1, \vf1
    vcompress.vm \vr2, \vt2, \vf2;  vcompress.vm \vr3, \vt3, \vf3
    vse16.v \vr0, (a0)
    add t2, t2, t2; add t3, t3, t3
    add a0, a0, t2; add t4, t4, t4
    vse16.v \vr1, (a0); add a0, a0, t3
    vse16.v \vr2, (a0); add a0, a0, t4; add t5, t5, t5
    vse16.v \vr3, (a0); add a0, a0, t5
.endm

.macro cbd2_core_x4 vf0_0, vf0_1, vf1_0, vf1_1, vf2_0, vf2_1, vf3_0, vf3_1, \
        vt0_0, vt0_1, vt0_2, vt0_3, vt1_0, vt1_1, vt1_2, vt1_3, \
        vt2_0, vt2_1, vt2_2, vt2_3, vt3_0, vt3_1, vt3_2, vt3_3, \
        vidx_low, vidx_high, x0x55, x0x33
    addi t2, a1, 32;    addi t3, a1, 32*2;  addi t4, a1, 32*3
    vle8.v \vf0_0, (a1);    vle8.v \vf1_0, (t2)
    vle8.v \vf2_0, (t3);    vle8.v \vf3_0, (t4)
    vsrl.vi \vf0_1, \vf0_0, 1;      vsrl.vi \vf1_1, \vf1_0, 1
    vsrl.vi \vf2_1, \vf2_0, 1;      vsrl.vi \vf3_1, \vf3_0, 1
    vand.vx \vf0_0, \vf0_0, \x0x55; vand.vx \vf0_1, \vf0_1, \x0x55
    vand.vx \vf1_0, \vf1_0, \x0x55; vand.vx \vf1_1, \vf1_1, \x0x55
    vand.vx \vf2_0, \vf2_0, \x0x55; vand.vx \vf2_1, \vf2_1, \x0x55
    vand.vx \vf3_0, \vf3_0, \x0x55; vand.vx \vf3_1, \vf3_1, \x0x55
    vadd.vv \vf0_0, \vf0_0, \vf0_1; vadd.vv \vf1_0, \vf1_0, \vf1_1
    vadd.vv \vf2_0, \vf2_0, \vf2_1; vadd.vv \vf3_0, \vf3_0, \vf3_1
    vsrl.vi \vf0_1, \vf0_0, 2;      vsrl.vi \vf1_1, \vf1_0, 2
    vsrl.vi \vf2_1, \vf2_0, 2;      vsrl.vi \vf3_1, \vf3_0, 2
    vand.vx \vf0_0, \vf0_0, \x0x33; vand.vx \vf1_0, \vf1_0, \x0x33
    vand.vx \vf2_0, \vf2_0, \x0x33; vand.vx \vf3_0, \vf3_0, \x0x33
    vand.vx \vf0_1, \vf0_1, \x0x33; vand.vx \vf1_1, \vf1_1, \x0x33
    vand.vx \vf2_1, \vf2_1, \x0x33; vand.vx \vf3_1, \vf3_1, \x0x33
    vadd.vx \vf0_0, \vf0_0, \x0x33; vadd.vx \vf1_0, \vf1_0, \x0x33
    vadd.vx \vf2_0, \vf2_0, \x0x33; vadd.vx \vf3_0, \vf3_0, \x0x33
    vsub.vv \vf0_0, \vf0_0, \vf0_1; vsub.vv \vf1_0, \vf1_0, \vf1_1
    vsub.vv \vf2_0, \vf2_0, \vf2_1; vsub.vv \vf3_0, \vf3_0, \vf3_1
    vsrl.vi \vf0_1, \vf0_0, 4;      vsrl.vi \vf1_1, \vf1_0, 4
    vsrl.vi \vf2_1, \vf2_0, 4;      vsrl.vi \vf3_1, \vf3_0, 4
    vand.vi \vf0_0, \vf0_0, 0xf;    vand.vi \vf1_0, \vf1_0, 0xf
    vand.vi \vf2_0, \vf2_0, 0xf;    vand.vi \vf3_0, \vf3_0, 0xf
    vadd.vi \vf0_1, \vf0_1, -3;     vadd.vi \vf1_1, \vf1_1, -3
    vadd.vi \vf2_1, \vf2_1, -3;     vadd.vi \vf3_1, \vf3_1, -3
    vadd.vi \vf0_0, \vf0_0, -3;     vadd.vi \vf1_0, \vf1_0, -3 
    vadd.vi \vf2_0, \vf2_0, -3;     vadd.vi \vf3_0, \vf3_0, -3 
    vrgather.vv \vt0_0, \vf0_0, \vidx_low;  vrgather.vv \vt0_1, \vf0_1, \vidx_low
    vrgather.vv \vt0_2, \vf0_0, \vidx_high; vrgather.vv \vt0_3, \vf0_1, \vidx_high
    vrgather.vv \vt1_0, \vf1_0, \vidx_low;  vrgather.vv \vt1_1, \vf1_1, \vidx_low
    vrgather.vv \vt1_2, \vf1_0, \vidx_high; vrgather.vv \vt1_3, \vf1_1, \vidx_high
    vrgather.vv \vt2_0, \vf2_0, \vidx_low;  vrgather.vv \vt2_1, \vf2_1, \vidx_low
    vrgather.vv \vt2_2, \vf2_0, \vidx_high; vrgather.vv \vt2_3, \vf2_1, \vidx_high
    vrgather.vv \vt3_0, \vf3_0, \vidx_low;  vrgather.vv \vt3_1, \vf3_1, \vidx_low
    vrgather.vv \vt3_2, \vf3_0, \vidx_high; vrgather.vv \vt3_3, \vf3_1, \vidx_high
    vmerge.vvm  \vf0_0, \vt0_0, \vt0_1, v0; vmerge.vvm  \vf0_1, \vt0_2, \vt0_3, v0
    vmerge.vvm  \vf1_0, \vt1_0, \vt1_1, v0; vmerge.vvm  \vf1_1, \vt1_2, \vt1_3, v0
    vmerge.vvm  \vf2_0, \vt2_0, \vt2_1, v0; vmerge.vvm  \vf2_1, \vt2_2, \vt2_3, v0
    vmerge.vvm  \vf3_0, \vt3_0, \vt3_1, v0; vmerge.vvm  \vf3_1, \vt3_2, \vt3_3, v0
    vsetvli a7, a7, e16, m2, tu, mu
    vsext.vf2 \vt0_0, \vf0_0;       vsext.vf2 \vt0_2, \vf0_1
    vsext.vf2 \vt1_0, \vf1_0;       vsext.vf2 \vt1_2, \vf1_1
    vsext.vf2 \vt2_0, \vf2_0;       vsext.vf2 \vt2_2, \vf2_1
    vsext.vf2 \vt3_0, \vf3_0;       vsext.vf2 \vt3_2, \vf3_1
    addi t2, a0, 32*2;  addi t3, a0, 32*4;  addi t4, a0, 32*6
    vse16.v \vt0_0, (a0);           vse16.v \vt0_2, (t2)
    vse16.v \vt1_0, (t3);           vse16.v \vt1_2, (t4)
    addi t2, a0, 32*8;  addi t3, a0, 32*10; addi t4, a0, 32*12; addi t5, a0, 32*14
    vse16.v \vt2_0, (t2);           vse16.v \vt2_2, (t3)
    vse16.v \vt3_0, (t4);           vse16.v \vt3_2, (t5)
.endm

.macro cbd3_core_x4 \
        vf0_0, vf0_1, vf0_2, vf0_3, vt0_0, vt0_1, \
        vf1_0, vf1_1, vf1_2, vf1_3, vt1_0, vt1_1, \
        vf2_0, vf2_1, vf2_2, vf2_3, vt2_0, vt2_1, \
        vf3_0, vf3_1, vf3_2, vf3_3, vt3_0, vt3_1, \
        vidx8_0122, vidx_low, vidx_high, \
        x0x249, x0x6DB, x0x70000
    li a7, 32
    vsetvli a7, a7, e8, m1, tu, mu
    addi t2, a1, 24;    addi t3, a1, 24*2;  addi t4, a1, 24*3
    vle8.v \vf0_1, (a1);    vle8.v \vf1_1, (t2)
    vle8.v \vf2_1, (t3);    vle8.v \vf3_1, (t4)
    addi a1, a1, 24*4
    vrgather.vv \vf0_0, \vf0_1, \vidx8_0122; vrgather.vv \vf1_0, \vf1_1, \vidx8_0122
    vrgather.vv \vf2_0, \vf2_1, \vidx8_0122; vrgather.vv \vf3_0, \vf3_1, \vidx8_0122
    vsetivli a7, 8, e32, m1, tu, mu
    vsrl.vi \vf0_1, \vf0_0, 1;      vsrl.vi \vf0_2, \vf0_0, 2
    vsrl.vi \vf1_1, \vf1_0, 1;      vsrl.vi \vf1_2, \vf1_0, 2
    vsrl.vi \vf2_1, \vf2_0, 1;      vsrl.vi \vf2_2, \vf2_0, 2
    vsrl.vi \vf3_1, \vf3_0, 1;      vsrl.vi \vf3_2, \vf3_0, 2
    vand.vx \vf0_0, \vf0_0, \x0x249; vand.vx \vf0_1, \vf0_1, \x0x249; vand.vx \vf0_2, \vf0_2, \x0x249
    vand.vx \vf1_0, \vf1_0, \x0x249; vand.vx \vf1_1, \vf1_1, \x0x249; vand.vx \vf1_2, \vf1_2, \x0x249
    vand.vx \vf2_0, \vf2_0, \x0x249; vand.vx \vf2_1, \vf2_1, \x0x249; vand.vx \vf2_2, \vf2_2, \x0x249
    vand.vx \vf3_0, \vf3_0, \x0x249; vand.vx \vf3_1, \vf3_1, \x0x249; vand.vx \vf3_2, \vf3_2, \x0x249
    vadd.vv \vf0_0, \vf0_0, \vf0_1; vadd.vv \vf1_0, \vf1_0, \vf1_1
    vadd.vv \vf2_0, \vf2_0, \vf2_1; vadd.vv \vf3_0, \vf3_0, \vf3_1
    vadd.vv \vf0_0, \vf0_0, \vf0_2; vadd.vv \vf1_0, \vf1_0, \vf1_2
    vadd.vv \vf2_0, \vf2_0, \vf2_2; vadd.vv \vf3_0, \vf3_0, \vf3_2
    vsrl.vi \vf0_1, \vf0_0, 3;      vsrl.vi \vf1_1, \vf1_0, 3
    vsrl.vi \vf2_1, \vf2_0, 3;      vsrl.vi \vf3_1, \vf3_0, 3
    vadd.vx \vf0_0, \vf0_0, \x0x6DB;vadd.vx \vf1_0, \vf1_0, \x0x6DB
    vadd.vx \vf2_0, \vf2_0, \x0x6DB;vadd.vx \vf3_0, \vf3_0, \x0x6DB
    vsub.vv \vf0_0, \vf0_0, \vf0_1; vsub.vv \vf1_0, \vf1_0, \vf1_1
    vsub.vv \vf2_0, \vf2_0, \vf2_1; vsub.vv \vf3_0, \vf3_0, \vf3_1
    vsll.vi \vf0_1, \vf0_0, 10; vsrl.vi \vf0_2, \vf0_0, 12; vsrl.vi \vf0_3, \vf0_0, 2
    vsll.vi \vf1_1, \vf1_0, 10; vsrl.vi \vf1_2, \vf1_0, 12; vsrl.vi \vf1_3, \vf1_0, 2
    vsll.vi \vf2_1, \vf2_0, 10; vsrl.vi \vf2_2, \vf2_0, 12; vsrl.vi \vf2_3, \vf2_0, 2
    vsll.vi \vf3_1, \vf3_0, 10; vsrl.vi \vf3_2, \vf3_0, 12; vsrl.vi \vf3_3, \vf3_0, 2
    vand.vi \vf0_0, \vf0_0, 7;  vand.vx \vf0_1, \vf0_1, \x0x70000
    vand.vi \vf0_2, \vf0_2, 7;  vand.vx \vf0_3, \vf0_3, \x0x70000
    vand.vi \vf1_0, \vf1_0, 7;  vand.vx \vf1_1, \vf1_1, \x0x70000
    vand.vi \vf1_2, \vf1_2, 7;  vand.vx \vf1_3, \vf1_3, \x0x70000
    vand.vi \vf2_0, \vf2_0, 7;  vand.vx \vf2_1, \vf2_1, \x0x70000
    vand.vi \vf2_2, \vf2_2, 7;  vand.vx \vf2_3, \vf2_3, \x0x70000
    vand.vi \vf3_0, \vf3_0, 7;  vand.vx \vf3_1, \vf3_1, \x0x70000
    vand.vi \vf3_2, \vf3_2, 7;  vand.vx \vf3_3, \vf3_3, \x0x70000
    vadd.vv \vf0_0, \vf0_0, \vf0_1;   vadd.vv \vf0_1, \vf0_2, \vf0_3
    vadd.vv \vf1_0, \vf1_0, \vf1_1;   vadd.vv \vf1_1, \vf1_2, \vf1_3
    vadd.vv \vf2_0, \vf2_0, \vf2_1;   vadd.vv \vf2_1, \vf2_2, \vf2_3
    vadd.vv \vf3_0, \vf3_0, \vf3_1;   vadd.vv \vf3_1, \vf3_2, \vf3_3
    vsetivli a7, 16, e16, m1, tu, mu
    vadd.vi \vf0_0, \vf0_0, -3;     vadd.vi \vf0_1, \vf0_1, -3
    vadd.vi \vf1_0, \vf1_0, -3;     vadd.vi \vf1_1, \vf1_1, -3
    vadd.vi \vf2_0, \vf2_0, -3;     vadd.vi \vf2_1, \vf2_1, -3
    vadd.vi \vf3_0, \vf3_0, -3;     vadd.vi \vf3_1, \vf3_1, -3
    vrgather.vv \vf0_2, \vf0_0, \vidx_low;  vrgather.vv \vf0_3, \vf0_1, \vidx_low
    vrgather.vv \vt0_0, \vf0_0, \vidx_high; vrgather.vv \vt0_1, \vf0_1, \vidx_high
    vrgather.vv \vf1_2, \vf1_0, \vidx_low;  vrgather.vv \vf1_3, \vf1_1, \vidx_low
    vrgather.vv \vt1_0, \vf1_0, \vidx_high; vrgather.vv \vt1_1, \vf1_1, \vidx_high
    vrgather.vv \vf2_2, \vf2_0, \vidx_low;  vrgather.vv \vf2_3, \vf2_1, \vidx_low
    vrgather.vv \vt2_0, \vf2_0, \vidx_high; vrgather.vv \vt2_1, \vf2_1, \vidx_high
    vrgather.vv \vf3_2, \vf3_0, \vidx_low;  vrgather.vv \vf3_3, \vf3_1, \vidx_low
    vrgather.vv \vt3_0, \vf3_0, \vidx_high; vrgather.vv \vt3_1, \vf3_1, \vidx_high
    vmerge.vvm  \vf0_0, \vf0_3, \vf0_2, v0;   vmerge.vvm  \vf0_1, \vt0_1, \vt0_0, v0
    vmerge.vvm  \vf1_0, \vf1_3, \vf1_2, v0;   vmerge.vvm  \vf1_1, \vt1_1, \vt1_0, v0
    vmerge.vvm  \vf2_0, \vf2_3, \vf2_2, v0;   vmerge.vvm  \vf2_1, \vt2_1, \vt2_0, v0
    vmerge.vvm  \vf3_0, \vf3_3, \vf3_2, v0;   vmerge.vvm  \vf3_1, \vt3_1, \vt3_0, v0
    addi t2, a0, 16*2;  addi t3, a0, 16*4;  addi t4, a0, 16*6
    vse16.v \vf0_0, (a0); vse16.v \vf0_1, (t2)
    vse16.v \vf1_0, (t3); vse16.v \vf1_1, (t4)
    addi t2, a0, 16*8;  addi t3, a0, 16*10; addi t4, a0, 16*12; addi t5, a0, 16*14
    vse16.v \vf2_0, (t2); vse16.v \vf2_1, (t3)
    vse16.v \vf3_0, (t4); vse16.v \vf3_1, (t5)
    addi a0, a0, 16*16
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

.globl ntt_rvv_vlen256
.align 2
ntt_rvv_vlen256:
    save_regs
    li a7, 16*8
    li t0, 3329;    addi a6, a1, _ZETAS_EXP_L0*2
    vsetvli a7, a7, e16, m8, tu, mu
    lh t2, 0*2(a6);     lh t1, 1*2(a6)
    # a[0-127] & a[128-255]
    addi a5, a0, 128*2
    vle16.v v16, (a0);  vle16.v v24, (a5)
    # level 0
    ct_bfu_vx v16, v24, t1, t2, t0, v0, v8
    # level 1
    li a7, 16*4;        addi a6, a6, 2*2
    vsetvli a7, a7, e16, m4, tu, mu
    lh t2, 0*2(a6);     lh t1, 1*2(a6)
    lh t4, 2*2(a6);     lh t3, 3*2(a6)
    ct_bfu_vx_x2 v16, v20, v24, v28, t1, t2, t3, t4, t0, v0, v4, v8, v12
    # level 2
    li a7, 16*2;        addi a6, a6, 4*2
    vsetvli a7, a7, e16, m2, tu, mu
    lh t2, 0*2(a6);     lh t1, 1*2(a6)
    lh t4, 2*2(a6);     lh t3, 3*2(a6)
    lh t6, 4*2(a6);     lh t5, 5*2(a6)
    lh a3, 6*2(a6);     lh a2, 7*2(a6)
    ct_bfu_vx_x4 v16, v18, v20, v22, v24, v26, v28, v30, \
        t1, t2, t3, t4, t5, t6, a2, a3, t0, \
        v0, v2, v4, v6, v8, v10, v12, v14
    # level 3
    vsetivli a7, 16, e16, m1, tu, mu
    # shuffle8
    li t6, 0x00ff
    addi a2, a1, _MASK_0_7x2*2;     addi a3, a1, _MASK_8_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v20, v17, v21, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v18, v22, v19, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v28, v25, v29, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v26, v30, v27, v31, v12, v13, v14, v15, v1, v2
    # shuffle4
    li t6, 0x0f0f
    addi a2, a1, _MASK_0_3x2_8_11x2*2;addi a3, a1, _MASK_4_7x2_12_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v20, v22, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v17, v19, v21, v23, v12, v13, v14, v15, v1, v2
    addi a6, a1, _ZETAS_EXP_L3*2
    shuffle_x2 v24, v26, v28, v30, v8,  v9,  v10, v11, v1, v2
    vl4re16.v v4, (a6); addi a6, a6, 16*4*2
    shuffle_x2 v25, v27, v29, v31, v12, v13, v14, v15, v1, v2
    ct_bfu_vv_x8 \
        v16, v17, v18, v19, v20, v21, v22, v23, \
        v24, v25, v26, v27, v28, v29, v30, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6,  t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 4
    # shuffle2
    li t6, 0x3333
    addi a2, a1, _MASK_01014545*2;  addi a3, a1, _MASK_23236767*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v20, v21, v22, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v25, v26, v27, v8,  v9,  v10, v11, v1, v2
    vl4re16.v v4, (a6); addi a6, a6, 16*4*2
    shuffle_x2 v28, v29, v30, v31, v12, v13, v14, v15, v1, v2
    ct_bfu_vv_x8 \
        v16, v20, v17, v21, v18, v22, v19, v23, \
        v24, v28, v25, v29, v26, v30, v27, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6,  t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 5
    # shuffle1
    addi a2, a1, _MASK_10325476*2;  li t6, 0x5555
    vle16.v v1, (a2);               vmv.s.x v0, t6
    shuffle_x2 v16, v20, v17, v21, v8,  v9,  v10, v11, v1, v1
    shuffle_x2 v18, v22, v19, v23, v12, v13, v14, v15, v1, v1
    shuffle_x2 v24, v28, v25, v29, v8,  v9,  v10, v11, v1, v1
    vl4re16.v v4, (a6); addi a6, a6, 16*4*2
    shuffle_x2 v26, v30, v27, v31, v12, v13, v14, v15, v1, v1
    ct_bfu_vv_x8 \
        v16, v18, v20, v22, v17, v19, v21, v23, \
        v24, v26, v28, v30, v25, v27, v29, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6,  t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 6
    vl8re16.v v0, (a6)
    ct_bfu_vv_o_x4 \
        v8,  v10, v9,  v11, v12, v14, v13, v15, \
        v16, v17, v20, v21, v18, v19, v22, v23, \
        v1,  v0,  v1,  v0,  v3,  v2,  v3,  v2,  t0
    vs8r.v v8, (a0)
    ct_bfu_vv_o_x4 \
        v8,  v10, v9,  v11, v12, v14, v13, v15, \
        v24, v25, v28, v29, v26, v27, v30, v31, \
        v5,  v4,  v5,  v4,  v7,  v6,  v7,  v6,  t0
    vs8r.v v8, (a5)
    restore_regs
ret

.globl intt_rvv_vlen256
.align 2
intt_rvv_vlen256:
    li a7, 16*8;    addi a5, a0, 128*2
    vsetvli a7, a7, e16, m8, tu, mu
    li t2, 1441;    li t3, -10079   // mont^2/128 and qinv*(mont^2/128)
    vle16.v v0, (a0);   vle16.v v8, (a5)
    li t0, 3329;    li a4, 20159
    csrwi vxrm, 0   # round-to-nearest-up (add +0.5 LSB)
    montmul_const v16, v0, t2, t3, t0, v24
    montmul_const v24, v8, t2, t3, t0, v0
    vsetivli a7, 16, e16, m1, tu, mu
    # level 0
    addi a6, a1, _ZETA_EXP_INTT_L0*2
    vl8re16.v v0, (a6); addi a6, a6, 8*16*2
    gs_bfu_vv_x8 \
        v16, v18, v17, v19, v20, v22, v21, v23, \
        v24, v26, v25, v27, v28, v30, v29, v31, \
        v1,  v0,  v1,  v0,  v3,  v2,  v3,  v2,  \
        v5,  v4,  v5,  v4,  v7,  v6,  v7,  v6, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 1
    vl4re16.v v0, (a6); addi a6, a6, 4*16*2
    gs_bfu_vv_x8 \
        v16, v20, v17, v21, v18, v22, v19, v23, \
        v24, v28, v25, v29, v26, v30, v27, v31, \
        v1,  v0,  v1,  v0,  v1,  v0,  v1,  v0,  \
        v3,  v2,  v3,  v2,  v3,  v2,  v3,  v2, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 2
    # shuffle1
    addi a2, a1, _MASK_10325476*2;  li t6, 0x5555
    vle16.v v1, (a2);               vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8,  v9,  v10, v11, v1, v1
    shuffle_x2 v20, v21, v22, v23, v12, v13, v14, v15, v1, v1
    shuffle_x2 v24, v25, v26, v27, v8,  v9,  v10, v11, v1, v1
    vl4re16.v v4, (a6); addi a6, a6, 4*16*2
    shuffle_x2 v28, v29, v30, v31, v12, v13, v14, v15, v1, v1
    gs_bfu_vv_x8 \
        v16, v17, v18, v19, v20, v21, v22, v23, \
        v24, v25, v26, v27, v28, v29, v30, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    # level 3
    # shuffle2
    li t6, 0x3333
    addi a2, a1, _MASK_01014545*2;  addi a3, a1, _MASK_23236767*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v20, v22, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v24, v26, v28, v30, v12, v13, v14, v15, v1, v2
    shuffle_x2 v17, v19, v21, v23, v8,  v9,  v10, v11, v1, v2
    vl4re16.v v4, (a6); addi a6, a6, 4*16*2
    shuffle_x2 v25, v27, v29, v31, v12, v13, v14, v15, v1, v2
    gs_bfu_vv_x8 \
        v16, v18, v20, v22, v17, v19, v21, v23, \
        v24, v26, v28, v30, v25, v27, v29, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    barrettRdcX2 v16, v24, v8, v9, a4, t0
    # level 4
    # shuffle4
    li t6, 0x0f0f
    addi a2, a1, _MASK_0_3x2_8_11x2*2;addi a3, a1, _MASK_4_7x2_12_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v20, v24, v28, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v17, v21, v25, v29, v12, v13, v14, v15, v1, v2
    shuffle_x2 v18, v22, v26, v30, v8,  v9,  v10, v11, v1, v2
    vl4re16.v v4, (a6); addi a6, a6, 4*16*2
    shuffle_x2 v19, v23, v27, v31, v12, v13, v14, v15, v1, v2
    gs_bfu_vv_x8 \
        v16, v20, v17, v21, v18, v22, v19, v23, \
        v24, v28, v25, v29, v26, v30, v27, v31, \
        v5,  v4,  v5,  v4,  v5,  v4,  v5,  v4,  \
        v7,  v6,  v7,  v6,  v7,  v6,  v7,  v6, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    barrettRdcX2 v16, v24, v8, v9, a4, t0
    # level 5
    # shuffle8
    li t6, 0x00ff
    addi a2, a1, _MASK_0_7x2*2;     addi a3, a1, _MASK_8_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v20, v21, v22, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v25, v26, v27, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v28, v29, v30, v31, v12, v13, v14, v15, v1, v2
    lh t2, 0*2(a6);     lh t1, 1*2(a6)
    lh t4, 2*2(a6);     lh t3, 3*2(a6)
    gs_bfu_vx_x4 \
        v16, v17, v18, v19, v20, v21, v22, v23, \
        t1,  t2,  t1,  t2,  t1,  t2,  t1,  t2, t0, \
        v8,  v9,  v10, v11, v12, v13, v14, v15
    gs_bfu_vx_x4 \
        v24, v25, v26, v27, v28, v29, v30, v31, \
        t3,  t4,  t3,  t4,  t3,  t4,  t3,  t4, t0, \
        v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7
    barrettRdcX2 v16, v24, v8, v9, a4, t0
    # level 6
    lh t2, 4*2(a6); lh t1, 5*2(a6)
    gs_bfu_vx_o_x4 \
        v0,  v8,  v1,  v9,  v2,  v10, v3,  v11, \
        v16, v24, v18, v26, v20, v28, v22, v30, \
        t1,  t2,  t1,  t2,  t1,  t2,  t1,  t2, t0
    gs_bfu_vx_o_x4 \
        v4,  v12, v5,  v13, v6,  v14, v7,  v15, \
        v17, v25, v19, v27, v21, v29, v23, v31, \
        t1,  t2,  t1,  t2,  t1,  t2,  t1,  t2, t0
    vs8r.v v0, (a0);    vs8r.v v8, (a5)
ret

// void poly_basemul_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table);
// (a0b0 + b1 * (a1zeta mod q)) mod q + ((a0b1 + a1b0) mod q)x
.globl poly_basemul_rvv_vlen256
.align 2
poly_basemul_rvv_vlen256:
    li a7, 32;  li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  a3, a3, t3; add  t3, a6, a7; addi t2, a1, 256*2
poly_basemul_rvv_vlen256_loop:
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
    # a0b1 + a1b0
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
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
    # a0b0 + b1 * (a1zeta mod q)
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    addi a4, a0, 0;    add a5, a0, a6;  vse16.v v20, (a4); vse16.v v21, (a5)
    add  a4, a4, t5;   add a5, a5, t5;  vse16.v v22, (a4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a3, a3, t5;  add a0, a0, t5
    bltu a1, t2, poly_basemul_rvv_vlen256_loop
ret

// void poly_basemul_acc_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table)
.globl poly_basemul_acc_rvv_vlen256
.align 2
poly_basemul_acc_rvv_vlen256:
    li a7, 32;  li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  a3, a3, t3; add  t3, a6, a7; addi t2, a1, 256*2
poly_basemul_acc_rvv_vlen256_loop:
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
    bltu a1, t2, poly_basemul_acc_rvv_vlen256_loop
ret

// void poly_basemul_cache_init_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table, int16_t *b_cache)
.globl poly_basemul_cache_init_rvv_vlen256
.align 2
poly_basemul_cache_init_rvv_vlen256:
    li a7, 32;  li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  a3, a3, t3; add  t3, a6, a7; addi t2, a1, 256*2
poly_basemul_cache_init_rvv_vlen256_loop:
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
    # a0b1 + a1b0
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
    add t4, a0, a7;   add a5, a0, t3;   vse16.v v16, (t4); vse16.v v17, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vse16.v v18, (t4); vse16.v v19, (a5)
    # load zetas
    addi t4, a3, 0;   add  a5, a3, a7;  vle16.v v16, (t4); vle16.v v17, (a5)
    add  t4, t4, a6;  add  a5, a5, a6;  vle16.v v18, (t4); vle16.v v19, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v24, v25, v26, v27, v12, v13, v14, v15, \
        v16, v17, v18, v19, t0, t1, v28, v29, v30, v31
    # store b1zeta
    addi t4, a4, 0*0;  add  a5, a4, a7; vse16.v v24, (t4); vse16.v v25, (a5)
    add  t4, t4, a6;   add  a5, a5, a6; vse16.v v26, (t4); vse16.v v27, (a5)
    montmul_x4 v0, v1, v2, v3, v4, v5, v6, v7, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    # a0b0 + a1 * (b1zeta mod q)
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    addi t4, a0, 0;    add a5, a0, a6;  vse16.v v20, (t4); vse16.v v21, (a5)
    add  t4, t4, t5;   add a5, a5, t5;  vse16.v v22, (t4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a3, a3, t5;  add a0, a0, t5;   add a4, a4, t5
    bltu a1, t2, poly_basemul_cache_init_rvv_vlen256_loop
ret

// void poly_basemul_acc_cache_init_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table, int16_t *b_cache)
.globl poly_basemul_acc_cache_init_rvv_vlen256
.align 2
poly_basemul_acc_cache_init_rvv_vlen256:
    li a7, 32;  li t3, _ZETAS_BASEMUL*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  a3, a3, t3; add  t3, a6, a7; addi t2, a1, 256*2
poly_basemul_acc_cache_init_rvv_vlen256_loop:
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
    add t4, a0, a7;   add a5, a0, t3;   vle16.v v24, (t4); vle16.v v25, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vle16.v v26, (t4); vle16.v v27, (a5)
    # a0b1 + a1b0; then accumulate
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
    vadd.vv v16, v16, v24;  vadd.vv v17, v17, v25
    vadd.vv v18, v18, v26;  vadd.vv v19, v19, v27
    add t4, a0, a7;   add a5, a0, t3;   vse16.v v16, (t4); vse16.v v17, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vse16.v v18, (t4); vse16.v v19, (a5)
    # load zetas
    addi t4, a3, 0;   add  a5, a3, a7;  vle16.v v16, (t4); vle16.v v17, (a5)
    add  t4, t4, a6;  add  a5, a5, a6;  vle16.v v18, (t4); vle16.v v19, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v24, v25, v26, v27, v12, v13, v14, v15, \
        v16, v17, v18, v19, t0, t1, v28, v29, v30, v31
    # store b1zeta
    addi t4, a4, 0*0;  add  a5, a4, a7; vse16.v v24, (t4); vse16.v v25, (a5)
    add  t4, t4, a6;   add  a5, a5, a6; vse16.v v26, (t4); vse16.v v27, (a5)
    montmul_x4 v0, v1, v2, v3, v4, v5, v6, v7, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    addi t4, a0, 0*2;  add  a5, a0, a6; vle16.v v28, (t4); vle16.v v29, (a5)
    add  t4, t4, t5;   add  a5, a5, t5; vle16.v v30, (t4); vle16.v v31, (a5)
    # a0b0 + a1 * (b1zeta mod q); then accumulate
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    vadd.vv v20, v20, v28;  vadd.vv v21, v21, v29
    vadd.vv v22, v22, v30;  vadd.vv v23, v23, v31
    addi t4, a0, 0;    add a5, a0, a6;  vse16.v v20, (t4); vse16.v v21, (a5)
    add  t4, t4, t5;   add a5, a5, t5;  vse16.v v22, (t4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a3, a3, t5;  add a0, a0, t5;   add a4, a4, t5
    bltu a1, t2, poly_basemul_acc_cache_init_rvv_vlen256_loop
ret

// void poly_basemul_cached_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table, int16_t *b_cache)
.globl poly_basemul_cached_rvv_vlen256
.align 2
poly_basemul_cached_rvv_vlen256:
    li a7, 32; addi t2, a1, 256*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  t3, a6, a7
poly_basemul_cached_rvv_vlen256_loop:
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
    # a0b1 + a1b0
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
    add t4, a0, a7;   add a5, a0, t3;   vse16.v v16, (t4); vse16.v v17, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vse16.v v18, (t4); vse16.v v19, (a5)
    # load b1zeta
    addi t4, a4, 0*0;  add  a5, a4, a7; vle16.v v24, (t4); vle16.v v25, (a5)
    add  t4, t4, a6;   add  a5, a5, a6; vle16.v v26, (t4); vle16.v v27, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v0, v1, v2, v3, v4, v5, v6, v7, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    # a0b0 + a1 * (b1zeta mod q)
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    addi t4, a0, 0;    add a5, a0, a6;  vse16.v v20, (t4); vse16.v v21, (a5)
    add  t4, t4, t5;   add a5, a5, t5;  vse16.v v22, (t4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a0, a0, t5;   add a4, a4, t5
    bltu a1, t2, poly_basemul_cached_rvv_vlen256_loop
ret

// void poly_basemul_acc_cached_rvv_vlen256(int16_t *r, const int16_t *a, const int16_t *b, const int16_t *table, int16_t *b_cache)
.globl poly_basemul_acc_cached_rvv_vlen256
.align 2
poly_basemul_acc_cached_rvv_vlen256:
    li a7, 32; addi t2, a1, 256*2
    vsetvli a7, a7, e16, m1, tu, mu; li t0, 3329; li t1, -3327
    slli t5, a7, 3;  slli a6, a7, 2;  slli a7, a7, 1
    add  t3, a6, a7
poly_basemul_acc_cached_rvv_vlen256_loop:
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
    add t4, a0, a7;   add a5, a0, t3;   vle16.v v24, (t4); vle16.v v25, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vle16.v v26, (t4); vle16.v v27, (a5)
    # a0b1 + a1b0; then accumulate
    vadd.vv v16, v16, v20;  vadd.vv v17, v17, v21
    vadd.vv v18, v18, v22;  vadd.vv v19, v19, v23
    vadd.vv v16, v16, v24;  vadd.vv v17, v17, v25
    vadd.vv v18, v18, v26;  vadd.vv v19, v19, v27
    add t4, a0, a7;   add a5, a0, t3;   vse16.v v16, (t4); vse16.v v17, (a5)
    add t4, t4, t5;   add a5, a5, t5;   vse16.v v18, (t4); vse16.v v19, (a5)
    # load b1zeta
    addi t4, a4, 0*0;  add  a5, a4, a7; vle16.v v24, (t4); vle16.v v25, (a5)
    add  t4, t4, a6;   add  a5, a5, a6; vle16.v v26, (t4); vle16.v v27, (a5)
    montmul_x4 v20, v21, v22, v23, v0, v1, v2, v3, \
        v8,  v9,  v10, v11, t0, t1, v28, v29, v30, v31
    montmul_x4 v0, v1, v2, v3, v4, v5, v6, v7, \
        v24, v25, v26, v27, t0, t1, v28, v29, v30, v31
    addi t4, a0, 0*2;  add  a5, a0, a6; vle16.v v28, (t4); vle16.v v29, (a5)
    add  t4, t4, t5;   add  a5, a5, t5; vle16.v v30, (t4); vle16.v v31, (a5)
    # a0b0 + a1 * (b1zeta mod q); then accumulate
    vadd.vv v20, v20, v0;  vadd.vv v21, v21, v1
    vadd.vv v22, v22, v2;  vadd.vv v23, v23, v3
    vadd.vv v20, v20, v28; vadd.vv v21, v21, v29
    vadd.vv v22, v22, v30; vadd.vv v23, v23, v31
    addi t4, a0, 0;    add a5, a0, a6;  vse16.v v20, (t4); vse16.v v21, (a5)
    add  t4, t4, t5;   add a5, a5, t5;  vse16.v v22, (t4); vse16.v v23, (a5)
    add  a0, a0, t5;   add a3, a3, t5;  add a0, a0, t5;   add a4, a4, t5
    bltu a1, t2, poly_basemul_acc_cached_rvv_vlen256_loop
ret

.globl poly_reduce_rvv_vlen256
.align 2
poly_reduce_rvv_vlen256:
    li a7, 16*8;    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    csrwi vxrm, 0   # round-to-nearest-up (add +0.5 LSB)
    li a6, 20159;   add  t4, a0, 256*2  
    slli t3, a7, 2; slli a7, a7, 1
poly_reduce_rvv_vlen256_loop:
    add a1, a0, a7
    vle16.v v0,  (a0);  vle16.v v8,  (a1)
    barrettRdc v0, v16, a6, t0
    barrettRdc v8, v24, a6, t0
    vse16.v v0,  (a0);  vse16.v v8,  (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_reduce_rvv_vlen256_loop
ret

.globl poly_tomont_rvv_vlen256
.align 2
poly_tomont_rvv_vlen256:
    li a7, 16*8;    li t0, 3329
    vsetvli a7, a7, e16, m8, tu, mu
    # mont^2 and qinv*mont^2
    li t1, 1353;    li t2, 20553
    slli t3, a7, 2; slli a7, a7, 1
    add  t4, a0, 256*2
poly_tomont_rvv_vlen256_loop:
    add a1, a0, a7
    vle16.v v0,  (a0);  vle16.v v8,  (a1)
    montmul_const v16, v0, t1, t2, t0, v24
    montmul_const v24, v8, t1, t2, t0, v0
    vse16.v v16, (a0);  vse16.v v24, (a1)
    add  a0, a0, t3
    bltu a0, t4, poly_tomont_rvv_vlen256_loop
ret

.globl normal2ntt_order_rvv_vlen256
.align 2
normal2ntt_order_rvv_vlen256:
    addi a5, a0, 128*2
    # a[0-127] & a[128-255]
    vsetivli a7, 16, e16, m1, tu, mu
    vl8re16.v v16, (a0);    vl8re16.v v24, (a5)
    # shuffle8
    li t6, 0x00ff
    addi a2, a1, _MASK_0_7x2*2;     addi a3, a1, _MASK_8_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v20, v17, v21, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v18, v22, v19, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v28, v25, v29, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v26, v30, v27, v31, v12, v13, v14, v15, v1, v2
    # shuffle4
    li t6, 0x0f0f
    addi a2, a1, _MASK_0_3x2_8_11x2*2;addi a3, a1, _MASK_4_7x2_12_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v20, v22, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v17, v19, v21, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v26, v28, v30, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v25, v27, v29, v31, v12, v13, v14, v15, v1, v2
    # shuffle2
    li t6, 0x3333
    addi a2, a1, _MASK_01014545*2;  addi a3, a1, _MASK_23236767*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v20, v21, v22, v23, v12, v13, v14, v15, v1, v2
    shuffle_x2 v24, v25, v26, v27, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v28, v29, v30, v31, v12, v13, v14, v15, v1, v2
    # shuffle1
    addi a2, a1, _MASK_10325476*2;  li t6, 0x5555
    vle16.v v1, (a2);               vmv.s.x v0, t6
    addi a4, a0, 4*16*2; addi a5, a0, 8*16*2; addi a6, a0, 12*16*2
    shuffle_o_x2 v4,  v5,  v6,  v7,  v16, v20, v17, v21, v1, v1
    vs4r.v v4, (a0)
    shuffle_o_x2 v8,  v9,  v10, v11, v18, v22, v19, v23, v1, v1
    vs4r.v v8, (a4)
    shuffle_o_x2 v12, v13, v14, v15, v24, v28, v25, v29, v1, v1
    vs4r.v v12, (a5)
    shuffle_o_x2 v16, v17, v18, v19, v26, v30, v27, v31, v1, v1
    vs4r.v v16, (a6)
ret

.globl ntt2normal_order_rvv_vlen256
.align 2
ntt2normal_order_rvv_vlen256:
    addi a5, a0, 128*2
    # a[0-127] & a[128-255]
    vsetivli a7, 16, e16, m1, tu, mu
    vl8re16.v v16, (a0);    vl8re16.v v24, (a5)
    # shuffle1
    addi a2, a1, _MASK_10325476*2;  li t6, 0x5555
    vle16.v v1, (a2);               vmv.s.x v0, t6
    shuffle_x2 v16, v17, v18, v19, v8,  v9,  v10, v11, v1, v1
    shuffle_x2 v20, v21, v22, v23, v12, v13, v14, v15, v1, v1
    shuffle_x2 v24, v25, v26, v27, v8,  v9,  v10, v11, v1, v1
    shuffle_x2 v28, v29, v30, v31, v12, v13, v14, v15, v1, v1
    # shuffle2
    li t6, 0x3333
    addi a2, a1, _MASK_01014545*2;  addi a3, a1, _MASK_23236767*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v18, v20, v22, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v24, v26, v28, v30, v12, v13, v14, v15, v1, v2
    shuffle_x2 v17, v19, v21, v23, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v25, v27, v29, v31, v12, v13, v14, v15, v1, v2
    # shuffle4
    li t6, 0x0f0f
    addi a2, a1, _MASK_0_3x2_8_11x2*2;addi a3, a1, _MASK_4_7x2_12_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_x2 v16, v20, v24, v28, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v17, v21, v25, v29, v12, v13, v14, v15, v1, v2
    shuffle_x2 v18, v22, v26, v30, v8,  v9,  v10, v11, v1, v2
    shuffle_x2 v19, v23, v27, v31, v12, v13, v14, v15, v1, v2
    # shuffle8
    li t6, 0x00ff
    addi a2, a1, _MASK_0_7x2*2;     addi a3, a1, _MASK_8_15x2*2
    vle16.v v1, (a2);    vle16.v v2, (a3);    vmv.s.x v0, t6
    shuffle_o_x2 v8,  v12, v9,  v13, v16, v17, v18, v19, v1, v2
    shuffle_o_x2 v10, v14, v11, v15, v20, v21, v22, v23, v1, v2
    vs8r.v v8, (a0)
    shuffle_o_x2 v16, v20, v17, v21, v24, v25, v26, v27, v1, v2
    shuffle_o_x2 v18, v22, v19, v23, v28, v29, v30, v31, v1, v2
    vs8r.v v16, (a5)
ret

// void rej_uniform_rvv_vlen256(int16_t *r, const uint8_t *buf, const int16_t *table, uint32_t *ctr_p, uint32_t *pos_p)
.globl rej_uniform_rvv_vlen256
.align 2
rej_uniform_rvv_vlen256:
    li t0, 0xfff;   li t1, 3329
    vsetivli a7, 16, e16, m1, tu, mu
    addi t2, a2, _REJ_UNIFORM_IDX8*2
    addi t3, a2, _REJ_UNIFORM_MASK_01*2
    vle16.v v30, (t2);  vle16.v v31, (t3)
    vmseq.vi v0, v31, 1
    addi a5, a0, 0; addi a6, a1, 0
# do...while(ctr <= KYBER_N - 16*4 && pos <= REJ_UNIFORM_VECTOR_BUFLEN - 24*4)
rej_uniform_rvv_vlen256_loop_x4:
    rej_core_x4 v8, v9, v10, v11, v12, v13, v14, v15, \
        v16, v17, v18, v19, v30, t0, t1
    sub  t2, a0, a5;    li  t4, 256-16*4
    srli t2, t2, 1;     sub t3, a1, a6
    li   t5, 504-24*4
    bgtu t2, t4, rej_uniform_rvv_vlen256_loopend_x4
    bleu t3, t5, rej_uniform_rvv_vlen256_loop_x4
rej_uniform_rvv_vlen256_loopend_x4:
# while(ctr <= KYBER_N - 16*2 && pos <= REJ_UNIFORM_VECTOR_BUFLEN - 24*2)
rej_uniform_rvv_vlen256_loop_x2:
    sub  t2, a0, a5;    li  t4, 256-16*2
    srli t2, t2, 1;     sub t3, a1, a6
    li   t5, 504-24*2
    bgtu t2, t4, rej_uniform_rvv_vlen256_loopend_x2
    bgtu t3, t5, rej_uniform_rvv_vlen256_loopend_x2
    rej_core_x2 v8, v9, v12, v13, v16, v17, v30, t0, t1
    j rej_uniform_rvv_vlen256_loop_x2
rej_uniform_rvv_vlen256_loopend_x2:
# while(ctr <= KYBER_N - 16 && pos <= REJ_UNIFORM_VECTOR_BUFLEN - 24)
rej_uniform_rvv_vlen256_loop_x1:
    sub  t2, a0, a5;    li  t4, 256-16
    srli t2, t2, 1;     sub t3, a1, a6
    li   t5, 504-24
    bgtu t2, t4, rej_uniform_rvv_vlen256_loopend_x1
    bgtu t3, t5, rej_uniform_rvv_vlen256_loopend_x1
    rej_core v8, v12, v16, v30, t0, t1
    j rej_uniform_rvv_vlen256_loop_x1
rej_uniform_rvv_vlen256_loopend_x1:
    sw t2, (a3);    sw t3, (a4)
ret

// void cbd2_rvv_vlen256(int16_t *r, const uint8_t *buf, const int16_t *table)
.globl cbd2_rvv_vlen256
.align 2
cbd2_rvv_vlen256:
    li a7, 32
    li t0, 0x55;    li t1, 0x33
    vsetvli a7, a7, e8, m1, tu, mu
    addi t2, a2, _CBD2_MASK_E8_01*2
    addi t3, a2, _CBD2_IDX8_LOW*2
    addi t4, a2, _CBD2_IDX8_HIGH*2
    vle8.v v29, (t2); vle8.v v30, (t3); vle8.v v31, (t4)
    vmseq.vi v0, v29, 1
    cbd2_core_x4 v1, v2, v3, v4, v5, v6, v7, v8, \
        v10, v11, v12, v13, v14, v15, v16, v17, \
        v18, v19, v20, v21, v22, v23, v24, v25, \
        v30, v31, t0, t1
ret

// void cbd3_rvv_vlen256(int16_t *r, const uint8_t *buf, const int16_t *table)
.globl cbd3_rvv_vlen256
.align 2
cbd3_rvv_vlen256:
    li t0, 0x249249;    li t1, 0x6DB6DB
    li a3, 0x70000;     li a4, 2
    vsetivli a7, 16, e16, m1, tu, mu
    addi t2, a2, _CBD3_MASK_E16_1100*2
    addi t3, a2, _CBD3_MASK_E8_0122*2
    addi t4, a2, _CBD3_IDX16_LOW*2
    addi t5, a2, _CBD3_IDX16_HIGH*2
    vle16.v v28, (t2);  vle16.v v29, (t3)
    vle16.v v30, (t4);  vle16.v v31, (t5)
    vmseq.vi v0, v28, 1
cbd3_rvv_vlen256_loop:
    cbd3_core_x4 \
        v2, v3, v4, v5, v6, v7, \
        v8, v9, v10,v11,v12,v13,\
        v14,v15,v16,v17,v18,v19,\
        v20,v21,v22,v23,v24,v25,\
        v29, v30, v31, t0, t1, a3
    addi a4, a4, -1
    bnez a4, cbd3_rvv_vlen256_loop
ret

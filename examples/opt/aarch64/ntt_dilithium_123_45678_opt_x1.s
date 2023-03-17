
// Needed to provide ASM_LOAD directive
#include <hal_env.h>

// NOTE
// We use a lot of trivial macros to simplify the parsing burden for Slothy
// The macros are not unfolded by Slothy and thus interpreted as instructions,
// which are easier to parse due to e.g. the lack of size specifiers and simpler
// syntax for pre and post increment for loads and stores.
//
// Eventually, NeLight should include a proper parser for AArch64,
// but for initial investigations, the below is enough.
xtmp0 .req x10
xtmp1 .req x11

.macro ldr_vo vec, base, offset                    // slothy:no-unfold
       ldr qform_\vec, [\base, \offset]
.endm

.macro ldr_vi vec, base, inc                        // slothy:no-unfold
        ldr qform_\vec, [\base], \inc
.endm

.macro str_vo vec, base, offset                     // slothy:no-unfold
        str qform_\vec, [\base, \offset]
.endm
.macro str_vi vec, base, inc                        // slothy:no-unfold
        str qform_\vec, [\base], \inc
.endm
.macro vqrdmulh d,a,b
        sqrdmulh \d\().4s, \a\().4s, \b\().4s
.endm
.macro vmls d,a,b
        mls \d\().4s, \a\().4s, \b\().4s
.endm
.macro vqrdmulhq d,a,b,i
        sqrdmulh \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vqdmulhq d,a,b,i
        sqdmulh \d\().4s, \a\().4s, \b\().4s[\i]
.endm
.macro vmulq d,a,b,i
        mul \d\().4s, \a\().4s, \b\().s[\i]
.endm
.macro vmlsq d,a,b,i
        mls \d\().4s, \a\().4s, \b\().s[\i]
.endm

.macro mulmodq dst, src, const, idx0, idx1
        vmulq       \dst,  \src, \const, \idx0
        vqrdmulhq   \src,  \src, \const, \idx1
        vmlsq        \dst,  \src, consts, 0
.endm

.macro mulmod dst, src, const, const_twisted
        mul        \dst\().4s,  \src\().4s, \const\().4s
        vqrdmulh   \src,  \src, \const_twisted
        vmlsq       \dst,  \src, consts, 0
.endm

.macro ct_butterfly a, b, root, idx0, idx1
        mulmodq  tmp, \b, \root, \idx0, \idx1
        sub     \b\().4s,    \a\().4s, tmp.4s
        add     \a\().4s,    \a\().4s, tmp.4s
.endm

.macro mulmod_v dst, src, const, const_twisted
        mul        \dst\().4s,  \src\().4s, \const\().4s
        vqrdmulh    \src,  \src, \const_twisted
        vmlsq        \dst,  \src, consts, 0
.endm

.macro ct_butterfly_v a, b, root, root_twisted
        mulmod  tmp, \b, \root, \root_twisted
        sub    \b\().4s,    \a\().4s, tmp.4s
        add    \a\().4s,    \a\().4s, tmp.4s
.endm

.macro barrett_reduce_single a
        srshr    tmp.4S, \a\().4S, #23
        vmlsq    \a, tmp, consts, 0
.endm

.macro barrett_reduce a0, a1, a2, a3
        barrett_reduce_single \a0
        barrett_reduce_single \a1
        barrett_reduce_single \a2
        barrett_reduce_single \a3
.endm

.macro load_vectors a0, a1, a2, a3, addr
        ldr_vo \a0, \addr, (16*0)
        ldr_vo \a1, \addr, (16*1)
        ldr_vo \a2, \addr, (16*2)
        ldr_vo \a3, \addr, (16*3)
.endm

.macro load_vectors_with_offset a0, a1, a2, a3, addr, offset
        ldr_vo \a0, \addr, (16*0 + (\offset))
        ldr_vo \a1, \addr, (16*1 + (\offset))
        ldr_vo \a2, \addr, (16*2 + (\offset))
        ldr_vo \a3, \addr, (16*3 + (\offset))
.endm

.macro store_vectors_with_inc a0, a1, a2, a3, addr, inc
        str_vi \a0, \addr, \inc
        str_vo \a1, \addr, (-(\inc) + 16*1)
        str_vo \a2, \addr, (-(\inc) + 16*2)
        str_vo \a3, \addr, (-(\inc) + 16*3)
.endm

.macro vec_to_scalar_matrix out, in
        vext \out\()_00, \in\()0, 0
        vext \out\()_01, \in\()0, 1
        vext \out\()_10, \in\()1, 0
        vext \out\()_11, \in\()1, 1
        vext \out\()_20, \in\()2, 0
        vext \out\()_21, \in\()2, 1
        vext \out\()_30, \in\()3, 0
        vext \out\()_31, \in\()3, 1
.endm

.macro store_scalar_matrix_with_inc x, addr, inc
        str \x\()t_00, [\addr], #( \inc)
        str \x\()t_01, [\addr,  #(-\inc + 8*1)]
        str \x\()t_10, [\addr,  #(-\inc + 8*2)]
        str \x\()t_11, [\addr,  #(-\inc + 8*3)]
        str \x\()t_20, [\addr,  #(-\inc + 8*4)]
        str \x\()t_21, [\addr,  #(-\inc + 8*5)]
        str \x\()t_30, [\addr,  #(-\inc + 8*6)]
        str \x\()t_31, [\addr,  #(-\inc + 8*7)]
.endm

.macro vext gpr_out, vec_in, lane                // slothy:no-unfold
        umov \gpr_out\(), \vec_in\().d[\lane]
.endm

.macro load_roots_123
        ldr_vi root0, r_ptr0, 64
        ldr_vo root1, r_ptr0, (-64 + 16)
        ldr_vo root2, r_ptr0, (-64 + 32)
        ldr_vo root3, r_ptr0, (-64 + 48)
.endm

.macro load_roots_456
        ldr_vi root0, r_ptr0, 64
        ldr_vo root1, r_ptr0, (-64 + 16)
        ldr_vo root2, r_ptr0, (-64 + 32)
        ldr_vo root3, r_ptr0, (-64 + 48)
.endm

.macro load_roots_78_part1
        ldr_vi root0,    r_ptr1, (12*16)
        ldr_vo root0_tw, r_ptr1, (-12*16 + 1*16)
        ldr_vo root1,    r_ptr1, (-12*16 + 2*16)
        ldr_vo root1_tw, r_ptr1, (-12*16 + 3*16)
        ldr_vo root2,    r_ptr1, (-12*16 + 4*16)
        ldr_vo root2_tw, r_ptr1, (-12*16 + 5*16)
.endm

.macro load_roots_78_part2
        ldr_vo root0,    r_ptr1, (-12*16 +  6*16)
        ldr_vo root0_tw, r_ptr1, (-12*16 +  7*16)
        ldr_vo root1,    r_ptr1, (-12*16 +  8*16)
        ldr_vo root1_tw, r_ptr1, (-12*16 +  9*16)
        ldr_vo root2,    r_ptr1, (-12*16 + 10*16)
        ldr_vo root2_tw, r_ptr1, (-12*16 + 11*16)
.endm

.macro transpose4 data0, data1, data2, data3
        trn1 t0.4s, \data0\().4s, \data1\().4s
        trn2 t1.4s, \data0\().4s, \data1\().4s
        trn1 t2.4s, \data2\().4s, \data3\().4s
        trn2 t3.4s, \data2\().4s, \data3\().4s

        trn2 \data2\().2d, t0.2d, t2.2d
        trn2 \data3\().2d, t1.2d, t3.2d
        trn1 \data0\().2d, t0.2d, t2.2d
        trn1 \data1\().2d, t1.2d, t3.2d
.endm

.macro transpose_single data_out0, data_out1, data_out2, data_out3, data_in0,  data_in1,  data_in2,  data_in3
        trn1 \data_out0\().4s, \data_in0\().4s, \data_in1\().4s
        trn2 \data_out1\().4s, \data_in0\().4s, \data_in1\().4s
        trn1 \data_out2\().4s, \data_in2\().4s, \data_in3\().4s
        trn2 \data_out3\().4s, \data_in2\().4s, \data_in3\().4s
.endm

.macro save_gprs // slothy:no-unfold
        sub sp, sp, #(16*6)
        stp x19, x20, [sp, #16*0]
        stp x19, x20, [sp, #16*0]
        stp x21, x22, [sp, #16*1]
        stp x23, x24, [sp, #16*2]
        stp x25, x26, [sp, #16*3]
        stp x27, x28, [sp, #16*4]
        stp x29, x30, [sp, #16*5]
.endm

.macro restore_gprs // slothy:no-unfold
        ldp x19, x20, [sp, #16*0]
        ldp x21, x22, [sp, #16*1]
        ldp x23, x24, [sp, #16*2]
        ldp x25, x26, [sp, #16*3]
        ldp x27, x28, [sp, #16*4]
        ldp x29, x30, [sp, #16*5]
        add sp, sp, #(16*6)
.endm

.macro save_vregs // slothy:no-unfold
        sub sp, sp, #(16*4)
        stp  d8,  d9, [sp, #16*0]
        stp d10, d11, [sp, #16*1]
        stp d12, d13, [sp, #16*2]
        stp d14, d15, [sp, #16*3]
.endm

.macro restore_vregs // slothy:no-unfold
        ldp  d8,  d9, [sp, #16*0]
        ldp d10, d11, [sp, #16*1]
        ldp d12, d13, [sp, #16*2]
        ldp d14, d15, [sp, #16*3]
        add sp, sp, #(16*4)
.endm

#define STACK_SIZE 16
#define STACK0 0

.macro restore a, loc     // slothy:no-unfold
        ldr \a, [sp, #\loc\()]
.endm
.macro save loc, a        // slothy:no-unfold
        str \a, [sp, #\loc\()]
.endm
.macro push_stack // slothy:no-unfold
        save_gprs
        save_vregs
        sub sp, sp, #STACK_SIZE
.endm

.macro pop_stack // slothy:no-unfold
        add sp, sp, #STACK_SIZE
        restore_vregs
        restore_gprs
.endm

.data
.p2align 4
roots:
#include "ntt_dilithium_123_456_78_twiddles.s"
.text

        .global ntt_dilithium_123_45678_opt_x1
        .global _ntt_dilithium_123_45678_opt_x1

.p2align 4
const_addr:   .word 8380417
              .word 0
              .word 0
              .word 0

ntt_dilithium_123_45678_opt_x1:
_ntt_dilithium_123_45678_opt_x1:
        push_stack

        in      .req x0
        inp     .req x1
        inpp    .req x2
        count   .req x3
        r_ptr0  .req x4
        r_ptr1  .req x5
        xtmp    .req x6

        data0  .req v9
        data1  .req v10
        data2  .req v11
        data3  .req v12
        data4  .req v13
        data5  .req v14
        data6  .req v15
        data7  .req v16

        qform_data0  .req q9
        qform_data1  .req q10
        qform_data2  .req q11
        qform_data3  .req q12
        qform_data4  .req q13
        qform_data5  .req q14
        qform_data6  .req q15
        qform_data7  .req q16

        qform_v0  .req q0
        qform_v1  .req q1
        qform_v2  .req q2
        qform_v3  .req q3
        qform_v4  .req q4
        qform_v5  .req q5
        qform_v6  .req q6
        qform_v7  .req q7
        qform_v8  .req q8
        qform_v9  .req q9
        qform_v10 .req q10
        qform_v11 .req q11
        qform_v12 .req q12
        qform_v13 .req q13
        qform_v14 .req q14
        qform_v15 .req q15
        qform_v16 .req q16
        qform_v17 .req q17
        qform_v18 .req q18
        qform_v19 .req q19
        qform_v20 .req q20
        qform_v21 .req q21
        qform_v22 .req q22
        qform_v23 .req q23
        qform_v24 .req q24
        qform_v25 .req q25
        qform_v26 .req q26
        qform_v27 .req q27
        qform_v28 .req q28
        qform_v29 .req q29
        qform_v30 .req q30
        qform_v31 .req q31

        x_00 .req x10
        x_01 .req x11
        x_10 .req x12
        x_11 .req x13
        x_20 .req x14
        x_21 .req x15
        x_30 .req x16
        x_31 .req x17

        xt_00 .req x_00
        xt_01 .req x_20
        xt_10 .req x_10
        xt_11 .req x_30
        xt_20 .req x_01
        xt_21 .req x_21
        xt_30 .req x_11
        xt_31 .req x_31

        root0 .req v0
        root1 .req v1
        root2 .req v2
        root3 .req v3

        qform_root0 .req q0
        qform_root1 .req q1
        qform_root2 .req q2
        qform_root3 .req q3

        tmp .req v24
        t0  .req v25
        t1  .req v26
        t2  .req v27
        t3  .req v28
        tp0 .req v17
        tp1 .req v18
        tp2 .req v19
        tp3 .req v20

        consts .req v8
        qform_consts .req q8

        ASM_LOAD(r_ptr0, roots_l012)
        ASM_LOAD(r_ptr1, roots_l67)

        ASM_LOAD(xtmp, const_addr)
        ld1r {consts.4s}, [xtmp]

        save STACK0, in
        mov count, #8

        load_roots_123

        .p2align 2
layer123_start:

        ldr_vo data0, in, 0
        ldr_vo data1, in, (1*(1024/8))
        ldr_vo data2, in, (2*(1024/8))
        ldr_vo data3, in, (3*(1024/8))
        ldr_vo data4, in, (4*(1024/8))
        ldr_vo data5, in, (5*(1024/8))
        ldr_vo data6, in, (6*(1024/8))
        ldr_vo data7, in, (7*(1024/8))

        ct_butterfly data0, data4, root0, 0, 1
        ct_butterfly data1, data5, root0, 0, 1
        ct_butterfly data2, data6, root0, 0, 1
        ct_butterfly data3, data7, root0, 0, 1

        ct_butterfly data0, data2, root0, 2, 3
        ct_butterfly data1, data3, root0, 2, 3
        ct_butterfly data4, data6, root1, 0, 1
        ct_butterfly data5, data7, root1, 0, 1

        ct_butterfly data0, data1, root1, 2, 3
        ct_butterfly data2, data3, root2, 0, 1
        ct_butterfly data4, data5, root2, 2, 3
        ct_butterfly data6, data7, root3, 0, 1

        str_vi data0, in, (16)
        str_vo data1, in, (-16 + 1*(1024/8))
        str_vo data2, in, (-16 + 2*(1024/8))
        str_vo data3, in, (-16 + 3*(1024/8))
        str_vo data4, in, (-16 + 4*(1024/8))
        str_vo data5, in, (-16 + 5*(1024/8))
        str_vo data6, in, (-16 + 6*(1024/8))
        str_vo data7, in, (-16 + 7*(1024/8))

        subs count, count, #1
        cbnz count, layer123_start

        restore inp, STACK0
        add inpp, inp, #64
        mov count, #8

        root0_tw .req v4
        root1_tw .req v5
        root2_tw .req v6
        root3_tw .req v7
        qform_root0_tw .req q4
        qform_root1_tw .req q5
        qform_root2_tw .req q6
        qform_root3_tw .req q7

        sub inp, inp, #64
        sub inpp, inpp, #64

        .p2align 2
        ldr_vi v12, x4, 64
        ldr_vo v6, x2, 112
        ldr_vo v2, x2, 96
        ldr_vo v20, x2, 64
        sqrdmulh v7.4S, v6.4S, v12.S[1]
        mul v9.4S, v6.4S, v12.S[0]
        ldr_vo v19, x1, 112
        sqrdmulh v30.4S, v2.4S, v12.S[1]
        mul v2.4S, v2.4S, v12.S[0]
        ldr_vo v6, x2, 80
        mul v1.4S, v20.4S, v12.S[0]
        add x2, x2, #64
        mls v9.4S, v7.4S, v8.S[0]
        ldr_vo v3, x1, 96
        sqrdmulh v5.4S, v20.4S, v12.S[1]
        mls v2.4S, v30.4S, v8.S[0]
        ldr_vo v29, x4, -48
        mul v4.4S, v6.4S, v12.S[0]
        add v14.4S, v19.4S, v9.4S
        sqrdmulh v16.4S, v6.4S, v12.S[1]
        sub v24.4S, v19.4S, v9.4S
        ldr_vo v20, x4, -16
        mul v22.4S, v14.4S, v12.S[2]
        add v30.4S, v3.4S, v2.4S
        sqrdmulh v11.4S, v14.4S, v12.S[3]
        sub v17.4S, v3.4S, v2.4S
        ldr_vo v13, x1, 80
        mul v18.4S, v24.4S, v29.S[0]
        mls v4.4S, v16.4S, v8.S[0]
        ldr_vo v9, x4, -32
        sqrdmulh v6.4S, v24.4S, v29.S[1]
        mls v22.4S, v11.4S, v8.S[0]
        ldr_vo v15, x1, 64
        mul v10.4S, v30.4S, v12.S[2]
        add v27.4S, v13.4S, v4.4S
        sqrdmulh v21.4S, v30.4S, v12.S[3]
        sub v26.4S, v13.4S, v4.4S
        add x1, x1, #64
        ldr_vi v0, x5, 192
        mls v18.4S, v6.4S, v8.S[0]
        add v4.4S, v27.4S, v22.4S
        sqrdmulh v25.4S, v17.4S, v29.S[1]
        sub v14.4S, v27.4S, v22.4S
        ldr_vo v3, x4, -16
        mul v27.4S, v4.4S, v29.S[2]
        sqrdmulh v6.4S, v4.4S, v29.S[3]
        ldr_vo v2, x5, -128
        mul v23.4S, v14.4S, v9.S[0]
        mls v1.4S, v5.4S, v8.S[0]
        add v11.4S, v26.4S, v18.4S
        sub v18.4S, v26.4S, v18.4S
        ldr_vo v19, x5, -336
        mls v10.4S, v21.4S, v8.S[0]
        mls v27.4S, v6.4S, v8.S[0]
        ldr_vo v28, x5, -160
        sqrdmulh v7.4S, v14.4S, v9.S[1]
        add v31.4S, v15.4S, v1.4S
        sub v22.4S, v15.4S, v1.4S
        ldr_vo v13, x5, -368
        mul v29.4S, v17.4S, v29.S[0]
        add v12.4S, v31.4S, v10.4S
        sqrdmulh v15.4S, v11.4S, v9.S[3]
        sub v31.4S, v31.4S, v10.4S
        ldr_vo v10, x5, -304
        mul v11.4S, v11.4S, v9.S[2]
        add v1.4S, v12.4S, v27.4S
        mls v23.4S, v7.4S, v8.S[0]
        sub v7.4S, v12.4S, v27.4S
        ldr_vo v12, x5, -96
        mls v29.4S, v25.4S, v8.S[0]
        trn2 v25.4S, v1.4S, v7.4S
        sqrdmulh v30.4S, v18.4S, v20.S[1]
        trn1 v7.4S, v1.4S, v7.4S
        ldr_vo v24, x5, -80
        mul v18.4S, v18.4S, v20.S[0]
        add v1.4S, v31.4S, v23.4S
        sub v23.4S, v31.4S, v23.4S
        ldr_vo v31, x5, -64
        mls v11.4S, v15.4S, v8.S[0]
        trn2 v15.4S, v1.4S, v23.4S
        trn1 v23.4S, v1.4S, v23.4S
        sub v1.4S, v22.4S, v29.4S
        ldr_vo v21, x5, -48
        add v22.4S, v22.4S, v29.4S
        trn2 v29.2D, v7.2D, v23.2D
        mls v18.4S, v30.4S, v8.S[0]
        trn2 v30.2D, v25.2D, v15.2D
        ldr_vo v17, x5, -32
        mul v9.4S, v29.4S, v0.4S
        add v16.4S, v22.4S, v11.4S
        mul v26.4S, v30.4S, v0.4S
        sub v11.4S, v22.4S, v11.4S
        ldr_vo v6, x5, -16
        sqrdmulh v22.4S, v29.4S, v13.4S
        add v29.4S, v1.4S, v18.4S
        sqrdmulh v13.4S, v30.4S, v13.4S
        mls v26.4S, v13.4S, v8.S[0]
        trn1 v20.2D, v25.2D, v15.2D
        trn2 v27.4S, v16.4S, v11.4S
        sub v18.4S, v1.4S, v18.4S
        ldr_vi v4, x4, 64
        trn1 v14.4S, v29.4S, v18.4S
        trn2 v15.4S, v29.4S, v18.4S
        mls v9.4S, v22.4S, v8.S[0]
        trn1 v30.4S, v16.4S, v11.4S
        ldr_vo v1, x2, 160
        trn1 v13.2D, v30.2D, v14.2D
        trn2 v16.2D, v30.2D, v14.2D
        trn2 v5.2D, v27.2D, v15.2D
        add v14.4S, v20.4S, v26.4S
        mul v29.4S, v5.4S, v12.4S
        sub v0.4S, v20.4S, v26.4S
        sqrdmulh v5.4S, v5.4S, v24.4S
        trn1 v18.2D, v27.2D, v15.2D
        mul v22.4S, v16.4S, v12.4S
        trn1 v12.2D, v7.2D, v23.2D
        sqrdmulh v30.4S, v16.4S, v24.4S
        mls v29.4S, v5.4S, v8.S[0]
        mul v27.4S, v0.4S, v2.4S
        ldr_vo v5, x1, 176
        sqrdmulh v25.4S, v14.4S, v19.4S
        mls v22.4S, v30.4S, v8.S[0]
        ldr_vo v19, x2, 144
        mul v11.4S, v14.4S, v28.4S
        sub v2.4S, v18.4S, v29.4S
        sqrdmulh v15.4S, v1.4S, v4.S[1]
        add v28.4S, v12.4S, v9.4S
        ldr_vo v24, x2, 176
        sqrdmulh v20.4S, v2.4S, v6.4S
        add v18.4S, v18.4S, v29.4S
        mul v30.4S, v2.4S, v17.4S
        add v16.4S, v13.4S, v22.4S
        ldr_vo v2, x1, 160
        mul v29.4S, v1.4S, v4.S[0]
        sub v26.4S, v13.4S, v22.4S
        sqrdmulh v23.4S, v0.4S, v10.4S
        ldr_vo v1, x2, 128
        mls v30.4S, v20.4S, v8.S[0]
        sqrdmulh v7.4S, v18.4S, v21.4S
        ldr_vi v0, x5, 192
        mls v29.4S, v15.4S, v8.S[0]
        mul v20.4S, v18.4S, v31.4S
        mul v17.4S, v24.4S, v4.S[0]
        add v14.4S, v26.4S, v30.4S
        lsr count, count, #1
        sub count, count, #1
.p2align 2
layer45678_start:
        sqrdmulh v31.4S, v24.4S, v4.S[1]
        add v10.4S, v2.4S, v29.4S
        sqrdmulh v24.4S, v19.4S, v4.S[1]
        sub v13.4S, v2.4S, v29.4S                            // gap(s) to follow
        ldr_vo v6, x1, 128
        mul v22.4S, v10.4S, v4.S[2]                          // gap(s) to follow
        mul v21.4S, v19.4S, v4.S[0]
        sub v15.4S, v26.4S, v30.4S                           // gap(s) to follow
        ldr_vo v26, x4, -32
        mls v17.4S, v31.4S, v8.S[0]                          // gap(s) to follow
        sqrdmulh v31.4S, v1.4S, v4.S[1]                      // gap(s) to follow
        ldr_vo v18, x4, -48
        mul v29.4S, v1.4S, v4.S[0]                           // gap(s) to follow
        mls v27.4S, v23.4S, v8.S[0]
        sub v19.4S, v12.4S, v9.4S                            // gap(s) to follow
        ldr_vo v12, x1, 144
        mls v21.4S, v24.4S, v8.S[0]                          // gap(s) to follow
        sqrdmulh v9.4S, v10.4S, v4.S[3]
        sub v30.4S, v5.4S, v17.4S                            // gap(s) to follow
        sqrdmulh v10.4S, v30.4S, v18.S[1]                    // gap(s) to follow
        mul v30.4S, v30.4S, v18.S[0]
        add v5.4S, v5.4S, v17.4S                             // gap(s) to follow
        mul v2.4S, v5.4S, v4.S[2]
        sub v17.4S, v12.4S, v21.4S
        sqrdmulh v4.4S, v5.4S, v4.S[3]
        add v21.4S, v12.4S, v21.4S                           // gap(s) to follow
        mls v11.4S, v25.4S, v8.S[0]                          // gap(s) to follow
        mls v30.4S, v10.4S, v8.S[0]                          // gap(s) to follow
        mls v29.4S, v31.4S, v8.S[0]                          // gap(s) to follow
        mls v2.4S, v4.4S, v8.S[0]                            // gap(s) to follow
        mls v20.4S, v7.4S, v8.S[0]
        sub v1.4S, v17.4S, v30.4S
        mul v5.4S, v13.4S, v18.S[0]
        add v30.4S, v17.4S, v30.4S                           // gap(s) to follow
        mls v22.4S, v9.4S, v8.S[0]
        add v10.4S, v21.4S, v2.4S
        mul v7.4S, v1.4S, v3.S[0]
        add v17.4S, v6.4S, v29.4S                            // gap(s) to follow
        sqrdmulh v9.4S, v13.4S, v18.S[1]
        sub v13.4S, v16.4S, v20.4S
        mul v31.4S, v30.4S, v26.S[2]
        sub v12.4S, v21.4S, v2.4S                            // gap(s) to follow
        sqrdmulh v23.4S, v1.4S, v3.S[1]
        sub v6.4S, v6.4S, v29.4S
        mul v3.4S, v12.4S, v26.S[0]
        add v4.4S, v17.4S, v22.4S                            // gap(s) to follow
        mls v5.4S, v9.4S, v8.S[0]
        add v29.4S, v19.4S, v27.4S
        sqrdmulh v24.4S, v30.4S, v26.S[3]
        sub v30.4S, v19.4S, v27.4S
        mls v7.4S, v23.4S, v8.S[0]
        sub v1.4S, v6.4S, v5.4S                              // gap(s) to follow
        ldr_vo v25, x5, -32
        sqrdmulh v9.4S, v12.4S, v26.S[1]
        add v27.4S, v28.4S, v11.4S
        mul v19.4S, v10.4S, v18.S[2]
        add v2.4S, v6.4S, v5.4S                              // gap(s) to follow
        sqrdmulh v26.4S, v10.4S, v18.S[3]
        add v21.4S, v1.4S, v7.4S
        mls v31.4S, v24.4S, v8.S[0]
        sub v12.4S, v1.4S, v7.4S                             // gap(s) to follow
        ldr_vo v24, x5, -368
        sub v1.4S, v17.4S, v22.4S
        trn2 v6.4S, v21.4S, v12.4S
        mls v3.4S, v9.4S, v8.S[0]
        trn1 v21.4S, v21.4S, v12.4S                          // gap(s) to follow
        ldr_vo v9, x5, -80
        mls v19.4S, v26.4S, v8.S[0]
        sub v10.4S, v2.4S, v31.4S
        add v18.4S, v2.4S, v31.4S
        sub v28.4S, v28.4S, v11.4S                           // gap(s) to follow
        ldr_vo v17, x5, -96
        sub v22.4S, v1.4S, v3.4S
        add v2.4S, v1.4S, v3.4S
        trn2 v3.4S, v18.4S, v10.4S
        trn1 v18.4S, v18.4S, v10.4S                          // gap(s) to follow
        ldr_vo v23, x5, -16
        sub v5.4S, v4.4S, v19.4S
        add v26.4S, v4.4S, v19.4S
        trn2 v7.2D, v3.2D, v6.2D                             // gap(s) to follow
        trn2 v4.2D, v18.2D, v21.2D
        mul v1.4S, v7.4S, v17.4S
        st4 {v27.4S,v28.4S,v29.4S,v30.4S}, [x1], #64
        sqrdmulh v28.4S, v7.4S, v9.4S
        trn2 v31.4S, v2.4S, v22.4S
        trn2 v10.4S, v26.4S, v5.4S
        ldr_vo v7, x5, -64
        sqrdmulh v19.4S, v4.4S, v9.4S                        // gap(s) to follow
        mul v17.4S, v4.4S, v17.4S
        add v12.4S, v16.4S, v20.4S
        trn2 v4.2D, v10.2D, v31.2D
        ldr_vo v9, x5, -128
        mls v1.4S, v28.4S, v8.S[0]
        st4 {v12.4S,v13.4S,v14.4S,v15.4S}, [x2], #64
        sqrdmulh v20.4S, v4.4S, v24.4S
        add x2, x2, #64
        mls v17.4S, v19.4S, v8.S[0]
        trn1 v21.2D, v18.2D, v21.2D
        mul v11.4S, v4.4S, v0.4S
        trn1 v14.2D, v3.2D, v6.2D
        add x16, x1, #64
        ldr_vo v18, x5, -48
        sub v30.4S, v14.4S, v1.4S
        add v12.4S, v14.4S, v1.4S
        trn1 v27.4S, v2.4S, v22.4S
        trn1 v1.2D, v10.2D, v31.2D                           // gap(s) to follow
        ldr_vo v16, x2, 112
        mul v2.4S, v12.4S, v7.4S
        sub v19.4S, v21.4S, v17.4S
        sqrdmulh v22.4S, v30.4S, v23.4S
        trn1 v13.4S, v26.4S, v5.4S                           // gap(s) to follow
        ldr_vo v6, x5, -304
        mul v25.4S, v30.4S, v25.4S                           // gap(s) to follow
        sqrdmulh v23.4S, v12.4S, v18.4S
        trn2 v18.2D, v13.2D, v27.2D                          // gap(s) to follow
        ldr_vo v14, x2, 144
        mul v30.4S, v18.4S, v0.4S                            // gap(s) to follow
        mls v11.4S, v20.4S, v8.S[0]                          // gap(s) to follow
        ldr_vo v31, x16, 96
        mls v25.4S, v22.4S, v8.S[0]                          // gap(s) to follow
        mls v2.4S, v23.4S, v8.S[0]                           // gap(s) to follow
        ldr_vi v28, x4, 64
        add v7.4S, v21.4S, v17.4S
        sub v17.4S, v1.4S, v11.4S
        sqrdmulh v12.4S, v18.4S, v24.4S                      // gap(s) to follow
        ldr_vo v18, x2, 96
        sub v24.4S, v7.4S, v2.4S
        add v23.4S, v7.4S, v2.4S
        sub v26.4S, v19.4S, v25.4S
        add v25.4S, v19.4S, v25.4S                           // gap(s) to follow
        ldr_vo v29, x2, 128
        st4 {v23.4S,v24.4S,v25.4S,v26.4S}, [x2], #64
        add x2, x2, #64
        mul v7.4S, v17.4S, v9.4S
        add v25.4S, v1.4S, v11.4S                            // gap(s) to follow
        ldr_vo v24, x16, 112
        sqrdmulh v26.4S, v17.4S, v6.4S                       // gap(s) to follow
        mul v4.4S, v16.4S, v28.S[0]                          // gap(s) to follow
        ldr_vo v5, x5, -160
        mls v30.4S, v12.4S, v8.S[0]                          // gap(s) to follow
        sqrdmulh v19.4S, v29.4S, v28.S[1]                    // gap(s) to follow
        ldr_vo v11, x5, -336
        mul v1.4S, v29.4S, v28.S[0]                          // gap(s) to follow
        mul v29.4S, v14.4S, v28.S[0]                         // gap(s) to follow
        sqrdmulh v6.4S, v25.4S, v11.4S
        trn1 v10.2D, v13.2D, v27.2D
        sqrdmulh v2.4S, v16.4S, v28.S[1]                     // gap(s) to follow
        ldr_vi v27, x5, 192
        sqrdmulh v9.4S, v18.4S, v28.S[1]
        add x1, x16, #64
        mul v20.4S, v18.4S, v28.S[0]
        add v18.4S, v10.4S, v30.4S                           // gap(s) to follow
        ldr_vo v0, x16, 64
        sqrdmulh v16.4S, v14.4S, v28.S[1]                    // gap(s) to follow
        mls v4.4S, v2.4S, v8.S[0]                            // gap(s) to follow
        ldr_vo v23, x4, -32
        mul v17.4S, v25.4S, v5.4S                            // gap(s) to follow
        mls v20.4S, v9.4S, v8.S[0]                           // gap(s) to follow
        ldr_vo v22, x4, -112
        mls v1.4S, v19.4S, v8.S[0]
        add v9.4S, v24.4S, v4.4S
        mls v7.4S, v26.4S, v8.S[0]                           // gap(s) to follow
        ldr_vo v19, x16, 144
        sqrdmulh v11.4S, v9.4S, v28.S[3]
        add v14.4S, v31.4S, v20.4S
        mls v29.4S, v16.4S, v8.S[0]
        sub v26.4S, v31.4S, v20.4S                           // gap(s) to follow
        ldr_vo v2, x5, -128
        mul v16.4S, v9.4S, v28.S[2]
        sub v5.4S, v24.4S, v4.4S
        mul v24.4S, v26.4S, v22.S[0]
        add v25.4S, v0.4S, v1.4S                             // gap(s) to follow
        ldr_vo v31, x5, -64
        mul v15.4S, v5.4S, v22.S[0]
        sub v21.4S, v19.4S, v29.4S
        sqrdmulh v4.4S, v5.4S, v22.S[1]                      // gap(s) to follow
        ldr_vo v3, x4, -16
        mls v16.4S, v11.4S, v8.S[0]
        add v9.4S, v19.4S, v29.4S
        sqrdmulh v5.4S, v14.4S, v28.S[3]
        sub v29.4S, v10.4S, v30.4S                           // gap(s) to follow
        ldr_vo v19, x5, -336
        mls v17.4S, v6.4S, v8.S[0]
        sub v12.4S, v29.4S, v7.4S
        mls v15.4S, v4.4S, v8.S[0]
        add v11.4S, v29.4S, v7.4S                            // gap(s) to follow
        ldr_vo v13, x5, -368
        sqrdmulh v20.4S, v26.4S, v22.S[1]
        sub v26.4S, v9.4S, v16.4S
        mul v6.4S, v14.4S, v28.S[2]
        add v4.4S, v9.4S, v16.4S                             // gap(s) to follow
        ldr_vo v7, x4, -16
        mul v29.4S, v4.4S, v22.S[2]
        sub v30.4S, v21.4S, v15.4S
        sqrdmulh v14.4S, v4.4S, v22.S[3]
        add v21.4S, v21.4S, v15.4S                           // gap(s) to follow
        ldr_vo v15, x5, -352
        mls v6.4S, v5.4S, v8.S[0]
        add v9.4S, v18.4S, v17.4S
        mul v5.4S, v30.4S, v7.S[0]
        sub v10.4S, v18.4S, v17.4S                           // gap(s) to follow
        ldr_vi v4, x4, 64
        sqrdmulh v28.4S, v30.4S, v7.S[1]
        st4 {v9.4S,v10.4S,v11.4S,v12.4S}, [x16], #64
        mls v29.4S, v14.4S, v8.S[0]
        sub v7.4S, v0.4S, v1.4S                              // gap(s) to follow
        ldr_vo v9, x2, 160
        mls v24.4S, v20.4S, v8.S[0]
        add v22.4S, v25.4S, v6.4S
        mul v16.4S, v26.4S, v23.S[0]
        sub v6.4S, v25.4S, v6.4S                             // gap(s) to follow
        ldr_vo v10, x5, -96
        mls v5.4S, v28.4S, v8.S[0]
        sub v18.4S, v22.4S, v29.4S
        sqrdmulh v20.4S, v26.4S, v23.S[1]
        add v28.4S, v22.4S, v29.4S                           // gap(s) to follow
        mul v14.4S, v21.4S, v23.S[2]
        add v17.4S, v7.4S, v24.4S
        sqrdmulh v0.4S, v21.4S, v23.S[3]
        sub v21.4S, v7.4S, v24.4S                            // gap(s) to follow
        ldr_vo v1, x5, -16
        trn1 v11.4S, v28.4S, v18.4S
        add v12.4S, v21.4S, v5.4S
        mls v16.4S, v20.4S, v8.S[0]
        sub v20.4S, v21.4S, v5.4S                            // gap(s) to follow
        mls v14.4S, v0.4S, v8.S[0]
        trn2 v5.4S, v28.4S, v18.4S
        sqrdmulh v21.4S, v9.4S, v4.S[1]
        trn1 v30.4S, v12.4S, v20.4S                          // gap(s) to follow
        ldr_vo v24, x2, 176
        add v22.4S, v6.4S, v16.4S
        sub v23.4S, v6.4S, v16.4S
        mul v29.4S, v9.4S, v4.S[0]
        trn2 v12.4S, v12.4S, v20.4S                          // gap(s) to follow
        ldr_vo v26, x5, -80
        sub v7.4S, v17.4S, v14.4S
        add v16.4S, v17.4S, v14.4S
        trn2 v28.4S, v22.4S, v23.4S
        trn1 v22.4S, v22.4S, v23.4S                          // gap(s) to follow
        mls v29.4S, v21.4S, v8.S[0]
        trn2 v21.2D, v11.2D, v22.2D
        mul v17.4S, v24.4S, v4.S[0]
        trn2 v23.4S, v16.4S, v7.4S                           // gap(s) to follow
        sqrdmulh v18.4S, v21.4S, v13.4S                      // gap(s) to follow
        mul v9.4S, v21.4S, v27.4S
        trn2 v21.2D, v23.2D, v12.2D                          // gap(s) to follow
        mul v14.4S, v21.4S, v10.4S
        trn1 v20.2D, v5.2D, v28.2D
        sqrdmulh v21.4S, v21.4S, v26.4S                      // gap(s) to follow
        trn2 v5.2D, v5.2D, v28.2D
        sqrdmulh v28.4S, v5.4S, v13.4S
        trn1 v0.4S, v16.4S, v7.4S
        mul v16.4S, v5.4S, v27.4S
        trn1 v5.2D, v23.2D, v12.2D                           // gap(s) to follow
        ldr_vo v7, x5, -32
        mls v9.4S, v18.4S, v8.S[0]
        trn2 v6.2D, v0.2D, v30.2D
        mls v14.4S, v21.4S, v8.S[0]                          // gap(s) to follow
        ldr_vo v23, x5, -48
        sqrdmulh v12.4S, v6.4S, v26.4S
        trn1 v21.2D, v0.2D, v30.2D
        mls v16.4S, v28.4S, v8.S[0]                          // gap(s) to follow
        ldr_vi v0, x5, 192
        sub v18.4S, v5.4S, v14.4S                            // gap(s) to follow
        mul v6.4S, v6.4S, v10.4S                             // gap(s) to follow
        mul v30.4S, v18.4S, v7.4S
        add v7.4S, v20.4S, v16.4S
        sqrdmulh v26.4S, v18.4S, v1.4S
        sub v10.4S, v20.4S, v16.4S                           // gap(s) to follow
        ldr_vo v13, x5, -496
        mls v6.4S, v12.4S, v8.S[0]
        trn1 v12.2D, v11.2D, v22.2D
        mul v27.4S, v10.4S, v2.4S                            // gap(s) to follow
        ldr_vo v1, x2, 128
        mls v30.4S, v26.4S, v8.S[0]
        add v18.4S, v5.4S, v14.4S
        sqrdmulh v25.4S, v7.4S, v19.4S                       // gap(s) to follow
        ldr_vo v5, x1, 176
        mul v11.4S, v7.4S, v15.4S
        sub v26.4S, v21.4S, v6.4S
        mul v20.4S, v18.4S, v31.4S
        add v16.4S, v21.4S, v6.4S                            // gap(s) to follow
        ldr_vo v2, x1, 160
        sqrdmulh v7.4S, v18.4S, v23.4S
        add v14.4S, v26.4S, v30.4S
        sqrdmulh v23.4S, v10.4S, v13.4S
        add v28.4S, v12.4S, v9.4S                            // gap(s) to follow
        ldr_vo v19, x2, 144                                  // gap(s) to follow
        subs count, count, #1
        cbnz count, layer45678_start
        mls v11.4S, v25.4S, v8.S[0]
        sub v15.4S, v26.4S, v30.4S
        sqrdmulh v24.4S, v24.4S, v4.S[1]
        add v25.4S, v2.4S, v29.4S
        ldr_vo v13, x4, -48
        mul v6.4S, v19.4S, v4.S[0]
        sub v10.4S, v2.4S, v29.4S
        sqrdmulh v31.4S, v25.4S, v4.S[3]
        ldr_vo v30, x1, 144
        mls v17.4S, v24.4S, v8.S[0]
        add v21.4S, v28.4S, v11.4S
        sqrdmulh v18.4S, v19.4S, v4.S[1]
        sub v22.4S, v28.4S, v11.4S
        mls v27.4S, v23.4S, v8.S[0]
        sqrdmulh v19.4S, v10.4S, v13.S[1]
        mls v6.4S, v18.4S, v8.S[0]
        sub v24.4S, v5.4S, v17.4S
        sqrdmulh v28.4S, v1.4S, v4.S[1]
        add v5.4S, v5.4S, v17.4S
        ldr_vo v18, x4, -32
        sqrdmulh v17.4S, v24.4S, v13.S[1]
        mul v24.4S, v24.4S, v13.S[0]
        sqrdmulh v26.4S, v5.4S, v4.S[3]
        mul v2.4S, v5.4S, v4.S[2]
        add v29.4S, v30.4S, v6.4S
        mls v24.4S, v17.4S, v8.S[0]
        mul v5.4S, v1.4S, v4.S[0]
        sub v6.4S, v30.4S, v6.4S
        ldr_vo v30, x1, 128
        mls v2.4S, v26.4S, v8.S[0]
        mul v11.4S, v25.4S, v4.S[2]
        sub v25.4S, v12.4S, v9.4S
        mls v5.4S, v28.4S, v8.S[0]
        add v17.4S, v6.4S, v24.4S
        mul v28.4S, v10.4S, v13.S[0]
        sub v6.4S, v6.4S, v24.4S
        mul v1.4S, v6.4S, v3.S[0]
        add v12.4S, v29.4S, v2.4S
        sqrdmulh v9.4S, v6.4S, v3.S[1]
        sub v26.4S, v29.4S, v2.4S
        mls v28.4S, v19.4S, v8.S[0]
        add v2.4S, v30.4S, v5.4S
        mul v19.4S, v26.4S, v18.S[0]
        sub v5.4S, v30.4S, v5.4S
        mls v1.4S, v9.4S, v8.S[0]
        add v23.4S, v25.4S, v27.4S
        sqrdmulh v4.4S, v26.4S, v18.S[1]
        sub v24.4S, v25.4S, v27.4S
        mul v10.4S, v17.4S, v18.S[2]
        st4 {v21.4S,v22.4S,v23.4S,v24.4S}, [x1], #64
        sqrdmulh v3.4S, v17.4S, v18.S[3]
        sub v6.4S, v5.4S, v28.4S
        ldr_vo v29, x5, -304
        mls v11.4S, v31.4S, v8.S[0]
        add v27.4S, v6.4S, v1.4S
        mul v26.4S, v12.4S, v13.S[2]
        sub v1.4S, v6.4S, v1.4S
        ldr_vo v25, x5, -96
        mls v10.4S, v3.4S, v8.S[0]
        trn1 v24.4S, v27.4S, v1.4S
        sqrdmulh v30.4S, v12.4S, v13.S[3]
        trn2 v21.4S, v27.4S, v1.4S
        add x1, x1, #64
        ldr_vo v18, x5, -80
        mls v19.4S, v4.4S, v8.S[0]
        add v6.4S, v2.4S, v11.4S
        mls v20.4S, v7.4S, v8.S[0]
        add v9.4S, v5.4S, v28.4S
        mls v26.4S, v30.4S, v8.S[0]
        sub v4.4S, v2.4S, v11.4S
        add v27.4S, v9.4S, v10.4S
        sub v3.4S, v9.4S, v10.4S
        ldr_vo v9, x5, -64
        trn1 v5.4S, v27.4S, v3.4S
        sub v28.4S, v4.4S, v19.4S
        trn2 v7.4S, v27.4S, v3.4S
        add v11.4S, v4.4S, v19.4S
        ldr_vo v10, x5, -48
        trn2 v17.4S, v11.4S, v28.4S
        trn2 v30.2D, v7.2D, v21.2D
        sub v22.4S, v6.4S, v26.4S
        add v2.4S, v6.4S, v26.4S
        ldr_vo v26, x5, -368
        mul v4.4S, v30.4S, v25.4S
        trn2 v1.2D, v5.2D, v24.2D
        sqrdmulh v31.4S, v30.4S, v18.4S
        trn2 v23.4S, v2.4S, v22.4S
        ldr_vo v30, x5, -160
        mul v27.4S, v1.4S, v25.4S
        trn1 v22.4S, v2.4S, v22.4S
        sqrdmulh v6.4S, v1.4S, v18.4S
        trn2 v19.2D, v23.2D, v17.2D
        ldr_vo v1, x5, -16
        mls v4.4S, v31.4S, v8.S[0]
        trn1 v21.2D, v7.2D, v21.2D
        mul v2.4S, v19.4S, v0.4S
        trn1 v25.4S, v11.4S, v28.4S
        ldr_vo v28, x5, -32
        mls v27.4S, v6.4S, v8.S[0]
        trn2 v11.2D, v22.2D, v25.2D
        sqrdmulh v31.4S, v19.4S, v26.4S
        sqrdmulh v6.4S, v11.4S, v26.4S
        add v7.4S, v21.4S, v4.4S
        mul v3.4S, v11.4S, v0.4S
        sub v18.4S, v21.4S, v4.4S
        mls v2.4S, v31.4S, v8.S[0]
        trn1 v19.2D, v23.2D, v17.2D
        sqrdmulh v31.4S, v7.4S, v10.4S
        ldr_vo v21, x5, -128
        mul v17.4S, v7.4S, v9.4S
        mls v3.4S, v6.4S, v8.S[0]
        sub v13.4S, v16.4S, v20.4S
        ldr_vo v10, x5, -336
        mul v23.4S, v18.4S, v28.4S
        sub v28.4S, v19.4S, v2.4S
        sqrdmulh v0.4S, v18.4S, v1.4S
        add v19.4S, v19.4S, v2.4S
        mul v4.4S, v28.4S, v21.4S
        trn1 v7.2D, v5.2D, v24.2D
        sqrdmulh v9.4S, v28.4S, v29.4S
        trn1 v2.2D, v22.2D, v25.2D
        mul v26.4S, v19.4S, v30.4S
        add v30.4S, v2.4S, v3.4S
        sqrdmulh v11.4S, v19.4S, v10.4S
        add v12.4S, v16.4S, v20.4S
        mls v17.4S, v31.4S, v8.S[0]
        st4 {v12.4S,v13.4S,v14.4S,v15.4S}, [x2], #64
        mls v4.4S, v9.4S, v8.S[0]
        add v18.4S, v7.4S, v27.4S
        mls v23.4S, v0.4S, v8.S[0]
        sub v6.4S, v7.4S, v27.4S
        mls v26.4S, v11.4S, v8.S[0]
        sub v31.4S, v2.4S, v3.4S
        sub v20.4S, v18.4S, v17.4S
        add v12.4S, v31.4S, v4.4S
        add v19.4S, v18.4S, v17.4S
        sub v13.4S, v31.4S, v4.4S
        add x2, x2, #64
        sub v22.4S, v6.4S, v23.4S
        add v10.4S, v30.4S, v26.4S
        add v21.4S, v6.4S, v23.4S
        sub v11.4S, v30.4S, v26.4S
        st4 {v19.4S,v20.4S,v21.4S,v22.4S}, [x2], #64
        st4 {v10.4S,v11.4S,v12.4S,v13.4S}, [x1], #64

       pop_stack
       ret
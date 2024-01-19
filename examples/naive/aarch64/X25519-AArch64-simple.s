/* X25519-AArch64 by Emil Lenngren (2018)
 *
 * To the extent possible under law, the person who associated CvC0 with
 * X25519-AArch64 has waived all copyright and related or neighboring rights
 * to X25519-AArch64.
 *
 * You should have received a copy of the CvC0 legalcode along with this
 * work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

/*
 * This is an AArch64 implementation of X25519.
 * It follows the reference implementation where the representation of
 * a field element [0..2^255-19) is represented by a 256-bit little endian integer,
 * reduced modulo 2^256-38, and may possibly be in the range [2^256-38..2^256).
 * The scalar is a 256-bit integer where certain bits are hardcoded per specification.
 *
 * The implementation runs in constant time (~145k cycles on Cortex-vA53),
 * and no conditional branches or memory access pattern depend on secret data.
 */

#include <hal_env.h>
#include "instruction_wrappers.i"


.macro vmull out, in0, in1
  umull \out\().2d, \in0\().2s, \in1\().2s
.endm

.macro vmlal out, in0, in1
  umlal \out\().2d, \in0\().2s, \in1\().2s
.endm

.macro vmul out, in0, in1
  mul \out\().2s, \in0\().2s, \in1\().2s
.endm

.macro vshl_d out, in, shift
  shl \out\().2d, \in\().2d, \shift
.endm

.macro vshl_s out, in, shift
  shl \out\().2s, \in\().2s, \shift
.endm

.macro vushr out, in, shift
  ushr \out\().2d, \in\().2d, \shift
.endm

.macro vusra out, in, shift
  usra \out\().2d, \in\().2d, \shift
.endm

.macro vand out, in0, in1
  and \out\().16b, \in0\().16b, \in1\().16b
.endm

.macro vbic out, in0, in1
  bic \out\().16b, \in0\().16b, \in1\().16b
.endm

.macro trn1_s out, in0, in1
  trn1 \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vuzp1 out, in0, in1
  uzp1 \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vuzp2 out, in0, in1
  uzp2 \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vzip1_4s out, in0, in1
  zip1 \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vzip1_2s out, in0, in1
  zip1 \out\().2s, \in0\().2s, \in1\().2s
.endm

.macro vzip2_4s out, in0, in1
  zip2 \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vzip2_2s out, in0, in1
  zip2 \out\().2s, \in0\().2s, \in1\().2s
.endm


.macro mov_d01 out, in
  mov \out\().d[0], \in\().d[1]
.endm

.macro mov_b00 out, in
  mov \out\().b[0], \in\().b[0]
.endm

.macro vadd_4s out, in0, in1
  add \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vadd_2s out, in0, in1
  add \out\().2s, \in0\().2s, \in1\().2s
.endm

.macro vsub_4s out, in0, in1
  sub \out\().4s, \in0\().4s, \in1\().4s
.endm

.macro vsub_2s out, in0, in1
  sub \out\().2s, \in0\().2s, \in1\().2s
.endm

# TODO: also unwrap
.macro fcsel_dform out, in0, in1, cond // @slothy:no-unfold
  fcsel dform_\out, dform_\in0, dform_\in1, \cond
.endm

.macro trn2_2s out, in0, in1
    trn2 \out\().2s, \in0\().2s, \in1\().2s
.endm

.macro trn1_2s out, in0, in1
    trn1 \out\().2s, \in0\().2s, \in1\().2s
.endm


    .cpu generic+fp+simd
    .text
    .align    2

    // in: x0: pointer
    // out: x0: loaded value
    // .type    load64unaligned, %function
load64unaligned:
    ldrb w1, [x0]
    ldrb w2, [x0, #1]
    ldrb w3, [x0, #2]
    ldrb w4, [x0, #3]
    ldrb w5, [x0, #4]
    ldrb w6, [x0, #5]
    ldrb w7, [x0, #6]
    ldrb w8, [x0, #7]

    orr    w1, w1, w2, lsl #8
    orr    w3, w3, w4, lsl #8
    orr    w5, w5, w6, lsl #8
    orr    w7, w7, w8, lsl #8

    orr    w1, w1, w3, lsl #16
    orr    w5, w5, w7, lsl #16

    orr    x0, x1, x5, lsl #32

    ret
    // .size    load64unaligned, .-load64unaligned

    // in: x0: pointer
    // out: x0-x3: loaded value
    // .type    load256unaligned, %function
load256unaligned:
    stp    x29, x30, [sp, #-64]!
    mov    x29, sp
    stp    x19, x20, [sp, #16]
    stp    x21, x22, [sp, #32]

    mov    x19, x0
    bl    load64unaligned
    mov    x20, x0
    add    x0, x19, #8
    bl    load64unaligned
    mov    x21, x0
    add    x0, x19, #16
    bl    load64unaligned
    mov    x22, x0
    add    x0, x19, #24
    bl    load64unaligned
    mov    x3, x0

    mov    x0, x20
    mov    x1, x21
    mov    x2, x22

    ldp    x19, x20, [sp, #16]
    ldp    x21, x22, [sp, #32]
    ldp    x29, x30, [sp], #64
    ret
    // .size load256unaligned, .-load256unaligned

vAB0 .req v0
vAB1 .req v1
vAB2 .req v2
vAB3 .req v3
vAB4 .req v4
vAB5 .req v5
vAB6 .req v6
vAB7 .req v7
vAB8 .req v8
vAB9 .req v9

vT0  .req vAB0
vT1  .req vAB1
vT2  .req vAB2
vT3  .req vAB3
vT4  .req vAB4
vT5  .req vAB5
vT6  .req vAB6
vT7  .req vAB7
vT8  .req vAB8
vT9  .req vAB9

vTA0 .req vAB0
vTA1 .req vAB1
vTA2 .req vAB2
vTA3 .req vAB3
vTA4 .req vAB4
vTA5 .req vAB5
vTA6 .req vAB6
vTA7 .req vAB7
vTA8 .req vAB8
vTA9 .req vAB9

vBX0 .req v10
vBX1 .req v11
vBX2 .req v12
vBX3 .req v13
vBX4 .req v14
vBX5 .req v15
vBX6 .req v16
vBX7 .req v17
vBX8 .req v18
vBX9 .req v19

vDC0  .req vBX0
vDC1  .req vBX1
vDC2  .req vBX2
vDC3  .req vBX3
vDC4  .req vBX4
vDC5  .req vBX5
vDC6  .req vBX6
vDC7  .req vBX7
vDC8  .req vBX8
vDC9  .req vBX9

vADBC0 .req v20
vADBC1 .req v21
vADBC2 .req v22
vADBC3 .req v23
vADBC4 .req v24
vADBC5 .req v25
vADBC6 .req v26
vADBC7 .req v27
vADBC8 .req v28
vADBC9 .req v29

vX4Z50 .req vADBC0
vX4Z51 .req vADBC1
vX4Z52 .req vADBC2
vX4Z53 .req vADBC3
vX4Z54 .req vADBC4
vX4Z55 .req vADBC5
vX4Z56 .req vADBC6
vX4Z57 .req vADBC7
vX4Z58 .req vADBC8
vX4Z59 .req vADBC9

vMaskA .req v30
vMaskB .req v15

vZ20 .req v1
vZ22 .req v3
vZ24 .req v5
vZ26 .req v7
vZ28 .req v9

vZ30 .req v11
vZ32 .req v13
vZ34 .req v15
vZ36 .req v17
vZ38 .req v19

vX20 .req v0
vX22 .req v2
vX24 .req v4
vX26 .req v6
vX28 .req v8

vX30 .req v10
vX32 .req v12
vX34 .req v14
vX36 .req v16
vX38 .req v18

vB0 .req v20
vB2 .req v21
vB4 .req v22
vB6 .req v23
vB8 .req v24

vA0 .req v0
vA2 .req v2
vA4 .req v4
vA6 .req v6
vA8 .req v8

vC0 .req v10
vC2 .req v12
vC4 .req v14
vC6 .req v16
vC8 .req v18

vD0 .req v25
vD2 .req v26
vD4 .req v27
vD6 .req v28
vD8 .req v29

vF0 .req v1
vF2 .req v3
vF4 .req v5
vF6 .req v7
vF8 .req v9

vG0 .req v20
vG2 .req v21
vG4 .req v22
vG6 .req v23
vG8 .req v24

// F
sF0 .req x0
sF1 .req x1
sF2 .req x2
sF3 .req x3
sF4 .req x4
sF5 .req x5
sF6 .req x6
sF7 .req x7
sF8 .req x8
sF9 .req x9

sAA0 .req x20
sAA1 .req x21
sAA2 .req x22
sAA3 .req x23
sAA4 .req x24
sAA5 .req x25
sAA6 .req x26
sAA7 .req x27
sAA8 .req x28
sAA9 .req x19

stmp .req x2

// G
sG0 .req x0
sG1 .req x1
sG2 .req x2
sG3 .req x3
sG4 .req x4
sG5 .req x5
sG6 .req x6
sG7 .req x7
sG8 .req x8
sG9 .req x9

sBB0 .req x0
sBB1 .req x1
sBB2 .req x2
sBB3 .req x3
sBB4 .req x4
sBB5 .req x5
sBB6 .req x6
sBB7 .req x7
sBB8 .req x8
sBB9 .req x9

// E
sE0 .req x10
sE1 .req x11
sE2 .req x12
sE3 .req x13
sE4 .req x14
sE5 .req x15
sE6 .req x16
sE7 .req x17
sE8 .req x19
sE9 .req x20

sZ40 .req x23
sZ41 .req x3
sZ42 .req x21
sZ44 .req x7
sZ45 .req x6
sZ46 .req x24
sZ48 .req x22

.macro scalar_stack_ldr sA, offset
  stack_ldr \sA\()0, \offset\()_0
  stack_ldr \sA\()2, \offset\()_8
  stack_ldr \sA\()4, \offset\()_16
  stack_ldr \sA\()6, \offset\()_24
  stack_ldr \sA\()8, \offset\()_32
.endm

.macro scalar_stack_str offset, sA
    stack_stp \offset\()_0, \offset\()_8, \sA\()0, \sA\()2
    stack_stp \offset\()_16, \offset\()_24, \sA\()4, \sA\()6
    stack_str \offset\()_32, \sA\()8
.endm

.macro vector_stack_str offset, vA
    stack_vstp_dform \offset\()_0, \offset\()_8, \vA\()0, \vA\()2
    stack_vstp_dform \offset\()_16, \offset\()_24, \vA\()4, \vA\()6
    stack_vstr_dform \offset\()_32, \vA\()8
.endm

.macro vector_load_lane vA, offset, lane
    // TODO: eliminate this explicit register assignment by converting stack_vld2_lane to AArch64Instruction
    xvector_load_lane_tmp .req x26

    add xvector_load_lane_tmp, sp, #\offset\()_0
    stack_vld2_lane \vA\()0, \vA\()1, xvector_load_lane_tmp, \offset\()_0,  \lane, 8
    stack_vld2_lane \vA\()2, \vA\()3, xvector_load_lane_tmp, \offset\()_8,  \lane, 8
    stack_vld2_lane \vA\()4, \vA\()5, xvector_load_lane_tmp, \offset\()_16, \lane, 8
    stack_vld2_lane \vA\()6, \vA\()7, xvector_load_lane_tmp, \offset\()_24, \lane, 8
    stack_vld2_lane \vA\()8, \vA\()9, xvector_load_lane_tmp, \offset\()_32, \lane, 8
.endm

.macro vector_sub_inner vC0, vC2, vC4, vC6, vC8, \
                        vA0, vA2, vA4, vA6, vA8, \
                        vB0, vB2, vB4, vB6, vB8
    // (2^255-19)*4 - vB
    vsub_2s    \vC0, v28, \vB0
    vsub_2s    \vC2, v29, \vB2
    vsub_2s    \vC4, v29, \vB4
    vsub_2s    \vC6, v29, \vB6
    vsub_2s    \vC8, v29, \vB8

    // ... + vA
    vadd_2s    \vC0, \vA0, \vC0
    vadd_2s    \vC2, \vA2, \vC2
    vadd_2s    \vC4, \vA4, \vC4
    vadd_2s    \vC6, \vA6, \vC6
    vadd_2s    \vC8, \vA8, \vC8
.endm

.macro vector_sub vC, vA, vB
    vector_sub_inner \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8, \
                     \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                     \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm


.macro vector_add_inner vC0, vC2, vC4, vC6, vC8, \
                        vA0, vA2, vA4, vA6, vA8, \
                        vB0, vB2, vB4, vB6, vB8
    vadd_2s    \vC0, \vA0, \vB0
    vadd_2s    \vC2, \vA2, \vB2
    vadd_2s    \vC4, \vA4, \vB4
    vadd_2s    \vC6, \vA6, \vB6
    vadd_2s    \vC8, \vA8, \vB8
.endm

.macro vector_add vC, vA, vB
    vector_add_inner \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8, \
                     \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                     \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro vector_cmov_inner vA0, vA2, vA4, vA6, vA8, \
                         vB0, vB2, vB4, vB6, vB8, \
                         vC0, vC2, vC4, vC6, vC8
    fcsel_dform    \vA0, \vB0, \vC0, eq
    fcsel_dform    \vA2, \vB2, \vC2, eq
    fcsel_dform    \vA4, \vB4, \vC4, eq
    fcsel_dform    \vA6, \vB6, \vC6, eq
    fcsel_dform    \vA8, \vB8, \vC8, eq
.endm

.macro vector_cmov vA, vB, vC
    vector_cmov_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                      \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8, \
                      \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,
.endm

.macro vector_transpose_inner vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9, \
                              vB0, vB2, vB4, vB6, vB8, \
                              vC0, vC2, vC4, vC6, vC8
    trn2_2s    \vA1, \vB0, \vC0
    trn1_2s    \vA0, \vB0, \vC0
    trn2_2s    \vA3, \vB2, \vC2
    trn1_2s    \vA2, \vB2, \vC2
    trn2_2s    \vA5, \vB4, \vC4
    trn1_2s    \vA4, \vB4, \vC4
    trn2_2s    \vA7, \vB6, \vC6
    trn1_2s    \vA6, \vB6, \vC6
    trn2_2s    \vA9, \vB8, \vC8
    trn1_2s    \vA8, \vB8, \vC8
.endm

.macro vector_transpose vA, vB, vC
    vector_transpose_inner \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9, \
                           \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8, \
                           \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,
.endm

.macro vector_to_scalar_inner sA0, sA2, sA4, sA6, sA8, \
                              vB0, vB2, vB4, vB6, vB8
    mov    \sA0, \vB0\().d[0]
    mov    \sA2, \vB2\().d[0]
    mov    \sA4, \vB4\().d[0]
    mov    \sA6, \vB6\().d[0]
    mov    \sA8, \vB8\().d[0]
.endm

.macro vector_to_scalar sA, vB
    vector_to_scalar_inner \sA\()0, \sA\()2, \sA\()4, \sA\()6, \sA\()8, \
                           \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro scalar_to_vector_inner vA0, vA2, vA4, vA6, vA8, \
                              sB0, sB2, sB4, sB6, sB8
    mov    \vA0\().d[0], \sB0
    mov    \vA2\().d[0], \sB2
    mov    \vA4\().d[0], \sB4
    mov    \vA6\().d[0], \sB6
    mov    \vA8\().d[0], \sB8
.endm

.macro scalar_to_vector vA, sB
    scalar_to_vector_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                           \sB\()0, \sB\()2, \sB\()4, \sB\()6, \sB\()8
.endm


.macro vector_extract_upper_inner vA0, vA2, vA4, vA6, vA8, \
                                  vB0, vB2, vB4, vB6, vB8
    mov_d01 \vA0, \vB0
    mov_d01 \vA2, \vB2
    mov_d01 \vA4, \vB4
    mov_d01 \vA6, \vB6
    mov_d01 \vA8, \vB8
.endm

.macro vector_extract_upper vA, vB
    vector_extract_upper_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                               \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro vector_compress_inner vA0, vA2, vA4, vA6, vA8, \
                             vB0, vB1, vB2, vB3, vB4, vB5, vB6, vB7, vB8, vB9
    trn1_s   \vA0, \vB0, \vB1
    trn1_s   \vA2, \vB2, \vB3
    trn1_s   \vA4, \vB4, \vB5
    trn1_s   \vA6, \vB6, \vB7
    trn1_s   \vA8, \vB8, \vB9
.endm

.macro vector_compress vA, vB
    vector_compress_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8, \
                          \vB\()0, \vB\()1, \vB\()2, \vB\()3, \vB\()4, \vB\()5, \vB\()6, \vB\()7, \vB\()8, \vB\()9,
.endm

.macro scalar_clear_carries_inner sA0, sA1, sA2, sA3, sA4, sA5, sA6, sA7, sA8, sA9
    and    \sA1, \sA1, #0x1ffffff
    and    \sA3, \sA3, #0x1ffffff
    and    \sA5, \sA5, #0x1ffffff
    and    \sA7, \sA7, #0x1ffffff
    mov    W<\sA0>, W<\sA0>
    mov    W<\sA2>, W<\sA2>
    mov    W<\sA4>, W<\sA4>
    mov    W<\sA6>, W<\sA6>
    mov    W<\sA8>, W<\sA8>
.endm

.macro scalar_clear_carries sA
    scalar_clear_carries_inner \sA\()0, \sA\()1, \sA\()2, \sA\()3, \sA\()4, \sA\()5, \sA\()6, \sA\()7, \sA\()8, \sA\()9
.endm

.macro scalar_decompress_inner sA0, sA1, sA2, sA3, sA4, sA5, sA6, sA7, sA8, sA9
    lsr    \sA1, \sA0, #32
    lsr    \sA3, \sA2, #32
    lsr    \sA5, \sA4, #32
    lsr    \sA7, \sA6, #32
    lsr    \sA9, \sA8, #32
.endm

.macro scalar_decompress sA
    scalar_decompress_inner \sA\()0, \sA\()1, \sA\()2, \sA\()3, \sA\()4, \sA\()5, \sA\()6, \sA\()7, \sA\()8, \sA\()9
.endm

.macro vector_addsub_repack_inner vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9, \
                    vC0, vC1, vC2, vC3, vC4, vC5, vC6, vC7, vC8, vC9
    // TODO: eliminate those. should be easy
    vR_l4h4l5h5 .req vADBC4
    vR_l6h6l7h7 .req vADBC5

    vR_l0h0l1h1 .req vADBC0
    vR_l2h2l3h3 .req vADBC1

    vR_l0123    .req vADBC4
    vR_l4567    .req vADBC6
    vR_h0123    .req vADBC5
    vR_h4567    .req vADBC7
    vR_l89h89   .req vADBC8

    vR_h89xx    .req vADBC9

    vSum0123 .req vADBC0
    vSum4567 .req vADBC1
    vSum89xx .req vADBC2

    vDiff0123 .req v10
    vDiff4567 .req v11
    vDiff89xx .req v12

    // TODO: eliminate those explicit register assignments by converting stack_vld1r and stack_vldr_bform to AArch64Instruction
    vrepack_inner_tmp .req v19
    vrepack_inner_tmp2 .req v0

    vuzp1    vR_l4h4l5h5, \vC4, \vC5
    vuzp1    vR_l6h6l7h7, \vC6, \vC7
    stack_vld1r vrepack_inner_tmp, STACK_MASK1
    vuzp1    vR_l4567, vR_l4h4l5h5, vR_l6h6l7h7
    vuzp2    vR_h4567, vR_l4h4l5h5, vR_l6h6l7h7
    trn1_s   vR_l89h89, \vC8, \vC9
    stack_vldr_bform vrepack_inner_tmp2, STACK_MASK2    // ldr      b0, [sp, #8]
    vuzp1    vR_l0h0l1h1, \vC0, \vC1
    vuzp1    vR_l2h2l3h3, \vC2, \vC3
    mov_d01  vR_h89xx, vR_l89h89
    vuzp1    vR_l0123, vR_l0h0l1h1, vR_l2h2l3h3
    vuzp2    vR_h0123, vR_l0h0l1h1, vR_l2h2l3h3
    vadd_4s  vDiff4567, vR_l4567, vrepack_inner_tmp
    vadd_2s  vDiff89xx, vR_l89h89, vrepack_inner_tmp
    mov_b00 vrepack_inner_tmp, vrepack_inner_tmp2
    vadd_4s  vSum0123, vR_l0123, vR_h0123
    vadd_4s  vSum4567, vR_l4567, vR_h4567
    vadd_2s  vSum89xx, vR_l89h89, vR_h89xx
    vadd_4s  vDiff0123, vR_l0123, vrepack_inner_tmp
    vsub_4s  vDiff4567, vDiff4567, vR_h4567
    vsub_4s  vDiff0123, vDiff0123, vR_h0123
    vsub_2s  vDiff89xx, vDiff89xx, vR_h89xx
    vzip1_4s \vA0, vDiff0123, vSum0123
    vzip2_4s \vA2, vDiff0123, vSum0123
    vzip1_4s \vA4, vDiff4567, vSum4567
    vzip2_4s \vA6, vDiff4567, vSum4567
    vzip1_2s \vA8, vDiff89xx, vSum89xx
    vzip2_2s \vA9, vDiff89xx, vSum89xx
    mov_d01  \vA1, \vA0
    mov_d01  \vA3, \vA2
    mov_d01  \vA5, \vA4
    mov_d01  \vA7, \vA6
.endm

.macro vector_addsub_repack vA, vC
vector_addsub_repack_inner \
        \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9, \
        \vC\()0, \vC\()1, \vC\()2, \vC\()3, \vC\()4, \vC\()5, \vC\()6, \vC\()7, \vC\()8, \vC\()9
.endm

// sAA0     .. sAA9       output AA = A^2
// sA0      .. sA9        input A
// TODO: simplify (this is still the same instruction order as before; we can make it simpler and leave the re-ordering to Sloty)
.macro scalar_sqr_inner \
        sAA0,     sAA1,     sAA2,     sAA3,     sAA4,     sAA5,     sAA6,     sAA7,     sAA8,     sAA9,      \
        sA0,      sA1,      sA2,      sA3,      sA4,      sA5,      sA6,      sA7,      sA8,      sA9
  lsr    \sA1, \sA0, #32
  lsr    \sA3, \sA2, #32
  lsr    \sA5, \sA4, #32
  lsr    \sA7, \sA6, #32
  lsr    \sA9, \sA8, #32
  add    X<tmp_scalar_sqr_dbl_9>, \sA9, \sA9
  add    X<tmp_scalar_sqr_dbl_8>, \sA8, \sA8
  add    X<tmp_scalar_sqr_dbl_7>, \sA7, \sA7
  add    X<tmp_scalar_sqr_dbl_6>, \sA6, \sA6
  add    X<tmp_scalar_sqr_dbl_5>, \sA5, \sA5
  add    X<tmp_scalar_sqr_dbl_4>, \sA4, \sA4
  add    X<tmp_scalar_sqr_dbl_3>, \sA3, \sA3
  add    X<tmp_scalar_sqr_dbl_2>, \sA2, \sA2
  add    X<tmp_scalar_sqr_dbl_1>, \sA1, \sA1
  umull  X<tmp_scalar_sqr_8>,      W<\sA4>,                 W<\sA4>
  umull  X<tmp_scalar_sqr_9>,      W<\sA4>,                 W<tmp_scalar_sqr_dbl_5>
  mul    W<\sA9>,                  W<\sA9>,                 W<const19>
  mul    W<\sA7>,                  W<\sA7>,                 W<const19>
  mul    W<\sA5>,                  W<\sA5>,                 W<const19>
  umaddl X<tmp_scalar_sqr_8>,      W<\sA9>,                 W<tmp_scalar_sqr_dbl_9>,  X<tmp_scalar_sqr_8>
  umaddl X<tmp_scalar_sqr_9>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_9>,  X<tmp_scalar_sqr_9>
  umull  X<tmp_scalar_sqr_0>,      W<\sA0>,                 W<\sA0>
  umull  X<tmp_scalar_sqr_1>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_1>
  umull  X<tmp_scalar_sqr_2>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_2>
  umull  X<tmp_scalar_sqr_3>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_3>
  umull  X<tmp_scalar_sqr_4>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_4>
  umull  X<tmp_scalar_sqr_5>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_5>
  umull  X<tmp_scalar_sqr_6>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_6>
  umull  X<tmp_scalar_sqr_7>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_7>
  umaddl X<tmp_scalar_sqr_8>,      W<\sA0>,                 W<tmp_scalar_sqr_dbl_8>,  X<tmp_scalar_sqr_8>
  mul    W<tmp_scalar_sqr_tw_6>,   W<\sA6>,                 W<const19>
  umaddl X<tmp_scalar_sqr_2>,      W<\sA1>,                 W<tmp_scalar_sqr_dbl_1>,  X<tmp_scalar_sqr_2>
  umaddl X<tmp_scalar_sqr_3>,      W<\sA1>,                 W<tmp_scalar_sqr_dbl_2>,  X<tmp_scalar_sqr_3>
  umaddl X<tmp_scalar_sqr_4>,      W<tmp_scalar_sqr_dbl_1>, W<tmp_scalar_sqr_dbl_3>,  X<tmp_scalar_sqr_4>
  umaddl X<tmp_scalar_sqr_5>,      W<\sA1>,                 W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_5>
  umaddl X<tmp_scalar_sqr_6>,      W<tmp_scalar_sqr_dbl_1>, W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_6>
  umaddl X<tmp_scalar_sqr_7>,      W<\sA1>,                 W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_7>
  umaddl X<tmp_scalar_sqr_8>,      W<tmp_scalar_sqr_dbl_1>, W<tmp_scalar_sqr_dbl_7>,  X<tmp_scalar_sqr_8>
  umaddl X<tmp_scalar_sqr_9>,      W<\sA1>,                 W<tmp_scalar_sqr_dbl_8>,  X<tmp_scalar_sqr_9>
  mul    W<tmp_scalar_sqr_tw_8>,   W<\sA8>,                 W<const19>
  umaddl X<tmp_scalar_sqr_4>,      W<\sA2>,                 W<\sA2>,                  X<tmp_scalar_sqr_4>
  umaddl X<tmp_scalar_sqr_5>,      W<\sA2>,                 W<tmp_scalar_sqr_dbl_3>,  X<tmp_scalar_sqr_5>
  umaddl X<tmp_scalar_sqr_6>,      W<\sA2>,                 W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_6>
  umaddl X<tmp_scalar_sqr_7>,      W<\sA2>,                 W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_7>
  umaddl X<tmp_scalar_sqr_8>,      W<\sA2>,                 W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_8>
  umaddl X<tmp_scalar_sqr_9>,      W<\sA2>,                 W<tmp_scalar_sqr_dbl_7>,  X<tmp_scalar_sqr_9>
  umaddl X<tmp_scalar_sqr_6>,      W<\sA3>,                 W<tmp_scalar_sqr_dbl_3>,  X<tmp_scalar_sqr_6>
  umaddl X<tmp_scalar_sqr_7>,      W<\sA3>,                 W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_7>
  umaddl X<tmp_scalar_sqr_8>,      W<tmp_scalar_sqr_dbl_3>, W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_8>
  umaddl X<tmp_scalar_sqr_9>,      W<\sA3>,                 W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_9>
  umaddl X<tmp_scalar_sqr_6>,      W<\sA8>,                 W<tmp_scalar_sqr_tw_8>,   X<tmp_scalar_sqr_6>
  umaddl X<tmp_scalar_sqr_2>,      W<\sA6>,                 W<tmp_scalar_sqr_tw_6>,   X<tmp_scalar_sqr_2>
  add    X<tmp_scalar_sqr_9>,      X<tmp_scalar_sqr_9>,     X<tmp_scalar_sqr_8>,      lsr #26
  umaddl X<tmp_scalar_sqr_0>,      W<\sA5>,                 W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_0>
  add    X<tmp_scalar_sqr_0>,      X<tmp_scalar_sqr_0>,     X<tmp_scalar_sqr_9>,      lsr #25
  bic    X<tmp_scalar_sqr_10>,     X<tmp_scalar_sqr_9>,     #0x1ffffff
  add    X<tmp_scalar_sqr_0>,      X<tmp_scalar_sqr_0>,     X<tmp_scalar_sqr_10>,     lsr #24
  and    X<tmp_scalar_sqr_9>,      X<tmp_scalar_sqr_9>,     #0x1ffffff
  add    X<tmp_scalar_sqr_0>,      X<tmp_scalar_sqr_0>,     X<tmp_scalar_sqr_10>,     lsr #21
  umaddl X<tmp_scalar_sqr_4>,      W<\sA7>,                 W<tmp_scalar_sqr_dbl_7>,  X<tmp_scalar_sqr_4>
  add    X<tmp_scalar_sqr_quad_1>, X<tmp_scalar_sqr_dbl_1>, X<tmp_scalar_sqr_dbl_1>
  add    X<tmp_scalar_sqr_quad_3>, X<tmp_scalar_sqr_dbl_3>, X<tmp_scalar_sqr_dbl_3>
  add    X<tmp_scalar_sqr_quad_5>, X<tmp_scalar_sqr_dbl_5>, X<tmp_scalar_sqr_dbl_5>
  add    X<tmp_scalar_sqr_quad_7>, X<tmp_scalar_sqr_dbl_7>, X<tmp_scalar_sqr_dbl_7>
  umaddl X<tmp_scalar_sqr_0>,      W<tmp_scalar_sqr_tw_6>,  W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_0>
  umaddl X<tmp_scalar_sqr_1>,      W<tmp_scalar_sqr_tw_6>,  W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_1>
  and    X<tmp_scalar_sqr_8>,      X<tmp_scalar_sqr_8>,     #0x3ffffff
  umaddl X<tmp_scalar_sqr_0>,      W<\sA7>,                 W<tmp_scalar_sqr_quad_3>, X<tmp_scalar_sqr_0>
  umaddl X<tmp_scalar_sqr_1>,      W<\sA7>,                 W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_1>
  umaddl X<tmp_scalar_sqr_2>,      W<\sA7>,                 W<tmp_scalar_sqr_quad_5>, X<tmp_scalar_sqr_2>
  umaddl X<tmp_scalar_sqr_3>,      W<\sA7>,                 W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_3>
  umaddl X<tmp_scalar_sqr_0>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_2>,  X<tmp_scalar_sqr_0>
  umaddl X<tmp_scalar_sqr_1>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_3>,  X<tmp_scalar_sqr_1>
  umaddl X<tmp_scalar_sqr_2>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_2>
  umaddl X<tmp_scalar_sqr_3>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_5>,  X<tmp_scalar_sqr_3>
  umaddl X<tmp_scalar_sqr_4>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_4>
  umaddl X<tmp_scalar_sqr_5>,      W<tmp_scalar_sqr_tw_8>,  W<tmp_scalar_sqr_dbl_7>,  X<tmp_scalar_sqr_5>
  umaddl X<tmp_scalar_sqr_0>,      W<\sA9>,                 W<tmp_scalar_sqr_quad_1>, X<tmp_scalar_sqr_0>
  umaddl X<tmp_scalar_sqr_1>,      W<\sA9>,                 W<tmp_scalar_sqr_dbl_2>,  X<tmp_scalar_sqr_1>
  umaddl X<tmp_scalar_sqr_2>,      W<\sA9>,                 W<tmp_scalar_sqr_quad_3>, X<tmp_scalar_sqr_2>
  umaddl X<tmp_scalar_sqr_3>,      W<\sA9>,                 W<tmp_scalar_sqr_dbl_4>,  X<tmp_scalar_sqr_3>
  umaddl X<tmp_scalar_sqr_4>,      W<\sA9>,                 W<tmp_scalar_sqr_quad_5>, X<tmp_scalar_sqr_4>
  umaddl X<tmp_scalar_sqr_5>,      W<\sA9>,                 W<tmp_scalar_sqr_dbl_6>,  X<tmp_scalar_sqr_5>
  umaddl X<tmp_scalar_sqr_6>,      W<\sA9>,                 W<tmp_scalar_sqr_quad_7>, X<tmp_scalar_sqr_6>
  umaddl X<tmp_scalar_sqr_7>,      W<\sA9>,                 W<tmp_scalar_sqr_dbl_8>,  X<tmp_scalar_sqr_7>
  add    \sAA1, X<tmp_scalar_sqr_1>, X<tmp_scalar_sqr_0>, lsr #26
  and    \sAA0, X<tmp_scalar_sqr_0>, #0x3ffffff
  add    \sAA2, X<tmp_scalar_sqr_2>, \sAA1, lsr #25
  bfi    \sAA0, \sAA1, #32, #25
  add    \sAA3, X<tmp_scalar_sqr_3>, \sAA2, lsr #26
  and    \sAA2, \sAA2, #0x3ffffff
  add    \sAA4, X<tmp_scalar_sqr_4>, \sAA3, lsr #25
  bfi    \sAA2, \sAA3, #32, #25
  add    \sAA5, X<tmp_scalar_sqr_5>, \sAA4, lsr #26
  and    \sAA4, \sAA4, #0x3ffffff
  add    \sAA6, X<tmp_scalar_sqr_6>, \sAA5, lsr #25
  bfi    \sAA4, \sAA5, #32, #25
  add    \sAA7, X<tmp_scalar_sqr_7>, \sAA6, lsr #26
  and    \sAA6, \sAA6, #0x3ffffff
  add    \sAA8, X<tmp_scalar_sqr_8>, \sAA7, lsr #25
  bfi    \sAA6, \sAA7, #32, #25
  add    \sAA9, X<tmp_scalar_sqr_9>, \sAA8, lsr #26
  and    \sAA8, \sAA8, #0x3ffffff
  bfi    \sAA8, \sAA9, #32, #26
.endm

.macro scalar_sqr sAA, sA
scalar_sqr_inner \
        \sAA\()0,  \sAA\()1,  \sAA\()2,  \sAA\()3,  \sAA\()4,  \sAA\()5,  \sAA\()6,  \sAA\()7,  \sAA\()8,  \sAA\()9,  \
        \sA\()0,   \sA\()1,   \sA\()2,   \sA\()3,   \sA\()4,   \sA\()5,   \sA\()6,   \sA\()7,   \sA\()8,   \sA\()9
.endm

// sC0     .. sC9        output C = A*B
// sA0     .. sA9        input A
// sB0     .. sB9        input B
.macro scalar_mul_inner \
        sC0,     sC1,     sC2,     sC3,     sC4,     sC5,     sC6,     sC7,     sC8,     sC9,     \
        sA0,     sA1,     sA2,     sA3,     sA4,     sA5,     sA6,     sA7,     sA8,     sA9,     \
        sB0,     sB1,     sB2,     sB3,     sB4,     sB5,     sB6,     sB7,     sB8,     sB9


  mul    W<tmp_scalar_mul_tw_1>, W<\sA1>,                W<const19>
  mul    W<tmp_scalar_mul_tw_2>, W<\sA2>,                W<const19>
  mul    W<tmp_scalar_mul_tw_3>, W<\sA3>,                W<const19>
  mul    W<tmp_scalar_mul_tw_5>, W<\sA5>,                W<const19>
  mul    W<tmp_scalar_mul_tw_6>, W<\sA6>,                W<const19>
  mul    W<tmp_scalar_mul_tw_7>, W<\sA7>,                W<const19>
  mul    W<tmp_scalar_mul_tw_8>, W<\sA8>,                W<const19>
  mul    W<tmp_scalar_mul_tw_9>, W<\sA9>,                W<const19>

  umull  X<tmp_scalar_mul_9>,    W<\sA1>,                W<\sB8>
  umaddl X<tmp_scalar_mul_9>,    W<\sA3>,                W<\sB6>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA5>,                W<\sB4>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA7>,                W<\sB2>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA9>,                W<\sB0>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA0>,                W<\sB9>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA2>,                W<\sB7>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA4>,                W<\sB5>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA6>,                W<\sB3>, X<tmp_scalar_mul_9>
  umaddl X<tmp_scalar_mul_9>,    W<\sA8>,                W<\sB1>, X<tmp_scalar_mul_9>

  umull  X<tmp_scalar_mul_8>,    W<\sA1>,                W<\sB7>
  umaddl X<tmp_scalar_mul_8>,    W<\sA3>,                W<\sB5>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA5>,                W<\sB3>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA7>,                W<\sB1>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<tmp_scalar_mul_tw_9>, W<\sB9>, X<tmp_scalar_mul_8>
  add    X<tmp_scalar_mul_8>,    X<tmp_scalar_mul_8>,    X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA0>,                W<\sB8>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA2>,                W<\sB6>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA4>,                W<\sB4>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA6>,                W<\sB2>, X<tmp_scalar_mul_8>
  umaddl X<tmp_scalar_mul_8>,    W<\sA8>,                W<\sB0>, X<tmp_scalar_mul_8>


  umull  X<tmp_scalar_mul_7>,    W<\sA1>,                W<\sB6>
  umaddl X<tmp_scalar_mul_7>,    W<\sA3>,                W<\sB4>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA5>,                W<\sB2>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA7>,                W<\sB0>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<tmp_scalar_mul_tw_9>, W<\sB8>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA0>,                W<\sB7>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA2>,                W<\sB5>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA4>,                W<\sB3>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<\sA6>,                W<\sB1>, X<tmp_scalar_mul_7>
  umaddl X<tmp_scalar_mul_7>,    W<tmp_scalar_mul_tw_8>, W<\sB9>, X<tmp_scalar_mul_7>

  umull  X<tmp_scalar_mul_6>,    W<\sA1>,                W<\sB5>
  umaddl X<tmp_scalar_mul_6>,    W<\sA3>,                W<\sB3>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<\sA5>,                W<\sB1>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<tmp_scalar_mul_tw_7>, W<\sB9>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<tmp_scalar_mul_tw_9>, W<\sB7>, X<tmp_scalar_mul_6>
  add    X<tmp_scalar_mul_6>,    X<tmp_scalar_mul_6>,    X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<\sA0>,                W<\sB6>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<\sA2>,                W<\sB4>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<\sA4>,                W<\sB2>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<\sA6>,                W<\sB0>, X<tmp_scalar_mul_6>
  umaddl X<tmp_scalar_mul_6>,    W<tmp_scalar_mul_tw_8>, W<\sB8>, X<tmp_scalar_mul_6>

  umull  X<tmp_scalar_mul_5>,    W<tmp_scalar_mul_tw_9>, W<\sB6>
  umaddl X<tmp_scalar_mul_5>,    W<\sA5>,                W<\sB0>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<tmp_scalar_mul_tw_7>, W<\sB8>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<\sA3>,                W<\sB2>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<\sA1>,                W<\sB4>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<tmp_scalar_mul_tw_8>, W<\sB7>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<tmp_scalar_mul_tw_6>, W<\sB9>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<\sA4>,                W<\sB1>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<\sA2>,                W<\sB3>, X<tmp_scalar_mul_5>
  umaddl X<tmp_scalar_mul_5>,    W<\sA0>,                W<\sB5>, X<tmp_scalar_mul_5>

  umull  X<tmp_scalar_mul_4>,    W<tmp_scalar_mul_tw_9>, W<\sB5>
  umaddl X<tmp_scalar_mul_4>,    W<tmp_scalar_mul_tw_7>, W<\sB7>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<tmp_scalar_mul_tw_5>, W<\sB9>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<\sA3>,                W<\sB1>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<\sA1>,                W<\sB3>, X<tmp_scalar_mul_4>
  add    X<tmp_scalar_mul_4>,    X<tmp_scalar_mul_4>,    X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<tmp_scalar_mul_tw_8>, W<\sB6>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<tmp_scalar_mul_tw_6>, W<\sB8>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<\sA4>,                W<\sB0>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<\sA2>,                W<\sB2>, X<tmp_scalar_mul_4>
  umaddl X<tmp_scalar_mul_4>,    W<\sA0>,                W<\sB4>, X<tmp_scalar_mul_4>

  umull  X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_9>, W<\sB4>
  umaddl X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_7>, W<\sB6>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_5>, W<\sB8>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<\sA3>,                W<\sB0>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<\sA1>,                W<\sB2>, X<tmp_scalar_mul_3>
  mul    W<tmp_scalar_mul_tw_4>, W<\sA4>,                W<const19>
  umaddl X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_8>, W<\sB5>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_6>, W<\sB7>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<tmp_scalar_mul_tw_4>, W<\sB9>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<\sA2>,                W<\sB1>, X<tmp_scalar_mul_3>
  umaddl X<tmp_scalar_mul_3>,    W<\sA0>,                W<\sB3>, X<tmp_scalar_mul_3>

  add    X<tmp_scalar_mul_5>, X<tmp_scalar_mul_5>, X<tmp_scalar_mul_4>, lsr #26
  and    \sC4, X<tmp_scalar_mul_4>, #0x3ffffff
  add    X<tmp_scalar_mul_6>, X<tmp_scalar_mul_6>, X<tmp_scalar_mul_5>, lsr #25
  and    \sC5, X<tmp_scalar_mul_5>, #0x1ffffff
  add    X<tmp_scalar_mul_7>, X<tmp_scalar_mul_7>, X<tmp_scalar_mul_6>, lsr #26
  and    \sC6, X<tmp_scalar_mul_6>, #0x3ffffff
  add    X<tmp_scalar_mul_8>, X<tmp_scalar_mul_8>, X<tmp_scalar_mul_7>, lsr #25
  bfi    \sC6, X<tmp_scalar_mul_7>, #32, #25
  add    X<tmp_scalar_mul_9>, X<tmp_scalar_mul_9>, X<tmp_scalar_mul_8>, lsr #26
  and    \sC8, X<tmp_scalar_mul_8>, #0x3ffffff
  bic    X<tmp_scalar_mul_0b>, X<tmp_scalar_mul_9>, #0x3ffffff
  lsr    X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0b>, #26
  bfi    \sC8, X<tmp_scalar_mul_9>, #32, #26
  add    X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0b>, lsr #25
  add    X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0b>, lsr #22

  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_9>, W<\sB1>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_7>, W<\sB3>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_5>, W<\sB5>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_3>, W<\sB7>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_1>, W<\sB9>, X<tmp_scalar_mul_0>
  add    X<tmp_scalar_mul_0>, X<tmp_scalar_mul_0>,    X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_8>, W<\sB2>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_6>, W<\sB4>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_4>, W<\sB6>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<tmp_scalar_mul_tw_2>, W<\sB8>, X<tmp_scalar_mul_0>
  umaddl X<tmp_scalar_mul_0>, W<\sA0>,                W<\sB0>, X<tmp_scalar_mul_0>

  umull  X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_9>, W<\sB2>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_7>, W<\sB4>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_5>, W<\sB6>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_3>, W<\sB8>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<\sA1>,                W<\sB0>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_8>, W<\sB3>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_6>, W<\sB5>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_4>, W<\sB7>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<tmp_scalar_mul_tw_2>, W<\sB9>, X<tmp_scalar_mul_1>
  umaddl X<tmp_scalar_mul_1>, W<\sA0>,                W<\sB1>, X<tmp_scalar_mul_1>

  umull  X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_9>, W<\sB3>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_7>, W<\sB5>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_5>, W<\sB7>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_3>, W<\sB9>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<\sA1>,                W<\sB1>, X<tmp_scalar_mul_2>
  add    X<tmp_scalar_mul_2>, X<tmp_scalar_mul_2>,    X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_8>, W<\sB4>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_6>, W<\sB6>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<tmp_scalar_mul_tw_4>, W<\sB8>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<\sA2>,                W<\sB0>, X<tmp_scalar_mul_2>
  umaddl X<tmp_scalar_mul_2>, W<\sA0>,                W<\sB2>, X<tmp_scalar_mul_2>

  add    \sC1, X<tmp_scalar_mul_1>, X<tmp_scalar_mul_0>, lsr #26
  and    \sC0, X<tmp_scalar_mul_0>, #0x3ffffff
  add    \sC2, X<tmp_scalar_mul_2>, \sC1, lsr #25
  bfi    \sC0, \sC1, #32, #25
  add    X<tmp_scalar_mul_3>, X<tmp_scalar_mul_3>, \sC2, lsr #26
  and    \sC2, \sC2, #0x3ffffff
  add    \sC4, \sC4, X<tmp_scalar_mul_3>, lsr #25
  bfi    \sC2, X<tmp_scalar_mul_3>, #32, #25
  add    \sC5, \sC5, \sC4, lsr #26
  and    \sC4, \sC4, #0x3ffffff
  bfi    \sC4, \sC5, #32, #26
.endm

.macro scalar_mul sC, sA, sB
scalar_mul_inner \
        \sC\()0,  \sC\()1,  \sC\()2,  \sC\()3,  \sC\()4,  \sC\()5,  \sC\()6,  \sC\()7,  \sC\()8,  \sC\()9,  \
        \sA\()0,  \sA\()1,  \sA\()2,  \sA\()3,  \sA\()4,  \sA\()5,  \sA\()6,  \sA\()7,  \sA\()8,  \sA\()9,  \
        \sB\()0,  \sB\()1,  \sB\()2,  \sB\()3,  \sB\()4,  \sB\()5,  \sB\()6,  \sB\()7,  \sB\()8,  \sB\()9
.endm

// sC0 .. sC4   output C = A +  4p - B  (registers may be the same as A)
// sA0 .. sA4   first operand A
// sB0 .. sB4   second operand B
.macro scalar_sub_inner \
        sC0, sC1, sC2, sC3, sC4, \
        sA0, sA1, sA2, sA3, sA4, \
        sB0, sB1, sB2, sB3, sB4

  xtmp_scalar_sub_0 .req x21

  ldr    xtmp_scalar_sub_0, #=0x07fffffe07fffffc
  add    \sC1, \sA1, xtmp_scalar_sub_0
  add    \sC2, \sA2, xtmp_scalar_sub_0
  add    \sC3, \sA3, xtmp_scalar_sub_0
  add    \sC4, \sA4, xtmp_scalar_sub_0
  movk   xtmp_scalar_sub_0, #0xffb4
  add    \sC0, \sA0, xtmp_scalar_sub_0
  sub    \sC0, \sC0, \sB0
  sub    \sC1, \sC1, \sB1
  sub    \sC2, \sC2, \sB2
  sub    \sC3, \sC3, \sB3
  sub    \sC4, \sC4, \sB4
.endm

.macro scalar_sub sC, sA, sB
scalar_sub_inner \sC\()0, \sC\()2, \sC\()4, \sC\()6, \sC\()8, \
                 \sA\()0, \sA\()2, \sA\()4, \sA\()6, \sA\()8, \
                 \sB\()0, \sB\()2, \sB\()4, \sB\()6, \sB\()8
.endm


.macro scalar_addm_inner  \
        sC0, sC1, sC2, sC3, sC4, sC5, sC6, sC7, sC8, sC9, \
        sA0, sA1, sA2, sA3, sA4, sA5, sA6, sA7, sA8, sA9, \
        sB0, sB1, sB2, sB3, sB4, sB5, sB6, sB7, sB8, sB9, \
        multconst

  ldr    X<tmp_scalar_addm_0>, #=\multconst
  umaddl \sC9, W<\sB9>, W<tmp_scalar_addm_0>, \sA9
  umaddl \sC0, W<\sB0>, W<tmp_scalar_addm_0>, \sA0
  umaddl \sC1, W<\sB1>, W<tmp_scalar_addm_0>, \sA1
  umaddl \sC2, W<\sB2>, W<tmp_scalar_addm_0>, \sA2
  lsr    X<tmp_scalar_addm_1>, \sC9, #25
  umaddl \sC3, W<\sB3>, W<tmp_scalar_addm_0>, \sA3
  and    \sC9, \sC9, #0x1ffffff
  umaddl \sC4, W<\sB4>, W<tmp_scalar_addm_0>, \sA4
  add    \sC0, \sC0, X<tmp_scalar_addm_1>
  umaddl \sC5, W<\sB5>, W<tmp_scalar_addm_0>, \sA5
  add    \sC0, \sC0, X<tmp_scalar_addm_1>, lsl #1
  umaddl \sC6, W<\sB6>, W<tmp_scalar_addm_0>, \sA6
  add    \sC0, \sC0, X<tmp_scalar_addm_1>, lsl #4
  umaddl \sC7, W<\sB7>, W<tmp_scalar_addm_0>, \sA7
  umaddl \sC8, W<\sB8>, W<tmp_scalar_addm_0>, \sA8

  add    \sC1, \sC1, \sC0, lsr #26
  and    \sC0, \sC0, #0x3ffffff
  add    \sC2, \sC2, \sC1, lsr #25
  and    \sC1, \sC1, #0x1ffffff
  add    \sC3, \sC3, \sC2, lsr #26
  and    \sC2, \sC2, #0x3ffffff
  add    \sC4, \sC4, \sC3, lsr #25
  and    \sC3, \sC3, #0x1ffffff
  add    \sC5, \sC5, \sC4, lsr #26
  and    \sC4, \sC4, #0x3ffffff
  add    \sC6, \sC6, \sC5, lsr #25
  and    \sC5, \sC5, #0x1ffffff
  add    \sC7, \sC7, \sC6, lsr #26
  and    \sC6, \sC6, #0x3ffffff
  add    \sC8, \sC8, \sC7, lsr #25
  and    \sC7, \sC7, #0x1ffffff
  add    \sC9, \sC9, \sC8, lsr #26
  and    \sC8, \sC8, #0x3ffffff
.endm

.macro scalar_addm sC, sA, sB, multconst
scalar_addm_inner \sC\()0, \sC\()1, \sC\()2, \sC\()3, \sC\()4, \sC\()5, \sC\()6, \sC\()7, \sC\()8, \sC\()9,  \
                  \sA\()0, \sA\()1, \sA\()2, \sA\()3, \sA\()4, \sA\()5, \sA\()6, \sA\()7, \sA\()8, \sA\()9,  \
                  \sB\()0, \sB\()1, \sB\()2, \sB\()3, \sB\()4, \sB\()5, \sB\()6, \sB\()7, \sB\()8, \sB\()9, \
                  \multconst
.endm

// vAA0     .. vAA9        output AA = A^2
// vA0      .. vA9         input A
.macro vector_sqr_inner \
        vAA0,     vAA1,     vAA2,     vAA3,     vAA4,     vAA5,     vAA6,     vAA7,     vAA8,     vAA9,     \
        vA0,      vA1,      vA2,      vA3,      vA4,      vA5,      vA6,      vA7,      vA8,      vA9
  vshl_s   V<tmp_vector_sqr_dbl_9>,  \vA9,  #1
  vshl_s   V<tmp_vector_sqr_dbl_8>,  \vA8,  #1
  vshl_s   V<tmp_vector_sqr_dbl_7>,  \vA7,  #1
  vshl_s   V<tmp_vector_sqr_dbl_6>,  \vA6,  #1
  vshl_s   V<tmp_vector_sqr_dbl_5>,  \vA5,  #1
  vshl_s   V<tmp_vector_sqr_dbl_4>,  \vA4,  #1
  vshl_s   V<tmp_vector_sqr_dbl_3>,  \vA3,  #1
  vshl_s   V<tmp_vector_sqr_dbl_2>,  \vA2,  #1
  vshl_s   V<tmp_vector_sqr_dbl_1>,  \vA1,  #1
  vmull    V<tmp_vector_sqr_9>,      \vA0,     V<tmp_vector_sqr_dbl_9>
  vmlal    V<tmp_vector_sqr_9>,      \vA1,     V<tmp_vector_sqr_dbl_8>
  vmlal    V<tmp_vector_sqr_9>,      \vA2,     V<tmp_vector_sqr_dbl_7>
  vmlal    V<tmp_vector_sqr_9>,      \vA3,     V<tmp_vector_sqr_dbl_6>
  vmlal    V<tmp_vector_sqr_9>,      \vA4,     V<tmp_vector_sqr_dbl_5>
  vmull    V<tmp_vector_sqr_8>,      \vA0,     V<tmp_vector_sqr_dbl_8>
  vmlal    V<tmp_vector_sqr_8>,      V<tmp_vector_sqr_dbl_1>, V<tmp_vector_sqr_dbl_7>
  vmlal    V<tmp_vector_sqr_8>,      \vA2,     V<tmp_vector_sqr_dbl_6>
  vmlal    V<tmp_vector_sqr_8>,      V<tmp_vector_sqr_dbl_3>, V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_8>,      \vA4,     \vA4
  vmul     V<tmp_vector_sqr_tw_9>,   \vA9,     vconst19
  vmull    V<tmp_vector_sqr_7>,      \vA0,     V<tmp_vector_sqr_dbl_7>
  vmlal    V<tmp_vector_sqr_7>,      \vA1,     V<tmp_vector_sqr_dbl_6>
  vmlal    V<tmp_vector_sqr_7>,      \vA2,     V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_7>,      \vA3,     V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_8>,      V<tmp_vector_sqr_tw_9>,     V<tmp_vector_sqr_dbl_9>
  vmull    V<tmp_vector_sqr_6>,      \vA0,     V<tmp_vector_sqr_dbl_6>
  vmlal    V<tmp_vector_sqr_6>,      V<tmp_vector_sqr_dbl_1>, V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_6>,      \vA2,     V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_6>,      V<tmp_vector_sqr_dbl_3>, \vA3
  vmull    V<tmp_vector_sqr_5>,      \vA0,     V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_5>,      \vA1,     V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_5>,      \vA2,     V<tmp_vector_sqr_dbl_3>
  vmull    V<tmp_vector_sqr_4>,      \vA0,     V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_4>,      V<tmp_vector_sqr_dbl_1>, V<tmp_vector_sqr_dbl_3>
  vmlal    V<tmp_vector_sqr_4>,      \vA2,     \vA2
  vmull    V<tmp_vector_sqr_3>,      \vA0,     V<tmp_vector_sqr_dbl_3>
  vmlal    V<tmp_vector_sqr_3>,      \vA1,     V<tmp_vector_sqr_dbl_2>
  vmull    V<tmp_vector_sqr_2>,      \vA0,     V<tmp_vector_sqr_dbl_2>
  vmlal    V<tmp_vector_sqr_2>,      V<tmp_vector_sqr_dbl_1>, \vA1
  vmull    V<tmp_vector_sqr_1>,      \vA0,     V<tmp_vector_sqr_dbl_1>
  vmull    V<tmp_vector_sqr_0>,      \vA0,     \vA0
  vusra    V<tmp_vector_sqr_9>,      V<tmp_vector_sqr_8>,     #26
  vand     V<tmp_vector_sqr_8>,      V<tmp_vector_sqr_8>,     vMaskA
  vmul     V<tmp_vector_sqr_tw_8>,   \vA8,     vconst19
  vbic     V<tmp_vector_sqr_dbl_9>,  V<tmp_vector_sqr_9>,     vMaskB
  vand     \vA9,      V<tmp_vector_sqr_9>,     vMaskB
  vusra    V<tmp_vector_sqr_0>,      V<tmp_vector_sqr_dbl_9>, #25
  vmul     V<tmp_vector_sqr_tw_7>,   \vA7,     vconst19
  vusra    V<tmp_vector_sqr_0>,      V<tmp_vector_sqr_dbl_9>, #24
  vmul     V<tmp_vector_sqr_tw_6>,   \vA6,     vconst19
  vusra    V<tmp_vector_sqr_0>,      V<tmp_vector_sqr_dbl_9>, #21
  vmul     V<tmp_vector_sqr_tw_5>,   \vA5,     vconst19
  vshl_s   V<tmp_vector_sqr_quad_1>, V<tmp_vector_sqr_dbl_1>, #1
  vshl_s   V<tmp_vector_sqr_quad_3>, V<tmp_vector_sqr_dbl_3>, #1
  vshl_s   V<tmp_vector_sqr_quad_5>, V<tmp_vector_sqr_dbl_5>, #1
  vshl_s   V<tmp_vector_sqr_quad_7>, V<tmp_vector_sqr_dbl_7>, #1
  vmlal    V<tmp_vector_sqr_0>, V<tmp_vector_sqr_tw_5>,  V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_0>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_quad_1>
  vmlal    V<tmp_vector_sqr_0>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_2>
  vmlal    V<tmp_vector_sqr_0>, V<tmp_vector_sqr_tw_7>,  V<tmp_vector_sqr_quad_3>
  vmlal    V<tmp_vector_sqr_0>, V<tmp_vector_sqr_tw_6>,  V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_1>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_dbl_2>
  vmlal    V<tmp_vector_sqr_1>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_3>
  vmlal    V<tmp_vector_sqr_1>, V<tmp_vector_sqr_tw_7>,  V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_1>, V<tmp_vector_sqr_tw_6>,  V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_2>, V<tmp_vector_sqr_tw_6>,  \vA6
  vmlal    V<tmp_vector_sqr_2>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_quad_3>
  vmlal    V<tmp_vector_sqr_2>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_2>, V<tmp_vector_sqr_tw_7>,  V<tmp_vector_sqr_quad_5>
  vusra    V<tmp_vector_sqr_1>, V<tmp_vector_sqr_0>, #26
  vmlal    V<tmp_vector_sqr_3>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_dbl_4>
  vmlal    V<tmp_vector_sqr_3>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_5>
  vmlal    V<tmp_vector_sqr_3>, V<tmp_vector_sqr_tw_7>,  V<tmp_vector_sqr_dbl_6>
  vusra    V<tmp_vector_sqr_2>, V<tmp_vector_sqr_1>, #25
  vmlal    V<tmp_vector_sqr_4>, V<tmp_vector_sqr_tw_7>,  V<tmp_vector_sqr_dbl_7>
  vmlal    V<tmp_vector_sqr_4>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_quad_5>
  vmlal    V<tmp_vector_sqr_4>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_6>
  vusra    V<tmp_vector_sqr_3>, V<tmp_vector_sqr_2>, #26
  vmlal    V<tmp_vector_sqr_5>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_dbl_6>
  vmlal    V<tmp_vector_sqr_5>, V<tmp_vector_sqr_tw_8>,  V<tmp_vector_sqr_dbl_7>
  vusra    V<tmp_vector_sqr_4>, V<tmp_vector_sqr_3>, #25
  vmlal    V<tmp_vector_sqr_6>, V<tmp_vector_sqr_tw_8>,  \vA8
  vmlal    V<tmp_vector_sqr_6>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_quad_7>
  vusra    V<tmp_vector_sqr_5>, V<tmp_vector_sqr_4>, #26
  vmlal    V<tmp_vector_sqr_7>, V<tmp_vector_sqr_tw_9>,  V<tmp_vector_sqr_dbl_8>
  vusra    V<tmp_vector_sqr_6>,  V<tmp_vector_sqr_5>, #25
  vusra    V<tmp_vector_sqr_7>,  V<tmp_vector_sqr_6>, #26
  vusra    V<tmp_vector_sqr_8>,  V<tmp_vector_sqr_7>, #25
  vusra    \vAA9,  V<tmp_vector_sqr_8>, #26
  vand     \vAA4,  V<tmp_vector_sqr_4>, vMaskA
  vand     \vAA5,  V<tmp_vector_sqr_5>, vMaskB
  vand     \vAA0,  V<tmp_vector_sqr_0>, vMaskA
  vand     \vAA6,  V<tmp_vector_sqr_6>, vMaskA
  vand     \vAA1,  V<tmp_vector_sqr_1>, vMaskB
  vand     \vAA7,  V<tmp_vector_sqr_7>, vMaskB
  vand     \vAA2,  V<tmp_vector_sqr_2>, vMaskA
  vand     \vAA8,  V<tmp_vector_sqr_8>, vMaskA
  vand     \vAA3,  V<tmp_vector_sqr_3>, vMaskB
.endm

.macro vector_sqr vAA, vA
vector_sqr_inner \
        \vAA\()0,  \vAA\()1,  \vAA\()2,  \vAA\()3,  \vAA\()4,  \vAA\()5,  \vAA\()6,  \vAA\()7,  \vAA\()8,  \vAA\()9,  \
        \vA\()0,   \vA\()1,   \vA\()2,   \vA\()3,   \vA\()4,   \vA\()5,   \vA\()6,   \vA\()7,   \vA\()8,   \vA\()9
.endm

// vC0 .. vC9   output C = A*B
// vA0 .. vA9   first operand A
// vB0 .. vB9   second operand B
.macro vector_mul_inner \
        vC0, vC1, vC2, vC3, vC4, vC5, vC6, vC7, vC8, vC9, \
        vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9, \
        vB0, vB1, vB2, vB3, vB4, vB5, vB6, vB7, vB8, vB9
  vmull    \vC9, \vA0, \vB9
  vmlal    \vC9, \vA2, \vB7
  vmlal    \vC9, \vA4, \vB5
  vmlal    \vC9, \vA6, \vB3
  vmlal    \vC9, \vA8, \vB1
  vmul     \vB9, \vB9, vconst19
  vmull    \vC8, \vA1, \vB7
  vmlal    \vC8, \vA3, \vB5
  vmlal    \vC8, \vA5, \vB3
  vmlal    \vC8, \vA7, \vB1
  vmlal    \vC8, \vA9, \vB9
  vmlal    \vC9, \vA1, \vB8
  vmlal    \vC9, \vA3, \vB6
  vmlal    \vC9, \vA5, \vB4
  vmlal    \vC9, \vA7, \vB2
  vmlal    \vC9, \vA9, \vB0
  vshl_d   \vC8, \vC8, #1
  vmull    \vC7, \vA0, \vB7
  vmlal    \vC7, \vA2, \vB5
  vmlal    \vC7, \vA4, \vB3
  vmlal    \vC7, \vA6, \vB1
  vmlal    \vC7, \vA8, \vB9
  vmul     \vB7, \vB7, vconst19
  vmlal    \vC8, \vA0, \vB8
  vmlal    \vC8, \vA2, \vB6
  vmlal    \vC8, \vA4, \vB4
  vmlal    \vC8, \vA6, \vB2
  vmlal    \vC8, \vA8, \vB0
  vmul     \vB8, \vB8, vconst19
  vmull    \vC6, \vA1, \vB5
  vmlal    \vC6, \vA3, \vB3
  vmlal    \vC6, \vA5, \vB1
  vmlal    \vC6, \vA7, \vB9
  vmlal    \vC6, \vA9, \vB7
  vmlal    \vC7, \vA1, \vB6
  vmlal    \vC7, \vA3, \vB4
  vmlal    \vC7, \vA5, \vB2
  vmlal    \vC7, \vA7, \vB0
  vmlal    \vC7, \vA9, \vB8
  vshl_d   \vC6, \vC6, #1
  vmull    \vC5, \vA0, \vB5
  vmlal    \vC5, \vA2, \vB3
  vmlal    \vC5, \vA4, \vB1
  vmlal    \vC5, \vA6, \vB9
  vmlal    \vC5, \vA8, \vB7
  vmul     \vB5, \vB5, vconst19
  vmlal    \vC6, \vA0, \vB6
  vmlal    \vC6, \vA2, \vB4
  vmlal    \vC6, \vA4, \vB2
  vmlal    \vC6, \vA6, \vB0
  vmlal    \vC6, \vA8, \vB8
  vmul     \vB6, \vB6, vconst19
  vmull    \vC4, \vA1, \vB3
  vmlal    \vC4, \vA3, \vB1
  vmlal    \vC4, \vA5, \vB9
  vmlal    \vC4, \vA7, \vB7
  vmlal    \vC4, \vA9, \vB5
  vmlal    \vC5, \vA1, \vB4
  vmlal    \vC5, \vA3, \vB2
  vmlal    \vC5, \vA5, \vB0
  vmlal    \vC5, \vA7, \vB8
  vmlal    \vC5, \vA9, \vB6
  vshl_d   \vC4, \vC4, #1
  vmull    \vC3, \vA0, \vB3
  vmlal    \vC3, \vA2, \vB1
  vmlal    \vC3, \vA4, \vB9
  vmlal    \vC3, \vA6, \vB7
  vmlal    \vC3, \vA8, \vB5
  vmul     \vB3, \vB3, vconst19
  vmlal    \vC4, \vA0, \vB4
  vmlal    \vC4, \vA2, \vB2
  vmlal    \vC4, \vA4, \vB0
  vmlal    \vC4, \vA6, \vB8
  vmlal    \vC4, \vA8, \vB6
  vmul     \vB4, \vB4, vconst19
  vmull    \vC2, \vA1, \vB1
  vmlal    \vC2, \vA3, \vB9
  vmlal    \vC2, \vA5, \vB7
  vmlal    \vC2, \vA7, \vB5
  vmlal    \vC2, \vA9, \vB3
  vmlal    \vC3, \vA1, \vB2
  vmlal    \vC3, \vA3, \vB0
  vmlal    \vC3, \vA5, \vB8
  vmlal    \vC3, \vA7, \vB6
  vmlal    \vC3, \vA9, \vB4
  vshl_d   \vC2, \vC2, #1
  vmull    \vC1, \vA0, \vB1
  vmlal    \vC1, \vA2, \vB9
  vmlal    \vC1, \vA4, \vB7
  vmlal    \vC1, \vA6, \vB5
  vmlal    \vC1, \vA8, \vB3
  vmul     \vB1, \vB1, vconst19
  vmlal    \vC2, \vA0, \vB2
  vmlal    \vC2, \vA2, \vB0
  vmlal    \vC2, \vA4, \vB8
  vmlal    \vC2, \vA6, \vB6
  vmlal    \vC2, \vA8, \vB4
  vmul     \vB2, \vB2, vconst19
  vmull    \vC0, \vA1, \vB9
  vmlal    \vC0, \vA3, \vB7
  vmlal    \vC0, \vA5, \vB5
  vushr    vMaskB, vMaskA, #1
  vusra    \vC3, \vC2, #26
  vand     \vC2, \vC2, vMaskA
  vmlal    \vC1, \vA1, \vB0
  vusra    \vC4, \vC3, #25
  vand     \vC3, \vC3, vMaskB
  vmlal    \vC0, \vA7, \vB3
  vusra    \vC5, \vC4, #26
  vand     \vC4, \vC4, vMaskA
  vmlal    \vC1, \vA3, \vB8
  vusra    \vC6, \vC5, #25
  vand     \vC5, \vC5, vMaskB
  vmlal    \vC0, \vA9, \vB1
  vusra    \vC7, \vC6, #26
  vand     \vC6, \vC6, vMaskA
  vmlal    \vC1, \vA5, \vB6
  vmlal    \vC1, \vA7, \vB4
  vmlal    \vC1, \vA9, \vB2
  vusra    \vC8, \vC7, #25
  vand     \vC7, \vC7, vMaskB
  vshl_d   \vC0, \vC0, #1
  vusra    \vC9, \vC8, #26
  vand     \vC8, \vC8, vMaskA
  vmlal    \vC0, \vA0, \vB0
  vmlal    \vC0, \vA2, \vB8
  vmlal    \vC0, \vA4, \vB6
  vmlal    \vC0, \vA6, \vB4
  vmlal    \vC0, \vA8, \vB2
  vbic     \vB9, \vC9, vMaskB
  vand     \vC9, \vC9, vMaskB
  vusra    \vC0, \vB9, #25
  vusra    \vC0, \vB9, #24
  vusra    \vC0, \vB9, #21
  vusra    \vC1, \vC0, #26
  vand     \vC0, \vC0, vMaskA
  vusra    \vC2, \vC1, #25
  vand     \vC1, \vC1, vMaskB
  vusra    \vC3, \vC2, #26
  vand     \vC2, \vC2, vMaskA
.endm

.macro vector_mul vC, vA, vB
vector_mul_inner \
        \vC\()0, \vC\()1, \vC\()2, \vC\()3, \vC\()4, \vC\()5, \vC\()6, \vC\()7, \vC\()8, \vC\()9, \
        \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9, \
        \vB\()0, \vB\()1, \vB\()2, \vB\()3, \vB\()4, \vB\()5, \vB\()6, \vB\()7, \vB\()8, \vB\()9
.endm

#define STACK_MASK1     0
#define STACK_MASK2     8
#define STACK_A_0      16
#define STACK_A_8      (STACK_A_0+ 8)
#define STACK_A_16     (STACK_A_0+16)
#define STACK_A_24     (STACK_A_0+24)
#define STACK_A_32     (STACK_A_0+32)
#define STACK_B_0      64
#define STACK_B_8      (STACK_B_0+ 8)
#define STACK_B_16     (STACK_B_0+16)
#define STACK_B_24     (STACK_B_0+24)
#define STACK_B_32     (STACK_B_0+32)
#define STACK_CTR      104
#define STACK_LASTBIT  108
#define STACK_SCALAR  112
#define STACK_X_0     168
#define STACK_X_8     (STACK_X_0+ 8)
#define STACK_X_16    (STACK_X_0+16)
#define STACK_X_24    (STACK_X_0+24)
#define STACK_X_32    (STACK_X_0+32)
#define STACK_OUT_PTR (STACK_X_0+48)



    // in: x1: scalar pointer, x2: base point pointer
    // out: x0: result pointer
    .global    x25519_scalarmult_alt_orig
    .global    _x25519_scalarmult_alt_orig
    // .type    x25519_scalarmult, %function
x25519_scalarmult_alt_orig:
_x25519_scalarmult_alt_orig:
    stp    x29, x30, [sp, #-160]!
    mov    x29, sp
    stp    x19, x20, [sp, #16]
    stp    x21, x22, [sp, #32]
    stp    x23, x24, [sp, #48]
    stp    x25, x26, [sp, #64]
    stp    x27, x28, [sp, #80]
    stp    d8, d9, [sp, #96]
    stp    d10, d11, [sp, #112]
    stp    d12, d13, [sp, #128]
    stp    d14, d15, [sp, #144]
    sub    sp, sp, STACK_OUT_PTR+8

    // 0: mask1, 8: mask2, 16: AA, 56: B/BB, 96: counter, 100: lastbit, 104: scalar, 136: X1, 176: outptr, 184: padding, 192: fp, 200: lr

    str    x0, [sp, STACK_OUT_PTR] // outptr
    mov    x19, x2 // point

    mov    x0, x1 // scalar
    bl    load256unaligned

    and    x3, x3, #0x7fffffffffffffff
    and    x0, x0, #0xfffffffffffffff8
    orr    x3, x3, #0x4000000000000000

    stp    x0, x1, [sp, STACK_SCALAR]
    stp    x2, x3, [sp, STACK_SCALAR+16]

    mov    x0, x19 // point
    bl    load256unaligned

    // Unpack point (discard most significant bit)
    lsr    x12, x0, #51
    lsr    x17, x2, #51
    orr    w12, w12, w1, lsl #13
    orr    w17, w17, w3, lsl #13
    ubfx    x8, x3, #12, #26
    ubfx    x9, x3, #38, #25
    ubfx    x11, x0, #26, #25
    ubfx    x13, x1, #13, #25
    lsr    x14, x1, #38
    ubfx    x16, x2, #25, #26
    and    w10, w0, #0x3ffffff
    and    w12, w12, #0x3ffffff
    and    w15, w2, #0x1ffffff
    and    w17, w17, #0x1ffffff
    stp    w10, w11, [sp, STACK_X_0]
    stp    w12, w13, [sp, STACK_X_8]
    stp    w14, w15, [sp, STACK_X_16]
    stp    w16, w17, [sp, STACK_X_24]
    stp    w8, w9, [sp, STACK_X_32]

    // X2 (initially set to 1)
    mov    x1, #1
    mov    v0.d[0], x1
    mov    v2.d[0], xzr
    mov    v4.d[0], xzr
    mov    v6.d[0], xzr
    mov    v8.d[0], xzr

    // Z2 (initially set to 0)
    mov    v1.d[0], xzr
    mov    v3.d[0], xzr
    mov    v5.d[0], xzr
    mov    v7.d[0], xzr
    mov    v9.d[0], xzr

    // X3 (initially set to X1)
    mov    v10.s[0], w10
    mov    v10.s[1], w11
    mov    v12.s[0], w12
    mov    v12.s[1], w13
    mov    v14.s[0], w14
    mov    v14.s[1], w15
    mov    v16.s[0], w16
    mov    v16.s[1], w17
    mov    v18.s[0], w8
    mov    v18.s[1], w9

    // Z3 (initially set to 1)
    mov    v11.d[0], x1
    mov    v13.d[0], xzr
    mov    v15.d[0], xzr
    mov    v17.d[0], xzr
    mov    v19.d[0], xzr

    mov    x0,  #255-1 // 255 iterations
    stack_str_wform STACK_CTR, x0

    const19  .req x30
    vconst19 .req v31

    mov    w30, #19
    dup    vconst19.2s, w30
    mov    x0, #(1<<26)-1
    dup    v30.2d, x0
    ldr    x0, #=0x07fffffe07fffffc
    // TODO: I do not quite understand what the two stps are doing
    // First seems to write bytes 0-15 (mask1+mask2); second seems to write bytes 16-31 (mask2+A)
    stack_stp STACK_MASK1, STACK_MASK2, x0, x0

    sub    x1, x0, #0xfc-0xb4
    stack_stp STACK_MASK2, STACK_A_0, x1, x0

    stack_vldr_dform v28, STACK_MASK2
    stack_vldr_dform v29, STACK_MASK1

    stack_ldrb w1, STACK_SCALAR, 31
    lsr    w1, w1, #6
    stack_str STACK_LASTBIT, w1
mainloop:
    tst    W<x1>, #1
    vector_sub vB, vX2, vZ2
    vector_sub vD, vX3, vZ3
    vector_add vA, vX2, vZ2
    vector_add vC, vX3, vZ3
    vector_cmov  vF, vA, vC
    vector_to_scalar sF, vF
    vector_transpose vAB, vA, vB   // (B|A)
    vector_cmov vG, vB, vD
    vector_transpose vDC, vD, vC   // (C|D)
    vector_stack_str STACK_B, vG
    scalar_sqr sAA, sF
    scalar_stack_str STACK_A, sAA
    scalar_stack_ldr sG, STACK_B
    scalar_sqr sBB, sG
    scalar_stack_str STACK_B, sBB
    scalar_stack_ldr sE, STACK_A
    // EE = FF - GG (scalar)
    scalar_sub sE, sE, sBB
    scalar_clear_carries sBB
    scalar_decompress sE
    // BB = BB + 121666 *E
    scalar_addm sBB, sBB, sE, 121666
    // Z4 = BB*E = (BB + 121666 · E)E
    scalar_mul sZ4, sBB, sE

    // unnamed ones are only counter + lastbit logic
    stack_ldr x2, STACK_CTR
    lsr    x3, x2, #32
    subs   W<x0>, W<x2>, #1
    asr    W<x1>, W<x0>, #5
    add    x4, sp, #STACK_SCALAR
    ldr    W<x1>, [x4, W<x1>, SXTW #2]
    and    W<x4>, W<x0>, #0x1f
    lsr    W<x1>, W<x1>, W<x4>
    stack_stp_wform STACK_CTR, STACK_LASTBIT, x0, x1

    // C = A*B -- (CB | DA) = (C|D)*(B|A) (vector)
    vector_mul vADBC, vAB, vDC
    // Compute T1 = DA + CB; T2 = DA - CB; Repack T=(T1|T2)
    vector_addsub_repack vT, vADBC
    // TA = T^2 = (T1^2 | T2^2)
    vector_sqr vTA, vT
    vector_load_lane vTA, STACK_A, 1
    vector_load_lane vBX, STACK_B, 1
    vector_load_lane vBX, STACK_X, 0
    vector_mul vX4Z5, vTA, vBX
    vector_compress vTA, vTA
    vector_compress vZ3, vX4Z5
    eor W<x1>, W<x1>, W<x3>
    // Make X4 and Z5 more compact
    vector_extract_upper vX3, vTA
    // Z4 -> Z2
    scalar_to_vector vZ2, sZ4
    stack_vldr_dform v28, STACK_MASK2
    stack_vldr_dform v29, STACK_MASK1

    // X4 -> X2
    vector_extract_upper vX2, vZ3
end_label:
    subs   w11, w0, #-1
    cbnz   w11, mainloop


    mov    w0, v1.s[0]
    mov    w1, v1.s[1]
    mov    w2, v3.s[0]
    mov    w3, v3.s[1]
    mov    w4, v5.s[0]
    mov    w5, v5.s[1]
    mov    w6, v7.s[0]
    mov    w7, v7.s[1]
    mov    w8, v9.s[0]
    mov    w9, v9.s[1]

    stp    w0, w1, [sp, #80]
    stp    w2, w3, [sp, #88]
    stp    w4, w5, [sp, #96]
    stp    w6, w7, [sp, #104]
    stp    w8, w9, [sp, #112]

    mov    x10, v0.d[0]
    mov    x11, v2.d[0]
    mov    x12, v4.d[0]
    mov    x13, v6.d[0]
    mov    x14, v8.d[0]

    stp    x10, x11, [sp]
    stp    x12, x13, [sp, #16]
    str    x14, [sp, #32]

    adr    x10, invtable
    str    x10, [sp, #160]

.Linvloopnext:
    ldrh    w11, [x10], #2
    mov    v20.s[0], w11
    str    x10, [sp, #160]

    and    w12, w11, #0x7f
    subs    w30, w12, #1 // square times
    bmi    .Lskipsquare

    mov    w23, w3
    mov    w24, w4
    mov    w25, w5
    mov    w26, w6
    mov    w27, w7
    mov    w14, w8
    add    w10, w0, w0
    add    w11, w1, w1
    add    w12, w2, w2

.Lsqrloop1:
    umull    x20, w0, w0
        add    x4, x24, x23, lsr #25
    umull    x21, w10, w1
        and    x3, x23, #0x1ffffff
    umull    x22, w10, w2
        add    w13, w3, w3
    umull    x23, w10, w3
        add    x5, x25, x4, lsr #26
    umull    x24, w11, w13
        and    x4, x4, #0x3ffffff
    umull    x28, w4, w4
        add    x6, x26, x5, lsr #25
    umull    x25, w12, w3
        and    x5, x5, #0x1ffffff
    umull    x26, w13, w3
        add    w15, w5, w5
    umaddl    x28, w13, w15, x28
        add    x7, x27, x6, lsr #26
    umull    x19, w4, w15
        and    x6, x6, #0x3ffffff
    umull    x27, w11, w6
        add    x8, x14, x7, lsr #25
    umaddl    x28, w12, w6, x28
        and    x7, x7, #0x1ffffff
    umaddl    x19, w13, w6, x19
        add    x9, x9, x8, lsr #26
    umaddl    x27, w10, w7, x27
        add    w17, w7, w7
    umaddl    x28, w11, w17, x28
        and    x8, x8, #0x3ffffff
    umaddl    x19, w10, w9, x19
        add    w14, w9, w9
    umaddl    x27, w12, w5, x27
        add    w16, w14, w14, lsl #1
    umaddl    x28, w10, w8, x28
        add    w3, w15, w15, lsl #1
    umaddl    x19, w12, w7, x19
        add    w16, w16, w14, lsl #4
    umaddl    x27, w13, w4, x27
        add    w3, w3, w15, lsl #4
    umaddl    x28, w16, w9, x28

    umaddl    x19, w11, w8, x19
        add    w9, w6, w6, lsl #1
    umaddl    x20, w3, w5, x20

    umaddl    x24, w10, w4, x24
        add    w9, w9, w6, lsl #4
    umaddl    x25, w10, w5, x25
        add    x19, x19, x28, lsr #26
    umaddl    x26, w10, w6, x26
        and    x14, x28, #0x3ffffff
    umaddl    x22, w11, w1, x22
        add    x20, x20, x19, lsr #25
    umaddl    x23, w11, w2, x23
        bic    x1, x19, #0x1ffffff
    umaddl    x26, w12, w4, x26
        add    x20, x20, x1, lsr #24
    umaddl    x24, w2, w2, x24
        add    w0, w4, w4
    umaddl    x25, w11, w4, x25
        add    x20, x20, x1, lsr #21
    umaddl    x26, w11, w15, x26
        add    w1, w17, w17, lsl #1
    umaddl    x20, w9, w0, x20

    umaddl    x21, w9, w15, x21
        add    w1, w1, w17, lsl #4
    umaddl    x22, w9, w6, x22
        add    w10, w8, w8, lsl #1
    umaddl    x20, w1, w13, x20
        and    x9, x19, #0x1ffffff
    umaddl    x21, w1, w4, x21
        add    w10, w10, w8, lsl #4
    umaddl    x22, w1, w15, x22
        subs    w30, w30, #1
    umaddl    x20, w10, w12, x20

    umaddl    x21, w10, w13, x21

    umaddl    x22, w10, w0, x22

    umaddl    x20, w16, w11, x20

    umaddl    x21, w16, w2, x21

    umaddl    x22, w16, w13, x22
        add    w11, w6, w6
    umaddl    x23, w1, w6, x23

    umaddl    x24, w1, w7, x24
        add    x21, x21, x20, lsr #26
    umaddl    x26, w10, w8, x26
        and    x0, x20, #0x3ffffff
    umaddl    x23, w10, w15, x23
        add    x22, x22, x21, lsr #25
    umaddl    x24, w10, w11, x24
        and    x1, x21, #0x1ffffff
    umaddl    x25, w10, w17, x25
        and    x2, x22, #0x3ffffff
    umaddl    x23, w16, w4, x23
        add    w10, w0, w0
    umaddl    x24, w16, w15, x24
        add    w11, w1, w1
    umaddl    x25, w16, w6, x25
        add    w12, w2, w2
    umaddl    x26, w16, w17, x26
        add    x23, x23, x22, lsr #26
    umaddl    x27, w16, w8, x27
        bpl    .Lsqrloop1

    mov    w11, v20.s[0]
    add    x4, x24, x23, lsr #25
    and    x3, x23, #0x1ffffff
    add    x5, x25, x4, lsr #26
    and    x4, x4, #0x3ffffff
    add    x6, x26, x5, lsr #25
    and    x5, x5, #0x1ffffff
    add    x7, x27, x6, lsr #26
    and    x6, x6, #0x3ffffff
    add    x8, x14, x7, lsr #25
    and    x7, x7, #0x1ffffff
    add    x9, x9, x8, lsr #26
    and    x8, x8, #0x3ffffff
.Lskipsquare:
    mov    w12, #40
    tst    w11, #1<<8
    ubfx    w13, w11, #9, #2
    bne    .Lskipmul
    mul    w20, w13, w12
    add    x20, sp, x20

    ldp    w10, w11, [x20]
    ldp    w12, w13, [x20, #8]
    ldp    w14, w15, [x20, #16]
    ldp    w16, w17, [x20, #24]
    ldp    w19, w20, [x20, #32]
    mov    w30, #19

    umull    x21, w1, w19
    umull    x22, w1, w17
    umull    x23, w1, w16
    umull    x24, w1, w15
    umaddl    x21, w3, w16, x21
    umaddl    x22, w3, w15, x22
    umaddl    x23, w3, w14, x23
    umaddl    x24, w3, w13, x24
    umaddl    x21, w5, w14, x21
    umaddl    x22, w5, w13, x22
    umaddl    x23, w5, w12, x23
    umaddl    x24, w5, w11, x24
    umaddl    x21, w7, w12, x21
    umaddl    x22, w7, w11, x22
    umaddl    x23, w7, w10, x23
    mul    w27, w7, w30
    mul    w25, w9, w30
    mul    w26, w8, w30
    mul    w28, w6, w30
    umaddl    x24, w27, w20, x24
    umaddl    x21, w9, w10, x21
    umaddl    x22, w25, w20, x22
    umaddl    x23, w25, w19, x23
    umaddl    x24, w25, w17, x24
    add    x22, x22, x22
    umaddl    x21, w0, w20, x21
    add    x24, x24, x24
    umaddl    x22, w0, w19, x22
    umaddl    x23, w0, w17, x23
    umaddl    x24, w0, w16, x24
    umaddl    x21, w2, w17, x21
    umaddl    x22, w2, w16, x22
    umaddl    x23, w2, w15, x23
    umaddl    x24, w2, w14, x24
    umaddl    x21, w4, w15, x21
    umaddl    x22, w4, w14, x22
    umaddl    x23, w4, w13, x23
    umaddl    x24, w4, w12, x24
    umaddl    x21, w6, w13, x21
    umaddl    x22, w6, w12, x22
    umaddl    x23, w6, w11, x23
    umaddl    x24, w6, w10, x24
    umaddl    x21, w8, w11, x21
    umaddl    x22, w8, w10, x22
    umaddl    x23, w26, w20, x23
    umaddl    x24, w26, w19, x24
    umull    x6, w25, w16
    umull    x7, w25, w15
    umull    x8, w25, w14
    umaddl    x6, w5, w10, x6
    mul    w5, w5, w30
    umaddl    x7, w27, w17, x7
    umaddl    x8, w27, w16, x8
    umaddl    x6, w27, w19, x6
    umaddl    x7, w5, w20, x7
    umaddl    x8, w5, w19, x8
    umaddl    x6, w3, w12, x6
    umaddl    x7, w3, w11, x7
    umaddl    x8, w3, w10, x8
    umaddl    x6, w1, w14, x6
    umaddl    x7, w1, w13, x7
    umaddl    x8, w1, w12, x8
    mul    w9, w4, w30
    add    x7, x7, x7
    umaddl    x6, w26, w17, x6
    umaddl    x7, w26, w16, x7
    umaddl    x8, w26, w15, x8
    umaddl    x6, w28, w20, x6
    umaddl    x7, w28, w19, x7
    umaddl    x8, w28, w17, x8
    umaddl    x6, w4, w11, x6
    umaddl    x7, w4, w10, x7
    umaddl    x8, w9, w20, x8
    umaddl    x6, w2, w13, x6
    umaddl    x7, w2, w12, x7
    umaddl    x8, w2, w11, x8
    umaddl    x6, w0, w15, x6
    umaddl    x7, w0, w14, x7
    umaddl    x8, w0, w13, x8
    mul    w4, w3, w30
    add    x6, x6, x7, lsr #26
    and    x7, x7, #0x3ffffff
    add    x24, x24, x6, lsr #25
    and    x6, x6, #0x1ffffff
    add    x23, x23, x24, lsr #26
    and    x24, x24, #0x3ffffff
    add    x22, x22, x23, lsr #25
    bfi    x24, x23, #32, #25
    add    x21, x21, x22, lsr #26
    and    x22, x22, #0x3ffffff
    bic    x3, x21, #0x3ffffff
    lsr    x23, x3, #26
    bfi    x22, x21, #32, #26
    add    x23, x23, x3, lsr #25
    umull    x21, w25, w13
    add    x23, x23, x3, lsr #22
    umull    x3, w25, w12
    umaddl    x23, w25, w11, x23
    umaddl    x21, w27, w15, x21
    umaddl    x3, w27, w14, x3
    umaddl    x23, w27, w13, x23
    mul    w27, w1, w30
    umaddl    x3, w5, w16, x3
    umaddl    x23, w5, w15, x23
    umaddl    x21, w5, w17, x21
    umaddl    x3, w4, w19, x3
    umaddl    x23, w4, w17, x23
    umaddl    x21, w4, w20, x21
    umaddl    x3, w1, w10, x3
    umaddl    x23, w27, w20, x23
    umaddl    x21, w1, w11, x21
    mul    w25, w2, w30
    add    x23, x23, x23
    add    x21, x21, x21
    umaddl    x23, w26, w12, x23
    umaddl    x3, w26, w13, x3
    umaddl    x21, w26, w14, x21
    umaddl    x23, w28, w14, x23
    umaddl    x3, w28, w15, x3
    umaddl    x21, w28, w16, x21
    umaddl    x23, w9, w16, x23
    umaddl    x3, w9, w17, x3
    umaddl    x21, w9, w19, x21
    umaddl    x23, w25, w19, x23
    umaddl    x3, w25, w20, x3
    umaddl    x21, w2, w10, x21
    umaddl    x23, w0, w10, x23
    umaddl    x3, w0, w11, x3
    umaddl    x21, w0, w12, x21
    add    x1, x3, x23, lsr #26
    and    x0, x23, #0x3ffffff
    add    x2, x21, x1, lsr #25
    and    x1, x1, #0x1ffffff
    add    x3, x8, x2, lsr #26
    and    x2, x2, #0x3ffffff
    add    x4, x7, x3, lsr #25
    and    x3, x3, #0x1ffffff
    add    x5, x6, x4, lsr #26
    and    x4, x4, #0x3ffffff
    and    x5, x5, #0x3ffffff

    mov    w11, v20.s[0]
    mov    w6, w24
    lsr    x7, x24, #32
    mov    w8, w22
    lsr    x9, x22, #32
.Lskipmul:
    ubfx    w12, w11, #11, #2
    cbz    w12, .Lskipstore
    mov    w13, #40
    mul    w12, w12, w13
    add    x12, sp, x12

    stp    w0, w1, [x12]
    stp    w2, w3, [x12, #8]
    stp    w4, w5, [x12, #16]
    stp    w6, w7, [x12, #24]
    stp    w8, w9, [x12, #32]
.Lskipstore:

    ldr    x10, [sp, #160]
    adr    x11, invtable+13*2
    cmp    x10, x11
    bne    .Linvloopnext

    // Final reduce
    // w5 and w9 are 26 bits instead of 25

    orr    x10, x0, x1, lsl #26
    orr    x10, x10, x2, lsl #51

    lsr    x11, x2, #13
    orr    x11, x11, x3, lsl #13
    orr    x11, x11, x4, lsl #38

    add    x12, x5, x6, lsl #25
    adds    x12, x12, x7, lsl #51

    lsr    x13, x7, #13
    orr    x13, x13, x8, lsl #12
    orr    x13, x13, x9, lsl #38

    adcs    x13, x13, xzr
    adc    x14, xzr, xzr

    extr    x17, x14, x13, #63
    mov    w19, #19
    mul    w15, w17, w19
    add    w15, w15, #19

    adds    x15, x10, x15
    adcs    x15, x11, xzr
    adcs    x15, x12, xzr
    adcs    x15, x13, xzr
    adc    x16, x14, xzr

    extr    x16, x16, x15, #63
    mul    w16, w16, w19

    adds    x10, x10, x16
    adcs    x11, x11, xzr
    adcs    x12, x12, xzr
    adc    x13, x13, xzr
    and    x13, x13, 0x7fffffffffffffff

    ldr    x17, [sp, STACK_OUT_PTR]
    stp    x10, x11, [x17]
    stp    x12, x13, [x17, #16]

    add sp, sp, STACK_OUT_PTR+8

    ldp    x19, x20, [sp, #16]
    ldp    x21, x22, [sp, #32]
    ldp    x23, x24, [sp, #48]
    ldp    x25, x26, [sp, #64]
    ldp    x27, x28, [sp, #80]
    ldp    d8, d9, [sp, #96]
    ldp    d10, d11, [sp, #112]
    ldp    d12, d13, [sp, #128]
    ldp    d14, d15, [sp, #144]
    ldp    x29, x30, [sp], #160

    ret
    // .size    x25519_scalarmult, .-x25519_scalarmult
    // .type    invtable, %object
invtable:
    //        square times,
    //            skip mul,
    //                   mulsource,
    //                          dest
    .hword      1|(1<<8)       |(1<<11)
    .hword      2|       (2<<9)|(2<<11)
    .hword      0|       (1<<9)|(1<<11)
    .hword      1|       (2<<9)|(2<<11)
    .hword      5|       (2<<9)|(2<<11)
    .hword     10|       (2<<9)|(3<<11)
    .hword     20|       (3<<9)
    .hword     10|       (2<<9)|(2<<11)
    .hword     50|       (2<<9)|(3<<11)
    .hword    100|       (3<<9)
    .hword     50|       (2<<9)
    .hword      5|       (1<<9)
    .hword      0|       (0<<9)
    // .size    invtable, .-invtable

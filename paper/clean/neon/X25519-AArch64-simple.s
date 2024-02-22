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

//#include <hal_env.h>

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

START:


.macro scalar_stack_ldr sA, offset, name
  ldr \sA\()0, [sp, #\offset\()_0]  // @slothy:reads=[\name\()0]
  ldr \sA\()2, [sp, #\offset\()_8]  // @slothy:reads=[\name\()8]
  ldr \sA\()4, [sp, #\offset\()_16] // @slothy:reads=[\name\()16]
  ldr \sA\()6, [sp, #\offset\()_24] // @slothy:reads=[\name\()24]
  ldr \sA\()8, [sp, #\offset\()_32] // @slothy:reads=[\name\()32]
.endm

.macro scalar_stack_str offset, sA, name
    stp \sA\()0, \sA\()2, [sp, #\offset\()_0]  // @slothy:writes=[\name\()0,\name\()8]
    stp \sA\()4, \sA\()6, [sp, #\offset\()_16] // @slothy:writes=[\name\()16,\name\()24]
    str \sA\()8, [sp, #\offset\()_32]          // @slothy:writes=[\name\()32]
.endm

.macro vector_stack_str offset, vA, name
    stp D<\vA\()0>, D<\vA\()2>, [sp, #\offset\()_0]  // @slothy:writes=[\name\()0,\name\()8]
    stp D<\vA\()4>, D<\vA\()6>, [sp, #\offset\()_16] // @slothy:writes=[\name\()16,\name\()24]
    str D<\vA\()8>, [sp, #\offset\()_32]             // @slothy:writes=[\name\()32]
.endm

    // TODO: eliminate this explicit register assignment by converting stack_vld2_lane to AArch64Instruction
    xvector_load_lane_tmp .req x26

.macro vector_load_lane vA, offset, lane, name
    add xvector_load_lane_tmp, sp, #\offset\()_0
    ld2 { \vA\()0.s, \vA\()1.s }[\lane\()], [xvector_load_lane_tmp], #8 // @slothy:reads=[\name\()0]
    ld2 { \vA\()2.s, \vA\()3.s }[\lane\()], [xvector_load_lane_tmp], #8 // @slothy:reads=[\name\()8]
    ld2 { \vA\()4.s, \vA\()5.s }[\lane\()], [xvector_load_lane_tmp], #8 // @slothy:reads=[\name\()16]
    ld2 { \vA\()6.s, \vA\()7.s }[\lane\()], [xvector_load_lane_tmp], #8 // @slothy:reads=[\name\()24]
    ld2 { \vA\()8.s, \vA\()9.s }[\lane\()], [xvector_load_lane_tmp], #8 // @slothy:reads=[\name\()32]
.endm

.macro vector_sub_inner vC0, vC2, vC4, vC6, vC8, \
                        vA0, vA2, vA4, vA6, vA8,  vB0, vB2, vB4, vB6, vB8
    // (2^255-19)*4 - vB
    sub \vC0\().2s, v28.2s, \vB0\().2s
    sub \vC2\().2s, v29.2s, \vB2\().2s
    sub \vC4\().2s, v29.2s, \vB4\().2s
    sub \vC6\().2s, v29.2s, \vB6\().2s
    sub \vC8\().2s, v29.2s, \vB8\().2s

    // ... + vA
    add \vC0\().2s, \vA0\().2s, \vC0\().2s
    add \vC2\().2s, \vA2\().2s, \vC2\().2s
    add \vC4\().2s, \vA4\().2s, \vC4\().2s
    add \vC6\().2s, \vA6\().2s, \vC6\().2s
    add \vC8\().2s, \vA8\().2s, \vC8\().2s
.endm

.macro vector_sub vC, vA, vB
    vector_sub_inner \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,  \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm


.macro vector_add_inner vC0, vC2, vC4, vC6, vC8,  vA0, vA2, vA4, vA6, vA8,  vB0, vB2, vB4, vB6, vB8
    add \vC0\().2s, \vA0\().2s, \vB0\().2s
    add \vC2\().2s, \vA2\().2s, \vB2\().2s
    add \vC4\().2s, \vA4\().2s, \vB4\().2s
    add \vC6\().2s, \vA6\().2s, \vB6\().2s
    add \vC8\().2s, \vA8\().2s, \vB8\().2s
.endm

.macro vector_add vC, vA, vB
    vector_add_inner \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,  \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro vector_cmov_inner vA0, vA2, vA4, vA6, vA8,  vB0, vB2, vB4, vB6, vB8,  vC0, vC2, vC4, vC6, vC8
    fcsel_dform    \vA0, \vB0, \vC0, eq
    fcsel_dform    \vA2, \vB2, \vC2, eq
    fcsel_dform    \vA4, \vB4, \vC4, eq
    fcsel_dform    \vA6, \vB6, \vC6, eq
    fcsel_dform    \vA8, \vB8, \vC8, eq
.endm

.macro vector_cmov vA, vB, vC
    vector_cmov_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8,  \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,
.endm

.macro vector_transpose_inner vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9,  vB0, vB2, vB4, vB6, vB8,  vC0, vC2, vC4, vC6, vC8
    trn2 \vA1\().2s, \vB0\().2s, \vC0\().2s
    trn1 \vA0\().2s, \vB0\().2s, \vC0\().2s
    trn2 \vA3\().2s, \vB2\().2s, \vC2\().2s
    trn1 \vA2\().2s, \vB2\().2s, \vC2\().2s
    trn2 \vA5\().2s, \vB4\().2s, \vC4\().2s
    trn1 \vA4\().2s, \vB4\().2s, \vC4\().2s
    trn2 \vA7\().2s, \vB6\().2s, \vC6\().2s
    trn1 \vA6\().2s, \vB6\().2s, \vC6\().2s
    trn2 \vA9\().2s, \vB8\().2s, \vC8\().2s
    trn1 \vA8\().2s, \vB8\().2s, \vC8\().2s
.endm

.macro vector_transpose vA, vB, vC
    vector_transpose_inner \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8,  \vC\()0, \vC\()2, \vC\()4, \vC\()6, \vC\()8,
.endm

.macro vector_to_scalar_inner sA0, sA2, sA4, sA6, sA8,  vB0, vB2, vB4, vB6, vB8
    mov    \sA0, \vB0\().d[0]
    mov    \sA2, \vB2\().d[0]
    mov    \sA4, \vB4\().d[0]
    mov    \sA6, \vB6\().d[0]
    mov    \sA8, \vB8\().d[0]
.endm

.macro vector_to_scalar sA, vB
    vector_to_scalar_inner \sA\()0, \sA\()2, \sA\()4, \sA\()6, \sA\()8,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro scalar_to_vector_inner vA0, vA2, vA4, vA6, vA8,  sB0, sB2, sB4, sB6, sB8
    mov    \vA0\().d[0], \sB0
    mov    \vA2\().d[0], \sB2
    mov    \vA4\().d[0], \sB4
    mov    \vA6\().d[0], \sB6
    mov    \vA8\().d[0], \sB8
.endm

.macro scalar_to_vector vA, sB
    scalar_to_vector_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \sB\()0, \sB\()2, \sB\()4, \sB\()6, \sB\()8
.endm


.macro vector_extract_upper_inner vA0, vA2, vA4, vA6, vA8,  vB0, vB2, vB4, vB6, vB8
    mov \vA0\().d[0], \vB0\().d[1]
    mov \vA2\().d[0], \vB2\().d[1]
    mov \vA4\().d[0], \vB4\().d[1]
    mov \vA6\().d[0], \vB6\().d[1]
    mov \vA8\().d[0], \vB8\().d[1]
.endm

.macro vector_extract_upper vA, vB
    vector_extract_upper_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \vB\()0, \vB\()2, \vB\()4, \vB\()6, \vB\()8
.endm

.macro vector_compress_inner vA0, vA2, vA4, vA6, vA8,  vB0, vB1, vB2, vB3, vB4, vB5, vB6, vB7, vB8, vB9
    trn1 \vA0\().4s, \vB0\().4s, \vB1\().4s
    trn1 \vA2\().4s, \vB2\().4s, \vB3\().4s
    trn1 \vA4\().4s, \vB4\().4s, \vB5\().4s
    trn1 \vA6\().4s, \vB6\().4s, \vB7\().4s
    trn1 \vA8\().4s, \vB8\().4s, \vB9\().4s
.endm

.macro vector_compress vA, vB
    vector_compress_inner \vA\()0, \vA\()2, \vA\()4, \vA\()6, \vA\()8,  \vB\()0, \vB\()1, \vB\()2, \vB\()3, \vB\()4, \vB\()5, \vB\()6, \vB\()7, \vB\()8, \vB\()9,
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

.macro vector_addsub_repack_inner vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9,  vC0, vC1, vC2, vC3, vC4, vC5, vC6, vC7, vC8, vC9
    uzp1 vR_l4h4l5h5.4s, \vC4\().4s, \vC5\().4s
    uzp1 vR_l6h6l7h7.4s, \vC6\().4s, \vC7\().4s
    ld1r {vrepack_inner_tmp.2d}, [sp] // @slothy:reads=mask1
    uzp1 vR_l4567.4s, vR_l4h4l5h5.4s, vR_l6h6l7h7.4s
    uzp2 vR_h4567.4s, vR_l4h4l5h5.4s, vR_l6h6l7h7.4s
    trn1 vR_l89h89.4s, \vC8\().4s, \vC9\().4s
    ldr B<vrepack_inner_tmp2>, [sp, #STACK_MASK2] // @slothy:reads=mask2
    uzp1 vR_l0h0l1h1.4s, \vC0\().4s, \vC1\().4s
    uzp1 vR_l2h2l3h3.4s, \vC2\().4s, \vC3\().4s
    mov vR_h89xx.d[0], vR_l89h89.d[1]
    uzp1 vR_l0123.4s, vR_l0h0l1h1.4s, vR_l2h2l3h3.4s
    uzp2 vR_h0123.4s, vR_l0h0l1h1.4s, vR_l2h2l3h3.4s
    add vDiff4567.4s, vR_l4567.4s, vrepack_inner_tmp.4s
    add vDiff89xx.2s, vR_l89h89.2s, vrepack_inner_tmp.2s
    mov vrepack_inner_tmp.b[0], vrepack_inner_tmp2.b[0]
    add vSum0123.4s, vR_l0123.4s, vR_h0123.4s
    add vSum4567.4s, vR_l4567.4s, vR_h4567.4s
    add vSum89xx.2s, vR_l89h89.2s, vR_h89xx.2s
    add vDiff0123.4s, vR_l0123.4s, vrepack_inner_tmp.4s
    sub vDiff4567.4s, vDiff4567.4s, vR_h4567.4s
    sub vDiff0123.4s, vDiff0123.4s, vR_h0123.4s
    sub vDiff89xx.2s, vDiff89xx.2s, vR_h89xx.2s
    zip1 \vA0\().4s, vDiff0123.4s, vSum0123.4s
    zip2 \vA2\().4s, vDiff0123.4s, vSum0123.4s
    zip1 \vA4\().4s, vDiff4567.4s, vSum4567.4s
    zip2 \vA6\().4s, vDiff4567.4s, vSum4567.4s
    zip1 \vA8\().2s, vDiff89xx.2s, vSum89xx.2s
    zip2 \vA9\().2s, vDiff89xx.2s, vSum89xx.2s
    mov \vA1\().d[0], \vA0\().d[1]
    mov \vA3\().d[0], \vA2\().d[1]
    mov \vA5\().d[0], \vA4\().d[1]
    mov \vA7\().d[0], \vA6\().d[1]
.endm

.macro vector_addsub_repack vA, vC
vector_addsub_repack_inner  \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9,  \vC\()0, \vC\()1, \vC\()2, \vC\()3, \vC\()4, \vC\()5, \vC\()6, \vC\()7, \vC\()8, \vC\()9
.endm

// sAA0     .. sAA9       output AA = A^2
// sA0      .. sA9        input A
// TODO: simplify (this is still the same instruction order as before; we can make it simpler and leave the re-ordering to Sloty)
.macro scalar_sqr_inner  sAA0,     sAA1,     sAA2,     sAA3,     sAA4,     sAA5,     sAA6,     sAA7,     sAA8,     sAA9,       sA0,      sA1,      sA2,      sA3,      sA4,      sA5,      sA6,      sA7,      sA8,      sA9
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
scalar_sqr_inner  \sAA\()0,  \sAA\()1,  \sAA\()2,  \sAA\()3,  \sAA\()4,  \sAA\()5,  \sAA\()6,  \sAA\()7,  \sAA\()8,  \sAA\()9,   \sA\()0,   \sA\()1,   \sA\()2,   \sA\()3,   \sA\()4,   \sA\()5,   \sA\()6,   \sA\()7,   \sA\()8,   \sA\()9
.endm

// sC0     .. sC9        output C = A*B
// sA0     .. sA9        input A
// sB0     .. sB9        input B
.macro scalar_mul_inner  sC0,     sC1,     sC2,     sC3,     sC4,     sC5,     sC6,     sC7,     sC8,     sC9,      sA0,     sA1,     sA2,     sA3,     sA4,     sA5,     sA6,     sA7,     sA8,     sA9,      sB0,     sB1,     sB2,     sB3,     sB4,     sB5,     sB6,     sB7,     sB8,     sB9


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
scalar_mul_inner  \sC\()0,  \sC\()1,  \sC\()2,  \sC\()3,  \sC\()4,  \sC\()5,  \sC\()6,  \sC\()7,  \sC\()8,  \sC\()9,   \sA\()0,  \sA\()1,  \sA\()2,  \sA\()3,  \sA\()4,  \sA\()5,  \sA\()6,  \sA\()7,  \sA\()8,  \sA\()9,   \sB\()0,  \sB\()1,  \sB\()2,  \sB\()3,  \sB\()4,  \sB\()5,  \sB\()6,  \sB\()7,  \sB\()8,  \sB\()9
.endm

xtmp_scalar_sub_0 .req x21

// sC0 .. sC4   output C = A +  4p - B  (registers may be the same as A)
// sA0 .. sA4   first operand A
// sB0 .. sB4   second operand B
.macro scalar_sub_inner  sC0, sC1, sC2, sC3, sC4,  sA0, sA1, sA2, sA3, sA4,  sB0, sB1, sB2, sB3, sB4

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
scalar_sub_inner \sC\()0, \sC\()2, \sC\()4, \sC\()6, \sC\()8,  \sA\()0, \sA\()2, \sA\()4, \sA\()6, \sA\()8,  \sB\()0, \sB\()2, \sB\()4, \sB\()6, \sB\()8
.endm


.macro scalar_addm_inner   sC0, sC1, sC2, sC3, sC4, sC5, sC6, sC7, sC8, sC9,  sA0, sA1, sA2, sA3, sA4, sA5, sA6, sA7, sA8, sA9,  sB0, sB1, sB2, sB3, sB4, sB5, sB6, sB7, sB8, sB9,  multconst

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
scalar_addm_inner \sC\()0, \sC\()1, \sC\()2, \sC\()3, \sC\()4, \sC\()5, \sC\()6, \sC\()7, \sC\()8, \sC\()9,   \sA\()0, \sA\()1, \sA\()2, \sA\()3, \sA\()4, \sA\()5, \sA\()6, \sA\()7, \sA\()8, \sA\()9,   \sB\()0, \sB\()1, \sB\()2, \sB\()3, \sB\()4, \sB\()5, \sB\()6, \sB\()7, \sB\()8, \sB\()9,  \multconst
.endm

// vAA0     .. vAA9        output AA = A^2
// vA0      .. vA9         input A
.macro vector_sqr_inner  vAA0,     vAA1,     vAA2,     vAA3,     vAA4,     vAA5,     vAA6,     vAA7,     vAA8,     vAA9,      vA0,      vA1,      vA2,      vA3,      vA4,      vA5,      vA6,      vA7,      vA8,      vA9
  shl V<tmp_vector_sqr_dbl_9>.2s, \vA9\().2s, #1
  shl V<tmp_vector_sqr_dbl_8>.2s, \vA8\().2s, #1
  shl V<tmp_vector_sqr_dbl_7>.2s, \vA7\().2s, #1
  shl V<tmp_vector_sqr_dbl_6>.2s, \vA6\().2s, #1
  shl V<tmp_vector_sqr_dbl_5>.2s, \vA5\().2s, #1
  shl V<tmp_vector_sqr_dbl_4>.2s, \vA4\().2s, #1
  shl V<tmp_vector_sqr_dbl_3>.2s, \vA3\().2s, #1
  shl V<tmp_vector_sqr_dbl_2>.2s, \vA2\().2s, #1
  shl V<tmp_vector_sqr_dbl_1>.2s, \vA1\().2s, #1
  umull V<tmp_vector_sqr_9>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_9>.2s
  umlal V<tmp_vector_sqr_9>.2d, \vA1\().2s, V<tmp_vector_sqr_dbl_8>.2s
  umlal V<tmp_vector_sqr_9>.2d, \vA2\().2s, V<tmp_vector_sqr_dbl_7>.2s
  umlal V<tmp_vector_sqr_9>.2d, \vA3\().2s, V<tmp_vector_sqr_dbl_6>.2s
  umlal V<tmp_vector_sqr_9>.2d, \vA4\().2s, V<tmp_vector_sqr_dbl_5>.2s
  umull V<tmp_vector_sqr_8>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_8>.2s
  umlal V<tmp_vector_sqr_8>.2d, V<tmp_vector_sqr_dbl_1>.2s, V<tmp_vector_sqr_dbl_7>.2s
  umlal V<tmp_vector_sqr_8>.2d, \vA2\().2s, V<tmp_vector_sqr_dbl_6>.2s
  umlal V<tmp_vector_sqr_8>.2d, V<tmp_vector_sqr_dbl_3>.2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_8>.2d, \vA4\().2s, \vA4\().2s
  mul V<tmp_vector_sqr_tw_9>.2s, \vA9\().2s, vconst19.2s
  umull V<tmp_vector_sqr_7>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_7>.2s
  umlal V<tmp_vector_sqr_7>.2d, \vA1\().2s, V<tmp_vector_sqr_dbl_6>.2s
  umlal V<tmp_vector_sqr_7>.2d, \vA2\().2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_7>.2d, \vA3\().2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_8>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_dbl_9>.2s
  umull V<tmp_vector_sqr_6>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_6>.2s
  umlal V<tmp_vector_sqr_6>.2d, V<tmp_vector_sqr_dbl_1>.2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_6>.2d, \vA2\().2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_6>.2d, V<tmp_vector_sqr_dbl_3>.2s, \vA3\().2s
  umull V<tmp_vector_sqr_5>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_5>.2d, \vA1\().2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_5>.2d, \vA2\().2s, V<tmp_vector_sqr_dbl_3>.2s
  umull V<tmp_vector_sqr_4>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_4>.2d, V<tmp_vector_sqr_dbl_1>.2s, V<tmp_vector_sqr_dbl_3>.2s
  umlal V<tmp_vector_sqr_4>.2d, \vA2\().2s, \vA2\().2s
  umull V<tmp_vector_sqr_3>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_3>.2s
  umlal V<tmp_vector_sqr_3>.2d, \vA1\().2s, V<tmp_vector_sqr_dbl_2>.2s
  umull V<tmp_vector_sqr_2>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_2>.2s
  umlal V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_dbl_1>.2s, \vA1\().2s
  umull V<tmp_vector_sqr_1>.2d, \vA0\().2s, V<tmp_vector_sqr_dbl_1>.2s
  umull V<tmp_vector_sqr_0>.2d, \vA0\().2s, \vA0\().2s
  usra V<tmp_vector_sqr_9>.2d, V<tmp_vector_sqr_8>.2d, #26
  and V<tmp_vector_sqr_8>.16b, V<tmp_vector_sqr_8>.16b, vMaskA.16b
  mul V<tmp_vector_sqr_tw_8>.2s, \vA8\().2s, vconst19.2s
  bic V<tmp_vector_sqr_dbl_9>.16b, V<tmp_vector_sqr_9>.16b, vMaskB.16b
  and \vA9\().16b, V<tmp_vector_sqr_9>.16b, vMaskB.16b
  usra V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_dbl_9>.2d, #25
  mul V<tmp_vector_sqr_tw_7>.2s, \vA7\().2s, vconst19.2s
  usra V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_dbl_9>.2d, #24
  mul V<tmp_vector_sqr_tw_6>.2s, \vA6\().2s, vconst19.2s
  usra V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_dbl_9>.2d, #21
  mul V<tmp_vector_sqr_tw_5>.2s, \vA5\().2s, vconst19.2s
  shl V<tmp_vector_sqr_quad_1>.2s, V<tmp_vector_sqr_dbl_1>.2s, #1
  shl V<tmp_vector_sqr_quad_3>.2s, V<tmp_vector_sqr_dbl_3>.2s, #1
  shl V<tmp_vector_sqr_quad_5>.2s, V<tmp_vector_sqr_dbl_5>.2s, #1
  shl V<tmp_vector_sqr_quad_7>.2s, V<tmp_vector_sqr_dbl_7>.2s, #1
  umlal V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_tw_5>.2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_quad_1>.2s
  umlal V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_2>.2s
  umlal V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_tw_7>.2s, V<tmp_vector_sqr_quad_3>.2s
  umlal V<tmp_vector_sqr_0>.2d, V<tmp_vector_sqr_tw_6>.2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_1>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_dbl_2>.2s
  umlal V<tmp_vector_sqr_1>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_3>.2s
  umlal V<tmp_vector_sqr_1>.2d, V<tmp_vector_sqr_tw_7>.2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_1>.2d, V<tmp_vector_sqr_tw_6>.2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_tw_6>.2s, \vA6\().2s
  umlal V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_quad_3>.2s
  umlal V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_tw_7>.2s, V<tmp_vector_sqr_quad_5>.2s
  usra V<tmp_vector_sqr_1>.2d, V<tmp_vector_sqr_0>.2d, #26
  umlal V<tmp_vector_sqr_3>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_dbl_4>.2s
  umlal V<tmp_vector_sqr_3>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_5>.2s
  umlal V<tmp_vector_sqr_3>.2d, V<tmp_vector_sqr_tw_7>.2s, V<tmp_vector_sqr_dbl_6>.2s
  usra V<tmp_vector_sqr_2>.2d, V<tmp_vector_sqr_1>.2d, #25
  umlal V<tmp_vector_sqr_4>.2d, V<tmp_vector_sqr_tw_7>.2s, V<tmp_vector_sqr_dbl_7>.2s
  umlal V<tmp_vector_sqr_4>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_quad_5>.2s
  umlal V<tmp_vector_sqr_4>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_6>.2s
  usra V<tmp_vector_sqr_3>.2d, V<tmp_vector_sqr_2>.2d, #26
  umlal V<tmp_vector_sqr_5>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_dbl_6>.2s
  umlal V<tmp_vector_sqr_5>.2d, V<tmp_vector_sqr_tw_8>.2s, V<tmp_vector_sqr_dbl_7>.2s
  usra V<tmp_vector_sqr_4>.2d, V<tmp_vector_sqr_3>.2d, #25
  umlal V<tmp_vector_sqr_6>.2d, V<tmp_vector_sqr_tw_8>.2s, \vA8\().2s
  umlal V<tmp_vector_sqr_6>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_quad_7>.2s
  usra V<tmp_vector_sqr_5>.2d, V<tmp_vector_sqr_4>.2d, #26
  umlal V<tmp_vector_sqr_7>.2d, V<tmp_vector_sqr_tw_9>.2s, V<tmp_vector_sqr_dbl_8>.2s
  usra V<tmp_vector_sqr_6>.2d, V<tmp_vector_sqr_5>.2d, #25
  usra V<tmp_vector_sqr_7>.2d, V<tmp_vector_sqr_6>.2d, #26
  usra V<tmp_vector_sqr_8>.2d, V<tmp_vector_sqr_7>.2d, #25
  usra \vAA9\().2d, V<tmp_vector_sqr_8>.2d, #26
  and \vAA4\().16b, V<tmp_vector_sqr_4>.16b, vMaskA.16b
  and \vAA5\().16b, V<tmp_vector_sqr_5>.16b, vMaskB.16b
  and \vAA0\().16b, V<tmp_vector_sqr_0>.16b, vMaskA.16b
  and \vAA6\().16b, V<tmp_vector_sqr_6>.16b, vMaskA.16b
  and \vAA1\().16b, V<tmp_vector_sqr_1>.16b, vMaskB.16b
  and \vAA7\().16b, V<tmp_vector_sqr_7>.16b, vMaskB.16b
  and \vAA2\().16b, V<tmp_vector_sqr_2>.16b, vMaskA.16b
  and \vAA8\().16b, V<tmp_vector_sqr_8>.16b, vMaskA.16b
  and \vAA3\().16b, V<tmp_vector_sqr_3>.16b, vMaskB.16b
.endm

.macro vector_sqr vAA, vA
vector_sqr_inner  \vAA\()0,  \vAA\()1,  \vAA\()2,  \vAA\()3,  \vAA\()4,  \vAA\()5,  \vAA\()6,  \vAA\()7,  \vAA\()8,  \vAA\()9,   \vA\()0,   \vA\()1,   \vA\()2,   \vA\()3,   \vA\()4,   \vA\()5,   \vA\()6,   \vA\()7,   \vA\()8,   \vA\()9
.endm

// vC0 .. vC9   output C = A*B
// vA0 .. vA9   first operand A
// vB0 .. vB9   second operand B
.macro vector_mul_inner  vC0, vC1, vC2, vC3, vC4, vC5, vC6, vC7, vC8, vC9,  vA0, vA1, vA2, vA3, vA4, vA5, vA6, vA7, vA8, vA9,  vB0, vB1, vB2, vB3, vB4, vB5, vB6, vB7, vB8, vB9
  umull \vC9\().2d, \vA0\().2s, \vB9\().2s
  umlal \vC9\().2d, \vA2\().2s, \vB7\().2s
  umlal \vC9\().2d, \vA4\().2s, \vB5\().2s
  umlal \vC9\().2d, \vA6\().2s, \vB3\().2s
  umlal \vC9\().2d, \vA8\().2s, \vB1\().2s
  mul \vB9\().2s, \vB9\().2s, vconst19.2s
  umull \vC8\().2d, \vA1\().2s, \vB7\().2s
  umlal \vC8\().2d, \vA3\().2s, \vB5\().2s
  umlal \vC8\().2d, \vA5\().2s, \vB3\().2s
  umlal \vC8\().2d, \vA7\().2s, \vB1\().2s
  umlal \vC8\().2d, \vA9\().2s, \vB9\().2s
  umlal \vC9\().2d, \vA1\().2s, \vB8\().2s
  umlal \vC9\().2d, \vA3\().2s, \vB6\().2s
  umlal \vC9\().2d, \vA5\().2s, \vB4\().2s
  umlal \vC9\().2d, \vA7\().2s, \vB2\().2s
  umlal \vC9\().2d, \vA9\().2s, \vB0\().2s
  shl \vC8\().2d, \vC8\().2d, #1
  umull \vC7\().2d, \vA0\().2s, \vB7\().2s
  umlal \vC7\().2d, \vA2\().2s, \vB5\().2s
  umlal \vC7\().2d, \vA4\().2s, \vB3\().2s
  umlal \vC7\().2d, \vA6\().2s, \vB1\().2s
  umlal \vC7\().2d, \vA8\().2s, \vB9\().2s
  mul \vB7\().2s, \vB7\().2s, vconst19.2s
  umlal \vC8\().2d, \vA0\().2s, \vB8\().2s
  umlal \vC8\().2d, \vA2\().2s, \vB6\().2s
  umlal \vC8\().2d, \vA4\().2s, \vB4\().2s
  umlal \vC8\().2d, \vA6\().2s, \vB2\().2s
  umlal \vC8\().2d, \vA8\().2s, \vB0\().2s
  mul \vB8\().2s, \vB8\().2s, vconst19.2s
  umull \vC6\().2d, \vA1\().2s, \vB5\().2s
  umlal \vC6\().2d, \vA3\().2s, \vB3\().2s
  umlal \vC6\().2d, \vA5\().2s, \vB1\().2s
  umlal \vC6\().2d, \vA7\().2s, \vB9\().2s
  umlal \vC6\().2d, \vA9\().2s, \vB7\().2s
  umlal \vC7\().2d, \vA1\().2s, \vB6\().2s
  umlal \vC7\().2d, \vA3\().2s, \vB4\().2s
  umlal \vC7\().2d, \vA5\().2s, \vB2\().2s
  umlal \vC7\().2d, \vA7\().2s, \vB0\().2s
  umlal \vC7\().2d, \vA9\().2s, \vB8\().2s
  shl \vC6\().2d, \vC6\().2d, #1
  umull \vC5\().2d, \vA0\().2s, \vB5\().2s
  umlal \vC5\().2d, \vA2\().2s, \vB3\().2s
  umlal \vC5\().2d, \vA4\().2s, \vB1\().2s
  umlal \vC5\().2d, \vA6\().2s, \vB9\().2s
  umlal \vC5\().2d, \vA8\().2s, \vB7\().2s
  mul \vB5\().2s, \vB5\().2s, vconst19.2s
  umlal \vC6\().2d, \vA0\().2s, \vB6\().2s
  umlal \vC6\().2d, \vA2\().2s, \vB4\().2s
  umlal \vC6\().2d, \vA4\().2s, \vB2\().2s
  umlal \vC6\().2d, \vA6\().2s, \vB0\().2s
  umlal \vC6\().2d, \vA8\().2s, \vB8\().2s
  mul \vB6\().2s, \vB6\().2s, vconst19.2s
  umull \vC4\().2d, \vA1\().2s, \vB3\().2s
  umlal \vC4\().2d, \vA3\().2s, \vB1\().2s
  umlal \vC4\().2d, \vA5\().2s, \vB9\().2s
  umlal \vC4\().2d, \vA7\().2s, \vB7\().2s
  umlal \vC4\().2d, \vA9\().2s, \vB5\().2s
  umlal \vC5\().2d, \vA1\().2s, \vB4\().2s
  umlal \vC5\().2d, \vA3\().2s, \vB2\().2s
  umlal \vC5\().2d, \vA5\().2s, \vB0\().2s
  umlal \vC5\().2d, \vA7\().2s, \vB8\().2s
  umlal \vC5\().2d, \vA9\().2s, \vB6\().2s
  shl \vC4\().2d, \vC4\().2d, #1
  umull \vC3\().2d, \vA0\().2s, \vB3\().2s
  umlal \vC3\().2d, \vA2\().2s, \vB1\().2s
  umlal \vC3\().2d, \vA4\().2s, \vB9\().2s
  umlal \vC3\().2d, \vA6\().2s, \vB7\().2s
  umlal \vC3\().2d, \vA8\().2s, \vB5\().2s
  mul \vB3\().2s, \vB3\().2s, vconst19.2s
  umlal \vC4\().2d, \vA0\().2s, \vB4\().2s
  umlal \vC4\().2d, \vA2\().2s, \vB2\().2s
  umlal \vC4\().2d, \vA4\().2s, \vB0\().2s
  umlal \vC4\().2d, \vA6\().2s, \vB8\().2s
  umlal \vC4\().2d, \vA8\().2s, \vB6\().2s
  mul \vB4\().2s, \vB4\().2s, vconst19.2s
  umull \vC2\().2d, \vA1\().2s, \vB1\().2s
  umlal \vC2\().2d, \vA3\().2s, \vB9\().2s
  umlal \vC2\().2d, \vA5\().2s, \vB7\().2s
  umlal \vC2\().2d, \vA7\().2s, \vB5\().2s
  umlal \vC2\().2d, \vA9\().2s, \vB3\().2s
  umlal \vC3\().2d, \vA1\().2s, \vB2\().2s
  umlal \vC3\().2d, \vA3\().2s, \vB0\().2s
  umlal \vC3\().2d, \vA5\().2s, \vB8\().2s
  umlal \vC3\().2d, \vA7\().2s, \vB6\().2s
  umlal \vC3\().2d, \vA9\().2s, \vB4\().2s
  shl \vC2\().2d, \vC2\().2d, #1
  umull \vC1\().2d, \vA0\().2s, \vB1\().2s
  umlal \vC1\().2d, \vA2\().2s, \vB9\().2s
  umlal \vC1\().2d, \vA4\().2s, \vB7\().2s
  umlal \vC1\().2d, \vA6\().2s, \vB5\().2s
  umlal \vC1\().2d, \vA8\().2s, \vB3\().2s
  mul \vB1\().2s, \vB1\().2s, vconst19.2s
  umlal \vC2\().2d, \vA0\().2s, \vB2\().2s
  umlal \vC2\().2d, \vA2\().2s, \vB0\().2s
  umlal \vC2\().2d, \vA4\().2s, \vB8\().2s
  umlal \vC2\().2d, \vA6\().2s, \vB6\().2s
  umlal \vC2\().2d, \vA8\().2s, \vB4\().2s
  mul \vB2\().2s, \vB2\().2s, vconst19.2s
  umull \vC0\().2d, \vA1\().2s, \vB9\().2s
  umlal \vC0\().2d, \vA3\().2s, \vB7\().2s
  umlal \vC0\().2d, \vA5\().2s, \vB5\().2s
  ushr vMaskB.2d, vMaskA.2d, #1
  usra \vC3\().2d, \vC2\().2d, #26
  and \vC2\().16b, \vC2\().16b, vMaskA.16b
  umlal \vC1\().2d, \vA1\().2s, \vB0\().2s
  usra \vC4\().2d, \vC3\().2d, #25
  and \vC3\().16b, \vC3\().16b, vMaskB.16b
  umlal \vC0\().2d, \vA7\().2s, \vB3\().2s
  usra \vC5\().2d, \vC4\().2d, #26
  and \vC4\().16b, \vC4\().16b, vMaskA.16b
  umlal \vC1\().2d, \vA3\().2s, \vB8\().2s
  usra \vC6\().2d, \vC5\().2d, #25
  and \vC5\().16b, \vC5\().16b, vMaskB.16b
  umlal \vC0\().2d, \vA9\().2s, \vB1\().2s
  usra \vC7\().2d, \vC6\().2d, #26
  and \vC6\().16b, \vC6\().16b, vMaskA.16b
  umlal \vC1\().2d, \vA5\().2s, \vB6\().2s
  umlal \vC1\().2d, \vA7\().2s, \vB4\().2s
  umlal \vC1\().2d, \vA9\().2s, \vB2\().2s
  usra \vC8\().2d, \vC7\().2d, #25
  and \vC7\().16b, \vC7\().16b, vMaskB.16b
  shl \vC0\().2d, \vC0\().2d, #1
  usra \vC9\().2d, \vC8\().2d, #26
  and \vC8\().16b, \vC8\().16b, vMaskA.16b
  umlal \vC0\().2d, \vA0\().2s, \vB0\().2s
  umlal \vC0\().2d, \vA2\().2s, \vB8\().2s
  umlal \vC0\().2d, \vA4\().2s, \vB6\().2s
  umlal \vC0\().2d, \vA6\().2s, \vB4\().2s
  umlal \vC0\().2d, \vA8\().2s, \vB2\().2s
  bic \vB9\().16b, \vC9\().16b, vMaskB.16b
  and \vC9\().16b, \vC9\().16b, vMaskB.16b
  usra \vC0\().2d, \vB9\().2d, #25
  usra \vC0\().2d, \vB9\().2d, #24
  usra \vC0\().2d, \vB9\().2d, #21
  usra \vC1\().2d, \vC0\().2d, #26
  and \vC0\().16b, \vC0\().16b, vMaskA.16b
  usra \vC2\().2d, \vC1\().2d, #25
  and \vC1\().16b, \vC1\().16b, vMaskB.16b
  usra \vC3\().2d, \vC2\().2d, #26
  and \vC2\().16b, \vC2\().16b, vMaskA.16b
.endm

.macro vector_mul vC, vA, vB
vector_mul_inner  \vC\()0, \vC\()1, \vC\()2, \vC\()3, \vC\()4, \vC\()5, \vC\()6, \vC\()7, \vC\()8, \vC\()9,  \vA\()0, \vA\()1, \vA\()2, \vA\()3, \vA\()4, \vA\()5, \vA\()6, \vA\()7, \vA\()8, \vA\()9,  \vB\()0, \vB\()1, \vB\()2, \vB\()3, \vB\()4, \vB\()5, \vB\()6, \vB\()7, \vB\()8, \vB\()9
.endm

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
    str W0, [sp, #STACK_CTR] // @slothy:writes=ctr

    const19  .req x30
    vconst19 .req v31

    mov    w30, #19
    dup    vconst19.2s, w30
    mov    x0, #(1<<26)-1
    dup    v30.2d, x0
    ldr    x0, #=0x07fffffe07fffffc
    // TODO: I do not quite understand what the two stps are doing
    // First seems to write bytes 0-15 (mask1+mask2); second seems to write bytes 16-31 (mask2+A)
    // stp x0, x0, [sp, #STACK_MASK1] // @slothy:writes=mask1

    sub x1, x0, #0xfc-0xb4
    str x0, [sp, #STACK_MASK1] // @slothy:writes=mask1
    str x1, [sp, #STACK_MASK2] // @slothy:writes=mask2

    ldr d28, [sp, #STACK_MASK2] // @slothy:reads=mask2
    ldr d29, [sp, #STACK_MASK1] // @slothy:reads=mask1

    ldrb w1, [sp, #STACK_SCALAR+31]
    lsr    w1, w1, #6
    str w1, [sp, #STACK_LASTBIT] // @slothy:writes=lastbit
mainloop:
    tst    W<x1>, #1
    vector_sub vB, vX2, vZ2
    vector_sub vD, vX3, vZ3
    vector_add vA, vX2, vZ2
    vector_add vC, vX3, vZ3
    vector_cmov  vF, vA, vC
    vector_to_scalar sF, vF
    vector_transpose vAB, vA, vB
    vector_cmov vG, vB, vD
    vector_transpose vDC, vD, vC
    vector_stack_str STACK_B, vG, B
    scalar_sqr sAA, sF
    scalar_stack_str STACK_A, sAA, A
    scalar_stack_ldr sG, STACK_B, B
    scalar_sqr sBB, sG
    scalar_stack_str STACK_B, sBB, B
    scalar_stack_ldr sE, STACK_A, A
    // EE = FF - GG (scalar)
    scalar_sub sE, sE, sBB
    scalar_clear_carries sBB
    scalar_decompress sE
    // BB = BB + 121666 *E
    scalar_addm sBB, sBB, sE, 121666
    // Z4 = BB*E = (BB + 121666 · E)E
    scalar_mul sZ4, sBB, sE

    // unnamed ones are only counter + lastbit logic
    ldr x2, [sp, #STACK_CTR] // @slothy:reads=[ctr,lastbit]
    lsr    x3, x2, #32
    subs   W<x0>, W<x2>, #1
    asr    W<x1>, W<x0>, #5
    add    x4, sp, #STACK_SCALAR
    ldr    W<x1>, [x4, W<x1>, SXTW #2]
    and    W<x4>, W<x0>, #0x1f
    lsr    W<x1>, W<x1>, W<x4>
    stp w0, w1, [sp, #STACK_CTR] // @slothy:writes=[ctr,lastbit]

    vector_mul vADBC, vAB, vDC
    vector_addsub_repack vT, vADBC
    vector_sqr vTA, vT
    vector_load_lane vTA, STACK_A, 1, A
    vector_load_lane vBX, STACK_B, 1, B
    vector_load_lane vBX, STACK_X, 0, X
    vector_mul vX4Z5, vTA, vBX
    vector_compress vTA, vTA
    vector_compress vZ3, vX4Z5
    eor W1, W1, W3
    // Make X4 and Z5 more compact
    vector_extract_upper vX3, vTA
    // Z4 -> Z2
    scalar_to_vector vZ2, sZ4
    ldr D28, [sp, #STACK_MASK2] // @slothy:reads=mask2
    ldr D29, [sp, #STACK_MASK1] // @slothy:reads=mask1

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
    // square times,
    // skip mul,
    // mulsource,
    // dest
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

END:

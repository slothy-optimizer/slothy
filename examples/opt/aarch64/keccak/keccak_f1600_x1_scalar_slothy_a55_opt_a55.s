/*
 * Copyright (c) 2021-2022 Arm Limited
 * Copyright (c) 2022 Matthias Kannwischer
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */


// Author: Hanno Becker <hanno.becker@arm.com>
// Author: Matthias Kannwischer <matthias@kannwischer.eu>


#include "macros.s"

/********************** CONSTANTS *************************/
    .data
    .balign 64
round_constants:
    .quad 0x0000000000000001
    .quad 0x0000000000008082
    .quad 0x800000000000808a
    .quad 0x8000000080008000
    .quad 0x000000000000808b
    .quad 0x0000000080000001
    .quad 0x8000000080008081
    .quad 0x8000000000008009
    .quad 0x000000000000008a
    .quad 0x0000000000000088
    .quad 0x0000000080008009
    .quad 0x000000008000000a
    .quad 0x000000008000808b
    .quad 0x800000000000008b
    .quad 0x8000000000008089
    .quad 0x8000000000008003
    .quad 0x8000000000008002
    .quad 0x8000000000000080
    .quad 0x000000000000800a
    .quad 0x800000008000000a
    .quad 0x8000000080008081
    .quad 0x8000000000008080
    .quad 0x0000000080000001
    .quad 0x8000000080008008

/****************** REGISTER ALLOCATIONS *******************/

    input_addr     .req x0
    const_addr     .req x26
    cur_const      .req x26
    count          .req w27

    /* Mapping of Kecck-f1600 state to scalar registers
     * at the beginning and end of each round. */
    Aba     .req x1
    Abe     .req x6
    Abi     .req x11
    Abo     .req x16
    Abu     .req x21
    Aga     .req x2
    Age     .req x7
    Agi     .req x12
    Ago     .req x17
    Agu     .req x22
    Aka     .req x3
    Ake     .req x8
    Aki     .req x13
    Ako     .req x18
    Aku     .req x23
    Ama     .req x4
    Ame     .req x9
    Ami     .req x14
    Amo     .req x19
    Amu     .req x24
    Asa     .req x5
    Ase     .req x10
    Asi     .req x15
    Aso     .req x20
    Asu     .req x25

    /* A_[y,2*x+3*y] = rot(A[x,y]) */
    Aba_ .req x30
    Abe_ .req x28
    Abi_ .req x11
    Abo_ .req x16
    Abu_ .req x21
    Aga_ .req x3
    Age_ .req x8
    Agi_ .req x12
    Ago_ .req x17
    Agu_ .req x22
    Aka_ .req x4
    Ake_ .req x9
    Aki_ .req x13
    Ako_ .req x18
    Aku_ .req x23
    Ama_ .req x5
    Ame_ .req x10
    Ami_ .req x14
    Amo_ .req x19
    Amu_ .req x24
    Asa_ .req x1
    Ase_ .req x6
    Asi_ .req x15
    Aso_ .req x20
    Asu_ .req x25

    /* C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4],   for x in 0..4 */
    /* E[x] = C[x-1] xor rot(C[x+1],1), for x in 0..4 */
    C0 .req x30
    E0 .req x29
    C1 .req x26
    E1 .req x0
    C2 .req x27
    E2 .req x26
    C3 .req x28
    E3 .req x27
    C4 .req x29
    E4 .req x28

    tmp .req x0

    tmp0 .req x0
    tmp1 .req x29

/************************ MACROS ****************************/

#define STACK_SIZE (16*6 + 3*8 + 8) // GPRs (16*6), count (8), const (8), input (8), padding (8)
#define STACK_BASE_GPRS (3*8+8)
#define STACK_OFFSET_INPUT (0*8)
#define STACK_OFFSET_CONST (1*8)
#define STACK_OFFSET_COUNT (2*8)

.macro alloc_stack
    sub sp, sp, #(STACK_SIZE)
.endm

.macro free_stack
    add sp, sp, #(STACK_SIZE)
.endm

.macro save_gprs
    stp x19, x20, [sp, #(STACK_BASE_GPRS + 16*0)]
    stp x21, x22, [sp, #(STACK_BASE_GPRS + 16*1)]
    stp x23, x24, [sp, #(STACK_BASE_GPRS + 16*2)]
    stp x25, x26, [sp, #(STACK_BASE_GPRS + 16*3)]
    stp x27, x28, [sp, #(STACK_BASE_GPRS + 16*4)]
    stp x29, x30, [sp, #(STACK_BASE_GPRS + 16*5)]
.endm

.macro restore_gprs
    ldp x19, x20, [sp, #(STACK_BASE_GPRS + 16*0)]
    ldp x21, x22, [sp, #(STACK_BASE_GPRS + 16*1)]
    ldp x23, x24, [sp, #(STACK_BASE_GPRS + 16*2)]
    ldp x25, x26, [sp, #(STACK_BASE_GPRS + 16*3)]
    ldp x27, x28, [sp, #(STACK_BASE_GPRS + 16*4)]
    ldp x29, x30, [sp, #(STACK_BASE_GPRS + 16*5)]
.endm

.macro eor5 dst, src0, src1, src2, src3, src4
    eor \dst, \src0, \src1
    eor \dst, \dst,  \src2
    eor \dst, \dst,  \src3
    eor \dst, \dst,  \src4
.endm



.macro addparity prty, dst0, src0, dst1, src1, dst2, src2, dst3, src3, dst4, src4
    eor \dst0, \src0, \prty
    eor \dst1, \src1, \prty
    eor \dst2, \src2, \prty
    eor \dst3, \src3, \prty
    eor \dst4, \src4, \prty
.endm




.macro keccak_f1600_round_initial
    eor5 C0, Ama, Asa, Aba, Aga, Aka
    eor5 C1, Ame, Ase, Abe, Age, Ake
    eor5 C2, Ami, Asi, Abi, Agi, Aki
    eor5 C3, Amo, Aso, Abo, Ago, Ako
    eor5 C4, Amu, Asu, Abu, Agu, Aku

    eor E1, C0, C2, ror #63
    eor E3, C2, C4, ror #63
    eor E0, C4, C1, ror #63
    eor E2, C1, C3, ror #63
    eor E4, C3, C0, ror #63

    eor Aba_, Aba, E0
    eor Asa_, Abi, E2
    eor Abi_, Aki, E2
    eor Aki_, Ako, E3
    eor Ako_, Amu, E4
    eor Amu_, Aso, E3
    eor Aso_, Ama, E0
    eor Aka_, Abe, E1
    eor Ase_, Ago, E3
    eor Ago_, Ame, E1
    eor Ake_, Agi, E2
    eor Agi_, Aka, E0
    eor Aga_, Abo, E3
    eor Abo_, Amo, E3
    eor Amo_, Ami, E2
    eor Ami_, Ake, E1
    eor Age_, Agu, E4
    eor Agu_, Asi, E2
    eor Asi_, Aku, E4
    eor Aku_, Asa, E0
    eor Ama_, Abu, E4
    eor Abu_, Asu, E4
    eor Asu_, Ase, E1
    eor Ame_, Aga, E0
    eor Abe_, Age, E1

    load_constant_ptr

    bic tmp0, Agi_, Age_, ror #47
    bic tmp1, Ago_, Agi_, ror #42
    eor Aga, tmp0,  Aga_, ror #39
    bic tmp0, Agu_, Ago_, ror #16
    eor Age, tmp1,  Age_, ror #25
    bic tmp1, Aga_, Agu_, ror #31
    eor Agi, tmp0,  Agi_, ror #58
    bic tmp0, Age_, Aga_, ror #56
    eor Ago, tmp1,  Ago_, ror #47
    bic tmp1, Aki_, Ake_, ror #19
    eor Agu, tmp0,  Agu_, ror #23
    bic tmp0, Ako_, Aki_, ror #47
    eor Aka, tmp1,  Aka_, ror #24
    bic tmp1, Aku_, Ako_, ror #10
    eor Ake, tmp0,  Ake_, ror #2
    bic tmp0, Aka_, Aku_, ror #47
    eor Aki, tmp1,  Aki_, ror #57
    bic tmp1, Ake_, Aka_, ror #5
    eor Ako, tmp0,  Ako_, ror #57
    bic tmp0, Ami_, Ame_, ror #38
    eor Aku, tmp1,  Aku_, ror #52
    bic tmp1, Amo_, Ami_, ror #5
    eor Ama, tmp0,  Ama_, ror #47
    bic tmp0, Amu_, Amo_, ror #41
    eor Ame, tmp1,  Ame_, ror #43
    bic tmp1, Ama_, Amu_, ror #35
    eor Ami, tmp0,  Ami_, ror #46
    bic tmp0, Ame_, Ama_, ror #9

    str const_addr, [sp, #(STACK_OFFSET_CONST)]
    ldr cur_const, [const_addr]

    eor Amo, tmp1,  Amo_, ror #12
    bic tmp1, Asi_, Ase_, ror #48
    eor Amu, tmp0,  Amu_, ror #44
    bic tmp0, Aso_, Asi_, ror #2
    eor Asa, tmp1,  Asa_, ror #41
    bic tmp1, Asu_, Aso_, ror #25
    eor Ase, tmp0,  Ase_, ror #50
    bic tmp0, Asa_, Asu_, ror #60
    eor Asi, tmp1,  Asi_, ror #27
    bic tmp1, Ase_, Asa_, ror #57
    eor Aso, tmp0,  Aso_, ror #21

    mov count, #1

    bic tmp0, Abi_, Abe_, ror #63
    eor Asu, tmp1,  Asu_, ror #53
    bic tmp1, Abo_, Abi_, ror #42
    eor Aba, Aba_, tmp0,  ror #21
    bic tmp0, Abu_, Abo_, ror #57
    eor Abe, tmp1,  Abe_, ror #41
    bic tmp1, Aba_, Abu_, ror #50
    eor Abi, tmp0,  Abi_, ror #35
    bic tmp0, Abe_, Aba_, ror #44
    eor Abo, tmp1,  Abo_, ror #43
    eor Abu, tmp0,  Abu_, ror #30

    eor Aba, Aba, cur_const
    str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

.endm

.macro eor5ror dst, src0, src1, rot1, src2, rot2, src3, rot3, src4, rot4
    eor \dst, \src0, \src1, ror \rot1
    eor \dst, \dst,  \src2, ror \rot2
    eor \dst, \dst,  \src3, ror \rot3
    eor \dst, \dst,  \src4, ror \rot4
.endm

.macro addparityror prty, dst0, src0, rot0, dst1, src1, rot1, dst2, src2, rot2, dst3, src3, rot3, dst4, src4, rot4
    eor \dst0, \prty, \src0, ror \rot0
    eor \dst1, \prty, \src1, ror \rot1
    eor \dst2, \prty, \src2, ror \rot2
    eor \dst3, \prty, \src3, ror \rot3
    eor \dst4, \prty, \src4, ror \rot4
.endm

.macro  chi_step_ror out, a, b, c, r1, r2
    bic X<tmp>, \c\(), \b\(), ror #\r1
    eor \out\(), X<tmp>, \a\(), ror #\r2
.endm

.macro keccak_f1600_round_noninitial

    eor X<C0>, Aba, Aga, ror #61
    eor X<C0>, X<C0>, Ama, ror #54
    eor X<C0>, X<C0>, Aka, ror #39
    eor X<C0>, X<C0>, Asa, ror #25
    eor X<C1>, Ake, Ame, ror #57
    eor X<C1>, X<C1>, Abe, ror #51
    eor X<C1>, X<C1>, Ase, ror #31
    eor X<C1>, X<C1>, Age, ror #27
    eor X<C2>, Asi, Abi, ror #52
    eor X<C2>, X<C2>, Aki, ror #48
    eor X<C2>, X<C2>, Ami, ror #10
    eor X<C2>, X<C2>, Agi, ror #5
    eor X<C3>, Abo, Ako, ror #63
    eor X<C3>, X<C3>, Amo, ror #37
    eor X<C3>, X<C3>, Ago, ror #36
    eor X<C3>, X<C3>, Aso, ror #2
    eor X<C4>, Aku, Agu, ror #50
    eor X<C4>, X<C4>, Amu, ror #34
    eor X<C4>, X<C4>, Abu, ror #26
    eor X<C4>, X<C4>, Asu, ror #15

    eor X<E1>, X<C0>, X<C2>, ror #61
    ror X<C2>, X<C2>, #62
    eor X<E3>, X<C2>, X<C4>, ror #57
    ror X<C4>, X<C4>, #58
    eor X<E0>, X<C4>, X<C1>, ror #55
    ror X<C1>, X<C1>, #56
    eor X<E2>, X<C1>, X<C3>, ror #63
    eor X<E4>, X<C3>, X<C0>, ror #63

    str Age, [sp, #16] // @slothy:writes=Age
    str Aga, [sp, #24] // @slothy:writes=Aga
    ldr Aga, [sp, #24] // @slothy:reads=Aga
    ldr Age, [sp, #16] // @slothy:reads=Age

    eor Aba_, X<E0>, Aba
    eor Asa_, X<E2>, Abi, ror #50
    eor Abi_, X<E2>, Aki, ror #46
    eor Aki_, X<E3>, Ako, ror #63
    eor Ako_, X<E4>, Amu, ror #28
    eor Amu_, X<E3>, Aso, ror #2
    eor Aso_, X<E0>, Ama, ror #54
    eor Aka_, X<E1>, Abe, ror #43
    eor Ase_, X<E3>, Ago, ror #36
    eor Ago_, X<E1>, Ame, ror #49
    eor Ake_, X<E2>, Agi, ror #3
    eor Agi_, X<E0>, Aka, ror #39
    eor Aga_, X<E3>, Abo
    eor Abo_, X<E3>, Amo, ror #37
    eor Amo_, X<E2>, Ami, ror #8
    eor Ami_, X<E1>, Ake, ror #56
    eor Age_, X<E4>, Agu, ror #44
    eor Agu_, X<E2>, Asi, ror #62
    eor Asi_, X<E4>, Aku, ror #58
    eor Aku_, X<E0>, Asa, ror #25
    eor Ama_, X<E4>, Abu, ror #20
    eor Abu_, X<E4>, Asu, ror #9
    eor Asu_, X<E1>, Ase, ror #23
    eor Ame_, X<E0>, Aga, ror #61
    eor Abe_, X<E1>, Age, ror #19

    load_constant_ptr_stack
    ldr count, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT
    ldr cur_const, [const_addr, count, UXTW #3]
    add count, count, #1
    str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT

    chi_step_ror Aga, Aga_, Agi_, Age_, 47, 39
    chi_step_ror Age, Age_, Ago_, Agi_, 42, 25
    chi_step_ror Agi, Agi_, Agu_, Ago_, 16, 58
    chi_step_ror Ago, Ago_, Aga_, Agu_, 31, 47
    chi_step_ror Agu, Agu_, Age_, Aga_, 56, 23
    chi_step_ror Aka, Aka_, Aki_, Ake_, 19, 24
    chi_step_ror Ake, Ake_, Ako_, Aki_, 47, 2
    chi_step_ror Aki, Aki_, Aku_, Ako_, 10, 57
    chi_step_ror Ako, Ako_, Aka_, Aku_, 47, 57
    chi_step_ror Aku, Aku_, Ake_, Aka_, 5,  52
    chi_step_ror Ama, Ama_, Ami_, Ame_, 38, 47
    chi_step_ror Ame, Ame_, Amo_, Ami_, 5,  43
    chi_step_ror Ami, Ami_, Amu_, Amo_, 41, 46
    chi_step_ror Amo, Amo_, Ama_, Amu_, 35, 12
    chi_step_ror Amu, Amu_, Ame_, Ama_, 9,  44
    chi_step_ror Asa, Asa_, Asi_, Ase_, 48, 41
    chi_step_ror Ase, Ase_, Aso_, Asi_, 2,  50
    chi_step_ror Asi, Asi_, Asu_, Aso_, 25, 27
    chi_step_ror Aso, Aso_, Asa_, Asu_, 60, 21
    chi_step_ror Asu, Asu_, Ase_, Asa_, 57, 53
    chi_step_ror Aba, Aba_, Abi_, Abe_, 63, 21
    chi_step_ror Abe, Abe_, Abo_, Abi_, 42, 41
    chi_step_ror Abi, Abi_, Abu_, Abo_, 57, 35
    chi_step_ror Abo, Abo_, Aba_, Abu_, 50, 43
    chi_step_ror Abu, Abu_, Abe_, Aba_, 44, 30

    eor Aba, Aba, cur_const
.endm

.macro load_state
    ldp Aba, Abe, [input_addr, #(1*8*0)]
    ldp Abi, Abo, [input_addr, #(1*8*2)]
    ldp Abu, Aga, [input_addr, #(1*8*4)]
    ldp Age, Agi, [input_addr, #(1*8*6)]
    ldp Ago, Agu, [input_addr, #(1*8*8)]
    ldp Aka, Ake, [input_addr, #(1*8*10)]
    ldp Aki, Ako, [input_addr, #(1*8*12)]
    ldp Aku, Ama, [input_addr, #(1*8*14)]
    ldp Ame, Ami, [input_addr, #(1*8*16)]
    ldp Amo, Amu, [input_addr, #(1*8*18)]
    ldp Asa, Ase, [input_addr, #(1*8*20)]
    ldp Asi, Aso, [input_addr, #(1*8*22)]
    ldr Asu,      [input_addr, #(1*8*24)]
.endm

.macro store_state
    stp Aba, Abe, [input_addr, #(1*8*0)]
    stp Abi, Abo, [input_addr, #(1*8*2)]
    stp Abu, Aga, [input_addr, #(1*8*4)]
    stp Age, Agi, [input_addr, #(1*8*6)]
    stp Ago, Agu, [input_addr, #(1*8*8)]
    stp Aka, Ake, [input_addr, #(1*8*10)]
    stp Aki, Ako, [input_addr, #(1*8*12)]
    stp Aku, Ama, [input_addr, #(1*8*14)]
    stp Ame, Ami, [input_addr, #(1*8*16)]
    stp Amo, Amu, [input_addr, #(1*8*18)]
    stp Asa, Ase, [input_addr, #(1*8*20)]
    stp Asi, Aso, [input_addr, #(1*8*22)]
    str Asu,      [input_addr, #(1*8*24)]
.endm

.macro final_rotate
    ror Abe, Abe,#(64-21)
    ror Abi, Abi,#(64-14)
    ror Abu, Abu,#(64-44)
    ror Aga, Aga,#(64-3)
    ror Age, Age,#(64-45)
    ror Agi, Agi,#(64-61)
    ror Ago, Ago,#(64-28)
    ror Agu, Agu,#(64-20)
    ror Aka, Aka,#(64-25)
    ror Ake, Ake,#(64-8)
    ror Aki, Aki,#(64-18)
    ror Ako, Ako,#(64-1)
    ror Aku, Aku,#(64-6)
    ror Ama, Ama,#(64-10)
    ror Ame, Ame,#(64-15)
    ror Ami, Ami,#(64-56)
    ror Amo, Amo,#(64-27)
    ror Amu, Amu,#(64-36)
    ror Asa, Asa,#(64-39)
    ror Ase, Ase,#(64-41)
    ror Asi, Asi,#(64-2)
    ror Aso, Aso,#(64-62)
    ror Asu, Asu,#(64-55)
.endm

#define KECCAK_F1600_ROUNDS 24

.text
.balign 16
.global keccak_f1600_x1_scalar_slothy_opt_a55
.global _keccak_f1600_x1_scalar_slothy_opt_a55

.macro load_constant_ptr_stack
    ldr const_addr, [sp, #(STACK_OFFSET_CONST)]
.endm
keccak_f1600_x1_scalar_slothy_opt_a55:
_keccak_f1600_x1_scalar_slothy_opt_a55:
    alloc_stack
    save_gprs

initial:
    load_state
    str input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:writes=STACK_OFFSET_INPUT
    keccak_f1600_round_initial
        loop:
                                                  // Instructions:    113
                                                  // Expected cycles: 57
                                                  // Expected IPC:    1.98
                                                  //
                                                  // Cycle bound:     57.0
                                                  // IPC bound:       1.98
                                                  //
                                                  // Wall time:     15.98s
                                                  // User time:     15.98s
                                                  //
                                                  // ------------------- cycle (expected) ------------------->
                                                  // 0                        25                       50
                                                  // |------------------------|------------------------|------
        eor x27, x1, x2, ror #61                  // *........................................................
        eor x28, x27, x4, ror #54                 // *........................................................
        eor x28, x28, x3, ror #39                 // .*.......................................................
        eor x0, x28, x5, ror #25                  // .*.......................................................
        eor x28, x8, x9, ror #57                  // ..*......................................................
        eor x26, x28, x6, ror #51                 // ...*.....................................................
        eor x28, x26, x10, ror #31                // ...*.....................................................
        eor x28, x28, x7, ror #27                 // ....*....................................................
        eor x26, x15, x11, ror #52                // ....*....................................................
        eor x26, x26, x13, ror #48                // .....*...................................................
        eor x26, x26, x14, ror #10                // .....*...................................................
        eor x30, x26, x12, ror #5                 // ......*..................................................
        eor x26, x16, x18, ror #63                // ......*..................................................
        eor x26, x26, x19, ror #37                // .......*.................................................
        eor x26, x26, x17, ror #36                // .......*.................................................
        eor x29, x26, x20, ror #2                 // ........*................................................
        eor x26, x23, x22, ror #50                // ........*................................................
        eor x26, x26, x24, ror #34                // .........*...............................................
        eor x26, x26, x21, ror #26                // .........*...............................................
        eor x27, x26, x25, ror #15                // ..........*..............................................
        eor x26, x0, x30, ror #61                 // ..........*..............................................
        ror x30, x30, #62                         // ...........*.............................................
        eor x30, x30, x27, ror #57                // ...........*.............................................
        ror x27, x27, #58                         // ............*............................................
        eor x27, x27, x28, ror #55                // ............*............................................
        ror x28, x28, #56                         // .............*...........................................
        eor x28, x28, x29, ror #63                // .............*...........................................
        eor x0, x29, x0, ror #63                  // ..............*..........................................
        str x7, [sp, #16]                         // ..............*.......................................... // @slothy:writes=Age
        str x2, [sp, #24]                         // ...............*......................................... // @slothy:writes=Aga
        ldr x2, [sp, #24]                         // ...............*......................................... // @slothy:reads=Aga
        ldr x7, [sp, #16]                         // ................*........................................ // @slothy:reads=Age
        eor x1, x27, x1                           // ................*........................................
        eor x11, x28, x11, ror #50                // .................*.......................................
        eor x29, x28, x13, ror #46                // .................*.......................................
        eor x13, x30, x18, ror #63                // ..................*......................................
        eor x18, x0, x24, ror #28                 // ..................*......................................
        eor x24, x30, x20, ror #2                 // ...................*.....................................
        eor x20, x27, x4, ror #54                 // ...................*.....................................
        eor x4, x26, x6, ror #43                  // ....................*....................................
        eor x6, x30, x17, ror #36                 // ....................*....................................
        eor x17, x26, x9, ror #49                 // .....................*...................................
        eor x9, x28, x12, ror #3                  // .....................*...................................
        eor x12, x27, x3, ror #39                 // ......................*..................................
        eor x3, x30, x16                          // ......................*..................................
        eor x16, x30, x19, ror #37                // .......................*.................................
        eor x19, x28, x14, ror #8                 // .......................*.................................
        eor x14, x26, x8, ror #56                 // ........................*................................
        eor x8, x0, x22, ror #44                  // ........................*................................
        eor x28, x28, x15, ror #62                // .........................*...............................
        eor x15, x0, x23, ror #58                 // .........................*...............................
        eor x23, x27, x5, ror #25                 // ..........................*..............................
        eor x21, x0, x21, ror #20                 // ..........................*..............................
        eor x30, x0, x25, ror #9                  // ...........................*.............................
        eor x25, x26, x10, ror #23                // ...........................*.............................
        eor x10, x27, x2, ror #61                 // ............................*............................
        eor x26, x26, x7, ror #19                 // ............................*............................
        ldr x7, [sp, #STACK_OFFSET_CONST]         // .............................*...........................
        ldr w5, [sp, #STACK_OFFSET_COUNT]         // .............................*........................... // @slothy:reads=STACK_OFFSET_COUNT
        ldr x0, [x7, w5, UXTW #3]                 // ..............................*..........................
        add w27, w5, #1                           // ..............................*..........................
        str w27, [sp, #STACK_OFFSET_COUNT]        // ...............................*......................... // @slothy:writes=STACK_OFFSET_COUNT
        bic x5, x8, x12, ror #47                  // ...............................*.........................
        eor x2, x5, x3, ror #39                   // ................................*........................
        bic x5, x12, x17, ror #42                 // ................................*........................
        eor x7, x5, x8, ror #25                   // .................................*.......................
        bic x5, x17, x28, ror #16                 // .................................*.......................
        eor x12, x5, x12, ror #58                 // ..................................*......................
        bic x5, x28, x3, ror #31                  // ..................................*......................
        eor x17, x5, x17, ror #47                 // ...................................*.....................
        bic x5, x3, x8, ror #56                   // ...................................*.....................
        eor x22, x5, x28, ror #23                 // ....................................*....................
        bic x28, x9, x13, ror #19                 // ....................................*....................
        eor x3, x28, x4, ror #24                  // .....................................*...................
        bic x5, x13, x18, ror #47                 // .....................................*...................
        eor x8, x5, x9, ror #2                    // ......................................*..................
        bic x5, x18, x23, ror #10                 // ......................................*..................
        eor x13, x5, x13, ror #57                 // .......................................*.................
        bic x5, x23, x4, ror #47                  // .......................................*.................
        eor x18, x5, x18, ror #57                 // ........................................*................
        bic x5, x4, x9, ror #5                    // ........................................*................
        eor x23, x5, x23, ror #52                 // .........................................*...............
        bic x5, x10, x14, ror #38                 // .........................................*...............
        eor x4, x5, x21, ror #47                  // ..........................................*..............
        bic x5, x14, x19, ror #5                  // ..........................................*..............
        eor x9, x5, x10, ror #43                  // ...........................................*.............
        bic x5, x19, x24, ror #41                 // ...........................................*.............
        eor x14, x5, x14, ror #46                 // ............................................*............
        bic x5, x24, x21, ror #35                 // ............................................*............
        eor x19, x5, x19, ror #12                 // .............................................*...........
        bic x5, x21, x10, ror #9                  // .............................................*...........
        eor x24, x5, x24, ror #44                 // ..............................................*..........
        bic x5, x6, x15, ror #48                  // ..............................................*..........
        eor x5, x5, x11, ror #41                  // ...............................................*.........
        bic x28, x15, x20, ror #2                 // ...............................................*.........
        eor x10, x28, x6, ror #50                 // ................................................*........
        bic x28, x20, x25, ror #25                // ................................................*........
        eor x15, x28, x15, ror #27                // .................................................*.......
        bic x28, x25, x11, ror #60                // .................................................*.......
        eor x20, x28, x20, ror #21                // ..................................................*......
        bic x28, x11, x6, ror #57                 // ..................................................*......
        eor x25, x28, x25, ror #53                // ...................................................*.....
        bic x28, x26, x29, ror #63                // ...................................................*.....
        eor x21, x28, x1, ror #21                 // ....................................................*....
        bic x28, x29, x16, ror #42                // ....................................................*....
        eor x6, x28, x26, ror #41                 // .....................................................*...
        bic x11, x16, x30, ror #57                // .....................................................*...
        bic x28, x30, x1, ror #50                 // ......................................................*..
        eor x11, x11, x29, ror #35                // ......................................................*..
        eor x16, x28, x16, ror #43                // .......................................................*.
        bic x28, x1, x26, ror #44                 // .......................................................*.
        eor x1, x21, x0                           // ........................................................*
        eor x21, x28, x30, ror #30                // ........................................................*

                                                     // ------------------- cycle (expected) ------------------->
                                                     // 0                        25                       50
                                                     // |------------------------|------------------------|------
        // eor X<x30>, x1, x2, ror #61               // *........................................................
        // eor X<x30>, X<x30>, x4, ror #54           // *........................................................
        // eor X<x30>, X<x30>, x3, ror #39           // .*.......................................................
        // eor X<x30>, X<x30>, x5, ror #25           // .*.......................................................
        // eor X<x26>, x8, x9, ror #57               // ..*......................................................
        // eor X<x26>, X<x26>, x6, ror #51           // ...*.....................................................
        // eor X<x26>, X<x26>, x10, ror #31          // ...*.....................................................
        // eor X<x26>, X<x26>, x7, ror #27           // ....*....................................................
        // eor X<x27>, x15, x11, ror #52             // ....*....................................................
        // eor X<x27>, X<x27>, x13, ror #48          // .....*...................................................
        // eor X<x27>, X<x27>, x14, ror #10          // .....*...................................................
        // eor X<x27>, X<x27>, x12, ror #5           // ......*..................................................
        // eor X<x28>, x16, x18, ror #63             // ......*..................................................
        // eor X<x28>, X<x28>, x19, ror #37          // .......*.................................................
        // eor X<x28>, X<x28>, x17, ror #36          // .......*.................................................
        // eor X<x28>, X<x28>, x20, ror #2           // ........*................................................
        // eor X<x29>, x23, x22, ror #50             // ........*................................................
        // eor X<x29>, X<x29>, x24, ror #34          // .........*...............................................
        // eor X<x29>, X<x29>, x21, ror #26          // .........*...............................................
        // eor X<x29>, X<x29>, x25, ror #15          // ..........*..............................................
        // eor X<x0>, X<x30>, X<x27>, ror #61        // ..........*..............................................
        // ror X<x27>, X<x27>, #62                   // ...........*.............................................
        // eor X<x27>, X<x27>, X<x29>, ror #57       // ...........*.............................................
        // ror X<x29>, X<x29>, #58                   // ............*............................................
        // eor X<x29>, X<x29>, X<x26>, ror #55       // ............*............................................
        // ror X<x26>, X<x26>, #56                   // .............*...........................................
        // eor X<x26>, X<x26>, X<x28>, ror #63       // .............*...........................................
        // eor X<x28>, X<x28>, X<x30>, ror #63       // ..............*..........................................
        // str x7, [sp, #16]                         // ..............*..........................................
        // str x2, [sp, #24]                         // ...............*.........................................
        // ldr x2, [sp, #24]                         // ...............*.........................................
        // ldr x7, [sp, #16]                         // ................*........................................
        // eor x30, X<x29>, x1                       // ................*........................................
        // eor x1, X<x26>, x11, ror #50              // .................*.......................................
        // eor x11, X<x26>, x13, ror #46             // .................*.......................................
        // eor x13, X<x27>, x18, ror #63             // ..................*......................................
        // eor x18, X<x28>, x24, ror #28             // ..................*......................................
        // eor x24, X<x27>, x20, ror #2              // ...................*.....................................
        // eor x20, X<x29>, x4, ror #54              // ...................*.....................................
        // eor x4, X<x0>, x6, ror #43                // ....................*....................................
        // eor x6, X<x27>, x17, ror #36              // ....................*....................................
        // eor x17, X<x0>, x9, ror #49               // .....................*...................................
        // eor x9, X<x26>, x12, ror #3               // .....................*...................................
        // eor x12, X<x29>, x3, ror #39              // ......................*..................................
        // eor x3, X<x27>, x16                       // ......................*..................................
        // eor x16, X<x27>, x19, ror #37             // .......................*.................................
        // eor x19, X<x26>, x14, ror #8              // .......................*.................................
        // eor x14, X<x0>, x8, ror #56               // ........................*................................
        // eor x8, X<x28>, x22, ror #44              // ........................*................................
        // eor x22, X<x26>, x15, ror #62             // .........................*...............................
        // eor x15, X<x28>, x23, ror #58             // .........................*...............................
        // eor x23, X<x29>, x5, ror #25              // ..........................*..............................
        // eor x5, X<x28>, x21, ror #20              // ..........................*..............................
        // eor x21, X<x28>, x25, ror #9              // ...........................*.............................
        // eor x25, X<x0>, x10, ror #23              // ...........................*.............................
        // eor x10, X<x29>, x2, ror #61              // ............................*............................
        // eor x28, X<x0>, x7, ror #19               // ............................*............................
        // ldr x26, [sp, #(STACK_OFFSET_CONST)]      // .............................*...........................
        // ldr w27, [sp, #STACK_OFFSET_COUNT]        // .............................*...........................
        // ldr x26, [x26, w27, UXTW #3]              // ..............................*..........................
        // add w27, w27, #1                          // ..............................*..........................
        // str w27, [sp, #STACK_OFFSET_COUNT]        // ...............................*.........................
        // bic X<x0>, x8, x12, ror #47               // ...............................*.........................
        // eor x2, X<x0>, x3, ror #39                // ................................*........................
        // bic X<x0>, x12, x17, ror #42              // ................................*........................
        // eor x7, X<x0>, x8, ror #25                // .................................*.......................
        // bic X<x0>, x17, x22, ror #16              // .................................*.......................
        // eor x12, X<x0>, x12, ror #58              // ..................................*......................
        // bic X<x0>, x22, x3, ror #31               // ..................................*......................
        // eor x17, X<x0>, x17, ror #47              // ...................................*.....................
        // bic X<x0>, x3, x8, ror #56                // ...................................*.....................
        // eor x22, X<x0>, x22, ror #23              // ....................................*....................
        // bic X<x0>, x9, x13, ror #19               // ....................................*....................
        // eor x3, X<x0>, x4, ror #24                // .....................................*...................
        // bic X<x0>, x13, x18, ror #47              // .....................................*...................
        // eor x8, X<x0>, x9, ror #2                 // ......................................*..................
        // bic X<x0>, x18, x23, ror #10              // ......................................*..................
        // eor x13, X<x0>, x13, ror #57              // .......................................*.................
        // bic X<x0>, x23, x4, ror #47               // .......................................*.................
        // eor x18, X<x0>, x18, ror #57              // ........................................*................
        // bic X<x0>, x4, x9, ror #5                 // ........................................*................
        // eor x23, X<x0>, x23, ror #52              // .........................................*...............
        // bic X<x0>, x10, x14, ror #38              // .........................................*...............
        // eor x4, X<x0>, x5, ror #47                // ..........................................*..............
        // bic X<x0>, x14, x19, ror #5               // ..........................................*..............
        // eor x9, X<x0>, x10, ror #43               // ...........................................*.............
        // bic X<x0>, x19, x24, ror #41              // ...........................................*.............
        // eor x14, X<x0>, x14, ror #46              // ............................................*............
        // bic X<x0>, x24, x5, ror #35               // ............................................*............
        // eor x19, X<x0>, x19, ror #12              // .............................................*...........
        // bic X<x0>, x5, x10, ror #9                // .............................................*...........
        // eor x24, X<x0>, x24, ror #44              // ..............................................*..........
        // bic X<x0>, x6, x15, ror #48               // ..............................................*..........
        // eor x5, X<x0>, x1, ror #41                // ...............................................*.........
        // bic X<x0>, x15, x20, ror #2               // ...............................................*.........
        // eor x10, X<x0>, x6, ror #50               // ................................................*........
        // bic X<x0>, x20, x25, ror #25              // ................................................*........
        // eor x15, X<x0>, x15, ror #27              // .................................................*.......
        // bic X<x0>, x25, x1, ror #60               // .................................................*.......
        // eor x20, X<x0>, x20, ror #21              // ..................................................*......
        // bic X<x0>, x1, x6, ror #57                // ..................................................*......
        // eor x25, X<x0>, x25, ror #53              // ...................................................*.....
        // bic X<x0>, x28, x11, ror #63              // ...................................................*.....
        // eor x1, X<x0>, x30, ror #21               // ....................................................*....
        // bic X<x0>, x11, x16, ror #42              // ....................................................*....
        // eor x6, X<x0>, x28, ror #41               // .....................................................*...
        // bic X<x0>, x16, x21, ror #57              // .....................................................*...
        // eor x11, X<x0>, x11, ror #35              // ......................................................*..
        // bic X<x0>, x21, x30, ror #50              // ......................................................*..
        // eor x16, X<x0>, x16, ror #43              // .......................................................*.
        // bic X<x0>, x30, x28, ror #44              // .......................................................*.
        // eor x21, X<x0>, x21, ror #30              // ........................................................*
        // eor x1, x1, x26                           // ........................................................*

        end_loop:

    cmp count, #(KECCAK_F1600_ROUNDS-1)
    ble loop
final:
    final_rotate
    ldr input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:reads=STACK_OFFSET_INPUT
    store_state
end_final:
    restore_gprs
    free_stack
    ret
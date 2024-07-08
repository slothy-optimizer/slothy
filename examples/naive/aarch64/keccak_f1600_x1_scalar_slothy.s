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

//
// Author: Hanno Becker <hanno.becker@arm.com>
// Author: Matthias Kannwischer <matthias@kannwischer.eu>
//

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

.macro keccak_f1600_round_noninitial
    eor5ror C0, Aba, Aga, #61, Ama, #54, Aka, #39, Asa, #25
    eor5ror C1, Ake, Ame, #57, Abe, #51, Ase, #31, Age, #27
    eor5ror C2, Asi, Abi, #52, Aki, #48, Ami, #10, Agi, #5
    eor5ror C3, Abo, Ako, #63, Amo, #37, Ago, #36, Aso, #2
    eor5ror C4, Aku, Agu, #50, Amu, #34, Abu, #26, Asu, #15

    eor E1, C0, C2, ror #61
    ror C2, C2, #62
    eor E3, C2, C4, ror #57
    ror C4, C4, #58
    eor E0, C4, C1, ror #55
    ror C1, C1, #56
    eor E2, C1, C3, ror #63
    eor E4, C3, C0, ror #63

    addparityror E0, X<Bba>, Aba, #0,  X<Bso>, Ama, #54, X<Bgi>, Aka, #39, X<Bku>, Asa, #25, X<Bme>, Aga, #61
    addparityror E1, X<Bka>, Abe, #43, X<Bgo>, Ame, #49, X<Bmi>, Ake, #56, X<Bsu>, Ase, #23, X<Bbe>, Age, #19
    addparityror E2, X<Bsa>, Abi, #50, X<Bbi>, Aki, #46, X<Bke>, Agi, #3,  X<Bmo>, Ami, #8,  X<Bgu>, Asi, #62
    addparityror E3, X<Bki>, Ako, #63, X<Bmu>, Aso, #2,  X<Bse>, Ago, #36, X<Bga>, Abo, #0,  X<Bbo>, Amo, #37
    addparityror E4, X<Bko>, Amu, #28, X<Bge>, Agu, #44, X<Bsi>, Aku, #58, X<Bma>, Abu, #20, X<Bbu>, Asu, #9

    load_constant_ptr_stack
    ldr count, [sp, #STACK_OFFSET_COUNT] // @slothy:reads=STACK_OFFSET_COUNT

    bic tmp0, X<Bgi>, X<Bge>, ror #47
    bic tmp1, X<Bgo>, X<Bgi>, ror #42
    eor Aga, tmp0,  X<Bga>, ror #39
    bic tmp0, X<Bgu>, X<Bgo>, ror #16
    eor Age, tmp1,  X<Bge>, ror #25
    bic tmp1, X<Bga>, X<Bgu>, ror #31
    eor Agi, tmp0,  X<Bgi>, ror #58
    bic tmp0, X<Bge>, X<Bga>, ror #56
    eor Ago, tmp1,  X<Bgo>, ror #47
    bic tmp1, X<Bki>, X<Bke>, ror #19
    eor Agu, tmp0,  X<Bgu>, ror #23
    bic tmp0, X<Bko>, X<Bki>, ror #47
    eor Aka, tmp1,  X<Bka>, ror #24
    bic tmp1, X<Bku>, X<Bko>, ror #10
    eor Ake, tmp0,  X<Bke>, ror #2
    bic tmp0, X<Bka>, X<Bku>, ror #47
    eor Aki, tmp1,  X<Bki>, ror #57
    bic tmp1, X<Bke>, X<Bka>, ror #5
    eor Ako, tmp0,  X<Bko>, ror #57
    bic tmp0, X<Bmi>, X<Bme>, ror #38
    eor Aku, tmp1,  X<Bku>, ror #52
    bic tmp1, X<Bmo>, X<Bmi>, ror #5
    eor Ama, tmp0,  X<Bma>, ror #47
    bic tmp0, X<Bmu>, X<Bmo>, ror #41
    eor Ame, tmp1,  X<Bme>, ror #43
    bic tmp1, X<Bma>, X<Bmu>, ror #35
    eor Ami, tmp0,  X<Bmi>, ror #46
    bic tmp0, X<Bme>, X<Bma>, ror #9

    ldr cur_const, [const_addr, count, UXTW #3]

    eor Amo, tmp1,  X<Bmo>, ror #12
    bic tmp1, X<Bsi>, X<Bse>, ror #48
    eor Amu, tmp0,  X<Bmu>, ror #44
    bic tmp0, X<Bso>, X<Bsi>, ror #2
    eor Asa, tmp1,  X<Bsa>, ror #41
    bic tmp1, X<Bsu>, X<Bso>, ror #25
    eor Ase, tmp0,  X<Bse>, ror #50
    bic tmp0, X<Bsa>, X<Bsu>, ror #60
    eor Asi, tmp1,  X<Bsi>, ror #27
    bic tmp1, X<Bse>, X<Bsa>, ror #57
    eor Aso, tmp0,  X<Bso>, ror #21
    bic tmp0, X<Bbi>, X<Bbe>, ror #63
    add count, count, #1
    str count, [sp, #STACK_OFFSET_COUNT] // @slothy:writes=STACK_OFFSET_COUNT
    eor Asu, tmp1,  X<Bsu>, ror #53
    bic tmp1, X<Bbo>, X<Bbi>, ror #42
    eor Aba, X<Bba>, tmp0,  ror #21
    bic tmp0, X<Bbu>, X<Bbo>, ror #57
    eor Abe, tmp1,  X<Bbe>, ror #41
    bic tmp1, X<Bba>, X<Bbu>, ror #50
    eor Abi, tmp0,  X<Bbi>, ror #35
    bic tmp0, X<Bbe>, X<Bba>, ror #44

    eor Abo, tmp1,  X<Bbo>, ror #43
    eor Abu, tmp0,  X<Bbu>, ror #30
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
.global keccak_f1600_x1_scalar_slothy
.global _keccak_f1600_x1_scalar_slothy

.macro load_constant_ptr_stack
    ldr const_addr, [sp, #(STACK_OFFSET_CONST)]
.endm
keccak_f1600_x1_scalar_slothy:
_keccak_f1600_x1_scalar_slothy:
    alloc_stack
    save_gprs

initial:
    load_state
    str input_addr, [sp, #STACK_OFFSET_INPUT] // @slothy:writes=STACK_OFFSET_INPUT
    keccak_f1600_round_initial
loop:
    keccak_f1600_round_noninitial
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

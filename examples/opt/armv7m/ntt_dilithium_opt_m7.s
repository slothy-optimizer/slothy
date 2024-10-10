// based on code by: Markus Krausz (18.03.18)
// date 23.07.21: Now licensed under CC0 with permission of the authors.

.syntax unified
// 3
.macro montgomery_mul_32 a, b, Qprime, Q, tmp, tmp2
    smull \tmp, \a, \a, \b
    mul \tmp2, \tmp, \Qprime
    smlal \tmp, \a, \tmp2, \Q
.endm

// 2
.macro addSub1 c0, c1
    add.w \c0, \c0, \c1
    sub.w \c1, \c0, \c1, lsl #1
.endm

// 3
.macro addSub2 c0, c1, c2, c3
    add \c0, \c0, \c1
    add \c2, \c2, \c3
    sub.w \c1, \c0, \c1, lsl #1
    sub.w \c3, \c2, \c3, lsl #1
.endm

// 6
.macro addSub4 c0, c1, c2, c3, c4, c5, c6, c7
    add \c0, \c0, \c1
    add \c2, \c2, \c3
    add \c4, \c4, \c5
    add \c6, \c6, \c7
    sub.w \c1, \c0, \c1, lsl #1
    sub.w \c3, \c2, \c3, lsl #1
    sub.w \c5, \c4, \c5, lsl #1
    sub.w \c7, \c6, \c7, lsl #1
.endm

.macro _2_layer_CT_32 c0, c1, c2, c3, zeta0, zeta1, zeta2, Qprime, Q, tmp, tmp2
    montgomery_mul_32 \c2, \zeta0, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \zeta0, \Qprime, \Q, \tmp, \tmp2
    addSub2 \c0, \c2, \c1, \c3

    montgomery_mul_32 \c1, \zeta1, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \zeta2, \Qprime, \Q, \tmp, \tmp2
    addSub2 \c0, \c1, \c2, \c3
.endm

.macro _2_layer_inv_CT_32 c0, c1, c2, c3, zeta0, zeta1, zeta2, Qprime, Q, tmp, tmp2
    montgomery_mul_32 \c1, \zeta0, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \zeta0, \Qprime, \Q, \tmp, \tmp2
    addSub2 \c0, \c1, \c2, \c3

    montgomery_mul_32 \c2, \zeta1, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \zeta2, \Qprime, \Q, \tmp, \tmp2
    addSub2 \c0, \c2, \c1, \c3
.endm

.macro _3_layer_CT_32 c0, c1, c2, c3, c4, c5, c6, c7, xi0, xi1, xi2, xi3, xi4, xi5, xi6, twiddle, Qprime, Q, tmp, tmp2
    vmov \twiddle, \xi0
    montgomery_mul_32 \c4, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c5, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c6, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c4, \c1, \c5, \c2, \c6, \c3, \c7

    vmov \twiddle, \xi1
    montgomery_mul_32 \c2, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi2
    montgomery_mul_32 \c6, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c2, \c1, \c3, \c4, \c6, \c5, \c7

    vmov \twiddle, \xi3
    montgomery_mul_32 \c1, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi4
    montgomery_mul_32 \c3, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi5
    montgomery_mul_32 \c5, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi6
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c1, \c2, \c3, \c4, \c5, \c6, \c7
.endm

.macro _3_layer_inv_CT_32 c0, c1, c2, c3, c4, c5, c6, c7, xi0, xi1, xi2, xi3, xi4, xi5, xi6, twiddle, Qprime, Q, tmp, tmp2
    vmov \twiddle, \xi0
    montgomery_mul_32 \c1, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c3, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c5, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c1, \c2, \c3, \c4, \c5, \c6, \c7

    vmov \twiddle, \xi1
    montgomery_mul_32 \c2, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c6, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi2
    montgomery_mul_32 \c3, \twiddle, \Qprime, \Q, \tmp, \tmp2
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c2, \c1, \c3, \c4, \c6, \c5, \c7

    vmov \twiddle, \xi3
    montgomery_mul_32 \c4, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi4
    montgomery_mul_32 \c5, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi5
    montgomery_mul_32 \c6, \twiddle, \Qprime, \Q, \tmp, \tmp2
    vmov \twiddle, \xi6
    montgomery_mul_32 \c7, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub4 \c0, \c4, \c1, \c5, \c2, \c6, \c3, \c7
.endm

/************************************************************
* Name:         _3_layer_inv_butterfly_light_fast_first
*
* Description:  upper half of 3-layer inverse butterfly
*               defined over X^8 - 1
*
* Input:        (c4, c1, c6, c3) = coefficients on the upper half;
*               (xi0, xi1, xi2, xi3, xi4, xi5, xi6) =
*               (  1,  1,  w_4,   1, w_8, w_4, w_8^3) in
*               Montgomery domain
*
* Symbols:      R = 2^32
*
* Constants:    Qprime = -MOD^{-1} mod^{+-} R, Q = MOD
*
* Output:
*               c4 =  c4 + c1        + (c6 + c3)
*               c5 = (c4 - c1) w_4   + (c6 + c3) w_8^3
*               c6 =  c4 + c1        - (c6 + c3)
*               c7 = (c4 - c1) w_8^3 + (c6 + c3) w_4
************************************************************/
// 15
.macro _3_layer_inv_butterfly_light_fast_first c0, c1, c2, c3, c4, c5, c6, c7, xi0, xi1, xi2, xi3, xi4, xi5, xi6, twiddle, Qprime, Q, tmp, tmp2
    addSub2 \c4, \c1, \c6, \c3
    addSub1 \c4, \c6

    vmov \tmp, \xi4
    vmov \tmp2, \xi6

    smull.w \c0, \c5, \c1, \tmp
    smlal.w \c0, \c5, \c3, \tmp2
    mul.w \twiddle, \c0, \Qprime
    smlal.w \c0, \c5, \twiddle, \Q

    smull.w \c2, \c7, \c1, \tmp2
    smlal.w \c2, \c7, \c3, \tmp
    mul.w \twiddle, \c2, \Qprime
    smlal.w \c2, \c7, \twiddle, \Q
.endm

/************************************************************
* Name:         _3_layer_inv_butterfly_light_fast_second
*
* Description:  lower half of 3-layer inverse butterfly
*               defined over X^8 - 1, and the 2nd
*               layer of butterflies
*
* Input:
*               (c4, c5, c6, c7) = results of the upper half;
*               (c0, c1, c2, c3) = coefficients on the lower half;
*               (xi0, xi1, xi2, xi3, xi4, xi5, xi6) =
*               (  1,  1,  w_4,   1, w_8, w_4, w_8^3) in
*               Montgomery domain
*
* Symbols:      R = 2^32
*
* Constants:    Qprime = -MOD^{-1} mod^{+-} R, Q = MOD
*
* Output:       (normal order)
*               c0 =   c0 + c1     + (c2 + c3)         + (  c4 + c5     + (c6 + c7)       )
*               c1 =  (c0 - c1) w3 + (c2 - c3)  w4     + ( (c4 - c5) w5 + (c6 - c7) w6    )
*               c2 = ( c0 + c1     - (c2 + c3)) w1     + (( c4 + c5     - (c6 + c7)   ) w2)
*               c3 = ((c0 - c1) w3 - (c2 - c3)  w4) w1 + (((c4 - c5) w5 - (c6 - c7) w6) w2)
*               c4 =   c0 + c1     - (c2 + c3)         - (  c4 + c5     + (c6 + c7)       ) w0
*               c5 =  (c0 - c1) w3 + (c2 - c3)  w4     - ( (c4 - c5) w5 + (c6 - c7) w6    ) w0
*               c6 = ( c0 + c1     - (c2 + c3)) w1     - (( c4 + c5     - (c6 + c7)   ) w2) w0
*               c7 = ((c0 - c1) w3 - (c2 - c3)  w4) w1 - (((c4 - c5) w5 - (c6 - c7) w6) w2) w0
************************************************************/
// 19
.macro _3_layer_inv_butterfly_light_fast_second c0, c1, c2, c3, c4, c5, c6, c7, xi0, xi1, xi2, xi3, xi4, xi5, xi6, twiddle, Qprime, Q, tmp, tmp2
    addSub2 \c0, \c1, \c2, \c3

    vmov \twiddle, \xi2
    montgomery_mul_32 \c3, \twiddle, \Qprime, \Q, \tmp, \tmp2
    addSub2 \c0, \c2, \c1, \c3

    montgomery_mul_32 \c6, \twiddle, \Qprime, \Q, \tmp, \tmp2

    addSub4 \c0, \c4, \c1, \c5, \c2, \c6, \c3, \c7
.endm

// This code uses UMULL - which is constant time on the M4, but not on the M3
// Make sure that this code is never used on an M3
smlad r0,r0,r0,r0

// ##############################
// ##########   NTT    ##########
// ##############################

// void pqcrystals_dilithium_ntt(int32_t p[N]);
.global pqcrystals_dilithium_ntt_opt_m7
#ifndef __CLANG__
.type pqcrystals_dilithium_ntt_opt_m7,%function
#endif
.align 2
pqcrystals_dilithium_ntt_opt_m7:
  // bind aliases
  ptr_p     .req R0
  ptr_zeta  .req R1
  zeta      .req R1
  qinv      .req R2
  q         .req R3
  cntr      .req R4
  pol4      .req R4
  pol0      .req R5
  pol1      .req R6
  pol2      .req R7
  pol3      .req R8
  temp_h    .req R9
  temp_l    .req R10
  zeta0     .req R11
  zeta1     .req R12
  zeta2     .req R14
  pol5     .req R11
  pol6     .req R12
  pol7     .req R14

  // preserve registers
  push {R4-R11, R14}

  // load constants, ptr
  ldr.w qinv, inv_ntt_asm_smull_qinv  // -qinv_signed
  ldr.w q, inv_ntt_asm_smull_q

  // stage 1 - 3
  .equ distance, 512
  .equ strincr, 4

  ldr ptr_zeta, =zetas_new332
  vldm ptr_zeta!, {s2-s8}
  vmov s0, ptr_zeta

  add.w temp_l, ptr_p, #32*strincr // 32 iterations
  vmov s9, temp_l
  1:
        layer123_start:
                                              // Instructions:    84
                                              // Expected cycles: 44
                                              // Expected IPC:    1.91
                                              //
                                              // Cycle bound:     43.0
                                              // IPC bound:       1.95
                                              //
                                              // Wall time:     300.33s
                                              // User time:     300.33s
                                              //
                                              // ------------ cycle (expected) ------------->
                                              // 0                        25
                                              // |------------------------|------------------
        ldr.w r9, [r0, #5*distance/4]         // *...........................................
        ldr.w r12, [r0, #7*distance/4]        // *...........................................
        vmov r1, s2                           // .*..........................................
        ldr.w r5, [r0, #6*distance/4]         // .*..........................................
        ldr.w r7, [r0, #3*distance/4]         // ..*.........................................
        smull r10, r8, r12, r1                // ..*.........................................
        smull r14, r5, r5, r1                 // ...*........................................
        ldr.w r4, [r0, #4*distance/4]         // ....*.......................................
        mul r6, r10, r2                       // ....*.......................................
        mul r12, r14, r2                      // .....*......................................
        vmov r11, s4                          // ......*.....................................
        smlal r10, r8, r6, r3                 // ......*.....................................
        smull r10, r6, r9, r1                 // .......*....................................
        ldr.w r9, [r0, #2*distance/4]         // .......*....................................
        add r7, r7, r8                        // ........*...................................
        smlal r14, r5, r12, r3                // ........*...................................
        mul r14, r10, r2                      // .........*..................................
        sub.w r12, r7, r8, lsl #1             // .........*..................................
        add r8, r9, r5                        // ..........*.................................
        smull r12, r9, r12, r11               // ..........*.................................
        sub.w r5, r8, r5, lsl #1              // ...........*................................
        smlal r10, r6, r14, r3                // ...........*................................
        mul r14, r12, r2                      // ............*...............................
        smull r10, r1, r4, r1                 // .............*..............................
        ldr.w r4, [r0, #1*distance/4]         // .............*..............................
        smlal r12, r9, r14, r3                // ..............*.............................
        add r12, r4, r6                       // ..............*.............................
        sub.w r14, r12, r6, lsl #1            // ...............*............................
        mul r4, r10, r2                       // ...............*............................
        smull r11, r6, r5, r11                // ................*...........................
        add r5, r14, r9                       // ................*...........................
        sub.w r9, r5, r9, lsl #1              // .................*..........................
        smlal r10, r1, r4, r3                 // .................*..........................
        vmov r4, s8                           // ..................*.........................
        mul r10, r11, r2                      // ..................*.........................
        smull r9, r4, r9, r4                  // ...................*........................
        ldr.w r14, [r0]                       // ...................*........................
        smlal r11, r6, r10, r3                // ....................*.......................
        vmov r11, s7                          // ....................*.......................
        mul r10, r9, r2                       // .....................*......................
        add r14, r14, r1                      // .....................*......................
        smull r11, r5, r5, r11                // ......................*.....................
        sub.w r1, r14, r1, lsl #1             // ......................*.....................
        smlal r9, r4, r10, r3                 // .......................*....................
        add r10, r1, r6                       // .......................*....................
        sub.w r9, r10, r6, lsl #1             // ........................*...................
        vmov r1, s3                           // ........................*...................
        add r9, r9, r4                        // .........................*..................
        smull r6, r7, r7, r1                  // .........................*..................
        str.w r9, [r0, #6*distance/4]         // ..........................*.................
        smull r1, r8, r8, r1                  // ..........................*.................
        sub.w r9, r9, r4, lsl #1              // ...........................*................
        mul r4, r6, r2                        // ...........................*................
        str.w r9, [r0, #7*distance/4]         // ............................*...............
        mul r9, r1, r2                        // ............................*...............
        smlal r6, r7, r4, r3                  // .............................*..............
        vmov r4, s5                           // .............................*..............
        smlal r1, r8, r9, r3                  // ..............................*.............
        mul r1, r11, r2                       // ...............................*............
        add r6, r12, r7                       // ...............................*............
        smull r4, r9, r6, r4                  // ................................*...........
        sub.w r12, r6, r7, lsl #1             // ................................*...........
        smlal r11, r5, r1, r3                 // .................................*..........
        vmov r1, s6                           // .................................*..........
        smull r12, r11, r12, r1               // ..................................*.........
        add r7, r14, r8                       // ..................................*.........
        add r1, r10, r5                       // ...................................*........
        mul r6, r4, r2                        // ...................................*........
        str.w r1, [r0, #4*distance/4]         // ....................................*.......
        mul r10, r12, r2                      // ....................................*.......
        smlal r4, r9, r6, r3                  // .....................................*......
        sub.w r4, r7, r8, lsl #1              // .....................................*......
        smlal r12, r11, r10, r3               // ......................................*.....
        sub.w r6, r1, r5, lsl #1              // ......................................*.....
        str.w r6, [r0, #5*distance/4]         // .......................................*....
        add r14, r7, r9                       // .......................................*....
        sub.w r12, r14, r9, lsl #1            // ........................................*...
        str.w r12, [r0, #1*distance/4]        // ........................................*...
        add r6, r4, r11                       // .........................................*..
        str.w r6, [r0, #2*distance/4]         // .........................................*..
        sub.w r7, r6, r11, lsl #1             // ..........................................*.
        str.w r7, [r0, #3*distance/4]         // ..........................................*.
        str r14, [r0], #strincr               // ...........................................*
        vmov r10, s9                          // ...........................................*

                                               // ------------ cycle (expected) ------------->
                                               // 0                        25
                                               // |------------------------|------------------
        // ldr.w R5, [R0]                      // ...................*........................
        // ldr.w R6, [R0, #1*distance/4]       // .............*..............................
        // ldr.w R7, [R0, #2*distance/4]       // .......*....................................
        // ldr.w R8, [R0, #3*distance/4]       // ..*.........................................
        // ldr.w R4, [R0, #4*distance/4]       // ....*.......................................
        // ldr.w R11, [R0, #5*distance/4]      // *...........................................
        // ldr.w R12, [R0, #6*distance/4]      // .*..........................................
        // ldr.w R14, [R0, #7*distance/4]      // *...........................................
        // vmov R1, s2                         // .*..........................................
        // smull R9, R4, R4, R1                // .............*..............................
        // mul R10, R9, R2                     // ...............*............................
        // smlal R9, R4, R10, R3               // .................*..........................
        // smull R9, R11, R11, R1              // .......*....................................
        // mul R10, R9, R2                     // .........*..................................
        // smlal R9, R11, R10, R3              // ...........*................................
        // smull R9, R12, R12, R1              // ...*........................................
        // mul R10, R9, R2                     // .....*......................................
        // smlal R9, R12, R10, R3              // ........*...................................
        // smull R9, R14, R14, R1              // ..*.........................................
        // mul R10, R9, R2                     // ....*.......................................
        // smlal R9, R14, R10, R3              // ......*.....................................
        // add R5, R5, R4                      // .....................*......................
        // add R6, R6, R11                     // ..............*.............................
        // add R7, R7, R12                     // ..........*.................................
        // add R8, R8, R14                     // ........*...................................
        // sub.w R4, R5, R4, lsl #1            // ......................*.....................
        // sub.w R11, R6, R11, lsl #1          // ...............*............................
        // sub.w R12, R7, R12, lsl #1          // ...........*................................
        // sub.w R14, R8, R14, lsl #1          // .........*..................................
        // vmov R1, s3                         // ........................*...................
        // smull R9, R7, R7, R1                // ..........................*.................
        // mul R10, R9, R2                     // ............................*...............
        // smlal R9, R7, R10, R3               // ..............................*.............
        // smull R9, R8, R8, R1                // .........................*..................
        // mul R10, R9, R2                     // ...........................*................
        // smlal R9, R8, R10, R3               // .............................*..............
        // vmov R1, s4                         // ......*.....................................
        // smull R9, R12, R12, R1              // ................*...........................
        // mul R10, R9, R2                     // ..................*.........................
        // smlal R9, R12, R10, R3              // ....................*.......................
        // smull R9, R14, R14, R1              // ..........*.................................
        // mul R10, R9, R2                     // ............*...............................
        // smlal R9, R14, R10, R3              // ..............*.............................
        // add R5, R5, R7                      // ..................................*.........
        // add R6, R6, R8                      // ...............................*............
        // add R4, R4, R12                     // .......................*....................
        // add R11, R11, R14                   // ................*...........................
        // sub.w R7, R5, R7, lsl #1            // .....................................*......
        // sub.w R8, R6, R8, lsl #1            // ................................*...........
        // sub.w R12, R4, R12, lsl #1          // ........................*...................
        // sub.w R14, R11, R14, lsl #1         // .................*..........................
        // vmov R1, s5                         // .............................*..............
        // smull R9, R6, R6, R1                // ................................*...........
        // mul R10, R9, R2                     // ...................................*........
        // smlal R9, R6, R10, R3               // .....................................*......
        // vmov R1, s6                         // .................................*..........
        // smull R9, R8, R8, R1                // ..................................*.........
        // mul R10, R9, R2                     // ....................................*.......
        // smlal R9, R8, R10, R3               // ......................................*.....
        // vmov R1, s7                         // ....................*.......................
        // smull R9, R11, R11, R1              // ......................*.....................
        // mul R10, R9, R2                     // ...............................*............
        // smlal R9, R11, R10, R3              // .................................*..........
        // vmov R1, s8                         // ..................*.........................
        // smull R9, R14, R14, R1              // ...................*........................
        // mul R10, R9, R2                     // .....................*......................
        // smlal R9, R14, R10, R3              // .......................*....................
        // add R5, R5, R6                      // .......................................*....
        // add R7, R7, R8                      // .........................................*..
        // add R4, R4, R11                     // ...................................*........
        // add R12, R12, R14                   // .........................*..................
        // sub.w R6, R5, R6, lsl #1            // ........................................*...
        // sub.w R8, R7, R8, lsl #1            // ..........................................*.
        // sub.w R11, R4, R11, lsl #1          // ......................................*.....
        // sub.w R14, R12, R14, lsl #1         // ...........................*................
        // str.w R6, [R0, #1*distance/4]       // ........................................*...
        // str.w R7, [R0, #2*distance/4]       // .........................................*..
        // str.w R8, [R0, #3*distance/4]       // ..........................................*.
        // str.w R4, [R0, #4*distance/4]       // ....................................*.......
        // str.w R11, [R0, #5*distance/4]      // .......................................*....
        // str.w R12, [R0, #6*distance/4]      // ..........................*.................
        // str.w R14, [R0, #7*distance/4]      // ............................*...............
        // str R5, [R0], #strincr              // ...........................................*
        // vmov R10, s9                        // ...........................................*

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      8400
        // Total Cycles:      10701
        // Total uOps:        8400
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    0.78
        // IPC:               0.78
        // Block RThroughput: 42.0
        //
        //
        // Cycles with backend pressure increase [ 78.49% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 18.69% ]
        //   Data Dependencies:      [ 59.80% ]
        //   - Register Dependencies [ 59.80% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r5, [r0]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #128]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #256]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #384]
        //  1      2     0.50    *                   ldr.w	r4, [r0, #512]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #640]
        //  1      2     0.50    *                   ldr.w	r12, [r0, #768]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #896]
        //  1      3     0.50                        vmov	r1, s2
        //  1      2     1.00                        smull	r9, r4, r4, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r4, r10, r3
        //  1      2     1.00                        smull	r9, r11, r11, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r11, r10, r3
        //  1      2     1.00                        smull	r9, r12, r12, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r12, r10, r3
        //  1      2     1.00                        smull	r9, lr, lr, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, lr, r10, r3
        //  1      1     0.50                        add	r5, r4
        //  1      1     0.50                        add	r6, r11
        //  1      1     0.50                        add	r7, r12
        //  1      1     0.50                        add	r8, lr
        //  1      2     1.00                        sub.w	r4, r5, r4, lsl #1
        //  1      2     1.00                        sub.w	r11, r6, r11, lsl #1
        //  1      2     1.00                        sub.w	r12, r7, r12, lsl #1
        //  1      2     1.00                        sub.w	lr, r8, lr, lsl #1
        //  1      3     0.50                        vmov	r1, s3
        //  1      2     1.00                        smull	r9, r7, r7, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r7, r10, r3
        //  1      2     1.00                        smull	r9, r8, r8, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r8, r10, r3
        //  1      3     0.50                        vmov	r1, s4
        //  1      2     1.00                        smull	r9, r12, r12, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r12, r10, r3
        //  1      2     1.00                        smull	r9, lr, lr, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, lr, r10, r3
        //  1      1     0.50                        add	r5, r7
        //  1      1     0.50                        add	r6, r8
        //  1      1     0.50                        add	r4, r12
        //  1      1     0.50                        add	r11, lr
        //  1      2     1.00                        sub.w	r7, r5, r7, lsl #1
        //  1      2     1.00                        sub.w	r8, r6, r8, lsl #1
        //  1      2     1.00                        sub.w	r12, r4, r12, lsl #1
        //  1      2     1.00                        sub.w	lr, r11, lr, lsl #1
        //  1      3     0.50                        vmov	r1, s5
        //  1      2     1.00                        smull	r9, r6, r6, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r6, r10, r3
        //  1      3     0.50                        vmov	r1, s6
        //  1      2     1.00                        smull	r9, r8, r8, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r8, r10, r3
        //  1      3     0.50                        vmov	r1, s7
        //  1      2     1.00                        smull	r9, r11, r11, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r11, r10, r3
        //  1      3     0.50                        vmov	r1, s8
        //  1      2     1.00                        smull	r9, lr, lr, r1
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, lr, r10, r3
        //  1      1     0.50                        add	r5, r6
        //  1      1     0.50                        add	r7, r8
        //  1      1     0.50                        add	r4, r11
        //  1      1     0.50                        add	r12, lr
        //  1      2     1.00                        sub.w	r6, r5, r6, lsl #1
        //  1      2     1.00                        sub.w	r8, r7, r8, lsl #1
        //  1      2     1.00                        sub.w	r11, r4, r11, lsl #1
        //  1      2     1.00                        sub.w	lr, r12, lr, lsl #1
        //  1      3     1.00           *            str.w	r6, [r0, #128]
        //  1      3     1.00           *            str.w	r7, [r0, #256]
        //  1      3     1.00           *            str.w	r8, [r0, #384]
        //  1      3     1.00           *            str.w	r4, [r0, #512]
        //  1      3     1.00           *            str.w	r11, [r0, #640]
        //  1      3     1.00           *            str.w	r12, [r0, #768]
        //  1      3     1.00           *            str.w	lr, [r0, #896]
        //  1      3     1.00           *            str	r5, [r0], #4
        //  1      3     0.50                        vmov	r10, s9
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      6399  (59.8%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 2000  (18.7%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              4101  (38.3%)
        //  1,              4800  (44.9%)
        //  2,              1800  (16.8%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          4101  (38.3%)
        //  1,          4800  (44.9%)
        //  2,          1800  (16.8%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    10100
        // Max number of mappings used:         4
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 12.00  12.00   -     4.00   4.00   36.00   -     12.00   -     8.00    -     4.00   4.00
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r5, [r0]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #128]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #256]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #384]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #512]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #640]
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r12, [r0, #768]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #896]
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r4, r4, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r4, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r11, r11, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r11, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r12, r12, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r12, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, lr, lr, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, lr, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r5, r4
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r6, r11
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r7, r12
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r8, lr
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r4, r5, r4, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r11, r6, r11, lsl #1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r12, r7, r12, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	lr, r8, lr, lsl #1
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r1, s3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r7, r7, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r7, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r8, r8, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r8, r10, r3
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r12, r12, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r12, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, lr, lr, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, lr, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r5, r7
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r6, r8
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r4, r12
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r11, lr
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r7, r5, r7, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r8, r6, r8, lsl #1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r12, r4, r12, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	lr, r11, lr, lsl #1
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r1, s5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r6, r6, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r6, r10, r3
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s6
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r8, r8, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r8, r10, r3
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r1, s7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r11, r11, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r11, r10, r3
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s8
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, lr, lr, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, lr, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r5, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r7, r8
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r4, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r12, lr
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r6, r5, r6, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r8, r7, r8, lsl #1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r11, r4, r11, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	lr, r12, lr, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #128]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r7, [r0, #256]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #384]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r4, [r0, #512]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r11, [r0, #640]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r12, [r0, #768]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	lr, [r0, #896]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0], #4
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r10, s9
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          01
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #128]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #256]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #384]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #512]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #640]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #768]
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #896]
        // [0,8]     .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s2
        // [0,9]     .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r4, r4, r1
        // [0,10]    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,11]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r4, r10, r3
        // [0,12]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [0,13]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,14]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r11, r10, r3
        // [0,15]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [0,16]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,17]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [0,18]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [0,19]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,20]    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [0,21]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r4
        // [0,22]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r6, r11
        // [0,23]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r7, r12
        // [0,24]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r8, lr
        // [0,25]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r4, r5, r4, lsl #1
        // [0,26]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r11, r6, r11, lsl #1
        // [0,27]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r12, r7, r12, lsl #1
        // [0,28]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r8, lr, lsl #1
        // [0,29]    .    .    .    .    .    .    . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s3
        // [0,30]    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r7, r7, r1
        // [0,31]    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,32]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r7, r10, r3
        // [0,33]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [0,34]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,35]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [0,36]    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s4
        // [0,37]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [0,38]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,39]    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [0,40]    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [0,41]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,42]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [0,43]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r7
        // [0,44]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r6, r8
        // [0,45]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r4, r12
        // [0,46]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r11, lr
        // [0,47]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r7, r5, r7, lsl #1
        // [0,48]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r8, r6, r8, lsl #1
        // [0,49]    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r12, r4, r12, lsl #1
        // [0,50]    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r11, lr, lsl #1
        // [0,51]    .    .    .    .    .    .    .    .    .    .    .    .    . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s5
        // [0,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r6, r6, r1
        // [0,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r6, r10, r3
        // [0,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s6
        // [0,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [0,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [0,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s7
        // [0,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [0,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r11, r10, r3
        // [0,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s8
        // [0,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [0,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [0,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [0,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r6
        // [0,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r7, r8
        // [0,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r4, r11
        // [0,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r12, lr
        // [0,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r6, r5, r6, lsl #1
        // [0,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r8, r7, r8, lsl #1
        // [0,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r11, r4, r11, lsl #1
        // [0,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r12, lr, lsl #1
        // [0,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r6, [r0, #128]
        // [0,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r7, [r0, #256]
        // [0,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [r0, #384]
        // [0,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r4, [r0, #512]
        // [0,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r11, [r0, #640]
        // [0,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r12, [r0, #768]
        // [0,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	lr, [r0, #896]
        // [0,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [r0], #4
        // [0,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r10, s9
        // [1,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0]
        // [1,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #128]
        // [1,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #256]
        // [1,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #384]
        // [1,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #512]
        // [1,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #640]
        // [1,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #768]
        // [1,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #896]
        // [1,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s2
        // [1,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r4, r4, r1
        // [1,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r4, r10, r3
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r11, r10, r3
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r4
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r6, r11
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r7, r12
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r8, lr
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r4, r5, r4, lsl #1
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r11, r6, r11, lsl #1
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r12, r7, r12, lsl #1
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r8, lr, lsl #1
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s3
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r7, r7, r1
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r7, r10, r3
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s4
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r7
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r6, r8
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r4, r12
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r11, lr
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r7, r5, r7, lsl #1
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r8, r6, r8, lsl #1
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r12, r4, r12, lsl #1
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r11, lr, lsl #1
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s5
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r6, r6, r1
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r6, r10, r3
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s6
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s7
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r11, r10, r3
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s8
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r6
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r7, r8
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r4, r11
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r12, lr
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r6, r5, r6, lsl #1
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r8, r7, r8, lsl #1
        // [1,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r11, r4, r11, lsl #1
        // [1,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r12, lr, lsl #1
        // [1,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r6, [r0, #128]
        // [1,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r7, [r0, #256]
        // [1,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [r0, #384]
        // [1,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r4, [r0, #512]
        // [1,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r11, [r0, #640]
        // [1,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r12, [r0, #768]
        // [1,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	lr, [r0, #896]
        // [1,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [r0], #4
        // [1,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r10, s9
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #128]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #256]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #384]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #512]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #640]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #768]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #896]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s2
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r4, r4, r1
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r4, r10, r3
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r11, r10, r3
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r5, r4
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r6, r11
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r7, r12
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   add	r8, lr
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r4, r5, r4, lsl #1
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r11, r6, r11, lsl #1
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	r12, r7, r12, lsl #1
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   sub.w	lr, r8, lr, lsl #1
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s3
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r7, r7, r1
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r7, r10, r3
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    ..   vmov	r1, s4
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    ..   smull	r9, r12, r12, r1
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    ..   smlal	r9, r12, r10, r3
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    ..   smull	r9, lr, lr, r1
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    ..   smlal	r9, lr, r10, r3
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   add	r5, r7
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   add	r6, r8
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   add	r4, r12
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   add	r11, lr
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    ..   sub.w	r7, r5, r7, lsl #1
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    ..   sub.w	r8, r6, r8, lsl #1
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   sub.w	r12, r4, r12, lsl #1
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   sub.w	lr, r11, lr, lsl #1
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    ..   vmov	r1, s5
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    ..   smull	r9, r6, r6, r1
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    ..   smlal	r9, r6, r10, r3
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    ..   vmov	r1, s6
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    ..   smull	r9, r8, r8, r1
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    ..   mul	r10, r9, r2
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    ..   smlal	r9, r8, r10, r3
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .    .    .    ..   vmov	r1, s7
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    ..   smull	r9, r11, r11, r1
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    ..   mul	r10, r9, r2
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    ..   smlal	r9, r11, r10, r3
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeeE    .    .    .    ..   vmov	r1, s8
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    ..   smull	r9, lr, lr, r1
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    ..   mul	r10, r9, r2
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    ..   smlal	r9, lr, r10, r3
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   add	r5, r6
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   add	r7, r8
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   add	r4, r11
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   add	r12, lr
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   sub.w	r6, r5, r6, lsl #1
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   sub.w	r8, r7, r8, lsl #1
        // [2,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   sub.w	r11, r4, r11, lsl #1
        // [2,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   sub.w	lr, r12, lr, lsl #1
        // [2,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    ..   str.w	r6, [r0, #128]
        // [2,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    ..   str.w	r7, [r0, #256]
        // [2,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    ..   str.w	r8, [r0, #384]
        // [2,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    ..   str.w	r4, [r0, #512]
        // [2,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   ..   str.w	r11, [r0, #640]
        // [2,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  ..   str.w	r12, [r0, #768]
        // [2,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE ..   str.w	lr, [r0, #896]
        // [2,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE.   str	r5, [r0], #4
        // [2,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   vmov	r10, s9
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r5, [r0]
        // 1.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #128]
        // 2.     3     0.0    0.0    0.0       ldr.w	r7, [r0, #256]
        // 3.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #384]
        // 4.     3     0.0    0.0    0.0       ldr.w	r4, [r0, #512]
        // 5.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #640]
        // 6.     3     0.0    0.0    0.0       ldr.w	r12, [r0, #768]
        // 7.     3     0.0    0.0    0.0       ldr.w	lr, [r0, #896]
        // 8.     3     0.0    0.0    0.0       vmov	r1, s2
        // 9.     3     0.0    0.0    0.0       smull	r9, r4, r4, r1
        // 10.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 11.    3     0.0    0.0    0.0       smlal	r9, r4, r10, r3
        // 12.    3     0.0    0.0    0.0       smull	r9, r11, r11, r1
        // 13.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 14.    3     0.0    0.0    0.0       smlal	r9, r11, r10, r3
        // 15.    3     0.0    0.0    0.0       smull	r9, r12, r12, r1
        // 16.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 17.    3     0.0    0.0    0.0       smlal	r9, r12, r10, r3
        // 18.    3     0.0    0.0    0.0       smull	r9, lr, lr, r1
        // 19.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 20.    3     0.0    0.0    0.0       smlal	r9, lr, r10, r3
        // 21.    3     0.0    0.0    0.0       add	r5, r4
        // 22.    3     0.0    0.0    0.0       add	r6, r11
        // 23.    3     0.0    0.0    0.0       add	r7, r12
        // 24.    3     0.0    0.0    0.0       add	r8, lr
        // 25.    3     0.0    0.0    0.0       sub.w	r4, r5, r4, lsl #1
        // 26.    3     0.0    0.0    0.0       sub.w	r11, r6, r11, lsl #1
        // 27.    3     0.0    0.0    0.0       sub.w	r12, r7, r12, lsl #1
        // 28.    3     0.0    0.0    0.0       sub.w	lr, r8, lr, lsl #1
        // 29.    3     0.0    0.0    0.0       vmov	r1, s3
        // 30.    3     0.0    0.0    0.0       smull	r9, r7, r7, r1
        // 31.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 32.    3     0.0    0.0    0.0       smlal	r9, r7, r10, r3
        // 33.    3     0.0    0.0    0.0       smull	r9, r8, r8, r1
        // 34.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 35.    3     0.0    0.0    0.0       smlal	r9, r8, r10, r3
        // 36.    3     0.0    0.0    0.0       vmov	r1, s4
        // 37.    3     0.0    0.0    0.0       smull	r9, r12, r12, r1
        // 38.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 39.    3     0.0    0.0    0.0       smlal	r9, r12, r10, r3
        // 40.    3     0.0    0.0    0.0       smull	r9, lr, lr, r1
        // 41.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 42.    3     0.0    0.0    0.0       smlal	r9, lr, r10, r3
        // 43.    3     0.0    0.0    0.0       add	r5, r7
        // 44.    3     0.0    0.0    0.0       add	r6, r8
        // 45.    3     0.0    0.0    0.0       add	r4, r12
        // 46.    3     0.0    0.0    0.0       add	r11, lr
        // 47.    3     0.0    0.0    0.0       sub.w	r7, r5, r7, lsl #1
        // 48.    3     0.0    0.0    0.0       sub.w	r8, r6, r8, lsl #1
        // 49.    3     0.0    0.0    0.0       sub.w	r12, r4, r12, lsl #1
        // 50.    3     0.0    0.0    0.0       sub.w	lr, r11, lr, lsl #1
        // 51.    3     0.0    0.0    0.0       vmov	r1, s5
        // 52.    3     0.0    0.0    0.0       smull	r9, r6, r6, r1
        // 53.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 54.    3     0.0    0.0    0.0       smlal	r9, r6, r10, r3
        // 55.    3     0.0    0.0    0.0       vmov	r1, s6
        // 56.    3     0.0    0.0    0.0       smull	r9, r8, r8, r1
        // 57.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 58.    3     0.0    0.0    0.0       smlal	r9, r8, r10, r3
        // 59.    3     0.0    0.0    0.0       vmov	r1, s7
        // 60.    3     0.0    0.0    0.0       smull	r9, r11, r11, r1
        // 61.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 62.    3     0.0    0.0    0.0       smlal	r9, r11, r10, r3
        // 63.    3     0.0    0.0    0.0       vmov	r1, s8
        // 64.    3     0.0    0.0    0.0       smull	r9, lr, lr, r1
        // 65.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 66.    3     0.0    0.0    0.0       smlal	r9, lr, r10, r3
        // 67.    3     0.0    0.0    0.0       add	r5, r6
        // 68.    3     0.0    0.0    0.0       add	r7, r8
        // 69.    3     0.0    0.0    0.0       add	r4, r11
        // 70.    3     0.0    0.0    0.0       add	r12, lr
        // 71.    3     0.0    0.0    0.0       sub.w	r6, r5, r6, lsl #1
        // 72.    3     0.0    0.0    0.0       sub.w	r8, r7, r8, lsl #1
        // 73.    3     0.0    0.0    0.0       sub.w	r11, r4, r11, lsl #1
        // 74.    3     0.0    0.0    0.0       sub.w	lr, r12, lr, lsl #1
        // 75.    3     0.0    0.0    0.0       str.w	r6, [r0, #128]
        // 76.    3     0.0    0.0    0.0       str.w	r7, [r0, #256]
        // 77.    3     0.0    0.0    0.0       str.w	r8, [r0, #384]
        // 78.    3     0.0    0.0    0.0       str.w	r4, [r0, #512]
        // 79.    3     0.0    0.0    0.0       str.w	r11, [r0, #640]
        // 80.    3     0.0    0.0    0.0       str.w	r12, [r0, #768]
        // 81.    3     0.0    0.0    0.0       str.w	lr, [r0, #896]
        // 82.    3     0.0    0.0    0.0       str	r5, [r0], #4
        // 83.    3     0.0    0.0    0.0       vmov	r10, s9
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (ORIGINAL) END
        //
        //
        // LLVM MCA STATISTICS (OPTIMIZED) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      8400
        // Total Cycles:      6601
        // Total uOps:        8400
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.27
        // IPC:               1.27
        // Block RThroughput: 42.0
        //
        //
        // Cycles with backend pressure increase [ 28.77% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 7.57% ]
        //   Data Dependencies:      [ 21.19% ]
        //   - Register Dependencies [ 21.19% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r9, [r0, #640]
        //  1      2     0.50    *                   ldr.w	r12, [r0, #896]
        //  1      3     0.50                        vmov	r1, s2
        //  1      2     0.50    *                   ldr.w	r5, [r0, #768]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #384]
        //  1      2     1.00                        smull	r10, r8, r12, r1
        //  1      2     1.00                        smull	lr, r5, r5, r1
        //  1      2     0.50    *                   ldr.w	r4, [r0, #512]
        //  1      2     1.00                        mul	r6, r10, r2
        //  1      2     1.00                        mul	r12, lr, r2
        //  1      3     0.50                        vmov	r11, s4
        //  1      2     1.00                        smlal	r10, r8, r6, r3
        //  1      2     1.00                        smull	r10, r6, r9, r1
        //  1      2     0.50    *                   ldr.w	r9, [r0, #256]
        //  1      1     0.50                        add	r7, r8
        //  1      2     1.00                        smlal	lr, r5, r12, r3
        //  1      2     1.00                        mul	lr, r10, r2
        //  1      2     1.00                        sub.w	r12, r7, r8, lsl #1
        //  1      1     0.50                        add.w	r8, r9, r5
        //  1      2     1.00                        smull	r12, r9, r12, r11
        //  1      2     1.00                        sub.w	r5, r8, r5, lsl #1
        //  1      2     1.00                        smlal	r10, r6, lr, r3
        //  1      2     1.00                        mul	lr, r12, r2
        //  1      2     1.00                        smull	r10, r1, r4, r1
        //  1      2     0.50    *                   ldr.w	r4, [r0, #128]
        //  1      2     1.00                        smlal	r12, r9, lr, r3
        //  1      1     0.50                        add.w	r12, r4, r6
        //  1      2     1.00                        sub.w	lr, r12, r6, lsl #1
        //  1      2     1.00                        mul	r4, r10, r2
        //  1      2     1.00                        smull	r11, r6, r5, r11
        //  1      1     0.50                        add.w	r5, lr, r9
        //  1      2     1.00                        sub.w	r9, r5, r9, lsl #1
        //  1      2     1.00                        smlal	r10, r1, r4, r3
        //  1      3     0.50                        vmov	r4, s8
        //  1      2     1.00                        mul	r10, r11, r2
        //  1      2     1.00                        smull	r9, r4, r9, r4
        //  1      2     0.50    *                   ldr.w	lr, [r0]
        //  1      2     1.00                        smlal	r11, r6, r10, r3
        //  1      3     0.50                        vmov	r11, s7
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      1     0.50                        add	lr, r1
        //  1      2     1.00                        smull	r11, r5, r5, r11
        //  1      2     1.00                        sub.w	r1, lr, r1, lsl #1
        //  1      2     1.00                        smlal	r9, r4, r10, r3
        //  1      1     0.50                        add.w	r10, r1, r6
        //  1      2     1.00                        sub.w	r9, r10, r6, lsl #1
        //  1      3     0.50                        vmov	r1, s3
        //  1      1     0.50                        add	r9, r4
        //  1      2     1.00                        smull	r6, r7, r7, r1
        //  1      3     1.00           *            str.w	r9, [r0, #768]
        //  1      2     1.00                        smull	r1, r8, r8, r1
        //  1      2     1.00                        sub.w	r9, r9, r4, lsl #1
        //  1      2     1.00                        mul	r4, r6, r2
        //  1      3     1.00           *            str.w	r9, [r0, #896]
        //  1      2     1.00                        mul	r9, r1, r2
        //  1      2     1.00                        smlal	r6, r7, r4, r3
        //  1      3     0.50                        vmov	r4, s5
        //  1      2     1.00                        smlal	r1, r8, r9, r3
        //  1      2     1.00                        mul	r1, r11, r2
        //  1      1     0.50                        add.w	r6, r12, r7
        //  1      2     1.00                        smull	r4, r9, r6, r4
        //  1      2     1.00                        sub.w	r12, r6, r7, lsl #1
        //  1      2     1.00                        smlal	r11, r5, r1, r3
        //  1      3     0.50                        vmov	r1, s6
        //  1      2     1.00                        smull	r12, r11, r12, r1
        //  1      1     0.50                        add.w	r7, lr, r8
        //  1      1     0.50                        add.w	r1, r10, r5
        //  1      2     1.00                        mul	r6, r4, r2
        //  1      3     1.00           *            str.w	r1, [r0, #512]
        //  1      2     1.00                        mul	r10, r12, r2
        //  1      2     1.00                        smlal	r4, r9, r6, r3
        //  1      2     1.00                        sub.w	r4, r7, r8, lsl #1
        //  1      2     1.00                        smlal	r12, r11, r10, r3
        //  1      2     1.00                        sub.w	r6, r1, r5, lsl #1
        //  1      3     1.00           *            str.w	r6, [r0, #640]
        //  1      1     0.50                        add.w	lr, r7, r9
        //  1      2     1.00                        sub.w	r12, lr, r9, lsl #1
        //  1      3     1.00           *            str.w	r12, [r0, #128]
        //  1      1     0.50                        add.w	r6, r4, r11
        //  1      3     1.00           *            str.w	r6, [r0, #256]
        //  1      2     1.00                        sub.w	r7, r6, r11, lsl #1
        //  1      3     1.00           *            str.w	r7, [r0, #384]
        //  1      3     1.00           *            str	lr, [r0], #4
        //  1      3     0.50                        vmov	r10, s9
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      1399  (21.2%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 500  (7.6%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              801  (12.1%)
        //  1,              3200  (48.5%)
        //  2,              2600  (39.4%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          801  (12.1%)
        //  1,          3200  (48.5%)
        //  2,          2600  (39.4%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    10100
        // Max number of mappings used:         5
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 12.00  12.00   -     4.00   4.00   36.00   -     12.00   -     8.00    -     4.00   4.00
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r9, [r0, #640]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r12, [r0, #896]
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s2
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #768]
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #384]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r10, r8, r12, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	lr, r5, r5, r1
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #512]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r6, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r12, lr, r2
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r11, s4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r10, r8, r6, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r10, r6, r9, r1
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	r9, [r0, #256]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r7, r8
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	lr, r5, r12, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	lr, r10, r2
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r12, r7, r8, lsl #1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r8, r9, r5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r12, r9, r12, r11
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r5, r8, r5, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r10, r6, lr, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	lr, r12, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r10, r1, r4, r1
        //  -      -      -      -     1.00    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #128]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r12, r9, lr, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r12, r4, r6
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	lr, r12, r6, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r4, r10, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r11, r6, r5, r11
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r5, lr, r9
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r9, r5, r9, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r10, r1, r4, r3
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r4, s8
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r11, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r4, r9, r4
        //  -      -      -     1.00    -      -      -      -      -      -      -      -      -     ldr.w	lr, [r0]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r11, r6, r10, r3
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r11, s7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	lr, r1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r11, r5, r5, r11
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r1, lr, r1, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r4, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r10, r1, r6
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r9, r10, r6, lsl #1
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r9, r4
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r6, r7, r7, r1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r9, [r0, #768]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r1, r8, r8, r1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r9, r9, r4, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r4, r6, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r9, [r0, #896]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r9, r1, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r6, r7, r4, r3
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r4, s5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r1, r8, r9, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r1, r11, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r6, r12, r7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r4, r9, r6, r4
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r12, r6, r7, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r11, r5, r1, r3
        //  -      -      -      -      -      -      -      -      -      -      -      -     1.00   vmov	r1, s6
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r12, r11, r12, r1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r7, lr, r8
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add.w	r1, r10, r5
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r6, r4, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r1, [r0, #512]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r12, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r4, r9, r6, r3
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r4, r7, r8, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r12, r11, r10, r3
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r6, r1, r5, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #640]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	lr, r7, r9
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r12, lr, r9, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r12, [r0, #128]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r6, r4, r11
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #256]
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r7, r6, r11, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r7, [r0, #384]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	lr, [r0], #4
        //  -      -      -      -      -      -      -      -      -      -      -     1.00    -     vmov	r10, s9
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          012345678
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #640]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #896]
        // [0,2]     .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s2
        // [0,3]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #768]
        // [0,4]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r7, [r0, #384]
        // [0,5]     .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r8, r12, r1
        // [0,6]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	lr, r5, r5, r1
        // [0,7]     .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #512]
        // [0,8]     .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r6, r10, r2
        // [0,9]     .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r12, lr, r2
        // [0,10]    .    . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r11, s4
        // [0,11]    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r8, r6, r3
        // [0,12]    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r6, r9, r1
        // [0,13]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #256]
        // [0,14]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	r7, r8
        // [0,15]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	lr, r5, r12, r3
        // [0,16]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	lr, r10, r2
        // [0,17]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, r7, r8, lsl #1
        // [0,18]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r8, r9, r5
        // [0,19]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r12, r9, r12, r11
        // [0,20]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r5, r8, r5, lsl #1
        // [0,21]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r6, lr, r3
        // [0,22]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	lr, r12, r2
        // [0,23]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r1, r4, r1
        // [0,24]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #128]
        // [0,25]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r12, r9, lr, r3
        // [0,26]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r12, r4, r6
        // [0,27]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	lr, r12, r6, lsl #1
        // [0,28]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r4, r10, r2
        // [0,29]    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r11, r6, r5, r11
        // [0,30]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r5, lr, r9
        // [0,31]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r5, r9, lsl #1
        // [0,32]    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r1, r4, r3
        // [0,33]    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r4, s8
        // [0,34]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r11, r2
        // [0,35]    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r9, r4, r9, r4
        // [0,36]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	lr, [r0]
        // [0,37]    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r11, r6, r10, r3
        // [0,38]    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r11, s7
        // [0,39]    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r9, r2
        // [0,40]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	lr, r1
        // [0,41]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r11, r5, r5, r11
        // [0,42]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r1, lr, r1, lsl #1
        // [0,43]    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r9, r4, r10, r3
        // [0,44]    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r10, r1, r6
        // [0,45]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r10, r6, lsl #1
        // [0,46]    .    .    .    .    .    .    .    DeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s3
        // [0,47]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	r9, r4
        // [0,48]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r6, r7, r7, r1
        // [0,49]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r9, [r0, #768]
        // [0,50]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r1, r8, r8, r1
        // [0,51]    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r9, r4, lsl #1
        // [0,52]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r4, r6, r2
        // [0,53]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r9, [r0, #896]
        // [0,54]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r9, r1, r2
        // [0,55]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r6, r7, r4, r3
        // [0,56]    .    .    .    .    .    .    .    .    . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r4, s5
        // [0,57]    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r1, r8, r9, r3
        // [0,58]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r1, r11, r2
        // [0,59]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r6, r12, r7
        // [0,60]    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r4, r9, r6, r4
        // [0,61]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, r6, r7, lsl #1
        // [0,62]    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r11, r5, r1, r3
        // [0,63]    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s6
        // [0,64]    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r12, r11, r12, r1
        // [0,65]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r7, lr, r8
        // [0,66]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r1, r10, r5
        // [0,67]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r6, r4, r2
        // [0,68]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r1, [r0, #512]
        // [0,69]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r12, r2
        // [0,70]    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r4, r9, r6, r3
        // [0,71]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r4, r7, r8, lsl #1
        // [0,72]    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r12, r11, r10, r3
        // [0,73]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r6, r1, r5, lsl #1
        // [0,74]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #640]
        // [0,75]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	lr, r7, r9
        // [0,76]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, lr, r9, lsl #1
        // [0,77]    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r12, [r0, #128]
        // [0,78]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r6, r4, r11
        // [0,79]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #256]
        // [0,80]    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r7, r6, r11, lsl #1
        // [0,81]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r7, [r0, #384]
        // [0,82]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	lr, [r0], #4
        // [0,83]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r10, s9
        // [1,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #640]
        // [1,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #896]
        // [1,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s2
        // [1,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #768]
        // [1,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r7, [r0, #384]
        // [1,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r8, r12, r1
        // [1,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	lr, r5, r5, r1
        // [1,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #512]
        // [1,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r6, r10, r2
        // [1,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r12, lr, r2
        // [1,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r11, s4
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r8, r6, r3
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r6, r9, r1
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #256]
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	r7, r8
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	lr, r5, r12, r3
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	lr, r10, r2
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, r7, r8, lsl #1
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r8, r9, r5
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r12, r9, r12, r11
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r5, r8, r5, lsl #1
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r6, lr, r3
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	lr, r12, r2
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r1, r4, r1
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #128]
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r12, r9, lr, r3
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r12, r4, r6
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	lr, r12, r6, lsl #1
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r4, r10, r2
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r11, r6, r5, r11
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r5, lr, r9
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r5, r9, lsl #1
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r1, r4, r3
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r4, s8
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r11, r2
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r9, r4, r9, r4
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	lr, [r0]
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r11, r6, r10, r3
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r11, s7
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r9, r2
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	lr, r1
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r11, r5, r5, r11
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r1, lr, r1, lsl #1
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r9, r4, r10, r3
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r10, r1, r6
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r10, r6, lsl #1
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s3
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add	r9, r4
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r6, r7, r7, r1
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r9, [r0, #768]
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r1, r8, r8, r1
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r9, r9, r4, lsl #1
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r4, r6, r2
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r9, [r0, #896]
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r9, r1, r2
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r6, r7, r4, r3
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r4, s5
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r1, r8, r9, r3
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r1, r11, r2
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r6, r12, r7
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r4, r9, r6, r4
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, r6, r7, lsl #1
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r11, r5, r1, r3
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s6
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r12, r11, r12, r1
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r7, lr, r8
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r1, r10, r5
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r6, r4, r2
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r1, [r0, #512]
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul	r10, r12, r2
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r4, r9, r6, r3
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r4, r7, r8, lsl #1
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   smlal	r12, r11, r10, r3
        // [1,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r6, r1, r5, lsl #1
        // [1,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #640]
        // [1,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	lr, r7, r9
        // [1,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, lr, r9, lsl #1
        // [1,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r12, [r0, #128]
        // [1,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.w	r6, r4, r11
        // [1,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #256]
        // [1,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.w	r7, r6, r11, lsl #1
        // [1,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r7, [r0, #384]
        // [1,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	lr, [r0], #4
        // [1,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r10, s9
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #640]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #896]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .  .   vmov	r1, s2
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #768]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r7, [r0, #384]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r8, r12, r1
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .  .   smull	lr, r5, r5, r1
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #512]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .  .   mul	r6, r10, r2
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .  .   mul	r12, lr, r2
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .  .   vmov	r11, s4
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .  .   smlal	r10, r8, r6, r3
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .  .   smull	r10, r6, r9, r1
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r9, [r0, #256]
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .  .   add	r7, r8
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .  .   smlal	lr, r5, r12, r3
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .  .   mul	lr, r10, r2
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .  .   sub.w	r12, r7, r8, lsl #1
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .  .   add.w	r8, r9, r5
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .  .   smull	r12, r9, r12, r11
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .  .   sub.w	r5, r8, r5, lsl #1
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .  .   smlal	r10, r6, lr, r3
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .  .   mul	lr, r12, r2
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .  .   smull	r10, r1, r4, r1
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .  .   ldr.w	r4, [r0, #128]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .  .   smlal	r12, r9, lr, r3
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .  .   add.w	r12, r4, r6
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .  .   sub.w	lr, r12, r6, lsl #1
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .  .   mul	r4, r10, r2
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .  .   smull	r11, r6, r5, r11
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .  .   add.w	r5, lr, r9
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .  .   sub.w	r9, r5, r9, lsl #1
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .  .   smlal	r10, r1, r4, r3
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .  .   vmov	r4, s8
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .  .   mul	r10, r11, r2
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .  .   smull	r9, r4, r9, r4
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .  .   ldr.w	lr, [r0]
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .  .   smlal	r11, r6, r10, r3
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .  .   vmov	r11, s7
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .  .   mul	r10, r9, r2
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .  .   add	lr, r1
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .  .   smull	r11, r5, r5, r11
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .  .   sub.w	r1, lr, r1, lsl #1
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .  .   smlal	r9, r4, r10, r3
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .  .   add.w	r10, r1, r6
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .  .   sub.w	r9, r10, r6, lsl #1
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeeE    .    .    .    .    .  .   vmov	r1, s3
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .  .   add	r9, r4
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .  .   smull	r6, r7, r7, r1
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .  .   str.w	r9, [r0, #768]
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .  .   smull	r1, r8, r8, r1
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .  .   sub.w	r9, r9, r4, lsl #1
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .  .   mul	r4, r6, r2
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .  .   str.w	r9, [r0, #896]
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .  .   mul	r9, r1, r2
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .  .   smlal	r6, r7, r4, r3
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .  .   vmov	r4, s5
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .  .   smlal	r1, r8, r9, r3
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .  .   mul	r1, r11, r2
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .  .   add.w	r6, r12, r7
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .  .   smull	r4, r9, r6, r4
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .  .   sub.w	r12, r6, r7, lsl #1
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .  .   smlal	r11, r5, r1, r3
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .  .   vmov	r1, s6
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .  .   smull	r12, r11, r12, r1
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .  .   add.w	r7, lr, r8
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .  .   add.w	r1, r10, r5
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .  .   mul	r6, r4, r2
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .  .   str.w	r1, [r0, #512]
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .  .   mul	r10, r12, r2
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .  .   smlal	r4, r9, r6, r3
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .  .   sub.w	r4, r7, r8, lsl #1
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .  .   smlal	r12, r11, r10, r3
        // [2,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .  .   sub.w	r6, r1, r5, lsl #1
        // [2,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .  .   str.w	r6, [r0, #640]
        // [2,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .  .   add.w	lr, r7, r9
        // [2,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .  .   sub.w	r12, lr, r9, lsl #1
        // [2,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .  .   str.w	r12, [r0, #128]
        // [2,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .  .   add.w	r6, r4, r11
        // [2,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.  .   str.w	r6, [r0, #256]
        // [2,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.  .   sub.w	r7, r6, r11, lsl #1
        // [2,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE  .   str.w	r7, [r0, #384]
        // [2,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE.   str	lr, [r0], #4
        // [2,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeeE   vmov	r10, s9
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r9, [r0, #640]
        // 1.     3     0.0    0.0    0.0       ldr.w	r12, [r0, #896]
        // 2.     3     0.0    0.0    0.0       vmov	r1, s2
        // 3.     3     0.0    0.0    0.0       ldr.w	r5, [r0, #768]
        // 4.     3     0.0    0.0    0.0       ldr.w	r7, [r0, #384]
        // 5.     3     0.0    0.0    0.0       smull	r10, r8, r12, r1
        // 6.     3     0.0    0.0    0.0       smull	lr, r5, r5, r1
        // 7.     3     0.0    0.0    0.0       ldr.w	r4, [r0, #512]
        // 8.     3     0.0    0.0    0.0       mul	r6, r10, r2
        // 9.     3     0.0    0.0    0.0       mul	r12, lr, r2
        // 10.    3     0.0    0.0    0.0       vmov	r11, s4
        // 11.    3     0.0    0.0    0.0       smlal	r10, r8, r6, r3
        // 12.    3     0.0    0.0    0.0       smull	r10, r6, r9, r1
        // 13.    3     0.0    0.0    0.0       ldr.w	r9, [r0, #256]
        // 14.    3     0.0    0.0    0.0       add	r7, r8
        // 15.    3     0.0    0.0    0.0       smlal	lr, r5, r12, r3
        // 16.    3     0.0    0.0    0.0       mul	lr, r10, r2
        // 17.    3     0.0    0.0    0.0       sub.w	r12, r7, r8, lsl #1
        // 18.    3     0.0    0.0    0.0       add.w	r8, r9, r5
        // 19.    3     0.0    0.0    0.0       smull	r12, r9, r12, r11
        // 20.    3     0.0    0.0    0.0       sub.w	r5, r8, r5, lsl #1
        // 21.    3     0.0    0.0    0.0       smlal	r10, r6, lr, r3
        // 22.    3     0.0    0.0    0.0       mul	lr, r12, r2
        // 23.    3     0.0    0.0    0.0       smull	r10, r1, r4, r1
        // 24.    3     0.0    0.0    0.0       ldr.w	r4, [r0, #128]
        // 25.    3     0.0    0.0    0.0       smlal	r12, r9, lr, r3
        // 26.    3     0.0    0.0    0.0       add.w	r12, r4, r6
        // 27.    3     0.0    0.0    0.0       sub.w	lr, r12, r6, lsl #1
        // 28.    3     0.0    0.0    0.0       mul	r4, r10, r2
        // 29.    3     0.0    0.0    0.0       smull	r11, r6, r5, r11
        // 30.    3     0.0    0.0    0.0       add.w	r5, lr, r9
        // 31.    3     0.0    0.0    0.0       sub.w	r9, r5, r9, lsl #1
        // 32.    3     0.0    0.0    0.0       smlal	r10, r1, r4, r3
        // 33.    3     0.0    0.0    0.0       vmov	r4, s8
        // 34.    3     0.0    0.0    0.0       mul	r10, r11, r2
        // 35.    3     0.0    0.0    0.0       smull	r9, r4, r9, r4
        // 36.    3     0.0    0.0    0.0       ldr.w	lr, [r0]
        // 37.    3     0.0    0.0    0.0       smlal	r11, r6, r10, r3
        // 38.    3     0.0    0.0    0.0       vmov	r11, s7
        // 39.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 40.    3     0.0    0.0    0.0       add	lr, r1
        // 41.    3     0.0    0.0    0.0       smull	r11, r5, r5, r11
        // 42.    3     0.0    0.0    0.0       sub.w	r1, lr, r1, lsl #1
        // 43.    3     0.0    0.0    0.0       smlal	r9, r4, r10, r3
        // 44.    3     0.0    0.0    0.0       add.w	r10, r1, r6
        // 45.    3     0.0    0.0    0.0       sub.w	r9, r10, r6, lsl #1
        // 46.    3     0.0    0.0    0.0       vmov	r1, s3
        // 47.    3     0.0    0.0    0.0       add	r9, r4
        // 48.    3     0.0    0.0    0.0       smull	r6, r7, r7, r1
        // 49.    3     0.0    0.0    0.0       str.w	r9, [r0, #768]
        // 50.    3     0.0    0.0    0.0       smull	r1, r8, r8, r1
        // 51.    3     0.0    0.0    0.0       sub.w	r9, r9, r4, lsl #1
        // 52.    3     0.0    0.0    0.0       mul	r4, r6, r2
        // 53.    3     0.0    0.0    0.0       str.w	r9, [r0, #896]
        // 54.    3     0.0    0.0    0.0       mul	r9, r1, r2
        // 55.    3     0.0    0.0    0.0       smlal	r6, r7, r4, r3
        // 56.    3     0.0    0.0    0.0       vmov	r4, s5
        // 57.    3     0.0    0.0    0.0       smlal	r1, r8, r9, r3
        // 58.    3     0.0    0.0    0.0       mul	r1, r11, r2
        // 59.    3     0.0    0.0    0.0       add.w	r6, r12, r7
        // 60.    3     0.0    0.0    0.0       smull	r4, r9, r6, r4
        // 61.    3     0.0    0.0    0.0       sub.w	r12, r6, r7, lsl #1
        // 62.    3     0.0    0.0    0.0       smlal	r11, r5, r1, r3
        // 63.    3     0.0    0.0    0.0       vmov	r1, s6
        // 64.    3     0.0    0.0    0.0       smull	r12, r11, r12, r1
        // 65.    3     0.0    0.0    0.0       add.w	r7, lr, r8
        // 66.    3     0.0    0.0    0.0       add.w	r1, r10, r5
        // 67.    3     0.0    0.0    0.0       mul	r6, r4, r2
        // 68.    3     0.0    0.0    0.0       str.w	r1, [r0, #512]
        // 69.    3     0.0    0.0    0.0       mul	r10, r12, r2
        // 70.    3     0.0    0.0    0.0       smlal	r4, r9, r6, r3
        // 71.    3     0.0    0.0    0.0       sub.w	r4, r7, r8, lsl #1
        // 72.    3     0.0    0.0    0.0       smlal	r12, r11, r10, r3
        // 73.    3     0.0    0.0    0.0       sub.w	r6, r1, r5, lsl #1
        // 74.    3     0.0    0.0    0.0       str.w	r6, [r0, #640]
        // 75.    3     0.0    0.0    0.0       add.w	lr, r7, r9
        // 76.    3     0.0    0.0    0.0       sub.w	r12, lr, r9, lsl #1
        // 77.    3     0.0    0.0    0.0       str.w	r12, [r0, #128]
        // 78.    3     0.0    0.0    0.0       add.w	r6, r4, r11
        // 79.    3     0.0    0.0    0.0       str.w	r6, [r0, #256]
        // 80.    3     0.0    0.0    0.0       sub.w	r7, r6, r11, lsl #1
        // 81.    3     0.0    0.0    0.0       str.w	r7, [r0, #384]
        // 82.    3     0.0    0.0    0.0       str	lr, [r0], #4
        // 83.    3     0.0    0.0    0.0       vmov	r10, s9
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        layer123_end:

    cmp.w ptr_p, temp_l
    bne 1b

  sub ptr_p, #32*4

  // stage 4 - 6
  .equ distance, 64
  add.w temp_l, ptr_p, #8*112+8*4*4 // 8 iterations
  vmov s9, temp_l
  1:
    add.w temp_l, ptr_p, #4*strincr // 4 iterations
    vmov s10, temp_l
    vmov ptr_zeta, s0
    vldm ptr_zeta!, {s2-s8}
    vmov s0, ptr_zeta
    2:
      .rept 2
        // layer456_start:
                                              // Instructions:    83
                                              // Expected cycles: 44
                                              // Expected IPC:    1.89
                                              //
                                              // Cycle bound:     43.0
                                              // IPC bound:       1.93
                                              //
                                              // Wall time:     300.23s
                                              // User time:     300.23s
                                              //
                                              // ------------ cycle (expected) ------------->
                                              // 0                        25
                                              // |------------------------|------------------
        vmov r14, s2                          // *...........................................
        ldr.w r10, [r0, #7*distance/4]        // *...........................................
        ldr.w r11, [r0, #6*distance/4]        // .*..........................................
        vmov r4, s4                           // .*..........................................
        smull r9, r8, r10, r14                // ..*.........................................
        ldr.w r1, [r0, #5*distance/4]         // ...*........................................
        smull r5, r7, r11, r14                // ...*........................................
        mul r10, r9, r2                       // ....*.......................................
        ldr.w r11, [r0, #3*distance/4]        // .....*......................................
        mul r12, r5, r2                       // .....*......................................
        smlal r9, r8, r10, r3                 // ......*.....................................
        ldr.w r10, [r0, #2*distance/4]        // ......*.....................................
        smull r1, r9, r1, r14                 // .......*....................................
        ldr.w r6, [r0, #4*distance/4]         // .......*....................................
        add r11, r11, r8                      // ........*...................................
        smlal r5, r7, r12, r3                 // ........*...................................
        sub.w r8, r11, r8, lsl #1             // .........*..................................
        mul r12, r1, r2                       // .........*..................................
        add r5, r10, r7                       // ..........*.................................
        smull r8, r10, r8, r4                 // ..........*.................................
        smlal r1, r9, r12, r3                 // ...........*................................
        sub.w r12, r5, r7, lsl #1             // ............*...............................
        mul r7, r8, r2                        // ............*...............................
        smull r1, r6, r6, r14                 // .............*..............................
        ldr.w r14, [r0, #1*distance/4]        // .............*..............................
        smlal r8, r10, r7, r3                 // ..............*.............................
        add r14, r14, r9                      // ..............*.............................
        sub.w r9, r14, r9, lsl #1             // ...............*............................
        mul r8, r1, r2                        // ...............*............................
        smull r4, r7, r12, r4                 // ................*...........................
        add r12, r9, r10                      // ................*...........................
        sub.w r9, r12, r10, lsl #1            // .................*..........................
        smlal r1, r6, r8, r3                  // .................*..........................
        mul r1, r4, r2                        // ..................*.........................
        vmov r10, s8                          // ..................*.........................
        ldr.w r8, [r0]                        // ...................*........................
        smull r10, r9, r9, r10                // ...................*........................
        smlal r4, r7, r1, r3                  // ....................*.......................
        vmov r4, s7                           // ....................*.......................
        mul r1, r10, r2                       // .....................*......................
        add r8, r8, r6                        // .....................*......................
        sub.w r6, r8, r6, lsl #1              // ......................*.....................
        smull r4, r12, r12, r4                // ......................*.....................
        smlal r10, r9, r1, r3                 // .......................*....................
        add r10, r6, r7                       // .......................*....................
        sub.w r6, r10, r7, lsl #1             // ........................*...................
        vmov r7, s3                           // ........................*...................
        smull r11, r1, r11, r7                // .........................*..................
        add r6, r6, r9                        // .........................*..................
        sub.w r9, r6, r9, lsl #1              // ..........................*.................
        smull r7, r5, r5, r7                  // ..........................*.................
        str.w r6, [r0, #6*distance/4]         // ...........................*................
        mul r6, r11, r2                       // ...........................*................
        str.w r9, [r0, #7*distance/4]         // ............................*...............
        mul r9, r7, r2                        // ............................*...............
        smlal r11, r1, r6, r3                 // .............................*..............
        vmov r11, s6                          // .............................*..............
        mul r6, r4, r2                        // ..............................*.............
        add r14, r14, r1                      // ...............................*............
        smlal r7, r5, r9, r3                  // ...............................*............
        vmov r9, s5                           // ................................*...........
        smlal r4, r12, r6, r3                 // ................................*...........
        sub.w r6, r14, r1, lsl #1             // .................................*..........
        smull r7, r4, r14, r9                 // .................................*..........
        add r14, r10, r12                     // ..................................*.........
        smull r10, r9, r6, r11                // ..................................*.........
        mul r11, r7, r2                       // ...................................*........
        sub.w r6, r14, r12, lsl #1            // ...................................*........
        str.w r14, [r0, #4*distance/4]        // ....................................*.......
        mul r12, r10, r2                      // ....................................*.......
        smlal r7, r4, r11, r3                 // .....................................*......
        str.w r6, [r0, #5*distance/4]         // .....................................*......
        add r6, r8, r5                        // ......................................*.....
        smlal r10, r9, r12, r3                // ......................................*.....
        sub.w r14, r6, r5, lsl #1             // .......................................*....
        add r8, r6, r4                        // .......................................*....
        sub.w r11, r8, r4, lsl #1             // ........................................*...
        str.w r11, [r0, #1*distance/4]        // ........................................*...
        add r6, r14, r9                       // .........................................*..
        str.w r6, [r0, #2*distance/4]         // .........................................*..
        sub.w r6, r6, r9, lsl #1              // ..........................................*.
        str.w r6, [r0, #3*distance/4]         // ..........................................*.
        str r8, [r0], #4                      // ...........................................*

                                               // ------------ cycle (expected) ------------->
                                               // 0                        25
                                               // |------------------------|------------------
        // ldr.w R5, [R0]                      // ...................*........................
        // ldr.w R6, [R0, #1*distance/4]       // .............*..............................
        // ldr.w R7, [R0, #2*distance/4]       // ......*.....................................
        // ldr.w R8, [R0, #3*distance/4]       // .....*......................................
        // ldr.w R4, [R0, #4*distance/4]       // .......*....................................
        // ldr.w R11, [R0, #5*distance/4]      // ...*........................................
        // ldr.w R12, [R0, #6*distance/4]      // .*..........................................
        // ldr.w R14, [R0, #7*distance/4]      // *...........................................
        // vmov R1, s2                         // *...........................................
        // smull R9, R4, R4, R1                // .............*..............................
        // mul R10, R9, R2                     // ...............*............................
        // smlal R9, R4, R10, R3               // .................*..........................
        // smull R9, R11, R11, R1              // .......*....................................
        // mul R10, R9, R2                     // .........*..................................
        // smlal R9, R11, R10, R3              // ...........*................................
        // smull R9, R12, R12, R1              // ...*........................................
        // mul R10, R9, R2                     // .....*......................................
        // smlal R9, R12, R10, R3              // ........*...................................
        // smull R9, R14, R14, R1              // ..*.........................................
        // mul R10, R9, R2                     // ....*.......................................
        // smlal R9, R14, R10, R3              // ......*.....................................
        // add R5, R5, R4                      // .....................*......................
        // add R6, R6, R11                     // ..............*.............................
        // add R7, R7, R12                     // ..........*.................................
        // add R8, R8, R14                     // ........*...................................
        // sub.w R4, R5, R4, lsl #1            // ......................*.....................
        // sub.w R11, R6, R11, lsl #1          // ...............*............................
        // sub.w R12, R7, R12, lsl #1          // ............*...............................
        // sub.w R14, R8, R14, lsl #1          // .........*..................................
        // vmov R1, s3                         // ........................*...................
        // smull R9, R7, R7, R1                // ..........................*.................
        // mul R10, R9, R2                     // ............................*...............
        // smlal R9, R7, R10, R3               // ...............................*............
        // smull R9, R8, R8, R1                // .........................*..................
        // mul R10, R9, R2                     // ...........................*................
        // smlal R9, R8, R10, R3               // .............................*..............
        // vmov R1, s4                         // .*..........................................
        // smull R9, R12, R12, R1              // ................*...........................
        // mul R10, R9, R2                     // ..................*.........................
        // smlal R9, R12, R10, R3              // ....................*.......................
        // smull R9, R14, R14, R1              // ..........*.................................
        // mul R10, R9, R2                     // ............*...............................
        // smlal R9, R14, R10, R3              // ..............*.............................
        // add R5, R5, R7                      // ......................................*.....
        // add R6, R6, R8                      // ...............................*............
        // add R4, R4, R12                     // .......................*....................
        // add R11, R11, R14                   // ................*...........................
        // sub.w R7, R5, R7, lsl #1            // .......................................*....
        // sub.w R8, R6, R8, lsl #1            // .................................*..........
        // sub.w R12, R4, R12, lsl #1          // ........................*...................
        // sub.w R14, R11, R14, lsl #1         // .................*..........................
        // vmov R1, s5                         // ................................*...........
        // smull R9, R6, R6, R1                // .................................*..........
        // mul R10, R9, R2                     // ...................................*........
        // smlal R9, R6, R10, R3               // .....................................*......
        // vmov R1, s6                         // .............................*..............
        // smull R9, R8, R8, R1                // ..................................*.........
        // mul R10, R9, R2                     // ....................................*.......
        // smlal R9, R8, R10, R3               // ......................................*.....
        // vmov R1, s7                         // ....................*.......................
        // smull R9, R11, R11, R1              // ......................*.....................
        // mul R10, R9, R2                     // ..............................*.............
        // smlal R9, R11, R10, R3              // ................................*...........
        // vmov R1, s8                         // ..................*.........................
        // smull R9, R14, R14, R1              // ...................*........................
        // mul R10, R9, R2                     // .....................*......................
        // smlal R9, R14, R10, R3              // .......................*....................
        // add R5, R5, R6                      // .......................................*....
        // add R7, R7, R8                      // .........................................*..
        // add R4, R4, R11                     // ..................................*.........
        // add R12, R12, R14                   // .........................*..................
        // sub.w R6, R5, R6, lsl #1            // ........................................*...
        // sub.w R8, R7, R8, lsl #1            // ..........................................*.
        // sub.w R11, R4, R11, lsl #1          // ...................................*........
        // sub.w R14, R12, R14, lsl #1         // ..........................*.................
        // str.w R6, [R0, #1*distance/4]       // ........................................*...
        // str.w R7, [R0, #2*distance/4]       // .........................................*..
        // str.w R8, [R0, #3*distance/4]       // ..........................................*.
        // str.w R4, [R0, #4*distance/4]       // ....................................*.......
        // str.w R11, [R0, #5*distance/4]      // .....................................*......
        // str.w R12, [R0, #6*distance/4]      // ...........................*................
        // str.w R14, [R0, #7*distance/4]      // ............................*...............
        // str R5, [R0], #4                    // ...........................................*

        // layer456_end:

      .endr
      vmov temp_l, s10
      cmp.w ptr_p, temp_l
      bne 2b

    add.w ptr_p, #112
    vmov temp_l, s9
    cmp.w ptr_p, temp_l
    bne 1b

    sub ptr_p, #4*4*8+112*8
    vmov ptr_zeta, s0
    // stage 7 and 8
    add cntr, ptr_p, #1024 // 64 iterations

layer78_loop:
                                          // Instructions:    31
                                          // Expected cycles: 21
                                          // Expected IPC:    1.48
                                          //
                                          // Cycle bound:     21.0
                                          // IPC bound:       1.48
                                          //
                                          // Wall time:     0.25s
                                          // User time:     0.25s
                                          //
                                          // ----- cycle (expected) ------>
                                          // 0                        25
                                          // |------------------------|----
        ldr.w r11, [r1, #8]               // *.............................
        ldr.w r8, [r1, #4]                // *.............................
        ldr r7, [r1], #12                 // .*............................
        ldr.w r6, [r0, #12]               // .*............................
        ldr.w r5, [r0, #8]                // ..*...........................
        smull r14, r9, r6, r7             // ...*..........................
        smull r12, r6, r5, r7             // ....*.........................
        mul r5, r14, r2                   // .....*........................
        mul r7, r12, r2                   // ......*.......................
        smlal r14, r9, r5, r3             // .......*......................
        ldr.w r5, [r0]                    // .......*......................
        smlal r12, r6, r7, r3             // ........*.....................
        ldr.w r14, [r0, #4]               // ........*.....................
        add r14, r14, r9                  // .........*....................
        smull r12, r7, r14, r8            // ..........*...................
        sub.w r14, r14, r9, lsl #1        // ..........*...................
        add r10, r5, r6                   // ...........*..................
        smull r5, r9, r14, r11            // ...........*..................
        mul r8, r12, r2                   // ............*.................
        mul r14, r5, r2                   // .............*................
        smlal r12, r7, r8, r3             // ..............*...............
        smlal r5, r9, r14, r3             // ...............*..............
        add r14, r10, r7                  // ................*.............
        sub.w r5, r10, r6, lsl #1         // ................*.............
        sub.w r6, r14, r7, lsl #1         // .................*............
        str.w r6, [r0, #4]                // .................*............
        add r6, r5, r9                    // ..................*...........
        str.w r6, [r0, #8]                // ..................*...........
        sub.w r6, r6, r9, lsl #1          // ...................*..........
        str.w r6, [r0, #12]               // ...................*..........
        str r14, [r0], #16                // ....................*.........

                                         // ------ cycle (expected) ------>
                                         // 0                        25
                                         // |------------------------|-----
        // ldr.w R12, [R1, #4]           // *..............................
        // ldr.w R14, [R1, #8]           // *..............................
        // ldr R11, [R1], #12            // .*.............................
        // ldr.w R5, [R0]                // .......*.......................
        // ldr.w R6, [R0, #4]            // ........*......................
        // ldr.w R7, [R0, #8]            // ..*............................
        // ldr.w R8, [R0, #12]           // .*.............................
        // smull R9, R7, R7, R11         // ....*..........................
        // mul R10, R9, R2               // ......*........................
        // smlal R9, R7, R10, R3         // ........*......................
        // smull R9, R8, R8, R11         // ...*...........................
        // mul R10, R9, R2               // .....*.........................
        // smlal R9, R8, R10, R3         // .......*.......................
        // add R5, R5, R7                // ...........*...................
        // add R6, R6, R8                // .........*.....................
        // sub.w R7, R5, R7, lsl #1      // ................*..............
        // sub.w R8, R6, R8, lsl #1      // ..........*....................
        // smull R9, R6, R6, R12         // ..........*....................
        // mul R10, R9, R2               // ............*..................
        // smlal R9, R6, R10, R3         // ..............*................
        // smull R9, R8, R8, R14         // ...........*...................
        // mul R10, R9, R2               // .............*.................
        // smlal R9, R8, R10, R3         // ...............*...............
        // add R5, R5, R6                // ................*..............
        // add R7, R7, R8                // ..................*............
        // sub.w R6, R5, R6, lsl #1      // .................*.............
        // sub.w R8, R7, R8, lsl #1      // ...................*...........
        // str.w R6, [R0, #4]            // .................*.............
        // str.w R7, [R0, #8]            // ..................*............
        // str.w R8, [R0, #12]           // ...................*...........
        // str R5, [R0], #16             // ....................*..........

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      3100
        // Total Cycles:      3301
        // Total uOps:        3100
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    0.94
        // IPC:               0.94
        // Block RThroughput: 15.5
        //
        //
        // Cycles with backend pressure increase [ 66.59% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 12.12% ]
        //   Data Dependencies:      [ 54.47% ]
        //   - Register Dependencies [ 54.47% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r12, [r1, #4]
        //  1      2     0.50    *                   ldr.w	lr, [r1, #8]
        //  1      2     0.50    *                   ldr	r11, [r1], #12
        //  1      2     0.50    *                   ldr.w	r5, [r0]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #4]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #8]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #12]
        //  1      2     1.00                        smull	r9, r7, r7, r11
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r7, r10, r3
        //  1      2     1.00                        smull	r9, r8, r8, r11
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r8, r10, r3
        //  1      1     0.50                        add	r5, r7
        //  1      1     0.50                        add	r6, r8
        //  1      2     1.00                        sub.w	r7, r5, r7, lsl #1
        //  1      2     1.00                        sub.w	r8, r6, r8, lsl #1
        //  1      2     1.00                        smull	r9, r6, r6, r12
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r6, r10, r3
        //  1      2     1.00                        smull	r9, r8, r8, lr
        //  1      2     1.00                        mul	r10, r9, r2
        //  1      2     1.00                        smlal	r9, r8, r10, r3
        //  1      1     0.50                        add	r5, r6
        //  1      1     0.50                        add	r7, r8
        //  1      2     1.00                        sub.w	r6, r5, r6, lsl #1
        //  1      2     1.00                        sub.w	r8, r7, r8, lsl #1
        //  1      3     1.00           *            str.w	r6, [r0, #4]
        //  1      3     1.00           *            str.w	r7, [r0, #8]
        //  1      3     1.00           *            str.w	r8, [r0, #12]
        //  1      3     1.00           *            str	r5, [r0], #16
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      1798  (54.5%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 400  (12.1%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              902  (27.3%)
        //  1,              1698  (51.4%)
        //  2,              701  (21.2%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          902  (27.3%)
        //  1,          1698  (51.4%)
        //  2,          701  (21.2%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    3700
        // Max number of mappings used:         4
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 4.00   4.00    -     3.50   3.50   12.00   -     4.00    -     4.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r12, [r1, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r1, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r11, [r1], #12
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #12]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r7, r7, r11
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r7, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r8, r8, r11
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r8, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r5, r7
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r6, r8
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r7, r5, r7, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r8, r6, r8, lsl #1
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r6, r6, r12
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r6, r10, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r9, r8, r8, lr
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r10, r9, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r9, r8, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	r5, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add	r7, r8
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r6, r5, r6, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r8, r7, r8, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #4]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r7, [r0, #8]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0], #16
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r12, [r1, #4]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	lr, [r1, #8]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr	r11, [r1], #12
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r5, [r0]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r6, [r0, #4]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r7, [r0, #8]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r8, [r0, #12]
        // [0,7]     .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r7, r7, r11
        // [0,8]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [0,9]     .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r7, r10, r3
        // [0,10]    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r8, r8, r11
        // [0,11]    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [0,12]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r8, r10, r3
        // [0,13]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   add	r5, r7
        // [0,14]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   add	r6, r8
        // [0,15]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   sub.w	r7, r5, r7, lsl #1
        // [0,16]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   sub.w	r8, r6, r8, lsl #1
        // [0,17]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r6, r6, r12
        // [0,18]    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [0,19]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r6, r10, r3
        // [0,20]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r8, r8, lr
        // [0,21]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [0,22]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r8, r10, r3
        // [0,23]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   add	r5, r6
        // [0,24]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   add	r7, r8
        // [0,25]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   sub.w	r6, r5, r6, lsl #1
        // [0,26]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .   .   sub.w	r8, r7, r8, lsl #1
        // [0,27]    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .   .   str.w	r6, [r0, #4]
        // [0,28]    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .   .   str.w	r7, [r0, #8]
        // [0,29]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .   .   str.w	r8, [r0, #12]
        // [0,30]    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .   .   str	r5, [r0], #16
        // [1,0]     .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r12, [r1, #4]
        // [1,1]     .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	lr, [r1, #8]
        // [1,2]     .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr	r11, [r1], #12
        // [1,3]     .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r5, [r0]
        // [1,4]     .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r6, [r0, #4]
        // [1,5]     .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r7, [r0, #8]
        // [1,6]     .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .   .   ldr.w	r8, [r0, #12]
        // [1,7]     .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r7, r7, r11
        // [1,8]     .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [1,9]     .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r7, r10, r3
        // [1,10]    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .   .   smull	r9, r8, r8, r11
        // [1,11]    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [1,12]    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .   .   smlal	r9, r8, r10, r3
        // [1,13]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .   .   add	r5, r7
        // [1,14]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .   .   add	r6, r8
        // [1,15]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .   .   sub.w	r7, r5, r7, lsl #1
        // [1,16]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .   .   sub.w	r8, r6, r8, lsl #1
        // [1,17]    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .   .   smull	r9, r6, r6, r12
        // [1,18]    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [1,19]    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .   .   smlal	r9, r6, r10, r3
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .   .   smull	r9, r8, r8, lr
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .   .   mul	r10, r9, r2
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .   .   smlal	r9, r8, r10, r3
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .   .   add	r5, r6
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .   .   add	r7, r8
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .   .   sub.w	r6, r5, r6, lsl #1
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .   .   sub.w	r8, r7, r8, lsl #1
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .   .   str.w	r6, [r0, #4]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .   .   str.w	r7, [r0, #8]
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .   .   str.w	r8, [r0, #12]
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .   .   str	r5, [r0], #16
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .   .   ldr.w	r12, [r1, #4]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .   .   ldr.w	lr, [r1, #8]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .   .   ldr	r11, [r1], #12
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .   .   ldr.w	r5, [r0]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .   .   ldr.w	r6, [r0, #4]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .   .   ldr.w	r7, [r0, #8]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .   .   ldr.w	r8, [r0, #12]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .   .   smull	r9, r7, r7, r11
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .   .   mul	r10, r9, r2
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .   .   smlal	r9, r7, r10, r3
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .   .   smull	r9, r8, r8, r11
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .   .   mul	r10, r9, r2
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .   .   smlal	r9, r8, r10, r3
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .   .   add	r5, r7
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .   .   add	r6, r8
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .   .   sub.w	r7, r5, r7, lsl #1
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .   .   sub.w	r8, r6, r8, lsl #1
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .   .   smull	r9, r6, r6, r12
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .   .   mul	r10, r9, r2
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .   .   smlal	r9, r6, r10, r3
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .   .   smull	r9, r8, r8, lr
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .   .   mul	r10, r9, r2
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .   .   smlal	r9, r8, r10, r3
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .   .   add	r5, r6
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .   .   add	r7, r8
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .   .   sub.w	r6, r5, r6, lsl #1
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.   .   sub.w	r8, r7, r8, lsl #1
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE   .   str.w	r6, [r0, #4]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE  .   str.w	r7, [r0, #8]
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE .   str.w	r8, [r0, #12]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE   str	r5, [r0], #16
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r12, [r1, #4]
        // 1.     3     0.0    0.0    0.0       ldr.w	lr, [r1, #8]
        // 2.     3     0.0    0.0    0.0       ldr	r11, [r1], #12
        // 3.     3     0.0    0.0    0.0       ldr.w	r5, [r0]
        // 4.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #4]
        // 5.     3     0.0    0.0    0.0       ldr.w	r7, [r0, #8]
        // 6.     3     0.0    0.0    0.0       ldr.w	r8, [r0, #12]
        // 7.     3     0.0    0.0    0.0       smull	r9, r7, r7, r11
        // 8.     3     0.0    0.0    0.0       mul	r10, r9, r2
        // 9.     3     0.0    0.0    0.0       smlal	r9, r7, r10, r3
        // 10.    3     0.0    0.0    0.0       smull	r9, r8, r8, r11
        // 11.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 12.    3     0.0    0.0    0.0       smlal	r9, r8, r10, r3
        // 13.    3     0.0    0.0    0.0       add	r5, r7
        // 14.    3     0.0    0.0    0.0       add	r6, r8
        // 15.    3     0.0    0.0    0.0       sub.w	r7, r5, r7, lsl #1
        // 16.    3     0.0    0.0    0.0       sub.w	r8, r6, r8, lsl #1
        // 17.    3     0.0    0.0    0.0       smull	r9, r6, r6, r12
        // 18.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 19.    3     0.0    0.0    0.0       smlal	r9, r6, r10, r3
        // 20.    3     0.0    0.0    0.0       smull	r9, r8, r8, lr
        // 21.    3     0.0    0.0    0.0       mul	r10, r9, r2
        // 22.    3     0.0    0.0    0.0       smlal	r9, r8, r10, r3
        // 23.    3     0.0    0.0    0.0       add	r5, r6
        // 24.    3     0.0    0.0    0.0       add	r7, r8
        // 25.    3     0.0    0.0    0.0       sub.w	r6, r5, r6, lsl #1
        // 26.    3     0.0    0.0    0.0       sub.w	r8, r7, r8, lsl #1
        // 27.    3     0.0    0.0    0.0       str.w	r6, [r0, #4]
        // 28.    3     0.0    0.0    0.0       str.w	r7, [r0, #8]
        // 29.    3     0.0    0.0    0.0       str.w	r8, [r0, #12]
        // 30.    3     0.0    0.0    0.0       str	r5, [r0], #16
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (ORIGINAL) END
        //
        //
        // LLVM MCA STATISTICS (OPTIMIZED) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      3100
        // Total Cycles:      2401
        // Total uOps:        3100
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.29
        // IPC:               1.29
        // Block RThroughput: 15.5
        //
        //
        // Cycles with backend pressure increase [ 49.90% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 8.29% ]
        //   Data Dependencies:      [ 41.61% ]
        //   - Register Dependencies [ 41.61% ]
        //   - Memory Dependencies   [ 0.00% ]
        //
        //
        // Instruction Info:
        // [1]: #uOps
        // [2]: Latency
        // [3]: RThroughput
        // [4]: MayLoad
        // [5]: MayStore
        // [6]: HasSideEffects (U)
        //
        // [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
        //  1      2     0.50    *                   ldr.w	r11, [r1, #8]
        //  1      2     0.50    *                   ldr.w	r8, [r1, #4]
        //  1      2     0.50    *                   ldr	r7, [r1], #12
        //  1      2     0.50    *                   ldr.w	r6, [r0, #12]
        //  1      2     0.50    *                   ldr.w	r5, [r0, #8]
        //  1      2     1.00                        smull	lr, r9, r6, r7
        //  1      2     1.00                        smull	r12, r6, r5, r7
        //  1      2     1.00                        mul	r5, lr, r2
        //  1      2     1.00                        mul	r7, r12, r2
        //  1      2     1.00                        smlal	lr, r9, r5, r3
        //  1      2     0.50    *                   ldr.w	r5, [r0]
        //  1      2     1.00                        smlal	r12, r6, r7, r3
        //  1      2     0.50    *                   ldr.w	lr, [r0, #4]
        //  1      1     0.50                        add	lr, r9
        //  1      2     1.00                        smull	r12, r7, lr, r8
        //  1      2     1.00                        sub.w	lr, lr, r9, lsl #1
        //  1      1     0.50                        add.w	r10, r5, r6
        //  1      2     1.00                        smull	r5, r9, lr, r11
        //  1      2     1.00                        mul	r8, r12, r2
        //  1      2     1.00                        mul	lr, r5, r2
        //  1      2     1.00                        smlal	r12, r7, r8, r3
        //  1      2     1.00                        smlal	r5, r9, lr, r3
        //  1      1     0.50                        add.w	lr, r10, r7
        //  1      2     1.00                        sub.w	r5, r10, r6, lsl #1
        //  1      2     1.00                        sub.w	r6, lr, r7, lsl #1
        //  1      3     1.00           *            str.w	r6, [r0, #4]
        //  1      1     0.50                        add.w	r6, r5, r9
        //  1      3     1.00           *            str.w	r6, [r0, #8]
        //  1      2     1.00                        sub.w	r6, r6, r9, lsl #1
        //  1      3     1.00           *            str.w	r6, [r0, #12]
        //  1      3     1.00           *            str	lr, [r0], #16
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      999  (41.6%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 199  (8.3%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              102  (4.2%)
        //  1,              1498  (62.4%)
        //  2,              801  (33.4%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          102  (4.2%)
        //  1,          1498  (62.4%)
        //  2,          801  (33.4%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    3700
        // Max number of mappings used:         5
        //
        //
        // Resources:
        // [0.0] - M7UnitALU
        // [0.1] - M7UnitALU
        // [1]   - M7UnitBranch
        // [2]   - M7UnitLoadH
        // [3]   - M7UnitLoadL
        // [4]   - M7UnitMAC
        // [5]   - M7UnitSIMD
        // [6]   - M7UnitShift1
        // [7]   - M7UnitShift2
        // [8]   - M7UnitStore
        // [9]   - M7UnitVFP
        // [10]  - M7UnitVPortH
        // [11]  - M7UnitVPortL
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]
        // 4.00   4.00    -     3.50   3.50   12.00   -     4.00    -     4.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r1, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r8, [r1, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r7, [r1], #12
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #12]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #8]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	lr, r9, r6, r7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r12, r6, r5, r7
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r5, lr, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r7, r12, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	lr, r9, r5, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0]
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r12, r6, r7, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #4]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add	lr, r9
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r12, r7, lr, r8
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	lr, lr, r9, lsl #1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r10, r5, r6
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smull	r5, r9, lr, r11
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	r8, r12, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     mul	lr, r5, r2
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r12, r7, r8, r3
        //  -      -      -      -      -     1.00    -      -      -      -      -      -      -     smlal	r5, r9, lr, r3
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     add.w	lr, r10, r7
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r5, r10, r6, lsl #1
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r6, lr, r7, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #4]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     add.w	r6, r5, r9
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #8]
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     sub.w	r6, r6, r9, lsl #1
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #12]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	lr, [r0], #16
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          012
        // Index     0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r11, [r1, #8]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r8, [r1, #4]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr	r7, [r1], #12
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r6, [r0, #12]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r5, [r0, #8]
        // [0,5]     . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    . .   smull	lr, r9, r6, r7
        // [0,6]     .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    . .   smull	r12, r6, r5, r7
        // [0,7]     .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    . .   mul	r5, lr, r2
        // [0,8]     .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    . .   mul	r7, r12, r2
        // [0,9]     .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    . .   smlal	lr, r9, r5, r3
        // [0,10]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	r5, [r0]
        // [0,11]    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    . .   smlal	r12, r6, r7, r3
        // [0,12]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    . .   ldr.w	lr, [r0, #4]
        // [0,13]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    . .   add	lr, r9
        // [0,14]    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    . .   smull	r12, r7, lr, r8
        // [0,15]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    . .   sub.w	lr, lr, r9, lsl #1
        // [0,16]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    . .   add.w	r10, r5, r6
        // [0,17]    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    . .   smull	r5, r9, lr, r11
        // [0,18]    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    . .   mul	r8, r12, r2
        // [0,19]    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    . .   mul	lr, r5, r2
        // [0,20]    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    . .   smlal	r12, r7, r8, r3
        // [0,21]    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    . .   smlal	r5, r9, lr, r3
        // [0,22]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    . .   add.w	lr, r10, r7
        // [0,23]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    . .   sub.w	r5, r10, r6, lsl #1
        // [0,24]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    . .   sub.w	r6, lr, r7, lsl #1
        // [0,25]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    . .   str.w	r6, [r0, #4]
        // [0,26]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    . .   add.w	r6, r5, r9
        // [0,27]    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    . .   str.w	r6, [r0, #8]
        // [0,28]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    . .   sub.w	r6, r6, r9, lsl #1
        // [0,29]    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    . .   str.w	r6, [r0, #12]
        // [0,30]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    . .   str	lr, [r0], #16
        // [1,0]     .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    . .   ldr.w	r11, [r1, #8]
        // [1,1]     .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    . .   ldr.w	r8, [r1, #4]
        // [1,2]     .    .    .    .    .   DE    .    .    .    .    .    .    .    .    . .   ldr	r7, [r1], #12
        // [1,3]     .    .    .    .    .    DE   .    .    .    .    .    .    .    .    . .   ldr.w	r6, [r0, #12]
        // [1,4]     .    .    .    .    .    DE   .    .    .    .    .    .    .    .    . .   ldr.w	r5, [r0, #8]
        // [1,5]     .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    . .   smull	lr, r9, r6, r7
        // [1,6]     .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    . .   smull	r12, r6, r5, r7
        // [1,7]     .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    . .   mul	r5, lr, r2
        // [1,8]     .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    . .   mul	r7, r12, r2
        // [1,9]     .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    . .   smlal	lr, r9, r5, r3
        // [1,10]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    . .   ldr.w	r5, [r0]
        // [1,11]    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    . .   smlal	r12, r6, r7, r3
        // [1,12]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    . .   ldr.w	lr, [r0, #4]
        // [1,13]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    . .   add	lr, r9
        // [1,14]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    . .   smull	r12, r7, lr, r8
        // [1,15]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    . .   sub.w	lr, lr, r9, lsl #1
        // [1,16]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    . .   add.w	r10, r5, r6
        // [1,17]    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    . .   smull	r5, r9, lr, r11
        // [1,18]    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    . .   mul	r8, r12, r2
        // [1,19]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    . .   mul	lr, r5, r2
        // [1,20]    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    . .   smlal	r12, r7, r8, r3
        // [1,21]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    . .   smlal	r5, r9, lr, r3
        // [1,22]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    . .   add.w	lr, r10, r7
        // [1,23]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    . .   sub.w	r5, r10, r6, lsl #1
        // [1,24]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    . .   sub.w	r6, lr, r7, lsl #1
        // [1,25]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    . .   str.w	r6, [r0, #4]
        // [1,26]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    . .   add.w	r6, r5, r9
        // [1,27]    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    . .   str.w	r6, [r0, #8]
        // [1,28]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    . .   sub.w	r6, r6, r9, lsl #1
        // [1,29]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    . .   str.w	r6, [r0, #12]
        // [1,30]    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    . .   str	lr, [r0], #16
        // [2,0]     .    .    .    .    .    .    .    .    .    . DE .    .    .    .    . .   ldr.w	r11, [r1, #8]
        // [2,1]     .    .    .    .    .    .    .    .    .    . DE .    .    .    .    . .   ldr.w	r8, [r1, #4]
        // [2,2]     .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    . .   ldr	r7, [r1], #12
        // [2,3]     .    .    .    .    .    .    .    .    .    .   DE    .    .    .    . .   ldr.w	r6, [r0, #12]
        // [2,4]     .    .    .    .    .    .    .    .    .    .   DE    .    .    .    . .   ldr.w	r5, [r0, #8]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    . .   smull	lr, r9, r6, r7
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    . .   smull	r12, r6, r5, r7
        // [2,7]     .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    . .   mul	r5, lr, r2
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    . .   mul	r7, r12, r2
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    . .   smlal	lr, r9, r5, r3
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    . .   ldr.w	r5, [r0]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    . .   smlal	r12, r6, r7, r3
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    . .   ldr.w	lr, [r0, #4]
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    . .   add	lr, r9
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    . .   smull	r12, r7, lr, r8
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    . .   sub.w	lr, lr, r9, lsl #1
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    . .   add.w	r10, r5, r6
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    . .   smull	r5, r9, lr, r11
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    . .   mul	r8, r12, r2
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    . .   mul	lr, r5, r2
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    . .   smlal	r12, r7, r8, r3
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   . .   smlal	r5, r9, lr, r3
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   . .   add.w	lr, r10, r7
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   . .   sub.w	r5, r10, r6, lsl #1
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  . .   sub.w	r6, lr, r7, lsl #1
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE . .   str.w	r6, [r0, #4]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE . .   add.w	r6, r5, r9
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE. .   str.w	r6, [r0, #8]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE. .   sub.w	r6, r6, r9, lsl #1
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE .   str.w	r6, [r0, #12]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE   str	lr, [r0], #16
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r11, [r1, #8]
        // 1.     3     0.0    0.0    0.0       ldr.w	r8, [r1, #4]
        // 2.     3     0.0    0.0    0.0       ldr	r7, [r1], #12
        // 3.     3     0.0    0.0    0.0       ldr.w	r6, [r0, #12]
        // 4.     3     0.0    0.0    0.0       ldr.w	r5, [r0, #8]
        // 5.     3     0.0    0.0    0.0       smull	lr, r9, r6, r7
        // 6.     3     0.0    0.0    0.0       smull	r12, r6, r5, r7
        // 7.     3     0.0    0.0    0.0       mul	r5, lr, r2
        // 8.     3     0.0    0.0    0.0       mul	r7, r12, r2
        // 9.     3     0.0    0.0    0.0       smlal	lr, r9, r5, r3
        // 10.    3     0.0    0.0    0.0       ldr.w	r5, [r0]
        // 11.    3     0.0    0.0    0.0       smlal	r12, r6, r7, r3
        // 12.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #4]
        // 13.    3     0.0    0.0    0.0       add	lr, r9
        // 14.    3     0.0    0.0    0.0       smull	r12, r7, lr, r8
        // 15.    3     0.0    0.0    0.0       sub.w	lr, lr, r9, lsl #1
        // 16.    3     0.0    0.0    0.0       add.w	r10, r5, r6
        // 17.    3     0.0    0.0    0.0       smull	r5, r9, lr, r11
        // 18.    3     0.0    0.0    0.0       mul	r8, r12, r2
        // 19.    3     0.0    0.0    0.0       mul	lr, r5, r2
        // 20.    3     0.0    0.0    0.0       smlal	r12, r7, r8, r3
        // 21.    3     0.0    0.0    0.0       smlal	r5, r9, lr, r3
        // 22.    3     0.0    0.0    0.0       add.w	lr, r10, r7
        // 23.    3     0.0    0.0    0.0       sub.w	r5, r10, r6, lsl #1
        // 24.    3     0.0    0.0    0.0       sub.w	r6, lr, r7, lsl #1
        // 25.    3     0.0    0.0    0.0       str.w	r6, [r0, #4]
        // 26.    3     0.0    0.0    0.0       add.w	r6, r5, r9
        // 27.    3     0.0    0.0    0.0       str.w	r6, [r0, #8]
        // 28.    3     0.0    0.0    0.0       sub.w	r6, r6, r9, lsl #1
        // 29.    3     0.0    0.0    0.0       str.w	r6, [r0, #12]
        // 30.    3     0.0    0.0    0.0       str	lr, [r0], #16
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        cmp cntr, ptr_p
        bne layer78_loop

    // restore registers
    pop {R4-R11, PC}

    // unbind aliases
    .unreq ptr_p
    .unreq ptr_zeta
    .unreq qinv
    .unreq q
    .unreq cntr
    .unreq pol0
    .unreq pol1
    .unreq pol2
    .unreq pol3
    .unreq temp_h
    .unreq temp_l
    .unreq zeta0
    .unreq zeta1
    .unreq zeta2

.align 2
inv_ntt_asm_smull_qinv:
.word 0xfc7fdfff
.align 2
inv_ntt_asm_smull_q:
.word 8380417

.section .rodata

.type zetas_new332, %object
.align 2
zetas_new332:
.word 25847, -2608894, -518909, 237124, -777960, -876248, 466468, 1826347, 2725464, 1024112, 2706023, 95776, 3077325, 3530437, 2353451, -1079900, 3585928, -1661693, -3592148, -2537516, 3915439, -359251, -549488, -1119584, -3861115, -3043716, 3574422, -2867647, -2091905, 2619752, -2108549, 3539968, -300467, 2348700, -539299, 3119733, -2118186, -3859737, -1699267, -1643818, 3505694, -3821735, -2884855, -1399561, -3277672, 3507263, -2140649, -1600420, 3699596, 3111497, 1757237, -19422, 811944, 531354, 954230, 3881043, 2680103, 4010497, 280005, 3900724, -2556880, 2071892, -2797779, -3930395, 2091667, 3407706, -1528703, 2316500, 3817976, -3677745, -3342478, 2244091, -3041255, -2446433, -3562462, -1452451, 266997, 2434439, 3475950, -1235728, 3513181, 2176455, -3520352, -3759364, -1585221, -1197226, -3193378, -1257611, 900702, 1859098, 1939314, 909542, 819034, -4083598, 495491, -1613174, -1000202, -43260, -522500, -3190144, -655327, -3122442, -3157330, 2031748, 3207046, -3632928, -3556995, -525098, 126922, -768622, -3595838, 3412210, 342297, 286988, -983419, -2437823, 4108315, 2147896, 3437287, -3342277, 2715295, 1735879, 203044, -2967645, 2842341, 2691481, -3693493, -2590150, 1265009, -411027, 4055324, 1247620, -2477047, 2486353, 1595974, -671102, -3767016, 1250494, -1228525, 2635921, -3548272, -22981, -2994039, 1869119, -1308169, 1903435, -1050970, -381987, -1333058, 1237275, 1349076, -3318210, -1430225, 1852771, -451100, 1312455, -1430430, 3306115, -1962642, -3343383, -1279661, 1917081, 264944, -2546312, -1374803, 508951, 1500165, 777191, 3097992, 2235880, 3406031, 44288, -542412, -2831860, -1100098, -1671176, -1846953, 904516, -2584293, -3724270, 3958618, 594136, -3776993, -3724342, -2013608, 2432395, -8578, 2454455, -164721, 1653064, 1957272, 3369112, -3249728, 185531, -1207385, 2389356, -3183426, 162844, -210977, 1616392, 3014001, 759969, 810149, 1652634, -1316856, -3694233, -1799107, 189548, -3038916, 3523897, -3553272, 3866901, 269760, 3159746, 2213111, -975884, -1851402, 1717735, 472078, -2409325, -426683, 1723600, -177440, -1803090, 1910376, 1315589, -1667432, -1104333, 1341330, -260646, -3833893, 1285669, -2939036, -2235985, -1584928, -420899, -2286327, -812732, 183443, -976891, -1439742, 1612842, -3545687, -3019102, -554416, 3919660, -3881060, -48306, -1362209, -3628969, 3937738, 1400424, 3839961, -846154, 1976782
.size zetas_new332,.-zetas_new332

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

    smull \c0, \c5, \c1, \tmp
    smlal \c0, \c5, \c3, \tmp2
    mul \twiddle, \c0, \Qprime
    smlal \c0, \c5, \twiddle, \Q

    smull \c2, \c7, \c1, \tmp2
    smlal \c2, \c7, \c3, \tmp
    mul \twiddle, \c2, \Qprime
    smlal \c2, \c7, \twiddle, \Q
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

//void pqcrystals_dilithium_ntt(int32_t p[N]);
.global pqcrystals_dilithium_ntt
#ifndef __CLANG__
.type pqcrystals_dilithium_ntt,%function
#endif
.align 2
pqcrystals_dilithium_ntt:
  //bind aliases
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

  //preserve registers
  push {R4-R11, R14}
  
  //load constants, ptr
  ldr.w qinv, inv_ntt_asm_smull_qinv  //-qinv_signed
  ldr.w q, inv_ntt_asm_smull_q

  //stage 1 - 3
  .equ distance, 512
  .equ strincr, 4
  
  ldr.w ptr_zeta, =zetas_new332
  vldm ptr_zeta!, {s2-s8} 
  vmov s0, ptr_zeta
  
  add.w temp_l, ptr_p, #32*strincr // 32 iterations
  vmov s9, temp_l
  layer123_loop:
    ldr.w pol0, [ptr_p]
    ldr.w pol1, [ptr_p, #1*distance/4]
    ldr.w pol2, [ptr_p, #2*distance/4]
    ldr.w pol3, [ptr_p, #3*distance/4]
    ldr.w pol4, [ptr_p, #4*distance/4]
    ldr.w pol5, [ptr_p, #5*distance/4]
    ldr.w pol6, [ptr_p, #6*distance/4]
    ldr.w pol7, [ptr_p, #7*distance/4]

    _3_layer_CT_32 pol0, pol1, pol2, pol3, pol4, pol5, pol6, pol7, s2, s3, s4, s5, s6, s7, s8, zeta, qinv, q, temp_h, temp_l

    str.w pol1, [ptr_p, #1*distance/4]
    str.w pol2, [ptr_p, #2*distance/4]
    str.w pol3, [ptr_p, #3*distance/4]
    str.w pol4, [ptr_p, #4*distance/4]
    str.w pol5, [ptr_p, #5*distance/4]
    str.w pol6, [ptr_p, #6*distance/4]
    str.w pol7, [ptr_p, #7*distance/4]
    str pol0, [ptr_p], #strincr // @slothy:core=True // @slothy:before=cmp
    vmov temp_l, s9

    cmp.w ptr_p, temp_l // @slothy:id=cmp
    bne layer123_loop
  
  sub ptr_p, #32*4

  // stage 4 - 6  
  .equ distance2, 64
  add.w temp_l, ptr_p, #8*112+8*4*4 // 8 iterations
  vmov s9, temp_l
  1:
    add.w temp_l, ptr_p, #4*strincr // 4 iterations
    vmov s10, temp_l
    vmov ptr_zeta, s0
    vldm ptr_zeta!, {s2-s8}
    vmov s0, ptr_zeta
    layer456_loop:
      ldr.w pol0, [ptr_p]
      ldr.w pol1, [ptr_p, #1*distance2/4]
      ldr.w pol2, [ptr_p, #2*distance2/4]
      ldr.w pol3, [ptr_p, #3*distance2/4]
      ldr.w pol4, [ptr_p, #4*distance2/4]
      ldr.w pol5, [ptr_p, #5*distance2/4]
      ldr.w pol6, [ptr_p, #6*distance2/4]
      ldr.w pol7, [ptr_p, #7*distance2/4]

      _3_layer_CT_32 pol0, pol1, pol2, pol3, pol4, pol5, pol6, pol7, s2, s3, s4, s5, s6, s7, s8, zeta, qinv, q, temp_h, temp_l
      
      str.w pol1, [ptr_p, #1*distance2/4]
      str.w pol2, [ptr_p, #2*distance2/4]
      str.w pol3, [ptr_p, #3*distance2/4]
      str.w pol4, [ptr_p, #4*distance2/4]
      str.w pol5, [ptr_p, #5*distance2/4]
      str.w pol6, [ptr_p, #6*distance2/4]
      str.w pol7, [ptr_p, #7*distance2/4]
      str pol0, [ptr_p], #4 // @slothy:core=True // @slothy:before=cmp
      vmov temp_l, s10
      cmp.w ptr_p, temp_l // @slothy:id=cmp
      bne layer456_loop

    add.w ptr_p, #112
    vmov temp_l, s9
    cmp.w ptr_p, temp_l
    bne 1b
  
    sub ptr_p, #4*4*8+112*8
    vmov ptr_zeta, s0
    //stage 7 and 8
    add cntr, ptr_p, #1024 // 64 iterations

    layer78_loop:
      ldr.w zeta1, [ptr_zeta, #4]  //z128,..., z254
      ldr.w zeta2, [ptr_zeta, #8]  //z129,..., z255
      ldr zeta0, [ptr_zeta], #12  //z64, ..., z127
      ldr.w pol0, [ptr_p]  //1*4
      ldr.w pol1, [ptr_p, #4]
      ldr.w pol2, [ptr_p, #8]
      ldr.w pol3, [ptr_p, #12] 

      _2_layer_CT_32 pol0, pol1, pol2, pol3, zeta0, zeta1, zeta2, qinv, q, temp_h, temp_l

      str.w pol1, [ptr_p, #4]
      str.w pol2, [ptr_p, #8]
      str.w pol3, [ptr_p, #12]
      str pol0, [ptr_p], #16 // @slothy:core=True // @slothy:before=cmp
      cmp.w ptr_p, cntr // @slothy:id=cmp
      bne.w layer78_loop

    //restore registers
    pop {R4-R11, PC}

    //unbind aliases
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

.size pqcrystals_dilithium_ntt, .-pqcrystals_dilithium_ntt

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

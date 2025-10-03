
///
/// Copyright (c) 2025 Arm Limited
/// SPDX-License-Identifier: Apache-2.0 OR MIT OR ISC
///

.thumb
.syntax unified
.text
.equ QSTACK0, 0
.equ A__00, 0
.equ A__01, 80
.equ A__02, 160
.equ A__03, 240
.equ A__04, 320
.equ A__10, 16
.equ A__11, 96
.equ A__12, 176
.equ A__13, 256
.equ A__14, 336
.equ A__20, 32
.equ A__21, 112
.equ A__22, 192
.equ A__23, 272
.equ A__24, 352
.equ A__30, 48
.equ A__31, 128
.equ A__32, 208
.equ A__33, 288
.equ A__34, 368
.equ A__40, 64
.equ A__41, 144
.equ A__42, 224
.equ A__43, 304
.equ A__44, 384
.equ B__00, 0
.equ B__01, 256
.equ B__02, 112
.equ B__03, 368
.equ B__04, 224
.equ B__10, 160
.equ B__11, 16
.equ B__12, 272
.equ B__13, 128
.equ B__14, 384
.equ B__20, 320
.equ B__21, 176
.equ B__22, 32
.equ B__23, 288
.equ B__24, 144
.equ B__30, 80
.equ B__31, 336
.equ B__32, 192
.equ B__33, 48
.equ B__34, 304
.equ B__40, 240
.equ B__41, 96
.equ B__42, 352
.equ B__43, 208
.equ B__44, 64
.equ RCxy_00, 0
.equ RCxy_01, 36
.equ RCxy_02, 3
.equ RCxy_03, 41
.equ RCxy_04, 18
.equ RCxy_10, 1
.equ RCxy_11, 44
.equ RCxy_12, 10
.equ RCxy_13, 45
.equ RCxy_14, 2
.equ RCxy_20, 62
.equ RCxy_21, 6
.equ RCxy_22, 43
.equ RCxy_23, 15
.equ RCxy_24, 61
.equ RCxy_30, 28
.equ RCxy_31, 55
.equ RCxy_32, 25
.equ RCxy_33, 21
.equ RCxy_34, 56
.equ RCxy_40, 27
.equ RCxy_41, 20
.equ RCxy_42, 39
.equ RCxy_43, 8
.equ RCxy_44, 14
.equ RC0_l, 0x1
.equ RC0_h, 0x0
.equ RC1_l, 0x0
.equ RC1_h, 0x89
.equ RC2_l, 0x0
.equ RC2_h, 0x8000008b
.equ RC3_l, 0x0
.equ RC3_h, 0x80008080
.equ RC4_l, 0x1
.equ RC4_h, 0x8b
.equ RC5_l, 0x1
.equ RC5_h, 0x8000
.equ RC6_l, 0x1
.equ RC6_h, 0x80008088
.equ RC7_l, 0x1
.equ RC7_h, 0x80000082
.equ RC8_l, 0x0
.equ RC8_h, 0xb
.equ RC9_l, 0x0
.equ RC9_h, 0xa
.equ RC10_l, 0x1
.equ RC10_h, 0x8082
.equ RC11_l, 0x0
.equ RC11_h, 0x8003
.equ RC12_l, 0x1
.equ RC12_h, 0x808b
.equ RC13_l, 0x1
.equ RC13_h, 0x8000000b
.equ RC14_l, 0x1
.equ RC14_h, 0x8000008a
.equ RC15_l, 0x1
.equ RC15_h, 0x80000081
.equ RC16_l, 0x0
.equ RC16_h, 0x80000081
.equ RC17_l, 0x0
.equ RC17_h, 0x80000008
.equ RC18_l, 0x0
.equ RC18_h, 0x83
.equ RC19_l, 0x0
.equ RC19_h, 0x80008003
.equ RC20_l, 0x1
.equ RC20_h, 0x80008088
.equ RC21_l, 0x0
.equ RC21_h, 0x80000088
.equ RC22_l, 0x1
.equ RC22_h, 0x8000
.equ RC23_l, 0x0
.equ RC23_h, 0x80008082

qA00_h .req q0
qA00_l .req q1
qA20_l .req q2

.macro ld_xor5 state, round, x, C, A
    vldrw.u32 q<\C>, [\state, #A__\x\()0] // @slothy:reads=A\state\()__\x\()0
    vldrw.u32 q<\A>, [\state, #A__\x\()1] // @slothy:reads=A\state\()__\x\()1
    veor  q<\C>, q<\C>, q<\A>
    vldrw.u32 q<\A>, [\state, #A__\x\()2] // @slothy:reads=A\state\()__\x\()2
    veor  q<\C>, q<\C>, q<\A>
    vldrw.u32 q<\A>, [\state, #A__\x\()3] // @slothy:reads=A\state\()__\x\()3
    veor  q<\C>, q<\C>, q<\A>
    vldrw.u32 q<\A>, [\state, #A__\x\()4] // @slothy:reads=A\state\()__\x\()4
    veor  q<\C>, q<\C>, q<\A>
    .endm

.macro ld_xor5_0 state, round, x, C, A, A0
    vldrw.u32 q<\C>, [\state, #A__\x\()1] // @slothy:reads=A\state\()__\x\()1
    veor  q<\C>, q<\C>, q<\A0>
    vldrw.u32 q<\A>, [\state, #A__\x\()2] // @slothy:reads=A\state\()__\x\()2
    veor  q<\C>, q<\C>, q<\A>
    vldrw.u32 q<\A>, [\state, #A__\x\()3] // @slothy:reads=A\state\()__\x\()3
    veor  q<\C>, q<\C>, q<\A>
    vldrw.u32 q<\A>, [\state, #A__\x\()4] // @slothy:reads=A\state\()__\x\()4
    veor  q<\C>, q<\C>, q<\A>
    .endm


.macro rot1_xor_l D1_l, C0_l, C2_h
    vshr.u32 q<\D1_l>, q<\C2_h>, #31
    vsli.32  q<\D1_l>, q<\C2_h>, #1
    veor     q<\D1_l>, q<\D1_l>, q<\C0_l>
    .endm

.macro rot1_xor_h D1_h, C0_h, C2_l
    veor     q<\D1_h>, q<\C2_l>, q<\C0_h>
    .endm

.macro rot_str_e s_l, s_h, A_l, A_h, RC, x, y
    vshr.u32 q<SHR_l>, q<A_l>, #32-(\RC/2)
    vsli.u32 q<SHR_l>, q<A_l>, #\RC/2
    vstrw.32 q<SHR_l>, [\s_l, #B__\x\()\y]
    vshr.u32 q<SHR_h>, q<A_h>, #32-(\RC/2)
    vsli.u32 q<SHR_h>, q<A_h>, #\RC/2
    vstrw.32 q<SHR_h>, [\s_h, #B__\x\()\y]
.endm

.macro rot_str_o  s_l, s_h, A_l, A_h, RC, x, y
    .if (\RC-1)/2 == 0
        vstrw.32 q<A_l>, [\s_h, #B__\x\()\y]
    .else
        vshr.u32 q<SHR_h>, q<A_l>, #32-((\RC-1)/2)
        vsli.u32 q<SHR_h>, q<A_l>, #(\RC-1)/2
        vstrw.32 q<SHR_h>, [\s_h, #B__\x\()\y]
    .endif

    .if (\RC+1)/2 == 0
        // should never happen
        vstrw.32 q<A_h>, [\s_l, #B__\x\()\y]
    .else
        vshr.u32 q<SHR_l>, q<A_h>, #32-((\RC+1)/2)
        vsli.u32 q<SHR_l>, q<A_h>, #(\RC+1)/2
        vstrw.32 q<SHR_l>, [\s_l, #B__\x\()\y]
    .endif
.endm

.macro ld_xorD_rot_str_e state_l, state_h, state_nl, state_nh, x, y, Dx_l, Dx_h
    vldrw.u32 q<A_l>, [\state_l, #A__\x\()\y] // @slothy:reads=A\state_l\()__\x\()\y
    vldrw.u32 q<A_h>, [\state_h, #A__\x\()\y] // @slothy:reads=A\state_h\()__\x\()\y
    veor q<A_l>, q<A_l>, q<\Dx_l>
    veor q<A_h>, q<A_h>, q<\Dx_h>
    rot_str_e \state_nl, \state_nh, A_l, A_h, RCxy_\x\()\y, \x, \y
.endm

.macro rot_str_e_0 s_l, s_h, A_l, A_h, RC, x, y, regl, regh
    vshr.u32 q<\regl>, q<A_l>, #32-(\RC/2)
    vsli.u32 q<\regl>, q<A_l>, #\RC/2
    //vstrw.32 q<SHR_l>, [\s_l, #B__\x\()\y]
    vshr.u32 q<\regh>, q<A_h>, #32-(\RC/2)
    vsli.u32 q<\regh>, q<A_h>, #\RC/2
    //vstrw.32 q<SHR_h>, [\s_h, #B__\x\()\y]
.endm

.macro ld_xorD_rot_str_e_0 state_l, state_h, state_nl, state_nh, x, y, Dx_l, Dx_h, regl, regh
    vldrw.u32 q<A_l>, [\state_l, #A__\x\()\y] // @slothy:reads=A\state_l\()__\x\()\y
    vldrw.u32 q<A_h>, [\state_h, #A__\x\()\y] // @slothy:reads=A\state_h\()__\x\()\y
    veor q<A_l>, q<A_l>, q<\Dx_l>
    veor q<A_h>, q<A_h>, q<\Dx_h>
    rot_str_e_0 \state_nl, \state_nh, A_l, A_h, RCxy_\x\()\y, \x, \y, \regl, \regh
.endm

.macro ld_xorD_rot_str_o state_l, state_h, state_nl, state_nh, x, y, Dx_l, Dx_h
    vldrw.u32 q<A_l>, [\state_l, #A__\x\()\y] // @slothy:reads=A\state_l\()__\x\()\y
    vldrw.u32 q<A_h>, [\state_h, #A__\x\()\y] // @slothy:reads=A\state_h\()__\x\()\y
    veor q<A_l>, q<A_l>, q<\Dx_l>
    veor q<A_h>, q<A_h>, q<\Dx_h>
    rot_str_o \state_nl, \state_nh, A_l, A_h, RCxy_\x\()\y, \x, \y
.endm

.macro ld_bic_str state, state_n, round, y
    vldrw.u32 q<B0>, [\state_n, #A__0\y] // @slothy:reads=A\state_n\()__0\y
    vldrw.u32 q<B1>, [\state_n, #A__1\y] // @slothy:reads=A\state_n\()__1\y
    vldrw.u32 q<B2>, [\state_n, #A__2\y] // @slothy:reads=A\state_n\()__2\y
    vbic q<T0>, q<B2>, q<B1>
    veor q<A0>, q<B0>, q<T0>
    vstrw.32 q<A0>, [\state, #A__0\y]  // @slothy:writes=A\state\()__0\y
    vldrw.u32 q<B3>, [\state_n, #A__3\y] // @slothy:reads=A\state_n\()__3\y
    vbic q<T1>, q<B3>, q<B2>
    veor q<A1>, q<B1>, q<T1>
    vstrw.32 q<A1>, [\state, #A__1\y]  // @slothy:writes=A\state\()__1\y
    vldrw.u32 q<B4>, [\state_n, #A__4\y] // @slothy:reads=A\state_n\()__4\y
    vbic q<T2>, q<B4>, q<B3>
    veor q<A2>, q<B2>, q<T2>
    vstrw.32 q<A2>, [\state, #A__2\y]  // @slothy:writes=A\state\()__2\y
    vbic q<T3>, q<B0>, q<B4>
    veor q<A3>, q<B3>, q<T3>
    vstrw.32 q<A3>, [\state, #A__3\y]  // @slothy:writes=A\state\()__3\y
    vbic q<T4>, q<B1>, q<B0>
    veor q<A4>, q<B4>, q<T4>
    vstrw.32 q<A4>, [\state, #A__4\y]  // @slothy:writes=A\state\()__4\y
.endm

.macro ld_bic_str_0 state, state_n round, y, A0
    vldrw.u32 q<B1>, [\state_n, #A__1\y] // @slothy:reads=A\state_n\()__1\y
    vldrw.u32 q<B2>, [\state_n, #A__2\y] // @slothy:reads=A\state_n\()__2\y
    vldrw.u32 q<B3>, [\state_n, #A__3\y] // @slothy:reads=A\state_n\()__3\y
    vbic q<T1>, q<B3>, q<B2>
    veor q<A1>, q<B1>, q<T1>
    vstrw.32 q<A1>, [\state, #A__1\y]  // @slothy:writes=A\state\()__1\y
    vldrw.u32 q<B4>, [\state_n, #A__4\y] // @slothy:reads=A\state_n\()__4\y
    vbic q<T2>, q<B4>, q<B3>
    veor q<A2>, q<B2>, q<T2>
    vstrw.32 q<A2>, [\state, #A__2\y]  // @slothy:writes=A\state\()__2\y
    vldrw.u32 q<B0>, [\state_n, #A__0\y] // @slothy:reads=A\state_n\()__0\y
    vbic q<T3>, q<B0>, q<B4>
    veor q<A3>, q<B3>, q<T3>
    vstrw.32 q<A3>, [\state, #A__3\y]  // @slothy:writes=A\state\()__3\y
    vbic q<T4>, q<B1>, q<B0>
    veor q<A4>, q<B4>, q<T4>
    vstrw.32 q<A4>, [\state, #A__4\y]  // @slothy:writes=A\state\()__4\y
    vbic q<T0>, q<B2>, q<B1>
    veor q<\A0>, q<B0>, q<T0>
    // A0 is stored later after the round-constant is added
.endm

.macro ld_bic_str_1 state, state_n, round, y, A0, A2
    vldrw.u32 q<B1>, [\state_n, #A__1\y] // @slothy:reads=A\state_n\()__1\y
    vldrw.u32 q<B2>, [\state_n, #A__2\y] // @slothy:reads=A\state_n\()__2\y
    vldrw.u32 q<B3>, [\state_n, #A__3\y] // @slothy:reads=A\state_n\()__3\y
    vbic q<T1>, q<B3>, q<B2>
    veor q<A1>, q<B1>, q<T1>
    vstrw.32 q<A1>, [\state, #A__1\y]  // @slothy:writes=A\state\()__1\y
    vldrw.u32 q<B4>, [\state_n, #A__4\y] // @slothy:reads=A\state_n\()__4\y
    vbic q<T2>, q<B4>, q<B3>
    veor q<\A2>, q<B2>, q<T2>
    vstrw.32 q<\A2>, [\state, #A__2\y]  // @slothy:writes=A\state\()__2\y
    vldrw.u32 q<B0>, [\state_n, #A__0\y] // @slothy:reads=A\state_n\()__0\y
    vbic q<T3>, q<B0>, q<B4>
    veor q<A3>, q<B3>, q<T3>
    vstrw.32 q<A3>, [\state, #A__3\y]  // @slothy:writes=A\state\()__3\y
    vbic q<T4>, q<B1>, q<B0>
    veor q<A4>, q<B4>, q<T4>
    vstrw.32 q<A4>, [\state, #A__4\y]  // @slothy:writes=A\state\()__4\y
    vbic q<T0>, q<B2>, q<B1>
    veor q<\A0>, q<B0>, q<T0>
    // A0 is stored later after the round-constant is added
.endm

.macro ld_1_bic_str state, state_n, round, y, B1
    vldrw.u32 q<B0>, [\state_n, #A__0\y] // @slothy:reads=A\state_n\()__0\y
    //vldrw.u32 q<B1>, [\state_n, #A__1\y] // @slothy:reads=A\state_n\()__1\y
    vldrw.u32 q<B2>, [\state_n, #A__2\y] // @slothy:reads=A\state_n\()__2\y
    vbic q<T0>, q<B2>, q<\B1>
    veor q<A0>, q<B0>, q<T0>
    vstrw.32 q<A0>, [\state, #A__0\y]  // @slothy:writes=A\state\()__0\y
    vldrw.u32 q<B3>, [\state_n, #A__3\y] // @slothy:reads=A\state_n\()__3\y
    vbic q<T1>, q<B3>, q<B2>
    veor q<A1>, q<\B1>, q<T1>
    vstrw.32 q<A1>, [\state, #A__1\y]  // @slothy:writes=A\state\()__1\y
    vldrw.u32 q<B4>, [\state_n, #A__4\y] // @slothy:reads=A\state_n\()__4\y
    vbic q<T2>, q<B4>, q<B3>
    veor q<A2>, q<B2>, q<T2>
    vstrw.32 q<A2>, [\state, #A__2\y]  // @slothy:writes=A\state\()__2\y
    vbic q<T3>, q<B0>, q<B4>
    veor q<A3>, q<B3>, q<T3>
    vstrw.32 q<A3>, [\state, #A__3\y]  // @slothy:writes=A\state\()__3\y
    vbic q<T4>, q<\B1>, q<B0>
    veor q<A4>, q<B4>, q<T4>
    vstrw.32 q<A4>, [\state, #A__4\y]  // @slothy:writes=A\state\()__4\y
.endm

.macro ld_3_bic_str state, state_n, round, y, B3
    vldrw.u32 q<B0>, [\state_n, #A__0\y] // @slothy:reads=A\state_n\()__0\y
    vldrw.u32 q<B1>, [\state_n, #A__1\y] // @slothy:reads=A\state_n\()__1\y
    vldrw.u32 q<B2>, [\state_n, #A__2\y] // @slothy:reads=A\state_n\()__2\y
    vbic q<T0>, q<B2>, q<B1>
    veor q<A0>, q<B0>, q<T0>
    vstrw.32 q<A0>, [\state, #A__0\y]  // @slothy:writes=A\state\()__0\y
    //vldrw.u32 q<B3>, [\state_n, #A__3\y] // @slothy:reads=A\state_n\()__3\y
    vbic q<T1>, q<\B3>, q<B2>
    veor q<A1>, q<B1>, q<T1>
    vstrw.32 q<A1>, [\state, #A__1\y]  // @slothy:writes=A\state\()__1\y
    vldrw.u32 q<B4>, [\state_n, #A__4\y] // @slothy:reads=A\state_n\()__4\y
    vbic q<T2>, q<B4>, q<\B3>
    veor q<A2>, q<B2>, q<T2>
    vstrw.32 q<A2>, [\state, #A__2\y]  // @slothy:writes=A\state\()__2\y
    vbic q<T3>, q<B0>, q<B4>
    veor q<A3>, q<\B3>, q<T3>
    vstrw.32 q<A3>, [\state, #A__3\y]  // @slothy:writes=A\state\()__3\y
    vbic q<T4>, q<B1>, q<B0>
    veor q<A4>, q<B4>, q<T4>
    vstrw.32 q<A4>, [\state, #A__4\y]  // @slothy:writes=A\state\()__4\y
.endm



.macro keccak_4fold_round_theta_rho_pi state_l, state_h, state_nl, state_nh, rc
    ld_xor5_0 \state_h, 0, 0, C0_h, A0_h, qA00_h
    ld_xor5_0 \state_l, 0, 2, C2_l, A2_l, qA20_l
    rot1_xor_h D1_h, C0_h, C2_l
    vstrw.32 q<C0_h>, [r13, #QSTACK0] // @slothy:writes=stack0

    ld_xor5_0 \state_l, 0, 0, C0_l, A0_l, qA00_l
    ld_xor5 \state_h, 0, 2, C2_h, A2_h
    rot1_xor_l D1_l, C0_l, C2_h

    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 1, 0, D1_l, D1_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 1, 1, D1_l, D1_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 1, 2, D1_l, D1_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 1, 3, D1_l, D1_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 1, 4, D1_l, D1_h

    ld_xor5 \state_h, 0, 4, C4_h, A4_h
    rot1_xor_l D3_l, C2_l, C4_h

    ld_xor5 \state_l, 0, 4, C4_l, A4_l
    rot1_xor_h D3_h, C2_h, C4_l

    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 3, 0, D3_l, D3_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 3, 1, D3_l, D3_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 3, 2, D3_l, D3_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 3, 3, D3_l, D3_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 3, 4, D3_l, D3_h

    ld_xor5 \state_h, 0, 1, C1_h, A1_h
    rot1_xor_l D0_l, C4_l, C1_h
    ld_xor5 \state_l, 0, 1, C1_l, A1_l
    rot1_xor_h D0_h, C4_h, C1_l

    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 0, 0, D0_l, D0_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 0, 1, D0_l, D0_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 0, 2, D0_l, D0_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 0, 3, D0_l, D0_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 0, 4, D0_l, D0_h

    ld_xor5 \state_l, 0, 3, C3_l, A3_l
    rot1_xor_h D2_h, C1_h, C3_l
    ld_xor5 \state_h, 0, 3, C3_h, A3_h
    rot1_xor_l D2_l, C1_l, C3_h

    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 2, 0, D2_l, D2_h
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 2, 1, D2_l, D2_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 2, 2, D2_l, D2_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 2, 3, D2_l, D2_h
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 2, 4, D2_l, D2_h

    rot1_xor_h D4_h, C3_h, C0_l
    vldrw.32 q<C0_h>, [r13, #QSTACK0] // @slothy:reads=stack0
    rot1_xor_l D4_l, C3_l, C0_h


    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 4, 0, D4_l, D4_h // B40 = A03
    ld_xorD_rot_str_o \state_l, \state_h, \state_nl, \state_nh, 4, 2, D4_l, D4_h // B42 = A24
    ld_xorD_rot_str_e \state_l, \state_h, \state_nl, \state_nh, 4, 4, D4_l, D4_h // B44 = A40
    // A11_l, A11_h, A32_l are held in registers from the next step
    ld_xorD_rot_str_e_0 \state_l, \state_h, \state_nl, \state_nh, 4, 3, D4_l, D4_h, A32_l, A32_h // B43 = A32 
    vstrw.32 q<A32_h>, [\state_nh, #B__43]
    ld_xorD_rot_str_e_0 \state_l, \state_h, \state_nl, \state_nh, 4, 1, D4_l, D4_h, A11_l, A11_h // B41 = A11
.endm

.macro keccak_4fold_round_chi_iota state_l, state_h, state_nl, state_nh, rc    // now BIC
    // A11_l, A11_h, A32_l are held in registers from the previous step
    ld_1_bic_str \state_l, \state_nl, 0, 1, A11_l
    ld_1_bic_str \state_h, \state_nh, 0, 1, A11_h

    ld_3_bic_str \state_l, \state_nl, 0, 2, A32_l
    ld_bic_str \state_h, \state_nh, 0, 2

    ld_bic_str \state_l, \state_nl, 0, 3
    ld_bic_str \state_h, \state_nh, 0, 3

    ld_bic_str \state_l, \state_nl, 0, 4
    ld_bic_str \state_h, \state_nh, 0, 4

    ld_bic_str_1 \state_l, \state_nl, 0, 0, A00_l, qA20_l
    ld_bic_str_0 \state_h, \state_nh, 0, 0, A00_h
    

    ldrd r<grc_l>, r<grc_h>, [\rc]
    vdup.32 q<vrc_l>, r<grc_l>
    veor qA00_l, q<A00_l>, q<vrc_l>
    vstrw.32 qA00_l, [\state_l, #A__00] // @slothy:writes=A\state_l\()__00
    vdup.32 q<vrc_h>, r<grc_h>
    veor qA00_h, q<A00_h>, q<vrc_h>
    vstrw.32 qA00_h, [\state_h, #A__00] // @slothy:writes=A\state_h\()__00
.endm

.text
RC_table:
    .word RC0_l,  RC0_h
    .word RC1_l,  RC1_h
    .word RC2_l,  RC2_h
    .word RC3_l,  RC3_h
    .word RC4_l,  RC4_h
    .word RC5_l,  RC5_h
    .word RC6_l,  RC6_h
    .word RC7_l,  RC7_h
    .word RC8_l,  RC8_h
    .word RC9_l,  RC9_h
    .word RC10_l, RC10_h
    .word RC11_l, RC11_h
    .word RC12_l, RC12_h
    .word RC13_l, RC13_h
    .word RC14_l, RC14_h
    .word RC15_l, RC15_h
    .word RC16_l, RC16_h
    .word RC17_l, RC17_h
    .word RC18_l, RC18_h
    .word RC19_l, RC19_h
    .word RC20_l, RC20_h
    .word RC21_l, RC21_h
    .word RC22_l, RC22_h
    .word RC23_l, RC23_h

.align 8
.type mve_keccak_state_permute_4fold, %function
.global mve_keccak_state_permute_4fold
mve_keccak_state_permute_4fold:

    push {r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
    vpush {d8-d15}
    sub sp, #8*16

    adr r6, RC_table

    // r0: state 0
    // r1: state 1
    // r2: this state low
    // r3: this state high
    // r4: next state low
    // r5: next state high
    // r6: rc table


    mov lr, #24

    mov r2, r0
    mov r4, r1

    // pre-fetch so we can keep in registers between rounds
    add r3, r2, #400
    vldrw.u32 qA00_h, [r3, #A__00]
    vldrw.u32 qA00_l, [r2, #A__00]
    vldrw.u32 qA20_l, [r2, #A__20]

    wls lr, lr, roundend
roundstart:
    add r3, r2, #400
    add r5, r4, #400
    keccak_4fold_round_theta_rho_pi r2, r3, r4, r5, r6
    keccak_4fold_round_chi_iota r2, r3, r4, r5, r6

    add r6, r6, #8
roundend_pre:
    le lr, roundstart
roundend:
    add sp, #8*16

    vpop {d8-d15}
    ldmia.w sp!, {r3,r4,r5,r6,r7,r8,r9,r10,r11,r12, pc}
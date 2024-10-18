/******************************************************************************
* Integrating the improved Plantard arithmetic into Kyber.
*
* Efficient Plantard arithmetic enables a faster Kyber implementation with the
* same stack usage.
*
* See the paper at https://eprint.iacr.org/2022/956.pdf for more details.
*
* //author   Junhao Huang, BNU-HKBU United International College, Zhuhai, China
*           jhhuang_nuaa//126.com
*
* //date     September 2022
******************************************************************************/
.syntax unified
.cpu cortex-m4
.thumb

.macro load a, a0, a1, a2, a3, mem0, mem1, mem2, mem3
  ldr.w \a0, [\a, \mem0]
  ldr.w \a1, [\a, \mem1]
  ldr.w \a2, [\a, \mem2]
  ldr.w \a3, [\a, \mem3]
.endm

.macro store a, a0, a1, a2, a3, mem0, mem1, mem2, mem3
  str.w \a0, [\a, \mem0]
  str.w \a1, [\a, \mem1]
  str.w \a2, [\a, \mem2]
  str.w \a3, [\a, \mem3]
.endm

.macro doubleplant a, tmp, q, qa, plantconst
	smulwb \tmp, \plantconst, \a
	smulwt \a, \plantconst, \a
	smlabt \tmp, \tmp, \q, \qa
	smlabt \a, \a, \q, \qa
	pkhtb \a, \a, \tmp, asr #16
.endm

.macro doublebarrett a, tmp, tmp2, q, barrettconst
  smulbb \tmp, \a, \barrettconst
  smultb \tmp2, \a, \barrettconst
  asr \tmp, \tmp, #26
  asr \tmp2, \tmp2, #26
  smulbb \tmp, \tmp, \q
  smulbb \tmp2, \tmp2, \q
  pkhbt \tmp, \tmp, \tmp2, lsl #16
  usub16 \a, \a, \tmp
.endm

// q locate in the top half of the register
.macro plant_red q, qa, qinv, tmp
	mul \tmp, \tmp, \qinv
	//tmp*qinv mod 2^2n/ 2^n; in high half
	smlatt \tmp, \tmp, \q, \qa
	// result in high half
.endm

.macro mul_twiddle_plant a, twiddle, tmp, q, qa
	smulwb \tmp, \twiddle, \a
	smulwt \a,   \twiddle, \a
	smlabt \tmp, \tmp, \q, \qa
	smlabt \a, \a, \q, \qa
	pkhtb \a, \a, \tmp, asr #16
.endm

.macro doublebutterfly_plant a0, a1, twiddle, tmp, q, qa
	smulwb \tmp, \twiddle, \a1
	smulwt \a1, \twiddle, \a1
	smlabt \tmp, \tmp, \q, \qa
	smlabt \a1, \a1, \q, \qa
	pkhtb \tmp, \a1, \tmp, asr #16
	usub16 \a1, \a0, \tmp
	uadd16 \a0, \a0, \tmp
.endm

.macro two_doublebutterfly_plant a0, a1, a2, a3, twiddle0, twiddle1, tmp, q, qa
	doublebutterfly_plant \a0, \a1, \twiddle0, \tmp, \q, \qa
	doublebutterfly_plant \a2, \a3, \twiddle1, \tmp, \q, \qa
.endm

.macro _3_layer_double_CT_16_plant c0, c1, c2, c3, c4, c5, c6, c7, twiddle1, twiddle2, twiddle_ptr, q, qa, tmp
	// layer 3
	ldr.w \twiddle1, [\twiddle_ptr], #4
	two_doublebutterfly_plant \c0, \c4, \c1, \c5, \twiddle1, \twiddle1, \tmp, \q, \qa
	two_doublebutterfly_plant \c2, \c6, \c3, \c7, \twiddle1, \twiddle1, \tmp, \q, \qa

	// layer 2
	ldrd \twiddle1, \twiddle2, [\twiddle_ptr], #8
	two_doublebutterfly_plant \c0, \c2, \c1, \c3, \twiddle1, \twiddle1, \tmp, \q, \qa

	two_doublebutterfly_plant \c4, \c6, \c5, \c7, \twiddle2, \twiddle2, \tmp, \q, \qa

	// layer 1
	ldrd \twiddle1, \twiddle2, [\twiddle_ptr], #8
	two_doublebutterfly_plant \c0, \c1, \c2, \c3, \twiddle1, \twiddle2, \tmp, \q, \qa

	ldrd \twiddle1, \twiddle2, [\twiddle_ptr], #8
	two_doublebutterfly_plant \c4, \c5, \c6, \c7, \twiddle1, \twiddle2, \tmp, \q, \qa
.endm

.macro _3_layer_double_CT_16_plant_fp c0, c1, c2, c3, c4, c5, c6, c7, xi0, xi1, xi2, xi3, xi4, xi5, xi6, twiddle1, twiddle2, q, qa, tmp
	// layer 3
	vmov \twiddle1, \xi0
	two_doublebutterfly_plant \c0, \c4, \c1, \c5, \twiddle1, \twiddle1, \tmp, \q, \qa
	two_doublebutterfly_plant \c2, \c6, \c3, \c7, \twiddle1, \twiddle1, \tmp, \q, \qa

	// layer 2
	vmov \twiddle1, \xi1
	vmov \twiddle2, \xi2
	two_doublebutterfly_plant \c0, \c2, \c1, \c3, \twiddle1, \twiddle1, \tmp, \q, \qa

	two_doublebutterfly_plant \c4, \c6, \c5, \c7, \twiddle2, \twiddle2, \tmp, \q, \qa

	// layer 1
	vmov \twiddle1, \xi3
	vmov \twiddle2, \xi4
	two_doublebutterfly_plant \c0, \c1, \c2, \c3, \twiddle1, \twiddle2, \tmp, \q, \qa

	vmov \twiddle1, \xi5
	vmov \twiddle2, \xi6
	two_doublebutterfly_plant \c4, \c5, \c6, \c7, \twiddle1, \twiddle2, \tmp, \q, \qa
.endm

.equ STACK_SIZE, (8*4)
.equ STACK_LOC_0, (0*4)
.equ STACK_LOC_1, (1*4)
.equ STACK_LOC_2, (2*4)
.equ STACK_LOC_3, (3*4)
.equ STACK_LOC_4, (4*4)
.equ STACK_LOC_5, (5*4)
.equ STACK_LOC_6, (6*4)
.equ STACK_LOC_7, (7*4)
.equ STACK_LOC_8, (8*4)

.global ntt_fast_symbolic
.type ntt_fast_symbolic, %function
.align 2
ntt_fast_symbolic:
	push {r4-r11, r14}
	vpush.w {s16-s25}
	poly         .req r0
	twiddle_ptr  .req r1
	###  qinv        .req r11 ### q^-1 mod 2^2n; n=16
	q           .req r12
	### at the top of r12
	### qa=2^a q;a=3; at the bottom of r12
	tmp         .req r14

	sub.w sp, sp, STACK_SIZE

	// movw qa, #26632
	// Why movt? Because we initially placed qa at the bottom of the same register as q;
	movt q, #3329

	### LAYER 7+6+5+4
	.equ distance, 256
	.equ offset, 32
	.equ strincr, 4
	// pre-load 15 twiddle factors to 15 FPU registers
	// s0-s7 used to temporary store 16 16-bit polys.
	vldm twiddle_ptr!, {s8-s22}
	vmov s25, twiddle_ptr

	add tmp, poly, #strincr*8
	// s23: poly addr
	// s24: tmp
	vmov s24, tmp
	1:
layer1234_start:
		// load a1, a3, ..., a15
		// vmov s23, poly
		load poly, R<poly1>, R<poly3>, R<poly5>, R<poly7>, #offset, #distance/4+offset, #2*distance/4+offset, #3*distance/4+offset
		load poly, R<poly9>, R<poly11>, R<poly13>, R<poly15>, #distance+offset, #5*distance/4+offset, #6*distance/4+offset, #7*distance/4+offset
		movw R<qa>, #26632

		// 8-NTT on a1, a3, ..., a15
		_3_layer_double_CT_16_plant_fp R<poly1>, R<poly3>, R<poly5>, R<poly7>, R<poly9>, R<poly11>, R<poly13>, R<poly15>, s8, s9, s10, s11, s12, s13, s14, R<twiddle1>, R<twiddle2>, q, R<qa>, R<ttt>

		// s15, s16, s17, s18, s19, s20, s21, s22 left
		// multiply coeffs by layer 8 twiddles for later use
		vmov R<twiddle1>, s15
		vmov R<twiddle2>, s16
		mul_twiddle_plant R<poly1>, R<twiddle1>, R<ttt>, q, R<qa>
		mul_twiddle_plant R<poly3>, R<twiddle2>, R<ttt>, q, R<qa>

		vmov R<twiddle1>, s17
		vmov R<twiddle2>, s18
		mul_twiddle_plant R<poly5>, R<twiddle1>, R<ttt>, q, R<qa>
		mul_twiddle_plant R<poly7>, R<twiddle2>, R<ttt>, q, R<qa>

		vmov R<twiddle1>, s19
		vmov R<twiddle2>, s20
		mul_twiddle_plant R<poly9>, R<twiddle1>, R<ttt>, q, R<qa>
		mul_twiddle_plant R<poly11>, R<twiddle2>, R<ttt>, q, R<qa>

		vmov R<twiddle1>, s21
		vmov R<twiddle2>, s22
		mul_twiddle_plant R<poly13>, R<twiddle1>, R<ttt>, q, R<qa>
		mul_twiddle_plant R<poly15>, R<twiddle2>, R<ttt>, q, R<qa>

		// vmov poly, s23

		// load a0, a2, ..., a14
		load poly, R<poly0>, R<poly2>, R<poly4>, R<poly6>, #0, #distance/4, #2*distance/4, #3*distance/4
		load poly, R<poly8>, R<poly10>, R<poly12>, R<poly14>, #distance, #5*distance/4, #6*distance/4, #7*distance/4

		// 8-NTT on a0, a2, ..., a14
		_3_layer_double_CT_16_plant_fp R<poly0>, R<poly2>, R<poly4>, R<poly6>, R<poly8>, R<poly10>, R<poly12>, R<poly14>, s8, s9, s10, s11, s12, s13, s14, R<twiddle1>, R<twiddle2>, q, R<qa>, R<ttt>


		// layer 4 - 1
		// addsub: (a2, a6, a10, a14), (a3, a7, a11, a15)
		uadd16 R<poly2out>, R<poly2>, R<poly3>
		usub16 R<poly3out>, R<poly2>, R<poly3>
		str.w R<poly2out>, [poly, #1*distance/4]
		str.w R<poly3out>, [poly, #1*distance/4+offset]

		uadd16 R<poly6out>, R<poly6>, R<poly7>
		usub16 R<poly7out>, R<poly6>, R<poly7>
		str.w R<poly6out>, [poly, #3*distance/4]
		str.w R<poly7out>, [poly, #3*distance/4+offset]

		uadd16 R<poly10out>, R<poly10>, R<poly11>
		usub16 R<poly11out>, R<poly10>, R<poly11>
		str.w R<poly10out>, [poly, #5*distance/4]
		str.w R<poly11out>, [poly, #5*distance/4+offset]

		uadd16 R<poly14out>, R<poly14>, R<poly15>
		usub16 R<poly15out>, R<poly14>, R<poly15>
		str.w R<poly14out>, [poly, #7*distance/4]
		str.w R<poly15out>, [poly, #7*distance/4+offset]

		// layer 4 - 2
		// addsub: (a0, a4, a8, a12), (a1, a5, a9, a13)
		uadd16 R<poly4out>, R<poly4>, R<poly5>
		usub16 R<poly5out>, R<poly4>, R<poly5>
		str.w R<poly4out>, [poly, #2*distance/4]
		str.w R<poly5out>, [poly, #2*distance/4+offset]

		//vmov R<poly9>, s4 // load a9
		uadd16 R<poly8out>, R<poly8>, R<poly9>
		usub16 R<poly9out>, R<poly8>, R<poly9>
		str.w R<poly8out>, [poly, #4*distance/4]
		str.w R<poly9out>, [poly, #4*distance/4+offset]

		//vmov R<poly13>, s6 // load a13
		uadd16 R<poly12out>, R<poly12>, R<poly13>
		usub16 R<poly13out>, R<poly12>, R<poly13>
		str.w R<poly12out>, [poly, #6*distance/4]
		str.w R<poly13out>, [poly, #6*distance/4+offset]

		//vmov R<poly1>, s0 // load a1
		uadd16 R<poly0out>, R<poly0>, R<poly1>
		usub16 R<poly1out>, R<poly0>, R<poly1>
		str.w R<poly1out>, [poly, #offset]
		str.w R<poly0out>, [poly], #4

	vmov tmp, s24
	layer1234_end:
	cmp.w poly, tmp
	bne.w 1b

	twiddle1     .req r10
	twiddle2     .req r11
	poly0        .req r2
	poly1        .req r3
	poly2        .req r4
	poly3        .req r5
	poly4        .req r6
	poly5        .req r7
	poly6        .req r8
	poly7        .req r9
	qa          .req r0
	sub.w poly, #8*strincr
	vmov twiddle_ptr, s25

	### LAYER 3+2+1

	.equ distance2, distance/16
	.equ strincr2, 32

	add.w tmp, poly, #strincr2*16
	vmov s13, tmp
	2:
	layer567_start:
		vmov s23, poly
		load poly, poly0, poly1, poly2, poly3, #0, #distance2/4, #2*distance2/4, #3*distance2/4
		load poly, poly4, poly5, poly6, poly7, #distance2, #5*distance2/4, #6*distance2/4, #7*distance2/4

		movw qa, #26632
		_3_layer_double_CT_16_plant poly0, poly1, poly2, poly3, poly4, poly5, poly6, poly7, twiddle1, twiddle2, twiddle_ptr, q, qa, tmp

		vmov poly, s23
		store poly, poly4, poly5, poly6, poly7, #distance2, #5*distance2/4, #6*distance2/4, #7*distance2/4
		str.w poly1, [poly, #distance2/4]
		str.w poly2, [poly, #2*distance2/4]
		str.w poly3, [poly, #3*distance2/4]
		str.w poly0, [poly], #strincr2

	vmov tmp, s13
	layer567_end:

	cmp.w poly, tmp
	bne.w 2b

	add.w sp, sp, STACK_SIZE

	vpop.w {s16-s25}
	pop {r4-r11, pc}

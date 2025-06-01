@
@ Implementation by the Keccak, Keyak and Ketje Teams, namely, Guido Bertoni,
@ Joan Daemen, Michaël Peeters, Gilles Van Assche and Ronny Van Keer, hereby
@ denoted as "the implementer".
@
@ For more information, feedback or questions, please refer to our websites:
@ http://keccak.noekeon.org/
@ http://keyak.noekeon.org/
@ http://ketje.noekeon.org/
@
@ To the extent possible under law, the implementer has waived all copyright
@ and related or neighboring rights to the source code in this file.
@ http://creativecommons.org/publicdomain/zero/1.0/
@

@ WARNING: These functions work only on little endian CPU with@ ARMv7m architecture (ARM Cortex-M3, ...).


	.thumb
	.syntax unified
.text

	@ Credit: Henry S. Warren, Hacker's Delight, Addison-Wesley, 2002
.macro	toBitInterleaving	x0,x1,s0,s1,t,over

	and		\t,\x0,#0x55555555
	orr		\t,\t,\t, lsr #1
	and		\t,\t,#0x33333333
	orr		\t,\t,\t, lsr #2
	and		\t,\t,#0x0F0F0F0F
	orr		\t,\t,\t, lsr #4
	and		\t,\t,#0x00FF00FF
	bfi		\t,\t,#8, #8
	.if \over != 0
	lsr		\s0,\t, #8
	.else
	eor		\s0,\s0,\t, lsr #8
	.endif

	and		\t,\x1,#0x55555555
	orr		\t,\t,\t, lsr #1
	and		\t,\t,#0x33333333
	orr		\t,\t,\t, lsr #2
	and		\t,\t,#0x0F0F0F0F
	orr		\t,\t,\t, lsr #4
	and		\t,\t,#0x00FF00FF
	orr		\t,\t,\t, lsr #8
	eor		\s0,\s0,\t, lsl #16

	and		\t,\x0,#0xAAAAAAAA
	orr		\t,\t,\t, lsl #1
	and		\t,\t,#0xCCCCCCCC
	orr		\t,\t,\t, lsl #2
	and		\t,\t,#0xF0F0F0F0
	orr		\t,\t,\t, lsl #4
	and		\t,\t,#0xFF00FF00
	orr		\t,\t,\t, lsl #8
	.if \over != 0
	lsr		\s1,\t, #16
	.else
	eor		\s1,\s1,\t, lsr #16
	.endif

	and		\t,\x1,#0xAAAAAAAA
	orr		\t,\t,\t, lsl #1
	and		\t,\t,#0xCCCCCCCC
	orr		\t,\t,\t, lsl #2
	and		\t,\t,#0xF0F0F0F0
	orr		\t,\t,\t, lsl #4
	and		\t,\t,#0xFF00FF00
	orr		\t,\t,\t, lsl #8
	bfc		\t, #0, #16
	eors.w \s1,\s1,\t
	.endm

	@ Credit: Henry S. Warren, Hacker's Delight, Addison-Wesley, 2002
.macro	fromBitInterleaving		x0, x1, t

	movs	\t, \x0					@ t = x0@
	bfi		\x0, \x1, #16, #16		@ x0 = (x0 & 0x0000FFFF) | (x1 << 16)@
	bfc		\x1, #0, #16			@	x1 = (t >> 16) | (x1 & 0xFFFF0000)@
	orr		\x1, \x1, \t, lsr #16

    eor		\t, \x0, \x0, lsr #8    @ t = (x0 ^ (x0 >>  8)) & 0x0000FF00UL@  x0 = x0 ^ t ^ (t <<  8)@
	and		\t, #0x0000FF00
    eors.w \x0, \x0, \t
    eor		\x0, \x0, \t, lsl #8

    eor		\t, \x0, \x0, lsr #4	@ t = (x0 ^ (x0 >>  4)) & 0x00F000F0UL@  x0 = x0 ^ t ^ (t <<  4)@
	and		\t, #0x00F000F0
    eors.w \x0, \x0, \t
    eor		\x0, \x0, \t, lsl #4

    eor		\t, \x0, \x0, lsr #2	@ t = (x0 ^ (x0 >>  2)) & 0x0C0C0C0CUL@  x0 = x0 ^ t ^ (t <<  2)@
	and		\t, #0x0C0C0C0C
    eors.w \x0, \x0, \t
    eor		\x0, \x0, \t, lsl #2

    eor		\t, \x0, \x0, lsr #1	@ t = (x0 ^ (x0 >>  1)) & 0x22222222UL@  x0 = x0 ^ t ^ (t <<  1)@
	and		\t, #0x22222222
    eors.w \x0, \x0, \t
    eor		\x0, \x0, \t, lsl #1

    eor		\t, \x1, \x1, lsr #8    @ t = (x1 ^ (x1 >>  8)) & 0x0000FF00UL@  x1 = x1 ^ t ^ (t <<  8)@
	and		\t, #0x0000FF00
    eors.w \x1, \x1, \t
    eor		\x1, \x1, \t, lsl #8

    eor		\t, \x1, \x1, lsr #4	@ t = (x1 ^ (x1 >>  4)) & 0x00F000F0UL@  x1 = x1 ^ t ^ (t <<  4)@
	and		\t, #0x00F000F0
    eors.w \x1, \x1, \t
    eor		\x1, \x1, \t, lsl #4

    eor		\t, \x1, \x1, lsr #2	@ t = (x1 ^ (x1 >>  2)) & 0x0C0C0C0CUL@  x1 = x1 ^ t ^ (t <<  2)@
	and		\t, #0x0C0C0C0C
    eors.w \x1, \x1, \t
    eor		\x1, \x1, \t, lsl #2

    eor		\t, \x1, \x1, lsr #1	@ t = (x1 ^ (x1 >>  1)) & 0x22222222UL@  x1 = x1 ^ t ^ (t <<  1)@
	and		\t, #0x22222222
    eors.w \x1, \x1, \t
    eor		\x1, \x1, \t, lsl #1
	.endm

@	--- offsets in state
.equ Aba0, 0*4
.equ Aba1, 1*4
.equ Abe0, 2*4
.equ Abe1, 3*4
.equ Abi0, 4*4
.equ Abi1, 5*4
.equ Abo0, 6*4
.equ Abo1, 7*4
.equ Abu0, 8*4
.equ Abu1, 9*4
.equ Aga0, 10*4
.equ Aga1, 11*4
.equ Age0, 12*4
.equ Age1, 13*4
.equ Agi0, 14*4
.equ Agi1, 15*4
.equ Ago0, 16*4
.equ Ago1, 17*4
.equ Agu0, 18*4
.equ Agu1, 19*4
.equ Aka0, 20*4
.equ Aka1, 21*4
.equ Ake0, 22*4
.equ Ake1, 23*4
.equ Aki0, 24*4
.equ Aki1, 25*4
.equ Ako0, 26*4
.equ Ako1, 27*4
.equ Aku0, 28*4
.equ Aku1, 29*4
.equ Ama0, 30*4
.equ Ama1, 31*4
.equ Ame0, 32*4
.equ Ame1, 33*4
.equ Ami0, 34*4
.equ Ami1, 35*4
.equ Amo0, 36*4
.equ Amo1, 37*4
.equ Amu0, 38*4
.equ Amu1, 39*4
.equ Asa0, 40*4
.equ Asa1, 41*4
.equ Ase0, 42*4
.equ Ase1, 43*4
.equ Asi0, 44*4
.equ Asi1, 45*4
.equ Aso0, 46*4
.equ Aso1, 47*4
.equ Asu0, 48*4
.equ Asu1, 49*4

@	--- offsets on stack
.equ mDa0, 0*4
.equ mDa1, 1*4
.equ mDo0, 2*4
.equ mDo1, 3*4
.equ mDi0, 4*4
.equ mRC	, 5*4
.equ mSize, 6*4


.macro	xor5		result,b,g,k,m,s

	ldr.w			\result, [r0, #\b]   // @slothy:reads=[r0\()\b]
	ldr.w			r1, [r0, #\g]        // @slothy:reads=[r0\()\g]
	eors.w	\result, \result, r1
	ldr.w			r1, [r0, #\k]        // @slothy:reads=[r0\()\k]
	eors.w	\result, \result, r1
	ldr.w			r1, [r0, #\m]        // @slothy:reads=[r0\()\m]
	eors.w	\result, \result, r1
	ldr.w			r1, [r0, #\s]        // @slothy:reads=[r0\()\s]
	eors.w	\result, \result, r1
	.endm

.macro	xorrol 		result, aa, bb

	eor			\result, \aa, \bb, ror #31
	.endm

.macro	xandnot 	resofs, aa, bb, cc

	bic.w			r1, \cc, \bb
	eors.w	r1, r1, \aa
	str.w			r1, [r0, #\resofs] // @slothy:writes=[r0\()\resofs]
	.endm

.macro	KeccakThetaRhoPiChiIota aA1, aDax, aA2, aDex, rot2, aA3, aDix, rot3, aA4, aDox, rot4, aA5, aDux, rot5, offset, last
	ldr.w		r3, [r0, #\aA1] // @slothy:reads=[r0\()\aA1]
	ldr.w		r4, [r0, #\aA2] // @slothy:reads=[r0\()\aA2]
	ldr.w		r5, [r0, #\aA3] // @slothy:reads=[r0\()\aA3]
	ldr.w		r6, [r0, #\aA4] // @slothy:reads=[r0\()\aA4]
	ldr.w		r7, [r0, #\aA5] // @slothy:reads=[r0\()\aA5]
	eors.w r3, r3, \aDax
	eors.w r5, r5, \aDix
	eors.w r4, r4, \aDex
	eors.w r6, r6, \aDox
	eors.w r7, r7, \aDux
	rors.w	r4, #32-\rot2
	rors.w	r5, #32-\rot3
	rors.w	r6, #32-\rot4
	rors.w	r7, #32-\rot5
    xandnot \aA2, r4, r5, r6
    xandnot \aA3, r5, r6, r7
    xandnot \aA4, r6, r7, r3
    xandnot \aA5, r7, r3, r4
	ldr.w		r1, [sp, #mRC]
	bics.w	r5, r5, r4
	ldr.w		r4, [r1, #\offset]
	eors.w r3, r3, r5
	eors.w r3, r3, r4
	.if	\last == 1
	ldr.w		r4, [r1, #32]!
	str.w		r1, [sp, #mRC]
	cmp		r4, #0xFF
	.endif
	str.w		r3, [r0, #\aA1] // @slothy:writes=[r0\()\aA1]
	.endm

.macro	KeccakThetaRhoPiChi aB1, aA1, aDax, rot1, aB2, aA2, aDex, rot2, aB3, aA3, aDix, rot3, aB4, aA4, aDox, rot4, aB5, aA5, aDux, rot5
	ldr.w		\aB1, [r0, #\aA1] // @slothy:reads=[r0\()\aA1]
	ldr.w		\aB2, [r0, #\aA2] // @slothy:reads=[r0\()\aA2]
	ldr.w		\aB3, [r0, #\aA3] // @slothy:reads=[r0\()\aA3]
	ldr.w		\aB4, [r0, #\aA4] // @slothy:reads=[r0\()\aA4]
	ldr.w		\aB5, [r0, #\aA5] // @slothy:reads=[r0\()\aA5]
	eors.w \aB1, \aB1, \aDax
	eors.w \aB3, \aB3, \aDix
	eors.w \aB2, \aB2, \aDex
	eors.w \aB4, \aB4, \aDox
	eors.w \aB5, \aB5, \aDux
	rors.w	\aB1, #32-\rot1
	.if	\rot2 > 0
	rors.w	\aB2, #32-\rot2
	.endif
	rors.w	\aB3, #32-\rot3
	rors.w	\aB4, #32-\rot4
	rors.w	\aB5, #32-\rot5
	xandnot \aA1, r3, r4, r5
    xandnot \aA2, r4, r5, r6
    xandnot \aA3, r5, r6, r7
    xandnot \aA4, r6, r7, r3
    xandnot \aA5, r7, r3, r4
	.endm

.macro	KeccakRound0
	xor5        r3,  Abu0, Agu0, Aku0, Amu0, Asu0
	xor5        r7, Abe1, Age1, Ake1, Ame1, Ase1
	xorrol      r6, r3, r7
	str.w			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
	xor5        r6,  Abu1, Agu1, Aku1, Amu1, Asu1
	xor5        lr, Abe0, Age0, Ake0, Ame0, Ase0
	eors.w      r8, r6, lr
	str.w			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

	xor5        r5,  Abi0, Agi0, Aki0, Ami0, Asi0
	xorrol      r9, r5, r6
	str.w			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
	xor5        r4,  Abi1, Agi1, Aki1, Ami1, Asi1
	eors.w	r3, r3, r4
	str.w			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

	xor5        r3,  Aba0, Aga0, Aka0, Ama0, Asa0
	xorrol      r10, r3, r4
	xor5        r6,  Aba1, Aga1, Aka1, Ama1, Asa1
	eors.w      r11, r6, r5

	xor5        r4,  Abo1, Ago1, Ako1, Amo1, Aso1
	xorrol      r5, lr, r4
	str.w			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
	xor5        r5,  Abo0, Ago0, Ako0, Amo0, Aso0
	eors.w      r2, r7, r5

	xorrol      r12, r5, r6
	eors.w      lr, r4, r3
	KeccakThetaRhoPiChi r5, Aka1, r8,  2, r6, Ame1, r11, 23, r7, Asi1, r2, 31, r3, Abo0, r9, 14, r4, Agu0, r12, 10
	KeccakThetaRhoPiChi r7, Asa1, r8,  9, r3, Abe0, r10,  0, r4, Agi1, r2,  3, r5, Ako0, r9, 12, r6, Amu1, lr,  4
	ldr.w			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
	KeccakThetaRhoPiChi r4, Aga0, r8, 18, r5, Ake0, r10,  5, r6, Ami1, r2,  8, r7, Aso0, r9, 28, r3, Abu1, lr, 14
	KeccakThetaRhoPiChi r6, Ama0, r8, 20, r7, Ase1, r11,  1, r3, Abi1, r2, 31, r4, Ago0, r9, 27, r5, Aku0, r12, 19
	ldr.w			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
	KeccakThetaRhoPiChiIota  Aba0, r8,          Age0, r10, 22,      Aki1, r2, 22,      Amo1, r9, 11,      Asu0, r12,  7, 0, 0

	ldr.w			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
	KeccakThetaRhoPiChi r5, Aka0, r8,  1, r6, Ame0, r10, 22, r7, Asi0, r2, 30, r3, Abo1, r9, 14, r4, Agu1, lr, 10
	KeccakThetaRhoPiChi r7, Asa0, r8,  9, r3, Abe1, r11,  1, r4, Agi0, r2,  3, r5, Ako1, r9, 13, r6, Amu0, r12,  4
	ldr.w			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
	KeccakThetaRhoPiChi r4, Aga1, r8, 18, r5, Ake1, r11,  5, r6, Ami0, r2,  7, r7, Aso1, r9, 28, r3, Abu0, r12, 13
	KeccakThetaRhoPiChi r6, Ama1, r8, 21, r7, Ase0, r10,  1, r3, Abi0, r2, 31, r4, Ago1, r9, 28, r5, Aku1, lr, 20
	ldr.w			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
	KeccakThetaRhoPiChiIota  Aba1, r8,          Age1, r11, 22,      Aki0, r2, 21,      Amo0, r9, 10,      Asu1, lr,  7, 4, 0
	.endm

.macro	KeccakRound1

	xor5        r3,  Asu0, Agu0, Amu0, Abu1, Aku1
	xor5        r7, Age1, Ame0, Abe0, Ake1, Ase1
	xorrol      r6, r3, r7
	str.w			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
	xor5        r6,  Asu1, Agu1, Amu1, Abu0, Aku0
	xor5        lr, Age0, Ame1, Abe1, Ake0, Ase0
	eors.w      r8, r6, lr
	str.w			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

	xor5        r5,  Aki1, Asi1, Agi0, Ami1, Abi0
	xorrol      r9, r5, r6
	str.w			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
	xor5        r4,  Aki0, Asi0, Agi1, Ami0, Abi1
	eors.w	r3, r3, r4
	str.w			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

	xor5        r3,  Aba0, Aka1, Asa0, Aga0, Ama1
	xorrol      r10, r3, r4
	xor5        r6,  Aba1, Aka0, Asa1, Aga1, Ama0
	eors.w      r11, r6, r5

	xor5        r4,  Amo0, Abo1, Ako0, Aso1, Ago0
	xorrol      r5, lr, r4
	str.w			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
	xor5        r5,  Amo1, Abo0, Ako1, Aso0, Ago1
	eors.w      r2, r7, r5

	xorrol      r12, r5, r6
	eors.w      lr, r4, r3

	KeccakThetaRhoPiChi r5, Asa1, r8,  2, r6, Ake1, r11, 23, r7, Abi1, r2, 31, r3, Amo1, r9, 14, r4, Agu0, r12, 10
	KeccakThetaRhoPiChi r7, Ama0, r8,  9, r3, Age0, r10,  0, r4, Asi0, r2,  3, r5, Ako1, r9, 12, r6, Abu0, lr,  4
	ldr.w			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
	KeccakThetaRhoPiChi r4, Aka1, r8, 18, r5, Abe1, r10,  5, r6, Ami0, r2,  8, r7, Ago1, r9, 28, r3, Asu1, lr, 14
	KeccakThetaRhoPiChi r6, Aga0, r8, 20, r7, Ase1, r11,  1, r3, Aki0, r2, 31, r4, Abo0, r9, 27, r5, Amu0, r12, 19
	ldr.w			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
	KeccakThetaRhoPiChiIota  Aba0, r8,          Ame1, r10, 22,      Agi1, r2, 22,      Aso1, r9, 11,      Aku1, r12,  7, 8, 0

	ldr.w			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
	KeccakThetaRhoPiChi r5, Asa0, r8,  1, r6, Ake0, r10, 22, r7, Abi0, r2, 30, r3, Amo0, r9, 14, r4, Agu1, lr, 10
	KeccakThetaRhoPiChi r7, Ama1, r8,  9, r3, Age1, r11,  1, r4, Asi1, r2,  3, r5, Ako0, r9, 13, r6, Abu1, r12,  4
	ldr.w			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
	KeccakThetaRhoPiChi r4, Aka0, r8, 18, r5, Abe0, r11,  5, r6, Ami1, r2,  7, r7, Ago0, r9, 28, r3, Asu0, r12, 13
	KeccakThetaRhoPiChi r6, Aga1, r8, 21, r7, Ase0, r10,  1, r3, Aki1, r2, 31, r4, Abo1, r9, 28, r5, Amu1, lr, 20
	ldr.w			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
	KeccakThetaRhoPiChiIota  Aba1, r8,          Ame0, r11, 22,      Agi0, r2, 21,      Aso0, r9, 10,      Aku0, lr,  7, 12, 0
	.endm

.macro	KeccakRound2

	xor5        r3, Aku1, Agu0, Abu1, Asu1, Amu1
	xor5        r7, Ame0, Ake0, Age0, Abe0, Ase1
	xorrol      r6, r3, r7
	str.w			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
	xor5        r6,  Aku0, Agu1, Abu0, Asu0, Amu0
	xor5        lr, Ame1, Ake1, Age1, Abe1, Ase0
	eors.w      r8, r6, lr
	str.w			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

	xor5        r5,  Agi1, Abi1, Asi1, Ami0, Aki1
	xorrol      r9, r5, r6
	str.w			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
	xor5        r4,  Agi0, Abi0, Asi0, Ami1, Aki0
	eors.w	r3, r3, r4
	str.w			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

	xor5        r3,  Aba0, Asa1, Ama1, Aka1, Aga1
	xorrol      r10, r3, r4
	xor5        r6,  Aba1, Asa0, Ama0, Aka0, Aga0
	eors.w      r11, r6, r5

	xor5        r4,  Aso0, Amo0, Ako1, Ago0, Abo0
	xorrol      r5, lr, r4
	str.w			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
	xor5        r5,  Aso1, Amo1, Ako0, Ago1, Abo1
	eors.w      r2, r7, r5

	xorrol      r12, r5, r6
	eors.w      lr, r4, r3

	KeccakThetaRhoPiChi r5, Ama0, r8,  2, r6, Abe0, r11, 23, r7, Aki0, r2, 31, r3, Aso1, r9, 14, r4, Agu0, r12, 10
	KeccakThetaRhoPiChi r7, Aga0, r8,  9, r3, Ame1, r10,  0, r4, Abi0, r2,  3, r5, Ako0, r9, 12, r6, Asu0, lr,  4
	ldr.w			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
	KeccakThetaRhoPiChi r4, Asa1, r8, 18, r5, Age1, r10,  5, r6, Ami1, r2,  8, r7, Abo1, r9, 28, r3, Aku0, lr, 14
	KeccakThetaRhoPiChi r6, Aka1, r8, 20, r7, Ase1, r11,  1, r3, Agi0, r2, 31, r4, Amo1, r9, 27, r5, Abu1, r12, 19
	ldr.w			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
	KeccakThetaRhoPiChiIota  Aba0, r8,          Ake1, r10, 22,      Asi0, r2, 22,      Ago0, r9, 11,      Amu1, r12,  7, 16, 0

	ldr.w			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
	KeccakThetaRhoPiChi r5, Ama1, r8,  1, r6, Abe1, r10, 22, r7, Aki1, r2, 30, r3, Aso0, r9, 14, r4, Agu1, lr, 10
	KeccakThetaRhoPiChi r7, Aga1, r8,  9, r3, Ame0, r11,  1, r4, Abi1, r2,  3, r5, Ako1, r9, 13, r6, Asu1, r12,  4
	ldr.w			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
	KeccakThetaRhoPiChi r4, Asa0, r8, 18, r5, Age0, r11,  5, r6, Ami0, r2,  7, r7, Abo0, r9, 28, r3, Aku1, r12, 13
	KeccakThetaRhoPiChi r6, Aka0, r8, 21, r7, Ase0, r10,  1, r3, Agi1, r2, 31, r4, Amo0, r9, 28, r5, Abu0, lr, 20
	ldr.w			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
	KeccakThetaRhoPiChiIota  Aba1, r8,          Ake0, r11, 22,      Asi1, r2, 21,      Ago1, r9, 10,      Amu0, lr,  7, 20, 0
	.endm

.macro	KeccakRound3

	xor5        r3,  Amu1, Agu0, Asu1, Aku0, Abu0
	xor5        r7, Ake0, Abe1, Ame1, Age0, Ase1
	xorrol      r6, r3, r7
	str.w			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
	xor5        r6,  Amu0, Agu1, Asu0, Aku1, Abu1
	xor5        lr, Ake1, Abe0, Ame0, Age1, Ase0
	eors.w      r8, r6, lr
	str.w			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

	xor5        r5,  Asi0, Aki0, Abi1, Ami1, Agi1
	xorrol      r9, r5, r6
	str.w			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
	xor5        r4,  Asi1, Aki1, Abi0, Ami0, Agi0
	eors.w	r3, r3, r4
	str.w			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

	xor5        r3,  Aba0, Ama0, Aga1, Asa1, Aka0
	xorrol      r10, r3, r4
	xor5        r6,  Aba1, Ama1, Aga0, Asa0, Aka1
	eors.w      r11, r6, r5

	xor5        r4,  Ago1, Aso0, Ako0, Abo0, Amo1
	xorrol      r5, lr, r4
	str.w			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
	xor5        r5,  Ago0, Aso1, Ako1, Abo1, Amo0
	eors.w      r2, r7, r5

	xorrol      r12, r5, r6
	eors.w      lr, r4, r3

	KeccakThetaRhoPiChi r5, Aga0, r8,  2, r6, Age0, r11, 23, r7, Agi0, r2, 31, r3, Ago0, r9, 14, r4, Agu0, r12, 10
	KeccakThetaRhoPiChi r7, Aka1, r8,  9, r3, Ake1, r10,  0, r4, Aki1, r2,  3, r5, Ako1, r9, 12, r6, Aku1, lr,  4
	ldr.w			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
	KeccakThetaRhoPiChi r4, Ama0, r8, 18, r5, Ame0, r10,  5, r6, Ami0, r2,  8, r7, Amo0, r9, 28, r3, Amu0, lr, 14
	KeccakThetaRhoPiChi r6, Asa1, r8, 20, r7, Ase1, r11,  1, r3, Asi1, r2, 31, r4, Aso1, r9, 27, r5, Asu1, r12, 19
	ldr.w			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
	KeccakThetaRhoPiChiIota  Aba0, r8,          Abe0, r10, 22,      Abi0, r2, 22,      Abo0, r9, 11,      Abu0, r12,  7, 24, 0

	ldr.w			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
	KeccakThetaRhoPiChi r5, Aga1, r8,  1, r6, Age1, r10, 22, r7, Agi1, r2, 30, r3, Ago1, r9, 14, r4, Agu1, lr, 10
	KeccakThetaRhoPiChi r7, Aka0, r8,  9, r3, Ake0, r11,  1, r4, Aki0, r2,  3, r5, Ako0, r9, 13, r6, Aku0, r12,  4
	ldr.w			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
	KeccakThetaRhoPiChi r4, Ama1, r8, 18, r5, Ame1, r11,  5, r6, Ami1, r2,  7, r7, Amo1, r9, 28, r3, Amu1, r12, 13
	KeccakThetaRhoPiChi r6, Asa0, r8, 21, r7, Ase0, r10,  1, r3, Asi0, r2, 31, r4, Aso0, r9, 28, r5, Asu0, lr, 20
	ldr.w			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
	KeccakThetaRhoPiChiIota  Aba1, r8,          Abe1, r11, 22,      Abi1, r2, 21,      Abo1, r9, 10,      Abu1, lr,  7, 28, 1
	.endm


@----------------------------------------------------------------------------
@
@ void KeccakF1600_Initialize( void )
@
.align 8
KeccakF1600_Initialize:
	bx		lr



@----------------------------------------------------------------------------
@
@ void KeccakF1600_StateXORBytes(void *state, const unsigned char *data, unsigned int offset, unsigned int length)
@
.align 8
KeccakF1600_StateXORBytes:
	cbz		r3, KeccakF1600_StateXORBytes_Exit1
	push	{r4 - r8, lr}							@ then
	bic.w		r4, r2, #7								@ offset &= ~7
	adds	r0, r0, r4								@ add whole lane offset to state pointer
	ands	r2, r2, #7								@ offset &= 7 (part not lane aligned)
	beq		KeccakF1600_StateXORBytes_CheckLanes	@ .if offset != 0
	movs	r4, r3									@ then, do remaining bytes in first lane
	rsb		r5, r2, #8								@ max size in lane = 8 - offset
	cmp		r4, r5
	ble		KeccakF1600_StateXORBytes_BytesAlign
	movs	r4, r5
KeccakF1600_StateXORBytes_BytesAlign:
	sub		r8, r3, r4								@ size left
	movs	r3, r4
	bl		__KeccakF1600_StateXORBytesInLane
	mov		r3, r8
KeccakF1600_StateXORBytes_CheckLanes:
	lsrs	r2, r3, #3								@ .if length >= 8
	beq		KeccakF1600_StateXORBytes_Bytes
	mov		r8, r3
	bl		__KeccakF1600_StateXORLanes
	and		r3, r8, #7
KeccakF1600_StateXORBytes_Bytes:
	cbz		r3, KeccakF1600_StateXORBytes_Exit
	movs	r2, #0
	bl		__KeccakF1600_StateXORBytesInLane
KeccakF1600_StateXORBytes_Exit:
	pop		{r4 - r8, pc}
KeccakF1600_StateXORBytes_Exit1:
	bx		lr


@----------------------------------------------------------------------------
@
@ __KeccakF1600_StateXORLanes
@
@ Input:
@  r0 state pointer
@  r1 data pointer
@  r2 laneCount
@
@ Output:
@  r0 state pointer next lane
@  r1 data pointer next byte to input
@
@ Changed: r2-r7
@
.align 8
__KeccakF1600_StateXORLanes:
__KeccakF1600_StateXORLanes_LoopAligned:
	ldr.w		r4, [r1], #4
	ldr.w		r5, [r1], #4
	ldrd    r6, r7, [r0]
	toBitInterleaving	r4, r5, r6, r7, r3, 0
	strd	r6, r7, [r0], #8
	subs	r2, r2, #1
	bne		__KeccakF1600_StateXORLanes_LoopAligned
	bx		lr


@----------------------------------------------------------------------------
@
@ __KeccakF1600_StateXORBytesInLane
@
@ Input:
@  r0 state pointer
@  r1 data pointer
@  r2 offset in lane
@  r3 length
@
@ Output:
@  r0 state pointer next lane
@  r1 data pointer next byte to input
@
@  Changed: r2-r7
@
.align 8
__KeccakF1600_StateXORBytesInLane:
	movs	r4, #0
	movs	r5, #0
	push	{ r4 - r5 }
	add		r2, r2, sp
__KeccakF1600_StateXORBytesInLane_Loop:
	ldrb	r5, [r1], #1
	strb	r5, [r2], #1
	subs	r3, r3, #1
	bne		__KeccakF1600_StateXORBytesInLane_Loop
	pop		{ r4 - r5 }
	ldrd    r6, r7, [r0]
	toBitInterleaving	r4, r5, r6, r7, r3, 0
	strd	r6, r7, [r0], #8
	bx		lr




@----------------------------------------------------------------------------
@
@ void KeccakF1600_StateExtractBytes(void *state, const unsigned char *data, unsigned int offset, unsigned int length)
@
.align 8
KeccakF1600_StateExtractBytes:
	cbz		r3, KeccakF1600_StateExtractBytes_Exit1	@ .if length != 0
	push	{r4 - r8, lr}							@ then
	bic.w		r4, r2, #7								@ offset &= ~7
	adds	r0, r0, r4								@ add whole lane offset to state pointer
	ands	r2, r2, #7								@ offset &= 7 (part not lane aligned)
	beq		KeccakF1600_StateExtractBytes_CheckLanes	@ .if offset != 0
	movs	r4, r3									@ then, do remaining bytes in first lane
	rsb		r5, r2, #8								@ max size in lane = 8 - offset
	cmp		r4, r5
	ble		KeccakF1600_StateExtractBytes_BytesAlign
	movs	r4, r5
KeccakF1600_StateExtractBytes_BytesAlign:
	sub		r8, r3, r4								@ size left
	movs	r3, r4
	bl		__KeccakF1600_StateExtractBytesInLane
	mov		r3, r8
KeccakF1600_StateExtractBytes_CheckLanes:
	lsrs	r2, r3, #3								@ .if length >= 8
	beq		KeccakF1600_StateExtractBytes_Bytes
	mov		r8, r3
	bl		__KeccakF1600_StateExtractLanes
	and		r3, r8, #7
KeccakF1600_StateExtractBytes_Bytes:
	cbz		r3, KeccakF1600_StateExtractBytes_Exit
	movs	r2, #0
	bl		__KeccakF1600_StateExtractBytesInLane
KeccakF1600_StateExtractBytes_Exit:
	pop		{r4 - r8, pc}
KeccakF1600_StateExtractBytes_Exit1:
	bx		lr


@----------------------------------------------------------------------------
@
@ __KeccakF1600_StateExtractLanes
@
@ Input:
@  r0 state pointer
@  r1 data pointer
@  r2 laneCount
@
@ Output:
@  r0 state pointer next lane
@  r1 data pointer next byte to input
@
@ Changed: r2-r5
@
.align 8
__KeccakF1600_StateExtractLanes:
__KeccakF1600_StateExtractLanes_LoopAligned:
	ldrd	r4, r5, [r0], #8
	fromBitInterleaving	r4, r5, r3
	str.w		r4, [r1], #4
	subs	r2, r2, #1
	str.w		r5, [r1], #4
	bne		__KeccakF1600_StateExtractLanes_LoopAligned
	bx		lr


@----------------------------------------------------------------------------
@
@ __KeccakF1600_StateExtractBytesInLane
@
@ Input:
@  r0 state pointer
@  r1 data pointer
@  r2 offset in lane
@  r3 length
@
@ Output:
@  r0 state pointer next lane
@  r1 data pointer next byte to input
@
@  Changed: r2-r6
@
.align 8
__KeccakF1600_StateExtractBytesInLane:
	ldrd	r4, r5, [r0], #8
	fromBitInterleaving	r4, r5, r6
	push	{r4, r5}
	add		r2, sp, r2
__KeccakF1600_StateExtractBytesInLane_Loop:
	ldrb	r4, [r2], #1
	subs	r3, r3, #1
	strb	r4, [r1], #1
	bne		__KeccakF1600_StateExtractBytesInLane_Loop
	add		sp, #8
	bx		lr



.align 8
KeccakF1600_StatePermute_RoundConstantsWithTerminator:
	@		0			1
		.long 		0x00000001,	0x00000000
		.long 		0x00000000,	0x00000089
		.long 		0x00000000,	0x8000008b
		.long 		0x00000000,	0x80008080

		.long 		0x00000001,	0x0000008b
		.long 		0x00000001,	0x00008000
		.long 		0x00000001,	0x80008088
		.long 		0x00000001,	0x80000082

		.long 		0x00000000,	0x0000000b
		.long 		0x00000000,	0x0000000a
		.long 		0x00000001,	0x00008082
		.long 		0x00000000,	0x00008003

		.long 		0x00000001,	0x0000808b
		.long 		0x00000001,	0x8000000b
		.long 		0x00000001,	0x8000008a
		.long 		0x00000001,	0x80000081

		.long 		0x00000000,	0x80000081
		.long 		0x00000000,	0x80000008
		.long 		0x00000000,	0x00000083
		.long 		0x00000000,	0x80008003

		.long 		0x00000001,	0x80008088
		.long 		0x00000000,	0x80000088
		.long 		0x00000001,	0x00008000
		.long 		0x00000000,	0x80008082

		.long 		0x000000FF	@terminator

@----------------------------------------------------------------------------
@
@ void KeccakF1600_StatePermute( void *state )
@
.align 8
.global   KeccakF1600_StatePermute_xkcp
.type KeccakF1600_StatePermute_xkcp,%function
KeccakF1600_StatePermute_xkcp:
	adr		r1, KeccakF1600_StatePermute_RoundConstantsWithTerminator
	push	{ r4 - r12, lr }
	sub		sp, #mSize
	str.w		r1, [sp, #mRC]
KeccakF1600_StatePermute_RoundLoop:
slothy_start:
	KeccakRound0
	KeccakRound1
	KeccakRound2
	KeccakRound3
slothy_end:
	bne		KeccakF1600_StatePermute_RoundLoop
	add		sp, #mSize
	pop		{ r4 - r12, pc }

.size KeccakF1600_StatePermute_xkcp, .-KeccakF1600_StatePermute_xkcp
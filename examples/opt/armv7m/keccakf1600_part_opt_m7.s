@
@ Implementation by the Keccak, Keyak and Ketje Teams, namely, Guido Bertoni,
@ Joan Daemen, Michaël Peeters, Gilles Van Assche and Ronny Van Keer, hereby
@ denoted as "the implementer".
@
@ For more information, feedback or questions, please refer to our websites:
@ http:// keccak.noekeon.org/
@ http:// keyak.noekeon.org/
@ http:// ketje.noekeon.org/
@
@ To the extent possible under law, the implementer has waived all copyright
@ and related or neighboring rights to the source code in this file.
@ http:// creativecommons.org/publicdomain/zero/1.0/
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
 eors.w	\s1,\t
 .endm

 @ Credit: Henry S. Warren, Hacker's Delight, Addison-Wesley, 2002
.macro	fromBitInterleaving		x0, x1, t

 movs	\t, \x0					@ t = x0@
 bfi		\x0, \x1, #16, #16		@ x0 = (x0 & 0x0000FFFF) | (x1 << 16)@
 bfc		\x1, #0, #16			@	x1 = (t >> 16) | (x1 & 0xFFFF0000)@
 orr		\x1, \x1, \t, lsr #16

    eor		\t, \x0, \x0, lsr #8    @ t = (x0 ^ (x0 >>  8)) & 0x0000FF00UL@  x0 = x0 ^ t ^ (t <<  8)@
 and		\t, #0x0000FF00
    eors.w	\x0, \t
    eor		\x0, \x0, \t, lsl #8

    eor		\t, \x0, \x0, lsr #4	@ t = (x0 ^ (x0 >>  4)) & 0x00F000F0UL@  x0 = x0 ^ t ^ (t <<  4)@
 and		\t, #0x00F000F0
    eors.w	\x0, \t
    eor		\x0, \x0, \t, lsl #4

    eor		\t, \x0, \x0, lsr #2	@ t = (x0 ^ (x0 >>  2)) & 0x0C0C0C0CUL@  x0 = x0 ^ t ^ (t <<  2)@
 and		\t, #0x0C0C0C0C
    eors.w	\x0, \t
    eor		\x0, \x0, \t, lsl #2

    eor		\t, \x0, \x0, lsr #1	@ t = (x0 ^ (x0 >>  1)) & 0x22222222UL@  x0 = x0 ^ t ^ (t <<  1)@
 and		\t, #0x22222222
    eors.w	\x0, \t
    eor		\x0, \x0, \t, lsl #1

    eor		\t, \x1, \x1, lsr #8    @ t = (x1 ^ (x1 >>  8)) & 0x0000FF00UL@  x1 = x1 ^ t ^ (t <<  8)@
 and		\t, #0x0000FF00
    eors.w	\x1, \t
    eor		\x1, \x1, \t, lsl #8

    eor		\t, \x1, \x1, lsr #4	@ t = (x1 ^ (x1 >>  4)) & 0x00F000F0UL@  x1 = x1 ^ t ^ (t <<  4)@
 and		\t, #0x00F000F0
    eors.w	\x1, \t
    eor		\x1, \x1, \t, lsl #4

    eor		\t, \x1, \x1, lsr #2	@ t = (x1 ^ (x1 >>  2)) & 0x0C0C0C0CUL@  x1 = x1 ^ t ^ (t <<  2)@
 and		\t, #0x0C0C0C0C
    eors.w	\x1, \t
    eor		\x1, \x1, \t, lsl #2

    eor		\t, \x1, \x1, lsr #1	@ t = (x1 ^ (x1 >>  1)) & 0x22222222UL@  x1 = x1 ^ t ^ (t <<  1)@
 and		\t, #0x22222222
    eors.w	\x1, \t
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

 ldr			\result, [r0, #\b]   // @slothy:reads=[r0\()\b]
 ldr			r1, [r0, #\g]        // @slothy:reads=[r0\()\g]
 eors.w		\result, \result, r1
 ldr			r1, [r0, #\k]        // @slothy:reads=[r0\()\k]
 eors.w		\result, \result, r1
 ldr			r1, [r0, #\m]        // @slothy:reads=[r0\()\m]
 eors.w		\result, \result, r1
 ldr			r1, [r0, #\s]        // @slothy:reads=[r0\()\s]
 eors.w		\result, \result, r1
 .endm

.macro	xorrol 		result, aa, bb

 eor			\result, \aa, \bb, ror #31
 .endm

.macro	xandnot 	resofs, aa, bb, cc

 bic			r1, \cc, \bb
 eors.w		r1, r1, \aa
 str			r1, [r0, #\resofs] // @slothy:writes=[r0\()\resofs]
 .endm

.macro	KeccakThetaRhoPiChiIota aA1, aDax, aA2, aDex, rot2, aA3, aDix, rot3, aA4, aDox, rot4, aA5, aDux, rot5, offset, last
 ldr		r3, [r0, #\aA1] // @slothy:reads=[r0\()\aA1]
 ldr		r4, [r0, #\aA2] // @slothy:reads=[r0\()\aA2]
 ldr		r5, [r0, #\aA3] // @slothy:reads=[r0\()\aA3]
 ldr		r6, [r0, #\aA4] // @slothy:reads=[r0\()\aA4]
 ldr		r7, [r0, #\aA5] // @slothy:reads=[r0\()\aA5]
 eors.w	r3, \aDax
 eors.w	r5, \aDix
 eors.w	r4, \aDex
 eors.w	r6, \aDox
 eors.w	r7, \aDux
 rors	r4, #32-\rot2
 rors	r5, #32-\rot3
 rors	r6, #32-\rot4
 rors	r7, #32-\rot5
    xandnot \aA2, r4, r5, r6
    xandnot \aA3, r5, r6, r7
    xandnot \aA4, r6, r7, r3
    xandnot \aA5, r7, r3, r4
 ldr		r1, [sp, #mRC]
 bics	r5, r5, r4
 ldr		r4, [r1, #\offset]
 eors.w	r3, r5
 eors.w	r3, r4
 .if	\last == 1
 ldr		r4, [r1, #32]!
 str		r1, [sp, #mRC]
 cmp		r4, #0xFF
 .endif
 str		r3, [r0, #\aA1] // @slothy:writes=[r0\()\aA1]
 .endm

.macro	KeccakThetaRhoPiChi aB1, aA1, aDax, rot1, aB2, aA2, aDex, rot2, aB3, aA3, aDix, rot3, aB4, aA4, aDox, rot4, aB5, aA5, aDux, rot5
 ldr		\aB1, [r0, #\aA1] // @slothy:reads=[r0\()\aA1]
 ldr		\aB2, [r0, #\aA2] // @slothy:reads=[r0\()\aA2]
 ldr		\aB3, [r0, #\aA3] // @slothy:reads=[r0\()\aA3]
 ldr		\aB4, [r0, #\aA4] // @slothy:reads=[r0\()\aA4]
 ldr		\aB5, [r0, #\aA5] // @slothy:reads=[r0\()\aA5]
 eors.w	\aB1, \aDax
 eors.w	\aB3, \aDix
 eors.w	\aB2, \aDex
 eors.w	\aB4, \aDox
 eors.w	\aB5, \aDux
 rors	\aB1, #32-\rot1
 .if	\rot2 > 0
 rors	\aB2, #32-\rot2
 .endif
 rors	\aB3, #32-\rot3
 rors	\aB4, #32-\rot4
 rors	\aB5, #32-\rot5
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
 str			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
 xor5        r6,  Abu1, Agu1, Aku1, Amu1, Asu1
 xor5        lr, Abe0, Age0, Ake0, Ame0, Ase0
 eors.w      r8, r6, lr
 str			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

 xor5        r5,  Abi0, Agi0, Aki0, Ami0, Asi0
 xorrol      r9, r5, r6
 str			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
 xor5        r4,  Abi1, Agi1, Aki1, Ami1, Asi1
 eors.w		r3, r3, r4
 str			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

 xor5        r3,  Aba0, Aga0, Aka0, Ama0, Asa0
 xorrol      r10, r3, r4
 xor5        r6,  Aba1, Aga1, Aka1, Ama1, Asa1
 eors.w      r11, r6, r5

 xor5        r4,  Abo1, Ago1, Ako1, Amo1, Aso1
 xorrol      r5, lr, r4
 str			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
 xor5        r5,  Abo0, Ago0, Ako0, Amo0, Aso0
 eors.w      r2, r7, r5

 xorrol      r12, r5, r6
 eors.w      lr, r4, r3
 KeccakThetaRhoPiChi r5, Aka1, r8,  2, r6, Ame1, r11, 23, r7, Asi1, r2, 31, r3, Abo0, r9, 14, r4, Agu0, r12, 10
 KeccakThetaRhoPiChi r7, Asa1, r8,  9, r3, Abe0, r10,  0, r4, Agi1, r2,  3, r5, Ako0, r9, 12, r6, Amu1, lr,  4
 ldr			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
 KeccakThetaRhoPiChi r4, Aga0, r8, 18, r5, Ake0, r10,  5, r6, Ami1, r2,  8, r7, Aso0, r9, 28, r3, Abu1, lr, 14
 KeccakThetaRhoPiChi r6, Ama0, r8, 20, r7, Ase1, r11,  1, r3, Abi1, r2, 31, r4, Ago0, r9, 27, r5, Aku0, r12, 19
 ldr			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
 KeccakThetaRhoPiChiIota  Aba0, r8,          Age0, r10, 22,      Aki1, r2, 22,      Amo1, r9, 11,      Asu0, r12,  7, 0, 0

 ldr			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
 KeccakThetaRhoPiChi r5, Aka0, r8,  1, r6, Ame0, r10, 22, r7, Asi0, r2, 30, r3, Abo1, r9, 14, r4, Agu1, lr, 10
 KeccakThetaRhoPiChi r7, Asa0, r8,  9, r3, Abe1, r11,  1, r4, Agi0, r2,  3, r5, Ako1, r9, 13, r6, Amu0, r12,  4
 ldr			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
 KeccakThetaRhoPiChi r4, Aga1, r8, 18, r5, Ake1, r11,  5, r6, Ami0, r2,  7, r7, Aso1, r9, 28, r3, Abu0, r12, 13
 KeccakThetaRhoPiChi r6, Ama1, r8, 21, r7, Ase0, r10,  1, r3, Abi0, r2, 31, r4, Ago1, r9, 28, r5, Aku1, lr, 20
 ldr			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
 KeccakThetaRhoPiChiIota  Aba1, r8,          Age1, r11, 22,      Aki0, r2, 21,      Amo0, r9, 10,      Asu1, lr,  7, 4, 0
 .endm

.macro	KeccakRound1

 xor5        r3,  Asu0, Agu0, Amu0, Abu1, Aku1
 xor5        r7, Age1, Ame0, Abe0, Ake1, Ase1
 xorrol      r6, r3, r7
 str			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
 xor5        r6,  Asu1, Agu1, Amu1, Abu0, Aku0
 xor5        lr, Age0, Ame1, Abe1, Ake0, Ase0
 eors.w      r8, r6, lr
 str			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

 xor5        r5,  Aki1, Asi1, Agi0, Ami1, Abi0
 xorrol      r9, r5, r6
 str			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
 xor5        r4,  Aki0, Asi0, Agi1, Ami0, Abi1
 eors.w		r3, r4
 str			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

 xor5        r3,  Aba0, Aka1, Asa0, Aga0, Ama1
 xorrol      r10, r3, r4
 xor5        r6,  Aba1, Aka0, Asa1, Aga1, Ama0
 eors.w      r11, r6, r5

 xor5        r4,  Amo0, Abo1, Ako0, Aso1, Ago0
 xorrol      r5, lr, r4
 str			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
 xor5        r5,  Amo1, Abo0, Ako1, Aso0, Ago1
 eors.w      r2, r7, r5

 xorrol      r12, r5, r6
 eors.w      lr, r4, r3

 KeccakThetaRhoPiChi r5, Asa1, r8,  2, r6, Ake1, r11, 23, r7, Abi1, r2, 31, r3, Amo1, r9, 14, r4, Agu0, r12, 10
 KeccakThetaRhoPiChi r7, Ama0, r8,  9, r3, Age0, r10,  0, r4, Asi0, r2,  3, r5, Ako1, r9, 12, r6, Abu0, lr,  4
 ldr			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
 KeccakThetaRhoPiChi r4, Aka1, r8, 18, r5, Abe1, r10,  5, r6, Ami0, r2,  8, r7, Ago1, r9, 28, r3, Asu1, lr, 14
 KeccakThetaRhoPiChi r6, Aga0, r8, 20, r7, Ase1, r11,  1, r3, Aki0, r2, 31, r4, Abo0, r9, 27, r5, Amu0, r12, 19
 ldr			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
 KeccakThetaRhoPiChiIota  Aba0, r8,          Ame1, r10, 22,      Agi1, r2, 22,      Aso1, r9, 11,      Aku1, r12,  7, 8, 0

 ldr			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
 KeccakThetaRhoPiChi r5, Asa0, r8,  1, r6, Ake0, r10, 22, r7, Abi0, r2, 30, r3, Amo0, r9, 14, r4, Agu1, lr, 10
 KeccakThetaRhoPiChi r7, Ama1, r8,  9, r3, Age1, r11,  1, r4, Asi1, r2,  3, r5, Ako0, r9, 13, r6, Abu1, r12,  4
 ldr			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
 KeccakThetaRhoPiChi r4, Aka0, r8, 18, r5, Abe0, r11,  5, r6, Ami1, r2,  7, r7, Ago0, r9, 28, r3, Asu0, r12, 13
 KeccakThetaRhoPiChi r6, Aga1, r8, 21, r7, Ase0, r10,  1, r3, Aki1, r2, 31, r4, Abo1, r9, 28, r5, Amu1, lr, 20
 ldr			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
 KeccakThetaRhoPiChiIota  Aba1, r8,          Ame0, r11, 22,      Agi0, r2, 21,      Aso0, r9, 10,      Aku0, lr,  7, 12, 0
 .endm

.macro	KeccakRound2

 xor5        r3, Aku1, Agu0, Abu1, Asu1, Amu1
 xor5        r7, Ame0, Ake0, Age0, Abe0, Ase1
 xorrol      r6, r3, r7
 str			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
 xor5        r6,  Aku0, Agu1, Abu0, Asu0, Amu0
 xor5        lr, Ame1, Ake1, Age1, Abe1, Ase0
 eors.w      r8, r6, lr
 str			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

 xor5        r5,  Agi1, Abi1, Asi1, Ami0, Aki1
 xorrol      r9, r5, r6
 str			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
 xor5        r4,  Agi0, Abi0, Asi0, Ami1, Aki0
 eors.w		r3, r4
 str			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

 xor5        r3,  Aba0, Asa1, Ama1, Aka1, Aga1
 xorrol      r10, r3, r4
 xor5        r6,  Aba1, Asa0, Ama0, Aka0, Aga0
 eors.w      r11, r6, r5

 xor5        r4,  Aso0, Amo0, Ako1, Ago0, Abo0
 xorrol      r5, lr, r4
 str			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
 xor5        r5,  Aso1, Amo1, Ako0, Ago1, Abo1
 eors.w      r2, r7, r5

 xorrol      r12, r5, r6
 eors.w      lr, r4, r3

 KeccakThetaRhoPiChi r5, Ama0, r8,  2, r6, Abe0, r11, 23, r7, Aki0, r2, 31, r3, Aso1, r9, 14, r4, Agu0, r12, 10
 KeccakThetaRhoPiChi r7, Aga0, r8,  9, r3, Ame1, r10,  0, r4, Abi0, r2,  3, r5, Ako0, r9, 12, r6, Asu0, lr,  4
 ldr			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
 KeccakThetaRhoPiChi r4, Asa1, r8, 18, r5, Age1, r10,  5, r6, Ami1, r2,  8, r7, Abo1, r9, 28, r3, Aku0, lr, 14
 KeccakThetaRhoPiChi r6, Aka1, r8, 20, r7, Ase1, r11,  1, r3, Agi0, r2, 31, r4, Amo1, r9, 27, r5, Abu1, r12, 19
 ldr			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
 KeccakThetaRhoPiChiIota  Aba0, r8,          Ake1, r10, 22,      Asi0, r2, 22,      Ago0, r9, 11,      Amu1, r12,  7, 16, 0

 ldr			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
 KeccakThetaRhoPiChi r5, Ama1, r8,  1, r6, Abe1, r10, 22, r7, Aki1, r2, 30, r3, Aso0, r9, 14, r4, Agu1, lr, 10
 KeccakThetaRhoPiChi r7, Aga1, r8,  9, r3, Ame0, r11,  1, r4, Abi1, r2,  3, r5, Ako1, r9, 13, r6, Asu1, r12,  4
 ldr			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
 KeccakThetaRhoPiChi r4, Asa0, r8, 18, r5, Age0, r11,  5, r6, Ami0, r2,  7, r7, Abo0, r9, 28, r3, Aku1, r12, 13
 KeccakThetaRhoPiChi r6, Aka0, r8, 21, r7, Ase0, r10,  1, r3, Agi1, r2, 31, r4, Amo0, r9, 28, r5, Abu0, lr, 20
 ldr			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
 KeccakThetaRhoPiChiIota  Aba1, r8,          Ake0, r11, 22,      Asi1, r2, 21,      Ago1, r9, 10,      Amu0, lr,  7, 20, 0
 .endm

.macro	KeccakRound3

 xor5        r3,  Amu1, Agu0, Asu1, Aku0, Abu0
 xor5        r7, Ake0, Abe1, Ame1, Age0, Ase1
 xorrol      r6, r3, r7
 str			r6, [sp, #mDa0] // @slothy:writes=[sp\()\mDa0]
 xor5        r6,  Amu0, Agu1, Asu0, Aku1, Abu1
 xor5        lr, Ake1, Abe0, Ame0, Age1, Ase0
 eors.w      r8, r6, lr
 str			r8, [sp, #mDa1] // @slothy:writes=[sp\()\mDa1]

 xor5        r5,  Asi0, Aki0, Abi1, Ami1, Agi1
 xorrol      r9, r5, r6
 str			r9, [sp, #mDo0] // @slothy:writes=[sp\()\mDo0]
 xor5        r4,  Asi1, Aki1, Abi0, Ami0, Agi0
 eors.w		r3, r4
 str			r3, [sp, #mDo1] // @slothy:writes=[sp\()\mDo1]

 xor5        r3,  Aba0, Ama0, Aga1, Asa1, Aka0
 xorrol      r10, r3, r4
 xor5        r6,  Aba1, Ama1, Aga0, Asa0, Aka1
 eors.w      r11, r6, r5

 xor5        r4,  Ago1, Aso0, Ako0, Abo0, Amo1
 xorrol      r5, lr, r4
 str			r5, [sp, #mDi0] // @slothy:writes=[sp\()\mDi0]
 xor5        r5,  Ago0, Aso1, Ako1, Abo1, Amo0
 eors.w      r2, r7, r5

 xorrol      r12, r5, r6
 eors.w      lr, r4, r3

 KeccakThetaRhoPiChi r5, Aga0, r8,  2, r6, Age0, r11, 23, r7, Agi0, r2, 31, r3, Ago0, r9, 14, r4, Agu0, r12, 10
 KeccakThetaRhoPiChi r7, Aka1, r8,  9, r3, Ake1, r10,  0, r4, Aki1, r2,  3, r5, Ako1, r9, 12, r6, Aku1, lr,  4
 ldr			r8, [sp, #mDa0] // @slothy:reads=[sp\()\mDa0]
 KeccakThetaRhoPiChi r4, Ama0, r8, 18, r5, Ame0, r10,  5, r6, Ami0, r2,  8, r7, Amo0, r9, 28, r3, Amu0, lr, 14
 KeccakThetaRhoPiChi r6, Asa1, r8, 20, r7, Ase1, r11,  1, r3, Asi1, r2, 31, r4, Aso1, r9, 27, r5, Asu1, r12, 19
 ldr			r9, [sp, #mDo1] // @slothy:reads=[sp\()\mDo1]
 KeccakThetaRhoPiChiIota  Aba0, r8,          Abe0, r10, 22,      Abi0, r2, 22,      Abo0, r9, 11,      Abu0, r12,  7, 24, 0

 ldr			r2, [sp, #mDi0] // @slothy:reads=[sp\()\mDi0]
 KeccakThetaRhoPiChi r5, Aga1, r8,  1, r6, Age1, r10, 22, r7, Agi1, r2, 30, r3, Ago1, r9, 14, r4, Agu1, lr, 10
 KeccakThetaRhoPiChi r7, Aka0, r8,  9, r3, Ake0, r11,  1, r4, Aki0, r2,  3, r5, Ako0, r9, 13, r6, Aku0, r12,  4
 ldr			r8, [sp, #mDa1] // @slothy:reads=[sp\()\mDa1]
 KeccakThetaRhoPiChi r4, Ama1, r8, 18, r5, Ame1, r11,  5, r6, Ami1, r2,  7, r7, Amo1, r9, 28, r3, Amu1, r12, 13
 KeccakThetaRhoPiChi r6, Asa0, r8, 21, r7, Ase0, r10,  1, r3, Asi0, r2, 31, r4, Aso0, r9, 28, r5, Asu0, lr, 20
 ldr			r9, [sp, #mDo0] // @slothy:reads=[sp\()\mDo0]
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
 bic		r4, r2, #7								@ offset &= ~7
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
 ldr		r4, [r1], #4
 ldr		r5, [r1], #4
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
 bic		r4, r2, #7								@ offset &= ~7
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
 str		r4, [r1], #4
 subs	r2, r2, #1
 str		r5, [r1], #4
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
.global   KeccakF1600_StatePermute_part_opt_m7
KeccakF1600_StatePermute_part_opt_m7:
 adr		r1, KeccakF1600_StatePermute_RoundConstantsWithTerminator
 push	{ r4 - r12, lr }
 sub		sp, #mSize
 str		r1, [sp, #mRC]
        slothy_start:
                                         // Instructions:    73
                                         // Expected cycles: 39
                                         // Expected IPC:    1.87
                                         //
                                         // Cycle bound:     37.0
                                         // IPC bound:       1.97
                                         //
                                         // Wall time:     15.00s
                                         // User time:     15.00s
                                         //
                                         // -------------------------- original position --------------------------->
                                         // 0                        25                       50
                                         // |------------------------|------------------------|----------------------
        ldr r2, [r0, #Aso1]              // ...........................*............................................. // @slothy:reads=[r0\()Aso1]
        ldr r11, [r0, #Ago1]             // .....................*................................................... // @slothy:reads=[r0\()Ago1]
        ldr r12, [r0, #Aga1]             // ...........*............................................................. // @slothy:reads=[r0\()Aga1]
        ldr r1, [r0, #Abo1]              // ....................*.................................................... // @slothy:reads=[r0\()Abo1]
        eors.w r10, r1, r11              // ......................*..................................................
        ldr r6, [r0, #Aka1]              // .............*........................................................... // @slothy:reads=[r0\()Aka1]
        ldr r1, [r0, #Aba0]              // *........................................................................ // @slothy:reads=[r0\()Aba0]
        ldr r11, [r0, #Aba1]             // ..........*.............................................................. // @slothy:reads=[r0\()Aba1]
        ldr r3, [r0, #Aka0]              // ...*..................................................................... // @slothy:reads=[r0\()Aka0]
        eors.w r11, r11, r12             // ............*............................................................
        ldr r12, [r0, #Ama1]             // ...............*......................................................... // @slothy:reads=[r0\()Ama1]
        eors.w r6, r11, r6               // ..............*..........................................................
        ldr r11, [r0, #Asa1]             // .................*....................................................... // @slothy:reads=[r0\()Asa1]
        eors.w r12, r6, r12              // ................*........................................................
        ldr r6, [r0, #Aga0]              // .*....................................................................... // @slothy:reads=[r0\()Aga0]
        eors.w r12, r12, r11             // ..................*......................................................
        eors.w r11, r12, r5              // ...................*.....................................................
        eors.w r1, r1, r6                // ..*......................................................................
        ldr r5, [r0, #Ama0]              // .....*................................................................... // @slothy:reads=[r0\()Ama0]
        eors.w r3, r1, r3                // ....*....................................................................
        ldr r6, [r0, #Asa0]              // .......*................................................................. // @slothy:reads=[r0\()Asa0]
        eors.w r1, r3, r5                // ......*..................................................................
        eors.w r3, r1, r6                // ........*................................................................
        ldr r6, [r0, #Ame1]              // ............................................*............................ // @slothy:reads=[r0\()Ame1]
        ldr r5, [r0, #Ako1]              // .......................*................................................. // @slothy:reads=[r0\()Ako1]
        ldr r1, [r0, #Abo0]              // ..............................................*.......................... // @slothy:reads=[r0\()Abo0]
        eors.w r10, r10, r5              // ........................*................................................
        ldr r5, [r0, #Amo1]              // .........................*............................................... // @slothy:reads=[r0\()Amo1]
        eors.w r1, r9                    // ...................................................*.....................
        eors.w r5, r10, r5               // ..........................*..............................................
        eors.w r2, r5, r2                // ............................*............................................
        eors.w r6, r11                   // ..................................................*......................
        eor r10, r3, r4, ror #31         // .........*...............................................................
        ldr r5, [r0, #Abo0]              // ...............................*......................................... // @slothy:reads=[r0\()Abo0]
        eor r4, r14, r2, ror #31         // .............................*...........................................
        eors.w r14, r2, r3               // ..........................................*..............................
        ldr r3, [r0, #Ago0]              // ................................*........................................ // @slothy:reads=[r0\()Ago0]
        rors r1, #32-14                  // ........................................................*................
        ldr r2, [r0, #Ako0]              // ..................................*...................................... // @slothy:reads=[r0\()Ako0]
        eors.w r5, r5, r3                // .................................*.......................................
        ldr r3, [r0, #Amo0]              // ....................................*.................................... // @slothy:reads=[r0\()Amo0]
        eors.w r2, r5, r2                // ...................................*.....................................
        ldr r5, [r0, #Aso0]              // ......................................*.................................. // @slothy:reads=[r0\()Aso0]
        eors.w r2, r2, r3                // .....................................*...................................
        rors r6, #32-23                  // ......................................................*..................
        eors.w r3, r2, r5                // .......................................*.................................
        eors.w r2, r7, r3                // ........................................*................................
        ldr r7, [r0, #Asi1]              // .............................................*........................... // @slothy:reads=[r0\()Asi1]
        eor r12, r3, r12, ror #31        // .........................................*...............................
        ldr r5, [r0, #Aka1]              // ...........................................*............................. // @slothy:reads=[r0\()Aka1]
        eors.w r7, r2                    // .................................................*.......................
        str r4, [sp, #mDi0]              // ..............................*.......................................... // @slothy:writes=[sp\()\mDi0]
        rors r7, #32-31                  // .......................................................*.................
        eors.w r5, r8                    // ................................................*........................
        bic r4, r1, r7                   // ...................................................................*.....
        rors r5, #32-2                   // .....................................................*...................
        eors.w r3, r4, r6                // ....................................................................*....
        ldr r4, [r0, #Agu0]              // ...............................................*......................... // @slothy:reads=[r0\()Agu0]
        str r3, [r0, #Abo0]              // .....................................................................*... // @slothy:writes=[r0\()Abo0]
        bic r3, r7, r6                   // ................................................................*........
        eors.w r4, r12                   // ....................................................*....................
        eors.w r3, r3, r5                // .................................................................*.......
        rors r4, #32-10                  // .........................................................*...............
        str r3, [r0, #Asi1]              // ..................................................................*...... // @slothy:writes=[r0\()Asi1]
        bic r3, r4, r1                   // ......................................................................*..
        bic r6, r6, r5                   // .............................................................*...........
        eors.w r6, r6, r4                // ..............................................................*..........
        // gap                           // .........................................................................
        str r6, [r0, #Ame1]              // ...............................................................*......... // @slothy:writes=[r0\()Ame1]
        bic r6, r5, r4                   // ..........................................................*..............
        eors.w r1, r6, r1                // ...........................................................*.............
        eors.w r3, r3, r7                // .......................................................................*.
        // gap                           // .........................................................................
        str r3, [r0, #Agu0]              // ........................................................................* // @slothy:writes=[r0\()Agu0]
        // gap                           // .........................................................................
        // gap                           // .........................................................................
        str r1, [r0, #Aka1]              // ............................................................*............ // @slothy:writes=[r0\()Aka1]
        // gap                           // .........................................................................

                                              // ----------------------------- new position ----------------------------->
                                              // 0                        25                       50
                                              // |------------------------|------------------------|----------------------
        // ldr			r3, [r0, #Aba0]              // ......*..................................................................
        // ldr			r1, [r0, #Aga0]              // ..............*..........................................................
        // eors.w		r3, r3, r1                 // .................*.......................................................
        // ldr			r1, [r0, #Aka0]              // ........*................................................................
        // eors.w		r3, r3, r1                 // ...................*.....................................................
        // ldr			r1, [r0, #Ama0]              // ..................*......................................................
        // eors.w		r3, r3, r1                 // .....................*...................................................
        // ldr			r1, [r0, #Asa0]              // ....................*....................................................
        // eors.w		r3, r3, r1                 // ......................*..................................................
        // eor			r10, r3, r4, ror #31         // ................................*........................................
        // ldr			r6, [r0, #Aba1]              // .......*.................................................................
        // ldr			r1, [r0, #Aga1]              // ..*......................................................................
        // eors.w		r6, r6, r1                 // .........*...............................................................
        // ldr			r1, [r0, #Aka1]              // .....*...................................................................
        // eors.w		r6, r6, r1                 // ...........*.............................................................
        // ldr			r1, [r0, #Ama1]              // ..........*..............................................................
        // eors.w		r6, r6, r1                 // .............*...........................................................
        // ldr			r1, [r0, #Asa1]              // ............*............................................................
        // eors.w		r6, r6, r1                 // ...............*.........................................................
        // eors.w      r11, r6, r5            // ................*........................................................
        // ldr			r4, [r0, #Abo1]              // ...*.....................................................................
        // ldr			r1, [r0, #Ago1]              // .*.......................................................................
        // eors.w		r4, r4, r1                 // ....*....................................................................
        // ldr			r1, [r0, #Ako1]              // ........................*................................................
        // eors.w		r4, r4, r1                 // ..........................*..............................................
        // ldr			r1, [r0, #Amo1]              // ...........................*.............................................
        // eors.w		r4, r4, r1                 // .............................*...........................................
        // ldr			r1, [r0, #Aso1]              // *........................................................................
        // eors.w		r4, r4, r1                 // ..............................*..........................................
        // eor			r5, r14, r4, ror #31         // ..................................*......................................
        // str			r5, [sp, #mDi0]              // ...................................................*.....................
        // ldr			r5, [r0, #Abo0]              // .................................*.......................................
        // ldr			r1, [r0, #Ago0]              // ....................................*....................................
        // eors.w		r5, r5, r1                 // .......................................*.................................
        // ldr			r1, [r0, #Ako0]              // ......................................*..................................
        // eors.w		r5, r5, r1                 // .........................................*...............................
        // ldr			r1, [r0, #Amo0]              // ........................................*................................
        // eors.w		r5, r5, r1                 // ...........................................*.............................
        // ldr			r1, [r0, #Aso0]              // ..........................................*..............................
        // eors.w		r5, r5, r1                 // .............................................*...........................
        // eors.w      r2, r7, r5             // ..............................................*..........................
        // eor			r12, r5, r6, ror #31         // ................................................*........................
        // eors.w      r14, r4, r3            // ...................................*.....................................
        // ldr		r5, [r0, #Aka1]               // .................................................*.......................
        // ldr		r6, [r0, #Ame1]               // .......................*.................................................
        // ldr		r7, [r0, #Asi1]               // ...............................................*.........................
        // ldr		r3, [r0, #Abo0]               // .........................*...............................................
        // ldr		r4, [r0, #Agu0]               // .........................................................*...............
        // eors.w	r5, r8                      // .....................................................*...................
        // eors.w	r7, r2                      // ..................................................*......................
        // eors.w	r6, r11                     // ...............................*.........................................
        // eors.w	r3, r9                      // ............................*............................................
        // eors.w	r4, r12                     // ............................................................*............
        // rors	r5, #32-2                     // .......................................................*.................
        // rors	r6, #32-23                    // ............................................*............................
        // rors	r7, #32-31                    // ....................................................*....................
        // rors	r3, #32-14                    // .....................................*...................................
        // rors	r4, #32-10                    // ..............................................................*..........
        // bic			r1, r5, r4                   // ....................................................................*....
        // eors.w		r1, r1, r3                 // .....................................................................*...
        // str			r1, [r0, #Aka1]              // ........................................................................*
        // bic			r1, r6, r5                   // .................................................................*.......
        // eors.w		r1, r1, r4                 // ..................................................................*......
        // str			r1, [r0, #Ame1]              // ...................................................................*.....
        // bic			r1, r7, r6                   // ...........................................................*.............
        // eors.w		r1, r1, r5                 // .............................................................*...........
        // str			r1, [r0, #Asi1]              // ...............................................................*.........
        // bic			r1, r3, r7                   // ......................................................*..................
        // eors.w		r1, r1, r6                 // ........................................................*................
        // str			r1, [r0, #Abo0]              // ..........................................................*..............
        // bic			r1, r4, r3                   // ................................................................*........
        // eors.w		r1, r1, r7                 // ......................................................................*..
        // str			r1, [r0, #Agu0]              // .......................................................................*.

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      7300
        // Total Cycles:      4502
        // Total uOps:        7300
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.62
        // IPC:               1.62
        // Block RThroughput: 36.5
        //
        //
        // Cycles with backend pressure increase [ 35.54% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 6.66% ]
        //   Data Dependencies:      [ 28.88% ]
        //   - Register Dependencies [ 28.88% ]
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
        //  1      2     0.50    *                   ldr	r3, [r0]
        //  1      2     0.50    *                   ldr	r1, [r0, #40]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #80]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #120]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #160]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     1.00                        eor.w	r10, r3, r4, ror #31
        //  1      2     0.50    *                   ldr	r6, [r0, #4]
        //  1      2     0.50    *                   ldr	r1, [r0, #44]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #84]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #124]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #164]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      1     0.50                        eors.w	r11, r6, r5
        //  1      2     0.50    *                   ldr	r4, [r0, #28]
        //  1      2     0.50    *                   ldr	r1, [r0, #68]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #108]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #148]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #188]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     1.00                        eor.w	r5, lr, r4, ror #31
        //  1      3     1.00           *            str	r5, [sp, #16]
        //  1      2     0.50    *                   ldr	r5, [r0, #24]
        //  1      2     0.50    *                   ldr	r1, [r0, #64]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #104]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #144]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #184]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      1     0.50                        eors.w	r2, r7, r5
        //  1      2     1.00                        eor.w	r12, r5, r6, ror #31
        //  1      1     0.50                        eors.w	lr, r4, r3
        //  1      2     0.50    *                   ldr	r5, [r0, #84]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #132]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #180]
        //  1      2     0.50    *                   ldr	r3, [r0, #24]
        //  1      2     0.50    *                   ldr	r4, [r0, #72]
        //  1      1     0.50                        eors.w	r5, r5, r8
        //  1      1     0.50                        eors.w	r7, r7, r2
        //  1      1     0.50                        eors.w	r6, r6, r11
        //  1      1     0.50                        eors.w	r3, r3, r9
        //  1      1     0.50                        eors.w	r4, r4, r12
        //  1      1     1.00                        rors.w	r5, r5, #30
        //  1      1     1.00                        rors.w	r6, r6, #9
        //  1      1     1.00                        rors.w	r7, r7, #1
        //  1      1     1.00                        rors.w	r3, r3, #18
        //  1      1     1.00                        rors.w	r4, r4, #22
        //  1      1     0.50                        bic.w	r1, r5, r4
        //  1      1     0.50                        eors.w	r1, r1, r3
        //  1      3     1.00           *            str	r1, [r0, #84]
        //  1      1     0.50                        bic.w	r1, r6, r5
        //  1      1     0.50                        eors.w	r1, r1, r4
        //  1      3     1.00           *            str.w	r1, [r0, #132]
        //  1      1     0.50                        bic.w	r1, r7, r6
        //  1      1     0.50                        eors.w	r1, r1, r5
        //  1      3     1.00           *            str.w	r1, [r0, #180]
        //  1      1     0.50                        bic.w	r1, r3, r7
        //  1      1     0.50                        eors.w	r1, r1, r6
        //  1      3     1.00           *            str	r1, [r0, #24]
        //  1      1     0.50                        bic.w	r1, r4, r3
        //  1      1     0.50                        eors.w	r1, r1, r7
        //  1      3     1.00           *            str	r1, [r0, #72]
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      1300  (28.9%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 300  (6.7%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              102  (2.3%)
        //  1,              1500  (33.3%)
        //  2,              2900  (64.4%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          102  (2.3%)
        //  1,          1500  (33.3%)
        //  2,          2900  (64.4%)
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
        // 21.00  21.00   -     12.50  12.50   -      -     8.00    -     6.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #40]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #80]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #120]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #160]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r10, r3, r4, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #44]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #84]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #124]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #164]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, r6, r5
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #28]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #68]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #108]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #148]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #188]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r5, lr, r4, ror #31
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [sp, #16]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #24]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #64]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #104]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #144]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #184]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r7, r5
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r12, r5, r6, ror #31
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, r4, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #84]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #132]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #180]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #24]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #72]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r8
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r9
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r12
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r5, r5, #30
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r6, r6, #9
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r7, r7, #1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r3, r3, #18
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r4, r4, #22
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r1, r5, r4
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r3
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0, #84]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r1, r6, r5
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r1, [r0, #132]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r1, r7, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r5
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r1, [r0, #180]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r1, r3, r7
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r6
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0, #24]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r1, r4, r3
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r7
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0, #72]
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,9]     .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [0,10]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [0,11]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [0,12]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,13]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [0,14]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,15]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [0,16]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,17]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [0,18]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,19]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [0,20]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [0,21]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [0,22]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,23]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [0,24]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,25]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [0,26]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,27]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [0,28]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,29]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [0,30]    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #16]
        // [0,31]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [0,32]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [0,33]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,34]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #104]
        // [0,35]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,36]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [0,37]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,38]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [0,39]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,40]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r7, r5
        // [0,41]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [0,42]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r4, r3
        // [0,43]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #84]
        // [0,44]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #132]
        // [0,45]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #180]
        // [0,46]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [0,47]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #72]
        // [0,48]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [0,49]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r2
        // [0,50]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r11
        // [0,51]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r9
        // [0,52]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [0,53]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r5, r5, #30
        // [0,54]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #9
        // [0,55]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #1
        // [0,56]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r3, r3, #18
        // [0,57]    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r4, r4, #22
        // [0,58]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r5, r4
        // [0,59]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r3
        // [0,60]    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #84]
        // [0,61]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r6, r5
        // [0,62]    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [0,63]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #132]
        // [0,64]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r7, r6
        // [0,65]    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r5
        // [0,66]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #180]
        // [0,67]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r3, r7
        // [0,68]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r6
        // [0,69]    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #24]
        // [0,70]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r4, r3
        // [0,71]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r7
        // [0,72]    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #72]
        // [1,0]     .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [1,1]     .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [1,2]     .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,3]     .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [1,4]     .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,5]     .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [1,6]     .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,7]     .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [1,8]     .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,9]     .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [1,10]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [1,12]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,13]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #16]
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #104]
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r7, r5
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r4, r3
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #84]
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #132]
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #180]
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #72]
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r2
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r11
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r9
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r5, r5, #30
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #9
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #1
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r3, r3, #18
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r4, r4, #22
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r5, r4
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r3
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #84]
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r6, r5
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #132]
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r7, r6
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r5
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #180]
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r3, r7
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r6
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #24]
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    ..   bic.w	r1, r4, r3
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r7
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    ..   str	r1, [r0, #72]
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    ..   str	r5, [sp, #16]
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   ldr	r1, [r0, #104]
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    ..   eors.w	r5, r5, r1
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    ..   eors.w	r2, r7, r5
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   eors.w	lr, r4, r3
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   ldr	r5, [r0, #84]
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r6, [r0, #132]
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r7, [r0, #180]
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr	r3, [r0, #24]
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr	r4, [r0, #72]
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   eors.w	r5, r5, r8
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   eors.w	r7, r7, r2
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   eors.w	r6, r6, r11
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   eors.w	r3, r3, r9
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   eors.w	r4, r4, r12
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   rors.w	r5, r5, #30
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   rors.w	r6, r6, #9
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   rors.w	r7, r7, #1
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   rors.w	r3, r3, #18
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   rors.w	r4, r4, #22
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   bic.w	r1, r5, r4
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    ..   eors.w	r1, r1, r3
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    ..   str	r1, [r0, #84]
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    ..   bic.w	r1, r6, r5
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    ..   eors.w	r1, r1, r4
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    ..   str.w	r1, [r0, #132]
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    ..   bic.w	r1, r7, r6
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   ..   eors.w	r1, r1, r5
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  ..   str.w	r1, [r0, #180]
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  ..   bic.w	r1, r3, r7
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE ..   eors.w	r1, r1, r6
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE..   str	r1, [r0, #24]
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE..   bic.w	r1, r4, r3
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE.   eors.w	r1, r1, r7
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   str	r1, [r0, #72]
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r3, [r0]
        // 1.     3     0.0    0.0    0.0       ldr	r1, [r0, #40]
        // 2.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 3.     3     0.0    0.0    0.0       ldr	r1, [r0, #80]
        // 4.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 5.     3     0.0    0.0    0.0       ldr	r1, [r0, #120]
        // 6.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 7.     3     0.0    0.0    0.0       ldr.w	r1, [r0, #160]
        // 8.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 9.     3     0.0    0.0    0.0       eor.w	r10, r3, r4, ror #31
        // 10.    3     0.0    0.0    0.0       ldr	r6, [r0, #4]
        // 11.    3     0.0    0.0    0.0       ldr	r1, [r0, #44]
        // 12.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 13.    3     0.0    0.0    0.0       ldr	r1, [r0, #84]
        // 14.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 15.    3     0.0    0.0    0.0       ldr	r1, [r0, #124]
        // 16.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 17.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #164]
        // 18.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 19.    3     0.0    0.0    0.0       eors.w	r11, r6, r5
        // 20.    3     0.0    0.0    0.0       ldr	r4, [r0, #28]
        // 21.    3     0.0    0.0    0.0       ldr	r1, [r0, #68]
        // 22.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 23.    3     0.0    0.0    0.0       ldr	r1, [r0, #108]
        // 24.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 25.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #148]
        // 26.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 27.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #188]
        // 28.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 29.    3     0.0    0.0    0.0       eor.w	r5, lr, r4, ror #31
        // 30.    3     0.0    0.0    0.0       str	r5, [sp, #16]
        // 31.    3     0.0    0.0    0.0       ldr	r5, [r0, #24]
        // 32.    3     0.0    0.0    0.0       ldr	r1, [r0, #64]
        // 33.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 34.    3     0.0    0.0    0.0       ldr	r1, [r0, #104]
        // 35.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 36.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #144]
        // 37.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 38.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #184]
        // 39.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 40.    3     0.0    0.0    0.0       eors.w	r2, r7, r5
        // 41.    3     0.0    0.0    0.0       eor.w	r12, r5, r6, ror #31
        // 42.    3     0.0    0.0    0.0       eors.w	lr, r4, r3
        // 43.    3     0.0    0.0    0.0       ldr	r5, [r0, #84]
        // 44.    3     0.0    0.0    0.0       ldr.w	r6, [r0, #132]
        // 45.    3     0.0    0.0    0.0       ldr.w	r7, [r0, #180]
        // 46.    3     0.0    0.0    0.0       ldr	r3, [r0, #24]
        // 47.    3     0.0    0.0    0.0       ldr	r4, [r0, #72]
        // 48.    3     0.0    0.0    0.0       eors.w	r5, r5, r8
        // 49.    3     0.0    0.0    0.0       eors.w	r7, r7, r2
        // 50.    3     0.0    0.0    0.0       eors.w	r6, r6, r11
        // 51.    3     0.0    0.0    0.0       eors.w	r3, r3, r9
        // 52.    3     0.0    0.0    0.0       eors.w	r4, r4, r12
        // 53.    3     0.0    0.0    0.0       rors.w	r5, r5, #30
        // 54.    3     0.0    0.0    0.0       rors.w	r6, r6, #9
        // 55.    3     0.0    0.0    0.0       rors.w	r7, r7, #1
        // 56.    3     0.0    0.0    0.0       rors.w	r3, r3, #18
        // 57.    3     0.0    0.0    0.0       rors.w	r4, r4, #22
        // 58.    3     0.0    0.0    0.0       bic.w	r1, r5, r4
        // 59.    3     0.0    0.0    0.0       eors.w	r1, r1, r3
        // 60.    3     0.0    0.0    0.0       str	r1, [r0, #84]
        // 61.    3     0.0    0.0    0.0       bic.w	r1, r6, r5
        // 62.    3     0.0    0.0    0.0       eors.w	r1, r1, r4
        // 63.    3     0.0    0.0    0.0       str.w	r1, [r0, #132]
        // 64.    3     0.0    0.0    0.0       bic.w	r1, r7, r6
        // 65.    3     0.0    0.0    0.0       eors.w	r1, r1, r5
        // 66.    3     0.0    0.0    0.0       str.w	r1, [r0, #180]
        // 67.    3     0.0    0.0    0.0       bic.w	r1, r3, r7
        // 68.    3     0.0    0.0    0.0       eors.w	r1, r1, r6
        // 69.    3     0.0    0.0    0.0       str	r1, [r0, #24]
        // 70.    3     0.0    0.0    0.0       bic.w	r1, r4, r3
        // 71.    3     0.0    0.0    0.0       eors.w	r1, r1, r7
        // 72.    3     0.0    0.0    0.0       str	r1, [r0, #72]
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
        // Instructions:      7300
        // Total Cycles:      3902
        // Total uOps:        7300
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.87
        // IPC:               1.87
        // Block RThroughput: 36.5
        //
        //
        // Cycles with backend pressure increase [ 5.13% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 2.56% ]
        //   Data Dependencies:      [ 2.56% ]
        //   - Register Dependencies [ 2.56% ]
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
        //  1      2     0.50    *                   ldr.w	r2, [r0, #188]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #68]
        //  1      2     0.50    *                   ldr.w	r12, [r0, #44]
        //  1      2     0.50    *                   ldr	r1, [r0, #28]
        //  1      1     0.50                        eors.w	r10, r1, r11
        //  1      2     0.50    *                   ldr	r6, [r0, #84]
        //  1      2     0.50    *                   ldr	r1, [r0]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #4]
        //  1      2     0.50    *                   ldr	r3, [r0, #80]
        //  1      1     0.50                        eors.w	r11, r11, r12
        //  1      2     0.50    *                   ldr.w	r12, [r0, #124]
        //  1      1     0.50                        eors.w	r6, r11, r6
        //  1      2     0.50    *                   ldr.w	r11, [r0, #164]
        //  1      1     0.50                        eors.w	r12, r6, r12
        //  1      2     0.50    *                   ldr	r6, [r0, #40]
        //  1      1     0.50                        eors.w	r12, r12, r11
        //  1      1     0.50                        eors.w	r11, r12, r5
        //  1      1     0.50                        eors.w	r1, r1, r6
        //  1      2     0.50    *                   ldr	r5, [r0, #120]
        //  1      1     0.50                        eors.w	r3, r1, r3
        //  1      2     0.50    *                   ldr.w	r6, [r0, #160]
        //  1      1     0.50                        eors.w	r1, r3, r5
        //  1      1     0.50                        eors.w	r3, r1, r6
        //  1      2     0.50    *                   ldr.w	r6, [r0, #132]
        //  1      2     0.50    *                   ldr	r5, [r0, #108]
        //  1      2     0.50    *                   ldr	r1, [r0, #24]
        //  1      1     0.50                        eors.w	r10, r10, r5
        //  1      2     0.50    *                   ldr.w	r5, [r0, #148]
        //  1      1     0.50                        eors.w	r1, r1, r9
        //  1      1     0.50                        eors.w	r5, r10, r5
        //  1      1     0.50                        eors.w	r2, r5, r2
        //  1      1     0.50                        eors.w	r6, r6, r11
        //  1      2     1.00                        eor.w	r10, r3, r4, ror #31
        //  1      2     0.50    *                   ldr	r5, [r0, #24]
        //  1      2     1.00                        eor.w	r4, lr, r2, ror #31
        //  1      1     0.50                        eors.w	lr, r2, r3
        //  1      2     0.50    *                   ldr	r3, [r0, #64]
        //  1      1     1.00                        rors.w	r1, r1, #18
        //  1      2     0.50    *                   ldr	r2, [r0, #104]
        //  1      1     0.50                        eors.w	r5, r5, r3
        //  1      2     0.50    *                   ldr.w	r3, [r0, #144]
        //  1      1     0.50                        eors.w	r2, r5, r2
        //  1      2     0.50    *                   ldr.w	r5, [r0, #184]
        //  1      1     0.50                        eors.w	r2, r2, r3
        //  1      1     1.00                        rors.w	r6, r6, #9
        //  1      1     0.50                        eors.w	r3, r2, r5
        //  1      1     0.50                        eors.w	r2, r7, r3
        //  1      2     0.50    *                   ldr.w	r7, [r0, #180]
        //  1      2     1.00                        eor.w	r12, r3, r12, ror #31
        //  1      2     0.50    *                   ldr	r5, [r0, #84]
        //  1      1     0.50                        eors.w	r7, r7, r2
        //  1      3     1.00           *            str	r4, [sp, #16]
        //  1      1     1.00                        rors.w	r7, r7, #1
        //  1      1     0.50                        eors.w	r5, r5, r8
        //  1      1     0.50                        bic.w	r4, r1, r7
        //  1      1     1.00                        rors.w	r5, r5, #30
        //  1      1     0.50                        eors.w	r3, r4, r6
        //  1      2     0.50    *                   ldr	r4, [r0, #72]
        //  1      3     1.00           *            str	r3, [r0, #24]
        //  1      1     0.50                        bic.w	r3, r7, r6
        //  1      1     0.50                        eors.w	r4, r4, r12
        //  1      1     0.50                        eors.w	r3, r3, r5
        //  1      1     1.00                        rors.w	r4, r4, #22
        //  1      3     1.00           *            str.w	r3, [r0, #180]
        //  1      1     0.50                        bic.w	r3, r4, r1
        //  1      1     0.50                        bic.w	r6, r6, r5
        //  1      1     0.50                        eors.w	r6, r6, r4
        //  1      3     1.00           *            str.w	r6, [r0, #132]
        //  1      1     0.50                        bic.w	r6, r5, r4
        //  1      1     0.50                        eors.w	r1, r6, r1
        //  1      1     0.50                        eors.w	r3, r3, r7
        //  1      3     1.00           *            str	r3, [r0, #72]
        //  1      3     1.00           *            str	r1, [r0, #84]
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      100  (2.6%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 100  (2.6%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              2  (0.1%)
        //  1,              500  (12.8%)
        //  2,              3400  (87.1%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          2  (0.1%)
        //  1,          500  (12.8%)
        //  2,          3400  (87.1%)
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
        // 21.00  21.00   -     12.50  12.50   -      -     8.00    -     6.00    -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r2, [r0, #188]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #68]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r12, [r0, #44]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #28]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r1, r11
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #84]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #80]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, r11, r12
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r12, [r0, #124]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r11, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #164]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r12, r6, r12
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #40]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r12, r12, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, r12, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #120]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r1, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #160]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r3, r5
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r1, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #132]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #108]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #24]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r10, r5
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #148]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r9
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r10, r5
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r5, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r11
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r10, r3, r4, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #24]
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r4, lr, r2, ror #31
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, r2, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #64]
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r1, r1, #18
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r2, [r0, #104]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r3, [r0, #144]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r5, r2
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #184]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r2, r3
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r6, r6, #9
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r2, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r7, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #180]
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r12, r3, r12, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #84]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r2
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [sp, #16]
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r7, r7, #1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r8
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r4, r1, r7
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r5, r5, #30
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r4, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #72]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #24]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r3, r7, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r12
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r5
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r4, r4, #22
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r3, [r0, #180]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r3, r4, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r6, r6, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r6, [r0, #132]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r6, r5, r4
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r6, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r7
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [r0, #72]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r1, [r0, #84]
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          012345678
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r2, [r0, #188]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #68]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #44]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0, #28]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r10, r1, r11
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r6, [r0, #84]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0]
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #4]
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r3, [r0, #80]
        // [0,9]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r11, r11, r12
        // [0,10]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #124]
        // [0,11]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r6, r11, r6
        // [0,12]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #164]
        // [0,13]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r12, r6, r12
        // [0,14]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r6, [r0, #40]
        // [0,15]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r12, r12, r11
        // [0,16]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r11, r12, r5
        // [0,17]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r1, r6
        // [0,18]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #120]
        // [0,19]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r1, r3
        // [0,20]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r6, [r0, #160]
        // [0,21]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r3, r5
        // [0,22]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r1, r6
        // [0,23]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r6, [r0, #132]
        // [0,24]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #108]
        // [0,25]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0, #24]
        // [0,26]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r10, r10, r5
        // [0,27]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #148]
        // [0,28]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r1, r9
        // [0,29]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r10, r5
        // [0,30]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r5, r2
        // [0,31]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r6, r6, r11
        // [0,32]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eor.w	r10, r3, r4, ror #31
        // [0,33]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #24]
        // [0,34]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eor.w	r4, lr, r2, ror #31
        // [0,35]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	lr, r2, r3
        // [0,36]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r3, [r0, #64]
        // [0,37]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r1, r1, #18
        // [0,38]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r2, [r0, #104]
        // [0,39]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r5, r3
        // [0,40]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r3, [r0, #144]
        // [0,41]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r5, r2
        // [0,42]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #184]
        // [0,43]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r2, r3
        // [0,44]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r6, r6, #9
        // [0,45]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r2, r5
        // [0,46]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r7, r3
        // [0,47]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r7, [r0, #180]
        // [0,48]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eor.w	r12, r3, r12, ror #31
        // [0,49]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #84]
        // [0,50]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r7, r7, r2
        // [0,51]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	r4, [sp, #16]
        // [0,52]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r7, r7, #1
        // [0,53]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r5, r8
        // [0,54]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   bic.w	r4, r1, r7
        // [0,55]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r5, r5, #30
        // [0,56]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r4, r6
        // [0,57]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r4, [r0, #72]
        // [0,58]    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	r3, [r0, #24]
        // [0,59]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   bic.w	r3, r7, r6
        // [0,60]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r4, r4, r12
        // [0,61]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r3, r5
        // [0,62]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r4, r4, #22
        // [0,63]    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r3, [r0, #180]
        // [0,64]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   bic.w	r3, r4, r1
        // [0,65]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   bic.w	r6, r6, r5
        // [0,66]    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r6, r6, r4
        // [0,67]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #132]
        // [0,68]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   bic.w	r6, r5, r4
        // [0,69]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r6, r1
        // [0,70]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r3, r7
        // [0,71]    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	r3, [r0, #72]
        // [0,72]    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   str	r1, [r0, #84]
        // [1,0]     .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r2, [r0, #188]
        // [1,1]     .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #68]
        // [1,2]     .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #44]
        // [1,3]     .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0, #28]
        // [1,4]     .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r10, r1, r11
        // [1,5]     .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r6, [r0, #84]
        // [1,6]     .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0]
        // [1,7]     .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #4]
        // [1,8]     .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r3, [r0, #80]
        // [1,9]     .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r11, r11, r12
        // [1,10]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #124]
        // [1,11]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r6, r11, r6
        // [1,12]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #164]
        // [1,13]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r12, r6, r12
        // [1,14]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r6, [r0, #40]
        // [1,15]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r12, r12, r11
        // [1,16]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r11, r12, r5
        // [1,17]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r1, r6
        // [1,18]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #120]
        // [1,19]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r1, r3
        // [1,20]    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r6, [r0, #160]
        // [1,21]    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r3, r5
        // [1,22]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r1, r6
        // [1,23]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r6, [r0, #132]
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #108]
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r1, [r0, #24]
        // [1,26]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r10, r10, r5
        // [1,27]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #148]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r1, r1, r9
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r10, r5
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r5, r2
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r6, r6, r11
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .  .   eor.w	r10, r3, r4, ror #31
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #24]
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .  .   eor.w	r4, lr, r2, ror #31
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	lr, r2, r3
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r3, [r0, #64]
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r1, r1, #18
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .  .   ldr	r2, [r0, #104]
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r5, r3
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r3, [r0, #144]
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r5, r2
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r5, [r0, #184]
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r2, r3
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .  .   rors.w	r6, r6, #9
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r2, r5
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .  .   eors.w	r2, r7, r3
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .  .   ldr.w	r7, [r0, #180]
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .  .   eor.w	r12, r3, r12, ror #31
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .  .   ldr	r5, [r0, #84]
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .  .   eors.w	r7, r7, r2
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .  .   str	r4, [sp, #16]
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .  .   rors.w	r7, r7, #1
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .  .   eors.w	r5, r5, r8
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .  .   bic.w	r4, r1, r7
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .  .   rors.w	r5, r5, #30
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .  .   eors.w	r3, r4, r6
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .  .   ldr	r4, [r0, #72]
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .  .   str	r3, [r0, #24]
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .  .   bic.w	r3, r7, r6
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .  .   eors.w	r4, r4, r12
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .  .   eors.w	r3, r3, r5
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .  .   rors.w	r4, r4, #22
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .  .   str.w	r3, [r0, #180]
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .  .   bic.w	r3, r4, r1
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .  .   bic.w	r6, r6, r5
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .  .   eors.w	r6, r6, r4
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .  .   str.w	r6, [r0, #132]
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .  .   bic.w	r6, r5, r4
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .  .   eors.w	r1, r6, r1
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .  .   eors.w	r3, r3, r7
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .  .   str	r3, [r0, #72]
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .  .   str	r1, [r0, #84]
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .  .   ldr.w	r2, [r0, #188]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #68]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .  .   ldr.w	r12, [r0, #44]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .  .   ldr	r1, [r0, #28]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .  .   eors.w	r10, r1, r11
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .  .   ldr	r6, [r0, #84]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .  .   ldr	r1, [r0]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .  .   ldr.w	r11, [r0, #4]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .  .   ldr	r3, [r0, #80]
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .  .   eors.w	r11, r11, r12
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .  .   ldr.w	r12, [r0, #124]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .  .   eors.w	r6, r11, r6
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .  .   ldr.w	r11, [r0, #164]
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .  .   eors.w	r12, r6, r12
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .  .   ldr	r6, [r0, #40]
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .  .   eors.w	r12, r12, r11
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .  .   eors.w	r11, r12, r5
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .  .   eors.w	r1, r1, r6
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .  .   ldr	r5, [r0, #120]
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .  .   eors.w	r3, r1, r3
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .  .   ldr.w	r6, [r0, #160]
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .  .   eors.w	r1, r3, r5
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .  .   eors.w	r3, r1, r6
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .  .   ldr.w	r6, [r0, #132]
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .  .   ldr	r5, [r0, #108]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .  .   ldr	r1, [r0, #24]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .  .   eors.w	r10, r10, r5
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .  .   ldr.w	r5, [r0, #148]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .  .   eors.w	r1, r1, r9
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .  .   eors.w	r5, r10, r5
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .  .   eors.w	r2, r5, r2
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .  .   eors.w	r6, r6, r11
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .  .   eor.w	r10, r3, r4, ror #31
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .  .   ldr	r5, [r0, #24]
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .  .   eor.w	r4, lr, r2, ror #31
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .  .   eors.w	lr, r2, r3
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .  .   ldr	r3, [r0, #64]
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .  .   rors.w	r1, r1, #18
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .  .   ldr	r2, [r0, #104]
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .  .   eors.w	r5, r5, r3
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .  .   ldr.w	r3, [r0, #144]
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .  .   eors.w	r2, r5, r2
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .  .   ldr.w	r5, [r0, #184]
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .  .   eors.w	r2, r2, r3
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .  .   rors.w	r6, r6, #9
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .  .   eors.w	r3, r2, r5
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .  .   eors.w	r2, r7, r3
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .  .   ldr.w	r7, [r0, #180]
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .  .   eor.w	r12, r3, r12, ror #31
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .  .   ldr	r5, [r0, #84]
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .  .   eors.w	r7, r7, r2
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .  .   str	r4, [sp, #16]
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .  .   rors.w	r7, r7, #1
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .  .   eors.w	r5, r5, r8
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .  .   bic.w	r4, r1, r7
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .  .   rors.w	r5, r5, #30
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .  .   eors.w	r3, r4, r6
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .  .   ldr	r4, [r0, #72]
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .  .   str	r3, [r0, #24]
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .  .   bic.w	r3, r7, r6
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .  .   eors.w	r4, r4, r12
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .  .   eors.w	r3, r3, r5
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .  .   rors.w	r4, r4, #22
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .  .   str.w	r3, [r0, #180]
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .  .   bic.w	r3, r4, r1
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .  .   bic.w	r6, r6, r5
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .  .   eors.w	r6, r6, r4
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.  .   str.w	r6, [r0, #132]
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.  .   bic.w	r6, r5, r4
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE  .   eors.w	r1, r6, r1
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE  .   eors.w	r3, r3, r7
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE.   str	r3, [r0, #72]
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE   str	r1, [r0, #84]
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr.w	r2, [r0, #188]
        // 1.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #68]
        // 2.     3     0.0    0.0    0.0       ldr.w	r12, [r0, #44]
        // 3.     3     0.0    0.0    0.0       ldr	r1, [r0, #28]
        // 4.     3     0.0    0.0    0.0       eors.w	r10, r1, r11
        // 5.     3     0.0    0.0    0.0       ldr	r6, [r0, #84]
        // 6.     3     0.0    0.0    0.0       ldr	r1, [r0]
        // 7.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #4]
        // 8.     3     0.0    0.0    0.0       ldr	r3, [r0, #80]
        // 9.     3     0.0    0.0    0.0       eors.w	r11, r11, r12
        // 10.    3     0.0    0.0    0.0       ldr.w	r12, [r0, #124]
        // 11.    3     0.0    0.0    0.0       eors.w	r6, r11, r6
        // 12.    3     0.0    0.0    0.0       ldr.w	r11, [r0, #164]
        // 13.    3     0.0    0.0    0.0       eors.w	r12, r6, r12
        // 14.    3     0.0    0.0    0.0       ldr	r6, [r0, #40]
        // 15.    3     0.0    0.0    0.0       eors.w	r12, r12, r11
        // 16.    3     0.0    0.0    0.0       eors.w	r11, r12, r5
        // 17.    3     0.0    0.0    0.0       eors.w	r1, r1, r6
        // 18.    3     0.0    0.0    0.0       ldr	r5, [r0, #120]
        // 19.    3     0.0    0.0    0.0       eors.w	r3, r1, r3
        // 20.    3     0.0    0.0    0.0       ldr.w	r6, [r0, #160]
        // 21.    3     0.0    0.0    0.0       eors.w	r1, r3, r5
        // 22.    3     0.0    0.0    0.0       eors.w	r3, r1, r6
        // 23.    3     0.0    0.0    0.0       ldr.w	r6, [r0, #132]
        // 24.    3     0.0    0.0    0.0       ldr	r5, [r0, #108]
        // 25.    3     0.0    0.0    0.0       ldr	r1, [r0, #24]
        // 26.    3     0.0    0.0    0.0       eors.w	r10, r10, r5
        // 27.    3     0.0    0.0    0.0       ldr.w	r5, [r0, #148]
        // 28.    3     0.0    0.0    0.0       eors.w	r1, r1, r9
        // 29.    3     0.0    0.0    0.0       eors.w	r5, r10, r5
        // 30.    3     0.0    0.0    0.0       eors.w	r2, r5, r2
        // 31.    3     0.0    0.0    0.0       eors.w	r6, r6, r11
        // 32.    3     0.0    0.0    0.0       eor.w	r10, r3, r4, ror #31
        // 33.    3     0.0    0.0    0.0       ldr	r5, [r0, #24]
        // 34.    3     0.0    0.0    0.0       eor.w	r4, lr, r2, ror #31
        // 35.    3     0.0    0.0    0.0       eors.w	lr, r2, r3
        // 36.    3     0.0    0.0    0.0       ldr	r3, [r0, #64]
        // 37.    3     0.0    0.0    0.0       rors.w	r1, r1, #18
        // 38.    3     0.0    0.0    0.0       ldr	r2, [r0, #104]
        // 39.    3     0.0    0.0    0.0       eors.w	r5, r5, r3
        // 40.    3     0.0    0.0    0.0       ldr.w	r3, [r0, #144]
        // 41.    3     0.0    0.0    0.0       eors.w	r2, r5, r2
        // 42.    3     0.0    0.0    0.0       ldr.w	r5, [r0, #184]
        // 43.    3     0.0    0.0    0.0       eors.w	r2, r2, r3
        // 44.    3     0.0    0.0    0.0       rors.w	r6, r6, #9
        // 45.    3     0.0    0.0    0.0       eors.w	r3, r2, r5
        // 46.    3     0.0    0.0    0.0       eors.w	r2, r7, r3
        // 47.    3     0.0    0.0    0.0       ldr.w	r7, [r0, #180]
        // 48.    3     0.0    0.0    0.0       eor.w	r12, r3, r12, ror #31
        // 49.    3     0.0    0.0    0.0       ldr	r5, [r0, #84]
        // 50.    3     0.0    0.0    0.0       eors.w	r7, r7, r2
        // 51.    3     0.0    0.0    0.0       str	r4, [sp, #16]
        // 52.    3     0.0    0.0    0.0       rors.w	r7, r7, #1
        // 53.    3     0.0    0.0    0.0       eors.w	r5, r5, r8
        // 54.    3     0.0    0.0    0.0       bic.w	r4, r1, r7
        // 55.    3     0.0    0.0    0.0       rors.w	r5, r5, #30
        // 56.    3     0.0    0.0    0.0       eors.w	r3, r4, r6
        // 57.    3     0.0    0.0    0.0       ldr	r4, [r0, #72]
        // 58.    3     0.0    0.0    0.0       str	r3, [r0, #24]
        // 59.    3     0.0    0.0    0.0       bic.w	r3, r7, r6
        // 60.    3     0.0    0.0    0.0       eors.w	r4, r4, r12
        // 61.    3     0.0    0.0    0.0       eors.w	r3, r3, r5
        // 62.    3     0.0    0.0    0.0       rors.w	r4, r4, #22
        // 63.    3     0.0    0.0    0.0       str.w	r3, [r0, #180]
        // 64.    3     0.0    0.0    0.0       bic.w	r3, r4, r1
        // 65.    3     0.0    0.0    0.0       bic.w	r6, r6, r5
        // 66.    3     0.0    0.0    0.0       eors.w	r6, r6, r4
        // 67.    3     0.0    0.0    0.0       str.w	r6, [r0, #132]
        // 68.    3     0.0    0.0    0.0       bic.w	r6, r5, r4
        // 69.    3     0.0    0.0    0.0       eors.w	r1, r6, r1
        // 70.    3     0.0    0.0    0.0       eors.w	r3, r3, r7
        // 71.    3     0.0    0.0    0.0       str	r3, [r0, #72]
        // 72.    3     0.0    0.0    0.0       str	r1, [r0, #84]
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        slothy_end:

 add		sp, #mSize
 pop		{ r4 - r12, pc }

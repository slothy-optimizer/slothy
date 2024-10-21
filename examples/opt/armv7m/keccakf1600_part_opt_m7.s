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
                                         // Instructions:    135
                                         // Expected cycles: 68
                                         // Expected IPC:    1.99
                                         //
                                         // Cycle bound:     68.0
                                         // IPC bound:       1.99
                                         //
                                         // Wall time:     329.40s
                                         // User time:     329.40s
                                         //
                                         // --------------------------------------------------------- original position ---------------------------------------------------------->
                                         // 0                        25                       50                       75                       100                      125
                                         // |------------------------|------------------------|------------------------|------------------------|------------------------|---------
        ldr r5, [r0, #Ako0]              // ................................................................................................*...................................... // @slothy:reads=[r0\()Ako0]
        ldr r14, [r0, #Asa1]             // ...............................................................................*....................................................... // @slothy:reads=[r0\()Asa1]
        ldr r3, [r0, #Abo0]              // .............................................................................................*......................................... // @slothy:reads=[r0\()Abo0]
        ldr r12, [r0, #Aka1]             // ...........................................................................*........................................................... // @slothy:reads=[r0\()Aka1]
        ldr r1, [r0, #Abu0]              // *...................................................................................................................................... // @slothy:reads=[r0\()Abu0]
        ldr r4, [r0, #Aga1]              // .........................................................................*............................................................. // @slothy:reads=[r0\()Aga1]
        ldr r6, [r0, #Aba1]              // ........................................................................*.............................................................. // @slothy:reads=[r0\()Aba1]
        ldr r11, [r0, #Aso0]             // ....................................................................................................*.................................. // @slothy:reads=[r0\()Aso0]
        ldr r2, [r0, #Amo0]              // ..................................................................................................*.................................... // @slothy:reads=[r0\()Amo0]
        eors.w r4, r6, r4                // ..........................................................................*............................................................
        ldr r8, [r0, #Ama1]              // .............................................................................*......................................................... // @slothy:reads=[r0\()Ama1]
        ldr r6, [r0, #Ago0]              // ..............................................................................................*........................................ // @slothy:reads=[r0\()Ago0]
        eors.w r4, r4, r12               // ............................................................................*..........................................................
        eors.w r12, r3, r6               // ...............................................................................................*.......................................
        eors.w r5, r12, r5               // .................................................................................................*.....................................
        eors.w r4, r4, r8                // ..............................................................................*........................................................
        eors.w r5, r5, r2                // ...................................................................................................*...................................
        eors.w r8, r4, r14               // ................................................................................*......................................................
        eors.w r6, r5, r11               // .....................................................................................................*.................................
        ldr r10, [r0, #Agu0]             // .*..................................................................................................................................... // @slothy:reads=[r0\()Agu0]
        eors.w r10, r1, r10              // ..*....................................................................................................................................
        eor r12, r6, r8, ror #31         // .......................................................................................................*...............................
        ldr r3, [r0, #Age1]              // ..........*............................................................................................................................ // @slothy:reads=[r0\()Age1]
        ldr r14, [r0, #Abe1]             // .........*............................................................................................................................. // @slothy:reads=[r0\()Abe1]
        ldr r1, [r0, #Ake1]              // ............*.......................................................................................................................... // @slothy:reads=[r0\()Ake1]
        eors.w r5, r14, r3               // ...........*...........................................................................................................................
        ldr r11, [r0, #Ame1]             // ..............*........................................................................................................................ // @slothy:reads=[r0\()Ame1]
        ldr r3, [r0, #Aku0]              // ...*................................................................................................................................... // @slothy:reads=[r0\()Aku0]
        ldr r2, [r0, #Amu0]              // .....*................................................................................................................................. // @slothy:reads=[r0\()Amu0]
        eors.w r9, r10, r3               // ....*..................................................................................................................................
        eors.w r1, r5, r1                // .............*.........................................................................................................................
        eors.w r3, r9, r2                // ......*................................................................................................................................
        ldr r5, [r0, #Ase1]              // ................*...................................................................................................................... // @slothy:reads=[r0\()Ase1]
        eors.w r7, r1, r11               // ...............*.......................................................................................................................
        eors.w r1, r7, r5                // .................*.....................................................................................................................
        ldr r9, [r0, #Asu0]              // .......*............................................................................................................................... // @slothy:reads=[r0\()Asu0]
        eors r2, r1, r6                  // ......................................................................................................*................................
        eors.w r7, r3, r9                // ........*..............................................................................................................................
        eor r5, r7, r1, ror #31          // ..................*....................................................................................................................
        ldr r14, [r0, #Abu1]             // ....................*.................................................................................................................. // @slothy:reads=[r0\()Abu1]
        ldr r11, [r0, #Agu1]             // .....................*................................................................................................................. // @slothy:reads=[r0\()Agu1]
        ldr r6, [r0, #Amu1]              // .........................*............................................................................................................. // @slothy:reads=[r0\()Amu1]
        eors.w r14, r14, r11             // ......................*................................................................................................................
        ldr r11, [r0, #Aku1]             // .......................*............................................................................................................... // @slothy:reads=[r0\()Aku1]
        eors.w r11, r14, r11             // ........................*..............................................................................................................
        str r5, [sp, #mDa0]              // ...................*................................................................................................................... // @slothy:writes=[sp\()\mDa0]
        eors.w r9, r11, r6               // ..........................*............................................................................................................
        ldr r4, [r0, #Asu1]              // ...........................*........................................................................................................... // @slothy:reads=[r0\()Asu1]
        ldr r10, [r0, #Abe0]             // .............................*......................................................................................................... // @slothy:reads=[r0\()Abe0]
        ldr r6, [r0, #Age0]              // ..............................*........................................................................................................ // @slothy:reads=[r0\()Age0]
        eors.w r11, r10, r6              // ...............................*.......................................................................................................
        ldr r1, [r0, #Ake0]              // ................................*...................................................................................................... // @slothy:reads=[r0\()Ake0]
        ldr r10, [r0, #Ame0]             // ..................................*.................................................................................................... // @slothy:reads=[r0\()Ame0]
        eors.w r3, r11, r1               // .................................*.....................................................................................................
        eors.w r14, r3, r10              // ...................................*...................................................................................................
        ldr r5, [r0, #Ase0]              // ....................................*.................................................................................................. // @slothy:reads=[r0\()Ase0]
        eors.w r1, r9, r4                // ............................*..........................................................................................................
        eors.w r11, r14, r5              // .....................................*.................................................................................................
        ldr r6, [r0, #Agi0]              // .........................................*............................................................................................. // @slothy:reads=[r0\()Agi0]
        ldr r4, [r0, #Abi0]              // ........................................*.............................................................................................. // @slothy:reads=[r0\()Abi0]
        eors.w r3, r4, r6                // ..........................................*............................................................................................
        ldr r9, [r0, #Aki0]              // ...........................................*........................................................................................... // @slothy:reads=[r0\()Aki0]
        ldr r5, [r0, #Ami0]              // .............................................*......................................................................................... // @slothy:reads=[r0\()Ami0]
        eors.w r4, r3, r9                // ............................................*..........................................................................................
        ldr r10, [r0, #Asi0]             // ...............................................*....................................................................................... // @slothy:reads=[r0\()Asi0]
        eors.w r3, r4, r5                // ..............................................*........................................................................................
        eors r5, r1, r11                 // ......................................*................................................................................................
        eors.w r6, r3, r10               // ................................................*......................................................................................
        str r5, [sp, #mDa1]              // .......................................*............................................................................................... // @slothy:writes=[sp\()\mDa1]
        eor r4, r6, r1, ror #31          // .................................................*.....................................................................................
        ldr r1, [r0, #Abi1]              // ...................................................*................................................................................... // @slothy:reads=[r0\()Abi1]
        ldr r14, [r0, #Agi1]             // ....................................................*.................................................................................. // @slothy:reads=[r0\()Agi1]
        eors.w r1, r1, r14               // .....................................................*.................................................................................
        ldr r3, [r0, #Aki1]              // ......................................................*................................................................................ // @slothy:reads=[r0\()Aki1]
        eors.w r10, r1, r3               // .......................................................*...............................................................................
        ldr r9, [r0, #Ami1]              // ........................................................*.............................................................................. // @slothy:reads=[r0\()Ami1]
        ldr r14, [r0, #Asi1]             // ..........................................................*............................................................................ // @slothy:reads=[r0\()Asi1]
        eors.w r3, r10, r9               // .........................................................*.............................................................................
        str r4, [sp, #mDo0]              // ..................................................*.................................................................................... // @slothy:writes=[sp\()\mDo0]
        eors.w r9, r3, r14               // ...........................................................*...........................................................................
        ldr r14, [r0, #Aba0]             // ..............................................................*........................................................................ // @slothy:reads=[r0\()Aba0]
        ldr r1, [r0, #Aga0]              // ...............................................................*....................................................................... // @slothy:reads=[r0\()Aga0]
        eors r10, r7, r9                 // ............................................................*..........................................................................
        eors.w r7, r14, r1               // ................................................................*......................................................................
        ldr r14, [r0, #Abo1]             // ..................................................................................*.................................................... // @slothy:reads=[r0\()Abo1]
        ldr r3, [r0, #Ago1]              // ...................................................................................*................................................... // @slothy:reads=[r0\()Ago1]
        eors.w r14, r14, r3              // ....................................................................................*..................................................
        ldr r3, [r0, #Ako1]              // .....................................................................................*................................................. // @slothy:reads=[r0\()Ako1]
        eors.w r1, r14, r3               // ......................................................................................*................................................
        ldr r14, [r0, #Amo1]             // .......................................................................................*............................................... // @slothy:reads=[r0\()Amo1]
        eors.w r14, r1, r14              // ........................................................................................*..............................................
        ldr r3, [r0, #Aso1]              // .........................................................................................*............................................. // @slothy:reads=[r0\()Aso1]
        ldr r1, [r0, #Ama0]              // ...................................................................*................................................................... // @slothy:reads=[r0\()Ama0]
        eors.w r3, r14, r3               // ..........................................................................................*............................................
        str r10, [sp, #mDo1]             // .............................................................*......................................................................... // @slothy:writes=[sp\()\mDo1]
        ldr r14, [r0, #Aka0]             // .................................................................*..................................................................... // @slothy:reads=[r0\()Aka0]
        eors.w r7, r7, r14               // ..................................................................*....................................................................
        eor r14, r11, r3, ror #31        // ...........................................................................................*...........................................
        // gap                           // .......................................................................................................................................
        eors.w r1, r7, r1                // ....................................................................*..................................................................
        eors r11, r8, r6                 // .................................................................................*.....................................................
        str r14, [sp, #mDi0]             // ............................................................................................*.......................................... // @slothy:writes=[sp\()\mDi0]
        ldr r14, [r0, #Aka1]             // .........................................................................................................*............................. // @slothy:reads=[r0\()Aka1]
        ldr r7, [r0, #Ame1]              // ..........................................................................................................*............................ // @slothy:reads=[r0\()Ame1]
        ldr r10, [r0, #Asi1]             // ...........................................................................................................*........................... // @slothy:reads=[r0\()Asi1]
        ldr r6, [r0, #Abo0]              // ............................................................................................................*.......................... // @slothy:reads=[r0\()Abo0]
        ldr r8, [r0, #Agu0]              // .............................................................................................................*......................... // @slothy:reads=[r0\()Agu0]
        eors.w r14, r5                   // ..............................................................................................................*........................
        eors.w r6, r4                    // .................................................................................................................*.....................
        rors r14, #32-2                  // ...................................................................................................................*...................
        eors.w r8, r12                   // ..................................................................................................................*....................
        rors r6, #32-14                  // ......................................................................................................................*................
        rors r8, #32-10                  // .......................................................................................................................*...............
        eors.w r10, r2                   // ...............................................................................................................*.......................
        eors.w r7, r11                   // ................................................................................................................*......................
        bic r5, r14, r8                  // ........................................................................................................................*..............
        rors r7, #32-23                  // ....................................................................................................................*..................
        eors.w r4, r5, r6                // .........................................................................................................................*.............
        str r4, [r0, #Aka1]              // ..........................................................................................................................*............ // @slothy:writes=[r0\()Aka1]
        bic r5, r7, r14                  // ...........................................................................................................................*...........
        rors r10, #32-31                 // .....................................................................................................................*.................
        eors.w r5, r5, r8                // ............................................................................................................................*..........
        str r5, [r0, #Ame1]              // .............................................................................................................................*......... // @slothy:writes=[r0\()Ame1]
        bic r5, r10, r7                  // ..............................................................................................................................*........
        ldr r4, [r0, #Asa0]              // .....................................................................*................................................................. // @slothy:reads=[r0\()Asa0]
        eors.w r5, r5, r14               // ...............................................................................................................................*.......
        str r5, [r0, #Asi1]              // ................................................................................................................................*...... // @slothy:writes=[r0\()Asi1]
        bic r5, r6, r10                  // .................................................................................................................................*.....
        eors.w r1, r1, r4                // ......................................................................*................................................................
        eors.w r5, r5, r7                // ..................................................................................................................................*....
        str r5, [r0, #Abo0]              // ...................................................................................................................................*... // @slothy:writes=[r0\()Abo0]
        bic r4, r8, r6                   // ....................................................................................................................................*..
        eors r14, r3, r1                 // ........................................................................................................*..............................
        eors.w r8, r4, r10               // .....................................................................................................................................*.
        str r8, [r0, #Agu0]              // ......................................................................................................................................* // @slothy:writes=[r0\()Agu0]
        eor r10, r1, r9, ror #31         // .......................................................................*...............................................................

                                              // ------------------------------------------------------------ new position ------------------------------------------------------------>
                                              // 0                        25                       50                       75                       100                      125
                                              // |------------------------|------------------------|------------------------|------------------------|------------------------|---------
        // ldr			r3, [r0, #Abu0]              // ....*..................................................................................................................................
        // ldr			r1, [r0, #Agu0]              // ...................*...................................................................................................................
        // eors.w		r3, r3, r1                 // ....................*..................................................................................................................
        // ldr			r1, [r0, #Aku0]              // ...........................*...........................................................................................................
        // eors.w		r3, r3, r1                 // .............................*.........................................................................................................
        // ldr			r1, [r0, #Amu0]              // ............................*..........................................................................................................
        // eors.w		r3, r3, r1                 // ...............................*.......................................................................................................
        // ldr			r1, [r0, #Asu0]              // ...................................*...................................................................................................
        // eors.w		r3, r3, r1                 // .....................................*.................................................................................................
        // ldr			r7, [r0, #Abe1]              // .......................*...............................................................................................................
        // ldr			r1, [r0, #Age1]              // ......................*................................................................................................................
        // eors.w		r7, r7, r1                 // .........................*.............................................................................................................
        // ldr			r1, [r0, #Ake1]              // ........................*..............................................................................................................
        // eors.w		r7, r7, r1                 // ..............................*........................................................................................................
        // ldr			r1, [r0, #Ame1]              // ..........................*............................................................................................................
        // eors.w		r7, r7, r1                 // .................................*.....................................................................................................
        // ldr			r1, [r0, #Ase1]              // ................................*......................................................................................................
        // eors.w		r7, r7, r1                 // ..................................*....................................................................................................
        // eor			r6, r3, r7, ror #31          // ......................................*................................................................................................
        // str			r6, [sp, #mDa0]              // .............................................*.........................................................................................
        // ldr			r6, [r0, #Abu1]              // .......................................*...............................................................................................
        // ldr			r1, [r0, #Agu1]              // ........................................*..............................................................................................
        // eors.w		r6, r6, r1                 // ..........................................*............................................................................................
        // ldr			r1, [r0, #Aku1]              // ...........................................*...........................................................................................
        // eors.w		r6, r6, r1                 // ............................................*..........................................................................................
        // ldr			r1, [r0, #Amu1]              // .........................................*.............................................................................................
        // eors.w		r6, r6, r1                 // ..............................................*........................................................................................
        // ldr			r1, [r0, #Asu1]              // ...............................................*.......................................................................................
        // eors.w		r6, r6, r1                 // ........................................................*..............................................................................
        // ldr			r14, [r0, #Abe0]             // ................................................*......................................................................................
        // ldr			r1, [r0, #Age0]              // .................................................*.....................................................................................
        // eors.w		r14, r14, r1               // ..................................................*....................................................................................
        // ldr			r1, [r0, #Ake0]              // ...................................................*...................................................................................
        // eors.w		r14, r14, r1               // .....................................................*.................................................................................
        // ldr			r1, [r0, #Ame0]              // ....................................................*..................................................................................
        // eors.w		r14, r14, r1               // ......................................................*................................................................................
        // ldr			r1, [r0, #Ase0]              // .......................................................*...............................................................................
        // eors.w		r14, r14, r1               // .........................................................*.............................................................................
        // eors        r8, r6, r14            // ..................................................................*....................................................................
        // str			r8, [sp, #mDa1]              // ....................................................................*..................................................................
        // ldr			r5, [r0, #Abi0]              // ...........................................................*...........................................................................
        // ldr			r1, [r0, #Agi0]              // ..........................................................*............................................................................
        // eors.w		r5, r5, r1                 // ............................................................*..........................................................................
        // ldr			r1, [r0, #Aki0]              // .............................................................*.........................................................................
        // eors.w		r5, r5, r1                 // ...............................................................*.......................................................................
        // ldr			r1, [r0, #Ami0]              // ..............................................................*........................................................................
        // eors.w		r5, r5, r1                 // .................................................................*.....................................................................
        // ldr			r1, [r0, #Asi0]              // ................................................................*......................................................................
        // eors.w		r5, r5, r1                 // ...................................................................*...................................................................
        // eor			r9, r5, r6, ror #31          // .....................................................................*.................................................................
        // str			r9, [sp, #mDo0]              // ..............................................................................*........................................................
        // ldr			r4, [r0, #Abi1]              // ......................................................................*................................................................
        // ldr			r1, [r0, #Agi1]              // .......................................................................*...............................................................
        // eors.w		r4, r4, r1                 // ........................................................................*..............................................................
        // ldr			r1, [r0, #Aki1]              // .........................................................................*.............................................................
        // eors.w		r4, r4, r1                 // ..........................................................................*............................................................
        // ldr			r1, [r0, #Ami1]              // ...........................................................................*...........................................................
        // eors.w		r4, r4, r1                 // .............................................................................*.........................................................
        // ldr			r1, [r0, #Asi1]              // ............................................................................*..........................................................
        // eors.w		r4, r4, r1                 // ...............................................................................*.......................................................
        // eors		r3, r3, r4                   // ..................................................................................*....................................................
        // str			r3, [sp, #mDo1]              // ..............................................................................................*........................................
        // ldr			r3, [r0, #Aba0]              // ................................................................................*......................................................
        // ldr			r1, [r0, #Aga0]              // .................................................................................*.....................................................
        // eors.w		r3, r3, r1                 // ...................................................................................*...................................................
        // ldr			r1, [r0, #Aka0]              // ...............................................................................................*.......................................
        // eors.w		r3, r3, r1                 // ................................................................................................*......................................
        // ldr			r1, [r0, #Ama0]              // ............................................................................................*..........................................
        // eors.w		r3, r3, r1                 // ..................................................................................................*....................................
        // ldr			r1, [r0, #Asa0]              // ...........................................................................................................................*...........
        // eors.w		r3, r3, r1                 // ...............................................................................................................................*.......
        // eor			r10, r3, r4, ror #31         // ......................................................................................................................................*
        // ldr			r6, [r0, #Aba1]              // ......*................................................................................................................................
        // ldr			r1, [r0, #Aga1]              // .....*.................................................................................................................................
        // eors.w		r6, r6, r1                 // .........*.............................................................................................................................
        // ldr			r1, [r0, #Aka1]              // ...*...................................................................................................................................
        // eors.w		r6, r6, r1                 // ............*..........................................................................................................................
        // ldr			r1, [r0, #Ama1]              // ..........*............................................................................................................................
        // eors.w		r6, r6, r1                 // ...............*.......................................................................................................................
        // ldr			r1, [r0, #Asa1]              // .*.....................................................................................................................................
        // eors.w		r6, r6, r1                 // .................*.....................................................................................................................
        // eors        r11, r6, r5            // ...................................................................................................*...................................
        // ldr			r4, [r0, #Abo1]              // ....................................................................................*..................................................
        // ldr			r1, [r0, #Ago1]              // .....................................................................................*.................................................
        // eors.w		r4, r4, r1                 // ......................................................................................*................................................
        // ldr			r1, [r0, #Ako1]              // .......................................................................................*...............................................
        // eors.w		r4, r4, r1                 // ........................................................................................*..............................................
        // ldr			r1, [r0, #Amo1]              // .........................................................................................*.............................................
        // eors.w		r4, r4, r1                 // ..........................................................................................*............................................
        // ldr			r1, [r0, #Aso1]              // ...........................................................................................*...........................................
        // eors.w		r4, r4, r1                 // .............................................................................................*.........................................
        // eor			r5, r14, r4, ror #31         // .................................................................................................*.....................................
        // str			r5, [sp, #mDi0]              // ....................................................................................................*..................................
        // ldr			r5, [r0, #Abo0]              // ..*....................................................................................................................................
        // ldr			r1, [r0, #Ago0]              // ...........*...........................................................................................................................
        // eors.w		r5, r5, r1                 // .............*.........................................................................................................................
        // ldr			r1, [r0, #Ako0]              // *......................................................................................................................................
        // eors.w		r5, r5, r1                 // ..............*........................................................................................................................
        // ldr			r1, [r0, #Amo0]              // ........*..............................................................................................................................
        // eors.w		r5, r5, r1                 // ................*......................................................................................................................
        // ldr			r1, [r0, #Aso0]              // .......*...............................................................................................................................
        // eors.w		r5, r5, r1                 // ..................*....................................................................................................................
        // eors        r2, r7, r5             // ....................................*..................................................................................................
        // eor			r12, r5, r6, ror #31         // .....................*.................................................................................................................
        // eors        r14, r4, r3            // ...................................................................................................................................*...
        // ldr		r5, [r0, #Aka1]               // .....................................................................................................*.................................
        // ldr		r6, [r0, #Ame1]               // ......................................................................................................*................................
        // ldr		r7, [r0, #Asi1]               // .......................................................................................................*...............................
        // ldr		r3, [r0, #Abo0]               // ........................................................................................................*..............................
        // ldr		r4, [r0, #Agu0]               // .........................................................................................................*.............................
        // eors.w	r5, r8                      // ..........................................................................................................*............................
        // eors.w	r7, r2                      // ................................................................................................................*......................
        // eors.w	r6, r11                     // .................................................................................................................*.....................
        // eors.w	r3, r9                      // ...........................................................................................................*...........................
        // eors.w	r4, r12                     // .............................................................................................................*.........................
        // rors	r5, #32-2                     // ............................................................................................................*..........................
        // rors	r6, #32-23                    // ...................................................................................................................*...................
        // rors	r7, #32-31                    // .......................................................................................................................*...............
        // rors	r3, #32-14                    // ..............................................................................................................*........................
        // rors	r4, #32-10                    // ...............................................................................................................*.......................
        // bic			r1, r5, r4                   // ..................................................................................................................*....................
        // eors.w		r1, r1, r3                 // ....................................................................................................................*..................
        // str			r1, [r0, #Aka1]              // .....................................................................................................................*.................
        // bic			r1, r6, r5                   // ......................................................................................................................*................
        // eors.w		r1, r1, r4                 // ........................................................................................................................*..............
        // str			r1, [r0, #Ame1]              // .........................................................................................................................*.............
        // bic			r1, r7, r6                   // ..........................................................................................................................*............
        // eors.w		r1, r1, r5                 // ............................................................................................................................*..........
        // str			r1, [r0, #Asi1]              // .............................................................................................................................*.........
        // bic			r1, r3, r7                   // ..............................................................................................................................*........
        // eors.w		r1, r1, r6                 // ................................................................................................................................*......
        // str			r1, [r0, #Abo0]              // .................................................................................................................................*.....
        // bic			r1, r4, r3                   // ..................................................................................................................................*....
        // eors.w		r1, r1, r7                 // ....................................................................................................................................*..
        // str			r1, [r0, #Agu0]              // .....................................................................................................................................*.

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      13500
        // Total Cycles:      8002
        // Total uOps:        13500
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.69
        // IPC:               1.69
        // Block RThroughput: 67.5
        //
        //
        // Cycles with backend pressure increase [ 28.74% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 3.75% ]
        //   Data Dependencies:      [ 24.99% ]
        //   - Register Dependencies [ 24.99% ]
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
        //  1      2     0.50    *                   ldr	r3, [r0, #32]
        //  1      2     0.50    *                   ldr	r1, [r0, #72]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #112]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #152]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #192]
        //  1      1     0.50                        eors.w	r3, r3, r1
        //  1      2     0.50    *                   ldr	r7, [r0, #12]
        //  1      2     0.50    *                   ldr	r1, [r0, #52]
        //  1      1     0.50                        eors.w	r7, r7, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #92]
        //  1      1     0.50                        eors.w	r7, r7, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #132]
        //  1      1     0.50                        eors.w	r7, r7, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #172]
        //  1      1     0.50                        eors.w	r7, r7, r1
        //  1      2     1.00                        eor.w	r6, r3, r7, ror #31
        //  1      3     1.00           *            str	r6, [sp]
        //  1      2     0.50    *                   ldr	r6, [r0, #36]
        //  1      2     0.50    *                   ldr	r1, [r0, #76]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #116]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #156]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #196]
        //  1      1     0.50                        eors.w	r6, r6, r1
        //  1      2     0.50    *                   ldr.w	lr, [r0, #8]
        //  1      2     0.50    *                   ldr	r1, [r0, #48]
        //  1      1     0.50                        eors.w	lr, lr, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #88]
        //  1      1     0.50                        eors.w	lr, lr, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #128]
        //  1      1     0.50                        eors.w	lr, lr, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #168]
        //  1      1     0.50                        eors.w	lr, lr, r1
        //  1      1     0.50                        eors.w	r8, r6, lr
        //  1      3     1.00           *            str.w	r8, [sp, #4]
        //  1      2     0.50    *                   ldr	r5, [r0, #16]
        //  1      2     0.50    *                   ldr	r1, [r0, #56]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #96]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #136]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #176]
        //  1      1     0.50                        eors.w	r5, r5, r1
        //  1      2     1.00                        eor.w	r9, r5, r6, ror #31
        //  1      3     1.00           *            str.w	r9, [sp, #8]
        //  1      2     0.50    *                   ldr	r4, [r0, #20]
        //  1      2     0.50    *                   ldr	r1, [r0, #60]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr	r1, [r0, #100]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #140]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      2     0.50    *                   ldr.w	r1, [r0, #180]
        //  1      1     0.50                        eors.w	r4, r4, r1
        //  1      1     0.50                        eors	r3, r4
        //  1      3     1.00           *            str	r3, [sp, #12]
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
        // RAT     - Register unavailable:                      2000  (25.0%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 300  (3.7%)
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              202  (2.5%)
        //  1,              2100  (26.2%)
        //  2,              5700  (71.2%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          202  (2.5%)
        //  1,          2100  (26.2%)
        //  2,          5700  (71.2%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    18600
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
        // 35.00  35.00   -     27.50  27.50   -      -     10.00   -     10.00   -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #32]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #72]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #112]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #152]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #192]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r3, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r7, [r0, #12]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #52]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #92]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #132]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #172]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r6, r3, r7, ror #31
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r6, [sp]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #36]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #76]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #116]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #156]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #196]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #48]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #88]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #128]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #168]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r8, r6, lr
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [sp, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #16]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #56]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #96]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #136]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #176]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r1
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r9, r5, r6, ror #31
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r9, [sp, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #20]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #60]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #100]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #140]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r1, [r0, #180]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors	r3, r4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r3, [sp, #12]
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
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          01
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #32]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #72]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #112]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #152]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #192]
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,9]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r7, [r0, #12]
        // [0,10]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #52]
        // [0,11]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [0,12]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [0,13]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [0,14]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #132]
        // [0,15]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [0,16]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #172]
        // [0,17]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [0,18]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r6, r3, r7, ror #31
        // [0,19]    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r6, [sp]
        // [0,20]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #36]
        // [0,21]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #76]
        // [0,22]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,23]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #116]
        // [0,24]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,25]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #156]
        // [0,26]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,27]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #196]
        // [0,28]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,29]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #8]
        // [0,30]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #48]
        // [0,31]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [0,32]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [0,33]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [0,34]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #128]
        // [0,35]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [0,36]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #168]
        // [0,37]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [0,38]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r6, lr
        // [0,39]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [sp, #4]
        // [0,40]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #16]
        // [0,41]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #56]
        // [0,42]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,43]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #96]
        // [0,44]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,45]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #136]
        // [0,46]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,47]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #176]
        // [0,48]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,49]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r9, r5, r6, ror #31
        // [0,50]    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r9, [sp, #8]
        // [0,51]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #20]
        // [0,52]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #60]
        // [0,53]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,54]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #100]
        // [0,55]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,56]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #140]
        // [0,57]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,58]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #180]
        // [0,59]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,60]    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors	r3, r4
        // [0,61]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r3, [sp, #12]
        // [0,62]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [0,63]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [0,64]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,65]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [0,66]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,67]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [0,68]    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,69]    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [0,70]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [0,71]    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [0,72]    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [0,73]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [0,74]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,75]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [0,76]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,77]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [0,78]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,79]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [0,80]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [0,81]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [0,82]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [0,83]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [0,84]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,85]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [0,86]    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,87]    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [0,88]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,89]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [0,90]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [0,91]    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [0,92]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #16]
        // [0,93]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [0,94]    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [0,95]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,96]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #104]
        // [0,97]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,98]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [0,99]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,100]   .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [0,101]   .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [0,102]   .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r7, r5
        // [0,103]   .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [0,104]   .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r4, r3
        // [0,105]   .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #84]
        // [0,106]   .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #132]
        // [0,107]   .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #180]
        // [0,108]   .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [0,109]   .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #72]
        // [0,110]   .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [0,111]   .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r2
        // [0,112]   .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r11
        // [0,113]   .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r9
        // [0,114]   .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [0,115]   .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r5, r5, #30
        // [0,116]   .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #9
        // [0,117]   .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #1
        // [0,118]   .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r3, r3, #18
        // [0,119]   .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r4, r4, #22
        // [0,120]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r5, r4
        // [0,121]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r3
        // [0,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #84]
        // [0,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r6, r5
        // [0,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [0,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #132]
        // [0,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r7, r6
        // [0,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r5
        // [0,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #180]
        // [0,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r3, r7
        // [0,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r6
        // [0,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #24]
        // [0,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r4, r3
        // [0,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r7
        // [0,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #72]
        // [1,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #32]
        // [1,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #72]
        // [1,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #112]
        // [1,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #152]
        // [1,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #192]
        // [1,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r7, [r0, #12]
        // [1,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #52]
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #132]
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #172]
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r6, r3, r7, ror #31
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r6, [sp]
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #36]
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #76]
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #116]
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #156]
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #196]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #8]
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #48]
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #128]
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #168]
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r6, lr
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [sp, #4]
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #16]
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #56]
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #96]
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #136]
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #176]
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r9, r5, r6, ror #31
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r9, [sp, #8]
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #20]
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #60]
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #100]
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #140]
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #180]
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors	r3, r4
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r3, [sp, #12]
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [1,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [1,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [1,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [1,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [1,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [1,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [1,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [1,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [1,84]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,85]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [1,86]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,87]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [1,88]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,89]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [1,90]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [1,91]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [1,92]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #16]
        // [1,93]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [1,94]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [1,95]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,96]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #104]
        // [1,97]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,98]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [1,99]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,100]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [1,101]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [1,102]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r7, r5
        // [1,103]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [1,104]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r4, r3
        // [1,105]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #84]
        // [1,106]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #132]
        // [1,107]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #180]
        // [1,108]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [1,109]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #72]
        // [1,110]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [1,111]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r2
        // [1,112]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r11
        // [1,113]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r9
        // [1,114]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [1,115]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r5, r5, #30
        // [1,116]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #9
        // [1,117]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #1
        // [1,118]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r3, r3, #18
        // [1,119]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r4, r4, #22
        // [1,120]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r5, r4
        // [1,121]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r3
        // [1,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #84]
        // [1,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r6, r5
        // [1,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [1,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #132]
        // [1,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r7, r6
        // [1,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r5
        // [1,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r1, [r0, #180]
        // [1,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r3, r7
        // [1,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r6
        // [1,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #24]
        // [1,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r1, r4, r3
        // [1,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r7
        // [1,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r1, [r0, #72]
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #32]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #72]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #112]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #152]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #192]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r7, [r0, #12]
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #52]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #132]
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #172]
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r1
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r6, r3, r7, ror #31
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r6, [sp]
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #36]
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #76]
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #116]
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #156]
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #196]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #8]
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #48]
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #128]
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #168]
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r1
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r6, lr
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [sp, #4]
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #16]
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #56]
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #96]
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #136]
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #176]
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    ..   eor.w	r9, r5, r6, ror #31
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    ..   str.w	r9, [sp, #8]
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #20]
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #60]
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #100]
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #140]
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #180]
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    ..   eors	r3, r4
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    ..   str	r3, [sp, #12]
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   ldr	r3, [r0]
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #80]
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #160]
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   eors.w	r3, r3, r1
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   eor.w	r10, r3, r4, ror #31
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [2,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   ldr	r1, [r0, #44]
        // [2,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   ldr	r1, [r0, #84]
        // [2,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    ..   ldr	r1, [r0, #124]
        // [2,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   ldr.w	r1, [r0, #164]
        // [2,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    ..   eors.w	r6, r6, r1
        // [2,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   eors.w	r11, r6, r5
        // [2,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   ldr	r4, [r0, #28]
        // [2,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   ldr	r1, [r0, #68]
        // [2,84]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,85]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   ldr	r1, [r0, #108]
        // [2,86]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,87]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    ..   ldr.w	r1, [r0, #148]
        // [2,88]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,89]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   ldr.w	r1, [r0, #188]
        // [2,90]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    ..   eors.w	r4, r4, r1
        // [2,91]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    ..   eor.w	r5, lr, r4, ror #31
        // [2,92]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    ..   str	r5, [sp, #16]
        // [2,93]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   ldr	r5, [r0, #24]
        // [2,94]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   ldr	r1, [r0, #64]
        // [2,95]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,96]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   ldr	r1, [r0, #104]
        // [2,97]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,98]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   ldr.w	r1, [r0, #144]
        // [2,99]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   eors.w	r5, r5, r1
        // [2,100]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   ldr.w	r1, [r0, #184]
        // [2,101]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    ..   eors.w	r5, r5, r1
        // [2,102]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    ..   eors.w	r2, r7, r5
        // [2,103]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    ..   eor.w	r12, r5, r6, ror #31
        // [2,104]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   eors.w	lr, r4, r3
        // [2,105]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   ldr	r5, [r0, #84]
        // [2,106]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r6, [r0, #132]
        // [2,107]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   ldr.w	r7, [r0, #180]
        // [2,108]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr	r3, [r0, #24]
        // [2,109]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    ..   ldr	r4, [r0, #72]
        // [2,110]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   eors.w	r5, r5, r8
        // [2,111]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   eors.w	r7, r7, r2
        // [2,112]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   eors.w	r6, r6, r11
        // [2,113]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   eors.w	r3, r3, r9
        // [2,114]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   eors.w	r4, r4, r12
        // [2,115]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   rors.w	r5, r5, #30
        // [2,116]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   rors.w	r6, r6, #9
        // [2,117]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   rors.w	r7, r7, #1
        // [2,118]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   rors.w	r3, r3, #18
        // [2,119]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   rors.w	r4, r4, #22
        // [2,120]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   bic.w	r1, r5, r4
        // [2,121]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    ..   eors.w	r1, r1, r3
        // [2,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    ..   str	r1, [r0, #84]
        // [2,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    ..   bic.w	r1, r6, r5
        // [2,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    ..   eors.w	r1, r1, r4
        // [2,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    ..   str.w	r1, [r0, #132]
        // [2,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    ..   bic.w	r1, r7, r6
        // [2,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   ..   eors.w	r1, r1, r5
        // [2,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  ..   str.w	r1, [r0, #180]
        // [2,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  ..   bic.w	r1, r3, r7
        // [2,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE ..   eors.w	r1, r1, r6
        // [2,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE..   str	r1, [r0, #24]
        // [2,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE..   bic.w	r1, r4, r3
        // [2,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE.   eors.w	r1, r1, r7
        // [2,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   str	r1, [r0, #72]
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r3, [r0, #32]
        // 1.     3     0.0    0.0    0.0       ldr	r1, [r0, #72]
        // 2.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 3.     3     0.0    0.0    0.0       ldr	r1, [r0, #112]
        // 4.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 5.     3     0.0    0.0    0.0       ldr.w	r1, [r0, #152]
        // 6.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 7.     3     0.0    0.0    0.0       ldr.w	r1, [r0, #192]
        // 8.     3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 9.     3     0.0    0.0    0.0       ldr	r7, [r0, #12]
        // 10.    3     0.0    0.0    0.0       ldr	r1, [r0, #52]
        // 11.    3     0.0    0.0    0.0       eors.w	r7, r7, r1
        // 12.    3     0.0    0.0    0.0       ldr	r1, [r0, #92]
        // 13.    3     0.0    0.0    0.0       eors.w	r7, r7, r1
        // 14.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #132]
        // 15.    3     0.0    0.0    0.0       eors.w	r7, r7, r1
        // 16.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #172]
        // 17.    3     0.0    0.0    0.0       eors.w	r7, r7, r1
        // 18.    3     0.0    0.0    0.0       eor.w	r6, r3, r7, ror #31
        // 19.    3     0.0    0.0    0.0       str	r6, [sp]
        // 20.    3     0.0    0.0    0.0       ldr	r6, [r0, #36]
        // 21.    3     0.0    0.0    0.0       ldr	r1, [r0, #76]
        // 22.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 23.    3     0.0    0.0    0.0       ldr	r1, [r0, #116]
        // 24.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 25.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #156]
        // 26.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 27.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #196]
        // 28.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 29.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #8]
        // 30.    3     0.0    0.0    0.0       ldr	r1, [r0, #48]
        // 31.    3     0.0    0.0    0.0       eors.w	lr, lr, r1
        // 32.    3     0.0    0.0    0.0       ldr	r1, [r0, #88]
        // 33.    3     0.0    0.0    0.0       eors.w	lr, lr, r1
        // 34.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #128]
        // 35.    3     0.0    0.0    0.0       eors.w	lr, lr, r1
        // 36.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #168]
        // 37.    3     0.0    0.0    0.0       eors.w	lr, lr, r1
        // 38.    3     0.0    0.0    0.0       eors.w	r8, r6, lr
        // 39.    3     0.0    0.0    0.0       str.w	r8, [sp, #4]
        // 40.    3     0.0    0.0    0.0       ldr	r5, [r0, #16]
        // 41.    3     0.0    0.0    0.0       ldr	r1, [r0, #56]
        // 42.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 43.    3     0.0    0.0    0.0       ldr	r1, [r0, #96]
        // 44.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 45.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #136]
        // 46.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 47.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #176]
        // 48.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 49.    3     0.0    0.0    0.0       eor.w	r9, r5, r6, ror #31
        // 50.    3     0.0    0.0    0.0       str.w	r9, [sp, #8]
        // 51.    3     0.0    0.0    0.0       ldr	r4, [r0, #20]
        // 52.    3     0.0    0.0    0.0       ldr	r1, [r0, #60]
        // 53.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 54.    3     0.0    0.0    0.0       ldr	r1, [r0, #100]
        // 55.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 56.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #140]
        // 57.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 58.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #180]
        // 59.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 60.    3     0.0    0.0    0.0       eors	r3, r4
        // 61.    3     0.0    0.0    0.0       str	r3, [sp, #12]
        // 62.    3     0.0    0.0    0.0       ldr	r3, [r0]
        // 63.    3     0.0    0.0    0.0       ldr	r1, [r0, #40]
        // 64.    3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 65.    3     0.0    0.0    0.0       ldr	r1, [r0, #80]
        // 66.    3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 67.    3     0.0    0.0    0.0       ldr	r1, [r0, #120]
        // 68.    3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 69.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #160]
        // 70.    3     0.0    0.0    0.0       eors.w	r3, r3, r1
        // 71.    3     0.0    0.0    0.0       eor.w	r10, r3, r4, ror #31
        // 72.    3     0.0    0.0    0.0       ldr	r6, [r0, #4]
        // 73.    3     0.0    0.0    0.0       ldr	r1, [r0, #44]
        // 74.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 75.    3     0.0    0.0    0.0       ldr	r1, [r0, #84]
        // 76.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 77.    3     0.0    0.0    0.0       ldr	r1, [r0, #124]
        // 78.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 79.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #164]
        // 80.    3     0.0    0.0    0.0       eors.w	r6, r6, r1
        // 81.    3     0.0    0.0    0.0       eors.w	r11, r6, r5
        // 82.    3     0.0    0.0    0.0       ldr	r4, [r0, #28]
        // 83.    3     0.0    0.0    0.0       ldr	r1, [r0, #68]
        // 84.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 85.    3     0.0    0.0    0.0       ldr	r1, [r0, #108]
        // 86.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 87.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #148]
        // 88.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 89.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #188]
        // 90.    3     0.0    0.0    0.0       eors.w	r4, r4, r1
        // 91.    3     0.0    0.0    0.0       eor.w	r5, lr, r4, ror #31
        // 92.    3     0.0    0.0    0.0       str	r5, [sp, #16]
        // 93.    3     0.0    0.0    0.0       ldr	r5, [r0, #24]
        // 94.    3     0.0    0.0    0.0       ldr	r1, [r0, #64]
        // 95.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 96.    3     0.0    0.0    0.0       ldr	r1, [r0, #104]
        // 97.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 98.    3     0.0    0.0    0.0       ldr.w	r1, [r0, #144]
        // 99.    3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 100.   3     0.0    0.0    0.0       ldr.w	r1, [r0, #184]
        // 101.   3     0.0    0.0    0.0       eors.w	r5, r5, r1
        // 102.   3     0.0    0.0    0.0       eors.w	r2, r7, r5
        // 103.   3     0.0    0.0    0.0       eor.w	r12, r5, r6, ror #31
        // 104.   3     0.0    0.0    0.0       eors.w	lr, r4, r3
        // 105.   3     0.0    0.0    0.0       ldr	r5, [r0, #84]
        // 106.   3     0.0    0.0    0.0       ldr.w	r6, [r0, #132]
        // 107.   3     0.0    0.0    0.0       ldr.w	r7, [r0, #180]
        // 108.   3     0.0    0.0    0.0       ldr	r3, [r0, #24]
        // 109.   3     0.0    0.0    0.0       ldr	r4, [r0, #72]
        // 110.   3     0.0    0.0    0.0       eors.w	r5, r5, r8
        // 111.   3     0.0    0.0    0.0       eors.w	r7, r7, r2
        // 112.   3     0.0    0.0    0.0       eors.w	r6, r6, r11
        // 113.   3     0.0    0.0    0.0       eors.w	r3, r3, r9
        // 114.   3     0.0    0.0    0.0       eors.w	r4, r4, r12
        // 115.   3     0.0    0.0    0.0       rors.w	r5, r5, #30
        // 116.   3     0.0    0.0    0.0       rors.w	r6, r6, #9
        // 117.   3     0.0    0.0    0.0       rors.w	r7, r7, #1
        // 118.   3     0.0    0.0    0.0       rors.w	r3, r3, #18
        // 119.   3     0.0    0.0    0.0       rors.w	r4, r4, #22
        // 120.   3     0.0    0.0    0.0       bic.w	r1, r5, r4
        // 121.   3     0.0    0.0    0.0       eors.w	r1, r1, r3
        // 122.   3     0.0    0.0    0.0       str	r1, [r0, #84]
        // 123.   3     0.0    0.0    0.0       bic.w	r1, r6, r5
        // 124.   3     0.0    0.0    0.0       eors.w	r1, r1, r4
        // 125.   3     0.0    0.0    0.0       str.w	r1, [r0, #132]
        // 126.   3     0.0    0.0    0.0       bic.w	r1, r7, r6
        // 127.   3     0.0    0.0    0.0       eors.w	r1, r1, r5
        // 128.   3     0.0    0.0    0.0       str.w	r1, [r0, #180]
        // 129.   3     0.0    0.0    0.0       bic.w	r1, r3, r7
        // 130.   3     0.0    0.0    0.0       eors.w	r1, r1, r6
        // 131.   3     0.0    0.0    0.0       str	r1, [r0, #24]
        // 132.   3     0.0    0.0    0.0       bic.w	r1, r4, r3
        // 133.   3     0.0    0.0    0.0       eors.w	r1, r1, r7
        // 134.   3     0.0    0.0    0.0       str	r1, [r0, #72]
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
        // Instructions:      13500
        // Total Cycles:      7201
        // Total uOps:        13500
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.87
        // IPC:               1.87
        // Block RThroughput: 67.5
        //
        //
        // Cycles with backend pressure increase [ 5.54% ]
        // Throughput Bottlenecks:
        //   Resource Pressure       [ 0.00% ]
        //   Data Dependencies:      [ 5.54% ]
        //   - Register Dependencies [ 5.54% ]
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
        //  1      2     0.50    *                   ldr	r5, [r0, #104]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #164]
        //  1      2     0.50    *                   ldr	r3, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r12, [r0, #84]
        //  1      2     0.50    *                   ldr	r1, [r0, #32]
        //  1      2     0.50    *                   ldr	r4, [r0, #44]
        //  1      2     0.50    *                   ldr	r6, [r0, #4]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #184]
        //  1      2     0.50    *                   ldr.w	r2, [r0, #144]
        //  1      1     0.50                        eors.w	r4, r6, r4
        //  1      2     0.50    *                   ldr.w	r8, [r0, #124]
        //  1      2     0.50    *                   ldr	r6, [r0, #64]
        //  1      1     0.50                        eors.w	r4, r4, r12
        //  1      1     0.50                        eors.w	r12, r3, r6
        //  1      1     0.50                        eors.w	r5, r12, r5
        //  1      1     0.50                        eors.w	r4, r4, r8
        //  1      1     0.50                        eors.w	r5, r5, r2
        //  1      1     0.50                        eors.w	r8, r4, lr
        //  1      1     0.50                        eors.w	r6, r5, r11
        //  1      2     0.50    *                   ldr.w	r10, [r0, #72]
        //  1      1     0.50                        eors.w	r10, r1, r10
        //  1      2     1.00                        eor.w	r12, r6, r8, ror #31
        //  1      2     0.50    *                   ldr	r3, [r0, #52]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #12]
        //  1      2     0.50    *                   ldr	r1, [r0, #92]
        //  1      1     0.50                        eors.w	r5, lr, r3
        //  1      2     0.50    *                   ldr.w	r11, [r0, #132]
        //  1      2     0.50    *                   ldr	r3, [r0, #112]
        //  1      2     0.50    *                   ldr.w	r2, [r0, #152]
        //  1      1     0.50                        eors.w	r9, r10, r3
        //  1      1     0.50                        eors.w	r1, r5, r1
        //  1      1     0.50                        eors.w	r3, r9, r2
        //  1      2     0.50    *                   ldr.w	r5, [r0, #172]
        //  1      1     0.50                        eors.w	r7, r1, r11
        //  1      1     0.50                        eors.w	r1, r7, r5
        //  1      2     0.50    *                   ldr.w	r9, [r0, #192]
        //  1      1     0.50                        eors.w	r2, r1, r6
        //  1      1     0.50                        eors.w	r7, r3, r9
        //  1      2     1.00                        eor.w	r5, r7, r1, ror #31
        //  1      2     0.50    *                   ldr.w	lr, [r0, #36]
        //  1      2     0.50    *                   ldr.w	r11, [r0, #76]
        //  1      2     0.50    *                   ldr.w	r6, [r0, #156]
        //  1      1     0.50                        eors.w	lr, lr, r11
        //  1      2     0.50    *                   ldr.w	r11, [r0, #116]
        //  1      1     0.50                        eors.w	r11, lr, r11
        //  1      3     1.00           *            str	r5, [sp]
        //  1      1     0.50                        eors.w	r9, r11, r6
        //  1      2     0.50    *                   ldr.w	r4, [r0, #196]
        //  1      2     0.50    *                   ldr.w	r10, [r0, #8]
        //  1      2     0.50    *                   ldr	r6, [r0, #48]
        //  1      1     0.50                        eors.w	r11, r10, r6
        //  1      2     0.50    *                   ldr	r1, [r0, #88]
        //  1      2     0.50    *                   ldr.w	r10, [r0, #128]
        //  1      1     0.50                        eors.w	r3, r11, r1
        //  1      1     0.50                        eors.w	lr, r3, r10
        //  1      2     0.50    *                   ldr.w	r5, [r0, #168]
        //  1      1     0.50                        eors.w	r1, r9, r4
        //  1      1     0.50                        eors.w	r11, lr, r5
        //  1      2     0.50    *                   ldr	r6, [r0, #56]
        //  1      2     0.50    *                   ldr	r4, [r0, #16]
        //  1      1     0.50                        eors.w	r3, r4, r6
        //  1      2     0.50    *                   ldr.w	r9, [r0, #96]
        //  1      2     0.50    *                   ldr.w	r5, [r0, #136]
        //  1      1     0.50                        eors.w	r4, r3, r9
        //  1      2     0.50    *                   ldr.w	r10, [r0, #176]
        //  1      1     0.50                        eors.w	r3, r4, r5
        //  1      1     0.50                        eors.w	r5, r1, r11
        //  1      1     0.50                        eors.w	r6, r3, r10
        //  1      3     1.00           *            str	r5, [sp, #4]
        //  1      2     1.00                        eor.w	r4, r6, r1, ror #31
        //  1      2     0.50    *                   ldr	r1, [r0, #20]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #60]
        //  1      1     0.50                        eors.w	r1, r1, lr
        //  1      2     0.50    *                   ldr	r3, [r0, #100]
        //  1      1     0.50                        eors.w	r10, r1, r3
        //  1      2     0.50    *                   ldr.w	r9, [r0, #140]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #180]
        //  1      1     0.50                        eors.w	r3, r10, r9
        //  1      3     1.00           *            str	r4, [sp, #8]
        //  1      1     0.50                        eors.w	r9, r3, lr
        //  1      2     0.50    *                   ldr.w	lr, [r0]
        //  1      2     0.50    *                   ldr	r1, [r0, #40]
        //  1      1     0.50                        eors.w	r10, r7, r9
        //  1      1     0.50                        eors.w	r7, lr, r1
        //  1      2     0.50    *                   ldr.w	lr, [r0, #28]
        //  1      2     0.50    *                   ldr	r3, [r0, #68]
        //  1      1     0.50                        eors.w	lr, lr, r3
        //  1      2     0.50    *                   ldr	r3, [r0, #108]
        //  1      1     0.50                        eors.w	r1, lr, r3
        //  1      2     0.50    *                   ldr.w	lr, [r0, #148]
        //  1      1     0.50                        eors.w	lr, r1, lr
        //  1      2     0.50    *                   ldr.w	r3, [r0, #188]
        //  1      2     0.50    *                   ldr	r1, [r0, #120]
        //  1      1     0.50                        eors.w	r3, lr, r3
        //  1      3     1.00           *            str.w	r10, [sp, #12]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #80]
        //  1      1     0.50                        eors.w	r7, r7, lr
        //  1      2     1.00                        eor.w	lr, r11, r3, ror #31
        //  1      1     0.50                        eors.w	r1, r7, r1
        //  1      1     0.50                        eors.w	r11, r8, r6
        //  1      3     1.00           *            str.w	lr, [sp, #16]
        //  1      2     0.50    *                   ldr.w	lr, [r0, #84]
        //  1      2     0.50    *                   ldr.w	r7, [r0, #132]
        //  1      2     0.50    *                   ldr.w	r10, [r0, #180]
        //  1      2     0.50    *                   ldr	r6, [r0, #24]
        //  1      2     0.50    *                   ldr.w	r8, [r0, #72]
        //  1      1     0.50                        eors.w	lr, lr, r5
        //  1      1     0.50                        eors.w	r6, r6, r4
        //  1      1     1.00                        rors.w	lr, lr, #30
        //  1      1     0.50                        eors.w	r8, r8, r12
        //  1      1     1.00                        rors.w	r6, r6, #18
        //  1      1     1.00                        rors.w	r8, r8, #22
        //  1      1     0.50                        eors.w	r10, r10, r2
        //  1      1     0.50                        eors.w	r7, r7, r11
        //  1      1     0.50                        bic.w	r5, lr, r8
        //  1      1     1.00                        rors.w	r7, r7, #9
        //  1      1     0.50                        eors.w	r4, r5, r6
        //  1      3     1.00           *            str	r4, [r0, #84]
        //  1      1     0.50                        bic.w	r5, r7, lr
        //  1      1     1.00                        rors.w	r10, r10, #1
        //  1      1     0.50                        eors.w	r5, r5, r8
        //  1      3     1.00           *            str.w	r5, [r0, #132]
        //  1      1     0.50                        bic.w	r5, r10, r7
        //  1      2     0.50    *                   ldr.w	r4, [r0, #160]
        //  1      1     0.50                        eors.w	r5, r5, lr
        //  1      3     1.00           *            str.w	r5, [r0, #180]
        //  1      1     0.50                        bic.w	r5, r6, r10
        //  1      1     0.50                        eors.w	r1, r1, r4
        //  1      1     0.50                        eors.w	r5, r5, r7
        //  1      3     1.00           *            str	r5, [r0, #24]
        //  1      1     0.50                        bic.w	r4, r8, r6
        //  1      1     0.50                        eors.w	lr, r3, r1
        //  1      1     0.50                        eors.w	r8, r4, r10
        //  1      3     1.00           *            str.w	r8, [r0, #72]
        //  1      2     1.00                        eor.w	r10, r1, r9, ror #31
        //
        //
        // Dynamic Dispatch Stall Cycles:
        // RAT     - Register unavailable:                      399  (5.5%)
        // RCU     - Retire tokens unavailable:                 0
        // SCHEDQ  - Scheduler full:                            0
        // LQ      - Load queue full:                           0
        // SQ      - Store queue full:                          0
        // GROUP   - Static restrictions on the dispatch group: 0
        // USH     - Uncategorised Structural Hazard:           0
        //
        //
        // Dispatch Logic - number of cycles where we saw N micro opcodes dispatched:
        // [# dispatched], [# cycles]
        //  0,              1  (0.0%)
        //  1,              900  (12.5%)
        //  2,              6300  (87.5%)
        //
        //
        // Schedulers - number of cycles where we saw N micro opcodes issued:
        // [# issued], [# cycles]
        //  0,          1  (0.0%)
        //  1,          900  (12.5%)
        //  2,          6300  (87.5%)
        //
        // Scheduler's queue usage:
        // No scheduler resources used.
        //
        //
        // Register File statistics:
        // Total number of mappings created:    18500
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
        // 35.00  35.00   -     27.50  27.50   -      -     10.00   -     10.00   -      -      -
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3]    [4]    [5]    [6]    [7]    [8]    [9]    [10]   [11]   Instructions:
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r5, [r0, #104]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #164]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #24]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r12, [r0, #84]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #32]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #44]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #4]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #184]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r2, [r0, #144]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r6, r4
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #124]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #64]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r12
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r12, r3, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r12, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r4, r8
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r8, r4, lr
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r5, r11
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r10, [r0, #72]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r1, r10
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r12, r6, r8, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #52]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #12]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #92]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, lr, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #132]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #112]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r2, [r0, #152]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r9, r10, r3
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r5, r1
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r9, r2
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #172]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r1, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r7, r5
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r9, [r0, #192]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r2, r1, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r3, r9
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r5, r7, r1, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #36]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #76]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r6, [r0, #156]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r11
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r11, [r0, #116]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, lr, r11
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [sp]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r9, r11, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #196]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r10, [r0, #8]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #48]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, r10, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #88]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r10, [r0, #128]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r11, r1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, r3, r10
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #168]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r9, r4
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, lr, r5
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #56]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r4, [r0, #16]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r4, r6
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r9, [r0, #96]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r5, [r0, #136]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r3, r9
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r10, [r0, #176]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r4, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r1, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r3, r10
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [sp, #4]
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r4, r6, r1, ror #31
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #20]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #60]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, lr
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #100]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r1, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r9, [r0, #140]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #180]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, r10, r9
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [sp, #8]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r9, r3, lr
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #40]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r7, r9
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, lr, r1
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #28]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #68]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r3, [r0, #108]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, lr, r3
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #148]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, r1, lr
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r3, [r0, #188]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r1, [r0, #120]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r3, lr, r3
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r10, [sp, #12]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #80]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, lr
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     eor.w	lr, r11, r3, ror #31
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r7, r1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r11, r8, r6
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	lr, [sp, #16]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	lr, [r0, #84]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r7, [r0, #132]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r10, [r0, #180]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr	r6, [r0, #24]
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r8, [r0, #72]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, lr, r5
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r6, r6, r4
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	lr, lr, #30
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r8, r8, r12
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r6, r6, #18
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r8, r8, #22
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r10, r10, r2
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r7, r7, r11
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r5, lr, r8
        //  -     1.00    -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r7, r7, #9
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r4, r5, r6
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r4, [r0, #84]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r5, r7, lr
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     rors.w	r10, r10, #1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r8
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #132]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r5, r10, r7
        //  -      -      -     0.50   0.50    -      -      -      -      -      -      -      -     ldr.w	r4, [r0, #160]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, lr
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r5, [r0, #180]
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     bic.w	r5, r6, r10
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r1, r1, r4
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	r5, r5, r7
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str	r5, [r0, #24]
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     bic.w	r4, r8, r6
        // 1.00    -      -      -      -      -      -      -      -      -      -      -      -     eors.w	lr, r3, r1
        //  -     1.00    -      -      -      -      -      -      -      -      -      -      -     eors.w	r8, r4, r10
        //  -      -      -      -      -      -      -      -      -     1.00    -      -      -     str.w	r8, [r0, #72]
        // 1.00    -      -      -      -      -      -     1.00    -      -      -      -      -     eor.w	r10, r1, r9, ror #31
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456
        // Index     0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789          0123456789
        //
        // [0,0]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #104]
        // [0,1]     DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #164]
        // [0,2]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [0,3]     .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #84]
        // [0,4]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #32]
        // [0,5]     . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #44]
        // [0,6]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [0,7]     .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #184]
        // [0,8]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #144]
        // [0,9]     .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r6, r4
        // [0,10]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #124]
        // [0,11]    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #64]
        // [0,12]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [0,13]    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r12, r3, r6
        // [0,14]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r12, r5
        // [0,15]    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r8
        // [0,16]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r2
        // [0,17]    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r4, lr
        // [0,18]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r5, r11
        // [0,19]    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #72]
        // [0,20]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r1, r10
        // [0,21]    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r6, r8, ror #31
        // [0,22]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #52]
        // [0,23]    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #12]
        // [0,24]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [0,25]    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, lr, r3
        // [0,26]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #132]
        // [0,27]    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #112]
        // [0,28]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #152]
        // [0,29]    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r10, r3
        // [0,30]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r5, r1
        // [0,31]    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r9, r2
        // [0,32]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #172]
        // [0,33]    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r1, r11
        // [0,34]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r7, r5
        // [0,35]    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #192]
        // [0,36]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r1, r6
        // [0,37]    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r3, r9
        // [0,38]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, r7, r1, ror #31
        // [0,39]    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #36]
        // [0,40]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #76]
        // [0,41]    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #156]
        // [0,42]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r11
        // [0,43]    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #116]
        // [0,44]    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r11
        // [0,45]    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp]
        // [0,46]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r11, r6
        // [0,47]    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #196]
        // [0,48]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #8]
        // [0,49]    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #48]
        // [0,50]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r10, r6
        // [0,51]    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [0,52]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #128]
        // [0,53]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r11, r1
        // [0,54]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r3, r10
        // [0,55]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #168]
        // [0,56]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r9, r4
        // [0,57]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r5
        // [0,58]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #56]
        // [0,59]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #16]
        // [0,60]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r4, r6
        // [0,61]    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #96]
        // [0,62]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #136]
        // [0,63]    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r3, r9
        // [0,64]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #176]
        // [0,65]    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r4, r5
        // [0,66]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r1, r11
        // [0,67]    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r3, r10
        // [0,68]    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #4]
        // [0,69]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r4, r6, r1, ror #31
        // [0,70]    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #20]
        // [0,71]    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #60]
        // [0,72]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, lr
        // [0,73]    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #100]
        // [0,74]    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r1, r3
        // [0,75]    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #140]
        // [0,76]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #180]
        // [0,77]    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r10, r9
        // [0,78]    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r4, [sp, #8]
        // [0,79]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r3, lr
        // [0,80]    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0]
        // [0,81]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [0,82]    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r7, r9
        // [0,83]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, lr, r1
        // [0,84]    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #28]
        // [0,85]    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #68]
        // [0,86]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r3
        // [0,87]    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #108]
        // [0,88]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, lr, r3
        // [0,89]    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #148]
        // [0,90]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r1, lr
        // [0,91]    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r3, [r0, #188]
        // [0,92]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [0,93]    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, lr, r3
        // [0,94]    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r10, [sp, #12]
        // [0,95]    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #80]
        // [0,96]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, lr
        // [0,97]    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	lr, r11, r3, ror #31
        // [0,98]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r7, r1
        // [0,99]    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r8, r6
        // [0,100]   .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	lr, [sp, #16]
        // [0,101]   .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #84]
        // [0,102]   .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #132]
        // [0,103]   .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #180]
        // [0,104]   .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #24]
        // [0,105]   .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #72]
        // [0,106]   .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r5
        // [0,107]   .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r4
        // [0,108]   .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	lr, lr, #30
        // [0,109]   .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r8, r12
        // [0,110]   .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #18
        // [0,111]   .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r8, r8, #22
        // [0,112]   .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r10, r2
        // [0,113]   .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r11
        // [0,114]   .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, lr, r8
        // [0,115]   .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #9
        // [0,116]   .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r5, r6
        // [0,117]   .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r4, [r0, #84]
        // [0,118]   .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r7, lr
        // [0,119]   .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r10, r10, #1
        // [0,120]   .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [0,121]   .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r5, [r0, #132]
        // [0,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r10, r7
        // [0,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #160]
        // [0,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, lr
        // [0,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r5, [r0, #180]
        // [0,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r6, r10
        // [0,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [0,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r7
        // [0,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [r0, #24]
        // [0,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r4, r8, r6
        // [0,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r3, r1
        // [0,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r4, r10
        // [0,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [r0, #72]
        // [0,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r1, r9, ror #31
        // [1,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #104]
        // [1,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #164]
        // [1,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [1,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #84]
        // [1,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #32]
        // [1,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #44]
        // [1,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [1,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #184]
        // [1,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #144]
        // [1,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r6, r4
        // [1,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #124]
        // [1,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #64]
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r12, r3, r6
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r12, r5
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r8
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r2
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r4, lr
        // [1,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r5, r11
        // [1,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #72]
        // [1,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r1, r10
        // [1,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r6, r8, ror #31
        // [1,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #52]
        // [1,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #12]
        // [1,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [1,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, lr, r3
        // [1,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #132]
        // [1,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #112]
        // [1,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #152]
        // [1,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r10, r3
        // [1,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r5, r1
        // [1,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r9, r2
        // [1,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #172]
        // [1,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r1, r11
        // [1,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r7, r5
        // [1,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #192]
        // [1,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r1, r6
        // [1,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r3, r9
        // [1,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, r7, r1, ror #31
        // [1,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #36]
        // [1,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #76]
        // [1,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #156]
        // [1,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r11
        // [1,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #116]
        // [1,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r11
        // [1,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp]
        // [1,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r11, r6
        // [1,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #196]
        // [1,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #8]
        // [1,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #48]
        // [1,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r10, r6
        // [1,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [1,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #128]
        // [1,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r11, r1
        // [1,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r3, r10
        // [1,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #168]
        // [1,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r9, r4
        // [1,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r5
        // [1,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #56]
        // [1,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #16]
        // [1,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r4, r6
        // [1,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #96]
        // [1,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #136]
        // [1,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r3, r9
        // [1,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #176]
        // [1,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r4, r5
        // [1,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r1, r11
        // [1,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r3, r10
        // [1,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [sp, #4]
        // [1,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r4, r6, r1, ror #31
        // [1,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #20]
        // [1,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #60]
        // [1,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, lr
        // [1,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #100]
        // [1,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r1, r3
        // [1,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #140]
        // [1,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #180]
        // [1,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r10, r9
        // [1,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r4, [sp, #8]
        // [1,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r3, lr
        // [1,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0]
        // [1,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [1,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r7, r9
        // [1,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, lr, r1
        // [1,84]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #28]
        // [1,85]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #68]
        // [1,86]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r3
        // [1,87]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #108]
        // [1,88]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, lr, r3
        // [1,89]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #148]
        // [1,90]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r1, lr
        // [1,91]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r3, [r0, #188]
        // [1,92]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #120]
        // [1,93]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, lr, r3
        // [1,94]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r10, [sp, #12]
        // [1,95]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #80]
        // [1,96]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, lr
        // [1,97]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	lr, r11, r3, ror #31
        // [1,98]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r7, r1
        // [1,99]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r11, r8, r6
        // [1,100]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	lr, [sp, #16]
        // [1,101]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #84]
        // [1,102]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r7, [r0, #132]
        // [1,103]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #180]
        // [1,104]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #24]
        // [1,105]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #72]
        // [1,106]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r5
        // [1,107]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r6, r4
        // [1,108]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	lr, lr, #30
        // [1,109]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r8, r12
        // [1,110]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r6, r6, #18
        // [1,111]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r8, r8, #22
        // [1,112]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r10, r2
        // [1,113]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r7, r11
        // [1,114]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, lr, r8
        // [1,115]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r7, r7, #9
        // [1,116]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r5, r6
        // [1,117]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r4, [r0, #84]
        // [1,118]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r7, lr
        // [1,119]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   rors.w	r10, r10, #1
        // [1,120]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r8
        // [1,121]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r5, [r0, #132]
        // [1,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r10, r7
        // [1,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #160]
        // [1,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, lr
        // [1,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r5, [r0, #180]
        // [1,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r5, r6, r10
        // [1,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r1, r4
        // [1,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r7
        // [1,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str	r5, [r0, #24]
        // [1,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   bic.w	r4, r8, r6
        // [1,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	lr, r3, r1
        // [1,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r4, r10
        // [1,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   str.w	r8, [r0, #72]
        // [1,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r10, r1, r9, ror #31
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r5, [r0, #104]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #164]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #24]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r12, [r0, #84]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #32]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #44]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #4]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #184]
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #144]
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r6, r4
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r8, [r0, #124]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #64]
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r12
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r12, r3, r6
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r12, r5
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r4, r4, r8
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, r5, r2
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r8, r4, lr
        // [2,18]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r6, r5, r11
        // [2,19]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #72]
        // [2,20]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r10, r1, r10
        // [2,21]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .    ..   eor.w	r12, r6, r8, ror #31
        // [2,22]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #52]
        // [2,23]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #12]
        // [2,24]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #92]
        // [2,25]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r5, lr, r3
        // [2,26]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #132]
        // [2,27]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    ..   ldr	r3, [r0, #112]
        // [2,28]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r2, [r0, #152]
        // [2,29]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r10, r3
        // [2,30]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r5, r1
        // [2,31]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    ..   eors.w	r3, r9, r2
        // [2,32]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #172]
        // [2,33]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r1, r11
        // [2,34]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   eors.w	r1, r7, r5
        // [2,35]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #192]
        // [2,36]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    ..   eors.w	r2, r1, r6
        // [2,37]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    ..   eors.w	r7, r3, r9
        // [2,38]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    ..   eor.w	r5, r7, r1, ror #31
        // [2,39]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    ..   ldr.w	lr, [r0, #36]
        // [2,40]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #76]
        // [2,41]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    ..   ldr.w	r6, [r0, #156]
        // [2,42]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    ..   eors.w	lr, lr, r11
        // [2,43]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    .    ..   ldr.w	r11, [r0, #116]
        // [2,44]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r11
        // [2,45]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .    .    .    .    .    .    .    ..   str	r5, [sp]
        // [2,46]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   eors.w	r9, r11, r6
        // [2,47]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    ..   ldr.w	r4, [r0, #196]
        // [2,48]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #8]
        // [2,49]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #48]
        // [2,50]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    ..   eors.w	r11, r10, r6
        // [2,51]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    ..   ldr	r1, [r0, #88]
        // [2,52]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #128]
        // [2,53]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    .    ..   eors.w	r3, r11, r1
        // [2,54]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   eors.w	lr, r3, r10
        // [2,55]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #168]
        // [2,56]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   eors.w	r1, r9, r4
        // [2,57]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    ..   eors.w	r11, lr, r5
        // [2,58]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr	r6, [r0, #56]
        // [2,59]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    ..   ldr	r4, [r0, #16]
        // [2,60]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   eors.w	r3, r4, r6
        // [2,61]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    ..   ldr.w	r9, [r0, #96]
        // [2,62]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   ldr.w	r5, [r0, #136]
        // [2,63]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    .    ..   eors.w	r4, r3, r9
        // [2,64]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   ldr.w	r10, [r0, #176]
        // [2,65]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    .    ..   eors.w	r3, r4, r5
        // [2,66]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   eors.w	r5, r1, r11
        // [2,67]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    .    ..   eors.w	r6, r3, r10
        // [2,68]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    ..   str	r5, [sp, #4]
        // [2,69]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   eor.w	r4, r6, r1, ror #31
        // [2,70]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    .    .    ..   ldr	r1, [r0, #20]
        // [2,71]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .    ..   ldr.w	lr, [r0, #60]
        // [2,72]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   eors.w	r1, r1, lr
        // [2,73]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .    ..   ldr	r3, [r0, #100]
        // [2,74]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   eors.w	r10, r1, r3
        // [2,75]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .    ..   ldr.w	r9, [r0, #140]
        // [2,76]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   ldr.w	lr, [r0, #180]
        // [2,77]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .    ..   eors.w	r3, r10, r9
        // [2,78]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    ..   str	r4, [sp, #8]
        // [2,79]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   eors.w	r9, r3, lr
        // [2,80]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    ..   ldr.w	lr, [r0]
        // [2,81]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    ..   ldr	r1, [r0, #40]
        // [2,82]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    ..   eors.w	r10, r7, r9
        // [2,83]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    ..   eors.w	r7, lr, r1
        // [2,84]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    ..   ldr.w	lr, [r0, #28]
        // [2,85]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    ..   ldr	r3, [r0, #68]
        // [2,86]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   eors.w	lr, lr, r3
        // [2,87]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    .    ..   ldr	r3, [r0, #108]
        // [2,88]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   eors.w	r1, lr, r3
        // [2,89]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    ..   ldr.w	lr, [r0, #148]
        // [2,90]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   eors.w	lr, r1, lr
        // [2,91]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    ..   ldr.w	r3, [r0, #188]
        // [2,92]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   ldr	r1, [r0, #120]
        // [2,93]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    ..   eors.w	r3, lr, r3
        // [2,94]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    ..   str.w	r10, [sp, #12]
        // [2,95]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    .    ..   ldr.w	lr, [r0, #80]
        // [2,96]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   eors.w	r7, r7, lr
        // [2,97]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    ..   eor.w	lr, r11, r3, ror #31
        // [2,98]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   eors.w	r1, r7, r1
        // [2,99]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    ..   eors.w	r11, r8, r6
        // [2,100]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .    ..   str.w	lr, [sp, #16]
        // [2,101]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   ldr.w	lr, [r0, #84]
        // [2,102]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    ..   ldr.w	r7, [r0, #132]
        // [2,103]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   ldr.w	r10, [r0, #180]
        // [2,104]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    .    ..   ldr	r6, [r0, #24]
        // [2,105]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   ldr.w	r8, [r0, #72]
        // [2,106]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    ..   eors.w	lr, lr, r5
        // [2,107]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   eors.w	r6, r6, r4
        // [2,108]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    ..   rors.w	lr, lr, #30
        // [2,109]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   eors.w	r8, r8, r12
        // [2,110]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    ..   rors.w	r6, r6, #18
        // [2,111]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   rors.w	r8, r8, #22
        // [2,112]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    ..   eors.w	r10, r10, r2
        // [2,113]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   eors.w	r7, r7, r11
        // [2,114]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    .    ..   bic.w	r5, lr, r8
        // [2,115]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   rors.w	r7, r7, #9
        // [2,116]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   .    ..   eors.w	r4, r5, r6
        // [2,117]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    ..   str	r4, [r0, #84]
        // [2,118]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    ..   bic.w	r5, r7, lr
        // [2,119]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE .    ..   rors.w	r10, r10, #1
        // [2,120]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE.    ..   eors.w	r5, r5, r8
        // [2,121]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE    ..   str.w	r5, [r0, #132]
        // [2,122]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    ..   bic.w	r5, r10, r7
        // [2,123]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE    ..   ldr.w	r4, [r0, #160]
        // [2,124]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   ..   eors.w	r5, r5, lr
        // [2,125]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DeE  ..   str.w	r5, [r0, #180]
        // [2,126]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  ..   bic.w	r5, r6, r10
        // [2,127]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE  ..   eors.w	r1, r1, r4
        // [2,128]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE ..   eors.w	r5, r5, r7
        // [2,129]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE..   str	r5, [r0, #24]
        // [2,130]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE..   bic.w	r4, r8, r6
        // [2,131]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DE..   eors.w	lr, r3, r1
        // [2,132]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE.   eors.w	r8, r4, r10
        // [2,133]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeE   str.w	r8, [r0, #72]
        // [2,134]   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE   eor.w	r10, r1, r9, ror #31
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	r5, [r0, #104]
        // 1.     3     0.0    0.0    0.0       ldr.w	lr, [r0, #164]
        // 2.     3     0.0    0.0    0.0       ldr	r3, [r0, #24]
        // 3.     3     0.0    0.0    0.0       ldr.w	r12, [r0, #84]
        // 4.     3     0.0    0.0    0.0       ldr	r1, [r0, #32]
        // 5.     3     0.0    0.0    0.0       ldr	r4, [r0, #44]
        // 6.     3     0.0    0.0    0.0       ldr	r6, [r0, #4]
        // 7.     3     0.0    0.0    0.0       ldr.w	r11, [r0, #184]
        // 8.     3     0.0    0.0    0.0       ldr.w	r2, [r0, #144]
        // 9.     3     0.0    0.0    0.0       eors.w	r4, r6, r4
        // 10.    3     0.0    0.0    0.0       ldr.w	r8, [r0, #124]
        // 11.    3     0.0    0.0    0.0       ldr	r6, [r0, #64]
        // 12.    3     0.0    0.0    0.0       eors.w	r4, r4, r12
        // 13.    3     0.0    0.0    0.0       eors.w	r12, r3, r6
        // 14.    3     0.0    0.0    0.0       eors.w	r5, r12, r5
        // 15.    3     0.0    0.0    0.0       eors.w	r4, r4, r8
        // 16.    3     0.0    0.0    0.0       eors.w	r5, r5, r2
        // 17.    3     0.0    0.0    0.0       eors.w	r8, r4, lr
        // 18.    3     0.0    0.0    0.0       eors.w	r6, r5, r11
        // 19.    3     0.0    0.0    0.0       ldr.w	r10, [r0, #72]
        // 20.    3     0.0    0.0    0.0       eors.w	r10, r1, r10
        // 21.    3     0.0    0.0    0.0       eor.w	r12, r6, r8, ror #31
        // 22.    3     0.0    0.0    0.0       ldr	r3, [r0, #52]
        // 23.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #12]
        // 24.    3     0.0    0.0    0.0       ldr	r1, [r0, #92]
        // 25.    3     0.0    0.0    0.0       eors.w	r5, lr, r3
        // 26.    3     0.0    0.0    0.0       ldr.w	r11, [r0, #132]
        // 27.    3     0.0    0.0    0.0       ldr	r3, [r0, #112]
        // 28.    3     0.0    0.0    0.0       ldr.w	r2, [r0, #152]
        // 29.    3     0.0    0.0    0.0       eors.w	r9, r10, r3
        // 30.    3     0.0    0.0    0.0       eors.w	r1, r5, r1
        // 31.    3     0.0    0.0    0.0       eors.w	r3, r9, r2
        // 32.    3     0.0    0.0    0.0       ldr.w	r5, [r0, #172]
        // 33.    3     0.0    0.0    0.0       eors.w	r7, r1, r11
        // 34.    3     0.0    0.0    0.0       eors.w	r1, r7, r5
        // 35.    3     0.0    0.0    0.0       ldr.w	r9, [r0, #192]
        // 36.    3     0.0    0.0    0.0       eors.w	r2, r1, r6
        // 37.    3     0.0    0.0    0.0       eors.w	r7, r3, r9
        // 38.    3     0.0    0.0    0.0       eor.w	r5, r7, r1, ror #31
        // 39.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #36]
        // 40.    3     0.0    0.0    0.0       ldr.w	r11, [r0, #76]
        // 41.    3     0.0    0.0    0.0       ldr.w	r6, [r0, #156]
        // 42.    3     0.0    0.0    0.0       eors.w	lr, lr, r11
        // 43.    3     0.0    0.0    0.0       ldr.w	r11, [r0, #116]
        // 44.    3     0.0    0.0    0.0       eors.w	r11, lr, r11
        // 45.    3     0.0    0.0    0.0       str	r5, [sp]
        // 46.    3     0.0    0.0    0.0       eors.w	r9, r11, r6
        // 47.    3     0.0    0.0    0.0       ldr.w	r4, [r0, #196]
        // 48.    3     0.0    0.0    0.0       ldr.w	r10, [r0, #8]
        // 49.    3     0.0    0.0    0.0       ldr	r6, [r0, #48]
        // 50.    3     0.0    0.0    0.0       eors.w	r11, r10, r6
        // 51.    3     0.0    0.0    0.0       ldr	r1, [r0, #88]
        // 52.    3     0.0    0.0    0.0       ldr.w	r10, [r0, #128]
        // 53.    3     0.0    0.0    0.0       eors.w	r3, r11, r1
        // 54.    3     0.0    0.0    0.0       eors.w	lr, r3, r10
        // 55.    3     0.0    0.0    0.0       ldr.w	r5, [r0, #168]
        // 56.    3     0.0    0.0    0.0       eors.w	r1, r9, r4
        // 57.    3     0.0    0.0    0.0       eors.w	r11, lr, r5
        // 58.    3     0.0    0.0    0.0       ldr	r6, [r0, #56]
        // 59.    3     0.0    0.0    0.0       ldr	r4, [r0, #16]
        // 60.    3     0.0    0.0    0.0       eors.w	r3, r4, r6
        // 61.    3     0.0    0.0    0.0       ldr.w	r9, [r0, #96]
        // 62.    3     0.0    0.0    0.0       ldr.w	r5, [r0, #136]
        // 63.    3     0.0    0.0    0.0       eors.w	r4, r3, r9
        // 64.    3     0.0    0.0    0.0       ldr.w	r10, [r0, #176]
        // 65.    3     0.0    0.0    0.0       eors.w	r3, r4, r5
        // 66.    3     0.0    0.0    0.0       eors.w	r5, r1, r11
        // 67.    3     0.0    0.0    0.0       eors.w	r6, r3, r10
        // 68.    3     0.0    0.0    0.0       str	r5, [sp, #4]
        // 69.    3     0.0    0.0    0.0       eor.w	r4, r6, r1, ror #31
        // 70.    3     0.0    0.0    0.0       ldr	r1, [r0, #20]
        // 71.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #60]
        // 72.    3     0.0    0.0    0.0       eors.w	r1, r1, lr
        // 73.    3     0.0    0.0    0.0       ldr	r3, [r0, #100]
        // 74.    3     0.0    0.0    0.0       eors.w	r10, r1, r3
        // 75.    3     0.0    0.0    0.0       ldr.w	r9, [r0, #140]
        // 76.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #180]
        // 77.    3     0.0    0.0    0.0       eors.w	r3, r10, r9
        // 78.    3     0.0    0.0    0.0       str	r4, [sp, #8]
        // 79.    3     0.0    0.0    0.0       eors.w	r9, r3, lr
        // 80.    3     0.0    0.0    0.0       ldr.w	lr, [r0]
        // 81.    3     0.0    0.0    0.0       ldr	r1, [r0, #40]
        // 82.    3     0.0    0.0    0.0       eors.w	r10, r7, r9
        // 83.    3     0.0    0.0    0.0       eors.w	r7, lr, r1
        // 84.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #28]
        // 85.    3     0.0    0.0    0.0       ldr	r3, [r0, #68]
        // 86.    3     0.0    0.0    0.0       eors.w	lr, lr, r3
        // 87.    3     0.0    0.0    0.0       ldr	r3, [r0, #108]
        // 88.    3     0.0    0.0    0.0       eors.w	r1, lr, r3
        // 89.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #148]
        // 90.    3     0.0    0.0    0.0       eors.w	lr, r1, lr
        // 91.    3     0.0    0.0    0.0       ldr.w	r3, [r0, #188]
        // 92.    3     0.0    0.0    0.0       ldr	r1, [r0, #120]
        // 93.    3     0.0    0.0    0.0       eors.w	r3, lr, r3
        // 94.    3     0.0    0.0    0.0       str.w	r10, [sp, #12]
        // 95.    3     0.0    0.0    0.0       ldr.w	lr, [r0, #80]
        // 96.    3     0.0    0.0    0.0       eors.w	r7, r7, lr
        // 97.    3     0.0    0.0    0.0       eor.w	lr, r11, r3, ror #31
        // 98.    3     0.0    0.0    0.0       eors.w	r1, r7, r1
        // 99.    3     0.0    0.0    0.0       eors.w	r11, r8, r6
        // 100.   3     0.0    0.0    0.0       str.w	lr, [sp, #16]
        // 101.   3     0.0    0.0    0.0       ldr.w	lr, [r0, #84]
        // 102.   3     0.0    0.0    0.0       ldr.w	r7, [r0, #132]
        // 103.   3     0.0    0.0    0.0       ldr.w	r10, [r0, #180]
        // 104.   3     0.0    0.0    0.0       ldr	r6, [r0, #24]
        // 105.   3     0.0    0.0    0.0       ldr.w	r8, [r0, #72]
        // 106.   3     0.0    0.0    0.0       eors.w	lr, lr, r5
        // 107.   3     0.0    0.0    0.0       eors.w	r6, r6, r4
        // 108.   3     0.0    0.0    0.0       rors.w	lr, lr, #30
        // 109.   3     0.0    0.0    0.0       eors.w	r8, r8, r12
        // 110.   3     0.0    0.0    0.0       rors.w	r6, r6, #18
        // 111.   3     0.0    0.0    0.0       rors.w	r8, r8, #22
        // 112.   3     0.0    0.0    0.0       eors.w	r10, r10, r2
        // 113.   3     0.0    0.0    0.0       eors.w	r7, r7, r11
        // 114.   3     0.0    0.0    0.0       bic.w	r5, lr, r8
        // 115.   3     0.0    0.0    0.0       rors.w	r7, r7, #9
        // 116.   3     0.0    0.0    0.0       eors.w	r4, r5, r6
        // 117.   3     0.0    0.0    0.0       str	r4, [r0, #84]
        // 118.   3     0.0    0.0    0.0       bic.w	r5, r7, lr
        // 119.   3     0.0    0.0    0.0       rors.w	r10, r10, #1
        // 120.   3     0.0    0.0    0.0       eors.w	r5, r5, r8
        // 121.   3     0.0    0.0    0.0       str.w	r5, [r0, #132]
        // 122.   3     0.0    0.0    0.0       bic.w	r5, r10, r7
        // 123.   3     0.0    0.0    0.0       ldr.w	r4, [r0, #160]
        // 124.   3     0.0    0.0    0.0       eors.w	r5, r5, lr
        // 125.   3     0.0    0.0    0.0       str.w	r5, [r0, #180]
        // 126.   3     0.0    0.0    0.0       bic.w	r5, r6, r10
        // 127.   3     0.0    0.0    0.0       eors.w	r1, r1, r4
        // 128.   3     0.0    0.0    0.0       eors.w	r5, r5, r7
        // 129.   3     0.0    0.0    0.0       str	r5, [r0, #24]
        // 130.   3     0.0    0.0    0.0       bic.w	r4, r8, r6
        // 131.   3     0.0    0.0    0.0       eors.w	lr, r3, r1
        // 132.   3     0.0    0.0    0.0       eors.w	r8, r4, r10
        // 133.   3     0.0    0.0    0.0       str.w	r8, [r0, #72]
        // 134.   3     0.0    0.0    0.0       eor.w	r10, r1, r9, ror #31
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        slothy_end:

 add		sp, #mSize
 pop		{ r4 - r12, pc }

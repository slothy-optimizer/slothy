.text

// This code was inspired by the eXtended Keccak Code Package and then modified
// https://github.com/XKCP/XKCP/tree/master/lib/low/KeccakP-1600/Optimized32biAsmARM/KeccakP-1600-inplace-32bi-armv7m-le-gcc.s

// State offsets
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

.macro xor5 dst,b,g,k,m,s,tmp
    lw    \dst, \b(a0)
    lw    \tmp, \g(a0)
    xor   \dst, \dst, \tmp
    lw    \tmp, \k(a0)
    xor   \dst, \dst, \tmp
    lw    \tmp, \m(a0)
    xor   \dst, \dst, \tmp
    lw    \tmp, \s(a0)
    xor   \dst, \dst, \tmp
.endm

.macro ror reg,dist,tmp
    srli  \tmp, \reg, \dist
    slli  \reg, \reg, 32-\dist
    xor   \reg, \reg, \tmp
.endm

.macro xorrol dst,aa,bb,tmp
    srli  \tmp, \bb, 31
    slli  \dst, \bb, 1
    xor   \dst, \dst, \tmp
    xor   \dst, \dst, \aa
.endm

.macro xorand dst,aa,bb,cc,tmp
    and   \tmp, \bb,  \cc
    xor   \tmp, \tmp, \aa
    sw    \tmp, \dst(a0)
.endm

.macro xornotand dst,aa,bb,cc,tmp
    not   \tmp, \bb
    and   \tmp, \tmp, \cc
    xor   \tmp, \tmp, \aa
    sw    \tmp, \dst(a0)
.endm

.macro notxorand dst,aa,bb,cc,tmp0,tmp1
    not   \tmp0, \aa
    and   \tmp1, \bb,   \cc
    xor   \tmp0, \tmp0, \tmp1
    sw    \tmp0, \dst(a0)
.endm

.macro xoror dst,aa,bb,cc,tmp
    or    \tmp, \bb,  \cc
    xor   \tmp, \tmp, \aa
    sw    \tmp, \dst(a0)
.endm

.macro xornotor dst,aa,bb,cc,tmp
    not   \tmp, \bb
    or    \tmp, \tmp, \cc
    xor   \tmp, \tmp, \aa
    sw    \tmp, \dst(a0)
.endm

.macro notxoror dst,aa,bb,cc,tmp0,tmp1
    not   \tmp0, \aa
    or    \tmp1, \bb,   \cc
    xor   \tmp0, \tmp0, \tmp1
    sw    \tmp0, \dst(a0)
.endm

.macro thetarhopifinal aA1,aDax,aA2,aDex,rot2,aA3,aDix,rot3,aA4,aDox,rot4,aA5,aDux,rot5
    lw      a2, \aA1(a0)
    lw      a3, \aA2(a0)
    lw      a4, \aA3(a0)
    lw      a5, \aA4(a0)
    lw      a6, \aA5(a0)
    xor     a2, a2, \aDax
    xor     a3, a3, \aDex
    xor     a4, a4, \aDix
    xor     a5, a5, \aDox
    xor     a6, a6, \aDux
    ror     a3, (32-\rot2), t6
    ror     a4, (32-\rot3), t6
    ror     a5, (32-\rot4), t6
    ror     a6, (32-\rot5), t6
.endm

.macro thetarhopi aB1,aA1,aDax,rot1,aB2,aA2,aDex,rot2,aB3,aA3,aDix,rot3,aB4,aA4,aDox,rot4,aB5,aA5,aDux,rot5
    lw    \aB1, \aA1(a0)
    lw    \aB2, \aA2(a0)
    lw    \aB3, \aA3(a0)
    lw    \aB4, \aA4(a0)
    lw    \aB5, \aA5(a0)
    xor   \aB1, \aB1, \aDax
    xor   \aB2, \aB2, \aDex
    xor   \aB3, \aB3, \aDix
    xor   \aB4, \aB4, \aDox
    xor   \aB5, \aB5, \aDux
    ror   \aB1, (32-\rot1), t6
    .if \rot2 > 0
    ror   \aB2, (32-\rot2), t6
    .endif
    ror   \aB3, (32-\rot3), t6
    ror   \aB4, (32-\rot4), t6
    ror   \aB5, (32-\rot5), t6
.endm

.macro chipattern0 aA1,aA2,aA3,aA4,aA5
    xoror     \aA1, a2, a3, a4, t6
    xorand    \aA2, a3, a4, a5, t6
    xornotor  \aA3, a4, a6, a5, t6
    xoror     \aA4, a5, a6, a2, t6
    xorand    \aA5, a6, a2, a3, t6
.endm

.macro chipattern1 aA1,aA2,aA3,aA4,aA5
    xoror     \aA1, a2, a3, a4, t6
    xorand    \aA2, a3, a4, a5, t6
    xornotand \aA3, a4, a5, a6, t6
    notxoror  \aA4, a5, a6, a2, t6, t1
    xorand    \aA5, a6, a2, a3, t6
.endm

.macro chipattern2 aA1,aA2,aA3,aA4,aA5
    xorand    \aA1, a2, a3, a4, t6
    xoror     \aA2, a3, a4, a5, t6
    xornotor  \aA3, a4, a5, a6, t6
    notxorand \aA4, a5, a6, a2, t6, t1
    xoror     \aA5, a6, a2, a3, t6
.endm

.macro chipattern3 aA1,aA2,aA3,aA4,aA5
    xornotand \aA1, a2, a3, a4, t6
    notxoror  \aA2, a3, a4, a5, t6, t1
    xorand    \aA3, a4, a5, a6, t6
    xoror     \aA4, a5, a6, a2, t6
    xorand    \aA5, a6, a2, a3, t6
.endm

.macro chiiota aA1,aA2,aA3,aA4,aA5,offset
    xornotor  \aA2, a3, a4, a5, t6
    xorand    \aA3, a4, a5, a6, t6
    xoror     \aA4, a5, a6, a2, t6
    xorand    \aA5, a6, a2, a3, t6
    or      a4, a4, a3
    lw      t6, \offset(a1)
    xor     a2, a2, a4
    xor     a2, a2, t6
    sw      a2, \aA1(a0)
.endm

.macro round0
    xor5        a2, Abu0, Agu0, Aku0, Amu0, Asu0, t6
    xor5        a6, Abe1, Age1, Ake1, Ame1, Ase1, t6
    xorrol      s0, a2, a6, t6
    xor5        a5, Abu1, Agu1, Aku1, Amu1, Asu1, t6
    xor5        t5, Abe0, Age0, Ake0, Ame0, Ase0, t6
    xor         t0, a5, t5

    xor5        a4, Abi0, Agi0, Aki0, Ami0, Asi0, t6
    xorrol      s4, a4, a5, t6
    xor5        a3, Abi1, Agi1, Aki1, Ami1, Asi1, t6
    xor         s1, a2, a3

    xor5        a2, Aba0, Aga0, Aka0, Ama0, Asa0, t6
    xorrol      t2, a2, a3, t6
    xor5        a5, Aba1, Aga1, Aka1, Ama1, Asa1, t6
    xor         t3, a5, a4

    xor5        a3, Abo1, Ago1, Ako1, Amo1, Aso1, t6
    xorrol      a7, t5, a3, t6
    xor5        a4, Abo0, Ago0, Ako0, Amo0, Aso0, t6
    xor         s2, a6, a4

    xorrol      t4, a4, a5, t6
    xor         t5, a3, a2

//used for masks: r2,r8,r9,r10,r11,r12,lr,mDa0,mDo1,mDi0,mDa1,mDo0
//           = >  a7,t0,t1, t2, t3, t4,t5,  s0,  s1,  s2,  s3,  s4
    thetarhopi  a4, Aka1, t0,  2, a5, Ame1, t3, 23, a6, Asi1, s2, 31, a2, Abo0, s4, 14, a3, Agu0, t4, 10
    chipattern0     Aka1,             Ame1,             Asi1,             Abo0,             Agu0
    thetarhopi  a6, Asa1, t0,  9, a2, Abe0, t2,  0, a3, Agi1, s2,  3, a4, Ako0, s4, 12, a5, Amu1, t5,  4
    chipattern1     Asa1,             Abe0,             Agi1,             Ako0,             Amu1
    thetarhopi  a3, Aga0, s0, 18, a4, Ake0, t2,  5, a5, Ami1, s2,  8, a6, Aso0, s4, 28, a2, Abu1, t5, 14
    chipattern2     Aga0,             Ake0,             Ami1,             Aso0,             Abu1
    thetarhopi  a5, Ama0, s0, 20, a6, Ase1, t3,  1, a2, Abi1, s2, 31, a3, Ago0, s4, 27, a4, Aku0, t4, 19
    chipattern3     Ama0,             Ase1,             Abi1,             Ago0,             Aku0
    thetarhopifinal Aba0, s0,         Age0, t2, 22,     Aki1, s2, 22,     Amo1, s1, 11,     Asu0, t4,  7
    chiiota         Aba0,             Age0,             Aki1,             Amo1,             Asu0, 0

    thetarhopi  a4, Aka0, s0,  1, a5, Ame0, t2, 22, a6, Asi0, a7, 30, a2, Abo1, s1, 14, a3, Agu1, t5, 10
    chipattern0     Aka0,             Ame0,             Asi0,             Abo1,             Agu1
    thetarhopi  a6, Asa0, s0,  9, a2, Abe1, t3,  1, a3, Agi0, a7,  3, a4, Ako1, s1, 13, a5, Amu0, t4,  4
    chipattern1     Asa0,             Abe1,             Agi0,             Ako1,             Amu0
    thetarhopi  a3, Aga1, t0, 18, a4, Ake1, t3,  5, a5, Ami0, a7,  7, a6, Aso1, s1, 28, a2, Abu0, t4, 13
    chipattern2     Aga1,             Ake1,             Ami0,             Aso1,             Abu0
    thetarhopi  a5, Ama1, t0, 21, a6, Ase0, t2,  1, a2, Abi0, a7, 31, a3, Ago1, s1, 28, a4, Aku1, t5, 20
    chipattern3     Ama1,             Ase0,             Abi0,             Ago1,             Aku1
    thetarhopifinal Aba1, t0,         Age1, t3, 22,     Aki0, a7, 21,     Amo0, s4, 10,     Asu1, t5,  7
    chiiota         Aba1,             Age1,             Aki0,             Amo0,             Asu1, 4
.endm

.macro round1
    xor5        a2, Asu0, Agu0, Amu0, Abu1, Aku1, t6
    xor5        a6, Age1, Ame0, Abe0, Ake1, Ase1, t6
    xorrol      s0, a2, a6, t6
    xor5        a5, Asu1, Agu1, Amu1, Abu0, Aku0, t6
    xor5        t5, Age0, Ame1, Abe1, Ake0, Ase0, t6
    xor         t0, a5, t5

    xor5        a4, Aki1, Asi1, Agi0, Ami1, Abi0, t6
    xorrol      s4, a4, a5, t6
    xor5        a3, Aki0, Asi0, Agi1, Ami0, Abi1, t6
    xor         s1, a2, a3

    xor5        a2, Aba0, Aka1, Asa0, Aga0, Ama1, t6
    xorrol      t2, a2, a3, t6
    xor5        a5, Aba1, Aka0, Asa1, Aga1, Ama0, t6
    xor         t3, a5, a4

    xor5        a3, Amo0, Abo1, Ako0, Aso1, Ago0, t6
    xorrol      a7, t5, a3, t6
    xor5        a4, Amo1, Abo0, Ako1, Aso0, Ago1, t6
    xor         s2, a6, a4

    xorrol      t4, a4, a5, t6
    xor         t5, a3, a2

//used for masks: r2,r8,r9,r10,r11,r12,lr,mDa0,mDo1,mDi0,mDa1,mDo0
//           = >  a7,t0,t1, t2, t3, t4,t5,  s0,  s1,  s2,  s3,  s4
    thetarhopi  a4, Asa1, t0,  2, a5, Ake1, t3, 23, a6, Abi1, s2, 31, a2, Amo1, s4, 14, a3, Agu0, t4, 10
    chipattern0     Asa1,             Ake1,             Abi1,             Amo1,             Agu0
    thetarhopi  a6, Ama0, t0,  9, a2, Age0, t2,  0, a3, Asi0, s2,  3, a4, Ako1, s4, 12, a5, Abu0, t5,  4
    chipattern1     Ama0,             Age0,             Asi0,             Ako1,             Abu0
    thetarhopi  a3, Aka1, s0, 18, a4, Abe1, t2,  5, a5, Ami0, s2,  8, a6, Ago1, s4, 28, a2, Asu1, t5, 14
    chipattern2     Aka1,             Abe1,             Ami0,             Ago1,             Asu1
    thetarhopi  a5, Aga0, s0, 20, a6, Ase1, t3,  1, a2, Aki0, s2, 31, a3, Abo0, s4, 27, a4, Amu0, t4, 19
    chipattern3     Aga0,             Ase1,             Aki0,             Abo0,             Amu0
    thetarhopifinal Aba0, s0,         Ame1, t2, 22,     Agi1, s2, 22,     Aso1, s1, 11,     Aku1, t4,  7
    chiiota         Aba0,             Ame1,             Agi1,             Aso1,             Aku1, 8

    thetarhopi  a4, Asa0, s0,  1, a5, Ake0, t2, 22, a6, Abi0, a7, 30, a2, Amo0, s1, 14, a3, Agu1, t5, 10
    chipattern0     Asa0,             Ake0,             Abi0,             Amo0,             Agu1
    thetarhopi  a6, Ama1, s0,  9, a2, Age1, t3,  1, a3, Asi1, a7,  3, a4, Ako0, s1, 13, a5, Abu1, t4,  4
    chipattern1     Ama1,             Age1,             Asi1,             Ako0,             Abu1
    thetarhopi  a3, Aka0, t0, 18, a4, Abe0, t3,  5, a5, Ami1, a7,  7, a6, Ago0, s1, 28, a2, Asu0, t4, 13
    chipattern2     Aka0,             Abe0,             Ami1,             Ago0,             Asu0
    thetarhopi  a5, Aga1, t0, 21, a6, Ase0, t2,  1, a2, Aki1, a7, 31, a3, Abo1, s1, 28, a4, Amu1, t5, 20
    chipattern3     Aga1,             Ase0,             Aki1,             Abo1,             Amu1
    thetarhopifinal Aba1, t0,         Ame0, t3, 22,     Agi0, a7, 21,     Aso0, s4, 10,     Aku0, t5,  7
    chiiota         Aba1,             Ame0,             Agi0,             Aso0,             Aku0, 12
.endm

.macro round2
    xor5        a2, Aku1, Agu0, Abu1, Asu1, Amu1, t6
    xor5        a6, Ame0, Ake0, Age0, Abe0, Ase1, t6
    xorrol      s0, a2, a6, t6
    xor5        a5, Aku0, Agu1, Abu0, Asu0, Amu0, t6
    xor5        t5, Ame1, Ake1, Age1, Abe1, Ase0, t6
    xor         t0, a5, t5

    xor5        a4, Agi1, Abi1, Asi1, Ami0, Aki1, t6
    xorrol      s4, a4, a5, t6
    xor5        a3, Agi0, Abi0, Asi0, Ami1, Aki0, t6
    xor         s1, a2, a3

    xor5        a2, Aba0, Asa1, Ama1, Aka1, Aga1, t6
    xorrol      t2, a2, a3, t6
    xor5        a5, Aba1, Asa0, Ama0, Aka0, Aga0, t6
    xor         t3, a5, a4

    xor5        a3, Aso0, Amo0, Ako1, Ago0, Abo0, t6
    xorrol      a7, t5, a3, t6
    xor5        a4, Aso1, Amo1, Ako0, Ago1, Abo1, t6
    xor         s2, a6, a4

    xorrol      t4, a4, a5, t6
    xor         t5, a3, a2

//used for masks: r2,r8,r9,r10,r11,r12,lr,mDa0,mDo1,mDi0,mDa1,mDo0
//           = >  a7,t0,t1, t2, t3, t4,t5,  s0,  s1,  s2,  s3,  s4
    thetarhopi  a4, Ama0, t0,  2, a5, Abe0, t3, 23, a6, Aki0, s2, 31, a2, Aso1, s4, 14, a3, Agu0, t4, 10
    chipattern0     Ama0,             Abe0,             Aki0,             Aso1,             Agu0
    thetarhopi  a6, Aga0, t0,  9, a2, Ame1, t2,  0, a3, Abi0, s2,  3, a4, Ako0, s4, 12, a5, Asu0, t5,  4
    chipattern1     Aga0,             Ame1,             Abi0,             Ako0,             Asu0
    thetarhopi  a3, Asa1, s0, 18, a4, Age1, t2,  5, a5, Ami1, s2,  8, a6, Abo1, s4, 28, a2, Aku0, t5, 14
    chipattern2     Asa1,             Age1,             Ami1,             Abo1,             Aku0
    thetarhopi  a5, Aka1, s0, 20, a6, Ase1, t3,  1, a2, Agi0, s2, 31, a3, Amo1, s4, 27, a4, Abu1, t4, 19
    chipattern3     Aka1,             Ase1,             Agi0,             Amo1,             Abu1
    thetarhopifinal Aba0, s0,         Ake1, t2, 22,     Asi0, s2, 22,     Ago0, s1, 11,     Amu1, t4,  7
    chiiota         Aba0,             Ake1,             Asi0,             Ago0,             Amu1, 16

    thetarhopi  a4, Ama1, s0,  1, a5, Abe1, t2, 22, a6, Aki1, a7, 30, a2, Aso0, s1, 14, a3, Agu1, t5, 10
    chipattern0     Ama1,             Abe1,             Aki1,             Aso0,             Agu1
    thetarhopi  a6, Aga1, s0,  9, a2, Ame0, t3,  1, a3, Abi1, a7,  3, a4, Ako1, s1, 13, a5, Asu1, t4,  4
    chipattern1     Aga1,             Ame0,             Abi1,             Ako1,             Asu1
    thetarhopi  a3, Asa0, t0, 18, a4, Age0, t3,  5, a5, Ami0, a7,  7, a6, Abo0, s1, 28, a2, Aku1, t4, 13
    chipattern2     Asa0,             Age0,             Ami0,             Abo0,             Aku1
    thetarhopi  a5, Aka0, t0, 21, a6, Ase0, t2,  1, a2, Agi1, a7, 31, a3, Amo0, s1, 28, a4, Abu0, t5, 20
    chipattern3     Aka0,             Ase0,             Agi1,             Amo0,             Abu0
    thetarhopifinal Aba1, t0,         Ake0, t3, 22,     Asi1, a7, 21,     Ago1, s4, 10,     Amu0, t5,  7
    chiiota         Aba1,             Ake0,             Asi1,             Ago1,             Amu0, 20
.endm

.macro round3
    xor5        a2, Amu1, Agu0, Asu1, Aku0, Abu0, t6
    xor5        a6, Ake0, Abe1, Ame1, Age0, Ase1, t6
    xorrol      s0, a2, a6, t6
    xor5        a5, Amu0, Agu1, Asu0, Aku1, Abu1, t6
    xor5        t5, Ake1, Abe0, Ame0, Age1, Ase0 t6
    xor         t0, a5, t5

    xor5        a4, Asi0, Aki0, Abi1, Ami1, Agi1, t6
    xorrol      s4, a4, a5, t6
    xor5        a3, Asi1, Aki1, Abi0, Ami0, Agi0, t6
    xor         s1, a2, a3

    xor5        a2, Aba0, Ama0, Aga1, Asa1, Aka0, t6
    xorrol      t2, a2, a3, t6
    xor5        a5, Aba1, Ama1, Aga0, Asa0, Aka1, t6
    xor         t3, a5, a4

    xor5        a3, Ago1, Aso0, Ako0, Abo0, Amo1, t6
    xorrol      a7, t5, a3, t6
    xor5        a4, Ago0, Aso1, Ako1, Abo1, Amo0, t6
    xor         s2, a6, a4

    xorrol      t4, a4, a5, t6
    xor         t5, a3, a2

//used for masks: r2,r8,r9,r10,r11,r12,lr,mDa0,mDo1,mDi0,mDa1,mDo0
//           = >  a7,t0,t1, t2, t3, t4,t5,  s0,  s1,  s2,  s3,  s4
    thetarhopi  a4, Aga0, t0,  2, a5, Age0, t3, 23, a6, Agi0, s2, 31, a2, Ago0, s4, 14, a3, Agu0, t4, 10
    chipattern0     Aga0,             Age0,             Agi0,             Ago0,             Agu0
    thetarhopi  a6, Aka1, t0,  9, a2, Ake1, t2,  0, a3, Aki1, s2,  3, a4, Ako1, s4, 12, a5, Aku1, t5,  4
    chipattern1     Aka1,             Ake1,             Aki1,             Ako1,             Aku1
    thetarhopi  a3, Ama0, s0, 18, a4, Ame0, t2,  5, a5, Ami0, s2,  8, a6, Amo0, s4, 28, a2, Amu0, t5, 14
    chipattern2     Ama0,             Ame0,             Ami0,             Amo0,             Amu0
    thetarhopi  a5, Asa1, s0, 20, a6, Ase1, t3,  1, a2, Asi1, s2, 31, a3, Aso1, s4, 27, a4, Asu1, t4, 19
    chipattern3     Asa1,             Ase1,             Asi1,             Aso1,             Asu1
    thetarhopifinal Aba0, s0,         Abe0, t2, 22,     Abi0, s2, 22,     Abo0, s1, 11,     Abu0, t4,  7
    chiiota         Aba0,             Abe0,             Abi0,             Abo0,             Abu0, 24

    thetarhopi  a4, Aga1, s0,  1, a5, Age1, t2, 22, a6, Agi1, a7, 30, a2, Ago1, s1, 14, a3, Agu1, t5, 10
    chipattern0     Aga1,             Age1,             Agi1,             Ago1,             Agu1
    thetarhopi  a6, Aka0, s0,  9, a2, Ake0, t3,  1, a3, Aki0, a7,  3, a4, Ako0, s1, 13, a5, Aku0, t4,  4
    chipattern1     Aka0,             Ake0,             Aki0,             Ako0,             Aku0
    thetarhopi  a3, Ama1, t0, 18, a4, Ame1, t3,  5, a5, Ami1, a7,  7, a6, Amo1, s1, 28, a2, Amu1, t4, 13
    chipattern2     Ama1,             Ame1,             Ami1,             Amo1,             Amu1
    thetarhopi  a5, Asa0, t0, 21, a6, Ase0, t2,  1, a2, Asi0, a7, 31, a3, Aso0, s1, 28, a4, Asu0, t5, 20
    chipattern3     Asa0,             Ase0,             Asi0,             Aso0,             Asu0
    thetarhopifinal Aba1, t0,         Abe1, t3, 22,     Abi1, a7, 21,     Abo1, s4, 10,     Abu1, t5,  7
    chiiota         Aba1,             Abe1,             Abi1,             Abo1,             Abu1, 28
.endm

.macro invert dst
    lw      t6, \dst(a0)
    not     t6, t6
    sw      t6, \dst(a0)
.endm

.macro complementlanes
    invert Abe0
    invert Abe1
    invert Abi0
    invert Abi1
    invert Ago0
    invert Ago1
    invert Aki0
    invert Aki1
    invert Ami0
    invert Ami1
    invert Asa0
    invert Asa1
.endm

.data

.align 3
keccakf1600_rc24:
    .long 0x00000001, 0x00000000
    .long 0x00000000, 0x00000089
    .long 0x00000000, 0x8000008b
    .long 0x00000000, 0x80008080
    .long 0x00000001, 0x0000008b
    .long 0x00000001, 0x00008000
    .long 0x00000001, 0x80008088
    .long 0x00000001, 0x80000082
    .long 0x00000000, 0x0000000b
    .long 0x00000000, 0x0000000a
    .long 0x00000001, 0x00008082
    .long 0x00000000, 0x00008003
    .long 0x00000001, 0x0000808b
    .long 0x00000001, 0x8000000b
    .long 0x00000001, 0x8000008a
    .long 0x00000001, 0x80000081
    .long 0x00000000, 0x80000081
    .long 0x00000000, 0x80000008
    .long 0x00000000, 0x00000083
    .long 0x00000000, 0x80008003
    .long 0x00000001, 0x80008088
    .long 0x00000000, 0x80000088
    .long 0x00000001, 0x00008000
    .long 0x00000000, 0x80008082

.text

// void keccakf1600(uint32_t *lanes);
.globl keccakf1600
.type keccakf1600,%function
.align 3
keccakf1600:
    addi    sp, sp, -24
    sw      s0,  4(sp)
    sw      s1,  8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    sw      s4, 20(sp)

    la      a1, keccakf1600_rc24
    addi    s3, zero, 5

    complementlanes

// With this loop it still fits in 16 KiB instruction cache
.align 3
1:  round0
    round1
    round2
    round3
    addi    a1, a1, 32
    addi    s3, s3, -1
    bge     s3, zero, 1b

    complementlanes

    lw      s0,  4(sp)
    lw      s1,  8(sp)
    lw      s2, 12(sp)
    lw      s3, 16(sp)
    lw      s4, 20(sp)
    addi    sp, sp, 24

    ret
.size keccakf1600,.-keccakf1600
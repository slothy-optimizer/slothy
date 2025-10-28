start:
// Base instruction
addi x1, x1, 1

// Arithmetic with immediates
bn.addi w0, w1, 17
bn.addi w3, w4, 100, FG0
bn.subi w5, w6, 50
bn.subi w7, w8, 75, FG1

// Basic arithmetic
bn.add w0, w1, w2
bn.add w3, w4, w5 << 8
bn.add w6, w7, w8 >> 16, FG0
bn.add w9, w10, w11 << 32, FG1

bn.addc w12, w13, w14
bn.addc w15, w16, w17 << 4, FG0

// Test MOD register dependency
bn.wsrw MOD, w31
bn.addm w18, w19, w20

bn.sub w0, w1, w2
bn.sub w3, w4, w5 >> 8
bn.sub w6, w7, w8, FG1

bn.subb w9, w10, w11
bn.subb w12, w13, w14 << 16, FG0

bn.subm w15, w16, w17

// Logical operations
bn.and w0, w1, w2
bn.and w3, w4, w5 << 8, FG0

bn.or w6, w7, w8
bn.or w9, w10, w11 >> 4

bn.not w12, w13
bn.not w14, w15 << 8

bn.xor w0, w1, w2
bn.xor w3, w4, w5 >> 16, FG1

// Shift
bn.rshi w0, w1, w2 >> 37

// Comparison
bn.cmp w0, w1
bn.cmp w2, w3 << 8
bn.cmp w4, w5, FG0
bn.cmpb w6, w7
bn.cmpb w8, w9 >> 4, FG1

// Move operations
bn.mov w0, w1
bn.movr x2, x3

// Conditional select
bn.sel w0, w1, w2, FG0.C
bn.sel w3, w4, w5, C

// Memory operations
bn.lid x10, 0(x11)
bn.sid x14, 0(x15)

// Special register access
bn.wsrr w0, URND
bn.wsrr w1, RND
bn.wsrr w2, ACC
bn.wsrr w3, MOD

bn.wsrw MOD, w4
bn.wsrw RND, w5
bn.wsrw ACC, w0
bn.wsrw URND, w6

// Multiply-accumulate
bn.mulqacc w1.0, w2.1, 0, FG0
bn.mulqacc.z w3.2, w4.3, 1, FG1
bn.mulqacc.so w5, w6.0, w7.1, 2, FG0
bn.mulqacc.wo w0, w1.0, w2.1, 3, FG1
bn.mulqacc.wo.z w8, w9.2, w10.3, 0, FG0
end:
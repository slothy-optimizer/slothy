/// Copyright (c) 2026 Amin Abdulrahman (amin@abdulrahman.de)
/// Copyright (c) 2026 Justus Bergermann (mail@justus-bergermann.de)
///
/// SPDX-License-Identifier: MIT
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

start:

// TODO: this is currently incomplete. We should add all instructions

// I extension - Register-Immediate ALU operations
addi x2, x1, 64
addiw x2, x1, 32
slti x3, x2, 100
sltiu x4, x3, 200
andi x5, x4, 0xff
ori x6, x5, 0x0f
xori x7, x6, 0xaa
slli x8, x7, 4
slliw x8, x7, 2
srli x9, x8, 2
srliw x9, x8, 1
srai x10, x9, 1
sraiw x10, x9, 2

// I extension - Register-Register ALU operations
and x11, x10, x9
or x12, x11, x10
xor x13, x12, x11
add x14, x13, x12
addw x14, x13, x12
slt x15, x14, x13
sltu x16, x15, x14
sll x17, x16, x15
sllw x17, x16, x15
srl x18, x17, x16
srlw x18, x17, x16
sub x19, x18, x17
subw x19, x18, x17
sra x20, x19, x18
sraw x20, x19, x18

// I extension - Load instructions
lb x21, 0(x1)
lbu x22, 4(x1)
lh x23, 8(x1)
lhu x24, 12(x1)
lw x25, 16(x1)
lwu x26, 20(x1)
ld x27, 24(x1)

// I extension - Store instructions
sb x21, 0(x1)
sh x22, 4(x1)
sw x23, 8(x1)
sd x24, 12(x1)

// I extension - Upper immediate
lui x28, 0x12345
auipc x29, 0xabcd

// I extension - Branch instructions (commented out - branches not supported in non-loop mode)
// beq x1, x2, .Lend
// bne x3, x4, .Lend
// blt x5, x6, .Lend
// bge x7, x8, .Lend
// bltu x9, x10, .Lend
// bgeu x11, x12, .Lend
// beqz x13, .Lend
// bnez x14, .Lend

// M extension - Multiplication and Division
mul x2, x1, x3
mulw x2, x1, x3
mulh x4, x3, x2
mulhsu x5, x4, x3
mulhu x6, x5, x4
div x7, x6, x5
divw x7, x6, x5
divu x8, x7, x6
divuw x8, x7, x6
rem x9, x8, x7
remw x9, x8, x7
remu x10, x9, x8
remuw x10, x9, x8

// Zbkb extension - Bit manipulation for cryptography
rol x11, x10, x9
ror x12, x11, x10
rori x13, x12, 5
andn x14, x13, x12
orn x15, x14, x13
xnor x16, x15, x14
pack x17, x16, x15
packh x18, x17, x16
rev8 x19, x18
zip x20, x19
unzip x21, x20

// Pseudo-instructions
li x22, 0x1234
mv x23, x22
neg x24, x23
not x25, x24

end:

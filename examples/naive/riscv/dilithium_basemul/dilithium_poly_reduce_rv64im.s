/// Copyright (c) 2024 Jipeng Zhang (jp-zhang@outlook.com) (Original Code)
/// Copyright (c) 2026 Amin Abdulrahman (amin@abdulrahman.de) (Modifications)
/// Copyright (c) 2026 Justus Bergermann (mail@justus-bergermann.de) (Modifications)
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

.equ q,    8380417
.equ q32,  0x7fe00100000000               // q << 32
.equ qinv, 0x180a406003802001             // q^-1 mod 2^64
.equ plantconst, 0x200801c0602            // (((-2**64) % q) * qinv) % (2**64)
.equ plantconst2, 0xb7b9f10ccf939804      // (((-2**64) % q) * ((-2**64) % q) * qinv) % (2**64)

# void poly_reduce_rv64im(int32_t in[256]);
.globl poly_reduce_rv64im
.align 2
poly_reduce_rv64im:
    li a1, 4194304  # 1<<22
    li a2, q
    addi a3, a0, 64*4*4
poly_reduce_rv64im_loop:
    lw a4, 0*4(a0)
    lw a5, 1*4(a0)
    lw a6, 2*4(a0)
    lw a7, 3*4(a0)
    add  t0, a4, a1
    add  t1, a5, a1
    add  t2, a6, a1
    add  t3, a7, a1
    srai t0, t0, 23
    srai t1, t1, 23
    srai t2, t2, 23
    srai t3, t3, 23
    mul  t0, t0, a2
    mul  t1, t1, a2
    mul  t2, t2, a2
    mul  t3, t3, a2
    sub  a4, a4, t0
    sub  a5, a5, t1
    sub  a6, a6, t2
    sub  a7, a7, t3
    sw a4, 0*4(a0)
    sw a5, 1*4(a0)
    sw a6, 2*4(a0)
    sw a7, 3*4(a0)
    addi a0, a0, 4*4
    bne a0, a3, poly_reduce_rv64im_loop
    ret
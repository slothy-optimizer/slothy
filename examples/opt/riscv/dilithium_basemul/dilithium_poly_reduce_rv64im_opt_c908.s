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

.macro save_regs
  addi sp, sp, -8*15
  sd s0,  0*8(sp)
  sd s1,  1*8(sp)
  sd s2,  2*8(sp)
  sd s3,  3*8(sp)
  sd s4,  4*8(sp)
  sd s5,  5*8(sp)
  sd s6,  6*8(sp)
  sd s7,  7*8(sp)
  sd s8,  8*8(sp)
  sd s9,  9*8(sp)
  sd s10, 10*8(sp)
  sd s11, 11*8(sp)
  sd gp,  12*8(sp)
  sd tp,  13*8(sp)
  sd ra,  14*8(sp)
.endm

.macro restore_regs
  ld s0,  0*8(sp)
  ld s1,  1*8(sp)
  ld s2,  2*8(sp)
  ld s3,  3*8(sp)
  ld s4,  4*8(sp)
  ld s5,  5*8(sp)
  ld s6,  6*8(sp)
  ld s7,  7*8(sp)
  ld s8,  8*8(sp)
  ld s9,  9*8(sp)
  ld s10, 10*8(sp)
  ld s11, 11*8(sp)
  ld gp,  12*8(sp)
  ld tp,  13*8(sp)
  ld ra,  14*8(sp)
  addi sp, sp, 8*15
.endm

# void poly_reduce_rv64im(int32_t in[256]);
.globl poly_reduce_rv64im_opt_c908
.align 2
poly_reduce_rv64im_opt_c908:
    save_regs
    li a1, 4194304  # 1<<22
    li a2, q
    addi a3, a0, 64*4*4
poly_reduce_rv64im_loop:
                                 // Instructions:    24
                                 // Expected cycles: 17
                                 // Expected IPC:    1.41
                                 //
                                 // Cycle bound:     17.0
                                 // IPC bound:       1.41
                                 //
                                 // Wall time:     0.11s
                                 // User time:     0.11s
                                 //
                                 // ----- cycle (expected) ------>
                                 // 0                        25
                                 // |------------------------|----
        lw x15, 0*4(x10)         // *............................. // @slothy:reads=mem0
        lw x6, 3*4(x10)          // .*............................ // @slothy:reads=mem3
        lw x7, 1*4(x10)          // ..*........................... // @slothy:reads=mem1
        lw x23, 2*4(x10)         // ...*.......................... // @slothy:reads=mem2
        add x30, x15, x11        // ...*..........................
        srai x8, x30, 23         // ....*.........................
        add x16, x6, x11         // ....*.........................
        mul x30, x8, x12         // .....*........................
        srai x16, x16, 23        // .....*........................
        add x5, x7, x11          // ......*.......................
        add x17, x23, x11        // ......*.......................
        mul x16, x16, x12        // .......*......................
        srai x24, x5, 23         // .......*......................
        srai x22, x17, 23        // ........*.....................
        sub x15, x15, x30        // .........*....................
        mul x4, x24, x12         // .........*....................
        sw x15, 0*4(x10)         // ..........*................... // @slothy:writes=mem0
        sub x30, x6, x16         // ...........*..................
        mul x28, x22, x12        // ...........*..................
        sw x30, 3*4(x10)         // ............*................. // @slothy:writes=mem3
        sub x27, x7, x4          // .............*................
        sw x27, 1*4(x10)         // ..............*............... // @slothy:writes=mem1
        sub x24, x23, x28        // ...............*..............
        sw x24, 2*4(x10)         // ................*............. // @slothy:writes=mem2

                                   // ------ cycle (expected) ------>
                                   // 0                        25
                                   // |------------------------|-----
        // lw x14, 0*4(x10)        // *..............................
        // lw x15, 1*4(x10)        // ..*............................
        // lw x16, 2*4(x10)        // ...*...........................
        // lw x17, 3*4(x10)        // .*.............................
        // add  x5, x14, x11       // ...*...........................
        // add  x6, x15, x11       // ......*........................
        // add  x7, x16, x11       // ......*........................
        // add  x28, x17, x11      // ....*..........................
        // srai x5, x5, 23         // ....*..........................
        // srai x6, x6, 23         // .......*.......................
        // srai x7, x7, 23         // ........*......................
        // srai x28, x28, 23       // .....*.........................
        // mul  x5, x5, x12        // .....*.........................
        // mul  x6, x6, x12        // .........*.....................
        // mul  x7, x7, x12        // ...........*...................
        // mul  x28, x28, x12      // .......*.......................
        // sub  x14, x14, x5       // .........*.....................
        // sub  x15, x15, x6       // .............*.................
        // sub  x16, x16, x7       // ...............*...............
        // sub  x17, x17, x28      // ...........*...................
        // sw x14, 0*4(x10)        // ..........*....................
        // sw x15, 1*4(x10)        // ..............*................
        // sw x16, 2*4(x10)        // ................*..............
        // sw x17, 3*4(x10)        // ............*..................

        addi a0, a0, 16
        bne a0, a3, poly_reduce_rv64im_loop
    restore_regs
    ret
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

addi gp, zero, 12
my_loop:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -1
  bge gp, zero, my_loop

addi gp, zero, 3
my_loop2:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -1
  bne gp, zero, my_loop2

addi gp, zero, 32
my_loop3:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -4
  bne gp, zero, my_loop3
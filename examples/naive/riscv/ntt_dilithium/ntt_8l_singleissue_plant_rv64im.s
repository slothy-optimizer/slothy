// 
// Code from https://github.com/Ji-Peng/PQRV/blob/2463d15ba6c49d05d45ff427b72646e038c860da/ntt/dilithium/ntt_8l_singleissue_plant_rv64im.S
// 
// The MIT license, the text of which is below, applies to PQRV in general.
// We have reused public-domain code from the following repositories: https://github.com/pq-crystals/kyber and https://github.com/pq-crystals/dilithium.
// 
// Copyright (c) 2024 Jipeng Zhang (jp-zhang@outlook.com)
// SPDX-License-Identifier: MIT
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 

.include "ntt_8l_singleissue_plant_rv64im_helper.s"



// |input| < 0.5q; |output| < 4q
// API: a0: poly, a1: 64-bit twiddle ptr; a6: q<<32; a7: tmp, variable twiddle factors; gp: loop;
// s0-s11, a2-a5: 16 coeffs; 
// 16+2+1+1=20 regs; 
// 9 twiddle factors: can be preloaded; t0-t6, tp, ra.
.global ntt_8l_rv64im
.align 2
ntt_8l_rv64im:
  addi sp, sp, -8*15
  save_regs
  li a6, q32          // q<<32
  addi a0, a0, 16*4   // poly[16]
  addi gp, x0, 15     // loop
  ld t0, 0*8(a1)
  ld t1, 1*8(a1)
  ld t2, 2*8(a1)
  ld t3, 3*8(a1)
  ld t4, 4*8(a1)
  ld t5, 5*8(a1)
  ld t6, 6*8(a1)
  ld tp, 7*8(a1)
  ld ra, 8*8(a1)
  //// LAYER 1+2+3+4
  ntt_8l_rv64im_loop1:
    addi a0, a0, -4
    load_coeffs a0, 16, 4
    // layer 1
    main_loop:
    ct_bfu s0, s8,  t0, a6, a7
    ct_bfu s1, s9,  t0, a6, a7
    ct_bfu s2, s10, t0, a6, a7
    ct_bfu s3, s11, t0, a6, a7
    ct_bfu s4, a2,  t0, a6, a7
    ct_bfu s5, a3,  t0, a6, a7
    ct_bfu s6, a4,  t0, a6, a7
    ct_bfu s7, a5,  t0, a6, a7

    // layer 2
    ct_bfu s0,  s4, t1, a6, a7
    ct_bfu s1,  s5, t1, a6, a7
    ct_bfu s2,  s6, t1, a6, a7
    ct_bfu s3,  s7, t1, a6, a7
    ct_bfu s8,  a2, t2, a6, a7
    ct_bfu s9,  a3, t2, a6, a7
    ct_bfu s10, a4, t2, a6, a7
    ct_bfu s11, a5, t2, a6, a7

    // layer 3
    ct_bfu s0, s2,  t3, a6, a7
    ct_bfu s1, s3,  t3, a6, a7
    ct_bfu s4, s6,  t4, a6, a7
    ct_bfu s5, s7,  t4, a6, a7
    ct_bfu s8, s10, t5, a6, a7
    ct_bfu s9, s11, t5, a6, a7
    ct_bfu a2, a4,  t6, a6, a7
    ct_bfu a3, a5,  t6, a6, a7

    // layer 4
    ct_bfu s0,  s1,  tp, a6, a7
    ct_bfu s2,  s3,  ra, a6, a7 
    ld a7, 9*8(a1)
    end_label:
    ct_bfu s4,  s5,  a7, a6, a7
    ld a7, 10*8(a1)


    ct_bfu s6,  s7,  a7, a6, a7
    ld a7, 11*8(a1)
    ct_bfu s8,  s9,  a7, a6, a7
    ld a7, 12*8(a1)
    ct_bfu s10, s11, a7, a6, a7
    ld a7, 13*8(a1)
    ct_bfu a2,  a3,  a7, a6, a7
    ld a7, 14*8(a1)
    ct_bfu a4,  a5,  a7, a6, a7

    store_coeffs a0, 16, 4
  addi gp, gp, -1
  bge gp, zero, ntt_8l_rv64im_loop1
  addi a1, a1, 15*8
  //// LAYER 5+6+7+8
  addi gp, x0, 16
  ntt_8l_rv64im_loop2:
    load_coeffs a0, 1, 4
    ld t0, 0*8(a1)
    ld t1, 1*8(a1)
    ld t2, 2*8(a1)
    ld t3, 3*8(a1)
    ld t4, 4*8(a1)
    ld t5, 5*8(a1)
    ld t6, 6*8(a1)
    ld tp, 7*8(a1)
    ld ra, 8*8(a1)
    // layer 5
    ct_bfu s0, s8,  t0, a6, a7
    ct_bfu s1, s9,  t0, a6, a7
    ct_bfu s2, s10, t0, a6, a7
    ct_bfu s3, s11, t0, a6, a7
    ct_bfu s4, a2,  t0, a6, a7
    ct_bfu s5, a3,  t0, a6, a7
    ct_bfu s6, a4,  t0, a6, a7
    ct_bfu s7, a5,  t0, a6, a7
    // layer 6
    ct_bfu s0,  s4, t1, a6, a7
    ct_bfu s1,  s5, t1, a6, a7
    ct_bfu s2,  s6, t1, a6, a7
    ct_bfu s3,  s7, t1, a6, a7
    ct_bfu s8,  a2, t2, a6, a7
    ct_bfu s9,  a3, t2, a6, a7
    ct_bfu s10, a4, t2, a6, a7
    ct_bfu s11, a5, t2, a6, a7
    // layer 7
    ct_bfu s0, s2,  t3, a6, a7
    ct_bfu s1, s3,  t3, a6, a7
    ct_bfu s4, s6,  t4, a6, a7
    ct_bfu s5, s7,  t4, a6, a7
    ct_bfu s8, s10, t5, a6, a7
    ct_bfu s9, s11, t5, a6, a7
    ct_bfu a2, a4,  t6, a6, a7
    ct_bfu a3, a5,  t6, a6, a7
    // layer 8
    ct_bfu s0,  s1,  tp, a6, a7
    ct_bfu s2,  s3,  ra, a6, a7 
    ld a7, 9*8(a1)
    ct_bfu s4,  s5,  a7, a6, a7
    ld a7, 10*8(a1)
    ct_bfu s6,  s7,  a7, a6, a7
    ld a7, 11*8(a1)
    ct_bfu s8,  s9,  a7, a6, a7
    ld a7, 12*8(a1)
    ct_bfu s10, s11, a7, a6, a7
    ld a7, 13*8(a1)
    ct_bfu a2,  a3,  a7, a6, a7
    ld a7, 14*8(a1)
    ct_bfu a4,  a5,  a7, a6, a7
    store_coeffs a0, 1, 4
    addi a0, a0, 16*4
    addi a1, a1, 15*8
  addi gp, gp, -1
  bne gp, zero, ntt_8l_rv64im_loop2
  restore_regs
  addi sp, sp, 8*15
  ret



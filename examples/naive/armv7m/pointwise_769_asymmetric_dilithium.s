/**
 * Copyright (c) 2023 Junhao Huang (jhhuang_nuaa@126.com)
 *
 * Licensed under the Apache License, Version 2.0(the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
.syntax unified
.cpu cortex-m4
.thumb

// q locate in the top half of the register
.macro plant_red q, qa, qinv, tmp
  mul \tmp, \tmp, \qinv     
  //tmp*qinv mod 2^2n/ 2^n; in high half
  smlatt \tmp, \tmp, \q, \qa
  // result in high half
.endm

#### r0: out; r1: a; r2: b; r3: bprime
  .align 2
.global small_asymmetric_mul_asm_769
.type small_asymmetric_mul_asm_769, %function
small_asymmetric_mul_asm_769:
    push.w {r4-r11, lr}

    movw r14, #24608 // qa
    movt r12, #769  // q
	movw r11, #64769
	movt r11, #58632 // qinv
    .equ width, 4
    add.w r10, r0, #256*2
    _asymmetric_mul_16_loop:
    ldr.w r7, [r1, #width]
    ldr.w r4, [r1], #2*width
    ldr.w r8, [r2, #width]
    ldr.w r5, [r2], #2*width
    ldr.w r9, [r3, #width]
    ldr.w r6, [r3], #2*width

    smuad r6, r4, r6
    plant_red r12, r14, r11, r6
    smuadx r5, r4, r5
    plant_red r12, r14, r11, r5

    pkhtb r5, r5, r6, asr #16
    str.w r5, [r0], #width

	smuad r6, r7, r9
    plant_red r12, r14, r11, r6
    smuadx r8, r7, r8
    plant_red r12, r14, r11, r8

    pkhtb r8, r8, r6, asr #16
    str.w r8, [r0], #width
    cmp.w r0, r10
    bne.w _asymmetric_mul_16_loop

    pop.w {r4-r11, pc}

.size small_asymmetric_mul_asm_769, .-small_asymmetric_mul_asm_769
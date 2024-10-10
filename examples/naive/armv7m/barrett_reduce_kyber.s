/******************************************************************************
* Integrating the improved Plantard arithmetic into Kyber.
*
* Efficient Plantard arithmetic enables a faster Kyber implementation with the 
* same stack usage.
*
* See the paper at https://eprint.iacr.org/2022/956.pdf for more details.
*
* @author   Junhao Huang, BNU-HKBU United International College, Zhuhai, China
*           jhhuang_nuaa@126.com
*
* @date     September 2022
******************************************************************************/

.macro doublebarrett a, tmp, tmp2, q, barrettconst
  smulbb \tmp, \a, \barrettconst
  smultb \tmp2, \a, \barrettconst
  asr \tmp, \tmp, #26
  asr \tmp2, \tmp2, #26
  smulbb \tmp, \tmp, \q
  smulbb \tmp2, \tmp2, \q
  pkhbt \tmp, \tmp, \tmp2, lsl #16
  usub16 \a, \a, \tmp
.endm

.syntax unified
.cpu cortex-m4
.thumb

.global asm_barrett_reduce
.type asm_barrett_reduce,%function
.align 2
asm_barrett_reduce:
	push    {r4-r11, r14}

	poly        .req r0
	poly0       .req r1
	poly1       .req r2
	poly2       .req r3
	poly3       .req r4
	poly4       .req r5
	poly5       .req r6
	poly6       .req r7
	poly7       .req r8
	loop        .req r9
	barrettconst .req r10
	q           .req r11
	tmp         .req r12
	tmp2        .req r14

	movw barrettconst, #20159
	movw q, #3329

	movw loop, #16
	1:
    asm_barrett_reduce_loop_start:
		ldm poly, {poly0-poly7}

		doublebarrett poly0, tmp, tmp2, q, barrettconst
		doublebarrett poly1, tmp, tmp2, q, barrettconst
		doublebarrett poly2, tmp, tmp2, q, barrettconst
		doublebarrett poly3, tmp, tmp2, q, barrettconst
		doublebarrett poly4, tmp, tmp2, q, barrettconst
		doublebarrett poly5, tmp, tmp2, q, barrettconst
		doublebarrett poly6, tmp, tmp2, q, barrettconst
		doublebarrett poly7, tmp, tmp2, q, barrettconst

		stm poly!, {poly0-poly7}

	subs.w loop, #1
    asm_barrett_reduce_loop_end:
	bne.w 1b

	.unreq poly        
	.unreq poly0       
	.unreq poly1       
	.unreq poly2       
	.unreq poly3       
	.unreq poly4       
	.unreq poly5       
	.unreq poly6       
	.unreq poly7       
	.unreq loop        
	.unreq barrettconst
	.unreq q           
	.unreq tmp         
	.unreq tmp2        

	pop     {r4-r11, pc}

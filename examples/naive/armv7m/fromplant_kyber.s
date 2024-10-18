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

.macro doubleplant a, tmp, q, qa, plantconst
	smulwb \tmp, \plantconst, \a
	smulwt \a, \plantconst, \a
	smlabt \tmp, \tmp, \q, \qa
	smlabt \a, \a, \q, \qa
	pkhtb \a, \a, \tmp, asr #16
.endm

.syntax unified
.cpu cortex-m4
.thumb

.global asm_fromplant
.type asm_fromplant,%function
.align 2
asm_fromplant:
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
	plantconst  .req r10
	q           .req r11
	qa          .req r12
	tmp         .req r14
	
	movw qa, #26632
	movt q, #3329
	
	### movt qinv, #3327
	### plant_constant=(Plant_const^2%M)*(p^-1) % 2^32
	movw plantconst, #20396
	movt plantconst, #38900
	movw loop, #16
	1:
		ldm poly, {poly0-poly7}

		doubleplant poly0, tmp, q, qa, plantconst
		doubleplant poly1, tmp, q, qa, plantconst
		doubleplant poly2, tmp, q, qa, plantconst
		doubleplant poly3, tmp, q, qa, plantconst
		doubleplant poly4, tmp, q, qa, plantconst
		doubleplant poly5, tmp, q, qa, plantconst
		doubleplant poly6, tmp, q, qa, plantconst
		doubleplant poly7, tmp, q, qa, plantconst
	
		stm poly!, {poly0-poly7}

	subs.w loop, #1
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
	.unreq plantconst  
	.unreq q           
	.unreq qa          
	.unreq tmp         
	pop     {r4-r11, pc}

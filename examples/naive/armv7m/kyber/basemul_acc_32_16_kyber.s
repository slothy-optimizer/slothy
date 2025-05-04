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

// void basemul_asm_acc_opt_32_16(int16_t *, const int16_t *, const int16_t *, const int16_t *, const int32_t *)
.global basemul_asm_acc_opt_32_16
.type basemul_asm_acc_opt_32_16, %function
.align 2
basemul_asm_acc_opt_32_16:
  push {r4-r11, lr}

  rptr      .req r0
  aptr      .req r1
  bptr      .req r2
  aprimeptr .req r3
  poly0     .req r4
  poly1     .req r6
  res0      .req r5
  res1      .req r7
  q         .req r8
  qa        .req r9
  qinv      .req r10
  //tmp       .req r11
  tmp2      .req r12
  rptr_tmp  .req r11
  loop      .req r14

  movw qa, #26632
	movt  q, #3329
	### qinv=0x6ba8f301
	movw qinv, #62209
	movt qinv, #27560

  ldr rptr_tmp, [sp, #9*4]
  movw loop, #64
  1:
    ldr poly0, [aptr], #4
    ldr poly1, [bptr], #4
    ldr.w res0, [rptr_tmp], #4
    ldr tmp2, [aprimeptr], #4
    ldr.w res1, [rptr_tmp], #4

    // (poly0_t * zeta) * poly1_t + poly0_b * poly0_b + res
    smlad res0, tmp2, poly1, res0
    plant_red q, qa, qinv, res0

    // poly1_t * poly0_b + poly1_b * poly0_t + res
    smladx res1, poly0, poly1, res1
    plant_red q, qa, qinv, res1

    pkhtb res0, res1, res0, asr #16
    str res0, [rptr], #4

    ldr poly0, [aptr], #4
    ldr poly1, [bptr], #4
    ldr.w res0, [rptr_tmp], #4
    ldr tmp2, [aprimeptr], #4     
    ldr.w res1, [rptr_tmp], #4
    
    smlad res0, tmp2, poly1, res0
    plant_red q, qa, qinv, res0
    
    smladx res1, poly0, poly1, res1
    plant_red q, qa, qinv, res1

    pkhtb res0, res1, res0, asr #16
    str res0, [rptr], #4

    subs.w loop, loop, #1
  bne.w 1b

  pop {r4-r11, pc}

.size basemul_asm_acc_opt_32_16, .-basemul_asm_acc_opt_32_16
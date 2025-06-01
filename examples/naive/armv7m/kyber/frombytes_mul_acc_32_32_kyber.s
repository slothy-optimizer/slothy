.syntax unified
.cpu cortex-m4
.thumb

.macro doublebasemul_frombytes_asm_acc_32_32 rptr_tmp, bptr, zeta, poly0, poly1, poly3, res0, tmp, q, qa, qinv
  ldr \poly0, [\bptr], #8
  ldr \res0, [\rptr_tmp]

  smulwt \tmp, \zeta, \poly1
 smlabt \tmp, \tmp, \q, \qa
 smlatt \tmp, \poly0, \tmp, \res0
 smlabb \tmp, \poly0, \poly1, \tmp

  str \tmp, [\rptr_tmp], #16 // @slothy:core=True

  ldr \res0, [\rptr_tmp, #-12]
  smladx \tmp, \poly0, \poly1, \res0
  str \tmp, [\rptr_tmp, #-12]

  neg \zeta, \zeta

  ldr \poly0, [\bptr, #-4]
  ldr \res0, [\rptr_tmp, #-8]

  smulwt \tmp, \zeta, \poly3
 smlabt \tmp, \tmp, \q, \qa
 smlatt \tmp, \poly0, \tmp, \res0
 smlabb \tmp, \poly0, \poly3, \tmp

  str \tmp, [\rptr_tmp, #-8]

  ldr \res0, [\rptr_tmp, #-4]
  smladx \tmp, \poly0, \poly3, \res0
  str \tmp, [\rptr_tmp, #-4]
.endm

// reduce 2 registers
.macro deserialize aptr, tmp, tmp2, tmp3, t0, t1
	ldrb.w \tmp, [\aptr, #2]
	ldrh.w \tmp2, [\aptr, #3]
	ldrb.w \tmp3, [\aptr, #5]
	ldrh.w \t0, [\aptr], #6

	ubfx \t1, \t0, #12, #4
	ubfx \t0, \t0, #0, #12
	orr \t1, \t1, \tmp, lsl #4
	orr \t0, \t0, \t1, lsl #16
	//tmp is free now
	ubfx \t1, \tmp2, #12, #4
	ubfx \tmp, \tmp2, #0, #12
	orr \t1, \t1, \tmp3, lsl #4
	orr \t1, \tmp, \t1, lsl #16
.endm

// void frombytes_mul_asm_acc_32_32(int32_t *r_tmp, const int16_t *b, const unsigned char *c, const int32_t zetas[64])
.global frombytes_mul_asm_acc_32_32
.type frombytes_mul_asm_acc_32_32, %function
.align 2
frombytes_mul_asm_acc_32_32:
  push {r4-r11, r14}

  rptr_tmp .req r0
  bptr     .req r1
  aptr     .req r2
  zetaptr  .req r3
  t0       .req r4
	t1       .req r5
	tmp      .req r6
	tmp2     .req r7
	tmp3     .req r8
	q        .req r9
	qa       .req r10
	qinv     .req r11
	zeta     .req r12
	ctr      .req r14

  movw qa, #26632
	movt  q, #3329
	### qinv=0x6ba8f301
	movw qinv, #62209
	movt qinv, #27560

  add ctr, rptr_tmp, #64*4*4
  1:
    ldr.w zeta, [zetaptr], #4
    deserialize aptr, tmp, tmp2, tmp3, t0, t1

    doublebasemul_frombytes_asm_acc_32_32 rptr_tmp, bptr, zeta, tmp3, t0, t1, tmp, tmp2, q, qa, qinv
    cmp.w rptr_tmp, ctr
    bne.w 1b

pop {r4-r11, pc}

.size frombytes_mul_asm_acc_32_32, .-frombytes_mul_asm_acc_32_32
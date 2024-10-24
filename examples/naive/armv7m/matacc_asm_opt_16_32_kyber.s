.syntax unified
.cpu cortex-m4
.thumb

.extern shake128_squeezeblocks

// q locates in the bottom half of the register
.macro plant_red_b q, qa, qinv, tmp
	mul \tmp, \tmp, \qinv     
	//tmp*qinv mod 2^2n/ 2^n; in high half
	smlatb \tmp, \tmp, \q, \qa
	// result in high half
.endm

// Checks if val0 is suitable and multiplies with values from bptr using func 
.macro first_if func, tmp, tmp2, val0, val1, rptr, bptr, cptr, bufptr, zetaptr, k, q, qa, qinv, ctr
  // if (val0 < KYBER_Q)
  cmp.w \val0, \q
  bhs.w 2f
    strh \val0, [\cptr], #2
    add \k, #1
    cmp.w \k, #4
    bne.w 2f
        sub \cptr, #4*2
        vmov s18, \bufptr
        vmov s19, \ctr
        vmov s20, \val1
        \func \rptr, \bptr, \cptr, \zetaptr, \bufptr, \k, \val0, \val1, \q, \qa, \qinv, \tmp, \tmp2, \ctr
        vmov \bufptr, s18
        vmov \ctr, s19
        vmov \val1, s20

        add \ctr, #1
        
        movw \k, #0
    2:
.endm

// Checks if val1 is suitable and multiplies with values from bptr using func 
.macro second_if func, tmp, tmp2, val0, val1, rptr, bptr, cptr, bufptr, zetaptr, k, q, qa, qinv, ctr
// if (val1 < KYBER_Q && ctr < KYBER_N/4)
  cmp.w \val1, \q
  bhs.w 2f
    cmp.w \ctr, #256/4
    bge.w 2f
      strh \val1, [\cptr], #2
      add \k, #1
      cmp.w \k, #4
      bne.w 2f
        sub \cptr, #4*2
        vmov s18, \bufptr
        vmov s19, \ctr
        \func \rptr, \bptr, \cptr, \zetaptr, \bufptr, \k, \val0, \val1, \q, \qa, \qinv, \tmp, \tmp2, \ctr
        vmov \bufptr, s18
        vmov \ctr, s19

        add \ctr, #1
        
        movw \k, #0
    2:
.endm

.macro load_vals val0, val1, bufptr, tmp
  ldrh \val0, [\bufptr], #2
  ldrb \val1, [\bufptr], #1
  ubfx \tmp, \val0, #12, #4
  orr \val1, \tmp, \val1, lsl #4
  ubfx \val0, \val0, #0, #12
  ubfx \val1, \val1, #0, #12
.endm

.macro doublebasemul_asm_opt_16_32 rptr_tmp, aptr, bptr, tmp3, poly0, poly1, poly2, poly3, q, qa, qinv, tmp, aprimeptr, tmp2
  vmov \aprimeptr, s27
  ldr \poly0, [\aptr], #4
  ldr \poly1, [\bptr]
  ldr \poly2, [\aptr], #4
  ldr.w \poly3, [\bptr, #4]

  ldr.w \tmp2, [\aprimeptr], #4 // load cached value
  
  // (poly0_t * zeta) * poly1_t + poly0_b * poly1_b
  smuad \tmp, \tmp2, \poly1

  // poly1_t * poly0_b + poly1_b * poly0_t
  smuadx \tmp3, \poly0, \poly1
    
  str \tmp, [\rptr_tmp], #4
  str \tmp3, [\rptr_tmp], #4

  ldr \tmp, [\aprimeptr], #4 // load cached value

  smuad \tmp2, \tmp, \poly3

  smuadx \tmp3, \poly2, \poly3

  str.w \tmp2, [\rptr_tmp], #4
  str.w \tmp3, [\rptr_tmp], #4
  vmov s27, \aprimeptr
.endm 

// shake128_squeezeblocks into buffer if all bytes have been used
.macro third_if tmp, tmp2, rptr, bptr, cptr, bufptr, ctr
// if (pos + 3 > buflen && ctr < KYBER_N/4)
  vmov \tmp, s17
  add \tmp, #168 // XOF_BLOCKBYTES=168
  add \tmp2, \bufptr, #3
  cmp.w \tmp2, \tmp  // pos + 3 > buflen
  ble.w 2f
    cmp.w \ctr, #256/4
    bge.w 2f
      vmov \bufptr, s17

      vmov s16, r12
      vmov s18, \rptr
      vmov s19, \bptr
      vmov s20, \cptr
      vmov s21, \ctr

      mov \rptr, \bufptr
      movw \bptr, #1
      vmov \cptr, s26 // load state

      bl shake128_squeezeblocks

      vmov r12, s16
      vmov \rptr, s18
      vmov \bptr, s19
      vmov \cptr, s20
      vmov \ctr, s21
      vmov \bufptr, s17
    2:
.endm

// void matacc_asm_opt_16_32(int32_t *r_tmp, const int16_t *b, int16_t c[4], unsigned char buf[XOF_BLOCKBYTES+2], xof_state *state, const int16_t *aprimeptr)
.global matacc_asm_opt_16_32
.type matacc_asm_opt_16_32, %function
.align 2
matacc_asm_opt_16_32:
  push {r0-r11, r14}
  rptr   .req r0 
  bptr   .req r1
  cptr   .req r2
  bufptr .req r3
  tmp3   .req r4
  val0   .req r5
  val1   .req r6
  tmp    .req r7
  tmp2   .req r8
  k      .req r9
  q      .req r10
  qa     .req r11
  qinv   .req r12
  ctr    .req r14

  movw qa, #26632
	movw q, #3329
	### qinv=0x6ba8f301
	movw qinv, #62209
	movt qinv, #27560
  movw k, #0
  
  ldr.w tmp, [sp, #13*4] // load state from stack
  vmov s26, tmp

  ldr.w tmp, [sp, #14*4] // load aprimeptr from stack
  vmov s27, tmp

  // outer while loop
  movw ctr, #0
  vmov s17, bufptr // save bufptr to check later
  1:

    load_vals val0, val1, bufptr, tmp

    first_if doublebasemul_asm_opt_16_32, tmp, tmp2, val0, val1, rptr, bptr, cptr, bufptr, tmp3, k, q, qa, qinv, ctr
    
    second_if doublebasemul_asm_opt_16_32, tmp, tmp2, val0, val1, rptr, bptr, cptr, bufptr, tmp3, k, q, qa, qinv, ctr

    third_if tmp, tmp2, rptr, bptr, cptr, bufptr, ctr

    cmp ctr, #256/4
    blt.w 1b

  pop {r0-r11, pc}
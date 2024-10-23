.syntax unified
.cpu cortex-m4
.thumb

// q locate in the top half of the register
.macro plant_red q, qa, qinv, tmp
 mul \tmp, \tmp, \qinv
 // tmp*qinv mod 2^2n/ 2^n; in high half
 smlatt \tmp, \tmp, \q, \qa
 // result in high half
.endm

.global basemul_asm_opt_m7
.type basemul_asm_opt_m7, %function
.align 2
basemul_asm_opt_m7:
 push {r4-r11, lr}

 rptr    .req r0
 aptr    .req r1
 bptr    .req r2
 zetaptr .req r3
 poly0   .req r4
 poly1   .req r6
 poly2   .req r5
 poly3   .req r7
 q       .req r8
 qa      .req r14
 qinv    .req r9
 tmp     .req r10
 tmp2    .req r11
 zeta    .req r12
 loop    .req r14

 // movw qa, #26632
 movt  q, #3329
 ### qinv=0x6ba8f301
 movw qinv, #62209
 movt qinv, #27560

 movw loop, #64
 1:
 vmov.w s0,loop
 movw qa, #26632

 ldrd poly0, poly2, [aptr], #8
 ldrd poly1, poly3, [bptr], #8
 // ldr poly0, [aptr], #4
 // ldr poly1, [bptr], #4
 // ldr poly2, [aptr], #4
 // ldr poly3, [bptr], #4

 ldr.w zeta, [zetaptr], #4

 // basemul(r->coeffs + 4 * i, a->coeffs + 4 * i, b->coeffs + 4 * i, zetas[64 + i]);
 smulwt tmp, zeta, poly1
 smlabt tmp, tmp, q, qa
 smultt tmp, poly0, tmp
 smlabb tmp, poly0, poly1, tmp
 plant_red q, qa, qinv, tmp
 // r[0] in upper half of tmp

 smuadx tmp2, poly0, poly1
 plant_red q, qa, qinv, tmp2
 // r[1] in upper half of tmp2
 pkhtb tmp, tmp2, tmp, asr#16
 str tmp, [rptr], #4

 neg zeta, zeta

 // basemul(r->coeffs + 4 * i + 2, a->coeffs + 4 * i + 2, b->coeffs + 4 * i + 2, - zetas[64 + i]);
 smulwt tmp, zeta, poly3
 smlabt tmp, tmp, q, qa
 smultt tmp, poly2, tmp
 smlabb tmp, poly2, poly3, tmp
 plant_red q, qa, qinv, tmp
 // r[0] in upper half of tmp

 smuadx tmp2, poly2, poly3
 plant_red q, qa, qinv, tmp2
 // r[1] in upper half of tmp2
 pkhtb tmp, tmp2, tmp, asr#16
 str tmp, [rptr], #4

 vmov.w loop,s0
 subs.w loop, #1
 bne.w 1b
    pop {r4-r11, pc}
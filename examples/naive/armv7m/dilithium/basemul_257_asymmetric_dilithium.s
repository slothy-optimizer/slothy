// 2
.macro barrett_32 a, Qbar, Q, tmp
    smmulr \tmp, \a, \Qbar
    mls \a, \tmp, \Q, \a
.endm

.syntax unified
.cpu cortex-m4

.align 2
.global __asm_asymmetric_mul_257_16
.type __asm_asymmetric_mul_257_16, %function
__asm_asymmetric_mul_257_16:
    push.w {r4-r11, lr}

    .equ width, 4

    add.w r12, r0, #256*width
    _asymmetric_mul_16_loop:

    ldr.w r7, [r1, #width]
    ldr.w r4, [r1], #2*width
    ldr.w r8, [r2, #width]
    ldr.w r5, [r2], #2*width
    ldr.w r9, [r3, #width]
    ldr.w r6, [r3], #2*width

    smuad r10, r4, r6
    smuadx r11, r4, r5

    str.w r11, [r0, #width]
    str.w r10, [r0], #2*width // @slothy:core=True

    smuad r10, r7, r9
    smuadx r11, r7, r8

    str.w r11, [r0, #width]
    str.w r10, [r0], #2*width // @slothy:core=True

    cmp.w r0, r12
    bne.w _asymmetric_mul_16_loop

    pop.w {r4-r11, pc}

.size __asm_asymmetric_mul_257_16, .-__asm_asymmetric_mul_257_16
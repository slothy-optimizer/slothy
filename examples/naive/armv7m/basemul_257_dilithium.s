// 2
.macro barrett_32 a, Qbar, Q, tmp
    smmulr \tmp, \a, \Qbar
    mls \a, \tmp, \Q, \a
.endm

.syntax unified
.cpu cortex-m4

.align 2
.global __asm_point_mul_257_16
.type __asm_point_mul_257_16, %function
__asm_point_mul_257_16:
    push.w {r4-r11, lr}

    ldr.w r14, [sp, #36]

    .equ width, 4

    add.w r12, r14, #64*width
    _point_mul_16_loop:

    ldr.w r7, [r1, #2*width]
    ldr.w r8, [r1, #3*width]
    ldr.w r9, [r14, #1*width]
    ldr.w r5, [r1, #1*width]
    ldr.w r4, [r1], #4*width
    ldr.w r6, [r14], #2*width

    smultb r10, r4, r6
    barrett_32 r10, r2, r3, r11
    pkhbt r4, r4, r10, lsl #16

    neg r6, r6

    smultb r10, r5, r6
    barrett_32 r10, r2, r3, r11
    pkhbt r5, r5, r10, lsl #16

    str.w r5, [r0, #1*width]
    str.w r4, [r0], #2*width

    smultb r10, r7, r9
    barrett_32 r10, r2, r3, r11
    pkhbt r7, r7, r10, lsl #16

    neg r9, r9

    smultb r10, r8, r9
    barrett_32 r10, r2, r3, r11
    pkhbt r8, r8, r10, lsl #16

    str.w r8, [r0, #1*width]
    str.w r7, [r0], #2*width

    cmp.w r14, r12
    bne.w _point_mul_16_loop

    pop.w {r4-r11, pc}

.size __asm_point_mul_257_16, .-__asm_point_mul_257_16
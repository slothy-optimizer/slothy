.syntax unified
.thumb

.macro barrett_32 a, Qbar, Q, tmp
    smmulr.w \tmp, \a, \Qbar
    mls.w \a, \tmp, \Q, \a
.endm

// void asm_reduce32(int32_t a[N]);
.global pqcrystals_dilithium_small_asm_reduce32_central
.type pqcrystals_dilithium_small_asm_reduce32_central, %function
.align 2
pqcrystals_dilithium_small_asm_reduce32_central:
    push {r4-r12, lr}


    movw r9, #:lower16:5585133
    movt r9, #:upper16:5585133
    mov.w r10,#769

    movw r12, #32
    1:
    reduce32_central_start:
        ldr.w r1, [r0]
        ldr.w r2, [r0, #1*4]
        ldr.w r3, [r0, #2*4]
        ldr.w r4, [r0, #3*4]
        ldr.w r5, [r0, #4*4]
        ldr.w r6, [r0, #5*4]
        ldr.w r7, [r0, #6*4]
        ldr.w r8, [r0, #7*4]

        barrett_32 r1, r9, r10, r11
        barrett_32 r2, r9, r10, r11
        barrett_32 r3, r9, r10, r11
        barrett_32 r4, r9, r10, r11
        barrett_32 r5, r9, r10, r11
        barrett_32 r6, r9, r10, r11
        barrett_32 r7, r9, r10, r11
        barrett_32 r8, r9, r10, r11


        str.w r2, [r0, #1*4]
        str.w r3, [r0, #2*4]
        str.w r4, [r0, #3*4]
        str.w r5, [r0, #4*4]
        str.w r6, [r0, #5*4]
        str.w r7, [r0, #6*4]
        str.w r8, [r0, #7*4]
        str r1, [r0], #8*4
        subs r12, #1
    reduce32_central_end:
        bne.w 1b

    pop {r4-r12, pc}

.size pqcrystals_dilithium_small_asm_reduce32_central, .-pqcrystals_dilithium_small_asm_reduce32_central
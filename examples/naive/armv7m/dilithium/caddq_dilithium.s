.syntax unified
.thumb

.macro caddq a, tmp, q
    and     \tmp, \q, \a, asr #31
    add     \a, \a, \tmp
.endm

// void asm_caddq(int32_t a[N]);
.global pqcrystals_dilithium_asm_caddq
.type pqcrystals_dilithium_asm_caddq, %function
.align 2
pqcrystals_dilithium_asm_caddq:
    push {r4-r11, r14}

    movw r12,#:lower16:8380417
    movt r12,#:upper16:8380417

    movw r10, #32
    1:
        ldr.w r1, [r0]
        ldr.w r2, [r0, #1*4]
        ldr.w r3, [r0, #2*4]
        ldr.w r4, [r0, #3*4]
        ldr.w r5, [r0, #4*4]
        ldr.w r6, [r0, #5*4]
        ldr.w r7, [r0, #6*4]
        ldr.w r8, [r0, #7*4]

        caddq r1, r9, r12
        caddq r2, r9, r12
        caddq r3, r9, r12
        caddq r4, r9, r12
        caddq r5, r9, r12
        caddq r6, r9, r12
        caddq r7, r9, r12
        caddq r8, r9, r12

        str.w r2, [r0, #1*4]
        str.w r3, [r0, #2*4]
        str.w r4, [r0, #3*4]
        str.w r5, [r0, #4*4]
        str.w r6, [r0, #5*4]
        str.w r7, [r0, #6*4]
        str.w r8, [r0, #7*4]
        str r1, [r0], #8*4
        subs r10, #1
        bne.w 1b

    pop {r4-r11, pc}

.size pqcrystals_dilithium_asm_caddq, .-pqcrystals_dilithium_asm_caddq
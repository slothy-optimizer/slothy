movw r5, #4
.loop:
    ldr r0, [r1]
    add r0, r0, #1
    str r0, [r1], #4
    subs.w r5, #1
    bne.w .loop

movw r5, #4
loop:
    ldr r0, [r1]
    add r0, r0, #1
    str r0, [r1], #4
    subs.w r5, #1
    bne.w loop
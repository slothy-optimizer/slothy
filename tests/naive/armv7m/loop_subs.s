movw r5, #16
start:
    subs.w r5, #1
    bne.w start

movw r5, #16
start2:
    eor.w r0, r0, r7
    mul r1, r0, r8
    eor.w r0, r1, r4
    subs.w r5, r5, #1
    bne.w start2
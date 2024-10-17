.equ ddd, 4

start:
ldr r1, [r0]
ldr r3, [r0, #ddd*2]
ldr r5, [r0, #ddd*4]
ldr r7, [r0, #ddd*6]
ldr r2, [r0, #ddd*1]
ldr r4, [r0, #ddd*3]
ldr r6, [r0, #ddd*5]
ldr r8, [r0, #ddd*7]
end:
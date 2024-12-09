
start:
ldr r1, [r0,   #4]
add r1, r2,r1
eor.w r1,r1, r3
smlabt r3,r2, r2, r1
asrs r3,   r3,#1
str r3, [r0,#4]

ldm r0, {r1-r2,r14}
add r1, r2,r1
eor.w r1,r1, r14
smlabt r3,r2, r2, r1
asrs r3,   r3,#1
str r3, [r0,#4]


ldm r0, {r1-r3}
add r1, r2,r1
eor.w r1,r1, r3
smlabt r3,r2, r2, r1
asrs r3,   r3,#1
str r3, [r0,#4]

ldm r0, {r1,r2,r3}
add r1, r2,r1
eor.w r1,r1, r3
smlabt r3,r2, r2, r1
asrs r3,   r3,#1
str r3, [r0,#4]

end:
start0:
ldm r0, {r2-r5}
ldm r1, {r6-r9}

add r10, r2, r6
add r11, r3, r7
add r12, r4, r8
add r14, r5, r9

stm r0!, {r10,r11,r12,r14}
end0:

start1:
ldm r0, {r2-r5}
ldm r1, {r6-r9}

add r10, r2, r6
add r11, r3, r7
add r12, r4, r8
add r14, r5, r9

stm r0!, {r10,r11,r12,r14}
end1:
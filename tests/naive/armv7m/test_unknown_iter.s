.syntax unified

count .req r2

// Simple loop for testing unknown iteration count with non-power-of-2 unrolling on ARM v7m
// This should trigger tail section generation when unroll > 1
start:
    add r5, r5, r4
    add r7, r5, r1
    ldr r5, [r0, #8]
    add r5, r5, r7

    subs count, count, #1
    bgt start
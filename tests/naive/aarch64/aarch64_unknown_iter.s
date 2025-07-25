count .req x2

// Simple loop for testing unknown iteration count with non-power-of-2 unrolling
// This should trigger tail section generation when unroll > 1
start:
    add x5, x5, x4
    add x7, x5, x1
    ldr x5, [x0, #8]
    add x5, x5, x7

    subs count, count, #1
    b.gt start

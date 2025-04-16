count .req x2

mov count, #16
start:

    add x5, x5, x4
    add x7, x5, x1
    ldr x5, [x0, #4]
    add x5, x5, x7

    subs count, count, #2
    b.gt count, start

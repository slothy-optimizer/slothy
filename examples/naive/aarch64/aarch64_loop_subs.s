count .req x2

mov count, #16
start:

    nop

    subs count, count, #1
    cbnz count, start

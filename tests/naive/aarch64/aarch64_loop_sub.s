count .req x2

mov count, #16
start:

    nop

    subs count, count, #1
    cbnz count, start

/* start2-loop is semantically incorrect */
start2:

    nop

    subs count, count, #1
    cbz count, start2

mov count, #16
start3:

    nop

    subs w10, w10, #1
    subs count, count, #1
    cbnz count, start3
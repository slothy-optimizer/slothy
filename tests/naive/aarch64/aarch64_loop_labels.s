count .req x2
data_ptr .req x0

mov count, #4
.loop:
    ldr x3, [data_ptr, #0]
    add x3, x3, #1
    str x3, [data_ptr], #8
    subs count, count, #1
    b.ne .loop

mov count, #4
loop:
    ldr x3, [data_ptr, #0]
    add x3, x3, #1
    str x3, [data_ptr], #8
    subs count, count, #1
    b.ne loop

mov count, #4
1:
    ldr x3, [data_ptr, #0]
    add x3, x3, #1
    str x3, [data_ptr], #8
    subs count, count, #1
    b.ne 1b

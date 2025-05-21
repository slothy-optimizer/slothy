count .req x2

mov count, #16
start:

	nop
	add	count,	count,	#0

    subs count, count, #1
    cbnz count, start

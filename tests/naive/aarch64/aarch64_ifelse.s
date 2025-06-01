ldr q0, [x1, #0]
ldr q1, [x2, #0]

ldr q8,  [x0]
ldr q9,  [x0, #1*16]
ldr q10, [x0, #2*16]
ldr q11, [x0, #3*16]
.if 5 != 0
    mul v24.8h, v9.8h, v0.h[0]
    sqrdmulh v9.8h, v9.8h, v0.h[1]
    mls v24.8h, v9.8h, v1.h[0]
    sub     v9.8h,    v8.8h, v24.8h
    add     v8.8h,    v8.8h, v24.8h

    .if 5 > 2
        mul v24.8h, v11.8h, v0.h[0]
        sqrdmulh v11.8h, v11.8h, v0.h[1]
        mls v24.8h, v11.8h, v1.h[0]
        sub     v11.8h,    v10.8h, v24.8h
        add     v10.8h,    v10.8h, v24.8h
    .else
        add v10.8h,   v10.8h, v11.8h
    .endif
.else
    add x0, x0, #4
.endif
str q8,  [x0], #4*16
str q9,  [x0, #-3*16]
str q10, [x0, #-2*16]
str q11, [x0, #-1*16]
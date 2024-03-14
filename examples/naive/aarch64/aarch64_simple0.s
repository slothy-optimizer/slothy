ldr q0, [x1, #0]

ldr q8,  [x0]
ldr q9,  [x0, #1*16]
ldr q10, [x0, #2*16]
ldr q11, [x0, #3*16]

mul v24.8h, v9.8h, v0.h[0]
sqrdmulh v9.8h, v9.8h, v0.h[1]
mls v24.8h, v9.8h, v1.h[0]
sub     v9.8h,    v8.8h, v24.8h
add     v8.8h,    v8.8h, v24.8h

mul v24.8h, v11.8h, v0.h[0]
sqrdmulh v11.8h, v11.8h, v0.h[1]
mls v24.8h, v11.8h, v1.h[0]
sub     v11.8h,    v10.8h, v24.8h
add     v10.8h,    v10.8h, v24.8h

str q8,  [x0], #4*16
str q9,  [x0, #-3*16]
str q10, [x0, #-2*16]
str q11, [x0, #-1*16]
start:
ldr q0, [x1, #0]
ldr q1, [x2, #0]
eor3 v5.16b, v1.16b, v2.16b, v3.16b // @slothy:some_tag // some comment
eor3 v3.16b, v1.16b, v2.16b, v3.16b // Cannot we split naively
ldr q8,  [x0]
ldr q9,  [x0, #1*16]
ldr q10, [x0, #2*16]
ldr q11, [x0, #3*16]
mul v24.8h, v9.8h, v0.h[0]
sqrdmulh v9.8h, v9.8h, v0.h[1]
mls v24.8h, v9.8h, v1.h[0]
sub     v9.8h,    v8.8h, v24.8h
add     v8.8h,    v8.8h, v24.8h
end:

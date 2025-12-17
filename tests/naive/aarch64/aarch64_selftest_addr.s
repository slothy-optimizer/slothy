start:
ld2 { v0.S, v1.S }[1], [x0], #8
ld1r {v2.4s}, [x1], #4
ldr q3, [x2, #16]
ldr q4, [x3], #16
ld1 {v5.4s}, [x4], #16
ldr x21, [x5, #8]
ldp x22, x23, [x6, #16]
mov w23, #0
ldr w24, [x7, w23, SXTW #0]
ldr x25, [x8], #8
str q6, [x9, #16]
str q7, [x10], #16
str x26, [x11, #8]
stp x27, x12, [x18, #16]
str x28, [x13], #8

// TODO: Instructions not supported on Cortex-A55
// ldp q24, q25, [x14, #32]
// ld4 {v26.4s, v27.4s, v28.4s, v29.4s}, [x15], #64
// st4 {v30.4s, v31.4s, v0.4s, v1.4s}, [x16], #64
// ld3 {v2.4s, v3.4s, v4.4s}, [x17], #48
// st3 {v5.4s, v6.4s, v7.4s}, [x18], #48
// ld2 {v8.4s, v9.4s}, [x19], #32
// st2 {v10.4s, v11.4s}, [x20], #32
end:

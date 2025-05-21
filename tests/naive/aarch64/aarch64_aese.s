
ldr q10, [x0, #0*16]
ldr q11, [x0, #3*16]
aese v10.16b, v11.16b
str q10, [x0, #-2*16]
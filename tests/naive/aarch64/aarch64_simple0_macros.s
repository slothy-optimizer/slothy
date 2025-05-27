qdata0   .req q8
qdata1   .req q9
qdata2   .req q10
qdata3   .req q11

qtwiddle .req q0
qmodulus .req q1

data0    .req v8
data1    .req v9
data2    .req v10
data3    .req v11

twiddle  .req v0
modulus  .req v1

tmp      .req v12

data_ptr      .req x0
twiddle_ptr   .req x1
modulus_ptr   .req x2

.macro barmul out, in, twiddle, modulus
    mul      \out.8h,   \in.8h, \twiddle.h[0]
    sqrdmulh \in.8h,    \in.8h, \twiddle.h[1]
    mls      \out.8h,   \in.8h, \modulus.h[0]
.endm

.macro butterfly data0, data1, tmp, twiddle, modulus
    barmul \tmp, \data1, \twiddle, \modulus
    sub    \data1.8h, \data0.8h, \tmp.8h
    add    \data0.8h, \data0.8h, \tmp.8h
.endm

count .req x2

start:

    ldr qtwiddle, [twiddle_ptr, #0]
    ldr qmodulus, [modulus_ptr, #0]

    ldr qdata0, [data_ptr, #0*16]
    ldr qdata1, [data_ptr, #1*16]
    ldr qdata2, [data_ptr, #2*16]
    ldr qdata3, [data_ptr, #3*16]

    butterfly data0, data1, tmp, twiddle, modulus
    butterfly data2, data3, tmp, twiddle, modulus

    str qdata0, [data_ptr], #4*16
    str qdata1, [data_ptr, #-3*16]
    str qdata2, [data_ptr, #-2*16]
    str qdata3, [data_ptr, #-1*16]

end:

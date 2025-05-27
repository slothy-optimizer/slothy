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
ldr qtwiddle, [twiddle_ptr, #0]
ldr qmodulus, [modulus_ptr, #0]
mov count, #16
        ldr q21, [x0, #16]
        mul v18.8H, v21.8H, v0.H[0]
        sub count, count, #1
start:
                                                // Instructions:    18
                                                // Expected cycles: 22
                                                // Expected IPC:    0.82
                                                //
                                                // Cycle bound:     11.0
                                                // IPC bound:       1.64
                                                //
                                                // Wall time:     1.15s
                                                // User time:     1.15s
                                                //
                                                // ----- cycle (expected) ------>
                                                // 0                        25
                                                // |------------------------|----
        ldr q19, [x0, #48]                      // *.............................
        sqrdmulh v26.8H, v21.8H, v0.H[1]        // ..*...........................
        ldr q8, [x0, #0]                        // ...*..........................
        mul v4.8H, v19.8H, v0.H[0]              // .....*........................
        sqrdmulh v7.8H, v19.8H, v0.H[1]         // ......*.......................
        mls v18.8H, v26.8H, v1.H[0]             // .......*......................
        ldr q24, [x0, #32]                      // ........*.....................
        mls v4.8H, v7.8H, v1.H[0]               // ..........*...................
        sub v19.8H, v8.8H, v18.8H               // ...........*..................
        ldr q21, [x0, #80]                      // ............e.................
        sub v13.8H, v24.8H, v4.8H               // ..............*...............
        str q19, [x0, #16]                      // ...............*..............
        add v9.8H, v8.8H, v18.8H                // ................*.............
        str q13, [x0, #48]                      // .................*............
        add v22.8H, v24.8H, v4.8H               // ..................*...........
        str q9, [x0], #4*16                     // ...................*..........
        mul v18.8H, v21.8H, v0.H[0]             // ....................e.........
        str q22, [x0, #-32]                     // .....................*........

                                                    // ------ cycle (expected) ------->
                                                    // 0                        25
                                                    // |------------------------|------
        // ldr q8, [x0, #0*16]                      // ..........'..*..................
        // ldr q9, [x0, #1*16]                      // e.........'...........~.........
        // ldr q10, [x0, #2*16]                     // ..........'.......*.............
        // ldr q11, [x0, #3*16]                     // ..........*.....................
        // mul      v12.8h,   v9.8h, v0.h[0]        // ........e.'...................~.
        // sqrdmulh v9.8h,    v9.8h, v0.h[1]        // ..........'.*...................
        // mls      v12.8h,   v9.8h, v1.h[0]        // ..........'......*..............
        // sub    v9.8h, v8.8h, v12.8h              // ..........'..........*..........
        // add    v8.8h, v8.8h, v12.8h              // ....~.....'...............*.....
        // mul      v12.8h,   v11.8h, v0.h[0]       // ..........'....*................
        // sqrdmulh v11.8h,    v11.8h, v0.h[1]      // ..........'.....*...............
        // mls      v12.8h,   v11.8h, v1.h[0]       // ..........'.........*...........
        // sub    v11.8h, v10.8h, v12.8h            // ..~.......'.............*.......
        // add    v10.8h, v10.8h, v12.8h            // ......~...'.................*...
        // str q8, [x0], #4*16                      // .......~..'..................*..
        // str q9, [x0, #-3*16]                     // ...~......'..............*......
        // str q10, [x0, #-2*16]                    // .........~'....................*
        // str q11, [x0, #-1*16]                    // .....~....'................*....

        subs count, count, 1
        cbnz count, start
        ldr q19, [x0, #48]
        sqrdmulh v26.8H, v21.8H, v0.H[1]
        ldr q8, [x0, #0]
        mul v4.8H, v19.8H, v0.H[0]
        sqrdmulh v7.8H, v19.8H, v0.H[1]
        mls v18.8H, v26.8H, v1.H[0]
        ldr q24, [x0, #32]
        mls v4.8H, v7.8H, v1.H[0]
        sub v19.8H, v8.8H, v18.8H
        sub v13.8H, v24.8H, v4.8H
        str q19, [x0, #16]
        add v9.8H, v8.8H, v18.8H
        str q13, [x0, #48]
        add v22.8H, v24.8H, v4.8H
        str q9, [x0], #4*16
        str q22, [x0, #-32]

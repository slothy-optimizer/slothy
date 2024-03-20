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
        ldr q31, [x0, #16]
        mul v4.8H, v31.8H, v0.H[0]
        sub count, count, #1
start:
        ldr q25, [x0, #48]                      // ...*..............
        // gap                                  // ..................
        // gap                                  // ..................
        // gap                                  // ..................
        sqrdmulh v11.8H, v31.8H, v0.H[1]        // .....*............
        // gap                                  // ..................
        ldr q12, [x0, #0]                       // *.................
        // gap                                  // ..................
        // gap                                  // ..................
        // gap                                  // ..................
        mul v3.8H, v25.8H, v0.H[0]              // .........*........
        // gap                                  // ..................
        sqrdmulh v31.8H, v25.8H, v0.H[1]        // ..........*.......
        // gap                                  // ..................
        mls v4.8H, v11.8H, v1.H[0]              // ......*...........
        // gap                                  // ..................
        ldr q25, [x0, #32]                      // ..*...............
        // gap                                  // ..................
        // gap                                  // ..................
        // gap                                  // ..................
        mls v3.8H, v31.8H, v1.H[0]              // ...........*......
        // gap                                  // ..................
        sub v23.8H, v12.8H, v4.8H               // .......*..........
        // gap                                  // ..................
        ldr q31, [x0, #80]                      // .e................
        // gap                                  // ..................
        // gap                                  // ..................
        // gap                                  // ..................
        sub v19.8H, v25.8H, v3.8H               // ............*.....
        // gap                                  // ..................
        str q23, [x0, #16]                      // ...............*..
        // gap                                  // ..................
        add v3.8H, v25.8H, v3.8H                // .............*....
        // gap                                  // ..................
        str q19, [x0, #48]                      // .................*
        // gap                                  // ..................
        add v25.8H, v12.8H, v4.8H               // ........*.........
        // gap                                  // ..................
        str q3, [x0, #32]                       // ................*.
        // gap                                  // ..................
        mul v4.8H, v31.8H, v0.H[0]              // ....e.............
        // gap                                  // ..................
        str q25, [x0], #4*16                    // ..............*...
        // gap                                  // ..................

        // original source code
        // ldr q8, [x0, #0*16]                      // .........|.*...............
        // ldr q9, [x0, #1*16]                      // e........|........e........
        // ldr q10, [x0, #2*16]                     // .........|.....*...........
        // ldr q11, [x0, #3*16]                     // .........*.................
        // mul      v12.8h,   v9.8h, v0.h[0]        // .......e.|...............e.
        // sqrdmulh v9.8h,    v9.8h, v0.h[1]        // .........|*................
        // mls      v12.8h,   v9.8h, v1.h[0]        // .........|....*............
        // sub    v9.8h, v8.8h, v12.8h              // .........|.......*.........
        // add    v8.8h, v8.8h, v12.8h              // .....*...|.............*...
        // mul      v12.8h,   v11.8h, v0.h[0]       // .........|..*..............
        // sqrdmulh v11.8h,    v11.8h, v0.h[1]      // .........|...*.............
        // mls      v12.8h,   v11.8h, v1.h[0]       // .........|......*..........
        // sub    v11.8h, v10.8h, v12.8h            // .*.......|.........*.......
        // add    v10.8h, v10.8h, v12.8h            // ...*.....|...........*.....
        // str q8, [x0], #4*16                      // ........*|................*
        // str q9, [x0, #-3*16]                     // ..*......|..........*......
        // str q10, [x0, #-2*16]                    // ......*..|..............*..
        // str q11, [x0, #-1*16]                    // ....*....|............*....

        //
        // LLVM MCA STATISTICS (ORIGINAL) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      1800
        // Total Cycles:      2902
        // Total uOps:        1900
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    0.65
        // IPC:               0.62
        // Block RThroughput: 10.0
        //
        //
        // Resources:
        // [0.0] - CortexA55UnitALU
        // [0.1] - CortexA55UnitALU
        // [1]   - CortexA55UnitB
        // [2]   - CortexA55UnitDiv
        // [3.0] - CortexA55UnitFPALU
        // [3.1] - CortexA55UnitFPALU
        // [4]   - CortexA55UnitFPDIV
        // [5.0] - CortexA55UnitFPMAC
        // [5.1] - CortexA55UnitFPMAC
        // [6]   - CortexA55UnitLd
        // [7]   - CortexA55UnitMAC
        // [8]   - CortexA55UnitSt
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3.0]  [3.1]  [4]    [5.0]  [5.1]  [6]    [7]    [8]
        //  -      -      -      -     10.00  10.00   -      -      -     4.00    -     4.00
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3.0]  [3.1]  [4]    [5.0]  [5.1]  [6]    [7]    [8]    Instructions:
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q8, [x0]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q9, [x0, #16]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q10, [x0, #32]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q11, [x0, #48]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     mul.8h	v12, v9, v0[0]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     sqrdmulh.8h	v9, v9, v0[1]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     mls.8h	v12, v9, v1[0]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     sub.8h	v9, v8, v12
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     add.8h	v8, v8, v12
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     mul.8h	v12, v11, v0[0]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     sqrdmulh.8h	v11, v11, v0[1]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     mls.8h	v12, v11, v1[0]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     sub.8h	v11, v10, v12
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     add.8h	v10, v10, v12
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   str	q8, [x0], #64
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   stur	q9, [x0, #-48]
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   stur	q10, [x0, #-32]
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   stur	q11, [x0, #-16]
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456789          0123456789
        // Index     0123456789          0123456789          0123456789          0123456789          012345678
        //
        // [0,0]     DeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	q8, [x0]
        // [0,1]     .DeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	q9, [x0, #16]
        // [0,2]     . DeeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	q10, [x0, #32]
        // [0,3]     .  DeeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   ldr	q11, [x0, #48]
        // [0,4]     .   DeeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul.8h	v12, v9, v0[0]
        // [0,5]     .    DeeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sqrdmulh.8h	v9, v9, v0[1]
        // [0,6]     .    .   DeeeE .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mls.8h	v12, v9, v1[0]
        // [0,7]     .    .    .  DeE    .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sub.8h	v9, v8, v12
        // [0,8]     .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .    .    .  .   add.8h	v8, v8, v12
        // [0,9]     .    .    .    DeeeE.    .    .    .    .    .    .    .    .    .    .    .    .    .  .   mul.8h	v12, v11, v0[0]
        // [0,10]    .    .    .    .DeeeE    .    .    .    .    .    .    .    .    .    .    .    .    .  .   sqrdmulh.8h	v11, v11, v0[1]
        // [0,11]    .    .    .    .    DeeeE.    .    .    .    .    .    .    .    .    .    .    .    .  .   mls.8h	v12, v11, v1[0]
        // [0,12]    .    .    .    .    .   DeE   .    .    .    .    .    .    .    .    .    .    .    .  .   sub.8h	v11, v10, v12
        // [0,13]    .    .    .    .    .    DeE  .    .    .    .    .    .    .    .    .    .    .    .  .   add.8h	v10, v10, v12
        // [0,14]    .    .    .    .    .    .DE  .    .    .    .    .    .    .    .    .    .    .    .  .   str	q8, [x0], #64
        // [0,15]    .    .    .    .    .    . DE .    .    .    .    .    .    .    .    .    .    .    .  .   stur	q9, [x0, #-48]
        // [0,16]    .    .    .    .    .    .  DE.    .    .    .    .    .    .    .    .    .    .    .  .   stur	q10, [x0, #-32]
        // [0,17]    .    .    .    .    .    .   DE    .    .    .    .    .    .    .    .    .    .    .  .   stur	q11, [x0, #-16]
        // [1,0]     .    .    .    .    .    .   DeeE  .    .    .    .    .    .    .    .    .    .    .  .   ldr	q8, [x0]
        // [1,1]     .    .    .    .    .    .    DeeE .    .    .    .    .    .    .    .    .    .    .  .   ldr	q9, [x0, #16]
        // [1,2]     .    .    .    .    .    .    .DeeE.    .    .    .    .    .    .    .    .    .    .  .   ldr	q10, [x0, #32]
        // [1,3]     .    .    .    .    .    .    . DeeE    .    .    .    .    .    .    .    .    .    .  .   ldr	q11, [x0, #48]
        // [1,4]     .    .    .    .    .    .    .  DeeeE  .    .    .    .    .    .    .    .    .    .  .   mul.8h	v12, v9, v0[0]
        // [1,5]     .    .    .    .    .    .    .   DeeeE .    .    .    .    .    .    .    .    .    .  .   sqrdmulh.8h	v9, v9, v0[1]
        // [1,6]     .    .    .    .    .    .    .    .  DeeeE  .    .    .    .    .    .    .    .    .  .   mls.8h	v12, v9, v1[0]
        // [1,7]     .    .    .    .    .    .    .    .    . DeE.    .    .    .    .    .    .    .    .  .   sub.8h	v9, v8, v12
        // [1,8]     .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .    .    .  .   add.8h	v8, v8, v12
        // [1,9]     .    .    .    .    .    .    .    .    .   DeeeE .    .    .    .    .    .    .    .  .   mul.8h	v12, v11, v0[0]
        // [1,10]    .    .    .    .    .    .    .    .    .    DeeeE.    .    .    .    .    .    .    .  .   sqrdmulh.8h	v11, v11, v0[1]
        // [1,11]    .    .    .    .    .    .    .    .    .    .   DeeeE .    .    .    .    .    .    .  .   mls.8h	v12, v11, v1[0]
        // [1,12]    .    .    .    .    .    .    .    .    .    .    .  DeE    .    .    .    .    .    .  .   sub.8h	v11, v10, v12
        // [1,13]    .    .    .    .    .    .    .    .    .    .    .   DeE   .    .    .    .    .    .  .   add.8h	v10, v10, v12
        // [1,14]    .    .    .    .    .    .    .    .    .    .    .    DE   .    .    .    .    .    .  .   str	q8, [x0], #64
        // [1,15]    .    .    .    .    .    .    .    .    .    .    .    .DE  .    .    .    .    .    .  .   stur	q9, [x0, #-48]
        // [1,16]    .    .    .    .    .    .    .    .    .    .    .    . DE .    .    .    .    .    .  .   stur	q10, [x0, #-32]
        // [1,17]    .    .    .    .    .    .    .    .    .    .    .    .  DE.    .    .    .    .    .  .   stur	q11, [x0, #-16]
        // [2,0]     .    .    .    .    .    .    .    .    .    .    .    .  DeeE   .    .    .    .    .  .   ldr	q8, [x0]
        // [2,1]     .    .    .    .    .    .    .    .    .    .    .    .   DeeE  .    .    .    .    .  .   ldr	q9, [x0, #16]
        // [2,2]     .    .    .    .    .    .    .    .    .    .    .    .    DeeE .    .    .    .    .  .   ldr	q10, [x0, #32]
        // [2,3]     .    .    .    .    .    .    .    .    .    .    .    .    .DeeE.    .    .    .    .  .   ldr	q11, [x0, #48]
        // [2,4]     .    .    .    .    .    .    .    .    .    .    .    .    . DeeeE   .    .    .    .  .   mul.8h	v12, v9, v0[0]
        // [2,5]     .    .    .    .    .    .    .    .    .    .    .    .    .  DeeeE  .    .    .    .  .   sqrdmulh.8h	v9, v9, v0[1]
        // [2,6]     .    .    .    .    .    .    .    .    .    .    .    .    .    . DeeeE   .    .    .  .   mls.8h	v12, v9, v1[0]
        // [2,7]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DeE .    .    .  .   sub.8h	v9, v8, v12
        // [2,8]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.    .    .  .   add.8h	v8, v8, v12
        // [2,9]     .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeeE  .    .  .   mul.8h	v12, v11, v0[0]
        // [2,10]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DeeeE .    .  .   sqrdmulh.8h	v11, v11, v0[1]
        // [2,11]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeeeE  .  .   mls.8h	v12, v11, v1[0]
        // [2,12]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DeE.  .   sub.8h	v11, v10, v12
        // [2,13]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .  DeE  .   add.8h	v10, v10, v12
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .   DE  .   str	q8, [x0], #64
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    DE .   stur	q9, [x0, #-48]
        // [2,16]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .DE.   stur	q10, [x0, #-32]
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    .    . DE   stur	q11, [x0, #-16]
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	q8, [x0]
        // 1.     3     0.0    0.0    0.0       ldr	q9, [x0, #16]
        // 2.     3     0.0    0.0    0.0       ldr	q10, [x0, #32]
        // 3.     3     0.0    0.0    0.0       ldr	q11, [x0, #48]
        // 4.     3     0.0    0.0    0.0       mul.8h	v12, v9, v0[0]
        // 5.     3     0.0    0.0    0.0       sqrdmulh.8h	v9, v9, v0[1]
        // 6.     3     0.0    0.0    0.0       mls.8h	v12, v9, v1[0]
        // 7.     3     0.0    0.0    0.0       sub.8h	v9, v8, v12
        // 8.     3     0.0    0.0    0.0       add.8h	v8, v8, v12
        // 9.     3     0.0    0.0    0.0       mul.8h	v12, v11, v0[0]
        // 10.    3     0.0    0.0    0.0       sqrdmulh.8h	v11, v11, v0[1]
        // 11.    3     0.0    0.0    0.0       mls.8h	v12, v11, v1[0]
        // 12.    3     0.0    0.0    0.0       sub.8h	v11, v10, v12
        // 13.    3     0.0    0.0    0.0       add.8h	v10, v10, v12
        // 14.    3     0.0    0.0    0.0       str	q8, [x0], #64
        // 15.    3     0.0    0.0    0.0       stur	q9, [x0, #-48]
        // 16.    3     0.0    0.0    0.0       stur	q10, [x0, #-32]
        // 17.    3     0.0    0.0    0.0       stur	q11, [x0, #-16]
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (ORIGINAL) END
        //
        //
        // LLVM MCA STATISTICS (OPTIMIZED) BEGIN
        //
        //
        // [0] Code Region
        //
        // Iterations:        100
        // Instructions:      1800
        // Total Cycles:      1803
        // Total uOps:        1900
        //
        // Dispatch Width:    2
        // uOps Per Cycle:    1.05
        // IPC:               1.00
        // Block RThroughput: 10.0
        //
        //
        // Resources:
        // [0.0] - CortexA55UnitALU
        // [0.1] - CortexA55UnitALU
        // [1]   - CortexA55UnitB
        // [2]   - CortexA55UnitDiv
        // [3.0] - CortexA55UnitFPALU
        // [3.1] - CortexA55UnitFPALU
        // [4]   - CortexA55UnitFPDIV
        // [5.0] - CortexA55UnitFPMAC
        // [5.1] - CortexA55UnitFPMAC
        // [6]   - CortexA55UnitLd
        // [7]   - CortexA55UnitMAC
        // [8]   - CortexA55UnitSt
        //
        //
        // Resource pressure per iteration:
        // [0.0]  [0.1]  [1]    [2]    [3.0]  [3.1]  [4]    [5.0]  [5.1]  [6]    [7]    [8]
        //  -      -      -      -     10.00  10.00   -      -      -     4.00    -     4.00
        //
        // Resource pressure by instruction:
        // [0.0]  [0.1]  [1]    [2]    [3.0]  [3.1]  [4]    [5.0]  [5.1]  [6]    [7]    [8]    Instructions:
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q25, [x0, #48]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     sqrdmulh.8h	v11, v31, v0[1]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q12, [x0]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     mul.8h	v3, v25, v0[0]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     sqrdmulh.8h	v31, v25, v0[1]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     mls.8h	v4, v11, v1[0]
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q25, [x0, #32]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     mls.8h	v3, v31, v1[0]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     sub.8h	v23, v12, v4
        //  -      -      -      -      -      -      -      -      -     1.00    -      -     ldr	q31, [x0, #80]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     sub.8h	v19, v25, v3
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   str	q23, [x0, #16]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     add.8h	v3, v25, v3
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   str	q19, [x0, #48]
        //  -      -      -      -      -     2.00    -      -      -      -      -      -     add.8h	v25, v12, v4
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   str	q3, [x0, #32]
        //  -      -      -      -     2.00    -      -      -      -      -      -      -     mul.8h	v4, v31, v0[0]
        //  -      -      -      -      -      -      -      -      -      -      -     1.00   str	q25, [x0], #64
        //
        //
        // Timeline view:
        //                     0123456789          0123456789          0123456
        // Index     0123456789          0123456789          0123456789
        //
        // [0,0]     DeeE .    .    .    .    .    .    .    .    .    .    ..   ldr	q25, [x0, #48]
        // [0,1]     .DeeeE    .    .    .    .    .    .    .    .    .    ..   sqrdmulh.8h	v11, v31, v0[1]
        // [0,2]     . DeeE    .    .    .    .    .    .    .    .    .    ..   ldr	q12, [x0]
        // [0,3]     .  DeeeE  .    .    .    .    .    .    .    .    .    ..   mul.8h	v3, v25, v0[0]
        // [0,4]     .   DeeeE .    .    .    .    .    .    .    .    .    ..   sqrdmulh.8h	v31, v25, v0[1]
        // [0,5]     .    DeeeE.    .    .    .    .    .    .    .    .    ..   mls.8h	v4, v11, v1[0]
        // [0,6]     .    .DeeE.    .    .    .    .    .    .    .    .    ..   ldr	q25, [x0, #32]
        // [0,7]     .    .  DeeeE  .    .    .    .    .    .    .    .    ..   mls.8h	v3, v31, v1[0]
        // [0,8]     .    .    DeE  .    .    .    .    .    .    .    .    ..   sub.8h	v23, v12, v4
        // [0,9]     .    .    DeeE .    .    .    .    .    .    .    .    ..   ldr	q31, [x0, #80]
        // [0,10]    .    .    . DeE.    .    .    .    .    .    .    .    ..   sub.8h	v19, v25, v3
        // [0,11]    .    .    . DE .    .    .    .    .    .    .    .    ..   str	q23, [x0, #16]
        // [0,12]    .    .    .  DeE    .    .    .    .    .    .    .    ..   add.8h	v3, v25, v3
        // [0,13]    .    .    .   DE    .    .    .    .    .    .    .    ..   str	q19, [x0, #48]
        // [0,14]    .    .    .    DeE  .    .    .    .    .    .    .    ..   add.8h	v25, v12, v4
        // [0,15]    .    .    .    DE   .    .    .    .    .    .    .    ..   str	q3, [x0, #32]
        // [0,16]    .    .    .    .DeeeE    .    .    .    .    .    .    ..   mul.8h	v4, v31, v0[0]
        // [0,17]    .    .    .    . DE .    .    .    .    .    .    .    ..   str	q25, [x0], #64
        // [1,0]     .    .    .    .  DeeE   .    .    .    .    .    .    ..   ldr	q25, [x0, #48]
        // [1,1]     .    .    .    .   DeeeE .    .    .    .    .    .    ..   sqrdmulh.8h	v11, v31, v0[1]
        // [1,2]     .    .    .    .    DeeE .    .    .    .    .    .    ..   ldr	q12, [x0]
        // [1,3]     .    .    .    .    .DeeeE    .    .    .    .    .    ..   mul.8h	v3, v25, v0[0]
        // [1,4]     .    .    .    .    . DeeeE   .    .    .    .    .    ..   sqrdmulh.8h	v31, v25, v0[1]
        // [1,5]     .    .    .    .    .  DeeeE  .    .    .    .    .    ..   mls.8h	v4, v11, v1[0]
        // [1,6]     .    .    .    .    .   DeeE  .    .    .    .    .    ..   ldr	q25, [x0, #32]
        // [1,7]     .    .    .    .    .    .DeeeE    .    .    .    .    ..   mls.8h	v3, v31, v1[0]
        // [1,8]     .    .    .    .    .    .  DeE    .    .    .    .    ..   sub.8h	v23, v12, v4
        // [1,9]     .    .    .    .    .    .  DeeE   .    .    .    .    ..   ldr	q31, [x0, #80]
        // [1,10]    .    .    .    .    .    .    DeE  .    .    .    .    ..   sub.8h	v19, v25, v3
        // [1,11]    .    .    .    .    .    .    DE   .    .    .    .    ..   str	q23, [x0, #16]
        // [1,12]    .    .    .    .    .    .    .DeE .    .    .    .    ..   add.8h	v3, v25, v3
        // [1,13]    .    .    .    .    .    .    . DE .    .    .    .    ..   str	q19, [x0, #48]
        // [1,14]    .    .    .    .    .    .    .  DeE    .    .    .    ..   add.8h	v25, v12, v4
        // [1,15]    .    .    .    .    .    .    .  DE.    .    .    .    ..   str	q3, [x0, #32]
        // [1,16]    .    .    .    .    .    .    .   DeeeE .    .    .    ..   mul.8h	v4, v31, v0[0]
        // [1,17]    .    .    .    .    .    .    .    DE   .    .    .    ..   str	q25, [x0], #64
        // [2,0]     .    .    .    .    .    .    .    .DeeE.    .    .    ..   ldr	q25, [x0, #48]
        // [2,1]     .    .    .    .    .    .    .    . DeeeE   .    .    ..   sqrdmulh.8h	v11, v31, v0[1]
        // [2,2]     .    .    .    .    .    .    .    .  DeeE   .    .    ..   ldr	q12, [x0]
        // [2,3]     .    .    .    .    .    .    .    .   DeeeE .    .    ..   mul.8h	v3, v25, v0[0]
        // [2,4]     .    .    .    .    .    .    .    .    DeeeE.    .    ..   sqrdmulh.8h	v31, v25, v0[1]
        // [2,5]     .    .    .    .    .    .    .    .    .DeeeE    .    ..   mls.8h	v4, v11, v1[0]
        // [2,6]     .    .    .    .    .    .    .    .    . DeeE    .    ..   ldr	q25, [x0, #32]
        // [2,7]     .    .    .    .    .    .    .    .    .   DeeeE .    ..   mls.8h	v3, v31, v1[0]
        // [2,8]     .    .    .    .    .    .    .    .    .    .DeE .    ..   sub.8h	v23, v12, v4
        // [2,9]     .    .    .    .    .    .    .    .    .    .DeeE.    ..   ldr	q31, [x0, #80]
        // [2,10]    .    .    .    .    .    .    .    .    .    .  DeE    ..   sub.8h	v19, v25, v3
        // [2,11]    .    .    .    .    .    .    .    .    .    .  DE.    ..   str	q23, [x0, #16]
        // [2,12]    .    .    .    .    .    .    .    .    .    .   DeE   ..   add.8h	v3, v25, v3
        // [2,13]    .    .    .    .    .    .    .    .    .    .    DE   ..   str	q19, [x0, #48]
        // [2,14]    .    .    .    .    .    .    .    .    .    .    .DeE ..   add.8h	v25, v12, v4
        // [2,15]    .    .    .    .    .    .    .    .    .    .    .DE  ..   str	q3, [x0, #32]
        // [2,16]    .    .    .    .    .    .    .    .    .    .    . DeeeE   mul.8h	v4, v31, v0[0]
        // [2,17]    .    .    .    .    .    .    .    .    .    .    .  DE..   str	q25, [x0], #64
        //
        //
        // Average Wait times (based on the timeline view):
        // [0]: Executions
        // [1]: Average time spent waiting in a scheduler's queue
        // [2]: Average time spent waiting in a scheduler's queue while ready
        // [3]: Average time elapsed from WB until retire stage
        //
        //       [0]    [1]    [2]    [3]
        // 0.     3     0.0    0.0    0.0       ldr	q25, [x0, #48]
        // 1.     3     0.0    0.0    0.0       sqrdmulh.8h	v11, v31, v0[1]
        // 2.     3     0.0    0.0    0.0       ldr	q12, [x0]
        // 3.     3     0.0    0.0    0.0       mul.8h	v3, v25, v0[0]
        // 4.     3     0.0    0.0    0.0       sqrdmulh.8h	v31, v25, v0[1]
        // 5.     3     0.0    0.0    0.0       mls.8h	v4, v11, v1[0]
        // 6.     3     0.0    0.0    0.0       ldr	q25, [x0, #32]
        // 7.     3     0.0    0.0    0.0       mls.8h	v3, v31, v1[0]
        // 8.     3     0.0    0.0    0.0       sub.8h	v23, v12, v4
        // 9.     3     0.0    0.0    0.0       ldr	q31, [x0, #80]
        // 10.    3     0.0    0.0    0.0       sub.8h	v19, v25, v3
        // 11.    3     0.0    0.0    0.0       str	q23, [x0, #16]
        // 12.    3     0.0    0.0    0.0       add.8h	v3, v25, v3
        // 13.    3     0.0    0.0    0.0       str	q19, [x0, #48]
        // 14.    3     0.0    0.0    0.0       add.8h	v25, v12, v4
        // 15.    3     0.0    0.0    0.0       str	q3, [x0, #32]
        // 16.    3     0.0    0.0    0.0       mul.8h	v4, v31, v0[0]
        // 17.    3     0.0    0.0    0.0       str	q25, [x0], #64
        //        3     0.0    0.0    0.0       <total>
        //
        //
        // ORIGINAL LLVM MCA STATISTICS (OPTIMIZED) END
        //
        sub count, count, #1
        cbnz count, start
        ldr q25, [x0, #48]
        sqrdmulh v11.8H, v31.8H, v0.H[1]
        ldr q12, [x0, #0]
        mul v3.8H, v25.8H, v0.H[0]
        sqrdmulh v31.8H, v25.8H, v0.H[1]
        mls v4.8H, v11.8H, v1.H[0]
        ldr q25, [x0, #32]
        mls v3.8H, v31.8H, v1.H[0]
        sub v23.8H, v12.8H, v4.8H
        sub v19.8H, v25.8H, v3.8H
        str q23, [x0, #16]
        add v3.8H, v25.8H, v3.8H
        str q19, [x0, #48]
        add v25.8H, v12.8H, v4.8H
        str q3, [x0, #32]
        str q25, [x0], #4*16
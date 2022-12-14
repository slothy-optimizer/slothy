        vldrw.32 q0, [src3]                   // *........
        nop                                   // .......*.
        vldrw.32 q5, [src1]                   // ..*......
        nop                                   // ........*
        vldrw.32 q6, [src0]                   // ...*.....
        vhadd.s32 q3, q5, q0                  // .....*...
        vldrw.32 q1, [src2]                   // .*.......
        vhadd.s32 q4, q6, q1                  // ......*..
        vldrw.32 q7, [twiddle0] , #16         // ....*....
        
        // original source code
        // vldrw.32 q0, [src3]                // *........
        // vldrw.32 q1, [src2]                // ......*..
        // vldrw.32 q5, [src1]                // ..*......
        // vldrw.32 q6, [src0]                // ....*....
        // vldrw.32 q7, [twiddle0] , #16      // ........*
        // vhadd.s32 q3, q5, q0               // .....*...
        // vhadd.s32 q4, q6, q1               // .......*.
        // nop                                // .*.......
        // nop                                // ...*.....
        
        sub lr, lr, #1
        wls lr, lr, fixedpoint_radix4_fft_loop_end
fixedpoint_radix4_fft_loop_start:
        vhadd.s32 q2, q4, q3                  // .........*...............
        vstrw.u32 q2, [src0] , #16            // ..........*..............
        vhsub.s32 q3, q4, q3                  // ...........*.............
        vqdmlsdh.s32 q4, q3, q7               // .............*...........
        vhsub.s32 q5, q5, q0                  // .......*.................
        vldrw.32 q0, [src3, #16]              // .....e...................
        vqdmladhx.s32 q4, q3, q7              // ...............*.........
        vldrw.32 q7, [twiddle2] , #16         // .....................*...
        vhsub.s32 q2, q6, q1                  // ....*....................
        vldrw.32 q1, [src2, #16]              // .e.......................
        vhcadd.s32 q3, q2, q5, #270           // ..............*..........
        vstrw.u32 q4, [src1] , #16            // ................*........
        vhcadd.s32 q6, q2, q5, #90            // ....................*....
        vqdmlsdh.s32 q2, q6, q7               // ......................*..
        vldrw.32 q5, [src1]                   // ...e.....................
        vqdmladhx.s32 q2, q6, q7              // .......................*.
        vldrw.32 q7, [twiddle1] , #16         // ........*................
        vqdmlsdh.s32 q4, q3, q7               // .................*.......
        vldrw.32 q6, [src0]                   // e........................
        vqdmladhx.s32 q4, q3, q7              // ..................*......
        vldrw.32 q7, [twiddle0] , #16         // ............e............
        vhadd.s32 q3, q5, q0                  // ......e..................
        vstrw.u32 q4, [src2] , #16            // ...................*.....
        vhadd.s32 q4, q6, q1                  // ..e......................
        vstrw.u32 q2, [src3] , #16            // ........................*
        
        // original source code
        // vldrw.32 q1, [src0]                // .............e...............................
        // vldrw.32 q6, [src2]                // ....e........................................
        // vhadd.s32 q0, q1, q6               // ..................e..........................
        // vldrw.32 q4, [src1]                // .........e...................................
        // vhsub.s32 q2, q1, q6               // ............................*................
        // vldrw.32 q5, [src3]                // e............................................
        // vhadd.s32 q1, q4, q5               // ................e............................
        // vhsub.s32 q3, q4, q5               // ........................*....................
        // vldrw.32 q7, [twiddle1] , #16      // ....................................*........
        // vhadd.s32 q4, q0, q1               // ....................*........................
        // vstrw.u32 q4, [src0] , #16         // .....................*.......................
        // vhsub.s32 q4, q0, q1               // ......................*......................
        // vldrw.32 q5, [twiddle0] , #16      // ...............e.............................
        // vqdmlsdh.s32 q0, q4, q5            // .......................*.....................
        // vhcadd.s32 q6, q2, q3, #270        // ..............................*..............
        // vqdmladhx.s32 q0, q4, q5           // ..........................*..................
        // vstrw.u32 q0, [src1] , #16         // ...............................*.............
        // vqdmlsdh.s32 q0, q6, q7            // .....................................*.......
        // vqdmladhx.s32 q0, q6, q7           // .......................................*.....
        // vstrw.u32 q0, [src2] , #16         // ..........................................*..
        // vhcadd.s32 q4, q2, q3, #90         // ................................*............
        // vldrw.32 q5, [twiddle2] , #16      // ...........................*.................
        // vqdmlsdh.s32 q0, q4, q5            // .................................*...........
        // vqdmladhx.s32 q0, q4, q5           // ...................................*.........
        // vstrw.u32 q0, [src3] , #16         // ............................................*
        
        le lr, fixedpoint_radix4_fft_loop_start
fixedpoint_radix4_fft_loop_end:
        vhadd.s32 q2, q4, q3                  // *.................
        vstrw.u32 q2, [src0] , #16            // .*................
        vhsub.s32 q3, q4, q3                  // ..*...............
        vqdmlsdh.s32 q4, q3, q7               // ...*..............
        vhsub.s32 q5, q5, q0                  // ....*.............
        vqdmladhx.s32 q4, q3, q7              // .....*............
        vhsub.s32 q2, q6, q1                  // .......*..........
        vldrw.32 q7, [twiddle1] , #16         // .............*....
        vhcadd.s32 q3, q2, q5, #270           // ........*.........
        vstrw.u32 q4, [src1] , #16            // .........*........
        vqdmlsdh.s32 q4, q3, q7               // ..............*...
        vhcadd.s32 q6, q2, q5, #90            // ..........*.......
        vqdmladhx.s32 q4, q3, q7              // ...............*..
        vldrw.32 q7, [twiddle2] , #16         // ......*...........
        vqdmlsdh.s32 q2, q6, q7               // ...........*......
        vstrw.u32 q4, [src2] , #16            // ................*.
        vqdmladhx.s32 q2, q6, q7              // ............*.....
        vstrw.u32 q2, [src3] , #16            // .................*
        
        // original source code
        // vhadd.s32 q2, q4, q3               // *.................
        // vstrw.u32 q2, [src0] , #16         // .*................
        // vhsub.s32 q3, q4, q3               // ..*...............
        // vqdmlsdh.s32 q4, q3, q7            // ...*..............
        // vhsub.s32 q5, q5, q0               // ....*.............
        // vqdmladhx.s32 q4, q3, q7           // .....*............
        // vldrw.32 q7, [twiddle2] , #16      // .............*....
        // vhsub.s32 q2, q6, q1               // ......*...........
        // vhcadd.s32 q3, q2, q5, #270        // ........*.........
        // vstrw.u32 q4, [src1] , #16         // .........*........
        // vhcadd.s32 q6, q2, q5, #90         // ...........*......
        // vqdmlsdh.s32 q2, q6, q7            // ..............*...
        // vqdmladhx.s32 q2, q6, q7           // ................*.
        // vldrw.32 q7, [twiddle1] , #16      // .......*..........
        // vqdmlsdh.s32 q4, q3, q7            // ..........*.......
        // vqdmladhx.s32 q4, q3, q7           // ............*.....
        // vstrw.u32 q4, [src2] , #16         // ...............*..
        // vstrw.u32 q2, [src3] , #16         // .................*
        

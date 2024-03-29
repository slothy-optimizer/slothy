        vld20.32 {q3,q4}, [r0]          // .*.
        // gap                          // ...
        vld20.32 {q6,q7}, [r0]          // *..
        // gap                          // ...
        vld21.32 {q3,q4}, [r0]!         // ..*
        
        // original source code
        // vld20.32 {q6,q7}, [r0]       // .*. 
        // vld20.32 {q3,q4}, [r0]       // *.. 
        // vld21.32 {q3,q4}, [r0]!      // ..* 
        
        sub lr, lr, #1
.p2align 2
start:
        vld21.32 {q6,q7}, [r0]!          // .............*..........
        vmul.f32 q5, q4, q4              // .........*..............
        vld20.32 {q0,q1}, [r0]           // *.......................
        vmul.f32 q2, q3, q3              // ........*...............
        vld20.32 {q3,q4}, [r0]           // ..................*.....
        vmul.f32 q6, q6, q6              // ..............*.........
        vadd.f32 q5, q5, q2              // ..........*.............
        vmul.f32 q7, q7, q7              // ...............*........
        vld21.32 {q3,q4}, [r0]!          // ...................*....
        vstrw.u32 q5, [r6] , #16         // ...........*............
        vadd.f32 q2, q7, q6              // ................*.......
        vld20.32 {q6,q7}, [r0]           // ............e...........
        vmul.f32 q5, q3, q3              // ....................*...
        vld21.32 {q0,q1}, [r0]!          // .*......................
        vstrw.u32 q2, [r6] , #16         // .................*......
        vmul.f32 q2, q4, q4              // .....................*..
        vld20.32 {q3,q4}, [r0]           // ......e.................
        vmul.f32 q1, q1, q1              // ...*....................
        vadd.f32 q2, q2, q5              // ......................*.
        vmul.f32 q0, q0, q0              // ..*.....................
        vstrw.u32 q2, [r6] , #16         // .......................*
        vld21.32 {q3,q4}, [r0]!          // .......e................
        vadd.f32 q5, q1, q0              // ....*...................
        vstrw.u32 q5, [r6] , #16         // .....*..................
        
        // original source code
        // vld20.32 {qr,qi}, [in]           // ...............*..................... 
        // vld21.32 {qr,qi}, [in]!          // ..........................*.......... 
        // vmul.f32 qtmp, qr, qr            // ................................*.... 
        // vmul.f32 qout, qi, qi            // ..............................*...... 
        // vadd.f32 qout, qout, qtmp        // ...................................*. 
        // vstrw.u32 qout, [out] , #16      // ....................................* 
        // vld20.32 {qr,qi}, [in]           // .....e............................... 
        // vld21.32 {qr,qi}, [in]!          // ..........e.......................... 
        // vmul.f32 qtmp, qr, qr            // ................*.................... 
        // vmul.f32 qout, qi, qi            // ..............*...................... 
        // vadd.f32 qout, qout, qtmp        // ...................*................. 
        // vstrw.u32 qout, [out] , #16      // ......................*.............. 
        // vld20.32 {qr,qi}, [in]           // e.................................... 
        // vld21.32 {qr,qi}, [in]!          // .............*....................... 
        // vmul.f32 qtmp, qr, qr            // ..................*.................. 
        // vmul.f32 qout, qi, qi            // ....................*................ 
        // vadd.f32 qout, qout, qtmp        // .......................*............. 
        // vstrw.u32 qout, [out] , #16      // ...........................*......... 
        // vld20.32 {qr,qi}, [in]           // .................*................... 
        // vld21.32 {qr,qi}, [in]!          // .....................*............... 
        // vmul.f32 qtmp, qr, qr            // .........................*........... 
        // vmul.f32 qout, qi, qi            // ............................*........ 
        // vadd.f32 qout, qout, qtmp        // ...............................*..... 
        // vstrw.u32 qout, [out] , #16      // .................................*... 
        
        le lr, start
        vld21.32 {q6,q7}, [r0]!          // *....................
        vmul.f32 q2, q3, q3              // ...*.................
        vld20.32 {q0,q1}, [r0]           // ....*................
        vmul.f32 q5, q4, q4              // .*...................
        vld20.32 {q3,q4}, [r0]           // ..*..................
        vmul.f32 q7, q7, q7              // .......*.............
        vld21.32 {q0,q1}, [r0]!          // ........*............
        vmul.f32 q6, q6, q6              // .....*...............
        vld21.32 {q3,q4}, [r0]!          // ............*........
        vadd.f32 q2, q5, q2              // ......*..............
        vmul.f32 q5, q1, q1              // ..............*......
        vadd.f32 q6, q7, q6              // ..........*..........
        vmul.f32 q7, q0, q0              // ...........*.........
        vstrw.u32 q2, [r6] , #16         // .........*...........
        vmul.f32 q1, q3, q3              // .................*...
        vstrw.u32 q6, [r6] , #16         // .............*.......
        vmul.f32 q6, q4, q4              // ...............*.....
        vadd.f32 q4, q5, q7              // ................*....
        vstrw.u32 q4, [r6] , #16         // ..................*..
        vadd.f32 q1, q6, q1              // ...................*.
        vstrw.u32 q1, [r6] , #16         // ....................*
        
        // original source code
        // vld21.32 {q6,q7}, [r0]!       // *.................... 
        // vmul.f32 q5, q4, q4           // ...*................. 
        // vld20.32 {q0,q1}, [r0]        // ....*................ 
        // vmul.f32 q2, q3, q3           // .*................... 
        // vld20.32 {q3,q4}, [r0]        // ..*.................. 
        // vmul.f32 q6, q6, q6           // .......*............. 
        // vadd.f32 q5, q5, q2           // .........*........... 
        // vmul.f32 q7, q7, q7           // .....*............... 
        // vld21.32 {q3,q4}, [r0]!       // ......*.............. 
        // vstrw.u32 q5, [r6] , #16      // .............*....... 
        // vadd.f32 q2, q7, q6           // ...........*......... 
        // vmul.f32 q5, q3, q3           // ............*........ 
        // vld21.32 {q0,q1}, [r0]!       // ........*............ 
        // vstrw.u32 q2, [r6] , #16      // ...............*..... 
        // vmul.f32 q2, q4, q4           // ..........*.......... 
        // vmul.f32 q1, q1, q1           // ................*.... 
        // vadd.f32 q2, q2, q5           // .................*... 
        // vmul.f32 q0, q0, q0           // ..............*...... 
        // vstrw.u32 q2, [r6] , #16      // ..................*.. 
        // vadd.f32 q5, q1, q0           // ...................*. 
        // vstrw.u32 q5, [r6] , #16      // ....................* 
        

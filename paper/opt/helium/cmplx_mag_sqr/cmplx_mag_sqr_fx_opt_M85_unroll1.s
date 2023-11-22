        .syntax unified
        .type   cmplx_mag_sqr_fx_opt_M85_unroll1, %function
        .global cmplx_mag_sqr_fx_opt_M85_unroll1

        .text
        .align 4
cmplx_mag_sqr_fx_opt_M85_unroll1:
        push {r4-r12,lr}
        vpush {d0-d15}

        out   .req r0
        in    .req r1
        sz    .req r2

        lsr lr, sz, #2
        wls lr, lr, end
.p2align 2
        vld20.32 {q2,q3}, [r1]          // *...
        // gap                          // ....
        vld21.32 {q2,q3}, [r1]!         // .*..
        // gap                          // ....
        // gap                          // ....
        // gap                          // ....
        vmulh.s32 q6, q2, q2            // ..*.
        // gap                          // ....
        vmulh.s32 q7, q3, q3            // ...*
        
        // original source code
        // vld20.32 {q4,q5}, [r1]       // *... 
        // vld21.32 {q4,q5}, [r1]!      // .*.. 
        // vmulh.s32 q6, q4, q4         // ..*. 
        // vmulh.s32 q7, q5, q5         // ...* 
        
        sub lr, lr, #1
.p2align 2
start:
        vld20.32 {q4,q5}, [r1]           // e.....
        vhadd.s32 q0, q7, q6             // ....*.
        vld21.32 {q4,q5}, [r1]!          // .e....
        // gap                           // ......
        vstrw.u32 q0, [r0] , #16         // .....*
        // gap                           // ......
        vmulh.s32 q6, q4, q4             // ..e...
        // gap                           // ......
        vmulh.s32 q7, q5, q5             // ...e..
        
        // original source code
        // vld20.32 {q6,q7}, [r1]        // e......... 
        // vld21.32 {q6,q7}, [r1]!       // ..e....... 
        // vmulh.s32 q2, q6, q6          // ....e..... 
        // vmulh.s32 q3, q7, q7          // .....e.... 
        // vhadd.s32 q1, q3, q2          // .......*.. 
        // vstrw.u32 q1, [r0] , #16      // .........* 
        
        le lr, start
        vhadd.s32 q4, q7, q6             // *.
        vstrw.u32 q4, [r0] , #16         // .*
        
        // original source code
        // vhadd.s32 q0, q7, q6          // *. 
        // vstrw.u32 q0, [r0] , #16      // .* 
        
end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
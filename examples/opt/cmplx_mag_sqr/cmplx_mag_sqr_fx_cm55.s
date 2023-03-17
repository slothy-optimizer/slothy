        .syntax unified
        .type   cmplx_mag_sqr_fx_opt_m55, %function
        .global cmplx_mag_sqr_fx_opt_m55

        .text
        .align 4
cmplx_mag_sqr_fx_opt_m55:
        push {r4-r12,lr}
        vpush {d0-d15}

        out   .req r0
        in    .req r1
        sz    .req r2

        qr   .req q0
        qi   .req q1
        qtmp .req q2
        qout .req q3

        lsr lr, sz, #2
        wls lr, lr, end
        vld20.32 {q3,q4}, [r1]          // *...
        // gap                          // ....
        vld21.32 {q3,q4}, [r1]!         // .*..
        vmulh.s32 q3, q3, q3            // ..*.
        // gap                          // ....
        vmulh.s32 q1, q4, q4            // ...*
        
        // original source code
        // vld20.32 {q4,q5}, [r1]       // *... 
        // vld21.32 {q4,q5}, [r1]!      // .*.. 
        // vmulh.s32 q3, q4, q4         // ..*. 
        // vmulh.s32 q1, q5, q5         // ...* 
        
        sub lr, lr, #1
.p2align 2
start:
        vld20.32 {q4,q5}, [r1]           // e.....
        vhadd.s32 q1, q1, q3             // ....*.
        vld21.32 {q4,q5}, [r1]!          // .e....
        vmulh.s32 q3, q4, q4             // ..e...
        vstrw.u32 q1, [r0] , #16         // .....*
        vmulh.s32 q1, q5, q5             // ...e..
        // gap                           // ......
        
        // original source code
        // vld20.32 {q0,q1}, [r1]        // e.......... 
        // vld21.32 {q0,q1}, [r1]!       // ..e........ 
        // vmulh.s32 q2, q0, q0          // ...e....... 
        // vmulh.s32 q3, q1, q1          // .....e..... 
        // vhadd.s32 q3, q3, q2          // .......*... 
        // vstrw.u32 q3, [r0] , #16      // ..........* 
        
        le lr, start
        vhadd.s32 q3, q1, q3             // *.
        vstrw.u32 q3, [r0] , #16         // .*
        
        // original source code
        // vhadd.s32 q1, q1, q3          // *. 
        // vstrw.u32 q1, [r0] , #16      // .* 
        
end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
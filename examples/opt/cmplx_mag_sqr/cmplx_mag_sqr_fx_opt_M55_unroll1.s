        .syntax unified
        .type   cmplx_mag_sqr_fx_opt_M55_unroll1, %function
        .global cmplx_mag_sqr_fx_opt_M55_unroll1

        .text
        .align 4
cmplx_mag_sqr_fx_opt_M55_unroll1:
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
        vld20.32 {q4,q5}, [r1]          // *.
        // gap                          // ..
        vld21.32 {q4,q5}, [r1]!         // .*
        
        // original source code
        // vld20.32 {q4,q5}, [r1]       // *. 
        // vld21.32 {q4,q5}, [r1]!      // .* 
        
        sub lr, lr, #1
.p2align 2
start:
        vmulh.s32 q3, q5, q5             // ...*..
        // gap                           // ......
        vmulh.s32 q1, q4, q4             // ..*...
        vld20.32 {q4,q5}, [r1]           // e.....
        vhadd.s32 q1, q3, q1             // ....*.
        vld21.32 {q4,q5}, [r1]!          // .e....
        // gap                           // ......
        vstrw.u32 q1, [r0] , #16         // .....*
        
        // original source code
        // vld20.32 {q0,q1}, [r1]        // e......... 
        // vld21.32 {q0,q1}, [r1]!       // ..e....... 
        // vmulh.s32 q2, q0, q0          // .....*.... 
        // vmulh.s32 q3, q1, q1          // ....*..... 
        // vhadd.s32 q3, q3, q2          // .......*.. 
        // vstrw.u32 q3, [r0] , #16      // .........* 
        
        le lr, start
        vmulh.s32 q1, q5, q5             // *...
        // gap                           // ....
        vmulh.s32 q5, q4, q4             // .*..
        // gap                           // ....
        vhadd.s32 q5, q1, q5             // ..*.
        vstrw.u32 q5, [r0] , #16         // ...*
        
        // original source code
        // vmulh.s32 q3, q5, q5          // *... 
        // vmulh.s32 q1, q4, q4          // .*.. 
        // vhadd.s32 q1, q3, q1          // ..*. 
        // vstrw.u32 q1, [r0] , #16      // ...* 
        
end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
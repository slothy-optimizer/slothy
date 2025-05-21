        .syntax unified
        .type   cmplx_mag_sqr_fx, %function
        .global cmplx_mag_sqr_fx

        .text
        .align 4
cmplx_mag_sqr_fx:
        push {r4-r12,lr}
        vpush {d0-d15}

        out   .req r0
        in    .req r1
        sz    .req r2

        lsr lr, sz, #2
        wls lr, lr, end
.p2align 2
start:
        vld20.32 {q4,q5}, [r1]
        vld21.32 {q4,q5}, [r1]!
        vmulh.s32 q2, q4, q4
        vmulh.s32 q4, q5, q5
        vhadd.s32 q4, q4, q2
        vstrw.u32 q4, [r0] , #16
        le lr, start
end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
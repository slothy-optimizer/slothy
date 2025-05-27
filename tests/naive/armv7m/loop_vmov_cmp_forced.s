/* For example, r5 represents an address where we will stop iterating and r6 is
the actual pointer which is incremented inside the loop.

In this specific example, the vmov shall not be accounted towards the loop
boundary but rather the body. */

mov.w r6, #0
add.w r5, r6, #64
vmov s0, r5

start:
    add r6, r6, #4
    vmov r5, s0
    cmp r6, r5
    bne start
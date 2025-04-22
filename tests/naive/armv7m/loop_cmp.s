/* For example, r5 represents an address where we will stop iterating and r6 is
the actual pointer which is incremented inside the loop. */

mov.w r6, #0
add.w r5, r6, #64

start:
    add r6, r6, #4
    cmp.w r6, r5
    bne.w start
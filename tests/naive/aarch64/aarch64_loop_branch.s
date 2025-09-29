cnt .req x2
val .req x1
threshold .req x0

loop:
    add cnt, cnt, #128       // Increment position counter
    // ...
    cmp cnt, threshold         // Compare position vs length
    bls loop


loop2:
    ldr val, [cnt], #128       // Increment position counter
    // ...
    cmp cnt, threshold          // Compare position vs length
    ble loop2                   // Branch if less or equal (signed)

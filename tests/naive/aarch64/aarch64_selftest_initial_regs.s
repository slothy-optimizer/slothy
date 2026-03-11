// Selftest fixture for selftest_initial_register_values.
//
// x0  = pointer to input data (address register, auto-detected)
// x1  = pointer to output data (address register, auto-detected)
// x2  = stride in bytes (contributes to address computation, NOT itself an address)
// x3  = loop counter
//
// x0 and x1 are advanced by x2 each iteration.  The selftest auto-detects
// x0/x1 as address registers but not x2.  Without pinning x2 to a small
// value via selftest_initial_register_values, a random x2 would cause the
// derived addresses to leave the mapped RAM region.

mov x3, #8
start:
    ldr x4, [x0]
    ldr x5, [x1]
    add x4, x4, x5
    str x4, [x1]
    add x0, x0, x2
    add x1, x1, x2
    subs x3, x3, #1
    b.gt start

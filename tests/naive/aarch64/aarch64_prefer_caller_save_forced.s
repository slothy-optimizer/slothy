// Three independent NTT butterflies that all reuse v4, v5 as temporaries
// (WAW hazard between butterflies).  Butterflies 1 and 2 only produce their
// upper outputs (v0, v1); butterfly 3 produces both outputs (v6 upper, v5
// lower).  v0-v3 are inputs/twiddles.
//
// v7 and v16-v31 are reserved in the test config, so the only free
// caller-save scratch registers are v4 and v5.  Overlapping any two
// butterflies for ILP requires four simultaneous temporaries, exhausting the
// two free caller-save slots and forcing SLOTHY to introduce at least one
// callee-saved register (v8-v15) even with prefer_caller_save_registers=True.
start:
    mul      v4.8h, v0.8h, v2.h[0]
    sqrdmulh v5.8h, v0.8h, v2.h[1]
    mls      v4.8h, v5.8h, v3.h[0]
    add      v0.8h, v0.8h, v4.8h
    mul      v4.8h, v1.8h, v2.h[0]
    sqrdmulh v5.8h, v1.8h, v2.h[1]
    mls      v4.8h, v5.8h, v3.h[0]
    add      v1.8h, v1.8h, v4.8h
    mul      v4.8h, v6.8h, v2.h[0]
    sqrdmulh v5.8h, v6.8h, v2.h[1]
    mls      v4.8h, v5.8h, v3.h[0]
    sub      v5.8h, v6.8h, v4.8h
    add      v6.8h, v6.8h, v4.8h
end:

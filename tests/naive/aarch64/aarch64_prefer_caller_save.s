// Two independent NTT butterflies using only caller-save NEON registers (v0-v7).
// With prefer_caller_save_registers=True SLOTHY should not introduce any
// callee-saved register (v8-v15) when renaming the temporaries v4/v5/v6/v7.
start:
    mul      v4.8h, v0.8h, v2.h[0]
    sqrdmulh v5.8h, v0.8h, v2.h[1]
    mls      v4.8h, v5.8h, v3.h[0]
    sub      v5.8h, v0.8h, v4.8h
    add      v0.8h, v0.8h, v4.8h
    mul      v6.8h, v1.8h, v2.h[0]
    sqrdmulh v7.8h, v1.8h, v2.h[1]
    mls      v6.8h, v7.8h, v3.h[0]
    sub      v7.8h, v1.8h, v6.8h
    add      v1.8h, v1.8h, v6.8h
end:
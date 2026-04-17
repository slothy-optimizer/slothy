// NTT butterfly loop using callee-saved NEON regs v8-v12.  The load-use
// latency between ldr and mul/sqrdmulh is long enough on Cortex-A55 that SW
// pipelining moves the loads into the preamble and the stores into the
// postamble, giving non-empty preamble and postamble.  This exercises the
// clobbered-set accumulation across all three parts in Heuristics.periodic().

count .req x3

mov      count, #16
start:
    ldr      q8,  [x0, #0*16]
    ldr      q9,  [x0, #1*16]

    mul      v12.8h, v9.8h,  v0.h[0]
    sqrdmulh v9.8h,  v9.8h,  v0.h[1]
    mls      v12.8h, v9.8h,  v1.h[0]
    sub      v9.8h,  v8.8h,  v12.8h
    add      v8.8h,  v8.8h,  v12.8h

    str      q8,  [x0, #0*16]
    str      q9,  [x0, #1*16]
    add      x0,  x0,  #2*16

    subs     count, count, #1
    cbnz     count, start

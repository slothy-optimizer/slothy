    mov res_lo, #0
    mov res_hi, #0
start:
    vldrw.u32     inA, [ptrA], #16
    vldrw.u32     inB, [ptrB], #16
    vmlaldava.s32 res_lo, res_hi, inA, inB
    vadd.u32      tmp, inA, inB
    vaddva.u32    res_hi, tmp
    le lr, start

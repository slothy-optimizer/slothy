// Small snippet that deliberately uses callee-saved registers (v8, v9, x19).
// Renaming is disabled in the test so the output preserves these exact register
// names; with emit_clobbered_callee_saves_comment=True SLOTHY must prepend a
// comment listing them.
start:
    ldr      q8,  [x0]
    ldr      q9,  [x0, #16]
    ldr      x19, [x0, #32]
    add      v8.4s, v8.4s, v9.4s
    add      x19, x19, x19
    str      q8,  [x1]
    str      x19, [x1, #16]
end:

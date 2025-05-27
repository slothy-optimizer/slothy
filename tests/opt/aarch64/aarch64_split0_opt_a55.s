start:
ldr q0, [x1, #0]
ldr q1, [x2, #0]
eor v5.16B, v1.16B, v2.16B// some comment // @slothy:some_tag
eor v5.16B, v5.16B, v3.16B// some comment // @slothy:some_tag
eor3 v3.16B, v1.16B, v2.16B, v3.16B// Cannot we split naively
ldr q8, [x0]
ldr q9, [x0, #16]
ldr q10, [x0, #32]
ldr q11, [x0, #48]
mul v24.8H, v9.8H, v0.H[0]
sqrdmulh v9.8H, v9.8H, v0.H[1]
mls v24.8H, v9.8H, v1.H[0]
sub v9.8H, v8.8H, v24.8H
add v8.8H, v8.8H, v24.8H
end:


.macro test parama
    add r0, r0, \parama
.endm
slothy_start:
adds r0, r0, r1
.if 5 != 0
    add r0, r0, r1
    .if 5 > 2
        add r1, r1, r1
    .else
        add r5, r5, r5
    .endif
.else
    add r0, r1
.endif
add r0, r0, r1, lsl #3
sub r0, r0, r1, lsl #3
mul r1, r2, r3
smull r1, r2, r3, r0
smlal r1, r2, r3, r0
and r0, r0, r1
orr r0, r0, r1
eor r0, r0, r1
eor r0, r0, r1, ror #4
bic r0, r0, r1
bic r0, r0, r1, ror #4
ror r0, r1, #5
slothy_end:
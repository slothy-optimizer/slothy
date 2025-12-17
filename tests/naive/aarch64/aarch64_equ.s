.equ BASE, 64
.equ NO_SPACES, (BASE+8)
.equ SPACE_AFTER_OP, (BASE+ 16)
.equ SPACE_BEFORE_OP, (BASE +24)
.equ SPACES_BOTH, (BASE + 32)
.equ MANY_SPACES, (BASE   +   40)
.equ WITH_MUL, (BASE*2)
.equ WITH_DIV, (BASE/2)
.equ MUL_AND_ADD, (BASE*2+16)
.equ COMPLEX_EXPR, (BASE + BASE*2 + 64/4)
.equ NESTED_SYMBOLS, (COMPLEX_EXPR + BASE)
.equ VERY_COMPLEX, (BASE*4 + NESTED_SYMBOLS/2 - 8)

start:
ldr q0, [x0, #NO_SPACES]
ldr q1, [x0, #SPACE_AFTER_OP]
ldr q2, [x0, #SPACE_BEFORE_OP]
ldr q3, [x0, #SPACES_BOTH]
ldr q4, [x0, #MANY_SPACES]
ldr q5, [x0, #WITH_MUL]
ldr q6, [x0, #WITH_DIV]
ldr q7, [x0, #MUL_AND_ADD]
ldr q8, [x0, #COMPLEX_EXPR]
ldr q9, [x0, #NESTED_SYMBOLS]
ldr q10, [x0, #VERY_COMPLEX]
end:

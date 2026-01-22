// Basic .rept test
start_rept:
.rept 5
    add x1, x1, x2
.endr
end_rept:

// Basic .irp test
start_irp:
.irp param,x2,x3,x4
    add x1, x1, \param
.endr
end_irp:

// .irp inside a macro
.macro test_irp, my_reg
    .irp param,x1,x2
        sub \my_reg, \my_reg, \param
    .endr
.endm

start_irp_in_macro:
test_irp x1
end_irp_in_macro:

// macro inside .irp
.macro some_macro, my_reg
    sub \my_reg, \my_reg, \my_reg
.endm

start_macro_in_irp:
.irp param,x2,x3,x4
    some_macro \param
.endr
end_macro_in_irp:

// .rept with \+ iteration counter (0-indexed)
start_rept_counter:
.rept 3
    add x\+, x\+, x5
.endr
end_rept_counter:

// Nested .rept
start_nested_rept:
.rept 2
    .rept 2
        add x1, x1, x2
    .endr
.endr
end_nested_rept:

// .rept inside .irp
start_rept_in_irp:
.irp reg,x1,x2
    .rept 2
        add \reg, \reg, x5
    .endr
.endr
end_rept_in_irp:

// .irp inside .rept
start_irp_in_rept:
.rept 2
    .irp param,x3,x4
        add x1, x1, \param
    .endr
.endr
end_irp_in_rept:

// Combined \+ and macro in .rept
.macro indexed_op, idx
    add x1, x1, x\idx
.endm

start_rept_macro_counter:
.rept 3
    indexed_op \+
.endr
end_rept_macro_counter:

// .rept 0 should produce no output
start_rept_zero:
add x1, x1, x2
.rept 0
    sub x1, x1, x3
.endr
add x1, x1, x4
end_rept_zero:

// .irp with single value
start_irp_single:
.irp param,x2
    add x1, x1, \param
.endr
end_irp_single:

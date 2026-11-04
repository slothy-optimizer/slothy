// .equ aliases for registers (with %) and offsets, as used by the Keccak code.
.equ rState, %rdi
.equ rT0, %rax
.equ rT1, %rbx
.equ _off, 1*8

start:
        mov _off(rState), rT0
        mov 2*8(rState), rT1
        xor rT1, rT0
        rol $1, rT0
        mov rT0, 3*8(rState)
end:

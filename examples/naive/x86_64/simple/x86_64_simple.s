// x86_64 example for the Intel Atom (Bonnell) model, AT&T syntax.
//
// Four regions, optimized separately (see _example.py):
//   start / end                      every non-branch instruction form (selftest runs)
//   start_subregisters / ...         8/16/32-bit register forms
//   start_symbolic / ...             symbolic registers and memory hints
//   start_fusion / ...               xor-with-memory splitting + opt-in memory constraint
// Branches (jz/jnz) are not included: loop optimization on x86_64 is not yet safe.

// Register aliases (.equ values may contain %) and memory offsets
.equ rState, %rdi
.equ rOut,   %rsi
.equ _a,  1*8
.equ _b,  2*8
.equ _c,  3*8
.equ _x,  4*8
.equ _y,  6*8

start:
        mov (rState), %rbx              // mov_from_mem
        mov _a(rState), %rax            // mov_from_mem_offset
        mov $3, %rcx                    // mov_qi
        movq $5, %rdx                   // movq_i
        add $1, %rax                    // add_qi
        add %rbx, %rax                  // add_qq
        and %rcx, %rax                  // and_qq
        or %rdx, %rbx                   // or_qq
        xor $7, %rbx                    // xor_qi
        xor %rax, %rbx                  // xor_qq
        not %rcx                        // not_q
        rol $3, %rcx                    // rol_qi
        rol %rdx                        // rol1
        shr $2, %rdx                    // shr_qi
        sub $4, %rdx                    // sub_qi
        xchg %rcx, %rdx                 // xchg_q: microcoded, uses every unit
        mov %rcx, %r8                   // mov_qq
        movq %rdx, %r9                  // movq
        xor _b(rState), %r8             // xor_from_mem_offset: ALU0 + MEM
        push %r9                        // push: implicit rsp, uses every unit
        pop %r10                        // pop
        mov %rax, (rOut)                // mov_to_mem
        mov %rbx, _a(rOut)              // mov_to_mem_offset
        xor %r8, _b(rOut)               // xor_to_mem_offset
        mov %r10, _c(rOut)
        movdqu _x(rState), %xmm0        // movdqu_x_from_mem_offset
        pxor _y(rState), %xmm0          // pxor_x_from_mem_offset: FP0 + MEM
        pxor %xmm1, %xmm0               // pxor_xx
        movdqu %xmm0, _x(rOut)          // movdqu_x_to_mem_offset
end:

// Sub-register forms on their own: overlap between e.g. al and rax is not modelled
start_subregisters:
        add $1, %al                     // add_hi
        add $1, %bx                     // add_si
        add $1, %ecx                    // add_di
        add %dl, %al                    // add_hh
        add %si, %bx                    // add_ss
        add %edi, %ecx                  // add_dd
end_subregisters:

// Symbolic registers (allocated by SLOTHY) and a memory dependency declared by tags
start_symbolic:
        mov _a(rState), %QW<x>
        mov _b(rState), %QW<y>
        xor %QW<y>, %QW<x>
        rol $1, %QW<x>
        mov %QW<x>, _a(rOut)            // @slothy:writes=out
        mov _a(rOut), %QW<z>            // @slothy:reads=out
        add %QW<z>, %QW<x>
        mov %QW<x>, _b(rOut)
end_symbolic:

// xor with a memory operand is split into a load and a register xor (fusion), then
// optimized with the opt-in Bonnell constraint: the load from _a(rState) and the
// store to _a(rOut) (same offset, different base register) stay 8 cycles apart
start_fusion:
        xor _a(rState), %rax
        xor _b(rState), %rbx
        mov %rax, _a(rOut)
        mov %rbx, _b(rOut)
end_fusion:

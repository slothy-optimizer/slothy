// One of each supported x86_64 instruction form (AT&T syntax), excluding branches.
start:
        add $1, %rax
        add %rbx, %rax
        and %rcx, %rax
        mov $5, %rcx
        mov %rax, %rdx
        movq %rdx, %r8
        movq $7, %r9
        mov (%rdi), %r10
        mov 8(%rdi), %r11
        mov %r10, (%rsi)
        mov %r11, 16(%rsi)
        not %r12
        or %r12, %r13
        rol $3, %r13
        rol %r13
        shr $2, %r14
        sub $4, %r14
        test $1, %r14
        xchg %r8, %r9
        xor $3, %r15
        xor %r15, %rax
        xor 24(%rdi), %rbx
        xor %rbx, 32(%rsi)
        movdqu 48(%rdi), %xmm0
        pxor 64(%rdi), %xmm0
        pxor %xmm0, %xmm1
        movdqu %xmm1, 80(%rsi)
        push %rax
        pop %rcx
end:

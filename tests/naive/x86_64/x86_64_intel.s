// Intel-syntax input; optimized with config.syntax = Intel_Code.
start:
        mov rax, qword ptr [rdi]
        mov rbx, qword ptr [rdi+8]
        xor rax, rbx
        rol rax, 3
        mov qword ptr [rdi+16], rax
        movdqu xmm0, xmmword ptr [rsi+0]
        pxor xmm0, xmmword ptr [rsi+16]
        movdqu xmmword ptr [rsi+32], xmm0
end:

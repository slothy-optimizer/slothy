// Two independent load/xor/rotate/store chains in Intel syntax
// (config.syntax = Intel_Code); the output stays in Intel syntax.
start:
        mov rax, qword ptr [rdi+0]
        mov rbx, qword ptr [rdi+8]
        xor rax, rbx
        rol rax, 1
        xor rcx, rax
        mov qword ptr [rsi+0], rcx

        mov rdx, qword ptr [rdi+16]
        mov r8, qword ptr [rdi+24]
        xor rdx, r8
        rol rdx, 1
        xor r9, rdx
        mov qword ptr [rsi+8], r9
end:

movq  %rbp, %rbx
rolq  %rbx
movq  2*8(%rdi), %r12
xorq  7*8(%rdi), %rdx
xorq  %r15, %rbx
xorq  12*8(%rdi), %r12
xorq  17*8(%rdi), %rdx
xorq  %rdx, %r12
movq  %r12, %rcx
rolq  %rcx
movq  3*8(%rdi), %r13
xorq  8*8(%rdi), %r8
xorq  %rsi, %rcx
xorq  13*8(%rdi), %r13
xorq  18*8(%rdi), %r8
xorq  %r8, %r13
movq  %r13, %rdx
rolq  %rdx
movq  %r15, %r8
xorq  %rbp, %rdx
rolq  %r8
movq  %rsi, %r9
xorq  %r12, %r8
rolq  %r9
movq  0*8(%rdi), %r10
movq  6*8(%rdi), %r11
xorq  %r13, %r9
movq  12*8(%rdi), %r12
movq  18*8(%rdi), %r13
movq  24*8(%rdi), %r14
xorq  %rcx, %r11
rolq  $44, %r11
xorq  %rdx, %r12
xorq  %rbx, %r10
rolq  $43, %r12
movq  %r11, %rsi
movq  $0x0, %rax
orq  %r12, %rsi
xorq  %r10 , %rax
xorq  %rax, %rsi
movq  %rsi, 0*8(%rsp)
xorq  %r9, %r14
rolq  $14, %r14
movq  %r10 , %r15
andq  %r11, %r15
xorq  %r14, %r15
movq  %r15, 4*8(%rsp)
xorq  %r8, %r13
rolq  $21, %r13
movq  %r13, %rax
andq  %r14, %rax
xorq  %r12, %rax
movq  %rax, 2*8(%rsp)
notq  %r12
orq  %r10 , %r14
orq  %r13, %r12
xorq  %r13, %r14
xorq  %r11, %r12
movq  %r14, 3*8(%rsp)
movq  %r12, 1*8(%rsp)
movq  %r12, %rbp
movq  9*8(%rdi), %r11
xorq  %r9, %r11
movq  10*8(%rdi), %r12
rolq  $20, %r11
xorq  %rbx, %r12
rolq  $3,  %r12
movq  3*8(%rdi), %r10
movq  %r11, %rax
orq  %r12, %rax
xorq  %r8, %r10
movq  16*8(%rdi), %r13
movq  22*8(%rdi), %r14
rolq  $28, %r10
xorq  %r10 , %rax
movq  %rax, 5*8(%rsp)
xor   %rax, %rsi
xorq  %rcx, %r13
rolq  $45, %r13
movq  %r12, %rax
andq  %r13, %rax
xorq  %r11, %rax
movq  %rax, 6*8(%rsp)
xorq  %rax, %rbp
xorq  %rdx, %r14
rolq  $61, %r14
movq  %r14, %rax
orq  %r10 , %rax
xorq  %r13, %rax
movq  %rax, 8*8(%rsp)
andq  %r11, %r10
xorq  %r14, %r10
movq  %r10 , 9*8(%rsp)
notq  %r14
xorq  %r10 , %r15
orq  %r14, %r13
xorq  %r12, %r13
movq  %r13, 7*8(%rsp)
movq  1*8(%rdi), %r10
movq  7*8(%rdi), %r11
movq  13*8(%rdi), %r12
movq  19*8(%rdi), %r13
movq  20*8(%rdi), %r14
xorq  %rdx, %r11
rolq  $6,  %r11
xorq  %r8, %r12
rolq  $25, %r12
movq  %r11, %rax
orq  %r12, %rax
xorq  %rcx, %r10
rolq  $1,  %r10
xorq  %r10 , %rax
movq  %rax, 10*8(%rsp)
xor   %rax, %rsi
xorq  %r9, %r13
rolq  $8,  %r13
movq  %r12, %rax
andq  %r13, %rax
xorq  %r11, %rax
movq  %rax, 11*8(%rsp)
xorq  %rax, %rbp
xorq  %rbx, %r14
rolq  $18, %r14
notq  %r13
movq  %r13, %rax
andq  %r14, %rax
xorq  %r12, %rax
movq  %rax, 12*8(%rsp)
movq  %r14, %rax
orq  %r10 , %rax
xorq  %r13, %rax
movq  %rax, 13*8(%rsp)
andq  %r11, %r10
xorq  %r14, %r10
movq  %r10 , 14*8(%rsp)
xorq  %r10 , %r15
movq  5*8(%rdi), %r11
xorq  %rbx, %r11
movq  11*8(%rdi), %r12
rolq  $36, %r11
xorq  %rcx, %r12
movq  4*8(%rdi), %r10
rolq  $10, %r12
movq  %r11, %rax
movq  17*8(%rdi), %r13
andq  %r12, %rax
xorq  %r9, %r10
movq  23*8(%rdi), %r14
rolq  $27, %r10
xorq  %r10 , %rax
movq  %rax, 15*8(%rsp)
xor   %rax, %rsi
xorq  %rdx, %r13
rolq  $15, %r13
movq  %r12, %rax
orq  %r13, %rax
xorq  %r11, %rax
movq  %rax, 16*8(%rsp)
xorq  %rax, %rbp
xorq  %r8, %r14
rolq  $56, %r14
notq  %r13
movq  %r13, %rax
orq  %r14, %rax
xorq  %r12, %rax
movq  %rax, 17*8(%rsp)
orq  %r10 , %r11
xorq  %r14, %r11
movq  %r11, 19*8(%rsp)
andq  %r10 , %r14
xorq  %r13, %r14
movq  %r14, 18*8(%rsp)
xorq  %r11, %r15
movq  2*8(%rdi), %r10
movq  8*8(%rdi), %r11
movq  14*8(%rdi), %r12
xorq  %rdx, %r10
movq  15*8(%rdi), %r13
rolq  $62, %r10
xorq  %r8, %r11
movq  21*8(%rdi), %r14
rolq  $55, %r11
xorq  %r9, %r12
movq  %r10 , %r9
xorq  %rcx, %r14
rolq  $2,  %r14
andq  %r11, %r9
xorq  %r14, %r9
movq  %r9, 24*8(%rsp)
rolq  $39, %r12
xorq  %r9, %r15
notq  %r11
xorq  %rbx, %r13
movq  %r11, %rbx
andq  %r12, %rbx
xorq  %r10 , %rbx
movq  %rbx, 20*8(%rsp)
xor   %rbx, %rsi
rolq  $41, %r13
movq  %r12, %rcx
orq  %r13, %rcx
xorq  %r11, %rcx
movq  %rcx, 21*8(%rsp)
xorq  %rcx, %rbp
movq  %r13, %rdx
movq  %r14, %r8
andq  %r14, %rdx
orq  %r10 , %r8
xorq  %r12, %rdx
xorq  %r13, %r8
movq  %rdx, 22*8(%rsp)
movq  %r8, 23*8(%rsp)

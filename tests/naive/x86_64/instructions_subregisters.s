// Instruction forms on 8/16/32-bit sub-registers (AT&T syntax).
start:
        add $1, %al
        add $1, %bx
        add $1, %ecx
        add %dl, %al
        add %si, %bx
        add %edi, %ecx
end:

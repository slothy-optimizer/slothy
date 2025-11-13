mov r0, #17
wlstp.u8 lr, r0, 2f
1:  
    nop
    letp lr, 1b
2:
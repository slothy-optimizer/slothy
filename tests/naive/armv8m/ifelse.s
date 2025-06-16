.equ RCxy_44, 14
.macro shift x, y
.if (RCxy_\x\()\y % 2) == 0
    vshr.u32 SHR_l, A_l, #32-(RCxy_\x\()\y/2)
.else
    vshr.u32 SHR_h, A_l, #32-((RCxy_\x\()\y-1)/2)
.endif
.endm

start:
shift 4, 4
end:
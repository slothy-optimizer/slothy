vmov.s32 c0, #42
vmov.s32 c1, #43
vmov.s32 c2, #44
vmov.s32 c3, #45
vadd.s32 b, a, c0
vadd.s32 c, b, c1
vadd.s32 d, c, c2
vadd.s32 e, d, c3

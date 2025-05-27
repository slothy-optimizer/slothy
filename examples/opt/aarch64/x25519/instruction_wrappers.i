
dform_v0  .req d0
dform_v1  .req d1
dform_v2  .req d2
dform_v3  .req d3
dform_v4  .req d4
dform_v5  .req d5
dform_v6  .req d6
dform_v7  .req d7
dform_v8  .req d8
dform_v9  .req d9
dform_v10  .req d10
dform_v11  .req d11
dform_v12  .req d12
dform_v13  .req d13
dform_v14  .req d14
dform_v15  .req d15
dform_v16  .req d16
dform_v17  .req d17
dform_v18  .req d18
dform_v19  .req d19
dform_v20 .req d20
dform_v21 .req d21
dform_v22 .req d22
dform_v23 .req d23
dform_v24 .req d24
dform_v25 .req d25
dform_v26 .req d26
dform_v27 .req d27
dform_v28 .req d28
dform_v29 .req d29

wform_x0 .req w0
wform_x1 .req w1
wform_x2 .req w2
wform_x3 .req w3
wform_x4 .req w4
wform_x5 .req w5
wform_x6 .req w6
wform_x7 .req w7
wform_x8 .req w8
wform_x9 .req w9
wform_x10 .req w10
wform_x11 .req w11
wform_x12 .req w12
wform_x13 .req w13
wform_x14 .req w14
wform_x15 .req w15
wform_x16 .req w16
wform_x17 .req w17
wform_x18 .req w18
wform_x19 .req w19
wform_x20 .req w20
wform_x21 .req w21
wform_x22 .req w22
wform_x23 .req w23
wform_x24 .req w24
wform_x25 .req w25
wform_x26 .req w26
wform_x27 .req w27
wform_x28 .req w28
wform_x29 .req w29
wform_x30 .req w30

bform_v0  .req b0
bform_v1  .req b1
bform_v2  .req b2
bform_v3  .req b3
bform_v4  .req b4
bform_v5  .req b5
bform_v6  .req b6
bform_v7  .req b7
bform_v8  .req b8
bform_v9  .req b9
bform_v10  .req b10
bform_v11  .req b11
bform_v12  .req b12
bform_v13  .req b13
bform_v14  .req b14
bform_v15  .req b15
bform_v16  .req b16
bform_v17  .req b17
bform_v18  .req b18
bform_v19  .req b19
bform_v20  .req b20
bform_v21  .req b21
bform_v22  .req b22
bform_v23  .req b23
bform_v24  .req b24
bform_v25  .req b25
bform_v26  .req b26
bform_v27  .req b27
bform_v28  .req b28
bform_v29  .req b29
bform_v30  .req b30


.macro stack_str loc, a                                      // slothy:no-unfold
  str \a, [sp, #\loc]
.endm

.macro stack_str_wform loc, a                                // slothy:no-unfold
  str wform_\a, [sp, #\loc]
.endm

.macro stack_stp loc1, loc2, sA, sB                          // slothy:no-unfold
  .if \loc1 + 8 != \loc2
    ERROR: loc2 needs to be loc1+8
  .endif
  stp \sA, \sB, [sp, #\loc1\()]
.endm

.macro stack_stp_wform loc1, loc2, sA, sB                    // slothy:no-unfold
  .if \loc1 + 4 != \loc2
    ERROR: loc2 needs to be loc1+4
  .endif
  stp wform_\sA, wform_\sB, [sp, #\loc1\()]
.endm

.macro stack_ldr a, loc                                      // slothy:no-unfold
  ldr \a, [sp, \loc]
.endm


.macro stack_ldp sA, sB, loc                                 // slothy:no-unfold
  ldp \sA, \sB, [sp, #\loc\()]
.endm

.macro stack_ldrb a, loc, offset                             // slothy:no-unfold
  ldrb \a, [sp, #\loc\()+\offset]
.endm

.macro stack_vstr_dform loc, a                               // slothy:no-unfold
  str dform_\a, [sp, #\loc]
.endm

.macro stack_vstp_dform loc, loc2, vA, vB                          // slothy:no-unfold
  stp dform_\vA, dform_\vB, [sp, #\loc\()]
.endm

.macro stack_vldr_dform a, loc                               // slothy:no-unfold
  ldr dform_\a, [sp, #\loc\()]
.endm

.macro stack_vldr_bform a, loc                               // slothy:no-unfold
  ldr bform_\a, [sp, #\loc]
.endm

.macro stack_vld1r a, loc                                    // slothy:no-unfold
  .if \loc != 0
      ERROR: loc needs to be 0
  .endif
  ld1r {\a\().2d}, [sp]
.endm

.macro stack_vld2_lane out0, out1, addr, loc, lane, imm      // slothy:no-unfold
  // loc is not used (it is included in other args), but we need to tell slothy
  // that it depends on the memory region
  ld2 { \out0\().s, \out1\().s }[\lane\()], [\addr\()], #\imm
.endm

.syntax unified
start:

add r0, r1, r2 

sub r0, r1, r2

ldr r0, [sp, #4]
ldr r1, [r13, #8]

ldr r0, [sp, #4]
ldr r1, [r13, 8]

vmulh.u8 q2, q0, q1
vmulh.u16 q2, q0, q1
vmulh.u32 q2, q0, q1

vmul.u8 q2, q0, r0
vmul.u16 q2, q0, r0
vmul.u32 q2, q0, r0

vmul.u8 q2, q0, q1
vmul.u16 q2, q0, q1
vmul.u32 q2, q0, q1

vmul.f16 q2, q0, r0
vmul.f32 q2, q0, r0

vmul.f16 q2, q0, q1
vmul.f32 q2, q0, q1

vqrdmulh.s8 q2, q0, q1
vqrdmulh.s16 q2, q0, q1
vqrdmulh.s32 q2, q0, q1

vqrdmulh.s8 q2, q0, r0
vqrdmulh.s16 q2, q0, r0
vqrdmulh.s32 q2, q0, r0

vqdmlah.s8 q2, q0, r0
vqdmlah.s16 q2, q0, r0
vqdmlah.s32 q2, q0, r0

vqdmlsdh.s8 q2, q0, q1
vqdmlsdh.s16 q2, q0, q1
vqdmlsdh.s32 q2, q0, q1

vqdmladhx.s8 q2, q0, q1
vqdmladhx.s16 q2, q0, q1
vqdmladhx.s32 q2, q0, q1

vqrdmlah.s8 q2, q0, r0
vqrdmlah.s16 q2, q0, r0
vqrdmlah.s32 q2, q0, r0

vqdmulh.s8 q2, q0, r0
vqdmulh.s16 q2, q0, r0
vqdmulh.s32 q2, q0, r0

vqdmulh.s8 q2, q0, q1
vqdmulh.s16 q2, q0, q1
vqdmulh.s32 q2, q0, q1

ldrd r0, r1, [r2]
ldrd r0, r1, [r2, #16]
ldrd r0, r1, [r2, #-16]
ldrd r0, r1, [r2], #16
ldrd r0, r1, [r2], #-16
ldrd r0, r1, [r2, #16]!
ldrd r0, r1, [r2, #-16]!

ldr r0, [r1, #16]
ldr r0, [r1, #-16]
ldr r0, [r1], #16
ldr r0, [r1], #-16
ldr r0, [r1, #16]!
ldr r0, [r1, #-16]!

strd r0, r1, [r2, #16]
strd r0, r1, [r2, #-16]
strd r0, r1, [r2], #16
strd r0, r1, [r2], #-16
strd r0, r1, [r2, #16]!
strd r0, r1, [r2, #-16]!

strd r0, r1, [r2, 16]
strd r0, r1, [r2, -16]
strd r0, r1, [r2], 16
strd r0, r1, [r2], -16
strd r0, r1, [r2, 16]!
strd r0, r1, [r2, -16]!

vrshr.u8 q2, q0, #8
vrshr.u16 q2, q0, #16
vrshr.u32 q2, q0, #16
vrshr.s8 q2, q0, #8
vrshr.s16 q2, q0, #16
vrshr.s32 q2, q0, #16

vrshl.u8 q0, r0
vrshl.u16 q0, r0
vrshl.u32 q0, r0
vrshl.s8 q0, r0
vrshl.s16 q0, r0
vrshl.s32 q0, r0

vshlc q0, r0, #16

vmov.i8 q0, #8
vmov.i16 q0, #16
vmov.i32 q0, #16
vmov.i64 q0, #0xFF

vmullt.u8 q2, q0, q1
vmullt.u16 q2, q0, q1
vmullt.u32 q2, q0, q1
vmullt.s8 q2, q0, q1
vmullt.s16 q2, q0, q1
vmullt.s32 q2, q0, q1

vmullb.u8 q2, q0, q1
vmullb.u16 q2, q0, q1
vmullb.u32 q2, q0, q1
vmullb.s8 q2, q0, q1
vmullb.s16 q2, q0, q1
vmullb.s32 q2, q0, q1

vdup.u8 q0, r0
vdup.u16 q0, r0
vdup.u32 q0, r0

vmov r0, r1, q0[2], q0[0]
vmov r0, r1, q0[3], q0[1]

mov r0, #16

mvn r0, #16

pkhbt r2, r1, r0, lsl #16

mov r1, r0

add r0, r1, #16

sub r0, r1, #16

vshr.u8 q0, q1, #8
vshr.u16 q0, q1, #16
vshr.u32 q0, q1, #16
vshr.s8 q0, q1, #8
vshr.s16 q0, q1, #16
vshr.s32 q0, q1, #16

vshrnt.i16 q0, q1, #8
vshrnt.i32 q0, q1, #8
vshrnb.i16 q0, q1, #8
vshrnb.i32 q0, q1, #8

vshllt.u8 q0, q1, #8
vshllt.u16 q0, q1, #8
vshllt.s8 q0, q1, #8
vshllt.s16 q0, q1, #8
vshllb.u8 q0, q1, #8
vshllb.u16 q0, q1, #8
vshllb.s8 q0, q1, #8
vshllb.s16 q0, q1, #8

vsli.u8 q0, q1, #6
vsli.u16 q0, q1, #8
vsli.s8 q0, q1, #6
vsli.s16 q0, q1, #8

vmovlb.u8 q1, q0
vmovlb.u16 q1, q0
vmovlb.s8 q1, q0
vmovlb.s16 q1, q0

vmovlt.u8 q1, q0
vmovlt.u16 q1, q0
vmovlt.s8 q1, q0
vmovlt.s16 q1, q0

vrev16.u8 q0, q1

vrev32.u8 q0, q1
vrev32.u16 q0, q1

vrev64.u8 q0, q1
vrev64.u16 q0, q1
vrev64.u32 q0, q1

vshl.u8 q1, q0, #7
vshl.u16 q1, q0, #15
vshl.u32 q1, q0, #16
vshl.s8 q1, q0, #7
vshl.s16 q1, q0, #15
vshl.s32 q1, q0, #16

vshl.u8 q2, q0, q1
vshl.u16 q2, q0, q1
vshl.u32 q2, q0, q1
vshl.s8 q1, q0, #7
vshl.s16 q1, q0, #15
vshl.s32 q1, q0, #16

vfma.f16 q2, q0, q1
vfma.f32 q2, q0, q1

vmla.u8 q1, q0, r0
vmla.u16 q1, q0, r0
vmla.u32 q1, q0, r0

vmlaldava.u16 r0, r1, q0, q1
vmlaldava.u32 r0, r1, q0, q1
vmlaldava.s16 r0, r1, q0, q1
vmlaldava.s32 r0, r1, q0, q1

vaddva.u8 r0, q0
vaddva.u16 r0, q0
vaddva.u32 r0, q0

vadd.u8 q2, q0, q1
vadd.u16 q2, q0, q1
vadd.u32 q2, q0, q1

vadd.i8 q2, q0, r1
vadd.i16 q2, q0, r1
vadd.i32 q2, q0, r1

vhadd.u8 q2, q0, q1
vhadd.u16 q2, q0, q1
vhadd.u32 q2, q0, q1

vsub.i8 q2, q0, q1
vsub.i16 q2, q0, q1
vsub.i32 q2, q0, q1

vsub.i32 q2, q0, r0


vhsub.u8 q2, q0, q1
vhsub.u16 q2, q0, q1
vhsub.u32 q2, q0, q1

vand.u8 q2, q0, q1
vand.u16 q2, q0, q1
vand.u32 q2, q0, q1
vand.u64 q2, q0, q1

vbic.u8 q2, q0, q1
vbic.u16 q2, q0, q1
vbic.u32 q2, q0, q1
vbic q2, q0, q1

vorr.u8 q2, q0, q1
vorr.u16 q2, q0, q1
vorr.u32 q2, q0, q1
vorr.u64 q2, q0, q1

veor.u8 q2, q0, q1
veor.u16 q2, q0, q1
veor.u32 q2, q0, q1
veor.u64 q2, q0, q1
veor q2, q0, q1

nop

vstrw.u32 q0, [r0, #16]
vstrw.u32 q0, [r0], #16
vstrw.u32 q0, [r0, #16]!

vstrw.32 q0, [r0, #16]
vstrw.32 q0, [r0], #16
vstrw.32 q0, [r0, #16]!

vstrw.u32 Q0, [r1, Q2, UXTW #2]
vstrw.u32 Q0, [r1, Q2, UXTW 2]

vldrb.u8 q0, [r0, #16]
vldrb.u8 q0, [r0], #16
vldrb.u8 q0, [r0, #16]!
vldrb.u16 q0, [r0, #16]
vldrb.u32 q0, [r0, #16]

vldrb.u8 q0, [r0, 16]
vldrb.u8 q0, [r0], 16
vldrb.u8 q0, [r0, 16]!
vldrb.u16 q0, [r0, 16]
vldrb.u32 q0, [r0, 16]

vldrh.u32 q0, [r0, #16]
vldrh.u32 q0, [r0], #16
vldrh.u32 q0, [r0, #16]!

vldrw.u32 q0, [r0, #16]
vldrw.u32 q0, [r0], #16
vldrw.u32 q0, [r0, #16]!

vldrw.u32 q1, [r0, q0]
vldrw.u32 q1, [r0, q0]

vldrw.u32 q1, [r0, q0]

vldrb.u32 q1, [r0, q0]

vldrh.u32 q1, [r0, q0]

vld20.32 {q4,q5}, [r1]
vld21.32 {q4,q5}, [r1]!

vld40.8 {q3,q4,q5,q6}, [r0]
vld41.16 {q3,q4,q5,q6}, [r0]!
vld42.32 {q3,q4,q5,q6}, [r0]
vld43.32 {q3,q4,q5,q6}, [r0]

vst20.u8 {q0, q1}, [r0]!
vst20.u16 {q0, q1}, [r0]!
vst20.u32 {q0, q1}, [r0]!

vst21.u8 {q0, q1}, [r0]!
vst21.u16 {q0, q1}, [r0]!
vst21.u32 {q0, q1}, [r0]!

vst40.u8 {q0, q1, q2, q3}, [r0]!
vst40.u16 {q0, q1, q2, q3}, [r0]!
vst40.u32 {q0, q1, q2, q3}, [r0]!

vst41.u8 {q0, q1, q2, q3}, [r0]!
vst41.u16 {q0, q1, q2, q3}, [r0]!
vst41.u32 {q0, q1, q2, q3}, [r0]!

vst42.u8 {q0, q1, q2, q3}, [r0]!
vst42.u16 {q0, q1, q2, q3}, [r0]!
vst42.u32 {q0, q1, q2, q3}, [r0]!

vst43.u8 {q0, q1, q2, q3}, [r0]!
vst43.u16 {q0, q1, q2, q3}, [r0]!
vst43.u32 {q0, q1, q2, q3}, [r0]!

vsub.f16 q2, q1, q0
vsub.f32 q2, q1, q0

vsub.f32 q2, q1, r0


vadd.f16 q2, q1, q0
vadd.f32 q2, q1, q0

vcmla.f16 q2, q0, q1, #0 
vcmla.f16 q2, q0, q1, #90 
vcmla.f16 q2, q0, q1, #180 
vcmla.f16 q2, q0, q1, #270 

vcmla.f32 q2, q0, q1, #0 
vcmla.f32 q2, q0, q1, #90 
vcmla.f32 q2, q0, q1, #180 
vcmla.f32 q2, q0, q1, #270 

vcmul.f16 q2, q0, q1, #0 
vcmul.f16 q2, q0, q1, #90 
vcmul.f16 q2, q0, q1, #180 
vcmul.f16 q2, q0, q1, #270 

vcmul.f16 q2, q0, q1, 0 
vcmul.f16 q2, q0, q1, 90 
vcmul.f16 q2, q0, q1, 180 
vcmul.f16 q2, q0, q1, 270 

vcmul.f32 q2, q0, q1, #0 
vcmul.f32 q2, q0, q1, #90 
vcmul.f32 q2, q0, q1, #180 
vcmul.f32 q2, q0, q1, #270 

vcadd.u8 q2, q0, q1, #90
vcadd.u8 q2, q0, q1, #270
vcadd.u16 q2, q0, q1, #90
vcadd.u16 q2, q0, q1, #270
vcadd.u32 q2, q0, q1, #90
vcadd.u32 q2, q0, q1, #270

vhcadd.s8 q2, q0, q1, #90
vhcadd.s8 q2, q0, q1, #270
vhcadd.s16 q2, q0, q1, #90
vhcadd.s16 q2, q0, q1, #270
vhcadd.s32 q2, q0, q1, #90
vhcadd.s32 q2, q0, q1, #270

lsr r0, r0, #1

end:

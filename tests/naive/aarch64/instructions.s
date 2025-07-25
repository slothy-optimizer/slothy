start:

// TODO: this is currently incomplete. We should add all instructions
shl v0.16b, v1.16b, #4
shl d2, d3, #8
sshr v4.16b, v5.16b, #2
ushr v6.16b, v7.16b, #3
uxtl v8.8h, v9.8b

zip1 v5.16b, v6.16b, v7.16b
zip2 v8.16b, v9.16b, v10.16b
uzp1 v11.16b, v12.16b, v13.16b
uzp2 v14.16b, v15.16b, v16.16b
and v16.16b, v17.16b, v18.16b
bic v19.16b, v20.16b, v21.16b
bic v0.8h, #0xf0, lsl #8
mvn v22.16b, v23.16b
orr v24.16b, v25.16b, v26.16b
orn v27.16b, v28.16b, v29.16b
eor v30.16b, v31.16b, v0.16b
ext v0.16b, v1.16b, v2.16b, #8
sli v3.16b, v4.16b, #2
sri v1.16b, v2.16b, #4
trn1 v17.16b, v18.16b, v19.16b
trn2 v20.16b, v21.16b, v22.16b
aese v0.16b, v1.16b
aesmc v2.16b, v3.16b

sub  x2, x2, #48
cmlt v4.8h, v30.8h, #0
cmle v4.8h, v30.8h, #0
cmhs v4.8h, v30.8h, v16.8h
cmgt v4.8h, v30.8h, v16.8h
cmeq v4.8h, v30.8h, v16.8h
cmge v4.8h, v30.8h, v16.8h
cmhi v4.8h, v30.8h, v16.8h
mov x12, #0
ldr q24, [x3, x12, lsl #4]
clz v0.16b, v0.16b
cnt v0.16b, v0.16b
tbl v16.16b, {v16.16b}, v24.16b
fmov w12, s20

// ASIMD multiply long 
umull v23.4s, v24.4h, v25.4h
umull2 v26.4s, v27.8h, v28.8h
umull v11.4s, v12.4h, v13.h[0]
umull2 v11.4s, v12.8h, v13.h[1]
smull v29.4s, v30.4h, v31.4h
smull2 v0.4s, v1.8h, v2.8h
smull v11.4s, v12.4h, v13.h[0]
smull2 v11.4s, v12.8h, v13.h[3]

// ASIMD multiply accumulate long
umlal v3.4s, v4.4h, v5.4h
umlal v3.4s, v4.4h, v5.h[0]
umlal2 v12.4s, v13.8h, v14.8h
umlal2 v12.4s, v13.8h, v14.h[0]
smlal v6.4s, v7.4h, v8.4h
smlal v6.4s, v7.4h, v8.h[3]
smlal2 v9.4s, v10.8h, v11.8h
smlal2 v9.4s, v10.8h, v11.h[2]

umlsl v3.4s, v4.4h, v5.4h
umlsl v3.4s, v4.4h, v5.h[0]
umlsl2 v12.4s, v13.8h, v14.8h
umlsl2 v12.4s, v13.8h, v14.h[0]
smlsl v6.4s, v7.4h, v8.4h
smlsl v6.4s, v7.4h, v8.h[3]
smlsl2 v9.4s, v10.8h, v11.8h
smlsl2 v9.4s, v10.8h, v11.h[2]

pmull v4.1q, v5.1d, v6.1d
pmull2 v7.1q, v8.2d, v9.2d

uaddlv s20, v4.8h

mla v4.4s, v5.4s, v6.4s
mla v4.4s, v5.4s, v6.s[0]
mls v4.4s, v5.4s, v6.4s
mls v4.4s, v5.4s, v6.s[0]
end:

start:

// TODO: this is currently incomplete. We should add all instructions

and v16.16b, v17.16b, v18.16b
bic v19.16b, v20.16b, v21.16b
mvn v22.16b, v23.16b
orr v24.16b, v25.16b, v26.16b
orn v27.16b, v28.16b, v29.16b
eor v30.16b, v31.16b, v0.16b
sri v1.16b, v2.16b, #4
sli v3.16b, v4.16b, #2
ext v0.16b, v1.16b, v2.16b, #8
aese v0.16b, v1.16b
aesmc v2.16b, v3.16b
pmull v4.1q, v5.1d, v6.1d
pmull2 v7.1q, v8.2d, v9.2d

end:

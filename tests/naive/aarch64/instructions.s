start:

// TODO: this is currently incomplete. We should add all instructions

zip1 v5.16b, v6.16b, v7.16b
zip2 v8.16b, v9.16b, v10.16b
uzp1 v11.16b, v12.16b, v13.16b
uzp2 v14.16b, v15.16b, v16.16b
and v16.16b, v17.16b, v18.16b
bic v19.16b, v20.16b, v21.16b
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
pmull v4.1q, v5.1d, v6.1d
pmull2 v7.1q, v8.2d, v9.2d

end:

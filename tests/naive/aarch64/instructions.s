start:

// TODO: this is currently incomplete. We should add all instructions

ext v0.16b, v1.16b, v2.16b, #8
aese v0.16b, v1.16b
aesmc v2.16b, v3.16b
pmull v4.1q, v5.1d, v6.1d
pmull2 v7.1q, v8.2d, v9.2d

end:

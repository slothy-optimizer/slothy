// Rule 8: Clear ACC and flags between bn.mulqacc instructions using shares of same secret
start:
// Leakage version - FORBIDDEN through FG
bn.xor        w9, w9, w9              // create zero register
bn.mulqacc.wo w6, w4.0, w0.0, 0, FG0  // use share0
bn.wsrw       ACC, w9                 // clear ACC
bn.mulqacc.wo w7, w5.0, w1.0, 0, FG0  // use share1 without clearing ACC/flags - FORBIDDEN
end:

start2:
// Leakage version - FORBIDDEN through ACC
bn.xor        w9, w9, w9              // create zero register
bn.mulqacc.wo w6, w4.0, w0.0, 0, FG0  // use share0
bn.mulqacc.wo w9, w9.0, w9.0, 0, FG0  // clear flags, dummy instruction
bn.mulqacc.wo w7, w5.0, w1.0, 0, FG0  // use share1 without clearing ACC/flags - FORBIDDEN
end2:

start3:
// No leakage version - ALLOWED
bn.xor        w9, w9, w9               // create zero register
bn.mulqacc.wo w6, w4.0, w0.0, 0, FG0  // use share0
bn.wsrw       ACC, w9                  // clear ACC
bn.mulqacc.wo w9, w9.0, w9.0, 0, FG0  // clear flags, dummy instruction
bn.mulqacc.wo w7, w5.0, w1.0, 0, FG0  // use share1 - OK after clearing
end3:

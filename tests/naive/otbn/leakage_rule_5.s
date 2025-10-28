// Rule 5: Be careful with addition and subtraction instructions
// Forbidden: Creating a relationship between shares through add/sub that enables leakage
bn.wsrr  w2, URND       // get random value
bn.xor   w0, w2, w0     // XOR share0 with random
bn.add   w0, w2, w0     // ADD creates relationship: w0 now = 2*w2 XOR original_w0
bn.xor   w9, w9, w9     // dummy instruction
bn.xor   w4, w1, w0     // mixing share1 with modified share0 - FORBIDDEN

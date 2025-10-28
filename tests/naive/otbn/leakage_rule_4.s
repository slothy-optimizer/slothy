// Rule 4: Do not have shares even in different bits of a register
// Forbidden: Having shares of the same secret in different parts of a register
bn.xor  w9, w9, w9      // set w9 to zero
bn.rshi w2, w1, w9 >> 254  // put share1 in low bits of w2
bn.xor  w4, w2, w0      // mix share0 (w0) with share1 (in w2) - FORBIDDEN

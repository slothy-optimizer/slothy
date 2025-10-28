// Rule 7: Do not use two shares of the same secret as sources of bn.sel
// Forbidden: Using share0 and share1 of same secret in bn.sel causes transient leakage
bn.sel w4, w1, w0, FG0.C  // w0 is share0, w1 is share1 - FORBIDDEN

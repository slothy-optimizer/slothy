// Rule 6: Do not use a source as the destination of bn.sel if selection flag is secret
// Forbidden: Using a share as both source and destination in bn.sel with secret flag
// Note: FG0 contains secret flag after bn.sub of shares
bn.sub w9, w0, w2       // Sets secret-dependent flag in FG0
bn.sel w5, w5, w4, FG0.C  // Using w5 as both source and dest with secret flag - FORBIDDEN

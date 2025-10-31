// Rule 6: Do not use a source as the destination of bn.sel if selection flag is secret
// Forbidden: Using a share as both source and destination in bn.sel with secret flag
// Assume: FG0 contains secret flag after bn.sub using a share

// Test case 1: Destination equals first source (Wa) with secret flag - FORBIDDEN
start:
bn.sub w9, w0, w2       // Sets secret-dependent flag in FG0
bn.sel w5, w5, w4, FG0.C  // Wd==Wa with secret flag - FORBIDDEN
end:

// Test case 2: Destination equals second source (Wb) with secret flag - FORBIDDEN
start2:
bn.sub w9, w0, w2       // Sets secret-dependent flag in FG0
bn.sel w4, w5, w4, FG0.C  // Wd==Wb with secret flag - FORBIDDEN
end2:

// Test case 3: Destination matches source but flag is PUBLIC - ALLOWED
start3:
bn.sub w9, w3, w2       // Creates PUBLIC flag (w2-w2=0, public operation)
bn.sel w5, w5, w4, FG0.C  // Wd==Wa but FG0 is public - ALLOWED
end3:

// Test case 4: Destination equals one of the inputs but is "healable"
start4:
bn.sub w9, w0, w2       // Sets secret-dependent flag in FG0
bn.sel w4, w5, w4, FG0.C  // Wd==Wb with secret flag - FORBIDDEN
bn.mov w10, w4            // Allow w4 to be renamed to a safe option
end4:
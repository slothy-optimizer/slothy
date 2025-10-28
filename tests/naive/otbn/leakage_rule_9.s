// Rule 9: Clear flags after using instructions which set flags depending on secret values
start:
// Without flag clearing - may leak through flags
bn.mulqacc.wo w6, w4.0, w0.0, 0, FG0  // Sets flags based on secret
bn.sub w5, w5, w2                      // Uses flags that contain secret info
end:

start2:
// With flag clearing - no leakage
bn.mulqacc.wo w6, w4.0, w0.0, 0, FG0  // Sets flags based on secret
bn.xor w9, w9, w9                      // Create zero
bn.mulqacc.wo w9, w9.0, w9.0, 0, FG0  // Clear flags with dummy instruction
bn.sub w5, w5, w2                      // Now safe to use flags
end2:

start3:
// Another example with bn.sub
bn.sub w4, w0, w2                      // Sets flags based on secret share
bn.add w5, w5, w3                      // May leak through flags
end3:

start4:
// With flag clearing
bn.sub w4, w0, w2                      // Sets flags based on secret share
bn.sub w9, w9, w9                      // Clear flags
bn.add w5, w5, w3                      // Now safe
end4:

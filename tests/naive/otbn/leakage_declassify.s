// Test declassification: XOR of a register with itself produces public 0
start:
bn.xor w2, w0, w0  // w0 is secret share, but w2 = w0 XOR w0 = 0 (public)
bn.add w3, w2, w1  // Now w2 is public, so mixing with w1 (different share) is OK
end:

// Test declassification: SUB of a register from itself produces public 0
start2:
bn.sub w2, w0, w0  // w0 is secret share, but w2 = w0 - w0 = 0 (public)
bn.add w3, w2, w1  // Now w2 is public, so mixing with w1 (different share) is OK
end2:

// Test declassification: ADD of a register with itself is NOT public
start3:
bn.add w2, w0, w0  // w0 is secret share, but w4 = w0 - w0 = 0 (public)
bn.add w3, w2, w1  // Now w2 is NOT public, so mixing with w1 (different share) is NOT OK
end3:
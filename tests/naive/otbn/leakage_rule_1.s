start:
bn.addi w2, w0, 0
bn.add w3, w2, w1
end:

start2:
bn.addi w2, w0, 0 // @slothy:ignore_useless_output
bn.addi w2, w4, 0
bn.add w3, w2, w1
end2:

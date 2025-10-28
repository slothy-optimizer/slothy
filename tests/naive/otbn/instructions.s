start:
addi x1, x1, 1
bn.addi w0, w1, 17
bn.add w0, w1, w2
bn.sub w0, w1, w2
bn.and w0, w1, w2
bn.xor w0, w1, w2
bn.rshi w0, w1, w2 >> 37
bn.mov w0, w1

bn.sel w0, w1, w2, FG0.C
bn.mulqacc.wo w0, w1.0, w2.1, 3, FG1

bn.wsrr w0, URND
bn.wsrw ACC, w0
end:
start1:
bn.and  w1, w0, w0
end1:

start2:
bn.addi w1, w0, 0x0 
end2:

start3:
bn.mov  w1, w0
end3:

start4:
bn.sel  w1, w0, w0, FG0.C
end4:

// Although we don't directly overwrite another share, the taint tracking should
// recognize here, that w2 is tainted through w0 and thus overwriting with w1 is
// not allowed.
start5:
bn.addi w2, w0, 5 // @slothy:ignore_useless_output
bn.add w2, w5, w1
end5:

start6:
bn.addi w2, w0, 0 // @slothy:ignore_useless_output
bn.addi w2, w4, 0
bn.add w3, w2, w1
end6:

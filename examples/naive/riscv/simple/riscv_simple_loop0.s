addi gp, zero, 12
my_loop:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -1
  bge gp, zero, my_loop

addi gp, zero, 3
my_loop2:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -1
  bne gp, zero, my_loop2

addi gp, zero, 32
my_loop3:
  lw x10, 0(x11)
  addi x5, x6, -4
  addi x6, x5, 16
  sub x5, x6, x7
  mul x8, x10, x5
  sw x8, 0(x11)
  addi gp, gp, -4
  bne gp, zero, my_loop3
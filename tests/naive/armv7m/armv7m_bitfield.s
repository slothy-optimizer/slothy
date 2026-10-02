.syntax unified
.thumb

// Exercises the instruction classes added alongside this test: mov, movs,
// lsr with an immediate, the three-operand and two-operand immediate AND,
// bfi and bfc.
//
// The point is the read-modify-write pair. `bfi r3, ...` keeps the bits of r3
// outside the inserted field and `bfc r6, ...` keeps the bits of r6 outside
// the cleared one, so both depend on whatever produced that register. Were
// either declared with Rd as a pure output, the scheduler could hoist it
// above its producer and the routine would compute something else. The
// selftest assembles and runs both versions and compares them, so that shows
// up as a wrong answer instead of passing quietly.

.align 2
.global bitfield_func
.type bitfield_func, %function
bitfield_func:
  push {r4-r11, lr}

start:
  ldr  r1, [r0, #0]
  ldr  r2, [r0, #4]

  mov  r3, r1
  movs r4, r2
  lsr  r5, r1, #8
  and  r6, r2, #0x55555555
  and  r4, #0x0f0f0f0f

  bfi  r3, r5, #8, #8
  bfc  r6, #24, #8

  eor  r3, r3, r6
  eor  r3, r3, r4
  str  r3, [r0, #0]
end:

  pop {r4-r11, pc}

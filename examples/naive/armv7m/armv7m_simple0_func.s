.syntax unified
//.cpu cortex-m4 // llvm-mc does not like this...
.thumb // unicorn seems to get confused by this...

.align 2
.global my_func
.type my_func, %function
my_func:
  push {r4-r11, lr}

start:
ldr r8, [r0, #4]
add r8, r2, r8
eor.w r8, r8, r3
smlabt r3, r2, r2, r8
asrs r3, r3, #1
str r3, [r0, #4]
end:

  pop {r4-r11, pc}

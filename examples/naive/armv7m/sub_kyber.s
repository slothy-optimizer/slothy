.syntax unified
.cpu cortex-m4
.thumb

.align 2
.global pointwise_sub
.type pointwise_sub, %function
pointwise_sub:
  push {r4-r11, lr}

  movw r14, #25
  1:
    ldm r1!, {r3-r7}
    ldm r2!, {r8-r12}
    usub16 r3, r3, r8
    usub16 r4, r4, r9
    usub16 r5, r5, r10
    usub16 r6, r6, r11
    usub16 r7, r7, r12
    stm r0!, {r3-r7}

    subs.w r14, #1
  bne.w 1b

  pointwise_sub_final_start:
  ldm r1!, {r3-r5}
  ldm r2!, {r8-r10}
  usub16 r3, r3, r8
  usub16 r4, r4, r9
  usub16 r5, r5, r10
  stm r0!, {r3-r5}
  pointwise_sub_final_end:
  pop {r4-r11, pc}

.size pointwise_sub, .-pointwise_sub
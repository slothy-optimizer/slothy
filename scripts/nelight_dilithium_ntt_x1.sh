#!/usr/bin/env sh
echo ""
echo "==============================================================================="
echo "========= NTT DILITHIUM 123-45678 (vector, without reduction) ================="
echo "==============================================================================="
echo ""

echo "* Layer 123"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/naive/aarch64/ntt_dilithium_123_45678.s   \
                -l layer123_start\
                -c sw_pipelining.enabled=true                           \
                -o ../examples/opt/aarch64/ntt_dilithium_123_45678_opt0_x1.s  \
                -r ntt_dilithium_123_45678,ntt_dilithium_123_45678_opt0_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

echo "* Layer 45678"

# time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/naive/aarch64/ntt_dilithium_123_45678.s    \
#                 -l layer45678_start                                         \
#                 -o ../examples/opt/aarch64/ntt_dilithium_123_45678_opt_x1.s       \
#                 -r ntt_dilithium_123_45678,ntt_dilithium_123_45678_opt_x1 \
#                 -c inputs_are_outputs \
#                 -c reserved_regs="[x3,x30,sp]"                                  \
#                 -c sw_pipelining.enabled=true                               \
#                 -c sw_pipelining.halving_heuristic=True \
#                 -c split_heuristic \
#                 -c split_heuristic_factor=3 \
#                 -c sw_pipelining.unroll=2 \
#                 -c split_heuristic_preprocess_naive_interleaving \
#                 -c constraints.stalls_first_attempt=16 \
#                 -c timeout=300

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/opt/aarch64/ntt_dilithium_123_45678_opt0_x1.s    \
                -l layer45678_start                                         \
                -o ../examples/opt/aarch64/ntt_dilithium_123_45678_opt_x1.s       \
                -r ntt_dilithium_123_45678_opt0_x1,ntt_dilithium_123_45678_opt_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x3,x30,sp]"                                  \
                -c sw_pipelining.enabled=true                               \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

echo ""
echo "==============================================================================="
echo "========= NTT DILITHIUM 123-45678 (manual st4, without reduction) ============="
echo "==============================================================================="
echo ""

echo "* Layer 123"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/naive/aarch64/ntt_dilithium_123_45678_manual_st4.s   \
                -l layer123_start\
                -c sw_pipelining.enabled=true                           \
                -o ../examples/opt/aarch64/ntt_dilithium_123_45678_manual_st4_opt0_x1.s  \
                -r ntt_dilithium_123_45678_manual_st4,ntt_dilithium_123_45678_manual_st4_opt0_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

echo "* Layer 45678"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/opt/aarch64/ntt_dilithium_123_45678_manual_st4_opt0_x1.s    \
                -l layer45678_start                                         \
                -o ../examples/opt/aarch64/ntt_dilithium_123_45678_manual_st4_opt_x1.s       \
                -r ntt_dilithium_123_45678_manual_st4_opt0_x1,ntt_dilithium_123_45678_manual_st4_opt_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x3,x30,sp]"                                  \
                -c sw_pipelining.enabled=true                               \
                -c sw_pipelining.halving_heuristic=True \
                -c split_heuristic \
                -c split_heuristic_factor=2 \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

echo ""
echo "==============================================================================="
echo "========= NTT DILITHIUM 1234-5678 (vector, without reduction) ================="
echo "==============================================================================="
echo ""

echo "* Layer 1234"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/naive/aarch64/ntt_dilithium_1234_5678.s   \
                -l layer1234_start                          \
                -o ../examples/opt/aarch64/ntt_dilithium_1234_5678_opt0_x1.s  \
                -r ntt_dilithium_1234_5678,ntt_dilithium_1234_5678_opt0_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c sw_pipelining.enabled=true                               \
                -c sw_pipelining.halving_heuristic=True \
                -c split_heuristic \
                -c split_heuristic_factor=2 \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300


echo "* Layer 5678"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 ../examples/opt/aarch64/ntt_dilithium_1234_5678_opt0_x1.s    \
                -l layer5678_start                                         \
                -o ../examples/opt/aarch64/ntt_dilithium_1234_5678_opt_x1.s       \
                -r ntt_dilithium_1234_5678_opt0_x1,ntt_dilithium_1234_5678_opt_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x3,x30,sp]"                                  \
                -c sw_pipelining.enabled=true                               \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

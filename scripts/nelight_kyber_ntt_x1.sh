#!/usr/bin/env sh
cd "${0%/*}"/..

echo ""
echo "=============================================================================="
echo "========= NTT KYBER 123-4567 (all vector, with reduction)=== ================="
echo "=============================================================================="
echo ""

time ./nelightx1-cli  examples/naive/aarch64/ntt_kyber_123_4567.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_opt_x1.s  \
                -r ntt_kyber_123_4567,ntt_kyber_123_4567_opt_x1 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=16                  \
                -c timeout=240

echo ""
echo "=============================================================================="
echo "====== NTT KYBER 123-4567 (vector loads via scalar, with reduction) =========="
echo "=============================================================================="
echo ""

time ./nelightx1-cli  examples/naive/aarch64/ntt_kyber_123_4567_scalar_load.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_load_opt_x1.s  \
                -r ntt_kyber_123_4567_scalar_load,ntt_kyber_123_4567_scalar_load_opt_x1 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=16 \
                -c timeout=120

echo ""
echo "=============================================================================="
echo "====== NTT KYBER 123-4567 (vector stores via scalar, with reduction) ========="
echo "=============================================================================="
echo ""

time ./nelightx1-cli  examples/naive/aarch64/ntt_kyber_123_4567_scalar_store.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_store_opt_x1.s  \
                -r ntt_kyber_123_4567_scalar_store,ntt_kyber_123_4567_scalar_store_opt_x1 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c inputs_are_outputs \
                -c constraints.stalls_first_attempt=16 \
                -c timeout=120

echo ""
echo "=============================================================================="
echo "=== NTT KYBER 123-4567 (vector loads+stores via scalar, with reduction) ======"
echo "=============================================================================="
echo ""

time ./nelightx1-cli  examples/naive/aarch64/ntt_kyber_123_4567_scalar_load_store.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_load_store_opt_x1.s  \
                -r ntt_kyber_123_4567_scalar_load_store,ntt_kyber_123_4567_scalar_load_store_opt_x1 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=16 \
                -c timeout=120

echo ""
echo "=========================================================="
echo "=== NTT KYBER 123-4567 (manual ST4, with reduction) ======"
echo "=========================================================="
echo ""

time ./nelightx1-cli  examples/naive/aarch64/ntt_kyber_123_4567_manual_st4.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_manual_st4_opt_x1.s  \
                -r ntt_kyber_123_4567_manual_st4,ntt_kyber_123_4567_manual_st4_opt_x1 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=16 \
                -c timeout=120

echo ""
echo "=============================================================================="
echo "========= NTT KYBER 1234-567 (all vector, with reduction)=== ================="
echo "=============================================================================="
echo ""

echo "* Layer 1234"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 examples/naive/aarch64/ntt_kyber_1234_567.s   \
                -l layer1234_start                          \
                -o examples/opt/aarch64/ntt_kyber_1234_567_opt0_x1.s  \
                -r ntt_kyber_1234_567,ntt_kyber_1234_567_opt0_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c sw_pipelining.enabled=true                               \
                -c sw_pipelining.halving_heuristic=True \
                -c split_heuristic \
                -c split_heuristic_factor=2 \
                -c split_heuristic_stepsize=0.05 \
                -c split_heuristic_repeat=4 \
                -c constraints.stalls_first_attempt=32 \
                -c timeout=300

echo "* Layer 567"

time ../slothy-cli Arm_AArch64 Arm_Cortex_X1 examples/opt/aarch64/ntt_kyber_1234_567_opt0_x1.s    \
                -l layer567_start                                         \
                -o examples/opt/aarch64/ntt_kyber_1234_567_opt_x1.s       \
                -r ntt_kyber_1234_567_opt0_x1,ntt_kyber_1234_567_opt_x1 \
                -c inputs_are_outputs \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                                  \
                -c sw_pipelining.enabled=true                               \
                -c constraints.stalls_first_attempt=16 \
                -c sw_pipelining.minimize_overlapping=False             \
                -c timeout=300

cd "${0%/*}"
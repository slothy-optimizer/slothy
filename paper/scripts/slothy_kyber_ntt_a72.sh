#!/usr/bin/env sh

# Kyber NTT for Cortex-A72
#
# Supporting material for
#
# "Fast and Clean: Auditable high-performance assembly via constraint solving"
# https://eprint.iacr.org/2022/1303.pdf

set -e

SLOTHY_DIR=../../
CLEAN_DIR=../clean
OPT_DIR=../opt

LOG_DIR=logs
mkdir -p $LOG_DIR

REDIRECT_OUTPUT="--log --logdir=${LOG_DIR}"
if [ "$SILENT" = "Y" ]; then
    REDIRECT_OUTPUT="${REDIRECT_OUTPUT} --silent"
fi

echo "* Kyber NTT, Cortex-A72, 123-4567 (all vector, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend       \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567.s                      \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_opt_a72.s                \
         -r ntt_kyber_123_4567,ntt_kyber_123_4567_opt_a72               \
         -l layer123_start                                              \
         -l layer4567_start                                             \
         -c sw_pipelining.enabled=true                                  \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"               \
         -c inputs_are_outputs                                          \
         -c sw_pipelining.minimize_overlapping=False                    \
         -c constraints.stalls_first_attempt=64 -c variable_size        \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "* Kyber NTT, Cortex-A72, 123-4567 (vector loads via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend                       \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_load.s                          \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_load_opt_a72.s                    \
         -r ntt_kyber_123_4567_scalar_load,ntt_kyber_123_4567_scalar_load_opt_a72       \
         -l layer123_start                                                              \
         -l layer4567_start                                                             \
         -c sw_pipelining.enabled=true                                                  \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                               \
         -c inputs_are_outputs                                                          \
         -c sw_pipelining.minimize_overlapping=False                                    \
         -c constraints.stalls_first_attempt=64 -c variable_size                        \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "* Kyber NTT, Cortex-A72, 123-4567 (vector stores via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend                       \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_store.s                         \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_store_opt_a72.s                   \
         -r ntt_kyber_123_4567_scalar_store,ntt_kyber_123_4567_scalar_store_opt_a72     \
         -l layer123_start                                                              \
         -l layer4567_start                                                             \
         -c sw_pipelining.enabled=true                                                  \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                               \
         -c sw_pipelining.minimize_overlapping=False                                    \
         -c inputs_are_outputs                                                          \
         -c constraints.stalls_first_attempt=64 -c variable_size                        \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "* Kyber NTT, Cortex-A72, 123-4567 (vector loads+stores via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend                               \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_load_store.s                            \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_load_store_opt_a72.s                      \
         -r ntt_kyber_123_4567_scalar_load_store,ntt_kyber_123_4567_scalar_load_store_opt_a72   \
         -l layer123_start                                                                      \
         -l layer4567_start                                                                     \
         -c sw_pipelining.enabled=true                                                          \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                                       \
         -c inputs_are_outputs                                                                  \
         -c sw_pipelining.minimize_overlapping=False                                            \
         -c constraints.stalls_first_attempt=64 -c variable_size                                \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "* Kyber NTT, Cortex-A72, 123-4567 (manual ST4, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend               \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_manual_st4.s                   \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_manual_st4_opt_a72.s             \
         -r ntt_kyber_123_4567_manual_st4,ntt_kyber_123_4567_manual_st4_opt_a72 \
         -l layer123_start                                                      \
         -l layer4567_start                                                     \
         -c sw_pipelining.enabled=true                                          \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                       \
         -c inputs_are_outputs                                                  \
         -c sw_pipelining.minimize_overlapping=False                            \
         -c constraints.stalls_first_attempt=64 -c variable_size                \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "* Kyber NTT, Cortex-A72, 1234-567 (all vector, with reduction)"

echo "** Layer 1234"
time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend       \
            ${CLEAN_DIR}/neon/ntt_kyber_1234_567.s                      \
         -o ${OPT_DIR}/neon/ntt_kyber_1234_567_opt_a72.s                \
         -r ntt_kyber_1234_567,ntt_kyber_1234_567_opt_a72               \
         -l layer1234_start                                             \
         -c sw_pipelining.enabled=true                                  \
         -c sw_pipelining.halving_heuristic=True                        \
         -c split_heuristic                                             \
         -c split_heuristic_factor=2                                    \
         -c constraints.stalls_first_attempt=40                         \
         -c split_heuristic_stepsize=0.1                                \
         -c split_heuristic_repeat=4                                    \
         -c max_solutions=64                                            \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x30,sp]"                  \
         -c inputs_are_outputs                                          \
         -c sw_pipelining.minimize_overlapping=False                    \
         -c variable_size                                               \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

echo "** Layer 567"
time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A72_frontend       \
            ${OPT_DIR}/neon/ntt_kyber_1234_567_opt_a72.s                \
         -o ${OPT_DIR}/neon/ntt_kyber_1234_567_opt_a72.s                \
         -r ntt_kyber_1234_567_opt_a72,ntt_kyber_1234_567_opt_a72       \
         -l layer567_start                                              \
         -c sw_pipelining.enabled=true                                  \
         -c constraints.stalls_first_attempt=40                         \
         -c max_solutions=64                                            \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x30,sp]"                  \
         -c inputs_are_outputs                                          \
         -c sw_pipelining.minimize_overlapping=False                    \
         -c variable_size                                               \
         $SLOTHY_FLAGS $REDIRECT_OUTPUT

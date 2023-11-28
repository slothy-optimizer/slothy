#!/usr/bin/env sh

# Kyber NTT for Cortex-A55
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
if [ -n "$SILENT" ]; then
    REDIRECT_OUTPUT="${REDIRECT_OUTPUT} --silent"
fi

echo "* Kyber NTT, Cortex-A55, 123-4567 (all vector, with reduction)"
time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55         \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567.s               \
         -l layer123_start                                       \
         -l layer4567_start                                      \
         -c sw_pipelining.enabled=true                           \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_opt_a55.s         \
         -r ntt_kyber_123_4567,ntt_kyber_123_4567_opt_a55        \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"        \
         -c inputs_are_outputs                                   \
         -c sw_pipelining.minimize_overlapping=False             \
         -c constraints.stalls_first_attempt=64 -c variable_size \
         ${REDIRECT_OUTPUT}

echo "* Kyber NTT, Cortex-A55, 123-4567 (vector loads via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_load.s                          \
         -l layer123_start                                                              \
         -l layer4567_start                                                             \
         -c sw_pipelining.enabled=true                                                  \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_load_opt_a55.s                    \
         -r ntt_kyber_123_4567_scalar_load,ntt_kyber_123_4567_scalar_load_opt_a55       \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                               \
         -c inputs_are_outputs                                                          \
         -c sw_pipelining.minimize_overlapping=False                                    \
         -c constraints.stalls_first_attempt=64                                         \
         -c variable_size                                                               \
         ${REDIRECT_OUTPUT}

echo "* Kyber NTT, Cortex-A55, 123-4567 (vector stores via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                \
            ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_store.s                         \
         -l layer123_start                                                              \
         -l layer4567_start                                                             \
         -c sw_pipelining.enabled=true                                                  \
         -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_store_opt_a55.s                   \
         -r ntt_kyber_123_4567_scalar_store,ntt_kyber_123_4567_scalar_store_opt_a55     \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                               \
         -c sw_pipelining.minimize_overlapping=False                                    \
         -c inputs_are_outputs                                                          \
         -c constraints.stalls_first_attempt=64                                         \
         -c variable_size                                                               \
         ${REDIRECT_OUTPUT}

echo "* Kyber NTT, Cortex-A55, 123-4567 (vector loads+stores via scalar, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                        \
          ${CLEAN_DIR}/neon/ntt_kyber_123_4567_scalar_load_store.s                              \
       -l layer123_start                                                                        \
       -l layer4567_start                                                                       \
       -c sw_pipelining.enabled=true                                                            \
       -o ${OPT_DIR}/neon/ntt_kyber_123_4567_scalar_load_store_opt_a55.s                        \
       -r ntt_kyber_123_4567_scalar_load_store,ntt_kyber_123_4567_scalar_load_store_opt_a55     \
       -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                                         \
       -c inputs_are_outputs                                                                    \
       -c sw_pipelining.minimize_overlapping=False                                              \
       -c constraints.stalls_first_attempt=64 -c variable_size                                  \
         ${REDIRECT_OUTPUT}

echo "* Kyber NTT, Cortex-A55, 123-4567 (manual ST4, with reduction)"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                        \
          ${CLEAN_DIR}/neon/ntt_kyber_123_4567_manual_st4.s                     \
       -l layer123_start                                                        \
       -l layer4567_start                                                       \
       -c sw_pipelining.enabled=true                                            \
       -o ${OPT_DIR}/neon/ntt_kyber_123_4567_manual_st4_opt_a55.s               \
       -r ntt_kyber_123_4567_manual_st4,ntt_kyber_123_4567_manual_st4_opt_a55   \
       -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                         \
       -c inputs_are_outputs                                                    \
       -c sw_pipelining.minimize_overlapping=False                              \
       -c constraints.stalls_first_attempt=64 -c variable_size                  \
         ${REDIRECT_OUTPUT}

cd "${0%/*}"

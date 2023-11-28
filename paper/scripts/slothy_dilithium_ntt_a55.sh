#!/usr/bin/env sh

# Dilithium NTT for Cortex-A55
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

echo "* Dilithium NTT, Cortex-A55, 123-45678 (vector, without reduction)"
echo "** Layer 123"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                        \
            ${CLEAN_DIR}/neon/ntt_dilithium_123_45678.s                         \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_opt0_a55.s                  \
         -l layer123_start                                                      \
         -r ntt_dilithium_123_45678,ntt_dilithium_123_45678_opt0_a55            \
         -c sw_pipelining.enabled=true                                          \
         -c inputs_are_outputs                                                  \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,v8,x30,sp]"                    \
         -c sw_pipelining.minimize_overlapping=False                            \
         -c constraints.stalls_first_attempt=110 -c variable_size               \
         $REDIRECT_OUTPUT

echo "** Layer 45678"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                       \
            ${OPT_DIR}/neon/ntt_dilithium_123_45678_opt0_a55.s                 \
         -l layer45678_start                                                   \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_opt_a55.s                  \
         -r ntt_dilithium_123_45678_opt0_a55,ntt_dilithium_123_45678_opt_a55   \
         -c sw_pipelining.enabled=true                                         \
         -c inputs_are_outputs                                                 \
         -c reserved_regs="[x3,x30,sp]"                                        \
         -c sw_pipelining.minimize_overlapping=False                           \
         -c constraints.stalls_first_attempt=40                                \
         $REDIRECT_OUTPUT

echo "* Dilithium NTT, Cortex-A55, 123-45678 (vector with scalar loads, without reduction)"
echo "** Layer 123"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                \
            ${CLEAN_DIR}/neon/ntt_dilithium_123_45678_w_scalar.s                        \
         -l layer123_start                                                              \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_w_scalar_opt0_a55.s                 \
         -r ntt_dilithium_123_45678_w_scalar,ntt_dilithium_123_45678_w_scalar_opt0_a55  \
         -c sw_pipelining.enabled=true                                                  \
         -c inputs_are_outputs                                                          \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,v8,x30,sp]"                            \
         -c sw_pipelining.minimize_overlapping=False                                    \
         -c constraints.stalls_first_attempt=110 -c variable_size                       \
         $REDIRECT_OUTPUT                                                               \

echo "** Layer 45678"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                       \
            ${OPT_DIR}/neon/ntt_dilithium_123_45678_w_scalar_opt0_a55.s                        \
         -l layer45678_start                                                                   \
         -c sw_pipelining.enabled=true                                                         \
         -c inputs_are_outputs                                                                 \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_w_scalar_opt_a55.s                         \
         -r ntt_dilithium_123_45678_w_scalar_opt0_a55,ntt_dilithium_123_45678_w_scalar_opt_a55 \
         -c reserved_regs="[x3,x30,sp]"                                                        \
         -c sw_pipelining.minimize_overlapping=False                                           \
         -c constraints.stalls_first_attempt=40                                                \
         $REDIRECT_OUTPUT

echo "* Dilithium NTT, Cortex-A55, 123-45678 (manual st4, without reduction)"
echo "** Layer 123"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                   \
            ${CLEAN_DIR}/neon/ntt_dilithium_123_45678_manual_st4.s                         \
         -l layer123_start                                                                 \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_manual_st4_opt0_a55.s                  \
         -r ntt_dilithium_123_45678_manual_st4,ntt_dilithium_123_45678_manual_st4_opt0_a55 \
         -c sw_pipelining.enabled=true                                                     \
         -c inputs_are_outputs                                                             \
         -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"                                  \
         -c sw_pipelining.minimize_overlapping=False                                       \
         -c constraints.stalls_first_attempt=110                                           \
         -c variable_size                                                                  \
         $REDIRECT_OUTPUT

echo "** Layer 45678"

time ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                                           \
            ${OPT_DIR}/neon/ntt_dilithium_123_45678_manual_st4_opt0_a55.s                          \
         -l layer45678_start                                                                       \
         -o ${OPT_DIR}/neon/ntt_dilithium_123_45678_manual_st4_opt_a55.s                           \
         -r ntt_dilithium_123_45678_manual_st4_opt0_a55,ntt_dilithium_123_45678_manual_st4_opt_a55 \
         -c inputs_are_outputs                                                                     \
         -c reserved_regs="[x3,x30,sp]"                                                            \
         -c sw_pipelining.enabled=true                                                             \
         -c sw_pipelining.halving_heuristic=True                                                   \
         -c split_heuristic                                                                        \
         -c split_heuristic_factor=2                                                               \
         -c constraints.stalls_first_attempt=40                                                    \
         $REDIRECT_OUTPUT

cd "${0%/*}"

#!/usr/bin/env sh

# X25519 scalar multiplication on Cortex-A55
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

echo "* X25519, Cortex-A55"

echo "** Step 0: Resolve symbolic registers"
${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                          \
       ${CLEAN_DIR}/neon/X25519-AArch64-simple.s                             \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_nosymvars.s                     \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c constraints.allow_reordering=False                                    \
    -c constraints.functional_only=True                                      \
    $REDIRECT_OUTPUT

echo "** Step 1: Preprocessing"
${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                          \
       ${OPT_DIR}/neon/X25519-AArch64-simple_nosymvars.s                     \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process0.s               \
    -r x25519_scalarmult_alt_orig,x25519_scalarmult_alt_unfold_process0      \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c split_heuristic -c split_heuristic_repeat=0                           \
    -c split_heuristic_preprocess_naive_interleaving                         \
    $REDIRECT_OUTPUT

echo "** Steps 2-6: Stepwise optimization, ignoring latencies"
# The goal here is to get a good amount of interleaving
# The best order of subregions is still TBD, but presently we 'comb' all stalls
# towards the middle of the code and repeat the process. The idea/hope is that
# by doing this multiple times, the stalls will eventually be absorbed.

echo "*** Step 2"
i=0
    ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                      \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=300                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0,1]"                                        \
    -c objective_precision=0.1                                               \
    -c split_heuristic_stepsize=0.1                                          \
    -c split_heuristic_factor=6                                              \
    -c constraints.model_latencies=False                                     \
    $REDIRECT_OUTPUT

echo "*** Step 3"
i=1
    ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                      \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=180                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0,0.6]"                                      \
    -c objective_precision=0.1                                               \
    -c constraints.move_stalls_to_bottom                                     \
    -c split_heuristic_stepsize=0.1                                          \
    -c split_heuristic_factor=4                                              \
    -c constraints.model_latencies=False                                     \
    $REDIRECT_OUTPUT

echo "*** Step 4"
i=2
    ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                      \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=240                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0.3,1]"                                      \
    -c objective_precision=0.1                                               \
    -c constraints.move_stalls_to_top                                        \
    -c split_heuristic_bottom_to_top                                         \
    -c split_heuristic_stepsize=0.2                                          \
    -c split_heuristic_factor=6                                              \
    -c split_heuristic_repeat=1                                              \
    -c constraints.model_latencies=False                                     \
    $REDIRECT_OUTPUT

echo "*** Step 5"
i=3
    ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                      \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=240                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0.3,1]"                                      \
    -c objective_precision=0.1                                               \
    -c constraints.move_stalls_to_top                                        \
    -c split_heuristic_stepsize=0.2                                          \
    -c split_heuristic_factor=6                                              \
    -c split_heuristic_repeat=1                                              \
    -c constraints.model_latencies=False                                     \
    $REDIRECT_OUTPUT

# Finally, also consider latencies

echo "*** Step 6"
i=4
   ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                       \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=300                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0,1]"                                        \
    -c objective_precision=0.1                                               \
    -c split_heuristic_stepsize=0.05                                         \
    -c split_heuristic_optimize_seam=10                                      \
    -c split_heuristic_factor=8                                              \
    -c split_heuristic_repeat=1                                              \
    $REDIRECT_OUTPUT

echo "*** Step 7"
i=5
   ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                       \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s     \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=300                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0,1]"                                        \
    -c split_heuristic_bottom_to_top=True                                    \
    -c objective_precision=0.1                                               \
    -c split_heuristic_stepsize=0.05                                         \
    -c split_heuristic_optimize_seam=10                                      \
    -c constraints.move_stalls_to_top                                        \
    -c split_heuristic_factor=8                                              \
    -c split_heuristic_repeat=2                                             \
    $REDIRECT_OUTPUT

echo "*** Step 8"
i=6
   ${SLOTHY_DIR}/slothy-cli Arm_AArch64 Arm_Cortex_A55                       \
       ${OPT_DIR}/neon/X25519-AArch64-simple_unfold_process${i}.s            \
    -o ${OPT_DIR}/neon/X25519-AArch64-simple_opt.s                           \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_opt        \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=300                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0,1]"                                        \
    -c objective_precision=0.1                                               \
    -c split_heuristic_stepsize=0.05                                         \
    -c split_heuristic_optimize_seam=10                                      \
    -c constraints.move_stalls_to_top                                        \
    -c split_heuristic_factor=8                                              \
    $REDIRECT_OUTPUT

cd "${0%/*}"

#!/usr/bin/env sh

# X25519 scalar multiplication on Cortex-A55
#
# Supporting material for
#
# "Fast and Clean: Auditable high-performance assembly via constraint solving"
# https://eprint.iacr.org/2022/1303.pdf

# Step 0: Resolve symbolic registers
../slothy-cli Arm_AArch64 Arm_Cortex_A55                                      \
   clean/neon/X25519-AArch64-simple.s                            \
    -o opt/neon/X25519-AArch64-simple_nosymvars.s                \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c constraints.allow_reordering=False                                    \
    -c constraints.functional_only=True


# Step 1: Preprocessing
../slothy-cli Arm_AArch64 Arm_Cortex_A55                                      \
   opt/neon/X25519-AArch64-simple_nosymvars.s                    \
    -o opt/neon/X25519-AArch64-simple_unfold_process0.s          \
    -r x25519_scalarmult_alt_orig,x25519_scalarmult_alt_unfold_process0      \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c split_heuristic -c split_heuristic_repeat=0                           \
    -c split_heuristic_preprocess_naive_interleaving


# Steps 2-4: Stepwise optimization, __ignoring latencies__
# The goal here is to get a good amount of interleaving
# The best order of subregions is still TBD, but presently we 'comb' all stalls
# towards the middle of the code and repeat the process. The idea/hope is that
# by doing this multiple times, the stalls will eventually be absorbed.
i=0
    ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                  \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s\
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
    -c constraints.model_latencies=False

i=1
    ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                  \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s\
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
    -c constraints.model_latencies=False

i=2
    ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                  \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s\
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
    -c split_heuristic_stepsize=0.08                                         \
    -c split_heuristic_factor=6                                              \
    -c split_heuristic_repeat=3                                              \
    -c constraints.model_latencies=False

i=3
    ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                  \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s   \
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
    -c split_heuristic_stepsize=0.05                                         \
    -c split_heuristic_factor=5                                              \
    -c split_heuristic_repeat=3                                              \
    -c split_heuristic_abort_cycle_at=8                                      \
    -c constraints.model_latencies=False

i=4
    ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                  \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s   \
    -r x25519_scalarmult_alt_unfold_process${i},x25519_scalarmult_alt_unfold_process$((${i}+1)) \
    -c inputs_are_outputs -c outputs="[x0]"                                  \
    -s mainloop -e end_label                                                 \
    -c variable_size                                                         \
    -c max_solutions=512                                                     \
    -c timeout=180                                                           \
    -c constraints.stalls_first_attempt=32                                   \
    -c split_heuristic                                                       \
    -c split_heuristic_region="[0.2,1]"                                      \
    -c objective_precision=0.1                                               \
    -c constraints.move_stalls_to_top                                        \
    -c split_heuristic_stepsize=0.05                                         \
    -c split_heuristic_factor=5                                              \
    -c split_heuristic_repeat=3                                              \
    -c split_heuristic_abort_cycle_at=5                                      \
    -c constraints.model_latencies=False

# Finally, also consider latencies

i=5
   ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                   \
   opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
    -o opt/neon/X25519-AArch64-simple_unfold_process$((${i}+1)).s   \
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
    -c split_heuristic_repeat=10


i=6
  ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                   \
  opt/neon/X25519-AArch64-simple_unfold_process${i}.s           \
   -o opt/neon/X25519-AArch64-simple_opt.s                      \
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
   -c split_heuristic_factor=8                                              \
   -c split_heuristic_repeat=3

i=6
  ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                   \
  opt/neon/X25519-AArch64-simple_unfold_preprocess${i}.s        \
   -o opt/neon/X25519-AArch64-simple_unfold_preprocess$((${i}+1)).s   \
   -r x25519_scalarmult_alt_unfold_preprocess${i},x25519_scalarmult_alt_unfold_preprocess$((${i}+1)) \
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
   -c split_heuristic_repeat=3

i=7
  ../slothy-cli Arm_AArch64 Arm_Cortex_A55                                   \
  opt/neon/X25519-AArch64-simple_unfold_preprocess${i}.s        \
   -o opt/neon/X25519-AArch64-simple_opt.s                      \
   -r x25519_scalarmult_alt_unfold_preprocess${i},x25519_scalarmult_opt     \
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
   -c split_heuristic_repeat=3                                              \
   -c constraints.move_stalls_to_top

cd "${0%/*}"

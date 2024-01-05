# Fixed point and floating FFT optimization scripts, targeting Cortex-M55 and Cortex-M85
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

${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_M55                        \
  ${CLEAN_DIR}/helium/flt_r4_fft/base_ref.s                             \
    -l flt_radix4_fft_loop_start                                        \
    -r floatingpoint_radix4_fft_ref,floatingpoint_radix4_fft_base       \
    -c constraints.allow_reordering=False                               \
    -c constraints.functional_only=True                                 \
    -c visualize_reordering=False                                       \
    -o ${OPT_DIR}/helium/flt_r4_fft/base_ref.s                          \
    $SLOTHY_FLAGS $REDIRECT_OUTPUT

for uarch in M55 M85; do
    echo "* Floating point FFT, Cortex-${uarch}"
    ${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_$uarch                          \
      ${CLEAN_DIR}/helium/flt_r4_fft/base_symbolic.s                             \
        -c variable_size -c constraints.stalls_first_attempt=16                  \
        -c sw_pipelining.enabled=True                                            \
        -c inputs_are_outputs                                                    \
        -l flt_radix4_fft_loop_start                                             \
        -c timeout=300                                                           \
        -r floatingpoint_radix4_fft_symbolic,floatingpoint_radix4_fft_opt_$uarch \
        -o ${OPT_DIR}/helium/flt_r4_fft/floatingpoint_radix4_fft_opt_$uarch.s    \
        $SLOTHY_FLAGS $REDIRECT_OUTPUT;
done

# Fixed point FFT

${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_M55                                 \
             ${CLEAN_DIR}/helium/fx_r4_fft/base_ref.s                            \
             -c constraints.allow_reordering=False                               \
             -c constraints.functional_only=True                                 \
             -r fixedpoint_radix4_fft_ref,fixedpoint_radix4_fft_base             \
             -l fixedpoint_radix4_fft_loop_start                                 \
             -c visualize_reordering=False                                       \
             -o ${OPT_DIR}/helium/fx_r4_fft/base_concrete.s                      \
             $SLOTHY_FLAGS $REDIRECT_OUTPUT

for uarch in M55 M85; do
    echo "* Fixed point FFT, Cortex-${uarch}"
    ${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_$uarch                    \
      ${CLEAN_DIR}/helium/fx_r4_fft/base_symbolic.s                        \
        -c sw_pipelining.enabled=True                                      \
        -c inputs_are_outputs                                              \
        -c variable_size -c constraints.stalls_first_attempt=16            \
        -l fixedpoint_radix4_fft_loop_start                                \
        -c timeout=300                                                     \
        -r fixedpoint_radix4_fft_symbolic,fixedpoint_radix4_fft_opt_$uarch \
        -c sw_pipelining.minimize_overlapping                              \
        -o ${OPT_DIR}/helium/fx_r4_fft/fixedpoint_radix4_fft_opt_$uarch.s  \
        $SLOTHY_FLAGS $REDIRECT_OUTPUT;
done

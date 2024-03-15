# Toy example from
# "Fast and ../Clean: Auditable high-performance assembly via constraint solving"
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

${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_M55                    \
       ${CLEAN_DIR}/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx.s.tmpl    \
    -l start                                                        \
    -c constraints.functional_only                                  \
    -c constraints.allow_renaming=False                             \
    -c constraints.allow_reordering=False                           \
    -o ${CLEAN_DIR}/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx.s         \
    -c /visualize_reordering                                        \
    $SLOTHY_FLAGS $REDIRECT_OUTPUT

for uarch in M55 M85; do for i in 1 2 4; do
  echo "* Squared magnitude, Cortex-${uarch}, unroll x${i}"
  ${SLOTHY_DIR}/slothy-cli Arm_v81M Arm_Cortex_$uarch                                   \
         ${CLEAN_DIR}/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx.s                           \
      -o ${OPT_DIR}/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx_opt_${uarch}_unroll${i}.s     \
      -r cmplx_mag_sqr_fx,cmplx_mag_sqr_fx_opt_${uarch}_unroll${i}                      \
      -l start                                                                          \
      -c inputs_are_outputs                                                             \
      -c sw_pipelining.enabled=True                                                     \
      -c sw_pipelining.unroll=$i                                                        \
      -c constraints.stalls_first_attempt=1                                             \
      -c timeout=$((10*$i))                                                             \
      -c /sw_pipelining.minimize_overlapping                                            \
      -c variable_size $SLOTHY_FLAGS $REDIRECT_OUTPUT ;
  done; done

# Toy example from
# "Fast and Clean: Auditable high-performance assembly via constraint solving"
# https://eprint.iacr.org/2022/1303.pdf

../slothy-cli Arm_v81M Arm_Cortex_M55 ../examples/naive/cmplx_mag_sqr/cmplx_mag_sqr_fx.s.tmpl                   \
  -l start -c constraints.functional_only -c constraints.allow_renaming=False -c constraints.allow_reordering=False \
  -o ../examples/naive/cmplx_mag_sqr/cmplx_mag_sqr_fx.s -c /visualize_reordering

for uarch in M55 M85; do for i in 1 2 4; do
    ../slothy-cli Arm_v81M Arm_Cortex_$uarch ../examples/naive/cmplx_mag_sqr/cmplx_mag_sqr_fx.s        \
      -l start -c sw_pipelining.enabled=True -c sw_pipelining.unroll=$i                            \
      -r cmplx_mag_sqr_fx,cmplx_mag_sqr_fx_opt_${uarch}_unroll${i}                                   \
      -o ../examples/opt/cmplx_mag_sqr/cmplx_mag_sqr_fx_opt_${uarch}_unroll${i}.s                     \
      -c constraints.stalls_first_attempt=1 -c timeout=$((10*$i))                                   \
      -c /sw_pipelining.minimize_overlapping -c variable_size;
  done; done

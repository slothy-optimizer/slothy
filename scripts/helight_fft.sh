# floating point
../slothy-cli Arm_v81M Arm_Cortex_M55                        \
            ../examples/naive/flt_r4_fft/base_ref.s            \
            -l flt_radix4_fft_loop_start                    \
            -r floatingpoint_radix4_fft_ref,floatingpoint_radix4_fft_base \
            -c constraints.allow_reordering=False           \
            -c constraints.functional_only=True             \
            -c visualize_reordering=False                   \
            -o ../examples/opt/flt_r4_fft/base_ref.s

for uarch in M85 M55; do
    ../slothy-cli Arm_v81M Arm_Cortex_$uarch                        \
                 ../examples/naive/flt_r4_fft/base_symbolic.s         \
                 -c variable_size -c constraints.stalls_first_attempt=16  \
                 -c sw_pipelining.enabled=True                     \
                 -l flt_radix4_fft_loop_start                      \
                 -r floatingpoint_radix4_fft_symbolic,floatingpoint_radix4_fft_opt_$uarch \
                 -o ../examples/opt/flt_r4_fft/floatingpoint_radix4_fft_opt_$uarch.s;
done

#fixed-point
../slothy-cli Arm_v81M Arm_Cortex_M55                             \
             ../examples/naive/fx_r4_fft/base_ref.s            \
             -c constraints.allow_reordering=False               \
             -c constraints.functional_only=True                 \
             -r fixedpoint_radix4_fft_ref,fixedpoint_radix4_fft_base \
             -l fixedpoint_radix4_fft_loop_start                 \
             -c visualize_reordering=False                       \
             -o ../examples/opt/fx_r4_fft/base_concrete.s

for uarch in M55 M85; do
    ../slothy-cli Arm_v81M Arm_Cortex_$uarch                        \
                 ../examples/naive/fx_r4_fft/base_symbolic.s          \
                 -c sw_pipelining.enabled=True                     \
                 -c variable_size -c constraints.stalls_first_attempt=16  \
                 -l fixedpoint_radix4_fft_loop_start               \
                 -r fixedpoint_radix4_fft_symbolic,fixedpoint_radix4_fft_opt_$uarch \
                 -c sw_pipelining.minimize_overlapping               \
                 -o ../examples/opt/fx_r4_fft/fixedpoint_radix4_fft_opt_$uarch.s;
done

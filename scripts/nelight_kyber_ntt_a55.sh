#!/usr/bin/env sh
cd "${0%/*}"/..

echo ""
echo "=============================================================================="
echo "========= NTT KYBER 123-4567 (all vector, with reduction)=== ================="
echo "=============================================================================="
echo ""

time ./nelight55-cli examples/naive/aarch64/ntt_kyber_123_4567.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_opt_a55.s  \
                -r ntt_kyber_123_4567,ntt_kyber_123_4567_opt_a55 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=64 -c variable_size

echo ""
echo "=============================================================================="
echo "====== NTT KYBER 123-4567 (vector loads via scalar, with reduction) =========="
echo "=============================================================================="
echo ""

time ./nelight55-cli examples/naive/aarch64/ntt_kyber_123_4567_scalar_load.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_load_opt_a55.s  \
                -r ntt_kyber_123_4567_scalar_load,ntt_kyber_123_4567_scalar_load_opt_a55 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=64 -c variable_size

echo ""
echo "=============================================================================="
echo "====== NTT KYBER 123-4567 (vector stores via scalar, with reduction) ========="
echo "=============================================================================="
echo ""

time ./nelight55-cli examples/naive/aarch64/ntt_kyber_123_4567_scalar_store.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_store_opt_a55.s  \
                -r ntt_kyber_123_4567_scalar_store,ntt_kyber_123_4567_scalar_store_opt_a55 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c sw_pipelining.minimize_overlapping=False             \
                -c inputs_are_outputs \
                -c constraints.stalls_first_attempt=64 -c variable_size

echo ""
echo "=============================================================================="
echo "=== NTT KYBER 123-4567 (vector loads+stores via scalar, with reduction) ======"
echo "=============================================================================="
echo ""

time ./nelight55-cli examples/naive/aarch64/ntt_kyber_123_4567_scalar_load_store.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_scalar_load_store_opt_a55.s  \
                -r ntt_kyber_123_4567_scalar_load_store,ntt_kyber_123_4567_scalar_load_store_opt_a55 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=64 -c variable_size

echo ""
echo "=========================================================="
echo "=== NTT KYBER 123-4567 (manual ST4, with reduction) ======"
echo "=========================================================="
echo ""

time ./nelight55-cli examples/naive/aarch64/ntt_kyber_123_4567_manual_st4.s   \
                -l layer123_start\
                -l layer4567_start\
                -c sw_pipelining.enabled=true                           \
                -o examples/opt/aarch64/ntt_kyber_123_4567_manual_st4_opt_a55.s  \
                -r ntt_kyber_123_4567_manual_st4,ntt_kyber_123_4567_manual_st4_opt_a55 \
                -c reserved_regs="[x0,x1,x2,x3,x4,x5,x6,x30,sp]"         \
                -c inputs_are_outputs \
                -c sw_pipelining.minimize_overlapping=False             \
                -c constraints.stalls_first_attempt=64 -c variable_size

cd "${0%/*}"
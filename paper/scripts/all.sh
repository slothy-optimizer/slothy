#!/usr/bin/env sh

# Supporting material for
#
# "Fast and Clean: Auditable high-performance assembly via constraint solving"
# https://eprint.iacr.org/2022/1303.pdf

# Build all examples discussed in the paper

set -e

export SILENT=1

echo "================================================"
echo "  Re-optimizing all examples from SLOTHY paper  "
echo "================================================\n"

echo "NOTE: This will take a long time (at least a few hours). If there are problems"\
     "or you want to follow along what the scripts are doing in more detail, run the"\
     "respective scripts by hand.\n"

echo "If you want to follow progress of an individual command, do \"tail -f\" on the respective logfile in the \"logs\" directory.\n"

echo "Squared magnitude toy example ..."
time ./slothy_sqmag.sh

echo "FFT, Cortex-M55 and Cortex-M85..."
time ./slothy_fft.sh

echo "Dilithium NTT, Cortex-A55..."
time ./slothy_dilithium_ntt_a55.sh

echo "Dilithium NTT, Cortex-A72..."
time ./slothy_dilithium_ntt_a72.sh

echo "Kyber NTT, Cortex-A55..."
time ./slothy_kyber_ntt_a55.sh

echo "Kyber NTT, Cortex-A72..."
time ./slothy_kyber_ntt_a72.sh

echo "X25519, Cortex-A55..."
time ./slothy_x25519.sh

source slothy_ntt_helium.sh

echo "All done!"

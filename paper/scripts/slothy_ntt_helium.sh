#!/usr/bin/env sh

# Helium NTTs for Cortex-M55 and Cortex-M85
#
# Supporting material for
#
# "Fast and Clean: Auditable high-performance assembly via constraint solving"
# https://eprint.iacr.org/2022/1303.pdf

set -e

ARGS=""
if [ "$SILENT" = "Y" ]; then
    ARGS="$ARGS --silent"
fi
if [ "$NO_LOG" = "Y" ]; then
    ARGS="$ARGS --no-log"
fi

ARGS="$ARGS $ADDITIONAL_ARGS"

export PYTHONPATH=../../

echo "Kyber NTT, Cortex-M55, layer split 1-23-45-67, variant 0..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_1_23_45_67_no_trans_m55

echo "Kyber NTT, Cortex-M55, layer split 1-23-45-67, variant 1..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_1_23_45_67_no_trans_vld4_m55

echo "Kyber NTT, Cortex-M55, layer split 12-345-67..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_12_345_67_m55

echo "Kyber NTT, Cortex-M85, layer split 1-23-45-67, variant 0..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_1_23_45_67_no_trans_m85

echo "Kyber NTT, Cortex-M85, layer split 1-23-45-67, variant 1..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_1_23_45_67_no_trans_vld4_m85

echo "Kyber NTT, Cortex-M85, layer split 12-345-67..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_kyber_12_345_67_m85

echo "Dilithium NTT, Cortex-M55, layer split 12-34-56-78, variant 0..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_12_34_56_78_m55

echo "Dilithium NTT, Cortex-M55, layer split 12-34-56-78, variant 1..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_12_34_56_78_no_trans_vld4_m55

echo "Dilithium NTT, Cortex-M55, layer split 123-456-78..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_123_456_78_m55

echo "Dilithium NTT, Cortex-M85, layer split 12-34-56-78, variant 0..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_12_34_56_78_m85

echo "Dilithium NTT, Cortex-M85, layer split 12-34-56-78, variant 1..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_12_34_56_78_no_trans_vld4_m85

echo "Dilithium NTT, Cortex-M85, layer split 123-456-78..."

time python3 ./slothy_ntt_helium.py $ARGS --examples=ntt_dilithium_123_456_78_m85

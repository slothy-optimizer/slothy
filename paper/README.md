This directory contains supporting material for the paper [Fast and Clean: Auditable
high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303.pdf)
that introduced SLOTHY. It enables interested readers to:

1. Reproduce the SLOTHY optimizations described in the paper.
2. Test the functional correctness of the optimized code.
3. If suitable development boards are available, benchmark the performance of the optimized code.

For Step 1., only SLOTHY is needed. For Steps 2. and 3., we recommend and describe the use of the
[pqmx](https://github.com/slothy-optimizer/pqmx) and [pqax](https://github.com/slothy-optimizer/pqax)
repositories.

# Reproducing SLOTHY optimizations

Here we describe how to reproduce the SLOTHY optimizations described in the paper:
  - The Number Theoretic Transforms (NTT) underlying Kyber/ML-KEM and Dilithium/ML-DSA, optimized for Cortex-A55,
    Cortex-A72, Cortex-M55 and Cortex-M85.
  - An instance of the Fast Fourier Transform (FFT) in fixed-point and floating-point arithmetic,
    optimized for Cortex-M55 and Cortex-M85.
  - The X25519 scalar multiplication, optimized for Cortex-A55.

## Overview

The optimizations described in the SLOTHY paper are driven by the following scripts:

```
slothy_dilithium_ntt_a55.sh
slothy_dilithium_ntt_a72.sh
slothy_kyber_ntt_a55.sh
slothy_kyber_ntt_a72.sh
slothy_fft.sh
slothy_x25519.sh
slothy_sqmag.sh
```

Each script optimizes one or more 'base' version(s) of the corresponding workload from [examples/naive/](../examples/naive)
(for Armv8.1-M code) and [examples/naive/aarch64](../examples/naive/aarch64) (for AArch64 code) and stores the optimized
code in [examples/opt/](../examples/opt) and [examples/opt/aarch64/](../examples/opt/aarch64/), respectively. Optimized
source files is suffixed with `_opt` and the target microarchitecture: For example, one of the optimizations conducted
by `slothy_kyber_ntt_a55.sh` transforms
[examples/naive/aarch64/ntt_kyber_123_4567.s](../examples/naive/aarch64/ntt_kyber_123_4567.s) to
[examples/opt/aarch64/ntt_kyber_123_4567_opt_a55.s](../examples/opt/aarch64/ntt_kyber_123_4567_opt_a55.s).

## Setup

* Follow the [SLOTHY Readme](../README.md) to setup SLOTHY.

* Make sure the OR-Tools venv is enabled by running `source init.sh` from the SLOTHY base directory (see
  [README](../README.md)).

## Running the optimizations

* From [scripts/](./scripts/), run one of the optimization scripts, e.g.

```
./slothy_kyber_ntt_a55.sh
```

* Wait. You should see a fair amount of output in stdout, and some scripts take >1h even on a powerful machine.

* Upon success, find the optimized source files in [examples/opt/](../examples/opt). They should be structurally equal
  to the input files, with the base assembly sections replaced by the optimized kernels and the rescheduling permutation
  indicated through comments.

# Testing optimized code

## AArch64

TODO

## Armv8.1-M

TODO

# Benchmarking optimized code

## AArch64

TODO

## Armv8.1-M

TODO
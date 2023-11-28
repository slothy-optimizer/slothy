This directory contains supporting material for the paper [Fast and Clean: Auditable
high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303.pdf)
that introduced SLOTHY. It enables interested readers to:

1. `Optimize`: Reproduce the SLOTHY optimizations described in the paper.
2. `Test`: Verify the functional correctness of the optimized code.
3. `Benchmark`: If suitable development boards are available, evaluate the performance of the optimized code.

For `Optimize`, only the SLOTHY repository is needed. For `Test` and `Benchmark`, we recommend the use of the [pqmx](https://github.com/slothy-optimizer/pqmx) and [pqax](https://github.com/slothy-optimizer/pqax)
repositories. See the respective README's for setup instructions, or use the Dockerfile provided in
[Artifact](artifact).

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
scripts/slothy_dilithium_ntt_a55.sh
scripts/slothy_dilithium_ntt_a72.sh
scripts/slothy_fft.sh
scripts/slothy_kyber_ntt_a55.sh
scripts/slothy_kyber_ntt_a72.sh
scripts/slothy_ntt_helium.sh
scripts/slothy_sqmag.sh
scripts/slothy_x25519.sh
```

Each script optimizes one or more 'base' version(s) of the corresponding workload from [clean/helium/](./clean/helium/)
(for Armv8.1-M code) and [clean/neon](clean/neon) (for AArch64 code) and stores the optimized
code in [opt/helium](./opt/helium) and [opt/neon](./opt/neon), respectively. Optimized
source files is suffixed with `_opt` and the target microarchitecture: For example, one of the optimizations conducted
by `slothy_kyber_ntt_a55.sh` transforms
[clean/neon/ntt_dilithium_123_45678.s](./clean/neon/ntt_dilithium_123_45678.s) to
[opt/neon/ntt_dilithium_123_45678_opt_a55.s](./opt/neon/ntt_dilithium_123_45678_opt_a55.s).

## Setup

* Follow the [SLOTHY Readme](../README.md) to setup SLOTHY.

* Make sure the OR-Tools venv is enabled by running `source init.sh` from the SLOTHY base directory (see
  [README](../README.md)).

## Running the optimizations

* From [scripts/](./scripts/), run one of the optimization scripts, e.g.

```
./slothy_kyber_ntt_a55.sh
```

If you want to run all all optimizations, run `all.sh`. If you don't want to see any output from SLOTHY, prefix the
command with `SILENT=1`.

* Wait. Running all optimizations will take multiple hours.

* Upon success, find the optimized source files in [examples/opt/](../examples/opt). They should be structurally equal
  to the input files, with the base assembly sections replaced by the optimized kernels and the rescheduling permutation
  indicated through comments.

# Testing optimized code using pqax and pqmx

## AArch64

PQAX provides unit tests for the Kyber NTTs, Dilithium NTTs, and X25519 scalar multiplication. Each unit test can be
built and run in different test environments depending on the target platform, driven by `make`. We refer to the PQAX
Readme for a detailed description of the repository structure.

To build a test, run:

```
make build-{cross,native_mac,native_linux}-{ntt_dilithium,ntt_kyber,x25519}
```

Here, `cross` cross-compiles the test for a Linux-AArch64 target, `native_linux` assumes native compilation on a
Linux-AArch64 host, and `native_mac` assumes native compilation on an Arm-based MacOS host. Upon success, the test
binaries can be found in `envs/{cross, native_mac, native_linux}`.

In case of a native AArch64 host, run can immediately run the tests via

```
make run-{native_mac,native_linux}-{ntt_dilithium,ntt_kyber,x25519}
```

In case of cross-compilation for a AArch64-Linux target, you have to manually copy the test binary from `envs/cross/` to
the target.

## Armv8.1-M

TODO

# Benchmarking optimized code

## AArch64

TODO

## Armv8.1-M

TODO

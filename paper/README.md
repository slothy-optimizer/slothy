This directory contains supporting material for the paper [Fast and Clean: Auditable
high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303.pdf)
that introduced SLOTHY. It enables interested readers to:

1. _Optimize:_ Reproduce the SLOTHY optimizations described in the paper.
2. _Test:_ Validate the functional correctness of the optimized code through tests.
3. _Benchmark:_ If suitable development boards are available, evaluate the performance of the optimized code.

For optimization, only the SLOTHY repository is needed. For testing and benchmarking, we recommend the use of the
[pqmx](https://github.com/slothy-optimizer/pqmx) and [pqax](https://github.com/slothy-optimizer/pqax)
repositories. See the respective READMEs for setup instructions, or use the Dockerfile provided in
[artifact](artifact) (see also [artifact/README.md](artifact/README.md)).

# Testing optimized code

SLOTHY, pqmx and pqax are shipped with the optimized code for the workloads discussed in the paper. To test that
those versions are functional, or to test re-optimizations (see below), you have the following options. We describe
them separately for the AArch64 and Armv8.1-M examples.

## AArch64

AArch64 tests live in pqax, which provides unit tests for the Kyber NTTs, Dilithium NTTs, and X25519 scalar
multiplication. Each unit test can be built and run in different test environments depending on the target platform.
We refer to the pqax README for a detailed description of the repository structure.

To build and/or run a test, do:

```
make {build, run}-{cross,native_mac,native_linux}-{ntt_dilithium,ntt_kyber,x25519}
```

Here, the first argument from `{build, run}` indicates whether the test should be built only, or built-and-run.
The third argument from `{ntt_dilithium, ntt_kyber, x25519}` denotes the workload under test. The
second argument from `{cross, native_mac, native_linux}` denotes the test environment:

* The `cross` test environment cross-compiles a user space binary for a Linux-AArch64 target that can be
  either run emulated, or copied onto a remote device and tested there.
* `native_linux` assumes native compilation on a Linux-AArch64 host.
* `native_mac` assumes native compilation on an Arm-based MacOS host.

Upon success, the test binaries can be found in `envs/{cross, native_mac, native_linux}`.

__Examples:__

* If you work with a local copy of pqax on a Mac, use `native_mac` as the test environment:
```
% make run-native_mac-ntt_kyber
% make run-native_mac-ntt_dilithium
% make run-native_mac-x25519
```

* If you work in a Docker container on an Arm-based Mac, or on an AArch64-based Linux host, use `native_linux` as the
  test environment:

```
% make run-native_linux-ntt_kyber
% make run-native_linux-ntt_dilithium
% make run-native_linux-x25519
```

* If you work on an x86 Linux host, use `cross` to build and run user QEMU user space emulation:

```
% make run-cross-ntt_kyber
% make run-cross-ntt_dilithium
% make run-cross-x25519
```

* If you want to cross-compile test binaries for a remote AARch64 Linux target, build the tests via

```
% make run-cross-ntt_kyber
% make run-cross-ntt_dilithium
% make run-cross-x25519
```

then copy and run them on the target.

### Troubleshooting

* Garbage benchmarks: The test binaries include both functional correctness checks and benchmarks. However, when built
  in the way described above, cycle measurements are stubbed out, so benchmark results will be meaningless -- please
  ignore them. We describe below how to build binaries for environments with cycle accurate benchmarking.

### Re-optimization, connection with SLOTHY

Unit tests in pqax obtain their assembly source from `pqax/asm/manual/`, which has symlinks into the subdirectory
of the SLOTHY repository where optimization outputs are stored. Running the above commands after re-optimization
in SLOTHY (explained below) should therefore automatically pick up the new files.

## Armv8.1-M

Armv8.1-M tests live in pqmx, which is structured in the same way as pqax. pqmx provides unit tests for the Kyber and
Dilithium NTTs, and for the floating point and fixed point partial FFT.

To build a unit test for use with QEMU, use

```
make build-m55-core-{ntt_kyber, ntt_dilithium, fx_fft, flt_fft}
```

The resulting image is located in `envs/core`, and can be run on QEMU via

```
make run-m55-core-{ntt_kyber, ntt_dilithium, fx_fft, flt_fft}
```

For example, to build and test all examples, do:

```
% make run-m55-core-ntt_kyber
% make run-m55-core-ntt_dilithium
% make run-m55-core-fx_fft
% make run-m55-core-flt_fft
```

# Reproducing SLOTHY optimizations

We now describe how to reproduce the SLOTHY optimizations discussed in the paper:

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

Follow the [SLOTHY Readme](../README.md) to setup SLOTHY. If you use the Docker container provided in
[artifact](artifact), this step is not necessary.

## Running the optimizations

* From [scripts/](./scripts/), run one of the optimization scripts, e.g.

```
./slothy_kyber_ntt_a55.sh
```

If you want to run all optimizations, run `all.sh`, passing `SILENT={N,Y}` to indicate whether you want to see log
output from SLOTHY.

```
SILENT={Y,N} ./all.sh
```

* Now, wait. Running all optimizations at once will take multiple hours.

* Upon success, find the optimized source files in [examples/opt/](../examples/opt). They should be structurally equal
  to the input files, with the base assembly sections replaced by the optimized kernels and the rescheduling permutation
  indicated through comments.

### Trouble-shooting

* Timing and quality of results: The underlying CP-SAT constraint solver is non-deterministic, which means that the
  optimization timings may vary. The performance of the optimized code may also vary, esp. for the Cortex-A72
  optimizations which are based on a heuristic model of Cortex-A72. Variations for the in-order cores Cortex-M55,
  Cortex-M85 and Cortex-A55 should be smaller.

* Timeout: In the extreme case, examples may not terminate in acceptable time. In this case, you can either re-run
  the optimization, or send a SIGINT via CTRL+C while the CP-SAT solver is running, which will abort the current
  optimization and attempt another one with a larger number of stalls. Note, though, that this may lead to a non-optimal
  result.

* Compilation failure from immediate offsets: Rarely, it can happen that the resulting code fails to compile because immediate offsets in
  load/store instructions have gone out of bounds: SLOTHY will adjust such offsets when a post-increment load/store like
  `ldr/str Q0, [X0], #imm0` is reordered against a load/store with immediate offset `ldr/str Q0, [X0, #imm1]`, but it is
  not presently aware of the architectural limitations of those offsets. If the optimized code fails to compile because
  of an excessive immediate, please re-run the respective script.

In case of other issues, please let us know and we will investigate.

# Benchmarking

## AArch64

To enable benchmarking in the test binaries for the Kyber NTTs, Dilithium NTTs, and X25519 scalar multiplication on
Cortex-A55 and Cortex-A72, use the following:

```
CYCLES={PMU,PERF} make {build,run}-{cross,native_linux}-{ntt_dilithium,ntt_kyber,x25519}
```

Here, `CYCLES=PMU` means that cycle counts will be obtained by directly accessing the PMU cycle counter register. This
access needs to be enabled by loading a suitable kernel module as described in
[https://github.com/mupq/pqax#enable-access-to-performance-counters](https://github.com/mupq/pqax#enable-access-to-performance-counters).

Alternatively, `CYCLES=PERF` means that cycle counts will be obtained via the `perf` module.

### Troubleshooting

* `Illegal instruction`: This fatal error is encountered when access to the PMU cycle counter has not been enabled. See
  the link above, or use `CYCLES=PERF` instead.

* No cycles on Arm-based Macs: pqax does not offer cycle measurements on Arm-based Macs yet.

## Armv8.1-M

pqmx supports building images ready for use with the MPS3 FPGA prototyping board and the AN547 and AN555 nodes for the
Cortex-M55 and Cortex-M85, respectively.

To build the respective images, use

```
make build-{m55-an547, m85-an555}-{ntt_kyber, ntt_dilithium, fx_fft, flt_fft}
```

Those images then need to be flashed onto the MPS3 for test.

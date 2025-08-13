# About SLOTHY

**SLOTHY** - **S**uper **L**azy **O**ptimization of **T**ricky **H**andwritten assembl**Y** - is an assembly-level superoptimizer
for:
1. Instruction scheduling
2. Register allocation
3. Software pipelining (= periodic loop interleaving)

SLOTHY is generic in the target architecture and microarchitecture. This repository provides instantiations for:
- Armv8.1-M+Helium: Cortex-M55, Cortex-M85
- AArch64: Cortex-A55, and experimentally Cortex-A72, Cortex-X/Neoverse-V, Apple M1 (Firestorm, Icestorm)

SLOTHY is discussed in [Fast and Clean: Auditable high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303).

## Goal

SLOTHY enables a development workflow where developers write 'clean' assembly by hand, emphasizing the logic of the computation, while SLOTHY automates microarchitecture-specific micro-optimizations. This accelerates development, keeps manually written code artifacts maintainable, and allows to split efforts for formal verification into the separate verification of the clean code and the micro-optimizations.

## How it works

SLOTHY is essentially a constraint solver frontend: It converts the input source into a data flow graph and
builds a constraint model capturing valid instruction schedulings, register renamings, and periodic loop
interleavings. The model is passed to an external constraint solver and, upon success,
a satisfying assignment converted back into the final code. Currently, SLOTHY uses
[Google OR-Tools](https://developers.google.com/optimization) as its constraint solver backend.

## Performance

As a rough rule of thumb, SLOTHY typically optimizes workloads of <50 instructions in seconds to minutes, workloads
up to 150 instructions in minutes to hours, while for larger kernels some heuristics are necessary.

## Applications

SLOTHY has been used to provide the fastest known implementations of various cryptographic and DSP primitives:
For example, the [SLOTHY paper](https://eprint.iacr.org/2022/1303) discusses the NTTs underlying ML-KEM and ML-DSA for
Cortex-{A55, A72, M55, M85}, the FFT for Cortex-{M55,M85}, and the X25519 scalar multiplication for Cortex-A55. You find
the clean and optimized source code for those examples in [`paper/`](https://github.com/slothy-optimizer/slothy/tree/main/paper).

# Getting started

Have a look at the [SLOTHY tutorial](tutorial/README.md) for a hands-on and example-based introduction to SLOTHY.

# Real world uses

* [AWS libcrypto (AWS-LC)](https://github.com/aws/aws-lc): SLOTHY-optimized X25519 code based on our un-interleaved form of the [original code by Emil
  Lenngren](https://github.com/Emill/X25519-AArch64) has been [formally verified and
  included](https://github.com/awslabs/s2n-bignum/pull/108) in
  [s2n-bignum](https://github.com/awslabs/s2n-bignum/) (the bignum component of AWS-LC) and [merged](https://github.com/aws/aws-lc/pull/1469) into
  AWS-LC. This was the topic of a [Real World Crypto 2024
  talk](https://iacr.org/submit/files/slides/2024/rwc/rwc2024/38/slides.pdf).

* [s2n-bignum](https://github.com/awslabs/s2n-bignum/) routinely employs SLOTHY for finding
further highly optimized ECC implementations (e.g., [P256](https://github.com/awslabs/s2n-bignum/pull/118),
[P384](https://github.com/awslabs/s2n-bignum/pull/122), [P521](https://github.com/awslabs/s2n-bignum/pull/130) and
verifies them through automated equivalence-checking in [HOL-Light](https://hol-light.github.io/).

* [Arm EndpointAI](https://github.com/ARM-software/EndpointAI): SLOTHY-optimized code has been deployed to the CMSIS DSP Library for the radix-4 CFFT routines as part
  of the Arm EndpointAI project in [this
  commit](https://github.com/ARM-software/EndpointAI/commit/817bb57d8a4a604538a04627851f5e9adb5f08fc).

# Installation

## Requirements

SLOTHY has been successfully used on

- Ubuntu-21.10 and up (64-bit),
- macOS Monterey 12.6 and up.

SLOTHY requires Python >= 3.10. See [requirements.txt](https://github.com/slothy-optimizer/slothy/blob/main/requirements.txt) for package requirements, and install via `pip
install -r requirements.txt`.

**Note:** `requirements.txt` pins versions for reproducibility. If you already have newer versions of some dependencies
installed and don't want them downgraded, consider using a virtual environment:

```
python3 -m venv venv
./venv/bin/python3 -m pip install -r requirements.txt
```

Then, enter the virtual environment via `source venv/bin/activate` prior to running SLOTHY.

## Docker

A dockerfile for an Ubuntu-22.04 based Docker image with all dependencies of SLOTHY and the PQMX+PQAX test
environments setup can be found in [paper/artifact/slothy.dockerfile](https://github.com/slothy-optimizer/slothy/blob/main/paper/artifact/slothy.Dockerfile). See
[paper/artifact/README.md](https://github.com/slothy-optimizer/slothy/blob/main/paper/artifact/README.md) for instructions.

## Quick check

To check that your setup is complete, try the following from the base directory:

```
% python3 example.py --examples aarch64_simple0_a55
```

You should see something like the following:

```
* Example: aarch64_simple0_a55...
INFO:aarch64_simple0_a55:Instructions in body: 20
INFO:aarch64_simple0_a55.slothy:Perform internal binary search for minimal number of stalls...
INFO:aarch64_simple0_a55.slothy:Attempt optimization with max 32 stalls...
INFO:aarch64_simple0_a55.slothy:Objective: minimize number of stalls
INFO:aarch64_simple0_a55.slothy:Invoking external constraint solver (OR-Tools CP-SAT v9.7.2996) ...
INFO:aarch64_simple0_a55.slothy:[0.0721s]: Found 1 solutions so far... objective 19.0, bound 8.0 (minimize number of stalls)
INFO:aarch64_simple0_a55.slothy:[0.0765s]: Found 2 solutions so far... objective 18.0, bound 12.0 (minimize number of stalls)
INFO:aarch64_simple0_a55.slothy:OPTIMAL, wall time: 0.155224 s
INFO:aarch64_simple0_a55.slothy:Booleans in result: 509
INFO:aarch64_simple0_a55.slothy.selfcheck:OK!
INFO:aarch64_simple0_a55.slothy:Minimum number of stalls: 18
```

## Examples

The [SLOTHY Tutorial](tutorial/README.md) and the [examples](https://github.com/slothy-optimizer/slothy/tree/main/examples/naive) directory contain numerous exemplary
assembly snippets. To try them, use `python3 example.py --examples={YOUR_EXAMPLE}`. See `python3 example.py --help` for
the list of all available examples.

The use of SLOTHY from the command line is illustrated in [paper/scripts/](https://github.com/slothy-optimizer/slothy/tree/main/paper/scripts) supporting the real-world optimizations
for the NTT, FFT and X25519 discussed in [Fast and Clean: Auditable high-performance assembly via constraint
solving](https://eprint.iacr.org/2022/1303).

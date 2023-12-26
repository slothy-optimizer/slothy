<p align="center">
    <image src="./docs/slothy_logo.png" width=160>
</p>

**SLOTHY** - **S**uper (**L**azy) **O**ptimization of **T**ricky **H**andwritten assembl**Y** - is an assembly-level superoptimizer
for:
1. Instruction scheduling
2. Register allocation
3. Software pipelining (= periodic loop interleaving)

SLOTHY is generic in the target architecture and microarchitecture. This repository provides instantiations for the
the Cortex-M55 and Cortex-M85 CPUs implementing Armv8.1-M + Helium, and the Cortex-A55 and Cortex-A72
CPUs implementing Armv8-A + Neon. There is an experimental model for Cortex-X/Neoverse-V cores.

SLOTHY is discussed in [Fast and Clean: Auditable high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303).

### Goal

SLOTHY enables a development workflow where developers write 'clean' assembly by hand, emphasizing the logic of the computation, while SLOTHY automates microarchitecture-specific micro-optimizations. This accelerates development, keeps manually written code artifacts maintainable, and allows to split efforts for formal verification into the separate verification of the clean code and the micro-optimizations.

### How it works

SLOTHY is essentially a constraint solver frontend: It converts the input source into a data flow graph and
builds a constraint model capturing valid instruction schedulings, register renamings, and periodic loop
interleavings. The model is passed to an external constraint solver and, upon success,
a satisfying assignment converted back into the final code. Currently, SLOTHY uses
[Google OR-Tools](https://developers.google.com/optimization) as its constraint solver backend.

### Performance

As a rough rule of thumb, SLOTHY typically optimizes workloads of <50 instructions in seconds to minutes, workloads
up to 150 instructions in minutes to hours, while for larger kernels some heuristics are necessary.

### Applications

SLOTHY has been used to provide the fastest known implementations of various cryptographic and DSP primitives:
For example, the [SLOTHY paper](https://eprint.iacr.org/2022/1303) discusses the NTTs underlying ML-KEM and ML-DSA for Cortex-{A55, A72, M55, M85}, the FFT for Cortex-{M55,M85}, and the X25519 scalar multiplication for Cortex-A55. You find the clean and
optimized source code for those examples in [`paper/`](paper).

## Setup

### Docker

A dockerfile for an Ubuntu-22.10 based Docker image with all dependencies of SLOTHY setup
can be found in [paper/artifact/slothy.dockerfile](paper/artifact/slothy.dockerfile). See
[paper/artifact/README.md](paper/artifact/README.md) for instructions.

### Manual

SLOTHY relies on [Google OR-Tools](https://developers.google.com/optimization) as the underlying constraint
solver. You need at least v9.3, and this repository by default uses v9.7. Unless you already have a working
installation, you can clone Google OR-Tools as a submodule of this repository and build from scratch, e.g. as follows:

```
% git submodule init
% git submodule update
% cd submodules/or-tools
% git apply ../0001-Pin-pybind11_protobuf-commit-in-cmake-files.patch
% mkdir build
% cmake -S. -Bbuild -DBUILD_PYTHON:BOOL=ON
% make -C build -j8
```

This is also available as [submodules/setup-ortools.sh](submodules/setup-ortools.sh)
for convenience.

**Dependencies:** You need `git`, `python3-pip`, `cmake`, `swig`, and build-tools (e.g. `build-essential`)
to build OR-Tools from source.

You also need `sympy`. To add it to the virtual Python environment provided by OR-Tools, do
```
> source submodules/or-tools/build/python/venv/bin/activate
> pip3 install sympy
> deactivate
```

Once set up, start the virtual environment with

```
> source init.sh
```

and you're ready to use OR-Tools and SLOTHY.

#### Trouble-shooting

In case of issues, check the [slothy.dockerfile](paper/artifact/slothy.dockerfile) for a complete list
of dependencies and setup instructions based on Ubuntu 22.10.

### Quick check

To check that your setup is complete, try the following from the base directory. It optimizes
an Armv8.1-M complex-magnitude kernel for Cortex-M55 (see Section 7.3 in the [SLOTHY paper](https://eprint.iacr.org/2022/1303.pdf) for some details).

```
% ./slothy-cli Arm_v81M Arm_Cortex_M55                       \
       ./paper/clean/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx.s \
    -c sw_pipelining.enabled                                 \
    -c sw_pipelining.unroll=2                                \
    -c inputs_are_outputs                                    \
    -c variable_size                                         \
    -c constraints.stalls_first_attempt=8                    \
    -l start
```

After a few seconds and some log output, you should see original and optimized code:

```
% ./slothy-cli Arm_v81M Arm_Cortex_M55                       \
       ./paper/clean/helium/cmplx_mag_sqr/cmplx_mag_sqr_fx.s \
    -c sw_pipelining.enabled                                 \
    -c sw_pipelining.unroll=2                                \
    -c inputs_are_outputs                                    \
    -c variable_size                                         \
    -c constraints.stalls_first_attempt=8                    \
    -l start
INFO:slothy-cli:- Setting configuration option enabled to value True
INFO:slothy-cli:- Setting configuration option unroll to value 2
INFO:slothy-cli:- Setting configuration option inputs_are_outputs to value True
INFO:slothy-cli:- Setting configuration option variable_size to value True
INFO:slothy-cli:- Setting configuration option stalls_first_attempt to value 8
INFO:slothy-cli:Optimizing loop start (6 instructions) ...
INFO:slothy-cli.start.slothy:Perform internal binary search for minimal number of stalls...
INFO:slothy-cli.start.slothy:Attempt optimization with max 8 stalls...
INFO:slothy-cli.start.slothy:Objective: minimize number of stalls
INFO:slothy-cli.start.slothy:Invoking external constraint solver (OR-Tools CP-SAT v9.7.2996) ...
INFO:slothy-cli.start.slothy:[0.4137s]: Found 1 solutions so far... objective 5.0, bound 0.0 (minimize number of stalls)
INFO:slothy-cli.start.slothy:[0.4756s]: Found 2 solutions so far... objective 4.0, bound 0.0 (minimize number of stalls)
INFO:slothy-cli.start.slothy:[0.4992s]: Found 3 solutions so far... objective 3.0, bound 0.0 (minimize number of stalls)
INFO:slothy-cli.start.slothy:[0.5096s]: Found 4 solutions so far... objective 2.0, bound 0.0 (minimize number of stalls)
INFO:slothy-cli.start.slothy:[0.5123s]: Found 5 solutions so far... objective 1.0, bound 0.0 (minimize number of stalls)
INFO:slothy-cli.start.slothy:OPTIMAL, wall time: 0.545340 s
INFO:slothy-cli.start.slothy:Booleans in result: 1518
INFO:slothy-cli.start.slothy:Number of early instructions: 7
INFO:slothy-cli.start.slothy.selfcheck:OK!
...

        .syntax unified
        .type   cmplx_mag_sqr_fx, %function
        .global cmplx_mag_sqr_fx

        .text
        .align 4
cmplx_mag_sqr_fx:
        push {r4-r12,lr}
        vpush {d0-d15}

        out   .req r0
        in    .req r1
        sz    .req r2

        lsr lr, sz, #2
        wls lr, lr, end
.p2align 2
        vld20.32 {q1,q2}, [r1]         // *....
        // gap                         // .....
        vld21.32 {q1,q2}, [r1]!        // .*...
        // gap                         // .....
        vld20.32 {q3,q4}, [r1]         // ..*..
        vmulh.s32 q7, q2, q2           // ....*
        vld21.32 {q3,q4}, [r1]!        // ...*.

        // original source code
        // vld20.32 {q1,q2}, [r1]      // *....
        // vld21.32 {q1,q2}, [r1]!     // .*...
        // vld20.32 {q3,q4}, [r1]      // ..*..
        // vld21.32 {q3,q4}, [r1]!     // ....*
        // vmulh.s32 q7, q2, q2        // ...*.

        lsr lr, lr, #1
        sub lr, lr, #1
.p2align 2
start:
        vmulh.s32 q0, q1, q1            // ..*.........
        vld20.32 {q1,q2}, [r1]          // e...........
        vmulh.s32 q6, q4, q4            // .........*..
        vld21.32 {q1,q2}, [r1]!         // .e..........
        vmulh.s32 q5, q3, q3            // ........*...
        vld20.32 {q3,q4}, [r1]          // ......e.....
        vhadd.s32 q0, q7, q0            // ....*.......
        vld21.32 {q3,q4}, [r1]!         // .......e....
        vmulh.s32 q7, q2, q2            // ...e........
        vstrw.u32 q0, [r0] , #16        // .....*......
        vhadd.s32 q6, q6, q5            // ..........*.
        vstrw.u32 q6, [r0] , #16        // ...........*
        // gap                          // ............

        // original source code
        // vld20.32 {q6,q7}, [r1]       // e..........|e..........
        // vld21.32 {q6,q7}, [r1]!      // ..e........|..e........
        // vmulh.s32 q6, q6, q6         // ...........*...........
        // vmulh.s32 q5, q7, q7         // .......e...|.......e...
        // vhadd.s32 q3, q5, q6         // .....*.....|.....*.....
        // vstrw.u32 q3, [r0] , #16     // ........*..|........*..
        // vld20.32 {q6,q7}, [r1]       // ....e......|....e......
        // vld21.32 {q6,q7}, [r1]!      // ......e....|......e....
        // vmulh.s32 q6, q6, q6         // ...*.......|...*.......
        // vmulh.s32 q5, q7, q7         // .*.........|.*.........
        // vhadd.s32 q3, q5, q6         // .........*.|.........*.
        // vstrw.u32 q3, [r0] , #16     // ..........*|..........*

        le lr, start
        vmulh.s32 q2, q1, q1            // *......
        // gap                          // .......
        vmulh.s32 q5, q4, q4            // .*.....
        vhadd.s32 q2, q7, q2            // ...*...
        vmulh.s32 q3, q3, q3            // ..*....
        vstrw.u32 q2, [r0] , #16        // ....*..
        vhadd.s32 q0, q5, q3            // .....*.
        vstrw.u32 q0, [r0] , #16        // ......*

        // original source code
        // vmulh.s32 q0, q1, q1         // *......
        // vmulh.s32 q6, q4, q4         // .*.....
        // vmulh.s32 q5, q3, q3         // ...*...
        // vhadd.s32 q0, q7, q0         // ..*....
        // vstrw.u32 q0, [r0] , #16     // ....*..
        // vhadd.s32 q6, q6, q5         // .....*.
        // vstrw.u32 q6, [r0] , #16     // ......*

end:

        vpop {d0-d15}
        pop {r4-r12,lr}

        bx lr
```

## Basic usage

### Command line interface

The quickest way to experiment with `slothy` is via its command line interface `slothy-cli`:

```
% slothy-cli ARCH TARGET INPUT [options]
```

Here are some options:

* Configuration of SLOTHY: You can set various configuration options via `-c option=value`. For example, to enable
  software pipelining, use `-c sw_pipelining.enabled=True`, or just `-c sw_pipelining.enabled` (generally, `-c option`
  is a shortcut for `-c option=True`, while `-c /option` is a shortcut for `-c option=False`). The hierarchy of
  configuration options is the same as for `Slothy.Config` in [slothy/config.py](slothy/config.py).

* Defining the part of the source code to operate on: Rather than asking SLOTHY to optimize an entire file, one will
  usually want to direct it to the optimization of some selected parts of assembly -- for example, the core loop. This
  can be done via the `-start/end {label}` options, which expect assembly labels delimiting the code to be
  optimized. Alternatively, `-loop {label}` can be used to operate on the body of a loop starting at the given label.

* An output file can be specified with `-o`.

For more details, see `slothy-cli --help` and/or the Python documentation.

### Python interface

`slothy` can also be called from Python, as demonstrated in the source code for [slothy-cli](slothy-cli) or the numerous
examples in [example.py](example.py). The basic flow is as follows:

1. Setup a `slothy` instance, passing the architecture and target microarchitecture modules as arguments.
   You can specify architecture modules directly, e.g. `slothy_m55 = Slothy(targets.arm_v81m.arch_v81m,
   targets.arm_v81m.cortex_m55r1)`, or query them from `targets.query` as done in [slothy-cli](slothy-cli).
2. Load the source code to optimize via `load_source_from_file()`
3. Modify the default configuration as desired
4. Call `slothy.optimize(first=START_LABEL, end=END_LABEL)` to optimize and replace the part of the current source code
   between the given labels. Alternatively, call `slothy.optimize_loop(loop_lbl=LABEL)` to do the same for a loop
   starting at label `LABEL` (the end will be detected automatically).
5. If you have multiple sections to be optimized, repeat 3 and 4 above.
6. Print and/or save the final source code via `slothy.print_code()` or `slothy.write_source_to_file()`.

If you want to optimize the intermediate code between two loops which have been optimized via software pipelining,
you'll need to know the dependencies carried across the optimized iterations. After a call to `slothy.optimize_loop()`,
you can query those as `slothy.last_result.kernel_input_output`.

### Examples

The [examples](examples/naive) directory contains numerous exemplary assembly snippets. To try them, use
`python3 example.py --examples={YOUR_EXAMPLE}`. See `python3 examples.py --help` for the list of all available examples.

The use of SLOTHY from the command line is illustrated in [scripts/](scripts/) supporting the real-world optimizations
for the NTT, FFT and X25519 discussed in [Fast and Clean: Auditable high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303).

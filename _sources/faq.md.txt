# Frequently asked questions

## Is SLOTHY a peephole optimizer?

No. SLOTHY is a _fixed-instruction_ super-optimizer: It keeps instructions and optimizes
register allocation, instruction scheduling, and software pipelining. It is the developer's or another tool's
responsibility to map the workload at hand to the target architecture.

<!-- #### When should I use SLOTHY?

You may want to use SLOTHY on performance-critical workloads for which precise control over instruction-selection
is beneficial (e.g. because other code-generation techniques do not find ideal instruction sequences) or needed
(e.g. because some instructions or instruction patterns have to be avoided for security). -->

## Is SLOTHY better than {name your favourite superoptimizer}?

Most likely, they serve different purposes. SLOTHY aims to do one thing well: Optimization _after_ instruction selection.
It is thus independent of and potentially combinable with superoptimizers operating at earlier stages of the code-generation process, such as [souper](https://github.com/google/souper) and [CryptOpt](https://github.com/0xADE1A1DE/CryptOpt).

## Does SLOTHY support x86?

The core of SLOTHY is architecture- and microarchitecture-agnostic and can accommodate x86. As it stands, however,
there is no model of the x86 architecture. Feel free to build one!

## Does SLOTHY support RISC-V?

As for x86.

## Is SLOTHY formally verified?

No. Arguably, that wouldn't be a good use of time. The more relevant question is the following:

## Is SLOTHY-generated code formally verified to be equivalent to the input code?

Not yet. SLOTHY runs a self-check confirming that input and output have isomorphic data flow graphs,
but pitfalls remain, such as bad user configurations allowing SLOTHY to clobber a register that's not
meant to be reserved. More work is needed for formal verification of the equivalence of input
and output.

## Why is my question not here?

Ping us! ([GitHub](https://github.com/slothy-optimizer/slothy/issues), or see [paper](https://eprint.iacr.org/2022/1303.pdf) for
contact information).
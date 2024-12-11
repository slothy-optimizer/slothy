---
layout: default
---

`SLOTHY` -- **S**uper **L**azy **O**ptimization of **T**ricky **H**andwritten assembl**Y** -- is a fixed-instruction
assembly superoptimizer based on constraint solving. It takes handwritten assembly as input and simultaneously
super-optimizes:
- Instruction scheduling
- Register allocation
- Software pipelining

`SLOTHY` enables a development workflow where developers write 'clean' assembly by hand, emphasizing the logic of the
computation, while `SLOTHY` automates microarchitecture-specific micro-optimizations. Since `SLOTHY` does not change
instructions, and scheduling/allocation optimizations are tightly controlled through configurable and extensible
constraints, the developer keeps close control over the final assembly, while being freed from tedious
micro-optimizations.

See also [FAQ](source/faq.md)

#### Architecture/Microarchitecture support

`SLOTHY` is generic in the target architecture and microarchitecture. It currently supports Cortex-M55 and Cortex-M85
implementing Armv8.1-M + Helium, and Cortex-A55 and Cortex-A72 implementing
Armv8-A + Neon. Moreover, there is an experimental model for Cortex-X/Neoverse-V cores.

#### Paper

SLOTHY is described in detail in the CHES 2024 paper [Fast and Clean: Auditable
high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303.pdf).

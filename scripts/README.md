## Supporting material

This directory contains some scripts conducting the optimizations described in the paper

"Fast and Clean: Auditable high-performance assembly via constraint solving"
https://eprint.iacr.org/2022/1303.pdf

by Amin Abdulrahman, Hanno Becker, Matthias J. Kannwischer, and Fabien Klein.

### Usage

* Make sure the OR-Tools venv is enabled by running `source init.sh` from the base directory (see
  [README](../README.md)).

* Run one of the optimization scripts, e.g.

```
./slothy_kyber_ntt_a55.sh
```

* Wait. You should see a fair amount of output in stdout, and some scripts take >1h even on a powerful machine.

* Upon success, find the optimized source files in [examples/opt/](../examples/opt)

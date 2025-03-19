# Contributing to SLOTHY

Welcome! We are pleased to see you are interested in contributing to SLOTHY.

In the following, we will lay out a few foundational things that are important
for your contributions.

## Setup
The setup for the development works just as the one we present in the
[`README`](https://github.com/slothy-optimizer/slothy/blob/main/README.md).

## Project Structure
This repository consists of the following, important elements:

- [`docs`](https://github.com/slothy-optimizer/slothy/tree/main/docs): Code
  related to building our sphinx documentation. 
- [`examples`](https://github.com/slothy-optimizer/slothy/tree/main/examples):
  Collection of assembly files used as examples for SLOTHY. The directory is
  split up in a part containing the naive implementations serving as a starting
  point, and another part containing the SLOTHY-optimized routines. 
- [`paper`](https://github.com/slothy-optimizer/slothy/tree/main/paper):
  Material relevant to the publication of the paper [Fast and Clean: Auditable
  high-performance assembly via constraint
  solving](https://eprint.iacr.org/2022/1303).
- [`slothy`](https://github.com/slothy-optimizer/slothy/tree/main/slothy):
  Core-part of SLOTHY. Contains the architectural/microarchitectural models, as
  well as the actual implementation of SLOTHY. 
- [`tutorial`](https://github.com/slothy-optimizer/slothy/tree/main/tutorial): A
  tutorial introducing various aspects about the usage of SLOTHY as a tool.
- [`example.py`](https://github.com/slothy-optimizer/slothy/blob/main/example.py):
  Script containing the invocations of SLOTHY, to optimize the naive assembly
  implementations from
  [`examples`](https://github.com/slothy-optimizer/slothy/tree/main/examples)
  into their optimized counterparts.

## Quality Assurance
### Providing Examples

In case you add new features to SLOTHY, extend the
architectural/microarchitectural model, or make any other modification to the
tool that may change its operation, we highly appreciate if you add an example
to the
[`example.py`](https://github.com/slothy-optimizer/slothy/blob/main/example.py)
script, that will cover your modifications. 

The
[`example.py`](https://github.com/slothy-optimizer/slothy/blob/main/example.py)
script gets run with the `--dry-run` flag in our CI in order to catch
superficial errors and some common pitfalls.

### Style
To ensure a certain level of quality for the code in this repository, we ask
contributors to verify whether the code satisfies a set of formatting and style
requirements. For this, we employ `flake8` and `black`. 

You can check the formatting of the source code, including the sphinx doc
strings by running `flake8 .` in the root of the repository.

In order to automate the formatting process, you can first check how `black`
would adjust the code by running `black --check --diff .`. If you are happy with
the proposed changes, run `black .` to apply them to the code. 

Note that these tools will also be run by our CI, which needs to pass before we
can merge your pull requests.


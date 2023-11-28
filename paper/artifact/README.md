# Submission artifact

This directory contains the artifact submission for the CHES 2024 paper [Fast and Clean: Auditable
high-performance assembly via constraint solving](https://eprint.iacr.org/2022/1303.pdf).

The artifact enables interested readers to:

1. _Optimize:_ Reproduce the SLOTHY optimizations described in the paper.
2. _Test:_ Validate the functional correctness of the optimized code through tests.
3. _Benchmark:_ If suitable development boards are available, evaluate the performance of the optimized code.

## Setup

Optimization requires the [SLOTHY](https://github.com/slothy-optimizer/slothy) repository. For testing and benchmarking,
we recommend and describe the use of the [pqmx](https://github.com/slothy-optimizer/pqmx) and
[pqax](https://github.com/slothy-optimizer/pqax) test repositories for Cortex-M and Cortex-A. Benchmarking further
requires the availability of suitable devices or development boards.

### Docker

SLOTHY, pqmx and pqax have a number of dependencies that can be cumbersome to setup manually, including [Google
OR-Tools](https://github.com/google/or-tools/) and cross-compilers for AArch64 and Armv8.1-M.

For convenience, this directory contains a Dockerfile [slothy.Dockerfile](./slothy.Dockerfile) establishing an
Ubuntu-22.04-based Docker image with SLOTHY, pqax and pqmx setup and ready for use.

#### Build image

* Build the image:

```
docker build -f slothy.Dockerfile -t slothy_image .
```

* Check success:

```
docker image ls
```

should show a line like this:

```
% docker image ls
REPOSITORY      TAG       IMAGE ID       CREATED         SIZE
slothy_image    latest    b009755ab33e   2 hours ago     3.5GB
```

#### Create and run container

* Create docker container from image

```
% docker run --name slothy_container -d -it slothy_image /bin/bash
e06f3c0155e552ce41a7fecdccf27f18e04e888ee30b5a43b48b98326df360bd
```

* Check that the container is running

```
% docker container ls
CONTAINER ID   IMAGE        COMMAND       CREATED          STATUS          PORTS     NAMES
e06f3c0155e5   slothy_image "/bin/bash"   20 seconds ago   Up 19 seconds             slothy_container
```

* Start shell in docker container

```
% docker exec -it slothy_container /bin/bash
root@e06f3c0155e5:/slothy#
```

Here are all steps together:

```
docker build -f slothy.Dockerfile -t slothy_image .
docker image ls
docker run --name slothy_container -d -it slothy_image /bin/bash
docker container ls
docker exec -it slothy_container /bin/bash
```

### Manual build

For a manual local build, you largely follow the steps in [`slothy.Dockerfile`](./slothy.Dockerfile). At the top-level,
you should have a directory structured as follows:

```
* artifact
* |-- pqmx
*     |-- submodules
*         |-- slothy # symlink to slothy repository
* |-- pqax
*     |-- submodules
*         |-- slothy # symlink to slothy repository
* |-- slothy
*     |-- submodules
*         |-- or-tools
```

Note that to avoid having three copies of SLOTHY, you should not use `git submodule` in the pqmx and pqax repositories,
but symlink the SLOTHY repository into the submodule location.

For the SLOTHYrepository, the main dependency is Google OR-Tools; see the README in the SLOTHY repository for setup
instructions (those are also followed in the Dockerfile).

## Using the artifact

Within either the docker container or your local copy of SLOTHY, please see `slothy/paper/README.md` for a detailed
description of how to reproduce, test and benchmark the results of the paper. This file is also available online
[here](https://github.com/slothy-optimizer/slothy/blob/ches2024_artifact/paper/README.md).

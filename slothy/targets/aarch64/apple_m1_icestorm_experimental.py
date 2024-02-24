#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author: Hanno Becker <hannobecker@posteo.de>
#

#
# Experimental model for Apple M1 efficiency "Icestorm" CPU cores
# Based on data by https://dougallj.github.io/applecpu/icestorm.html
#

from enum import Enum
from itertools import combinations, product

from slothy.targets.aarch64.aarch64_neon import *

# 4 uops per cycle
# Most arithmetic instructions consist of 1 uop, SIMD loads/stores are made up of multiple
issue_rate = 4


class ExecutionUnit(Enum):
    SCALAR_I0 = 0,
    SCALAR_I1 = 1,
    SCALAR_I2 = 2,
    LSU0 = 3,
    LU0 = 4,
    VEC0 = 5,
    VEC1 = 6,

    def __repr__(self):
        return self.name

    def I():
        return [ExecutionUnit.SCALAR_I0, ExecutionUnit.SCALAR_I1,
                ExecutionUnit.SCALAR_I2]

    def V():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1]

    def LSU():
        return [ExecutionUnit.LSU0]

    def LOAD():
        return [ExecutionUnit.LSU0, ExecutionUnit.LU0]

    def STORE():
        return [ExecutionUnit.LSU0]

#  Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.


def add_further_constraints(slothy):
    _ = slothy


def has_min_max_objective(config):
    return False


def get_min_max_objective(slothy):
    return

# TODO: Copy-pasted from A72 model and roughly adjusted


execution_units = {
    (vmul, vmul_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqrdmulh, vqrdmulh_lane,
     vqdmulh_lane): ExecutionUnit.V(),

    (vadd, vsub,
     trn1, trn2): ExecutionUnit.V(),

    Vins: ExecutionUnit.V(),  # ???
    umov_d: ExecutionUnit.V(),  # ???

    (Ldr_Q, Ldr_X): ExecutionUnit.LOAD(),

    (Str_Q, Str_X): ExecutionUnit.STORE(),

    (add, add_imm): ExecutionUnit.I(),

    # These instructions use a (/any?) pair of integer units at the same time
    (add_lsl, add_lsr): list(map(list, combinations(ExecutionUnit.I(), 2))),

    vsrshr: ExecutionUnit.V(),

    St4: [[ExecutionUnit.VEC0, ExecutionUnit.VEC1, ExecutionUnit.LU0,
           ExecutionUnit.LSU0] + ExecutionUnit.I()],  # guess based on A55

    # guess based on A72
    Ld4: list(map(list, product(ExecutionUnit.LOAD(), ExecutionUnit.V())))
}

inverse_throughput = {
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqdmulh_lane): 1,

    (vadd, vsub,
     trn1, trn2): 1,

    Vins: 2,  # not clear
    umov_d: 2,  # not clear

    (add, add_imm): 1,
    (add_lsl, add_lsr): 1,

    (Ldr_Q, Str_Q, q_ldr1_stack, Ld2, Ldr_X, Str_X): 1,  # approx.

    vsrshr: 1,

    St4: 4,  # or more? 
    Ld4: 4  # or more? 
}

# REVISIT
default_latencies = {
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmls, vmls_lane,
     vmla, vmla_lane,
     vqdmulh_lane): 3,

    (vadd, vsub,
     trn1, trn2): 2,

    (q_ldr1_stack, Ld2): 4,  # guessed
    (Ldr_Q) : 4,  # something less than 8
    (Ldr_X): 3,  # something less than 5
    (Str_Q, Str_X): 3,  # guessed

    Vins: 5,  # something in [2,9]
    umov_d: 4,  # something less than 8

    (add, add_imm): 1,
    (add_lsl, add_lsr): 2,

    vsrshr: 3,
    St4: 5,  # guessed
    Ld4: 4  # guessed
}


def get_latency(src, out_idx, dst):
    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)
    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    else:
        return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

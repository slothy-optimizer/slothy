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
# Experimental model for high-end Apple M1 CPU
# Based on data by https://dougallj.github.io/applecpu/firestorm.html
#

from enum import Enum
from itertools import combinations, product

from slothy.targets.aarch64.aarch64_neon import *

issue_rate = 8


class ExecutionUnit(Enum):
    SCALAR_I0 = 0,
    SCALAR_I1 = 1,
    SCALAR_I2 = 2,
    SCALAR_I3 = 3,
    SCALAR_I4 = 4,
    SCALAR_I5 = 5,
    SCALAR_M0 = 4,  # Overlaps with fifth I pipeline
    SCALAR_M1 = 5,  # Overlaps with sixth I pipeline
    SU0 = 6,
    LSU0 = 7,
    LU0 = 8,
    LU1 = 9,
    VEC0 = 10,
    VEC1 = 11,
    VEC2 = 12,
    VEC3 = 13,

    def __repr__(self):
        return self.name

    def I():
        return [ExecutionUnit.SCALAR_I0, ExecutionUnit.SCALAR_I1,
                ExecutionUnit.SCALAR_I2, ExecutionUnit.SCALAR_I3,
                ExecutionUnit.SCALAR_I4, ExecutionUnit.SCALAR_I5]

    def M():
        return [ExecutionUnit.SCALAR_M0, ExecutionUnit.SCALAR_M1]

    def V():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1,
                ExecutionUnit.VEC2, ExecutionUnit.VEC3]

    def V0():
        return [ExecutionUnit.VEC0]

    def V1():
        return [ExecutionUnit.VEC1]

    def V13():
        return [ExecutionUnit.VEC1, ExecutionUnit.VEC3]

    def V01():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC1]

    def V02():
        return [ExecutionUnit.VEC0, ExecutionUnit.VEC2]

    def LSU():
        return [ExecutionUnit.LSU0]

    def LOAD():
        return [ExecutionUnit.LSU0, ExecutionUnit.LU0, ExecutionUnit.LU1]

    def STORE():
        return [ExecutionUnit.LSU0, ExecutionUnit.SU0]

#  Opaque functions called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.


def add_further_constraints(slothy):
    _ = slothy


def has_min_max_objective(config):
    return False


def get_min_max_objective(slothy):
    return


execution_units = {
    (vmul, vmul_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqrdmulh, vqrdmulh_lane,
     vqdmulh_lane): ExecutionUnit.V(),

    (vadd, vsub,
     trn1, trn2): ExecutionUnit.V(),

    Vins: ExecutionUnit.V(),
    umov_d: ExecutionUnit.V(),  # ???

    (Ldr_Q, Ldr_X): ExecutionUnit.LOAD(),

    (Str_Q, Str_X): ExecutionUnit.STORE(),

    (add, add_imm): ExecutionUnit.I(),
    (add_lsl, add_lsr): list(map(list, combinations(ExecutionUnit.I(), 2))),

    vsrshr: ExecutionUnit.V(),

    St4: list(map(list, product(ExecutionUnit.STORE(), ExecutionUnit.V()))),

    Ld4: [list(l[0] + (l[1],)) for l in map(list, (product(combinations(ExecutionUnit.LOAD(), 2), ExecutionUnit.V())))]
}

# NOTE: Throughput as defined in https://dougallj.github.io/applecpu/firestorm.html
# refers to "cycles per instruction", as opposed to "instructions per cycle"
# from the Arm SWOGs.
# Based on the data from https://dougallj.github.io/applecpu/firestorm.html, the
# inverse throughput can be obtained by multiplying the throughput `TP` given in
# the tables by the number of execution units able to execute the given instruction.

inverse_throughput = {
    (vmul, vmul_lane,
     vqrdmulh, vqrdmulh_lane,
     vmla, vmla_lane,
     vmls, vmls_lane,
     vqdmulh_lane): 1,

    (vadd, vsub,
     trn1, trn2): 1,

    Vins: 1,
    umov_d: 2,

    (add, add_imm): 1,
    (add_lsl, add_lsr): 1,

    (Ldr_Q,
     Str_Q,
     q_ldr1_stack, Ld2, Ldr_X, Str_X): 1,

    vsrshr: 1,

    St4: 5,  # guessed
    Ld4: 5  # guessed
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

    (Ldr_Q): 4,  # probably something less than 10
    (Str_Q): 4,  # guessed
    (Ldr_X): 3,  # something less than 5
    (Str_X): 4,  # guessed
    (q_ldr1_stack, Ld2): 4,  # guessed
    Vins: 2,  # or something less than 13
    umov_d: 5,  # less than 11

    (add, add_imm): 1,
    (add_lsl, add_lsr): 2,

    vsrshr: 3,
    St4: 4,  # guessed
    Ld4: 6  # guessed
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

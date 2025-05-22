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

"""
Experimental and incomplete model capturing an approximation of the
frontend limitations and latencies of the Cortex-A72 CPU.

It might be surprising at first that an in-order optimizer such as Slothy could be
used for an out of order core such as Cortex-A72.

The key observation is that unless the frontend is much wider than the backend,
a high overall throughput requires a high throughput in the frontend. Since the
frontend is in-order and has documented dispatch constraints, we can model those
constraints in SLOTHY.

The consideration of latencies is less important, yet not irrelevant in this view:
Instructions dispatched well before they are ready to execute will occupy the issue
queue (IQ) for a long time, and once the IQs are full, the frontend will stall.
It is therefore advisable to generally seek to obey latencies to reduce presssure
on issue queues.

This file thus tries to model basic aspects of the frontend of Cortex-A72
alongside instruction latencies, both taken from the Cortex-A72 Software Optimization
Guide.

.. note::

    We focus on a very small subset of AArch64, just enough to experiment with the
    optimization of the Kyber and Dilithium NTT.
"""

from enum import Enum, auto
from slothy.targets.aarch64.aarch64_neon import (
    lookup_multidict,
    find_class,
    all_subclass_leaves,
    Ldr_X,
    Str_X,
    Ldr_Q,
    Str_Q,
    vadd,
    vmul,
    St4,
    Vzip,
    vsub,
    Vmull,
    Vmlal,
    vmul_lane,
    vmla,
    vmla_lane,
    vmls,
    vmls_lane,
    vqrdmulh,
    vqrdmulh_lane,
    vqdmulh_lane,
    trn1,
    trn2,
    ASimdCompare,
    Vins,
    umov_d,
    add,
    add_imm,
    add_lsl,
    add_lsr,
    VShiftImmediateRounding,
    VShiftImmediateBasic,
    St3,
    St2,
    Ld3,
    Ld4,
    ubfx,
)

# From the A72 SWOG, Section "4.1 Dispatch Constraints"
# "The dispatch stage can process up to three µops per cycle"
# The name `issue_rate` is a slight misnomer here because we're
# modelling the frontend, not the backend, but `issue_width` is
# what SLOTHY expects.
issue_rate = 3
llvm_mca_target = "cortex-a72"


class ExecutionUnit(Enum):
    """Enumeration of execution units in approximative Cortex-A72 SLOTHY model"""

    LOAD0 = auto()
    LOAD1 = auto()
    STORE0 = auto()
    STORE1 = auto()
    INT0 = auto()
    INT1 = auto()
    MINT0 = auto()
    MINT1 = auto()
    ASIMD0 = auto()
    ASIMD1 = auto()

    def __repr__(self):
        return self.name

    @classmethod
    def ASIMD(cls):
        return [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1]

    @classmethod
    def LOAD(cls):
        return [ExecutionUnit.LOAD0, ExecutionUnit.LOAD1]

    @classmethod
    def STORE(cls):
        return [ExecutionUnit.STORE0, ExecutionUnit.STORE1]

    @classmethod
    def INT(cls):
        return [ExecutionUnit.INT0, ExecutionUnit.INT1]

    @classmethod
    def MINT(cls):
        return [ExecutionUnit.MINT0, ExecutionUnit.MINT1]

    @classmethod
    def SCALAR(cls):
        return ExecutionUnit.INT() + ExecutionUnit.MINT()


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    _ = slothy


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    _ = slothy
    return False


def get_min_max_objective(slothy):
    _ = slothy


execution_units = {
    (
        vmul,
        vmul_lane,
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vqdmulh_lane,
        Vmlal,
        Vmull,
    ): [ExecutionUnit.ASIMD0],
    (vadd, vsub, Vzip, trn1, trn2, ASimdCompare): [
        ExecutionUnit.ASIMD0,
        ExecutionUnit.ASIMD1,
    ],
    Vins: [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    umov_d: ExecutionUnit.LOAD(),  # ???
    (Ldr_Q, Ldr_X): ExecutionUnit.LOAD(),
    (Str_Q, Str_X): ExecutionUnit.STORE(),
    (add, add_imm, add_lsl, add_lsr, ubfx): ExecutionUnit.SCALAR(),
    (VShiftImmediateRounding, VShiftImmediateBasic): [ExecutionUnit.ASIMD1],
    (St4, St3, St2): [ExecutionUnit.ASIMD0, ExecutionUnit.ASIMD1],
    (Ld3, Ld4): [
        [ExecutionUnit.ASIMD0, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
        [ExecutionUnit.ASIMD1, ExecutionUnit.LOAD0, ExecutionUnit.LOAD1],
    ],
}

inverse_throughput = {
    (
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vmla,
        vmla_lane,
        vmls,
        vmls_lane,
        vqdmulh_lane,
    ): 2,
    (Vmull, Vmlal): 1,
    Vzip: 1,
    (vadd, vsub, trn1, trn2, ASimdCompare): 1,
    Vins: 1,
    umov_d: 1,
    (add, add_imm, add_lsl, add_lsr): 1,
    (Ldr_Q, Str_Q, Ldr_X, Str_X): 1,
    (VShiftImmediateRounding, VShiftImmediateBasic): 1,
    # TODO: this seems in accurate; revisiting may improve performance
    St2: 4,
    St3: 6,
    St4: 8,
    Ld3: 3,
    Ld4: 4,
    ubfx: 1,
}

# REVISIT
default_latencies = {
    (
        vmul,
        vmul_lane,
        vqrdmulh,
        vqrdmulh_lane,
        vmls,
        vmls_lane,
        vmla,
        vmla_lane,
        vqdmulh_lane,
    ): 5,
    (Vmull, Vmlal): 1,
    (
        vadd,
        vsub,
        Vzip,
        trn1,
        trn2,
        ASimdCompare,
    ): 3,  # Approximation -- not necessary to get it exactly right, as mentioned above
    (Ldr_Q, Ldr_X, Str_Q, Str_X): 4,  # approx
    Vins: 6,  # approx
    umov_d: 4,  # approx
    (add, add_imm, add_lsl, add_lsr): 2,
    VShiftImmediateRounding: 3,  # approx
    VShiftImmediateBasic: 3,
    # TODO: this seems in accurate; revisiting may improve performance
    St2: 4,
    St3: 6,
    St4: 8,
    Ld3: 3,
    Ld4: 4,
    ubfx: 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src)

    # Fast mul->mla forwarding
    if (
        instclass_src in [vmul, vmul_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mla->mla forwarding
    if (
        instclass_src in [vmla, vmla_lane, vmls, vmls_lane]
        and instclass_dst in [vmla, vmla_lane, vmls, vmls_lane]
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mull->mlal forwarding
    if (
        instclass_src in all_subclass_leaves(Vmull)
        and instclass_dst in all_subclass_leaves(Vmlal)
        and src.args_out[0] == dst.args_in_out[0]
    ):
        return 1
    # Fast mlal->mlal forwarding
    if (
        instclass_src in all_subclass_leaves(Vmlal)
        and instclass_dst in all_subclass_leaves(Vmlal)
        and src.args_in_out[0] == dst.args_in_out[0]
    ):
        return 1

    return latency


def get_units(src):
    units = lookup_multidict(execution_units, src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    return lookup_multidict(inverse_throughput, src)

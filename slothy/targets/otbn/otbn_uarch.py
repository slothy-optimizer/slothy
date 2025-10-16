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
OTBN coprocessor.
"""

from enum import Enum, auto
from slothy.helper import lookup_multidict
from slothy.targets.otbn.otbn import (
    find_class,
    all_subclass_leaves,
    OTBNInstruction,
)

# From the A72 SWOG, Section "4.1 Dispatch Constraints"
# "The dispatch stage can process up to three µops per cycle"
# The name `issue_rate` is a slight misnomer here because we're
# modelling the frontend, not the backend, but `issue_width` is
# what SLOTHY expects.
issue_rate = 1
llvm_mca_target = ""


class ExecutionUnit(Enum):
    """Enumeration of execution units in approximative Cortex-A72 SLOTHY model"""

    OTBN = auto()

    def __repr__(self):
        return self.name


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
    (OTBNInstruction): [ExecutionUnit.OTBN],
}

inverse_throughput = {
    (OTBNInstruction,): 1,
}

# REVISIT
default_latencies = {
    (OTBNInstruction,): 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src, instclass_src)

    return latency


def get_units(src):
    instclass_src = find_class(src)
    units = lookup_multidict(execution_units, src, instclass_src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    instclass_src = find_class(src)
    return lookup_multidict(inverse_throughput, src, instclass_src)

#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
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

# Playground for experiments

import logging
import re

from enum import Enum
from .aarch64_neon import *

issue_rate = 1

class ExecutionUnit(Enum):
    LSU=0
    SCALAR=1,
    VALU=2,
    def __repr__(self):
        return self.name

# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    pass

# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    return False
def get_min_max_objective(slothy):
    return

execution_units = {
    ( add, sub, mul, mla, sqrdmulh ) : ExecutionUnit.VALU,
    ( vldr, vstr ) : ExecutionUnit.LSU,
    nop : ExecutionUnit.SCALAR,
}

inverse_throughput = {
    ( add, sub, mul, mla, sqrdmulh, vstr ) : 1,
    vldr : 2,
    nop : 1,
}

default_latencies = {
    ( add, sub ) : 2,
    ( mul, mla, sqrdmulh ) : 4,
    vldr : 4
}

def _find_class(src):
    for inst_class in Instruction.__subclasses__():
        if isinstance(src,inst_class):
            return inst_class
    raise Exception("Couldn't find instruction class")

def _lookup_multidict(d, k, default=None):
    for l,v in d.items():
        if k == l:
            return v
        if isinstance(l,tuple) and k in l:
            return v
    if default == None:
        raise Exception(f"Couldn't find {k}")
    return default

def get_latency(src, out_idx, dst):
    instclass_src = _find_class(src)
    instclass_dst = _find_class(dst)

    default_latency = _lookup_multidict(
        default_latencies, instclass_src)

    return default_latency

def get_units(src):
    instclass = _find_class(src)
    units = _lookup_multidict(execution_units, instclass)
    if isinstance(units,list):
        return units
    else:
        return [units]

def get_inverse_throughput(src):
    instclass = _find_class(src)
    return _lookup_multidict(
        inverse_throughput, instclass)

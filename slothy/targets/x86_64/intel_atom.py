#
# Copyright (c) 2026 Maggie Simmons
# Copyright (c) 2026 Hayden Parsons
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

from enum import Enum
from slothy.helper import lookup_multidict
from slothy.targets.x86_64.x86_64 import find_class
from slothy.targets.x86_64.x86_64_base_instructions import (
    add_hi,
    add_si,
    add_di,
    add_qi,
    add_hh,
    add_ss,
    add_dd,
    add_qq,
    and_qq,
    jnz,
    jz,
    mov_qi,
    mov_qq,
    movq,
    movq_i,
    mov_from_mem,
    mov_from_mem_offset,
    mov_to_mem,
    mov_to_mem_offset,
    not_q,
    or_qq,
    pop,
    push,
    rol_qi,
    rol1,
    shr_qi,
    sub_qi,
    test_qi,
    xchg_q,
    xor_qi,
    xor_qq,
    xor_from_mem_offset,
    xor_to_mem_offset,
)
from slothy.targets.x86_64.x86_64_sse_instructions import (
    movdqu_x_from_mem_offset,
    movdqu_x_to_mem_offset,
    pxor_x_from_mem_offset,
    pxor_xx,
)
from slothy.targets.x86_64.x86_64_avx_instructions import (  # noqa: F401
    vpunpcklqdq_yyy,
)

issue_rate = 2
llvm_mca_target = "atom"


class ExecutionUnit(Enum):
    """Enumeration of execution units in intel Atom model"""

    ALU0 = 1
    ALU1 = 2
    MUL = 3
    DIV = 4
    MEM = 5
    FP0 = 6
    FP1 = 7

    def __repr__(self):
        return self.name

    @classmethod
    def SCALAR(cls):
        """All scalar execution units"""
        return [ExecutionUnit.ALU0, ExecutionUnit.ALU1]

    @classmethod
    def SCALAR_MUL(cls):
        """All multiply-capable scalar execution units"""
        return [ExecutionUnit.MUL]


# Opt-in constraint for a Bonnell memory-access quirk (h2parson, 97d697b): memory
# accesses with the same immediate offset but different base registers that issue
# fewer than 8 cycles apart stalled on hardware more than predicted. On average this
# made SLOTHY's predictions more accurate and stall counts lower, but it is an
# oversimplification of the real behaviour and should be reformulated once its root
# cause is understood, so it is off by default. Enable with
#   slothy.targets.x86_64.intel_atom.memory_offset_constraint = True
memory_offset_constraint = False
MEMORY_OFFSET_CYCLE_BUFFER = 8


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    if not memory_offset_constraint:
        return

    from itertools import combinations, product

    from sympy import simplify

    def offset_key(offset):
        # Compare offsets by value: 16(%rdi) and 2*8(%rsp) have the same offset
        try:
            return str(simplify(offset))
        except Exception:
            return offset.strip()

    # Start-cycle variables of memory accesses, keyed by offset and base register
    offset_dict = {}
    for node in slothy._model.tree.nodes:
        inst = node.inst
        offset = getattr(inst, "offset", None)
        if offset is not None:
            addr = getattr(inst, "addr", None)
            offset_dict.setdefault(offset_key(offset), {}).setdefault(addr, []).append(
                node.cycle_start_var
            )

    model = slothy._model.cp_model
    cycle_buffer = MEMORY_OFFSET_CYCLE_BUFFER

    # Pairs of instructions with the same offset but distinct base registers are at
    # least cycle_buffer cycles apart
    for addr_dict in offset_dict.values():
        for addr1, addr2 in combinations(list(addr_dict.keys()), 2):
            for x, y in product(addr_dict[addr1], addr_dict[addr2]):
                b = model.NewBoolVar("")
                model.Add(x - y >= cycle_buffer).OnlyEnforceIf(b)
                model.Add(y - x >= cycle_buffer).OnlyEnforceIf(b.Not())


def has_min_max_objective(config):
    _ = config
    return False


def get_min_max_objective(slothy):
    _ = slothy
    return


execution_units = {
    # Microcoded; measured inverse throughput 6 (see inverse_throughput), so model it
    # as occupying every execution unit
    (xchg_q,): [[unit for unit in ExecutionUnit]],
    (
        rol_qi,
        rol1,
        rol_qi,
        shr_qi,
    ): [
        ExecutionUnit.ALU0,
    ],
    (
        jnz,
        jz,
    ): [
        ExecutionUnit.ALU1,
    ],
    (
        movdqu_x_from_mem_offset,
        movdqu_x_to_mem_offset,
    ): [ExecutionUnit.MEM],
    (
        add_hi,
        add_si,
        add_di,
        add_qi,
        add_hh,
        add_ss,
        add_dd,
        add_qq,
        and_qq,
        mov_qi,
        mov_qq,
        movq,
        movq_i,
        not_q,
        or_qq,
        sub_qi,
        test_qi,
        xor_qi,
        xor_qq,
    ): [
        ExecutionUnit.ALU0,
        ExecutionUnit.ALU1,
    ],
    (pxor_xx,): [
        ExecutionUnit.FP0,
        ExecutionUnit.FP1,
    ],
    (
        mov_from_mem,
        mov_from_mem_offset,
        mov_to_mem,
        mov_to_mem_offset,
        xor_from_mem_offset,
        xor_to_mem_offset,
    ): [[ExecutionUnit.ALU0, ExecutionUnit.MEM]],
    # Needs the MEM unit and an FP unit. Modelled as FP0 + MEM only: a choice between
    # groups ([[FP0, MEM], [FP1, MEM]]) is not supported by SLOTHY's unit model
    (pxor_x_from_mem_offset,): [[ExecutionUnit.FP0, ExecutionUnit.MEM]],
    (
        pop,
        push,
    ): [
        [
            unit for unit in ExecutionUnit
        ]  # Not pairable so model as using every execution unit
    ],
}

inverse_throughput = {
    (
        add_hi,
        add_si,
        add_di,
        add_qi,
        add_hh,
        add_ss,
        add_dd,
        add_qq,
        and_qq,
        mov_qi,
        mov_qq,
        movq,
        movq_i,
        mov_from_mem,
        mov_from_mem_offset,
        mov_to_mem,
        mov_to_mem_offset,
        not_q,
        or_qq,
        pop,
        push,
        pxor_x_from_mem_offset,
        pxor_xx,
        rol_qi,
        rol1,
        rol_qi,
        shr_qi,
        sub_qi,
        test_qi,
        xor_qi,
        xor_qq,
        xor_from_mem_offset,
        xor_to_mem_offset,
    ): 1,
    (
        jnz,
        jz,
    ): 2,
    (
        movdqu_x_from_mem_offset,
        movdqu_x_to_mem_offset,
        xchg_q,
    ): 6,
}

default_latencies = {
    (
        jnz,
        jz,
    ): 0,
    (
        add_hi,
        add_si,
        add_di,
        add_qi,
        add_hh,
        add_ss,
        add_dd,
        add_qq,
        and_qq,
        mov_qi,
        mov_qq,
        movq,
        movq_i,
        mov_from_mem,
        mov_from_mem_offset,
        mov_to_mem,
        mov_to_mem_offset,
        not_q,
        or_qq,
        pop,
        push,
        pxor_x_from_mem_offset,
        pxor_xx,
        rol_qi,
        rol1,
        rol_qi,
        shr_qi,
        sub_qi,
        test_qi,
        xor_qi,
        xor_qq,
        xor_from_mem_offset,
        xor_to_mem_offset,
    ): 1,
    (
        movdqu_x_from_mem_offset,
        movdqu_x_to_mem_offset,
        xchg_q,
    ): 6,
}


def get_latency(src, out_idx, dst):
    _ = out_idx
    _ = dst

    instclass_src = find_class(src)

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

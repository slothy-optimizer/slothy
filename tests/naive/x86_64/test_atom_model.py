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

"""Unit tests for the Intel Atom (Bonnell) microarchitectural model"""

import logging
import re
import shutil
import subprocess
from itertools import combinations

from slothy import Slothy
from slothy.helper import SourceLine
import slothy.targets.x86_64.x86_64 as Arch
import slothy.targets.x86_64.intel_atom as Target

# Measured with nanoBench on Bonnell, one instruction form at a time:
# instruction -> (inverse throughput, latency or None if not measured)
MEASURED = {
    "add %rbx, %rax": (0.5, 1.0),
    "add $1, %rax": (0.5, 1.0),
    "mov %rbx, %rax": (0.5, 1.0),
    "mov $1, %rax": (0.875, 1.0),
    "mov (%rdi), %rax": (1.0, None),
    "mov %rax, (%rdi)": (1.0, None),
    "mov 8(%rdi), %rax": (1.0, None),
    "mov %rax, 8(%rdi)": (1.0, None),
    "not %rax": (0.5, 1.0),
    "or %rbx, %rax": (0.5, 1.0),
    "pop %rax": (1.0, 1.0),
    "push %rax": (1.0, 1.0),
    "rol $1, %rax": (1.0, 1.0),
    "rol %rax": (1.0, 1.0),
    "shr $1, %rax": (1.0, 1.0),
    "sub $1, %rax": (0.5, 1.0),
    "xchg %rax, %rbx": (6.0, 6.0),
    "xor $1, %rax": (0.5, 1.0),
    "xor %rbx, %rax": (0.5, 1.0),
    "xor 8(%rdi), %rax": (1.0, None),
    "xor %rax, 8(%rdi)": (1.0, None),
}

# Known differences between model and measurement: instruction -> modelled
# inverse throughput. Update or remove when the model is changed.
KNOWN_DEVIATIONS = {
    # Modelled like other ALU moves; measured slower
    "mov $1, %rax": 0.5,
}


def _parse(line):
    return Arch.Instruction.parser(SourceLine(line))[0]


def _max_parallel(alternatives):
    """Most instructions that can run at once: largest set of alternatives that
    pairwise share no unit"""
    alternatives = [set(a) if isinstance(a, list) else {a} for a in alternatives]
    for k in range(len(alternatives), 0, -1):
        for subset in combinations(alternatives, k):
            units = [u for alt in subset for u in alt]
            if len(units) == len(set(units)):
                return k
    return 0


def _modelled_inverse_throughput(inst):
    units = Target.get_units(inst)
    if len(units) == 0:
        return 0.0
    return Target.get_inverse_throughput(inst) / _max_parallel(units)


def test_memory_source_unit_groups():
    """Memory-source xor and pxor each need the MEM unit plus one ALU/FP unit, modelled
    as a single group (SLOTHY doesn't support a choice between groups)"""
    EU = Target.ExecutionUnit
    assert Target.get_units(_parse("pxor 8(%rdi), %xmm0")) == [[EU.FP0, EU.MEM]]
    assert Target.get_units(_parse("xor 8(%rdi), %rax")) == [[EU.ALU0, EU.MEM]]


def test_unpairable_instructions_use_all_units():
    """push, pop and the microcoded xchg occupy every execution unit"""
    for line in ["push %rax", "pop %rax", "xchg %rax, %rbx"]:
        units = Target.get_units(_parse(line))
        assert len(units) == 1
        assert set(units[0]) == set(Target.ExecutionUnit)


def test_model_matches_measurements():
    for line, (inv_thr, latency) in MEASURED.items():
        inst = _parse(line)
        modelled = _modelled_inverse_throughput(inst)
        expected = KNOWN_DEVIATIONS.get(line, inv_thr)
        assert modelled == expected, f"{line}: modelled {modelled}, expected {expected}"
        if latency is not None:
            assert Target.get_latency(inst, 0, None) == latency, line


def _expected_cycles(body):
    logger = logging.getLogger("atom_test")
    logger.addHandler(logging.NullHandler())
    logger.propagate = False
    slothy = Slothy(Arch, Target, logger=logger)
    slothy.load_source_raw("start:\n" + body + "end:\n")
    slothy.config.allow_useless_instructions = True
    slothy.config.variable_size = True
    slothy.config.selftest = False
    slothy.optimize(start="start", end="end")
    src = slothy.get_source_as_string()
    return int(re.search(r"Expected cycles:\s*(\d+)", src).group(1))


def test_scheduling_respects_shared_mem_unit():
    """Memory-source xors and pxors serialize on the single MEM unit, while register
    xors dual-issue on the two ALUs"""
    regs = ["rax", "rbx", "rcx", "rdx", "r8", "r9", "r10", "r11"]
    mem_xors = "".join(f"        xor {8 * i}(%rdi), %{r}\n" for i, r in enumerate(regs))
    mem_pxors = "".join(f"        pxor {16 * i}(%rdi), %xmm{i}\n" for i in range(8))
    alu_xors = "".join(f"        xor %rsi, %{r}\n" for r in regs)
    assert _expected_cycles(mem_xors) >= len(regs)
    assert _expected_cycles(mem_pxors) >= 8
    assert _expected_cycles(alu_xors) == len(regs) // 2


def test_memory_offset_constraint_opt_in():
    """Same offset, different base register: adjacent by default, at least 8 cycles
    apart with the opt-in Bonnell constraint"""
    body = "        mov 8(%rdi), %rax\n        mov 8(%rsi), %rbx\n"
    assert Target.memory_offset_constraint is False
    assert _expected_cycles(body) <= 2
    Target.memory_offset_constraint = True
    try:
        assert _expected_cycles(body) > Target.MEMORY_OFFSET_CYCLE_BUFFER
        # Offsets are compared by value
        body = "        mov 16(%rdi), %rax\n        mov 2*8(%rsi), %rbx\n"
        assert _expected_cycles(body) > Target.MEMORY_OFFSET_CYCLE_BUFFER
    finally:
        Target.memory_offset_constraint = False


def test_llvm_mca_accepts_target_name():
    if shutil.which("llvm-mca") is None:
        return
    res = subprocess.run(
        ["llvm-mca", "-mtriple=x86_64", f"-mcpu={Target.llvm_mca_target}"],
        input="nop\n",
        capture_output=True,
        text=True,
    )
    assert "is not a recognized processor" not in res.stderr, res.stderr


def run_atom_model_tests():
    test_memory_source_unit_groups()
    test_unpairable_instructions_use_all_units()
    test_model_matches_measurements()
    test_scheduling_respects_shared_mem_unit()
    test_memory_offset_constraint_opt_in()
    test_llvm_mca_accepts_target_name()


if __name__ == "__main__":
    run_atom_model_tests()

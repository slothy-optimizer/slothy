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

"""Tests for the hardware-free parts of the Keccak-round utility scripts.

Running code under nanoBench needs root and a real Atom, so it is not tested here.
"""

import importlib.util
import logging
from pathlib import Path

from examples.misc.x86_64 import nanobench

SCRIPTS = Path(__file__).resolve().parents[3] / "examples/misc/x86_64"

NANOBENCH_OUTPUT = """\
Some header line
CORE_CYCLES: 117.90
INST_RETIRED: 212.00
L1D_CACHE.ALL_REF: 58.00
"""


def _load_script(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_render_template():
    round_script = _load_script("keccak_round_ex_opts")
    text = "mKeccakRound %{iState}, %{oState}, {rc}, {lastRound}"
    params = {"iState": "rdi", "oState": "rsp", "rc": "0x0", "lastRound": "1"}
    assert (
        round_script.render_template(text, params) == "mKeccakRound %rdi, %rsp, 0x0, 1"
    )
    try:
        round_script.render_template(text, {"iState": "rdi"})
    except KeyError:
        pass
    else:
        raise AssertionError("missing parameter not reported")


def test_round_template_renders_completely():
    round_script = _load_script("keccak_round_ex_opts")
    params = {"iState": "rdi", "oState": "rsp", "rc": "0x0", "lastRound": "0"}
    src = round_script.render_template(round_script.template_path.read_text(), params)
    assert "{" not in src
    assert "mKeccakRound\t%rdi, %rsp, 0x0, 0" in src


def test_stall_counter():
    """The scripts read the stall count from SLOTHY's log"""
    round_script = _load_script("keccak_round_ex_opts")
    counter = round_script.StallCounter()
    logger = logging.getLogger("stall_counter_test")
    logger.propagate = False
    logger.addHandler(counter)
    logger.setLevel(logging.INFO)
    logger.info("Attempt optimization with max 16 stalls...")
    assert counter.stalls is None
    logger.info("Minimum number of stalls: 3")
    assert counter.stalls == 3


def test_parse_nanobench_counters():
    counters = nanobench.parse_counters(NANOBENCH_OUTPUT)
    assert counters == {
        "CORE_CYCLES": 117.9,
        "INST_RETIRED": 212.0,
        "L1D_CACHE.ALL_REF": 58.0,
    }


def test_nanobench_command():
    assert nanobench.nanobench_cmd("NOP", unroll=2, config="c.txt") == [
        "sudo",
        "./nanoBench.sh",
        "-asm",
        "NOP",
        "-config",
        "c.txt",
        "-unroll_count=2",
    ]


def test_to_nanobench_asm():
    asm = nanobench.to_nanobench_asm(["mov 8(%rdi), %rax", "", "xor %rbx, %rax"])
    assert asm == "mov rax, qword ptr [rdi+8]; xor rax, rbx"


def run_keccak_utilities_tests():
    test_render_template()
    test_round_template_renders_completely()
    test_stall_counter()
    test_parse_nanobench_counters()
    test_nanobench_command()
    test_to_nanobench_asm()


if __name__ == "__main__":
    run_keccak_utilities_tests()

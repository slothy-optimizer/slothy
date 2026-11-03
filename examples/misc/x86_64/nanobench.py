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

"""Run code under nanoBench and parse its performance counters.

nanoBench (https://github.com/andreas-abel/nanoBench) needs root and real hardware;
only the output parsing and the code translation here are testable without it.
"""

import os
import subprocess
from pathlib import Path

from slothy.targets.x86_64.x86_translator import Atat_Code

# nanoBench checkout; override with the NANOBENCH_DIR environment variable
DEFAULT_NANOBENCH_DIR = os.environ.get("NANOBENCH_DIR", "../nanoBench")
# Counter config, relative to the nanoBench directory
DEFAULT_CONFIG = "configs/cfg_Bonnell_common.txt"


def to_nanobench_asm(lines):
    """Translate AT&T instruction lines (e.g. SLOTHY x86_64 output) to the
    ``;``-separated Intel string that nanoBench's ``-asm`` option takes"""
    atat_code = Atat_Code(text=[line.strip() for line in lines])
    atat_code.parse_source()
    atat_code.to_intel()
    return "; ".join(line.text for line in atat_code.lines if line.text is not None)


def parse_counters(output):
    """Parse nanoBench output into a dict of counter name -> float.

    nanoBench prints one counter per line as ``NAME: value``; other lines are
    ignored.
    """
    counters = {}
    for line in output.splitlines():
        name, sep, value = line.partition(":")
        if not sep:
            continue
        try:
            counters[name.strip()] = float(value.strip().split(" ")[0])
        except ValueError:
            continue
    return counters


def nanobench_cmd(asm, asm_init=None, unroll=None, config=DEFAULT_CONFIG):
    """Command line for running asm (Intel syntax, ``;``-separated) under nanoBench"""
    cmd = ["sudo", "./nanoBench.sh"]
    if asm_init is not None:
        cmd += ["-asm_init", asm_init]
    cmd += ["-asm", asm, "-config", config]
    if unroll is not None:
        cmd += [f"-unroll_count={unroll}"]
    return cmd


def run(asm, asm_init=None, unroll=None, nanobench_dir=None, config=DEFAULT_CONFIG):
    """Run asm under nanoBench; returns (stdout, stderr)"""
    nanobench_dir = Path(nanobench_dir or DEFAULT_NANOBENCH_DIR)
    result = subprocess.run(
        nanobench_cmd(asm, asm_init=asm_init, unroll=unroll, config=config),
        cwd=nanobench_dir,
        capture_output=True,
        text=True,
    )
    return result.stdout, result.stderr

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

"""
Optimize one Keccak-f[1600] round on Intel Atom with a fixed split-heuristic setup.

Three steps, each writing its result to the output directory:
  0. Register allocation only (functional_only, no reordering)       -> *_0.s
  1. Split-heuristic optimization of the step-0 result               -> *_split.s
  2. Fixed-order pass on the step-1 result to count stalls (in place) -> *_split.s

Usage (from anywhere):
    python3 examples/misc/x86_64/keccak_splitting.py \
        [--output-dir DIR] [--istate REG] [--ostate REG] [--rc RC] [--last-round 0|1]
        [--memory-offset-constraint]
"""

import argparse
import logging
import sys
import tempfile
from pathlib import Path


def find_repo_root():
    """Closest parent directory containing the slothy package"""
    for parent in Path(__file__).resolve().parents:
        if (parent / "slothy" / "__init__.py").is_file():
            return parent
    raise RuntimeError("Could not find the SLOTHY repository root")


REPO_ROOT = find_repo_root()
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from slothy import Slothy  # noqa: E402
import slothy.targets.x86_64.x86_64 as x86_64  # noqa: E402
import slothy.targets.x86_64.intel_atom as intel_atom  # noqa: E402
from slothy.targets.x86_64.x86_translator import Atat_Code  # noqa: E402
from keccak_round_ex_opts import ALL_GPRS, StallCounter, render_template  # noqa: E402

arch = x86_64
target = intel_atom
syntax = Atat_Code

template_path = REPO_ROOT / "examples/naive/x86_64/keccak/x86_mKeccakRound_template.s"

# Split heuristic setup
SPLITS = 6
SPLIT_REPEAT = 2


def reinitialize():
    slothy = Slothy(arch, target, syntax=syntax)
    slothy.config._allow_useless_instructions = True
    slothy.config.reserved_regs = set()
    return slothy


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "opt/keccakSplitting",
        help="directory for the outputs",
    )
    parser.add_argument("--istate", default="rdi", help="input state register")
    parser.add_argument("--ostate", default="rsp", help="output state register")
    parser.add_argument("--rc", default="0x0", help="round constant")
    parser.add_argument("--last-round", default="0", choices=["0", "1"])
    parser.add_argument(
        "--memory-offset-constraint",
        action="store_true",
        help="enable the opt-in Atom constraint intel_atom.memory_offset_constraint "
        "(same offset, different base register: at least 8 cycles apart)",
    )
    args = parser.parse_args()
    intel_atom.memory_offset_constraint = args.memory_offset_constraint

    # SLOTHY's default console logging, plus the stall count of the last pass
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    stall_counter = StallCounter()
    logging.getLogger().addHandler(stall_counter)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    params = {
        "iState": args.istate,
        "oState": args.ostate,
        "rc": args.rc,
        "lastRound": args.last_round,
    }
    name = (
        f"{template_path.stem}_{args.istate}_{args.ostate}_{args.rc}_{args.last_round}"
    )
    out_0 = args.output_dir / f"{name}_0.s"
    out_split = args.output_dir / f"{name}_split.s"

    with tempfile.TemporaryDirectory() as tmp:
        source_path = Path(tmp) / f"{name}.s"
        source_path.write_text(render_template(template_path.read_text(), params))

        # Step 0: register allocation only
        slothy = reinitialize()
        slothy.load_source_from_file(source_path)
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.constraints.functional_only = True
        slothy.optimize(start="start")
        slothy.write_source_to_file(out_0)

    # Step 1: split heuristic
    slothy = reinitialize()
    slothy.load_source_from_file(out_0)
    slothy.config.inputs_are_outputs = True
    slothy.config.variable_size = True
    slothy.config.constraints.stalls_first_attempt = 32
    slothy.config.split_heuristic = True
    slothy.config.split_heuristic_estimate_performance = False
    slothy.config.split_heuristic_stepsize = 1 / (2 * SPLITS)
    slothy.config.split_heuristic_factor = SPLITS
    slothy.config.split_heuristic_repeat = SPLIT_REPEAT
    slothy.config.selftest = False
    slothy.optimize(start="start")
    slothy.write_source_to_file(out_split)

    # Step 2: fixed-order pass to count stalls
    slothy = reinitialize()
    slothy.load_source_from_file(out_split)
    slothy.config.inputs_are_outputs = True
    slothy.config.variable_size = True
    slothy.config.constraints.stalls_first_attempt = 32
    slothy.config.reserved_regs = ALL_GPRS
    slothy.config.constraints.allow_reordering = False
    slothy.config.selftest = False
    stall_counter.stalls = None
    slothy.optimize(start="start")
    slothy.write_source_to_file(out_split)
    print(f"Stalls: {stall_counter.stalls} ({out_split})")


if __name__ == "__main__":
    main()

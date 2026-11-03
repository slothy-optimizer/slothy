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
Sweep SLOTHY's split heuristic over one Keccak-f[1600] round on Intel Atom.

For every combination of macro parameters (input/output state registers, round
constant, last-round flag) and split-heuristic settings, this optimizes the round
with the split heuristic, writes the result, then reruns SLOTHY in fixed order on
the result to count stalls and writes the count at the top of the output file.

Usage (from anywhere):
    python3 examples/misc/x86_64/keccak_round_ex_opts.py \
        [--output-dir DIR] [--max-configs N] [--memory-offset-constraint]
"""

import argparse
import itertools
import logging
import re
import sys
import tempfile
from collections import deque
from pathlib import Path


def find_repo_root():
    """Closest parent directory containing the slothy package"""
    for parent in Path(__file__).resolve().parents:
        if (parent / "slothy" / "__init__.py").is_file():
            return parent
    raise RuntimeError("Could not find the SLOTHY repository root")


REPO_ROOT = find_repo_root()
sys.path.insert(0, str(REPO_ROOT))

from slothy import Slothy  # noqa: E402
import slothy.targets.x86_64.x86_64 as x86_64  # noqa: E402
import slothy.targets.x86_64.intel_atom as intel_atom  # noqa: E402
from slothy.targets.x86_64.x86_translator import Atat_Code  # noqa: E402
from slothy.helper import SourceLine  # noqa: E402

arch = x86_64
target = intel_atom
syntax = Atat_Code

macro_io_pairs = [["rdi", "rsp"], ["rsp", "rdi"]]
macro_rc_options = ["0x0"]
macro_lastround_options = ["0", "1"]
heur_split_step_rep_combos = [
    ["3", ["1", "6"], "1"],
    ["3", ["1", "12"], "1"],
    ["3", ["1", "6"], "2"],
    ["4", ["1", "8"], "1"],
    ["4", ["1", "16"], "1"],
    ["4", ["1", "8"], "2"],
    ["5", ["1", "10"], "1"],
    ["5", ["1", "10"], "2"],
    ["5", ["1", "10"], "3"],
    ["6", ["1", "12"], "1"],
    ["6", ["1", "12"], "2"],
    ["6", ["1", "12"], "3"],
]

ALL_GPRS = ["rax", "rbx", "rcx", "rdx", "rsi", "rdi", "rsp", "rbp",
            "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]  # fmt: skip

template_path = REPO_ROOT / "examples/naive/x86_64/keccak/x86_mKeccakRound_template.s"

# Suppress Slothy's log output, but keep the last 1000 lines buffered in case we need
# to dump them
log_buffer = deque(maxlen=1000)


class BufferHandler(logging.Handler):
    def emit(self, record):
        log_buffer.append(self.format(record))


class StallCounter(logging.Handler):
    """Records the stall count SLOTHY logs when an optimization finishes
    ("Minimum number of stalls: N"); reset ``stalls`` before each run"""

    PATTERN = re.compile(r"Minimum number of stalls: (\d+)")

    def __init__(self):
        super().__init__()
        self.stalls = None

    def emit(self, record):
        match = self.PATTERN.search(record.getMessage())
        if match is not None:
            self.stalls = int(match.group(1))


# Track configs completed so far, so we can report them if we fail partway through
completed_configs = []


# Replace the parameters of the macro
def render_template(text, params):
    def replace(match):
        key = match.group(1)
        if key not in params:
            raise KeyError(f"Missing parameter: {key}")
        return str(params[key])

    return re.sub(r"\{(\w+)\}", replace, text)


def fail(stage, config_str, e):
    print(f"\nFAILED during {stage}")
    print(f"Config: {config_str}")
    print(f"Exception: {e}\n")
    print(f"--- Last {len(log_buffer)} log lines ---")
    for line in log_buffer:
        print(line)
    print("--- Configs completed before failure ---")
    for c in completed_configs:
        print(f"  {c}")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "opt/keccakRound",
        help="directory for the optimized outputs",
    )
    parser.add_argument(
        "--max-configs",
        type=int,
        default=None,
        help="only run the first N split-heuristic configs per macro-parameter set",
    )
    parser.add_argument(
        "--memory-offset-constraint",
        action="store_true",
        help="enable the opt-in Atom constraint intel_atom.memory_offset_constraint "
        "(same offset, different base register: at least 8 cycles apart)",
    )
    args = parser.parse_args()
    intel_atom.memory_offset_constraint = args.memory_offset_constraint
    args.output_dir.mkdir(parents=True, exist_ok=True)

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(logging.INFO)
    buffer_handler = BufferHandler()
    buffer_handler.setFormatter(logging.Formatter("%(name)s:%(levelname)s:%(message)s"))
    root_logger.addHandler(buffer_handler)
    stall_counter = StallCounter()
    root_logger.addHandler(stall_counter)

    template_text = template_path.read_text()
    combos = heur_split_step_rep_combos[: args.max_configs]

    # Create the Slothy instance
    slothy = Slothy(arch, target, syntax=syntax)

    with tempfile.TemporaryDirectory() as tmp:
        # Iterate over dictionaries of macro parameters
        for params in [
            {"iState": i, "oState": o, "rc": rc, "lastRound": lr}
            for [i, o], rc, lr in itertools.product(
                macro_io_pairs, macro_rc_options, macro_lastround_options
            )
        ]:
            macro_str = (
                f"{params['iState']}_{params['oState']}"
                f"_{params['rc']}_{params['lastRound']}"
            )

            # Create temporary file with macro parameters substituted
            source_path = (
                Path(tmp) / f"{template_path.stem}_{macro_str}{template_path.suffix}"
            )
            source_path.write_text(render_template(template_text, params))

            # Now iterate over the splitting heuristic parameters
            for split, [num, denom], rep in combos:
                # Announce that config has begun
                config_str = (
                    f"MACROPARAMS-{macro_str} SPLITPARAMS-{split}_{num}_{denom}_{rep}"
                )
                print(f"Started: {config_str}")

                # Load the temporary source
                slothy.load_source_from_file(source_path)

                # Basic configurations
                slothy.config._allow_useless_instructions = True
                slothy.config.inputs_are_outputs = True
                slothy.config.variable_size = True
                slothy.config.reserved_regs = []
                slothy.config.constraints.allow_reordering = True
                slothy.config.constraints.stalls_first_attempt = 64
                slothy.config.split_heuristic = True

                # Use split heuristic parameters
                slothy.config.split_heuristic_factor = int(split)
                slothy.config.split_heuristic_stepsize = float(num) / float(denom)
                slothy.config.split_heuristic_repeat = int(rep)
                slothy.config.split_heuristic_estimate_performance = False

                # Run the Optimization
                try:
                    slothy.optimize(start="start")
                except Exception as e:
                    fail("FIRST optimization pass (split-heuristic)", config_str, e)

                # Write the result to file
                output_name = (
                    f"keccakRound_MACROPARAMS-{macro_str}"
                    f"__SPLITPARAMS-{split}_{num}_{denom}_{rep}.s"
                )
                output_path = args.output_dir / output_name
                slothy.write_source_to_file(output_path)

                # Now we want to run a trivial optimization on the output file to get
                # the stall information
                slothy.config.reserved_regs = ALL_GPRS
                slothy.config.constraints.allow_reordering = False
                slothy.config.constraints.stalls_first_attempt = 16
                slothy.config.split_heuristic = False

                stall_counter.stalls = None
                try:
                    slothy.optimize(start="start")
                except Exception as e:
                    fail("SECOND optimization pass (stall-count)", config_str, e)
                stalls = stall_counter.stalls

                # Overwrite the output file with stall count at the top
                slothy.source.insert(0, SourceLine(f"Stalls: {stalls}"))
                slothy.source.insert(1, SourceLine(""))
                slothy.write_source_to_file(output_path)

                # Record that this configuration finished successfully
                completed_configs.append(config_str)
                print(f"Finished: {config_str} (stalls: {stalls})")


if __name__ == "__main__":
    main()

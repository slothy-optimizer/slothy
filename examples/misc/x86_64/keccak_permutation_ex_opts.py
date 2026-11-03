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
Sweep SLOTHY's split heuristic over the full Keccak-f[1600] permutation on Intel Atom.

Sibling of keccak_round_ex_opts.py: same two passes (split-heuristic optimization,
then a fixed-order pass to count stalls) and the same output format, but on all 24
rounds chained together instead of a single round.

The split-heuristic settings are the per-round settings of keccak_round_ex_opts.py,
scaled by the number of rounds so that each chunk covers about the same amount of
code as in the single-round sweep.

Usage (from anywhere):
    python3 examples/misc/x86_64/keccak_permutation_ex_opts.py \
        [--rounds N] [--output-dir DIR] [--max-configs N] [--memory-offset-constraint]
"""

import argparse
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
sys.path.insert(0, str(Path(__file__).resolve().parent))

from slothy import Slothy  # noqa: E402
import slothy.targets.x86_64.x86_64 as x86_64  # noqa: E402
import slothy.targets.x86_64.intel_atom as intel_atom  # noqa: E402
from slothy.targets.x86_64.x86_translator import Atat_Code  # noqa: E402
from slothy.helper import SourceLine  # noqa: E402
from keccak_round_ex_opts import StallCounter  # noqa: E402

arch = x86_64
target = intel_atom
syntax = Atat_Code

# Keccak-f[1600] round constants
KECCAK_RC = [
    "0x0000000000000001",
    "0x0000000000008082",
    "0x800000000000808a",
    "0x8000000080008000",
    "0x000000000000808b",
    "0x0000000080000001",
    "0x8000000080008081",
    "0x8000000000008009",
    "0x000000000000008a",
    "0x0000000000000088",
    "0x0000000080008009",
    "0x000000008000000a",
    "0x000000008000808b",
    "0x800000000000008b",
    "0x8000000000008089",
    "0x8000000000008003",
    "0x8000000000008002",
    "0x8000000000000080",
    "0x000000000000800a",
    "0x800000008000000a",
    "0x8000000080008081",
    "0x8000000000008080",
    "0x0000000080000001",
    "0x8000000080008008",
]

# Per-round [split factor, [stepsize numerator, denominator], repeat], as in
# keccak_round_ex_opts.py
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

ALL_GPRS = [
    "rax",
    "rbx",
    "rcx",
    "rdx",
    "rsi",
    "rdi",
    "rsp",
    "rbp",
    "r8",
    "r9",
    "r10",
    "r11",
    "r12",
    "r13",
    "r14",
    "r15",
]

template_path = (
    REPO_ROOT / "examples/naive/x86_64/keccak/x86_mKeccakPermutation_template.s"
)

# Suppress Slothy's log output, but keep the last 1000 lines buffered in case we need
# to dump them
log_buffer = deque(maxlen=1000)


class BufferHandler(logging.Handler):
    def emit(self, record):
        log_buffer.append(self.format(record))


# Track configs completed so far, so we can report them if we fail partway through
completed_configs = []


def render_rounds(num_rounds):
    """Round invocations for the first num_rounds rounds; the last is marked lastRound."""
    lines = []
    for r in range(num_rounds):
        i_state, o_state = (
            ("rpState", "rpStack") if r % 2 == 0 else ("rpStack", "rpState")
        )
        last_round = 1 if r == num_rounds - 1 else 0
        lines.append(
            f"\t\tmKeccakRound\t{i_state}, {o_state}, {KECCAK_RC[r]}, {last_round}"
        )
        if r % 6 == 5 and r != num_rounds - 1:
            lines.append("")
    return "\n".join(lines)


# Replace the parameters of the template
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
        "--rounds",
        type=int,
        default=24,
        help="number of permutation rounds to include (1-24, default 24)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "opt/keccakPermutation",
        help="directory for the optimized outputs",
    )
    parser.add_argument(
        "--max-configs",
        type=int,
        default=None,
        help="only run the first N split-heuristic configs",
    )
    parser.add_argument(
        "--memory-offset-constraint",
        action="store_true",
        help="enable the opt-in Atom constraint intel_atom.memory_offset_constraint "
        "(same offset, different base register: at least 8 cycles apart)",
    )
    args = parser.parse_args()
    intel_atom.memory_offset_constraint = args.memory_offset_constraint

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(logging.INFO)
    buffer_handler = BufferHandler()
    buffer_handler.setFormatter(logging.Formatter("%(name)s:%(levelname)s:%(message)s"))
    root_logger.addHandler(buffer_handler)
    stall_counter = StallCounter()
    root_logger.addHandler(stall_counter)

    if not 1 <= args.rounds <= len(KECCAK_RC):
        parser.error(f"--rounds must be between 1 and {len(KECCAK_RC)}")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    source = render_template(
        template_path.read_text(), {"rounds": render_rounds(args.rounds)}
    )
    combos = heur_split_step_rep_combos[: args.max_configs]

    with tempfile.TemporaryDirectory() as tmp:
        source_path = (
            Path(tmp) / f"{template_path.stem}_{args.rounds}{template_path.suffix}"
        )
        source_path.write_text(source)

        for split, [num, denom], rep in combos:
            # Scale per-round settings to the number of rounds
            factor = int(split) * args.rounds
            denom_scaled = int(denom) * args.rounds
            config_str = (
                f"ROUNDS-{args.rounds} SPLITPARAMS-{factor}_{num}_{denom_scaled}_{rep}"
            )
            print(f"Started: {config_str}")

            slothy = Slothy(arch, target, syntax=syntax)
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
            slothy.config.split_heuristic_factor = factor
            slothy.config.split_heuristic_stepsize = float(num) / float(denom_scaled)
            slothy.config.split_heuristic_repeat = int(rep)
            slothy.config.split_heuristic_estimate_performance = False

            # Run the Optimization
            try:
                slothy.optimize(start="start")
            except Exception as e:
                fail("FIRST optimization pass (split-heuristic)", config_str, e)

            # Write the result to file
            output_name = (
                f"keccakPermutation_ROUNDS-{args.rounds}"
                f"__SPLITPARAMS-{factor}_{num}_{denom_scaled}_{rep}.s"
            )
            output_path = args.output_dir / output_name
            slothy.write_source_to_file(output_path)

            # Now run a trivial optimization on the output to get the stall information
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

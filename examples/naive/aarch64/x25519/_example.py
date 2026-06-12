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
# Author: Amin Abdulrahman <amin@abdulrahman.de>
#

import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class x25519_scalarmult(OptimizationRunner):
    """Multi-pass optimization of X25519 scalar multiplication for Cortex-A55.

    Implements the optimization pipeline from paper/scripts/slothy_x25519.sh:

    Step 0: Resolve symbolic registers (functional-only, no reordering).
    Step 1: Preprocessing pass using naive interleaving heuristic.
    Steps 2-5: Stepwise optimization sweeps without latency modeling.
    Steps 6-8: Final sweeps with full latency modeling and seam optimization.
    """

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = "x25519_scalarmult"
        infile = "X25519-AArch64-simple"

        super().__init__(
            infile,
            name,
            funcname="x25519_scalarmult_alt_orig",
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        # Detect whether the framework put us in dry-run / functional-only mode
        # so we can skip the expensive optimization passes.
        dry_run = slothy.config.constraints.functional_only

        # ------------------------------------------------------------------
        # Step 0: Resolve symbolic registers.
        # Use functional-only mode to just resolve register allocation without
        # any scheduling, preserving the original instruction order.
        # ------------------------------------------------------------------
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.optimize(start="mainloop", end="end_label")

        if dry_run:
            return

        slothy.config.constraints.functional_only = False
        slothy.config.constraints.allow_reordering = True

        # Save the base config so each subsequent pass can start clean.
        conf = slothy.config.copy()

        # ------------------------------------------------------------------
        # Step 1: Preprocessing.
        # Use the naive interleaving heuristic to get an initial interleaved
        # code layout without caring about performance estimation yet.
        # ------------------------------------------------------------------
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 0
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # ------------------------------------------------------------------
        # Steps 2-5: Stepwise optimization sweeps without latency modeling.
        # The goal is to build up good interleaving by combing stalls toward
        # the middle repeatedly. Latency constraints are intentionally omitted
        # here to allow more freedom in scheduling.
        # ------------------------------------------------------------------

        # Step 2: Sweep full region [0, 1], factor 6.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 300
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.objective_precision = 0.1
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.split_heuristic_factor = 6
        slothy.config.constraints.model_latencies = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 3: Sweep first 60% [0, 0.6], push stalls toward the bottom.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 180
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 0.6]
        slothy.config.objective_precision = 0.1
        slothy.config.constraints.move_stalls_to_bottom = True
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.split_heuristic_factor = 4
        slothy.config.constraints.model_latencies = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 4: Sweep last 70% [0.3, 1], bottom-to-top, push stalls up,
        # repeat once.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 240
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0.3, 1]
        slothy.config.objective_precision = 0.1
        slothy.config.constraints.move_stalls_to_top = True
        slothy.config.split_heuristic_bottom_to_top = True
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_repeat = 1
        slothy.config.constraints.model_latencies = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 5: Sweep last 70% [0.3, 1] again, push stalls up, repeat once.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 240
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0.3, 1]
        slothy.config.objective_precision = 0.1
        slothy.config.constraints.move_stalls_to_top = True
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_repeat = 1
        slothy.config.constraints.model_latencies = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # ------------------------------------------------------------------
        # Steps 6-8: Final optimization passes with full latency modeling.
        # These refine the schedule to account for actual CPU latencies and
        # use seam optimization across split boundaries.
        # ------------------------------------------------------------------

        # Step 6: Full sweep [0, 1] with latencies, seam optimization, repeat once.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 300
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.objective_precision = 0.1
        slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_optimize_seam = 10
        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_repeat = 1
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 7: Full sweep [0, 1] bottom-to-top, push stalls up,
        # seam optimization, repeat twice.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 300
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.split_heuristic_bottom_to_top = True
        slothy.config.objective_precision = 0.1
        slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_optimize_seam = 10
        slothy.config.constraints.move_stalls_to_top = True
        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_repeat = 2
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 8: Final full sweep [0, 1], push stalls up, seam optimization.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 512
        slothy.config.timeout = 300
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.objective_precision = 0.1
        slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_optimize_seam = 10
        slothy.config.constraints.move_stalls_to_top = True
        slothy.config.split_heuristic_factor = 8
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")


class x25519_scalarmult_ci(OptimizationRunner):
    """Reduced x25519 optimization pipeline for CI.

    Covers each distinct feature used in x25519_scalarmult at least once, but
    with aggressive parameters (high stall budgets, coarse step sizes, low
    timeouts, no repeats) and with redundant passes removed:

    Step 0: Symbolic register resolution (functional-only, same as full).
    Step 1: Naive interleaving preprocessing.
    Step 2: No-latency sweep, move_stalls_to_bottom.
    Step 3: No-latency sweep, move_stalls_to_top + bottom_to_top.
    Step 4: Latency-aware sweep with seam optimization.
    """

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = "x25519_scalarmult_ci"
        infile = "X25519-AArch64-simple"

        super().__init__(
            infile,
            name,
            funcname="x25519_scalarmult_alt_orig",
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        dry_run = slothy.config.constraints.functional_only

        # Step 0: Resolve symbolic registers (fast, always runs).
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.optimize(start="mainloop", end="end_label")

        if dry_run:
            return

        slothy.config.constraints.functional_only = False
        slothy.config.constraints.allow_reordering = True

        conf = slothy.config.copy()

        # Step 1: Naive interleaving preprocessing.
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 0
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 2: No-latency sweep, move stalls to bottom.
        # Covers: model_latencies=False, move_stalls_to_bottom.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 2
        slothy.config.timeout = 30
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0.1, 0.9]
        slothy.config.objective_precision = 0.5
        slothy.config.split_heuristic_stepsize = 0.5
        slothy.config.split_heuristic_factor = 20
        slothy.config.constraints.move_stalls_to_bottom = True
        slothy.config.constraints.model_latencies = False
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 3: No-latency sweep, move stalls to top, bottom-to-top direction.
        # Covers: move_stalls_to_top, split_heuristic_bottom_to_top.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 2
        slothy.config.timeout = 30
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.objective_precision = 0.5
        slothy.config.constraints.move_stalls_to_top = True
        slothy.config.split_heuristic_bottom_to_top = True
        slothy.config.split_heuristic_stepsize = 0.5
        slothy.config.split_heuristic_factor = 20
        slothy.config.constraints.model_latencies = False
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")

        # Step 4: Latency-aware sweep with seam optimization.
        # Covers: full latency modeling, split_heuristic_optimize_seam.
        slothy.config = conf.copy()
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = ["x0"]
        slothy.config.variable_size = True
        slothy.config.max_solutions = 2
        slothy.config.timeout = 30
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_region = [0, 1]
        slothy.config.objective_precision = 0.5
        slothy.config.split_heuristic_stepsize = 0.5
        slothy.config.split_heuristic_optimize_seam = 2
        slothy.config.split_heuristic_factor = 20
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.selftest = False
        slothy.optimize(start="mainloop", end="end_label")


example_instances = [
    x25519_scalarmult(),
    x25519_scalarmult_ci(),
]

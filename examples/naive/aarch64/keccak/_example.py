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


class neon_keccak_x1_no_symbolic(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "keccak_f1600_x1_scalar_slothy_no_symbolic"
        infile = "keccak_f1600_x1_scalar_slothy"
        outfile = "examples/naive/aarch64/keccak/keccak_f1600_x1_scalar_no_symbolic.s"
        super().__init__(
            infile,
            name,
            outfile=outfile,
            rename=True,
            arch=arch,
            target=target,
            outfile_full=True,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.constraints.minimize_spills = True
        slothy.config.constraints.allow_reordering = True
        slothy.config.constraints.allow_spills = True
        # NOTE:
        # There are better solutions to this (the true minimum seems to be 1),
        # but they take a long time to find.
        slothy.config.objective_lower_bound = 6
        slothy.config.visualize_expected_performance = True
        slothy.optimize(start="loop", end="end_loop")

        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial_round_start", end="initial_round_end")


class neon_keccak_x1_scalar_opt(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "keccak_f1600_x1_scalar_opt"
        infile = "keccak_f1600_x1_scalar_no_symbolic"
        outfile = "keccak_f1600_x1_scalar"

        super().__init__(
            infile,
            name,
            outfile=outfile,
            rename=True,
            arch=arch,
            target=target,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.absorb_spills = False
        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.visualize_expected_performance = True

        slothy.optimize(start="loop", end="end_loop")

        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial_round_start", end="initial_round_end")


class neon_keccak_x4_hybrid_no_symbolic(OptimizationRunner):
    def __init__(self, var="v84a", arch=AArch64_Neon, target=Target_CortexA55):
        name = f"keccak_f1600_x4_{var}_hybrid_slothy_no_symbolic"
        infile = f"keccak_f1600_x4_{var}_hybrid_slothy_symbolic"
        outfile = (
            f"examples/naive/aarch64/keccak/keccak_f1600_x4_{var}_hybrid_slothy_clean.s"
        )

        super().__init__(
            infile,
            name,
            outfile=outfile,
            rename=f"keccak_f1600_x4_{var}_hybrid_no_symbolic",
            arch=arch,
            target=target,
            outfile_full=True,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.ignore_objective = True
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.constraints.allow_spills = True
        slothy.config.visualize_expected_performance = True

        slothy.optimize(start="loop", end="loop_end")
        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial", end="loop")


class neon_keccak_x4_hybrid_interleave(OptimizationRunner):
    def __init__(self, var="v84a", arch=AArch64_Neon, target=Target_CortexA55):
        name = f"keccak_f1600_x4_{var}_hybrid_slothy_interleave"
        infile = f"keccak_f1600_x4_{var}_hybrid_slothy_clean"
        outfile = (
            "examples/naive/aarch64/keccak/"
            + f"keccak_f1600_x4_{var}_hybrid_slothy_interleaved.s"
        )

        super().__init__(
            infile,
            name,
            outfile=outfile,
            rename=f"keccak_f1600_x4_{var}_hybrid_slothy_interleaved",
            arch=arch,
            target=target,
            outfile_full=True,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags", "hint_STACK_OFFSET_COUNT"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.ignore_objective = True
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.constraints.allow_spills = True
        slothy.config.visualize_expected_performance = True

        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 0
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.split_heuristic_preprocess_naive_interleaving_strategy = (
            "alternate"
        )
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.absorb_spills = False

        slothy.optimize(start="loop", end="loop_end")
        slothy.optimize(start="initial", end="loop")


example_instances = [
    neon_keccak_x1_no_symbolic(),
    neon_keccak_x1_scalar_opt(),
    neon_keccak_x4_hybrid_no_symbolic(var="v84a"),
    neon_keccak_x4_hybrid_interleave(var="v84a"),
    neon_keccak_x4_hybrid_no_symbolic(var="v8a"),
    neon_keccak_x4_hybrid_interleave(var="v8a"),
    neon_keccak_x4_hybrid_no_symbolic(var="v8a_v84a"),
    neon_keccak_x4_hybrid_interleave(var="v8a_v84a"),
]

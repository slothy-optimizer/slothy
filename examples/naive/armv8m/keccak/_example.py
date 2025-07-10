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
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class keccak_mve_4x(OptimizationRunner):
    def __init__(
        self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1, timeout=None
    ):
        name = "mve-keccak-4x"
        infile = name

        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            var=var,
            subfolder=SUBFOLDER,
            funcname="mve_keccak_state_permute_4fold",
        )
        self.var = var
        self.timeout = timeout

    def core(self, slothy):
        # first pass: replace symbolic register names by architectural registers
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.optimize(start="roundstart", end="roundend_pre")

        # second pass: splitting heuristic
        slothy.config.constraints.functional_only = False
        slothy.config.constraints.allow_reordering = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.constraints.stalls_maximum_attempt = 4096
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_factor = 20
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.split_heuristic_optimize_seam = 2

        slothy.optimize(start="roundstart", end="roundend_pre")


example_instances = [
    # Cortex-M85
    keccak_mve_4x(target=Target_CortexM85r1),
    # Cortex-M55
    keccak_mve_4x(),
]

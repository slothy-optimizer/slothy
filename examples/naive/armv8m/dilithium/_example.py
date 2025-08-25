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

from common.OptimizationRunner import OptimizationRunner, target_label_dict
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class ntt_dilithium_12_34_56_78(OptimizationRunner):
    def __init__(self, var="", target=Target_CortexM55r1, arch=Arch_Armv81M):
        infile = "ntt_dilithium_12_34_56_78"
        name = infile

        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )
        self.var = var

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("layer56_loop", postamble_label="layer56_loop_end")
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer78_loop")
        # Optimize seams between loops
        # Make sure we preserve the inputs to the loop body
        slothy.config.outputs = slothy.last_result.kernel_input_output + ["r14"]
        slothy.config.constraints.st_ld_hazard = True
        slothy.config.sw_pipelining.enabled = False
        slothy.optimize(start="layer56_loop_end", end="layer78_loop")


class ntt_dilithium_12(OptimizationRunner):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1, var=""):
        name = "ntt_dilithium_12"
        infile = "ntt_dilithium_12_34_56_78"

        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer12_loop")


class ntt_dilithium_34(OptimizationRunner):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1, var=""):
        name = "ntt_dilithium_34"
        infile = "ntt_dilithium_12_34_56_78"

        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer34_loop")


class ntt_dilithium_56(OptimizationRunner):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1, var=""):
        name = "ntt_dilithium_56"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer56_loop")


class ntt_dilithium_78(OptimizationRunner):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1, var=""):
        name = "ntt_dilithium_78"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer78_loop")


class ntt_dilithium_123_456_78(OptimizationRunner):
    def __init__(
        self,
        cross_loops_optim=False,
        var="",
        arch=Arch_Armv81M,
        target=Target_CortexM55r1,
    ):
        infile = "ntt_dilithium_123_456_78"
        if cross_loops_optim:
            name = "ntt_dilithium_123_456_78_speed"
            suffix = "opt_speed"
        else:
            name = "ntt_dilithium_123_456_78_size"
            suffix = "opt_size"

        super().__init__(
            infile,
            name=name,
            suffix=suffix,
            arch=arch,
            target=target,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )
        self.cross_loops_optim = cross_loops_optim
        self.var = var

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.locked_registers = set(
            [f"QSTACK{i}" for i in [4, 5, 6]]
            + [f"ROOT{i}_STACK" for i in [0, 1, 4]]
            + ["RPTR_STACK"]
        )
        if self.var != "" or (
            "speed" in self.name and self.target == Target_CortexM85r1
        ):
            slothy.config.constraints.st_ld_hazard = (
                False  # optional, if it takes too long
            )
        if not self.cross_loops_optim:
            slothy.config.sw_pipelining.enabled = False
            slothy.optimize_loop("layer123_loop")
            slothy.optimize_loop("layer456_loop")
        else:
            slothy.config.sw_pipelining.enabled = True
            slothy.config.sw_pipelining.halving_heuristic = True
            slothy.config.sw_pipelining.halving_heuristic_periodic = True
            slothy.optimize_loop("layer123_loop", postamble_label="layer123_loop_end")
            slothy.optimize_loop("layer456_loop", postamble_label="layer456_loop_end")

        slothy.config.constraints.st_ld_hazard = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.optimize_loop("layer78_loop")

        if self.cross_loops_optim:
            slothy.config.sw_pipelining.enabled = False
            slothy.config.constraints.st_ld_hazard = True
            slothy.config.outputs = slothy.last_result.kernel_input_output + ["r14"]
            slothy.optimize(start="layer456_loop_end", end="layer78_loop")


class ntt_dilithium_123_456_78_symbolic(OptimizationRunner):
    def __init__(self, var=""):
        super().__init__(
            "ntt_dilithium_123_456_78_symbolic",
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_minimum_attempt = 0
        slothy.config.constraints.stalls_first_attempt = 0
        slothy.config.locked_registers = set(
            [f"QSTACK{i}" for i in [4, 5, 6]] + ["ROOT0_STACK", "RPTR_STACK"]
        )
        slothy.optimize_loop("layer456_loop")


class intt_dilithium_12_34_56_78(OptimizationRunner):
    def __init__(
        self,
        var="",
        target=Target_CortexM55r1,
    ):
        super().__init__(
            "intt_dilithium_12_34_56_78",
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
            target=target,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.optimize_loop("layer78_loop")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    # Dilithium NTT
    # Cortex-M55
    ntt_dilithium_12_34_56_78(),
    ntt_dilithium_12_34_56_78(var="no_trans_vld4"),
    ntt_dilithium_123_456_78(False),
    ntt_dilithium_123_456_78(True),
    # Cortex-M85
    ntt_dilithium_12_34_56_78(target=Target_CortexM85r1),
    ntt_dilithium_12_34_56_78(var="no_trans_vld4", target=Target_CortexM85r1),
    ntt_dilithium_123_456_78(False, target=Target_CortexM85r1),
    ntt_dilithium_123_456_78(True, target=Target_CortexM85r1),
    # Dilithium invNTT
    # Cortex-M55
    intt_dilithium_12_34_56_78(),
    # Cortex-M85
    intt_dilithium_12_34_56_78(target=Target_CortexM85r1),
]

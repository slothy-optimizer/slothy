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


class ntt_kyber_1_23_45_67(OptimizationRunner):
    def __init__(
        self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1, timeout=None
    ):
        name = "ntt_kyber_1_23_45_67"
        infile = name

        super().__init__(
            infile,
            name=name,
            arch=arch,
            target=target,
            rename=True,
            var=var,
            subfolder=SUBFOLDER,
        )
        self.var = var
        self.timeout = timeout

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer1_loop")
        slothy.optimize_loop("layer23_loop")
        slothy.optimize_loop("layer45_loop")
        slothy.config.constraints.st_ld_hazard = False
        if self.timeout is not None:
            slothy.config.timeout = self.timeout
        if "no_trans" in self.var:
            slothy.config.constraints.st_ld_hazard = True
        slothy.optimize_loop("layer67_loop")


class ntt_kyber_1(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_1"
        infile = "ntt_kyber_1_23_45_67"

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
        slothy.optimize_loop("layer1_loop")


class ntt_kyber_23(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_23"
        infile = "ntt_kyber_1_23_45_67"

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
        slothy.optimize_loop("layer23_loop")


class ntt_kyber_45(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_45"
        infile = "ntt_kyber_1_23_45_67"

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
        slothy.optimize_loop("layer45_loop")


class ntt_kyber_67(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_67"
        infile = "ntt_kyber_1_23_45_67"

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
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer67_loop")


class ntt_kyber_12_345_67(OptimizationRunner):
    def __init__(
        self,
        cross_loops_optim=False,
        var="",
        arch=Arch_Armv81M,
        target=Target_CortexM55r1,
    ):
        infile = "ntt_kyber_12_345_67"
        if cross_loops_optim:
            name = "ntt_kyber_12_345_67_speed"
            suffix = "opt_speed"
        else:
            name = "ntt_kyber_12_345_67_size"
            suffix = "opt_size"

        self.var = var
        super().__init__(
            infile,
            name=name,
            suffix=suffix,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
            arch=arch,
            target=target,
        )
        self.cross_loops_optim = cross_loops_optim

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("layer12_loop", postamble_label="layer12_loop_end")
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.locked_registers = set(
            [f"QSTACK{i}" for i in [4, 5, 6]] + ["STACK0"]
        )
        if not self.cross_loops_optim:
            if "no_trans" not in self.var and "trans" in self.var:
                slothy.config.constraints.st_ld_hazard = (
                    False  # optional, if it takes too long
                )
            slothy.config.sw_pipelining.enabled = False
            slothy.optimize_loop("layer345_loop")
        else:
            if "no_trans" not in self.var and "trans" in self.var:
                slothy.config.constraints.st_ld_hazard = (
                    False  # optional, if it takes too long
                )
            slothy.config.sw_pipelining.enabled = True
            slothy.config.sw_pipelining.halving_heuristic = True
            slothy.config.sw_pipelining.halving_heuristic_periodic = True
            slothy.optimize_loop("layer345_loop", postamble_label="layer345_loop_end")
            layer345_deps = slothy.last_result.kernel_input_output.copy()

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.sw_pipelining.halving_heuristic_periodic = True
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer67_loop")
        layer67_deps = slothy.last_result.kernel_input_output.copy()

        if self.cross_loops_optim:
            slothy.config.inputs_are_outputs = False
            slothy.config.constraints.st_ld_hazard = True
            slothy.config.sw_pipelining.enabled = False
            slothy.config.outputs = layer345_deps + ["r14"]
            slothy.optimize(start="layer12_loop_end", end="layer345_loop")
            slothy.config.outputs = layer67_deps + ["r14"]
            slothy.optimize(start="layer345_loop_end", end="layer67_loop")


class ntt_kyber_12(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_12"
        infile = "ntt_kyber_12_345_67"
        name += f"_{target_label_dict[target]}"
        super().__init__(
            infile,
            name=name,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
            arch=arch,
            target=target,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("layer12_loop", postamble_label="layer12_loop_end")


class ntt_kyber_345(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_345"
        infile = "ntt_kyber_12_345_67"
        name += f"_{target_label_dict[target]}"
        super().__init__(
            infile,
            name=name,
            rename=True,
            subfolder=SUBFOLDER,
            var=var,
            arch=arch,
            target=target,
        )

    def core(self, slothy):
        slothy.config.locked_registers = set(
            [f"QSTACK{i}" for i in [4, 5, 6]] + ["STACK0"]
        )
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("layer345_loop")


class ntt_kyber_l345_symbolic(OptimizationRunner):
    def __init__(self):
        super().__init__("ntt_kyber_layer345_symbolic")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.sw_pipelining.halving_heuristic_periodic = True
        slothy.optimize_loop("layer345_loop")


class intt_kyber_1_23_45_67(OptimizationRunner):
    def __init__(self, var=""):
        super().__init__(
            "intt_kyber_1_23_45_67", rename=True, subfolder=SUBFOLDER, var=var
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("layer1_loop")
        slothy.optimize_loop("layer23_loop")
        slothy.optimize_loop("layer45_loop")
        slothy.optimize_loop("layer67_loop")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    ntt_kyber_1_23_45_67(),
    ntt_kyber_1_23_45_67(var="no_trans"),
    ntt_kyber_1_23_45_67(var="no_trans_vld4", timeout=600),
    ntt_kyber_12_345_67(False),
    ntt_kyber_12_345_67(True),
    # Cortex-M85
    ntt_kyber_1_23_45_67(target=Target_CortexM85r1),
    ntt_kyber_1_23_45_67(var="no_trans", target=Target_CortexM85r1),
    ntt_kyber_1_23_45_67(var="no_trans_vld4", target=Target_CortexM85r1, timeout=600),
    ntt_kyber_12_345_67(False, target=Target_CortexM85r1),
    ntt_kyber_12_345_67(True, target=Target_CortexM85r1),
    # Kyber InvNTT
    # Cortex-M55
    intt_kyber_1_23_45_67(),
]

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
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class ntt_dilithium_123_45678(OptimizationRunner):
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None
    ):
        name = "ntt_dilithium_123_45678"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + [
            "v8",
            "x30",
            "sp",
        ]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 110
        slothy.optimize_loop("layer123_start")

        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 40
        slothy.optimize_loop("layer45678_start")


class intt_dilithium_123_45678(OptimizationRunner):
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None
    ):
        name = "intt_dilithium_123_45678"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.inputs_are_outputs = True

        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + [
            "v8",
            "x30",
            "sp",
        ]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 40
        slothy.optimize_loop("layer45678_start")

        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + [
            "v8",
            "x30",
            "sp",
        ]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 110
        slothy.optimize_loop("layer123_start")


class ntt_dilithium_123(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_dilithium_123"
        infile = "ntt_dilithium_123_45678"

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, subfolder=SUBFOLDER
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + [
            "v8",
            "x30",
            "sp",
        ]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer123_start")


class ntt_dilithium_45678(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_dilithium_45678"
        infile = "ntt_dilithium_123_45678"

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, subfolder=SUBFOLDER
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 160
        slothy.config.constraints.stalls_minimum_attempt = 160
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer45678_start")


class ntt_dilithium_1234_5678(OptimizationRunner):
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None
    ):
        name = "ntt_dilithium_1234_5678"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        conf = slothy.config.copy()

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2
        slothy.config.split_heuristic_repeat = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.constraints.stalls_first_attempt = 14
        slothy.optimize_loop("layer1234_start")

        slothy.config = conf.copy()

        if self.timeout is not None:
            slothy.config.timeout = self.timeout * 12

        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.split_heuristic = False
        slothy.optimize_loop("layer5678_start")


class intt_dilithium_1234_5678(OptimizationRunner):
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None
    ):
        name = "intt_dilithium_1234_5678"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
        )

    def core(self, slothy):
        conf = slothy.config.copy()

        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.split_heuristic = False
        slothy.optimize_loop("layer5678_start")

        slothy.config = conf.copy()

        if self.timeout is not None:
            slothy.config.timeout = self.timeout // 12

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2
        slothy.config.split_heuristic_repeat = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.constraints.stalls_first_attempt = 14
        slothy.optimize_loop("layer1234_start")


class ntt_dilithium_1234(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "ntt_dilithium_1234"
        infile = "ntt_dilithium_1234_5678"

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, subfolder=SUBFOLDER
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer1234_start")


class ntt_dilithium_5678(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "ntt_dilithium_5678"
        infile = "ntt_dilithium_1234_5678"

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, subfolder=SUBFOLDER
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer5678_start")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    # Cortex-A55
    ntt_dilithium_45678(),
    ntt_dilithium_123_45678(),
    ntt_dilithium_123_45678(var="w_scalar"),
    ntt_dilithium_123_45678(var="manual_st4"),
    ntt_dilithium_1234_5678(),
    ntt_dilithium_1234_5678(var="manual_st4"),
    intt_dilithium_123_45678(),
    intt_dilithium_123_45678(var="manual_ld4"),
    intt_dilithium_1234_5678(),
    intt_dilithium_1234_5678(var="manual_ld4"),
    # Cortex-A72
    ntt_dilithium_123_45678(target=Target_CortexA72),
    ntt_dilithium_123_45678(var="w_scalar", target=Target_CortexA72),
    ntt_dilithium_123_45678(var="manual_st4", target=Target_CortexA72),
    ntt_dilithium_1234_5678(target=Target_CortexA72),
    ntt_dilithium_1234_5678(var="manual_st4", target=Target_CortexA72),
    intt_dilithium_123_45678(target=Target_CortexA72),
    intt_dilithium_123_45678(var="manual_ld4", target=Target_CortexA72),
    intt_dilithium_1234_5678(target=Target_CortexA72),
    intt_dilithium_1234_5678(var="manual_ld4", target=Target_CortexA72),
    # Apple M1 Firestorm
    ntt_dilithium_123_45678(target=Target_AppleM1_firestorm, timeout=3600),
    ntt_dilithium_123_45678(
        var="w_scalar", target=Target_AppleM1_firestorm, timeout=3600
    ),
    ntt_dilithium_123_45678(
        var="manual_st4", target=Target_AppleM1_firestorm, timeout=3600
    ),
    ntt_dilithium_1234_5678(target=Target_AppleM1_firestorm, timeout=300),
    ntt_dilithium_1234_5678(
        var="manual_st4", target=Target_AppleM1_firestorm, timeout=300
    ),
    intt_dilithium_123_45678(target=Target_AppleM1_firestorm, timeout=3600),
    intt_dilithium_123_45678(
        var="manual_ld4", target=Target_AppleM1_firestorm, timeout=3600
    ),
    intt_dilithium_1234_5678(target=Target_AppleM1_firestorm, timeout=3600),
    intt_dilithium_1234_5678(
        var="manual_ld4", target=Target_AppleM1_firestorm, timeout=3600
    ),
    # Apple M1 Icestorm
    ntt_dilithium_123_45678(target=Target_AppleM1_icestorm, timeout=3600),
    ntt_dilithium_123_45678(
        var="w_scalar", target=Target_AppleM1_icestorm, timeout=3600
    ),
    ntt_dilithium_123_45678(
        var="manual_st4", target=Target_AppleM1_icestorm, timeout=3600
    ),
    ntt_dilithium_1234_5678(target=Target_AppleM1_icestorm, timeout=300),
    ntt_dilithium_1234_5678(
        var="manual_st4", target=Target_AppleM1_icestorm, timeout=300
    ),
    intt_dilithium_123_45678(target=Target_AppleM1_icestorm, timeout=3600),
    intt_dilithium_123_45678(
        var="manual_ld4", target=Target_AppleM1_icestorm, timeout=3600
    ),
    intt_dilithium_1234_5678(target=Target_AppleM1_icestorm, timeout=3600),
    intt_dilithium_1234_5678(
        var="manual_ld4", target=Target_AppleM1_icestorm, timeout=3600
    ),
]

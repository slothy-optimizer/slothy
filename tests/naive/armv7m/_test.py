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

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7


class Armv7mExample0(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "armv7m_simple0"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize(start="start", end="end")


class Armv7mExample0Func(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "armv7m_simple0_func"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize(start="start", end="end")
        slothy.global_selftest("my_func", {"r0": 1024})


class Armv7mLoopSubs(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_subs"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.SubsLoop)
        slothy.config.sw_pipelining.enabled = True
        slothy.config.outputs = ["r0", "r1", "r2", "r5", "flags"]
        slothy.optimize_loop("start2", forced_loop_type=Arch_Armv7M.BranchLoop)


class Armv7mLoopCmp(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_cmp"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["r6"]
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.CmpLoop)


class Armv7mLoopVmovCmp(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_vmov_cmp"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["r6"]
        slothy.optimize_loop("start")


class Armv7mLoopVmovCmpForced(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_vmov_cmp_forced"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["r5", "r6"]
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.CmpLoop)


class Armv7mLoopLabels(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "armv7m_loop_labels"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["r0", "r1", "r5"]
        slothy.optimize_loop(".loop", forced_loop_type=Arch_Armv7M.SubsLoop)
        slothy.optimize_loop("loop", forced_loop_type=Arch_Armv7M.SubsLoop)
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.SubsLoop)


test_instances = [
    Armv7mLoopSubs(),
    Armv7mLoopCmp(),
    Armv7mLoopVmovCmp(),
    Armv7mLoopVmovCmpForced(),
    Armv7mExample0(),
    Armv7mExample0Func(),
    Armv7mLoopLabels(),
]

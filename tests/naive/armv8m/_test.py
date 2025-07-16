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
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1


class Instructions(OptimizationRunner):
    def __init__(self):
        super().__init__("instructions", base_dir="tests")

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.optimize(start="start", end="end")


class Example0(OptimizationRunner):
    def __init__(self):
        super().__init__("simple0", base_dir="tests")

    def core(self, slothy):
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.inputs_are_outputs = True
        slothy.optimize()


class Example1(OptimizationRunner):
    def __init__(self):
        super().__init__("simple1", base_dir="tests")


class Example2(OptimizationRunner):
    def __init__(self):
        super().__init__("simple0_loop", base_dir="tests")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")


class Example3(OptimizationRunner):
    def __init__(self):
        super().__init__("simple1_loop", base_dir="tests")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")


class LoopLe(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "loop_le"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.optimize_loop("start")


class HintTest(OptimizationRunner):
    def __init__(self):
        super().__init__(
            "hint_test", arch=Arch_Armv81M, target=Target_CortexM55r1, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.optimize()


test_instances = [
    Instructions(),
    Example0(),
    Example1(),
    Example2(),
    Example3(),
    LoopLe(),
    HintTest(),
]

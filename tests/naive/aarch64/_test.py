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
import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.neoverse_n1_experimental as Target_NeoverseN1
import slothy.targets.aarch64.aarch64_big_experimental as Target_AArch64Big


class Instructions(OptimizationRunner):
    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55):
        super().__init__("instructions", base_dir="tests", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.optimize(start="start", end="end")


class AArch64LoopSub(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_sub"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.optimize_loop("start")

        slothy.optimize_loop("start2")
        slothy.config.inputs_are_outputs = True

        slothy.optimize_loop("start3")


class AArch64LoopSubs(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_subs"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")

        slothy.optimize_loop("start2")

        slothy.optimize_loop("start3")

        slothy.optimize_loop("start4")


class AArch64LoopSubTabs(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_sub_tabs"
        infile = name
        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.optimize_loop("start")


class AArch64Example0(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize()


class AArch64Example0Equ(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_equ"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize(start="start", end="end")


class AArch64Example1(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_macros"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize(start="start", end="end")


class AArch64Example2(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_loop"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("start")


class AArch64ExampleLdSt(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_ldst"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.optimize()


class AArch64Split0(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_split0"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.fusion_region("start", "end", ssa=False)


class AArch64Aese(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_AArch64Big):
        name = "aarch64_aese"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize()


class AArch64IfElse(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_ifelse"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.optimize()


class AArch64Ubfx(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "aarch64_ubfx"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize()


class AArch64UnknownIter(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_unknown_iter"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.unroll = 3
        slothy.config.sw_pipelining.unknown_iteration_count = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")


class AArch64UnknownIterPow2(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_unknown_iter_pow2"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.unroll = 4
        slothy.config.sw_pipelining.unknown_iteration_count = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")


test_instances = [
    Instructions(),
    Instructions(target=Target_CortexA72),
    Instructions(target=Target_NeoverseN1),
    AArch64Example0(),
    AArch64Example0(target=Target_CortexA72),
    AArch64Example0Equ(),
    AArch64Example1(),
    AArch64Example1(target=Target_CortexA72),
    AArch64Example2(),
    AArch64Example2(target=Target_CortexA72),
    AArch64ExampleLdSt(),
    AArch64IfElse(),
    AArch64Split0(),
    AArch64Aese(),
    AArch64LoopSub(),
    AArch64LoopSubs(),
    AArch64LoopSubTabs(),
    AArch64Ubfx(),
    AArch64UnknownIter(),
    AArch64UnknownIterPow2(),
]

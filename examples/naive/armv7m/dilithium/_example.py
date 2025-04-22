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
import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"
print(f"SUBFOLDER = {SUBFOLDER}")


class ntt_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ntt_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_ntt"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.constraints.stalls_first_attempt = 16

        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.sw_pipelining.allow_pre = True

        slothy.config.outputs = ["r0"]
        # slothy.optimize_loop("layer123_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r0", "s0", "s10", "s9"]
        # slothy.optimize_loop("layer456_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r0", "r4"]  # r4 is cntr
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer78_loop", forced_loop_type=Arch_Armv7M.BranchLoop)


class intt_dilithium_123_456_78(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_dilithium_123_456_78"
        infile = name
        funcname = "pqcrystals_dilithium_invntt_tomont"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.constraints.stalls_first_attempt = 16

        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = True
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.sw_pipelining.allow_pre = True

        slothy.optimize_loop("layer123_loop", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.optimize_loop("layer456_first_loop")
        slothy.optimize_loop("layer456_loop")

        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer78_loop", forced_loop_type=Arch_Armv7M.BranchLoop)


class pointwise_montgomery_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_montgomery_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_pointwise_montgomery"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("1")


class pointwise_acc_montgomery_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_acc_montgomery_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_pointwise_acc_montgomery"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("1")


class fnt_257_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "fnt_257_dilithium"
        infile = name
        funcname = "__asm_fnt_257"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.visualize_expected_performance = False
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.variable_size = True

        func_args = {"r1", "r2", "r3"}
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(30))  # reserve FPR
        r = r.union(func_args)
        slothy.config.reserved_regs = r

        slothy.config.constraints.stalls_first_attempt = 8
        slothy.config.sw_pipelining.enabled = True
        slothy.config.timeout = 600
        slothy.optimize_loop("_fnt_0_1_2")

        slothy.config.sw_pipelining.enabled = False
        slothy.config.timeout = 300

        slothy.config.constraints.stalls_first_attempt = 8
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.timeout = 180  # Not more than 2min per step
        # TODO: run with more repeats
        slothy.config.split_heuristic_repeat = 2
        slothy.config.outputs = ["s25", "s27", "r12"]
        slothy.fusion_loop("_fnt_3_4_5_6", ssa=False)
        slothy.optimize_loop("_fnt_3_4_5_6")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("_fnt_3_4_5_6")

        # Due dependencies in the memory between loads and stores, skip this for now
        # slothy.optimize_loop("_fnt_to_16_bit")


class ifnt_257_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ifnt_257_dilithium"
        infile = name
        funcname = "__asm_ifnt_257"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.timeout = 300

        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.outputs = ["r14", "s1", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.config.objective_precision = 0.07
        # TODO: run with more repeats
        slothy.config.split_heuristic_repeat = 1
        slothy.fusion_loop("_ifnt_7_6_5_4", ssa=False)
        slothy.optimize_loop("_ifnt_7_6_5_4")

        slothy.config.outputs = ["r14", "r1", "s1"]
        slothy.config.inputs_are_outputs = True
        slothy.config.split_heuristic = False
        slothy.optimize_loop("_ifnt_0_1_2")


class basemul_257_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_257_dilithium"
        infile = name
        funcname = "__asm_point_mul_257_16"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):

        slothy.config.outputs = ["r12", "r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("_point_mul_16_loop")


class basemul_257_asymmetric_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_257_asymmetric_dilithium"
        infile = name
        funcname = "__asm_asymmetric_mul_257_16"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("_asymmetric_mul_16_loop")


class ntt_769_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ntt_769_dilithium"
        infile = name
        outfile = name
        funcname = "small_ntt_asm_769"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            outfile=outfile,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.outputs = ["r14"]
        slothy.config.constraints.stalls_first_attempt = 32

        r = slothy.config.reserved_regs
        r.add("r1")
        r = r.union(f"s{i}" for i in range(31))  # reserve FPR
        slothy.config.reserved_regs = r

        # TODO
        # - Experiment with lower split factors
        # - Try to get stable performance: It currently varies a lot with each run

        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.variable_size = True
        slothy.config.split_heuristic = True
        slothy.config.timeout = 360  # Not more than 2min per step
        slothy.config.visualize_expected_performance = False
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.optimize_loop("layer1234_loop", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer1234_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r14"]

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer567_loop", ssa=False)
        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.outputs = ["r14"]

        slothy.config.timeout = 360
        slothy.config.variable_size = True
        slothy.config.split_heuristic_optimize_seam = 0
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_factor = 2.25
        slothy.config.split_heuristic_stepsize = 0.25
        slothy.optimize_loop("layer567_loop")

        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer567_loop")


class intt_769_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_769_dilithium"
        infile = name
        funcname = "small_invntt_asm_769"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.timeout = 180

        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.split_heuristic = True
        slothy.config.reserved_regs = ["r1", "r13"] + [f"s{i}" for i in range(23, 32)]

        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.split_heuristic_repeat = 1

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer1234_loop", ssa=False)
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("layer1234_loop")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer1234_loop")

        slothy.config.split_heuristic_factor = 4

        # Optimize first iteration that has been separated from the loop
        # TODO: Do we further need to limit renaming because of the following
        # loop using registers set in this region?

        slothy.config.outputs = ["s0", "s2"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_region(
            start="layer567_first_start", end="layer567_first_end", ssa=False
        )
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize(start="layer567_first_start", end="layer567_first_end")

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer567_loop", ssa=False)
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("layer567_loop")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer567_loop")


class pointwise_769_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_769_dilithium"
        infile = name
        funcname = "small_pointmul_asm_769"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r3")
        slothy.config.reserved_regs = r
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("_point_mul_16_loop")


class pointwise_769_asymmetric_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_769_asymmetric_dilithium"
        infile = name
        funcname = "small_asymmetric_mul_asm_769"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("_asymmetric_mul_16_loop")


class reduce32_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "reduce32_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_reduce32"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("1")


class caddq_dilithium(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "caddq_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_caddq"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            var=var,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname=funcname,
        )

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("1")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    ntt_dilithium(),
    intt_dilithium_123_456_78(),
    pointwise_montgomery_dilithium(),
    pointwise_acc_montgomery_dilithium(),
    fnt_257_dilithium(),
    ifnt_257_dilithium(),
    basemul_257_dilithium(),
    basemul_257_asymmetric_dilithium(),
    ntt_769_dilithium(),
    intt_769_dilithium(),
    pointwise_769_dilithium(),
    pointwise_769_asymmetric_dilithium(),
    reduce32_dilithium(),
    caddq_dilithium(),
]

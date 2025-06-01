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


class ntt_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ntt_kyber"
        infile = name
        funcname = "ntt_fast"

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
        slothy.config.outputs = ["r14", "s23"]

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(30))  # reserve FPR
        r.add("r1")
        slothy.config.reserved_regs = r

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = True

        # TODO
        # - Experiment with lower split factors
        # - Try to get stable performance: It currently varies a lot with each run
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.split_heuristic = True
        slothy.config.timeout = 360  # Not more than 6min per step
        slothy.config.visualize_expected_performance = False
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r14"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("2", ssa=False, forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.timeout = 360
        slothy.config.split_heuristic_optimize_seam = 0
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_factor = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)


class intt_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_kyber"
        infile = name
        funcname = "invntt_fast"

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
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs = ["r1", "r13"] + [f"s{i}" for i in range(23, 32)]
        slothy.config.timeout = 300

        # Step 1: optimize first loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 4
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.config.split_heuristic_repeat = 1
        slothy.config.outputs = ["r14", "s8"]
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

        # Step 2: optimize the start of the second loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2.5
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.outputs = ["r14", "r0", "r10", "s0", "s2"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_region(
            start="layer567_first_start", end="layer567_first_end", ssa=False
        )
        slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize(start="layer567_first_start", end="layer567_first_end")

        # Step 3: optimize the start of the second loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 3
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.outputs = ["r14", "s14"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("2", ssa=False, forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)


class basemul_16_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_16_32_kyber"
        infile = name
        funcname = "basemul_asm_opt_16_32"

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
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")


class basemul_acc_32_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_32_32_kyber"
        infile = name
        funcname = "basemul_asm_acc_opt_32_32"

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
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)


class basemul_acc_32_16_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_32_16_kyber"
        infile = name
        funcname = "basemul_asm_acc_opt_32_16"

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
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")


class frombytes_mul_16_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_16_32_kyber"
        infile = name
        funcname = "frombytes_mul_asm_16_32"

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
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")


class frombytes_mul_acc_32_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_32_32_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc_32_32"

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
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")


class frombytes_mul_acc_32_16_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_32_16_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc_32_16"

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

        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)


class add_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "add_kyber"
        infile = name
        funcname = "pointwise_add"

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
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")
        slothy.config.sw_pipelining.enabled = False
        slothy.fusion_region(
            start="pointwise_add_final_start", end="pointwise_add_final_end", ssa=False
        )
        slothy.optimize(
            start="pointwise_add_final_start", end="pointwise_add_final_end"
        )


class sub_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "sub_kyber"
        infile = name
        funcname = "pointwise_sub"

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
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")

        slothy.config.sw_pipelining.enabled = False
        slothy.fusion_region(
            start="pointwise_sub_final_start", end="pointwise_sub_final_end", ssa=False
        )
        slothy.optimize(
            start="pointwise_sub_final_start", end="pointwise_sub_final_end"
        )


class barrett_reduce_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "barrett_reduce_kyber"
        infile = name
        funcname = "asm_barrett_reduce"

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
        slothy.config.outputs = ["r9"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 43
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")


class fromplant_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "fromplant_kyber"
        infile = name
        funcname = "asm_fromplant"

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
        slothy.config.outputs = ["r9"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")


class basemul_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_kyber"
        infile = name
        funcname = "basemul_asm"

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
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.constraints.stalls_first_attempt = 16
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(31))  # reserve FPR
        slothy.config.reserved_regs = r

        slothy.fusion_loop("1", ssa=False)
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.SubsLoop)


class basemul_acc_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_kyber"
        infile = name
        funcname = "basemul_asm_acc"

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
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.constraints.stalls_first_attempt = 16

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(31))  # reserve FPR
        slothy.config.reserved_regs = r

        slothy.fusion_loop("1", ssa=False)
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.SubsLoop)


class frombytes_mul_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_kyber"
        infile = name
        funcname = "frombytes_mul_asm"

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
        r.add("r14")
        r = r.union(f"s{i}" for i in range(31))  # reserve FPR
        slothy.config.reserved_regs = r
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")


class frombytes_mul_acc_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc"

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
        slothy.config.unsafe_address_offset_fixup = False
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(32))  # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)


class matacc_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_kyber"
        infile = name
        funcname = "matacc_asm"

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
        r = r.union(f"s{i}" for i in range(32))  # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_acc_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_acc_kyber"
        infile = name
        funcname = "matacc_asm_acc"

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
        r = r.union(f"s{i}" for i in range(32))  # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_opt_16_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_16_32_kyber"
        infile = name
        funcname = "matacc_asm_opt_16_32"

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
        slothy.config.unsafe_address_offset_fixup = False

        # TODO: r10, r11, r12 shouldn't actually be needed as q,qa,qinv are
        # unused in this code.
        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_opt_32_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_32_32_kyber"
        infile = name
        funcname = "matacc_asm_opt_32_32"

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
        slothy.config.unsafe_address_offset_fixup = False

        # TODO: r10, r11, r12 shouldn't actually be needed as q,qa,qinv are
        # unused in this code.
        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_opt_32_16_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_32_16_kyber"
        infile = name
        funcname = "matacc_asm_opt_32_16"

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
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_cache_16_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_16_32_kyber"
        infile = name
        funcname = "matacc_asm_cache_16_32"

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
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_cache_32_32_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_32_32_kyber"
        infile = name
        funcname = "matacc_asm_cache_32_32"

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
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_cache_32_16_kyber(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_32_16_kyber"
        infile = name
        funcname = "matacc_asm_cache_32_16"

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
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = (
            [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]
        )

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    ntt_kyber(),
    intt_kyber(),
    basemul_16_32_kyber(),
    basemul_acc_32_32_kyber(),
    basemul_acc_32_16_kyber(),
    frombytes_mul_16_32_kyber(),
    frombytes_mul_acc_32_32_kyber(),
    frombytes_mul_acc_32_16_kyber(),
    add_kyber(),
    sub_kyber(),
    barrett_reduce_kyber(),
    fromplant_kyber(),
    basemul_kyber(),
    basemul_acc_kyber(),
    frombytes_mul_kyber(),
    frombytes_mul_acc_kyber(),
    matacc_kyber(),
    matacc_acc_kyber(),
    matacc_asm_opt_16_32_kyber(),
    matacc_asm_opt_32_32_kyber(),
    matacc_asm_opt_32_16_kyber(),
    matacc_asm_cache_16_32_kyber(),
    matacc_asm_cache_32_32_kyber(),
    matacc_asm_cache_32_16_kyber(),
]

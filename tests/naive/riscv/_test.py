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
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908


class Instructions(OptimizationRunner):
    def __init__(self, arch=RISC_V, target=Target_XuanTieC908):
        super().__init__("instructions", base_dir="tests", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.optimize(start="start", end="end")


class RISC_VSimple0(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908):
        name = "riscv_simple0"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = [
            "v0",
            "v1",
            "v2",
            "v3",
            "v4",
            "v5",
            "v6",
            "v7",
            "v8",
            "v9",
            "v10",
            "v11",
            "x1",
            "x2",
            "x3",
        ]
        slothy.optimize(start="start", end="end")


class RISC_VSimpleLoop0(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908):
        name = "riscv_simple_loop0"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("my_loop")
        slothy.optimize_loop("my_loop2")
        slothy.optimize_loop("my_loop3")


class RISC_VTest(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "riscv_test"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            funcname="test",
            timeout=timeout,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = [
            "x1",
            "x2",
            "x3",
            "x4",
            "x5",
            "x6",
            "x7",
            "x8",
            "x9",
            "x10",
            "x11",
            "x12",
            "x13",
            "x14",
            "x15",
            "x16",
            "x17",
            "x18",
            "x19",
            "x20",
            "x21",
            "x22",
            "x23",
            "x24",
            "x25",
            "x26",
            "x27",
            "x28",
            "x29",
            "x30",
            "x31",
        ]
        slothy.optimize(start="start_label", end="end_label")


test_instances = [
    Instructions(),
    RISC_VSimple0(),
    RISC_VSimpleLoop0(),
    RISC_VTest(),
]

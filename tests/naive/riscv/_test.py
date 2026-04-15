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

        # Set LMUL in target module
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = 8
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
    def __init__(
        self, var="", arch=RISC_V, target=Target_XuanTieC908, lmul=1, timeout=None
    ):
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
        self.lmul = lmul

    def core(self, slothy):
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = self.lmul
        print(target_module.lmul)
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        # slothy.config.outputs = [
        #    "v8"
        # ]
        outputs = [f"v{i}" for i in range(32)]
        outputs.extend([f"x{i}" for i in range(1, 32)])
        slothy.config.outputs = outputs
        slothy.optimize(start="start_label", end="end_label")


class RISC_V_lmul_test(OptimizationRunner):
    def __init__(
        self, var="", arch=RISC_V, target=Target_XuanTieC908, lmul=2, timeout=None
    ):
        name = "riscv_lmul_test"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            base_dir="tests",
        )
        self.lmul = lmul

    def core(self, slothy):
        # Set LMUL in target module
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = self.lmul

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        # For LMUL > 1, we need to ensure expanded registers are in outputs
        if self.lmul > 1:
            outputs = []
            # Add all vector registers that might be implicitly used
            for i in range(32):
                outputs.append(f"v{i}")
        else:  # TODO: This else clause makes no sense?
            outputs = [f"v{i}" for i in range(32)]

        slothy.config.outputs = outputs

        print(f"Testing with LMUL={self.lmul}")
        slothy.optimize(start="start", end="end")


class RISC_V_lmul_comprehensive_test(OptimizationRunner):
    def __init__(
        self, var="", arch=RISC_V, target=Target_XuanTieC908, lmul=2, timeout=None
    ):
        name = "riscv_lmul_comprehensive"
        infile = name  # Uses comprehensive assembly with all instruction types

        if var != "":
            name += f"_{var}"
            # infile stays the same - we use the same assembly for different LMUL values

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            base_dir="tests",
        )
        self.lmul = lmul

    def core(self, slothy):
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = self.lmul

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        # Include all vector and scalar registers in outputs
        outputs = [f"v{i}" for i in range(32)]
        outputs.extend([f"x{i}" for i in range(1, 32)])
        slothy.config.outputs = outputs

        print(
            (
                "Testing comprehensive LMUL ops (vector-vector, vector-scalar,"
                "vector-immediate, scalar-vector, move, masked)"
                f"with LMUL={self.lmul}"
            )
        )
        slothy.optimize(start="start", end="end")


class RISC_V_nf_load_store_whole_reg_test(OptimizationRunner):
    def __init__(
        self, var="", arch=RISC_V, target=Target_XuanTieC908, lmul=1, timeout=None
    ):
        name = "riscv_nf_load_store_whole_reg"
        infile = name  # Uses assembly with various NF values (1, 2, 4, 8)

        if var != "":
            name += f"_{var}"

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            base_dir="tests",
        )
        self.lmul = lmul

    def core(self, slothy):
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = self.lmul

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        # Include all vector and scalar registers in outputs
        outputs = [f"v{i}" for i in range(32)]
        outputs.extend([f"x{i}" for i in range(1, 32)])
        slothy.config.outputs = outputs

        print("Testing load/store whole register ops with various NF values (1,2,4,8)")
        slothy.optimize(start="start", end="end")


test_instances = [
    Instructions(),
    RISC_VSimple0(),
    RISC_VSimpleLoop0(),
    RISC_VTest(lmul=8),
    RISC_V_lmul_test(target=Target_XuanTieC908, lmul=2),
    RISC_V_lmul_test(var="lmul4", target=Target_XuanTieC908, lmul=4),
    RISC_V_lmul_test(var="lmul8", target=Target_XuanTieC908, lmul=8),
    # Comprehensive LMUL tests (all instruction types in one file)
    RISC_V_lmul_comprehensive_test(target=Target_XuanTieC908, lmul=2),
    RISC_V_lmul_comprehensive_test(var="lmul4", target=Target_XuanTieC908, lmul=4),
    # NF tests for load/store whole register instructions (tests NF=1,2,4,8 in one file)
    RISC_V_nf_load_store_whole_reg_test(target=Target_XuanTieC908, lmul=1),
]

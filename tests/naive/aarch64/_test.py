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

import re

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

        slothy.optimize_loop("start5")

        slothy.optimize_loop("start6")


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


class AArch64Equ(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_equ"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
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
        ]
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


class AArch64ExampleImpossible(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_impossible"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.constraints.stalls_maximum_attempt = 4
        # slothy.config.variable_size = True

        try:
            slothy.optimize()
        except Exception as exc:
            if "No solution found" not in str(exc):
                raise Exception("Test failed for wrong reason.")


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
        slothy.optimize("start", "end")
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("loop_start")


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


class AArch64LoopLabels(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_labels"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.optimize_loop(".loop")
        slothy.optimize_loop("loop")
        slothy.optimize_loop("1")


class AArch64LoopBranch(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_branch"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["flags"]
        slothy.optimize_loop("loop")
        slothy.config.outputs = ["flags", "x1"]
        slothy.optimize_loop("loop2")


class AArch64FusionVeor(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "aarch64_fusion_veor"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.outputs = ["v10"]
        slothy.fusion_region(start="start", end="end", ssa=False)


class AArch64CStyleComments(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_cstyle_comments"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.optimize(start="start", end="end")


class AArch64SelftestAddr(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_selftest_addr"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 64
        # Mark all vector and GPR outputs from loads
        slothy.config.outputs = [
            "v0",
            "v1",
            "v2",
            "v3",
            "v4",
            "v8",
            "v9",
            "v24",
            "v25",
            "v26",
            "v27",
            "v28",
            "v29",  # vector loads
            "x1",
            "x21",
            "x22",
            "x23",
            "x24",
            "x25",
            "x26",
            "x27",
            "x28",  # GPR loads
        ]
        slothy.optimize(start="start", end="end")


class AArch64SelftestInitialRegs(OptimizationRunner):
    """Tests selftest_initial_register_values.

    The loop uses x2 as a stride that is added to the address registers x0/x1.
    The selftest auto-detects x0/x1 as addresses but not x2, so without
    pinning x2 to a small known value the derived addresses would quickly
    leave the mapped RAM region.
    """

    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_selftest_initial_regs"
        super().__init__(
            name, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        # x0/x1 are address registers; x2 is a stride offset (not an address).
        # Pin x2 to 8 so add x0,x0,x2 stays within the mapped RAM window.
        slothy.config.selftest_initial_register_values = {"x2": 8}
        slothy.optimize_loop("start")


class AArch64Directives(OptimizationRunner):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_directives"
        infile = name

        super().__init__(
            infile, name, rename=True, arch=arch, target=target, base_dir="tests"
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 32

        # Basic tests
        slothy.optimize(start="start_rept", end="end_rept")  # 5 instructions
        slothy.optimize(start="start_irp", end="end_irp")  # 3 instructions

        # Macro/directive interaction
        slothy.optimize(
            start="start_irp_in_macro", end="end_irp_in_macro"
        )  # 2 instructions
        slothy.optimize(
            start="start_macro_in_irp", end="end_macro_in_irp"
        )  # 3 instructions

        # .rept with \+ counter
        slothy.optimize(
            start="start_rept_counter", end="end_rept_counter"
        )  # 3 instructions

        # Nested directives
        slothy.optimize(
            start="start_nested_rept", end="end_nested_rept"
        )  # 4 instructions
        slothy.optimize(
            start="start_rept_in_irp", end="end_rept_in_irp"
        )  # 4 instructions
        slothy.optimize(
            start="start_irp_in_rept", end="end_irp_in_rept"
        )  # 4 instructions

        # Combined .rept counter and macro
        slothy.optimize(
            start="start_rept_macro_counter", end="end_rept_macro_counter"
        )  # 3 instructions

        # Edge cases
        slothy.optimize(
            start="start_rept_zero", end="end_rept_zero"
        )  # 2 instructions (no .rept output)
        slothy.optimize(start="start_irp_single", end="end_irp_single")  # 1 instruction


class AArch64PreferCallerSave(OptimizationRunner):
    """Verify that prefer_caller_save_registers=True does not introduce
    callee-saved NEON registers (v8-v15) when the input uses only caller-save
    registers (v0-v7).  The snippet contains enough instructions for SLOTHY
    to consider register renaming, so the absence of callee-saved registers in
    the output is a meaningful behavioural check."""

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55):
        super().__init__(
            "aarch64_prefer_caller_save",
            rename=True,
            arch=arch,
            target=target,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.outputs = ["v0", "v1", "v5", "v7"]
        slothy.config.constraints.prefer_caller_save_registers = True
        slothy.optimize(start="start", end="end")

        callee_saved_neon = {f"v{i}" for i in range(8, 16)}
        source_text = "\n".join(
            line.to_string(comments=False, tags=False)
            for line in slothy.source
            if line.text
        )
        found_vregs = {f"v{n}" for n in re.findall(r"\bv(\d+)", source_text)}
        introduced = callee_saved_neon & found_vregs
        if introduced:
            raise Exception(
                f"prefer_caller_save_registers=True introduced callee-saved "
                f"NEON register(s): {', '.join(sorted(introduced))}"
            )


class AArch64PreferCallerSaveForced(OptimizationRunner):
    """Verify that prefer_caller_save_registers=True still produces correct
    code when callee-saved registers are unavoidable.

    Three independent NTT butterflies all reuse v4, v5 as temporaries.
    v7 and v16-v31 are reserved, leaving only v4 and v5 as free caller-save
    scratch space.  Overlapping any two butterflies for ILP needs four
    simultaneous temporaries, which exhausts the caller-save pool and forces
    SLOTHY to introduce at least one callee-saved register (v8-v15).

    The test asserts:
      - the selftest passes (functional correctness is preserved), and
      - at least one v8-v15 register appears in the output (confirming that
        callee-saved registers were actually introduced when necessary)."""

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55):
        super().__init__(
            "aarch64_prefer_caller_save_forced",
            rename=True,
            arch=arch,
            target=target,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.outputs = ["v0", "v1", "v5", "v6"]
        slothy.config.constraints.prefer_caller_save_registers = True
        slothy.config.reserved_regs = ["v7"] + [f"v{i}" for i in range(16, 32)]
        slothy.optimize(start="start", end="end")

        source_text = "\n".join(
            line.to_string(comments=False, tags=False)
            for line in slothy.source
            if line.text
        )
        found_callee_saved = {
            f"v{n}" for n in re.findall(r"\bv(\d+)", source_text) if 8 <= int(n) <= 15
        }
        if not found_callee_saved:
            raise Exception(
                "Expected SLOTHY to introduce callee-saved NEON registers "
                "(v8-v15) when caller-save scratch space is exhausted, but "
                "none were found in the output"
            )


class AArch64ClobberComment(OptimizationRunner):
    """Verify that emit_clobbered_callee_saves_comment=True prepends a comment
    listing the callee-saved registers that the snippet clobbers.  The input
    explicitly uses v8, v9 (callee-saved NEON) and x19 (callee-saved GPR),
    so all three must appear in the comment.

    Renaming is disabled so the output registers match the input exactly and
    the assertion is not sensitive to which physical register SLOTHY happens
    to allocate."""

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55):
        super().__init__(
            "aarch64_clobber_comment",
            rename=True,
            arch=arch,
            target=target,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.constraints.allow_renaming = False
        slothy.config.outputs = ["v8", "x19"]
        slothy.config.emit_clobbered_callee_saves_comment = True
        slothy.optimize(start="start", end="end")

        source_text = "\n".join(line.to_string() for line in slothy.source)
        if "Clobbered callee-saved registers:" not in source_text:
            raise Exception(
                "emit_clobbered_callee_saves_comment=True did not produce "
                "a clobber comment in the output"
            )
        # All three callee-saved registers used in the snippet must be listed.
        for reg in ("v8", "v9", "x19"):
            # The comment line contains the register names separated by ", "
            comment_line = next(
                (
                    line.to_string()
                    for line in slothy.source
                    if "Clobbered callee-saved registers:" in line.to_string()
                ),
                "",
            )
            if reg not in comment_line:
                raise Exception(
                    f"Clobber comment is missing callee-saved register {reg}. "
                    f"Full comment line: {comment_line!r}"
                )


class AArch64ClobberCommentSWP(OptimizationRunner):
    """Verify that emit_clobbered_callee_saves_comment works through the SW
    pipelining code path in Heuristics.periodic().

    The loop uses callee-saved NEON registers v8, v9, v12.  Renaming is
    disabled so the output registers are fixed.  minimize_overlapping is
    disabled so the solver is free to move instructions across iteration
    boundaries, producing non-empty preamble and postamble; the clobbered set
    must be accumulated across kernel + preamble + postamble and appear in the
    comment prepended to kernel_code."""

    def __init__(self, arch=AArch64_Neon, target=Target_CortexA55):
        super().__init__(
            "aarch64_clobber_comment_swp",
            rename=True,
            arch=arch,
            target=target,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.constraints.allow_renaming = False
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.emit_clobbered_callee_saves_comment = True
        slothy.optimize_loop("start")

        source_text = "\n".join(line.to_string() for line in slothy.source)
        if "Clobbered callee-saved registers:" not in source_text:
            raise Exception(
                "emit_clobbered_callee_saves_comment=True did not produce "
                "a clobber comment through the SW pipelining code path"
            )
        comment_line = next(
            line.to_string()
            for line in slothy.source
            if "Clobbered callee-saved registers:" in line.to_string()
        )
        for reg in ("v8", "v9"):
            if reg not in comment_line:
                raise Exception(
                    f"Clobber comment missing {reg}. Full line: {comment_line!r}"
                )


test_instances = [
    Instructions(),
    Instructions(target=Target_CortexA72),
    Instructions(target=Target_NeoverseN1),
    AArch64Example0(),
    AArch64Example0(target=Target_CortexA72),
    AArch64Example0Equ(),
    AArch64Equ(),
    AArch64Example1(),
    AArch64Example1(target=Target_CortexA72),
    AArch64Example2(),
    AArch64Example2(target=Target_CortexA72),
    AArch64ExampleLdSt(),
    AArch64ExampleImpossible(),
    AArch64IfElse(),
    AArch64Split0(),
    AArch64Aese(),
    AArch64LoopSub(),
    AArch64LoopSubs(),
    AArch64LoopSubTabs(),
    AArch64Ubfx(),
    AArch64LoopLabels(),
    AArch64LoopBranch(),
    AArch64FusionVeor(),
    AArch64CStyleComments(),
    AArch64SelftestAddr(),
    AArch64SelftestInitialRegs(),
    AArch64Directives(),
    AArch64PreferCallerSave(),
    AArch64PreferCallerSaveForced(),
    AArch64ClobberComment(),
    AArch64ClobberCommentSWP(),
]

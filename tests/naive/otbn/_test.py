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
import slothy.targets.otbn.otbn as Arch_OTBN
import slothy.targets.otbn.otbn_uarch as Target_OTBN


class UnexpectedTestResultException(Exception):
    pass


def expect_optimization_failure(
    slothy, *, start=None, end=None, label=None, reason="No solution found"
):
    """Run optimize and ensure it fails; raise if it succeeds."""
    context = label
    if context is None:
        if start is not None and end is not None:
            context = f"{start}->{end}"
        elif start is not None:
            context = start
        elif end is not None:
            context = f"end={end}"
        else:
            context = "default snippet"

    try:
        if start is None and end is None:
            slothy.optimize()
        else:
            slothy.optimize(start=start, end=end)
    except Exception as exc:
        if reason in str(exc):
            slothy.logger.info(
                f"As expected, optimization failed with {reason} for {context}: {exc}"
            )
            return
        else:
            raise UnexpectedTestResultException(
                f"Optimization failed for wrong reason {context}: {exc}"
            )

    raise UnexpectedTestResultException(
        f"Optimization unexpectedly succeeded for {context}"
    )


class Instructions(OptimizationRunner):
    def __init__(self, arch=Arch_OTBN, target=Target_OTBN):
        super().__init__("instructions", base_dir="tests", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.selftest = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.optimize(start="start", end="end")


class leakage(OptimizationRunner):
    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4", "w5", "w6", "w7", "w8", "w11"]

        # w0, w1 are shares of secret 'a'
        # w2, w3 are shares of secret 'b'
        # w9, w10 are public inputs
        # w4 = a[0] + b[0] - depends on both a and b (share 0 of each)
        # w5 = a[1] + b[1] - depends on both a and b (share 1 of each)
        # w6 = w4 + w4 = 2*(a[0] + b[0]) - still depends on a[0] and b[0]
        # w7 = w5 + w5 = 2*(a[1] + b[1]) - still depends on a[1] and b[1]
        # w8 = w9 + w10 - public + public = no masking info (public)
        # w11 = w8 + w8 - public + public = no masking info (public)
        slothy.config.secret_inputs = {
            "a": [["w0"], ["w1"]],  # 2 shares, each share uses 1 register
            "b": [["w2"], ["w3"]],
        }
        slothy.config.public_inputs = {"w9", "w10"}

        slothy.optimize()


class leakage_rule_1(OptimizationRunner):
    """Example that violates rule 1: overwriting shares of same secret - should error"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_1"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w1", "w2", "w3"]
        slothy.config.variable_size = True

        slothy.config.constraints.track_share_taint = True

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}
        for start, end in [(f"start{i}", f"end{i}") for i in range(1, 6)]:
            expect_optimization_failure(slothy, start=start, end=end)
        slothy.optimize(start="start6", end="end6")


class leakage_rule_2(OptimizationRunner):
    """Example that violates rule 2: mixing shares of the same secret - should error"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_2"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4"]

        # This violates rule 2: mixing share0 (w0) and share1 (w1) of the same secret
        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        expect_optimization_failure(slothy)


class leakage_rule_3(OptimizationRunner):
    """Example violating rule 3: Shares of same secret in consecutive instructions"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_3"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.variable_size = True
        slothy.config.outputs = ["w4", "w7", "x1"]
        # Disallow stalls so that only actual NOP instructions can satisfy
        # the share separation constraint
        slothy.config.constraints.stalls_maximum_attempt = 0

        # This violates rule 3: mixing share0 (w0) and share1 (w1) of the same secret
        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        slothy.optimize(start="start", end="end")

        # start2 will fail initially, but automatic NOP injection will make it succeed
        slothy.config.constraints.automatic_nop_injection = True
        slothy.config.constraints.automatic_nop_max_injections = 1
        slothy.optimize(start="start2", end="end2")


class leakage_declassify(OptimizationRunner):
    """Example that showcases automatic declassification."""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_declassify"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w3"]

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}
        slothy.optimize(start="start", end="end")
        slothy.optimize(start="start2", end="end2")
        expect_optimization_failure(slothy, start="start3", end="end3")


class leakage_rule_4(OptimizationRunner):
    """Example that violates rule 4: shares in different bits of same register"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_4"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4"]

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}
        expect_optimization_failure(slothy)


class leakage_rule_5(OptimizationRunner):
    """Example that violates rule 5: addition/subtraction creating share relationships"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_5"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4"]

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}
        # TODO: Not failing for the right reason
        slothy.optimize()


class leakage_rule_6(OptimizationRunner):
    """Example that violates rule 6: source as destination in bn.sel with secret flag"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_6"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.variable_size = True
        slothy.config.outputs = ["w5", "w9", "w4"]

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        # Test case 1: Wd==Wa with secret flag (should fail)
        expect_optimization_failure(
            slothy, start="start", end="end", label="Test 1: Wd==Wa with secret flag"
        )

        # Test case 2: Wd==Wb with secret flag (should fail)
        expect_optimization_failure(
            slothy, start="start2", end="end2", label="Test 2: Wd==Wb with secret flag"
        )

        # Test case 3: Wd==Wa but public flag (should succeed)
        slothy.optimize(start="start3", end="end3")

        # Test case 4: Healable (should succeed)
        slothy.config.outputs = ["w9", "w10"]
        slothy.optimize(start="start4", end="end4")


class leakage_rule_7(OptimizationRunner):
    """Example that violates rule 7: two shares of same secret in bn.sel"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_7"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4"]

        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        expect_optimization_failure(slothy)


class leakage_rule_8(OptimizationRunner):
    """Example that violates rule 8: bn.mulqacc without clearing ACC/flags"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_8"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False

        # Forbid overwriting FG1 to force use of FG0
        r = slothy.config.reserved_regs
        r = r.union(["FG1"])
        slothy.config.reserved_regs = r

        slothy.config.outputs = ["w6", "w7", "FG0"]

        slothy.config.constraints.track_share_taint = True
        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        # TODO: 1. case should fail because of relation through FG (overwrite)
        expect_optimization_failure(slothy, start="start", end="end")
        expect_optimization_failure(
            slothy, start="start2", end="end2", reason="Cannot mix different shares"
        )

        slothy.optimize(start="start3", end="end3")
        slothy.optimize(start="start4", end="end4")


class leakage_rule_9(OptimizationRunner):
    """Example violating rule 9: not clearing flags after secret-dependent operations"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_9"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w5", "w6"]

        slothy.config.secret_inputs = {"a": [["w0"]]}

        slothy.optimize(start="start", end="end")
        slothy.optimize(start="start2", end="end2")
        slothy.optimize(start="start3", end="end3")
        slothy.optimize(start="start4", end="end4")


class leakage_rule_10(OptimizationRunner):
    """Example for rule 10: apply fresh masking when needed"""

    def __init__(self, var="", arch=Arch_OTBN, target=Target_OTBN, timeout=None):
        name = "leakage_rule_10"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            base_dir="tests",
        )

    def core(self, slothy):
        slothy.config.selftest = False
        slothy.config.outputs = ["w4"]

        slothy.config.secret_inputs = {"a": [["w0"]]}

        slothy.optimize()


test_instances = [
    Instructions(),
    leakage(),
    leakage_rule_1(),
    leakage_rule_2(),
    leakage_rule_3(),
    leakage_declassify(),
    leakage_rule_4(),
    leakage_rule_5(),
    leakage_rule_6(),
    leakage_rule_7(),
    leakage_rule_8(),
    leakage_rule_9(),
    leakage_rule_10(),
]

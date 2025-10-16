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
from slothy.core.core import SlothyException


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

        slothy.optimize()


class leakage_rule_3(OptimizationRunner):
    """Example that violates rule 3: Using shares of the same secret in consecutive instructions"""

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
        # Disallow any stalls such that "waiting" a cycle does not make
        # forbidden back-to-back instructions pass optimization.
        # Eventually, NOPs should be inserted to automatically "heal"
        slothy.config.constraints.stalls_maximum_attempt = 0

        # This violates rule 2: mixing share0 (w0) and share1 (w1) of the same secret
        slothy.config.secret_inputs = {"a": [["w0"], ["w1"]]}

        slothy.optimize(start="start", end="end")
        try:
            slothy.optimize(start="start2", end="end2")
        except SlothyException:
            slothy.logger.info("No solution found, but this is expected!")


test_instances = [Instructions(), leakage(), leakage_rule_2(), leakage_rule_3()]

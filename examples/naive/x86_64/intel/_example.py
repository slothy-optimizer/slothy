#
# Copyright (c) 2026 Maggie Simmons
# Copyright (c) 2026 Hayden Parsons
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

import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.x86_64.x86_64 as Arch_X86_64
import slothy.targets.x86_64.intel_atom as Target_IntelAtom
from slothy.targets.x86_64.x86_translator import Intel_Code

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class X86_64SimpleIntel(OptimizationRunner):
    def __init__(self, var="", arch=Arch_X86_64, target=Target_IntelAtom, timeout=None):
        name = "x86_64_simple_intel"
        super().__init__(
            name,
            name,
            subfolder=SUBFOLDER,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
        )

    def core(self, slothy):
        slothy.config.syntax = Intel_Code
        slothy.config.variable_size = True
        slothy.config.outputs = ["rcx", "r9"]
        slothy.optimize(start="start", end="end")


example_instances = [
    X86_64SimpleIntel(),
]

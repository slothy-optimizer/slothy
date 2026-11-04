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

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.x86_64.x86_64 as Arch_X86_64
import slothy.targets.x86_64.intel_atom as Target_IntelAtom
from tests.naive.x86_64.test_instruction_model import run_instruction_model_tests
from tests.naive.x86_64.test_atom_model import run_atom_model_tests


class Instructions(OptimizationRunner):
    def __init__(self, arch=Arch_X86_64, target=Target_IntelAtom):
        super().__init__("instructions", base_dir="tests", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 256
        slothy.optimize(start="start", end="end")


class InstructionsSubregisters(OptimizationRunner):
    def __init__(self, arch=Arch_X86_64, target=Target_IntelAtom):
        super().__init__(
            "instructions_subregisters", base_dir="tests", arch=arch, target=target
        )

    def core(self, slothy):
        slothy.config.allow_useless_instructions = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.variable_size = True
        slothy.optimize(start="start", end="end")


class Equ(OptimizationRunner):
    def __init__(self, arch=Arch_X86_64, target=Target_IntelAtom):
        super().__init__("x86_64_equ", base_dir="tests", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.outputs = ["rax"]
        slothy.optimize(start="start", end="end")


class _UnitTests:
    """Runs a module's plain test functions as part of test.py"""

    def __init__(self, name, run_tests):
        self.name = name
        self._run_tests = run_tests

    def run(
        self,
        debug=False,
        log_model=False,
        log_model_dir="models",
        dry_run=False,
        silent=False,
        timeout=0,
        debug_logfile=None,
        only_target=None,
    ):
        if only_target is not None and only_target != Target_IntelAtom.__name__:
            return

        if not silent:
            print(f"* Example: {self.name}...")
        self._run_tests()


test_instances = [
    Instructions(),
    InstructionsSubregisters(),
    Equ(),
    _UnitTests("instruction_model_x86_64", run_instruction_model_tests),
    _UnitTests("atom_model", run_atom_model_tests),
]

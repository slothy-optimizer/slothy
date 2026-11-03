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
from slothy.targets.x86_64.x86_translator import Atat_Code

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class KeccakRound(OptimizationRunner):
    """One Keccak-f[1600] round (state in rdi, output to the stack), rendered from
    examples/naive/x86_64/keccak/x86_mKeccakRound_template.s.

    Split-heuristic settings (SPLITPARAMS-3_1_6_1) and the opt-in Atom memory
    constraint are those of the sweep batch in which this setting measured fastest
    on Bonnell (about 108 cycles); that batch was optimized with the constraint on."""

    def __init__(self, var="", arch=Arch_X86_64, target=Target_IntelAtom, timeout=None):
        name = "keccak_round_rdi_rsp"
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
        # AT&T input with size suffixes (movq, xorq, ...); the translator
        # normalizes them
        slothy.config.syntax = Atat_Code
        slothy.config.allow_useless_instructions = True
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.reserved_regs = []
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 3
        slothy.config.split_heuristic_stepsize = 1 / 6
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_estimate_performance = False
        Target_IntelAtom.memory_offset_constraint = True
        try:
            slothy.optimize(start="start")
        finally:
            Target_IntelAtom.memory_offset_constraint = False


example_instances = [
    KeccakRound(),
]

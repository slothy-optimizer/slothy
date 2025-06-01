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
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class CRT(OptimizationRunner):
    def __init__(self):
        super().__init__("crt", subfolder=SUBFOLDER)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.selfcheck = True
        # Double the loop body to create more interleaving opportunities
        # Basically a tradeoff of code-size vs performance
        slothy.config.sw_pipelining.unroll = 2
        slothy.config.typing_hints = {
            "const_prshift": Arch_Armv81M.RegisterType.GPR,
            "const_shift9": Arch_Armv81M.RegisterType.GPR,
            "p_inv_mod_q": Arch_Armv81M.RegisterType.GPR,
            "p_inv_mod_q_tw": Arch_Armv81M.RegisterType.GPR,
            "mod_p": Arch_Armv81M.RegisterType.GPR,
            "mod_p_tw": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize()


example_instances = [
    CRT(),
]

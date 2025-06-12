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
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class fft_floatingpoint_radix4(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "floatingpoint_radix4_fft"
        infile = "base_symbolic"
        outfile = name

        super().__init__(
            infile,
            name,
            outfile=outfile,
            rename=True,
            arch=arch,
            target=target,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        # This is default value, but it's overwritten in case of a dry-run.
        # However, the symbolic registers in the FLT FFT cannot be resolved
        # without reordering, so let's ignore the dry-run parameter here.
        slothy.config.constraints.allow_reordering = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("flt_radix4_fft_loop_start")
        slothy.rename_function("floatingpoint_radix4_fft_symbolic", "floatingpoint_radix4_fft_opt_M55")


example_instances = [
    fft_floatingpoint_radix4(),
]

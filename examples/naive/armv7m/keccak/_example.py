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
import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class Keccak(OptimizationRunner):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "keccakf1600"
        infile = name
        funcname = "KeccakF1600_StatePermute"

        super().__init__(
            infile,
            name,
            var=var,
            subfolder=SUBFOLDER,
            funcname=funcname,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.reserved_regs = ["sp", "r13"]
        slothy.config.locked_registers = ["sp", "r13"]
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.config.split_heuristic_stepsize = 0.05

        if "adomnicai_m7" in self.name:
            slothy.config.split_heuristic_factor = 6

            slothy.config.outputs = [
                "hint_spEga0",
                "hint_spEge0",
                "hint_spEgi0",
                "hint_spEgo0",
                "hint_spEgu0",
                "hint_spEka1",
                "hint_spEke1",
                "hint_spEki1",
                "hint_spEko1",
                "hint_spEku1",
                "hint_spEma0",
                "hint_spEme0",
                "hint_spEmi0",
                "hint_spEmo0",
                "hint_spEmu0",
                "hint_spEsa1",
                "hint_spEse1",
                "hint_spEsi1",
                "hint_spEso1",
                "hint_spEsu1",
                "hint_spEbe0",
                "hint_spEbi0",
                "hint_spEbo0",
                "hint_spEbu0",
                "hint_spEba0",
                "hint_spEga1",
                "hint_spEge1",
                "hint_spEgi1",
                "hint_spEgo1",
                "hint_spEgu1",
                "hint_spEka0",
                "hint_spEke0",
                "hint_spEki0",
                "hint_spEko0",
                "hint_spEku0",
                "hint_spEma1",
                "hint_spEme1",
                "hint_spEmi1",
                "hint_spEmo1",
                "hint_spEmu1",
                "hint_spEsa0",
                "hint_spEse0",
                "hint_spEsi0",
                "hint_spEso0",
                "hint_spEsu0",
                "hint_spEbe1",
                "hint_spEbi1",
                "hint_spEbo1",
                "hint_spEbu1",
                "hint_spEba1",
            ]
            slothy.optimize(start="slothy_start_round0", end="slothy_end_round0")
            slothy.config.outputs = [
                "flags",
                "hint_r0Aba0",
                "hint_r0Aba1",
                "hint_r0Abe0",
                "hint_r0Abe1",
                "hint_r0Abi0",
                "hint_r0Abi1",
                "hint_r0Abo0",
                "hint_r0Abo1",
                "hint_r0Abu0",
                "hint_r0Abu1",
                "hint_r0Aga0",
                "hint_r0Aga1",
                "hint_r0Age0",
                "hint_r0Age1",
                "hint_r0Agi0",
                "hint_r0Agi1",
                "hint_r0Ago0",
                "hint_r0Ago1",
                "hint_r0Agu0",
                "hint_r0Agu1",
                "hint_r0Aka0",
                "hint_r0Aka1",
                "hint_r0Ake0",
                "hint_r0Ake1",
                "hint_r0Aki0",
                "hint_r0Aki1",
                "hint_r0Ako0",
                "hint_r0Ako1",
                "hint_r0Aku0",
                "hint_r0Aku1",
                "hint_r0Ama0",
                "hint_r0Ama1",
                "hint_r0Ame0",
                "hint_r0Ame1",
                "hint_r0Ami0",
                "hint_r0Ami1",
                "hint_r0Amo0",
                "hint_r0Amo1",
                "hint_r0Amu0",
                "hint_r0Amu1",
                "hint_r0Asa0",
                "hint_r0Asa1",
                "hint_r0Ase0",
                "hint_r0Ase1",
                "hint_r0Asi0",
                "hint_r0Asi1",
                "hint_r0Aso0",
                "hint_r0Aso1",
                "hint_r0Asu0",
                "hint_r0Asu1",
            ]
            slothy.optimize(start="slothy_start_round1", end="slothy_end_round1")
        else:
            if "xkcp" in self.name:
                slothy.config.outputs = [
                    "flags",
                    "hint_spEba0",
                    "hint_spEba1",
                    "hint_spEbe0",
                    "hint_spEbe1",
                    "hint_spEbi0",
                    "hint_spEbi1",
                    "hint_spEbo0",
                    "hint_spEbo1",
                    "hint_spEbu0",
                    "hint_spEbu1",
                    "hint_spEga0",
                    "hint_spEga1",
                    "hint_spEge0",
                    "hint_spEge1",
                    "hint_spEgi0",
                    "hint_spEgi1",
                    "hint_spEgo0",
                    "hint_spEgo1",
                    "hint_spEgu0",
                    "hint_spEgu1",
                    "hint_spEka0",
                    "hint_spEka1",
                    "hint_spEke0",
                    "hint_spEke1",
                    "hint_spEki0",
                    "hint_spEki1",
                    "hint_spEko0",
                    "hint_spEko1",
                    "hint_spEku0",
                    "hint_spEku1",
                    "hint_spEma0",
                    "hint_spEma1",
                    "hint_spEme0",
                    "hint_spEme1",
                    "hint_spEmi0",
                    "hint_spEmi1",
                    "hint_spEmo0",
                    "hint_spEmo1",
                    "hint_spEmu0",
                    "hint_spEmu1",
                    "hint_spEsa0",
                    "hint_spEsa1",
                    "hint_spEse0",
                    "hint_spEse1",
                    "hint_spEsi0",
                    "hint_spEsi1",
                    "hint_spEso0",
                    "hint_spEso1",
                    "hint_spEsu0",
                    "hint_spEsu1",
                ]
            if "adomnicai_m4" in self.name:
                slothy.config.outputs = [
                    "flags",
                    "hint_r0Aba1",
                    "hint_r0Aka1",
                    "hint_spEba0",
                    "hint_spEba1",
                    "hint_spEbe0",
                    "hint_spEbe1",
                    "hint_spEbi0",
                    "hint_spEbi1",
                    "hint_spEbo0",
                    "hint_spEbo1",
                    "hint_spEbu0",
                    "hint_spEbu1",
                    "hint_spEga0",
                    "hint_spEga1",
                    "hint_spEge0",
                    "hint_spEge1",
                    "hint_spEgi0",
                    "hint_spEgi1",
                    "hint_spEgo0",
                    "hint_spEgo1",
                    "hint_spEgu0",
                    "hint_spEgu1",
                    "hint_spEka0",
                    "hint_spEka1",
                    "hint_spEke0",
                    "hint_spEke1",
                    "hint_spEki0",
                    "hint_spEki1",
                    "hint_spEko0",
                    "hint_spEko1",
                    "hint_spEku0",
                    "hint_spEku1",
                    "hint_spEma0",
                    "hint_spEma1",
                    "hint_spEme0",
                    "hint_spEme1",
                    "hint_spEmi0",
                    "hint_spEmi1",
                    "hint_spEmo0",
                    "hint_spEmo1",
                    "hint_spEmu0",
                    "hint_spEmu1",
                    "hint_spEsa0",
                    "hint_spEsa1",
                    "hint_spEse0",
                    "hint_spEse1",
                    "hint_spEsi0",
                    "hint_spEsi1",
                    "hint_spEso0",
                    "hint_spEso1",
                    "hint_spEsu0",
                    "hint_spEsu1",
                    "hint_spmDa0",
                ]

            slothy.config.split_heuristic_factor = 22
            slothy.config.constraints.stalls_first_attempt = 16

            slothy.optimize(start="slothy_start", end="slothy_end")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    Keccak(var="xkcp"),
    Keccak(var="adomnicai_m4"),
    Keccak(var="adomnicai_m7"),
]

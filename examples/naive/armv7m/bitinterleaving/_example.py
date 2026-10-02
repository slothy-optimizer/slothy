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
# Author: Bruno Ribeiro de Almeida <almeidabruno99@gmail.com>
#
# Contributed by the UFCG team of the CISSA project, "Otimização de Algoritmos
# Pós-Quânticos para Plataformas Restritas" (Optimization of Post-Quantum
# Algorithms for Constrained Platforms), at the Unidade Acadêmica de Engenharia
# Elétrica, Universidade Federal de Campina Grande, Campina Grande, PB, Brazil,
# with the EMBRAPII CESAR Competence Centre in Cybersecurity.
#
#   Edmar Candeia Gurjão, Leocarlos Bezerra da Silva Lima,
#   Bruno Ribeiro de Almeida, Fernando Luiz Florência Barros,
#   João Mateus Alves Felinto, Marcus Vinícius Almeida Filho
#

import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class BitInterleaving(OptimizationRunner):
    """Keccak bit-interleaving helpers.

    Covers the instruction classes added alongside this example: `and` with an
    immediate (both the three- and two-operand forms), `lsr`, `bfi`, `bfc` and
    register-to-register `mov`/`movs`. Before those existed, SLOTHY could not
    parse these routines at all.
    """

    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "bitinterleaving"
        super().__init__(
            name,
            name,
            var=var,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.config.reserved_regs = ["sp", "r13"]
        slothy.config.locked_registers = ["sp", "r13"]

        slothy.config.outputs = ["r2", "r3"]
        slothy.optimize(start="slothy_start_to", end="slothy_end_to")

        slothy.config.outputs = ["r0", "r1"]
        slothy.config.inputs_are_outputs = True
        slothy.optimize(start="slothy_start_from", end="slothy_end_from")


example_instances = [
    BitInterleaving(),
]

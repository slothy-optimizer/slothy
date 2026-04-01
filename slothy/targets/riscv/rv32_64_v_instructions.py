#
# Copyright (c) 2024 Justus Bergermann
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
# Author: Justus Bergermann <mail@justus-bergermann.de>
#

"""This module creates the RV3264-V extension set instructions"""
from slothy.targets.riscv.riscv_super_instructions import *  # noqa: F403
from slothy.targets.riscv.riscv_instruction_core import RISCVInstruction


class RISCVvsetvli(RISCVInstruction):
    pattern = "vsetvli <Xd>, <Xa>, <vtype>"
    inputs = ["Xa"]
    outputs = ["Xd"]


class RISCVvsetivli(RISCVInstruction):
    pattern = "vsetivli <Xd>, <imm>, <vtype>"
    inputs = []
    outputs = ["Xd"]


class RISCVvsetvl(RISCVInstruction):
    pattern = "vsetvl <Xd>, <Xa>, <Xb>"
    inputs = ["Xa", "Xb"]
    outputs = ["Xd"]


v_instrs = [
    (["vle<len>.v"], RISCVVectorLoadUnitStride),
    (["vlse<len>.v"], RISCVVectorLoadStrided),
    (["vluxei<len>.v", "vloxei<len>.v"], RISCVVectorLoadIndexed),
    (["vl<nf>re<ew>.v", "vl<nf>r.v"], RISCVVectorLoadWholeRegister),
    (["vse<len>.v"], RISCVVectorStoreUnitStride),
    (["vsse<len>.v"], RISCVVectorStoreStrided),
    (["vsuxei<len>.v", "vsoxei<len>.v"], RISCVVectorStoreIndexed),
    (["vs<nf>re<ew>.v", "vs<nf>r.v"], RISCVVectorStoreWholeRegister),
    (
        [
            "vadd.vv",
            "vsub.vv",
            "vrsub.vv",
            "vand.vv",
            "vor.vv",
            "vxor.vv",
            "vsll.vv",
            "vsrl.vv",
            "vmseq.vv",
            "vmsne.vv",
            "vmsltu.vv",
            "vmslt.vv",
            "vmsleu.vv",
            "vmsle.vv",
            "vminu.vv",
            "vmin.vv",
            "vmaxu.vv",
            "vmax.vv",
            "vmul.vv",
            "vmulh.vv",
            "vmulhu.vv",
            "vmulhsu.vv",
            "vdivu.vv",
            "vdiv.vv",
            "vremu.vv",
            "vrem.vv",
            "vmacc.vv",
            "vnmsac.vv",
            "vmadd.vv",
            "vnmsub.vv",
            "vrgather.vv",
            "vrgatherei16.vv",
        ],
        RISCVVectorIntegerVectorVector,
    ),
    (
        [
            "vadd.vx",
            "vsub.vx",
            "vrsub.vx",
            "vand.vx",
            "vor.vx",
            "vxor.vx",
            "vsll.vx",
            "vsrl.vx",
            "vmseq.vx",
            "vmsne.vx",
            "vmsltu.vx",
            "vmslt.vx",
            "vmsleu.vx",
            "vmsle.vx",
            "vmsgtu.vx",
            "vmsgt.vx",
            "vmsgeu.vx",
            "vmsge.vx",
            "vminu.vx",
            "vmin.vx",
            "vmaxu.vx",
            "vmax.vx",
            "vmul.vx",
            "vmulh.vx",
            "vmulhu.vx",
            "vmulhsu.vx",
            "vdivu.vx",
            "vdiv.vx",
            "vremu.vx",
            "vrem.vx",
            "vmacc.vx",
            "vnmsac.vx",
            "vmadd.vx",
            "vnmsub.vx",
            "vrgather.vx",
        ],
        RISCVVectorIntegerVectorScalar,
    ),
    (
        [
            "vadd.vi",
            "vrsub.vi",
            "vand.vi",
            "vor.vi",
            "vxor.vi",
            "vsll.vi",
            "vsrl.vi",
            "vsra.vi",
            "vmseq.vi",
            "vmsne.vi",
            "vmsleu.vi",
            "vmsle.vi",
            "vmsgtu.vi",
            "vmsgt.vi",
            "vrgather.vi",
        ],
        RISCVVectorIntegerVectorImmediate,
    ),
    (["vmerge.vvm"], RISCVVectorIntegerVectorVectorMasked),
    (["vmerge.vxm"], RISCVVectorIntegerVectorScalarMasked),
    (["vmerge.vim"], RISCVVectorIntegerVectorImmediateMasked),
    (["vsetvli"], RISCVvsetvli),
    (["vsetivli"], RISCVvsetivli),
    (["vsetvl"], RISCVvsetvl),
    (["vmv.x.s"], RISCVScalarVector),
    (["vmv.s.x"], RISCVVectorScalar),
    (["vmv.v.v"], RISCVVectorVector),
    (["vnmsac.vx"], RISCVVectorScalarVector),
]


def generate_rv32_64_v_instructions():
    """
    Generates all instruction classes for the rv32_64_v extension set
    """
    for elem in v_instrs:
        RISCVInstruction.instr_factory(elem[0], elem[1])

    RISCVInstruction.classes_by_names.update(
        {cls.__name__: cls for cls in RISCVInstruction.dynamic_instr_classes}
    )
    return RISCVInstruction.dynamic_instr_classes


generate_rv32_64_v_instructions()

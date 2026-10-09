#
# Copyright (c) 2026 Arm Limited
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
# Author: Brendan Moran <brendan.moran@arm.com>
#

import logging

from slothy.core.config import Config
from slothy.core.dataflow import DataFlowGraph
from slothy.helper import SourceLine
import slothy.targets.arm_v81m.arch_v81m as Arch
import slothy.targets.arm_v81m.cortex_m55r1 as Target


def _graph(src, outputs=None, allow_useless=True):
    logger = logging.getLogger(__name__)
    logger.addHandler(logging.NullHandler())
    logger.propagate = False
    config = Config(Arch, Target, logger)
    config.allow_useless_instructions = allow_useless
    config.outputs = set(outputs or [])
    return DataFlowGraph(SourceLine.read_multiline(src), logger, config)


def test_adjacent_vmov_pair_rewrites_first_only():
    graph = _graph(
        """
        vmov q1[2], q1[0], r0, r1
        vmov q1[3], q1[1], r2, r3
        """,
        outputs=["q1"],
    )

    first, second = graph.nodes
    assert first.inst.args_out == ["q1"]
    assert first.inst.args_in_out == []
    assert getattr(first.inst, "detected_vmov_double_r2v_pair", False)
    assert second.inst.args_in_out == ["q1"]
    assert second.src_in_out[0].src is first


def test_vmov_pair_rewrites_across_intervening_unrelated_instruction():
    graph = _graph(
        """
        vmov q1[2], q1[0], r0, r1
        ror r4, #10
        vmov q1[3], q1[1], r2, r3
        """,
        outputs=["q1", "r4"],
    )

    first, unrelated, second = graph.nodes
    assert first.inst.args_out == ["q1"]
    assert first.inst.args_in_out == []
    assert getattr(first.inst, "detected_vmov_double_r2v_pair", False)
    assert unrelated.inst.args_in_out == ["r4"]
    assert second.inst.args_in_out == ["q1"]
    assert second.src_in_out[0].src is first


def test_vmov_pair_does_not_rewrite_across_intervening_read():
    graph = _graph(
        """
        vmov q1[2], q1[0], r0, r1
        vadd.u32 q2, q1, q3
        vmov q1[3], q1[1], r2, r3
        """,
        outputs=["q1", "q2"],
    )

    first, reader, second = graph.nodes
    assert first.inst.args_out == []
    assert first.inst.args_in_out == ["q1"]
    assert not getattr(first.inst, "detected_vmov_double_r2v_pair", False)
    assert reader.src_in[0].src is first
    assert second.src_in_out[0].src is first


def test_repeated_vmov_pairs_do_not_chain_from_successor():
    graph = _graph(
        """
        vmov q1[2], q1[0], r0, r1
        vmov q1[3], q1[1], r2, r3
        vmov q1[2], q1[0], r4, r5
        vmov q1[3], q1[1], r6, r7
        """,
        outputs=["q1"],
    )

    first, second, third, fourth = graph.nodes
    assert first.inst.args_out == ["q1"]
    assert first.inst.args_in_out == []
    assert second.inst.args_out == []
    assert second.inst.args_in_out == ["q1"]
    assert not getattr(second.inst, "detected_vmov_double_r2v_pair", False)
    assert getattr(second.inst, "detected_vmov_double_r2v_pair_successor", False)
    assert second.src_in_out[0].src is first

    assert third.inst.args_out == ["q1"]
    assert third.inst.args_in_out == []
    assert fourth.inst.args_in_out == ["q1"]
    assert fourth.src_in_out[0].src is third


def test_cmp_outputs_flags():
    inst = Arch.Instruction.parser(SourceLine("cmp r7, #0xFF"))[0]
    assert inst.args_in == ["r7"]
    assert inst.args_out == ["flags"]
    assert inst.arg_types_out == [Arch.RegisterType.FLAGS]


def test_flags_can_be_declared_as_region_output():
    graph = _graph(
        "cmp r7, #0xFF\n",
        outputs=["flags"],
        allow_useless=False,
    )

    assert graph.nodes[0].inst.args_out == ["flags"]
    assert "flags" in graph.outputs


def test_issue_419_reproducer_forms_parse():
    insts = [
        Arch.Instruction.parser(SourceLine(line))[0]
        for line in [
            "bic  r1, r5, r4, ror #24",
            "str r6, [r13, #0]",
            "ror r3, #10",
            "cmp r7, #0xFF",
        ]
    ]

    assert insts[2].args_in_out == ["r3"]
    assert insts[1].is_load_store_instruction()
    assert insts[3].args_out == ["flags"]


def test_armv7m_width_suffix_and_expression_forms_parse():
    source_lines = [
        SourceLine("ldr.w r3, [r0, #8*4] // @slothy:reads=[r0Aba0]"),
        SourceLine("str.w r1, [r0, #3*4] // @slothy:writes=[r0Abe0]"),
        SourceLine("eor.w r3, r3, r5"),
    ]
    insts = [Arch.Instruction.parser(line)[0] for line in source_lines]

    assert insts[0].width == ".w"
    assert insts[0].immediate == "8*4"
    assert insts[0].args_in == ["r0", "hint_r0Aba0"]
    assert insts[1].width == ".w"
    assert insts[1].immediate == "3*4"
    assert insts[1].args_out == ["hint_r0Abe0"]
    assert insts[2].width == ".w"
    assert insts[2].args_in == ["r3", "r5"]
    assert insts[2].args_out == ["r3"]
    assert insts[0].write() == "ldr.w r3, [r0, #32]"
    assert insts[1].write() == "str.w r1, [r0, #3*4]"
    assert insts[2].write() == "eor.w r3, r3, r5"


def test_flexible_shifted_operand2_forms_parse_and_round_trip():
    cases = [
        ("add.w r0, r1, r2, ror #7", Arch.add_shifted),
        ("adc.w r0, r1, r2, ror #7", Arch.adc_shifted),
        ("and.w r0, r1, r2, ror #7", Arch.log_and_shifted),
        ("orr.w r0, r1, r2, ror #7", Arch.orr_shifted),
        ("orn.w r0, r1, r2, ror #7", Arch.orn_shifted),
        ("eor.w r0, r1, r2, ror #7", Arch.eor_shifted),
        ("bic.w r0, r1, r2, ror #7", Arch.bic_shifted),
        ("cmn.w r1, r2, ror #7", Arch.cmn_shifted),
        ("cmp.w r1, r2, ror #7", Arch.cmp_shifted),
        ("mvn.w r0, r2, ror #7", Arch.mvn_shifted),
        ("rsb.w r0, r1, r2, ror #7", Arch.rsb_shifted),
        ("sbc.w r0, r1, r2, ror #7", Arch.sbc_shifted),
        ("sub.w r0, r1, r2, ror #7", Arch.sub_shifted),
        ("teq.w r1, r2, ror #7", Arch.teq_shifted),
        ("tst.w r1, r2, ror #7", Arch.tst_shifted),
    ]

    for source, expected_class in cases:
        inst = Arch.Instruction.parser(SourceLine(source))[0]
        assert type(inst) is expected_class
        assert isinstance(inst, Arch.ShiftedOperandInstruction)
        assert inst.shifted_register == "r2"
        assert inst.width == ".w"
        assert inst.write() == source

        round_trip = Arch.Instruction.parser(SourceLine(inst.write()))[0]
        assert type(round_trip) is expected_class
        assert round_trip.shifted_register == "r2"
        assert round_trip.width == ".w"


def test_flexible_shifted_operand2_flag_semantics():
    adc = Arch.adc_shifted.make("adc.w r0, r1, r2, lsl #3")
    sbc = Arch.sbc_shifted.make("sbc.w r0, r1, r2, lsr #3")

    for inst in [adc, sbc]:
        assert inst.args_in == ["r1", "r2", "flags"]
        assert inst.arg_types_in == [
            Arch.RegisterType.GPR,
            Arch.RegisterType.GPR,
            Arch.RegisterType.FLAGS,
        ]
        assert inst.args_out == ["r0"]
        assert inst.shifted_register == "r2"

    for instruction_class, mnemonic in [
        (Arch.cmn_shifted, "cmn"),
        (Arch.cmp_shifted, "cmp"),
        (Arch.teq_shifted, "teq"),
        (Arch.tst_shifted, "tst"),
    ]:
        inst = instruction_class.make(f"{mnemonic}.w r1, r2, asr #3")
        assert inst.args_in == ["r1", "r2"]
        assert inst.args_out == ["flags"]
        assert inst.arg_types_out == [Arch.RegisterType.FLAGS]
        assert inst.shifted_register == "r2"

    mvn = Arch.mvn_shifted.make("mvn.w r0, r2, ror #3")
    assert mvn.args_in == ["r2"]
    assert mvn.args_out == ["r0"]
    assert mvn.shifted_register == "r2"


def test_shifted_adc_and_sbc_consume_without_replacing_flags():
    graph = _graph(
        """
        cmp r7, r8
        adc.w r0, r1, r2, lsl #3
        sbc.w r3, r4, r5, lsr #3
        """,
        outputs=["r0", "r3"],
        allow_useless=False,
    )

    compare, adc, sbc = graph.nodes
    assert adc.src_in[2].src is compare
    assert sbc.src_in[2].src is compare


def test_pkhbt_is_not_a_flexible_operand2_instruction():
    inst = Arch.pkhbt_shifted.make("pkhbt r0, r1, r2, lsl #16")
    assert not isinstance(inst, Arch.ShiftedOperandInstruction)


def run_instruction_model_tests():
    test_adjacent_vmov_pair_rewrites_first_only()
    test_vmov_pair_rewrites_across_intervening_unrelated_instruction()
    test_vmov_pair_does_not_rewrite_across_intervening_read()
    test_repeated_vmov_pairs_do_not_chain_from_successor()
    test_cmp_outputs_flags()
    test_flags_can_be_declared_as_region_output()
    test_issue_419_reproducer_forms_parse()
    test_armv7m_width_suffix_and_expression_forms_parse()
    test_flexible_shifted_operand2_forms_parse_and_round_trip()
    test_flexible_shifted_operand2_flag_semantics()
    test_shifted_adc_and_sbc_consume_without_replacing_flags()
    test_pkhbt_is_not_a_flexible_operand2_instruction()


if __name__ == "__main__":
    run_instruction_model_tests()

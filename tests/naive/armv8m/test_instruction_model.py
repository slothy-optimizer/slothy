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


def run_instruction_model_tests():
    test_adjacent_vmov_pair_rewrites_first_only()
    test_vmov_pair_rewrites_across_intervening_unrelated_instruction()
    test_vmov_pair_does_not_rewrite_across_intervening_read()
    test_repeated_vmov_pairs_do_not_chain_from_successor()
    test_cmp_outputs_flags()
    test_flags_can_be_declared_as_region_output()
    test_issue_419_reproducer_forms_parse()


if __name__ == "__main__":
    run_instruction_model_tests()

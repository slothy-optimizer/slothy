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

"""Unit tests for the x86_64 architectural model (AT&T syntax)"""

import logging
import subprocess
import sys
from pathlib import Path

from slothy import Slothy
from slothy.core.config import Config
from slothy.core.dataflow import DataFlowGraph, Config as DFGConfig
from slothy.helper import SourceLine
from slothy.targets.exceptions import ParsingException
import slothy.targets.x86_64.x86_64 as Arch
import slothy.targets.x86_64.intel_atom as Target
from slothy.targets.x86_64.x86_64_instruction_core import x86_64Instruction

REPO_ROOT = Path(__file__).resolve().parents[3]


def _logger():
    logger = logging.getLogger(__name__)
    logger.addHandler(logging.NullHandler())
    logger.propagate = False
    return logger


def _parse(line):
    insts = Arch.Instruction.parser(SourceLine(line))
    assert len(insts) == 1, insts
    return insts[0]


def _graph(src, outputs=None):
    config = Config(Arch, Target, _logger())
    config.allow_useless_instructions = True
    config.outputs = set(outputs or [])
    return DataFlowGraph(SourceLine.read_multiline(src), _logger(), DFGConfig(config))


def test_all_instruction_forms_parse():
    """Every instruction in instructions.s parses and writes back unchanged"""
    src = (REPO_ROOT / "tests/naive/x86_64/instructions.s").read_text()
    lines = [
        line.strip()
        for line in src.splitlines()
        if line.strip()
        and not line.strip().startswith("//")
        and not line.strip().endswith(":")
    ]
    assert len(lines) > 20
    for line in lines:
        assert _parse(line).write() == line, line


def test_operand_roles():
    """Inputs, outputs and in/outs follow AT&T operand order"""
    inst = _parse("xor %rbx, %rax")
    assert inst.args_in == ["rbx"]
    assert inst.args_in_out == ["rax"]

    inst = _parse("mov %rax, %rdx")
    assert inst.args_in == ["rax"]
    assert inst.args_out == ["rdx"]


def test_address_register_is_an_input():
    inst = _parse("mov 8(%rdi), %rax")
    assert inst.args_in == ["rdi"]
    assert inst.args_out == ["rax"]
    assert inst.addr == "rdi"

    inst = _parse("mov %rax, 16(%rsi)")
    assert set(inst.args_in) == {"rax", "rsi"}
    assert inst.args_out == []


def test_symbolic_registers_parse():
    inst = _parse("mov 8(%QW<ptr>), %QW<x>")
    assert inst.args_in == ["QW<ptr>"]
    assert inst.args_out == ["QW<x>"]
    assert inst.write() == "mov 8(%QW<ptr>), %QW<x>"

    # Symbolic names that look like register IDs stay symbolic
    inst = _parse("xor %QW<a>, %QW<sp>")
    assert inst.args_in == ["QW<a>"]
    assert inst.args_in_out == ["QW<sp>"]
    inst = _parse("pxor %XMM<0>, %XMM<t>")
    assert inst.args_in == ["XMM<0>"]


def test_wrong_register_size_rejected():
    """A 32-bit register does not match a 64-bit operand"""
    inst = _parse("add %ebx, %ecx")
    assert type(inst).__name__ == "add_dd"
    for line in ["mov %ebx, %rcx", "xor %eax, %rbx"]:
        try:
            _parse(line)
        except Exception:
            continue
        raise AssertionError(f"{line} should not parse")


def test_memory_offset_required_where_modelled():
    """movdqu/pxor/xor from memory are only modelled with an explicit offset; the
    offset-free form is rejected cleanly rather than parsed with an empty offset"""
    assert _parse("movdqu 0(%rsi), %xmm0").offset == "0"
    for line in ["movdqu (%rsi), %xmm0", "xor (%rdi), %rax"]:
        try:
            _parse(line)
        except ParsingException:
            continue
        raise AssertionError(f"{line} should not parse")


def test_push_pop_read_and_write_rsp():
    """push/pop implicitly update rsp, so stack accesses stay ordered around them"""
    push = _parse("push %rax")
    assert push.args_in == ["rax"]
    assert push.args_in_out == ["rsp"]
    assert push.args_in_out_restrictions == [["rsp"]]
    assert push.write() == "push %rax"

    pop = _parse("pop %rcx")
    assert pop.args_out == ["rcx"]
    assert pop.args_in_out == ["rsp"]

    graph = _graph(
        """
        push %rbx
        mov (%rsp), %rax
        """,
        outputs=["rax"],
    )
    push_node, load_node = graph.nodes
    rsp_idx = load_node.inst.args_in.index("rsp")
    assert load_node.src_in[rsp_idx].src is push_node


def test_memory_hint_tags():
    """reads=/writes= tags add hint pseudo-registers"""
    graph = _graph(
        """
        mov %rax, 0(%rdi) // @slothy:writes=buf
        mov 8(%rsi), %rbx // @slothy:reads=buf
        """,
        outputs=["rbx"],
    )
    store, load = graph.nodes
    assert "hint_buf" in store.inst.args_out
    assert "hint_buf" in load.inst.args_in
    hint_idx = load.inst.args_in.index("hint_buf")
    assert load.src_in[hint_idx].src is store


def test_symbolic_inputs_with_selftest_off():
    """Code that reads a symbolic register (here an address that is never written)
    can't be assembled for the selftest, so it is optimized with the selftest off"""
    slothy = Slothy(Arch, Target, logger=_logger())
    slothy.load_source_raw("start:\n        mov 8(%QW<p>), %rax\nend:\n")
    slothy.config.outputs = ["rax"]
    slothy.config.selftest = False
    slothy.optimize(start="start", end="end")
    lines = [ln.text.strip() for ln in slothy.source if ln.text.strip()]
    assert lines[1].startswith("mov 8(%") and lines[1].endswith(", %rax"), lines


def test_register_ids_round_trip():
    """Register -> ID -> register is the identity (rdi must not become rdx)"""
    rt = Arch.RegisterType
    to_reg = x86_64Instruction._to_reg
    for ty in [rt.GPR_H, rt.GPR_S, rt.GPR_D, rt.GPR_Q, rt.XMM, rt.YMM]:
        for reg in rt.list_registers(ty):
            assert to_reg(ty, rt.reg_to_id(reg)) == reg, reg
    assert to_reg(rt.GPR_Q, rt.reg_to_id("QW<a>")) == "QW<a>"


def test_xor_from_memory_fusion():
    """fusion_region splits xor-from-memory into a load and a register xor,
    keeping the base register"""
    slothy = Slothy(Arch, Target, logger=_logger())
    slothy.config.outputs = ["rax", "rbx"]
    slothy.load_source_raw("""start:
        xor 8(%rdi), %rax
        xor 16(%rbp), %rbx
end:
""")
    slothy.fusion_region("start", "end", ssa=False)
    lines = [
        line.text for line in slothy.source if line.text and not line.text.endswith(":")
    ]
    assert len(lines) == 4
    assert lines[0].startswith("mov 8(%rdi), %QW<aux_")
    assert lines[1].startswith("xor %QW<aux_") and lines[1].endswith(", %rax")
    assert lines[2].startswith("mov 16(%rbp), %QW<aux_")
    assert lines[3].endswith(", %rbx")


def test_branches_parse():
    """jz/jnz take a label and read only ZF (test writes SF, ZF and PF)"""
    for line, label in [("jnz loop", "loop"), ("jz .Lend", ".Lend"), ("jnz 1b", "1b")]:
        inst = _parse(line)
        assert inst.label == label
        assert inst.args_in == ["ZF"]
        assert inst.write() == line
    assert _parse("test $1, %rcx").args_out == ["SF", "ZF", "PF"]


def test_branch_loop_end_is_x86():
    loop = Arch.BranchLoop("loop")
    loop.additional_data = {"br_type": "nz"}
    assert list(loop.end({})) == ["jnz loop"]


def test_arch_loads_instructions_without_target():
    """Importing only the architecture makes all instruction classes available"""
    code = (
        "import slothy.targets.x86_64.x86_64 as a;"
        "from slothy.helper import SourceLine;"
        "print(type(a.Instruction.parser(SourceLine('pxor %xmm0, %xmm1'))[0]).__name__)"
    )
    res = subprocess.run(
        [sys.executable, "-c", code],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    assert res.stdout.strip() == "pxor_xx", res.stderr


def run_instruction_model_tests():
    test_all_instruction_forms_parse()
    test_operand_roles()
    test_address_register_is_an_input()
    test_symbolic_registers_parse()
    test_wrong_register_size_rejected()
    test_memory_offset_required_where_modelled()
    test_push_pop_read_and_write_rsp()
    test_memory_hint_tags()
    test_symbolic_inputs_with_selftest_off()
    test_register_ids_round_trip()
    test_xor_from_memory_fusion()
    test_branches_parse()
    test_branch_loop_end_is_x86()
    test_arch_loads_instructions_without_target()


if __name__ == "__main__":
    run_instruction_model_tests()

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

"""Unit tests for the x86_64 Intel <-> AT&T syntax translator"""

import logging
import os
import shutil
import subprocess
from pathlib import Path

from slothy import Slothy
from slothy.core.config import InvalidConfig
from slothy.helper import SourceLine
import slothy.targets.x86_64.x86_64 as Arch
import slothy.targets.x86_64.intel_atom as Target
import slothy.targets.x86_64.x86_translator as x86_translator
from slothy.targets.x86_64.x86_translator import Atat_Code, Code, Intel_Code

# Known-good pairs: SLOTHY-optimized and original Keccak rounds in AT&T, and their
# Intel translations as benchmarked with nanoBench (";"-separated, one line)
FIXTURES = Path(__file__).resolve().parent / "translator"

# Instruction forms in Intel syntax and their AT&T equivalents
FORMS = [
    ("add rax, rbx", "add %rbx, %rax"),
    ("add rax, 1", "add $1, %rax"),
    ("not rax", "not %rax"),
    ("rol rax", "rol %rax"),
    ("rol rax, 36", "rol $36, %rax"),
    ("mov rax, qword ptr [rdi]", "mov (%rdi), %rax"),
    ("mov qword ptr [rdi], rax", "mov %rax, (%rdi)"),
    ("mov rax, qword ptr [rdi+8]", "mov 8(%rdi), %rax"),
    ("mov qword ptr [rsp+160], r13", "mov %r13, 160(%rsp)"),
    ("mov rax, qword ptr [rdi-8]", "mov -8(%rdi), %rax"),
    ("xor r8, qword ptr [rdi+2*8]", "xor 2*8(%rdi), %r8"),
    ("xor r8, qword ptr [rdi+(3*8)]", "xor (3*8)(%rdi), %r8"),
    ("mov rax, qword ptr [rdi+rcx*8+16]", "mov 16(%rdi,%rcx,8), %rax"),
    ("pxor xmm1, xmm0", "pxor %xmm0, %xmm1"),
    ("movdqu xmm0, xmmword ptr [rdi+48]", "movdqu 48(%rdi), %xmm0"),
    ("pxor xmm0, xmmword ptr [rdi+64]", "pxor 64(%rdi), %xmm0"),
    ("mov eax, dword ptr [rdi+8]", "mov 8(%rdi), %eax"),
    ("mov byte ptr [rdi], bl", "mov %bl, (%rdi)"),
    ("jnz loop", "jnz loop"),
    ("ret", "ret"),
    ("nop", "nop"),
]


def _translate(cls, line, to):
    code = cls(text=[line])
    code.parse_source()
    getattr(code, to)()
    return code.write_code()[0]


def _att_normalized(lines):
    """AT&T lines as the translator writes them (size suffixes stripped)"""
    return [
        _translate(Atat_Code, line.strip(), "to_atat") for line in lines if line.strip()
    ]


def _fixture_pairs():
    pairs = sorted((FIXTURES / "att").glob("*.s"))
    assert len(pairs) == 8
    for att in pairs:
        intel = (FIXTURES / "intel" / att.name).read_text().strip()
        yield att.read_text().splitlines(), intel


def test_forms_intel_to_att():
    for intel, att in FORMS:
        assert _translate(Intel_Code, intel, "to_atat") == att, intel


def test_forms_att_to_intel():
    for intel, att in FORMS:
        assert _translate(Atat_Code, att, "to_intel") == intel, att


def test_forms_assemble():
    """Both sides of every form are accepted by the LLVM assembler"""
    if shutil.which("llvm-mc") is None:
        return
    forms = [(i, a) for i, a in FORMS if not i.startswith("j")]
    for prefix, lines in [
        (".intel_syntax noprefix\n", [i for i, _ in forms]),
        ("", [a for _, a in forms]),
    ]:
        res = subprocess.run(
            ["llvm-mc", "--triple=x86_64", "--filetype=obj", "-o", os.devnull],
            input=prefix + "\n".join(lines) + "\n",
            capture_output=True,
            text=True,
        )
        assert res.returncode == 0, res.stderr


def test_golden_att_to_intel():
    for att_lines, intel in _fixture_pairs():
        code = Atat_Code(text=[line.strip() for line in att_lines])
        code.parse_source()
        code.to_intel()
        got = "; ".join(line.text for line in code.lines if line.text is not None)
        assert got == intel


def test_golden_intel_to_att():
    for att_lines, intel in _fixture_pairs():
        code = Intel_Code(text=[x.strip() for x in intel.split(";")])
        code.parse_source()
        code.to_atat()
        got = [line.text for line in code.lines if line.text is not None]
        assert got == _att_normalized(att_lines)


def test_invalid_att_scale_rejected():
    """A scale without an index register is not a valid AT&T memory operand"""
    try:
        _translate(Atat_Code, "mov (%rdi,16), %rax", "to_intel")
    except Exception:
        return
    raise AssertionError("(%rdi,16) should not parse")


def test_syntax_detection():
    for line in ["rol rbx", "mov r12, 0x0", "xor rax, rbx"]:
        code = Code(text=[line])
        code.parse_source()
        assert type(code) is Intel_Code, line
    for line in ["rol %rbx", "mov $0x0, %r12", "jnz 1b"]:
        code = Code(text=[line])
        code.parse_source()
        assert type(code) is Atat_Code, line
    # Calling it on a syntax class uses that syntax
    code = Intel_Code(text=["jnz start"])
    code.parse_source()
    assert type(code) is Intel_Code


def test_to_native_keeps_metadata():
    src = SourceLine.read_multiline("""start:
    mov rax, qword ptr [rdi+8] // load // @slothy:reads=buf
    .p2align 4
    rol rax, 3
""")
    native = Intel_Code.to_native(src)
    assert [line.text for line in native] == [
        "start:",
        "mov 8(%rdi), %rax",
        ".p2align 4",
        "rol $3, %rax",
        "",
    ]
    assert native[1].tags == {"reads": "buf"}
    assert native[1].indentation == src[1].indentation
    back = Intel_Code.from_native(native)
    assert [line.text.strip() for line in back] == [line.text.strip() for line in src]


def test_syntax_config_validation():
    slothy = Slothy(Arch, Target)
    assert slothy.config.syntax is None
    slothy.config.syntax = Intel_Code
    try:
        slothy.config.syntax = "intel"
    except InvalidConfig:
        return
    raise AssertionError("invalid syntax object accepted")


def test_intel_input_produces_intel_output():
    logger = logging.getLogger("translator_test")
    logger.addHandler(logging.NullHandler())
    logger.propagate = False
    slothy = Slothy(Arch, Target, logger=logger, syntax=Intel_Code)
    slothy.load_source_raw("""start:
        mov rax, qword ptr [rdi]
        mov rbx, qword ptr [rdi+8]
        xor rax, rbx
        rol rax, 3
        mov qword ptr [rdi+16], rax
end:
""")
    slothy.config.variable_size = True
    slothy.optimize(start="start", end="end")
    lines = [
        line.text
        for line in slothy.source
        if line.text.strip() and not line.text.strip().endswith(":")
    ]
    assert len(lines) == 5
    for text in lines:
        assert "%" not in text and "$" not in text, text


def test_module_syntax_auto_detects():
    """syntax=x86_translator (as in the Slothy-for-Atom documentation) detects the
    syntax of the whole code and translates it to AT&T"""
    intel = SourceLine.read_multiline("xor rax, rbx\nrol rax, 3\n")
    assert [line.text for line in x86_translator.to_native(intel)] == [
        "xor %rbx, %rax",
        "rol $3, %rax",
        "",
    ]
    att = SourceLine.read_multiline("movq 8(%rdi), %rax\nxorq %rbx, %rax\n")
    assert [line.text for line in x86_translator.to_native(att)][:2] == [
        "mov 8(%rdi), %rax",
        "xor %rbx, %rax",
    ]
    assert x86_translator.from_native(att) is att
    # Optimizing with the module as syntax (the config is deep-copied on the way)
    slothy = Slothy(Arch, Target, syntax=x86_translator)
    assert slothy.config.syntax is x86_translator
    slothy.load_source_raw(
        "start:\n        mov rax, qword ptr [rdi+8]\n        xor rax, rbx\nend:\n"
    )
    slothy.config.outputs = ["rax"]
    slothy.optimize(start="start", end="end")
    assert any(line.text.strip().startswith("xor %") for line in slothy.source)
    assert slothy.config.copy().syntax is x86_translator


def run_translator_tests():
    test_forms_intel_to_att()
    test_forms_att_to_intel()
    test_forms_assemble()
    test_golden_att_to_intel()
    test_golden_intel_to_att()
    test_invalid_att_scale_rejected()
    test_syntax_detection()
    test_to_native_keeps_metadata()
    test_syntax_config_validation()
    test_module_syntax_auto_detects()
    test_intel_input_produces_intel_output()


if __name__ == "__main__":
    run_translator_tests()

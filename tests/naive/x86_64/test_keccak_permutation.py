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

"""Tests for the full Keccak-f[1600] permutation template and sweep script"""

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "examples/misc/x86_64"
TEMPLATES = REPO_ROOT / "examples/naive/x86_64/keccak"


def _load_script(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _round_lines(src):
    return [
        line.split()
        for line in src.splitlines()
        if line.strip().startswith("mKeccakRound") and "rp" in line
    ]


def test_render_full_permutation():
    perm = _load_script("keccak_permutation_ex_opts")
    src = perm.render_template(
        perm.template_path.read_text(), {"rounds": perm.render_rounds(24)}
    )
    assert "{" not in src
    rounds = _round_lines(src)
    assert len(rounds) == 24
    for r, words in enumerate(rounds):
        i_state, o_state, rc, last = [w.rstrip(",") for w in words[1:]]
        assert (i_state, o_state) == (
            ("rpState", "rpStack") if r % 2 == 0 else ("rpStack", "rpState")
        )
        assert rc == perm.KECCAK_RC[r]
        assert last == ("1" if r == 23 else "0")


def test_render_partial_permutation():
    perm = _load_script("keccak_permutation_ex_opts")
    rounds = _round_lines(perm.render_rounds(3))
    assert len(rounds) == 3
    assert rounds[-1][-1] == "1"


def test_round_macro_matches_round_template():
    """The permutation reuses the round macro unchanged"""

    def macro(path):
        text = path.read_text()
        start = text.index(".macro\tmKeccakRound")
        return text[start : text.index(".endm", start)]

    assert macro(TEMPLATES / "x86_mKeccakPermutation_template.s") == macro(
        TEMPLATES / "x86_mKeccakRound_template.s"
    )


def run_keccak_permutation_tests():
    test_render_full_permutation()
    test_render_partial_permutation()
    test_round_macro_matches_round_template()


if __name__ == "__main__":
    run_keccak_permutation_tests()

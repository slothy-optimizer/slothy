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

"""Measure inverse throughput and latency of single instruction forms with nanoBench.

The results of a Bonnell (Intel Atom) run are embedded in
tests/naive/x86_64/test_atom_model.py (``MEASURED``), which checks the Atom model
against them.

Usage:
    python3 examples/misc/x86_64/thrpt_lat.py
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from examples.misc.x86_64 import nanobench  # noqa: E402

ASM_INIT = "MOV RAX, R14; MOV RBX, R14; MOV RCX, R14; MOV RDX, R14;"


def test_single(asm):
    out, stderr = nanobench.run(asm, asm_init=ASM_INIT, unroll=500)

    if stderr is not None and stderr != "":
        print(f'Skipping line "{asm}", due to stderr output of "{stderr}"!')
        return None

    counters = nanobench.parse_counters(out)
    return counters["CORE_CYCLES"], counters["INST_RETIRED"]


byte_regs = ["AL", "BL", "CL", "DL"]
word_regs = ["AX", "BX", "CX", "DX"]
dblword_regs = ["EAX", "EBX", "ECX", "EDX"]
qdword_regs = ["RAX", "RBX", "RCX", "RDX"]
xmm_regs = [f"XMM{i}" for i in range(16)]
ymm_regs = [f"YMM{i}" for i in range(16)]


def n_regs(sz, n):
    if sz == "HW":
        return byte_regs[:n]
    elif sz == "SW":
        return word_regs[:n]
    elif sz == "DW":
        return dblword_regs[:n]
    elif sz == "QW":
        return qdword_regs[:n]
    elif sz == "X":
        return xmm_regs[:n]
    elif sz == "Y":
        return ymm_regs[:n]
    return None


def thruput_single(asm_temp, sz):
    n = len(re.findall(r"\{\d*\}", asm_temp))
    args = n_regs(sz, 2 * n)
    inst1 = asm_temp.format(*(args[:n]))
    inst2 = asm_temp.format(*(args[n:]))
    asm = inst1 + "; " + inst2

    cycles, insts = test_single(asm)

    thruput = cycles / insts

    print(f"inverse throughput = {thruput}")


def latency_single(asm_temp, sz):
    n = len(re.findall(r"\{\d*\}", asm_temp))
    args = n_regs(sz, n)
    inst1 = asm_temp.format(*args)
    if "ptr" not in asm_temp:
        inst2 = asm_temp.format(*args[::-1])
    else:
        print("latency not tested!")
        return
    asm = inst1 + "; " + inst2

    cycles, insts = test_single(asm)

    latency = cycles / insts

    print(f"latency = {latency}")


one_arg_temp = r"{mn} {0}"
two_arg_temp = r"{mn} {0}, {1}"
two_arg_with_imm_temp = r"{mn} {0}, 1"
two_arg_from_ptr_temp = r"{mn} {0}, {ptr_sz} ptr[{1}]"
two_arg_to_ptr_temp = r"{mn} {ptr_sz} ptr[{0}], {1}"
two_arg_imm_to_ptr_temp = r"{mn} {ptr_sz} ptr[{0}], 1"
two_arg_from_ptr_with_offset_temp = r"{mn} {0}, {ptr_sz} ptr[{1}+8]"
two_arg_to_ptr_with_offset_temp = r"{mn} {ptr_sz} ptr[{0}+8], {1}"
two_arg_imm_to_ptr_with_offset_temp = r"{mn} {ptr_sz} ptr[{0}+8], 1"

inst_dict = {
    "add": two_arg_temp.replace("{mn}", "ADD"),
    "add_with_imm": two_arg_with_imm_temp.replace("{mn}", "ADD"),
    "mov": two_arg_temp.replace("{mn}", "MOV"),
    "mov_with_imm": two_arg_with_imm_temp.replace("{mn}", "MOV"),
    "mov_from_ptr": two_arg_from_ptr_temp.replace("{mn}", "MOV"),
    "mov_to_ptr": two_arg_to_ptr_temp.replace("{mn}", "MOV"),
    "mov_imm_to_ptr": two_arg_imm_to_ptr_temp.replace("{mn}", "MOV"),
    "mov_from_ptr_with_offset": two_arg_from_ptr_with_offset_temp.replace(
        "{mn}", "MOV"
    ),
    "mov_to_ptr_with_offset": two_arg_to_ptr_with_offset_temp.replace("{mn}", "MOV"),
    "mov_imm_to_ptr_with_offset": two_arg_imm_to_ptr_with_offset_temp.replace(
        "{mn}", "MOV"
    ),
    "not": one_arg_temp.replace("{mn}", "NOT"),
    "or": two_arg_temp.replace("{mn}", "OR"),
    "pop": one_arg_temp.replace("{mn}", "POP"),
    "push": one_arg_temp.replace("{mn}", "PUSH"),
    "rol_with_imm": two_arg_with_imm_temp.replace("{mn}", "ROL"),
    "rol_with_implicit_shift": one_arg_temp.replace("{mn}", "ROL"),
    "shr_with_imm": two_arg_with_imm_temp.replace("{mn}", "SHR"),
    "sub_with_imm": two_arg_with_imm_temp.replace("{mn}", "SUB"),
    "xchg": two_arg_temp.replace("{mn}", "XCHG"),
    "xor_with_imm": two_arg_with_imm_temp.replace("{mn}", "XOR"),
    "xor": two_arg_temp.replace("{mn}", "XOR"),
    "xor_from_ptr_with_offset": two_arg_from_ptr_with_offset_temp.replace(
        "{mn}", "XOR"
    ),
    "xor_to_ptr_with_offset": two_arg_to_ptr_with_offset_temp.replace("{mn}", "XOR"),
    "xor_imm_to_ptr_with_offset": two_arg_imm_to_ptr_with_offset_temp.replace(
        "{mn}", "XOR"
    ),
}


def replace_ptr_sz(inst, sz):
    res = inst
    # I'm only using QW for now so just keep it simple
    if "{ptr_sz}" in inst:
        res = inst.replace("{ptr_sz}", "qword")
    return res


def thruputs():
    for name, inst in inst_dict.items():
        print(f"Inverse throughput for instruction {name}:")
        inst = replace_ptr_sz(inst, "QW")
        thruput_single(inst, "QW")

    return


def latencies():
    for name, inst in inst_dict.items():
        print(f"Latency for instruction {name}:")
        inst = replace_ptr_sz(inst, "QW")
        latency_single(inst, "QW")

    return


def main():

    thruputs()
    latencies()


if __name__ == "__main__":
    main()

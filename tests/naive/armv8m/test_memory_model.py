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

from dataclasses import dataclass
from types import SimpleNamespace

from slothy.targets.arm_v81m.arch_v81m import (
    add_shifted,
    bic_shifted,
    eor,
    eor_shifted,
    ldr,
    ldrd,
    log_and_shifted,
    orr_shifted,
    qrestore,
    qsave,
    str_reg,
    strd,
)
from slothy.targets.arm_v81m.cortex_m55r1 import (
    ExecutionUnit,
    add_further_constraints,
    get_inverse_throughput,
    get_latency,
    get_units,
    is_same_bank_scalar_store_load_hazard,
    m55_dtcm_bank,
    try_get_base_and_imm,
)


@dataclass(frozen=True)
class _CycleExpr:
    var: str
    offset: int


@dataclass(frozen=True)
class _NotEqual:
    lhs: str
    rhs: _CycleExpr


class _CycleVar:
    def __init__(self, name):
        self.name = name

    def __add__(self, offset):
        return _CycleExpr(self.name, offset)

    def __ne__(self, rhs):
        return _NotEqual(self.name, rhs)


class _Constraint:
    def __init__(self, expr):
        self.expr = expr
        self.enforced_by = None

    def OnlyEnforceIf(self, literal):
        self.enforced_by = literal
        return self


class _Node:
    def __init__(self, inst, idx):
        self.inst = inst
        self.id = idx
        self.is_locked = False
        self.cycle_start_var = _CycleVar(f"cycle{idx}")


class _FakeSlothy:
    def __init__(self, nodes, ignore_stack=False):
        constraints = SimpleNamespace(
            functional_only=False,
            st_ld_hazard=True,
            st_ld_hazard_ignore_scattergather=False,
            st_ld_hazard_ignore_stack=ignore_stack,
        )
        self.config = SimpleNamespace(constraints=constraints)
        self._model = SimpleNamespace(tree=SimpleNamespace(nodes=nodes))
        self.constraints = []
        self.logger = SimpleNamespace(debug=lambda *_args, **_kwargs: None)

    def get_inst_pairs(self, cond_fst=None, cond_snd=None, cond=None):
        if cond_fst is None:

            def cond_fst(_node):
                return True

        if cond_snd is None:

            def cond_snd(_node):
                return True

        if cond is None:

            def cond(_fst, _snd):
                return True

        fst = list(filter(cond_fst, self._model.tree.nodes))
        snd = list(filter(cond_snd, self._model.tree.nodes))
        for node_a in fst:
            for node_b in snd:
                if cond(node_a, node_b):
                    yield node_a, node_b

    def _NewConstant(self, value):
        return value

    def _NewBoolVar(self, _name):
        return "hazard"

    def _Add(self, expr):
        constraint = _Constraint(expr)
        self.constraints.append(constraint)
        return constraint


def _consumer():
    return eor.make("eor r4, r5, r6")


def _scalar_str_ldr_pair(base, store_imm=0, load_imm=16):
    parse_base = "r13" if base == "sp" else base
    store = str_reg.make(f"str r2, [{parse_base}, #{store_imm}]")
    load = ldr.make(f"ldr r3, [{parse_base}, #{load_imm}]")
    store.addr = base
    load.addr = base
    return store, load


def _run_hazard_model(store, load, ignore_stack=False):
    slothy = _FakeSlothy([_Node(store, 0), _Node(load, 1)], ignore_stack=ignore_stack)
    add_further_constraints(slothy)
    return slothy


def _assert_forbidden_st_ld_distance(slothy):
    assert len(slothy._model.st_ld_hazard_vars) == 1
    assert len(slothy.constraints) == 1
    assert slothy.constraints[0].expr == _NotEqual("cycle1", _CycleExpr("cycle0", 2))
    assert slothy.constraints[0].enforced_by is True


def _assert_no_st_ld_hazard(slothy):
    assert slothy._model.st_ld_hazard_vars == {}
    assert slothy.constraints == []


def test_ldrd_model():
    inst = ldrd.make("ldrd r0, r1, [r2, #16]")

    assert get_units(inst) == [ExecutionUnit.LOAD]
    assert get_inverse_throughput(inst) == 1
    assert get_latency(inst, 0, _consumer()) == 2


def test_strd_model():
    inst = strd.make("strd r0, r1, [r2, #16]")

    assert get_units(inst) == [ExecutionUnit.STORE]
    assert get_inverse_throughput(inst) == 1
    assert get_latency(inst, 0, _consumer()) == 1


def test_scalar_str_model():
    inst = str_reg.make("str r1, [r0, #116]")

    assert get_units(inst) == [ExecutionUnit.STORE]
    assert get_inverse_throughput(inst) == 1
    assert get_latency(inst, 0, _consumer()) == 1


def test_shifted_source_operand_needs_extra_cycle():
    producer = eor.make("eor r1, r2, r3")
    shifted_consumers = [
        add_shifted.make("add r4, r5, r1, ror #13"),
        eor_shifted.make("eor r4, r5, r1, ror #13"),
        orr_shifted.make("orr r4, r5, r1, ror #13"),
        log_and_shifted.make("and r4, r5, r1, ror #13"),
        bic_shifted.make("bic r4, r5, r1, ror #13"),
    ]

    for consumer in shifted_consumers:
        assert get_latency(producer, 0, consumer) == 2


def test_unshifted_source_operand_keeps_default_latency():
    producer = eor.make("eor r1, r2, r3")
    unshifted_consumers = [
        add_shifted.make("add r4, r1, r5, ror #13"),
        eor_shifted.make("eor r4, r1, r5, ror #13"),
        orr_shifted.make("orr r4, r1, r5, ror #13"),
        log_and_shifted.make("and r4, r1, r5, ror #13"),
        bic_shifted.make("bic r4, r1, r5, ror #13"),
    ]

    for consumer in unshifted_consumers:
        assert get_latency(producer, 0, consumer) == 1


def test_dtcm_bank_uses_address_bits_3_2():
    assert m55_dtcm_bank(0) == 0
    assert m55_dtcm_bank(4) == 1
    assert m55_dtcm_bank(8) == 2
    assert m55_dtcm_bank(12) == 3
    assert m55_dtcm_bank(16) == 0


def test_same_base_same_bank_scalar_str_ldr_adds_forbidden_distance():
    store, load = _scalar_str_ldr_pair("r0")

    assert try_get_base_and_imm(store) == ("r0", 0)
    assert try_get_base_and_imm(load) == ("r0", 16)
    assert is_same_bank_scalar_store_load_hazard(_Node(store, 0), _Node(load, 1))
    _assert_forbidden_st_ld_distance(_run_hazard_model(store, load))


def test_same_base_different_bank_scalar_str_ldr_has_no_model_hazard():
    store, load = _scalar_str_ldr_pair("r0", store_imm=0, load_imm=4)

    assert not is_same_bank_scalar_store_load_hazard(_Node(store, 0), _Node(load, 1))
    _assert_no_st_ld_hazard(_run_hazard_model(store, load))


def test_different_base_same_bank_scalar_str_ldr_has_no_model_hazard():
    store = str_reg.make("str r2, [r0, #0]")
    load = ldr.make("ldr r3, [r1, #16]")

    assert not is_same_bank_scalar_store_load_hazard(_Node(store, 0), _Node(load, 1))
    _assert_no_st_ld_hazard(_run_hazard_model(store, load))


def test_unknown_immediate_does_not_trigger_scalar_hazard():
    store, load = _scalar_str_ldr_pair("r0")
    store.pre_index = "unknown"

    assert try_get_base_and_imm(store) is None
    assert not is_same_bank_scalar_store_load_hazard(_Node(store, 0), _Node(load, 1))
    _assert_no_st_ld_hazard(_run_hazard_model(store, load))


def test_stack_ignore_is_pseudo_stack_only_for_scalar_str_ldr():
    for base in ["r13", "sp"]:
        store, load = _scalar_str_ldr_pair(base)

        assert is_same_bank_scalar_store_load_hazard(_Node(store, 0), _Node(load, 1))
        _assert_forbidden_st_ld_distance(
            _run_hazard_model(store, load, ignore_stack=True)
        )


def test_stack_ignore_suppresses_pseudo_stack_hazards():
    store = qsave.make("qsave QSTACK0, q0")
    load = qrestore.make("qrestore q1, QSTACK0")

    _assert_forbidden_st_ld_distance(_run_hazard_model(store, load))
    _assert_no_st_ld_hazard(_run_hazard_model(store, load, ignore_stack=True))


def run_memory_model_tests():
    test_ldrd_model()
    test_strd_model()
    test_scalar_str_model()
    test_shifted_source_operand_needs_extra_cycle()
    test_unshifted_source_operand_keeps_default_latency()
    test_dtcm_bank_uses_address_bits_3_2()
    test_same_base_same_bank_scalar_str_ldr_adds_forbidden_distance()
    test_same_base_different_bank_scalar_str_ldr_has_no_model_hazard()
    test_different_base_same_bank_scalar_str_ldr_has_no_model_hazard()
    test_unknown_immediate_does_not_trigger_scalar_hazard()
    test_stack_ignore_is_pseudo_stack_only_for_scalar_str_ldr()
    test_stack_ignore_suppresses_pseudo_stack_hazards()


if __name__ == "__main__":
    run_memory_model_tests()

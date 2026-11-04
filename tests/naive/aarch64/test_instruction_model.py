#
# Copyright (c) 2026 Aurivelle
# SPDX-License-Identifier: MIT
#

from slothy.helper import SourceLine
from slothy.targets.exceptions import UnknownInstruction
import slothy.targets.aarch64.aarch64_neon as Arch
import slothy.targets.aarch64.cortex_a72_frontend as Target

PARSER_CASES = {
    "neg v0.4s, v1.4s": Arch.vneg,
    "ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]": Arch.q_ld1_4,
    "ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64": (Arch.q_ld1_4_with_postinc),
    "ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], x1": (Arch.q_ld1_4_with_reg_postinc),
    "ld1 {v4.s}[1], [x2]": Arch.q_ld1_lane,
    "ld1 {v6.4s, v7.4s}, [x3], #32": Arch.q_ld1_2_with_postinc,
    "st1 {v0.4s}, [x0]": Arch.q_st1,
    "st1 {v1.s}[2], [x1], #4": Arch.q_st1_lane_with_postinc,
    "st1 {v2.4s, v3.4s}, [x2], #32": Arch.q_st1_2_with_postinc,
    "st1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x3]": Arch.q_st1_4,
    "stp q0, q1, [x4]": Arch.q_stp,
    "ldr w0, [x0]": Arch.w_ldr,
    "ldr w1, [x1, #12]": Arch.w_ldr_imm,
    "ldr w2, [x3], #4": Arch.w_ldr_with_postinc,
    "add w3, w4, #7": Arch.add_imm_w,
    "b.ne .Lagain": Arch.b_cond,
    "mov x5, xzr": Arch.mov_xzr,
    "cmp w6, #4": Arch.cmp_imm_w,
    "shsub v8.4s, v9.4s, v10.4s": Arch.vshsub,
    "sqrdmlah v11.4s, v12.4s, v13.4s": Arch.sqrdmlah,
    "bsl v14.16b, v15.16b, v16.16b": Arch.vbsl,
    "tbl v17.16b, {v18.16b, v19.16b, v20.16b, v21.16b}, v22.16b": (Arch.vtbl_4),
    "sxtl v23.8h, v24.8b": Arch.vsxtl,
    "sxtl2 v25.8h, v26.16b": Arch.vsxtl2,
    "str w7, [x5]": Arch.w_str,
    "str w8, [x6], #4": Arch.w_str_with_postinc,
    "stp w9, w10, [x7], #8": Arch.w_stp_with_postinc,
    "st3 {v27.4s-v29.4s}, [x8], #48": Arch.st3_range_with_inc,
}


def _parse(source):
    return Arch.Instruction.parser(SourceLine(source))[0]


def test_added_instruction_forms_parse_and_round_trip():
    for source, expected_class in PARSER_CASES.items():
        instruction = _parse(source)
        assert type(instruction) is expected_class
        assert type(_parse(instruction.write())) is expected_class


def test_a72_model_covers_supported_added_forms():
    for source in PARSER_CASES:
        instruction = _parse(source)
        if isinstance(instruction, Arch.sqrdmlah):
            continue
        Target.get_units(instruction)
        Target.get_inverse_throughput(instruction)
        Target.get_latency(instruction, 0, instruction)


def test_a72_swog_load_store_timings():
    # Arm Cortex-A72 Software Optimization Guide, A64 ASIMD load/store tables:
    # https://documentation-service.arm.com/static/5ed75eeeca06a95ce53f93c7
    expected = {
        "ld1 {v0.4s}, [x0]": (5, 1),
        "ld1 {v0.4s, v1.4s}, [x0]": (6, 2),
        "ld1 {v0.4s, v1.4s, v2.4s, v3.4s}, [x0]": (8, 4),
        "ld1 {v4.s}[1], [x2]": (8, 1),
        "ld1 {v4.d}[1], [x2]": (5, 1),
        "st1 {v0.4s}, [x0]": (2, 2),
        "st1 {v1.s}[2], [x1], #4": (3, 1),
        "st1 {v1.d}[1], [x1], #8": (1, 1),
        "st1 {v2.4s, v3.4s}, [x2], #32": (4, 4),
        "st1 {v4.4s, v5.4s, v6.4s, v7.4s}, [x3]": (8, 8),
        "cmp w6, #4": (1, 1),
    }

    for source, timing in expected.items():
        instruction = _parse(source)
        actual = (
            Target.get_latency(instruction, 0, instruction),
            Target.get_inverse_throughput(instruction),
        )
        assert actual == timing


def test_conditional_branch_is_tagged():
    instruction = _parse("b.ne .Lagain")
    assert instruction.source_line.tags["branch"] is True


def test_sqrdmlah_is_not_modelled_for_cortex_a72():
    # SQRDMLAH requires the Armv8.1-A RDM extension, which Cortex-A72 lacks.
    instruction = _parse("sqrdmlah v11.4s, v12.4s, v13.4s")
    try:
        Target.get_units(instruction)
    except UnknownInstruction:
        return
    raise AssertionError("SQRDMLAH must not be scheduled for Cortex-A72")


def run_instruction_model_tests():
    test_added_instruction_forms_parse_and_round_trip()
    test_a72_model_covers_supported_added_forms()
    test_a72_swog_load_store_timings()
    test_conditional_branch_is_tagged()
    test_sqrdmlah_is_not_modelled_for_cortex_a72()


if __name__ == "__main__":
    run_instruction_model_tests()

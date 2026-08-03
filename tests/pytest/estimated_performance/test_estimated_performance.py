#
# Copyright (c) SLOTHY contributors
# SPDX-License-Identifier: MIT
#

"""Estimated-performance regression tests.

Each case is a pair of files in ``cases``: an assembly snippet ``<name>.s`` and a
sidecar ``<name>.yml`` describing how to invoke SLOTHY and the cycle/stall
estimate it is expected to report for the optimized code. These are SLOTHY's own
estimates (``result.cycles`` / ``result.stalls``), not measured hardware numbers;
because they are the optimum of a minimization they are deterministic, so pinning
them turns a change in what SLOTHY believes it found into a test failure.

Run the tests with::

    python3 -m pytest tests/pytest

Print SLOTHY's current estimate for every case (handy when authoring or
refreshing a sidecar) with::

    PYTHONPATH=. python3 tests/pytest/estimated_performance/test_estimated_performance.py
"""

import logging
from pathlib import Path

import pytest
import yaml

from slothy import Slothy

import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.riscv.riscv as RISCV

import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.neoverse_n1_experimental as Target_NeoverseN1
import slothy.targets.aarch64.aarch64_big_experimental as Target_AArch64Big
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1Firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1Icestorm
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

# Maps the `target` name used in a sidecar to its (architecture, target) modules.
# The architecture is derived from the target, so sidecars only name the target.
TARGETS = {
    "cortex_m7": (Arch_Armv7M, Target_CortexM7),
    "cortex_m55r1": (Arch_Armv81M, Target_CortexM55r1),
    "cortex_m85r1": (Arch_Armv81M, Target_CortexM85r1),
    "cortex_a55": (AArch64_Neon, Target_CortexA55),
    "cortex_a72": (AArch64_Neon, Target_CortexA72),
    "neoverse_n1": (AArch64_Neon, Target_NeoverseN1),
    "aarch64_big": (AArch64_Neon, Target_AArch64Big),
    "apple_m1_firestorm": (AArch64_Neon, Target_AppleM1Firestorm),
    "apple_m1_icestorm": (AArch64_Neon, Target_AppleM1Icestorm),
    "xuantie_c908": (RISCV, Target_XuanTieC908),
}

CASES_DIR = Path(__file__).resolve().parent / "cases"


def _load_case(path):
    """Load a sidecar YAML file into a dict."""
    with open(path, "r", encoding="utf8") as f:
        return yaml.safe_load(f)


def _apply_config(config, overrides):
    """Apply a mapping of (possibly dotted) keys onto a slothy.config object."""
    for dotted, value in overrides.items():
        obj = config
        *parents, leaf = dotted.split(".")
        for name in parents:
            obj = getattr(obj, name)
        setattr(obj, leaf, value)


def _run(case_path, target_name):
    """Run SLOTHY for one (case, target) pair and return slothy.last_result."""
    if target_name not in TARGETS:
        raise KeyError(
            f"Unknown target '{target_name}' in {case_path.name}; "
            f"known targets: {sorted(TARGETS)}"
        )
    arch, target = TARGETS[target_name]

    case = _load_case(case_path)
    source = case.get("source") or f"{case_path.stem}.s"
    source_path = case_path.parent / source

    logger = logging.getLogger(f"estperf.{case_path.stem}.{target_name}")
    logger.setLevel(logging.WARNING)

    slothy = Slothy(arch, target, logger=logger)
    slothy.load_source_from_file(str(source_path))

    # variable_size lets SLOTHY minimize stalls; a case may override it.
    cfg = {"variable_size": True}
    cfg.update(case.get("config") or {})
    _apply_config(slothy.config, cfg)

    # On Apple M1, x18 is reserved by the platform ABI.
    if "m1" in target_name:
        slothy.config.reserved_regs = ["x18"]

    opt = case.get("optimize") or {}
    call = opt.get("call", "optimize")
    if call == "optimize":
        slothy.optimize(start=opt.get("start"), end=opt.get("end"))
    elif call == "optimize_loop":
        slothy.optimize_loop(opt.get("loop"))
    else:
        raise ValueError(f"Unknown optimize.call '{call}' in {case_path.name}")

    return slothy.last_result


def _discover():
    """Discover (case_path, target_name) pairs from the sidecars in CASES_DIR."""
    params, ids = [], []
    for path in sorted(CASES_DIR.glob("*.yml")):
        case = _load_case(path)
        for target_name in case.get("expected") or {}:
            params.append((path, target_name))
            ids.append(f"{path.stem}-{target_name}")
    return params, ids


_PARAMS, _IDS = _discover()


@pytest.mark.parametrize("case_path,target_name", _PARAMS, ids=_IDS)
def test_estimated_performance(case_path, target_name):
    """SLOTHY's estimate for the optimized code matches the pinned values."""
    expected = _load_case(case_path)["expected"][target_name]
    result = _run(case_path, target_name)
    assert result is not None, "optimization did not expose a result"

    label = f"{case_path.stem}[{target_name}]"

    # A case may set `match: max` to assert "no worse than" instead of equality,
    # e.g. for a large case that only solves to a bound rather than the optimum.
    if expected.get("match") == "max":
        assert result.cycles <= expected["cycles"], (
            f"{label}: expected <= {expected['cycles']} cycles, "
            f"SLOTHY estimated {result.cycles}"
        )
        return

    assert result.cycles == expected["cycles"], (
        f"{label}: expected {expected['cycles']} cycles, "
        f"SLOTHY estimated {result.cycles}"
    )
    if "stalls" in expected:
        assert result.stalls == expected["stalls"], (
            f"{label}: expected {expected['stalls']} stalls, "
            f"SLOTHY estimated {result.stalls}"
        )


def _print_estimates():
    """Print SLOTHY's current estimate for every (case, target) pair."""
    params, _ = _discover()
    for case_path, target_name in params:
        result = _run(case_path, target_name)
        bound = getattr(result, "cycles_bound", None)
        optimal = bound is not None and result.cycles == bound
        print(
            f"{case_path.stem}-{target_name}: "
            f"cycles={result.cycles} stalls={result.stalls} optimal={optimal}"
        )


if __name__ == "__main__":
    _print_estimates()

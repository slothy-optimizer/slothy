#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
# Copyright (c) 2025 Amin Abdulrahman
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
# Author: Amin Abdulrahman <amin@abdulrahman.de>
#

import argparse
import os
import time

from common.OptimizationRunner import OptimizationRunnerException

import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.aarch64_big_experimental as Target_AArch64Big
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

##########################################################################################

# from examples.naive.aarch64.dilithium._example import ntt_dilithium_123_45678
from examples.naive.aarch64.kyber._example import ntt_kyber_123_4567
from examples.naive.aarch64.keccak._example import neon_keccak_x1_no_symbolic

from examples.naive.armv7m.dilithium._example import ntt_dilithium
from examples.naive.armv7m.keccak._example import Keccak
from examples.naive.armv7m.kyber._example import ntt_kyber

from examples.naive.armv8m.kyber._example import ntt_kyber_1_23_45_67
from examples.naive.armv8m.dilithium._example import ntt_dilithium_12_34_56_78


def main():
    regression_tests = (
        neon_keccak_x1_no_symbolic(),  # aarch64 spilling
        # TODO: get this to work in CI
        # ntt_dilithium_123_45678(),  # aarch64 NEON
        ntt_kyber_123_4567(),  # aarch64 NEON
        Keccak(var="xkcp"),  # armv7m
        ntt_dilithium(),  # armv7m
        ntt_kyber(),  # armv7m
        ntt_kyber_1_23_45_67(),  # armv8m
        ntt_dilithium_12_34_56_78(),  # armv8m
    )

    all_regression_test_names = [e.name for e in regression_tests]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--regression_tests",
        type=str,
        default="all",
        help=f"The list of regression_tests to be run, comma-separated list from "
        f"{all_regression_test_names}. "
        f"Format: {{name}}_{{variant}}_{{target}}, e.g., "
        "ntt_kyber_123_4567_scalar_load_a55",
    )
    parser.add_argument("--dry-run", default=False, action="store_true")
    parser.add_argument("--debug", default=False, action="store_true")
    parser.add_argument("--silent", default=False, action="store_true")
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=0)
    parser.add_argument("--debug-logfile", type=str, default=None)
    parser.add_argument("--log-model", default=False, action="store_true")
    parser.add_argument("--log-model-dir", type=str, default="models")
    parser.add_argument(
        "--only-target",
        type=str,
        choices=[
            Target_CortexM7.__name__,
            Target_CortexM55r1.__name__,
            Target_CortexM85r1.__name__,
            Target_CortexA55.__name__,
            Target_CortexA72.__name__,
            Target_AppleM1_firestorm.__name__,
            Target_AppleM1_icestorm.__name__,
            Target_AArch64Big.__name__,
        ],
    )
    args = parser.parse_args()
    if args.regression_tests != "all":
        todo = args.regression_tests.split(",")
    else:
        todo = all_regression_test_names
    iterations = args.iterations

    def run_reg_test(name, **kwargs):
        ex = None
        for e in regression_tests:
            if e.name == name:
                ex = e
                break
        if ex is None:
            raise OptimizationRunnerException(f"Could not find regression test {name}")
        start_time = time.time()
        for _ in range(iterations):
            ex.run(**kwargs)
        end_time = time.time()

        avg_time = (end_time - start_time) / iterations

        return e.name, avg_time

    reg_res = {}

    for e in todo:
        n, t = run_reg_test(
            e,
            debug=args.debug,
            dry_run=args.dry_run,
            silent=args.silent,
            log_model=args.log_model,
            debug_logfile=args.debug_logfile,
            log_model_dir=args.log_model_dir,
            timeout=args.timeout,
            only_target=args.only_target,
        )
        reg_res[n] = t

    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    with open(summary_file, "w") as f:
        s = ""
        s += "# Regression Test Result\n"
        for k, v in reg_res.items():
            s += f"{k}: {v}\n"
        f.write(s)


if __name__ == "__main__":
    main()

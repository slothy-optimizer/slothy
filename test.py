#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
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

from common.OptimizationRunner import OptimizationRunnerException

import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.aarch64_big_experimental as Target_AArch64Big
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

import slothy.targets.otbn.otbn_uarch as Target_OTBN


from tests.naive.armv7m._test import (
    test_instances as test_instances_armv7m,
)

from tests.naive.armv8m._test import (
    test_instances as test_instances_armv8m,
)

from tests.naive.aarch64._test import (
    test_instances as test_instances_aarch64,
)

from tests.naive.otbn._test import test_instances as test_instances_otbn


def main():
    tests = (
        test_instances_armv7m
        + test_instances_armv8m
        + test_instances_aarch64
        + test_instances_otbn
    )

    all_test_names = [e.name for e in tests]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "--tests",
        type=str,
        default="all",
        help=f"The list of tests to be run, comma-separated list from "
        f"{all_test_names}. "
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
            Target_OTBN.__name__,
        ],
    )
    args = parser.parse_args()
    if args.tests != "all":
        todo = args.tests.split(",")
    else:
        todo = all_test_names
    iterations = args.iterations

    def run_test(name, **kwargs):
        t = None
        for e in tests:
            if e.name == name:
                t = e
                break
        if t is None:
            raise OptimizationRunnerException(f"Could not find test {name}")
        t.run(**kwargs)

    for e in todo:
        for _ in range(iterations):
            run_test(
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


if __name__ == "__main__":
    main()

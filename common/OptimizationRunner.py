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
# Author: Hanno Becker <hannobecker@posteo.de>
#

import logging
import sys
from pathlib import Path

from slothy import Slothy

import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.neoverse_n1_experimental as Target_NeoverseN1
import slothy.targets.aarch64.aarch64_big_experimental as Target_AArch64Big
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

import slothy.targets.riscv.riscv as RISCV
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

target_label_dict = {
    Target_CortexA55: "a55",
    Target_CortexA72: "a72",
    Target_NeoverseN1: "neoverse_n1",
    Target_CortexM7: "m7",
    Target_CortexM55r1: "m55",
    Target_CortexM85r1: "m85",
    Target_AppleM1_firestorm: "m1_firestorm",
    Target_AppleM1_icestorm: "m1_icestorm",
    Target_AArch64Big: "aarch64_big",
    Target_XuanTieC908: "c908",
}

arch_label_dict = {
    Arch_Armv7M: "armv7m",
    Arch_Armv81M: "armv8m",
    AArch64_Neon: "aarch64",
    RISCV: "riscv",
}


class OptimizationRunnerException(Exception):
    """Exception thrown when an example goes wrong"""


class OptimizationRunner:
    """Common boilerplate for SLOTHY examples"""

    def __init__(
        self,
        infile,
        name=None,
        funcname=None,
        suffix="opt",
        rename=False,
        outfile="",
        arch=Arch_Armv81M,
        target=Target_CortexM55r1,
        timeout=None,
        subfolder="",
        base_dir="examples",
        outfile_full=False,
        var="",
        **kwargs,
    ):
        if name is None:
            name = infile

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        self.arch = arch
        self.target = target
        self.funcname = funcname
        self.infile = infile
        self.suffix = suffix
        if outfile_full is True:
            self.outfile = outfile
        else:
            if outfile == "":
                self.outfile = (
                    f"{infile}_{self.suffix}_{target_label_dict[self.target]}"
                )
            else:
                self.outfile = (
                    f"{outfile}_{self.suffix}_{target_label_dict[self.target]}"
                )
        if funcname is None:
            self.funcname = self.infile
        subfolder = arch_label_dict[self.arch] + "/" + subfolder
        self.infile_full = f"{base_dir}/naive/{subfolder}{self.infile}.s"
        if outfile_full is False:
            self.outfile_full = f"{base_dir}/opt/{subfolder}{self.outfile}.s"
        else:
            self.outfile_full = self.outfile
        self.name = name
        self.rename = rename
        self.timeout = timeout
        self.extra_args = kwargs
        self.target_reserved = ""

    # By default, optimize the whole file

    def core(self, slothy):
        slothy.optimize()

    def run(
        self,
        debug=False,
        log_model=False,
        log_model_dir="models",
        dry_run=False,
        silent=False,
        timeout=0,
        debug_logfile=None,
        only_target=None,
    ):

        if dry_run is True:
            annotation = " (dry run only)"
        else:
            annotation = ""

        print(f"* Example: {self.name}{annotation}...")

        # skip eaxmples for all but the target that was asked for
        if only_target is not None and self.target.__name__ != only_target:
            return

        handlers = []

        h_err = logging.StreamHandler(sys.stderr)
        h_err.setLevel(logging.WARNING)
        handlers.append(h_err)

        if silent is False:
            h_info = logging.StreamHandler(sys.stdout)
            h_info.setLevel(logging.DEBUG)
            h_info.addFilter(lambda r: r.levelno == logging.INFO)
            handlers.append(h_info)

        if debug is True:
            h_verbose = logging.StreamHandler(sys.stdout)
            h_verbose.setLevel(logging.DEBUG)
            h_verbose.addFilter(lambda r: r.levelno < logging.INFO)
            handlers.append(h_verbose)

        if debug_logfile is not None:
            h_file = logging.FileHandler(debug_logfile)
            h_file.setLevel(logging.DEBUG)
            handlers.append(h_file)

        if debug is True or debug_logfile is not None:
            base_level = logging.DEBUG
        else:
            base_level = logging.INFO

        logging.basicConfig(
            level=base_level,
            handlers=handlers,
        )
        logger = logging.getLogger(self.name)

        slothy = Slothy(self.arch, self.target, logger=logger)
        slothy.load_source_from_file(self.infile_full)

        if timeout != 0:
            slothy.config.timeout = timeout
        elif self.timeout is not None:
            slothy.config.timeout = self.timeout

        if dry_run is True:
            slothy.config.constraints.functional_only = True
            slothy.config.constraints.allow_reordering = False
            slothy.config.constraints.allow_renaming = False
            slothy.config.variable_size = True

        if log_model is True:
            slothy.config.log_model_dir = log_model_dir
            slothy.config.log_model = self.name

        # On Apple M1, we must not use x18
        if "m1" in target_label_dict[self.target]:
            self.target_reserved = ["x18"]

        self.core(slothy, *self.extra_args)

        if self.rename:
            slothy.rename_function(
                self.funcname,
                f"{self.funcname}_{self.suffix}_{target_label_dict[self.target]}",
            )

        if dry_run is False:
            out_dir = Path(self.outfile_full).parent
            out_dir.mkdir(parents=True, exist_ok=True)
            slothy.write_source_to_file(self.outfile_full)

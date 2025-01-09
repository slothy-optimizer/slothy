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

import argparse
import logging
import sys

from slothy import Slothy, Config

import slothy.targets.arm_v7m.arch_v7m as Arch_Armv7M
import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v7m.cortex_m7 as Target_CortexM7
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

target_label_dict = {Target_CortexA55: "a55",
                     Target_CortexA72: "a72",
                     Target_CortexM7: "m7",
                     Target_CortexM55r1: "m55",
                     Target_CortexM85r1: "m85",
                     Target_AppleM1_firestorm: "m1_firestorm",
                     Target_AppleM1_icestorm: "m1_icestorm"}


class ExampleException(Exception):
    """Exception thrown when an example goes wrong"""


class Example():
    """Common boilerplate for SLOTHY examples"""

    def __init__(self, infile, name=None, funcname=None, suffix="opt",
                 rename=False, outfile="", arch=Arch_Armv81M, target=Target_CortexM55r1,
                 timeout=None, **kwargs):
        if name is None:
            name = infile

        self.arch = arch
        self.target = target
        self.funcname = funcname
        self.infile = infile
        self.suffix = suffix
        if outfile == "":
            self.outfile = f"{infile}_{self.suffix}_{target_label_dict[self.target]}"
        else:
            self.outfile = f"{outfile}_{self.suffix}_{target_label_dict[self.target]}"
        if funcname is None:
            self.funcname = self.infile
        subfolder = ""
        if self.arch == AArch64_Neon:
            subfolder = "aarch64/"
        elif self.arch == Arch_Armv7M:
            subfolder = "armv7m/"
        self.infile_full = f"examples/naive/{subfolder}{self.infile}.s"
        self.outfile_full = f"examples/opt/{subfolder}{self.outfile}.s"
        self.name = name
        self.rename = rename
        self.timeout = timeout
        self.extra_args = kwargs
        self.target_reserved = ""
    # By default, optimize the whole file

    def core(self, slothy):
        slothy.optimize()

    def run(self, debug=False, log_model=False, log_model_dir="models", dry_run=False, silent=False, timeout=0, debug_logfile=None, only_target=None):

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
            level = base_level,
            handlers = handlers,
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
                self.funcname, f"{self.funcname}_{self.suffix}_{target_label_dict[self.target]}")

        if dry_run is False:
            slothy.write_source_to_file(self.outfile_full)

class Example0(Example):
    def __init__(self):
        super().__init__("simple0")


class Example1(Example):
    def __init__(self):
        super().__init__("simple1")


class Example2(Example):
    def __init__(self):
        super().__init__("simple0_loop")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints["const"] = Arch_Armv81M.RegisterType.GPR
        slothy.optimize_loop("start")


class Example3(Example):
    def __init__(self):
        super().__init__("simple1_loop")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("start")

class LoopLe(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "loop_le"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.optimize_loop("start")

class AArch64LoopSubs(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_loop_subs"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.optimize_loop("start")

class CRT(Example):
    def __init__(self):
        super().__init__("crt")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.selfcheck = True
        # Double the loop body to create more interleaving opportunities
        # Basically a tradeoff of code-size vs performance
        slothy.config.sw_pipelining.unroll = 2
        slothy.config.typing_hints = {
            "const_prshift": Arch_Armv81M.RegisterType.GPR,
            "const_shift9": Arch_Armv81M.RegisterType.GPR,
            "p_inv_mod_q": Arch_Armv81M.RegisterType.GPR,
            "p_inv_mod_q_tw": Arch_Armv81M.RegisterType.GPR,
            "mod_p": Arch_Armv81M.RegisterType.GPR,
            "mod_p_tw": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize()


class ntt_n256_l6_s32(Example):
    def __init__(self, var):
        super().__init__(f"ntt_n256_l6_s32_{var}")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {r: Arch_Armv81M.RegisterType.GPR for r in
                                      ["root0",         "root1",         "root2",
                                       "root0_twisted", "root1_twisted", "root2_twisted"]}
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")


class ntt_n256_l8_s32(Example):
    def __init__(self, var):
        super().__init__(f"ntt_n256_l8_s32_{var}")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer78_loop")


class intt_n256_l6_s32(Example):
    def __init__(self, var):
        super().__init__(f"intt_n256_l6_s32_{var}")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")


class intt_n256_l8_s32(Example):
    def __init__(self, var):
        super().__init__(f"intt_n256_l8_s32_{var}")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer78_loop")


class ntt_kyber_1_23_45_67(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1, timeout=None):
        name = "ntt_kyber_1_23_45_67"
        infile = name
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)
        self.var = var
        self.timeout = timeout
    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer1_loop")
        slothy.optimize_loop("layer23_loop")
        slothy.optimize_loop("layer45_loop")
        slothy.config.constraints.st_ld_hazard = False
        if self.timeout is not None:
            slothy.config.timeout = self.timeout
        if "no_trans" in self.var:
            slothy.config.constraints.st_ld_hazard = True
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer67_loop")


class ntt_kyber_1(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_1"
        infile = "ntt_kyber_1_23_45_67"

        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer1_loop")


class ntt_kyber_23(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_23"
        infile = "ntt_kyber_1_23_45_67"

        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer23_loop")


class ntt_kyber_45(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_45"
        infile = "ntt_kyber_1_23_45_67"

        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer45_loop")


class ntt_kyber_67(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_67"
        infile = "ntt_kyber_1_23_45_67"

        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.constraints.st_ld_hazard = False
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer67_loop")


class ntt_kyber_12_345_67(Example):
    def __init__(self, cross_loops_optim=False, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        infile = "ntt_kyber_12_345_67"
        if cross_loops_optim:
            name = "ntt_kyber_12_345_67_speed"
            suffix = "opt_speed"
        else:
            name = "ntt_kyber_12_345_67_size"
            suffix = "opt_size"
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        self.var = var
        super().__init__(infile, name=name,
                         suffix=suffix, rename=True, arch=arch, target=target)
        self.cross_loops_optim = cross_loops_optim

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop(
            "layer12_loop", postamble_label="layer12_loop_end")
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.locked_registers = set([f"QSTACK{i}" for i in [4, 5, 6]] +
                                             ["STACK0"])
        if not self.cross_loops_optim:
            if "no_trans" not in self.var and "trans" in self.var:
                slothy.config.constraints.st_ld_hazard = False  # optional, if it takes too long
            slothy.config.sw_pipelining.enabled = False
            slothy.optimize_loop("layer345_loop")
        else:
            if "no_trans" not in self.var and "trans" in self.var:
                slothy.config.constraints.st_ld_hazard = False  # optional, if it takes too long
            slothy.config.sw_pipelining.enabled = True
            slothy.config.sw_pipelining.halving_heuristic = True
            slothy.config.sw_pipelining.halving_heuristic_periodic = True
            slothy.optimize_loop(
                "layer345_loop", postamble_label="layer345_loop_end")
            layer345_deps = slothy.last_result.kernel_input_output.copy()

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.sw_pipelining.halving_heuristic_periodic = True
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer67_loop")
        layer67_deps = slothy.last_result.kernel_input_output.copy()

        if self.cross_loops_optim:
            slothy.config.inputs_are_outputs = False
            slothy.config.constraints.st_ld_hazard = True
            slothy.config.sw_pipelining.enabled = False
            slothy.config.outputs = layer345_deps + ["r14"]
            slothy.optimize(start="layer12_loop_end", end="layer345_loop")
            slothy.config.outputs = layer67_deps + ["r14"]
            slothy.optimize(start="layer345_loop_end", end="layer67_loop")


class ntt_kyber_12(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_12"
        infile = "ntt_kyber_12_345_67"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop(
            "layer12_loop", postamble_label="layer12_loop_end")


class ntt_kyber_345(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_kyber_345"
        infile = "ntt_kyber_12_345_67"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.locked_registers = set([f"QSTACK{i}" for i in [4, 5, 6]] +
                                             ["STACK0"])
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("layer345_loop")


class ntt_kyber_l345_symbolic(Example):
    def __init__(self):
        super().__init__("ntt_kyber_layer345_symbolic")

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.sw_pipelining.halving_heuristic_periodic = True
        slothy.optimize_loop("layer345_loop")

class AArch64Example0(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.constraints.stalls_first_attempt=32
        slothy.optimize()

class AArch64Example0Equ(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_equ"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.constraints.stalls_first_attempt=32
        slothy.optimize(start="start", end="end")


class AArch64Example1(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_macros"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.constraints.stalls_first_attempt=32
        slothy.optimize(start="start", end="end")


class AArch64Example2(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_simple0_loop"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.constraints.stalls_first_attempt=32
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("start")

class AArch64Split0(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_split0"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.allow_useless_instructions = True
        slothy.fusion_region("start", "end", ssa=False)
class Armv7mExample0(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "armv7m_simple0"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.inputs_are_outputs = True
        slothy.fusion_region("start", "end", ssa=False)
        slothy.optimize(start="start", end="end")
        

class Armv7mExample0Func(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "armv7m_simple0_func"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.inputs_are_outputs = True
        slothy.optimize(start="start", end="end")
        slothy.global_selftest("my_func", {"r0": 1024 })

class Armv7mLoopSubs(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_subs"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.SubsLoop)
        slothy.config.sw_pipelining.enabled = True
        slothy.config.outputs = ["r0", "r1", "r2", "r5", "flags"]
        slothy.optimize_loop("start2", forced_loop_type=Arch_Armv7M.BranchLoop)

class Armv7mLoopCmp(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_cmp"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.outputs = ["r6"]
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.CmpLoop)

class Armv7mLoopVmovCmp(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_vmov_cmp"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.outputs = ["r6"]
        slothy.optimize_loop("start")
        
class Armv7mLoopVmovCmpForced(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7):
        name = "loop_vmov_cmp_forced"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.variable_size=True
        slothy.config.outputs = ["r5", "r6"]
        slothy.optimize_loop("start", forced_loop_type=Arch_Armv7M.CmpLoop)

class AArch64IfElse(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "aarch64_ifelse"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.optimize()

class ntt_kyber_123_4567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = "ntt_kyber_123_4567"
        infile = name

        self.var = var
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.variable_size = True
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.optimize_loop("layer123_start")
        slothy.optimize_loop("layer4567_start")
        # Build + emulate entire function to test that behaviour has not changed
        if self.var == "":
            slothy.global_selftest("ntt_kyber_123_4567",
                                   {"x0": 1024, "x1": 1024, "x3": 1024, "x4": 1024, "x5": 1024})

class intt_kyber_123_4567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = "intt_kyber_123_4567"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.variable_size = True
        slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.optimize_loop("layer4567_start")
        slothy.optimize_loop("layer123_start")


class ntt_kyber_123(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_kyber_123"
        infile = "ntt_kyber_123_4567"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer123_start")


class ntt_kyber_4567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_kyber_4567"
        infile = "ntt_kyber_123_4567"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer4567_start")


class ntt_kyber_1234_567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None):
        name = "ntt_kyber_1234_567"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        conf = slothy.config.copy()

        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.variable_size = True
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.split_heuristic_repeat = 4
        slothy.config.constraints.stalls_first_attempt = 40
        slothy.config.max_solutions = 64

        slothy.optimize_loop("layer1234_start")

        # layer567 is small enough for SW pipelining without heuristics
        slothy.config = conf.copy()
        slothy.config.timeout = self.timeout
        # Increase the timeout when not using heuristics
        if self.timeout is not None:
            slothy.config.timeout = self.timeout * 12
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.variable_size = True
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 64

        slothy.optimize_loop("layer567_start")


class ntt_kyber_1234(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "ntt_kyber_1234"
        infile = "ntt_kyber_1234_567"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved

        slothy.optimize_loop("layer1234_start")


class ntt_kyber_567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None):
        name = "ntt_kyber_567"
        infile = "ntt_kyber_1234_567"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        # layer567 is small enough for SW pipelining without heuristics
        slothy.config.timeout = self.timeout
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved

        slothy.optimize_loop("layer567_start")


class intt_kyber_1_23_45_67(Example):
    def __init__(self):
        super().__init__("intt_kyber_1_23_45_67", rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer1_loop")
        slothy.optimize_loop("layer23_loop")
        slothy.optimize_loop("layer45_loop")
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer67_loop")


class ntt_dilithium_12_34_56_78(Example):
    def __init__(self, var="", target=Target_CortexM55r1, arch=Arch_Armv81M):
        infile = "ntt_dilithium_12_34_56_78"
        name = infile
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)
        self.var = var

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
            "const1": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop(
            "layer56_loop", postamble_label="layer56_loop_end")
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.typing_hints = {}
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer78_loop")
        # Optimize seams between loops
        # Make sure we preserve the inputs to the loop body
        slothy.config.outputs = slothy.last_result.kernel_input_output + \
            ["r14"]
        slothy.config.constraints.st_ld_hazard = True
        slothy.config.sw_pipelining.enabled = False
        slothy.optimize(start="layer56_loop_end", end="layer78_loop")


class ntt_dilithium_12(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_dilithium_12"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
            "const1": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer12_loop")


class ntt_dilithium_34(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_dilithium_34"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
            "const1": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer34_loop")


class ntt_dilithium_56(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_dilithium_56"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
            "const1": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer56_loop")


class ntt_dilithium_78(Example):
    def __init__(self, arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "ntt_dilithium_78"
        infile = "ntt_dilithium_12_34_56_78"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name, arch=arch, target=target, rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {}
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False

        slothy.optimize_loop("layer78_loop")


class ntt_dilithium_123_456_78(Example):
    def __init__(self, cross_loops_optim=False, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        infile = "ntt_dilithium_123_456_78"
        if cross_loops_optim:
            name = "ntt_dilithium_123_456_78_speed"
            suffix = "opt_speed"
        else:
            name = "ntt_dilithium_123_456_78_size"
            suffix = "opt_size"
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name,
                         suffix=suffix, arch=arch, target=target, rename=True)
        self.cross_loops_optim = cross_loops_optim
        self.var = var

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root3": Arch_Armv81M.RegisterType.GPR,
            "root5": Arch_Armv81M.RegisterType.GPR,
            "root6": Arch_Armv81M.RegisterType.GPR,
            "rtmp": Arch_Armv81M.RegisterType.GPR,
            "rtmp_tw": Arch_Armv81M.RegisterType.GPR,
            "root2_tw": Arch_Armv81M.RegisterType.GPR,
            "root3_tw": Arch_Armv81M.RegisterType.GPR,
            "root5_tw": Arch_Armv81M.RegisterType.GPR,
            "root6_tw": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.locked_registers = set([f"QSTACK{i}" for i in [4, 5, 6]] +
                                             [f"ROOT{i}_STACK" for i in [0, 1, 4]] + ["RPTR_STACK"])
        if self.var != "" or ("speed" in self.name and self.target == Target_CortexM85r1):
            slothy.config.constraints.st_ld_hazard = False  # optional, if it takes too long
        if not self.cross_loops_optim:
            slothy.config.sw_pipelining.enabled = False
            slothy.optimize_loop("layer123_loop")
            slothy.optimize_loop("layer456_loop")
        else:
            slothy.config.sw_pipelining.enabled = True
            slothy.config.sw_pipelining.halving_heuristic = True
            slothy.config.sw_pipelining.halving_heuristic_periodic = True
            slothy.optimize_loop(
                "layer123_loop", postamble_label="layer123_loop_end")
            slothy.optimize_loop(
                "layer456_loop", postamble_label="layer456_loop_end")

        slothy.config.constraints.st_ld_hazard = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer78_loop")

        if self.cross_loops_optim:
            slothy.config.sw_pipelining.enabled = False
            slothy.config.constraints.st_ld_hazard = True
            slothy.config.outputs = slothy.last_result.kernel_input_output + \
                ["r14"]
            slothy.optimize(start="layer456_loop_end", end="layer78_loop")


class ntt_dilithium_123_456_78_symbolic(Example):
    def __init__(self):
        super().__init__("ntt_dilithium_123_456_78_symbolic", rename=True)

    def core(self, slothy):
        slothy.config.typing_hints = {
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root3": Arch_Armv81M.RegisterType.GPR,
            "root5": Arch_Armv81M.RegisterType.GPR,
            "root6": Arch_Armv81M.RegisterType.GPR,
            "rtmp": Arch_Armv81M.RegisterType.GPR,
            "rtmp_tw": Arch_Armv81M.RegisterType.GPR,
            "root2_tw": Arch_Armv81M.RegisterType.GPR,
            "root3_tw": Arch_Armv81M.RegisterType.GPR,
            "root5_tw": Arch_Armv81M.RegisterType.GPR,
            "root6_tw": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_minimum_attempt = 0
        slothy.config.constraints.stalls_first_attempt = 0
        slothy.config.locked_registers = set([f"QSTACK{i}" for i in [4, 5, 6]] +
                                             ["ROOT0_STACK", "RPTR_STACK"])
        slothy.optimize_loop("layer456_loop")


class ntt_dilithium_123_45678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = f"ntt_dilithium_123_45678"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["v8", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 110
        slothy.optimize_loop("layer123_start")

        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 40
        slothy.optimize_loop("layer45678_start")


class intt_dilithium_123_45678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = f"intt_dilithium_123_45678"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.inputs_are_outputs = True

        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["v8", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 40
        slothy.optimize_loop("layer45678_start")

        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["v8", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 110
        slothy.optimize_loop("layer123_start")




class ntt_dilithium_123(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_dilithium_123"
        infile = "ntt_dilithium_123_45678"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["v8", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer123_start")


class ntt_dilithium_45678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "ntt_dilithium_45678"
        infile = "ntt_dilithium_123_45678"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 160
        slothy.config.constraints.stalls_minimum_attempt = 160
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer45678_start")


class ntt_dilithium_1234_5678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None):
        name = f"ntt_dilithium_1234_5678"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        conf = slothy.config.copy()

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2
        slothy.config.split_heuristic_repeat = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.constraints.stalls_first_attempt = 14
        slothy.optimize_loop("layer1234_start")

        slothy.config = conf.copy()

        if self.timeout is not None:
            slothy.config.timeout = self.timeout * 12

        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.split_heuristic = False
        slothy.optimize_loop("layer5678_start")


class intt_dilithium_1234_5678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72, timeout=None):
        name = f"intt_dilithium_1234_5678"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        conf = slothy.config.copy()

        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.split_heuristic = False
        slothy.optimize_loop("layer5678_start")

        slothy.config = conf.copy()

        if self.timeout is not None:
            slothy.config.timeout = self.timeout // 12

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2
        slothy.config.split_heuristic_repeat = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.constraints.stalls_first_attempt = 14
        slothy.optimize_loop("layer1234_start")


class ntt_dilithium_1234(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "ntt_dilithium_1234"
        infile = "ntt_dilithium_1234_5678"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 6)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer1234_start")


class ntt_dilithium_5678(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72):
        name = "ntt_dilithium_5678"
        infile = "ntt_dilithium_1234_5678"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.config.reserved_regs = ["x3", "x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.optimize_loop("layer5678_start")


class intt_dilithium_12_34_56_78(Example):
    def __init__(self):
        super().__init__("intt_dilithium_12_34_56_78", rename=True)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.typing_hints = {
            "root0": Arch_Armv81M.RegisterType.GPR,
            "root1": Arch_Armv81M.RegisterType.GPR,
            "root2": Arch_Armv81M.RegisterType.GPR,
            "root0_twisted": Arch_Armv81M.RegisterType.GPR,
            "root1_twisted": Arch_Armv81M.RegisterType.GPR,
            "root2_twisted": Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer78_loop")


class fft_fixedpoint_radix4(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "fixedpoint_radix4_fft"
        subpath = "fx_r4_fft/"
        infile = subpath + "base_symbolic"
        outfile = subpath + name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=outfile,
                         rename=True, arch=arch, target=target)

    def core(self, slothy):
        # This is default value, but it's overwritten in case of a dry-run.
        # However, the symbolic registers in the FLT FFT cannot be resolved
        # without reordering, so let's ignore the dry-run parameter here.
        slothy.config.constraints.allow_reordering = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("fixedpoint_radix4_fft_loop_start")


class fft_floatingpoint_radix4(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        name = "floatingpoint_radix4_fft"
        subpath = "flt_r4_fft/"
        infile = subpath + "base_symbolic"
        outfile = subpath + name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, outfile=outfile,
                         rename=True, arch=arch, target=target)

    def core(self, slothy):
        # This is default value, but it's overwritten in case of a dry-run.
        # However, the symbolic registers in the FLT FFT cannot be resolved
        # without reordering, so let's ignore the dry-run parameter here.
        slothy.config.constraints.allow_reordering = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("flt_radix4_fft_loop_start")

#############################################################################################

class ntt_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = f"ntt_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_ntt"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.constraints.stalls_first_attempt = 16

        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.sw_pipelining.allow_pre = True

        slothy.config.outputs = ["r0"]
        slothy.optimize_loop("layer123_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r0", "s0", "s10", "s9"]
        slothy.optimize_loop("layer456_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r0", "r4"]  # r4 is cntr
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer78_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

class intt_dilithium_123_456_78(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_dilithium_123_456_78"
        infile = name
        funcname = "pqcrystals_dilithium_invntt_tomont"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.constraints.stalls_first_attempt = 16

        slothy.config.unsafe_address_offset_fixup = True


        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.minimize_overlapping = True
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.sw_pipelining.allow_pre = True

        slothy.optimize_loop("layer123_loop", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.optimize_loop("layer456_first_loop")
        slothy.optimize_loop("layer456_loop")

        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer78_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

class pointwise_montgomery_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_montgomery_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_pointwise_montgomery"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("1")

class pointwise_acc_montgomery_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_acc_montgomery_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_pointwise_acc_montgomery"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("1")

class fnt_257_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "fnt_257_dilithium"
        infile = name
        funcname = "__asm_fnt_257"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.visualize_expected_performance = False
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.variable_size = True

        func_args = {"r1", "r2", "r3"}
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(30)) # reserve FPR
        r = r.union(func_args)
        slothy.config.reserved_regs = r

        slothy.config.constraints.stalls_first_attempt = 8
        slothy.config.sw_pipelining.enabled = True
        slothy.config.timeout = 600
        slothy.optimize_loop("_fnt_0_1_2")

        slothy.config.sw_pipelining.enabled = False
        slothy.config.timeout = 300

        slothy.config.constraints.stalls_first_attempt = 8
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.timeout = 180 # Not more than 2min per step
        # TODO: run with more repeats
        slothy.config.split_heuristic_repeat = 2
        slothy.config.outputs = ["s25", "s27", "r12"]
        slothy.fusion_loop("_fnt_3_4_5_6", ssa=False)
        slothy.optimize_loop("_fnt_3_4_5_6")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("_fnt_3_4_5_6")

        # Due dependencies in the memory between loads and stores, skip this for now
        # slothy.optimize_loop("_fnt_to_16_bit")

class ifnt_257_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ifnt_257_dilithium"
        infile = name
        funcname = "__asm_ifnt_257"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.timeout = 300
        
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.outputs = ["r14", "s1", "r12"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.config.objective_precision = 0.07
        # TODO: run with more repeats
        slothy.config.split_heuristic_repeat = 1
        slothy.fusion_loop("_ifnt_7_6_5_4", ssa=False)
        slothy.optimize_loop("_ifnt_7_6_5_4")

        slothy.config.outputs = ["r14", "r1", "s1"]
        slothy.config.inputs_are_outputs = True
        slothy.config.split_heuristic = False
        slothy.optimize_loop("_ifnt_0_1_2")


class basemul_257_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_257_dilithium"
        infile = name
        funcname = "__asm_point_mul_257_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):

        slothy.config.outputs = ["r12", "r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("_point_mul_16_loop")

class basemul_257_asymmetric_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_257_asymmetric_dilithium"
        infile = name
        funcname = "__asm_asymmetric_mul_257_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14", "r12"]
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("_asymmetric_mul_16_loop")


class ntt_769_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "ntt_769_dilithium"
        infile = name
        outfile = name
        funcname = "small_ntt_asm_769"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, outfile=outfile, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.outputs = ["r14"]
        slothy.config.constraints.stalls_first_attempt = 32

        r = slothy.config.reserved_regs
        r.add("r1")
        r = r.union(f"s{i}" for i in range(31)) # reserve FPR
        slothy.config.reserved_regs = r

        ### TODO
        # - Experiment with lower split factors
        # - Try to get stable performance: It currently varies a lot with each run

        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.variable_size = True
        slothy.config.split_heuristic = True
        slothy.config.timeout = 360 # Not more than 2min per step
        slothy.config.visualize_expected_performance = False
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.optimize_loop("layer1234_loop", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer1234_loop", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r14"]

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer567_loop", ssa=False)
        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.outputs = ["r14"]

        slothy.config.timeout = 360
        slothy.config.variable_size = True
        slothy.config.split_heuristic_optimize_seam = 0
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_factor = 2.25
        slothy.config.split_heuristic_stepsize = 0.25
        slothy.optimize_loop("layer567_loop")

        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer567_loop")

class intt_769_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_769_dilithium"
        infile = name
        funcname = "small_invntt_asm_769"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.timeout = 180
        
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.split_heuristic = True
        slothy.config.reserved_regs = ["r1", "r13"] + [f"s{i}" for i in range(23, 32)]

        slothy.config.split_heuristic_factor = 8
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.config.split_heuristic_repeat = 1

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer1234_loop", ssa=False)
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("layer1234_loop")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer1234_loop")

        slothy.config.split_heuristic_factor = 4

        # Optimize first iteration that has been separated from the loop
        # TODO: Do we further need to limit renaming because of the following
        # loop using registers set in this region?

        slothy.config.outputs = ["s0", "s2"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_region(start="layer567_first_start", end="layer567_first_end", ssa=False)
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize(start="layer567_first_start", end="layer567_first_end")

        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("layer567_loop", ssa=False)
        # slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("layer567_loop")
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("layer567_loop")


class pointwise_769_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_769_dilithium"
        infile = name
        funcname = "small_pointmul_asm_769"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r3")
        slothy.config.reserved_regs = r
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("_point_mul_16_loop")


class pointwise_769_asymmetric_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "pointwise_769_asymmetric_dilithium"
        infile = name
        funcname = "small_asymmetric_mul_asm_769"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("_asymmetric_mul_16_loop")

class reduce32_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "reduce32_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_reduce32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("1")

class caddq_dilithium(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "caddq_dilithium"
        infile = name
        funcname = "pqcrystals_dilithium_asm_caddq"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r10"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("1")
        
class Keccak(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = f"keccakf1600"
        infile = name
        funcname = "KeccakF1600_StatePermute"
        

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
            funcname += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, funcname=funcname, rename=True, arch=arch, target=target, timeout=timeout)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.reserved_regs = ["sp", "r13"]
        slothy.config.locked_registers = ["sp", "r13"]
        slothy.config.unsafe_address_offset_fixup = False
        
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.config.split_heuristic_stepsize = 0.05

        if "adomnicai_m7" in self.name:
            slothy.config.split_heuristic_factor = 6
            
            slothy.config.outputs = ['hint_spEga0', 'hint_spEge0', 'hint_spEgi0', 'hint_spEgo0', 'hint_spEgu0', 'hint_spEka1', 'hint_spEke1', 'hint_spEki1', 'hint_spEko1', 'hint_spEku1', 'hint_spEma0', 'hint_spEme0', 'hint_spEmi0', 'hint_spEmo0', 'hint_spEmu0', 'hint_spEsa1', 'hint_spEse1', 'hint_spEsi1', 'hint_spEso1', 'hint_spEsu1', 'hint_spEbe0', 'hint_spEbi0', 'hint_spEbo0', 'hint_spEbu0', 'hint_spEba0', 'hint_spEga1', 'hint_spEge1', 'hint_spEgi1', 'hint_spEgo1', 'hint_spEgu1', 'hint_spEka0', 'hint_spEke0', 'hint_spEki0', 'hint_spEko0', 'hint_spEku0', 'hint_spEma1', 'hint_spEme1', 'hint_spEmi1', 'hint_spEmo1', 'hint_spEmu1', 'hint_spEsa0', 'hint_spEse0', 'hint_spEsi0', 'hint_spEso0', 'hint_spEsu0', 'hint_spEbe1', 'hint_spEbi1', 'hint_spEbo1', 'hint_spEbu1', 'hint_spEba1']
            slothy.optimize(start="slothy_start_round0", end="slothy_end_round0")
            slothy.config.outputs = ['flags', 'hint_r0Aba0', 'hint_r0Aba1', 'hint_r0Abe0', 'hint_r0Abe1', 'hint_r0Abi0', 'hint_r0Abi1', 'hint_r0Abo0', 'hint_r0Abo1', 'hint_r0Abu0', 'hint_r0Abu1', 'hint_r0Aga0', 'hint_r0Aga1', 'hint_r0Age0', 'hint_r0Age1', 'hint_r0Agi0', 'hint_r0Agi1', 'hint_r0Ago0', 'hint_r0Ago1', 'hint_r0Agu0', 'hint_r0Agu1', 'hint_r0Aka0', 'hint_r0Aka1', 'hint_r0Ake0', 'hint_r0Ake1', 'hint_r0Aki0', 'hint_r0Aki1', 'hint_r0Ako0', 'hint_r0Ako1', 'hint_r0Aku0', 'hint_r0Aku1', 'hint_r0Ama0', 'hint_r0Ama1', 'hint_r0Ame0', 'hint_r0Ame1', 'hint_r0Ami0', 'hint_r0Ami1', 'hint_r0Amo0', 'hint_r0Amo1', 'hint_r0Amu0', 'hint_r0Amu1', 'hint_r0Asa0', 'hint_r0Asa1', 'hint_r0Ase0', 'hint_r0Ase1', 'hint_r0Asi0', 'hint_r0Asi1', 'hint_r0Aso0', 'hint_r0Aso1', 'hint_r0Asu0', 'hint_r0Asu1']
            slothy.optimize(start="slothy_start_round1", end="slothy_end_round1")
        else: 
            if "xkcp" in self.name:
                slothy.config.outputs = ['flags', 'hint_spEba0', 'hint_spEba1', 'hint_spEbe0', 'hint_spEbe1', 'hint_spEbi0', 'hint_spEbi1', 'hint_spEbo0', 'hint_spEbo1', 'hint_spEbu0', 'hint_spEbu1', 'hint_spEga0', 'hint_spEga1', 'hint_spEge0', 'hint_spEge1', 'hint_spEgi0', 'hint_spEgi1', 'hint_spEgo0', 'hint_spEgo1', 'hint_spEgu0', 'hint_spEgu1', 'hint_spEka0', 'hint_spEka1', 'hint_spEke0', 'hint_spEke1', 'hint_spEki0', 'hint_spEki1', 'hint_spEko0', 'hint_spEko1', 'hint_spEku0', 'hint_spEku1', 'hint_spEma0', 'hint_spEma1', 'hint_spEme0', 'hint_spEme1', 'hint_spEmi0', 'hint_spEmi1', 'hint_spEmo0', 'hint_spEmo1', 'hint_spEmu0', 'hint_spEmu1', 'hint_spEsa0', 'hint_spEsa1', 'hint_spEse0', 'hint_spEse1', 'hint_spEsi0', 'hint_spEsi1', 'hint_spEso0', 'hint_spEso1', 'hint_spEsu0', 'hint_spEsu1']
            if "adomnicai_m4" in self.name:
                slothy.config.outputs = ['flags', 'hint_r0Aba1', 'hint_r0Aka1', 'hint_spEba0', 'hint_spEba1', 'hint_spEbe0', 'hint_spEbe1', 'hint_spEbi0', 'hint_spEbi1', 'hint_spEbo0', 'hint_spEbo1', 'hint_spEbu0', 'hint_spEbu1', 'hint_spEga0', 'hint_spEga1', 'hint_spEge0', 'hint_spEge1', 'hint_spEgi0', 'hint_spEgi1', 'hint_spEgo0', 'hint_spEgo1', 'hint_spEgu0', 'hint_spEgu1', 'hint_spEka0', 'hint_spEka1', 'hint_spEke0', 'hint_spEke1', 'hint_spEki0', 'hint_spEki1', 'hint_spEko0', 'hint_spEko1', 'hint_spEku0', 'hint_spEku1', 'hint_spEma0', 'hint_spEma1', 'hint_spEme0', 'hint_spEme1', 'hint_spEmi0', 'hint_spEmi1', 'hint_spEmo0', 'hint_spEmo1', 'hint_spEmu0', 'hint_spEmu1', 'hint_spEsa0', 'hint_spEsa1', 'hint_spEse0', 'hint_spEse1', 'hint_spEsi0', 'hint_spEsi1', 'hint_spEso0', 'hint_spEso1', 'hint_spEsu0', 'hint_spEsu1', 'hint_spmDa0']
            
            slothy.config.split_heuristic_factor = 22
            slothy.config.constraints.stalls_first_attempt = 16

            slothy.optimize(start="slothy_start", end="slothy_end")


class ntt_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = f"ntt_kyber"
        infile = name
        funcname = "ntt_fast"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14", "s23"]

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(30)) # reserve FPR
        r.add("r1")
        slothy.config.reserved_regs = r

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = True

        ### TODO
        # - Experiment with lower split factors
        # - Try to get stable performance: It currently varies a lot with each run
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.split_heuristic = True
        slothy.config.timeout = 360 # Not more than 6min per step
        slothy.config.visualize_expected_performance = False
        slothy.config.split_heuristic_factor = 6
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.outputs = ["r14"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("2", ssa=False, forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.unsafe_address_offset_fixup = True

        slothy.config.timeout = 360
        slothy.config.split_heuristic_optimize_seam = 0
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_factor = 4
        slothy.config.split_heuristic_stepsize = 0.1
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)

        slothy.config.split_heuristic_optimize_seam = 6
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)


class intt_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "intt_kyber"
        infile = name
        funcname = "invntt_fast"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.reserved_regs = ["r1", "r13"] + [f"s{i}" for i in range(23, 32)]
        slothy.config.timeout = 300

        # Step 1: optimize first loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 4
        slothy.config.split_heuristic_stepsize = 0.15
        slothy.config.split_heuristic_repeat = 1
        slothy.config.outputs = ["r14", "s8"]
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

        # Step 2: optimize the start of the second loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 2.5
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.outputs = ["r14", "r0", "r10", "s0", "s2"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_region(start="layer567_first_start", end="layer567_first_end", ssa=False)
        slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize(start="layer567_first_start", end="layer567_first_end")

        # Step 3: optimize the start of the second loop
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 3
        slothy.config.split_heuristic_stepsize = 0.2
        slothy.config.outputs = ["r14", "s14"]
        slothy.config.unsafe_address_offset_fixup = False
        slothy.fusion_loop("2", ssa=False, forced_loop_type=Arch_Armv7M.BranchLoop)
        slothy.config.unsafe_address_offset_fixup = True
        slothy.optimize_loop("2", forced_loop_type=Arch_Armv7M.BranchLoop)


class basemul_16_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_16_32_kyber"
        infile = name
        funcname = "basemul_asm_opt_16_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")

class basemul_acc_32_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_32_32_kyber"
        infile = name
        funcname = "basemul_asm_acc_opt_32_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

class basemul_acc_32_16_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_32_16_kyber"
        infile = name
        funcname = "basemul_asm_acc_opt_32_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")

class frombytes_mul_16_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_16_32_kyber"
        infile = name
        funcname = "frombytes_mul_asm_16_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")

class frombytes_mul_acc_32_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_32_32_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc_32_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r14")
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")

class frombytes_mul_acc_32_16_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_32_16_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc_32_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

class add_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "add_kyber"
        infile = name
        funcname = "pointwise_add"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")
        slothy.config.sw_pipelining.enabled = False
        slothy.fusion_region(start="pointwise_add_final_start", end="pointwise_add_final_end", ssa=False)
        slothy.optimize(start="pointwise_add_final_start", end="pointwise_add_final_end")

class sub_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "sub_kyber"
        infile = name
        funcname = "pointwise_sub"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")

        slothy.config.sw_pipelining.enabled = False
        slothy.fusion_region(start="pointwise_sub_final_start", end="pointwise_sub_final_end", ssa=False)
        slothy.optimize(start="pointwise_sub_final_start", end="pointwise_sub_final_end")

class barrett_reduce_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "barrett_reduce_kyber"
        infile = name
        funcname = "asm_barrett_reduce"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r9"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 43
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")



class fromplant_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "fromplant_kyber"
        infile = name
        funcname = "asm_fromplant"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r9"]
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 4
        slothy.fusion_loop("1", ssa=False)
        slothy.optimize_loop("1")

class basemul_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_kyber"
        infile = name
        funcname = "basemul_asm"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.constraints.stalls_first_attempt = 16
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(31)) # reserve FPR
        slothy.config.reserved_regs = r

        slothy.fusion_loop("1", ssa=False)
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.SubsLoop)

class basemul_acc_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "basemul_acc_kyber"
        infile = name
        funcname = "basemul_asm_acc"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.outputs = ["r14"]
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.constraints.stalls_first_attempt = 16

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(31)) # reserve FPR
        slothy.config.reserved_regs = r

        slothy.fusion_loop("1", ssa=False)
        slothy.config.unsafe_address_offset_fixup = False
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.SubsLoop)

class frombytes_mul_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_kyber"
        infile = name
        funcname = "frombytes_mul_asm"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r.add("r14")
        r = r.union(f"s{i}" for i in range(31)) # reserve FPR
        slothy.config.reserved_regs = r
        slothy.config.unsafe_address_offset_fixup = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1")

class frombytes_mul_acc_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "frombytes_mul_acc_kyber"
        infile = name
        funcname = "frombytes_mul_asm_acc"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False
        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(32)) # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.optimize_loop("1", forced_loop_type=Arch_Armv7M.BranchLoop)

class matacc_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_kyber"
        infile = name
        funcname = "matacc_asm"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(32)) # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_acc_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_acc_kyber"
        infile = name
        funcname = "matacc_asm_acc"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True

        r = slothy.config.reserved_regs
        r = r.union(f"s{i}" for i in range(32)) # reserve FPR
        slothy.config.reserved_regs = r

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")



class matacc_asm_opt_16_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_16_32_kyber"
        infile = name
        funcname = "matacc_asm_opt_16_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        # TODO: r10, r11, r12 shouldn't actually be needed as q,qa,qinv are unused in this code.
        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")

class matacc_asm_opt_32_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_32_32_kyber"
        infile = name
        funcname = "matacc_asm_opt_32_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        # TODO: r10, r11, r12 shouldn't actually be needed as q,qa,qinv are unused in this code.
        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_opt_32_16_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_opt_32_16_kyber"
        infile = name
        funcname = "matacc_asm_opt_32_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_cache_16_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_16_32_kyber"
        infile = name
        funcname = "matacc_asm_cache_16_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")


class matacc_asm_cache_32_32_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_32_32_kyber"
        infile = name
        funcname = "matacc_asm_cache_32_32"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")

class matacc_asm_cache_32_16_kyber(Example):
    def __init__(self, var="", arch=Arch_Armv7M, target=Target_CortexM7, timeout=None):
        name = "matacc_asm_cache_32_16_kyber"
        infile = name
        funcname = "matacc_asm_cache_32_16"

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"

        super().__init__(infile, name, rename=True, arch=arch, target=target, timeout=timeout, funcname=funcname)

    def core(self, slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.unsafe_address_offset_fixup = False

        slothy.config.reserved_regs = [f"s{i}" for i in range(0, 32)] + ["sp", "r13"] + ["r10", "r11", "r12"]

        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_1", end="slothy_end_1")
        slothy.config.outputs = ["r9"]
        slothy.optimize(start="slothy_start_2", end="slothy_end_2")

def main():
    examples = [ Example0(),
                 Example1(),
                 Example2(),
                 Example3(),

                 AArch64Example0(),
                 AArch64Example0(target=Target_CortexA72),
                 AArch64Example0Equ(),
                 AArch64Example1(),
                 AArch64Example1(target=Target_CortexA72),
                 AArch64Example2(),
                 AArch64Example2(target=Target_CortexA72),
                 AArch64IfElse(),

                 AArch64Split0(),

                # Armv7m examples
                 Armv7mExample0(),
                 Armv7mExample0Func(),

                # Loop examples
                 AArch64LoopSubs(),
                 LoopLe(),
                 Armv7mLoopSubs(),
                 Armv7mLoopCmp(),
                 Armv7mLoopVmovCmp(),
                 Armv7mLoopVmovCmpForced(),

                 CRT(),

                 ntt_n256_l6_s32("bar"),
                 ntt_n256_l6_s32("mont"),
                 ntt_n256_l8_s32("bar"),
                 ntt_n256_l8_s32("mont"),
                 intt_n256_l6_s32("bar"),
                 intt_n256_l6_s32("mont"),
                 intt_n256_l8_s32("bar"),
                 intt_n256_l8_s32("mont"),

                 # Kyber NTT
                 # Cortex-M55
                 ntt_kyber_1_23_45_67(),
                 ntt_kyber_1_23_45_67(var="no_trans"),
                 ntt_kyber_1_23_45_67(var="no_trans_vld4", timeout=600),
                 ntt_kyber_12_345_67(False),
                 ntt_kyber_12_345_67(True),
                 # Cortex-M85
                 ntt_kyber_1_23_45_67(target=Target_CortexM85r1),
                 ntt_kyber_1_23_45_67(var="no_trans", target=Target_CortexM85r1),
                 ntt_kyber_1_23_45_67(var="no_trans_vld4", target=Target_CortexM85r1, timeout=600),
                 ntt_kyber_12_345_67(False, target=Target_CortexM85r1),
                 ntt_kyber_12_345_67(True, target=Target_CortexM85r1),
                 # Cortex-A55
                 ntt_kyber_123_4567(),
                 ntt_kyber_123_4567(var="scalar_load"),
                 ntt_kyber_123_4567(var="scalar_store"),
                 ntt_kyber_123_4567(var="scalar_load_store"),
                 ntt_kyber_123_4567(var="manual_st4"),
                 ntt_kyber_1234_567(),
                 intt_kyber_123_4567(),
                 intt_kyber_123_4567(var="manual_ld4"),
                 # Cortex-A72
                 ntt_kyber_123_4567(target=Target_CortexA72),
                 ntt_kyber_123_4567(var="scalar_load", target=Target_CortexA72),
                 ntt_kyber_123_4567(var="scalar_store", target=Target_CortexA72),
                 ntt_kyber_123_4567(var="scalar_load_store", target=Target_CortexA72),
                 ntt_kyber_123_4567(var="manual_st4", target=Target_CortexA72),
                 ntt_kyber_1234_567(target=Target_CortexA72),
                 intt_kyber_123_4567(target=Target_CortexA72),
                 intt_kyber_123_4567(var="manual_ld4", target=Target_CortexA72),
                #  # Apple M1 Firestorm
                 ntt_kyber_123_4567(target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_load", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_store", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_load_store", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_kyber_123_4567(var="manual_st4", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_kyber_1234_567(target=Target_AppleM1_firestorm, timeout=300),
                 ntt_kyber_1234_567(var="manual_st4", target=Target_AppleM1_firestorm, timeout=300),
                 intt_kyber_123_4567(target=Target_AppleM1_firestorm, timeout=3600),
                 intt_kyber_123_4567(var="manual_ld4", target=Target_AppleM1_firestorm, timeout=3600),
                 # Apple M1 Icestorm
                 ntt_kyber_123_4567(target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_load", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_store", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_kyber_123_4567(var="scalar_load_store", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_kyber_123_4567(var="manual_st4", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_kyber_1234_567(target=Target_AppleM1_icestorm, timeout=300),
                 ntt_kyber_1234_567(var="manual_st4", target=Target_AppleM1_icestorm, timeout=300),
                 intt_kyber_123_4567(target=Target_AppleM1_icestorm, timeout=3600),
                 intt_kyber_123_4567(var="manual_ld4", target=Target_AppleM1_icestorm, timeout=3600),
                 # Kyber InvNTT
                 # Cortex-M55
                 intt_kyber_1_23_45_67(),
                 # Dilithium NTT
                 # Cortex-M55
                 ntt_dilithium_12_34_56_78(),
                 ntt_dilithium_12_34_56_78(var="no_trans_vld4"),
                 ntt_dilithium_123_456_78(False),
                 ntt_dilithium_123_456_78(True),
                 # Cortex-M85
                 ntt_dilithium_12_34_56_78(target=Target_CortexM85r1),
                 ntt_dilithium_12_34_56_78(var="no_trans_vld4", target=Target_CortexM85r1),
                 ntt_dilithium_123_456_78(False, target=Target_CortexM85r1),
                 ntt_dilithium_123_456_78(True, target=Target_CortexM85r1),
                 # Cortex-A55
                 ntt_dilithium_45678(),
                 ntt_dilithium_123_45678(),
                 ntt_dilithium_123_45678(var="w_scalar"),
                 ntt_dilithium_123_45678(var="manual_st4"),
                 ntt_dilithium_1234_5678(),
                 ntt_dilithium_1234_5678(var="manual_st4"),
                 intt_dilithium_123_45678(),
                 intt_dilithium_123_45678(var="manual_ld4"),
                 intt_dilithium_1234_5678(),
                 intt_dilithium_1234_5678(var="manual_ld4"),
                 # Cortex-A72
                 ntt_dilithium_123_45678(target=Target_CortexA72),
                 ntt_dilithium_123_45678(var="w_scalar", target=Target_CortexA72),
                 ntt_dilithium_123_45678(var="manual_st4", target=Target_CortexA72),
                 ntt_dilithium_1234_5678(target=Target_CortexA72),
                 ntt_dilithium_1234_5678(var="manual_st4", target=Target_CortexA72),
                 intt_dilithium_123_45678(target=Target_CortexA72),
                 intt_dilithium_123_45678(var="manual_ld4", target=Target_CortexA72),
                 intt_dilithium_1234_5678(target=Target_CortexA72),
                 intt_dilithium_1234_5678(var="manual_ld4", target=Target_CortexA72),
                 # Apple M1 Firestorm
                ntt_dilithium_123_45678(target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_dilithium_123_45678(var="w_scalar", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_dilithium_123_45678(var="manual_st4", target=Target_AppleM1_firestorm, timeout=3600),
                 ntt_dilithium_1234_5678(target=Target_AppleM1_firestorm, timeout=300),
                 ntt_dilithium_1234_5678(var="manual_st4", target=Target_AppleM1_firestorm, timeout=300),
                 intt_dilithium_123_45678(target=Target_AppleM1_firestorm, timeout=3600),
                 intt_dilithium_123_45678(var="manual_ld4", target=Target_AppleM1_firestorm, timeout=3600),
                 intt_dilithium_1234_5678(target=Target_AppleM1_firestorm, timeout=3600),
                 intt_dilithium_1234_5678(var="manual_ld4", target=Target_AppleM1_firestorm, timeout=3600),
                 # Apple M1 Icestorm
                 ntt_dilithium_123_45678(target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_dilithium_123_45678(var="w_scalar", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_dilithium_123_45678(var="manual_st4", target=Target_AppleM1_icestorm, timeout=3600),
                 ntt_dilithium_1234_5678(target=Target_AppleM1_icestorm, timeout=300),
                 ntt_dilithium_1234_5678(var="manual_st4", target=Target_AppleM1_icestorm, timeout=300),
                 intt_dilithium_123_45678(target=Target_AppleM1_icestorm, timeout=3600),
                 intt_dilithium_123_45678(var="manual_ld4", target=Target_AppleM1_icestorm, timeout=3600),
                 intt_dilithium_1234_5678(target=Target_AppleM1_icestorm, timeout=3600),
                 intt_dilithium_1234_5678(var="manual_ld4", target=Target_AppleM1_icestorm, timeout=3600),
                 # Dilithium invNTT
                 # Cortex-M55
                 intt_dilithium_12_34_56_78(),

                 # Fast Fourier Transform (FFT)
                 # Floating point
                 fft_floatingpoint_radix4(),
                 # Fixed point
                 fft_fixedpoint_radix4(),
                 
                 ntt_dilithium(),
                 intt_dilithium_123_456_78(),
                 pointwise_montgomery_dilithium(),
                 pointwise_acc_montgomery_dilithium(),
                 fnt_257_dilithium(),
                 ifnt_257_dilithium(),
                 basemul_257_dilithium(),
                 basemul_257_asymmetric_dilithium(),
                 ntt_769_dilithium(),
                 intt_769_dilithium(),
                 pointwise_769_dilithium(),
                 pointwise_769_asymmetric_dilithium(),
                 reduce32_dilithium(),
                 caddq_dilithium(),
                 
                 Keccak(var="xkcp"),
                 Keccak(var="adomnicai_m4"),
                 Keccak(var="adomnicai_m7"),

                 ntt_kyber(),
                 intt_kyber(),
                 basemul_16_32_kyber(),
                 basemul_acc_32_32_kyber(),
                 basemul_acc_32_16_kyber(),
                 frombytes_mul_16_32_kyber(),
                 frombytes_mul_acc_32_32_kyber(),
                 frombytes_mul_acc_32_16_kyber(),
                 add_kyber(),
                 sub_kyber(),
                 barrett_reduce_kyber(),
                 fromplant_kyber(),

                 basemul_kyber(),
                 basemul_acc_kyber(),
                 frombytes_mul_kyber(),
                 frombytes_mul_acc_kyber(),
                 matacc_kyber(),
                 matacc_acc_kyber(),
                 matacc_asm_opt_16_32_kyber(),
                 matacc_asm_opt_32_32_kyber(),
                 matacc_asm_opt_32_16_kyber(),
                 matacc_asm_cache_16_32_kyber(),
                 matacc_asm_cache_32_32_kyber(),
                 matacc_asm_cache_32_16_kyber(),
                 ]

    all_example_names = [e.name for e in examples]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        "--examples", type=str, default="all",
        help=f"The list of examples to be run, comma-separated list from {all_example_names}. "
        f"Format: {{name}}_{{variant}}_{{target}}, e.g., ntt_kyber_123_4567_scalar_load_a55"
    )
    parser.add_argument("--dry-run", default=False, action="store_true")
    parser.add_argument("--debug", default=False, action="store_true")
    parser.add_argument("--silent", default=False, action="store_true")
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=0)
    parser.add_argument("--debug-logfile", type=str, default=None)
    parser.add_argument("--log-model", default=False, action="store_true")
    parser.add_argument("--log-model-dir", type=str, default="models")
    parser.add_argument("--only-target", type=str,choices=[
        Target_CortexM7.__name__,
        Target_CortexM55r1.__name__, Target_CortexM85r1.__name__, \
        Target_CortexA55.__name__, Target_CortexA72.__name__, Target_AppleM1_firestorm.__name__, \
        Target_AppleM1_icestorm.__name__])
    args = parser.parse_args()
    if args.examples != "all":
        todo = args.examples.split(",")
    else:
        todo = all_example_names
    iterations = args.iterations

    def run_example(name, **kwargs):
        ex = None
        for e in examples:
            if e.name == name:
                ex = e
                break
        if ex is None:
            raise ExampleException(f"Could not find example {name}")
        ex.run(**kwargs)

    for e in todo:
        for _ in range(iterations):
            run_example(e, debug=args.debug, dry_run=args.dry_run,
                        silent=args.silent, log_model=args.log_model,
                        debug_logfile=args.debug_logfile,
                        log_model_dir=args.log_model_dir, timeout=args.timeout,
                        only_target=args.only_target)

if __name__ == "__main__":
    main()

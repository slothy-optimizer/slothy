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

import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55
import slothy.targets.aarch64.cortex_a72_frontend as Target_CortexA72
import slothy.targets.aarch64.apple_m1_firestorm_experimental as Target_AppleM1_firestorm
import slothy.targets.aarch64.apple_m1_icestorm_experimental as Target_AppleM1_icestorm

target_label_dict = {Target_CortexA55: "a55",
                     Target_CortexA72: "a72",
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
                 timeout=None, outfile_full=False, **kwargs):
        if name is None:
            name = infile

        self.arch = arch
        self.target = target
        self.funcname = funcname
        self.infile = infile
        self.suffix = suffix
        if outfile_full is True:
            self.outfile = outfile
        else:
            if outfile == "":
                self.outfile = f"{infile}_{self.suffix}_{target_label_dict[self.target]}"
            else:
                self.outfile = f"{outfile}_{self.suffix}_{target_label_dict[self.target]}"
        if funcname is None:
            self.funcname = self.infile
        subfolder = ""
        if self.arch == AArch64_Neon:
            subfolder = "aarch64/"
        self.infile_full = f"examples/naive/{subfolder}{self.infile}.s"
        if outfile_full is False:
            self.outfile_full = f"examples/opt/{subfolder}{self.outfile}.s"
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

    def run(self, debug=False, log_model=False, log_model_dir="models", dry_run=False, silent=False, timeout=0, debug_logfile=None):

        if dry_run is True:
            annotation = " (dry run only)"
        else:
            annotation = ""

        print(f"* Example: {self.name}{annotation}...")

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

        if self.rename is not False:
            if self.rename is True:
                slothy.rename_function(
                    self.funcname, f"{self.funcname}_{self.suffix}_{target_label_dict[self.target]}")
            elif isinstance(self.rename, str):
                slothy.rename_function(self.funcname, self.rename)

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



class ntt_kyber_123_4567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None):
        name = "ntt_kyber_123_4567"
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
        slothy.config.reserved_regs = [
            f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
        slothy.config.reserved_regs += self.target_reserved
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.optimize_loop("layer123_start")
        slothy.optimize_loop("layer4567_start")

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

class neon_keccak_x1_no_symbolic(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "keccak_f1600_x1_scalar_slothy_no_symbolic"
        infile = "keccak_f1600_x1_scalar_slothy"
        outfile = "keccak_f1600_x1_scalar_no_symbolic"

        super().__init__(infile, name, outfile=outfile, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.constraints.minimize_spills = True
        slothy.config.constraints.allow_reordering = True
        slothy.config.constraints.allow_spills = True
        slothy.config.constraints.minimize_spills = True
        slothy.config.visualize_expected_performance = True
        slothy.optimize(start="loop", end="end_loop")

        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial_round_start", end="initial_round_end")

class neon_keccak_x1_scalar_opt(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA55):
        name = "keccak_f1600_x1_scalar_opt"
        infile = "keccak_f1600_x1_scalar_pre_opt"
        outfile = "keccak_f1600_x1_scalar"

        super().__init__(infile, name, outfile=outfile, rename=True, arch=arch, target=target)

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.visualize_expected_performance = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 1.5
        slothy.config.split_heuristic_stepsize = 0.3
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_optimize_seam = 5

        slothy.optimize(start="loop", end="end_loop")

        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial_round_start", end="initial_round_end")

class neon_keccak_x4_hybrid_no_symbolic(Example):
    def __init__(self, var="v84a", arch=AArch64_Neon, target=Target_CortexA55):
        name = f"keccak_f1600_x4_{var}_hybrid_slothy_no_symbolic"
        infile = f"keccak_f1600_x4_{var}_hybrid_slothy_symbolic"
        outfile = f"examples/naive/aarch64/keccak_f1600_x4_{var}_hybrid_slothy_clean.s"

        super().__init__(infile, name, outfile=outfile, rename=f"keccak_f1600_x4_{var}_hybrid_no_symbolic", arch=arch, target=target)

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.ignore_objective = True
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.constraints.allow_spills = True
        slothy.config.visualize_expected_performance = True

        slothy.optimize(start="loop", end="loop_end")
        slothy.config.outputs = ["hint_STACK_OFFSET_COUNT"]
        slothy.optimize(start="initial", end="loop")

class neon_keccak_x4_hybrid_interleave(Example):
    def __init__(self, var="v84a", arch=AArch64_Neon, target=Target_CortexA55):
        name = f"keccak_f1600_x4_{var}_hybrid_slothy_interleave"
        infile = f"keccak_f1600_x4_{var}_hybrid_slothy_clean"
        outfile = f"examples/naive/aarch64/keccak_f1600_x4_{var}_hybrid_slothy_interleaved.s"

        super().__init__(infile, name, outfile=outfile, rename=f"keccak_f1600_x4_{var}_hybrid_slothy_interleaved",
                         arch=arch, target=target, outfile_full=True)

    def core(self, slothy):
        slothy.config.reserved_regs = ["x18", "sp"]

        slothy.config.inputs_are_outputs = True
        slothy.config.variable_size = True
        slothy.config.visualize_expected_performance = False
        slothy.config.timeout = 10800

        slothy.config.selfcheck_failure_logfile = "selfcheck_fail.log"

        slothy.config.outputs = ["flags", "hint_STACK_OFFSET_COUNT"]
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.ignore_objective = True
        slothy.config.constraints.functional_only = True
        slothy.config.constraints.allow_reordering = False
        slothy.config.constraints.allow_spills = True
        slothy.config.visualize_expected_performance = True

        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_repeat = 0
        slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.split_heuristic_preprocess_naive_interleaving_strategy = "alternate"
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.absorb_spills = False

        slothy.optimize(start="loop", end="loop_end")

#############################################################################################


def main():
    examples = [ Example0(),
                 Example1(),
                 Example2(),
                 Example3(),

                 AArch64Example0(),
                 AArch64Example0(target=Target_CortexA72),
                 AArch64Example1(),
                 AArch64Example1(target=Target_CortexA72),
                 AArch64Example2(),
                 AArch64Example2(target=Target_CortexA72),

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
                 # Keccak
                 neon_keccak_x1_no_symbolic(),
                 neon_keccak_x1_scalar_opt(),
                 neon_keccak_x4_hybrid_no_symbolic(var="v84a"),
                 neon_keccak_x4_hybrid_interleave(var="v84a"),
                 neon_keccak_x4_hybrid_no_symbolic(var="v8a"),
                 neon_keccak_x4_hybrid_interleave(var="v8a"),
                 neon_keccak_x4_hybrid_no_symbolic(var="v8a_v84a"),
                 neon_keccak_x4_hybrid_interleave(var="v8a_v84a"),
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
                        log_model_dir=args.log_model_dir, timeout=args.timeout)

if __name__ == "__main__":
    main()

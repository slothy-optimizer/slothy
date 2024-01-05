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

import argparse, logging, sys, os, time
from io import StringIO

from slothy import Slothy, Config

import slothy.targets.arm_v81m.arch_v81m as Arch_Armv81M
import slothy.targets.arm_v81m.cortex_m55r1 as Target_CortexM55r1
import slothy.targets.arm_v81m.cortex_m85r1 as Target_CortexM85r1

target_label_dict = {Target_CortexM55r1: "m55",
                     Target_CortexM85r1: "m85"}

class Example():
    def __init__(self, infile, name=None, funcname=None, suffix="opt",
                 rename=False, outfile="", arch=Arch_Armv81M, target=Target_CortexM55r1,
                 **kwargs):
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
        self.infile_full  = f"../clean/helium/ntt/{self.infile}.s"
        self.outfile_full = f"../opt/helium/ntt/{self.outfile}.s"
        self.name = name
        self.rename = rename

        self.extra_args = kwargs
    # By default, optimize the whole file
    def core(self, slothy):
        slothy.optimize()

    def run(self, silent=False):
        logdir = "logs"

        handlers = []

        h_err = logging.StreamHandler(sys.stderr)
        h_err.setLevel(logging.WARNING)
        handlers.append(h_err)

        if silent is False:
            h_info = logging.StreamHandler(sys.stdout)
            h_info.setLevel(logging.DEBUG)
            h_info.addFilter(lambda r: r.levelno == logging.INFO)
            handlers.append(h_info)

        # By default, use time stamp and input file
        file_base = os.path.basename(self.outfile_full).replace('.','_')
        logfile = f"slothy_log_{int(time.time())}_{file_base}.log"
        logfile = f"{logdir}/{logfile}"
        h_log = logging.FileHandler(logfile)
        h_log.setLevel(logging.DEBUG)
        handlers.append(h_log)

        logging.basicConfig(
            level = logging.INFO,
            handlers = handlers,
        )

        logger = logging.getLogger(self.name)
        slothy = Slothy(self.arch, self.target, logger=logger)
        slothy.load_source_from_file(self.infile_full)
        slothy.config.with_llvm_mca = True
        self.core(slothy, *self.extra_args)

        if self.rename:
            slothy.rename_function(self.funcname, f"{self.funcname}_{self.suffix}_{target_label_dict[self.target]}")
        slothy.write_source_to_file(self.outfile_full)

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
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.typing_hints = {
            "root0"         : Arch_Armv81M.RegisterType.GPR,
            "root1"         : Arch_Armv81M.RegisterType.GPR,
            "root2"         : Arch_Armv81M.RegisterType.GPR,
            "root0_twisted" : Arch_Armv81M.RegisterType.GPR,
            "root1_twisted" : Arch_Armv81M.RegisterType.GPR,
            "root2_twisted" : Arch_Armv81M.RegisterType.GPR,
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


class ntt_kyber_12_345_67(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        infile = "ntt_kyber_12_345_67"
        name = "ntt_kyber_12_345_67"
        suffix = "opt_size"
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        self.var=var
        super().__init__(infile, name=name,
                         suffix=suffix, rename=True, arch=arch, target=target)

    def core(self,slothy):
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.optimize_loop("layer12_loop", postamble_label="layer12_loop_end")
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.locked_registers = set( [ f"QSTACK{i}" for i in [4,5,6] ] +
                                               [ "STACK0" ] )
        slothy.config.sw_pipelining.enabled = False
        slothy.optimize_loop("layer345_loop")

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.sw_pipelining.halving_heuristic_periodic = True
        slothy.config.constraints.st_ld_hazard = False
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
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True
        slothy.config.typing_hints = {
            "root0"         : Arch_Armv81M.RegisterType.GPR,
            "root1"         : Arch_Armv81M.RegisterType.GPR,
            "root2"         : Arch_Armv81M.RegisterType.GPR,
            "root0_twisted" : Arch_Armv81M.RegisterType.GPR,
            "root1_twisted" : Arch_Armv81M.RegisterType.GPR,
            "root2_twisted" : Arch_Armv81M.RegisterType.GPR,
            "const1"        : Arch_Armv81M.RegisterType.GPR,
        }
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.config.sw_pipelining.optimize_preamble  = True
        slothy.config.sw_pipelining.optimize_postamble = False
        slothy.optimize_loop("layer56_loop", postamble_label="layer56_loop_end")
        slothy.config.sw_pipelining.optimize_preamble  = False
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.config.typing_hints = {}
        slothy.config.constraints.st_ld_hazard = False
        slothy.optimize_loop("layer78_loop")
        # Optimize seams between loops
        # Make sure we preserve the inputs to the loop body
        slothy.config.outputs = slothy.last_result.kernel_input_output + ["r14"]
        slothy.config.constraints.st_ld_hazard = True
        slothy.config.sw_pipelining.enabled = False
        slothy.optimize(start="layer56_loop_end", end="layer78_loop")

class ntt_dilithium_123_456_78(Example):
    def __init__(self, var="", arch=Arch_Armv81M, target=Target_CortexM55r1):
        infile = "ntt_dilithium_123_456_78"
        name = "ntt_dilithium_123_456_78"
        suffix = "opt_size"
        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        name += f"_{target_label_dict[target]}"
        super().__init__(infile, name=name,
                         suffix=suffix, arch=arch, target=target, rename=True)
        self.var = var
    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 16
        slothy.config.inputs_are_outputs = True
        slothy.config.typing_hints = {
            "root2"         : Arch_Armv81M.RegisterType.GPR,
            "root3"         : Arch_Armv81M.RegisterType.GPR,
            "root5"         : Arch_Armv81M.RegisterType.GPR,
            "root6"         : Arch_Armv81M.RegisterType.GPR,
            "rtmp"          : Arch_Armv81M.RegisterType.GPR,
            "rtmp_tw"       : Arch_Armv81M.RegisterType.GPR,
            "root2_tw"      : Arch_Armv81M.RegisterType.GPR,
            "root3_tw"      : Arch_Armv81M.RegisterType.GPR,
            "root5_tw"      : Arch_Armv81M.RegisterType.GPR,
            "root6_tw"      : Arch_Armv81M.RegisterType.GPR,
        }
        slothy.config.locked_registers = set([f"QSTACK{i}" for i in [4, 5, 6]] +
                                              [f"ROOT{i}_STACK" for i in [0, 1, 4]] + ["RPTR_STACK"])
        slothy.config.sw_pipelining.enabled=False
        slothy.optimize_loop("layer123_loop")
        slothy.optimize_loop("layer456_loop")

        slothy.config.constraints.st_ld_hazard = False
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = False
        slothy.config.typing_hints = {}
        slothy.optimize_loop("layer78_loop")

#############################################################################################

def main():
    examples = [ # Kyber NTT
                 # Cortex-M55
                 ntt_kyber_1_23_45_67(var="no_trans"),
                 ntt_kyber_1_23_45_67(var="no_trans_vld4", timeout=600),
                 ntt_kyber_12_345_67(),
                 # Cortex-M85
                 ntt_kyber_1_23_45_67(var="no_trans", target=Target_CortexM85r1),
                 ntt_kyber_1_23_45_67(var="no_trans_vld4", target=Target_CortexM85r1, timeout=600),
                 ntt_kyber_12_345_67(target=Target_CortexM85r1),
                 # # Dilithium NTT
                 # # Cortex-M55
                 ntt_dilithium_12_34_56_78(),
                 ntt_dilithium_12_34_56_78(var="no_trans_vld4"),
                 ntt_dilithium_123_456_78(),
                 # # Cortex-M85
                 ntt_dilithium_12_34_56_78(target=Target_CortexM85r1),
                 ntt_dilithium_12_34_56_78(var="no_trans_vld4", target=Target_CortexM85r1),
                 ntt_dilithium_123_456_78(target=Target_CortexM85r1),
                ]

    all_example_names = [ e.name for e in examples ]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        "--examples", type=str, default="all",
        help=f"The list of examples to be run, comma-separated list from {all_example_names}."
    )
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--silent", default=False, action='store_true',
                        help="""Silent mode: Only print warnings and errors""")

    args = parser.parse_args()
    if args.examples != "all":
        todo = args.examples.split(",")
    else:
        todo = all_example_names
    iterations = args.iterations

    def run_example(name, silent=False):
        ex = None
        for e in examples:
            if e.name == name:
                ex = e
                break
        if ex == None:
            raise Exception(f"Could not find example {name} (known: {list(e.name for e in examples)}")
        ex.run(silent=silent)

    for e in todo:
        for _ in range(iterations):
            run_example(e, silent=args.silent)

if __name__ == "__main__":
   main()

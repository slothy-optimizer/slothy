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

from slothy.targets.aarch64 import aarch64_neon as AArch64_Neon
from slothy.targets.aarch64 import cortex_a55 as Target_CortexA55
from slothy.targets.aarch64 import cortex_a72_frontend as Target_CortexA72_Frontend

target_label_dict = { Target_CortexA55 : "a55",
                      Target_CortexA72_Frontend : "a72" }

class Example():
    def __init__(self, infile, name=None, funcname=None, suffix="opt",
                 rename=False, outfile="", arch=AArch64_Neon, target=Target_CortexA72_Frontend,
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
        self.infile_full  = f"../clean/neon/{self.infile}.s"
        self.outfile_full = f"../opt/neon/{self.outfile}.s"
        self.name = name
        self.rename = rename

        self.extra_args = kwargs
    # By default, optimize the whole file
    def core(self, slothy):
        slothy.optimize()

    def run(self, silent=False, no_log=False):
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

        if no_log is False:
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
        self.core(slothy, *self.extra_args)

        if self.rename:
            slothy.rename_function(self.funcname, f"{self.funcname}_{self.suffix}_{target_label_dict[self.target]}")
        slothy.write_source_to_file(self.outfile_full)

class ntt_kyber_123_4567(Example):
    def __init__(self, var="", arch=AArch64_Neon, target=Target_CortexA72_Frontend, timeout=None):
        name = "ntt_kyber_123_4567"
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
        slothy.config.sw_pipelining.minimize_overlapping = False
        slothy.config.sw_pipelining.optimize_preamble = False
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 64
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer123_start")

        slothy.config.outputs = slothy.last_result.kernel_input_output + [f"x{i}" for i in range(0,6)]
        slothy.config.locked_registers = [f"x{i}" for i in range(0,6)]
        slothy.config.sw_pipelining.enabled = False
        slothy.config.inputs_are_outputs = False
        slothy.optimize(start="ntt_kyber_123_4567_preamble", end="layer123_start")

        slothy.config.outputs = []
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.optimize_preamble = True
        slothy.config.sw_pipelining.optimize_postamble = True
        slothy.optimize_loop("layer4567_start", postamble_label="ntt_kyber_123_4567_postamble")

        slothy.config.outputs = [f"v{i}" for i in range(8,16)]
        slothy.config.locked_registers = [f"x{i}" for i in range(0,6)]
        slothy.config.sw_pipelining.enabled = False
        slothy.config.inputs_are_outputs = False
        slothy.optimize(start="ntt_kyber_123_4567_postamble", end="ntt_kyber_123_4567_end")

        # slothy.config.sw_pipelining.enabled = True
        # slothy.config.inputs_are_outputs = True
        # slothy.config.sw_pipelining.optimize_preamble = True
        # slothy.config.sw_pipelining.optimize_postamble = True
        # slothy.optimize(start=""layer4567_start")

#############################################################################################

def main():
    examples = [ # Kyber Neon NTT
                 # Cortex-A72
                 ntt_kyber_123_4567(target=Target_CortexA72_Frontend)
                ]

    all_example_names = [ e.name for e in examples ]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        "--examples", type=str, default="all",
        help=f"The list of examples to be run, comma-separated list from {all_example_names}."
    )
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--no-log", default=False, action='store_true',
                        help="Don't store logfiles")
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
        ex.run(silent=silent, no_log=args.no_log)

    for e in todo:
        for _ in range(iterations):
            run_example(e, silent=args.silent)

if __name__ == "__main__":
   main()

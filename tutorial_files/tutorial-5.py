import logging
import sys

sys.path.append("/")
from slothy import Slothy

import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55

logging.basicConfig(stream=sys.stdout, level=logging.INFO)

arch = AArch64_Neon
target = Target_CortexA55

slothy = Slothy(arch, target)

# example
slothy.load_source_from_file("../examples/naive/aarch64/aarch64_simple0_loop.s")
slothy.config.variable_size=True
slothy.config.constraints.stalls_first_attempt=32

slothy.config.sw_pipelining.enabled = True
slothy.config.sw_pipelining.optimize_preamble = False
slothy.config.sw_pipelining.optimize_postamble = False
slothy.config.with_llvm_mca = True
slothy.optimize_loop("start")
slothy.write_source_to_file("opt/aarch64_simple0_loop_opt_mca_a55.s")

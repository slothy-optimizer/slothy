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
slothy.load_source_from_file("../examples/naive/aarch64/ntt_kyber_123_4567.s")
slothy.config.sw_pipelining.enabled = True
slothy.config.inputs_are_outputs = True
slothy.config.sw_pipelining.minimize_overlapping = False
slothy.config.variable_size = True
slothy.config.reserved_regs = [f"x{i}" for i in range(0, 7)] + ["x30", "sp"]
slothy.config.constraints.stalls_first_attempt = 64
slothy.optimize_loop("layer123_start")
slothy.optimize_loop("layer4567_start")
slothy.write_source_to_file("opt/ntt_kyber_123_4567_opt_a55.s")

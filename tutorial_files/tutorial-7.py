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
slothy.load_source_from_file("../examples/naive/aarch64/X25519-AArch64-simple.s")

# first pass: replace symbolic register names by architectural registers
slothy.config.inputs_are_outputs=True
slothy.config.outputs=["x0"]
slothy.config.constraints.functional_only = True
slothy.config.constraints.allow_reordering = False
slothy.optimize(start="mainloop", end="end_label")
slothy.config.constraints.functional_only = False
slothy.config.constraints.allow_reordering = True

# second pass: splitting heuristic
slothy.config.variable_size=True
slothy.config.constraints.stalls_first_attempt=32
slothy.config.split_heuristic = True
slothy.config.split_heuristic_stepsize = 0.05
slothy.config.split_heuristic_factor = 10
slothy.config.split_heuristic_repeat = 2
slothy.config.split_heuristic_estimate_performance = False
slothy.optimize(start="mainloop", end="end_label")
slothy.write_source_to_file("opt/X25519-AArch64-simple_opt.s")

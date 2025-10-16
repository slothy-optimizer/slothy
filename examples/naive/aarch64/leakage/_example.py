import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.aarch64.aarch64_neon as AArch64_Neon
import slothy.targets.aarch64.cortex_a55 as Target_CortexA55

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class leakage(OptimizationRunner):
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None
    ):
        name = "leakage"
        infile = name

        super().__init__(
            infile,
            name,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            subfolder=SUBFOLDER,
            var=var,
        )

    def core(self, slothy):
        slothy.config.outputs = ["x4", "x5"]

        # x0 and x1 are two shares of secret 'a', x2 is public
        slothy.config.secret_inputs = {
            "a": [["x0"], ["x1"]]  # 2 shares, each share uses 1 register
        }
        slothy.config.public_inputs = {"x2"}

        slothy.optimize()


example_instances = [
    leakage(),
]

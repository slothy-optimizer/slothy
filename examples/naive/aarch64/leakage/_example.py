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
        slothy.config.outputs = ["x4", "x5", "x6", "x7", "x8", "x11"]

        # x0, x1 are shares of secret 'a'
        # x2, x3 are shares of secret 'b'
        # x9, x10 are public inputs
        # x4 = a[0] + b[0] - depends on both a and b (share 0 of each)
        # x5 = a[1] + b[1] - depends on both a and b (share 1 of each)
        # x6 = x4 + x4 = 2*(a[0] + b[0]) - still depends on a[0] and b[0]
        # x7 = x5 + x5 = 2*(a[1] + b[1]) - still depends on a[1] and b[1]
        # x8 = x9 + x10 - public + public = no masking info (public)
        # x11 = x8 + x8 - public + public = no masking info (public)
        slothy.config.secret_inputs = {
            "a": [["x0"], ["x1"]],  # 2 shares, each share uses 1 register
            "b": [["x2"], ["x3"]]
        }
        slothy.config.public_inputs = {"x9", "x10"}

        slothy.optimize()


class leakage_rule_2(OptimizationRunner):
    """Example that violates rule 2: mixing shares of the same secret - should error"""
    def __init__(
        self, var="", arch=AArch64_Neon, target=Target_CortexA55, timeout=None
    ):
        name = "leakage_rule_2"
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
        slothy.config.outputs = ["x4"]

        # This violates rule 2: mixing share0 (x0) and share1 (x1) of the same secret
        slothy.config.secret_inputs = {
            "a": [["x0"], ["x1"]]
        }

        slothy.optimize()


example_instances = [
    leakage(),
    # leakage_rule_2(),  # Uncomment to test rule 2 violation detection
]

import os

from common.OptimizationRunner import OptimizationRunner

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class ntt_n256_l6_s32(OptimizationRunner):
    def __init__(self, var):
        super().__init__(f"ntt_n256_l6_s32_{var}", subfolder=SUBFOLDER)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")


class ntt_n256_l8_s32(OptimizationRunner):
    def __init__(self, var):
        super().__init__(f"ntt_n256_l8_s32_{var}", subfolder=SUBFOLDER)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.optimize_loop("layer78_loop")


class intt_n256_l6_s32(OptimizationRunner):
    def __init__(self, var):
        super().__init__(f"intt_n256_l6_s32_{var}", subfolder=SUBFOLDER)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")


class intt_n256_l8_s32(OptimizationRunner):
    def __init__(self, var):
        super().__init__(f"intt_n256_l8_s32_{var}", subfolder=SUBFOLDER)

    def core(self, slothy):
        slothy.config.sw_pipelining.enabled = True
        slothy.config.inputs_are_outputs = True
        slothy.optimize_loop("layer12_loop")
        slothy.optimize_loop("layer34_loop")
        slothy.optimize_loop("layer56_loop")
        slothy.optimize_loop("layer78_loop")


# example_instances = [obj() for _, obj in globals().items()
#            if inspect.isclass(obj) and obj.__module__ == __name__]

example_instances = [
    ntt_n256_l6_s32("bar"),
    ntt_n256_l6_s32("mont"),
    ntt_n256_l8_s32("bar"),
    ntt_n256_l8_s32("mont"),
    intt_n256_l6_s32("bar"),
    intt_n256_l6_s32("mont"),
    intt_n256_l8_s32("bar"),
    intt_n256_l8_s32("mont"),
]

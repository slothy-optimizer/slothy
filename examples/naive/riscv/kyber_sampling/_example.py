import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_cbd2_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_cbd2_rvv_vlen128"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            funcname="cbd2_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        import slothy.targets.riscv.xuantie_c908 as target_module

        #target_module.lmul = 8
        #target_module.sew = 16

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        #slothy.config.sw_pipelining.enabled = True
        #slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("cbd2_rvv_vlen128_loop")


class RISC_V_cbd3_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_cbd3_rvv_vlen128"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            funcname="cbd3_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("cbd3_rvv_vlen128_loop")


class RISC_V_rej_uniform_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_rej_uniform_rvv_vlen128"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            funcname="rej_uniform_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.with_preprocessor = True

        r = slothy.config.reserved_regs
        # x3 (gp) is reserved by convention. x15 (a5) and x16 (a6) hold the
        # output/input buffer base pointers: they are set before the loop and
        # read by the loop-bound checks after each region (sub t2,a0,a5 /
        # sub t3,a1,a6), but are not used inside the optimized bodies. Without
        # reserving them SLOTHY may allocate them as scratch, clobbering the
        # bases so the loop miscounts and exits early.
        r += ["x3", "x15", "x16"]
        slothy.config.reserved_regs = r

        slothy.optimize(start="start", end="end")
        slothy.optimize(start="start_x2", end="end_x2")
        slothy.optimize(start="start_x1", end="end_x1")


example_instances = [
    RISC_V_cbd2_rvv_vlen128(),
    RISC_V_cbd3_rvv_vlen128(),
    RISC_V_rej_uniform_rvv_vlen128(),
]

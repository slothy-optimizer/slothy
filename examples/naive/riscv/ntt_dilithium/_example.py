import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_ntt8l_singleissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "ntt_dilithium_8l_singleissue_plant_rv64im"
        # subpath = "ntt_dilithium/"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        # name += f"_{target_label_dict[target]}"

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            funcname="ntt_8l_rv64im",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05
        # slothy.config.split_heuristic_factor = 10
        # slothy.config.split_heuristic_repeat = 1
        # slothy.config.split_heuristic_stepsize = 0.3
        slothy.optimize_loop("ntt_8l_rv64im_loop1")
        slothy.optimize_loop("ntt_8l_rv64im_loop2")


class RISC_V_ntt8l_dualissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "ntt_dilithium_8l_dualissue_plant_rv64im"
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
            funcname="ntt_8l_dual_rv64im",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05
        # slothy.config.split_heuristic_factor = 10
        # slothy.config.split_heuristic_repeat = 1
        # slothy.config.split_heuristic_stepsize = 0.3
        slothy.optimize_loop("ntt_8l_rv64im_loop1")
        slothy.optimize_loop("ntt_8l_rv64im_loop2")


class RISC_V_intt8l_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "intt_dilithium_8l_plant_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            funcname="intt_dilithium_8l_plant_rv64im",
            timeout=timeout,
            var=var,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05
        # slothy.config.split_heuristic_factor = 10
        # slothy.config.split_heuristic_repeat = 1
        # slothy.config.split_heuristic_stepsize = 0.3
        slothy.optimize_loop("intt_rv64im_loop1")
        slothy.optimize_loop("intt_rv64im_loop2")


example_instances = [
    RISC_V_ntt8l_singleissue_plant_rv64im(target=Target_XuanTieC908, timeout=300),
    RISC_V_ntt8l_dualissue_plant_rv64im(timeout=300),
    RISC_V_intt8l_plant_rv64im(timeout=300),
    RISC_V_intt8l_plant_rv64im(timeout=300, var="dual"),
]

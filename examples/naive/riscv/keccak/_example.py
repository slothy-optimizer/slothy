import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_fips202_rv32im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "fips202_rv32im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            funcname="KeccakF1600_StatePermute_RV32ASM",
            var=var,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("loop_start")


example_instances = [
    RISC_V_fips202_rv32im(),
]

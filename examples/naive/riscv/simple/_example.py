import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_VExample0(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908):
        name = "riscv_simple0"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        # name += f"_{target_label_dict[target]}"

        super().__init__(
            infile, name, subfolder=SUBFOLDER, rename=True, arch=arch, target=target
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.outputs = [
            "v0",
            "v1",
            "v2",
            "v3",
            "v4",
            "v5",
            "v6",
            "v7",
            "v8",
            "v9",
            "v10",
            "v11",
        ]
        slothy.optimize()


class RISC_VExampleLoop0(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908):
        name = "riscv_simple_loop0"
        infile = name

        if var != "":
            name += f"_{var}"
            infile += f"_{var}"
        # name += f"_{target_label_dict[target]}"

        super().__init__(
            infile, name, subfolder=SUBFOLDER, rename=True, arch=arch, target=target
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.inputs_are_outputs = True

        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("my_loop")
        slothy.optimize_loop("my_loop2")
        slothy.optimize_loop("my_loop3")


class RISC_V_test(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "riscv_test"
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
            funcname="test",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = [
            "x1",
            "x2",
            "x3",
            "x4",
            "x5",
            "x6",
            "x7",
            "x8",
            "x9",
            "x10",
            "x11",
            "x12",
            "x13",
            "x14",
            "x15",
            "x16",
            "x17",
            "x18",
            "x19",
            "x20",
            "x21",
            "x22",
            "x23",
            "x24",
            "x25",
            "x26",
            "x27",
            "x28",
            "x29",
            "x30",
            "x31",
        ]
        slothy.optimize(start="start_label", end="end_label")


example_instances = [
    RISC_VExample0(target=Target_XuanTieC908),
    RISC_VExampleLoop0(),
    RISC_V_test(target=Target_XuanTieC908),
]

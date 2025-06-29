import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_poly_basemul_8l_init_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_8l_init_rv64im"
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
            timeout=timeout,
            funcname="poly_basemul_8l_init_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_8l_init_rv64im_looper")


class RISC_V_poly_basemul_8l_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_8l_rv64im"
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
            timeout=timeout,
            funcname="poly_basemul_8l_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_8l_rv64im_looper")


class RISC_V_poly_basemul_8l_acc_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_8l_acc_rv64im"
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
            timeout=timeout,
            funcname="poly_basemul_8l_acc_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_8l_acc_rv64im_looper")


class RISC_V_poly_basemul_8l_acc_end_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_8l_acc_end_rv64im"
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
            timeout=timeout,
            funcname="poly_basemul_8l_acc_end_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = ["x3"]
        slothy.optimize_loop("poly_basemul_8l_acc_end_rv64im_looper")


class RISC_V_poly_reduce_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_reduce_rv64im"
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
            timeout=timeout,
            funcname="poly_reduce_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = ["x3"]
        slothy.optimize_loop("poly_reduce_rv64im_loop")


class RISC_V_poly_basemul_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_rvv_vlen128"
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
            timeout=timeout,
            funcname="poly_basemul_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = ["x3"]
        slothy.optimize_loop("poly_basemul_rvv_vlen128_loop")


class RISC_V_poly_basemul_acc_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "dilithium_poly_basemul_acc_rvv_vlen128"
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
            timeout=timeout,
            funcname="poly_basemul_acc_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.config.outputs = ["x3"]
        slothy.optimize_loop("poly_basemul_acc_rvv_vlen128_loop")


example_instances = [
    RISC_V_poly_basemul_8l_init_rv64im(),
    RISC_V_poly_basemul_8l_rv64im(),
    RISC_V_poly_basemul_8l_acc_rv64im(),
    RISC_V_poly_basemul_8l_acc_end_rv64im(),
    RISC_V_poly_reduce_rv64im(),
    RISC_V_poly_basemul_8l_init_rv64im(var="dual"),
    RISC_V_poly_basemul_8l_rv64im(var="dual"),
    RISC_V_poly_basemul_8l_acc_rv64im(var="dual"),
    RISC_V_poly_basemul_8l_acc_end_rv64im(var="dual"),
    RISC_V_poly_reduce_rv64im(var="dual"),
    # RVV
    RISC_V_poly_basemul_rvv_vlen128(),
    RISC_V_poly_basemul_acc_rvv_vlen128(),
]

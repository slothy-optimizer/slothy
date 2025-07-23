import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_poly_basemul_acc_cache_end_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cache_end_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cache_end_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        loop_control = "x17" if self.var == "dual" else "x16"
        r = slothy.config.reserved_regs
        r += [loop_control]  # loop control
        slothy.config.reserved_regs = r
        # slothy.config.reserved_regs_are_locked = False

        slothy.config.constraints.allow_reordering = True
        slothy.config.constraints.allow_renaming = True
        slothy.optimize_loop("poly_basemul_acc_cache_end_rv64im_loop")


class RISC_V_poly_basemul_acc_cache_init_end_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cache_init_end_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cache_init_end_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        loop_control = "x17" if self.var == "dual" else "x16"
        r = slothy.config.reserved_regs
        r += [loop_control]  # loop control
        slothy.config.reserved_regs = r
        slothy.config.reserved_regs_are_locked = False
        slothy.optimize_loop("poly_basemul_acc_cache_init_end_rv64im_loop")


class RISC_V_poly_basemul_acc_cache_init_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cache_init_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cache_init_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x16"]  # loop control
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_acc_cache_init_rv64im_loop")


class RISC_V_poly_basemul_acc_cached_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cached_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cached_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x16"]  # loop control
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_acc_cached_rv64im_loop")


class RISC_V_poly_basemul_acc_end_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_end_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_end_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        loop_control = "x17" if self.var == "dual" else "x16"
        r = slothy.config.reserved_regs
        r += [loop_control]  # loop control
        slothy.config.reserved_regs = r
        slothy.config.reserved_regs_are_locked = False
        slothy.optimize_loop("poly_basemul_acc_end_rv64im_loop")


class RISC_V_poly_basemul_acc_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x16"]  # loop control
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_acc_rv64im_loop")


class RISC_V_poly_basemul_cache_init_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_cache_init_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_cache_init_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x16"]  # loop control
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_basemul_cache_init_rv64im_loop")


class RISC_V_poly_plantard_rdc_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_plantard_rdc_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_plantard_rdc_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_plantard_rdc_rv64im_loop")


class RISC_V_poly_toplant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_toplant_rv64im"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_toplant_rv64im",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True
        slothy.config.sw_pipelining.enabled = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_toplant_rv64im_loop")


# RVV


class RISC_V_poly_basemul_acc_cache_init_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cache_init_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cache_init_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.unsafe_address_offset_fixup = False

        # slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop(
            "poly_basemul_acc_cache_init_rvv_vlen128_loop",
            forced_loop_type=RISC_V.BranchLoop,
        )


class RISC_V_poly_basemul_cache_init_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_cache_init_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_cache_init_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop(
            "poly_basemul_cache_init_rvv_vlen128_loop",
            forced_loop_type=RISC_V.BranchLoop,
        )


class RISC_V_poly_basemul_acc_cached_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_cached_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_cached_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop(
            "poly_basemul_acc_cached_rvv_vlen128_loop",
            forced_loop_type=RISC_V.BranchLoop,
        )


class RISC_V_poly_basemul_cached_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_cached_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_cached_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop(
            "poly_basemul_cached_rvv_vlen128_loop", forced_loop_type=RISC_V.BranchLoop
        )


class RISC_V_poly_basemul_acc_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_acc_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_acc_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop(
            "poly_basemul_acc_rvv_vlen128_loop", forced_loop_type=RISC_V.BranchLoop
        )


class RISC_V_poly_basemul_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_basemul_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_basemul_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop(
            "poly_basemul_rvv_vlen128_loop", forced_loop_type=RISC_V.BranchLoop
        )


class RISC_V_poly_reduce_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_reduce_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_reduce_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_reduce_rvv_vlen128_loop")


class RISC_V_poly_tomont_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_poly_tomont_rvv_vlen128"
        infile = name

        super().__init__(
            infile,
            name,
            subfolder=SUBFOLDER,
            rename=True,
            arch=arch,
            target=target,
            timeout=timeout,
            var=var,
            funcname="poly_tomont_rvv_vlen128",
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r
        slothy.optimize_loop("poly_tomont_rvv_vlen128")


example_instances = [
    RISC_V_poly_basemul_acc_cache_end_rv64im(),
    RISC_V_poly_basemul_acc_cache_end_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_acc_cache_init_end_rv64im(),
    RISC_V_poly_basemul_acc_cache_init_end_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_acc_cache_init_rv64im(),
    RISC_V_poly_basemul_acc_cache_init_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_acc_cached_rv64im(),
    RISC_V_poly_basemul_acc_cached_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_acc_end_rv64im(),
    RISC_V_poly_basemul_acc_end_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_acc_rv64im(),
    RISC_V_poly_basemul_acc_rv64im(var="dual", timeout=300),
    RISC_V_poly_basemul_cache_init_rv64im(),
    RISC_V_poly_basemul_cache_init_rv64im(var="dual", timeout=300),
    RISC_V_poly_plantard_rdc_rv64im(),
    RISC_V_poly_plantard_rdc_rv64im(var="dual", timeout=300),
    RISC_V_poly_toplant_rv64im(),
    RISC_V_poly_toplant_rv64im(var="dual", timeout=300),
    # RVV
    RISC_V_poly_basemul_acc_cache_init_rvv_vlen128(),
    RISC_V_poly_basemul_acc_cached_rvv_vlen128(),
    RISC_V_poly_basemul_acc_rvv_vlen128(),
    RISC_V_poly_basemul_rvv_vlen128(),
    RISC_V_poly_basemul_cached_rvv_vlen128(),
    RISC_V_poly_basemul_cache_init_rvv_vlen128(),
    RISC_V_poly_reduce_rvv_vlen128(),
    RISC_V_poly_tomont_rvv_vlen128(),
]

import os

from common.OptimizationRunner import OptimizationRunner
import slothy.targets.riscv.riscv as RISC_V
import slothy.targets.riscv.xuantie_c908 as Target_XuanTieC908

SUBFOLDER = os.path.basename(os.path.dirname(__file__)) + "/"


class RISC_V_ntt_singleissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "ntt_kyber_singleissue_plant_rv64im"
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
            funcname="ntt_rv64im",
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
        slothy.optimize_loop("ntt_rv64im_loop1")
        slothy.optimize_loop("ntt_rv64im_loop2")


class RISC_V_ntt_dualissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "ntt_kyber_dualissue_plant_rv64im"
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
            funcname="ntt_dual_rv64im",
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
        slothy.optimize_loop("ntt_rv64im_loop1")
        slothy.optimize_loop("ntt_rv64im_loop2")


class RISC_V_intt_singleissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "intt_kyber_singleissue_plant_rv64im"
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
            funcname="intt_rv64im",
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
        # slothy.config.split_heuristic_factor = 5
        # slothy.config.split_heuristic_repeat = 2
        # slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_factor = 10
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_stepsize = 0.3
        slothy.optimize_loop("intt_rv64im_loop1")
        slothy.optimize_loop("intt_rv64im_loop2")


class RISC_V_intt_dualissue_plant_rv64im(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "intt_kyber_dualissue_plant_rv64im"
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
            funcname="intt_rv64im",
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
        # slothy.config.split_heuristic_factor = 5
        # slothy.config.split_heuristic_repeat = 2
        # slothy.config.split_heuristic_stepsize = 0.05
        slothy.config.split_heuristic_factor = 10
        slothy.config.split_heuristic_repeat = 1
        slothy.config.split_heuristic_stepsize = 0.3
        slothy.optimize_loop("intt_rv64im_loop1")
        slothy.optimize_loop("intt_rv64im_loop2")


class RISC_V_ntt_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "ntt_kyber_rvv_vlen128"
        infile = name + "_unfolded"

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
            funcname="ntt_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        #        import slothy.targets.riscv.xuantie_c908 as target_module

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        slothy.config.allow_useless_instructions = True

        # NOTE: software pipelining is intentionally disabled here.
        # The source region (start..end) is straight-line code: it covers
        # the entire Kyber NTT body and is *not* wrapped in a loop. With
        # sw_pipelining.enabled + halving_heuristic, slothy lays the
        # output out as preamble | kernel | postamble and expects the
        # caller to wrap the kernel in a runtime loop. Because no loop
        # branch is emitted, the kernel runs exactly once instead of the
        # intended (N-1) times, so the total work becomes
        #   preamble + 1*kernel + postamble = N+1 iterations
        # rather than the N iterations the source represents. For the
        # Kyber NTT (N = 2: P0 and P1 halves of levels 1..6) this
        # produces an extra full NTT pass on top of the correct result.
        # See docs/SLOTHY_KYBER_NTT_BUG.md for the full write-up.
        # The matching dilithium RVV NTT config (ntt_dilithium/_example.py
        # :: RISC_V_ntt_rvv_vlen128) keeps these two lines commented out
        # for the same reason.
        # slothy.config.sw_pipelining.enabled = True
        # slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 10
        slothy.config.split_heuristic_repeat = 3
        slothy.config.split_heuristic_stepsize = 0.05
        # slothy.config.split_heuristic_preprocess_naive_interleaving = True
        slothy.config.split_heuristic_estimate_performance = False
        slothy.config.constraints.stalls_maximum_attempt = 4096

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.outputs = ["x17"]
        slothy.config.reserved_regs = r
        # target_module.lmul = 8
        # slothy.optimize("start_1", "end_1")
        # target_module.lmul = 8
        # slothy.optimize("start_2", "end_2")
        # target_module.lmul = 4
        # slothy.optimize("start_3", "end_3")
        # target_module.lmul = 1
        # slothy.optimize("start_4", "end_4")
        # target_module.lmul = 8
        # slothy.optimize("start_5", "end_5")
        # target_module.lmul = 4
        # slothy.optimize("start_6", "end_6")
        # target_module.lmul = 1
        # slothy.optimize("start_7", "end_7")
        slothy.optimize("start", "end")


class RISC_V_intt_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "intt_kyber_rvv_vlen128"
        infile = name + "_unfolded"

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
            funcname="intt_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        slothy.config.allow_useless_instructions = True

        # WARNING: same caveat as RISC_V_ntt_rvv_vlen128.core() above.
        # Each start_N/end_N region is straight-line (no loop branch),
        # so software pipelining on each of them produces preamble |
        # kernel | postamble code that the asm file does not wrap in a
        # runtime loop. If you observe correctness issues in the
        # generated intt asm, disable these two lines and re-run.
        # See docs/SLOTHY_KYBER_NTT_BUG.md for details.
        slothy.config.sw_pipelining.enabled = True
        slothy.config.sw_pipelining.halving_heuristic = True
        slothy.config.split_heuristic = True
        slothy.config.split_heuristic_factor = 5
        slothy.config.split_heuristic_repeat = 2
        slothy.config.split_heuristic_stepsize = 0.05
        import slothy.targets.riscv.xuantie_c908 as target_module

        slothy.config.outputs = ["x17"]  # TODO: this does not do anything
        r = slothy.config.reserved_regs
        r += ["x3"]

        slothy.config.reserved_regs = r
        target_module.lmul = 8
        slothy.optimize("start_1", "end_1")
        target_module.lmul = 1
        slothy.optimize("start_2", "end_2")
        target_module.lmul = 8
        slothy.optimize("start_3", "end_3")
        target_module.lmul = 1
        slothy.optimize("start_4", "end_4")
        target_module.lmul = 8
        slothy.optimize("start_5", "end_5")


class RISC_V_kyber_normal2ntt_order_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_normal2ntt_order_rvv_vlen128"
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
            funcname="normal2ntt_order_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        import slothy.targets.riscv.xuantie_c908 as target_module

        target_module.lmul = 1

        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        slothy.config.allow_useless_instructions = True
        slothy.config.outputs = ["x17"]
        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("normal2ntt_order_rvv_vlen128_loop")


class RISC_V_kyber_ntt2normal_order_rvv_vlen128(OptimizationRunner):
    def __init__(self, var="", arch=RISC_V, target=Target_XuanTieC908, timeout=None):
        name = "kyber_ntt2normal_order_rvv_vlen128"
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
            funcname="ntt2normal_order_rvv_vlen128",
            timeout=timeout,
        )

    def core(self, slothy):
        slothy.config.variable_size = True
        slothy.config.constraints.stalls_first_attempt = 32
        slothy.config.inputs_are_outputs = True

        slothy.config.allow_useless_instructions = True
        slothy.config.outputs = ["x17"]

        r = slothy.config.reserved_regs
        r += ["x3"]
        slothy.config.reserved_regs = r

        slothy.config.sw_pipelining.enabled = True

        slothy.optimize_loop("ntt2normal_order_rvv_vlen128_loop")


example_instances = [
    RISC_V_ntt_singleissue_plant_rv64im(target=Target_XuanTieC908, timeout=300),
    RISC_V_ntt_dualissue_plant_rv64im(timeout=300),
    RISC_V_intt_dualissue_plant_rv64im(),
    RISC_V_intt_singleissue_plant_rv64im(),
    RISC_V_ntt_rvv_vlen128(target=Target_XuanTieC908, timeout=300),
    RISC_V_intt_rvv_vlen128(),
    RISC_V_kyber_normal2ntt_order_rvv_vlen128(),
    RISC_V_kyber_ntt2normal_order_rvv_vlen128(),
]

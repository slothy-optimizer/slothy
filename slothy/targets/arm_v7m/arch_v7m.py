import logging
import inspect
import re
import math
import itertools
from enum import Enum
from functools import cache

from unicorn import (
    UC_ARCH_ARM,
    UC_MODE_THUMB,
    UC_MODE_MCLASS,
)

from unicorn.arm_const import (
    UC_ARM_REG_LR,
    UC_ARM_REG_PC,
    UC_ARM_REG_SP,
    UC_ARM_REG_R0,
    UC_ARM_REG_R1,
    UC_ARM_REG_R2,
    UC_ARM_REG_R3,
    UC_ARM_REG_R4,
    UC_ARM_REG_R5,
    UC_ARM_REG_R6,
    UC_ARM_REG_R7,
    UC_ARM_REG_R8,
    UC_ARM_REG_R9,
    UC_ARM_REG_R10,
    UC_ARM_REG_R11,
    UC_ARM_REG_R12,
    UC_ARM_REG_S0,
    UC_ARM_REG_S1,
    UC_ARM_REG_S2,
    UC_ARM_REG_S3,
    UC_ARM_REG_S4,
    UC_ARM_REG_S5,
    UC_ARM_REG_S6,
    UC_ARM_REG_S7,
    UC_ARM_REG_S8,
    UC_ARM_REG_S9,
    UC_ARM_REG_S10,
    UC_ARM_REG_S11,
    UC_ARM_REG_S12,
    UC_ARM_REG_S13,
    UC_ARM_REG_S14,
    UC_ARM_REG_S15,
    UC_ARM_REG_S16,
    UC_ARM_REG_S17,
    UC_ARM_REG_S18,
    UC_ARM_REG_S19,
    UC_ARM_REG_S20,
    UC_ARM_REG_S21,
    UC_ARM_REG_S22,
    UC_ARM_REG_S23,
    UC_ARM_REG_S24,
    UC_ARM_REG_S25,
    UC_ARM_REG_S26,
    UC_ARM_REG_S27,
    UC_ARM_REG_S28,
    UC_ARM_REG_S29,
    UC_ARM_REG_S30,
    UC_ARM_REG_S31,
)

from slothy.helper import SourceLine, Loop
from sympy import simplify

arch_name = "Arm_v7M"
llvm_mca_arch = "arm"
llvm_mc_arch = "thumb"
llvm_mc_attr = "armv7e-m,thumb2,dsp,fpregs"

unicorn_arch = UC_ARCH_ARM
unicorn_mode = UC_MODE_THUMB | UC_MODE_MCLASS


class RegisterType(Enum):
    GPR = 1
    FPR = 2
    FLAGS = 3
    HINT = 4

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    @cache
    def _spillable(reg_type):
        return reg_type in [RegisterType.GPR]

    # TODO: remove workaround (needed for Python 3.9)
    spillable = staticmethod(_spillable)

    @staticmethod
    def callee_saved_registers():
        return [f"r{i}" for i in range(4, 12)] + [f"s{i}" for i in range(0, 16)]

    @staticmethod
    def unicorn_link_register():
        return UC_ARM_REG_LR

    @staticmethod
    def unicorn_program_counter():
        return UC_ARM_REG_PC

    @staticmethod
    def unicorn_stack_pointer():
        return UC_ARM_REG_SP

    @cache
    def _unicorn_reg_by_name(reg):
        """Converts string name of register into numerical identifiers used
        within the unicorn engine"""

        d = {
            "r0": UC_ARM_REG_R0,
            "r1": UC_ARM_REG_R1,
            "r2": UC_ARM_REG_R2,
            "r3": UC_ARM_REG_R3,
            "r4": UC_ARM_REG_R4,
            "r5": UC_ARM_REG_R5,
            "r6": UC_ARM_REG_R6,
            "r7": UC_ARM_REG_R7,
            "r8": UC_ARM_REG_R8,
            "r9": UC_ARM_REG_R9,
            "r10": UC_ARM_REG_R10,
            "r11": UC_ARM_REG_R11,
            "r12": UC_ARM_REG_R12,
            "r13": UC_ARM_REG_SP,
            "r14": UC_ARM_REG_LR,
            "s0": UC_ARM_REG_S0,
            "s1": UC_ARM_REG_S1,
            "s2": UC_ARM_REG_S2,
            "s3": UC_ARM_REG_S3,
            "s4": UC_ARM_REG_S4,
            "s5": UC_ARM_REG_S5,
            "s6": UC_ARM_REG_S6,
            "s7": UC_ARM_REG_S7,
            "s8": UC_ARM_REG_S8,
            "s9": UC_ARM_REG_S9,
            "s10": UC_ARM_REG_S10,
            "s11": UC_ARM_REG_S11,
            "s12": UC_ARM_REG_S12,
            "s13": UC_ARM_REG_S13,
            "s14": UC_ARM_REG_S14,
            "s15": UC_ARM_REG_S15,
            "s16": UC_ARM_REG_S16,
            "s17": UC_ARM_REG_S17,
            "s18": UC_ARM_REG_S18,
            "s19": UC_ARM_REG_S19,
            "s20": UC_ARM_REG_S20,
            "s21": UC_ARM_REG_S21,
            "s22": UC_ARM_REG_S22,
            "s23": UC_ARM_REG_S23,
            "s24": UC_ARM_REG_S24,
            "s25": UC_ARM_REG_S25,
            "s26": UC_ARM_REG_S26,
            "s27": UC_ARM_REG_S27,
            "s28": UC_ARM_REG_S28,
            "s29": UC_ARM_REG_S29,
            "s30": UC_ARM_REG_S30,
            "s31": UC_ARM_REG_S31,
        }
        return d.get(reg, None)

    # TODO: remove workaround (needed for Python 3.9)
    unicorn_reg_by_name = staticmethod(_unicorn_reg_by_name)

    @cache
    def _list_registers(
        reg_type, only_extra=False, only_normal=False, with_variants=False
    ):
        """Return the list of all registers of a given type"""

        gprs_normal = [f"r{i}" for i in range(15)]
        fprs_normal = [f"s{i}" for i in range(32)]

        gprs_extra = []
        fprs_extra = []

        gprs = []
        fprs = []
        # TODO: What are hints?
        hints = (
            [f"t{i}" for i in range(100)]
            + [f"t{i}{j}" for i in range(8) for j in range(8)]
            + [f"t{i}_{j}" for i in range(16) for j in range(16)]
        )

        flags = ["flags"]
        if not only_extra:
            gprs += gprs_normal
            fprs += fprs_normal
        if not only_normal:
            gprs += gprs_extra
            fprs += fprs_extra

        return {
            RegisterType.GPR: gprs,
            RegisterType.FPR: fprs,
            RegisterType.HINT: hints,
            RegisterType.FLAGS: flags,
        }[reg_type]

    # TODO: remove workaround (needed for Python 3.9)
    list_registers = staticmethod(_list_registers)

    @staticmethod
    def find_type(r):
        """Find type of architectural register"""

        if r.startswith("hint_"):
            return RegisterType.HINT

        for ty in RegisterType:
            if r in RegisterType.list_registers(ty):
                return ty

        return None

    @staticmethod
    def is_renamed(ty):
        """Indicate if register type should be subject to renaming"""
        if ty == RegisterType.HINT:
            return False
        return True

    @staticmethod
    def from_string(string):
        """Find registe type from string"""
        string = string.lower()
        return {
            "fpr": RegisterType.FPR,
            "gpr": RegisterType.GPR,
            "hint": RegisterType.HINT,
            "flags": RegisterType.FLAGS,
        }.get(string, None)

    @staticmethod
    def default_reserved():
        """Return the list of registers that should be reserved by default"""
        # r13 is the stack pointer
        return set(["flags", "r13"] + RegisterType.list_registers(RegisterType.HINT))

    @staticmethod
    def default_aliases():
        "Register aliases used by the architecture"
        return {
            "lr": "r14",
        }


# TODO: Comparison can also be done with {add,sub,...}s
class Branch:
    """Helper for emitting branches"""

    @staticmethod
    def if_equal(cnt, val, lbl):
        """Emit assembly for a branch-if-equal sequence"""
        yield f"cmp {cnt}, #{val}"
        yield f"beq {lbl}"

    @staticmethod
    def if_greater_equal(cnt, val, lbl):
        """Emit assembly for a branch-if-greater-equal sequence"""
        yield f"cmp {cnt}, #{val}"
        yield f"bge {lbl}"

    @staticmethod
    def unconditional(lbl):
        """Emit unconditional branch"""
        yield f"b {lbl}"


class VmovCmpLoop(Loop):
    """
    Loop ending in a vmov, a compare, and a branch.

    The modification to the value we compare against happens inside the loop
    body. The value that is being compared to is stashed to a floating point
    register before the loop starts and therefore needs to be recovered before
    the comparison.

    .. warning::

        This type of loop is experimental as slothy has no knowledge about
        what happens inside the loop boundary! Especially, a register is written
        inside the boundary which may be used for renaming by slothy. Use with
        caution.

    Example:

    .. code-block:: asm

        loop_lbl:
           {code}
           vmov <end>, <endf>
           cmp <cnt>, <end>
           (cbnz|bnz|bne) loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl="lbl", lbl_start="1", lbl_end="2", loop_init="lr") -> None:
        super().__init__(lbl_start=lbl_start, lbl_end=lbl_end, loop_init=loop_init)
        self.lbl = lbl
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            r"^\s*vmov(?:\.w)?\s+(?P<end>\w+),\s*(?P<endf>\w+)",
            r"^\s*cmp(?:\.w)?\s+(?P<cnt>\w+),\s*(?P<end>\w+)",
            rf"^\s*(cbnz|cbz|bne)(?:\.w)?\s+{lbl}",
        )

    def start(
        self,
        loop_cnt,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        """Emit starting instruction(s) and jump label for loop"""
        indent = " " * indentation
        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield (
                f"{indent}lsr {self.additional_data['end']}, "
                f"{self.additional_data['end']}, #{int(math.log2(unroll))}"
            )

        # Find out by how much the loop counter is modified in one iteration
        inc_per_iter = 0
        if body_code is not None:
            try:
                loop_cnt_reg = register_aliases[loop_cnt]
            except KeyError:
                loop_cnt_reg = loop_cnt
            for line in body_code:
                if line.text == "":
                    continue
                inst = Instruction.parser(line)
                if (
                    loop_cnt_reg.lower() == inst[0].addr
                    and inst[0].increment is not None
                ):
                    inc_per_iter = inc_per_iter + simplify(inst[0].increment)
        logging.debug(
            f"Loop counter {loop_cnt} is incremented by {inc_per_iter} per iteration"
        )
        # Check whether instructions modifying the loop count moved to
        # pre/postamble and adjust the fixup based on that.
        # new_fixup = 0
        # if postamble_code is not None:
        #     new_fixup = 0
        #     for l in postamble_code:
        #         if l.text == "":
        #             continue
        #         inst = Instruction.parser(l)
        #         if loop_cnt in inst[0].args_in_out and inst[0].increment is not None:
        #             new_fixup = new_fixup + simplify(inst[0].increment)

        # if new_fixup != 0 or fixup != 0:
        if fixup != 0:
            yield f"{indent}push {{{self.additional_data['end']}}}"
            yield (
                f"{indent}vmov {self.additional_data['end']}, "
                f"{self.additional_data['endf']}"
            )

        # if new_fixup != 0:
        #     yield f"{indent}sub {self.additional_data['end']},
        #           {self.additional_data['end']}, #{new_fixup}"
        if fixup != 0:
            yield (
                f"{indent}sub {self.additional_data['end']}, "
                f"{self.additional_data['end']}, #{fixup*inc_per_iter}"
            )
        # if new_fixup != 0 or fixup != 0:
        if fixup != 0:
            yield (
                f"{indent}vmov {self.additional_data['endf']}, "
                f"{self.additional_data['end']}"
            )
            yield f"{indent}pop {{{self.additional_data['end']}}}"
        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        indent = " " * indentation
        lbl_start = self.lbl
        if lbl_start.isdigit():
            lbl_start += "b"

        yield f'{indent}vmov {other["end"]}, {other["endf"]}'
        yield f'{indent}cmp {other["cnt"]}, {other["end"]}'
        yield f"{indent}bne {lbl_start}"


class BranchLoop(Loop):
    """
    More general loop type that just considers the branch instruction as part
    of the boundary.
    This can help to improve performance as the instructions that belong to
    handling the loop can be considered by SLOTHY as well.

    .. note::

        This loop type is still rather experimental. It has a lot of logics
        inside as it needs to be able to "understand" a variety of different
        ways to express loops, e.g., how counters get incremented, how
        registers marking the end of the
        loop need to be modified in case of software pipelining etc.
        Currently, this type covers the three other types we offer
        above, namely `SubsLoop`, `CmpLoop`, and `VmovCmpLoop`.

    For examples, we refer to the classes `SubsLoop`, `CmpLoop`, and
    `VmovCmpLoop`.
    """

    def __init__(self, lbl="lbl", lbl_start="1", lbl_end="2", loop_init="lr") -> None:
        super().__init__(lbl_start=lbl_start, lbl_end=lbl_end, loop_init=loop_init)
        self.lbl = lbl
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        # Defines the end of the loop, boolean indicates whether the instruction
        # shall be considered part of the body or not.
        self.end_regex = ((rf"^\s*(cbnz|cbz|bne)(?:\.w)?\s+{lbl}", True),)

    def start(
        self,
        loop_cnt,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        """Emit starting instruction(s) and jump label for loop"""
        indent = " " * indentation
        if body_code is None:
            logging.debug("No body code in loop start: Just printing label.")
            yield f"{self.lbl}:"
            return
        # Identify the register that is used as a loop counter
        body_code = [line for line in body_code if line.text != ""]
        for line in body_code:
            inst = Instruction.parser(line)
            # Flags are set through cmp
            # LIMITATION: By convention, we require the first argument to be the
            # "counter" and the second the one marking the iteration end.
            if isinstance(inst[0], cmp):
                # Assume this mapping
                loop_cnt_reg = inst[0].args_in[0]
                loop_end_reg = inst[0].args_in[1]
                logging.debug(
                    f"Assuming {loop_cnt_reg} as counter register and {loop_end_reg} "
                    "as end register."
                )
                break
            # Flags are set through subs
            elif isinstance(inst[0], subs_imm_short):
                loop_cnt_reg = inst[0].args_in_out[0]
                loop_end_reg = inst[0].args_in_out[0]
                break
            elif isinstance(inst[0], subs_imm):
                loop_cnt_reg = inst[0].args_out[0]
                loop_end_reg = inst[0].args_out[0]
                break

        # Find FPR that is used to stash the loop end incase it's vmov loop
        loop_end_reg_fpr = None
        for li, l in enumerate(body_code):
            inst = Instruction.parser(l)
            # Flags are set through cmp
            if isinstance(inst[0], vmov_gpr):
                if loop_end_reg in inst[0].args_out:
                    logging.debug(f"Copying from {inst[0].args_in} to {loop_end_reg}")
                    loop_end_reg_fpr = inst[0].args_in[0]

            # The last vmov occurance before the cmp that writes to the register
            # we compare to will be the right one. The same GPR could be written
            # previously due to renaming, before it becomes the value used in
            # the cmp.
            if isinstance(inst[0], cmp):
                break

        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield f"{indent}lsr {loop_end_reg}, {loop_end_reg}, #{int(math.log2(unroll))}"

        inc_per_iter = 0
        for line in body_code:
            inst = Instruction.parser(line)
            # Increment happens through pointer modification
            if loop_cnt_reg.lower() == inst[0].addr and inst[0].increment is not None:
                inc_per_iter = inc_per_iter + simplify(inst[0].increment)
            # Increment through explicit modification
            elif (
                loop_cnt_reg.lower() in (inst[0].args_out + inst[0].args_in_out)
                and inst[0].immediate is not None
            ):
                # TODO: subtract if we have a subtraction
                inc_per_iter = inc_per_iter + simplify(inst[0].immediate)
        logging.debug(
            f"Loop counter {loop_cnt_reg} is incremented by {inc_per_iter} per iteration."
        )

        if fixup != 0 and loop_end_reg_fpr is not None:
            yield f"{indent}push {{{loop_end_reg}}}"
            yield f"{indent}vmov {loop_end_reg}, {loop_end_reg_fpr}"

        if fixup != 0:
            yield f"{indent}sub {loop_end_reg}, {loop_end_reg}, #{fixup*inc_per_iter}"

        if fixup != 0 and loop_end_reg_fpr is not None:
            yield f"{indent}vmov {loop_end_reg_fpr}, {loop_end_reg}"
            yield f"{indent}pop {{{loop_end_reg}}}"

        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl}:"

    def end(self, other, indentation=0):
        """Nothing to do here"""
        yield ""


class CmpLoop(Loop):
    """
    Loop ending in a compare and a branch.
    The modification to the value we compare against happens inside the loop body.
    WARNING: This type of loop is experimental as slothy has no knowledge about
    what happens inside the loop boundary! Use with caution.

    Example:

    .. code-block:: asm

        loop_lbl:
           {code}
           cmp <cnt>, <end>
           (cbnz|bnz|bne) loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl="lbl", lbl_start="1", lbl_end="2", loop_init="lr") -> None:
        super().__init__(lbl_start=lbl_start, lbl_end=lbl_end, loop_init=loop_init)
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            r"^\s*cmp(?:\.w)?\s+(?P<cnt>\w+),\s*(?P<end>\w+)",
            rf"^\s*(cbnz|cbz|bne)(?:\.w)?\s+{lbl}",
        )

    def start(
        self,
        loop_cnt,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        """Emit starting instruction(s) and jump label for loop"""
        indent = " " * indentation
        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield (
                f"{indent}lsr {self.additional_data['end']}, "
                f"{self.additional_data['end']}, #{int(math.log2(unroll))}"
            )

        # Find out by how much the loop counter is modified in one iteration
        inc_per_iter = 0
        if body_code is not None:
            try:
                loop_cnt_reg = register_aliases[loop_cnt]
            except KeyError:
                loop_cnt_reg = loop_cnt
            for line in body_code:
                if line.text == "":
                    continue
                inst = Instruction.parser(line)
                if (
                    loop_cnt_reg.lower() == inst[0].addr
                    and inst[0].increment is not None
                ):
                    inc_per_iter = inc_per_iter + simplify(inst[0].increment)
        logging.debug(
            f"Loop counter {loop_cnt} is incremented by {inc_per_iter} per iteration"
        )

        # Check whether instructions modifying the loop count moved to
        # pre/postamble and adjust the fixup based on that.
        # new_fixup = 0
        # if postamble_code is not None:
        #     new_fixup = 0
        #     for l in postamble_code:
        #         if l.text == "":
        #             continue
        #         inst = Instruction.parser(l)
        #         if loop_cnt in inst[0].args_in_out and inst[0].increment is not None:
        #             new_fixup = new_fixup + simplify(inst[0].increment)

        # if new_fixup != 0:
        #     yield f"{indent}sub {self.additional_data['end']},
        #  {self.additional_data['end']}, #{new_fixup}"

        if fixup != 0:
            yield (
                f"{indent}sub {self.additional_data['end']}, "
                f"{self.additional_data['end']}, #{fixup*inc_per_iter}"
            )

        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl_start}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        indent = " " * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"

        yield f'{indent}cmp {other["cnt"]}, {other["end"]}'
        yield f"{indent}bne {lbl_start}"


class SubsLoop(Loop):
    """
    Loop ending in a flag setting subtraction and a branch.

    Example:

    .. code-block::

        loop_lbl:
           {code}
           sub[s] <cnt>, <cnt>, #1
           (cbnz|bnz|bne) loop_lbl

    where cnt is the loop counter in lr.
    """

    def __init__(self, lbl_start="1", lbl_end="2", loop_init="lr") -> None:
        super().__init__(lbl_start=lbl_start, lbl_end=lbl_end, loop_init=loop_init)
        self.lbl_regex = r"^\s*(?P<label>\w+)\s*:(?P<remainder>.*)$"
        self.end_regex = (
            r"^\s*sub[s]?(?:\.w)?\s+(?P<cnt>\w+),(?:\s*(?P<reg1>\w+),)?\s*(?P<imm>#1)",
            rf"^\s*(cbnz|cbz|bne)(?:\.w)?\s+{lbl_start}",
        )

    def start(
        self,
        loop_cnt,
        indentation=0,
        fixup=0,
        unroll=1,
        jump_if_empty=None,
        preamble_code=None,
        body_code=None,
        postamble_code=None,
        register_aliases=None,
    ):
        """Emit starting instruction(s) and jump label for loop"""
        indent = " " * indentation
        if unroll > 1:
            assert unroll in [1, 2, 4, 8, 16, 32]
            yield f"{indent}lsr {loop_cnt}, {loop_cnt}, #{int(math.log2(unroll))}"
        if fixup != 0:
            yield f"{indent}sub {loop_cnt}, {loop_cnt}, #{fixup}"
        if jump_if_empty is not None:
            yield f"cbz {loop_cnt}, {jump_if_empty}"
        yield f"{self.lbl_start}:"

    def end(self, other, indentation=0):
        """Emit compare-and-branch at the end of the loop"""
        indent = " " * indentation
        lbl_start = self.lbl_start
        if lbl_start.isdigit():
            lbl_start += "b"
        if other["reg1"] is None:
            yield f'{indent}subs {other["cnt"]}, #1'
        else:
            # `subs` sets flags
            yield f'{indent}subs {other["cnt"]}, {other["reg1"]}, {other["imm"]}'
        yield f"{indent}bne {lbl_start}"


class FatalParsingException(Exception):
    """A fatal error happened during instruction parsing"""


class UnknownInstruction(Exception):
    """The parent instruction class for the given object could not be found"""


class UnknownRegister(Exception):
    """The register could not be found"""


class Instruction:

    class ParsingException(Exception):
        """An attempt to parse an assembly line as a specific instruction failed

        This is a frequently encountered exception since assembly lines are parsed by
        trial and error, iterating over all instruction parsers."""

        def __init__(self, err=None):
            super().__init__(err)

    def __init__(
        self, *, mnemonic, arg_types_in=None, arg_types_in_out=None, arg_types_out=None
    ):

        if arg_types_in is None:
            arg_types_in = []
        if arg_types_out is None:
            arg_types_out = []
        if arg_types_in_out is None:
            arg_types_in_out = []

        self.mnemonic = mnemonic

        self.args_out_combinations = None
        self.args_in_combinations = None
        self.args_in_out_combinations = None
        self.args_in_out_different = None
        self.args_inout_out_different = None
        self.args_in_inout_different = None

        self.arg_types_in = arg_types_in
        self.arg_types_out = arg_types_out
        self.arg_types_in_out = arg_types_in_out
        self.num_in = len(arg_types_in)
        self.num_out = len(arg_types_out)
        self.num_in_out = len(arg_types_in_out)

        self.args_out_restrictions = [None for _ in range(self.num_out)]
        self.args_in_restrictions = [None for _ in range(self.num_in)]
        self.args_in_out_restrictions = [None for _ in range(self.num_in_out)]

        self.args_in = []
        self.args_out = []
        self.args_in_out = []

        self.addr = None
        self.increment = None
        self.pre_index = None
        self.offset_adjustable = True

        self.immediate = None
        self.datatype = None
        self.index = None
        self.flag = None
        self.width = None
        self.barrel = None
        self.label = None
        self.reg_list = None

    def extract_read_writes(self):
        """Extracts 'reads'/'writes' clauses from the source line of the instruction"""

        src_line = self.source_line

        def hint_register_name(tag):
            return f"hint_{tag}"

        # Check if the source line is tagged as reading/writing from memory
        def add_memory_write(tag):
            self.num_out += 1
            self.pattern_outputs.append((hint_register_name(tag), RegisterType.HINT))
            self.args_out_restrictions.append(None)
            self.args_out.append(hint_register_name(tag))
            self.arg_types_out.append(RegisterType.HINT)

        def add_memory_read(tag):
            self.num_in += 1
            self.pattern_inputs.append((hint_register_name(tag), RegisterType.HINT))
            self.args_in_restrictions.append(None)
            self.args_in.append(hint_register_name(tag))
            self.arg_types_in.append(RegisterType.HINT)

        write_tags = src_line.tags.get("writes", [])
        read_tags = src_line.tags.get("reads", [])

        if not isinstance(write_tags, list):
            write_tags = [write_tags]

        if not isinstance(read_tags, list):
            read_tags = [read_tags]

        for w in write_tags:
            add_memory_write(w)

        for r in read_tags:
            add_memory_read(r)

        return self

    def global_parsing_cb(self, a, log=None):
        """Parsing callback triggered after DataFlowGraph parsing which allows
        modification of the instruction in the context of the overall computation.

        This is primarily used to remodel input-outputs as outputs in jointly destructive
        instruction patterns (See Section 4.4, https://eprint.iacr.org/2022/1303.pdf).
        """
        _ = log  # log is not used
        return False

    def global_fusion_cb(self, a, log=None):
        """Fusion callback triggered after DataFlowGraph parsing which allows fusing
        of the instruction in the context of the overall computation.

        This can be used e.g. to detect eor-eor pairs and replace them by eor3."""
        _ = log  # log is not used
        return False

    def write(self):
        """Write the instruction"""
        args = self.args_out + self.args_in_out + self.args_in
        return self.mnemonic + " " + ", ".join(args)

    @staticmethod
    def unfold_abbrevs(mnemonic):
        return mnemonic

    def _is_instance_of(self, inst_list):
        for inst in inst_list:
            if isinstance(self, inst):
                return True
        return False

    def is_ldr(self):
        return self._is_instance_of(
            [
                ldr,
                ldr_with_imm,
                ldr_with_imm_stack,
                ldr_with_postinc,
                ldr_with_inc_writeback,
            ]
        )

    def is_load(self):
        """Indicates if an instruction is a load instruction"""
        return self._is_instance_of(
            [
                ldr,
                ldr_with_imm,
                ldrb_with_imm,
                ldrh_with_imm,
                ldr_with_imm_stack,
                ldr_with_postinc,
                ldrh_with_postinc,
                ldrb_with_postinc,
                ldrd_imm,
                ldrd_with_postinc,
                ldr_with_inc_writeback,
                ldm_interval,
                ldm_interval_inc_writeback,
                vldr_with_imm,
                vldr_with_postinc,
                vldm_interval_inc_writeback,
            ]
        )

    def is_store(self):
        """Indicates if an instruction is a store instruction"""
        return self._is_instance_of(
            [
                str_no_off,
                strh_with_imm,
                str_with_imm,
                str_with_imm_stack,
                str_with_postinc,
                strh_with_postinc,
                stm_interval_inc_writeback,
            ]
        )

    def is_load_store_instruction(self):
        """Indicates if an instruction is a load or store instruction"""
        return self.is_load() or self.is_store()

    @classmethod
    def make(cls, src):
        """Abstract factory method parsing a string into an instruction instance."""

    @staticmethod
    def build(c: any, src: str, mnemonic: str, **kwargs: list) -> "Instruction":
        """Attempt to parse a string as an instance of an instruction.


        :param c: The target instruction the string should be attempted to be parsed as.
        :type c: any
        :param src: The string to parse.
        :type src: str
        :param mnemonic: The mnemonic of instruction c
        :type mnemonic: str
        :param **kwargs: Additional arguments to pass to the constructor of c.
        :type **kwargs: list

        :return: Upon success, the result of parsing src as an instance of c.
        :rtype: Instruction

        :raises Instruction.ParsingException: The str argument cannot be parsed as an
                instance of c.
        :raises FatalParsingException: A fatal error during parsing happened
                that's likely a bug in the model.
        """

        if src.split(" ")[0] != mnemonic:
            raise Instruction.ParsingException(
                f"Mnemonic does not match: {src.split(' ')[0]} vs. {mnemonic}"
            )

        obj = c(mnemonic=mnemonic, **kwargs)

        # Replace <dt> by list of all possible datatypes
        mnemonic = Instruction.unfold_abbrevs(obj.mnemonic)

        expected_args = obj.num_in + obj.num_out + obj.num_in_out
        regexp_txt = rf"^\s*{mnemonic}"
        if expected_args > 0:
            regexp_txt += r"\s+"
        regexp_txt += ",".join([r"\s*(\w+)\s*" for _ in range(expected_args)])
        regexp = re.compile(regexp_txt)

        p = regexp.match(src)
        if p is None:
            raise Instruction.ParsingException(
                f"Doesn't match basic instruction template {regexp_txt}"
            )

        operands = list(p.groups())

        if obj.num_out > 0:
            obj.args_out = operands[: obj.num_out]
            idx_args_in = obj.num_out
        elif obj.num_in_out > 0:
            obj.args_in_out = operands[: obj.num_in_out]
            idx_args_in = obj.num_in_out
        else:
            idx_args_in = 0

        obj.args_in = operands[idx_args_in:]

        if not len(obj.args_in) == obj.num_in:
            raise FatalParsingException(
                f"Something wrong parsing {src}: Expect {obj.num_in} input,"
                f" but got {len(obj.args_in)} ({obj.args_in})"
            )

        return obj

    @staticmethod
    def parser(src_line):
        """Global factory method parsing an assembly line into an instance
        of a subclass of Instruction."""
        insts = []
        exceptions = {}
        instnames = []

        src = src_line.text.strip()

        # Iterate through all derived classes and call their parser
        # until one of them hopefully succeeds
        for inst_class in Instruction.all_subclass_leaves:
            try:
                inst = inst_class.make(src)
                instnames = [inst_class.__name__]
                insts = [inst]
                break
            except Instruction.ParsingException as e:
                exceptions[inst_class.__name__] = e

        for i in insts:
            i.source_line = src_line

            # Mark as branch for BranchLoop
            if isinstance(i, Armv7mBranch):
                i.source_line.tags["branch"] = True

            i.extract_read_writes()

        if len(insts) == 0:
            logging.error("Failed to parse instruction %s", src)
            logging.error("A list of attempted parsers and their exceptions follows.")
            for i, e in exceptions.items():
                msg = f"* {i + ':':20s} {e}"
                logging.error(msg)
            raise Instruction.ParsingException(
                f"Couldn't parse {src}\nYou may need to add support "
                "for a new instruction (variant)?"
            )

        logging.debug("Parsing result for '%s': %s", src, instnames)
        return insts

    def __repr__(self):
        return self.write()


class Armv7mInstruction(Instruction):
    """Abstract class representing Armv7m instructions"""

    PARSERS = {}

    @staticmethod
    def _unfold_pattern(src):
        src = re.sub(r", +", ",", src)
        src = re.sub(r"\.", "\\\\s*\\\\.\\\\s*", src)
        src = re.sub(r"\[", "\\\\s*\\\\[\\\\s*", src)
        src = re.sub(r"\]", "\\\\s*\\\\]\\\\s*", src)

        def pattern_transform(g):
            return (
                f"([{g.group(1).lower()}{g.group(1)}]"
                f"(?P<raw_{g.group(1)}{g.group(2)}>[0-9_][0-9_]*)|"
                f"([{g.group(1).lower()}{g.group(1)}]"
                f"<(?P<symbol_{g.group(1)}{g.group(2)}>\\w+)>))"
            )

        src = re.sub(r"<([RS])(\w+)>", pattern_transform, src)

        # Replace <key> or <key0>, <key1>, ... with pattern
        def replace_placeholders(src, mnemonic_key, regexp, group_name):
            prefix = f"<{mnemonic_key}"
            pattern = f"<{mnemonic_key}>"

            def pattern_i(i):
                return f"<{mnemonic_key}{i}>"

            cnt = src.count(prefix)
            if cnt > 1:
                for i in range(cnt):
                    src = re.sub(pattern_i(i), f"(?P<{group_name}{i}>{regexp})", src)
            else:
                src = re.sub(pattern, f"(?P<{group_name}>{regexp})", src)

            return src

        flaglist = [
            "eq",
            "ne",
            "cs",
            "hs",
            "cc",
            "lo",
            "mi",
            "pl",
            "vs",
            "vc",
            "hi",
            "ls",
            "ge",
            "lt",
            "gt",
            "le",
        ]

        flag_pattern = "|".join(flaglist)
        # TODO: Notion of dt can be placed with notion for size in FP instructions
        dt_pattern = "(?:|2|4|8|16)(?:B|H|S|D|b|h|s|d)"
        imm_pattern = "#(\\\\w|\\\\s|/| |-|\\*|\\+|\\(|\\)|=|,)+"
        index_pattern = "[0-9]+"
        width_pattern = r"(?:\.w|\.n|)"
        barrel_pattern = "(?:lsl|ror|lsr|asr)\\\\s*"
        label_pattern = r"(?:\\w+)"

        # reg_list is <range>(,<range>)*
        # range is [rs]NN(-rsMM)?
        range_pat = "([rs]\\\\d+)(-[rs](\\\\d+))?"
        reg_list_pattern = "{" + range_pat + "(," + range_pat + ")*" + "}"

        src = re.sub(" ", "\\\\s+", src)
        src = re.sub(",", "\\\\s*,\\\\s*", src)

        src = replace_placeholders(src, "imm", imm_pattern, "imm")
        src = replace_placeholders(src, "dt", dt_pattern, "datatype")
        src = replace_placeholders(src, "index", index_pattern, "index")
        src = replace_placeholders(
            src, "flag", flag_pattern, "flag"
        )  # TODO: Are any changes required for IT syntax?
        src = replace_placeholders(src, "width", width_pattern, "width")
        src = replace_placeholders(src, "barrel", barrel_pattern, "barrel")
        src = replace_placeholders(src, "label", label_pattern, "label")
        src = replace_placeholders(src, "reg_list", reg_list_pattern, "reg_list")

        src = r"\s*" + src + r"\s*(//.*)?\Z"
        return src

    @staticmethod
    def _build_parser(src):
        regexp_txt = Armv7mInstruction._unfold_pattern(src)
        regexp = re.compile(regexp_txt)

        def _parse(line):
            regexp_result = regexp.match(line)
            if regexp_result is None:
                raise Instruction.ParsingException(
                    f"Does not match instruction pattern {src}" f"[regex: {regexp_txt}]"
                )
            res = regexp.match(line).groupdict()
            items = list(res.items())
            for k, v in items:
                for prefix in ["symbol_", "raw_"]:
                    if k.startswith(prefix):
                        del res[k]
                        if v is None:
                            continue
                        k = k[len(prefix) :]
                        res[k] = v
            return res

        return _parse

    @staticmethod
    def get_parser(pattern):
        """Build parser for given AArch64 instruction pattern"""
        if pattern in Armv7mInstruction.PARSERS:
            return Armv7mInstruction.PARSERS[pattern]
        parser = Armv7mInstruction._build_parser(pattern)
        Armv7mInstruction.PARSERS[pattern] = parser
        return parser

    @cache
    def __infer_register_type(ptrn):
        if ptrn[0].upper() in ["R"]:
            return RegisterType.GPR
        if ptrn[0].upper() in ["S"]:
            return RegisterType.FPR
        if ptrn[0].upper() in ["T"]:
            return RegisterType.HINT
        raise FatalParsingException(f"Unknown pattern: {ptrn}")

    # TODO: remove workaround (needed for Python 3.9)
    _infer_register_type = staticmethod(__infer_register_type)

    def __init__(
        self,
        pattern,
        *,
        inputs=None,
        outputs=None,
        in_outs=None,
        modifiesFlags=False,
        dependsOnFlags=False,
    ):

        self.mnemonic = pattern.split(" ")[0]

        if inputs is None:
            inputs = []
        if outputs is None:
            outputs = []
        if in_outs is None:
            in_outs = []
        arg_types_in = [Armv7mInstruction._infer_register_type(r) for r in inputs]
        arg_types_out = [Armv7mInstruction._infer_register_type(r) for r in outputs]
        arg_types_in_out = [Armv7mInstruction._infer_register_type(r) for r in in_outs]

        if modifiesFlags:
            arg_types_out += [RegisterType.FLAGS]
            outputs += ["flags"]

        if dependsOnFlags:
            arg_types_in += [RegisterType.FLAGS]
            inputs += ["flags"]

        super().__init__(
            mnemonic=pattern,
            arg_types_in=arg_types_in,
            arg_types_out=arg_types_out,
            arg_types_in_out=arg_types_in_out,
        )

        self.inputs = inputs
        self.outputs = outputs
        self.in_outs = in_outs

        self.pattern = pattern
        assert len(inputs) == len(arg_types_in)
        self.pattern_inputs = list(zip(inputs, arg_types_in))
        assert len(outputs) == len(arg_types_out)
        self.pattern_outputs = list(zip(outputs, arg_types_out))
        assert len(in_outs) == len(arg_types_in_out)
        self.pattern_in_outs = list(zip(in_outs, arg_types_in_out))

    @staticmethod
    def _to_reg(ty, s):
        if ty == RegisterType.GPR:
            c = "r"
        elif ty == RegisterType.FPR:
            c = "s"
        elif ty == RegisterType.HINT:
            c = "t"
        else:
            assert False
        if s.replace("_", "").isdigit():
            return f"{c}{s}"
        return s

    @staticmethod
    def _build_pattern_replacement(s, ty, arg):
        if ty == RegisterType.GPR:
            if arg[0] != "r":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.FPR:
            if arg[0] != "s":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        if ty == RegisterType.HINT:
            if arg[0] != "t":
                return f"{s[0].upper()}<{arg}>"
            return s[0].lower() + arg[1:]
        raise FatalParsingException(f"Unknown register type ({s}, {ty}, {arg})")

    @staticmethod
    def _instantiate_pattern(s, ty, arg, out):
        if ty == RegisterType.FLAGS or ty == RegisterType.HINT:
            return out
        rep = Armv7mInstruction._build_pattern_replacement(s, ty, arg)
        res = out.replace(f"<{s}>", rep)
        if res == out:
            raise FatalParsingException(f"Failed to replace <{s}> by {rep} in {out}!")
        return res

    @staticmethod
    def _expand_reg_list(reg_list):
        """Expanding list of registers that may contain ranges
        Examples:
        r1,r2,r3
        s1-s7
        r1-r3,r14
        """
        reg_list = reg_list.replace("{", "")
        reg_list = reg_list.replace("}", "")

        reg_list_type = reg_list[0]
        regs = []
        for reg_range in reg_list.split(","):
            if "-" in reg_range:
                start = reg_range.split("-")[0]
                end = reg_range.split("-")[1]
                start = int(start.replace(reg_list_type, ""))
                end = int(end.replace(reg_list_type, ""))
                regs += [f"{reg_list_type}{i}" for i in range(start, end + 1)]
            else:  # not a range, just a register
                regs += [reg_range]
        return reg_list_type, regs

    @staticmethod
    def build_core(obj, res):

        def group_to_attribute(group_name, attr_name, f=None):
            def f_default(x):
                return x

            def group_name_i(i):
                return f"{group_name}{i}"

            if f is None:
                f = f_default
            if group_name in res.keys():
                setattr(obj, attr_name, f(res[group_name]))
            else:
                idxs = [i for i in range(4) if group_name_i(i) in res.keys()]
                if len(idxs) == 0:
                    return
                assert idxs == list(range(len(idxs)))
                setattr(
                    obj, attr_name, list(map(lambda i: f(res[group_name_i(i)]), idxs))
                )

        group_to_attribute("datatype", "datatype", lambda x: x.lower())
        group_to_attribute("imm", "immediate", lambda x: x[1:])  # Strip '#'
        group_to_attribute("index", "index", int)
        group_to_attribute("flag", "flag")
        group_to_attribute("width", "width")
        group_to_attribute("barrel", "barrel")
        group_to_attribute("label", "label")
        group_to_attribute("reg_list", "reg_list")

        for s, ty in obj.pattern_inputs:
            if ty == RegisterType.FLAGS:
                obj.args_in.append("flags")
            else:
                obj.args_in.append(Armv7mInstruction._to_reg(ty, res[s]))
        for s, ty in obj.pattern_outputs:
            if ty == RegisterType.FLAGS:
                obj.args_out.append("flags")
            else:
                obj.args_out.append(Armv7mInstruction._to_reg(ty, res[s]))

        for s, ty in obj.pattern_in_outs:
            obj.args_in_out.append(Armv7mInstruction._to_reg(ty, res[s]))

    @staticmethod
    def build(c, src):
        pattern = getattr(c, "pattern")
        inputs = getattr(c, "inputs", []).copy()
        outputs = getattr(c, "outputs", []).copy()
        in_outs = getattr(c, "in_outs", []).copy()
        modifies_flags = getattr(c, "modifiesFlags", False)
        depends_on_flags = getattr(c, "dependsOnFlags", False)

        if isinstance(src, str):
            # Leave checking the mnemonic out for now; not strictly required
            # Allows xxx.w and xxx.n syntax
            res = Armv7mInstruction.get_parser(pattern)(src)
        else:
            assert isinstance(src, dict)
            res = src

        obj = c(
            pattern,
            inputs=inputs,
            outputs=outputs,
            in_outs=in_outs,
            modifiesFlags=modifies_flags,
            dependsOnFlags=depends_on_flags,
        )

        Armv7mInstruction.build_core(obj, res)
        return obj

    @classmethod
    def make(cls, src):
        return Armv7mInstruction.build(cls, src)

    def write(self):
        out = self.pattern
        ll = (
            list(zip(self.args_in, self.pattern_inputs))
            + list(zip(self.args_out, self.pattern_outputs))
            + list(zip(self.args_in_out, self.pattern_in_outs))
        )
        for arg, (s, ty) in ll:
            out = Armv7mInstruction._instantiate_pattern(s, ty, arg, out)

        def replace_pattern(txt, attr_name, mnemonic_key, t=None):
            def t_default(x):
                return x

            if t is None:
                t = t_default

            a = getattr(self, attr_name)
            if a is None:
                return txt
            if not isinstance(a, list):
                txt = txt.replace(f"<{mnemonic_key}>", t(a))
                return txt
            for i, v in enumerate(a):
                txt = txt.replace(f"<{mnemonic_key}{i}>", t(v))
            return txt

        out = replace_pattern(out, "immediate", "imm", lambda x: f"#{x}")
        out = replace_pattern(out, "datatype", "dt", lambda x: x.upper())
        out = replace_pattern(out, "flag", "flag")
        out = replace_pattern(out, "index", "index", str)
        out = replace_pattern(out, "width", "width", lambda x: x.lower())
        out = replace_pattern(out, "barrel", "barrel", lambda x: x.lower())
        out = replace_pattern(out, "label", "label")
        out = replace_pattern(out, "reg_list", "reg_list", lambda x: x.lower())

        out = out.replace("\\[", "[")
        out = out.replace("\\]", "]")
        return out


class Armv7mBranch(Armv7mInstruction):
    pass


class Armv7mBasicArithmetic(Armv7mInstruction):
    pass


class Armv7mShiftedArithmetic(Armv7mInstruction):
    pass


class Armv7mMultiplication(Armv7mInstruction):
    pass


class Armv7mLogical(Armv7mInstruction):
    pass


class Armv7mShiftedLogical(Armv7mInstruction):
    pass


class Armv7mLoadInstruction(Armv7mInstruction):
    pass


class Armv7mStoreInstruction(Armv7mInstruction):
    pass


class Armv7mFPInstruction(Armv7mInstruction):
    pass


# FP
class vmov_gpr(Armv7mFPInstruction):
    pattern = "vmov<width> <Rd>, <Sa>"
    inputs = ["Sa"]
    outputs = ["Rd"]


class vmov_gpr2(Armv7mFPInstruction):
    pattern = "vmov<width> <Sd>, <Ra>"
    inputs = ["Ra"]
    outputs = ["Sd"]


class vmov_gpr2_dual(Armv7mFPInstruction):
    pattern = "vmov<width> <Sd1>, <Sd2>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Sd1", "Sd2"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.args_out_combinations = [
            (
                [0, 1],
                [
                    [f"s{i}", f"s{i+1}"]
                    for i in range(
                        0, len(RegisterType.list_registers(RegisterType.FPR))
                    )
                ],
            )
        ]
        return obj


# movs
class movw_imm(Armv7mBasicArithmetic):
    pattern = "movw <Rd>, <imm>"
    outputs = ["Rd"]


class movt_imm(Armv7mBasicArithmetic):
    pattern = "movt <Rd>, <imm>"
    in_outs = ["Rd"]


# Addition
class add(Armv7mBasicArithmetic):
    pattern = "add<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class add_short(Armv7mBasicArithmetic):
    pattern = "add<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]


class add_imm(Armv7mBasicArithmetic):
    pattern = "add<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]


class add_imm_short(Armv7mBasicArithmetic):
    pattern = "add<width> <Rd>, <imm>"
    in_outs = ["Rd"]


class add_shifted(Armv7mShiftedArithmetic):
    pattern = "add<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class adds(Armv7mBasicArithmetic):
    pattern = "adds<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]
    modifiesFlags = True


class uadd16(Armv7mBasicArithmetic):
    pattern = "uadd16<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class sadd16(Armv7mBasicArithmetic):
    pattern = "sadd16<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


# Subtraction
class sub(Armv7mBasicArithmetic):
    pattern = "sub<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class sub_shifted(Armv7mShiftedArithmetic):
    pattern = "sub<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class sub_short(Armv7mBasicArithmetic):
    pattern = "sub<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]


class sub_imm_short(Armv7mBasicArithmetic):
    pattern = "sub<width> <Ra>, <imm>"
    in_outs = ["Ra"]


class subs_imm(Armv7mBasicArithmetic):
    pattern = "subs<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]
    modifiesFlags = True


class subs_imm_short(Armv7mBasicArithmetic):
    pattern = "subs<width> <Ra>, <imm>"
    in_outs = ["Ra"]
    modifiesFlags = True


class usub16(Armv7mBasicArithmetic):
    pattern = "usub16<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class ssub16(Armv7mBasicArithmetic):
    pattern = "ssub16<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


# Multiplication
class mul(Armv7mMultiplication):
    pattern = "mul<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class mul_short(Armv7mMultiplication):
    pattern = "mul<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]


class mla(Armv7mMultiplication):
    pattern = "mla<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class mls(Armv7mMultiplication):
    pattern = "mls<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class smulwb(Armv7mMultiplication):
    pattern = "smulwb<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class smulwt(Armv7mMultiplication):
    pattern = "smulwt<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class smultb(Armv7mMultiplication):
    pattern = "smultb<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class smultt(Armv7mMultiplication):
    pattern = "smultt<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class smulbb(Armv7mMultiplication):
    pattern = "smulbb<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class smlabt(Armv7mMultiplication):
    pattern = "smlabt<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class smlabb(Armv7mMultiplication):
    pattern = "smlabb<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class smlatt(Armv7mMultiplication):
    pattern = "smlatt<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class smlatb(Armv7mMultiplication):
    pattern = "smlatb<width> <Rd>, <Ra>, <Rb>, <Rc>"
    inputs = ["Ra", "Rb", "Rc"]
    outputs = ["Rd"]


class smull(Armv7mMultiplication):
    pattern = "smull<width> <Ra>, <Rb>, <Rc>, <Rd>"
    inputs = ["Rc", "Rd"]
    outputs = ["Ra", "Rb"]


class smlal(Armv7mMultiplication):
    pattern = "smlal<width> <Ra>, <Rb>, <Rc>, <Rd>"
    inputs = ["Rc", "Rd"]
    in_outs = ["Ra", "Rb"]


class smlad(Armv7mMultiplication):
    pattern = "smlad<width> <Ra>, <Rb>, <Rc>, <Rd>"
    inputs = ["Rb", "Rc", "Rd"]
    outputs = ["Ra"]


class smladx(Armv7mMultiplication):
    pattern = "smladx<width> <Ra>, <Rb>, <Rc>, <Rd>"
    inputs = ["Rb", "Rc", "Rd"]
    outputs = ["Ra"]


class smmulr(Armv7mMultiplication):
    pattern = "smmulr<width> <Ra>, <Rb>, <Rc>"
    inputs = ["Rb", "Rc"]
    outputs = ["Ra"]


class smuad(Armv7mMultiplication):
    pattern = "smuad<width> <Ra>, <Rb>, <Rc>"
    inputs = ["Rb", "Rc"]
    outputs = ["Ra"]


class smuadx(Armv7mMultiplication):
    pattern = "smuadx<width> <Ra>, <Rb>, <Rc>"
    inputs = ["Rb", "Rc"]
    outputs = ["Ra"]


# Logical


class neg_short(Armv7mLogical):
    pattern = "neg<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]


class log_and(Armv7mLogical):
    pattern = "and<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class log_and_shifted(Armv7mShiftedLogical):
    pattern = "and<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class log_or(Armv7mLogical):
    pattern = "orr<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class log_or_shifted(Armv7mShiftedLogical):
    pattern = "orr<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class eor(Armv7mLogical):
    pattern = "eor<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class eor_short(Armv7mLogical):
    pattern = "eor<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]


class eors(Armv7mLogical):
    pattern = "eors<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]
    modifiesFlags = True


class eors_short(Armv7mLogical):
    pattern = "eors<width> <Rd>, <Ra>"
    inputs = ["Ra"]
    in_outs = ["Rd"]
    modifiesFlags = True


class eor_shifted(Armv7mShiftedLogical):
    pattern = "eor<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]

    def write(self):
        self.immediate = simplify(self.immediate)
        return super().write()


class bic(Armv7mLogical):
    pattern = "bic<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class bics(Armv7mLogical):
    pattern = "bics<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]
    modifiesFlags = True


class bic_shifted(Armv7mShiftedLogical):
    pattern = "bic<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class ubfx_imm(Armv7mLogical):
    pattern = "ubfx<width> <Rd>, <Ra>, <imm0>, <imm1>"
    inputs = ["Ra"]
    outputs = ["Rd"]


class ror(Armv7mLogical):
    pattern = "ror<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]


class ror_short(Armv7mLogical):
    pattern = "ror<width> <Rd>, <imm>"
    in_outs = ["Rd"]


class rors_short(Armv7mLogical):
    pattern = "rors<width> <Rd>, <imm>"
    in_outs = ["Rd"]
    modifiesFlags = True


class lsl(Armv7mLogical):
    pattern = "lsl<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]


class asr(Armv7mLogical):
    pattern = "asr<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]


class asrs(Armv7mLogical):
    pattern = "asrs<width> <Rd>, <Ra>, <imm>"
    inputs = ["Ra"]
    outputs = ["Rd"]
    modifiesFlags = True


class pkhtb(Armv7mShiftedLogical):
    pattern = "pkhtb<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class pkhbt(Armv7mLogical):
    pattern = "pkhbt<width> <Rd>, <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


class pkhbt_shifted(Armv7mShiftedLogical):
    pattern = "pkhbt<width> <Rd>, <Ra>, <Rb>, <barrel><imm>"
    inputs = ["Ra", "Rb"]
    outputs = ["Rd"]


# Load
class ldr(Armv7mLoadInstruction):
    pattern = "ldr<width> <Rd>, [<Ra>]"
    inputs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = 0
        obj.addr = obj.args_in[0]
        obj.args_in_out_different = [(0, 0)]  # Can't have Rd==Ra
        return obj

    def write(self):
        if int(self.pre_index) != 0:
            self.immediate = simplify(self.pre_index)
            self.pattern = ldr_with_imm.pattern
        return super().write()


class ldr_with_imm(Armv7mLoadInstruction):
    pattern = "ldr<width> <Rd>, [<Ra>, <imm>]"
    inputs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        obj.args_in_out_different = [(0, 0)]  # Can't have Rd==Ra
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)

        if self.immediate < 0:
            # if immediate is < 0, the encoding is 32-bit anyway
            # and the .w has no meaning.
            # LLVM complains about the .w in this case
            # TODO: This actually seems to be a bug in LLVM
            self.width = ""
        return super().write()


class ldrb_with_imm(Armv7mLoadInstruction):
    pattern = "ldrb<width> <Rd>, [<Ra>, <imm>]"
    inputs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.args_in_out_different = [(0, 0)]  # Can't have Rd==Ra
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldrh_with_imm(Armv7mLoadInstruction):
    pattern = "ldrh<width> <Rd>, [<Ra>, <imm>]"
    inputs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.args_in_out_different = [(0, 0)]  # Can't have Rd==Ra
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldr_with_imm_stack(Armv7mLoadInstruction):
    pattern = "ldr<width> <Rd>, [sp, <imm>]"
    inputs = []
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldr_with_postinc(Armv7mLoadInstruction):
    pattern = "ldr<width> <Rd>, [<Ra>], <imm>"
    in_outs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.args_inout_out_different = [(0, 0)]  # Can't have Rd==Ra
        obj.addr = obj.args_in_out[0]
        return obj


class ldrh_with_postinc(Armv7mLoadInstruction):
    pattern = "ldrh<width> <Rd>, [<Ra>], <imm>"
    in_outs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.args_inout_out_different = [(0, 0)]  # Can't have Rd==Ra
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class ldrb_with_postinc(Armv7mLoadInstruction):
    pattern = "ldrb<width> <Rd>, [<Ra>], <imm>"
    in_outs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.args_inout_out_different = [(0, 0)]  # Can't have Rd==Ra
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class Ldrd(Armv7mLoadInstruction):
    pass


class ldrd_imm(Ldrd):
    pattern = "ldrd<width> <Ra>, <Rb>, [<Rc>, <imm>]"
    in_outs = ["Rc"]
    outputs = ["Ra", "Rb"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in_out[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class ldrd_with_postinc(Ldrd):
    pattern = "ldrd<width> <Ra>, <Rb>, [<Rc>], <imm>"
    in_outs = ["Rc"]
    outputs = ["Ra", "Rb"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class ldr_with_inc_writeback(Armv7mLoadInstruction):
    pattern = "ldr<width> <Rd>, [<Ra>, <imm>]!"
    in_outs = ["Ra"]
    outputs = ["Rd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class ldm_interval(Armv7mLoadInstruction):
    pattern = "ldm<width> <Ra>, <reg_list>"
    inputs = ["Ra"]
    outputs = []

    def write(self):
        regs = ",".join(self.args_out)
        self.reg_list = f"{{{regs}}}"
        return super().write()

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        reg_list_type, reg_list = Armv7mInstruction._expand_reg_list(obj.reg_list)

        obj.args_out = reg_list
        obj.num_out = len(obj.args_out)
        obj.arg_types_out = [RegisterType.GPR] * obj.num_out
        available_regs = RegisterType.list_registers(RegisterType.GPR)
        obj.args_out_combinations = [
            (
                list(range(0, obj.num_out)),
                [list(a) for a in itertools.combinations(available_regs, obj.num_out)],
            )
        ]
        obj.args_out_restrictions = [None for _ in range(obj.num_out)]
        return obj


class ldm_interval_inc_writeback(Armv7mLoadInstruction):
    pattern = "ldm<width> <Ra>!, <reg_list>"
    in_outs = ["Ra"]
    outputs = []

    def write(self):
        regs = ",".join(self.args_out)
        self.reg_list = f"{{{regs}}}"
        return super().write()

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        reg_list_type, reg_list = Armv7mInstruction._expand_reg_list(obj.reg_list)

        obj.args_out = reg_list
        obj.num_out = len(obj.args_out)
        obj.arg_types_out = [RegisterType.GPR] * obj.num_out
        obj.increment = obj.num_out * 4

        available_regs = RegisterType.list_registers(RegisterType.GPR)
        obj.args_out_combinations = [
            (
                list(range(0, obj.num_out)),
                [list(a) for a in itertools.combinations(available_regs, obj.num_out)],
            )
        ]
        obj.args_out_restrictions = [None for _ in range(obj.num_out)]
        return obj


class vldr_with_imm(Armv7mLoadInstruction):
    pattern = "vldr<width> <Sd>, [<Ra>, <imm>]"
    inputs = ["Ra"]
    outputs = ["Sd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class vldr_with_postinc(Armv7mLoadInstruction):
    pattern = "vldr<width> <Sd>, [<Ra>], <imm>"
    in_outs = ["Ra"]
    outputs = ["Sd"]

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class vldm_interval_inc_writeback(Armv7mLoadInstruction):
    pattern = "vldm<width> <Ra>!, <reg_list>"
    in_outs = ["Ra"]
    outputs = []

    def write(self):
        regs = ",".join(self.args_out)
        self.reg_list = f"{{{regs}}}"
        return super().write()

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)
        reg_list_type, reg_list = Armv7mInstruction._expand_reg_list(obj.reg_list)

        obj.args_out = reg_list
        obj.num_out = len(obj.args_out)
        obj.arg_types_out = [RegisterType.FPR] * obj.num_out
        obj.increment = obj.num_out * 4

        available_regs = RegisterType.list_registers(RegisterType.FPR)
        obj.args_out_combinations = [
            (
                list(range(0, obj.num_out)),
                [
                    [f"s{i+j}" for i in range(0, obj.num_out)]
                    for j in range(0, len(available_regs) - obj.num_out)
                ],
            )
        ]
        obj.args_out_restrictions = [None for _ in range(obj.num_out)]
        return obj


# Store


class str_no_off(Armv7mStoreInstruction):
    pattern = "str<width> <Rd>, [<Ra>]"
    inputs = ["Ra", "Rd"]
    outputs = []

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = 0
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        if int(self.pre_index) != 0:
            self.immediate = simplify(self.pre_index)
            self.pattern = str_with_imm.pattern
        return super().write()


class strh_with_imm(Armv7mStoreInstruction):
    pattern = "strh<width> <Rd>, [<Ra>, <imm>]"
    inputs = ["Ra", "Rd"]
    outputs = []

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class str_with_imm(Armv7mStoreInstruction):
    pattern = "str<width> <Rd>, [<Ra>, <imm>]"
    inputs = ["Ra", "Rd"]
    outputs = []

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = obj.args_in[0]
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)

        if self.immediate < 0:
            # if immediate is < 0, the encoding is 32-bit anyway
            # and the .w has no meaning.
            # LLVM complains about the .w in this case
            # TODO: This actually seems to be a bug in LLVM
            self.width = ""

        return super().write()


class str_with_imm_stack(Armv7mStoreInstruction):
    pattern = "str<width> <Rd>, [sp, <imm>]"
    inputs = ["Rd"]
    outputs = []

    @classmethod
    def make(cls, src):
        obj = Armv7mInstruction.build(cls, src)
        obj.increment = None
        obj.pre_index = obj.immediate
        obj.addr = "sp"
        return obj

    def write(self):
        self.immediate = simplify(self.pre_index)
        return super().write()


class str_with_postinc(Armv7mStoreInstruction):
    pattern = "str<width> <Rd>, [<Ra>], <imm>"
    inputs = ["Rd"]
    in_outs = ["Ra"]

    @classmethod
    def make(cls, src):
        obj = Armv7mStoreInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class strh_with_postinc(Armv7mStoreInstruction):
    pattern = "strh<width> <Rd>, [<Ra>], <imm>"
    inputs = ["Rd"]
    in_outs = ["Ra"]

    @classmethod
    def make(cls, src):
        obj = Armv7mStoreInstruction.build(cls, src)
        obj.increment = obj.immediate
        obj.pre_index = None
        obj.addr = obj.args_in_out[0]
        return obj


class stm_interval_inc_writeback(Armv7mLoadInstruction):
    pattern = "stm<width> <Ra>!, <reg_list>"
    in_outs = ["Ra"]
    outputs = []

    def write(self):
        regs = ",".join(self.args_out)
        self.reg_list = f"{{{regs}}}"
        return super().write()

    @classmethod
    def make(cls, src):
        obj = Armv7mLoadInstruction.build(cls, src)

        reg_list_type, reg_list = Armv7mInstruction._expand_reg_list(obj.reg_list)

        obj.args_in = reg_list
        obj.num_in = len(obj.args_in)
        obj.arg_types_in = [RegisterType.GPR] * obj.num_in
        obj.increment = obj.num_in * 4

        available_regs = RegisterType.list_registers(RegisterType.GPR)
        obj.args_in_combinations = [
            (
                list(range(0, obj.num_in)),
                [
                    [f"s{i+j}" for i in range(0, obj.num_in)]
                    for j in range(0, len(available_regs) - obj.num_in)
                ],
            )
        ]
        obj.args_in_restrictions = [None for _ in range(obj.num_in)]
        return obj


# Other
class cmp(Armv7mBasicArithmetic):
    pattern = "cmp<width> <Ra>, <Rb>"
    inputs = ["Ra", "Rb"]
    modifiesFlags = True
    dependsOnFlags = True


class cmp_imm(Armv7mBasicArithmetic):
    pattern = "cmp<width> <Ra>, <imm>"
    inputs = ["Ra"]
    modifiesFlags = True


class bne(Armv7mBranch):
    pattern = "bne<width> <label>"
    dependsOnFlags = True


class Spill:
    def spill(reg, loc, spill_to_vreg=None):
        """Generates the instruction text for a spill to either
        the stack or the FPR. If spill_to_vreg is None (default),
        the spill goes to the stack. Otherwise, spill_to_vreg must
        be an integer defining the base of the registers in the FPR
        which should be used as a stack. For example, passing 8 would
        spill to s8,s9,.. ."""
        if spill_to_vreg is None:
            return f"str {reg}, [sp, #STACK_LOC_{loc}]"
        else:
            vreg_base = int(spill_to_vreg)
            return f"vmov s{vreg_base+int(loc)}, {reg}"

    def restore(reg, loc, spill_to_vreg=None):
        """Generates the instruction text for a spill restore from either
        the stack or the FPR. If spill_to_vreg is None (default),
        the spill goes to the stack. Otherwise, spill_to_vreg must
        be an integer defining the base of the registers in the FPR
        which should be used as a stack. For example, passing 8 would
        spill to s8,s9,.. ."""
        if spill_to_vreg is None:
            return f"ldr {reg}, [sp, #STACK_LOC_{loc}]"
        else:
            vreg_base = int(spill_to_vreg)
            return f"vmov {reg}, s{vreg_base+int(loc)}"


def ldm_interval_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in[0]
        regs = inst.args_out
        width = inst.width

        ldrs = []
        offset = 0
        for r in regs:
            ldr = Armv7mInstruction.build(
                ldr_with_imm, {"width": width, "Rd": r, "Ra": ptr, "imm": f"#{offset}"}
            )
            ldr.pre_index = offset
            ldrs.append(ldr)
            offset += 4

            ldr_src = (
                SourceLine(ldr.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            ldr.source_line = ldr_src

        if log is not None:
            log(f"ldm splitting: {t.inst}; {[ldr for ldr in ldrs]}")

        t.changed = True
        t.inst = ldrs
        return True

    return core


ldm_interval.global_fusion_cb = ldm_interval_splitting_cb()


def stm_interval_inc_writeback_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in_out[0]
        regs = inst.args_in
        width = inst.width

        strs = []
        offset = (len(regs) - 1) * 4
        for r in regs[:0:-1]:
            store = Armv7mInstruction.build(
                str_with_imm, {"width": width, "Rd": r, "Ra": ptr, "imm": f"#{offset}"}
            )
            store.pre_index = offset
            strs.append(store)
            offset -= 4
        # Final store includes increment
        store = Armv7mInstruction.build(
            str_with_postinc,
            {"width": width, "Rd": regs[0], "Ra": ptr, "imm": f"#{len(regs) * 4}"},
        )
        strs.append(store)

        for store in strs:
            store_src = (
                SourceLine(store.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            store.source_line = store_src

        if log is not None:
            log(f"stm! splitting: {t.inst}; {[store for store in strs]}")

        t.changed = True
        t.inst = strs
        return True

    return core


stm_interval_inc_writeback.global_fusion_cb = stm_interval_inc_writeback_splitting_cb()


def ldm_interval_inc_writeback_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in_out[0]
        regs = inst.args_out
        width = inst.width

        ldrs = []
        offset = (len(regs) - 1) * 4
        for r in regs[:0:-1]:
            ldr = Armv7mInstruction.build(
                ldr_with_imm, {"width": width, "Rd": r, "Ra": ptr, "imm": f"#{offset}"}
            )
            ldr.pre_index = offset
            ldrs.append(ldr)
            offset -= 4
        # Final load includes increment
        ldr = Armv7mInstruction.build(
            ldr_with_postinc,
            {"width": width, "Rd": regs[0], "Ra": ptr, "imm": f"#{len(regs) * 4}"},
        )
        ldrs.append(ldr)

        for ldr in ldrs:
            ldr_src = (
                SourceLine(ldr.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            ldr.source_line = ldr_src

        if log is not None:
            log(f"ldm! splitting: {t.inst}; {[ldr for ldr in ldrs]}")

        t.changed = True
        t.inst = ldrs
        return True

    return core


ldm_interval_inc_writeback.global_fusion_cb = ldm_interval_inc_writeback_splitting_cb()


def vldm_interval_inc_writeback_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in_out[0]
        regs = inst.args_out
        width = inst.width

        ldrs = []
        offset = 0
        for r in regs:
            ldr = Armv7mInstruction.build(
                vldr_with_imm, {"width": width, "Sd": r, "Ra": ptr, "imm": f"#{offset}"}
            )
            ldr.pre_index = offset
            ldrs.append(ldr)
            offset += 4

        add_ptr = Armv7mInstruction.build(
            add_imm, {"width": width, "Rd": ptr, "Ra": ptr, "imm": f"#{offset}"}
        )
        ldrs.append(add_ptr)

        for ldr in ldrs:
            ldr_src = (
                SourceLine(ldr.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            ldr.source_line = ldr_src

        if log is not None:
            log(f"ldm! splitting: {t.inst}; {[ldr for ldr in ldrs]}")

        t.changed = True
        t.inst = ldrs
        return True

    return core


vldm_interval_inc_writeback.global_fusion_cb = (
    vldm_interval_inc_writeback_splitting_cb()
)


def ldrd_postinc_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in_out[0]
        regs = inst.args_out
        width = inst.width

        ldrs = []

        ldr = Armv7mInstruction.build(
            ldr_with_imm, {"width": width, "Rd": regs[1], "Ra": ptr, "imm": "#4"}
        )
        ldr.pre_index = 4
        ldrs.append(ldr)
        # Final load includes increment
        ldr = Armv7mInstruction.build(
            ldr_with_postinc, {"width": width, "Rd": regs[0], "Ra": ptr, "imm": "#8"}
        )
        ldr.increment = 8
        ldr.pre_index = None
        ldr.addr = ptr
        ldrs.append(ldr)

        for ldr in ldrs:
            ldr_src = (
                SourceLine(ldr.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            ldr.source_line = ldr_src

        if log is not None:
            log(f"ldrd splitting: {t.inst}; {[ldr for ldr in ldrs]}")

        t.changed = True
        t.inst = ldrs
        return True

    return core


ldrd_with_postinc.global_fusion_cb = ldrd_postinc_splitting_cb()


def ldrd_imm_splitting_cb():
    def core(inst, t, log=None):

        ptr = inst.args_in_out[0]
        regs = inst.args_out
        width = inst.width

        ldrs = []

        ldr = Armv7mInstruction.build(
            ldr_with_imm,
            {"width": width, "Rd": regs[0], "Ra": ptr, "imm": inst.pre_index},
        )
        ldr.pre_index = inst.pre_index
        ldrs.append(ldr)
        # Final load includes increment
        ldr = Armv7mInstruction.build(
            ldr_with_imm,
            {"width": width, "Rd": regs[1], "Ra": ptr, "imm": f"{inst.pre_index}+4"},
        )
        ldr.pre_index = f"{inst.pre_index}+4"
        ldr.addr = ptr
        ldrs.append(ldr)

        for ldr in ldrs:
            ldr_src = (
                SourceLine(ldr.write())
                .add_tags(inst.source_line.tags)
                .add_comments(inst.source_line.comments)
            )
            ldr.source_line = ldr_src

        if log is not None:
            log(f"ldrd splitting: {t.inst}; {[ldr for ldr in ldrs]}")

        t.changed = True
        t.inst = ldrs
        return True

    return core


ldrd_imm.global_fusion_cb = ldrd_imm_splitting_cb()


# Returns the list of all subclasses of a class which don't have
# subclasses themselves
def all_subclass_leaves(c):

    def has_subclasses(cl):
        return len(cl.__subclasses__()) > 0

    def is_leaf(c):
        return not has_subclasses(c)

    def all_subclass_leaves_core(leaf_lst, todo_lst):
        leaf_lst += filter(is_leaf, todo_lst)
        todo_lst = [
            csub
            for c in filter(has_subclasses, todo_lst)
            for csub in c.__subclasses__()
        ]
        if len(todo_lst) == 0:
            return leaf_lst
        return all_subclass_leaves_core(leaf_lst, todo_lst)

    return all_subclass_leaves_core([], [c])


Instruction.all_subclass_leaves = all_subclass_leaves(Instruction)


def iter_armv7m_instructions():
    yield from all_subclass_leaves(Instruction)


def find_class(src):
    for inst_class in iter_armv7m_instructions():
        if isinstance(src, inst_class):
            return inst_class
    raise UnknownInstruction(
        f"Couldn't find instruction class for {src} (type {type(src)})"
    )


def lookup_multidict(d, inst, default=None):
    instclass = find_class(inst)
    for ll, v in d.items():
        # Multidict entries can be the following:
        # - An instruction class. It matches any instruction of that class.
        # - A callable. It matches any instruction returning `True` when passed
        #   to the callable.
        # - A tuple of instruction classes or callables. It matches any instruction
        #   which matches at least one element in the tuple.
        def match(x):
            if inspect.isclass(x):
                return isinstance(inst, x)
            assert callable(x)
            return x(inst)

        if not isinstance(ll, tuple):
            ll = [ll]
        for lp in ll:
            if match(lp):
                return v
    if default is None:
        raise UnknownInstruction(f"Couldn't find {instclass} for {inst}")
    return default

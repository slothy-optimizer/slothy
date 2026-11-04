#
# Copyright (c) 2026 Maggie Simmons
# Copyright (c) 2026 Hayden Parsons
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

import re
from enum import Enum
import copy

# Lists of registers of each size
byte_regs = (
    [f"{p}l" for p in ["a", "b", "c", "d"]]
    + ["dil", "sil"]
    + ["spl", "bpl"]
    + [f"r{n}l" for n in range(8, 16)]
)

word_regs = (
    [f"{p}x" for p in ["a", "b", "c", "d"]]
    + ["di", "si"]
    + ["sp", "bp"]
    + [f"r{n}w" for n in range(8, 16)]
)

dword_regs = (
    [f"e{p}x" for p in ["a", "b", "c", "d"]]
    + ["edi", "esi"]
    + ["esp", "ebp"]
    + [f"r{n}d" for n in range(8, 16)]
)

qword_regs = (
    [f"r{p}x" for p in ["a", "b", "c", "d"]]
    + ["rdi", "rsi"]
    + ["rsp", "rbp"]
    + [f"r{n}" for n in range(8, 16)]
)

# list of size-specifying suffixes
sz_sufs = ["b", "w", "l", "q", "dq"]

# lists of mmnemonics which contain size suffixes at the end which should not be stripped
b_suf_mms = ["clwb", "fisub", "fsub", "sbb", "sub", "eldb", "ewb"]
w_suf_mms = [
    "cbw",
    "cmpsw",
    "fldcw",
    "fnstcw",
    "fnstsw",
    "fstcw",
    "fstsw",
    "lmsw",
    "mpsadbw",
    "packssdw",
    "packusdw",
    "pblendw",
    "phminposuw",
    "pmaddubsw",
    "pmulhrsw",
    "pmulhuw",
    "pmulhw",
    "prefetchw",
    "psadbw",
    "pshufhw",
    "pshuflw",
    "psubusw",
    "punpckhbw",
    "punpcklbw",
    "smsw",
    "vcvtph2uw",
    "vcvtph2w",
    "vcvttph2uw",
    "vcvttph2w",
    "vdbpsadbw",
    "verw",
    "vmovw",
]
l_suf_mms = [
    "aesdec128kl",
    "aesdec256kl",
    "aesdecwide128kl",
    "aesdecwide256kl",
    "aesenc128kl",
    "aesenc256kl",
    "aesencwide128kl",
    "aesencwide256kl",
    "arpl",
    "bndcl",
    "call",
    "fimul",
    "fmul",
    "imul",
    "lsl",
    "mul",
    "rcl",
    "rol",
    "sal",
    "shl",
    "syscall",
    "vzeroall",
    "smctrl",
    "vmcall",
]
# These d suffixes are only used in the construction of the dq and q list since d is
# never stripped by itself
d_suf_mms = [
    "aad",
    "add",
    "addpd",
    "addsd",
    "addsubpd",
    "and",
    "andnpd",
    "andpd",
    "blendpd",
    "blendvpd",
    "bound",
    "cld",
    "cmppd",
    "cmpsd",
    "cmpsd",
    "comisd",
    "cpuid",
    "cvtdq2pd",
    "cvtpi2pd",
    "cvtps2pd",
    "cvtsi2sd",
    "cvtss2sd",
    "cwd",
    "divpd",
    "divsd",
    "dppd",
    "enqcmd",
    "fadd",
    "fbld",
    "fiadd",
    "fild",
    "fld",
    "haddpd",
    "hsubpd",
    "incsspd",
    "insd",
    "invd",
    "invpcid",
    "iretd",
    "kaddd",
    "kandd",
    "kandnd",
    "kmovd",
    "knotd",
    "kord",
    "kortestd",
    "kshiftld",
    "kshiftrd",
    "ktestd",
    "kunpckwd",
    "kxnord",
    "kxord",
    "lodsd",
    "maxpd",
    "maxsd",
    "minpd",
    "minsd",
    "movapd",
    "movd",
    "movhpd",
    "movlpd",
    "movmskpd",
    "movntpd",
    "movsd",
    "movsd",
    "movsxd",
    "movupd",
    "mulpd",
    "mulsd",
    "orpd",
    "outsd",
    "pabsd",
    "paddd",
    "pand",
    "pcmpeqd",
    "pcmpgtd",
    "pextrd",
    "phaddd",
    "phsubd",
    "pinsrd",
    "pmaddwd",
    "pmaxsd",
    "pmaxud",
    "pminsd",
    "pminud",
    "pmulld",
    "popad",
    "popfd",
    "pshufd",
    "psignd",
    "pslld",
    "psrad",
    "psrld",
    "psubd",
    "punpckhwd",
    "punpcklwd",
    "pushad",
    "pushfd",
    "rdpid",
    "rdrand",
    "rdseed",
    "rdsspd",
    "roundpd",
    "roundsd",
    "scasd",
    "shld",
    "shrd",
    "shufpd",
    "sqrtpd",
    "sqrtsd",
    "std",
    "stosd",
    "subpd",
    "subsd",
    "tdpbssd",
    "tdpbsud",
    "tdpbusd",
    "tdpbuud",
    "tileloadd",
    "tilestored",
    "ucomisd",
    "ud",
    "unpckhpd",
    "unpcklpd",
    "valignd",
    "vblendmpd",
    "vcompresspd",
    "vcvtph2pd",
    "vcvtqq2pd",
    "vcvtsh2sd",
    "vcvtudq2pd",
    "vcvtuqq2pd",
    "vcvtusi2sd",
    "vexpandpd",
    "vfixupimmpd",
    "vfixupimmsd",
    "vfmadd132pd",
    "vfmadd132sd",
    "vfmadd213pd",
    "vfmadd213sd",
    "vfmadd231pd",
    "vfmadd231sd",
    "vfmaddrnd231pd",
    "vfmaddsub132pd",
    "vfmaddsub213pd",
    "vfmaddsub231pd",
    "vfmsub132pd",
    "vfmsub132sd",
    "vfmsub213pd",
    "vfmsub213sd",
    "vfmsub231pd",
    "vfmsub231sd",
    "vfmsubadd132pd",
    "vfmsubadd213pd",
    "vfmsubadd231pd",
    "vfnmadd132pd",
    "vfnmadd132sd",
    "vfnmadd213pd",
    "vfnmadd213sd",
    "vfnmadd231pd",
    "vfnmadd231sd",
    "vfnmsub132pd",
    "vfnmsub132sd",
    "vfnmsub213pd",
    "vfnmsub213sd",
    "vfnmsub231pd",
    "vfnmsub231sd",
    "vfpclasspd",
    "vfpclasssd",
    "vgatherdpd",
    "vgatherdpd",
    "vgatherqpd",
    "vgatherqpd",
    "vgetexppd",
    "vgetexpsd",
    "vgetmantpd",
    "vgetmantsd",
    "vp2intersectd",
    "vpblendd",
    "vpblendmd",
    "vpbroadcastd",
    "vpcmpd",
    "vpcmpud",
    "vpcompressd",
    "vpconflictd",
    "vpdpbusd",
    "vpdpwssd",
    "vpermd",
    "vpermi2d",
    "vpermi2pd",
    "vpermilpd",
    "vpermpd",
    "vpermt2d",
    "vpermt2pd",
    "vpexpandd",
    "vpgatherdd",
    "vpgatherdd",
    "vpgatherqd",
    "vpgatherqd",
    "vplzcntd",
    "vpmovm2d",
    "vpmovqd",
    "vpmovsqd",
    "vpmovusqd",
    "vprold",
    "vprolvd",
    "vprord",
    "vprorvd",
    "vpscatterdd",
    "vpscatterqd",
    "vpshld",
    "vpshrd",
    "vpsllvd",
    "vpsravd",
    "vpsrlvd",
    "vpternlogd",
    "vptestmd",
    "vptestnmd",
    "vrangepd",
    "vrangesd",
    "vrcp14pd",
    "vrcp14sd",
    "vreducepd",
    "vreducesd",
    "vrndscalepd",
    "vrndscalesd",
    "vrsqrt14pd",
    "vrsqrt14sd",
    "vscalefpd",
    "vscalefsd",
    "vscatterdpd",
    "vscatterqpd",
    "vtestpd",
    "wbinvd",
    "wbnoinvd",
    "wrssd",
    "wrussd",
    "xadd",
    "xend",
    "xorpd",
    "eadd",
    "edbgrd",
    "eextend",
    "edecvirtchild",
    "eincvirtchild",
    "invvpid",
    "vmptrld",
    "vmread",
    "vexp2pd",
    "vgatherpf0dpd",
    "vgatherpf0qpd",
    "vgatherpf1dpd",
    "vgatherpf1qpd",
    "vp4dpwssd",
    "vrcp28pd",
    "vrcp28sd",
    "vrsqrt28pd",
    "vrsqrt28sd",
    "vscatterpf0dpd",
    "vscatterpf0qpd",
    "vscatterpf1dpd",
    "vscatterpf1qpd",
]
dq_suf_mms_base = [
    "cdq",
    "cvtpd2dq",
    "cvtps2dq",
    "cvttpd2dq",
    "cvttps2dq",
    "kunpckdq",
    "movntdq",
    "movq2dq",
    "pclmulqdq",
    "pmuludq",
    "punpcklqdq",
    "vcvtpd2udq",
    "vcvtph2dq",
    "vcvtph2udq",
    "vcvtps2udq",
    "vcvttpd2udq",
    "vcvttph2dq",
    "vcvttph2udq",
    "vcvttps2udq",
]
# Only strip the q when a mnemonic ending in d has a q appended
dq_suf_mms = dq_suf_mms_base + [mm + "q" for mm in d_suf_mms]
q_suf_mms = [
    "cmpsq",
    "maskmovq",
    "movdq2q",
    "movsq",
    "vpmadd52huq",
    "vpmadd52luq",
    "vpmovm2q",
] + dq_suf_mms_base

short_sz_suf_mms = b_suf_mms + w_suf_mms + l_suf_mms + q_suf_mms


def is_reg_name(name):
    """Whether name is an x86_64 register name (case-insensitive)"""
    name = name.lower()
    if name in byte_regs + word_regs + dword_regs + qword_regs:
        return True
    return re.fullmatch(r"[xy]mm(1[0-5]|[0-9])", name) is not None


def is_label_name(name):
    """Whether name can be a label: not a register or a number (GAS local labels
    such as 1b/1f are allowed)"""
    if is_reg_name(name):
        return False
    if name[0].isdigit():
        return re.fullmatch(r"\d+[bf]", name) is not None
    return True


def reg_type(reg):
    if reg in byte_regs:
        return "byte"
    elif reg in word_regs:
        return "word"
    elif reg in dword_regs:
        return "dword"
    elif reg in qword_regs:
        return "qword"
    else:
        raise Exception(f"Reg type of {reg} not known!")


# Class for a single instruction
class Instruction:
    def __init__(self, text="", indentation="", mmnemonic="", args=None):
        self.text = text
        self.indentation = indentation
        self.mmnemonic = mmnemonic
        self.args = args if args is not None else []

    class Arg_type(Enum):
        REG = 1
        IMM = 2
        PTR = 3
        LABEL = 4

        INVALID = -1

    class Arg:
        def __init__(self, ty=None):
            self.ty = ty
            if ty is None:
                self.ty = Instruction.Arg_type.INVALID
            self.imm = None
            self.reg = None
            self.sz = None
            self.base = None
            self.disp = None
            self.idx = None
            self.scale = None
            self.label = None

    def consume_mmnemonic(self, text):
        regexp_txt = r"(?P<space>^\s*)(?P<mmnemonic>\w[\w\d]*)"
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        space = match.group("space")
        mmnemonic = match.group("mmnemonic")
        # consume the text and add the mmnemonic
        self.indentation = space
        self.mmnemonic = mmnemonic
        text = text[len(space) + len(mmnemonic) :]
        return text

    def imm_regexp_txt(self, label):
        num = r"([\w\d]+)"
        signed_num = rf"-?{num}"
        # innermost: just numbers, no parens
        level0 = rf"{signed_num}(?:[\+\-\*/]{signed_num})*"
        # level1: numbers or one paren-group of level0
        level1 = (
            rf"(?:{signed_num}|\({level0}\))(?:[\+\-\*/](?:{signed_num}|\({level0}\)))*"
        )
        # level2 (top): numbers or one paren-group of level1 -- supports 2 levels of
        # nesting
        level2 = (
            rf"(?:{signed_num}|\({level1}\))(?:[\+\-\*/](?:{signed_num}|\({level1}\)))*"
        )
        return f"(?P<{label}>{level2})"

    def consume_imm(self, text, commas=True):
        pass

    def consume_reg(self, text, commas=True):
        pass

    def consume_ptr(self, text, commas=True):
        pass

    def consume_label(self, text, commas=True):
        regexp_txt = (
            r"(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)(?P<label>\w[\w\d]*)"
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        label = match.group("label")
        # Registers and numbers are not labels; rejecting them keeps AT&T from
        # accepting Intel-syntax operands (and vice versa)
        if not is_label_name(label):
            return None
        # consume the text and add the argument
        arg = Instruction.Arg(Instruction.Arg_type.LABEL)
        arg.label = label
        self.args.append(arg)
        text = text[len(preamble) + len(label) :]
        return text

    def consume_whitespace(self, text, commas=None):
        _ = commas  # commas not used here
        regexp_txt = r"^\s+"
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        space = match.group()
        if len(space) != len(text):
            return None
        return ""

    # Ordered from strictest requirements to least so as not to falsely classify an
    # argument/whitespace
    arg_consumers = [
        "consume_ptr",
        "consume_reg",
        "consume_imm",
        "consume_label",
        "consume_whitespace",
    ]

    def parse_instruction(self):
        text = self.text

        # parse the mmnemonic
        res = self.consume_mmnemonic(text)
        if res is None:
            raise Exception(f"Mmnemonic in {text} is invalid!")
        text = res

        # An instruction with no arguments which had no trailing whitespace succeeds
        # here if no text reamins
        no_args_insts = ["nop", "ret"]
        if self.mmnemonic in no_args_insts and res == "":
            return

        # parse first argument if any
        success = False

        for consumer_name in self.arg_consumers:
            consumer = getattr(self, consumer_name)
            res = consumer(text, commas=False)
            if res is not None:
                text = res
                success = True
                break

        # An instruction with no arguments which had trailing whitespace succeeds here
        # if the whitespace was stripped
        if self.mmnemonic in no_args_insts and res == "":
            return

        if not success:
            raise Exception(f"Portion {text} of line {self.text} could not be parsed!")

        # parse remaining arguments
        while len(res) > 0:
            success = False

            for consumer_name in self.arg_consumers:
                consumer = getattr(self, consumer_name)
                res = consumer(text)
                if res is not None:
                    text = res
                    success = True
                    break

            if not success:
                raise Exception(
                    f"Portion {text} of line {self.text} could not be parsed!"
                )

    def write_arg(self, arg):
        pass

    def write_instruction(self):
        if self.indentation is None:
            raise Exception(f"Indentation is None for instruction {self.text}!")
        text = self.indentation

        # write the mmnemonic
        if self.mmnemonic is None:
            raise Exception("Instruction must have a mmnemonic!")
        text += self.mmnemonic

        args_written = 0

        # write first arg if relevant
        if len(self.args) > 0:
            text = text + " " + self.write_arg(self.args[0])
            args_written += 1

        while args_written < len(self.args):
            text = text + ", " + self.write_arg(self.args[args_written])
            args_written += 1

        return text


class Atat_Instruction(Instruction):
    # For AT&T we need to further process the mmnemonic for a size specifier
    def consume_mmnemonic(self, text):
        regexp_txt = r"(?P<space>^\s*)(?P<mmnemonic>\w[\w\d]*)"
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        space = match.group("space")
        mmnemonic = match.group("mmnemonic")
        # consume the text and add the mmnemonic
        self.indentation = space
        text = text[len(space) + len(mmnemonic) :]

        # strip any size suffixes
        # start with larger suffixes
        # do nothing if ends with qq
        if mmnemonic[-2:] == "qq":
            pass
        if mmnemonic[-2:] in sz_sufs and mmnemonic not in dq_suf_mms:
            mmnemonic = mmnemonic[:-2]
        if mmnemonic[-1] in sz_sufs and mmnemonic not in short_sz_suf_mms:
            mmnemonic = mmnemonic[:-1]

        self.mmnemonic = mmnemonic
        return text

    def consume_imm(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)(?P<dollar>\$)"
            + self.imm_regexp_txt("imm")
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        dollar = match.group("dollar")
        imm = match.group("imm")
        # consume the text and add the argument
        arg = Instruction.Arg(Instruction.Arg_type.IMM)
        arg.imm = imm
        self.args.append(arg)
        text = text[len(preamble) + len(dollar) + len(imm) :]
        return text

    def reg_regexp_txt(self, percent_label, reg_label):
        return (
            f"(?P<{percent_label}>"
            + r"\%)"
            + (
                f"(?P<{reg_label}>"
                "([eErR]?([a-dA-D][lLxX]|([sSdD][iI]|[sSbB][pP])[lL]?)"
                "|[rR](8|9|1[0-5])[wWlLdD]?"
                "|([xX]|[yY])[mM][mM](1[0-5]|[0-9]))"
                "|(([HSDQ]W)|[XY]MM)<\\w[\\w\\d_]*>)"
            )
        )

    def consume_reg(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)"
            + self.reg_regexp_txt("percent", "reg")
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        percent = match.group("percent")
        reg = match.group("reg")
        # consume the text and add the argument
        arg = Instruction.Arg(Instruction.Arg_type.REG)
        arg.reg = reg
        self.args.append(arg)
        text = text[len(preamble) + len(percent) + len(reg) :]
        return text

    def comma_regexp_txt(self, label):
        return f"(?P<{label}>" + r"\s*,\s*)"

    def ptr_regexp_text(self):
        disp = self.imm_regexp_txt("disp") + "?"
        base = self.reg_regexp_txt("percent1", "base")
        comma1 = self.comma_regexp_txt("comma1") + "?"
        idx = "(" + self.reg_regexp_txt("percent2", "idx") + ")?"
        comma2 = self.comma_regexp_txt("comma2") + "?"
        scale = self.imm_regexp_txt("scale") + "?"
        return f"{disp}" + r"\(" + f"{base}{comma1}{idx}{comma2}{scale}" + r"\)"

    def consume_ptr(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)"
            + self.ptr_regexp_text()
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        disp = match.group("disp")
        percent1 = match.group("percent1")
        base = match.group("base")
        comma1 = match.group("comma1")
        percent2 = match.group("percent2")
        idx = match.group("idx")
        comma2 = match.group("comma2")
        scale = match.group("scale")
        # A scale is only valid after an index register: (base,idx,scale)
        if scale is not None and (idx is None or comma2 is None):
            return None
        # Construct the arg piece by piece
        arg = Instruction.Arg(Instruction.Arg_type.PTR)

        def safe_set(obj, attr, val):
            if val is not None:
                setattr(obj, attr, val)

        safe_set(arg, "disp", disp)
        arg.base = base
        safe_set(arg, "idx", idx)
        safe_set(arg, "scale", scale)
        self.args.append(arg)

        # Get the total length of the text and consume it
        def safe_len(text):
            return len(text) if text is not None else 0

        text_length = (
            len(preamble)
            + safe_len(disp)
            + 1
            + len(percent1)
            + len(base)
            + safe_len(comma1)
            + safe_len(percent2)
            + safe_len(idx)
            + safe_len(comma2)
            + safe_len(scale)
            + 1
        )
        text = text[text_length:]
        return text

    def write_arg(self, arg):
        if arg.ty is None:
            raise Exception(
                f"Argument exists but has incomplete type for instruction: {self.text}!"
            )
        elif arg.ty is Instruction.Arg_type.IMM:
            return f"${arg.imm}"
        elif arg.ty is Instruction.Arg_type.REG:
            return f"%{arg.reg}"
        elif arg.ty is Instruction.Arg_type.PTR:
            text = ""
            if arg.disp is not None:
                text += arg.disp
            text += r"(%" + arg.base
            if arg.idx is not None:
                text += r",%" + arg.idx
            if arg.scale is not None:
                text += r"," + arg.scale
            text += ")"
            return text
        elif arg.ty is Instruction.Arg_type.LABEL:
            return arg.label
        else:
            raise Exception(
                f"Argument exists but has invalid type {arg.ty} "
                f"for instruction: {self.text}!"
            )


class Intel_Instruction(Instruction):
    def consume_imm(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)"
            + self.imm_regexp_txt("imm")
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        imm = match.group("imm")
        # The target of a jump is a label, not an immediate
        if self.mmnemonic.lower().startswith("j") and is_label_name(imm):
            return None
        # consume the text and add the argument
        arg = Instruction.Arg(Instruction.Arg_type.IMM)
        arg.imm = imm
        self.args.append(arg)
        text = text[len(preamble) + len(imm) :]
        return text

    def reg_regexp_txt(self, reg_label):
        return (
            f"(?P<{reg_label}>"
            "([eErR]?([a-dA-D][lLxX]|([sSdD][iI]|[sSbB][pP])[lL]?)"
            "|[rR](8|9|1[0-5])[wWlLdD]?"
            "|([xX]|[yY])[mM][mM](1[0-5]|[0-9]))"
            "|(([HSDQ]W)|[XY]MM)<\\w[\\w\\d_]*>)"
        )

    def consume_reg(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)"
            + self.reg_regexp_txt("reg")
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        reg = match.group("reg")
        # consume the text and add the argument
        arg = Instruction.Arg(Instruction.Arg_type.REG)
        arg.reg = reg
        self.args.append(arg)
        text = text[len(preamble) + len(reg) :]
        return text

    def ptr_regexp_text(self):
        sz = r"(?P<sz>(byte|word|dword|qword|xmmword|ymmword) ptr)"
        space = r"(?P<space>\s*)"
        base = self.reg_regexp_txt("base")
        plus1 = r"(?P<plus1>\s*\+\s*)?"
        idx = "(" + self.reg_regexp_txt("idx") + ")?"
        times = r"(?P<times>\s*\*\s*)?"
        scale = self.imm_regexp_txt("scale_disp") + "?"
        return f"{sz}{space}" + r"\[" + f"{base}{plus1}{idx}{times}{scale}" + r"\]"

    def ptr_size(self, ptr_arg):
        """Operand size of a memory operand: that of the instruction's register
        operand, or of the base register if there is none"""
        symbolic_sizes = {
            "hw<": "byte",
            "sw<": "word",
            "dw<": "dword",
            "qw<": "qword",
            "xmm<": "xmmword",
            "ymm<": "ymmword",
        }
        for arg in self.args:
            if arg.ty is Instruction.Arg_type.REG:
                reg = arg.reg.lower()
                for prefix, size in symbolic_sizes.items():
                    if reg.startswith(prefix):
                        return size
                if reg.startswith("xmm"):
                    return "xmmword"
                if reg.startswith("ymm"):
                    return "ymmword"
                return reg_type(reg)
        base = ptr_arg.base.lower()
        for prefix, size in symbolic_sizes.items():
            if base.startswith(prefix):
                return size
        return reg_type(base)

    def separate_scale_disp(self, text, scale_disp):
        if scale_disp is None:
            return None, None, None

        # If not bracketed, then we look for first plus sign
        if scale_disp[0] != "(":
            plus_idx = scale_disp.find("+")
            # If there is no plus sign
            if plus_idx == -1:
                return scale_disp, None, None
            scale = scale_disp[:plus_idx]
            plus = "+"
            disp = scale_disp[plus_idx + 1 :]
            return scale, plus, disp

        # If it is bracketed, find the parenthesis that closes the first one
        depth = 0
        close_idx = None
        for i, ch in enumerate(scale_disp):
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    close_idx = i + 1
                    break
        if close_idx is None:
            raise Exception(
                f"Unmatched parentheses in the scale attribute of instruction {text}!"
            )

        # The bracketed group is the whole attribute
        if close_idx == len(scale_disp):
            return scale_disp, None, None

        # Otherwise it must be followed by a plus sign and a displacement
        if scale_disp[close_idx] != "+" or close_idx == len(scale_disp) - 1:
            raise Exception(f"Bad formatting in scale attribute of instruction {text}!")

        scale = scale_disp[:close_idx]
        plus = "+"
        disp = scale_disp[close_idx + 1 :]
        return scale, plus, disp

    def consume_ptr(self, text, commas=True):
        regexp_txt = (
            "(?P<preamble>^"
            + (r"\s*," if commas else "")
            + r"\s+)"
            + self.ptr_regexp_text()
        )
        match = re.match(regexp_txt, text)
        # If no match was found then return trivial result to indicate
        if match is None:
            return None
        # Otherwise return the match and length of text to consume
        preamble = match.group("preamble")
        sz = match.group("sz")
        space = match.group("space")
        base = match.group("base")
        plus1 = match.group("plus1")
        idx = match.group("idx")
        times = match.group("times")
        scale_disp = match.group("scale_disp")
        # Process the scale and displacement. Without an index register and '*',
        # the number after the base is a displacement, not a scale: [base+disp]
        if idx is None and times is None:
            scale, plus2, disp = None, None, scale_disp
        else:
            scale, plus2, disp = self.separate_scale_disp(text, scale_disp)
        # Construct the arg piece by piece
        arg = Instruction.Arg(Instruction.Arg_type.PTR)

        def safe_set(obj, attr, val):
            if val is not None:
                setattr(obj, attr, val)

        arg.base = base
        safe_set(arg, "idx", idx)
        safe_set(arg, "scale", scale)
        safe_set(arg, "disp", disp)
        self.args.append(arg)

        # Get the total length of the text and consume it
        def safe_len(text):
            return len(text) if text is not None else 0

        text_length = (
            len(preamble)
            + len(sz)
            + safe_len(space)
            + 1
            + len(base)
            + safe_len(plus1)
            + safe_len(idx)
            + safe_len(times)
            + safe_len(scale)
            + safe_len(plus2)
            + safe_len(disp)
            + 1
        )
        text = text[text_length:]
        return text

    def write_arg(self, arg):
        if arg.ty is None:
            raise Exception(
                f"Argument exists but has incomplete type for instruction: {self.text}!"
            )
        elif arg.ty is Instruction.Arg_type.IMM:
            return f"{arg.imm}"
        elif arg.ty is Instruction.Arg_type.REG:
            return f"{arg.reg}"
        elif arg.ty is Instruction.Arg_type.PTR:
            text = ""
            sz = self.ptr_size(arg)
            text += sz + " ptr "
            text += r"[" + arg.base
            if arg.idx is not None:
                text += r"+" + arg.idx
            if arg.scale is not None:
                text += r"*" + arg.scale
            if arg.disp is not None:
                if arg.disp.startswith("-"):
                    text += arg.disp
                else:
                    text += r"+" + arg.disp
            text += r"]"
            return text
        elif arg.ty is Instruction.Arg_type.LABEL:
            return arg.label
        else:
            raise Exception(
                f"Argument exists but has invalid type {arg.ty} "
                f"for instruction: {self.text}!"
            )


# A code is a sequence of instructions
class Code:
    code_syntaxes = []
    source = None

    def __init_subclass__(self, **kwargs):
        super().__init_subclass__(**kwargs)
        Code.code_syntaxes.append(self)

    def __init__(self, text="", lines=None, instruction_class=None):
        self.text = text
        self.lines = lines if lines is not None else []
        self.instruction_class = instruction_class

    class Line_Type(Enum):
        BLANK = 0
        LABEL = 1
        INST = 2

    class Line:
        def __init__(self, ty=None, text=None, inst=None):
            self.ty = ty
            self.text = text
            self.inst = inst

    def is_blank(self, line):
        return line.strip() == ""

    def is_label(self, line):
        regexp_txt = r"\s*\w[\w\d]*:\s*"
        match = re.match(regexp_txt, line)
        if match is None:
            return False
        return True

    def parse_line(self, line):
        if line is None:
            raise Exception("Line cannot be None!")
        elif self.is_blank(line):
            line_obj = Code.Line(Code.Line_Type.BLANK)
            self.lines.append(line_obj)
        elif self.is_label(line):
            line_obj = Code.Line(Code.Line_Type.LABEL, text=line)
            self.lines.append(line_obj)
        else:
            # Now we try to parse this as an instruction of the Code's instruction class
            try:
                inst = self.instruction_class(text=line)
                inst.parse_instruction()
                line_obj = Code.Line(Code.Line_Type.INST, text=line, inst=inst)
                self.lines.append(line_obj)
            except Exception:
                # Now we know that the line does not match any of the expected types
                raise Exception(
                    f"Line {line} does not match any of the accepted types!"
                )
        return

    def try_parse_source(self):
        for line in self.text:
            # try to parse each line
            try:
                self.parse_line(line)
            except Exception:
                # return false if any line failed to parse
                return False
        # otherwise return true to reflect parsing success
        return True

    def parse_source(self, syntax=None):
        # Calling this on a syntax subclass (e.g. Intel_Code) implies that syntax
        if syntax is None and type(self) in self.code_syntaxes:
            syntax = type(self)
        # If the user specified the syntax, then use it
        if syntax in self.code_syntaxes:
            obj = syntax(text=self.text)
            # try to parse with this syntax
            res = obj.try_parse_source()
            if res:
                self.__class__ = obj.__class__
                self.__dict__ = obj.__dict__
                return
            raise Exception(
                "Could not parse the source as any of the supported syntaxes!"
            )

        # try each of the child classes each corresponding to a different syntax
        for cls in self.code_syntaxes:
            obj = cls(text=self.text)
            # try to parse with this syntax
            res = obj.try_parse_source()
            if res:
                self.__class__ = obj.__class__
                self.__dict__ = obj.__dict__
                return
        raise Exception("Could not parse the source as any of the supported syntaxes!")

    def write_line(self, line):
        if line is None:
            raise Exception("Line cannot be None!")
        elif line.ty is Code.Line_Type.BLANK:
            return ""
        elif line.ty is Code.Line_Type.LABEL:
            return line.text
        elif line.ty is Code.Line_Type.INST:
            return line.inst.write_instruction()
        else:
            raise Exception(f"Type of line {line.text} is not supported!")

    def write_code(self):
        text = []
        try:
            for line in self.lines:
                if line.text is not None:
                    text.append(self.write_line(line))
        except Exception:
            raise Exception("Failed to write code in requested syntax!")
        return text

    def to_atat(self):
        if self.__class__ == Atat_Code:
            return

        atat_obj = Atat_Code(self.text)
        for line in self.lines:
            if line.ty is Code.Line_Type.INST:
                new_inst = Atat_Instruction(
                    mmnemonic=line.inst.mmnemonic,
                    args=line.inst.args,
                    indentation=line.inst.indentation,
                )
                new_inst.args.reverse()
                new_line = Code.Line(ty=Code.Line_Type.INST, inst=new_inst)
                new_line.text = atat_obj.write_line(new_line)
                atat_obj.lines.append(new_line)
            else:
                atat_obj.lines.append(
                    copy.deepcopy(Code.Line(ty=line.ty, text=line.text))
                )

        self.__class__ = atat_obj.__class__
        self.__dict__ = atat_obj.__dict__

        self.text = atat_obj.write_code()

    def to_intel(self):
        if self.__class__ == Intel_Code:
            return

        intel_obj = Intel_Code(self.text)
        for line in self.lines:
            if line.ty is Code.Line_Type.INST:
                new_inst = Intel_Instruction(
                    mmnemonic=line.inst.mmnemonic,
                    args=line.inst.args,
                    indentation=line.inst.indentation,
                )
                new_inst.args.reverse()
                new_line = Code.Line(ty=Code.Line_Type.INST, inst=new_inst)
                new_line.text = intel_obj.write_line(new_line)
                intel_obj.lines.append(new_line)
            else:
                intel_obj.lines.append(
                    copy.deepcopy(Code.Line(ty=line.ty, text=line.text))
                )

        self.__class__ = intel_obj.__class__
        self.__dict__ = intel_obj.__dict__

        self.text = intel_obj.write_code()

    @classmethod
    def _translate_line(cls, text, dst):
        """Translate a single instruction from syntax cls to syntax dst"""
        code = cls(text=[text])
        code.parse_source(syntax=cls)
        if dst is Atat_Code:
            code.to_atat()
        else:
            code.to_intel()
        return code.write_code()[0]

    @staticmethod
    def _is_instruction_text(text):
        """Whether a (stripped) source line is an instruction, not a blank line,
        label or directive"""
        return not (text == "" or text.startswith(".") or text.endswith(":"))

    @staticmethod
    def _translate_source(source, src, dst):
        """Translate the instructions in a list of SourceLines from syntax src to
        syntax dst, keeping indentation, comments and tags. Blank lines, labels and
        directives are passed through unchanged."""
        res = []
        for line in source:
            text = line.text.strip()
            if not Code._is_instruction_text(text):
                res.append(line)
                continue
            res.append(line.copy().set_text(src._translate_line(text, dst)))
        return res

    @classmethod
    def to_native(cls, source):
        """Translate SourceLines from this syntax to AT&T, the native syntax of
        SLOTHY's x86_64 model"""
        return Code._translate_source(source, cls, Atat_Code)

    @classmethod
    def from_native(cls, source):
        """Translate SourceLines from AT&T back to this syntax"""
        return Code._translate_source(source, Atat_Code, cls)


class Atat_Code(Code):
    def __init__(self, text="", lines=None):
        super().__init__(text=text, lines=lines, instruction_class=Atat_Instruction)


class Intel_Code(Code):
    def __init__(self, text="", lines=None):
        super().__init__(text=text, lines=lines, instruction_class=Intel_Instruction)


# Passing this module as the syntax (Slothy(..., syntax=x86_translator)) detects the
# syntax of the whole code, as SLOTHY did by default before the syntax became an
# explicit option. The code is translated to AT&T and left in AT&T.


def to_native(source):
    """Detect the syntax (AT&T or Intel) of all instructions together and translate
    them to AT&T"""
    texts = [
        line.text.strip()
        for line in source
        if Code._is_instruction_text(line.text.strip())
    ]
    if not texts:
        return source
    code = Code(text=texts)
    code.parse_source()
    return type(code).to_native(source)


def from_native(source):
    """Output stays in AT&T when the syntax was auto-detected"""
    return source

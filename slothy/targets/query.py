#
# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# Copyright (c) 2023 Amin Abdulrahman, Matthias Kannwischer
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
# Author: Hanno Becker <hannobecker@posteo.de>
#

"""
Convenience module for querying available architecture
and microarchitecture models for SLOTHY.
"""

from slothy.targets.arm_v7m import arch_v7m as Arch_Armv7M
from slothy.targets.arm_v7m import cortex_m7 as Target_CortexM7

from slothy.targets.arm_v81m import arch_v81m as Arch_Armv81M
from slothy.targets.arm_v81m import cortex_m55r1 as Target_CortexM55r1
from slothy.targets.arm_v81m import cortex_m85r1 as Target_CortexM85r1
from slothy.targets.arm_v81m import helium_experimental as Target_Helium_Experimental

from slothy.targets.aarch64 import aarch64_neon as AArch64_Neon
from slothy.targets.aarch64 import cortex_a55 as Target_CortexA55
from slothy.targets.aarch64 import cortex_a72_frontend as Target_CortexA72_Frontend
from slothy.targets.aarch64 import (
    neoverse_n1_experimental as Target_NeoverseN1_Experimental,
)
from slothy.targets.aarch64 import aarch64_big_experimental as Target_Big_Experimental
from slothy.targets.aarch64 import (
    apple_m1_firestorm_experimental as Target_AppleM1_Firestorm_Experimental,
)
from slothy.targets.aarch64 import (
    apple_m1_icestorm_experimental as Target_AppleM1_Icestorm_Experimental,
)


class UnknownTarget(Exception):
    """Exception raised when an unknown architecture or microarchitecture
    is requested."""


class Archery:
    """This is a small helper class for querying architectures"""

    _archs = {
        "Arm_v7M": Arch_Armv7M,
        "Arm_v81M": Arch_Armv81M,
        "Arm_AArch64": AArch64_Neon,
    }

    _targets = {
        "Arm_Cortex_M55": Target_CortexM55r1,
        "Arm_Cortex_M85": Target_CortexM85r1,
        "Arm_Helium_Experimental": Target_Helium_Experimental,
        "Arm_Cortex_M7": Target_CortexM7,
        "Arm_Cortex_A55": Target_CortexA55,
        "Arm_Cortex_A72_frontend": Target_CortexA72_Frontend,
        "Arm_Neoverse_N1_experimental": Target_NeoverseN1_Experimental,
        "Arm_Big_experimental": Target_Big_Experimental,
        "Apple_M1_firestorm_experimental": Target_AppleM1_Firestorm_Experimental,
        "Apple_M1_icestorm_experimental": Target_AppleM1_Icestorm_Experimental,
    }

    @staticmethod
    def list_archs():
        """Lists all available architectures"""
        return list(Archery._archs.keys())

    @staticmethod
    def list_targets():
        """Lists all available targets"""
        return list(Archery._targets.keys())

    @staticmethod
    def get_arch(name):
        """Query an architecture by name"""
        arch = Archery._archs.get(name, None)
        if arch is None:
            raise UnknownTarget(
                f"Could not find architecture {name}. "
                f"Known architectures are {list(Archery._archs.keys())}"
            )
        return arch

    @staticmethod
    def get_target(name):
        """Query a target by name"""
        target = Archery._targets.get(name, None)
        if target is None:
            raise UnknownTarget(
                f"Could not find target {name}. "
                f"Known targets are {list(Archery._targets.keys())}"
            )
        return target

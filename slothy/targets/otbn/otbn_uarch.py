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
Experimental and incomplete model capturing an approximation of the
OTBN coprocessor.
"""

from enum import Enum, auto
from slothy.helper import lookup_multidict
from slothy.targets.otbn.otbn import (
    find_class,
    all_subclass_leaves,
    OTBNInstruction,
)
from slothy.core.masking import get_node_input_masking_infos

# From the A72 SWOG, Section "4.1 Dispatch Constraints"
# "The dispatch stage can process up to three µops per cycle"
# The name `issue_rate` is a slight misnomer here because we're
# modelling the frontend, not the backend, but `issue_width` is
# what SLOTHY expects.
issue_rate = 1
llvm_mca_target = ""


class ExecutionUnit(Enum):
    """Enumeration of execution units in approximative Cortex-A72 SLOTHY model"""

    OTBN = auto()

    def __repr__(self):
        return self.name


# Opaque function called by SLOTHY to add further microarchitecture-
# specific constraints which are not encapsulated by the general framework.
def add_further_constraints(slothy):
    if slothy.config.constraints.functional_only:
        return
    add_non_consec_shares(slothy)


def add_non_consec_shares(slothy):
    """Add constraints to prevent consecutive execution on different shares of
       the same secret variable.

    This function adds microarchitectural constraints to ensure that instructions
    operating on different shares of the same secret variable are not scheduled
    in consecutive cycles. This helps prevent power side-channels in masked
    cryptographic implementations.

    Args:
        slothy: The SLOTHY optimization object
    """

    constraint_count = 0

    def is_share_pair(inst_a, inst_b):
        """Check if two instructions operate on different shares of the same secret.

        Args:
            inst_a: First ComputationNode to compare
            inst_b: Second ComputationNode to compare

        Returns:
            True if the instructions operate on different shares of the same secret
            variable (e.g., inst_a uses a[0] and inst_b uses a[1]), False otherwise
        """
        # Collect all masking info from both instructions
        inst_a_masking = (
            get_node_input_masking_infos(inst_a)
            + inst_a.masking_info_out
            + inst_a.masking_info_in_out
        )
        inst_b_masking = (
            get_node_input_masking_infos(inst_b)
            + inst_b.masking_info_out
            + inst_b.masking_info_in_out
        )

        # Filter out None and public values, keep only secret shares
        inst_a_secrets = [
            m for m in inst_a_masking if m is not None and not m.is_public
        ]
        inst_b_secrets = [
            m for m in inst_b_masking if m is not None and not m.is_public
        ]

        # Check if they operate on different shares of the same secret variable
        for mask_a in inst_a_secrets:
            for share_a in mask_a.shares:
                for mask_b in inst_b_secrets:
                    for share_b in mask_b.shares:
                        if (
                            share_a.secret_name == share_b.secret_name
                            and share_a.share_index != share_b.share_index
                        ):
                            return True
        return False

    for t0, t1 in slothy.get_inst_pairs(cond=is_share_pair):
        if t0.is_locked and t1.is_locked:
            continue
        # Use program_start_var to prevent consecutive program positions
        slothy._Add(t0.program_start_var != t1.program_start_var + 1)
        slothy._Add(t0.program_start_var != t1.program_start_var - 1)
        constraint_count += 1

    if constraint_count > 0:
        slothy.logger.debug(
            f"Added {constraint_count} share separation constraint(s) for leakage rule 3."
        )


# Opaque function called by SLOTHY to add further microarchitecture-
# specific objectives.
def has_min_max_objective(slothy):
    _ = slothy
    return False


def get_min_max_objective(slothy):
    _ = slothy


execution_units = {
    (OTBNInstruction): [ExecutionUnit.OTBN],
}

inverse_throughput = {
    (OTBNInstruction,): 1,
}

# REVISIT
default_latencies = {
    (OTBNInstruction,): 1,
}


def get_latency(src, out_idx, dst):
    _ = out_idx  # out_idx unused

    instclass_src = find_class(src)
    instclass_dst = find_class(dst)

    latency = lookup_multidict(default_latencies, src, instclass_src)

    return latency


def get_units(src):
    instclass_src = find_class(src)
    units = lookup_multidict(execution_units, src, instclass_src)
    if isinstance(units, list):
        return units
    return [units]


def get_inverse_throughput(src):
    instclass_src = find_class(src)
    return lookup_multidict(inverse_throughput, src, instclass_src)

"""
Masking information tracking for secret sharing schemes.

This module provides classes and utilities for tracking masking information
through data flow graphs to ensure that different shares of the same secret
are not mixed inappropriately.
"""


class ShareInfo:
    """Information about a single share of a secret variable."""

    def __init__(self, secret_name, share_index):
        assert secret_name is not None, "Secret name must be provided"
        assert share_index is not None, "Share index must be provided"
        self.secret_name = secret_name
        self.share_index = share_index

    def __eq__(self, other):
        if not isinstance(other, ShareInfo):
            return False
        return (self.secret_name == other.secret_name and
                self.share_index == other.share_index)

    def __hash__(self):
        return hash((self.secret_name, self.share_index))

    def __repr__(self):
        return f"{self.secret_name}[{self.share_index}]"


class MaskingInfo:
    """Masking information for an input/output register.

    A value can be:
    - Public (is_public=True, shares=[])
    - A single share of a secret (is_public=False, shares=[one ShareInfo])
    - Dependent on multiple shares (is_public=False, shares=[multiple ShareInfo])
    """

    def __init__(self, is_public, shares=None):
        assert isinstance(is_public, bool), "is_public must be True or False"
        self.is_public = is_public

        if shares is None:
            shares = []
        if isinstance(shares, ShareInfo):
            shares = [shares]

        self.shares = list(shares)  # List of ShareInfo objects

        # Validate: if secret, must have at least one share
        if not is_public:
            assert len(self.shares) > 0, "Secret values must have at least one share"

    @staticmethod
    def from_single_share(secret_name, share_index):
        """Create MaskingInfo for a single share of a secret."""
        return MaskingInfo(is_public=False, shares=ShareInfo(secret_name, share_index))

    @staticmethod
    def public():
        """Create MaskingInfo for a public value."""
        return MaskingInfo(is_public=True)

    def __repr__(self):
        if self.is_public:
            return "public"
        elif len(self.shares) == 1:
            s = self.shares[0]
            return f"secret({s.secret_name},share{s.share_index})"
        else:
            share_strs = [str(s) for s in sorted(self.shares, key=lambda x: (x.secret_name, x.share_index))]
            return f"secret({','.join(share_strs)})"

    @staticmethod
    def combine(masking_infos, logger=None):
        """Combine masking information from multiple inputs to determine output masking.

        Rules:
        - If all inputs are public or None → output is None (no masking info)
        - If any input is secret → output depends on all secret shares from inputs
        - If inputs have different shares of the SAME variable → ERROR (cannot mix shares)
        - If inputs have different secret variables → output depends on all of them

        Args:
            masking_infos: List of MaskingInfo objects or None
            logger: Optional logger for debug messages

        Returns:
            MaskingInfo object or None

        Raises:
            Exception if different shares of the same secret are mixed
        """
        # Filter out None values
        non_none = [m for m in masking_infos if m is not None]

        if not non_none:
            return None  # All inputs are untracked

        # Get all secret masking infos
        secrets = [m for m in non_none if not m.is_public]

        if not secrets:
            return None  # All inputs are public → output is public (no tracking needed)

        # Collect all shares from all secret inputs
        all_shares = set()
        for s in secrets:
            all_shares.update(s.shares)

        # Check that we don't have different shares of the same secret
        secrets_to_shares = {}
        for share in all_shares:
            if share.secret_name not in secrets_to_shares:
                secrets_to_shares[share.secret_name] = set()
            secrets_to_shares[share.secret_name].add(share.share_index)

        # Verify no secret has multiple shares
        for secret_name, share_indices in secrets_to_shares.items():
            if len(share_indices) > 1:
                raise Exception(
                    f"Cannot mix different shares of secret '{secret_name}': "
                    f"shares {sorted(share_indices)}"
                )

        # All validation passed - create combined masking info
        result = MaskingInfo(is_public=False, shares=list(all_shares))

        if logger:
            logger.debug(f"Output inherits masking: {result}")

        return result


def get_masking_info(config, logger, name):
    """Determine masking information for an input register.

    Args:
        config: Configuration object with secret_inputs and public_inputs
        logger: Logger for debug messages
        name: Register name

    Returns:
        MaskingInfo object if the register has masking annotations, None otherwise
    """
    # Check if this register is marked as public
    if name in config.public_inputs:
        logger.debug(f"-> {name} is marked as public input")
        return MaskingInfo.public()

    # Check if this register is part of a secret input
    for secret, shares in config.secret_inputs.items():
        for idx, share_regs in enumerate(shares):
            if name in share_regs:
                logger.debug(
                    f"-> {name} is share {idx} of secret '{secret}'"
                )
                return MaskingInfo.from_single_share(secret, idx)

    return None


def propagate_masking_info(dfg):
    """Propagate masking information through the data flow graph.

    Args:
        dfg: DataFlowGraph object

    Processes nodes in depth order to ensure inputs are processed before outputs.
    """
    logger = dfg.logger.getChild("masking")
    logger.debug("Propagating masking information through DFG...")

    # Sort nodes by depth to ensure we process inputs before outputs
    sorted_nodes = sorted(dfg.nodes_all, key=lambda n: n.depth)

    for node in sorted_nodes:
        compute_node_masking_info(node, logger)

    # Log output masking info
    for node in dfg.nodes_output:
        for idx, reg in enumerate(node.inst.args_in):
            mask_info = None
            # Find the source of this output
            src = node.src_in[idx]
            # Import here to avoid circular dependency
            from slothy.core.dataflow import InstructionOutput, InstructionInOut
            if isinstance(src, InstructionOutput):
                mask_info = src.src.masking_info_out[src.idx]
            elif isinstance(src, InstructionInOut):
                mask_info = src.src.masking_info_in_out[src.idx]

            if mask_info:
                logger.info(f"Output {reg}: {mask_info}")
            else:
                logger.info(f"Output {reg}: public")


def compute_node_masking_info(node, logger=None):
    """Compute masking information for a node's outputs based on its inputs.

    Args:
        node: ComputationNode object
        logger: Optional logger for debug messages

    For virtual input nodes, masking info is already set in the instruction.
    For other nodes, we combine the masking info from all inputs.
    """
    # Virtual input nodes have masking info already set
    if node.is_virtual_input:
        if node.inst.masking_info is not None:
            node.masking_info_out[0] = node.inst.masking_info
            if logger:
                logger.debug(f"{node.id}: Input has masking {node.inst.masking_info}")
        return

    # For regular instructions, collect masking info from all inputs
    input_masking_infos = []

    # Import here to avoid circular dependency
    from slothy.core.dataflow import InstructionOutput, InstructionInOut

    # Collect from regular inputs
    for src in node.src_in:
        if isinstance(src, InstructionOutput):
            mask_info = src.src.masking_info_out[src.idx]
            input_masking_infos.append(mask_info)
        elif isinstance(src, InstructionInOut):
            mask_info = src.src.masking_info_in_out[src.idx]
            input_masking_infos.append(mask_info)

    # Collect from in/out inputs
    for src in node.src_in_out:
        if isinstance(src, InstructionInOut):
            mask_info = src.src.masking_info_in_out[src.idx]
            input_masking_infos.append(mask_info)

    # Combine masking info for all outputs (for now, same for all outputs)
    try:
        combined = MaskingInfo.combine(input_masking_infos, logger)
        for i in range(len(node.masking_info_out)):
            node.masking_info_out[i] = combined
        for i in range(len(node.masking_info_in_out)):
            node.masking_info_in_out[i] = combined

        if logger and combined:
            logger.debug(f"{node.id}: Output masking computed as {combined}")
    except Exception as e:
        if logger:
            logger.error(f"{node.id}: {str(e)}")
        raise

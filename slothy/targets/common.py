class FatalParsingException(Exception):
    """A fatal error happened during instruction parsing"""


class UnknownInstruction(Exception):
    """The parent instruction class for the given object could not be found"""


class UnknownRegister(Exception):
    """The register could not be found"""

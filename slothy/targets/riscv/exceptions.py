class FatalParsingException(Exception):  # done
    """A fatal error happened during instruction parsing"""

class UnknownInstruction(Exception):  # done
    """The parent instruction class for the given object could not be found"""

class UnknownRegister(Exception):  # done
    """The register could not be found"""

class ParsingException(Exception):
    """An attempt to parse an assembly line as a specific instruction failed

    This is a frequently encountered exception since assembly lines are parsed by
    trial and error, iterating over all instruction parsers."""
    def __init__(self, err=None):
        super().__init__(err)
#!/usr/bin/env python3

# Copyright (c) 2022 Arm Limited
# Copyright (c) 2022 Hanno Becker
# SPDX-License-Identifier: MIT

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import sys
import argparse
import logging
import time
import os

from slothy import Slothy, Archery


class CmdLineException(Exception):
    """Exception thrown when a problem is encountered with the command line parameters"""


def validate_output_path(output_path):
    """Validate that the output path can be written to."""
    if output_path is None:
        return
    output_dir = os.path.dirname(output_path) or "."
    if not os.path.exists(output_dir):
        raise CmdLineException(f"Output directory '{output_dir}' does not exist")
    if not os.path.isdir(output_dir):
        raise CmdLineException(f"'{output_dir}' is not a directory")


def main():
    """Main entry point for the slothy-cli command."""

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "arch", type=str, choices=Archery.list_archs(), help="The target architecture"
    )
    parser.add_argument(
        "target",
        type=str,
        choices=Archery.list_targets(),
        help="The target microarchitecture",
    )
    parser.add_argument("input", type=str, help="The name of the assembly source file.")
    parser.add_argument(
        "-d", "--debug", default=False, action="store_true", help="Show debug output"
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        default=None,
        help="The name of the file to write the generated assembly to. "
        "If unspecified, the assembly will be printed on the standard output.",
    )
    parser.add_argument(
        "-c",
        "--config",
        default=[],
        action="append",
        nargs="*",
        metavar="OPTION=VALUE",
        help="""Set SLOTHY configuration value (can be used multiple times).
                See Python API documentation for details here:
                https://slothy-optimizer.github.io/slothy/apidocs/slothy/slothy.core.config.html""",  # noqa: E501
    )
    parser.add_argument(
        "-l",
        "--loop",
        default=[],
        action="append",
        type=str,
        help="""The starting label for the loop to optimize. This is mutually
                exclusive with -s/--start and -e/--end, which allowv you to specify
                the code to optimize via start/end separately.""",
    )
    parser.add_argument("--fusion", default=False, action="store_true")
    parser.add_argument("--fusion-only", default=False, action="store_true")
    parser.add_argument(
        "--unfold",
        default=False,
        action="store_true",
        help="""Unfold macros and/or register aliases, but don't optimize.
                                See also --unfold-macros and --unfold-aliases.""",
    )
    parser.add_argument(
        "--unfold-macros",
        type=bool,
        default=True,
        help="""If --unfold is set, unfold assembly macros.""",
    )
    parser.add_argument(
        "--unfold-aliases",
        type=bool,
        default=False,
        help="""If --unfold is set, unfold register aliases.""",
    )
    parser.add_argument(
        "-s",
        "--start",
        default=None,
        type=str,
        help="""The label or line at which the to code to optimize begins.
                This is mutually exclusive with -l/--loop.""",
    )
    parser.add_argument(
        "-e",
        "--end",
        default=None,
        type=str,
        help="""The label or line at which the to code to optimize ends
                This is mutually exclusive with -l/--loop.""",
    )
    parser.add_argument(
        "-r",
        "--rename-function",
        default=None,
        type=str,
        help="""Perform function renaming. Format: 'old_func_name,new_func_name'""",
    )
    parser.add_argument(
        "--silent",
        default=False,
        action="store_true",
        help="""Silent mode: Only print warnings and errors""",
    )
    parser.add_argument(
        "--log",
        default=False,
        action="store_true",
        help="""Write logging output to file""",
    )
    parser.add_argument(
        "--logdir", default=".", type=str, help="""Directory to store log output to"""
    )
    parser.add_argument(
        "--logfile",
        default=None,
        type=str,
        help="""File to write logging output to. Can be omitted, "\
                "in which case a generic name with timestamp is used""",
    )

    args = parser.parse_args()

    handlers = []

    h_err = logging.StreamHandler(sys.stderr)
    h_err.setLevel(logging.WARNING)
    handlers.append(h_err)

    if args.log is True and args.logfile is None:
        # By default, use time stamp and input file
        if args.output is not None:
            file_base = os.path.basename(args.output).replace(".", "_")
        else:
            file_base = os.path.basename(args.input).replace(".", "_")
        args.logfile = f"slothy_log_{int(time.time())}_{file_base}.log"
        logfile = f"{args.logdir}/{args.logfile}"

    if args.silent is False:
        h_info = logging.StreamHandler(sys.stdout)
        h_info.setLevel(logging.DEBUG)
        h_info.addFilter(lambda r: r.levelno == logging.INFO)
        handlers.append(h_info)

    if args.debug:
        h_verbose = logging.StreamHandler(sys.stdout)
        h_verbose.setLevel(logging.DEBUG)
        h_verbose.addFilter(lambda r: r.levelno < logging.INFO)
        handlers.append(h_verbose)

    if args.log:
        h_log = logging.FileHandler(logfile)
        h_log.setLevel(logging.DEBUG)
        handlers.append(h_log)

    if args.debug:
        base_level = logging.DEBUG
    else:
        base_level = logging.INFO

    logging.basicConfig(
        level=base_level,
        handlers=handlers,
    )

    logger = logging.getLogger("slothy-cli")

    arch = Archery.get_arch(args.arch)
    target = Archery.get_target(args.target)
    slothy = Slothy(arch, target, logger=logger)

    def parse_config_value_as(val, ty):
        def parse_as_float(val):
            try:
                res = float(val)
                return res
            except ValueError:
                return None

        def check_ty(ty_real):
            if ty is None or ty is type(None) or ty == ty_real:
                return
            raise CmdLineException(
                f"Configuration value {val} isn't correctly typed -- "
                f"expected {ty}, but got {ty_real}"
            )

        if val == "":
            raise CmdLineException("Invalid configuration value")
        logger.debug("Parsing configuration value %s with expected type %s", val, ty)
        if val.isdigit():
            check_ty(int)
            logger.debug("Value %s parsed as integer", val)
            return int(val)
        if val.lower() == "true":
            check_ty(bool)
            logger.debug("Value %s parsed as Boolean", val)
            return True
        if val.lower() == "false":
            check_ty(bool)
            logger.debug("Value %s parsed as Boolean", val)
            return False
        # Try to parse as RegisterType
        ty = arch.RegisterType.from_string(val)
        if ty is not None:
            logger.debug("Value %s parsed as RegisterType", val)
            return ty
        f = parse_as_float(val)
        if f is not None:
            check_ty(float)
            logger.debug("Value %s parsed as float", val)
            return f
        if val[0] == "[" and val[-1] == "]":
            check_ty(list)
            val = val[1:-1].split(",")
            val = list(map(str.strip, val))

            # Find numeric suffix (e.g. x30 -> ('x', 30))
            def split_numeric_suffix(v):
                # Find first digit
                i = next((i for (i, c) in enumerate(v) if c.isdigit()), len(v))
                return v[:i], v[i:]

            # Check for range entries (e.g. 'x10--x18')
            def unfold_range(v):
                if "--" not in v:
                    return [v]
                vs = v.split("--")
                if not len(vs) == 2:
                    logger.debug("Invalid range entry %s -- ignore", v)
                    return [v]
                # Find numeric suffix
                v0, v1 = vs
                v0, v0i = split_numeric_suffix(v0)
                v1, v1i = split_numeric_suffix(v1)
                if v0 != v1:
                    raise CmdLineException(f"Invalid range expression {v}")
                # Ranges are inclusive
                res = [f"{v0}{i}" for i in range(int(v0i), int(v1i) + 1)]
                logger.debug("Decoded range entry %s to %s", v, res)
                return res

            val = [r for v in val for r in unfold_range(v)]
            logger.debug("Parsing %s is a list -- parse recursively", val)
            return [parse_config_value_as(v, None) for v in val]
        if val[0] == "{" and val[-1] == "}":
            check_ty(dict)
            kvs = val[1:-1].split(",")
            kvs = [kv.split(":") for kv in kvs]
            for kv in kvs:
                if not len(kv) == 2:
                    raise CmdLineException("Invalid dictionary entry")
            logger.debug("Parsing %s is a dictionary -- parse recursively", val)
            return {
                parse_config_value_as(k, None): parse_config_value_as(v, None)
                for k, v in kvs
            }
        logger.debug("Parsing %s as string", val)
        return val

    # A plain '-c' without arguments should list all available configuration options
    if [] in args.config:
        slothy.config.list_options()
        return

    if args.rename_function:
        args.rename_function = args.rename_function.split(",")
        if len(args.rename_function) != 2:
            logger.error("Invalid function renaming argument")
            return

    # Parse and set Slothy configuration

    def setattr_recursive(obj, attr, val):
        attr.strip()
        # If attr starts with
        attrs = attr.split(".")
        while len(attrs) > 1:
            obj = getattr(obj, attrs.pop(0))
        attr = attrs.pop(0)
        val = parse_config_value_as(val, type(getattr(obj, attr)))
        logger.info("Setting configuration option %s to value %s", attr, val)
        setattr(obj, attr, val)

    def check_list_of_fixed_len_list(lst):
        invalid = next(filter(lambda o: len(o) != 1, lst), None)
        if invalid is not None:
            raise CmdLineException(f"Invalid configuration argument {invalid} in {lst}")

    check_list_of_fixed_len_list(args.config)
    config_kv_pairs = [c[0].split("=") for c in args.config]
    for kv in config_kv_pairs:
        # We allow shorthands for boolean configurations
        # "-c config.options" as a shorthand for "-c config.options=True"
        # "-c /config.options" as a shorthand for "-c config.options=False"
        # '!' would be more intuitive, but this confuses some shells.
        negate_char = "/"
        if len(kv) == 1:
            kv[0] = kv[0].strip()
            if kv[0][0] == negate_char:
                val = False
                kv[0] = kv[0][1:]
            else:
                val = True
            setattr_recursive(slothy.config, kv[0], str(val))
        elif len(kv) == 2:
            setattr_recursive(slothy.config, kv[0], kv[1])
        else:
            raise CmdLineException(f"Invalid configuration {kv}")

    # Validate output path before starting optimization
    validate_output_path(args.output)

    # Read input
    slothy.load_source_from_file(args.input)

    done = False

    # Unfold only?
    if args.unfold is True:
        slothy.unfold(
            start=args.start,
            end=args.end,
            macros=args.unfold_macros,
            aliases=args.unfold_aliases,
        )
        done = True

    # Fusion
    if done is False and args.fusion is True:
        if len(args.loop) > 0:
            for lll in args.loop:
                slothy.fusion_loop(lll)
        if args.fusion_only:
            done = True

    # Optimize
    if done is False:
        if len(args.loop) > 0:
            for lll in args.loop:
                slothy.optimize_loop(lll)
        else:
            slothy.optimize(start=args.start, end=args.end)

    # Rename
    if args.rename_function:
        slothy.rename_function(args.rename_function[0], args.rename_function[1])
        slothy.rename_function(
            "_" + args.rename_function[0], "_" + args.rename_function[1]
        )

    # Write output
    if args.output is not None:
        slothy.write_source_to_file(args.output)
    else:
        print(slothy.get_source_as_string())


if __name__ == "__main__":
    main()

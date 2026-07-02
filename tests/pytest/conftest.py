#
# Copyright (c) SLOTHY contributors
# SPDX-License-Identifier: MIT
#

"""Pytest configuration for the SLOTHY test suite."""

import sys
from pathlib import Path

# Make the slothy package importable when running `pytest` from the repo root
# without having installed slothy (mirrors how test.py is run from the root).
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

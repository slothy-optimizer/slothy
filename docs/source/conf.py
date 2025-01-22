# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

import os, sys

project = 'SLOTHY'
copyright = '2025, Hanno Becker, Amin Abdulrahman, Matthias Kannwischer, Justus Bergermann'
author = 'Hanno Becker, Amin Abdulrahman, Matthias Kannwischer, Justus Bergermann'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

sys.path.insert(0, os.path.abspath("../../slothy"))

suppress_warnings = [
    'misc.highlighting_failure',
    'myst.xref_missing',
    'autodoc2.dup_item'
]

extensions = [
    'sphinx.ext.imgmath',
    'sphinx_rtd_theme',
    'myst_parser',
    'autodoc2'
]

templates_path = ['_templates']
exclude_patterns = []

source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
}
master_doc = 'index'


autodoc2_packages = [
    "../../slothy",
]


# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "sphinx_rtd_theme"
html_static_path = ['_static']
html_logo = "../slothy_logo.png"
html_theme_options = { 'logo_only': True, }
html_css_files = [
    'css/style.css',
]



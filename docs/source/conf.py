# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'SLOTHY'
copyright = '2024, Hanno Becker, Amin Abdulrahman, Matthias Kannwischer, Justus Bergermann'
author = 'Hanno Becker, Amin Abdulrahman, Matthias Kannwischer, Justus Bergermann'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.imgmath',
    'sphinx_rtd_theme',
    'sphinx.ext.autosectionlabel',
    #'autoapi.extension',
    #'myst_parser',
    'sphinx_mdinclude',

]

templates_path = ['_templates']
exclude_patterns = []

source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
}
master_doc = 'index'

#autoapi_dirs = ['../../slothy']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "sphinx_rtd_theme"
html_static_path = ['_static']
html_logo = "../slothy_logo.png"
html_theme_options = { 'logo_only': True, }
html_css_files = [
    'css/style.css',
]

# Makefile for formatting and linting Python code

# Targets
.PHONY: black flake8 check all

# Format code using black
black:
	black --version
	black . --exclude venv

# Lint code using flake8
flake8:
	flake8 --version
	flake8 . --config .flake8 --exclude venv,.venv

# Run both format and lint
check: black flake8

# Alias for check
all: check

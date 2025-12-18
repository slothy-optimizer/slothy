{
  description = "SLOTHY: Assembly superoptimization via constraint solving";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Use Python 3.12 to match pyproject.toml requirements
        python = pkgs.python312;

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            python
            pkgs.uv
            pkgs.llvmPackages_19.llvm
            pkgs.git
            # C/C++ toolchain from Nix
            pkgs.gcc
            pkgs.gnumake
          ];

          shellHook = ''
            # Set Python for uv
            export UV_PYTHON="${python}/bin/python"

            # Ensure llvm-mca is in PATH
            export PATH="${pkgs.llvmPackages_19.llvm}/bin:$PATH"

            # Create and activate venv if it doesn't exist
            if [ ! -d .venv ]; then
              echo "Creating virtual environment with uv..."
              uv venv .venv --python ${python}/bin/python
            fi

            # Activate the virtual environment
            source .venv/bin/activate

            # Sync dependencies from pyproject.toml
            echo "Syncing dependencies from pyproject.toml..."
            uv sync --all-extras

            echo ""
            echo "======================================"
            echo "SLOTHY development environment"
            echo "======================================"
            echo "Python: $(python --version)"
            echo "uv: $(uv --version)"
            echo "llvm-mca: $(which llvm-mca)"
            echo ""
            echo "You can verify the setup using:"
            echo "  python test.py --tests aarch64_simple0_a55"
            echo "======================================"
            echo ""
          '';
        };
      }
    );
}

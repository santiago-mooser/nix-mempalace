{
  description = "Nix flake for mempalace — AI memory palace for Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    mempalace-src = {
      url = "github:milla-jovovich/mempalace/v3.4.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, mempalace-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python312;

        # The package ships `mempalace` and `mempalace-mcp` console scripts,
        # which the upstream Claude Code plugin (>= 3.4.0) invokes by bare
        # name. Install into the user profile so they land on PATH:
        #   nix profile install ~/repos/nix-mempalace#mempalace
        # The profile is a GC root, so no manual symlink roots are needed.
        mempalace = python.pkgs.buildPythonPackage {
          pname = "mempalace";
          version = "3.4.0";
          pyproject = true;
          src = mempalace-src;

          nativeBuildInputs = [
            python.pkgs.pythonRelaxDepsHook
          ];

          build-system = [
            python.pkgs.hatchling
          ];

          dependencies = [
            python.pkgs.chromadb
            python.pkgs.pyyaml
            python.pkgs.huggingface-hub
            python.pkgs.tokenizers
            python.pkgs.numpy
            python.pkgs.python-dateutil
          ];

          pythonRelaxDeps = [
            "chromadb"
          ];

          doCheck = false;

          meta = {
            description = "Give your AI a memory — mine projects and conversations into a searchable palace.";
            homepage = "https://github.com/milla-jovovich/mempalace";
            license = pkgs.lib.licenses.mit;
            mainProgram = "mempalace";
          };
        };

        pythonWithMempalace = python.withPackages (_: [ mempalace ]);

      in {
        packages = {
          inherit mempalace;
          default = mempalace;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pythonWithMempalace
            python.pkgs.pytest
            python.pkgs.ruff
          ];
        };
      }
    );
}

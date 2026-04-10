{
  description = "Nix flake for mempalace — AI memory palace for Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    mempalace-src = {
      url = "github:milla-jovovich/mempalace";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, mempalace-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python312;

        mempalace = python.pkgs.buildPythonPackage {
          pname = "mempalace";
          version = "3.1.0";
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

        mempalace-mcp = pkgs.writeShellScriptBin "mempalace-mcp" ''
          exec ${pythonWithMempalace}/bin/python3 -m mempalace.mcp_server "$@"
        '';

        mempalace-claude-plugin = pkgs.runCommand "mempalace-claude-plugin-3.1.0" {} ''
          mkdir -p $out
          cp -r ${mempalace-src}/.claude-plugin/* $out/
          chmod -R u+w $out

          substituteInPlace $out/hooks/mempal-stop-hook.sh \
            --replace-warn "python3 -m mempalace" "${pythonWithMempalace}/bin/python3 -m mempalace"
          substituteInPlace $out/hooks/mempal-precompact-hook.sh \
            --replace-warn "python3 -m mempalace" "${pythonWithMempalace}/bin/python3 -m mempalace"

          substituteInPlace $out/plugin.json \
            --replace-warn '"command": "python3"' '"command": "${pythonWithMempalace}/bin/python3"'
        '';

      in {
        packages = {
          inherit mempalace mempalace-mcp mempalace-claude-plugin;
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

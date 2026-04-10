# nix-mempalace

Nix flake for [mempalace](https://github.com/milla-jovovich/mempalace) — an AI memory palace for Claude Code and other AI assistants.

mempalace doesn't work out-of-the-box on NixOS because the system Python is read-only, native dependencies (numpy, onnxruntime) need `libstdc++`, and the chromadb version in nixpkgs exceeds the upstream pin. This flake handles all of that.

## Packages

| Package | Description |
|---------|-------------|
| `mempalace` | The Python package with CLI (`mempalace init`, `mine`, `search`, etc.) |
| `mempalace-mcp` | Wrapper script for the MCP server (for Claude Code / AI assistants) |
| `mempalace-claude-plugin` | Patched `.claude-plugin/` directory with Nix store paths in hooks and MCP config |

## Quick start

```bash
# Run the CLI directly
nix run github:santiago-mooser/nix-mempalace -- init --yes ~/projects/myapp
nix run github:santiago-mooser/nix-mempalace -- mine ~/projects/myapp
nix run github:santiago-mooser/nix-mempalace -- search "some query"

# Register MCP server with Claude Code
nix build github:santiago-mooser/nix-mempalace#mempalace-mcp
claude mcp add mempalace -- ./result/bin/mempalace-mcp
```

## Use as a flake input

```nix
{
  inputs.nix-mempalace.url = "github:santiago-mooser/nix-mempalace";

  outputs = { self, nixpkgs, nix-mempalace, ... }: {
    # Access packages via nix-mempalace.packages.${system}.mempalace
  };
}
```

## How it works

- Uses `pythonRelaxDepsHook` to allow nixpkgs' chromadb (1.5.x) despite the upstream `<0.7` pin — the API surface mempalace uses is stable and backwards-compatible
- Builds mempalace as a Nix Python package with all native dependencies (numpy, onnxruntime, etc.) properly handled via Nix's RPATH
- Patches Claude Code hook scripts and plugin.json at build time with `substituteInPlace` to reference the Nix store Python interpreter

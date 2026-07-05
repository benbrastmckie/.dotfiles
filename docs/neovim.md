# Neovim Configuration

Neovim configuration spans two layers: a Home Manager module in the dotfiles repo
that handles provider injection and tool availability, and a standalone vim config
repository at `~/.config/nvim/` that handles plugins, keybindings, and LSP setup.

## Why home-manager manages neovim

`programs.neovim.enable = true` is kept in `modules/home/core/neovim.nix` for two reasons:

1. **Provider wrapping** -- Home Manager wraps the neovim binary to inject Nix-store
   paths for the Python3 and Ruby providers (`python3_host_prog`, `ruby_host_prog`),
   which would otherwise be unavailable on NixOS. Providers are disabled
   (`withPython3 = false`, `withRuby = false`) since neither is needed by the
   current plugin setup.
2. **`extraPackages`** -- makes packages available on neovim's runtime path.
   `luajitPackages.jsregexp` is required by LuaSnip for snippet expansion and is
   scoped to neovim rather than the global environment.

## sideloadInitLua

By default (introduced in a home-manager update, May 2026), the neovim module writes
its generated provider configuration to `~/.config/nvim/init.lua` as a Home
Manager-managed symlink into the nix store. This overwrites the user's actual
`init.lua`.

`sideloadInitLua = true` tells the module to inject provider configuration via
`--cmd` wrapper arguments on the neovim binary instead. The result is identical --
Python/Ruby providers work -- but `~/.config/nvim/` is left completely unmanaged
by Home Manager.

Without this option, after any `nixos-rebuild switch`, `~/.config/nvim/init.lua`
becomes a read-only nix store symlink containing only the provider configuration
lines, and neovim shows the default startup screen instead of loading the user config.

## Package choice

The `package` is set to `pkgs-unstable.neovim-unwrapped`:

- `unwrapped` is used because home-manager wraps neovim itself to inject provider
  paths. Using the fully-wrapped package (`pkgs.neovim`) would result in double
  wrapping.
- The unstable channel is used to stay current with neovim releases faster than
  the stable nixpkgs channel allows.

## Standalone vim config

The actual neovim configuration (plugins, keybindings, LSP, colorscheme) lives in
`~/.config/nvim/` and is maintained as a separate git repository. It is not part of
this dotfiles repo.

Home Manager should not manage any files under `~/.config/nvim/`. The
`sideloadInitLua` option ensures this separation is maintained, so the standalone
config repository remains the single source of truth for neovim behavior.

## Related

- [Neovim module in modules/home/core/neovim.nix](../modules/home/core/neovim.nix) -- `programs.neovim` block with the
  active configuration values

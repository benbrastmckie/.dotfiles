# Neovim editor configuration via home-manager programs.neovim.
{ pkgs, pkgs-unstable, ... }:
{
  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped; # Use neovim-unwrapped directly from unstable
    withRuby = false;
    withPython3 = false;

    # By default, programs.neovim writes provider config (python3_host_prog,
    # ruby_host_prog, etc.) to ~/.config/nvim/init.lua as a Home Manager-managed
    # symlink, overwriting any user-managed init.lua. sideloadInitLua = true
    # routes that same config through --cmd wrapper args on the neovim binary
    # instead, leaving ~/.config/nvim/ entirely unmanaged by Home Manager.
    # See docs/neovim.md.
    sideloadInitLua = true;

    # jsregexp is required by LuaSnip and must be on neovim's runtime path.
    # Keeping it here (rather than home.packages) scopes it to neovim only.
    extraPackages = [
      pkgs.luajitPackages.jsregexp
      # pkgs.tree-sitter-grammars.tree-sitter-latex  # Add latex grammar for tree-sitter
    ];

    # Note: MCP-Hub is managed via lazy.nvim in NeoVim config
  };
}

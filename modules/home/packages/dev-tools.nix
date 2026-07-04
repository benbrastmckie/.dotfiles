# Development tools: editors, formatters, web, git, system monitoring
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    stylua # Lua formatter for Neovim
    wezterm # GPU-accelerated terminal emulator
    zulip-term # Terminal UI client for Zulip chat
    slidev # Presentation slides from Markdown (sli.dev)
    # sioyek is installed via configuration.nix (Wayland wrapper, CSD disabled)

    # GNOME Shell Extensions
    gnomeExtensions.activate-window-by-title # For cross-window WezTerm tab navigation
    gnomeExtensions.mouse-follows-focus-2 # Warp pointer to keyboard-focused window (task 73: focus-follows-mouse vs keyboard fix)

    # Web Development & API Tools
    httpie # User-friendly HTTP client (better than curl for APIs)
    fx # Interactive JSON viewer

    # Git Enhancement Tools
    glab # GitLab CLI
    delta # Better git diff viewer

    # System Monitoring
    btop # Modern, beautiful system monitor
    htop # Interactive process viewer
    bandwhich # Network bandwidth monitor

    # Documentation Tools
    vale # Prose linting for documentation
    marksman # Markdown language server (LSP)
    mdl # Markdown linter
    prettier # Code formatter (JS/TS/JSON/MD/YAML/CSS)

    # Image Optimization
    imagemagick # Image manipulation
    optipng # PNG optimizer
    jpegoptim # JPEG optimizer

    nodejs # Required runtime dependency
  ];
}

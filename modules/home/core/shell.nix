# Shell configuration: session variables, home.file config sources, and related settings.
{ config, pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    # Prefer Wayland over X11
    NIXOS_OZONE_WL = "1";
    SASL_PATH = "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2";
    # Cursor settings for WezTerm and other applications
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    # Library path for CVC5 C++ dependencies
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    # Centralized literature repository for all projects (Claude Code --lit flag)
    LITERATURE_DIR = "${config.home.homeDirectory}/Projects/Literature";
  };

  home.file = {
    ".config/fastfetch/config.jsonc".source = ../../../config/fastfetch.jsonc;
    ".config/opencode/opencode.json".source = ../../../config/opencode.json;
    ".config/sioyek/prefs_user.config".source = ../../../config/sioyek/prefs_user.config;
    ".config/sioyek/keys_user.config".source = ../../../config/sioyek/keys_user.config;
    # Niri config - ENABLED (dual-session with GNOME)
    ".config/niri/config.kdl".source = ../../../config/config.kdl;
    # WezTerm config is now managed by programs.wezterm above
    # ".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;

    # Active configuration files
    ".config/fish/config.fish".source = ../../../config/config.fish;
    ".config/kitty/kitty.conf".source = ../../../config/kitty.conf;
    ".config/zathura/zathurarc".source = ../../../config/zathurarc;
    ".config/alacritty/alacritty.toml".source = ../../../config/alacritty.toml;
    ".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;
    ".config/himalaya/config.toml".source = ../../../config/himalaya-config.toml;
    # NOTE: .claude/{settings,keybindings}.json managed via activation script (not symlink)
    # so that Claude Code can write runtime changes. Source: config/claude/
    # See home.activation.claudeSettings below.
    ".tmux.conf".source = ../../../config/.tmux.conf;
    ".latexmkrc".source = ../../../config/latexmkrc;

    # Config-files directory (actual file copies for version control)
    ".config/config-files/config.fish".text = builtins.readFile ../../../config/config.fish;
    ".config/config-files/kitty.conf".text = builtins.readFile ../../../config/kitty.conf;
    ".config/config-files/zathurarc".text = builtins.readFile ../../../config/zathurarc;
    ".config/config-files/alacritty.toml".text = builtins.readFile ../../../config/alacritty.toml;
    ".config/config-files/wezterm.lua".text = builtins.readFile ../../../config/wezterm.lua;
    ".config/config-files/.tmux.conf".text = builtins.readFile ../../../config/.tmux.conf;
    ".config/config-files/latexmkrc".text = builtins.readFile ../../../config/latexmkrc;

    # TTS/STT Models - declaratively managed
    ".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;
    ".local/share/vosk/vosk-model-small-en-us-0.15".source = pkgs.vosk-model-small-en-us;
  };

  # Zulip configuration
  home.file.".zuliprc".source = ../../../config/zuliprc;

  # Copy claude config files as regular files (not symlinks) so Claude Code can write to them
  home.activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${config.home.homeDirectory}/.claude
    rm -f ${config.home.homeDirectory}/.claude/settings.json
    cp ${../../../config/claude/settings.json} ${config.home.homeDirectory}/.claude/settings.json
    chmod u+w ${config.home.homeDirectory}/.claude/settings.json
    rm -f ${config.home.homeDirectory}/.claude/keybindings.json
    cp ${../../../config/claude/keybindings.json} ${config.home.homeDirectory}/.claude/keybindings.json
    chmod u+w ${config.home.homeDirectory}/.claude/keybindings.json
  '';

  # Reinstall uv tools after rebuild (Python interpreter path changes break virtualenvs)
  home.activation.uvTools = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if command -v uv &>/dev/null; then
      run uv tool install --force lean-lsp-mcp 2>/dev/null || true
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

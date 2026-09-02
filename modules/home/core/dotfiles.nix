# Dotfiles deployment: session variables, home.file sources from config/, and related
# activation scripts.
# See config/README.md for the full deployment-mechanism reference (symlinks, config-files
# mirrors, and the config/claude/ activation-script copy).
{ config, pkgs, ... }:
{
  home = {
    sessionVariables = {
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

    file = {
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
      # See home.activation.claudeSettings below (settings.json: three-way jq merge that resets
      # only an enforced key set; keybindings.json: plain copy) and, for the distinct
      # single-file ~/.claude.json (mcpServers etc.), home.activation.claudeMcpServers (merge,
      # never overwrite) further below.
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
    file.".zuliprc".source = ../../../config/zuliprc;

    # Claude config files are regular files (not symlinks) so Claude Code can write to them.
    #
    # settings.json is MERGED rather than overwritten, because Claude Code writes this file
    # itself: every setting changed through /config or /model (editorMode, autoCompactEnabled,
    # agentPushNotifEnabled, remoteControlAtStartup, ...) is persisted here. The previous
    # rm -f + cp defeated the very writability the "regular files" choice was made for -- each
    # rebuild silently reverted every interactive change, and the only remedy was to notice the
    # loss and hand-fold each key back into the source.
    #
    # The merge is three-way, so the repo keeps ownership of what it actually cares about:
    #   source defaults  <  live values  <  source enforced keys
    # Keys in ENFORCED are forced back to the source value on every activation (system
    # behaviour and anything the repo references by path). Every other key in the source acts
    # as a seed: it populates a fresh machine, but a live value wins thereafter, so preferences
    # set interactively survive. Keys the source does not mention are always preserved.
    #
    # Adding a key to ENFORCED makes it repo-owned and un-changeable from inside Claude Code
    # (the next rebuild reverts it), so add deliberately. model is enforced on purpose: Opus is
    # the intended default, and a per-session /model switch is still free -- only the persisted
    # default is reset.
    #
    # Failure mode is fail-safe: if the live file is missing or unparseable, or jq errors, the
    # source is copied verbatim rather than leaving a broken or absent settings file. Guarded
    # by the same DRY_RUN variable the claudeMcpServers block below uses, for the same reason.
    #
    # keybindings.json keeps the plain copy: it is not written back by Claude Code the way
    # settings.json is, so there is nothing to preserve.
    activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      claudeDir="${config.home.homeDirectory}/.claude"
      settingsSrc="${../../../config/claude/settings.json}"
      settingsDst="$claudeDir/settings.json"

      if [[ -v DRY_RUN ]]; then
        echo "Would merge $settingsSrc into $settingsDst (enforced keys reset, others preserved)"
        echo "Would copy keybindings.json into $claudeDir"
      else
        mkdir -p "$claudeDir"

        merged=0
        if [ -f "$settingsDst" ] && ${pkgs.jq}/bin/jq -e . "$settingsDst" >/dev/null 2>&1; then
          tmpFile="$(mktemp "$claudeDir/settings.json.XXXXXX")"
          if ${pkgs.jq}/bin/jq -s             --argjson enforced '["_NOTE","env","hooks","model","permissions","statusLine"]'             '.[0] as $src | .[1] as $live
             | ($src * $live)
             | reduce $enforced[] as $k (.;
                 if ($src | has($k)) then .[$k] = $src[$k] else . end)'             "$settingsSrc" "$settingsDst" > "$tmpFile" 2>/dev/null && [ -s "$tmpFile" ]; then
            mv "$tmpFile" "$settingsDst"
            merged=1
          else
            rm -f "$tmpFile"
          fi
        fi

        # No live file, unparseable live file, or a failed merge: fall back to the source.
        if [ "$merged" -eq 0 ]; then
          cp "$settingsSrc" "$settingsDst"
        fi
        chmod u+w "$settingsDst"

        rm -f "$claudeDir/keybindings.json"
        cp ${../../../config/claude/keybindings.json} "$claudeDir/keybindings.json"
        chmod u+w "$claudeDir/keybindings.json"
      fi
    '';

    # Reinstall uv tools after rebuild (Python interpreter path changes break virtualenvs)
    activation.uvTools = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if command -v uv &>/dev/null; then
        run uv tool install --force lean-lsp-mcp 2>/dev/null || true
      fi
    '';

    # Idempotently merge the playwright MCP server into ~/.claude.json (user scope; subagents
    # cannot see project-scoped .mcp.json). Deliberate counterpoint to claudeSettings above:
    # this file also carries Claude Code's OAuth/session/project-list state, which must survive
    # every rebuild, so this block merges via jq (like .claude/scripts/setup-lean-mcp.sh). It
    # preserves every key unconditionally, where claudeSettings above resets its ENFORCED set --
    # nothing here is repo-owned. The existing mcpServers.lean-lsp
    # entry (and every other key) is left untouched. jq output needs shell redirection, which the
    # `run` helper (a plain "$@" exec, no shell) cannot express directly, so — unlike uvTools'
    # `run`-wrapped form — this block guards its own mutating body behind the same `DRY_RUN`
    # variable `run` itself checks, keeping `home-manager switch --dry-run` non-destructive
    # without fighting `run`'s argument-vector-only interface.
    activation.claudeMcpServers = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      claudeJson="${config.home.homeDirectory}/.claude.json"
      if [[ -v DRY_RUN ]]; then
        echo "Would merge mcpServers.playwright into $claudeJson"
      else
        [ -f "$claudeJson" ] || echo '{}' > "$claudeJson"
        tmpFile="$(mktemp "${config.home.homeDirectory}/.claude.json.XXXXXX")"
        if ${pkgs.jq}/bin/jq \
          --argjson cfg '{"type":"stdio","command":"playwright-mcp","args":[]}' \
          '.mcpServers.playwright = $cfg' \
          "$claudeJson" > "$tmpFile"; then
          mv "$tmpFile" "$claudeJson"
          chmod u+w "$claudeJson"
        else
          rm -f "$tmpFile"
        fi
      fi
    '';
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

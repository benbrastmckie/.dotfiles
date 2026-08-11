# Shell configuration — programs.fish and programs.bash system-wide settings.
_: {
  # Shell configuration
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Initialize zoxide for better directory navigation
      zoxide init fish | source

      # Discord bot link token for Neovim integration (read from sops-nix secret)
      if test -r /run/secrets/link_api_token
        set -gx DISCORD_BOT_LINK_TOKEN (cat /run/secrets/link_api_token)
      end

      # Zotero credentials for the literature write-back path (read from sops-nix secret).
      # ZOTERO_API_KEY is what the consuming repo's gate-check scripts test; ZOT_API_KEY /
      # ZOT_LIBRARY_ID are what the zot CLI itself reads. Both are required.
      if test -r /run/secrets/zotero_api_key
        set -gx ZOTERO_API_KEY (cat /run/secrets/zotero_api_key)
        set -gx ZOT_API_KEY $ZOTERO_API_KEY
        # 2622830 is the Zotero userID for benbrastmckie, derived from
        # GET https://api.zotero.org/keys/current on 2026-08-11. Not sensitive (Zotero user IDs
        # are not secret); recorded as a plain constant rather than re-derived on every rebuild.
        set -gx ZOT_LIBRARY_ID 2622830
      end
    '';
  };

  # No precedent existed for programs.bash.interactiveShellInit in this repo before this task —
  # only programs.fish was configured. Bash-specific option preferred over the shell-agnostic
  # environment.interactiveShellInit, matching NixOS docs' guidance not to assume Bash there.
  programs.bash = {
    interactiveShellInit = ''
      # Zotero credentials for the literature write-back path (read from sops-nix secret).
      # Mirrors the fish block above — see its comments for the ZOTERO_API_KEY / ZOT_API_KEY /
      # ZOT_LIBRARY_ID rationale.
      if [ -r /run/secrets/zotero_api_key ]; then
        ZOTERO_API_KEY="$(cat /run/secrets/zotero_api_key)"; export ZOTERO_API_KEY
        ZOT_API_KEY="$ZOTERO_API_KEY"; export ZOT_API_KEY
        export ZOT_LIBRARY_ID=2622830
      fi
    '';
  };
}

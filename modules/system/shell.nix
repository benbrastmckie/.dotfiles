# Shell configuration — programs.fish system-wide settings.
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
    '';
  };
}

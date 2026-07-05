# Discord bot infrastructure — sops secrets, opencode-serve, and discord-bot systemd services.
# Optional/host-toggled module: opt in explicitly per host via
# services.discordBot.enable (see hosts/nandi/default.nix, hosts/hamsa/default.nix +
# flake.nix extraModules).
# See: specs/053_nixos_discord_bot_prerequisites/
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.services.discordBot;

  # Discord Bot packaged application (Task 89)
  # buildPythonApplication derivation for the Nextcord bot service, callPackage'd directly
  # here (not via overlays/python-packages.nix, which is scoped to library overrides
  # composed via python3.withPackages). Replaces the pre-task-89 ad-hoc interpreter
  # environment and manual working-tree sys.path wiring with a real nix-store binary.
  opencodeDiscordBot =
    pkgs.python3Packages.callPackage ../../../packages/opencode-discord-bot.nix
      { };
in
{
  options.services.discordBot.enable = lib.mkEnableOption "the OpenCode Discord bot relay (discord-bot + opencode-serve services)";

  # ==========================================================================
  # Discord Bot Prerequisites (Task 53)
  # ==========================================================================
  # sops-nix decryption: injects bot token and OpenCode password into
  # systemd services via LoadCredential (never on disk unencrypted).
  # Bot project: ~/.dotfiles/packages/opencode-discord-bot/opencode_discord_bot/src/bot.py (Nextcord)
  # See: specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md
  # ==========================================================================

  config = lib.mkIf cfg.enable {

    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      age.keyFile = "${config.users.users.${username}.home}/.config/sops/age/keys.txt";

      secrets = {
        "discord_bot_token" = {
          owner = config.users.users.${username}.name;
        };
        "opencode_server_password" = {
          owner = config.users.users.${username}.name;
        };
        "discord_channel_id" = {
          owner = config.users.users.${username}.name;
        };
        "link_api_token" = {
          owner = config.users.users.${username}.name;
        };
        "ollama_api_key" = {
          owner = config.users.users.${username}.name;
        };
      };
    };

    systemd.services = {
      # ==========================================================================
      # opencode-serve: headless OpenCode agent server binding to localhost.
      # Server password is injected from sops-nix via systemd LoadCredential.
      # ==========================================================================
      opencode-serve = {
        description = "OpenCode headless agent server";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.bash}/bin/bash -c 'OPENCODE_SERVER_PASSWORD=$(cat %d/opencode_server_password) OLLAMA_API_KEY=$(cat %d/ollama_api_key) exec ${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096'";
          Restart = "always";
          RestartSec = "10s";
          LoadCredential = [
            "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
            "ollama_api_key:${config.sops.secrets."ollama_api_key".path}"
          ];
          # Working directory where .opencode/ config lives
          WorkingDirectory = "${config.users.users.${username}.home}/.dotfiles";
          User = config.users.users.${username}.name;
          Group = "users";
        };
      };

      # ==========================================================================
      # discord-bot: Nextcord Discord bot relay for OpenCode agent management.
      # Depends on opencode-serve. Runs the packaged opencodeDiscordBot console script
      # (nix-store binary; no working-tree interpreter search path wiring needed).
      # Session persistence is written to StateDirectory (/var/lib/discord-bot),
      # not the read-only nix store.
      # ==========================================================================
      discord-bot = {
        description = "Discord bot relay for OpenCode agent management";
        after = [
          "network-online.target"
          "opencode-serve.service"
        ];
        wants = [
          "network-online.target"
          "opencode-serve.service"
        ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "notify";
          ExecStart = "${opencodeDiscordBot}/bin/opencode-discord-bot";
          WatchdogSec = "120s";
          Restart = "always";
          RestartSec = "10s";
          StateDirectory = "discord-bot";
          LoadCredential = [
            "discord_bot_token:${config.sops.secrets."discord_bot_token".path}"
            "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
            "discord_channel_id:${config.sops.secrets."discord_channel_id".path}"
            "link_api_token:${config.sops.secrets."link_api_token".path}"
          ];
          Environment = [
            "DISCORD_BOT_TOKEN=%d/discord_bot_token"
            "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
            "OPENCODE_SERVER_URL=http://127.0.0.1:4096"
            "DISCORD_CHANNEL_ID=%d/discord_channel_id"
            "WHITELISTED_USER_IDS="
            "LINK_API_TOKEN=%d/link_api_token"
            "LOG_LEVEL=info"
            "SESSION_STORE_PATH=%S/discord-bot/sessions.json"
          ];
          WorkingDirectory = "${config.users.users.${username}.home}/.dotfiles";
          User = config.users.users.${username}.name;
          Group = "users";
        };
      };
    };
  };
}

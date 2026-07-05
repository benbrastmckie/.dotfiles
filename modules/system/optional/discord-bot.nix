# Discord bot infrastructure — sops secrets, opencode-serve, and discord-bot systemd services.
# Optional/host-toggled module: opt in explicitly per host via
# services.discordBot.enable (see hosts/nandi/default.nix + flake.nix extraModules).
# See: specs/053_nixos_discord_bot_prerequisites/
{ config, lib, pkgs, username, ... }:
let
  cfg = config.services.discordBot;

  # Discord Bot Python environment (Task 53)
  # Dedicated Python 3 environment for the Nextcord bot service
  # (nextcord: Discord library, aiohttp: local HTTP API, anyio: structured concurrency)
  discordBotPython = pkgs.python3.withPackages (p: with p; [
    nextcord
    aiohttp
    anyio
  ]);
in
{
  options.services.discordBot.enable = lib.mkEnableOption "the OpenCode Discord bot relay (discord-bot + opencode-serve services)";

  # ==========================================================================
  # Discord Bot Prerequisites (Task 53)
  # ==========================================================================
  # sops-nix decryption: injects bot token and OpenCode password into
  # systemd services via LoadCredential (never on disk unencrypted).
  # Bot project: ~/.dotfiles/opencode-discord-bot/src/bot.py (Nextcord)
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
    # Depends on opencode-serve. Uses dedicated discordBotPython environment.
    # PYTHONPATH points to bot project at ~/.dotfiles/opencode-discord-bot/.
    # ==========================================================================
    discord-bot = {
      description = "Discord bot relay for OpenCode agent management";
      after = [ "network-online.target" "opencode-serve.service" ];
      wants = [ "network-online.target" "opencode-serve.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";
        WatchdogSec = "120s";
        Restart = "always";
        RestartSec = "10s";
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
          "PYTHONPATH=${config.users.users.${username}.home}/.dotfiles/opencode-discord-bot"
        ];
        WorkingDirectory = "${config.users.users.${username}.home}/.dotfiles";
        User = config.users.users.${username}.name;
        Group = "users";
      };
    };
  };
  };
}

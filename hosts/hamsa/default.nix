# hamsa-specific NixOS configuration.
# Opts hamsa into the optional Discord bot relay (see modules/system/optional/discord-bot.nix
# and .claude/rules/nix.md's Optional / Host-Toggled Modules convention). Wires the tracked
# config to match the discord-bot/opencode-serve units already running on hamsa in practice.
{ ... }:
{
  imports = [ ../../modules/system/optional/discord-bot.nix ];
  services.discordBot.enable = true;
}

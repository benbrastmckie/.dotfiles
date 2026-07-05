# nandi-specific NixOS configuration.
# Opts nandi into the optional Discord bot relay (see modules/system/optional/discord-bot.nix
# and .claude/rules/nix.md's Optional / Host-Toggled Modules convention). Only nandi runs
# the bot; hamsa/garuda/iso/usb-installer do not import this module.
{ ... }:
{
  imports = [ ../../modules/system/optional/discord-bot.nix ];
  services.discordBot.enable = true;
}

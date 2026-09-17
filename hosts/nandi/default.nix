# nandi-specific NixOS configuration.
{ ... }:
{
  # Optional Discord bot relay (discord-bot + opencode-serve services) -- currently DISABLED.
  # Uncomment both lines to re-enable (see modules/system/optional/discord-bot.nix,
  # docs/discord-bot.md, and .claude/rules/nix.md's Optional / Host-Toggled Modules convention).
  # imports = [ ../../modules/system/optional/discord-bot.nix ];
  # services.discordBot.enable = true;
}

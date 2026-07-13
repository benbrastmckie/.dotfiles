# hamsa-specific NixOS configuration.
# Opts hamsa into the optional Discord bot relay (see modules/system/optional/discord-bot.nix
# and .claude/rules/nix.md's Optional / Host-Toggled Modules convention). Wires the tracked
# config to match the discord-bot/opencode-serve units already running on hamsa in practice.
{ ... }:
{
  imports = [ ../../modules/system/optional/discord-bot.nix ];
  services.discordBot.enable = true;

  # Trust the ProtonMail Bridge self-signed CA so aerc (and any other client
  # validating against the system trust store) can send through the local
  # Bridge SMTP listener on 127.0.0.1:1025 without a TLS verification failure.
  # This is a public server certificate (no private-key material); the Bridge
  # regenerates it only if its local vault is reset, at which point re-export
  # protonmail-bridge-ca.pem from the running Bridge and rebuild.
  security.pki.certificateFiles = [ ./protonmail-bridge-ca.pem ];
}

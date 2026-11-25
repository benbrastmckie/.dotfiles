# hamsa-specific NixOS configuration.
_: {
  # VoxCPM2 voice-cloning TTS on the Radeon 890M via ROCm. Enabled on hamsa only: this is the
  # host with the gfx1150 iGPU the ROCm torch targets, and the closure is ~12.6 GiB unpacked,
  # so it has no business on a host that cannot use it. See packages/voxcpm.nix and
  # modules/system/optional/voxcpm.nix.
  imports = [ ../../modules/system/optional/voxcpm.nix ];
  programs.voxcpm.enable = true;

  # Optional Discord bot relay (discord-bot + opencode-serve services) -- currently DISABLED.
  # Uncomment both lines to re-enable (see modules/system/optional/discord-bot.nix,
  # docs/discord-bot.md, and .claude/rules/nix.md's Optional / Host-Toggled Modules convention).
  # imports = [ ../../modules/system/optional/discord-bot.nix ];
  # services.discordBot.enable = true;

  # Trust the ProtonMail Bridge self-signed CA so aerc (and any other client
  # validating against the system trust store) can send through the local
  # Bridge SMTP listener on 127.0.0.1:1025 without a TLS verification failure.
  # This is a public server certificate (no private-key material); the Bridge
  # regenerates it only if its local vault is reset, at which point re-export
  # protonmail-bridge-ca.pem from the running Bridge and rebuild.
  security.pki.certificateFiles = [ ./protonmail-bridge-ca.pem ];
}

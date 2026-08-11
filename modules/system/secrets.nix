# Always-on sops-nix wiring. Hoisted out of modules/system/optional/discord-bot.nix, where
# `sops.defaultSopsFile` and `sops.age.keyFile` previously lived inside `lib.mkIf cfg.enable` —
# secrets availability was accidentally coupled to `services.discordBot.enable`. Both real hosts
# (nandi, hamsa) happen to enable that service, so it "worked" by coincidence, but a new
# always-on secret (zotero_api_key, consumed by modules/system/shell.nix,
# modules/home/services/zotero-env.nix, and modules/home/core/zotero.nix) must not inherit that
# coincidence. This module is imported unconditionally by modules/system/default.nix so
# /run/secrets/zotero_api_key exists on every real host regardless of which optional services
# are enabled.
{
  config,
  username,
  ...
}:
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "${config.users.users.${username}.home}/.config/sops/age/keys.txt";

    secrets."zotero_api_key" = {
      owner = config.users.users.${username}.name;
      mode = "0400";
    };
  };
}

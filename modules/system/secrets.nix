# Always-on sops-nix wiring: `sops.defaultSopsFile` and `sops.age.keyFile`, held here rather
# than in any optional module so that secrets availability is never coupled to an optional
# service's enable toggle. Imported unconditionally by modules/system/default.nix, so
# /run/secrets/zotero_api_key exists on every real host regardless of which optional services
# are on — which is what lets zotero_api_key be consumed by modules/system/shell.nix,
# modules/home/services/zotero-env.nix and modules/home/core/zotero.nix. Keep these two
# file-scoped settings here; a per-service module declares only its own `sops.secrets.*`.
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

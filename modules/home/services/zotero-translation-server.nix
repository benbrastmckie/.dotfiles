# Localhost-only zotero-translation-server: a metadata-resolution HTTP API for the literature
# extension's Zotero write-back path. Uses nixpkgs' pre-built package (no container runtime, no
# image pull, no registry credential surface) rather than podman/oci-containers.
#
# Disabled by default. Enable via:
#   services.zoteroTranslationServer.enable = true;
#
# The package's own default config (share/zotero-translation-server/config/default.json5) binds
# host = "0.0.0.0" — wide open on every interface. The `NODE_CONFIG` env var (the `config` npm
# module's standard override mechanism) is what forces host = "127.0.0.1" here; this is the
# localhost-only guarantee the task requires, verified at runtime via `ss -lntp`.
#
# nodejs override: nixpkgs' zotero-translation-server.nix takes `nodejs` as a plain callPackage
# argument (currently resolving to the "nodejs" alias, Node 24 on this pinned channel). The
# bundled (2023-era) `config` npm package's `Utils.isRegExp` helper crashes under Node 24 with
# `TypeError: Utils.isRegExp is not a function` on EVERY startup (confirmed live, independent of
# any NODE_CONFIG override — this is an upstream Node/package-vintage incompatibility, not
# something this module's config introduces). Node 22 still has the (deprecated but present)
# `util.isRegExp`, so the service is overridden onto `pkgs.nodejs_22` here. `nodejs_20` was tried
# first but is marked insecure on this channel and refuses to build without explicitly
# allowlisting it, so nodejs_22 is the pragmatic minimum-diff fix.
#
# NODE_CONFIG quoting: systemd's `Environment=` parser strips one layer of quoting from the
# value, so a bare `Environment=NODE_CONFIG={"host":"127.0.0.1","port":1969}` has its double
# quotes eaten by systemd itself, leaving `{host:127.0.0.1,port:1969}` (invalid JSON) — confirmed
# live via `systemctl --user show ... -p Environment` and the resulting
# "$NODE_CONFIG environment variable is malformed JSON" warning (server falls back to
# host=0.0.0.0, defeating the localhost-only requirement). Wrapping the WHOLE `NAME=value` pair
# in single quotes at the unit-file level (`Environment=NODE_CONFIG='{"..."}'`) makes systemd
# strip only the outer single quotes and preserve the inner double quotes literally — this is
# the fix applied below, not the `TRANSLATORS_DIR` + `NODE_CONFIG`-file fallback the plan
# documented as an alternative (this fix was simpler and verified working).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zoteroTranslationServer;
  # See the nodejs-override header comment above.
  zoteroTranslationServerPkg = pkgs.zotero-translation-server.override { nodejs = pkgs.nodejs_22; };
  # See the NODE_CONFIG-quoting header comment above: single-quote the whole NAME=value pair so
  # systemd's Environment= parser preserves the inner double quotes verbatim.
  nodeConfigJson = builtins.toJSON {
    host = "127.0.0.1";
    port = cfg.port;
  };
in
{
  options.services.zoteroTranslationServer = {
    enable = lib.mkEnableOption "the local Zotero translation-server (127.0.0.1:1969, metadata resolution)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 1969;
      description = "Port for the Zotero translation-server to listen on (localhost only).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.zotero-translation-server = {
      Unit = {
        Description = "Zotero translation-server (localhost-only metadata resolution)";
      };
      Service = {
        Type = "simple";
        Restart = "on-failure";
        # The package's translatorsDirectory is a relative path ("./modules/translators"), so
        # WorkingDirectory must point at the npm package root for it to resolve.
        WorkingDirectory = "${zoteroTranslationServerPkg}/lib/node_modules/translation-server";
        Environment = [
          "NODE_CONFIG='${nodeConfigJson}'"
        ];
        ExecStart = "${zoteroTranslationServerPkg}/bin/translation-server";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

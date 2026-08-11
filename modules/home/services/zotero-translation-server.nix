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
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zoteroTranslationServer;
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
        WorkingDirectory = "${pkgs.zotero-translation-server}/lib/node_modules/translation-server";
        Environment = [
          ''NODE_CONFIG={"host":"127.0.0.1","port":${toString cfg.port}}''
        ];
        ExecStart = "${pkgs.zotero-translation-server}/bin/translation-server";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

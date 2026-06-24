# Weekly cleanup of regenerable package-manager caches (pip/uv/npm).
# Nix store GC is handled by nix.gc (configuration.nix) and
# home-manager generation expiry by services.home-manager.autoExpire.
# See task 64. (systemd.user.tmpfiles.rules avoided due to HM issue #8125.)
{ config, pkgs, ... }:
{
  systemd.user.services.cache-cleanup = {
    Unit = {
      Description = "Purge regenerable package-manager caches (pip/uv/npm)";
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "cache-cleanup" ''
            export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
            echo "cache-cleanup: starting"
            command -v pip >/dev/null 2>&1 && pip cache purge || true
            command -v uv  >/dev/null 2>&1 && uv cache clean || true
            command -v npm >/dev/null 2>&1 && npm cache clean --force || true
            ${pkgs.coreutils}/bin/rm -rf "${config.home.homeDirectory}/.npm/_npx" || true
            echo "cache-cleanup: done"
          '';
        in
        "${script}";
    };
  };

  systemd.user.timers.cache-cleanup = {
    Unit = {
      Description = "Weekly timer for regenerable cache cleanup";
      Requires = [ "cache-cleanup.service" ];
    };
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = 3600;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}

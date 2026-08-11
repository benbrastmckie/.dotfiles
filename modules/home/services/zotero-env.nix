# Propagates the Zotero API credential into the systemd `--user` manager's default environment,
# so headless and agent-spawned units started after activation inherit it via
# `systemctl --user show-environment`.
#
# home.sessionVariables CANNOT do this: it writes a profile script sourced by login shells, but
# systemd --user units do not automatically inherit it (home-manager issue #5542, still open as
# of this writing). systemd.user.sessionVariables (an environment.d(5) drop-in) was also
# rejected: its value is a plain Nix string baked at BUILD time and parsed literally by systemd's
# generator — no `$(cat ...)` expansion — so it cannot carry a runtime-decrypted sops secret path
# at all. A oneshot unit calling `systemctl --user set-environment` is the correct mechanism for
# exactly this problem: it updates the user manager's default environment at activation/session
# time, independent of shell inheritance.
#
# Ordering caveat: `set-environment` affects units started *after* it runs; already-running units
# keep their old environment until restarted.
{ config, pkgs, ... }:
let
  script = pkgs.writeShellScript "zotero-env" ''
    if [ -r /run/secrets/zotero_api_key ]; then
      key="$(cat /run/secrets/zotero_api_key)"
      systemctl --user set-environment ZOTERO_API_KEY="$key" ZOT_API_KEY="$key" ZOT_LIBRARY_ID=2622830
    else
      echo "zotero-env: /run/secrets/zotero_api_key not readable; skipping (secret not yet provisioned on this host, or this is a pre-Phase-4 state)" >&2
    fi
  '';
in
{
  systemd.user.services.zotero-env = {
    Unit = {
      Description = "Propagate Zotero credentials into the systemd --user environment";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${script}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}

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
#
# Latch hazard (why ConditionPathExists and the non-zero skip below both exist): this unit is a
# `oneshot` with `RemainAfterExit = true`, so whatever terminal state it reaches on its first run
# persists for the life of the user manager. An earlier revision's skip path echoed a message and
# exited 0, which systemd recorded as `active (exited)` — indistinguishable from a real success.
# When the secret was provisioned later by a subsequent `nixos-rebuild switch`, nothing
# re-triggered the unit (its own definition had not changed), so the user environment stayed
# silently empty while `systemctl status` reported success. Observed live: the unit "succeeded"
# at 09:32 against a secret that did not exist until 13:56.
#
# The two guards split the two distinct failure modes so neither can masquerade as success:
#   - ConditionPathExists: the secret does not exist yet (first provisioning, pre-switch state).
#     systemd re-evaluates conditions on EVERY start attempt and reports `condition failed`
#     without entering an active state, so the unit never latches and recovers cleanly once the
#     secret appears.
#   - Non-zero exit below: the secret exists but is unreadable (wrong owner/mode — a genuine
#     misconfiguration, not a bootstrap-ordering artifact). This surfaces as a real unit failure,
#     because it is one.
{ pkgs, ... }:
let
  script = pkgs.writeShellScript "zotero-env" ''
    if [ -r /run/secrets/zotero_api_key ]; then
      key="$(cat /run/secrets/zotero_api_key)"
      systemctl --user set-environment ZOTERO_API_KEY="$key" ZOT_API_KEY="$key" ZOT_LIBRARY_ID=2622830
    else
      # Reachable only when the file exists (ConditionPathExists passed) but is not readable.
      # Exit non-zero deliberately: `RemainAfterExit` would otherwise latch this skip as a
      # permanent success. See the latch-hazard note above.
      echo "zotero-env: /run/secrets/zotero_api_key exists but is not readable (check owner/mode; expected 0400 benjamin)" >&2
      exit 1
    fi
  '';
in
{
  systemd.user.services.zotero-env = {
    Unit = {
      Description = "Propagate Zotero credentials into the systemd --user environment";
      # Re-evaluated on every start; keeps the not-yet-provisioned case out of the active state
      # entirely rather than latching it as a false success.
      ConditionPathExists = "/run/secrets/zotero_api_key";
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

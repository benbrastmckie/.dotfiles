# Gmail OAuth2 token refresh service and timer — PARKED. The entire body below is commented
# out deliberately; this module contributes nothing to the configuration as it stands. See
# specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md for the decision.
#
# Why it has no consumer: this service exists only to keep a Gmail XOAUTH2 access token fresh
# for `mbsync`, and mbsync authenticates with the Gmail app password instead (AuthMechs LOGIN —
# see modules/home/email/mbsync.nix). himalaya and aerc use that same app password. Nothing on
# this machine reads an XOAUTH2 token.
#
# Do NOT re-enable casually. The stored refresh token is expired/revoked (`invalid_grant`), so
# the timer would re-run this oneshot every 45 min and fail every time, leaving the user systemd
# session permanently "degraded" — visible on every `home-manager switch`. Restoring XOAUTH2
# properly means publishing the OAuth app to Production, which requires a Google CASA Tier 2
# assessment (multi-week, paid, annual); the app-password path avoids that entirely.
#
# To restore anyway: uncomment below and re-point mbsync.nix's Gmail store to AuthMechs XOAUTH2.
# deadnix: skip
{ config, ... }:
{
  # systemd.user.services.gmail-oauth2-refresh = {
  #   Unit = {
  #     Description = "Refresh Gmail OAuth2 tokens";
  #     After = [ "graphical-session.target" ];
  #   };
  #   Service = {
  #     Type = "oneshot";
  #     ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
  #     EnvironmentFile = "%h/.config/gmail-oauth2.env";
  #   };
  # };
  #
  # systemd.user.timers.gmail-oauth2-refresh = {
  #   Unit = {
  #     Description = "Timer for Gmail OAuth2 token refresh";
  #     Requires = [ "gmail-oauth2-refresh.service" ];
  #   };
  #   Timer = {
  #     OnCalendar = "*:0/45"; # Every 45 minutes
  #     Persistent = true;
  #     RandomizedDelaySec = 300; # Random delay up to 5 minutes
  #   };
  #   Install = {
  #     WantedBy = [ "timers.target" ];
  #   };
  # };
}

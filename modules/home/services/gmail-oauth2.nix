# Gmail OAuth2 token refresh service and timer
#
# DISABLED 2026-07-02 (task 72, Phase 3 — see
# specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md).
#
# Why this is no longer needed:
#   - This service existed ONLY to keep a Gmail XOAUTH2 access token fresh for `mbsync`.
#   - mbsync now authenticates with the Gmail app password (AuthMechs LOGIN) — see
#     modules/home/email/mbsync.nix — and himalaya/aerc were already on the app password.
#     Nothing reads the OAuth2 tokens anymore, so this refresh has no consumer.
#   - The underlying refresh token is expired/revoked (`invalid_grant`), so the timer was
#     re-running this oneshot every 45 min only to FAIL every time, leaving the user systemd
#     session permanently "degraded" (visible on each `home-manager switch`).
#   - Publishing the OAuth app to Production to fix XOAUTH2 would require a Google CASA Tier 2
#     assessment (multi-week, paid, annual); the app-password path avoids that entirely.
#
# Kept (commented, not deleted) so re-enabling XOAUTH2 later is a one-block revert. To restore:
# uncomment below and re-point mbsync.nix's Gmail store back to AuthMechs XOAUTH2.
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

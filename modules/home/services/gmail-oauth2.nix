# Gmail OAuth2 token refresh service and timer
{ config, ... }:
{
  # Systemd user services for OAuth2 token refresh
  systemd.user.services.gmail-oauth2-refresh = {
    Unit = {
      Description = "Refresh Gmail OAuth2 tokens";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
      EnvironmentFile = "%h/.config/gmail-oauth2.env";
    };
  };

  systemd.user.timers.gmail-oauth2-refresh = {
    Unit = {
      Description = "Timer for Gmail OAuth2 token refresh";
      Requires = [ "gmail-oauth2-refresh.service" ];
    };
    Timer = {
      OnCalendar = "*:0/45"; # Every 45 minutes
      Persistent = true;
      RandomizedDelaySec = 300; # Random delay up to 5 minutes
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}

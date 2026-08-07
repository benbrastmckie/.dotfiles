# Memory monitoring user services
# Part of the three-tier memory monitoring system:
#   Tier 1: earlyoom (system-level OOM prevention in modules/system/power.nix)
#   Tier 2: memory-monitor (aggregate usage logging and desktop alerts)
#   Tier 3: process-memory-tracker (top-N per-process attribution)
#
# See docs/memory-monitoring.md for the log schemas and analysis recipes.
{ config, ... }:
{
  # Memory monitor service - logs system memory and sends desktop alerts
  systemd.user.services.memory-monitor = {
    Unit = {
      Description = "System memory monitor with desktop alerts";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/memory-monitor";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Process memory tracker service - logs the top RSS consumers system-wide
  #
  # Supersedes the former claude-memory-tracker unit. Home Manager's sd-switch
  # stops and removes the old unit on activation, since it is no longer declared.
  systemd.user.services.process-memory-tracker = {
    Unit = {
      Description = "Top-N process memory tracker";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/process-memory-tracker";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # DISABLED: pgrep -f 'claude' self-matches inhibitor script, memory-tracker,
  # earlyoom, etc., causing sleep to be permanently blocked.
  # systemd.user.services.claude-sleep-inhibitor = { ... };
}

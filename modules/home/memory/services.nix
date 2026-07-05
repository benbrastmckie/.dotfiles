# Memory monitoring user services
# Part of the three-tier memory monitoring system:
#   Tier 1: earlyoom (system-level OOM prevention in configuration.nix)
#   Tier 2: memory-monitor (user-level logging and alerts)
#   Tier 3: claude-memory-tracker (process-specific tracking)
#
# See: specs/26_memory_monitoring_systemd_services_nixos
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

  # Claude memory tracker service - tracks Claude process memory usage
  systemd.user.services.claude-memory-tracker = {
    Unit = {
      Description = "Claude process memory tracker";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/claude-memory-tracker";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # DISABLED: pgrep -f 'claude' self-matches inhibitor script, memory-tracker,
  # earlyoom, etc., causing sleep to be permanently blocked. See task 50.
  # systemd.user.services.claude-sleep-inhibitor = { ... };
}

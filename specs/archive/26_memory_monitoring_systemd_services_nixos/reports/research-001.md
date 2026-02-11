# Research Report: Memory Monitoring Systemd Services for NixOS

- **Task**: 26 - memory_monitoring_systemd_services_nixos
- **Started**: 2026-02-10T12:00:00Z
- **Completed**: 2026-02-10T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**: NixOS documentation, nixpkgs source, NixOS Discourse, local configuration.nix and home.nix
- **Artifacts**: This research report
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- NixOS provides robust memory management infrastructure via earlyoom, systemd-oomd, and ananicy-cpp for system-level protection
- Home Manager's `systemd.user.services` is the recommended approach for user-level monitoring services with desktop notifications
- Desktop notifications from systemd services require proper D-Bus session bus access (`DBUS_SESSION_BUS_ADDRESS`)
- Process-specific tracking (like Claude) can be implemented using standard procps tools (ps, pgrep) available on the system
- The existing codebase already uses systemd user services pattern (ydotool, gmail-oauth2-refresh) which can be extended
- A three-tier monitoring approach is recommended: earlyoom for system protection, custom user service for logging and alerts, and process watcher for Claude-specific tracking

## Context & Scope

This research investigates NixOS approaches for implementing memory monitoring systemd services, specifically:
1. Continuous memory logging to track system memory usage patterns
2. Threshold-based desktop alerts to warn users before memory exhaustion
3. Claude process tracking to identify memory leaks and usage patterns

The implementation should integrate with the existing NixOS flake configuration and Home Manager setup.

## Findings

### Existing Configuration Patterns

The local configuration already uses systemd services in both system and user contexts:

**System Services (configuration.nix)**:
```nix
systemd.services = {
  disable-speaker-amp = {
    description = "Disable internal speaker amplifier";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.alsa-tools}/bin/hda-verb ...";
    };
  };
};
```

**User Services (home.nix)**:
```nix
systemd.user.services.ydotool = {
  Unit = {
    Description = "ydotool daemon for input automation";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = "${pkgs.ydotool}/bin/ydotoold";
    Restart = "on-failure";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

### Available Memory Monitoring Tools

**System-Level Protection**:

1. **earlyoom** - Early OOM daemon for Linux
   - NixOS module: `services.earlyoom.enable = true`
   - Key options:
     - `freeMemThreshold` (default 10%): Below this, sends SIGTERM to largest process
     - `freeSwapThreshold` (default 10%): Swap space threshold
     - `enableNotifications`: Sends D-Bus notifications (requires systembus-notify)
     - `killHook`: Script executed when process is killed
     - `reportInterval`: Memory status reporting (default 3600 seconds)
   - Source: [nixpkgs earlyoom.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/earlyoom.nix)

2. **systemd-oomd** - systemd's built-in OOM killer
   - Enabled by default on NixOS 24.05+
   - Uses Linux pressure stall information (PSI) for decisions
   - Operates in userspace before kernel OOM killer
   - Reference: [nixpkgs Issue #113903](https://github.com/NixOS/nixpkgs/issues/113903)

3. **ananicy-cpp** - Process priority and OOM score manager
   - NixOS module: `services.ananicy.enable = true`
   - Features:
     - `oom_score_adj`: Control OOM kill priority (-999 to 999)
     - Process scheduling policies (batch, idle, realtime)
     - cgroup assignment
   - Source: [nixpkgs ananicy.nix](https://github.com/NixOS/nixpkgs/blob/release-24.11/nixos/modules/services/misc/ananicy.nix)

**Monitoring Tools in nixpkgs**:

The following packages are already installed or available:
- `btop` - Modern system monitor (installed in home.nix)
- `htop` - Interactive process viewer (installed in home.nix)
- `procps` - System utilities (ps, pgrep, free) - available system-wide (confirmed: procps-ng 4.0.4)
- `libnotify` - Desktop notification tool (installed in home.nix)

### Desktop Notification Patterns

**Challenge**: System services lack D-Bus session access needed for desktop notifications.

**Solution 1: User Services (Recommended)**

User services automatically inherit session context:
```nix
systemd.user.services.memory-alert = {
  Service = {
    ExecStart = "${pkgs.writeShellScript "memory-check" ''
      ${pkgs.libnotify}/bin/notify-send "Memory Warning" "Usage above 80%"
    ''}";
  };
};
```

**Solution 2: Explicit D-Bus Configuration**

For system services that need user notifications:
```nix
systemd.services.memory-alert = {
  serviceConfig = {
    User = "benjamin";
    Environment = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus";
  };
};
```

Source: [NixOS Discourse - Desktop notifications from Systemd Service](https://discourse.nixos.org/t/desktop-notifications-from-systemd-service/17672)

### Systemd Timer Patterns for NixOS

Standard pattern for recurring tasks:

```nix
# Service definition
systemd.services.memory-logger = {
  serviceConfig.Type = "oneshot";
  path = with pkgs; [ procps ];
  script = ''
    free -m >> /var/log/memory-usage.log
  '';
};

# Timer definition
systemd.timers.memory-logger = {
  wantedBy = [ "timers.target" ];
  partOf = [ "memory-logger.service" ];
  timerConfig = {
    OnCalendar = "*:0/5";  # Every 5 minutes
    Unit = "memory-logger.service";
  };
};
```

Source: [Repeated Tasks with Systemd Service/Timers on NixOS](https://www.codyhiar.com/blog/repeated-tasks-with-systemd-service-timers-on-nixos/)

### Process-Specific Monitoring (Claude)

Standard Linux tools for process tracking:

```bash
# Find Claude processes
pgrep -f "claude" | xargs ps -o pid,rss,vsize,%mem,comm

# Monitor specific process memory
ps -o pid,rss,vsize,%mem,comm -p $(pgrep -f claude)

# Continuous monitoring with pidstat
pidstat -r -p $(pgrep -f claude) 2 3
```

**Implementation Pattern**:
```nix
(pkgs.writeShellScriptBin "claude-memory-track" ''
  #!/usr/bin/env bash
  LOG_FILE="$HOME/.local/share/memory-monitor/claude.log"
  mkdir -p "$(dirname "$LOG_FILE")"

  while true; do
    PIDS=$(${pkgs.procps}/bin/pgrep -f "claude" 2>/dev/null)
    if [ -n "$PIDS" ]; then
      TIMESTAMP=$(date -Iseconds)
      for PID in $PIDS; do
        MEM=$(${pkgs.procps}/bin/ps -o rss= -p "$PID" 2>/dev/null)
        if [ -n "$MEM" ]; then
          echo "$TIMESTAMP,$PID,$MEM" >> "$LOG_FILE"
        fi
      done
    fi
    sleep 60
  done
'')
```

### Recommended Architecture

**Tier 1: System Protection (configuration.nix)**

Enable earlyoom for OOM prevention:
```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  freeSwapThreshold = 10;
  enableNotifications = true;  # Requires trusted users
};
```

**Tier 2: User Memory Monitoring (home.nix)**

Create user service for continuous logging and alerts:
```nix
systemd.user.services.memory-monitor = {
  Unit = {
    Description = "Memory usage monitor and alerter";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = "${memory-monitor-script}";
    Restart = "on-failure";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

**Tier 3: Process Tracker (home.nix)**

Optional Claude-specific monitoring:
```nix
systemd.user.services.claude-memory-tracker = {
  Unit = {
    Description = "Claude process memory tracker";
    After = [ "default.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = "${claude-tracker-script}";
    Restart = "on-failure";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

## Decisions

1. **Use Home Manager for user services**: User services (`systemd.user.services`) are preferred over system services for desktop notifications and user-specific monitoring
2. **Enable earlyoom for system protection**: Provides last-resort OOM prevention with configurable thresholds
3. **Use procps tools**: Standard `ps`, `pgrep`, and `free` commands are sufficient for monitoring without additional dependencies
4. **Log to XDG directories**: Store logs in `~/.local/share/memory-monitor/` following XDG conventions
5. **Use libnotify for alerts**: Already installed, provides reliable desktop notification support

## Recommendations

### Priority 1: Enable System Protection
- Enable `services.earlyoom` in configuration.nix with appropriate thresholds
- Consider enabling notifications for killed processes

### Priority 2: Create Memory Monitor Service
- Create a Home Manager systemd user service for continuous logging
- Implement threshold-based alerts using libnotify
- Log to `~/.local/share/memory-monitor/system.log`

### Priority 3: Add Claude Process Tracker
- Create optional service specifically for tracking Claude/claude-code processes
- Log RSS, virtual memory, and timestamps
- Enable pattern analysis for memory leak detection

### Implementation Approach
1. Create shell scripts as nixpkgs `writeShellScriptBin` packages
2. Define systemd user services in home.nix
3. Add timer for log rotation or use logrotate
4. Implement configurable thresholds (80% warning, 90% critical)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Notification spam during high memory usage | Implement cooldown period (e.g., 5 minutes between alerts) |
| Log file growth | Implement log rotation or daily truncation |
| Performance impact of monitoring | Use efficient polling intervals (30-60 seconds) |
| earlyoom kills wrong process | Configure prefer/avoid patterns for critical processes |
| D-Bus session issues | Use user services to inherit session context automatically |

## Appendix

### References

- [NixOS earlyoom module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/earlyoom.nix)
- [earlyoom GitHub](https://github.com/rfjakob/earlyoom)
- [Desktop notifications from Systemd Service - NixOS Discourse](https://discourse.nixos.org/t/desktop-notifications-from-systemd-service/17672)
- [Repeated Tasks with Systemd Timers on NixOS](https://www.codyhiar.com/blog/repeated-tasks-with-systemd-service-timers-on-nixos/)
- [Home Manager systemd module](https://github.com/nix-community/home-manager/blob/master/modules/systemd.nix)
- [NixOS Discourse - Avoid Linux locking up with earlyoom](https://discourse.nixos.org/t/avoid-linux-locking-up-in-low-memory-situations-using-earlyoom/22072)
- [ananicy-cpp GitLab](https://gitlab.com/ananicy-cpp/ananicy-cpp)
- [Log Memory Consumption on Linux - Baeldung](https://www.baeldung.com/linux/log-memory-consumption)
- [Monitor Resource Usage of a Single Process - Baeldung](https://www.baeldung.com/linux/monitor-process-resource-usage)

### Search Queries Used

1. "NixOS memory monitoring systemd service continuous logging 2025 2026"
2. "NixOS earlyoom memory pressure threshold alert notification"
3. "NixOS desktop notification libnotify systemd service memory alert"
4. "nixpkgs prometheus node exporter memory monitoring home-manager"
5. "home-manager systemd user service timer memory logging bash script"
6. "linux process memory tracking pgrep ps specific process monitor script"
7. "NixOS ananicy-cpp memory management priority"
8. "NixOS systemd-oomd memory killer alternative earlyoom"

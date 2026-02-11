# Implementation Plan: Task #26

- **Task**: 26 - memory_monitoring_systemd_services_nixos
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/26_memory_monitoring_systemd_services_nixos/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Implement a three-tier memory monitoring solution for NixOS: earlyoom for system-level OOM prevention, a user-space memory monitor with desktop alerts, and Claude-specific process tracking. The implementation leverages existing patterns from home.nix (ydotool, gmail-oauth2-refresh services) and uses Home Manager systemd user services for desktop notification access.

### Research Integration

Key findings from research-001.md:
- NixOS provides `services.earlyoom` module for system protection
- Home Manager `systemd.user.services` is preferred for desktop notifications (automatic D-Bus session access)
- Existing codebase patterns: ydotool service template, gmail-oauth2-refresh timer template
- Use procps tools (ps, pgrep, free) and libnotify for monitoring and alerts
- Log to XDG directories (`~/.local/share/memory-monitor/`)

## Goals & Non-Goals

**Goals**:
- Enable earlyoom for system-level OOM prevention with appropriate thresholds
- Create a user-space memory monitoring service with configurable alerts
- Implement Claude process tracking for memory leak detection
- Log memory usage patterns for analysis
- Integrate with desktop notifications for user alerts

**Non-Goals**:
- Implementing a full Prometheus/Grafana monitoring stack
- Real-time memory profiling or performance optimization
- Automatic process killing beyond earlyoom's built-in functionality
- Cross-host configuration (this is for the user's workstation only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Notification spam during high memory usage | M | M | Implement cooldown period (5 min between alerts) |
| Log file growth consuming disk space | M | M | Implement daily log rotation or size limits |
| Performance impact from monitoring | L | L | Use efficient polling intervals (30-60 seconds) |
| earlyoom kills wrong process | H | L | Configure prefer/avoid patterns for critical processes |
| D-Bus session issues in edge cases | L | L | Use user services to inherit session context automatically |

## Implementation Phases

### Phase 1: Enable earlyoom System Protection [COMPLETED]

**Goal**: Configure earlyoom for last-resort OOM prevention with notifications

**Tasks**:
- [ ] Add `services.earlyoom` configuration to configuration.nix
- [ ] Set memory threshold at 10% (default)
- [ ] Enable notifications for killed processes
- [ ] Test earlyoom is running with `systemctl status earlyoom`

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add earlyoom service configuration

**Verification**:
- `systemctl status earlyoom` shows active
- `journalctl -u earlyoom` shows memory reporting

---

### Phase 2: Create Memory Monitor Script [COMPLETED]

**Goal**: Create shell script for memory monitoring with alerts

**Tasks**:
- [ ] Create `memory-monitor` script as `writeShellScriptBin` in home.nix
- [ ] Implement memory usage checking using `free` command
- [ ] Add threshold-based notifications (80% warning, 90% critical)
- [ ] Implement cooldown logic to prevent notification spam
- [ ] Log memory usage to `~/.local/share/memory-monitor/system.log`

**Timing**: 45 minutes

**Files to modify**:
- `home.nix` - Add memory-monitor script to home.packages

**Verification**:
- Script runs without errors: `memory-monitor --check`
- Notifications appear when thresholds are exceeded
- Log file is created and populated

---

### Phase 3: Create Claude Tracker Script [COMPLETED]

**Goal**: Create script for tracking Claude process memory usage

**Tasks**:
- [ ] Create `claude-memory-tracker` script as `writeShellScriptBin` in home.nix
- [ ] Implement process detection using `pgrep -f "claude"`
- [ ] Log PID, RSS, virtual memory, and timestamp to CSV format
- [ ] Handle case when no Claude processes are running

**Timing**: 30 minutes

**Files to modify**:
- `home.nix` - Add claude-memory-tracker script to home.packages

**Verification**:
- Script runs without errors
- When Claude is running, log entries are created
- When Claude is not running, script handles gracefully

---

### Phase 4: Create systemd User Services [COMPLETED]

**Goal**: Configure systemd user services and timers for monitoring

**Tasks**:
- [ ] Create `systemd.user.services.memory-monitor` in home.nix (continuous service)
- [ ] Create `systemd.user.services.claude-memory-tracker` in home.nix (continuous service)
- [ ] Follow existing ydotool service pattern for consistency
- [ ] Set appropriate restart policies

**Timing**: 30 minutes

**Files to modify**:
- `home.nix` - Add systemd user service definitions

**Verification**:
- `systemctl --user status memory-monitor` shows active
- `systemctl --user status claude-memory-tracker` shows active
- Services restart on failure

---

### Phase 5: Testing and Verification [COMPLETED]

**Goal**: Verify complete system and document usage

**Tasks**:
- [ ] Run `nix flake check` to validate configuration
- [ ] Run `nixos-rebuild switch --flake .#hostname` to apply changes
- [ ] Verify all services are running
- [ ] Test memory alerts by simulating high memory usage
- [ ] Verify log files are created and populated
- [ ] Document commands for checking service status

**Timing**: 25 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- Configuration builds without errors
- All three tiers operational: earlyoom, memory-monitor, claude-memory-tracker
- Logs show expected entries
- Notifications work when thresholds exceeded

## Testing & Validation

- [ ] `nix flake check` passes without errors
- [ ] `nixos-rebuild switch` completes successfully
- [ ] `systemctl status earlyoom` shows active
- [ ] `systemctl --user status memory-monitor` shows active
- [ ] `systemctl --user status claude-memory-tracker` shows active
- [ ] Memory log file created at `~/.local/share/memory-monitor/system.log`
- [ ] Claude log file created at `~/.local/share/memory-monitor/claude.log`
- [ ] Desktop notifications appear when memory exceeds 80%

## Artifacts & Outputs

- `configuration.nix` - Modified with earlyoom configuration
- `home.nix` - Modified with scripts and systemd services
- `~/.local/share/memory-monitor/system.log` - System memory log (runtime)
- `~/.local/share/memory-monitor/claude.log` - Claude process log (runtime)
- `specs/26_memory_monitoring_systemd_services_nixos/summaries/implementation-summary-YYYYMMDD.md` - Implementation summary

## Rollback/Contingency

If implementation causes issues:
1. Disable earlyoom: Set `services.earlyoom.enable = false` in configuration.nix
2. Stop user services: `systemctl --user stop memory-monitor claude-memory-tracker`
3. Disable user services: Comment out or remove systemd.user.services definitions
4. Rebuild: `nixos-rebuild switch --flake .#hostname`
5. Remove log directory: `rm -rf ~/.local/share/memory-monitor`

All changes are declarative and can be reverted by removing the added configuration blocks.

# Implementation Plan: Task #24

- **Task**: 24 - Implement Protonmail Bridge systemd autostart in NixOS config
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/24_protonmail_bridge_nixos_config/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Use the official home-manager `services.protonmail-bridge` module to enable ProtonMail Bridge as a systemd user service. This replaces manual package installation with declarative service configuration. The research identified this as the recommended approach with minimal code changes.

### Research Integration

- Official home-manager module available at `services.protonmail-bridge`
- Module automatically adds package to `home.packages` (so manual entry should be removed)
- Module uses `--noninteractive` flag and starts after `graphical-session.target`
- Credentials already configured in `~/.config/protonmail/bridge-v3/`

## Goals & Non-Goals

**Goals**:
- Enable ProtonMail Bridge to start automatically on login via systemd
- Use official home-manager module for maintainability
- Remove redundant package declaration

**Non-Goals**:
- Changing ProtonMail Bridge configuration or credentials
- Modifying mbsync/himalaya email client configuration
- Custom restart policies or timeouts (module defaults are acceptable)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Module not available | M | Very Low | Using master branch of home-manager; fallback to manual service |
| Service fails to start | L | Low | Credentials already configured; verify with systemctl status |
| Port conflict | M | Very Low | Fixed ports 1143/1025; no other services use them |

## Implementation Phases

### Phase 1: Configure ProtonMail Bridge Service [NOT STARTED]

**Goal**: Enable ProtonMail Bridge systemd service using home-manager module

**Tasks**:
- [ ] Add `services.protonmail-bridge` configuration block to home.nix
- [ ] Remove `protonmail-bridge` from `home.packages` list (line 185)
- [ ] Apply configuration with `home-manager switch`
- [ ] Verify service is running and ports are listening

**Timing**: 0.5 hours

**Files to modify**:
- `home.nix` - Add service configuration (4 lines), remove package from list (1 line)

**Changes**:

1. Add after line 850 (after `services.mako` block):
```nix
# ProtonMail Bridge systemd service for local IMAP/SMTP
services.protonmail-bridge = {
  enable = true;
  logLevel = "info";
};
```

2. Remove line 185:
```nix
protonmail-bridge  # Protonmail Bridge for local IMAP/SMTP access
```

**Verification**:
- `home-manager switch` completes without errors
- `systemctl --user status protonmail-bridge` shows active/running
- `ss -tlnp | grep -E '1143|1025'` shows both ports listening
- `mbsync -V logos-inbox` successfully syncs (optional, confirms end-to-end)

---

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager switch` applies without errors
- [ ] Service is enabled: `systemctl --user is-enabled protonmail-bridge`
- [ ] Service is running: `systemctl --user is-active protonmail-bridge`
- [ ] IMAP port listening: `ss -tlnp | grep 1143`
- [ ] SMTP port listening: `ss -tlnp | grep 1025`

## Artifacts & Outputs

- Modified `home.nix` with declarative service configuration
- Implementation summary at `specs/24_protonmail_bridge_nixos_config/summaries/`

## Rollback/Contingency

If the service fails to start or causes issues:

1. Revert changes: `git checkout home.nix`
2. Apply reverted config: `home-manager switch`
3. If manual service needed, use the alternative from research report:
```nix
systemd.user.services.protonmail-bridge = {
  Unit = {
    Description = "ProtonMail Bridge - Local IMAP/SMTP server";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive --log-level info";
    Restart = "on-failure";
    RestartSec = 10;
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

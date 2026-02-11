# Research Report: Task #24

**Task**: 24 - protonmail_bridge_nixos_config
**Started**: 2026-02-10T12:00:00Z
**Completed**: 2026-02-10T12:15:00Z
**Effort**: Low
**Dependencies**: None
**Sources/Inputs**: home.nix, flake.nix, home-manager module documentation, existing research
**Artifacts**: specs/24_protonmail_bridge_nixos_config/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- ProtonMail Bridge v3.21.2 is already installed and configured in home.nix
- Official home-manager module `services.protonmail-bridge` is available and recommended
- Existing systemd patterns in home.nix (ydotool, gmail-oauth2-refresh) provide template
- Implementation requires adding ~4 lines to home.nix using official module

## Context & Scope

This research builds on prior work (research at `~/.config/nvim/specs/052_protonmail_bridge_systemd_autostart/`) and focuses specifically on NixOS/home-manager integration for auto-starting ProtonMail Bridge as a systemd user service.

**In Scope**:
- Systemd user service configuration via home-manager
- Integration with existing home.nix patterns
- Comparison of manual vs official module approach

**Out of Scope**:
- Neovim-specific tasks (handled elsewhere)
- Initial ProtonMail Bridge setup (already completed)
- Email client configuration (Himalaya/mbsync already configured)

## Findings

### 1. Current System State

**Package Installation**:
- Package: `protonmail-bridge` in home.packages (line 185 of home.nix)
- Binary: `/home/benjamin/.nix-profile/bin/protonmail-bridge`
- Version: 3.21.2

**Configuration**:
- Config directory: `~/.config/protonmail/bridge-v3/`
- Vault encrypted: `vault.enc` present
- Keychain: `keychain.json` configured
- IMAP sync state: `imap-sync/` directory exists

**Dependent Services**:
- mbsync (logos account): connects to 127.0.0.1:1143
- Himalaya (logos SMTP): connects to 127.0.0.1:1025
- Password stored in GNOME keyring

### 2. Existing Systemd User Services Pattern

Current home.nix defines two systemd user services that provide implementation patterns:

```nix
# Pattern 1: Simple daemon (ydotool)
systemd.user.services.ydotool = {
  Unit = {
    Description = "ydotool daemon for input automation";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = "${pkgs.ydotool}/bin/ydotoold";
    Restart = "on-failure";
    Environment = "PATH=/run/current-system/sw/bin";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};

# Pattern 2: Oneshot with timer (gmail-oauth2-refresh)
systemd.user.services.gmail-oauth2-refresh = {
  Unit = {
    Description = "Refresh Gmail OAuth2 tokens";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "oneshot";
    ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
    Environment = [...];
  };
};
```

### 3. Official Home-Manager Module

Home-manager includes an official `services.protonmail-bridge` module:

**Source**: [home-manager/modules/services/protonmail-bridge.nix](https://github.com/nix-community/home-manager/blob/master/modules/services/protonmail-bridge.nix)

**Available Options**:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable ProtonMail Bridge service |
| `package` | package | pkgs.protonmail-bridge | Package to use |
| `extraPackages` | list of packages | [] | Additional packages in service PATH |
| `logLevel` | enum (null/"panic"/"fatal"/"error"/"warn"/"info"/"debug") | null | Log verbosity |

**Module Behavior**:
- Adds package to `home.packages` automatically
- Creates systemd user service with `--noninteractive` flag
- Starts after `graphical-session.target`
- Sets `WantedBy = [ "graphical-session.target" ]`
- Restart policy: `always`

**Module Implementation** (for reference):
```nix
systemd.user.services.protonmail-bridge = {
  Unit = {
    Description = "ProtonMail Bridge";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Environment = lib.mkIf (cfg.extraPackages != [ ])
      [ "PATH=${lib.makeBinPath cfg.extraPackages}" ];
    ExecStart = "${lib.getExe cfg.package} --noninteractive"
      + lib.optionalString (cfg.logLevel != null) " --log-level ${cfg.logLevel}";
    Restart = "always";
  };
  Install = {
    WantedBy = [ "graphical-session.target" ];
  };
};
```

### 4. Comparison: Official Module vs Manual Configuration

| Aspect | Official Module | Manual Service |
|--------|-----------------|----------------|
| Lines of code | 3-4 | 12-15 |
| Maintenance | Home-manager team | User |
| Package addition | Automatic | Must keep separate |
| Configuration | Limited options | Full control |
| WantedBy | graphical-session.target | Configurable |
| Restart policy | always | Configurable |
| RestartSec | Not configurable | Configurable |

**Recommendation**: Use official module for simplicity and maintainability.

### 5. Integration Considerations

**Duplicate Package Declaration**:
The official module automatically adds protonmail-bridge to `home.packages`. Since it's already declared in home.nix (line 185), one of these should be removed to avoid redundancy:
- Option A: Remove from home.packages, let module add it
- Option B: Use `package` option to point to existing declaration

**Service Dependencies**:
- Bridge must start before mbsync/himalaya can connect
- After `graphical-session.target` ensures GNOME keyring is available
- No explicit socket activation support (mbsync handles connection failures gracefully)

**Verification Path**:
```bash
# After implementation
home-manager switch  # or sudo nixos-rebuild switch
systemctl --user status protonmail-bridge
ss -tlnp | grep -E '1143|1025'
journalctl --user -u protonmail-bridge -f
```

## Recommendations

### Primary Recommendation: Use Official Home-Manager Module

Add to `~/.dotfiles/home.nix`:

```nix
# ProtonMail Bridge systemd service for local IMAP/SMTP
services.protonmail-bridge = {
  enable = true;
  logLevel = "info";
};
```

**Also**: Remove `protonmail-bridge` from `home.packages` (line 185) since the module adds it automatically.

### Alternative: Manual Service Definition

If more control is needed:

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

This keeps `protonmail-bridge` in home.packages and provides configurable `RestartSec`.

## Decisions

1. **Module choice**: Official home-manager module (simplest, maintained upstream)
2. **Log level**: `info` (provides useful operational visibility without verbosity)
3. **Package management**: Let module handle package addition (remove from home.packages)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Module not available in current home-manager | Low | Medium | Using master branch; fallback to manual config |
| Service fails on boot | Low | Low | Credentials already configured; test with `systemctl --user start` |
| Port conflict | Very Low | Medium | Fixed ports; no other services use 1143/1025 |

## Implementation Summary

**Files to Modify**: `~/.dotfiles/home.nix`

**Changes**:
1. Add `services.protonmail-bridge.enable = true;` and `services.protonmail-bridge.logLevel = "info";`
2. Remove `protonmail-bridge` from home.packages (line 185)

**Verification**:
```bash
home-manager switch
systemctl --user status protonmail-bridge
mbsync -V logos-inbox
```

## Appendix

### Search Queries Used
- "home-manager services.protonmail-bridge module NixOS 2025 2026"
- `nix search nixpkgs#protonmail-bridge`

### References
- [Home-Manager protonmail-bridge module](https://github.com/nix-community/home-manager/blob/master/modules/services/protonmail-bridge.nix)
- [NixOS Discourse: Writing a service for protonmail-bridge](https://discourse.nixos.org/t/writing-a-service-for-protonmail-bridge/10623)
- [Home-Manager Issue #3019: protonmail-bridge](https://github.com/nix-community/home-manager/issues/3019)
- Existing research: `~/.config/nvim/specs/052_protonmail_bridge_systemd_autostart/reports/research-001.md`

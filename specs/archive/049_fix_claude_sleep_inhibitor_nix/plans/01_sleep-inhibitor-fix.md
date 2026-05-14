# Implementation Plan: Fix claude-sleep-inhibitor Nix derivation

- **Task**: 49 - fix_claude_sleep_inhibitor_nix
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md
- **Artifacts**: plans/01_sleep-inhibitor-fix.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: true

## Overview

The `claude-sleep-inhibitor` systemd user service in `home.nix` passes a bare `sh` to `systemd-inhibit`, which fails to resolve in the Nix environment because `/bin/sh` is not on PATH in systemd service contexts. The inner `sleep` command has the same issue. This causes the service to fail immediately each cycle. The fix is a single-file, three-line change: replace bare `sh` with `${pkgs.bash}/bin/bash`, replace bare `sleep` inside the `-c` string with `${pkgs.coreutils}/bin/sleep`, and add a `|| sleep 5` failure guard after the `systemd-inhibit` invocation.

### Research Integration

Research confirmed the bug is on line 813 of `home.nix`. Three bare command references need Nix store paths: `sh` (passed to `systemd-inhibit`), `sleep 30` (inside the `-c` subshell), and a failure guard is needed to prevent tight loops if `systemd-inhibit` itself fails. The rest of the file already follows the `${pkgs.X}/bin/Y` pattern consistently.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace bare `sh` with fully-qualified `${pkgs.bash}/bin/bash` Nix store path
- Replace bare `sleep` inside the `-c` string with `${pkgs.coreutils}/bin/sleep`
- Add `|| sleep 5` failure guard to prevent rapid retry on `systemd-inhibit` failure
- Verify the fix builds successfully with `home-manager build`

**Non-Goals**:
- Redesigning the sleep-inhibitor architecture (e.g., background PID approach)
- Fixing the pre-existing `pgrep -f 'claude'` self-matching issue
- Adding logging or monitoring to the service

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nix expression syntax error in modified line | M | L | Verify with `home-manager build --flake .#benjamin` |
| Shell quoting issues with nested `${pkgs...}` inside single-quoted `-c` string | M | L | Nix interpolation happens at build time before shell sees the string; confirmed by research |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix bare command references and add failure guard [COMPLETED]

**Goal**: Replace all bare command references with Nix store paths and add error handling

**Tasks**:
- [ ] Replace `sh -c` with `${pkgs.bash}/bin/bash -c` on the `systemd-inhibit` line (home.nix ~line 813)
- [ ] Replace `sleep 30` inside the `-c` string with `${pkgs.coreutils}/bin/sleep 30`
- [ ] Add `|| sleep 5` after the `systemd-inhibit` invocation closing quote as a failure guard
- [ ] Run `home-manager build --flake /home/benjamin/.dotfiles#benjamin` to verify the build succeeds
- [ ] Inspect the generated script in the Nix store to confirm all paths are fully qualified

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `home.nix` - Replace line 813 (bare `sh` and `sleep`) and add failure guard line

**Verification**:
- `home-manager build --flake .#benjamin` completes without errors
- Generated script contains `/nix/store/...-bash-.../bin/bash` instead of bare `sh`
- Generated script contains `/nix/store/...-coreutils-.../bin/sleep` inside the `-c` string
- `|| sleep 5` guard is present after the `systemd-inhibit` invocation

## Testing & Validation

- [ ] `home-manager build --flake /home/benjamin/.dotfiles#benjamin` succeeds
- [ ] Inspect generated service file: `grep -A5 ExecStart` on the `.service` file in the build result
- [ ] Confirm no bare `sh` or `sleep` references remain in the generated script

## Artifacts & Outputs

- Modified `home.nix` with fixed `claude-sleep-inhibitor` service definition
- Successful `home-manager build` output confirming valid configuration

## Rollback/Contingency

Revert the single changed line in `home.nix` via `git checkout home.nix` if the fix introduces any issues. The change is isolated to one service definition and does not affect any other Home Manager configuration.

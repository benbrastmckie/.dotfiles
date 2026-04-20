# Implementation Summary: Fix claude-sleep-inhibitor Nix derivation

- **Task**: 49 - fix_claude_sleep_inhibitor_nix
- **Status**: [COMPLETED]
- **Started**: 2026-04-19T00:00:00Z
- **Completed**: 2026-04-19T00:10:00Z
- **Effort**: 10 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_sleep-inhibitor-fix.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

The `claude-sleep-inhibitor` systemd user service was failing in a tight loop because it used bare `sh` and `sleep` commands that are not on PATH in Nix-managed systemd service contexts. This fix replaces all bare command references with fully-qualified Nix store paths and adds a failure guard.

## What Changed

- Replaced bare `sh` with `${pkgs.bash}/bin/bash` in the `systemd-inhibit` invocation (home.nix line 813)
- Replaced bare `sleep 30` inside the `-c` subshell string with `${pkgs.coreutils}/bin/sleep 30`
- Replaced bare `sleep 30` in the outer loop with `${pkgs.coreutils}/bin/sleep 30`
- Added `|| ${pkgs.coreutils}/bin/sleep 5` failure guard after the `systemd-inhibit` invocation to prevent tight retry loops if systemd-inhibit itself fails

## Decisions

- Used `${pkgs.bash}/bin/bash` rather than `${pkgs.bashInteractive}/bin/bash` since the subshell only needs non-interactive execution
- Set failure guard sleep to 5 seconds (shorter than the 30-second main loop) to allow reasonably quick recovery while preventing tight loops

## Impacts

- The `claude-sleep-inhibitor` service will now correctly inhibit system sleep while Claude Code is running
- No other services or configurations are affected by this change
- The service will gracefully handle `systemd-inhibit` failures by sleeping 5 seconds before retrying

## Follow-ups

- None required

## References

- `home.nix` lines 806-820 (modified service definition)
- `specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md` (research report)
- `specs/049_fix_claude_sleep_inhibitor_nix/plans/01_sleep-inhibitor-fix.md` (implementation plan)

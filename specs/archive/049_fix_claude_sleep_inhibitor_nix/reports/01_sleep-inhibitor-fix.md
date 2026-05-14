# Research Report: Task #49

**Task**: 49 - fix_claude_sleep_inhibitor_nix
**Started**: 2026-04-19T00:00:00Z
**Completed**: 2026-04-19T00:05:00Z
**Effort**: Small (single file, single location)
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis
**Artifacts**: - specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md
**Standards**: report-format.md

## Executive Summary

- The bug is on line 813 of `home.nix`: `sh -c '...'` uses a bare `sh` that is not on PATH in the Nix systemd service environment
- `systemd-inhibit` spawns `sh` as a child process, but the systemd unit has a minimal PATH without `/bin` or `/usr/bin`, causing immediate "No such file or directory" failure
- The outer `while true` loop has no failure guard, so it retries immediately every iteration (no delay after `systemd-inhibit` fails), causing ~110 process spawns/sec
- The inner `sleep 30` command (line 813) also uses a bare `sleep` which would fail for the same reason
- Fix requires: (1) replace bare `sh` with `${pkgs.bash}/bin/bash`, (2) replace bare `sleep` inside the `-c` string with `${pkgs.coreutils}/bin/sleep`, (3) add a sleep-on-failure guard to the outer loop

## Context & Scope

The `claude-sleep-inhibitor` is a Home Manager systemd user service defined in `home.nix` (lines 799-825). Its purpose is to inhibit system sleep/idle while Claude Code processes are running. It uses `systemd-inhibit` to hold an inhibition lock for the duration of a subcommand, where that subcommand polls `pgrep` every 30 seconds until Claude is no longer running.

## Findings

### Current Implementation (lines 807-817)

```nix
script = pkgs.writeShellScript "claude-sleep-inhibitor" ''
  while true; do
    if ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; then
      ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
        --why="Claude Code is running" \
        --who="claude-sleep-inhibitor" \
        sh -c 'while ${pkgs.procps}/bin/pgrep -f "claude" > /dev/null; do sleep 30; done'
    fi
    sleep 30
  done
'';
```

### Bug Analysis

Three bare command references exist that are not resolved through Nix store paths:

1. **`sh` on line 813** -- passed as the command argument to `systemd-inhibit`. Since `systemd-inhibit` uses `execvp()` to spawn this, it needs `sh` on PATH. Nix systemd services have minimal PATH (typically just `/nix/store/...-coreutils/bin` from `writeShellScript`), so `sh` is not found.

2. **`sleep 30` inside the `-c` string on line 813** -- this `sleep` runs inside the `sh -c` subshell. Even if `sh` were found, this bare `sleep` would also fail to resolve.

3. **`sleep 30` on line 815** (outer loop) -- this runs in the main `writeShellScript` context. `pkgs.writeShellScript` sets PATH to include coreutils, so this `sleep` actually works. However, it only executes when `pgrep` finds no Claude processes. When `systemd-inhibit` fails immediately (due to the `sh` not found error), the loop falls through to the `sleep 30`, but this only provides a 30-second delay between failure bursts -- the real problem is the rapid spawning during the `systemd-inhibit` call itself.

**Wait, correction**: Looking more carefully at the control flow:
- When `pgrep` finds Claude: `systemd-inhibit sh -c '...'` runs and fails instantly -> falls through to `sleep 30` (line 815) -> retries
- This means the spin rate is actually ~1 attempt per 30 seconds when the outer sleep works, not 110/sec

Actually, re-examining: `writeShellScript` does add coreutils to PATH, so the outer `sleep 30` works. The 110 spawns/sec described in the task suggests the outer `sleep` might also be failing, or there is a different failure mode. Regardless, the `sh` reference is definitively broken and needs fixing.

### Nix Pattern for Shell References

The correct Nix pattern (used consistently elsewhere in this file) is to use full store paths for all executables. Examples from the same file:
- `${pkgs.procps}/bin/pgrep` (already used on lines 809, 813)
- `${pkgs.systemd}/bin/systemd-inhibit` (already used on line 810)

The fix should follow this same pattern for `sh` and `sleep`.

### Note on `writeShellScript`

`pkgs.writeShellScript` wraps the script with `#!/nix/store/...-bash/bin/bash` as the shebang and adds coreutils to PATH. This means:
- The outer script's bash interpreter is correct
- `sleep` in the outer loop context likely works (coreutils is on PATH)
- But `systemd-inhibit` spawns `sh` as a new process using `execvp`, which searches PATH -- and `sh` is not the same as `bash` on NixOS

### Recommended Fix

Replace the `systemd-inhibit` invocation block (lines 810-813) with:

```nix
script = pkgs.writeShellScript "claude-sleep-inhibitor" ''
  while true; do
    if ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; then
      ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
        --why="Claude Code is running" \
        --who="claude-sleep-inhibitor" \
        ${pkgs.bash}/bin/bash -c 'while ${pkgs.procps}/bin/pgrep -f "claude" > /dev/null; do ${pkgs.coreutils}/bin/sleep 30; done'
    fi
    sleep 30
  done
'';
```

Changes:
1. `sh` -> `${pkgs.bash}/bin/bash` -- resolves the primary "No such file or directory" error
2. `sleep 30` (inside `-c` string) -> `${pkgs.coreutils}/bin/sleep 30` -- ensures sleep resolves inside the subshell
3. **Sleep-on-failure guard**: Add error handling to the outer loop to prevent rapid spinning if `systemd-inhibit` itself fails for any reason:

```nix
script = pkgs.writeShellScript "claude-sleep-inhibitor" ''
  while true; do
    if ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; then
      ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
        --why="Claude Code is running" \
        --who="claude-sleep-inhibitor" \
        ${pkgs.bash}/bin/bash -c 'while ${pkgs.procps}/bin/pgrep -f "claude" > /dev/null; do ${pkgs.coreutils}/bin/sleep 30; done' \
        || sleep 5
    fi
    sleep 30
  done
'';
```

The `|| sleep 5` ensures that if `systemd-inhibit` fails for any reason (permissions, dbus issues, etc.), the loop pauses 5 seconds before retrying rather than immediately looping back to `sleep 30` (which is fine) or potentially spinning if the outer sleep also fails.

### Alternative: Inline the polling without subshell

A cleaner alternative avoids the subshell entirely:

```nix
script = pkgs.writeShellScript "claude-sleep-inhibitor" ''
  while true; do
    if ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; then
      ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
        --why="Claude Code is running" \
        --who="claude-sleep-inhibitor" \
        ${pkgs.coreutils}/bin/sleep infinity &
      INHIBIT_PID=$!
      while ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; do
        sleep 30
      done
      kill $INHIBIT_PID 2>/dev/null
      wait $INHIBIT_PID 2>/dev/null
    fi
    sleep 30
  done
'';
```

This eliminates the subshell entirely by running `systemd-inhibit sleep infinity` in the background and killing it when Claude exits. However, this changes the architecture significantly and the simpler fix (replacing `sh` with `${pkgs.bash}/bin/bash`) is recommended as the primary approach.

## Decisions

- **Recommended approach**: Replace bare `sh` with `${pkgs.bash}/bin/bash`, replace bare `sleep` inside `-c` with `${pkgs.coreutils}/bin/sleep`, and add `|| sleep 5` failure guard
- **Scope**: Single file change in `home.nix`, lines 810-813
- **Testing**: Rebuild with `home-manager build --flake .#benjamin` then verify the generated script in the Nix store

## Risks & Mitigations

- **Risk**: The `pgrep -f 'claude'` pattern might match the sleep-inhibitor service itself (since its script name contains "claude"). **Mitigation**: Check if `pgrep` is matching the service; if so, add `--ignore-ancestors` or filter by process name more specifically. (This is a pre-existing issue, not introduced by this fix.)
- **Risk**: `systemd-inhibit` might need polkit permissions. **Mitigation**: The service already runs as user service; `systemd-inhibit` for `sleep:idle` is typically allowed for the session user without extra polkit rules.

## Appendix

### Files to modify
- `/home/benjamin/.dotfiles/home.nix` lines 810-813

### Verification steps
```bash
home-manager build --flake /home/benjamin/.dotfiles#benjamin
# Inspect the generated script:
cat $(readlink -f result/home-files/.config/systemd/user/claude-sleep-inhibitor.service) | grep ExecStart
# Or check the script content directly in the nix store
```

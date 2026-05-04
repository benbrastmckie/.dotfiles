# Research Report: Sleep Inhibition for Claude Code and Opencode

## Metadata
- **Task**: 52 - sleep_inhibition_claude_opencode
- **Started**: 2026-05-04T12:49:00Z
- **Completed**: 2026-05-04T13:14:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: Task 49 (completed), Task 50 (pending - addresses known pgrep bug)
- **Sources/Inputs**:
  - `specs/TODO.md` (Task 52 description)
  - `specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md`
  - `home.nix` (disabled inhibitor service, process definitions, Gnome settings)
  - `modules/opencode.nix` (Opencode package definition)
  - `man systemd-inhibit`
  - NixOS Power Management Wiki
- **Artifacts**:
  - `specs/052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md`
- **Standards**: report-format.md, tasks.md

## Executive Summary
- A `claude-sleep-inhibitor` systemd user service exists in `home.nix` but is currently disabled.
- Task 49 already fixed bare-path Nix derivation bugs, but a `pgrep` self-match bug identified in Task 50 must be resolved before re-enabling the service.
- The inhibitor should use `systemd-inhibit --what=sleep:idle` to block sleep while respecting GNOME dimming settings (`idle-dim=true`, `idle-delay=300`).
- Detection logic must be expanded to include both `claude` and `opencode` processes.
- Recommend consolidating Task 50 and Task 52 fixes into a single implementation phase.

## Context & Scope

Scope is to create a feature that inhibits computer sleep while Claude Code or Opencode are actively running, while still allowing screen dimming per GNOME settings. The task is specifically a Nix configuration task. A future `<leader>ai` Neovim mapping is a downstream dependent but out of scope for the Nix module itself.

## Findings

### 1. Existing Infrastructure (Task 49)
- **Status**: A `claude-sleep-inhibitor` systemd user service was previously implemented in `home.nix` (lines approx 817-844), but is currently **disabled via comments**.
- **Rationale for disabling**: Task 49 fixed a Nix derivation bug where bare `sh` and `sleep` commands failed inside the systemd unit environment. Task 50 (pending) identified a more critical bug where `pgrep -f 'claude'` matches the inhibitor script itself, the `claude-memory-tracker`, and the `earlyoom` `--prefer` regex, causing the inhibitor to hold the lock permanently.

### 2. System Context
- **Desktop**: Wayland-based (Niri compositor).
- **Idle/Power**: Gnome settings are configured in `home.nix` (`idle-delay=300`, `idle-dim=true`).
- **Inhibitor Mechanism**: `systemd-inhibit --what=sleep:idle` is the standard, effective mechanism for blocking sleep while allowing screen dimming/idle in a systemd session.

### 3. Process Detection Strategy
- **Claude Code**: Runs as `claude` (Node.js binary).
- **Opencode**: Runs as `opencode` (Rust binary, via `pkgs.opencode` in `modules/opencode.nix`).
- **Critical Bug (Task 50)**: A naive `pgrep -f 'claude'` is insufficient and self-matching.
- **Solution**: The pgrep/pidof logic must be constrained. Options:
  1. Use `pgrep -u $USER -x claude` for exact match on the binary name (if the binary name is exactly `claude`).
  2. Use `pgrep -f` but pipe through `grep -v` to exclude the inhibitor's own PID or script name.
  3. Use `pgrep -u $USER` to restrict search to the current user, preventing matches on system-level configs.

### 4. Implementation Path
- **Service Type**: A `systemd.user.services` unit in `home.nix` is the most idiomatic and robust approach for NixOS/Nix.
- **Logic**:
  - Poll for `claude` or `opencode` PIDs every 30 seconds.
  - If found, launch `systemd-inhibit --what=sleep:idle --why="AI agent active" COMMAND`.
  - `COMMAND` should be a long-running poll (e.g., a bash loop that sleeps while the target processes exist).
  - Release inhibition automatically when the `COMMAND` exits.
  - **Fixing Task 50**: The script must use `pgrep` flags that do not match the script itself.

### 5. Risks
- **Task 50 Regression**: If the `pgrep` pattern is not fixed, the system will never sleep once the service is enabled.
- **Scope Creep**: The Neovim `<leader>ai` mapping should be handled in a separate Neovim configuration task, not this Nix configuration module. However, the Nix module should provide an easy on/off switch (e.g., a systemd service that can be started/stopped or a Nix option) for the mapping to toggle.

## Decisions
- Recommends **re-enabling** the inhibitor service in `home.nix`.
- Recommends **fixing the `pgrep` self-match bug** (Task 50) as a prerequisite or as part of the implementation.
- Recommends expanding the detection logic to include `opencode`.
- Recommends keeping the `systemd-inhibit` approach (using `sleep:idle`) as it respects GNOME dimming while blocking sleep.

## Recommendations
1. **Consolidate Fix**: Implement Task 50 (fix pgrep) and Task 52 (add opencode) in the same implementation phase to avoid re-enabling a broken service.
2. **Service Definition**: Use a robust `writeShellScript` that uses exact store paths (as fixed in Task 49) and a non-self-matching `pgrep`.
3. **Example Script Logic**:
   - Use `pgrep -u "$(id - u)" -x claude` or `pgrep -u "$(id - u)" -x opencode`.
   - Alternatively, use `pgrep -f` and filter out the script name/pid.
4. **Integration**: Enable the service in `home.nix`. A future Neovim mapping can toggle the service via `systemctl --user start/stop`.

## Context Extension Recommendations
- **Topic**: Power Management / Sleep Inhibition
- **Gap**: There is no centralized documentation for how sleep inhibition is handled in this dotfiles repo.
- **Recommendation**: Add a note to `NOTES.md` or a new `docs/power-management.md` explaining the `claude-sleep-inhibitor` service and why it exists.

## Appendix
- **References**:
  - `home.nix`: Lines ~817-844 (disabled service).
  - `specs/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md`
  - `man systemd-inhibit`
  - `modules/opencode.nix`
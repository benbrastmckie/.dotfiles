---
task: 52
name: "sleep_inhibition_claude_opencode"
artifact_number: 01
created: "2026-05-14T12:00:00Z"
session: "sess_1778791443_841b84"
status: "NOT STARTED"
---

# Sleep Inhibition for Claude Code and Opencode

## Summary

This plan re-enables and fixes the disabled `claude-sleep-inhibitor` systemd user service in `home.nix`. The service will use robust process detection to inhibit system sleep while Claude Code or Opencode are actively running, while respecting GNOME dimming settings via `systemd-inhibit --what=sleep:idle`. The fix consolidates the pending Task 50 pgrep self-match bug fix with the Task 52 requirement to detect both `claude` and `opencode` processes.

## Context

### Problem

A `claude-sleep-inhibitor` systemd user service exists in `home.nix` (lines ~818-845) but is currently disabled via comments. It was disabled because:

1. **Task 49**: Fixed bare-path Nix derivation bugs (using `${pkgs.procps}/bin/pgrep` instead of bare `pgrep`).
2. **Task 50 (pending)**: Identified a critical `pgrep -f 'claude'` self-match bug where the inhibitor script itself, the `claude-memory-tracker` service, and the `earlyoom --prefer` regex all match the pattern, causing sleep to be permanently blocked.

### System Context

- **Desktop**: Wayland-based (Niri compositor).
- **Idle/Power**: GNOME settings in `home.nix` configure `idle-delay=300` and `idle-dim=true`. These must be respected.
- **Inhibitor Mechanism**: `systemd-inhibit --what=sleep:idle` blocks sleep while allowing screen dimming and idle notifications.
- **Process Names**: Claude Code runs as `claude` (Node.js binary). Opencode runs as `opencode` (Rust binary, via `pkgs.opencode` in `modules/opencode.nix`).

### Research Integration

Research report `specs/052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md` recommends:
- Consolidating Task 50 (pgrep fix) and Task 52 (opencode detection) into a single implementation phase.
- Using `pgrep -u "$(id - u)" -x claude` for exact process name matching restricted to the current user.
- Polling every 30 seconds and launching `systemd-inhibit` when target processes are found.

### Constraints

- The Neovim `<leader>ai` mapping is out of scope for this Nix module, but the service should be easily toggleable via `systemctl --user start/stop` for future integration.
- All binaries must use Nix store paths (Task 49 fix must be preserved).
- Changes must not affect the existing `claude-memory-tracker` service.

## Goals

- [ ] Fix the `pgrep` self-match bug by using exact process name matching (`pgrep -x`) restricted to the current user.
- [ ] Expand process detection to include both `claude` and `opencode` binaries.
- [ ] Re-enable the systemd user service in `home.nix` with the corrected logic.
- [ ] Verify the service builds successfully and correctly inhibits sleep when target processes run.
- [ ] Verify inhibition releases automatically when all target processes exit.
- [ ] Document the toggle mechanism for future Neovim integration.

## Phases

### Phase 1: Fix Process Detection Logic

- **Status**: [NOT STARTED]
- **Estimated Effort**: 1h
- **Depends On**: None
- **Artifacts**: `home.nix` (lines ~818-845, script rewrite)

**Objective**: Rewrite the inhibitor script to eliminate pgrep self-matches and detect both `claude` and `opencode` processes.

**Steps**:
1. Locate the commented `claude-sleep-inhibitor` service in `home.nix` (lines ~816-845).
2. Rewrite the `writeShellScript` block with the following logic:
   - Replace `pgrep -f 'claude'` with `pgrep -u "$(id - u)" -x claude` for exact binary name matching restricted to the current user.
   - Add detection for `opencode` using `pgrep -u "$(id - u)" -x opencode`.
   - The outer poll loop checks if either process is running.
   - The inner `systemd-inhibit` loop sleeps while either process is still running, exiting (and releasing inhibition) only when both have exited.
   - Keep Task 49 fixes: use `${pkgs.procps}`, `${pkgs.systemd}`, `${pkgs.bash}`, `${pkgs.coreutils}` for all binaries.
3. Update the service `Description` to mention both Claude Code and Opencode.

**Verification**:
- Review the rewritten script to confirm:
  - No use of `pgrep -f` with broad patterns.
  - Both `claude` and `opencode` are checked with `-x` (exact match) and `-u "$(id - u)"` (current user only).
  - All external binaries reference Nix store paths.

**Risks**:
- `pgrep -x` might fail if the running binary name differs from expectations (e.g., wrapper scripts). Mitigation: Test against actual running processes in Phase 3; fallback to `pidof` if needed.
- The `id - u` command might not be available in the script environment. Mitigation: Use `$UID` bash variable instead, which is always available in bash.

---

### Phase 2: Update and Enable Service Definition

- **Status**: [NOT STARTED]
- **Estimated Effort**: 1h
- **Depends On**: Phase 1
- **Artifacts**: `home.nix` (uncomment/rewrite service block)

**Objective**: Replace the commented service definition with the working version and ensure it is enabled.

**Steps**:
1. Uncomment the `systemd.user.services.claude-sleep-inhibitor` block (or replace it entirely with the new definition).
2. Ensure the `Install.WantedBy = [ "default.target" ];` is present so the service starts automatically on login.
3. Verify the `Restart = "always";` and `RestartSec = 10;` settings are preserved for resilience.
4. Run `nix flake check` to validate Nix syntax.
5. Run `home-manager build --flake .#benjamin` (or `nixos-rebuild build --flake .#<hostname>` if testing via NixOS) to confirm the configuration evaluates without errors.

**Verification**:
- `nix flake check` exits with code 0.
- `home-manager build --flake .#benjamin` completes successfully.
- The generated systemd unit file contains the corrected script.

**Risks**:
- Syntax error in the Nix script block. Mitigation: Build immediately after editing; Nix will report exact line numbers.
- Accidental modification of adjacent services (`claude-memory-tracker`). Mitigation: Review the diff carefully before building.

---

### Phase 3: Build Verification and Manual Testing

- **Status**: [NOT STARTED]
- **Estimated Effort**: 1h
- **Depends On**: Phase 2
- **Artifacts**: Runtime verification only

**Objective**: Confirm the service works correctly in practice by observing sleep inhibition when target processes run and release when they exit.

**Steps**:
1. Apply the Home Manager configuration (e.g., `home-manager switch --flake .#benjamin` or rebuild NixOS).
2. Start the service manually: `systemctl --user start claude-sleep-inhibitor`.
3. Check service status: `systemctl --user status claude-sleep-inhibitor`.
4. Verify no inhibitor is active initially: `systemd-inhibit --list` should not show a `claude-sleep-inhibitor` entry.
5. Start `claude` (Claude Code) in a terminal.
6. Within 30 seconds, run `systemd-inhibit --list` and confirm an inhibitor entry appears with `What: sleep:idle` and `Why: "AI agent active"` (or the chosen description).
7. Exit `claude` and wait 30 seconds. Confirm the inhibitor disappears from `systemd-inhibit --list`.
8. Repeat steps 5-7 with `opencode` running.
9. Test with both `claude` and `opencode` running simultaneously. Exit one, confirm inhibition remains. Exit the second, confirm inhibition releases.
10. Stop the service: `systemctl --user stop claude-sleep-inhibitor`.

**Verification**:
- Inhibitor appears within 30 seconds of starting `claude` or `opencode`.
- Inhibitor disappears within 30 seconds of the last target process exiting.
- `systemctl --user status claude-sleep-inhibitor` shows no errors.
- Screen dimming still occurs per GNOME settings (verify visually or check `gsettings get org.gnome.settings-daemon.plugins.power idle-dim`).

**Risks**:
- `systemd-inhibit` requires a valid systemd user session. Mitigation: Ensure the user session is active (`systemctl --user status` works).
- The 30-second poll delay makes testing slow. Mitigation: Temporarily reduce the sleep interval to 5 seconds during testing, then restore to 30.

---

### Phase 4: Add Toggle Interface and Documentation

- **Status**: [NOT STARTED]
- **Estimated Effort**: 0.5h
- **Depends On**: Phase 3
- **Artifacts**: `home.nix` (optional comments), `docs/power-management.md` or `NOTES.md`

**Objective**: Provide clear documentation on how the service works and how it can be toggled for future Neovim integration.

**Steps**:
1. Add a comment block above the service definition in `home.nix` explaining:
   - What the service does.
   - Why `pgrep -x` is used (self-match prevention).
   - That it detects both `claude` and `opencode`.
   - How to toggle it manually (`systemctl --user start/stop claude-sleep-inhibitor`).
2. Create or update `docs/power-management.md` (or add to `NOTES.md` if docs/ does not exist) with a brief section on the `claude-sleep-inhibitor` service.
3. Document the expected behavior: sleep is blocked, but screen dimming is allowed.

**Verification**:
- A new user can read the comment in `home.nix` and understand the service behavior.
- The toggle commands (`systemctl --user start claude-sleep-inhibitor`, `systemctl --user stop claude-sleep-inhibitor`) are documented.

**Risks**:
- `docs/` directory may not exist. Mitigation: Use `NOTES.md` at repository root or create `docs/power-management.md`.

## Rollback Plan

| Phase | Rollback Action | Time to Revert |
|-------|----------------|----------------|
| 1 | Re-comment the service block or restore from git | 2 min |
| 2 | Re-comment the service block in `home.nix` and rebuild | 5 min |
| 3 | Stop the service: `systemctl --user stop claude-sleep-inhibitor`; re-comment and rebuild | 2 min |
| 4 | Delete added documentation/comments | 2 min |

## Timeline

| Phase | Description | Est. Duration | Cumulative |
|-------|-------------|---------------|------------|
| 1 | Fix process detection logic | 1h | 1h |
| 2 | Update and enable service | 1h | 2h |
| 3 | Build verification and manual testing | 1h | 3h |
| 4 | Add toggle interface and documentation | 0.5h | 3.5h |

## Success Criteria

- [ ] `nix flake check` and `home-manager build` succeed with the new service enabled.
- [ ] `systemctl --user start claude-sleep-inhibitor` starts without errors.
- [ ] Running `claude` causes `systemd-inhibit --list` to show a `sleep:idle` inhibitor within 30 seconds.
- [ ] Running `opencode` causes `systemd-inhibit --list` to show a `sleep:idle` inhibitor within 30 seconds.
- [ ] Exiting all target processes causes the inhibitor to disappear within 30 seconds.
- [ ] GNOME screen dimming still occurs while the inhibitor is active (i.e., only sleep is blocked, not idle/dim).
- [ ] Toggle commands are documented for future Neovim `<leader>ai` integration.
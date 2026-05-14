# Implementation Plan: Memory Optimization Updates

- **Task**: 44 - Review memory logs and design system optimizations
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/044_review_memory_logs_design_optimizations/reports/02_memory-usage-update.md
- **Artifacts**: specs/044_review_memory_logs_design_optimizations/plans/01_memory-optimization.md (this file)
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/status-markers.md
  - .opencode/rules/artifact-management.md
  - .opencode/rules/tasks.md
- **Type**: markdown

## Overview

Current memory usage has improved to ~51% (down from 80% in March), but OpenCode has emerged as a new significant consumer (~1.7 GB across 3 instances). The existing memory infrastructure (earlyoom, zram, swap, VM tuning) remains robust and requires no changes. This plan implements two minimal, focused system-level updates: extending the claude-memory-tracker to monitor OpenCode processes, and adding OpenCode to the earlyoom prefer list. Both changes fit within the existing NixOS/Home Manager configuration and avoid needless complexity.

## Goals & Non-Goals

- **Goals**:
  - Extend claude-memory-tracker to capture OpenCode process memory usage
  - Add `opencode` to earlyoom's `--prefer` list for consistent OOM policy
  - Validate all memory monitoring services remain operational after changes
  - Document OpenCode instance hygiene as a user practice

- **Non-Goals**:
  - No changes to zram, swap, or VM sysctl parameters (proven effective)
  - No renaming of existing services or log files (avoids migration complexity)
  - No new systemd services or automation beyond the existing tracker
  - No changes to memory-monitor threshold logic (80% warning remains appropriate)

## Risks & Mitigations

- **Risk**: Modifying the pgrep pattern in claude-memory-tracker could match unintended processes or break CSV formatting.
  - **Mitigation**: Test the new pattern with `pgrep -f "(claude|@anthropic|opencode)"` before applying; verify CSV output format is unchanged.
- **Risk**: Adding `opencode` to earlyoom prefer list may cause unwanted kills of the OpenCode Discord bot or server process.
  - **Mitigation**: The prefer list is heuristic, not automatic; earlyoom only acts at 10% free RAM. The Discord bot uses only ~57 MB and is unlikely to be selected. Monitor earlyoom logs after deployment.
- **Risk**: Rebuilding NixOS configuration introduces unrelated changes.
  - **Mitigation**: Use `nixos-rebuild test` first, then `switch` only after validation.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Extend claude-memory-tracker to include OpenCode [NOT STARTED]
- **Goal:** Update the process tracking script in `home.nix` to log OpenCode memory usage alongside Claude.
- **Tasks:**
  - [ ] In `home.nix`, locate the `claude-memory-tracker` script (lines 620–679)
  - [ ] Update the `pgrep` pattern on line 655 from `(claude|@anthropic)` to `(claude|@anthropic|opencode)`
  - [ ] Verify the CSV header and logging loop handle the new process names without format changes
  - [ ] Rebuild the Home Manager configuration to install the updated script
  - [ ] Restart the `claude-memory-tracker` user service
  - [ ] Verify OpenCode PIDs appear in `~/.local/share/memory-monitor/claude.csv`
- **Timing:** 30 minutes
- **Depends on:** none
- **Started:**
- **Completed:**

### Phase 2: Update earlyoom prefer list for OpenCode [NOT STARTED]
- **Goal:** Ensure earlyoom consistently considers OpenCode processes when selecting candidates for termination under memory pressure.
- **Tasks:**
  - [ ] In `configuration.nix`, locate the `services.earlyoom` block (lines 371–380)
  - [ ] Update the `--prefer` argument on line 378 from `^(lean|lake|claude|node|npm)$` to `^(lean|lake|claude|node|npm|opencode)$`
  - [ ] Rebuild the NixOS configuration with `nixos-rebuild test`
  - [ ] Verify earlyoom service is active and the new prefer list is loaded (`systemctl status earlyoom`)
- **Timing:** 30 minutes
- **Depends on:** none
- **Started:**
- **Completed:**

### Phase 3: Validate infrastructure and document hygiene practices [NOT STARTED]
- **Goal:** Confirm all memory management components remain operational and document user-level OpenCode hygiene recommendations.
- **Tasks:**
  - [ ] Run `systemctl --user status memory-monitor claude-memory-tracker` and confirm both are active
  - [ ] Run `systemctl status earlyoom` and confirm it is active with updated arguments
  - [ ] Check `~/.local/share/memory-monitor/claude.csv` contains both `claude` and `opencode` entries
  - [ ] Review `~/.local/share/memory-monitor/system.log` for any anomalies post-restart
  - [ ] Verify `free -h`, `zramctl`, and `swapon --show` output match pre-change baselines
  - [ ] Document OpenCode instance hygiene recommendations in a brief summary:
    - Limit OpenCode headless agents to the minimum needed (currently 2 agents + 1 server)
    - Close unused OpenCode sessions before starting new ones
    - Review whether the OpenCode Discord bot needs to run continuously
- **Timing:** 30 minutes
- **Depends on:** 1, 2
- **Started:**
- **Completed:**

## Testing & Validation

- [ ] `pgrep -f "(claude|@anthropic|opencode)"` returns expected PIDs without false positives
- [ ] `~/.local/share/memory-monitor/claude.csv` contains rows with `opencode` in the `command` column
- [ ] `systemctl status earlyoom` shows the updated `--prefer` regex in the command line
- [ ] No errors in `systemctl --user status memory-monitor` or `claude-memory-tracker` after restart
- [ ] Memory usage and swap statistics remain stable 10 minutes after service restarts
- [ ] `nixos-rebuild test` succeeds without unexpected side effects

## Artifacts & Outputs

- `specs/044_review_memory_logs_design_optimizations/plans/01_memory-optimization.md` (this plan)
- `specs/044_review_memory_logs_design_optimizations/.return-meta.json` (return metadata)
- Updated `home.nix` (claude-memory-tracker pgrep pattern)
- Updated `configuration.nix` (earlyoom prefer list)

## Rollback/Contingency

- If the extended pgrep pattern causes issues (false matches or missing processes), revert `home.nix` to the original `(claude|@anthropic)` pattern and rebuild.
- If earlyoom behaves unexpectedly with `opencode` in the prefer list, revert `configuration.nix` to the original regex and run `nixos-rebuild switch`.
- Both changes are isolated to single lines in their respective files; rollback is a one-line revert with standard NixOS/Home Manager rebuild commands.
- If validation reveals broader issues, abandon further changes and rely on the proven existing infrastructure (zram + swap + VM tuning) which has already handled a 99% memory spike successfully.

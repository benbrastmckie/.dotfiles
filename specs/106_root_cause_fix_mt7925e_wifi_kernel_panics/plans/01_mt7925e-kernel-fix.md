# Implementation Plan: mt7925e WiFi Kernel-Panic Root-Cause Fix (kernel 7.1.3 + panic_on_oops)

- **Task**: 106 - root_cause_fix_mt7925e_wifi_kernel_panics
- **Status**: [NOT STARTED]
- **Effort**: 3 hours (main path; +1.5 hours if the conditional fallback Phase 6 is triggered)
- **Dependencies**: None (builds on task 104 mitigations already in `modules/system/boot.nix`)
- **Research Inputs**: reports/01_mt7925e-panic-upstream-fix.md
- **Artifacts**: plans/01_mt7925e-kernel-fix.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/nix.md
- **Type**: nix

## Overview

Host `hamsa` (Framework 13 AMD, MediaTek MT7925/RZ717) suffers recurring hard kernel panics from
a `sta_poll_list` corruption race in the mt76/mt7925e driver (`mt76_wcid_add_poll`). Research
identified the REAL merged upstream fix — mainline commit `20b126920a25` ("wifi: mt76: add wcid
publish check in mt76_sta_add"), released in stable kernel **7.1.3** — whose commit message
reproduces hamsa's backtrace verbatim. The `nixos-26.05` nixpkgs branch already ships 7.1.3, so
the primary fix is a `nixpkgs` input bump (kernel pulled from the Hydra binary cache, no local
compile), plus a diagnostics correction (`kernel.panic_on_oops = 1`) so any future panic is
actually captured. Scope is limited to `flake.nix`/`flake.lock` and `modules/system/boot.nix`; the
existing `panic=10` safety net is retained, not removed. Definition of done: hamsa builds and runs
kernel >= 7.1.3 with `panic=10` and `panic_on_oops=1` active, config change staged, and system
activation flagged as a user-confirmed step.

### Research Integration

- Primary fix = `nix flake update nixpkgs` -> kernel 7.1.3 from binary cache (report Findings §1, §2, Rec. 1).
- Abort gate: `nix eval` the resolved kernel version and confirm >= 7.1.3 BEFORE any switch; fall
  back to Phase 6 (`boot.kernelPatches`) only if the bump does not deliver 7.1.3 or would regress
  another input (report Rec. 1/2).
- `nixpkgs-unstable` is a separate input (task-104 r-V8 pin at `567a49d`) and is deliberately NOT
  touched — updating only the `nixpkgs` input avoids reintroducing task-61's build break (report §2, Adversarial Analysis).
- Diagnostics: add `boot.kernel.sysctl."kernel.panic_on_oops" = 1;`; the recent panics wrote NO
  pstore records (the earlier "pstore full" reading was wrong — `/sys/fs/pstore` was empty). Keep
  `panic=10` (report §6, Rec. 3).
- Fallback snippet (`boot.kernelPatches`, precomputed hash `sha256-gn0aq/7ruSlBobDribGiSKwh3wJqHhV0aKHb7yYOXxY=`)
  is verified-viable but forces a full local kernel rebuild and MUST be removed once kernel >= 7.1.3 (report §3).
- Note: the report cites the pinned rev as `a50de1b7` (2026-07-04); the live `flake.lock` shows a
  different rev — Phase 1 records the ACTUAL current state rather than assuming the report's rev.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (not provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Deliver running kernel >= 7.1.3 on hamsa via a `nixpkgs`-input bump (binary-cache path).
- Add `kernel.panic_on_oops = 1` so a future panic produces a capturable oops/pstore record.
- Retain the existing `panic=10` auto-reboot safety net.
- Verify build success and kernel version BEFORE switching; leave activation as a user-confirmed step.
- Document the `boot.kernelPatches` cherry-pick as a ready, conditional fallback.

**Non-Goals**:
- Updating `nixpkgs-unstable` or any other flake input (leave the task-104 r-V8 pin intact).
- Running `sudo nixos-rebuild switch` autonomously (activation requires the user / sudo).
- Hardware swap (Intel AX210 / QCNCM865) — terminal fallback only, not in scope.
- Threaded-NAPI toggling or BSSID pinning (research proved these are dead ends / pure downside).
- Deleting the retained Jun-29 pstore dump before upstream hygiene is considered.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bump does not resolve to kernel >= 7.1.3 | H | L | Phase 2 `nix eval` abort gate before any build/switch; divert to Phase 6 fallback |
| Channel bump regresses unrelated packages | M | L | `nixos-rebuild build` gate (Phase 4) before switch; `nixpkgs-unstable` pin untouched; rollback via systemd-boot generations |
| Fix insufficient / different-bug recurrence on 7.1.3 | M | L | `panic_on_oops=1` guarantees next trace is captured; hardware swap remains terminal fallback |
| `boot.kernelPatches` forgotten after later bumps | M | L | Patch fails loudly (loud build error) once kernel >= 7.1.3; snippet comment mandates removal |
| `panic_on_oops=1` reboots on any unrelated oops | L | L | Deterministic reboot + captured trace is preferable to a wedged desktop on this hardware history |
| Activation run without user consent | H | L | Plan flags switch as user-confirmed; implementer builds + stages only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 7 | 5 |

Phases within the same wave can execute in parallel. Phase 6 is a CONDITIONAL off-path fallback:
it is executed only if the Phase 2 abort gate shows kernel < 7.1.3, in which case it substitutes
for the flake-update route and feeds into Phase 4 (blocked by 2, conditional).

### Phase 1: Pre-change verification & snapshot [NOT STARTED]

**Goal**: Record the exact current state so the fix is verifiable and the bump is scoped safely.

**Tasks**:
- [ ] Record running kernel: `uname -r` (expected `7.1.2`).
- [ ] Record current panic sysctls: `cat /proc/sys/kernel/panic` (expect `10`) and `cat /proc/sys/kernel/panic_on_oops` (expect `0`).
- [ ] Record the ACTUAL pinned nixpkgs rev/date: `jq '.nodes.nixpkgs.locked | {rev, lastModified, ref}' flake.lock` (do not assume the report's `a50de1b7` — capture the real value).
- [ ] Evaluate the kernel version at the current pin BEFORE any change: `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version`.
- [ ] Confirm `/sys/fs/pstore` is empty (`ls -la /sys/fs/pstore/`) and note that one Jun-29 dump under `/var/lib/systemd/pstore/` should be retained (no deletion this task).
- [ ] Note the r-V8/`nixpkgs-unstable` constraint from task 104: the bump must touch the `nixpkgs` input ONLY.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- None (read-only snapshot; capture command output into the phase notes / summary).

**Verification**:
- Current kernel version and both panic sysctls recorded; actual `flake.lock` nixpkgs rev captured.

---

### Phase 2: Update nixpkgs input & confirm kernel >= 7.1.3 (abort gate) [NOT STARTED]

**Goal**: Bump only the `nixpkgs` input and prove — cheaply, via eval — that it resolves to kernel >= 7.1.3 before committing to a build.

**Tasks**:
- [ ] Run the targeted input update: `nix flake update nixpkgs` (updates ONLY the `nixpkgs` node in `flake.lock`; leaves `nixpkgs-unstable` at its task-104 pin).
- [ ] Confirm `flake.lock` changed only the `nixpkgs` node: `git diff flake.lock` (verify `nixpkgs-unstable` rev is unchanged).
- [ ] Evaluate the resolved kernel version: `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version`.
- [ ] ABORT GATE: it MUST print `"7.1.3"` (or higher). If it still shows `7.1.2` (or the bump would regress another input), revert `flake.lock` (`git checkout flake.lock`) and divert to the conditional Phase 6 fallback instead.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `flake.lock` - `nixpkgs` node advanced to `nixos-26.05` HEAD (kernel 7.1.3). No change to `flake.nix`.

**Verification**:
- `nix eval` of the kernel version prints >= `7.1.3`; `git diff flake.lock` shows only the `nixpkgs` node changed.

---

### Phase 3: Add panic_on_oops sysctl (retain panic=10) [NOT STARTED]

**Goal**: Ensure a future panic produces a capturable oops/pstore record, without removing the existing auto-reboot net.

**Tasks**:
- [ ] In `modules/system/boot.nix`, add `boot.kernel.sysctl."kernel.panic_on_oops" = 1;` (with a comment referencing task 104/106 and the empty-pstore diagnostics finding).
- [ ] Confirm the existing `"panic=10"` entry in `boot.kernelParams` is retained unchanged.
- [ ] Keep `extraModprobeConfig` (`mt7925e disable_aspm=1 power_save=0`) unchanged — research confirmed these are irrelevant to this race but harmless.
- [ ] Format the file: `nix fmt modules/system/boot.nix`.

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `modules/system/boot.nix` - add the `panic_on_oops` sysctl; `panic=10` retained.

**Verification**:
- `modules/system/boot.nix` contains both `panic=10` (in `kernelParams`) and `kernel.panic_on_oops = 1` (in `boot.kernel.sysctl`); `nix fmt` reports no further changes.

---

### Phase 4: Build hamsa & verify (no switch) [NOT STARTED]

**Goal**: Prove the combined change (kernel bump + sysctl) evaluates and builds, and that the toplevel embeds kernel >= 7.1.3, without activating.

**Tasks**:
- [ ] Flake sanity check: `nix flake check` (or at minimum a successful eval of the hamsa system).
- [ ] Build the configuration without switching: `nixos-rebuild build --flake .#hamsa` (equivalently `nix build .#nixosConfigurations.hamsa.config.system.build.toplevel`).
- [ ] Re-confirm the built kernel: `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version` prints >= `7.1.3`.
- [ ] Confirm the kernel came from the binary cache (no long local compile) — expected for the pure `nixpkgs` bump.
- [ ] Leave the change staged/uncommitted for the parent skill's postflight; do NOT switch.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Files to modify**:
- None beyond Phases 2-3 (this phase builds and verifies only).

**Verification**:
- `nixos-rebuild build --flake .#hamsa` succeeds; result symlink present; kernel version in the build is >= `7.1.3`.

---

### Phase 5: Activation (user-confirmed) & post-switch verification [NOT STARTED]

**Goal**: Activate the verified build and confirm the fix is live. Activation is a USER-CONFIRMED step (requires sudo) — the implementer flags it, the user runs it.

**Tasks**:
- [ ] FLAG for the user (do NOT run autonomously): `sudo nixos-rebuild switch --flake .#hamsa` followed by a reboot into the new kernel.
- [ ] After the user reboots, verify: `uname -r` >= `7.1.3`.
- [ ] Verify panic sysctls live: `cat /proc/sys/kernel/panic` == `10` and `cat /proc/sys/kernel/panic_on_oops` == `1`.
- [ ] Optional source confirmation: the `published`/`rcu_dereference_protected` block is present in `mt76_sta_add()` (per report Rec. 1).

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- None (system activation only; no repo file changes).

**Verification**:
- `uname -r` >= `7.1.3`, `/proc/sys/kernel/panic` == `10`, `/proc/sys/kernel/panic_on_oops` == `1`.

---

### Phase 6: FALLBACK — boot.kernelPatches cherry-pick [NOT STARTED] (CONDITIONAL)

**Goal**: Only if Phase 2's abort gate shows kernel < 7.1.3 (or the bump is otherwise blocked): apply the merged fix as a source patch onto the current kernel. Skip entirely on the main path.

**Tasks**:
- [ ] CONDITIONAL — execute only if Phase 2 did not deliver kernel >= 7.1.3. Otherwise mark this phase skipped.
- [ ] Revert any speculative `flake.lock` change from Phase 2 (`git checkout flake.lock`) so the base kernel stays at the current pin.
- [ ] Add the exact snippet below to `modules/system/boot.nix` (report §3, hash precomputed and apply dry-run-verified):

```nix
boot.kernelPatches = [
  {
    # Real fix for the mt76_wcid_add_poll sta_poll_list corruption panic
    # (task 104/106). Upstream 20b126920a25, in mainline 7.2-rc1 and stable
    # 7.1.3. REMOVE once linuxPackages_latest >= 7.1.3 (the patch will fail
    # to apply on a kernel that already contains it).
    name = "mt76-wcid-publish-check";
    patch = pkgs.fetchpatch {
      name = "mt76-wcid-publish-check.patch";
      url = "https://github.com/torvalds/linux/commit/20b126920a259df4d7dcae19fcfe2c57a74d6b2e.patch";
      hash = "sha256-gn0aq/7ruSlBobDribGiSKwh3wJqHhV0aKHb7yYOXxY=";
    };
  }
];
```

- [ ] Accept that a non-empty `boot.kernelPatches` forces a FULL local kernel rebuild (long compile on this laptop); build via `nixos-rebuild build --flake .#hamsa`.
- [ ] Add a tracking reminder to remove this snippet at the next successful nixpkgs bump to >= 7.1.3 (or the build will fail loudly on the already-applied hunk).
- [ ] Then proceed to Phase 4 (build/verify) and Phase 5 (user-confirmed switch).

**Timing**: 1.5 hours (dominated by the local kernel compile) — only if triggered.

**Depends on**: 2 (conditional — executed in place of the successful bump)

**Files to modify**:
- `modules/system/boot.nix` - add `boot.kernelPatches` list (temporary, remove at >= 7.1.3).
- `flake.lock` - reverted to the pre-Phase-2 pin.

**Verification**:
- `nixos-rebuild build --flake .#hamsa` succeeds with the patch applied (loud failure if the base kernel already contains it, confirming the >= 7.1.3 removal signal).

---

### Phase 7: Monitoring & close-out [NOT STARTED]

**Goal**: Establish how to confirm the fix held and document the escalation path if it does not.

**Tasks**:
- [ ] Record the success criteria to watch: 2+ weeks on >= 7.1.3 with (a) no journal-truncation freezes, (b) no new `/var/lib/systemd/pstore/` entries, (c) no `WARN … mt76_sta_add` lines in the journal.
- [ ] Document the check commands: `journalctl --list-boots` for unexpected reboots; `ls /var/lib/systemd/pstore/` for new dumps; `journalctl -k | grep -i mt76_sta_add` for the residual-race WARN.
- [ ] Note post-task housekeeping (retain one Jun-29 dump for upstream hygiene; prune the rest and `~/pstore-copy/` only after that, per report §6) — NOT executed in this task.
- [ ] Document the terminal fallback: if the same trace recurs on >= 7.1.3 WITH capture working, escalate to the Intel AX210 (non-vPro) / QCNCM865 hardware swap (report §5).

**Timing**: 0.25 hours (plus passive multi-week observation).

**Depends on**: 5

**Files to modify**:
- None (documentation / observation guidance captured in the implementation summary).

**Verification**:
- Monitoring commands and success/escalation criteria documented in the task summary.

## Testing & Validation

- [ ] `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version` prints >= `7.1.3` (Phase 2 and Phase 4).
- [ ] `git diff flake.lock` shows only the `nixpkgs` node changed (`nixpkgs-unstable` pin intact).
- [ ] `nixos-rebuild build --flake .#hamsa` succeeds and the kernel is sourced from the binary cache (no local compile on the main path).
- [ ] `modules/system/boot.nix` retains `panic=10` AND adds `kernel.panic_on_oops = 1`.
- [ ] Post-switch (user-run): `uname -r` >= `7.1.3`, `/proc/sys/kernel/panic` == `10`, `/proc/sys/kernel/panic_on_oops` == `1`.

## Artifacts & Outputs

- `flake.lock` - `nixpkgs` node bumped to kernel 7.1.3 (main path).
- `modules/system/boot.nix` - adds `boot.kernel.sysctl."kernel.panic_on_oops" = 1;`; retains `panic=10`.
- `modules/system/boot.nix` (conditional, Phase 6 only) - `boot.kernelPatches` fallback snippet.
- `specs/106_root_cause_fix_mt7925e_wifi_kernel_panics/summaries/01_mt7925e-kernel-fix-summary.md` - implementation summary (created at implement time).

## Rollback/Contingency

- Config changes are declarative: revert `flake.lock` and `modules/system/boot.nix` via git if the
  build fails, and the previous kernel remains selectable as a prior systemd-boot generation.
- If activation causes an unexpected regression, roll back to the previous generation from the
  systemd-boot menu, then `git checkout flake.lock modules/system/boot.nix`.
- If the `nixpkgs` bump does not deliver 7.1.3 or regresses another package, revert `flake.lock`
  and take the Phase 6 `boot.kernelPatches` fallback (local compile, remove at next >= 7.1.3 bump).
- If panics recur on >= 7.1.3 with capture working, escalate to the hardware swap (terminal fallback).

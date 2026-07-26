# Implementation Plan: Task #123 - Fix backstop polkit denial and replace stubbed verification with live checks

- **Task**: 123 - fix_backstop_polkit_denial_live_verification
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours (2.0 agent-runnable, 0.5 user-required)
- **Dependencies**: Task 117 (rounds 1-3 built, committed, and live; round 3's USER CHECKLIST item 3b discovered this defect and opened this task). Task 117 files are **read-only cross-references** for this plan — see File Scope.
- **Research Inputs**: specs/123_fix_backstop_polkit_denial_live_verification/reports/01_backstop-polkit-denial.md
- **Artifacts**: plans/01_backstop-polkit-fix.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/nix.md
- **Type**: nix

## Overview

The `battery-suspend-backstop` oneshot in `modules/system/power.nix` calls
`systemctl suspend -i` as session-less root with no polkit agent. The shipped login1 policy sets
`allow_any=auth_admin_keep` on `org.freedesktop.login1.suspend-ignore-inhibit`, so that call is
**denied on every firing** — the <=10% battery safety net has never once been able to suspend.
This plan adds a narrowly-scoped `security.polkit.extraConfig` rule granting root that one action,
corrects two places in the repo that already assert (falsely) that root is polkit-authorized,
commits the previously-ephemeral offline test suite with an honest scope caveat, and replaces
stubbed verification with a layered check ladder whose strongest rungs are user-run.

Definition of done: the rule is committed and build-verified; the offline suite is a real file in
the repo carrying its own stub caveat plus one new non-stubbed `pkcheck` assertion; the two false
polkit claims are corrected; and the USER CHECKLIST in Phase 4 has been executed with recorded
results, including a real `systemctl suspend -i` from a session-less root context that actually
suspends the machine.

**This plan does not accept build-green or offline-green as evidence of the live behavior.** Two
consecutive defects in this same file shipped as "verified" because the verification stubbed out
the real call (`BACKSTOP_SYSTEMCTL_BIN` hid the polkit denial; `BACKSTOP_NOTIFY_BIN` hid the
`runuser #UID` defect). Phases 1-3 are explicitly incapable of proving the backstop can suspend.
Only Phase 4 items U3 and U4 prove that, and they require `sudo` and a real suspend cycle.

### Research Integration

| Finding | How this plan uses it |
|---|---|
| A — `security.polkit.extraConfig` is the correct mechanism; it merges into the existing `/etc/polkit-1/rules.d/10-nixos.rules` body, so no new-file ordering conflict exists | Phase 1 uses `extraConfig` with exact-equality checks on `action.id` and `subject.user`. The `environment.etc` symlink to systemd's `.example` is **rejected** (it grants all five `*-ignore-inhibit` actions). |
| B — `/sys/power/state` and inhibitor-teardown alternatives evaluated and rejected | Settled. Not re-litigated. No phase explores them. |
| C — polkit refuses `CheckAuthorization()` for subjects other than the caller unless the caller is uid 0; agents in this repo must not run `sudo` | Drives the split: agent-runnable checks are Phase 1/2/3 + the unprivileged `pkcheck` non-regression probe; the true end-to-end checks are Phase 4's USER CHECKLIST. |
| C row 3 — nixpkgs `polkit.nix:91` carries an upstream `# TODO: validation on compilation`; a typo in the rule JS builds fine and silently fails to load | Phase 1 adds a `node --check` syntax smoke test on the extracted rule block. |
| D — the "23/23 assertions" suite is **not committed**; it exists only as a session scratchpad | Phase 2 commits it with an in-file caveat header and one new no-`sudo` assertion. |
| E — the security delta is narrow and net-positive (root already has an unconditional, hook-skipping `/sys/power/state` path) | Recorded in the code comment and docs; no additional gating required. |

### Prior Plan Reference

No prior plan exists for task 123. Task 117's
`specs/117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md`
Phase 8 is used as a **format reference only** for the USER CHECKLIST pattern (delimited block,
numbered items, `RESULT <date> — PASSES/FAILS` annotations written in-place). No task 117 file is
edited by this plan.

### Roadmap Alignment

No ROADMAP.md found in this repository. No roadmap phases included.

## File Scope

This task may create or modify exactly these files:

| Path | Status | Change |
|---|---|---|
| `modules/system/power.nix` | modify | Add `security.polkit.extraConfig` rule; correct the false "root is polkit-authorized" comment at ~line 218 |
| `tests/battery-suspend-backstop-offline.sh` | create | Commit the previously-ephemeral offline suite + caveat header + one new `pkcheck` assertion |
| `docs/no-sleep-agents.md` | modify | Correct the false "Root is authorized to do this via polkit" claim (~line 180) |
| `docs/testing.md` | modify | One pointer to the new test script and its scope limits |

**Out of scope — do not edit**: anything under `specs/117_*` (separate task, separate scope —
cross-reference by path only), any other `modules/`, `hosts/`, or `flake.nix` file, and any file
under `/etc` or `/nix/store` (read-only inspection of built closures is permitted).

Directory guardrail: create `specs/123_.../plans/` only when writing this artifact; do not
pre-create `summaries/`.

## Goals & Non-Goals

**Goals**:
- Grant root `org.freedesktop.login1.suspend-ignore-inhibit` and nothing else, via
  `security.polkit.extraConfig` in `modules/system/power.nix`.
- Prove — by a real, non-stubbed, session-less-root `systemctl suspend -i` that actually suspends
  the machine — that the backstop's suspend leg now works.
- Prove — by a real, non-stubbed run of the built backstop script — that the notification leg
  works with only the battery state faked.
- Make the offline test suite a committed repo artifact whose own text states what it does not
  cover, so "N/N passing" can never again be mistaken for end-to-end coverage.
- Remove the two false polkit-authorization claims already in the repo.

**Non-Goals**:
- Granting any of the other four `*-ignore-inhibit` actions (power-off, reboot, halt, hibernate).
- Introducing a test framework (bats, NixOS VM tests, mocked polkit). The suite stays a single
  plain shell script.
- Re-opening the mechanism decision or the rejected alternatives from research findings A and B.
- Any change to the wake-grace logic, timer cadence, threshold, or notification helper. Those are
  task 117's; this task only fixes authorization plus verification honesty.
- Editing task 117's plan, summary, or handoff files to record this round's results.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| A typo in the new polkit JS builds fine but silently fails to load at the polkit daemon, reproducing the same silent-no-op class of defect one layer deeper (nixpkgs `polkit.nix:91` has no compile-time validation) | H | L | Phase 1 greps the rule out of the **built** closure and runs `node --check` on it; Phase 4 item U2 then positively confirms the rule is live via a root `pkcheck` before anything suspends |
| `sudo pkcheck ... --process "$$"` is written unquoted, so `$$` expands in the *user's* shell (uid 1000) instead of the root shell — the check then reports the pre-fix result and looks like a failure (or, with other shapes, a false pass) | H | M | Phase 4 U2 mandates the single-quoted `sudo bash -c '...'` form and states the expansion hazard inline; the expected exit code is stated for both the correct and the mis-expanded form so a mistake is self-evident |
| The user skips the `sudo`/suspend items under time pressure and the task is marked done on build-green alone — exactly the failure mode that shipped the last two defects | H | M | The USER CHECKLIST is a delimited, un-skippable block; Phase 4's agent-runnable follow-up explicitly cannot be completed without U1-U4 results, and the plan states that Phases 1-3 prove nothing about live behavior |
| `nix flake check` is documented as unreliable in this repo (`docs/testing.md` says evaluation errors are expected for complex wrappers) and its failure is misread as this change breaking the build | M | M | Phase 1 makes `nixos-rebuild build --flake .#hamsa` the authoritative build gate; `nix flake check` is best-effort and its output must be compared against a pre-change baseline before being attributed to this change |
| A future NixOS module drops a `.rules` file sorting lexically before `10-nixos.rules` and shadows this rule (polkit stops at the first non-`NOT_HANDLED` result) | M | L | No such file exists today (verified in research); Phase 1 adds a one-line code comment recording the ordering assumption so a future change to `rules.d` composition is flagged |
| The team over-trusts "23/23 assertions" again, since the assertion count barely changes after this fix | H | M | Phase 2 puts the caveat in the script's own header comment and in its final summary line, not only in prose docs; Phase 3 repeats it in `docs/testing.md` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`modules/system/power.nix` vs. `tests/`) and may be dispatched together.

---

### Phase 1: Add the root suspend-ignore-inhibit polkit rule [COMPLETED]

**Runnable by**: **Agent.** No `sudo`, no activation, no suspend. Build verification is
agent-runnable and is included here.

**Goal**: The narrow polkit rule is committed to `modules/system/power.nix`, present and
syntactically valid in the built system closure, and the file no longer claims root is already
authorized.

**Tasks**:
- [x] Read `modules/system/power.nix` and locate the top-level `config` attribute set (opens at
      line 118) and the backstop banner comment block (~lines 205-285).
- [x] Add a `security.polkit.extraConfig` attribute at the top level of that set, placed adjacent
      to the `systemd.services.battery-suspend-backstop` definition so the grant and its consumer
      are read together. Use exactly this rule shape (exact equality on both fields, mirroring the
      `automatic-timezoned` in-tree precedent):
      ```nix
      security.polkit.extraConfig = ''
        // Allow root to suspend while ignoring inhibitors, for the session-less
        // battery-suspend-backstop oneshot below. Without this the oneshot's
        // `systemctl suspend -i` is denied on every firing (login1 ships
        // suspend-ignore-inhibit as auth_admin_keep on all three subject
        // classes, and a session-less root caller has no agent to prompt), so
        // the <=10% safety net is a silent no-op.
        //
        // Deliberately narrower than systemd's shipped
        // 10-systemd-logind-root-ignore-inhibitors.rules.example, which grants
        // all five *-ignore-inhibit actions (power-off/reboot/halt/suspend/
        // hibernate). This repo needs suspend only.
        //
        // Ordering assumption: NixOS appends extraConfig into the body of
        // /etc/polkit-1/rules.d/10-nixos.rules, today the only .rules file on
        // this host. polkit stops at the first rule returning a non-NOT_HANDLED
        // value, so a future .rules file sorting lexically before 10-nixos
        // could shadow this. Re-check if rules.d composition ever changes.
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.login1.suspend-ignore-inhibit" &&
              subject.user == "root") {
            return polkit.Result.YES;
          }
        });
      '';
      ```
- [x] Correct the false claim in the existing banner comment (~line 218): `systemctl suspend -i`
      is *not* something "root is polkit-authorized to use" by default. Replace that clause with
      wording that points at the `security.polkit.extraConfig` rule as the thing that makes it
      true, so the comment stops asserting a property the system does not have on its own.
- [x] Verify formatting against `.claude/rules/nix.md`: 2-space indent, no tabs, no top-level
      `with pkgs;`, comment lines within the soft 100-column limit.

**Timing**: 45 minutes (most of it the build).

**Depends on**: none

**Files to modify**:
- `modules/system/power.nix` — add `security.polkit.extraConfig`; correct the ~line 218 comment.

**Verification** (all agent-runnable, all read-only; **none of these prove the backstop can
suspend**):
1. **Authoritative build gate**: `nixos-rebuild build --flake .#hamsa` exits 0. This produces a
   `./result` symlink; `result` is already gitignored — inspect it, then remove the symlink and
   never stage it.
2. **Best-effort only**: `nix flake check`. `docs/testing.md` documents that this repo hits
   expected evaluation errors here for unrelated reasons. If it fails, capture the output and
   compare against a pre-change baseline (`git stash` the edit, re-run, unstash) before
   attributing the failure to this change. A pre-existing failure does not block the phase.
3. **Rule is present in the built artifact, not just the source**:
   `grep -n "suspend-ignore-inhibit" ./result/etc/polkit-1/rules.d/10-nixos.rules` — must show the
   new rule inside the same file that already carries the `addAdminRule` block and the
   `automatic-timezoned`/cups/NetworkManager/`fwupd-refresh` rules.
4. **Scope is narrow**: in that same built file, confirm zero matches for
   `power-off-ignore-inhibit`, `reboot-ignore-inhibit`, `halt-ignore-inhibit`, and
   `hibernate-ignore-inhibit`. Confirm the rule body contains `subject.user == "root"` with `==`,
   not `indexOf` or a substring test.
5. **Syntax smoke test** (closes the upstream no-validation gap): extract the `addRule` block from
   the built file into a scratch `.js` under the session scratchpad and run `node --check` on it.
   Exit 0 required. `node` is on `$PATH` on this host. This catches gross typos only — polkit runs
   mozjs, not node — and is not a substitute for verification item U2 in Phase 4.
6. **Non-regression for unprivileged callers** (baseline capture):
   `pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"` run as the
   agent's own uid-1000 identity. Expected **now and after activation**: `polkit.result=auth_admin_keep`,
   exit 2. A change here would mean the rule over-granted. Note that this probe reads the
   *currently live* `/etc` rules, so before activation it is a baseline, not a post-fix check.
7. Record explicitly in the phase notes: items 1-6 prove the rule builds, is present, is narrow,
   and parses — they prove **nothing** about whether root can now suspend. That is Phase 4.

**Verification results (recorded 2026-07-26)**:
1. `nixos-rebuild build --flake .#hamsa` — exit 0. Built
   `/nix/store/x3siinp9ccib8z5wxa0dwbi8p3szxxca-nixos-system-hamsa-26.05.20260710.8f0500b`.
2. `nix flake check` — exit 0, "all checks passed!" (all four `nixosConfigurations`, `formatter`,
   `devShells`). Not a known-expected failure this round; reported as an honest pass, not
   presumed green without running it.
3. `grep -n "suspend-ignore-inhibit" ./result/etc/polkit-1/rules.d/10-nixos.rules` — one match, the
   new rule, alongside the pre-existing `addAdminRule` and `automatic-timezoned`/cups/
   NetworkManager/`fwupd-refresh` blocks in the same file.
4. Scope check in the same built file: `grep -c` for `power-off-ignore-inhibit`,
   `reboot-ignore-inhibit`, `halt-ignore-inhibit`, `hibernate-ignore-inhibit` — zero matches for
   all four (grep exit 1). `subject.user == "root"` confirmed present with `==`.
5. `node --check` on the extracted `addRule` block (lines 5-10 of the built file) — exit 0, no
   syntax errors.
6. Unprivileged baseline: `pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit
   --process "$$"` as uid 1000 — `polkit.result=auth_admin_keep`, exit 2, as expected pre- and
   post-activation. This is a pre-activation baseline only (reads the live, not-yet-updated
   `/etc` rules); it must be re-run after Phase 4 U1 to confirm no over-grant.
7. Confirmed: none of items 1-6 demonstrate that root can now suspend. That evidence is Phase 4
   U2/U3/U4 only, and requires `sudo` this agent must not run.

---

### Phase 2: Commit the offline test suite with its stub caveat and one live assertion [COMPLETED]

**Runnable by**: **Agent.** No `sudo`. The script itself must run without `sudo` and without
suspending anything.

**Goal**: The "23/23 assertions" suite stops being an ephemeral scratchpad and becomes a committed
file that states its own coverage limits in its own text, plus one new assertion that is not
stubbed.

**Tasks**:
- [x] Create `tests/battery-suspend-backstop-offline.sh` (new top-level `tests/` directory; the
      repo has no existing test-harness convention, and `modules/system/` holds Nix modules only).
      Make it executable.
- [x] Reconstruct the offline logic exercise: resolve the built backstop script out of the
      current system closure, then drive it with `BACKSTOP_BATTERY_GLOB` pointed at a scratch fake
      `BAT0` tree, `STATE_DIRECTORY` pointed at a scratch dir, and `BACKSTOP_SYSTEMCTL_BIN` /
      `BACKSTOP_NOTIFY_BIN` pointed at recording stubs. Cover the same assertion set as the prior
      round: threshold boundary behavior, the `Discharging` vs. `Not charging`/`Charging` AC gate,
      the wake-grace window bounds, the notified-marker logic, and the `--test-notify` path.
- [x] **Caveat header, mandatory** — a comment block at the very top of the file stating, in
      substance: these assertions exercise the script's *decision logic only*. They stub
      `systemctl` and the notify helper, so they cannot detect an authorization failure on the real
      `systemctl suspend -i` (the defect this task fixes) nor a failure in the real
      root-to-session notification path (the `runuser` defect fixed in the prior round). Both of
      those defects passed this suite. A green run here is **not** evidence the backstop works.
      Name the two env vars responsible so the mechanism is unambiguous.
- [x] **New assertion (non-stubbed, no `sudo`)** — authorization non-regression for the calling
      identity: run
      `pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"` as the
      invoking (unprivileged) user and assert the result is `auth_admin_keep` / exit 2, i.e. the
      new rule did **not** broaden authorization beyond root. Comment it honestly as
      "authorization non-regression for the calling identity — this CANNOT confirm root is
      granted; polkit refuses cross-identity CheckAuthorization() for untrusted callers. See the
      known-gap footer." Skip with a clear message (not a failure) if `pkcheck` is absent.
- [x] **Known-gap footer** — the script's final summary must print, alongside the pass count, a
      short block naming the checks that require a human: the root `pkcheck` query and the real
      session-less `systemctl suspend -i` probe, with a pointer to this plan's Phase 4 USER
      CHECKLIST by path. The pass line must not read as unqualified success.
- [x] Keep it proportionate: one plain `bash` script, roughly 70-100 lines. No bats, no NixOS VM
      test, no mocked polkit, no new dependency. *(deviation: altered — 108 lines, ~8% over the
      soft 70-100 envelope; the extra length comes from covering all 8 offline cases from the
      task-117 baseline plus the notified-marker-suppression and pkcheck assertions without
      collapsing readability. No test framework or new dependency was introduced.)*

**Timing**: 45 minutes.

**Depends on**: none

**Files to modify**:
- `tests/battery-suspend-backstop-offline.sh` — new file.

**Verification** (agent-runnable):
1. `bash tests/battery-suspend-backstop-offline.sh` exits 0 with all assertions passing, run as
   the unprivileged agent user, with no `sudo` and no suspend.
2. `bash -n tests/battery-suspend-backstop-offline.sh` parses clean; `shellcheck` if available
   (non-blocking).
3. The script leaves no residue outside its scratch dir: re-running twice in a row is idempotent,
   and `/var/lib/battery-suspend-backstop` is untouched (confirm its mtime is unchanged).
4. `grep -c "" tests/battery-suspend-backstop-offline.sh` is within the ~70-100 line envelope.
5. The caveat header and known-gap footer are present and mention `BACKSTOP_SYSTEMCTL_BIN` and
   `BACKSTOP_NOTIFY_BIN` by name.
6. Confirm the new `pkcheck` assertion actually invoked `pkcheck` (it is the one assertion in the
   file with no stub between it and the system).

**Verification results (recorded 2026-07-26)**:
1. `bash tests/battery-suspend-backstop-offline.sh` — exit 0, "16 passed, 0 failed", run as the
   unprivileged agent user, no `sudo`, no suspend.
2. `bash -n tests/battery-suspend-backstop-offline.sh` — parses clean. `shellcheck` is not on
   `$PATH` on this host; skipped per the plan's non-blocking allowance.
3. Ran the script twice in a row: outputs byte-identical (idempotent), and
   `/var/lib/battery-suspend-backstop` mtime confirmed unchanged before/after
   (`1785003350` both times) — the suite operates entirely inside a `mktemp -d` scratch tree via
   `STATE_DIRECTORY`/`BACKSTOP_BATTERY_GLOB` overrides.
4. `grep -c "" tests/battery-suspend-backstop-offline.sh` — 108 lines. Slightly over the ~70-100
   soft envelope (see deviation annotation above); no test framework or new dependency added.
5. Caveat header (top of file) and known-gap footer both present and both name
   `BACKSTOP_SYSTEMCTL_BIN` and `BACKSTOP_NOTIFY_BIN` explicitly.
6. Confirmed the `pkcheck` assertion actually invokes the real `pkcheck` binary (no stub) and
   returned `auth_admin_keep`/exit 2, consistent with Phase 1 item 6's baseline — no over-grant to
   the unprivileged caller.

---

### Phase 3: Correct the false polkit claims in the docs [COMPLETED]

**Runnable by**: **Agent.** Documentation only.

**Goal**: No file in the repo asserts that root is authorized for `suspend-ignore-inhibit` by
default, and a reader can find the test suite and its limits.

**Tasks**:
- [x] `docs/no-sleep-agents.md` (~line 180, mechanism 4): the sentence "Root is authorized to do
      this via polkit." is false as written — it was false when written, and is the precise belief
      that let the defect ship. Replace it with an accurate statement: the login1 policy ships
      `suspend-ignore-inhibit` as `auth_admin_keep` for all three subject classes, so a
      session-less root caller is denied by default; this configuration grants root that one
      action explicitly via `security.polkit.extraConfig` in `modules/system/power.nix`. Note the
      grant is narrower than systemd's shipped example (suspend only, not the other four actions).
      *(deviation: altered — per `.claude/rules/no-task-references-in-deliverables.md`, the
      replacement text does not cite the task number or a `specs/` path since `docs/` is outside
      `specs/**`; it states the mechanism and rationale directly instead.)*
- [x] In the same document's verification section (~lines 243-247, alongside the existing
      `systemctl is-active battery-suspend-backstop.timer` checks), add the root `pkcheck` query as
      the way to confirm the authorization leg, flagged as requiring `sudo`.
- [x] `docs/testing.md`: add a short pointer to `tests/battery-suspend-backstop-offline.sh`
      stating what it covers (decision logic, stubbed `systemctl`/notify) and what it does not
      (the authorization and notification legs), so the caveat is discoverable from the repo's
      testing entry point and not only from inside the script.
- [x] Cross-reference task 117 by path only
      (`specs/117_laptop_lid_close_no_sleep_headless/`) where prior-round history is relevant. Do
      not edit any file under that directory. *(deviation: altered — no cross-reference to
      task 117 was added to the docs/ files themselves, consistent with the no-task-references
      rule above; task 117 is cross-referenced only within this plan file, which lives under
      `specs/**`.)*

**Timing**: 25 minutes.

**Depends on**: 1, 2

**Files to modify**:
- `docs/no-sleep-agents.md` — correct the false claim; add the `pkcheck` verification line.
- `docs/testing.md` — pointer to the new suite and its scope limits.

**Verification** (agent-runnable):
1. `grep -rn "Root is authorized to do this via polkit" docs/` returns nothing.
2. `grep -rn "polkit-authorized" modules/ docs/` returns nothing, or only text that names the
   explicit rule as the source of the authorization.
3. `grep -rn "battery-suspend-backstop-offline" docs/` finds the pointer in `docs/testing.md`.
4. `git status --short` shows changes confined to the four paths in File Scope; nothing under
   `specs/117_*` is modified.

**Verification results (recorded 2026-07-26)**:
1. `grep -rn "Root is authorized to do this via polkit" docs/` — no matches.
2. `grep -rn "polkit-authorized" modules/ docs/` — no matches.
3. `grep -rn "battery-suspend-backstop-offline" docs/` — found in `docs/testing.md` (two lines:
   prose pointer and the invocation example).
4. `git status --short` — changes confined to `docs/no-sleep-agents.md`, `docs/testing.md` (this
   phase), plus `modules/system/power.nix` and `tests/battery-suspend-backstop-offline.sh` from
   Phases 1-2, all within File Scope. Nothing under `specs/117_*` touched.

---

### Phase 4: Live end-to-end verification [NOT STARTED]

**Runnable by**: **Split.** Items U1-U4 are **user-required** — they need `sudo`, a NixOS
generation activation, and a real suspend/resume cycle. Agents must not attempt any of them. The
post-activation block at the end is agent-runnable, but only *after* the user reports U1-U4
results.

**Goal**: A recorded, non-stubbed demonstration that the backstop's `systemctl suspend -i`
actually suspends the machine from a session-less root context, and that the notification leg
fires for real.

**Why this cannot be automated**: polkit refuses `CheckAuthorization()` for any subject other than
the caller's own identity unless the caller is uid 0 (research finding C, reproduced live: a
`--process "1"` probe returns `GDBus.Error:...NotAuthorized`, and the `PID,START_TIME,UID`
override's UID field is ignored for untrusted callers). This is a security boundary, not a tooling
gap. There is no agent-side substitute; do not invent one.

**Tasks**:
- [ ] Present the USER CHECKLIST below to the user verbatim and wait for results.
- [ ] Record each item's outcome in place as `RESULT <YYYY-MM-DD> — PASSES` / `— FAILS` with the
      observed output, mirroring the annotation style of
      `specs/117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md`
      Phase 8.
- [ ] If U2 fails, **stop**: do not proceed to U3 or U4, mark the phase `[BLOCKED]`, and treat the
      rule as not working. Re-check Phase 1 verification items 3-5 against the *live* `/etc` file
      rather than the built closure (activation may not have taken).

**Timing**: 30 minutes of user time; 15 minutes of agent follow-up.

**Depends on**: 1, 2, 3

**Files to modify**: none. This phase produces recorded results only.

---

**USER CHECKLIST** — requires `sudo`, a NixOS activation, or a real suspend cycle. **Agents must
not perform any of these.** Run them in order: U2 is a cheap, non-suspending gate placed
deliberately before U3 so an authorization failure is caught without ever suspending the machine.

**U1. Activate the change.**
```
sudo nixos-rebuild switch --flake .#hamsa
```
No reboot required — this adds a polkit rule to a file the system already ships and does not alter
logind. Confirm the new rule is live in the running system (not just the built closure):
```
grep -n suspend-ignore-inhibit /etc/polkit-1/rules.d/10-nixos.rules
```

**U2. Cheap authorization gate — query only, nothing suspends.** This is the first positive proof
that root is granted the action.
```
sudo bash -c 'pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"'
```
Expected after the fix: **exit 0** (authorized), with no `auth_admin_keep` line.

Note the quoting: the single-quoted `bash -c` form is required so `$$` expands to the **root**
shell's PID. Writing `sudo pkcheck ... --process "$$"` expands `$$` in your own uid-1000 shell
instead and will report `polkit.result=auth_admin_keep`, exit 2 — that is the mis-invocation, not
a real failure. If you get exit 2, re-run with the exact command above before concluding anything.

**If U2 does not return exit 0, STOP HERE.** Do not run U3 or U4. Report the output; the rule is
not live or not matching.

**U3. Real end-to-end suspend probe — this suspends the machine.** This is the exact
session-less-root, no-agent shape that reproduced the original denial:
```
sudo systemd-run --pipe --quiet --service-type=oneshot systemctl suspend -i --no-ask-password
```
Expected: the machine **actually suspends**, instead of printing "The current polkit policy does
not allow root to ignore inhibitors without authentication in order to suspend." Wake with the lid
or a keypress. Run this with a Claude Code session open so block inhibitors are genuinely held —
otherwise the probe does not exercise the inhibitor-skipping path that matters.

**U4. Non-stubbed backstop run — real suspend AND real notification, only the battery faked.**
This is the item that satisfies "verify the suspend and notification legs without the stubs".
Create a scratch fake battery tree and a scratch state dir, then invoke the **real built** backstop
script with only `BACKSTOP_BATTERY_GLOB` and `STATE_DIRECTORY` overridden — leave
`BACKSTOP_SYSTEMCTL_BIN` and `BACKSTOP_NOTIFY_BIN` **unset** so the real `systemctl` and the real
notify helper are used:
```
mkdir -p /tmp/fakebat/BAT0 /tmp/fakestate
echo Discharging > /tmp/fakebat/BAT0/status
echo 9          > /tmp/fakebat/BAT0/capacity
sudo env BACKSTOP_BATTERY_GLOB='/tmp/fakebat/BAT*' STATE_DIRECTORY=/tmp/fakestate \
  "$(systemctl cat battery-suspend-backstop.service | sed -n 's/^ExecStart=//p')"
```
Expected: a critical low-battery notification appears in the GNOME session **and** the machine
suspends. Nobody should drain the real battery to 9% to test this; the battery state is the one
input that cannot safely be faked any other way. Both overridden vars are inputs only — neither
stands between the script and the two legs under test.

**U5. Report back** the outcome of U1-U4 (pass/fail plus any output) so the agent-runnable
follow-up below can be completed.

---

**Agent-runnable post-activation follow-up** (only after the user reports U1-U4):
- [ ] Re-run the unprivileged non-regression probe:
      `pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"` — must
      still be `auth_admin_keep`, exit 2. A change means the rule over-granted to non-root callers.
- [ ] Re-run `bash tests/battery-suspend-backstop-offline.sh` against the newly activated system;
      all assertions still pass.
- [ ] `journalctl -u battery-suspend-backstop.service -n 40 --no-pager` — confirm the denial
      message no longer appears on firings after activation.
- [ ] Confirm the resume from U3/U4 exercised the wake hook:
      `systemctl status battery-backstop-wake-mark.service` shows an activation timestamp, and
      `/var/lib/battery-suspend-backstop/` is no longer empty. (This is task 117's mechanism being
      exercised for the first time as a side effect; record the observation, do not modify it.)
- [ ] Confirm the live `/etc/polkit-1/rules.d/10-nixos.rules` still contains no
      `power-off`/`reboot`/`halt`/`hibernate` `-ignore-inhibit` grant.

**Verification**: this phase is complete only when U1-U4 carry recorded `RESULT` annotations and
U3 or U4 shows an actual suspend. Build-green and offline-green do **not** complete this phase.

## Testing & Validation

Ordered weakest to strongest. Each row states who can run it and what it actually proves.

- [ ] **Agent** — `nixos-rebuild build --flake .#hamsa` exits 0. Proves: the Nix evaluates.
- [ ] **Agent** — `nix flake check` (best-effort; compare to pre-change baseline before blaming
      this change). Proves: nothing on its own in this repo.
- [ ] **Agent** — the new rule is present in `./result/etc/polkit-1/rules.d/10-nixos.rules` and
      grants exactly one action to exactly one subject. Proves: the text landed and is narrow.
- [ ] **Agent** — `node --check` on the extracted rule block exits 0. Proves: no gross JS typo
      (upstream provides no compile-time validation).
- [ ] **Agent** — `bash tests/battery-suspend-backstop-offline.sh` all-pass. Proves: the script's
      **decision logic** only. Stubs `systemctl` and notify. **Does not prove the backstop works.**
- [ ] **Agent** — unprivileged `pkcheck` still returns `auth_admin_keep`/exit 2 after activation.
      Proves: no over-grant to non-root callers. Cannot prove root is granted.
- [ ] **User** (`sudo`, no suspend) — root `pkcheck` returns exit 0. Proves: root is authorized.
- [ ] **User** (`sudo`, suspends) — `sudo systemd-run --pipe --quiet --service-type=oneshot
      systemctl suspend -i --no-ask-password` suspends the machine. **Proves the suspend leg works
      end to end.**
- [ ] **User** (`sudo`, suspends + notifies) — the real built backstop script with only the battery
      faked suspends **and** raises a notification. **Proves both legs work with no stub in the
      path.**

**Acceptance bar**: the task may be marked complete only if the last two rows passed and were
recorded. Any other combination is at best `[PARTIAL]`.

## Artifacts & Outputs

- `modules/system/power.nix` — modified: `security.polkit.extraConfig` rule; corrected comment.
- `tests/battery-suspend-backstop-offline.sh` — new: committed offline suite with stub caveat
  header, one non-stubbed `pkcheck` assertion, and a known-gap footer.
- `docs/no-sleep-agents.md` — modified: false polkit claim corrected; root `pkcheck` verification
  step added.
- `docs/testing.md` — modified: pointer to the new suite and its scope limits.
- `specs/123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md` — this
  plan, with Phase 4 USER CHECKLIST results annotated in place.
- `specs/123_fix_backstop_polkit_denial_live_verification/summaries/01_backstop-polkit-fix-summary.md`
  — implementation summary. Must reproduce the USER CHECKLIST outcomes and must not present
  build-green or offline-green as end-to-end verification.

**Commits** (per `.claude/rules/git-workflow.md`, targeted staging only — never `git add -A`):
- `task 123 phase 1: grant root suspend-ignore-inhibit via polkit rule`
- `task 123 phase 2: commit offline backstop suite with stub caveat`
- `task 123 phase 3: correct false polkit authorization claims in docs`
- `task 123: complete implementation` (after Phase 4 results are recorded)

Do not stage `./result`.

## Rollback/Contingency

- **Phases 1-3 (nothing activated)**: `git revert` the phase commit, or drop the
  `security.polkit.extraConfig` block. No system state has changed — a built-but-unswitched
  closure has no effect on the running system.
- **After U1 activation, if the rule misbehaves**: `sudo nixos-rebuild switch --rollback` returns
  to the prior generation immediately; the polkit rule disappears with it. The backstop reverts to
  its current (broken, denied) behavior — no worse than today. Alternatively boot the previous
  generation from the boot menu.
- **If U2 fails (rule not effective)**: mark Phase 4 `[BLOCKED]`, leave the committed rule in place
  (it is inert when not matching, and reverting loses the diff needed to diagnose), and re-verify
  against the live `/etc/polkit-1/rules.d/10-nixos.rules` rather than the built closure. Check for
  a newly-appeared `.rules` file sorting before `10-nixos.rules` and for a JS parse failure in the
  polkit daemon's journal (`journalctl -u polkit -b 0`) — the latter is the silent-typo failure
  mode Phase 1 verification item 5 targets.
- **If U3/U4 fail after U2 passes**: the authorization leg is fixed but something else in the call
  path is broken. Do **not** revert the polkit rule (U2 proved it correct). Open a follow-up rather
  than widening this task's scope, and record the failure verbatim in the summary — a partial
  result stated honestly is the point of this task.
- **Test suite**: `tests/battery-suspend-backstop-offline.sh` is inert — it is never invoked by the
  build or by any systemd unit. Deleting the file is a complete rollback of Phase 2.

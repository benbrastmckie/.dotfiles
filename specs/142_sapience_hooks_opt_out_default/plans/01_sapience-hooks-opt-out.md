# Implementation Plan: Sapience Hooks Opt-Out Default

- **Task**: 142 - Stop the Sapience vendor updater from wiring machine-wide Claude Code hooks
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/142_sapience_hooks_opt_out_default/reports/01_sapience_hooks_opt_out.md
- **Artifacts**: plans/01_sapience-hooks-opt-out.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

`modules/home/services/sapience.nix`'s `sapienceBootstrap` writes `~/.sapience/config.json`'s
`"hooks"` key through two jq expressions that both force the value to `true`: a merge site using
`.hooks = (.hooks // true)` (jq's `//` treats an explicit `false` identically to absent) and a
first-run mint literal `hooks: true`. The vendor's own gate, `hooks_opted_out()` in
`~/.sapience/sapience_upkeep.py`, already does the right thing (`.get('hooks') is False`, an
explicit identity test), so the defect is entirely this repository's. This plan replaces `//`
with an explicit null test at the merge site, flips the mint literal to `false`, adds a
repo-tracked detector for a reappeared vendor hook in `~/.claude/settings.json` wired into
activation ahead of the enforced-key merge that would otherwise hide it, documents the resulting
three-layer design, and closes with an on-machine rebuild plus a forced vendor update to confirm
no user-level hook returns.

Definition of done: both write sites default `"hooks"` to `false` while preserving any explicit
value; the detector exists, is covered by `nix flake check`'s shellcheck, and fires on an
injected hook; `docs/sapience.md` and the `sapience.nix` header state the design; and a real
`home-manager switch` followed by `python3 ~/.sapience/sapience_upkeep.py --update` leaves
`~/.claude/settings.json` free of any `~/.sapience` injection hook.

### Research Integration

Findings carried into this plan from `reports/01_sapience_hooks_opt_out.md`:

- The two write sites and their exact current text (report §1) are reproduced verbatim in Phase 1
  so the implementer diffs both rather than fixing only the one the dispatch text highlighted.
- GOAL item (2) is **already confirmed from vendor source** (report §2) and needs no further
  investigation: `"hooks": false` gates exactly two things — the updater's `wire_hooks()` write
  into `~/.claude/settings.json`, and `cli_auto_on_plan`'s auto-on probe. It does not gate
  `mcp.py --briefing-text/--receipt/--effect-line` (they check only `TOKEN` presence) or
  `sapience_cli.py`'s `hook`/`answer` dispatcher (they check only `folder_allowed(cwd)` and
  per-session state), which is what the sapience extension's per-repository
  `settings-fragment.json` invokes. Phase 4 re-attests this empirically rather than re-deriving
  it; no vendor-side or extension-side change is implicated.
- Report Decision 1 (default, not force) is adopted — see `## Decisions` below.
- Report Decision 2 (the new check is new code in this repository, never an edit to the
  extension's `verify-sapience-mcp.sh`) is adopted; nothing in this plan touches `.claude/**` or
  the extension source store.
- Report §3's detection signature is adopted verbatim: a command string containing
  `.sapience/mcp.py` **together with** one of `--briefing-text`, `--receipt`, `--effect-line`.
  The legitimate, durable `sapience-mcp-register-project.sh` entry carries neither the path nor
  the flags, so it can never trip the detector.
- Report §3's **ordering recommendation is corrected by this plan** — see `## Decisions`
  Decision 3. This correction also re-derives report Decision 3 (abort vs. warn) on the correct
  ordering, reaching a different conclusion than the report's provisional recommendation.
- Report §4's doc scope is adopted: the new passage is additive to `docs/sapience.md`'s existing
  `### Why the hooks live in the repo` section, which today does not mention `config.json`'s
  `"hooks"` field at all.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so no roadmap phases are
added and `specs/ROADMAP.md` is neither read as authority nor modified. For orientation only:
the roadmap's Sapience cluster names other tasks (local-inference diagnosis, capture-coverage
measurement, classifier cost) and does not name this one; this task shares `docs/sapience.md`
territory with that cluster, which matters for batching but imposes no sequencing here while
those tasks are standing down.

## Goals & Non-Goals

**Goals**:

- Both `config.json` write sites in `sapienceBootstrap` default `"hooks"` to `false` and preserve
  an explicit value of either polarity (never `//`).
- A repo-tracked check detects any `~/.sapience` injection hook in `~/.claude/settings.json` and
  reports it loudly, with a hard-failing exit status available to a standalone or CI invocation.
- The check is positioned so it can actually observe an injection rather than inspecting a file
  the same activation run has already cleaned.
- `docs/sapience.md` and `modules/home/services/sapience.nix`'s header comment state the
  resulting design, naming the three layers and what each one does and does not do.
- An on-machine rebuild followed by a forced `sapience_upkeep.py --update` is observed to leave
  no user-level `~/.sapience` hook in `~/.claude/settings.json`.

**Non-Goals**:

- Changing the sibling `.auto_approve = (.auto_approve // false)` expression's behavior. It
  carries the same latent `//` defect in principle, but its default and its only
  desired-preserved-value coincide today, so the bug is invisible there. Phase 1 adds a one-line
  comment explaining the asymmetry; it does not change the expression.
- Any edit under `.claude/**`, or to the sapience extension's source store at
  `/home/benjamin/.config/nvim/agent-system/extensions/sapience`. The extension-side
  verifier/doc work is the companion task's
  (`sapience_activation_surface_scoping_gaps`, nvim repository).
- Adding a `programs.sapience` option to toggle machine-wide hooks back on. The default/preserve
  semantics chosen in Phase 1 leave that door open; building the toggle is out of scope.
- Changing `modules/home/core/dotfiles.nix`'s `claudeSettings` entry or its enforced-key list.
  This plan orders a new entry relative to it and must not alter it.
- Removing or narrowing the per-repository hooks the sapience extension merges into a
  repository's own `settings.local.json`. Those are the intended design and are confirmed
  unaffected by `"hooks": false`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Only the merge site is fixed, leaving the first-run mint still writing `hooks: true` on a fresh machine | M | M | Phase 1 reproduces both sites' exact current text and its verification requires a diff showing two changed hunks, not one |
| The detector is ordered after `claudeSettings` and silently never fires, giving false confidence | H | H (this is the report's own recommendation) | Decision 3: order `entryBefore [ "claudeSettings" ]`; Phase 2's verification injects a synthetic hook and requires the detector to actually report it |
| A hard-abort at activation blocks `home-manager switch` and, ordered before the enforced-key merge, also prevents the automatic strip | M | M | Decision 4: the activation invocation is non-fatal and loud; the hard-failing exit lives in the standalone script, which cannot brick a switch |
| The detector false-positives on the legitimate `sapience-mcp-register-project.sh` SessionStart entry | H | L | Signature requires `.sapience/mcp.py` **and** one of the three flag names together in one command string; Phase 2 verification asserts a clean live file reports no finding |
| `nix flake check` fails on the new shell script (it is inside the `shellSrc` fileset) or on formatting | L | M | Phase 2 runs `nix flake check` and `nixfmt`/`shellcheck` locally before closing |
| Phase 4's forced vendor update mutates live machine state in a way that is awkward to undo | M | L | The only mutation at risk is `~/.claude/settings.json` and `~/.sapience/config.json`; back both up to timestamped copies at the start of Phase 4 (the same convention the 2026-11-14 manual fix used), and a reverted-config failure is itself the finding being tested for |
| `sapience-bootstrap` is interactive (prompts for a token), so the fixed jq cannot be exercised end to end without a live token paste | M | H | Phase 1 verifies the jq expressions directly against fixture `config.json` files for all three input cases, which is the actual behavioral claim; Phase 4 does not depend on running `sapience-bootstrap` |

## Decisions

1. **Default, not force.** The merge site becomes
   `.hooks = (if .hooks == null then false else .hooks end)` and the mint literal becomes
   `hooks: false`. An explicit value of either polarity is preserved; only an absent key is
   defaulted. Grounds: the task's own title says "default ... to false" and its body says
   "preserve an explicit false" — both are default/preserve semantics, and unconditional forcing
   would break a future user-facing toggle without doing anything useful now. This answers the
   GOAL's "decide whether false is forced or only defaulted, and say why" explicitly.

2. **Never `//` for this field, independent of Decision 1.** The explicit-null test is the part
   that is not in question. If the force-vs-default branch were ever revisited, the replacement
   would be a flat `.hooks = false`, never a return to `//`.

3. **The detector runs BEFORE `claudeSettings`, not after** — a correction to
   `reports/01_sapience_hooks_opt_out.md` §3, which recommended
   `entryAfter [ "writeBoundary" "claudeSettings" ]`. Verified in
   `modules/home/core/dotfiles.nix`: `claudeSettings`'s three-way jq merge lists `hooks` in its
   `--argjson enforced` array and resets it from `config/claude/settings.json` on every switch.
   A guard ordered after that entry therefore inspects a file whose `hooks` key has already been
   replaced by this repository's declared set, so it can never observe an injection and would be
   structurally dead code that looks like a working check. The guard is declared
   `config.lib.dag.entryBefore [ "claudeSettings" ]` so it reads the live, pre-merge state.

4. **The activation invocation is loud but non-fatal; the hard-failing exit lives in the
   standalone script.** This follows from Decision 3 rather than contradicting the GOAL's "fails
   loudly": once the guard runs before the enforced-key merge, aborting the switch there would
   leave the injected hooks in place *and* prevent `claudeSettings` from stripping them, turning
   a self-healing switch into a manual repair. The detector is therefore one script with two
   invocation modes — a standalone/CI run that exits `1` on detection (the hard failure GOAL
   item (3) asks for, with no capacity to brick a switch), and a non-fatal activation call that
   prints an unmissable banner naming the offending entries and the remedy, after which the same
   switch's `claudeSettings` strips them. Detection and repair both happen in one switch, and
   the message is what tells the operator the Phase 1 fix has regressed.

5. **One script, two call sites, rather than an inline activation heredoc.** The detector is
   `scripts/check-sapience-hooks.sh`, referenced from Nix by path so activation and the
   standalone run share one implementation. This also brings it inside `flake.nix`'s `shellSrc`
   fileset, so `nix flake check`'s `shellcheck` covers it — an inline Nix string would be
   checked by nothing.

6. **Not wired into `scripts/pre-push-checks.sh`.** That script checks repository content; a
   live-machine-state probe there would block a push for a condition unrelated to the pushed
   commits. The standalone script is invocable by hand and by any future CI that wants it.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: phases 1, 2
and 3 all edit `modules/home/services/sapience.nix`, so they are serialized to avoid concurrent
edits to one file rather than because of a logical data dependency.

### Phase 1: Correct both `config.json` "hooks" write sites [COMPLETED]

**Goal**: `sapienceBootstrap` defaults `"hooks"` to `false` at both write sites and preserves an
explicit value of either polarity.

**Tasks**:

- [x] Locate the re-bootstrap merge site in `modules/home/services/sapience.nix` (inside
      `sapienceBootstrap`, in the `if [ -f "${configFile}" ]` branch). Its current jq program is
      `'.token = $token | .backend = $backend | .host = $host | .auto_approve = (.auto_approve // false) | .hooks = (.hooks // true)'`.
- [x] Replace that program's final clause with
      `.hooks = (if .hooks == null then false else .hooks end)`, leaving the `.token`,
      `.backend`, `.host` and `.auto_approve` clauses byte-identical.
- [x] Locate the first-run mint site (the `else` branch's `jq -n` object literal) and change
      `hooks: true` to `hooks: false`, leaving `auto_approve: false` and the three `$`-args
      untouched.
- [x] Add a comment at the merge site stating why `hooks` uses an explicit null test while the
      adjacent `auto_approve` keeps `//`: `//` returns its right-hand side for `false` as well
      as `null`, which would silently reset a deliberate `"hooks": false` opt-out; for
      `auto_approve` the default and the only value worth preserving are both `false`, so the
      distinction has no observable effect there today. Do not change the `auto_approve`
      expression.
- [x] Confirm by grep that no other expression anywhere in `modules/` writes `config.json`'s
      `hooks` key (expected: the two sites above only; `sapienceTokenRepair` writes `.token`,
      `sapienceApiKey` writes `.api_key`/`.api_key_env`).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly two expressions in `modules/home/services/sapience.nix` write
`config.json`'s `"hooks"` key, and no other file under `modules/` writes it at all. Confirm at
implementation time with `grep -rn 'hooks' modules/` and by checking that the resulting diff
touches exactly two jq programs plus one added comment; if a third write site appears, fix it to
the same semantics and note the divergence from this hypothesis in the phase record rather than
leaving it.

**Tier Justification**: `suite_selection_select modules/home/services/sapience.nix` returns
`__FULL_SWEEP__` — no shell test suite maps to this path — so the covering check is this
repository's own authoritative gate, `nix flake check`, whose `statix`, `deadnix`, `nixfmt` and
`home-eval` checks all read this module, together with a direct jq exercise of the changed
expressions.

**Files to modify**:

- `modules/home/services/sapience.nix` - merge-site jq program's `.hooks` clause, first-run mint
  literal, and one explanatory comment

**Verification**:

- `nix flake check` passes (this is the authoritative gate per `rules/nix.md`; it runs `statix`,
  `deadnix --fail`, `nixfmt --check`, `shellcheck` and the `home-eval` evaluation check).
- `git diff -- modules/home/services/sapience.nix` shows exactly the two jq programs changed
  plus the added comment, and no change to `.auto_approve`.
- Direct jq exercise of the merge expression against three fixture `config.json` files in the
  scratchpad, asserting all three outcomes:
  `{"hooks": false}` -> `false` (the preserve case the bug broke);
  `{}` (key absent) -> `false` (the new default);
  `{"hooks": true}` -> `true` (an explicit opt-in is preserved, proving default-not-force).
- `jq -n '<mint literal>'` yields an object whose `.hooks` is `false`.

---

### Phase 2: Add the vendor-hook-injection detector and wire it into activation [COMPLETED]

**Goal**: a single repo-tracked script detects any `~/.sapience` injection hook in
`~/.claude/settings.json`, exits non-zero standalone, and is invoked loudly but non-fatally at
activation *before* the enforced-key merge can hide the evidence.

**Tasks**:

- [x] Create `scripts/check-sapience-hooks.sh`. It reads `~/.claude/settings.json` (path
      overridable by a first positional argument, so the phase can test it against a fixture),
      flattens the command strings under `hooks.SessionStart`, `hooks.SessionEnd` and
      `hooks.Stop`, and reports every entry whose command contains `.sapience/mcp.py` **and** one
      of `--briefing-text`, `--receipt`, `--effect-line`.
- [x] Make the script's failure output name each offending event, the offending command string,
      and the remedy: remove the entry by hand, confirm `~/.sapience/config.json` holds
      `"hooks": false`, and re-run `home-manager switch`.
- [x] Give the script defined behavior on the edge cases: missing file, unparseable JSON, and a
      missing `hooks` key must all exit `0` with a short note (absence of the file is not an
      injection), and only a positive match exits `1`.
- [x] Add a `--quiet-ok` (or equivalent) mode that prints nothing on a clean result, for the
      activation call site, while the standalone call prints a one-line confirmation.
- [x] In `modules/home/services/sapience.nix`, add a `sapienceHooksGuard` entry to
      `home.activation`, declared `config.lib.dag.entryBefore [ "claudeSettings" ]` per Decision
      3, which runs the script via a Nix path reference (so one implementation serves both call
      sites) and is non-fatal per Decision 4 — a detection prints the script's banner and
      activation continues, so the same switch's `claudeSettings` still strips the injection.
- [x] Guard the activation entry with the `[[ -v DRY_RUN ]]` / `$DRY_RUN_CMD` convention the
      sibling entries in this file already use, printing a "Would check ..." line under dry run.
- [x] Add a comment on the new entry recording *why* it is ordered before `claudeSettings`: that
      entry resets `hooks` as an enforced key, so a guard running after it would inspect an
      already-cleaned file and could never fire.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase adds exactly one new file and one new `home.activation` entry,
and changes no existing activation entry — in particular `modules/home/core/dotfiles.nix` is not
edited, only ordered against. Confirm with `git status --short` (expect one untracked script and
one modified `.nix` file) and `git diff --stat`; if ordering turns out to require a change in
`dotfiles.nix`, stop and record that as a scope expansion rather than editing the enforced-key
list silently.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both
`scripts/check-sapience-hooks.sh` and `modules/home/services/sapience.nix`, so no shell suite
maps to either; the covering check is `nix flake check`, which lints the new script via its
`shellcheck` check (`scripts/*.sh` is inside `flake.nix`'s `shellSrc` fileset) and evaluates the
new activation entry via `statix`/`deadnix`/`nixfmt`/`home-eval`, plus the fixture-based positive
and negative detector runs below.

**Files to modify**:

- `scripts/check-sapience-hooks.sh` - new detector script; exits 1 on a positive match
- `modules/home/services/sapience.nix` - new `sapienceHooksGuard` activation entry ordered
  `entryBefore [ "claudeSettings" ]`, with its ordering rationale comment

**Verification**:

- `nix flake check` passes (exit status checked, not just its output read), including the
  `shellcheck` check that now covers the new script because `scripts/*.sh` is inside
  `flake.nix`'s `shellSrc` fileset. `nix flake check` is this repository's sanctioned entry point
  for shellcheck; do not substitute a bare `shellcheck` invocation for it.
- Negative case: run the script against the real `~/.claude/settings.json` (whose `SessionStart`
  today carries an inhibitor, `lean-lsp-register-project.sh` and
  `sapience-mcp-register-project.sh`, none referencing `.sapience/mcp.py`) and confirm exit `0`
  with no finding — this is the false-positive check against the legitimate registration hook.
- Positive case: build a fixture settings file in the scratchpad carrying the three known vendor
  entries (`python3 ~/.sapience/mcp.py --briefing-text` under `SessionStart`, `--receipt` under
  `SessionEnd`, `--effect-line` under `Stop`), run the script against it, and confirm exit `1`
  with all three entries named.
- Edge cases: a missing path, a file containing invalid JSON, and a valid file with no `hooks`
  key each exit `0`.
- `nix eval` (or the `home-eval` check inside `nix flake check`) confirms the activation DAG
  resolves with the new entry ordered before `claudeSettings` — no cycle, no unknown-entry error.

---

### Phase 3: Document the resulting three-layer design [NOT STARTED]

**Goal**: `docs/sapience.md` and the `sapience.nix` header comment state what the machine
actually does, replacing the per-repository claim the dispatch found to be contradicted.

**Tasks**:

- [ ] Extend `docs/sapience.md`'s `### Why the hooks live in the repo` section (or add a
      subsection immediately after it) describing the three layers and the distinct job of each:
      (1) `~/.sapience/config.json`'s `"hooks": false` stops the vendor updater's `wire_hooks()`
      from ever writing its machine-wide hooks into `~/.claude/settings.json`, and stops
      `cli_auto_on_plan`'s auto-on probe; (2) `claudeSettings`'s enforced `hooks` key reverts
      anything that slips through, but only at the *next* switch, so it is a backstop and not a
      preventative; (3) the new `sapienceHooksGuard` reports an injection that happened since the
      last switch, which is why it is ordered before layer (2) rather than after it.
- [ ] State in the same passage what `"hooks": false` does **not** do: it has no effect on the
      per-repository hooks the sapience extension merges into a loaded repository's own
      `settings.local.json`, because `mcp.py`'s `--briefing-text`/`--receipt`/`--effect-line`
      entry points and `sapience_cli.py`'s `hook`/`answer` dispatcher consult `TOKEN` presence,
      `folder_allowed(cwd)` and per-session state — never `config.json`'s `hooks` key. This is
      the doc record of GOAL item (2).
- [ ] State the default/preserve semantics (Decision 1) and that `sapience-bootstrap` therefore
      never resets an explicit value in either direction.
- [ ] Add the standalone detector invocation (`bash scripts/check-sapience-hooks.sh`) to the doc
      as the hand-run check, noting that activation runs the same script non-fatally.
- [ ] Update `modules/home/services/sapience.nix`'s header comment block: the existing
      per-repository-design paragraph gains a pointer to the `"hooks": false` opt-out and to
      `sapienceHooksGuard`, parallel to how that block already explains the enforced-key
      reasoning. Keep it to the one-or-two-line pointer style the surrounding comments use; the
      full narrative belongs in `docs/sapience.md`.
- [ ] State the current design only, with no draft-history or supersession framing, per
      `rules/no-record-versioning-in-deliverables.md`, and cite no task numbers, per
      `rules/no-task-references-in-deliverables.md` — both files are outside `specs/**`.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: the doc change is additive to one existing section of `docs/sapience.md`
and needs no edit elsewhere in that file; the `sapience.nix` change is confined to the header
comment block and touches no code. Confirm with `git diff -- docs/sapience.md
modules/home/services/sapience.nix` showing additions inside the one named section and inside
the comment block only; if the `## Module options` table or another passage also asserts the
contradicted claim, extend the fix there and record the wider footprint.

**Tier Justification**: every hunk in this phase lies inside markdown prose or a Nix `#` comment
with zero evaluation surface, so the `prose` tier's diff read-through is the covering check,
backed by `nix flake check`'s `nixfmt --check` for the comment block's formatting;
`suite_selection_select` returns `__FULL_SWEEP__` for both paths, so no shell suite covers them
and none is claimed.

**Files to modify**:

- `docs/sapience.md` - extend `### Why the hooks live in the repo` with the three-layer design,
  the `"hooks": false` scope boundary, and the standalone detector invocation
- `modules/home/services/sapience.nix` - header comment pointer to the opt-out and the new guard

**Verification**:

- Diff read-through confirming every changed hunk in `docs/sapience.md` is prose and every
  changed hunk in `sapience.nix` is inside the `#` comment block — no code line touched.
- `nix flake check` still passes (`nixfmt --check` covers the comment block).
- `grep -n 'hooks' docs/sapience.md` shows the new passage naming `config.json`'s `"hooks"` key,
  which the file does not mention today.
- No version-history or supersession phrasing and no task-number reference appears in either
  changed file.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.dotfiles`
  passes the task-reference lint over the changed deliverables (gate 3 is deliberately not
  selected: doc-lint only checks the agent-system source store, which this phase does not touch,
  and selecting it would make every selected gate SKIP).

---

### Phase 4: Rebuild, force a vendor update, and confirm no hook returns [NOT STARTED]

**Goal**: the fix holds against the real machine — an actual rebuild followed by a forced vendor
update leaves `~/.claude/settings.json` free of any `~/.sapience` injection hook and
`~/.sapience/config.json` still holding `"hooks": false`.

**Tasks**:

- [ ] Back up both live files to timestamped copies before touching anything:
      `~/.claude/settings.json` and `~/.sapience/config.json` (same convention as the
      `.bak-*` copies the 2026-11-14 manual fix left).
- [ ] Record the before-state: `jq '.hooks' ~/.sapience/config.json` (expect `false`) and the
      flattened `hooks.SessionStart`/`SessionEnd`/`Stop` command strings from
      `~/.claude/settings.json`.
- [ ] Rebuild: `bash scripts/update.sh`, or the explicit pair it wraps
      (`sudo nixos-rebuild switch --flake .#<host>` and
      `home-manager switch --flake .#benjamin`) if a narrower run is preferred. Confirm the new
      `sapienceHooksGuard` entry ran and reported nothing.
- [ ] Confirm the rebuild did not reset the opt-out: `jq '.hooks' ~/.sapience/config.json` is
      still `false`. (No activation entry writes this key, so this is a regression check on the
      whole module, not on `sapienceBootstrap` alone.)
- [ ] Force the vendor updater: `python3 ~/.sapience/sapience_upkeep.py --update`. Capture its
      output and confirm it reports leaving the hooks alone (the `hooks_opted_out()` branch)
      rather than wiring them.
- [ ] Re-check `~/.claude/settings.json` and confirm no entry under `hooks.SessionStart`,
      `hooks.SessionEnd` or `hooks.Stop` references `.sapience/mcp.py` with any of
      `--briefing-text`, `--receipt`, `--effect-line`.
- [ ] Run `bash scripts/check-sapience-hooks.sh` standalone and confirm exit `0` against the real
      post-update file — the detector agreeing with the manual inspection above.
- [ ] Re-attest GOAL item (2) empirically: confirm that in a repository that loads the sapience
      extension, the per-repository hooks are still present in that repository's own
      `.claude/settings.local.json` and unaffected by `"hooks": false`. Inspect the merged file;
      do not edit the extension or its source store.
- [ ] Run the full gate set and record the result.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: this phase changes no tracked file — it is an operational verification
phase whose only writes are the two timestamped backups outside the repository. Confirm with
`git status --short` showing no new or modified tracked file attributable to this phase; if a
defect surfaces that requires a source change, treat that as a return to the owning phase rather
than an edit made here.

**Files to modify**:

- none planned (operational verification only; the two backups are written outside the
  repository and are not tracked)

**Verification**:

- The complete gate set for this repository, run and observed green rather than assumed:
  `nix flake check` (the authoritative gate per `rules/nix.md` — `statix`, `deadnix --fail`,
  `nixfmt --check`, `shellcheck`, and the `home-eval` standalone-home-manager evaluation check),
  plus `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` for the agent-system
  gates over the `specs/**` artifacts this task produced.
- `jq '.hooks' ~/.sapience/config.json` is `false` both after the rebuild and after the forced
  update.
- `python3 ~/.sapience/sapience_upkeep.py --update` output shows the opt-out branch taken.
- `bash scripts/check-sapience-hooks.sh` exits `0` against the live post-update
  `~/.claude/settings.json`.
- Manual `jq` inspection of all three hook events in `~/.claude/settings.json` finds no
  `.sapience/mcp.py` command carrying any of the three flags.
- An extension-loading repository's own `.claude/settings.local.json` still carries the
  per-repository sapience hooks, confirming `"hooks": false` did not disable them.

---

## Testing & Validation

- [ ] `nix flake check` passes at the close of every phase that changes a tracked file (1, 2, 3)
      and in Phase 4's full gate run.
- [ ] The merge expression preserves `false`, preserves `true`, and defaults an absent key to
      `false` — all three cases exercised against fixtures, not reasoned about.
- [ ] The first-run mint literal yields `.hooks == false`.
- [ ] `scripts/check-sapience-hooks.sh` exits `1` with all three entries named on the synthetic
      injection fixture, and `0` on the real live file, a missing file, invalid JSON, and a file
      with no `hooks` key.
- [ ] The activation DAG resolves with `sapienceHooksGuard` ordered before `claudeSettings`.
- [ ] A real `home-manager switch` followed by `python3 ~/.sapience/sapience_upkeep.py --update`
      leaves no user-level `~/.sapience` hook in `~/.claude/settings.json`.
- [ ] `docs/sapience.md` and the `sapience.nix` header no longer assert a per-repository-only
      design without naming the `config.json` opt-out and the guard.
- [ ] No task-number reference and no version-history phrasing in `docs/sapience.md` or
      `modules/home/services/sapience.nix`.

## Artifacts & Outputs

- `modules/home/services/sapience.nix` - both `config.json` `"hooks"` write sites corrected to
  default-not-force semantics; new `sapienceHooksGuard` activation entry; header comment updated.
- `scripts/check-sapience-hooks.sh` - new detector, exit `1` on a positive match, covered by
  `nix flake check`'s `shellcheck`.
- `docs/sapience.md` - the three-layer hook design, the `"hooks": false` scope boundary, and the
  standalone detector invocation.
- `specs/142_sapience_hooks_opt_out_default/plans/01_sapience-hooks-opt-out.md` - this plan.
- Phase 4 evidence: the captured `sapience_upkeep.py --update` output and the before/after
  `~/.claude/settings.json` hook inventories, recorded in the implementation summary.

## Rollback/Contingency

Phases 1-3 are small, additive source edits in a git working tree, each closed by its own commit,
so the ordinary remedy is to fix forward or to revert the specific commit — no working-tree
discard is needed and none should be reached for.

If a rollback that would discard uncommitted work becomes genuinely necessary, take a snapshot
first per `context/contracts/recovery.md`'s rollback rung (including its out-of-scope override
flag for a deliberate whole-tree case), then perform the revert; never discard uncommitted
changes to reach a passing build.

Machine-state contingency for Phase 4: the two timestamped backups taken at the start of that
phase restore `~/.claude/settings.json` and `~/.sapience/config.json` by `cp`. If the new
`sapienceHooksGuard` entry ever misbehaves badly enough to disrupt activation, it is a single
self-contained `home.activation` attribute and can be removed from
`modules/home/services/sapience.nix` and the switch re-run; because the entry is non-fatal by
Decision 4, this should not arise. If the vendor updater re-adds hooks despite `"hooks": false`,
that is a finding, not a rollback trigger: record it, leave the opt-out in place, and let
`claudeSettings`'s enforced key keep stripping the entries at each switch while the cause is
investigated.

# Research Report: Task #81 — NixOS Dotfiles Repository Reorganization Design

**Task**: reorganize_nixos_dotfiles_repository_design
**Date**: 2026-07-04
**Mode**: Team Research (4 teammates)

## Summary

- The repo's existing top-level shape (`hosts/`, `modules/`, `overlays/`, `packages/`, `lib/`,
  `config/`) already matches what three independent, well-regarded personal Nix configs converge
  on (Misterio77, mitchellh, hlissner) — this is a **convention-enforcement and cleanup task, not
  a structural rewrite or framework migration**. Do not adopt flake-parts or snowfall-lib.
- Target layout: thin root entrypoints (`configuration.nix`, `home.nix` stay at root, unchanged
  location) + new `modules/{system,home}/default.nix` aggregators + a `scripts/` dir for root
  shell scripts + explicit per-host wiring for optional modules, replacing today's
  half-built "optional/ in name only" convention.
- Migration philosophy is **incremental, not big-bang**: a strictly ordered queue of small,
  independently-verifiable subtasks (matching this repo's actual operating cadence), tiered by
  strategic value rather than pure risk-ordering — the module-convention/per-host-opt-in fix
  (options pattern + real toggling) is the highest-leverage single change because it currently
  blocks task 77 from being cheap, not a mid-list cosmetic item.
- The seed report is factually solid but the Critic found two claims needing correction
  (`packages/test-mcphub.sh` is actively doc-referenced, not dead cruft; `specs/tmp/` must
  continue to exist on disk for `skill-base.sh`'s atomic-write pattern) and one critical
  unaddressed risk that changes how *every* subtask must be executed: `flake.nix`'s `root = self`
  means `nix flake check`/`nixos-rebuild build` only see **git-tracked** content, so every
  move/create/delete subtask needs a `git add <path>` step before verification, not after.
- Recommended subtask count: **10** (the seed/Teammate A's 9, plus one new CI-gate subtask),
  restructured into three value tiers rather than one flat risk-ordered sequence.

## Key Findings

### Recommended Target Directory Layout (synthesized)

Teammate A's proposed tree is adopted as the design baseline; Teammate B's prior-art survey
independently confirms every major shape decision in it (same skeleton across Misterio77,
mitchellh, hlissner). Corrections from the Critic (C) are folded in inline.

```
.
├── flake.nix / flake.lock
├── configuration.nix          # thin: imports ./modules/system + system.stateVersion (KEPT AT ROOT)
├── home.nix                   # thin: imports ./modules/home + home.stateVersion + username (KEPT AT ROOT)
├── .gitignore  .sops.yaml  README.md
│
├── scripts/                   # NEW — root shell scripts relocated
│   ├── install.sh
│   ├── update.sh
│   └── build-usb-installer.sh
│                               (test-sasl.sh deleted, not moved)
│
├── .github/workflows/         # NEW — nix flake check CI gate (Teammate D's new candidate)
│
├── lib/
│   └── mkHost.nix             # unchanged internals; per-host wiring stays explicit (see below)
│
├── hosts/
│   ├── README.md               # rewritten: current mkHost pattern (drop obsolete inline-nixosSystem example)
│   ├── nandi/{hardware-configuration.nix, default.nix?}  # default.nix only if nandi needs an opt-in module
│   ├── hamsa/{hardware-configuration.nix}                # no default.nix needed unless it opts into something
│   ├── garuda/{hardware-configuration.nix}                # empty-body default.nix DELETED; re-added with real
│   │                                                       #   content + explicit flake.nix wiring only when needed
│   ├── usb-installer/{hardware-configuration.nix?, default.nix}   # unchanged content
│   └── iso/{default.nix}       # OPTIONAL/stretch — the ~60-line inline block extracted from flake.nix,
│                                #   only if the mkHost-unification stretch item is taken; scope to wiring
│                                #   only, do not touch task-68's broken zfs-kernel state
│
├── modules/
│   ├── README.md                # NEW — system/home split, aggregator convention, optional/ meaning
│   ├── system/
│   │   ├── default.nix          # NEW aggregator — replaces configuration.nix's flat list; always-on modules only
│   │   ├── boot.nix … shell.nix  # unchanged
│   │   └── optional/
│   │       └── discord-bot.nix  # converted to options + mkIf; NOT imported by default.nix;
│   │                             #   opted into explicitly per-host (see Conflicts Resolved #2)
│   └── home/
│       ├── default.nix          # NEW aggregator — replaces home.nix's flat list
│       ├── core/{git,neovim,xdg}.nix
│       │   └── dotfiles.nix     # renamed from shell.nix (deploys config/, not shell config);
│       │                         #   consider splitting deployment by owning module over time (see B, finding 6)
│       ├── desktop/*.nix        # unchanged
│       ├── email/
│       │   ├── agent-tools/     # split from the single 761-line file (exact boundaries: finalize during planning)
│       │   │   ├── default.nix
│       │   │   └── {per-wrapper}.nix
│       │   └── {mbsync,aerc,notmuch,protonmail}.nix
│       ├── packages/
│       │   ├── misc.nix         # merged fonts.nix + lean-math.nix + ai-tools.nix
│       │   └── {dev-tools,media-dictation,email-tools,python}.nix
│       ├── scripts/ + services/ # memory-monitor.nix + memory-services.nix co-located/renamed to match
│       └── misc.nix
│
├── overlays/                    # unchanged — already clean
├── packages/                    # neovim.nix + test-mcphub.sh removed IN TANDEM with their doc
│                                 #   references (docs/packages.md:244, docs/applications.md:26,
│                                 #   packages/README.md:260-277) — see Conflicts Resolved / Critic note
├── config/                      # unchanged location and NAME (rename explicitly rejected)
│   └── README.md                # expanded: document 3 deployment mechanisms + config/ vs Nix `config`
│                                 #   argument shadowing + config/claude/ vs .claude/ naming collision (Critic C.3)
├── secrets/                     # unchanged
├── wallpapers/                  # unchanged location (assets/ deferred, not adopted now); 5 cruft files removed
├── docs/                        # README.md index completed; hosts/discord-bot docs updated
├── opencode-discord-bot/
│   └── pyproject.toml           # NEW near-term step — packaged via buildPythonApplication;
│                                 #   extraction to its own repo/flake input is a later, separate
│                                 #   strategic follow-on (see Conflicts Resolved #1)
└── specs/                       # untouched by this task (agent-orchestration tree, out of scope — Critic C.3)
```

**Where A and B converge** (high confidence, adopt as-is): keep `lib/mkHost.nix` hand-rolled and
reject flake-parts/snowfall-lib entirely; scope the options pattern to optional/toggleable
modules only, not a blanket 43-file rewrite; reject the `config/` → `dotfiles/` rename; treat
`assets/` as a deferred/future consideration, not an action for this task; centralize secrets as-is
(no per-host colocation).

**Where a call had to be made** (A and B differ): the exact *mechanism* for per-host optional
modules (auto-discovery via `pathExists` in `lib/mkHost.nix` vs. explicit per-host wiring in
`flake.nix`) — resolved in favor of explicit wiring; see Conflicts Resolved #2.

### Design-Question Decisions (synthesized)

| Question | Resolved recommendation | Support |
|---|---|---|
| Options pattern vs plain config sets | Scoped adoption only: options + `mkIf` required for modules a host must selectively enable (starting with `discord-bot.nix`); the other ~40 always-on modules and host-glue files remain plain config sets. Amend `.claude/rules/nix.md` to say so explicitly rather than mandating a 43-file rewrite. | A (recommendation), B finding 7 (Misterio77/hlissner precedent: reusable/toggleable modules use options, host-glue doesn't) — full convergence |
| Per-host optional-module wiring mechanism | Require an **explicit** (possibly one-line) `hosts/<name>/default.nix` per host that opts into something, wired via `extraModules` in `flake.nix` — not a generic `pathExists`/`readDir` auto-import layer. | B (3 converging prior-art repos; the one repo using auto-discovery explicitly warns against over-applying it) — overrides A's narrower `pathExists`-guard proposal; see Conflicts Resolved #2 |
| `configuration.nix` / `home.nix` location | Keep at repo root. Do not move under `hosts/common/`. | A (5+ call sites reference them directly; genuinely repo-level, not per-host) — also sidesteps Critic's task-69-sequencing concern entirely, since no relocation is happening |
| `modules/{system,home}/default.nix` aggregators | Introduce both; free under Nix directory-import convention; co-locates the module manifest with the modules themselves. | A — no counter-evidence from B/C/D |
| `scripts/` for root shell scripts | Yes, for `install.sh`/`update.sh`/`build-usb-installer.sh`; update direct doc references in the same subtask. `test-sasl.sh` deleted, not moved. | A, corroborated by B finding 8 (hlissner's `bin/`) |
| `assets/` for wallpapers | Reject for now — clean the 5 scaffolding files, keep `wallpapers/`. Revisit only when a second asset class appears. | A (only one real asset today) and B finding 8 (hlissner precedent supports the pattern "if it accumulates," not "adopt now") — these converge, not conflict |
| `config/` rename | Reject. Document the Nix-`config`-argument shadowing (and the separate `.claude/` vs `config/claude/` naming collision Critic flagged) in `config/README.md` instead. | A, D (explicitly ranked lowest priority/optional) |
| Discord-bot packaging destination | Near-term: package in-tree via `buildPythonApplication` under `packages/` (concrete, low-risk, immediately fixes the reproducibility hazard). Treat "extract to its own repo as a flake input" as a later strategic follow-on once the bot's interface stabilizes, mirroring the email-extension precedent. | A, B (unanimous prior-art support for in-tree packaging of a still-evolving, same-repo tool) primary; D's extract-to-repo elevated to a documented future step, not the immediate action — see Conflicts Resolved #1 |
| flake-parts / snowfall-lib adoption | Reject both, decisively. | B — three independent well-regarded repos all hand-roll instead; no counter-evidence anywhere |
| Task 69 (dual home-manager) resolution | Resolve inside this reorg's doc-sync work as a documentation-only closure ("Option A retained, documented") rather than spawning it as fully separate work — the underlying bug is already fixed as of task 66; only a judgment call remains. | D — not addressed by A/B/C in depth; adopted as-is |
| Raw-dotfile deployment structure (`shell.nix`→`dotfiles.nix`) | Rename now (per A); treat "split deployment out to each owning module" (per B finding 6) as a direction for the *next* iteration of `home/core/`, not mandatory within this task's granularity-pass subtask. | A (concrete, scoped) + B (validates the direction, doesn't mandate the full split now) |

### Recommended Subtask Decomposition (ordered)

Base: Teammate A's 9-subtask refinement of the seed's list. Restructured into Teammate D's
three value tiers (strategic leverage, not just risk/independence), with Critic corrections
folded into each subtask's scope, and one new subtask (CI gate) added.

**Cross-cutting requirements applying to every subtask below** (Critic C.1, C.3, E; Teammate D
finding 4):
- **Stage-before-verify protocol**: `git add <specific paths>` (never `-A`) immediately before
  running the nix verification harness on any subtask that moves/creates/deletes files —
  `flake.nix`'s `root = self` means `nix flake check`/`nixos-rebuild build` only see git-tracked
  content; an unstaged move looks like a stale-success or a confusing "file not found" failure.
- **Scope boundary**: task 81 is scoped to the Nix-managed tree only (`modules/`, `hosts/`,
  `config/`, `overlays/`, `lib/`, `packages/`, `secrets/`, root `*.nix`) — `.claude/`, `.memory/`,
  `.opencode/`, `specs/` are explicitly out of scope and untouched.
- **This is a queue of small, independently-landable subtasks — never a single reorg PR.**

| # | Tier | Subtask | Depends on | Verification |
|---|---|---|---|---|
| 1 | 0 | **Dead code removal**: `home-modules/` (+3 stale comment refs), `modules/opencode.nix`, `packages/neovim.nix` (NOT `modules/home/core/neovim.nix` — easy to conflate, confirmed different files), `test-sasl.sh`, `test-update.md`, root `TODO.md`, wallpapers cruft (5 files). **`packages/test-mcphub.sh` removal widened to also patch `docs/packages.md:244`, `docs/applications.md:26`, `packages/README.md:260-277`** in the same subtask (Critic correction — it is doc-referenced, not orphaned). Drop the `config/rclone.conf` "verify" step — already untracked/resolved, nothing to do. | none | `git status` shows only deletions + the 3 doc edits; harness green (none of these files are imported anywhere). |
| 2 | 0 | **Git hygiene**: untrack `specs/tmp/*` contents and extend `.gitignore` — **but the `specs/tmp/` directory itself must continue to exist on disk** (Critic correction: `skill-base.sh`'s atomic state-write depends on it). Note `specs/tmp/lit.md` is an unrelated mbsync troubleshooting note, not `--lit` tooling — no decoupling work needed. Fix `update.sh`'s mangled shebang and stray `complete\!`. | none | `git status --porcelain` clean on `specs/tmp/` contents; directory still present; `./update.sh` still executes. |
| 3 | 0 | **NEW — CI gate**: add a `nix flake check` GitHub Actions workflow (repo already has a GitHub remote, free for personal repos) and/or a pre-commit hook. Closes the exact gap that let tasks 67/68/69's underlying issues go undetected until a full rebuild; cheap (one workflow file), high ROI. | none | Workflow runs green on a trivial PR/push; local `nix flake check` still passes. |
| 4 | 0 | **Root shell scripts → `scripts/`**: move `install.sh`, `update.sh`, `build-usb-installer.sh`; update references in root `README.md`, `docs/testing.md`, `docs/usb-installer.md` in the same subtask. | none | `grep` shows only `scripts/`-prefixed paths in docs; `./scripts/update.sh` runs. |
| 5 | 1 (strategic core — sequence before task 77) | **Module convention + aggregators + per-host discord-bot opt-in**: amend `.claude/rules/nix.md` to scope the options-pattern requirement to optional/host-toggled modules; introduce `modules/system/default.nix` + `modules/home/default.nix` aggregators; convert `discord-bot.nix` to `options.services.discordBot.enable` + `mkIf`; remove it from the shared aggregator; wire it explicitly per-host (e.g. `hosts/nandi/default.nix` sets `services.discordBot.enable = true`, referenced via `extraModules` in `flake.nix` — explicit, not auto-discovered, per Conflicts Resolved #2); delete garuda's empty-body `default.nix` now, re-add only with real content when needed; update `docs/discord-bot.md:25`. Fold task 69's Option A/B/C documentation-only resolution in here or into subtask 10. **Explicitly a behavior-changing subtask** (a host that silently got the Discord bot stops getting it) — not covered by the standard build-only inertness harness. | none (self-contained; no longer gated on subtask 3-as-numbered in the seed, since hosts/ standardization is folded in here) | Full build harness (`nix flake check` + build nandi/hamsa/garuda + HM activation) **plus** a runtime check: `nixos-rebuild switch` + `systemctl status`/`journalctl` confirming hamsa's closure no longer includes the Discord bot's Python closure, and nandi's does (Critic correction: build-only diff cannot detect this class of change). |
| 6 | 2 | **hosts/ structural cleanup**: rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example to the current `mkHost` pattern (folds into subtask 5's doc edit); extract the ISO inline config block to `hosts/iso/default.nix` **only** as an explicitly optional stretch step — scope strictly to wiring, do not touch task 68's broken zfs-kernel state, and do not use the task-66 build-diff harness for iso/usb-installer (excluded per the seed's own verification baseline). | 5 | `nix flake check`; iso/usb-installer build state must remain exactly as (un)buildable as before. |
| 7 | 2 | **Module granularity pass**: split `agent-tools.nix` (761 lines) into `email/agent-tools/{default.nix, per-wrapper}.nix` — exact split boundaries finalized during planning by reading the full file, not prescribed here; merge tiny fragments (`fonts.nix`/`lean-math.nix`/`ai-tools.nix` → `packages/misc.nix`); co-locate memory scripts+services; rename `home/core/shell.nix` → `dotfiles.nix`. New files register in the subtask-5 aggregators rather than needing a second hand-edit. | 5 | `nix build .#homeConfigurations.benjamin.activationPackage`; `diff-closures` empty (pure structural refactor). |
| 8 | 2 | **opencode-discord-bot packaging**: add `pyproject.toml`, convert to `buildPythonApplication` under `packages/`, point the systemd unit's `ExecStart`/`PYTHONPATH` at the built store path instead of `~/.dotfiles/opencode-discord-bot`, fix the `discord-bot.nix:20` comment path typo, resolve the untracked-`.opencode/`-vs-tracked-`opencode.json` inconsistency. Document "extract to own repo as a flake input" as the next strategic step once the bot's interface stabilizes (mirrors the email-extension precedent already in this repo) — not required by this subtask. **Explicitly behavior-changing** (closure gains the packaged bot). | 5 | Build harness + explicit runtime check (`systemctl cat`/dry-run showing a store path, not a `$HOME` path); document expected closure delta as intentional. |
| 9 | 2 (optional/low priority) | **config/ deployment clarity**: document (not rename) the three deployment mechanisms in `config/README.md`; note the `config/` vs Nix-`config`-argument shadowing and the separate `.claude/` vs `config/claude/` naming collision; cross-reference from `dotfiles.nix`'s header. Explicitly flagged as optional/do-only-if-a-slow-week-presents-itself. | 7 | Doc-only; stale-reference grep. |
| 10 | Final (gated on all above) | **Documentation sync**: root README Module Map + package list (drop `neovim.nix`, add `piper-bin.nix`/`piper-voices.nix`, remove stale "(planned: task 66 ...)" annotations); `docs/README.md` index completion (`dual-home-manager.md`, `email-workflow.md`, `how-to-add-package.md`, `how-to-add-service.md`, `gnome-settings.md`, `video-editing.md`); new `modules/README.md`; one-line "checked, no action needed" notes for `flake.lock` health and `stateVersion` values (Critic: both verified fine, don't let a later pass rediscover them as false positives); resolve task 69's documentation closure here if not done in subtask 5. Establish a "docs verified against source, not fixed once" convention that task 78 can cite (not be merged with). | 1-9 | Full harness once more as final regression check; manual README-vs-`find` drift check. |

**Explicitly rejected from this task's scope**: `profiles/` layering (only 2-3 near-identical
hosts today — revisit if a 4th, role-divergent host appears); per-host secrets colocation
(current single-recipient/single-rule setup is simpler as-is); a generic `readDir`/`mapModules`
auto-import library (more machinery than 4 hosts justify).

### Migration Philosophy

Incremental, strictly ordered, independently-verifiable subtasks — never a single reorg PR or
one master plan. This is both what the repo's own operating history already does (task 66's
phased, closure-diff-gated refactor; the niri work split into four sequential tasks 74-77 off
one seed) and what Teammate D's tiering argues for explicitly: a "systematic reorganization"
framing invites collapsing this into one big-bang phase list, and the design output must say
plainly that it should not be collapsed that way.

Two subtasks (5 and 8, module-convention/opt-in and discord-bot packaging) are **intentionally
behavior-changing** and must be verified at the runtime/activation level (`switch` +
`systemctl`/`journalctl`), not just the build-level `nix store diff-closures` harness the seed
proposed uniformly — this is a hard correction from the Critic, not a stylistic suggestion,
since build-only verification cannot observe systemd runtime path literals
(`WorkingDirectory`/`PYTHONPATH`) at all. Every other subtask remains held to strict closure
equivalence (inertness).

The CI gate (new subtask 3) is the design's answer to "no automated backstop exists across a
9-10 subtask, multi-session reorg" — it is scoped as a first-class Tier-0 subtask specifically
because three of the repo's last ~15 tasks (67 R-env/ICU, 68 zfs-kernel, 69 lectic specialArgs)
are exactly the class of drift a `nix flake check` gate would catch immediately rather than
during an unrelated task's audit.

## Synthesis

### Conflicts Resolved

1. **opencode-discord-bot packaging destination.** Teammates A and B recommend packaging in-tree
   via `buildPythonApplication` under `packages/`, citing unanimous positive prior-art support
   (no surveyed repo runs a service via `PYTHONPATH` into a working tree; extraction to a
   separate flake input is what *mature, reusable* tools graduate to). Teammate D recommends
   extracting to its own repo now, citing the repo's own precedent (the email extension is
   already split this way) and the reproducibility hazard of the current `PYTHONPATH` approach.
   **Resolution**: adopt in-tree `buildPythonApplication` as the concrete, near-term subtask
   (fixes the reproducibility hazard immediately, lowest execution risk, matches the "still
   evolving, same-repo, no test harness yet" profile B's evidence describes), and record
   extraction-to-own-repo as the documented strategic follow-on once the bot's interface
   stabilizes — not a requirement of this task. This preserves both teammates' evidence: B's
   "what a not-yet-mature tool needs now" and D's "what a mature tool graduates to."
2. **Per-host optional-module wiring mechanism.** Teammate A proposes a `builtins.pathExists`
   guard inside `lib/mkHost.nix` that auto-imports `hosts/<name>/default.nix` if present (a
   narrow, one-file form of auto-discovery). Teammate B's live prior-art survey found that
   neither Misterio77 nor mitchellh (the two most comparable single-maintainer, multi-host repos)
   use any auto-import mechanism — both hand-list `extraModules`/imports explicitly per host —
   and that hlissner, the one surveyed repo that *does* build a generic auto-import helper,
   explicitly warns in his own code comments against depending on this class of implicit
   convention for exactly the reasons this task is trying to eliminate elsewhere (undocumented
   conventions, silent breakage). **Resolution**: adopt explicit per-host wiring in `flake.nix`
   (B's recommendation) over A's `pathExists` guard — three converging real-world examples plus
   a directly-cited caution from the fourth outweighs an internally-reasoned proposal with no
   external corroboration. This also means garuda's fix is to give it *real* content plus
   explicit wiring (matching Misterio77/mitchellh), not to remove its `flake.nix` wiring in favor
   of implicit discovery.
3. **Sequencing axis.** The seed and Teammate A order subtasks by risk-and-independence alone
   (near-zero-risk deletions first, design-decision items last). Teammate D argues this is the
   right axis for *within-tier* sequencing but the wrong axis for *priority* — it buries the
   options-pattern/per-host-opt-in fix (originally seed item 7) at position 7-of-9 when it is
   actually the one piece of debt actively blocking task 77 from being cheap. **Resolution**:
   adopt D's three-tier restructuring (Tier 0 near-zero-risk hygiene, Tier 1 the strategic
   opt-in/convention core sequenced before task 77's dispatch, Tier 2 lower-value/cosmetic work
   that can slip) as the sequencing frame, while keeping A's per-subtask content, scope, and
   verification detail as the substance within each tier.
4. **Documentation-sync ordering.** The seed originally scheduled "Documentation sync" as item 3,
   before the structural changes (hosts standardization, module granularity, module convention)
   that would change the very tree it documents. Teammate A identified this as a sequencing bug
   and moved it to last; Teammate D independently reinforces the same conclusion (doc sync must
   be gated on task 77/78 convention adoption too). **Resolution**: doc sync is the final subtask
   (10), unanimous across A and D, no dissent found.

### Coverage Gaps

The Critic (Teammate C) surfaced several gaps the seed did not address at all, none of which are
contradicted by A, B, or D — they are additive and must be carried into the design/planning
phase:

1. **`self`/store-path staging risk** — `flake.nix`'s `root = self` means every reorg subtask
   that moves/creates/deletes files must `git add` the specific paths before running the nix
   verification harness, or the harness silently checks the stale tracked layout. No subtask in
   the seed's or A's decomposition mentioned this; it is now a cross-cutting requirement (see
   Recommended Subtask Decomposition, cross-cutting requirements).
2. **Build-only verification misses runtime-only breakage** — `discord-bot.nix`'s
   `WorkingDirectory`/`PYTHONPATH` are runtime string literals invisible to `nix store
   diff-closures`. Subtasks 5 and 8 need an explicit `switch` + `systemctl`/`journalctl` check,
   not just a build-level harness. Folded into those subtasks above.
3. **Scope boundary for `.claude/`/`.memory/`/`.opencode/`/`specs/` vs. the Nix-managed tree was
   never stated.** Now explicit: task 81 is scoped to the Nix-managed tree only. Also flag the
   `.claude/` (agent system) vs. `config/claude/` (deployed dotfiles) naming collision so it isn't
   conflated during the reorg conversation or in subtask 9's documentation.
4. **`config/claude/` activation force-overwrites, doesn't just risk drift** — any manual edit to
   `~/.claude/settings.json` not round-tripped into `config/claude/settings.json` is destroyed on
   the next `switch`. Pre-existing behavior, not something this task should fix, but subtask 9
   (or any future move of `config/claude/`) must preserve this exact semantic and flag it, not
   silently widen what gets force-copied.
5. **No CI/automated backstop existed in the original decomposition at all.** Addressed by new
   subtask 3.
6. **`flake.lock` and `stateVersion` — verified as non-issues, but undocumented as such.** Both
   are confirmed healthy/intentional by the Critic; subtask 10 should record "checked, no action
   needed" one-liners so a future pass doesn't rediscover these as false positives.
7. **Whether every subtask must be behavior-preserving (inert) was never explicitly decided** —
   resolved above: subtasks 5 and 8 are explicitly behavior-changing by design; all others hold
   to strict closure equivalence.
8. **Task 69's dual-home-manager question remains a genuine open judgment call** (Option A/B/C in
   `docs/dual-home-manager.md`) — the underlying bug is fixed, but the architecture decision
   itself is not something this research can resolve; it is deferred to subtask 5/10 as a
   documentation-only closure, per Teammate D, unless the maintainer wants to actively pursue
   Option B/C migration (out of scope for this design).
9. **Task 78 (niri docs) should adopt but not merge with this reorg's doc convention** — a
   sequencing note for the task-creation phase, not a gap in the technical design itself.

### Recommendations

Ranked by leverage, per Teammate D's tiering, for the design + subtask-creation phase that
follows this research:

1. **Create the 10 ordered subtasks above as separate tasks/dependency waves**, preserving the
   Tier 0/1/2 boundaries — do not collapse into one big-bang implementation task.
2. **Sequence Tier 1 (subtask 5: module convention + per-host opt-in) before task 77 is
   dispatched.** This is the single highest-leverage design decision in this research: it turns
   task 77's niri/GNOME reconciliation from "invent a mechanism ad hoc" into "wire the new
   option."
3. **Add the CI gate (new subtask 3) early and cheaply** — it is a one-workflow-file change that
   directly prevents the recurrence pattern behind tasks 67/68/69's drift-discovered-late history.
4. **Bake the git-add-before-verify protocol into every subtask's own verification steps**,
   not as a one-time note — this is the single correction most likely to cause a confusing,
   hard-to-diagnose failure if missed.
5. **Treat subtasks 5 and 8 as behavior-changing** in their own task descriptions and plans, with
   runtime verification steps spelled out explicitly, not inherited generically from the task-66
   build-only harness.
6. **Defer discord-bot repo extraction and the `config/` rename** — both are real, evidence-backed
   ideas, but explicitly lower priority/optional; do not let them compete for the same tier as the
   module-convention fix.
7. **State the Nix-tree-only scope boundary explicitly** in the design document itself, so the
   task-creation phase and any future contributor don't have to infer it.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary (layout + decomposition) | completed | high |
| B | Alternatives (NixOS prior art) | completed | high (structural convergence); medium (specific sub-recommendations) |
| C | Critic (seed gaps/corrections) | completed | high |
| D | Horizons (strategic alignment) | completed | medium-high |

## References

- Seed report: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
- Repo evidence anchors (file:line): `flake.nix:96` (`root = self`), `flake.nix:107-114` (host
  wiring asymmetry), `lib/mkHost.nix:30-31,44`, `configuration.nix:25-26`,
  `modules/system/optional/discord-bot.nix:20,25,68,95,105,107`, `modules/home/core/shell.nix:20-67`,
  `docs/discord-bot.md:25`, `docs/dual-home-manager.md:33`, `docs/packages.md:244`,
  `docs/applications.md:26`, `packages/README.md:260-277`, `.claude/scripts/skill-base.sh:356,362`,
  `.claude/hooks/tts-notify.sh:31`, `.gitignore:34-36,41`, `home.nix:6,62`,
  `configuration.nix:30`, `hosts/garuda/default.nix:1-7`, `hosts/README.md:28-37`.
- Related open tasks: 66 (completed modular refactor baseline/harness), 67 (R env, not started),
  68 (zfs/iso-usb-installer broken, not started), 69 (dual home-manager decision, not started),
  71/72 (email extension extraction precedent), 74-77 (niri/GNOME sequential work), 78 (niri docs
  rewrite, depends on 74-77).
- External prior art (Teammate B, live `gh api` pulls + WebFetch/WebSearch):
  [Misterio77/nix-config](https://github.com/Misterio77/nix-config),
  [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs),
  [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config),
  [hlissner/dotfiles](https://github.com/hlissner/dotfiles), [flake.parts](https://flake.parts/),
  [evantravers.com — Reorganizing My Nix Dotfiles](https://evantravers.com/articles/2025/04/17/reorganizing-my-nix-dotfiles/).

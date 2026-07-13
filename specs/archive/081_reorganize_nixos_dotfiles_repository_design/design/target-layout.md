# Design Document: NixOS Dotfiles Repository Target Layout & Reorganization Blueprint

**Task**: 81 — reorganize_nixos_dotfiles_repository_design
**Status**: Canonical design reference for task 81 and its subtasks
**Sources**: `reports/01_repo-organization-review.md` (seed inventory),
`reports/02_team-research.md` (synthesized 4-teammate design + decomposition). No decision below is
invented beyond these two reports.

This document is the single source of truth that every reorganization subtask (see "Subtask
Blueprint" below) must reference before touching any file. It is NOT itself an implementation —
task 81 and this document move, rename, or delete nothing in the Nix-managed tree.

---

## 1. Target Directory Layout

### 1.1 Migration Philosophy (headline)

**This is an incremental, strictly ordered queue of small, independently-verifiable subtasks —
never a single reorg PR or one master implementation task.** The repo's own operating history
already works this way (task 66's phased, closure-diff-gated refactor; the niri work split into
four sequential tasks 74-77 off one seed), and the "systematic reorganization" framing of task 81
must not be collapsed into one big-bang phase list. Each subtask below lands, is verified, and is
committed independently before the next begins.

The existing top-level shape (`hosts/`, `modules/`, `overlays/`, `packages/`, `lib/`, `config/`)
already matches what three independent, well-regarded personal Nix configs converge on
(Misterio77, mitchellh, hlissner). **This is a convention-enforcement and cleanup task, not a
structural rewrite or framework migration.** flake-parts and snowfall-lib are explicitly rejected
(see decision table).

### 1.2 Scope Boundary (Nix-tree-only)

Task 81 and all subtasks it spawns are scoped **exclusively** to the Nix-managed tree:

```
modules/   hosts/   config/   overlays/   lib/   packages/   secrets/   root *.nix files
(plus: scripts/, .github/workflows/, docs/, wallpapers/, opencode-discord-bot/, root shell scripts)
```

**Explicitly out of scope and untouched**: `.claude/`, `.memory/`, `.opencode/`, `specs/` (the
agent-orchestration tree). No subtask created by this task may move, rename, or edit files in
those directories.

**Naming collision to never conflate**: `.claude/` (the agent-orchestration system, out of scope)
vs. `config/claude/` (deployed dotfiles for the `~/.claude/` runtime directory, in scope, deployed
via an activation-script `cp`). These are two different directories serving two different
purposes that happen to share a substring; subtask 9 (config/ deployment clarity) must document
this collision explicitly rather than let it be conflated during the reorg conversation.

### 1.3 Adopted Target Directory Tree

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
├── .github/workflows/         # NEW — nix flake check CI gate
│
├── lib/
│   └── mkHost.nix             # unchanged internals; per-host wiring stays explicit
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
│   │                             #   opted into explicitly per-host
│   └── home/
│       ├── default.nix          # NEW aggregator — replaces home.nix's flat list
│       ├── core/{git,neovim,xdg}.nix
│       │   └── dotfiles.nix     # renamed from shell.nix (deploys config/, not shell config);
│       │                         #   splitting deployment by owning module is a future direction, not mandatory now
│       ├── desktop/*.nix        # unchanged
│       ├── email/
│       │   ├── agent-tools/     # split from the single 761-line file (exact boundaries finalized during
│       │   │   ├── default.nix  #   subtask 7 planning by reading the full file)
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
│                                 #   packages/README.md:260-277)
├── config/                      # unchanged location and NAME (rename explicitly rejected)
│   └── README.md                # expanded: document 3 deployment mechanisms + config/ vs Nix `config`
│                                 #   argument shadowing + config/claude/ vs .claude/ naming collision
├── secrets/                     # unchanged
├── wallpapers/                  # unchanged location (assets/ deferred, not adopted now); 5 cruft files removed
├── docs/                        # README.md index completed; hosts/discord-bot docs updated
├── opencode-discord-bot/
│   └── pyproject.toml           # NEW near-term step — packaged via buildPythonApplication;
│                                 #   extraction to its own repo/flake input is a later, separate
│                                 #   strategic follow-on
└── specs/                       # untouched by this task (agent-orchestration tree, out of scope)
```

**High-confidence convergence points** (adopt as-is, no further debate): keep `lib/mkHost.nix`
hand-rolled and reject flake-parts/snowfall-lib entirely; scope the options pattern to
optional/toggleable modules only, not a blanket 43-file rewrite; reject the `config/` →
`dotfiles/` rename; treat `assets/` as deferred; centralize secrets as-is (no per-host
colocation).

---

## 2. Resolved Design-Question Decision Table

| # | Question | Resolved recommendation | Rationale (summarized) |
|---|---|---|---|
| 1 | Options pattern vs plain config sets | **Scoped adoption only**: options + `mkIf` required for modules a host must selectively enable (starting with `discord-bot.nix`); the other ~40 always-on modules and host-glue files remain plain config sets. Amend `.claude/rules/nix.md` to say so explicitly rather than mandating a 43-file rewrite. | Full convergence: matches Misterio77/hlissner precedent (reusable/toggleable modules use options, host-glue doesn't); avoids an unjustified blanket rewrite. |
| 2 | Per-host optional-module wiring mechanism | **Explicit per-host wiring**: require an explicit (possibly one-line) `hosts/<name>/default.nix` per host that opts into something, wired via `extraModules` in `flake.nix` — NOT a generic `pathExists`/`readDir` auto-import layer. | Three converging prior-art repos (Misterio77, mitchellh) hand-list imports explicitly; the one repo using auto-discovery (hlissner) explicitly warns in its own code comments against over-applying it — outweighs the narrower internally-reasoned `pathExists`-guard alternative. |
| 3 | `configuration.nix` / `home.nix` location | **Keep at repo root.** Do not move under `hosts/common/`. | 5+ call sites reference them directly; genuinely repo-level, not per-host; also sidesteps the task-69 relocation-sequencing concern entirely since no relocation happens. |
| 4 | `modules/{system,home}/default.nix` aggregators | **Introduce both.** | Free under Nix directory-import convention; co-locates the module manifest with the modules themselves; no counter-evidence. |
| 5 | `scripts/` for root shell scripts | **Yes**, for `install.sh`/`update.sh`/`build-usb-installer.sh`; update doc references in the same subtask. `test-sasl.sh` deleted, not moved. | Corroborated by hlissner's `bin/` precedent. |
| 6 | `assets/` for wallpapers | **Reject for now** — clean the 5 scaffolding files, keep `wallpapers/`. Revisit only when a second asset class appears. | Only one real asset today; prior art supports "adopt if it accumulates," not "adopt now." |
| 7 | `config/` rename | **Reject.** Document the Nix-`config`-argument shadowing and the `.claude/` vs `config/claude/` naming collision in `config/README.md` instead. | Explicitly ranked lowest priority/optional by research; a touch-everything rename with no functional benefit. |
| 8 | Discord-bot packaging destination | **Near-term: package in-tree via `buildPythonApplication` under `packages/`** (concrete, low-risk, immediately fixes the reproducibility hazard). Treat "extract to its own repo as a flake input" as a later strategic follow-on once the bot's interface stabilizes, mirroring the email-extension precedent. | Unanimous prior-art support for in-tree packaging of a still-evolving, same-repo tool; extraction elevated to documented future step, not the immediate action. |
| 9 | flake-parts / snowfall-lib adoption | **Reject both, decisively.** | Three independent well-regarded repos all hand-roll instead; no counter-evidence anywhere. |
| 10 | Task 69 (dual home-manager) resolution | **Resolve as a documentation-only closure** ("Option A retained, documented") folded into subtask 5 or 10, rather than spawning fully separate work — the underlying bug is already fixed as of task 66; only a judgment call remains. | Not addressed by other teammates in depth; adopted as-is; avoids re-litigating an already-fixed bug as new engineering work. |
| 11 | Raw-dotfile deployment structure (`shell.nix` → `dotfiles.nix`) | **Rename now** (concrete, scoped). Treat "split deployment out to each owning module" as a direction for the *next* iteration of `home/core/`, not mandatory within this task's granularity-pass subtask. | Rename is low-risk and immediately fixes the misnomer; full split validated as a direction but not required now. |

---

## 3. Subtask Blueprint

One row per subtask, drawn from research report 02 §"Recommended Subtask Decomposition". Real
task numbers and dependencies are filled in below in §6 ("Created Subtasks") once Phase 5
executes; this table retains the blueprint (#) identity as the stable cross-reference key.

**Cross-cutting requirements inherited by EVERY subtask below** (see §4 for full detail):
- **Stage-before-verify protocol**: `git add <specific paths>` (never `-A`) immediately before
  running the nix verification harness on any subtask that moves/creates/deletes files.
- **Scope boundary**: Nix-managed tree only (§1.2); `.claude/`, `.memory/`, `.opencode/`, `specs/`
  untouched.
- **Queue discipline**: independently-landable, never collapsed into one reorg PR.

| Blueprint # | Tier | Title | One-line scope | Depends on (blueprint #) | Suggested task_type | Verification level | Behavior-changing? |
|---|---|---|---|---|---|---|---|
| 1 | 0 | Dead code removal | Remove `home-modules/`, `modules/opencode.nix`, `packages/neovim.nix`, `test-sasl.sh`, `test-update.md`, root `TODO.md`, wallpapers cruft (5 files); widen `packages/test-mcphub.sh` removal to patch its 3 doc references (`docs/packages.md:244`, `docs/applications.md:26`, `packages/README.md:260-277`); drop the already-resolved `config/rclone.conf` verify step. | none | nix | Build-only inertness: `git status` shows only deletions + doc edits; harness green. | No |
| 2 | 0 | Git hygiene | Untrack `specs/tmp/*` contents and extend `.gitignore` — **the `specs/tmp/` directory itself must continue to exist on disk** (skill-base.sh's atomic state-write depends on it). `specs/tmp/lit.md` is an unrelated note, no decoupling needed. Fix `update.sh`'s mangled shebang and stray `complete\!`. | none | nix | Build-only inertness: `git status --porcelain` clean on `specs/tmp/` contents; directory still present; `./update.sh` still executes. | No |
| 3 | 0 | NEW — CI gate | Add a `nix flake check` GitHub Actions workflow (and/or a pre-commit hook); closes the drift-discovered-late gap that let tasks 67/68/69's underlying issues go undetected. | none | nix | Build-only inertness: workflow runs green on a trivial PR/push; local `nix flake check` still passes. | No |
| 4 | 0 | Root shell scripts → `scripts/` | Move `install.sh`, `update.sh`, `build-usb-installer.sh` into `scripts/`; update references in root `README.md`, `docs/testing.md`, `docs/usb-installer.md` in the same subtask. | none | nix | Build-only inertness: `grep` shows only `scripts/`-prefixed paths in docs; `./scripts/update.sh` runs. | No |
| 5 | **1 (strategic core — sequence before task 77)** | Module convention + aggregators + per-host discord-bot opt-in | Amend `.claude/rules/nix.md` to scope the options-pattern requirement to optional/host-toggled modules; introduce `modules/system/default.nix` + `modules/home/default.nix` aggregators; convert `discord-bot.nix` to `options.services.discordBot.enable` + `mkIf`; remove it from the shared aggregator; wire it explicitly per-host via `extraModules` in `flake.nix`; delete garuda's empty-body `default.nix` now, re-add only with real content when needed; update `docs/discord-bot.md:25`. Fold task 69's Option A documentation-only resolution in here or into subtask 10. | none (self-contained) | nix | **Runtime + build**: full harness (`nix flake check` + build nandi/hamsa/garuda + HM activation) PLUS `nixos-rebuild switch` + `systemctl status`/`journalctl` confirming hamsa's closure no longer includes the Discord bot's Python closure and nandi's does. | **YES — highest leverage** |
| 6 | 2 | hosts/ structural cleanup | Rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example to the current `mkHost` pattern; extract the ISO inline config block to `hosts/iso/default.nix` only as an explicitly optional stretch step — scope strictly to wiring, do not touch task 68's broken zfs-kernel state, and exclude iso/usb-installer from the build-diff harness. | 5 | nix | Build-only inertness: `nix flake check`; iso/usb-installer build state unchanged. | No |
| 7 | 2 | Module granularity pass | Split `agent-tools.nix` (761 lines) into `email/agent-tools/{default.nix, per-wrapper}.nix` (exact boundaries finalized during planning by reading the full file); merge tiny fragments (`fonts.nix`/`lean-math.nix`/`ai-tools.nix` → `packages/misc.nix`); co-locate memory scripts+services; rename `home/core/shell.nix` → `dotfiles.nix`. New files register in the subtask-5 aggregators. | 5 | nix | Build-only inertness: `nix build .#homeConfigurations.benjamin.activationPackage`; `diff-closures` empty (pure structural refactor). | No |
| 8 | 2 | opencode-discord-bot packaging | Add `pyproject.toml`, convert to `buildPythonApplication` under `packages/`, point the systemd unit's `ExecStart`/`PYTHONPATH` at the built store path instead of `~/.dotfiles/opencode-discord-bot`, fix the `discord-bot.nix:20` comment path typo, resolve the untracked-`.opencode/`-vs-tracked-`opencode.json` inconsistency. Document "extract to own repo as a flake input" as the next strategic step, not required now. | 5 | nix | **Runtime + build**: build harness + explicit runtime check (`systemctl cat`/dry-run showing a store path, not a `$HOME` path); document expected closure delta as intentional. | **YES** |
| 9 | 2 (optional/low priority) | config/ deployment clarity | Document (not rename) the three deployment mechanisms in `config/README.md`; note the `config/` vs Nix-`config`-argument shadowing and the `.claude/` vs `config/claude/` naming collision; cross-reference from `dotfiles.nix`'s header. Optional/do-only-if-a-slow-week-presents-itself. | 7 | markdown | Doc-only: stale-reference grep. | No |
| 10 | Final (gated on all above) | Documentation sync | Root README Module Map + package list (drop `neovim.nix`, add `piper-bin.nix`/`piper-voices.nix`, remove stale "(planned: task 66 ...)" annotations); `docs/README.md` index completion (`dual-home-manager.md`, `email-workflow.md`, `how-to-add-package.md`, `how-to-add-service.md`, `gnome-settings.md`, `video-editing.md`); new `modules/README.md`; one-line "checked, no action needed" notes for `flake.lock` health and `stateVersion` values; resolve task 69's documentation closure here if not done in subtask 5. Establish a "docs verified against source, not fixed once" convention that task 78 can cite (not merge with). | 1,2,3,4,5,6,7,8,9 | markdown | Full harness once more as final regression check; manual README-vs-`find` drift check. | No |

**Explicitly rejected from this task's scope** (do not re-open in any subtask): `profiles/`
layering (only 2-3 near-identical hosts today); per-host secrets colocation (current
single-recipient/single-rule setup is simpler as-is); a generic `readDir`/`mapModules`
auto-import library (more machinery than 4 hosts justify).

### 3.1 Inter-Subtask Dependency Wave Table (blueprint numbering)

| Wave | Blueprint subtasks | Blocked by |
|---|---|---|
| 1 | 1, 2, 3, 4 (Tier 0, fully parallel) | none |
| 2 | 5 (Tier 1, self-contained) | none (can run concurrently with wave 1, but strategically should land before task 77 dispatch) |
| 3 | 6, 7, 8 (Tier 2, all depend on 5) | 5 |
| 4 | 9 (depends on 7) | 7 |
| 5 | 10 (Final — documentation sync) | 1, 2, 3, 4, 5, 6, 7, 8, 9 |

Real task numbers and the same wave structure are recorded in §6 below.

---

## 4. Migration Safety & Verification

### 4.1 Git-Add-Before-Verify Protocol (mandatory, every subtask)

`flake.nix` uses `root = self` (`flake.nix:96`), which means `nix flake check` /
`nixos-rebuild build` only evaluate **git-tracked** content. Every move/create/delete subtask
MUST run:

```bash
git add <specific paths>     # NEVER git add -A
```

immediately before running the nix verification harness. Skipping this step does not fail loudly
— it silently checks the *stale tracked layout*, producing a false-positive green result or a
confusing "file not found" failure that looks unrelated to the actual change. This is the single
correction (Critic finding) most likely to cause a hard-to-diagnose failure if missed, and it is
baked into every subtask's own verification steps below rather than left as a one-time note.

### 4.2 Baseline Verification Harness (task-66 lineage)

For every subtask that touches the Nix-managed tree, run, in order, after staging (§4.1):

```bash
nix flake check
nixos-rebuild build --flake .#nandi
nixos-rebuild build --flake .#hamsa
nixos-rebuild build --flake .#garuda
nix build .#homeConfigurations.benjamin.activationPackage
nix store diff-closures <old-path> <new-path>   # expect EMPTY diff for inert subtasks
```

**`iso`/`usb-installer` are excluded** from this harness (task 68's broken zfs-kernel state means
they are not reliably buildable regardless of this task's changes; do not treat a failure there as
a regression introduced by task 81's subtasks).

### 4.3 Runtime Verification Requirement (subtasks 5 and 8 only)

Subtasks 5 (module convention + per-host discord-bot opt-in) and 8 (opencode-discord-bot
packaging) are **intentionally behavior-changing** — a host that silently got the Discord bot
before will legitimately stop getting it (subtask 5), and the bot's runtime execution path changes
from a working-tree `PYTHONPATH` import to a nix-store path (subtask 8). Build-level
`nix store diff-closures` **cannot observe** these changes: systemd unit fields like
`WorkingDirectory`/`PYTHONPATH`/`ExecStart` are runtime string literals invisible to closure
diffing.

For these two subtasks, the build harness (§4.2) must be supplemented with:

```bash
nixos-rebuild switch --flake .#<host>
systemctl status opencode-discord-bot.service   # or the actual unit name
journalctl -u opencode-discord-bot.service -n 50
systemctl cat opencode-discord-bot.service       # confirm ExecStart/PYTHONPATH points at a
                                                  # /nix/store/... path, not $HOME
```

Expected observations:
- Subtask 5: hamsa's closure no longer includes the Discord bot's Python closure; nandi's does.
- Subtask 8: the unit's `ExecStart`/working directory resolves to a nix-store path, not
  `~/.dotfiles/opencode-discord-bot`.

### 4.4 CI-Gate Rationale (subtask 3)

Subtask 3 adds a `nix flake check` GitHub Actions workflow. This is the design's answer to "no
automated backstop exists across a 9-10 subtask, multi-session reorg" — three of the repo's last
~15 tasks (67 R-env/ICU, 68 zfs-kernel, 69 lectic specialArgs) are exactly the class of drift such
a gate would catch immediately rather than during an unrelated task's audit later. It is
first-class Tier-0, not optional, precisely because it must be in place *before* the bulk of the
remaining 9 subtasks land, to catch any regression they introduce as early as possible.

### 4.5 Inertness Contract

**All subtasks except 5 and 8 hold to strict closure equivalence (inertness)** — verified via
`nix store diff-closures` producing an empty diff. Subtasks 5 and 8 are behavior-changing by
design and are verified instead via the runtime checks in §4.3, with their expected closure deltas
documented as intentional, not regressions.

---

## 5. Open Decisions & Dispositions

Every coverage gap enumerated in research report 02 §"Coverage Gaps" is given an explicit
disposition below. No decision the research rejected is left ambiguous or reopened.

| # | Gap (from report 02) | Disposition | Detail |
|---|---|---|---|
| 1 | `self`/store-path staging risk (`flake.nix`'s `root = self`) | **Resolve-now** | Codified as the git-add-before-verify protocol, §4.1 above, inherited by every subtask. |
| 2 | Build-only verification misses runtime-only breakage (discord-bot `WorkingDirectory`/`PYTHONPATH`) | **Resolve-now** | Codified as the runtime verification requirement for subtasks 5 and 8, §4.3 above. |
| 3 | Scope boundary for `.claude/`/`.memory/`/`.opencode/`/`specs/` vs. the Nix-managed tree never stated | **Resolve-now** | Codified as §1.2 above (Nix-tree-only scope boundary), including the explicit `.claude/` vs `config/claude/` naming-collision callout. |
| 4 | `config/claude/` activation force-overwrites, doesn't just risk drift | **Resolve-in-subtask 9** | Pre-existing, intended behavior — not something this task fixes. Subtask 9 (config/ deployment clarity) must document and preserve this exact semantic, flagging it explicitly rather than silently widening what gets force-copied. |
| 5 | No CI/automated backstop existed in the original decomposition | **Resolve-now** (via new subtask) | Addressed by subtask 3 (NEW — CI gate), §4.4 above. |
| 6 | `flake.lock` and `stateVersion` — verified non-issues, but undocumented as such | **Verified-non-issue; resolve-in-subtask 10** | Both confirmed healthy/intentional by the Critic. Subtask 10 (documentation sync) records one-line "checked, no action needed" notes so a future pass doesn't rediscover these as false positives. |
| 7 | Whether every subtask must be behavior-preserving (inert) was never explicitly decided | **Resolve-now** | Codified as the inertness contract, §4.5: subtasks 5 and 8 are explicitly behavior-changing by design; all others hold to strict closure equivalence. |
| 8 | Task 69's dual-home-manager question (Option A/B/C in `docs/dual-home-manager.md`) remains a genuine open judgment call | **Resolve-in-subtask 5-or-10 (defer the architecture decision itself)** | The underlying bug is already fixed as of task 66; only a documentation judgment call remains. Resolved as "Option A retained, documented" — a documentation-only closure folded into subtask 5 or subtask 10 (whichever lands the relevant doc edit; not a fully separate engineering task). Actively pursuing Option B/C migration is explicitly out of scope for this design. |
| 9 | Task 78 (niri docs) should adopt but not merge with this reorg's doc convention | **Resolve-now (sequencing note)** | Task 78 depends on tasks 74-77 and should adopt the "docs verified against source, not fixed once" convention established by subtask 10, but must not be merged with or made dependent on task 81's subtask chain — it is an adjacent, independently-scoped task. |

### 5.1 Additional resolve-now dispositions (carried by the design itself)

- **Explicit per-host wiring over `pathExists` auto-discovery** (Conflict #2 in report 02):
  resolved in the decision table, §2 row 2.
- **Keep `configuration.nix`/`home.nix` at root**: resolved in the decision table, §2 row 3 —
  sidesteps the task-69 relocation-sequencing concern entirely since no relocation occurs.
- **Scope the options pattern to optional/host-toggled modules only**: resolved in the decision
  table, §2 row 1; `.claude/rules/nix.md` is to be amended accordingly by subtask 5, not treated
  as requiring a blanket 43-file rewrite.

### 5.2 Defer-as-follow-on dispositions (explicitly NOT part of task 81 or its subtasks)

- Discord-bot extraction to its own repo/flake input (after the bot's interface stabilizes,
  mirroring the email-extension precedent) — documented as a future step in subtask 8, not
  required now.
- `assets/` directory — only when a second asset class appears (§2 row 6).
- `config/` → `dotfiles/` rename — rejected (§2 row 7).
- `profiles/` layering — only 2-3 near-identical hosts today; revisit if a 4th, role-divergent
  host appears.
- Per-host secrets colocation — current single-recipient/single-rule setup is simpler as-is.
- The generic auto-import (`readDir`/`mapModules`) library — more machinery than 4 hosts justify.

### 5.3 Roadmap Linkage Note (read-only observation, not a ROADMAP.md edit)

`specs/ROADMAP.md` currently has no populated items ("No items yet"). This design and its
subtasks advance general repository-health/maintainability goals (dead-code removal, CI backstop,
module-convention consistency, documentation accuracy). A later `/todo` completion pass, once
subtasks land, may choose to annotate `specs/ROADMAP.md` with these outcomes — this document only
notes the linkage; it does not edit ROADMAP.md, which remains read-only for task 81.

---

## 6. Created Subtasks

Blueprint # is the stable cross-reference key into §3 above. All 10 subtasks were created in
`specs/state.json` (project numbers 82-91) with `parent_task: 81`, status `not_started`, and a
seed report at `specs/{NNN}_{slug}/reports/01_seed.md` pointing back to this design document plus
reports 01/02.

| Blueprint # | Real task number | Title | Status | Dependencies (real numbers) |
|---|---|---|---|---|
| 1 | 82 | Dead code removal | not_started | none |
| 2 | 83 | Git hygiene (specs/tmp/) | not_started | none |
| 3 | 84 | NEW — nix flake check CI gate | not_started | none |
| 4 | 85 | Root shell scripts → scripts/ | not_started | none |
| 5 | 86 | Module convention + aggregators + per-host discord-bot opt-in | not_started | none (self-contained) |
| 6 | 87 | hosts/ structural cleanup | not_started | 86 |
| 7 | 88 | Module granularity pass | not_started | 86 |
| 8 | 89 | opencode-discord-bot packaging | not_started | 86 |
| 9 | 90 | config/ deployment clarity | not_started | 88 |
| 10 | 91 | Documentation sync (final) | not_started | 82, 83, 84, 85, 86, 87, 88, 89, 90 |

### 6.1 Dependency Wave Ordering (real task numbers)

| Wave | Tasks | Blocked by |
|---|---|---|
| 1 | 82, 83, 84, 85 (Tier 0, fully parallel) | none |
| 2 | 86 (Tier 1, self-contained — strategically should land before task 77 dispatch) | none |
| 3 | 87, 88, 89 (Tier 2) | 86 |
| 4 | 90 | 88 |
| 5 | 91 (Final — documentation sync) | 82, 83, 84, 85, 86, 87, 88, 89, 90 |

### 6.2 Roadmap Linkage

`specs/ROADMAP.md` is unmodified by task 81 (no populated items existed at design time; see §5.3).
These 10 subtasks advance repository-health/maintainability goals; a later `/todo` completion pass
may annotate ROADMAP.md once they land.

### 6.3 Consistency Check

`next_project_number` in `specs/state.json` was set to 92 after creation. `bash
.claude/scripts/generate-todo.sh` was run to regenerate `specs/TODO.md` from `specs/state.json`.

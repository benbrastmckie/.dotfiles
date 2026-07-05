# Research Report: Task #88 - Module granularity pass over modules/home/

- **Task**: 88 - Module granularity pass over modules/home/
- **Started**: 2026-07-04T00:00:00Z
- **Completed**: 2026-07-04T00:00:00Z
- **Effort**: ~1.5 hours (research only)
- **Dependencies**: Task 86 (module convention + aggregators) — landed, verified below
- **Sources/Inputs**:
  - `modules/home/default.nix` (current aggregator, read in full)
  - `modules/home/email/agent-tools.nix` (761 lines, read in full)
  - `modules/home/packages/{fonts,lean-math,ai-tools,dev-tools}.nix` (read in full)
  - `modules/home/scripts/memory-monitor.nix`, `modules/home/services/memory-services.nix` (read in full)
  - `modules/home/core/shell.nix` (read in full)
  - `modules/home/misc.nix` (top-level, read for collision check)
  - `flake.nix`, `home.nix` (special-args wiring: `lectic`, `root = self`)
  - `specs/086_module_convention_discord_bot_opt_in/summaries/01_module-convention-opt-in-summary.md`
  - `specs/081_.../design/target-layout.md` §1.3, §2 row 11, §3 row 7
  - `specs/081_.../reports/02_team-research.md` (blueprint row 7)
  - `README.md:71`, `docs/email-workflow.md:15`, `docs/how-to-add-service.md:121` (stale-reference scan)
  - `nix eval .#homeConfigurations.benjamin.activationPackage.name` (baseline sanity check)
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md, nix.md rules

## Executive Summary

- Task 86 landed exactly as expected: `modules/home/default.nix` is a **manually maintained,
  comment-grouped `imports` list** (31 entries), not auto-discovery. Every file this task
  renames/splits/merges must get a corresponding one-line edit in that single file — no second
  hand-edit site exists (`home.nix` only does `imports = [ ./modules/home ];`).
- `agent-tools.nix` (761 lines) splits cleanly along its existing `let`-bound helper functions
  (`mkPreamble`, `mkMutationPreamble`, `lower`) vs. its five `pkgs.writeShellScriptBin` entries.
  Recommended: `agent-tools/lib.nix` (plain, non-module, pure Nix — no `pkgs`/`config` needed)
  holding the shared bash-generator functions, plus one small HM-module file per binary that
  imports from `lib.nix`, plus `agent-tools/default.nix` that just lists the five.
- The three tiny package fragments (`fonts.nix`, `lean-math.nix`, `ai-tools.nix`, 8/8/10 lines)
  merge trivially into a new `packages/misc.nix` — but this collides in **basename** (not path)
  with the existing, unrelated top-level `modules/home/misc.nix` (activation/autoExpire/session
  vars). Both are sanctioned to coexist per `design/target-layout.md`'s own tree diagram; this
  report recommends a one-line disambiguating header comment in each, not a rename.
- Memory-system co-location has no single prescribed target directory in the seed docs (just
  "co-located/renamed to match"). Recommended: new `modules/home/memory/` directory with
  `monitor.nix` (was `scripts/memory-monitor.nix`) and `services.nix` (was
  `services/memory-services.nix`) — mirrors the `email/agent-tools/` subdirectory-grouping
  pattern this same task already establishes, so the repo ends up with one consistent idiom for
  "these N files are one conceptual unit."
- `core/shell.nix` → `core/dotfiles.nix` is a pure rename plus a header-comment reword (the
  existing header already says "config sources" but still titles itself "Shell configuration",
  perpetuating the misnomer it names itself after).
- `lectic` is available as a global `extraSpecialArgs` (wired in `flake.nix`/`home.nix`), so the
  merged `packages/misc.nix` can declare `{ pkgs, lectic, ... }:` without new plumbing.
- Documentation references to the old paths exist (`README.md:71` Module Map, `docs/email-
  workflow.md:15`, `docs/how-to-add-service.md:121`) but are **explicitly task 91's scope**
  (gated on 82-90 landing first) — task 88 should not touch them; this report flags them only so
  task 91's drift check isn't a surprise.

## Context & Scope

Task 88 is subtask blueprint #7 of the task-81 reorganization, depending on subtask 86 (module
convention + aggregators, already landed at commit `add7cae`). Its job is a pure structural
refactor of `modules/home/` — split one oversized file, merge three tiny ones, co-locate two
related-but-separated files, and fix one misnomer — with the aggregator as the single
registration point and an empty `nix store diff-closures` as the correctness bar. No option
schemas, no behavior changes, no new dependencies.

## Findings

### Aggregator (`modules/home/default.nix`) — confirmed convention

Read in full (52 lines). It is a flat, hand-maintained `{ ... }: { imports = [ ... ]; }` with six
comment-delimited groups (Core, Desktop, Email, Package, Script, Service) plus a trailing
`./misc.nix`. There is **no auto-discovery** (`lib.filesystem` / `readDir` glob) — task 86's
summary explicitly notes it "[reused] the existing garuda `extraModules` shape ... rather than
introducing a new auto-discovery mechanism." This means:

- Every renamed/split/merged file needs exactly one line changed/added/removed in this file.
- `home.nix` (`imports = [ ./modules/home ]; home.username = ...; home.stateVersion = ...;`) is
  untouched by anything in this task — it never lists individual module files.
- Directory imports work fine for Nix (`imports = [ ./email/agent-tools ]` resolves to
  `./email/agent-tools/default.nix` automatically, same as plain `import`), so the agent-tools
  split does not require a `/default.nix` suffix in the aggregator entry, though writing it
  explicitly is also valid — this report recommends the terser directory form since no other
  directory-style import currently exists in the file, to keep this one visually distinguishable
  as "this is a split module."

### (1) `email/agent-tools.nix` split — read in full, 761 lines

Structure (line numbers from the current file):

| Region | Lines | Content |
|---|---|---|
| Header comment | 1-27 | Contract description (task 72/79 provenance, two-layer enforcement rationale) — applies to the whole file, not one binary |
| `{ pkgs, ... }:` + `let` | 28-311 | `manifestDirDefault` (30); `mkPreamble` (36-103, shared by all 5); `mkMutationPreamble` (111-309, extends `mkPreamble`, shared by the 2 mutation binaries — bundles `state_set`/`state_status_for`, `resolve_envelope_id`, `pending_ids_for_action`/`enforce_batch_size`, `is_mbsync_auth_failure`/`run_mbsync_reconcile`); `lower` (311) |
| `email-census` | 317-361 (45 lines) | read-only sender/folder/date census |
| `email-classify` | 363-523 (161 lines) | local-tags-only; largest single binary — Tier-1/Tier-2 rule tables + `classify_one` + main loop + `--append-approved` mode |
| `email-unsubscribe-extract` | 525-585 (61 lines) | read-only, List-Unsubscribe header harvest |
| `email-archive-confirmed` | 587-637 (51 lines) | mutation, single-hop move |
| `email-delete-confirmed` | 639-759 (121 lines) | mutation, two-hop delete (`--expunge-trash`) |

**Key coupling constraint**: `mkMutationPreamble` is used by *both* mutation binaries and its
internal bash functions (`resolve_envelope_id`, `state_set`/`state_status_for`,
`run_mbsync_reconcile`, etc.) are tightly interdependent — splitting it further than "one
function" would fragment cohesive bash logic across files for no benefit. All of `mkPreamble` /
`mkMutationPreamble` / `lower` are **pure string-generation functions with no `pkgs` or `config`
dependency** (verified: `mkPreamble`'s only interpolation is `manifestDirDefault`, a plain
string; `lower` is a literal `tr` invocation) — they do not need to be a home-manager module at
all.

**Recommended split** — `modules/home/email/agent-tools/`:

- `lib.nix` — plain (non-module) Nix file: `{ manifestDirDefault, mkPreamble, mkMutationPreamble,
  lower }`, carrying the full header comment (contract provenance) since it describes the whole
  subsystem, not one binary. No function arguments needed (verified pure). ~290 lines (27 header
  + ~260 body).
- `census.nix` — `{ pkgs, ... }: let inherit (import ./lib.nix) mkPreamble; in { home.packages =
  [ (pkgs.writeShellScriptBin "email-census" (mkPreamble { ... } + '' ... '')) ]; }`. ~55 lines.
- `classify.nix` — same shape, ~170 lines (still the largest file post-split, but a 4.5x
  reduction from the monolith and self-contained to one binary's logic).
- `unsubscribe-extract.nix` — ~70 lines.
- `archive-confirmed.nix` — needs `mkMutationPreamble`; ~60 lines.
- `delete-confirmed.nix` — needs `mkMutationPreamble`; ~130 lines.
- `default.nix` — `{ ... }: { imports = [ ./census.nix ./classify.nix ./unsubscribe-extract.nix
  ./archive-confirmed.nix ./delete-confirmed.nix ]; }`, ~10 lines.

File names drop the redundant `email-` prefix (directory already scopes them), mirroring the
existing convention of `core/git.nix` not being named `home-git.nix`. Sum of new files (~785
lines across 7 files) is larger than the original 761 due to per-file module boilerplate
(`{ pkgs, ... }: let ... in { home.packages = [ ... ]; }` repeated 5x) — expected and acceptable;
no file exceeds ~290 lines vs. the original 761.

**Aggregator change**: replace `./email/agent-tools.nix` with `./email/agent-tools` (or
`./email/agent-tools/default.nix`) in the Email modules group, same position.

### (2) Tiny package fragments → `packages/misc.nix`

Read in full:
- `fonts.nix` (8 lines): `{ pkgs, ... }: { home.packages = with pkgs; [ nerd-fonts.roboto-mono
  jetbrains-mono ]; }`
- `lean-math.nix` (8 lines): `{ pkgs, lectic, ... }: { home.packages = with pkgs; [ lectic
  loogle ]; }` — **note the `lectic` special arg**.
- `ai-tools.nix` (10 lines): `{ pkgs, ... }: { home.packages = with pkgs; [ claude-code
  claude-squad gemini-cli gh ]; }`

`lectic` is a global `extraSpecialArgs` wired in `flake.nix` (lines 87, 95, 138, 173, 203-206)
and `home.nix:1`, so it is available to any home-manager module unconditionally — the merged
file can safely declare `{ pkgs, lectic, ... }:`.

**Recommended merge** — new `modules/home/packages/misc.nix`:
```nix
# Miscellaneous small package groups: fonts, Lean 4/formal-math tools, AI coding assistants.
# Merged from fonts.nix + lean-math.nix + ai-tools.nix (each too small to justify its own file).
{ pkgs, lectic, ... }:
{
  home.packages = with pkgs; [
    # Fonts
    nerd-fonts.roboto-mono
    jetbrains-mono

    # Lean 4 and formal mathematics tools
    lectic
    loogle

    # AI and coding assistant tools
    claude-code
    claude-squad
    gemini-cli
    gh
  ];
}
```
(Comment sub-groups preserve the per-source provenance a future reader would want; `lectic` stays
outside `with pkgs;` scope-wise since it is not a `pkgs` attribute — Nix resolves it fine as a
free variable inside the list even under `with pkgs;` because `with` only adds fallback bindings,
it does not shadow an existing lexical binding.)

**Naming collision to flag, not fix**: `modules/home/misc.nix` (top-level; unrelated —
`home.activation.createMailDir`, `services.home-manager.autoExpire`,
`systemd.user.sessionVariables`, `systemd.user.startServices`) and the new
`modules/home/packages/misc.nix` share a basename in different directories. `design/target-
layout.md`'s own tree diagram shows both paths side by side deliberately, so this is a sanctioned
outcome, not an oversight to rename away — but each file's header comment should make the
distinction explicit (e.g. "packages/misc.nix — package-only fragments, see also the top-level
`../misc.nix` for activation/session settings") to prevent a future contributor editing the wrong
one.

**Aggregator change**: in the "Package modules" group, remove `./packages/ai-tools.nix`,
`./packages/lean-math.nix`, `./packages/fonts.nix` (3 lines removed) and add one
`./packages/misc.nix` line. Net: group shrinks from 7 entries to 5.

### (3) Memory system co-location

`scripts/memory-monitor.nix` (`home.packages`: two `writeShellScriptBin` scripts,
`memory-monitor` and `claude-memory-tracker`) and `services/memory-services.nix`
(`systemd.user.services.memory-monitor` / `.claude-memory-tracker`) are two halves of one
three-tier system (both files carry an identical provenance header comment referencing
`specs/26_memory_monitoring_systemd_services_nixos`) but currently live in unrelated top-level
directories (`scripts/` and `services/`) alongside 6 other, unrelated files each.

The seed docs (`target-layout.md` §1.3: `"scripts/ + services/ # memory-monitor.nix +
memory-services.nix co-located/renamed to match"`) do not prescribe an exact target directory —
only the outcome ("sit together", "named consistently"). Two options considered:

1. Rename in place only (`scripts/memory.nix`, `services/memory.nix`) — satisfies "named
   consistently" but not literally "sit together" (still two directories; only adjacent in the
   aggregator's comment-grouped list, not the filesystem).
2. **Recommended**: new `modules/home/memory/` directory with `monitor.nix` (was
   `scripts/memory-monitor.nix`) and `services.nix` (was `services/memory-services.nix`). This
   literally co-locates them and gives this task exactly one grouping idiom throughout
   (`email/agent-tools/` for a split, `memory/` for a co-location) rather than two different
   conventions for "these files belong together."

**Aggregator change**: remove `./scripts/memory-monitor.nix` from the Script modules group and
`./services/memory-services.nix` from the Service modules group; add a new comment-delimited
group (or extend an existing one) with `./memory/monitor.nix` and `./memory/services.nix`. The
Script and Service groups each still retain 3 other unrelated entries after removal, so neither
group is emptied by this move.

### (4) `core/shell.nix` → `core/dotfiles.nix`

Read in full (78 lines). Content is entirely `home.sessionVariables`, `home.file` (source/text
deployments of `config/*` into `~/.config`, `~/.tmux.conf`, `~/.latexmkrc`, `~/.zuliprc`,
TTS/STT model directories), two `home.activation` blocks (`claudeSettings`, `uvTools`), and
`programs.home-manager.enable = true;`. Nothing shell-configuration-specific (no fish/bash/zsh
options) — confirms the misnomer. The file's own header comment ("Shell configuration: session
variables, home.file config sources, and related settings.") already half-describes the
mismatch; recommend rewording alongside the rename, e.g.: `# Dotfiles deployment: session
variables, home.file sources from config/, and related activation scripts.` Pure rename + header
reword, no logic change. Per task scope, splitting the `home.file` block out to each owning
module (e.g. sioyek prefs into a sioyek module) is explicitly future direction, not required
here.

**Aggregator change**: `./core/shell.nix` → `./core/dotfiles.nix`, same position in the Core
modules group.

### Stale documentation references (informational — task 91's scope, not task 88's)

- `README.md:71` — Module Map tree still shows `shell.nix` under `core/`.
- `docs/email-workflow.md:15` — "Built by `modules/home/email/agent-tools.nix`" (will become a
  directory after this task).
- `docs/how-to-add-service.md:121` — references the systemd unit name
  `systemd.user.services.memory-monitor` (unaffected — service names aren't renamed, only the
  `.nix` file paths that declare them), so no change needed there.

Task 91 ("documentation_sync_reorg_final", task 81 Final tier, explicitly gated on subtasks
82-90 landing first) already owns exactly this kind of drift and does a "manual README-vs-`find`
drift check across the whole tree" — task 88 should leave these untouched rather than partially
pre-empting task 91's scope.

### Build verification baseline

`nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeds against the current tree
(returns `"home-manager-generation"`), confirming the flake evaluates cleanly before this task's
changes — a valid pre-change baseline point for the `nix build
.#homeConfigurations.benjamin.activationPackage` + `nix store diff-closures` verification the
task specifies. (Full build was not run during research to keep this pass read-only; the
planning/implementation phase should capture the pre-change closure path before making any
`git mv`.)

## Decisions

- Recommend `email/agent-tools/lib.nix` as a **plain, non-module** Nix file (not itself a home-
  manager module) holding `mkPreamble`/`mkMutationPreamble`/`lower`/`manifestDirDefault`, since
  all four are pure string/data generators with no `pkgs`/`config` dependency — avoids threading
  unnecessary module args through a file that isn't itself contributing `home.packages`.
- Recommend per-binary files drop the `email-` prefix (directory scopes it): `census.nix`,
  `classify.nix`, `unsubscribe-extract.nix`, `archive-confirmed.nix`, `delete-confirmed.nix`.
- Recommend `modules/home/memory/{monitor.nix,services.nix}` for the memory co-location (new
  directory) over an in-place rename-only, to give the task one consistent grouping idiom.
- Recommend NOT renaming/touching the existing top-level `modules/home/misc.nix` despite the new
  `packages/misc.nix` basename collision — `target-layout.md` shows both paths deliberately;
  only a disambiguating header-comment addition is recommended, not a structural change.
- Recommend the aggregator entry for the split use the directory form (`./email/agent-tools`)
  rather than `./email/agent-tools/default.nix`, since Nix resolves both identically and the
  shorter form is idiomatic for import-list entries pointing at a package/module directory.
- Recommend leaving `README.md`, `docs/email-workflow.md`, `docs/how-to-add-service.md`
  untouched — explicitly task 91's scope per its own task description.

## Risks & Mitigations

- **Risk**: Splitting `agent-tools.nix`'s bash across 6 files could silently break string
  interpolation if a helper function reference is missed during extraction (e.g. `lower` used
  only in `classify.nix`'s `sender_lc=$(... | ${lower})`). **Mitigation**: `nix build
  .#homeConfigurations.benjamin.activationPackage` will fail loudly on any missing/misspelled
  `import`/`inherit`; additionally the wrapper contract's own smoke-test pattern (each binary
  supports `--help`) gives a fast per-binary manual check post-build.
  `nix store diff-closures` against the pre-change baseline is the authoritative check — the
  generated store paths' *content* (not just evaluation) must be byte-identical since this is a
  pure text refactor of `let`-bound Nix expressions producing the same interpolated shell script.
- **Risk**: Forgetting to update `modules/home/default.nix` for any one of the ~7 file-path
  changes (5 removed + up to 4 added across the 4 subtasks) would silently drop that module from
  the home-manager build (Nix would not error — the file would simply not be imported).
  **Mitigation**: the aggregator is the single hand-edit site (confirmed above); a final
  line-count diff of the aggregator (31 entries before, expect 31 - 3 removed (misc merge) - 2
  removed (memory scripts/services, replaced by 2 new) + 1 (packages/misc.nix) + 0 net for
  agent-tools (1-for-1 replace) + 0 net for shell->dotfiles (1-for-1 rename) = 29 total lines,
  i.e. 2 fewer than 31) is a cheap self-check before running the build.
- **Risk**: `git mv` ordering — `flake.nix`'s `root = self` means any file present in the working
  tree but not `git add`-ed is invisible to the flake evaluator (pure evaluation reads from the
  git index/store, not the raw filesystem, when `self` is a git-tracked flake). **Mitigation**:
  the task's own inherited protocol already specifies `git mv` (never plain `mv` followed by `-A`
  add) for every rename, and targeted `git add <path>` for new files (the split/merge files are
  genuinely new paths, not renames, so they need `git add`, not `git mv`).

## Recommended Aggregator Diff (net effect on `modules/home/default.nix`)

```diff
     # Core modules
     ./core/git.nix
     ./core/neovim.nix
-    ./core/shell.nix
+    ./core/dotfiles.nix
     ./core/xdg.nix

     ...

     # Email modules
     ./email/mbsync.nix
     ./email/protonmail.nix
     ./email/notmuch.nix
     ./email/aerc.nix
-    ./email/agent-tools.nix
+    ./email/agent-tools

     # Package modules
-    ./packages/ai-tools.nix
-    ./packages/lean-math.nix
     ./packages/dev-tools.nix
     ./packages/media-dictation.nix
     ./packages/email-tools.nix
     ./packages/python.nix
-    ./packages/fonts.nix
+    ./packages/misc.nix

     # Script modules (inline shell scripts)
     ./scripts/sioyek-theme.nix
     ./scripts/gmail-oauth2.nix
     ./scripts/whisper.nix
-    ./scripts/memory-monitor.nix

     # Service modules (systemd user services and timers)
     ./services/screenshot.nix
     ./services/ydotool.nix
     ./services/gmail-oauth2.nix
-    ./services/memory-services.nix
     ./services/cache-cleanup.nix

+    # Memory monitoring (co-located: scripts + systemd services, three-tier system)
+    ./memory/monitor.nix
+    ./memory/services.nix

     # Miscellaneous settings (activation, autoExpire, sessionVariables, startServices)
     ./misc.nix
```

## Appendix

- `modules/home/default.nix` full current content: 52 lines, 31 import entries across 6
  comment-delimited groups + trailing `./misc.nix`.
- Confirmed via `git log --oneline -- modules/home/`: task 86 aggregator commit is `add7cae`
  ("task 86 phase 2: add modules/system + modules/home aggregators").
- `nix (Nix) 2.34.7` available in this environment; `nix eval
  .#homeConfigurations.benjamin.activationPackage.name` returns `"home-manager-generation"`
  against the current (pre-task-88) tree.

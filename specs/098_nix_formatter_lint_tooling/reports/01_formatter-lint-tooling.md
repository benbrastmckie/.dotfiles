# Research Report: Task #98

**Task**: 98 - nix_formatter_lint_tooling
**Started**: 2026-07-05T10:16:00Z
**Completed**: 2026-07-05T10:35:00Z
**Effort**: Medium (research only; no files modified)
**Dependencies**: Task 97 (completed — `refactor_dead_comment_cleanup`; both tasks touch `flake.nix`,
confirmed no conflict remains: task 97 already extracted the three inline `packages.nix` wrapper
derivations into `packages/polkit-gnome-agent-wrapper.nix` / two others, which is why
`packages/*.nix` now has 16 files instead of the 13 the backlog report counted)
**Sources/Inputs**: `flake.nix` (full read), `.github/workflows/ci.yml` (full read),
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group D,
primary source), live `nix eval`/`nix build`/`nixfmt --check`/`statix check`/`deadnix` runs against
this repo's own pinned `nixpkgs` input (`nixos-26.05`), `specs/state.json`
**Artifacts**: This report —
`specs/098_nix_formatter_lint_tooling/reports/01_formatter-lint-tooling.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **User decision is already made and is baked in below, not re-litigated**: nixfmt as
  `formatter`, statix + deadnix as devShell tools, CI runs statix/deadnix non-blocking (`|| true`),
  `nix flake check` stays the only hard gate.
- **Important attribute correction**: in this repo's pinned nixpkgs (`nixos-26.05`),
  `pkgs.nixfmt-rfc-style` still evaluates but is a **deprecated alias** — it emits
  `evaluation warning: nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used
  instead` on every evaluation. Verified `pkgs.nixfmt.outPath == pkgs.nixfmt-rfc-style.outPath`
  (identical derivation, version 1.3.1, `meta.description = "Official formatter for Nix code"`).
  **Recommendation: use `pkgs.nixfmt` as the actual attribute**, referring to it as "nixfmt (RFC
  166 / formerly nixfmt-rfc-style)" in comments so the task's naming intent is preserved without
  the repo picking up a stderr deprecation warning on every `nix flake check` / `nixos-rebuild` /
  `home-manager build`.
- `flake.nix` is single-system (`system = "x86_64-linux";` hardcoded in the `let` block, no
  `flake-utils.eachDefaultSystem`) — the `utils` input (flake-utils) exists but is unused anywhere
  in `outputs`. This means `formatter` and `devShells` attach the same way every other per-system
  output would if one existed: `formatter.${system} = ...;` / `devShells.${system}.default = ...;`,
  no new multi-system plumbing needed.
- No `devShells` output exists today at all — this will be a new top-level key, not an edit to an
  existing one.
- `.github/workflows/ci.yml` is a single minimal job (`flake-check`) with one `run: nix flake check`
  step. Adding non-blocking statix/deadnix means adding two more `run:` steps (or a second job) each
  suffixed `|| true`, using `nix develop --command` so the linters resolve to the exact versions
  pinned in `flake.lock` rather than an independent nixpkgs registry fetch.
- statix and deadnix are both available and buildable from this repo's pinned nixpkgs
  (`statix` version `0-unstable-2026-05-14`, `deadnix` version `1.3.1`) — both built successfully
  from the binary cache during this research, confirming no custom overlay/derivation is needed.
- Blast radius of an initial `nix fmt` pass, measured directly with `nixfmt --check` against all
  80 `.nix` files in the tree: **47 files need reformatting, 33 already conform, 0 parse errors**.
  `flake.nix` itself needs reformatting. 14 of 16 `packages/*.nix` files need reformatting.
- statix already finds **33 real warnings** and deadnix finds several unused-binding warnings
  across the tree today (both confirmed via live dry runs, not applied) — this is exactly why the
  user's non-blocking decision is the right call for an initial adoption: existing lint debt would
  otherwise instantly redden CI.
- Task 96 (`documentation_completeness_gaps`, status `not_started`) is the concurrent task adding
  header comments to `packages/*.nix`. Since 14 of those 16 files will be touched by the format
  pass, **sequence the format pass to run after task 96 lands** (or, if task 96 is not done first,
  expect `packages/*.nix` header-comment additions and the format-pass reformatting to land in the
  same commit/PR and both must be verified together) to avoid a rebase/merge collision on the same
  lines.

## Context & Scope

Research-only investigation for task 98, per
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` Group D
(finding 13). The user has already decided the open questions that report flagged as needing
confirmation (formatter choice, CI strictness) — this report does not re-open them. Scope: (1) the
exact `flake.nix` edit to add `formatter` + `devShells`, (2) the exact `.github/workflows/ci.yml`
edit to add non-blocking statix/deadnix, (3) statix/deadnix invocation and config-file conventions,
(4) blast-radius measurement of the first `nix fmt` pass, (5) confirmation that nixfmt-rfc-style
(`pkgs.nixfmt`), statix, and deadnix are present and buildable in this repo's pinned nixpkgs.

MCP-NixOS was not available in this session (no `mcp__nixos__nix` tool surfaced); package/attribute
verification was done directly against this repo's own pinned nixpkgs input via
`builtins.getFlake` + `nix eval`/`nix build`, which is strictly more accurate than a registry-based
MCP or CLI search for this repo's purposes (it reflects exactly what `nixos-rebuild`/`home-manager
switch`/`nix flake check` will resolve, not whatever nixpkgs revision a generic search indexes).

## Findings

### 1. `flake.nix` structure (full read)

- 180 lines, single `outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri,
  lectic, nix-ai-tools, utils, sops-nix, ... }@inputs:` function.
- `let ... in { ... }` body — `system = "x86_64-linux";` is bound once at the top of `let` (line
  43) and used verbatim wherever a system-scoped attribute is needed (e.g.
  `pkgs-unstable = import nixpkgs-unstable { inherit system; ... }` at line 46-47, `pkgs = import
  nixpkgs nixpkgsConfig;` at line 76 where `nixpkgsConfig` inherits `system`).
- No `flake-utils.lib.eachDefaultSystem`/`eachSystem` call anywhere — the `utils` input (line 27,
  `github:numtide/flake-utils`) is destructured into the `outputs` argument set but **not
  referenced anywhere in the function body**. This is pre-existing, out of scope for this task, but
  relevant context: adding `formatter`/`devShells` should follow the repo's existing hardcoded
  single-system convention (`${system}` = `"x86_64-linux"`), not introduce
  `flake-utils.eachDefaultSystem` as a new pattern — that would be a much larger, unrelated
  refactor of every existing output.
- The `outputs` attrset currently has exactly two top-level keys: `nixosConfigurations` (lines
  104-159) and `homeConfigurations` (lines 164-178). No `packages`, no `devShells`, no `formatter`,
  no `checks`, no `overlays` output exists at the flake level (overlays are consumed internally via
  `nixpkgsConfig.overlays`, not exposed as a flake output).
- `pkgs` (line 76, the stable overlay-applied package set for `system`) is the natural value to
  pull `nixfmt`/`statix`/`deadnix` from — it is already in scope in the `let` block and is exactly
  the package set every other host/home config in this flake resolves against, so the formatter
  and devShell tools will be version-consistent with the rest of the config (same `nixpkgs`
  input, same overlays applied, though the overlays here — `claude-squad`, `unstable-packages`,
  `python-packages` — do not touch `nixfmt`/`statix`/`deadnix` so there is no interaction risk).

### 2. Exact `flake.nix` diff (conceptual)

Insert as two new top-level keys inside the existing `outputs`'s returned attrset, after
`homeConfigurations` (i.e. right before the final closing `};` at line 178/179):

```nix
    # Standalone home-manager: manages ~/.nix-profile/
    homeConfigurations = {
      benjamin = home-manager.lib.homeManagerConfiguration {
        ...
      };
    };

    # nix fmt -> nixfmt (RFC 166 official formatter; nixfmt-rfc-style is now a deprecated
    # alias of the same derivation as of this nixpkgs pin — use nixfmt directly to avoid its
    # stderr deprecation warning on every evaluation)
    formatter.${system} = pkgs.nixfmt;

    # nix develop -> nixfmt/statix/deadnix available for local formatting/linting
    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = [
        pkgs.nixfmt
        pkgs.statix
        pkgs.deadnix
      ];
    };
  };
}
```

Notes on this diff:
- `pkgs.mkShellNoCC` (no C compiler wrapper) is the idiomatic minimal choice here since the shell
  only needs to expose CLI tools, not a build environment — matches nixpkgs convention for
  tooling-only devShells. `pkgs.mkShell` also works identically for this case if the repo prefers
  consistency with a future devShell that does need a compiler; either is defensible, `mkShellNoCC`
  is marginally more correct/minimal.
- No `system`-based `builtins.mapAttrs`/`genAttrs` indirection is needed because the whole flake is
  already single-system; `formatter.${system}` and `devShells.${system}.default` are exactly as
  simple as `nixosConfigurations.<name>` already is.
- This is purely additive — no existing line changes, no risk to `nixosConfigurations`/
  `homeConfigurations`.

### 3. CI config: current state and exact edit

`.github/workflows/ci.yml` (19 lines total, full contents):

```yaml
name: nix-flake-check

on:
  push:
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  flake-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
        with:
          github_access_token: ${{ secrets.GITHUB_TOKEN }}
      - run: nix flake check
```

Single job, single hard-gating step. Per the user's decision, add two more non-blocking steps to
the **same job** (simplest — no new job/runner startup cost, same checkout/install-nix already
done), using `nix develop --command` so the tool versions come from this repo's own
`flake.lock`-pinned `devShells.${system}.default` rather than an independent `nixpkgs#statix`/
`nixpkgs#deadnix` registry fetch (keeps CI and local `nix develop` using identical tool versions):

```yaml
jobs:
  flake-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
        with:
          github_access_token: ${{ secrets.GITHUB_TOKEN }}
      - run: nix flake check
      - name: statix (non-blocking)
        run: nix develop --command statix check || true
      - name: deadnix (non-blocking)
        run: nix develop --command deadnix . || true
```

Notes:
- `|| true` matches the user's explicit instruction verbatim and guarantees the step's exit code is
  always 0 regardless of findings — this is a deliberate trade-off (GitHub Actions will show these
  steps as green/passed even when lint issues are found; the actual statix/deadnix stdout is still
  visible in the step's log for a human to read, it's just not gating). This is the correct
  behavior per the user's already-made decision and should not be replaced with
  `continue-on-error: true` (which would show a distinct "step failed but job continues" annotation
  instead) unless the user asks for that visibility trade-off specifically — noting it here only so
  the planner is aware the choice was deliberate, not overlooked.
- `nix flake check` remains untouched as the only step whose non-zero exit fails the job/PR check —
  matches the user's decision exactly ("keep `nix flake check` as the only hard CI gate").
- No new job, no matrix, no separate workflow file — minimal edit to the existing single job,
  consistent with how small this CI file already is.

### 4. statix / deadnix invocation and config files

Both binaries were built and run directly against this repo (via
`pkgs.statix`/`pkgs.deadnix` from this repo's pinned nixpkgs) to confirm exact CLI surface:

**statix** (subcommands: `check`, `fix`, `single`, `explain`, `dump`, `list`, `help`):
```
statix check [OPTIONS] [TARGET]   # TARGET defaults to "."
  -o, --format <FORMAT>    stderr (default) | errfmt | json
  -c, --config <CONF_PATH> path to statix.toml or its parent dir (default: ".")
  -i, --ignore <IGNORE>    globs to skip
```
- Config file name is **`statix.toml`** (not `.statix.toml`) — confirmed from `--help` text
  (`-c, --config <CONF_PATH>  Path to statix.toml or its parent directory [default: .]`) and from
  `statix dump` which prints a sample `statix.toml`. Per the task's "keep it minimal" instruction:
  **do not add a `statix.toml`** for this initial pass — the default config (all lints enabled, no
  ignores) is fine for a report-only, non-blocking CI step; a config file can be added later if
  specific lints need suppressing once someone reviews the 33 current warnings.
- Live dry run (`statix check .`, not applied) found **33 warnings** across the tree today
  (confirmed count via `statix check -o json . | jq '[.[].report[]] | length'`), including repeated
  patterns like "Avoid repeated keys in attribute sets" (`flake.nix:131`, `hosts/iso/default.nix:8`)
  and "Found empty pattern in function argument" (`{ ... }:` — several `modules/**/*.nix` files use
  this deliberately for modules that ignore all standard args). This pre-existing lint debt is
  exactly why the non-blocking decision is correct for the initial adoption — gating CI on statix
  today would immediately fail every PR until all 33 are triaged/fixed or suppressed.

**deadnix** (positional args, no subcommands):
```
deadnix [OPTIONS] [FILE_PATHS]...   # defaults to "."
  -f, --fail                 exit 1 if unused code found (NOT passed by default — default exit is 0)
  -e, --edit                 auto-remove and write (NOT used here — report-only)
  -o, --output-format <FMT>  human-readable (default) | json
  --exclude <EXCLUDES>...    files to exclude
```
- No dedicated config file — deadnix is flag-only (confirmed via `--help`, no `-c`/`--config`
  option exists). "Keep it minimal" is trivially satisfied: no config file needed at all.
- Note deadnix's default exit code is already 0 unless `-f`/`--fail` is passed, so `deadnix . ||
  true` is technically double-insurance (the tool itself won't fail the step even without `|| true`)
  — but per the user's explicit instruction to add `|| true` uniformly and for defense against a
  future flag change, keep it on both steps for consistency and clarity of intent in the CI file.
- Live dry run found unused-lambda-argument/pattern warnings (e.g. `hosts/{garuda,hamsa,nandi,
  usb-installer}/hardware-configuration.nix:4` — unused `pkgs` in the standard hardware-config
  header; `packages/pymupdf4llm.nix` — unused `old` in an `overrideAttrs` callback) — same
  pre-existing-debt rationale as statix above.

### 5. Package availability (verified live against this repo's pinned nixpkgs)

Verified via `builtins.getFlake (toString ./.)` + `import flake.inputs.nixpkgs { system =
"x86_64-linux"; }` (i.e. exactly the `nixpkgs` input this repo already pins to
`github:NixOS/nixpkgs/nixos-26.05`), then `nix build --impure --no-link` for each package to
confirm they build/fetch successfully (not just evaluate):

| Package | Attr | Version | Status |
|---|---|---|---|
| nixfmt (RFC 166 official formatter) | `pkgs.nixfmt` | `1.3.1` | Built successfully from cache. `meta.description = "Official formatter for Nix code"`. |
| nixfmt-rfc-style (alias) | `pkgs.nixfmt-rfc-style` | same derivation as `pkgs.nixfmt` (`outPath` identical) | Evaluates, but **deprecated** — emits `evaluation warning: nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead`. Do not reference this attribute directly in `flake.nix`; use `pkgs.nixfmt`. |
| statix | `pkgs.statix` | `0-unstable-2026-05-14` | Built successfully from cache. |
| deadnix | `pkgs.deadnix` | `1.3.1` | Built successfully from cache. |

`nixfmt --help` also confirms its default `--width` is **100** and default `--indent` is **2** —
both match `.claude/rules/nix.md`'s existing stated conventions ("Use 2 spaces for indentation",
"Soft line limit: 100 characters") exactly, so no `--width`/`--indent` override flags are needed
anywhere (devShell, CI, or a `nix fmt` invocation) — the tool's defaults already match this repo's
documented style.

### 6. Blast radius of the initial `nix fmt` pass

Measured directly with the built `nixfmt --check` (non-mutating) against every `.nix` file in the
tree (`find . -name '*.nix' -not -path './.git/*'`, 80 files total):

- **47 files need reformatting**, **33 already conform**, **0 parse/syntax errors** — i.e. the
  first `nix fmt` pass is purely a formatting pass, not a correctness risk; every file already
  parses.
- `flake.nix` itself needs reformatting.
- Per-directory breakdown of the 80 total `.nix` files: `packages/` (16), `modules/system/` (13),
  `modules/home/email/agent-tools/` (7), `modules/home/packages/` (5), `modules/home/desktop/` (5),
  `modules/home/services/` (4), `modules/home/email/` (4), `modules/home/core/` (4), `overlays/`
  (3), `modules/home/scripts/` (3), root (`flake.nix`, `configuration.nix`, `home.nix`) (3),
  `modules/home/memory/` (2), `modules/home/` (2), `hosts/{usb-installer,nandi}/` (2 each),
  `modules/system/optional/`, `lib/`, `hosts/{iso,hamsa,garuda}/` (1 each).
- **`packages/*.nix` specifically: 14 of 16 files need reformatting** (only 2 already conform):
  `aristotle.nix`, `claude-code.nix`, `kooha.nix`, `loogle.nix`, `opencode-discord-bot.nix`,
  `opencode.nix`, `piper-bin.nix`, `piper-voices.nix`, `polkit-gnome-agent-wrapper.nix`,
  `pymupdf4llm.nix`, `python-cvc5.nix`, `python-vosk.nix`, `slidev.nix`, `vosk-models.nix`.

### 7. Sequencing against task 96 (concurrent header-comment work)

Task 96 (`documentation_completeness_gaps`, status `not_started` as of this research) is described
in state.json as covering the backlog report's Group B item 9 — adding 1-3 line header comments to
the `packages/*.nix` files that lack one. That work and this task's format pass both touch the same
14 `packages/*.nix` files. Two sequencing options, in order of preference:

1. **Preferred: run task 96 first, then this task's format pass.** A header-comment-only edit is
   small and orthogonal to reformatting; landing it first means the format pass's `nix fmt` run
   simply reformats whatever task 96 left (including its new header comments) in one deterministic
   pass, with no risk of the format pass reformatting lines that task 96 is about to add comments
   next to (avoiding a diff/merge collision on adjacent lines in the same files).
2. **Acceptable fallback: if task 96 has not landed when this task implements**, note explicitly
   in the implementation plan that `packages/*.nix` will be reformatted regardless, and that task
   96's header comments (whenever added) will need to conform to nixfmt's comment-formatting rules
   (already-conforming single-line `#` comments are untouched by nixfmt; multi-line `/* */` blocks
   would be reformatted — but `.claude/rules/nix.md` already mandates line `#` comments over block
   comments repo-wide, so this is a non-issue if task 96 follows existing conventions).

Either way, **this task's own scope does not depend on task 96 being done first** — the
dependency is purely about avoiding line-level collision/rebase noise on the same 14 files, not a
functional blocker. Task 98's `state.json` dependency is on task 97 (already completed), not task
96; this is a sequencing recommendation for the *implementation plan*, not an added
`dependencies` entry.

## Decisions

- Use `pkgs.nixfmt` (not `pkgs.nixfmt-rfc-style`) as the actual `formatter`/devShell attribute,
  despite the task description naming "nixfmt-rfc-style" — verified they are the identical
  derivation in this repo's pinned nixpkgs, and `nixfmt-rfc-style` is a deprecated alias that emits
  a stderr warning on every evaluation. This satisfies the task's intent (RFC 166 / official
  formatter) without the warning noise. Comments in the diff should mention both names so a reader
  searching for "nixfmt-rfc-style" (the name used in the task description and backlog report) finds
  the right attribute.
- Do not add a `statix.toml` or any deadnix config/exclude list for this initial pass — both tools'
  defaults are sufficient, and the task explicitly asked to "keep it minimal." A config file can be
  a follow-up once the 33 statix warnings / deadnix findings are triaged.
- Add the two new CI steps to the existing single `flake-check` job rather than a new job — avoids
  duplicate checkout/install-nix overhead for a minimal, non-blocking addition.
- Recommend `nix develop --command statix check` / `nix develop --command deadnix .` in CI over a
  bare `nix run nixpkgs#statix`/`nix shell nixpkgs#deadnix`, so CI resolves the exact same tool
  versions as the new `devShells.default` (single source of truth via `flake.lock`), keeping local
  and CI lint runs reproducibly identical.

## Risks & Mitigations

- **47 of 80 files will change in the initial format pass** — this is a large, single mechanical
  commit. Mitigate by doing it as its own dedicated commit/phase (not mixed with the flake.nix/CI
  edits), so `git blame`/history stays legible and the formatting-only diff can be
  reviewed/reverted independently of the tooling-addition diff.
- **Sequencing collision with task 96** on `packages/*.nix` (14 of 16 files touched by both) — see
  Finding 7. Mitigation: sequence format pass after task 96, or explicitly accept and note the
  fallback in the plan if task 96 hasn't landed yet.
- **Existing lint debt (33 statix warnings, several deadnix findings) predates this task** — do not
  scope-creep this task into fixing them; the user's non-blocking CI decision already accounts for
  this, and fixing lint warnings is a separate, larger, judgment-heavy task (some of statix's
  "repeated keys" suggestions and deadnix's "unused lambda pattern" findings on
  `hardware-configuration.nix` files are auto-generated NixOS files that arguably should stay as-is
  — a call for a future, dedicated lint-fix task, not this one).
- **`pkgs.nixfmt-rfc-style` deprecation**: if a future nixpkgs bump removes the alias entirely
  (not just deprecates it), any code that still referenced `nixfmt-rfc-style` would break — using
  `pkgs.nixfmt` directly now avoids inheriting that future risk.
- **`nix develop --command` in CI requires the devShell to evaluate successfully** — since
  `devShells.${system}.default` only adds three packages with no build inputs beyond fetching
  binary-cache paths, this is low-risk, but the CI edit's own verification step (a green
  `nix flake check` after the `flake.nix` edit, plus a manual `nix develop -c statix check` /
  `nix develop -c deadnix .` local run) should confirm the devShell evaluates before relying on it
  in CI.

## Appendix

### Search/verification commands used

```bash
# flake.nix structure — full Read, no grep needed
# CI config — full Read of .github/workflows/ci.yml

# .nix file census
find . -name '*.nix' -not -path './.git/*' | wc -l                 # 80
find . -name '*.nix' -not -path './.git/*' | sed 's#/[^/]*$##' | sort | uniq -c | sort -rn

# task 96/97/98 dependency status
jq -r '.active_projects[] | select(.project_number==96)' specs/state.json   # not_started
jq -r '.active_projects[] | select(.project_number==97)' specs/state.json   # completed

# Package verification against THIS repo's pinned nixpkgs (not registry/CLI search)
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
  in { nixfmt = pkgs.nixfmt-rfc-style.pname or pkgs.nixfmt-rfc-style.name;
       statix = pkgs.statix.pname or pkgs.statix.name;
       deadnix = pkgs.deadnix.pname or pkgs.deadnix.name; }'
# -> evaluation warning: nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead

nix eval --impure --expr '... pkgs.nixfmt.version ... pkgs.nixfmt-rfc-style.outPath == pkgs.nixfmt.outPath ...'
# -> same_deriv = true; nixfmt_version = "1.3.1"; statix_version = "0-unstable-2026-05-14"; deadnix_version = "1.3.1"

nix build --impure --no-link --print-out-paths --expr '... pkgs.nixfmt'     # built OK
nix build --impure --no-link --print-out-paths --expr '... pkgs.statix'    # built OK
nix build --impure --no-link --print-out-paths --expr '... pkgs.deadnix'   # built OK

# CLI surface confirmation
nixfmt --help      # -w/--width default 100, --indent default 2, -c/--check
statix --help      # subcommands: check, fix, single, explain, dump, list
statix check --help  # -c/--config <CONF_PATH> default "." (statix.toml)
deadnix --help     # -f/--fail (not default), -o/--output-format, --exclude

# Blast radius measurement (non-mutating --check loop over all 80 files)
for f in $(find . -name '*.nix' -not -path './.git/*'); do nixfmt --check "$f" ...; done
# -> total=80 needs_fmt=47 already_ok=33 errors=0
for f in packages/*.nix; do nixfmt --check "$f" ...; done   # 14 of 16 need reformatting
nixfmt --check flake.nix                                     # needs formatting

# Lint debt dry runs (non-mutating, not applied)
statix check .                    # 33 warnings (confirmed count via -o json | jq length)
deadnix .                         # several unused-binding warnings, exit 0 by default
```

### Files read in full

`flake.nix`, `.github/workflows/ci.yml`,
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md`.

### Cross-references

- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` — Group D
  (finding 13), the primary source for this task's scope and the original (now-resolved) open
  questions about formatter choice and CI strictness.
- Task 96 (`documentation_completeness_gaps`, not yet started) — concurrent work on the same
  `packages/*.nix` files; see Finding 7 for sequencing recommendation.
- Task 97 (`refactor_dead_comment_cleanup`, completed) — this task's declared `dependencies`,
  already resolved; its extraction of inline wrapper derivations into `packages/*.nix` explains why
  `packages/*.nix` now has 16 files instead of the 13 the backlog report counted.

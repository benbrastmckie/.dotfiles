# Research Report: Task #101

**Task**: 101 - Clear statix/deadnix findings from the warn-only lint tooling (task 98 follow-on)
**Started**: 2026-07-05T14:43:02Z
**Completed**: 2026-07-05
**Effort**: Medium (mechanical but touches ~20 files; one file — `modules/system/desktop.nix` — needs
careful manual reflow)
**Dependencies**: task 98 (nix formatter + lint tooling), completed
**Sources/Inputs**: Live `statix check -o json` / `deadnix . -o json` runs against the current
tree, `nix develop` devShell (statix 1.x, deadnix 1.3.1), repo source files, `statix fix --dry-run`
probe, `deadnix --exclude` probe, upstream deadnix README (skip-pragma syntax)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Findings have drifted since task 98**: statix now reports **69** warnings (not 33) across the
  same 4 rule classes — the "repeated keys" rule (W20) grew from 18 to **54** because it fires on
  every file with 3+ same-key attrpath assignments, not just the `flake.nix` home-manager block
  task 98 called out. Task 98's count of 33 was accurate for the block it inspected; it did not
  claim to be exhaustive. **deadnix's count is unchanged: 23 findings across 16 files**, exactly
  matching task 98's tally.
- `statix fix --dry-run` proves that 3 of the 4 rule classes (empty-pattern W10, assignment-
  instead-of-inherit W04, useless-parens W08 — 15 findings total) are **safely auto-fixable** with
  `statix fix`; the diff is minimal and mechanical (verified below). The 54 repeated-keys (W20)
  findings have **no statix auto-fix** (`"suggestion": null` in the JSON) and must be hand-collapsed
  file by file.
- Of the 54 repeated-keys findings, **12 (3 each × 4 files) live in auto-generated
  `hosts/*/hardware-configuration.nix`** and should be suppressed via a `statix.toml` path
  `ignore` glob, not hand-edited (confirmed: nixos-generate-config stamps a "Do not modify this
  file!" header on all four). The remaining 42 are hand-fixable; **most are safe, tight,
  mechanical wraps**, but `modules/system/desktop.nix` (7 `services.*` + 4 `programs.*`
  occurrences interleaved with unrelated per-feature comment blocks across the whole file) is a
  materially bigger, judgment-heavy edit — flagged as a risk below.
- deadnix's 23 findings split cleanly into three buckets: **11 safe-to-remove** (flake.nix's
  `lean4`/`utils`/`inputs`, home.nix's 4 args, 4 trivial `packages/*.nix` wrappers' `lib`), **8
  intentional-signature-convention** (NixOS module `lib` in boot/nix/desktop.nix mandated by this
  repo's own `nix.md` style rule; overlay `final`/`prev`/`old` args mandated by the overlay-pattern
  convention; a deliberately-dormant `config` arg in `gmail-oauth2.nix`) that should get
  `# deadnix: skip` comments rather than be deleted, and **4 auto-generated** (`hardware-
  configuration.nix` × 4, same files as the statix exclusion) that should be excluded via a CI/
  local `--exclude` flag rather than edited (deadnix has no config-file support, confirmed against
  its `--help` and README).
- Recommended order: (1) skip-comment the 8 keep-set deadnix findings first, (2) `deadnix --edit`
  the remaining 11 safe removals, (3) `statix fix` the 15 auto-fixable statix findings, (4)
  hand-collapse the 42 non-excluded repeated-keys findings per the per-file plan below, (5) add
  `statix.toml` (ignore glob) and a `deadnix --exclude` CI flag for the 4 auto-generated hardware
  files, (6) re-run `nix fmt`, then `nix flake check`, then re-run both linters to confirm zero
  findings outside the two documented exclusions.
- `nix flake check` is green on the current tree (baseline confirmed) and must stay green after
  every edit; the repeated-keys collapses are semantically inert (Nix's `a.b = x; a.c = y;` syntax
  already desugars to `a = { b = x; c = y; }` — collapsing is a pure re-nesting, not a behavior
  change), so the main verification risk is a stray syntax/indentation slip during hand-editing,
  not a semantic regression.

## Context & Scope

Task 98 added `nix fmt` (nixfmt), a `nix develop` devShell carrying `statix` and `deadnix`, and two
non-blocking (`|| true`) CI steps that surface — but do not gate on — statix/deadnix findings. Task
98's summary explicitly left the 33 statix warnings and the deadnix findings unfixed as a
"future task." This task (101) is that follow-on: get the tree to zero findings, or a small,
explicitly documented, deliberately-excluded remainder (the auto-generated hardware-configuration
files), per the task's own framing.

This is a **research-only** task. No files were edited. All commands below were run read-only
(`statix check`, `deadnix .` with no `--edit`/`--fail`, `statix fix --dry-run`) against the live
tree at commit `9313142` (branch `master`, clean working tree). A scratch copy of one file was
used outside the repo (`/tmp/.../scratchpad/boot-test.nix`) to verify the deadnix skip-pragma
placement; nothing under `/home/benjamin/.dotfiles` was modified.

## Findings

### Current statix findings (live run, `nix develop --command statix check -o json`)

**Total: 69 warnings** (up from task 98's 33), broken down by rule:

| Rule (statix code) | Count | Auto-fixable via `statix fix`? |
|---|---|---|
| W20 `repeated_keys` ("Avoid repeated keys in attribute sets") | 54 | No (`suggestion: null` in JSON) |
| W10 `empty_pattern` ("Found empty pattern in function argument") | 11 | Yes |
| W04 `manual_inherit_from` ("Assignment instead of inherit from") | 3 | Yes |
| W08 `useless_parens` ("These parentheses can be omitted") | 1 | Yes |

The count discrepancy vs. task 98 (33) is fully explained by W20: task 98's report called out "18x
repeated keys… (the home-manager.useGlobalPkgs/useUserPackages/users block in flake.nix:155-157,
collapse into one home-manager = { ... } attrset)" as if that were the whole story, but the same
rule fires on *any* file where a top-level (or nested) attribute path key repeats 3+ times at the
same level — which turns out to be the case in 16 different files across this repo, not just
`flake.nix`. (Statix appears to require **3 or more** occurrences of the same key before it flags
repetition at all — files with exactly 2 same-key assignments, e.g. `environment.etc.*` in
`modules/system/desktop.nix`, are never flagged.) The W10/W04/W08 counts match task 98's figures
exactly (11 / 3 / 1).

#### W10 — empty pattern in function argument (11, all auto-fixable to `_:`)

All are top-level module headers of the exact form `{ ... }:` used purely because the module body
never needs the module system's default args (`config`/`lib`/`pkgs`/etc.). `statix fix` rewrites
each to `_:` verbatim (verified via dry-run diff), which is semantically identical — the module
system still calls the function with one attrset argument either way.

Files (all at line 2, except `aerc.nix`/`kanshi.nix`/`swaylock.nix` at line 3, offset by a leading
comment): `modules/system/shell.nix`, `modules/system/networking.nix`,
`modules/system/services.nix`, `modules/home/core/git.nix`, `modules/home/core/xdg.nix`,
`modules/home/desktop/waybar.nix`, `modules/home/desktop/mako.nix`,
`modules/home/desktop/kanshi.nix`, `modules/home/desktop/swaylock.nix`,
`modules/home/email/aerc.nix`, `modules/home/email/protonmail.nix`.

**Recommendation**: run `statix fix` (or hand-apply `{ ... }:` → `_:`) across all 11 — zero risk,
already verified via dry-run.

#### W04 — assignment instead of inherit (3, all auto-fixable)

| File:line | Current | Fix |
|---|---|---|
| `flake.nix:55` | `lib = nixpkgs.lib;` | `inherit (nixpkgs) lib;` |
| `overlays/unstable-packages.nix:6` | `niri = pkgs-unstable.niri;` | `inherit (pkgs-unstable) niri;` |
| `overlays/unstable-packages.nix:12` | `gemini-cli = pkgs-unstable.gemini-cli;` | `inherit (pkgs-unstable) gemini-cli;` |

All three are simple direct-attribute-access assignments where the bound name equals the accessed
attribute name — the textbook case for `inherit (X) Y;`. Trailing comments on each line are
preserved verbatim by `statix fix` (confirmed in the dry-run diff). Semantically identical, zero
risk. Note: the *other* unstable-packages.nix entries (`claude-code`, `opencode`, `aristotle`,
`slidev`, `kooha`, the two `zathura`/`sioyek` wrapper lines) are correctly *not* flagged — they call
`final.callPackage`/`import`, not a bare attribute access, so `inherit` doesn't apply.

#### W08 — useless parentheses (1, auto-fixable)

`modules/system/packages.nix:5` — `environment.systemPackages = ( with pkgs; [ ... ] );` → drop the
outer parens: `environment.systemPackages = with pkgs; [ ... ];`. `statix fix`'s dry-run diff shows
this cleanly (removes the opening paren + trailing `);`, leaves the ~200-line package list
untouched). Note: this repo's own `nix.md` style rule says "Do Not: Use top-level `with pkgs;`"
generally — that's a *pre-existing, separate* style question about the surrounding `with pkgs;`
itself, not something W08 asks to change and out of scope for this lint-findings task; only the
redundant parens are in scope here.

After `statix fix` runs, a follow-up `nix fmt` pass is recommended since the auto-fix's
re-indentation is not guaranteed to match nixfmt's own opinion (observed in the `packages.nix`
dry-run diff: the `with pkgs;`/`[` lines keep their original indentation after paren removal,
which nixfmt would likely re-flow).

#### W20 — repeated keys in attribute sets (54; no auto-fix; hand-collapse per file)

Statix's fixed suggestion format is always "Try `<key> = { <rest>=...; <rest>=...; }` instead" —
i.e., take every `<key>.<rest> = <value>;` statement in the enclosing set and nest them under one
`<key> = { ... };` block. This is **semantically inert**: Nix already treats
`a.b = x; a.c = y;` as sugar for `a = { b = x; c = y; }` (recursively merged at parse time), so
collapsing does not change evaluation — it only changes surface syntax. The engineering work is
almost entirely about *how far apart* the repeated occurrences are and how many unrelated
comment blocks sit between them, since collapsing requires physically re-nesting text while
preserving every interleaved comment.

**Tier 1 — tight, low-risk, small diff** (occurrences on 2-4 adjacent/near lines):

| File | Key | Lines | Notes |
|---|---|---|---|
| `flake.nix` | `home-manager` | 155-157 (+158 `extraSpecialArgs`, folded into "1 occurrence omitted") | The exact block task 98 called out. Collapse to `home-manager = { useGlobalPkgs = true; useUserPackages = true; users.${username} = import ./home.nix; extraSpecialArgs = hmExtraSpecialArgs; };` |
| `lib/mkHost.nix` | `home-manager` | 42-44 (+1 omitted = `extraSpecialArgs`) | Mirrors the flake.nix block exactly — same collapse shape |
| `hosts/iso/default.nix` | `isoImage` | 13,14,16 | `isoImage = { edition = lib.mkForce "nandi"; compressImage = true; squashfsCompression = "zstd"; };` |
| `hosts/usb-installer/default.nix` | `isoImage` | 6,7,8 (+2 omitted) | Same shape; also check `networking.hostName` a few lines below is a *different* key (not part of this collapse) |
| `home.nix` (root) | `home` | 17,18,23 | `home = { username = "benjamin"; homeDirectory = "/home/benjamin"; stateVersion = "24.11"; };` — preserve the historical stateVersion comment block between homeDirectory and stateVersion |
| `modules/system/audio.nix` | `services` | 14,16,18 | `blueman`, `pulseaudio`, `pipewire` — 3 short, adjacent, uncommented-between lines |
| `modules/system/services.nix` | `services` | 6,12,19 (+1 omitted = `libinput`) | `printing`, `avahi`, `xserver`, `libinput` — each has its own 1-2 line comment; comments can move inline into the collapsed set without loss |
| `modules/home/email/aerc.nix` | `home` (via `home.file`) | 226,249,264 | Contained to the file's last ~50 lines (of 273) — the earlier `programs.aerc = {...}` block is untouched. Collapse to a single `home.file = { ".config/aerc/accounts.conf".text = ...; ".config/aerc/querymap-gmail".text = ...; ".config/aerc/querymap-logos".text = ...; };` |

**Tier 2 — whole-file wrap, larger diff but still mechanical/safe** (the repeated key's occurrences
effectively *are* the bulk of the file's content, each already living next to its own explanatory
comment block; wrapping the whole file body in one outer `<key> = { ... };` and stripping the
`<key>.` prefix from each line preserves every comment in its current relative position):

| File | Key | Lines (shown / total via "omitted") | Notes |
|---|---|---|---|
| `modules/system/boot.nix` | `boot` | 5,6,26 (+3 omitted = 6 total: `loader.systemd-boot.enable`, `loader.efi.canTouchEfiVariables`, `kernelPackages`, `blacklistedKernelModules`, `kernelParams`, `extraModprobeConfig`) | Whole file (54 lines) is `boot.*` assignments interleaved with large Ryzen-specific comment blocks; wrap the entire body in `boot = { ... };`, dropping the `boot.` prefix on all 6, re-flow with `nix fmt` after |
| `modules/home/core/dotfiles.nix` | `home` | 7,21,59 (+2 omitted) | `sessionVariables`, `file` (the big block), `file.".zuliprc".source` — note the suggested collapse keeps `file=...` and `file.".zuliprc".source=...;` as two *separate* statements inside the merged `home = {...}`, i.e. this is not a full recursive collapse, just one level |
| `modules/home/core/xdg.nix` | `xdg` | 5,10,24 | `enable`, `dataFile."applications/sioyek.desktop".text`, `mimeApps` — whole file, wrap in `xdg = { ... };` |
| `modules/system/power.nix` | `services` | 12,28,52 (+1 omitted = `power-profiles-daemon.enable`, `udev.extraRules`, `fwupd.enable`) | These 3 are separated by large feature-specific comment blocks (the udev ACPI rules explanation is ~15 lines); the *other* top-level keys in this file (`powerManagement`, `systemd.services.init-power-profile`) have only 1 occurrence each and are untouched/interspersed — so this collapse must skip over them, not absorb them |

**Tier 3 — genuinely awkward; flag as an implementation-time judgment call, not a blocker**:

| File | Keys | Lines | Why it's harder |
|---|---|---|---|
| `modules/system/desktop.nix` | `services` (7 occurrences: 5,7,38,62,66,85,92) **and** `programs` (4 occurrences: 20,48,63,89) | whole 124-line file | This file interleaves `services.*` and `programs.*` with *other*, non-repeated keys (`environment.etc.*` × 2, `hardware.graphics`, `security.polkit.enable`, `xdg.portal`) in a deliberate "one comment block per desktop feature, in UI-relevant order" narrative (GDM → dconf wallpaper → GNOME desktop → niri → wayland hardware → GNOME services → XDG portal). Fully collapsing `services` and `programs` each into one attrset requires *physically relocating* 7 and 4 non-contiguous chunks respectively, which either drags unrelated single-use keys along for the ride or breaks the current "read top to bottom as a feature walkthrough" structure. It is still 100% safe (no semantic risk — same desugaring argument as Tier 1/2), but it is the single largest, most judgment-heavy diff in this cleanup and deserves its own careful pass (and possibly its own commit) separate from the more mechanical Tier 1/2 files. |

**Tier 4 — auto-generated, exclude via `statix.toml`, do not hand-edit** (12 findings, 3 per file):

`hosts/garuda/hardware-configuration.nix` (17,25,26), `hosts/hamsa/hardware-configuration.nix`
(17,24,25), `hosts/nandi/hardware-configuration.nix` (17,25,26),
`hosts/usb-installer/hardware-configuration.nix` (18,30,31) — all four are the standard
`nixos-generate-config` `boot.initrd.availableKernelModules = [...]; boot.initrd.kernelModules =
[...]; boot.kernelModules = [...];` triple. All four files carry the literal header comment "Do
not modify this file! It was generated by 'nixos-generate-config' and may be overwritten by future
invocations." (verified via `head -3` on all four). Hand-collapsing these would be silently
reverted the next time `nixos-generate-config` regenerates the file — matching the same rationale
task 98's note already applied to deadnix's 4 hardware-configuration.nix hits.

**Verified exclusion mechanism**: a `statix.toml` at the repo root with
```toml
disabled = []
ignore = [".direnv", "hosts/*/hardware-configuration.nix"]
```
was tested locally (`statix check -c <that file> -o json`) and correctly drops all findings in the
4 hardware-configuration.nix files to zero while leaving every other finding untouched (23 files
still reporting, down from 27, with zero of them being a hardware-configuration.nix path).
`statix check`'s `--config`/`-c` flag defaults to `.` (repo root), so **no `ci.yml` change is
needed** for this — CI's existing `nix develop --command statix check || true` will pick up
`statix.toml` automatically once it's added.

### Current deadnix findings (live run, `nix develop --command deadnix . -o json`)

**Total: 23 findings across 16 files — unchanged from task 98's count.** Full list:

| File | Unused binding(s) | Line(s) |
|---|---|---|
| `flake.nix` | `lean4`, `utils`, `inputs` | 45, 49, 52 |
| `home.nix` | `config`, `pkgs`, `pkgs-unstable`, `lectic` | 2-5 |
| `packages/aristotle.nix` | `lib` | 4 |
| `packages/claude-code.nix` | `lib` | 7 |
| `packages/polkit-gnome-agent-wrapper.nix` | `lib` | 4 |
| `packages/slidev.nix` | `lib` | 4 |
| `modules/home/services/gmail-oauth2.nix` | `config` | 19 |
| `modules/system/boot.nix` | `lib` | 2 |
| `modules/system/nix.nix` | `lib` | 2 |
| `modules/system/desktop.nix` | `lib` | 2 |
| `overlays/claude-squad.nix` | `prev` | 3 |
| `overlays/python-packages.nix` | `final`, `old`, `old` | 3, 9, 12 |
| `hosts/garuda/hardware-configuration.nix` | `pkgs` | 7 |
| `hosts/hamsa/hardware-configuration.nix` | `pkgs` | 7 |
| `hosts/nandi/hardware-configuration.nix` | `pkgs` | 7 |
| `hosts/usb-installer/hardware-configuration.nix` | `pkgs` | 7 |

#### Classification

**Safe to remove (11 findings, 7 files)**:
- `flake.nix:45,49,52` (`lean4`, `utils`, `inputs`). Verified via grep: `lean4` and `utils`
  (flake-utils) are declared in `inputs = {...}` and destructured in the `outputs = { ... }@inputs:`
  header, but never referenced anywhere in the `outputs` body — no `lean4.*` host module, no
  `utils.lib.eachSystem` call (this is intentionally a single-system flake per task 98/61 history).
  `inputs` (the `@inputs` alias) is also unreferenced since every input the body needs is
  destructured by name directly. Removing these three from the `outputs` function header does
  **not** remove the `lean4`/`utils` flake inputs themselves (those stay in `inputs = {...}` and
  stay locked in `flake.lock`); it only removes the now-dead destructured bindings.
- `home.nix:2-5` (`config`, `pkgs`, `pkgs-unstable`, `lectic`). None of the four is referenced in
  the file body (only `imports`, `home.username`, `home.homeDirectory`, `home.stateVersion`).
  Home-manager's module system still supplies all of these (plus `username`/`name`) via
  `extraSpecialArgs`/its own module args regardless of whether `home.nix`'s function signature
  destructures them — so removing them (down to `_:`) is functionally identical to today. Flagged
  as slightly lower-confidence than the flake.nix case only because `home.nix` is the single most
  central entry point in the repo (imported by both the NixOS-integrated and standalone
  home-manager paths) — worth a quick "does removing all 4 make future edits to this exact file
  harder" gut-check during planning, but there is no style-guide mandate (unlike the NixOS-module
  `lib` case below) requiring these names stay.
- `packages/aristotle.nix:4`, `packages/claude-code.nix:7`, `packages/polkit-gnome-agent-
  wrapper.nix:4`, `packages/slidev.nix:4` — all four are trivial `writeShellScriptBin` wrappers
  (`callPackage`-invoked from the overlays) whose bodies never reference `lib` (verified: no
  `lib.` occurrence in any of the four). Unlike the NixOS module case, `callPackage` auto-resolves
  whatever a derivation's signature asks for — there is no repo convention requiring these small
  wrapper packages to declare an unused `lib`. Safe to drop.

**Intentional signature convention — keep, add `# deadnix: skip` (8 findings, 6 files)**:
- `modules/system/boot.nix:2`, `modules/system/nix.nix:2`, `modules/system/desktop.nix:2` — all
  three use the exact `{ pkgs, lib, ... }:` header this repo's own `.claude/rules/nix.md` mandates
  verbatim under "Standard Function Signatures: Always use the `{ config, lib, pkgs, ... }:`
  pattern." `lib` genuinely is unused today in all three bodies (double-checked via
  `grep -n "lib\."` — zero hits in each), but removing it would contradict the project's own
  documented style rule and would need to be re-added the moment any of these modules needs
  `lib.mkIf`/`lib.mkForce`/etc. — a near-certainty for NixOS hardware/desktop modules over time.
  Recommend a `# deadnix: skip` comment on the line above the header in each file rather than
  deletion.
- `overlays/claude-squad.nix:3` (`prev`) and `overlays/python-packages.nix:3` (`final`) — this
  repo's `nix.md` "Overlay Patterns" section mandates the `final: prev:` naming for every overlay
  in the repo (not `self`/`super`), specifically for consistency across the 3 overlays composed
  together in `flake.nix`'s `nixpkgsConfig.overlays` list. `claude-squad.nix` doesn't override an
  existing package (pure `buildGoModule` addition) so never needs `prev`; `python-packages.nix`'s
  outer `final: prev:` only uses `prev` (for the two `overridePythonAttrs` calls) but never `final`
  at that outer scope. Recommend keeping both for consistency with the mandated pattern, with skip
  comments.
- `overlays/python-packages.nix:9,12` (`old`, `old` — the `overridePythonAttrs (old: { doCheck =
  false; })` callback argument, twice). Weaker case than the `final`/`prev` one — no explicit
  in-repo rule mandates naming an unused `overrideAttrs`-style callback arg `old`, but it is a very
  strong nixpkgs-wide idiom (readers instantly recognize `(old: {...})` as the override-callback
  shape even when `old.*` isn't referenced). Judgment call: **recommend keeping with skip comments
  for consistency with the idiom**, but renaming both to `_: { doCheck = false; }` is an equally
  valid, slightly-lower-friction alternative if the plan prefers minimizing skip-comment count.
- `modules/home/services/gmail-oauth2.nix:19` (`config`). The entire module body is commented out;
  the file's own header comment explains this is a deliberate, documented, "one-block-revert"
  dormant state (disabled 2026-07-02, task 72) — the commented-out systemd block references
  `${config.home.homeDirectory}` at (commented) line 28. Keeping the `config` arg in the live
  signature is what makes the promised "uncomment below" revert actually a single block (no
  signature edit needed on revert). Recommend a skip comment, not removal.

**Auto-generated — exclude via CLI flag, do not edit (4 findings, 4 files)**:
- `hosts/{garuda,hamsa,nandi,usb-installer}/hardware-configuration.nix:7` (`pkgs`, in each file's
  `{ config, lib, pkgs, modulesPath, ... }:` header). Same "Do not modify this file!" auto-generated
  header as the statix W20 hits in these same 4 files. **deadnix has no config-file mechanism**
  (confirmed against `deadnix --help` and the upstream README — CLI-only, no `.deadnix.toml`
  equivalent), so exclusion must be a CLI flag change to the existing CI `run:` line:
  `nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' -- . || true` (glob
  needs quoting so the shell doesn't expand it before deadnix sees it; verified `--exclude
  <paths...> -- <FILE_PATHS...>` works locally with explicit paths). This is the one place a
  `ci.yml` edit is required (unlike statix's config-file-based exclusion above); worth also noting
  in a local dev-facing doc (e.g. README or the devShell's `shellHook`) so a developer running
  `deadnix .` locally by hand sees the same expected-clean baseline.

## Decisions

- **Treat the current live findings (69 statix / 23 deadnix), not task 98's stale 33/23 snapshot,
  as the source of truth for planning** — task 98's report undercounted W20 because it only
  inspected the block it was asked to inspect; nothing in the codebase changed between task 98 and
  now (confirmed: no commits touched `.nix` files since task 98's formatting commit `8bc1aee`), so
  this is a measurement gap, not code drift.
- **Prefer `statix fix` for the 3 auto-fixable rule classes (W10/W04/W08, 15 findings)** rather than
  hand-editing — dry-run diffs were inspected and are exactly the expected minimal changes with all
  comments preserved.
- **Do not use `statix fix` or `deadnix --edit` for W20 (repeated keys) or the deadnix
  keep-set** — W20 has no auto-fix at all (must hand-edit), and `deadnix --edit` would blindly
  strip the 8 intentional-convention bindings unless skip comments are added first.
- **Exclude, don't edit, the 4 auto-generated `hosts/*/hardware-configuration.nix` files** for both
  linters — statix via a repo-root `statix.toml` `ignore` glob (no CI change needed, verified), and
  deadnix via a CLI `--exclude` flag addition in `ci.yml` (deadnix has no config-file mechanism).
- **`modules/system/desktop.nix`'s W20 findings are a distinct, larger-scope edit** and should be
  called out as its own plan phase/step rather than bundled anonymously with the other ~13
  W20 file-fixes, given the file's deliberate interleaved-narrative structure.

## Risks & Mitigations

- **Risk**: hand-collapsing W20 findings introduces a stray brace/semicolon error.
  **Mitigation**: `nix flake check` (currently green, verified) after every file's edit, plus a
  final full-tree `nix fmt` pass to normalize formatting before the final `statix check`/`deadnix .`
  re-run.
- **Risk**: collapsing `modules/system/desktop.nix` or `modules/system/power.nix` degrades
  readability by separating a feature's code from its explanatory comment, or by requiring
  comments to be merged/reordered.
  **Mitigation**: for Tier 2/3 files, collapse by literally wrapping the *existing* line range in
  one outer `<key> = { ... };` and stripping the repeated prefix — this preserves every comment's
  current relative position exactly; nothing needs to move. Only `desktop.nix`'s two keys
  (`services`, `programs`) are non-contiguous enough that pure wrapping isn't possible without
  interleaving unrelated keys — that file should get deliberate manual review, not a mechanical
  script.
- **Risk**: `deadnix --edit` run before skip comments are in place silently deletes one of the 8
  intentional-convention bindings.
  **Mitigation**: sequence the plan as skip-comments-first, `--edit`-second (as recommended above),
  and diff-review the `--edit` output before committing.
- **Risk**: regenerating a host's `hardware-configuration.nix` (e.g., after new hardware or a
  `nixos-generate-config` re-run) silently reintroduces the excluded findings in a *slightly*
  different shape (line numbers shift) and someone "fixes" it by hand later, causing repeated
  churn.
  **Mitigation**: the `statix.toml` `ignore` glob (`hosts/*/hardware-configuration.nix`) and the
  `deadnix --exclude` CLI glob both match by *path*, not by line number, so they remain valid
  after regeneration with no maintenance needed — this should be called out in the plan/commit
  message so a future contributor understands why these 4 files are exempt rather than assuming
  it's an oversight.
- **Risk**: `nix fmt`'s re-indentation after `statix fix`/hand-edits could reintroduce a *new*
  statix/deadnix finding (e.g., nixfmt collapsing a multi-line form back into something that
  re-triggers W20 or W08).
  **Mitigation**: the verification sequence below runs the linters *after* the final `nix fmt`
  pass, not before, so this would be caught before task completion.

## Recommended Verification Sequence

1. Add `# deadnix: skip` comments to the 8 keep-set bindings (verified pragma placement: on the
   line immediately above the line containing the flagged binding — tested locally against a
   scratch copy of `modules/system/boot.nix`, confirms `deadnix` reports zero for that file once
   the pragma is added above the `{ pkgs, lib, ... }:` header).
2. Run `deadnix --edit .` (excluding, or immediately followed by manually reverting, the 4
   hardware-configuration.nix files if not yet CLI-excluded) to remove the 11 safe deadnix
   bindings; diff-review.
3. Run `statix fix` (whole tree) to apply the 15 auto-fixable statix findings (W10/W04/W08);
   diff-review against the dry-run output already captured in this report.
4. Hand-collapse the 42 non-excluded W20 findings per the Tier 1/2/3 breakdown above, file by
   file, running `nix flake check` after each file (or small batch).
5. Add `statix.toml` (`disabled = []`, `ignore = [".direnv", "hosts/*/hardware-configuration.nix"]`)
   at the repo root.
6. Update `.github/workflows/ci.yml`'s deadnix step to
   `nix develop --command deadnix --exclude 'hosts/*/hardware-configuration.nix' -- . || true`.
7. Run `nix fmt $(git ls-files '*.nix')` (matching task 98's documented invocation, to sidestep the
   known `./result`-symlink issue) to normalize formatting.
8. Final verification: `nix flake check` (must stay green — baseline confirmed green in this
   research pass), then `statix check` (expect zero findings tree-wide, since hardware-config is
   now ignored via config file) and `deadnix --exclude 'hosts/*/hardware-configuration.nix' -- .`
   (expect zero findings). Optionally, consider (as a separate, out-of-scope-for-this-task
   follow-up) tightening the two CI steps from non-blocking `|| true` to hard-gating now that the
   tree is clean — noted here only as a future option, not a requirement of this task.

## Appendix

### Commands run during research

```bash
nix develop --command statix check -o json          # 69 findings, 27 files
nix develop --command deadnix . -o json              # 23 findings, 16 files (jsonlines, one per file)
nix develop --command statix fix --dry-run            # confirms 15/69 auto-fixable, exact diffs inspected
nix develop --command statix dump                     # confirms statix.toml schema (disabled/ignore)
nix develop --command statix list                     # confirms W01-W23 rule code table
nix develop --command deadnix --exclude <4 hw-config paths> -- .   # confirms --exclude mechanics
nix flake check                                        # baseline green, confirmed before and assumed after
```

### statix.toml probe (verified locally, not committed)

```toml
disabled = []
ignore = [".direnv", "hosts/*/hardware-configuration.nix"]
```
`statix check -c <path-to-this-file> -o json` dropped from 27 files-with-findings to 23, with zero
of the 23 being a `hardware-configuration.nix` path.

### deadnix skip-pragma probe (verified locally, not committed)

Adding a `# deadnix: skip` comment line directly above `{ pkgs, lib, ... }:` in a scratch copy of
`modules/system/boot.nix` (outside the repo, under the session scratchpad) caused `deadnix` to
report zero findings for that file, confirming the pragma placement described in deadnix's
upstream README.

### References

- [astro/deadnix GitHub](https://github.com/astro/deadnix) — skip-pragma syntax (`# deadnix: skip`),
  underscore-prefix handling, `--exclude` CLI flag, no config-file support.

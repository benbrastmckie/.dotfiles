# Implementation Plan: Task #134

- **Task**: 134 - Pin aeneas/charon to Verification revision
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours (excluding any unexpected source build)
- **Dependencies**: None
- **Research Inputs**: specs/134_pin_aeneas_charon_to_verification_revision/reports/01_pin-aeneas-charon-revision.md
- **Artifacts**: plans/01_pin-aeneas-charon-revision.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The floating `aeneas.url` input drifted to aeneas `86158eb` / charon `b104e24`, so the
Verification repo's `framed_channel/check.sh` "aeneas revision coherence" stage fails. The fix
pins `aeneas.url` to `227f4e7ac70d687a6b1a4871b3304f5a1c6994bf` (whose own lockfile resolves
charon to `a5591f6b94c8575a6ba2ae71090614a722f2b011`, live-verified in research), re-locks only
that input, adds `hacl.cachix.org` as a trusted substituter so both packages are fetched rather
than compiled, and corrects the stale flake.nix comment. Done when `aeneas -version` and
`charon version` on PATH report the pinned revisions and Verification's coherence stage prints
all `[ok]`.

### Research Integration

- Pinning aeneas alone is sufficient; no charon override/follows needed (pinned rev's lock names
  charon `a5591f6`).
- `lib/mkHost.nix` and `modules/home/packages/misc.nix` need no changes.
- `hacl.cachix.org` serves signed narinfos for both exact store paths
  (`8psy457a...-charon`, `64zn9jy2...-ocaml5.2.1-aeneas-0.1.0`).
- Substituter belongs in `modules/system/nix.nix`'s existing `nix.settings` block; the
  unprivileged user is not a trusted-user, so per-invocation `--extra-substituters` is ignored
  for it.
- Re-lock narrowly (only the aeneas input), never a full `nix flake update`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (not provided in dispatch).

## Goals & Non-Goals

**Goals**:
- Pin `aeneas.url` to exact revision `227f4e7...`; lock charon to `a5591f6...`.
- Add `hacl.cachix.org` substituter + key system-wide.
- Update the flake.nix comment to reflect the pin rationale and the cache.
- Verify on PATH and via Verification's `check.sh` coherence stage.

**Non-Goals**:
- Moving any other flake input (nixpkgs, home-manager, etc.).
- Changing `lib/mkHost.nix` or `modules/home/packages/misc.nix`.
- Automating future re-pins against Verification.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Substituter not yet active in the daemon during the same rebuild that first needs the new aeneas/charon paths, causing a multi-hour source build | H | M | Sequence: activate the nix.nix substituter change first (Phase 2 switch, where aeneas is still the old, already-built revision), and only then build the pinned aeneas (Phase 3). Alternative for a single rebuild: run the root-owned rebuild with `--option extra-substituters https://hacl.cachix.org --option extra-trusted-public-keys <key>` (root is trusted). |
| `nix flake lock --update-input` is deprecated/renamed in the installed Nix | L | M | Use `nix flake update aeneas` (current syntax) or simply `nix flake lock` (re-locks the input whose URL changed); confirm the lock diff touches only aeneas-subtree nodes. |
| Lock diff moves unrelated inputs | M | L | Inspect `git diff flake.lock`; only `aeneas` and its nested nodes (charon, their own nixpkgs/rust-overlay etc.) may change. Revert and retry narrowly otherwise. |
| `substituters` list clobbers `cache.nixos.org` | H | L | listOf-merge semantics extend the default; confirm post-switch via `grep substituters /etc/nix/nix.conf` showing both caches. |
| Rebuild requires sudo, unavailable to the implementing agent non-interactively | M | M | If `sudo -n true` fails, stop after committing the config and lock changes, mark the rebuild/verification phases [BLOCKED] with the exact commands for the user to run. |
| Pinned store paths no longer on the cache | L | L | Falls back to source build (slow, not broken); note in summary. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases are strictly sequential (the substituter must be live before the pinned build).

### Phase 1: Edit configuration and re-lock aeneas [NOT STARTED]

**Goal**: Land all source changes: pin, comment, substituter, narrow lock update.

**Tasks**:
- [ ] `flake.nix`: change `aeneas.url = "github:AeneasVerif/aeneas";` to
      `aeneas.url = "github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf";`
- [ ] `flake.nix`: rewrite the comment block above it — keep the "not nixpkgs-follows" rationale
      (own OCaml 5.2 / Rust nightly toolchains), replace the "no public binary cache" sentence
      with: pinned to the exact revision the Logos Verification toolchain expects (its
      `charon-pin` names charon a5591f6) so any move is deliberate and made in lockstep; binaries
      are substituted from hacl.cachix.org (configured in `modules/system/nix.nix`).
- [ ] `modules/system/nix.nix`: inside `nix.settings`, add
      `substituters = [ "https://hacl.cachix.org" ];` and
      `trusted-public-keys = [ "hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=" ];`
      with a short comment (HACL*/Aeneas project cache; serves aeneas/charon outputs).
- [ ] Re-lock only aeneas: `nix flake update aeneas` (or `nix flake lock` if the former is
      unavailable).
- [ ] Confirm lock: `jq -r '.nodes.aeneas.locked.rev, .nodes.charon.locked.rev' flake.lock`
      prints `227f4e7...` and `a5591f6...` (node names may be suffixed, e.g. `charon_2`; resolve
      via `.nodes.aeneas.inputs.charon`).
- [ ] `nix fmt`/formatter if the repo uses one (check flake `formatter` output); keep style.
- [ ] Commit `flake.nix`, `flake.lock`, `modules/system/nix.nix` (explicit file list).

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: Exactly three files change (flake.nix, flake.lock, modules/system/nix.nix).
Confirm with `git status --short`; flake.lock diff must touch only the aeneas subtree nodes.

**Files to modify**:
- `flake.nix` - pin URL, update comment
- `flake.lock` - aeneas/charon lock entries
- `modules/system/nix.nix` - substituters + trusted-public-keys

**Verification**:
- `nix flake check` (or at minimum `nix eval .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath`) succeeds.
- `nix eval --raw .#nixosConfigurations.hamsa.config.nix.settings.substituters --apply 'builtins.concatStringsSep " "'`
  lists both `https://hacl.cachix.org` and `https://cache.nixos.org/`.
- `nix eval --raw 'github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf#packages.x86_64-linux.charon.outPath'`
  equals the research store path `/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon`.

---

### Phase 2: Activate the substituter in the daemon [NOT STARTED]

**Goal**: Make hacl.cachix.org live in `/etc/nix/nix.conf` before the pinned packages are built.

**Tasks**:
- [ ] Check `sudo -n true`; if sudo is unavailable non-interactively, mark this and later phases
      [BLOCKED] and hand the user the exact command sequence (below).
- [ ] Preferred single-step path: `sudo nixos-rebuild switch --flake .#hamsa --option extra-substituters https://hacl.cachix.org --option extra-trusted-public-keys hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=`
      (root is trusted, so the options apply to this build; this also completes Phase 3's build).
      Before running, preview with `nixos-rebuild dry-build --flake .#hamsa` plus the same options
      and confirm charon/aeneas appear under "will be fetched", not "will be built".
- [ ] If the dry-build preview still shows charon/aeneas "will be built", do NOT proceed with a
      multi-hour source build: check the narinfo is still served
      (`curl -sI https://hacl.cachix.org/8psy457ay66wy4flknrfbh6ddzw9k93z.narinfo`), and if the
      cache no longer has the paths, stop and report (user decides whether to accept the
      source build).

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- none (system activation only)

**Verification**:
- `grep -E '^(substituters|trusted-public-keys)' /etc/nix/nix.conf` shows both cache.nixos.org and
  hacl.cachix.org entries and both keys.
- Build log shows `copying path '...-charon' from 'https://hacl.cachix.org'` (and likewise for
  aeneas), not a compile.

---

### Phase 3: Confirm pinned binaries on PATH [NOT STARTED]

**Goal**: Verify the installed tools report the pinned revisions.

**Tasks**:
- [ ] Open a fresh shell (or `hash -r`); `readlink -f "$(command -v charon)"` and
      `readlink -f "$(command -v aeneas)"` resolve to the research store paths.
- [ ] `charon version` parenthesized suffix == `a5591f6b94c8575a6ba2ae71090614a722f2b011`
      (parse with `sed -n 's/.*(\([0-9a-f]*\)).*/\1/p'`, the same parsing `aeneas-revs.sh` uses).
- [ ] `aeneas -version` output is a prefix of `227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`.

**Timing**: 10 minutes

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- none

**Verification**:
- Both revision checks pass exactly as stated above.

---

### Phase 4: Run Verification coherence gate [NOT STARTED]

**Goal**: Meet the acceptance criterion in the real Verification repo, using the normal store.

**Tasks**:
- [ ] From `~/Projects/Logos/Verification`, run `bash framed_channel/check.sh` in the
      environment that repo's preflight requires (its own `nix develop` if charon/aeneas/jq must
      come from there; otherwise the rebuilt system PATH), with no scratch/alternate Nix store.
- [ ] Confirm the `== aeneas revision coherence ==` section prints only `[ok]` lines (notably
      "aeneas on PATH" and "charon on PATH matches Aeneas's charon-pin"). Later, unrelated stages
      failing is out of scope; record them in the summary but do not fix them here.
- [ ] Do not modify any file in the Verification repo.

**Timing**: 20 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- none

**Verification**:
- Coherence stage all `[ok]`; output excerpt captured in the implementation summary.

## Testing & Validation

- [ ] `nix flake check` passes (or the hamsa toplevel evaluates, if flake check is too costly).
- [ ] flake.lock: aeneas rev `227f4e7...`, charon rev `a5591f6...`; no unrelated input moved.
- [ ] `/etc/nix/nix.conf` lists cache.nixos.org and hacl.cachix.org with both keys.
- [ ] charon/aeneas were substituted, not compiled.
- [ ] `charon version` -> `a5591f6...`; `aeneas -version` prefix of `227f4e7...`.
- [ ] Verification `check.sh` coherence stage all `[ok]`.

## Artifacts & Outputs

- `flake.nix`, `flake.lock`, `modules/system/nix.nix` (committed changes)
- `specs/134_pin_aeneas_charon_to_verification_revision/summaries/01_pin-aeneas-charon-revision-summary.md`

## Rollback/Contingency

- Configuration: `git revert` the Phase 1 commit (restores floating URL, old lock, no cache).
- System: `sudo nixos-rebuild switch --rollback` (or select the previous generation at boot)
  returns to the prior aeneas/charon and nix.conf.
- If only the cache is problematic (e.g. signature failures), remove the two `nix.settings`
  entries; the pin still works, merely building from source.

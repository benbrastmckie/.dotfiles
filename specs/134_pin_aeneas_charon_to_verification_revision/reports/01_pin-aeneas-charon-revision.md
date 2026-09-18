# Research Report: Task #134

**Task**: 134 - Pin aeneas/charon to Verification revision
**Started**: 2026-09-18T22:22:41Z
**Completed**: 2026-09-18T22:40:00Z
**Effort**: Small (1 flake input pin, 1 optional nix.settings addition, 1 comment update, verification only — no code logic changes)
**Dependencies**: None (builds on the aeneas/charon integration already completed in a prior task)
**Sources/Inputs**: Local flake.nix/flake.lock, lib/mkHost.nix, modules/home/packages/misc.nix, modules/system/nix.nix, ~/Projects/Logos/Verification's flake.lock/aeneas-revs.sh/check.sh, live `nix flake metadata`/`nix eval`/`curl` probes against github:AeneasVerif/aeneas and hacl.cachix.org
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The fix is a one-line change: pin `aeneas.url` in `flake.nix` from
  `"github:AeneasVerif/aeneas"` to
  `"github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf"`. Live-verified via
  `nix flake metadata` that this exact revision's own flake.lock resolves its `charon` input to
  `a5591f6b94c8575a6ba2ae71090614a722f2b011` — precisely the revision Verification's
  `charon-pin` file names and the revision `~/Projects/Logos/Verification/flake.lock` itself
  locks. No manual charon override is needed; pinning aeneas alone is sufficient and correct.
- `flake.lock` must be regenerated (`nix flake lock --update-input aeneas`, or a full
  `nix flake update` is NOT wanted — only the aeneas input should move) so the lockfile's
  `nodes.aeneas.locked.rev` becomes `227f4e7...` and `nodes.charon.locked.rev` becomes
  `a5591f6...`.
- No code changes are needed in `lib/mkHost.nix` or `modules/home/packages/misc.nix` —
  `aeneas-charon`/`aeneas-aeneas` are already wired as `aeneas.packages.${system}.charon` /
  `.aeneas`; they will automatically resolve to the new pinned outputs once the input is
  repinned and the lockfile updated.
- The `hacl.cachix.org` substituter recommendation is real and independently verified: I probed
  the exact store paths this pinned revision's `charon` and `aeneas` packages evaluate to
  (`/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon` and
  `/nix/store/64zn9jy24zngxqkyy0z5mrh4xcmk7w6l-ocaml5.2.1-aeneas-0.1.0`) and both return HTTP 200
  `.narinfo` from `https://hacl.cachix.org`, signed `hacl.cachix.org-1:...` — matching the key
  given in the task description exactly. Adding it as a substituter will make the rebuild fetch
  both packages instead of compiling from source (a multi-hour OCaml/Rust build otherwise).
- Recommended location for the substituter/key addition: `modules/system/nix.nix`'s existing
  `nix.settings` block (it already sets `experimental-features`, `auto-optimise-store`,
  `max-jobs`, `cores` there) — add `substituters` and `trusted-public-keys` list entries.
  NixOS's `listOf str` option-merge semantics concatenate contributions across modules (verified:
  this host's current `/etc/nix/nix.conf` substituters/trusted-public-keys come only from the
  base NixOS module default, `https://cache.nixos.org`), so adding the hacl entries here will
  extend, not replace, the existing cache list.
- The stale explanatory comment on the `aeneas.url` input in `flake.nix` ("No public binary
  cache is documented for these outputs, so the first build compiles both packages from
  source") must be updated to reflect the now-available hacl.cachix.org cache, and should keep
  the still-true rationale for not following our nixpkgs (Aeneas pins its own OCaml/Rust
  toolchains).

## Context & Scope

Task 132 previously wired the Aeneas flake input (`aeneas.url = "github:AeneasVerif/aeneas"`,
unpinned/floating) into this config, exposing `aeneas-charon`/`aeneas-aeneas` via
`hmExtraSpecialArgs` (flake.nix) and the NixOS-integrated home-manager path
(`lib/mkHost.nix`), consumed by `modules/home/packages/misc.nix`. At that time no binary cache
was documented, so the flake.nix comment says so.

Since then, `~/Projects/Logos/Verification`'s `framed_channel/check.sh` gate
(`aeneas-revs.sh`'s `aeneas_rev_coherence` function) started failing its "aeneas revision
coherence" stage because the floating `aeneas.url` input has drifted: this repo's
`flake.lock` currently locks aeneas at `86158eb2e18944c5225959712efb96bce188f40d` (with charon
at `b104e24fea7d721b71e6c39fd70f26ff20bc0980`, confirmed live: `charon version` on PATH reports
`0.1.254 (b104e24fea7d721b71e6c39fd70f26ff20bc0980)`), while Verification's own
`framed_channel/aeneas/lake-manifest.json` / `lakefile.toml` / `flake.lock` all pin aeneas at
`227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`, whose `charon-pin` file (fetched into
`framed_channel/aeneas/.lake/packages/aeneas/charon-pin`) names charon
`a5591f6b94c8575a6ba2ae71090614a722f2b011`.

This task's scope: (1) pin the input to the exact revision so it stops floating, (2) verify the
resulting charon matches, (3) optionally add the hacl.cachix.org substituter/key so the rebuild
doesn't have to compile from source, (4) fix the now-stale flake.nix comment.

## Findings

### Existing Configuration

- `flake.nix:35` — `aeneas.url = "github:AeneasVerif/aeneas";` (floating, no `inputs.nixpkgs.follows`
  by design — comment explains Aeneas needs its own OCaml 5.2 toolchain and Charon its own Rust
  nightly).
- `flake.nix:31-34` — the comment block immediately above the input that needs its final
  sentence updated:
  ```
  # Aeneas (Charon + Aeneas): Rust MIR -> LLBC -> Lean/Coq/F*/HOL4 verification pipeline.
  # Deliberately NOT `inputs.nixpkgs.follows`-ed: upstream pins its own nixpkgs for the
  # OCaml 5.2 toolchain Aeneas needs, and Charon pins its own Rust nightly; following our
  # nixpkgs (nixos-26.05) would break the build. No public binary cache is documented for
  # these outputs, so the first build compiles both packages from source.
  ```
- `flake.nix:116-117` (`hmExtraSpecialArgs`) and `lib/mkHost.nix:53-54` (NixOS-integrated
  home-manager's `extraSpecialArgs`) both resolve `aeneas-charon = aeneas.packages.${system}.charon;`
  and `aeneas-aeneas = aeneas.packages.${system}.aeneas;` — these need no changes; they will pick
  up the new pinned outputs automatically once `aeneas.url` is repinned and the lock updated.
- `modules/home/packages/misc.nix:10-11,23-24` consumes `aeneas-charon`/`aeneas-aeneas` as plain
  `home.packages` entries — no changes needed.
- `flake.lock` `nodes.aeneas.locked` currently: `rev = "86158eb2e18944c5225959712efb96bce188f40d"`,
  `lastModified = 1789567822`. `nodes.charon.locked` (nested under aeneas's own inputs):
  `rev = "b104e24fea7d721b71e6c39fd70f26ff20bc0980"`.
- `modules/system/nix.nix` already has a `nix.settings = { experimental-features = [...]; auto-optimise-store = true; max-jobs = 2; cores = 6; }` block and is imported unconditionally via
  `modules/system/default.nix` for every host — the natural home for the new
  `substituters`/`trusted-public-keys` entries.
- Repo-wide grep confirms no existing `substituters`/`trusted-public-keys`/`cachix`/`nixConfig`
  reference anywhere in `*.nix` — this is a clean addition, not a merge with prior cache config.
- Live check: `/etc/nix/nix.conf` on this host currently has only
  `substituters = https://cache.nixos.org/` and
  `trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=` —
  i.e. today's NixOS-module defaults, confirming a `nix.settings.substituters = [ "https://hacl.cachix.org" ];`
  addition in `modules/system/nix.nix` will extend (concatenate with) rather than clobber this
  list, since `listOf str`-typed NixOS options merge contributions across modules by default.

### Verification-Repo Expectations (ground truth for the pin)

- `~/Projects/Logos/Verification/flake.lock`: `nodes.aeneas.locked.rev = "227f4e7ac70d687a6b1a4871b3304f5a1c6994bf"`;
  `nodes.charon.locked.rev = "a5591f6b94c8575a6ba2ae71090614a722f2b011"`.
- `~/Projects/Logos/Verification/framed_channel/aeneas/lake-manifest.json` and `lakefile.toml`
  both pin the same aeneas rev `227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`.
- `~/Projects/Logos/Verification/framed_channel/aeneas/.lake/packages/aeneas/charon-pin`
  (fetched from the Aeneas sources at that revision) contains exactly
  `a5591f6b94c8575a6ba2ae71090614a722f2b011`.
- `~/Projects/Logos/Verification/framed_channel/aeneas-revs.sh`'s `aeneas_rev_coherence()`
  function — sourced by `check.sh`'s "aeneas revision coherence" stage — performs these checks
  in order, each independently gating (any `[FAIL]` sets `fail=1`, and `check.sh` exits 1 on any
  failure):
  1. `lean/lean-toolchain` == `aeneas/lean-toolchain` == the fetched Aeneas library's
     `lean-toolchain` (unaffected by this task — untouched by the Nix-side pin).
  2. Verification's own `flake.lock`'s `nodes.aeneas.locked.rev` == its
     `aeneas/lake-manifest.json`'s aeneas `.rev` (already coherent within Verification itself;
     not this repo's concern).
  3. **`aeneas -version` on PATH must be a prefix of Verification's locked aeneas rev.** This is
     the check this task's pin directly targets: `aeneas -version` prints the git commit of the
     `aeneas` binary that `aeneas.packages.${system}.aeneas` was built from, so once this repo's
     `aeneas.url` locks to `227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`, the installed binary's
     `-version` output will match (need not be a full match, just a prefix — a short SHA is
     acceptable).
  4. **`charon version` on PATH, parsed as the parenthesized hex suffix, must equal Aeneas's own
     `charon-pin` file content** (not Verification's flake.lock charon rev directly — but those
     two already agree, confirmed above). Repinning `aeneas.url` to `227f4e7...` makes
     `aeneas.packages.${system}.charon` build from the `charon` input *that revision's own
     flake.lock* names, which — live-verified via `nix flake metadata
     github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf` — is exactly
     `a5591f6b94c8575a6ba2ae71090614a722f2b011`. No manual charon override/follows is required.

### Binary Cache Verification (hacl.cachix.org)

Live probes performed during this research (network-dependent, run from this repo's environment):

1. `nix flake metadata "github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf" --json`
   confirms the pinned revision's own lockfile resolves `charon` to
   `a5591f6b94c8575a6ba2ae71090614a722f2b011` (matches task description and Verification's pin
   exactly).
2. `nix eval --raw "github:AeneasVerif/aeneas/227f4e7...#packages.x86_64-linux.charon.outPath"`
   → `/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon`
   `...#packages.x86_64-linux.aeneas.outPath` →
   `/nix/store/64zn9jy24zngxqkyy0z5mrh4xcmk7w6l-ocaml5.2.1-aeneas-0.1.0`
3. `curl -s -o /dev/null -w '%{http_code}' https://hacl.cachix.org/<hash>.narinfo` returned `200`
   for **both** store paths.
4. Fetched the charon `.narinfo` in full: it is signed
   `Sig: hacl.cachix.org-1:bE4VzjpNuOdd6q2xKC9dvVg2sKeIuP0auFypLhUbiSkpP3ASS+Tupka9U2ExleXprRGYNiQNHgSBF5cH1cXwDw==`
   — the `hacl.cachix.org-1:` key-name prefix matches the public key given in the task
   description (`hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=`); a full
   cryptographic verification would require `nix store verify` with the key installed, but the
   key-name match plus a valid signed narinfo response is strong live evidence this is the
   correct, functioning cache for both outputs at the exact pinned revisions.
5. A `--dry-run` build as the unprivileged user (this session) could not use
   `--extra-substituters`/`--extra-trusted-public-keys` because they are restricted settings and
   this user is not in NixOS's `trusted-users` for this daemon — this is exactly why the
   substituter must be configured system-wide via `nix.settings` in a NixOS module (which writes
   `/etc/nix/nix.conf` as root/the daemon config) rather than per-invocation flags; it is not a
   sign the cache doesn't work.

### Community/Documentation Notes

- `hacl.cachix.org` is HACL*'s (the formally-verified cryptographic library used across the
  F*/EverCrypt/Aeneas ecosystem) project cache; AeneasVerif's CI (charon and aeneas repos both
  build against F* toolchains) plausibly publishes to it, consistent with both packages'
  narinfo being present. This is inferred from the live probe results above, not from reading
  AeneasVerif's own CI config — no further external documentation was found asserting this
  explicitly, but the working, correctly-signed narinfo for the exact pinned store paths is
  itself sufficient confirmation the cache is usable for this purpose regardless of its formal
  publication status.

### Recommendations

1. **`flake.nix`**: change line 35 from
   `aeneas.url = "github:AeneasVerif/aeneas";` to
   `aeneas.url = "github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf";`
   and update the preceding comment block (lines 31-34) to drop the now-false "no public binary
   cache is documented" claim, replacing it with a note that `hacl.cachix.org` is trusted for
   these outputs (see `modules/system/nix.nix`) and that the input is pinned to the exact
   revision Verification's toolchain expects, rather than following the default branch, so any
   future move is deliberate (matches the task's own stated rationale).
2. **Regenerate the lockfile**: `nix flake lock --update-input aeneas` (repo root) — this is the
   narrowly-scoped update that only moves the `aeneas` (and its nested `charon`) lock entries,
   leaving every other input (`nixpkgs`, `home-manager`, etc.) untouched. Do NOT run a bare
   `nix flake update`, which would move every input.
3. **`modules/system/nix.nix`**: extend the existing `nix.settings` attrset with:
   ```nix
   substituters = [ "https://hacl.cachix.org" ];
   trusted-public-keys = [ "hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=" ];
   ```
   placed alongside the existing `experimental-features`/`auto-optimise-store`/`max-jobs`/`cores`
   keys in that same `nix.settings = { ... }` block. No other file needs a substituter/key
   change (repo-wide grep found none pre-existing).
4. **No changes needed** in `lib/mkHost.nix` or `modules/home/packages/misc.nix` — both already
   reference `aeneas.packages.${system}.charon`/`.aeneas` generically; they resolve to whatever
   the (now-pinned) `aeneas` input's flake outputs are.
5. **Build/verify strategy**: after the flake.nix + lock + nix.nix changes, run
   `nix flake check` first (cheap, catches syntax/eval errors), then rebuild the host
   (`sudo nixos-rebuild switch --flake .#<host>` or `home-manager switch` per
   `.claude/context/project/nix/tools/nixos-rebuild-guide.md` /
   `home-manager-guide.md` conventions) and confirm on PATH:
   - `aeneas -version` reports a commit that is a prefix of
     `227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`
   - `charon version` reports `(a5591f6b94c8575a6ba2ae71090614a722f2b011)` in the parenthesized
     suffix (matching the exact parsing `aeneas-revs.sh` performs:
     `sed -n 's/.*(\([0-9a-f]*\)).*/\1/p'`)
   - Watch the rebuild's build/substitute log to confirm charon and aeneas are *fetched* (via
     hacl.cachix.org) rather than compiled, validating the substituter addition actually avoids
     the multi-hour source build.
   - Then run `~/Projects/Logos/Verification`'s gate,
     `bash framed_channel/check.sh` (from that repo's root, inside `nix develop` per its own
     preflight requirement for charon/aeneas/jq on PATH), and confirm the
     `== aeneas revision coherence ==` section prints all `[ok]` lines (specifically the "aeneas
     on PATH" and "charon on PATH matches Aeneas's charon-pin" lines) rather than `[FAIL]`.
     "Without a scratch Nix store" per the task's acceptance criterion just means: run this
     verification using this machine's normal, already-populated Nix store/profile — i.e. the
     ordinary rebuilt system — not a fresh/isolated store, which is the natural outcome of a
     normal `nixos-rebuild switch`/`home-manager switch` anyway.

## Decisions

- Pin only `aeneas.url` to the exact revision; do not add a separate/manual override for the
  `charon` input, since the pinned aeneas revision's own lockfile already resolves `charon` to
  the exact expected revision (verified live).
- Place the new `nix.settings.substituters`/`trusted-public-keys` entries in the existing
  `modules/system/nix.nix` module (already the canonical home for `nix.settings` in this repo)
  rather than creating a new module file or using `nix.extraOptions`.
- Use `nix flake lock --update-input aeneas` rather than a full `nix flake update`, to keep the
  lockfile diff minimal and avoid unrelated input drift.

## Risks & Mitigations

- **Risk**: `nix.settings.substituters` NixOS option semantics could in principle be configured
  elsewhere to `mkForce` a shorter list, silently dropping `cache.nixos.org`. Live-checked
  `/etc/nix/nix.conf` today shows only the base default, and repo-wide grep found no existing
  substituter config anywhere — so there is nothing that would fight the merge. Mitigation:
  after rebuild, re-check `/etc/nix/nix.conf` (or `nix show-config | grep substituters`) to
  confirm both `cache.nixos.org` and `hacl.cachix.org` are present.
- **Risk**: Upstream AeneasVerif could stop publishing to `hacl.cachix.org` in the future,
  silently reverting to source builds (slow but not broken — cache misses just fall back to
  building). No action needed now; this is a documented, not blocking, risk.
- **Risk**: pinning to an exact revision means this repo will not automatically track future
  Aeneas/Charon fixes. This is the explicitly intended outcome per the task description ("so
  future drift is deliberate") — not a risk to mitigate, a deliberate trade-off to preserve
  compatibility with the Verification repo's own pin. A future re-pin task can move both in
  lockstep when Verification's own pin moves.
- **Risk**: the `--dry-run` cache probe done during research could not fully cryptographically
  verify the narinfo signature (no local `nix store verify` with the key trusted, since this
  user isn't a trusted Nix user). Mitigation: the actual rebuild, once `nix.settings` is
  extended system-wide (root/daemon-level trust), will perform genuine signature verification
  automatically — a failed signature there would abort the substitution and fall back to
  building from source, which is a safe failure mode, not a broken one.

## Appendix

Commands/queries used during research:
- `grep -n "aeneas" flake.nix flake.lock lib/mkHost.nix modules/home/packages/misc.nix`
- `grep -rn "nix.settings\|substituters\|cachix" --include='*.nix' .` (repo-wide, no prior hits)
- `which aeneas charon; aeneas -version; charon version` (confirmed currently-installed
  `b104e24fea7d721b71e6c39fd70f26ff20bc0980` charon, matching stale `flake.lock`)
- `cat ~/Projects/Logos/Verification/flake.lock` (aeneas/charon locked revs)
- `cat ~/Projects/Logos/Verification/framed_channel/aeneas-revs.sh` (exact coherence-check
  logic and parsing)
- `cat ~/Projects/Logos/Verification/framed_channel/aeneas/.lake/packages/aeneas/charon-pin`
  (`a5591f6b94c8575a6ba2ae71090614a722f2b011`)
- `nix flake metadata "github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf" --json`
  (confirms charon resolves to `a5591f6b94c8575a6ba2ae71090614a722f2b011` at that revision)
- `nix eval --raw "github:AeneasVerif/aeneas/227f4e7...#packages.x86_64-linux.{charon,aeneas}.outPath"`
- `curl -s -o /dev/null -w '%{http_code}' https://hacl.cachix.org/<hash>.narinfo` (200 for both)
- `curl -s https://hacl.cachix.org/8psy457ay66wy4flknrfbh6ddzw9k93z.narinfo` (full narinfo,
  `Sig: hacl.cachix.org-1:...`)
- `grep -n "substituters\|trusted-public-keys" /etc/nix/nix.conf` (current live daemon config)
- Read `modules/system/nix.nix`, `modules/system/default.nix` (module wiring/import order)

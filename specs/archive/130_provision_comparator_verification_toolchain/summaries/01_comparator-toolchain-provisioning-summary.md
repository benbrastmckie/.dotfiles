# Implementation Summary: Provision the Comparator Lean proof-verification toolchain

- **Task**: 130 - Provision the Comparator Lean proof-verification toolchain (landrun, lean4export, comparator)
- **Status**: [COMPLETED]
- **Completed**: 2026-09-07
- **Duration**: ~4.5 hours (first pass) + a short follow-up pass after the user's rebuild
- **Artifacts**: plans/01_comparator-toolchain-provisioning.md

## Overview

All 8 plan phases were executed. `landrun` (pinned `v0.1.17`), a deterministic Lean
`v4.34.0-rc2` toolchain acquisition, a real pinned `comparator` derivation, and a
toolchain-keyed `comparator-lean4export-resolve` resolver were built and behaviorally verified —
including Comparator accepting a matching Challenge/Solution fixture and rejecting a mismatching
one, both under the README's `systemd-run` sandbox-escape wrapper. A first implementing pass left
Phase 6 `[PARTIAL]` because it could not run `sudo nixos-rebuild switch` itself (a categorical
sandbox permission denial), and it recorded an incorrect mechanism claim about *why* that step
mattered. The user has since run `sudo nixos-rebuild switch --flake .#hamsa`. A follow-up pass
re-verified Phase 6 end to end against the live post-rebuild system, corrected the mechanism
record (see Notes), and re-ran both Phase 7 fixtures against the now-installed binaries with
`COMPARATOR_LANDRUN` deliberately left unset — both produced correct, content-based verdicts,
confirming the task's acceptance criteria are genuinely met. Status is `[COMPLETED]`.

## What Changed

- `packages/landrun.nix` — new; pinned `v0.1.17` `buildGoModule` derivation (rejects nixpkgs'
  `0.1.15` on recursive-ELF-`ldd` evidence)
- `packages/lean-toolchain-bin.nix` — new; deterministic Lean `v4.34.0-rc2` acquisition (FOD
  fetch of the official release tarball + offline `autoPatchelfHook` unpack)
- `packages/comparator.nix` — new; real pinned `comparator` derivation (offline `path`-style
  `lean4export` vendoring, no FOD fallback needed)
- `packages/lean4export.nix` — new; defines `comparator-lean4export-resolve`, a toolchain-keyed
  resolver script (not a fixed binary)
- `overlays/unstable-packages.nix` — `callPackage` wiring for all four packages
- `flake.nix` — resolved the previously-unused `lean4` input with an explanatory comment
  (comment-and-keep, not pin-and-use)
- `modules/home/packages/dev-tools.nix` — added the three packages to `home.packages`;
  set `home.sessionVariables.COMPARATOR_LANDRUN`; documented the deliberate
  `COMPARATOR_LEAN4EXPORT`/`COMPARATOR_NANODA` omissions in place
- `packages/README.md` — new "Comparator Lean Proof-Verification Toolchain" section with four
  package entries and six decision records (five task-mandated plus the
  elan-wrapper-script-vs-landrun finding discovered during verification)

## Decisions

- **landrun**: pinned tag `v0.1.17` (commit `62823c05e58ec22c1f91b4c8468318c1f97f2d32`), not
  nixpkgs' `0.1.15` — recursive vs. shallow `--ldd` ELF resolution sits directly in the flag
  combination Comparator hardcodes. This host's Landlock ABI probes at 9, matching `v0.1.17`'s
  ceiling exactly.
- **lean4export**: one system-wide binary is structurally wrong (binary format is tied to the
  Lean version that produced the `.olean` files it reads); resolution is hoisted into a
  standalone resolver (`comparator-lean4export-resolve`) since Comparator's own sandboxed call
  has no writable paths or network. Cache keyed by the target's exact `lean-toolchain` string,
  with a sidecar recording what was actually built, for caller-side mismatch detection.
- **comparator**: a real, pinned Nix derivation, not a `loogle.nix`-style silent-rebuild wrapper
  — trust semantics of a checker whose provenance must be auditable, and a Mathlib-free
  dependency footprint that makes this tractable unlike loogle's case. Offline vendoring of
  `lean4export` via a `path`-style Lake require worked cleanly (verified under `unshare -rn`); no
  network-permitted FOD fallback was needed for the whole build.
- **nanoda**: deferred explicitly (not silently omitted) — not required for these acceptance
  criteria; leaving `COMPARATOR_NANODA` unset makes `enable_nanoda: true` fail loudly rather than
  silently skip.
- **systemd-run wrapper**: retained for portability even though this host (kernel `7.1.3`) is
  past the landrun sandbox-escape fix Comparator's README describes as landing in Linux 7.1 —
  both fixture runs were performed under it and confirmed compatible.
- **Load-bearing discovery**: elan-installed Lean toolchains ship `bin/lake` as a bash-shebang
  wrapper script (LEAN_CC injection), which landrun's ELF-only `--ldd` dependency detection
  cannot see through — the kernel's nested exec of the wrapper's bash interpreter is denied by
  Landlock (`permission denied`, no verdict). Using `lean-toolchain-bin` (raw ELF via
  `autoPatchelfHook`) instead of elan's own toolchain on `PATH` resolved this. Documented in
  `packages/README.md` as an operational requirement for any `comparator` caller on this host
  when the checked project targets `v4.34.0-rc2`.
- **`COMPARATOR_LANDRUN` propagation (corrected in the follow-up pass)**: `home.sessionVariables`
  on this host is propagated into shells by the GRAPHICAL SESSION sourcing `hm-session-vars.sh`
  once at login (confirmed via `systemctl --user show-environment`), not by
  `/etc/profile`/`set-environment` as the first pass incorrectly claimed — that chain, plus
  `/etc/bashrc`/`~/.profile`/`~/.bashrc`, sources nothing of the sort on this host, and this repo
  does not enable home-manager's `programs.bash`/`programs.zsh` (the mechanism that would
  normally add that sourcing line). Consequence: a new value appears in *new* terminals only
  after the graphical session's next login or a reboot, not immediately after
  `sudo nixos-rebuild switch`. Decision: accept this standard propagation delay (no config change)
  rather than adding home-manager shell integration, because Comparator's own upstream code
  already falls back to a bare, `PATH`-resolved `"landrun"` when `COMPARATOR_LANDRUN` is unset
  (`Main.lean:335`), and `landrun` is unconditionally on `PATH` via `~/.nix-profile/bin`
  regardless of session-variable sourcing — verified empirically by re-running both Phase 7
  fixtures with the variable deliberately unset (see Verification below). Recorded in
  `packages/README.md`'s Env-var contract section so the sibling agent-system tasks
  (`~/.config/nvim/`) that consume this contract do not treat an unset `COMPARATOR_LANDRUN` as
  broken.

## Verification

- `nix flake check`: Success (all NixOS configurations, `homeConfigurations`, `formatter`,
  `devShells` evaluate cleanly)
- `nixos-rebuild build --flake .#hamsa`: Success (31 derivations, full system closure including
  the home-manager-integrated session variables)
- `home-manager build --flake .#benjamin`: Success
- `home-manager switch --flake .#benjamin`: Success — put `landrun`, `comparator`,
  `comparator-lean4export-resolve` on `PATH` immediately
- `landrun --version` (real login shell): `landrun version 0.1.17`
- `landrun --help`: lists `--ldd` and `--add-exec`
- `comparator --help` (real execution): no true `--help` flag exists upstream; produces its real,
  deterministic "no such file or directory" error (exit 1) since it treats any argument as a
  config-file path — documented honestly rather than claimed as conventional usage text
- `comparator-lean4export-resolve --help`: full contract documentation printed
- `"$(comparator-lean4export-resolve <project>)" --help`: real lean4export metadata JSON,
  reporting `"version":"4.34.0-rc2"` (lean4export similarly has no true `--help` flag)
- Resolver mismatch detection: hand-tampered a sidecar file, confirmed the resolver refuses
  (exit 1) rather than returning a possibly-mismatched cached binary; restored afterward
- Resolver failure path: a deliberately-nonexistent Lean release exits 1 with the real
  `lake`/elan error on stderr and empty stdout
- **Accept fixture** (`tests/projects/simple_match`, under the `systemd-run` wrapper): full
  build + export + kernel-replay pipeline completed; final line `"Your solution is okay!"`;
  exit 0 — matches `test.json`'s `exit_code: 0`
- **Reject fixture** (`tests/projects/simple_mismatch`, under the `systemd-run` wrapper): full
  build + export pipeline completed; final line `"uncaught exception: Challenge and solution
  constant kind don't match: 'comm'"`; exit 1 — matches `test.json`'s `exit_code: 1`, and the
  rejection is content-based (names the actual mismatch), clearly distinguishable from a tooling
  or sandbox-setup failure
- `echo "$COMPARATOR_LANDRUN"` from this session's shell: empty, because this shell predates the
  graphical session's next login (expected — see the propagation-mechanism correction below); the
  underlying value is confirmed correct by directly `grep`-ing
  `/etc/profiles/per-user/benjamin/etc/profile.d/hm-session-vars.sh` for `COMPARATOR_LANDRUN`,
  which shows `/nix/store/zh3fa8g7f0khc3ygxi9hvga1s4swny6g-landrun-0.1.17/bin/landrun`, and by
  `readlink -f /run/current-system` confirming the `hamsa` generation carrying that value is the
  currently active one
- **Follow-up re-run against the user-rebuilt system, `COMPARATOR_LANDRUN` deliberately unset**:
  both `simple_match` (accept, exit 0, "Your solution is okay!") and `simple_mismatch` (reject,
  exit 1, "Challenge and solution constant kind don't match: 'comm'") were re-run under the same
  `systemd-run` wrapper with `COMPARATOR_LANDRUN` genuinely absent from the environment (not
  manually exported) and `lean-toolchain-bin` ahead of `elan` on `PATH`. Both produced the same
  correct, content-based verdicts as the original Phase 7 run, empirically confirming Comparator's
  own bare-`"landrun"`-via-`PATH` fallback works on this host independent of session-variable
  sourcing state
- `which landrun comparator comparator-lean4export-resolve`: all three resolve to
  `~/.nix-profile/bin/*`, confirmed present regardless of `COMPARATOR_LANDRUN`'s sourcing state
- `landrun --version` (re-confirmed post user-rebuild): `landrun version 0.1.17`

## Notes

**`COMPARATOR_LANDRUN` propagation timing (corrected — not a blocker)**: the first implementing
pass incorrectly claimed that `/etc/profile` → the NixOS-generated `set-environment` chain
auto-sources `home.sessionVariables` into a plain login shell, and that the only obstacle was its
own inability to run `sudo nixos-rebuild switch`. **This diagnosis was wrong.** Verified with
`env -i HOME="$HOME" bash -lc 'echo $COMPARATOR_LANDRUN'` even after the user's real rebuild: it
is still empty in a genuinely clean login shell (as is the pre-existing `LITERATURE_DIR`
session variable; `$EDITOR` resolves to the system-level `nano`, not home-manager's `nvim`).
Nothing in `/etc/profile`, `/etc/set-environment`, `/etc/bashrc`, `~/.profile`, or `~/.bashrc`
sources `hm-session-vars.sh` on this host, and this repo does not enable home-manager's
`programs.bash`/`programs.zsh`. What actually propagates `home.sessionVariables` here is the
**graphical session**, which sources `hm-session-vars.sh` once at login via systemd's
user-environment import (confirmed: `systemctl --user show-environment` already carries
`LITERATURE_DIR` from an earlier login but not yet `COMPARATOR_LANDRUN`, since this host's
graphical session predates the user's rebuild) — every terminal spawned from that session
inherits it as a child process. **Consequence**: `COMPARATOR_LANDRUN` becomes visible in new
terminals only after the next logout/login or reboot of the graphical session — ordinary
home-manager behavior on a host without per-shell integration, not a defect and not specific to
this task. **Decision (recorded durably in `packages/README.md`'s Env-var contract section)**:
accept this standard propagation delay rather than making a config change (e.g. enabling
home-manager's `programs.bash`/`programs.zsh` repo-wide, which would still not help genuinely
non-graphical contexts like SSH sessions) — and rely on Comparator's own already-correct
PATH-fallback behavior (`Main.lean:335`, defaults to bare `"landrun"` resolved via `PATH`) as the
safety net, verified empirically in the re-run above. The sibling agent-system tasks
(`~/.config/nvim/`, tasks 153-156) that consume this env-var contract should not treat
`COMPARATOR_LANDRUN` being unset as broken. Everything else — the four packages, the overlay
wiring, and the `comparator-lean4export-resolve` mismatch/failure handling — required no
correction and is unchanged from the first pass.

**Fixture verification environment note**: Comparator's own hardcoded landrun sandbox args
(`--best-effort --ro / --rw /dev --ldd --add-exec`) interact badly with `elan`'s
toolchain-wrapper-script convention (see Decisions above); both the original and follow-up
Phase 7 fixture runs used `packages/lean-toolchain-bin.nix`'s output on `PATH` (ahead of `elan`)
to avoid this. This is recorded in `packages/README.md` as a required operational note for
downstream callers, since it is not specific to this verification session — any caller checking a
`v4.34.0-rc2` project on this host would hit the same issue with a bare `elan` toolchain on
`PATH`.

## References

- `specs/130_provision_comparator_verification_toolchain/plans/01_comparator-toolchain-provisioning.md`
- `specs/130_provision_comparator_verification_toolchain/reports/01_comparator-toolchain-provisioning.md`
- `specs/130_provision_comparator_verification_toolchain/handoffs/phase-{1..8}-handoff-*.md`
- `packages/README.md` (Comparator Lean Proof-Verification Toolchain section)

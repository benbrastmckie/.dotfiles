# Implementation Summary: Task 66 — Review and Refactor NixOS Configuration

**Status**: COMPLETED
**Completed**: 2026-06-24
**Branch**: `task-66-refactor-nixos`
**Session**: sess_1782334885_f45b18

## Outcome

A semantically-inert modular refactor of the NixOS + Home Manager configuration.
`configuration.nix` went from 954 lines to a 31-line thin import list; `home.nix`
from 1680 lines to 64 lines. Logic now lives in focused modules under
`modules/system/`, `modules/home/`, `overlays/`, `lib/`, and `hosts/`.

## Phases (all committed)

| Phase | Commit | Description |
|-------|--------|-------------|
| 0/1 | (pre-session) | Branch, baseline harness, quick-win safe fixes |
| 2 | `dba1487` | Extract 3 inline overlays into `overlays/*.nix` |
| 3 | `f567062` | Add `lib/mkHost.nix`; extract USB-installer module; add `garuda` host |
| 4a | `8c6d9f7` | Split `configuration.nix` into `modules/system/*.nix` (part 1) |
| 4b | `817e177` | Collapse `configuration.nix` to thin import list (part 2) |
| 5a | `185d50d` | Split `home.nix` core/desktop/email into `modules/home/*` |
| 5b | `46ad3fc` | Split `home.nix` scripts/services/packages into `modules/home/*` |
| 6 | `85d1fdd` | Replace 28 hardcoded username literals with config references |
| 7/8 | (pre-session) | Dual-HM docs, how-to docs, README module map |
| 9 | `dcfa751` | Final cross-host audit + standalone-home `lectic` fix |

## Behavioral-Equivalence Audit (Phase 9)

Compared the fully-refactored HEAD against the pre-refactor baseline (`2911937`)
via `nix store diff-closures`:

- **nandi** (integrated system + home): byte-identical (empty diff)
- **hamsa** (integrated system + home): byte-identical (empty diff)
- **standalone home** (`homeConfigurations.benjamin`): dependency set identical
  (empty diff)
- **garuda** (new host added in Phase 3): builds
- **iso / usb-installer**: fail to build identically on BOTH baseline and HEAD due
  to a pre-existing broken `zfs-kernel` (kernel 7.1.1) — not a refactor regression.

### Regression found and fixed

The final audit caught a defect the per-phase checks missed (they only built the
integrated `nandi` system, not the standalone home profile): the Phase 3
`hmExtraSpecialArgs` consolidation passed the **raw** `lectic` flake input to the
standalone `homeConfigurations.benjamin` instead of the **resolved package** the
baseline used. This silently dropped `lectic` + its node_modules (~280 MiB) from the
`home-manager switch` profile (the integrated NixOS path was unaffected). Phase 9
restored the resolved `lectic` for the standalone path only.

## Known cosmetic deviation

The embedded `refresh-gmail-oauth2` script had trailing whitespace on two blank
lines normalized during the home.nix split (Phase 5a). Behaviorally inert (no
dependency/version change; `diff-closures` empty) but produces a non-byte-identical
top-level home-manager generation hash.

## Verification commands

```bash
nix flake check                                            # all checks pass
nixos-rebuild build --flake .#nandi                        # builds; closure == baseline
nixos-rebuild build --flake .#hamsa                        # builds; closure == baseline
nix build .#homeConfigurations.benjamin.activationPackage  # closure == baseline
```

Build-only verification throughout — no `nixos-rebuild switch` was run; activation
is left to the user.

## Process note

This task was implemented under `/orchestrate`. An early agent dispatched for
"Phases 2–9" ran far past its (misleading) completion notification and produced
overlapping work with a second agent; this was caught, the repo was stabilized,
and the remaining phases (5b, 6, 9) were each driven by a single fresh,
hard-scoped agent with independent per-phase closure verification by the
orchestrator. All committed work is verified inert.

## Pre-existing follow-ups (not part of this inert refactor)

- `iso` / `usb-installer` cannot build until the broken `zfs-kernel` on kernel
  7.1.1 is resolved upstream (or ZFS is disabled in the installer). Pre-existing.
- The integrated home-manager path installs the raw `lectic` input (source) rather
  than the built package — a pre-existing latent inconsistency preserved here for
  inertness; worth a separate task if the integrated profile should also ship the
  built tool.
- Dual home-manager consolidation question raised in `docs/dual-home-manager.md`
  (Phase 7) remains open for user decision.

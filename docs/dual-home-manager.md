# Dual Home-Manager Architecture

> **Verified current**: the `extraSpecialArgs`/`lectic` unification (documented
> below under "Consequences of the Dual Setup") and the "Keep both paths (Option A)"
> recommendation (under "Current Recommendation") are both closed and already documented in this
> file — re-checked against the current tree during a documentation sync pass, no further
> action needed.

## Overview

This flake runs two home-manager instances **in parallel** for the `benjamin` user:

| Path | Type | How Updated | Profile Location |
|------|------|-------------|-----------------|
| NixOS-integrated | `home-manager.nixosModules.home-manager` | `sudo nixos-rebuild switch --flake .#<host>` | `/etc/profiles/per-user/benjamin/` |
| Standalone | `homeConfigurations.benjamin` | `home-manager switch --flake .#benjamin` | `~/.nix-profile/` |

Both paths import `./home.nix` and receive the same `extraSpecialArgs`. `scripts/update.sh` runs both in sequence to keep them in sync.

## Why Two Paths Exist

The standalone path was introduced before NixOS-integrated home-manager was fully configured.
It enables **quick, sudo-free home rebuilds** — useful when iterating on shell aliases or dotfiles
without rebuilding the full NixOS system closure.

`~/.nix-profile/` takes precedence over `/etc/profiles/per-user/benjamin/` in `PATH`, so the
standalone profile is effectively the "active" one for interactive shell sessions.

## Consequences of the Dual Setup

- **Double evaluation cost**: Every `scripts/update.sh` run evaluates `home.nix` twice (once per path),
  building two activation derivations and two GC roots.
- **Two GC roots**: `/nix/var/nix/gcroots/per-user/benjamin/home-manager` (standalone) and
  the NixOS-managed profile root. Both must be included in GC analysis.
- **Sync risk**: If one path is updated and the other is not, they diverge. `scripts/update.sh` mitigates
  this by running both atomically, but a partial failure can leave them out of sync.
- **extraSpecialArgs unified**: The two paths pass the same set of arg *names*
  (`{ pkgs-unstable, lectic, nix-ai-tools }` plus `username`/`name`), and `lectic`'s
  *value* is identical across both: every path resolves `lectic` to the built package via the
  shared expression `lectic.packages.${system}.lectic or lectic.packages.${system}.default or
  lectic`. Keeping that expression in every path matters: `lib/mkHost.nix`'s
  `home-manager.extraSpecialArgs` and `flake.nix`'s `hmExtraSpecialArgs` (consumed raw by the
  `iso` config) must not pass the unbuilt `lectic` flake input straight into `home.packages`,
  which installs an inert reference carrying no `bin/lectic` and fails silently rather than at
  evaluation.

## Which Path to Keep

**Decided: keep both — Option A below.** The double evaluation costs roughly 30 extra seconds on
a full rebuild, which is negligible here, and the sync risk stays low because
`scripts/update.sh` always runs both paths. If build times ever become a pain point, Option B is
the cleanest migration: it removes complexity without changing any system behavior the user sees.

**The three options, on their merits**:

### Option A: Keep both (current state)

**Pros**: Enables sudo-free home rebuilds; quick iteration on user config.
**Cons**: Double evaluation; double GC roots; sync risk.
**Action required**: None.

### Option B: Drop the standalone (`homeConfigurations.benjamin`)

**Pros**: Single source of truth; halves home-manager evaluation overhead; no sync risk.
**Cons**: Every home change requires `sudo nixos-rebuild switch` (slower, requires root).
**Action required**: Remove `homeConfigurations.benjamin` from `flake.nix`; update `scripts/update.sh`
to call only `nixos-rebuild switch`.

### Option C: Drop the NixOS-integrated path

**Pros**: Fully sudo-free workflow; standalone home-manager is the canonical path.
**Cons**: System NixOS config and user config become decoupled; `nixos-rebuild switch` no longer
updates the user profile; requires all user services to be managed via standalone home-manager.
**Action required**: Remove `home-manager.nixosModules.home-manager` from all `nixosConfigurations`;
update `scripts/update.sh` to call only `home-manager switch`.

## Notes on Unmanaged Secrets

The Gmail app password is not managed by sops-nix or home-manager — it is stored by hand in the
libsecret keyring (`secret-tool` service `gmail-app-password`). This is intentional: it is a
long-lived secret with no rotation, so no Nix-declared file or refresh job is involved. Do not
attempt to declare secrets in `home.file` without a secrets backend.

## Related Files

- `flake.nix` — Both home-manager paths are defined here
- `home.nix` — Shared home configuration imported by both paths
- `scripts/update.sh` — Runs both `nixos-rebuild switch` and `home-manager switch` in sequence

# Dual Home-Manager Architecture

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
- **extraSpecialArgs divergence** (resolved): Previously the two paths had slightly different
  `extraSpecialArgs`. As of task 66, both paths pass the same set of args:
  `{ pkgs-unstable, lectic, username, name }`.

## QUESTION for User: Which Path to Keep?

**Three options**:

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

## Current Recommendation

Keep both paths (Option A) until the workflow impact of dropping one is measured. The double
evaluation cost is negligible on modern hardware (~30 extra seconds per full rebuild). The sync
risk is low given `scripts/update.sh` always runs both.

If build times become a pain point, Option B (drop standalone) is the cleanest migration:
it removes complexity without changing the system behavior visible to the user.

## Notes on Unmanaged Secrets

The Gmail app password is not managed by sops-nix or home-manager — it is stored by hand in the
libsecret keyring (`secret-tool` service `gmail-app-password`). This is intentional: it is a
long-lived secret with no rotation, so no Nix-declared file or refresh job is involved. Do not
attempt to declare secrets in `home.file` without a secrets backend.

> Legacy (pre-2026-07-02): `~/.config/himalaya/gmail-oauth2.env` held hand-created Gmail OAuth2
> credentials rotated by the `refresh-gmail-oauth2` script. Gmail now uses the app password (see
> `docs/himalaya.md`) and the refresh unit is disabled, so that env file is no longer part of the
> active setup.

## Related Files

- `flake.nix` — Both home-manager paths are defined here
- `home.nix` — Shared home configuration imported by both paths
- `scripts/update.sh` — Runs both `nixos-rebuild switch` and `home-manager switch` in sequence

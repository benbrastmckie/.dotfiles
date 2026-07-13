# Research Report: Task #63

**Task**: 63 - Enable automatic user-level Nix garbage collection and expire old home-manager generations
**Started**: 2026-06-24T10:00:00-07:00
**Completed**: 2026-06-24T10:45:00-07:00
**Effort**: ~45 minutes
**Dependencies**: None (Lean build must finish before any GC command is run)
**Sources/Inputs**: home-manager source (nix-gc.nix, home-manager-auto-expire.nix), NixOS Discourse, Nix issue tracker, home.nix and configuration.nix inspection
**Artifacts**: - specs/063_user_level_nix_gc_expire_home_manager_generations/reports/01_user-nix-gc.md
**Standards**: report-format.md

---

## Executive Summary

- The system's root `nix.gc` timer (weekly, `--delete-older-than 30d`) runs as root and targets only `/nix/var/nix/profiles` — it never touches the user-level home-manager generations stored in `~/.local/state/nix/profiles/` (69 generations, IDs 109–177, Mar 13 – Jun 23 2026).
- Home Manager provides **two** relevant options for user-level GC: `nix.gc.*` (runs `nix-collect-garbage` on a user systemd timer) and `services.home-manager.autoExpire.*` (runs `home-manager expire-generations` then optionally `nix-collect-garbage` on a user systemd timer).
- The correct one-time reclamation sequence — **after** the Lean build finishes — is: (1) `home-manager expire-generations '-30 days'` as user, (2) `nix-collect-garbage --delete-older-than 30d` as user, (3) `sudo nix-collect-garbage --delete-older-than 30d` as root for the system side.
- Adding `services.home-manager.autoExpire` to `home.nix` is the most correct permanent approach; it mirrors the root policy and runs expire + GC together.
- `/nix/store` is currently **92 GB**; expiring ~65 of 69 HM generations should free significant space because each generation closure includes all configured packages (torch, texlive, R packages, etc.).

---

## Context & Scope

The system runs NixOS (unstable) on a Framework 13 AMD AI 300. The root-level `nix.gc` in `configuration.nix` is:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

This generates a system-level `nix-gc.service` that runs:
```
/nix/store/.../nix-collect-garbage --delete-older-than 30d
```

as root. Confirmed from `systemctl cat nix-gc.service`. The timer next fires 2026-06-29.

**Critical gap**: The root GC only searches `/nix/var/nix/profiles/` and `/nix/var/nix/profiles/per-user/`. The user's home-manager profile generations live in `~/.local/state/nix/profiles/` (XDG path, even though `use-xdg-base-directories = false` in the nix system config — home-manager 24.11+ migrates to XDG automatically). The `/nix/var/nix/profiles/per-user/` directory has no `benjamin` subdirectory, only `root`. Therefore **zero** user HM generations are removed by the system GC run.

**Current state (as of 2026-06-24)**:
- `/nix/store` size: **92 GB** (root disk at ~94%)
- Total HM generations: **69** (IDs 109–177)
- Oldest: ID 109, 2026-03-13
- Newest (current): ID 177, 2026-06-23
- User GC timer: **does not exist** (confirmed via `systemctl --user status nix-gc.timer` and `home-manager-auto-expire.timer`)
- `~/.local/state/home-manager/gcroots/current-home` → current HM generation in store

---

## Findings

### Existing Configuration

**configuration.nix** (lines 734–745):
```nix
nix = {
  settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
};
```

**home.nix**: No `nix.gc` or `services.home-manager.autoExpire` settings. The file uses `systemd.user.services/timers` for other services (gmail-oauth2-refresh, memory-monitor, etc.) so the pattern is established and working.

### Profile Path Analysis

Home-manager stores generations as symlinks in `~/.local/state/nix/profiles/`:

```
home-manager          -> home-manager-177-link  (current)
home-manager-109-link -> /nix/store/4p8g55..-home-manager-generation
home-manager-110-link -> /nix/store/0f7c88..-home-manager-generation
... (69 total numbered links) ...
home-manager-177-link -> /nix/store/qzs6wl..-home-manager-generation
```

Each `home-manager-N-link` is a GC root. The GC cannot collect the closures pinned by IDs 109–176. The root's `nix-collect-garbage --delete-older-than 30d` does NOT scan `~/.local/state/nix/profiles/` so these remain pinned indefinitely.

GC root `~/.local/state/home-manager/gcroots/current-home` points to the current generation's store path — this is correctly managed by HM activation and persists the running config even between profile updates.

### Home Manager Option A: `nix.gc` (user-level GC only)

Source: `modules/services/nix-gc.nix` in home-manager.

This option creates a `systemd.user.timers.nix-gc` + `systemd.user.services.nix-gc` that runs `nix-collect-garbage` with the configured options.

```nix
# In home.nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

Available options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nix.gc.automatic` | bool | `false` | Enable auto GC |
| `nix.gc.dates` | string | `"weekly"` | systemd OnCalendar schedule |
| `nix.gc.randomizedDelaySec` | string | `"0"` | Random delay (e.g., `"45min"`) |
| `nix.gc.options` | string\|null | `null` | Args to `nix-collect-garbage` |
| `nix.gc.persistent` | bool | `true` | Re-run if missed while inactive |

**Limitation**: This only runs `nix-collect-garbage`; it does **not** call `home-manager expire-generations` first. Without expiring generations, the old HM generation symlinks remain as GC roots and the store objects they pin cannot be freed. To work correctly, the `options` field would need `--delete-older-than 30d`, which makes `nix-collect-garbage` itself delete old profile generations it can find — but it targets the XDG profiles only if invoked as the user (and Nix 2.34.7 will find the XDG paths when running as the user even with `use-xdg-base-directories = false`).

### Home Manager Option B: `services.home-manager.autoExpire` (expire + GC combined)

Source: `modules/services/home-manager-auto-expire.nix` in home-manager.

This is the more complete option. It creates a timer that first calls `home-manager expire-generations` (which removes generation symlinks from `~/.local/state/nix/profiles/`), then optionally runs `nix-collect-garbage`.

```nix
# In home.nix
services.home-manager.autoExpire = {
  enable = true;
  timestamp = "-30 days";       # Keep generations from last 30 days
  frequency = "weekly";         # Run weekly (same as root policy)
  store.cleanup = true;         # Also run nix-collect-garbage afterward
  store.options = "--delete-older-than 30d";
};
```

Available options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Activate the service |
| `timestamp` | string | `"-30 days"` | Date-tool format age cutoff |
| `frequency` | string | `"monthly"` | systemd OnCalendar schedule |
| `store.cleanup` | bool | `false` | Run `nix-collect-garbage` after expire |
| `store.options` | string | `""` | Args to `nix-collect-garbage` |

**Recommendation**: Use `services.home-manager.autoExpire` rather than bare `nix.gc` because it handles both the generation symlink removal AND the store collection in the correct order.

### Root GC Does Not Handle User HM Generations — Confirmed

The root nix-gc service explicitly runs:
```bash
exec /nix/store/.../nix-2.34.7/bin/nix-collect-garbage --delete-older-than 30d
```

When run as root, `nix-collect-garbage --delete-older-than 30d` scans:
- `/nix/var/nix/profiles/` (system generations: system-N-link)
- `/nix/var/nix/profiles/per-user/root/` (root's channels)

It does NOT scan `~/.local/state/nix/profiles/` (user-owned XDG path). This is confirmed by Nix issue #8508 (filed 2023, open as of June 2026) and the Discourse thread cited above. The user `benjamin` has no entry under `/nix/var/nix/profiles/per-user/` (only `root` is there).

### Community Consensus on Ordering

From Nix docs, home-manager source, and NixOS Discourse the safe sequence is:

1. **First**: `home-manager expire-generations '-30 days'` — removes the generation symlinks from `~/.local/state/nix/profiles/` that are older than 30 days. This makes those store paths unreachable (no longer GC roots).
2. **Second**: `nix-collect-garbage --delete-older-than 30d` (as user) — collects store objects reachable only through the now-removed generation links. Running as user, Nix 2.34.7 will traverse the XDG profile directory.
3. **Third (optional)**: `sudo nix-collect-garbage --delete-older-than 30d` (as root) — handles system-side profiles. Can be combined with or run at the same time as a manual root GC.

**Why order matters**: If you run `nix-collect-garbage` before `expire-generations`, the old generation symlinks still exist as GC roots, so the store objects they pin cannot be freed. The GC would be a no-op for HM closures.

### Verification: Checking Store Size

To measure before/after, run (as user — read-only):
```bash
du -sh /nix/store
df -h /
```
Current: `/nix/store` = **92 GB**, root disk ~94% full.

After GC, re-run the same commands. Optionally:
```bash
nix-store --gc --print-roots 2>/dev/null | grep home-manager | wc -l
```
to count remaining HM GC roots before and after expiry.

---

## Decisions

1. **Use `services.home-manager.autoExpire`** rather than `nix.gc` alone — it provides the correct expire-then-collect ordering declaratively.
2. **Mirror the root policy** exactly: `timestamp = "-30 days"`, `frequency = "weekly"` to match `configuration.nix`'s weekly/30d setup.
3. **Enable `store.cleanup = true`** with `store.options = "--delete-older-than 30d"` so the timer also runs the GC step without requiring a second manual timer.
4. **One-time cleanup sequence** must be deferred until the Lean build is complete (build is actively using the Nix store and holds GC locks).
5. **Do NOT add `nix.gc` to `home.nix`** in addition to `autoExpire` — this would create two separate GC timers both running `nix-collect-garbage` as user, which is redundant and wasteful.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Running GC while Lean build holds store locks | Wait until Lean build completes; nix GC will block on locks but this can cause hangs. Schedule one-time GC manually after build. |
| `home-manager expire-generations '-30 days'` removes current generation | HM protects the current generation via `~/.local/state/home-manager/gcroots/current-home`; even if symlink is deleted, the store path is still a GC root |
| Insufficient space during `home-manager build` (needed to activate the new config) | Run one-time GC first (after Lean build), THEN apply new home.nix config; or apply config in dry-run mode |
| `store.options = "--delete-older-than 30d"` in autoExpire redundant with expire step | The expire step handles profile generations; the GC step collects the freed store paths. The `--delete-older-than` in store.options is advisory — it additionally deletes any other old profile generations found. Safe to include. |
| 69 HM generations may not all free unique store space | Consecutive generations with identical configs (e.g., IDs 165/166 both point to same store path `8yslk7g9...`) save nothing. Most HM generations here do have unique paths so meaningful recovery expected. |

---

## Implementation Plan (for `/plan` phase)

The implementation task should:

1. Add to `home.nix`:
   ```nix
   services.home-manager.autoExpire = {
     enable = true;
     timestamp = "-30 days";
     frequency = "weekly";
     store.cleanup = true;
     store.options = "--delete-older-than 30d";
   };
   ```

2. Document the one-time reclamation sequence (DO NOT run until Lean finishes):
   ```bash
   # Step 1: Expire old HM generations (user, removes GC root symlinks)
   home-manager expire-generations '-30 days'

   # Step 2: Collect unreachable store paths (user)
   nix-collect-garbage --delete-older-than 30d

   # Step 3: System-side collection (root, handles system generations)
   sudo nix-collect-garbage --delete-older-than 30d

   # Step 4: Verify space reclaimed
   du -sh /nix/store
   df -h /
   ```

3. Verify `home.nix` builds correctly (dry-run, no store writes):
   ```bash
   home-manager build --dry-run --flake .#benjamin
   ```
   (Only after Lean build completes.)

4. Activate the new config (writes new generation, no GC):
   ```bash
   home-manager switch --flake .#benjamin
   ```

---

## Appendix

### Search Queries Used
- `home-manager nix.gc automatic user-level garbage collection systemd timer options 2025 2026`
- `home-manager "expire-generations" "nix-collect-garbage" user profile safe sequence`
- `nixos "nix-collect-garbage" root vs user profile GC roots home-manager generations "--delete-older-than" 2025`
- `nixos nix-collect-garbage user profile XDG ".local/state/nix/profiles" NOT root correct way reclaim space`
- `home-manager "expire-generations" then "nix-collect-garbage" ordering user not root XDG profiles`

### References
- [home-manager/modules/services/nix-gc.nix](https://github.com/nix-community/home-manager/blob/master/modules/services/nix-gc.nix)
- [home-manager/modules/services/home-manager-auto-expire.nix](https://github.com/nix-community/home-manager/blob/master/modules/services/home-manager-auto-expire.nix)
- [Nix Issue #8508: nix-collect-garbage -d does not clean up user profiles in XDG directories when run as root](https://github.com/NixOS/nix/issues/8508)
- [NixOS Discourse: Home-manager and garbage collection](https://discourse.nixos.org/t/home-manager-and-garbage-collection/41715)
- [Home Manager Generation and Profile Management (DeepWiki)](https://deepwiki.com/nix-community/home-manager/2.5-generation-and-profile-management)
- [Nix Reference Manual: nix-collect-garbage](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage)

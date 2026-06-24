# Research Report: Cache Cleanup and Disk Space Reclaim

- **Task**: 64 - Clean regenerable caches and reclaim disk space
- **Started**: 2026-06-24T10:49:00Z
- **Completed**: 2026-06-24T11:15:00Z
- **Effort**: 1.5 hours
- **Dependencies**: None (Lean work in progress — loogle and nix caches deferred)
- **Sources/Inputs**:
  - Read-only `du`/`ls` inspection of all target directories
  - Proton Mail Bridge documentation (proton.me/support) on cache reset
  - OpenCode DeepWiki architecture (deepwiki.com/sst/opencode) on storage model
  - NixOS Discourse: systemd timers in home-manager
  - systemd-tmpfiles manpage and community examples
  - home-manager source: modules/systemd.nix, modules/services/borgmatic.nix
- **Artifacts**:
  - `specs/064_clean_regenerable_caches_reclaim_disk_space/reports/01_cache-cleanup.md`
- **Standards**: status-markers.md, artifact-management.md, report-format.md

---

## Executive Summary

- ~6 GB was already reclaimed (Trash + memory-monitor rotated logs) before this research run; current filesystem is still at 94% (408 GB / 457 GB used).
- **Safe-now** (losslessly regenerable, not in active use): `~/.cache/pip` (3.0 GB), `~/.cache/uv` (2.0 GB), `~/.npm` (8.8 GB) — total ~13.8 GB clearable immediately with single commands.
- **Must wait for Lean work to finish**: `~/.cache/loogle` (7.4 GB, active mathlib build), `~/.cache/nix` (2.2 GB, active flake eval/fetch cache) — safe to clear only after Lean sessions are complete, reclaims ~9.6 GB.
- `~/.local/share/protonmail` (14 GB): the gluon/backend/store is a local IMAP mirror — fully regenerable by Bridge resync, but resync will re-download all email (~13 GB) and takes hours; logs (201 MB) and old update binaries (207 MB) are safe to delete now (~400 MB immediate gain).
- `~/.local/share/opencode` (11 GB): the SQLite database and storage/ directory contain irreplaceable session history; the log/ directory (527 MB) has large rotated logs that are safe to trim except the current session file.
- Best-practice periodic automation on NixOS is a `systemd.user.services` + `systemd.user.timers` pair in home.nix; `systemd-tmpfiles` age-based rules are a complementary but less flexible option for purely age-based deletion.

---

## Context & Scope

Root filesystem (`/dev/nvme0n1p2`, 457 GB) is at 94% used (408 GB). The nix store alone is 92 GB. The immediate target is regenerable caches in `~benjamin/` that can be cleared without losing personal data or interrupting active work.

**Already done (do not re-plan)**:
- `~/.local/share/Trash` — deleted (~4.2 GB recovered)
- `~/.local/share/memory-monitor/` rotated logs (`system.log.old`, `claude.csv.old`) — deleted (~1.8 GB recovered)
- Total already reclaimed: ~6 GB

**Constraint**: Lean work is in progress. `~/.cache/loogle` is the active loogle server build (mathlib + batteries). `~/.cache/nix` is the active nix fetch and eval cache. These must not be deleted until Lean sessions close.

---

## Findings

### 1. `~/.cache/loogle` — 7.4 GB

**Breakdown**:
- `.lake/packages/mathlib/` — 6.5 GB (compiled mathlib oleans)
- `.lake/packages/batteries/` — 453 MB
- `.lake/packages/aesop/` — 133 MB
- `.lake/build/` — 212 MB
- Top-level source files — small (< 1 MB)

**Regenerable**: Yes. This is the loogle server's Lake build cache. Loogle rebuilds it automatically on next `loogle serve` (or when the derivation is updated in `packages/loogle.nix`). The compiled `.olean` files take 1-2 hours to rebuild on first run but require no user data.

**In active use**: Yes. While a Lean proof session is running, loogle's server reads these compiled oileans for search queries. Deleting them mid-session will break the loogle server until it rebuilds.

**Safe deletion command** (run only after Lean work is complete):
```bash
rm -rf ~/.cache/loogle/.lake/packages ~/.cache/loogle/.lake/build
# Or delete the entire cache if you want a clean reinstall:
# rm -rf ~/.cache/loogle
```

**Expected reclaim**: 7.2 GB (leaving top-level source files, which are small)

---

### 2. `~/.cache/pip` — 3.0 GB

**Breakdown**:
- `http-v2/` — 3.0 GB (HTTP wheel/sdist download cache)
- `selfcheck/` — 80 KB (pip self-update check)

**Regenerable**: Yes. pip re-downloads packages from PyPI on next install if not cached. The cache only speeds up repeated installs.

**In active use**: No (pip caches are never locked by running processes).

**Safe deletion command**:
```bash
pip cache purge
# Or equivalently:
# rm -rf ~/.cache/pip
```

**Expected reclaim**: 3.0 GB

---

### 3. `~/.cache/uv` — 2.0 GB

**Breakdown**:
- `archive-v0/` — 1.9 GB (extracted wheel/sdist archives)
- `simple-v21/` — 34 MB (package index metadata, current version)
- `simple-v20/`, `simple-v19/`, `simple-v18/` — 62 MB combined (older index versions, superseded)
- `binaries-v0/` — 34 MB (uv self-update binaries)
- `wheels-v6/`, `wheels-v5/` — ~2.7 MB (compiled wheel cache)

**Regenerable**: Yes. uv re-downloads from PyPI or the project's lock file. The versioned `simple-vNN` directories below the current version (v18, v19, v20) are explicitly obsolete — uv does not read them after upgrading the cache format.

**In active use**: No.

**Safe deletion command**:
```bash
uv cache clean
# Or to selectively remove only obsolete format versions:
# rm -rf ~/.cache/uv/simple-v18 ~/.cache/uv/simple-v19 ~/.cache/uv/simple-v20
```

**Expected reclaim**: 2.0 GB (full clean) or ~62 MB (obsolete versions only)

---

### 4. `~/.npm` — 8.8 GB

**Breakdown**:
- `_cacache/` — 6.9 GB (npm package download cache)
- `_npx/` — 1.9 GB (npx run-once package installs, 10+ entries at 50-525 MB each)
- `_logs/` — 48 KB

**Regenerable**: Yes. npm re-downloads from the registry on next install. The `_npx/` directory caches packages run via `npx`; each subdirectory is a hash of the invocation and is recreated on next `npx` run.

**In active use**: No (npm caches are file-level, never locked).

**Safe deletion command**:
```bash
npm cache clean --force
# This clears _cacache. To also clear _npx:
# rm -rf ~/.npm/_cacache ~/.npm/_npx
```

**Expected reclaim**: 8.8 GB

---

### 5. `~/.cache/nix` — 2.2 GB

**Breakdown**:
- `tarball-cache/` — 1.4 GB (legacy tarball archives, pre-v2)
- `tarball-cache-v2/` — 423 MB (current tarball cache for flake inputs)
- `eval-cache-v6/` — 458 MB (flake evaluation results cache)
- `fetcher-cache-v4.sqlite` — 5.4 MB (fetcher metadata)
- `binary-cache-v7.sqlite` — 40 KB (binary cache metadata)
- `flake-registry.json` — symlink to /nix/store (no space)

**Regenerable**: Yes. Nix recreates all cache files during the next `nix flake update`, `nixos-rebuild`, or `home-manager switch`. The tarball-cache holds downloaded flake input archives (nixpkgs, etc.) that are re-fetched as needed.

**In active use**: Yes, while flake evaluation (e.g., `nix flake check`, `nixos-rebuild`) or loogle's Lake fetch is running. Clearing mid-evaluation forces a re-download but does not corrupt anything.

**Safe deletion command** (run only after Lean work is complete):
```bash
rm -rf ~/.cache/nix/tarball-cache ~/.cache/nix/tarball-cache-v2 \
       ~/.cache/nix/eval-cache-v6 \
       ~/.cache/nix/fetcher-cache-v4.sqlite \
       ~/.cache/nix/binary-cache-v7.sqlite
# Note: do NOT run nix-collect-garbage here; that operates on /nix/store, not ~/.cache/nix
```

**Expected reclaim**: 2.2 GB

---

### 6. `~/.local/share/opencode` — 11 GB (MIXED — partial safe)

**Breakdown**:
- `opencode.db` — 3.3 GB (primary SQLite: all sessions, messages, tool outputs)
- `opencode-stable.db` — 754 MB (older stable-release database snapshot)
- `storage/part/` — 2.4 GB (message parts/chunks, JSON storage layer)
- `storage/message/` — 1.9 GB (message bodies, JSON storage layer)
- `storage/session_diff/` — 1.6 GB (per-session file diffs)
- `storage/session/` — 36 MB (session metadata JSON)
- `storage/todo/` — 632 KB (OpenCode task data)
- `snapshot/` — 159 MB (per-project internal git repo for undo/revert)
- `log/` — 527 MB (application logs, see below)
- `bin/` — 84 MB (opencode binary, managed by opencode auto-update)
- `tool-output/` — 116 KB

**Irreplaceable data (do not delete)**:
- `opencode.db` — contains all conversation history
- `storage/part/`, `storage/message/`, `storage/session_diff/`, `storage/session/` — these are the pre-SQLite JSON storage layer that was migrated to SQLite. They may still be read by older opencode versions or serve as fallback. Deleting risks losing message history if the DB is incomplete.
- `snapshot/` — per-project git history for file undo; deleting removes the ability to revert to prior file states within opencode sessions

**Safely deletable now**:
- `log/` except the current session log — the largest file is `2026-06-24T000611.log` at 420 MB (a single runaway log from a session on June 23). All logs older than the current session are debug logs and are not needed for functionality.
  ```bash
  # Keep only the currently-active log; delete older ones
  # First identify the current session log (most recently modified):
  ls -t ~/.local/share/opencode/log/ | head -1
  # Then delete all others:
  find ~/.local/share/opencode/log/ -name "*.log" -not -newer ~/.local/share/opencode/log/2026-06-24T044743.log -delete
  # Or conservatively, delete logs older than 7 days:
  find ~/.local/share/opencode/log/ -name "*.log" -mtime +7 -delete
  ```
  **Expected reclaim from logs**: ~525 MB (leaving the two most recent small logs)

- `opencode-stable.db` — this is a 754 MB snapshot from May 4 of the stable-release database. If the current `opencode.db` is the active database, this older snapshot can be removed if you do not need to roll back to the stable release. **Caution**: only delete if you are confident the current `opencode.db` is complete.

**Conservative safe reclaim from opencode**: ~525 MB (logs only)
**Aggressive reclaim if old DB accepted as stale**: ~1.3 GB (logs + opencode-stable.db)

---

### 7. `~/.local/share/protonmail` — 14 GB (MIXED — mostly regenerable with caveat)

**Breakdown**:
- `bridge-v3/gluon/backend/store/` — 13 GB (local IMAP mirror database, UUID-named SQLite + directory)
- `bridge-v3/gluon/backend/db/` — 186 MB (gluon IMAP metadata SQLite files)
- `bridge-v3/logs/` — 201 MB (74 bridge log files going back to March 2026, all capped at 5 MB)
- `bridge-v3/updates/3.25.0/` — 207 MB (bridge binary for version 3.25.0, kept for rollback)

**Gluon store (13 GB)**:
The store is a local cache of your Proton Mail mailbox for use by local IMAP clients (Thunderbird, etc.). All email content lives on Proton's servers. The local store can be rebuilt by using Bridge's "Repair" function or by removing the account and re-adding it. During resync, Bridge re-downloads all email bodies. With large mailboxes this takes hours and hammers disk writes, but nothing is lost.

**Safe deletion approach**: You can delete the gluon store if you accept a re-download. Proton's own "Reset Bridge" feature does exactly this. Do NOT manually delete individual files inside the store directory while Bridge is running — stop Bridge first.
```bash
# Stop bridge first:
systemctl --user stop protonmail-bridge
# Then clear the store:
rm -rf ~/.local/share/protonmail/bridge-v3/gluon/backend/store/*
# On next Bridge start it will resync (hours, ~13 GB re-download)
```
**Expected reclaim**: 13 GB (with mandatory resync penalty)

**Safely deletable now (no caveat)**:
- `bridge-v3/logs/` — all 74 log files are debug logs. Bridge recreates them automatically.
  ```bash
  rm -f ~/.local/share/protonmail/bridge-v3/logs/*.log
  ```
  **Expected reclaim**: 201 MB

- `bridge-v3/updates/3.25.0/` — this is a downloaded update binary kept for rollback. The currently running bridge binary is the one managed by NixOS (in /nix/store), not this path. Since the bridge is installed via Nix, update rollback is handled by `nixos-rebuild` or flake pin, not by this directory.
  ```bash
  rm -rf ~/.local/share/protonmail/bridge-v3/updates/
  ```
  **Expected reclaim**: 207 MB

---

## Summary Table

| Target | Current Size | Safe Now? | Active Use? | Safe Deletion Command | Reclaim |
|--------|-------------|-----------|-------------|----------------------|---------|
| `~/.cache/pip` | 3.0 GB | Yes | No | `pip cache purge` | 3.0 GB |
| `~/.cache/uv` | 2.0 GB | Yes | No | `uv cache clean` | 2.0 GB |
| `~/.npm` | 8.8 GB | Yes | No | `npm cache clean --force && rm -rf ~/.npm/_npx` | 8.8 GB |
| `~/.local/share/opencode/log/` (old logs) | 527 MB | Yes | No (current only) | `find ... -mtime +7 -delete` | ~525 MB |
| Protonmail bridge logs | 201 MB | Yes | No | `rm -f .../logs/*.log` | 201 MB |
| Protonmail update binaries | 207 MB | Yes | No | `rm -rf .../updates/` | 207 MB |
| **Safe-now subtotal** | **~15 GB** | | | | **~14.7 GB** |
| `~/.cache/loogle` | 7.4 GB | After Lean | Yes (active) | `rm -rf ~/.cache/loogle/.lake` | 7.2 GB |
| `~/.cache/nix` | 2.2 GB | After Lean | Yes (active) | `rm -rf ~/.cache/nix/{tarball*,eval*,*sqlite}` | 2.2 GB |
| **Deferred subtotal** | **~9.6 GB** | | | | **~9.4 GB** |
| Protonmail gluon/store | 13 GB | With caveat | No | Stop bridge + `rm -rf .../store/*` (hours to resync) | 13 GB |
| opencode storage/ + old DB | ~6.7 GB | With caveat | No | Only after confirming DB completeness | ~1.3 GB safe |
| **Total recoverable** | **~39 GB** | | | | **~37 GB** |

---

## Periodic Cleanup: NixOS Declarative Approach

### Option A: `systemd.user.services` + `systemd.user.timers` in home.nix (Recommended)

This is the most flexible approach and matches the existing pattern already in use (`gmail-oauth2-refresh`, `memory-monitor`, etc.).

```nix
# In home.nix
systemd.user.services.cache-cleanup = {
  Unit = {
    Description = "Periodic user cache cleanup (pip, uv, npm)";
  };
  Service = {
    Type = "oneshot";
    ExecStart = toString (
      pkgs.writeShellScript "cache-cleanup" ''
        # pip HTTP cache
        ${pkgs.python3Packages.pip}/bin/pip cache purge 2>/dev/null || true
        # uv cache (full)
        ${pkgs.uv}/bin/uv cache clean 2>/dev/null || true
        # npm content cache (not _npx which may be in active use)
        ${pkgs.nodejs}/bin/npm cache clean --force 2>/dev/null || true
      ''
    );
  };
};

systemd.user.timers.cache-cleanup = {
  Unit.Description = "Timer for cache-cleanup service";
  Timer = {
    OnCalendar = "weekly";
    Persistent = true;
    RandomizedDelaySec = "1h";
  };
  Install.WantedBy = [ "timers.target" ];
};
```

**Trade-offs**:
- Full control over which caches are cleared and how
- Can condition on disk usage (add `df` check before clearing)
- `Persistent = true` ensures the timer catches up if the machine was off
- `RandomizedDelaySec` prevents thundering herd if multiple machines sync

### Option B: `systemd.user.tmpfiles.rules` (age-based, simpler but less targeted)

Home Manager exposes `systemd.user.tmpfiles.rules` (a list of tmpfiles.d rule strings). The `d` type with an age argument deletes directory contents older than the given age.

```nix
# In home.nix
systemd.user.tmpfiles.rules = [
  # Delete pip http cache entries older than 30 days
  "d %h/.cache/pip/http-v2 - - - 30d"
  # Delete uv archive cache entries older than 30 days
  "d %h/.cache/uv/archive-v0 - - - 30d"
  # Delete npm cacache entries older than 30 days
  "d %h/.npm/_cacache - - - 30d"
];
```

**Caveats**:
- `systemd-tmpfiles --clean` runs at boot and on a periodic timer (systemd-tmpfiles-clean.timer, default daily)
- The `d` type with age only affects *file* mtime, not directory entries — effective for flat cache structures, less so for deeply nested ones
- Home Manager's `systemd.user.tmpfiles.rules` had a regression in some versions (HM issue #8125, 2024); verify with `systemd-tmpfiles --user --clean` after switching
- Does not handle loogle or nix caches well (these have active build files where mtime is unreliable)

### Option C: Nix GC (`nix.gc`) for the Nix store itself

For the nix store (92 GB, not directly in scope but the largest single consumer), add to `configuration.nix`:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

This removes store paths not referenced by any GC root older than 30 days. It does not touch `~/.cache/nix` (which is the user-level download/eval cache, not the store).

### Recommended Combination

1. **`systemd.user.timers` in home.nix** for pip/uv/npm (weekly, using native CLI tools)
2. **`nix.gc` in configuration.nix** for nix store GC (weekly, 30-day threshold)
3. **Manual one-shot** for loogle cache (delete after each major mathlib upgrade cycle, not automated)
4. **Protonmail log age** handled by the bridge's own rotation (already caps at 5 MB/file, 74 files = 370 MB max)

---

## Decisions

- `~/.cache/loogle` and `~/.cache/nix` are blocked by active Lean work and must not be deleted until Lean sessions are complete.
- `~/.local/share/opencode/storage/` and `opencode.db` are classified as irreplaceable user data; only logs are safe to delete now.
- The protonmail gluon store (13 GB) is regenerable but requires a multi-hour resync; it is not included in the "safe-now" count but is documented for deliberate future action.
- For periodic automation, `systemd.user.services/timers` is preferred over `systemd-tmpfiles` because it supports tool-native cache purge commands (pip/uv/npm CLIs) that handle internal cache versioning correctly.

---

## Recommendations

1. **Immediate (safe now, ~14.7 GB)**:
   - `pip cache purge` — 3.0 GB
   - `uv cache clean` — 2.0 GB
   - `npm cache clean --force && rm -rf ~/.npm/_npx` — 8.8 GB
   - Delete opencode logs older than 7 days — ~525 MB
   - Delete protonmail bridge logs and update binaries — ~408 MB

2. **After Lean work completes (~9.4 GB)**:
   - `rm -rf ~/.cache/loogle/.lake` — 7.2 GB
   - `rm -rf ~/.cache/nix/tarball-cache ~/.cache/nix/tarball-cache-v2 ~/.cache/nix/eval-cache-v6 ~/.cache/nix/fetcher-cache-v4.sqlite` — 2.2 GB

3. **Deliberate future decision (13 GB, hours of resync)**:
   - Stop Proton Bridge, delete gluon store, restart and let it resync

4. **Declarative automation in home.nix**:
   - Add `systemd.user.services.cache-cleanup` + `systemd.user.timers.cache-cleanup` (weekly, targeting pip/uv/npm)
   - Add `nix.gc.automatic = true` in configuration.nix (weekly, 30-day threshold)

5. **Nix store GC** (separate concern, 92 GB store):
   - Run `nix-collect-garbage --delete-older-than 30d` manually or via `nix.gc` automation after Lean work is safe; the store is the largest single consumer but is outside the ~cache scope of this task

---

## Risks & Mitigations

- **Loogle rebuild time**: Deleting `~/.cache/loogle/.lake` requires 1-2 hours of rebuilding mathlib oileans on next loogle start. Mitigation: only delete after Lean sessions are closed; schedule for a time when Lean is not needed immediately.
- **Nix re-download after cache clear**: Clearing `~/.cache/nix` causes nix to re-fetch all flake inputs on next evaluation. With nixpkgs pinned in flake.lock this is one large tarball download (~100 MB). Mitigation: ensure network connectivity before next build.
- **opencode DB completeness**: The `storage/` JSON files predate the SQLite migration. If the migration was incomplete, deleting storage/ could lose messages not reflected in `opencode.db`. Mitigation: do not delete storage/ without verifying opencode DB row counts match expectations; only delete logs.
- **Protonmail resync interruption**: If the resync is interrupted partway through, the local mail cache will be in a partially rebuilt state until completion. Mitigation: only initiate when there will be sustained uptime and network access.
- **systemd-tmpfiles HM regression**: HM issue #8125 noted that `systemd.user.tmpfiles.rules` stopped working in some versions. Mitigation: prefer the service/timer approach; verify tmpfiles rules with `systemd-tmpfiles --user --clean --dry-run` before relying on them.

---

## Appendix

### Disk State at Research Time
- Filesystem: `/dev/nvme0n1p2`, 457 GB total, 408 GB used (94%), 27 GB free
- Nix store: 92 GB at `/nix/store`
- Already reclaimed before this research: ~6 GB (Trash + memory-monitor logs)

### Key File Paths
- Loogle Lake packages: `~/.cache/loogle/.lake/packages/` (6.5 GB mathlib, 453 MB batteries)
- Nix eval cache: `~/.cache/nix/eval-cache-v6/` (458 MB)
- OpenCode primary DB: `~/.local/share/opencode/opencode.db` (3.3 GB)
- OpenCode runaway log: `~/.local/share/opencode/log/2026-06-24T000611.log` (420 MB, from June 23 session)
- Protonmail gluon store: `~/.local/share/protonmail/bridge-v3/gluon/backend/store/2cbf9715-0b81-4622-b916-4b798acc6018/` (13 GB)
- Existing home.nix systemd patterns: line 736 (`screenshot-path-copy`), line 789 (`gmail-oauth2-refresh` timer), line 816 (`memory-monitor`)

### References
- [Implementing systemd Timers in home-manager — NixOS Discourse](https://discourse.nixos.org/t/implementing-systemd-timers-in-home-manager/32001)
- [systemd.user.tmpfiles.rules — MyNixOS](https://mynixos.com/nixpkgs/option/systemd.user.tmpfiles.rules)
- [HM issue #8125 — systemd.user.tmpfiles.rules regression](https://github.com/nix-community/home-manager/issues/8125)
- [How to remove cache when uninstalling Proton Mail Bridge — Proton Support](https://proton.me/support/remove-cache-and-configuration-when-uninstalling-proton-mail-bridge)
- [OpenCode Storage and Database — DeepWiki](https://deepwiki.com/sst/opencode/2.9-storage-and-database)
- [Cleaning the nix store — NixOS Wiki](https://nixos.wiki/wiki/Cleaning_the_nix_store)

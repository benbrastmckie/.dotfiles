# Memory Monitoring

Three cooperating tiers watch memory on this machine: one prevents a hard lockup, one records
how much memory was in use, and one records *which processes* were using it.

| Tier | Component | Declared in | Answers |
|------|-----------|-------------|---------|
| 1 | `earlyoom` | `modules/system/power.nix` | "Kill something before the machine freezes" |
| 2 | `memory-monitor` | `modules/home/memory/` | "When was the system under pressure?" |
| 3 | `process-memory-tracker` | `modules/home/memory/` | "What caused it?" |

Scripts live in `modules/home/memory/monitor.nix`; the systemd user units that run them live in
`modules/home/memory/services.nix`. Both are imported by `modules/home/default.nix`.

## Tier 1 — earlyoom

`services.earlyoom` sends `SIGTERM` when available memory **and** free swap both drop below 10%,
and `SIGKILL` at 5%. It runs in userspace ahead of the kernel OOM killer, so it reacts sooner and
is configurable.

```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  freeSwapThreshold = 10;
  enableNotifications = true;
  extraArgs = [
    "--avoid" "^(gnome-shell|Xwayland|niri)$"   # never kill the desktop
    "--prefer" "^(lean|lake|claude|node|npm|opencode)$"
  ];
};
```

`systemd-oomd` is deliberately disabled (`power.nix`, `oomd.enable = false`) so the two OOM
killers do not fight over the same decision.

**earlyoom's journal is a first-class data source.** Every kill records the process name, its
`VmRSS` at the moment of death, and the full cmdline:

```bash
journalctl -u earlyoom --since "30 days ago" | grep "sending SIG"
```

This is often the fastest way to identify a repeat offender, because it captures the peak — the
one number the periodic samplers are most likely to miss.

## Tier 2 — memory-monitor

Samples `free` every 30s and appends aggregate percentages to
`~/.local/share/memory-monitor/system.log`:

```
2026-08-06T14:53:32-07:00,mem=68%,swap=45%
```

It also raises desktop notifications at 80% (warning) and 90% (critical), rate-limited to one
notification per level per 5 minutes via `.cooldown.<level>` marker files. The log rotates to
`system.log.old` at 10MB.

This tier is cheap and long-running — it holds months of history — but it records no process
attribution whatsoever. Use it to find *when* to look; use Tier 3 to find *what* to look at.

## Tier 3 — process-memory-tracker

Snapshots the top RSS consumers system-wide and appends them to
`~/.local/share/memory-monitor/processes.csv`.

```
timestamp,mem_pct,swap_pct,mode,rank,pid,comm,rss_kb,cmdline
2026-08-06T16:55:23-07:00,76,43,burst,1,4006848,lean,10289220,/home/benjamin/.elan/...
```

| Setting | Value | Meaning |
|---------|-------|---------|
| `TOP_N` | 10 | Processes recorded per sample |
| `MIN_RSS_KB` | 51200 | Skip anything under 50MB |
| `INTERVAL_NORMAL` | 60s | Cadence below the burst threshold |
| `INTERVAL_BURST` | 5s | Cadence at or above it |
| `BURST_THRESHOLD` | 75% | Memory use that switches to high-resolution sampling |
| `MAX_LOG_SIZE` | 50MB | Rotates to `processes.csv.old` (~2 weeks per file) |

Two design points are worth keeping in mind when editing this script:

**No allowlist.** The tracker deliberately does not filter by process name. Its predecessor,
`claude-memory-tracker`, matched a hardcoded `pgrep -f "(claude|@anthropic|opencode)"`, which
excluded the processes that actually exhaust this machine — earlyoom's journal recorded `lean`
workers at 19 GB and a `pytest` run at 22 GB, none of which that pattern selected. `lean` appeared
in the old CSV at all only by accident, when its source file happened to sit under a
`/tmp/claude-1000` scratchpad, and its logged peak was 7× lower than reality. Selecting by
*consumption* rather than by *name* means the next offender is already being recorded before you
know to look for it.

**`comm` is derived from `argv[0]`, not requested from `ps`.** `ps -o comm=` truncates to 15
characters and can itself contain spaces (`npm exec @anthr`), which would misalign a
whitespace-split parse. The script requests `pid=,rss=,args=` — two numeric fields then the
remaining argv — and takes the basename of `argv[0]` as the label.

**Burst sampling exists because the ramp is the interesting part.** A 60s interval routinely
misses the climb into a spike entirely; by the time a sample lands, earlyoom has already killed
the culprit and the evidence is gone.

## Analysis Recipes

Days with the most critical-pressure samples:

```bash
awk -F, '/mem=/{gsub(/mem=|%/,"",$2); if ($2+0>=90) {split($1,d,"T"); n[d[1]]++}} END {for (k in n) print n[k], k}' \
  ~/.local/share/memory-monitor/system.log | sort -rn | head
```

Peak RSS per command, in MB:

```bash
awk -F, 'NR>1 {if ($8+0>m[$7]) m[$7]=$8+0} END {for (k in m) printf "%8.0f MB  %s\n", m[k]/1024, k}' \
  ~/.local/share/memory-monitor/processes.csv | sort -rn | head
```

What was at the top during every burst-mode sample:

```bash
awk -F, 'NR>1 && $4=="burst" && $5==1 {printf "%s  %-12s %.1f GB\n", $1, $7, $8/1048576}' \
  ~/.local/share/memory-monitor/processes.csv
```

Every earlyoom kill with its peak RSS:

```bash
journalctl -u earlyoom --since "90 days ago" | grep "sending SIG"
```

## Live Inspection

```bash
systemctl --user status memory-monitor process-memory-tracker
free -h
ps -eo pid,rss,comm,args --sort=-rss | head -20
```

Aggregate current RSS by command:

```bash
ps -eo rss,comm --no-headers | awk '{a[$2]+=$1} END {for (c in a) printf "%8.1f MB  %s\n", a[c]/1024, c}' | sort -rn | head
```

## Applying Changes

The units run scripts from `~/.nix-profile/bin/`, so a standalone home-manager switch is
sufficient:

```bash
home-manager switch --flake .#benjamin
```

`systemd.user.startServices = "sd-switch"` (set in `modules/home/misc.nix`) restarts the units
automatically on activation, and removes units that are no longer declared. Run
`sudo nixos-rebuild switch --flake .#hamsa` (or `./scripts/update.sh`) afterwards to keep
`/etc/profiles/per-user/` in sync — see [dual-home-manager.md](dual-home-manager.md).

## Known Gaps

- **No per-process memory limits yet.** earlyoom kills at 10% free, which is already too late
  when a single Lean elaboration can claim 19 GB in a few minutes. A `MemoryMax=` on a slice for
  Lean and `lake` is the likely next step; it should be sized from `processes.csv` data rather
  than guessed.
- **Editor and CLI builds duplicate work.** A Lean LSP worker and a `lake build` on the same file
  each hold a full elaboration, doubling peak cost. Nothing currently detects or prevents this.
- **`processes.csv` has no retention beyond rotation.** Two 50MB files roll over roughly monthly;
  anything older is lost. If longer baselines become useful, archive the rotated file on a timer.

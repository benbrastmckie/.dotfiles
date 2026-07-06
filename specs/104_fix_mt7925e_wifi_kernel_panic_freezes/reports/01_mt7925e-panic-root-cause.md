# Research Report: mt7925e WiFi Kernel Panic Freezes (Task 104)

**Date**: 2026-07-06
**Machine**: hamsa — Framework Laptop 13 (AMD Ryzen AI 9 HX 370 "Strix Point"), BIOS 03.04
**Kernel at time of crashes**: 7.1.1 #1-NixOS (built 2026-06-19, `linuxPackages_latest`,
nixpkgs generation `nixos-system-hamsa-26.05.20260622.3426825`)

## Symptom

The system hard-freezes and never recovers; the Caps Lock LED blinks. The blinking LED is
the kernel's `panic_blink` indicator — the machine is in a kernel panic, not a userspace
hang. Two freezes occurred on 2026-07-06 alone (~14:41 and ~14:51, the second only 8
minutes into the boot); at least three more occurred on 2026-06-29.

## Evidence

### Journal analysis

- Journal ends abruptly mid-activity at each freeze; no oops/backtrace reaches disk
  (normal for hard panics — the trace was recovered from EFI pstore instead, below).
- **Ruled out — memory exhaustion**: 30 GiB RAM + 31 GiB swap (zram + swapfile), zero
  OOM-killer events in the journal for the whole week.
- **Ruled out — CPU/hardware errors**: no MCE (machine check) events in any recent boot.
- **Ruled out — suspend/resume**: both Jul 6 freezes happened during normal runtime with
  no sleep transition in the journal.
- Suggestive: last kernel activity before the 14:51 freeze was a WiFi roam between AP
  BSSIDs at 14:46 (`wlp192s0: disconnect from AP ... for new auth to ...`).

### pstore crash dumps (definitive)

`systemd-pstore` archived three panic dumps from 2026-06-29 to
`/var/lib/systemd/pstore/` (epochs 1782791514 ≈ 20:51, 1782792090 ≈ 21:02,
1782794377 ≈ 21:41). All three are the **identical crash**:

```
kernel BUG at lib/list_debug.c:32!
Oops: invalid opcode: 0000 [#1] SMP NOPTI
CPU: 6 UID: 0 PID: 815 Comm: napi/phy0-0 Not tainted 7.1.1 #1-NixOS
RIP: 0010:__list_add_valid_or_report+0xa8/0xb0
Call Trace:
  mt76_wcid_add_poll+0x95/0xd0        [mt76]
  mt7925_mac_add_txs.part.0+0x92/0xa0 [mt7925_common]   (variant: mt7925_queue_rx_skb)
  mt7925_rx_check+0xa7/0xc0           [mt7925_common]
  mt76_dma_rx_poll+0x4a2/0x6d0        [mt76]
  mt792x_poll_rx+0x52/0xe0            [mt792x_lib]
  __napi_poll / napi_threaded_poll_loop
```

`lib/list_debug.c:32` is the kernel's linked-list corruption check
(`__list_add_valid_or_report`): the MediaTek MT7925 driver (`mt7925e` / `mt76` stack)
corrupts its per-station `poll_list` while processing TX-status/RX packets on the
threaded NAPI path, and CONFIG_DEBUG_LIST turns that into an immediate `BUG()` → panic.

One of the June 29 panics hit just 364 seconds after boot; another at ~37 minutes — the
bug can strike any time WiFi is active. The dumps and today's journal both show heavy AP
roaming (multi-AP network, frequent BSSID hops between `a4:99:a8:be:ea:6x` /
`b4:b0:24:77:93:2x`) immediately preceding crashes, consistent with wcid (wireless client
ID) churn during roam/reconnect being the trigger.

## Root cause

Known upstream bug in the mt76/mt7925 driver: wcid entries are added to the station poll
list in a racy/invalid way, corrupting the list and panicking the kernel. Relevant
upstream work:

- ["wifi: mt76: do not add non-sta wcid entries to the poll list"](https://lists.linaro.org/archives/list/linux-stable-mirror@lists.linaro.org/message/EI53CCV3GNFHSFWV3OOOLXJ4X5XAJ3UU/)
  — one-line guard in exactly the crashing function (`mt76_wcid_add_poll`), backported to
  stable via AUTOSEL.
- ["wifi: mt76: mt7925: fix double wcid initialization race condition"](https://lkml.org/lkml/2026/1/29/486)
  — newer series (2026-01) addressing the initialization race.
- Same panic reported at [openwrt/mt76 issue #1023](https://github.com/openwrt/mt76/issues/1023).

The running kernel (built 2026-06-19) still crashes, so it lacks the complete fix set.

## Prior related work on this machine

`modules/system/boot.nix` already carries Ryzen AI 300 workarounds from an earlier freeze
investigation (`specs/reports/019_system_freeze_shutdown_analysis.md`, since archived):
`amdgpu.dcdebugmask=0x10`, `mt7925e disable_aspm=1 power_save=0`,
`hung_task_timeout_secs=60`. Those addressed suspend/NetworkManager deadlocks; this panic
is a distinct runtime bug in the driver's RX/TX-status path and is not mitigated by them.

## Recommendations

1. **Update the kernel** (primary fix): `nix flake update` + rebuild. The host uses
   `linuxPackages_latest`, so a nixpkgs bump pulls the newest kernel, where mt7925 fixes
   land first. Verify after update that freezes stop; if a new kernel still panics with
   the same trace, pin the patch series above via `boot.kernelPatches`.
2. **Make panics survivable** (mitigation): add `"panic=10"` to `boot.kernelParams` so
   the machine auto-reboots 10 s after a panic instead of hanging with a blinking LED
   (current `kernel.panic = 0` means hang forever).
3. **Reduce trigger surface** (optional): less aggressive AP roaming/band-steering makes
   crashes rarer but does not fix the bug.
4. **Hardware fallback** (last resort): the Framework 13 WiFi module is replaceable; an
   Intel AX210 sidesteps the mt76 driver entirely.

## Post-research findings during implementation (2026-07-06)

Verification against the v7.1.2 source tree showed that **both published upstream fixes
are already present in the crashing kernel**: `mt76_wcid_add_poll()` in 7.1.1/7.1.2
carries the `!wcid->sta` guard, and `mt7925_mac_link_sta_add()` no longer has the
duplicate `mt76_wcid_init()` (the 7.1.2 changelog contains no mt76 commits, so 7.1.1 is
identical). This panic is therefore a **still-unfixed variant** of the wcid/poll_list
race. The community fix tracker ([zbowling/mt7925](https://github.com/zbowling/mt7925))
does not catalog this exact backtrace, and its per-kernel patch sets stop at 6.19 (all
merged into 7.x).

Implications:
- The kernel bump (7.1.1 → 7.1.2) does NOT contain a targeted fix; recurrence is
  possible. `panic=10` is the operative mitigation until upstream fixes the race.
- Reporting the pstore dumps upstream (linux-mediatek list or zbowling/mt7925 issues)
  would be genuinely useful — this trace is not yet catalogued.
- If panics persist across future kernel updates, fall back to swapping the WiFi module
  (Intel AX210).

Also encountered: the 2026-07-05 `nixpkgs-unstable` rev breaks `r-V8` (link failure
against nodejs-slim libv8), which breaks the R environment in
`modules/system/packages.nix` (gt → gtsummary chain, cf. task 61). `nixpkgs-unstable`
was pinned back to 567a49d (2026-06-16) in flake.lock; the main `nixpkgs` input (which
provides the kernel) stayed on the 2026-07-04 rev.

## Verification notes for implementation

- After `nix flake update`, build with `nixos-rebuild build --flake .#hamsa` (or
  `nix build .#nixosConfigurations.hamsa.config.system.build.toplevel`) before switching.
- Post-switch, confirm `cat /proc/sys/kernel/panic` reports `10`.
- Crash recurrence check: after a week of uptime, `ls /var/lib/systemd/pstore/` should
  show no new entries (systemd archives any new panic dumps there at boot).
- Raw dumps preserved at `/var/lib/systemd/pstore/` (root-only) and a user-readable copy
  at `~/pstore-copy/` (can be deleted once this task completes).

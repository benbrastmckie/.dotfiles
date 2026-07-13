# Research Report: Root-Cause Fix for mt7925e WiFi Kernel Panics (Task 106)

- **Task**: 106 - root_cause_fix_mt7925e_wifi_kernel_panics
- **Started**: 2026-07-11T00:00:00Z
- **Completed**: 2026-07-11T00:00:00Z
- **Effort**: ~2 hours (hard-mode research, web + repo + live-system evidence)
- **Dependencies**: Task 104 (diagnosis; report `specs/104_fix_mt7925e_wifi_kernel_panic_freezes/reports/01_mt7925e-panic-root-cause.md`)
- **Machine**: hamsa — Framework Laptop 13 (AMD Ryzen AI 9 HX 370 "Strix Point"), MediaTek MT7925 (RZ717)
- **Kernel at time of research**: 7.1.2 (`linuxPackages_latest`, nixpkgs `nixos-26.05` rev `a50de1b7`, 2026-07-04)
- **Session**: sess_1783800961_28ec54
- **Sources/Inputs**:
  - Repo: `modules/system/boot.nix`, `flake.nix`, `flake.lock`, task-104 report
  - Live system: journalctl (boots 0/-1), `/var/lib/systemd/pstore/`, `/sys/firmware/efi/efivars/`, `/proc/sys/kernel/{panic,panic_on_oops}`, booted kernel `.config`, `nix eval` of pinned kernel
  - Upstream: torvalds/linux commit API + patch, kernel.org ChangeLog-7.1.3, openwrt/mt76 commit log, zbowling/mt7925 tracker, Framework community, LWN/CVE roundups, nixpkgs `kernels-org.json` (pinned rev vs `nixos-26.05` HEAD)
  - Fresh evidence memo: scratchpad `fresh-evidence.md` (2026-07-11)
- **Artifacts**: `specs/106_root_cause_fix_mt7925e_wifi_kernel_panics/reports/01_mt7925e-panic-upstream-fix.md` (this file)
- **Standards**: report-format.md, artifact-formats.md, return-metadata-file.md

## Executive Summary

- **A targeted upstream fix for hamsa's exact crash EXISTS and is MERGED**: mainline commit
  `20b126920a259df4d7dcae19fcfe2c57a74d6b2e` — "wifi: mt76: add wcid publish check in
  mt76_sta_add" (Jiajia Liu, authored 2026-05-28, merged via Felix Fietkau 2026-06-09). Its
  commit message reproduces hamsa's backtrace **verbatim, including the identical symbol offset**
  (`mt76_wcid_add_poll+0x95/0xd0` → `mt7925_mac_add_txs.part.0` → `mt7925_rx_check` →
  `mt76_dma_rx_poll` → `mt792x_poll_rx`), triggered by the same AP-roam pattern, reported
  against 7.1-rc4. Confidence of match: very high.
- **The fix is already in stable 7.1.3** (ChangeLog-7.1.3 carries it as
  "commit 20b12692… upstream"), and the `nixos-26.05` branch of nixpkgs already ships
  **linux 7.1.3** for `linuxPackages_latest`. The pinned rev (`a50de1b7`, 2026-07-04) still has
  7.1.2 — the crashing kernel. **`nix flake update nixpkgs` + rebuild is the real fix**, with
  Hydra binary cache (no local kernel build).
- Fallback real fix (verified viable): `boot.kernelPatches` cherry-pick of the commit onto
  7.1.2 — the patch **dry-run-applies cleanly to the v7.1 tree** (offset −2 lines) and the
  `fetchpatch` hash has been precomputed (`sha256-gn0aq/7ruSlBobDribGiSKwh3wJqHhV0aKHb7yYOXxY=`).
- **Diagnostics-gap finding revised**: the "pstore is full" hypothesis is NOT supported.
  `/sys/fs/pstore` was **empty** at today's boot (systemd's Platform Persistent Storage Archival
  was skipped on `ConditionDirectoryNotEmpty=/sys/fs/pstore`) and there are **zero** leftover
  `dump-type0-*` EFI variables (110 efivars total). The Jul-6 and Jul-11 panics simply never
  produced pstore records; nothing has been captured since Jun 29. `kernel.panic_on_oops=0`
  (current) is the leading suspect: the initial oops does not panic immediately, the machine
  wedges progressively (crashed NAPI thread dies holding `sta_poll_lock`), and by the time a
  panic finally fires, EFI runtime writes may no longer succeed. Set `panic_on_oops=1`.
- Trigger-surface toggles are dead ends: mt76 hard-codes threaded NAPI on an internal dummy
  netdev (`dma.c:1134`, `dev->napi_dev->threaded = 1`) with no module parameter and no
  `/sys/class/net/*/threaded` handle (wlp192s0's `threaded=0` is a different netdev), and
  disabling threading would not remove the concurrency anyway. Existing `disable_aspm`/
  `power_save=0` do not address this race.
- Hardware fallback (Intel AX210, iwlwifi) remains available and community-validated on the
  AMD Framework 13, but is **not needed if the kernel fix works** — reserve it for recurrence
  on ≥7.1.3.

## Context & Scope

Task 104 diagnosed recurring hard kernel panics on hamsa as a linked-list corruption race in
the mt76/mt7925e driver (`kernel BUG at lib/list_debug.c:32` in `mt76_wcid_add_poll` on the
threaded-NAPI RX/TXS path, triggered by wcid churn during AP roaming) and established that both
then-published upstream fixes were already present in the crashing 7.1.1/7.1.2 kernel — i.e. a
still-unfixed variant. Task 104 shipped mitigations only (`panic=10`, kernel 7.1.1 → 7.1.2).

This task's mandate: find the real upstream fix (if any), assess kernel-version and
`boot.kernelPatches` routes, honestly assess trigger-surface mitigations and the AX210 hardware
fallback, and close the diagnostics gap so future panics are captured. Hard-mode: every upstream
claim source-grounded; candidate fixes adversarially examined.

## Fresh Evidence (2026-07-11)

- Running kernel 7.1.2; `/proc/sys/kernel/panic = 10` (task-104 mitigation active).
- **The freeze recurred on 7.1.2**: boot −1 journal ends abruptly mid-activity at
  Jul 11 13:09:49 PDT (classic hard-panic truncation, same signature as task 104); boot 0
  starts 13:10:49 — the ~60 s gap is consistent with a wedge-then-panic followed by the 10 s
  `panic=10` auto-reboot plus POST. Mitigation works; bug persists.
- **Capture-gap finding (revised from the initial memo)**: the scratchpad memo hypothesized
  "EFI pstore backend full". Direct inspection contradicts this:
  - Boot-0 journal: `Platform Persistent Storage Archival skipped, unmet condition check
    ConditionDirectoryNotEmpty=/sys/fs/pstore` — **`/sys/fs/pstore` was empty** when systemd
    looked. The same skip appears on boot −1 (Jul 6). systemd-pstore already unlinked the
    Jun-29 records when it archived them (13 dirs under `/var/lib/systemd/pstore/`, epochs
    1782791514…1782794378, all Jun 29).
  - `/sys/firmware/efi/efivars/` holds 110 variables, **zero** matching `dump*` — no orphaned
    crash variables clogging NVRAM from the efivarfs point of view.
  - Conclusion: the Jul-6 (×2) and Jul-11 panics **never wrote pstore records at all**. Nothing
    has been captured since Jun 29. Root cause of the missed captures is not fully determinable
    from userspace; leading hypotheses in Findings §6.
- Relevant sysctls/config on the booted kernel: `kernel.panic_on_oops = 0`,
  `CONFIG_DEBUG_LIST=y`, `CONFIG_BUG_ON_DATA_CORRUPTION=y` (list corruption → immediate
  `BUG()`), `CONFIG_EFI_VARS_PSTORE=y`.

## Findings

### 1. Upstream fix status — the core question [ANSWERED: fix exists, merged, in stable]

**The fix**: `wifi: mt76: add wcid publish check in mt76_sta_add`

| Attribute | Value | Status |
|---|---|---|
| Mainline commit | `20b126920a259df4d7dcae19fcfe2c57a74d6b2e` | **merged** (torvalds/linux) |
| Author / date | Jiajia Liu <liujiajia@kylinos.cn>, authored 2026-05-28 | — |
| Merged to mainline | 2026-06-09 (committer Felix Fietkau <nbd@nbd.name>) | **merged** |
| Lore message-id | `20260528033814.46418-1-liujiajia@kylinos.cn` (patch.msgid.link) | — |
| mt76 maintainer tree mirror | openwrt/mt76 commit `2ab6498` (staged May 28–Jun 2, 2026) | **merged** |
| File touched | `drivers/net/wireless/mediatek/mt76/mac80211.c` (+12/−3) | — |
| Stable backport | **present in 7.1.3** ("commit 20b12692… upstream" in ChangeLog-7.1.3) | **released** |
| Fixes:/Cc: stable tags | **absent** from the commit message | note below |

**Why this is hamsa's bug** (evidence of match):

- The commit message embeds the reporter's crash, which is line-for-line hamsa's pstore trace —
  same functions, same modules, and the **same symbol offset** `mt76_wcid_add_poll+0x95/0xd0`:
  `mt76_wcid_add_poll` → `mt7925_mac_add_txs.part.0` → `mt7925_rx_check` → `mt76_dma_rx_poll`
  → `mt792x_poll_rx`.
- Same trigger: the reporter's log shows an AP roam immediately before corruption
  (`wlan0: disconnect from AP … for new auth to …`) — exactly hamsa's multi-AP roam churn.
- Same corruption class: `list_add corruption. prev->next should be next (…), but was …` on
  `dev->sta_poll_list` — the check behind `lib/list_debug.c:32` / `__list_add_valid_or_report`
  (hamsa's `BUG()` variant comes from `CONFIG_BUG_ON_DATA_CORRUPTION=y`).
- Reported against **7.1-rc4** — the same kernel series hamsa crashes on.

**Root-cause mechanics** (from the diff): `mt7925_mac_sta_add()` publishes the wcid (making it
visible to concurrent RX/TX-status processing) *before* `mt76_sta_add()` runs. `mt76_sta_add()`
then unconditionally re-ran `mt76_wcid_init()`, re-initializing `wcid->poll_list` while the
threaded-NAPI RX path could concurrently `mt76_wcid_add_poll()` the same wcid — corrupting
`dev->sta_poll_list`. The fix makes `mt76_sta_add()` check (under `dev->mutex`,
`rcu_dereference_protected`) whether this wcid is already published in `dev->wcid[idx]`; if so
it only sets `phy_idx` and skips re-init. This closes the race for **both** observed variants
(`mt7925_mac_add_txs` and `mt7925_queue_rx_skb`), since both corrupt the list via the same
`mt76_wcid_add_poll()`/re-init interleaving.

**Distinguishing from the already-present fixes** (task 104 ground truth holds): the
`!wcid->sta` guard (commit `a3c99ef88a08…`, AUTOSEL to stable, 2025) and the "double wcid
initialization" fix are prophylactics on other entry points; neither prevented the
publish-before-init re-initialization window. This commit is the first upstream change that
does.

**Related but distinct work** (checked and excluded):

- zbowling "mt7925/mt792x comprehensive stability fixes" 17-patch series
  (msgid `20260105002638.668723-…@gmail.com`, patchew, Jan 2026) and the
  "[PATCH v7 0/6] wifi: mt76: mt7925: MLO stability fixes" (lkml.org/lkml/2026/1/29/484,
  Jan 29 2026): NULL-deref/mutex/MLO-roam hardening. Not this bug; the zbowling tracker
  (zbowling.github.io/mt7925) still does not catalog the poll_list corruption signature.
- **Correction to task 104**: openwrt/mt76 issue #1023 is *not* this panic — it is a firmware
  `strnlen` buffer overflow in `mt76_connac2_load_patch()` on 6.19-rc1
  (`kernel BUG at lib/string_helpers.c:1043`). Task 104's citation of #1023 as "the same panic"
  was inaccurate.
- CVE-2026-53098 (mt7915 `mt7915_mac_dump_work()` UAF, disclosed 2026-06-24, fixed in the same
  7.1.3 stable round) is unrelated to this crash but confirms the 7.1.3 release contents/date.

### 2. Kernel-version angle [ANSWERED: 7.1.3 is the fixed version]

- Fixed versions: **mainline 7.2-rc1+** and **stable 7.1.3** (released on/about 2026-07-04,
  per the LWN stable-release roundup and the kernel.org ChangeLog). No `Fixes:`/`Cc: stable`
  tag was on the commit, but the stable maintainers picked it up anyway (visible verbatim in
  ChangeLog-7.1.3) — so no AUTOSEL wait is needed.
- nixpkgs state (checked directly against `kernels-org.json`):
  - Pinned `nixpkgs` (`nixos-26.05`, rev `a50de1b7d8a5…`, 2026-07-04): `7.1 → 7.1.2`
    (verified both in the JSON at that rev and by `nix eval
    .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version` → `"7.1.2"`).
  - `nixos-26.05` branch HEAD (2026-07-11): `7.1 → 7.1.3` (and `testing → 7.2-rc2`).
- Therefore **bumping the `nixpkgs` input is sufficient and is the cleanest real fix**. Per the
  comment in `flake.nix`, the host tracks the stable channel precisely because Hydra fully
  builds it — the 7.1.3 kernel will come from the binary cache, no local compile.
- `nixpkgs-unstable` stays pinned at `567a49d` (2026-06-15, the task-104 r-V8 pin) — it is a
  separate input and is unaffected by updating `nixpkgs`.

### 3. boot.kernelPatches viability [ANSWERED: viable, verified, hash precomputed]

Verified in this session: the GitHub-exported patch for `20b126920a25` **applies cleanly to the
v7.1 tree** (`patch -p1 --dry-run`: both hunks succeed at offset −2 lines; the pre-image
context at `mac80211.c:1598` matches). The `fetchpatch` output hash was computed against the
pinned nixpkgs' `fetchpatch` normalizer.

Exact pattern (add to `modules/system/boot.nix`, only while the kernel is < 7.1.3):

```nix
boot.kernelPatches = [
  {
    # Real fix for the mt76_wcid_add_poll sta_poll_list corruption panic
    # (task 104/106). Upstream 20b126920a25, in mainline 7.2-rc1 and stable
    # 7.1.3. REMOVE once linuxPackages_latest >= 7.1.3 (the patch will fail
    # to apply on a kernel that already contains it).
    name = "mt76-wcid-publish-check";
    patch = pkgs.fetchpatch {
      name = "mt76-wcid-publish-check.patch";
      url = "https://github.com/torvalds/linux/commit/20b126920a259df4d7dcae19fcfe2c57a74d6b2e.patch";
      hash = "sha256-gn0aq/7ruSlBobDribGiSKwh3wJqHhV0aKHb7yYOXxY=";
    };
  }
];
```

Costs/caveats:
- Any non-empty `boot.kernelPatches` forces a **full local kernel rebuild** (the derivation no
  longer matches Hydra's) — expect a long compile on this laptop and on every subsequent
  nixpkgs bump while the patch is present.
- The patch **must be removed** when the kernel reaches ≥ 7.1.3, or the build will fail on an
  already-applied hunk (a loud failure — safe, but a rebuild-blocker).
- Given Finding 2, this route is strictly a fallback: it only wins if the flake update is
  undesirable right now (e.g. an unrelated channel regression blocks the bump).

### 4. Trigger-surface reduction (mitigations, honestly assessed) [ANSWERED: mostly dead ends]

- **Threaded NAPI cannot be toggled and would not fix the race.** mt76 hard-codes
  `dev->napi_dev->threaded = 1` (openwrt/mt76 `dma.c` line 1134) on an **internal dummy
  netdev** ("phy0", hence the `napi/phy0-0` comm in the trace) that is not exposed under
  `/sys/class/net/` — the `threaded=0` readable at `/sys/class/net/wlp192s0/threaded` belongs
  to the mac80211 netdev, not the device doing the polling. There is no module parameter.
  Even if softirq NAPI could be forced, the race is between process-context `mt76_sta_add()`
  and *any* concurrent RX/TXS processing — softirq polling is exactly as capable of hitting
  the window. Verdict: not actionable, not a fix.
- **`disable_aspm=1` / `power_save=0`** (already in `extraModprobeConfig`): address firmware
  wedges/latency, not this memory race. Keep them for their original purpose; expect no effect
  on this panic. Verdict: keep, irrelevant here.
- **Roaming aggressiveness**: the trigger is wcid churn on roam, so fewer roams = fewer dice
  rolls. With NetworkManager + wpa_supplicant there is no clean declarative "roam less" knob;
  the practical declarative option is pinning the connection profile to one BSSID
  (`networking.networkmanager.ensureProfiles` with `wifi.bssid=…`), trading mobility across
  the multi-AP network for fewer roam events. Verdict: real but lossy mitigation; only worth
  doing if the kernel fix somehow fails. Not recommended now.
- **`panic=10`** (already present): keep permanently; it is the recovery net regardless.

### 5. Hardware fallback — Intel AX210 [ANSWERED: viable, but hold]

- Community-validated on AMD Framework 13 boards: the **Intel AX210 (non-vPro)** swap is a
  well-trodden path (Framework community "WiFi Replacement Guide 2025" thread 72699; multiple
  Ryzen-board write-ups, e.g. theopark.me 2025-11-28), uses `iwlwifi`, and fully sidesteps the
  entire mt76/mt7925 stack. The vPro variant should be avoided (pairing/regression reports).
  A newer community favorite on these boards is the Qualcomm **QCNCM865** (`ath12k`, WiFi 7,
  Framework thread 78181), also reported as a large reliability/throughput upgrade over the
  RZ717 on Linux.
- Framework's official replacement options for the AMD boards have historically been the
  shipped MediaTek modules; AX210 is a user swap, not an official SKU for this board — warranty
  posture unchanged (module is a user-serviceable M.2 2230 part).
- Verdict: with a merged, released upstream fix for the exact crash, the swap is **premature**.
  Hold as the terminal fallback if panics recur on ≥ 7.1.3.

### 6. Diagnostics gap — why no fresh dump, and how to fix capture [PARTIALLY ANSWERED]

Established facts (see Fresh Evidence): `/sys/fs/pstore` empty at boots after both the Jul-6 and
Jul-11 panics; zero `dump-type0-*` efivars; systemd-pstore healthy and correctly archiving/
unlinking (Jun-29 records archived to `/var/lib/systemd/pstore/`). So the capture failure is at
**write time (panic path)**, not a full backend at read time.

Hypotheses, in order of plausibility:
1. **Progressive wedge before panic** (best supported): `kernel.panic_on_oops=0` means the
   `BUG()` oops kills the NAPI kthread but does not panic. That thread dies holding
   `dev->sta_poll_lock`; CPUs subsequently wedge on the spinlock, and the eventual panic (hung
   task/hard-lockup path, consistent with the observed ~60 s gap vs. the 10 s `panic=10`
   window) happens with the machine in a state where the EFI-variable kmsg dump can no longer
   complete. Note the oops-time `KMSG_DUMP_OOPS` write evidently also failed or was lost on
   Jul 6/11 even though it worked on Jun 29 — which is why this is a hypothesis, not a proof.
2. EFI runtime service write failure at panic time (AMD/Framework firmware flakiness under
   panic context) — indistinguishable from (1) from userspace.
3. The Jul-6/Jul-11 events are a *different* failure that never runs the oops path (pure hard
   lockup / firmware hang). Cannot be excluded without a capture. See Adversarial Analysis.

Capture-path fixes (declarative, low risk):
```nix
# modules/system/boot.nix
boot.kernel.sysctl."kernel.panic_on_oops" = 1;
```
- `panic_on_oops=1` makes the FIRST oops panic immediately: the pstore kmsg dump runs at the
  earliest, cleanest moment (before spinlock wedge), and `panic=10` reboots 10 s later instead
  of after a minute of zombie limping. This is the single highest-value diagnostics change.
- One-time root verification/housekeeping (manual, next convenient moment):
  - `sudo ls -la /sys/fs/pstore/` — confirm empty (expected; if anything is present,
    systemd-pstore will archive+unlink it on next boot anyway).
  - Prune the 13 archived Jun-29 dirs under `/var/lib/systemd/pstore/` and the user copy
    `~/pstore-copy/` once this task closes (housekeeping only — archived copies do NOT block
    new captures; keep at least one dump for the upstream report, see Recommendations).
  - Optional: `sudo ls /sys/firmware/efi/efivars/ | grep -i dump` after the next panic to
    check whether records were written but not exposed.
- Not recommended: ramoops (needs a reserved-RAM `memmap=` carve-out — fragile on this UEFI
  platform); kdump/`boot.crashDump` (heavyweight, overkill when the fix is already released).

## Decisions

- Treat mainline `20b126920a25` as THE fix for this crash (evidence: verbatim backtrace with
  matching symbol offset, same trigger, same kernel series, maintainer-merged, stable-released).
- Prefer the nixpkgs bump (7.1.3 from binary cache) over `boot.kernelPatches` (local rebuild);
  keep the patch snippet as a documented, hash-verified fallback.
- Correct the task-104 record: openwrt/mt76 #1023 is an unrelated firmware-loading bug.
- Do not pursue threaded-NAPI toggling (impossible without patching; ineffective in principle).
- Defer the AX210/QCNCM865 hardware swap; it is the terminal fallback only.
- Add `panic_on_oops=1` alongside the existing `panic=10` regardless of the kernel decision.

## Adversarial / Counter-Case Analysis (H4)

- **"The candidate fix might not be this bug"** — the strongest identity evidence available
  short of a bisect: identical call chain *with identical offsets* (`+0x95/0xd0`), identical
  corruption message class, identical roam trigger, reported on 7.1-rc4 (hamsa: 7.1.1/7.1.2),
  and the fix lands in the exact function-pair task 104 implicated (publish in
  `mt7925_mac_sta_add` vs re-init in `mt76_sta_add`). Task-104's skepticism standard is met in
  a way the two previously-verified fixes never were: those guarded *other* entry points, this
  one removes the re-initialization window itself.
- **"The fix may be incomplete"** — residual risk acknowledged: the new code path
  `WARN_ON_ONCE(published)` tolerates a *different* wcid being published at the same index and
  still re-inits in that case. If hamsa's corruption were an index-collision variant rather
  than the same-wcid republish, panics could persist on 7.1.3. Detection: the WARN would now
  appear in logs pre-crash. Mitigation: the diagnostics fixes below guarantee the next trace is
  captured; the hardware fallback remains.
- **"Today's panic may not even be this bug"** — true and unprovable either way: the Jul-11
  (and Jul-6) events have **no captured trace**; identity rests on the Jun-29 dumps plus
  identical macro-signature (hard journal truncation during normal WiFi-active runtime).
  A different latent bug (e.g. the zbowling-class MLO/NULL derefs) is possible. This does not
  change the recommendation — 20b126920a25 is known-absent from 7.1.2 and known-present in
  7.1.3, so the bump is justified on the confirmed Jun-29 crashes alone — but it raises the
  priority of the capture-path fix from "nice" to "required" so a post-upgrade recurrence is
  attributable.
- **"The bump might regress something else"** — task 104 hit exactly this (r-V8 breakage) on
  `nixpkgs-unstable`; but that input is independently pinned and untouched by
  `nix flake update nixpkgs`. The `nixpkgs` input tracks the stable 26.05 channel (Hydra-built),
  a week of drift (Jul 4 → Jul 11) — materially lower risk. Standard `nixos-rebuild build`
  before `switch` catches eval/build breakage.
- **"The kernelPatches fallback might silently no-op"** — it cannot: nixpkgs applies patches
  with `patch`, which fails loudly on already-applied or non-applying hunks. Verified applies
  today on v7.1; will fail (by design) once the base kernel is ≥ 7.1.3, forcing its removal.

## Recommendations (ranked)

1. **REAL FIX — bump nixpkgs to get kernel 7.1.3** (owner: task 106 implement phase):
   ```bash
   nix flake update nixpkgs                     # nixos-26.05 HEAD -> kernel 7.1.3
   nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version
   #   -> must print "7.1.3" (abort and fall back to Rec. 2 if still 7.1.2)
   nixos-rebuild build --flake .#hamsa          # build before switching
   sudo nixos-rebuild switch --flake .#hamsa && reboot
   ```
   Verification after reboot: `uname -r` = 7.1.3; confirm the fix is in the running source:
   the `published`/`rcu_dereference_protected` block in
   `mt76_sta_add()` (`drivers/net/wireless/mediatek/mt76/mac80211.c`).
2. **REAL FIX (fallback) — cherry-pick via `boot.kernelPatches`** if the bump is blocked by an
   unrelated channel regression: use the exact snippet in Finding 3 (hash precomputed, apply
   verified). Accept the local kernel compile; remove the patch at the next successful bump.
3. **DIAGNOSTICS (do regardless, same change-set)**: add
   `boot.kernel.sysctl."kernel.panic_on_oops" = 1;` to `modules/system/boot.nix` (complements
   the existing `panic=10`); keep `panic=10`. One-time root check of `/sys/fs/pstore` and
   post-task pruning of `/var/lib/systemd/pstore/` + `~/pstore-copy/` per Finding 6 — but
   **retain one Jun-29 dump** until Rec. 5 is done.
4. **MITIGATIONS (status quo)**: keep `panic=10`, `disable_aspm=1 power_save=0`. Do NOT add
   BSSID pinning or NAPI changes now — with the fix released they are pure downside.
5. **UPSTREAM HYGIENE (optional, low effort)**: reply to the fix's lore thread
   (msgid `20260528033814.46418-1-liujiajia@kylinos.cn`) or note on zbowling/mt7925 that the
   crash reproduced on a Framework 13 / Ryzen AI 9 HX 370 / RZ717 on 7.1.1–7.1.2 and (after
   verification) that 7.1.3 resolves it — closes the loop task 104 opened, and the signature is
   still uncatalogued in the community tracker.
6. **HARDWARE FALLBACK (hold)**: only if the same trace recurs ON ≥ 7.1.3 with capture working:
   swap to Intel AX210 non-vPro (or QCNCM865/ath12k) per Framework guide thread 72699.

**Success criteria**: 2+ weeks on ≥ 7.1.3 with (a) no journal-truncation freezes, (b) no new
`/var/lib/systemd/pstore/` entries, (c) no `WARN … mt76_sta_add` lines in the journal.

## Risks & Mitigations

- **Fix insufficient / different-bug recurrence** → panic_on_oops=1 + verified-empty pstore
  guarantees the next trace is captured and attributable; escalation path: kernelPatches for
  any follow-up commit, then hardware swap.
- **Channel bump breaks unrelated packages** → `nixos-rebuild build` gate before switch;
  `nixpkgs-unstable` pin untouched; rollback via systemd-boot generations.
- **kernelPatches route forgotten after later bumps** → patch fails loudly at ≥ 7.1.3;
  comment in snippet mandates removal.
- **panic_on_oops=1 side effect**: any unrelated oops now reboots the machine (after pstore
  write + 10 s) instead of limping. On this hardware history, deterministic reboot + captured
  trace is strictly preferable to a wedged desktop.

## Appendix

- **Primary sources**:
  - Mainline fix: https://github.com/torvalds/linux/commit/20b126920a259df4d7dcae19fcfe2c57a74d6b2e
    (author Jiajia Liu, authored 2026-05-28, committed 2026-06-09; lore msgid
    `20260528033814.46418-1-liujiajia@kylinos.cn`)
  - mt76 maintainer tree mirror: https://github.com/openwrt/mt76/commit/2ab6498
  - Stable inclusion: https://cdn.kernel.org/pub/linux/kernel/v7.x/ChangeLog-7.1.3
    (contains "commit 20b126920a259df4d7dcae19fcfe2c57a74d6b2e upstream"); LWN stable roundup
    https://lwn.net/Articles/1081230/ (7.1.3 among "Seven stable kernels for Saturday",
    on/about 2026-07-04)
  - nixpkgs kernel versions: `pkgs/os-specific/linux/kernel/kernels-org.json` at rev
    `a50de1b7` (7.1.2) vs `nixos-26.05` HEAD 2026-07-11 (7.1.3)
- **Prior/related upstream work** (verified already present in 7.1.x by task 104):
  - `a3c99ef88a08…` "wifi: mt76: do not add non-sta wcid entries to the poll list"
    (AUTOSEL, https://lists.linaro.org/archives/list/linux-stable-mirror@lists.linaro.org/message/EI53CCV3GNFHSFWV3OOOLXJ4X5XAJ3UU/)
  - "wifi: mt76: mt7925: fix double wcid initialization race condition" — patch 1 of
    "[PATCH v7 0/6] wifi: mt76: mt7925: MLO stability fixes" (lkml.org/lkml/2026/1/29/484,
    2026-01-29, Zac Bowling)
  - zbowling series/tracker: https://github.com/zbowling/mt7925 ,
    https://zbowling.github.io/mt7925/issues/known-issues/ (signature still uncatalogued),
    17-patch series msgid `20260105002638.668723-1-zbowling@gmail.com` (patchew)
- **Corrected reference**: https://github.com/openwrt/mt76/issues/1023 = firmware
  `strnlen`/`mt76_connac2_load_patch` overflow on 6.19-rc1 — NOT this panic (task-104 citation
  correction)
- **Unrelated but date-anchoring**: CVE-2026-53098 (mt7915 dump_work UAF, disclosed
  2026-06-24, fixed in 7.1.3 round)
- **Hardware swap references**: https://community.frame.work/t/wifi-replacement-guide-2025-version-feedback/72699 ,
  https://community.frame.work/t/replaced-the-rz717-for-qcncm865-10x-speed-upgrade-linux-highly-recommend-it/78181 ,
  https://theopark.me/blog/2025-11-28-framework-intel-ax210-upgrade/ ,
  Framework tracking thread: https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
- **Source-code evidence**: openwrt/mt76 `dma.c:1134` (`dev->napi_dev->threaded = 1;`);
  v7.1 `mac80211.c:1598` pre-image match; local `patch -p1 --dry-run` both hunks OK (offset −2)
- **Local evidence commands**: journalctl boot 0/−1 pstore-condition lines;
  `/var/lib/systemd/pstore/` listing (13 × Jun-29); efivars census (110 vars, 0 dump-type);
  `nix eval …kernel.version` = 7.1.2; `/proc/sys/kernel/panic_on_oops` = 0;
  fetchpatch hash derivation via fakeHash build in scratchpad (`prefetch.nix`)
- **Search queries used**: exact-symbol searches (`mt76_wcid_add_poll` + list_debug),
  GitHub commits API (`repo:torvalds/linux "wcid publish check"`), openwrt/mt76 commit-log
  scan, zbowling tracker, Framework forum, kernel ChangeLog greps. lore.kernel.org and
  lkml.org were Anubis-blocked; GitHub mirrors + kernel.org CDN + GitHub API used instead.

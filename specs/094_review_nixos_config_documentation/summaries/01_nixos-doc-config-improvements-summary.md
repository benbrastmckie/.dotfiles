# Implementation Summary: Task #94

**Completed**: 2026-07-05
**Duration**: ~1 session (single agent, sequential phases)

## Overview

Executed Phases 1-7 of the plan to systematically de-stale the NixOS/Home Manager dotfiles
documentation and make a small set of conservative, comment-only config cleanups. The repo was
structurally healthy going in (task 66/81-91 reorg fully landed); the work here corrected one
confirmed factual bug, brought several contributor-facing docs into agreement with the current
post-reorg module layout, closed a documentation convention gap, and swept stray emoji glyphs
from eligible docs. Phase 8 (three explicitly user-confirmation-only items) was left untouched
per the orchestration directive.

## What Changed

- `README.md` — corrected the nandi/hamsa CPU-vendor mislabel (nandi is Intel, hamsa is the AMD
  Ryzen AI 9 HX 370 host — confirmed via `hostname`/`/proc/cpuinfo` on this machine); added a
  missing `overlays/` bullet to the "Directory Organization" list.
- `docs/configuration.md` — removed stale "(planned)"/"pending Phase 2"/"gated on task 62/65"
  language; rewrote the `configuration.nix`/`home.nix` sections to describe them as thin import
  shims pointing at `modules/system/*.nix`/`modules/home/**/*.nix`; fixed the overlay heading.
- `docs/unstable-packages.md` — removed the stale "inlined in flake.nix, pending Phase 2" intro
  note and the matching "after Phase 2" caveat; both now correctly describe
  `overlays/unstable-packages.nix` as already extracted.
- `docs/how-to-add-package.md` — rewrote the decision tree to name `modules/system/packages.nix`
  and `modules/home/packages/*.nix` as primary targets (not parenthetical future work); fixed two
  stale overlay-file descriptions.
- `docs/how-to-add-service.md` — repointed all examples and the "Current Services" table to
  `modules/system/*.nix` / `modules/home/services/*.nix` (and `modules/home/memory/services.nix`
  for memory-monitor); added a new "Optional/Host-Toggled System Services" subsection naming the
  `options.<path>.enable` + `mkIf` pattern with `modules/system/optional/discord-bot.nix` as the
  worked example. Also corrected two service-table entries found to be misattributed while
  verifying ground truth: `services.openssh` is only enabled on the `usb-installer` host (not an
  always-on system service), and `services.protonmail-bridge` is actually a Home Manager service
  in `modules/home/email/protonmail.nix`, not a system service.
- `packages/README.md` — removed the `marker-pdf.nix` section and its "UVX/UV Wrapper Pattern"
  reference (confirmed zero `marker` hits in the repo); added standalone sections for
  `opencode.nix`, `kooha.nix`, `slidev.nix` (all real files wired via
  `overlays/unstable-packages.nix`); replaced all `python312`/`python312Packages` references with
  `python3`/`python3Packages`.
- `docs/packages.md` — fixed the deleted-file reference (now `overlays/unstable-packages.nix`, at
  both the intro and the "Adding Packages" section) and the stale `python312.withPackages`
  mention.
- `overlays/README.md` (new file) — per-overlay documentation mirroring `packages/README.md`'s
  format, describing `claude-squad.nix`, `unstable-packages.nix`, and `python-packages.nix`.
- `modules/system/packages.nix` — pruned the four confirmed-configured items (`mako`, `waybar`,
  `kanshi`, `swaylock`) from the dead "For use with Niri without Gnome utilities" comment block,
  with a short breadcrumb note; left the remaining uncertain X11-era items untouched.
- `home.nix` — added a one-line clarifying comment above the two historical, commented-out
  `home.stateVersion` values ("history, do not restore"); the active `24.11` value is unchanged.
- `docs/usb-installer.md`, `docs/wifi.md`, `docs/installation.md`, `docs/development.md` —
  removed emoji glyphs (⚠️, ❌, ✅, ☰, ⚙), preserving surrounding text, navigation arrows, and
  heading structure.

## Decisions

- Confirmed hamsa (this machine) is the AMD Ryzen AI 9 HX 370 (Ryzen AI 300 series) host via
  direct `hostname` + `/proc/cpuinfo` inspection, resolving the plan's "keep or drop the Ryzen AI
  300 annotation" choice in favor of keeping it, correctly attributed to hamsa.
- `modules/system/desktop.nix`'s commented `# core-network.enable = true;` line was left
  unchanged (plan's option (b) — the option's current validity was not independently confirmed
  this run, and the plan explicitly defaults to leave-unchanged when intent is unclear).
- Chose to also correct two service-table misattributions in `docs/how-to-add-service.md`
  (`openssh`, `protonmail-bridge`) beyond the plan's literal file-path-repoint instruction, since
  leaving them would have perpetuated a different factual inaccuracy while the table was already
  being rewritten for accuracy.
- Chose to also fix a third (unlisted) stale `unstable-packages.nix` path reference in
  `docs/packages.md`'s "Adding Packages" section, same finding category as the two the plan named.

## Plan Deviations

- Phase 3: altered — corrected two additional service-table misattributions
  (`services.openssh`, `services.protonmail-bridge`) beyond the plan's literal scope; same
  doc-accuracy finding category, no functional/config changes.
- Phase 4: altered — fixed a third stale `unstable-packages.nix` path reference in
  `docs/packages.md` not explicitly named in the plan's line list.
- Phase 6: `modules/system/desktop.nix` — no change made (plan's default option (b) taken
  explicitly; not a deviation from the plan, but noted per the plan's own instruction to record
  the choice).
- Phase 7: altered — added a missing `overlays/` bullet to root `README.md`'s "Directory
  Organization" list, since the new `overlays/README.md` needed a discoverable pointer from the
  root README to actually close the stated convention gap.
- Phase 8: deferred entirely, as instructed. No files under this phase were touched:
  `docs/ryzen-ai-300-compatibility.md`, `docs/ryzen-ai-300-support-summary.md`, `docs/niri.md`
  remain unmodified (verified via `git status --short`).

## Verification

- Flake check: Success (`nix flake check` — all 4 `nixosConfigurations` +
  `homeConfigurations` evaluate cleanly; only pre-existing, unrelated `boot.zfs.forceImportRoot`
  default-value warnings, no new errors).
- Doc accuracy: re-read every edited doc; zero remaining "planned"/"pending Phase 2"/"gated on
  task" language (`grep -i` swept clean); zero `python312`/`marker-pdf` references remain in
  `packages/README.md` or `docs/packages.md`.
- Emoji sweep: zero emoji glyphs remain in scanned range across all eligible `docs/*.md` files;
  navigation arrows (`→`, `↓`) preserved; no orphaned double-spaces or altered heading text.
- Config comment-only edits: `git diff` confirms only comment lines changed in
  `modules/system/packages.nix` and `home.nix`; `modules/system/desktop.nix` has no diff; no
  active option or `stateVersion` value was altered.
- Phase 8 files unmodified: confirmed via `git status --short`.

## Notes

- Recommend spawning follow-up task(s) for the three Phase 8 items: Ryzen doc consolidation
  (`docs/ryzen-ai-300-compatibility.md` + `docs/ryzen-ai-300-support-summary.md` near-duplicates),
  the niri.md "testing phase" framing re-confirmation, and a dedicated `docs/niri.md` emoji-strip
  task (~58 glyphs across 1035 lines) — all three require user judgment/confirmation before
  acting, per the plan's non-goals.
- `overlays/README.md` is a new file; `docs/configuration.md` now links to it (created earlier in
  this same run via Phase 7, so the link resolves).

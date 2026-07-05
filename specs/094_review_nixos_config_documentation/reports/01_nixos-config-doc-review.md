# Research Report: Task #94

**Task**: 94 - Systematically review the NixOS config to improve the documentation (and the
config) where relevant
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: Medium (mostly doc-only fixes; a few small config cleanups)
**Dependencies**: None (builds on the completed task 66/81-91 reorg + task 65 python312->python3
migration)
**Sources/Inputs**:
- Codebase: `flake.nix`, `lib/mkHost.nix`, `configuration.nix`, `home.nix`, `modules/system/**`,
  `modules/home/**`, `overlays/*.nix`, `packages/*.nix`, `hosts/**`, `docs/*.md`, `README.md`,
  `packages/README.md`, `hosts/README.md`, `modules/README.md`
- Git history: `git log` on `docs/README.md`, `docs/configuration.md`,
  `docs/how-to-add-package.md`, `docs/how-to-add-service.md`, `docs/niri.md`
- `specs/091_documentation_sync_reorg_final/summaries/01_documentation-sync-final-summary.md`
  (explicitly records some of the same stale spots as deferred follow-ups)
- `specs/065_migrate_python312_pins_to_default_python3/summaries/01_implementation-summary.md`
**Artifacts**: This report —
`specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The repo is in good structural shape: the task 66/81-91 reorg (thin `configuration.nix`/`home.nix`,
  `modules/system/` + `modules/home/` aggregator convention, `overlays/`, `lib/mkHost.nix`) is
  fully implemented and internally consistent, and per-module header comments are uniformly good.
- However, several **narrative docs describe the pre-reorg architecture as still in progress**
  ("planned Phase 2", "gated on tasks 62/65") even though that work finished tasks ago. This is
  the single largest issue: `docs/configuration.md`, `docs/unstable-packages.md`,
  `docs/how-to-add-package.md`, and `docs/how-to-add-service.md` would actively misdirect a new
  contributor (or agent) into editing `configuration.nix`/`home.nix` directly instead of the
  correct current-convention module files.
- Found a **confirmed factual bug**, not just staleness: root `README.md`'s module map labels
  `nandi` as "Primary workstation (AMD Ryzen AI 300)", but `hosts/nandi/hardware-configuration.nix`
  uses `kvm-intel`/`hardware.cpu.intel` — nandi is Intel. `hamsa` is the actual AMD host
  (`kvm-amd`/`hardware.cpu.amd`), and root README doesn't label it as such. `hosts/README.md` and
  `hosts/nandi/README.md` both correctly say "Intel", so only the root README module-map line is
  wrong.
- `packages/README.md` documents a **nonexistent package** (`marker-pdf.nix` — confirmed deleted,
  zero hits on `find`), is missing entries for three packages that do exist (`opencode.nix`,
  `kooha.nix`, `slidev.nix`), and contains 5 stale `python312.withPackages` references although
  task 65 migrated the whole repo to `python3.withPackages` (confirmed zero `python312` hits in
  any `.nix` file). `docs/packages.md` has the same two problems (references the deleted
  root-level `unstable-packages.nix`; one stale `python312` mention).
- Task 91's own summary already flagged the `docs/configuration.md` / `docs/unstable-packages.md`
  "(planned)"/"pending Phase 2" lines and the `packages/README.md` `marker-pdf.nix`/missing-sections
  gap as **known, explicitly out-of-scope follow-ups** — this task is a natural place to close
  those out, plus the additional drift found independently below (`how-to-add-*.md`,
  `docs/packages.md`, the `python312` doc references, the nandi/hamsa CPU mislabel).
- Secondary, lower-risk findings: the repo's own "No emojis in documentation files" rule (added
  in task 91, commit `50ac345`) predates most of the doc corpus, so ~14 of ~23 doc files still
  contain emoji (`docs/niri.md` worst at ~58 glyphs); two Ryzen AI 300 docs are near-duplicates
  and both violate the emoji rule; a few small dead/uncommented code fragments exist in
  `modules/system/packages.nix` and `modules/system/desktop.nix`.

## Context & Scope

This is a documentation-and-config-quality audit of `/home/benjamin/.dotfiles`, a NixOS + Home
Manager flake-based dotfiles repo. Research-only: no files were modified. Scope covered
`flake.nix`, `lib/mkHost.nix`, `hosts/`, `modules/system/`, `modules/home/`, `overlays/`,
`packages/`, `configuration.nix`, `home.nix`, and all of `docs/*.md` plus the directory-level
`README.md` files (root, `hosts/`, `modules/`, `packages/`, `docs/`). The repo has an unusually
rich task history of prior reorg/doc-sync work (tasks 66, 78, 81-91); this review deliberately
cross-checked its findings against that history to avoid re-flagging already-fixed issues and to
build on task 91's own explicitly-recorded follow-up list.

## Findings

### Repository structure (baseline — healthy)

- `flake.nix` → `lib/mkHost.nix` factory → `nixosConfigurations.{nandi,hamsa,garuda,usb-installer}`
  (`iso` wired directly, documented rationale: no `hardware-configuration.nix`). Clean, well
  commented, no drift found.
- `configuration.nix` (19 lines) and `home.nix` (20 lines) are thin aggregator shims that just
  `import ./modules/system` / `./modules/home` respectively — this is real and matches
  `modules/README.md`'s documented convention (task 86 aggregator pattern). All 12 system modules
  and ~30 home modules have solid one-line header comments describing purpose and, where
  relevant, a `specs/NNN.../` or `.claude/rules/nix.md` cross-reference.
- `overlays/` (`claude-squad.nix`, `unstable-packages.nix`, `python-packages.nix`) and
  `packages/*.nix` (13 files) are fully populated, real, non-planned artifacts.
- `modules/README.md` is itself an excellent, current, recently-written (task 91) document —
  no issues found there.

### High priority — doc/config mismatches that actively misdirect

1. **`docs/configuration.md`** (last touched 2026-06-24, task 66 phases 7-8; task 91 only
   patched one unrelated line in it) describes the **pre-reorg** state as current:
   - Lines 18-19: `overlays/` and `lib/` are marked `# (planned)` in the ASCII tree, even though
     both are fully implemented (`overlays/*.nix` × 3, `lib/mkHost.nix`).
   - Lines 23-25: a blockquote states "Phases 2-6 ... are gated on tasks 62 and 65 completing
     first" — tasks 62 and 65 are both complete, and phases 2-6 of task 66 (plus the whole
     task-81 reorg) are done.
   - Line 54: "`### Package Overlays (inlined in flake.nix, pending Phase 2 extraction)`" — false;
     all three overlays are extracted files, curried/imported from `flake.nix`.
   - Lines 27-43 and 75-83 describe `configuration.nix`/`home.nix` as directly containing all
     system/user settings ("System packages and services... Boot configuration...", "Application
     configurations... Dotfiles management...") — both files are now 19-20-line import shims; the
     real content lives in `modules/system/*.nix` / `modules/home/**/*.nix`.
   - **Note**: task 91's summary explicitly recorded lines 18-19 and 22-25 as a deferred
     follow-up ("not fixed, to avoid scope creep") — this task is the natural place to close it,
     along with the newly-found line 54 and the 27-43/75-83 sections.
   - Fix: doc-only. Rewrite the "File Structure" ASCII tree and the `configuration.nix`/`home.nix`
     prose sections to point at the actual `modules/system/` + `modules/home/` split (mirroring
     `modules/README.md`), and delete the stale task-66 status blockquote entirely.

2. **`docs/unstable-packages.md`** lines 5-7 and line 51: states the unstable-packages overlay is
   "inlined in `flake.nix`... pending Phase 2 extraction to `overlays/unstable-packages.nix`" —
   directly contradicted two lines later in the same file (line 12), which correctly says the
   overlay **is already** "implemented in `overlays/unstable-packages.nix`". Also flagged (lines
   5-7 only) as a deferred follow-up in task 91's summary; line 51 was not caught.
   - Fix: doc-only. Delete the stale intro note; update line 51's "(after Phase 2: ...)" caveat.

3. **`docs/how-to-add-package.md`** — not previously flagged. Actively describes the **superseded**
   workflow as current:
   - Lines 9, 13: decision tree says add packages to `environment.systemPackages`
     "in `configuration.nix` (or `modules/system/packages.nix` after Phase 4b)" and `home.packages`
     "in `home.nix` (or `modules/home/packages/*.nix` after Phase 5b)" — both "after Phase" targets
     are the actual current locations; `configuration.nix`/`home.nix` are no longer where packages
     are declared.
   - Line 80: `# In overlays/unstable-packages.nix (planned Phase 2 artifact)` — the file exists
     and is in active use.
   - Line 97: "Custom Python packages live in `overlays/python-packages.nix` (planned Phase 2
     artifact; currently inlined in `flake.nix`)" — false; it's a real standalone file
     (confirmed by direct read), not inlined.
   - Fix: doc-only. Rewrite the decision tree and examples to point at
     `modules/system/packages.nix` / `modules/home/packages/*.nix` as the primary (not parenthetical
     future) locations, matching the aggregator convention in `modules/README.md`.

4. **`docs/how-to-add-service.md`** — not previously flagged. Same pattern: all examples show
   adding `systemd.services.*`/`services.<name>` directly to `configuration.nix`/`home.nix`, and
   the "Current Services in This Config" table (lines 104-121) attributes services to
   `configuration.nix`/`home.nix` — but system services now live in `modules/system/*.nix` (e.g.
   `services.nix`, `optional/discord-bot.nix`) and user services in
   `modules/home/services/*.nix`. The guide also never mentions the **optional/host-toggled
   module pattern** (`options.<path>.enable` + `mkIf`, documented in `modules/README.md` and
   `.claude/rules/nix.md`) that `modules/system/optional/discord-bot.nix` actually uses for a
   host-specific service — which is exactly the scenario this guide's own "Discord-Bot Style
   Service" section (lines 123-148) walks through, without naming the pattern it's demonstrating.
   - Fix: doc-only. Update file paths in all examples and the service table; add a short
     subsection on the optional/host-toggled module pattern with a pointer to
     `modules/system/optional/discord-bot.nix` as the worked example.

5. **`packages/README.md`** — three issues, two already flagged by task 91 as an explicit
   out-of-scope follow-up ("recommended as a follow-up `/fix-it` or spawned task"):
   - Documents `marker-pdf.nix` in detail (lines 48-59, plus a whole "UVX/UV Wrapper Pattern"
     section referencing it at line 132) — file does not exist (`find . -iname "*marker*"` →
     zero hits).
   - Missing standalone sections for `opencode.nix`, `kooha.nix`, `slidev.nix` — all three exist
     as real files and are referenced from `overlays/unstable-packages.nix`.
   - **New finding** (not in task 91's list): 5 occurrences of stale `python312.withPackages`
     (lines 106, 110, 161, 165, and the `python312Packages.cvc5` mention at line 98) — task 65
     migrated the entire repo to `python3`; zero `python312` references remain in any `.nix`
     file.
   - Fix: doc-only. Delete the `marker-pdf.nix` section and its wrapper-pattern reference; add
     sections for `opencode.nix`/`kooha.nix`/`slidev.nix`; replace `python312` with `python3`
     throughout.

6. **`docs/packages.md`** — new finding, same family:
   - Line 14: "Packages from nixpkgs unstable channel defined in `unstable-packages.nix`" —
     references the **deleted** root-level file (task 66 Phase 1) instead of
     `overlays/unstable-packages.nix`.
   - Line 39: `python312.withPackages` — stale per task 65 (see above).
   - Fix: doc-only, two one-line edits.

### High priority — factual error (not staleness)

7. **Root `README.md` mislabels nandi's CPU vendor.** Line 32 of the "Module Map" ASCII tree:
   ```
   │   ├── nandi/hardware-configuration.nix   # Primary workstation (AMD Ryzen AI 300)
   ```
   Verified against `hosts/nandi/hardware-configuration.nix`: `boot.kernelModules = [ "kvm-intel" ]`
   and `hardware.cpu.intel.updateMicrocode = ...` — nandi is **Intel**, not AMD. The actual AMD
   host is `hamsa` (`kvm-amd` / `hardware.cpu.amd.updateMicrocode`), which the same ASCII tree
   labels only as "Secondary machine" with no CPU vendor at all (line 33). `hosts/README.md`
   ("Nandi host system (Intel laptop)", "Hamsa host system (AMD laptop)") and
   `hosts/nandi/README.md` ("CPU: Intel with KVM support") are both already correct — only the
   root README's module-map comment is wrong, likely a copy/paste or host-rename artifact.
   - Risk if left as-is: actively misleading for anyone using the module map as ground truth
     (e.g. deciding which host to test AMD-specific config on), and it contradicts
     `docs/ryzen-ai-300-compatibility.md`/`docs/ryzen-ai-300-support-summary.md`, which are about
     the AMD Ryzen AI 9 HX 370 and are presumably about `hamsa`, not `nandi`.
   - Fix: one-line edit — swap the CPU annotation to `hamsa`'s line (or drop the annotation
     entirely and point to `hosts/README.md` for hardware details, consistent with how
     `garuda`'s line already has no CPU annotation).

### Medium priority

8. **Emoji convention not retroactively enforced.** `docs/README.md`'s "No emojis in
   documentation files" rule was added in task 91 (commit `50ac345`, 2026-07-05), so it only
   applies going forward by default; the existing corpus was never swept. Emoji-glyph counts
   found (excluding the `←` nav arrows used intentionally in README cross-links):
   `docs/niri.md` ~58, `docs/usb-installer.md` 22, `docs/himalaya.md` 13,
   `docs/how-to-add-package.md` 12, `docs/ryzen-ai-300-support-summary.md` 10,
   `docs/ryzen-ai-300-compatibility.md` 7, `docs/discord-bot.md` 6,
   `docs/how-to-add-service.md` 6, `docs/wifi.md` 6, plus smaller counts in `gnome-settings.md`,
   `dictation.md`, `development.md`, `installation.md`, `unstable-packages.md`. This is
   mechanical, low-risk, doc-only cleanup — but `docs/niri.md` at 1035 lines is large enough that
   it likely warrants its own follow-up task rather than folding into this one.

9. **`docs/ryzen-ai-300-compatibility.md` (210 lines) and `docs/ryzen-ai-300-support-summary.md`
   (120 lines) are near-duplicate content** — both cover AMD Ryzen AI 300 / USB-installer
   hardware support with substantially overlapping headings ("Fully Supported", "Ryzen AI
   Specific/Advantages Features", "Installation Process", "Expected Performance", "Conclusion").
   `support-summary.md` reads like a session recap of the same work documented in
   `compatibility.md` (its heading "🔧 What I've Updated" and "📖 Created Comprehensive Guide"
   language is self-referential to having just written the other file) — it resembles a
   changelog entry more than a durable topic doc. The repo's own `docs/README.md` "Prohibited
   practices" section discourages exactly this kind of redundant quick-reference duplication.
   Recommend consolidating into `ryzen-ai-300-compatibility.md` (more thorough, canonical) and
   either deleting `support-summary.md` or moving any unique content into the canonical file —
   **confirm with the user first**, since it's possible they intentionally want an
   executive-summary variant kept separate.

10. **`docs/niri.md`'s "Recommended Usage Strategy" section (lines ~95-112) may be stale relative
    to actual usage.** It frames "GNOME + PaperWM" as the current daily driver and niri as
    "Phase 1: Current - Testing (You are here!)" of a 3-phase migration plan. However: (a) no
    PaperWM GNOME extension appears anywhere in `modules/home/desktop/gnome.nix`'s
    `enabled-extensions` list (only `activate-window-by-title`, `unite`, `mouse-follows-focus`),
    and (b) `flake.nix`/`overlays/unstable-packages.nix` both describe niri as "**ENABLED**
    (dual-session with GNOME)" — a settled state, not an experimental one — and tasks 74-77
    (niri session startup, keybindings, hardware keys, GNOME service reconciliation) have since
    landed. This reads like leftover framing from before niri was made a permanent dual-session
    option. **This is a "verify with user" item, not a mechanical fix** — it concerns actual
    day-to-day usage state, which only the user can confirm, not something inferable purely from
    config.

### Low priority — small config/comment cleanups

11. **`modules/system/packages.nix` lines 24-35**: a commented-out block "For use with Niri
    without Gnome utilities" lists `mako`, `grim`, `slurp`, `swaylock`, `waybar`, `swayidle`,
    `network-manager-applet`, `blueman`, `wl-clipboard-x11`, `clipman`, `kanshi` as
    not-yet-added. This predates niri's dual-session enablement: `mako`, `waybar`, `kanshi`, and
    `swaylock` are now genuinely configured (as home-manager modules —
    `modules/home/desktop/{mako,kanshi,swaylock,waybar}.nix` all exist and are imported). The
    comment block is stale for those four and should be pruned to just the items still actually
    missing (`grim`, `slurp`, `swayidle`, `network-manager-applet`, `blueman`,
    `wl-clipboard-x11`, `clipman` — verify each before removing since some may be deliberately
    still-excluded X11-era leftovers).

12. **`modules/system/desktop.nix:70`**: `# core-network.enable = true;  # Ensure GNOME network
    components are enabled` — an unexplained commented-out option, inconsistent with the two
    lines immediately below it (`localsearch.enable = false` / `tinysparql.enable = false`),
    which both carry full rationale and a `specs/40_...` cross-reference. Also uncertain whether
    `services.gnome.core-network` is even a valid current NixOS option (not confirmed via
    MCP/options search in this pass). Recommend either documenting why it's disabled (with a
    spec/task reference, matching the sibling lines) or removing the stray line if it's dead.

13. **`home.nix` lines 17-19**: two fully commented-out historical `home.stateVersion` values
    (`24.05`, `23.11`) beneath the active `24.11` line. Harmless (and the active value is
    correctly frozen per `modules/README.md`'s "Verified Health Notes" — never bump an existing
    `stateVersion`), but the dead lines are unexplained clutter. A one-line comment
    ("history, do not restore") or deletion would tidy this; very low priority, cosmetic only.

14. **`overlays/` has no `README.md`**, unlike its sibling directories `hosts/`, `modules/`,
    `packages/`, `config/` (all of which root `README.md`'s "Directory Organization" section
    links to). Given `overlays/` is only 3 short, well-commented files, this isn't urgent, but a
    short `overlays/README.md` (mirroring `packages/README.md`'s per-file format) would close a
    real convention gap and give `flake.nix`'s overlay list somewhere authoritative to point to.

## Decisions

- Treated task 91's summary "Out-of-Scope Follow-Up" and "Plan Deviations" sections as
  authoritative prior art: findings 1, 2, and 5 (`docs/configuration.md`,
  `docs/unstable-packages.md`, `packages/README.md`'s `marker-pdf.nix`/missing-sections) were
  independently re-confirmed against the current tree rather than assumed still-accurate from
  that prior report, per the repo's own "Docs verified against source, not fixed once"
  convention (`docs/README.md`).
- Did not attempt to verify whether `services.gnome.core-network` (finding 12) is a real NixOS
  option via MCP-NixOS/nixos-options search — flagged as an open question for the implementation
  pass rather than guessed at.
- Excluded `docs/niri.md`'s emoji cleanup from being bundled with the "Phase 1: Testing" usage-
  strategy question (finding 10) even though they're in the same file, because one is mechanical
  (emoji strip) and the other requires user confirmation of current usage — conflating them risks
  an implementation agent skipping the mechanical fix while waiting on the judgment call.

## Risks & Mitigations

- **Do not touch `modules/home/services/gmail-oauth2.nix`.** It is fully, deliberately disabled
  (task 72 Phase 3) with an exceptionally thorough rationale comment and explicit "kept commented,
  not deleted, to allow one-block revert" instruction. This is the gold-standard example of *why*
  a module is disabled — the opposite of finding 12's problem — and should be treated as a
  reference for how to document finding 12's `core-network` line, not as something to clean up
  itself.
- **Do not touch `flake.lock` transitive-duplicate nixpkgs pins or either `stateVersion`.** Both
  are explicitly recorded as "checked, no action needed" in `modules/README.md`'s Verified Health
  Notes; re-litigating them would contradict a already-completed verification pass.
- **`overlays/unstable-packages.nix` line 10** (`# opencode = pkgs-unstable.opencode; # ...`,
  superseded by the custom-build line 11) is intentional history-preserving comment, matching the
  repo's stated inline-comment convention (explain *why*) — no action needed, noted here so a
  future pass doesn't re-flag it as dead code.
- **Ryzen doc consolidation (finding 9) and niri usage-phase framing (finding 10) both touch
  content that may reflect deliberate user choices** (keeping an executive-summary doc separate;
  genuinely still being in a "testing niri" phase) — confirm with the user before deleting or
  substantially rewriting either, rather than treating them as pure staleness.
- All "High priority" findings (1-7) are doc-only or single-line edits with no build/runtime
  impact — safe to implement without a `nixos-rebuild`/`home-manager switch` cycle, though a
  `nix flake check` re-run after any `.nix` comment edits (findings 11-13) is still good practice
  per the repo's CI gate.

## Appendix

### Search/verification commands used

```bash
find . -maxdepth 2 -not -path '*/.git*'
grep -rn "marker-pdf\|marker_pdf" --include="*.nix" .
grep -rn "python312" -r . --include="*.nix" --include="*.md"
grep -rn "planned\|pending\|Phase [0-9]\|TODO\|stub" docs/*.md README.md
grep -oP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' docs/*.md | sort | uniq -c
grep -in "cpu\|vendor\|amd\|intel\|kvm-amd\|kvm-intel" hosts/{nandi,hamsa,garuda}/hardware-configuration.nix
git log --oneline -5 -- docs/README.md docs/configuration.md docs/how-to-add-package.md docs/niri.md
```

### Files read in full or substantially

`flake.nix`, `lib/mkHost.nix`, `configuration.nix`, `home.nix`, `modules/system/default.nix`,
`modules/home/default.nix`, `modules/system/desktop.nix`, `modules/system/packages.nix`,
`modules/home/desktop/gnome.nix`, `modules/home/services/gmail-oauth2.nix`,
`overlays/{claude-squad,unstable-packages,python-packages}.nix`, `README.md`, `docs/README.md`,
`docs/configuration.md`, `docs/unstable-packages.md`, `docs/packages.md`,
`docs/how-to-add-package.md`, `docs/how-to-add-service.md`,
`docs/ryzen-ai-300-{compatibility,support-summary}.md` (headings + emoji scan),
`docs/niri.md` (usage-strategy section + emoji scan), `hosts/README.md`,
`hosts/{garuda,nandi}/README.md`, `modules/README.md`, `packages/README.md`.

### Cross-references

- `specs/091_documentation_sync_reorg_final/` — prior doc-sync capstone; source of the
  already-recorded follow-up list this task partially closes out.
- `specs/065_migrate_python312_pins_to_default_python3/` — source of ground truth for the
  `python312` → `python3` doc staleness findings.
- `.claude/rules/nix.md` — authoritative source for the always-on vs. optional/host-toggled
  module convention referenced in findings 4 and 11.

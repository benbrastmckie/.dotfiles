# Research Report: Task #95

**Task**: 95 - post_reorg_documentation_sweep — fix all remaining docs that still point
contributors at `configuration.nix`/`home.nix` for content that now lives in
`modules/system/*`/`modules/home/**`, plus `docs/dictation.md`'s independent staleness
(package rename, broken line reference, dead `wtype` references)
**Started**: 2026-07-05T02:55:55-07:00
**Completed**: 2026-07-05T03:20:00-07:00
**Effort**: Medium (9 files, all doc-only line-level edits; no config changes; no `nix flake
check` needed)
**Dependencies**: None (task 94 Phases 1-7 already landed; this closes Group A of task 94's
follow-up backlog)
**Sources/Inputs**:
- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group A,
  the authoritative enumerated defect list this report grounds and re-verifies against current
  line numbers)
- Live repo tree: `README.md`, `hosts/{nandi,garuda}/README.md`, `docs/{dictation,neovim,
  gnome-settings,discord-bot,installation,development}.md`, `docs/configuration.md`,
  `docs/how-to-add-{package,service}.md` (established fix pattern), `modules/system/**`,
  `modules/home/**`, `configuration.nix`, `home.nix`, `flake.nix`, `hosts/README.md`
**Artifacts**: This report —
`specs/095_post_reorg_documentation_sweep/reports/01_post-reorg-doc-sweep.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every defect the backlog (task 94 report 02, Group A) named was re-verified against the current
  tree and still exists at (in most files) the same line numbers. Two files — `docs/discord-bot.md`
  and `docs/gnome-settings.md` — have **more** stale `configuration.nix`/`home.nix` references than
  the backlog explicitly enumerated; this report lists the full current set for each file so the
  plan can close the category completely rather than just the backlog's sample lines.
- The corrected wording pattern already exists in the repo (`docs/configuration.md` lines 25-30 and
  71-76, `docs/how-to-add-package.md`, `docs/how-to-add-service.md`) — task 94's own fix style.
  Every edit below should mirror that established phrasing: name the specific
  `modules/system/*.nix` or `modules/home/**/*.nix` file, not just the aggregator directory.
- **Not every `configuration.nix`/`home.nix` mention is stale.** Several are legitimate,
  mechanism-level references that should be left untouched: `hosts/README.md` (describes `mkHost`
  wiring, accurate), `modules/README.md` (describes the two-shim split, accurate),
  `docs/configuration.md` itself (already fixed), and root `README.md` lines 102 and 182 (describe
  what `home-manager switch`/`nixos-rebuild` mechanically evaluate — `home.nix` genuinely is the
  entry point they run against — not a "where do I add config" pointer). This report flags these
  explicitly so the plan doesn't over-correct.
- `docs/dictation.md`'s three independent defects are all confirmed: `openai-whisper-cpp` (line 20)
  has zero hits in any `.nix` file — actual package is `whisper-cpp`
  (`modules/home/packages/media-dictation.nix:9`, with an inline rename comment). The
  `home.nix:183-264` reference (line 271) is unresolvable — `home.nix` is 22 lines total
  (confirmed `wc -l`); the actual script lives in `modules/home/scripts/whisper.nix` lines 6-74
  (the `whisper-dictate` `writeShellScriptBin` block, terminated by the next block at line 75).
  `wtype` (lines 311, 321) has zero hits in any `.nix` file — confirmed sole mechanism is
  `ydotool` (`modules/home/services/ydotool.nix` for the daemon,
  `modules/home/packages/media-dictation.nix` for the package), and the doc's own line 163 already
  explains why GNOME needs `ydotool` instead of `wtype`.

## Context & Scope

Research-only, no files modified. Scope: the 9 files named in the task description (root
`README.md`, `hosts/{nandi,garuda}/README.md`, and 6 topic docs). For each file: located every
`configuration.nix`/`home.nix` reference via `grep -n`, classified each as stale (misdirects to a
file whose actual content moved to `modules/system/*`/`modules/home/**`) or legitimate (accurate
mechanism/entry-point reference), and traced the real current location via `grep` against
`modules/system/**`/`modules/home/**`. Line numbers below are current as of this research pass
(2026-07-05); re-verify before editing if further commits land first, per this repo's own
"docs verified against source, not fixed once" convention (`docs/README.md`).

## Findings

### File 1 — Root `README.md` (4 spots, backlog finding 1)

Verified via `grep -n "configuration\.nix\|home\.nix" README.md`. All four backlog-named spots
confirmed at the same lines; two additional legitimate (non-stale) mentions also found and
explicitly excluded below.

| Line(s) | Current text | Status | Corrected target |
|---|---|---|---|
| 9 | "**System Configuration**: NixOS system-wide settings via `configuration.nix`" | STALE | Should read "...via `modules/system/*.nix`" (or "the `modules/system/` aggregator") — `configuration.nix` is a 19-line import shim (confirmed `wc -l configuration.nix` = 19), all actual settings live in `modules/system/*.nix`. |
| 10 | "**User Environment**: Home Manager configuration in `home.nix`" | STALE | Should read "...in `modules/home/**/*.nix`" — `home.nix` is a 22-line import shim (confirmed `wc -l home.nix` = 22). |
| 19 | "[`configuration.nix`](configuration.nix): System-wide NixOS configuration" | STALE | Reword to describe it as the thin import shim (mirror `docs/configuration.md:25`: "A thin import shim: it imports `./modules/system`..."), and add a line pointing at `modules/system/*.nix` as the actual edit target. |
| 20 | "[`home.nix`](home.nix): Home Manager user environment configuration" | STALE | Same treatment, mirroring `docs/configuration.md:71` ("A thin import shim: it imports `./modules/home`...") and pointing at `modules/home/**/*.nix`. |
| 27-29 | ASCII tree: `configuration.nix # System NixOS config (boot, hardware, services, packages)` / `home.nix # User Home Manager config (apps, dotfiles, user services)` | STALE | These inline comments describe content that lives in `modules/system/*.nix`/`modules/home/**/*.nix`, not in the two shim files. The tree already has correct entries for `modules/` (lines 59-62: "system/ # Always-on NixOS modules..." / "home/ # Home Manager modules..."). Reword lines 28-29's inline comments to say something like `# Thin import shim -> modules/system/` and `# Thin import shim -> modules/home/` so the tree doesn't contradict its own `modules/` entry two blocks down. |
| 125 | "**System changes**: Edit [`configuration.nix`](configuration.nix)" | STALE (most actively misleading) | Should read "Edit `modules/system/*.nix`" (or link `modules/README.md`) — directly contradicts the corrected `docs/how-to-add-package.md:9`/`docs/how-to-add-service.md:9` guidance ("YES → environment.systemPackages in modules/system/packages.nix" / "YES → System service in modules/system/*.nix"). |
| 126 | "**User environment**: Edit [`home.nix`](home.nix)" | STALE | Should read "Edit `modules/home/**/*.nix`" — contradicts `docs/how-to-add-package.md:13` ("YES → home.packages in modules/home/packages/*.nix"). |
| 102 | "Both commands evaluate `home.nix`" | **Not stale — leave as-is** | Accurate: `home.nix` genuinely is the file both `nixos-rebuild` and `home-manager switch` evaluate as their entry point (it imports `./modules/home`). This describes build mechanics, not "where to add config." |
| 182 | "Both commands install `home.nix` packages to separate profile paths" | **Not stale — leave as-is** | Same reasoning as line 102. |

### File 2 — `hosts/nandi/README.md` (backlog finding 2)

Verified via `grep -n "configuration\.nix\|home\.nix" hosts/nandi/README.md`.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 29 | "This hardware configuration is auto-generated by `nixos-generate-config` and should not be modified manually. System-specific changes should be made in the main `configuration.nix` file." | STALE | Reword to: always-on system settings go in `modules/system/*.nix`; host-specific overrides (opt-in modules like the Discord bot relay this host already imports, per `hosts/nandi/default.nix:2,7`) go in `hosts/nandi/default.nix`, per `.claude/rules/nix.md`'s always-on vs. optional/host-toggled distinction. |

### File 3 — `hosts/garuda/README.md` (backlog finding 2)

Verified via `grep -n "configuration\.nix\|home\.nix" hosts/garuda/README.md`. Identical stale
sentence to nandi's, one line earlier.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 25 | "This hardware configuration is auto-generated by `nixos-generate-config` and should not be modified manually. System-specific changes should be made in the main `configuration.nix` file." | STALE | Same corrected wording as nandi above, adjusted: garuda has no `hosts/garuda/default.nix` (confirmed — only nandi and usb-installer carry a `default.nix` per `hosts/README.md:29-32`), so the host-specific-override sentence should say "if garuda needs host-specific overrides, add `hosts/garuda/default.nix`" rather than referencing an existing file. |

### File 4 — `docs/dictation.md` (backlog finding 3 — 4 independent defects)

Verified via `grep -n "configuration\.nix\|home\.nix\|openai-whisper\|wtype\|whisper-cpp" docs/dictation.md` plus full-file read.

| Line(s) | Current text | Defect type | Corrected target |
|---|---|---|---|
| 18 | "The dictation tools are already configured in `home.nix`:" | Stale file pointer | Reword to name the three real module files: `modules/home/scripts/whisper.nix` (the `whisper-dictate`/`whisper-download-models` scripts), `modules/home/services/ydotool.nix` (the daemon), `modules/home/packages/media-dictation.nix` (the `whisper-cpp` package). |
| 20 | "`openai-whisper-cpp`: Fast C++ implementation of Whisper" | Stale package name | Package was renamed to `whisper-cpp`. Confirmed: `modules/home/packages/media-dictation.nix:9` — `whisper-cpp # Fast offline speech-to-text (renamed from openai-whisper-cpp)`. Zero `openai-whisper-cpp` hits remain in any `.nix` file (confirmed `grep -rn "openai-whisper" --include="*.nix" .` returns only the rename-comment above). Change bullet to `whisper-cpp: Fast offline speech-to-text (C++ implementation of Whisper)`. |
| 271 | "The script is defined in `home.nix` (home.nix:183-264). You can:" | Broken line reference | `home.nix` is 22 lines total (confirmed `wc -l home.nix` = 22); a `183-264` range cannot exist there. The `whisper-dictate` script actually lives in `modules/home/scripts/whisper.nix`, lines 6-74 (the `writeShellScriptBin "whisper-dictate"` block; the next block, `writeShellScriptBin "whisper-download-models"`, starts at line 75, confirmed via `grep -n "writeShellScriptBin"`). Corrected text: "The script is defined in `modules/home/scripts/whisper.nix` (lines 6-74)." |
| 311 | "- **wtype Documentation**: https://github.com/atx/wtype" | Dead reference | `wtype` has zero hits in any `.nix` file (confirmed `grep -rn "wtype" --include="*.nix" .` returns nothing). The doc's own line 163 explains: "GNOME's compositor (Mutter) doesn't support the virtual keyboard protocol that other tools like `wtype` need. ydotool works at a lower level..." — the `wtype` link directly contradicts this. Remove the `wtype` Resources bullet (or replace with a `ydotool` documentation link if one is wanted). |
| 321 | `\| \`echo "text" \| wtype -\` \| Test text input \|` (Quick Reference table row) | Dead reference | Same contradiction as line 311 — no `wtype` binary is installed anywhere in this config. Replace with the actual `ydotool` test-input equivalent, or remove the row if no simple one-liner equivalent exists (note: `ydotool` typically needs `ydotool type "text"` once the daemon is running — verify exact invocation during implementation, don't guess a syntax that hasn't been tested). |

Note: line 18's fix should NOT introduce a home.nix reference at all (three real files, no shim
mention needed) — this is a case where task 94's "point at modules/X instead of the shim" pattern
applies cleanly.

### File 5 — `docs/neovim.md` (backlog finding 4)

Verified via `grep -n "configuration\.nix\|home\.nix" docs/neovim.md` plus context read.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 9 | "`programs.neovim.enable = true` is kept in `home.nix` for two reasons:" | STALE | `programs.neovim` is declared in `modules/home/core/neovim.nix` (confirmed line 4: `programs.neovim = {`), not `home.nix`. Reword to "...is kept in `modules/home/core/neovim.nix` for two reasons:". |
| 58 | "- [Neovim module in home.nix](../home.nix) -- `programs.neovim` block with the active configuration values" | STALE (markdown link target too) | Both the link text and the relative link target (`../home.nix`) need to change to `modules/home/core/neovim.nix` — from `docs/neovim.md` the relative path is `../modules/home/core/neovim.nix`. |

### File 6 — `docs/gnome-settings.md` (backlog finding 5 — backlog listed 5 of 9 actual hits)

Verified via `grep -n "configuration\.nix\|home\.nix" docs/gnome-settings.md` (full file read for
context). The backlog named lines 3, 59, 60, 70, 75; the live file has **4 additional** hits at
lines 73, 86, 106, 128 that belong to the same stale-pointer category and should be fixed in the
same pass since Group A's rationale ("bundling lets a single pass re-verify ground truth and apply
the same correction once") applies directly here.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 3 | "GNOME desktop settings are managed declaratively through Home Manager's `dconf.settings` module in `home.nix`." | STALE | `dconf.settings` lives in `modules/home/desktop/gnome.nix` (confirmed line 5: `dconf.settings = {`). Reword to "...in `modules/home/desktop/gnome.nix`." |
| 59 | "Enabled declaratively in `home.nix` via `enabled-extensions`..." | STALE | Repoint to `modules/home/desktop/gnome.nix` (confirmed `enabled-extensions` at that file's line 8). |
| 60 | "Extension settings also managed in `home.nix` under `org/gnome/shell/extensions/unite`" | STALE | Repoint to `modules/home/desktop/gnome.nix`. |
| 70 | "**Managed settings** (defined in `home.nix`):" | STALE | Repoint to `modules/home/desktop/gnome.nix`. |
| 73 | "Source of truth is `home.nix`" | STALE (not in backlog's list — additional) | Repoint to `modules/home/desktop/gnome.nix`. |
| 75 | "**Unmanaged settings** (not in `home.nix`):" | STALE | Repoint to `modules/home/desktop/gnome.nix`. |
| 86 | "\| Edit \`home.nix\` + rebuild \| Yes \| Yes \|" (table row) | STALE (not in backlog's list — additional) | Change cell text to "Edit `modules/home/desktop/gnome.nix` + rebuild". |
| 106 | "3. Add to `home.nix`:" (followed by a `dconf.settings = { ... }` code example) | STALE (not in backlog's list — additional) | Change to "3. Add to `modules/home/desktop/gnome.nix`:". |
| 128 | "4. Add to `home.nix` to make permanent" | STALE (not in backlog's list — additional) | Change to "4. Add to `modules/home/desktop/gnome.nix` to make permanent". |

### File 7 — `docs/discord-bot.md` (backlog finding 6 — backlog listed 2 of 7 actual hits)

Verified via `grep -n "configuration\.nix\|home\.nix" docs/discord-bot.md` plus context read at
each hit. The backlog named lines 167 and 233; the live file has **5 additional** hits at lines
176, 328, 329, 330, and 367. All seven describe content that has moved: `sops.secrets` and the
`sops` config block live in `modules/system/optional/discord-bot.nix` (confirmed lines 70-71,
101-104 for `sops.secrets` usage; line 1 header confirms this file *is* "Discord bot
infrastructure — sops secrets, opencode-serve, and discord-bot systemd services"), and the
`programs.fish.interactiveShellInit` block with `DISCORD_BOT_LINK_TOKEN` lives in
`modules/system/shell.nix` (confirmed line 13), not `configuration.nix`.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 167 | "...is **not** declared in `sops.secrets` in `configuration.nix`. ... add it to `sops.secrets` + `LoadCredential`." | STALE | `sops.secrets` is declared in `modules/system/optional/discord-bot.nix` (confirmed lines 70-71, 101-104). Repoint. |
| 176 | "### sops-nix NixOS Configuration\n\nIn `configuration.nix`:" (heading directly above a `sops = { defaultSopsFile = ...; age.sshKeyPaths = [...]; ...}` code block) | STALE | This code block's actual content lives in `modules/system/optional/discord-bot.nix`. Repoint "In `configuration.nix`:" to "In `modules/system/optional/discord-bot.nix`:". |
| 233 | "- Add a corresponding entry in `sops.secrets` in `configuration.nix`" | STALE | Same as line 167 — repoint to `modules/system/optional/discord-bot.nix`. |
| 328 | "# 2. Remove opencodeDiscordBot binding (and packages/opencode-discord-bot.nix) from configuration.nix" (Rollback bash-comment script) | STALE | `opencodeDiscordBot` binding is declared in `modules/system/optional/discord-bot.nix:14` (confirmed: `opencodeDiscordBot = pkgs.python3Packages.callPackage ../../../packages/opencode-discord-bot.nix { };`), not `configuration.nix`. Repoint comment. |
| 329 | "# 3. Remove sops config block from configuration.nix" | STALE | Same file, repoint to `modules/system/optional/discord-bot.nix`. |
| 330 | "# 4. Remove both systemd services from configuration.nix" | STALE | Same file — the two systemd services (`opencodeServe`/`discord-bot`, confirmed in `modules/system/optional/discord-bot.nix`) are declared there. Repoint. Also note the rollback script's step 1 ("Remove sops-nix flake input ... and all 4 host module imports") should be double-checked during implementation — currently only `hosts/nandi/default.nix` imports `modules/system/optional/discord-bot.nix` (confirmed: `grep -rln "discord-bot" hosts/*/default.nix` returns only `hosts/nandi/default.nix`), so "all 4 host module imports" may itself be stale/inaccurate and worth a quick sanity check against `flake.nix`'s `sops-nix.nixosModules.sops` wiring (line 126) before editing — this report only confirms the `configuration.nix` mis-pointer, not the "4 hosts" count, since that count is outside Group A's stated scope. |
| 367 | "# In programs.fish.interactiveShellInit (configuration.nix):" | STALE | Confirmed: `DISCORD_BOT_LINK_TOKEN` fish-init block lives in `modules/system/shell.nix:13`, not `configuration.nix`. Repoint. |

### File 8 — `docs/installation.md` (backlog finding 7)

Verified via `grep -n "configuration\.nix\|home\.nix" docs/installation.md` plus context read
(lines 60-80).

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 72 | "4. Reference host-specific settings in `configuration.nix`" (step in a "To add a new host" list, after "3. Update `flake.nix` to include the new host") | STALE | Per `.claude/rules/nix.md`'s always-on vs. optional/host-toggled convention: always-on settings belong in `modules/system/*.nix`; host-specific overrides belong in `hosts/<name>/default.nix` (the optional/host-toggled pattern nandi already demonstrates). Reword step 4 to name both, e.g. "Reference always-on settings in `modules/system/*.nix`; for host-specific overrides, add `hosts/<name>/default.nix` (see `hosts/nandi/default.nix` for the pattern)." |

### File 9 — `docs/development.md` (backlog finding 7)

Verified via `grep -n "configuration\.nix\|home\.nix" docs/development.md` plus context read
(lines 40-60, 105-120). Note: this file has an additional `configuration.nix` mention at line 47
("System configuration from `configuration.nix`" in the ISO Contents bullet list) that the
backlog did not name — flagged below as borderline/likely-legitimate rather than definitely stale,
since it's describing what the ISO's build process includes at a high level rather than telling a
contributor where to edit something; recommend the plan re-confirm this one specifically rather
than assuming it needs the same fix as line 117.

| Line | Current text | Status | Corrected target |
|---|---|---|---|
| 47 | "- System configuration from `configuration.nix`" (bullet under "### ISO Contents") | BORDERLINE (not in backlog's list) | This describes the ISO build including "system configuration" generically; `configuration.nix` genuinely is what's imported at the top of the chain (it in turn imports `modules/system`). Could arguably stay as-is (it's describing the import chain's root, similar to README.md lines 102/182) or be expanded to "...(via `modules/system/*.nix`)" for precision. Recommend the plan treat this as optional/low-priority precision, not a required fix, given the ambiguity — distinct from line 117 below, which is unambiguous edit-target guidance. |
| 117 | "4. Reference host-specific settings in `configuration.nix`" (step in a "For adding new hosts" list, after "3. Update `flake.nix` to include the new host") | STALE | Identical pattern to `docs/installation.md:72` — same corrected wording: point at `modules/system/*.nix` for always-on settings, `hosts/<name>/default.nix` for host-specific overrides. |

## Decisions

- Treated the backlog (task 94 report 02, Group A) as authoritative for which files/categories are
  in scope, but re-verified every line number against the live tree rather than trusting the
  backlog's line numbers unchecked — two files (`docs/gnome-settings.md`, `docs/discord-bot.md`)
  had more matching hits than the backlog enumerated, and this report lists the complete current
  set for both so a single implementation pass can close the category fully.
- Explicitly identified legitimate (non-stale) `configuration.nix`/`home.nix` mentions (README.md
  lines 102/182, `hosts/README.md`, `modules/README.md`, `docs/configuration.md` itself,
  `docs/development.md:47` as borderline) so the implementation plan doesn't over-correct
  mechanism-accurate references into something incorrect.
- Did not attempt to fix the `wtype` Quick Reference row's replacement text myself (line 321) — the
  exact `ydotool` one-liner invocation should be verified against `modules/home/services/
  ydotool.nix`/`modules/home/scripts/whisper.nix` usage during implementation rather than guessed
  here, since a wrong command in a "Quick Reference" table would just replace one dead reference
  with a broken one.
- Flagged (but did not fix, and flagged as out-of-scope for Group A specifically) the rollback
  script's "4 host module imports" claim in `docs/discord-bot.md:322` context (line 328's
  surrounding comment) as a second, distinct possible staleness — only nandi currently imports the
  discord-bot module per `hosts/*/default.nix` grep. Recommend the plan owner decide whether to
  fix this in the same pass (same file, adjacent lines) or leave for a separate finding, since it's
  a factual-count question rather than a `configuration.nix`/`home.nix` pointer question.

## Risks & Mitigations

- All 9 files are doc-only edits with no build/runtime impact — no `nix flake check` or rebuild
  needed to verify, consistent with the backlog's own risk assessment.
- `docs/discord-bot.md` and `docs/gnome-settings.md` have more edits than the backlog named;
  implementing only the backlog's original line numbers would leave the category incompletely
  fixed in those two files — the plan should use this report's per-file tables, not the backlog's
  finding list, as the line-level source of truth.
- `docs/dictation.md` line 321's `wtype` replacement needs a verified working `ydotool` command,
  not a guessed one — check `modules/home/scripts/whisper.nix` for how `ydotool` is actually
  invoked in the real script before writing the Quick Reference row.
- Do not "fix" `hosts/README.md`, `modules/README.md`, `docs/configuration.md`, or README.md lines
  102/182 — these are accurate as-is; changing them would introduce new inaccuracy, not remove it.
- `docs/discord-bot.md:328`'s "4 host module imports" claim (adjacent to the `configuration.nix`
  fix at the same line) may itself be stale (only nandi currently imports the module) — this is
  flagged as a separate observation, not verified as in/out of Group A's scope; the plan owner
  should decide whether to bundle a fix or leave it.

## Appendix

### Search/verification commands used

```bash
grep -n "configuration\.nix\|home\.nix" README.md hosts/nandi/README.md hosts/garuda/README.md \
  docs/{neovim,gnome-settings,discord-bot,installation,development}.md
grep -n "configuration\.nix\|home\.nix\|openai-whisper\|wtype\|whisper-cpp" docs/dictation.md
grep -n "sops.secrets" modules/system/optional/discord-bot.nix
grep -n "dconf.settings\|enabled-extensions" modules/home/desktop/gnome.nix
grep -n "programs.neovim" modules/home/core/neovim.nix
grep -n "whisper-dictate\|whisper-download-models\|whisper-cpp" modules/home/scripts/whisper.nix
cat modules/home/packages/media-dictation.nix
wc -l home.nix configuration.nix modules/home/scripts/whisper.nix
grep -rn "wtype" --include="*.nix" .
grep -rn "openai-whisper" --include="*.nix" .
grep -rn "programs.fish.interactiveShellInit\|DISCORD_BOT_LINK_TOKEN" --include="*.nix" .
grep -rln "opencodeDiscordBot\|sops-nix\|sops =" --include="*.nix" .
grep -n "sops\b" flake.nix
grep -rn "discord-bot" hosts/*/default.nix flake.nix
grep -n "modules/system\|modules/home" docs/configuration.md docs/how-to-add-package.md \
  docs/how-to-add-service.md
cat hosts/README.md
```

### Files read in full or substantially

`README.md`, `hosts/{nandi,garuda}/README.md`, `hosts/README.md`, `docs/dictation.md` (in full),
`docs/neovim.md` (in full), `docs/gnome-settings.md` (in full), `docs/discord-bot.md` (relevant
sections), `docs/installation.md` (relevant sections), `docs/development.md` (relevant sections),
`docs/configuration.md` (relevant sections), `docs/how-to-add-{package,service}.md` (relevant
sections), `modules/README.md` (partial), `configuration.nix` (in full), `home.nix` (in full),
`modules/system/optional/discord-bot.nix` (partial), `modules/system/shell.nix` (partial),
`modules/home/desktop/gnome.nix` (partial), `modules/home/core/neovim.nix` (partial),
`modules/home/scripts/whisper.nix` (in full), `modules/home/packages/media-dictation.nix` (in
full), `modules/home/services/ydotool.nix` (partial), `flake.nix` (partial), `hosts/nandi/
default.nix` (partial).

### Cross-references

- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` — Group A,
  the authoritative source backlog this report grounds and re-verifies.
- `specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md` — round-1
  findings; established the fix pattern task 94 applied to `docs/configuration.md` and the
  `how-to-add-*.md` guides, which this report's corrected-target column mirrors throughout.
- `.claude/rules/nix.md` — source for the always-on vs. optional/host-toggled module convention
  used in the `hosts/{nandi,garuda}/README.md` and `docs/{installation,development}.md` fixes.

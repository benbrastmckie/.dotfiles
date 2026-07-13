# Research Report: Task #94 (Round 2) — Remaining Cleanup Backlog

**Task**: 94 - Systematically review the NixOS config to improve the documentation (and the
config) where relevant
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: Medium (investigation only; no files modified)
**Dependencies**: Builds on completed task 94 (Phases 1-7 landed; Phase 8 deferred)
**Sources/Inputs**:
- `specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md` (round-1
  findings, all 14 confirmed cross-checked here to avoid re-proposing fixed work)
- `specs/094_review_nixos_config_documentation/summaries/01_nixos-doc-config-improvements-summary.md`
  (what was actually implemented)
- `specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md`
  (Phase 8 deferred-item definitions)
- Codebase: `README.md`, `flake.nix`, `configuration.nix`, `home.nix`, `lib/mkHost.nix`,
  `modules/system/**`, `modules/home/**`, `hosts/**`, `overlays/**`, `packages/**`, `docs/**`,
  `.github/workflows/ci.yml`, `.gitignore`, `.claude/rules/nix.md`
**Artifacts**: This report —
`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 94 closed out the highest-risk staleness (architecture-status docs, package inventory,
  the nandi/hamsa CPU bug) but its own fix **did not reach every file that carries the same
  "configuration.nix/home.nix contain everything" framing**. Root `README.md`, both
  `hosts/{nandi,garuda}/README.md`, and six topic docs (`docs/dictation.md`, `docs/neovim.md`,
  `docs/gnome-settings.md`, `docs/discord-bot.md`, `docs/installation.md`, `docs/development.md`)
  still point contributors at `configuration.nix`/`home.nix` for settings that actually live in
  `modules/system/*.nix` / `modules/home/**/*.nix` — the exact contributor-misdirection problem
  task 94 fixed for `docs/configuration.md` and the `how-to-add-*.md` guides, just not fixed
  everywhere it appears. This is the single largest remaining item (Group A below).
- `docs/dictation.md` has its own, independent staleness beyond the file-location pattern: it
  references a renamed package (`openai-whisper-cpp` → `whisper-cpp`, confirmed via an inline
  rename-comment in `modules/home/packages/media-dictation.nix`), a broken line reference
  (`home.nix:183-264` — `home.nix` is 22 lines total), and `wtype` usage/docs that contradict the
  file's own explanation that GNOME doesn't support the protocol `wtype` needs (the actual
  mechanism, confirmed by `grep`, is `ydotool` only — zero `wtype` hits in any `.nix` file).
- `hosts/hamsa/README.md` does not exist, while `hosts/nandi/README.md` and
  `hosts/garuda/README.md` do — `hosts/README.md` itself documents this asymmetry ("Present on
  `garuda/` and `nandi/`"). Hamsa is confirmed (task 94's summary) to be the user's actual
  AMD Ryzen AI 9 HX 300 daily machine, making this a real, easy-to-close documentation gap.
- 9 of 13 `packages/*.nix` files have no header comment describing purpose (100% of
  `modules/system/*.nix` and `modules/home/**/*.nix` files do have one) — an inconsistent
  documentation convention, easy to close.
- One confirmed internal contradiction in `flake.nix` itself: line 33's comment says "MCPHub is
  loaded via lazy.nvim, not as a flake input" while line 62's comment says "MCPHub is now handled
  via official flake input instead of custom overlay" — these two comments describe mutually
  exclusive states of the same thing, and only line 33 matches current reality (confirmed:
  `programs.neovim`/`lazy.nvim` load MCPHub; there is no MCPHub flake input or overlay). Line 62
  is dead/stale and should be removed or corrected.
- `modules/system/packages.nix` (226 lines) inlines three custom `writeShellScriptBin` wrapper
  derivations (`zathura`, `sioyek`, `polkit-gnome-authentication-agent-1`) directly in the package
  list, inconsistent with the repo's own convention of putting custom derivations in
  `packages/*.nix` (13 files already follow that convention, including comparably-sized wrapper
  scripts like `packages/aristotle.nix`, `packages/loogle.nix`, `packages/slidev.nix`).
- No Nix formatter (`nixfmt`/`alejandra`/`nixpkgs-fmt`) or lint tool (`statix`/`deadnix`) is
  configured anywhere in the repo — no `formatter` flake output, no devShell, no pre-commit hook,
  and `.github/workflows/ci.yml` runs only `nix flake check` (evaluation, not formatting/lint).
  This is a real tooling gap but an opinionated one — **flagged as needing user confirmation**
  before adding, since it changes the contributor-facing bar (what a "clean" diff looks like).
- **Verified clean, no action needed**: (a) a full `.nix`-file sweep for `TODO`/`FIXME`/`XXX`
  scratch-tags found zero — every `NOTE:` hit is a legitimate rationale comment matching
  `docs/README.md`'s approved convention; (b) a repo-wide emoji scan found **no new drift** beyond
  the two files task 94 already identified and deferred (`docs/niri.md`,
  `docs/ryzen-ai-300-{compatibility,support-summary}.md`) — all other emoji-range hits are the
  intentional `→`/`←`/`↓` navigation arrows task 94's own report explicitly excluded; (c) the
  repo's pervasive scoped `with pkgs; [ ... ]` / `with lib; { ... }` usage (17 occurrences) is
  idiomatic nixpkgs style, not a violation of `.claude/rules/nix.md`'s "no top-level `with pkgs;`"
  rule — none of the occurrences wrap an entire file, so **no code change is warranted** (noted
  under Risks so a future pass doesn't misread the rule and "fix" idiomatic code).
- Task 94's three explicitly deferred Phase 8 items remain outstanding and are carried forward
  unchanged here: Ryzen doc consolidation, `docs/niri.md` usage-phase re-confirmation (both need
  user judgment), and a dedicated `docs/niri.md` emoji-strip task (mechanical, ~58 glyphs/1035
  lines).

## Context & Scope

This is a follow-up investigation to task 94, explicitly scoped to find **new** refactoring,
documentation, and polish opportunities beyond what task 94 already fixed or already recorded as
deferred. Research-only, no files modified. Covered: `flake.nix`, `lib/mkHost.nix`,
`configuration.nix`, `home.nix`, all of `modules/system/*.nix` (12 files) and `modules/home/**/*.nix`
(~34 files), all of `hosts/**` (hardware configs, `default.nix` host modules, per-host READMEs),
`overlays/*.nix` (3 files), `packages/*.nix` (13 files), all of `docs/*.md` (24 files), root
`README.md`, `.github/workflows/ci.yml`, `.gitignore`, and cross-checked against
`.claude/rules/nix.md`'s stated conventions (module patterns, formatting "Do Not" list).

Every finding below was independently re-verified against the current tree (per
`docs/README.md`'s own "Docs verified against source, not fixed once" convention) rather than
assumed from task 94's report — findings 1-14 in report 01 are treated as closed and are not
re-listed here except where explicitly noted as still-open (Phase 8 carry-forwards).

## Findings

### Group A — Complete the post-reorg documentation sweep (HIGH priority, doc)

Task 94 fixed the "configuration.nix/home.nix contain everything" staleness in
`docs/configuration.md`, `docs/unstable-packages.md`, `docs/how-to-add-package.md`, and
`docs/how-to-add-service.md`. The same pattern is still present, unfixed, in files task 94 did not
touch:

1. **Root `README.md`** — four separate spots still describe the pre-reorg layout as current:
   - Lines 9-10 (Overview): "System Configuration: NixOS system-wide settings via
     `configuration.nix`" / "User Environment: Home Manager configuration in `home.nix`".
   - Lines 19-20 (Core Configuration Files): `configuration.nix`/`home.nix` described with no
     mention that they are 19/20-line import shims.
   - Lines 27-29 (Module Map ASCII tree inline comments): `configuration.nix # System NixOS
     config (boot, hardware, services, packages)` and `home.nix # User Home Manager config (apps,
     dotfiles, user services)` — describes content that actually lives in `modules/system/*.nix`
     / `modules/home/**/*.nix`.
   - Lines 125-127 (Customization section): "System changes: Edit `configuration.nix`" / "User
     environment: Edit `home.nix`" — this is the most actively misleading of the four: it directly
     contradicts the now-corrected `docs/how-to-add-package.md`/`docs/how-to-add-service.md`
     guidance to edit `modules/system/*.nix` / `modules/home/**/*.nix`.
   - Fix: doc-only. Rewrite these four spots to name `modules/system/` + `modules/home/` as the
     primary edit targets, mirroring `modules/README.md` and the corrected `docs/configuration.md`.

2. **`hosts/nandi/README.md:29`** and **`hosts/garuda/README.md:25`** — identical stale sentence:
   "System-specific changes should be made in the main `configuration.nix` file." Same pattern as
   finding 1; should point at `modules/system/*.nix` (and, for host-specific overrides, at
   `hosts/<name>/default.nix` per the optional/host-toggled convention).

3. **`docs/dictation.md`** — three independent staleness issues (not just file-location):
   - Line 18: "The dictation tools are already configured in `home.nix`" — actually
     `modules/home/scripts/whisper.nix` (the `whisper-dictate`/`whisper-download-models` scripts),
     `modules/home/services/ydotool.nix` (the daemon), and
     `modules/home/packages/media-dictation.nix` (the `whisper-cpp` package).
   - Line 20: `openai-whisper-cpp` — confirmed renamed to `whisper-cpp` (rename recorded inline in
     `modules/home/packages/media-dictation.nix:9`: "whisper-cpp # ... (renamed from
     openai-whisper-cpp)"). Zero `openai-whisper-cpp` hits remain in any `.nix` file.
   - Line 271: "The script is defined in `home.nix` (home.nix:183-264)." — `home.nix` is 22 lines
     total; this line range cannot exist there. Should point at
     `modules/home/scripts/whisper.nix`.
   - "Resources" (line 311) and the "Quick Reference" table (line 321) still reference `wtype`
     ("wtype Documentation", "echo text | wtype -"), but a `grep` for `wtype` across all `.nix`
     files returns **zero** hits — the actual, sole input mechanism is `ydotool`, and the doc's
     own line 163 explains *why* GNOME needs `ydotool` instead of `wtype`. The `wtype` references
     are dead and contradict the doc's own explanation.
   - Fix: doc-only. Update the "Installation" and "Customizing the Script" sections to name the
     three real module files; fix the package name; remove or replace the `wtype` references with
     the actual `ydotool` equivalent.

4. **`docs/neovim.md`** — lines 9 and 58: "`programs.neovim.enable = true` is kept in `home.nix`"
   and "[Neovim module in home.nix](../home.nix)" — confirmed via `grep` that `programs.neovim` is
   declared in `modules/home/core/neovim.nix`, not `home.nix`. Fix: doc-only, repoint both
   references (and the markdown link target) to `modules/home/core/neovim.nix`.

5. **`docs/gnome-settings.md`** — four references (lines 3, 59, 60, 70, 75) to `dconf.settings`/
   `enabled-extensions` being "in `home.nix`" — confirmed via `grep` that GNOME dconf settings live
   in `modules/home/desktop/gnome.nix`. Fix: doc-only, repoint all references.

6. **`docs/discord-bot.md`** — lines 167 and 233: references to `sops.secrets` living "in
   `configuration.nix`" — confirmed via `grep` that `sops.secrets` is declared in
   `modules/system/optional/discord-bot.nix` (the optional/host-toggled module itself, not the
   thin `configuration.nix` shim). Fix: doc-only, repoint both references.

7. **`docs/installation.md:72`** and **`docs/development.md:117`** — both say "Reference
   host-specific settings in `configuration.nix`" as generic advice. Should point at
   `modules/system/*.nix` for always-on settings or `hosts/<name>/default.nix` for host-specific
   overrides (per `.claude/rules/nix.md`'s always-on vs. optional/host-toggled distinction).

**Grouping rationale**: all seven items are the same finding category (stale post-reorg file
pointers) task 94 already established a fix pattern for; bundling them into one task lets a single
pass re-verify ground truth once and apply the same correction style everywhere, rather than
re-deriving the pattern per file. Items 3-4 additionally carry small independent facts (package
rename, `wtype` dead reference) that should be fixed in the same pass since they're in the same
file/section already being touched.

- **Effort**: Medium (9 files, all doc-only, each a small number of line-level edits; no config
  changes, no `nix flake check` needed).
- **Priority**: High (directly misdirects contributors, same severity class as task 94's own
  headline findings).

### Group B — Documentation completeness gaps (MEDIUM priority, doc)

8. **`hosts/hamsa/README.md` does not exist.** `hosts/README.md`'s own "Structure" section
   documents this asymmetry: "`README.md` - Per-host notes on hardware details and building.
   Present on `garuda/` and `nandi/`." Hamsa is confirmed (task 94 summary) to be the user's actual
   AMD Ryzen AI 9 HX 370 (Ryzen AI 300 series) daily machine — the most-used host, yet the only one
   without hardware notes. Fix: add `hosts/hamsa/README.md` mirroring the `nandi`/`garuda` format
   (Hardware Details: AMD Ryzen AI 9 HX 370, `kvm-amd`, MediaTek WiFi firmware note already present
   in `hosts/hamsa/hardware-configuration.nix`'s own comment — reuse that as ground truth); update
   `hosts/README.md`'s "Structure" bullet to add `hamsa/` once created. **Do not** copy the stale
   "changes should be made in `configuration.nix`" sentence from nandi/garuda's README — use the
   Group A-corrected wording instead (natural to sequence this after or alongside Group A).

9. **9 of 13 `packages/*.nix` files lack a header comment**: `aristotle.nix`, `kooha.nix`,
   `loogle.nix`, `piper-voices.nix`, `pymupdf4llm.nix`, `python-cvc5.nix`, `python-vosk.nix`,
   `slidev.nix`, `vosk-models.nix`. By contrast, 100% of `modules/system/*.nix` and
   `modules/home/**/*.nix` files carry a 1-3 line header, and `packages/piper-bin.nix` and
   `packages/claude-code.nix` already demonstrate the desired style for this directory. Fix: add a
   1-3 line header comment per file (what it builds/wraps and why it's a custom derivation rather
   than a plain nixpkgs package), matching `piper-bin.nix`'s style. Low-risk, additive-only.

- **Effort**: Small (one new file + 9 one-line header additions).
- **Priority**: Medium (real gap, not misleading like Group A — just incomplete).

### Group C — Small refactor / dead-comment cleanup (LOW-MEDIUM priority, refactor)

10. **`modules/system/packages.nix` inlines three custom wrapper derivations** (`zathura` override
    at the file's end, `sioyek` override, and `polkit-gnome-authentication-agent-1`, all
    `writeShellScriptBin` blocks embedded directly in the `environment.systemPackages` list) —
    inconsistent with the repo's established convention (13 files in `packages/*.nix`) of giving
    each custom derivation its own file, callPackage'd from an overlay or referenced directly.
    Fix: extract the three wrappers into `packages/zathura-x11.nix`, `packages/sioyek-wayland.nix`
    (or similar names), and `packages/polkit-gnome-agent-wrapper.nix`; import them in
    `modules/system/packages.nix` the same way other custom packages are referenced. Verify with
    `nix flake check` after moving (no functional change, just an extraction).
    - **Effort**: Medium (touches a live, always-on module; must preserve exact behavior).
    - **Priority**: Low-medium (cosmetic/organizational consistency, not a bug).

11. **`flake.nix` contains a contradictory comment pair** about MCPHub: line 33 ("MCPHub is loaded
    via lazy.nvim, not as a flake input") vs. line 62 ("MCPHub is now handled via official flake
    input instead of custom overlay"). Confirmed via `grep` (zero MCPHub flake input or overlay
    exists; `modules/home/core/neovim.nix:25` confirms "MCP-Hub is managed via lazy.nvim") that
    line 33 is accurate and line 62 is stale/dead — likely left over from an intermediate state
    (custom overlay → flake input → lazy.nvim) where only the first and last comments were kept in
    sync. Fix: delete or correct line 62's comment. One-line, comment-only.
    - **Effort**: Small.
    - **Priority**: Low (comment-only, no functional confusion risk to a human reading the actual
      code, but a stale comment is exactly the kind of thing that misleads the next investigation
      pass).

12. **(Optional, judgment call — do not implement without explicit user interest)**: systemd
    user-service boilerplate (`Unit`/`Service`/`Install` blocks) is repeated with only small
    variations across `modules/home/services/{ydotool,cache-cleanup,screenshot}.nix` and
    `modules/home/memory/services.nix` (4-5 files). A shared `lib/mkUserService.nix` helper is
    possible, but the services differ enough (`Type = "simple"` vs `"oneshot"`, different `After`/
    `Requires` deps, one has an attached `systemd.user.timers` block) that an abstraction may cost
    more clarity than it saves for a personal dotfiles repo of this size. **Recommendation: do not
    do this unless the user specifically wants it** — flagged here only so it's recorded as
    considered-and-declined rather than undiscovered.

### Group D — Nix formatter / lint tooling gap (MEDIUM priority, polish — needs user confirmation)

13. **No Nix formatter or lint tool is configured anywhere in the repo.** Confirmed via search:
    zero references to `nixfmt`/`alejandra`/`nixpkgs-fmt`/`statix`/`deadnix`/`treefmt` in any
    `.nix`, `.yml`, or `.md` file; `flake.nix` has no `formatter` output and no `devShells` output;
    `.github/workflows/ci.yml` runs only `nix flake check` (evaluation correctness, not style);
    `.git/hooks/` has no active hooks. Root `README.md`'s own "Optional: local flake-check hook"
    section only offers an opt-in `nix flake check` pre-push hook, not a format check. This means
    formatting drift (spacing, alignment, `.claude/rules/nix.md`'s own 2-space/100-char/layout
    rules) has no automated enforcement — currently relying entirely on manual review.
    - Fix (if wanted): add a `formatter = pkgs.nixfmt-rfc-style;` (or `alejandra`) output to
      `flake.nix` (enables `nix fmt`), optionally add a `nix fmt -- --check` step to
      `.github/workflows/ci.yml`, and optionally add `statix` as a `devShells.default` tool for
      local linting.
    - **This is flagged as needing explicit user confirmation** rather than being auto-added: it's
      an opinionated tooling choice (which formatter, whether to gate CI on it, whether a
      repo-wide reformat commit should run once first) rather than a pure correctness fix, and a
      first-time repo-wide format pass would touch many files at once — a decision the user should
      make deliberately, not have made for them.
    - **Effort**: Medium (tooling addition + first-time reformat pass if adopted).
    - **Priority**: Medium (real gap, but the repo is not currently suffering from format drift
      that's causing problems — this is preventive, not remedial).

### Group E — Deferred from task 94 (carry-forward, needs user confirmation)

These three items were explicitly recorded in task 94's plan (Phase 8) and summary as
requiring user judgment before any action, and remain untouched (confirmed via `git status`/`git
log` — none of the three files below have been modified since task 94's Phase 1-7 work landed):

14. **Ryzen doc consolidation**: `docs/ryzen-ai-300-compatibility.md` (210 lines) and
    `docs/ryzen-ai-300-support-summary.md` (120 lines) remain near-duplicate content (same
    headings: "Fully Supported", "Ryzen AI Specific Features", "Installation Process", "Expected
    Performance", "Conclusion"). `support-summary.md` still reads as a session recap of
    `compatibility.md`'s content. **Confirm with user first** — may be an intentional
    executive-summary variant.

15. **`docs/niri.md`'s "Recommended Usage Strategy"** (lines ~95-112) still frames GNOME+PaperWM
    as the daily driver and niri as "Phase 1: Current - Testing (You are here!)" — still
    contradicted by `flake.nix`/`overlays/unstable-packages.nix`'s "ENABLED (dual-session with
    GNOME)" language (settled, not experimental). **Confirm with user** — only they know current
    actual daily-driver usage.

- **Priority**: High-value if confirmed (removes real staleness) but **blocked on user input**,
  not on further investigation — no new information would change the recommendation to ask first.

### Group F — Deferred from task 94, mechanical (LOW-MEDIUM priority, polish)

16. **`docs/niri.md` emoji strip**: ~58 glyphs across 1035 lines (39 x ✅, 25 x ⭐, 7 x ❌, 6 x ⚠,
    2 x 📝, 2 x ⚙, 2 x ↔, 1 x 🖱, 1 x 🔄, 1 x ↓ — confirmed via the same scan command task 94's
    report used, restricted to this file). Task 94 explicitly deferred this to its own follow-up
    task rather than bundling with the smaller emoji sweep (its own stated reason: a 1035-line file
    is large enough to risk an error-prone bulk edit, and it should not be bundled with finding 15's
    judgment-call item so a mechanical fix isn't blocked on a judgment call). No new emoji drift was
    found anywhere else in the repo (see Executive Summary) — this is the only remaining emoji
    cleanup item.
    - **Effort**: Medium (mechanical but large file; needs careful glyph-only removal preserving
      headings/arrows, same discipline task 94 already demonstrated on 11 smaller files).
    - **Priority**: Low-medium (cosmetic, no misdirection risk, but closes out a fully-decided
      rule with no open questions — unlike Group E, this can proceed without user confirmation).

## Decisions

- Treated all 14 findings in report 01 as closed and did not re-verify or re-propose them; spent
  the investigation budget entirely on files/areas report 01 did not cover (root `README.md`,
  `hosts/*/README.md`, topic docs beyond the four task 94 touched, `packages/*.nix` headers,
  formatter/lint tooling, `flake.nix`'s MCPHub comments).
- Did not flag the repo's pervasive scoped `with pkgs;`/`with lib;` usage as a rule violation.
  `.claude/rules/nix.md`'s "Do Not: Use top-level `with pkgs;`" rule is about whole-file `with`
  blocks (the historical static-analysis/shadowing problem); none of the 17 occurrences found wrap
  an entire file — all are scoped to a single package list or `meta` attrset, which is standard
  nixpkgs idiom. No code change proposed; noted under Risks so a future pass doesn't misread the
  rule text and "fix" idiomatic code into something worse.
- Chose not to recommend the systemd-user-service boilerplate extraction (finding 12) as an
  actionable task — recorded as considered-and-declined rather than omitted, per the instruction
  to call out things that should not be changed without more explicit signal.
- Grouped Group A's seven files into a single task rather than one-per-file: all seven are the
  identical finding category with an already-established fix pattern from task 94; splitting them
  would multiply coordination overhead without changing the actual work.
- Kept Group E (judgment-call, needs user confirmation) and Group F (mechanical, no confirmation
  needed) separate, preserving task 94's own explicit reasoning for that split rather than
  re-merging them now that both are "old."

## Risks & Mitigations

- **Do not** touch `modules/home/services/gmail-oauth2.nix` — still the gold-standard
  deliberately-disabled-service reference (task 94's finding, unchanged).
- **Do not** touch `flake.lock`, either `stateVersion`, or re-litigate the transitive-nixpkgs-pin
  question — all explicitly recorded as "checked, no action needed" in `modules/README.md`.
- **Do not** treat the widespread scoped `with pkgs;`/`with lib;` usage as something to "fix" —
  see Decisions above. A future pass that greps `.claude/rules/nix.md`'s "Do Not" list literally
  against this repo could misidentify these 17 occurrences as violations; they are not.
- **Group E items need explicit user confirmation before any file is touched** — same rationale
  task 94 already established (possible intentional executive-summary doc; actual daily-driver
  usage is only knowable from the user, not from the config tree).
- **Group C finding 10** (extracting inline package wrappers) changes a live, always-on,
  currently-working module (`modules/system/packages.nix`) — must be verified with
  `nix flake check` (and ideally a `nixos-rebuild build --flake .#hamsa` dry-build) after the
  extraction, not just visually reviewed, since a subtly wrong `callPackage` wiring would silently
  break `zathura`/`sioyek`/the polkit agent without a flake-check-visible error in some cases.
- **Group D (formatter/lint)** is the one item in this backlog that changes contributor-facing
  tooling/CI behavior rather than fixing an existing inaccuracy — treat as opt-in, present the
  choice, do not auto-adopt a specific formatter.
- All Group A, B, and F fixes are doc-only (or, for Group B's `hosts/hamsa/README.md`, a new
  additive file) with no build/runtime impact — safe to implement without a
  `nixos-rebuild`/`home-manager switch` cycle. Group C and D are the only groups touching live
  `.nix`/CI files and are the only ones needing a `nix flake check` (and, for Group C finding 10,
  ideally a build) as part of verification.

## Appendix

### Search/verification commands used

```bash
find . -maxdepth 3 -not -path './.git*'
wc -l modules/system/*.nix modules/system/optional/*.nix
find modules/home -name '*.nix' | xargs wc -l
wc -l docs/*.md
find hosts -maxdepth 2
diff hosts/nandi/hardware-configuration.nix hosts/{hamsa,garuda,usb-installer}/hardware-configuration.nix
cat .github/workflows/ci.yml
grep -rn "formatter\|nixpkgs-fmt\|alejandra\|nixfmt\|statix\|deadnix\|treefmt" flake.nix . --include="*.nix" --include="*.yml" --include="*.md"
grep -rn "TODO\|FIXME\|FIX:\|NOTE:\|QUESTION:\|XXX" --include="*.nix" .
grep -oP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2190}-\x{21FF}\x{2B00}-\x{2BFF}]' docs/*.md README.md hosts/*/README.md ... | sort | uniq -c
grep -rn "planned\|pending\|Phase [0-9]\|TODO\|stub" docs/*.md README.md hosts/*/README.md ...
grep -rn "in \`home.nix\`|in home.nix|in \`configuration.nix\`|(home.nix:|(configuration.nix:" docs/*.md README.md hosts/*/README.md
grep -rn "programs.neovim\|sops.secrets\|dconf.settings\|enabled-extensions" --include="*.nix" .
grep -rn "whisper-cpp\|openai-whisper\|wtype" --include="*.nix" .
grep -rn "MCPHub\|MCP-Hub\|MCP Hub" --include="*.nix" --include="*.md" .
grep -rn "with pkgs;\|with pkgs-unstable;\|with lib;" --include="*.nix" .
grep -rln "^rec |= rec {" --include="*.nix" .
for f in packages/*.nix; do head -1 "$f"; done   # header-comment presence check
git log -1 --format="%ai %s" -- <file>            # staleness-by-recency spot checks
```

### Files read in full or substantially

`README.md`, `flake.nix`, `configuration.nix`, `home.nix`, `hosts/README.md`,
`hosts/{nandi,garuda}/README.md`, `hosts/{nandi,usb-installer,iso}/default.nix`,
`hosts/{nandi,hamsa,garuda,usb-installer}/hardware-configuration.nix`, `docs/README.md`,
`docs/dictation.md` (in full), `modules/system/{packages,desktop}.nix` (in full),
`modules/system/default.nix`, `modules/home/default.nix`,
`modules/home/desktop/{kanshi,swaylock}.nix`, `modules/home/memory/services.nix`,
`modules/home/services/{ydotool,cache-cleanup,screenshot}.nix`,
`modules/home/scripts/{whisper,gmail-oauth2}.nix`, `overlays/{claude-squad,unstable-packages,
python-packages}.nix`, `packages/{piper-bin,piper-voices,vosk-models,aristotle,claude-code,
kooha,loogle,pymupdf4llm,python-cvc5,python-vosk,slidev}.nix` (headers), `.github/workflows/ci.yml`,
`.gitignore`, `.claude/rules/nix.md`.

### Cross-references

- `specs/094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md` — round-1
  findings (all 14 confirmed closed except the three Phase 8 deferrals carried forward as Groups
  E/F here).
- `specs/094_review_nixos_config_documentation/summaries/01_nixos-doc-config-improvements-summary.md`
  — ground truth for what task 94 actually changed (used to avoid re-proposing fixed work).
- `.claude/rules/nix.md` — source for the always-on vs. optional/host-toggled module convention
  (Group A finding 7) and the "no top-level `with pkgs;`" rule (see Decisions/Risks re: why the
  repo's scoped usage is not a violation).

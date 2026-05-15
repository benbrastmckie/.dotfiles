# Research Report: Documentation Refactor Analysis

- **Task**: 51 - documentation_refactor_integrate_adhoc_notes
- **Started**: 2026-05-14T00:00:00Z
- **Completed**: 2026-05-14T00:00:00Z
- **Effort**: 2 hours
- **Dependencies**: None (task 51 subsumes prior ad-hoc documentation)
- **Sources/Inputs**:
  - Codebase: `home.nix`, `configuration.nix`, `hosts/hamsa/hardware-configuration.nix`
  - Documentation: `NOTES.md`, `docs/README.md`, `README.md`, all files in `docs/`
  - Standards: `.opencode/context/standards/documentation-standards.md`
- **Artifacts**:
  - `specs/051_documentation_refactor_integrate_adhoc_notes/reports/01_documentation-analysis.md`
- **Standards**: report-format.md, documentation-standards.md

## Executive Summary

- NOTES.md is a 141-line catch-all with six sections; the Neovim/sideloadInitLua section
  (lines 94-121) is the most substantive, but overlaps with home.nix inline comments and
  is not cross-referenced from docs/README.md.
- The inline comment at `home.nix:30-35` explains sideloadInitLua in 4 lines --
  appropriate length for inline documentation and a good model for the "why briefly"
  principle.
- docs/ has 18 files organized by domain, but `docs/neovim.md` is missing entirely.
  Neovim content is scattered across NOTES.md, home.nix inline comments, README.md,
  and docs/development.md.
- No established convention exists for cross-referencing inline comments to docs/.
  The single `see docs/wifi.md` comment in `hardware-configuration.nix` is the only
  example of its kind in the codebase.
- NOTES.md duplicates content from `docs/development.md` (first build, ISO build, niri
  logs) and `docs/niri.md` (niri section), making it both redundant and a maintenance
  liability.
- The recommended approach: migrate Neovim content to a new `docs/neovim.md`, dissolve
  NOTES.md content into appropriate docs/ files, establish a `see docs/X.md` cross-reference
  convention for inline comments, and add `docs/neovim.md` to docs/README.md.

## Context & Scope

This research analyzes the current state of documentation in the dotfiles repository
to inform a refactor that:

1. Evaluates and cleans up the sideloadInitLua documentation (created in May 2026)
2. Integrates it properly into docs/ and relevant README files
3. Uses this specific case to establish patterns for documenting NixOS config decisions,
   gotchas, and fixes repo-wide

The refactor scope is limited to markdown documentation, inline nix comments, and
cross-references between them. It does not include `.opencode/` system documentation
or `specs/` task artifacts.

## Findings

### Current State of sideloadInitLua Documentation

The fix is documented in two places:

**home.nix (lines 24-45)**:
```nix
programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    withRuby = false;
    withPython3 = false;

    # By default, programs.neovim writes provider config (python3_host_prog,
    # ruby_host_prog, etc.) to ~/.config/nvim/init.lua as a Home Manager-managed
    # symlink, overwriting any user-managed init.lua. sideloadInitLua = true
    # routes that same config through --cmd wrapper args on the neovim binary
    # instead, leaving ~/.config/nvim/ entirely unmanaged by Home Manager.
    sideloadInitLua = true;

    # jsregexp is required by LuaSnip and must be on neovim's runtime path.
    # Keeping it here (rather than home.packages) scopes it to neovim only.
    extraPackages = [
      pkgs.luajitPackages.jsregexp
    ];

    # Note: MCP-Hub is managed via lazy.nvim in NeoVim config
  };
```

The sideloadInitLua comment (4 lines) explains why the option exists (home-manager
behavior change), what it does (routes config through --cmd args), and what the
outcome is (leaves ~/.config/nvim/ unmanaged). It is well-written for its purpose:
concise, present-tense, and actionable. The only improvement would be adding a
cross-reference to docs/.

**NOTES.md (lines 94-121)**:
The "Neovim" section contains two subsections:
- "Why programs.neovim.enable = true is kept" (lines 96-105): explains provider
  wrapping and extraPackages
- "Why sideloadInitLua = true is required" (lines 107-121): explains the home-manager
  default behavior change, what sideloadInitLua does, and the consequences without it

The NOTES.md version is more verbose (28 lines total) and duplicates the inline
explanation. It adds value in one area: documenting why `programs.neovim.enable`
is kept at all (provider wrapping + extraPackages), which the inline comments only
hint at. Its main problems are discoverability (not linked from docs/README.md) and
redundancy.

### NOTES.md Analysis

NOTES.md (141 lines) contains six sections:

| Section | Lines | Content Type | Duplicated In |
|---------|-------|-------------|---------------|
| API | 3-5 | Environment var location | `docs/development.md` line 7 |
| Build ISO | 7-73 | Step-by-step build instructions | `docs/development.md` lines 11-16, 43-50; `docs/usb-installer.md` |
| First Build | 75-92 | Setup procedure | `docs/installation.md` lines 30-45; `docs/development.md` lines 52-82 |
| Neovim | 94-121 | Config rationale + gotcha | `home.nix` lines 30-44 |
| Niri | 123-128 | Log checking command | `docs/development.md` lines 84-93; `docs/niri.md` |
| Secrets Management | 130-141 | Quick reference + link | `docs/discord-bot.md` |

Key observations:
- Every section in NOTES.md duplicates or partially duplicates content in docs/
- NOTES.md is not referenced from docs/README.md or root README.md, making it
  invisible to users following the documented navigation paths
- It functions as a staging area where documentation was placed before docs/
  existed, but has not been maintained since docs/ matured
- The one unique value is the secrets-management quick-reference snippet
  (lines 135-138), which is genuinely useful as a brief pointer, but belongs in
  a docs/ file or README

### docs/ Directory Structure

| File | Lines | Purpose | Quality |
|------|-------|---------|---------|
| README.md | 54 | Documentation index + reading order | Good: organized, cross-referenced |
| applications.md | 131 | App configurations (discord, email, terminals, TTS/STT) | Good: well-organized by app |
| configuration.md | 147 | Core config: configuration.nix, flake.nix, home.nix, memory/WiFi | Good: detailed with tables |
| development.md | 192 | Dev notes: first build, ISO, niri, Lean dev | Mixed: catch-all, duplicates other files |
| dictation.md | 328 | Whisper dictation setup | Good: focused |
| discord-bot.md | 379 | Discord bot architecture and services | Excellent: detailed, diagrams |
| gnome-settings.md | 222 | GNOME desktop settings | Good: dconf-focused |
| himalaya.md | 723 | Email client configuration | Excellent: very detailed |
| installation.md | 78 | Setup and installation | Good: focused |
| niri.md | 1035 | Niri window manager | Excellent: comprehensive |
| packages.md | 247 | Package management | Good: covers overlays |
| terminal.md | 322 | Terminal emulator configs | Good: WezTerm and Kitty |
| testing.md | 154 | Testing procedures | Good: clear |
| unstable-packages.md | (exists) | Unstable channel management | Not reviewed in detail |
| usb-installer.md | (exists) | USB installer guide | Not reviewed in detail |
| wifi.md | 152 | WiFi configuration | Good: troubleshooting-focused |
| ryzen-ai-300-compatibility.md | (exists) | Hardware support | Not reviewed in detail |
| ryzen-ai-300-support-summary.md | (exists) | Hardware support summary | Not reviewed in detail |

Gaps identified:
- **Neovim**: No `docs/neovim.md` exists. Content is scattered across home.nix
  inline comments, NOTES.md, README.md ("Development Environment" mention), and
  docs/development.md.
- **Power management**: The sleep inhibitor for Claude/OpenCode interaction (task 52)
  is undocumented in docs/.
- **Activation scripts**: `home.nix` lines 1103-1106 reference activation scripts
  for rclone.conf and .claude settings but no docs/ file explains this pattern.

### Inline Comment Patterns in Nix Files

Survey of comment patterns across the nix codebase:

| Pattern | Frequency | Example |
|---------|-----------|---------|
| `# Note:` | 11 | `# Note: MCP-Hub is managed via lazy.nvim in NeoVim config` |
| `# NOTE:` | 3 | `# NOTE: rclone.conf is managed via activation script` |
| `# CRITICAL:` | 1 | `# CRITICAL: Required for mt7925e WiFi 6E/7 chip - see docs/wifi.md` |
| `# Why/explanation block` | 2 | `# By default, programs.neovim writes provider config...` |
| `# see docs/X.md` cross-ref | 1 | `# CRITICAL: ... - see docs/wifi.md` |
| `# TODO:` | 0 | None found |
| `# FIXME:` | 0 | None found |
| `# HACK:` | 0 | None found |

Inconsistencies:
- `Note` vs `NOTE` capitalization varies
- Most comments explain what/where, not why
- Only one cross-reference to docs/ exists (wifi)
- No established severity levels or tagging system
- The `programs.neovim` block comments are among the most thorough in the repo

### Cross-Reference Patterns

Current cross-referencing approaches:
- `docs/README.md` -> individual doc files (comprehensive)
- `README.md` -> `docs/README.md` + individual doc files
- `hardware-configuration.nix` -> `docs/wifi.md` (1 instance)
- `docs/applications.md` -> `docs/discord-bot.md`, `docs/himalaya.md`
- `docs/configuration.md` -> `docs/discord-bot.md`
- `docs/development.md` -> `docs/usb-installer.md`, other docs/ files
- `docs/niri.md` -> specs/reports (legacy references)

Missing cross-references:
- Nothing points from nix files to `docs/neovim.md` (does not exist)
- docs/README.md does not reference NOTES.md
- README.md does not reference NOTES.md
- No `docs/` file mentions activation script patterns

### Application of documentation-standards.md

The `.opencode/context/standards/documentation-standards.md` file defines standards
primarily for `.opencode/` context files but explicitly includes `docs/` in scope
(line 3). Key applicable rules:

- Content: document current state, use present tense, no historical references
- Formatting: max 100 chars/line, ATX headings, code blocks with language spec
- Prohibitions: no emojis, no "Quick Start" sections, no "Quick Reference" documents
  (except tables within authoritative documents)

Current compliance issues:
- `docs/niri.md` has "Quick Reference Card" section (lines 626-649) -- violates
  standalone quick-reference prohibition
- `docs/terminal.md` has "Quick Reference" section (lines 99-119) -- same issue
- Several docs/ files use emojis: `docs/wifi.md` (checkmark in header), `docs/niri.md`
  (checkmarks in comparison tables), `docs/README.md` (no emojis found), multiple
  others use emojis in status indicators and comparison tables

## Decisions

- **D1**: NOTES.md should be dissolved, not preserved. Every section duplicates
  content already in docs/. The "Secrets Management" quick-reference snippet is
  useful but belongs in a dedicated file or section.
- **D2**: A new `docs/neovim.md` should be created as the authoritative home for
  Neovim configuration documentation, including the sideloadInitLua gotcha.
- **D3**: The inline comment at `home.nix:30-35` should be kept but shortened
  slightly and given a `see docs/neovim.md` cross-reference.
- **D4**: The cross-reference convention should be a simple `# See docs/X.md.`
  trailer on inline comments, modeled after the existing WiFi example in
  `hardware-configuration.nix`.
- **D5**: A documentation convention section should be added to either
  `docs/README.md` or `docs/configuration.md` defining the pattern for inline
  comments and cross-references.

## Recommendations

### Priority 1: Create docs/neovim.md

Move the Neovim section from NOTES.md (lines 94-121) into a new `docs/neovim.md`,
expanding it to cover:

- Why `programs.neovim.enable = true` is kept (provider wrapping, extraPackages)
- The sideloadInitLua gotcha and fix (full context from NOTES.md)
- Relationship between home-manager neovim module and standalone config in `~/.config/nvim/`
- Package choice: `neovim-unwrapped` from unstable
- `extraPackages` rationale
- Reference to the separate nvim config repo

### Priority 2: Dissolve NOTES.md

Redistribute NOTES.md content:

| Section | Destination |
|---------|------------|
| API | Already covered in `docs/development.md` line 7 |
| Build ISO | Already covered in `docs/usb-installer.md` and `docs/development.md` |
| First Build | Already covered in `docs/installation.md` and `docs/development.md` |
| Neovim | Move to new `docs/neovim.md` |
| Niri (logs) | Already covered in `docs/niri.md` and `docs/development.md` |
| Secrets Management | Already covered in `docs/discord-bot.md`; move quick-reference snippet |

After dissolution, delete NOTES.md or replace with a single line pointing to
`docs/README.md`.

### Priority 3: Update Cross-References

- Add `docs/neovim.md` to `docs/README.md` index under "Applications & Desktop"
- Add `docs/neovim.md` reference to root `README.md`
- Add `# See docs/neovim.md.` to the sideloadInitLua inline comment in home.nix
- Remove Neovim-related content from `docs/development.md` (replace with link)
  or move Niri log-checking from development.md to niri.md
- Ensure no broken links after NOTES.md dissolution (currently only
  `docs/development.md:98` references NOTES.md)

### Priority 4: Establish Inline Comment Convention

Define a lightweight convention for nix file inline comments:

- Use `# See docs/X.md.` as a standard cross-reference trailer on comments that
  explain decisions, gotchas, or workarounds with full docs/ context
- Keep inline comments to 1-4 lines explaining why (not what)
- Use consistent capitalization: `# Note:` for implementation notes, `# Critical:`
  for must-know warnings, no ALL_CAPS variants
- Pattern: `# Brief why. See docs/X.md for full context.`

### Priority 5: Document the Convention

Add a "Documentation Conventions" section to `docs/README.md` or a new
`docs/documentation-conventions.md` covering:

- The inline-comment-to-docs/ cross-reference pattern
- How to decide what goes inline vs. docs/
- How to add new docs/ files
- The prohibition on NOTES.md as a staging area (docs/ is the authoritative home)

## Risks & Mitigations

- **Risk**: Deleting NOTES.md breaks workflows that reference it
  - **Mitigation**: Search entire repo for NOTES.md references before deletion;
    only `docs/development.md:98` currently references it
- **Risk**: New docs/neovim.md diverges from actual configuration over time
  - **Mitigation**: Keep docs/neovim.md focused on rationale and gotchas, not
    configuration values that change; cross-reference home.nix as the source of truth
- **Risk**: Cross-reference convention adds maintenance burden
  - **Mitigation**: The convention is opt-in -- only add cross-references for
    decisions/gotchas that genuinely benefit from docs/ context; most inline
    comments remain standalone

## Context Extension Recommendations

- **Topic**: NixOS dotfiles documentation conventions
- **Gap**: No documented convention for how config decisions, gotchas, and fixes
  should be documented across inline comments and docs/
- **Recommendation**: Create a new `docs/documentation-conventions.md` or add a
  "Documentation Conventions" section to `docs/configuration.md` defining:
  (1) inline comment style for nix files, (2) cross-reference pattern to docs/,
  (3) criteria for docs/ vs. inline, (4) prohibition on NOTES.md as staging area

- **Topic**: Neovim configuration in the dotfiles repo
- **Gap**: Neovim setup is a significant part of the configuration but has no
  dedicated docs/ file
- **Recommendation**: Create `docs/neovim.md` covering the home-manager neovim
  module rationale, package choice, provider wrapping, sideloadInitLua gotcha,
  and relationship to the standalone config repo

- **Topic**: Activation script patterns in home.nix
- **Gap**: `home.nix` uses activation scripts for rclone.conf and .claude config
  files (lines 1103-1106) but this pattern is not explained in any docs/ file
- **Recommendation**: Add a section to `docs/configuration.md` or create
  `docs/activation-scripts.md` explaining when and why activation scripts are used
  instead of home.file symlinks

## Appendix

### Search Queries Used

- `grep sideloadInitLua` -- find all references to the fix
- `grep "see docs/|See docs/" *.nix` -- find existing cross-references from nix to docs/
- `grep "# (Why|NOTE|WARNING|IMPORTANT|CRITICAL)" *.nix` -- find explanatory comments
- `grep "# (Note|NOTE|WARNING|IMPORTANT|CRITICAL|FIXME|HACK|TODO)" *.nix` -- broader comment pattern search
- `grep "NOTES\.md" **/*.md` -- find all references to NOTES.md
- Read of all 18 files in docs/ (full or partial)
- Read of NOTES.md, README.md, home.nix (neovim section)

### Documentation File Sizes (for refactoring reference)

| File | Lines |
|------|-------|
| NOTES.md | 141 |
| docs/niri.md | 1035 |
| docs/himalaya.md | 723 |
| docs/discord-bot.md | 379 |
| docs/dictation.md | 328 |
| docs/terminal.md | 322 |
| docs/gnome-settings.md | 222 |
| docs/packages.md | 247 |
| docs/development.md | 192 |
| docs/testing.md | 154 |
| docs/wifi.md | 152 |
| docs/configuration.md | 147 |
| docs/applications.md | 131 |
| docs/installation.md | 78 |
| docs/README.md | 54 |

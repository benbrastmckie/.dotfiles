# Research Report: Discord Bot Documentation Revision

**Task**: 54 - revise_configuration_to_discord_bot_documentation
**Started**: 2026-05-08T12:00:00Z
**Completed**: 2026-05-08T12:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 53 (completed - NixOS Discord bot prerequisites)
**Sources/Inputs**:
- Codebase: `docs/configuration.md` (current file to be revised)
- Codebase: `docs/discord-bot.md` (existing Discord bot documentation)
- Codebase: `configuration.nix` (actual NixOS config with sops, services, Python env)
- Codebase: `flake.nix` (sops-nix input and module imports)
- Codebase: `.sops.yaml` (age key configuration)
- Codebase: `docs/README.md`, `README.md`, `NOTES.md` (crosslink sources)
- Codebase: `docs/usb-installer.md` (crosslink source)
- Codebase: `docs/applications.md` (crosslink source)
- Codebase: Task 53 artifacts (`specs/053_nixos_discord_bot_prerequisites/`)
**Artifacts**:
- specs/054_revise_configuration_to_discord_bot_documentation/reports/01_discord-bot-docs.md
**Standards**: report-format.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- **Two files exist**: `docs/configuration.md` contains a mix of general NixOS configuration docs AND Discord-bot-specific content (sops-nix, systemd services). `docs/discord-bot.md` already exists as a comprehensive standalone Discord bot doc created by task 53.
- **The task is a rename + content revision**: `configuration.md` should NOT be deleted wholesale -- it contains valuable general NixOS documentation (configuration.nix overview, flake.nix, home.nix, WezTerm, memory management, overlays, integration points) that is NOT Discord-bot-specific.
- **Duplication problem**: The sops-nix and systemd services sections in `configuration.md` (lines 141-204) duplicate content already in `discord-bot.md`, and both files crosslink to each other.
- **discord-bot.md is already good**: The existing `docs/discord-bot.md` (284 lines) is comprehensive and accurate -- it covers architecture, files, Python environment, both systemd services, sops-nix secrets, setup checklist, verification, troubleshooting, and rollback.
- **Six files reference `configuration.md`**: `docs/README.md` (2 refs), `README.md` (2 refs), `docs/usb-installer.md` (1 ref). All need updating if configuration.md is renamed or removed.
- **Recommended approach**: Keep `configuration.md` for its general NixOS content, remove the Discord-bot-specific sections from it (sops-nix and systemd services), and ensure `discord-bot.md` is the single source of truth for the Discord bot feature. Update crosslinks as needed.

## Context & Scope

Task 54 asks to "revise `docs/configuration.md` to be named `discord-bot.md` and to carefully and correctly document this feature." However, the research reveals a more nuanced situation: `discord-bot.md` already exists and is comprehensive, while `configuration.md` serves a dual purpose -- it documents both general NixOS configuration AND Discord bot infrastructure.

The task description appears to have been written before `discord-bot.md` was created by task 53. The actual work needed is:
1. Remove Discord-bot-specific content from `configuration.md` (deduplicate)
2. Audit `discord-bot.md` for accuracy against actual NixOS config
3. Fix crosslinks so the docs are consistent
4. Potentially add any missing content from `configuration.md` into `discord-bot.md` if the latter lacks it

## Findings

### 1. Current State of `docs/configuration.md`

The file (210 lines) has these sections:

| Section | Lines | Discord-bot related? | Action |
|---------|-------|---------------------|--------|
| `# NixOS Configuration Details` | 1 | No | Keep |
| `## configuration.nix` | 2-19 | No | Keep |
| `## flake.nix` + overlays | 21-50 | No | Keep |
| `## home.nix` | 52-60 | No | Keep |
| `## Terminal Emulator Configurations` | 62-86 | No | Keep (but could move to `terminal.md`) |
| `## Memory Management` | 88-139 | No | Keep |
| `## Secrets Management (sops-nix)` | 141-181 | **Yes** | Remove -- duplicated in `discord-bot.md` |
| `## Systemd Services` | 183-204 | **Yes** | Remove -- duplicated in `discord-bot.md` |
| `## Key Integration Points` | 206-210 | No | Keep |

The sops-nix and systemd services sections (lines 141-204, ~64 lines) are Discord-bot-specific and already covered (more thoroughly) in `discord-bot.md`.

### 2. Current State of `docs/discord-bot.md`

The file (284 lines) is comprehensive and covers:

| Section | Lines | Content |
|---------|-------|---------|
| Architecture diagram | 7-14 | ASCII art showing Discord <-> bot <-> opencode flow |
| Files table | 16-24 | Lists all relevant config files |
| Python Environment | 26-41 | `discordBotPython` details with package versions |
| opencode-serve.service | 43-66 | Full service config with explanations |
| discord-bot.service | 68-101 | Full service config with env vars |
| Secrets Management | 103-195 | sops-nix config, key files, operations, lifecycle |
| Manual Setup Checklist | 197-220 | Step-by-step first-time setup |
| Verification | 222-248 | Commands to check everything works |
| Troubleshooting | 250-258 | Symptom/cause/fix table |
| Rollback | 260-273 | How to remove the infrastructure |
| Related Documentation | 275-284 | Links to spec artifacts |

### 3. Accuracy Audit of `discord-bot.md` Against Actual Config

Comparing `discord-bot.md` content against `configuration.nix` and `flake.nix`:

| Claim in discord-bot.md | Actual in config | Accurate? |
|------------------------|------------------|-----------|
| Architecture: port `:41100 (random)` | No port specified anywhere | **Inaccurate** -- `:41100` is not referenced in any config; should say "no fixed port" |
| `discordBotPython` packages: nextcord, aiohttp, anyio | `configuration.nix` lines 10-14 confirm | Accurate |
| Package versions (3.1.1, 3.13.4, 4.13.0) | Not verified in config; these were point-in-time | **May drift** -- versions are from nixpkgs, not pinned |
| opencode-serve ExecStart | `configuration.nix` line 874 | Accurate |
| opencode-serve LoadCredential | `configuration.nix` line 878 | Accurate |
| discord-bot ExecStart | `configuration.nix` line 901 | Accurate |
| discord-bot Requires/After | `configuration.nix` lines 894-896 | Accurate |
| discord-bot LoadCredential list | `configuration.nix` lines 904-906 | Accurate |
| discord-bot Environment vars | `configuration.nix` lines 908-915 | Accurate |
| sops config block | `configuration.nix` lines 464-476 | Accurate |
| `.sops.yaml` age key | `.sops.yaml` line 2 | Accurate (key matches) |
| sops-nix in flake.nix | `flake.nix` lines 23-25 | Accurate |
| Module imported on all 4 hosts | `flake.nix` lines 152-153, 184-185, 217-218, 279-280 | Accurate |
| "External task 547" reference | Bot source not yet created | Accurate (still pending) |
| Secrets: whitelisted_user_ids, link_api_token | In secrets.yaml but NOT in sops.secrets NixOS block | **Partial** -- these secrets exist in the encrypted file but are NOT declared in sops.secrets config, so they're NOT decrypted to /run/secrets/ |

**Issues found**:
1. **Line 10**: Architecture diagram shows `:41100 (random)` which is misleading. No port is specified or documented elsewhere. Should say "(dynamic)" or remove the port entirely.
2. **Lines 34-36**: Package versions (nextcord 3.1.1, aiohttp 3.13.4, anyio 4.13.0) are point-in-time values from nixpkgs and will drift. Consider removing specific versions or noting they track nixpkgs.
3. **Lines 127-128**: `whitelisted_user_ids` and `link_api_token` are listed as secrets but are NOT declared in `sops.secrets` in `configuration.nix`. They exist only in the encrypted YAML file. The discord-bot service has empty env vars for `WHITELISTED_USER_IDS` and `LINK_API_TOKEN` (lines 912-913). This means these values are NOT injected from sops -- they are set to empty strings. This should be documented clearly: either add them to `sops.secrets` + `LoadCredential`, or note they are placeholders set directly in the service config.

### 4. Accuracy Audit of `configuration.md` Discord Sections

| Claim | Actual | Accurate? |
|-------|--------|-----------|
| sops-nix on all hosts | `flake.nix` confirms 4 hosts | Accurate |
| sops config block | Matches `configuration.nix` | Accurate |
| opencode-serve description | Correct | Accurate |
| discord-bot description | Mostly correct | **Typo**: "Injectes" should be "Injects" (line 195) |
| `PYTHONPATH` in code block | Shows as attribute, not env var | **Misleading** -- actual config uses `Environment = ["PYTHONPATH=..."]`, the doc shows it as a standalone `PYTHONPATH = ...` |

### 5. Crosslink Inventory

Files that reference `configuration.md` and need updating:

| File | Line | Current Reference | Needed Change |
|------|------|-------------------|---------------|
| `docs/README.md` | 10 | `[configuration.md](configuration.md)` - Core configuration details | Keep as-is (configuration.md stays) |
| `docs/README.md` | 35 | `[configuration.md](configuration.md)` - Reading order | Keep as-is |
| `README.md` | 36 | `docs/configuration.md` - Core configuration details | Keep as-is |
| `README.md` | 76 | `docs/configuration.md` - comprehensive config details | Keep as-is |
| `docs/usb-installer.md` | 773 | `[Configuration Guide](configuration.md)` | Keep as-is |

Files that reference `discord-bot.md`:

| File | Line | Current Reference | Status |
|------|------|-------------------|--------|
| `docs/README.md` | 19 | `[discord-bot.md](discord-bot.md)` | Good |
| `docs/applications.md` | 7 | `[docs/discord-bot.md](discord-bot.md)` | Good |
| `README.md` | 87 | `[docs/discord-bot.md](docs/discord-bot.md)` | Good |
| `docs/configuration.md` | 181 | `[docs/discord-bot.md](discord-bot.md)` | **Remove** (section being deleted) |
| `docs/configuration.md` | 204 | `[docs/discord-bot.md](discord-bot.md)` | **Remove** (section being deleted) |
| `NOTES.md` | 132 | `[docs/discord-bot.md](docs/discord-bot.md)` | Good |

### 6. Documentation Formatting Conventions

Based on analysis of existing docs (`himalaya.md`, `dictation.md`, `niri.md`, `discord-bot.md`):

- **Title**: `# Feature Name` (e.g., `# Himalaya Email Client Configuration`, `# Whisper Dictation Setup`)
- **Opening line**: Brief description of what the feature does
- **Sections**: `## Overview`, `## Architecture`, `## Files`, `## Configuration`, `## Verification`, `## Troubleshooting`
- **Tables**: Used for structured data (file lists, keybindings, parameters)
- **Code blocks**: Use `nix` or `bash` language tags
- **Crosslinks**: Relative paths within `docs/` (e.g., `[discord-bot.md](discord-bot.md)`), from root use `docs/` prefix
- **Back links**: Some docs end with `[Back to main README](../README.md)` but not all

### 7. Content in `configuration.md` That Should Stay

The following sections in `configuration.md` are general NixOS documentation and should remain:

1. **configuration.nix overview** (lines 3-19): General purpose description of configuration.nix
2. **flake.nix overview** (lines 21-50): Flake structure and overlays (Claude Squad, unstable packages, Python packages)
3. **home.nix overview** (lines 52-60): Home Manager description
4. **Terminal Emulator Configurations** (lines 62-86): WezTerm config (NOTE: `docs/terminal.md` also exists -- potential overlap to check)
5. **Memory Management** (lines 88-139): OOM killer, swap hierarchy, VM kernel parameters
6. **Key Integration Points** (lines 206-210): General architecture summary

### 8. Terminal Configuration Overlap

Both `docs/configuration.md` (lines 62-86) and `docs/terminal.md` exist. Let me note this as a potential separate concern -- the WezTerm section in `configuration.md` may be duplicated in `terminal.md`.

## Decisions

1. **Do NOT rename configuration.md to discord-bot.md**: `discord-bot.md` already exists and is comprehensive. `configuration.md` contains valuable general NixOS docs that are not Discord-bot-related.

2. **Remove Discord-bot-specific content from configuration.md**: Remove the "Secrets Management (sops-nix)" section (lines 141-181) and "Systemd Services" section (lines 183-204). Add a brief note pointing to `discord-bot.md` for service/secrets documentation.

3. **Fix inaccuracies in discord-bot.md**: Correct the `:41100 (random)` port reference, fix the `whitelisted_user_ids`/`link_api_token` documentation to accurately reflect their not being in `sops.secrets`.

4. **Keep all crosslinks to configuration.md**: Since configuration.md is being retained (not deleted), no crosslink updates are needed for files referencing it.

5. **Add a crosslink from configuration.md to discord-bot.md**: Add a brief mention in configuration.md's services or integration section pointing readers to `discord-bot.md` for Discord bot infrastructure.

## Recommendations

### Priority 1: Revise `configuration.md`
1. Remove lines 141-204 (sops-nix and systemd services sections)
2. Add a brief "Services" subsection under "Key Integration Points" or as a standalone section that mentions the Discord bot and points to `discord-bot.md`
3. Fix any remaining references to discord-bot content

### Priority 2: Fix `discord-bot.md` Inaccuracies
1. Remove `:41100 (random)` from the architecture diagram -- replace with "(dynamic)" or remove port reference
2. Consider removing specific package versions (3.1.1, 3.13.4, 4.13.0) or noting they track nixpkgs
3. Clarify that `whitelisted_user_ids` and `link_api_token` exist in the encrypted secrets file but are NOT declared in `sops.secrets` and therefore NOT injected via LoadCredential -- the service has empty-string env vars for these

### Priority 3: Crosslink Consistency
1. No crosslink updates needed for `configuration.md` references (file is being kept)
2. Remove the two `discord-bot.md` references in the sections being deleted from `configuration.md`

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Removing config.md content loses useful info | Low | Medium | Verify all removed content exists (more thoroughly) in discord-bot.md before deleting |
| WezTerm section in config.md duplicates terminal.md | Medium | Low | Out of scope for this task; note for future cleanup |
| Package versions in discord-bot.md drift silently | High | Low | Remove specific versions or add note that they track nixpkgs |
| whitelisted_user_ids/link_api_token confusion | Medium | Medium | Document clearly whether these are sops-managed or hardcoded empty |

## Appendix

### A. Files to Modify (Implementation)

| File | Action |
|------|--------|
| `docs/configuration.md` | Remove sops-nix section (lines 141-181), remove systemd services section (lines 183-204), add brief crosslink to discord-bot.md |
| `docs/discord-bot.md` | Fix architecture diagram port, clarify secrets status, consider removing pinned versions |

### B. Files That Do NOT Need Changes

| File | Reason |
|------|--------|
| `docs/README.md` | Already lists both configuration.md and discord-bot.md correctly |
| `README.md` | References to configuration.md remain valid; discord-bot.md reference is correct |
| `docs/usb-installer.md` | Reference to configuration.md remains valid |
| `docs/applications.md` | Reference to discord-bot.md is correct |
| `NOTES.md` | Reference to discord-bot.md is correct |
| `flake.nix` | No doc references |
| `configuration.nix` | No doc references |

### C. Search Queries Used

- `grep -rn "configuration\.md"` across repo
- `grep -rn "discord-bot\.md"` across repo
- `grep -n "discord\|sops\|discordBot\|opencode-serve"` in configuration.nix
- `grep -n "sops"` in flake.nix
- Direct file reads of all docs/*.md files for convention analysis

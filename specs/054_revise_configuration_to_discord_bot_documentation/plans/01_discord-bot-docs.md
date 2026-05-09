# Implementation Plan: Revise Configuration to Discord Bot Documentation

- **Task**: 54 - revise_configuration_to_discord_bot_documentation
- **Status**: [IMPLEMENTING]
- **Effort**: 0.75 hours
- **Dependencies**: Task 53 (completed)
- **Research Inputs**: specs/054_revise_configuration_to_discord_bot_documentation/reports/01_discord-bot-docs.md
- **Artifacts**: plans/01_discord-bot-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: true

## Overview

The task is to eliminate Discord-bot-specific content from `docs/configuration.md` (which also serves as general NixOS documentation) and fix three inaccuracies in the existing `docs/discord-bot.md`. Research found that `discord-bot.md` already exists as a comprehensive standalone document created by task 53, so the work reduces to deduplication, accuracy fixes, and crosslink maintenance. Definition of done: `configuration.md` contains no Discord-bot-specific sections, `discord-bot.md` is accurate against the actual NixOS config, and all crosslinks are valid.

### Research Integration

Research report `01_discord-bot-docs.md` identified:
- `configuration.md` lines 141-204 (sops-nix and systemd services sections) duplicate content already in `discord-bot.md`
- Three inaccuracies in `discord-bot.md`: misleading `:41100` port in architecture diagram, pinned package versions that will drift, and `whitelisted_user_ids`/`link_api_token` listed as sops-managed secrets but NOT declared in `sops.secrets` config
- All five files referencing `configuration.md` can keep their references since the file is retained
- Two `discord-bot.md` references inside the sections being deleted from `configuration.md` will be removed along with the sections

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove duplicated Discord-bot sections (sops-nix, systemd services) from `configuration.md`
- Add a brief crosslink from `configuration.md` to `discord-bot.md` in the Key Integration Points section
- Fix the misleading `:41100 (random)` port reference in `discord-bot.md`
- Clarify that pinned package versions track nixpkgs (not fixed)
- Accurately document the `whitelisted_user_ids` and `link_api_token` secrets status
- Ensure all crosslinks across the docs remain valid after changes

**Non-Goals**:
- Renaming or deleting `configuration.md` (research showed it must be kept for general NixOS content)
- Resolving the WezTerm duplication between `configuration.md` and `terminal.md` (separate concern)
- Modifying any Nix configuration files
- Updating `docs/README.md`, `README.md`, or other docs (their references remain valid)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing sops-nix section loses info not in discord-bot.md | M | L | Research verified discord-bot.md covers all content more thoroughly |
| Package version numbers become inaccurate over time | L | H | Remove specific versions and note they track nixpkgs |
| Secrets documentation misleads users about whitelisted_user_ids | M | M | Clearly document these are empty-string env vars, not sops-injected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Revise `docs/configuration.md` [COMPLETED]

**Goal**: Remove Discord-bot-specific sections and add a crosslink to discord-bot.md

**Tasks**:
- [ ] Remove the "Secrets Management (sops-nix)" section (lines 141-181)
- [ ] Remove the "Systemd Services" section (lines 183-204)
- [ ] Add a bullet to the "Key Integration Points" section mentioning Discord bot infrastructure with a link to `discord-bot.md`
- [ ] Verify the remaining sections flow naturally without the removed content

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `docs/configuration.md` - Remove lines 141-204, add crosslink bullet in Key Integration Points

**Verification**:
- `docs/configuration.md` contains no sops-nix or systemd services sections
- Key Integration Points section includes a link to `discord-bot.md`
- Remaining content reads coherently

---

### Phase 2: Fix `docs/discord-bot.md` Inaccuracies [COMPLETED]

**Goal**: Correct three documented inaccuracies identified by research

**Tasks**:
- [ ] Fix architecture diagram line 10: replace `:41100 (random)` with a note that no port is fixed (dynamic/mDNS discovery)
- [ ] Fix Python Environment table (lines 33-35): remove specific version numbers (3.1.1, 3.13.4, 4.13.0) and note that versions track nixpkgs
- [ ] Fix secrets table (lines 126-127): clarify that `whitelisted_user_ids` and `link_api_token` exist in the encrypted file but are NOT declared in `sops.secrets`, so they are NOT decrypted to `/run/secrets/`; the service sets empty-string env vars for these
- [ ] Update the Manual Setup Checklist item about `whitelisted_user_ids` and `link_api_token` (line 211) to reflect they are set directly in the service config, not injected from sops
- [ ] Verify all internal crosslinks in `discord-bot.md` remain valid

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `docs/discord-bot.md` - Fix architecture diagram, package versions, and secrets documentation

**Verification**:
- Architecture diagram no longer shows `:41100`
- Package version table shows "tracks nixpkgs" instead of specific versions
- Secrets documentation accurately reflects which secrets are sops-managed vs. hardcoded empty
- All crosslinks within the file and to external docs are valid

## Testing & Validation

- [ ] `grep -n "41100" docs/discord-bot.md` returns no results
- [ ] `grep -n "sops\|Secrets Management" docs/configuration.md` returns no results for the removed sections
- [ ] `grep -rn "configuration\.md" docs/ README.md` confirms all references still point to a valid file
- [ ] `grep -rn "discord-bot\.md" docs/ README.md NOTES.md` confirms all references still point to a valid file
- [ ] Visual review: both files read naturally and contain no stale crosslinks

## Artifacts & Outputs

- `docs/configuration.md` - Revised (Discord-bot sections removed, crosslink added)
- `docs/discord-bot.md` - Revised (3 inaccuracies fixed)

## Rollback/Contingency

Both files are tracked in git. If changes introduce errors, revert with:
```bash
git checkout HEAD -- docs/configuration.md docs/discord-bot.md
```

# NixOS Configuration Improvements Implementation Plan

## Metadata
- **Date**: 2025-10-01
- **Feature**: NixOS Configuration Organization, Architecture, and Documentation Improvements
- **Scope**: System-wide configuration refactoring focused on clarity, maintainability, and documentation consistency
- **Estimated Phases**: 5
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Notes**: Based on analysis of configuration structure, 2025 best practices, documentation quality, and architecture issues

## Overview

This plan improves the NixOS configuration for clarity, robustness, and maintainability through targeted refactoring and documentation cleanup. The approach prioritizes simplification over perfection, focusing on:

1. **Quick wins**: Documentation cleanup to establish foundation
2. **Architecture fixes**: Resolve redundancy and hardcoded paths
3. **Selective modularization**: Extract high-impact areas (email config, package lists)
4. **Documentation improvements**: Fill gaps and ensure consistency

The strategy emphasizes incremental, testable changes with dry-build validation after each phase. Current configuration is functional - improvements target maintainability without over-engineering.

## Success Criteria

- [ ] Main configuration files reduced by 40-50% through modularization
- [ ] All specialArgs duplication eliminated
- [ ] No hardcoded Nix store paths remain
- [ ] Email configuration extracted to dedicated module (~180 lines)
- [ ] Documentation inconsistencies resolved
- [ ] All changes validated with dry-build before applying
- [ ] System remains fully functional throughout process

## Technical Design

### Architecture Improvements

**Current Issues:**
- `specialArgs` redundantly passed via both `specialArgs` and `extraSpecialArgs` across 3 configs (flake.nix:125-137, 153-157, 214-220)
- `unstable-packages.nix` exists but unused (overlays defined inline in flake.nix:79-89)
- Hardcoded Nix store paths in home.nix:416
- ISO/nandi configuration duplication (flake.nix:140-196)

**Solutions:**
- Consolidate specialArgs to single location per configuration
- Either use or remove unstable-packages.nix (recommend: use for consistency)
- Replace hardcoded paths with dynamic references
- Extract common ISO/nandi config to shared module

### Modularization Strategy

**Priority Targets (High Impact):**
1. **Email Configuration** (~180 lines in home.nix:168-377)
   - Extract to `home-modules/email.nix`
   - Includes himalaya, mbsync, OAuth2 refresh scripts, systemd services
   - Clear module interface with enable option

2. **Package Lists** (~140 lines in configuration.nix:187-319)
   - Extract to categorized modules in `configuration-modules/`
   - Categories: wayland, terminals, development, editors, multimedia, etc.
   - Use consistent enableOption pattern

3. **Inline Package Definitions** (40+ lines in flake.nix:46-77)
   - claude-squad overlay to `overlays/claude-squad.nix`
   - Unstable packages overlay to `overlays/unstable-packages.nix`

**Not Targeted (Low Impact):**
- Font configuration (already concise, ~18 lines)
- Shell configuration (minimal, ~6 lines)
- Simple service enables

### Documentation Strategy

**Cleanup Tasks:**
1. Remove orchestration content from docs/documentation-index.md (210 lines)
2. Update specs/README.md to reflect existing plans/summaries
3. Consolidate terminal config documentation (currently split)
4. Remove references to deleted helper command files

**New Documentation:**
1. Document config/ directory structure and usage
2. Document .claude/ ecosystem (agents, hooks, commands)
3. Add inline comments for complex Nix expressions
4. Create modules/README.md explaining module structure

## Implementation Phases

### Phase 1: Documentation Cleanup (Foundation)
**Objective**: Remove inconsistencies and outdated content to establish clear documentation baseline
**Complexity**: Low
**Risk**: Minimal (documentation-only changes)

Tasks:
- [ ] Read docs/documentation-index.md and identify orchestration content to remove
- [ ] Edit docs/documentation-index.md to remove helper command references (coordination-hub, resource-manager, workflow-status, performance-monitor, progress-aggregator, workflow-recovery, dependency-resolver, workflow-template)
- [ ] Read specs/README.md and update "Current Documents" section to reflect 7 existing plans and summaries
- [ ] Verify terminal config split between docs/terminal.md and other locations
- [ ] Consolidate or cross-reference terminal documentation appropriately
- [ ] Test: Read all modified documentation files to ensure coherence

Testing:
```bash
# Verify documentation consistency
grep -r "coordination-hub\|resource-manager\|workflow-status" docs/
# Should return no results in documentation-index.md

# Check specs directory accuracy
ls -1 specs/plans/*.md | wc -l
ls -1 specs/summaries/*.md | wc -l
# Compare with specs/README.md content
```

**Validation**: Documentation accurately reflects codebase state, no broken links

### Phase 2: Architecture Fixes (Critical Issues)
**Objective**: Resolve architectural redundancy and hardcoded paths
**Complexity**: Medium
**Risk**: Moderate (requires careful testing)

Tasks:
- [ ] Read flake.nix lines 112-221 to analyze specialArgs usage patterns
- [ ] Consolidate specialArgs: remove duplication between specialArgs and extraSpecialArgs
- [ ] Standard pattern: system-level args in specialArgs, home-manager-specific in extraSpecialArgs
- [ ] Read home.nix:416 and identify hardcoded SASL_PATH
- [ ] Replace hardcoded paths with dynamic package references using ${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2
- [ ] Read unstable-packages.nix to determine its intended purpose
- [ ] Decision: Either use unstable-packages.nix OR remove it (recommend: remove, overlays already inline)
- [ ] If removing: delete unstable-packages.nix and update docs/unstable-packages.md to reference flake.nix overlays
- [ ] Test: nixos-rebuild dry-build

Testing:
```bash
# Dry build test
nixos-rebuild dry-build --flake .#$(hostname)

# Verify no hardcoded paths remain
grep -n "/nix/store/" home.nix
# Should return no results

# Check specialArgs consistency
grep -A 10 "specialArgs\|extraSpecialArgs" flake.nix
# Review output for logical separation
```

**Validation**: Dry-build succeeds, no hardcoded paths, clear specialArgs separation

### Phase 3: Email Configuration Extraction (High-Impact Modularization)
**Objective**: Extract 180-line email configuration to dedicated home module
**Complexity**: Medium
**Risk**: Moderate (complex OAuth2 setup, systemd services)

Tasks:
- [ ] Create home-modules/email.nix with proper module structure (imports/options/config)
- [ ] Extract himalaya package override (home.nix:102-104)
- [ ] Extract mbsync with XOAUTH2 (home.nix:107-119)
- [ ] Extract related packages: cyrus-sasl-xoauth2, msmtp, pass, gnupg, w3m, curl, jq (home.nix:121-127)
- [ ] Extract refresh-gmail-oauth2 script (home.nix:49-99)
- [ ] Extract Mail directory creation activation (home.nix:168-178)
- [ ] Extract systemd services and timers (home.nix:181-217)
- [ ] Extract config files: himalaya config.toml and .mbsyncrc (home.nix:241-377)
- [ ] Add module options: enable (boolean), email (string), clientId (string)
- [ ] Import email.nix in home.nix imports section
- [ ] Enable module: email.enable = true with appropriate config values
- [ ] Test: nixos-rebuild dry-build, then rebuild, verify systemd services

Testing:
```bash
# Dry build test
nixos-rebuild dry-build --flake .#$(hostname)

# Full rebuild
sudo nixos-rebuild switch --flake .#$(hostname)

# Verify systemd services
systemctl --user status gmail-oauth2-refresh.service
systemctl --user status gmail-oauth2-refresh.timer

# Test email functionality
himalaya list
```

**Validation**: Email functionality unchanged, module cleanly separated, home.nix reduced by ~180 lines

### Phase 4: Package List Modularization (Configuration.nix)
**Objective**: Extract categorized package lists from configuration.nix to dedicated modules
**Complexity**: Medium
**Risk**: Low (straightforward package lists)

Tasks:
- [ ] Create configuration-modules/ directory for system package modules
- [ ] Create configuration-modules/wayland-packages.nix (lines 189-209)
- [ ] Create configuration-modules/terminal-packages.nix (lines 211-218)
- [ ] Create configuration-modules/browser-packages.nix (lines 220-222)
- [ ] Create configuration-modules/appearance-packages.nix (lines 224-226)
- [ ] Create configuration-modules/development-packages.nix (lines 228-246, 298-299)
- [ ] Create configuration-modules/lean-packages.nix (lines 248-251)
- [ ] Create configuration-modules/editor-packages.nix (lines 253-257)
- [ ] Create configuration-modules/document-packages.nix (lines 259-271)
- [ ] Create configuration-modules/gnome-packages.nix (lines 273-276)
- [ ] Create configuration-modules/multimedia-packages.nix (lines 278-283)
- [ ] Create configuration-modules/file-transfer-packages.nix (lines 285-287)
- [ ] Create configuration-modules/input-packages.nix (lines 289-291)
- [ ] Create configuration-modules/misc-packages.nix (lines 293-296)
- [ ] Keep inline package wrappers (zathura, sioyek) in configuration.nix (context-specific)
- [ ] Import all new modules in configuration.nix imports section
- [ ] Replace environment.systemPackages with concatenation of module lists
- [ ] Test: nixos-rebuild dry-build, then rebuild

Testing:
```bash
# Dry build test
nixos-rebuild dry-build --flake .#$(hostname)

# Full rebuild
sudo nixos-rebuild switch --flake .#$(hostname)

# Verify package availability (sample from each category)
which kitty vivaldi neovim git zathura
# All should return valid paths
```

**Validation**: All packages available, configuration.nix reduced by ~130 lines, modules organized logically

### Phase 5: Documentation Improvements and Overlay Extraction
**Objective**: Complete documentation gaps and extract remaining inline code
**Complexity**: Low
**Risk**: Minimal

Tasks:
- [ ] Create config/README.md documenting config directory structure and usage
- [ ] Create .claude/README.md documenting agents/, hooks/, commands/ ecosystem
- [ ] Extract claude-squad overlay from flake.nix:45-77 to overlays/claude-squad.nix
- [ ] Extract unstable packages overlay from flake.nix:79-89 to overlays/unstable-packages.nix
- [ ] Create overlays/ directory and update flake.nix to import overlay files
- [ ] Update flake.nix to import overlays: overlays = [ (import ./overlays/claude-squad.nix) (import ./overlays/unstable-packages.nix) ]
- [ ] Create configuration-modules/README.md explaining module structure and conventions
- [ ] Create home-modules/README.md explaining home module patterns
- [ ] Add inline comments to complex Nix expressions in flake.nix (specialArgs logic, nixpkgsConfig)
- [ ] Update docs/configuration.md to reference new module structure
- [ ] Test: nix flake check, nixos-rebuild dry-build

Testing:
```bash
# Flake validation
nix flake check --option allow-import-from-derivation false

# Dry build test
nixos-rebuild dry-build --flake .#$(hostname)

# Verify documentation completeness
ls config/README.md .claude/README.md configuration-modules/README.md home-modules/README.md
# All should exist

# Check overlay imports work
nix eval .#nixosConfigurations.$(hostname).pkgs.claude-squad.version --raw
# Should return version number
```

**Validation**: All documentation complete, overlays cleanly separated, flake passes validation

## Testing Strategy

### Per-Phase Testing
Each phase requires:
1. **Dry-build validation**: `nixos-rebuild dry-build --flake .#$(hostname)`
2. **Phase-specific tests**: Documented in each phase
3. **Incremental commits**: Commit after successful phase completion

### Full System Testing (After All Phases)
```bash
# Complete rebuild
sudo nixos-rebuild switch --flake .#$(hostname)

# Verify critical services
systemctl status NetworkManager
systemctl status gdm
systemctl --user status gmail-oauth2-refresh.timer

# Verify package availability (comprehensive sample)
which kitty wezterm nvim git himalaya mbsync claude-code claude-squad

# Test email functionality
himalaya list
mbsync gmail-inbox-quick

# Verify flake integrity
nix flake check --option allow-import-from-derivation false

# Check configuration file sizes (should be reduced)
wc -l flake.nix configuration.nix home.nix
# Compare with original: flake.nix (224→~180), configuration.nix (367→~230), home.nix (426→~240)
```

### Rollback Testing
```bash
# Test rollback capability
sudo nixos-rebuild switch --rollback

# Verify system boots and functions
# Re-apply latest generation
sudo nixos-rebuild switch --flake .#$(hostname)
```

## Risk Assessment

### High Risk Areas
1. **Email OAuth2 Configuration** (Phase 3)
   - Complex token refresh mechanism
   - Systemd service dependencies
   - Mitigation: Test incrementally, verify services before proceeding

2. **specialArgs Changes** (Phase 2)
   - Critical for flake evaluation
   - Affects all configurations
   - Mitigation: Dry-build after each change, test both nixos and home-manager

### Medium Risk Areas
1. **Package List Extraction** (Phase 4)
   - Many packages to migrate
   - Potential for missing packages
   - Mitigation: Comprehensive post-build package verification

2. **Overlay Extraction** (Phase 5)
   - Custom packages must remain functional
   - Mitigation: Test specific packages (claude-code, claude-squad) after changes

### Low Risk Areas
1. **Documentation Changes** (Phases 1, 5)
   - No code changes
   - Mitigation: Review for broken links, accuracy

## Dependencies

### External
- NixOS 24.11 (current system)
- Home Manager release-24.11
- All current flake inputs (nixpkgs, nixpkgs-unstable, lean4, niri, lectic, nix-ai-tools, utils)

### Internal
- Phase 2 must complete before Phase 3 (specialArgs needed for modules)
- Phase 3 should complete before Phase 4 (establishes module pattern)
- Phase 5 depends on Phases 1-4 (documents final structure)

### Tools Required
- nix flake check
- nixos-rebuild dry-build
- git (for incremental commits)
- grep, wc (for verification)

## Notes

### Design Decisions

1. **Modularization Scope**: Targeted high-impact areas only (email, package lists) rather than complete modularization. Font config, shell config, and service enables remain inline due to brevity.

2. **unstable-packages.nix**: Recommend removal rather than usage - overlays already cleanly defined inline in flake.nix. Avoids introducing another abstraction layer.

3. **Module Structure**: Follow Nix module convention with imports/options/config sections. Enable options provide clear on/off switches.

4. **ISO/nandi Duplication**: Addressed indirectly through package module extraction. Full deduplication would require shared module, but current duplication is minimal after Phase 4.

5. **Inline Wrappers**: Keep zathura and sioyek wrappers in configuration.nix - they're context-specific to GNOME/Unite integration and brief enough not to warrant extraction.

### Simplification Philosophy

This plan follows the user's guidance to avoid over-complication:
- **No** complete modularization of every config section
- **No** complex abstraction layers
- **Yes** to extracting large, self-contained blocks (email, packages)
- **Yes** to fixing clear issues (hardcoded paths, duplicated args)
- **Yes** to documentation that adds value

### Future Considerations

Post-implementation opportunities (not in scope):
- Consider extracting neovim configuration to separate flake input
- Evaluate splitting configuration.nix into system-modules/ (networking, services, hardware)
- Add CI/CD for flake validation on commits
- Consider using nixos-rebuild dry-activate for more thorough pre-flight checks

### Commit Strategy

Recommended commit messages following conventional commit format:

**Phase 1:**
- `docs: remove outdated orchestration content from documentation index`
- `docs: update specs README to reflect current plans and summaries`
- `docs: consolidate terminal configuration documentation`

**Phase 2:**
- `refactor: consolidate specialArgs to eliminate duplication`
- `fix: replace hardcoded Nix store paths with dynamic references`
- `chore: remove unused unstable-packages.nix file`

**Phase 3:**
- `refactor: extract email configuration to dedicated home module`

**Phase 4:**
- `refactor: modularize system packages into categorized modules`

**Phase 5:**
- `refactor: extract overlays to dedicated directory`
- `docs: add README files for config, modules, and .claude directories`
- `docs: add inline comments to complex flake expressions`

## Rollback Plan

### Per-Phase Rollback
If any phase fails validation:
1. Revert changes: `git reset --hard HEAD~1`
2. Re-attempt with refined approach
3. Document issue in implementation notes

### Complete Rollback
If system becomes unstable:
1. Boot previous generation from bootloader
2. Or: `sudo nixos-rebuild switch --rollback`
3. Review all changes in current generation
4. Identify problematic change via git history
5. Cherry-pick successful phases, exclude failing phase

### Data Safety
- All configurations in git: no data loss risk
- NixOS generations provide automatic rollback
- Email data stored separately in ~/Mail: unaffected by config changes
- OAuth2 tokens stored in keyring: unaffected by config changes

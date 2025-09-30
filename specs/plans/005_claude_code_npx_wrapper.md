# Claude Code NPX Wrapper Implementation Plan

## Metadata
- **Date**: 2025-09-30
- **Feature**: Claude Code NPX Wrapper
- **Scope**: Replace complex custom claude-code derivation with zero-maintenance NPX wrapper for latest version access
- **Estimated Phases**: 3
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Reports**: None

## Overview
Replace the current claude-code package management approach with a simple NPX wrapper that automatically uses the latest version from NPM. This eliminates the need for manual version updates, hash calculations, and dependency management while ensuring access to Claude Code 2.0+ features including the new terminal interface and checkpoint system.

The current approach using a custom `buildNpmPackage` derivation has proven complex due to missing package-lock.json files and npm dependency resolution issues. The NPX wrapper approach prioritizes maintainability and automatic updates over traditional Nix package management principles.

## Success Criteria
- [ ] Claude Code 2.0+ accessible via `claude` command system-wide
- [ ] Automatic latest version usage without manual intervention
- [ ] Seamless integration with existing Neovim configuration
- [ ] Zero maintenance required for version updates
- [ ] All Claude Code 2.0 features available (terminal interface, checkpoints, etc.)
- [ ] Fallback to cached version when offline
- [ ] Clean removal of complex custom derivation

## Technical Design

### Architecture
The solution uses a `writeShellScriptBin` derivation that creates a wrapper script:
```nix
writeShellScriptBin "claude" ''
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
```

### Benefits
1. **Zero Maintenance**: No version number updates or hash calculations required
2. **Always Latest**: Automatically uses newest version from NPM registry
3. **Simple Implementation**: Single-file derivation with minimal complexity
4. **Offline Tolerance**: NPX caches versions for offline use
5. **Easy Rollback**: Can revert to nixpkgs version if needed

### Trade-offs
- Requires internet connection for initial version downloads
- Less control over exact version (always uses latest)
- Slight startup delay for version checking (cached after first run)
- Dependency on NPM registry availability

## Implementation Phases

### Phase 1: Create NPX Wrapper Package
**Objective**: Replace the complex custom claude-code.nix with a simple NPX wrapper
**Complexity**: Low

Tasks:
- [ ] Replace `/home/benjamin/.dotfiles/packages/claude-code.nix` with NPX wrapper implementation
- [ ] Ensure nodejs dependency is properly declared
- [ ] Add proper meta information including unfree license
- [ ] Test wrapper builds successfully in isolation

Testing:
```bash
# Test the wrapper builds correctly
NIXPKGS_ALLOW_UNFREE=1 nix-build -E "with import <nixpkgs> {}; callPackage ./packages/claude-code.nix {}"

# Verify the generated script
cat result/bin/claude
```

Expected outcomes:
- Successful build without npm dependency errors
- Generated script contains correct npx invocation
- Proper nodejs path in wrapper script

### Phase 2: Integration and Configuration Updates
**Objective**: Update flake configuration and remove obsolete entries
**Complexity**: Low

Tasks:
- [ ] Verify `/home/benjamin/.dotfiles/flake.nix` overlay correctly references new package
- [ ] Confirm `/home/benjamin/.dotfiles/unstable-packages.nix` has claude-code commented out
- [ ] Update unfree package allowlist in flake.nix if needed
- [ ] Check that home.nix still includes claude-code in packages list

Testing:
```bash
# Test flake builds successfully
nix flake check --option allow-import-from-derivation false

# Dry-run the configuration
home-manager switch --flake .#benjamin --dry-run
```

Expected outcomes:
- Flake check passes without errors
- Home Manager configuration validates successfully
- No conflicts with existing packages

### Phase 3: System Deployment and Validation
**Objective**: Deploy the new wrapper and verify full functionality
**Complexity**: Medium

Tasks:
- [ ] Deploy configuration using home-manager switch
- [ ] Test claude command availability and version
- [ ] Verify Claude Code 2.0+ features are accessible
- [ ] Test Neovim integration still works correctly
- [ ] Validate offline functionality with cached version
- [ ] Clean up old build artifacts if any

Testing:
```bash
# Deploy the configuration
home-manager switch --flake .#benjamin --option allow-import-from-derivation false

# Test basic functionality
claude --version
claude --help

# Test 2.0 features (if available in CLI)
claude # Should show 2.0 terminal interface

# Test from Neovim
nvim # Then test any claude integrations
```

Expected outcomes:
- Claude command works from any directory
- Version shows 2.0+ indicating latest version
- All existing workflows continue to function
- No errors in system rebuild process

## Testing Strategy

### Build Validation
- Isolated package build testing before system integration
- Flake check validation to catch configuration errors early
- Dry-run deployment to verify no conflicts

### Functional Testing
- Command availability testing across different contexts
- Version verification to ensure 2.0+ features
- Integration testing with existing Neovim setup
- Offline functionality testing for cached versions

### Regression Testing
- Verify existing claude workflows still function
- Test system rebuild process completes successfully
- Validate no impact on other package management

## Documentation Requirements
- No additional documentation needed due to implementation simplicity
- CLAUDE.md already covers package management patterns
- Consider adding note about NPX approach if this becomes a pattern

## Dependencies
- **Node.js**: Already available in system via nixpkgs
- **NPM Registry**: Internet access for initial downloads and updates
- **NPX**: Bundled with Node.js, no additional installation needed

## Rollback Plan
If issues arise, easy rollback options:
1. **Immediate**: Uncomment claude-code line in unstable-packages.nix
2. **Alternative**: Use `npx @anthropic-ai/claude-code@latest` directly
3. **Fallback**: Revert to previous system generation

## Risk Assessment

### Low Risk
- Simple implementation with minimal complexity
- Well-tested npx mechanism
- Easy rollback options available

### Mitigation Strategies
- Test in isolation before system deployment
- Maintain commented fallback in unstable-packages.nix
- Use dry-run validation before actual deployment

## Notes
- This approach prioritizes maintainability over traditional Nix packaging principles
- NPX caching means internet is only required for new versions, not every invocation
- The wrapper maintains the same command interface as the original package
- Can serve as a template for other Node.js tools with similar update frequency requirements
- Consider this pattern for other rapidly-updating development tools
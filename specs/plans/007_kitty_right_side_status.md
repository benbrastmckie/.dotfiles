# Kitty Right-Side Status Display Implementation Plan

## Metadata
- **Date**: 2025-10-01
- **Feature**: Custom Kitty tab bar with right-side status display (directory + git branch)
- **Scope**: Implement custom tab_bar.py that preserves exact angled powerline appearance while adding active tab context on right side
- **Estimated Phases**: 3
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Reports**:
  - `/home/benjamin/.dotfiles/specs/reports/008_kitty_right_side_status_display.md`

## Overview

This plan implements a custom Kitty tab bar that displays the active tab's current directory and git branch information on the right side of the tab bar, while maintaining the exact clean angled powerline appearance currently in use.

### Current State
- Kitty config at `/home/benjamin/.dotfiles/config/kitty.conf`
- Tab bar style: `powerline` with `angled` separators
- Tab title template: `"{index}"` showing only numbers (1, 2, 3...)
- Clean, simple appearance that must be preserved

### Target State
- Tab bar style: `custom` (Python-based)
- Custom `tab_bar.py` at `/home/benjamin/.dotfiles/config/tab_bar.py`
- Tabs: Identical angled powerline appearance with numbered titles (no visual change)
- Right side: Shows `~/d/dotfiles  󰘬 master` for active tab's directory and git branch
- Updates dynamically when Neovim changes directories via sessions

### User Workflow Compatibility
1. Terminal opens in `~/`
2. User launches Neovim
3. User selects a session in Neovim (e.g., "dotfiles")
4. Neovim changes directory to `~/.dotfiles`
5. Right-side display updates to show `~/.dotfiles  󰘬 master`

**Critical Requirement**: Must use `draw_tab_with_powerline()` to ensure tabs look **identical** to current setup.

## Success Criteria
- [ ] Tabs render with identical angled powerline appearance (pixel-perfect match to current)
- [ ] Numbered tabs (1, 2, 3...) display exactly as they do now
- [ ] Right side shows active tab's directory in abbreviated form (e.g., `~/d/dotfiles`)
- [ ] Right side shows git branch with icon when in a git repository
- [ ] Display updates when changing directories (including within Neovim sessions)
- [ ] No UI freezing or performance degradation
- [ ] Works in git and non-git directories
- [ ] Long paths are truncated gracefully if terminal is narrow
- [ ] Configuration managed through home-manager/NixOS

## Technical Design

### Architecture

```
Tab Bar Rendering Flow:
1. Kitty calls draw_tab() for each tab
2. Collect active tab's directory and git branch
3. Call draw_tab_with_powerline() for each tab (preserves exact appearance)
4. On last tab, draw right-side status with active tab's info
```

### Key Components

**1. Path Abbreviation (`_abbreviate_path`)**
- Replaces `/home/benjamin` with `~`
- Abbreviates middle directories: `/home/benjamin/projects/myapp` → `~/p/myapp`
- Similar to Fish shell's `prompt_pwd`

**2. Git Branch Detection (`_get_active_git_branch`)**
- Only runs for active tab
- Uses `tab.active_wd` to get current working directory
- Runs `git branch --show-current` with 50ms timeout
- Caches result for 10 redraws to prevent repeated subprocess calls
- Returns formatted string: `"󰘬 branch-name"` or empty string

**3. Directory Retrieval (`_get_active_directory`)**
- Only runs for active tab
- Reads `tab.active_wd` property
- Abbreviates path for display
- Returns abbreviated path string

**4. Right-Side Status Drawing (`_draw_right_status`)**
- Only draws on last tab (rightmost position)
- Calculates right-aligned position based on screen width
- Handles truncation if terminal is narrow
- Draws: `directory  󰘬 branch`

**5. Main Drawing Function (`draw_tab`)**
- Collects info from active tab (directory + branch)
- **Calls `draw_tab_with_powerline()` to render tabs** ← Critical for preserving appearance
- Calls `_draw_right_status()` on last tab with active tab's info

### Data Flow

```
Active Tab Change
    ↓
draw_tab() called for each tab
    ↓
If tab.is_active:
    _get_active_directory(tab) → abbreviated path
    _get_active_git_branch(tab) → git branch (with cache check)
    Store in global variables
    ↓
draw_tab_with_powerline() → Renders tab (identical to built-in)
    ↓
If is_last tab:
    _draw_right_status() → Draws directory + branch on right
```

### Shell Integration Dependency

Requires Kitty shell integration to track `tab.active_wd`:
- Fish shell sends OSC 7 escape codes when directory changes
- Kitty updates `tab.active_wd` property
- Works even when Neovim changes directories internally
- May require adding OSC 7 support to Neovim config if directory changes don't propagate

## Implementation Phases

### Phase 1: Create Custom Tab Bar Python Module
**Objective**: Implement the complete tab_bar.py file with all required functions
**Complexity**: Medium

Tasks:
- [ ] Create `/home/benjamin/.dotfiles/config/tab_bar.py`
- [ ] Add module docstring explaining purpose and features
- [ ] Import required modules from Kitty:
  - [ ] `from kitty.fast_data_types import Screen, get_boss`
  - [ ] `from kitty.tab_bar import DrawData, ExtraData, TabBarData, draw_tab_with_powerline, as_rgb`
- [ ] Import standard library modules: `os`, `subprocess`, `typing.Dict`, `typing.Tuple`
- [ ] Initialize module-level cache: `_git_branch_cache: Dict[str, Tuple[int, str]] = {}`
- [ ] Initialize global variables for active tab info: `_active_directory = ""`, `_active_branch = ""`
- [ ] Implement `_abbreviate_path(path: str) -> str` function:
  - [ ] Replace home directory with `~`
  - [ ] Abbreviate middle path components to first letter
  - [ ] Handle edge cases (empty path, root directory)
  - [ ] Add docstring with examples
- [ ] Implement `_get_active_directory(tab: TabBarData) -> str` function:
  - [ ] Return empty string if not active tab
  - [ ] Read `tab.active_wd` property
  - [ ] Call `_abbreviate_path()` to shorten path
  - [ ] Add docstring
- [ ] Implement `_get_active_git_branch(tab: TabBarData) -> str` function:
  - [ ] Return empty string if not active tab
  - [ ] Read `tab.active_wd` property
  - [ ] Check cache for existing branch (with countdown)
  - [ ] If cache miss, run `git branch --show-current` with subprocess
  - [ ] Set timeout to 0.05 seconds (50ms)
  - [ ] Truncate branch names longer than 20 characters
  - [ ] Format with git icon: `f"󰘬 {branch}"`
  - [ ] Cache result with countdown of 10 (valid) or 5 (empty)
  - [ ] Handle exceptions: `TimeoutExpired`, `FileNotFoundError`, generic `Exception`
  - [ ] Add docstring
- [ ] Implement `_draw_right_status(screen, is_last, directory, git_branch, draw_data)` function:
  - [ ] Early return if not last tab
  - [ ] Build status text from directory and git_branch parts
  - [ ] Calculate status length
  - [ ] Set cursor colors to active tab colors using `as_rgb()`
  - [ ] Calculate right-aligned position: `screen.columns - cursor.x - margin`
  - [ ] Implement truncation logic for long paths
  - [ ] Draw gap spaces to fill to right edge
  - [ ] Draw status text
  - [ ] Add docstring
- [ ] Implement `draw_tab(...)` main function:
  - [ ] Full signature: `draw_data, screen, tab, before, max_title_length, index, is_last, extra_data`
  - [ ] Collect info from active tab and store in globals
  - [ ] **Call `draw_tab_with_powerline()` with all parameters**
  - [ ] Call `_draw_right_status()` on last tab
  - [ ] Return `screen.cursor.x`
  - [ ] Add docstring explaining preservation of powerline appearance

Testing:
```bash
# Validate Python syntax
python3 -m py_compile config/tab_bar.py

# Check for import errors (will fail on Kitty imports, but validates structure)
python3 -c "import ast; ast.parse(open('config/tab_bar.py').read())"
```

Expected Outcomes:
- `tab_bar.py` file created with ~100-120 lines of code
- Python syntax is valid
- All functions have type hints and docstrings
- Code includes comments explaining critical sections

---

### Phase 2: Update Configuration Files
**Objective**: Modify kitty.conf and home.nix to use the custom tab bar
**Complexity**: Low

Tasks:
- [ ] Update `/home/benjamin/.dotfiles/config/kitty.conf`:
  - [ ] Change line ~66: `tab_bar_style powerline` → `tab_bar_style custom`
  - [ ] Comment out line ~67: `tab_powerline_style angled` → `# tab_powerline_style angled  # Not used with custom style`
  - [ ] Add explanatory comment above `tab_bar_style custom`
  - [ ] Keep all other settings unchanged (colors, template, margins, etc.)
- [ ] Update `/home/benjamin/.dotfiles/home.nix`:
  - [ ] Add to "Active configuration files" section (after kitty.conf):
    ```nix
    ".config/kitty/tab_bar.py".source = ./config/tab_bar.py;
    ```
  - [ ] Add to "Config-files directory" section (after kitty.conf):
    ```nix
    ".config/config-files/tab_bar.py".text = builtins.readFile ./config/tab_bar.py;
    ```
- [ ] Stage files for git:
  ```bash
  git add config/tab_bar.py config/kitty.conf home.nix
  ```

Testing:
```bash
# Verify kitty.conf syntax
grep "tab_bar_style" config/kitty.conf
# Should output: tab_bar_style custom

# Verify home.nix syntax
nix-instantiate --parse home.nix > /dev/null
# Should exit with no errors

# Check git status
git status --short
# Should show:
# M  config/kitty.conf
# M  home.nix
# A  config/tab_bar.py
```

Expected Outcomes:
- `kitty.conf` updated to use custom tab bar style
- `home.nix` configured to symlink `tab_bar.py`
- Files staged in git and ready for commit
- No syntax errors in configuration files

---

### Phase 3: Apply Configuration and Test
**Objective**: Deploy the custom tab bar and verify it works correctly in various scenarios
**Complexity**: Medium

Tasks:
- [ ] Apply home-manager configuration:
  ```bash
  home-manager switch --flake .#benjamin --option allow-import-from-derivation false -b backup
  ```
- [ ] Verify files are symlinked:
  ```bash
  ls -lh ~/.config/kitty/kitty.conf ~/.config/kitty/tab_bar.py
  # Both should be symlinks to /nix/store/...
  ```
- [ ] Verify kitty.conf shows custom style:
  ```bash
  grep "tab_bar_style" ~/.config/kitty/kitty.conf
  # Should output: tab_bar_style custom
  ```
- [ ] Reload Kitty configuration (Ctrl+Shift+F5 or restart Kitty)

**Test Scenario 1: Visual Appearance**
- [ ] Open Kitty terminal
- [ ] Verify tabs have angled powerline separators (identical to before)
- [ ] Verify tabs show numbered titles: 1, 2, 3
- [ ] Verify tab colors match previous setup (active: black on light gray, inactive: dark gray on medium gray)
- [ ] Check that powerline angles are crisp and clean

**Test Scenario 2: Git Repository Display**
- [ ] Navigate to a git repository: `cd ~/.dotfiles`
- [ ] Verify right side shows: `~/.dotfiles  󰘬 master` (or current branch)
- [ ] Verify git icon (󰘬) renders correctly (Nerd Font test)
- [ ] Check that branch name is displayed next to directory

**Test Scenario 3: Non-Git Directory**
- [ ] Open new tab and navigate to: `cd /tmp`
- [ ] Verify right side shows: `/tmp` (no git branch)
- [ ] Verify no git icon displayed
- [ ] Switch back to git repo tab, verify branch reappears

**Test Scenario 4: Path Abbreviation**
- [ ] Navigate to: `cd ~/projects/some/deep/directory`
- [ ] Verify right side shows abbreviated path: `~/p/s/d/directory`
- [ ] Verify paths starting with home show `~` instead of `/home/benjamin`

**Test Scenario 5: Long Branch Names**
- [ ] In git repo, create test branch: `git checkout -b very-long-feature-branch-name-that-should-be-truncated`
- [ ] Verify branch name is truncated: `󰘬 very-long-feat...`
- [ ] Checkout original branch: `git checkout master` (or main)

**Test Scenario 6: Neovim Directory Change**
- [ ] Start in home: `cd ~`
- [ ] Verify right side shows: `~`
- [ ] Open Neovim: `nvim`
- [ ] In Neovim, change directory: `:cd ~/.dotfiles`
- [ ] Verify right side updates to: `~/.dotfiles  󰘬 master`
- [ ] If it doesn't update, note that Neovim OSC 7 integration is needed (documented in report)

**Test Scenario 7: Multiple Tabs**
- [ ] Open 3-5 tabs in different directories
- [ ] Verify only active tab's info is shown on right side
- [ ] Switch between tabs, verify right side updates to active tab's context
- [ ] Verify no performance lag when switching tabs

**Test Scenario 8: Narrow Terminal**
- [ ] Resize terminal to narrow width
- [ ] Verify status truncates gracefully or hides if too narrow
- [ ] Resize back to normal width, verify status reappears

**Test Scenario 9: Performance**
- [ ] Open 10+ tabs
- [ ] Rapidly switch between tabs
- [ ] Monitor for UI freezing or lag
- [ ] Verify git branch caching is working (no repeated git calls)

**Test Scenario 10: Edge Cases**
- [ ] Test in repository root: `cd /`
- [ ] Test in directory with no permissions (if applicable)
- [ ] Test with detached HEAD state in git
- [ ] Test with very long directory paths

Testing Commands:
```bash
# Python syntax validation
python3 -m py_compile ~/.config/kitty/tab_bar.py

# Check symlinks
ls -lh ~/.config/kitty/ | grep -E "(kitty.conf|tab_bar.py)"

# Verify git branch detection
cd ~/.dotfiles && git branch --show-current
# Should output current branch name

# Test in non-git directory
cd /tmp && git branch --show-current 2>&1
# Should output error (expected)
```

Expected Outcomes:
- Home-manager applies configuration successfully
- Files are properly symlinked to `~/.config/kitty/`
- Tabs render with identical angled powerline appearance
- Right side displays active tab's directory and git branch
- All test scenarios pass without errors
- No UI freezing or performance issues
- Git branch caching works (check by monitoring git command calls)

---

## Testing Strategy

### Unit-Level Testing
- Python syntax validation with `py_compile`
- Import structure validation (AST parsing)
- Git command availability check

### Visual Regression Testing
- Compare tab appearance before/after implementation
- Verify angled powerline separators are identical
- Check tab colors match previous setup
- Confirm numbered tab titles unchanged

### Functional Testing
- Directory display in various paths
- Git branch detection in repositories
- Non-git directory handling
- Path abbreviation correctness
- Branch name truncation
- Right-side positioning and alignment

### Integration Testing
- Home-manager configuration application
- Kitty configuration reload
- Neovim directory change detection
- Multiple tab scenarios
- Terminal resize handling

### Performance Testing
- Tab switching responsiveness (10+ tabs)
- Git branch caching effectiveness
- Large repository timeout handling
- Subprocess timeout verification

## Rollback Plan

If implementation causes issues, revert using these steps:

### Quick Rollback (Keep tab_bar.py for reference)
```bash
# 1. Restore original kitty.conf settings
cd /home/benjamin/.dotfiles
git diff config/kitty.conf
# Manually revert tab_bar_style to 'powerline' and uncomment tab_powerline_style

# 2. Apply home-manager
home-manager switch --flake .#benjamin --option allow-import-from-derivation false -b backup

# 3. Reload Kitty (Ctrl+Shift+F5)
```

### Full Rollback (Remove custom tab bar)
```bash
# 1. Revert all changes
cd /home/benjamin/.dotfiles
git checkout config/kitty.conf config/tab_bar.py home.nix

# 2. Remove tab_bar.py if created
rm -f config/tab_bar.py

# 3. Apply home-manager
home-manager switch --flake .#benjamin --option allow-import-from-derivation false -b backup

# 4. Reload Kitty
```

### Verify Rollback
```bash
# Check config
grep "tab_bar_style" ~/.config/kitty/kitty.conf
# Should show: tab_bar_style powerline

# Check tab_bar.py doesn't exist (if fully rolled back)
ls ~/.config/kitty/tab_bar.py
# Should show: No such file or directory
```

## Documentation Requirements

### Code Documentation
- [ ] Module-level docstring in `tab_bar.py` explaining purpose
- [ ] Function docstrings with parameters and return types
- [ ] Inline comments for complex logic (caching, positioning calculations)
- [ ] Type hints for all function signatures

### Configuration Documentation
- [ ] Comment in `kitty.conf` explaining custom tab bar reference
- [ ] Comment explaining why `tab_powerline_style` is disabled

### Project Documentation
After successful implementation:
- [ ] Update `CLAUDE.md` or create docs entry for custom tab bar location
- [ ] Document Neovim OSC 7 integration if needed
- [ ] Add troubleshooting section for common issues

### Implementation Summary
After completion:
- [ ] Create `specs/summaries/007_kitty_right_side_status.md`
- [ ] Document files modified, key decisions, results
- [ ] Note any issues encountered and solutions
- [ ] Record performance observations

## Dependencies

### System Dependencies
- **Kitty Terminal**: Version >= 0.26.0 (for custom tab bar API and `draw_tab_with_powerline`)
- **Git**: Version >= 2.0 (for `git branch --show-current` command)
- **Python**: Version >= 3.6 (used by Kitty internally)
- **Nerd Font**: RobotoMono Nerd Font Mono (already configured, supports git icon)
- **Fish Shell**: For shell integration and OSC 7 support

### Python Modules (Standard Library)
- `os`: For path manipulation (`os.path.expanduser`, `os.path.basename`)
- `subprocess`: For running git commands
- `typing`: For type hints (`Dict`, `Tuple`)

### Kitty Python API
- `kitty.fast_data_types.Screen`: Screen drawing interface
- `kitty.fast_data_types.get_boss`: Access to Kitty boss object (imported but may not be used)
- `kitty.tab_bar.DrawData`: Tab bar drawing data container
- `kitty.tab_bar.ExtraData`: Additional drawing data
- `kitty.tab_bar.TabBarData`: Individual tab data (includes `active_wd`, `is_active`)
- `kitty.tab_bar.draw_tab_with_powerline`: Built-in powerline tab rendering function
- `kitty.tab_bar.as_rgb`: Color conversion utility

### Configuration Dependencies
- Existing `config/kitty.conf` with tab bar settings
- `home.nix` for home-manager configuration management
- Kitty shell integration enabled (for `tab.active_wd` to work)

### Optional: Neovim Integration
If directory changes in Neovim don't update the display:
- Neovim configured to send OSC 7 escape sequences on directory change
- Add autocmd in `init.lua` or `init.vim` to emit OSC 7

## Notes

### Design Decisions

**1. Use `draw_tab_with_powerline()` instead of manual rendering**
- **Rationale**: Ensures pixel-perfect match to current angled powerline appearance
- **Alternative considered**: Manually draw separators (rejected - previous Option B failed due to this)
- **Guarantee**: Tabs will look identical to current setup

**2. Display on right side, collect from active tab**
- **Rationale**: User wants info "next to tabs," not in tab titles; needs active tab context
- **Implementation**: Store active tab info in global variables, draw on last tab
- **Alternative considered**: Show in each tab title (rejected - doesn't meet requirements)

**3. Path abbreviation strategy**
- **Rationale**: Long paths take up too much space on right side
- **Chosen approach**: Abbreviate middle components similar to Fish `prompt_pwd`
- **Alternative considered**: Show full path (rejected - too long), show only directory name (rejected - loses context)

**4. Git branch caching with countdown**
- **Rationale**: Prevents repeated subprocess calls on every tab redraw
- **Expiration**: 10 redraws for valid results (~2-5 seconds typical usage)
- **Alternative considered**: Time-based caching (rejected - more complex, no benefit)

**5. 50ms git command timeout**
- **Rationale**: Fast enough for most repos, short enough to prevent UI freezing
- **Trade-off**: Very large repos may timeout and show no branch
- **Alternative considered**: 100ms (too slow), 20ms (too fast)

**6. Global variables for active tab info**
- **Rationale**: Need to pass info from active tab to last tab for display
- **Alternative considered**: Use `extra_data` parameter (cleaner but requires coordination between tab draws)
- **Chosen**: Global variables for simplicity

### Known Limitations

1. **Right-side display only on last tab**: Status appears on rightmost edge, not on active tab itself
   - **Mitigation**: This is by design to display info "next to tabs" on the right side

2. **Neovim directory changes may not propagate**: Requires OSC 7 support in Neovim
   - **Mitigation**: Document how to add OSC 7 autocmd to Neovim config

3. **Git command timeout in large repos**: 50ms may not be enough for very large repositories
   - **Mitigation**: Increase timeout if needed, or implement async approach

4. **Path truncation in narrow terminals**: Status may be truncated or hidden if window is very narrow
   - **Mitigation**: Automatic truncation logic, hides status if no space

5. **Cache doesn't invalidate on git operations**: If user creates/switches branches, cache may show stale info for a few seconds
   - **Mitigation**: Cache expires after 10 redraws (typically 2-5 seconds)

### Future Enhancements

Potential improvements for future iterations:

1. **Async git branch detection**: Use background threads to eliminate any blocking
2. **Git status indicators**: Show `*` for uncommitted changes, `↑3` for unpushed commits
3. **Configurable truncation**: Allow user to set max path length
4. **Color-coded branches**: Different colors for main/develop/feature branches
5. **Additional context**: Show Python venv, Node.js version, kubectl context, etc.
6. **Configuration file**: JSON config for customizing display format and content

### Troubleshooting Guide

**Issue**: Tabs don't look like they used to
- **Cause**: `draw_tab_with_powerline()` not being called correctly
- **Solution**: Verify `tab_bar.py` is calling the function with correct parameters

**Issue**: Right-side status not showing
- **Cause 1**: `tab.active_wd` not available (shell integration issue)
- **Solution**: Verify Kitty shell integration enabled, check `$KITTY_SHELL_INTEGRATION`
- **Cause 2**: Window too narrow
- **Solution**: Widen terminal, status auto-hides if insufficient space

**Issue**: Git branch not updating when Neovim changes directory
- **Cause**: Neovim not sending OSC 7 escape sequences
- **Solution**: Add OSC 7 autocmd to Neovim config (see report for code)

**Issue**: Icons showing as boxes
- **Cause**: Nerd Font not loaded
- **Solution**: Verify `font_family RobotoMono Nerd Font Mono` in kitty.conf

**Issue**: UI freezing when switching tabs
- **Cause**: Git command taking too long
- **Solution**: Increase timeout or check for very large repository issues

**Issue**: Branch name outdated after switching branches
- **Cause**: Cache hasn't expired yet
- **Solution**: Wait a few seconds or switch tabs to trigger redraw

## Phase Execution Notes

### For Implementation with `/implement` Command

This plan is designed for execution with the `/implement` command:
- Each phase is self-contained with clear objectives
- Tasks are specific and testable
- Testing criteria provided for each phase
- Phases build on each other sequentially

### Estimated Time per Phase
- **Phase 1**: 30-45 minutes (Python implementation)
- **Phase 2**: 10-15 minutes (configuration updates)
- **Phase 3**: 30-45 minutes (deployment and comprehensive testing)

**Total estimated time**: 70-105 minutes

### Complexity Assessment
- **Overall complexity**: Medium
- **Primary challenge**: Ensuring tabs render identically to current setup
- **Secondary challenge**: Git subprocess management and caching
- **Risk areas**: Shell integration compatibility, Neovim OSC 7 support

---

**End of Implementation Plan**

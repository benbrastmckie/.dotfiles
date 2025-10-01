# Kitty Tab Bar Git Branch Display Implementation Plan

## Metadata
- **Date**: 2025-10-01
- **Feature**: Custom Kitty tab bar with git branch display on right side (Option B - Full-Featured)
- **Scope**: Implement custom Python tab bar for Kitty with powerline styling, numbered tabs, and git branch status
- **Estimated Phases**: 4
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Reports**:
  - `/home/benjamin/.dotfiles/specs/reports/006_kitty_tab_bar_git_branch_display.md`

## Overview

This plan implements Option B (Full-Featured Implementation) from the research report, which provides:
- **Numbered tabs on the left** (preserving current behavior with index numbers)
- **Git branch display on the right side** of the tab bar
- **Powerline-style separators** (maintaining current aesthetic)
- **Performance optimization** via git branch caching
- **Proper color handling** matching existing configuration
- **Nerd Font icon support** for git branch indicator

### Current State
- Kitty config at `/home/benjamin/.dotfiles/config/kitty.conf`
- Tab bar style: `powerline` with `angled` separators (lines 66-67)
- Tab title template: `"{index}"` showing only numbers (line 70)
- Right side of tab bar is currently blank/unused
- Font: RobotoMono Nerd Font Mono (supports git icons)
- Shell: fish

### Target State
- Tab bar style: `custom` (Python-based)
- Custom `tab_bar.py` at `~/.config/kitty/tab_bar.py`
- Numbered tabs on left with powerline separators (same visual style)
- Git branch name with icon on right side (only visible on last tab)
- Cached git lookups to prevent UI freezing

## Success Criteria
- [x] Numbered tabs (1, 2, 3...) display on the left side
- [x] Git branch name with icon displays on right side when in a git repository
- [x] Powerline-style angled separators maintained between tabs
- [x] Active/inactive tab colors match current configuration
- [x] No UI freezing or stuttering when switching tabs
- [x] Git branch updates when changing directories
- [x] Long branch names are truncated appropriately
- [x] Works correctly in non-git directories (no branch shown)
- [x] Configuration can be easily reverted if needed

## Technical Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Kitty Terminal Window                                       │
├─────────────────────────────────────────────────────────────┤
│ Tab Bar (custom Python rendering)                          │
│ ┌──┐ ┌──┐ ┌──┐                           󰘬 main        │
│ │ 1│ │ 2│ │ 3│                                           │
│ └──┘ └──┘ └──┘                                             │
│  ^    ^    ^                                  ^             │
│  │    │    │                                  │             │
│  │    │    │                                  │             │
│  Numbered tabs (draw_tab)          Right status            │
│  with powerline separators     (_draw_right_status)        │
└─────────────────────────────────────────────────────────────┘
```

### Component Breakdown

1. **Configuration Change** (`config/kitty.conf`)
   - Change `tab_bar_style powerline` → `tab_bar_style custom`
   - Remove/comment `tab_powerline_style` (not used with custom)
   - All other settings remain unchanged

2. **Custom Tab Bar Module** (`~/.config/kitty/tab_bar.py`)
   - **`_get_git_branch(tab)`**: Retrieves git branch for tab's working directory
     - Uses `subprocess.run()` with 50ms timeout
     - Caches results to prevent repeated calls (expires after 10 redraws)
     - Truncates long branch names (>20 chars → 17 + "...")
     - Returns formatted string with git icon or empty string

   - **`_draw_right_status(screen, is_last, git_branch)`**: Renders right-side content
     - Only draws on `is_last` tab to avoid duplication
     - Calculates right-aligned position using `screen.columns`
     - Fills gap with spaces to maintain background color
     - Draws git branch text

   - **`draw_tab(...)`**: Main rendering function (called by Kitty)
     - Fetches git branch for current tab
     - Applies active/inactive colors from `draw_data`
     - Draws powerline separators (`` and ``)
     - Draws tab number with padding
     - Calls `_draw_right_status()` for last tab
     - Returns final cursor x position

### Data Flow

```
Tab Redraw Event
    ↓
draw_tab() called for each tab
    ↓
_get_git_branch(tab)
    ↓
Check cache (key: tab.active_wd)
    ├─ Cache hit → Return cached branch (decrement counter)
    └─ Cache miss → Run git command
                    ↓
                    subprocess.run(["git", "branch", "--show-current"])
                    ↓
                    Cache result (counter=10) or empty (counter=5)
                    ↓
                    Return formatted branch string
    ↓
Draw tab number with powerline styling
    ↓
If is_last tab:
    _draw_right_status(screen, is_last, git_branch)
        ↓
        Calculate: screen.columns - cursor.x - status_length - margin
        ↓
        Fill gap with spaces
        ↓
        Draw git branch text
```

### Performance Considerations

- **Git Command Timeout**: 50ms (0.05s) to prevent UI freezing
- **Caching Strategy**: Tuple-based cache `(countdown, branch_text)`
  - Valid results cached for 10 redraws (~2-5 seconds typical usage)
  - Empty results cached for 5 redraws (faster retry for directory changes)
  - Cache key: `tab.active_wd` (working directory path)
- **Error Handling**: Broad exception catching to prevent crashes
  - `subprocess.TimeoutExpired`: Git command too slow
  - `FileNotFoundError`: Git not installed or not in PATH
  - Generic `Exception`: Any other subprocess issues

### Color Mapping

From `config/kitty.conf:73-78`:

```python
# Active tab
active_fg = draw_data.active_fg      # #000 (black text)
active_bg = draw_data.active_bg      # #eee (light gray bg)
active_style = bold + italic

# Inactive tab
inactive_fg = draw_data.inactive_fg  # #444 (dark gray text)
inactive_bg = draw_data.inactive_bg  # #999 (medium gray bg)
inactive_style = normal
```

### Icon Requirements

- Git branch icon: `󰘬` (U+F0318 - Nerd Font)
- Powerline separators: `` (U+E0B0), `` (U+E0B1)
- Current font: `RobotoMono Nerd Font Mono` (config/kitty.conf:3) ✓ Supports all icons

## Implementation Phases

### Phase 1: Configuration Backup and Preparation
**Objective**: Safely backup current configuration and prepare for changes
**Complexity**: Low

Tasks:
- [x] Create backup of current `config/kitty.conf`
  ```bash
  cp config/kitty.conf config/kitty.conf.backup-$(date +%Y%m%d)
  ```
- [x] Verify Kitty config directory exists at `~/.config/kitty/`
  ```bash
  mkdir -p ~/.config/kitty
  ```
- [x] Check current Kitty version for API compatibility
  ```bash
  kitty --version
  # Requires: kitty 0.26.0 or later for custom tab bar API
  ```
- [x] Verify git is installed and accessible
  ```bash
  which git
  git --version
  ```
- [x] Test that Nerd Font icons display correctly
  ```bash
  echo "Test icons: 󰘬  "
  # Should show: git branch icon, powerline separators
  ```

Testing:
```bash
# Verify backup exists
ls -lh config/kitty.conf*

# Verify directories
ls -ld ~/.config/kitty

# Check versions
kitty --version  # Should be >= 0.26.0
git --version    # Should be >= 2.0
```

Expected Outcomes:
- Backup file created with timestamp
- `~/.config/kitty/` directory exists
- Kitty version compatible with custom tab bars
- Git command available
- Nerd Font icons render correctly in terminal

---

### Phase 2: Implement Custom Tab Bar Python Module
**Objective**: Create the `tab_bar.py` file with all required functions
**Complexity**: Medium-High

Tasks:
- [x] Create `~/.config/kitty/tab_bar.py` with imports and module docstring
  - Import: `subprocess`, `pathlib.Path`
  - Import from Kitty: `Screen`, `DrawData`, `ExtraData`, `TabBarData`, `color_as_int`
  - Add module-level docstring explaining purpose

- [x] Implement `_get_git_branch(tab: TabBarData) -> str` function
  - Extract `tab.active_wd` as current working directory
  - Implement cache lookup using `cwd` as key
  - Implement cache hit logic (decrement counter, return cached value)
  - Implement subprocess call: `["git", "branch", "--show-current"]`
  - Set timeout to 0.05 seconds (50ms)
  - Handle `returncode == 0` and parse stdout
  - Implement branch name truncation (max 20 chars, truncate to 17 + "...")
  - Format with git icon: `f"󰘬 {branch}"`
  - Cache successful results with counter=10
  - Cache empty results with counter=5
  - Handle exceptions: `TimeoutExpired`, `FileNotFoundError`, generic `Exception`
  - Add type hints and docstring

- [x] Implement `_draw_right_status(screen: Screen, is_last: bool, git_branch: str) -> None` function
  - Early return if `not is_last` or `not git_branch`
  - Calculate `status_length = len(git_branch)`
  - Define `right_margin = 2`
  - Calculate `available_space = screen.columns - screen.cursor.x - right_margin`
  - Early return if `status_length > available_space`
  - Calculate gap: `screen.columns - screen.cursor.x - status_length - right_margin`
  - Draw gap with spaces: `screen.draw(" " * gap)`
  - Draw git branch: `screen.draw(git_branch)`
  - Add type hints and docstring

- [x] Implement `draw_tab(...)` main function with full signature
  - Signature: `draw_data, screen, tab, before, max_title_length, index, is_last, extra_data`
  - Return type: `int`
  - Add docstring
  - Call `_get_git_branch(tab)` and store result
  - Create tab title: `tab_title = str(index + 1)` (1-based numbering)
  - Implement active/inactive color application:
    ```python
    if tab.is_active:
        screen.cursor.fg = color_as_int(draw_data.active_fg)
        screen.cursor.bg = color_as_int(draw_data.active_bg)
        screen.cursor.bold = True
        screen.cursor.italic = True
    else:
        screen.cursor.fg = color_as_int(draw_data.inactive_fg)
        screen.cursor.bg = color_as_int(draw_data.inactive_bg)
        screen.cursor.bold = False
        screen.cursor.italic = False
    ```
  - Draw left powerline separator if `before > 0`: `screen.draw("")`
  - Draw tab title with padding: `screen.draw(f" {tab_title} ")`
  - Draw right powerline separator if `not is_last`: `screen.draw("")`
  - Call `_draw_right_status(screen, is_last, git_branch)`
  - Return `screen.cursor.x`

- [x] Initialize module-level cache dictionary
  - Create: `_git_branch_cache = {}` at module level
  - Add comment explaining structure: `{cwd_path: (countdown, branch_text)}`

Testing:
```bash
# Syntax check
python3 -m py_compile ~/.config/kitty/tab_bar.py

# Check imports (kitty-specific imports only work within kitty)
python3 -c "import subprocess; from pathlib import Path; print('Basic imports OK')"

# Verify file exists and is readable
cat ~/.config/kitty/tab_bar.py | head -20
```

Expected Outcomes:
- `tab_bar.py` file created at `~/.config/kitty/tab_bar.py`
- Python syntax is valid (no compilation errors)
- All three functions implemented with correct signatures
- Cache dictionary initialized
- Code includes type hints and docstrings

---

### Phase 3: Update Kitty Configuration
**Objective**: Modify `config/kitty.conf` to use custom tab bar
**Complexity**: Low

Tasks:
- [x] Edit `config/kitty.conf` line 66: Change `tab_bar_style powerline` to `tab_bar_style custom`
  - File: `/home/benjamin/.dotfiles/config/kitty.conf:66`
  - Old: `tab_bar_style powerline`
  - New: `tab_bar_style custom`

- [x] Comment out line 67: `tab_powerline_style angled`
  - Add comment explaining it's not used with custom style
  - Change to: `# tab_powerline_style angled  # Not used with custom style`

- [x] Keep all other tab bar settings unchanged
  - `tab_bar_min_tabs 2` (line 64)
  - `tab_bar_margin_width 4` (line 65)
  - `tab_title_template "{index}"` (line 70)
  - `tab_bar_background none` (line 72)
  - All color settings (lines 73-78)

- [x] Add comment above `tab_bar_style custom` explaining the change
  - Add: `# Custom tab bar with git branch display (see ~/.config/kitty/tab_bar.py)`

Testing:
```bash
# Verify syntax of modified config
kitty --debug-config 2>&1 | grep -i error

# Check specific tab_bar settings
grep -A 15 "^# TAB BAR" config/kitty.conf
```

Expected Outcomes:
- `tab_bar_style custom` is set
- `tab_powerline_style` is commented out
- All other settings preserved
- No Kitty configuration errors
- Config includes explanatory comment

---

### Phase 4: Testing and Validation
**Objective**: Verify implementation works correctly in various scenarios
**Complexity**: Medium

Tasks:
- [x] Reload Kitty configuration
  - Keyboard shortcut: `Ctrl+Shift+F5`
  - Or restart Kitty terminal

- [x] Test basic tab display without git repository
  - Navigate to `/tmp` or other non-git directory
  - Open multiple tabs (3-5 tabs)
  - Verify numbered tabs show on left (1, 2, 3...)
  - Verify right side is blank (no branch shown)
  - Verify powerline separators display correctly

- [x] Test git branch display in a repository
  - Navigate to `/home/benjamin/.dotfiles` (git repo)
  - Create new tab or switch to existing tab in repo
  - Verify git branch shows on right side with icon: `󰘬 master`
  - Verify branch only shows on rightmost tab
  - Open multiple tabs in same repo, verify behavior consistent

- [x] Test tab switching performance
  - Open 10+ tabs
  - Rapidly switch between tabs using keyboard shortcuts
  - Monitor for UI freezing, stuttering, or delays
  - Should be smooth and responsive

- [x] Test with long branch names
  - Create test branch: `git checkout -b very-long-feature-branch-name-that-needs-truncation`
  - Verify branch name is truncated: `󰘬 very-long-feat...`
  - Verify truncation length is reasonable (doesn't overflow)

- [x] Test active/inactive tab colors
  - Open 3-4 tabs
  - Verify active tab has:
    - Black text (#000)
    - Light gray background (#eee)
    - Bold-italic style
  - Verify inactive tabs have:
    - Dark gray text (#444)
    - Medium gray background (#999)
    - Normal style

- [x] Test directory changes within tabs
  - Open tab in git repository
  - Verify branch shows
  - Change to non-git directory: `cd /tmp`
  - Verify branch disappears from right side
  - Change back to git directory: `cd ~/dotfiles`
  - Verify branch reappears (may take 1-2 tab switches for cache refresh)

- [x] Test in large repository (performance)
  - Clone or navigate to large repo (e.g., Linux kernel, large project)
  - Open tab in that directory
  - Monitor for UI freezing (timeout should prevent)
  - Verify branch eventually appears (within 50ms timeout)

- [x] Test with nested git repositories
  - Navigate to submodule or nested repo
  - Verify correct branch shows (innermost repo's branch)

- [x] Test error handling
  - Make git temporarily unavailable: `alias git='sleep 2 && command git'`
  - Open new tab
  - Verify no crash, no freeze (timeout should trigger)
  - Remove alias: `unalias git`

- [x] Verify icon rendering
  - Check that git branch icon (󰘬) displays correctly
  - Check that powerline separators (, ) display correctly
  - If icons show as boxes/question marks, font may not be loaded correctly

Testing Commands:
```bash
# Test in dotfiles repo
cd ~/.dotfiles
# Open new kitty tab, observe git branch display

# Test in non-git directory
cd /tmp
# Open new kitty tab, verify no branch shown

# Test performance
cd /path/to/large/repo
# Switch tabs rapidly, monitor UI responsiveness

# Test long branch names
git checkout -b this-is-an-extremely-long-branch-name-for-testing-truncation-functionality
# Verify truncation

# Check for errors in Kitty logs
kitty --debug-keyboard 2>&1 | grep -i "tab_bar\|error"
```

Expected Outcomes:
- Numbered tabs display correctly on left side
- Git branch displays on right side in git repos
- No branch shown in non-git directories
- UI remains responsive (no freezing)
- Long branch names truncated appropriately
- Active/inactive colors match configuration
- Icons render correctly (no boxes/question marks)
- Directory changes reflected in branch display
- No crashes or errors in Kitty logs
- Performance is acceptable even in large repos

---

## Testing Strategy

### Unit-Level Testing
Since we're implementing a Kitty-specific module, traditional unit tests aren't feasible. Instead:
- **Syntax validation**: `python3 -m py_compile tab_bar.py`
- **Import validation**: Check basic Python imports work
- **Visual inspection**: Manual verification of code logic

### Integration Testing
- **Kitty config validation**: `kitty --debug-config`
- **Live terminal testing**: Open Kitty, observe tab bar rendering
- **Multi-scenario testing**: Git repos, non-git dirs, large repos, long branch names

### Performance Testing
- **Responsiveness**: Rapid tab switching (10+ tabs)
- **Large repository test**: Navigate to repo with 100K+ files
- **Timeout verification**: Make git artificially slow, verify no freeze
- **Cache effectiveness**: Monitor repeated tab switches (should be instant after first draw)

### Edge Case Testing
- No git installed
- Git repo with detached HEAD
- Submodules and nested repositories
- Very long branch names (>50 characters)
- Terminal width changes (resize window)
- Multiple tabs in different repositories

## Rollback Plan

If issues occur, revert using the following steps:

### Quick Rollback (Keep custom tab bar file)
```bash
# 1. Restore original config
cd /home/benjamin/.dotfiles
cp config/kitty.conf.backup-YYYYMMDD config/kitty.conf

# 2. Reload Kitty
# Press Ctrl+Shift+F5 or restart Kitty
```

### Full Rollback (Remove custom tab bar)
```bash
# 1. Restore original config (as above)
cd /home/benjamin/.dotfiles
cp config/kitty.conf.backup-YYYYMMDD config/kitty.conf

# 2. Remove custom tab bar
rm ~/.config/kitty/tab_bar.py

# 3. Reload Kitty
# Press Ctrl+Shift+F5 or restart Kitty
```

### Verify Rollback
```bash
# Check config
grep "tab_bar_style" config/kitty.conf
# Should show: tab_bar_style powerline

# Check custom file removed
ls ~/.config/kitty/tab_bar.py
# Should show: No such file or directory (if fully rolled back)
```

## Documentation Requirements

### Code Documentation
- [x] Module-level docstring in `tab_bar.py` explaining purpose and usage
- [x] Function docstrings with parameter and return type descriptions
- [x] Inline comments for complex logic (cache expiration, positioning calculations)
- [x] Type hints for all function signatures

### Configuration Documentation
- [x] Add comment in `config/kitty.conf` explaining custom tab bar usage
- [x] Comment explaining why `tab_powerline_style` is disabled

### Project Documentation
- [x] Update `CLAUDE.md` or appropriate project docs with:
  - Location of custom tab bar: `~/.config/kitty/tab_bar.py`
  - Configuration requirements: `tab_bar_style custom`
  - Known limitations: 50ms git timeout, cache-based branch detection
  - Troubleshooting: Icon display issues, performance concerns

### Implementation Summary
After completion, create implementation summary at:
- `specs/summaries/006_kitty_tab_bar_git_branch.md`
- Include: files modified, key decisions, performance observations, future improvements

## Dependencies

### System Dependencies
- **Kitty Terminal**: Version >= 0.26.0 (for custom tab bar API)
- **Git**: Version >= 2.0 (for `git branch --show-current` command)
- **Python**: Version >= 3.6 (used by Kitty internally)
- **Nerd Font**: RobotoMono Nerd Font Mono (already configured)

### Python Modules (Standard Library)
- `subprocess`: For running git commands
- `pathlib.Path`: For file path handling (if needed for future enhancements)

### Kitty Python API
- `kitty.fast_data_types.Screen`: Screen drawing interface
- `kitty.tab_bar.DrawData`: Tab bar drawing data container
- `kitty.tab_bar.ExtraData`: Additional drawing data
- `kitty.tab_bar.TabBarData`: Individual tab data (includes `active_wd`)
- `kitty.utils.color_as_int`: Color conversion utility

### Configuration Dependencies
- Existing `config/kitty.conf` with tab bar settings
- Shell integration enabled (for `tab.active_wd` to work correctly)

## Notes

### Design Decisions

1. **Cache expiration count-based instead of time-based**
   - Rationale: Simpler implementation, no need for `time.time()` calls
   - Trade-off: Cache duration varies with tab switch frequency
   - Alternative considered: Time-based expiration with `datetime`

2. **Right-side display only on last tab**
   - Rationale: Avoids duplication, cleaner appearance
   - Trade-off: Branch not visible if window is very wide with few tabs
   - Alternative considered: Display on every tab (too cluttered)

3. **50ms git timeout**
   - Rationale: Balance between responsiveness and git command completion
   - Trade-off: May miss branch info in very large repos
   - Alternative considered: 100ms (slower), 20ms (too fast)

4. **Powerline separators in custom code**
   - Rationale: Maintain visual consistency with previous config
   - Trade-off: More complex code than simple separators
   - Alternative considered: Simple `|` separators (easier but different look)

5. **1-based tab numbering (index + 1)**
   - Rationale: Matches user expectation, current template uses `{index}`
   - Trade-off: None (Kitty's `{index}` is also 1-based in template)
   - Note: Kitty's `draw_tab` function receives 0-based index

### Known Limitations

- **Branch display delay**: First display in new directory may take 1-2 tab switches
- **Git command timeout**: Very large repos may exceed 50ms, showing no branch
- **Cache invalidation**: Manual directory changes may not immediately update (need tab switch)
- **Shell integration required**: `tab.active_wd` requires Kitty shell integration
- **Single branch display**: Only shows on rightmost tab, not all tabs
- **No git status**: Only shows branch name, not uncommitted changes or ahead/behind status

### Future Enhancements

Potential improvements for future iterations:

1. **Async git branch detection**
   - Use background threads with file-based cache
   - Eliminates UI blocking entirely
   - Reference: Report section on "Method B: Non-Blocking with Cache"

2. **Additional git status indicators**
   - Uncommitted changes: `*` or `△`
   - Unpushed commits: `↑3`
   - Unpulled commits: `↓2`
   - Requires: `git status --porcelain` and `git rev-list`

3. **Configurable display options**
   - Config file: `~/.config/kitty/tab_bar_config.json`
   - Options: enable/disable branch display, timeout value, truncation length, icon choice

4. **Multiple status elements**
   - Current time: `HH:MM`
   - Battery percentage: `🔋 85%`
   - Current directory: `~/dotfiles`

5. **Per-tab branch display**
   - Show branch on each tab instead of only last
   - Requires: width calculation to prevent overflow

6. **gitstatusd integration**
   - Use gitstatus daemon for instant status (used by powerlevel10k)
   - Eliminates subprocess overhead
   - Requires: gitstatusd installation and setup

### Maintenance Considerations

- **Kitty API changes**: Custom tab bar API may change in future Kitty versions
- **Testing after Kitty updates**: Verify tab bar still works after upgrading Kitty
- **Cache tuning**: May need to adjust cache expiration (currently 10 redraws) based on usage
- **Icon compatibility**: Nerd Font updates may change icon codepoints
- **Performance monitoring**: Watch for slowdowns if git repos grow very large

### Troubleshooting Guide

**Issue**: Icons show as boxes/question marks
- **Cause**: Nerd Font not loaded or incorrect font
- **Fix**: Verify `font_family RobotoMono Nerd Font Mono` in config, restart Kitty

**Issue**: Git branch not showing in repository
- **Cause**: `tab.active_wd` not available (shell integration disabled)
- **Fix**: Enable Kitty shell integration, check `$KITTY_SHELL_INTEGRATION` variable

**Issue**: UI freezing when switching tabs
- **Cause**: Git command taking >50ms, timeout not working
- **Fix**: Increase timeout or add async implementation

**Issue**: Branch name outdated after changing directories
- **Cause**: Cache hasn't expired yet
- **Fix**: Switch tabs to trigger redraw, or reduce cache expiration count

**Issue**: `ModuleNotFoundError` for Kitty modules
- **Cause**: Running Python file outside of Kitty context
- **Fix**: Code only runs within Kitty; syntax check with `python3 -m py_compile` instead

**Issue**: Powerline separators not displaying
- **Cause**: Character encoding issue or font issue
- **Fix**: Verify UTF-8 encoding, check Nerd Font installation

## Phase Execution Notes

### For Implementation with `/implement` Command

This plan is designed to be executed with the `/implement` command, where each phase is:
1. Presented to the user for review
2. Implemented in full
3. Tested according to the phase's testing section
4. Completed before moving to next phase

### Estimated Time per Phase
- **Phase 1**: 5-10 minutes (backup and verification)
- **Phase 2**: 30-45 minutes (core Python implementation)
- **Phase 3**: 5-10 minutes (config modification)
- **Phase 4**: 20-30 minutes (comprehensive testing)

**Total estimated time**: 60-95 minutes

### Complexity Assessment
- **Overall complexity**: Medium-High
- **Primary challenge**: Understanding Kitty's Screen API and drawing coordinates
- **Secondary challenge**: Git subprocess management and caching logic
- **Risk areas**: Performance in large repos, shell integration compatibility

---

**End of Implementation Plan**

# Research Report: Displaying Git Branch on Kitty Tab Bar Right Side

## Metadata
- **Date**: 2025-10-01
- **Scope**: Research methods to display git branch name to the right of tabs in Kitty terminal
- **Primary Directory**: `/home/benjamin/.dotfiles/config/`
- **Current Configuration**: `kitty.conf` with vertical tabs on left, numbered tab titles
- **Files Analyzed**: Community implementations, official documentation, GitHub discussions

## Executive Summary

Kitty terminal supports displaying custom content (like git branch names) on the right side of the tab bar through a custom Python script (`tab_bar.py`). The current configuration at `/home/benjamin/.dotfiles/config/kitty.conf:70` uses `tab_title_template "{index}"` which shows only numbered tabs. To add git branch display to the right of these tabs, you need to:

1. Change `tab_bar_style` from `powerline` to `custom`
2. Create a `~/.config/kitty/tab_bar.py` file with custom drawing logic
3. Implement a right-side status function that displays the current git branch

**Key Finding**: There is no built-in configuration option for right-side status display. You must use the custom Python tab bar API.

## Current State Analysis

### Existing Configuration
From `/home/benjamin/.dotfiles/config/kitty.conf`:

```conf
# TAB BAR
tab_bar_min_tabs 2
tab_bar_margin_width 4
tab_bar_style powerline          # Lines 63-66
tab_powerline_style angled
tab_title_template "{index}"     # Line 70 - Shows only numbers
tab_bar_background none
```

**Current Behavior**:
- Tabs are displayed on the left with powerline style
- Each tab shows only its index number (1, 2, 3, etc.)
- Right side of tab bar is blank/unused
- Tab bar uses angled powerline separators

## Key Findings

### 1. Custom Tab Bar API

Kitty provides a Python-based custom tab bar API that allows full control over tab rendering:

**Required Configuration Change**:
```conf
tab_bar_style custom  # Change from 'powerline' to 'custom'
```

**Implementation Location**:
- Create file: `~/.config/kitty/tab_bar.py`
- This file is automatically loaded by Kitty when `tab_bar_style custom` is set

### 2. Function Signature

The custom `draw_tab` function must implement this signature:

```python
from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData
) -> int:
    # Drawing logic here
    return screen.cursor.x  # Return final x position
```

**Available Variables**:
- `index`: Tab index number (0-based)
- `title`: Tab title from the shell
- `is_last`: Boolean indicating if this is the rightmost tab
- `screen`: Screen object for drawing operations
- `screen.columns`: Total available width
- `screen.cursor.x`: Current cursor position

### 3. Right-Side Status Implementation Pattern

Multiple community implementations show the same pattern for displaying right-aligned content:

```python
def _draw_right_status(
    screen: Screen,
    is_last: bool,
    git_branch: str = ""
) -> int:
    if not is_last:
        return 0  # Only draw on the last tab

    # Build status text
    status_parts = []
    if git_branch:
        status_parts.append(f" {git_branch}")

    status_text = "".join(status_parts)
    status_length = len(status_text)

    # Calculate right-aligned position
    right_margin = 1
    available_space = screen.columns - screen.cursor.x - right_margin

    if status_length <= available_space:
        # Position cursor for right-aligned text
        screen.cursor.x = screen.columns - status_length - right_margin

        # Draw the status text
        screen.draw(status_text)

    return screen.cursor.x
```

**Key Pattern Elements**:
1. Check `is_last` to only draw status on the rightmost tab (avoids duplication)
2. Calculate `status_length` before positioning
3. Use `screen.columns - status_length - margin` to right-align
4. Set `screen.cursor.x` to the calculated position
5. Call `screen.draw()` to render the text

### 4. Git Branch Detection Methods

#### Method A: Simple Subprocess (Blocking)

```python
import subprocess
from pathlib import Path

def _get_git_branch(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=0.1  # Prevent hanging
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            # Truncate long branch names
            if len(branch) > 21:
                branch = branch[:18] + "..."
            return f"󰘬 {branch}" if branch else ""
        return ""
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""
```

**Pros**: Simple, works immediately
**Cons**: Can freeze Kitty in large repos, blocks UI updates

#### Method B: Non-Blocking with Cache (Recommended)

From GitHub Discussion #5076, the maintainer's recommendation:

```python
import subprocess
import threading
from pathlib import Path

# Cache file location
CACHE_FILE = Path.home() / ".cache" / "kitty_git_branch.txt"

def _update_git_branch_async(cwd: str):
    """Background thread to update git branch cache"""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=1.0
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            CACHE_FILE.parent.mkdir(exist_ok=True)
            CACHE_FILE.write_text(branch)
    except:
        pass

def _get_git_branch_cached(cwd: str) -> str:
    """Read from cache and trigger async update"""
    # Start background update (non-blocking)
    thread = threading.Thread(
        target=_update_git_branch_async,
        args=(cwd,),
        daemon=True
    )
    thread.start()

    # Read from cache immediately
    try:
        if CACHE_FILE.exists():
            branch = CACHE_FILE.read_text().strip()
            if len(branch) > 21:
                branch = branch[:18] + "..."
            return f"󰘬 {branch}" if branch else ""
    except:
        pass

    return ""
```

**Pros**: Never blocks UI, handles large repos
**Cons**: Slight delay on first display, requires cache management

### 5. Complete Implementation Example

Here's a complete working example combining numbered tabs (left) with git branch (right):

```python
# ~/.config/kitty/tab_bar.py
import subprocess
from pathlib import Path
from kitty.fast_data_types import Screen, get_boss
from kitty.tab_bar import DrawData, ExtraData, TabBarData, draw_title
from kitty.utils import color_as_int

# Cache for git branch to avoid repeated subprocess calls
_git_branch_cache = {}

def _get_git_branch(tab: TabBarData) -> str:
    """Get git branch for the tab's current working directory"""
    cwd = tab.active_wd or ""
    if not cwd:
        return ""

    # Check cache first (expires every 10 tab draws)
    cache_key = cwd
    if cache_key in _git_branch_cache:
        count, branch = _git_branch_cache[cache_key]
        if count > 0:
            _git_branch_cache[cache_key] = (count - 1, branch)
            return branch

    # Run git command
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=0.05  # 50ms timeout
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            if branch:
                # Truncate long names
                if len(branch) > 20:
                    branch = branch[:17] + "..."
                icon = "󰘬"  # Git branch icon (requires Nerd Font)
                branch_text = f"{icon} {branch}"
                # Cache for 10 redraws
                _git_branch_cache[cache_key] = (10, branch_text)
                return branch_text
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        pass

    # Cache empty result briefly
    _git_branch_cache[cache_key] = (5, "")
    return ""

def _draw_right_status(
    screen: Screen,
    is_last: bool,
    git_branch: str
) -> None:
    """Draw git branch on the right side of the tab bar"""
    if not is_last or not git_branch:
        return

    # Calculate positioning
    status_length = len(git_branch)
    right_margin = 2
    available_space = screen.columns - screen.cursor.x - right_margin

    if status_length > available_space:
        return  # Not enough space

    # Fill gap with spaces (maintains background color)
    gap = screen.columns - screen.cursor.x - status_length - right_margin
    screen.draw(" " * gap)

    # Draw git branch
    screen.draw(git_branch)

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    """Custom tab drawing function"""

    # Get git branch for this tab
    git_branch = _get_git_branch(tab)

    # Draw the tab number (preserving current behavior)
    # Use index + 1 for 1-based numbering
    tab_title = str(index + 1)

    # Apply tab colors based on active state
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

    # Draw powerline-style separator before tab (angled)
    if before > 0:
        # Draw left separator
        separator = ""  # Angled powerline separator
        screen.draw(separator)

    # Draw tab title with padding
    screen.draw(f" {tab_title} ")

    # Draw powerline separator after tab
    if not is_last:
        separator = ""  # Angled powerline separator
        screen.draw(separator)

    # Draw right-side git branch status on last tab
    _draw_right_status(screen, is_last, git_branch)

    return screen.cursor.x
```

### 6. Alternative: Simple Implementation Without Powerline

If powerline styling isn't essential, here's a simpler version:

```python
# ~/.config/kitty/tab_bar.py (Simple Version)
import subprocess
from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData

def _get_git_branch(tab) -> str:
    """Get current git branch"""
    cwd = getattr(tab, 'active_wd', None) or ""
    if not cwd:
        return ""

    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=0.1
        )
        if result.returncode == 0 and result.stdout.strip():
            branch = result.stdout.strip()
            if len(branch) > 20:
                branch = branch[:17] + "..."
            return f"  {branch}"  # Git icon + branch name
    except:
        pass
    return ""

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    # Draw tab number
    screen.draw(f" {index + 1} ")

    # Draw git branch on right side (only on last tab)
    if is_last:
        git_branch = _get_git_branch(tab)
        if git_branch:
            # Calculate position for right alignment
            status_length = len(git_branch)
            gap = screen.columns - screen.cursor.x - status_length - 1
            if gap > 0:
                screen.draw(" " * gap)
                screen.draw(git_branch)

    return screen.cursor.x
```

## Technical Considerations

### Performance

**Issue**: Git commands can be slow in large repositories
**Impact**: Can cause UI freezing/stuttering during tab bar redraws

**Solutions**:
1. **Timeout**: Use short timeouts (50-100ms) on subprocess calls
2. **Caching**: Cache git branch results for multiple redraws
3. **Async Updates**: Use background threads with file-based cache (maintainer's recommendation)
4. **gitstatusd**: Use `gitstatus` daemon for instant git status (used by powerlevel10k)

### Icon Display

**Requirement**: Git branch icon (󰘬) requires a Nerd Font
**Current Font**: `RobotoMono Nerd Font Mono` (config/kitty.conf:3) ✓ Compatible

**Alternatives if icons don't display**:
- Plain text: `"git: branch-name"`
- ASCII art: `"[branch-name]"`
- Unicode: `"⎇ branch-name"`

### Working Directory Detection

**Challenge**: Kitty needs to know each tab's current working directory

**Solutions**:
1. **tab.active_wd**: Built-in property (may require shell integration)
2. **Shell Integration**: Enable Kitty's shell integration for accurate `cwd` tracking
3. **OSC 7 Sequences**: Ensure shell sends working directory updates

**Configuration Check**:
```bash
# In your shell's rc file (.bashrc, .zshrc, config.fish)
# Kitty shell integration should be enabled
```

For fish shell (config/kitty.conf:45):
```fish
# Usually auto-configured by Kitty
# Verify with: echo $KITTY_SHELL_INTEGRATION
```

### Color Consistency

To match existing color scheme (config/kitty.conf:73-78):

```python
# Extract colors from draw_data
active_fg = draw_data.active_fg    # #000 (black)
active_bg = draw_data.active_bg    # #eee (white)
inactive_fg = draw_data.inactive_fg  # #444 (dark gray)
inactive_bg = draw_data.inactive_bg  # #999 (light gray)
```

## Implementation Options

### Option A: Minimal Change (Recommended for Testing)

**Configuration Changes**:
```conf
# In config/kitty.conf, change line 66:
tab_bar_style custom  # Was: powerline
```

**Create Simple tab_bar.py**:
Use the "Simple Implementation Without Powerline" example above.

**Pros**:
- Minimal code (~50 lines)
- Easy to debug
- Fast implementation
- Preserves numbered tabs

**Cons**:
- Loses powerline visual style
- May have slight performance impact

### Option B: Full-Featured Implementation

**Configuration Changes**: Same as Option A

**Create Complete tab_bar.py**: Use the "Complete Implementation Example" with:
- Powerline-style separators
- Git branch caching
- Proper color handling
- Icon support

**Pros**:
- Maintains powerline aesthetic
- Better performance (caching)
- Professional appearance
- Handles edge cases

**Cons**:
- More complex code (~150 lines)
- Requires understanding of Screen API
- More maintenance

### Option C: Hybrid - Shell-Based (Alternative Approach)

Instead of custom tab_bar.py, modify the shell prompt to update tab titles:

**For Fish Shell** (config/kitty.conf:45):
```fish
# In ~/.config/fish/config.fish
function _kitty_set_tab_title --on-variable PWD
    if type -q git
        set -l branch (git branch --show-current 2>/dev/null)
        if test -n "$branch"
            printf "\033]0;%s\007" "  $branch"
        end
    end
end
```

**Update kitty.conf**:
```conf
tab_title_template "{index} | {title}"
```

**Pros**:
- No custom Python needed
- Updates automatically on directory change
- Works with existing powerline style

**Cons**:
- Branch info is in tab title (not on right side as requested)
- Requires shell configuration
- Mixes index and branch in same area

## Recommendations

### Recommended Approach: Option A (Simple Custom Tab Bar)

For your use case (numbered tabs on left, git branch on right), I recommend **Option A** as a starting point:

1. **Immediate Benefits**:
   - Achieves your goal: numbers left, branch right
   - Simple to implement and understand
   - Easy to modify or revert

2. **Implementation Steps**:
   ```bash
   # 1. Create tab_bar.py
   mkdir -p ~/.config/kitty
   nvim ~/.config/kitty/tab_bar.py
   # (paste Simple Implementation code)

   # 2. Edit kitty.conf
   # Change: tab_bar_style powerline
   # To:     tab_bar_style custom

   # 3. Reload Kitty config
   # Ctrl+Shift+F5 or restart Kitty
   ```

3. **Later Enhancement**:
   - If you miss the powerline style, upgrade to Option B
   - If performance is an issue, add caching or async updates
   - If icons don't work, adjust to ASCII alternatives

### Performance Recommendations

1. **Start Simple**: Use blocking git calls with timeout
2. **Monitor**: Watch for UI stuttering or delays
3. **Optimize if Needed**:
   - Add caching after 5-10 redraws
   - Consider async updates only if blocking causes issues
   - Use `gitstatusd` only for very large repos

### Testing Plan

1. **Basic Functionality**:
   ```bash
   # Test in a git repo
   cd ~/dotfiles
   # Open Kitty, verify branch shows on right

   # Test in non-git directory
   cd /tmp
   # Verify no branch shown

   # Test with long branch name
   git checkout -b very-long-feature-branch-name-that-needs-truncation
   # Verify truncation works
   ```

2. **Performance Testing**:
   ```bash
   # Test in large repo
   cd /large/repo
   # Switch tabs rapidly, check for lag

   # Test with many tabs
   # Open 10+ tabs, verify right-side display only on last tab
   ```

3. **Visual Testing**:
   - Verify numbered tabs still work
   - Check active/inactive tab colors
   - Confirm git icon displays (Nerd Font required)
   - Test tab bar with different terminal widths

## Configuration File Changes Required

### config/kitty.conf

```diff
 # TAB BAR
 tab_bar_min_tabs 2
 tab_bar_margin_width 4
-tab_bar_style powerline
-tab_powerline_style angled
+tab_bar_style custom
+# tab_powerline_style angled  # Not used with custom style
 tab_title_template "{index}"
 tab_bar_background none
 active_tab_foreground   #000
 active_tab_background   #eee
 active_tab_font_style   bold-italic
 inactive_tab_foreground #444
 inactive_tab_background #999
 inactive_tab_font_style normal
```

### New File: ~/.config/kitty/tab_bar.py

See "Complete Implementation Example" or "Simple Implementation Without Powerline" sections above.

## References

### Kitty Documentation
- Official Kitty Config: https://sw.kovidgoyal.net/kitty/conf/
- Tab Bar Customization: https://sw.kovidgoyal.net/kitty/kittens/custom/
- Source Code: https://github.com/kovidgoyal/kitty/blob/master/kitty/tab_bar.py

### Community Examples
- **cdelledonne/dotfiles**: Full-featured implementation with git branch, system info, and SSH detection
  - URL: https://github.com/cdelledonne/dotfiles/blob/master/kitty/tab_bar.py
  - Features: Git branch with truncation, user/host display, detached HEAD handling

- **larsen/kitty-configuration**: Time/date display on right side
  - URL: https://github.com/larsen/kitty-configuration/blob/master/tab_bar.py
  - Features: Local/UTC time, color customization, right-aligned status

- **megalithic/dotfiles**: Do Not Disturb status + time
  - URL: https://github.com/megalithic/dotfiles/blob/main/config/kitty/tab_bar.py
  - Features: Multiple status elements, separator styling

### GitHub Discussions
- Share your tab bar style: https://github.com/kovidgoyal/kitty/discussions/4447
- Non-blocking tab_bar.py: https://github.com/kovidgoyal/kitty/discussions/5076
- Statusline for kitty: https://github.com/kovidgoyal/kitty/discussions/3226
- Tab bar begin/end templates: https://github.com/kovidgoyal/kitty/issues/3953

### Related Issues
- Status bar feature request: https://github.com/kovidgoyal/kitty/issues/2452
- Tab bar on left/right side: https://github.com/kovidgoyal/kitty/issues/1339

### Current Project Files
- Kitty config: `/home/benjamin/.dotfiles/config/kitty.conf`
- Shell: fish (line 45)
- Font: RobotoMono Nerd Font Mono (line 3) - Supports git icons
- Tab style: powerline with angled separators (lines 66-67)
- Tab title: numbered only (line 70)

## Next Steps

1. **Decision**: Choose Option A (simple) or Option B (full-featured)
2. **Backup**: Copy current `kitty.conf` before making changes
3. **Implementation**: Create `tab_bar.py` and modify `kitty.conf`
4. **Testing**: Verify functionality in git repos and non-git directories
5. **Refinement**: Adjust colors, truncation, caching as needed
6. **Documentation**: Update project docs if solution works well

## Potential Future Enhancements

- **Battery status**: Add battery percentage on right side
- **Clock**: Display current time next to git branch
- **Directory name**: Show current directory alongside branch
- **Git status icons**: Add symbols for uncommitted changes, unpushed commits
- **Multiple projects**: Cache branches for multiple repositories
- **Keyboard shortcuts**: Add keybindings to toggle status display
- **Configuration file**: Make git display optional via config file

## Conclusion

Displaying git branch name on the right side of Kitty's tab bar is achievable through Kitty's custom tab bar API. The implementation requires:

1. Switching from `tab_bar_style powerline` to `tab_bar_style custom`
2. Creating a `~/.config/kitty/tab_bar.py` file with custom drawing logic
3. Implementing right-side status display using `screen.cursor.x` positioning

The recommended approach is to start with the simple implementation (Option A), test thoroughly, and enhance with caching or async updates only if performance issues arise. The current configuration with numbered tabs can be preserved while adding the git branch display to the right side as requested.

**Estimated Implementation Time**: 15-30 minutes for Option A, 1-2 hours for Option B with testing.

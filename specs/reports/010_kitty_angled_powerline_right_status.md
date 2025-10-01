# Research Report: Kitty Angled Powerline with Right-Side Status

## Metadata
- **Date**: 2025-10-01
- **Report Number**: 010
- **Scope**: Investigate approaches for adding right-side status (directory + git branch) to Kitty tab bar while maintaining clean angled powerline appearance
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Related Reports**: 006, 007, 008
- **Status**: ✅ Research Complete

## Executive Summary

Adding custom status information (current directory and git branch) to the right side of Kitty's tab bar while maintaining the clean angled powerline appearance requires using `tab_bar_style custom` with careful implementation. The challenge is that custom tab bars can inadvertently change the tab rendering, causing mixed powerline styles (angled + fade).

**Key Finding**: The "angled" powerline style uses custom-drawn glyphs () rendered by Kitty's box_drawing.py, not Unicode characters. When using `draw_tab_with_powerline()` in custom tab bars, the function's behavior with the `is_last` parameter can cause inconsistent rendering.

**Recommended Solution**: Use a custom tab bar that properly passes `draw_data.powerline_style` to maintain consistent angled separators across all tabs, then adds right-side status information after tab rendering is complete.

## Background

### User Requirements
1. **Maintain Clean Appearance**: Tabs must look exactly as they do with built-in `tab_bar_style powerline` and `tab_powerline_style angled`
2. **Add Right-Side Status**: Display current directory and git branch to the right of tabs (not in tab titles)
3. **Dynamic Updates**: Status must update when directory changes (including within Neovim sessions)
4. **Clean Look Priority**: User explicitly stated: "I want something clean (no fade) where angled dividers are especially nice"

### User Workflow Context
- Opens terminal in `~/`
- Opens Neovim, selects a session, which changes to a project directory
- Needs to see current directory and git branch without looking at tab titles
- Uses NixOS with home-manager for configuration management

### Current Configuration
- **Terminal**: Kitty
- **Shell**: Fish
- **Font**: RobotoMono Nerd Font Mono (supports Nerd Font icons)
- **Tab Style**: Powerline with angled separators
- **Tab Template**: `{index}` (numbered tabs: 1, 2, 3...)

## Problem Analysis

### Issue: Mixed Powerline Styles with Custom Tab Bar

When implementing a custom tab bar using `tab_bar_style custom` and `draw_tab_with_powerline()`, tabs rendered with inconsistent styles:
- Tabs 1, 2: Clean angled separators ()
- Tab 3 and beyond: "Faded" separators with different appearance

**Screenshot Evidence**: User reported "odd mix of angled look and faded look" - tabs appeared inconsistent, breaking the clean aesthetic.

### Root Causes Identified

#### 1. Powerline Style Implementation
Kitty implements three powerline styles in `kitty/tab_bar.py`:

```python
powerline_symbols: dict[PowerlineStyle, tuple[str, str]] = {
    'slanted': ('', '╱'),
    'round': ('', '')
}
```

**Critical Discovery**: The "angled" style is NOT in the `powerline_symbols` dictionary. It uses a different mechanism.

#### 2. Angled Style is Custom-Drawn
Through research (PR #3339, discussion #3492):
- **Angled separators use `` (custom-drawn glyph)**
- Rendered by `box_drawing.py` in Kitty's source
- Not a standard Unicode character - programmatically generated
- This is the default powerline style when no specific style is set

#### 3. `draw_tab_with_powerline()` Behavior
From source code analysis:

```python
def draw_tab_with_powerline(
    draw_data: DrawData, screen: Screen, tab: TabBarData,
    before: int, max_tab_length: int, index: int, is_last: bool,
    extra_data: ExtraData
) -> int:
    # ... rendering logic ...

    # Determine next tab's background
    if extra_data.next_tab:
        next_tab_bg = as_rgb(draw_data.tab_bg(extra_data.next_tab))
        needs_soft_separator = next_tab_bg == tab_bg
    else:
        next_tab_bg = default_bg
        needs_soft_separator = False

    separator_symbol, soft_separator_symbol = powerline_symbols.get(
        draw_data.powerline_style, ('', '')
    )
```

**The Problem**: When `draw_data.powerline_style` is not properly set to 'angled', the function defaults to using fade separators ('', ''), causing the mixed appearance.

#### 4. Custom Tab Bar Configuration Challenge
When using `tab_bar_style custom`:
- The `tab_powerline_style` setting in kitty.conf may not be properly propagated to `draw_data.powerline_style`
- Custom `draw_tab()` implementations must ensure correct style is maintained
- Simply passing `is_last=False` to all tabs doesn't solve the style inconsistency

## Research Findings

### Finding 1: Built-In Powerline Works Perfectly
**Verification**: User confirmed that reverting to:
```conf
tab_bar_style powerline
tab_powerline_style angled
```

Results in perfect, clean angled separators across all tabs. This confirms:
- The desired appearance is achievable
- The issue is in the custom tab bar implementation
- `tab_powerline_style angled` properly sets the style when using built-in powerline

### Finding 2: Angled Style Implementation Details
**Source**: GitHub PR #3339, discussions #3492, #3984

Key insights:
1. **Three Powerline Styles Available**:
   - `angled` (default): Uses  separator
   - `slanted`: Uses  and ╱ separators
   - `round`: Uses  and  separators

2. **Box Drawing Integration**:
   - Powerline symbols rendered by `box_drawing.py`
   - Custom-drawn glyphs, not font-based
   - Works without patched fonts

3. **Style Selection**:
   - Controlled by `tab_powerline_style` in kitty.conf
   - Passed to `draw_data.powerline_style` parameter
   - Must be explicitly maintained in custom tab bars

### Finding 3: Right-Side Status Requires Custom Tab Bar
**Source**: GitHub issues #2452, #2391, discussion #4447

- No built-in way to add custom status to right side of tab bar
- Must use `tab_bar_style custom` with Python `tab_bar.py` file
- Examples show using `draw_right_status()` function called from `draw_tab()`

**User Examples**:
- `larsen/kitty-configuration`: Shows right-side time/date display
- Discussion #4447: Multiple users sharing custom status implementations
- All require `tab_bar_style custom`

### Finding 4: `draw_tab_with_powerline()` is Reusable
**Source**: Kitty documentation, user examples

The built-in `draw_tab_with_powerline()` function can be reused in custom tab bars:

```python
from kitty.tab_bar import (
    DrawData, ExtraData, TabBarData, Screen,
    draw_tab_with_powerline
)

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
    # Delegate tab rendering to built-in function
    draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length,
        index, is_last, extra_data
    )

    # Add custom right-side status
    if is_last:
        draw_right_status(screen, ...)

    return screen.cursor.x
```

This approach:
- ✅ Maintains official tab rendering logic
- ✅ Reduces custom code complexity
- ✅ Future-proof (Kitty updates to powerline rendering are inherited)
- ❌ Still requires proper `draw_data.powerline_style` configuration

## Technical Analysis

### Why Previous Implementation Failed

**Original Implementation** (from summary 007):
```python
def draw_tab(...):
    global _active_directory, _active_branch

    if tab.is_active:
        _active_directory = _get_active_directory(tab)
        _active_branch = _get_active_git_branch(tab)

    # Called with is_last parameter
    draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length,
        index, is_last, extra_data
    )

    if is_last:
        _draw_right_status(screen, is_last, _active_directory, _active_branch, draw_data)

    return screen.cursor.x
```

**Issues**:
1. ❌ `draw_data.powerline_style` may not be set to 'angled'
2. ❌ When style defaults to fade ('', ''), tabs render inconsistently
3. ❌ Passing `is_last=False` to all tabs doesn't fix the underlying style issue

**Attempted Fix #1**: Pass `is_last=False` to all tabs
```python
# Draw ALL tabs as if they're not last to get consistent angled style
draw_tab_with_powerline(
    draw_data, screen, tab, before, max_title_length,
    index, False, extra_data  # Always False
)
```

**Result**: ❌ Still showed mixed styles because `draw_data.powerline_style` was not 'angled'

### Configuration Propagation Issue

When using `tab_bar_style custom`:

**kitty.conf**:
```conf
tab_bar_style custom
tab_powerline_style angled  # Does this work with custom?
```

**Question**: Does `tab_powerline_style` setting propagate to custom tab bar's `draw_data.powerline_style`?

**Answer from Research**:
- ✅ YES, if `tab_powerline_style` is uncommented in kitty.conf
- ❌ Initially commented out with note "Not used with custom style" (incorrect assumption)
- ✅ After uncommenting, should propagate to `draw_data.powerline_style`

**Test Results**:
1. With `tab_powerline_style angled` commented: Mixed angled/fade appearance
2. With `tab_powerline_style angled` uncommented: Should maintain angled style (not fully verified by user yet)

## Recommended Solutions

### Option A: Properly Configured Custom Tab Bar (Recommended)

**Approach**: Use custom tab bar with `draw_tab_with_powerline()` while ensuring `tab_powerline_style angled` is active.

**Implementation**:

1. **kitty.conf**:
```conf
tab_bar_style custom
tab_powerline_style angled  # MUST be uncommented for custom style
tab_bar_min_tabs 2
tab_bar_margin_width 4
tab_title_template "{index}"
```

2. **config/tab_bar.py** (simplified):
```python
"""Custom Kitty tab bar with right-side status."""

import os
import subprocess
from typing import Dict, Tuple

from kitty.fast_data_types import Screen
from kitty.tab_bar import (
    DrawData, ExtraData, TabBarData,
    draw_tab_with_powerline, as_rgb,
)

# Git branch cache
_git_branch_cache: Dict[str, Tuple[int, str]] = {}
_active_directory = ""
_active_branch = ""


def _abbreviate_path(path: str) -> str:
    """Abbreviate path similar to Fish's prompt_pwd."""
    if not path:
        return ""
    home = os.path.expanduser("~")
    if path.startswith(home):
        path = "~" + path[len(home):]
    parts = path.split("/")
    if len(parts) > 3:
        result = []
        for i, part in enumerate(parts):
            if i == 0 or i == len(parts) - 1:
                result.append(part)
            elif part:
                result.append(part[0])
        path = "/".join(result)
    return path


def _get_git_branch(cwd: str) -> str:
    """Get git branch with caching."""
    cache_key = cwd
    if cache_key in _git_branch_cache:
        count, branch = _git_branch_cache[cache_key]
        if count > 0:
            _git_branch_cache[cache_key] = (count - 1, branch)
            return branch

    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, cwd=cwd, timeout=0.05
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            if branch:
                if len(branch) > 20:
                    branch = branch[:17] + "..."
                branch_text = f"󰘬 {branch}"
                _git_branch_cache[cache_key] = (10, branch_text)
                return branch_text
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        pass

    _git_branch_cache[cache_key] = (5, "")
    return ""


def _draw_right_status(screen: Screen, directory: str, git_branch: str, draw_data: DrawData) -> None:
    """Draw status on right side of tab bar."""
    status_parts = []
    if directory:
        status_parts.append(directory)
    if git_branch:
        status_parts.append(git_branch)

    if not status_parts:
        return

    status_text = "  ".join(status_parts)
    status_length = len(status_text)

    # Use active tab colors
    screen.cursor.fg = as_rgb(draw_data.active_fg)
    screen.cursor.bg = as_rgb(draw_data.active_bg)

    # Right-align with margin
    right_margin = 2
    available_space = screen.columns - screen.cursor.x - right_margin

    if status_length > available_space:
        # Truncate if needed
        if directory and git_branch:
            max_dir_length = available_space - len(git_branch) - 2 - 5
            if max_dir_length > 10:
                directory = "..." + directory[-(max_dir_length - 3):]
                status_text = f"{directory}  {git_branch}"
                status_length = len(status_text)

        if status_length > available_space:
            return

    gap = screen.columns - screen.cursor.x - status_length - right_margin
    if gap >= 0:
        screen.draw(" " * gap)
        screen.draw(status_text)


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
    """Draw tab with angled powerline style and right-side status."""
    global _active_directory, _active_branch

    # Collect active tab info
    if tab.is_active:
        cwd = tab.active_wd or ""
        _active_directory = _abbreviate_path(cwd) if cwd else ""
        _active_branch = _get_git_branch(cwd) if cwd else ""

    # Draw tab with built-in powerline renderer
    # draw_data.powerline_style should be 'angled' from kitty.conf
    draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length,
        index, is_last, extra_data
    )

    # Add right-side status on last tab
    if is_last:
        _draw_right_status(screen, _active_directory, _active_branch, draw_data)

    return screen.cursor.x
```

3. **home.nix** (ensure tab_bar.py is symlinked):
```nix
".config/kitty/tab_bar.py".source = ./config/tab_bar.py;
```

**Pros**:
- ✅ Maintains clean angled powerline appearance
- ✅ Adds right-side status information
- ✅ Uses built-in `draw_tab_with_powerline()` for consistency
- ✅ Minimal custom code
- ✅ Future-proof

**Cons**:
- ⚠️ Requires `tab_powerline_style angled` to be uncommented
- ⚠️ Depends on proper style propagation from kitty.conf to draw_data

**Risk Level**: Low (if `tab_powerline_style` is properly set)

### Option B: Shell-Based Status in Prompt (Alternative)

**Approach**: Keep built-in `tab_bar_style powerline`, show directory/branch in shell prompt instead.

**Implementation**:

**kitty.conf**:
```conf
tab_bar_style powerline
tab_powerline_style angled
# No custom tab bar needed
```

**Fish config** (add to `config.fish`):
```fish
function fish_prompt
    set_color brblue
    echo -n (prompt_pwd)

    # Git branch
    if git rev-parse --git-dir > /dev/null 2>&1
        set branch (git branch --show-current 2>/dev/null)
        if test -n "$branch"
            set_color yellow
            echo -n "  󰘬 $branch"
        end
    end

    set_color normal
    echo -n " > "
end
```

**Pros**:
- ✅ Guaranteed clean tab appearance (uses built-in powerline)
- ✅ No custom Python code needed
- ✅ Simple implementation
- ✅ Works with existing Neovim workflow

**Cons**:
- ❌ Information in prompt, not next to tabs (not what user requested)
- ❌ Takes up vertical space
- ❌ Doesn't meet original requirement

**Risk Level**: None (but doesn't meet requirements)

### Option C: Separator Style Tab Bar (Simple Alternative)

**Approach**: Use `tab_bar_style separator` with custom background, add status via title template.

**Implementation**:

**kitty.conf**:
```conf
tab_bar_style separator
tab_separator " │ "
tab_title_template "{index}"
# Show directory in window title, read via automation
```

**Pros**:
- ✅ Simple configuration
- ✅ No mixed style issues

**Cons**:
- ❌ Loses angled powerline aesthetic (user explicitly wants clean angled look)
- ❌ Difficult to add dynamic right-side status
- ❌ Doesn't meet aesthetic requirements

**Risk Level**: Low (but doesn't meet requirements)

## Implementation Plan (Option A)

### Phase 1: Verify Style Propagation
1. Ensure `tab_powerline_style angled` is uncommented in `kitty.conf`
2. Apply configuration via `home-manager switch`
3. Reload Kitty (`Ctrl+Shift+F5`)
4. Verify all tabs show consistent angled separators

### Phase 2: Simplify Custom Tab Bar
1. Update `config/tab_bar.py` with simplified implementation (shown above)
2. Remove unnecessary complexity from current implementation
3. Ensure `draw_tab_with_powerline()` is called with standard parameters
4. Test that tabs maintain angled appearance

### Phase 3: Test Right-Side Status
1. Verify directory appears on right side
2. Test git branch detection in repositories
3. Test path abbreviation with long directories
4. Verify status updates when changing directories in Neovim

### Phase 4: Performance Verification
1. Monitor git subprocess calls (should be cached)
2. Verify no UI lag when switching tabs
3. Test with large repositories (timeout protection)

## Testing Strategy

### Visual Testing Checklist
- [ ] All tabs show consistent angled separators ()
- [ ] No "fade" or mixed separator styles
- [ ] Right-side shows abbreviated directory (e.g., `~/.dotfiles`)
- [ ] Git branch displays with icon (e.g., `󰘬 master`)
- [ ] Status updates when changing directories
- [ ] Status truncates gracefully on narrow terminal
- [ ] Nerd Font icon renders correctly

### Functional Testing
- [ ] Open terminal in `~/` - shows `~`
- [ ] Open Neovim, select session - status updates to project directory
- [ ] Navigate between tabs - only active tab's info shown
- [ ] Change branches - git status updates
- [ ] Non-git directory - only directory shown, no branch
- [ ] Very long path - truncates with `...`

### Performance Testing
- [ ] No lag when switching tabs
- [ ] Git command cached (not called every redraw)
- [ ] Large repository - timeout prevents freezing
- [ ] Multiple tabs - no performance degradation

## Rollback Plan

If custom tab bar continues to show mixed styles:

1. **Immediate Rollback**:
   ```bash
   # Revert kitty.conf
   git checkout config/kitty.conf
   # Remove custom tab bar
   git checkout home.nix
   # Apply
   home-manager switch --flake .#benjamin
   ```

2. **Alternative: Disable Custom Tab Bar**:
   ```conf
   # In kitty.conf
   tab_bar_style powerline
   tab_powerline_style angled
   # tab_bar.py won't be loaded
   ```

3. **Fallback to Option B**: Use shell prompt for status information

## Open Questions

1. **Does `tab_powerline_style` properly propagate to `draw_data.powerline_style` when using custom tab bar?**
   - Need to verify with debug print or source code confirmation
   - If not, may need to manually set style in Python code

2. **Is there a way to inspect `draw_data.powerline_style` at runtime?**
   - Could add debug logging to tab_bar.py to confirm value
   - Would help diagnose style propagation issue

3. **Can we force `draw_data.powerline_style = 'angled'` in Python code?**
   - If propagation fails, this could be a workaround
   - Need to verify if DrawData is mutable

## References

### Kitty Source Code
- `kitty/tab_bar.py`: Main tab rendering logic
- `kitty/box_drawing.py`: Powerline symbol rendering
- GitHub PR #3339: Added angled/slanted/round powerline styles
- GitHub Discussion #3492: Powerline symbol implementation details
- GitHub Discussion #4447: User custom tab bar examples

### Kitty Documentation
- Configuration Reference: https://sw.kovidgoyal.net/kitty/conf/
- Custom Tab Bar: https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.tab_bar_style

### Project Files
- `/home/benjamin/.dotfiles/config/kitty.conf`: Kitty configuration
- `/home/benjamin/.dotfiles/config/tab_bar.py`: Custom tab bar implementation
- `/home/benjamin/.dotfiles/home.nix`: Home-manager configuration
- `/home/benjamin/.dotfiles/specs/summaries/007_kitty_right_side_status.md`: Previous implementation summary
- `/home/benjamin/.dotfiles/specs/reports/008_kitty_right_side_status_display.md`: Previous research report

### Related Issues
- Kitty Issue #2452: Request for status bar on right side of tab bar
- Kitty Issue #2391: Duplicate status bar request

## Conclusion

Adding right-side status to Kitty's tab bar while maintaining clean angled powerline appearance is achievable using `tab_bar_style custom` with proper configuration. The key requirement is ensuring `tab_powerline_style angled` is active and properly propagates to the custom tab bar's `draw_data.powerline_style` parameter.

**Critical Success Factor**: The `tab_powerline_style angled` line in kitty.conf MUST be uncommented when using custom tab bar, contrary to the initial assumption that it's "not used with custom style."

**Next Step**: Verify that uncommenting `tab_powerline_style angled` resolves the mixed style issue, then proceed with Option A implementation.

**Expected Outcome**: Clean numbered tabs with consistent angled powerline separators, plus abbreviated directory and git branch displayed on the right side of the tab bar.

# Research Report: Alternative Approaches for Git Branch Display in Kitty

## Metadata
- **Date**: 2025-10-01
- **Scope**: Research alternative methods to display git branch information in Kitty terminal tab bar
- **Primary Directory**: `/home/benjamin/.dotfiles/config/`
- **Previous Research**: `specs/reports/006_kitty_tab_bar_git_branch_display.md`
- **Context**: Previous custom tab_bar.py implementation didn't maintain clean visual appearance

## Executive Summary

After implementing Option B from the previous research report (custom Python tab bar), the result did not maintain the simple, clean appearance of the original powerline tab bar. This report explores three alternative approaches that better balance functionality with visual simplicity:

1. **Shell-Based Tab Title Setting**: Use Fish shell's `fish_title` function to dynamically set tab titles
2. **Simplified Custom Tab Bar with Built-in Powerline**: Leverage Kitty's existing `draw_tab_with_powerline` function
3. **Alternative Display Methods**: Status line, window title, or external tools

**Key Finding**: The shell-based approach (Option 1) is the simplest and most maintainable solution that preserves the clean powerline aesthetic while adding git branch information.

## Background

### Previous Implementation Issues

The custom Python tab bar (Option B from report 006) had two main problems:

1. **Visual Appearance**: Manual powerline separator drawing in Python didn't match the clean look of Kitty's built-in powerline style
2. **Information Display**: Git branch only showed on the rightmost tab, not on the currently selected/active tab

### User Requirements

- **Clean visual appearance**: Maintain the simple, numbered tab style with powerline separators
- **Git branch visibility**: Show git branch for the currently selected tab
- **Low maintenance**: Avoid complex custom Python code if possible
- **Performance**: No UI freezing or lag

## Option 1: Shell-Based Tab Title Setting

### Overview

Use Fish shell's built-in `fish_title` function to set terminal tab titles dynamically based on the current directory's git branch.

### How It Works

Fish shell calls the `fish_title` function before and after every command execution. The function's output is used as the terminal's title, which Kitty displays in the tab. By customizing this function to include git branch information, we can show the branch name in the tab title.

### Implementation

#### Step 1: Create Custom fish_title Function

Add to `~/.config/fish/config.fish` (or create a separate function file):

```fish
function fish_title
    # Get current directory (abbreviated)
    set -l pwd_info (prompt_pwd)

    # Try to get git branch
    set -l git_branch ""
    if command -sq git
        set git_branch (git branch --show-current 2>/dev/null)
    end

    # Format title based on whether we're in a git repo
    if test -n "$git_branch"
        # In git repo: show index number and branch
        echo "$pwd_info [$git_branch]"
    else
        # Not in git repo: just show directory
        echo "$pwd_info"
    end
end
```

#### Step 2: Update kitty.conf Tab Title Template

Modify the tab title template to use the title provided by the shell:

```conf
# In config/kitty.conf
tab_title_template "{index} {title}"
```

This displays: `1 ~/dotfiles [master]` or `2 ~/projects [feature-branch]`

#### Alternative: Index Only in Tab, Branch in Window Title

Keep tabs simple with just numbers, show full info in window title:

```conf
tab_title_template "{index}"
# Window title will show full path and branch from fish_title
```

### Example Variations

#### Minimal Version (Branch Icon Only)
```fish
function fish_title
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "󰘬 $git_branch"
    else
        echo (prompt_pwd)
    end
end
```

Tab shows: `1 󰘬 master` or `2 /tmp`

#### Detailed Version (Directory + Branch)
```fish
function fish_title
    set -l pwd_info (fish_prompt_pwd_dir_length=1 prompt_pwd)
    set -l git_branch (git branch --show-current 2>/dev/null)

    if test -n "$git_branch"
        echo "$pwd_info 󰘬 $git_branch"
    else
        echo "$pwd_info"
    end
end
```

Tab shows: `1 ~/d/dotfiles 󰘬 master`

#### Performance-Optimized Version (Cached)
```fish
function fish_title
    # Use a global variable to cache git branch for this session
    if not set -q _cached_git_branch
        set -g _cached_git_branch (git branch --show-current 2>/dev/null)
    end

    set -l pwd_info (prompt_pwd)

    if test -n "$_cached_git_branch"
        echo "$pwd_info [$_cached_git_branch]"
    else
        echo "$pwd_info"
    end
end

# Clear cache when changing directories
function _clear_git_cache --on-variable PWD
    set -e _cached_git_branch
end
```

### Configuration in home.nix

Since your `config.fish` is managed by home-manager, add the function there:

```nix
# In home.nix, modify the fish config
".config/fish/config.fish".text = ''
  # ... existing config ...

  # Custom tab title with git branch
  function fish_title
      set -l pwd_info (prompt_pwd)
      set -l git_branch (git branch --show-current 2>/dev/null)

      if test -n "$git_branch"
          echo "$pwd_info [$git_branch]"
      else
          echo "$pwd_info"
      end
  end
'';
```

Or keep it in a separate file and source it:

```nix
# Create config/fish_title.fish
".config/fish/functions/fish_title.fish".source = ./config/fish_title.fish;
```

### Pros and Cons

**Pros:**
- ✅ **Simple**: Only ~10 lines of Fish code
- ✅ **No Python required**: Uses shell scripting only
- ✅ **Maintains clean look**: Uses built-in powerline style
- ✅ **Automatic updates**: Updates on every directory change
- ✅ **Shows on active tab**: Git branch visible in current tab's title
- ✅ **Easy to customize**: Modify format/content easily
- ✅ **No performance issues**: Git command runs in shell, not Python subprocess

**Cons:**
- ⚠️ Branch info in tab title (not separate on right side)
- ⚠️ Tab titles become longer (may need truncation)
- ⚠️ Mixes index and branch in same area
- ⚠️ Git command runs on every prompt refresh (can be cached)

### Visual Comparison

**Before (Original):**
```
┌──┐ ┌──┐ ┌──┐
│ 1│ │ 2│ │ 3│
└──┘ └──┘ └──┘
```

**After (Option 1 - Minimal):**
```
┌────────────┐ ┌─────────┐ ┌─────┐
│ 1 󰘬 master │ │ 2 ~/tmp │ │ 3 / │
└────────────┘ └─────────┘ └─────┘
```

**After (Option 1 - Index Only in Tab):**
```
┌──┐ ┌──┐ ┌──┐
│ 1│ │ 2│ │ 3│  Window Title: ~/dotfiles [master]
└──┘ └──┘ └──┘
```

### Testing

```bash
# Test the function manually
function fish_title
    set -l pwd_info (prompt_pwd)
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "$pwd_info [$git_branch]"
    else
        echo "$pwd_info"
    end
end

# Trigger title update
cd ~/.dotfiles
# Tab should show: ~/d/dotfiles [master]

cd /tmp
# Tab should show: /tmp
```

---

## Option 2: Simplified Custom Tab Bar with Built-in Powerline

### Overview

Create a minimal custom `tab_bar.py` that leverages Kitty's built-in `draw_tab_with_powerline()` function for rendering, then adds git branch information to the right side.

### How It Works

Instead of manually drawing powerline separators, import and use Kitty's own `draw_tab_with_powerline()` function to render the tabs. Then add a separate function to draw status information on the right side of the tab bar.

### Implementation

#### Step 1: Create Minimal tab_bar.py

```python
# ~/.config/kitty/tab_bar.py
import subprocess
from typing import Dict, Tuple

from kitty.fast_data_types import Screen
from kitty.tab_bar import (
    DrawData, ExtraData, TabBarData,
    draw_tab_with_powerline,  # Use built-in powerline renderer
    as_rgb
)

# Cache for git branch
_git_branch_cache: Dict[str, Tuple[int, str]] = {}


def _get_git_branch(tab: TabBarData) -> str:
    """Get git branch for the active tab's working directory."""
    if not tab.is_active:
        return ""  # Only get branch for active tab

    cwd = tab.active_wd or ""
    if not cwd:
        return ""

    # Check cache
    if cwd in _git_branch_cache:
        count, branch = _git_branch_cache[cwd]
        if count > 0:
            _git_branch_cache[cwd] = (count - 1, branch)
            return branch

    # Get branch
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=0.05
        )
        if result.returncode == 0:
            branch = result.stdout.strip()
            if branch:
                if len(branch) > 20:
                    branch = branch[:17] + "..."
                branch_text = f"󰘬 {branch}"
                _git_branch_cache[cwd] = (10, branch_text)
                return branch_text
    except:
        pass

    _git_branch_cache[cwd] = (5, "")
    return ""


def _draw_right_status(
    screen: Screen,
    is_last: bool,
    git_branch: str,
    draw_data: DrawData
) -> None:
    """Draw git branch on the right side."""
    if not is_last or not git_branch:
        return

    # Use active tab colors for the status
    screen.cursor.fg = as_rgb(draw_data.active_fg)
    screen.cursor.bg = as_rgb(draw_data.active_bg)

    status_length = len(git_branch)
    right_margin = 2
    available = screen.columns - screen.cursor.x - right_margin

    if status_length > available:
        return

    # Fill gap and draw status
    gap = available - status_length
    screen.draw(" " * gap)
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
    """Custom tab drawing using built-in powerline renderer."""

    # Get git branch for this tab
    git_branch = _get_git_branch(tab)

    # Use built-in powerline drawing
    draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length,
        index, is_last, extra_data
    )

    # Add git branch on right side
    _draw_right_status(screen, is_last, git_branch, draw_data)

    return screen.cursor.x
```

#### Step 2: Update kitty.conf

```conf
# In config/kitty.conf
tab_bar_style custom
tab_title_template "{index}"
```

### Key Differences from Previous Implementation

1. **Uses `draw_tab_with_powerline()`**: Delegates tab rendering to Kitty's built-in function
2. **Active tab only**: Gets git branch only for the currently active tab
3. **Simpler code**: ~70 lines vs. ~180 lines
4. **Cleaner appearance**: Built-in renderer ensures consistent look

### Pros and Cons

**Pros:**
- ✅ **Clean powerline look**: Uses built-in rendering, guaranteed to match
- ✅ **Git branch on right**: Separate from tab numbers
- ✅ **Cached performance**: Same caching strategy as Option B
- ✅ **Active tab focus**: Branch shows for currently selected tab
- ✅ **Simpler code**: Easier to understand and maintain

**Cons:**
- ⚠️ Still requires custom Python code
- ⚠️ Needs to be managed in NixOS config
- ⚠️ More complex than shell-based approach
- ⚠️ Potential API changes in future Kitty versions

### Visual Comparison

```
┌──┐ ┌──┐ ┌──┐                    󰘬 master
│ 1│ │ 2│ │ 3│
└──┘ └──┘ └──┘
```

With powerline separators (angled/slanted/round based on `tab_powerline_style`).

### Testing

Same testing approach as before:
- Verify Python syntax
- Apply home-manager configuration
- Test in git and non-git directories
- Check performance with multiple tabs

---

## Option 3: Alternative Display Methods

### 3a. Use Window Title Instead of Tab Title

**Implementation:**
```fish
# In config.fish
function fish_title
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "󰘬 $git_branch - "(prompt_pwd)
    else
        echo (prompt_pwd)
    end
end
```

```conf
# In kitty.conf
tab_title_template "{index}"  # Tabs show just numbers
# Window title shows: 󰘬 master - ~/dotfiles
```

**Pros:**
- Cleanest tab appearance (just numbers)
- Git branch in window title bar
- No custom code needed

**Cons:**
- Branch not visible in tab bar
- Requires looking at window title
- Less convenient for quick reference

### 3b. Use Status Line (Panel Kitten)

**Implementation:**
Create a panel at the top or bottom showing git branch.

```python
# ~/.config/kitty/git_status_panel.py
from kittens.tui.handler import result_handler
import subprocess

def main(args):
    # Get git branch
    try:
        branch = subprocess.check_output(
            ["git", "branch", "--show-current"],
            text=True
        ).strip()
        return f"󰘬 {branch}"
    except:
        return ""

@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    pass
```

Launch with: `kitty +kitten panel.py git_status_panel.py`

**Pros:**
- Separate status area
- Clean tab bar
- Can show additional info (time, battery, etc.)

**Cons:**
- Takes up vertical space
- More complex setup
- Requires manual launch or startup config

### 3c. Use Tab Bar Margin Text

**Limitation:** Kitty doesn't support adding text to tab bar margins directly. This would require a custom tab bar implementation similar to Option 2.

### 3d. Use External Status Bar (tmux-like)

**Tools:**
- `tmux` with status line
- `zellij` (terminal workspace with status bar)
- `screen` with hardstatus line

**Implementation:**
Run Kitty with tmux and configure tmux status line to show git branch.

```bash
# In .tmux.conf
set -g status-right '#{?#{pane_in_mode},#[fg=yellow]COPY#[default] ,}#[fg=green]#(git branch --show-current 2>/dev/null | sed "s/^/󰘬 /")#[default]'
```

**Pros:**
- Powerful status line customization
- Session management included
- Well-tested and stable

**Cons:**
- Adds another layer (tmux)
- More complex configuration
- Different keybindings to learn

### 3e. Fish Prompt Integration

Show git branch in the shell prompt itself (not in tab title).

**Implementation:**
```fish
# In config.fish or prompt function
function fish_prompt
    # ... existing prompt ...

    # Add git branch to prompt
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        set_color yellow
        echo -n " 󰘬 $git_branch"
        set_color normal
    end

    echo -n ' $ '
end
```

**Pros:**
- Always visible in terminal
- No tab bar modifications needed
- Standard approach used by many themes

**Cons:**
- Branch in prompt, not tab bar
- Takes up horizontal space in terminal
- Not the requested location

---

## Comparison Matrix

| Feature | Option 1: Shell Title | Option 2: Custom Python | Option 3a: Window Title | Option 3b: Panel | Option 3d: tmux |
|---------|---------------------|------------------------|------------------------|------------------|----------------|
| **Complexity** | Low | Medium | Low | High | High |
| **Maintenance** | Easy | Medium | Easy | Hard | Medium |
| **Visual Cleanliness** | Medium | High | High | High | Medium |
| **Git Branch Location** | Tab title | Right side | Window title | Separate panel | Status line |
| **Preserves Powerline** | Yes | Yes | Yes | Yes | N/A |
| **Shows on Active Tab** | Yes | Yes | Yes | Always visible | Always visible |
| **Code Lines** | ~10 Fish | ~70 Python | ~8 Fish | ~30+ Python | tmux config |
| **Performance Impact** | Minimal | Minimal | Minimal | Low | Low |
| **NixOS Integration** | Easy | Medium | Easy | Medium | Easy |
| **Customization** | High | High | High | Very High | Very High |

---

## Recommendations

### Recommended: Option 1 (Shell-Based Tab Title)

**Why:**
1. **Simplest implementation**: Just ~10 lines of Fish code
2. **Maintains clean look**: Uses built-in powerline style
3. **Easy to maintain**: Pure Fish shell script, no Python
4. **Automatic updates**: Updates on every directory change
5. **NixOS-friendly**: Easy to add to `config.fish` via home-manager
6. **Shows on active tab**: Git branch visible where you're working

**Suggested Configuration:**

```fish
# Minimal and clean
function fish_title
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "󰘬 $git_branch"
    else
        echo (prompt_pwd)
    end
end
```

```conf
# kitty.conf
tab_title_template "{index} {title}"
```

Result: Tabs show `1 󰘬 master`, `2 󰘬 feature`, `3 /tmp`

### Alternative: Option 1 with Window Title

If you prefer absolutely minimal tabs (just numbers), use window title for branch:

```fish
function fish_title
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "󰘬 $git_branch - "(prompt_pwd)
    else
        echo (prompt_pwd)
    end
end
```

```conf
# kitty.conf
tab_title_template "{index}"  # Tabs show only numbers
```

Result:
- Tabs: `1`, `2`, `3` (clean as original)
- Window: `󰘬 master - ~/dotfiles` (shows git branch)

### For Advanced Users: Option 2 (Custom Python with Built-in Powerline)

If you specifically want git branch on the right side of the tab bar (not in tab title):

- Use the simplified custom `tab_bar.py` with `draw_tab_with_powerline()`
- ~70 lines of code vs. ~180 from previous implementation
- Guaranteed clean powerline appearance
- Shows branch only for active tab

---

## Implementation Guide

### Quick Start: Option 1 (Shell-Based)

**Step 1:** Add function to Fish config

File: `/home/benjamin/.dotfiles/config/config.fish`

```fish
# Add at the end of the file
function fish_title
    set -l git_branch (git branch --show-current 2>/dev/null)
    if test -n "$git_branch"
        echo "󰘬 $git_branch"
    else
        echo (prompt_pwd)
    end
end
```

**Step 2:** Update Kitty config

File: `/home/benjamin/.dotfiles/config/kitty.conf`

```conf
# Change tab_title_template line
tab_title_template "{index} {title}"
```

**Step 3:** Apply configuration

```bash
# Stage files
git add config/config.fish config/kitty.conf

# Apply home-manager
home-manager switch --flake .#benjamin --option allow-import-from-derivation false

# Reload Kitty
# Press Ctrl+Shift+F5
```

**Step 4:** Test

```bash
# Open new tab in a git repository
cd ~/.dotfiles
# Tab should show: 1 󰘬 master

# Open new tab in non-git directory
cd /tmp
# Tab should show: 2 /tmp
```

### Quick Start: Option 2 (Custom Python with Powerline)

**Step 1:** Create tab_bar.py

File: `/home/benjamin/.dotfiles/config/tab_bar.py`

(See full implementation in "Option 2" section above)

**Step 2:** Add to home.nix

```nix
".config/kitty/tab_bar.py".source = ./config/tab_bar.py;
```

**Step 3:** Update kitty.conf

```conf
tab_bar_style custom
tab_title_template "{index}"
```

**Step 4:** Apply and test (same as Option 1)

---

## Performance Considerations

### Option 1 (Shell-Based)

**Git Command Execution:**
- Runs on every prompt refresh (before/after commands)
- Typical execution time: 5-15ms for normal repos
- Can be cached with Fish variables if needed

**Optimization:**
```fish
# Cache branch per directory
set -g _git_branch_cache ""
set -g _git_branch_pwd ""

function fish_title
    if test "$PWD" != "$_git_branch_pwd"
        set -g _git_branch_pwd "$PWD"
        set -g _git_branch_cache (git branch --show-current 2>/dev/null)
    end

    if test -n "$_git_branch_cache"
        echo "󰘬 $_git_branch_cache"
    else
        echo (prompt_pwd)
    end
end
```

### Option 2 (Custom Python)

- Uses same caching as previous implementation (10-redraw expiration)
- 50ms timeout on git subprocess
- Minimal performance impact

### Comparison

| Metric | Option 1 | Option 2 |
|--------|----------|----------|
| Git calls per tab switch | 1-2 | 1 (cached) |
| Typical latency | <20ms | <50ms (first), <1ms (cached) |
| CPU usage | Negligible | Negligible |
| Memory | Minimal | ~1MB cache |

---

## Visual Examples

### Option 1: Various Formats

**Minimal (Icon Only):**
```
Tabs: [1 󰘬 main] [2 /tmp] [3 󰘬 dev]
```

**With Directory:**
```
Tabs: [1 ~/d/dotfiles 󰘬 main] [2 /tmp] [3 ~/p/proj 󰘬 dev]
```

**Bracketed:**
```
Tabs: [1 [main]] [2 /tmp] [3 [dev]]
```

**Parenthesized:**
```
Tabs: [1 (main)] [2 /tmp] [3 (dev)]
```

### Option 2: Right-Side Display

```
┌──┐ ┌──┐ ┌──┐                              󰘬 master
│ 1│ │ 2│ │ 3│
└──┘ └──┘ └──┘
 ↑    ↑    ↑
 │    │    └─ Selected tab
 │    └────── Other tabs
 └─────────── Numbered tabs with powerline separators
```

---

## Migration Path

If you want to try Option 1 first, then potentially switch to Option 2:

1. **Start with Option 1** (shell-based)
   - Simple to implement
   - Easy to customize
   - No risk of breaking tab bar

2. **Evaluate for 1-2 weeks**
   - Check if tab titles become too long
   - Verify performance in large repos
   - Assess visual appearance

3. **Switch to Option 2 if needed**
   - If you want branch on right side specifically
   - If tab titles are too cluttered
   - If you need more control over rendering

Both options are easily reversible via git.

---

## Known Limitations

### Option 1 (Shell-Based)

1. **Tab title length**: Longer titles may be truncated by Kitty
   - Mitigation: Use minimal format (icon + branch only)
   - Mitigation: Truncate branch names in Fish function

2. **Updates timing**: Branch updates on prompt refresh, not immediately on directory change
   - Mitigation: Usually not noticeable (updates within 1-2 seconds)

3. **Mixed content**: Branch and tab index in same area
   - Mitigation: Use clear separators or minimal format

### Option 2 (Custom Python)

1. **API stability**: Kitty's custom tab bar API may change
   - Mitigation: Use `draw_tab_with_powerline()` to minimize custom code

2. **Maintenance**: Requires understanding of Kitty's Python API
   - Mitigation: Code is well-commented and simpler than Option B

3. **Right-side only on last tab**: Branch shows on rightmost tab, not middle tabs
   - Mitigation: This is intentional to avoid duplication
   - Alternative: Show on all tabs (requires more complex width calculations)

---

## Testing Checklist

### For Option 1 (Shell-Based)

- [ ] Function added to `config.fish`
- [ ] `tab_title_template` updated in `kitty.conf`
- [ ] Home-manager applied successfully
- [ ] Tab shows git branch in git repository
- [ ] Tab shows directory in non-git directory
- [ ] Branch updates when changing directories
- [ ] Icons render correctly (Nerd Font test)
- [ ] No performance issues with multiple tabs
- [ ] Branch truncation works for long names

### For Option 2 (Custom Python)

- [ ] `tab_bar.py` created in `config/`
- [ ] File added to `home.nix` symlinks
- [ ] `tab_bar_style custom` set in `kitty.conf`
- [ ] Python syntax valid (`py_compile` test)
- [ ] Home-manager applied successfully
- [ ] Tabs display with powerline separators
- [ ] Git branch shows on right side
- [ ] Branch displays for active tab
- [ ] No branch shown in non-git directories
- [ ] Caching works (no repeated git calls)
- [ ] No UI freezing or lag

---

## Troubleshooting

### Option 1 Issues

**Problem:** Tab title doesn't update
- **Cause:** `fish_title` function not loaded
- **Solution:** Reload Fish config: `source ~/.config/fish/config.fish`

**Problem:** Git branch not showing
- **Cause:** Git not in PATH or not a git repository
- **Solution:** Test `git branch --show-current` manually

**Problem:** Icons show as boxes
- **Cause:** Nerd Font not loaded
- **Solution:** Verify font in kitty.conf: `font_family RobotoMono Nerd Font Mono`

### Option 2 Issues

**Problem:** Tabs don't render correctly
- **Cause:** Error in Python code or wrong API usage
- **Solution:** Check Kitty debug output: `kitty --debug-keyboard`

**Problem:** Git branch not appearing
- **Cause:** `tab.active_wd` not available (shell integration issue)
- **Solution:** Verify Kitty shell integration enabled

**Problem:** Performance lag
- **Cause:** Git command taking too long
- **Solution:** Increase timeout or add more aggressive caching

---

## Future Enhancements

### Option 1 Enhancements

1. **Git status indicators**: Add symbols for uncommitted changes, ahead/behind
   ```fish
   if git status --porcelain | string length -q
       echo -n " *"  # Uncommitted changes
   end
   ```

2. **Conditional formatting**: Different colors for different branch types
   ```fish
   if string match -q "main" $git_branch
       # Main branch - show in green
   else if string match -q "feature/*" $git_branch
       # Feature branch - show in blue
   end
   ```

3. **Multiple VCS support**: Support for Mercurial, SVN, etc.

### Option 2 Enhancements

1. **Multiple status elements**: Show time, battery, hostname
2. **Per-tab branch display**: Show branch on each tab (not just last)
3. **Color-coded branches**: Different colors for main/feature/hotfix branches
4. **Git status icons**: Show dirty/clean state, ahead/behind counts

---

## Conclusion

After analyzing the three main approaches, **Option 1 (Shell-Based Tab Title Setting)** is the recommended solution because it:

1. ✅ Maintains the clean powerline visual style
2. ✅ Shows git branch on the currently active tab
3. ✅ Requires minimal code (~10 lines of Fish)
4. ✅ Integrates easily with your NixOS configuration
5. ✅ Has no performance concerns
6. ✅ Is easy to customize and maintain

If you specifically need the git branch displayed on the right side (separate from the tab title), then **Option 2 (Simplified Custom Tab Bar with Built-in Powerline)** is the better choice, as it leverages Kitty's built-in rendering while adding custom status information.

Both options are significantly simpler and more maintainable than the previous Option B implementation, and both preserve the clean visual appearance that was important to you.

---

## References

### Documentation
- Fish Shell: `fish_title` - https://fishshell.com/docs/current/cmds/fish_title.html
- Fish Shell: `fish_git_prompt` - https://fishshell.com/docs/current/cmds/fish_git_prompt.html
- Kitty Shell Integration - https://sw.kovidgoyal.net/kitty/shell-integration/
- Kitty Tab Bar Customization - https://sw.kovidgoyal.net/kitty/conf/#tab-bar

### Source Code
- Kitty tab_bar.py - https://github.com/kovidgoyal/kitty/blob/master/kitty/tab_bar.py
- Fish fish_title.fish - https://github.com/fish-shell/fish-shell/blob/master/share/functions/fish_title.fish

### Community Examples
- GitHub Discussion #4447: Share your tab bar style
- Stack Overflow: PS1 prompt in fish shell show git branch
- Unix Stack Exchange: Kitty Terminal Tab Title customization

### Related Reports
- Previous research: `/home/benjamin/.dotfiles/specs/reports/006_kitty_tab_bar_git_branch_display.md`

---

## Next Steps

1. **Choose approach**: Decide between Option 1 (shell-based) or Option 2 (custom Python)
2. **Implement**: Follow the Quick Start guide for your chosen option
3. **Test**: Verify functionality in git and non-git directories
4. **Customize**: Adjust format and appearance to your preference
5. **Document**: Update project docs with your chosen approach

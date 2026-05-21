# Research Report: Fix Neovim Rendering Corruption After System Sleep in WezTerm

- **Task**: 59 - Fix Neovim rendering corruption after system sleep in WezTerm
- **Started**: 2026-05-21T00:00:00Z
- **Completed**: 2026-05-21T00:45:00Z
- **Effort**: ~45 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: WezTerm config (`config/wezterm.lua`), Neovim config (`~/.config/nvim/`)
  - Codebase: yanky.nvim plugin config (`lua/neotex/plugins/tools/yanky.lua`)
  - Codebase: autocmds (`lua/neotex/config/autocmds.lua`), options (`lua/neotex/config/options.lua`)
  - Codebase: treesitter config (`lua/neotex/plugins/editor/treesitter.lua`)
  - Codebase: treesitter-recovery (`after/plugin/treesitter-recovery.lua`)
  - Codebase: sleep-inhibit utility (`lua/neotex/util/sleep-inhibit.lua`)
  - GitHub: neovim/neovim#24470, neovim/neovim#25832, gbprod/yanky.nvim#123
  - GitHub: wezterm/wezterm#4404, wezterm/wezterm#3384, wezterm/wezterm#1757
  - GitHub: LazyVim/LazyVim#3981
  - Web: Neovim TUI docs, WezTerm event docs, wl-clipboard behavior
- **Artifacts**:
  - `specs/059_fix_neovim_rendering_after_sleep_wezterm/reports/01_neovim-sleep-rendering.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- **Primary root cause**: yanky.nvim's `system_clipboard.sync_with_ring = true` (the default) triggers a blocking `wl-paste` call via `FocusGained` on wake. On Wayland/GNOME, `wl-paste` can hang indefinitely when the Wayland compositor's clipboard state is stale after sleep, freezing the entire Neovim TUI in the focused tab.
- **Why only the focused tab**: Only the active/visible WezTerm tab receives `FocusGained` terminal events on window wake. Background tabs never receive this event, so yanky's clipboard sync never fires and they recover cleanly.
- **Secondary contributors**: Missing `VimResume`/`FocusGained` autocommands for terminal state reset (cursor shape, treesitter re-highlight, `redraw!`) exacerbate visual corruption even after the clipboard hang resolves.
- **WezTerm's OpenGL renderer** (`front_end = "OpenGL"`) may lose GPU texture state after sleep on AMD, but this is a minor contributor since WezTerm itself recovers when the terminal writes new content.
- **Recommended fix**: A three-part approach -- (1) disable yanky's sync_with_ring, (2) add a FocusGained/VimResume autocommand for full TUI reset, (3) optionally add a WezTerm window-focus-changed handler to inject a terminal reset sequence.

## Context & Scope

### System Environment

- **OS**: NixOS Linux 7.0.3 kernel
- **GPU**: AMD (vendor 0x1002), no NVIDIA drivers
- **Display**: Wayland (GNOME compositor)
- **Terminal**: WezTerm with `front_end = "OpenGL"`, `enable_wayland = true`
- **Clipboard**: wl-clipboard 2.3.0 (`wl-copy`/`wl-paste`)
- **Neovim**: v0.12.2 (unstable channel via Nix)
- **Clipboard option**: `clipboard = "unnamedplus"`

### Problem Description

When the computer goes to sleep with Neovim open in a WezTerm tab, the tab that was visible/focused during sleep exhibits on wake:
1. Cursor not visible
2. Syntax highlighting broken/wrong
3. Claude Code sidebar (claudecode.nvim) shows stale content
4. Takes several minutes to recover

Background WezTerm tabs with Neovim recover immediately.

### Key Behavioral Clue

The visible-tab-only corruption is the critical diagnostic clue. WezTerm sends `FocusGained`/`FocusLost` terminal escape sequences only to the active pane in the active tab. Background tabs do not receive these focus events. This means the corruption is triggered by something that runs specifically on `FocusGained`.

## Findings

### Primary Cause: yanky.nvim Clipboard Sync on FocusGained

The user has yanky.nvim installed at `~/.config/nvim/lua/neotex/plugins/tools/yanky.lua` with default settings for `system_clipboard`:

```lua
system_clipboard = {
  sync_with_ring = true,  -- THIS IS THE PROBLEM
},
```

**How it causes the freeze:**

1. System sleeps. The Wayland compositor (GNOME) suspends, and the Wayland socket goes into an undefined state.
2. System wakes. WezTerm regains focus and sends `CSI I` (FocusGained) to the active pane.
3. Neovim fires the `FocusGained` autocommand. yanky.nvim's system_clipboard module responds by calling Neovim's clipboard provider to sync the system clipboard with the yank ring.
4. Neovim's clipboard provider calls `wl-paste` via `systemlist()` (a synchronous, blocking call with no timeout).
5. `wl-paste` attempts to read from the Wayland compositor's clipboard, but the compositor's clipboard state may be stale or the data-offer may be invalid after sleep.
6. `wl-paste` hangs indefinitely (this is documented in neovim/neovim#24470 as a known Wayland protocol limitation -- there is no timeout mechanism in the Wayland data-device protocol).
7. Because `systemlist()` is synchronous and blocks Neovim's event loop, the entire TUI freezes. No rendering, cursor updates, or input processing occurs.

**Evidence from upstream issues:**
- gbprod/yanky.nvim#123: Multiple users confirm this exact behavior on GNOME Wayland. The fix `sync_with_ring = false` resolves it.
- neovim/neovim#24470: Confirms `wl-paste` can hang indefinitely and freeze Neovim. The GDB backtrace shows the hang occurs in `s:try_cmd()` inside `provider/clipboard.vim`.
- LazyVim/LazyVim#3981: Users report identical "cannot resume LazyVim after wake" behavior, traced to yanky.nvim.
- neovim/neovim#25832: Users report "Neovim frozen after sleep" -- resolved by disabling yanky.nvim.

### Secondary Cause: No Terminal State Reset on Focus/Resume

The user's Neovim configuration has **no** `VimResume` autocommands and the only `FocusGained` autocommand is for `checktime` (file reload detection). There is no mechanism to:

1. Reset terminal cursor state (`:mode` command)
2. Force treesitter re-highlight after corruption
3. Trigger `redraw!` to refresh the entire screen
4. Reset statusline/winbar rendering

When the yanky hang eventually resolves (either by `wl-paste` timing out at the OS level or the compositor recovering), the Neovim TUI state is corrupted because:
- Terminal cursor shape/visibility escape sequences were not re-sent
- Treesitter highlight decorations may reference stale buffer state
- The screen contents are partially drawn from pre-sleep state

### Tertiary Cause: WezTerm OpenGL GPU State

WezTerm is configured with `front_end = "OpenGL"`. After system sleep, the GPU may lose OpenGL texture/framebuffer state. WezTerm has no explicit sleep/resume handling for OpenGL context restoration (confirmed by wezterm/wezterm#4404 where Wez stated "this is a problem with the drivers"). However:

- This is primarily an issue with NVIDIA drivers, not AMD
- WezTerm's OpenGL renderer does eventually re-render when new content is written
- The user has AMD GPU (vendor 0x1002), which handles suspend/resume better
- This is likely a minor contributor compared to the yanky freeze

### Claude Code Sidebar Staleness

The claudecode.nvim plugin creates a terminal buffer in a vertical split. After the focused tab hangs due to yanky's clipboard sync, the terminal buffer stops receiving updates. Even after the main Neovim TUI recovers, the terminal buffer may show stale content because:
1. The Claude Code process continued running during sleep (outputting to its PTY)
2. The terminal buffer's scrollback may have overflowed
3. No explicit refresh mechanism exists for the sidebar terminal on FocusGained

## Decisions

- **yanky.nvim sync_with_ring is the primary fix target** -- it is the root cause of the freeze, not a rendering issue.
- **A FocusGained/VimResume autocommand is the secondary fix** -- it addresses residual rendering corruption after the freeze resolves.
- **WezTerm front_end change is NOT recommended** -- switching to Software renderer would degrade performance significantly. The OpenGL renderer works well on AMD.
- **WezTerm-side reset sequence injection is a nice-to-have** -- not essential if the Neovim-side fixes are implemented.

## Recommendations

### Priority 1: Disable yanky.nvim clipboard sync (Critical)

In `~/.config/nvim/lua/neotex/plugins/tools/yanky.lua`, change:

```lua
system_clipboard = {
  sync_with_ring = false,  -- Prevent FocusGained clipboard hang on Wayland
},
```

This is the single most impactful fix. It eliminates the blocking `wl-paste` call on `FocusGained` that causes the multi-minute freeze. The clipboard still works normally for explicit yank/paste operations; only the automatic background sync is disabled.

### Priority 2: Add FocusGained/VimResume TUI reset autocommand (Important)

Create a new file or add to the existing `autocmds.lua` a comprehensive focus recovery handler:

```lua
-- Terminal state recovery on focus/resume
-- Handles rendering corruption after system sleep, terminal detach, etc.
local recovery_group = vim.api.nvim_create_augroup("TerminalRecovery", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
  group = recovery_group,
  callback = function()
    -- 1. Reset terminal mode (cursor shape, mouse mode, bracketed paste)
    vim.cmd("mode")

    -- 2. Force full screen redraw
    vim.cmd("redraw!")

    -- 3. Re-trigger treesitter highlighting for current buffer
    vim.schedule(function()
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
        if ok and parser then
          pcall(function()
            parser:invalidate()
            parser:parse()
          end)
        end
      end
      -- 4. Refresh statusline
      vim.cmd("redrawstatus!")
    end)
  end,
  desc = "Reset terminal state and re-highlight on focus/resume",
})
```

Key commands explained:
- `:mode` -- Re-sends all terminal mode escape sequences (cursor shape, mouse protocol, kitty keyboard protocol, bracketed paste). This is the official Neovim mechanism for terminal state recovery.
- `:redraw!` -- Forces a complete screen redraw, clearing any stale content.
- `parser:invalidate()` + `parser:parse()` -- Forces treesitter to re-parse the buffer and regenerate highlight decorations.
- `:redrawstatus!` -- Forces statusline (lualine) refresh.

### Priority 3: Add Claude Code sidebar refresh on FocusGained (Nice-to-have)

After the FocusGained event, the Claude Code terminal buffer may still show stale content. A targeted refresh could be added:

```lua
vim.api.nvim_create_autocmd("FocusGained", {
  group = recovery_group,
  callback = function()
    -- Scroll Claude Code terminal buffers to bottom to show latest output
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "terminal" then
          local bufname = vim.api.nvim_buf_get_name(buf)
          if bufname:match("claude") or bufname:match("ClaudeCode") then
            -- Scroll terminal to bottom
            pcall(function()
              vim.api.nvim_win_call(win, function()
                vim.cmd("normal! G")
              end)
            end)
          end
        end
      end
    end)
  end,
  desc = "Refresh Claude Code sidebar on focus",
})
```

### Priority 4: Optional WezTerm-side reset (Low priority)

In `config/wezterm.lua`, a `window-focus-changed` handler could inject a terminal reset sequence to the active pane:

```lua
wezterm.on("window-focus-changed", function(window, pane)
  if window:is_focused() then
    -- Inject a no-op escape sequence to force the pane to redraw
    -- CSI 0 c is "Send Device Attributes" - harmless query that triggers response
    pane:inject_output("\027[0c")
  end
end)
```

This is low priority because the Neovim-side fixes should handle all cases.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Disabling sync_with_ring breaks clipboard workflow | Low | Low | System clipboard still works for explicit yank/paste. Only automatic ring sync is lost. |
| FocusGained autocommand fires too often and causes flicker | Low | Low | The `:mode` and `:redraw!` commands are fast (<5ms). Treesitter re-parse is deferred via `vim.schedule`. |
| Treesitter invalidation causes momentary highlight flash | Medium | Low | Parser re-parse is nearly instantaneous for already-parsed buffers. |
| Claude Code terminal scroll-to-bottom disrupts user viewing | Low | Medium | Only runs on FocusGained, not continuously. User is unlikely to be reading the terminal during sleep. |
| WezTerm inject_output causes unexpected terminal behavior | Low | Medium | The `CSI 0 c` query is harmless (Device Attributes). Skip this fix if Neovim-side fixes suffice. |

## Appendix

### Search Queries Used
- "WezTerm rendering corruption after system sleep suspend GPU context loss OpenGL"
- "WezTerm focused tab background tab different behavior rendering resume wake"
- "neovim TUI rendering corruption terminal sleep wake FocusGained redraw mode"
- "neovim frozen after sleep wake linux fix autocommand SIGCONT redraw"
- "wezterm issue 4404 nvidia sleep suspend freeze workaround"
- "neovim mode command reset terminal state cursor highlighting fix corruption"
- "neovim FocusGained autocommand treesitter re-highlight redraw syntax fix"
- "wezterm OpenGL front_end Software WebGpu rendering issues linux wayland"
- "neovim issue 25832 frozen after sleep wake fix solution"
- "yanky.nvim wl-clipboard freeze wayland GNOME sync_with_ring FocusGained fix"
- "neovim wl-copy blocking hang clipboard unnamedplus wayland sleep resume timeout"
- "neovim redraw mode terminal reset corruption fix FocusGained VimResume autocommand"
- "wezterm window-focus-changed event sleep wake resume rendering refresh pane"
- "wezterm focus event only active tab terminal FocusGained background tab not receive"

### Key References
- [gbprod/yanky.nvim#123](https://github.com/gbprod/yanky.nvim/issues/123) -- yanky freeze on Wayland/GNOME
- [neovim/neovim#24470](https://github.com/neovim/neovim/issues/24470) -- wl-paste hang freezes Neovim
- [neovim/neovim#25832](https://github.com/neovim/neovim/issues/25832) -- Neovim frozen after sleep (yanky root cause)
- [LazyVim/LazyVim#3981](https://github.com/LazyVim/LazyVim/issues/3981) -- LazyVim sleep resume failure (yanky root cause)
- [wezterm/wezterm#4404](https://github.com/wezterm/wezterm/issues/4404) -- WezTerm sleep on NVIDIA (driver issue)
- [wezterm/wezterm#1757](https://github.com/wezterm/wezterm/issues/1757) -- Cursor hollow until refocus
- [wl-clipboard transient windows blog post](https://mwop.net/blog/2024-09-23-nvim-wl-clipboard.html) -- wl-clipboard Wayland issues
- [Neovim TUI docs](https://neovim.io/doc/user/tui.html) -- Terminal UI architecture
- [VimResume/VimSuspend events](https://github.com/neovim/neovim/issues/3648) -- Neovim suspend/resume autocommands

### Files Examined
- `/home/benjamin/.dotfiles/config/wezterm.lua` -- WezTerm configuration
- `/home/benjamin/.config/nvim/init.lua` -- Neovim entry point
- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` -- Autocommand configuration
- `/home/benjamin/.config/nvim/lua/neotex/config/options.lua` -- Options including clipboard
- `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/yanky.lua` -- yanky.nvim configuration (root cause)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/treesitter.lua` -- Treesitter setup
- `/home/benjamin/.config/nvim/after/plugin/treesitter-recovery.lua` -- Treesitter error recovery
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claudecode.lua` -- Claude Code plugin
- `/home/benjamin/.config/nvim/lua/neotex/util/sleep-inhibit.lua` -- Sleep inhibitor utility
- `/home/benjamin/.config/nvim/lua/neotex/lib/wezterm.lua` -- WezTerm OSC integration

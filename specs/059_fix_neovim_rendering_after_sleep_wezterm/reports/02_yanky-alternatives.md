# Research Report: Yanky.nvim Alternatives and Custom Implementation Feasibility

**Task**: 59 - Fix Neovim rendering corruption after system sleep in WezTerm
**Started**: 2026-05-21T00:00:00Z
**Completed**: 2026-05-21T00:45:00Z
**Effort**: Medium
**Dependencies**: Round 1 research (report 01)
**Sources/Inputs**:
- Codebase: User's yanky.nvim config (`~/.config/nvim/lua/neotex/plugins/tools/yanky.lua`)
- Codebase: Installed yanky.nvim source (`~/.local/share/nvim/lazy/yanky.nvim/lua/`)
- Codebase: Neovim options/autocmds config (`~/.config/nvim/lua/neotex/config/`)
- Web: yanky.nvim GitHub repository and source code
- Web: nvim-neoclip.lua, yankbank-nvim, cutlass.nvim, vim-yoink GitHub repos
- Web: Neovim issues #24470 (wl-paste hang), yanky.nvim PR #117 (focus loop fix)
- Web: Neovim clipboard provider documentation
**Artifacts**:
- `specs/059_fix_neovim_rendering_after_sleep_wezterm/reports/02_yanky-alternatives.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The user's yanky.nvim config uses 5 of yanky's features: yank ring, enhanced put, system clipboard sync, yank highlighting, and Telescope history picker. Put cycling (the ability to cycle through yank history after pasting) is NOT configured despite being yanky's signature feature.
- No alternative plugin provides all of yanky's features AND avoids the Wayland clipboard sync bug; the root cause is `vim.fn.getreg('+')` which is synchronous and calls `wl-paste` under the hood -- this is a Neovim-level problem, not plugin-specific.
- A minimal custom implementation covering the user's actual feature usage is feasible at approximately 150-200 lines of Lua, which would be cleaner than yanky's 1620 LOC across 18 files.
- **Recommended approach**: Option D (Hybrid) -- disable yanky's `system_clipboard.sync_with_ring`, add a custom non-blocking clipboard sync using `vim.system()` with a 2-second timeout, and add `FocusGained`/`VimResume` recovery autocommands. This keeps yanky for its ring/put infrastructure while eliminating the freeze.

## Context & Scope

Round 1 research identified that yanky.nvim's `system_clipboard.sync_with_ring = true` causes a blocking `wl-paste` call on `FocusGained` after system wake on Wayland/GNOME. This round investigates: (1) which yanky features the user actually uses, (2) whether alternative plugins avoid the issue, (3) whether a custom replacement is practical, and (4) the best path forward.

## Findings

### 1. Feature Audit: What the User Actually Uses

From reading `~/.config/nvim/lua/neotex/plugins/tools/yanky.lua` and `which-key.lua`:

| Feature | Used? | Config Details |
|---------|-------|----------------|
| Yank ring (history) | Yes | 50 entries, memory storage, deduplication on |
| Enhanced put (y/p/P/gp/gP) | Yes | All 5 Plug mappings bound in keys table |
| Put cycling (cycle through history after paste) | **NO** | No `<Plug>(YankyCycleForward/Backward)` keymaps anywhere in config |
| System clipboard sync | Yes | `sync_with_ring = true` -- THIS IS THE BUG |
| Yank highlighting | Yes | `on_put = true, on_yank = true, timer = 100` |
| Telescope picker | Yes | Custom `_G.YankyTelescopeHistory()` function with previewer |
| Preserve cursor position | Yes | `enabled = true` |
| Numbered register sync | Yes | `sync_with_numbered_registers = true` |
| Text object (last put) | No | Not configured |
| Wrappers (linewise/charwise/joined) | No | No wrapper keymaps bound |

Key observation: **Put cycling is yanky's most distinctive feature, and the user does not use it.** The user also wrote a 70-line custom Telescope picker rather than using yanky's built-in Telescope extension. This suggests the user could be well served by simpler infrastructure.

Additional observations:
- The user has `clipboard = "unnamedplus"` in options.lua, meaning `"` register maps to `+` (system clipboard)
- The BufWritePre autocommand trims history to 30 entries (below the 50-entry limit)
- The VimLeavePre autocommand clears history on exit
- Which-key binds: `<leader>fy` (find yanks), `<leader>yh` (yank history), `<leader>yc` (clear history)

### 2. Alternative Plugin Comparison

| Plugin | Stars | Last Active | Ring | Cycling | Clipboard Sync | Telescope | Wayland Bug? |
|--------|-------|-------------|------|---------|----------------|-----------|-------------|
| **yanky.nvim** | ~850 | 2025-12 | Yes | Yes | Yes (FocusGained) | Yes + Snacks | **YES** - `vim.fn.getreg('+')` on FocusGained |
| **nvim-neoclip.lua** | 1.1k | Active | Yes | **No** | **No** (TextYankPost only) | Yes + fzf-lua | **No** - no FocusGained handler |
| **yankbank-nvim** | ~200 | Active | Yes | No | Optional (focus_gain_poll) | Snacks picker | **Possible** - focus_gain_poll may trigger same issue |
| **vim-yoink** | ~350 | Stale (VimScript) | Yes | Yes | No | No | No |
| **cutlass.nvim** | ~200 | Low activity | No (just cut separation) | No | No | No | No |
| **nvim-miniyank** | ~250 | Stale | Yes | No | Shared across instances | No | No |

**nvim-neoclip.lua** is the closest alternative:
- Provides yank ring + Telescope picker
- Does NOT have put cycling
- Does NOT have system clipboard sync (only captures internal yanks via TextYankPost)
- Does NOT use FocusGained, so it would avoid the Wayland bug entirely
- Missing: enhanced put mappings, yank highlighting, cursor preservation

**yankbank-nvim** has a `focus_gain_poll` option that, like yanky, checks the clipboard on FocusGained. If it uses `vim.fn.getreg('+')` internally, it would have the same blocking issue.

**None of the alternatives provide all of**: yank ring + enhanced put + yank highlighting + system clipboard sync + Telescope picker. Switching to any alternative means losing features or recreating them.

### 3. Root Cause Analysis: Why the Bug is Not Plugin-Specific

The call chain on FocusGained with yanky is:

```
WezTerm sends FocusGained escape sequence
  -> Neovim fires FocusGained autocmd
    -> yanky system_clipboard.on_focus_gained()
      -> utils.get_register_info('+')
        -> vim.fn.getreg('+')
          -> Neovim clipboard provider invokes: wl-paste --no-newline
            -> wl-paste hangs (compositor clipboard state stale after sleep)
              -> ENTIRE NEOVIM TUI FROZEN
```

The critical insight: `vim.fn.getreg('+')` is a synchronous, blocking call. When `wl-paste` hangs, there is no timeout. This is Neovim issue #24470 (open, unresolved). The wl-clipboard maintainers consider this "expected behavior" and say consuming applications should implement timeouts.

Yanky already has two mitigations:
1. **PR #117 (folke)**: Prevents focus gained/lost infinite loop where wl-paste stealing focus would trigger another FocusLost
2. **PR #235**: Wraps `vim.fn.getreg` in `pcall` to handle errors gracefully

Neither addresses the fundamental problem: a single `wl-paste` hang after sleep still blocks Neovim because `pcall` catches errors, not hangs.

### 4. Custom Implementation Feasibility

A custom replacement covering the user's actual features would need:

| Component | LOC Estimate | Complexity | Notes |
|-----------|-------------|------------|-------|
| Ring buffer (memory storage) | ~35 | Trivial | Direct copy of yanky's `storage/memory.lua` |
| History management | ~60 | Low | Push, dedup, numbered register sync |
| TextYankPost capture | ~15 | Trivial | Single autocommand |
| Yank/put highlighting | ~30 | Low | `vim.hl.on_yank` + namespace-based put highlight |
| Enhanced put mappings (p/P/gp/gP) | ~20 | Low | Thin wrappers around native put |
| Telescope picker | ~0 | None | User already has a custom 70-line picker that works |
| Non-blocking clipboard sync | ~40 | Medium | `vim.system({'wl-paste'}, {timeout=2000})` with callback |
| **Total** | **~200** | **Low-Medium** | Single file, no external dependencies |

Neovim provides enough infrastructure to build this:
- `TextYankPost` autocommand for yank detection
- `vim.fn.getreg()` / `vim.fn.setreg()` for register manipulation
- `vim.hl.on_yank()` for yank highlighting (built-in since 0.5)
- `vim.api.nvim_buf_set_mark()` + namespace highlighting for put highlighting
- `vim.system()` (since 0.10) for non-blocking subprocess execution with timeout
- Numbered registers `"1` through `"9` automatically maintain delete history natively

What would be lost by going fully custom:
- Put cycling (`<Plug>(YankyCycleForward/Backward)`) -- but user doesn't use it
- Put wrappers (linewise, charwise, joined, shift) -- user doesn't use them
- Text object for last put -- user doesn't use it
- Cursor preservation on yank -- small but nice feature (~50 LOC to implement)
- Snacks picker integration -- user uses Telescope

### 5. Non-Blocking Clipboard Sync Design

The key innovation for any solution is replacing the blocking `vim.fn.getreg('+')` with a non-blocking alternative on FocusGained:

```lua
-- Non-blocking clipboard read with timeout
local function async_clipboard_read(callback)
  vim.system(
    { 'wl-paste', '--no-newline' },
    { timeout = 2000 },  -- 2 second timeout
    function(obj)
      vim.schedule(function()
        if obj.code == 0 and obj.stdout then
          callback(obj.stdout)
        end
        -- On timeout or error: silently skip (clipboard will sync on next yank)
      end)
    end
  )
end
```

This approach:
- Never blocks the TUI event loop
- Times out after 2 seconds if `wl-paste` hangs
- Falls back gracefully (the ring still works for internal yanks)
- Can be used in a FocusGained handler OR as a replacement for yanky's system_clipboard module

### 6. Custom Clipboard Provider Alternative

An even more robust approach: define a custom `vim.g.clipboard` provider with built-in timeout protection. This would protect ALL clipboard operations, not just yanky's:

```lua
vim.g.clipboard = {
  name = 'wl-clipboard-safe',
  copy = {
    ['+'] = { 'wl-copy', '--type', 'text/plain' },
    ['*'] = { 'wl-copy', '--primary', '--type', 'text/plain' },
  },
  paste = {
    ['+'] = function()
      local result = vim.system({'wl-paste', '--no-newline'}, {timeout = 2000}):wait()
      if result.code == 0 then
        return vim.split(result.stdout, '\n')
      end
      return {''}
    end,
    ['*'] = function()
      local result = vim.system({'wl-paste', '--no-newline', '--primary'}, {timeout = 2000}):wait()
      if result.code == 0 then
        return vim.split(result.stdout, '\n')
      end
      return {''}
    end,
  },
  cache_enabled = 0,
}
```

**Caveat**: The paste functions here use `:wait()` which is still synchronous within the call, but the 2-second timeout prevents indefinite hangs. A fully async approach would require restructuring how yanky's FocusGained handler works.

## Decisions

1. **Put cycling is not a requirement** -- the user has never configured it despite yanky supporting it
2. **The Wayland clipboard hang is a Neovim-level issue** (issue #24470), not yanky-specific -- any plugin or code that calls `vim.fn.getreg('+')` during FocusGained is vulnerable
3. **nvim-neoclip.lua avoids the bug by not doing FocusGained clipboard sync**, but also does not provide enhanced put mappings or yank highlighting
4. **A full custom replacement is feasible** at ~200 LOC but provides marginal benefit over keeping yanky with a config fix
5. **The custom clipboard provider approach is the most robust** because it protects all clipboard operations system-wide, not just yanky's FocusGained handler

## Recommendations

Listed in order of preference (best first):

### Option D: Hybrid Approach (RECOMMENDED)

**Effort**: ~1 hour implementation
**Risk**: Low

1. **Disable yanky's clipboard sync**: Set `system_clipboard = { sync_with_ring = false }`
2. **Add custom clipboard provider** with timeout-protected `wl-paste` calls in `options.lua`
3. **Add FocusGained/VimResume recovery autocommand** that uses `vim.system()` to async-read the clipboard and push to yanky's ring if changed
4. **Keep all other yanky features** (ring, enhanced put, highlighting, cursor preservation)

This gives the user everything they have today minus the freeze, with minimal code changes (~50 lines of new config code).

### Option A: Keep Yanky, Minimal Fix

**Effort**: ~15 minutes
**Risk**: Low (but doesn't protect other clipboard reads)

1. Set `system_clipboard = { sync_with_ring = false }` in yanky config
2. Add `VimResume` + `FocusGained` autocommand to `:mode` (redraw) and `checktime`
3. Accept that external clipboard changes won't auto-appear in yank ring (must paste normally first)

### Option C: Full Custom Implementation

**Effort**: ~4-6 hours
**Risk**: Medium (new code to maintain, edge cases)

1. Create `~/.config/nvim/lua/neotex/plugins/tools/yank-ring.lua` (~200 LOC)
2. Ring buffer + TextYankPost capture + async clipboard sync + highlighting
3. Reuse existing custom Telescope picker (already 70 LOC in the config)
4. Delete yanky.nvim dependency

This is viable but provides little benefit over Option D. The user would own more code, and yanky.nvim handles edge cases (visual mode put, expression register, etc.) that a custom implementation would need to rediscover.

### Option B: Switch to nvim-neoclip.lua

**Effort**: ~2 hours
**Risk**: Medium (feature regression)

1. Install nvim-neoclip.lua, remove yanky.nvim
2. Remap p/P to native Neovim put (lose enhanced put behavior)
3. Add separate yank highlighting autocommand (Neovim built-in `vim.hl.on_yank()`)
4. Adapt Telescope picker to use neoclip's API

This loses enhanced put and cursor preservation. Not recommended unless the user wants to simplify their setup significantly.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Custom clipboard provider breaks OSC 52 or SSH clipboard | Low | High | Check `$WAYLAND_DISPLAY` before applying; fall back to default provider |
| `vim.system()` timeout still blocks on `:wait()` for 2 seconds | Low | Medium | Use fully async callback form for FocusGained; only use `:wait()` for explicit paste |
| Yanky.nvim update overrides fix | None | None | Fix is in user config, not plugin source |
| Future Neovim versions add native timeout for clipboard provider | Low | Positive | Would make custom provider unnecessary; easy to remove |

## Appendix

### Search Queries Used
- "neovim yank ring plugin alternative yanky.nvim 2025 2026"
- "nvim-neoclip.lua neovim clipboard manager telescope alternative"
- "yanky.nvim source code system_clipboard sync_with_ring wl-paste wayland clipboard"
- "neovim custom yank ring lua implementation TextYankPost numbered registers"
- "neovim vim.fn.getreg + wayland wl-paste blocking hang freeze"
- "neovim async clipboard read vim.fn.getreg timeout workaround wayland 2025"
- "neovim lua vim.system async wl-paste timeout clipboard non-blocking"
- "yanky.nvim FocusGained hang freeze wayland issue github"
- "neovim clipboard provider g:clipboard wl-paste timeout custom provider lua async"

### Key Source Files Examined
- `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/yanky.lua` (user config, 198 lines)
- `/home/benjamin/.config/nvim/lua/neotex/config/options.lua` (clipboard = "unnamedplus")
- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` (existing FocusGained handlers)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky.lua` (411 lines, main module)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky/system_clipboard.lua` (69 lines, THE bug location)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky/utils.lua` (80 lines, get_register_info)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky/history.lua` (85 lines, ring management)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky/storage/memory.lua` (37 lines, ring buffer)
- `/home/benjamin/.local/share/nvim/lazy/yanky.nvim/lua/yanky/highlight.lua` (67 lines, yank/put highlighting)

### References
- [Neovim issue #24470: wl-paste can hang infinitely](https://github.com/neovim/neovim/issues/24470)
- [yanky.nvim PR #117: prevent focus gained/lost loop on wayland](https://github.com/gbprod/yanky.nvim/pull/117)
- [yanky.nvim PR #184: better way of dealing with focus-stealing clipboards](https://github.com/gbprod/yanky.nvim/commit/7933856)
- [yanky.nvim PR #235: gracefully handle clipboard provider errors](https://github.com/gbprod/yanky.nvim/commit/04fc42b)
- [yanky.nvim GitHub repository](https://github.com/gbprod/yanky.nvim)
- [nvim-neoclip.lua GitHub repository](https://github.com/AckslD/nvim-neoclip.lua)
- [yankbank-nvim GitHub repository](https://github.com/ptdewey/yankbank-nvim)
- [Neovim clipboard provider documentation](https://neovim.io/doc/user/provider/)
- [Neovim vim.system() documentation](https://neovim.io/doc/user/lua/)

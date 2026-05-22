local wezterm = require("wezterm")
local config = wezterm.config_builder()
local mux = wezterm.mux
local act = wezterm.action

-- Helper function to detect the current compositor
local function detect_compositor()
  local xdg_current_desktop = os.getenv("XDG_CURRENT_DESKTOP")
  if xdg_current_desktop and xdg_current_desktop:find("GNOME") then
    return "gnome"
  end
  return "unknown"
end

-- Focus WezTerm window via GNOME Shell extension D-Bus interface
-- Uses activate-window-by-title extension to bypass Wayland focus-stealing prevention
local function focus_wezterm_window_gnome()
  local cmd = [[gdbus call --session ]] ..
    [[--dest org.gnome.Shell ]] ..
    [[--object-path /de/lucaswerkmeister/ActivateWindowByTitle ]] ..
    [[--method de.lucaswerkmeister.ActivateWindowByTitle.activateByWmClass ]] ..
    [['org.wezfurlong.wezterm' 2>/dev/null]]
  os.execute(cmd)
end

-- Start maximized (removed duplicate - only one gui-startup handler should exist)
-- Commented out to prevent double window issue
-- wezterm.on('gui-startup', function(cmd)
--   local tab, pane, window = mux.spawn_window(cmd or {})
--   window:gui_window():maximize()
-- end)

-- Removed cursor theme forcing - let system handle it
-- wezterm.on('window-focus-changed', function(window, pane)
--   local overrides = window:get_config_overrides() or {}
--   overrides.xcursor_theme = 'Adwaita'
--   window:set_config_overrides(overrides)
-- end)

-- FONT
config.font_size = 12.0
config.font = wezterm.font("RobotoMono Nerd Font Mono")

-- PERFORMANCE
-- PERFORMANCE & WAYLAND SETTINGS
config.enable_wayland = true -- Keep Wayland enabled
config.front_end = "OpenGL" -- OpenGL is more stable than WebGpu on NixOS
-- Window decorations - try NONE to let compositor handle decorations
config.window_decorations = "NONE" -- Let Wayland compositor handle decorations
-- DPI handling - let system manage this
-- config.dpi = 96  -- Commenting out to let system handle DPI
-- config.dpi_by_screen = {}
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 120
config.animation_fps = 60
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- LAYOUT
config.initial_cols = 80
config.initial_rows = 24
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
-- TAB BAR
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false

-- -- Option 1: Direct toggle_fullscreen (original approach)
-- wezterm.on('gui-startup', function(cmd)
--     local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
--     window:gui_window():toggle_fullscreen()
-- end)

-- Single gui-startup handler to maximize window
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

-- -- Option 3: Using perform_action (often more reliable)
-- wezterm.on('gui-startup', function(cmd)
--     local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
--     local gui_window = window:gui_window()
--     gui_window:perform_action(wezterm.action.ToggleFullScreen, pane)
-- end)

-- APPEARANCE
config.window_background_opacity = 0.9
config.text_background_opacity = 1.0
config.adjust_window_size_when_changing_font_size = false

-- Color scheme matching Kitty
config.colors = {
  foreground = "#d0d0d0",
  background = "#202020",
  cursor_bg = "#d0d0d0",
  cursor_fg = "#202020",
  selection_fg = "#202020",
  selection_bg = "#303030",

  ansi = {
    "#151515", -- black
    "#ac4142", -- red
    "#7e8d50", -- green
    "#e5b566", -- yellow
    "#6c99ba", -- blue
    "#9e4e85", -- magenta
    "#7dd5cf", -- cyan
    "#d0d0d0", -- white
  },
  brights = {
    "#505050", -- bright black
    "#ac4142", -- bright red
    "#7e8d50", -- bright green
    "#e5b566", -- bright yellow
    "#6c99ba", -- bright blue
    "#9e4e85", -- bright magenta
    "#7dd5cf", -- bright cyan
    "#f5f5f5", -- bright white
  },
}

-- KEYBOARD PROTOCOL
-- Enable Kitty keyboard protocol for unambiguous Ctrl+punctuation keys (e.g., <C-'>)
config.enable_kitty_keyboard = true

-- GENERAL
config.default_prog = { "fish" }
config.selection_word_boundary = " \t\n{}[]()\"'`"

-- SCROLLBACK
config.scrollback_lines = 10000
config.enable_scroll_bar = false

-- MOUSE SUPPORT
config.hide_mouse_cursor_when_typing = false -- Disabled to prevent cursor disappearing bug on Wayland
-- Let NixOS handle cursor theme through environment variables

-- Slow down scroll speed in alternate buffer (vim, less, etc.)
config.alternate_buffer_wheel_scroll_speed = 1

config.mouse_bindings = {
  -- Right click to paste
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = act.PasteFrom("Clipboard"),
  },
  -- Change selection to copy to clipboard
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
  },
  -- Middle click to paste from primary selection
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    action = act.PasteFrom("PrimarySelection"),
  },
  -- Ctrl+Click to open URLs
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
}

-- TAB BAR
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.show_tabs_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 25

-- Smaller, sleeker tab bar styling
config.window_frame = {
  font = wezterm.font({ family = "RobotoMono Nerd Font Mono", weight = "Bold" }),
  font_size = 9.0,
  active_titlebar_bg = "#202020",
  inactive_titlebar_bg = "#202020",
}

-- Tab bar colors
config.colors.tab_bar = {
  background = "#1a1a1a",

  active_tab = {
    bg_color = "#e5b566",
    fg_color = "#151515",
    intensity = "Bold",
    underline = "None",
    italic = false,
    strikethrough = false,
  },

  inactive_tab = {
    bg_color = "#202020",
    fg_color = "#808080",
    intensity = "Normal",
  },

  inactive_tab_hover = {
    bg_color = "#2a2a2a",
    fg_color = "#a0a0a0",
    italic = false,
  },

  new_tab = {
    bg_color = "#1a1a1a",
    fg_color = "#808080",
  },

  new_tab_hover = {
    bg_color = "#2a2a2a",
    fg_color = "#a0a0a0",
  },
}

-- Helper function to compute global tab position across all windows
-- Tab IDs are globally unique and assigned in creation order, so sorting them
-- gives us the global creation order. This matches TTS announcement numbering.
local function get_global_tab_position(current_tab_id)
  local ok, result = pcall(function()
    local all_tab_ids = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      for _, mux_tab in ipairs(mux_window:tabs()) do
        table.insert(all_tab_ids, mux_tab:tab_id())
      end
    end
    table.sort(all_tab_ids)
    for i, tid in ipairs(all_tab_ids) do
      if tid == current_tab_id then
        return i
      end
    end
    return nil
  end)
  return ok and result or nil
end

-- Helper function to activate a tab by its global position across all windows
-- Uses the same sorting algorithm as get_global_tab_position for consistency
-- Requires WezTerm >= 20230408 for MuxTab:activate()
local function activate_global_tab(global_position)
  return wezterm.action_callback(function(window, pane)
    -- Collect all tabs with their IDs and references
    local all_tabs = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      for _, mux_tab in ipairs(mux_window:tabs()) do
        table.insert(all_tabs, {
          tab_id = mux_tab:tab_id(),
          tab = mux_tab,
          window = mux_window,
        })
      end
    end

    -- Sort by tab_id to get global creation order (matches get_global_tab_position)
    table.sort(all_tabs, function(a, b)
      return a.tab_id < b.tab_id
    end)

    -- Find the target tab at the requested global position
    local target = all_tabs[global_position]
    if not target then
      -- No tab at this position, do nothing
      return
    end

    -- Activate the target tab
    target.tab:activate()

    -- Check if we're navigating to a different window
    local current_window_id = window:mux_window():window_id()
    local target_window_id = target.window:window_id()

    if current_window_id == target_window_id then
      -- Same window, no focus change needed
      return
    end

    -- Try WezTerm's native focus first (works on X11, may work if xdg-activation implemented)
    local gui_win = wezterm.gui.gui_window_for_mux_window(target_window_id)
    if gui_win then
      gui_win:focus()
    end

    -- Fallback to compositor-specific focus for cross-window navigation
    local compositor = detect_compositor()
    if compositor == "gnome" then
      -- Use GNOME Shell extension to focus the window
      focus_wezterm_window_gnome()
    end
  end)
end

-- Custom tab title formatting with cleaner look
-- Shows project directory name and optionally task number from Claude Code
-- Also handles Claude Code notification coloring via CLAUDE_STATUS user variable
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local edge_background = "#1a1a1a"
  local background = tab.is_active and "#e5b566" or "#202020"
  local foreground = tab.is_active and "#151515" or "#808080"

  -- Check for Claude Code notification status on inactive tabs
  -- The CLAUDE_STATUS user variable is set by .claude/hooks/wezterm-notify.sh
  -- Supports lifecycle states: needs_input, researched, planned, completed, blocked
  -- and artifact-type states: report, plan, summary, error
  if not tab.is_active then
    local active_pane = tab.active_pane
    if active_pane and active_pane.user_vars and active_pane.user_vars.CLAUDE_STATUS then
      local claude_status = active_pane.user_vars.CLAUDE_STATUS
      -- Lifecycle and artifact-type color mapping for inactive tabs
      local status_colors = {
        needs_input  = { bg = "#3a3a3a", fg = "#d0d0d0" },  -- gray (Stop hook default)
        researched   = { bg = "#2a4a2a", fg = "#d0d0d0" },  -- dark green
        planned      = { bg = "#2a2a5a", fg = "#d0d0d0" },  -- dark blue
        completed    = { bg = "#1a5a1a", fg = "#d0d0d0" },  -- bright green
        blocked      = { bg = "#5a2a2a", fg = "#d0d0d0" },  -- dark red
        researching  = { bg = "#2a4a2a", fg = "#808080" },  -- dim green (in progress)
        planning     = { bg = "#2a2a5a", fg = "#808080" },  -- dim blue (in progress)
        implementing = { bg = "#3a3a1a", fg = "#808080" },  -- dim yellow (in progress)
        -- Artifact-type states (set by postflight notification, distinct from lifecycle states)
        report       = { bg = "#1a5a2a", fg = "#d0d0d0" },  -- bright green (research artifact)
        plan         = { bg = "#1a2a5a", fg = "#d0d0d0" },  -- bright blue (plan artifact)
        summary      = { bg = "#5a4a1a", fg = "#d0d0d0" },  -- dark gold (implementation summary)
        error        = { bg = "#5a1a1a", fg = "#d0d0d0" },  -- bright red (error condition)
      }
      local colors = status_colors[claude_status]
      if colors then
        background = colors.bg
        foreground = colors.fg
      end
      -- Unknown CLAUDE_STATUS values fall through to default styling (safe degradation)
    end
  end

  -- Extract project name from current working directory
  local project_name = nil
  local active_pane = tab.active_pane
  if active_pane then
    local cwd_url = active_pane.current_working_dir
    if cwd_url then
      -- current_working_dir is a Url object; file_path gives the path string
      local cwd_path = cwd_url.file_path
      if cwd_path then
        -- Extract the last path component as project name
        project_name = cwd_path:match("([^/]+)/?$")
      end
    end
  end

  -- Fallback to pane title if cwd unavailable
  if not project_name or project_name == "" then
    if active_pane and active_pane.title then
      project_name = active_pane.title
    else
      project_name = "shell"
    end
  end

  -- Build tab title: global_position + project_name
  -- Use global tab position (matches TTS announcements), fallback to per-window index
  local tab_number = get_global_tab_position(tab.tab_id) or (tab.tab_index + 1)
  local title = tostring(tab_number) .. " " .. project_name

  -- Append task number if set via TASK_NUMBER user variable
  if active_pane and active_pane.user_vars and active_pane.user_vars.TASK_NUMBER then
    local task_num = active_pane.user_vars.TASK_NUMBER
    if task_num and task_num ~= "" then
      title = title .. " #" .. task_num
    end
  end

  -- Truncate if too long
  if #title > max_width - 2 then
    title = wezterm.truncate_right(title, max_width - 2)
  end

  -- Add separator between tabs
  local separator = tab.tab_index < #tabs - 1 and "│" or ""

  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = " " .. title .. " " },
    { Background = { Color = edge_background } },
    { Foreground = { Color = "#404040" } },
    { Text = separator },
  }
end)

-- Clear Claude notification when tab becomes active
-- Uses update-status event to track tab switches and clear CLAUDE_STATUS user variable
-- This ensures the amber notification color resets when the user views the notified tab
config.status_update_interval = 500 -- 500ms for responsive clearing

wezterm.on("update-status", function(window, pane)
  local window_id = window:window_id()
  local active_tab = window:active_tab()
  local tab_id = active_tab:tab_id()

  -- Get or initialize tracking table
  -- wezterm.GLOBAL persists across config reloads within the same WezTerm instance
  local tracking = wezterm.GLOBAL.tab_tracking or {}
  local last_active = tracking[window_id]

  if last_active ~= tab_id then
    -- Tab changed! Check if new tab has CLAUDE_STATUS and clear it
    for _, tab_pane in ipairs(active_tab:panes()) do
      local user_vars = tab_pane:get_user_vars()
      if user_vars.CLAUDE_STATUS and user_vars.CLAUDE_STATUS ~= "" then
        -- Clear the user variable via OSC escape sequence
        -- This removes lifecycle/notification coloring when the user views the tab
        tab_pane:inject_output("\027]1337;SetUserVar=CLAUDE_STATUS=\007")
      end
    end
    -- Update tracking
    tracking[window_id] = tab_id
    wezterm.GLOBAL.tab_tracking = tracking
  end
end)

-- LEADER KEY - Ctrl+Space just like Kitty
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

-- Visual bell instead of audio
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_function = "EaseIn",
  fade_in_duration_ms = 75,
  fade_out_function = "EaseOut",
  fade_out_duration_ms = 75,
  target = "CursorColor",
}

-- KEYBINDINGS
config.keys = {
  -- Fix Delete key sending ^H under kitty keyboard protocol
  { key = "Delete", action = act.SendString("\x1b[3~") },

  -- Fullscreen toggle (Alt+Enter is the WezTerm default)
  {
    key = "Enter",
    mods = "ALT",
    action = act.ToggleFullScreen,
  },

  -- Tab management with Ctrl+Space leader
  {
    key = "c",
    mods = "LEADER",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  {
    key = "k",
    mods = "LEADER",
    action = act.CloseCurrentTab({ confirm = true }),
  },
  {
    key = "n",
    mods = "LEADER",
    action = act.ActivateTabRelative(1),
  },
  {
    key = "p",
    mods = "LEADER",
    action = act.ActivateTabRelative(-1),
  },

  -- Global tab switching with Ctrl+Space + number (1-9)
  -- Navigates to the tab with that global position across ALL windows,
  -- not just the nth tab in the current window
  {
    key = "1",
    mods = "LEADER",
    action = activate_global_tab(1),
  },
  {
    key = "2",
    mods = "LEADER",
    action = activate_global_tab(2),
  },
  {
    key = "3",
    mods = "LEADER",
    action = activate_global_tab(3),
  },
  {
    key = "4",
    mods = "LEADER",
    action = activate_global_tab(4),
  },
  {
    key = "5",
    mods = "LEADER",
    action = activate_global_tab(5),
  },
  {
    key = "6",
    mods = "LEADER",
    action = activate_global_tab(6),
  },
  {
    key = "7",
    mods = "LEADER",
    action = activate_global_tab(7),
  },
  {
    key = "8",
    mods = "LEADER",
    action = activate_global_tab(8),
  },
  {
    key = "9",
    mods = "LEADER",
    action = activate_global_tab(9),
  },

  -- Font size adjustment matching Kitty
  {
    key = "=",
    mods = "CTRL|SHIFT",
    action = act.IncreaseFontSize,
  },
  {
    key = "+",
    mods = "CTRL|SHIFT",
    action = act.IncreaseFontSize,
  },
  {
    key = "-",
    mods = "CTRL|SHIFT",
    action = act.DecreaseFontSize,
  },

  -- Copy/Paste with Ctrl+Shift (leaves Ctrl+C unbound for terminal use)
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = act.CopyTo("Clipboard"),
  },
  {
    key = "v",
    mods = "CTRL|SHIFT",
    action = act.PasteFrom("Clipboard"),
  },

  -- Search mode
  {
    key = "/",
    mods = "LEADER",
    action = act.Search({ CaseSensitiveString = "" }),
  },

  -- Copy mode (vim-like scrolling)
  {
    key = "[",
    mods = "LEADER",
    action = act.ActivateCopyMode,
  },

  -- Command palette (useful for discovering commands)
  {
    key = "P",
    mods = "CTRL|SHIFT",
    action = act.ActivateCommandPalette,
  },
}

-- Enable copy on select (similar to Kitty's copy_on_select = yes)
config.selection_word_boundary = " \t\n{}[]()\"'`"

-- Smart selection patterns for double-click
config.quick_select_patterns = {
  -- URLs
  "https?://[\\w\\.-]+\\S*",
  -- File paths
  "(?:[\\w\\-\\.]+)?(?:/[\\w\\-\\.]+)+",
  -- Email addresses
  "[\\w\\.-]+@[\\w\\.-]+\\.[\\w]+",
  -- IP addresses
  "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b",
  -- Hex colors
  "#[0-9a-fA-F]{3,8}",
}

return config

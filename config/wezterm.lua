local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- FONT
config.font_size = 12.0
config.font = wezterm.font('RobotoMono Nerd Font Mono')

-- PERFORMANCE
config.enable_wayland = true
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- LAYOUT
config.initial_cols = 80
config.initial_rows = 24
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- Start in fullscreen mode
config.launch_menu = {}
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.native_macos_fullscreen_mode = false
-- Start maximized/fullscreen
wezterm.on('gui-startup', function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

-- APPEARANCE
config.window_decorations = "NONE"
config.window_background_opacity = 0.9

-- Color scheme matching Kitty
config.colors = {
  foreground = '#d0d0d0',
  background = '#202020',
  cursor_bg = '#d0d0d0',
  cursor_fg = '#202020',
  selection_fg = '#202020',
  selection_bg = '#303030',
  
  ansi = {
    '#151515', -- black
    '#ac4142', -- red
    '#7e8d50', -- green
    '#e5b566', -- yellow
    '#6c99ba', -- blue
    '#9e4e85', -- magenta
    '#7dd5cf', -- cyan
    '#d0d0d0', -- white
  },
  brights = {
    '#505050', -- bright black
    '#ac4142', -- bright red
    '#7e8d50', -- bright green
    '#e5b566', -- bright yellow
    '#6c99ba', -- bright blue
    '#9e4e85', -- bright magenta
    '#7dd5cf', -- bright cyan
    '#f5f5f5', -- bright white
  },
}

-- GENERAL
config.default_prog = { 'fish' }
config.selection_word_boundary = " \t\n{}[]()\"'`"

-- TAB BAR
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.show_tabs_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 25

-- Smaller, sleeker tab bar styling
config.window_frame = {
  font = wezterm.font({ family = 'RobotoMono Nerd Font Mono', weight = 'Bold' }),
  font_size = 9.0,
  active_titlebar_bg = '#202020',
  inactive_titlebar_bg = '#202020',
}

-- Tab bar colors
config.colors.tab_bar = {
  background = '#1a1a1a',
  
  active_tab = {
    bg_color = '#3a3a3a',
    fg_color = '#d0d0d0',
    intensity = 'Bold',
    underline = 'None',
    italic = false,
    strikethrough = false,
  },
  
  inactive_tab = {
    bg_color = '#202020',
    fg_color = '#808080',
    intensity = 'Normal',
  },
  
  inactive_tab_hover = {
    bg_color = '#2a2a2a',
    fg_color = '#a0a0a0',
    italic = false,
  },
  
  new_tab = {
    bg_color = '#1a1a1a',
    fg_color = '#808080',
  },
  
  new_tab_hover = {
    bg_color = '#2a2a2a',
    fg_color = '#a0a0a0',
  },
}

-- Custom tab title formatting with cleaner look
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local edge_background = '#1a1a1a'
  local background = tab.is_active and '#3a3a3a' or '#202020'
  local foreground = tab.is_active and '#d0d0d0' or '#808080'
  
  local title = tostring(tab.tab_index + 1)
  
  -- Add separator between tabs
  local separator = tab.tab_index < #tabs - 1 and '│' or ''
  
  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = ' ' .. title .. ' ' },
    { Background = { Color = edge_background } },
    { Foreground = { Color = '#404040' } },
    { Text = separator },
  }
end)

-- LEADER KEY - Ctrl+Space just like Kitty
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

-- KEYBINDINGS matching Kitty exactly
config.keys = {
  -- Tab management with Ctrl+Space leader (exactly like Kitty)
  {
    key = 'c',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  {
    key = 'n',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(-1),
  },

  -- Font size adjustment matching Kitty
  {
    key = '=',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '+',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.DecreaseFontSize,
  },
  
  -- Copy on select (similar to Kitty's copy_on_select)
  {
    key = 'c',
    mods = 'CTRL',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CTRL',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}

-- Enable copy on select (similar to Kitty's copy_on_select = yes)
config.selection_word_boundary = " \t\n{}[]()\"'`"

return config
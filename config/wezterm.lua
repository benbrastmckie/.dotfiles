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
config.tab_bar_at_bottom = false
config.show_tabs_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32

-- Custom tab title formatting to match Kitty's "{index}" template
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tostring(tab.tab_index + 1)
  return {
    { Background = { Color = tab.is_active and '#eee' or '#999' } },
    { Foreground = { Color = tab.is_active and '#000' or '#444' } },
    { Text = ' ' .. title .. ' ' },
  }
end)

-- KEYBINDINGS matching Kitty
config.keys = {
  -- Tab management (Ctrl+Space prefix like Kitty)
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'k',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  {
    key = 'n',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'p',
    mods = 'CTRL|SHIFT',
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
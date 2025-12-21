# Research Report: NixOS Sleep Prevention for OpenCode

**Report ID:** 017  
**Date:** 2025-12-19  
**Author:** General (AI Agent)  
**Status:** Complete

## Executive Summary

This report examines best practices for preventing system sleep/suspend on NixOS when OpenCode (or similar development tools) is actively running. The recommended approach uses **systemd inhibitor locks** via `systemd-inhibit`, which is the modern, standard Linux mechanism for preventing sleep during critical operations.

## Problem Statement

When running long-running development tasks (compilation, AI agent operations, etc.) in OpenCode, the system may automatically suspend due to inactivity, interrupting work and potentially causing data loss or incomplete operations.

## Research Findings

### 1. systemd Inhibitor Locks (Recommended)

**Overview:**  
systemd provides a built-in mechanism called "inhibitor locks" that allows applications to prevent system sleep, shutdown, or idle states. This is the modern, standard approach used by most Linux applications.

**Key Features:**
- **Lock Types:** `sleep`, `shutdown`, `idle`, `handle-power-key`, `handle-suspend-key`, `handle-hibernate-key`, `handle-lid-switch`
- **Lock Modes:**
  - `block`: Prevents operation entirely until lock is released
  - `delay`: Delays operation temporarily (up to `InhibitDelayMaxSec` configured in logind.conf)
  - `block-weak`: Like block, but has no effect on operations by root or lock owner

**How It Works:**
1. Application calls `systemd-inhibit` with desired lock type
2. systemd-logind manages the lock via D-Bus API
3. Lock is automatically released when the process exits or file descriptor is closed
4. System respects the lock and won't suspend while active

**Command-Line Usage:**
```bash
# Prevent sleep while running a command
systemd-inhibit --what=sleep:idle --who="OpenCode" --why="AI agent processing" --mode=block <command>

# Example with opencode
systemd-inhibit --what=sleep:idle --who="OpenCode" --why="Development session active" opencode
```

**Advantages:**
- ✅ Standard Linux mechanism (part of systemd)
- ✅ Automatically releases lock when process exits
- ✅ No additional packages required
- ✅ Works with all desktop environments
- ✅ Respects user privileges and polkit policies
- ✅ Can be monitored with `systemd-inhibit --list`

**Disadvantages:**
- ⚠️ Requires wrapping the command or modifying how it's launched
- ⚠️ Only prevents sleep while the specific process is running

### 2. NixOS Power Management Configuration

**Global Sleep Disable (Not Recommended for This Use Case):**

You can disable sleep entirely in NixOS configuration:

```nix
systemd.sleep.extraConfig = ''
  AllowSuspend=no
  AllowHibernation=no
  AllowHybridSleep=no
  AllowSuspendThenHibernate=no
'';
```

**Advantages:**
- ✅ Simple configuration
- ✅ Guaranteed to prevent sleep

**Disadvantages:**
- ❌ Disables sleep globally, not just during OpenCode sessions
- ❌ Reduces power efficiency when not working
- ❌ Not suitable for laptops
- ❌ Defeats the purpose of power management

### 3. Conditional Power Management via udev Rules

**Overview:**  
Create udev rules that detect when on AC power vs battery and adjust power settings accordingly.

**Example Approach:**
```nix
services.udev.extraRules = ''
  # On AC power, disable auto-suspend
  SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/path/to/script disable-autosuspend"
  # On battery, enable auto-suspend
  SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/path/to/script enable-autosuspend"
'';
```

**Advantages:**
- ✅ Automatically adjusts based on power source
- ✅ Good for laptops

**Disadvantages:**
- ❌ Requires custom scripts
- ❌ Not specific to OpenCode running
- ❌ May still suspend on AC if idle timeout is reached

### 4. Desktop Environment Power Settings

**Overview:**  
Most desktop environments (GNOME, KDE, Xfce) have their own power management that can inhibit systemd's sleep handling.

**Current System Status (from `systemd-inhibit --list`):**
```
GNOME Shell is currently taking inhibitor locks:
- sleep (GNOME needs to lock the screen) - delay mode
- handle-power-key/suspend-key/hibernate-key - block mode
```

**Advantages:**
- ✅ GUI configuration available
- ✅ Integrates with desktop environment

**Disadvantages:**
- ❌ Desktop-environment specific
- ❌ Not programmatically controllable for specific applications
- ❌ May conflict with systemd settings

### 5. Caffeine-like Tools

**Overview:**  
Tools like `caffeine` or `caffeinate` that prevent sleep while running.

**Available in nixpkgs:**
- `caffeine-ng` (GNOME/GTK)
- Manual systemd-inhibit wrapper scripts

**Advantages:**
- ✅ Simple toggle on/off
- ✅ System tray integration

**Disadvantages:**
- ❌ Requires manual activation/deactivation
- ❌ Not automatic based on OpenCode running
- ❌ Additional package dependency

## Recommended Solution

### Option A: Wrapper Script (Recommended)

Create a wrapper script that launches OpenCode with systemd-inhibit:

**File: `~/.local/bin/opencode-nosleep` or add to NixOS config**

```bash
#!/usr/bin/env bash
systemd-inhibit \
  --what=sleep:idle \
  --who="OpenCode" \
  --why="Development session active" \
  --mode=block \
  opencode "$@"
```

**NixOS Configuration:**

```nix
# In home.nix or configuration.nix
environment.systemPackages = with pkgs; [
  (pkgs.writeScriptBin "opencode-nosleep" ''
    #!/usr/bin/env bash
    exec ${pkgs.systemd}/bin/systemd-inhibit \
      --what=sleep:idle \
      --who="OpenCode" \
      --why="Development session active" \
      --mode=block \
      opencode "$@"
  '')
];
```

**Usage:**
```bash
# Instead of: opencode
# Use: opencode-nosleep
```

### Option B: Desktop Entry Modification

Modify the OpenCode desktop entry to always use systemd-inhibit:

```nix
# In home.nix
xdg.desktopEntries.opencode-nosleep = {
  name = "OpenCode (No Sleep)";
  genericName = "AI-Powered Code Editor";
  exec = "systemd-inhibit --what=sleep:idle --who=OpenCode --why='Development session' opencode %F";
  terminal = false;
  categories = [ "Development" "TextEditor" ];
  icon = "code";
};
```

### Option C: Process Detection Service (Advanced)

Create a systemd user service that monitors for OpenCode processes and takes inhibitor locks:

```nix
systemd.user.services.opencode-sleep-inhibitor = {
  Unit = {
    Description = "Prevent sleep while OpenCode is running";
  };
  Service = {
    Type = "simple";
    ExecStart = pkgs.writeScript "opencode-inhibitor" ''
      #!/usr/bin/env bash
      while true; do
        if pgrep -x opencode > /dev/null; then
          ${pkgs.systemd}/bin/systemd-inhibit \
            --what=sleep:idle \
            --who="OpenCode Monitor" \
            --why="OpenCode is running" \
            --mode=block \
            sleep infinity &
          INHIBIT_PID=$!
          
          # Wait for OpenCode to exit
          while pgrep -x opencode > /dev/null; do
            sleep 5
          done
          
          # Kill the inhibitor
          kill $INHIBIT_PID 2>/dev/null
        fi
        sleep 10
      done
    '';
    Restart = "always";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

## Implementation Comparison

| Approach | Complexity | Automatic | Power Efficient | Recommended |
|----------|-----------|-----------|-----------------|-------------|
| Wrapper Script | Low | No (manual launch) | Yes | ⭐⭐⭐⭐ |
| Desktop Entry | Low | Yes (if launched via GUI) | Yes | ⭐⭐⭐⭐⭐ |
| Process Monitor Service | High | Yes | Yes | ⭐⭐⭐ |
| Global Sleep Disable | Very Low | Yes | No | ⭐ |
| AC/Battery udev Rules | Medium | Yes | Partial | ⭐⭐ |

## Best Practices

1. **Use `systemd-inhibit` over global sleep disable** - More granular control
2. **Prefer `block` mode over `delay`** - Ensures sleep is prevented, not just delayed
3. **Inhibit both `sleep` and `idle`** - Prevents both manual and automatic sleep
4. **Monitor active locks** - Use `systemd-inhibit --list` to verify
5. **Consider power source** - On laptops, you may want different behavior on battery
6. **Document the wrapper** - Make it clear why the wrapper exists

## Security Considerations

- Inhibitor locks require appropriate polkit permissions
- Default polkit policy allows users to take inhibitor locks for their own session
- No additional privileges needed for the recommended solutions
- Locks are automatically released when process exits (fail-safe)

## Testing Recommendations

1. **Verify inhibitor lock is taken:**
   ```bash
   opencode-nosleep &
   systemd-inhibit --list | grep -i opencode
   ```

2. **Test sleep prevention:**
   - Launch OpenCode with wrapper
   - Attempt manual suspend: `systemctl suspend`
   - Should be blocked or delayed

3. **Test automatic release:**
   - Close OpenCode
   - Verify lock is released: `systemd-inhibit --list`

## Alternative Considerations

### For Non-systemd Systems
If not using systemd (unlikely on NixOS), alternatives include:
- `xdg-screensaver` (X11 only)
- `xset` commands (X11 only)
- `caffeinate` (macOS-style tool)

### For Wayland Compositors
Most Wayland compositors respect systemd inhibitor locks, but some may have their own mechanisms:
- Sway: Uses systemd-logind
- Hyprland: Respects systemd inhibitors
- GNOME/KDE: Full systemd integration

## Option D: Neovim Keymap Toggle (User-Controlled)

### Overview

Instead of wrapping OpenCode or automatically detecting processes, you can create a Neovim keymap that allows you to manually toggle system-wide sleep inhibition on and off. This gives you complete control over when sleep prevention is active.

### How It Works

1. Neovim runs a background `systemd-inhibit` process when you enable the lock
2. The process ID is stored in a Lua variable
3. Toggling off kills the inhibitor process
4. The lock is automatically released when Neovim exits (fail-safe)

### Implementation

**Lua Configuration (add to your Neovim config):**

```lua
-- ~/.config/nvim/lua/sleep-inhibit.lua or in your init.lua

local M = {}

-- Store the inhibitor job ID
M.inhibit_job_id = nil
M.is_active = false

-- Start sleep inhibitor
function M.enable()
  if M.is_active then
    vim.notify("Sleep inhibitor already active", vim.log.levels.INFO)
    return
  end

  -- Start systemd-inhibit in the background
  M.inhibit_job_id = vim.fn.jobstart({
    'systemd-inhibit',
    '--what=sleep:idle',
    '--who=Neovim',
    '--why=Development session active',
    '--mode=block',
    'sleep', 'infinity'
  }, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 and exit_code ~= 143 then  -- 143 = SIGTERM (normal)
        vim.notify("Sleep inhibitor exited unexpectedly", vim.log.levels.WARN)
      end
      M.is_active = false
      M.inhibit_job_id = nil
    end
  })

  if M.inhibit_job_id > 0 then
    M.is_active = true
    vim.notify("Sleep inhibitor enabled", vim.log.levels.INFO)
  else
    vim.notify("Failed to start sleep inhibitor", vim.log.levels.ERROR)
  end
end

-- Stop sleep inhibitor
function M.disable()
  if not M.is_active or not M.inhibit_job_id then
    vim.notify("Sleep inhibitor not active", vim.log.levels.INFO)
    return
  end

  vim.fn.jobstop(M.inhibit_job_id)
  M.is_active = false
  M.inhibit_job_id = nil
  vim.notify("Sleep inhibitor disabled", vim.log.levels.INFO)
end

-- Toggle sleep inhibitor
function M.toggle()
  if M.is_active then
    M.disable()
  else
    M.enable()
  end
end

-- Get current status
function M.status()
  if M.is_active then
    vim.notify("Sleep inhibitor: ACTIVE", vim.log.levels.INFO)
  else
    vim.notify("Sleep inhibitor: INACTIVE", vim.log.levels.INFO)
  end
end

-- Cleanup on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if M.is_active then
      M.disable()
    end
  end,
  desc = "Cleanup sleep inhibitor on exit"
})

return M
```

**Keymap Configuration:**

```lua
-- In your init.lua or keymaps.lua

local sleep_inhibit = require('sleep-inhibit')

-- Toggle sleep inhibitor with <leader>si
vim.keymap.set('n', '<leader>si', sleep_inhibit.toggle, {
  desc = 'Toggle sleep inhibitor'
})

-- Check status with <leader>ss
vim.keymap.set('n', '<leader>ss', sleep_inhibit.status, {
  desc = 'Check sleep inhibitor status'
})

-- Explicit enable/disable (optional)
vim.keymap.set('n', '<leader>se', sleep_inhibit.enable, {
  desc = 'Enable sleep inhibitor'
})
vim.keymap.set('n', '<leader>sd', sleep_inhibit.disable, {
  desc = 'Disable sleep inhibitor'
})
```

### Usage

1. **Toggle on/off:** Press `<leader>si` (default: `\si` or `,si` depending on your leader key)
2. **Check status:** Press `<leader>ss` to see if inhibitor is active
3. **Automatic cleanup:** Inhibitor is automatically disabled when you exit Neovim

### Advantages

- ✅ **User control:** You decide when to prevent sleep
- ✅ **Visual feedback:** Notifications show current state
- ✅ **Fail-safe:** Automatically cleans up on Neovim exit
- ✅ **No wrapper needed:** Works with any Neovim launch method
- ✅ **Flexible:** Can be enabled/disabled mid-session
- ✅ **Lightweight:** Single background process, minimal overhead

### Disadvantages

- ⚠️ **Manual activation:** You must remember to toggle it on
- ⚠️ **Neovim-specific:** Only works when using Neovim, not other editors
- ⚠️ **Requires systemd:** Won't work on non-systemd systems

### Enhanced Version with Status Line Integration

For better visibility, you can add the inhibitor status to your status line:

```lua
-- Add to your statusline configuration (e.g., lualine)

-- For lualine:
require('lualine').setup {
  sections = {
    lualine_x = {
      function()
        local sleep_inhibit = require('sleep-inhibit')
        if sleep_inhibit.is_active then
          return '󰒲 NoSleep'  -- Icon + text
        end
        return ''
      end,
      'encoding',
      'fileformat',
      'filetype'
    }
  }
}

-- For a simple custom statusline:
vim.o.statusline = '%<%f %h%m%r%=%{v:lua.require("sleep-inhibit").is_active ? "󰒲 " : ""}%-14.(%l,%c%V%) %P'
```

### NixOS Integration

Add systemd to your Neovim's runtime path in your NixOS config:

```nix
# In home.nix
programs.neovim = {
  enable = true;
  extraPackages = with pkgs; [
    systemd  # Ensures systemd-inhibit is available
  ];
};
```

### Testing

1. **Start Neovim and enable inhibitor:**
   ```vim
   :lua require('sleep-inhibit').enable()
   ```

2. **Verify in another terminal:**
   ```bash
   systemd-inhibit --list | grep -i neovim
   ```
   
   Should show:
   ```
   Neovim  1000  youruser  12345  systemd-inhibit  sleep:idle  Development session active  block
   ```

3. **Test toggle:**
   - Press `<leader>si` to enable
   - Press `<leader>si` again to disable
   - Check with `systemd-inhibit --list` each time

4. **Test auto-cleanup:**
   - Enable inhibitor
   - Exit Neovim (`:q`)
   - Verify lock is gone: `systemd-inhibit --list`

### Alternative: D-Bus Integration (Advanced)

For a more sophisticated approach, you can use Neovim's Lua to interact directly with systemd's D-Bus API:

```lua
-- Requires lua-dbus or similar library
-- This is more complex but doesn't require spawning a process

local M = {}
local dbus = require('dbus_proxy')  -- Example, actual library may vary

function M.enable_via_dbus()
  local bus = dbus.Proxy:new({
    bus = dbus.Bus.SYSTEM,
    name = 'org.freedesktop.login1',
    interface = 'org.freedesktop.login1.Manager',
    path = '/org/freedesktop/login1'
  })
  
  -- Call Inhibit method
  local fd = bus:Inhibit('sleep:idle', 'Neovim', 'Development session', 'block')
  M.inhibit_fd = fd
  
  vim.notify("Sleep inhibitor enabled via D-Bus", vim.log.levels.INFO)
end

-- Note: This requires additional Lua libraries and is more complex
-- The jobstart approach above is simpler and more portable
```

## Conclusion

**Recommended Implementation:**  
For maximum flexibility, use **Option D (Neovim Keymap Toggle)** if you want manual control, or **Option B (Desktop Entry)** for automatic behavior. The Neovim approach is ideal for users who:
- Want fine-grained control over when sleep is prevented
- Work in terminal-based environments
- Prefer keyboard-driven workflows
- Want visual feedback in their editor

For automatic "set and forget" behavior, use the wrapper script or desktop entry approach.

**Comparison of All Options:**

| Approach | Control | Automatic | Visibility | Recommended For |
|----------|---------|-----------|------------|-----------------|
| Wrapper Script | Low | No | None | Simple use cases |
| Desktop Entry | Low | Yes | None | GUI users |
| Process Monitor | None | Yes | None | Advanced automation |
| **Neovim Toggle** | **High** | **No** | **High** | **Terminal users, manual control** |

**Next Steps:**
1. Choose your preferred approach based on workflow
2. For Neovim toggle: Add Lua module and keymaps to your config
3. For wrapper/desktop: Add configuration to `home.nix` or `configuration.nix`
4. Test with `systemd-inhibit --list`
5. Document for other users

## References

- [systemd Inhibitor Locks Documentation](https://systemd.io/INHIBITOR_LOCKS/)
- [systemd-inhibit(1) Manual](https://man.archlinux.org/man/systemd-inhibit.1)
- [NixOS Power Management Wiki](https://nixos.wiki/wiki/Power_Management)
- [Arch Linux Power Management](https://wiki.archlinux.org/title/Power_management)
- [logind.conf(5) Manual](https://man.archlinux.org/man/logind.conf.5)

## Appendix: Current System Inhibitors

From `systemd-inhibit --list` on the research system:

```
WHO            UID  USER     PID  COMM            WHAT                                                     WHY                                       MODE
ModemManager   0    root     1914 ModemManager    sleep                                                    ModemManager needs to reset devices       delay
NetworkManager 0    root     1307 NetworkManager  sleep                                                    NetworkManager needs to turn off networks delay
UPower         0    root     2094 upowerd         sleep                                                    Pause device polling                      delay
GNOME Shell    1000 benjamin 2496 .gnome-shell-wr sleep                                                    GNOME needs to lock the screen            delay
GNOME Shell    1000 benjamin 2496 .gnome-shell-wr sleep                                                    GNOME needs to save screen time data      delay
benjamin       1000 benjamin 2624 .gsd-media-keys handle-power-key:handle-suspend-key:handle-hibernate-key GNOME handling keypresses                 block
benjamin       1000 benjamin 2624 .gsd-media-keys sleep                                                    GNOME handling keypresses                 delay
benjamin       1000 benjamin 2626 .gsd-power-wrap sleep                                                    GNOME needs to lock the screen            delay
```

This shows that GNOME is already using inhibitor locks extensively, confirming this is the standard mechanism on the system.

# Power management, udev rules, battery suspend backstop, OOM handling, swap,
# zram, and VM parameters.
{ pkgs, lib, ... }:
{
  # Power management configuration for Ryzen AI 300
  # cpuFreqGovernor removed - power-profiles-daemon manages governor dynamically
  # Setting both causes a conflict where PPD's powersave is overridden on boot
  powerManagement = {
    enable = true;
  };

  services = {
    # Power profiles daemon for Waybar integration and system-wide power management
    power-profiles-daemon.enable = true;

    # ==========================================================================
    # Automatic Power Profile Switching - AC vs Battery
    # ==========================================================================
    # The HX 370 at "balanced" platform profile can draw 45W+ and runs the fan
    # continuously. Switching to "low-power" on battery: reduces CPU TDP, limits
    # boost, and significantly quiets the fan (GPU+CPU both power-gate more).
    #
    # Implementation: udev rules write directly to the ACPI platform_profile sysfs
    # node on AC state change. We do NOT call powerprofilesctl because udev rules
    # run outside the D-Bus session. PPD will not override these sysfs writes.
    #
    # The GPU DPM performance level is also set per ArchWiki Framework 13 guidance:
    # https://wiki.archlinux.org/title/Framework_Laptop_13
    # ==========================================================================
    udev.extraRules = lib.mkAfter ''
      # On battery: low-power platform profile + GPU low performance level
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="${pkgs.bash}/bin/bash -c 'echo low-power > /sys/firmware/acpi/platform_profile'"
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="${pkgs.bash}/bin/bash -c 'echo low > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level'"
      # On AC: balanced platform profile + GPU auto performance level
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="${pkgs.bash}/bin/bash -c 'echo balanced > /sys/firmware/acpi/platform_profile'"
      SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="${pkgs.bash}/bin/bash -c 'echo auto > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level'"
    '';

    # Firmware updates via fwupd - recommended for Framework laptops.
    # BIOS >= 3.05 is required to fix standby power drain (Framework community).
    # Run: fwupdmgr refresh && fwupdmgr update
    fwupd.enable = true;

    # ==========================================================================
    # Lid-Close Behavior - Lock and Blank, Never Suspend
    # ==========================================================================
    # Lid close must never suspend: long-running headless workloads (AI agents,
    # builds) keep running with the lid shut and no external monitors.
    #
    # Why "lock" and not "ignore": mutter deliberately keeps the internal eDP
    # panel ACTIVE when it is the only monitor and the lid closes (it refuses to
    # leave the session with zero outputs - see MONITOR_MATCH_ALLOW_FALLBACK and
    # find_primary_monitor's "except if no other alternatives exist"). Under
    # "ignore" the panel therefore stays lit inside the closed lid until the
    # 5-minute idle blank, and re-lights when undocking with the lid shut.
    # logind's "lock" action never suspends, and GNOME powers the panel off
    # ~30s after locking (gsd-power SCREENSAVER_TIMEOUT_BLANK), which gives us
    # blank-but-awake. swayidle's existing lock handler covers the niri session.
    #
    # - HandleLidSwitch: covers battery / unspecified power state.
    # - HandleLidSwitchExternalPower: covers AC (systemd default inherits
    #   HandleLidSwitch; set explicitly to be robust to upstream changes).
    # - HandleLidSwitchDocked is deliberately NOT set: it already defaults to
    #   "ignore" (docked = docking station OR >1 display), and while docked
    #   gsd-power's handle-lid-switch block inhibitor makes these settings moot
    #   anyway - so external-monitor behavior is preserved exactly (windows
    #   stay on external displays, no lock on lid close).
    #
    # Note: sleep inhibitors (e.g. Claude Code's sleep:idle) do NOT block the
    # lid action (LidSwitchIgnoreInhibited=yes is the logind default), so this
    # config is the only reliable lid protection.
    # See docs/no-sleep-agents.md.
    # ==========================================================================
    logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
    };
  };

  systemd = {
    services = {
      # Apply the correct profile at boot based on current AC state
      init-power-profile = {
        description = "Set initial power profile based on AC state";
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'if [ \"$(cat /sys/class/power_supply/ACAD/online)\" = \"1\" ]; then echo balanced > /sys/firmware/acpi/platform_profile; echo auto > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level; else echo low-power > /sys/firmware/acpi/platform_profile; echo low > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level; fi'";
        };
      };

      # ========================================================================
      # Battery Suspend Backstop - fires REGARDLESS of sleep inhibitors
      # ========================================================================
      # Claude Code sessions hold logind block inhibitors (sleep:idle). On
      # systemd 260 a strong block inhibitor makes logind reject ALL ordinary
      # sleep requests outright - including UPower's own 2% CriticalPowerAction
      # (verified from source; see specs/117_laptop_lid_close_no_sleep_headless/
      # reports/03_battery-level-backstop.md). Without this unit, a lid-closed
      # laptop with active agents drains to 0% and hard-powers-off.
      # `systemctl suspend -i` = SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS),
      # which root is polkit-authorized to use; the timer retries every minute
      # so it cannot be raced by a freshly acquired inhibitor.
      #
      # Re-suspend loop is INTENTIONAL, not an oversight: after any wake that is
      # still <=10% and Discharging, the next tick (<=60s, worst case ~2min
      # under the default timer AccuracySec=1min coalescing) suspends again.
      # Each cycle costs little battery and s2idle at <=10% survives hours - the
      # loop IS the protection. No threshold-band hysteresis (e.g. re-allow at
      # 15%): it would only lengthen awake time below 10% with nothing to damp
      # (the machine is suspended, not flapping a service). Escape hatches:
      #   - plug in (status leaves "Discharging"), or
      #   - systemctl stop battery-suspend-backstop.timer for a deliberate
      #     low-battery session (re-enabled at next boot/switch).
      #
      # The status check is the AC gate (live strings on this host: "Not
      # charging" / "Charging" on AC or dock, "Discharging" on battery). Do NOT
      # add ConditionACPower - it duplicates the gate with subtly different
      # multi-supply semantics; the sysfs check is authoritative.
      # Glob BAT* ONLY - never power_supply/*: this host has a peripheral
      # hid-*-battery reporting perpetual "Discharging 100" that must not match.
      # See docs/no-sleep-agents.md.
      # ========================================================================
      battery-suspend-backstop = {
        description = "Suspend at <=10% battery, bypassing sleep inhibitors";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "battery-suspend-backstop" ''
            threshold=10
            for bat in /sys/class/power_supply/BAT*; do
              [ -e "$bat/capacity" ] || continue
              status=$(cat "$bat/status")
              cap=$(cat "$bat/capacity")
              if [ "$status" = "Discharging" ] && [ "$cap" -le "$threshold" ]; then
                echo "battery at ''${cap}% and discharging: suspending (inhibitors bypassed)"
                exec ${pkgs.systemd}/bin/systemctl suspend -i
              fi
            done
          '';
        };
      };
    };

    timers.battery-suspend-backstop = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "60s";
      };
    };

    # ==========================================================================
    # Memory Management - Disable systemd-oomd (earlyoom preferred)
    # ==========================================================================
    # systemd-oomd conflicts with earlyoom. earlyoom is more configurable and
    # provides desktop notifications. Disabling systemd-oomd to avoid dual OOM
    # killer confusion.
    #
    # See: specs/39_analyze_memory_logs_optimize_system
    # ==========================================================================
    oomd.enable = false;
  };

  # ==========================================================================
  # Memory Management - earlyoom for OOM Prevention
  # ==========================================================================
  # earlyoom monitors memory usage and kills processes before the system
  # becomes unresponsive due to memory exhaustion. It operates in userspace
  # before the kernel OOM killer, providing faster and more controllable
  # intervention.
  #
  # See: specs/26_memory_monitoring_systemd_services_nixos
  # ==========================================================================
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10; # Kill process when free RAM drops below 10%
    freeSwapThreshold = 10; # Also consider swap usage
    enableNotifications = true; # Send desktop notifications when process is killed
    extraArgs = [
      "--avoid"
      "^(gnome-shell|Xwayland|niri)$" # Avoid killing desktop essentials
      "--prefer"
      "^(lean|lake|claude|node|npm|opencode)$" # Prefer killing memory-heavy processes first
    ];
  };

  # ==========================================================================
  # Swap Configuration - Memory Safety Buffer
  # ==========================================================================
  # Three-tier memory management:
  # 1. Normal operation: Applications use RAM freely
  # 2. Memory pressure: Kernel moves inactive pages to swap
  # 3. Critical: earlyoom terminates memory-hungry processes at 10% free
  #
  # 16GB swap provides buffer before earlyoom intervention, especially useful
  # for memory spikes from development tools (Claude, Node.js, browsers).
  #
  # Note: For hibernation support, swap must be >= RAM size (32GB+).
  # Current configuration is for memory safety only, not hibernation.
  #
  # See: specs/25_configure_swap_space_nixos
  # ==========================================================================
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024; # 16GB in MiB
      discardPolicy = "once"; # TRIM on activation for SSD optimization
    }
  ];

  # ==========================================================================
  # zram Compressed Swap - Fast In-Memory Swap
  # ==========================================================================
  # zram provides compressed swap in RAM, which is faster than disk swap.
  # Priority 5 ensures zram is used before the swapfile (priority -2).
  # The zstd algorithm offers best compression/speed ratio.
  #
  # Swap hierarchy:
  # 1. zram (priority 5) - Fast, compressed RAM swap
  # 2. swapfile (priority -2) - Disk-based fallback
  #
  # See: specs/39_analyze_memory_logs_optimize_system
  # ==========================================================================
  zramSwap = {
    enable = true;
    algorithm = "zstd"; # Best compression/speed ratio
    memoryPercent = 50; # Use up to 50% of RAM (16GB of 32GB)
    priority = 5; # Higher than swapfile (-2)
  };

  # ==========================================================================
  # VM Parameters - Desktop Memory Optimization
  # ==========================================================================
  # Tuned for desktop responsiveness with zram swap:
  # - Lower swappiness: Keep more in RAM, desktop feels snappier
  # - Watermark tuning: Better memory reclaim behavior
  # - Disable page-cluster: zram doesn't benefit from readahead
  #
  # See: specs/39_analyze_memory_logs_optimize_system
  # ==========================================================================
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Prefer RAM over swap (default: 60)
    "vm.watermark_boost_factor" = 0; # Disable watermark boosting
    "vm.watermark_scale_factor" = 125; # Better memory reclaim (default: 10)
    "vm.page-cluster" = 0; # Disable readahead for zram (default: 3)
  };
}

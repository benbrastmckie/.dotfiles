# Power management, udev rules, battery suspend backstop, OOM handling, swap,
# zram, and VM parameters.
{ pkgs, lib, ... }:
let
  # ==========================================================================
  # Battery backstop wake-grace scripts (round 3 -- report 04 Q5)
  # ==========================================================================
  # Test-only override hooks (BACKSTOP_BATTERY_GLOB / BACKSTOP_SYSTEMCTL_BIN /
  # BACKSTOP_NOTIFY_BIN / STATE_DIRECTORY env vars, read via bash's ${var:-...}
  # default expansion) let the Phase 6 offline logic exercise run the built
  # store script against a fake sysfs tree, a fake state directory, and a
  # stubbed systemctl -- no sudo, no real suspend. All default to the real
  # paths baked in below, so an unmodified production invocation (via the
  # systemd unit, which sets STATE_DIRECTORY itself) is unaffected.
  batteryBackstopNotify = pkgs.writeShellScript "battery-backstop-notify" ''
    set -u
    urgency="$1"
    summary="$2"
    body="$3"
    # runuser resolves its -u argument via getpwnam, which has no "#UID" handling
    # (that is a sudo convention) -- so the username from loginctl's second field
    # is what must be passed here. Getting this wrong fails silently: notify-send's
    # stderr is discarded below and safe_notify's `|| true` swallows the exit code.
    ${pkgs.systemd}/bin/loginctl list-users --no-legend | while read -r uid user _rest; do
      [ "$uid" -ge 1000 ] 2>/dev/null || continue
      ${pkgs.util-linux}/bin/runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        ${pkgs.libnotify}/bin/notify-send -u "$urgency" "$summary" "$body" 2>/dev/null
    done
  '';

  batteryBackstopWakeMark = pkgs.writeShellScript "battery-backstop-wake-mark" ''
    set -u
    # Run as the sleep.target hook's ExecStop after every resume (see the
    # battery-backstop-wake-mark unit below): writes epoch + capacity at wake
    # time. Clearing the notified marker re-arms one notification per grace
    # window (see battery-suspend-backstop's notified_marker logic).
    state_dir="''${STATE_DIRECTORY:-/var/lib/battery-suspend-backstop}"
    mkdir -p "$state_dir"
    cap=0
    for bat in ''${BACKSTOP_BATTERY_GLOB:-/sys/class/power_supply/BAT*}; do
      [ -e "$bat/capacity" ] || continue
      cap=$(cat "$bat/capacity")
      break
    done
    echo "$(date +%s) $cap" > "$state_dir/wake-mark"
    rm -f "$state_dir/notified"
  '';

  batteryBackstopScript = pkgs.writeShellScript "battery-suspend-backstop" ''
    set -u

    # Unchanged core (round 1): threshold, BAT* glob, Discharging gate.
    threshold=10
    # Round-3 wake-grace parameters (report 04 Q5). See power.nix's banner
    # comment above for the full rationale and the three independent bounds.
    grace_secs=300   # wake-grace window length in seconds (5 min)
    grace_floor=5    # no grace at or below this capacity - unconditional loop resumes
    grace_drop=2     # grace voided once capacity has fallen this many points since wake

    state_dir="''${STATE_DIRECTORY:-/var/lib/battery-suspend-backstop}"
    mkdir -p "$state_dir"
    wake_mark="$state_dir/wake-mark"
    notified_marker="$state_dir/notified"
    notify_bin="''${BACKSTOP_NOTIFY_BIN:-${batteryBackstopNotify}}"
    systemctl_bin="''${BACKSTOP_SYSTEMCTL_BIN:-${pkgs.systemd}/bin/systemctl}"

    safe_notify() {
      # Never allowed to block/delay the suspend decision: bounded timeout,
      # and a failure here is cosmetic only -- the journal echo alongside
      # every call site is the always-works fallback.
      timeout 5 "$notify_bin" "$1" "$2" "$3" || true
    }

    if [ "''${1:-}" = "--test-notify" ]; then
      safe_notify critical "Battery backstop test" "root-to-session notification path OK (--test-notify)"
      exit 0
    fi

    for bat in ''${BACKSTOP_BATTERY_GLOB:-/sys/class/power_supply/BAT*}; do
      [ -e "$bat/capacity" ] || continue
      status=$(cat "$bat/status")
      cap=$(cat "$bat/capacity")
      if [ "$status" = "Discharging" ] && [ "$cap" -le "$threshold" ]; then
        grant_grace=0
        delta=0
        if [ "$cap" -gt "$grace_floor" ] && [ -f "$wake_mark" ]; then
          wake_epoch=""
          wake_cap=""
          read -r wake_epoch wake_cap < "$wake_mark" || true
          if [ -n "''${wake_epoch:-}" ] && [ -n "''${wake_cap:-}" ]; then
            now=$(date +%s)
            delta=$(( now - wake_epoch ))
            drop=$(( wake_cap - cap ))
            if [ "$delta" -ge 0 ] && [ "$delta" -lt "$grace_secs" ] && [ "$drop" -lt "$grace_drop" ]; then
              grant_grace=1
            fi
          fi
        fi

        if [ "$grant_grace" -eq 1 ]; then
          remaining=$(( grace_secs - delta ))
          echo "battery at ''${cap}%, discharging, within wake-grace (''${remaining}s remaining): skipping this tick"
          if [ ! -f "$notified_marker" ]; then
            touch "$notified_marker"
            safe_notify critical "Battery low (''${cap}%)" "Wake-grace active: ~''${remaining}s before the backstop may suspend again. Plug in or shut down."
          fi
        else
          echo "battery at ''${cap}% and discharging: suspending (inhibitors bypassed)"
          safe_notify critical "Battery at ''${cap}%" "Suspending now to protect the battery - inhibitors bypassed."
          exec "$systemctl_bin" suspend -i
        fi
        break
      fi
    done
  '';
in
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

  # ==========================================================================
  # Polkit grant: root may suspend while ignoring inhibitors (task 123)
  # ==========================================================================
  # Allow root to suspend while ignoring inhibitors, for the session-less
  # battery-suspend-backstop oneshot below. Without this the oneshot's
  # `systemctl suspend -i` is denied on every firing (login1 ships
  # suspend-ignore-inhibit as auth_admin_keep on all three subject
  # classes, and a session-less root caller has no agent to prompt), so
  # the <=10% safety net has never once been able to suspend.
  #
  # Deliberately narrower than systemd's shipped
  # 10-systemd-logind-root-ignore-inhibitors.rules.example, which grants
  # all five *-ignore-inhibit actions (power-off/reboot/halt/suspend/
  # hibernate). This repo needs suspend only.
  #
  # Ordering assumption: NixOS appends extraConfig into the body of
  # /etc/polkit-1/rules.d/10-nixos.rules, today the only .rules file on
  # this host. polkit stops at the first rule returning a non-NOT_HANDLED
  # value, so a future .rules file sorting lexically before 10-nixos
  # could shadow this. Re-check if rules.d composition ever changes.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.suspend-ignore-inhibit" &&
          subject.user == "root") {
        return polkit.Result.YES;
      }
    });
  '';

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
      # `systemctl suspend -i` = SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS).
      # Root is NOT authorized to use this by default -- login1 ships
      # suspend-ignore-inhibit as auth_admin_keep for all subject classes, so
      # a session-less root caller (no agent to prompt) is denied outright.
      # The `security.polkit.extraConfig` rule above this block is what makes
      # this call succeed; without it this oneshot silently fails every time
      # it fires (task 123). The timer retries every minute so it cannot be
      # raced by a freshly acquired inhibitor.
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
      #
      # -- Round 3: bounded wake-grace + lock-screen-visible notification --
      # Defect fixed (report 04 Q5, HIGH): with no grace and no visible
      # notification, a user who wakes the machine at <=10% specifically to
      # plug in a charger could be re-suspended within ~60s, repeatedly, with
      # zero feedback (the journal echo above is invisible behind a lock
      # screen). Fixed additively -- the unconditional re-suspend loop above
      # is retained below the grace floor; nothing about the core threshold,
      # glob, or Discharging gate changed.
      #
      # Parameters (in battery-suspend-backstop's ExecStart script):
      #   threshold=10     unchanged suspend trigger
      #   grace_secs=300   wake-grace window length (5 min)
      #   grace_floor=5    NO grace at or below this capacity
      #   grace_drop=2     grace voided once capacity has fallen this many
      #                    points below its value at wake
      #
      # Three independent bounds keep the grace from defeating the backstop's
      # purpose: (a) grace is granted only after a *resume* (via the
      # battery-backstop-wake-mark unit below), never on the unattended
      # descent; (b) grace_floor -- zero grace at/below 5%, the original
      # unconditional loop resumes; (c) grace_drop -- grace is voided the
      # moment capacity falls 2 points below its wake-time value, so each
      # grant costs at most ~2% regardless of the clock. Worst case: a
      # handful of grants between 10% and 5%, i.e. the descent is slowed,
      # never halted.
      #
      # Fail-safe direction: no wake-mark file (or a stale/unparsable one)
      # means no grace, i.e. exactly the pre-round-3 unconditional behavior.
      # This is deliberate -- protection is never weakened by the resume hook
      # failing to fire (see battery-backstop-wake-mark below).
      #
      # Trade-off (stated plainly, not hidden): a grace window IS a
      # deliberate, bounded weakening of an unattended machine's protection.
      # In the worst case (a bagged laptop that keeps waking spuriously),
      # each grant costs at most 5 minutes of awake time OR 2% of charge,
      # whichever comes first, and no grant is possible at or below 5%. A
      # longer window (15-30 min) was rejected because on a bagged laptop it
      # could burn the entire remaining reserve in one or two spurious wakes.
      #
      # Notifications never block or delay the suspend decision: the notify
      # helper is wrapped in `timeout 5 ... || true`; the journal echo
      # alongside every call site is retained unconditionally as the
      # always-works fallback. `--test-notify` turns the root-to-user-session
      # bus path into a one-line check (`sudo <script> --test-notify`)
      # instead of an assumption -- see docs/gnome-settings.md.
      # ========================================================================
      battery-suspend-backstop = {
        description = "Suspend at <=10% battery, bypassing sleep inhibitors (bounded wake-grace + notification)";
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "battery-suspend-backstop";
          ExecStart = batteryBackstopScript;
        };
      };

      # Resume hook: marks the wake timestamp + capacity that the backstop
      # script above reads to decide whether a wake-grace applies.
      #
      # post-resume.target does NOT exist on this host (`systemctl show
      # post-resume.target` reports LoadState=not-found) -- this unit
      # previously targeted it via wantedBy and was therefore never pulled
      # in by a resume, despite a populated .wants/ directory (systemd
      # writes [Install] symlinks from a unit's static WantedBy= list
      # regardless of whether the target resolves; a populated .wants/ dir
      # is NOT evidence a unit fires).
      #
      # Rewired to sleep.target, the documented systemd integration point
      # for post-resume hooks (man systemd.special: "hook program code
      # after the actual system sleep operation ... place the command in
      # ExecStop=, enable StopWhenUnneeded= and RemainAfterExit="). This is
      # byte-for-byte the shape nixpkgs's own sleep-actions.service already
      # uses on this host (generated because powerManagement.enable = true
      # above) -- `before = [ "sleep.target" ]` orders activation before
      # sleep, and the ExecStop= body (the actual wake-mark write) runs when
      # sleep.target is torn down on resume.
      battery-backstop-wake-mark = {
        description = "Record wake timestamp/capacity for the battery-suspend-backstop wake-grace window";
        wantedBy = [ "sleep.target" ];
        before = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "battery-suspend-backstop";
          ExecStop = batteryBackstopWakeMark;
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

# Boot loader, kernel, and low-level hardware configuration.
# deadnix: skip
{ pkgs, lib, ... }:
{
  boot = {
    # Bootloader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # ==========================================================================
    # Suspend/Resume and NetworkManager Deadlock Fixes for Ryzen AI 300 Series
    # ==========================================================================
    # Problem: System fails to suspend due to MediaTek WiFi (mt7925e) timeout
    # and AMD GPU VPE (Video Processing Engine) reset failure.
    # Also: NetworkManager deadlocks caused by WiFi driver kernel worker threads.
    #
    # Solution:
    # 1. Use latest kernel for best Ryzen AI 300 hardware support
    # 2. Add AMD-specific kernel parameters for better power management
    # 3. Disable problematic WiFi power management during suspend AND runtime
    # 4. Work around AMD GPU VPE suspend issues
    # 5. Reduce hung task timeout for earlier deadlock detection
    #
    # See: specs/reports/019_system_freeze_shutdown_analysis.md
    # ==========================================================================

    # Use latest kernel for best Ryzen AI 300 series support
    kernelPackages = pkgs.linuxPackages_latest;

    # ==========================================================================
    # Framework 13 AMD AI 300 - Phantom Audio Interface Fix
    # ==========================================================================
    # The Framework BIOS incorrectly reports the ACP device as a wired audio
    # device. This causes snd_acp70 and snd_acp_pci to load and create phantom
    # UCM audio interfaces that can cause hardware polling and IRQ noise.
    # Blacklisting matches the nixos-hardware framework-amd-ai-300-series module.
    # See: https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/amd-ai-300-series
    # ==========================================================================
    blacklistedKernelModules = [
      "snd_acp70"
      "snd_acp_pci"
    ];

    # Kernel parameters for Ryzen AI 300 suspend/resume and deadlock detection
    kernelParams = [
      "amd_pstate=active" # Enable AMD P-state driver for better power management
      "amdgpu.dcdebugmask=0x10" # Disable problematic GPU features during suspend
      "rtc_cmos.use_acpi_alarm=1" # Better ACPI wake support
      "hung_task_timeout_secs=60" # Detect deadlocks faster (default: 120s)
      # Auto-reboot 10s after a kernel panic instead of hanging with a blinking
      # Caps Lock LED. The mt7925e WiFi driver has a known list-corruption panic
      # (mt76_wcid_add_poll, see task 104 research report); until the fixed
      # kernel lands this keeps the machine recoverable without a power-button hold.
      "panic=10"
    ];

    # Panic on the first oops instead of limping along. Task 104/106 diagnostics
    # finding: the mt7925e sta_poll_list corruption panic (mt76_wcid_add_poll)
    # was leaving NO pstore/EFI-var record — with panic_on_oops=0 the crashed
    # NAPI kthread dies holding a lock, the system wedges for ~60s, and by the
    # time the eventual hung-task/hard-lockup panic fires, the kmsg dump can no
    # longer be written. Setting panic_on_oops=1 panics immediately on the first
    # oops so the pstore dump captures cleanly before any wedge, and the
    # existing panic=10 auto-reboot below still applies afterward.
    # See: specs/106_root_cause_fix_mt7925e_wifi_kernel_panics/reports/01_mt7925e-panic-upstream-fix.md
    kernel.sysctl."kernel.panic_on_oops" = 1;

    # Audio and WiFi kernel module options
    # snd_hda_intel power_save=1: allow codec to idle after 1s of silence.
    #   Previously set to 0, but the EAPD speaker-amp is already disabled by the
    #   disable-speaker-amp service, so clicks from power-state transitions won't
    #   come through internal speakers. Enabling saves meaningful battery.
    # battery cache_time=10000: poll battery hardware every 10s (default ~1s).
    #   At 1s the kernel fires power_supply change events ~60/min, keeping udevd
    #   and journald busy. 10s gives accurate-enough readings while cutting
    #   that wakeup rate by 10x.
    extraModprobeConfig = ''
      options snd_hda_intel power_save=1 power_save_controller=N
      options mt7925e disable_aspm=1 power_save=0
      options battery cache_time=10000
    '';
  };
}

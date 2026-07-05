# Boot loader, kernel, and low-level hardware configuration.
# deadnix: skip
{ pkgs, lib, ... }:
{
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ==========================================================================
  # Framework 13 AMD AI 300 - Phantom Audio Interface Fix
  # ==========================================================================
  # The Framework BIOS incorrectly reports the ACP device as a wired audio
  # device. This causes snd_acp70 and snd_acp_pci to load and create phantom
  # UCM audio interfaces that can cause hardware polling and IRQ noise.
  # Blacklisting matches the nixos-hardware framework-amd-ai-300-series module.
  # See: https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/amd-ai-300-series
  # ==========================================================================
  boot.blacklistedKernelModules = [
    "snd_acp70"
    "snd_acp_pci"
  ];

  # Kernel parameters for Ryzen AI 300 suspend/resume and deadlock detection
  boot.kernelParams = [
    "amd_pstate=active" # Enable AMD P-state driver for better power management
    "amdgpu.dcdebugmask=0x10" # Disable problematic GPU features during suspend
    "rtc_cmos.use_acpi_alarm=1" # Better ACPI wake support
    "hung_task_timeout_secs=60" # Detect deadlocks faster (default: 120s)
  ];

  # Audio and WiFi kernel module options
  # snd_hda_intel power_save=1: allow codec to idle after 1s of silence.
  #   Previously set to 0, but the EAPD speaker-amp is already disabled by the
  #   disable-speaker-amp service, so clicks from power-state transitions won't
  #   come through internal speakers. Enabling saves meaningful battery.
  # battery cache_time=10000: poll battery hardware every 10s (default ~1s).
  #   At 1s the kernel fires power_supply change events ~60/min, keeping udevd
  #   and journald busy. 10s gives accurate-enough readings while cutting
  #   that wakeup rate by 10x.
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1 power_save_controller=N
    options mt7925e disable_aspm=1 power_save=0
    options battery cache_time=10000
  '';
}

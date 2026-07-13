# Research Report: Task #76

**Task**: 76 - niri_laptop_hardware_keys
**Started**: 2026-07-04T19:07:57Z
**Completed**: 2026-07-04T19:27:10Z
**Effort**: Small (~30-45 min implementation)
**Dependencies**: None
**Sources/Inputs**: nixpkgs source (brightnessctl package.nix), brightnessctl upstream source (brightnessctl.c, README.md), NixOS Wiki "Backlight" page, local repo (config/config.kdl, modules/system/{desktop,packages,users,audio}.nix, modules/home/desktop/kanshi.nix)
**Artifacts**: specs/076_niri_laptop_hardware_keys/reports/01_niri-hardware-keys.md (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Crucial correctness question resolved via source-code reading**: `pkgs.brightnessctl` on current nixpkgs is built with `ENABLE_SYSTEMD=1` (links `systemd`'s `sd-bus`). At runtime, if the calling user is not root and lacks write access to `/sys/class/backlight/*/brightness`, brightnessctl **automatically falls back to calling `org.freedesktop.login1` `Session.SetBrightness` over the system D-Bus** (logind), which performs the write on the caller's behalf. This requires **no udev rule, no `video` group membership, and no extra NixOS option** — only a live logind session, which this machine already has (GDM manages both the GNOME and niri sessions, so `systemd-logind` is active in both). This matches and is *confirmed* (not just asserted) by both the NixOS Wiki and the upstream C source.
- Recommendation: add `pkgs.brightnessctl` to `environment.systemPackages` (matching the existing "Niri essential packages" group in `modules/system/packages.nix`). **Do not** add `services.udev.packages = [ pkgs.brightnessctl ]` or a `video` group as a required step — they are unnecessary given the logind fallback path, though harmless as defense-in-depth if ever desired.
- Bind `XF86MonBrightnessUp` / `XF86MonBrightnessDown` in `config/config.kdl` binds block (after the audio binds, config.kdl:180-186), spawning `brightnessctl set 5%+` / `brightnessctl set 5%-`, using brightnessctl's own `-n`/`--min-value` flag (accepts a percentage) to set an explicit floor and prevent a full blackout on repeated down-presses.
- Existing `XF86Audio*` binds (config.kdl:181-183, using `wpctl`) need **no change**. PipeWire/WirePlumber (`modules/system/audio.nix:13-21`) run as user-session services independent of the compositor (GNOME vs. niri), so `wpctl` already works identically in both sessions — this is corroborated by the pattern already established by `docs/niri.md`/prior niri tasks and by the fact PipeWire is enabled system-wide, not gated on `services.desktopManager.gnome`.

## Context & Scope

Researched how to wire laptop brightness function keys (`XF86MonBrightnessUp`/`Down`) into the niri Wayland session on this machine (laptop, primary output `eDP-1` 2560x1600, per `modules/home/desktop/kanshi.nix:13`). In the GNOME session, `gsd-media-keys` (part of `services.gnome.gnome-settings-daemon`, enabled at `modules/system/desktop.nix:65`) owns global media keys, but niri has its own keybinding table (`config/config.kdl`) and gsd does not grab keys in a niri session. Currently `config/config.kdl` has no brightness binds and `brightnessctl` is not packaged anywhere in the repo (`grep -ri brightnessctl` over `modules/` returned nothing).

The central open question was whether NixOS needs extra plumbing (a `hardware.brightnessctl.enable`-style option, `services.udev.packages`, or `video` group membership) for a non-root user to change backlight brightness in a Wayland session, or whether installing the package alone suffices.

## Findings

### Existing Configuration

- `config/config.kdl:154-241` is the single `binds { }` block. Audio keys already present and working via `wpctl` (config.kdl:181-183):
  ```kdl
  XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
  XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
  XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
  ```
  No `XF86MonBrightness*` binds exist anywhere in the file.
- `modules/system/packages.nix:5-35` has a clearly labeled "Niri essential packages (for dual-session with GNOME)" group (`xwayland-satellite`, `fuzzel`, `wdisplays`) — the natural home for `brightnessctl` given the sibling task 75 (`niri_keybinding_dependencies`) recommends the same placement pattern for `grimshot`/`playerctl`.
- `modules/system/desktop.nix` confirms both GNOME and niri are GDM sessions (`services.displayManager.gdm.enable = true`, `services.displayManager.sessionPackages = [ pkgs.niri ]`, comment at line 45: "Both GNOME and niri sessions available at GDM login"). This means `systemd-logind` manages a real seat/session for niri exactly as it does for GNOME — there is no reduced-privilege or logind-less mode for niri on this system.
- `modules/system/users.nix:8` — the primary user's `extraGroups` is `[ "networkmanager" "wheel" "input" "uinput" ]`. **No `video` group.** Only `hosts/usb-installer/default.nix:115` (an unrelated installer image) has `video` in its groups. This matters only if the udev-rule permission path were required — it is not (see Recommendations), but it rules out relying on the classic "add user to video group" approach without an extra state.json/users.nix edit.
- `modules/system/audio.nix:13-21` — PipeWire (`services.pipewire.enable = true`, `wireplumber.enable = true`, `systemWide = false`) is a normal per-user-session service unrelated to `services.desktopManager.gnome`; it is not conditionally disabled for niri anywhere in the repo. This is why `wpctl` binds already work in niri without any GNOME-specific dependency.

### Nix Documentation / Source-Level Findings

**1. Current nixpkgs `brightnessctl` derivation** (`pkgs/by-name/br/brightnessctl/package.nix`, fetched from nixpkgs master):
```nix
makeFlags = [ "PREFIX=" "DESTDIR=$(out)" "ENABLE_SYSTEMD=1" ];
installTargets = [ "install" "install_udev_rules" ];
buildInputs = [ systemd ];
```
The package **does** build with systemd/logind support (`ENABLE_SYSTEMD=1`) and **does** install `90-brightnessctl.rules` into `$out/lib/udev/rules.d/` as part of the build (`install_udev_rules` target) — but on NixOS, a udev rule shipped inside a package's `$out` is only actually loaded by the running udev daemon if that package is listed in `services.udev.packages`; simply being in `environment.systemPackages` does not auto-register udev rules. (This is the same general NixOS behavior documented for other udev-rule-shipping packages, e.g. the `ddcutil`/`rtl-sdr` udev-registration issues found during search.)

**2. The former `hardware.brightnessctl` NixOS module** (`nixos/modules/hardware/brightnessctl.nix`, existed through at least release-19.09):
```nix
options.hardware.brightnessctl.enable = mkOption { default = false; type = types.bool;
  description = "Enable brightnessctl in userspace. This will allow brightness control from users in the video group."; };
config = mkIf cfg.enable {
  services.udev.packages = with pkgs; [ brightnessctl ];
  environment.systemPackages = with pkgs; [ brightnessctl ];
};
```
**This module has since been removed from nixpkgs** (confirmed: `nixos/modules/hardware/brightnessctl.nix` returns 404 on current master; the directory listing shows only `brillo.nix` remains, no `brightnessctl.nix`). It was removed precisely because newer `brightnessctl` builds support the `systemd-logind` D-Bus API directly, making the module's udev+group approach unnecessary for the common case. **There is no `hardware.brightnessctl.enable` option available in current nixpkgs** — do not reference it in the plan.

**3. Upstream `brightnessctl.c` runtime logic** (read directly from `Hummer12007/brightnessctl` master, the exact source nixpkgs builds):
```c
if ((p.operation == SET || p.restore) && !p.pretend && geteuid()) {
    // not root
    if (access(file_path, W_OK)) {
        // no direct write permission on the sysfs brightness file
        write_device = logind_set_brightness;
    }
}
...
bool logind_set_brightness(struct device *d) {
    sd_bus *bus = NULL;
    int r = sd_bus_default_system(&bus);
    r = sd_bus_call_method(bus, ..., "SetBrightness", ...);
    ...
}
```
This is the definitive answer: as a non-root user, if `brightnessctl` cannot write the sysfs file directly (i.e., no udev rule/`video` group grant), it transparently calls `logind`'s `Session.SetBrightness` D-Bus method instead, which performs the privileged write via `systemd-logind` (running as root) on behalf of the calling session. `logind` verifies the caller belongs to the active session for the seat that owns the device — no polkit prompt, no extra NixOS config, no `video` group. **This is exactly the "works out of the box" behavior described by the NixOS Wiki's Backlight page**, now verified at the source level rather than taken on faith.

**4. `README.md` Permissions section** (upstream, verbatim): three permission mechanisms are listed — (1) udev rules for `video`/`input` groups ("done by default" at the packaging level, i.e., the rule file is installed by the build but only takes effect on NixOS via `services.udev.packages`), (2) suid binary, (3) `systemd-logind` API. Mechanism (3) is what actually fires here since neither (1) nor (2) is configured in this repo.

**5. Min-value floor**: `-n, --min-value[=MIN-VALUE]` (default `1` if given with no argument) — confirmed in both the CLI help text and the source (`parse_value(&p.min, optarg)` at brightnessctl.c:162, applied via the same value parser used for `SET`, at line 403 `p.min.val = percent_to_val(p.min.val, d)` when a percentage is supplied). **This confirms `-n 5%` is valid syntax** — the min-value argument accepts the same percentage/absolute grammar as the main `set` value, not just a raw integer. Without any `-n`, brightnessctl already clamps to a minimum raw value of `1` (never literal `0`), so a *total* blackout from repeated `5%-` presses is already prevented by the tool's own default; explicitly passing `-n 5%` is a stronger, more visible floor recommended in the task description.

### Community/Wiki Confirmation

- NixOS Wiki "Backlight" page: "Since `brightnessctl` supports the systemd-logind API it should work out of the box (i.e. without installing any udev rules or using a setuid wrapper)... You can use it by simply installing the package." Test commands shown: `brightnessctl set 5%-` / `brightnessctl set 5%+`, with `-d <device>` to disambiguate devices if more than one backlight class device is present.

## Recommendations

### 1. Package placement — `modules/system/packages.nix`

Add `brightnessctl` to the existing "Niri essential packages" comment group (after `wdisplays`, around packages.nix:21), following the same convention task 75 proposes for `grimshot`/`playerctl`:

```nix
      # Niri essential packages (for dual-session with GNOME)
      xwayland-satellite # X11 compatibility layer for Niri (auto-detected since 25.08)
      fuzzel # Lightweight application launcher for Wayland
      wdisplays # GUI monitor configuration tool for wlr-output-management
      brightnessctl # Laptop backlight control (XF86MonBrightness keys in niri; uses logind SetBrightness, no udev/video-group needed)
```

No other NixOS option is required. Do **not** add `services.udev.packages = [ pkgs.brightnessctl ];` and do **not** add `video` to `modules/system/users.nix:8` extraGroups as a prerequisite — both are unnecessary given the logind D-Bus fallback verified above. (Optional, not recommended unless the logind path is later found insufficient on this hardware: adding `video`/`input` to extraGroups would activate the *direct sysfs write* path instead of the D-Bus fallback, marginally faster but with no functional benefit here and requiring a `nixos-rebuild switch` + re-login for group membership to take effect, whereas the logind path works immediately after just installing the package.)

### 2. Keybinds — `config/config.kdl`

Insert after the existing audio binds (after config.kdl:186, before the "Window management" comment at line 188):

```kdl
    // Brightness controls (niri owns these keys; gsd-media-keys does not grab them here)
    XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "-n" "5%" "set" "5%-"; }
```

Notes:
- Matches the existing multi-arg `spawn` array style already used for the `wpctl` binds (no shell wrapper needed, since brightnessctl takes plain positional args — no `sh -c` required, unlike the clipboard/screenshot-annotation binds that need shell pipelines).
- `-n 5%` on the down-bind sets an explicit 5% floor (confirmed valid syntax — `-n` accepts the same percentage grammar as `set`), preventing the panel from going fully black on repeated presses; not needed on the up-bind.
- Optional (not required, out of scope unless requested): Shift-modified variants for finer 1% steps, e.g. `Mod+Shift+XF86MonBrightnessUp` is not meaningful for XF86 keys the way it is for letter keys since XF86 keys don't reliably combine with Shift on most keyboards/firmware — if finer control is wanted later, prefer separate niri binds on ordinary keys instead.
- If multiple backlight-class devices are ever detected (unlikely on this Intel-graphics laptop hardware per `hosts/{garuda,nandi}/hardware-configuration.nix` showing only `kvm-intel`/Intel microcode, no discrete GPU module) run `brightnessctl -l` post-switch to confirm a single unambiguous device; only add `-d <device>` to the binds if disambiguation is actually needed.

### 3. Audio binds — no change needed

`config.kdl:181-183` (`wpctl set-volume`/`set-mute`) require **no modification**. PipeWire + WirePlumber (`modules/system/audio.nix:13-21`) are enabled unconditionally at the system level, independent of `services.desktopManager.gnome`, and run as ordinary per-user-session D-Bus-activated services — the same PipeWire/WirePlumber instance backs `wpctl` regardless of which compositor (GNOME Shell or niri) is the active Wayland compositor. There is no GNOME-specific dependency in the audio stack that niri would lack. This should be spot-checked at VERIFY time (raise/lower/mute while in the niri session) but no code change is anticipated.

## Decisions

- Use `environment.systemPackages` (not `home.packages`) for `brightnessctl`, matching the placement convention already used for other niri-session utility binaries (`fuzzel`, `wdisplays`) in `modules/system/packages.nix`.
- Do not add a `hardware.brightnessctl.enable` reference — this option does not exist in current nixpkgs (module removed).
- Do not require `video`/`input` group changes to `modules/system/users.nix` as part of this fix; the logind D-Bus fallback path is sufficient and requires no group membership.
- Bind brightness keys directly in `config/config.kdl`'s existing `binds { }` block, immediately after the audio binds, using the same plain multi-arg `spawn` array style.

## Risks & Mitigations

- **Risk**: If for some reason `systemd-logind`'s `SetBrightness` D-Bus method is unreachable (e.g., a non-standard session registration for niri under GDM), brightness keys would silently no-op.
  **Mitigation**: VERIFY step in the task description already covers this (press keys, observe panel brightness change after switch). If it fails, the fallback is to add `services.udev.packages = [ pkgs.brightnessctl ]` plus `video`/`input` to `modules/system/users.nix:8` extraGroups (requires re-login) to activate the direct-sysfs-write path instead — this is a known-good fallback documented above but should not be pre-emptively added since it is unnecessary in the common case and adds an unneeded group grant.
- **Risk**: Multiple backlight devices (e.g. if a second GPU or an external HDMI panel exposes a `/sys/class/backlight` node) could make brightnessctl pick the wrong device.
  **Mitigation**: Run `brightnessctl -l` after the rebuild to confirm; add `-d <device>` to both binds only if ambiguity is observed. Hardware evidence (Intel-only kernel modules on both `garuda` and `nandi` hosts) suggests this is unlikely.
- **Risk**: `-n 5%` floor could be interpreted as a global default rather than per-invocation — it is not; `-n` is a per-invocation CLI flag with no persistent state, so it only affects that specific `spawn` call.

## Appendix

### Search queries used
- "NixOS brightnessctl udev rule services.udev.packages video group without sudo"
- "nixpkgs brightnessctl.nix udev rules postInstall 90-brightnessctl.rules"
- "\"hardware.brightnessctl\" nixos module removed OR deprecated logind"

### Key references
- https://wiki.nixos.org/wiki/Backlight
- https://github.com/NixOS/nixpkgs/blob/release-19.09/nixos/modules/hardware/brightnessctl.nix (removed module, historical)
- https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/br/brightnessctl/package.nix (current derivation, fetched directly)
- https://github.com/Hummer12007/brightnessctl (upstream source; `brightnessctl.c`, `README.md`, `90-brightnessctl.rules` read directly via GitHub API/raw fetch)

### Local files read
- `/home/benjamin/.dotfiles/config/config.kdl` (lines 140-249, binds block)
- `/home/benjamin/.dotfiles/modules/system/desktop.nix` (full)
- `/home/benjamin/.dotfiles/modules/system/packages.nix` (lines 1-60)
- `/home/benjamin/.dotfiles/modules/system/users.nix` (full)
- `/home/benjamin/.dotfiles/modules/system/audio.nix` (full)
- `/home/benjamin/.dotfiles/modules/home/desktop/kanshi.nix` (lines 1-40)
- `/home/benjamin/.dotfiles/hosts/{garuda,nandi,hamsa,usb-installer}/*` (grep for GPU/session context)
- `/home/benjamin/.dotfiles/specs/state.json` (tasks 75, 76 entries, for cross-task consistency)

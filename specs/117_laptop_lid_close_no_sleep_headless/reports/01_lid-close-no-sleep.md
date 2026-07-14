# Research Report: Task #117

**Task**: 117 - laptop_lid_close_no_sleep_headless
**Started**: 2026-07-14T12:39:14-07:00
**Completed**: 2026-07-14T12:52:00-07:00
**Effort**: ~1 hour research; implementation estimated small (1 module edit + docs)
**Dependencies**: None
**Sources/Inputs**: Local repo exploration, live system inspection (loginctl/busctl/gsettings/systemd-inhibit, read-only), `nix eval` against the flake, systemd-logind semantics
**Artifacts**: specs/117_laptop_lid_close_no_sleep_headless/reports/01_lid-close-no-sleep.md (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The live session is **GNOME on Wayland** (verified: `XDG_CURRENT_DESKTOP=GNOME`, gnome-shell running, no niri/swayidle processes). Lid handling is currently owned by **systemd-logind**, whose effective `HandleLidSwitch` is the stock default **`suspend`** (verified live via `busctl get-property org.freedesktop.login1 ... HandleLidSwitch` → `"suspend"`; the repo sets no logind lid options anywhere).
- The current "doesn't suspend when external monitors are attached" behavior is **not configured in the repo** — it is GNOME's `gsd-power` taking a `handle-lid-switch` **block inhibitor** when an external monitor is attached (verified live in `systemd-inhibit --list`: `gsd-power ... handle-lid-switch ... "External monitor attached or configuration changed recently" block`), plus logind's own docked heuristic (`HandleLidSwitchDocked` defaults to `ignore` when >1 display is connected).
- The reason the machine "never sleeps unless told" is that **Claude Code sessions hold `sleep:idle` block inhibitors** (verified live: six `claude-code systemd-inhibit sleep:idle ... block` entries). These inhibitors do **not** protect against lid-close suspend, because logind's `LidSwitchIgnoreInhibited` defaults to `yes` (sleep inhibitors are ignored for the lid action; only `handle-lid-switch` inhibitors count).
- **Recommended change (one file)**: in `modules/system/power.nix`, set `services.logind.settings.Login = { HandleLidSwitch = "ignore"; HandleLidSwitchExternalPower = "ignore"; }`. The pinned nixpkgs (`nixos-26.05`, `flake.nix:8`) has renamed the legacy `services.logind.lidSwitch` options into `services.logind.settings.Login.*` (verified: `nix eval .#...services.logind.lidSwitch` reports "Renaming error: option `services.logind.settings.Login.HandleLidSwitch` does not exist", i.e. it is an alias of the settings path, currently unset).
- Screen blanking needs **no change**: the eDP panel physically blanks when the lid closes (mutter disables the internal output on lid close), and the existing 5-minute idle blank (`idle-delay = 300`, `modules/home/desktop/gnome.nix:34`) is untouched by the logind change. Multi-monitor behavior is also untouched: `ignore` is strictly less aggressive than the current inhibitor-based path, so windows continue to distribute to external monitors exactly as today.

## Context & Scope

Goal: lid close → internal screen blanks, system does NOT suspend (AI agents keep running headless, no external monitors needed); when external monitors ARE attached, behavior must remain identical to today (no suspend, windows on external displays). Research only — no config edited. Documentation targets enumerated at the end.

## Findings

### (a) What the repo currently does

**Repo/flake layout**
- NixOS flake pinned to `github:NixOS/nixpkgs/nixos-26.05` (`flake.nix:8`). Hosts: `nandi` (Intel laptop), `hamsa` (AMD laptop — this machine, verified `hostname` = hamsa), `garuda`, `iso`, `usb-installer` (`flake.nix:126-140`, `hosts/README.md:7-22`).
- Always-on system modules aggregated in `modules/system/default.nix:8-23` (imports `power.nix`, `desktop.nix`, `display.nix`, etc.). Home Manager modules live under `modules/home/`.
- Dual desktop session: full GNOME + GDM (`modules/system/desktop.nix:5-20`) and niri as an alternative GDM session (`modules/system/desktop.nix:23`, `programs.niri.enable = true` at `modules/system/desktop.nix:81-85`). **Live session is GNOME Wayland** (verified: `XDG_CURRENT_DESKTOP=GNOME`, `gnome-shell` processes present, no `niri` or `swayidle` processes running).

**Sleep/suspend/lid configuration**
- **No logind configuration exists in the repo.** `grep -r logind|lidSwitch|HandleLid` across `*.nix` finds only an unrelated comment (`modules/system/packages.nix:21`). The generated `/etc/systemd/logind.conf` contains only `[Login] KillUserProcesses=false` (verified live and via `nix eval --raw '.#nixosConfigurations.hamsa.config.environment.etc."systemd/logind.conf".text'`). Effective `HandleLidSwitch` is therefore the systemd default **`suspend`** (verified live via busctl: `s "suspend"`).
- `modules/system/power.nix` handles power-profile switching (udev rules, lines 29-36), earlyoom (66-77), swap/zram (95-121), sysctl (133-138) — but nothing lid/suspend related. This file is the natural home for the logind change.
- GNOME idle-suspend is configured via Home Manager dconf: `sleep-inactive-ac-timeout = 3600`, `sleep-inactive-battery-timeout = 900`, `idle-dim = true` (`modules/home/desktop/gnome.nix:37-41`); live `sleep-inactive-ac-type`/`-battery-type` are both `'suspend'` (gsettings defaults, not set in the repo).
- **Why the machine "never sleeps unless told" today**: `systemd-inhibit --list` (live) shows six `claude-code ... sleep:idle ... block` inhibitors ("Claude Code session"). The `idle` block prevents GNOME's session-idle timer from firing, and the `sleep` block prevents suspend — but **only while a Claude Code process is running**. These inhibitors are not managed by this repo (they come from the Claude Code CLI itself). A commented-out repo-managed inhibitor unit exists at `modules/home/memory/services.nix:45-46` (deliberately disabled — see task 50 note there). A Neovim `<leader>rz` inhibitor is documented at `docs/gnome-settings.md:26`.
- **Critical gap**: `sleep` block inhibitors do NOT block the lid action. logind's `LidSwitchIgnoreInhibited` defaults to `yes`, meaning the lid-switch action ignores ordinary sleep inhibitors; only `handle-lid-switch` inhibitors (which g-s-d takes solely when an external monitor is attached) stop it. So **today, closing the lid with no external monitors suspends the machine and kills agents**, regardless of Claude Code's inhibitors — this is exactly the behavior the task wants changed.

**Screen blanking (the 5-minute blank to keep)**
- GNOME session: `idle-delay = 300` under `org/gnome/desktop/session` (`modules/home/desktop/gnome.nix:32-35`) — the 5-minute dim/blank the user observes. Verified live: `gsettings get org.gnome.desktop.session idle-delay` → `uint32 300`.
- Niri session (not currently active): swayidle spawned from the niri config — `config/config.kdl:270`: `spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "timeout" "600" "systemctl suspend" "before-sleep" "swaylock -f" "lock" "swaylock -f"`. Note this includes a **10-minute auto-suspend** in the niri session. `config.kdl` is deployed via `modules/home/core/dotfiles.nix:28` (`".config/niri/config.kdl".source = ../../../config/config.kdl`). The Home Manager `services.swayidle` module is deliberately disabled (`modules/home/desktop/swaylock.nix:15-31`).

**Multi-monitor / window distribution**
- GNOME session (active): mutter handles monitor hotplug and window redistribution natively; nothing repo-configured beyond `move-to-monitor-*` keybindings (`modules/home/desktop/gnome.nix:76-79`). The no-suspend-when-docked behavior is gsd-power's automatic `handle-lid-switch` inhibitor (verified live) plus logind's `HandleLidSwitchDocked` default of `ignore` (logind treats >1 connected display as "docked").
- Niri session: kanshi with a single "undocked" eDP-1 profile (`modules/home/desktop/kanshi.nix:4-29`; docked profiles are commented placeholders). Niri gives each monitor its own window strip (`docs/niri.md:116,394,427-434`).

### (b) What needs to change

1. **logind lid handling** — the single required change. Make logind ignore the lid switch so that lid close never suspends, independent of external-monitor state and power source. This is the layer that actually owns lid handling on this system (GNOME delegates lid actions to logind; g-s-d only ever *inhibits* logind, never suspends on lid itself; niri likewise does not perform lid suspend).
2. **Nothing for blanking**: when the lid closes, the eDP backlight is off and mutter disables the internal output — "blank" is inherent. The 5-minute `idle-delay` blank continues to govern the open-lid case and external monitors, unchanged.
3. **Nothing for multi-monitor**: setting `ignore` cannot regress the docked case — today's docked behavior already resolves to "don't suspend" via inhibitor/docked-default; after the change every lid-close path resolves to "don't suspend". Window distribution is mutter's (or niri's) job and is untouched.
4. **Optional hardening (decision points, not required)** — see Risks: (i) GNOME AC idle-suspend after 60 min (`sleep-inactive-ac-timeout = 3600` with live type `'suspend'`) would still suspend a headless machine if no Claude Code inhibitor is held; (ii) the niri session's swayidle line auto-suspends after 10 min idle (`config/config.kdl:270`).

### (c) Exact options and rationale

The pinned nixpkgs (nixos-26.05) has migrated logind to RFC-42 style settings. Verified against this flake: evaluating the legacy `services.logind.lidSwitch` produces `Renaming error: option 'services.logind.settings.Login.HandleLidSwitch' does not exist` — i.e. the legacy option is an alias for the freeform `settings.Login` path, which is currently unset. **Use the canonical settings form** (the legacy aliases still work but are deprecated):

```nix
# modules/system/power.nix (always-on module; inert on non-laptop hosts)
services.logind.settings.Login = {
  # Lid close must never suspend: AI agents keep running headless.
  # The internal panel still blanks (mutter/niri disable eDP-1 on lid close).
  HandleLidSwitch = "ignore";              # on battery, no external power
  HandleLidSwitchExternalPower = "ignore"; # on AC (default inherits HandleLidSwitch, but be explicit)
  # HandleLidSwitchDocked already defaults to "ignore" (docked = docking
  # station OR >1 connected display) — no need to set it; today's
  # external-monitor behavior flows through this default plus gsd-power's
  # handle-lid-switch inhibitor, and both remain in effect.
};
```

Rationale per option:
- `HandleLidSwitch = "ignore"`: covers the headline case — lid shut, no monitors, on battery or otherwise unspecified power state. logind takes no action; the session keeps running; the panel is off.
- `HandleLidSwitchExternalPower = "ignore"`: covers lid shut while on AC with no external monitor (systemd default for this key is to inherit `HandleLidSwitch`, so this is technically redundant, but stating it makes intent explicit and robust against upstream default changes).
- `HandleLidSwitchDocked`: leave at default `ignore`. Setting it would be a no-op; omitting it keeps the diff minimal and preserves the exact docked semantics used today.
- Placement: `modules/system/power.nix` (imported always-on by `modules/system/default.nix:16`), consistent with the file's charter ("Power management ..."). Both flake laptops (hamsa, nandi) get the fix; on any non-laptop host the options are harmless.

**Who owns lid handling on THIS system (layer analysis)**
- logind: executes the lid action (`suspend` today → `ignore` after change).
- GNOME (active session): gsd-power only *inhibits* logind when an external monitor is attached (verified live); mutter disables the internal output on lid close (provides the "blank"). Modern GNOME has no lid gsettings (verified: `gsettings list-keys org.gnome.settings-daemon.plugins.power | grep -i lid` → empty). So GNOME cannot re-introduce lid suspend after logind is set to ignore.
- niri (alternate session): does not suspend on lid; it turns the internal output off on lid close. The only niri-session suspend source is the swayidle `timeout 600 systemctl suspend` (`config/config.kdl:270`), which is idle-based, not lid-based (and `systemctl suspend` is itself refused while a Claude Code `sleep` block inhibitor is held).

## Verification Steps

Build-time:
1. `nix flake check` (syntax/eval).
2. `nixos-rebuild build --flake .#hamsa` (full closure build without activation).
3. `nix eval --raw '.#nixosConfigurations.hamsa.config.environment.etc."systemd/logind.conf".text'` — must show `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore` under `[Login]`.

Post-activation (after `sudo nixos-rebuild switch --flake .#hamsa`):
4. `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `s "ignore"` (logind picks up logind.conf changes on `systemctl restart systemd-logind` or reboot; a rebuild switch restarts it automatically when the file changes... verify rather than assume).
5. Functional: with no external monitor, close lid → screen off, `loginctl list-sessions` from SSH (or reopen lid) shows session still active; a long-running process (e.g. `journalctl -f` timestamp continuity, or a running agent) shows no suspend gap; `journalctl -b -u systemd-logind | grep -i lid` shows "Lid closed." with no suspend entry.
6. Regression: with external monitor attached, close lid → windows remain on external display exactly as today; `systemd-inhibit --list` still shows the gsd-power `handle-lid-switch` inhibitor when a monitor is attached.
7. Blank regression: leave machine idle 5 min with lid open → screen still blanks (`idle-delay=300` untouched).

## Decisions

- Use the canonical `services.logind.settings.Login.*` form, not the deprecated `services.logind.lidSwitch*` aliases (pinned nixpkgs is nixos-26.05 where the rename is live — verified by eval error message naming the rename target).
- Put the change in `modules/system/power.nix` (always-on), not `hosts/hamsa/default.nix`: both configured laptops benefit; option is inert elsewhere; matches the file's existing role.
- Do NOT set `HandleLidSwitchDocked` (default already `ignore`) — minimal diff, preserves current docked semantics byte-for-byte.
- Treat GNOME idle-suspend (`sleep-inactive-ac-*`) and the niri swayidle auto-suspend as **explicit decision points for the plan phase**, not silent changes — the user said the machine "does not sleep unless told", which currently holds only because Claude Code sessions hold `sleep:idle` inhibitors.

## Risks & Mitigations

- **Idle-suspend can still kill headless agents (AC)**: `sleep-inactive-ac-timeout = 3600` with live type `'suspend'` (`modules/home/desktop/gnome.nix:38`) suspends after 60 idle minutes if NO Claude Code inhibitor is held (e.g. agents launched without the CLI wrapper, or detached background jobs). Mitigation option: set `"org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-type = "nothing"` in `gnome.nix` to make "never sleep unless told" declarative on AC. Battery timeout (900 s) could be kept as thermal/battery protection — surface as a plan-phase question.
- **Battery drain with lid shut**: after this change, lid close on battery no longer suspends. This is what the task asks for, but docs should state it plainly so an unplugged, lid-shut laptop in a bag is a known hazard. (Explicit `systemctl suspend` still works as before.)
- **Niri session divergence**: `config/config.kdl:270` auto-suspends after 10 min idle in the niri session. If the user switches sessions, headless-agent behavior differs from GNOME. Mitigation: plan may drop the `"timeout" "600" "systemctl suspend"` pair (keeping the 5-min swaylock and before-sleep lock), or leave it and document the difference. `docs/niri.md:75` and the `docs/niri.md:910` snippet would need matching edits if changed.
- **logind restart semantics**: `nixos-rebuild switch` updates `/etc/systemd/logind.conf`; if systemd-logind is not restarted/reexecuted in that activation, the old `HandleLidSwitch` remains in memory. Verification step 4 catches this; `systemctl restart systemd-logind` is safe on this systemd version but verify session survival, or just reboot.
- **Non-repo inhibitor dependency**: the current no-idle-sleep behavior depends on Claude Code's own `systemd-inhibit` calls (not tracked in this repo). Docs should describe the three independent layers (Claude Code inhibitors, gsd-power monitor inhibitor, logind lid config) so future debugging doesn't conflate them.

## Documentation targets

Proportionate updates (the change is one small module edit — keep docs correspondingly small):

1. **`modules/system/power.nix`** — inline comment block above the new `services.logind.settings.Login` (the repo's established style; cf. the banner comments at lines 15-28, 56-65). Primary "why" documentation lives here.
2. **`docs/gnome-settings.md`** — extend the existing "Power Management" section (lines 20-26): add lid-close behavior (blank, no suspend; docked behavior unchanged) alongside the already-documented idle-delay/sleep timeouts and the `<leader>rz` inhibitor note. This is the main user-facing doc for this topic.
3. **`docs/niri.md`** — only if the niri swayidle suspend line is touched: update line 75 ("Swaylock + Swayidle" bullet) and the `services.swayidle` snippet around line 910; otherwise add one sentence noting lid-close no longer suspends in either session.
4. **`modules/README.md`** — one-line touch only if the `power.nix` description there (lines 31, 70 mention it by name) needs to say "lid/logind" — do not add a new section.
5. **`docs/configuration.md`** — line 33 already lists `power.nix` under hardware enablement; at most adjust that phrase. No new document.
6. **Not recommended**: new dedicated doc file, root `README.md` changes, or `hosts/*/README.md` changes — the change is host-agnostic and small; a new top-level doc would over-represent it (explicit task constraint).

## Appendix

**Live-system evidence gathered (all read-only)**
- `XDG_CURRENT_DESKTOP=GNOME`; `loginctl` session Type=wayland; gnome-shell running; no niri/swayidle processes.
- `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `s "suspend"`.
- `/etc/systemd/logind.conf` non-comment content: `[Login] KillUserProcesses=false` (matches `nix eval` of the flake-generated file).
- `systemd-inhibit --list`: gsd-power `handle-lid-switch` block ("External monitor attached..."); six claude-code `sleep:idle` blocks; GNOME Shell/gsd delay inhibitors.
- `gsettings`: `sleep-inactive-ac-type 'suspend'`, `sleep-inactive-battery-type 'suspend'`, `sleep-inactive-ac-timeout 3600`, `idle-delay uint32 300`; no `lid*` keys in the g-s-d power schema.
- `nix eval .#nixosConfigurations.hamsa.config.services.logind.lidSwitch` → rename error naming `services.logind.settings.Login.HandleLidSwitch` (proves canonical option path on nixos-26.05).

**Key repo citations**
- `flake.nix:8` (nixpkgs nixos-26.05), `flake.nix:126-140` (hosts)
- `modules/system/default.nix:16` (power.nix always-on import)
- `modules/system/power.nix` (no lid/logind config today; target file)
- `modules/system/desktop.nix:5-23,81-85` (GNOME+GDM, niri dual session)
- `modules/home/desktop/gnome.nix:32-41` (idle-delay 300, sleep-inactive timeouts), `:76-79` (move-to-monitor binds)
- `modules/home/desktop/kanshi.nix:4-29` (niri kanshi, undocked-only profile)
- `modules/home/desktop/swaylock.nix:15-31` (HM swayidle disabled, rationale)
- `config/config.kdl:268-270` (niri swayidle spawn incl. 10-min suspend), deployed by `modules/home/core/dotfiles.nix:28`
- `modules/home/memory/services.nix:45-46` (disabled repo-managed sleep inhibitor, task 50)
- Docs: `docs/gnome-settings.md:20-26`, `docs/niri.md:75,116,394,427-434,900-916`, `docs/configuration.md:33`, `modules/README.md:31,70`, `hosts/README.md:7-15`

**Search queries used**: repo greps for `logind|lidSwitch|HandleLid|suspend|sleep`, `niri|swayidle|hypridle|dpms|idle|monitor`; MCP-NixOS unavailable in this session — validation done directly against the pinned flake via `nix eval` (stronger evidence than a channel-generic MCP lookup for this repo).

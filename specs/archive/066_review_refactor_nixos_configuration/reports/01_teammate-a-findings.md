# Research Report: Task #66 — Teammate A (Primary Angle)

**Task**: 66 — Review and Refactor NixOS Configuration
**Angle**: PRIMARY — Current-State Audit + Recommended Refactor Approach
**Artifact**: 01_teammate-a-findings.md
**Completed**: 2026-06-24
**Effort**: ~3 hours
**Sources/Inputs**: Direct file audit, NixOS & Flakes Book, NixOS Discourse, personal blogs
**Confidence Level**: High for current-state audit; High for recommended structure

---

## Key Findings

1. **The configuration is monolithic and fragile.** `configuration.nix` (945 lines) and `home.nix` (1,627 lines) contain every domain of concern mixed together — hardware quirks, GNOME settings, systemd services, packages, shell scripts, email config, and more. This makes it difficult to navigate, test, or share parts across hosts.

2. **Overlays are inlined in flake.nix** (~120 lines of overlay logic embedded in the `let` block), instead of being in dedicated `overlays/` files. The flake creates three overlays (claude-squad build, unstable packages, Python packages) directly in-situ.

3. **Four package-installation paths exist simultaneously** — `environment.systemPackages`, `home.packages`, `programs.X.enable` (Home Manager), and custom `writeShellScriptBin` derivations in `home.packages` — with no clear ownership policy for where packages live.

4. **Confirmed package duplication**: `stylua`, `cvc5`, `lectic`, and `wl-clipboard` appear in both `environment.systemPackages` (configuration.nix) and `home.packages` (home.nix). `neovim` appears in both `environment.systemPackages` and `programs.neovim.enable = true` in home.nix (dual install).

5. **The `modules/` directory contains only one file** (`modules/opencode.nix`), which is itself not imported anywhere (`imports` in home.nix has it commented out). Similarly, `home-modules/mcp-hub.nix` is defined but disabled. The module infrastructure exists but is not used.

6. **Six inline `writeShellScriptBin` scripts live in `home.packages`**: sioyek-theme-toggle, refresh-gmail-oauth2, whisper-dictate, whisper-download-models, memory-monitor, claude-memory-tracker. These are 50–200-line Bash programs managed as Nix string literals, making them untestable and uncategorizable.

7. **The `unstable-packages.nix` file is a legacy artifact** — the overlay it defines (2 entries: `neovim-unwrapped`, `niri`) is superseded by the `unstablePackagesOverlay` in `flake.nix`. The file is not imported anywhere in flake.nix.

8. **Four hosts exist** (nandi, hamsa, garuda, usb-installer/iso) but all share a single `configuration.nix` with no per-host module branches. Host-specific logic (like the USB installer's Calamares setup) is inlined directly in `flake.nix` as an anonymous inline module (200+ lines).

9. **The standalone `homeConfigurations` and NixOS-integrated home-manager diverge in `extraSpecialArgs`**: the standalone path omits `niri` while the NixOS path includes it in some hosts. This duplication-with-subtle-differences is a maintenance hazard.

10. **`SASL_PATH` is hardcoded to a Nix store hash** in `home.sessionVariables` (`/nix/store/ja75va5...`), which breaks on any rebuild that changes the hash.

---

## Current-State Audit

### File Inventory Table

| File | Lines | Role | Issues |
|------|-------|------|--------|
| `flake.nix` | 477 | Entry point: inputs, overlays, host/HM defs | Overlays inlined (~120 lines); host defs repeated 4× with minor variations; USB installer has 200-line anonymous module |
| `configuration.nix` | 945 | NixOS system config (all hosts share this) | Monolithic: boot+network+GNOME+niri+audio+power+memory+services+packages+secrets mixed; no host branching |
| `home.nix` | 1,627 | Home Manager config | Monolithic: GNOME dconf + packages + 6 inline scripts + systemd services + email config + waybar + tools |
| `unstable-packages.nix` | 18 | Overlay fragment (unused) | Not imported anywhere; duplicates flake.nix overlay |
| `packages/aristotle.nix` | 4 | Custom derivation | Minimal, fine |
| `packages/claude-code.nix` | 10 | Custom derivation | Fine |
| `packages/kooha.nix` | 8 | Custom derivation (override) | Fine |
| `packages/loogle.nix` | 18 | Custom derivation | Fine |
| `packages/neovim.nix` | 26 | Custom derivation | Fine |
| `packages/opencode.nix` | 49 | Custom derivation | Fine |
| `packages/pymupdf4llm.nix` | 25 | Custom derivation | Fine |
| `packages/python-cvc5.nix` | 39 | Python package | Fine |
| `packages/python-vosk.nix` | 62 | Python package | Fine |
| `packages/slidev.nix` | 5 | Custom derivation | Fine |
| `packages/vosk-models.nix` | 24 | Model download derivation | Fine |
| `modules/opencode.nix` | 34 | Home Manager module (unused) | Not imported; good template for future modules |
| `home-modules/mcp-hub.nix` | 35 | Home Manager module (disabled) | Not imported; good module pattern with mkEnableOption |
| `hosts/nandi/hardware-configuration.nix` | 39 | Intel hardware config | Fine (auto-generated) |
| `hosts/hamsa/hardware-configuration.nix` | 35 | Intel hardware config | Fine |
| `hosts/garuda/hardware-configuration.nix` | 38 | GPU hardware config | Fine |
| `hosts/usb-installer/hardware-configuration.nix` | 43 | USB hardware config | Fine |
| `update.sh` | 43 | Build + rebuild script | Fine; hardcodes `benjamin` username |

**Total .nix source lines**: ~3,604
**Monolithic core**: 2,572 lines (71%) in 3 files (flake.nix, configuration.nix, home.nix)

### Identified Concerns by Category

**Organization problems:**
- No `overlays/` directory; overlays embedded in `flake.nix` let-block
- No `lib/` directory; no helper functions abstracted
- `modules/` exists but has 1 unused file; `home-modules/` has 1 disabled file
- Inline USB installer config (200+ lines) in flake.nix instead of `hosts/usb-installer/default.nix`

**Duplication:**
- Hosts `nandi`, `hamsa`, `iso`, `usb-installer` all paste the same home-manager block in `flake.nix`
- `stylua`, `cvc5`, `lectic`, `wl-clipboard` in both system and home packages
- `neovim` in both `environment.systemPackages` and `programs.neovim.enable`
- Fish shell config: `programs.fish` in `configuration.nix` AND `home.file.".config/fish/config.fish"` in `home.nix` (dual management)

**Maintenance hazards:**
- Hardcoded Nix store hash in `SASL_PATH`
- `unstable-packages.nix` is a dead file (not imported)
- `config/README.md` says to edit `opencode.json` but `home.nix` now writes it via `home.file`
- Comments like `# garuda` in `hosts/garuda/` directory but no `default.nix` (only hardware-configuration.nix) — no per-host NixOS module

**Scope creep in `home.nix`:**
- Full `mbsyncrc` config (170 lines) as an inline `home.file` text block
- Full aerc keybindings and config (180 lines) inline
- Waybar full configuration (90 lines) inline
- 6 Bash scripts totaling ~350 lines as Nix string literals in `home.packages`

---

## Recommended Approach

### Target Directory Structure

```
.dotfiles/
├── flake.nix                          # SLIMMED: inputs + mkHost/mkHome helpers only
├── update.sh                          # Unchanged
├── secrets/                           # Unchanged
├── wallpapers/                        # Unchanged
├── config/                            # Unchanged (dotfiles sources)
├── docs/                              # Unchanged
│
├── overlays/                          # NEW: one file per overlay
│   ├── claude-squad.nix               # Extracted from flake.nix let-block
│   ├── unstable-packages.nix          # Replaces/merges root unstable-packages.nix
│   └── python-packages.nix            # Extracted from flake.nix
│
├── lib/                               # NEW: flake helpers
│   └── mkHost.nix                     # mkHost function (dedup host definitions)
│
├── packages/                          # UNCHANGED: custom derivations (already good)
│   ├── aristotle.nix
│   ├── claude-code.nix
│   ├── kooha.nix
│   ├── loogle.nix
│   ├── neovim.nix
│   ├── opencode.nix
│   ├── pymupdf4llm.nix
│   ├── python-cvc5.nix
│   ├── python-vosk.nix
│   ├── slidev.nix
│   └── vosk-models.nix
│
├── hosts/                             # EXPANDED: per-host NixOS modules
│   ├── common/
│   │   ├── core/
│   │   │   ├── default.nix            # Imports all core modules (applied to all hosts)
│   │   │   ├── boot.nix               # boot.loader, kernelPackages, kernelParams, modules
│   │   │   ├── hardware.nix           # hardware.graphics, bluetooth, uinput, qmk
│   │   │   ├── audio.nix              # pipewire, pulseaudio=false, rtkit, speaker-amp service
│   │   │   ├── networking.nix         # networkmanager, firewall
│   │   │   ├── desktop.nix            # GNOME + niri + GDM + XDG portal + xwayland
│   │   │   ├── display.nix            # GDM login wallpaper, dconf gdm profile, fonts
│   │   │   ├── power.nix              # earlyoom, swap, zram, sysctl, udev power rules, systemd power
│   │   │   ├── locale.nix             # i18n, time, geoclue2, automatic-timezoned
│   │   │   ├── users.nix              # users.users.benjamin definition
│   │   │   ├── nix.nix                # nix.settings, gc, nix-ld, allowUnfree
│   │   │   ├── security.nix           # polkit, pam, sudo, rtkit
│   │   │   ├── services.nix           # printing, avahi, fwupd, libinput, gvfs
│   │   │   └── packages.nix           # environment.systemPackages (system-level only)
│   │   └── optional/
│   │       ├── discord-bot.nix        # discord-bot + opencode-serve systemd services + sops secrets
│   │       └── usb-installer.nix      # Calamares + installer-specific config (extracted from flake.nix)
│   ├── nandi/
│   │   ├── default.nix                # imports common + hardware; sets hostName
│   │   └── hardware-configuration.nix # UNCHANGED
│   ├── hamsa/
│   │   ├── default.nix                # imports common + hardware; sets hostName
│   │   └── hardware-configuration.nix # UNCHANGED
│   ├── garuda/
│   │   ├── default.nix                # NEW: imports common + hardware; host-specific overrides
│   │   └── hardware-configuration.nix # UNCHANGED
│   └── usb-installer/
│       ├── default.nix                # imports common/optional/usb-installer.nix + hardware
│       └── hardware-configuration.nix # UNCHANGED
│
└── home/                              # EXPANDED: modular Home Manager
    ├── benjamin/
    │   ├── default.nix                # Top-level imports + home.username/homeDirectory/stateVersion
    │   ├── core/
    │   │   ├── git.nix                # programs.git
    │   │   ├── neovim.nix             # programs.neovim (sideloadInitLua, extraPackages)
    │   │   ├── shell.nix              # home.file fish config, home.sessionVariables
    │   │   └── xdg.nix                # xdg.enable, xdg.mimeApps, xdg.dataFile sioyek.desktop
    │   ├── desktop/
    │   │   ├── gnome.nix              # dconf.settings (all GNOME keybindings + extensions + prefs)
    │   │   ├── cursor.nix             # home.pointerCursor
    │   │   ├── waybar.nix             # programs.waybar (extracted from home.nix)
    │   │   ├── mako.nix               # services.mako
    │   │   ├── kanshi.nix             # services.kanshi
    │   │   └── swaylock.nix           # programs.swaylock
    │   ├── email/
    │   │   ├── notmuch.nix            # programs.notmuch
    │   │   ├── aerc.nix               # programs.aerc (config + binds extracted)
    │   │   ├── mbsync.nix             # home.file.".mbsyncrc" (IMAP sync config)
    │   │   └── protonmail.nix         # services.protonmail-bridge
    │   ├── packages/
    │   │   ├── ai-tools.nix           # claude-code, claude-squad, gemini-cli, opencode
    │   │   ├── dev-tools.nix          # git tools, LSP servers, formatters, etc.
    │   │   ├── lean-math.nix          # loogle, lectic, aristotle
    │   │   ├── media.nix              # obs-studio, vlc, kooha, etc.
    │   │   ├── python.nix             # python3.withPackages (full env)
    │   │   └── fonts.nix              # nerd-fonts, jetbrains-mono
    │   ├── scripts/
    │   │   ├── whisper.nix            # whisper-dictate + whisper-download-models scripts
    │   │   ├── memory-monitor.nix     # memory-monitor + claude-memory-tracker scripts
    │   │   ├── sioyek-theme.nix       # sioyek-theme-toggle script
    │   │   └── gmail-oauth2.nix       # refresh-gmail-oauth2 script + oauth2 timer/service
    │   └── services/
    │       ├── ydotool.nix            # systemd.user.services.ydotool
    │       ├── screenshot.nix         # systemd.user.services.screenshot-path-copy
    │       └── memory-services.nix    # systemd.user.services.{memory-monitor,claude-memory-tracker}
```

### Migration Mapping (Current → Target)

| Current Location | Content | Target Location |
|-----------------|---------|-----------------|
| `flake.nix` lines 50–81 | claude-squad overlay | `overlays/claude-squad.nix` |
| `flake.nix` lines 83–103 | unstable packages overlay | `overlays/unstable-packages.nix` |
| `flake.nix` lines 105–123 | Python packages overlay | `overlays/python-packages.nix` |
| `flake.nix` lines 154–183 | nandi host (duplicate block) | `hosts/nandi/default.nix` + `lib/mkHost.nix` |
| `flake.nix` lines 186–216 | hamsa host (duplicate block) | `hosts/hamsa/default.nix` |
| `flake.nix` lines 242–279 | iso inline module (~200 lines) | `hosts/usb-installer/` or combined with iso |
| `configuration.nix` lines 22–78 | boot config + kernel params | `hosts/common/core/boot.nix` |
| `configuration.nix` lines 85–99 | networking | `hosts/common/core/networking.nix` |
| `configuration.nix` lines 102–138 | locale/time/geoclue2 | `hosts/common/core/locale.nix` |
| `configuration.nix` lines 156–264 | GNOME + niri + xdg | `hosts/common/core/desktop.nix` |
| `configuration.nix` lines 273–290 | printing + avahi + bluetooth | `hosts/common/core/services.nix` |
| `configuration.nix` lines 292–316 | audio (pipewire) | `hosts/common/core/audio.nix` |
| `configuration.nix` lines 318–401 | power management | `hosts/common/core/power.nix` |
| `configuration.nix` lines 433–438 | vm/sysctl params | `hosts/common/core/power.nix` (sysctl section) |
| `configuration.nix` lines 441–484 | users + sops secrets | `hosts/common/core/users.nix` + `hosts/common/optional/discord-bot.nix` |
| `configuration.nix` lines 486–697 | environment.systemPackages | `hosts/common/core/packages.nix` |
| `configuration.nix` lines 700–711 | programs.fish + interactiveShellInit | `hosts/common/core/packages.nix` or new shell module |
| `configuration.nix` lines 713–732 | fonts | `hosts/common/core/display.nix` |
| `configuration.nix` lines 734–780 | nix settings + nix-ld | `hosts/common/core/nix.nix` |
| `configuration.nix` lines 799–940 | systemd services (discord-bot, opencode-serve) | `hosts/common/optional/discord-bot.nix` |
| `configuration.nix` lines 813–848 | audio service + NetworkManager timeout | `hosts/common/core/audio.nix` |
| `home.nix` lines 14–44 | git + neovim | `home/benjamin/core/git.nix` + `home/benjamin/core/neovim.nix` |
| `home.nix` lines 50–173 | dconf GNOME settings | `home/benjamin/desktop/gnome.nix` |
| `home.nix` lines 185–693 | home.packages (all) | Split across `home/benjamin/packages/` |
| `home.nix` lines 203–225 | sioyek-theme-toggle script | `home/benjamin/scripts/sioyek-theme.nix` |
| `home.nix` lines 270–320 | refresh-gmail-oauth2 script | `home/benjamin/scripts/gmail-oauth2.nix` |
| `home.nix` lines 416–506 | whisper-dictate + whisper-download-models | `home/benjamin/scripts/whisper.nix` |
| `home.nix` lines 521–694 | memory-monitor + claude-memory-tracker | `home/benjamin/scripts/memory-monitor.nix` |
| `home.nix` lines 736–803 | systemd user services (screenshot, ydotool) | `home/benjamin/services/` |
| `home.nix` lines 804–884 | memory monitoring services | `home/benjamin/services/memory-services.nix` |
| `home.nix` lines 949–1119 | mbsyncrc inline text | `home/benjamin/email/mbsync.nix` |
| `home.nix` lines 1132–1200 | home.file config symlinks | Distributed across relevant modules |
| `home.nix` lines 1203–1335 | waybar settings | `home/benjamin/desktop/waybar.nix` |
| `home.nix` lines 1338–1392 | protonmail-bridge + notmuch | `home/benjamin/email/` |
| `home.nix` lines 1394–1578 | aerc config + bindings | `home/benjamin/email/aerc.nix` |
| `home.nix` lines 1580–1626 | swaylock + kanshi + sessionVars | `home/benjamin/desktop/` + `home/benjamin/core/shell.nix` |
| `unstable-packages.nix` | Duplicate overlay (unused) | Delete; merged into `overlays/unstable-packages.nix` |
| `modules/opencode.nix` | Unused HM module (good template) | Move to `home/benjamin/packages/ai-tools.nix` or activate |

### Proposed `lib/mkHost.nix` — Deduplication Helper

```nix
# lib/mkHost.nix
# Usage in flake.nix:
#   nixosConfigurations.nandi = mkHost { hostname = "nandi"; system = "x86_64-linux"; };
{ self, nixpkgs, home-manager, sops-nix, pkgs-unstable, pkgs, username, name, lectic, nix-ai-tools, ... }:
{ hostname, system ? "x86_64-linux", extraModules ? [] }:

nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./hosts/${hostname}
    sops-nix.nixosModules.sops
    { nixpkgs = { inherit system; config.allowUnfree = true; overlays = [ ... ]; }; }
    home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = import ./home/${username};
      home-manager.extraSpecialArgs = { inherit pkgs-unstable lectic nix-ai-tools; };
    }
  ] ++ extraModules;
  specialArgs = { inherit username name pkgs-unstable lectic; };
}
```

### Priority Fixes (Quick Wins Before Full Refactor)

These can be done independently and immediately:

1. **Delete `unstable-packages.nix`** (root) — it is unused and confusing.
2. **Fix `SASL_PATH`** hardcoded store hash — use `${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2`.
3. **Remove duplicate packages**: `stylua`, `cvc5`, `lectic`, `wl-clipboard` from `environment.systemPackages` (they belong in home.packages).
4. **Remove `neovim`** from `environment.systemPackages` (it's managed by `programs.neovim.enable`).
5. **Add `hosts/garuda/default.nix`** — the garuda host has hardware-configuration.nix but no corresponding flake entry.
6. **Extract USB installer inline module** from flake.nix into `hosts/usb-installer/default.nix`.

---

## Evidence and Examples

### Community Consensus on Structure (June 2026)

The NixOS & Flakes Book (the most widely-cited community reference) recommends:

```
├── flake.nix
├── home/           # Home Manager shared configs
│   ├── default.nix
│   └── programs/
├── hosts/          # Per-host NixOS configs
│   ├── machine-1/default.nix
│   └── machine-2/default.nix
└── modules/        # Reusable NixOS modules
```

The `unmovedcentre.com` "Anatomy of a NixOS Config" guide (widely referenced in 2025–2026) formalizes this into `common/core/` (always-on) vs. `common/optional/` (per-host opt-in) — a pattern ideal for this repo since most config applies to all hosts.

The `johns.codes` guide demonstrates the `mkHost` helper function pattern to eliminate the repeated `lib.nixosSystem { ... }` blocks currently in this repo's `flake.nix`.

### On Inline Shell Scripts

The community consensus (Nix Discourse 2025) is to extract large inline Bash scripts into either:
- Separate `.sh` files referenced via `pkgs.writeShellApplication` with `runtimeInputs`, or
- Dedicated `packages/my-script.nix` derivations that use `pkgs.writeShellApplication` with `checkPhase`

`writeShellApplication` (vs `writeShellScriptBin`) adds `shellcheck` validation and explicit runtime dependency injection — catching bugs at build time.

### On Overlays Separation

NixOS & Flakes Book states: "If an overlay becomes complex, it's best to define it in a separate file." Current practice of ~120 lines of overlay code in the `let` block of `flake.nix` is a clear violation of this guideline.

### flake-parts Consideration

`flake-parts` is a viable option for further refactoring the flake itself (used by nixpkgs CI, many large configs). However, it adds a new abstraction layer and is best introduced after the directory structure refactor is complete. **Not recommended for the initial refactor** — the current complexity is organizational, not structural, and can be addressed without `flake-parts`.

---

## Decisions

1. **Do not adopt flake-parts in this refactor.** The current flake structure is adequate; the problem is file organization, not flake architecture. Introducing flake-parts mid-refactor adds risk.

2. **Adopt `common/core/` + `common/optional/` pattern for hosts.** The single `configuration.nix` covering all hosts works today because all three machines share all config — but the USB installer already breaks this. The `optional/` pattern is the lowest-friction solution.

3. **Keep `packages/` directory as-is.** The custom derivations are already well-structured and small. No reorganization needed.

4. **Extract inline Bash scripts to their own module files under `home/benjamin/scripts/`.** Each script becomes a `pkgs.writeShellApplication` call with explicit `runtimeInputs`, making dependencies declarative.

5. **Merge `home-modules/` and `modules/` into `home/benjamin/` subdirectories.** The existing two-module-directory confusion is resolved by the new `home/` layout.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Breaking a host during staged migration | High | Migrate one module at a time; run `nix flake check` after each; keep backup branch |
| Home Manager import order causing option conflicts | Medium | Use `lib.mkDefault` / `lib.mkForce` in modules where needed; test with `home-manager build` before switch |
| USB installer config (200 lines in flake.nix) harder to test | Medium | Extract to `hosts/usb-installer/default.nix`; test with `nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage` |
| `SASL_PATH` hardcoded hash continues to break | High | Fix immediately (Quick Win #2 above) — this breaks email on every rebuild |
| `unstable-packages.nix` being imported by something not visible | Low | Grep confirms it is not referenced anywhere; safe to delete |
| Discord-bot services depend on sops secrets paths | Medium | Keep `sops` config co-located with discord-bot services in optional module; document ordering requirement |
| Three-way standalone HM / NixOS-HM / system package duplication | High | Priority cleanup: define clear policy (user tools in home.packages, system daemons in system packages) |

---

## Appendix: Search Queries Used

- "NixOS flake configuration modular structure best practices 2025 2026 hosts modules home-manager"
- "NixOS flake-parts configuration refactor modularity mkModule patterns 2025"
- "NixOS configuration structure hosts/ modules/ home/ directory layout community examples GitHub 2025"
- "NixOS nixos-modules home-modules split configuration.nix monolithic refactor overlays lib mkModule 2025"
- "NixOS overlays separate file overlays/ flake.nix refactor packages/ directory custom derivations 2025"

## Sources

- [Modularize Your NixOS Configuration — NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/modularize-the-configuration)
- [How do you structure your NixOS configs? — NixOS Discourse](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851)
- [Organizing system configs with NixOS — johns.codes](https://johns.codes/blog/organizing-system-configs-with-nixos)
- [Anatomy of a NixOS Config — Unmoved Centre](https://unmovedcentre.com/posts/anatomy-of-a-nixos-config/)
- [Nix Refactoring: Managing Your Configuration with Custom Modules — zenn.dev](https://zenn.dev/sei40kr/articles/nix-custom-modules-refactoring?locale=en)
- [How I Organized over 100 NixOS Modules Without Going Crazy — iampavel.dev](https://iampavel.dev/blog/nixos-module-organization)
- [Modularizing your NixOS configuration — blog.ricardof.dev](https://blog.ricardof.dev/modularizing-your-nixos-config/)
- [Flake Parts — flake.parts](https://flake.parts/)
- [Overlays — NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays)
- [Config Parts — NixOS Discourse](https://discourse.nixos.org/t/config-parts-modular-nixos-hm-configuration-construction-for-flake-parts/77901)

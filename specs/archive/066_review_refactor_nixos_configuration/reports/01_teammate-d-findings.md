# Research Report: Task #66 — Strategic Direction (Teammate D: HORIZONS)

**Task**: 66 - Review and Refactor NixOS Configuration
**Role**: Teammate D — Strategic Direction (HORIZONS)
**Artifact**: 01_teammate-d-findings.md
**Completed**: 2026-06-24
**Effort**: ~1.5h
**Scope**: Sequencing, roadmap alignment, long-term structural direction

---

## Key Findings

### 1. Configuration Scale and Composition

The repository currently contains two monolithic files:

- `configuration.nix` — 945 lines covering hardware-specific workarounds (Ryzen AI 300), desktop
  environment (GNOME + niri dual-session), system services, secrets (sops-nix), Discord bot, memory
  management, power management, networking, fonts, Nix settings, and shell config
- `home.nix` — 1,627 lines covering user packages, shell scripts (whisper-dictate, memory monitors,
  OAuth2 helpers), systemd user services, GNOME dconf, Waybar, email (notmuch + aerc + mbsync),
  XDG config, activation scripts, dotfile links, and the niri session

Combined: **2,572 lines across two files**. A `home-modules/` directory exists but is essentially
unused (disabled MCP-Hub module). A `modules/` directory contains only `opencode.nix`, `mcp-hub.nix`.

### 2. The Flake Has Meaningful Structure Already

`flake.nix` is well-structured with:
- Two real hosts (`nandi`, `hamsa`) sharing `configuration.nix` and `home.nix`
- Overlays factored into named `let` bindings (`claudeSquadOverlay`, `unstablePackagesOverlay`,
  `pythonPackagesOverlay`)
- `nixpkgs-unstable` threaded through `pkgs-unstable` properly
- A standalone `homeConfigurations.benjamin` block kept in sync with the NixOS-integrated HM

The structural problem is not in `flake.nix` — it is the flat monolithic `configuration.nix` and
`home.nix` that have grown to absorb everything.

### 3. In-Flight Task Clusters and Their Relationship to Task 66

**Active/in-flight Nix tasks**:

| Task | Status | Nature | Relationship to T66 |
|------|--------|--------|---------------------|
| 60 | NOT STARTED | `nix.settings.max-jobs`/`cores` limits | Natural home in `nix-settings` module |
| 61 | NOT STARTED | Pin nixpkgs to stable channel | Touches `flake.nix` inputs + `update.sh` |
| 62 | IMPLEMENTING | Swap piper → pico2wave; drop onnxruntime | Touches TTS block in `configuration.nix:635` |
| 63 | NOT STARTED | User-level HM GC + expire generations | Natural home in `nix-maintenance` or `nix-settings` module |
| 64 | NOT STARTED | Cache cleanup (not NixOS config change) | Independent (mostly imperative, not config) |
| 65 | IMPLEMENTING | python312 → python3 pin migration | Touches `home.nix:352` Python block |

**62 and 65 are already running.** Any refactor must not conflict with their active changes. Both
make targeted, line-addressed edits — they would create merge conflicts if task 66 restructures the
same regions during implementation.

### 4. The Dual homeConfigurations Problem

`flake.nix` maintains two paths for `home.nix`:
1. NixOS-integrated (`nixosConfigurations.*.modules`)
2. Standalone (`homeConfigurations.benjamin`)

`update.sh` runs both `nixos-rebuild switch` and `home-manager switch` sequentially. This works but
adds evaluation and build time. A refactor could consolidate or document this more clearly but
should **not** remove the standalone path until the user consciously decides to.

### 5. Hardcoded Username and Paths

`"benjamin"` and `/home/benjamin` appear scattered across `home.nix` (activation scripts,
`systemd.user.services` ExecStart paths, mail dir creation, etc.). The `username` variable is
threaded through `specialArgs` and used in `flake.nix`, but once inside `home.nix` the value is
re-hardcoded. This blocks multi-user or renamed-user scenarios.

### 6. The Agent/Dotfiles Boundary

The Claude Code agent system lives at `.dotfiles/.claude/` and `.config/nvim/.claude/`. The
dotfiles repo manages `config/claude/settings.json` and `config/claude/keybindings.json` via
`home.activation.claudeSettings` (copied not symlinked, so Claude Code can write runtime changes).
This is the correct approach. The `tts-notify.sh` hook lives in both repos (5 copies spanning
`.dotfiles/.claude/hooks/` and `.config/nvim/.claude/...` paths). Task 62 already touches these.

The boundary is clean in principle but the 5-copy duplication of `tts-notify.sh` is a maintenance
liability. The refactor should leave this boundary untouched (it belongs to a separate concern)
while ensuring module organization does not accidentally capture or shadow agent config files.

### 7. Current Module Opportunities Visible in the Monolith

Identifiable functional clusters within the existing files that could become modules:

**In `configuration.nix`**:
- `hardware/` — kernel packages, params, modprobe, blacklist, graphics, uinput, bluetooth
- `power/` — power-profiles-daemon, udev AC rules, earlyoom, zram, swapDevices, vm.sysctl
- `desktop/` — GNOME, niri, XDG portal, display manager, dconf GDM profile, wallpapers
- `networking/` — NetworkManager, firewall, avahi, geoclue2, automatic-timezoned
- `services/` — printing, pipewire, fwupd, libinput, unclutter, sops secrets
- `nix-settings/` — `nix.settings`, `nix.gc`, `nix-ld` libraries, `nixpkgs.config`
- `bot/` — Discord bot + opencode-serve systemd services, discordBotPython env

**In `home.nix`**:
- `packages/` — the ~100-entry `home.packages` list
- `shell/` — fish config, zoxide, prompt
- `email/` — himalaya, mbsync, notmuch, aerc, protonmail-bridge, OAuth2 timer
- `desktop/` — dconf GNOME settings, waybar, mako, kanshi, XDG, cursor
- `scripts/` — whisper-dictate, memory monitors, OAuth2 helper, sioyek-theme-toggle
- `services/` — systemd user services (ydotool, memory-monitor, screenshot-path-copy, gmail-oauth2)
- `dev-tools/` — neovim, git, Python env, Claude/agent activation scripts
- `tts-stt/` — picotts, whisper-cpp, vosk model link, piper removal artifacts

---

## Roadmap Alignment

The ROADMAP.md is empty ("No items yet"). Task 66 is therefore the opportunity to **write the
roadmap** in the form of a module structure: each module becomes a named concern that can be
independently tracked, evolved, or replaced.

The implicit roadmap emerging from the in-flight task queue is:

1. **Stability first** — fix OOM (60), stop source-building (61), clean disk (64)
2. **Reduce closure bloat** — drop onnxruntime/piper (62, done), migrate python (65, done)
3. **Maintenance automation** — user-level GC (63), periodic cache cleanup (64)
4. **Structural refactor** — cleaner modules, second-host readiness, documented workflows (66)

Task 66 is correctly positioned at the **end of the current priority cluster**, not the beginning.

---

## Sequencing Recommendation (vs Tasks 60–65)

### Current State

- 62 (IMPLEMENTING), 65 (IMPLEMENTING) — these are active. Do not refactor their target regions.
- 60, 61, 63, 64 (NOT STARTED) — queued but not yet in progress.

### Recommended Sequence

```
[NOW]   62 complete → applied to configuration.nix:635 (TTS swap)
[NOW]   65 complete → applied to home.nix:352 (Python env)
[THEN]  60 + 61 + 63 implement → nix.settings + flake inputs + HM GC
[THEN]  64 implement → cache cleanup (imperative, config-independent)
[LAST]  66 implement → structural refactor with clean slate
```

**Rationale**: Tasks 60/61/63 are small, targeted, and introduce new `nix.*` settings blocks that
will predictably land in a `nix-settings` module during the refactor. Letting them land first means
the refactor is moving settled code, not code that is about to change. Task 64 is largely
imperative (cache deletion) with only minor config changes (maybe adding systemd-tmpfiles rules) —
also fine to land before T66.

**Risk of early refactor**: If task 66 restructures before 60/61/62/63/65 complete, any
implementation of those tasks will face a changed file layout and must hunt for the new module
location. This is a concrete merge-risk since 62 and 65 are already active.

**The one exception**: Task 61 (channel pin) touches `flake.nix` inputs and `update.sh`, neither
of which the refactor should need to restructure. It can proceed in parallel with T66 planning, as
long as the T66 implementation does not begin until T61 completes.

### Decision

**Task 66 implementation should start after tasks 62 and 65 are confirmed complete, and after 60,
61, and 63 are implemented.** Tasks 64 (cache cleanup, imperative) can proceed in parallel since
it does not modify `.nix` files. Task 66 planning and research can proceed now.

---

## Strategic Scoping for Task 66

### What Task 66 SHOULD Include

**Phase A — Module Extraction (the core refactor)**

1. Create `modules/system/` for NixOS modules, `modules/home/` for Home Manager modules
2. Extract the 7–8 functional clusters from `configuration.nix` into `modules/system/*.nix`
3. Extract the 8–10 functional clusters from `home.nix` into `modules/home/*.nix`
4. `configuration.nix` becomes a thin `imports` list (target: ~50 lines)
5. `home.nix` becomes a thin `imports` list (target: ~50 lines)

**Phase B — Variable Hygiene**

6. Replace hardcoded `"benjamin"` and `/home/benjamin` in `home.nix` modules with `config.home.username` and `config.home.homeDirectory`
7. Pass the `username` variable consistently via `specialArgs` rather than re-hardcoding

**Phase C — Documentation and Workflow**

8. Add a `docs/how-to-add-package.md` documenting the exact process: edit `modules/home/packages.nix`, rebuild, test
9. Add a `docs/how-to-add-service.md` documenting the NixOS module pattern vs HM service pattern
10. Update `README.md` with the module map so it serves as the entry point for future changes

**Phase D — flake.nix Deduplication**

11. The ISO and USB-installer configurations in `flake.nix` duplicate all the shared module list.
    Extract a `mkHost` helper function to reduce boilerplate while preserving per-host overrides.
12. Consider moving the overlay definitions to `overlays/` as separate files, imported by `flake.nix`

### What Task 66 SHOULD NOT Include

**Out of scope**:
- Any new package additions or removals (those are separate tasks)
- Switching the nixpkgs channel (task 61)
- Adding GC settings (task 63) — they will already be in place
- nix-darwin or multi-user support (premature — `hamsa` exists in flake but shares hardware-configurations indicating a second real NixOS machine, not macOS)
- Converting to a Nix-based secrets alternative (sops-nix is working)
- Merging or eliminating the standalone `homeConfigurations` path (functional decision, not refactor)
- Reorganizing `packages/` custom derivations (they are already well-structured)
- Any changes to the `.claude/` agent system (separate concern, separate repo boundary)

**Why these exclusions matter**: The goal of a structural refactor is to reduce cognitive load and
maintenance surface. Adding features or switching channels during a refactor multiplies risk. Keep
the diff semantically inert — same behavior, different layout.

---

## Long-Term Opportunities

### 1. Host-Specific Modules Pattern

`hamsa` and `nandi` both import the same `configuration.nix`. The `hosts/` directory has
`hardware-configuration.nix` for each. The right long-term pattern is:

```
hosts/
  nandi/
    hardware-configuration.nix
    host.nix          # nandi-specific overrides (hostname, hardware quirks)
  hamsa/
    hardware-configuration.nix
    host.nix          # hamsa-specific overrides
modules/system/       # shared system modules
modules/home/         # shared home modules
```

This makes adding a third host trivial: copy the hardware-configuration, write a 20-line `host.nix`
with overrides, add an entry to `flake.nix`. The current structure is already close to this; the
refactor just needs to make it explicit.

### 2. `mkHost` / `mkUser` Abstractions

The four `lib.nixosSystem` calls in `flake.nix` share 90% of their structure. A `mkHost` function
in `flake.nix`'s `let` block would reduce copy-paste drift. Example:

```nix
mkHost = hostName: extraModules: lib.nixosSystem {
  inherit system;
  modules = sharedModules ++ extraModules ++ [
    { networking.hostName = hostName; }
  ];
  specialArgs = sharedArgs;
};
```

### 3. A Documented `nix-settings` Module as the Policy Home

When task 60 (resource limits) and 61 (channel pin) land, their settings will be scattered across
`configuration.nix`. Extracting a `modules/system/nix-settings.nix` creates a single authoritative
location for all Nix daemon policy:

```
modules/system/nix-settings.nix
  nix.settings.max-jobs = 8;              # task 60
  nix.settings.cores = 4;                 # task 60
  nix.settings.experimental-features = [...];
  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = [...];
```

This answers the question "where does Nix policy live?" definitively for future agents and
contributors.

### 4. Channel Strategy Documentation

Task 61 proposes pinning to `nixos-26.05` stable. The refactor should document the channel
decision in a comment at the top of `flake.nix` (or in a new `docs/channel-strategy.md`) explaining:
- Why some inputs track unstable (niri, nix-ai-tools)
- Why `home-manager` tracks a stable release
- When to run `nix flake update` vs when it is blocked

### 5. Cache Health as a First-Class Concern

The recurring OOM and source-build problems (tasks 60/61/65) suggest cache health is an ongoing
maintenance concern, not a one-time fix. After the refactor, a `modules/system/nix-settings.nix`
should include:
- `nix.settings.builders-use-substitutes = true`
- `nix.settings.substituters` pointing to the correct cache(s)
- Comments explaining the unstable→cache lag risk and mitigation

### 6. The `update.sh` Problem

`update.sh` runs `nix flake update` unconditionally on every rebuild (see task 61). After task 61
lands, `update.sh` should become a separate `update-flake.sh` that is opt-in, while the default
rebuild workflow only runs `nixos-rebuild switch` and `home-manager switch` against the existing
lockfile. The refactor could document or restructure this without implementing the channel pin
change itself.

---

## Confidence Level

**High confidence** on:
- Sequencing (wait for 62 + 65 to complete, implement after 60/61/63 settle)
- Module extraction approach (this is standard practice; risk is low given the clear clusters)
- `mkHost` helper value (eliminates 4x duplication in `flake.nix`)
- Scope exclusions (what NOT to include is as important as what to include)

**Medium confidence** on:
- Exact module naming and boundaries (will need coordination with Teammate A/B findings on structure)
- Whether to fold `nix-settings` absorption of tasks 60/63 into task 66 or keep them separate
  (either works; depends on sequencing decision)

**Lower confidence** on:
- Whether the standalone `homeConfigurations` path should be removed (functional trade-off that
  only the user can decide — agent should document options, not decide)
- Timeline for task 61 (channel migration is higher-risk than it appears; might delay T66 if 26.05
  introduces breakage)

---

## Summary

The refactor is well-motivated: 2,572 lines across two files, no module structure, and a queue of
in-flight tasks (60–65) that are all adding settings to the same flat files. The strategic call is
to **let the in-flight tasks land first** (especially 62 and 65 which are already active), then
implement the refactor as a semantically inert restructuring. Task 66 should extract ~15 named
modules across `modules/system/` and `modules/home/`, collapse `configuration.nix` and `home.nix`
to thin import lists, fix hardcoded username references, and add a `mkHost` helper to eliminate
the four-way duplication in `flake.nix`. It should explicitly not include new features, channel
changes, or agent-system boundary changes.

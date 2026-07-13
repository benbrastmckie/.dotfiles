# Research Report: Task #87

**Task**: 87 - hosts/ structural cleanup
**Started**: 2026-07-05T05:47:38Z
**Completed**: 2026-07-05T06:10:00Z
**Effort**: Small (item 1: doc-only, ~15 min; item 2 optional stretch: ~20 min incl. verification)
**Dependencies**: 86 (module convention + aggregators) — landed, `834943a`
**Sources/Inputs**: current `flake.nix`, `lib/mkHost.nix`, `hosts/` tree, `hosts/README.md`,
  task 86 artifacts (report/summary/plan), `nix flake check --no-build` baseline run,
  specs/081 design docs (`reports/01_repo-organization-review.md`, `reports/02_team-research.md`,
  `design/target-layout.md` §1.3/§3/§4.2)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, `.claude/rules/nix.md`

## Executive Summary

- **Item 1 is NOT verify-only** — task 86 explicitly left `hosts/README.md` untouched (confirmed
  both by direct file read and by task 86's own report/summary, which name this exact deferral to
  task 87). The obsolete inline-`nixosSystem` example at `hosts/README.md:28-37` is unchanged and
  must be rewritten to document the `mkHost` factory.
- **Item 2 (ISO extraction) is genuinely optional** and has one real correctness gotcha: the
  ISO's inline module closes over the outer `system` let-binding from `flake.nix`'s `outputs`
  scope (`nixpkgs.hostPlatform = system;`); a naive cut-and-paste into a standalone
  `hosts/iso/default.nix` file loses that closure. Fix: use `pkgs.system` (already available as a
  module arg) instead of the closed-over `system` — zero `specialArgs` changes needed.
- The ISO config **cannot** be routed through `mkHost` itself (not part of this task's scope
  regardless): `mkHost.nix:31` unconditionally requires
  `hosts/<hostname>/hardware-configuration.nix`, which a generic installer image doesn't have.
  `target-layout.md` confirms `lib/mkHost.nix` stays "unchanged internals" — the extraction is a
  pure file-move of the ISO-specific module body into `hosts/iso/default.nix`, not a
  mkHost-unification.
- Baseline `nix flake check --no-build` passes today (all 5 nixosConfigurations + homeConfigurations
  evaluate cleanly, with pre-existing `boot.zfs.forceImportRoot` warnings on `iso`/`usb-installer`
  — task 68 lineage, not to be touched).
- Verification for the optional item can use `nix eval` `drvPath` comparison (works even though
  `iso`/`usb-installer` are excluded from the build-diff harness and are not reliably buildable).

## Context & Scope

Task 87 (blueprint row 6, depends on subtask 5/task 86) has two parts:

1. **Required**: rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example
   (currently lines 28-37) to document the current `mkHost` factory pattern.
2. **Explicitly optional stretch**: extract the ~60-line ISO inline config block
   (`flake.nix:118-175`) to `hosts/iso/default.nix` for symmetry with other hosts — scope
   strictly to wiring; do not touch task 68's broken zfs-kernel state; exclude `iso`/
   `usb-installer` from any build-diff harness.

Verification level for both: build-only inertness (`nix flake check`); `iso`/`usb-installer`
build state must remain exactly as (un)buildable as before task 87 (no new regression
attributable to this subtask).

## Findings

### Current state of `hosts/README.md` (item 1 — confirmed NOT done by task 86)

Read directly (2026-07-05): `hosts/README.md` lines 28-37 still show:

```nix
nixosConfigurations = {
  garuda = nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      ./hosts/garuda/hardware-configuration.nix
    ];
  };
};
```

This predates `lib/mkHost.nix` entirely (no `mkHost` factory, no `home-manager` module, no
`sops-nix`, wrong per-host list). Task 86's own report
(`specs/086_module_convention_discord_bot_opt_in/reports/01_module-convention-discord-bot-opt-in.md:117,252,280,369`)
and summary (`.../summaries/01_module-convention-opt-in-summary.md:54`) explicitly confirm this
file was left untouched and named as task 87's scope. **This item is a live rewrite, not
verify-only.**

The rest of `hosts/README.md` (lines 1-26, 39-51) is largely accurate but has two smaller drifts
worth fixing in the same edit for consistency (not separately gated, low risk, doc-only):
- "Structure" section (line 19-23) says every host directory contains only
  `hardware-configuration.nix` — no longer true: `nandi/` and `usb-installer/` also carry a
  `default.nix` (per-host opt-in module, per `.claude/rules/nix.md`'s Optional/Host-Toggled
  convention), and `garuda/`, `nandi/` carry a `README.md`.
- "Available hosts" line (line 49) already correctly lists `garuda, nandi, hamsa, usb-installer`
  — no `iso` (consistent with `iso` not being a `hosts/<name>/` directory today). If the optional
  item 2 is taken, `iso` gains a `hosts/iso/` directory and should be added to this list and to
  the "Hosts" section header list (lines 5-17) as a fifth entry, with a note that it is wired
  directly via `lib.nixosSystem` in `flake.nix` rather than via `mkHost` (see below).

### Current `mkHost` factory (`lib/mkHost.nix`, unchanged by task 86 except discord-bot wiring elsewhere)

```nix
{ nixpkgs, home-manager, sops-nix, nixpkgsConfig, username, name, pkgs-unstable,
  lectic, nix-ai-tools, system, root }:
{ hostname, extraModules ? [], extraSpecialArgs ? {} }:
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    "${root}/configuration.nix"
    "${root}/hosts/${hostname}/hardware-configuration.nix"
    { networking.hostName = hostname; }
    sops-nix.nixosModules.sops
    { nixpkgs = nixpkgsConfig; }
    home-manager.nixosModules.home-manager
    { home-manager.useGlobalPkgs = true; home-manager.useUserPackages = true;
      home-manager.users.${username} = import "${root}/home.nix";
      home-manager.extraSpecialArgs = { inherit pkgs-unstable lectic nix-ai-tools; }; }
  ] ++ extraModules;
  specialArgs = { inherit username name pkgs-unstable; lectic = <resolved>; } // extraSpecialArgs;
}
```

Call sites in `flake.nix` (all current, all working):
- `nandi = mkHost { hostname = "nandi"; extraModules = [ ./hosts/nandi/default.nix ]; };`
- `hamsa = mkHost { hostname = "hamsa"; };`
- `garuda = mkHost { hostname = "garuda"; };`
- `usb-installer = mkHost { hostname = "usb-installer"; extraModules = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ./hosts/usb-installer/default.nix ]; extraSpecialArgs = { inherit niri; }; };`

This is the pattern the README rewrite must document, using `usb-installer` (which exercises
both `extraModules` and `extraSpecialArgs`) as the richest illustrative example, plus the
simpler `hamsa`/`garuda` one-liners.

### ISO's deliberate `mkHost` bypass (why it can't just call `mkHost`)

`flake.nix:116-117` comment: *"ISO configuration — uses nixpkgs CD template; kept explicit (not
via mkHost) because it needs the installer module and custom iso specialArgs (niri)."* That
comment undersells the real blocker: `mkHost.nix:31` hardcodes
`"${root}/hosts/${hostname}/hardware-configuration.nix"` as an **unconditional** module list
entry — there is no `hosts/iso/hardware-configuration.nix` and there should never be one (an
installer ISO is not tied to specific hardware). Making `mkHost` tolerate a hostname with no
hardware-configuration.nix would mean touching `lib/mkHost.nix` itself, which `target-layout.md`
line 69 explicitly freezes ("`lib/mkHost.nix` — unchanged internals; per-host wiring stays
explicit"). **Conclusion: do not attempt mkHost-unification for `iso`.** The "symmetry" the
design doc and task description ask for is *only* that the ISO's own config content lives in a
`hosts/iso/default.nix` file, matching the shape of `hosts/usb-installer/default.nix` and
`hosts/nandi/default.nix` — not that `iso` routes through `mkHost`.

### The ~60-line inline block and its one closure gotcha

`flake.nix:118-175`, the `iso` entry, has three parts:
1. Scaffolding shared conceptually with `mkHost` (configuration.nix, sops-nix, nixpkgs overlay
   application, home-manager block) — **do not extract this**, it stays in `flake.nix` because
   `iso` doesn't use `mkHost`.
2. Two ISO-only module-list one-liners: the CD-DVD installer module path and
   `{ networking.hostName = "nixos-iso"; }` — trivial, could stay inline or move; not required to
   move for "symmetry" (usb-installer keeps its cd-dvd module reference inline in `flake.nix`'s
   `extraModules` list too, not inside `hosts/usb-installer/default.nix`).
3. The anonymous inline module function at lines 138-166
   (`({ pkgs, lib, lectic, ... }: { isoImage...; nixpkgs.hostPlatform = system; networking...;
   environment.systemPackages = [...]; })`) — **this is the ~60-line block to extract**, and it
   is the direct structural analog of `hosts/usb-installer/default.nix`'s
   `{ pkgs, lib, ... }: { ... }` file.

**Gotcha**: `nixpkgs.hostPlatform = system;` inside that function does NOT receive `system` as a
module arg — it captures the outer `let system = "x86_64-linux";` binding from `flake.nix`'s
`outputs` scope via **lexical closure**, because the function is defined inline inside that
scope. A plain cut-and-paste into a standalone `hosts/iso/default.nix` file breaks this: NixOS
modules only receive `config`, `lib`, `pkgs`, and whatever is in `specialArgs`/`extraSpecialArgs`
— `system` is not currently in the `iso` entry's `specialArgs` (`flake.nix:168-174` only has
`username`, `name`, `pkgs-unstable`, `niri`, `lectic`). Extracting verbatim would produce an
`undefined variable 'system'` eval error.

**Recommended fix** (avoids touching `specialArgs` at all): replace
`nixpkgs.hostPlatform = system;` with `nixpkgs.hostPlatform = pkgs.system;` — `pkgs` is already a
standard module arg, and `pkgs.system` is the platform string the `pkgs` set was instantiated
with (identical value here, since this `pkgs` was built with `nixpkgsConfig.system = "x86_64-linux"`).
This is a same-behavior substitution, not a functional change.

Secondary, non-required cleanup: the function signature also declares an unused `lectic` arg
(never referenced in the body) — safe to drop to `{ pkgs, lib, ... }:` when extracting, since
`...` already tolerates extra specialArgs being ignored. Purely cosmetic; leaving it in is also
fine (harmless).

### Proposed `hosts/iso/default.nix` (if the optional stretch is taken)

```nix
# ISO installer-specific NixOS configuration.
# Extracted from the `iso` nixosConfiguration's inline module in flake.nix for symmetry with
# other hosts/<name>/default.nix files (e.g. hosts/usb-installer/default.nix). The iso
# nixosConfiguration is NOT built via lib/mkHost.nix — mkHost.nix unconditionally requires a
# hosts/<hostname>/hardware-configuration.nix, which a generic installer image doesn't have —
# so it stays wired explicitly in flake.nix; only this ISO-specific module content moves here.
{ pkgs, lib, ... }:
{
  # ISO-specific configurations
  isoImage.edition = lib.mkForce "nandi";
  isoImage.compressImage = true;
  # Enable copy-on-write for the ISO
  isoImage.squashfsCompression = "zstd";
  # Make the ISO compatible with most systems
  nixpkgs.hostPlatform = pkgs.system;
  # Configure networking for ISO with NetworkManager only
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "iwd"; # Use iwd backend for better performance
    };
    # Explicitly disable wpa_supplicant
    wireless.enable = false;
  };
  # Enable basic system utilities for the live environment
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    # Add networking tools that might be helpful during installation
    iw
    wirelesstools
    networkmanager
  ];
}
```

And in `flake.nix`, the `modules` list for `iso` shrinks from the 30-line anonymous function to
a single path entry (`./hosts/iso/default.nix`) inserted at the same position — everything else
in the `iso` block (the `lib.nixosSystem` call, `configuration.nix`, cd-dvd module, hostName
override, `sops-nix`, `nixpkgs = nixpkgsConfig`, the home-manager block, and `specialArgs`)
stays exactly as-is.

### Baseline verification state (recorded before any change)

`nix flake check --no-build` (run 2026-07-05, on the current dirty-but-unrelated tree — see Risks):

```
checking NixOS configuration 'nixosConfigurations.nandi'...
checking NixOS configuration 'nixosConfigurations.hamsa'...
checking NixOS configuration 'nixosConfigurations.garuda'...
checking NixOS configuration 'nixosConfigurations.iso'...
evaluation warning: `boot.zfs.forceImportRoot` is using the default value of `true`. ...
checking NixOS configuration 'nixosConfigurations.usb-installer'...
evaluation warning: `boot.zfs.forceImportRoot` is using the default value of `true`. ...
checking flake output 'homeConfigurations'...
all checks passed!
```

All five `nixosConfigurations` (including `iso` and `usb-installer`) currently **evaluate**
cleanly; the `boot.zfs.forceImportRoot` warnings are pre-existing (task 68 zfs-kernel lineage)
and must not be treated as new regressions or "fixed" incidentally by this task. Whether `iso`/
`usb-installer` currently **build** (vs. merely evaluate) was not tested here — per task 68
lineage and the design doc's §4.2 exclusion, they are "not reliably buildable regardless," and
this task's contract is only that their build state doesn't get worse, not that it gets fixed.

### Recommended verification sequence for implementation

1. `git add hosts/README.md` (item 1) and, if item 2 is taken, `git add hosts/iso/default.nix flake.nix` — **never `git add -A`**, per the repo's mandatory git-add-before-verify protocol (`target-layout.md` §4.1) and this task's own inherited cross-cutting instruction.
2. `nix flake check --no-build` (or full `nix flake check`) — expect identical "all checks
   passed!" output, same two pre-existing zfs warnings, no new warnings/errors.
3. **Item 2 only**, since `iso`/`usb-installer` are excluded from the build-diff harness and
   `nix store diff-closures` needs a real build: use eval-time equivalence instead —
   `nix eval --raw .#nixosConfigurations.iso.config.system.build.toplevel.drvPath` captured
   **before** the extraction and again **after**; an identical `.drv` path is a strong,
   cheap proof of byte-for-byte config equivalence without requiring `iso` to actually build
   (sidesteps the zfs-kernel breakage entirely — this command only evaluates, it does not
   realize the derivation).
4. For `nandi`/`hamsa`/`garuda`/`homeConfigurations.benjamin` (the hosts actually in the
   build-diff harness per §4.2), item 1 and item 2 as scoped here touch neither `lib/mkHost.nix`
   nor those hosts' modules — no rebuild or diff-closures run is strictly necessary, but running
   the full §4.2 harness costs little and is the documented default for any Nix-tree-touching
   subtask.

## Decisions

- Item 1 (`hosts/README.md` rewrite) is **required work**, not verify-only — task 86 explicitly
  deferred it.
- Item 2 (ISO extraction) is **optional**; if skipped, no code changes are needed beyond item 1
  and this report stands as the researched rationale for skipping it.
- If item 2 is taken, do **not** attempt to route `iso` through `mkHost` — extract only the
  ISO-specific inline module body to `hosts/iso/default.nix`, keep the `lib.nixosSystem` call in
  `flake.nix` bypassing `mkHost` exactly as today, and fix the `system` closure dependency via
  `pkgs.system` rather than adding `system` to `specialArgs`.
- `lib/mkHost.nix` itself is out of scope for any change in this task (per `target-layout.md`
  line 69 and the mkHost-hardware-configuration.nix blocker documented above).
- `hosts/hamsa/`'s missing `README.md` (flagged in the original review report as an
  inconsistency) is explicitly **out of scope** for task 87 — blueprint row 6 only covers
  `hosts/README.md` (the directory-level doc) and the ISO extraction; per-host README parity is
  not named in this subtask.

## Risks & Mitigations

- **Risk**: working tree currently has unrelated dirty state (`specs/TODO.md`, `specs/state.json`,
  task 86/93/069/088 artifacts) from adjacent orchestration activity. Since `flake.nix` uses
  `root = self`, `nix flake check` only evaluates git-tracked content — the mandatory
  git-add-before-verify protocol (§4.1) means whatever is staged determines what gets checked.
  **Mitigation**: stage only `hosts/README.md` (and, if item 2 is taken, `hosts/iso/default.nix`
  + `flake.nix`) explicitly before verifying — never `git add -A`, which would also stage the
  unrelated dirty task-orchestration files.
- **Risk**: extracting the ISO module verbatim (copy-paste without the `pkgs.system` fix) would
  silently break `iso` evaluation with an "undefined variable `system`" error, which could be
  mistaken for a pre-existing task-68 zfs issue rather than a new regression from this task.
  **Mitigation**: documented above; use `pkgs.system`, and confirm via `nix flake check --no-build`
  that `nixosConfigurations.iso` still evaluates (it does today, per the baseline run recorded in
  this report) before and after the change.
- **Risk**: scope creep into `lib/mkHost.nix` (attempting real mkHost-unification for `iso`) would
  touch a file `target-layout.md` explicitly wants left unchanged, and would require handling
  `iso`'s missing `hardware-configuration.nix` — a materially larger, non-optional-stretch-sized
  change. **Mitigation**: this report explicitly rules that path out; the recommended extraction
  is a pure file-move.
- **Risk**: treating `iso`/`usb-installer`'s zfs-kernel build warnings/failures as something this
  task should fix. **Mitigation**: explicitly out of scope (task 68 lineage); baseline recorded
  above (warnings present, evaluation succeeds) so any deviation after this task's changes is
  attributable correctly.

## Appendix

### Files read
- `/home/benjamin/.dotfiles/flake.nix`
- `/home/benjamin/.dotfiles/lib/mkHost.nix`
- `/home/benjamin/.dotfiles/hosts/README.md`
- `/home/benjamin/.dotfiles/hosts/nandi/default.nix`
- `/home/benjamin/.dotfiles/hosts/nandi/README.md`
- `/home/benjamin/.dotfiles/hosts/garuda/README.md`
- `/home/benjamin/.dotfiles/hosts/usb-installer/default.nix`
- `/home/benjamin/.dotfiles/specs/086_module_convention_discord_bot_opt_in/reports/01_module-convention-discord-bot-opt-in.md`
- `/home/benjamin/.dotfiles/specs/086_module_convention_discord_bot_opt_in/summaries/01_module-convention-opt-in-summary.md`
- `/home/benjamin/.dotfiles/specs/086_module_convention_discord_bot_opt_in/plans/01_module-convention-opt-in.md`
- `/home/benjamin/.dotfiles/specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
- `/home/benjamin/.dotfiles/specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
- `/home/benjamin/.dotfiles/specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`

### Commands run
- `nix flake check --no-build` (baseline, all checks passed, pre-existing zfs warnings only)
- `git status --short`, `git log --oneline -5` (confirmed task 86 landed at `834943a`, tree
  otherwise dirty with unrelated orchestrator files)
- `find hosts -maxdepth 2`, `grep`/`cat` over seed reports and design docs

### References
- `specs/081_.../reports/01_repo-organization-review.md:79-94` (hosts/ and lib/ sections)
- `specs/081_.../reports/02_team-research.md:160` (subtask blueprint row 6), `:125-126` (per-host
  wiring decision), `:323` (hosts/README.md:28-37 citation)
- `specs/081_.../design/target-layout.md:68-80` (§1.3 tree), `:150-...:160` (§3 blueprint row 6),
  `:213-228` (§4.2 baseline harness + iso/usb-installer exclusion)

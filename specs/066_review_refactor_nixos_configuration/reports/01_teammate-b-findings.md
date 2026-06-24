# Research Report: Task #66 — Teammate B (Alternative Approaches / Prior Art)

**Task**: 066 - Review and refactor NixOS configuration  
**Focus**: Alternative frameworks, prior art, performance prior art  
**Teammate Role**: B — Alternative Approaches / Prior Art  
**Artifact Number**: 01  
**Completed**: 2026-06-24

---

## Key Findings

1. **The dominant community pattern for personal dotfiles in 2026 is a hand-rolled `hosts/` + `modules/` layout**, possibly with `flake-parts` for output structure — but without the opinionated auto-discovery of Snowfall or nixos-unified. Community consensus in NixOS Discourse is that frameworks often obscure fundamentals without solving real problems for single-machine configs.

2. **The current `flake.nix` has two concrete structural problems** that matter regardless of any framework choice: (a) three overlays defined inline as let-bindings inflating the file to ~200 lines; and (b) a `nixpkgs-unstable` input that is functionally a duplicate of `nixpkgs` (both point to `nixos-unstable`), adding unnecessary eval cost with no benefit.

3. **`flake-parts` is the only framework worth considering**, and only for its "every file is a flake-parts module" idiom — it lets you split the monolithic `flake.nix` into files like `overlays/default.nix`, `packages/default.nix`, and `hosts/nandi.nix` without imposing directory conventions on your NixOS modules themselves.

4. **Snowfall-lib, nixos-unified, and haumea are over-engineered for a single-host personal config.** Each imposes opinionated directory structures and adds a dependency that must be kept in sync. At least one key maintainer (Snowfall) has "moved on" from the project as of mid-2025.

5. **The "import all and enable" pattern** is valuable for the `modules/` directory: import all modules unconditionally via a `default.nix` aggregator, then use `enable` flags per-host. This eliminates the N-host × M-module import bookkeeping problem if a second or third host is ever added.

6. **Performance wins are structural, not framework-dependent**: (a) eliminate the duplicate `nixpkgs-unstable` input or make it truly `follows` correctly; (b) move overlays out of `let` bindings in `flake.nix` into the `nixpkgs.overlays` module option so they compose cleanly; (c) avoid `import-from-derivation` (IFD) in custom packages.

---

## Framework / Approach Comparison

| Framework | What It Solves | Lock-in Level | Learning Curve | Multi-host Fit | Single-host Fit | Maintenance Health (2026) |
|-----------|---------------|---------------|----------------|----------------|-----------------|---------------------------|
| **Hand-rolled `hosts/` + `modules/`** | Nothing — pure Nix idioms | None | Low (standard Nix) | Good with "import all" pattern | Excellent | N/A — just Nix |
| **`flake-parts`** | Output schema boilerplate, per-system repetition | Low (thin wrapper) | Low–Medium | Good | Good (optional, incremental adoption) | Active, well-maintained |
| **`nixos-unified`** (srid) | Unified NixOS + nix-darwin + HM activation + autowiring | Medium (requires flake-parts + its module) | Medium | Excellent | Moderate over-engineering | Active |
| **Snowfall-lib** | Auto-discovery of packages/modules/homes/systems by directory convention | High (opinionated directory tree) | Medium–High | Good | Over-engineered; single-channel limitation | Maintenance concern — maintainer disengaged mid-2025 |
| **haumea / import-tree** | Auto-loading arbitrary `.nix` files into attr sets | Medium | Medium | Neutral | Adds complexity without clear benefit for small configs | Moderate (nix-community, less active) |
| **"import all and enable"** (pattern, not library) | N hosts × M modules import bookkeeping | None | Low | Very good | Good (future-proofs for new hosts) | N/A — just a pattern |
| **flake-utils** | Per-system iteration | Low | Low | Fine | Fine | Discouraged by community; superseded by `flake-parts` |

---

## Recommended Approach

### For this repo: **Incremental hand-rolled refactor + optional flake-parts**

**Recommended in order of value:**

**1. Fix the `nixpkgs-unstable` duplicate (performance + clarity)**  
The current `flake.nix` declares both `nixpkgs` and `nixpkgs-unstable`, both pointing to `nixos-unstable`. This means the flake evaluates two copies of nixpkgs unnecessarily. Options:
- If you truly need occasional stable-channel pinning: keep both, but have `nixpkgs` follow a release branch (`nixos-25.05`) and use `nixpkgs-unstable` only for packages that need edge versions.
- If you only want one unstable nixpkgs: remove `nixpkgs-unstable`, add the overlay trick `pkgs.extend` or just expose `pkgs` directly.

The current `nixpkgsConfig` struct already imports `nixpkgs` once with overlays applied — `pkgs-unstable` is then imported separately with different `config`. This dual-import is a known eval-cost pattern: the community recommendation is to consolidate into a single `import nixpkgs { ... overlays = [...]; }` where possible.

**2. Extract overlays from `flake.nix` into separate files**  
The three overlays (`claudeSquadOverlay`, `unstablePackagesOverlay`, `pythonPackagesOverlay`) are inline in `flake.nix`, making it ~200 lines of opaque let-bindings. Move each to `overlays/claude-squad.nix`, `overlays/unstable.nix`, `overlays/python.nix` and load them with:
```nix
overlays = [
  (import ./overlays/claude-squad.nix)
  (import ./overlays/unstable.nix { inherit pkgs-unstable; })
  (import ./overlays/python.nix)
];
```
This is the explicit-import pattern that `nixcademy` identifies as preferred over `extend`-based composition.

**3. Extract host-specific config from `flake.nix` using a `mkHost` helper**  
The four `nixosConfigurations` entries (`nandi`, `hamsa`, `iso`, `usb-installer`) repeat the same block structure with minor variation. A local `mkHost` function eliminates this:
```nix
let
  mkHost = hostname: extraModules: lib.nixosSystem {
    inherit system;
    modules = [
      ./configuration.nix
      ./hosts/${hostname}/hardware-configuration.nix
      { networking.hostName = hostname; }
      sops-nix.nixosModules.sops
      { nixpkgs = nixpkgsConfig; }
      home-manager.nixosModules.home-manager { ... }
    ] ++ extraModules;
    specialArgs = { ... };
  };
in {
  nixosConfigurations = {
    nandi = mkHost "nandi" [];
    hamsa = mkHost "hamsa" [];
    iso = mkHost "iso" [ ./hosts/iso/extras.nix ];
  };
}
```
This is idiomatic Nix — no framework needed.

**4. Consider `flake-parts` only if splitting `flake.nix` further**  
If you want to split `flake.nix` into multiple files (e.g., `packages/flake-module.nix`, `overlays/flake-module.nix`), `flake-parts` provides a clean mechanism. The "every file is a flake-parts module" pattern from NixOS Discourse is well-established. However, for a single-host personal repo, this is optional — a well-commented 80-line `flake.nix` is often easier to understand than a tree of flake-module files.

**5. Apply "import all and enable" to `modules/`**  
Create `modules/default.nix` that imports every file in the directory, then use `lib.mkEnableOption` in each module. Host configs enable what they need. This future-proofs the config for additional hosts.

---

## What to Explicitly Avoid (Over-Engineering)

- **Snowfall-lib**: Opinionated directory tree, single-channel limitation, maintenance concerns. Nothing it does can't be done with 30 lines of Nix.
- **nixos-unified**: Its value is in cross-platform NixOS + nix-darwin + standalone HM unification. This repo is Linux-only with NixOS-integrated HM — nixos-unified adds indirection with no benefit.
- **haumea / import-tree**: Auto-loading `.nix` files is magic that obscures what's actually being imported. For a personal config with a known, finite set of modules, explicit `imports = [...]` is cleaner and easier to debug.
- **flake-utils**: Community consensus is this is superseded by `flake-parts` and shouldn't be introduced in new configs. (Note: `utils` is already in the current flake inputs — it may be unused and a candidate for removal.)
- **Multiple `nixpkgs` imports without `follows`**: Each `import nixpkgs { ... }` in a flake is an independent evaluation. Minimize these to one primary import.
- **Autowiring**: Both Snowfall and nixos-unified offer directory scanning that automatically creates flake outputs. This is genuinely useful for 10+ hosts. For 2–4 hosts, the convention obscures intent.

---

## Evidence / Examples

### Current Redundancy: Dual nixpkgs
From `flake.nix` lines 5–7 and 39–46:
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
# Both point to the same ref. Two copies evaluated.
```
The NixOS Discourse thread "Unstable and stable inputs on flake.nix" (2024) documents exactly this pattern as a common inefficiency.

### Current Redundancy: 4× repeated home-manager block
Each of `nandi`, `hamsa`, `iso`, `usb-installer` contains the identical:
```nix
home-manager.nixosModules.home-manager {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${username} = import ./home.nix;
  home-manager.extraSpecialArgs = { ... };
}
```
A `mkHost` helper eliminates this repetition entirely.

### Flake-parts "every file is a module" pattern (NixOS Discourse 2024–2025)
```nix
# flake.nix with flake-parts
{
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      ./overlays/flake-module.nix
      ./packages/flake-module.nix
      ./nixos/flake-module.nix
    ];
    systems = [ "x86_64-linux" ];
  };
}
```
Each `flake-module.nix` file uses the `perSystem` and `flake` options from flake-parts.

### srid/nixos-config autowiring (reference only)
The most mature example of nixos-unified + flake-parts + autowiring for a personal multi-platform config. Structure:
```
configurations/nixos/nandi.nix  -> nixosConfigurations.nandi (auto)
configurations/home/benjamin.nix -> homeConfigurations.benjamin (auto)
modules/nixos/*.nix              -> imported automatically
packages/*.nix                   -> packages.x86_64-linux.* (auto)
```
This is worth studying as a reference ceiling — but not adopting wholesale for a single-host Linux-only config.

### Performance: Parallel Nix eval (Determinate Systems, 2025)
Determinate Nix 3.11.1 ships parallel evaluation (multi-threaded evaluator) with reported 3–4× speedups for large flakes. This is not yet in upstream Nix as of mid-2026. For personal configs, the bigger practical win is eliminating duplicate `import nixpkgs` calls and keeping the `flake.lock` updated to benefit from nixpkgs binary cache hits.

### Binary cache strategy for custom packages
For `claude-code.nix`, `opencode.nix`, `loogle.nix` etc. — these are not in `cache.nixos.org`. Options:
- **Cachix personal cache**: Free tier, push via `cachix push` in CI or post-rebuild. Add to `nix.settings.substituters`.
- **Local cache via `nix-serve`**: Serves `/nix/store` over HTTP; useful for LAN but not cloud.
- **Accept rebuild cost**: For <10 custom packages, local rebuild is often faster than cache lookup overhead on a fast machine.

The recommended minimum: add community caches that the custom inputs already use (e.g., `nix-community.cachix.org` for `nix-community/haumea`, `lean4.cachix.org` for the lean4 input). This avoids rebuilding lean4 from source, which is the most expensive input.

---

## Confidence Level

**High** on framework comparison and what to avoid — community discourse and documentation are consistent.  
**High** on the `mkHost` and overlay-extraction recommendations — these are direct observations from the current `flake.nix`.  
**Medium** on performance numbers — eval benchmarks are highly config-dependent; the structural guidance (avoid duplicate imports) is well-established, but exact speedups for this specific config would require measurement.  
**Medium** on binary cache strategy — depends on the user's rebuild frequency and network conditions.

---

## Sources

- [flake-parts official site](https://flake.parts/)
- [Flake Parts — Official NixOS Wiki](https://wiki.nixos.org/wiki/Flake_Parts)
- [nixos-unified: Introduction](https://nixos-unified.org/)
- [srid/nixos-unified GitHub](https://github.com/srid/nixos-unified)
- [srid/nixos-config GitHub](https://github.com/srid/nixos-config)
- [Snowfall Lib](https://github.com/snowfallorg/lib)
- [Snowfall Lib v2 — NixOS Discourse](https://discourse.nixos.org/t/snowfall-lib-v2/33015)
- [easy-hosts, ez-config, snowfall... what do you use? — NixOS Discourse](https://discourse.nixos.org/t/easy-hosts-ez-config-snowfall-what-do-you-use/61240)
- [haumea — nix-community GitHub](https://github.com/nix-community/haumea)
- [Pattern: every file is a flake-parts module — NixOS Discourse](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271/15)
- [Scaling NixOS with "Import All and Enable" Pattern](https://kobimedrish.com/posts/scaling_nixos_with_import_all_and_enable_pattern/)
- [Parallel Nix evaluation — Determinate Systems](https://determinate.systems/blog/parallel-nix-eval/)
- [Mastering Nixpkgs Overlays — Nixcademy](https://nixcademy.com/posts/mastering-nixpkgs-overlays-techniques-and-best-practice/)
- [Modularize Your NixOS Configuration — NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/modularize-the-configuration)
- [Unstable and stable inputs on flake.nix — NixOS Discourse](https://discourse.nixos.org/t/unstable-and-stable-inputs-on-flake-nix/50108)
- [Modularizing nix dotfiles for multiple machines — flyinggrizzly.net (2025)](https://www.flyinggrizzly.net/2025/04/modularizing-nix-dotfiles/)

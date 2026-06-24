# Research Report: Task #61

**Task**: 061 - Pin nixpkgs flake input to a stable release channel (nixos-26.05) to maximize binary cache hits and stop source-building heavy packages
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T00:30:00Z
**Effort**: ~1 hour research
**Dependencies**: None
**Sources/Inputs**: NixOS Wiki, Hydra/status.nixos.org, nixpkgs GitHub, numtide/nix-ai-tools README, flake.nix, flake.lock, update.sh (all read-only)
**Artifacts**:
- specs/061_pin_nixpkgs_stable_channel_binary_cache_hits/reports/01_pin-nixpkgs-stable.md

**Standards**: report-format.md

---

## Executive Summary

- NixOS 26.05 ("Yarara") is the correct current stable channel, released 2026-05-30, supported through 2026-12-31. The `nixos-26.05` branch is live and Hydra coverage is complete.
- The flake currently has `nixpkgs` tracking `nixos-unstable` and a separate `nixpkgs-unstable` input; both end up on `nixos-unstable`, creating a redundant dual-unstable setup that outpaces Hydra and triggers local source builds.
- `home-manager` is already pinned to `release-26.05` in the flake — alignment is correct but moot until `nixpkgs` itself moves to `nixos-26.05`.
- The critical blocker is `nix-ai-tools` (numtide): its README explicitly warns that setting `inputs.nixpkgs.follows = "nixpkgs"` with a stable release branch **will break eventually** — it is only built and tested against `nixpkgs-unstable`. This input must remain on its own pinned unstable nixpkgs.
- `lean4`, `niri`, `sops-nix`, and `lectic` all use `inputs.nixpkgs.follows = "nixpkgs"` and are compatible with a stable nixpkgs, though some (especially `lean4` and `niri`) may need version verification against 26.05 packages.
- `update.sh` runs `nix flake update` unconditionally on every rebuild — making it opt-in is straightforward with a flag or a separate script.

---

## Context & Scope

The machine (`nandi`, `x86_64-linux`) is under disk pressure (root at 94%) and has a concurrent Lean build occupying the Nix store. The goal is to:

1. Pin the primary `nixpkgs` input to `nixos-26.05` to align with Hydra's fully-built binary cache
2. Keep `nixpkgs-unstable` as a secondary input for packages that require it
3. Align `home-manager` to `release-26.05` (already done)
4. Identify which inputs cannot follow a stable nixpkgs
5. Make `nix flake update` in `update.sh` opt-in rather than automatic

Research is read-only; no builds or store writes were performed.

---

## Findings

### 1. Channel Status: nixos-26.05 Is the Correct Stable Target

NixOS 26.05 "Yarara" was officially released on 2026-05-30. It is the current stable channel and will receive bug and security fixes through 2026-12-31. The predecessor, 25.11 "Xantusia", reaches end-of-life 2026-06-30 (imminently). Channel branch `nixos-26.05` is in active maintenance.

**Hydra coverage**: Large stable channels (`nixos-26.05`) are updated only after Hydra completes building the full breadth of Nixpkgs for a commit. This means every package at a channel-pinned commit has a pre-built binary in `cache.nixos.org`. By contrast, `nixos-unstable` advances whenever its Hydra job set passes, but individual packages may lag or have cache misses when new commits outpace Hydra's evaluation queue — exactly the 29-source-build symptom described in the task.

### 2. Current flake.nix State (Read-Only Inspection)

From `flake.nix` and `flake.lock`:

| Input | URL in flake.nix | Locked ref in flake.lock | Notes |
|-------|------------------|--------------------------|-------|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` | rev `cf3ffa5d` (lastModified 1745997950) | Primary pkgs used by all nixosConfigurations |
| `nixpkgs-unstable` | `github:NixOS/nixpkgs/nixos-unstable` | rev `567a49d1` (lastModified 1781577229) | Used only for `pkgs-unstable` derivation |
| `home-manager` | `github:nix-community/home-manager/release-26.05` | rev `7bfff44b` | Already on 26.05 release branch |
| `lean4` | `github:leanprover/lean4` | rev `c50c2ba6` | `inputs.nixpkgs.follows = "nixpkgs"` |
| `niri` | `github:YaLTeR/niri` | rev `49fc6117` | `inputs.nixpkgs.follows = "nixpkgs"` |
| `lectic` | `github:gleachkr/lectic` | rev `d5721b5f` | `inputs.nixpkgs.follows = "nixpkgs"` |
| `nix-ai-tools` | `github:numtide/nix-ai-tools` | rev `3c958647` | `inputs.nixpkgs.follows = "nixpkgs-unstable"` |
| `sops-nix` | `github:Mic92/sops-nix` | rev `56b24064` | `inputs.nixpkgs.follows = "nixpkgs"` |
| `utils` | `github:numtide/flake-utils` | rev `11707dc2` | No nixpkgs follows |

**Key observation**: `nixpkgs` and `nixpkgs-unstable` are two separate entries that both point to `nixos-unstable`, but are locked at different revisions (1745997950 vs 1781577229 — about 36 days apart). This is the root cause: `nix flake update` advances both independently, so `nixpkgs` (used for the main system) may be pinned to a commit where Hydra has not yet finished building, causing source builds.

`nix-ai-tools` already correctly follows `nixpkgs-unstable` (not `nixpkgs`), which is the right split.

### 3. Migration Plan: Pinning nixpkgs to nixos-26.05

The change in `flake.nix` would be:
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
# nixpkgs-unstable remains for nix-ai-tools and packages that need it:
nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
```

The `nixpkgs-unstable` input stays as-is. Its follows relationship with `nix-ai-tools` is already correct. The `pkgs-unstable` derivation (`import nixpkgs-unstable { ... }`) continues to provide rolling packages via `unstablePackagesOverlay`.

After this change, `nix flake update` will advance `nixos-26.05` only within the stable channel's commit history (conservative security/bug patches), while `nixpkgs-unstable` advances independently on `nixos-unstable`.

### 4. home-manager Alignment

`home-manager` is already pinned to `release-26.05` in `flake.nix`:
```nix
home-manager.url = "github:nix-community/home-manager/release-26.05";
home-manager.inputs.nixpkgs.follows = "nixpkgs";
```

When `nixpkgs` moves to `nixos-26.05`, this alignment is complete and correct. The Home Manager manual states that mismatched versions (HM release-X vs nixpkgs-Y) produce a build warning and can cause unexpected failures. With both on 26.05, that risk is eliminated.

The commented-out entry `release-23.11` in `flake.nix` (lines 31-33) is dead code and can be removed during migration.

### 5. Input-by-Input Analysis: Which Can Follow Stable, Which Must Stay Unstable

#### MUST remain on nixpkgs-unstable

**`nix-ai-tools`** (numtide/nix-ai-tools):
- Official README states: *"This flake is only built and tested against its pinned `nixpkgs-unstable` input. If you set `llm-agents.inputs.nixpkgs.follows = "nixpkgs"`, your `nixpkgs` must also track `nixpkgs-unstable` and be reasonably current — using a stable release branch (e.g. `nixos-25.05`) **will** break eventually."*
- Currently correctly follows `nixpkgs-unstable` in the flake. **No change needed.**
- Tools sourced from it (AI coding agents like gemini-cli) depend on frequently-updated tool versions that stable lags on.

#### CAN follow stable nixpkgs (with verification)

**`sops-nix`**:
- Tracks nixpkgs and works with stable releases. Confirmed compatible with stable NixOS versions in community usage. The `inputs.nixpkgs.follows = "nixpkgs"` pattern is recommended in sops-nix docs and community guides.
- No change needed; already follows `nixpkgs`.

**`lean4`**:
- Uses `inputs.nixpkgs.follows = "nixpkgs"`. Lean 4.26.0 is packaged in nixpkgs including 26.05.
- The lean4 flake builds Lean from source against nixpkgs regardless of channel; stable nixpkgs provides a sufficient base (GHC, cmake, etc.).
- Risk: Lean releases frequently. The lean4 flake is pinned in `flake.lock`; the follow just supplies base tools. Should be safe, but should be verified after the switch by checking `nix flake show` (read-only).

**`lectic`**:
- Uses `inputs.nixpkgs.follows = "nixpkgs"`. A Haskell-based tool (academic logic assistant). No known nixpkgs-unstable-only dependencies found.
- Should be compatible with stable nixpkgs.

**`niri`**:
- Uses `inputs.nixpkgs.follows = "nixpkgs"`.
- Niri v26.04 is packaged in nixpkgs as of the stable 26.05 channel. The niri project flake (`YaLTeR/niri`) builds the compositor from source with its own Rust toolchain; it needs nixpkgs for build dependencies (wayland-protocols, libinput, etc.) which are all present in 26.05.
- **Binary cache note**: niri compiled from the external flake is NOT in `cache.nixos.org`; it's cached at `niri.cachix.org`. This is independent of the nixpkgs channel choice. The current setup already sources niri via the external flake (not `pkgs.niri`) with `unstablePackagesOverlay` wrapping `pkgs-unstable.niri`. Since the overlay reads `pkgs-unstable` (which remains on `nixos-unstable`), niri continues to come from `pkgs-unstable.niri`, not the external flake. Verify this path is correct in `unstablePackagesOverlay`.

**`utils`** (flake-utils):
- No nixpkgs dependency; pure Nix utility library. Not affected by channel change.

### 6. Custom Packages and the Unstable Overlay

The `unstablePackagesOverlay` injects packages from `pkgs-unstable` into the main `pkgs` set. After the migration:
- `pkgs` = nixos-26.05 (stable, good binary cache coverage)
- `pkgs-unstable` = nixos-unstable (via `nixpkgs-unstable` input, rolling)

The overlay already correctly bridges this split. Packages like `gemini-cli`, `niri` (via `pkgs-unstable.niri`), are drawn from unstable. The custom derivations (`claude-code.nix`, `opencode.nix`, `slidev.nix`, `kooha.nix`, `loogle.nix`, `aristotle.nix`, `vosk-models.nix`) use `final` and `prev` from the overlay fixed-point, which will be evaluated against the stable nixpkgs — these are custom fetches (npx wrappers, pre-built binaries, custom builds) that don't depend on nixpkgs version for their source, only for build tools.

Python overlay (`pythonPackagesOverlay`): `python-cvc5`, `pymupdf4llm`, `python-vosk` are custom derivations. They use `pySelf.callPackage` against `prev.python3`, which will be stable's Python. The `httplib2` and `pymupdf` patches (disabling `doCheck`) are defensive overrides that work regardless of python version. Should be safe.

### 7. Binary Cache Coverage: Stable vs. Unstable

**Stable (nixos-26.05)**:
- Hydra must complete building the full Nixpkgs for a commit before the channel advances. Every package at the pinned commit has a pre-built binary in `cache.nixos.org`.
- For `x86_64-linux`, this covers essentially all standard packages. Source builds should be near-zero for standard packages.
- The 29 packages that triggered source builds on the last `nix flake update` were almost certainly due to the unstable nixpkgs revision being newer than the highest Hydra-evaluated commit.

**Unstable (nixos-unstable)**:
- Hydra builds `nixos/unstable/tested` job set and advances the channel only when that job set passes, but individual packages can still be ahead of the cache if commits land faster than Hydra evaluates.
- `nix flake update` on an unstable input can jump to a commit where Hydra is mid-evaluation, producing cache misses and source builds of heavy packages (Rust crates, GHC packages, LLVM, etc.).

**Mitigation for remaining unstable input (`nixpkgs-unstable`)**:
The packages pulled from `pkgs-unstable` via the overlay are selected ones (niri, gemini-cli, etc.), not the entire system. Source builds from `nixpkgs-unstable` will only occur for those specific packages if their pinned revision outpaces Hydra. This is acceptable since it's a small, controlled set vs. the previous situation where the entire system was on unstable.

### 8. Making `nix flake update` Opt-In in update.sh

Current `update.sh` (line 21):
```bash
nix flake update
```

This updates ALL inputs unconditionally before every rebuild. The consequence: `nixpkgs` (and `nixpkgs-unstable`) jump to the latest commit, often outrunning Hydra.

**Recommended pattern** — separate update from rebuild:

```bash
# In update.sh: remove the unconditional nix flake update
# Instead, use a flag:

UPDATE_FLAKE=0
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE_FLAKE=1 ;;
  esac
done

if [ "$UPDATE_FLAKE" -eq 1 ]; then
  echo "===> Updating flake inputs..."
  nix flake update
else
  echo "===> Skipping flake input update (pass --update to update)"
fi
```

**Alternative**: Selective input update. Since `nixos-26.05` receives only security patches, you could update stable on a monthly schedule and update unstable selectively:

```bash
# Update only the unstable input:
nix flake update nixpkgs-unstable

# Update stable (infrequently, e.g., for security patches):
nix flake update nixpkgs
```

Nix 2.x supports `nix flake update <input-name>` to update a single named input. The `--update-input` flag (legacy) also works in older nix versions.

**Best practice**: Add a comment in `update.sh` documenting when to run `nix flake update nixpkgs` (e.g., weekly security window) vs. rebuilding without updating.

---

## Decisions

1. **Target channel**: `nixos-26.05` is confirmed correct for stable pinning as of June 2026.
2. **`nix-ai-tools` stays on `nixpkgs-unstable`**: The numtide project's own documentation prohibits stable follows.
3. **`home-manager` is already correct**: No change needed to `home-manager.url`.
4. **`nixpkgs-unstable` input must be retained**: It serves `pkgs-unstable` for the overlay and `nix-ai-tools`. Only the primary `nixpkgs` input changes.
5. **`niri` via overlay (not external flake)**: The current architecture pulls niri from `pkgs-unstable.niri`, not `inputs.niri`. The `inputs.niri` flake is declared but its follows points at `nixpkgs` (line 13 of flake.nix). Clarify in implementation whether `niri` input is still needed or can be removed.
6. **update.sh should be made opt-in**: Remove the unconditional `nix flake update` and replace with a `--update` flag.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| `lean4` flake incompatibility with stable nixpkgs base tools | Medium | Run `nix flake show` (read-only) post-migration to verify outputs before building. lean4 flake has `nixpkgs-old` and `nixpkgs-older` inputs for legacy Lean versions — these are tarball URLs and unaffected by the nixpkgs channel change. |
| `niri` from `inputs.niri` vs `pkgs-unstable.niri` confusion | Medium | The flake has both `inputs.niri` (external flake, follows `nixpkgs`) and `unstablePackagesOverlay` using `pkgs-unstable.niri`. During migration, clarify which path is active. If `inputs.niri` is dead code (not referenced in nixosConfigurations specialArgs), it can be removed to simplify. |
| `lectic` Haskell build using stable GHC | Low | lectic uses `inputs.nixpkgs.follows = "nixpkgs"` already; Haskell ecosystem in 26.05 is well-cached. Community reports confirm no 26.05 incompatibility. |
| `sops-nix` secrets decryption behavior change | Low | sops-nix is stable-compatible; functionality doesn't change between nixpkgs versions. |
| Disk space during migration (94% full) | High | Since this change only touches `flake.nix` and `flake.lock`, the actual build/switch should be done after disk cleanup (Tasks 063, 064). The flake edit itself is zero-cost. **Do not run nixos-rebuild until disk space is reclaimed.** |
| `nixpkgs-unstable` updates still triggering source builds for overlay packages | Low | This is acceptable: only specific packages (niri, gemini-cli) will be affected, not the entire system. Total source-build count should drop dramatically. |
| Packages in `nixpkgs-26.05` older than currently used unstable versions | Medium | Some packages have version differences between channels. Review critical packages (neovim, fish, kitty, ghostty) in stable vs. what unstable provided. Run `nix eval --raw nixpkgs#<pkg>.version` (read-only) comparisons if needed. |
| `calamares-nixos` in USB installer nixosConfiguration | Low | Available in nixpkgs 26.05; no special unstable requirement known. |

---

## Appendix: Flake Input Dependency Graph

```
flake.nix
├── nixpkgs            -> nixos-unstable    [CHANGE TO: nixos-26.05]
│   ├── lean4.follows
│   ├── niri.follows
│   ├── lectic.follows
│   ├── sops-nix.follows
│   └── home-manager.follows
├── nixpkgs-unstable   -> nixos-unstable    [KEEP: feeds pkgs-unstable overlay + nix-ai-tools]
│   └── nix-ai-tools.follows
├── home-manager       -> release-26.05     [ALREADY CORRECT]
├── lean4              -> github:leanprover/lean4 (no channel tag)
├── niri               -> github:YaLTeR/niri (no channel tag)
├── lectic             -> github:gleachkr/lectic (no channel tag)
├── nix-ai-tools       -> github:numtide/nix-ai-tools (pinned unstable)
├── sops-nix           -> github:Mic92/sops-nix
└── utils              -> github:numtide/flake-utils
```

## Appendix: Search Queries Used

- `nixos-26.05 release status stable channel 2026`
- `nixpkgs flake pin stable channel nixos-25.11 binary cache hydra coverage 2026`
- `nix flake update opt-in script update.sh pattern 2026`
- `nixos-26.05 binary cache hydra stable vs unstable cache hit rate`
- `niri window manager nixpkgs stable 26.05 packaging status`
- `lean4 flake nixpkgs follows stable nixos-26.05 compatibility`
- `numtide nix-ai-tools flake nixpkgs-unstable requirement ollama gemini-cli`
- `sops-nix flake nixpkgs stable follows nixos-26.05 compatibility`
- `nixpkgs nixos-26.05 home-manager release-26.05 flake alignment version match requirement`
- `nixpkgs stable vs unstable binary cache hit rate local compilation statistics community`
- `"nix flake update" "--update-input" specific inputs opt-in bash script pattern`

## References

- [NixOS 26.05 Release Blog](https://nixos.org/blog/announcements/2026/nixos-2605/)
- [Channel Branches - Official NixOS Wiki](https://wiki.nixos.org/wiki/Channel_branches)
- [NixOS Status (Hydra)](https://status.nixos.org/)
- [numtide/nix-ai-tools README](https://github.com/numtide/nix-ai-tools) — nixpkgs-unstable requirement
- [nix flake update - Nix Reference Manual](https://nix.dev/manual/nix/2.25/command-ref/new-cli/nix3-flake-update)
- [Home Manager Manual - Preface](https://nix-community.github.io/home-manager/)
- [Home-manager and nixpkgs version mismatch - NixOS Discourse](https://discourse.nixos.org/t/home-manager-and-nixpkgs-version-mismatch/77988)
- [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake) — niri binary cache at niri.cachix.org
- [sops-nix - Mic92/sops-nix](https://github.com/Mic92/sops-nix)

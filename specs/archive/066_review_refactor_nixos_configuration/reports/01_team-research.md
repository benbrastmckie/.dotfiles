# Research Report: Task #66 — Review and Refactor NixOS Configuration

**Task**: 66 — Systematically review the NixOS configuration and design a careful refactor improving organization, documentation, modularity, maintainability, and performance (per June 2026 best practices)
**Date**: 2026-06-24
**Mode**: Team Research (4 teammates: Primary, Alternatives, Critic, Horizons)
**Status**: RESEARCHED

---

## Summary

The configuration is **2,572 lines concentrated in three files** — `flake.nix` (477L), `configuration.nix` (945L), and `home.nix` (1,627L) — with every domain of concern mixed together and a `modules/`/`home-modules/` scaffold that exists but is unused (both contain only disabled files). All four teammates independently agree the refactor is well-motivated and should be a **semantically inert restructuring** (same behavior, new layout), verified by closure-diffing.

Two cross-cutting conclusions dominate:

1. **No framework is needed.** A hand-rolled `hosts/` + `modules/` layout with a `mkHost` helper is the right tool; Snowfall/nixos-unified/haumea are over-engineered for a single-user, ~2-host Linux config. `flake-parts` is the only framework worth *optionally* considering, and only to split `flake.nix` itself.
2. **Sequencing is the critical decision.** Tasks 62 and 65 are actively editing the same files by line number; tasks 60/61/63 will add `nix.*` settings that naturally belong in a future `nix-settings` module. **Task 66 implementation must land after 62, 65 complete and 60/61/63 settle** — but research/planning can proceed now.

---

## Key Findings

### Current-State Audit (Teammate A — high confidence)

| File | Lines | Issues |
|------|-------|--------|
| `flake.nix` | 477 | 3 overlays (~120L) inlined in `let`; 4 host definitions repeated with minor variation; ~200L USB-installer anonymous inline module |
| `configuration.nix` | 945 | Monolithic, all hosts share it; no per-host branching |
| `home.nix` | 1,627 | Monolithic; 6 inline `writeShellScriptBin` scripts (~350L), full mbsyncrc (170L), aerc (180L), waybar (90L) as string literals |
| `unstable-packages.nix` | 18 | **Dead file** — not imported anywhere; superseded by flake overlay |
| `packages/*.nix` | ~270 | Already well-structured; leave as-is |
| `modules/`, `home-modules/` | — | Each holds 1 disabled/unused file (extraction stalled previously) |

- **4 package-install paths** with no ownership policy: `environment.systemPackages`, `home.packages`, `programs.X.enable`, custom `writeShellScriptBin`.
- **Confirmed duplication**: `stylua`, `cvc5`, `lectic`, `wl-clipboard` in both system + home; `neovim` installed twice (system pkg + `programs.neovim.enable`); fish config managed in both files.

### Recommended Approach (Teammates A + B + D converge)

A hand-rolled modular layout. **Two equivalent naming conventions surfaced** (resolved below) — the substance is identical:

- Split `configuration.nix` → ~13 focused system modules (boot, hardware, audio, networking, desktop, power, locale, users, nix-settings, security, services, packages, + `optional/discord-bot.nix`, `optional/usb-installer.nix`).
- Split `home.nix` → ~20 focused home modules grouped as `core/`, `desktop/`, `email/`, `packages/`, `scripts/`, `services/`.
- `configuration.nix` and `home.nix` collapse to thin (~50-line) import lists.
- Extract the 3 overlays into `overlays/*.nix`.
- Add `lib/mkHost.nix` to eliminate the 4× host duplication in `flake.nix`.
- Convert inline Bash scripts to `pkgs.writeShellApplication` (adds shellcheck + explicit `runtimeInputs`).
- Replace hardcoded `"benjamin"` / `/home/benjamin` with `config.home.username` / `config.home.homeDirectory`.

### Framework Comparison (Teammate B — high confidence)

| Approach | Single-host fit | Verdict |
|----------|-----------------|---------|
| Hand-rolled `hosts/` + `modules/` | Excellent | **Recommended** |
| `flake-parts` | Good (optional) | Only if splitting `flake.nix` further; incremental |
| `nixos-unified` | Moderate over-engineering | Skip (value is cross-platform NixOS+darwin) |
| Snowfall-lib | Over-engineered | Skip (maintainer disengaged mid-2025; single-channel limit) |
| haumea / import-tree | Adds opacity | Skip (auto-loading obscures imports) |
| "import all and enable" (pattern) | Good | Adopt for `modules/` to future-proof multi-host |

### Critical Defects to Fix (Teammate C — high confidence, found by inspection)

1. **Hardcoded Nix store hash** at `home.nix:1613` (`SASL_PATH`) — breaks email silently on package updates; the correct dynamic form already exists at `home.nix:882`. **Fix immediately.**
2. **Dual `nixpkgs`/`nixpkgs-unstable` inputs both pointing to `nixos-unstable`** — two independent lockfile entries → system can mix packages from two snapshots; doubles eval cost.
3. **Dual home-manager paths** (NixOS-integrated + standalone `homeConfigurations.benjamin`) with subtly divergent `extraSpecialArgs`; `update.sh` runs both. A file move could silently worsen the divergence.
4. **Missing `follows = "nixpkgs"`** on `lean4`, `lectic`, `utils` → extra eval paths, larger lock, lower cache hits.
5. **Dead `nix-ai-tools` argument** in `home.nix` (declared, never used).
6. **Unmanaged secret** `~/.config/gmail-oauth2.env` — outside sops-nix, no provisioning/`.gitignore` story.
7. **`home-manager` on `release-26.05` vs `nixpkgs` on unstable** — known footgun (works via `follows`, but HM module options are pinned to 26.05).

### "High Performance" Is Eval-Time, Not Runtime (Teammates B + C)

Runtime is already heavily tuned (earlyoom, zram, `vm.swappiness`, power profiles, QMK udev). The real wins are **eval/build time**: kill the duplicate nixpkgs, add `follows`, drop unused ISO/USB outputs from routine `nix flake check`, and align with binary caches (task 61). Determinate Nix's parallel evaluator is *not* upstream as of mid-2026.

---

## Synthesis

### Conflicts Resolved

1. **Directory naming: `hosts/common/core/` + `home/benjamin/` (A) vs `modules/system/` + `modules/home/` (D).** These are stylistically different but functionally equivalent. **Resolution: recommend `modules/system/` + `modules/home/` + `hosts/<name>/` for host-specific bits**, because (a) it reuses the repo's existing (empty) `modules/` directory, (b) it cleanly separates *reusable* modules from *per-host* wiring, and (c) it matches the "import all and enable" future-proofing B recommends. Teammate A's detailed line-by-line migration mapping remains directly usable under either naming — the planner should adopt A's mapping table with D's top-level names.
2. **Is `flake.nix` "well-structured" (D) or a problem (A/B/C)?** Reconciled: its *output wiring* is fine, but it carries genuine debt — inlined overlays, 4× host duplication, the dual-nixpkgs input, and the 200L inline USB module. Treat `flake.nix` cleanup (overlays → files, `mkHost`, fix inputs) as in-scope but secondary to the monolith split.

### Gaps Identified

- **No behavioral-equivalence workflow exists.** The plan must define it explicitly: `nix store diff-closures` / `nvd` before vs after each phase, with "empty diff = phase safe to merge" as the acceptance criterion.
- **No CI / lint / format gate.** Recommend adding `nixfmt-rfc-style` + `statix` + `deadnix` via `git-hooks.nix` — but this is arguably a *separate* task (it changes behavior/tooling, not just layout).
- **Docs will go stale** the moment `configuration.nix` is split; `docs/` updates + a module map in `README.md` must be part of the refactor, not a follow-up.

### Recommendations (for the planner)

**Sequencing (high confidence, all teammates agree):**
```
[active]  62 (TTS swap), 65 (python pins) → must complete first
[then]    60 (resource limits) + 61 (channel pin) + 63 (user GC) → land their nix.* settings
[parallel] 64 (cache cleanup, imperative) → independent
[last]    66 → semantically inert restructuring on settled code
```
Task 66 **research/planning can proceed now**; only *implementation* must wait.

**Scope — INCLUDE:** monolith split into `modules/system/` + `modules/home/`; thin `configuration.nix`/`home.nix`; `overlays/` extraction; `lib/mkHost.nix`; username hygiene; inline-script → `writeShellApplication`; delete dead `unstable-packages.nix`; add `hosts/garuda/default.nix`; the critical fixes (SASL_PATH, dual-nixpkgs, `follows`, dead `nix-ai-tools` arg); docs + README module map.

**Scope — EXCLUDE (functional decisions / separate tasks):** new packages, channel migration (61), GC settings (63), removing the standalone `homeConfigurations` path, reorganizing `packages/`, any `.claude/` agent-system changes, secrets-backend changes.

**Quick wins (can be done now, independent of the full refactor):** (1) fix `SASL_PATH`; (2) delete `unstable-packages.nix`; (3) remove the 4 duplicate packages + duplicate neovim; (4) add `follows` to `lean4`/`lectic`/`utils`; (5) remove dead `nix-ai-tools` arg.

**Mandatory safeguards:** stage one module at a time; `nix flake check` + closure-diff after each; keep a backup branch; verify both home-manager paths produce identical profiles.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary: current-state audit + target structure + migration map | completed | High |
| B | Alternatives: framework comparison + performance prior art | completed | High |
| C | Critic: latent defects, eval-vs-runtime, safeguards, collisions | completed | High (findings 1–5,7–8); Low on dual-HM divergence (unproven) |
| D | Horizons: sequencing vs tasks 60–65, strategic scoping | completed | High |

Full per-teammate reports: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`, `01_teammate-c-findings.md`, `01_teammate-d-findings.md`.

---

## References

- NixOS & Flakes Book — Modularize Your Configuration; Overlays
- "Anatomy of a NixOS Config" (unmovedcentre.com) — `common/core` vs `common/optional`
- johns.codes — `mkHost` helper pattern
- flake.parts; NixOS Wiki — Flake Parts; "every file is a flake-parts module" (Discourse)
- nixos-unified.org; srid/nixos-config; Snowfall Lib; nix-community/haumea
- "Scaling NixOS with Import All and Enable" (kobimedrish.com)
- Nixcademy — Mastering Nixpkgs Overlays
- Determinate Systems — Parallel Nix evaluation
- cachix/git-hooks.nix; `nix store diff-closures`, `nvd`, `nix-diff`, `statix`, `deadnix`, `nixfmt-rfc-style`
- NixOS Discourse — "Unstable and stable inputs on flake.nix"; "How do you structure your NixOS configs?"

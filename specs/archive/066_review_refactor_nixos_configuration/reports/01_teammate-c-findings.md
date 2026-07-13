# Research Report: Task 66 — Critic Findings (Teammate C)

**Task**: 66 — Review & Refactor NixOS Configuration
**Role**: Teammate C (Critic)
**Started**: 2026-06-24
**Completed**: 2026-06-24
**Artifact**: 01_teammate-c-findings.md

---

## Key Findings

### 1. The Dual Home-Manager Path Is an Active Complexity Liability

The flake simultaneously runs:
- a NixOS-integrated home-manager (manages `/etc/profiles/per-user/`), updated by `nixos-rebuild switch`
- a standalone `homeConfigurations.benjamin` (manages `~/.nix-profile/`), updated by `home-manager switch`

`update.sh` runs both on every update. This creates two GC roots, two profile generations, two evaluation paths, and doubled evaluation time. The comment in flake.nix ("both evaluate home.nix with the same overlays") is aspirational, not guaranteed: `extraSpecialArgs` differ between the two paths (the standalone path passes `lectic` as an attrset, the NixOS-integrated path resolves it to a derivation with `.packages.${system}.lectic or ...`). A refactor that silently diverges these two paths could produce a configuration that passes `nix flake check` but whose `~/.nix-profile/` and `/etc/profiles/per-user/` disagree at runtime.

### 2. `update.sh` Unconditionally Runs `nix flake update` — Defeating Pinning

Every `./update.sh` call updates all flake inputs before rebuilding. Task 61 (pin to `nixos-26.05` for binary cache coverage) is NOT STARTED. Until 61 lands, any refactor that expands the package list will compound the already-identified issue of 29+ source-builds per update. A refactor should not proceed until the update strategy (opt-in vs opt-out updates) is resolved, or at minimum the refactor plan must explicitly coordinate with task 61.

### 3. The Redundant Dual-Nixpkgs Input Is a Correctness Hazard

`flake.nix` declares:
```nix
nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
```

Both point to the **same channel**. `pkgs-unstable` is imported from `nixpkgs-unstable`, but both inputs will typically resolve to different lockfile commits after any `nix flake update`, since Nix tracks them independently. The overlay `unstablePackagesOverlay` injects `pkgs-unstable.niri`, `pkgs-unstable.gemini-cli`, etc. into the main package set — so the system can end up with packages from two different `nixos-unstable` snapshots. A refactor focused on "organization" is likely to leave this time-bomb untouched because it does not affect file structure.

### 4. `home.sessionVariables.SASL_PATH` Contains a Hardcoded Nix Store Hash

At `home.nix:1613`:
```nix
SASL_PATH = "/nix/store/ja75va5vkxrmm0y95gdzk04kxa0pmw1s-cyrus-sasl-xoauth2-0.2/lib/sasl2:/nix/store/f4spmcr74xb2zwin34n8973jj7ppn4bv-cyrus-sasl-2.1.28-bin/lib/sasl2";
```

Two lines above (at `home.nix:882`) the _correct_ dynamic version exists:
```nix
SASL_PATH = "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2";
```

The stale hardcoded path in `home.sessionVariables` will break silently when packages update (the store path changes). This bug exists right now and is invisible to `nix flake check`. A structural refactor that does not audit `home.sessionVariables` will preserve this defect.

### 5. `nix-ai-tools` Is Passed as `extraSpecialArgs` but Unused in `home.nix`

`home.nix` declares `{ config, pkgs, pkgs-unstable, lectic, nix-ai-tools, ... }:` in its argument list, but `nix-ai-tools` does not appear in the file body. The flake passes it as `extraSpecialArgs` to all four `nixosConfigurations` (nandi, hamsa, iso, usb-installer) and to `homeConfigurations`. This is dead weight in the evaluation graph and signals that the module was planned but not wired up. A naive refactor could accidentally remove it and break something else that depends on the `nix-ai-tools` input being present in the flake, or preserve it as dead code indefinitely.

### 6. Several Flake Inputs Lack `follows` for `nixpkgs`

The following inputs bring their own nixpkgs, creating additional evaluation paths and potential diamond-dependency confusion:
- `lean4` — no `follows`
- `lectic` — no `follows`
- `utils` — no `follows`

Only `niri`, `home-manager`, `sops-nix`, and `nix-ai-tools` (follows `nixpkgs-unstable`) set `follows`. Adding `follows = "nixpkgs"` to the others would reduce the lock file size, reduce evaluation time, and improve cache hit rates. A refactor focused on file structure will not naturally surface this.

### 7. Home-Manager Channel Mismatch with nixpkgs

`home-manager.url = "github:nix-community/home-manager/release-26.05"` while `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`. The NixOS module option set from HM 26.05 may silently accept or reject options that are present or absent on `nixos-unstable`. This is the known "don't mix stable HM with unstable nixpkgs" footgun. The current setup works because `home-manager.inputs.nixpkgs.follows = "nixpkgs"` forces HM to use the unstable package set — but HM's own module machinery is version 26.05. Any option added by HM after 26.05 won't be available. A refactor that adds new HM module options must verify they exist in the pinned HM version.

### 8. The `gmail-oauth2.env` File Is an Unmanaged Secret

`home.nix:785` references `EnvironmentFile = "%h/.config/gmail-oauth2.env"` which must contain `GMAIL_CLIENT_ID` (used at `home.nix:280`). This file is not managed by sops-nix, not tracked in the flake, and not mentioned in `.gitignore`. Its existence is a prerequisite for the `gmail-oauth2-refresh` systemd timer to work, but there is no documentation or provisioning story for it. A refactor that reorganizes secrets handling (e.g., consolidating under sops-nix) must not overlook this out-of-band environment file.

### 9. Parallel ISO/USB Configurations Add Evaluation Overhead Without Active Use

The flake defines four `nixosConfigurations`: `nandi`, `hamsa`, `iso`, and `usb-installer`. The ISO and USB-installer configs include Home Manager (which must evaluate home.nix) and the full package list from `configuration.nix`, even though ISOs typically shouldn't need most user packages. These configurations add evaluation time and are rarely built. `nix flake check` evaluates all outputs, so they cost CI time even if never deployed. A refactor proposal should explicitly decide whether to keep these in-tree or move them to a separate flake.

### 10. `configuration.nix` and `home.nix` Are Both Monolithic (~950 and ~1,627 lines)

The existing structure is two large flat files with inline shell scripts, systemd services, GNOME dconf, package lists, and hardware-specific workarounds mixed together. A structural refactor will split these — but splitting without a principled module boundary strategy risks fragmented context (e.g., the EAPD speaker-amp fix referencing an audio module that doesn't exist yet). The `modules/opencode.nix` and `home-modules/mcp-hub.nix` (commented out) files exist but are not actively used, suggesting module extraction has been attempted and stalled.

---

## Gaps & Blind Spots

If a refactor focuses only on **file structure** (splitting into modules), the following are likely to be overlooked:

1. **The hardcoded store hash in `home.sessionVariables.SASL_PATH`** — a latent runtime breakage that is invisible to eval-time checks.

2. **The dual home-manager evaluation divergence risk** — splitting files may silently change which `extraSpecialArgs` flow to the standalone vs NixOS-integrated paths.

3. **The `update.sh` auto-update behavior** — any refactor that makes the config "larger" without first landing task 61 (stable channel pinning) will worsen the source-build problem.

4. **Evaluation performance vs. runtime performance** — the task description says "high performance configuration." This is ambiguous. The main perf concerns in this repo are:
   - **Evaluation time**: reduced by eliminating redundant imports, fixing the dual-nixpkgs issue, adding `follows`
   - **Build time**: reduced by binary cache alignment (task 61)
   - **Runtime/system performance**: already well-tuned (earlyoom, zram, vm.swappiness, power profiles, QMK udev workaround)
   A structural refactor primarily improves eval time and maintainability, not runtime system performance.

5. **Testing and behavioral equivalence verification** — there is no CI, no `nix flake check` in a pre-commit hook, and no way to verify that a module split produces an identical system closure. `nix store diff-closures` / `nvd` can compare before/after closures, but the workflow for doing this is not documented.

6. **Dead code accumulation**: commented-out packages, disabled services (sleep inhibitor, swayidle, mako, waybar), and multiple `# Disabled` modules (mcp-hub.nix) will likely be preserved "as-is" during a structural refactor unless someone explicitly audits them. `deadnix` would catch unused Nix bindings; it won't catch commented shell blocks.

7. **Collision with in-flight tasks**: tasks 62 (piper→pico TTS), 63 (user GC), 65 (python3 pins) are in-progress or implementing. A large structural refactor that touches `configuration.nix` lines 635 (piper/picotts) and `home.nix` line ~400 (markitdown/magika) will conflict with task 62's diff. Task 65 has already modified python overlays in `flake.nix`. Any refactor plan that doesn't explicitly state "sequence after tasks 62/63/65 land" is setting up merge conflicts against itself.

8. **Documentation staleness**: `docs/` contains several files (e.g., `docs/packages.md`, `docs/configuration.md`) that were presumably written for the pre-refactor structure. Splitting `configuration.nix` into `modules/` without updating `docs/` will immediately make the docs wrong.

---

## Unvalidated Assumptions

The following assumptions are embedded in a typical refactor task description but are **not verified** against this repo:

| Assumption | Reality |
|---|---|
| "Multi-host support exists and needs generalization" | It exists (nandi + hamsa) but both hosts share one `configuration.nix` with only `{ networking.hostName }` differing. The generalization may already be sufficient. |
| "Modules will improve maintainability" | Only if accompanied by principled extraction criteria. Splitting a 950-line file into 15 small files without clear ownership makes grep harder. |
| "Rollback is easy" | NixOS boot-time rollback exists, but it requires a working bootloader selection. The last 30 generations are kept (30d GC). Task 63 (user GC) may prune HM generations, tightening the rollback window. |
| "secrets are managed" | Partially true. sops-nix handles bot token and OpenCode password. `gmail-oauth2.env` is unmanaged. GNOME keyring holds OAuth2 tokens outside Nix management. |
| "performance means runtime performance" | The repo already has significant runtime tuning. The main bottleneck is eval+build time, which is addressed by tasks 60/61, not structural refactoring. |
| "linting tools catch all issues" | `statix`/`deadnix`/`nixfmt` catch Nix-language antipatterns. They will not catch: hardcoded store hashes in strings, dangling `extraSpecialArgs`, or behavior changes from module merge order. |

---

## Questions To Ask Before Committing to a Refactor

1. **What is the actual problem being solved?** Is it: (a) hard to find where to add new packages? (b) hard to understand what a given module does? (c) eval is slow? (d) merge conflicts are frequent? Each has a different correct solution.

2. **Should the dual home-manager evaluation be consolidated first?** The parallel NixOS-integrated + standalone paths are the largest source of confusion in the current structure. Eliminating the standalone path or formalizing it would simplify refactoring more than any file split.

3. **What is the rollback story for a sweeping rename?** If splitting `configuration.nix` into 10 modules breaks something at boot, can the user get back to the working state without the refactored branch being checked out?

4. **How will behavioral equivalence be verified?** What is the concrete command sequence to compare `nixosConfigurations.nandi.config.system.build.toplevel` before and after the refactor? Who runs it, and when?

5. **Should iso and usb-installer move out of this flake?** They add significant evaluation overhead and are likely built at most a few times per year.

6. **Does module extraction need to happen before or after task 61 (stable pinning)?** A refactor that rewrites the overlay structure while also changing the channel is a larger diff and harder to verify.

7. **Is multi-host generality actually needed?** Nandi and Hamsa share 100% of `configuration.nix`. If the machines will continue to be nearly identical, a simpler host-override layer (a la `lib.mkDefault` + per-host attrsets) may be sufficient without a full `hosts/` restructure.

8. **What happens to `update.sh` after a refactor?** The script hardcodes `home-manager switch --flake .#benjamin` and `nixos-rebuild switch --flake .#$HOSTNAME`. If the refactor changes output names, `update.sh` breaks.

---

## Recommended Safeguards (Tooling)

### Formatting
- **`nixfmt-rfc-style`** (package: `pkgs.nixfmt-rfc-style`) — the emerging community standard, soon to be enforced in nixpkgs. Preferred for new files and formatting passes.
- **`alejandra`** — semantically correct, Rust-based, fast; good alternative if `nixfmt-rfc-style` behavior is undesirable for specific files.
- **Recommendation**: Adopt `nixfmt-rfc-style` as the single formatter and run it as a pre-commit hook. Do not mix formatters.

### Linting
- **`statix`** (`pkgs.statix`) — catches antipatterns: `with pkgs;` at top scope, `rec { }`, deprecated overlay variable names (`self`/`super`), `builtins.` vs `lib.` redundancy. Run: `statix check .`
- **`deadnix`** (`pkgs.deadnix`) — finds unused bindings and function arguments. Will flag the dead `nix-ai-tools` argument in `home.nix`. Run: `deadnix -f .`

### Pre-commit Integration
- **`git-hooks.nix`** (formerly `pre-commit-hooks.nix`, now at `cachix/git-hooks.nix`) — add a `devShell` with nixfmt, statix, and deadnix as pre-commit hooks via `flake-parts` or manual devShell. Prevents formatting drift and antipattern accumulation without CI.

### Closure Diff (Behavioral Equivalence)
- **`nix store diff-closures`** (built-in) — compare before/after closures:
  ```bash
  # Before refactor: record the current toplevel
  PRE=$(nixos-rebuild build --flake .#nandi --no-link --print-out-paths 2>/dev/null)
  # After refactor: build again
  POST=$(nixos-rebuild build --flake .#nandi --no-link --print-out-paths 2>/dev/null)
  nix store diff-closures $PRE $POST
  ```
  An empty diff means the refactor is a no-op from the system's perspective. Any unexpected additions must be explained.
- **`nvd`** (`pkgs.nvd`) — friendlier output format than `nix store diff-closures`; prints human-readable package add/remove/update summary.
- **`nix-diff`** (`pkgs.nix-diff`) — compares two derivations attribute by attribute; useful for diagnosing why two closures differ when they should not.

### Evaluation Correctness
- **`nix flake check`** — run before and after every phase; should pass throughout. The `--option allow-import-from-derivation false` flag (already used in `update.sh`) should remain.
- **`nix eval .#nixosConfigurations.nandi.config.system.build.toplevel`** — pure evaluation check without building; fast.

### Secrets Audit
- **`git-secrets`** or **`trufflehog`** — scan git history for accidentally committed secrets. Not Nix-specific, but warranted before making this config more modular (and potentially reorganizing where environment files are referenced).

---

## Confidence Level

**High confidence** in findings 1–5, 7–8 (verified by direct file inspection).

**Medium confidence** in finding 6 (lectic/lean4/utils `follows` — the behavior without `follows` is benign if the lockfile is stable, but adds evaluation overhead and diamond-dep risk over time).

**Medium confidence** on web research findings (nixfmt-rfc-style community adoption trajectory, `nix store diff-closures` as the canonical equivalence tool — these are consistent with known community direction as of June 2026 but the tooling landscape evolves quickly).

**Low confidence** in the dual home-manager path divergence claim without actually running a diff — the behavior may be identical in practice given the `or` guards in `lectic` resolution; the risk is structural, not proven to be active.

---

## Summary

The most critical pre-refactor fixes are: (a) remove the hardcoded store hash at `home.sessionVariables.SASL_PATH` line 1613, (b) collapse or document the divergence between the dual home-manager evaluation paths, and (c) explicitly sequence the refactor after tasks 62/63/65 land to avoid merge conflicts. The most overlooked dimension of "high performance" in the task description is eval-time performance (redundant dual nixpkgs, missing `follows`, unnecessary ISO configs in `nix flake check`) — not runtime performance, which is already heavily tuned. Tooling-wise, the refactor should adopt `nixfmt-rfc-style`, `statix`, `deadnix`, and `nix store diff-closures` as mandatory checkpoints, and should define behavioral equivalence criteria before moving a single line of code.

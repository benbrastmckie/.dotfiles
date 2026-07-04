# Research Report: Alternative Patterns & Prior Art (NixOS Community Conventions)

**Task**: 81 — Design and orchestrate a systematic reorganization of the NixOS/Home Manager dotfiles repository
**Role**: Teammate B — Alternative Approaches / Prior Art survey
**Date**: 2026-07-04
**Method**: Live `gh api` tree/content pulls against real repos (not paraphrase-only), plus targeted
WebFetch/WebSearch for framework docs and a reorg case study.

## Key Findings

### 1. Three independent, well-regarded personal configs converge on the same hand-rolled shape

I pulled full file trees and representative file contents from:
- **Misterio77/nix-config** (7 hosts: servers + desktops + RPi, sops-nix, single maintainer)
- **mitchellh/nixos-config** (multi-machine, WSL + VM + laptop)
- **hlissner/dotfiles** (large, ~15 years matured, explicitly documented rationale)

All three land on the *same* skeleton this repo already has, independently:

```
flake.nix              # thin: inputs + a small mkHost/mksystem-style factory call per host
lib/                    # 1 file (mkHost.nix / mksystem.nix) or a small handful
hosts/<name>/           # default.nix + hardware-configuration.nix, one dir per machine
modules/{nixos,home-manager}/   # or system/home split (this repo's naming) — plain files + one aggregator
overlays/               # single default.nix aggregator; patch files live alongside it
pkgs/<name>/default.nix # one directory per custom package + a pkgs/default.nix aggregator
config/ or similar      # raw dotfiles referenced by .source from the owning module
```

This is strong convergent evidence that this repo's *existing* top-level shape
(`hosts/`, `modules/`, `overlays/`, `pkgs`≈`packages/`, `lib/`, `config/`) is not wrong — the
seed report's decomposition (dead-code removal, hygiene, per-host standardization, module
granularity) is the right kind of work: convention *enforcement and cleanup*, not a structural
rewrite.

### 2. `global`/`optional` naming is an established convention — and confirms the seed report's discord-bot finding

Misterio77's `hosts/common/` splits into:
- `hosts/common/global/default.nix` — a hand-written `imports = [ ... ]` list, unconditionally
  pulled into **every** host via `../common/global` in each `hosts/<name>/default.nix`.
- `hosts/common/optional/*.nix` — individual files, each **explicitly** listed in only the hosts
  that want them (e.g. `alcyone/default.nix` imports `../common/optional/fail2ban.nix` and
  `../common/optional/tailscale-exit-node.nix` by name; other hosts don't).

This is exactly the convention this repo's directory name (`modules/system/optional/`) implies
but doesn't honor: the seed report found `discord-bot.nix` sits in `optional/` yet is imported
unconditionally by `configuration.nix` for every host. The community convention makes this an
unambiguous bug, not a style nitpick — the fix is to move the explicit import decision to each
`hosts/<name>/default.nix` (which the seed already flagged as needing standardization for
another reason: `garuda`'s empty placeholder vs `nandi`/`hamsa` having none at all).

### 3. Per-host auto-import via `pathExists`/`readDir` exists in prior art, but its own author warns against over-applying it

hlissner's `lib/modules.nix` has a genuinely reusable `mapModules`/`mapModulesRec` helper built on
`builtins.readDir` + `pathExists "${path}/default.nix"` — a generic auto-import-by-convention
function. However hlissner's own `lib/nixos.nix` comment is the most useful evidence here:

> "This may look a lot like what flake-parts, flake-utils(-plus), and/or digga offer. I reinvent
> the wheel because... they are too volatile to depend on... I'd rather have a less polished API
> that I fully control than a robust one that I cannot predict."

Notably, **neither Misterio77 nor mitchellh bothers with a generic auto-import helper at all** —
both hand-list `imports = [ ... ]` in each host's `default.nix`. For a 4-host repo, a bespoke
`readDir`-based auto-import layer is more machinery than the problem needs; explicit lists are
easier to `grep`, diff, and reason about, and this repo's `lib/mkHost.nix` is already a single
small file in the same spirit as `mksystem.nix`/`mkFlake`. **Recommendation for the seed report's
open "hosts/ standardization" decision**: require every host to have an explicit (possibly
one-line) `default.nix`, not an auto-discovered one — mirrors Misterio77/mitchellh, not hlissner's
generic-lib approach.

### 4. Framework adoption (flake-parts / snowfall-lib) — clear recommendation: do not adopt

- **flake-parts** is a NixOS-module-system mirror for flake outputs. Its own docs position it as
  valuable "if you plan to pull pieces of your flake into re-usable modules" (i.e. cross-repo
  sharing, plugin ecosystems) — "otherwise, it's likely unnecessary" (per flake.parts wiki
  commentary surfaced in search results). This repo has one flake, one repo, one user; there is
  nothing to compose across boundaries.
- **snowfall-lib** goes further: it *enforces* a specific directory convention so it can
  auto-wire everything by naming/location alone ("say here is my directory... it will import
  everything"). That is more opinionated magic layered on top of exactly the kind of implicit
  convention (dead files, undocumented `optional/` semantics, silently-broken references) this
  task's seed report is trying to *eliminate*. Adding a framework that hides wiring behind
  directory-name magic would fight the task's own goals of legibility and documented convention.
- **The strongest evidence is negative-space**: none of the three surveyed "well-regarded,
  mature, multi-host" personal configs use flake-parts or snowfall-lib. All three hand-roll a
  single small `lib/mkHost`-style function. This repo already has exactly that
  (`lib/mkHost.nix`). The recommendation is to keep it, document it, and resist the temptation
  to reach for a framework during this reorg — the payoff (composability across repos) doesn't
  exist for a single-user, single-repo, 4-host setup, and the cost (an extra abstraction layer,
  a new dependency, less transparent evaluation) is real.

Trade-off table for the design doc:

| | Hand-rolled (`lib/mkHost.nix`, status quo) | flake-parts | snowfall-lib |
|---|---|---|---|
| Fits single-repo/single-user | Yes — matches all 3 surveyed repos | Adds unused composability | Adds unused composability + convention lock-in |
| Debuggability | Full control, plain functions | NixOS-module indirection to learn | Directory-convention magic, harder to trace |
| Migration cost | Zero (already in place) | Touch flake.nix + learn module idioms | Touch-everything rename to snowfall's required layout |
| Where it wins | N/A | Multi-repo/plugin ecosystems | Zero-boilerplate for very large multi-user setups |

### 5. Python service packaging: prior art is unanimous — package as a derivation, never `PYTHONPATH` into the working tree

Misterio77's `pkgs/` has multiple precedents for exactly the seed report's item 8
(`opencode-discord-bot`): one directory per package (`pkgs/lyrics/default.nix` via
`pkgs.python3Packages.callPackage`, `pkgs/jellysearch/default.nix` via a language-appropriate
`buildXPackage`), aggregated in `pkgs/default.nix`, and wired into the flake by the overlay's
`additions` function (`import ../pkgs {pkgs = final;}` in `overlays/default.nix`). **No surveyed
repo runs a service via a raw `PYTHONPATH` pointing at the working tree** — every service-backing
package is built into the Nix store first, then referenced by its store path/`meta.mainProgram`
in the systemd unit. This directly corroborates and strengthens the seed report's option (a)
(`buildPythonApplication` + `pyproject.toml` under `packages/`) over option (b) (extract to its
own repo) for a single, still-evolving in-repo tool — extraction to a separate flake input is
what mature/reusable tools graduate to (see Misterio77's own `themes`/`website` flake inputs,
which are *his own* separately-versioned projects), not what a 2,392-line, still-coupled,
same-repo bot needs yet.

### 6. Raw-dotfile directories are co-located with the *owning* module, not centralized in one big file

hlissner keeps raw dotfiles in a root `config/` directory (this repo already uses the identical
name), but each home-manager module wires only *its own* subtree:
`modules/desktop/term/foot.nix` sets `home.configFile."foot/foot.ini"` sourced from his
`config/foot/`; `modules/shell/tmux.nix` sets `home.configFile."tmux".source =
"${hey.configDir}/tmux"`. **No single file deploys all of `config/`.** This is directly relevant
to the seed report's finding that `modules/home/core/shell.nix` is a misnomer because it deploys
14+ unrelated dotfiles (fastfetch, sioyek, niri, kitty, wezterm, himalaya, tmux, zathura...) from
one file via three different mechanisms. The community pattern argues for splitting that
deployment logic out to the module that owns each program (or, at minimum, out of a file named
`shell.nix`) rather than centralizing it — this reinforces seed decomposition items 6 and 9
(and specifically strengthens the `dotfiles.nix`-style extraction idea in item 9 by giving it a
per-program-module target instead of one big file).

### 7. Options pattern is used, but selectively — not a blanket rule

hlissner's repo is `mkIf cfg.enable` end-to-end (even trivial modules like `modules/dev/default.nix`
declare `options.modules.dev.xdg.enable`). Misterio77 uses the options pattern specifically for
his own reusable NixOS *service* modules (`opencode.nix`, `satisfactory.nix`, `openrgb.nix` — each
with `mkEnableOption`/`mkOption`), but his **host-level glue** (`hosts/common/global/default.nix`,
`hosts/alcyone/default.nix`) is plain config attribute sets with no options at all — those aren't
meant to be reusable/toggleable, they're the one-shot wiring for a specific host. This suggests
the seed report's open "module convention decision" (item 7) doesn't need to be all-or-nothing:
reserve the options pattern for genuinely optional/reusable modules (exactly the
`discord-bot.nix` case), and it's reasonable to amend `.claude/rules/nix.md` to explicitly bless
plain config sets for host-glue and always-on system modules rather than rewriting all 43 files.

### 8. Confirmations of smaller seed-report calls

- **`assets/` directory for static files**: hlissner has a top-level `assets/` (`assets/sounds/`)
  — corroborates the seed report's suggestion of an `assets/` dir for `wallpapers/`-like content
  if more static assets accumulate.
- **`scripts/` or `bin/` for personal helper scripts**: hlissner has `bin/` for maintenance
  scripts (`autoclicker.zsh`, `optimize.zsh`, etc.) — corroborates seed item 4's `scripts/`
  candidate for `install.sh`/`update.sh`/`build-usb-installer.sh`.
- **Per-host README**: Misterio77 keeps a `README.org` inside each `hosts/<name>/` describing that
  machine's purpose — worth considering alongside the seed's flagged missing `modules/README.md`,
  though lower priority than the global/optional documentation gap.

### 9. What the seed decomposition doesn't mention that prior art suggests considering (low priority)

- **Per-host secrets colocation**: Misterio77 colocates `secrets.yaml` inside each `hosts/<name>/`
  rather than one central `secrets/secrets.yaml`. Given this repo's much smaller secret surface
  (one sops rule, one age recipient, two consumers), centralizing is simpler and fine as-is — this
  is a "don't bother" finding, not a recommendation to change.
- **Deep profile/role layering** (hlissner's `modules/profiles/{hardware,network,platform,role,user}/`)
  is a heavier taxonomy than a 4-host repo needs. Misterio77's flatter `hosts/common/{global,optional,users}`
  is the better weight-class match — worth citing in the design doc as the "don't over-engineer
  toward hlissner's scale" caution.

## Recommended Approach

1. **Stay hand-rolled.** Do not introduce flake-parts or snowfall-lib. This repo's existing
   `lib/mkHost.nix` + flat `hosts/`/`modules/`/`overlays/`/`packages/` shape already matches the
   convention used by every well-regarded personal config surveyed. Frame this task as
   convention-enforcement + dead-code removal, not a framework migration — this validates the
   seed report's own framing.
2. **Adopt the `global`/`optional` semantic literally** for `modules/system/`: an always-imported
   list (mirrors current `configuration.nix`) plus a genuinely optional set that each
   `hosts/<name>/default.nix` opts into by name. This gives item 5 (hosts/ standardization) and
   the `discord-bot.nix` fix (item 7) a single, community-precedented target shape instead of two
   independent decisions.
3. **Require an explicit (not auto-discovered) `default.nix` per host.** Skip building a generic
   `readDir`/`pathExists` auto-import lib helper — it's more machinery than 4 hosts justify, and
   the two most directly comparable repos (Misterio77, mitchellh) don't use one either.
4. **Package `opencode-discord-bot` in-tree via `buildPythonApplication`** under `packages/`
   (seed item 8, option (a)) — this has direct, unanimous prior-art support and no surveyed
   counterexample of the current `PYTHONPATH`-into-working-tree approach.
5. **Split `config/` deployment by owning module** rather than centralizing in one file — informs
   how seed items 6 and 9 should land: don't just rename `shell.nix`, distribute its
   `config/`-wiring responsibility to the modules that already own each program where practical.
6. **Scope the options-pattern decision (item 7) to optional/reusable modules only** — amend
   `.claude/rules/nix.md` to explicitly permit plain config sets for host glue and always-on
   system modules, rather than mandating a 43-file rewrite.

## Evidence/Examples

- [Misterio77/nix-config](https://github.com/Misterio77/nix-config) — `hosts/common/{global,optional,users}`,
  `pkgs/<name>/default.nix` + `pkgs/default.nix` aggregator, `overlays/default.nix` single-file
  aggregator with patches alongside, options-pattern service modules
  (`modules/nixos/opencode.nix`, `satisfactory.nix`).
- [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) — minimal
  boilerplate confirming the same `pkgs/`, `overlay/`, `modules/{nixos,home-manager}` skeleton at
  the smallest possible scale.
- [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) — `lib/mksystem.nix` single
  hand-rolled factory function, `machines/` (hosts), `users/mitchellh/` (home-manager +
  raw dotfiles co-located per user).
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) — `lib/modules.nix` generic
  `mapModules`/`readDir`+`pathExists` auto-import helper (with the author's own rationale
  against depending on flake-parts/flake-utils/digga, in `lib/nixos.nix`'s header comment),
  root `config/` raw-dotfile directory wired per-owning-module (`modules/desktop/term/foot.nix`,
  `modules/shell/tmux.nix`), `assets/` and `bin/` top-level directories, full options-pattern
  usage even for trivial modules.
- [flake.parts](https://flake.parts/) — framework positioning: valuable for
  cross-repo/reusable-module composition, not asserted as beneficial for single-repo personal
  configs.
- [evantravers.com — Reorganizing My Nix Dotfiles](https://evantravers.com/articles/2025/04/17/reorganizing-my-nix-dotfiles/) —
  independent case study of a personal-repo reorg explicitly modeled on mitchellh's structure;
  reports the reorg's main measurable win was correcting `home-manager.useGlobalPkgs`/
  `extraSpecialArgs` wiring (a config-correctness win, not a directory-renaming win) — a useful
  caution that structural reorg alone doesn't guarantee payoff; the *semantic* fixes (dead
  code, broken references, unconditional "optional" imports) matter as much as the directory
  layout.

## Confidence Level

**High** for the "stay hand-rolled, don't adopt flake-parts/snowfall" recommendation and the
`global`/`optional` naming fix — these rest on directly-fetched file contents from three
independent, actively-maintained, well-regarded repos with converging structure, not summaries.

**Medium** for the specific per-module `config/`-file-splitting recommendation (item 6/9
refinement) — hlissner's pattern is real and directly comparable, but is one data point for that
specific sub-question rather than a three-way convergence.

**Medium** for the Python-packaging recommendation's strength — strong unanimous *positive*
precedent for `buildPythonApplication`/`pkgs/<name>` packaging, but the "no counterexample of
PYTHONPATH-into-working-tree" observation is necessarily a negative/absence finding from a
small (3-repo) sample, not a guarantee no personal config anywhere does this.

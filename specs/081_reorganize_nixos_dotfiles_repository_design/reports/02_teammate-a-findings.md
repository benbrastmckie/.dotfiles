# Research Report: Target Layout Design + Subtask Decomposition (Teammate A — Primary)

**Task**: 81 — Design and orchestrate a systematic reorganization of the NixOS/Home Manager
dotfiles repository
**Role**: Teammate A (Primary implementation approach and patterns)
**Builds on**: `specs/081_.../reports/01_repo-organization-review.md` (seed inventory — not
re-audited here; every claim below that touches the seed's inventory was spot-verified against
the live tree, see Evidence section).

## Key Findings

1. **`mkHost.nix`'s API already anticipates the standardization the seed asks for** —
   `extraModules` and `extraSpecialArgs` are the mechanism, but nothing auto-wires
   `hosts/<name>/default.nix`; `flake.nix` hand-wires it only for `garuda`
   (`flake.nix:111-114`), leaving `nandi`/`hamsa` implicitly "no host module" and `garuda`
   pointing at a file whose entire body is a comment (`hosts/garuda/default.nix:1-7`). This is
   fixable with one `builtins.pathExists` guard inside `lib/mkHost.nix` — a small, low-blast-radius
   change with a big convention payoff.
2. **The ISO path's duplication of `mkHost`'s home-manager stanza is caused by one hard
   assumption in `mkHost.nix`**: it unconditionally imports
   `"${root}/hosts/${hostname}/hardware-configuration.nix"` (`lib/mkHost.nix:31`). ISO builds use
   the upstream `cd-dvd` template instead, which is *why* `flake.nix:118-175` reimplements
   `mkHost`'s ~40 shared lines inline. Making that import conditional (same `pathExists` pattern)
   unlocks full `mkHost` unification for `iso` too — this is a stretch item, not a prerequisite,
   because it touches every host's build path and deserves its own dedicated verification pass.
3. **`configuration.nix`'s unconditional `discord-bot.nix` import is the same root cause as the
   options-pattern gap**: the file lives under `modules/system/optional/` (naming implies
   opt-in) but is imported by the one shared `configuration.nix` all hosts share
   (`configuration.nix:26`), and `docs/discord-bot.md:25` documents it as living in
   `configuration.nix` directly — so today there is no way to build `hamsa` or `garuda` without
   also getting the Discord bot. Fixing "hosts standardization" (item 1) and "module convention"
   (options pattern) are the same underlying fix applied to the same file, and should be one
   subtask, not two independently-scheduled ones — doing them separately means editing
   `configuration.nix`'s import list twice.
4. **A `modules/{system,home}/default.nix` aggregator is idiomatic and nearly free**: Nix
   resolves `import ./modules/system` to `modules/system/default.nix` automatically. Today
   `configuration.nix:8-27` and `home.nix:5-52` are the *only* place the 43-file module manifest
   lives, split across two flat, hand-maintained lists with no co-location in `modules/` itself.
   Moving the list into `modules/system/default.nix` / `modules/home/default.nix` costs one new
   file per branch and turns `configuration.nix`/`home.nix` into thin per-repo entrypoints (which
   is what they should be, since they also carry `system.stateVersion` / `home.stateVersion` and
   username — real per-repo config, not module bookkeeping).
5. **The seed's ordering has a sequencing bug**: its item 3 ("Documentation sync") is scheduled
   before items 5-9 (hosts standardization, module granularity, module convention, packaging,
   config/ clarity) — all of which change the very tree that documentation sync would document
   (root README's Module Map, `hosts/README.md`, a new `modules/README.md`). Doing doc sync
   third means rewriting the same sections twice. Documentation sync must be the **last**
   subtask, gated on every structural change landing first.
6. **Two of the seed's "consider" suggestions should be explicitly rejected, not left open**:
   renaming `config/` → `dotfiles/`/`configs/` and introducing a generic `assets/` directory. See
   "Challenged Assumptions" below — both are unforced, non-load-bearing churn for cosmetic gains
   only, on a repo with exactly one directory currently needing either concern.

## Recommended Approach

### Target directory layout

```
.
├── flake.nix / flake.lock
├── configuration.nix          # thin: imports ./modules/system + system.stateVersion
├── home.nix                   # thin: imports ./modules/home + home.stateVersion + username
├── .gitignore  .sops.yaml  README.md
│
├── scripts/                   # NEW — root shell scripts relocated
│   ├── install.sh
│   ├── update.sh
│   └── build-usb-installer.sh
│                               (test-sasl.sh deleted, not moved)
│
├── lib/
│   └── mkHost.nix             # + pathExists auto-import of hosts/<name>/default.nix
│                               #   (+ optional stretch: pathExists hardware-configuration.nix
│                               #    to unify the `iso` build under mkHost too)
│
├── hosts/
│   ├── README.md               # rewritten: mkHost pattern, auto-import convention
│   ├── nandi/{hardware-configuration.nix, default.nix}   # NEW default.nix: discordBot.enable
│   ├── hamsa/{hardware-configuration.nix}                # no default.nix needed — fine, optional
│   ├── garuda/{hardware-configuration.nix}                # empty placeholder default.nix REMOVED
│   ├── usb-installer/{hardware-configuration.nix?, default.nix}   # unchanged content
│   └── iso/{default.nix}       # NEW — the ~60-line inline block extracted from flake.nix:138-166
│                                #   (stretch item, see finding 2)
│
├── modules/
│   ├── README.md                # NEW — system/home split, aggregator convention, optional/ meaning
│   ├── system/
│   │   ├── default.nix          # NEW aggregator — replaces configuration.nix's flat list
│   │   ├── boot.nix … shell.nix  # unchanged
│   │   └── optional/
│   │       └── discord-bot.nix  # converted to options + mkIf; NOT imported by default.nix
│   └── home/
│       ├── default.nix          # NEW aggregator — replaces home.nix's flat list
│       ├── core/{git,neovim,xdg}.nix
│       │   └── dotfiles.nix     # renamed from shell.nix — it deploys all of config/, not shell cfg
│       ├── desktop/*.nix        # unchanged
│       ├── email/
│       │   ├── agent-tools/     # split from the single 761-line file
│       │   │   ├── default.nix
│       │   │   └── {per-wrapper}.nix
│       │   └── {mbsync,aerc,notmuch,protonmail}.nix
│       ├── packages/
│       │   ├── misc.nix         # merged fonts.nix + lean-math.nix + ai-tools.nix (8/8/10 lines)
│       │   └── {dev-tools,media-dictation,email-tools,python}.nix
│       ├── scripts/ + services/ # memory-monitor.nix + memory-services.nix co-located/renamed to match
│       └── misc.nix
│
├── overlays/                    # unchanged — already clean
├── packages/                    # neovim.nix + test-mcphub.sh removed; rest unchanged
├── config/                      # unchanged location (rename rejected, see below)
│   └── README.md                # expanded: document 3 deployment mechanisms, cross-ref dotfiles.nix
├── secrets/                     # unchanged
├── wallpapers/                  # unchanged location (assets/ rejected, see below); 5 cruft files removed
├── docs/                        # README.md index completed; hosts/discord-bot docs updated
├── opencode-discord-bot/
│   └── pyproject.toml           # NEW — packaged via buildPythonApplication
└── specs/                       # untouched by this task
```

### Design-question decisions

| Question | Recommendation | Why |
|---|---|---|
| hosts/ standardization | `lib/mkHost.nix` auto-imports `hosts/<name>/default.nix` via `builtins.pathExists`, so it's optional-but-uniform: no host is *forced* to carry a boilerplate file, but any host *may* have one and it wires itself in without a `flake.nix` edit. Delete `garuda`'s empty placeholder now (it adds nothing); recreate it (auto-picked-up) the moment it needs real content. | Matches existing usage: `nandi`/`hamsa` already work with none; only `garuda` needed manual wiring, and only because of a file with zero content. |
| configuration.nix / home.nix location | **Keep at repo root.** Do not move to `hosts/common/` or similar. | They are referenced from 5+ call sites (`flake.nix:121,135,197`, `lib/mkHost.nix:30,44`, `hosts/README.md`, root `README.md`) and are genuinely repo-level (not per-host) entrypoints carrying `stateVersion`/username — moving them is a rename with no functional gain, unlike introducing the aggregators below which *does* reduce coupling. |
| modules/{system,home}/default.nix aggregators | **Introduce both.** `configuration.nix`/`home.nix` shrink to `{ imports = [ ./modules/system ]; system.stateVersion = "24.11"; }` (and the home equivalent). | Free under Nix's directory-import convention; co-locates the module manifest with the modules; directly enables removing `discord-bot.nix` from the shared list without editing `configuration.nix`'s import array by hand each time a host opts in/out. |
| options pattern vs plain config sets | **Scoped adoption, not blanket conversion.** Amend `.claude/rules/nix.md` to require the options+`mkIf` pattern only for modules under `modules/system/optional/` (or any module a host must be able to selectively enable) — plain config sets remain the norm for the other ~40 always-on modules. Convert `discord-bot.nix` now (it's the one module that actually needs a toggle); do not touch the other 41. | This is a single-user personal-dotfiles repo, not a shared module library — `mkEnableOption` only pays for itself where per-host toggling is real. Blanket conversion is 41 files of churn for a rule that currently has zero enforcement pressure behind it. |
| scripts/ for root shell scripts | **Yes** — `install.sh`, `update.sh`, `build-usb-installer.sh` → `scripts/`. `test-sasl.sh` is deleted (dead), not moved. | Root currently mixes flake/config entrypoints with imperative bootstrap scripts; low-risk mechanical move, but must update its own direct doc references inline (README quick-links, `docs/testing.md`, `docs/usb-installer.md`) as part of the same subtask — not deferred to the final doc-sync pass. |
| assets/ for wallpapers | **Reject — keep `wallpapers/`.** Only clean the 5 scaffolding files out of it. | Exactly one real asset (`riverside.jpg`) exists; both live references (`modules/system/desktop.nix:33`, `modules/home/desktop/gnome.nix:45-52`) already hardcode `wallpapers/`. Generalizing to `assets/` now is speculative — revisit only when a second asset class (icons, sounds) actually appears. |
| config/ rename | **Reject.** Keep the name `config/`; document the Nix-`config`-argument shadowing risk in `config/README.md` instead of renaming. | 17-file rename touching every `home/core/*.nix` reference plus `home.nix` comments for a purely cosmetic naming collision that has caused zero actual bugs in this codebase (verified: no `config/` vs `config` argument confusion found in any file read). Classic touch-everything-for-cosmetics anti-pattern; the seed itself flags this as "weigh cost/benefit" rather than asserting it — cost clearly outweighs benefit here. |

### Refined subtask decomposition (9 subtasks, reordered/merged from the seed's 9)

Dependency chain: **Wave 0** (parallel, zero nix-risk) → **Wave 1** (parallel, nix-touching but
mutually independent) → **Wave 2** (sequential, depends on Wave 1) → **Wave 3** (parallel,
depends on Wave 2) → **Final** (depends on everything).

| # | Subtask | Wave | Depends on | Verification |
|---|---|---|---|---|
| 1 | **Dead code removal**: `home-modules/` + its 3 stale comment refs, `modules/opencode.nix`, `packages/neovim.nix`, `packages/test-mcphub.sh`, `config/rclone.conf`, wallpapers cruft (5 files), `test-sasl.sh`, `test-update.md`, root `TODO.md`. | 0 | none | `git status` shows only deletions; full harness (below) still green since none of these files are imported anywhere (confirmed: none appear in any `imports =` list or `home.file`/`xdg.configFile` source). |
| 2 | **Git hygiene**: `git rm --cached specs/tmp/*`, extend `.gitignore`, fix `update.sh`'s mangled shebang (`#\!/bin/bash` → `#!/bin/bash`) and stray `complete\!`. | 0 | none | `git status --porcelain` clean on `specs/tmp/`; `./update.sh` still executes (shebang fix is cosmetic-functional, not behavioral). |
| 3 | **hosts/ standardization**: `lib/mkHost.nix` gains `builtins.pathExists`-guarded auto-import of `hosts/<hostname>/default.nix`; remove the now-redundant explicit `extraModules = [ ./hosts/garuda/default.nix ]` wiring in `flake.nix`; delete `garuda/default.nix`'s empty body (file itself can stay absent until needed); extract the ISO inline block (`flake.nix:138-166`) to `hosts/iso/default.nix` *only if* the stretch item (conditional hardware-configuration.nix import) is taken — otherwise leave `iso` as the documented, deliberate `mkHost` bypass. Rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example (lines 28-37) to show the current `mkHost { hostname = ...; }` call. | 1 | none | `nix flake check`; `nixos-rebuild build --flake .#nandi` and `.#hamsa` and `.#garuda`; `nix store diff-closures` against pre-change baseline for all three — must be empty (semantically inert, wiring-only change). |
| 4 | **Root shell scripts → `scripts/`**: move `install.sh`, `update.sh`, `build-usb-installer.sh`; update their own direct references in root `README.md`, `docs/testing.md`, `docs/usb-installer.md`. | 1 | none | `grep -rn 'install\.sh\|update\.sh\|build-usb-installer\.sh' docs/ README.md` shows only `scripts/`-prefixed paths; `./scripts/update.sh` runs to completion. |
| 5 | **Module convention + aggregators + discord-bot opt-in** (merges seed's #7 with a new aggregator introduction): amend `.claude/rules/nix.md` to scope the options-pattern requirement to `optional/`-and-host-toggled modules; introduce `modules/system/default.nix` + `modules/home/default.nix` aggregators (move the flat lists out of `configuration.nix`/`home.nix`); convert `modules/system/optional/discord-bot.nix` to `options.services.discordBot.enable` + `mkIf`; remove it from the shared aggregator; add `services.discordBot.enable = true;` to `hosts/nandi/default.nix` (created here, auto-imported per subtask 3's convention); update `docs/discord-bot.md:25`'s "lives in `configuration.nix`" claim. | 2 | 3 (needs the auto-import convention for `hosts/nandi/default.nix` to take effect without a `flake.nix` edit) | Full harness (`nix flake check` + build nandi/hamsa/garuda + `nix build .#homeConfigurations.benjamin.activationPackage`) + explicit check that `nixos-rebuild build --flake .#hamsa` no longer pulls in the Discord bot closure (`nix store diff-closures` between hamsa-with-bot baseline and hamsa-after should show the bot's Python closure removed — this is the one INTENTIONALLY non-inert step in the whole reorg, and must be called out as such rather than run through the inertness harness blindly). |
| 6 | **Module granularity pass**: split `agent-tools.nix` (761 lines) into `email/agent-tools/{default.nix, per-wrapper}.nix`; merge `packages/{fonts,lean-math,ai-tools}.nix` (8/8/10 lines) into `packages/misc.nix`; co-locate `scripts/memory-monitor.nix` + `services/memory-services.nix`; rename `home/core/shell.nix` → `home/core/dotfiles.nix`. | 2 | 5 (new files register in the aggregators from #5 rather than needing a second edit to `home.nix`) | `nix build .#homeConfigurations.benjamin.activationPackage`; `diff-closures` empty (pure file-structure refactor, no logic change). |
| 7 | **opencode-discord-bot packaging**: add `pyproject.toml`, convert to `buildPythonApplication` (or document the "extract to own repo + flake input" alternative and pick one), point the systemd `ExecStart`/`PYTHONPATH` at the built store path instead of `~/.dotfiles/opencode-discord-bot`, fix the `discord-bot.nix:20` comment path typo (`opencode-discord-bot/src/bot.py` → `opencode_discord_bot/src/bot.py`), resolve `opencode.json`. | 3 | 5 (edits the same file's options surface — sequencing after avoids double-editing `discord-bot.nix`) | `nixos-rebuild build --flake .#nandi`; manually verify `systemctl cat discord-bot` (or dry-run equivalent) shows a store path, not a `$HOME` path; this is also an intentionally non-inert step (closure changes to include the packaged bot) — document expected closure delta. |
| 8 | **config/ deployment clarity**: document (not rename) the three deployment mechanisms in `config/README.md`, cross-reference from the new `home/core/dotfiles.nix` header. | 3 | 6 (documents the file `dotfiles.nix` that #6 just renamed) | Doc-only; no build verification needed beyond a stale-reference grep. |
| 9 | **Documentation sync** (final, gated on all above): root README Module Map + package list (drop `neovim.nix`, add `piper-bin.nix`/`piper-voices.nix`, remove "(planned: task 66 ...)" annotations, reflect `scripts/`, `modules/{system,home}/default.nix`); `docs/README.md` index (`dual-home-manager.md`, `email-workflow.md`, `how-to-add-package.md`, `how-to-add-service.md`, `gnome-settings.md`, `video-editing.md`); `hosts/README.md` already updated in #3 — verify it stayed current; new `modules/README.md` (system/home split, aggregator convention, `optional/` meaning, per-subdir granularity from #6). | Final | 1-8 | Full harness once more as a final regression check; manual read-through of README Module Map against `find . -maxdepth 3 -type f` output for drift. |

**Cross-cutting note preserved from the seed**: tasks 68 (zfs/iso+usb-installer build broken),
69 (dual home-manager consolidation), 67 (R env migration) are adjacent open tasks. Subtask 3's
ISO-unification stretch item should explicitly NOT attempt to fix task 68's zfs-kernel breakage —
scope it to the *wiring* refactor only, leaving the iso/usb-installer builds exactly as
buildable/broken as they are today. Subtask 9's doc sync should note task 69 as a known
follow-up rather than attempting to resolve the dual-home-manager question itself.

## Evidence/Examples

- `flake.nix:107-114` — `nandi`/`hamsa` call `mkHost { hostname = "..."; }` with no
  `extraModules`; `garuda` manually adds `extraModules = [ ./hosts/garuda/default.nix ]` even
  though that file's entire body is a comment (`hosts/garuda/default.nix:1-7`, confirmed via
  direct read: `{ ... }: { # Garuda-specific settings (none beyond hardware-configuration.nix for now) }`).
- `lib/mkHost.nix:30-31` — the two hardcoded modules every `mkHost` host gets:
  `"${root}/configuration.nix"` and `"${root}/hosts/${hostname}/hardware-configuration.nix"`.
  Line 31 is exactly why `iso` (no `hardware-configuration.nix`, uses the nixpkgs CD template
  instead) cannot go through `mkHost` today and instead reimplements the same modules inline at
  `flake.nix:118-175`.
- `configuration.nix:25-26` — `discord-bot.nix` is imported unconditionally beneath a comment
  that says "Optional modules — enabled for nandi; may be removed for other hosts" — the comment
  already documents the intent that this be per-host, but no mechanism enforces it.
- `docs/discord-bot.md:25` — table row `| \`configuration.nix\` | \`discordBotPython\` env + sops
  config + both systemd services |` — corroborates that the doc layer also treats
  `configuration.nix` (not a host-scoped file) as the Discord bot's home, so fixing the module
  needs a doc update too (folded into subtask 5, not deferred to subtask 9, since it's a direct
  factual correction not a structural-map rewrite).
- `modules/home/core/shell.nix:20-53` — 17 `home.file`/`home.activation` entries referencing
  `../../../config/*`, confirming the seed's "deploys all of config/, not shell config" naming
  complaint; file is 79 lines, entirely dedicated to this, justifying the `dotfiles.nix` rename.
- `.gitignore:34-36` lists `config/rclone.conf` and `config/zuliprc` under "# Secrets", but
  `git ls-files config/` shows `config/zuliprc` IS tracked (pre-existing exception, out of this
  task's scope) while `config/rclone.conf` correctly is not — confirms the seed's dead-file
  verdict for `rclone.conf` and that no code references it (grep across `modules/` for
  `rclone` returns nothing).
- `wc -l` confirms seed's size claims: `agent-tools.nix` 761, `mbsync.nix` 310, `aerc.nix` 273,
  `packages.nix` 228 — and the merge-candidate fragments: `fonts.nix`/`lean-math.nix` 8 lines
  each, `ai-tools.nix` 10.
- `home.nix:6` — `# ./home-modules/mcp-hub.nix  # Disabled - using lazy.nvim approach` is the
  sole reference to the dead `home-modules/` directory, confirming subtask 1's safety.

## Confidence Level

**High** on: the `mkHost.nix` `pathExists` mechanism, the aggregator introduction, the
discord-bot per-host opt-in design, the config/ and assets/ rejections, and the doc-sync
reordering (all directly grounded in files read this session).

**Medium** on: the ISO-unification stretch item within subtask 3 — it is architecturally sound
but touches `lib/mkHost.nix`'s hardware-configuration.nix assumption, which is used by *every*
host, so its risk profile is higher than the rest of subtask 3; recommend the orchestration
plan treat it as an explicitly optional sub-step with its own gate, not a hard requirement for
subtask 3's completion.

**Medium** on the exact module-granularity split boundaries in subtask 6 (e.g., precisely how
`agent-tools.nix`'s 5 wrapper binaries should be divided into files) — the seed's line-count
inventory is solid evidence a split is warranted, but the specific file boundaries should be
finalized by whichever subtask agent reads `agent-tools.nix` in full during planning, not
prescribed here without reading all 761 lines.

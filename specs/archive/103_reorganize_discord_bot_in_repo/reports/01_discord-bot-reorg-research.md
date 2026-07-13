# Research Report: Task #103

**Task**: 103 - Reorganize the opencode-discord-bot in-repo (host-wiring fix + repo-root declutter)
**Started**: 2026-07-05T19:29:46Z
**Completed**: 2026-07-05T20:23:01Z
**Effort**: Medium (2 independent goals, both mechanical once grounded; verification needs a live
`nixos-rebuild switch` on hamsa which this session cannot execute — see Risks)
**Dependencies**: Follows task 89 (opencode-discord-bot packaging, complete) and task 86 (module
convention + per-host opt-in, complete)
**Sources/Inputs**: Live `hamsa` host state (`systemctl status/cat`, `nixos-version`,
`/run/current-system`), `nix eval`/`nix flake check` against this flake, `flake.nix`,
`lib/mkHost.nix` usage, `modules/system/optional/discord-bot.nix`, `hosts/{hamsa,nandi}/`,
`packages/opencode-discord-bot.nix`, `opencode-discord-bot/` tracked file list, `docs/discord-bot.md`,
`packages/README.md`, `modules/README.md`, `README.md`, `.gitignore` (root + nested), git grep
across the full repo, task 89/86 reports and summaries, task 81 design docs (historical context).
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Drift is real and currently live on hamsa.** hamsa (this session's own host) is running
  `discord-bot.service`/`opencode-serve.service` right now (5 days uptime, since 2026-06-30), but
  the *tracked* flake config for hamsa has **no wiring for either service at all** —
  `nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable` errors with "does not
  provide attribute" (the option doesn't even exist for hamsa, since `hosts/hamsa/` has no
  `default.nix` importing `modules/system/optional/discord-bot.nix`). The **running** unit is a
  **stale pre-task-86/89 build** (`ExecStart=.../bin/python -m opencode_discord_bot.src.bot` with
  `PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot`, not the packaged
  `${opencodeDiscordBot}/bin/opencode-discord-bot` console script) — i.e. hamsa was last switched
  *before* task 86 converted the module to the opt-in `mkIf cfg.enable` pattern, and has not been
  rebuilt since. **The next `nixos-rebuild switch --flake .#hamsa` would silently kill both
  services** because hamsa imports neither the module nor its enable flag. This is exactly the
  "tracked config doesn't match reality" drift the task describes, and it is a real, currently
  latent regression, not a hypothetical.
- `modules/system/optional/discord-bot.nix` itself is already host-agnostic — it defines
  `options.services.discordBot.enable` (`mkEnableOption`) and gates its entire `config` under
  `lib.mkIf cfg.enable`, with no nandi-specific or hamsa-specific logic anywhere inside. **No
  change to the module file is needed for goal 1** — only the host wiring (a new
  `hosts/hamsa/default.nix` mirroring `hosts/nandi/default.nix`, plus a `flake.nix` `extraModules`
  entry for the `hamsa` `mkHost { ... }` call, exactly like `nandi`'s).
- `hosts/hamsa/` currently contains only `hardware-configuration.nix` and `README.md` — no
  `default.nix`. `hosts/hamsa/README.md` line ~26 already anticipates this: *"if hamsa needs
  host-specific overrides, add `hosts/hamsa/default.nix` (hamsa does not currently have one)"*.
- Goal 2 (declutter): 16 tracked files under root `opencode-discord-bot/` (confirmed via
  `git ls-files opencode-discord-bot/` — 14 not 16 by raw count including `.gitignore`,
  `data/.gitkeep`, 12 `.py` files, `pyproject.toml`; the task's "16" figure likely counts
  differently, e.g. including untracked `__pycache__`/`data/sessions.json` present on disk — treat
  the git-tracked set as authoritative for the move). The move is a pure `git mv` of the whole
  directory plus a one-line `src = ` update in `packages/opencode-discord-bot.nix` and doc updates
  in exactly the 4 files the task names (`docs/discord-bot.md`, `packages/README.md`,
  `modules/README.md`, `README.md`) plus historical/comment-only touch-ups inside the moved
  `bot.py`/`store.py` doc-comments (optional, low priority — see Findings).
- **Recommended co-location target: `packages/opencode-discord-bot/`** (the task's own suggestion)
  — it is the cleanest option and the "naming caveat" the task flags is not an actual filesystem
  conflict (`opencode-discord-bot.nix` and `opencode-discord-bot/` are distinct path strings; git
  and Linux filesystems handle a file and a differently-named directory in the same parent without
  issue). The caveat is purely about *visual/discoverability* clarity in a directory listing, and
  is an acceptable, minor cost — no other packages/*.nix in this repo currently vendors its own
  source subdirectory, so this will be the first, and is worth a one-line comment in
  `packages/README.md` to preempt confusion.

## Context & Scope

Task 103 has two independent goals against the same subsystem (the Discord bot infrastructure
introduced across tasks 53/55/56/57/58/86/89):

1. **Host-wiring drift fix**: make `services.discordBot.enable` cleanly enableable on any host,
   enable it on hamsa (to match the service that is actually running there), and decide whether
   nandi should stay enabled.
2. **Repo-root declutter**: move root `opencode-discord-bot/` (16 tracked Python/packaging files)
   to co-locate with its derivation, updating `src =`, `.gitignore`, and 4 named docs.

Both goals were investigated against the actual current repo state (not the task description's
assumptions) since the task explicitly asks to "ground the two goals in the actual repo layout."
This report does not implement anything — it hands findings and a recommended target to `/plan`.

## Findings

### Goal 1: Host-wiring drift

**Current flake host topology** (`flake.nix:126-183`, `lib/mkHost.nix` factory):

| Host | `extraModules` | Discord bot wiring |
|------|----------------|---------------------|
| `nandi` | `[ ./hosts/nandi/default.nix ]` | `hosts/nandi/default.nix` imports `modules/system/optional/discord-bot.nix` and sets `services.discordBot.enable = true;` |
| `hamsa` | *(none — `mkHost { hostname = "hamsa"; }`)* | **Not wired at all.** No `hosts/hamsa/default.nix` exists. |
| `garuda` | *(none)* | Not wired (out of scope per task; not running the bot) |
| `iso` / `usb-installer` | explicit `lib.nixosSystem`/`mkHost`, no discord wiring | Not wired (out of scope) |

Verified live with `nix eval`:
```
$ nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable
error: ... does not provide attribute 'nixosConfigurations.hamsa.config.services.discordBot.enable'
$ nix eval .#nixosConfigurations.nandi.config.services.discordBot.enable
true
```
For hamsa the option doesn't exist in evaluation at all — not merely `false` — because the module
that defines it is never imported into hamsa's module list.

**Yet hamsa is running the service right now** (this research session's own host is hamsa):
```
$ systemctl status discord-bot opencode-serve
● discord-bot.service   Active: active (running) since Tue 2026-06-30 09:40:25 PDT; 5 days ago
● opencode-serve.service Active: active (running) since Tue 2026-06-30 09:39:39 PDT; 5 days ago
$ systemctl cat discord-bot
...
Environment=PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot
ExecStart=/nix/store/9f18v...-python3-3.13.13-env/bin/python -m opencode_discord_bot.src.bot
```
This `ExecStart`/`PYTHONPATH` shape is the **pre-task-89, pre-task-86** unconditional-module
version (task 89's report independently confirmed this exact same staleness on 2026-07-05,
attributing it to "hamsa has not yet had 86's switch applied — sudo was denied to that task's
agent"). `/run/current-system` resolves to
`nixos-system-hamsa-26.05.20260622.3426825`, i.e. hamsa's last activated generation predates the
86/89 module rewrites still on disk in this checkout. `nix flake check` against the *current*
tree passes cleanly for all four `nixosConfigurations` (nandi/hamsa/garuda/iso) plus
`usb-installer`, confirming the repo itself is internally consistent — the drift is specifically
"what's running on hamsa" vs. "what the current flake tree would produce for hamsa," not a syntax
or eval error.

**Consequence if left unfixed**: the next `nixos-rebuild switch --flake .#hamsa` (run by
`scripts/update.sh` or manually) would activate a generation with **no** `discord-bot` or
`opencode-serve` units at all, silently stopping both services with no error (mkIf simply omits
them). This is the concrete regression goal 1 must close.

**The module itself needs no changes.** `modules/system/optional/discord-bot.nix` is already
fully host-agnostic:
- `options.services.discordBot.enable = lib.mkEnableOption "..."` — no host-specific defaults.
- `config = lib.mkIf cfg.enable { sops = {...}; systemd.services = { opencode-serve = {...};
  discord-bot = {...}; }; }` — every value inside references `config.users.users.${username}` (a
  flake-level `specialArgs` value, not per-host), `../../../secrets/secrets.yaml` (repo-relative,
  identical for all hosts), and `../../../packages/opencode-discord-bot.nix` (also repo-relative).
  Nothing in the module assumes nandi.
- The only thing gating which hosts run it is the **import + enable pair**, exactly as
  `modules/README.md` documents: *"`hamsa`, `garuda`, and `iso` do not import it and so never
  evaluate it."* That line is accurate for the *tracked* config; it is the intent this task must
  now also make true of the *running* config.

**Fix shape** (for `/plan`, not implemented here): create `hosts/hamsa/default.nix` mirroring
`hosts/nandi/default.nix`:
```nix
{ ... }:
{
  imports = [ ../../modules/system/optional/discord-bot.nix ];
  services.discordBot.enable = true;
}
```
and add `extraModules = [ ./hosts/hamsa/default.nix ];` to the `hamsa = mkHost { ... };` call in
`flake.nix:132`, matching nandi's pattern at `flake.nix:127-130`. `hosts/hamsa/README.md` already
anticipates this exact file (`"if hamsa needs host-specific overrides, add
hosts/hamsa/default.nix (hamsa does not currently have one)"`) — that README line will need a
follow-up edit once the file exists, though it is not one of the 4 docs the task names explicitly
(worth flagging to `/plan` as a likely-missed doc touch).

**Should nandi stay enabled?** Task 89/86 reports and `hosts/nandi/README.md` both describe nandi
as the deliberate original opt-in host with no report of it being decommissioned or repurposed;
nothing in this session's investigation found evidence nandi should be disabled. Recommend
**keep nandi enabled** — the task only asks to "decide," and there's no signal pointing to
disabling it. If nandi is actually retired hardware (this session cannot reach nandi to check
liveness — task 89's report independently noted "nandi is unreachable from this session"), that
would be a separate, unrelated decision; nothing here indicates that's the case now.

### Goal 2: Repo-root declutter

**Current tracked contents of root `opencode-discord-bot/`** (`git ls-files opencode-discord-bot/`,
14 entries):
```
opencode-discord-bot/.gitignore
opencode-discord-bot/data/.gitkeep
opencode-discord-bot/opencode_discord_bot/__init__.py
opencode-discord-bot/opencode_discord_bot/src/__init__.py
opencode-discord-bot/opencode_discord_bot/src/__main__.py
opencode-discord-bot/opencode_discord_bot/src/api.py
opencode-discord-bot/opencode_discord_bot/src/auth.py
opencode-discord-bot/opencode_discord_bot/src/bot.py
opencode-discord-bot/opencode_discord_bot/src/config.py
opencode-discord-bot/opencode_discord_bot/src/logging_config.py
opencode-discord-bot/opencode_discord_bot/src/opencode_client.py
opencode-discord-bot/opencode_discord_bot/src/permission_view.py
opencode-discord-bot/opencode_discord_bot/src/relay.py
opencode-discord-bot/opencode_discord_bot/src/sse_subscriber.py
opencode-discord-bot/opencode_discord_bot/src/store.py
opencode-discord-bot/pyproject.toml
```
(14 tracked paths; the task description's "16 tracked files" may be counting a slightly different
snapshot or including two files no longer present — `git ls-files` above is the authoritative
current count for planning the move. Also present on disk but **untracked**, gitignored by
`opencode-discord-bot/.gitignore`: `data/sessions.json`, and 16 `__pycache__/*.pyc` files across
two directories — these should NOT be `git mv`'d; `nix flake check`/build does not touch them, and
they'll simply regenerate or be left behind at the old path, harmless either way since they're
untracked.)

**Derivation reference** (`packages/opencode-discord-bot.nix:27`):
```nix
src = ../opencode-discord-bot;
```
This is the single point of truth for the source location as far as the Nix build is concerned —
updating it to `./opencode-discord-bot` (once the directory is co-located under `packages/`) is
the only required code change for the build to keep working. `pythonImportsCheck = [
"opencode_discord_bot" ]` and the `pyproject.toml`'s `[tool.setuptools.packages.find] where =
["."] include = ["opencode_discord_bot*"]` are both relative to `src` and need no changes — they
already resolve correctly regardless of where `src` physically lives, since Nix copies the `src`
tree's contents into the build sandbox rooted at `.` either way.

**`.gitignore` situation**: the **root** `.gitignore` has **no** entries for
`opencode-discord-bot/` at all today (confirmed by reading `.gitignore` in full — its only
per-directory entries are for `config/rclone.conf`, `config/zuliprc`, `/.claude/`, `/.opencode/`,
`/opencode.json`, and `specs/tmp/*`). All bot-specific ignores (`data/sessions.json`,
`__pycache__/`, `*.pyc`, `*.pyo`, editor/IDE cruft, `.venv/`/`venv/`) live in a **nested**
`opencode-discord-bot/.gitignore`, which is itself one of the 14 tracked files being moved. Since
git resolves nested `.gitignore` files relative to their own directory, this file's patterns
continue to work unchanged after a straight `git mv opencode-discord-bot packages/opencode-discord-bot`
— **no edits to any `.gitignore` are actually required**, only the directory relocation (the
task's "plus .gitignore entries" is satisfied by the move itself, not a new edit). Worth
double-checking after the move that `git status` shows no new untracked noise from the relocated
`__pycache__/`/`data/sessions.json` (they'll simply also move on disk if `git mv` is used on the
tracked files and the untracked siblings are moved with a plain `mv`, or left behind harmlessly if
not — either is fine since they're build artifacts, not source).

**All files referencing the current path** (git grep across the full repo, excluding historical
`specs/archive/`, `specs/081.../`, `specs/089.../`, `specs/086.../`, `specs/091.../`,
`specs/095.../`, `specs/096.../`, `specs/097.../`, `specs/098.../` design/report artifacts, which
are point-in-time records and should NOT be edited to reflect the post-move path — same
`specs/**` treatment task 85's research already established for this repo):

| File | Line(s) | Reference | Needs edit? |
|------|---------|-----------|-------------|
| `packages/opencode-discord-bot.nix` | 1, 7-8, 27 | header comment `(opencode-discord-bot/)`, `../opencode-discord-bot` prose + `src = ../opencode-discord-bot;` | **Yes** — update `src =` and the two header-comment path mentions |
| `modules/system/optional/discord-bot.nix` | 21, 32 | `../../../packages/opencode-discord-bot.nix` (callPackage path — **unchanged**, this file itself isn't moving), header comment `~/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` (prose only) | Comment only, optional — the callPackage path is correct either way since `packages/opencode-discord-bot.nix` itself doesn't move, only its `src` |
| `docs/discord-bot.md` | 26-27, 36, 53, 62-63, 113, 269, 308, 328, 406 | multiple prose references to `opencode-discord-bot/`, `../opencode-discord-bot`, and `~/.dotfiles/opencode-discord-bot/` | **Yes** — task explicitly names this file |
| `packages/README.md` | 37-44 | `../opencode-discord-bot`, `opencode-discord-bot/` prose in the `opencode-discord-bot.nix` section | **Yes** — task explicitly names this file |
| `modules/README.md` | — | no direct path references to the source tree (only to the module file and option), no edit needed for goal 2, but task names it — likely because goal 1's host-wiring description at line ~53 ("hamsa... do not import it") will become stale once hamsa is wired in | **Yes** — for goal 1's sake, not goal 2's |
| `README.md` | 43 | tree diagram: `├── opencode-discord-bot.nix   # OpenCode Discord bot relay (buildPythonApplication)` inside the `packages/` subtree | **Yes** — task explicitly names this; add a `opencode-discord-bot/` child entry under it |
| `opencode-discord-bot/opencode_discord_bot/src/bot.py` | 4 | docstring: "Requires PYTHONPATH to include the opencode-discord-bot/ directory." | Already stale pre-task-89 (bot no longer runs via PYTHONPATH); low-priority cleanup, directory basename (`opencode-discord-bot/`) is unchanged by the move so this line remains literally true either way |
| `opencode-discord-bot/opencode_discord_bot/src/store.py` | 18, 33 | comments: "relative to the opencode-discord-bot/ project root" | Same as above — basename unchanged, comment stays accurate; optional to touch |
| `opencode-discord-bot/pyproject.toml` | 6, 16 | `name = "opencode-discord-bot"`, console-script entry point name | **No change** — package/console-script name is independent of directory location |

Note: `README.md`'s tree diagram does **not** currently show root `opencode-discord-bot/` as a
top-level entry at all (only `packages/opencode-discord-bot.nix` appears, inside the `packages/`
list) — so the "declutter" is also fixing a pre-existing documentation gap, not just relocating a
visible tree node.

### Recommended co-location target

The task suggests `packages/opencode-discord-bot/` and flags the caveat of a file/dir with the
same stem living side by side. Investigated alternatives:

1. **`packages/opencode-discord-bot/` (recommended)** — matches the task's own suggestion, requires
   the smallest diff (`git mv` + one `src =` line + 4 docs), and keeps the "one custom package =
   one thing under `packages/`" mental model the repo already has for `piper-bin.nix` +
   `piper-voices.nix`-style pairs (though those are flat files, not directories). The stem
   collision (`opencode-discord-bot.nix` vs. `opencode-discord-bot/`) is **not a filesystem or git
   conflict** — they are distinct path strings and coexist without issue; it is purely a
   readability consideration in a directory listing (`ls packages/` will show both
   `opencode-discord-bot.nix` and `opencode-discord-bot/` adjacent). This is a one-time, permanent
   precedent in this repo (first packages/*.nix with a same-stem co-located source dir) and is
   worth a one-line callout in `packages/README.md`'s `opencode-discord-bot.nix` section so a
   future reader isn't confused by the pairing.
2. **New `pkgs/` or `apps/` directory** (task's stated fallback) — would establish an entirely new
   top-level convention for exactly one package, when `packages/` already exists and holds every
   other custom derivation in this repo (14 files). Rejected: higher blast radius (new top-level
   dir needs its own README, its own tree-diagram entry, and breaks the existing "all custom
   derivations live under `packages/`" invariant `README.md` and `packages/README.md` both state)
   for no discernible benefit over option 1.
3. **Nest under `packages/opencode-discord-bot.nix`'s sibling with a disambiguating suffix**, e.g.
   `packages/opencode-discord-bot-src/` — avoids the stem-collision optics entirely. Viable, but
   inconsistent with the task's own naming (`src = ./opencode-discord-bot` is the example path
   given in the task description) and adds a non-obvious suffix a reader has to learn. Not
   recommended unless `/plan` or the user has an aesthetic objection to option 1's pairing.

**Recommendation: option 1, `packages/opencode-discord-bot/`**, exactly as the task suggests, with
a short explanatory note added to `packages/README.md`.

## Decisions

- Goal 1 requires **no changes to `modules/system/optional/discord-bot.nix`** — it is already
  written generically. The only required changes are a new `hosts/hamsa/default.nix` (mirroring
  `hosts/nandi/default.nix`) and one `extraModules` line in `flake.nix` for the `hamsa` `mkHost`
  call.
- nandi should **stay enabled** — no evidence found to disable it; the task only asks to decide,
  and the default (status quo) is the well-grounded choice.
- Goal 2 target: **`packages/opencode-discord-bot/`**, per the task's own recommendation. The
  file/dir naming pairing is a non-issue technically; document it once in `packages/README.md` to
  preempt confusion, per the task's caveat.
- Root `.gitignore` needs **no new entries** — the nested `opencode-discord-bot/.gitignore` moves
  with the directory and continues to resolve its patterns relative to its own (new) location.
- Untracked build artifacts (`data/sessions.json`, `__pycache__/**`) should be left alone or
  simply `mv`'d alongside the tracked tree with a plain filesystem move — they are gitignored
  either way and irrelevant to the Nix build (Nix only ever reads the git-tracked `src` via the
  flake's filtered source, not the live working tree's stray artifacts).
- Docs to update: `docs/discord-bot.md`, `packages/README.md`, `modules/README.md`, `README.md`
  (all 4 named by the task) — plus, opportunistically, `hosts/hamsa/README.md`'s line noting
  hamsa "does not currently have" a `default.nix`, since goal 1 will make that line stale too
  (not explicitly named by the task, but directly caused by goal 1's fix; flag for `/plan` to
  decide whether it's in scope).

## Risks & Mitigations

- **Live verification on hamsa requires `sudo`.** Task 89's report already established that
  `sudo` is sandbox-denied in agent sessions on this machine (matching this session's own
  constraints). `nix flake check` and `nixos-rebuild build --flake .#hamsa` (build-only, no
  `sudo`) can both be run today and should be treated as the required inertness gate; the actual
  `sudo nixos-rebuild switch --flake .#hamsa` + `systemctl status discord-bot`/`journalctl` runtime
  verification the task also asks for will need to be run by the user (or a session with `sudo`
  access) after implementation — plan for this as a documented manual verification step, not an
  automated one, exactly as task 89's report recommended for its own scope.
- **This task is behavior-changing for hamsa in a good way but still behavior-changing**: applying
  the fix and switching will replace the current stale pre-86/89 unit (PYTHONPATH-based) with the
  current packaged (task-89) unit (nix-store console-script based). This is the intended outcome
  (tracked config matching a *correct, current* build, not just matching whatever happens to be
  running), but should be called out explicitly in the plan/summary as an expected, positive
  closure/behavior delta — mirroring how task 89's own report flagged its ExecStart change as
  "explicitly behavior-changing."
- **Moving `opencode-discord-bot/` changes `src` in a derivation that's referenced only from one
  call site** (`modules/system/optional/discord-bot.nix:21`, via a repo-relative
  `../../../packages/opencode-discord-bot.nix` path that does not change). Confirm after the move
  that `pythonImportsCheck = [ "opencode_discord_bot" ]` still passes (`nix build
  .#nixosConfigurations.hamsa.config.systemd.services.discord-bot...` or more directly building the
  derivation standalone via `nix build --impure --expr` or `pkgs.python3Packages.callPackage
  packages/opencode-discord-bot.nix {}` in a `nix repl`) before considering goal 2 done — this is a
  cheap, sandboxed, no-`sudo` check.
- **Ordering the two goals**: they touch disjoint files (goal 1: `hosts/hamsa/default.nix`,
  `flake.nix`; goal 2: `opencode-discord-bot/` → `packages/opencode-discord-bot/`, `packages/opencode-discord-bot.nix`,
  4 docs) except for shared doc touch-ups in `docs/discord-bot.md`/`modules/README.md`/`README.md`.
  Recommend implementing goal 2 (mechanical move) first, then goal 1 (host wiring), so the final
  `nixos-rebuild build --flake .#hamsa` verification exercises both changes together in one pass
  rather than requiring two separate build checks — or implement in either order and do one
  combined build check at the end; either sequencing is safe since the changes don't conflict.

## Appendix

### Commands run during research

```bash
git ls-files opencode-discord-bot/
cat packages/opencode-discord-bot.nix
cat modules/system/optional/discord-bot.nix
cat hosts/nandi/default.nix hosts/hamsa/README.md hosts/nandi/README.md
grep -n "hamsa\|nandi\|nixosConfigurations" flake.nix
grep -n -i "discord" .gitignore opencode-discord-bot/.gitignore
git grep -n "opencode-discord-bot"   # full-repo, then filtered against historical specs/ dirs
nix flake check
nix eval .#nixosConfigurations.hamsa.config.services.discordBot.enable   # errors: option absent
nix eval .#nixosConfigurations.nandi.config.services.discordBot.enable  # => true
systemctl status discord-bot opencode-serve --no-pager
systemctl cat discord-bot
nixos-version; readlink -f /run/current-system
```

### References

- `specs/089_opencode_discord_bot_packaging/reports/02_opencode-discord-bot-packaging.md` — prior
  task's independent confirmation of hamsa's stale pre-86 unit, and its "nix-eval substitute for
  live systemctl verification" precedent (relevant to this task's own verification constraints).
- `specs/086_module_convention_discord_bot_opt_in/` — established the `mkEnableOption` +
  `mkIf cfg.enable` pattern this task's goal 1 wiring reuses verbatim.
- `.claude/rules/nix.md` §"Optional / Host-Toggled Modules" — the authoritative convention
  `hosts/hamsa/default.nix` must follow.
- `modules/README.md` — documents the current (soon-to-be-partially-stale) host-wiring state;
  needs the goal-1 sentence about hamsa updated.
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  ("opencode-discord-bot/ — structurally misplaced" section) — original identification of the
  root-clutter problem this task's goal 2 resolves; historical, not to be edited.

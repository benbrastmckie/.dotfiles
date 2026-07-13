# Research Report: Task #89 — opencode-discord-bot packaging

**Task**: 89 - Package opencode-discord-bot via buildPythonApplication
**Started**: 2026-07-05T05:35:00Z
**Completed**: 2026-07-05T05:53:39Z
**Effort**: ~5 (per design blueprint row 8)
**Dependencies**: Task 86 (module convention + per-host discord-bot opt-in) — **confirmed landed**
**Sources/Inputs**: `modules/system/optional/discord-bot.nix` (current, post-86), `opencode-discord-bot/`
source tree, `packages/*.nix` precedents, `overlays/python-packages.nix`, root `opencode.json` /
`config/opencode.json`, `flake.nix`, `flake.lock`, live `hamsa` host state (`systemctl cat`,
`journalctl`), `nix eval` against `nixosConfigurations.nandi`, task 86 plan/summary/reports,
design doc `specs/081.../design/target-layout.md` §1.3/§2/§3/§4.3, seed reports
`specs/081.../reports/01_repo-organization-review.md` + `02_team-research.md`,
`specs/089.../reports/01_seed.md`.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 86 has landed as expected: `discord-bot.nix` now has `options.services.discordBot.enable`
  (line 19) + `config = lib.mkIf cfg.enable { ... }` (line 30/121), and only `nandi` opts in
  (`hosts/nandi/default.nix` + `flake.nix` `extraModules`). This confirms task 89's dependency is
  satisfied and gives a stable base to convert underneath.
- All four line/path citations in the task description have **drifted or need correction** after
  86's rewrite — verified exact current locations below. Most notably, the comment-typo line is
  now **26**, not 20.
- **New, previously-undocumented blocker discovered**: `opencode_discord_bot/src/store.py`'s
  `SessionStore` computes its default persistence path from `__file__` (package install
  location) and calls `os.makedirs()` + atomic temp-file writes there. Once packaged into the
  (read-only) nix store, this will raise `OSError`/`PermissionError` the first time a session is
  linked — a **functional regression**, not just a wiring change. This must be fixed as source
  code (not just Nix) in this task's scope; see Findings §"Session-store nix-store-write hazard".
- Root `opencode.json` (tracked) vs. `config/opencode.json` (tracked, different file, unrelated)
  are easy to confuse — confirmed they are two distinct files with two distinct purposes. Only the
  **root** one is the inconsistency in scope.
- Found a fully automatable, no-sudo, no-remote-access verification method for the runtime
  behavior change (`nix eval` against the evaluated `nixosConfigurations.nandi` module tree) that
  is strictly better than the design doc's switch-and-`systemctl cat` approach for this repo's
  constraints (nandi is unreachable from this session; `sudo` is sandbox-denied, per task 86's own
  precedent).
- Recommended package shape: a genuine `buildPythonApplication` (not routed through the existing
  `pythonPackagesOverlay`, which is scoped to *library* overrides consumed via
  `python3.withPackages`) wired directly in `discord-bot.nix`'s existing `let` block, replacing
  `discordBotPython`/`PYTHONPATH` with a single `${opencodeDiscordBot}/bin/opencode-discord-bot`
  `ExecStart`.

## Context & Scope

Task 89 is subtask #8 of task 81's blueprint (Tier 2), gated on task 86 (module convention +
per-host opt-in), which completed 2026-07-05 per
`specs/086_module_convention_discord_bot_opt_in/summaries/01_module-convention-opt-in-summary.md`.
Scope per the task description and seed report (`specs/089.../reports/01_seed.md`):

1. Add `opencode-discord-bot/pyproject.toml`; convert packaging to `buildPythonApplication` under
   `packages/` (near-term, in-tree — NOT extraction to its own repo).
2. Point `ExecStart`/`PYTHONPATH` at the built nix-store path instead of
   `~/.dotfiles/opencode-discord-bot`.
3. Fix the `discord-bot.nix` comment path typo.
4. Resolve the untracked-`.opencode/`-vs-tracked-`opencode.json` inconsistency.

Scope boundary (per seed): `packages/`, `modules/system/optional/discord-bot.nix`,
`opencode-discord-bot/`, root `opencode.json`. Verification level: RUNTIME + BUILD.

## Findings

### 1. Current state of `modules/system/optional/discord-bot.nix` (post-task-86, verified line-by-line)

Full current file read and line-numbered. Key facts, with **exact current line numbers**
(all task-description line citations have shifted since 86's rewrite added the `options`/`cfg`/
`mkIf` wrapper):

- Line 19: `options.services.discordBot.enable = lib.mkEnableOption "the OpenCode Discord bot
  relay (discord-bot + opencode-serve services)";` — confirms task 86 landed correctly.
- **Line 26** (task description cites "line 20" — that citation is now stale/wrong post-86):
  `# Bot project: ~/.dotfiles/opencode-discord-bot/src/bot.py (Nextcord)` — this is the typo.
  The real path is `~/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` (the
  comment is missing the entire inner `opencode_discord_bot/` package directory component, not
  just an underscore/hyphen swap — verified against `git ls-files opencode-discord-bot`).
- Lines 87-119: the `discord-bot` systemd service block.
  - Line 95: `ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";`
  - Lines 105-114: the `Environment = [ ... ];` list (task description's "line 105" now points at
    the **opening bracket of this list**, not the PYTHONPATH line itself).
  - **Line 113**: `"PYTHONPATH=${config.users.users.${username}.home}/.dotfiles/opencode-discord-bot"`
    — this is the literal value that must become unnecessary (packaged apps carry their own
    import path via `makeWrapper`) rather than merely repointed.
  - Line 115: `WorkingDirectory = "${config.users.users.${username}.home}/.dotfiles";` — currently
    shared with `opencode-serve`'s `WorkingDirectory` (used there because `opencode-serve` needs
    `.opencode/` config in cwd; `discord-bot` doesn't need cwd for imports post-packaging, but
    see the session-store finding below for why a `WorkingDirectory`-or-`StateDirectory` decision
    still matters).
  - Lines 12-16: `discordBotPython = pkgs.python3.withPackages (p: with p; [ nextcord aiohttp
    anyio ]);` — this ad hoc environment is the thing being replaced by a real application
    derivation; nothing else in the file references `discordBotPython`, so removing it is safe.

Live verification on `hamsa` (this session's host) confirms the file matches disk exactly:
`systemctl cat discord-bot.service` shows `ExecStart=/nix/store/9f18v...-python3-3.13.13-env/bin/python
-m opencode_discord_bot.src.bot` and `Environment=...PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot`
verbatim (hamsa has not yet had 86's switch applied — sudo was denied to that task's agent, so
hamsa is still running the **pre-86** unconditional-import version; this is expected and
documented in task 86's summary, not a task-89 concern).

### 2. `opencode-discord-bot/` source tree

- Tracked files: `data/.gitkeep`, `.gitignore`, and 12 Python files under
  `opencode_discord_bot/{__init__.py, src/{__init__.py, __main__.py, api.py, auth.py, bot.py,
  config.py, logging_config.py, opencode_client.py, permission_view.py, relay.py,
  sse_subscriber.py, store.py}}`. No `pyproject.toml`/`setup.py`/`requirements.txt` exist today —
  confirmed via `find`.
- Untracked (gitignored via `opencode-discord-bot/.gitignore`): `data/sessions.json`,
  `__pycache__/**` (currently present on disk, not a git concern — these are ordinary runtime
  artifacts of the current PYTHONPATH-based execution and will simply not exist once the source
  moves into a nix-store build).
- External imports used across all source files (`grep -h '^import\|^from'`):
  `aiohttp`, `nextcord` (+ `nextcord.ext`, `nextcord.ui`), plus stdlib only. **`anyio` is listed
  in `discordBotPython`'s package set but is not actually imported anywhere in the source** —
  worth flagging to the planner as a candidate to drop from the new package's dependency list
  (verify with a repo-wide `grep -rn anyio opencode-discord-bot/` — it returned zero matches).
- `nextcord` is available in the pinned nixpkgs (`nixos-26.05`, locked rev `cf3ffa5d...`) at
  version `3.2.0` — confirmed via `nix eval --raw 'nixpkgs#python3Packages.nextcord.version'` and
  independently via task 86's own closure inspection (`python3.13-nextcord-3.2.0` present in
  nandi's build). `aiohttp` is a mainstream nixpkgs package; no availability risk for either.
- Entry point: `opencode_discord_bot/src/__main__.py` documents the *intended* invocation as
  `python -m opencode_discord_bot.src.bot` (not `.src`), and `bot.py:420-431` has a `main()`
  function guarded by `if __name__ == "__main__": main()`. This maps directly onto a
  `[project.scripts]` console-script entry point: `opencode_discord_bot.src.bot:main`.

### 2a. Session-store nix-store-write hazard (new finding — required scope addition)

`opencode_discord_bot/src/store.py:18-23`:

```python
_DEFAULT_STORE_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "data",
)
_DEFAULT_STORE_PATH = os.path.join(_DEFAULT_STORE_DIR, "sessions.json")
```

`bot.py:46` calls `SessionStore()` with **no path argument**, so this default is always used.
`__file__` resolves three `dirname()`s up from `.../opencode_discord_bot/src/store.py`, i.e. to
whatever directory contains the `opencode_discord_bot/` package — today that's
`~/.dotfiles/opencode-discord-bot` (writable, matches the tracked `data/` directory with the
gitignored `sessions.json` inside it). `_save()` (store.py:59-81) then does
`os.makedirs(store_dir, exist_ok=True)` followed by a temp-file-write + `os.replace()` — a normal,
correct atomic-write pattern **for a writable filesystem**.

Once `opencode_discord_bot` is installed via `buildPythonApplication`, `__file__` resolves inside
`/nix/store/<hash>-opencode-discord-bot-<ver>/lib/python3.13/site-packages/opencode_discord_bot/src/store.py`,
so `_DEFAULT_STORE_DIR` becomes a path *inside the nix store* — read-only at runtime. The very
first `session_store.link(...)` call (any time a Discord thread is created) will raise
`PermissionError`/`OSError` from `os.makedirs`/`tempfile.mkstemp`, uncaught by `_save()`'s
exception handling (which only catches around the temp-file write, re-raising after cleanup, not
around `os.makedirs`). This is a **functional regression** silently introduced by "just" pointing
`ExecStart` at a store path — not covered by the task description's literal wording (which only
mentions `ExecStart`/`PYTHONPATH`), but squarely inside its "point the systemd unit... at the
built nix-store path" intent, since the whole point is for the bot to *run* correctly from the
store.

**Required fix (recommend deciding exact shape during planning, not here)**: introduce an
explicit, environment-driven override for the session-store path — e.g. add a
`session_store_path: str | None` field to `Config` (read from a new `SESSION_STORE_PATH` env var,
optional), thread it into `SessionStore(path=...)` at the `bot.py:46` call site, and set
`Environment=["SESSION_STORE_PATH=%S/discord-bot/sessions.json"]` +
`StateDirectory = "discord-bot";` in the systemd unit (systemd creates/owns
`/var/lib/discord-bot` with correct ownership on first start — the idiomatic mechanism for a
packaged app's mutable state, and consistent with "off the `$HOME` path" as much as the
`ExecStart` change is). A same-effort but less-idiomatic alternative is to keep the current
`data/sessions.json` inside `~/.dotfiles/opencode-discord-bot/data/` by setting
`SESSION_STORE_PATH` to that literal path (no migration, but state remains under `$HOME`,
partially undercutting the intent of getting off the working tree). Recommend the `StateDirectory`
approach and flag the existing `data/sessions.json` on disk as a one-time manual migration note
(copy to `/var/lib/discord-bot/sessions.json` before/after first switch, or accept a clean slate —
low-stakes, session-to-thread links only).

### 3. `packages/` precedent and packaging shape

- `packages/` currently has 12 files, all either `writeShellScriptBin` wrappers
  (`aristotle.nix`, `claude-code.nix`) or **library** `buildPythonPackage` derivations
  (`python-cvc5.nix`, `pymupdf4llm.nix`, `python-vosk.nix`) wired into `python3Packages` via
  `overlays/python-packages.nix`'s `customPythonPackages` override — consumed elsewhere via
  `pkgs.python3.withPackages`. **There is no existing precedent in this repo for a
  `buildPythonApplication`** (a standalone executable, not a library to compose into an
  environment). This is architecturally different from the three existing Python packages: it
  should NOT be routed through `overlays/python-packages.nix` (that overlay's purpose is library
  overrides for composition into `python3.withPackages`, a different consumer), but instead
  `callPackage`d directly and locally, mirroring how `discordBotPython` is already defined inline
  in `discord-bot.nix`'s own `let` block today.
- Recommended new file: `packages/opencode-discord-bot.nix`, in the `buildPythonApplication`
  shape (`pyproject = true;`, `build-system = [ setuptools ]`, `dependencies = [ nextcord aiohttp
  ]` — drop `anyio`, see finding above, unless the planner wants to keep it defensively since it's
  cheap and nixpkgs-available). `pythonImportsCheck = [ "opencode_discord_bot" ]` should work
  offline (no network/credential-dependent code executes at bare import time — `Config.from_env()`
  and `nextcord.Client()` construction happen inside `main()`, not at module import).
- `src = ../opencode-discord-bot;` (relative from `packages/`) is the correct source pointer. Nix
  flakes only see git-tracked (or `git add`-staged) files under `self`, so `data/sessions.json`
  and `__pycache__/**` (both gitignored/untracked) will automatically be excluded from the built
  closure without any extra filtering — confirmed this is exactly why the design doc's "stage
  before verify" rule (`git add <specific paths>`, never `-A`) exists and matters here concretely:
  the new `pyproject.toml` and `packages/opencode-discord-bot.nix` **must be `git add`-staged**
  before any `nix build`/`nix eval`/`nixos-rebuild build` will see them.
- Wiring: add e.g. `opencodeDiscordBot = pkgs.python3Packages.callPackage
  ../../../packages/opencode-discord-bot.nix { };` next to (replacing) the current
  `discordBotPython` binding in `discord-bot.nix`, then `ExecStart =
  "${opencodeDiscordBot}/bin/opencode-discord-bot";` and delete the `PYTHONPATH=...` line from
  `Environment` entirely (a `buildPythonApplication`-produced wrapper sets up `sys.path`/
  `PYTHONPATH` internally via `makeWrapper`, so it is not merely "repointed" but made obsolete).
  `packages/README.md` should also gain a short `opencode-discord-bot.nix` section for
  consistency with every other package's documentation there (all 8 existing packages have one) —
  a natural addition for whoever plans this, though not explicitly called out in the task
  description.

### 4. Runtime verification: unit-name discrepancy + an automatable alternative to switch-and-`systemctl`

- The design doc's §4.3 example commands (`systemctl status opencode-discord-bot.service`,
  `journalctl -u opencode-discord-bot.service`, `systemctl cat opencode-discord-bot.service`) use
  the **wrong unit name**. The actual systemd unit defined in `discord-bot.nix`'s
  `systemd.services` attrset is named **`discord-bot`** (and its sibling `opencode-serve`), not
  `opencode-discord-bot`. Confirmed live: `systemctl list-units | grep -i discord` on hamsa shows
  `discord-bot.service`, and `systemctl cat discord-bot.service` succeeds while
  `opencode-discord-bot.service` would not exist. The planner/implementer should use
  `discord-bot.service` in all verification commands.
- **nandi is unreachable from this session** (this research ran on `hamsa`), and task 86's own
  summary already hit a hard `sudo`-denial wall trying to live-verify on `hamsa` — the same
  constraint will apply to task 89's implementer on either host. A `nixos-rebuild switch
  --flake .#nandi` + `systemctl cat` round-trip is therefore **not obtainable** from an agent
  session on this machine, mirroring task 86's "Outstanding Manual Step" precedent.
- **Discovered fully-automatable substitute**, requiring no switch, no sudo, and no network
  access to nandi — evaluate the already-materialized NixOS module tree directly:
  ```bash
  nix eval --raw '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.ExecStart'
  nix eval --json '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.Environment'
  nix eval --raw '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.WorkingDirectory'
  ```
  Verified working today (**pre-fix baseline**, captured this session):
  - `ExecStart` = `/nix/store/9f18vrbacdi0vzj5csbrs3n9pvanjnk2-python3-3.13.13-env/bin/python -m
    opencode_discord_bot.src.bot`
  - `Environment` includes `"PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"` verbatim.

  Post-fix, the same two commands should show `ExecStart` resolving to
  `/nix/store/<hash>-opencode-discord-bot-<ver>/bin/opencode-discord-bot` and the `Environment`
  array **no longer containing any `PYTHONPATH=...dotfiles...` entry** — a precise, byte-for-byte,
  fully automatable proof of the behavior change, strictly stronger evidence than a live
  `systemctl cat` (which additionally requires an actual switch+running system) for exactly the
  property this task cares about (does the store path resolve, and is the `$HOME` string gone).
  Recommend the implementation plan adopt this as the primary automated check, with the live
  `nixos-rebuild switch --flake .#nandi` + `systemctl cat discord-bot.service` step documented as
  an **Outstanding Manual Step** for a human with SSH/sudo access to nandi (same posture task 86
  took for hamsa).
- The pre-existing crash loop on hamsa (`nextcord.gateway: Shard ID None heartbeat blocked for
  more than 10300 seconds`, confirmed via `journalctl -u discord-bot.service`) is an asyncio
  event-loop bug unrelated to packaging — it is running the **pre-86** unconditional-import
  version on hamsa (hamsa's switch is still outstanding from task 86), not a symptom of anything
  task 89 touches. Do not conflate; do not attempt to fix it in this task.

### 5. `opencode.json` / `.opencode/` inconsistency

Two distinct, same-named files exist in this repo — confirmed they serve unrelated purposes and
must not be conflated:

| File | Tracked? | Purpose | In scope for task 89? |
|---|---|---|---|
| `/opencode.json` (root) | **Yes** (git-tracked; added in commit `70d1117` "added new agent system") | OpenCode CLI **agent-orchestration framework** config — 6 `agent` entries, each `prompt` pointing at `{file:.opencode/agent/subagents/*.md}` | **Yes — this is the one in scope** |
| `config/opencode.json` | Yes (unrelated, fine) | The actual OpenCode **application** config, deployed via `modules/home/core/shell.nix:20`'s `home.file` to `~/.config/opencode/opencode.json`; documented in `config/README.md:46` and referenced by `docs/discord-bot.md:294` (`default_agent` troubleshooting) | No — untouched, unrelated, do not edit |

- `.opencode/` (like `.claude/`) is **entirely gitignored**: `.gitignore:37` is `/.opencode/`
  (mirroring `.gitignore:36`'s `/.claude/`). Confirmed via `git ls-files .claude` and
  `git ls-files .opencode` both returning **zero** tracked files, and `git check-ignore -v` on
  both `.opencode/AGENTS.md` and `.claude/CLAUDE.md` confirming both are ignored by those exact
  `.gitignore` lines. On disk today, `.opencode/` is fully populated (agent/, commands/, context/,
  skills/, etc. — the OpenCode-flavored mirror of `.claude/`'s own agent framework), just not
  committed to this repo's git history — exactly analogous to how `.claude/` is populated locally
  but untracked.
- **The actual inconsistency**: `.claude/` is *fully self-consistent* under this treatment — **no
  tracked file in the repo assumes `.claude/`'s presence** (its own `CLAUDE.md` explicitly says
  "This file is generated automatically" and is itself untracked). Root `opencode.json` breaks
  that symmetry: it is the **one tracked file in the repo** that hard-references 6+ paths inside
  the untracked `.opencode/agent/subagents/` tree (verified all 6 referenced files exist on this
  machine's local `.opencode/`, e.g. `nix-research-agent.md`, `nix-implementation-agent.md`,
  `python-research-agent.md`, etc. — but a fresh clone of the bare dotfiles repo would have a
  dangling `opencode.json` until `.opencode/` is separately installed by whatever out-of-band
  tooling installs `.claude/`).
- **Recommended resolution**: untrack root `opencode.json` (`git rm --cached opencode.json`) and
  add a `/opencode.json` line to `.gitignore` immediately alongside the existing `/.claude/` and
  `/.opencode/` lines. This restores exact symmetry with `.claude/`'s treatment, requires zero
  content edits to the file itself (it keeps working locally exactly as before — git-ignoring a
  file doesn't delete it from disk), and is minimal/reversible. `git log --oneline -- opencode.json`
  shows only 2 commits ever touched it (its addition, plus one unrelated `checkpoint: auto-commit
  before update`), so no other tooling depends on it staying tracked. (Report 01's original
  phrasing — "relocate or remove" — is satisfied by the untrack option, which is safer than
  deletion since the working file is preserved.)

## Decisions

- Package as a genuine `buildPythonApplication` wired directly in `discord-bot.nix` (not routed
  through `overlays/python-packages.nix`, which is scoped to library overrides for
  `python3.withPackages` composition — an architecturally different consumer than a systemd
  `ExecStart` target).
- Treat the session-store nix-store-write hazard (§2a) as in-scope required work, not a follow-on
  — the task's own "RUNTIME + BUILD" verification level and "point ExecStart... at the built
  nix-store path" intent are not actually satisfied if the bot crashes on first session-link.
- Use `nix eval` against `nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig`
  as the primary automated runtime-shape check (§4), deferring the live switch+`systemctl cat`
  round-trip to an Outstanding Manual Step for a human with nandi access — mirrors task 86's
  precedent for hamsa exactly.
- Untrack root `opencode.json` (add to `.gitignore` next to `/.claude/`/`/.opencode/`) rather than
  deleting it, restoring symmetry with the `.claude/` precedent with a fully reversible change.
- Correct the design doc's §4.3 unit name (`opencode-discord-bot.service` → `discord-bot.service`)
  in the implementation plan's verification steps; do not propagate the wrong name.

## Risks & Mitigations

- **Session-store write failure post-packaging** (highest-severity, silent-until-first-use risk):
  mitigated by the `SESSION_STORE_PATH`/`StateDirectory` fix in §2a; without it, this task would
  ship a bot that crashes (or silently loses session links, depending on exception propagation
  through `bot.py`'s call sites) the first time anyone uses `/link`.
- **nandi unreachable for live verification**: mitigated by the `nix eval`-based automated proxy
  (§4) plus an explicit Outstanding Manual Step, matching task 86's already-accepted pattern for
  this repo's environment constraints.
- **Untracking `opencode.json` could be seen as scope creep on a nix-focused task**: mitigated by
  it being explicitly named in the task's own scope (item 4) and its scope boundary line ("root
  `opencode.json`"); the fix is a one-line `.gitignore` addition + `git rm --cached`, not a
  content rewrite, so blast radius is minimal.
- **Comment-typo line number drift**: mitigated by verifying the exact current line (26, not 20)
  in this report before planning; re-verify once more immediately before editing in case other
  task-89-adjacent edits land first.
- **`anyio` dependency may be dead**: flagged, not required to resolve in this task; the planner
  can choose to keep it defensively (zero cost, already in nixpkgs) or drop it (verified unused
  via `grep`) — either is safe.

## Appendix

Search/verification commands used (representative, not exhaustive):

```bash
cat -n modules/system/optional/discord-bot.nix
git ls-files opencode-discord-bot | sort
find opencode-discord-bot -type f | sort
grep -RhoE "^import [a-zA-Z0-9_]+|^from [a-zA-Z0-9_.]+ import" opencode-discord-bot/opencode_discord_bot/src/*.py | sort -u
cat overlays/python-packages.nix
nix eval --raw 'nixpkgs#python3Packages.nextcord.version'
jq -r '.nodes.nixpkgs.locked | "\(.rev) \(.lastModified)"' flake.lock
systemctl cat discord-bot.service
journalctl -u discord-bot.service -n 30 --no-pager
nix eval --raw '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.ExecStart'
nix eval --json '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.Environment'
git ls-files .claude | wc -l   # 0
git ls-files .opencode | wc -l # 0 (implied by same check-ignore result)
git check-ignore -v .claude/CLAUDE.md .opencode/AGENTS.md opencode.json
git log --oneline -- opencode.json
```

References:
- `specs/086_module_convention_discord_bot_opt_in/summaries/01_module-convention-opt-in-summary.md`
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` §1.3, §2 row 8,
  §3 row 8, §4.3
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  ("opencode-discord-bot/" section)
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md` (Conflicts
  Resolved #1, Decision Table row 8)
- `specs/089_opencode_discord_bot_packaging/reports/01_seed.md`

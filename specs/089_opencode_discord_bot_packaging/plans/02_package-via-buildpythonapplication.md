# Implementation Plan: Task #89 — Package opencode-discord-bot via buildPythonApplication

- **Task**: 89 - Package opencode-discord-bot via buildPythonApplication
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: Task 86 (module convention + per-host opt-in) — confirmed landed
- **Research Inputs**: specs/089_opencode_discord_bot_packaging/reports/02_opencode-discord-bot-packaging.md
- **Artifacts**: plans/02_package-via-buildpythonapplication.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; nix.md; git-workflow.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Convert `opencode-discord-bot/` from a working-tree PYTHONPATH import into a genuine
`buildPythonApplication` derivation (`packages/opencode-discord-bot.nix`), `callPackage`d directly
in `modules/system/optional/discord-bot.nix`, and repoint the `discord-bot` systemd unit's
`ExecStart` at the built nix-store binary. Along the way, fix a runtime-blocking source defect
(`SessionStore`'s `__file__`-relative default path resolves inside the read-only nix store once
packaged) via a `SESSION_STORE_PATH` env var backed by a systemd `StateDirectory`, correct a
stale comment path typo, and restore `.claude/`-symmetry by untracking root `opencode.json`.
This is a BEHAVIOR-CHANGING task: the closure gains the packaged bot and the runtime import path
moves from the `$HOME` working tree to the nix store. Definition of done: `nixos-rebuild build
--flake .#nandi` succeeds and `nix eval` on `nandi`'s evaluated `discord-bot.serviceConfig` shows
`ExecStart` resolving to the store-path binary with no `PYTHONPATH=...dotfiles...` entry remaining.

### Research Integration

Integrates report `02_opencode-discord-bot-packaging.md`:
- Verified current (post-task-86) line numbers: comment typo at **line 26**, `ExecStart` at line
  95, `PYTHONPATH` literal at **line 113**, `Environment` list opens at line 105, `discordBotPython`
  at lines 12-16. Phase tasks re-verify immediately before editing (drift guard).
- Session-store nix-store-write hazard (§2a) is treated as **in-scope required work**, not a
  follow-on: the packaged bot would crash on first `/link` without it.
- No `buildPythonApplication` precedent exists in `packages/` (confirmed: `grep -rl` returns none);
  the three existing Python packages are libraries routed through `overlays/python-packages.nix`.
  This app is `callPackage`d directly in `discord-bot.nix` — NOT via the overlay.
- Design doc §4.3's unit name is wrong: the real unit is **`discord-bot.service`**, not
  `opencode-discord-bot.service`. All verification commands use `discord-bot`.
- `nandi` is unreachable and `sudo`/switch are sandbox-denied; the automated substitute is
  `nix eval` against `nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig`
  (baseline captured in the report). Live switch + `systemctl cat` is an Outstanding Manual Step.
- `anyio` is listed in `discordBotPython` but imported nowhere (verified); dropped from the new
  derivation's dependency list.

### Prior Plan Reference

No prior plan. Report 01 (seed) and report 02 (full research) are the only prior artifacts.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (no `roadmap_path` provided). Task 89 is subtask #8 of
task 81's blueprint (Tier 2), gated on task 86.

## Goals & Non-Goals

**Goals**:
- Add `opencode-discord-bot/pyproject.toml` and `packages/opencode-discord-bot.nix`
  (`buildPythonApplication`).
- Fix `SessionStore`'s read-only-store write hazard with a `SESSION_STORE_PATH` env var +
  systemd `StateDirectory`.
- Point `discord-bot` `ExecStart` at `${opencodeDiscordBot}/bin/opencode-discord-bot`; delete the
  now-obsolete `PYTHONPATH` entry and the `discordBotPython` binding.
- Fix the `discord-bot.nix` comment path typo (line 26).
- Untrack root `opencode.json` (`git rm --cached` + `.gitignore`), restoring `.claude/` symmetry.
- Prove the runtime-shape change via `nix eval` (byte-for-byte pre/post) and a successful build;
  document the intentional closure delta.
- Document (do not implement) future own-repo extraction, mirroring the email-extension precedent.

**Non-Goals**:
- Do NOT touch `config/opencode.json` (unrelated OpenCode application config, deployed via
  home-manager).
- Do NOT extract `opencode-discord-bot/` to its own repository (documented as future work only).
- Do NOT attempt a live `nixos-rebuild switch`/`sudo`/`systemctl` on `nandi` (unreachable;
  Outstanding Manual Step for a human).
- Do NOT fix the pre-existing hamsa heartbeat/asyncio crash loop (unrelated pre-86 issue).
- Do NOT use `git add -A`/`git commit -am`; stage specific paths only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Session-store write crash on first `/link` post-packaging | H | H (certain without fix) | Phase 1 `SESSION_STORE_PATH` + Phase 3 `StateDirectory`; verified by inspecting the built `Environment` array in Phase 5 |
| Comment-typo line number drifts again before editing | L | M | Phase 3 re-greps for the exact comment string immediately before editing rather than trusting line 26 |
| New files invisible to flake eval/build (untracked) | H | M | Phase 5 `git add <specific paths>` for `pyproject.toml` + `packages/opencode-discord-bot.nix` BEFORE any `nix build`/`nix eval` |
| `pythonImportsCheck` fails in the sandbox | M | L | Report confirms bare import runs no network/credential code; `pythonImportsCheck = [ "opencode_discord_bot" ]` only |
| Untracking `opencode.json` seen as scope creep | L | L | Explicitly in task scope (item 4); one-line `.gitignore` add + `git rm --cached`, no content edit, fully reversible |
| Existing `data/sessions.json` links lost on cutover | L | M | Documented one-time manual migration to `/var/lib/discord-bot/sessions.json` as an Outstanding Manual Step (low stakes: session→thread links only) |
| Over-staging pulls in concurrent/unrelated edits | M | L | Per-phase `git add <specific paths>`; never `-A`; review `git status --short` + `git diff --staged` before each commit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 5, 6 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Session-store source fix (Python) [COMPLETED]

**Goal**: Make the persistence path environment-overridable so the packaged (read-only store) bot
writes session state to a writable location instead of `__file__`-relative `data/`.

**Tasks**:
- [x] In `opencode_discord_bot/src/config.py`: add a `session_store_path: str = ""` field to the
      `Config` dataclass (place near `link_api_token`); document it in the class docstring's
      "Optional variables" block (`SESSION_STORE_PATH - session persistence file path (empty =
      package-relative default)`). *(completed)*
- [x] In `Config.from_env`: read `session_store_path = os.environ.get("SESSION_STORE_PATH", "")`
      and pass `session_store_path=session_store_path` into the final `cls(...)` constructor call. *(completed)*
- [x] In `opencode_discord_bot/src/bot.py` (`DiscordBot.__init__`, the `self.session_store =
      SessionStore()` line): change to `self.session_store = SessionStore(path=config.session_store_path or None)`.
      Confirm `self.config = config` is assigned before this line (it is) so `config` is in scope. *(completed)*
- [x] Leave `store.py`'s `_DEFAULT_STORE_PATH` fallback intact (used when the env var is empty /
      local dev) — the fix is purely additive; `SessionStore(path=None)` preserves current behavior. *(completed — store.py untouched)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `opencode-discord-bot/opencode_discord_bot/src/config.py` - add field + env read + threading into `from_env`
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` - pass `config.session_store_path` into `SessionStore`

**Verification**:
- `python -c "import ast; ast.parse(open('opencode-discord-bot/opencode_discord_bot/src/config.py').read()); ast.parse(open('opencode-discord-bot/opencode_discord_bot/src/bot.py').read())"` (syntax OK)
- `grep -n "session_store_path" opencode-discord-bot/opencode_discord_bot/src/config.py` shows the field, the `from_env` read, and the constructor pass (3 hits)
- `grep -n "SessionStore(path=" opencode-discord-bot/opencode_discord_bot/src/bot.py` shows the threaded call
- Commit: `git add opencode-discord-bot/opencode_discord_bot/src/config.py opencode-discord-bot/opencode_discord_bot/src/bot.py` (specific paths only)

---

### Phase 2: Author pyproject.toml + buildPythonApplication derivation [COMPLETED]

**Goal**: Produce the packaging inputs — a PEP 621 `pyproject.toml` with a console-script entry
point, and a `buildPythonApplication` derivation that builds from the (Phase 1-fixed) source tree.

**Tasks**:
- [x] Create `opencode-discord-bot/pyproject.toml`:
      - `[build-system]` `requires = ["setuptools"]`, `build-backend = "setuptools.build_meta"`
      - `[project]` `name = "opencode-discord-bot"`, `version = "0.1.0"`,
        `requires-python = ">=3.11"`, `dependencies = ["nextcord", "aiohttp"]` (drop `anyio` —
        verified unused)
      - `[project.scripts]` `opencode-discord-bot = "opencode_discord_bot.src.bot:main"`
      - `[tool.setuptools.packages.find]` `where = ["."]`, `include = ["opencode_discord_bot*"]`
        (so `data/`, with only `.gitkeep`, is not treated as a package) *(completed)*
- [x] Create `packages/opencode-discord-bot.nix` in `buildPythonApplication` shape:
      - function args `{ lib, buildPythonApplication, setuptools, nextcord, aiohttp }`
      - `pname = "opencode-discord-bot"; version = "0.1.0"; pyproject = true;`
      - `src = ../opencode-discord-bot;` (relative from `packages/`)
      - `build-system = [ setuptools ];` `dependencies = [ nextcord aiohttp ];`
      - `pythonImportsCheck = [ "opencode_discord_bot" ];`
      - `meta` with `description`, `homepage` (repo), `license = lib.licenses.mit` (or match repo
        convention), `platforms = lib.platforms.linux;` *(completed — also carries the future
        own-repo-extraction note as a header comment, pulling forward part of Phase 6)*
- [x] Do NOT add an entry to `overlays/python-packages.nix` (that overlay is for library overrides
      composed via `python3.withPackages`; this app is `callPackage`d directly in Phase 3).
      *(completed — overlay untouched)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `opencode-discord-bot/pyproject.toml` - new (PEP 621 packaging metadata + console script)
- `packages/opencode-discord-bot.nix` - new (buildPythonApplication derivation)

**Verification**:
- Files exist and are non-empty; `nix-instantiate --parse packages/opencode-discord-bot.nix >/dev/null` (Nix syntax OK)
- `python -c "import tomllib; tomllib.load(open('opencode-discord-bot/pyproject.toml','rb'))"` (TOML parses; entry point present)
- Actual build deferred to Phase 5 (requires the module wiring + staging)
- Commit: `git add opencode-discord-bot/pyproject.toml packages/opencode-discord-bot.nix` (specific paths only)

---

### Phase 3: Wire the module + repoint the systemd unit [NOT STARTED]

**Goal**: Replace the ad-hoc `discordBotPython` env with the packaged app, repoint `ExecStart`,
delete the obsolete `PYTHONPATH`, add the state-directory-backed `SESSION_STORE_PATH`, and fix
the comment typo — all in `modules/system/optional/discord-bot.nix`.

**Tasks**:
- [ ] Re-verify current line locations before editing (drift guard):
      `grep -n "opencode-discord-bot/src/bot.py\|discordBotPython\|PYTHONPATH\|Environment = \[" modules/system/optional/discord-bot.nix`
- [ ] In the `let` block (currently lines 12-16): replace the `discordBotPython = pkgs.python3.withPackages ...`
      binding with `opencodeDiscordBot = pkgs.python3Packages.callPackage ../../../packages/opencode-discord-bot.nix { };`
      Update the accompanying comment (lines 9-11) to describe the packaged application.
- [ ] Fix the comment path typo (line 26): `~/.dotfiles/opencode-discord-bot/src/bot.py` →
      `~/.dotfiles/opencode-discord-bot/opencode_discord_bot/src/bot.py` (add the missing inner
      `opencode_discord_bot/` package directory component).
- [ ] `ExecStart` (line 95): `"${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"` →
      `"${opencodeDiscordBot}/bin/opencode-discord-bot"`.
- [ ] In the `discord-bot` `Environment` list (lines 105-114): DELETE the
      `"PYTHONPATH=...dotfiles/opencode-discord-bot"` entry (line 113) entirely; ADD
      `"SESSION_STORE_PATH=%S/discord-bot/sessions.json"`.
- [ ] In the `discord-bot` `serviceConfig`: add `StateDirectory = "discord-bot";` (systemd creates
      and owns `/var/lib/discord-bot` on first start; `%S` resolves to `/var/lib`).
- [ ] Update the block comment (lines 82-86) that references PYTHONPATH to reflect the packaged
      app + state directory. Leave `opencode-serve` and its shared `WorkingDirectory` untouched
      (`opencode-serve` still needs `.opencode/` in cwd; `discord-bot` no longer relies on cwd for
      imports, but leaving its `WorkingDirectory` as-is is harmless and out of scope).

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `modules/system/optional/discord-bot.nix` - swap binding, repoint ExecStart, drop PYTHONPATH, add SESSION_STORE_PATH + StateDirectory, fix comment typo

**Verification**:
- `grep -n "discordBotPython\|PYTHONPATH" modules/system/optional/discord-bot.nix` returns NOTHING
- `grep -n "opencodeDiscordBot\|SESSION_STORE_PATH\|StateDirectory" modules/system/optional/discord-bot.nix` returns the three additions
- `grep -n "opencode_discord_bot/src/bot.py" modules/system/optional/discord-bot.nix` shows the corrected comment path
- Full build/eval deferred to Phase 5
- Commit: `git add modules/system/optional/discord-bot.nix` (specific path only)

---

### Phase 4: Untrack root opencode.json [COMPLETED]

**Goal**: Restore symmetry with `.claude/`/`.opencode/` treatment — the one tracked file
referencing the gitignored `.opencode/` tree becomes untracked (working copy preserved).

**Tasks**:
- [x] `git rm --cached opencode.json` (removes from index only; file stays on disk and keeps
      working locally). *(completed)*
- [x] Add `/opencode.json` to `.gitignore` immediately after the existing `/.opencode/` line
      (line 37), so it sits alongside `/.claude/` (line 36) and `/.opencode/` (line 37). *(completed)*
- [x] Confirm `config/opencode.json` is NOT touched (`git status` must not list it). *(completed — verified `git ls-files config/opencode.json` still returns it, unstaged)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.gitignore` - add `/opencode.json` line
- `opencode.json` - untracked via `git rm --cached` (working copy unchanged)

**Verification**:
- `git ls-files opencode.json` returns EMPTY (no longer tracked)
- `test -f opencode.json` still passes (working copy preserved)
- `git check-ignore -v opencode.json` shows the new `.gitignore` line matches
- `git ls-files config/opencode.json` still returns `config/opencode.json` (untouched)
- Commit: `git add .gitignore` plus the staged `git rm --cached opencode.json` deletion (specific paths only)

---

### Phase 5: Build + runtime-shape verification (BUILD + RUNTIME) [NOT STARTED]

**Goal**: Prove the behavior change with a successful build and a byte-for-byte `nix eval`
pre/post comparison of `nandi`'s evaluated `discord-bot.serviceConfig`; document the intentional
closure delta and the Outstanding Manual Step.

**Tasks**:
- [ ] STAGE FIRST (flakes only see tracked/staged files): confirm `pyproject.toml`,
      `packages/opencode-discord-bot.nix`, the module, and the Python edits are all `git add`-ed
      (Phases 1-4 commits cover this; re-check with `git status --short` — no relevant file should
      show as untracked `??`).
- [ ] BUILD proof: `nixos-rebuild build --flake .#nandi` (build only, no `sudo`/switch) completes
      successfully — confirms the packaged bot enters `nandi`'s closure and the module evaluates.
      Fallback if a full host build is heavy: `nix build --no-link
      .#nixosConfigurations.nandi.config.systemd.services.discord-bot` is not a valid attr; instead
      build the package indirectly by evaluating `ExecStart` (next task) which forces the derivation.
- [ ] RUNTIME-shape proof (primary automated check), compare against the report's captured
      pre-fix baseline:
      - `nix eval --raw '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.ExecStart'`
        → MUST now resolve to `/nix/store/<hash>-opencode-discord-bot-0.1.0/bin/opencode-discord-bot`
        (pre-fix baseline was `/nix/store/...-python3-3.13.13-env/bin/python -m opencode_discord_bot.src.bot`).
      - `nix eval --json '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.Environment'`
        → MUST NOT contain any `PYTHONPATH=...dotfiles...` entry (pre-fix baseline contained
        `"PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"`), and MUST now contain
        `"SESSION_STORE_PATH=%S/discord-bot/sessions.json"`.
      - `nix eval --raw '.#nixosConfigurations.nandi.config.systemd.services.discord-bot.serviceConfig.StateDirectory'`
        → `discord-bot`.
- [ ] Record the pre/post values in the implementation summary as the behavior-change evidence.
- [ ] Document the intentional closure delta: `nandi`'s system closure now contains
      `opencode-discord-bot-0.1.0` (and no longer the ad-hoc `python3-*-env` built solely for the
      bot's PYTHONPATH import).
- [ ] Write the **Outstanding Manual Step** (human with SSH/sudo to `nandi`): `nixos-rebuild
      switch --flake .#nandi` then `systemctl cat discord-bot.service` + `journalctl -u
      discord-bot.service` to confirm live; and a one-time session-state migration — copy the
      existing `~/.dotfiles/opencode-discord-bot/data/sessions.json` to
      `/var/lib/discord-bot/sessions.json` before/after the first switch (or accept a clean slate;
      low stakes — session→thread links only).

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- None (verification + evidence capture; summary written at task completion)

**Verification**:
- `nixos-rebuild build --flake .#nandi` exits 0
- The three `nix eval` commands above return the post-fix values (store-path binary, no
  `PYTHONPATH`, `SESSION_STORE_PATH` present, `StateDirectory=discord-bot`)
- No commit unless evidence is captured into an artifact; if so, `git add` the specific summary path

---

### Phase 6: Documentation [NOT STARTED]

**Goal**: Keep `packages/README.md` complete and record the deferred own-repo extraction, mirroring
the email-extension precedent.

**Tasks**:
- [ ] Add an `### opencode-discord-bot.nix` section to `packages/README.md` (consistent with the
      existing per-package sections): note it is a `buildPythonApplication` (the first in this repo),
      `callPackage`d directly in `modules/system/optional/discord-bot.nix` (not via
      `overlays/python-packages.nix`), producing the `opencode-discord-bot` console script.
- [ ] Add a short "Future work: own-repo extraction" note (in `docs/discord-bot.md` or a comment
      block in `packages/opencode-discord-bot.nix`) documenting — but NOT implementing — extracting
      `opencode-discord-bot/` into its own repository consumed as a flake input, mirroring how the
      email extension documents its wrapper-binary/own-source precedent. State the current in-tree
      `src = ../opencode-discord-bot;` shape as the deliberate near-term choice.

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `packages/README.md` - new `opencode-discord-bot.nix` section
- `docs/discord-bot.md` (or a header comment in `packages/opencode-discord-bot.nix`) - future-extraction note

**Verification**:
- `grep -n "opencode-discord-bot.nix" packages/README.md` shows the new section
- `grep -rn "own repo\|extraction\|future" docs/discord-bot.md packages/opencode-discord-bot.nix` shows the deferred-work note
- Commit: `git add packages/README.md docs/discord-bot.md` (specific paths only)

## Testing & Validation

- [ ] Python syntax valid for edited `config.py` / `bot.py` (Phase 1)
- [ ] `pyproject.toml` parses; console-script entry `opencode_discord_bot.src.bot:main` present (Phase 2)
- [ ] `nix-instantiate --parse packages/opencode-discord-bot.nix` succeeds (Phase 2)
- [ ] Module no longer references `discordBotPython`/`PYTHONPATH`; contains `opencodeDiscordBot`,
      `SESSION_STORE_PATH`, `StateDirectory` (Phase 3)
- [ ] Comment typo corrected to `opencode_discord_bot/src/bot.py` (Phase 3)
- [ ] `git ls-files opencode.json` empty; working copy preserved; `config/opencode.json` untouched (Phase 4)
- [ ] `nixos-rebuild build --flake .#nandi` exits 0 (Phase 5, BUILD)
- [ ] `nix eval` shows store-path `ExecStart`, no `PYTHONPATH`, `SESSION_STORE_PATH` +
      `StateDirectory` present (Phase 5, RUNTIME)
- [ ] `packages/README.md` + future-extraction note present (Phase 6)

## Artifacts & Outputs

- `opencode-discord-bot/pyproject.toml` (new)
- `packages/opencode-discord-bot.nix` (new)
- Edited: `opencode-discord-bot/opencode_discord_bot/src/config.py`, `.../bot.py`,
  `modules/system/optional/discord-bot.nix`, `.gitignore`, `packages/README.md`, `docs/discord-bot.md`
- Untracked: root `opencode.json` (`git rm --cached`)
- `specs/089_opencode_discord_bot_packaging/summaries/02_package-via-buildpythonapplication-summary.md`
  (with the captured `nix eval` pre/post evidence + Outstanding Manual Step)

## Rollback/Contingency

- All changes are additive/localized and committed per-phase; revert any single phase's commit to
  roll back that phase independently.
- If the Phase 5 build/eval fails: fix forward (correct source per `error-handling.md`); do not
  discard uncommitted work. The pre-fix `discordBotPython`/PYTHONPATH wiring is recoverable from
  git history if a full revert of Phase 3 is needed.
- Untracking `opencode.json` (Phase 4) is fully reversible: `git add opencode.json` re-tracks it
  and remove the `.gitignore` line.
- Session-state: if the `StateDirectory` migration is undesirable, the same-effort fallback is to
  set `SESSION_STORE_PATH` to the existing `~/.dotfiles/opencode-discord-bot/data/sessions.json`
  literal (keeps state under `$HOME`, no migration) — noted but not recommended.

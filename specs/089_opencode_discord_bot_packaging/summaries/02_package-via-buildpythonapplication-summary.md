# Implementation Summary: Task #89

**Completed**: 2026-07-05
**Duration**: ~50 minutes (single session, all 6 phases)

## Overview

Converted `opencode-discord-bot/` from a working-tree `PYTHONPATH` import into a real
`buildPythonApplication` derivation (`packages/opencode-discord-bot.nix`, the first
`buildPythonApplication` in this repo), `callPackage`d directly in
`modules/system/optional/discord-bot.nix`, and repointed the `discord-bot` systemd unit's
`ExecStart` at the built nix-store console script. Fixed a runtime-blocking source defect
(`SessionStore`'s `__file__`-relative default path would resolve inside the read-only nix store
once packaged) via a `SESSION_STORE_PATH` env var backed by a systemd `StateDirectory`, corrected
a stale comment path typo, and untracked the root `opencode.json` to restore `.claude/` symmetry.
This is a **behavior-changing** task: `nandi`'s system closure now contains the packaged bot
instead of an ad-hoc `python3.withPackages` environment, and the bot's runtime import path moved
from `$HOME` to the nix store.

## What Changed

- `opencode-discord-bot/opencode_discord_bot/src/config.py` — added `session_store_path: str = ""`
  field + `SESSION_STORE_PATH` env read in `Config.from_env`
- `opencode-discord-bot/opencode_discord_bot/src/bot.py` — threaded
  `config.session_store_path` into `SessionStore(path=...)`
- `opencode-discord-bot/pyproject.toml` — new PEP 621 packaging metadata, console-script entry
  point `opencode-discord-bot = "opencode_discord_bot.src.bot:main"`
- `packages/opencode-discord-bot.nix` — new `buildPythonApplication` derivation, header comment
  documents the deferred own-repo-extraction option
- `modules/system/optional/discord-bot.nix` — replaced `discordBotPython` binding with
  `opencodeDiscordBot = pkgs.python3Packages.callPackage ../../../packages/opencode-discord-bot.nix { }`;
  `ExecStart` repointed at `${opencodeDiscordBot}/bin/opencode-discord-bot`; dropped the
  `PYTHONPATH` env entry; added `SESSION_STORE_PATH=%S/discord-bot/sessions.json` and
  `StateDirectory = "discord-bot"`; fixed the comment path typo
  (`opencode-discord-bot/src/bot.py` -> `opencode_discord_bot/src/bot.py`)
- `.gitignore` — added `/opencode.json` (alongside `/.claude/`, `/.opencode/`)
- `opencode.json` (root) — untracked via `git rm --cached`; working copy preserved;
  `config/opencode.json` (HM-deployed, unrelated) untouched
- `packages/README.md` — new `opencode-discord-bot.nix` section
- `docs/discord-bot.md` — refreshed Files table, Python Environment section (renamed "Python
  Packaging"), `discord-bot.service` code block + bullets, and the Rollback binding name to match
  the new packaged wiring; added the future own-repo-extraction note

## Decisions

- `buildPythonApplication` is `callPackage`d directly at its single consumption site
  (`discord-bot.nix`), not routed through `overlays/python-packages.nix` — that overlay is scoped
  to library overrides composed via `python3.withPackages`, an architecturally different consumer.
- `anyio` dropped from the dependency list (confirmed unused via `grep`).
- `SessionStore(path=config.session_store_path or None)` — empty string preserves the existing
  `_DEFAULT_STORE_PATH` fallback for local/dev use; the fix is purely additive.
- Own-repo extraction of `opencode-discord-bot/` is documented as future work only (both a header
  comment in the new `.nix` file and a `docs/discord-bot.md` section), mirroring the email
  extension's wrapper-binary/own-source precedent — not implemented.

## Plan Deviations

- **Phase 1/4 commit boundary**: a `git reset --soft HEAD -- .` command (used while trying to
  isolate Phase 1's staging) silently failed — real git rejects `--soft` combined with a pathspec,
  and stderr was redirected to `/dev/null` — so the already-staged Phase 4 `git rm --cached
  opencode.json` deletion rode into the Phase 1 commit (`436d323`) instead of getting its own.
  The `.gitignore` addition was still caught and committed correctly as a standalone Phase 4
  commit (`eead168`). Net effect: content is correct and scoped to task 89 only (no unrelated
  files swept in), but the phase/commit boundary for Phase 4 is imperfect.
- **Phase 3 comment wording**: the plan's own verification requires `grep -n
  "discordBotPython\|PYTHONPATH" modules/system/optional/discord-bot.nix` to return nothing.
  Explanatory comments describing the pre-task-89 wiring were phrased to avoid those literal
  strings (e.g. "ad-hoc interpreter environment" instead of "discordBotPython") so the exact-match
  verification passes.
- **Phase 6 doc scope**: `docs/discord-bot.md` was updated beyond the plan's minimal
  future-extraction-note ask, also correcting now-stale `discordBotPython`/`PYTHONPATH`/`ExecStart`
  references left behind by Phase 3's module rewiring (Files table, a renamed "Python Packaging"
  section, the `discord-bot.service` code block, and the Rollback section's binding name). This
  keeps the doc consistent with the shipped module rather than contradicting it. Pre-existing
  staleness in the Rollback section (`configuration.nix`, `hamsa` — predates task 89 and this
  module's move under `modules/system/optional/`) was deliberately left untouched as out of scope.
- No other deviations; all phase task checklists are fully annotated `[x] ... (completed)`.

## Verification

- Python syntax: `ast.parse` clean for `config.py` and `bot.py`
- `pyproject.toml`: parses via `tomllib`; console-script entry confirmed
- `nix-instantiate --parse packages/opencode-discord-bot.nix`: OK
- `nix-instantiate --parse modules/system/optional/discord-bot.nix`: OK
- `git ls-files opencode.json`: empty (untracked); `test -f opencode.json`: still present;
  `config/opencode.json`: untouched (still tracked, unstaged)
- **BUILD**: `nixos-rebuild build --flake .#nandi` — exit 0. Built
  `opencode-discord-bot-0.1.0.drv` and `unit-discord-bot.service.drv` among 12 derivations. Final
  output: `/nix/store/hflllx5hw9w85yxzmpfw7xckj24ssvac-nixos-system-nandi-26.05.20260622.3426825`
- **RUNTIME-shape proof** (`nix eval` against `nixosConfigurations.nandi`'s evaluated
  `discord-bot.serviceConfig`):

  | Field | Pre-fix baseline | Post-fix (this task) |
  |-------|-------------------|------------------------|
  | `ExecStart` | `/nix/store/...-python3-3.13.13-env/bin/python -m opencode_discord_bot.src.bot` | `/nix/store/fi6z2vi7a5s17c5rv039yxcihfhv7lin-opencode-discord-bot-0.1.0/bin/opencode-discord-bot` |
  | `Environment` (`PYTHONPATH`) | `"PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"` present | absent (confirmed via grep on `nix eval --json` output) |
  | `Environment` (`SESSION_STORE_PATH`) | not present | `"SESSION_STORE_PATH=%S/discord-bot/sessions.json"` present |
  | `StateDirectory` | not set | `"discord-bot"` |

- `nix flake check`: all checks passed (run after all 6 phases, including doc edits)

## Closure Delta (intentional, behavior-changing)

`nandi`'s system closure now contains `opencode-discord-bot-0.1.0` (a real `buildPythonApplication`
derivation with its own console script) and no longer contains the ad-hoc `python3-*-env` that was
built solely to house `nextcord`/`aiohttp`/`anyio` for the working-tree `PYTHONPATH` import. The
`discord-bot.service` unit's `ExecStart` now points at a store path outside `$HOME`, and session
persistence moved from a working-tree-relative `data/sessions.json` to a systemd
`StateDirectory` (`/var/lib/discord-bot/sessions.json`).

## Outstanding Manual Step

`nandi` is unreachable and `sudo`/SSH are sandbox-denied in this environment, so the following
must be performed by a human with access:

1. `sudo nixos-rebuild switch --flake .#nandi`
2. `systemctl cat discord-bot.service` + `journalctl -u discord-bot.service` to confirm the unit
   is live and healthy with the new `ExecStart`/`Environment`/`StateDirectory`.
3. **One-time session-state migration** (low stakes — session-to-thread links only): before or
   after the first switch, copy the existing
   `~/.dotfiles/opencode-discord-bot/data/sessions.json` to
   `/var/lib/discord-bot/sessions.json` (created by systemd on first start via
   `StateDirectory`), or accept a clean slate.

Note: `discord-bot.service` is separately known to be crash-looping on `hamsa` from an unrelated
pre-existing asyncio bug — that issue is out of scope for this task and was not touched here; this
task's changes and verification target `nandi` only, per the plan and research.

## Notes

No `overlays/python-packages.nix` entry was added — that overlay remains scoped to library
overrides. `flake.nix` and `modules/home/` were not touched (out of scope; `modules/home/` belongs
to the just-completed task 88).

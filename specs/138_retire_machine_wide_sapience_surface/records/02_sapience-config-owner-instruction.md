# Owner Instruction: Reconcile `~/.sapience/config.json` to the Four-Repository Set

This surface is outside every repository's tree, mode 600, and its payload self-updates daily —
it is owner-only state and is never edited by an agent. This record hands over an exact,
runnable instruction instead of performing the edit.

## Pre-instruction re-read (confirms the plan's assumption still holds)

Read on 2026-11-13 at implementation time:

- Top-level `folders`: 5 entries — `-home-benjamin--config-nvim`, `-home-benjamin--dotfiles`,
  `-home-benjamin-Philosophy-Papers-PossibleWorlds`, `-home-benjamin-Projects-BimodalLogic`,
  `-home-benjamin-Projects-Logos-Verification`.
- `capture.mode`: `"opt-in"`.
- `capture.projects`: 10 entries, 5 `enabled: true` — `/home/benjamin/Projects/BimodalLogic`,
  `/home/benjamin/.dotfiles`, `/home/benjamin/Philosophy/Papers/PossibleWorlds`,
  `/home/benjamin/.config/nvim`, `/home/benjamin/Projects/Logos/Verification` — and 5
  `enabled: false`.
- Neither `abood` nor `sapience-app` appears anywhere in the file.
- `token` field present (16 characters; never printed). File mode 600.

This matches what the plan assumed. The instruction below is generated against this exact shape.

## Route determination

`sapience projects` (this repository's wrapper around the vendor's own interactive flow,
`extract_local.py --projects`) is the sanctioned route for the `capture.projects` half: it is the
vendor's own supported mechanism for toggling which projects sync and require review. The
interactive folder picker that runs first in a `sapience-bootstrap` or extraction run owns the
top-level `folders` half the same way.

Neither route can express the full target in one pass, however. The picker only lists transcript
directories that already exist under `~/.claude/projects/` — and
`-home-benjamin-Projects-Sapience-sapience-app` does not exist yet; it is created the first time
a Claude Code session runs from the moved `/home/benjamin/Projects/Sapience/sapience-app`
checkout. So the sanctioned route for THIS reconciliation, in one pass, covering both keys
together, is a guarded `jq` hand-edit — the one below. It is a one-time correction for the
`abood`/moved-checkout gap the interactive tools cannot yet reach; `sapience projects` and the
folder picker remain the sanctioned ongoing routes for all future changes.

**Caveat**: a later `sapience-bootstrap` or interactive extraction run's folder picker persists
its own selection over `folders`. Re-check `folders` after any such run and re-apply the relevant
part of this instruction if it has drifted from the four-repository set.

## The instruction

Run this as the owner (never as an agent), from any shell:

```bash
set -euo pipefail
cfg="$HOME/.sapience/config.json"
tmp="$(mktemp "${cfg}.XXXXXX")"

jq '
  .capture.projects = (
    [ .capture.projects[]
      | if (.path_prefix == "/home/benjamin/Projects/BimodalLogic"
            or .path_prefix == "/home/benjamin/Philosophy/Papers/PossibleWorlds"
            or .path_prefix == "/home/benjamin/Projects/Logos/Verification")
        then .enabled = false
        else . end
    ]
    + [
      {path_prefix: "/home/benjamin/Projects/abood", name: "abood", target: "personal", enabled: true},
      {path_prefix: "/home/benjamin/Projects/Sapience/sapience-app", name: "sapience-app", target: "personal", enabled: true}
    ]
  )
  | .folders = [
      "-home-benjamin--config-nvim",
      "-home-benjamin--dotfiles",
      "-home-benjamin-Projects-abood",
      "-home-benjamin-Projects-Sapience-sapience-app"
    ]
' "$cfg" > "$tmp" && mv "$tmp" "$cfg" && chmod 600 "$cfg"
```

This:
- preserves `token` and every other top-level key (only `capture.projects` and `folders` are
  touched);
- sets `enabled: false` on `/home/benjamin/Projects/BimodalLogic`,
  `/home/benjamin/Philosophy/Papers/PossibleWorlds` and `/home/benjamin/Projects/Logos/Verification`
  (their entries are kept, not deleted — matching the existing ten-entry convention of listing
  disabled candidates rather than removing them);
- adds `/home/benjamin/Projects/abood` and `/home/benjamin/Projects/Sapience/sapience-app` as new
  `enabled: true` entries, `target: "personal"`, in the existing
  `{path_prefix, name, target, enabled}` shape;
- replaces the top-level `folders` array with exactly the four loaded repositories' transcript
  keys;
- operates on a temp file and moves it into place atomically (`mv` is atomic on the same
  filesystem), and restores mode 600 explicitly afterward, since `jq`'s stdout redirection does
  not preserve the source file's mode.

**Do not use** the stale pre-move key `-home-benjamin-Projects-sapience-app` (no `Sapience/`
segment) anywhere — it names a different, no-longer-checked-out directory, not the moved one.

## Verification the owner can run afterwards

```bash
jq -r '.folders' "$HOME/.sapience/config.json"
# Expect exactly: -home-benjamin--config-nvim, -home-benjamin--dotfiles,
#                 -home-benjamin-Projects-abood, -home-benjamin-Projects-Sapience-sapience-app

jq -r '.capture.projects[] | select(.enabled==true) | .path_prefix' "$HOME/.sapience/config.json" | sort
# Expect exactly: /home/benjamin/.config/nvim, /home/benjamin/.dotfiles,
#                 /home/benjamin/Projects/Sapience/sapience-app, /home/benjamin/Projects/abood

jq -r '.token | length' "$HOME/.sapience/config.json"
# Expect the same length as before (16) -- confirms the token field survived untouched
# (never print the token value itself).

stat -c '%a' "$HOME/.sapience/config.json"
# Expect: 600
```

## Rehearsal performed by this task (never against the live file)

The exact recipe above was rehearsed against a copy of the live file placed under this session's
scratchpad directory (never under `~/.sapience/` and never the live file itself). The rehearsal
copy, after the recipe ran, showed `folders` with exactly the 4 target keys, `capture.projects`
with exactly 4 `enabled: true` entries matching the loaded set (`.config/nvim`, `.dotfiles`,
`abood`, `Sapience/sapience-app`), 12 total `capture.projects` entries (10 original + 2 new), the
original token length (16) preserved, and mode 600. The live file's own
`jq -S . ~/.sapience/config.json | sha256sum` digest and mtime were read before and after the
rehearsal and are identical, confirming the live file was never touched by this task.

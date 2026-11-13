# Install for the 11-12 jam (about 5 minutes per person)

Nothing below was applied tonight. No settings file was changed.

## 1. Get the guard onto each machine
- Oliver: it is at /Users/oz/data/oliver-ben-guard/ already.
- Ben: he needs a copy of guard.py, install.sh and README.md. It is stdlib Python 3 with no dependencies.
  Sending it is a send, so Oliver decides how (for example, drop it on the jam branch in the room).

## 2. Per checkout of coretxinc/sapience-app (each person, in their own worktree)
    sh /path/to/oliver-ben-guard/install.sh <checkout> <oliver|ben> <source>
This writes only `.git/hooks/pre-commit` and `.git/oliver-ben-guard/config.json`, never a tracked file. It refuses
to overwrite an existing pre-commit hook and prints the line to add instead. It ends by printing `guard.py status`:
read it, and check that the rules shown are the room's rules.

## 3. Claude Code hook (Claude Code CLI, both people)
Put this in `<checkout>/.claude/settings.local.json`. Claude Code keeps that file out of git, so the machine path
never lands in a PR. `.claude/settings.json` works the same way, but it is a tracked path, so don't commit it.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash",
        "hooks": [
          { "type": "command", "command": "python3 /ABSOLUTE/PATH/oliver-ben-guard/guard.py hook", "timeout": 30 }
        ]
      }
    ]
  }
}
```
Restart Claude Code in that checkout, then run `/hooks` and check the entry is listed.
Smoke test: ask Claude to write `logos-internal` into a scratch file. It should be blocked with a KO hash. Then
delete the file.

## 4. Ben's setup (Neovim + Claude)
- **Claude Code CLI in a terminal or an nvim terminal split:** steps 2 and 3 apply as written. The hook belongs
  to Claude Code, not the editor.
- **An nvim plugin that calls the API directly (no Claude Code), or edits typed by hand in nvim:** there is no
  PreToolUse point, so step 3 does nothing. The pre-commit hook from step 2 is the guard there: it checks every
  commit, whoever or whatever made the edit. Ownership and banned strings then bind at commit time, not at edit
  time. Say so in the room so the two of you know the gap.
- Ask Ben at 0:00 which of the two it is: `which claude` plus the plugin name.

## 5. Each card
    python3 guard.py card C-<n>      # in the checkout, when you pick up a card: forces a fresh rule read
    python3 guard.py status          # what is in force, what is superseded, revision, cache age

## The rule source: the one thing still missing
- The guard reads the oliver-ben KOs through `source` in config.json. Tonight's real reads:
  - `GET /v1/projects` (Oliver's token): 200 in 1.7 s. `oliver-ben` exists with **0 KOs and 5 docs**, so there are no
    rule KOs to read yet. The morning seed creates them.
  - `GET /clusters.json`, the only route found that returns a project's KO rows: **client timeout at 20 s**, and per
    the stop rule no further read was made. It is also owner-only (company surfaces), so Ben's token could never
    use it.
- **Needed from APP, before the jam or at 0:00:** a small read route, for example
  `GET /v1/projects/<slug>/rules` -> `{"kos": [{hash, subject, predicate, object, provenance, type, updated_at,
  invalid_at}]}`, member-readable, read from sqlite like `_project_tag_rows`, not from the engine. guard.py already
  takes `source: "hosted-rules:<url>"`. It stops on the first 503/504/429/timeout, makes no retry, and keeps at
  least 10 s between reads.
- **Fallback if that route doesn't exist by 9:00:** keep the rules in one JSON file that both people point at
  (`source: "fixture:<path>"`, format as fixtures/oliver-ben-seed.example.json). Whoever writes a rule KO in the
  room also adds it to the file. Then it binds deterministically, but the store isn't the source of truth, and
  that must be said in the scorecard.
- Either way, the seed must carry `SUPERSEDES 78bf4d93` on the 8c116781 line (see the report). The real 8c116781
  only names e809b86a.

# Phase A (2026-11-12): attached mode, fail closed

    sh install.sh <checkout> <oliver|ben> hub-rules:/Users/oz/data/oliver-ben-guard/hub-rules-oliver-ben.json attached \
       local-events:/Users/oz/data/oliver-ben-guard/hub-events-local.json

Both sources above are LOCAL stand-ins until APP ships GET /v1/projects/<slug>/rules and POST /v1/rooms/<id>/events
(spec: /Users/oz/data/sf1-reports/sf1-hub-phase-a-app-routes-spec-1112.md). Then switch to
`hub-route:<url>` and `hosted-events:<url>` with `key_file` in config.json.

`.claude/settings.local.json` (restart Claude Code afterwards):
- PreToolUse, matcher `Edit|Write|MultiEdit|NotebookEdit|Bash`:
  `/opt/homebrew/bin/python3 /Users/oz/data/oliver-ben-guard/guard.py hook --attached || exit 2`
- PostToolUse, same matcher: `/opt/homebrew/bin/python3 /Users/oz/data/oliver-ben-guard/guard.py posthook --attached`

Why `|| exit 2`: Claude Code 2.1.322 runs the tool when a hook exits 1 or times out (tests/g1_results.json, G1a, G1c).

Human-only commands (an agent's attempt is blocked while suspended, and always once `RULE guard-protect` is ruled):
`guard.py unstop` (after a suspension), `guard.py detach`, `guard.py send --reset` (after the sender breaker trips).
Tests: `python3 tests/run_hub_tests.py` (39 rows), `python3 tests/g1_claude_hooks.py` (6 headless runs, ~$0.02).

# Writing rules in the room (Oliver + Ben, one page)

The guard reads the `oliver-ben` project's **constraint** and **decision** KOs before every edit and every
`git commit` / `git push`. A line that starts with `RULE` is enforced by code, the same way every time. Anything
else in a constraint or decision is shown to you as "check in the room" and never blocks.

## The five rules

| Write this line in the KO | What happens |
|---|---|
| `RULE owner: src/app/live/** = oliver` | Ben's edits and commits to those files are blocked. Oliver's pass. |
| `RULE owner: src/app/live/chat.tsx = ben` | A newer owner rule wins: this hands one file to Ben (a handoff). |
| `RULE ban-string: logos-internal` | Any added text containing it (any case) is blocked. |
| `RULE ban-path: .env*` | Writing or committing a matching file is blocked. |
| `RULE no-git: ben` | `git commit` / `git push` by that person is blocked. |

Also: `RULE ban-regex: <pattern>` (a Python regex), and `owner: <glob> = oliver,ben` for shared files.

## Changing or retiring a rule

Write a NEW KO that says what replaces what, and add a line:

    SUPERSEDES 78bf4d93

The old KO stays visible to both of you ("superseded, not enforced", with its author). Two KOs with the same
subject and predicate also count as newest-wins, so give each rule its own subject, e.g.
`oliver-ben rule: live owner`.

## When it takes effect

- At once, on the next action, when the person picks up a new card (`guard.py card C-3`).
- Otherwise within 10 minutes (the cache). Measured: 3.1 s on a 3 s cache; 0 actions after a card change.
- If you need it to bind right now, say "new card" in the room and the other side runs `guard.py card <id>`
  (or `guard.py refresh`).

## Globs

- No `/` in the pattern: matches the file name anywhere (`.env*` catches `config/.env.local`).
- With a `/`: from the repo root. `**` crosses folders, `*` stays inside one folder.

## When it blocks you

The message names the rule's KO hash and author. If the rule is wrong, fix it in the room with a newer KO.
Don't work around it. The pre-commit hook checks again at commit time, and `--no-verify` skips it, so only
use that if you've both agreed in the room.

## Write rules like this

- One `RULE` per line, and the reason in plain words above it: "Nothing from Logos goes in the project."
  then `RULE ban-string: logos-internal`.
- Pick strings that can't turn up in normal code. `logos` alone would block the word in comments.
- A rule the code can't check, like "founding terms never go in the project", stays as prose. The guard shows
  it at every commit and on each refresh, and it's up to you two to hold it.

# Research Report: Sapience Hooks Opt-Out Default

**Task**: Default `~/.sapience/config.json` `"hooks"` to `false` in
`modules/home/services/sapience.nix` and preserve an explicit `false` across activation.
**Started**: 2026-11-17
**Completed**: 2026-11-17
**Effort**: Small (two jq-expression edits, one new activation check, two doc updates)
**Dependencies**: None
**Sources/Inputs**: `modules/home/services/sapience.nix`, `modules/home/core/dotfiles.nix`,
`docs/sapience.md`, `~/.sapience/sapience_upkeep.py`, `~/.sapience/mcp.py`,
`~/.sapience/sapience_cli.py`, `~/.sapience/config.json`, `~/.claude/settings.json`,
`~/.dotfiles/.claude/scripts/verify-sapience-mcp.sh` (read for scoping only, out of territory)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The bug is entirely local to `modules/home/services/sapience.nix`: two jq expressions use
  `//`, whose "default on falsy" semantics treat an explicit `false` the same as absent/`null`,
  so a `"hooks": false` opt-out is silently reset to `true` the next time either site runs.
- The vendor's own gate (`hooks_opted_out()` in `~/.sapience/sapience_upkeep.py`) already does
  the right thing (`.get('hooks') is False`, an explicit identity check) — the vendor is not the
  bug; this repo's own jq is.
- `"hooks": false` is confirmed, by direct reading of `mcp.py` and `sapience_cli.py`, to gate
  only two things: the daily/forced updater's `wire_hooks()` write into
  `~/.claude/settings.json`, and the CLI auto-on probe (`cli_auto_on_plan`). It does **not** gate
  `mcp.py --briefing-text/--receipt/--effect-line` or `sapience_cli.py`'s `hook()` dispatcher
  themselves — those run unconditionally whenever something invokes them, which is exactly what
  the sapience extension's own per-repository `settings-fragment.json` hooks do. GOAL item (2)
  is confirmed, not merely assumed.
- Recommended fix: replace `//` with an explicit `.hooks == null` test at both jq sites, and
  default (not force) to `false`. This is a **default**, not a **force** — an explicit value the
  user (or a future toggle) sets is preserved; only an absent key is defaulted to `false`. This
  matches the task's own title ("default ... to false") and its "preserve an explicit false"
  requirement, and mirrors the existing `.auto_approve = (.auto_approve // false)` sibling
  expression's intent (fixed to actually honor an explicit `false`).
- A new, narrowly-scoped home-manager activation check (new territory, not an edit to the
  extension's own `verify-sapience-mcp.sh`, which is out of this task's scope — see Territory
  note below) can detect and loudly flag a reappeared vendor hook in `~/.claude/settings.json`
  between switches.

## Context & Scope

### Territory boundary (read before implementing)

This repository's `.claude/` tree is itself a deploy artifact (see
`.claude-extensions.json`'s `sapience` entry, `source_dir:
/home/benjamin/.config/nvim/agent-system/extensions/sapience`). The dispatch's own text names a
companion task, `sapience_activation_surface_scoping_gaps` (task 636 in the nvim repository), as
owning "the extension-side verifier/doc task." Confirmed: the nvim repo's
`agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` (mirrored here at
`.claude/scripts/verify-sapience-mcp.sh`) checks per-project MCP registration and the merged
`settings.local.json` permission/hook fragment — a completely different surface from the
machine-wide `~/.claude/settings.json` vendor-hook-injection this task is about. **Nothing in
this task touches `.claude/**` or the extension source store.** The fix, the new verification
check, and the doc updates all belong under `modules/`, `docs/sapience.md`, and (if a
dedicated check script is added) a new script tracked directly in this repository — never under
`.claude/`.

### What was researched

1. The exact jq sites in `sapience.nix` that write the `config.json` `"hooks"` field, and why
   `//` is the wrong operator there.
2. Whether `"hooks": false` in `config.json` is sufficient to stop every machine-wide Claude Code
   hook injection path the vendor client carries, or only some of them — read directly from the
   vendor's own `~/.sapience/*.py` files rather than assumed from the dispatch's prose.
3. Where an activation-time or verification check belongs, and what signature it should look
   for.
4. What `docs/sapience.md` already says about the hook story, to scope the doc update precisely
   rather than duplicating prose.

## Findings

### 1. The two write sites, exact text, and the fix

Both sites are in `sapienceBootstrap` (the user-invoked CLI, `pkgs.writeShellScriptBin
"sapience-bootstrap"`), not in a `home.activation` block — the dispatch's "activation merge"
phrasing refers to this script's own config-mutation logic, which is the only place in this repo
that writes the `"hooks"` key into `config.json`.

**Site A — re-bootstrap merge (existing `config.json`), `modules/home/services/sapience.nix`
line 319-325:**

```nix
${pkgs.jq}/bin/jq \
  --arg token "$TOKEN" \
  --arg backend "${cfg.backend}" \
  --arg host "${cfg.host}" \
  '.token = $token | .backend = $backend | .host = $host
   | .auto_approve = (.auto_approve // false) | .hooks = (.hooks // true)' \
  "${configFile}" > "$tmp"
```

`.hooks = (.hooks // true)`: jq's `//` returns the right-hand side whenever the left is `false`
**or** `null` — not only when absent. So an explicit `"hooks": false` (exactly the value the
2026-11-14 manual fix wrote) is indistinguishable from "never set" and is reset to `true` on the
next run of this script. This is the measured bug.

**Site B — first-run mint (no existing `config.json`), line 327-332:**

```nix
${pkgs.jq}/bin/jq -n \
  --arg token "$TOKEN" \
  --arg backend "${cfg.backend}" \
  --arg host "${cfg.host}" \
  '{token: $token, backend: $backend, host: $host, auto_approve: false, hooks: true}' \
  > "$tmp"
```

A flat object literal with `hooks: true` baked in — no merge semantics needed here, just a
literal that should read `false`.

**Recommended fix (default, not force — see Decision 1 below):**

Site A: `| .hooks = (if .hooks == null then false else .hooks end)'`
Site B: `'{token: $token, backend: $backend, host: $host, auto_approve: false, hooks: false}'`

Note the sibling `.auto_approve = (.auto_approve // false)` expression carries the exact same
latent defect in principle (an explicit `auto_approve: true` is fine, but an explicit `false`
and "absent" both already collapse to the same default, so the bug is invisible for that field
today only because default and desired-preserved-value happen to coincide). It is **out of
scope** for this task (the dispatch names only `hooks`), but worth a one-line comment at the fix
site so a future reader does not wonder why one sibling field uses `//` and the other does not.

### 2. GOAL item (2), confirmed from vendor source, not assumed

Read directly in `~/.sapience/sapience_upkeep.py`, `~/.sapience/mcp.py`, and
`~/.sapience/sapience_cli.py` on this machine (the live, currently-deployed vendor payload):

- `hooks_opted_out(dest)` (`sapience_upkeep.py:72-73`) is `SAPIENCE_NO_HOOKS == '1' or
  _cfg(dest).get('hooks') is False` — an explicit identity check against `False`, not a truthy
  check. The vendor's own gate already does the right thing; it is this repo's write path that
  breaks the contract.
- It is consulted at exactly two call sites:
  - `update(...)` (`sapience_upkeep.py:~324-327`): `if hooks_opted_out(dest): out('left
    alone...')  else: wire_hooks(...)`. This is reached both by `sapience update` /
    `sapience_upkeep.py --update` (direct, unconditional) and by `auto_update(...)` (the daily
    background pass, gated separately by `auto_update_allowed()` and a once-a-day mark file).
  - `cli_auto_on_plan(...)` (`sapience_upkeep.py:~369-377`): returns `''` (no action) when
    `hooks_opted_out(dest)` is true, which is what stops the daily auto-update from silently
    switching on `sapience_cli.py`'s own Claude Code hooks for a hosted install that never had
    them.
- It is **not** consulted anywhere else. In particular:
  - `mcp.py`'s `--briefing-text` / `--receipt` / `--effect-line` entry points (`mcp.py:1953,
    1960, 1970`) gate only on `TOKEN` presence (and, for `--effect-line`, on there being
    something to report) — never on `config.json`'s `"hooks"` field.
  - `sapience_cli.py`'s `hook(event, raw)` / `answer(...)` dispatcher (`sapience_cli.py:745-782`)
    gates only on `folder_allowed(cwd)` and per-session state — never on `"hooks"`.

**Conclusion**: `"hooks": false` stops exactly two things — the updater's write into
`~/.claude/settings.json`, and the CLI auto-on probe. It has no effect on, and must not be
expected to affect, whatever directly invokes `mcp.py --briefing-text/--receipt/--effect-line`
or `sapience_cli.py hook prompt/tool` from a repository's own merged `settings.local.json` (the
sapience extension's `settings-fragment.json`, in the nvim repository, outside this task's
territory) — those calls carry no dependency on `config.json`'s `"hooks"` key at all. GOAL item
(2) is satisfied by the current design once the jq fix lands; no vendor-side or extension-side
change is implicated.

### 3. Where the new verification check belongs, and what it should look for

`home.activation` entries are a single flat merged namespace across every home-manager module
file — `sapience.nix` already orders its own entries relative to `dotfiles.nix`'s `claudeSettings`
is not referenced today, but the pattern (`config.lib.dag.entryAfter [ "writeBoundary"
"sapiencePayload" ]` inside `sapienceTokenRepair`) demonstrates that cross-file ordering by name
works. A new entry (e.g. `sapienceHooksGuard`) can be declared in `sapience.nix` itself, ordered
`entryAfter [ "writeBoundary" "claudeSettings" ]` so it inspects `~/.claude/settings.json`
**after** `dotfiles.nix`'s own enforced-key merge has run for this activation.

**Live baseline measured on this machine** (`~/.claude/settings.json` today): `hooks.SessionStart`
carries exactly three entries (an inhibitor, `lean-lsp-register-project.sh`,
`sapience-mcp-register-project.sh`), `hooks.SessionEnd` carries the inhibitor cleanup, and
`hooks.Stop` is `[]`. None reference `.sapience/mcp.py`. The vendor's injection signature is
unambiguous and distinct from the legitimate, durable `sapience-mcp-register-project.sh` entry:
a command string containing `.sapience/mcp.py` together with one of `--briefing-text`,
`--receipt`, or `--effect-line`. A check can `jq` over `hooks.SessionStart`, `hooks.SessionEnd`,
and `hooks.Stop`'s flattened command strings for that pattern and treat any match as a loud
failure — it can never fire on the legitimate registration hook, which invokes a different
script with no such flags.

**Decision needed in planning, not settled here**: whether "fails loudly" means a hard abort
(`exit 1` from the activation script, blocking `home-manager switch` until fixed by hand) or a
loud non-blocking message (printed warning, switch proceeds). The existing `claudeSettings`
activation entry in `dotfiles.nix` is deliberately fail-safe for *external* conditions (missing
file, bad JSON, jq error) because those can arise from a transient or pre-existing state this
repo does not control. A reappeared vendor hook is different in kind: it is exactly the
self-inflicted condition this whole task exists to prevent, and "fails loudly" in the GOAL text
reads as intentionally stronger language than the warning-only pattern used elsewhere in this
module (the `backend == "ollama"` / `apiKeyFile == ""` `warnings` list, which is build-time only
and cannot see live file content in any case — those are evaluated from `config`, not
activation). A hard-abort activation check is recommended: this condition should never occur
once the jq fix lands and `hooks_opted_out()` honors it, so a switch-blocking failure has no
plausible false-positive, and surfacing it immediately (at the next `home-manager switch`) beats
discovering it only via manual inspection of `~/.claude/settings.json`.

### 4. Doc update scope

`docs/sapience.md`'s "Why the hooks live in the repo" section (lines 645-674) documents the
**existing** two-layer story precisely: the per-repository hooks live in the extension's
`settings-fragment.json`, and the one durable machine-wide entry
(`sapience-mcp-register-project.sh`) is intentional. It does not currently mention
`config.json`'s `"hooks"` opt-out at all — that field, and the vendor updater's own write path
into `~/.claude/settings.json`, are absent from the doc entirely. The doc update for this task
is additive to that section (or a new subsection immediately after it): state that
`~/.sapience/config.json`'s `"hooks": false` is a second, independent guard — it stops the
vendor's *own* updater from ever writing its three machine-wide hooks into
`~/.claude/settings.json` in the first place, which is a different failure mode from the
`hooks`-enforced-key mechanism (that one only reverts an injection *after* it has already
happened, at the next switch). Both should be named as complementary, not redundant: enforced-key
reverts anything that slips through; `"hooks": false` in `config.json` is what should stop it
from slipping through at all. The new activation check (§3) is the third layer and belongs in
the same doc passage as the detection backstop.

The `sapience.nix` header comment block (lines 12-18) makes the same claim ("per-repository
design") that the dispatch found to not match machine reality; it should gain a one-line pointer
to the `"hooks": false` opt-out once the fix lands, parallel to how the existing comment already
explains the `hooks`-enforced-key reasoning.

## Decisions

1. **Default, not force.** Use `if .hooks == null then false else .hooks end` (preserve an
   explicit value, default only when the key is absent) rather than unconditionally overwriting
   to `false` on every run. Rationale: the task's own title says "default ... to false," and its
   body says "preserve an explicit false" — both point at default/preserve semantics, not force.
   It also matches the sibling `auto_approve` field's intent in the same jq pipeline. A future
   toggle that lets a user opt back into machine-wide hooks (not in scope here) would be broken
   by unconditional forcing; defaulting leaves that door open without doing anything about it
   now.
2. **New verification check is new code in `modules/`, not an edit to the extension's
   `verify-sapience-mcp.sh`.** That script is sourced from a different repository's source store
   and is explicitly the companion task's territory (per the dispatch's own "Companion:" line and
   confirmed by reading its actual header, which covers per-project MCP registration and
   settings-fragment merging — an unrelated surface).
3. **Recommend a hard-abort activation check**, not a warning-only one, for the new guard —
   subject to final confirmation in planning, since this is a judgment call the dispatch leaves
   open ("fails loudly" is stated, not a specific mechanism).

## Risks & Mitigations

- **Risk**: a hard-abort activation check could block `home-manager switch` entirely if it ever
  false-positives (e.g., a future legitimate hook happens to mention `.sapience/mcp.py` for an
  unrelated reason). *Mitigation*: scope the signature narrowly to the three known flag names
  (`--briefing-text`, `--receipt`, `--effect-line`) combined with the `.sapience/mcp.py` path,
  exactly the vendor's own `wire_hooks()` command strings — nothing else in this codebase writes
  that combination.
- **Risk**: forgetting to update both jq sites (A and B) leaves the first-run case still minting
  `hooks: true` for a brand-new machine. *Mitigation*: both sites are named explicitly above with
  exact before/after text; the implementation phase should diff both.
- **Risk**: the GOAL's "decide whether false is forced or only defaulted" could legitimately be
  re-opened during planning/implementation with a different conclusion than this report's
  (default). If so, the planner should still keep the explicit-null-test fix (never `//`) since
  that part is not in question — only the force-vs-default branch would need to change from `if
  .hooks == null then false else .hooks end` to a flat `.hooks = false`.

## Appendix

### Commands/greps used
- Full read of `modules/home/services/sapience.nix` (1211 lines).
- Full read of `docs/sapience.md` (821 lines).
- `grep -n "hooks"` across `~/.sapience/sapience_upkeep.py`, `~/.sapience/mcp.py`,
  `~/.sapience/sapience_cli.py`.
- Targeted `sed -n` reads of `hooks_opted_out`, `wire_hooks`, `update`, `auto_update`,
  `cli_auto_on_plan`, `main` in `sapience_upkeep.py`; `main()`'s `--briefing-text/--receipt/
  --effect-line` branches in `mcp.py`; `hook`/`answer` in `sapience_cli.py`.
- `cat ~/.sapience/config.json`, `cat ~/.claude/settings.json` (live state baseline).
- `cat /home/benjamin/.dotfiles/.claude/scripts/verify-sapience-mcp.sh` header (territory check
  only — confirms this is the companion task's surface, not this one's).
- Read of `modules/home/core/dotfiles.nix`'s `claudeSettings` activation entry (the enforced-key
  merge the dispatch references).

### References
- `modules/home/services/sapience.nix:319-332` (the two jq sites)
- `modules/home/core/dotfiles.nix:93-128` (`claudeSettings` enforced-key activation entry)
- `docs/sapience.md:645-674` (`### Why the hooks live in the repo`)
- `~/.sapience/sapience_upkeep.py:72-73,122-183,289-327,354-380,503-520` (`hooks_opted_out`,
  `wire_hooks`, `update`, `cli_auto_on_plan`/`_cli_hooks_wired`, `main`)
- `~/.sapience/mcp.py:1953-1972` (`--briefing-text`/`--receipt`/`--effect-line` entry points)
- `~/.sapience/sapience_cli.py:745-782` (`hook`/`answer`)

# Teammate B Findings: Prior-Art Harvest + Alternative Approaches (Task 72, Round 2)

**Task**: 72 (.dotfiles) — email workflow infrastructure/prerequisites
**Round**: 2 team research, teammate B
**Lens**: Deep ~/Mail/.claude prior-art audit (harvest manifest) + alternative approaches / prior art
**Does NOT duplicate**: teammate A's nix-module authoring approach

---

## Key Findings

1. **Prior art already gets delete right at the mechanism level, wrong at the enforcement level.** `email_execute.py` never calls `himalaya message delete`; every "delete" is `himalaya message move -a <account> -f <folder> <id> <trash_folder>` (email_execute.py:138-150), i.e. move-to-Trash, matching the shared-invariant's "IMAP-level, never local tag+Expunge" rule. What it lacks entirely is any enforcement mechanism — no PreToolUse hook of any kind exists anywhere in `~/Mail/.claude/settings.json` (grep for `hooks`/`PreToolUse` returns nothing). Safety in the prior art was 100% procedural (agent instructions + a human reading a table), never technical. This sharpens the seed's Phase-3 rationale: the wrapper+hook design isn't replacing a weaker hook, it's adding the *first* hook this domain has ever had.

2. **The "AI triage" in prior art is not an LLM call.** `email_triage.py:272-324` — the function is literally named to invoke Claude but the docstring admits "Falls back to REVIEW if AI unavailable" and the implementation (line 280: `# For now, use heuristics as AI fallback`) is pure keyword/domain scoring, never a real model call. HARVEST verdict should say explicitly: there is no working LLM-classification code to harvest, only the rule engine and the (unused) intent to call Claude.

3. **The prior art has zero List-Unsubscribe / precedence:bulk / reply-history / VIP-allowlist logic.** `grep -rn "List-Unsubscribe\|precedence" ~/Mail/.claude/` returns nothing except unrelated "precedence" hits in `task.md`/`CLAUDE.md` about routing precedence. The entire deterministic-classification backbone the v3 plan Phase 8 specifies (List-Unsubscribe extraction, `precedence: bulk`, sender-domain, reply-history, VIP allowlist) is **new work**, not harvestable — the prior art's only deterministic signals are hardcoded sender/domain substring lists (`email-preferences.md` "Sender Categorization Patterns" section) and age/read-state thresholds. Don't let Phase 0 imply otherwise.

4. **Confirmed opus pin and confirmed checkbox churn, with exact locations.** `~/Mail/.claude/commands/email.md:5` — `model: claude-opus-4-5-20251101` (the *only* file with a model pin; `agents/email-agent.md` itself has no model field). Checkbox UX churn is real and traceable: `~/Mail/specs/archive/014_remove_email_approve_mode/`, `022_add_checkboxes_to_email_plans/`, `023_revise_parse_checked_items/` — three archived tasks iterating on the same approval-UX seam, confirming the seed's DISCARD verdict.

5. **`gmail-folders` channel (mbsync.nix:83-84) has an explicit `Remove Both` that the seed report's freeze/thaw note doesn't distinguish.** The seed says "primary gmail channels currently set `Expunge Both` but no `Remove` (default `None`)" — true for `gmail-inbox/sent/drafts/trash/all/spam` (each has only `Expunge Both`, confirmed via `grep -n "Channel\|Expunge\|Remove"`), but the catch-all `gmail-folders` channel (line 83) explicitly sets `Remove Both`, and two Logos channels (lines 153-154, 162-163) do too. Phase 5's freeze/thaw review item should scope precisely: `Remove Both` on `gmail-folders` means locally-deleted folders propagate as remote folder deletions — irrelevant to message-level bulk purge but worth a one-line callout so it isn't conflated with the inbox channels during review.

6. **aerc already has a native confirm-gesture primitive and it already bypasses any Claude-side hook.** `modules/home/email/aerc.nix:79` — the existing `d` keybind is `:prompt 'Delete message?' 'delete-message'`; `A` is an unmark/mark/archive macro. These are aerc's own internal commands, executed by aerc's Go IMAP/notmuch worker process, **never through a Bash tool call Claude Code can intercept**. This is a structural point the seed report doesn't surface: the entire PreToolUse mail-guard hook design (Phase 3) only ever gates *agent-issued* Bash commands. A human pressing `d`/`a`/`A` in aerc today already performs a real IMAP mutation with zero manifest, zero wrapper, zero hook — by design, since it's the human's own interactive action, not an agent's. The implication for Phase 9: the new `Proposed-Delete/Archive/Unsure` querymap confirm-keybinds MUST explicitly `:exec` the wrapper binaries (or a script that calls them) rather than reusing aerc's built-in `:archive`/`:delete-message`/`:prompt` verbs, or the "confirm gesture feeds the IMAP-level wrapper, not just retags locally" requirement (v3 plan line 100) silently fails — aerc's native commands never touch the manifest system.

7. **`permissions.deny` in `.dotfiles/.claude/settings.json` currently has zero mail-related entries** (`Bash(rm -rf /)`, `Bash(rm -rf ~)`, `Bash(sudo *)`, `Bash(chmod 777 *)` only, lines 127-130). The v3 plan's "keep the coarse permissions.deny backstop entries" (Phase 3) describes entries that must be *added*, not ones that already exist — a subtle but real distinction for phase scoping (this is new surface, not a preservation task).

## Recommended Approach

### A. Harvest manifest (concrete, ready to write to the extension's `email-preferences.md`)

| Item | Source | Harvest as |
|---|---|---|
| Sender/domain/subject keyword lists (newsletter, notification-domain, promotional, transactional patterns) | `email-preferences.md` lines 28-92 | Seed lists for the *keyword-fallback tier only* — NOT the primary classifier (List-Unsubscribe/precedence:bulk supersede substring matching per shared invariant #4) |
| `MAX_BATCH_SIZE = 50` | `email_execute.py:26` | Direct constant reuse in the wrapper contract |
| `PLAN_EXPIRY_DAYS = 7` | `email_execute.py:27` | Consider reusing for manifest staleness (a manifest older than 7 days should require regeneration — not in the v3 plan today, worth adding as a small hardening) |
| Confidence threshold table (>=0.80 auto-action, 0.70-0.79 borderline, <0.70 manual review) | `email-preferences.md` lines 567-573 | Reasonable starting point for the `unsure` bucket threshold, but the v3 design's bias is ~100% recall-on-keep — recommend tightening to >=0.90 auto-delete, everything else to `unsure`, since the prior art's 0.70 threshold is what let churn happen (a message at 0.71 confidence got auto-deleted with no review) |
| Safe-ordering-of-actions idea (`flag -> unflag -> keep -> archive -> delete`, `email_execute.py:250`) | `email_execute.py` | Worth keeping as an implementation detail inside `email-delete-confirmed`/`email-archive-confirmed` if a single manifest ever mixes action types |
| Custom per-sender/domain override list (13 hand-added domain rules in `email-preferences.md` lines 372-519 — amazon.com, spotify.com, coinbase.com, proton.me, etc.) | `email-preferences.md` | Harvest as seed data for a VIP/blocklist starting point — but note these are all *delete* rules the user hand-added via `/revise`; there is no harvested KEEP-list beyond one entry (`onanyajoni@gmail.com`, line 359) — the new design needs to build its VIP-allowlist mechanism from scratch, prior art only proves the mechanism (custom rules take precedence) is desired |

**Explicitly NOT harvestable** (contradicts finding 3): List-Unsubscribe extraction, `precedence:bulk` detection, reply-history signal, VIP-allowlist logic. Write this into the handoff file as a "gap, not omission" note so nvim #803 doesn't go looking for code that isn't there.

### B. RETIRE verdict — confirmed, with full file inventory

```
~/Mail/.claude/commands/email.md                              (opus pin, DISCARD the pin specifically)
~/Mail/.claude/skills/skill-email/SKILL.md
~/Mail/.claude/agents/email-agent.md
~/Mail/.claude/scripts/email/email_list.py      (203 lines... actually 236)
~/Mail/.claude/scripts/email/email_analyze.py   (819 lines)
~/Mail/.claude/scripts/email/email_triage.py    (745 lines)
~/Mail/.claude/scripts/email/email_filter.py    (348 lines)
~/Mail/.claude/scripts/email/email_execute.py   (417 lines)
~/Mail/.claude/context/project/email/{email-plan-format,email-patterns,task-integration,ai-triage-prompts,himalaya-integration}.md
```
Only `email-preferences.md` (harvest per §A) survives as data. Confirm all five scripts are dead code beyond their `__pycache__` compiled artifacts (present for filter/triage/analyze, absent for list/execute — consistent with `execute` being invoked least and `list` never having been separately imported).

### C. DISCARD verdict — confirmed with citations

- **Checkbox-approval UX**: `specs/archive/{014,022,023}_*` — three churned tasks. Superseded by aerc tagged-view + manifest per shared invariant. Do not resurrect `email_filter.py`'s markdown-checkbox parser even as a fallback.
- **`model: claude-opus-4-5-20251101`** (`commands/email.md:5`) — follow the current tiered policy (Sonnet for worker/implementation agents).

### D. Prior art / existing solutions worth adopting instead of hand-rolling (new material this teammate contributes)

1. **List-Unsubscribe parsing**: don't hand-roll a regex. `planetaryescape/list-unsubscribe` (GitHub) parses both RFC 2369 (`List-Unsubscribe`) and RFC 8058 one-click (`List-Unsubscribe-Post`) headers into a typed action enum — directly matches the `email-unsubscribe-extract` wrapper's need to distinguish "mailto: unsubscribe" vs "one-click HTTPS POST" vs "manual-link-only" senders (the last category is exactly the one the postmortem's rule #7 says must never auto-fetch). Even if not vendored, its header-parsing logic (which fields to check, precedence between `List-Unsubscribe-Post: List-Unsubscribe=One-Click` and the URL(s) in `List-Unsubscribe`) is a useful reference to avoid re-deriving from the RFC.
2. **`afew`** (`github.com/afewmail/afew`) — an existing, mature notmuch auto-tagging daemon with a `ClassifyingFilter` architecture and user-definable Python filter classes read from `~/.config/afew/`. This is a *direct alternative* to hand-writing the `postNew` junk-rule shell lines in `notmuch.nix` (Phase 11). Trade-off: `afew` adds a new runtime dependency and its own config surface (a second place besides `notmuch.nix` postNew hooks where tagging logic lives), but it buys battle-tested move-mode + spam-filter-hook integration and per-sender rule files instead of a growing shell-script `postNew` string. Recommend the seed/plan explicitly record this as a **considered-and-rejected** option (simplicity + single ownership line favors staying in `notmuch.nix` postNew per the existing nix-vs-.claude ownership table) rather than silently not mentioning it — a future implementer will otherwise "discover" afew and be tempted to bolt it on mid-implementation.
3. **Terraform's saved-plan pattern** (`terraform plan -out=FILE` then `terraform apply FILE`) is the closest mainstream analog to the wrapper contract's dry-run-then-execute-from-manifest design, and it's a useful precedent to cite in the extension's docs — but it's *weaker* than the seed's chosen design: Terraform's `apply FILE` trusts the binary plan file directly with no hash/signature step; the manifest system deliberately adds `--confirm-manifest <sha256>` as a tamper/staleness check Terraform doesn't have. Worth stating explicitly in the extension docs that the sha256 step is a deliberate hardening beyond the Terraform precedent (email deletion is less reversible than most infra changes outside 30-day Trash retention).
4. **aerc's own `:choose` command** (`:choose -o y 'Permanently delete?' delete-message<Enter>`, documented in aerc's binds reference) is aerc's native two-step confirm primitive, stronger than the currently-configured `:prompt`. If Phase 9's new querymap keybinds want an in-aerc "are you sure" gate *in addition to* the external manifest-review step, `:choose` is the right primitive — but per finding 6, whatever the keybind ultimately runs must `:exec` out to the wrapper, not call `:delete-message`/`:archive` directly.

### E. Alternative safety-envelope designs considered

| Alternative | How it would work | Trade-off vs. seed's dry-run + sha256-manifest |
|---|---|---|
| **aerc tagged-view confirm feeding the wrapper directly** (seed's actual choice) | Human reviews `+proposed-*` tagged messages in aerc, presses a keybind that appends IDs to a manifest file + optionally shells to the wrapper | Best fit: reuses aerc (already the human's daily driver per the pre-existing `<leader>me` nvim binding) as the review surface; downside is the keybind logic must be careful (finding 6) not to accidentally use aerc's native mutation commands |
| **Two-person-review style** (a second human/session must independently approve the manifest before `--execute` accepts it) | E.g. require two distinct `--confirm-manifest` invocations from different sessions, or a second sha256 of a "reviewed-by" stamp | Overkill for a single-user personal mailbox; the threat model here is "wrong classification," not "malicious insider" — reject, but note the git-tracked manifest already gives an audit trail equivalent to a lightweight single-reviewer sign-off |
| **git-tracked manifests as the sole confirmation mechanism** (no separate sha256 flag; `--execute` just requires the manifest file to be a committed, unmodified-since-commit git object) | Wrapper checks `git status --porcelain <manifest>` is clean and `git log -1` exists before executing | Interesting alternative: piggybacks on git's own integrity guarantee instead of a bespoke hash, and gets "who approved this" for free via git blame/commit metadata. Downside: requires the manifest to be committed *before* review is meaningfully done (commit-then-review vs. review-then-commit ordering is easy to get backwards), and ties execution to git working-tree state which is fragile if someone runs `--execute` from a dirty worktree. The seed's explicit `sha256` flag is simpler to reason about and doesn't depend on git state — recommend keeping the seed's choice, but pairing it with git-tracking (already planned) rather than replacing the hash with git status as the sole gate. |
| **Manifest-driven confirm-then-execute in other CLI tools generally** (Terraform saved-plan, `kubectl diff` + `kubectl apply`, `aws-vault exec` confirmation prompts) | Surveyed in §D.3 | None add a cryptographic tamper-check on the plan artifact the way the seed's sha256 flag does; the seed's design is more conservative than any of these precedents, which is appropriate given delete is harder to undo than most infra/k8s changes |

### F. mbsync freeze/thaw alternatives

- **Seed's choice** (stop timer, confirm no proc, back up SyncState, single explicit `mbsync gmail` to reconcile) is standard and matches how mbsync's own docs describe safe manual operation — no better-established alternative found. One refinement worth recording: `systemctl --user stop mbsync.timer` alone does not kill an in-flight `mbsync` run; the freeze helper must also `pgrep mbsync` (already specified in Phase 5 tasks) AND ideally `systemctl --user is-active mbsync.service` (if mbsync also runs as a oneshot service unit, not just a timer) to catch a run that started just before the timer was stopped. Confirm whether this repo's mbsync systemd unit is timer-triggered oneshot only, or also has a long-running service — not visible in `mbsync.nix` itself (likely in a separate systemd module); teammate A or the plan author should check `modules/home/email/` siblings / systemd config for the actual unit name before Phase 5 implementation.
- **Alternative not chosen, worth recording as rejected**: relying solely on `Sync Pull` mode (mbsync's read-only-remote flag) during bulk ops instead of a full stop/backup. Rejected because it doesn't protect against a concurrent local mutation racing the agent's own writes — freeze/thaw's full-stop is strictly safer and the plan already selected it.

### G. notmuch postNew institutionalization alternatives

- Current `postNew` hook (`modules/home/email/notmuch.nix` lines ~14-24) is a short inline shell string doing folder/account tagging only — no junk rules yet. The v3 plan's Phase 11 approach (append `notmuch tag +junk -inbox -- from:...` lines to this same string) is the minimal-diff option and keeps ownership in one nix file, consistent with the existing "Extend, never rewrite" preserved-asset note.
- `afew` (§D.2) is the only serious existing-tool alternative found; recommend recording as considered-and-rejected rather than silently omitted (see §D.2 trade-off).
- A third option — Gmail server-side filters as the *sole* mechanism, skipping local `postNew` tagging — is explicitly what the v3 plan already does NOT choose for the passive loop (it dual-writes both), and multiple-account coverage (Logos/Protonmail has no Gmail-filter equivalent) is the reason: `postNew` is the only mechanism that works identically across both accounts.

## Evidence/Examples

- `email_execute.py:87-102` (`get_archive_folder`/`get_trash_folder`) and `:124-150` (`execute_action` archive/delete branches) — confirms move-based delete, not `himalaya message delete`.
- `email_triage.py:272-324` — the unimplemented "AI" categorization function; line 280 comment is explicit (`# For now, use heuristics as AI fallback`).
- `email-preferences.md` lines 1-92 (schema + sender-categorization patterns), 567-573 (confidence thresholds), 372-519 (13 custom domain-delete rules), 664-747 (checkbox workflow docs — the DISCARD target itself, fully described).
- `commands/email.md:5` — `model: claude-opus-4-5-20251101`.
- `~/Mail/specs/archive/{014,022,023}_*` directory listing — churn evidence.
- `.dotfiles/modules/home/email/mbsync.nix` — `grep -n "Channel\|Expunge\|Remove"` output showing `Remove Both` only at lines 84, 154, 163 (folders/catch-all channels), never on the six named gmail channels.
- `.dotfiles/modules/home/email/aerc.nix:79` (`d = ":prompt 'Delete message?' 'delete-message'<Enter>"`) and the existing `query-map` / `home.file.".config/aerc/querymap-gmail"` block (already present, Phase 9 just appends entries).
- `.dotfiles/.claude/settings.json` lines 31-40 (existing `PreToolUse`/`Write` matcher — the template Phase 3's Bash matcher should mirror) and lines 125-131 (`permissions.deny`, currently zero mail entries).
- `.dotfiles/.claude/hooks/validate-meta-write.sh` — closest existing hook template (stdin JSON parse via `jq '.tool_input...'`, case-match, emit decision JSON) for authoring `mail-guard.sh`.
- Web: `planetaryescape/list-unsubscribe` (GitHub), RFC 8058 (`rfc-editor.org/rfc/rfc8058.html`), `afew` (`github.com/afewmail/afew`, `afew.readthedocs.io`), Terraform plan/apply docs (`developer.hashicorp.com/terraform/cli/commands/{plan,apply}`), aerc binds reference (`man.archlinux.org/man/aerc-binds.5.en`, `mankier.com/5/aerc-binds`).

## Confidence Level

**High** for all file-cited findings (prior-art script behavior, exact line numbers, churn task IDs, existing nix config contents) — all directly read from source.
**Medium** for the aerc `:choose`-vs-`:prompt` and native-command-bypass analysis (finding 6) — the mechanism (aerc's built-in commands operate independently of Claude Code's tool-call interception) is a structural/architectural inference from how aerc and Claude Code hooks work, not something explicitly documented as a "gotcha" in aerc's own docs; recommend the nvim #803 or implementation-phase author verify empirically (fire the `d` keybind under a PreToolUse Bash-matcher hook that logs all Bash calls, confirm no log line appears) before relying on this claim in the extension's hook design.
**Medium** on the `afew` recommendation — a reasonable existing tool but not verified against this repo's exact notmuch/mbsync integration; the "considered and rejected" framing is the safe conclusion pending deeper spike if postNew's shell-string approach becomes unwieldy.
**Low** on the git-tracked-manifest-as-sole-gate alternative (§E) — included for completeness per the task's ask, but this is closer to a design fiction than surveyed prior art (no tool found that does exactly this for email); treat as a brainstormed alternative, not a researched pattern.

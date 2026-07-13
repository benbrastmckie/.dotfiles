# Teammate D Findings: HORIZONS — Task 72 Infrastructure/Prereqs (Round 2)

**Task**: 72 (.dotfiles) — email workflow infrastructure/prerequisites
**Role**: Horizons — long-term alignment and strategic direction
**Date**: 2026-07-02
**Inputs read**: `reports/01_infrastructure-prereqs-seed.md`, `specs/071_.../plans/04_email-workflow-implementation.md` (v3), `specs/ROADMAP.md` (empty template — contributing general strategic thinking per instructions), `modules/home/email/{mbsync,notmuch,aerc}.nix`, `.claude/settings.json`, `.claude/hooks/*`, `.claude/extensions/*`

---

## Key Findings

### 1. The nix-vs-extension split is correct, but the *coupling* between the two is unenforced — that's the real reusability risk

The v3 plan's ownership line (wrappers = nix, agent instructions/hooks = `.claude` extension authored canonically in `~/.config/nvim`) is well-reasoned, not arbitrary: it directly avoids repeating the `~/Mail/.claude` fork failure (a second, uncoordinated, orphaned copy of executable logic). Nix is also the *correct* axis for "reusable across machines" — that is literally nix/home-manager's job, and it is a stronger reusability guarantee than putting shell scripts inside a `.claude` extension, which only travels between **projects/repos** on a machine that already has the wrappers, not between **machines**. Two different, complementary reusability axes are already being served by the current split; I would not re-open this decision.

The gap is that reusability of the *extension* silently assumes the *nix layer* is present. Nothing in the Phase 6 agent/skill design (per the seed report and plan v3 §Phase 6) checks that the five wrapper binaries actually exist on `$PATH` before instructing the agent to call them. If the `email/` extension is loaded (via `<leader>al`) into a repo/machine that hasn't rebuilt this `.dotfiles` config, the agent will confidently try to invoke `email-census` etc. and get a bare "command not found" with no actionable remediation. Given the extension is explicitly designed to be portable across arbitrary consuming projects, this failure mode is not hypothetical — it's the first thing that will happen on a partially-configured machine.

### 2. The safety-envelope pattern is genuinely novel to this repo's agent system — worth hardening for reuse, but not worth generalizing into a framework right now

I checked whether any equivalent "confirmed-mutation wrapper" pattern (dry-run default + sha256-manifest confirmation + PreToolUse allowlist/deny hook) already exists anywhere in `.claude/`. It does not. Current state:
- `.claude/settings.json` `permissions.deny` is a static 4-entry list (`rm -rf /`, `rm -rf ~`, `sudo *`, `chmod 777 *`) — no dynamic allowlist-of-wrapper-binaries pattern anywhere.
- The only `PreToolUse` hook in the repo (`Write` matcher) unconditionally allows and does nothing but tag `state.json` writes.
- `git-workflow.md`'s "Git Safety Protocol" (never force-push, never `reset --hard`, never skip hooks) is enforced **only by prose instruction to the agent** — there is no hook backstop today. This is the same class of risk task 72's mail-guard hook is designed to close, just for a different destructive surface.

This means task 72's Phase 3 hook would be the **first instance** of this pattern in the whole agent system, not a copy of an existing one. That is a real, general capability gap this task happens to be forced to solve. My recommendation is *not* to scope-expand #72 into building a generic "confirmed-mutation" framework (that would violate the task's own postmortem discipline against analysis-paralysis/scope creep) — but to author `mail-guard.sh` and the manifest schema so the pattern is trivially liftable later: keep the binary-allowlist and deny-regex as clearly isolated data (arrays/tables), not interleaved control flow, and keep the manifest JSON schema generic (`id, sender, subject, date, proposed_action, reason` — already generic-shaped in the seed report) rather than email-specific field names where avoidable. Then leave a one-line breadcrumb (a memory candidate / roadmap note, not a task) suggesting future extraction to `.claude/context/patterns/confirmed-mutation-wrapper.md` if/when a second destructive surface (e.g., git, bulk file ops) needs it. Cheap now, expensive to retrofit later; not worth doing as new scope today.

### 3. Right seam for multi-account: generalize the *contract surface*, not the *implementation*

Plan v3 correctly rejects "dual-account-now" as a settled design decision, and I agree the Logos/Protonmail implementation itself should stay deferred (no 30-day Trash undo, Bridge-uptime dependency, much smaller 58-message volume — Phase 13 already documents this well). But there's a cheaper, orthogonal question: should the wrapper **CLI contract** reserve an `--account` flag (defaulting to `gmail`) now, even though only Gmail is implemented behind it?

This costs approximately nothing at authoring time (Himalaya is already multi-account aware — `modules/home/email/mbsync.nix` already declares a complete, working `logos` account/group alongside `gmail`, so the underlying stack is not Gmail-only, only the *policy* is Gmail-first). But retrofitting an account parameter into a contract that three separate repos (`.dotfiles` #72, nvim #803's extension/skill instructions, `~/Mail` #29's purge driver) have already consumed and hardcoded against is a breaking, cross-repo change. This is exactly the kind of seam that's cheap before three consumers exist and expensive after. Recommend: add `--account gmail` (default, only value validated/accepted for now) to the five wrapper signatures and the manifest schema, explicitly documented as reserved-not-implemented, so Phase-2 Logos work is additive rather than a contract break.

### 4. A concrete blast-radius bug in the plan: Phase 5's `thaw` step is not account-scoped

This is a specific, actionable catch grounded directly in `modules/home/email/mbsync.nix`: the file declares two independent `Group`s — `gmail` (lines 88-96) and `logos` (lines 166-174) — each with its own channels. Plan v3 Phase 7's verification step correctly scopes reconciliation to `mbsync gmail` (group-scoped). But Phase 5's freeze/thaw helper, as specified in the seed report and plan (`"thaw re-enables the timer and runs a single explicit mbsync -a"`), uses `-a` (**all** groups, i.e., both Gmail and Logos).

Given the whole design is explicitly Gmail-first with Logos/Protonmail Bridge deferred, and given Bridge-uptime is itself flagged in Phase 13 as an independent reliability concern, a Gmail-only backlog-purge freeze/thaw that reconciles `-a` on thaw will unexpectedly also sync Logos — coupling the blast radius of a supervised, high-stakes Gmail operation to an unrelated account's availability and timing. This should be `mbsync gmail` (group-scoped), matching Phase 7. Small fix, but exactly the kind of scope-boundary leak that's cheap to catch now and easy to miss during implementation because "just run `mbsync -a`" is the more familiar/default invocation.

### 5. Idempotency/replay-safety of the manifest is under-specified relative to how much Phase 10 depends on it

Of the four strategic challenges named in the assignment (unattended/scheduled runs, observability, idempotency/replay, disaster recovery), two are already first-class in the v3 design: OAuth-expiry handling (Phase 1 gate + `invalid_grant` fail-safe threaded through Phases 2/8/10) and disaster recovery (Phase 5 SyncState backup + documented restore procedure). Observability is partially first-class: the mail-guard hook appends an audit line per command, which covers "what did the agent attempt," but not "what did the mailbox state look like before/after" (a full audit trail would ideally correlate hook log entries with manifest execution outcomes, not just the command that was allowed through).

Idempotency/replay is the weakest of the four. The current contract (seed report §4) says execute mode "diffs executed IDs against the approved manifest" — this prevents re-deriving a *different* ID list, but doesn't specify what happens if the **same** manifest is re-submitted after a partial run (e.g., an `invalid_grant` halt mid-batch, per Postmortem rule 9, or a crash). Does the wrapper re-issue IMAP delete/move calls for messages already moved to Trash on the previous run? Himalaya's operations are likely idempotent in practice (deleting an already-trashed message probably no-ops or errors harmlessly), but that should not be an unverified assumption at 64k-message scale where Phase 10 explicitly requires resumability via "partial manifests."

Given Phase 10 already commits to resumability as a done-when criterion, I'd promote this from "nice to have" to **first-class in the mechanism** (Phase 2's wrapper contract), not deferred: extend the manifest schema with a per-ID execution-status field (`pending|executed|failed`) written back to a companion state file (keeping the sha256-hashed "approved" content immutable, so the confirmation hash never needs recomputation mid-run), and have `--execute` skip IDs already marked `executed`. This is a small addition to Phase 2's scope, directly serves an already-committed Phase 10 requirement, and is much cheaper to build into the initial contract than to bolt on after the nvim extension and `~/Mail` purge driver are already coded against a simpler contract.

---

## Recommended Approach

1. **Keep the current nix/extension ownership split as-is** — it correctly serves two different reusability axes (machine vs. project) and directly avoids the `~/Mail/.claude` fork failure mode. Do not relocate wrapper implementation into the extension.
2. **Add a `$PATH`/precondition check** to the wrapper-calling surface (either as a first step in `skill-email-cleanup`/`skill-email-implementation`'s instructions, or as a cheap guard inside `mail-guard.sh` itself) that fails with an actionable message ("wrapper binaries not found — run `home-manager switch` with `modules/home/email/agent-tools.nix` enabled") rather than a bare command-not-found. This is the one piece of the current design that assumes cross-repo/cross-machine coupling without verifying it.
3. **Do not build a generic confirmed-mutation framework in #72.** Author `mail-guard.sh` and the manifest schema with the allowlist/deny data cleanly isolated from control flow so the pattern is lift-able later; leave a memory-candidate breadcrumb, not a new task.
4. **Reserve `--account gmail` (default, sole accepted value for now)** in the five wrapper CLI signatures and the manifest schema, documented as reserved-not-implemented, so Phase-2 Logos work is additive across all three consuming repos instead of a breaking contract change.
5. **Fix Phase 5's thaw step to be group-scoped (`mbsync gmail`)**, matching Phase 7's verification scoping, so a Gmail-only supervised operation cannot have side effects on the independent Logos/Bridge sync.
6. **Promote manifest idempotency/replay-safety to first-class in Phase 2's wrapper contract**: add a per-ID execution-status field to the manifest lifecycle (approved → executing → executed/failed) so `--execute --confirm-manifest <hash>` is safely re-runnable after an `invalid_grant` halt or crash, without re-deriving state or risking double-execution at 64k-message scale.

## Evidence/Examples

- No existing PreToolUse allowlist/deny-by-binary hook anywhere in `.claude/settings.json` or `.claude/hooks/` — confirmed by direct inspection; only a trivial unconditional-allow `Write` matcher exists today.
- `git-workflow.md`'s destructive-op prohibitions (force-push, `reset --hard`, `rebase -i`, skipping hooks) are prose-only, unenforced by any hook — the same risk class task 72 is solving for email, evidence that the pattern generalizes beyond email.
- `modules/home/email/mbsync.nix` lines 16-96 (`Group gmail`) vs lines 97-174 (`Group logos`) — two fully independent, already-configured account groups; Himalaya/mbsync are not Gmail-only at the tooling layer, only the *policy* (v3 plan) is Gmail-first.
- Plan v3 Phase 7 task list: `mbsync gmail` (correctly group-scoped) vs. Phase 5 task list: `mbsync -a` (all-groups) — direct textual inconsistency within the same plan document.
- Plan v3 Phase 10 "Done when": explicitly requires resumability ("resumable via partial manifests") — an already-committed requirement that the current manifest schema (id, sender, subject, date, proposed_action, reason) does not yet structurally support without an execution-status field.
- `~/.config/nvim/.claude/extensions/email/` does not yet exist (confirmed via direct filesystem check) — the extension side has not started, so contract changes recommended here (reserved `--account` flag, manifest status field) are still free; they become expensive the moment nvim #803 or `~/Mail` #29 start coding against the current contract.

## Confidence Level

- Findings 1, 2 (extension/nix split reasoning, novelty of safety-envelope pattern in this repo): **High** — directly grounded in reading `.claude/settings.json`, `.claude/hooks/`, and `git-workflow.md`.
- Finding 3 (account-flag seam): **Medium-High** — sound cost/benefit reasoning and grounded in the existing multi-account mbsync config, but "worth reserving now" is a judgment call, not a hard requirement.
- Finding 4 (Phase 5 `mbsync -a` vs `mbsync gmail` scoping bug): **High** — directly verified against `mbsync.nix` and the plan text; this is a concrete, low-ambiguity correction.
- Finding 5 (manifest idempotency): **Medium-High** — the gap is real and the recommendation is proportionate to an already-committed Phase 10 requirement, but the exact schema shape is an implementation-time design choice, not fully pinned here.
- ROADMAP.md alignment: **N/A / Low applicability** — `specs/ROADMAP.md` is the unpopulated generic template (no items yet), so findings above reflect general strategic reasoning about this repo's trajectory (nix reproducibility + extension portability + agent-safety precedent) rather than alignment against stated roadmap items.

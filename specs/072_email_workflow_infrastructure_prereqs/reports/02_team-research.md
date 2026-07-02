# Research Report: Task #72 — Email Workflow Infrastructure & Prerequisites

**Task**: 72 (.dotfiles) — email workflow INFRASTRUCTURE + PREREQUISITES (child of task 71)
**Date**: 2026-07-02
**Mode**: Team Research (4 teammates — Primary, Alternatives, Critic, Horizons) · Round 2
**Builds on**: `reports/01_infrastructure-prereqs-seed.md` (round-1 seed) and
`specs/071_.../plans/04_email-workflow-implementation.md` (v3 reference plan)
**Session**: sess_1783024044_75bbd5

---

## Summary

Round 2 hardened the round-1 seed against the **live system** and surfaced material corrections.
The seed's core design — nix-declared, dry-run-by-default wrapper binaries gated by
`--execute --confirm-manifest <sha256>`, a PreToolUse allowlist/deny hook, mbsync freeze/thaw, aerc
review querymap, notmuch `postNew` scaffolding — is **sound and should proceed**. But four teammates
independently verified claims against `himalaya`, `notmuch`, `mbsync.nix`, and `systemctl`, and the
result is a set of **corrections that must land before planning** or they will force a plan revision
mid-implementation:

1. **The "IMAP-level Himalaya ONLY (safe)" invariant is mis-framed** — Himalaya is configured with
   `backend.type = "maildir"`, so it operates on the *local* Maildir, exactly like the "unsafe" path.
   The mechanism still works, but for a different reason than stated (verified by lead).
2. **The live notmuch index is empty** (0 messages indexed vs. 64,316 Maildir files) — every
   census/classify/aerc claim currently queries nothing. `notmuch new` must be re-run and confirmed.
3. **`invalid_grant` targets the wrong call site** — `himalaya`/`aerc` use working app passwords;
   only `mbsync` uses the broken XOAUTH2. The OAuth fail-safe belongs on the `mbsync` step.
4. **aerc's native `d`/`D`/`a`/`A` keybinds bypass the entire hook/wrapper design** (all 4 teammates
   or 3 independently) — a pre-existing human-operated mutation path the seed never accounts for.

Plus two concrete, verified **plan bugs** (Phase 5 `mbsync -a` blast-radius; manifest envelope-ID
instability) and several cheap contract-hardening seams worth reserving now (per-ID execution status,
`--account` flag) before three repos consume the contract.

---

## Key Findings

### Primary Approach — nix wrapper mechanism (Teammate A)

- **New file `modules/home/email/agent-tools.nix`** (not extending `packages/email-tools.nix`, which
  is a pure package list). Author 5 `pkgs.writeShellScriptBin` derivations. **Confidence: high.**
- **No shared-bash-library pattern exists** in this repo's `writeShellScriptBin` usage
  (`modules/home/scripts/*.nix` all inline their bodies). Use a Nix `let`-bound preamble **string
  interpolated** into each wrapper rather than a `source`d external lib — keeps each produced binary
  self-contained, which the mail-guard hook relies on (it allowlists by binary path with no external
  file to tamper). A provided full skeletons for `email-census` (read-only), `email-delete-confirmed`
  (dangerous), the `mutationPreamble` (`--execute`/`--confirm-manifest`/dry-run banner/hash verify),
  and a working `mail-guard.sh`. **Confidence: high.**
- **Live-verified Himalaya verb semantics** (`himalaya v1.2.0`): `message delete` soft-moves to the
  trash folder (`folder.alias.trash = "[Gmail].Trash"`); `folder expunge` truly deletes flagged
  messages; the correct read verb is **`envelope list -o json`** — `message list` does **not exist**
  in v1.2.0 (any doc/plan text saying `message list` must be corrected). **Confidence: high.**
- **Manifest = JSONL** (one object per line), fields `id, sender, subject, date, proposed_action
  (delete|archive|unsure|keep), reason`. `--confirm-manifest` = `sha256sum` over raw manifest bytes;
  the wrapper recomputes and refuses on mismatch (staleness/tamper check). **Confidence: high.**
- **Two-layer enforcement (design clarification):** Claude Code's PreToolUse hook only fires on the
  agent's *own* top-level Bash tool calls, not on subprocesses a wrapper spawns. So the hook enforces
  "agent may only invoke the 5 wrapper binaries"; the **git-tracked, nix-built wrapper source** is the
  second enforcement layer ("wrappers only ever call the exact himalaya verbs their contract allows").
  The plan/extension docs must state this explicitly. **Confidence: high.**
- **Open question A raised (unresolved):** who filters `email-classify`'s raw output into the
  *approved* manifest that the mutation wrappers consume? Almost certainly the Phase 9 aerc review
  gesture must **write a new manifest file** of `+confirmed-*` IDs, not just retag. This couples to the
  aerc keybind design (below).

### Alternative Approaches & Prior-Art Harvest (Teammate B)

- **Prior-art delete is already mechanism-correct** (`email_execute.py:138-150` uses
  `himalaya message move ... <trash_folder>`), but had **zero enforcement** — no PreToolUse hook ever
  existed in `~/Mail/.claude`; safety was 100% procedural. Task 72's hook is the *first* hook this
  domain has had. **Confidence: high.**
- **Prior-art "AI triage" is not an LLM call** (`email_triage.py:280`: `# For now, use heuristics as
  AI fallback`) — there is no working classification code to harvest, only a keyword/domain rule engine.
- **Harvest table (data only, ready for the nvim #803 handoff):** `MAX_BATCH_SIZE=50`
  (`email_execute.py:26`), `PLAN_EXPIRY_DAYS=7` (reuse for manifest staleness), confidence-threshold
  table (recommend **tightening to ≥0.90 auto-delete**, everything else → `unsure`; the prior art's
  0.70 threshold is what caused churn), 13 hand-added custom domain-**delete** rules, and sender/domain
  keyword lists (**keyword-fallback tier only**). **Explicitly NOT harvestable** (confirmed via grep):
  List-Unsubscribe, `precedence:bulk`, reply-history, VIP-allowlist — the entire deterministic backbone
  the v3 plan Phase 8 specifies is **new work**, not a port. Record as "gap, not omission."
- **RETIRE inventory confirmed** with line counts: `commands/email.md` (opus pin at `:5`),
  `skills/skill-email/`, `agents/email-agent.md`, and all 5 py scripts (`email_list` 236,
  `email_analyze` 819, `email_triage` 745, `email_filter` 348, `email_execute` 417). Only
  `email-preferences.md` survives as harvestable data. **DISCARD** confirmed: checkbox UX
  (`~/Mail/specs/archive/{014,022,023}`), opus pin.
- **Considered-and-rejected alternatives (record explicitly so an implementer doesn't bolt them on):**
  `planetaryescape/list-unsubscribe` (RFC 8058 one-click parser — good reference, don't hand-roll the
  regex); `afew` notmuch auto-tagging daemon (rejected: second config surface, keep tagging in
  `notmuch.nix` postNew); Terraform plan/apply (weaker — no hash check, the seed's sha256 is a
  deliberate hardening); aerc's native `:choose` confirm primitive (use only if the keybind still
  `:exec`s the wrapper). **Confidence: high** on harvest/retire; **medium** on tooling alternatives.

### Strategic Horizons (Teammate D)

- **Keep the nix-vs-extension split.** It serves two *different* reusability axes — nix = across
  machines, extension = across projects — and directly avoids the `~/Mail/.claude` fork failure. Do
  not relocate wrappers into the extension. **Confidence: high.**
- **The safety-envelope pattern is genuinely novel to this repo** — no allowlist/deny-by-binary hook
  exists anywhere in `.claude/`; even `git-workflow.md`'s destructive-op rules are prose-only. Author
  `mail-guard.sh` with the allowlist/deny as clean isolated data (not interleaved control flow) so the
  pattern is trivially liftable later, and leave a **memory-candidate breadcrumb** — but do **not**
  scope-expand #72 into a generic framework. **Confidence: high.**
- **Reserve `--account gmail`** (default, sole accepted value) in the 5 wrapper signatures + manifest
  now — costs ~nothing (mbsync already has a full working `logos` group), but retrofitting after 3
  repos consume the contract is a breaking cross-repo change. Implementation stays Gmail-only.
- **Promote manifest idempotency/replay to first-class in Phase 2** (a per-ID execution-status field:
  `pending|executed|failed`, written to a companion state file so the approved sha256 content stays
  immutable). Phase 10 already commits to resumability via "partial manifests" at 64k scale; the
  current schema can't support it. **Confidence: medium-high.**
- **Add a `$PATH`/precondition check** so the extension fails with an actionable message when the
  wrapper binaries aren't built, instead of a bare "command not found."

### Gaps, Blind Spots & Unverified Premises (Critic — Teammate C)

- **FINDING 1 (critical, LEAD-VERIFIED):** the "IMAP-level Himalaya ONLY" framing is not what the
  config does — see conflict resolution below.
- **FINDING 2 (critical):** live notmuch index empty — see below.
- **FINDING 3 (critical):** `invalid_grant` call-site mismatch — see below.
- **FINDING 5:** aerc native keybind bypass — see convergent finding below.
- **FINDING 8 (manifest ID stability):** Himalaya envelope IDs are **per-folder and change on move**
  (the `--folder` flag is required on every id-based subcommand). A manifest generated against INBOX
  ids is **not reusable** once `email-delete-confirmed` moves messages to Trash. The contract must key
  on a **stable Message-ID header**, not the envelope id — or explicitly accept single-use-per-manifest
  ids. This is "the key handoff" nvim #803 authors against, so pin it before planning. **Confidence:
  medium** (documented CLI behavior; impact depends on implementation choices).
- **FINDING 7 (OAuth timeline):** `https://mail.google.com/` is one of Google's **restricted** scopes
  (plus contacts/calendar/carddav per `docs/himalaya.md:198`); publishing to Production may require a
  security assessment taking **weeks**, not the ~2h Phase 1 budgets. Research Google's actual
  requirements before recommending "publish to Production" as *the* fix. **Confidence: high** that this
  is unresearched; timeline itself unquantified.
- **FINDING 6 (cross-repo dependency not machine-enforced):** nvim #803's `dependencies` JSON is `[]`;
  the #72→#803 coupling is purely documentation-based (3 near-identical seed reports). Given task 71's
  own fork/orphan postmortem, note this explicitly rather than implying the handoff contract enforces ordering.

---

## Synthesis

### Conflicts Resolved

**CONFLICT 1 — "IMAP-level Himalaya = safe" (Seed/Teammate A) vs. "backend is maildir" (Teammate C).
Resolution: C is factually correct; the mechanism survives but the rationale is rewritten.**

Lead independently verified `config/himalaya-config.toml`: **both** accounts declare
`backend.type = "maildir"` (gmail root `/home/benjamin/Mail/Gmail`, lines 6/23). Therefore
`himalaya message delete`/`folder expunge` operate on the **local Maildir**, and Gmail-side
propagation happens only on the subsequent `mbsync gmail` (`Expunge Both`). A's live `--help`
verification of the *verb semantics* is also correct — the two findings are compatible; they conflict
only on *interpretation*.

The corrected invariant for the planner:
> Delete = **Himalaya `message delete` (moves the message into the `[Gmail].Trash` maildir folder)**,
> then, after human approval, **`folder expunge Trash`**, then **`mbsync gmail`** reconciles the
> `\Deleted` flag to the server via `Expunge Both`. What makes this safe is the **two-step
> move-to-Trash-then-expunge sequence + server push-back**, NOT a transport-layer ("IMAP vs local")
> distinction. A raw `rm` of the Maildir file or a notmuch tag-strip is unsafe because it only removes
> the INBOX *label* (an archive) — the message survives in `[Gmail]/All Mail` (64,316 baseline).

Consequence: **Phase 7 verification must confirm server-side removal from All Mail end-to-end** (not
local file-count deltas), because the two-hop path (local Himalaya op → separate `mbsync gmail`) can
half-succeed if the mbsync reconcile fails (see CONFLICT 3).

**CONFLICT 2 — none (convergent): notmuch index is empty.** C reproduced `notmuch count tag:inbox → 0`
and a 28K Xapian DB against a 64,316-file Maildir; A explicitly flagged it never tested its
`email-classify` queries against a populated index; aerc's source is `notmuch://~/Mail` so it would
currently show zero mail. **Action: re-run `notmuch new` and confirm the index count matches the
Maildir before Phase 2/8 wrapper work.** This blocks any believable census/classify design.

**CONFLICT 3 — none (convergent, refines seed): OAuth fail-safe targets the wrong component.** C
confirmed live that `mbsync` uses XOAUTH2 (`gmail-oauth2-refresh.service` = failed, `invalid_grant`)
while `himalaya`/`aerc` use working app passwords (`gmail-app-password` keyring). So the wrapper's
`himalaya` calls will **not** surface `invalid_grant`; only the `mbsync gmail` reconcile will. **The
fail-safe belongs on the freeze/thaw `mbsync` step, not the himalaya wrappers.** This also means the
**infrastructure build (this task) does not itself need OAuth resolved** — home-manager build +
wrapper dry-runs work with app passwords; only the destructive `mbsync` reconcile in #29 needs
OAuth/task-46. Task 46 is a hard blocker for the *purge*, not for building the mechanism.

**CONFLICT 4 — none (convergent, seed gap): aerc native `d`/`D`/`a`/`A` keybinds bypass the guardrail.**
B (finding 6) and C (finding 5) independently: `aerc.nix` already binds `d`→`:prompt ... delete-message`,
`D`→`:delete`, `a`/`A`→`:archive`. These run inside aerc's Go worker, never through Claude's Bash tool,
so the PreToolUse hook cannot intercept them. Two implications:
1. **Phase 9's new querymap confirm-keybinds MUST `:exec` the wrapper binaries** (or a script calling
   them), never reuse aerc's native `:delete-message`/`:archive` — else "confirm gesture feeds the
   IMAP-level wrapper, not just retags" (plan line 100) silently fails.
2. **Decide explicitly** whether the pre-existing `d`/`D`/`a`/`A` bindings are in scope — rebind/disable
   them to route through the wrapper+manifest flow, or document that human-operated aerc deletes remain
   outside the guardrail by design. Silence is itself the gap.

**Refinement (all 3 of A/B/C agree): mbsync `Remove Both`** is present **only** on `gmail-folders`
(catch-all, `mbsync.nix:83-84`) and the two Logos channels (154, 163) — **not** on the six primary
gmail channels (`gmail-inbox/sent/drafts/trash/all/spam`), which set only `Expunge Both`. The seed's
blanket "no Remove" claim should note this exception. No mbsync config change needed for Phase 2.

### Concrete plan bugs found (verified)

- **Phase 5 `mbsync -a` blast-radius (Teammate D, high confidence):** the thaw step runs `mbsync -a`
  (all groups), but `mbsync.nix` has independent `gmail` and `logos` groups and Phase 7 correctly uses
  `mbsync gmail`. A Gmail-only supervised purge would inadvertently sync the deferred Logos/Bridge
  account. **Fix: `mbsync gmail` (group-scoped) in Phase 5 too.**
- **`permissions.deny` has zero mail entries today (Teammate B):** the v3 plan's "keep the coarse
  `permissions.deny` backstop" describes entries to be **added**, not preserved — new surface, not a
  preservation task. Scope Phase 3 accordingly.

### Gaps Identified (carry into planning / verify first)

1. Re-run `notmuch new`; confirm index count ≈ 64,316 (CONFLICT 2). **Blocking for Phase 2/8.**
2. Empirically test the full two-hop delete path on one disposable message; verify server-side All Mail
   removal (CONFLICT 1 / Phase 7).
3. Rewrite the `invalid_grant` fail-safe against `mbsync`, not `himalaya` (CONFLICT 3).
4. Pin the manifest key: **Message-ID header, not Himalaya envelope id** (C finding 8). Load-bearing for
   the #803 handoff.
5. Decide aerc pre-existing-keybind scope; make Phase 9 keybinds `:exec` the wrapper (CONFLICT 4).
6. Research Google's Production-verification requirements/timeline for the restricted scope set before
   recommending "publish to Production" (C finding 7).
7. Resolve manifest-approval provenance: aerc review writes a new approved manifest of `+confirmed-*`
   IDs; mutation wrappers consume only that (A open question).
8. Confirm exact `notmuch address` invocation — bare form errors; needs a query term, e.g.
   `notmuch address --output=sender --output=count --deduplicate=address -- '*'` (A/C).

### Recommendations (net design for the plan)

- Proceed with the seed's architecture. **Correct the delete-invariant wording** (CONFLICT 1) and
  **re-target the OAuth fail-safe** (CONFLICT 3) in the plan's shared-invariants section.
- **New file** `modules/home/email/agent-tools.nix`; nix `let`-string preamble; 5 wrappers; JSONL +
  sha256 manifest; document the two-layer enforcement model.
- **Harden the contract cheaply now** (before nvim #803 / ~/Mail #29 consume it): reserve
  `--account gmail`; add a per-ID execution-status companion-state field for replay-safety; key
  manifests on Message-ID.
- **Phase 9**: querymap confirm-keybinds `:exec` the wrappers; settle the native-keybind question.
- **Phase 5**: `mbsync gmail`, and freeze must `pgrep mbsync` + check the actual systemd unit name (a
  timer-triggered oneshot vs. long-running service — locate the unit in `modules/home/email/` siblings).
- **Phase 0 handoff**: harvest data-only per B's table; write the "not harvestable" gap note; RETIRE the
  full file inventory; DISCARD checkbox UX + opus pin.
- Leave a **memory breadcrumb** for a future `confirmed-mutation-wrapper` pattern; do not build the
  framework now.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary — nix wrapper mechanism, hook, live Himalaya verification | completed | high |
| B | Alternatives — prior-art harvest/retire, adaptable tooling | completed | high (harvest), medium (tooling) |
| C | Critic — unverified premises, scope/dependency/OAuth gaps | completed | high (F2/3/4/6/7), medium-high (F1) |
| D | Horizons — reusability seams, contract hardening, blast-radius bug | completed | high (F1/2/4), medium-high (F3/5) |

## References

- Round-1 seed: `specs/072_.../reports/01_infrastructure-prereqs-seed.md`
- Teammate findings: `specs/072_.../reports/02_teammate-{a,b,c,d}-findings.md`
- Reference plan (v3): `specs/071_.../plans/04_email-workflow-implementation.md`
- Task 46 (OAuth): `specs/046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md`
- Live config verified by lead: `config/himalaya-config.toml` (`backend.type = "maildir"`, lines 6/23)
- Local config: `modules/home/email/{mbsync,notmuch,aerc,protonmail}.nix`,
  `modules/home/packages/email-tools.nix`, `docs/himalaya.md`, `.claude/settings.json`,
  `.claude/hooks/validate-meta-write.sh`
- Prior art: `~/Mail/.claude/{commands/email.md, skills/skill-email, agents/email-agent.md,
  scripts/email/*.py, context/project/email/email-preferences.md}`
- External (Teammate B): `planetaryescape/list-unsubscribe`, RFC 8058, `afew`, Terraform plan/apply,
  aerc-binds(5)

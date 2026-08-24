# Seed Report: AI-Assisted Email Management Workflow

**Task**: 71 — Design AI-assisted email management workflow
**Type**: general (with nix implementation surface)
**Status**: Seed report (preliminary — intended as a base for further `/research 71`)
**Date**: 2026-07-02
**Session**: sess_1783018733_e662d5

---

## 1. Purpose and Scope

This is a **seed report**, not a finished research artifact. It establishes the current
state of the machine's email tooling, surveys July-2026 best practices for AI-assisted
email management, and frames the key design decisions so that a follow-up `/research 71`
(or `/research 71 --team`) has a concrete foundation to build on.

**User goals** (in priority order):

1. **Backlog cleanup (largest task)**: delete all backlogged junk email, archive what is
   worth keeping, delete everything else.
2. **Ongoing inbox hygiene**: ask an agent to "clean up my inbox" (remove junk, unsubscribe
   noise) on a recurring basis.
3. **Drafting**: have an agent draft responses to emails as appropriate, for human review.

The central design question is **not** "which tool" but **"which access path drives which
task"** — because the two AI access paths available have fundamentally different capability
ceilings.

---

## 2. Current State (as installed)

The machine already has a mature, dual-account, offline-first email stack, fully declared in
the NixOS/home-manager config. Nothing new needs to be installed to begin — the gap is
**workflow design and a safe agent harness**, not tooling.

### 2.1 Accounts

| Account | Address | Transport | Auth |
|---------|---------|-----------|------|
| Gmail (default) | benbrastmckie@gmail.com | Gmail IMAP/SMTP | OAuth2 (XOAUTH2), keyring-backed, auto-refreshed every 45 min via systemd timer |
| Protonmail (Logos) | benjamin@logos-labs.ai | Protonmail Bridge (localhost:1143/1025) | Bridge password in keyring |

### 2.2 Local stack (declared in `modules/home/email/`)

| Layer | Tool | Role | Config file |
|-------|------|------|-------------|
| Sync | **mbsync (isync)** | Bidirectional IMAP ↔ Maildir++, custom-built with cyrus-sasl-xoauth2 | `email/mbsync.nix` → `~/.mbsyncrc` |
| Index/search | **notmuch** | Full-text index + tag database over `~/Mail`, auto-tags by folder/account on `notmuch new` | `email/notmuch.nix` |
| Scripting CLI | **Himalaya** (v1.2.0, Feb 2026) | "Commands in, text (JSON) out" — the agent-drivable client, built with `--features=oauth2,keyring` | `packages/email-tools.nix`, `~/.config/himalaya/config.toml` |
| Interactive TUI | **aerc** | Tabbed terminal UI over the notmuch backend, for human reading/triage/compose | `email/aerc.nix` |
| Send | **msmtp** | SMTP send helper | `packages/email-tools.nix` |

Mail lives locally in Maildir++ at `~/Mail/Gmail/` and `~/Mail/Logos/`. There is a
`gmail-inbox-quick` mbsync channel (MaxMessages 50) for fast partial syncs.

**Key observation**: Himalaya and aerc are **not redundant** — this matches 2026 best
practice. Himalaya is a real CLI (one command, prints, exits) that an agent can drive
reliably; aerc is an interactive TUI an agent would have to "puppet." The recommended
pattern is exactly what is installed: **aerc/NeoMutt for human reading, Himalaya for the
scripted/agent bits.** The user's uncertainty about having "another TUI tool" is resolved:
keep both; they occupy different roles.

### 2.3 The AI access path already connected: Anthropic Gmail connector

`~/.claude.json` shows `gmail.mcp.claude.com` — Anthropic's official managed **Gmail
connector** (part of the Google Workspace connectors). Critically, per Anthropic's docs and
2026 third-party reviews, this connector is **read-only plus draft-creation**:

- ✅ Search inbox in natural language, summarize threads, pull info across emails.
- ✅ Create **unsent drafts** in Gmail (with explicit approval).
- ❌ **Cannot send.** ❌ **Cannot archive.** ❌ **Cannot delete.** ❌ No attachment *content*
  (metadata only). Mirrors your existing Workspace permissions — no elevation.

**Implication — this is the pivotal finding:** the connector you have already wired up is
**structurally incapable of the user's #1 goal** (bulk delete/archive backlog). It is
excellent for triage/summarize/draft, useless for cleanup. The backlog task must be driven
through the **local stack** instead.

---

## 3. The Two Access Paths (the core architectural choice)

| Dimension | Path A: Anthropic Gmail connector (`gmail.mcp.claude.com`) | Path B: Local stack via agent (Himalaya + notmuch + mbsync) |
|-----------|-----------------------------------------------------------|-------------------------------------------------------------|
| Read/search/summarize | ✅ Native NL search | ✅ `himalaya envelope list`, `notmuch search` |
| Draft responses | ✅ Draft into Gmail (approval-gated) | ✅ `himalaya template`/draft files |
| **Send** | ❌ Disabled by design | ✅ via msmtp/Himalaya SMTP (must be gated) |
| **Archive / move** | ❌ | ✅ notmuch tags + mbsync, or `himalaya message move` |
| **Delete (backlog!)** | ❌ | ✅ move-to-Trash + expunge (Gmail semantics) |
| Both accounts (Gmail+Proton) | Gmail only | ✅ Both (Proton via Bridge) |
| Setup burden | Already connected | Already installed; needs an agent harness/skill |
| Blast radius / risk | Low (can't mutate) | **High** (shell + SMTP + delete power) → needs strict guardrails |

**Recommended division of labor** (to be validated in follow-up research):

- **Path A (connector)** → low-risk daily triage: "summarize what's important today,"
  "draft a reply to X." Zero destructive capability = safe to use liberally.
- **Path B (local, agent-driven)** → the backlog cleanup and any move/delete/send. This is
  where the real design work and safety engineering lives.

---

## 4. July-2026 Best Practices (survey)

Consistent themes across current sources:

1. **Reduce volume before automating.** Unsubscribe from high-volume senders first; route
   newsletters to folders/digests; protect VIP senders so triage never buries them. Rules do
   the predictable work; agents handle the messy residue.
2. **Hybrid rules + agent.** Deterministic filters (Gmail filters, notmuch tag rules) for
   the 80% that is mechanically classifiable; LLM judgment only for ambiguous mail.
3. **Least privilege + human-in-the-loop.** Start read-only; draft-only sending; audit logs;
   explicit human review for any external send or any deletion. This is the near-universal
   security posture in 2026 write-ups.
4. **Drafts-first workflow** (the published *Claude Himalaya skill* pattern): the agent
   writes replies as local template files and **prints the send/delete command without
   executing it**; the human approves before anything transmits or is destroyed. For bulk
   moves/deletes the agent must print the **complete ID list + destination**, wait for
   written approval, then execute per-ID.
5. **Treat message bodies as untrusted input** — prompt-injection vector. An agent reading
   attacker-controlled email must not treat body text as instructions.
6. **Gmail deletion semantics.** Gmail's proprietary IMAP means "delete" = move to
   `[Gmail]/Trash` then expunge; a raw `rm` on the maildir without the trash dance
   desyncs. **Turn off sync during bulk operations** to avoid race conditions, operate on
   notmuch queries/tags, then re-sync with `Expunge Both`.

### 4.1 Landscape of alternatives (for comparison, not necessarily adoption)

- **Managed SaaS cleaners**: SaneBox, Clean Email, Mailstrom, Leave Me Alone — strong at
  bulk unsubscribe/backlog, but hand a third party inbox access (privacy cost; conflicts
  with the self-hosted, keyring-secured posture already chosen).
- **AI email clients**: Shortwave, Superhuman, Spark, Mimestream (native Gmail), plus Gemini
  inside Workspace — faster UX, but GUI-centric and not scriptable from this NixOS/terminal
  workflow.
- **Gmail MCP servers (community, write-capable)**: e.g. VoltAgent/GongRzhe-style Gmail MCP
  servers expose send/delete/label to an agent via the Gmail API. These *can* do the backlog
  task through Path-A-style plumbing, but re-introduce OAuth scope + third-party trust
  questions and duplicate what the already-installed local stack does natively.

**Provisional lean**: prefer the **local stack (Path B)** for destructive work — it keeps
data on-device, reuses the existing OAuth/keyring/Bridge investment, and avoids granting a
new external service write access. Managed cleaners are a fallback only if the local agent
harness proves too slow for a one-time massive backlog purge.

---

## 5. Design Sketch for the Backlog Cleanup (largest task)

A candidate pipeline to pressure-test in follow-up research/planning:

1. **Freeze sync.** Stop timers/mbsync during the operation (avoid race conditions).
2. **Full local index.** `mbsync -a && notmuch new` so notmuch sees the entire backlog.
3. **Classify with notmuch queries** (cheap, deterministic first pass): senders, list-ids,
   age, folder. Bucket into `junk` (bulk senders, `list:` headers, promotions), `keep`
   (VIPs, threads you replied to, receipts), and `unsure`.
4. **Agent adjudicates the `unsure` bucket** in batches, proposing tag `+junk` / `+archive`
   / `+keep` — **printing IDs, never auto-acting.**
5. **Human approves** the tag sets (aerc is ideal for eyeballing a tagged view).
6. **Execute per bucket**: archive = retag/move to `All_Mail`/`Archive`; delete = move to
   Gmail Trash + `notmuch tag +deleted`, then re-enable sync with `Expunge Both` so the
   server reflects it.
7. **Unsubscribe pass**: extract `List-Unsubscribe` headers from the `junk` senders; agent
   drafts a batch (one-click/mailto), human confirms, to stop regrowth.
8. **Institutionalize**: convert the winning heuristics into standing Gmail filters +
   notmuch post-new tag rules so the inbox stays clean without re-running the big job.

---

## 6. Open Questions for Follow-up `/research 71`

1. **Harness form-factor**: a Claude Code **skill** (à la the published Himalaya skill), a
   set of `/email-*` slash commands, a nix-declared wrapper script, or a write-capable Gmail
   MCP server? Trade-offs: reproducibility, blast radius, latency for large backlogs.
2. **Approval UX**: how does the human review 500+ proposed deletions efficiently? (Tagged
   aerc view vs. a generated manifest file vs. batch prompts.)
3. **Both accounts or Gmail-first?** Protonmail-via-Bridge complicates the delete/expunge
   dance; scope the backlog job to Gmail first?
4. **Backlog scale**: how many messages, and does that push toward a one-time managed-cleaner
   assist vs. a purely local run? (Need a `notmuch count` census.)
5. **Guardrail enforcement**: how to *technically* prevent auto-send/auto-delete (not just
   policy) — deny-auto-approve for mail-touching bash, a send/delete wrapper that always
   requires a confirmation token, dry-run defaults.
6. **Junk classifier quality**: pure notmuch rules vs. LLM-in-the-loop — measure false-positive
   rate on `keep` before trusting deletion.
7. **Spam-injection hardening**: sandbox for treating email bodies as untrusted.

---

## 7. Recommendation Summary

- **Keep the installed stack** — Himalaya (scripting/agent) + aerc (human reading) is the
  correct 2026 pattern, not a redundancy to resolve.
- **Use the two access paths for what each can do**: Anthropic Gmail connector for safe
  read/summarize/draft; the **local stack for all destructive/backlog work**.
- **The backlog cleanup cannot go through the Anthropic connector** (no delete/archive) —
  design it as a **local, notmuch-driven, drafts-first, human-approved** pipeline.
- **Build a safe agent harness** (skill or slash-commands) whose defining property is
  hard guardrails: dry-run by default, print-IDs-then-approve, no auto-send, Gmail
  trash-then-expunge semantics, sync frozen during bulk ops.
- **Next step**: run `/research 71` (consider `--team` for a tools/security/UX split) to
  resolve the seven open questions, then `/plan 71`.

---

## 8. References

- [Himalaya CLI (pimalaya/himalaya)](https://github.com/pimalaya/himalaya)
- [Claude Himalaya Skill: Email from the Terminal (2026) — MCP.Directory](https://mcp.directory/blog/claude-himalaya-skill-guide)
- [Best email clients for developers 2026: TUI, scriptable, and honest](https://email-tools.me/posts/best-email-clients-developers/)
- [aerc — a pretty good email client](https://aerc-mail.org/)
- [Use Google Workspace connectors | Claude Help Center](https://support.claude.com/en/articles/10166901-use-google-workspace-connectors)
- [Gmail Connector | Claude by Anthropic](https://claude.com/connectors/gmail)
- [Claude + Gmail: What the Integration Can (and Can't) Do in 2026 — Carly](https://www.usecarly.com/blog/claude-gmail-integration/)
- [Gmail MCP Server — VoltAgent](https://voltagent.dev/mcp/gmail/)
- [How To Use AI Agents To Streamline Email Sorting — Forbes](https://www.forbes.com/sites/technology/article/how-to-use-ai-agents-for-emails/)
- [AI Agent for Email Management 2026 Guide — MoClaw](https://moclaw.ai/blog/ai-agent-for-email-management-2026-guide)
- [Best AI Email Assistants in 2026 — Lindy](https://www.lindy.ai/blog/ai-email-assistant)
- [Removing messages with notmuch — Tomáš Tomeček](https://blog.tomecek.net/post/removing-messages-with-notmuch/)
- [Sync mail deletion with Notmuch + mbsync for Gmail (notmuch mailing list)](https://notmuchmail.org/pipermail/notmuch/2016/023112.html)
- [7 Best Email Cleanup Tools in 2026 — Mailstrom](https://mailstrom.co/articles/best-email-cleanup-tools-2026/)

---

*Local config references: `modules/home/email/{mbsync,notmuch,aerc,protonmail}.nix`,
`modules/home/packages/email-tools.nix`, `docs/himalaya.md`, `~/.config/himalaya/config.toml`,
`~/.mbsyncrc`, `~/.claude.json` (gmail.mcp.claude.com connector).*

# Teammate B Findings: Security / Guardrails for AI-Assisted Email Management

**Task**: 71 — Design AI-assisted email management workflow
**Dimension**: Security / Guardrails (technical enforcement, not policy statements)
**Date**: 2026-07-02
**Session**: sess_1783019173_bf51f6 (team-research, teammate B)

---

## Key Findings

1. **Claude Code hooks give real, structural enforcement — not just documentation.** A `PreToolUse` hook with `matcher: "Bash"` runs *before every Bash call*, receives the literal command string on stdin, and can emit `permissionDecision: "deny"` to hard-block it regardless of whether the model "wants" to run it. This is materially different from `permissions.deny` alone, which is a static pattern match that historically has had enforcement bugs (see [anthropics/claude-code#18846](https://github.com/anthropics/claude-code/issues/18846)) and can be bypassed by command composition (subshells, `&&`, variable expansion). Hooks see the resolved command text and can be regex/keyword-based, so they are the correct primary mechanism for gating `himalaya message send`, `msmtp`, `mbsync ... Expunge`, and `rm ~/Mail/...`.

2. **The published Claude Himalaya skill already encodes the exact "drafts-first, print-then-approve" pattern the seed report described** — confirmed via [mcp.directory/blog/claude-himalaya-skill-guide](https://mcp.directory/blog/claude-himalaya-skill-guide). Its own documentation is explicit that the approval gate is a **procedural convention layered on top of, not a substitute for, technical blocking**: *"don't auto-approve Bash commands in sessions that touch mail."* This is the seam this project should close — the published skill relies on the agent's good behavior plus a CLAUDE.md instruction; this repo's existing hooks infrastructure (see `.claude/settings.json` `PreToolUse`/`PostToolUse` blocks, already using `permissionDecision` JSON) can upgrade that convention into an enforced control.

3. **Gmail's non-standard IMAP semantics make "delete" itself a two-step, syncable action** — moving a message to `[Gmail]/Trash` gives a ~30-day undo window; only a subsequent `Expunge` (locally or via Gmail's own retention) makes it unrecoverable. Because mbsync mirrors deletions bidirectionally, running bulk delete/mutate operations *while mbsync's systemd timer is active* creates a race window where a local mistake (or partial notmuch tag operation) can propagate to the server before a human reviews it. Freezing sync (stopping the timer, confirming no `mbsync` process is running) for the duration of the bulk operation is a cheap, load-bearing control, not a nicety.

4. **The "lethal trifecta" (Willison) applies directly and unconditionally to this design**: the agent has (a) private data — the mailbox and keyring-backed credentials, (b) untrusted content — every email body/subject is attacker-controllable, and (c) an exfiltration path — SMTP send, or even crafting an outbound HTTP fetch if any tool permits it. Per Willison's own framing, once all three are present *"it's vulnerable, period"* — the only reliable mitigation is breaking one leg of the triangle, not adding a percentage-based filter. For this workflow, the practical leg to break is (c) constrained: no action with external effect (send, forward, unsubscribe-click) may be triggered directly by content the agent read from a message body; it must always pass through a human-approved, out-of-band confirmation step that is not itself influenceable by the email content.

5. **Credential blast radius is asymmetric between the two access paths already identified in the seed report.** An agent with shell access can run `secret-tool lookup ...` against libsecret/gnome-keyring and, if it can read the OAuth token or Bridge password, could act as the account outside of Claude Code's own tool-call visibility (e.g., construct a raw `curl` against the Gmail API, or feed the password to a script). This is a strict superset of what the connector's scoped, read-plus-draft-only OAuth grant can do. This structurally reinforces the seed report's Path A/Path B split: the read-only connector is the *lower-blast-radius default* for daily triage precisely because it cannot reach the keyring or shell at all, while the local stack (Path B) needs the guardrails in this report specifically because it is not sandboxed away from credential material.

6. **Dry-run-by-default is a well-established, load-bearing CLI safety pattern directly applicable to any wrapper scripts this project builds** (Terraform plan/apply, Ansible `--check`, `kubectl --dry-run=client`): the destructive path should require an explicit, hard-to-fat-finger flag (e.g., `--execute`, not just the absence of `--dry-run`), so that a misconfigured or automated invocation defaults to safe.

7. **Auditability is cheap to add and directly supports the undo story**: since Gmail Trash already provides a ~30-day recoverability window, the missing piece is a durable, human-reviewable record of *what the agent proposed and what was approved* — a git-tracked manifest (message IDs, subjects, senders, action, approval timestamp) gives a second, independent undo/audit trail that survives past the Trash window and is diffable in the same repo that already tracks this machine's configuration.

---

## Recommended Approach

### 1. Enforcement layer: hooks, not just `permissions.deny`

Use both, in this order of trust:

- **`permissions.deny` in `settings.json`** as a coarse, always-on backstop (this repo's own global `~/.claude/settings.json` already shows the pattern: `"deny": ["Bash(rm -rf /)", "Bash(sudo *)", ...]`). Add mail-specific entries:
  ```json
  "deny": [
    "Bash(himalaya message send*)",
    "Bash(himalaya template send*)",
    "Bash(msmtp*)",
    "Bash(mbsync*Expunge*)",
    "Bash(rm*~/Mail*)",
    "Bash(rm*Maildir*)"
  ]
  ```
  This blocks the *naive* invocation shape, but is defeatable by quoting/variable tricks and does not have full visibility into compound commands — treat it as a tripwire, not the control.

- **A `PreToolUse` hook (matcher: `Bash`)** as the actual enforcement point. Per the official [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks), the hook receives `tool_input.command` as the *resolved* string, so it can pattern-match regardless of quoting, and return a structured JSON decision:
  ```bash
  #!/bin/bash
  # .claude/hooks/mail-guard.sh
  CMD=$(jq -r '.tool_input.command')
  if echo "$CMD" | grep -qE 'himalaya (message|template) send|msmtp|mbsync.*Expunge|rm .*Mail'; then
    if ! echo "$CMD" | grep -q "CONFIRMED:"; then
      jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
        permissionDecisionReason:"Mail-mutating command requires an explicit CONFIRMED: token appended after human review of the printed manifest."}}'
      exit 0
    fi
  fi
  exit 0
  ```
  This mirrors the exact mechanism already deployed in this repo's own `.claude/settings.json` (`PreToolUse`/matcher `Write` hooks emitting `permissionDecision` JSON), so no new infrastructure pattern needs to be invented — only a new hook script and matcher entry.

- **Confirmation token, not just approval prose.** Rather than relying on the agent "remembering" it got a human's go-ahead (which is exactly the seam prompt injection can exploit — injected mail content could try to make the agent believe it was approved), require the *executed command itself* to carry a token the hook checks for (e.g., a per-session nonce the human types back, or a `--confirm-manifest <sha256-of-printed-list>` flag). This converts "the agent claims it was approved" into "the shell command is structurally incapable of running without the token," which is verifiable by the hook without trusting the agent's self-report.

### 2. Drafts-first + print-IDs-then-approve, technically anchored

Adopt the published Himalaya skill's workflow ([mcp.directory/blog/claude-himalaya-skill-guide](https://mcp.directory/blog/claude-himalaya-skill-guide)) as the interaction pattern, but anchor its two "hard rules" in the hook above instead of only in CLAUDE.md prose:
- Single-message drafts: agent writes `/tmp/reply-<id>.txt` or a task-scoped scratch path, prints the exact `himalaya template send < file` command, does not execute.
- Bulk operations: agent must print the **complete ID list + destination/action** (as a file, not just chat text, so it can be diffed/git-tracked — see Auditability below), then only issue per-ID execute commands carrying the confirmation token, and only for IDs present in the approved manifest (the hook or a small wrapper script should diff the executed ID against the approved manifest file, not just check for a token, to prevent a compromised/confused agent from re-using one approval to cover a different, larger set of IDs).

### 3. Dry-run-by-default wrapper scripts

Any nix-declared or ad hoc wrapper script for bulk tag/move/delete should:
- Default to `--dry-run` (or have no execute mode at all without the flag) and write a manifest file (message IDs, current tag/folder, proposed tag/folder, reason) instead of mutating anything.
- Require a distinct `--execute` flag (not `--no-dry-run`, to avoid double-negative typos) that only works when pointed at a manifest file that already exists on disk (i.e., execute mode consumes a previously generated, human-reviewed file rather than re-deriving the ID list itself — this closes the gap between "what was shown" and "what runs").

### 4. Gmail delete safety + sync freeze

- Never target hard delete. All delete operations should move to `[Gmail]/Trash` (Himalaya `message move` / notmuch tag + mbsync `Expunge Both` only on the *server-acknowledged* Trash state), preserving the ~30-day Gmail-side recovery window as a second safety net beyond the git manifest.
- Before any bulk operation: `systemctl --user stop mbsync.timer` (or the unit name declared in `modules/home/email/mbsync.nix`), confirm no in-flight `mbsync` process (`pgrep mbsync`), operate purely against the local notmuch/Maildir snapshot, then re-enable the timer and run a single explicit `mbsync -a` with `Expunge Both` afterward so server state converges deliberately, not via a background race.

### 5. Prompt-injection hardening

- Treat every email **Subject**, **body**, and **List-Unsubscribe**/header value the agent reads as data, never as instructions — this must be an explicit statement in the skill/CLAUDE.md context passed to the agent (data/instruction separation), reinforced structurally by the fact that no tool call the agent can make in response to reading mail is allowed to execute without passing back through the human-approval + token gate above. This directly implements the mitigation in Willison's lethal-trifecta framing: break the exfiltration/action leg, don't try to filter the untrusted-content leg.
- Concretely: the classification/adjudication pass (bucketing into junk/keep/unsure) may read bodies and propose tags, but the tagging/deletion *execution* step must never be a direct causal continuation of "the email told me to..." — it must always restart from the human-approved manifest file, which is inert data, not live instructions.
- Do not let the agent auto-click or auto-fetch `List-Unsubscribe` URLs found in bodies (this is itself an exfiltration/action vector driven by untrusted content) — draft the unsubscribe batch for human confirmation, per the seed report's step 7.

### 6. Credential / keyring scope minimization

- Keep the Anthropic Gmail connector (read + draft-only, scoped OAuth, no keyring/shell reach) as the default daily-use surface specifically because it cannot reach `secret-tool` or execute shell commands — this is a structural, not just policy, containment boundary.
- For the local stack, there is no practical way to hide the OAuth token/Bridge password from an agent with shell access short of running the agent in a restricted user/container without keyring access and proxying only the mail commands it needs — flag this as a design trade-off for the planning phase (e.g., consider a dedicated low-privilege service account or a sandboxed exec wrapper that the agent can only invoke through Himalaya's own subcommands, never via raw `secret-tool`).
- At minimum, add `Bash(secret-tool*)` to the deny list / hook pattern for the email-management skill's tool context, since there is no legitimate reason for the agent's own commands to invoke `secret-tool` directly — Himalaya and mbsync already do that internally via their own configured keyring integration.

### 7. Auditability

- Log every mail-mutating command (the hook script above is a natural place to append to `~/Mail/.agent-audit.log` or a task-scoped log before allowing execution) with timestamp, full command, and the approved-manifest hash it satisfied.
- Git-track the approval manifests themselves (e.g., commit the "delete batch N — IDs + reasons + approval timestamp" file into the task's `specs/071_.../` artifacts or a dedicated `~/Mail/manifests/` repo) so there is a diffable, permanent record of what was deleted/archived independent of Gmail's 30-day Trash window.

---

## Evidence/Examples

- This repo's own `.claude/settings.json` already implements the exact `PreToolUse` → `permissionDecision` JSON pattern recommended above (see `matcher: "Write"` hook emitting `{"permissionDecision": "allow", ...}` conditionally on file path), confirming this is a proven, in-repo mechanism, not a speculative one.
- Global `~/.claude/settings.json` shows the working `permissions.deny`/`allow` array syntax (`"Bash(rm -rf /)"`, `"Bash(sudo *)"`) that the mail-specific deny patterns above should extend.
- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks): documents the full `PreToolUse` input schema (`tool_name`, `tool_input.command`), the `hookSpecificOutput.permissionDecision` values (`allow`/`deny`/`ask`/`defer`), and that exit code 2 vs. exit-0-with-JSON are different control paths — exit 0 with JSON is the correct mechanism for structured deny decisions.
- [anthropics/claude-code#18846](https://github.com/anthropics/claude-code/issues/18846): documents that raw `permissions.deny` Bash pattern matching has had real enforcement gaps, which is why the hook is described as the primary control and the deny-list as a backstop.
- [Claude Himalaya Skill guide (mcp.directory)](https://mcp.directory/blog/claude-himalaya-skill-guide): source of the drafts-first pattern and the explicit quote "don't auto-approve Bash commands in sessions that touch mail" plus the bulk-delete hard rule ("nothing from a human sender goes on the list ... you run `himalaya message delete <id>` only after I approve the list").
- [Simon Willison, "The lethal trifecta for AI agents"](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/): definition of the three properties and the framing that email is "a perfect source of untrusted content" because "an attacker can literally email your LLM and tell it what to do."
- Gmail IMAP/Trash/expunge mechanics: [notmuchmail.org pipermail thread on mbsync + Gmail deletion](https://notmuchmail.org/pipermail/notmuch/2016/023112.html) and 2026 recovery-window write-ups confirming the ~30-day Trash recoverability and the need to disable auto-expunge for safety.
- Dry-run-by-default precedent: Terraform plan/apply, Ansible `--check`, `kubectl --dry-run=client`, as surveyed in ["Why every script needs a dry-run flag" (2026)](https://danieljamesglover.com/blog/2026-02-01-dry-run-engineering-practice/).
- Least-privilege OAuth framing for the Anthropic connector: 2026 Google Workspace connector guidance recommending scoped, read-only-first connection ("connect one surface at a time with least-privilege, read-only scopes and prove value before adding the next").
- libsecret/`secret-tool` mechanics confirming shell-level lookup capability: [GNOME Keyring — ArchWiki](https://wiki.archlinux.org/title/GNOME/Keyring), [Projects/Libsecret — GNOME Wiki](https://wiki.gnome.org/Projects/Libsecret).

---

## Confidence Level

**Medium-High.**

- High confidence: the Claude Code hooks mechanism (schema, `permissionDecision` values, exit-code semantics) — directly confirmed against official docs and cross-checked against this repo's own working `settings.json` hooks, which use the identical pattern today.
- High confidence: the lethal trifecta framing and its applicability to email agents — directly sourced from Willison's original post with an explicit email example.
- High confidence: Gmail Trash/expunge recoverability semantics and the value of freezing sync — corroborated by multiple independent sources (notmuch mailing list, general Gmail recovery documentation) and consistent with the seed report's own findings.
- Medium confidence: the published Claude Himalaya skill's *exact* internal implementation details (I relied on a third-party blog summary of it, not the skill's raw source/manifest, so specific file paths or command names in that skill may differ slightly from what's quoted here — worth a direct fetch of the skill repo during planning if exact reproduction matters).
- Medium confidence: the credential/keyring blast-radius section is reasoned from general `secret-tool`/libsecret mechanics plus this project's known architecture (per the seed report), not from a source that specifically analyzes "AI agent + local keyring" risk — this is inference, clearly flagged as such above, and should be validated against this machine's actual `~/.config/himalaya/config.toml` keyring integration during planning.
- The specific hook script shown above is illustrative, not tested against this repo's Himalaya/mbsync command syntax — planning/implementation should verify exact command patterns (e.g., confirm actual mbsync channel names, `himalaya` v1.2.0 subcommand spelling) before finalizing the regex.

---

## References

- [Claude Code Hooks reference (official docs)](https://code.claude.com/docs/en/hooks)
- [BUG: Bash permissions in settings.json not enforced — requires custom hook workaround (anthropics/claude-code#18846)](https://github.com/anthropics/claude-code/issues/18846)
- [Claude Himalaya Skill: Email from the Terminal (2026) — MCP.Directory](https://mcp.directory/blog/claude-himalaya-skill-guide)
- [The lethal trifecta for AI agents — Simon Willison's Newsletter](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- [The lethal trifecta for AI agents (Substack mirror)](https://simonw.substack.com/p/the-lethal-trifecta-for-ai-agents)
- [Defend against indirect prompt injection attacks — Microsoft Learn](https://learn.microsoft.com/en-us/security/zero-trust/sfi/defend-indirect-prompt-injection)
- [LLM Prompt Injection Prevention — OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
- [Sync mail deletion with Notmuch + mbsync for Gmail (notmuchmail.org pipermail)](https://notmuchmail.org/pipermail/notmuch/2016/023112.html)
- [How to Recover Deleted Emails in Gmail (Trash, Permanent, Workspace, 2026) — Carly](https://www.usecarly.com/blog/how-to-recover-deleted-emails-in-gmail/)
- [Why every script needs a dry-run flag — Daniel J Glover (2026)](https://danieljamesglover.com/blog/2026-02-01-dry-run-engineering-practice/)
- [How to Connect Claude to Google Workspace: Drive, Gmail & Calendar — Vantage Point](https://vantagepoint.io/blog/ai/connect-claude-to-google-workspace)
- [The Hidden Risk of Connecting Claude to Your Gmail Account — Wayne Rodrigues, Medium](https://waynerod10.medium.com/the-hidden-risk-of-connecting-claude-to-your-gmail-account-49805d415fc1)
- [GNOME/Keyring — ArchWiki](https://wiki.archlinux.org/title/GNOME/Keyring)
- [Projects/Libsecret — GNOME Wiki Archive](https://wiki.gnome.org/Projects/Libsecret)
- Local evidence: `/home/benjamin/.dotfiles/.claude/settings.json` (`PreToolUse`/`PostToolUse` hooks using `permissionDecision` JSON), `~/.claude/settings.json` (`permissions.allow`/`deny` array syntax)

---

*Prepared as Teammate B (Security/Guardrails) findings for task 71's team research round. See `01_ai-email-workflow.md` (seed report) for architecture/tool-mechanics context and Teammate A's findings for the complementary tool-mechanics dimension.*

# Teammate A Findings: Wrapper Mechanism Implementation (nix + bash)

**Task**: 72 (.dotfiles) — email workflow infrastructure/prerequisites
**Round**: 2 (team) — Teammate A, PRIMARY ANGLE: nix wrapper mechanism implementation
**Date**: 2026-07-02
**Builds on**: reports/01_infrastructure-prereqs-seed.md (§2 Shared Invariants, §4 wrapper contract)

---

## Key Findings

1. **Live-verified: Himalaya v1.2.0's `message delete` is textually confirmed to be the
   "soft move to Trash" the seed report claims** — not an assumption. `himalaya message delete
   --help` (run live) states verbatim: *"This command does not really delete the message: if the
   given folder points to the trash folder, it adds the 'deleted' flag to its envelope, otherwise
   it moves it to the trash folder. Only the expunge folder command truly deletes messages."* This
   directly confirms seed report §3 Phase 2 and the wrapper contract's two-step delete
   (`message delete` → `[Gmail].Trash` via `folder.alias.trash` in `docs/himalaya.md:207`, then
   `folder expunge Trash`). **Confidence: high.**

2. **`Expunge Both` without `Remove` on `gmail-inbox`/`gmail-all`/etc. is confirmed live** in
   `modules/home/email/mbsync.nix:29,37,47,54,61,68,75,83` — every Gmail channel sets `Expunge Both`
   but the `Remove` directive only appears on `gmail-folders` (line 84) and the Logos
   `logos-labels`/`logos-folders` channels (lines 154, 163). This matters operationally:
   `Expunge Both` propagates the **`\Deleted` IMAP flag** (i.e., messages moved into `[Gmail].Trash`
   by Himalaya sync down/up correctly), but it does NOT delete/reconcile *folders themselves* on the
   core channels — that's what `Remove` controls and it is deliberately absent there (folder
   deletion isn't wanted for `INBOX`/`All_Mail`/`Trash` etc.). This is correct-as-is for the
   wrapper's needs; no mbsync config change is required for Phase 2, only for Phase 5
   (freeze/thaw doesn't touch channel directives) — **the seed report's flag for "review during
   implementation" can be resolved now: no change needed.** **Confidence: high.**

3. **There is no existing shared-bash-library pattern in this repo's `writeShellScriptBin` usage.**
   Every existing wrapper (`modules/home/scripts/{gmail-oauth2,memory-monitor,sioyek-theme,whisper}.nix`)
   inlines its full script body in a single `''...''` string; none use `pkgs.writeShellApplication`
   or an external `source`d lib file (`writeShellApplication` appears only in unrelated research
   docs, never in `modules/`). This means Teammate A's design (below) — a Nix `let`-bound bash
   string interpolated into each of the 5 `writeShellScriptBin` calls — is the path of least
   surprise and keeps each produced binary self-contained (a real requirement for the mail-guard
   hook, which allowlists by binary name/path with no external file to tamper). **Confidence: high**
   (verified by grep across `modules/`).

4. **`himalaya envelope list -o json`** (not `message list`) is the correct read subcommand;
   `himalaya message list` does not exist as of v1.2.0 (`himalaya message --help` lists
   `read/export/thread/write/reply/forward/edit/mailto/save/send/copy/move/delete`, no `list`).
   The seed report's mention of `himalaya envelope list -o json` (§3 Phase 2) is correct; anywhere
   plan v3 or extension docs say `message list` should be corrected to `envelope list`.
   **Confidence: high** (live `--help` output).

5. **The plan's ownership line already puts wrapper scripts at
   `modules/home/packages/email-tools.nix` (extend) OR a new `modules/home/email/agent-tools.nix`**
   (plan line 113). Given `email-tools.nix` currently only declares `home.packages` (raw package
   list, no `writeShellScriptBin`, see `modules/home/packages/email-tools.nix:1-41`), and
   `modules/home/email/*.nix` is the pattern for behavior/config modules (mbsync, notmuch, aerc,
   protonmail), **a new `modules/home/email/agent-tools.nix` is the better fit** — it keeps
   `email-tools.nix` as pure package-list (its established role) and colocates the wrapper
   *mechanism* with the other `modules/home/email/*.nix` behavioral modules it depends on
   (mbsync channel names, notmuch tag vocabulary, aerc archive target). **Confidence: high.**

---

## Recommended Approach

### 1. Module structure: `modules/home/email/agent-tools.nix`

Use a single Nix file with:
- A `let`-bound **shared preamble string** (`commonPreamble`) containing arg-parsing helpers
  (`--execute`, `--confirm-manifest <hash>`, `--help`), the dry-run banner, and a
  `verify_manifest()` bash function. This string is interpolated (`${commonPreamble}`) at the top
  of every `writeShellScriptBin` body that needs mutation-gating (`email-archive-confirmed`,
  `email-delete-confirmed`); read-only tools (`email-census`, `email-classify`,
  `email-unsubscribe-extract`) use a smaller `readonlyPreamble` (just `--help`/`--output` parsing).
- Five `pkgs.writeShellScriptBin` derivations, each producing exactly one binary on `$PATH` via
  `home.packages`.
- A `MANIFEST_DIR` constant pointing at `specs/071_design_ai_email_management_workflow/manifests/`
  (per plan line 124-125) — but note **wrapper scripts run outside any git worktree context** (a
  human or agent could invoke them from `~`), so the manifest path should be resolved via an
  environment variable (`EMAIL_MANIFEST_DIR`, default `$HOME/.dotfiles/specs/071_.../manifests`)
  rather than assuming CWD. This is a gap in plan v3 worth flagging to the planner.

```nix
# modules/home/email/agent-tools.nix
# Dry-run-by-default wrapper scripts for AI-assisted Gmail cleanup (task 71/72).
# Every mutating wrapper requires --execute + --confirm-manifest <sha256>.
# See specs/072_email_workflow_infrastructure_prereqs/reports/01_infrastructure-prereqs-seed.md §2.
{ pkgs, ... }:
let
  manifestDirDefault = "$HOME/.dotfiles/specs/071_design_ai_email_management_workflow/manifests";

  # Sourced (via string interpolation, not `source`) into every mutating wrapper.
  # Provides: --execute / --confirm-manifest parsing, dry-run banner, manifest-hash
  # verification, and the "diff executed IDs against approved manifest" helper.
  mutationPreamble = ''
    set -euo pipefail

    MANIFEST_DIR="''${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"
    EXECUTE=false
    CONFIRM_HASH=""
    MANIFEST_FILE=""

    usage() {
      echo "Usage: $(basename "$0") --manifest <file> [--execute --confirm-manifest <sha256>]"
      echo "  Dry-run (default): prints the manifest contents and the sha256 that"
      echo "  --confirm-manifest must match to execute."
      exit "''${1:-0}"
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --manifest) MANIFEST_FILE="$2"; shift 2 ;;
        --execute) EXECUTE=true; shift ;;
        --confirm-manifest) CONFIRM_HASH="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) echo "Unknown argument: $1" >&2; usage 1 ;;
      esac
    done

    [ -n "$MANIFEST_FILE" ] || { echo "ERROR: --manifest <file> is required" >&2; exit 1; }
    [ -f "$MANIFEST_FILE" ] || { echo "ERROR: manifest not found: $MANIFEST_FILE" >&2; exit 1; }

    ACTUAL_HASH=$(sha256sum "$MANIFEST_FILE" | ${pkgs.gawk}/bin/awk '{print $1}')

    if [ "$EXECUTE" = false ]; then
      echo "[DRY RUN] Manifest: $MANIFEST_FILE"
      echo "[DRY RUN] sha256: $ACTUAL_HASH"
      echo "[DRY RUN] Re-run with: $(basename "$0") --manifest $MANIFEST_FILE --execute --confirm-manifest $ACTUAL_HASH"
      # Read-only tools continue past this block; mutation tools exit here.
    fi

    if [ "$EXECUTE" = true ]; then
      [ -n "$CONFIRM_HASH" ] || { echo "ERROR: --execute requires --confirm-manifest <sha256>" >&2; exit 1; }
      if [ "$CONFIRM_HASH" != "$ACTUAL_HASH" ]; then
        echo "ERROR: --confirm-manifest ($CONFIRM_HASH) does not match current manifest hash ($ACTUAL_HASH)." >&2
        echo "The manifest file changed since it was approved, or the wrong hash was passed. Refusing to execute." >&2
        exit 1
      fi
    fi
  '';
in
{
  home.packages = [

    # --- READ-ONLY: email-census ---------------------------------------
    (pkgs.writeShellScriptBin "email-census" ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Read-only: sender counts, folder/age buckets, List-Unsubscribe presence.
      # Never writes tags, never touches IMAP mutation state.

      echo "== Sender counts (top 30) =="
      ${pkgs.notmuch}/bin/notmuch address --output=sender --output=count \
        --deduplicate=address -- '*' | sort -rn -k1 | head -30

      echo
      echo "== Folder counts =="
      for f in inbox sent drafts trash all spam; do
        n=$(${pkgs.notmuch}/bin/notmuch count -- "folder:Gmail/.$f" 2>/dev/null || echo 0)
        printf '%-10s %s\n' "$f" "$n"
      done

      echo
      echo "== Envelope sample (JSON, first 20 INBOX) =="
      himalaya envelope list -o json | ${pkgs.jq}/bin/jq '.[:20]'
    '')

    # --- READ-ONLY (writes local provisional tags): email-classify -----
    (pkgs.writeShellScriptBin "email-classify" ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Deterministic-first classification. Writes +proposed-{delete,archive,unsure}
      # notmuch tags and emits a JSONL manifest. NEVER touches IMAP. NEVER auto-junks
      # low-confidence senders (recall-on-keep ~100%: default bucket is unsure).
      MAX_BATCH_SIZE=50   # harvested from ~/Mail/.claude/scripts/email/email_execute.py:26

      OUT="''${1:?usage: email-classify <output-manifest.jsonl>}"
      : > "$OUT"

      # Deterministic rule pass (List-Unsubscribe / precedence:bulk / sender-domain).
      ${pkgs.notmuch}/bin/notmuch search --output=messages \
        -- 'tag:inbox and (header:List-Unsubscribe:* or header:Precedence:bulk)' \
        | head -n "$MAX_BATCH_SIZE" \
        | while read -r id; do
            himalaya envelope list -o json "id:$id" 2>/dev/null \
              | ${pkgs.jq}/bin/jq -c '.[0] | {
                  id: .id, sender: .from.addr, subject: .subject, date: .date,
                  proposed_action: "delete",
                  reason: "list-unsubscribe/precedence-bulk"
                }' >> "$OUT"
            ${pkgs.notmuch}/bin/notmuch tag +proposed-delete -- "id:$id"
          done

      echo "Wrote $(wc -l < "$OUT") proposals to $OUT"
    '')

    # --- MUTATING: email-archive-confirmed ------------------------------
    (pkgs.writeShellScriptBin "email-archive-confirmed" ''
      #!/usr/bin/env bash
      ${mutationPreamble}
      [ "$EXECUTE" = false ] && exit 0

      # Diff: only act on IDs present in the approved manifest. Never re-derive
      # the candidate set from live rules at execute time.
      ${pkgs.jq}/bin/jq -r 'select(.proposed_action == "archive") | .id' "$MANIFEST_FILE" \
        | while read -r id; do
            himalaya message move All_Mail "$id" --folder INBOX
            ${pkgs.notmuch}/bin/notmuch tag +confirmed-archive -proposed-archive -- "id:$id"
          done
      echo "Archived $(${pkgs.jq}/bin/jq -r 'select(.proposed_action == "archive") | .id' "$MANIFEST_FILE" | wc -l) messages."
    '')

    # --- MUTATING (dangerous): email-delete-confirmed -------------------
    (pkgs.writeShellScriptBin "email-delete-confirmed" ''
      #!/usr/bin/env bash
      ${mutationPreamble}
      [ "$EXECUTE" = false ] && exit 0

      # IMAP-level delete ONLY. Never local Maildir rm, never notmuch-tag+Expunge
      # (Gmail All_Mail retains the message either way — see seed report §2.2).
      DELETE_IDS=$(${pkgs.jq}/bin/jq -r 'select(.proposed_action == "delete") | .id' "$MANIFEST_FILE")

      for id in $DELETE_IDS; do
        # Step 1: soft-move to [Gmail].Trash (himalaya alias "trash").
        himalaya message delete --folder INBOX "$id" \
          || { echo "invalid_grant" | grep -qi "$?" && { echo "OAuth failure, halting. Manifest preserved: $MANIFEST_FILE" >&2; exit 2; }; }
      done

      echo "Moved $(echo "$DELETE_IDS" | wc -w) messages to Trash. Run 'himalaya folder expunge Trash' after human approval to finalize."
      # NOTE: expunge is a SEPARATE, explicitly separate approval step (plan v3
      # Phase 7/10) -- this wrapper does not auto-expunge.
    '')

    # --- READ-ONLY: email-unsubscribe-extract ---------------------------
    (pkgs.writeShellScriptBin "email-unsubscribe-extract" ''
      #!/usr/bin/env bash
      set -euo pipefail
      # Extracts List-Unsubscribe headers per sender to a review list.
      # NEVER auto-fetches/POSTs the URL (exfil/lethal-trifecta vector).
      ${pkgs.notmuch}/bin/notmuch search --output=messages -- 'header:List-Unsubscribe:*' \
        | while read -r id; do
            himalaya envelope list -o json "id:$id" 2>/dev/null \
              | ${pkgs.jq}/bin/jq -c '.[0] | {id, sender: .from.addr}'
          done
    '')
  ];
}
```

**Notes on the skeleton above**:
- `mutationPreamble` is interpolated, not sourced at runtime — the resulting binary is a single
  self-contained script in the nix store, so the mail-guard hook (below) can allowlist it purely
  by binary path/name with no risk of the shared logic being edited out-of-band.
- `email-classify` and `email-census` are illustrative; exact notmuch query syntax
  (`header:List-Unsubscribe:*`) should be verified against the live `notmuch search-terms(7)` man
  page during Phase 2 implementation — I did not have a populated notmuch index to test against
  live in this research pass. **This is a verification gap, not a correctness claim.**
  **Confidence: medium** on the exact notmuch query strings; **high** on the overall structure.

### 2. Manifest schema + confirmation-token mechanics

**Format: JSONL (one JSON object per line)**, not a single JSON array. Rationale: JSONL is
`jq -c` / `grep` / `wc -l` friendly for streaming diff-against-approved logic in bash without a
full JSON parse of a potentially 10k+-line manifest for the residual `unsure` bucket sample; it is
also append-safe for resumable/batched runs (Postmortem rule 4/plan Phase 10).

```jsonl
{"id":"482913","sender":"newsletter@example.com","subject":"Weekly digest #212","date":"2026-06-28T09:00:00Z","proposed_action":"delete","reason":"list-unsubscribe+precedence-bulk"}
{"id":"482920","sender":"receipts@vendor.com","subject":"Your order shipped","date":"2026-06-29T14:22:00Z","proposed_action":"archive","reason":"sender-domain-keep-not-inbox-worthy"}
```

Required fields (matches seed report §4 handoff table exactly): `id`, `sender`, `subject`, `date`,
`proposed_action` (enum: `delete`|`archive`|`unsure`|`keep`), `reason` (free text,
human-readable). Recommend adding an optional `batch` field (integer) for the Phase 8
sampling/clustering tier's resumability, though this is additive and not load-bearing for Phase 2.

**Confirmation-token mechanics** (bash, exact commands):

```bash
# Generate the hash a human/agent would review before approving:
sha256sum manifest.jsonl
# -> e30f...  manifest.jsonl

# The wrapper computes the SAME hash internally and compares:
ACTUAL_HASH=$(sha256sum "$MANIFEST_FILE" | awk '{print $1}')
[ "$CONFIRM_HASH" = "$ACTUAL_HASH" ] || { echo "hash mismatch, refusing"; exit 1; }
```

This is deliberately `sha256sum` over the **raw manifest file bytes**, not a re-serialization or
re-derivation of its contents — any edit to the manifest (even reordering lines) changes the hash,
which is the desired "diff executed IDs against the approved manifest, never re-derive" property
(Postmortem rule 4). The human reviews the dry-run's printed hash, then re-invokes with
`--confirm-manifest <that hash>`. **Confidence: high** (standard, verified `sha256sum` semantics;
no live-system dependency).

One gap versus plan v3: the plan doesn't specify **who computes the manifest** for
`email-archive-confirmed`/`email-delete-confirmed` — it's produced by `email-classify` (dry-run,
read-only) and then presumably hand-edited/filtered via the Phase 9 aerc review before being
passed as `--manifest`. The wrapper contract should state explicitly that the manifest consumed by
the mutation wrappers is a **human-approved subset** of `email-classify`'s output (i.e., aerc's
confirm gesture filters the JSONL down to only `+confirmed-*` tagged IDs and writes a new,
approved manifest file) — not the raw classify output. This should be confirmed with the planner;
it affects the aerc keybind design (Phase 9) which must *write a manifest file*, not just retag.

### 3. PreToolUse mail-guard hook

**Location** (per plan v3, NOT `.dotfiles`): authored in
`~/.config/nvim/.claude/extensions/email/hooks/mail-guard.sh`, installed into
`.dotfiles/.claude/hooks/mail-guard.sh` via the `<leader>al` loader + `provides.hooks` +
`merge_targets.settings` (plan lines 375-384). This repo's existing hooks
(`.claude/hooks/validate-meta-write.sh`, `claude-stop-notify.sh`) confirm the shape: a bash script
reading JSON from **stdin** (not just `$CLAUDE_TOOL_INPUT` env var — `validate-meta-write.sh:11-20`
shows the robust pattern of falling back from stdin to env var) and printing a JSON response to
stdout.

**Matcher**: `"matcher": "Bash"` in `PreToolUse` (this repo's existing PreToolUse hooks use
`"matcher": "Write"` for file-path checks — `.claude/settings.json` shown above — so a `Bash`
matcher on `tool_input.command` is the parallel pattern for command-string checks).

**JSON contract** — permissionDecision output (matches existing `permissionDecision` pattern seen
in `.claude/settings.json`'s inline `Write` hook):

```bash
#!/bin/bash
# mail-guard.sh — PreToolUse Bash-matcher hook.
# ALLOWLIST the 5 email wrapper binaries; DENY raw mail-mutation commands outright.
set -uo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && { echo '{}'; exit 0; }

ALLOWED_BINS='email-census|email-classify|email-archive-confirmed|email-delete-confirmed|email-unsubscribe-extract'

# Deny raw mutation commands regardless of whether an allowed binary also appears
# on the line (defense-in-depth against `email-census; himalaya message delete ...`).
if echo "$CMD" | grep -Eq '\bhimalaya\s+message\s+(delete|move|send)\b|\bhimalaya\s+folder\s+expunge\b|\bhimalaya\s+template\s+send\b|\bmsmtp\b|\brm\s+.*Mail\b|\bsecret-tool\b'; then
  echo '{"permissionDecision":"deny","permissionDecisionReason":"mail-guard: raw mail-mutation command denied. Use the wrapper binaries: email-archive-confirmed / email-delete-confirmed."}'
  echo "$(date -Iseconds) DENY: $CMD" >> "$HOME/.local/share/mail-guard/audit.log"
  exit 0
fi

if echo "$CMD" | grep -Eq "\\b($ALLOWED_BINS)\\b"; then
  echo '{"permissionDecision":"allow"}'
  MANIFEST_HASH=$(echo "$CMD" | grep -oP '(?<=--confirm-manifest )\S+' || echo "-")
  echo "$(date -Iseconds) ALLOW: $CMD (manifest_hash=$MANIFEST_HASH)" >> "$HOME/.local/share/mail-guard/audit.log"
  exit 0
fi

# Neither allowed nor explicitly denied (e.g. unrelated command) -- no opinion.
echo '{}'
exit 0
```

**Testing shape** (matches plan v3 Phase 3 Done-when criteria, lines 391-393): feed this script
`{"tool_input":{"command":"himalaya message delete --folder INBOX 12345"}}` on stdin → expect
`permissionDecision: deny`; feed `{"tool_input":{"command":"email-delete-confirmed --manifest x.jsonl --execute --confirm-manifest abc123"}}` → expect `permissionDecision: allow`.

**Gap found**: the deny regex above matches `himalaya message move` unconditionally, but
`email-archive-confirmed` (my Phase-2 skeleton) itself calls `himalaya message move All_Mail "$id"`
**internally** — that's fine because the hook only inspects the *top-level Bash tool call*
(`email-archive-confirmed ...`), not the wrapper's internal subprocess calls, which are not
separately intercepted by Claude Code's PreToolUse hook (it only fires on the agent's own Bash tool
invocations, not on child processes spawned by an allowed binary). This is actually the **correct**
trust boundary — the wrapper script itself is the audited, git-tracked enforcement point for what
`himalaya` subcommands it's allowed to call — but it means **the wrapper scripts are the second
half of the enforcement story**, not just the hook. Recommend the plan/extension docs state this
explicitly: hook enforces "agent may only invoke wrapper binaries directly," wrapper source code
(reviewable, git-tracked, nix-built) enforces "wrapper binaries only ever call the exact himalaya
verbs their contract specifies." **Confidence: high** (this is how Claude Code hooks work —
PreToolUse only sees the tool call the agent issues, not subprocess trees).

### 4. Verification against the live system — summary of what I checked

| Claim (seed report) | Verified? | Method |
|---|---|---|
| Himalaya v1.2.0 installed, `+oauth2 +keyring` | **Confirmed** | `himalaya --version` live: `himalaya v1.2.0 +smtp +oauth2 +sendmail +pgp-commands +wizard +imap +keyring +maildir` |
| `himalaya message delete` soft-moves to Trash | **Confirmed** | `himalaya message delete --help` live text, quoted above |
| `himalaya folder expunge` truly deletes | **Confirmed** | `himalaya folder expunge --help` live: "definitely deletes emails ... that contain the 'deleted' flag" |
| `himalaya envelope list -o json` is the correct read verb | **Confirmed**, and corrected: `message list` does not exist in v1.2.0 (`message --help` has no `list` subcommand) | `himalaya message --help`, `himalaya folder --help` |
| gmail channels set `Expunge Both` but no `Remove` | **Confirmed**, and clarified: `Remove` is present on `gmail-folders`/`logos-labels`/`logos-folders` only, by design (folder-removal sync, distinct from message-expunge sync) | Read `modules/home/email/mbsync.nix:29,84,154,163` |
| Wrapper location candidates | **Both nix files read**; recommend new `modules/home/email/agent-tools.nix` over extending `packages/email-tools.nix` | Read both files (§ above) |
| `notmuch address --output=sender --output=count --deduplicate=address` census command | **Not independently re-verified against a live index in this pass** (no populated notmuch DB accessible for a clean read-only test); seed report attributes this to R2 Teammate A §1, taken as given | N/A — flagged as inherited, not independently re-derived |
| `--execute`/`--confirm-manifest` sha256 mechanics | **Verified mechanically** (ran `sha256sum` live to confirm command shape) | Bash `sha256sum` test in this session |

**Nothing in the seed report was found to be stale or incorrect.** The one genuine correction is
minor terminology: any place that says `himalaya message list` should say `himalaya envelope
list` — `message` subcommand has no `list` in v1.2.0.

---

## Confidence Summary

| Finding | Confidence |
|---|---|
| `himalaya message delete` = soft move to Trash (label-based) | high |
| `folder expunge` = true delete | high |
| No existing shared-bash-lib pattern; use nix `let`-string interpolation | high |
| `envelope list` not `message list` is correct read verb | high |
| New `modules/home/email/agent-tools.nix` over extending `packages/email-tools.nix` | high |
| JSONL over JSON array for manifest format | medium-high (design choice, not a verified fact) |
| sha256sum confirm-manifest mechanics | high |
| Hook only sees top-level Bash tool calls, not wrapper subprocess trees (two-layer enforcement) | high |
| Exact notmuch query syntax in `email-classify` skeleton | medium (illustrative, not live-tested against populated index) |
| mbsync `Expunge`/`Remove` directive semantics as described | high |
| Manifest-approval provenance gap (who filters `email-classify` output into an approved manifest before mutation) | flagged as open question for planner, not resolved here |

---

## References

- Live commands run: `himalaya --version`, `himalaya message --help`, `himalaya message delete --help`, `himalaya message move --help`, `himalaya folder expunge --help`, `himalaya envelope list --help`
- Read: `modules/home/email/{mbsync,notmuch,aerc,protonmail}.nix`, `modules/home/packages/email-tools.nix`, `modules/home/scripts/{gmail-oauth2,memory-monitor}.nix`, `docs/himalaya.md`, `.claude/settings.json`, `.claude/hooks/validate-meta-write.sh`
- `specs/072_email_workflow_infrastructure_prereqs/reports/01_infrastructure-prereqs-seed.md`
- `specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md` (v3, Phases 0-13)

# Prior-Art Harvest → nvim #803 (Task 72, Phase 2)

**Date**: 2026-07-02
**Source**: the dormant `~/Mail/.claude` email harness (separate repo), harvested data-only before
retirement.
**Consumer**: nvim #803 (the `email/` Claude Code extension) authors classification/preferences
against this. **The #72 → #803 coupling is documentation-only** (Critic F6): nvim #803 declares no
machine dependency on this repo; this file is a reference input, not an enforced contract.

---

## 1. HARVEST — reusable data (verbatim from prior art)

### 1.1 Constants (verified in source)

| Constant | Value | Source | Reuse in this task |
|----------|-------|--------|--------------------|
| `MAX_BATCH_SIZE` | 50 | `email_execute.py:26` | per-run mutation cap (wrapper contract Phase 4) |
| `PLAN_EXPIRY_DAYS` | 7 | `email_execute.py:27` | manifest staleness window (`--confirm-manifest` refuses >7d) |

### 1.2 Rule schema (JSON, from `email-preferences.md`)

Each rule: `pattern`/`condition`, `match_type` (`sender`|`domain`|`subject`|`from_addr`),
optional `condition` (`age_days` `{gt|lt|gte|lte}`, `is_read`, `is_flagged`, `category`),
`action` (`delete`|`archive`|`keep`|`review`), `confidence` (0.0–1.0), `reason`.
Match types: `sender_contains`, `sender_exact`, `domain_contains`, `subject_contains`,
`subject_or_sender_contains`. Processing order: custom rules → triage rules → cleanup rules →
default `keep`.

### 1.3 Confidence-threshold table — HARVESTED **with correction**

Prior art (recorded as-was, for reference):

| Range | Prior-art behavior |
|-------|--------------------|
| ≥ 0.80 | auto-action, no review |
| 0.70–0.79 | auto-action but flagged borderline |
| < 0.70 | manual review |

**RECOMMENDATION for #803 (tightened):** for the *delete* action, require **confidence ≥ 0.90 to
auto-propose delete; everything below → `unsure`.** The prior art's 0.70–0.80 auto-delete band is
the churn source (it auto-actioned marginal mail). Archive/keep may stay more permissive; delete is
the irreversible verb and gets the strict bar. This is the ≥0.90 figure baked into the wrapper
contract (Phase 4).

### 1.4 Sender/domain categorization keyword lists — **keyword-fallback tier ONLY**

Harvested but explicitly demoted: these substring lists are a *fallback* tier, not the primary
signal (header-based classification — §2 gap items — should lead; keywords catch the remainder).

- **Newsletter** (`from_addr`): newsletter, digest, weekly, daily, updates, noreply, no-reply,
  donotreply, notification, news@, info@, marketing@, promo
- **Notification domains**: github.com, gitlab.com, bitbucket.org, linkedin.com, twitter.com,
  x.com, slack.com, discord.com, trello.com, jira, atlassian, asana.com, circleci.com,
  travis-ci.com
- **Promotional** (`from_addr_or_subject`): promo, sale, offer, deal, discount, coupon,
  unsubscribe, %off, limited time
- **Transactional** (`from_addr`): receipt, invoice, order, shipping, delivery, confirm

### 1.5 User-authored custom rules — HARVESTED (the hand-tuned ground truth)

**Custom domain-delete rules (14, all confidence 0.98, `action: delete`)** — NOTE: the plan
estimated "13"; the source actually contains **14**. Recorded faithfully:

`amazon.com`, `voltagesupply.com`, `protonmail.com`, `zidedoor.com`, `spotify.com`,
`sportsmans.com`, `aveneusa`, `lokvani.com`, `espressoparts.com`, `proton.me`, `coinbase.com`,
`mithas.org`, `reviews.io`, `ambrosia.church` (note: `ambrosia.church` ≈ "Zide Door", conceptually
overlaps `zidedoor.com` — likely why the estimate said 13).

**Custom sender-keep rule (1):** `onanyajoni@gmail.com` → `keep` (confidence 0.98).

These 15 rules are the user's revealed preferences (added via the prior `/revise` learning loop);
#803 should seed its allow/deny lists from them. The two `proton*` delete rules coexist with the
user's own Protonmail account — they target *inbound proton marketing*, not personal mail; #803
must not over-generalize them into a Protonmail-account block.

### 1.6 Notable per-sender triage rules (worth porting)

Amazon transactional (order-update@/auto-confirm@/shipment-tracking@/return@/ship-confirm@/
delivery@amazon.com, >30d read → delete 0.90); PayPal receipts (service@/noreply@paypal.com >30d
→ delete 0.85); newsletters (>30d read → delete 0.92); dev notifications (github/gitlab/... >14d
read → archive 0.88); social (linkedin/twitter/facebook/x >30d read → archive 0.87); always-keep
flagged (1.0); keep recent-unread (<2d → 0.85).

---

## 2. GAP NOTE — new work, NOT harvestable (gap, not omission)

Confirmed absent from the prior art; #803 must build these fresh (they are the header-based
primary tier that relegates §1.4 keywords to fallback):

- **List-Unsubscribe header parsing** (RFC 2369 / RFC 8058 one-click) — the prior art had no
  header extraction; Task 72 ships `email-unsubscribe-extract` (read-only) as the mechanism, but
  the *classification use* of the header is #803's.
- **`Precedence: bulk` / `Auto-Submitted`** signals — no handling in prior art.
- **Reply-history / thread-participation** scoring (did the user ever reply to this sender?) —
  absent.
- **VIP allow-list** derived from contacts/sent-folder correspondents — absent (§1.5's single
  `keep` rule is the only allow signal in prior art).

Record these as a **gap, not an omission**: they were never built, so there is nothing to migrate.

---

## 3. DISCARD verdicts (recorded, per v3 Phase 0)

- **Checkbox-approval UX** (`~/Mail` tasks 014/022/023: mark `[x]` in a markdown plan, `/revise
  "only delete the checked items"`) — **DISCARD.** Superseded by the Task 72 model: aerc tagged
  review views + a git-tracked, sha256-confirmed JSONL manifest keyed on Message-ID. The checkbox
  flow does not survive maildir id churn and has no cryptographic approval provenance.
- **Retired `email.md` command's `model: opus` pin** — **DISCARD.** The tiered model policy
  applies (worker agents = sonnet; deep-reasoning = opus); no per-command opus pin is carried
  forward.

---

## 4. RETIRE inventory (the harness removal in the `~/Mail` repo)

Files to `git rm` from `~/Mail` (its own git; **not** this dotfiles repo). All data above is now
preserved here, so removal is non-destructive to the harvest:

| Path (in `~/Mail`) | Lines | Kind |
|--------------------|-------|------|
| `.claude/commands/email.md` | — | command |
| `.claude/skills/skill-email/` | — | skill dir |
| `.claude/agents/email-agent.md` | — | agent |
| `.claude/scripts/email/email_list.py` | 235 | script |
| `.claude/scripts/email/email_analyze.py` | 819 | script |
| `.claude/scripts/email/email_triage.py` | 745 | script |
| `.claude/scripts/email/email_filter.py` | 348 | script |
| `.claude/scripts/email/email_execute.py` | 416 | script |

**PRESERVE** everything else in `~/Mail` (the maildir, the repo's specs history, the rest of its
`.claude`) untouched. `~/Mail/.claude/context/project/email/email-preferences.md` is the data
source — its content survives in §1 of this file; whether to also delete it is left to the
retirement step (recommend keeping it in `~/Mail` history via the removal commit, or leaving it —
decided at execution time).

**Caution flagged at execution:** `~/Mail`'s working tree has **many pre-existing uncommitted
changes unrelated to Task 72**. The retirement commit must stage ONLY the paths above
(`git rm` the specific files), never `git add -A`, to avoid sweeping unrelated edits into the
task-72 retirement commit.

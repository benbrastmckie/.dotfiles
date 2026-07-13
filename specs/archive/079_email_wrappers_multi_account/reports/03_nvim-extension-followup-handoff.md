# Handoff: nvim email/ extension is multi-account ready — remaining verification for the .dotfiles side

**Direction**: `~/.config/nvim` (agent system) -> `~/.dotfiles` (this repo)
**Reciprocal of**: `reports/01_nvim-extension-handoff.md` (which went .dotfiles -> nvim)
**Source task**: `~/.config/nvim` task 815 (`revise_email_extension_multi_account`), status `[COMPLETED]`
**Created**: 2026-07-04
**Wrapper task (this repo)**: task 79 (`email_wrappers_multi_account`), status `[COMPLETED]`

---

## 1. TL;DR — what this hands you

The `.claude/extensions/email/` extension in `~/.config/nvim` has been revised to support a
second account (`logos` / Protonmail Bridge) alongside the existing Gmail-only path. That work
(nvim task 815, Phases 1-5) is **landed and complete**. It was authored *additive + gated*: the
bare `/email` Gmail path is byte-for-byte unchanged, and `/email --logos` is fully parsed and
documented but routed through a precondition gate that **fails loudly** rather than silently
falling back to Gmail.

One segment was deliberately deferred as **Phase 6 `[BLOCKED]`**, because at the time task 815
ran, this repo's task 79 was only `researched` — the `--account`-aware wrapper binaries did not
yet exist live. **Task 79 is now `[COMPLETED]`**, so that precondition has landed and Phase 6 is
now unblockable. This report is the checklist to close the loop.

---

## 2. The contract the nvim extension now assumes from your wrappers

The extension encodes the following assumptions about the five frozen wrapper binaries
(`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract`, defined in `~/.dotfiles/modules/home/email/agent-tools.nix`).
**Your first job is to confirm the landed task-79 wrappers actually satisfy each row** — if any
diverges, that is where the two repos are out of sync.

| # | Assumption encoded in the nvim extension | Confirm against landed `agent-tools.nix` |
|---|-------------------------------------------|------------------------------------------|
| 1 | Every wrapper accepts `--account <gmail\|logos>` | flag name + enum spelling exact |
| 2 | Default account when `--account` omitted is `gmail` | preserves old Gmail-only behavior |
| 3 | An unknown account (e.g. `--account work`) is **rejected with an actionable error** at the wrapper preamble, never coerced to Gmail | error path, not silent fallback |
| 4 | Gmail scope tokens: inbox = `folder:Gmail`, archive = `folder:Gmail/.All_Mail` | unchanged |
| 5 | Logos scope tokens: inbox = `folder:Logos` (bare root = INBOX), archive = `folder:Logos/.Archive` | **no `.All_Mail`, no `.Spam` for Logos** |
| 6 | Logos real folders are `.Sent`, `.Archive`, `.Drafts`, `.Trash` only (dot-prefixed maildir++) | non-dot siblings are stray/empty |
| 7 | Account scope is resolved by `folder:` queries **exclusively** — `tag:logos` / `tag:gmail` are inert in the live notmuch DB and MUST NOT be used | tag-based scoping confirmed non-functional |
| 8 | mbsync channels are per-account: `gmail -> mbsync gmail`, `logos -> mbsync logos`; **never `mbsync -a`** | channel names in `mbsync.nix` |
| 9 | Task 79 adds **no new binaries** — only the `--account` flag on existing ones (so `hooks/mail-guard.sh`, which allowlists by binary name, needed no change) | binary set unchanged |

If rows 1-3 or 8 are true but the *flag spelling* differs from `--account` / `--logos`, only the
argument-threading in the nvim extension (and the contract doc in Phase 6) needs a small
adjustment — the folder-token rows (4-7) are query-side facts and stay valid regardless.

---

## 3. What landed on the nvim side (Phases 1-5, for context)

Files edited in `~/.config/nvim/.claude/extensions/email/`:

- `commands/email.md` — `--account <gmail|logos>` / `--logos` selector; threads the resolved
  account into both cleanup and sync delegation args; per-account `--archive` semantics;
  unknown-account error; the loud precondition gate.
- `skills/skill-email-cleanup/SKILL.md` — the load-bearing edit: account-aware `BASE_QUERY`
  (rows 4-5 above), `--account` passthrough to *every* wrapper invocation, per-account
  pilot-gate scoping, and an "Account Precondition Gate" section.
- `skills/skill-email-sync/SKILL.md` — mbsync channel defaulted from the active account
  (row 8), preserving the never-`mbsync -a` invariant.
- `EXTENSION.md` — account dimension documented in the command table + safety invariants.
- `manifest.json` — added `logos` / `protonmail` / `proton` keywords.
- `hooks/mail-guard.sh` — **intentionally unchanged** (confirmed via empty git diff).

Full detail: `~/.config/nvim/specs/815_revise_email_extension_multi_account/` (see
`reports/01_multi-account-extension-revision.md` and
`plans/01_email-multi-account-support.md`).

---

## 4. What remains — Phase 6 (now unblocked)

These are the exact steps carried as `[BLOCKED]` in the task-815 plan, now that task 79 has
landed. They require the live, switched-in wrapper environment — which is why they belong with a
`.dotfiles`-context agent that can run against real mail.

- [ ] **Confirm `home-manager switch` has actually applied task 79** (the wrappers must be live
      on `PATH`, not merely committed). `email-census --help` should show the `--account` flag.
- [ ] **Re-confirm the exact flag spelling** via `email-census --help` before treating the Logos
      path as live — guard against a flag-name shift during task 79's own implementation. If it
      is not literally `--account` / `--logos`, note the real spelling (nvim side will need a
      one-line passthrough adjustment).
- [ ] **Exercise `/email --logos` end-to-end** (census -> classify -> a small archive/delete dry
      run) against the live Logos maildir. Confirm `folder:Logos` and `folder:Logos/.Archive`
      scoping return non-empty, correct counts, and that the precondition gate now **passes**.
- [ ] **Refresh `~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`**
      (§2 / §11) with the real `--account` enum and the per-account folder-token table,
      re-verified against the landed `agent-tools.nix`.
- [ ] *(optional editorial)* Generalize the illustrative `folder:Gmail/.All_Mail` tokens in
      `.../domain/archive-mode-risk.md` to be account-neutral.

Estimated effort once live: ~0.5 hour.

---

## 5. How to close the loop

Two clean options:

1. **Resume Phase 6 in the nvim repo**: from `~/.config/nvim`, run `/spawn 815` (or a fresh
   `/task`) to create a small follow-up that discharges the Phase 6 checklist above and flips the
   plan's Phase 6 marker from `[BLOCKED]` to `[COMPLETED]`. This keeps the verification artifact
   version-controlled with task 815.

2. **Verify from this repo and report back**: if the `.dotfiles` agent runs the row 1-9 contract
   confirmation and the live `/email --logos` exercise here, drop the findings (especially any
   flag-spelling or folder-token divergence) into a short note, and the nvim side applies the
   `wrapper-contracts.md` refresh.

Either way, the single most important deliverable is **rows 1-9 in §2 confirmed against the
landed `agent-tools.nix`** — that is the actual cross-repo handshake. Everything else is
downstream of it.

---

## 6. Pointers

- nvim task 815 dir: `~/.config/nvim/specs/815_revise_email_extension_multi_account/`
- nvim extension under revision: `~/.config/nvim/.claude/extensions/email/`
- wrapper source (this repo): `~/.dotfiles/modules/home/email/agent-tools.nix`
- mbsync channels (this repo): `~/.dotfiles/modules/home/email/mbsync.nix`
- prior handoffs: `reports/01_nvim-extension-handoff.md`, `reports/02_wrapper-multi-account.md`

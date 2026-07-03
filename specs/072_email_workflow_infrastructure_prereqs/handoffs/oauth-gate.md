# OAuth Gate — Research + `invalid_grant` Fail-Safe (Task 72, Phase 3)

**Date**: 2026-07-02
**Purpose**: Verify OAuth state, research Google's actual Production-verification requirements for
the restricted `mail.google.com` scope BEFORE recommending "publish to Production", identify the
lowest-friction unblock, and specify the auth-failure fail-safe against the `mbsync gmail` step.
Consumed by Phases 4/6/8 and folded into the #29 handoff.

---

## 1. Live state (verified 2026-07-02)

| Component | Auth | State |
|-----------|------|-------|
| `gmail-oauth2-refresh.service` | XOAUTH2 refresh | **failed** (`invalid_grant` / "Bad Request"), token revoked |
| `mbsync gmail` (IMAP sync) | XOAUTH2 | **broken** — `[AUTHENTICATIONFAILED] Invalid credentials` (Phase 1 test) |
| himalaya (local maildir + send) | **app password** (`gmail-app-password` keyring) | **working** |
| aerc (reads maildir) | via himalaya/maildir | **working** |

Consent screen is in **Testing** mode (task 46 report). Requested scopes (`docs/himalaya.md:198`):
`https://mail.google.com/` (**restricted**) + `contacts`, `calendar`, `carddav` (sensitive/
restricted). Account is a **consumer `@gmail.com`** with 2-Step Verification (not Workspace).

**Root cause (task 46, confirmed):** Testing-mode enforces a **7-day refresh-token expiry**; the
refresh token expired/was revoked → `invalid_grant`. This is the ONLY XOAUTH2 consumer that
matters for this build; himalaya/aerc are on app-password and are unaffected. **The whole infra
build (himalaya wrappers, dry-runs, classification, aerc review) is NOT gated on OAuth.** Only
`mbsync` server reconcile + server-side delete verification are.

## 2. Research — Production verification for the restricted `mail.google.com` scope

- **Restricted scope ⇒ CASA required.** Any app requesting restricted Gmail scopes
  (`https://mail.google.com/`) that can move data through a third-party server must pass a
  **CASA (Cloud Application Security Assessment) Tier 2** audit by a Google-empanelled assessor.
- **Publishing alone is insufficient.** Setting the consent screen to "In production" does **not**
  reliably remove the 7-day refresh-token expiry for *restricted* scopes; the indefinite-lifetime
  guarantee applies once the app is published **and verified**. (Sensitive-scope apps get a
  bypassable "unverified app" warning; restricted scopes are stricter.)
- **Cost / cadence.** CASA Tier 2: LOA from an assessor, **annual** re-verification, typically a
  few hundred to a few thousand USD/yr, and a multi-week turnaround. This is a real schedule risk
  the plan flagged — publishing to Production is **not** a same-day self-serve fix for restricted
  scopes.
- **"Internal-only" is unavailable** here: it requires a Google Workspace domain; this is a
  consumer `@gmail.com`.

## 3. Decision branch — **DECIDED: (c), user-confirmed 2026-07-02**

> **DECISION (user-confirmed):** Option **(c)** — switch `mbsync` from XOAUTH2 to the existing
> `gmail-app-password`. Task 46 is **downgraded from a #29 blocker to optional**. Follow-up action
> (task-46 / `mbsync.nix` scope, not this task's wrapper contract): set the Gmail IMAP store to
> `AuthMechs LOGIN` + `PassCmd` reading `gmail-app-password` from the keyring, then verify
> `mbsync gmail` authenticates. This lifts the server-side delete-verification block with no CASA.
> Carried into the #29 runbook (Phase 11) and a task-46 note.


**(a) Pursue publish-to-Production + CASA Tier 2.** Documented, but heavyweight: multi-week + paid
+ annual re-audit for a single-user personal mail client. Not recommended as the unblock path.

**(b) Declare task 46 a hard blocker** for the #29 purge and for server-side delete verification,
and proceed with this infra build on the app-password path (dry-runs + local ops fully functional;
server reconcile deferred). Safe but leaves `mbsync` permanently broken.

**(c) RECOMMENDED — switch `mbsync` from XOAUTH2 to the existing app password.** For a **consumer
`@gmail.com` with 2-Step Verification, app passwords still authenticate IMAP in July 2026**
(Google removed this for *Workspace* accounts in May 2025 but retained it for consumer accounts).
himalaya/aerc already use the working `gmail-app-password` keyring entry, so the credential exists.
Reconfiguring mbsync's Gmail IMAP store to `AuthMechs LOGIN` + `PassCmd` (read the app password
from the keyring) **sidesteps OAuth entirely** and unblocks server sync + server-side delete
verification **with no CASA process**. This effectively **downgrades task 46 from a #29 blocker to
optional** (OAuth would only be needed if the user later wants XOAUTH2 specifically).
- Trade-off: app passwords are a static long-lived secret (vs. rotating OAuth tokens); acceptable
  for a personal single-user setup, and it is already the trust model himalaya/aerc rely on.
- This is a **task-46 / mbsync.nix change**, not part of this task's wrapper contract; recorded
  here as the recommended unblock and carried into the #29 handoff + a task-46 note.

## 4. `invalid_grant` / auth-failure fail-safe CONTRACT (consumed by Phases 4/6/8)

- **Sole detection point: the `mbsync gmail` reconcile step** — the only network/auth consumer in
  the mutation flow. Detection matches either XOAUTH2 `invalid_grant` **or** app-password
  `[AUTHENTICATIONFAILED] Invalid credentials` in `mbsync` output (covers both auth models, so the
  contract survives the Option-(c) switch).
- **On detection:** halt cleanly BEFORE any further mutation; **preserve** (a) the approved
  manifest bytes (hash stays valid) and (b) the `<manifest>.state.jsonl` execution-status file;
  print resume instructions (fix auth → re-run `mbsync gmail` → re-run the wrapper `--execute`,
  which skips `executed` IDs).
- **Himalaya wrapper calls do NOT check for `invalid_grant`.** They are on the app-password path
  (local maildir move/delete) and never touch XOAUTH2; adding an OAuth check there would be
  incorrect. The fail-safe lives exclusively on the mbsync reconcile.
- `email-delete-confirmed` / `email-archive-confirmed` (Phase 6) and `email-thaw` (Phase 8) all
  print the reconcile step wrapped in this fail-safe.

## 5. Blocking scope summary (for #29)

- **Infra build (this task):** NOT blocked — proceeds fully on app-password.
- **`~/Mail #29` purge + server-side All-Mail delete verification:** was BLOCKED on task 46 under
  XOAUTH2. Per the user-confirmed decision (Option c), the block is **lifted** without CASA once
  the small `mbsync.nix` app-password auth change lands (task-46 follow-up); no dependency on
  publishing to Production or CASA remains.

## Sources

- [Restricted scope verification — Google for Developers](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
- [OAuth App Verification Help — Google Cloud](https://support.google.com/cloud/answer/13463073?hl=en)
- [Google CASA security assessment 2025 — DeepStrike](https://deepstrike.io/blog/google-casa-security-assessment-2025)
- [Google OAuth Refresh Token: 7-Day Limit & Lifetime (2026) — Unipile](https://www.unipile.com/google-oauth-refresh-token/)
- [Transition from less secure apps to OAuth — Google Workspace](https://knowledge.workspace.google.com/admin/sync/transition-from-less-secure-apps-to-oauth)
- [Synchronize your 2FA Gmail with mbsync — FrostyX](https://frostyx.cz/posts/synchronize-your-2fa-gmail-with-mbsync)

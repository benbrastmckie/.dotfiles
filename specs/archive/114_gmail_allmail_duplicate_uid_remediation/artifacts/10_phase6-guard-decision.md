# Phase 6 — mail-sync.nix benign-duplicate guard decision

## Existing behavior reviewed

`modules/home/email/mail-sync.nix` (`is_duplicate_uid()`, lines ~94-137) already recognizes the
`Maildir error: duplicate UID <n> in ...` class, prints detailed manual-remediation guidance
referencing ".dotfiles task 852/853", and explicitly still returns `OVERALL_STATUS=1` (does not
silently exit 0). This is what causes aerc's `check-mail-cmd` to red-banner whenever this class
occurs.

## Decision: DO NOT add a guard that exits 0 for the duplicate-UID class

**Rationale**:

1. This implementation (task 114) resolved EVERY duplicate-UID collision found across a full
   sweep of `~/Mail/Gmail/*` and `~/Mail/Logos/*` — 149 total (UID 15, UID 104, and 147 more
   found by the Phase 5 scan), all in `Gmail/.All_Mail`. Post-remediation, zero `,U=<n>`
   collisions remain anywhere swept.
2. With the known corruption cleared, there is no longer a "known, durable, benign" class left
   to whitelist. A guard written now would necessarily be a **blanket** suppression of the
   whole `is_duplicate_uid()` branch, not a narrow, evidence-backed allowlist of specific UIDs —
   exactly the failure mode the plan's Phase 6 goal warned against ("not a blanket suppression
   of all duplicate-UID failures").
3. A FUTURE duplicate-UID collision, after this cleanup, would represent a **new** instance of
   the same class of Maildir corruption this task just spent significant effort diagnosing and
   fixing (mis-tagged `,U=` filenames from historical migration tooling). Silently exiting 0
   would hide that recurrence from aerc's check-mail banner — the opposite of what a user
   monitoring mail health wants. The existing manual-remediation guidance printed by
   `is_duplicate_uid()` remains the right response: surface it, don't suppress it.
4. The plan's own default recommendation (research report open question 3, plan Phase 6 task 2)
   already anticipated this exact conclusion: "do NOT silently exit 0 for the whole class after
   this remediation, since Phases 3-5 remove the current corruption and a future duplicate-UID
   SHOULD surface. Only implement a guard if there is a durable, benign, whitelisted case that
   cannot be remediated." No such case exists post-cleanup.

## Outcome

`modules/home/email/mail-sync.nix` is **unchanged**. No `home-manager build` / `nix flake
check` run was required for this phase since no Nix file was modified.

## Note: unrelated to the separate `specs,U=67297` blocker

This decision concerns the duplicate-UID detection class specifically. The separate stray
non-mail-directory blocker documented in `08_stray-directory-finding-NOT-REMOVED.md` is NOT a
duplicate-UID collision (`is_duplicate_uid()` would not match its "Is a directory" error text
at all) and is unaffected by this decision either way.

# Implementation Summary: Sapience Fresh-Machine Declarative Gaps

- **Task**: 144 - Close the three remaining hand steps between a fresh switch and a working
  Sapience client
- **Status**: [BLOCKED]
- **Started**: 2026-11-18T19:40:00Z
- **Completed**: 2026-11-18T21:50:00Z
- **Effort**: ~2.1 hours
- **Dependencies**: None blocking. File-adjacency with task 136 (home.nix,
  modules/home/services/sapience.nix, docs/sapience.md) and task 141 (disjoint file scope) —
  both re-read immediately before each edit; no conflicting edit encountered.
- **Artifacts**: plans/01_fresh-machine-declarative-gaps.md,
  reports/01_fresh-machine-declarative-gaps.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-5 of the plan are complete and gate-green: `tokenFile` now resolves to a sops-backed
secret so a fresh machine's bootstrap no longer needs an interactive token paste; the
`sourceDirs` registration question is resolved as "stays manual" with the reasoning recorded in
the option description, the `home.nix` comment, and the docs; and lingering is granted
declaratively at the NixOS layer (`users.users.benjamin.linger = true`) with a narrowed
activation-time notice for the one case (WSL2) that grant cannot reach. Phase 6 is blocked, by
design: the three remaining live verifications require `sudo nixos-rebuild switch` and the real
Sapience token, neither of which this dispatch can touch, and the team lead directed that this
be left open for the user to run themselves rather than closed as `[COMPLETED WITH EXCLUSIONS]`.

## What Changed

- `home.nix` — `programs.sapience.tokenFile = "/run/secrets/sapience_token";` (quoted string),
  an extended `sourceDirs` comment, and (briefly, reverted) a temporary `backgroundSync = true`
  probe used only to confirm Phase 4's activation entry materializes.
- `modules/system/secrets.nix` — new `secrets."sapience_token"` entry (owner/mode `0400`,
  matching `anthropic_api_key`); the whole `secrets` block restructured into one nested attrset
  to satisfy `statix`'s repeated-key lint (see Plan Deviations).
- `modules/system/users.nix` — `users.users.${username}.linger = true;`, with a scope comment.
- `modules/home/services/sapience.nix` — `sourceDirs` option description extended with the
  manual-registration reasoning; new `sapienceLingerNotice` activation entry (gated on
  `cfg.backgroundSync`, inert today) that probes real linger state and warns, non-fatally,
  naming both remedies.
- `docs/sapience.md` — both tables updated (`tokenFile`'s set value, a NixOS-level `linger`
  note, two new "How this machine is configured" rows); `## First-time setup` steps 1-3
  rewritten around the sops-backed token plus a new "what remains manual" list naming exactly
  four items; three design-decision sections (`### The token never enters the Nix store`,
  `### The source store goes in by name`, `### Home-manager, not NixOS` /
  `### Nothing extracts on a schedule`) each extended by one sentence or short paragraph.
- No change to `secrets/secrets.yaml` or `packages/sapience-flake/**`.

## Decisions

- **Gap 1**: wire a sibling sops secret (`sapience_token`) with the same owner/mode shape as
  `anthropic_api_key`; no module-logic change needed, since `tokenFile` already flowed through
  the repair/validation guard (`sap_token_clean`/`sap_token_ok`) before this task.
- **Gap 2**: resolved as option (b) — registration stays manual. The deciding argument is the
  vendor's own `adddir` confirmation gate (TTY or `--yes` required to read anything), not the
  ledger-cost framing the dispatch raised; an activation-time call would be either a no-op that
  looks like registration or an unattended credential-dependent upload on every switch.
- **Gap 3**: grant `linger = true` declaratively at the NixOS layer
  (`modules/system/users.nix`), and author a new, narrowed activation notice in the live module
  (the fork's `sapienceWslSyncNotice` the dispatch described does not exist in the live module)
  that probes actual linger state rather than proxying for WSL-ness.
- **Dispatch-level override (from the team lead, superseding `.decisions.json`'s recorded
  answer)**: `sudo` is structurally denied in this harness, so this dispatch did not attempt the
  operator-run tasks and left Phase 6 `[BLOCKED]` rather than closing it
  `[COMPLETED WITH EXCLUSIONS]`.

## Plan Deviations

- **Phase 1** (altered): `modules/system/secrets.nix` restructured from three top-level
  `secrets."x" = {...};` statements into one nested `secrets = { "x" = {...}; ... };` attrset.
  `statix`'s "repeated keys" lint fires at 3 occurrences of the top-level form (2 passes, the
  naive 3rd addition failed `nix flake check`'s `checks.x86_64-linux.statix`); restructured to
  match statix's own suggested fix.
- **Phase 1** (altered): the plan's literal quoting-check command,
  `grep -nE 'tokenFile *= *[^"]' home.nix`, is non-discriminating (a quantifier/character-class
  artifact — it also "matches" the already-correct `apiKeyFile` precedent line). Used the
  corrected single-space form `grep -nE 'tokenFile = [^"]' home.nix` instead, which correctly
  finds nothing for both lines.
- **Phase 1** (altered): the non-interactive bootstrap demonstration needed the built script's
  `~/.sapience/*` paths further redirected into an isolated scratchpad directory, beyond
  substituting only the token path, to avoid touching real vendor state (the real `config.json`
  already carries a valid token, which would otherwise short-circuit the demonstration or, on an
  unreachable-host code path, risk a clobber).
- **Phase 5** (altered, caught and fixed): one new sentence briefly introduced forbidden
  record-versioning phrasing ("no longer prompts"); reworded before this phase closed.
- **Phase 5** (noted, not a real divergence): the plan's own Scope Hypothesis undercounts its
  own "Files to modify" list (says "three" `### ...` design-decision sections, lists four); 7
  named regions were touched in `docs/sapience.md`, matching "Files to modify" exactly.
- **Phase 6** (per dispatch-level override, not a plan defect): agent-executable verification
  only; operator-run tasks not attempted; phase left `[BLOCKED]` rather than
  `[COMPLETED WITH EXCLUSIONS]`. Full detail in Decisions above and the Operator Checkpoint
  section below.

## Impacts

- A fresh machine's `sapience-bootstrap` will read the token from `/run/secrets/sapience_token`
  non-interactively once the operator completes the sequence below — no agent or automated flow
  ever handles the real token value.
- `users.users.benjamin.linger = true` applies to every host this flake builds (`nandi`,
  `hamsa`, `garuda`, `usb-installer`) once a system switch runs; it benefits every
  `systemd.user.timers.*` unit in this tree, not only Sapience's.
- `sourceDirs` remains declared-but-inert until a human runs `sapience-adddir-sources` once — now
  documented as a deliberate, permanent property rather than an oversight.
- Two consecutive `home-manager switch --flake .#benjamin` runs on this machine are confirmed
  no-ops for all three gaps (see Verification).

## Follow-ups

- **Operator Checkpoint — run this sequence to close Phase 6** (owner: user; no due date set):

  ```bash
  # 1. Add the real token to the sops-encrypted secrets file, beside anthropic_api_key.
  sops secrets/secrets.yaml

  # 2. Apply both secrets and the linger grant at the system layer.
  cd ~/.dotfiles && sudo nixos-rebuild switch --flake .#$(hostname)

  # 3. Confirm the secret decrypted at the declared owner/mode.
  test -r /run/secrets/sapience_token && echo readable

  # 4. Confirm lingering is actually granted (Acceptance Criterion 4).
  loginctl show-user benjamin --property=Linger   # must report Linger=yes

  # 5. Confirm bootstrap picks up the real token with no prompt (Acceptance Criterion 2's live half).
  #    The vendor's folder-selection picker still needs a TTY; that stays manual.
  sapience-bootstrap </dev/null

  # 6. Confirm the system switch is a no-op the second time (Acceptance Criterion 5's system half).
  sudo nixos-rebuild switch --flake .#$(hostname)
  ```

  Afterward, re-run `nix flake check` (should still be green) and reconcile Phase 6's status in
  the plan from `[BLOCKED]` to `[COMPLETED]` once all six steps above have run successfully.
- A separate, already-tracked task covers making the vendor hook-wiring opt-out
  (`~/.sapience/config.json`'s `"hooks": false`) declarative; this task does not touch it and
  `docs/sapience.md`'s remaining-manual list names it explicitly as still outside this task's
  scope.
- `sapience-adddir-sources` still needs one manual run per Decision 2; named in
  `docs/sapience.md`'s remaining-manual list.

## References

- `specs/144_sapience_fresh_machine_declarative_gaps/plans/01_fresh-machine-declarative-gaps.md`
- `specs/144_sapience_fresh_machine_declarative_gaps/reports/01_fresh-machine-declarative-gaps.md`
- `home.nix`, `modules/system/secrets.nix`, `modules/system/users.nix`,
  `modules/home/services/sapience.nix`, `docs/sapience.md`

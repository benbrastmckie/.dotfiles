# Implementation Summary: Sapience Fresh-Machine Declarative Gaps

- **Task**: 144 - Close the three remaining hand steps between a fresh switch and a working
  Sapience client
- **Status**: [COMPLETED WITH EXCLUSIONS]
- **Started**: 2026-11-18T19:40:00Z
- **Completed**: 2026-11-18T22:20:00Z
- **Effort**: ~2.4 hours
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
activation-time notice for the one case (WSL2) that grant cannot reach. Phase 6 is now closed
`[COMPLETED WITH EXCLUSIONS]`: the operator has since run the sequence an earlier dispatch could
not — adding the real token via `sops secrets/secrets.yaml` (committed `ba9d8bd`) and running
`sudo nixos-rebuild switch` successfully — and this dispatch independently re-verified the live
evidence (`Linger=yes`; the real secret present at the declared owner/mode) rather than trusting
the report. Two items remain genuinely outside what an agent can do and are recorded as reasoned
exclusions: running the interactive `sapience-bootstrap` folder-picker flow, and a second
literal `sudo nixos-rebuild switch` (for which a non-sudo substitute convergence proof was
gathered instead — see Verification).

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
- **Phase 6 closure**: once the operator ran the sequence (real token via `sops`, successful
  `sudo nixos-rebuild switch`), this dispatch re-verified the live evidence itself rather than
  trusting the report, then closed Phase 6 under the plan's own original Closure rule —
  `[COMPLETED WITH EXCLUSIONS]` — naming exactly two reasoned exclusions (the interactive
  `sapience-bootstrap` folder-picker run, and a second literal `sudo` invocation, for which a
  non-sudo substitute convergence proof was gathered instead).

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
- **Phase 6** (closure, not a plan defect): the operator sequence ran between the prior dispatch
  and this one. This dispatch re-verified AC2's secret half and AC4 live, and found a non-sudo
  substitute proof for AC5's second-switch no-op half (store-path equality between
  `/run/current-system` and a fresh `nix build` of the same host's toplevel) rather than running
  the literal second `sudo nixos-rebuild switch`. Phase closes `[COMPLETED WITH EXCLUSIONS]` with
  two reasoned exclusions: the interactive `sapience-bootstrap` run, and that second literal
  `sudo` invocation. Full detail in Decisions above and the Verification section below.

## Impacts

- A fresh machine's `sapience-bootstrap` reads the token from `/run/secrets/sapience_token`
  non-interactively — confirmed live on this machine (the secret exists at the declared
  owner/mode) — no agent or automated flow ever handles the real token value.
- `users.users.benjamin.linger = true` applies to every host this flake builds (`nandi`,
  `hamsa`, `garuda`, `usb-installer`); confirmed live on this machine (`Linger=yes`) after the
  system switch. It benefits every `systemd.user.timers.*` unit in this tree, not only
  Sapience's.
- `sourceDirs` remains declared-but-inert until a human runs `sapience-adddir-sources` once — now
  documented as a deliberate, permanent property rather than an oversight.
- Two consecutive `home-manager switch --flake .#benjamin` runs on this machine are confirmed
  no-ops for all three gaps (see Verification).

## Verification (Phase 6 closure)

Re-verified live by this dispatch, independent of the operator's own report:

```
$ loginctl show-user benjamin --property=Linger
Linger=yes

$ ls -la /run/secrets/sapience_token
-r-------- 1 benjamin users 43 Nov 18 12:44 /run/secrets/sapience_token
$ stat -c '%a %U %s' /run/secrets/sapience_token
400 benjamin 43
$ test -r /run/secrets/sapience_token && echo readable
readable

$ nix flake check
...
all checks passed!

$ readlink -f /run/current-system
/nix/store/5b3a6hpcdqkrqckmsv7a9schxbcwaxm0-nixos-system-hamsa-26.05.20260921.1e8bc65
$ nix build .#nixosConfigurations.hamsa.config.system.build.toplevel --no-link --print-out-paths
/nix/store/5b3a6hpcdqkrqckmsv7a9schxbcwaxm0-nixos-system-hamsa-26.05.20260921.1e8bc65
```

The last pair is a non-sudo substitute for AC5's second-switch no-op proof: the running
system's store path and a fresh, non-activating build of this flake's `hamsa` toplevel are
identical, so a second `sudo nixos-rebuild switch` would have nothing new to activate.

**Reasoned exclusions (full detail and table in the plan's Phase 6 section)**:
- `sapience-bootstrap </dev/null` against the real secret — state-changing, opens an
  interactive vendor folder picker; not safely automatable from a dispatch.
- A second literal `sudo nixos-rebuild switch` — `sudo` is structurally denied to this
  dispatch; the store-path-equality proof above substitutes for it.

## Follow-ups

- A separate, already-tracked task covers making the vendor hook-wiring opt-out
  (`~/.sapience/config.json`'s `"hooks": false`) declarative; this task does not touch it and
  `docs/sapience.md`'s remaining-manual list names it explicitly as still outside this task's
  scope.
- `sapience-adddir-sources` still needs one manual run per Decision 2; named in
  `docs/sapience.md`'s remaining-manual list.
- `sapience-bootstrap`'s interactive folder-picker step still needs a TTY; named in
  `docs/sapience.md`'s remaining-manual list and carried as a Phase 6 reasoned exclusion above.

## References

- `specs/144_sapience_fresh_machine_declarative_gaps/plans/01_fresh-machine-declarative-gaps.md`
- `specs/144_sapience_fresh_machine_declarative_gaps/reports/01_fresh-machine-declarative-gaps.md`
- `home.nix`, `modules/system/secrets.nix`, `modules/system/users.nix`,
  `modules/home/services/sapience.nix`, `docs/sapience.md`

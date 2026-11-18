# Roadmap

*Forward-only: this file carries ordering, gates and rulings for open work, never a record of
finished work. A task that reaches a terminal state is removed from it, not annotated. Per-task
detail lives in `specs/TODO.md`; `## Next` and `## Open work` below are rendered from
`specs/state.json` by `.claude/scripts/roadmap-integration.sh` and must not be hand-edited. Gate
state last measured: not yet measured.*

## Goal

Keep this machine's NixOS and Home Manager configuration reproducible, buildable from a clean
checkout, and cheap to change: every host builds from `flake.nix` with pinned inputs, user
environment lives under `modules/home/**`, system configuration under `modules/system/**`, and
no working configuration depends on state that is not in this repository.

## Gate state

Not yet measured. The gates below are the ones worth measuring before a batch is dispatched; run
them and replace this section with the observed result and the date.

- `nix flake check` -- clean, or the named failing check.
- `sudo nixos-rebuild build --flake .#<host>` -- builds without evaluation errors.
- `home-manager build --flake .#<user>` -- builds without evaluation errors.
- `bash .claude/scripts/validate-state.sh specs/state.json` -- currently FAILS on one
  pre-existing finding: missing/empty `task_type` on legacy tasks 15, 19, 23, 41, 42, 43, 46.

## Next

Every open Sapience task now leads this list, with the part of it that is actually attendable at the very top. The hook-reinjection convergence work and the fresh-machine declarative gaps both have an empty dependencies[] and can be picked up today; the hooks opt-out default rides in the same batch because it shares the detector surface and the sapience.nix territory with them, even though the graph will skip it until the parked measurement clears. That measurement stays parked -- it is five or more hand-run extraction passes spaced across more than a week, not something a dispatch can discharge -- and the classifier-cost task is blocked behind it, so that pair sits second rather than first. Extraction still runs against a metered third-party key, so every pass costs money and sends raw transcript chunks off this machine, which is what makes the declarative and hook-scoping work above worth taking before the configuration work below it. Everything after the Sapience batches is ordinary configuration work that is not getting more expensive while it waits.

```
/orchestrate 136, 139   # Parked: resume the coverage measurement, then settle the classifier cost it prices
/orchestrate 124, 77, 117, 120, 78   # Settle the niri session and resume behavior before documenting a setup that stops moving
/orchestrate 125, 131   # Contain and schedule Claude's own session hygiene on one systemd user-unit surface
```

Why this order:
- Sapience leads this list now, and two of this batch's three members can genuinely be picked up today: 141 and 144 both carry an empty dependencies[] and sit in wave 1 on their own merits. 141 opens the batch because it is the convergence-and-detection half of the hook problem and because its scope (a) and (b) are the only work in the whole Sapience cluster that touches modules/home/core/dotfiles.nix -- the claudeSettings activation entry and its enforced-key list -- which 142's already-written plan explicitly declares out of its own scope. 144 follows: its three gaps (a sops-backed tokenFile, the sourceDirs registration decision, declarative lingering) are independent of the hook problem, and its own text already instructs the implementer to coordinate rather than duplicate should it reach the same activation entry; co-batching is what makes that instruction checkable instead of aspirational. 142 is listed last and wave dispatch will skip it until its recorded predecessor clears -- it stays in the batch regardless, because an unmet predecessor is an ordering constraint, never grounds for dropping a member, and because it shares docs/sapience.md and modules/home/services/sapience.nix with 144.

  Two exclusions here are deliberate rather than overlooked, and are stated because a bare exclusion is indistinguishable from an oversight. First, no dependency edge is added between 141 and 142, even though 142's plan Phase 2 builds scripts/check-sapience-hooks.sh -- precisely the between-activations detector 141's own scope (c) still treats as an open siting question. The substantively correct direction would be 141-after-142, since 142's plan has already answered that siting question (detector in this repository, wired entryBefore ["claudeSettings"] so it reads live pre-merge state); but wiring that edge would park the one dispatchable task in this cluster behind 142, which is itself parked behind an owner-parked measurement. The ordering is therefore carried here in prose instead of in the graph: whoever takes 141 must read 142's plan Phase 2 and adopt its siting decision rather than build a second detector. Second, no edge is added between 144 and 142, 139 or 136 despite all four declaring docs/sapience.md, home.nix and modules/home/services/sapience.nix, for the same reason -- every would-be predecessor in that set is stalled behind the parked measurement, and an edge there would park dispatchable work behind something no task in this system can unblock.
- This pair sits second rather than first because neither member is attendable, and it is kept as a batch rather than dissolved so that neither task gets auto-suggested as ready work without this context attached. 136 is parked at the owner's request. Its status is deliberately unchanged -- it remains IMPLEMENTING, not held and not abandoned -- because parking here is an ordering signal about what to pick up next, not a lifecycle transition; its own shape already resists dispatch, since it is a series of five or more hand-run extraction passes spaced across more than a week, not something a single run can discharge. 139 is not merely sequenced after 136 by judgment, it is blocked behind it in the live graph, and that edge is kept rather than relaxed to make the batch look more actionable: 139's three levers -- NO_CLASSIFY=1, caching classifier verdicts the way source_skip verdicts are already cached, or accepting and documenting the cost -- can only be weighed against a measured backlog denominator that only 136 produces. 139's other recorded predecessor, the local-inference diagnosis, is now discharged, so 136 alone is what holds it.

  This pair also carries the whole cluster's stall, which is why reopening the measurement window is worth more than it looks. 142's own edge onto 136 is the sole reason the lead batch's third member cannot dispatch, and that edge is a shared-territory serialization over docs/sapience.md, home.nix and modules/home/services/sapience.nix rather than a content dependency -- nothing in 142's plan reads a coverage figure or a backlog denominator. Reopening the window therefore unblocks two tasks, not one.
- These five share file territory across config/config.kdl, docs/niri.md and the power/idle surface, which makes one batch mandatory even though it serializes to near width 1. 124 opens it because the wake-mark resume hook is 117's recorded predecessor and lid-close behavior cannot be judged while resume is still wrong. 77 reconciles the background services, 120 then layers AC/battery-conditional idle suspend on the session 77 settled, and 78 closes the batch because it is a documentation rewrite: writing docs/niri.md while service reconciliation and idle policy are both still open guarantees a second rewrite. 124 and 117 are both already PARTIAL, so work is on disk and unverified in each -- finishing them is cheaper than re-deriving where they stopped.
- Both tasks build on the same systemd user-unit surface: 125 contains each Claude session in its own scope and reaps abandoned ones, 131 installs the claude-refresh timer modeled on that same reaper module and makes its mako prompts actionable. Running them together warms one context rather than two. No dependency edge is asserted between them: 131's own text states that its (a), (c) and (d) items can land first, and its only declared predecessor is a sibling task in the nvim repository, so co-membership here is ordering judgment, not evidence of a missing graph edge. One collision to keep visible: 131 item (c) adds a mako criteria section and 77 in the preceding batch also declares modules/home/desktop/mako.nix, so this batch running after that one is the right order -- reconcile the service behavior first, then add notification criteria on top.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 15,19,23,43,46,67,68,126
/orchestrate 133
```

## Open work

**Nixos config (5)**
```
117 PARTIAL         laptop_lid_close_no_sleep_headless
124 PARTIAL         fix_wake_mark_resume_hook_wiring
125 PARTIAL         claude_session_scope_containment_and_reaper
126 ready           nix_fmt_whole_tree_formatter_drift
133 ready           restructure_nix_configuration_layout
```

**Nix infrastructure (2)**
```
67 ready            migrate_r_env_back_to_stable_nixpkgs
68 ready            fix_broken_zfs_kernel_installer_builds
```

**Services (6)**
```
136 IN FLIGHT       Measure Sapience capture coverage under manual extraction and decide whether ...   <- parked for now; the measurement window is 5+ hand-run passes over 1+ week, not one dispatch
19 ready            install_setup_mcp_servers_web_development
23 ready            install_simple_webcam_recording_software
43 ready            install_forgejo_self_hosted_git
46 ready            investigate_fix_gmail_oauth2_token_expiry
131 ready           Install claude-refresh timer via home-manager and make mako idle-Lean-tree pr...
```

**Desktop (3)**
```
78 blocked:77,120   niri_documentation_rewrite
120 blocked:77      niri_ac_battery_conditional_idle_suspend
77 ready            niri_gnome_service_reconciliation
```

**Maintenance (1)**
```
15 ready            configure_timezone_location_based
```

**Packaging (2)**
```
41 BLOCKED          reenable_pdf2docx_nixpkgs_fix
42 BLOCKED          reenable_jupytext_nixpkgs_fix
```

**Sapience (1)**
```
139 blocked:136     reduce_sapience_classifier_cost   <- needs 136's measured backlog; not attendable while 136 is parked
```
The packaging pair (41, 42) is waiting on upstream nixpkgs fixes rather than on anything in this repository, so neither appears in a batch above.

## Checks before and after every call

- Before: `git status --short` is clean, or every pending change is one this call intends to
  touch; confirm the task's `file_scope` covers what the work will edit.
- Before: a task whose edit target is a source-store path (resolvable through
  `.claude-extensions.json`'s `source_dir`) is edited there, never under `.claude/**`, which is a
  regenerated deploy artifact.
- After: the relevant build gate above passes for whatever was touched -- a `modules/system/**`
  edit rebuilds the system closure, a `modules/home/**` edit rebuilds the Home Manager closure.
- After: `bash .claude/scripts/validate-state.sh specs/state.json` reports no NEW findings beyond
  the pre-existing one named in `## Gate state`.
- After: commits are scoped through `.claude/scripts/git-commit-scoped.sh` with an explicit file
  list -- never a directory or glob pathspec.

## Settled decisions (do not re-litigate)

- Configuration is flake-based with pinned inputs. Channels are not reintroduced.
- `configuration.nix` and `home.nix` stay thin import shims; real configuration lives in
  `modules/system/**` and `modules/home/**`.
- `.claude/**` is a disposable deploy artifact regenerated from the extension source store.
  Hand-authored files there are wiped by the next regeneration, so edits go to the source.
- `## Next` and `## Open work` in this file are generated. Judgment about batch membership,
  order, description and rationale lives in `specs/state.json`'s `roadmap_batches` /
  `roadmap_notes`, maintained through `/roadmap`.

## Standing rules

- Push and pull-request creation are user actions. An agent commits locally and stops.
- Batching related open tasks into one invocation is the default operating mode; shared file
  territory is a reason to batch, serialized if need be, never to exclude.
- A task parked by the owner keeps its lifecycle status. Parking is recorded as roadmap ordering
  and annotation, not as a status transition.
- An upstream-blocked task stays visible in `## Open work` and out of `## Next`.

## Unfiled observations (none worth a task yet)

- Task 126's `file_scope` lists only `modules/home/email/aerc.nix` and `.github/workflows/ci.yml`,
  while its actual work is a whole-tree formatter run. The understated scope would let it
  co-dispatch with tasks it will in fact collide with.

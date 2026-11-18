# Phase 5 Handoff — Task 144

**Immediate Next Action**: Proceed to Phase 6 (operator checkpoint, full gate, convergence
proof). Per the team-lead's dispatch-level override (see below), run only the agent-executable
subset; do not run the operator-run tasks (sops edit, `sudo nixos-rebuild switch`) and do not
close Phase 6 as `[COMPLETED WITH EXCLUSIONS]`.

**Current State**: Phases 1-5 of
`specs/144_sapience_fresh_machine_declarative_gaps/plans/01_fresh-machine-declarative-gaps.md`
are `[COMPLETED]`, each committed as its own phase commit (`task 144 phase N: ...`). `nix flake
check` is green after every phase. `home.nix`, `modules/system/secrets.nix`,
`modules/system/users.nix`, `modules/home/services/sapience.nix` and `docs/sapience.md` all carry
this task's edits; `secrets/secrets.yaml` and `packages/sapience-flake/**` are untouched.

**Key Decisions Made**:
- Gap 1: `tokenFile` wired to a sibling sops secret (`sapience_token`, same owner/mode-0400 shape
  as `anthropic_api_key`), set as a quoted string in `home.nix`.
- Gap 2: resolved as option (b) — registration stays manual; reasoning recorded in the
  `sourceDirs` option description, the `home.nix` comment, and `docs/sapience.md`.
- Gap 3: `users.users.benjamin.linger = true` added declaratively in `modules/system/users.nix`;
  a new `sapienceLingerNotice` activation entry (gated on `cfg.backgroundSync`) probes actual
  linger state rather than WSL-ness.
- **Dispatch-level override, received from the team lead before Phase 6 work began**: despite
  `.decisions.json`'s recorded user answer ("run the Phase 6 operator sequence yourself"), `sudo`
  is structurally denied in this harness, so the agent must NOT attempt the operator-run tasks
  and must NOT close Phase 6 `[COMPLETED WITH EXCLUSIONS]` (overriding the plan's own Decision 4
  / Phase 6 closure rule). Instead: run Phase 6's agent-executable tasks only, print the operator
  command sequence into the summary as a clearly-labelled checkpoint, and leave Phase 6 open
  (not `[COMPLETED]`, not `[COMPLETED WITH EXCLUSIONS]`) pending that human step.

**Deviations from Plan**:
- Phase 1: `modules/system/secrets.nix` restructured from three top-level `secrets."x" = ...;`
  statements into one nested `secrets = { "x" = ...; ... };` attrset — `statix`'s repeated-key
  lint fires at 3 occurrences (2 is fine), which the naive third `secrets."sapience_token"`
  addition tripped.
- Phase 1: the plan's literal `grep -nE 'tokenFile *= *[^"]' home.nix` quoting-check is
  non-discriminating (a quantifier artifact; also "matches" the already-correct `apiKeyFile`
  line). Used the corrected single-space form instead.
- Phase 1: the scratchpad non-interactive demonstration needed the built script's
  `~/.sapience/*` paths further redirected into an isolated scratchpad directory (beyond
  substituting just the token path), to avoid touching real vendor state.
- Phase 5: one new sentence briefly introduced forbidden record-versioning phrasing ("no longer
  prompts"); caught and reworded before this phase closed.
- Phase 5: the plan's own Scope Hypothesis undercounts its "Files to modify" list (says "three"
  `### ...` sections, lists four) — 7 regions touched, not 6; noted inline, not treated as an
  actual scope violation since it matches "Files to modify" exactly.

**What NOT to Try**:
- Do not run `sapience-bootstrap` or any shell demonstration against the REAL
  `~/.sapience/config.json` / `~/.sapience/*` paths — redirect to an isolated scratchpad copy
  first (see Phase 1's deviation above).
- Do not attempt `sudo` from inside this dispatch (denied).
- Do not re-run a bare `nix flake check` foreground Bash call without an explicit `timeout`
  parameter on the tool call itself (it defaults to 120s and gets auto-backgrounded, which this
  agent must not wait on via Monitor/background — stop the background task and retry with an
  explicit longer tool-level timeout instead).

**References**: plan at
`specs/144_sapience_fresh_machine_declarative_gaps/plans/01_fresh-machine-declarative-gaps.md`;
current phase 5 (complete); next phase 6.

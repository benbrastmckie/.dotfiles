# Implementation Plan: Reorganization Design + Subtask Orchestration

- **Task**: 81 - reorganize_nixos_dotfiles_repository_design
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**:
  - reports/01_repo-organization-review.md (seed inventory)
  - reports/02_team-research.md (synthesized 4-teammate design + decomposition)
- **Artifacts**: plans/03_reorg-design-and-subtasks.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/context/workflows/task-breakdown.md
- **Type**: markdown

## Overview

This is a DESIGN + ORCHESTRATION meta-task. The deliverable is NOT to move any files in the
NixOS/Home Manager tree. It is to (1) record a single canonical **target-layout design
document** that all reorganization subtasks will reference, (2) enumerate an ordered,
dependency-sequenced **blueprint of ~10 reorganization subtasks** drawn from the research, (3)
codify the **migration-safety strategy** (incremental ordering, CI backstop, git-add-before-verify
protocol, runtime-vs-build verification), (4) explicitly **resolve or defer the open design
decisions** the research flagged, and (5) **create the subtasks** via `/task` (each with a seed
research report) and record their numbers back into the design document. Definition of done: a
committed design document under this task's directory plus ~10 created subtasks in state.json/TODO.md
whose numbers and dependency ordering are recorded in that document.

### Research Integration

- **reports/02_team-research.md** (primary): supplies the adopted target directory tree, the
  resolved design-question decision table, the ordered 10-subtask three-tier decomposition,
  the migration philosophy (incremental, never big-bang), the four resolved conflicts, and nine
  coverage gaps that must be carried forward. Every phase below draws its substance from this
  report; no design decision in this plan is invented beyond it.
- **reports/01_repo-organization-review.md** (seed): supplies the concrete current-repo inventory
  (which files are dead, which are doc-referenced, out-of-tree coupling map, the task-66
  verification harness baseline) that the subtask scopes cite.

### Prior Plan Reference

No prior plan. This is plan version 1 (artifact round 03) for task 81.

### Roadmap Alignment

`specs/ROADMAP.md` exists but currently contains no populated items ("No items yet"), and
`roadmap_flag` is false for this dispatch, so no roadmap review/update phases are added. Phase 5
still records the created subtask numbers so a later `/todo` completion pass can annotate the
roadmap if items are populated.

## Goals & Non-Goals

**Goals**:
- Produce one canonical target-layout design document under the task directory that all
  reorganization subtasks reference (single source of truth for the target tree + resolved
  decisions).
- Enumerate the ordered ~10-subtask blueprint (title, one-line scope, dependencies, suggested
  task_type, tier, verification protocol) exactly as synthesized by the research.
- Codify the cross-cutting migration-safety protocol so every subtask inherits it: incremental
  landing, the `nix flake check` CI gate, git-add-before-verify (`root = self`), and
  runtime-vs-build verification for the two behavior-changing subtasks.
- Record explicit dispositions (resolve-now / resolve-in-subtask / defer) for every open design
  decision the research flagged as a gap.
- Create the subtasks mechanically via `/task`, each seeded from the relevant report sections,
  and record their assigned numbers + dependency waves back into the design document.

**Non-Goals**:
- Moving, renaming, deleting, or editing any file in the Nix-managed tree (`modules/`, `hosts/`,
  `config/`, `overlays/`, `lib/`, `packages/`, `secrets/`, root `*.nix`). That is the work of the
  created subtasks, not this task.
- Touching `.claude/`, `.memory/`, `.opencode/`, or `specs/` content (out of scope per research
  scope boundary).
- Adopting flake-parts or snowfall-lib, renaming `config/`, adopting `assets/`, adopting a
  generic `readDir`/`mapModules` auto-import layer, or `profiles/` layering (all explicitly
  rejected by the research).
- Resolving tasks 67, 68, 69 as independent engineering work (69 is a documentation-only closure
  folded into a subtask; 67/68 are adjacent and only sequenced around, not duplicated).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Plan phases collapse the reorg into one big-bang subtask, contradicting the research | H | M | Phase 2 fixes the subtask count at 10 discrete tasks across three tiers; the design doc states plainly "queue of small independently-landable subtasks, never one reorg PR". |
| Created subtasks omit the git-add-before-verify protocol and hit stale-success failures (`root = self`) | H | M | Phase 3 bakes the protocol into the design doc's cross-cutting section, and Phase 5 injects it into every subtask's seed so it is inherited, not a one-time note. |
| Behavior-changing subtasks (module opt-in, discord-bot packaging) verified with build-only harness, missing runtime path breakage | H | M | Phase 3 + Phase 4 flag subtasks 5 and 8 as behavior-changing requiring `switch` + `systemctl`/`journalctl` checks, recorded in their seeds by Phase 5. |
| Strategic Tier-1 subtask (module convention + per-host opt-in) buried late, blocking task 77 | M | M | Phase 2 preserves the research's three-tier priority ordering; the Tier-1 subtask is sequenced before task 77 dispatch and marked highest-leverage. |
| Subtask creation drifts from research scope (e.g., re-adopts rejected ideas) | M | L | Phase 4 records explicit rejected/deferred dispositions; Phase 5 seeds each subtask directly from the corresponding research subtask row + scope corrections. |
| `/task` creation partially completes, leaving orphaned/uncorrelated task numbers | M | L | Phase 5 creates subtasks in dependency order, records each number into the design doc as it is created, and verifies state.json/TODO.md consistency at the end. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave are logically independent. If executed by a single agent, the Wave-2
phases append distinct, non-overlapping sections to the shared design document.

### Phase 1: Author the Canonical Target-Layout Design Document [NOT STARTED]

**Goal**: Create the single design artifact that all reorganization subtasks will reference,
capturing the adopted target directory tree, the resolved design-decision table, and the
explicit Nix-tree-only scope boundary.

**Tasks**:
- [ ] Create `specs/081_reorganize_nixos_dotfiles_repository_design/design/` and write
  `target-layout.md` as the canonical design document.
- [ ] Transcribe the adopted target directory tree from research §"Recommended Target Directory
  Layout" (thin root `configuration.nix`/`home.nix` kept at root; new
  `modules/{system,home}/default.nix` aggregators; new `scripts/` dir; new `.github/workflows/`
  CI gate; explicit per-host wiring; the `email/agent-tools/` split; `packages/misc.nix` merges;
  `shell.nix`->`dotfiles.nix` rename).
- [ ] Reproduce the resolved design-question decision table (options-pattern scoped adoption,
  explicit per-host wiring over `pathExists` auto-discovery, keep-`config/`-name, reject
  flake-parts/snowfall, in-tree `buildPythonApplication` for the discord bot, etc.) with the
  supporting rationale summarized per row.
- [ ] State the explicit scope boundary: task 81 and its subtasks touch only the Nix-managed tree
  (`modules/`, `hosts/`, `config/`, `overlays/`, `lib/`, `packages/`, `secrets/`, root `*.nix`);
  `.claude/`, `.memory/`, `.opencode/`, `specs/` are untouched. Note the `.claude/` vs
  `config/claude/` naming collision so it is never conflated.
- [ ] State the migration philosophy headline: an incremental, strictly ordered queue of small,
  independently-verifiable subtasks -- never a single reorg PR.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - create the
  canonical design document (target tree + decision table + scope boundary + philosophy).

**Verification**:
- Design document exists and its target tree + decision table match research report 02 with no
  invented decisions.
- Scope boundary and incremental-not-big-bang philosophy are stated explicitly.

---

### Phase 2: Enumerate the Ordered Subtask Blueprint [NOT STARTED]

**Goal**: Record the ordered ~10-subtask decomposition (the blueprint for later `/task` creation)
as a section of the design document, preserving the research's three value tiers and per-subtask
scope, dependencies, suggested task_type, and verification protocol.

**Tasks**:
- [ ] Add a "Subtask Blueprint" section to the design document with one row per subtask, drawn
  from research §"Recommended Subtask Decomposition": # / tier / title / one-line scope /
  depends-on / suggested task_type / verification level.
- [ ] Preserve the three-tier ordering exactly: Tier 0 (subtasks 1-4: dead-code removal, git
  hygiene, NEW CI gate, root scripts->`scripts/`); Tier 1 (subtask 5: module convention +
  aggregators + per-host discord-bot opt-in -- highest leverage, sequence before task 77); Tier 2
  (subtasks 6-9: hosts/ cleanup, module granularity, discord-bot packaging, config/ doc clarity);
  Final (subtask 10: documentation sync, gated on 1-9).
- [ ] For each subtask, fold in the Critic's scope corrections (e.g., subtask 1 widens
  `test-mcphub.sh` removal to patch its three doc references and drops the resolved
  `config/rclone.conf` step; subtask 2 keeps `specs/tmp/` on disk while untracking its contents).
- [ ] Assign a suggested `task_type` per subtask (default `nix`; `markdown` for doc-only subtasks
  9 and 10; `nix` for the CI-gate subtask 3 since it adds a flake-check workflow).
- [ ] Mark subtasks 5 and 8 as intentionally behavior-changing (not inert).
- [ ] Record the inter-subtask dependency graph as a wave table (Tier 0 subtasks 1-4 parallel;
  subtask 5 self-contained; 6/7/8 depend on 5; 9 depends on 7; 10 depends on 1-9).

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - append the
  "Subtask Blueprint" section (10 rows + inter-subtask wave table).

**Verification**:
- Blueprint lists exactly 10 subtasks in the research's three-tier order with dependencies,
  task_type, and behavior-changing flags recorded.
- Every Critic scope correction from research report 02 is reflected in the corresponding row.

---

### Phase 3: Codify the Migration-Safety Strategy [NOT STARTED]

**Goal**: Record the cross-cutting verification and safety protocol every subtask inherits, so it
is enforced per-subtask rather than left as a one-time note.

**Tasks**:
- [ ] Add a "Migration Safety & Verification" section to the design document.
- [ ] Document the **git-add-before-verify protocol**: because `flake.nix` uses `root = self`,
  every move/create/delete subtask must `git add <specific paths>` (never `git add -A`)
  immediately before running the nix verification harness, or the harness silently checks the
  stale tracked layout.
- [ ] Document the baseline verification harness (task-66 lineage): `nix flake check` +
  `nixos-rebuild build --flake .#nandi/.#hamsa/.#garuda` +
  `nix build .#homeConfigurations.benjamin.activationPackage` + `nix store diff-closures` for
  closure-equivalence; iso/usb-installer excluded (task 68 broken zfs-kernel state).
- [ ] Document the **runtime verification requirement** for behavior-changing subtasks 5 and 8:
  `nixos-rebuild switch` + `systemctl status`/`journalctl` confirming closure membership changes
  (e.g., hamsa drops the Discord bot's Python closure, nandi gains it; discord-bot ExecStart
  points at a store path, not `$HOME`). Build-only diff cannot observe runtime path literals.
- [ ] Document the **CI-gate rationale**: subtask 3 adds a `nix flake check` GitHub Actions
  workflow that closes the drift-discovered-late gap behind tasks 67/68/69; note it as first-class
  Tier-0, not optional.
- [ ] State the inertness contract: all subtasks except 5 and 8 hold to strict closure
  equivalence; 5 and 8 are behavior-changing by design.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - append the
  "Migration Safety & Verification" section.

**Verification**:
- git-add-before-verify protocol, the build harness, the runtime checks for subtasks 5/8, and the
  CI-gate rationale are all documented.
- The inertness-vs-behavior-changing contract is explicit and consistent with Phase 2's flags.

---

### Phase 4: Resolve or Defer Open Design Decisions [NOT STARTED]

**Goal**: Give every open decision the research flagged an explicit disposition
(resolve-now / resolve-within-a-named-subtask / defer-as-follow-on), so the task-creation phase
and future contributors never have to re-litigate them.

**Tasks**:
- [ ] Add an "Open Decisions & Dispositions" section to the design document.
- [ ] Record **resolve-now** dispositions carried by the design itself: explicit per-host wiring
  over auto-discovery (Conflict #2); keep `configuration.nix`/`home.nix` at root (sidesteps the
  task-69 relocation-sequencing concern); scope the options pattern to optional/host-toggled
  modules and amend `.claude/rules/nix.md` accordingly.
- [ ] Record **resolve-within-subtask** dispositions: task 69 dual-home-manager as a
  documentation-only closure ("Option A retained, documented") folded into subtask 5 or 10;
  `agent-tools.nix` split boundaries finalized during subtask 7 planning by reading the full file;
  `config/` deployment-mechanism documentation in subtask 9.
- [ ] Record **defer-as-follow-on** dispositions: discord-bot extraction to its own repo/flake
  input (after interface stabilizes, mirroring the email-extension precedent); `assets/`
  directory (only when a second asset class appears); `config/`->`dotfiles/` rename; `profiles/`
  layering; per-host secrets colocation; the generic auto-import library.
- [ ] Record the **verified-non-issues** to prevent false-positive rediscovery: `flake.lock`
  health and `stateVersion` values are confirmed fine (note as "checked, no action needed" for
  subtask 10); `config/claude/` activation force-overwrite is pre-existing intended behavior that
  subtask 9 must preserve and flag, not fix.
- [ ] Note the sequencing constraint that task 78 (niri docs) should adopt but not merge with this
  reorg's doc convention.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - append the
  "Open Decisions & Dispositions" section.

**Verification**:
- Every gap enumerated in research report 02 §"Coverage Gaps" has an explicit disposition
  (resolve-now / resolve-in-subtask N / defer / verified-non-issue).
- No decision the research rejected is left ambiguous or reopened.

---

### Phase 5: Create Subtasks and Record Numbers [NOT STARTED]

**Goal**: Mechanically create the 10 reorganization subtasks via `/task`, each seeded from the
relevant design + report sections, then record their assigned numbers and dependency waves back
into the design document.

**Tasks**:
- [ ] For each of the 10 blueprint subtasks, run `/task "<title>"` with the suggested `task_type`,
  a description drawn from its blueprint row, and a `parent_task: 81` linkage; include the
  inherited cross-cutting protocol (git-add-before-verify, verification level) in the description.
- [ ] Seed each subtask with a pointer to (or an extracted excerpt of) the relevant sections of
  reports/01 and reports/02 and this design document, so each has its own starting research
  context per the task requirement.
- [ ] Create subtasks in dependency order; as each number is assigned, record it into the design
  document's "Subtask Blueprint" table (fill in the actual task number and set inter-subtask
  `depends_on` using the real numbers).
- [ ] Add a "Created Subtasks" summary table to the design document mapping blueprint # -> real
  task number -> status, plus the dependency wave ordering with real numbers.
- [ ] Verify state.json and TODO.md are consistent after creation
  (`bash .claude/scripts/generate-todo.sh` if any manual state edits were made) and that all 10
  subtasks appear with `[NOT STARTED]`.
- [ ] Record roadmap linkage: note in the design document which subtasks advance repository-health
  goals so a later `/todo` completion pass can annotate `specs/ROADMAP.md` (read-only here; do not
  edit ROADMAP.md).

**Timing**: 2 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- `specs/state.json` - new subtask entries (via `/task`).
- `specs/TODO.md` - regenerated from state.json (via `/task` / `generate-todo.sh`).
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - fill in real
  task numbers, add "Created Subtasks" mapping table + roadmap linkage note.

**Verification**:
- 10 subtasks exist in state.json and TODO.md, each `[NOT STARTED]`, each with `parent_task: 81`.
- The design document's blueprint and "Created Subtasks" tables reference the real assigned task
  numbers with correct dependency ordering.
- ROADMAP.md is unmodified.

---

## Testing & Validation

- [ ] `design/target-layout.md` exists and contains all five sections: target tree, decision
  table, subtask blueprint, migration-safety, and open-decision dispositions.
- [ ] The subtask blueprint lists exactly 10 subtasks in three tiers matching research report 02.
- [ ] Every coverage gap from research report 02 has an explicit disposition in the design doc.
- [ ] Subtasks 5 and 8 are marked behavior-changing with runtime verification requirements.
- [ ] The git-add-before-verify protocol is documented as a per-subtask inherited requirement.
- [ ] 10 subtasks created and visible in TODO.md as `[NOT STARTED]`, numbers recorded in the
  design document.
- [ ] `specs/ROADMAP.md` unmodified; state.json and TODO.md consistent.

## Artifacts & Outputs

- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` - the canonical
  reorganization design document (target tree, decisions, subtask blueprint, migration-safety,
  open-decision dispositions, created-subtask mapping).
- 10 new subtasks in `specs/state.json` / `specs/TODO.md`, each seeded and dependency-ordered,
  linked to parent task 81.
- Updated `.return-meta.json` for task 81 with plan metadata (written by the planner at plan
  creation; final subtask numbers recorded in the design doc during Phase 5 execution).

## Rollback/Contingency

- Phases 1-4 write only to a new design document under the task directory; to revert, discard or
  `git checkout` `design/target-layout.md` (no Nix-tree or shared-state changes occur).
- Phase 5 mutates `specs/state.json` / `specs/TODO.md`. If subtask creation is interrupted or
  incorrect, abandon the erroneously-created subtasks via `/task --abandon N` (moves to archive)
  and re-run creation for the remainder; the design document's running number-map identifies
  exactly which subtasks were already created, making resume deterministic.
- No file in the Nix-managed tree is touched by this task, so no `nixos-rebuild`/closure rollback
  is ever required at this stage; that responsibility belongs to the individual subtasks.

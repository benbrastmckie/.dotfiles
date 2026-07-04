# Research Report: Horizons — Strategic Alignment for the Reorganization (Teammate D)

**Task**: 81 — Design and orchestrate a systematic reorganization of the NixOS/Home Manager
dotfiles repository
**Angle**: Long-term alignment and strategic direction
**Date**: 2026-07-04

## Key Findings

### 1. The seed decomposition is sound but under-weights the highest-leverage item

The seed report's candidate list (items 1-9) is ordered by risk/independence, which is the right
axis for *sequencing*, but not the right axis for *priority*. Re-reading it against the five
adjacent open tasks (67, 68, 69, 77, 78) and the repo's actual trajectory (niri adoption, email
automation, multi-host, AI tooling coupling), one item dominates the others in strategic value:
**candidate #7, the module convention decision (options pattern + real per-host opt-in)**. It is
currently ranked 7th-of-9 by "independence and risk," but it is the one piece of technical debt
that is actively causing incidents in *other* tasks:

- `modules/system/optional/discord-bot.nix` is imported unconditionally by `configuration.nix`
  despite its `optional/` directory name — every host (nandi, hamsa, garuda) gets the Discord
  bot whether or not that host should run it.
- `hosts/garuda/default.nix` is an empty placeholder yet is explicitly wired via `extraModules`
  (`flake.nix:111-113`), while nandi and hamsa have no `default.nix` at all — i.e. the
  "per-host module selection" mechanism exists in the flake's plumbing but is not actually used
  by any host today. This is a half-built abstraction, not a working one.
- Task 77 (niri/gnome service reconciliation) is *exactly* the kind of problem that a real
  per-host/per-session opt-in convention would make tractable: it needs to know, declaratively,
  which hosts/sessions run niri (waybar/swaybg/mako/swayidle) vs pure GNOME
  (gnome-settings-daemon, gsd-power) so the overlap logic in `configuration.nix` /
  `modules/system/desktop.nix` can be conditioned rather than reconciled by hand per incident.
  Right now task 77's scope is entirely "confirm behavior empirically and patch"; a
  `services.niriSession.enable` (or similar) option surfaced through `hosts/<name>/default.nix`
  would let the reconciliation be expressed as config rather than tribal knowledge.

**This means the reorg and task 77 are not really independent work streams — they compete for
the same yet-to-be-built convention.** If task 81 lands the options-pattern decision and the
`hosts/*/default.nix` opt-in convention *before* 77 is dispatched, 77 gets dramatically cheaper
(it becomes "wire the new option" instead of "invent the mechanism ad hoc, again"). Doing it in
the other order means 77 invents a one-off mechanism that the reorg later has to reconcile or
discard. **Recommendation: sequence candidate #7 before task 77, not after items #1-6.**

### 2. Task 69 (dual home-manager) is a decision task masquerading as a bug, and the reorg can supply the missing decision framework

Reading `docs/dual-home-manager.md` closely: the *bug* half of task 69 (the `extraSpecialArgs`
asymmetry that caused the lectic regression) is already noted as "resolved" as of task 66 — both
paths now pass identical `extraSpecialArgs`. What remains open is the **Option A/B/C
architectural question** the doc poses ("keep both," "drop standalone," "drop NixOS-integrated"),
which the doc explicitly punts with "Current Recommendation: keep both... until workflow impact
is measured." Task 69 is stalled on a judgment call, not a technical blocker.

This is precisely the kind of judgment call a repo-wide reorganization pass should resolve,
because the right answer depends on the very conventions this task is designing:
- If task 81 adopts a `hosts/<name>/default.nix` opt-in convention (per finding #1) that lets
  *some* hosts skip the NixOS-integrated home-manager path entirely (e.g. a future lightweight
  server host with no interactive user session), the dual-path question becomes
  per-host-conditional rather than global — a third option the current doc doesn't consider.
- If the reorg's documentation-sync subtask (#3) is going to touch `docs/dual-home-manager.md`
  anyway (it's one of the "exists but unlisted in docs/README.md index" files flagged in the
  seed report), that is the natural place to either (a) make the keep-both decision final and
  close task 69 as "no action, documented," or (b) if the maintainer wants to reduce evaluation
  overhead, fold "drop standalone" into the reorg's root-files subtask (#5, since
  `configuration.nix`/`home.nix` placement is already in scope there).

**Recommendation**: don't spawn task 69 as a fully separate effort — either resolve it as a
sub-decision inside subtask #5/#3 of the reorg (cheap, since the files are already being touched
for other reasons), or explicitly close it with "Option A retained, documented" if the maintainer
has no appetite for the migration risk of B/C. Leaving it as an independent backlog item invites a
third pass over the same root files that the reorg is already going to make two passes over.

### 3. Task 78 (niri docs rewrite) should NOT be absorbed into the reorg's doc-sync subtask, but should adopt whatever README convention the reorg establishes

These two tasks look similar (both touch `docs/`) but are different kinds of work: task 81's
doc-sync candidate (#3) is *structural* (root README Module Map accuracy, `docs/README.md` index
completeness, a missing `modules/README.md`), while task 78 is *content* (niri keybinding-table
accuracy against `config/config.kdl`, PaperWM-content quarantine, GNOME-hybrid architecture
narrative). Merging them would make task 78 — which already depends on 74-77 landing first —
also depend on the reorg's full convention-decision phase, adding a needless dependency edge.

What *should* transfer: if task 81 establishes a `modules/README.md` pattern and a "living docs
generated/checked against source" discipline (e.g., a doc-lint script per the `.claude/scripts/
check-extension-docs.sh` pattern already used elsewhere in this Claude Code system), task 78
should follow that same convention for `docs/niri.md`'s keybinding table, so the whole repo
converges on one documentation-freshness pattern instead of niri docs being bespoke. Recommend
the reorg's doc-sync subtask explicitly write down "docs must be verified against source, not
just fixed once" as a repo convention (a doc-lint precedent, not necessarily automated tooling
yet) that task 78 can cite rather than re-derive.

### 4. Big-bang vs incremental: incremental wins decisively for a single-maintainer, high-velocity repo

The git log shows very high task throughput (roughly one task per session, many same-day) with
tight, verified, single-purpose commits. This repo's actual operating cadence is small, gated,
independently-verifiable changes — that is the same shape the seed report's candidate list
already takes for items #1-4 (dead code, git hygiene, doc sync, script relocation), and it should
stay that shape all the way through #5-9. A "systematic reorganization" framing invites treating
this as one big master plan/PR; the evidence in this repo (task 66's own phased, closure-diff-
gated refactor; the niri work 74-77 done as four small sequential tasks off one seed) says the
opposite pattern is what actually ships here. **Recommendation: task 81's design-phase output
should be a strictly ordered task queue of small, independently landable subtasks (as already
sketched), explicitly NOT a single reorg PR — and the design document should say so, to prevent
a future planner from collapsing it back into one big-bang phase list "for efficiency."**

### 5. Maintainability investment (options pattern, per-host opt-in, a cheap CI gate) should outrank cosmetic moves

Ranking the seed's candidates by actual risk-reduction value rather than mechanical risk:
- **High value, currently under-ranked**: #7 (options pattern + real per-host opt-in — see
  finding #1), and a new candidate not in the seed list: **a pre-commit or CI `nix flake check`
  gate**. This repo has zero CI today (`.github/` does not exist, though the GitHub remote does —
  `git@github.com:benbrastmckie/.dotfiles.git`) and no pre-commit hook, despite three of the last
  ~15 tasks (67 R-env/ICU, 68 zfs-kernel installer, 69 lectic specialArgs) being exactly the
  class of "a nixpkgs/host-drift break only caught by a full rebuild, sometime later" that a
  cheap `nix flake check` gate run on every commit (or push, via GitHub Actions, which is free
  for a personal repo) would catch immediately instead of during an unrelated task's final
  audit. This is a much better ROI than most of the cosmetic renames below, and it is *cheap*:
  a single workflow file plus (optionally) a git hook, no new module authoring effort. **Add this
  as a first-class candidate subtask, sequenced early (alongside #2 git hygiene), since it directly
  prevents the recurrence pattern that produced tasks 67-68.**
- **Medium value**: #5 (hosts/ standardization), #6 (module granularity — the `agent-tools.nix`
  761-line split and tiny-fragment merges), #8 (discord-bot packaging), #9 (`config/` deployment
  clarity/rename).
- **Low value, purely cosmetic, do last or make optional**: the `config/` → `dotfiles/` rename
  in particular is a "touch-everything" diff (every `home.file.*.source` reference, three
  deployment mechanisms) for a benefit that is purely naming-collision avoidance with the Nix
  `config` argument — a real but minor readability nit. Given this repo's actual pain points are
  option-pattern gaps and CI absence, not naming, this should be explicitly framed in the design
  doc as *optional, low priority, do only if a slow week presents itself* — not bundled into the
  same priority tier as #7.

### 6. Creative/unconventional options worth naming, and why to accept or reject each

- **Flake `nixosModules`/`homeModules` outputs for reuse.** Idiomatic in the wider Nix community,
  and *cheap to try partially*: `lib/mkHost.nix` already centralizes host construction, so
  exposing the current `modules/system/*` and `modules/home/*` trees as flake outputs consumed by
  `mkHost.nix` itself (self-dogfooding) costs little and pays off if the maintainer ever wants to
  (a) share a module with a future second flake/repo, or (b) extract `opencode-discord-bot` as
  its own flake input (see below) — the module system needs to already be output-shaped for that
  to compose cleanly. **Accept, but scope it as "expose what already exists," not "author a new
  public module API"** — over-engineering options/interfaces for a single consumer (this same
  flake) has no payoff yet.
- **`profiles/` layer (desktop/laptop/server) instead of pure per-host.** Rejected for now: there
  are only three real hosts (nandi, hamsa — both "Intel with KVM support, NVMe, USB 3.0/Thunderbolt"
  laptops/desktops per their READMEs, near-identical hardware class) plus garuda (placeholder) and
  the iso/usb-installer path. A profiles abstraction pays off when there are enough hosts with
  genuinely divergent *roles* (e.g., a headless server host) to justify the extra indirection;
  with 2-3 near-identical desktop/laptop hosts today, per-host `default.nix` opt-in (finding #1)
  is the right-sized abstraction. **Revisit `profiles/` only if/when a 4th host with a distinct
  role (e.g. headless, server, or a second niri-only machine) is added** — don't build it
  speculatively now.
- **Moving agent-tooling coupling out of the nix repo.** The repo already shows a working
  precedent for this: the email extension is "authored canonically in
  `~/.config/nvim/.claude/extensions/email/`" (a *different* repo) and merely *consumed* here via
  the wrapper binaries in `modules/home/email/agent-tools.nix` (per task 71/72's completion
  notes). The same split should be extended to `opencode-discord-bot/`: it is 2,392 lines of
  untracked-mixed Python with no packaging, run via `PYTHONPATH=~/.dotfiles/opencode-discord-bot`
  against the live working tree (a real reproducibility hazard — a `git pull` or accidental edit
  changes running-service behavior with no derivation pinning it). Of the seed report's two
  options for this (`buildPythonApplication` in-repo, or extract to its own repo as a flake
  input), **extract-to-own-repo is the better fit given the precedent already set by the email
  extension**, and it directly serves the "AI tooling" trajectory item by making the Discord bot
  independently testable/versioned (pytest, its own CI) rather than nix-repo-embedded source with
  no test harness at all.

### 7. Strategic challenges this task can help address, ranked

1. **Reproducibility of the Discord bot service** (finding #6) — real, already flagged, has a
   clear remediation path (extract-to-repo + flake input, or `buildPythonApplication`).
2. **Multi-machine divergence / the optional-module lie** (finding #1) — real and *active*
   (garuda placeholder vs nandi/hamsa no-file inconsistency; discord-bot force-imported
   everywhere), directly blocks task 77 from being cheap.
3. **Secrets growth** — currently minimal risk: one age recipient, one `secrets.yaml`, scoped by
   a single sops rule (`secrets/*.yaml`). No evidence of growth pressure yet (no multi-user, no
   per-host secret scoping need surfaced in any open task). **Low priority — note it, do not
   spend reorg budget on it until a second recipient or per-host secret actually appears.**
4. **CI absence** (finding #5) — not in the seed's list at all; recommend adding it as new
   candidate #10, sequenced early and cheaply.

## Recommended Approach

Restructure the seed's 9-item candidate list into three tiers, not one risk-ordered sequence:

**Tier 0 (do first, near-zero risk, unblocks nothing but costs nothing)**: seed items #1
(dead code), #2 (git hygiene), plus **new candidate #10: add a `nix flake check` CI workflow
(GitHub Actions, since the repo already has a GitHub remote) and/or pre-commit hook** —
this closes the exact gap that let tasks 67/68/69's underlying issues go undetected until a
full rebuild.

**Tier 1 (do second, unlocks adjacent open tasks — the actual strategic core)**: seed item #7
(options pattern + real per-host `default.nix` opt-in convention), sequenced *before* task 77 is
dispatched so 77 can consume the new convention instead of inventing one. Fold task 69's
remaining open decision (Option A/B/C) into this tier as a documentation-only resolution rather
than spawning further work, since the underlying bug is already fixed.

**Tier 2 (do third, lower-value/cosmetic, can slip or be dropped)**: seed items #3 (doc sync —
sequenced so task 78 can adopt whatever README/doc-freshness convention it sets, without merging
the two tasks), #4 (scripts/ dir), #5 (hosts/ standardization, now largely subsumed by Tier 1's
opt-in convention), #6 (module granularity), #8 (discord-bot packaging — recommend extract-to-
own-repo per finding #6), #9 (`config/` rename — explicitly flagged as optional/low-priority,
touch-everything).

Do **not** attempt this as a single reorganization PR or a single dispatch; the repo's own
operating history (small, gated, closure-diff-verified tasks) is the evidence for why. The
design document that comes out of task 81 should explicitly state the tiering above and instruct
the eventual task-creation step to preserve tier boundaries as separate tasks/dependency waves,
not collapse them.

## Evidence/Examples

- `flake.nix:111-113`: garuda is the only host wired through `extraModules`/`hosts/*/default.nix`,
  yet its `default.nix` is an empty placeholder — direct evidence the per-host opt-in mechanism
  exists in plumbing but is unused.
- `docs/dual-home-manager.md`: "As of task 66, both paths pass the same set of args" (bug fixed)
  vs. "Current Recommendation: Keep both paths... until the workflow impact of dropping one is
  measured" (decision still open) — task 69 is a stalled judgment call, not an open defect.
- `hosts/nandi/README.md` and `hosts/garuda/README.md`: near-identical hardware descriptions
  ("Intel with KVM support," "NVMe SSD," "USB 3.0 ... Thunderbolt support") — evidence against
  needing a `profiles/` abstraction yet; these are not divergent roles, just divergent machines
  of the same role.
- `git remote -v` → `git@github.com:benbrastmckie/.dotfiles.git`; `.github/` does not exist in
  the repo — confirms CI is genuinely absent, not just undiscovered, and GitHub Actions is
  immediately available at zero cost.
- state.json task 77 description: explicitly reconciling gsd/mako/swayidle/xwayland-satellite
  overlaps "depends on tasks 74-76 being applied" with no per-host or per-session conditional
  mechanism referenced — supports the claim that 77 currently has no declarative lever to pull
  and would benefit from Tier 1 landing first.
- state.json task 71/72 completion notes: the email extension is "authored canonically in
  `~/.config/nvim/.claude/extensions/email/`" and merely consumed here — the precedent finding
  #6 recommends extending to `opencode-discord-bot/`.

## Confidence Level

**Medium-high** on the sequencing recommendations (Tier 0/1/2 restructuring, task 77/78/69
interactions) — these are grounded in direct reads of `flake.nix`, `docs/dual-home-manager.md`,
`hosts/*/README.md`, and the state.json task descriptions, not speculation. **Medium** on the
`profiles/` rejection and the discord-bot extract-to-own-repo recommendation — these are
judgment calls about a single-maintainer repo's future needs, reasonable given current evidence
(host count, existing email-extension precedent) but not certainties; if the maintainer plans
near-term additional hosts with genuinely different roles, revisit the `profiles/` rejection.
**Low-medium** on secrets growth being a non-issue — this is based on absence of evidence
(no open task mentions secret scoping pressure) rather than a forward-looking risk analysis,
which was outside this angle's scope.

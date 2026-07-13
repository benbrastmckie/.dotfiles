# Research Report: Module Convention + Aggregators + Per-Host Discord-Bot Opt-In

- **Task**: 86 - Adopt the module convention (options + aggregators) and make the Discord bot a
  real per-host opt-in
- **Started**: 2026-07-05T05:13:38Z
- **Completed**: 2026-07-05T06:10:00Z
- **Effort**: Small-to-medium (≈10 files touched, no new packaging/logic — pure wiring +
  one options conversion)
- **Dependencies**: None (task 81 Tier 1, self-contained; sequenced before task 77's dispatch
  and before subtasks 87/88/89/90/91, all of which depend on 86)
- **Sources/Inputs**: see Appendix
- **Artifacts**: this report
- **Standards**: report-format.md, artifact-formats.md, git-workflow.md, state-management.md

## Executive Summary

- This machine (`hamsa`, confirmed via `hostname`) is currently running both
  `discord-bot.service` and `opencode-serve.service` — **live proof that hamsa silently gets
  the Discord bot today**, exactly the bug this task fixes. `discord-bot.service` is also
  presently crash-looping (`asyncio` traceback, unrelated pre-existing bug — out of scope, not
  to be fixed here).
- Root cause: `configuration.nix:26` imports `./modules/system/optional/discord-bot.nix`
  **unconditionally**, and `lib/mkHost.nix:30` hard-codes `configuration.nix` into every
  `mkHost`-built system (nandi, hamsa, garuda, usb-installer) plus `flake.nix:121` imports it
  directly a second time for `iso`. All five nixosConfigurations currently get the bot; only
  nandi is supposed to (per `configuration.nix:25`'s own comment: "enabled for nandi; may be
  removed for other hosts" — aspirational, not enforced).
- Fix has two independent halves: (1) convert `discord-bot.nix` to a real
  `options.services.discordBot.enable` + `mkIf` module (currently zero active modules use the
  options pattern anywhere in the repo); (2) stop importing it from the shared aggregator and
  instead opt in explicitly per-host via `hosts/nandi/default.nix` (new file) wired through
  `extraModules` in `flake.nix` — mirroring the existing `hosts/garuda/default.nix` +
  `extraModules` precedent already in the repo, not a new mechanism.
- Introducing `modules/system/default.nix` and `modules/home/default.nix` aggregators is a
  separate, orthogonal piece of this task (also required by the task description) — it replaces
  `configuration.nix`'s and `home.nix`'s flat 12-line and 33-line hand-maintained `imports`
  lists with a single `./modules/system` / `./modules/home` directory import, using Nix's
  directory-import convention (a directory containing `default.nix` is importable as itself).
- `.claude/rules/nix.md`'s "Module Patterns" section currently presents the options+`mkIf`
  structure as *the* module pattern with no scoping language, which is why report 01 (task 81
  seed) called it a contradiction with the repo's ~40 plain-config-set modules. The fix is
  additive: two labeled subsections ("Always-On Modules" vs "Optional/Host-Toggled Modules")
  making the scope explicit, not a rewrite of the existing examples.
- `docs/discord-bot.md:25-26`'s file table is already stale even before this task (attributes
  the bot to `configuration.nix`, when the file has lived at
  `modules/system/optional/discord-bot.nix` all along) and will become doubly wrong after this
  task (claims "module import on all 4 hosts"). Both lines need updating.
- `docs/dual-home-manager.md:31-33` makes an inaccurate claim ("both paths pass the same set of
  args") that `flake.nix:199-207`'s own comment contradicts (the two paths deliberately diverge
  on `lectic`: raw flake input vs. resolved package). Task 69's Option-A closure is a one-line
  correction to that claim, not a code change — cheap to fold into this task's doc edit.
- Two additional, previously-unflagged behavior changes fall out of the same root cause and
  should be captured in this task's runtime verification: `iso` (`flake.nix:118-175`) and
  `usb-installer` (`flake.nix:178-187`) currently also get the bot unconditionally via the same
  `configuration.nix` import path, and will legitimately stop getting it too. This is desirable
  (an install medium should not ship a bot toggle) but is additional blast radius beyond the
  nandi/hamsa pair named in the task description.

## Context & Scope

Task 86 is Tier 1 of task 81's ten-subtask reorganization (see
`specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`, blueprint row 5,
real task number 86). It is explicitly self-contained (no dependencies) and explicitly
behavior-changing — not covered by the standard build-only inertness harness used by every other
subtask in the reorg. Six pieces of work are in scope, per the task description; all six are
addressed below with exact files/lines and a concrete diff plan. `.claude/` and `specs/` remain
untouched (Nix-tree-only scope boundary, target-layout.md §1.2).

## Findings

### 1. Current repo state (evidence, file:line)

**Root import lists** (the two "flat hand-maintained import lists" the task asks to replace):
- `configuration.nix:8-27` — 12-entry `imports` list ending with
  `./modules/system/optional/discord-bot.nix` at line 26, under a comment
  (`configuration.nix:25`) that already says "enabled for nandi; may be removed for other
  hosts" — an aspiration the code has never enforced.
- `home.nix:5-50` — 33-entry `imports` list across 6 comment-delimited groups (core, desktop,
  email, packages, scripts, services). No optional/toggle modules in this list; nothing in
  `modules/home/` needs converting.

**The un-optional "optional" module**:
- `modules/system/optional/discord-bot.nix` (113 lines) — plain attribute set, function
  signature `{ config, pkgs, username, ... }:` (no `lib`). Defines `discordBotPython` (let
  binding), a `sops.secrets` block (5 secrets), and `systemd.services.{opencode-serve,
  discord-bot}`. No `options`, no `mkIf`. Out-of-tree refs preserved by this task unchanged:
  `../../../secrets/secrets.yaml` (line 25), runtime `PYTHONPATH=~/.dotfiles/opencode-discord-bot`
  (line 105) — both are task 89's concern (opencode-discord-bot packaging), not this task's.

**Blast radius — every nixosConfiguration currently imports it**:
- `lib/mkHost.nix:30` — `"${root}/configuration.nix"` is unconditionally the first module for
  every `mkHost`-built host. `flake.nix:107-114,178-187` builds nandi, hamsa, garuda, and
  usb-installer all via `mkHost`, so all four currently get the bot.
- `flake.nix:121` — the `iso` config bypasses `mkHost` but imports `./configuration.nix`
  directly too, so `iso` also currently gets the bot.
- **Confirmed live on this machine**: `hostname` → `hamsa`; `systemctl status
  discord-bot.service opencode-serve.service` shows both `active (running)` (discord-bot has
  been crash-looping with an unrelated `asyncio` traceback since restart — a pre-existing bug,
  not introduced by and not to be fixed by this task). This is direct proof of the bug this task
  fixes: hamsa was never supposed to run this service (only nandi was, per the aspirational
  comment), yet it does.
- `nix flake check` currently passes cleanly on this machine (baseline green, captured before
  any change — two pre-existing unrelated warnings about `boot.zfs.forceImportRoot` on
  `garuda`/`usb-installer`, not related to this task).

**hosts/ state**:
- `hosts/garuda/default.nix` (7 lines) — literally an empty-body placeholder
  (`{ ... }: { }` with only comments), yet wired via `flake.nix:111-114`'s
  `extraModules = [ ./hosts/garuda/default.nix ];`. This is the exact precedent pattern to reuse
  for nandi, and the exact file to delete per item (5).
- `hosts/nandi/default.nix` and `hosts/hamsa/*/default.nix` **do not exist** — both hosts build
  today with zero `extraModules`, which is *why* they get identical treatment (both get
  `configuration.nix`'s full unconditional list, including the bot).
- `hosts/garuda/README.md` and `hosts/nandi/README.md` exist and do not reference
  `default.nix` at all (only `hardware-configuration.nix`) — no edit needed to either as part of
  this task.
- `hosts/README.md:28-37` documents an obsolete inline-`nixosSystem` pattern predating `mkHost` —
  this is explicitly task 87's scope (blueprint row 6, "folds into subtask 86's doc edit **if
  not already done there**"). Recommendation: leave it to 87; this task's `hosts/*/default.nix`
  changes don't make anything in that README more wrong than it already is, so there's no
  forcing function to pull it in early and risk tier-boundary creep.

**`.claude/rules/nix.md`** (`.claude/rules/nix.md:29-73`, "Module Patterns" section): presents
`NixOS Module Structure` and `Home Manager Module Structure` as *the* pattern (options +
`mkEnableOption`/`mkOption` + `mkIf cfg.enable`) with no scoping language distinguishing
always-on modules from optional ones. Every currently-active module in the repo except the
(to-be-converted) `discord-bot.nix` is a plain attribute set (`modules/system/boot.nix`,
`modules/home/core/git.nix`, etc., confirmed by direct read — no `options`/`mkIf` anywhere in
either directory). Design decision table row 1 (target-layout.md §2) requires the rule to say
explicitly that only optional/host-toggled modules need the options pattern.

**docs/discord-bot.md**: line-by-line drift confirmed —
```
25 | `configuration.nix` | `discordBotPython` env + sops config + both systemd services |
26 | `flake.nix` | sops-nix flake input + module import on all 4 hosts |
```
Line 25 already misattributes the file (it has been at
`modules/system/optional/discord-bot.nix` since well before this task — a pre-existing drift,
not introduced by this task). Line 26 is currently *accurate* (all 4 mkHost hosts + iso do get
it) but becomes false the moment this task lands. Both need editing. Two further pre-existing
mentions of `configuration.nix` (a `sops = {...}` code sample and a "Remove discordBotPython
binding from configuration.nix" instruction, both deeper in the file) share the same stale
attribution; fixing them is a natural drive-by while editing lines 25-26 but is not required by
the task description, which names only line 25 — flag as optional scope, not mandatory.

**docs/dual-home-manager.md**: lines 31-33 state "extraSpecialArgs divergence (resolved) ...
both paths pass the same set of args: `{ pkgs-unstable, lectic, username, name }`." This
contradicts `flake.nix:199-207`'s own comment, which explains the two paths *intentionally* keep
different `lectic` values (NixOS-integrated: raw flake input via `hmExtraSpecialArgs`; standalone:
resolved package, overriding it) — "matching pre-refactor behavior... do not unify these." The
"Current Recommendation" section (lines 60-67) already correctly documents Option A (keep both)
as the chosen state. The only genuine drift is the lines-31-33 claim of full unification, which
should be corrected to describe the actual (intentional) divergence. This is task 69's whole
remaining scope — a one-paragraph documentation fix, no code change — and is cheap to fold into
this task per target-layout.md §2 row 10 / §5 gap 8.

### 2. Module-convention pattern to adopt

Two-tier convention (target-layout.md §2 row 1, full A/B/C convergence):

| Module class | Pattern | Example (existing, unchanged) |
|---|---|---|
| Always-on (imported unconditionally by an aggregator; every host gets it) | Plain attribute set, no `options`/`mkIf` required | `modules/system/boot.nix`, `modules/home/core/git.nix` (~40 files, all unchanged by this task) |
| Optional/host-toggled (a host must be able to select it) | `options.services.<name>.enable = lib.mkEnableOption "..."` + `config = lib.mkIf cfg.enable { ... }`, function signature includes `lib` | `modules/system/optional/discord-bot.nix` (the only conversion this task performs) |

### 3. Concrete implementation plan (file-by-file)

**(1) `.claude/rules/nix.md`** — insert scoping language into the "Module Patterns" section
(after line 28, before the existing `### NixOS Module Structure` heading at line 31). Relabel
the two existing structure examples as the **required** pattern for optional/host-toggled
modules, and add a short "Always-On Modules" note pointing at plain attribute sets as the norm
for the other ~40 files, with a one-line description of the aggregator convention
(`modules/{system,home}/default.nix` import always-on modules only; optional modules are wired
per-host via `hosts/<name>/default.nix` + `extraModules` in `flake.nix`). No rewrite of the
existing code samples — purely additive scoping text, avoiding the blanket-rewrite the design
explicitly rejects.

**(2) `modules/system/default.nix`** (new) — aggregator with the same 11 always-on entries
currently in `configuration.nix:12-23` (`boot.nix` … `shell.nix`), explicitly NOT including
`optional/discord-bot.nix`, with a comment explaining why (opt-in per host).
**`configuration.nix`** rewritten to `imports = [ ./modules/system ];` + unchanged
`system.stateVersion = "24.11";` (drops from 27 lines to ~10).

**`modules/home/default.nix`** (new) — aggregator with the same 27 entries currently in
`home.nix:6-49` (all six groups, unchanged order/grouping via comments). **`home.nix`** rewritten
to `imports = [ ./modules/home ];`, preserving `home.username`, `home.homeDirectory`,
`home.stateVersion`, and the existing trailing comments verbatim (drops from 63 lines to ~15).
Both aggregators rely on Nix's directory-import convention — no code elsewhere needs to change
to resolve `./modules/system` / `./modules/home` to their `default.nix`.

**(3) `modules/system/optional/discord-bot.nix`** — add `lib` to the function signature
(currently `{ config, pkgs, username, ... }:`, missing `lib`); add
`options.services.discordBot.enable = lib.mkEnableOption "the OpenCode Discord bot relay (discord-bot + opencode-serve services)";`;
wrap the existing `sops` and `systemd.services` blocks (lines 24-112, unchanged internally) in a
single `config = lib.mkIf cfg.enable { ... };` (with `cfg = config.services.discordBot;` as a
`let` binding). One option, both services gated together — `opencode-serve` exists in this file
solely to back the bot (per `docs/discord-bot.md`'s own architecture section: "fallback when no
TUI-specific `server_url`... Scoped to `~/.dotfiles`"), so splitting it into a second option
would be unwarranted scope expansion. Not imported by `modules/system/default.nix`.

**(4) Per-host wiring** — new `hosts/nandi/default.nix`:
```nix
# Nandi-specific NixOS configuration — opts into the Discord bot service.
{ ... }:
{
  imports = [ ../../modules/system/optional/discord-bot.nix ];
  services.discordBot.enable = true;
}
```
This mirrors the *existing* `hosts/garuda/default.nix` + `extraModules` shape exactly (not a new
mechanism). `flake.nix:107` changes from `nandi = mkHost { hostname = "nandi"; };` to:
```nix
nandi = mkHost {
  hostname = "nandi";
  extraModules = [ ./hosts/nandi/default.nix ];
};
```
`hamsa = mkHost { hostname = "hamsa"; };` (`flake.nix:109`) is left completely unchanged — the
absence of `extraModules` is exactly what makes hamsa stop getting the bot once
`modules/system/default.nix` no longer includes it by default. This is the crux of the
behavior change and is directly observable on this machine.

**(5) `hosts/garuda/default.nix`** — delete the file (`git rm hosts/garuda/default.nix`).
`flake.nix:111-114`'s
```nix
garuda = mkHost {
  hostname = "garuda";
  extraModules = [ ./hosts/garuda/default.nix ];
};
```
collapses to `garuda = mkHost { hostname = "garuda"; };`, matching nandi/hamsa's pre-change
style. `hosts/garuda/README.md` needs no edit (doesn't reference `default.nix`).

**(6) `docs/discord-bot.md`** — line 25: `configuration.nix` → `modules/system/optional/discord-bot.nix`.
Line 26: replace "sops-nix flake input + module import on all 4 hosts" with language reflecting
opt-in wiring, e.g. "sops-nix flake input; `discord-bot.nix` opted in explicitly per-host (see
`hosts/nandi/default.nix`), not imported by default." Optional drive-by (not required by the
task description, flag only): the `sops = {...}` sample and the "Remove discordBotPython binding
from `configuration.nix`" instruction later in the file share the same pre-existing
misattribution and could be corrected in the same pass for consistency, but are not required to
close this task's item (6).

**Task 69 fold-in** (`docs/dual-home-manager.md:31-33`): rewrite the "extraSpecialArgs
divergence (resolved)" paragraph to state the actual, intentional divergence (`lectic` differs
by design between the two paths; everything else is shared) instead of claiming full
unification, citing `flake.nix:199-207`'s comment. This closes task 69's Option-A documentation
resolution here per target-layout.md §5 gap 8 — task 69 (currently depends on 86 and is
sequenced after it) then becomes a verification-only close-out with no further code changes.

**Out of scope for this task** (confirmed, for the record): `modules/README.md` (new file) is
task 91's deliverable, not 86's, per target-layout.md blueprint row 10; root `README.md`'s
Module Map staleness is also task 91's; `hosts/README.md`'s obsolete example is task 87's.

### 4. Additional behavior-change blast radius (beyond nandi/hamsa)

`iso` (`flake.nix:118-175`, imports `./configuration.nix` directly at line 121) and
`usb-installer` (`flake.nix:178-187`, built via `mkHost` with no discord-bot wiring) both
currently inherit the bot unconditionally through the same `configuration.nix` import chain and
will also stop getting it. This is desirable (an installer image should not carry a Discord bot
toggle) and is excluded from the build-diff harness per the design's own baseline
(target-layout.md §4.2, "iso/usb-installer excluded... not reliably buildable regardless of this
task's changes" — task 68's broken zfs-kernel state), but should be named explicitly in the
implementation plan/summary so it isn't mistaken for scope creep or an unnoticed side effect.

## Decisions

- **Single option, both services gated together**: `services.discordBot.enable` wraps both
  `opencode-serve` and `discord-bot` systemd services in one `mkIf`, matching the task
  description's singular option name and the architecture doc's framing of `opencode-serve` as
  existing to back the bot.
- **Reuse the garuda `extraModules` shape for nandi**, not a new per-host mechanism — the design
  explicitly resolved against `pathExists`/`readDir` auto-discovery (target-layout.md §2 row 2);
  this task's `hosts/nandi/default.nix` is structurally identical to the (soon-deleted)
  `hosts/garuda/default.nix` precedent, just with real content.
- **`.claude/rules/nix.md` gets additive scoping text, not a rewrite** of its existing code
  samples — avoids relitigating the (already-rejected) blanket 43-file options-pattern proposal.
- **Task 69's fold-in is a doc-only paragraph correction**, not a code change — the underlying
  `lectic` divergence is intentional and already correctly explained in `flake.nix`'s own
  comment; only the doc's claim that it was "resolved" into uniformity is wrong.
- **`hosts/README.md` and both hosts' per-host `README.md` files are left untouched** by this
  task — deferred to task 87 (hosts/ structural cleanup) per the tier boundary, since nothing
  this task does makes them any more inaccurate than they already are.

## Recommendations

1. Implement items (2) and (3) (aggregators + options conversion) before item (4) (per-host
   wiring), so that `nix flake check` can validate the aggregator refactor in isolation
   (should be a no-op closure-wise) before the intentionally-behavior-changing per-host step.
2. Stage every touched/deleted/created path explicitly before verification
   (`git add configuration.nix home.nix modules/system/default.nix modules/home/default.nix
   modules/system/optional/discord-bot.nix hosts/nandi/default.nix flake.nix
   docs/discord-bot.md docs/dual-home-manager.md .claude/rules/nix.md`; `git rm
   hosts/garuda/default.nix`) — `flake.nix`'s `root = self` means unstaged moves/creates are
   invisible to `nix flake check`/`nixos-rebuild build` (target-layout.md §4.1).
3. Run the full build harness in order: `nix flake check`, then
   `nixos-rebuild build --flake .#nandi`, `.#hamsa`, `.#garuda`, then
   `nix build .#homeConfigurations.benjamin.activationPackage`. Expect the aggregator refactor
   alone (before the per-host opt-in change) to produce an EMPTY `nix store diff-closures`
   against pre-change baselines for all three hosts (pure structural refactor); expect the
   per-host opt-in change to then produce a non-empty diff for nandi (gains the bot) and no diff
   for hamsa/garuda (already lacked it in the pre-change *intended* state, though hamsa's
   pre-change *actual* closure did contain it — see note below).
4. Runtime verification, split by what's actually reachable from this machine (hamsa):
   - **hamsa (this machine)**: `sudo nixos-rebuild switch --flake .#hamsa`, then
     `systemctl status discord-bot.service opencode-serve.service` (expect
     `Unit discord-bot.service could not be found` / inactive — service definitions removed from
     the closure) and `journalctl -u discord-bot.service -n 20` (no new activity). This is the
     one host where a live `switch` + `systemctl` check can actually run from here.
   - **nandi (not this machine)**: `nixos-rebuild build --flake .#nandi` (cross-build only,
     no `switch` possible from hamsa), then inspect the built closure for the
     `discordBotPython` (`python3-*-env` containing `nextcord`) derivation via
     `nix store diff-closures <pre-change-nandi-path> <post-change-nandi-path>` or
     `nix-store -qR <result> | grep nextcord` to confirm it is now present. Do not claim a
     `switch`/`systemctl` check occurred on nandi unless the implementer actually has access to
     that machine.
   - **garuda**: build-only (`nixos-rebuild build --flake .#garuda`); expect empty closure diff
     (never had the placeholder wired to anything functional, and still doesn't).
5. Note in the implementation summary that `discord-bot.service` was found crash-looping on
   hamsa at research time (unrelated `asyncio` traceback) — this is a pre-existing bug, not
   introduced by and not required to be fixed by this task; removing the service from hamsa's
   closure entirely resolves the symptom as a side effect, but that should not be reported as
   "fixed a bug," only as "removed an unintended service."
6. Fold `docs/dual-home-manager.md`'s correction into this task's commit and mark task 69 for a
   verification-only close-out in its own next dispatch, per target-layout.md §5 gap 8.

## Risks & Mitigations

- **Risk**: forgetting to add `lib` to `discord-bot.nix`'s function signature before using
  `lib.mkEnableOption`/`lib.mkIf` — immediate eval error. **Mitigation**: `nix flake check`
  catches this before any build step.
- **Risk**: staging omission under `flake.nix`'s `root = self` causing a false-positive green
  check against the stale tracked tree. **Mitigation**: explicit `git add`/`git rm` list in
  Recommendation 2, run immediately before verification, matching the cross-cutting protocol in
  target-layout.md §4.1.
- **Risk**: conflating "hamsa's discord-bot.service is crash-looping" (pre-existing, unrelated)
  with a regression introduced by this task. **Mitigation**: documented explicitly above and in
  Recommendation 5; the crash predates this task's changes (confirmed via `journalctl` showing
  4-day-old `Active: active (running) since Tue 2026-06-30`).
- **Risk**: attempting to runtime-verify nandi from hamsa via `switch`, which is not possible
  cross-machine. **Mitigation**: Recommendation 4 explicitly scopes the live `switch`/`systemctl`
  check to hamsa only and specifies a build+closure-inspection method for nandi instead.

## Appendix

### Sources/Inputs consulted

- Seed context (as directed): `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  ("modules/" and "hosts/" sections), `reports/02_team-research.md` (Conflicts Resolved #2,
  Design-Question Decisions table, subtask blueprint row 5), `design/target-layout.md` §1.3, §2
  (rows 1, 2, 10), §3 (Subtask Blueprint row 5), §4.3 (Runtime Verification Requirement).
- Direct repo reads: `configuration.nix`, `home.nix`, `flake.nix`, `lib/mkHost.nix`,
  `modules/system/optional/discord-bot.nix`, `.claude/rules/nix.md`, `hosts/garuda/default.nix`,
  `hosts/garuda/README.md`, `hosts/nandi/README.md`, `hosts/README.md`, `docs/discord-bot.md`,
  `docs/dual-home-manager.md`, full `modules/` file listing (43 files, confirmed count).
- Live environment checks on this machine: `hostname` (→ `hamsa`), `nixos-version`,
  `systemctl status discord-bot.service opencode-serve.service`, `nix flake check` (baseline
  green), `nix --version`.
- `specs/state.json` — confirmed tasks 82-85 (Tier 0) already `completed`; 87-91 (Tier 2/Final)
  `not_started` and depend on 86; task 69 confirmed `not_started`, scope-updated to depend on 86.

### File:line reference index

`configuration.nix:8-27` (import list, line 25-26 discord-bot), `home.nix:5-50` (import list),
`flake.nix:96` (`root = self`), `flake.nix:107-114` (nandi/hamsa/garuda hosts),
`flake.nix:118-175` (iso), `flake.nix:178-187` (usb-installer), `flake.nix:199-207` (lectic
divergence comment), `lib/mkHost.nix:22-51` (mkHost body, line 30 hard-codes
`configuration.nix`), `modules/system/optional/discord-bot.nix:1-113` (full file, line 3 function
signature, line 25 secrets path, line 105 PYTHONPATH), `hosts/garuda/default.nix:1-7` (empty
placeholder to delete), `hosts/README.md:28-37` (obsolete example, task 87 scope),
`.claude/rules/nix.md:29-73` (Module Patterns section), `docs/discord-bot.md:25-26` (file table),
`docs/dual-home-manager.md:31-33` (inaccurate unification claim) and `:60-67` (correct Option-A
recommendation, unchanged).

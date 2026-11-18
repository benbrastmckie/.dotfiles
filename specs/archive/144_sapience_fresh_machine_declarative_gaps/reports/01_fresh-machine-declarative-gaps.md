# Research Report: Sapience Fresh-Machine Declarative Gaps

- **Task**: 144 - sapience_fresh_machine_declarative_gaps
- **Started**: 2026-11-18T11:15:00Z
- **Completed**: 2026-11-18T12:05:00Z
- **Effort**: ~1 session, codebase-only (no web research needed; one MCP-NixOS option lookup)
- **Dependencies**: None blocking. Shares file territory (non-conflicting) with task 136
  (`evaluate_sapience_coverage_and_tune_extraction_scope`, status `implementing`) and with the
  separately-tracked hook-opt-out work completed as task 142.
- **Sources/Inputs**:
  - `modules/home/services/sapience.nix` (full read, the live module)
  - `packages/sapience-flake/modules/sapience.nix` (comparison read, the non-live vendored fork)
  - `modules/home/default.nix`, `flake.nix`, `configuration.nix`, `lib/mkHost.nix`
  - `modules/system/users.nix`, `modules/system/secrets.nix`, `secrets/secrets.yaml`, `.sops.yaml`
  - `docs/sapience.md`
  - `git log` on both `sapience.nix` copies
  - MCP-NixOS: `nix(action="info", query="users.users.<name>.linger", type="option", channel="26.05")`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed the live module is `modules/home/services/sapience.nix` (imported unconditionally at
  `modules/home/default.nix:48`); `packages/sapience-flake/modules/sapience.nix` is a separate,
  unconsumed `homeManagerModules.sapience` flake output — nothing in `home.nix`/`flake.nix`
  references it.
- **Gap 1 (tokenFile) needs only wiring, no module-logic change.** `tokenFile` already flows
  through the same `sap_token_clean` / `sap_token_ok` / server-verification gauntlet as every
  other token source (confirmed by reading the full `sapienceBootstrap` script). The only missing
  pieces are a `modules/system/secrets.nix` entry and `home.nix` setting `tokenFile`. One sharp
  edge found: the value **must** be a quoted string (`"/run/secrets/sapience_token"`), never a
  bare Nix path literal, or Nix's evaluator will try to copy the (not-yet-existing, secret) file
  into the world-readable store at eval time.
- **Gap 2 (sourceDirs) is already resolved as option (b) in the code, just not in the plan
  record.** The `sourceDirs` option description already states: "Run it by hand; nothing here is
  scheduled and activation never ingests anything" — literally the wording Acceptance Criterion 3
  asks for. The open question for planning is whether to *upgrade* to option (a): the
  `sapience-adddir-sources` wrapper already uses a **persistent** `denyHome` ledger directory
  specifically so re-runs are incremental, which means wiring it into activation would likely
  already be idempotent-safe — this is a real design choice, not a foregone one, and this report
  does not pick it.
- **Gap 3's premise does not hold against the live module — this is the most important finding.**
  The "WSL sync-notice activation entry" the dispatch quotes (`sapienceWslSyncNotice`,
  `wslDetect`, `userManagerProbe`) exists **only** in `packages/sapience-flake/modules/sapience.nix`
  (added in commit `20715ff`, a fork-only feature). `modules/home/services/sapience.nix` has
  **zero** matches for `WSL`, `linger`, or `lingering` anywhere in its 1242 lines. "KEEP the
  existing activation notice" cannot be satisfied literally in the live file because there is
  nothing there to keep.
- Confirmed via MCP-NixOS that `users.users.<name>.linger` (null-or-boolean, default null) exists
  on `nixos-26.05`, the exact channel this flake's `nixpkgs` input is pinned to
  (`flake.lock` rev `643809054d65fdd466a63e3155b8c498cb483c04`). No `systemd.tmpfiles` fallback is
  needed. `modules/system/users.nix` is the natural, already-existing, unconditionally-imported
  (via `configuration.nix` → all of `nandi`/`hamsa`/`garuda`/`usb-installer`) place to set it.
- `backgroundSync` is currently `false` in `home.nix` (its default), so no Sapience timer is
  defined on this machine today — the lingering fix is about making the declaration correct for
  whenever it *is* turned on, and incidentally benefits every other `systemd.user.timers.*` unit
  in this configuration (`cache-cleanup`, `claude-session-reaper`, `mail-sync-timer`,
  `sf1-hub-ben`), none of which currently mention lingering either.
- A standing operational constraint applies to Acceptance Criterion 4's verification step: a
  prior session's memory record in this same task dispatch notes that `sudo` is categorically
  denied in this harness, so `sudo nixos-rebuild switch` — the only path that would make
  `linger = true` actually take effect and let `loginctl show-user <name> --property=Linger` be
  checked — cannot be run by an agent in this environment. Flagged as a risk for the plan/implement
  phases, not something this research phase can resolve.

## Context & Scope

Scope is exactly the three gaps named in the dispatch: a fresh-machine `tokenFile`, registering
`sourceDirs`, and declarative lingering for the background sync timer. The vendor hook opt-out
(task 142, already implemented) is explicitly out of scope and was only read for situational
context. Task 136 is mid-implementation and shares `home.nix`, `modules/home/services/sapience.nix`
and `docs/sapience.md`; this research treats that as a concurrency fact to flag, not a reason to
redesign those files' existing structure.

## Findings

### Live-module confirmation

- `modules/home/default.nix:48` imports `./services/sapience.nix` unconditionally, alongside 20+
  other service modules, with no `lib.mkIf` gate.
- `packages/sapience-flake/flake.nix:95` exposes `homeManagerModules.sapience = ./modules/sapience.nix;`
  as a flake output, but a repo-wide grep for `sapience-flake` / `homeManagerModules.sapience`
  found no consumer anywhere in `home.nix` or the root `flake.nix` — it is published for
  consumption by *other* flakes, not wired into this one's own configuration.
- Both files share a common ancestor (`df76f7f`, "scaffold the directory and vendor a verbatim
  module copy") and have since diverged under independent commit histories (36 vs. 23 commits
  touching each path respectively). They are not kept in sync.

**Conclusion**: every finding and recommendation below is scoped to
`modules/home/services/sapience.nix`, per the dispatch's own instruction.

### Gap 1 — `tokenFile`

- The option (`tokenFile`, `nullOr path`, default `null`) is declared at
  `modules/home/services/sapience.nix:678` with a description already warning that the value
  "Must be a path OUTSIDE the Nix store ... When null, sapience-bootstrap prompts instead."
- Consumption is inside `sapienceBootstrap` (the `sapience-bootstrap` wrapper), lines 266-282:
  `TOKEN` is populated, in order, from (1) an already-valid stored token, (2) a repaired
  link-shaped stored token, (3) `$SAPIENCE_TOKEN`, (4) `tokenFile` (only if steps 1-3 left it
  empty and the file is readable), (5) an interactive `read -r`. **Critically**, line 282 —
  `TOKEN="$(sap_token_clean "$TOKEN")"` — runs unconditionally *after* that entire chain,
  followed by `sap_token_ok` validation (line 288) and a live `/v1/stats?token=$TOKEN` check
  (lines 297-318) before anything is written. This means a `tokenFile`-sourced value is **not**
  exempt from the repair/validation guard the dispatch asked about — it is already run through
  exactly the same gauntlet as a hand-typed paste. No code change is needed here.
- What *is* missing is purely wiring: `home.nix`'s `programs.sapience` block does not set
  `tokenFile`, and there is no sops secret for it. The existing `anthropic_api_key` pattern
  (`modules/system/secrets.nix:25`, owner-readable `0400`, consumed by `home.nix`'s
  `apiKeyFile = "/run/secrets/anthropic_api_key"`) is the exact template to mirror: a new
  `secrets."sapience_token" = { owner = config.users.users.${username}.name; mode = "0400"; };`
  entry, a new value added to `secrets/secrets.yaml` via `sops secrets/secrets.yaml` (single age
  recipient `benjamin_age`, no `.sops.yaml` change needed — `creation_rules` already matches any
  `secrets/*.yaml` path), and `tokenFile = "/run/secrets/sapience_token";` in `home.nix`.
- **A sharp edge not mentioned in the dispatch**: `tokenFile`'s declared type is
  `lib.types.nullOr lib.types.path`. `lib.types.path` accepts an absolute-looking *string*
  (confirmed by the option's own `example = "/run/secrets/sapience_token";`, a quoted string,
  and by `apiKeyFile` — same pattern, declared `lib.types.str` — being set the same way in
  `home.nix` today). If `home.nix` instead wrote an **unquoted** Nix path literal
  (`tokenFile = /run/secrets/sapience_token;`), the Nix evaluator would treat that as a real path
  value and attempt to copy the referenced file into the (world-readable) store at evaluation
  time — on a fresh machine before the secret even exists, this fails evaluation outright; if the
  file *did* exist, it would leak the token into `/nix/store`. The implementation must set this
  as a quoted string, exactly mirroring `apiKeyFile`'s existing syntax. This is the one place the
  "never expose a token" binding constraint has a real, easy-to-miss failure mode at the Nix
  syntax level rather than the shell-script level.
- No activation-time merge of `tokenFile` into `config.json` exists today (unlike `apiKeyFile`,
  which has a dedicated `sapienceApiKey` activation entry at lines 999-1043). This appears
  intentional, not an oversight: the sibling `sapienceApiKey` entry itself refuses to run until
  `configFile` already exists ("`${configFile}` does not exist yet; run sapience-bootstrap
  first"), i.e. this module's own established pattern is that `config.json`'s *initial* creation
  (including the token) is `sapience-bootstrap`'s job, not activation's — activation only enriches
  an already-bootstrapped `config.json`. Acceptance Criterion 2 ("a fresh-machine bootstrap
  requires no interactive token paste") reads as consistent with that existing division: the fix
  is to make the still-manual-but-now-non-interactive `sapience-bootstrap` invocation pick up the
  token automatically, not to add a new activation entry that creates `config.json` outright.
- Non-interactive demonstration (for the plan/implement phase, not this report): with `tokenFile`
  set and a readable file in place, `SAPIENCE_BOOTSTRAP_LOCKED=1 sapience-bootstrap </dev/null`
  (or simply running it with stdin closed) should proceed past the token step without blocking on
  `read -r`, since `tokenFile` is checked before the interactive-read branch. This can be
  demonstrated with a placeholder/invalid token (which will be rejected at the `/v1/stats` check
  with a clear non-prompting failure) to prove non-interactivity without needing the real secret
  value in the demonstration.
- Remaining manual step regardless of implementation: a human must put the *real* token into
  `secrets/secrets.yaml` via `sops` by hand — no agent in this session has or should have that
  credential, and the binding constraint forbids exposing it. This is unavoidable and should be
  named explicitly in the updated `docs/sapience.md` setup sequence (Acceptance Criterion 6).

### Gap 2 — `sourceDirs` registration

- `home.nix` sets `sourceDirs = [ "/home/benjamin/.config/nvim/agent-system" ]` with a comment
  already stating "Run `sapience-adddir-sources` by hand -- nothing about this is scheduled."
- The option's own description (`modules/home/services/sapience.nix:761-784`) **already contains**
  the literal sentence option (b) asks for: "Run it by hand; nothing here is scheduled and
  activation never ingests anything." Read narrowly, Acceptance Criterion 3's "outcome visible in
  the option's own description" clause is already satisfied by the code as it stands today.
- What is *not* yet recorded anywhere is the **reasoning** — specifically the clobbering/ledger
  cost the dispatch names. That reasoning does exist in the codebase, just not next to the
  decision: the `sapienceAddDirSources` definition's own comment block (lines ~565-585) explains
  that `adddir` keys an incremental ledger by content sha at `$HOME/.sapience/adddir-<sha>.json`,
  and that `denyHome` (`"${stateDir}/adddir-home"`) is deliberately **persistent, not a tempdir**,
  specifically so a re-run only sends what changed rather than re-sending everything.
- This persistence detail matters for the open design question: the risk the dispatch describes
  for option (a) — "an unconditional activation run has both a clobbering risk and a cost (a
  mis-keyed ledger re-sends every file)" — is largely already mitigated at the mechanism level,
  because the wrapper's ledger directory does not change between runs (it is not a per-activation
  tempdir). The remaining risk for option (a) is narrower than the dispatch's framing suggests:
  not "does every activation re-send everything" (it would not, given the persistent ledger), but
  (i) whether an activation-time `adddir` call should be allowed to run unconditionally even when
  `cfg.sourceDirs` shrinks (removal semantics — the dispatch's own (a) wording requires "never
  removes undeclared ones", which matches `adddir`'s own additive nature: it has no corresponding
  "remove" subcommand, so there is nothing for an activation step to accidentally over-remove),
  and (ii) whether running it non-interactively on every `home-manager switch` is an acceptable
  cost given it calls out to the network (`/extract-doc`) and needs a valid token in `config.json`
  (exactly the same "config.json must already exist" precondition `sapienceApiKey` already
  handles by checking and warning rather than failing).
- This report does not resolve (a) vs. (b) — that decision, with its reasoning, is explicitly a
  planning-phase deliverable per the dispatch. Both are mechanically straightforward from here:
  (b) requires only adding one sentence of reasoning to the option description (the ledger point
  above) plus recording the decision in the plan; (a) requires a new `lib.mkIf (cfg.sourceDirs !=
  [ ]) (config.lib.dag.entryAfter [ "writeBoundary" "sapiencePayload" "sapienceTokenRepair" ] ...)`
  activation entry that shells out to the already-built `sapienceAddDirSources` derivation,
  following the same non-fatal `|| echo ...` discipline every other entry in this file already
  uses.

### Gap 3 — Lingering (the central finding of this report)

- **The dispatch's description of "the existing activation notice" describes the wrong file.**
  `sapienceWslSyncNotice` (and its helpers `wslDetect`/`userManagerProbe`) exist only in
  `packages/sapience-flake/modules/sapience.nix` (lines 375-405), introduced in commit `20715ff`
  ("sapience-flake: support Linux and Windows/WSL2, drop Darwin") — a feature developed after the
  two module copies had already diverged, and never ported back into the live module. A grep
  across `modules/home/services/sapience.nix`, `modules/system/`, and `hosts/` for `linger`,
  `WSL`, `wsl`, `enable-linger`, and `systemd=true` returns **zero matches** in all three
  locations. The live module has no WSL-awareness or lingering-awareness of any kind today.
  Acceptance Criterion 6's "KEEP the existing activation notice" instruction therefore cannot be
  executed as a literal preserve-in-place edit against the live file — there is nothing there to
  keep. This needs a planning decision, not a research guess: either (i) port a narrowed version
  of the WSL notice into the live module as part of closing this gap (the dispatch's framing
  reads as if it expects this), or (ii) treat it as explicitly out of scope on the grounds that no
  host in `hosts/` (`garuda`, `hamsa`, `nandi`, `usb-installer`) is a WSL target today. No current
  host is WSL, so option (ii) is defensible, but the module's own `terminal`/`webAppCommand`
  options and general design clearly anticipate portability, and the vendor's own WSL2 support
  (visible in the fork) suggests this was a deliberately-planned feature path, not dead code.
  Recommend the plan make this choice explicitly rather than silently importing or silently
  dropping the fork's code.
- **The NixOS-level mechanism is confirmed and simple.** MCP-NixOS (`nix(action="info",
  query="users.users.<name>.linger", type="option", channel="26.05")`) confirms `linger` (type
  `null or boolean`, default `null`) is present on `nixos-26.05`, the exact channel this flake's
  primary `nixpkgs` input tracks (`flake.lock`: `nixpkgs` → rev `643809054d65fdd466a63e3155b8c498cb483c04`,
  `nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"` in `flake.nix:8`). The option's own
  description states explicitly: "Setting this option to `true` or `false` is the declarative
  equivalent of running `loginctl enable-linger`." No `systemd.tmpfiles` fallback into
  `/var/lib/systemd/linger` is needed on this nixpkgs revision — that fallback exists for older
  revisions that predate this option, which is not the case here.
- **Where to set it**: `modules/system/users.nix` already declares
  `users.users.${username} = { isNormalUser = true; description = "Benjamin"; extraGroups = [...]; };`
  and is imported unconditionally by `modules/system/default.nix:16`, which is in turn imported by
  every real host (`configuration.nix:14` → `./modules/system`, consumed by all of `nandi`,
  `hamsa`, `garuda`, `usb-installer` via `lib/mkHost.nix`'s fixed module list). Adding
  `linger = true;` inside that same `users.users.${username} = { ... }` block is the minimal,
  already-precedented place — directly parallel to how `modules/system/secrets.nix` declares the
  `anthropic_api_key` secret once, unconditionally, for every host regardless of which optional
  home-manager service consumes it.
- **`backgroundSync` is currently off.** `home.nix`'s `programs.sapience` block does not set
  `backgroundSync`, so it is at its default (`false`): no `systemd.user.timers.sapience-sync` unit
  is even defined on this machine today. The lingering gap is latent, not actively broken, on the
  current configuration — it matters the moment `backgroundSync = true` is set, or for any other
  `systemd.user.timers.*` unit in this tree. A repo-wide check found five other such modules
  (`cache-cleanup.nix`, `mail-sync-timer.nix`, `claude-session-reaper.nix`,
  `screen-blank-watchdog.nix`, `sf1-hub-ben.nix`), none of which mention lingering either — this
  machine is presumably usually logged in at the desktop, which masks the gap for all of them
  today. Setting `linger = true` once at the NixOS level benefits all of them, not just Sapience;
  worth noting to whoever reviews the plan as a reason this is a clean, low-risk, broadly-useful
  change rather than a narrow one.
- **Verification constraint.** Acceptance Criterion 4 asks for `loginctl show-user <name>
  --property=Linger` to report `Linger=yes` *after a switch*. `linger` is a NixOS-level
  (system-activation) option, so it only takes effect via `nixos-rebuild switch`, which requires
  `sudo`. This task's own dispatch carries a memory-context note from a prior session on this same
  machine stating that "sudo is categorically denied by this session's own permission system
  (every sudo invocation, including a bare probe, was refused) — not an intermittent or
  configurable limitation, but a structural one," and that only the user-level `home-manager
  switch` path (which does not own NixOS-level state) was achievable in that session. If that
  constraint still holds for the implementing session, Acceptance Criterion 4's live verification
  cannot be self-demonstrated by an agent and will need either a human-run `nixos-rebuild switch`
  between the plan and implementation phases, or the acceptance criterion's verification step
  explicitly deferred to the user. Flagging this now so the plan does not promise a verification
  step the implementing agent structurally cannot perform.

### Cross-task territory (task 136)

- Task 136 (`evaluate_sapience_coverage_and_tune_extraction_scope`, status `implementing`) is
  about coverage measurement and extraction-scope tuning (backend/model/filter behavior), based on
  its artifact names (`baseline-and-extraction-backend-blocked`,
  `coverage-measurement-series-and-decision`, `coverage-pass-ledger`, `vault-content-audit`). It
  shares `home.nix`, `modules/home/services/sapience.nix`, and `docs/sapience.md` with this task's
  declared scope, but its own focus (coverage/extraction tuning) does not touch `tokenFile`,
  `sourceDirs`, or lingering by name in any artifact title found. Risk is file-adjacency, not
  design overlap. Recommend the eventual plan/implementation keep edits narrowly scoped to the new
  option/doc regions (new secret, `linger` line, `sourceDirs` description/activation entry, the
  "First-time setup" and "Module options" sections of `docs/sapience.md`) and re-read each file
  immediately before editing, per the territory protocol already named in the dispatch.

## Decisions

- Confirmed `modules/home/services/sapience.nix` (not `packages/sapience-flake/modules/sapience.nix`)
  is the live module, via `modules/home/default.nix:48`'s unconditional import and the absence of
  any `packages/sapience-flake` consumer in `home.nix`/`flake.nix`. All findings and the
  recommendations below are scoped to it exclusively.
- Did not pick between Gap 2's option (a) vs (b), or between Gap 3's "port the WSL notice" vs
  "treat as out of scope" — both are explicitly named in the dispatch as decisions for the plan to
  make and record, not for research to preempt.
- Treated the Gap 3 file-location discrepancy (notice lives in the non-live fork, not the live
  module) as a finding to surface rather than something to silently correct by assuming the
  dispatch meant the fork file — the dispatch is explicit that `packages/sapience-flake/modules/sapience.nix`
  is out of scope for this task.

## Recommendations

1. **Gap 1**: add `secrets."sapience_token" = { owner = config.users.users.${username}.name; mode
   = "0400"; };` to `modules/system/secrets.nix` (mirroring `anthropic_api_key` verbatim), set
   `tokenFile = "/run/secrets/sapience_token";` (quoted string, not a path literal) in `home.nix`'s
   `programs.sapience` block, and have the human add the real value to `secrets/secrets.yaml` via
   `sops secrets/secrets.yaml` — no module-logic change is needed since the consumption and
   validation path already exists and already applies uniformly to every token source.
2. **Gap 2**: the plan should explicitly choose (a) or (b) and record the reasoning; given the
   `sapience-adddir-sources` wrapper's ledger is already persistent across runs (not a per-call
   tempdir), option (a) is less risky than the dispatch's framing suggests, but it does add a
   network-dependent, token-dependent step to every `home-manager switch` once any `sourceDirs`
   entry exists — the plan should weigh that cost explicitly rather than default to (a) just
   because it is now known to be safer than first assumed. If (b) is kept, the plan should still
   add one sentence to the option description naming the ledger-cost reasoning, since the sentence
   that satisfies Acceptance Criterion 3's literal wording is already present but the *reasoning*
   is not yet co-located with it.
3. **Gap 3**: set `users.users.${username}.linger = true;` in `modules/system/users.nix` (no
   `systemd.tmpfiles` fallback needed on `nixos-26.05`). Separately and explicitly, the plan must
   decide whether to port a narrowed version of `sapienceWslSyncNotice`/`wslDetect`/
   `userManagerProbe` from `packages/sapience-flake/modules/sapience.nix` into the live module
   (scoped down, since the NixOS-level grant now covers the only real host type in `hosts/`), or
   to state explicitly that WSL support is out of scope for the live module until a WSL host
   actually exists. Either is defensible; silence is not, per the dispatch's own instruction.
4. Flag the `sudo`-denial constraint to whoever runs the implementation phase before it commits to
   demonstrating `loginctl show-user <name> --property=Linger` itself; plan for a human-run
   `nixos-rebuild switch` checkpoint if the constraint still holds.
5. For Acceptance Criterion 6, update `docs/sapience.md`'s "Module options" table (new `tokenFile`
   "Set here" value once wired; a new line or subsection for the NixOS-level `linger` option,
   which is not a `programs.sapience.*` option and so does not fit the existing table's scope
   without a note) and its "First-time setup" sequence, explicitly naming every step that remains
   manual after this task: pasting the real token into `secrets/secrets.yaml` via `sops`, the
   vendor's own interactive folder-selection picker inside `sapience-bootstrap` (unaffected by this
   task), `sourceDirs` registration if (b) is kept, and the separately-tracked hook opt-out
   (task 142) — the dispatch requires this last one be named explicitly so the document is not
   silently incomplete.

## Risks & Mitigations

- **Risk**: implementing Gap 1 with an unquoted path literal for `tokenFile` either breaks
  evaluation on a fresh machine (file does not exist yet) or copies the token into the
  world-readable Nix store. **Mitigation**: use a quoted string, exactly mirroring `apiKeyFile`'s
  existing syntax in `home.nix`; this report names the hazard explicitly so the plan/implementation
  does not reintroduce it.
- **Risk**: Gap 3's acceptance criterion assumes a verification step (`nixos-rebuild switch` +
  `loginctl show-user`) that may be structurally unavailable to an agent in this harness (`sudo`
  denial, per this task's own carried memory record). **Mitigation**: name this explicitly in the
  plan as a human checkpoint rather than let the implementation phase silently fail or fabricate
  the verification.
- **Risk**: silently porting the WSL notice from the non-live fork, or silently dropping it,
  either one without recording the reasoning, reproduces exactly the "leaving the decision
  implicit" failure mode the dispatch explicitly forbids for Gap 2 — the same discipline applies
  here even though the dispatch did not label Gap 3 with the (a)/(b) framing. **Mitigation**: the
  plan should record this choice with the same explicitness as Gap 2's.
- **Risk**: task 136 is mid-implementation on overlapping files. **Mitigation**: narrow,
  re-read-before-edit commits as already mandated by the territory protocol; no mitigation beyond
  what the dispatch already requires.

## Appendix

- `modules/home/services/sapience.nix` line references used above: option declarations at
  ~678 (`tokenFile`), ~761-797 (`sourceDirs`, `sourceDirInclude`), ~721-742 (`backgroundSync`,
  `syncInterval`); `sapienceBootstrap` token-sourcing chain at 253-282, validation/server-check at
  284-318; activation entries at 892-1043 (`sapienceHooksGuard`, `sapiencePayload`,
  `sapienceTokenRepair`, `sapienceApiKey`); `sapienceAddDirSources` definition and ledger comment
  at ~560-634; timer definitions at 1169-1240.
- `packages/sapience-flake/modules/sapience.nix` line references: `sapienceWslSyncNotice` and
  helpers at 350-406; introduced in commit `20715ff` ("sapience-flake: support Linux and
  Windows/WSL2, drop Darwin").
- `modules/system/users.nix` (full file, 18 lines): current `users.users.${username}` block with
  `isNormalUser`, `description`, `extraGroups`; no `linger` key present today.
- `modules/system/secrets.nix`: `anthropic_api_key` entry (owner/mode pattern to mirror for a new
  `sapience_token` entry).
- `flake.lock`: `nixpkgs` node locked to rev `643809054d65fdd466a63e3155b8c498cb483c04`
  (`nixos-26.05`); `users.users.<name>.linger` confirmed present on that channel via MCP-NixOS.
- Hosts confirmed to receive `modules/system/*` unconditionally: `nandi`, `hamsa`, `garuda`,
  `usb-installer` (all via `lib/mkHost.nix` → `configuration.nix` → `./modules/system`); the `iso`
  target does not go through `configuration.nix` and was not further investigated (out of scope —
  not a persistent machine any lingering setting would meaningfully apply to).

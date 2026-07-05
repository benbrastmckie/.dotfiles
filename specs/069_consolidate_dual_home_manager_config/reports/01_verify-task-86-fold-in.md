# Research Report: Task #69

**Task**: 69 - Consolidate dual home-manager config (rescoped, depends on 86)
**Started**: 2026-07-05T05:50:19Z
**Completed**: 2026-07-05T06:05:00Z
**Effort**: ~30 min (verification + targeted nix eval)
**Dependencies**: 86 (completed)
**Sources/Inputs**: lib/mkHost.nix, flake.nix, docs/dual-home-manager.md, home.nix, modules/home/packages/lean-math.nix, git log (task 66 phase 9, task 86 phase 5), `nix eval` against live flake outputs
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 86 did **not** unify `extraSpecialArgs` between the two home-manager paths. It only edited
  `docs/dual-home-manager.md` to describe the asymmetry as an intentional, deliberate divergence.
- Live `nix eval` verification shows the asymmetry is not a harmless stylistic difference: on the
  NixOS-integrated path (`nandi`, and by construction `hamsa`/`garuda`/`usb-installer` via
  `lib/mkHost.nix`), the `lectic` entry in `home.packages` is literally the **raw flake input**
  (an attrset with keys `_type, apps, devShell, inputs, ..., outPath, sourceInfo`, `name` absent).
  On the standalone path (`homeConfigurations.benjamin`) it correctly resolves to the built
  derivation `lectic-0.0.0`.
- This is functionally the same defect that task 66 phase 9 found and fixed **only for the
  standalone path** — the NixOS-integrated path has carried it, unnoticed, since before task 66,
  and still carries it today. It is masked in practice only because `~/.nix-profile`
  (standalone, built via `home-manager switch`) wins `$PATH` priority over
  `/etc/profiles/per-user/benjamin/` (NixOS-integrated, built via `nixos-rebuild switch`).
- Recommended outcome: **(B) documentation-only resolution still needed**, using the
  "minimal specialArgs alignment if trivial" allowance explicitly granted by the task's rescoped
  description — a genuinely trivial one-line fix exists (the exact resolution expression is
  already used three other places in the same two files), plus a doc correction removing the
  "not a bug" framing that this verification shows is inaccurate.

## Context & Scope

Task 69 was rescoped by task 81's decomposition to depend on task 86 and to be resolved as
"Option A — DOCUMENTATION-ONLY". Task 86 just landed (commit `9946058`, "task 86 phase 5: correct
docs for opt-in wiring (+ task 69 fold-in)") and its return metadata claims it "corrected
docs/dual-home-manager.md:31-33 (closes out task 69's fold-in)". This research verifies, against
current file contents, whether that closes task 69 outright or whether a minimal action remains.

## Findings

### Existing Configuration (current file contents, post-86)

**`lib/mkHost.nix`** (NixOS-integrated path, used by `nandi`, `hamsa`, `garuda`, `usb-installer`
via `mkHost`):

```nix
home-manager.extraSpecialArgs = {
  inherit pkgs-unstable;
  inherit lectic;              # <-- raw flake input, unresolved
  inherit nix-ai-tools;
};
```

Immediately below, the *same file's* top-level `specialArgs` (used by NixOS modules, not
home-manager) resolves `lectic` correctly:

```nix
specialArgs = {
  ...
  lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
} // extraSpecialArgs;
```

So the correct resolution idiom is already present in the very same file, three lines away from
the unresolved one.

**`flake.nix`** (standalone path, `homeConfigurations.benjamin`):

```nix
hmExtraSpecialArgs = {
  inherit pkgs-unstable;
  inherit lectic;               # <-- raw input, shared base
  inherit nix-ai-tools;
};
...
homeConfigurations.benjamin = home-manager.lib.homeManagerConfiguration {
  ...
  extraSpecialArgs = {
    inherit username; inherit name;
  } // hmExtraSpecialArgs // {
    # Standalone home installs the BUILT lectic package (home.packages gets the
    # derivation), matching pre-refactor behavior. The NixOS-integrated path keeps
    # the raw lectic input via hmExtraSpecialArgs, so do not unify these.
    lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
  };
};
```

This override was added in task 66 phase 9 (commit `b864e63`, "restore standalone home lectic
package (final audit fix)"), whose commit message is explicit: *"the Phase 3 hmExtraSpecialArgs
consolidation passed the raw lectic flake input to the standalone homeConfigurations.benjamin
instead of the resolved package, dropping lectic + its node_modules (~280 MiB) ... the
NixOS-integrated path is unchanged (still byte-identical to baseline)."* In other words: this was
a real regression, fixed **only** on the path where it was actually noticed (standalone, because
that's the profile in the user's live `$PATH`). The NixOS-integrated path has always had the same
defect; it was simply never exercised/observed there.

**`home.nix`** signature: `{ config, pkgs, pkgs-unstable, lectic, ... }:` — `lectic` is a genuine
function parameter (lexically bound), consumed in `modules/home/packages/lean-math.nix`:
`home.packages = with pkgs; [ lectic loogle ];`. Because `lectic` is a lexical binding, `with
pkgs;` does not shadow it — whatever value flows in via `extraSpecialArgs` is what lands directly
in `home.packages`.

### Live Verification (nix eval, not just static reading)

```
$ nix eval .#nixosConfigurations.nandi.config.home-manager.users.benjamin.home.packages \
    --apply 'map (p: (p.name or "NO-NAME"))'
[ ... "nodejs-24.16.0" "NO-NAME" "loogle" "claude" ... ]
```

The package with no `.name` is the `lectic` entry. Inspecting its attribute names confirms it is
the raw flake object, not a derivation:

```
$ nix eval .#nixosConfigurations.nandi.config.home-manager.users.benjamin.home.packages \
    --apply 'ps: map builtins.attrNames (builtins.filter (p: !(p ? name)) ps)'
[ [ "_type" "apps" "devShell" "inputs" "lastModified" "lastModifiedDate" "narHash"
    "outPath" "outputs" "packages" "rev" "shortRev" "sourceInfo" ] ]
```

Contrast with the standalone path:

```
$ nix eval .#homeConfigurations.benjamin.config.home.packages --apply 'map (p: (p.name or "NO-NAME"))'
[ ... "nodejs-24.16.0" "lectic-0.0.0" "loogle" "claude" ... ]
```

`lectic-0.0.0` is the real built derivation. The NixOS-integrated path instead gets an attrset
whose only usable-for-profile-linking feature is `outPath` (nix's generic "things with `outPath`
behave like derivations for symlinking" duck-typing) pointing at the **raw, unbuilt git checkout**
of `github:gleachkr/lectic`. That checkout has no `bin/lectic`, so activating this path installs
no working `lectic` command into `/etc/profiles/per-user/benjamin/` — it silently contributes
nothing usable, exactly mirroring the "~280 MiB dropped, silently, no build error" symptom that
task 66 phase 9 caught and fixed for the *other* path only.

### docs/dual-home-manager.md (post-86 content)

The doc now contains (added by task 86):

> **extraSpecialArgs divergence (intentional)**: The two paths pass the same set of arg *names*
> ..., but `lectic`'s *value* deliberately differs between them. ... See `flake.nix:199-207`'s
> inline comment, which states this explicitly and instructs not to unify the two — this is a
> deliberate divergence, not a bug.

This is **descriptively accurate** (it correctly states what the code does and cites the right
lines) but **substantively misleading**: the verification above shows the NixOS-integrated side
of the "divergence" is not a considered alternate design, it is the identical class of defect
task 66 phase 9 already diagnosed and fixed on the other path. There is no plausible reason to
want the raw, unbuilt flake source sitting in `home.packages` — the doc's "not a bug" framing
closes the historical open question about *whether this was noticed* but asserts an incorrect
conclusion about *whether it is correct*. The separate, older "QUESTION for User: Which Path to
Keep?" (Option A/B/C, whether to keep both paths at all) is unrelated to lectic and is already
answered ("Current Recommendation: Keep both paths (Option A)... Action required: None") — that
question is genuinely closed and out of scope here.

### Git History Corroboration

- `b864e63` (task 66 phase 9): fixed the regression **only** for `homeConfigurations.benjamin`,
  explicitly noting the NixOS-integrated path was left unchanged/byte-identical to baseline (i.e.
  the same defect, pre-existing, not introduced by task 66, and not fixed by it either).
- `9946058` (task 86 phase 5): touched `docs/dual-home-manager.md` and `docs/discord-bot.md`
  only — no `.nix` file changes for the task-69 fold-in. Confirms 86 performed documentation only,
  not code unification, consistent with its own commit message.

## Decisions

- Verification confirms task 86 did **not** unify `extraSpecialArgs`; it documented the asymmetry
  and asserted it is intentional/non-bug.
- Live `nix eval` evidence contradicts the "not a bug" characterization for the NixOS-integrated
  side: that side installs a non-functional `lectic` reference (raw flake source, no `bin/`),
  which is only masked by `$PATH` priority favoring the standalone profile.
- This is **not** a verification-only close-out. Recommend **outcome (B)**: a minimal,
  documentation-scoped resolution, using the task's own explicit allowance for "a minimal
  specialArgs alignment if trivial" — which this is, since the correct resolution expression
  already exists verbatim three lines away in `lib/mkHost.nix`'s own top-level `specialArgs`.

## Recommended Minimal Resolution (Option A, documentation-only + trivial alignment)

1. **`lib/mkHost.nix`** — change the one line in `home-manager.extraSpecialArgs`:
   ```nix
   # before
   inherit lectic;
   # after
   lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
   ```
   This mirrors the exact expression already used in the same file's `specialArgs` block (3 lines
   below) and in `flake.nix`'s standalone override — no new pattern introduced, one line changed
   in one file. This fixes `nandi`/`hamsa`/`garuda`/`usb-installer`'s per-user profile to carry a
   real, working `lectic` binary instead of a silently-inert raw source checkout.

2. **`docs/dual-home-manager.md`** — replace the "intentional divergence, not a bug" paragraph
   (added by task 86) with a short note that the two paths are now unified on the resolved
   `lectic` package (both use `lectic.packages.${system}.lectic or ... or lectic`), and remove the
   "do not unify these" instruction from `flake.nix`'s comment (or update it to reflect that they
   are now the same value, kept as two call sites because the arg-passing plumbing differs
   structurally between `lib/mkHost.nix` and the standalone `homeConfigurations` block, not
   because the *value* should differ).

3. **Do not** touch `home-manager.useGlobalPkgs`, `useUserPackages`, the aggregator modules, or
   any of task 86's opt-in wiring (`hosts/nandi/default.nix`, `modules/system/default.nix`,
   `modules/home/default.nix`) — those are out of scope and already verified working by 86.

This keeps the change surface to exactly what the rescoped task description authorizes: finalize
the doc, plus a one-line specialArgs alignment because it is trivial and directly closes the
original bug this task was created to fix (the task 66 phase 9 "lectic regression").

## Risks & Mitigations

- **Risk**: Changing `lib/mkHost.nix`'s `home-manager.extraSpecialArgs` changes the derivation
  closure for `nandi`/`hamsa`/`garuda`'s NixOS-integrated home-manager profile (adds the real
  ~280 MiB `lectic` + node_modules where previously nothing usable was linked). This is a closure
  *growth*, not a behavior regression, but should be called out in the commit message and briefly
  verified with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or at least
  `nix eval ...home.packages` re-check) before considering it done, consistent with task 86's own
  practice of eval-level verification.
- **Risk of scope creep**: it would be easy to over-fix by also touching `useGlobalPkgs`/
  aggregator wiring. Explicitly out of scope — task 86 already owns and verified that surface.
- **Mitigation**: the fix is a single line plus a doc paragraph; no new abstractions, no new
  files, no new options.

## Appendix

### Verification commands used

```bash
nix eval .#nixosConfigurations.nandi.config.home-manager.users.benjamin.home.packages \
  --apply 'map (p: (p.name or "NO-NAME"))'

nix eval .#nixosConfigurations.nandi.config.home-manager.users.benjamin.home.packages \
  --apply 'ps: map builtins.attrNames (builtins.filter (p: !(p ? name)) ps)'

nix eval .#homeConfigurations.benjamin.config.home.packages \
  --apply 'map (p: (p.name or "NO-NAME"))'

git log --oneline -20 -- docs/dual-home-manager.md lib/mkHost.nix flake.nix
git show b864e63   # task 66 phase 9 regression fix (standalone only)
git show 9946058   # task 86 phase 5 doc fold-in (no .nix changes)
```

### File/line references

- `lib/mkHost.nix:44-49` (`home-manager.extraSpecialArgs`, unresolved `lectic`)
- `lib/mkHost.nix:52-57` (top-level `specialArgs`, correctly resolved `lectic`, same file)
- `flake.nix:83-88` (`hmExtraSpecialArgs`, shared base, unresolved `lectic`)
- `flake.nix:199-207` (`homeConfigurations.benjamin` override, correctly resolved `lectic`,
  with the "do not unify" comment added by task 66 phase 9 / referenced by task 86)
- `docs/dual-home-manager.md` (`extraSpecialArgs divergence (intentional)` bullet, added by task
  86, commit `9946058`)
- `modules/home/packages/lean-math.nix:1-7` (consumer of the `lectic` arg; confirms it lands
  directly in `home.packages`)

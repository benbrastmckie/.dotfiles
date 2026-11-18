# Implementation Summary: Sapience standalone flake and nixpkgs blockers

**Completed**: 2026-11-04
**Duration**: ~1 implementation session (7 phases)

## Overview

Built `packages/sapience-flake/`, a self-contained, vendor-shareable NixOS/Home Manager flake
packaging the Sapience client, forked out of this repository's live
`modules/home/services/sapience.nix` module. The directory evaluates and builds entirely on its
own when copied outside this repository — verified directly, not assumed. It exposes
`homeManagerModules.sapience` plus `packages.<system>.{sapience,sf1,sapience-bootstrap}` built
from one shared wrapper-script builder, carries a generalized set of defaults suited to a
stranger rather than this machine, and ships a `README.md` documenting the Claude Code
hooks/statusline gap and the three evidenced reasons a nixpkgs submission is not possible today,
plus the two concrete vendor asks that would unblock two of the three. The live
`modules/home/services/sapience.nix` and `home.nix` are confirmed byte-identical and untouched.

## What Changed

- `packages/sapience-flake/modules/sapience.nix` — new file: generalized fork of the live module
  (`backend` default `relay`, `memoryFiles` default `true`, `apiKeyFile` example
  de-machine-specific-ized, header retargeted at a flake consumer, ticker gate widened to also
  require `config.services.ollama.enable`)
- `packages/sapience-flake/lib/wrappers.nix` — new file: the three CLI wrapper derivations
  (`sapience`, `sf1`, `sapience-bootstrap`) plus the shared constants they and the module's other
  config glue both need (`python`, `runtimePath`, `requiredPayload`, `optionalPayload`),
  parameterized by plain arguments with zero home-manager dependency; adds a runtime
  `systemctl --user is-active --quiet ollama.service` probe for the ticker launch
- `packages/sapience-flake/flake.nix` — new file: standalone flake, single `nixpkgs` input
  pinned to `nixos-26.05`, `homeManagerModules.{sapience,default}`,
  `packages.<system>.{sapience,sf1,sapience-bootstrap,default}` for four systems,
  `lib.mkSapienceWrappers`
- `packages/sapience-flake/flake.lock` — generated lock
- `packages/sapience-flake/README.md` — new file: usage for both output sets, generalized
  defaults table, privacy consequences of the `relay` default, why the payload stays
  deliberately unpinned/mutable, the Claude Code hooks/statusline gap (exact commands and
  permission names, verified against `config/claude/settings.json`), the three nixpkgs blockers
  with live evidence, and the two concrete vendor asks
- `packages/README.md` — new `### sapience-flake/` entry
- `docs/sapience.md` — short pointer to the shareable fork, near "Not packaged as a derivation"

## Decisions

- Expanded `lib/wrappers.nix`'s return beyond the plan's literal `{ sapience, sf1,
  sapience-bootstrap }` to also export `python`/`runtimePath`/`requiredPayload`/`optionalPayload`,
  because the module's own non-wrapper config glue (payload-seed activation, MCP server
  registration, the sync systemd service) also reads those four constants; the module now
  `inherit`s them from the builder rather than duplicating them.
- Ran `nixfmt` on the whole vendored module file in Phase 2 (not just the touched lines), since
  the live module itself is not nixfmt-clean in two unrelated spots and the plan hard-requires
  `nixfmt --check` to pass on the vendored copy.
- Verified every claim with a live probe or build rather than reasoning from the Nix source
  alone: a `lib.evalModules` scratch harness built `sapience-bootstrap` under three
  backend/ollama-enable combinations and diffed the rendered scripts (Phases 3 and 4); the
  standalone flake was evaluated and built both in-repo (via `git add -N`) and from a genuine
  out-of-repo scratch copy (Phase 7); a minimal standalone `homeManagerConfiguration` was built
  to confirm the generalized defaults produce no Ollama-related warning.

## Plan Deviations

- **Phase 2** `nixfmt --check` task: altered — formatting the vendored copy also reformatted two
  pre-existing, unrelated whitespace blocks (`sapienceTokenRepair`, `sapienceMcpServer`) that are
  not nixfmt-clean in the live module either (confirmed independently). The live-vs-vendored diff
  therefore carries two extra whitespace-only hunks beyond the intended header/three-options
  change.
- **Phase 4**, three items: (1) `lib/wrappers.nix`'s return set expanded to also export
  `python`/`runtimePath`/`requiredPayload`/`optionalPayload`, discovered necessary because the
  module's other config glue reads them too; (2) two irreducible `grep -nE '\bcfg\.|\bconfig\.'`
  hits remain in `lib/wrappers.nix` — both are the literal `config.json` filename the vendor's
  client actually reads/writes, not a stray attribute access; (3) the ticker-gate comment's
  wording (not its logic) changed when moved into `lib/wrappers.nix`, to drop the `cfg.`/`config.`
  substrings needed for (2) — confirmed via a 3-way scratch build diff that no executable line
  changed.
- **Phase 7**, isolation proof: `git add -A` is blocked outright by this environment's
  `guard-destructive-git.sh` hook, even in a disposable scratch repo outside the project.
  Substituted an explicit full-file-list `git add` in the scratch repo — same effect.
- **Phase 7**, Nix gate set / Reasoned Exclusions: `statix check packages/sapience-flake/` has
  one remaining, irreducible warning ("Avoid repeated keys in attribute sets" on the vendored
  module's `home.packages`/`home.activation.*` block), inherited verbatim from the live module,
  which carries the identical warning — confirmed by running `statix` on the untouched live file.
  Fixed 8 of the original 9 statix warnings (all in this task's own new "use inherit" code); this
  one is out of scope to fix without restructuring content that came verbatim from the live
  module. The darwin systems (`x86_64-darwin`/`aarch64-darwin`) in the flake's `systems` list were
  never built in this `x86_64-linux`-only environment, beyond `nix flake show`'s cross-system
  attribute listing. Both recorded as Reasoned Exclusions on Phase 7's heading.

## Verification

- Flake check (standalone, out-of-repo scratch copy): Success
- `nix flake show` (out-of-repo, `git+file://` URL): Success, confirms true isolation
- `nix build .#sapience .#sf1 .#sapience-bootstrap` (out-of-repo): Success, all three `bin/`
  entries present, `bash -n` clean
- Minimal standalone `homeManagerConfiguration` smoke test: Success, builds an
  `activationPackage`; zero Ollama-related warnings (one unrelated HM/nixpkgs version-mismatch
  warning from the ad hoc test harness itself)
- Protected-file gate: `git diff --stat modules/home/services/sapience.nix home.nix` empty;
  `git status --short` empty for both
- Parent repo `nix flake check`: Success ("all checks passed!")
- Parent repo `home-manager build --flake .` (`homeConfigurations.benjamin`): Success
- `nixfmt --check` on all three new `.nix` files: Success
- `deadnix packages/sapience-flake/`: Success (clean)
- `statix check packages/sapience-flake/`: one inherited, evidenced, excluded warning (see
  Phase 7's Reasoned Exclusions)
- `grep -rniE 'benjamin|\.dotfiles' packages/sapience-flake/`: no matches
- `check-task-references.sh` on the README and both doc-wiring files: 0 unexempted occurrences
- All three Claude Code hook commands and all seven `mcp__sapience__*` permission names verified
  verbatim against `config/claude/settings.json` via JSON parse (not raw-text grep, which would
  false-fail on JSON quote-escaping)

## Notes

- `packages/sapience-flake/` is deliberately **not** wired into this repository's own
  `nixosConfigurations`/`homeConfigurations` or overlays — it is a nested, independent flake
  meant to be copied elsewhere.
- The vendor payload stays unpinned/mutable in the standalone flake too, by design — documented
  prominently in the README rather than "fixed."
- `nix flake show` cannot introspect the `homeManagerModules`/`lib` outputs (reports them as
  `unknown`), since those are non-standard output schemas for that command; this is expected and
  not a defect — `nix build`/`nix eval` against them both succeed.

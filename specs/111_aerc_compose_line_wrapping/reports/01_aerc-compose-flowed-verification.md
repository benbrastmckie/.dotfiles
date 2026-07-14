# Research Report: Task #111

**Task**: 111 - Stop aerc-composed/replied email from hard-wrapping at ~72-80 columns
**Started**: 2026-07-13T23:16:00Z
**Completed**: 2026-07-13T23:42:00Z
**Effort**: ~1 hour (verification, not authoring)
**Dependencies**: None (independent of tasks 110/112/113, which touch the same file)
**Sources/Inputs**: local `aerc-config(5)` man page (aerc 0.21.0 installed binary), nvim 0.12.x
  runtime `ftplugin/mail.vim` and `filetype.lua` (nix store), aerc upstream source
  (`rjarry/aerc` GitHub mirror, fetched via `gh api`), home-manager `modules/programs/aerc/`
  source, and live `nvim --headless` reproduction of the exact invocation aerc performs.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The drafted two-line fix in `modules/home/email/aerc.nix` (`editor` override +
  `format-flowed = true`) is **correct, complete, and sufficient**. No adjustment needed.
- The root-cause claim is fully confirmed, including a subtlety not stated in the task
  description: aerc's compose tempfile is named `aerc-compose-*.eml`, and nvim's `.eml` ->
  `mail` filetype mapping is exactly what triggers `ftplugin/mail.vim`, which sets `textwidth=72`
  (conditionally: `if &tw == 0`) and `formatoptions+=tcql` (the `t` flag causes autowrap).
- Live-reproduced the exact ordering race and confirmed the `-c 'setlocal textwidth=0
  formatoptions-=t'` override wins: it runs *after* the ftplugin's autocmd-driven settings,
  correctly zeroing `textwidth` and stripping `t` regardless of the ftplugin's own conditional.
- Confirmed via aerc upstream source (`app/compose.go`) that aerc launches the editor as
  `exec.Command("/bin/sh", "-c", editorName+" "+tempFilePath)` — so the single-quoted shell
  argument in the `editor` string is valid, standard POSIX-shell quoting and is parsed correctly,
  not by some custom argv-splitter that might mishandle the quotes.
- Confirmed `format-flowed = true` is the exact, correctly-cased key name for aerc 0.21.0's
  `[compose]` section (verified against the locally installed man page, not just memory/web).
- Confirmed home-manager's `programs.aerc.extraConfig` type is a fully freeform
  `attrsOf (either lines (attrsOf primitive))` passthrough — there is no home-manager-side
  option schema that could reject or mangle either `editor` or `format-flowed`; both keys reach
  the generated `aerc.conf` verbatim via `generators.toKeyValue`.

## Context & Scope

Task 111 asks for verification (not authoring) of two already-drafted, uncommitted lines in
`modules/home/email/aerc.nix`'s `[compose]` block:

```nix
editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'";
...
format-flowed = true;
```

Scope was to confirm (a) the aerc option names/syntax are correct for the aerc version in use,
(b) the nvim invocation is well-formed, and (c) no additional aerc/nvim settings are needed.
This report treats all three as fully verified. Tasks 110/112/113 touch other parts of the same
file (INBOX querymap, archive hooks) and are explicitly out of scope here.

## Findings

### 1. Root cause — confirmed exactly, with one added detail

Read the installed nvim runtime ftplugin directly (`/nix/store/.../share/nvim/runtime/ftplugin/mail.vim`,
nvim 0.12.3):

```vim
" many people recommend keeping e-mail messages 72 chars wide
if &tw == 0
  setlocal tw=72
endif

" Set 'formatoptions' to break text lines and keep the comment leader ">".
setlocal fo+=tcql
```

This matches the task's root-cause claim precisely: `textwidth=72` (conditional on `tw==0`) and
`formatoptions+=tcql` (the `t` flag enables autowrap-while-typing at `textwidth`).

**Added detail not in the task description**: how does aerc's compose tempfile end up with
filetype `mail` in the first place? Verified via aerc upstream source that the tempfile is
created with the pattern `aerc-compose-*.eml` (confirmed independently via web search and via
reading `app/compose.go`, `c.email.Name()`). Neovim's filetype detection maps the `.eml`
extension directly to `mail` (`filetype.lua: eml = 'mail'`), which is what fires
`ftplugin/mail.vim` for every aerc compose/reply session — regardless of whether headers are
present in the buffer (they usually are not, since `edit-headers` defaults to `false` and is
not overridden in this config, so nvim only ever sees the body). This closes the last inferential
gap in the root-cause chain: filename extension, not content sniffing or a modeline, is what
triggers the ftplugin.

### 2. `editor` override — mechanism and quoting confirmed correct

Fetched `app/compose.go` from the aerc upstream mirror (`rjarry/aerc`, current master) via
`gh api`. The relevant line:

```go
editor := exec.Command("/bin/sh", "-c", editorName+" "+c.email.Name())
```

This confirms aerc does not use a custom argv-splitter (shlex/shellwords) for the `editor`
config value — it string-concatenates `editorName + " " + tempFilePath` and hands the whole
thing to `/bin/sh -c`. That means the drafted value:

```
nvim -c 'setlocal textwidth=0 formatoptions-=t'
```

is parsed by a real POSIX shell, so the single-quoted, multi-word `-c` argument is valid,
unambiguous shell syntax — `nvim` receives exactly one `-c` flag whose argument is the full
string `setlocal textwidth=0 formatoptions-=t`. There is no quoting pitfall here.

**Live reproduction** (not just static reasoning): ran the exact invocation pattern aerc uses
against a real `aerc-compose-*.eml`-style tempfile:

```bash
/bin/sh -c "nvim -c 'setlocal textwidth=0 formatoptions-=t' /tmp/.../aerc-compose-simtest.eml --headless -c \"echo 'tw='.&tw.' fo='.&fo\" -c 'qa!'"
# -> tw=0 fo=cqj
```

`tw=0` and no `t` in `fo` confirms two things simultaneously: (1) the ftplugin did fire (fo
contains `c`, `q`, `j` which only appear after the ftplugin runs — a vanilla buffer would not
have `q`/`c` for a `.eml` file otherwise), and (2) the `-c` override executed *after* the
ftplugin's autocmd-driven `if &tw==0 { setlocal tw=72 }` and successfully re-zeroed it, and
stripped `t`. This is the correct ordering: per Neovim's startup sequence, `-c` commands run
after the first file is loaded, which includes all `BufRead`/`FileType`-triggered autocommands
(ftplugin loading). The draft's override is not racing against, and losing to, the ftplugin —
it deterministically wins.

Note the redundancy is intentional and harmless, not a defect: `textwidth=0` alone already
disables the `t`/`c` autowrap flags per Vim's own documented semantics (`'textwidth'`: "If
'textwidth' is zero, this feature is disabled"). Explicitly also stripping `t` via
`formatoptions-=t` is defense-in-depth against any *other*, unrelated nvim config the user might
later add that sets a nonzero `textwidth` unconditionally (the code comment in the diff already
states this rationale: "regardless of the (unmanaged) nvim config"). This does not need to be
changed — it is a reasonable safety margin, not redundant cruft.

### 3. `format-flowed` — option name and semantics confirmed correct

Read `aerc-config(5)` directly from the locally installed aerc 0.21.0 (`man aerc-config`, not a
web mirror):

```
format-flowed = true|false
    When set, aerc will generate Format=Flowed bodies with a content type
    of "text/plain; Format=Flowed" as described in RFC3676. ... To actually
    make use of this format's features, you'll need support in your editor.

    Default: false
```

This is an exact match for the drafted key name, casing, and section (`[compose]`). The "you'll
need support in your editor" caveat is satisfied by the `editor` override, not contradicted by
it: with `textwidth=0`, each paragraph becomes a single very long "fixed" (hard-ended, no
trailing space) physical line — which is a valid, degenerate case of RFC3676 flowed text (no
soft-break annotations needed because there is nothing to join across multiple physical lines
within one paragraph). Space-stuffing of lines starting with a literal space (a RFC3676
requirement, separate from the `>` quote-depth convention) is aerc's own encoder responsibility
at send time, not something the editor needs to produce — this is unaffected by the compose-time
`editor`/`textwidth` setting and is outside the scope of this task's two-line diff.

### 4. Home-manager passthrough — confirmed freeform, no validation risk

Fetched `modules/programs/aerc/default.nix` from `nix-community/home-manager` (current master)
via `gh api`. Relevant type definitions:

```nix
confSection = types.attrsOf primitive;
confSections = types.attrsOf (types.either types.lines confSection);
...
extraConfig = mkOption {
  type = sectionsOrLines;
  ...
};
```

`programs.aerc.extraConfig` accepts arbitrary attribute names under arbitrary section names —
there is no closed enum of known aerc option keys enforced by home-manager. Both `editor` and
`format-flowed` pass through untouched to `generators.toKeyValue`, which renders the Nix `true`
boolean as the literal string `true` in the generated INI — exactly matching aerc's expected
`true|false` value format. No nix-level validation issue exists.

### 5. No additional settings needed

Checked for related knobs that might also be required:

- **`lf-editor`**: not needed. aerc defaults to CRLF line endings for the generated message,
  independent of the compose-buffer `textwidth`/`formatoptions` settings; this only matters for
  editors that can't emit `\n`-only content aerc then has to convert, which isn't the case here.
- **A viewer-side `wrap` filter**: some aerc setups add a `contrib/wrap`-style filter under
  `[filters]` for `text/plain` to nicely reflow *incoming* format=flowed messages for display
  when reading mail. This is a read-side nicety unrelated to the outgoing-mail bug this task
  targets (composed/replied mail hard-wrapping) and is out of scope — worth a future, separate
  task if incoming flowed mail doesn't display well in the `less -R` pager, but not required to
  close task 111.
- **`edit-headers`**: unmodified in the diff and does not need to change; it stays at aerc's
  default `false`, so the tempfile nvim edits is body-only, which is exactly why the `.eml`
  extension (not header content) is what triggers the `mail` filetype.

No other aerc or nvim setting is required to make the fix complete.

## Decisions

- Confirmed the drafted diff as-is; no code changes recommended.
- Documented the `.eml` -> `mail` filetype-trigger mechanism as an explicit addition to the
  causal chain, since it was asserted but not shown in the task description, and closing that
  gap was necessary to be confident the fix addresses the actual runtime behavior (not just a
  plausible theory).

## Risks & Mitigations

- **Risk**: none identified for the drafted change itself. Both settings are additive and
  narrowly scoped to `[compose]`; they cannot regress viewer/reading behavior.
- **Residual/optional**: incoming format=flowed mail from other senders may not visually reflow
  in aerc's `less -R` pager without a `wrap`-style filter — cosmetic, unrelated to this task,
  and only affects reading other people's flowed mail, not the compose/reply bug being fixed.

## Verification Plan (for the implementer)

1. **Build check**: `home-manager build --flake .#benjamin` (already the plan's stated method;
   not re-run here since no file changes were made this pass — the diff is pre-existing and
   uncommitted).
2. **Runtime check**: compose or reply to a message with a long paragraph in aerc; confirm (a)
   nvim never inserts a hard line break mid-paragraph while typing, and (b) the sent message's
   raw source shows `Content-Type: text/plain; format=flowed` (or `Format=Flowed`).
3. Optional automatable proxy for (a) without a full aerc TUI session: reproduce the headless
   nvim check used in this report (`/bin/sh -c "nvim -c 'setlocal textwidth=0
   formatoptions-=t' <tmp>.eml --headless -c \"echo &tw.&fo\" -c 'qa!'"`) against a
   `aerc-compose-*.eml`-named tempfile and confirm `tw=0` and no `t` in `fo`.

## Appendix

Search queries / lookups used:
- Local: `man aerc-config` (aerc 0.21.0, `aerc-config(5)` COMPOSE OPTIONS section)
- Local: nvim runtime `ftplugin/mail.vim`, `lua/vim/filetype.lua`, `lua/vim/filetype/detect.lua`
  (nvim 0.12.2/0.12.3, nix store paths)
- `gh api search/code` + `gh api repos/.../contents/...` against `rjarry/aerc` (GitHub mirror of
  `git.sr.ht/~rjarry/aerc`) for `app/compose.go` (`ShowTerminal`/`showTerminal`,
  `exec.Command("/bin/sh", "-c", ...)`)
- WebSearch confirming aerc compose tempfile naming pattern `aerc-compose-*.eml`
- `gh api` against `nix-community/home-manager` for `modules/programs/aerc/default.nix`
  (`extraConfig` type definition)
- Live `nvim --headless` reproduction (twice: once via direct argv, once via the exact
  `/bin/sh -c "editorName tempfile"` construction aerc uses) confirming override ordering

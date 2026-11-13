# Coordinated Follow-Ups, Sited in the nvim Repository

This task performs neither of the two follow-ups below. Both are named here, precisely, so the
coordination requirement is discharged without widening this task's own edit-target list
(`config/claude/settings.json`, `modules/home/services/sapience.nix`, `docs/sapience.md`,
`home.nix`). Both follow-ups' edit targets live under
`agent-system/extensions/` or `core/` in `/home/benjamin/.config/nvim`'s source store, so per
`.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection, each belongs to a task
filed in that repository, not here.

## Follow-up (a): Update the stale sapience worked example

**File**: `agent-system/core/context/patterns/mcp-server-ownership.md`, in
`/home/benjamin/.config/nvim`.

**Why it goes stale**: that file carries a sapience worked example that holds only while two
surfaces coexist: the dotfiles-level seven-tool `permissions.allow` read-grant list and the
top-level `mcpServers.sapience` merge into `~/.claude.json`. This task's Phase 2 and Phase 3
removed both. The moment this task lands, that worked example describes a machine-wide
arrangement that exists nowhere in this repository or on this machine.

**What the follow-up should do**: rewrite the worked example to describe the arrangement this
task leaves in place instead — per-repository hooks and grants merged from
`agent-system/extensions/sapience/settings-fragment.json`, plus the one durable, machine-wide
`SessionStart` registration hook in `config/claude/settings.json` that makes per-project
registration survive a `home-manager switch`.

**Why it should run alongside this task, not after it**: the companion project
(`gate_sapience_activation_behind_extension`, project 612) named this update as something to do
"together with" this task's removal, specifically to close the staleness window rather than
leave it open between the two landings.

## Follow-up (b): Resolve an SF-1 card worktree to its parent checkout for registration

**Files**: the per-project MCP-registration logic under
`agent-system/extensions/sapience/scripts/` and `agent-system/extensions/sapience/hooks/`, in
`/home/benjamin/.config/nvim`.

**The gap**: per-project MCP registration keys on the repository's absolute path and on whether
that repository's own `.claude-extensions.json` carries an active sapience extension. An SF-1
card session runs inside a throwaway git worktree under
`~/.local/state/sf1-hub-ben/hub/runner/work/`, which matches no registered project path and
carries no `.claude-extensions.json` of its own (verified: no tracked `.claude/` tree in the card
repository at all). The worktree therefore gets no registration and no tools at all — including
the scoped retrieval tool (`sapience_search`, reached indirectly via
`agent-system/extensions/sapience/scripts/sapience-retrieve.sh`'s `[repo:<slug>]` provenance
filter) that SHOULD be available there, since that tool's retrieval is already scoped to the
card repository's own accumulated decisions and findings — precisely the material a card doing
work in that repository should be able to draw on. This is a known, deliberate gap, not something
this task closes or claims to close (see Verification this task owns in the dispatch, and
acceptance criterion 3).

**What the follow-up should do**: resolve a worktree path to its parent checkout before applying
the registration decision, so the card repository's own repo-scoped retrieval becomes reachable
from inside the worktree. `git rev-parse --git-common-dir` resolves a worktree to its checkout in
one call. There is already a precedent for this exact resolution inside the SF-1 hub runner
itself: its memory sync already keys on the checkout path, not the worktree path, which is why
room rulings land under the card repository's own Claude Code memory directory today regardless
of this task's change.

**What must NOT change**: hook-injected context (`SessionStart`, `UserPromptSubmit`,
`PreToolUse`) must continue to reach NO card session, because none of those three sites can be
scoped to a repository from this side (see
`agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`).
The follow-up is scoped to the retrieval channel only (`sapience_search` and
`sapience-retrieve.sh`), never to re-enabling hook injection in a worktree.

# Research Report: Task #3

**Task**: Fix meta.md directory creation specification conflict
**Date**: 2026-02-02
**Focus**: Compare .dotfiles and ProofChecker .claude/ systems to identify discrepancies

## Summary

Comparative analysis reveals that **both repositories have identical .claude/ systems** with the same specification conflict. The ProofChecker repository appears to work correctly because tasks went through the standard `/research` → `/plan` → `/implement` workflow, not because of different specifications. The directory creation issue exists in both systems but may not have manifested due to different usage patterns.

## Findings

### 1. Specification Conflict (CONFIRMED IN BOTH REPOS)

**Location**: `.claude/commands/meta.md` line 29

**Problematic text** (identical in both):
```markdown
**REQUIRED** - This command MUST:
- Track all work via tasks in TODO.md + state.json
- Require explicit user confirmation before creating any tasks
- Create task directories for each task      <-- LINE 29: CONFLICTS
- Delegate execution to skill-meta
```

**Conflicting rule**: `.claude/rules/state-management.md` lines 226-257
```markdown
### Lazy Directory Creation Rule

Create task directories **lazily** - only when the first artifact is written...

**DO NOT** create directories at task creation time. The `/task` command only:
1. Updates `specs/state.json` (adds task to active_projects)
2. Updates `specs/TODO.md` (adds task entry)

**WHO creates directories**: Artifact-writing agents (researcher, planner, implementer)
create directories with `mkdir -p` when writing their first artifact to a task.
```

### 2. No Automatic Plan Creation (BY DESIGN IN BOTH REPOS)

**meta-builder-agent.md Stage 6 (lines 317-343)** - identical in both:
```markdown
### Interview Stage 6: CreateTasks

**For each task**:
1. Get next task number
2. Create slug from title
3. Update state.json
4. Update TODO.md
```

No plan creation is specified. Plans are created by the `/plan` command.

**ProofChecker tasks have plans because**:
- They followed the workflow: `/task` → `/research N` → `/plan N` → `/implement N`
- Example: Task 812 has `**Plan**: [implementation-002.md](...)`
- The plan was created by `/plan 812`, not by `/meta`

### 3. Repository-Specific Customizations (EXPECTED)

Only the language keyword detection differs between repos:

| Location | .dotfiles | ProofChecker |
|----------|-----------|--------------|
| meta-builder-agent.md:234 | `"nvim", "neovim", "plugin"` | `"lean", "theorem", "proof"` |
| meta-builder-agent.md:379 | `"neovim", "plugin", "command"` | `"lean", "proof", "command"` |

These are intentional per-repository customizations for language routing.

### 4. Why ProofChecker "Works Correctly"

**Hypothesis**: The ProofChecker repository didn't encounter the empty directory issue because:

1. **Tasks were created manually or through `/task`** - which doesn't create directories
2. **The `/meta` command was used less frequently** - so the specification conflict wasn't exercised
3. **When `/meta` was used, the empty directories were created but not noticed** - they don't cause functional problems

**Evidence**: ProofChecker's TODO.md shows 813 tasks. Most have plans and research reports, meaning they went through the standard workflow that creates directories lazily when artifacts are written.

## Root Cause Analysis

### Issue: Empty Directory Creation

| Step | What Should Happen | What Happened |
|------|-------------------|---------------|
| `/meta` invoked | Read spec, see line 29 "Create task directories" | Created empty directories |
| Correct behavior | Only update TODO.md and state.json | Would defer directory creation to `/research` or `/plan` |
| Root cause | Outdated specification in meta.md line 29 | Conflicts with state-management.md rule |

### Issue: No Plan Artifacts from /meta

This is **not a bug** - it's the intended design:
- `/meta` creates task entries only
- `/plan` creates implementation plans
- The workflow is documented in the output: "Progress through /research -> /plan -> /implement cycle"

## Recommendations

### Fix 1: Update meta.md line 29 (HIGH PRIORITY)

**Current**:
```markdown
- Create task directories for each task
```

**Proposed**:
```markdown
- Directories created lazily when artifacts are written (per state-management.md)
```

Or simply remove the line entirely since it's covered by state-management.md.

### Fix 2: Clarify Workflow in Output (LOW PRIORITY)

The "Next Steps" output already mentions the workflow:
```
1. Review tasks in TODO.md
2. Run `/research {N}` to begin research on first task
3. Progress through /research -> /plan -> /implement cycle
```

Could add explicit note that plans are created by `/plan`, not `/meta`.

### Fix 3: No Change Needed for Plan Creation

The current design is correct:
- `/meta` creates task entries for system-building work
- User runs `/plan N` to create implementation plan
- This matches the ProofChecker workflow that works correctly

## References

- `.claude/commands/meta.md` lines 26-30 (specification conflict)
- `.claude/rules/state-management.md` lines 226-257 (lazy directory creation rule)
- `.claude/agents/meta-builder-agent.md` lines 317-343 (task creation logic)
- `/home/benjamin/Projects/ProofChecker/specs/TODO.md` (example of working workflow)

## Next Steps

1. Edit `.claude/commands/meta.md` line 29 to remove directory creation requirement
2. Verify change aligns with state-management.md
3. Test by running `/meta` and confirming no directories are created

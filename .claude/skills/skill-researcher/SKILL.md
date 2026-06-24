---
name: skill-researcher
description: Conduct general research using web search, documentation, and codebase exploration. Invoke for general research tasks.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/context/formats/report-format.md
# Original tools (now used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Researcher Skill

Thin wrapper that delegates general research to `general-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "general", "meta", "markdown", "latex", or "typst"
- Research is needed for implementation planning
- Documentation or external resources need to be gathered

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

```bash
.claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

This atomically updates state.json (status, timestamps, session_id), TODO.md task entry, and TODO.md Task Order section. If the script exits non-zero, abort and keep current status.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-researcher",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Read Artifact Number

Read `next_artifact_number` from state.json (or fall back to directory scanning for legacy tasks):

```bash
# Read next_artifact_number from state.json
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks: count existing artifacts
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

# Reconciliation: scan all task subdirs for max artifact number on disk
# Handles legacy tasks where next_artifact_number may be behind actual files
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(find "specs/${padded_num}_${project_name}" -name "[0-9][0-9]_*.md" 2>/dev/null \
  | sed 's|.*/\([0-9][0-9]\)_.*|\1|' | sort -n | tail -1)
max_on_disk=${max_on_disk:-0}
# Strip leading zeros to avoid octal interpretation
max_on_disk=$((10#$max_on_disk))
if [ "$artifact_number" -le "$max_on_disk" ]; then
  artifact_number=$((max_on_disk + 1))
  # If reconciliation advanced the number, also sync state.json so subsequent operations stay in sync
  jq --argjson num "$task_number" --argjson new_num "$artifact_number" \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number = $new_num' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

artifact_padded=$(printf "%02d" "$artifact_number")

# Collision check: ensure no existing file uses this prefix in reports/
while ls "specs/${padded_num}_${project_name}/reports/${artifact_padded}_"*.md 2>/dev/null | grep -q .; do
  artifact_number=$((artifact_number + 1))
  artifact_padded=$(printf "%02d" "$artifact_number")
done
```

---

### Stage 4a: Memory Retrieval (Auto)

Retrieve relevant memories from the memory system to inject into the delegation context.

**Skip if**: `clean_flag` is true in the delegation context (from `--clean` command flag).

```bash
# Check clean_flag
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi

# memory_context will be empty string if:
# - clean_flag is true (skipped)
# - memory-index.json missing or empty
# - no keywords matched any entries
# - script exited with error
```

If `memory_context` is non-empty, it will be injected into the Stage 5 prompt alongside the format specification from Stage 4b. If empty, no memory block is injected.

```bash
# Literature sub-index detection (interactive setup when sub-index is missing)
lit_context=""
if [ "$lit_flag" = "true" ] && [ ! -f "specs/literature-index.json" ]; then
  LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
  GLOBAL_INDEX="$LIT_DIR/index.json"
  if [ ! -f "$GLOBAL_INDEX" ]; then
    # Global index missing -- inform user and continue without literature context
    echo "Note: --lit flag used but no global Literature index found at $GLOBAL_INDEX. Continuing without literature context." >&2
    # lit_context remains ""
  else
    # Global index exists but sub-index is missing -- present interactive setup options
    # (AskUserQuestion must be called inline here; cannot be delegated to a shell script)
    #
    # Present AskUserQuestion with 3 options:
    # 1. Skip: Continue without literature context
    # 2. Create setup task: Create task and continue without literature context now
    # 3. Create task and run now: Create task, populate sub-index inline, then use it
    #
    # Pseudocode (executed by Claude as the skill runs):
    #   user_choice = AskUserQuestion(
    #     "The --lit flag was used but specs/literature-index.json does not exist for this repo.\n\n" +
    #     "A global Literature index was found at $GLOBAL_INDEX.\n\n" +
    #     "How would you like to proceed?",
    #     options=[
    #       "Skip: Continue without literature context (--lit is ignored this time)",
    #       "Create setup task: Create a task to populate the sub-index, then continue without literature context",
    #       "Create task and run now: Create the task AND populate specs/literature-index.json inline before proceeding"
    #     ]
    #   )
    #
    # After user_choice:
    #   if "Skip":
    #     lit_context=""  (already set, no action needed)
    #
    #   if "Create setup task":
    #     new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
    #     echo "Created task $new_task_num to populate specs/literature-index.json. Run /orchestrate $new_task_num to populate before using --lit."
    #     lit_context=""  (continue without literature context)
    #
    #   if "Create task and run now":
    #     new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
    #     echo "Created task $new_task_num. Populating specs/literature-index.json inline via fork agent..."
    #     # Fork dispatch: inline population of sub-index (see Stage 4a-fork below)
    #     # After fork completes and sub-index exists:
    #     lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
    :
  fi
fi
```

**Stage 4a-fork: Inline population (option "Create task and run now")**

When the user selects "Create task and run now", after calling `literature-create-setup-task.sh`:

1. Invoke the Agent tool with `subagent_type: "fork"` and a prompt instructing the fork to:
   - Read `~/Projects/Literature/index.json` (or `$LITERATURE_DIR/index.json`)
   - Read `specs/state.json` to understand this repo's task descriptions and domain
   - Analyze keyword/topic overlap between global index `keywords`, `project_tags`, and `summary` fields and the repo's task descriptions
   - Write matched entries to `specs/literature-index.json` with this schema:
     ```json
     {
       "entries": [
         {"doc_id": "<id>", "relevance": "<one-sentence note>", "source": "discover"}
       ]
     }
     ```
   - Update the newly created task (number from step above) to `completed` status in `specs/state.json`
   - Call `bash .claude/scripts/generate-todo.sh` after updating state.json

2. After the fork returns, check if `specs/literature-index.json` was created:
   - If yes: run `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""`
   - If no (fork failed or timed out): log a warning, report the task number, suggest `/orchestrate N`, set `lit_context=""`

```bash
# Literature briefing injection (runs if sub-index already exists OR was just created by fork)
if [ "$lit_flag" = "true" ] && [ -f "specs/literature-index.json" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature-index.json is empty or missing (after all detection/setup above)
# - script exited with error
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "focus_prompt": "{optional focus}",
  "effort_flag": "{effort_flag from command, null if not set}",
  "model_flag": "{model_flag from command, null if not set}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`).

**Model/Effort Flags**: If `model_flag` is set (haiku, sonnet, opus), pass it as the `model` parameter on the Agent tool to override the agent's frontmatter default. If `effort_flag` is set (fast, hard), include it as prompt context for reasoning depth guidance.

---

### Stage 4b: Read and Inject Format Specification

Read the report format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context, regardless of whether it reads the file itself.

```bash
format_content=$(cat .claude/context/formats/report-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt (see below).

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "general-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute research for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Report Format Requirements

You MUST follow this format specification exactly when writing the research report.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

**Memory Context Injection**: If `memory_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

```
{memory_context from Stage 4a -- already wrapped in <memory-context> tags}
```

Place the memory context block AFTER the format specification and BEFORE the task-specific instructions. Do NOT inject an empty `<memory-context>` block when no memories were retrieved.

**Literature Briefing Injection**: If `lit_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

```
{lit_context from Stage 4a -- already wrapped in <literature-briefing> tags}
```

Place the literature briefing block AFTER the memory context block (if any) and BEFORE the task-specific instructions. Do NOT inject an empty `<literature-briefing>` block when no literature briefing was generated.

**DO NOT** use `Skill(general-research-agent)` - this will FAIL.

The subagent will:
- Search codebase for related patterns
- Search web for documentation and examples
- Analyze findings and synthesize recommendations
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value `"researched"` and the appropriate artifact information.

If you DID use the Agent tool (Stage 5), skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return (Read Metadata File)

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status is "researched" and `artifact_path` is non-empty, validate the report artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "researched" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating report artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" report --fix; then
        echo "WARNING: Report artifact has format issues (non-blocking). Review output above."
    fi
fi
```

**Note**: The `--fix` flag attempts auto-repair of missing metadata fields. Validation failures are logged but do not block status update or git commit.

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update status and increment artifact number:

```bash
# Step 1: Update status (state.json, TODO.md task entry, TODO.md Task Order)
if [ "$status" = "researched" ]; then
  .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
fi

# Step 2: Increment next_artifact_number (research advances the sequence)
jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
    (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Note**: Research is the only operation that increments `next_artifact_number`. Plan and implement use `(current - 1)` to stay in the same "round".

**On partial/failed**: Keep status as "researching" for resume (do not call the script).

---

### Stage 7a: Propagate Memory Candidates

If the agent emitted memory candidates, append them to the task's state.json entry using append semantics (merge with any existing candidates from prior operations).

```bash
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    # Append new candidates to existing array (append semantics, not overwrite)
    jq --argjson new_candidates "$memory_candidates" \
      '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates =
        ((.active_projects[] | select(.project_number == '$task_number')).memory_candidates // []) + $new_candidates' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Note**: Uses `// []` fallback so this works whether or not the task already has candidates. Append semantics ensure research and implementation candidates coexist.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Regenerate TODO.md** from state.json (state.json artifact update was done in the step above):

```bash
bash .claude/scripts/generate-todo.sh || echo "WARNING: generate-todo.sh failed (non-fatal)" >&2
```

This regenerates TODO.md from state.json with correct bracket-only `[path]` format artifact links. Never use markdown `[name](path)` format for artifact links. If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 8a: Lifecycle TTS Notification

Fire TTS and WezTerm tab coloring after artifact linking is complete:

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$STATE_STATUS" &
fi
```

Non-blocking: called in background after artifacts are linked. Speaks "Tab N STATUS"
(e.g., "Tab 3 researched") to announce the lifecycle transition.

---

### Stage 9: Cleanup

Remove marker and metadata files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 10: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Research completed for task {N}:
- Found {count} relevant patterns and resources
- Identified implementation approach: {approach}
- Created report at specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "researching"
2. Do not cleanup postflight marker
3. Report error to user

### Subagent Timeout
Return partial status if subagent times out (default 3600s).
Keep status as "researching" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All research work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP/WebSearch tools** - Research tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Incrementing `next_artifact_number` via jq
- Linking artifacts in state.json
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Research completed for task 412:
- Found 8 relevant patterns for implementation
- Identified lazy context loading and skill-to-agent mapping patterns
- Created report at specs/412_general_research/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
```

Example partial return:
```
Research partially completed for task 412:
- Found 4 codebase patterns
- Web search failed due to network error
- Partial report created at specs/412_general_research/reports/MM_{short-slug}.md
- Status remains [RESEARCHING] - run /research 412 to continue
```

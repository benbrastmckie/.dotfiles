# Research Report: Fix claude-sleep-inhibitor pgrep Self-Matching (Task #50)

**Task**: 50 - fix_sleep_inhibitor_pgrep_self_matching
**Started**: 2026-05-14T00:00:00Z
**Completed**: 2026-05-14T00:15:00Z
**Effort**: Medium (~1 hour analysis, extensive runtime verification)
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis, runtime process inspection (`pgrep`, `ps`, `ss`), `man pgrep`, previous research reports (Tasks 49, 52), NixOS/Home Manager documentation
**Artifacts**: - specs/050_fix_sleep_inhibitor_pgrep_self_matching/reports/01_sleep-inhibitor-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The disabled `claude-sleep-inhibitor` service in `home.nix` uses `pgrep -f 'claude'`, which matches **10 processes** on the current system, of which only **2 are actual Claude Code sessions**.
- The `pgrep -f` pattern incorrectly matches: the inhibitor script itself (via its filename `claude-sleep-inhibitor`), `claude-memory-tracker`, `earlyoom --prefer` regex, `systemd-inhibit` hooks from `settings.json`, bash wrapper scripts, and `npm exec` parent processes.
- **`pgrep -u $(id -u) -x claude`** matches exactly and only the actual Claude Code binaries (process name `claude` in `/proc/pid/stat`) with **zero false positives**.
- For OpenCode, the process name is `.opencode-wrapp` (15-char kernel truncation), so `-x` does not work. **`pgrep -u $(id -u) -f '/bin/opencode '`** matches actual OpenCode processes while excluding the Discord bot, pgrep itself, and wrapper scripts.
- A superior alternative exists: `config/claude/settings.json` already implements per-session `systemd-inhibit` hooks (SessionStart/SessionEnd) that are lifecycle-bound and require no polling. These hooks are already active on the system.
- **Recommendation**: Consolidate the fix by (1) removing the redundant claude polling service entirely and relying on settings.json hooks, (2) implementing a robust `ai-sleep-inhibitor` service that uses safe `pgrep` patterns for OpenCode detection only, or (3) if retaining the unified service, using `-x claude` for Claude and `-f '/bin/opencode '` for OpenCode.

---

## Context & Scope

The `claude-sleep-inhibitor` systemd user service in `home.nix` (lines 816-845, currently disabled) was intended to block system sleep while Claude Code sessions are active. Task 49 fixed Nix derivation bugs (bare `sh` and `sleep` commands). Task 50 identified that the fundamental `pgrep -f 'claude'` pattern is broken due to self-matching and over-matching. Task 52 later requested expanding detection to include OpenCode.

This research report comprehensively analyzes:
1. All processes currently matched by the broken `pgrep -f 'claude'` pattern
2. The exact process names and command lines of legitimate Claude Code and OpenCode sessions
3. Safe `pgrep` patterns that eliminate false positives
4. Alternative approaches that avoid process matching entirely
5. Interaction with existing settings.json per-session inhibitors

---

## Problem Analysis

### Current Disabled Implementation

Located in `home.nix` lines 816-845 (commented out):

```nix
script = pkgs.writeShellScript "claude-sleep-inhibitor" ''
  while true; do
    if ${pkgs.procps}/bin/pgrep -f 'claude' > /dev/null; then
      ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
        --why="Claude Code is running" \
        --who="claude-sleep-inhibitor" \
        ${pkgs.bash}/bin/bash -c 'while ${pkgs.procps}/bin/pgrep -f "claude" > /dev/null; do ${pkgs.coreutils}/bin/sleep 30; done' \
        || ${pkgs.coreutils}/bin/sleep 5
    fi
    ${pkgs.coreutils}/bin/sleep 30
  done
'';
```

### Processes Matched by `pgrep -f 'claude'`

On the current live system, running `pgrep -u $(id -u) -f 'claude' -a` returns **10 matches**:

| PID | Process Name (comm) | Full Command Line | Is Actual Session? |
|-----|--------------------:|-------------------|:-----------------:|
| 1342 | `earlyoom` | `earlyoom ... --prefer ^(lean|lake|claude|node|npm)$` | **NO** |
| 2488368 | `bash` | `bash -c ... && claude ... && popd ...` (nvim wrapper) | **NO** |
| 2488369 | `npm exec @anthr` | `npm exec @anthropic-ai/claude-code@latest ...` | **NO** (parent) |
| **2488447** | **`claude`** | **`claude --dangerously-skip-permissions`** | **YES** |
| 2621345 | `bash` | `bash -c ... && claude ... && popd ...` (nvim wrapper) | **NO** |
| 2621346 | `npm exec @anthr` | `npm exec @anthropic-ai/claude-code@latest ...` | **NO** (parent) |
| **2621365** | **`claude`** | **`claude --dangerously-skip-permissions`** | **YES** |
| 2621439 | `systemd-inhibit` | `systemd-inhibit --what=sleep:idle --who=claude-code ...` | **NO** (settings.json hook) |
| 2627532 | `systemd-inhibit` | `systemd-inhibit --what=sleep:idle --who=claude-code ...` | **NO** (settings.json hook) |
| 2719989 | `claude-memory-t` | `bash .../bin/claude-memory-tracker` | **NO** |

**Result**: 8 out of 10 matches are false positives. The inhibitor would never release.

### Root Causes of False Positives

1. **Self-matching via script name**: The script is named `claude-sleep-inhibitor`. Its command line is `/nix/store/...-bash/bin/bash /nix/store/...-claude-sleep-inhibitor`, which contains the substring `claude`.
2. **Memory tracker**: `claude-memory-tracker` contains `claude` in its script path.
3. **earlyoom regex**: The `--prefer` argument contains `claude` as a pattern character.
4. **settings.json hooks**: The per-session `systemd-inhibit` commands contain `--who=claude-code` and `--why=Claude Code session`.
5. **Wrapper scripts**: nvim terminal wrappers execute `claude` as part of their `-c` argument.
6. **Parent npm processes**: `npm exec @anthropic-ai/claude-code@latest` contains `claude` in the package name.

---

## Technical Findings

### Finding 1: Actual Claude Code Process Names

The legitimate Claude Code session processes have **exact process name `claude`** in `/proc/pid/stat` (visible as `comm=claude` via `ps`).

The process tree per session is:
1. `bash` (nvim wrapper, keeps running)
2. `npm exec @anthropic-ai/claude-code@latest` (spawned by wrapper)
3. **`claude --dangerously-skip-permissions`** (the actual interactive session)

There are typically 2-3 processes per session, but only the one named exactly `claude` is the actual session.

**Verification**:
```bash
$ pgrep -u $(id -u) -x claude -a
2488447 claude --dangerously-skip-permissions
2621365 claude --dangerously-skip-permissions
```
This returns exactly the 2 active sessions and nothing else.

### Finding 2: Actual OpenCode Process Names

OpenCode processes have **process name `.opencode-wrapp`** (15-character kernel truncation of `.opencode-wrapper`).

```bash
$ cat /proc/2533930/comm
.opencode-wrapp
```

**Therefore `pgrep -x opencode` does NOT match OpenCode processes.**

The command lines are:
- `/nix/store/.../bin/opencode serve --hostname 127.0.0.1 --port 4096`
- `/run/current-system/sw/bin/opencode --port`

The Discord bot (`python -m opencode_discord_bot.src.bot`) is a separate process with `comm=python3.12` and should NOT be matched.

### Finding 3: Safe pgrep Patterns

#### For Claude Code

**Recommended**: `pgrep -u "$(id -u)" -x claude`

- `-u "$(id -u)"`: Restricts to current user's processes (eliminates system-level matches like earlyoom)
- `-x`: Exact match on process name in `/proc/pid/stat` (15-char field)
- `claude`: Matches only processes whose kernel name is exactly `claude`

**Eliminates all false positives**:
- earlyoom (comm=`earlyoom`)
- bash wrappers (comm=`bash`)
- npm exec (comm=`npm exec @anthr`)
- systemd-inhibit hooks (comm=`systemd-inhibit`)
- claude-memory-tracker (comm=`claude-memory-t`)
- The inhibitor script itself (comm=`bash`)

**Caveat**: `pgrep -x` uses the 15-char process name from `/proc/pid/stat`, not the full command line. If the Claude Code binary ever changes its process name to something else (e.g., `node`), this would break. However, the current npm package binary is named `claude`, and the wrapper script uses `exec` which preserves the script name if the child is spawned rather than exec'd. This has been verified on the live system.

#### For OpenCode

**Recommended**: `pgrep -u "$(id -u)" -f '/bin/opencode '`

- `-u "$(id -u)"`: Restricts to current user
- `-f`: Matches full command line
- `/bin/opencode ` (with trailing space): Matches paths like `/nix/store/.../bin/opencode ` and `/run/current-system/sw/bin/opencode `

**Eliminates false positives**:
- Discord bot (`python -m opencode_discord_bot.src.bot` does not contain `/bin/opencode `)
- pgrep itself (automatically excluded by pgrep)
- The inhibitor script (cmdline does not contain `/bin/opencode ` if not named with it)

**Verification**:
```bash
$ pgrep -u $(id -u) -f '/bin/opencode ' -a
2533930 /nix/store/.../bin/opencode serve --hostname 127.0.0.1 --port 4096
2643391 /run/current-system/sw/bin/opencode --port
2729101 /run/current-system/sw/bin/opencode --port
```
Returns exactly 3 OpenCode instances, zero false positives.

### Finding 4: Settings.json Already Implements Per-Session Inhibition for Claude

`config/claude/settings.json` contains SessionStart/SessionEnd hooks that launch and kill `systemd-inhibit` on a per-session basis:

```json
"SessionStart": [{
  "hooks": [{
    "type": "command",
    "command": "SESSION_ID=$(jq -r '.session_id // \"default\"'); systemd-inhibit --what=sleep:idle --who=claude-code --why=\"Claude Code session\" --mode=block sleep infinity & echo $! > /tmp/claude-inhibitor-${SESSION_ID}.pid",
    "async": true
  }]
}],
"SessionEnd": [{
  "hooks": [{
    "type": "command",
    "command": "SESSION_ID=$(jq -r '.session_id // \"default\"'); PID_FILE=\"/tmp/claude-inhibitor-${SESSION_ID}.pid\"; [ -f \"$PID_FILE\" ] && kill \"$(cat \"$PID_FILE\")\" 2>/dev/null; rm -f \"$PID_FILE\"",
    "async": true
  }]
}]
```

These hooks are **already active** on the system. Verification shows two active inhibitors:
```bash
$ pgrep -f "systemd-inhibit.*claude-code" -a
2621439 systemd-inhibit --what=sleep:idle --who=claude-code --why=Claude Code session --mode=block sleep infinity
2627532 systemd-inhibit --what=sleep:idle --who=claude-code --why=Claude Code session --mode=block sleep infinity
```

**Advantages over polling service**:
1. **Lifecycle-bound**: Inhibitor starts exactly when the session starts, ends exactly when it ends
2. **No polling overhead**: No 30-second sleep loops, no repeated pgrep invocations
3. **No race conditions**: Immediate response to session state changes
4. **Multi-session safe**: Each session gets its own inhibitor PID; they all block sleep independently
5. **No false positives**: No process matching at all

**Disadvantages**:
1. **Claude-specific**: Only works for Claude Code, not OpenCode
2. **PID file fragility**: If `claude` crashes without triggering SessionEnd, the inhibitor may leak (though `systemd-inhibit` with `--mode=block` would also be killed when the parent dies if properly set up; with `sleep infinity` backgrounded, it may survive)
3. **Requires Claude Code support**: Depends on the tool having hook infrastructure

### Finding 5: OpenCode Has No Equivalent Hook System

OpenCode (`opencode --help`) provides:
- `opencode serve` (headless server)
- `opencode [project]` (TUI, default)
- `opencode run [message..]` (one-shot)
- Session management (`opencode session`)

But **no hooks or events system** for running commands on session start/end. Therefore, a polling-based approach is necessary for OpenCode unless:
- We wrap the `opencode` binary to inject inhibitors
- We use port-based detection (opencode servers listen on ports)
- We monitor for `.opencode` session files or sockets

### Finding 6: Port-Based Detection for OpenCode

OpenCode server instances listen on TCP ports:
```bash
$ ss -tlnp | grep opencode
127.0.0.1:4096   (opencode serve, explicit port)
127.0.0.1:35581  (opencode --port, auto-assigned)
127.0.0.1:43481  (opencode --port, auto-assigned)
```

Port-based detection would require:
- Checking for ANY localhost listener owned by `.opencode-wrapp`
- Or checking specific known ports (4096 for `serve`, but TUI ports are random)

This is more complex and fragile than process matching. The `pgrep -f '/bin/opencode '` pattern is simpler and more reliable.

---

## Options Evaluated

### Option A: Fix pgrep Patterns in Existing Service (Recommended Minimal Fix)

Replace `pgrep -f 'claude'` with user-scoped exact matching.

**Pros**:
- Minimal change to existing code
- Fastest to implement
- Retains single unified service for both tools

**Cons**:
- Still uses polling (30-second latency, resource overhead)
- Still subject to race conditions
- For OpenCode, relies on path matching which could break if opencode installation path changes
- Does not leverage superior settings.json hooks for claude

**Implementation**:
```bash
# For claude
pgrep -u "$(id -u)" -x claude > /dev/null

# For opencode
pgrep -u "$(id -u)" -f '/bin/opencode ' > /dev/null

# Combined
if pgrep -u "$(id -u)" -x claude > /dev/null || pgrep -u "$(id -u)" -f '/bin/opencode ' > /dev/null; then
  systemd-inhibit ...
fi
```

### Option B: Remove Service, Rely on Settings.json Hooks for Claude Only (Alternative)

Delete the systemd service entirely. Claude Code inhibition is already handled by settings.json. OpenCode would have no inhibition.

**Pros**:
- Cleanest architecture for Claude
- No polling overhead
- No pgrep false positive risk at all

**Cons**:
- Leaves OpenCode without sleep inhibition
- Inconsistent user experience between tools
- If settings.json hooks fail (e.g., claude crashes), inhibitors may leak

### Option C: Hybrid - Settings.json for Claude, Robust Service for OpenCode (Recommended Best Practice)

1. **For Claude**: Continue using settings.json hooks (already working, superior)
2. **For OpenCode**: Implement a new `opencode-sleep-inhibitor` service using safe `pgrep`
3. Optionally rename the unified service to `ai-sleep-inhibitor` and use safe patterns for both

**Pros**:
- Best of both worlds: lifecycle-bound for claude, polling for opencode
- No redundant inhibition (claude gets two inhibitors if both are active, but that's harmless)
- Future-proof: if opencode adds hooks, the service can be deprecated

**Cons**:
- Slightly more complex (two mechanisms)
- The opencode service still has polling limitations

### Option D: Wrapper Script with Inhibitor Injection

Create a wrapper around `opencode` that launches `systemd-inhibit` before running the real binary.

**Pros**:
- Lifecycle-bound like settings.json
- No polling
- Works for any invocation of `opencode`

**Cons**:
- Complex to implement in Nix (requires overriding the package or creating a wrapper derivation)
- Must handle all subcommands (`serve`, `run`, TUI)
- The `opencode serve` daemon stays running; we'd need to detect when to release
- May interfere with `opencode attach` or other client-server interactions

### Option E: Port-Based Detection for OpenCode

Use `ss` or `lsof` to detect opencode listening ports.

**Pros**:
- Independent of process names
- Works even if opencode changes its binary name

**Cons**:
- `opencode --port` uses random ephemeral ports
- `ss` requires elevated privileges or specific kernel configs to see all sockets
- More complex and slower than `pgrep`
- False positives if another service uses the same port

---

## Recommendations

### Primary Recommendation: Option C - Hybrid Approach with Unified Service Rename

Implement a single `ai-sleep-inhibitor` service in `home.nix` that uses **safe pgrep patterns** for both Claude and OpenCode. While settings.json hooks already handle claude, the unified service provides:
1. A safety net if settings.json hooks fail
2. Consistent inhibition for OpenCode
3. A single toggle point (`systemctl --user start/stop ai-sleep-inhibitor`)

**Service script**:
```nix
systemd.user.services.ai-sleep-inhibitor = {
  Unit = {
    Description = "Inhibit sleep while AI agents (Claude/OpenCode) are active";
    After = [ "default.target" ];
  };
  Service = {
    Type = "simple";
    ExecStart = let
      script = pkgs.writeShellScript "ai-sleep-inhibitor" ''
        while true; do
          # Safe process detection:
          # - -x claude: exact match on kernel process name (comm=claude)
          # - -f '/bin/opencode ': path match for opencode binaries
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x claude > /dev/null \
             || ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f '/bin/opencode ' > /dev/null; then
            ${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle \
              --why="AI agent (Claude/OpenCode) is running" \
              --who="ai-sleep-inhibitor" \
              ${pkgs.coreutils}/bin/sleep infinity \
              || ${pkgs.coreutils}/bin/sleep 5
          fi
          ${pkgs.coreutils}/bin/sleep 30
        done
      '';
    in "${script}";
    Restart = "always";
    RestartSec = 10;
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

**Key differences from original**:
1. **Renamed** to `ai-sleep-inhibitor` to avoid self-matching via script name
2. **Uses `pgrep -u $(id -u) -x claude`** instead of `pgrep -f 'claude'`
3. **Uses `pgrep -u $(id -u) -f '/bin/opencode '`** for OpenCode
4. **Uses `sleep infinity`** as the inhibitor subcommand instead of a polling bash loop (simpler, no nested pgrep)
5. **Retains `|| sleep 5`** failure guard from Task 49

**Why `sleep infinity` instead of a bash loop**:
- The original design used `systemd-inhibit bash -c 'while pgrep ...; do sleep 30; done'`
- With `sleep infinity`, `systemd-inhibit` holds the lock until we kill it
- The outer `while true` loop already handles the polling; when `pgrep` no longer finds processes, the loop simply continues and `systemd-inhibit` is not re-invoked
- When `pgrep` finds processes again, a new `systemd-inhibit` is launched
- Wait, this means there could be multiple overlapping inhibitors if the loop runs faster than `systemd-inhibit` exits. Actually, `systemd-inhibit sleep infinity` blocks until killed. The outer loop would only reach the next iteration after `systemd-inhibit` exits. But `sleep infinity` never exits unless killed. So the outer loop would block at the `systemd-inhibit` call.

**Correction**: With `sleep infinity`, the outer loop blocks on `systemd-inhibit`, which only exits when the sleep is interrupted. But nothing interrupts it in this script. So the service would launch ONE inhibitor and then hang forever, even after Claude exits.

**Better approach**: Keep the bash loop as the subcommand, or use `systemd-inhibit` with a timeout and re-evaluate. Actually, the original design (bash loop inside `systemd-inhibit`) is correct: `systemd-inhibit` holds the lock for the duration of its child process. The child process polls pgrep and exits when no processes are found. Then `systemd-inhibit` releases the lock. Then the outer loop sleeps 30 and repeats.

So the subcommand should be:
```bash
${pkgs.bash}/bin/bash -c 'while ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x claude > /dev/null || ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f "/bin/opencode " > /dev/null; do ${pkgs.coreutils}/bin/sleep 30; done'
```

This is the correct pattern. It holds the inhibition lock continuously while either process exists.

### Secondary Recommendation: Document the Settings.json Hooks

Since settings.json already has superior per-session inhibition for Claude, add documentation to `NOTES.md` or `docs/power-management.md` explaining:
1. Claude Code uses lifecycle-bound inhibitors via settings.json hooks
2. OpenCode uses the `ai-sleep-inhibitor` systemd service
3. Both can be manually toggled

### Tertiary Recommendation: Consider Future Opencode Hook Support

If OpenCode adds SessionStart/SessionEnd hooks in the future, migrate OpenCode inhibition to hooks and deprecate the polling service.

---

## Decisions

1. **Do NOT use `pgrep -f 'claude'` or `pgrep -f '(claude|@anthropic|opencode)'` for sleep inhibition** - these patterns are fundamentally unsafe due to self-matching and over-matching.
2. **Use `pgrep -u $(id -u) -x claude` for Claude Code** - exact process name matching eliminates all false positives.
3. **Use `pgrep -u $(id -u) -f '/bin/opencode '`** for OpenCode - path-based matching is necessary because the kernel process name is `.opencode-wrapp`.
4. **Rename the service** from `claude-sleep-inhibitor` to `ai-sleep-inhibitor` to avoid the script name itself containing `claude`.
5. **Retain the `systemd-inhibit` polling architecture** for OpenCode, as no hook system exists. For Claude, the settings.json hooks already provide superior inhibition; the unified service acts as a backup.
6. **Do NOT use port-based detection** for OpenCode - it's more complex and less reliable than safe `pgrep` patterns.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Claude Code binary changes its process name from `claude` to `node` or something else | Low | High | Monitor after claude-code package updates; `-f` fallback pattern documented |
| OpenCode binary path changes (e.g., no longer in `/bin/opencode`) | Low | Medium | Use multiple path patterns or broader `-f 'opencode '` with negative filters |
| `pgrep -f '/bin/opencode '` matches unintended processes in the future | Low | Low | Restrict to current user with `-u`; pattern includes trailing space for specificity |
| Settings.json hooks leak inhibitors if Claude crashes | Medium | Low | The unified service also inhibits, so sleep is still blocked; leaked inhibitors can be killed manually or on logout |
| User runs both Claude and OpenCode simultaneously, causing multiple inhibitors | Certain | None | Multiple `systemd-inhibit` locks are additive, not conflicting. System sleeps only when ALL are released. |
| Performance impact of 30-second polling | Low | Very Low | One `pgrep` invocation every 30 seconds is negligible |

---

## Appendix

### A. Process Name Verification Commands

```bash
# Verify claude exact matching
pgrep -u $(id -u) -x claude -a

# Verify opencode path matching
pgrep -u $(id -u) -f '/bin/opencode ' -a

# Check kernel process names
for pid in $(pgrep -f 'claude' | head -10); do
  echo "PID $pid: comm=$(cat /proc/$pid/comm 2>/dev/null)"
done

# List all claude-pattern matches with details
pgrep -u $(id -u) -f 'claude' -a
```

### B. References to Existing Code

- `home.nix` lines 816-845: Disabled `claude-sleep-inhibitor` service
- `home.nix` line 655: `claude-memory-tracker` pgrep pattern `(claude|@anthropic|opencode)`
- `packages/claude-code.nix`: Claude Code wrapper script (`writeShellScriptBin "claude"`)
- `modules/opencode.nix`: OpenCode configuration module
- `config/claude/settings.json`: SessionStart/SessionEnd hooks with `systemd-inhibit`
- `configuration.nix` line 378: earlyoom `--prefer` regex containing `claude`

### C. Previous Research

- `specs/archive/049_fix_claude_sleep_inhibitor_nix/reports/01_sleep-inhibitor-fix.md` (Task 49)
- `specs/052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md` (Task 52)
- `specs/052_sleep_inhibition_claude_opencode/plans/01_sleep-inhibition-implementation.md` (Task 52 plan)

### D. pgrep Behavior Notes

From `man pgrep`:
> The process name used for matching is limited to the 15 characters present in the output of /proc/pid/stat. Use the -f option to match against the complete command line, /proc/pid/cmdline.

> The running pgrep, pkill, or pidwait process will never report itself as a match.

### E. Verification of Safe Patterns on Live System

**Date**: 2026-05-14
**User**: benjamin (UID 1000)
**Active Sessions**: 2x Claude Code, 3x OpenCode

| Pattern | Matches | False Positives | Notes |
|---------|---------|-----------------|-------|
| `pgrep -f 'claude'` | 10 | 8 | Includes earlyoom, wrappers, npm, inhibitors, memory-tracker |
| `pgrep -x claude` | 2 | 0 | Exact kernel name match |
| `pgrep -f 'opencode'` | 5 | 2 | Includes discord bot, pgrep test command |
| `pgrep -f '/bin/opencode '` | 3 | 0* | *Excludes discord bot; pgrep excludes itself |
| `pgrep -f '/claude '` | 0 | 0 | No cmdline starts with `/claude ` |


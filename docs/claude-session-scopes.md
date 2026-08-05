# Claude Session Scopes and the Orphan Reaper

Every `claude` invocation on this machine runs inside its own systemd user **scope**, and a
timer stops scopes whose owning session has exited. The purpose is narrow: a process spawned by
a Claude Code session must never outlive the session that spawned it.

Without this, a detached child survives its session indefinitely. That is not hypothetical — it
is why this mechanism exists. A `python3` process double-forked out of a dead session ran for
just over two days, accumulated more than 50 hours of CPU time, and held the package at 99 °C
with the fan pinned; a separate incident leaked several gigabytes of orphaned language-server
workers. Before containment, every session and every child shared the terminal emulator's single
cgroup, so there was no per-session boundary to clean up even if you wanted to.

**If you are here because something you wanted to keep got killed, or you are about to launch
work that must outlive its session, skip to [Keeping work alive](#keeping-work-alive).** The
short answer is that the reaper never kills a child while its session is alive, and
`systemd-run --user --unit=my-job -- <cmd>` is the supported way to detach work on purpose.

## How containment works

The `claude` wrapper (`packages/claude-code.nix`) launches the CLI inside a transient scope:

```
systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet -- <claude>
```

The resulting unit is named `claude-<pid>-<epoch>.scope` and lives under
`user.slice/user@1000.service/app.slice/`. Everything the session spawns — including a child
that double-forks via `setsid nohup` specifically to escape its parent — lands in that scope's
cgroup, because cgroup membership is inherited and cannot be shed by forking. That is the whole
mechanism: `setsid` breaks the process-group and session relationship, but it does not move a
process out of its cgroup.

The wrapper degrades safely. If `systemd-run` is missing or `XDG_RUNTIME_DIR` is unset (no user
systemd session — a plain SSH login, a rescue shell), it falls through to launching the CLI
directly, unscoped, rather than failing.

## The liveness-only guarantee

The reaper (`modules/home/services/claude-session-reaper.nix`, run every 10 minutes by
`claude-session-reaper.timer`) decides using exactly one question:

> Is there still a live Claude process inside this scope?

For each unit matching `claude-*.scope`, it reads that unit's own `cgroup.procs`, tests only
those PIDs' `/proc/<pid>/cmdline` against `claude`, `@anthropic`, and `opencode`, and stops the
unit only when **zero** of them match. Anything ambiguous — an unparsable PID list, a PID that
vanishes mid-read — causes the unit to be skipped, never stopped.

**There are no CPU-time, memory, or wall-clock thresholds anywhere in the predicate, and none
will be added.** A child burning a full core for six hours is untouched as long as its session
lives. Age and resource use are not evidence of abandonment; only the absence of the owning
session is. The reaper also never enumerates or kills arbitrary user processes — a unit whose
name does not match `claude-*.scope` is invisible to it.

## Keeping work alive

Two supported ways, depending on what you want.

**Detach work on purpose, so it outlives the session.** Launch it as its own top-level transient
unit with a name that does not match `claude-*.scope`:

```bash
systemd-run --user --unit=my-long-job -- <command>

systemctl --user status my-long-job     # check on it
journalctl --user -u my-long-job -f     # follow its output
systemctl --user stop my-long-job       # stop it when you're done
```

The reaper never looks at it. It survives session exit, terminal close, and logout by design.
This is the right tool for a long build, a training run, or anything you intend to come back to.

**Turn containment off for the current shell** (no rebuild, takes effect immediately):

```bash
export CLAUDE_NO_SCOPE=1
```

Sessions launched from that shell run unscoped, exactly as they did before this mechanism
existed. Use this if the wrapper itself is misbehaving; use `systemd-run` above if you simply
want a job to outlive its session.

## Inspection recipes

```bash
# Which sessions are currently contained?
systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'

# What is actually inside one of them?
CG=$(systemctl --user show claude-<pid>-<epoch>.scope -p ControlGroup --value)
cat "/sys/fs/cgroup${CG}/cgroup.procs"

# ...with names, and proof they are not in the terminal's scope:
for p in $(cat "/sys/fs/cgroup${CG}/cgroup.procs"); do
  printf '%s\t%s\t%s\n' "$p" "$(cat /proc/$p/comm)" "$(cat /proc/$p/cgroup)"
done

# What would the reaper do right now? (decides and logs, kills nothing)
CLAUDE_REAPER_DRY_RUN=1 $(systemctl --user show claude-session-reaper.service \
  -p ExecStart --value | sed -n 's/.*path=\([^ ;]*\).*/\1/p')

# What has it done?
journalctl --user -u claude-session-reaper.service -n 40 --no-pager
systemctl --user list-timers 'claude-session-reaper*'

# Run it on demand
systemctl --user start claude-session-reaper.service
```

A dry run prints `DRY-RUN would stop <unit>` for scopes it judges abandoned and
`<unit> alive, skipping` for scopes with a live session. It is always safe to run.

## Notes and interactions

**Nested sessions.** Running `claude` from inside a Claude session creates a *sibling* scope, not
a nested one: the inner invocation migrates into its own `claude-<pid>-<epoch>.scope`. This is
expected and benign. Each session is judged independently, so the inner one being reaped after it
exits has no effect on the outer one.

**Independent of the sleep inhibitors.** The containment scopes and the `SessionStart` /
`SessionEnd` sleep inhibitors described in [no-sleep-agents.md](no-sleep-agents.md) are separate
mechanisms that do not coordinate. They use different identifiers, and neither reads the other's
state. Disabling one has no effect on the other.

**Manual cleanup.** If you stop a scope by hand, confirm first that no live session owns it —
`cat "/sys/fs/cgroup${CG}/cgroup.procs"` and look for a `claude` process. `systemctl --user stop`
on a scope SIGKILLs everything inside it.

## Rollback

Cheapest first. The first option needs no rebuild and is the one to reach for the moment the
interactive experience misbehaves.

1. **Per-shell, immediate**: `export CLAUDE_NO_SCOPE=1`. The wrapper falls through to a bare
   launch; previous behavior is restored in that shell.
2. **Disable the reaper, keep containment** (cgroup boundary stays, nothing is killed
   automatically):
   ```bash
   systemctl --user stop claude-session-reaper.timer
   systemctl --user disable claude-session-reaper.timer
   ```
   This lasts until the next `home-manager switch`. To make it permanent, comment out the
   `./services/claude-session-reaper.nix` import in `modules/home/default.nix` and rebuild.
3. **Previous generation**: `sudo nixos-rebuild switch --rollback`, and/or activate an earlier
   home-manager generation (`home-manager generations`, then run that generation's `activate`
   script).
4. **Source revert**: revert the changes to `packages/claude-code.nix`,
   `modules/home/services/claude-session-reaper.nix`, and `modules/home/default.nix`, then
   re-run `sudo nixos-rebuild switch --flake .#hamsa` and
   `home-manager switch --flake .#benjamin`.
5. **Leftover units after a rollback**:
   ```bash
   systemctl --user list-units --type=scope --all --no-legend --plain 'claude-*.scope'
   systemctl --user stop <unit>          # only after confirming no live session owns it
   systemctl --user reset-failed <unit>
   ```

The wrapper and the reaper are independent and can be reverted separately. Containment without
the reaper is a safe intermediate state: you get the per-session cgroup boundary and manual
`systemctl --user stop` cleanup, with no automatic killing at all.

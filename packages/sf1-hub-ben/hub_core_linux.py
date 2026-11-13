#!/usr/bin/env python3
"""hub_core_linux: runs the SHARED hub runner core (vendor/hub-runner/runner.py, the same bytes Oliver runs) on Ben's
Linux / NixOS machine. Platform layer only; the vendored files are never edited (sha256 checked against
vendor.lock.json on every start, refused on mismatch).

What this file adds at runtime, without touching the core's bytes:
  - child_env: the core hard-codes a macOS PATH for card workers; here the PATH is the unit's PATH
    (SF1_HUB_CHILD_PATH), and every *_TOKEN / *_KEY variable is dropped from the worker env.
  - post and prompt wording: the core's status lines say "for oliver"; here they name the runner's owner.
  - `capabilities`: a probe Ben's preflight reads. executor_guard_hook is true only when the core's own executor
    profile carries the guard hook (`guard.py hook --attached || exit 2`) and the deny hook, and start_card checks
    the guard is bound in the card worktree before it starts (fail closed).
  - go-live gate read from the SERVER, never a local marker (Oliver 2026-11-12, KO sf1:ben-runner-golive-memory-1112):
    the core's live_verified() is replaced by a check of the room itself. Verified live = the room holds the room
    thread's labeled test post (by "SF-1", via "sf1", agent label, body == GOLIVE_TEXT) AND a later SF-1 digest
    message ("[SF-1] Tonight's digest for Ben ("). golive reads the room once; not verified -> refuses, no further call.
    In the loop the state is re-read from every room poll; no post and no card before a poll confirms it.
  - memory sync ON, as Oliver's RB10 (one hub-rulings.md + one MEMORY.md pointer line, MEMORY.md backed up first),
    into Ben's Claude Code project memory dir: $CLAUDE_CONFIG_DIR or ~/.claude, projects/<checkout path with every
    non-alphanumeric as '-'>/memory. If any piece of that path is in the Nix store (home-manager) or not writable,
    memory sync stays OFF with the reason in the config and in `status`; nothing under ~/.claude is replaced.
  - `prepare`: writes the core's config.json for Ben (me, repo, keys from Ben's env file), the executor profile,
    the code copies the profile points at, and the manifest component golive needs.
Commands: capabilities | prepare | memplan | unsync | loop | run-once | stop | unstop | status | golive
State: $SF1_HUB_HOME (set by sf1-hub-ben to $XDG_STATE_HOME/sf1-hub-ben/hub). launchd is never called
(SF1_HUB_NO_LAUNCHCTL=1); systemd is the supervisor.
"""
import hashlib
import inspect
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
VENDOR = os.environ.get('SF1_HUB_VENDOR') or os.path.join(HERE, 'vendor')
CORE_DIR = os.path.join(VENDOR, 'hub-runner')
LOCK = os.path.join(HERE, 'vendor.lock.json')
os.environ['SF1_HUB_NO_LAUNCHCTL'] = '1'
PERSON = os.environ.get('SF1_HUB_PERSON', 'benjamin')
EX_REFUSE = 78


def sha256(path):
    with open(path, 'rb') as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def lock_check():
    """-> list of vendored files whose sha256 differs from the lock (empty = byte-identical)."""
    lock = json.load(open(LOCK))
    return [p for p, s in lock['files'].items()
            if not os.path.isfile(os.path.join(VENDOR, p)) or sha256(os.path.join(VENDOR, p)) != s]


bad = lock_check()
if bad:
    print(json.dumps({'executor_guard_hook': False, 'refused': 'vendored files differ from vendor.lock.json: %s' % bad}))
    sys.exit(EX_REFUSE)

sys.dont_write_bytecode = True                 # the vendor dir may be the read-only Nix store
sys.path.insert(0, CORE_DIR)
import runner  # noqa: E402  (the shared core, unmodified)

DROP_SUFFIX = ('_TOKEN', '_KEY', '_SECRET')


def child_env_linux(extra=None):
    env = {k: v for k, v in os.environ.items()
           if k not in runner.KEY_ENV_DROP and not k.startswith('SF1_HUB_NEG') and not k.endswith(DROP_SUFFIX)}
    env['PATH'] = os.environ.get('SF1_HUB_CHILD_PATH') or os.environ.get('PATH', '/run/current-system/sw/bin')
    env.update(extra or {})
    return env


runner.child_env = child_env_linux

Who = PERSON.capitalize()
SAY_MAP = [(' for oliver', ' for %s' % PERSON), ("waiting for Oliver's TAKE", "waiting for %s's TAKE" % Who),
           ('taken by Oliver', 'taken by %s' % Who), ("on Oliver's machine", "on %s's machine" % Who),
           ("Oliver's uncommitted diff", "%s's uncommitted diff" % Who), ('CARD for:oliver', 'CARD for:%s' % PERSON)]
_say = runner.Runner.say
_prompt = runner.Runner.card_prompt


def say_person(self, text, source):
    if PERSON != 'oliver':
        for a, b in SAY_MAP:
            text = text.replace(a, b)
    return _say(self, text, source)


def prompt_person(self, cid, c, plan):
    t = _prompt(self, cid, c, plan)
    return t.replace('for Oliver, in a fresh', 'for %s, in a fresh' % Who, 1) if PERSON != 'oliver' else t


runner.Runner.say = say_person
runner.Runner.card_prompt = prompt_person
runner.PLAN_SYS = runner.PLAN_SYS.replace("Oliver's sapience-app checkout", "%s's checkout" % Who)


# ---------------------------------------------------------------- go-live from the server (no local marker)
GOLIVE_TEXT = "[SF-1] test: room thread connected (agent post)"     # room_thread.py GOLIVE_TEXT (contract)
DIGEST_PREFIX = "[SF-1] Tonight's digest for Ben ("                  # room_thread.DIGEST_MSG_PREFIX (contract, fb0de243c)
ROOM_LIVE = {'ok': False, 'why': 'room not read yet in this process'}


def _sf1(m):
    return m.get('by') == 'SF-1' and m.get('via') == 'sf1' and 'agent' in str(m.get('label') or '').lower() \
        and not m.get('me')


def room_live_state(msgs):
    """-> (ok, why) from the room's messages alone."""
    t = [m for m in msgs if _sf1(m) and str(m.get('body') or '') == GOLIVE_TEXT]
    if not t:
        return False, 'no labeled SF-1 test post from the room thread in the room'
    tn = min(int(m.get('n', 0)) for m in t)
    d = [m for m in msgs if _sf1(m) and int(m.get('n', 0)) > tn
         and str(m.get('body') or '').startswith(DIGEST_PREFIX)]
    if not d:
        return False, 'test post #%d seen, but no SF-1 digest message after it' % tn
    return True, 'room verified live: test post #%d, digest #%d' % (tn, min(int(m['n']) for m in d))


def live_verified_room(cfg, base=None):
    if runner.neg('livegate'):
        return True, 'gate OFF (negative control)'
    return ROOM_LIVE['ok'], ROOM_LIVE['why']


_get_messages = runner.HubRoom.get_messages


def get_messages_tracking(self, since=0):
    msgs = _get_messages(self, since)
    if since == 0:
        ok, why = room_live_state(msgs)
        if ok != ROOM_LIVE['ok']:
            self.R.log(event='room-live-state', ok=ok, why=why)
        ROOM_LIVE.update(ok=ok, why=why)
    return msgs


_golive = runner.golive


def golive_room(home=None, base='https://app.spnc.ai', brain_spec=None):
    """ONE room GET with Ben's brain token. Not verified -> refuse; no rules GET, no key mint, nothing else."""
    R = runner.Runner(home)
    if R.state.killed():
        return {'ok': False, 'why': 'stopped: %s' % R.state.killed(), 'requests': 0}
    cfg = dict(R.cfg, base_url=base)
    net = runner.Net(cfg, R.state)
    try:
        st, _, d = net.req('GET', '/v1/rooms/%s' % cfg['room_id'], 'brain')
    except runner.TransportStop as e:
        return {'ok': False, 'why': 'room read stopped: %s' % e, 'requests': net.requests}
    if st != 200:
        return {'ok': False, 'why': 'room GET returned %s' % st, 'requests': net.requests}
    ok, why = room_live_state(d.get('messages') or [])
    ROOM_LIVE.update(ok=ok, why=why)
    if not ok:
        R.log(event='golive-refused', why=why)
        return {'ok': False, 'why': 'room thread has not verified go-live (%s); staying pre-live' % why,
                'requests': net.requests}
    r = _golive(home, base, brain_spec)
    r['requests'] = r.get('requests', 0) + net.requests
    r['room_live'] = why
    return r


runner.live_verified = live_verified_room
runner.HubRoom.get_messages = get_messages_tracking
runner.golive = golive_room


# ---------------------------------------------------------------- Claude Code memory path on Linux / NixOS
def in_store(path):
    try:
        return os.path.realpath(path).startswith('/nix/store/')
    except OSError:
        return False


def memplan(repo_top):
    """-> {'dir', 'ok', 'why', 'existed': [...]} for Ben's Claude Code project memory of this checkout."""
    base = os.environ.get('CLAUDE_CONFIG_DIR') or os.path.join(os.path.expanduser('~'), '.claude')
    proj = os.path.join(base, 'projects', mangle(repo_top))
    mem = os.path.join(proj, 'memory')
    chain = [base, os.path.join(base, 'projects'), proj, mem]
    files = [os.path.join(mem, 'MEMORY.md'), os.path.join(mem, 'hub-rulings.md')]
    out = {'dir': mem, 'ok': True, 'why': 'writable', 'existed': [p for p in chain if os.path.isdir(p)]}
    for p in chain + files:
        if os.path.lexists(p) and (in_store(p) or (os.path.islink(p) and p in files)):
            out.update(ok=False, why='%s is managed by Nix/home-manager (read-only link); memory sync OFF, the guard '
                                     'and the room still carry the rulings' % p)
            return out
    anc = next((p for p in reversed(chain) if os.path.isdir(p)), None)
    if anc is None or not os.access(anc, os.W_OK):
        out.update(ok=False, why='%s is not writable; memory sync OFF' % (anc or base))
    for p in files:
        if os.path.exists(p) and not os.access(p, os.W_OK):
            out.update(ok=False, why='%s is not writable; memory sync OFF' % p)
    return out


def unsync(repo_top=None):
    """Uninstall: the core's unsync_memory (restores MEMORY.md byte for byte), then remove the project dirs this
    runner created, only if empty."""
    p = runner.P()
    cfg = runner.load_cfg(p)
    done = runner.unsync_memory(runner.Path(cfg['memory_dir']), p) if p.mem_backup.exists() else []
    try:
        plan = json.loads((p.r / 'memplan.json').read_text())
    except Exception:
        plan = {}
    base_dirs = plan.get('existed', [])
    for d in (os.path.dirname(cfg['memory_dir']),):
        if d not in base_dirs and os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)
            done.append('removed ' + d)
    return {'ok': True, 'done': done}


# ---------------------------------------------------------------- capabilities (gate GX / RB4)
def capabilities():
    p = runner.P()
    cfg = runner.load_cfg(p)
    if not p.cfg.exists():                     # before the first prepare: judge the values prepare will write
        cfg.update(guard=os.path.join(VENDOR, 'guard', 'guard.py'), python=os.path.realpath(sys.executable))
    checks = {}
    prof = runner.executor_profile(cfg, p)
    pre = [h['command'] for e in prof.get('hooks', {}).get('PreToolUse', []) for h in e.get('hooks', [])]
    mt = ' '.join(e.get('matcher', '') for e in prof.get('hooks', {}).get('PreToolUse', []))
    post = [h['command'] for e in prof.get('hooks', {}).get('PostToolUse', []) for h in e.get('hooks', [])]
    checks['profile_guard_hook'] = any(cfg['guard'] in c and 'hook --attached' in c and c.rstrip().endswith('|| exit 2')
                                       for c in pre)
    checks['profile_guard_matcher'] = all(t in mt for t in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'Bash'))
    checks['profile_guard_posthook'] = any(cfg['guard'] in c and 'posthook --attached' in c for c in post)
    checks['profile_deny_hook_first'] = bool(pre) and 'deny_hook.py' in pre[0]
    src = inspect.getsource(runner.Runner.start_card)
    checks['start_checks_guard_bound'] = 'self.guard_bound(wt)' in src and 'fail closed' in src
    checks['executor_loads_profile'] = '"--settings", str(self.p.profile)' in src and 'dangerously' not in src
    checks['guard_file_present'] = os.path.isfile(cfg['guard'])
    checks['worker_path_not_macos'] = '/opt/homebrew' not in child_env_linux()['PATH']
    ok = all(checks.values())
    return {'executor_guard_hook': ok, 'core_version': runner.VERSION, 'core_sha256': sha256(runner.__file__),
            'platform': 'linux-systemd (hub_core_linux)', 'person': PERSON, 'checks': checks,
            'card_repo': cfg.get('repo_name'), 'mode': cfg.get('mode')}


# ---------------------------------------------------------------- prepare (Ben's install of the core's runtime files)
def mangle(path):
    return ''.join(ch if ch.isalnum() or ch == '-' else '-' for ch in path)


def prepare(repo_top, repo_name, env_file, claude_bin):
    p = runner.P()
    for d in (p.hub, p.r, p.bin):
        os.makedirs(d, exist_ok=True)
    for fn in ('runner.py', 'deny_hook.py', 'room_member.py'):
        shutil.copy2(os.path.join(CORE_DIR, fn), p.bin / fn)
    try:
        cur = json.loads(p.cfg.read_text())
    except Exception:
        cur = {'mode': 'prelive', 'installed_at': time.time()}
    plan = memplan(repo_top)
    if not (p.r / 'memplan.json').exists():               # first plan only: which ~/.claude dirs existed before us
        runner.atomic_write(p.r / 'memplan.json', json.dumps(plan, indent=1))
    guard = os.path.join(VENDOR, 'guard', 'guard.py')
    cur.update({
        'me': PERSON, 'members': ['oliver', PERSON], 'repo': repo_top, 'repo_name': repo_name,
        'brain_token_file': '%s@SAPIENCE_TOKEN' % env_file,
        'anthropic_key_file': '%s@ANTHROPIC_API_KEY' % env_file,
        'openrouter_key_file': '%s@OPENROUTER_API_KEY' % env_file,
        'hub_key_file': str(p.r / 'hub.key'), 'work_dir': str(p.r / 'work'),
        'claude_bin': claude_bin or 'claude', 'python': os.path.realpath(sys.executable), 'guard': guard,
        'memory_sync': plan['ok'], 'memory_off_reason': None if plan['ok'] else plan['why'],
        'memory_dir': plan['dir'],
        'share_unpushed_branches': False, 'platform': 'linux-systemd sf1-hub-ben'})
    cur.setdefault('mode', 'prelive')
    runner.atomic_write(p.cfg, json.dumps(cur, indent=1))
    cfg = runner.load_cfg(p)
    runner.atomic_write(p.profile, json.dumps(runner.executor_profile(cfg, p), indent=1))
    m = runner.read_manifest(p)
    comp = m.setdefault('components', {}).get('runner') or {'installed_at': time.time(), 'mode': 'prelive',
                                                              'runtime_created': []}
    comp.update(version=runner.VERSION, platform='linux-systemd', supervisor='systemd --user sf1-hub-ben.service',
                files=[str(p.bin / f) for f in ('runner.py', 'deny_hook.py', 'room_member.py')] + [str(p.cfg),
                                                                                                    str(p.profile)],
                core_sha256=sha256(runner.__file__), never_touched=['~/.claude', '/usr', 'the checkout main tree'])
    m.setdefault('schema', 'sf1-hub-manifest/1')
    m['components']['runner'] = comp
    runner.atomic_write(p.manifest, json.dumps(m, indent=1))
    return {'ok': True, 'hub': str(p.hub), 'repo': repo_name, 'mode': cfg['mode'], 'files': comp['files'],
            'memory_sync': cfg['memory_sync'], 'memory_dir': cfg['memory_dir'], 'memory_off_reason': cfg.get('memory_off_reason')}


def main(a):
    cmd = a[0] if a else ''
    if cmd == 'capabilities':
        print(json.dumps(capabilities(), indent=1))
        return 0
    if cmd == 'prepare':
        kw = dict(zip(a[1::2], a[2::2]))
        print(json.dumps(prepare(kw['--repo'], kw['--repo-name'], kw['--env-file'], kw.get('--claude')), indent=1))
        return 0
    if cmd == 'memplan':
        print(json.dumps(memplan(a[a.index('--repo') + 1]), indent=1))
        return 0
    if cmd == 'unsync':
        print(json.dumps(unsync(), indent=1))
        return 0
    if cmd == 'status':
        st = runner.status()
        cfg = runner.load_cfg(runner.P())
        st.update(room_live=None, memory_sync=cfg.get('memory_sync'), memory_dir=cfg.get('memory_dir'),
                  memory_off_reason=cfg.get('memory_off_reason'))
        st.pop('launchd', None)
        print(json.dumps(st, indent=1, default=str))
        return 0
    if cmd in ('loop', 'run-once', 'stop', 'unstop', 'golive'):
        return runner.main(a)
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]) or 0)

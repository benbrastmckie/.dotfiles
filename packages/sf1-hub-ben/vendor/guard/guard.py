#!/usr/bin/env python3
"""oliver-ben binding guard (2026-11-11, for the 11-12 Oliver + Ben jam).

A deterministic action-boundary check. Rules are KOs (type constraint or decision) in the shared Sapience project
"oliver-ben"; machine-checkable lines inside a KO's text start with RULE. Stdlib only, no model calls.

  guard.py hook          Claude Code PreToolUse hook (Edit / Write / MultiEdit / NotebookEdit / Bash). JSON on stdin.
                         exit 0 = allow, exit 2 = block (stderr is shown to Claude and the person).
  guard.py precommit     git pre-commit hook: checks the staged diff. exit 1 = refuse the commit.
  guard.py card <id>     set the current task card (a change forces a rule refresh on the next action).
  guard.py status        print the rules in force, the superseded ones, the cache age and the revision.
  guard.py refresh       force one pull now (respects the 10 s spacing and the stop marker).
  guard.py unstop        clear the stop marker after a 503/504/timeout (a human decides when to read again).

Phase A (2026-11-12, attached mode; see the hub section below):
  guard.py hook --attached       PreToolUse, fail closed        guard.py posthook --attached   PostToolUse late re-check
  guard.py precommit --attached  pre-commit, fail closed        guard.py postcommit / postrewrite <how>   events -> outbox
  guard.py send [--reset]        drain the outbox to the sink   guard.py reconcile             find commits the hooks missed
  guard.py observe <sha> [--surface fold]                       guard.py detach                human step: stop enforcing

Rule format (one per line, anywhere in the KO text):
  RULE owner: <glob> = <person>[,<person>]   edits to matching files by anyone else are blocked
  RULE ban-string: <text>                     added text containing <text> (case-insensitive) is blocked
  RULE ban-regex: <python regex>              same, as a regex
  RULE ban-path: <glob>                       writing / staging a matching path is blocked
  RULE no-git: <person>                       git commit / push by <person> is blocked
  SUPERSEDES <hash8> [<hash8> ...]            this KO replaces those KOs (they stay visible, no longer enforced)
A constraint/decision KO with no RULE line is prose: it is printed as "check in the room", never blocks.
Globs: a pattern with no "/" matches the file name at any depth (".env*"); otherwise it is anchored at the repo root;
"**" spans directories, "*" and "?" stay inside one path segment.

State lives in <git-dir>/oliver-ben-guard/ (never tracked): config.json, cache.json, card, log.jsonl, stopped.json.
config.json: {"me": "oliver"|"ben", "source": "...", "ttl_s": 600, "fail": "open"|"closed"}
Env overrides: GUARD_ME, GUARD_SOURCE, GUARD_TTL_S, GUARD_FAIL, GUARD_STATE_DIR, GUARD_DISABLE=1 (guard off).
Sources:
  fixture:<path> / file:<path>     a JSON list of KOs (or {"kos": [...]})
  hosted-rules:<url>               PROPOSED app route returning {"kos": [...]} for one project (not built yet)
  hosted-clusters:oliver-ben       GET <host>/clusters.json, the project's cluster nodes (owner token only; timed out
                                   at 20 s on 2026-11-11, so unverified)
Hosted reads use ~/.sapience/config.json host + token (never printed). On the first 503/504/429/timeout/connection
error the guard writes stopped.json and makes no further network read until `guard.py unstop`; the last good cache
keeps enforcing. Network pulls are at least 10 s apart.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error  # noqa: E402  (light)
from pathlib import Path

RULE_TYPES = ('constraint', 'decision')
MIN_PULL_GAP_S = 10
UA = 'Mozilla/5.0 (Macintosh) oliver-ben-guard/0.1'
EDIT_TOOLS = ('Edit', 'Write', 'MultiEdit', 'NotebookEdit')


# ---------------------------------------------------------------- matching (tests swap these for the negative control)
def glob_to_regex(pat):
    pat = pat.strip()
    anchored = '/' in pat.rstrip('/')
    pat = pat.lstrip('/')
    out, i = '', 0
    while i < len(pat):
        if pat.startswith('**/', i): out += '(?:.*/)?'; i += 3
        elif pat.startswith('**', i): out += '.*'; i += 2
        elif pat[i] == '*': out += '[^/]*'; i += 1
        elif pat[i] == '?': out += '[^/]'; i += 1
        else: out += re.escape(pat[i]); i += 1
    if pat.endswith('/'): out += '.*'
    return ('^' if anchored else '^(?:.*/)?') + out + '$'


def glob_match(path, pat):
    p = path.replace(os.sep, '/')
    if p.startswith('./'): p = p[2:]
    return re.match(glob_to_regex(pat), p) is not None


def string_match(text, needle):
    return needle.lower() in (text or '').lower()


def regex_match(text, rx):
    try: return re.search(rx, text or '') is not None
    except re.error: return False


# ---------------------------------------------------------------- rules
RULE_RE = re.compile(r'^\s*RULE\s+([a-z-]+)\s*:\s*(.+?)\s*$', re.M)
SUP_RE = re.compile(r'^\s*SUPERSEDES\s+(.+)$', re.M)
PROV_SUP_RE = re.compile(r'Supersedes\s*\[([0-9a-f, ]+)\]', re.I)


def h8(h): return str(h or '')[:8]


def author_of(ko):
    a = ko.get('author') or ''
    if a: return a
    pv = str(ko.get('provenance') or '')
    return pv.split('|')[0].strip()[:60] or 'unknown'


def parse_kos(kos):
    """-> (active_rules, prose, superseded, revision). Each rule: dict(kind, arg, ko, author, updated_at)."""
    kos = [k for k in kos if str(k.get('type') or k.get('ko_type') or '').lower() in RULE_TYPES]
    by8 = {h8(k.get('hash')): k for k in kos}
    sup_by = {}                                                # hash8 superseded -> superseding KO
    for k in kos:
        text = str(k.get('object') or k.get('object_value') or '')
        targets = []
        for m in SUP_RE.finditer(text): targets += re.findall(r'[0-9a-f]{6,16}', m.group(1))
        for m in PROV_SUP_RE.finditer(str(k.get('provenance') or '')): targets += re.findall(r'[0-9a-f]{6,16}', m.group(1))
        for t in targets:
            if h8(t) != h8(k.get('hash')): sup_by[h8(t)] = k
    # same subject + predicate: the newest governs (the engine's own supersession rule)
    groups = {}
    for k in kos:
        key = (str(k.get('subject') or '').strip().lower(), str(k.get('predicate') or '').strip().lower())
        if key[0]: groups.setdefault(key, []).append(k)
    for g in groups.values():
        if len(g) < 2: continue
        g = sorted(g, key=lambda k: str(k.get('updated_at') or k.get('created_at') or ''))
        for old in g[:-1]: sup_by.setdefault(h8(old.get('hash')), g[-1])
    active, prose, superseded = [], [], []
    for k in kos:
        if k.get('invalid_at') or h8(k.get('hash')) in sup_by:
            superseded.append({'ko': k, 'by': sup_by.get(h8(k.get('hash')))}); continue
        text = str(k.get('object') or k.get('object_value') or '')
        rules = RULE_RE.findall(text)
        if not rules:
            prose.append(k); continue
        for kind, arg in rules:
            active.append({'kind': kind, 'arg': arg, 'ko': k, 'author': author_of(k),
                           'updated_at': str(k.get('updated_at') or k.get('created_at') or '')})
    canon = json.dumps(sorted([[str(k.get('hash')), str(k.get('object') or k.get('object_value') or ''),
                                str(k.get('updated_at') or ''), str(k.get('invalid_at') or '')] for k in kos]))
    rev = {'sha': hashlib.sha256(canon.encode()).hexdigest()[:12],
           'max_updated_at': max([str(k.get('updated_at') or k.get('created_at') or '') for k in kos] or ['']),
           'n_kos': len(kos)}
    return active, prose, superseded, rev


def cite(r):
    k = r['ko']
    return 'KO %s by %s (%s)' % (h8(k.get('hash')), r['author'], r['updated_at'][:16] or 'no date')


def owners_rule(rules, path):
    """Newest matching owner rule governs (a handoff is a newer owner rule)."""
    hits = [r for r in rules if r['kind'] == 'owner' and '=' in r['arg'] and glob_match(path, r['arg'].split('=', 1)[0].strip())]
    if not hits: return None
    return sorted(hits, key=lambda r: r['updated_at'])[-1]


def check_paths_and_text(rules, me, paths, added_text, git_action=None):
    """-> list of violation strings."""
    v = []
    for p in paths:
        r = owners_rule(rules, p)
        if r:
            owners = [x.strip().lower() for x in r['arg'].split('=', 1)[1].split(',') if x.strip()]
            if me.lower() not in owners and 'anyone' not in owners:
                v.append('%s is owned by %s, not %s: %s ("RULE owner: %s")' % (p, ','.join(owners), me, cite(r), r['arg']))
        for r in rules:
            if r['kind'] == 'ban-path' and glob_match(p, r['arg']):
                v.append('%s is a banned path: %s ("RULE ban-path: %s")' % (p, cite(r), r['arg']))
    for r in rules:
        if r['kind'] == 'ban-string' and string_match(added_text, r['arg']):
            v.append('added text contains banned string "%s": %s' % (r['arg'], cite(r)))
        if r['kind'] == 'ban-regex' and regex_match(added_text, r['arg']):
            v.append('added text matches banned pattern /%s/: %s' % (r['arg'], cite(r)))
    if git_action:
        for r in rules:
            if r['kind'] == 'no-git' and r['arg'].strip().lower() == me.lower():
                v.append('git %s by %s is not allowed: %s ("RULE no-git: %s")' % (git_action, me, cite(r), r['arg']))
    return v


# ---------------------------------------------------------------- state, cache, sources
def git(args, cwd):
    p = subprocess.run(['git'] + args, cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def repo_root(cwd):
    rc, out, _ = git(['rev-parse', '--show-toplevel'], cwd)
    return out.strip() if rc == 0 else None


def state_dir(root):
    if os.environ.get('GUARD_STATE_DIR'): d = Path(os.environ['GUARD_STATE_DIR'])
    else:
        rc, out, _ = git(['rev-parse', '--git-common-dir'], root)
        gd = Path(out.strip()); gd = gd if gd.is_absolute() else Path(root) / gd
        d = gd / 'oliver-ben-guard'
    d.mkdir(parents=True, exist_ok=True)
    return d


def load_cfg(sd):
    cfg = {'me': '', 'source': '', 'ttl_s': 600, 'fail': 'open'}
    try: cfg.update(json.loads((sd / 'config.json').read_text()))
    except Exception: pass
    for k, e in (('me', 'GUARD_ME'), ('source', 'GUARD_SOURCE'), ('ttl_s', 'GUARD_TTL_S'), ('fail', 'GUARD_FAIL')):
        if os.environ.get(e): cfg[k] = os.environ[e]
    cfg['ttl_s'] = float(cfg['ttl_s'])
    return cfg


def atomic_write(p, data):
    tmp = Path(str(p) + '.tmp'); tmp.write_text(data); os.replace(tmp, p)


class _LazyUrllib:
    def __getattr__(self, name):
        import urllib.request as _r
        return getattr(_r, name)


class SourceStop(Exception): pass


_URLREQ = _LazyUrllib()


def fetch_source(src):
    """-> list of KO dicts. Raises SourceStop on a load-type failure from a hosted Sapience."""
    if src.startswith('fixture:') or src.startswith('file:'):
        d = json.loads(Path(src.split(':', 1)[1]).expanduser().read_text())
        return d.get('kos', d) if isinstance(d, dict) else d
    if src.startswith('hosted-rules:') or src.startswith('hosted-clusters:'):
        c = json.loads((Path.home() / '.sapience' / 'config.json').read_text())
        kind, arg = src.split(':', 1)
        url = arg if kind == 'hosted-rules' else c['host'].rstrip('/') + '/clusters.json'
        req = _URLREQ.Request(url, headers={'Authorization': 'Bearer ' + c['token'], 'User-Agent': UA})
        try:
            body = _URLREQ.urlopen(req, timeout=20).read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503, 504): raise SourceStop('HTTP %d' % e.code)
            raise
        except Exception as e:                           # timeout, refused, reset, DNS
            raise SourceStop(type(e).__name__)
        d = json.loads(body)
        if kind == 'hosted-rules': return d.get('kos', [])
        out = []
        for cl in d.get('clusters') or []:
            if cl.get('project_tag') != arg: continue
            for n in cl.get('nodes') or []:
                if str(n.get('h', '')).startswith('doc:'): continue
                out.append({'hash': n.get('h'), 'subject': n.get('s'), 'predicate': n.get('pr'), 'object': n.get('o'),
                            'provenance': n.get('pv'), 'type': n.get('ty'), 'updated_at': ''})   # the map has no updated_at
        return out
    raise ValueError('unknown source %r' % src)


def get_rules(root, force=False):
    """-> (active, prose, superseded, rev, meta). Pulls on cache miss: no cache, card changed, TTL expired, or force."""
    sd = state_dir(root); cfg = load_cfg(sd)
    card = (sd / 'card').read_text().strip() if (sd / 'card').exists() else ''
    try: cache = json.loads((sd / 'cache.json').read_text())
    except Exception: cache = None
    now = time.time()
    why = None
    if cache is None: why = 'no cache'
    elif force: why = 'forced'
    elif cache.get('card') != card: why = 'card changed %r -> %r' % (cache.get('card'), card)
    elif now - cache.get('fetched_at', 0) >= cfg['ttl_s']: why = 'ttl expired'
    meta = {'card': card, 'pulled': False, 'why': why, 'warn': ''}
    if why:
        hosted = cfg['source'].startswith('hosted')
        stopped = (sd / 'stopped.json').exists()
        too_soon = hosted and cache and now - cache.get('fetched_at', 0) < MIN_PULL_GAP_S
        if not cfg['source']: meta['warn'] = 'no rule source configured'
        elif hosted and stopped: meta['warn'] = 'network reads stopped after a failure (see stopped.json; `guard.py unstop`)'
        elif too_soon: meta['warn'] = 'pull skipped: last pull < %d s ago' % MIN_PULL_GAP_S
        else:
            try:
                kos = fetch_source(cfg['source'])
                cache = {'fetched_at': now, 'card': card, 'source': cfg['source'], 'kos': kos}
                atomic_write(sd / 'cache.json', json.dumps(cache))
                meta['pulled'] = True
            except SourceStop as e:
                atomic_write(sd / 'stopped.json', json.dumps({'at': now, 'error': str(e), 'source': cfg['source']}))
                meta['warn'] = 'hosted read failed (%s): STOPPED, no retry; using last cache' % e
            except Exception as e:
                meta['warn'] = 'rule source error (%s): using last cache' % str(e)[:120]
    kos = (cache or {}).get('kos')
    if kos is None:
        meta['no_rules'] = True; kos = []
    meta['age_s'] = round(now - (cache or {}).get('fetched_at', now), 1)
    active, prose, superseded, rev = parse_kos(kos)
    return active, prose, superseded, rev, meta, cfg, sd


def log(sd, rec):
    try:
        with open(sd / 'log.jsonl', 'a') as f: f.write(json.dumps(rec) + '\n')
    except OSError: pass


def prose_lines(prose, superseded):
    out = []
    for k in prose:
        out.append('  check in the room: KO %s by %s: %s' % (h8(k.get('hash')), author_of(k),
                                                             re.sub(r'\s+', ' ', str(k.get('object') or k.get('object_value') or ''))[:220]))
    for s in superseded:
        k, by = s['ko'], s['by']
        out.append('  superseded (not enforced): KO %s by %s%s' % (h8(k.get('hash')), author_of(k),
                   (' -> replaced by KO %s by %s' % (h8(by.get('hash')), author_of(by))) if by else ' (invalidated)'))
    return out


# ---------------------------------------------------------------- what an action touches
GIT_COMMIT_RE = re.compile(r'(^|[;&|(]\s*|\s)git\s+(?:-C\s+\S+\s+)?commit\b')
GIT_PUSH_RE = re.compile(r'(^|[;&|(]\s*|\s)git\s+(?:-C\s+\S+\s+)?push\b')


def staged_changes(root, include_worktree=False):
    """-> (paths, added_text) for the staged diff (plus unstaged + untracked when include_worktree)."""
    rc, names, _ = git(['diff', '--cached', '--name-only', '--diff-filter=ACMRD'], root)
    rc2, diff, _ = git(['diff', '--cached', '-U0', '--no-color'], root)
    paths = [p for p in names.splitlines() if p]
    if include_worktree:
        _, n2, _ = git(['diff', 'HEAD', '--name-only'], root)
        _, d2, _ = git(['diff', 'HEAD', '-U0', '--no-color'], root)
        _, un, _ = git(['ls-files', '--others', '--exclude-standard'], root)
        paths += n2.splitlines() + un.splitlines(); diff += d2
        for u in un.splitlines():
            try: diff += '\n+' + (Path(root) / u).read_text(errors='replace')[:200000]
            except OSError: pass
    added = '\n'.join(l[1:] for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++'))
    return sorted(set(p for p in paths if p)), added


def push_changes(root):
    for rng in ('@{u}..HEAD', 'origin/HEAD..HEAD', 'origin/main..HEAD'):
        rc, names, _ = git(['diff', '--name-only', rng], root)
        if rc == 0:
            _, diff, _ = git(['diff', '-U0', '--no-color', rng], root)
            added = '\n'.join(l[1:] for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++'))
            return [p for p in names.splitlines() if p], added, rng
    return [], '', None


def rel(root, fp):
    try: return str(Path(os.path.realpath(fp)).relative_to(os.path.realpath(root)))
    except ValueError: return None


# ---------------------------------------------------------------- entry points
def evaluate_tool_legacy(payload):
    """-> (exit_code, stderr_text, system_message). Pure enough for in-process tests."""
    if os.environ.get('GUARD_DISABLE') == '1': return 0, '', ''
    tool = payload.get('tool_name') or ''
    ti = payload.get('tool_input') or {}
    cwd = payload.get('cwd') or os.getcwd()
    paths, text, git_action, extra = [], '', None, []
    if tool in EDIT_TOOLS:
        fp = ti.get('file_path') or ti.get('notebook_path') or ''
        base = os.path.dirname(fp) if fp else cwd
        while base and not os.path.isdir(base): base = os.path.dirname(base)
        root = repo_root(base or cwd)
        if not root: return 0, '', ''
        r = rel(root, fp)
        if r is None: return 0, '', ''
        paths = [r]
        text = '\n'.join([str(ti.get('content') or ''), str(ti.get('new_string') or ''), str(ti.get('new_source') or '')] +
                         [str(e.get('new_string') or '') for e in (ti.get('edits') or [])])
    elif tool == 'Bash':
        cmd = str(ti.get('command') or '')
        is_commit, is_push = bool(GIT_COMMIT_RE.search(cmd)), bool(GIT_PUSH_RE.search(cmd))
        if not (is_commit or is_push): return 0, '', ''
        root = repo_root(cwd)
        if not root: return 0, '', ''
        if is_commit:
            wide = bool(re.search(r'\s-[a-zA-Z]*a|--all|git\s+add', cmd))
            p, t = staged_changes(root, include_worktree=wide); paths += p; text += t; git_action = 'commit'
        if is_push:
            p, t, rng = push_changes(root); paths += p; text += '\n' + t; git_action = git_action or 'push'
            if rng is None: extra.append('push range unknown (no upstream): commits were not re-checked here')
    else:
        return 0, '', ''
    active, prose, superseded, rev, meta, cfg, sd = get_rules(root)
    me = cfg['me'] or 'unknown'
    v = check_paths_and_text(active, me, paths, text, git_action)
    rec = {'ts': time.time(), 'tool': tool, 'me': me, 'card': meta['card'], 'paths': paths[:20], 'revision': rev,
           'pulled': meta['pulled'], 'why': meta['why'], 'cache_age_s': meta['age_s'], 'warn': meta['warn'],
           'enforced': sorted(set(h8(r['ko'].get('hash')) for r in active)), 'decision': 'block' if v else 'allow',
           'violations': v}
    head = '[oliver-ben guard] rules rev %s (%d KOs, newest %s, card %s, cache %ss%s)' % (
        rev['sha'], rev['n_kos'], rev['max_updated_at'][:16] or '-', meta['card'] or '-', meta['age_s'],
        ', just pulled' if meta['pulled'] else '')
    warn = []
    if meta['warn']: warn.append('  WARNING: ' + meta['warn'])
    if meta.get('no_rules'):
        warn.append('  WARNING: NO RULES LOADED. The guard is not enforcing anything.')
        if cfg.get('fail') == 'closed' and (tool in EDIT_TOOLS or git_action):
            v = v + ['no rules loaded and fail=closed']
            rec['decision'] = 'block'; rec['violations'] = v
    log(sd, rec)
    show_prose = meta['pulled'] or git_action
    sysmsg = '\n'.join([head] + warn + (prose_lines(prose, superseded) if show_prose else []) + ['  ' + e for e in extra])
    if v:
        msg = '\n'.join([head, 'BLOCKED by the oliver-ben rules:'] + ['  - ' + x for x in v] + warn +
                        ['If the rule is wrong, change it in the room (a newer KO); do not work around it.'])
        return 2, msg, ''
    return 0, '', sysmsg if (show_prose or warn or extra) else ''




# ==================================================================================================================
# SF-1 shared hub, phase A (2026-11-12). Attached mode. Prereg: /Users/oz/data/sf1-reports/sf1-hub-phase-a-prereg-1112.md
#
# Attached mode is selected by config.json {"mode": "attached"} AND the hook flag --attached. In attached mode:
#  - every CONTROLLED action is admitted against the current rules revision (coalescing window coalesce_s, default 1 s);
#  - unknown authority (source missing / unreadable / wrong schema / not a member / timeout / 401 / 403 / 429 / 5xx)
#    SUSPENDS: block, stop marker, one "suspended" event, no retry on a timer; a human runs `guard.py unstop`;
#  - a guard crash or the internal deadline blocks (the settings command adds `|| exit 2`), never admits;
#  - read-only Bash never needs admission and is never slowed by the network;
#  - blocks come only from RULE lines in the rules source (plus the fail-closed cases above). Self-protection and the
#    deploy/send authority matrix are RULE kinds too (guard-protect, authority), so they bind only once ruled.
# Rule sources:  hub-rules:<path>  LOCAL FIXTURE stand-in (schema sf1-hub-rules/1)
#                hub-route:<url>   APP's GET /v1/projects/<slug>/rules (ETag / If-None-Match); not shipped yet
# Event sinks:   local-events:<path>  LOCAL EVENT LOG stand-in (stamps received_at, dedupes on event_id)
#                hosted-events:<url>  APP's POST /v1/rooms/<id>/events; not shipped yet
# ==================================================================================================================
import fcntl
import secrets
import shlex
import signal
import socket

HUB_SCHEMA = 'sf1-hub-rules/1'
EVENT_SCHEMA = 'sf1-hub-event/1'
EVENT_KINDS = ('commit', 'rewrite', 'guard', 'reconcile', 'observe')
GUARD_DIR = Path(__file__).resolve().parent
TEST_ROOT = GUARD_DIR / '_testrun_hub'
AGENT_ID_RE = re.compile(r'^\s*(claude|sf-?1|cc\b|bot|agent|sapience|assistant|astra|fable|codex|gpt)', re.I)
CROCK = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'


def ulid():
    n = (int(time.time() * 1000) << 80) | secrets.randbits(80)
    return ''.join(CROCK[(n >> (5 * i)) & 31] for i in range(25, -1, -1))


def iso(ts=None):
    return time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(ts if ts is not None else time.time())) + \
        '.%03dZ' % int(((ts if ts is not None else time.time()) % 1) * 1000)


class Suspend(Exception): pass
class DeadlineHit(Exception): pass


def fast_root(cwd):
    """(toplevel, common git dir) by walking up for .git, without a git subprocess (saves ~25 ms per hook call).
    Falls back to git for anything unusual."""
    d = os.path.realpath(cwd)
    while True:
        g = os.path.join(d, '.git')
        if os.path.isdir(g): return d, g
        if os.path.isfile(g):
            try:
                gd = open(g).read().split('gitdir:', 1)[1].strip()
                gd = gd if os.path.isabs(gd) else os.path.normpath(os.path.join(d, gd))
                cd = os.path.join(gd, 'commondir')
                if os.path.isfile(cd):
                    c = open(cd).read().strip(); gd = c if os.path.isabs(c) else os.path.normpath(os.path.join(gd, c))
                return d, gd
            except Exception: break
        nd = os.path.dirname(d)
        if nd == d: return None, None
        d = nd
    r = repo_root(cwd)
    if not r: return None, None
    rc, out, _ = git(['rev-parse', '--git-common-dir'], r)
    gd = Path(out.strip()); return r, str(gd if gd.is_absolute() else Path(r) / gd)


def peek_cfg(root):
    """Read config without creating anything. -> (cfg dict, state dir Path) or (None, None)."""
    r, gd = fast_root(root)
    if not gd: return None, None
    sd = Path(gd) / 'oliver-ben-guard'
    try: cfg = json.loads((sd / 'config.json').read_text())
    except Exception: return None, sd
    return cfg, sd


def in_test(sd):
    try: return Path(os.path.realpath(sd)).is_relative_to(os.path.realpath(TEST_ROOT))
    except Exception: return False


def knobs(sd):
    """Negative-control switches. Honoured ONLY when the state dir is inside the guard's own test dir."""
    if not in_test(sd): return set()
    return set(x for x in os.environ.get('GUARD_TEST_BREAK', '').split(',') if x)


def hub_cfg(root):
    cfg, sd = peek_cfg(root)
    if cfg is None: return None, sd
    c = {'me': '', 'source': '', 'sink': '', 'mode': 'legacy', 'coalesce_s': 1.0, 'net_timeout_s': 2.0,
         'deadline_s': 8.0, 'members': None, 'require_accept': True, 'refs': [], 'since_ts': 0, 'key_file': ''}
    c.update(cfg)
    if in_test(sd):                                   # env overrides only inside the test dir (agents cannot use them)
        for k, e in (('me', 'GUARD_ME'), ('source', 'GUARD_SOURCE'), ('sink', 'GUARD_SINK')):
            if os.environ.get(e): c[k] = os.environ[e]
        if os.environ.get('GUARD_COALESCE_S'): c['coalesce_s'] = float(os.environ['GUARD_COALESCE_S'])
        if os.environ.get('GUARD_DEADLINE_S'): c['deadline_s'] = float(os.environ['GUARD_DEADLINE_S'])
    c['coalesce_s'] = float(c['coalesce_s']); c['net_timeout_s'] = float(c['net_timeout_s'])
    c['deadline_s'] = float(c['deadline_s'])
    return c, sd


def source_label(src):
    if src.startswith('hub-rules:'): return 'LOCAL FIXTURE (not the store)'
    if src.startswith('hub-route:'):
        return 'MOCK route' if '127.0.0.1' in src or 'localhost' in src else 'APP rules route'
    return 'unknown'


# ---------------------------------------------------------------- admission
def hub_token(cfg):
    if cfg.get('key_file'):
        return Path(cfg['key_file']).expanduser().read_text().strip()
    return json.loads((Path.home() / '.sapience' / 'config.json').read_text())['token']


def hub_fetch(cfg, cache):
    """-> (doc or None if 304, etag). Raises Suspend on any unknown-authority condition."""
    src = cfg['source']
    if src.startswith('hub-rules:'):
        p = Path(src.split(':', 1)[1]).expanduser()
        try: d = json.loads(p.read_text())
        except FileNotFoundError: raise Suspend('rule source missing (%s)' % p)
        except Exception as e: raise Suspend('rule source unreadable (%s)' % type(e).__name__)
        return d, 'r%s' % d.get('revision') if isinstance(d, dict) else None
    if src.startswith('hub-route:'):
        url = src.split(':', 1)[1]
        try: tok = hub_token(cfg)
        except Exception: raise Suspend('no hub key available')
        h = {'Authorization': 'Bearer ' + tok, 'User-Agent': UA, 'Accept': 'application/json'}
        if cache and cache.get('etag'): h['If-None-Match'] = cache['etag']
        try:
            resp = _URLREQ.urlopen(_URLREQ.Request(url, headers=h), timeout=cfg['net_timeout_s'])
            body, etag = resp.read(), resp.headers.get('ETag')
        except urllib.error.HTTPError as e:
            if e.code == 304: return None, cache.get('etag') if cache else None
            if e.code in (401, 403): raise Suspend('rules route refused this key (HTTP %d): not a member?' % e.code)
            raise Suspend('rules route HTTP %d' % e.code)
        except Exception as e:
            raise Suspend('rules route unreachable (%s)' % type(e).__name__)
        try: d = json.loads(body)
        except Exception: raise Suspend('rules route returned non-JSON')
        return d, etag
    raise Suspend('attached mode needs a hub-rules: or hub-route: source (got %r)' % src[:40])


def validate_doc(d, cfg):
    if not isinstance(d, dict) or d.get('schema') != HUB_SCHEMA: raise Suspend('rules doc has the wrong schema')
    if not isinstance(d.get('revision'), int): raise Suspend('rules doc has no integer revision')
    members = [str(m).lower() for m in (d.get('members') or [])]
    if (cfg['me'] or '').lower() not in members: raise Suspend('%r is not a member of %s' % (cfg['me'], d.get('project')))


def suspend(root, sd, cfg, reason):
    stop = sd / 'stopped.json'
    if not stop.exists():
        atomic_write(stop, json.dumps({'at': time.time(), 'error': reason, 'source': cfg['source'], 'by': 'admission'}))
        enqueue(root, sd, cfg, guard_event(root, cfg, sd, 'suspended', reason=reason))


def admit(root, sd, cfg):
    """-> (cache, how). cache = {checked_at, etag, revision, doc}. Raises Suspend."""
    k = knobs(sd)
    stop = sd / 'stopped.json'
    try: cache = json.loads((sd / 'hubcache.json').read_text())
    except Exception: cache = None
    if stop.exists() and 'suspend' not in k:
        try: why = json.loads(stop.read_text()).get('error', '')
        except Exception: why = 'stop marker'
        raise Suspend('stopped earlier: %s' % why)
    now = time.time()
    if cache and ('revcheck' in k or now - cache.get('checked_at', 0) < cfg['coalesce_s']):
        return cache, 'coalesced' if 'revcheck' not in k else 'cache(BROKEN revcheck)'
    try:
        d, etag = hub_fetch(cfg, cache)
        if d is None:
            if not cache: raise Suspend('rules route sent 304 with no cached revision')
            cache['checked_at'] = now; atomic_write(sd / 'hubcache.json', json.dumps(cache)); return cache, '304'
        validate_doc(d, cfg)
    except Suspend as e:
        if 'suspend' in k: return (cache or {'revision': -1, 'doc': {'kos': []}, 'etag': None}), 'BROKEN suspend'
        suspend(root, sd, cfg, str(e)); raise
    old_rev = cache.get('revision') if cache else None
    cache = {'checked_at': now, 'etag': etag, 'revision': d['revision'], 'doc': d}
    atomic_write(sd / 'hubcache.json', json.dumps(cache))
    return cache, ('pulled' if old_rev != d['revision'] else 'checked')


def hub_rules(cache, cfg):
    """Filter the doc into enforceable KOs: events never become rules; unaccepted RULE KOs are proposals."""
    d = cache.get('doc') or {}
    members = [str(m).lower() for m in (d.get('members') or [])]
    out = []
    for k in d.get('kos') or []:
        if str(k.get('kind') or '').lower() in EVENT_KINDS or str(k.get('type') or '').lower() == 'event' or \
                str(k.get('provenance') or '').lower().startswith('hub-event'):
            continue                                                 # echo suppression: events are never rules
        text = str(k.get('object') or k.get('object_value') or '')
        if cfg.get('require_accept', True) and (RULE_RE.search(text) or SUP_RE.search(text)):
            acc = str(k.get('accepted_by') or '').strip()
            ok = bool(acc) and not AGENT_ID_RE.match(acc) and acc.lower().split()[0] in members
            if not ok:
                k = dict(k, object='[PROPOSED by %s, not binding until a human member Accepts] ' % author_of(k) +
                         RULE_RE.sub(lambda m: 'rule-text ' + m.group(1) + ': ' + m.group(2), SUP_RE.sub('supersedes-text \\1', text)),
                         provenance='proposal')
        out.append(k)
    return parse_kos(out)


# ---------------------------------------------------------------- Bash classification
READ_CMDS = set('''ls cat head tail less more grep egrep fgrep rg ag wc pwd echo printf which type stat file du df date
whoami id hostname uname sw_vers uptime ps lsof pgrep sort uniq cut tr awk jq diff cmp basename dirname realpath
readlink true false test [ tree md5 shasum sha256sum cd pushd popd export unset set read sleep env column nl fold
od hexdump strings comm paste expr seq yes printenv locale tput clear history alias'''.split())
GIT_READ = set('status log diff show branch rev-parse ls-files ls-tree blame grep describe shortlog remote fetch '
               'reflog cat-file show-ref name-rev merge-base rev-list for-each-ref help version count-objects add'.split())
GIT_PATHWRITE = set('checkout restore mv rm'.split())
INTERP = set('python python3 node ruby perl bash sh zsh deno bun php lua'.split())
WRAPPERS = set('sudo command nohup time exec nice caffeinate'.split())
SEPS = {';', '&&', '||', '|', '&', '(', ')', ';;', '|&', '\n'}
REDIR_W = {'>', '>>', '>|', '&>', '&>>'}
REDIR_SKIP = {'<', '<<', '<<<', '<&', '>&', '<>'}
HEREDOC_RE = re.compile(r'<<-?\s*([\'"]?)([A-Za-z_][A-Za-z0-9_]*)\1')
PATH_LIT_RE = re.compile(r'''['"]([^'"\n]{1,300})['"]''')


def strip_heredocs(cmd):
    lines, out, bodies, i = cmd.split('\n'), [], [], 0
    while i < len(lines):
        l = lines[i]; out.append(l)
        delims = [m.group(2) for m in HEREDOC_RE.finditer(l)]
        for dl in delims:
            j, body = i + 1, []
            while j < len(lines) and lines[j].strip() != dl: body.append(lines[j]); j += 1
            bodies.append('\n'.join(body)); i = j
        i += 1
    return '\n'.join(out), bodies


def tokenize(s):
    s = s.replace('$(', ' ; ').replace('`', ' ; ').replace('\n', ' ; ')
    lex = shlex.shlex(s, posix=True, punctuation_chars=';&|<>()')
    lex.whitespace_split = True; lex.commenters = ''
    return list(lex)


def classify_bash(cmd, cwd, root, depth=0):
    """-> dict(kinds set, targets [abs], unknown bool, text str, segs [..]).
    kinds: read | write | opaque | commit | push. targets = paths the command writes (best effort)."""
    res = {'kinds': set(), 'targets': [], 'unknown': False, 'text': cmd, 'segs': []}
    flat, bodies = strip_heredocs(cmd)
    res['text'] = cmd + '\n' + '\n'.join(bodies)
    try: toks = tokenize(flat)
    except ValueError:
        res['kinds'].add('opaque'); res['unknown'] = True; return res
    segs, cur = [], []
    for t in toks:
        if t in SEPS: (segs.append(cur) if cur else None); cur = []
        else: cur.append(t)
    if cur: segs.append(cur)
    cwd_now = cwd

    def ab(p):
        p = os.path.expanduser(p)
        return os.path.normpath(p if os.path.isabs(p) else os.path.join(cwd_now, p))

    for seg in segs:
        words, wtargets, i = [], [], 0
        while i < len(seg):
            t = seg[i]
            if t in REDIR_W:
                if i + 1 < len(seg):
                    tg = seg[i + 1]
                    if tg.startswith('$'): res['unknown'] = True
                    elif not (tg.isdigit() or tg.startswith('/dev/')): wtargets.append(ab(tg))
                i += 2; continue
            if t in REDIR_SKIP: i += 2; continue
            words.append(t); i += 1
        while words and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', words[0]): words = words[1:]
        while words and words[0] in WRAPPERS: words = words[1:]
        if words and words[0] == 'env':
            words = words[1:]
            while words and (words[0].startswith('-') or '=' in words[0]): words = words[1:]
        if not words:
            if wtargets: res['kinds'].add('write'); res['targets'] += wtargets
            continue
        c = os.path.basename(words[0]); args = words[1:]
        opts = [a for a in args if a.startswith('-')]
        nonopt = [a for a in args if not a.startswith('-') and a != '']
        kind, tg = 'read', []
        if c == 'cd':
            if nonopt: cwd_now = ab(nonopt[0])
        elif c == 'git':
            a = list(args)
            while a and a[0] in ('-C', '-c'): a = a[2:]
            sub = a[0] if a else ''
            rest = a[1:]
            if sub == 'commit': kind = 'commit'
            elif sub == 'push': kind = 'push'
            elif sub in GIT_PATHWRITE:
                files = rest[rest.index('--') + 1:] if '--' in rest else [x for x in rest if not x.startswith('-')]
                if sub == 'checkout' and '--' not in rest:
                    kind = 'opaque'                                     # branch switch: many files
                else:
                    kind, tg = 'write', [ab(f) for f in files] if sub != 'mv' else [ab(f) for f in files]
            elif sub in GIT_READ or (sub == 'config' and ('--get' in rest or '--list' in rest or '-l' in rest)) \
                    or (sub == 'stash' and rest[:1] == ['list']):
                kind = 'read'
            else:
                kind = 'opaque'
        elif c == 'sed':
            if any(o.startswith('-i') or o.startswith('--in-place') for o in opts):
                files = list(nonopt)
                if '-e' not in args and '-f' not in args and files: files = files[1:]
                kind, tg = 'write', [ab(f) for f in files]
        elif c in ('perl', 'ruby') and any(re.match(r'^-[a-zA-Z]*i', o) for o in opts):
            files, skip = [], False
            for x in args:
                if skip: skip = False; continue
                if x in ('-e', '-E'): skip = True; continue
                if x.startswith('-'): continue
                files.append(x)
            kind, tg = 'write', [ab(f) for f in files if f]
        elif c in INTERP:
            if c in ('bash', 'sh', 'zsh') and '-c' in args and depth < 3:
                inner = args[args.index('-c') + 1] if args.index('-c') + 1 < len(args) else ''
                sub = classify_bash(inner, cwd_now, root, depth + 1)
                res['kinds'] |= sub['kinds']; res['targets'] += sub['targets']; res['unknown'] |= sub['unknown']
                res['segs'] += sub['segs']; kind = None
            elif any(o in ('-c', '-e', '-E', '--eval') for o in opts):
                flag = next(o for o in args if o in ('-c', '-e', '-E', '--eval'))
                code = args[args.index(flag) + 1] if args.index(flag) + 1 < len(args) else ''
                lits = [m.group(1) for m in PATH_LIT_RE.finditer(code)]
                cand = [ab(x) for x in lits if ('/' in x or '.' in x) and ' ' not in x and len(x) < 200]
                cand = [x for x in cand if rel(root, x) is not None]
                kind, tg = ('write', cand) if cand else ('opaque', [])
            else:
                kind = 'opaque'
        elif c == 'tee':
            kind, tg = 'write', [ab(f) for f in nonopt]
        elif c in ('cp', 'mv', 'install', 'ln', 'rsync', 'ditto', 'scp'):
            if nonopt:
                dest = ab(nonopt[-1]); tg = [dest]
                if os.path.isdir(dest) and len(nonopt) > 1: tg += [os.path.join(dest, os.path.basename(s)) for s in nonopt[:-1]]
                if c == 'mv': tg += [ab(s) for s in nonopt[:-1]]
            kind = 'write'
        elif c in ('rm', 'rmdir', 'unlink', 'touch', 'chmod', 'chown', 'mkdir', 'shred', 'chflags'):
            files = nonopt[1:] if c in ('chmod', 'chown', 'chflags') else nonopt
            kind, tg = 'write', [ab(f) for f in files]
        elif c == 'truncate':
            files, skip = [], False
            for x in args:
                if skip: skip = False; continue
                if x in ('-s', '-r'): skip = True; continue
                if x.startswith('-'): continue
                files.append(x)
            kind, tg = 'write', [ab(f) for f in files]
        elif c == 'dd':
            tg = [ab(x[3:]) for x in args if x.startswith('of=')]
            kind = 'write' if tg else 'read'
        elif c == 'find':
            if any(o in ('-delete', '-exec', '-execdir', '-ok', '-okdir', '-fprint', '-fprintf', '-fls') for o in args): kind = 'opaque'
        elif c in ('xargs', 'make', 'npm', 'npx', 'pnpm', 'yarn', 'cargo', 'go', 'patch', 'brew', 'pip', 'pip3', 'uv',
                   'docker', 'flyctl', 'fly', 'vercel', 'gh', 'curl', 'wget', 'osascript', 'open', 'tmux', 'ssh', 'scp',
                   'sqlite3', 'kill', 'pkill', 'killall', 'launchctl', 'crontab', 'claude'):
            kind = 'opaque'
        elif c in READ_CMDS:
            kind = 'read'
        else:
            kind = 'opaque'                                             # unknown command: cannot prove read-only
        if kind: res['kinds'].add(kind)
        if wtargets: res['kinds'].add('write'); tg = tg + wtargets
        res['targets'] += tg
        res['segs'].append({'cmd': c, 'kind': kind, 'n_targets': len(tg)})
    return res


# ---------------------------------------------------------------- self-protection + authority (RULE kinds; bind only when ruled)
def cfg_paths():
    """The configured rules file and event sink, wherever they live (set by evaluate_hub)."""
    return list(_CFG_PATHS)


_CFG_PATHS = []


def protected_zones(root, sd):
    z = [str(GUARD_DIR), str(sd)] + cfg_paths() + [ os.path.join(root, '.git', 'hooks'), os.path.join(root, '.git', 'config'),
         str(Path.home() / '.claude' / 'settings.json'), str(Path.home() / '.claude' / 'settings.local.json')]
    return [os.path.realpath(x) for x in z]


def is_protected(path, root, sd):
    rp = os.path.realpath(path)
    tr = os.path.realpath(TEST_ROOT)
    for z in protected_zones(root, sd):
        if z == os.path.realpath(GUARD_DIR) and (rp == tr or rp.startswith(tr + '/')): continue   # test repos live here
        if rp == z or rp.startswith(z.rstrip('/') + '/'): return True
    r = rel(root, rp)
    return bool(r and re.match(r'^\.claude/settings(\.local)?\.json$', r))


SELFMOD_CMD_RES = [(re.compile(r'--no-verify\b'), 'git --no-verify skips the guard hooks'),
                   (re.compile(r'\bgit\b[^;&|\n]*\bcommit\b[^;&|\n]*\s-[a-zA-Z]*n[a-zA-Z]*\b'), 'git commit -n skips the guard hooks'),
                   (re.compile(r'core\.hooksPath', re.I), 'changing core.hooksPath detaches the guard hooks'),
                   (re.compile(r'\bGUARD_[A-Z_]+'), 'GUARD_* environment variables change the guard'),
                   (re.compile(r'guard\.py\s+(unstop|detach)\b'), 'unstop / detach is a human step in your own terminal'),
                   (re.compile(r'disableAllHooks'), 'disableAllHooks turns the guard off')]
AUTH_RES = [(re.compile(r'\b(fly|flyctl)\s+deploy\b'), 'deploy', 'deploy (fly)'),
            (re.compile(r'\bvercel\b[^;&|\n]*--prod'), 'deploy', 'deploy (vercel --prod)'),
            (re.compile(r'\bgit\b[^;&|\n]*\bpush\b[^;&|\n]*\b(main|master|production)\b'), 'deploy', 'push to main/production'),
            (re.compile(r'\b(twine\s+upload|npm\s+publish|cargo\s+publish|docker\s+push)\b'), 'deploy', 'package publish'),
            (re.compile(r'\brelease\.sh\b|\bdeploy[-_a-z]*\.sh\b'), 'deploy', 'release/deploy script'),
            (re.compile(r'\bgh\s+(pr|issue|release)\s+create\b'), 'send', 'GitHub PR/issue/release'),
            (re.compile(r'\bgh\s+api\b[^;&|\n]*-X\s*(POST|PUT|PATCH|DELETE)', re.I), 'send', 'gh api write'),
            (re.compile(r'hooks\.slack\.com|slack\.com/api|api\.resend\.com|web\.archive\.org'), 'send', 'external send')]


def protect_rules(active, me):
    """guard-protect: <all|person,...>  ;  authority: <deploy|send|all> = <person,...>"""
    gp = [r for r in active if r['kind'] == 'guard-protect' and
          ({'all', 'anyone', me.lower()} & set(x.strip().lower() for x in r['arg'].split(',')))]
    au = []
    for r in active:
        if r['kind'] == 'authority' and '=' in r['arg']:
            allowed = [x.strip().lower() for x in r['arg'].split('=', 1)[1].split(',')]
            if me.lower() not in allowed: au.append(r)
    return gp, au


def selfmod_violations(gp, tool, ti, root, sd, bash_cls=None):
    if not gp: return []
    r0 = gp[0]; v = []
    if tool in EDIT_TOOLS:
        fp = ti.get('file_path') or ti.get('notebook_path') or ''
        if fp and is_protected(fp, root, sd): v.append('%s is guard machinery: %s ("RULE guard-protect: %s")' % (fp, cite(r0), r0['arg']))
    elif tool == 'Bash':
        cmd = str(ti.get('command') or '')
        for rx, why in SELFMOD_CMD_RES:
            if rx.search(cmd): v.append('%s: %s' % (why, cite(r0)))
        for t in (bash_cls or {}).get('targets', []):
            if is_protected(t, root, sd): v.append('%s is guard machinery: %s' % (t, cite(r0)))
        # running anything that names the guard dir or its rules file, other than a read or a guard status/refresh/card
        names = [str(GUARD_DIR)] + cfg_paths()
        kinds = (bash_cls or {}).get('kinds', set()) - {'read'}
        benign = re.fullmatch(r'\s*(\S*python3?\S*\s+)?\S*guard\.py\s+(status|refresh|card(\s+\S+)?)\s*', cmd)
        if kinds and not benign and any(n and n in cmd for n in names):
            v.append('this command runs or changes guard machinery (%s): %s' % (', '.join(sorted(kinds)), cite(r0)))
    return v


def authority_violations(au, cmd, me):
    v = []
    for rx, cat, what in AUTH_RES:
        if not rx.search(cmd): continue
        for r in au:
            scope = r['arg'].split('=', 1)[0].strip().lower()
            if scope in ('all', cat):
                v.append('%s by %s is reserved for %s: %s ("RULE authority: %s")' % (what, me, r['arg'].split('=', 1)[1].strip(), cite(r), r['arg']))
                break
    return v


# ---------------------------------------------------------------- events, outbox, sender, sink
def runner_id(me):
    return '%s-%s' % (me or 'unknown', hashlib.sha256(socket.gethostname().encode()).hexdigest()[:8])


def surface():
    if os.environ.get('SF1_HUB_SURFACE') == 'bg-cc': return 'bg-cc'
    return 'cc' if os.environ.get('CLAUDECODE') == '1' else 'human'


def repo_id(root):
    rc, out, _ = git(['config', '--get', 'remote.origin.url'], root)
    u = out.strip()
    if rc == 0 and u:
        u = re.sub(r'^[a-z]+://[^@/]*@', 'https://', u)
        m = re.search(r'[:/]([^/:]+/[^/]+?)(?:\.git)?$', u)
        return 'github:' + m.group(1) if m else u
    return 'local:' + os.path.basename(root)


def redact(s, active, cap=200):
    s = re.sub(r'[\x00-\x08\x0b-\x1f\x7f]', ' ', str(s or ''))[:cap * 2]
    for r in active:
        if r['kind'] == 'ban-string' and string_match(s, r['arg']):
            s = re.sub(re.escape(r['arg']), '[redacted %s]' % h8(r['ko'].get('hash')), s, flags=re.I)
        if r['kind'] == 'ban-regex':
            try: s = re.sub(r['arg'], '[redacted %s]' % h8(r['ko'].get('hash')), s)
            except re.error: pass
    s = re.sub(r'(?m)^(\s*)(RULE|SUPERSEDES)\b', r'\1quoted-\2', s)            # an event can never read as a rule line
    return s[:cap]


def cached_active(sd):
    try: cache = json.loads((sd / 'hubcache.json').read_text())
    except Exception: return None
    return hub_rules(cache, {'require_accept': True})[0]


def guard_event(root, cfg, sd, what, **kw):
    ev = {'schema': EVENT_SCHEMA, 'event_id': ulid(), 'kind': 'guard', 'what': what, 'person': cfg.get('me'),
          'runner_id': runner_id(cfg.get('me')), 'surface': surface(), 'repo': repo_id(root), 'client_at': iso(), 'wake': False}
    act = cached_active(sd) or []
    for k, v in kw.items(): ev[k] = redact(v, act, 400) if isinstance(v, str) else v
    return ev


def enqueue(root, sd, cfg, ev, spawn=True):
    ob = sd / 'outbox'; ob.mkdir(parents=True, exist_ok=True)
    atomic_write(ob / ('%s.json' % ev['event_id']), json.dumps(ev))
    if spawn: spawn_sender(root, sd)


def spawn_sender(root, sd):
    if in_test(sd) and os.environ.get('GUARD_SYNC_SEND') == '1':
        try: send(root, sd)
        except SystemExit: pass
        return
    if in_test(sd) and os.environ.get('GUARD_NO_SEND') == '1': return
    try:
        with open(sd / 'sender.log', 'a') as lf:
            subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'send', '--root', root], cwd=root,
                             stdin=subprocess.DEVNULL, stdout=lf, stderr=lf, start_new_session=True)
    except OSError: pass


def sink_post(cfg, sd, ev):
    k = knobs(sd); sink = cfg.get('sink') or ''
    if sink.startswith('local-events:'):
        p = Path(sink.split(':', 1)[1]).expanduser()
        with open(str(p) + '.lock', 'a') as lk:
            fcntl.flock(lk, fcntl.LOCK_EX)
            try: d = json.loads(p.read_text())
            except FileNotFoundError: d = {'schema': 'sf1-local-events/1', 'label': 'LOCAL EVENT LOG (stand-in for the room)', 'events': [], 'groups': {}}
            ids = set(e['event_id'] for e in d['events'])
            if ev['event_id'] in ids and 'dedupe' not in k: return 'duplicate'
            now = time.time()
            rec = dict(ev, received_at=iso(now), received_ts=now)
            d['events'].append(rec)
            if ev.get('sha'):
                g = '%s|%s' % (ev.get('repo'), ev['sha'])
                d['groups'].setdefault(g, []).append(ev['event_id'])
            atomic_write(p, json.dumps(d, indent=1))
        return 'ok'
    if sink.startswith('hosted-events:'):
        url = sink.split(':', 1)[1]
        req = _URLREQ.Request(url, data=json.dumps(ev).encode(), method='POST', headers={
            'Authorization': 'Bearer ' + hub_token(cfg), 'Content-Type': 'application/json', 'User-Agent': UA,
            'Idempotency-Key': ev['event_id']})
        try:
            _URLREQ.urlopen(req, timeout=3).read(); return 'ok'
        except urllib.error.HTTPError as e:
            if e.code == 409: return 'duplicate'
            raise
    raise RuntimeError('no event sink configured')


def send(root, sd, reset=False):
    cfg, _ = hub_cfg(root)
    br = sd / 'breaker.json'
    if reset:
        try: br.unlink()
        except FileNotFoundError: pass
    if br.exists(): print('sender breaker is open (%s); run `guard.py send --reset` after checking the sink' % br); return 1
    with open(sd / 'send.lock', 'a') as lk:
        try: fcntl.flock(lk, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError: return 0                                  # another sender is draining; it loops until empty
        sent = sd / 'sent'; sent.mkdir(exist_ok=True)
        n = 0
        while True:
            files = sorted((sd / 'outbox').glob('*.json')) if (sd / 'outbox').exists() else []
            if not files: break
            for f in files:
                try: ev = json.loads(f.read_text())
                except Exception: f.rename(sent / (f.name + '.bad')); continue
                try: st = sink_post(cfg, sd, ev)
                except Exception as e:
                    atomic_write(br, json.dumps({'at': time.time(), 'error': '%s: %s' % (type(e).__name__, str(e)[:120]), 'event': ev['event_id']}))
                    print('sender stopped: %s (breaker open, no retry)' % type(e).__name__); return 1
                if 'die-after-sink' in knobs(sd) and os.environ.get('_GUARD_DIE_ONCE') and not (sd / '_died').exists():
                    (sd / '_died').write_text('1'); os._exit(9)
                os.replace(f, sent / f.name); n += 1
                ack = {'at': time.time(), 'event_id': ev['event_id'], 'sha': ev.get('sha'), 'status': st}
                with open(sd / 'acks.jsonl', 'a') as af: af.write(json.dumps(ack) + '\n')
        return 0


def commit_event(root, sd, cfg, sha, kind='commit', surf=None, extra=None):
    rc, out, _ = git(['show', '-s', '--format=%H%x00%P%x00%an%x00%ct%x00%s', sha], root)
    H, P, an, ct, subj = (out.rstrip('\n').split('\x00') + [''] * 5)[:5]
    _, br, _ = git(['rev-parse', '--abbrev-ref', 'HEAD'], root)
    _, names, _ = git(['diff-tree', '--no-commit-id', '--name-only', '-r', '--root', H], root)
    paths = [p for p in names.splitlines() if p]
    act = cached_active(sd)
    if act is None: summary, plist = '[no rules cached: summary withheld]', []
    else:
        summary = redact(subj, act)
        plist = []
        for p in paths[:50]:
            banned = any(r['kind'] == 'ban-path' and glob_match(p, r['arg']) for r in act)
            plist.append('[redacted path]' if banned else redact(p, act, 160))
    adm = {}
    try:
        lp = json.loads((sd / 'last_precommit.json').read_text())
        _, tree, _ = git(['rev-parse', H + '^{tree}'], root)
        if lp.get('tree') == tree.strip(): adm = lp
    except Exception: pass
    ev = {'schema': EVENT_SCHEMA, 'event_id': ulid(), 'kind': kind, 'person': cfg.get('me'), 'runner_id': runner_id(cfg.get('me')),
          'surface': surf or surface(), 'card': ((sd / 'card').read_text().strip() if (sd / 'card').exists() else ''),
          'repo': repo_id(root), 'branch': redact(br.strip(), act or [], 120), 'base_sha': (P.split() or [''])[0],
          'parents': P.split(), 'sha': H, 'git_author': redact(an, act or [], 80), 'committed_at': iso(float(ct or 0)),
          'committed_ts': float(ct or 0), 'summary': summary, 'n_files': len(paths), 'paths': plist,
          'admission_id': adm.get('admission_id'), 'rules_revision': adm.get('revision'),
          'admission_note': 'pre-commit admitted' if adm else 'NO ADMISSION RECORD (pre-commit did not run for this tree)',
          'client_at': iso(), 'wake': False}
    if extra: ev.update(extra)
    return ev


def acked_shas(cfg, sd, repo):
    sink = cfg.get('sink') or ''
    if sink.startswith('local-events:'):
        try: d = json.loads(Path(sink.split(':', 1)[1]).expanduser().read_text())
        except Exception: return set(), None
        s = set(); last = None
        for e in d['events']:
            if e.get('repo') == repo and e.get('sha') and e.get('person') == cfg.get('me'):
                s.add(e['sha']); last = max(last or '', e['received_at'])
        return s, last
    raise RuntimeError('reconcile against the hosted sink needs APP route GET /v1/rooms/<id>/events/acks')


def reconcile(root, sd, cfg):
    repo = repo_id(root)
    refs = cfg.get('refs') or [git(['rev-parse', '--abbrev-ref', 'HEAD'], root)[1].strip()]
    since = int(cfg.get('since_ts') or 0)
    shas = []
    for ref in refs:
        rc, out, _ = git(['rev-list', '--max-count=500', '--since=%d' % since, ref], root)
        if rc == 0: shas += out.split()
    acked, last = acked_shas(cfg, sd, repo)
    queued = set()
    for f in (sd / 'outbox').glob('*.json') if (sd / 'outbox').exists() else []:
        try: queued.add(json.loads(f.read_text()).get('sha'))
        except Exception: pass
    gaps = [s for s in dict.fromkeys(shas) if s not in acked and s not in queued]
    for s in gaps:
        enqueue(root, sd, cfg, commit_event(root, sd, cfg, s, surf='reconcile',
                                            extra={'reconciled': True, 'gap_note': 'missed by the post-commit hook; found by reconciliation'}), spawn=False)
    print('reconcile: refs %s, commits %d, acked %d, queued %d, gaps found %d, last ack %s' % (
        ','.join(refs), len(set(shas)), len(acked & set(shas)), len(queued), len(gaps), last or '-'))
    return gaps


# ---------------------------------------------------------------- hub evaluation (PreToolUse / PostToolUse / pre-commit)
def decision_log(sd, rec):
    rec.setdefault('ts', time.time()); rec.setdefault('schema', 'sf1-guard-decision/1')
    log(sd, rec)


def evaluate_hub(payload, root, cfg, sd, phase='pre'):
    t0 = time.time()
    k = knobs(sd)
    if 'crash' in k: raise RuntimeError('forced crash (negative control)')
    if 'glob' in k: globals()['glob_match'] = lambda p, pat: False
    if 'string' in k: globals()['string_match'] = lambda t, n: False
    if 'slow' in k: time.sleep(60)
    tool = payload.get('tool_name') or ''
    ti = payload.get('tool_input') or {}
    cwd = payload.get('cwd') or root
    me = cfg['me'] or 'unknown'
    _CFG_PATHS[:] = [os.path.realpath(os.path.expanduser(x.split(':', 1)[1])) for x in (cfg.get('source') or '', cfg.get('sink') or '')
                     if x.startswith(('hub-rules:', 'local-events:'))]
    join = {'session_id': payload.get('session_id'), 'tool_use_id': payload.get('tool_use_id'),
            'transcript_path': payload.get('transcript_path'), 'hook_event': payload.get('hook_event_name'),
            'permission_mode': payload.get('permission_mode')}
    rec = dict(join, tool=tool, me=me, phase=phase, mode='attached', source=source_label(cfg['source']))
    paths, text, git_action, layer, cls, controlled = [], '', None, '', None, False
    if tool in EDIT_TOOLS:
        fp = ti.get('file_path') or ti.get('notebook_path') or ''
        r = rel(root, fp) if fp else None
        prot = bool(fp) and is_protected(fp, root, sd)
        if r is not None or prot:
            controlled = True; layer = 'edit-hook'
            paths = [r] if r is not None else []
            text = '\n'.join([str(ti.get('content') or ''), str(ti.get('new_string') or ''), str(ti.get('new_source') or '')] +
                             [str(e.get('new_string') or '') for e in (ti.get('edits') or [])])
    elif tool == 'Bash':
        cmd = str(ti.get('command') or '')
        cls = classify_bash(cmd, cwd, root)
        if 'classifier' in k: cls = {'kinds': {'read'}, 'targets': [], 'unknown': False, 'text': cmd, 'segs': []}
        rec['bash_kinds'] = sorted(cls['kinds']); rec['bash_segs'] = cls['segs'][:12]
        inrepo = [rel(root, t) for t in cls['targets'] if rel(root, t) is not None]
        prot_t = [t for t in cls['targets'] if is_protected(t, root, sd)]
        selfmod_txt = any(rx.search(cmd) for rx, _ in SELFMOD_CMD_RES) and 'classifier' not in k
        auth_txt = any(rx.search(cmd) for rx, _, _ in AUTH_RES) and 'classifier' not in k
        if cls['kinds'] - {'read'} or prot_t or selfmod_txt or auth_txt:
            controlled = True
            if 'commit' in cls['kinds'] or 'push' in cls['kinds']: layer = 'git'
            elif inrepo: layer = 'bash-write'
            else: layer = 'bash-opaque (pre-commit is the backstop)'
            paths = inrepo
            if inrepo: text = cls['text']
            if 'commit' in cls['kinds']:
                wide = bool(re.search(r'\s-[a-zA-Z]*a|--all|git\s+add', cmd))
                p, t = staged_changes(root, include_worktree=wide); paths += p; text += '\n' + t; git_action = 'commit'
            if 'push' in cls['kinds']:
                p, t, rng = push_changes(root); paths += p; text += '\n' + t; git_action = git_action or 'push'
    if not controlled:
        rec.update(decision='allow', layer='read-only (no admission)', latency_ms=round((time.time() - t0) * 1000, 1))
        decision_log(sd, rec)
        return 0, '', ''
    rec['layer'] = layer; rec['paths'] = paths[:20]
    try:
        cache, how = admit(root, sd, cfg)
    except Suspend as e:
        rec.update(decision='block', reason='suspended', violations=['guard suspended: %s' % e],
                   latency_ms=round((time.time() - t0) * 1000, 1))
        decision_log(sd, rec)
        return 2, ('[oliver-ben guard] SUSPENDED: %s\nControlled actions (repo writes, commits, scripts) are paused until a person '
                   'checks the rule source and runs `python3 %s unstop` in their own terminal. Reads still work. '
                   'No automatic retry.' % (e, Path(__file__).resolve())), ''
    active, prose, superseded, rev = hub_rules(cache, cfg)
    gp, au = protect_rules(active, me)
    v = check_paths_and_text(active, me, paths, text, git_action)
    v += selfmod_violations(gp, tool, ti, root, sd, cls)
    if tool == 'Bash' and au: v += authority_violations(au, str(ti.get('command') or ''), me)
    aid = ulid()
    rec.update(admission_id=aid, revision=cache.get('revision'), etag=cache.get('etag'), how=how, rules_sha=rev['sha'],
               enforced=sorted(set(h8(r['ko'].get('hash')) for r in active)), decision='block' if v else 'allow', violations=v,
               matched=sorted(set(re.findall(r'KO ([0-9a-z-]{6,8})', ' '.join(v)))), latency_ms=round((time.time() - t0) * 1000, 1))
    decision_log(sd, rec)
    head = '[oliver-ben guard] rules r%s (%s, %s, %d KOs)' % (cache.get('revision'), source_label(cfg['source']), how, rev['n_kos'])
    if v:
        enqueue(root, sd, cfg, guard_event(root, cfg, sd, 'block', admission_id=aid, revision=cache.get('revision'),
                                           layer=layer, matched=rec['matched'], tool=tool))
        return 2, '\n'.join([head, 'BLOCKED by the oliver-ben rules:'] + ['  - ' + x for x in v] +
                            ['If the rule is wrong, change it in the room (a newer KO, Accepted by a person); do not work around it.']), ''
    if phase == 'pre' and payload.get('tool_use_id'):
        ad = sd / 'admits'; ad.mkdir(exist_ok=True)
        atomic_write(ad / ('%s.json' % re.sub(r'[^A-Za-z0-9_-]', '_', payload['tool_use_id'])[:80]),
                     json.dumps({'admission_id': aid, 'revision': cache.get('revision'), 'at': time.time()}))
    msg = ''
    if how == 'pulled' and prose:
        msg = '\n'.join([head] + prose_lines(prose, superseded)[:12])
    return 0, '', msg


def evaluate_post(payload, root, cfg, sd):
    """PostToolUse: if the rules changed between admission and execution, re-check and report a LATE violation."""
    tid = payload.get('tool_use_id')
    if not tid: return 0, ''
    f = sd / 'admits' / ('%s.json' % re.sub(r'[^A-Za-z0-9_-]', '_', tid)[:80])
    try: adm = json.loads(f.read_text()); f.unlink()
    except Exception: return 0, ''
    try: cache, how = admit(root, sd, dict(cfg, coalesce_s=0))
    except Suspend as e:
        return 2, '[oliver-ben guard] the rule source became unreachable while this action ran (%s); controlled actions are now suspended.' % e
    if cache.get('revision') == adm.get('revision'): return 0, ''
    code, err, _ = evaluate_hub(dict(payload, hook_event_name='PostToolUse-recheck'), root, cfg, sd, phase='post')
    if code == 2:
        enqueue(root, sd, cfg, guard_event(root, cfg, sd, 'late-violation', admitted_revision=adm.get('revision'),
                                           revision=cache.get('revision'), admission_id=adm.get('admission_id'),
                                           tool=payload.get('tool_name')))
        return 2, ('[oliver-ben guard] LATE: this action was admitted under rules r%s, but r%s landed before it ran and '
                   'forbids it. Undo it now; the pre-commit hook will refuse it anyway.\n%s' % (adm.get('revision'), cache.get('revision'), err))
    return 0, ''


def precommit_hub(root, cfg, sd):
    t0 = time.time()
    paths, added = staged_changes(root)
    me = cfg['me'] or 'unknown'
    rec = {'tool': 'pre-commit', 'me': me, 'phase': 'pre-commit', 'mode': 'attached', 'paths': paths[:20], 'layer': 'pre-commit',
           'surface': surface()}
    try: cache, how = admit(root, sd, cfg)
    except Suspend as e:
        rec.update(decision='block', reason='suspended', latency_ms=round((time.time() - t0) * 1000, 1)); decision_log(sd, rec)
        print('COMMIT REFUSED: the oliver-ben guard is SUSPENDED (%s). A person checks the source and runs `guard.py unstop`.' % e, file=sys.stderr)
        return 1
    active, prose, superseded, rev = hub_rules(cache, cfg)
    v = check_paths_and_text(active, me, paths, added, 'commit')
    aid = ulid()
    rec.update(admission_id=aid, revision=cache.get('revision'), how=how, decision='block' if v else 'allow', violations=v,
               latency_ms=round((time.time() - t0) * 1000, 1))
    decision_log(sd, rec)
    print('[oliver-ben guard pre-commit] rules r%s (%s), me %s' % (cache.get('revision'), source_label(cfg['source']), me), file=sys.stderr)
    if v:
        enqueue(root, sd, cfg, guard_event(root, cfg, sd, 'block', admission_id=aid, revision=cache.get('revision'), layer='pre-commit'))
        print('COMMIT REFUSED by the oliver-ben rules:', file=sys.stderr)
        for x in v: print('  - ' + x, file=sys.stderr)
        return 1
    _, tree, _ = git(['write-tree'], root)
    atomic_write(sd / 'last_precommit.json', json.dumps({'tree': tree.strip(), 'admission_id': aid, 'revision': cache.get('revision'), 'at': time.time()}))
    return 0


def hub_status(root, cfg, sd):
    try: cache = json.loads((sd / 'hubcache.json').read_text())
    except Exception: cache = None
    ob = len(list((sd / 'outbox').glob('*.json'))) if (sd / 'outbox').exists() else 0
    last_ack = None
    try: last_ack = iso(json.loads((sd / 'acks.jsonl').read_text().splitlines()[-1])['at'])
    except Exception: pass
    print('mode=attached me=%s source=%s [%s] sink=%s' % (cfg['me'], cfg['source'], source_label(cfg['source']), cfg.get('sink') or '-'))
    print('revision=%s etag=%s checked %ss ago; stopped=%s; breaker=%s; queued %d, last ack %s' % (
        (cache or {}).get('revision'), (cache or {}).get('etag'), round(time.time() - (cache or {}).get('checked_at', time.time()), 1),
        (sd / 'stopped.json').exists(), (sd / 'breaker.json').exists(), ob, last_ack or '-'))
    if cache:
        active, prose, superseded, rev = hub_rules(cache, cfg)
        for r in active: print('  RULE %s: %s   [%s]' % (r['kind'], r['arg'], cite(r)))
        for l in prose_lines(prose, superseded): print(l)


def evaluate_tool(payload):
    """Legacy in-process entry (2026-11-11 suite)."""
    return evaluate_tool_legacy(payload)


# ---------------------------------------------------------------- entry points
def _session(payload_cwd, attached_flag):
    root = fast_root(payload_cwd)[0] if payload_cwd and os.path.isdir(payload_cwd) else None
    if not root: return None, None, None
    cfg, sd = hub_cfg(root)
    if cfg and cfg.get('mode') == 'attached': return root, cfg, sd
    if attached_flag:                                   # hook installed as attached but config missing/changed: fail closed
        sd = sd or (Path(root) / '.git' / 'oliver-ben-guard'); sd.mkdir(parents=True, exist_ok=True)
        c = {'me': (cfg or {}).get('me', ''), 'source': '', 'sink': (cfg or {}).get('sink', ''), 'mode': 'attached',
             'coalesce_s': 1.0, 'net_timeout_s': 2.0, 'deadline_s': 8.0, 'require_accept': True}
        return root, c, sd
    return root, None, sd


def _arm_deadline(cfg):
    def _hit(signum, frame): raise DeadlineHit()
    signal.signal(signal.SIGALRM, _hit)
    signal.setitimer(signal.ITIMER_REAL, max(0.5, float(cfg.get('deadline_s', 8.0))))


def main_hook(attached_flag=False):
    try: payload = json.loads(sys.stdin.read() or '{}')
    except Exception:
        if attached_flag:
            sys.stderr.write('[oliver-ben guard] hook input unreadable: blocked (fail closed)\n'); return 2
        return 0
    try:
        root, cfg, sd = _session(payload.get('cwd') or os.getcwd(), attached_flag)
    except Exception as e:
        if attached_flag: sys.stderr.write('[oliver-ben guard] error (%s): blocked (fail closed)\n' % type(e).__name__); return 2
        root, cfg, sd = None, None, None
    if cfg is None:                                          # legacy (2026-11-11) behaviour, unchanged
        code, err, sysmsg = evaluate_tool_legacy(payload)
        if code == 2: sys.stderr.write(err + '\n'); return 2
        if sysmsg: sys.stdout.write(json.dumps({'systemMessage': sysmsg}) + '\n')
        return 0
    t0 = time.time()
    try:
        _arm_deadline(cfg)
        code, err, sysmsg = evaluate_hub(payload, root, cfg, sd)
        signal.setitimer(signal.ITIMER_REAL, 0)
    except DeadlineHit:
        decision_log(sd, {'tool': payload.get('tool_name'), 'session_id': payload.get('session_id'), 'tool_use_id': payload.get('tool_use_id'),
                          'decision': 'block', 'reason': 'deadline', 'latency_ms': round((time.time() - t0) * 1000, 1)})
        sys.stderr.write('[oliver-ben guard] check exceeded its %.1f s deadline: blocked (fail closed). Try again; if it repeats, '
                         'check the rule source.\n' % cfg.get('deadline_s', 8.0)); return 2
    except Exception as e:
        signal.setitimer(signal.ITIMER_REAL, 0)
        decision_log(sd, {'tool': payload.get('tool_name'), 'session_id': payload.get('session_id'), 'tool_use_id': payload.get('tool_use_id'),
                          'decision': 'block', 'reason': 'guard error %s' % type(e).__name__, 'latency_ms': round((time.time() - t0) * 1000, 1)})
        sys.stderr.write('[oliver-ben guard] internal error (%s: %s): blocked (fail closed)\n' % (type(e).__name__, str(e)[:160])); return 2
    if code == 2: sys.stderr.write(err + '\n'); return 2
    if sysmsg: sys.stdout.write(json.dumps({'systemMessage': sysmsg}) + '\n')
    return 0


def main_posthook(attached_flag=False):
    try: payload = json.loads(sys.stdin.read() or '{}')
    except Exception: return 0
    try:
        root, cfg, sd = _session(payload.get('cwd') or os.getcwd(), attached_flag)
        if cfg is None: return 0
        _arm_deadline(cfg)
        code, err = evaluate_post(payload, root, cfg, sd)
        signal.setitimer(signal.ITIMER_REAL, 0)
    except Exception as e:
        sys.stderr.write('[oliver-ben guard] post-check error (%s); the pre-commit hook re-checks\n' % type(e).__name__); return 0
    if code == 2: sys.stderr.write(err + '\n'); return 2
    return 0


def main_precommit(attached_flag=False):
    root = repo_root(os.getcwd())
    if not root: return 0
    root_, cfg, sd = _session(root, attached_flag)
    if cfg is not None:
        try: return precommit_hub(root, cfg, sd)
        except Exception as e:
            print('COMMIT REFUSED: guard error (%s), fail closed' % type(e).__name__, file=sys.stderr); return 1
    # legacy (2026-11-11) path
    if os.environ.get('GUARD_DISABLE') == '1': return 0
    paths, added = staged_changes(root)
    active, prose, superseded, rev, meta, cfg, sd = get_rules(root)
    me = cfg['me'] or 'unknown'
    v = check_paths_and_text(active, me, paths, added, 'commit')
    log(sd, {'ts': time.time(), 'tool': 'pre-commit', 'me': me, 'card': meta['card'], 'paths': paths[:20], 'revision': rev,
             'pulled': meta['pulled'], 'warn': meta['warn'], 'decision': 'block' if v else 'allow', 'violations': v})
    print('[oliver-ben guard pre-commit] rules rev %s, card %s, me %s' % (rev['sha'], meta['card'] or '-', me), file=sys.stderr)
    for l in prose_lines(prose, superseded): print(l, file=sys.stderr)
    if meta['warn']: print('  WARNING: ' + meta['warn'], file=sys.stderr)
    if v:
        print('COMMIT REFUSED by the oliver-ben rules:', file=sys.stderr)
        for x in v: print('  - ' + x, file=sys.stderr)
        return 1
    return 0


def main_postcommit():
    """Never blocks or fails git: writes the event to the durable outbox and spawns the sender."""
    try:
        root = repo_root(os.getcwd())
        root, cfg, sd = _session(root, False)
        if cfg is None: return 0
        enqueue(root, sd, cfg, commit_event(root, sd, cfg, 'HEAD'))
    except Exception as e:
        print('[oliver-ben guard post-commit] event not queued (%s); reconciliation will find it' % type(e).__name__, file=sys.stderr)
    return 0


def main_postrewrite(how):
    try:
        root = repo_root(os.getcwd())
        root, cfg, sd = _session(root, False)
        if cfg is None: return 0
        for line in sys.stdin.read().splitlines():
            parts = line.split()
            if len(parts) < 2: continue
            old, new = parts[0], parts[1]
            enqueue(root, sd, cfg, commit_event(root, sd, cfg, new, kind='rewrite',
                                                extra={'supersedes': old, 'rewrite': how}), spawn=False)
        spawn_sender(root, sd)
    except Exception as e:
        print('[oliver-ben guard post-rewrite] not queued (%s)' % type(e).__name__, file=sys.stderr)
    return 0


def main():
    a = sys.argv[1:]
    att = '--attached' in a
    a = [x for x in a if x != '--attached']
    if not a or a[0] == 'hook': return main_hook(att)
    if a[0] == 'posthook': return main_posthook(att)
    if a[0] == 'precommit': return main_precommit(att)
    if a[0] == 'postcommit': return main_postcommit()
    if a[0] == 'postrewrite': return main_postrewrite(a[1] if len(a) > 1 else '')
    root = None
    if '--root' in a:
        root = a[a.index('--root') + 1]; a = [x for i, x in enumerate(a) if x != '--root' and (i == 0 or a[i - 1] != '--root')]
    root = repo_root(root or os.getcwd())
    if not root: print('not in a git repo'); return 1
    hcfg, hsd = hub_cfg(root)
    if hcfg and hcfg.get('mode') == 'attached':
        sd = hsd
        if a[0] == 'send': return send(root, sd, reset='--reset' in a)
        if a[0] == 'reconcile': reconcile(root, sd, hcfg); return send(root, sd)
        if a[0] == 'observe':
            sha = git(['rev-parse', a[1]], root)[1].strip()
            surf = a[a.index('--surface') + 1] if '--surface' in a else 'fold'
            enqueue(root, sd, hcfg, commit_event(root, sd, hcfg, sha, kind='observe', surf=surf), spawn=False)
            return send(root, sd)
        if a[0] == 'status': hub_status(root, hcfg, sd); return 0
        if a[0] == 'card':
            (sd / 'card').write_text((a[1] if len(a) > 1 else '').strip()); print('card =', a[1] if len(a) > 1 else ''); return 0
        if a[0] == 'unstop':
            try: (sd / 'stopped.json').unlink(); print('stop marker cleared; the next controlled action reads the source once')
            except FileNotFoundError: print('no stop marker')
            enqueue(root, sd, hcfg, guard_event(root, hcfg, sd, 'unstopped'))
            return 0
        if a[0] == 'detach':
            c = json.loads((sd / 'config.json').read_text()); c['mode'] = 'detached'
            atomic_write(sd / 'config.json', json.dumps(c))
            enqueue(root, sd, hcfg, guard_event(root, hcfg, sd, 'detached'))
            print('detached: the guard no longer enforces here; the room has been told (event queued)'); return 0
        if a[0] == 'refresh':
            try: cache, how = admit(root, sd, dict(hcfg, coalesce_s=0)); print('revision', cache.get('revision'), how)
            except Suspend as e: print('SUSPENDED:', e); return 1
            return 0
    sd = state_dir(root)
    if a[0] == 'card':
        (sd / 'card').write_text((a[1] if len(a) > 1 else '').strip()); print('card =', a[1] if len(a) > 1 else ''); return 0
    if a[0] == 'unstop':
        try: (sd / 'stopped.json').unlink(); print('stop marker cleared')
        except FileNotFoundError: print('no stop marker')
        return 0
    if a[0] in ('status', 'refresh'):
        active, prose, superseded, rev, meta, cfg, _ = get_rules(root, force=(a[0] == 'refresh'))
        print('me=%s source=%s ttl=%ss card=%s rev=%s n=%d newest=%s cache_age=%ss %s' % (
            cfg['me'], cfg['source'], cfg['ttl_s'], meta['card'], rev['sha'], rev['n_kos'], rev['max_updated_at'],
            meta['age_s'], meta['warn']))
        for r in active: print('  RULE %s: %s   [%s]' % (r['kind'], r['arg'], cite(r)))
        for l in prose_lines(prose, superseded): print(l)
        return 0
    print(__doc__); return 1


if __name__ == '__main__':
    sys.exit(main())

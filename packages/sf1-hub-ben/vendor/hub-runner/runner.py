#!/usr/bin/env python3
"""SF-1 shared hub, phase B: Oliver's per-person card runner (2026-11-12).

Rulings: 619fbd4f (build now, live when APP's hub release lands), 8ac442c6 (CC-READ API-billed, $40/person/day),
eabf6897 (fail CLOSED), f88a2c96 (guard-protect; Oliver-only deploys and sends), 761e4b20 (binding items into Claude
Code memory), 6efa3e3d (Claude Code decides; pairs logged), b8de8412 (per-repo scope, custom-command tag).
Prereg (sealed): /Users/oz/data/sf1-reports/sf1-hub-phase-bc-oliver-1112-prereg.md, rows S1-S7 and RB1-RB11.
Design: /Users/oz/data/sf1-reports/sf1-shared-hub-path-v2-1112.md (2.2 a-k, 3.1-3.2, phase B).

One process (pidfile lock). Every 15 s, when LIVE: refresh the project rules (ETag), poll the oliver-ben room, act on
CARD / TAKE / HOLD lines, run consented cards for oliver in a fresh `git worktree` of sapience-app at the card's base
sha, post card status to the room as [SF-1] via "sf1". PRE-LIVE (the installed default): every tick makes zero
network calls and zero model calls until `golive` writes the hosted config.

Card line (first line of a room message, then the task on the following lines):
  CARD for:oliver [repo:sapience-app] base:<sha> files:<glob>[,<glob>] accept:<cmd> cites:#n,#m|none dirty:no|apply
  TAKE C-<n>     (Oliver consents to a card Ben wrote for oliver)
  HOLD C-<n>     (either member: kill the card's own recorded process group; the worktree is kept; never restarts)

Commands: install | detach | stop | unstop | status | golive | run-once | loop
Keys are read from files (mode 600) and never printed, logged or put in argv. Stdlib only.
"""
from __future__ import annotations

import argparse
import base64
import fcntl
import hashlib
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
for _c in (HERE, HERE.parent / "room-member"):
    if (_c / "room_member.py").exists():
        sys.path.insert(0, str(_c))
        break
import room_member as rm  # noqa: E402  (State, privacy_check, guard_ban_strings, Member, LABEL, VIA)

VERSION = "hub-runner-oliver/1 (2026-11-12)"
LABEL_JOB = "ai.sapience.sf1-hub-runner-oliver"
UA = "sf1-hub-runner/1"
CODE_FILES = ("runner.py", "deny_hook.py")          # + room_member.py from the room member build
LIMIT_RX = re.compile(r"(hit your (weekly |session |usage |5-hour |daily )?limit|usage limit reached|"
                      r"limit\s*[·.-]\s*resets|out of extra usage|rate_limit_error)", re.I)
CARD_RX = re.compile(r"^CARD\s+for:(?P<for>\S+)(?:\s+repo:(?P<repo>\S+))?\s+base:(?P<base>\S+)\s+files:(?P<files>\S+)"
                     r"\s+accept:(?P<accept>.+?)\s+cites:(?P<cites>\S+)\s+dirty:(?P<dirty>\S+)\s*$")
TAKE_RX = re.compile(r"^TAKE\s+C-(\d+)\b")
HOLD_RX = re.compile(r"^HOLD\s+C-(\d+)\b")
SUP_RX = re.compile(r"SUPERSEDES\s+((?:[0-9A-Za-z-]{4,}\s*)+)")
RULE_LINE_RX = re.compile(r"^\s*RULE\b", re.M)
AGENT_RX = re.compile(r"^\s*(claude|sf-?1|cc\b|bot|agent|sapience|assistant|astra|fable|codex|gpt)", re.I)
ACTIVE = ("QUEUED", "WAITING_TAKE", "RUNNING", "ACCEPTING")
KEY_ENV_DROP = ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "OPENROUTER_API_KEY", "OPENAI_API_KEY",
                "SF1_HUB_KEY", "CLAUDE_CODE_OAUTH_TOKEN_FILE")
POINTER = ("- [Hub rulings (oliver-ben)](hub-rulings.md) - binding items from the shared room, "
           "synced by the SF-1 hub runner")

# test-only negative-control switches (prereg NCs). Never set in production; env form honoured only with SF1_HUB_TEST=1.
NEGCTRL: set = set()


def neg(x: str) -> bool:
    if x in NEGCTRL:
        return True
    return os.environ.get("SF1_HUB_TEST") == "1" and x in os.environ.get("SF1_HUB_NEGCTRL", "").split(",")


# ---------------------------------------------------------------- paths and config
class P:
    def __init__(self, home: Optional[str] = None):
        self.hub = Path(home or os.environ.get("SF1_HUB_HOME") or Path.home() / ".sf1" / "hub")
        self.r = self.hub / "runner"
        self.cfg = self.r / "config.json"
        self.manifest = self.hub / "manifest.json"
        self.profile = self.hub / "executor-profile.json"
        self.cards = self.r / "cards.json"
        self.cards_dir = self.r / "cards"
        self.rules = self.r / "rules-cache.json"
        self.rules_doc = self.r / "rules-doc.json"
        self.contact = self.r / "last_contact"
        self.budget = self.r / "budget.jsonl"
        self.pidfile = self.r / "runner.pid"
        self.heartbeat = self.r / "heartbeat"
        self.bin = self.r / "bin"
        self.sf1_state = self.r / "sf1-arm"
        self.mem_backup = self.r / "memory-backup.json"
        self.la = Path(os.environ.get("SF1_HUB_LAUNCHAGENTS") or Path.home() / "Library" / "LaunchAgents")


def defaults(p: P) -> dict:
    return {
        "mode": "prelive", "base_url": "", "room_id": rm.DEFAULT_ROOM, "project": rm.DEFAULT_PROJECT, "me": "oliver",
        "members": ["oliver", "ben"],
        "brain_token_file": "/Users/oz/.sapience/config.json#token",
        "hub_key_file": str(p.r / "hub.key"), "hub_key_id": "",
        "repo": os.environ.get("SF1_HUB_REPO") or "/Users/oz/coretx-worktrees/sapience-app", "repo_name": "sapience-app",
        "work_dir": str(p.r / "work"),
        "claude_bin": "/opt/homebrew/bin/claude", "python": "/opt/homebrew/bin/python3",
        "guard": "/Users/oz/data/oliver-ben-guard/guard.py",
        "post_gate_file": str(p.hub / "room-thread" / "LIVE_VERIFIED.json"),
        "poll_s": 15, "stale_s": 15, "net_timeout_s": 10,
        "card_budget_usd": 2.0, "card_max_turns": 40, "card_deadline_s": 1800, "accept_timeout_s": 600,
        "pairing": True, "pair_daily_cap_usd": 40.0, "cc_read_max_usd": 1.0, "sf1_max_usd": 0.5,
        "cc_read_model": "fable",
        "anthropic_key_file": "/Users/oz/.sapience/private/anthropic.env@ANTHROPIC_API_KEY",
        "openrouter_key_file": str(Path.home() / ".sf1" / "openrouter-runs.key"),
        "sf1_base_url": "https://openrouter.ai/api/v1", "sf1_model": "anthropic/claude-sonnet-5.5",
        "memory_sync": True,
        "memory_dir": os.environ.get("SF1_HUB_MEMORY_DIR") or
        str(Path.home() / ".claude" / "projects" / "-Users-oz-coretx-worktrees-sapience-app" / "memory"),
        "memory_alarm_lines": 60,
    }


def load_cfg(p: P) -> dict:
    c = defaults(p)
    try:
        c.update(json.loads(p.cfg.read_text()))
    except Exception:
        pass
    return c


def atomic_write(path: Path, data: str, mode: Optional[int] = None):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(data)
    if mode is not None:
        os.chmod(tmp, mode)
    os.replace(tmp, path)


def sha256(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def today() -> str:
    return time.strftime("%Y-%m-%d")


# ---------------------------------------------------------------- secrets (S4)
class KeyError_(Exception):
    pass


def read_secret(spec: str) -> Optional[str]:
    """spec = <path> | <path>#<json field> | <path>@<ENV VAR in a KEY=VALUE file>. Mode must be 600 (no group/other).
    Returns None when the file or the value is absent/empty. Never logs or prints the value."""
    if not spec:
        return None
    field = var = None
    path = spec
    if "#" in path:
        path, field = path.split("#", 1)
    if "@" in path:
        path, var = path.split("@", 1)
    f = Path(path).expanduser()
    if not f.exists():
        return None
    if f.stat().st_mode & 0o077:
        raise KeyError_("key file %s is readable by group/other (mode %o); refusing" % (f, f.stat().st_mode & 0o777))
    txt = f.read_text()
    if field:
        try:
            v = json.loads(txt).get(field)
        except Exception:
            return None
        return (str(v).strip() or None) if v else None
    if var:
        for line in txt.splitlines():
            m = re.match(r"\s*(?:export\s+)?%s\s*=\s*(.*)$" % re.escape(var), line)
            if m:
                v = m.group(1).strip().strip("'\"")
                return v or None
        return None
    return txt.strip() or None


# ---------------------------------------------------------------- state
class RState(rm.State):
    def killed(self) -> Optional[str]:
        if neg("kill"):
            return None
        if os.environ.get("SF1_HUB_RUNNER_OFF") == "1":
            return "env SF1_HUB_RUNNER_OFF=1"
        if self.stop.exists():
            try:
                return "STOP: " + self.stop.read_text()[:200]
            except Exception:
                return "STOP"
        return None

    def write_log(self, **row):
        row["ts"] = time.time()
        if neg("leaky-logger") and row.get("_secret"):
            pass                                        # NC: a deliberately leaky logger keeps the secret
        else:
            row.pop("_secret", None)
        with self.log.open("a") as f:
            f.write(json.dumps(row) + "\n")


class TransportStop(Exception):
    pass


class Net:
    """The hosted app. One request per call, never a retry. 504 / 503 / client timeout -> STOP (S2), and every later
    call is refused until a human `unstop`. Other failures are returned to the caller (which fails closed)."""

    def __init__(self, cfg: dict, state: RState):
        self.cfg = cfg
        self.state = state
        self.requests = 0

    def _auth(self, kind: str) -> str:
        spec = self.cfg["hub_key_file"] if kind == "hub" else self.cfg["brain_token_file"]
        v = read_secret(spec)
        if not v:
            raise TransportStop("no %s credential at its configured path" % kind)
        return v

    def req(self, method: str, path: str, auth: str, body: Optional[dict] = None, headers: Optional[dict] = None,
            base: Optional[str] = None):
        why = self.state.killed()
        if why:
            raise TransportStop(why)
        tok = self._auth(auth)
        url = (base or self.cfg["base_url"]).rstrip("/") + path
        h = {"Authorization": "Bearer " + tok, "User-Agent": UA, "Accept": "application/json"}
        if body is not None:
            h["Content-Type"] = "application/json"
        h.update(headers or {})
        data = json.dumps(body).encode() if body is not None else None
        r = urllib.request.Request(url, data=data, method=method, headers=h)
        self.requests += 1
        t0 = time.time()
        row = {"event": "net", "m": method, "p": path, "auth": auth}
        if neg("leaky-logger"):
            row["_secret"] = tok
            row["auth_header"] = tok                      # NC only
        try:
            with urllib.request.urlopen(r, timeout=float(self.cfg["net_timeout_s"])) as resp:
                raw = resp.read()
                st, hd = resp.status, dict(resp.headers)
        except urllib.error.HTTPError as e:
            st, hd = e.code, dict(e.headers or {})
            raw = e.read() if hasattr(e, "read") else b""
            if st in (503, 504) and not neg("stoprule"):
                self.state.set_stop("hosted %s on %s %s (one request, no retry)" % (st, method, path))
                self.state.write_log(**row, status=st, ms=int((time.time() - t0) * 1000))
                raise TransportStop("hosted %s" % st)
        except (TimeoutError, socket.timeout) as e:
            if not neg("stoprule"):
                self.state.set_stop("client timeout on %s %s (%s)" % (method, path, type(e).__name__))
            self.state.write_log(**row, status="timeout", ms=int((time.time() - t0) * 1000))
            raise TransportStop("timeout")
        except urllib.error.URLError as e:
            if isinstance(getattr(e, "reason", None), (TimeoutError, socket.timeout)):
                if not neg("stoprule"):
                    self.state.set_stop("client timeout on %s %s" % (method, path))
                self.state.write_log(**row, status="timeout", ms=int((time.time() - t0) * 1000))
                raise TransportStop("timeout")
            self.state.write_log(**row, status="conn-error", err=type(e.reason).__name__ if e.reason else "URLError",
                                 ms=int((time.time() - t0) * 1000))
            return 0, {}, {"error": "connection error"}
        self.state.write_log(**row, status=st, ms=int((time.time() - t0) * 1000))
        try:
            d = json.loads(raw or b"{}")
        except Exception:
            d = {"error": "non-JSON body"}
        return st, hd, d


class HubRoom:
    """Room transport for room_member.Member: GET the room with Oliver's brain token (a hub key gets 401 on the real
    room GET); POST as SF-1 with the hub key, {"via":"sf1","body","rid"}."""

    def __init__(self, runner: "Runner"):
        self.R = runner

    def get_messages(self, since: int = 0) -> list:
        st, _, d = self.R.net.req("GET", "/v1/rooms/%s" % self.R.cfg["room_id"], "brain")
        if st != 200:
            raise RoomError("room GET returned %s" % st)
        return [m for m in d.get("messages", []) if int(m.get("n", 0)) > since]

    def post_message(self, body: str, rid: str) -> dict:
        if not body.startswith(rm.LABEL) and not neg("label"):
            raise ValueError("unlabeled SF-1 body refused")
        try:
            st, _, d = self.R.net.req("POST", "/v1/rooms/%s/messages" % self.R.cfg["room_id"], "hub",
                                      {"body": body, "via": rm.VIA, "rid": rid})
        except TransportStop as e:
            raise rm.TransportStop(str(e))
        if st not in (200, 201):
            raise rm.TransportStop("post returned %s" % st)
        return d.get("message", {})


class RoomError(Exception):
    pass


# ---------------------------------------------------------------- globs (same semantics as the guard's, copied read-only)
def glob_to_regex(pat):
    pat = pat.strip()
    anchored = "/" in pat.rstrip("/")
    pat = pat.lstrip("/")
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"; i += 3
        elif pat.startswith("**", i):
            out += ".*"; i += 2
        elif pat[i] == "*":
            out += "[^/]*"; i += 1
        elif pat[i] == "?":
            out += "[^/]"; i += 1
        else:
            out += re.escape(pat[i]); i += 1
    if pat.endswith("/"):
        out += ".*"
    return ("^" if anchored else "^(?:.*/)?") + out + "$"


def glob_match(path, pat):
    p = path.replace(os.sep, "/")
    if p.startswith("./"):
        p = p[2:]
    return re.match(glob_to_regex(pat), p) is not None


def git(args, cwd, check=False):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    p = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, env=env)
    if check and p.returncode != 0:
        raise RuntimeError("git %s: rc=%s %s" % (args[0], p.returncode, p.stderr.strip()[:200]))
    return p.returncode, p.stdout, p.stderr


# ---------------------------------------------------------------- card parsing (RB1)
def parse_card(body: str, cfg: dict):
    """-> (card dict, None) or (None, reason). The first line is the CARD line; the task is the rest."""
    lines = body.strip().splitlines()
    first = lines[0].strip() if lines else ""
    task = "\n".join(lines[1:]).strip()
    if neg("parser"):
        m = CARD_RX.match(first)
        g = m.groupdict() if m else {}
        return {"for": g.get("for") or cfg["me"], "repo": g.get("repo"), "base": g.get("base") or "HEAD",
                "files": [g.get("files") or "**"], "accept": g.get("accept") or "true", "cites": [],
                "dirty": g.get("dirty") or "no", "task": task or first}, None
    m = CARD_RX.match(first)
    if not m:
        return None, "the CARD line does not match the format"
    g = m.groupdict()
    if g["for"].lower() not in [x.lower() for x in cfg["members"]]:
        return None, "for:%s is not a member of the room" % g["for"]
    if not re.fullmatch(r"[0-9a-f]{7,40}", g["base"]):
        return None, "base must be a commit sha (7-40 hex)"
    if g["dirty"] not in ("no", "apply"):
        return None, "dirty must be no or apply"
    files = [f for f in g["files"].split(",") if f]
    for f in files:
        if f.startswith(("/", "~")) or ".." in f.split("/"):
            if not neg("scope"):
                return None, "files:%s points outside the repo" % f
    if g["cites"] in ("none", "-"):
        cites = []
    elif re.fullmatch(r"#\d+(,#\d+)*", g["cites"]):
        cites = [int(x[1:]) for x in g["cites"].split(",")]
    else:
        return None, "cites must be #n,#m or none"
    if not task:
        return None, "the task text is empty (put it on the lines after the CARD line)"
    if g["repo"] and g["repo"] != cfg["repo_name"] and not neg("scope"):
        return None, "repo:%s is not this runner's repo (only %s)" % (g["repo"], cfg["repo_name"])
    if re.search(r"(^|\s)(/|~)", g["accept"]) and not neg("scope"):
        return None, "the accept command names a path outside the worktree"
    import deny_hook  # same module the executor profile loads
    v = deny_hook.verdict({"tool_name": "Bash", "tool_input": {"command": g["accept"]}})
    if v and not neg("deny"):
        return None, "the accept command is an irreversible action (%s); that is Oliver's" % v[0]
    return {"for": g["for"].lower(), "repo": g["repo"] or cfg["repo_name"], "base": g["base"], "files": files,
            "accept": g["accept"], "cites": cites, "dirty": g["dirty"], "task": task}, None


# ---------------------------------------------------------------- memory sync (RB10)
def _h8(k):
    return str(k.get("hash") or "")[:8]


def binding_items(doc: dict, members: list) -> list:
    """Binding items of the rules doc (rulings, constraints, decisions, file ownership), accepted, not superseded.
    A KO carrying RULE / SUPERSEDES lines binds only after a human member's Accept (as in the guard)."""
    kos = doc.get("kos") or []
    ok = []
    for k in kos:
        if str(k.get("type") or "").lower() not in ("constraint", "decision", "ruling", "ownership"):
            continue
        text = str(k.get("object") or k.get("object_value") or "")
        if RULE_LINE_RX.search(text) or SUP_RX.search(text):
            acc = str(k.get("accepted_by") or "").strip()
            if not (acc and not AGENT_RX.match(acc) and acc.lower().split()[0] in members):
                continue
        ok.append(k)
    superseded = {}
    for k in ok:
        for m in SUP_RX.finditer(str(k.get("object") or "")):
            for h in m.group(1).split():
                superseded[h[:8]] = _h8(k)
    return ok, superseded


def item_line(k: dict) -> str:
    text = str(k.get("object") or k.get("object_value") or "")
    text = " ".join(l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith("SUPERSEDES"))
    subj = str(k.get("subject") or "").strip()
    if subj and not text.lower().startswith(subj.lower()):
        text = "%s: %s" % (subj, text)
    if len(text) > 300:
        text = text[:297] + "..."
    ts = k.get("updated_at") or k.get("accepted_at") or k.get("created_at")
    try:
        date = time.strftime("%Y-%m-%d", time.gmtime(float(ts)))
    except Exception:
        date = str(ts or "")[:10] or "undated"
    author = str(k.get("author") or k.get("accepted_by") or "unknown").split()[0].lower()
    return "- %s [KO %s] (%s, %s)" % (text.replace("\n", " "), _h8(k), author, date)


KO_IN_LINE = re.compile(r"\[KO ([0-9A-Za-z-]{4,8})\]")


def sync_memory(doc: dict, memory_dir: Path, members: list, p: P, revision=None) -> dict:
    """One file hub-rulings.md + one MEMORY.md pointer line. Superseded lines are rewritten in place; never a room
    turn's text (the only input is the rules doc). Records what it creates for detach."""
    memory_dir = Path(memory_dir).expanduser()
    items, superseded = binding_items(doc, members)
    if neg("supersession"):
        superseded = {}
    active = {_h8(k): k for k in items if _h8(k) not in superseded and not k.get("invalid_at")}
    f = memory_dir / "hub-rulings.md"
    old_order = []
    if f.exists():
        for line in f.read_text().splitlines():
            m = KO_IN_LINE.search(line)
            if m:
                old_order.append(m.group(1))
    order, placed = [], set()
    for h in old_order:
        if h in active and h not in placed:
            order.append(h); placed.add(h)
        elif h in superseded and superseded[h] in active and superseded[h] not in placed:
            order.append(superseded[h]); placed.add(superseded[h])          # rewritten in place
    for k in items:
        h = _h8(k)
        if h in active and h not in placed:
            order.append(h); placed.add(h)
    if neg("supersession"):
        order = old_order + [h for h in order if h not in old_order]        # NC: no in-place rewrite
    lines = ["# Hub rulings (oliver-ben)", "",
             "Binding items from the shared oliver-ben room (rulings, constraints, decisions, file ownership). "
             "Written by the SF-1 hub runner from the project rules at revision %s; do not edit by hand, changes go "
             "through the room." % revision, ""]
    for h in order:
        k = active.get(h)
        if k is None:
            for kk in items:
                if _h8(kk) == h:
                    k = kk
        if k is not None:
            lines.append(item_line(k))
    created = []
    if not memory_dir.exists():
        memory_dir.mkdir(parents=True)
        created.append(str(memory_dir))
    if not f.exists():
        created.append(str(f))
    atomic_write(f, "\n".join(lines) + "\n")
    # MEMORY.md pointer: backed up before the first touch, one line inserted, never a rewrite of other lines
    mm = memory_dir / "MEMORY.md"
    if not p.mem_backup.exists():
        bk = {"memory_md_existed": mm.exists(), "memory_dir_existed": str(memory_dir) not in created,
              "rulings_existed": str(f) not in created, "at": time.time(),
              "memory_md_b64": base64.b64encode(mm.read_bytes()).decode() if mm.exists() else None}
        atomic_write(p.mem_backup, json.dumps(bk))
    cur = mm.read_text() if mm.exists() else ""
    pointer_added = False
    if "(hub-rulings.md)" not in cur:
        if not mm.exists():
            created.append(str(mm))
        sep = "" if (not cur or cur.endswith("\n")) else "\n"
        atomic_write(mm, cur + sep + POINTER + "\n")
        pointer_added = True
    n = len([l for l in lines if KO_IN_LINE.search(l)])
    return {"lines": n, "created": created, "pointer_added": pointer_added,
            "replaced": [h for h in old_order if h in superseded], "alarm": n > 60}


def unsync_memory(memory_dir: Path, p: P) -> list:
    """Detach: remove hub-rulings.md and restore MEMORY.md byte-for-byte from the backup taken before the first touch."""
    memory_dir = Path(memory_dir).expanduser()
    done = []
    try:
        bk = json.loads(p.mem_backup.read_text())
    except Exception:
        return done
    f = memory_dir / "hub-rulings.md"
    if f.exists() and not bk.get("rulings_existed"):
        f.unlink(); done.append("removed " + str(f))
    mm = memory_dir / "MEMORY.md"
    if bk.get("memory_md_existed"):
        atomic_write(mm, base64.b64decode(bk["memory_md_b64"]).decode())
        done.append("restored " + str(mm))
    elif mm.exists():
        mm.unlink(); done.append("removed " + str(mm))
    if not bk.get("memory_dir_existed") and memory_dir.exists() and not any(memory_dir.iterdir()):
        memory_dir.rmdir(); done.append("removed " + str(memory_dir))
    p.mem_backup.unlink()
    return done


# ---------------------------------------------------------------- processes (S7)
def ps_lstart(pid: int) -> Optional[str]:
    p = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True)
    return p.stdout.strip() or None


def group_alive(pgid: int) -> bool:
    p = subprocess.run(["ps", "-o", "stat=", "-g", str(pgid)], capture_output=True, text=True)
    return any(s.strip() and not s.strip().startswith("Z") for s in p.stdout.splitlines())


def spawn(argv, cwd, env, out_path=None, err_path=None) -> dict:
    out = open(out_path, "ab") if out_path else subprocess.DEVNULL
    err = open(err_path, "ab") if err_path else subprocess.DEVNULL
    pr = subprocess.Popen(argv, cwd=cwd, env=env, stdout=out, stderr=err, stdin=subprocess.DEVNULL,
                          start_new_session=True)
    rec = {"pid": pr.pid, "pgid": os.getpgid(pr.pid), "lstart": ps_lstart(pr.pid), "started": time.time()}
    return rec, pr


def kill_recorded(rec: dict, log=None) -> dict:
    """Kill only a process group this runner recorded when it spawned it (pid == pgid, same start time)."""
    pid, pgid = int(rec.get("pid") or 0), int(rec.get("pgid") or 0)
    t0 = time.time()
    if not pid or not pgid:
        return {"killed": False, "why": "nothing recorded"}
    if not group_alive(pgid):
        return {"killed": False, "why": "already gone", "ms": 0}
    if not neg("lstart") and (pgid != pid or ps_lstart(pid) != rec.get("lstart")):
        if log:
            log(event="kill-refused", pid=pid, why="pid/pgid not the one recorded at spawn (reused?)")
        return {"killed": False, "why": "not the recorded process (start time differs)"}
    try:
        os.killpg(pgid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except PermissionError:
        # macOS answers EPERM when the group is exiting (only a zombie leader left): re-check before reporting
        time.sleep(0.2)
        if not group_alive(pgid):
            return {"killed": False, "why": "exited during the kill", "ms": int((time.time() - t0) * 1000)}
        if log:
            log(event="kill-eperm", pid=pid)
        return {"killed": False, "why": "EPERM on a live group", "alive_after": True}
    for _ in range(30):
        if not group_alive(pgid):
            break
        time.sleep(0.1)
    if group_alive(pgid):
        try:
            os.killpg(pgid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        for _ in range(20):
            if not group_alive(pgid):
                break
            time.sleep(0.1)
    return {"killed": True, "ms": int((time.time() - t0) * 1000), "alive_after": group_alive(pgid)}


# ---------------------------------------------------------------- executor profile (RB4, RB5)
DENY_PERMS = ["Bash(git push:*)", "Bash(git -C * push:*)", "Bash(gh:*)", "Bash(vercel:*)", "Bash(npx vercel:*)",
              "Bash(flyctl deploy:*)", "Bash(fly deploy:*)", "Bash(twine upload:*)", "Bash(npm publish:*)",
              "Bash(docker push:*)", "Bash(osascript:*)", "Bash(*deploy*.sh:*)", "Bash(*/release.sh:*)"]


def executor_profile(cfg: dict, p: P, hook_on=True, deny_on=True) -> dict:
    py = cfg["python"]
    pre = []
    if deny_on:     # first, so an irreversible action is always reported as "waiting for Oliver"
        pre.append({"type": "command", "command": "%s %s || exit 2" % (py, p.bin / "deny_hook.py"), "timeout": 10})
    if hook_on:
        pre.append({"type": "command", "command": "%s %s hook --attached || exit 2" % (py, cfg["guard"]), "timeout": 30})
    prof = {"_sf1_hub": "card executor profile, written by %s; loaded only by `claude -p --settings` for hub cards. "
                        "Guard hook ON (guard-protect: the guard lives outside every task-writable path); irreversible "
                        "actions denied (Oliver-only)." % VERSION,
            "hooks": {}, "permissions": {"deny": list(DENY_PERMS) if deny_on else []}}
    if pre:
        prof["hooks"]["PreToolUse"] = [{"matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__.*", "hooks": pre}]
    if hook_on:
        prof["hooks"]["PostToolUse"] = [{"matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash", "hooks": [
            {"type": "command", "command": "%s %s posthook --attached" % (py, cfg["guard"]), "timeout": 30}]}]
    return prof


def child_env(extra: Optional[dict] = None) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in KEY_ENV_DROP and not k.startswith("SF1_HUB_NEG")}
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + str(Path.home() / ".local" / "bin")
    env.update(extra or {})
    return env


# ---------------------------------------------------------------- pairing (RB9, S6)
PLAN_SYS = ("You are planning a hub card for Oliver's sapience-app checkout. You can only read files (Read, Grep, "
            "Glob). Do not try to write, run commands or send anything. Reply with a short numbered plan: which "
            "files you would change and how, and how the acceptance command will pass. End with one line "
            "'ACTION: <one sentence>'.")


class Pairer:
    def __init__(self, R: "Runner"):
        self.R = R

    def spent_today(self) -> float:
        s = 0.0
        try:
            for line in self.R.p.budget.read_text().splitlines():
                r = json.loads(line)
                if r.get("date") == today():
                    s += float(r.get("usd") or 0)
        except FileNotFoundError:
            pass
        return s

    def _book(self, arm, cid, usd, kind):
        with self.R.p.budget.open("a") as f:
            f.write(json.dumps({"date": today(), "ts": time.time(), "arm": arm, "card": cid, "usd": round(usd, 6),
                                "kind": kind}) + "\n")

    def cap_ok(self, need: float) -> bool:
        if neg("cap"):
            return True
        return self.spent_today() + need <= float(self.R.cfg["pair_daily_cap_usd"]) + 1e-9

    def sealed(self, cid, card, wt, msgs_by_n, rules_cache) -> tuple:
        cfg = self.R.cfg
        cited = [{"n": n, "by": msgs_by_n.get(n, {}).get("by"), "body": msgs_by_n.get(n, {}).get("body", "")}
                 for n in card["cites"]]
        doc = (rules_cache or {}).get("doc") or {}
        items, sup = binding_items(doc, cfg["members"])
        rules_txt = "\n".join(item_line(k) for k in items if _h8(k) not in sup)
        files = {}
        for name, fp in (("CLAUDE.md", Path(wt) / "CLAUDE.md"), ("MEMORY.md", Path(wt) / "MEMORY.md"),
                         ("memory/hub-rulings.md", Path(cfg["memory_dir"]).expanduser() / "hub-rulings.md"),
                         ("memory/MEMORY.md", Path(cfg["memory_dir"]).expanduser() / "MEMORY.md")):
            if fp.exists():
                files[name] = fp.read_bytes()
        dirty_hash = card.get("dirty_hash")
        prompt = ("Card %s for %s (asked by %s), repo %s, base %s, files %s, accept: %s\n\nTask:\n%s\n\n"
                  "Cited room turns:\n%s\n\nRules and decisions in force at revision %s:\n%s\n\n"
                  "Project files:\n%s" % (
                      cid, card["for"], card["author"], card["repo"], card["base"], ",".join(card["files"]),
                      card["accept"], card["task"],
                      "\n".join("#%s %s: %s" % (c["n"], c["by"], c["body"][:2000]) for c in cited) or "(none)",
                      (rules_cache or {}).get("revision"), rules_txt or "(none)",
                      "\n\n".join("== %s ==\n%s" % (k, v.decode("utf-8", "replace")[:20000]) for k, v in files.items())
                      or "(none)"))
        fields = {"prompt_sha": sha256(prompt.encode()), "sealed_turn_ids": card["cites"],
                  "rules_revision": (rules_cache or {}).get("revision"), "base": card["base"],
                  "dirty_hash": dirty_hash, "store_cursor": None,
                  "project_files": {k: sha256(v) for k, v in files.items()},
                  "sf1_memory_block": None, "cc_mcp_tools": []}
        return prompt, fields, sha256(json.dumps(fields, sort_keys=True).encode())[:16]

    def cc_read(self, prompt, wt, cid) -> dict:
        cfg = self.R.cfg
        try:
            key = read_secret(cfg["anthropic_key_file"])
        except KeyError_ as e:
            key = None
            self.R.state.write_log(event="cc-read-off", why=str(e))
        if not key:
            self.R.state.write_log(event="cc-read-off", card=cid,
                                   why="no Anthropic API key in %s; never plan-billed instead" %
                                       cfg["anthropic_key_file"].split("@")[0])
            return {"ok": False, "availability": "off: no API key", "text": "", "cost": 0.0, "ms": 0, "model": None}
        need = float(cfg["cc_read_max_usd"])
        if not self.cap_ok(need):
            return {"ok": False, "availability": "dropped", "dropped": "cap", "text": "", "cost": 0.0, "ms": 0,
                    "model": None}
        argv = [cfg["claude_bin"], "--bare", "-p", prompt, "--output-format", "json", "--tools", "Read,Grep,Glob",
                "--allowedTools", "Read,Grep,Glob",
                "--disallowedTools", "Bash,Edit,Write,NotebookEdit,WebFetch,WebSearch,Agent,Task",
                "--permission-mode", "dontAsk", "--append-system-prompt", PLAN_SYS,
                "--max-budget-usd", str(need), "--model", cfg["cc_read_model"], "--no-session-persistence"]
        env = {k: os.environ[k] for k in ("HOME", "USER", "LOGNAME", "LANG", "TMPDIR", "SHELL", "TZ") if k in os.environ}
        env["PATH"] = child_env()["PATH"]
        env["ANTHROPIC_API_KEY"] = key                     # child env only (S6); never argv, never logged
        for k in ("SF1_STUB_LOG", "SF1_STUB_COST"):
            if k in os.environ:
                env[k] = os.environ[k]
        d = Path(self.R.p.cards_dir / cid)
        d.mkdir(parents=True, exist_ok=True)
        t0 = time.time()
        rec, pr = spawn(argv, wt, env, d / "cc-read.json", d / "cc-read.err")
        try:
            pr.wait(timeout=300)
        except subprocess.TimeoutExpired:
            kill_recorded(rec)
            return {"ok": False, "availability": "timeout", "text": "", "cost": 0.0,
                    "ms": int((time.time() - t0) * 1000), "model": None}
        try:
            out = json.loads((d / "cc-read.json").read_text().strip().splitlines()[-1])
        except Exception:
            out = {}
        cost = float(out.get("total_cost_usd") or 0)
        self._book("cc-read", cid, cost, "api")
        models = sorted((out.get("modelUsage") or {}).keys())
        return {"ok": bool(out.get("result")) and not out.get("is_error"), "availability": "answered" if out else
                "error", "text": str(out.get("result") or ""), "cost": cost, "ms": int((time.time() - t0) * 1000),
                "model": models[0] if models else None, "models": models}

    def _sf1_tool(self, wt, name, args):
        root = os.path.realpath(wt)

        def inside(rel):
            ap = os.path.realpath(os.path.join(root, rel or "."))
            return ap if (ap == root or ap.startswith(root + os.sep)) else None
        if name == "read_file":
            ap = inside(args.get("path", ""))
            if not ap or not os.path.isfile(ap):
                return "not a file inside the worktree"
            lines = open(ap, errors="replace").read().splitlines()
            o = int(args.get("offset") or 0)
            return "\n".join(lines[o:o + int(args.get("limit") or 200)])[:20000]
        if name == "grep":
            ap = inside(args.get("path", ""))
            if not ap:
                return "path outside the worktree"
            pr = subprocess.run(["grep", "-rn", "-I", "-m", "50", "-e", str(args.get("pattern", "")), ap],
                                capture_output=True, text=True, timeout=30)
            return pr.stdout.replace(root + "/", "")[:20000] or "(no matches)"
        if name == "glob":
            import glob as _g
            hits = _g.glob(os.path.join(root, str(args.get("pattern", "*"))), recursive=True)
            return "\n".join(h.replace(root + "/", "") for h in hits[:200]) or "(no matches)"
        return "unknown tool"

    def sf1(self, prompt, wt, cid) -> dict:
        cfg = self.R.cfg
        try:
            key = read_secret(cfg["openrouter_key_file"])
        except KeyError_ as e:
            key = None
        if not key:
            return {"ok": False, "availability": "off: no OpenRouter key", "text": "", "cost": 0.0, "ms": 0,
                    "model": None}
        need = float(cfg["sf1_max_usd"])
        if not self.cap_ok(need):
            return {"ok": False, "availability": "dropped", "dropped": "cap", "text": "", "cost": 0.0, "ms": 0,
                    "model": None}
        tools = [{"type": "function", "function": {"name": n, "description": d, "parameters": {
            "type": "object", "properties": pr, "required": rq}}} for n, d, pr, rq in (
            ("read_file", "Read a file in the worktree", {"path": {"type": "string"}, "offset": {"type": "integer"},
                                                          "limit": {"type": "integer"}}, ["path"]),
            ("grep", "Search file contents in the worktree", {"pattern": {"type": "string"},
                                                              "path": {"type": "string"}}, ["pattern"]),
            ("glob", "List files matching a glob in the worktree", {"pattern": {"type": "string"}}, ["pattern"]))]
        msgs = [{"role": "system", "content": PLAN_SYS}, {"role": "user", "content": prompt}]
        cost, models, t0 = 0.0, [], time.time()
        sd = self.R.p.sf1_state / cid
        sd.mkdir(parents=True, exist_ok=True)
        text = ""
        try:
            for _round in range(8):
                body = {"model": cfg["sf1_model"], "messages": msgs, "tools": tools, "max_tokens": 1500,
                        "usage": {"include": True}}
                rq = urllib.request.Request(cfg["sf1_base_url"].rstrip("/") + "/chat/completions",
                                            data=json.dumps(body).encode(), method="POST",
                                            headers={"Authorization": "Bearer " + key,
                                                     "Content-Type": "application/json", "User-Agent": UA})
                with urllib.request.urlopen(rq, timeout=120) as r:
                    out = json.loads(r.read())
                models.append(out.get("model"))
                cost += float((out.get("usage") or {}).get("cost") or 0)
                msg = (out.get("choices") or [{}])[0].get("message") or {}
                with (sd / "transcript.jsonl").open("a") as f:
                    f.write(json.dumps({"round": _round, "model": out.get("model"), "msg": msg}) + "\n")
                calls = msg.get("tool_calls") or []
                if not calls or cost >= need:
                    text = str(msg.get("content") or "")
                    break
                msgs.append({"role": "assistant", "content": msg.get("content") or "", "tool_calls": calls})
                for c in calls:
                    try:
                        a = json.loads(c["function"].get("arguments") or "{}")
                    except Exception:
                        a = {}
                    msgs.append({"role": "tool", "tool_call_id": c.get("id"),
                                 "content": self._sf1_tool(wt, c["function"]["name"], a)})
        except Exception as e:
            self._book("sf1", cid, cost, "api")
            return {"ok": False, "availability": "error: %s" % type(e).__name__, "text": text, "cost": cost,
                    "ms": int((time.time() - t0) * 1000), "model": models[-1] if models else None}
        self._book("sf1", cid, cost, "api")
        return {"ok": bool(text.strip()), "availability": "answered", "text": text, "cost": cost,
                "ms": int((time.time() - t0) * 1000), "model": models[-1] if models else None,
                "models": sorted(set(m for m in models if m))}

    def run(self, cid, card, wt, msgs_by_n, rules_cache) -> tuple:
        prompt, fields, ih = self.sealed(cid, card, wt, msgs_by_n, rules_cache)
        sf1_prompt = prompt + ("\n(extra context only SF-1 sees)" if neg("pairhash") else "")
        sf1_ih = ih if sf1_prompt == prompt else sha256(json.dumps(dict(fields, prompt_sha=sha256(sf1_prompt.encode())),
                                                                   sort_keys=True).encode())[:16]
        res = {}
        th = [threading.Thread(target=lambda: res.__setitem__("cc", self.cc_read(prompt, wt, cid))),
              threading.Thread(target=lambda: res.__setitem__("sf1", self.sf1(sf1_prompt, wt, cid)))]
        for t in th:
            t.start()
        for t in th:
            t.join()
        cc, s1 = res["cc"], res["sf1"]
        cc["input_hash"], s1["input_hash"] = ih, sf1_ih
        for a in (cc, s1):
            a["proposed_action"] = next((l[7:].strip() for l in a.get("text", "").splitlines()
                                         if l.startswith("ACTION:")), None)
        invalid = []
        if not cc["ok"]:
            invalid.append("cc-read " + str(cc.get("availability")))
        if not s1["ok"]:
            invalid.append("sf1 " + str(s1.get("availability")))
        if cc["input_hash"] != s1["input_hash"]:
            invalid.append("input hash differs")
        if cc["ok"] and not cc.get("model"):
            invalid.append("cc-read model id not read")
        if s1["ok"] and not s1.get("model"):
            invalid.append("sf1 model id not read")
        dropped = cc.get("dropped") or s1.get("dropped")
        row = {"schema": "sf1-hub-pair/1", "pair_id": "%s-%s" % (cid, int(time.time())), "turn_id": card["n"],
               "person": card["author"], "surface": "card-plan", "task_id": cid, "turn_type": "T4",
               "input_hash": ih, "input_fields": fields, "sf1": s1, "cc_read": cc,
               "decider_used": "cc-read" if cc["ok"] else "executor (no CC-READ plan)",
               "asker_click": None, "blinding": "none (card plans are not blinded)", "judge": None,
               "second_judge": None, "corrected_later": None, "card_acceptance": None, "counterfactual": None,
               "availability": {"cc_read": cc.get("availability"), "sf1": s1.get("availability")},
               "dropped": dropped, "custom_command": card["task"].lstrip().startswith("/"), "repo": card["repo"],
               "pair_valid": not invalid, "invalid_reasons": invalid, "stratum": VERSION, "ts": time.time()}
        with self.R.state.pairs.open("a") as f:
            f.write(json.dumps(row) + "\n")
        return (cc["text"] if cc["ok"] else None), row


# ---------------------------------------------------------------- the runner
class Runner:
    def __init__(self, home: Optional[str] = None):
        self.p = P(home)
        self.p.r.mkdir(parents=True, exist_ok=True)
        self.cfg = load_cfg(self.p)
        self.state = RState(self.p.r)
        self.net = Net(self.cfg, self.state)
        self.room = HubRoom(self)
        self.member = rm.Member(room=self.room, state=self.state,
                                limits=rm.Limits(posts_per_hour=40, posts_per_day=300, answers_per_person_10min=99),
                                rules_file=self.p.rules_doc)
        self.procs: dict = {}
        self.msgs_by_n: dict = {}
        self.pairer = Pairer(self)
        self.model_calls = 0

    # ---- persistence
    def cards(self) -> dict:
        try:
            return json.loads(self.p.cards.read_text())
        except Exception:
            return {}

    def save_cards(self, c: dict):
        atomic_write(self.p.cards, json.dumps(c, indent=1))

    def log(self, **row):
        self.state.write_log(**row)

    # ---- posting (S3)
    def posting_enabled(self) -> bool:
        if self.cfg.get("mode") != "live":
            return False
        return live_verified(self.cfg)[0]

    def say(self, text: str, source: str) -> dict:
        if not self.posting_enabled():
            self.log(event="post-suppressed", source=source, why="room posting disabled until %s exists" %
                     self.cfg["post_gate_file"])
            return {"posted": False, "reason": "posting disabled"}
        try:
            return self.member.post(text, "status", source)
        except Exception as e:
            self.log(event="post-failed", source=source, err=type(e).__name__)
            return {"posted": False, "reason": type(e).__name__}

    # ---- rules (RB7)
    def refresh_rules(self) -> bool:
        try:
            cache = json.loads(self.p.rules.read_text())
        except Exception:
            cache = None
        hdr = {"If-None-Match": cache["etag"]} if cache and cache.get("etag") else {}
        try:
            st, hd, d = self.net.req("GET", "/v1/projects/%s/rules" % self.cfg["project"], "hub", headers=hdr)
        except TransportStop as e:
            self._suspend("rules route: %s" % e)
            return False
        now = time.time()
        if st == 304 and cache:
            atomic_write(self.p.contact, str(now))
            self._unsuspend()
            return False
        if st != 200:
            self._suspend("rules route returned %s" % st)
            return False
        if d.get("schema") != "sf1-hub-rules/1" or not isinstance(d.get("revision"), int) or \
                self.cfg["me"] not in [str(m).lower() for m in d.get("members") or []]:
            self._suspend("rules doc has the wrong schema or %s is not a member" % self.cfg["me"])
            return False
        etag = hd.get("ETag") or hd.get("Etag") or hd.get("etag")
        changed = not cache or cache.get("revision") != d["revision"]
        atomic_write(self.p.rules, json.dumps({"etag": etag, "revision": d["revision"], "doc": d, "checked_at": now}))
        atomic_write(self.p.rules_doc, json.dumps(d))
        atomic_write(self.p.contact, str(now))
        self._unsuspend()
        if changed:
            self.log(event="rules", revision=d["revision"], kos=len(d.get("kos") or []))
        return changed

    def _suspend(self, why):
        L = self.state.ledger
        if not L.get("suspended"):
            self.log(event="suspended", why=why)
        L["suspended"] = {"why": why, "at": time.time()}
        self.state.save()

    def _unsuspend(self):
        L = self.state.ledger
        if L.get("suspended"):
            self.log(event="resumed", after=L["suspended"])
            L["suspended"] = None
            self.state.save()

    def fresh(self) -> tuple:
        if neg("fresh"):
            return True, "freshness check OFF (negative control)"
        s = self.state.ledger.get("suspended")
        if s:
            return False, "suspended: %s" % s["why"]
        try:
            lc = float(self.p.contact.read_text())
        except Exception:
            return False, "no contact with the rules route yet"
        age = time.time() - lc
        if age > float(self.cfg["stale_s"]):
            return False, "last contact with the rules route %.0f s ago (> %s s)" % (age, self.cfg["stale_s"])
        return True, "fresh (%.1f s)" % age

    # ---- memory (RB10)
    def memory_sync(self):
        if not self.cfg.get("memory_sync"):
            return None
        try:
            cache = json.loads(self.p.rules.read_text())
        except Exception:
            return None
        res = sync_memory(cache["doc"], Path(self.cfg["memory_dir"]), self.cfg["members"], self.p, cache["revision"])
        if res["created"]:
            self._manifest_runtime(res["created"])
        self.log(event="memory-sync", lines=res["lines"], replaced=res["replaced"], created=len(res["created"]))
        if res["lines"] > int(self.cfg["memory_alarm_lines"]):
            self.say("memory file has %d binding items (over %d). All are delivered; consider retiring some."
                     % (res["lines"], self.cfg["memory_alarm_lines"]), "memory-alarm:%s" % today())
        return res

    def _manifest_runtime(self, paths):
        try:
            m = json.loads(self.p.manifest.read_text())
        except Exception:
            return
        comp = m.setdefault("components", {}).setdefault("runner", {})
        rt = comp.setdefault("runtime_created", [])
        for x in paths:
            if x not in rt:
                rt.append(x)
        atomic_write(self.p.manifest, json.dumps(m, indent=1))

    # ---- room (RB1, RB2, RB6)
    def handle(self, m: dict) -> str:
        return str(m.get("by", "")).split()[0].lower() if m.get("by") else ""

    def poll(self) -> Optional[list]:
        try:
            msgs = self.room.get_messages(0)
        except (TransportStop, RoomError) as e:
            self._suspend("room: %s" % e)
            return None
        self.msgs_by_n = {int(m["n"]): m for m in msgs}
        L = self.state.ledger
        if not L.get("cursor_init"):
            L["cursor"] = max([int(m["n"]) for m in msgs] or [0])
            L["cursor_init"] = time.time()
            self.state.save()
            self.log(event="backlog-skipped", upto=L["cursor"])
            return []
        new = [m for m in msgs if int(m["n"]) > int(L["cursor"])]
        for m in new:
            L["cursor"] = max(int(L["cursor"]), int(m["n"]))
        self.state.save()
        return new

    def is_self(self, m):
        return self.member.is_self(m)

    def on_message(self, m: dict):
        if self.is_self(m):
            return
        who = self.handle(m)
        if who not in self.cfg["members"]:
            self.log(event="skip", n=m["n"], why="not a member")
            return
        first = str(m.get("body", "")).strip().splitlines()[0] if str(m.get("body", "")).strip() else ""
        if first.startswith("CARD"):
            self.on_card(m, who)
        elif TAKE_RX.match(first):
            self.on_take(m, who, "C-" + TAKE_RX.match(first).group(1))
        elif HOLD_RX.match(first):
            self.on_hold(m, who, "C-" + HOLD_RX.match(first).group(1))
        # anything else (including @SF-1 questions) belongs to the room thread, not the runner (RC6)

    def on_card(self, m, who):
        cid = "C-%s" % m["n"]
        cards = self.cards()
        if cid in cards:
            return
        card, why = parse_card(m["body"], self.cfg)
        if card and not neg("parser") and not neg("scope"):
            rc, _, _ = git(["cat-file", "-e", card["base"] + "^{commit}"], self.cfg["repo"])
            if rc != 0:
                card, why = None, "base %s is not a commit in %s" % (card["base"][:12], self.cfg["repo_name"])
        if card is None:
            cards[cid] = {"state": "REFUSED", "reason": why, "n": m["n"], "author": who}
            self.save_cards(cards)
            self.log(event="card-refused", card=cid, why=why)
            self.say("%s refused: %s. Format: CARD for:oliver base:<sha> files:<glob> accept:<cmd> cites:#n|none "
                     "dirty:no|apply, then the task on the next lines." % (cid, why), "card:%s:refused" % cid)
            return
        card.update(n=m["n"], author=who)
        if card["for"] != self.cfg["me"]:
            cards[cid] = {"state": "IGNORED", "for": card["for"], "n": m["n"], "author": who}
            self.save_cards(cards)
            self.log(event="card-ignored", card=cid, why="for:%s" % card["for"])
            return
        if not self.posting_enabled():
            cards[cid] = dict(card, state="NOT_RUN", reason="room posting disabled (LIVE_VERIFIED.json absent)")
            self.save_cards(cards)
            self.log(event="card-not-run", card=cid, why="posting disabled")
            return
        if card["dirty"] == "apply" and who != self.cfg["me"]:
            cards[cid] = dict(card, state="REFUSED", reason="dirty:apply needs the asker's diff, which is not on "
                                                            "this machine")
            self.save_cards(cards)
            self.say("%s refused: dirty:apply needs %s's own diff, which is not on Oliver's machine." % (cid, who),
                     "card:%s:refused" % cid)
            return
        if who == self.cfg["me"] or neg("consent"):
            cards[cid] = dict(card, state="QUEUED", consent="by %s" % who)
            self.save_cards(cards)
            self.say("%s queued for oliver (card by %s, base %s)." % (cid, who, card["base"][:8]),
                     "card:%s:queued" % cid)
        else:
            cards[cid] = dict(card, state="WAITING_TAKE")
            self.save_cards(cards)
            self.say("%s by %s for oliver: waiting for Oliver's TAKE %s." % (cid, who, cid), "card:%s:wait" % cid)
        self.log(event="card", card=cid, state=cards[cid]["state"], author=who)

    def on_take(self, m, who, cid):
        cards = self.cards()
        c = cards.get(cid)
        if not c:
            return
        if who != self.cfg["me"]:
            self.log(event="take-ignored", card=cid, by=who, why="only Oliver consents to his cards")
            return
        if c["state"] == "WAITING_TAKE":
            c["state"], c["consent"] = "QUEUED", "TAKE by %s (#%s)" % (who, m["n"])
            self.save_cards(cards)
            self.say("%s taken by Oliver; queued." % cid, "card:%s:taken" % cid)

    def on_hold(self, m, who, cid):
        c = self.cards().get(cid)
        if c and c["state"] in ACTIVE:
            if neg("hold"):
                self.log(event="hold-ignored", card=cid, why="NC hold off")
                return
            self.hold(cid, who, "HOLD #%s" % m["n"])

    def hold(self, cid, by, why, post=True) -> dict:
        cards = self.cards()
        c = cards[cid]
        t0 = time.time()
        res = {}
        for k in ("exec", "accept_proc"):
            if c.get(k):
                res[k] = kill_recorded(c[k], self.log)
                pr = self.procs.pop((cid, k), None)
                if pr:
                    try:
                        pr.wait(timeout=2)
                    except Exception:
                        pass
        c["state"], c["held_by"], c["held_why"] = "HELD", by, why
        c["kill_ms"] = int((time.time() - t0) * 1000)
        c["held_at"] = time.time()
        self.save_cards(cards)
        self.log(event="held", card=cid, by=by, why=why, kill=res, ms=c["kill_ms"])
        if post:
            self.say("%s HELD by %s: stopped in %d ms; worktree kept; it will not restart." % (cid, by, c["kill_ms"]),
                     "card:%s:held" % cid)
        return c

    def hold_active(self, why, by="runner", post=True):
        for cid, c in self.cards().items():
            if c["state"] in ACTIVE:
                self.hold(cid, by, why, post=post)

    # ---- cards (RB3, RB4, RB5, RB8, RB9)
    def start_card(self, cid):
        cards = self.cards()
        c = cards[cid]
        cfg = self.cfg
        wt = Path(cfg["work_dir"]).expanduser() / ("%s-%s" % (cid, time.strftime("%Y%m%d%H%M%S")))
        wt.parent.mkdir(parents=True, exist_ok=True)
        rc, _, err = git(["worktree", "add", "--detach", str(wt), c["base"]], cfg["repo"])
        if rc != 0:
            c["state"], c["reason"] = "FAILED", "git worktree add failed"
            self.save_cards(cards)
            self.log(event="card-failed", card=cid, why=err[:200])
            self.say("%s failed: could not create its worktree at base %s." % (cid, c["base"][:8]),
                     "card:%s:failed" % cid)
            return
        c["worktree"] = str(wt)
        gerr = self.guard_bound(wt)
        if gerr and not neg("guardbind"):
            c["state"], c["reason"] = "FAILED", "guard not bound in the card worktree (%s): fail closed" % gerr
            self.save_cards(cards)
            self.log(event="card-failed", card=cid, why=c["reason"])
            self.say("%s refused before start: the guard is not attached for this repo (fail closed); worktree "
                     "kept." % cid, "card:%s:noguard" % cid)
            return
        if c["dirty"] == "apply":
            _, diff, _ = git(["diff", "HEAD", "--binary"], cfg["repo"])         # read-only on Oliver's tree
            c["dirty_hash"] = sha256(diff.encode())[:16]
            if diff.strip():
                pr = subprocess.run(["git", "apply", "--whitespace=nowarn", "-"], cwd=str(wt), input=diff,
                                    capture_output=True, text=True)
                if pr.returncode != 0:
                    c["state"], c["reason"] = "FAILED", "dirty diff does not apply at base"
                    self.save_cards(cards)
                    self.say("%s failed: Oliver's uncommitted diff does not apply at base %s; worktree kept." %
                             (cid, c["base"][:8]), "card:%s:failed" % cid)
                    return
        d = self.p.cards_dir / cid
        d.mkdir(parents=True, exist_ok=True)
        plan = None
        if cfg.get("pairing"):
            try:
                rules_cache = json.loads(self.p.rules.read_text())
            except Exception:
                rules_cache = None
            plan, row = self.pairer.run(cid, c, str(wt), self.msgs_by_n, rules_cache)
            c["pair"] = {"pair_valid": row["pair_valid"], "invalid": row["invalid_reasons"], "id": row["pair_id"]}
        # re-check after the (slow) pairing step: fail closed if the rules went stale or STOP landed
        ok, why = self.fresh()
        if self.state.killed() or not ok:
            c["state"], c["held_why"] = "HELD", "not started: %s" % (self.state.killed() or why)
            self.save_cards(cards)
            self.log(event="card-not-started", card=cid, why=c["held_why"])
            return
        prompt = self.card_prompt(cid, c, plan)
        (d / "prompt.txt").write_text(prompt)
        argv = [cfg["claude_bin"], "-p", prompt, "--settings", str(self.p.profile), "--output-format", "stream-json",
                "--verbose", "--max-budget-usd", str(cfg["card_budget_usd"]), "--strict-mcp-config",
                "--mcp-config", json.dumps({"mcpServers": {}}), "--no-session-persistence"]
        env = child_env({"SF1_HUB_CARD_DIR": str(d)})
        rec, pr = spawn(argv, str(wt), env, d / "stream.jsonl", d / "stderr.txt")
        self.procs[(cid, "exec")] = pr
        self.model_calls += 1
        c.update(state="RUNNING", exec=rec, started=time.time(), turns=0, offset=0, denied_seen=0)
        self.save_cards(cards)
        self.log(event="card-started", card=cid, pid=rec["pid"], pgid=rec["pgid"])
        self.say("%s started for oliver at base %s (budget $%s, %s turns, %d min)." % (
            cid, c["base"][:8], cfg["card_budget_usd"], cfg["card_max_turns"], int(cfg["card_deadline_s"]) // 60),
            "card:%s:started" % cid)

    def guard_bound(self, wt) -> Optional[str]:
        """The guard binds a worktree through the COMMON git dir (guard.fast_root follows .git -> commondir), so a card
        worktree sees <repo>/.git/oliver-ben-guard/config.json. Read-only check; never edits the guard's config."""
        rc, out, _ = git(["rev-parse", "--git-common-dir"], str(wt))
        if rc != 0:
            return "no git dir"
        gd = Path(out.strip())
        gd = gd if gd.is_absolute() else Path(wt) / gd
        try:
            gc = json.loads((gd / "oliver-ben-guard" / "config.json").read_text())
        except Exception:
            return "no guard config.json in the common git dir"
        if gc.get("mode") != "attached":
            return "guard mode is %r, not attached" % gc.get("mode")
        if str(gc.get("me") or "").lower() != self.cfg["me"]:
            return "guard me=%r, not %s" % (gc.get("me"), self.cfg["me"])
        if not Path(self.cfg["guard"]).exists():
            return "guard.py missing"
        return None

    def card_prompt(self, cid, c, plan):
        cited = "\n".join("#%s %s: %s" % (n, self.msgs_by_n.get(n, {}).get("by"), self.msgs_by_n.get(n, {}).get(
            "body", "")[:2000]) for n in c["cites"]) or "(none)"
        return ("You are running hub card %s for Oliver, in a fresh git worktree of %s at base %s (detached HEAD).\n"
                "Task (from %s, room message #%s):\n%s\n\nFiles in scope: %s\n"
                "The runner runs this acceptance command after you finish: %s\n\nCited room turns:\n%s\n\n"
                "Plan from Claude Code (CC-READ):\n%s\n\n"
                "Rules: do not push, deploy, open PRs or send anything (denied; Oliver does those). Do not commit. "
                "Stay inside the files in scope. If the guard blocks an edit, stop and say why.\n" % (
                    cid, self.cfg["repo_name"], c["base"], c["author"], c["n"], c["task"], ",".join(c["files"]),
                    c["accept"], cited, plan or "(none: plan it yourself)"))

    def monitor(self):
        cards = self.cards()
        for cid, c in list(cards.items()):
            if c["state"] not in ("RUNNING", "ACCEPTING"):
                continue
            k = "exec" if c["state"] == "RUNNING" else "accept_proc"
            rec = c[k]
            pr = self.procs.get((cid, k))
            ended = (pr.poll() is not None) if pr else not group_alive(rec["pgid"])
            d = self.p.cards_dir / cid
            if c["state"] == "RUNNING":
                why = self._scan_stream(cid, c, d)
                self._post_denials(cid, c, d)
                if not why and time.time() - c["started"] > float(self.cfg["card_deadline_s"]):
                    why = "deadline %s s" % self.cfg["card_deadline_s"]
                if not why and c["turns"] > int(self.cfg["card_max_turns"]):
                    why = "max turns %s" % self.cfg["card_max_turns"]
                if why and not ended:
                    kr = kill_recorded(rec, self.log)
                    if pr:
                        try:
                            pr.wait(timeout=2)
                        except Exception:
                            pass
                    c["state"], c["reason"], c["kill"] = "STOPPED", why, kr
                    cards[cid] = c
                    self.save_cards(cards)
                    self.log(event="card-stopped", card=cid, why=why)
                    self.say("%s stopped: %s; worktree kept; it will not restart." % (cid, why), "card:%s:stop" % cid)
                    continue
                if ended:
                    self.procs.pop((cid, k), None)
                    self._scan_stream(cid, c, d)
                    self._post_denials(cid, c, d)
                    if c.get("limit_hit"):
                        c["state"], c["reason"] = "STOPPED", "plan limit message"
                        cards[cid] = c
                        self.save_cards(cards)
                        self.say("%s stopped on a plan limit message; worktree kept." % cid, "card:%s:limit" % cid)
                        continue
                    env = child_env({"SF1_HUB_CARD_DIR": str(d)})
                    arec, apr = spawn(["/bin/sh", "-c", c["accept"]], c["worktree"], env, d / "accept.out",
                                      d / "accept.out")
                    self.procs[(cid, "accept_proc")] = apr
                    c.update(state="ACCEPTING", accept_proc=arec, accept_started=time.time())
                    cards[cid] = c
                    self.save_cards(cards)
            else:
                if not ended and time.time() - c["accept_started"] > float(self.cfg["accept_timeout_s"]):
                    kill_recorded(rec, self.log)
                    c["accept_rc"] = "timeout"
                    ended = True
                if ended:
                    if pr:
                        rcode = pr.wait()
                        c.setdefault("accept_rc", rcode)
                    else:
                        c.setdefault("accept_rc", "unknown (runner restarted)")
                    self.procs.pop((cid, k), None)
                    self._finish(cid, c, d)
                    cards[cid] = c
                    self.save_cards(cards)

    def _scan_stream(self, cid, c, d) -> Optional[str]:
        f = d / "stream.jsonl"
        if not f.exists():
            return None
        with f.open("rb") as fh:
            fh.seek(int(c.get("offset") or 0))
            chunk = fh.read()
        if not chunk:
            return None
        last_nl = chunk.rfind(b"\n")
        if last_nl < 0:
            return None
        c["offset"] = int(c.get("offset") or 0) + last_nl + 1
        why = None
        for line in chunk[:last_nl].decode("utf-8", "replace").splitlines():
            try:
                ev = json.loads(line)
            except Exception:
                continue
            t = ev.get("type")
            if t == "assistant":
                content = (ev.get("message") or {}).get("content") or []
                if any(isinstance(x, dict) and x.get("type") == "tool_use" for x in content):
                    c["turns"] = int(c.get("turns") or 0) + 1
                txt = " ".join(str(x.get("text") or "") for x in content if isinstance(x, dict))
                if LIMIT_RX.search(txt):
                    c["limit_hit"] = True
                    why = why or "plan limit message"
            elif t == "result":
                c["cost_usd"] = ev.get("total_cost_usd")
                c["num_turns"] = ev.get("num_turns")
                c["result_subtype"] = ev.get("subtype")
                c["is_error"] = ev.get("is_error")
                if LIMIT_RX.search(str(ev.get("result") or "")):
                    c["limit_hit"] = True
                    why = why or "plan limit message"
            elif t == "system" and LIMIT_RX.search(json.dumps(ev)[:2000]) and ev.get("subtype") != "init":
                c["limit_hit"] = True
                why = why or "plan limit message"
        return why

    def _post_denials(self, cid, c, d):
        f = d / "denied.jsonl"
        if not f.exists():
            return
        rows = f.read_text().splitlines()
        for i, line in enumerate(rows[int(c.get("denied_seen") or 0):], start=int(c.get("denied_seen") or 0)):
            try:
                r = json.loads(line)
            except Exception:
                continue
            self.say("%s: %s denied inside the card, waiting for Oliver." % (cid, r.get("kind")),
                     "card:%s:denied:%d" % (cid, i))
        c["denied_seen"] = len(rows)

    def _finish(self, cid, c, d):
        wt = c["worktree"]
        _, st, _ = git(["status", "--porcelain", "--untracked-files=all"], wt)
        changed = sorted(set(l[3:].strip() for l in st.splitlines() if l.strip()))
        outside = [f for f in changed if not any(glob_match(f, g) for g in c["files"])]
        c["changed"], c["outside_scope"] = changed, outside
        ok = c["accept_rc"] == 0 and not outside
        c["state"] = "DONE" if ok else "FAILED"
        with self.state.pairs.open("a") as f:
            f.write(json.dumps({"schema": "sf1-hub-pair-outcome/1", "pair_id": (c.get("pair") or {}).get("id"),
                                "task_id": cid, "card_acceptance": {"rc": c["accept_rc"], "outside_scope": outside,
                                                                    "changed": len(changed)},
                                "ts": time.time()}) + "\n")
        self.log(event="card-done", card=cid, state=c["state"], accept_rc=c["accept_rc"], changed=len(changed),
                 outside=len(outside), cost=c.get("cost_usd"))
        cost = c.get("cost_usd")
        self.say("%s %s: accept %s (rc %s), %d files changed%s, %s plan-equivalent, %s turns; worktree kept." % (
            cid, "done" if ok else "failed", "PASS" if c["accept_rc"] == 0 else "FAIL", c["accept_rc"], len(changed),
            (", %d outside files:%s" % (len(outside), ",".join(c["files"]))) if outside else "",
            ("$%.2f" % float(cost)) if cost is not None else "cost unknown", c.get("num_turns")), "card:%s:done" % cid)

    # ---- the tick
    def tick(self, net_due=True) -> dict:
        self.cfg = load_cfg(self.p)
        self.net.cfg = self.cfg
        if self.cfg.get("mode") != "live":
            atomic_write(self.p.heartbeat, json.dumps({"at": time.time(), "mode": self.cfg.get("mode")}))
            return {"mode": self.cfg.get("mode"), "network": 0, "model": 0}
        why = self.state.killed()
        if why:
            for cid, c in self.cards().items():
                if c["state"] in ACTIVE:
                    self.hold(cid, "STOP", why, post=False)
            return {"killed": why}
        self.monitor()
        if not net_due:
            return {"net": False}
        changed = self.refresh_rules()
        if changed and not self.state.killed():
            self.memory_sync()
        ok, fwhy = self.fresh()
        if self.state.killed():
            self.hold_active(self.state.killed(), "STOP", post=False)
            return {"killed": self.state.killed()}
        if not ok:
            self.hold_active("rules not fresh: %s" % fwhy, post=True)
            return {"fresh": False, "why": fwhy}
        new = self.poll()
        if new is None:
            self.hold_active("room unreachable (a HOLD could not be seen)", post=False)
            return {"room": False}
        for m in new:
            self.on_message(m)
        if self.state.killed():
            return {"killed": self.state.killed()}
        ok, fwhy = self.fresh()
        cards = self.cards()
        if ok and not any(c["state"] in ("RUNNING", "ACCEPTING") for c in cards.values()):
            q = sorted((int(c["n"]), cid) for cid, c in cards.items() if c["state"] == "QUEUED")
            if q:
                self.start_card(q[0][1])
        elif not ok:
            self.log(event="no-start", why=fwhy)
        return {"fresh": ok, "new": len(new)}


# ---------------------------------------------------------------- loop (one process, pidfile)
def run_loop(home=None):
    R = Runner(home)
    fd = os.open(str(R.p.pidfile), os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("another runner holds %s; exiting" % R.p.pidfile)
        return 0
    os.ftruncate(fd, 0)
    os.write(fd, str(os.getpid()).encode())
    stop = {"x": False}
    signal.signal(signal.SIGTERM, lambda *a: stop.__setitem__("x", True))
    next_net = 0.0
    while not stop["x"]:
        now = time.time()
        due = now >= next_net
        try:
            R.tick(net_due=due)
        except Exception as e:
            try:
                R.log(event="tick-error", err="%s: %s" % (type(e).__name__, str(e)[:200]))
            except Exception:
                pass
        if due:
            next_net = now + float(R.cfg.get("poll_s", 15))
        time.sleep(1)
    return 0


# ---------------------------------------------------------------- install / detach / golive (RB11)
RUNTIME_GLOBS = ["runner/config.json", "runner/log.jsonl", "runner/ledger.json", "runner/ledger.tmp",
                 "runner/pairs.jsonl", "runner/budget.jsonl", "runner/cards.json", "runner/rules-cache.json",
                 "runner/rules-doc.json", "runner/last_contact", "runner/runner.pid", "runner/heartbeat",
                 "runner/launchd.log", "runner/STOP", "runner/hub.key", "runner/memory-backup.json", "runner/*.tmp",
                 "runner/bin/**", "runner/cards/**", "runner/work/**", "runner/sf1-arm/**"]
# BEGIN NEVER_TOUCHED (documentation only: the manifest records what the runner promises not to touch)
NEVER_TOUCHED = ["~/.claude/settings.json", "~/.claude.json", "the checkout's .claude/ and .git/hooks", "~/.sf1/bin",
                 "~/.sf1/opencode", "~/.sf1/shadow", "~/.sf1/twin", "/Users/oz/data/oliver-ben-guard"]
# END NEVER_TOUCHED
OTHER_COMPONENT_DIRS = ["room-thread", "room-thread-bin", "manifest-room-thread.json"]   # phase C's, not ours


def snapshot(p: P, cfg: dict) -> dict:
    """file -> sha256 (dirs -> 'dir') over the attach-diff roots."""
    out = {}
    roots = [(p.hub, True), (p.la, False), (Path(cfg["memory_dir"]).expanduser(), True),
             (Path(cfg["repo"]) / ".claude", True), (Path(cfg["repo"]) / ".git" / "hooks", True),
             (Path.home() / ".claude" / "settings.json", False)]
    skip = [str(p.hub / x) for x in OTHER_COMPONENT_DIRS] + [str(p.r / "work")]
    for root, rec in roots:
        if root.is_file():
            out[str(root)] = sha256(root.read_bytes())
            continue
        if not root.is_dir():
            continue
        if rec:
            out[str(root)] = "dir"
            for dp, dns, fns in os.walk(root):
                if any(dp == s or dp.startswith(s + os.sep) for s in skip):
                    dns[:] = []
                    continue
                for dn in dns:
                    full = os.path.join(dp, dn)
                    if not any(full == s for s in skip):
                        out[full] = "dir"
                for fn in fns:
                    fp = os.path.join(dp, fn)
                    if any(fp == s_ for s_ in skip):
                        continue
                    try:
                        out[fp] = sha256(open(fp, "rb").read())
                    except Exception:
                        out[fp] = "unreadable"
        else:
            for fn in os.listdir(root):
                fp = root / fn
                if fp.is_file():
                    out[str(fp)] = sha256(fp.read_bytes())
    return out


def diff_snap(a: dict, b: dict) -> dict:
    return {"added": sorted(k for k in b if k not in a), "removed": sorted(k for k in a if k not in b),
            "changed": sorted(k for k in b if k in a and a[k] != b[k])}


def manifest_allows(p: P, comp: dict, path: str) -> bool:
    if path in comp.get("files", []) or path in comp.get("dirs", []) or path in comp.get("runtime_created", []):
        return True
    if path == str(p.manifest):
        return True
    try:
        rel = os.path.relpath(path, p.hub)
    except ValueError:
        return False
    if rel.startswith(".."):
        return False
    return any(re.match(glob_to_regex(g), rel) for g in RUNTIME_GLOBS)


def verify_attach(p: P, before: dict, after: dict, comp: dict) -> dict:
    d = diff_snap(before, after)
    unexplained = [x for x in d["added"] + d["changed"] if not manifest_allows(p, comp, x)]
    return {"diff": d, "unexplained": unexplained, "removed_unexpected": d["removed"],
            "ok": not unexplained and not d["removed"]}


def plist_xml(p: P, cfg: dict) -> str:
    def s(x):
        return x.replace("&", "&amp;").replace("<", "&lt;")
    return """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>%s</string>
  <key>ProgramArguments</key>
  <array><string>%s</string><string>%s</string><string>loop</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>SF1_HUB_HOME</key><string>%s</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>%s</string>
  <key>StandardErrorPath</key><string>%s</string>
</dict>
</plist>
""" % (LABEL_JOB, s(cfg["python"]), s(str(p.bin / "runner.py")), s(str(p.hub)), s(str(p.r / "launchd.log")),
       s(str(p.r / "launchd.log")))


def read_manifest(p: P) -> dict:
    try:
        return json.loads(p.manifest.read_text())
    except Exception:
        return {"schema": "sf1-hub-manifest/1", "components": {}}


def launchctl(args):
    if os.environ.get("SF1_HUB_NO_LAUNCHCTL") == "1":
        return 0, "(launchctl skipped: SF1_HUB_NO_LAUNCHCTL=1)"
    pr = subprocess.run(["launchctl"] + args, capture_output=True, text=True)
    return pr.returncode, (pr.stdout + pr.stderr).strip()


def install(home=None, results=None, force_gate=False) -> dict:
    p = P(home)
    gate = Path(results or HERE / "tests" / "results.json")
    need = ["S1", "S2", "S3", "S4", "S5", "S6", "S7"] + ["RB%d" % i for i in range(1, 11)]
    try:
        rows = json.loads(gate.read_text())["rows"]
    except Exception:
        rows = {}
    bad = [r for r in need if (rows.get(r) or {}).get("verdict") != "PASS"]
    if bad and not force_gate:
        return {"ok": False, "why": "install gate: rows not PASS in %s: %s" % (gate, ",".join(bad))}
    m = read_manifest(p)
    if "runner" in m.get("components", {}):
        return {"ok": False, "why": "already installed (manifest has a runner component); detach first"}
    cfg0 = load_cfg(p)
    before = snapshot(p, cfg0)
    files, dirs = [], []
    for dd in (p.hub, p.r, p.bin):
        if not dd.exists():
            dd.mkdir(parents=True)
            dirs.append(str(dd))
    manifest_existed = p.manifest.exists()
    for fn in CODE_FILES:
        shutil.copy2(HERE / fn, p.bin / fn)
        files.append(str(p.bin / fn))
    shutil.copy2(Path(rm.__file__), p.bin / "room_member.py")
    files.append(str(p.bin / "room_member.py"))
    if not p.cfg.exists():
        atomic_write(p.cfg, json.dumps({"mode": "prelive", "installed_at": time.time()}, indent=1))
        files.append(str(p.cfg))
    cfg = load_cfg(p)
    if p.profile.exists():
        return {"ok": False, "why": "%s exists and is not ours; refusing to overwrite" % p.profile}
    atomic_write(p.profile, json.dumps(executor_profile(cfg, p), indent=1))
    files.append(str(p.profile))
    plist = p.la / (LABEL_JOB + ".plist")
    if plist.exists():
        return {"ok": False, "why": "%s exists; refusing to overwrite" % plist}
    p.la.mkdir(parents=True, exist_ok=True)
    atomic_write(plist, plist_xml(p, cfg))
    files.append(str(plist))
    comp = {"version": VERSION, "installed_at": time.time(), "mode": "prelive", "files": files, "dirs": dirs,
            "runtime_globs_under_hub": RUNTIME_GLOBS, "launchd": [LABEL_JOB], "runtime_created": [],
            "runtime_later": {"golive": [str(p.r / "hub.key")],
                              "memory_sync": [str(Path(cfg["memory_dir"]).expanduser() / "hub-rulings.md"),
                                              "one line in " + str(Path(cfg["memory_dir"]).expanduser() / "MEMORY.md")]},
            "manifest_existed": manifest_existed,
            "never_touched": NEVER_TOUCHED}
    m.setdefault("schema", "sf1-hub-manifest/1")
    m.setdefault("components", {})["runner"] = comp
    atomic_write(p.manifest, json.dumps(m, indent=1))
    rc, out = launchctl(["bootstrap", "gui/%d" % os.getuid(), str(plist)])
    for _ in range(3):                      # rc 5 right after a bootout of the same label: launchd is still tearing down
        if rc != 5:
            break
        time.sleep(3)
        rc, out = launchctl(["bootstrap", "gui/%d" % os.getuid(), str(plist)])
    comp["launchctl_bootstrap"] = {"rc": rc, "out": out[:300]}
    m["components"]["runner"] = comp
    atomic_write(p.manifest, json.dumps(m, indent=1))
    time.sleep(0.5 if os.environ.get("SF1_HUB_NO_LAUNCHCTL") == "1" else 3)
    after = snapshot(p, cfg)
    v = verify_attach(p, before, after, comp)
    return {"ok": v["ok"] and rc == 0, "manifest": str(p.manifest), "component": comp, "verify": v,
            "before": before}


def detach(home=None, remove_worktrees=False) -> dict:
    p = P(home)
    m = read_manifest(p)
    comp = m.get("components", {}).get("runner")
    if not comp:
        return {"ok": False, "why": "no runner component in the manifest"}
    out = {"steps": []}
    rc, o = launchctl(["bootout", "gui/%d/%s" % (os.getuid(), LABEL_JOB)])
    out["steps"].append("launchctl bootout rc=%s" % rc)
    R = Runner(home)
    for cid, c in R.cards().items():
        if c["state"] in ACTIVE:
            R.hold(cid, "detach", "detach", post=False)
            out["steps"].append("held " + cid)
    if R.cfg.get("mode") == "live" and R.posting_enabled() and not R.state.killed():
        R.say("runner detached on Oliver's machine; cards for oliver will not run.", "detach:%s" % time.time())
    if R.cfg.get("mode") == "live" and R.cfg.get("hub_key_id") and not R.state.killed():
        try:
            st, _, _ = R.net.req("POST", "/v1/hub/keys/%s/revoke" % R.cfg["hub_key_id"], "brain", {})
            out["steps"].append("hub key revoke -> %s" % st)
        except TransportStop as e:
            out["steps"].append("hub key revoke not sent: %s" % e)
    out["steps"] += unsync_memory(Path(R.cfg["memory_dir"]), p)
    for x in comp.get("runtime_created", []):
        if Path(x).is_file():
            Path(x).unlink()
    wdir = Path(R.cfg["work_dir"]).expanduser()
    kept = []
    if wdir.exists():
        for wt in sorted(wdir.iterdir()):
            if remove_worktrees:
                git(["worktree", "remove", "--force", str(wt)], R.cfg["repo"])
            else:
                kept.append(str(wt))
    for x in comp.get("files", []):
        if Path(x).exists():
            Path(x).unlink()
    # runtime files under runner/ (matched by the manifest's runtime globs), never anything else
    if p.r.exists():
        for dp, dns, fns in os.walk(p.r, topdown=False):
            for fn in fns:
                fp = os.path.join(dp, fn)
                rel = os.path.relpath(fp, p.hub)
                if rel.startswith("runner/work/"):
                    continue
                if any(re.match(glob_to_regex(g), rel) for g in RUNTIME_GLOBS):
                    os.unlink(fp)
            for dn in dns:
                full = os.path.join(dp, dn)
                if os.path.isdir(full) and not os.listdir(full) and (full != str(wdir) or not kept):
                    os.rmdir(full)
    del m["components"]["runner"]
    if not m["components"] and not comp.get("manifest_existed"):
        p.manifest.unlink()
    else:
        atomic_write(p.manifest, json.dumps(m, indent=1))
    for x in sorted(comp.get("dirs", []), key=len, reverse=True):
        if Path(x).is_dir() and not os.listdir(x):
            os.rmdir(x)
    out["kept_worktrees"] = kept
    out["ok"] = True
    return out


def live_verified(cfg: dict, base: Optional[str] = None) -> tuple:
    """Go-live order (KO 68561121): the room thread posts its labeled test post, verifies it reads as "SF-1", posts
    tonight's digest, then writes LIVE_VERIFIED.json. Required: the file, and the digest marker. The marker is either
    "digest_posted": true (the ruling's wording) or the room thread's shipped shape (room_thread.py golive step 3):
    an integer digest_msg_n plus a non-empty digest_doc_rev. When present, by must be "SF-1", via "sf1", room this
    room and base this base."""
    f = Path(cfg["post_gate_file"]).expanduser()
    if neg("livegate"):
        return True, "gate OFF (negative control)"
    if not f.exists():
        return False, "%s absent" % f
    try:
        d = json.loads(f.read_text())
    except Exception:
        return False, "%s is not valid JSON" % f
    if not isinstance(d, dict):
        return False, "%s is not a JSON object" % f
    digest = d.get("digest_posted") is True or (isinstance(d.get("digest_msg_n"), int) and
                                                 not isinstance(d.get("digest_msg_n"), bool) and
                                                 bool(d.get("digest_doc_rev")))
    if not digest:
        return False, "%s has no digest marker (\"digest_posted\": true, or digest_msg_n + digest_doc_rev)" % f
    if "by" in d and d["by"] != "SF-1":
        return False, "%s says the test post read as %r, not SF-1" % (f, d["by"])
    if "via" in d and d["via"] != rm.VIA:
        return False, "%s says via %r, not sf1" % (f, d["via"])
    if "room" in d and d["room"] != cfg["room_id"]:
        return False, "%s is for another room" % f
    want = (base or cfg.get("base_url") or "").rstrip("/")
    if "base" in d and want and str(d["base"]).rstrip("/") != want:
        return False, "%s is for another base (%s)" % (f, d["base"])
    return True, "verified"


def golive(home=None, base="https://app.spnc.ai", brain_spec=None) -> dict:
    """(1) one GET of the rules route with Oliver's brain token must return 200 (504/503/timeout -> STOP, no retry);
    (2) mint the hub key once (POST /v1/hub/keys), stored mode 600; (3) write the live config. Room posting stays
    disabled until the room-thread agent's LIVE_VERIFIED.json exists with "digest_posted": true (checked at every post);
    golive itself refuses, with zero network calls, until that file is in place (KO 68561121)."""
    p = P(home)
    m = read_manifest(p)
    if "runner" not in m.get("components", {}):
        return {"ok": False, "why": "not installed (no runner component in %s)" % p.manifest}
    R = Runner(home)
    if R.state.killed():
        return {"ok": False, "why": "stopped: %s; a human runs `runner.py unstop` first" % R.state.killed()}
    lv, lwhy = live_verified(R.cfg, base)
    if not lv:
        R.log(event="golive-refused", why=lwhy)
        return {"ok": False, "why": "room thread has not verified go-live (%s); staying pre-live" % lwhy,
                "requests": 0}
    cfg = dict(R.cfg)
    cfg["base_url"] = base
    if brain_spec:
        cfg["brain_token_file"] = brain_spec
    net = Net(cfg, R.state)
    try:
        st, _, d = net.req("GET", "/v1/projects/%s/rules" % cfg["project"], "brain")
    except TransportStop as e:
        return {"ok": False, "why": "rules route check stopped: %s (STOP written; no retry)" % e, "requests": 1}
    if st != 200 or d.get("schema") != "sf1-hub-rules/1":
        return {"ok": False, "why": "rules route returned %s; refusing to go live" % st, "requests": net.requests}
    keyf = Path(cfg["hub_key_file"]).expanduser()
    minted = False
    if not keyf.exists():
        try:
            st, _, d = net.req("POST", "/v1/hub/keys", "brain", {"room": cfg["room_id"], "label": "sf1 hub runner"})
        except TransportStop as e:
            return {"ok": False, "why": "key mint stopped: %s" % e, "requests": net.requests}
        if st != 201 or not str(d.get("key", "")).startswith("hub_"):
            return {"ok": False, "why": "hub key mint returned %s" % st, "requests": net.requests}
        keyf.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(str(keyf), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.write(fd, d["key"].encode())
        os.close(fd)
        cfg["hub_key_id"] = d.get("id", "")
        minted = True
    live = json.loads(p.cfg.read_text()) if p.cfg.exists() else {}
    live.update(mode="live", base_url=base, brain_token_file=cfg["brain_token_file"], hub_key_file=str(keyf),
                hub_key_id=cfg.get("hub_key_id", live.get("hub_key_id", "")), golive_at=time.time())
    atomic_write(p.cfg, json.dumps(live, indent=1))
    comp = m["components"]["runner"]
    comp["mode"] = "live"
    comp.setdefault("runtime_created", [])
    if minted and str(keyf) not in comp["runtime_created"]:
        comp["runtime_created"].append(str(keyf))
    atomic_write(p.manifest, json.dumps(m, indent=1))
    R.log(event="golive", base=base, minted=minted, requests=net.requests)
    return {"ok": True, "minted": minted, "requests": net.requests,
            "posting": "enabled" if live_verified(cfg, base)[0] else "disabled: %s" % live_verified(cfg, base)[1]}


def status(home=None) -> dict:
    R = Runner(home)
    cards = R.cards()
    try:
        lc = time.time() - float(R.p.contact.read_text())
    except Exception:
        lc = None
    rc, o = launchctl(["print", "gui/%d/%s" % (os.getuid(), LABEL_JOB)])
    st = re.search(r"state = (\w+)", o or "")
    return {"mode": R.cfg.get("mode"), "base_url": R.cfg.get("base_url") or None, "stop": R.state.killed(),
            "suspended": R.state.ledger.get("suspended"), "last_contact_s": lc,
            "posting": R.posting_enabled(), "spent_today_pairs_usd": round(R.pairer.spent_today(), 4),
            "cards": {k: v.get("state") for k, v in cards.items()},
            "launchd": (st.group(1) if st else ("not loaded" if rc else "loaded"))}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("cmd", choices=["install", "detach", "stop", "unstop", "status", "golive", "run-once", "loop"])
    ap.add_argument("--home", default=None, help="hub home (default ~/.sf1/hub, or $SF1_HUB_HOME)")
    ap.add_argument("--base", default="https://app.spnc.ai")
    ap.add_argument("--results", default=None, help="install gate: the test results json")
    ap.add_argument("--remove-worktrees", action="store_true")
    ap.add_argument("--why", default="human stop")
    a = ap.parse_args(argv)
    if a.cmd == "loop":
        return run_loop(a.home)
    if a.cmd == "install":
        r = install(a.home, a.results)
        r.pop("before", None)
    elif a.cmd == "detach":
        r = detach(a.home, a.remove_worktrees)
    elif a.cmd == "golive":
        r = golive(a.home, a.base)
    elif a.cmd == "status":
        r = status(a.home)
    elif a.cmd == "stop":
        R = Runner(a.home)
        R.state.set_stop(a.why)
        held = []
        for cid, c in R.cards().items():
            if c["state"] in ACTIVE:
                R.hold(cid, "STOP", a.why, post=False)
                held.append(cid)
        r = {"stopped": True, "held": held}
    elif a.cmd == "unstop":
        R = Runner(a.home)
        R.state.unstop()
        r = {"unstopped": True, "note": "new cards only; held cards stay held"}
    else:
        R = Runner(a.home)
        r = R.tick(net_due=True)
    print(json.dumps(r, indent=1, default=str))
    return 0 if r.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main())

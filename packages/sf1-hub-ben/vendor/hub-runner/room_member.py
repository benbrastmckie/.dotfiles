#!/usr/bin/env python3
"""SF-1 as a labeled member of the oliver-ben room (minimal shared SF-1 thread, 2026-11-12).

Rulings: KO 2470a8f7 (item 3), 6efa3e3d (hub goal: Claude Code decides), 8ac442c6 / b2df1518 (path v2),
b8de8412 (per-repo scope + leak canary, custom-command tag). Prereg: PREREG.md (sha in PREREG.md.sha256).

Stdlib only. No model calls unless a live backend is configured. Never prints keys.

Transports:
  MockRoom    LOCAL MOCK of APP's routes (a JSON file; every file carries "_mock").
  HostedRoom  APP's routes: POST /v1/rooms/<id>/messages {body, via:"sf1", rid}, GET /v1/rooms/<id>,
              POST /v1/docs/<slug> {title, body, author, base_hash}. OFF unless --hosted. Stop rule: on the
              first 504, 503 or timeout it writes STOP and never retries.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional

LABEL = "[SF-1]"
VIA = "sf1"
DEFAULT_ROOM = "mEdYrFW_qClSGDfx"
DEFAULT_PROJECT = "oliver-ben"
MEMBERS = ("oliver", "ben")
MENTION_RE = re.compile(r"(?<![\w@])@sf-?1\b", re.I)

# test hooks for negative controls (never set in production)
NEGCTRL: set = set()


# ---------------------------------------------------------------- privacy filter (R4)
PRIVATE_PATTERNS = [
    ("logos", re.compile(r"logos", re.I)),
    ("equity", re.compile(r"\b(equity|vesting|vest(ed)?\b|cap[ -]table|advisor grant|founding terms|"
                          r"stock option|option pool|shares? of|valuation|salary|compensation)\b", re.I)),
    ("percent-stake", re.compile(r"\b\d{1,2}(\.\d+)?\s?%\s*(stake|of the company|role|ownership)", re.I)),
    ("secret", re.compile(r"(sk-[A-Za-z0-9_-]{8,}|npub_sk_\w+|hub_[A-Za-z0-9]{8,}|ghp_\w{10,}|"
                          r"AKIA[0-9A-Z]{12,}|Bearer\s+\S{8,}|xox[bp]-\S+)")),
    ("local-path", re.compile(r"(/Users/|/private/tmp/|/home/\w+/|~/\.)")),
    ("personal", re.compile(r"\b(lawyer|attorney|divorce|custody|medical|diagnosis)\b", re.I)),
]


def guard_ban_strings(rules_file: Optional[Path]) -> list[str]:
    """RULE ban-string lines from the guard's rules file, read-only (guard-protect: we never write it)."""
    if not rules_file or not rules_file.exists():
        return []
    try:
        doc = json.loads(rules_file.read_text())
    except Exception:
        return []
    out = []
    for ko in doc.get("kos", []):
        for line in str(ko.get("object") or ko.get("object_value") or "").splitlines():
            m = re.match(r"\s*RULE ban-string:\s*(.+?)\s*$", line)
            if m and not ko.get("invalid_at"):
                out.append(m.group(1))
    return out


def privacy_check(text: str, extra_bans: list[str] = ()) -> list[str]:
    """Reasons the text may not be posted ([] = clean). Whole-post refusal, never a redaction."""
    if "privacy" in NEGCTRL:
        return []
    bad = [name for name, rx in PRIVATE_PATTERNS if rx.search(text)]
    low = text.lower()
    bad += ["guard-ban:" + b for b in extra_bans if b and b.lower() in low]
    return bad


# ---------------------------------------------------------------- state: kill switch, rate limits, ledgers
@dataclass
class Limits:
    posts_per_hour: int = 12
    posts_per_day: int = 40
    answers_per_person_10min: int = 3
    digests_per_date: int = 1


class State:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.stop = self.root / "STOP"
        self.log = self.root / "log.jsonl"
        self.pairs = self.root / "pairs.jsonl"
        self.ledger_f = self.root / "ledger.json"
        self.ledger = self._load()

    def _load(self):
        try:
            return json.loads(self.ledger_f.read_text())
        except Exception:
            return {"posts": [], "answers": [], "answered": {}, "digests": {}, "cursor": 0, "idem": {},
                    "started_at": time.time()}

    def save(self):
        tmp = self.ledger_f.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.ledger))
        os.replace(tmp, self.ledger_f)

    def write_log(self, **row):
        row["ts"] = time.time()
        with self.log.open("a") as f:
            f.write(json.dumps(row) + "\n")

    def killed(self) -> Optional[str]:
        if "kill" in NEGCTRL:
            return None
        if os.environ.get("SF1_ROOM_MEMBER_OFF") == "1":
            return "env SF1_ROOM_MEMBER_OFF=1"
        if self.stop.exists():
            return "STOP: " + self.stop.read_text()[:200]
        return None

    def set_stop(self, cause: str):
        self.stop.write_text(json.dumps({"cause": cause, "at": time.time()}))
        self.write_log(event="stop", cause=cause)

    def unstop(self):
        if self.stop.exists():
            self.stop.unlink()
            self.write_log(event="unstop")


def rate_ok(state: State, lim: Limits, kind: str, person: str = "", date: str = "") -> Optional[str]:
    if "rate" in NEGCTRL:
        return None
    now = time.time()
    posts = [t for t in state.ledger["posts"] if now - t < 86400]
    if sum(1 for t in posts if now - t < 3600) >= lim.posts_per_hour:
        return "rate: %d posts in the last hour" % lim.posts_per_hour
    if len(posts) >= lim.posts_per_day:
        return "rate: %d posts in the last day" % lim.posts_per_day
    if kind == "digest" and state.ledger["digests"].get(date, 0) >= lim.digests_per_date:
        return "rate: digest for %s already posted" % date
    if kind == "answer":
        recent = [a for a in state.ledger["answers"] if a["p"] == person and now - a["t"] < 600]
        if len(recent) >= lim.answers_per_person_10min:
            return "rate: %d answers to %s in 10 min" % (lim.answers_per_person_10min, person)
    return None


# ---------------------------------------------------------------- transports
class TransportStop(Exception):
    pass


class MockRoom:
    """LOCAL MOCK of APP's room + docs routes. Same shapes as feat/hub-phase-a-1112 / the via:"sf1" post."""

    def __init__(self, path: Path, room_id: str = DEFAULT_ROOM):
        self.path = Path(path)
        self.room_id = room_id
        if not self.path.exists():
            self._w({"_mock": "LOCAL MOCK of APP routes (not the live room). Shapes: POST /v1/rooms/<id>/messages "
                     "{body, via, rid}; GET /v1/rooms/<id>; POST /v1/docs/<slug>.",
                     "room": {"id": room_id, "title": "Oliver Ben", "members": list(MEMBERS), "messages": []},
                     "docs": {}, "requests": 0})

    def _r(self):
        return json.loads(self.path.read_text())

    def _w(self, d):
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(d, indent=1))
        os.replace(tmp, self.path)

    def human_post(self, by: str, body: str, ts: Optional[float] = None) -> int:
        """Test/demo helper: a person writes in the room."""
        d = self._r()
        n = len(d["room"]["messages"]) + 1
        d["room"]["messages"].append({"n": n, "kind": "message", "by": by, "body": body, "ts": ts or time.time()})
        self._w(d)
        return n

    def get_messages(self, since: int = 0) -> list[dict]:
        d = self._r()
        d["requests"] += 1
        self._w(d)
        return [m for m in d["room"]["messages"] if m["n"] > since]

    def post_message(self, body: str, rid: str) -> dict:
        if "label" not in NEGCTRL and not body.startswith(LABEL):
            raise ValueError("unlabeled SF-1 body refused")
        d = self._r()
        d["requests"] += 1
        for m in d["room"]["messages"]:
            if m.get("rid") == rid:
                return dict(m, replayed=True)
        n = len(d["room"]["messages"]) + 1
        m = {"n": n, "kind": "message", "by": "SF-1", "via": VIA, "body": body, "rid": rid, "ts": time.time()}
        d["room"]["messages"].append(m)
        self._w(d)
        return m

    def put_doc(self, slug: str, title: str, body: str) -> dict:
        d = self._r()
        d["requests"] += 1
        prev = d["docs"].get(slug)
        head = hashlib.sha256(body.encode()).hexdigest()[:16]
        d["docs"][slug] = {"title": title, "body": body, "author": "SF-1", "head": head,
                           "versions": (prev or {}).get("versions", 0) + 1}
        self._w(d)
        return {"ok": True, "slug": slug, "head": head}


class HostedRoom:
    """APP's routes on the hosted app. One request per call, never a retry; 504/503/timeout -> STOP."""

    def __init__(self, base: str, room_id: str, key_file: Path, state: State, timeout: float = 15.0):
        self.base = base.rstrip("/")
        self.room_id = room_id
        self.key_file = Path(key_file)
        self.state = state
        self.timeout = timeout
        self.requests = 0

    def _req(self, method: str, path: str, body: Optional[dict] = None):
        if self.state.killed():
            raise TransportStop(self.state.killed())
        key = self.key_file.read_text().strip()   # never logged or printed
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
        self.requests += 1
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code in (503, 504):
                self.state.set_stop("hosted %s on %s %s" % (e.code, method, path))
                raise TransportStop("hosted %s" % e.code)
            raise
        except (TimeoutError, urllib.error.URLError) as e:
            self.state.set_stop("hosted timeout/conn on %s %s: %s" % (method, path, type(e).__name__))
            raise TransportStop("hosted timeout")

    def get_messages(self, since: int = 0) -> list[dict]:
        d = self._req("GET", "/v1/rooms/%s" % self.room_id)
        return [m for m in d.get("messages", []) if int(m.get("n", 0)) > since]

    def post_message(self, body: str, rid: str) -> dict:
        if not body.startswith(LABEL):
            raise ValueError("unlabeled SF-1 body refused")
        return self._req("POST", "/v1/rooms/%s/messages" % self.room_id, {"body": body, "via": VIA, "rid": rid})

    def put_doc(self, slug: str, title: str, body: str) -> dict:
        return self._req("POST", "/v1/docs/%s" % slug, {"title": title, "body": body, "author": "SF-1"})


# ---------------------------------------------------------------- poster
@dataclass
class Member:
    room: object
    state: State
    limits: Limits = field(default_factory=Limits)
    rules_file: Optional[Path] = None

    def post(self, text: str, kind: str, source: str, person: str = "", date: str = "") -> dict:
        """Every outgoing line goes through here: kill switch, label, privacy, rate, idempotency."""
        why = self.state.killed()
        if why:
            self.state.write_log(event="refused", kind=kind, source=source, reason=why)
            return {"posted": False, "reason": why}
        body = text if text.startswith(LABEL) else LABEL + " " + text
        if "label" in NEGCTRL:
            body = text
        bad = privacy_check(body, guard_ban_strings(self.rules_file))
        if bad:
            self.state.write_log(event="refused", kind=kind, source=source, reason="privacy", hits=bad)
            return {"posted": False, "reason": "privacy", "hits": bad}
        r = rate_ok(self.state, self.limits, kind, person, date)
        if r:
            self.state.write_log(event="refused", kind=kind, source=source, reason=r)
            return {"posted": False, "reason": r}
        rid = "sf1-" + hashlib.sha256(("%s|%s|%s" % (kind, source, body)).encode()).hexdigest()[:24]
        if rid in self.state.ledger["idem"]:
            return {"posted": False, "reason": "duplicate", "rid": rid}
        try:
            m = self.room.post_message(body, rid)
        except TransportStop as e:
            return {"posted": False, "reason": "stop: %s" % e}
        now = time.time()
        self.state.ledger["posts"].append(now)
        self.state.ledger["idem"][rid] = m.get("n")
        if kind == "digest":
            self.state.ledger["digests"][date] = self.state.ledger["digests"].get(date, 0) + 1
        if kind == "answer":
            self.state.ledger["answers"].append({"p": person, "t": now})
        self.state.save()
        self.state.write_log(event="posted", kind=kind, source=source, rid=rid, n=m.get("n"))
        return {"posted": True, "n": m.get("n"), "rid": rid}

    def put_doc(self, slug: str, title: str, body: str) -> dict:
        """The project doc (e.g. oliver-ben-updates): same kill switch and privacy gate as a room post."""
        why = self.state.killed()
        if why:
            return {"ok": False, "reason": why}
        bad = privacy_check(body, guard_ban_strings(self.rules_file))
        if bad:
            self.state.write_log(event="refused", kind="doc", source=slug, reason="privacy", hits=bad)
            return {"ok": False, "reason": "privacy", "hits": bad}
        try:
            return self.room.put_doc(slug, title, body)
        except TransportStop as e:
            return {"ok": False, "reason": "stop: %s" % e}

    # ------------------------------------------------------------ answering (R2, R3, R8-R11, R13)
    def is_self(self, m: dict) -> bool:
        if "self" in NEGCTRL:
            return False
        return m.get("via") == VIA or str(m.get("by", "")).lower() in ("sf-1", "sf1") or \
            str(m.get("body", "")).startswith(LABEL)

    @staticmethod
    def mentions(body: str) -> bool:
        live = "\n".join(l for l in body.splitlines() if not l.lstrip().startswith(">"))
        return bool(MENTION_RE.search(live))

    def poll(self, decider: Callable, sf1: Callable, context_for: Callable) -> list[dict]:
        why = self.state.killed()
        if why:
            self.state.write_log(event="poll-refused", reason=why)
            return []
        try:
            msgs = self.room.get_messages(since=int(self.state.ledger["cursor"]))
        except TransportStop:
            return []
        out = []
        for m in msgs:
            self.state.ledger["cursor"] = max(int(self.state.ledger["cursor"]), int(m["n"]))
            key = str(m["n"])
            person = str(m.get("by", "")).split()[0].lower() if m.get("by") else ""
            if self.is_self(m) or not self.mentions(m.get("body", "")):
                continue
            if person not in MEMBERS:
                self.state.write_log(event="skip", n=m["n"], reason="not a member")
                continue
            if float(m.get("ts", 0)) < float(self.state.ledger["started_at"]):
                self.state.write_log(event="skip", n=m["n"], reason="backlog")
                continue
            if "ledger" not in NEGCTRL and key in self.state.ledger["answered"]:
                continue
            out.append(self.answer(m, person, decider, sf1, context_for))
            self.state.ledger["answered"][key] = time.time()
            self.state.save()
        self.state.save()
        return out

    def answer(self, m: dict, person: str, decider: Callable, sf1: Callable, context_for: Callable) -> dict:
        q = MENTION_RE.sub("", m["body"]).strip()
        rm = re.search(r"\brepo:([\w.-]+)", q)
        repo = rm.group(1) if rm else ""
        custom = q.lstrip().startswith("/")
        ctx = context_for(repo)
        prompt = "Room question from %s%s:\n%s\n\nRules and decisions in scope:\n%s" % (
            person, " (repo %s)" % repo if repo else "", q, ctx)
        ihash = hashlib.sha256(prompt.encode()).hexdigest()[:16]
        arms = {}
        for name, fn in (("cc", decider), ("sf1", sf1)):
            t0 = time.time()
            try:
                ans = fn(prompt)
                arms[name] = {"text": ans, "ok": bool(ans), "ms": int((time.time() - t0) * 1000)}
            except Exception as e:
                arms[name] = {"text": "", "ok": False, "ms": int((time.time() - t0) * 1000), "err": type(e).__name__}
        if arms["cc"]["ok"]:
            text = "Claude Code (deciding): %s" % arms["cc"]["text"]
            if arms["sf1"]["ok"]:
                same = arms["sf1"]["text"].strip() == arms["cc"]["text"].strip()
                text += "\n\nSF-1 (alongside, not deciding%s): %s" % (", agrees" if same else ", differs",
                                                                       arms["sf1"]["text"])
            decider_used = "cc"
        elif arms["sf1"]["ok"]:
            text = ("ADVISORY, not a decision: Claude Code did not answer, so decisions are held until Claude Code "
                    "answers.\nSF-1: %s" % arms["sf1"]["text"])
            decider_used = "none (advisory)"
        else:
            text = "Neither Claude Code nor SF-1 answered. Nothing is decided."
            decider_used = "none"
        res = self.post("re #%s (@%s): %s" % (m["n"], person, text), "answer", "msg:%s" % m["n"], person=person)
        if not res["posted"] and res.get("reason") == "privacy":
            res = self.post("re #%s: answer withheld by the privacy filter; ask again in your own Claude Code."
                            % m["n"], "answer", "msg:%s:withheld" % m["n"], person=person)
        row = {"turn": m["n"], "person": person, "surface": "room", "repo": repo, "custom_command": custom,
               "input_hash": ihash, "cc": arms["cc"], "sf1": arms["sf1"], "decider": decider_used,
               "posted": res.get("posted"), "ts": time.time()}
        with self.state.pairs.open("a") as f:
            f.write(json.dumps(row) + "\n")
        return row


# ---------------------------------------------------------------- per-repo context (R10)
def make_context(rules: list[dict]) -> Callable[[str], str]:
    """rules: [{hash, text, repo?}]. A turn for repo X sees repo X rules plus unscoped ones, never another repo's."""
    def ctx(repo: str) -> str:
        keep = [r for r in rules if "scope" in NEGCTRL or not r.get("repo") or r.get("repo") == repo]
        return "\n".join("- %s [KO %s]" % (r["text"], r["hash"][:8]) for r in keep)
    return ctx


# ---------------------------------------------------------------- live backends (off by default)
def claude_code_backend(cwd: str, max_usd: float = 0.5, timeout: int = 180) -> Callable[[str], str]:
    """Headless Claude Code, read-only tools, as the decider (CC-READ). Billing per Q1 is the caller's env."""
    def run(prompt: str) -> str:
        p = subprocess.run(["claude", "-p", prompt, "--output-format", "json", "--allowedTools", "Read,Grep,Glob",
                            "--max-budget-usd", str(max_usd)], cwd=cwd, capture_output=True, text=True,
                           timeout=timeout)
        if p.returncode != 0:
            raise RuntimeError("claude rc=%s" % p.returncode)
        return json.loads(p.stdout).get("result", "").strip()
    return run


def command_backend(cmd: list[str], timeout: int = 180) -> Callable[[str], str]:
    """SF-1's answer: any command that reads the prompt on stdin and prints the answer."""
    def run(prompt: str) -> str:
        p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, timeout=timeout)
        if p.returncode != 0:
            raise RuntimeError("sf1 rc=%s" % p.returncode)
        return p.stdout.strip()
    return run


def unavailable(_prompt: str) -> str:
    raise RuntimeError("backend not configured")


# ---------------------------------------------------------------- CLI
def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="SF-1 room member (oliver-ben). Mock by default.")
    ap.add_argument("cmd", choices=["post", "poll", "stop", "unstop", "status"])
    ap.add_argument("--state", default=os.path.expanduser("~/.sf1/room-member"))
    ap.add_argument("--mock", default=None, help="mock room JSON (default <state>/mock-room.json)")
    ap.add_argument("--hosted", default=None, help="base URL of the app; OFF unless given")
    ap.add_argument("--key-file", default=None)
    ap.add_argument("--room", default=DEFAULT_ROOM)
    ap.add_argument("--text", default="")
    ap.add_argument("--kind", default="ruling", choices=["ruling", "digest"])
    ap.add_argument("--source", default="cli")
    ap.add_argument("--cc-cwd", default=None, help="enable the live Claude Code decider in this checkout")
    ap.add_argument("--sf1-cmd", default=None, help="enable a live SF-1 answer command (stdin -> stdout)")
    a = ap.parse_args(argv)
    st = State(Path(a.state))
    if a.cmd == "stop":
        st.set_stop("human stop"); print("stopped"); return 0
    if a.cmd == "unstop":
        st.unstop(); print("unstopped"); return 0
    if a.cmd == "status":
        print(json.dumps({"killed": st.killed(), "cursor": st.ledger["cursor"], "posts": len(st.ledger["posts"]),
                          "answered": len(st.ledger["answered"])})); return 0
    room = HostedRoom(a.hosted, a.room, Path(a.key_file), st) if a.hosted else \
        MockRoom(Path(a.mock or Path(a.state) / "mock-room.json"), a.room)
    mem = Member(room, st)
    if a.cmd == "post":
        print(json.dumps(mem.post(a.text, a.kind, a.source, date=time.strftime("%Y-%m-%d"))))
        return 0
    dec = claude_code_backend(a.cc_cwd) if a.cc_cwd else unavailable
    sf1 = command_backend(a.sf1_cmd.split()) if a.sf1_cmd else unavailable
    print(json.dumps(mem.poll(dec, sf1, make_context([])), default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())

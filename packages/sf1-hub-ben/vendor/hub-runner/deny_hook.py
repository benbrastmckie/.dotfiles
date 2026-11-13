#!/usr/bin/env python3
"""Card executor deny hook (RB5): irreversible actions inside a hub card are refused and handed to Oliver.

Claude Code PreToolUse hook, loaded only through ~/.sf1/hub/executor-profile.json (never Oliver's own settings).
JSON on stdin; exit 2 = block (stderr goes back to the model), exit 0 = no opinion (the guard hook and Oliver's own
permissions still apply). Each denial is appended to $SF1_HUB_CARD_DIR/denied.jsonl so the runner can post
"waiting for Oliver" in the room. Stdlib only, no network, no model calls.

Denied: git push (any form), gh, vercel / deploy scripts / flyctl deploy, package publishes, docker push, Wayback,
sends (Slack, Notion, Resend, SendGrid, SMTP, mail/sendmail, Linear, Google APIs), osascript, and MCP tools whose
name says send / post / publish / deploy / slack / notion / gmail.
"""
import json
import os
import re
import sys
import time

BASH_RULES = [
    ("git push", re.compile(r"(^|[;&|(`$]\s*|\s)git\b[^;&|\n]*\bpush\b")),
    ("gh", re.compile(r"(^|[;&|(`$]\s*|\s|/)gh\s")),
    ("deploy", re.compile(r"\b(vercel|netlify|flyctl\s+deploy|fly\s+deploy|deploy[\w.-]*\.sh|release\.sh|"
                          r"wrangler\s+(deploy|publish)|firebase\s+deploy|heroku)\b")),
    ("publish", re.compile(r"\b(twine\s+upload|npm\s+publish|pnpm\s+publish|yarn\s+publish|cargo\s+publish|"
                           r"docker\s+push|gem\s+push|poetry\s+publish|uv\s+publish)\b")),
    ("archive", re.compile(r"(web\.archive\.org|archive\.org/save)")),
    ("send", re.compile(r"(hooks\.slack\.com|slack\.com/api|api\.notion\.com|api\.resend\.com|api\.sendgrid\.com|"
                        r"api\.linear\.app|googleapis\.com/(gmail|calendar|drive)|smtp\.|\bsendmail\b|\bmailx?\s|"
                        r"\bmsmtp\b|\bswaks\b)")),
    ("osascript", re.compile(r"\bosascript\b")),
]
MCP_RX = re.compile(r"(send|post|publish|deploy|slack|notion|gmail|email|share|reply|comment|create_pr|merge)", re.I)


def verdict(payload):
    """-> (kind, detail) when denied, else None."""
    if os.environ.get("SF1_HUB_DENY_OFF") == "1" and os.environ.get("SF1_HUB_TEST") == "1":
        return None                                   # negative control only, honoured only under the test flag
    tool = str(payload.get("tool_name") or "")
    ti = payload.get("tool_input") or {}
    if tool == "Bash":
        cmd = str(ti.get("command") or "")
        for kind, rx in BASH_RULES:
            if rx.search(cmd):
                return kind, cmd[:300]
    if tool.startswith("mcp__") and MCP_RX.search(tool):
        return "mcp-send", tool
    if tool in ("WebFetch",) and re.search(r"(slack|notion|resend|sendgrid)", json.dumps(ti), re.I):
        return "send", tool
    return None


def main():
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except Exception:
        sys.stderr.write("[SF-1 hub card] hook input unreadable: blocked (fail closed)\n")
        return 2
    v = verdict(payload)
    if not v:
        return 0
    kind, detail = v
    d = os.environ.get("SF1_HUB_CARD_DIR")
    if d:
        try:
            with open(os.path.join(d, "denied.jsonl"), "a") as f:
                f.write(json.dumps({"ts": time.time(), "kind": kind, "tool": payload.get("tool_name"),
                                    "detail": detail}) + "\n")
        except Exception:
            pass
    sys.stderr.write("[SF-1 hub card] %s is an irreversible action: denied inside a card. It is posted to the room as "
                     "waiting for Oliver; do not retry it another way.\n" % kind)
    return 2


if __name__ == "__main__":
    sys.exit(main())

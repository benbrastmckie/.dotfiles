---
description: Fetch a Zulip thread via API and write formatted JSON to a file
allowed-tools: Skill
argument-hint: <zulip-url> [output-path]
---

# /zulip Command

Fetches all messages from a Zulip chat thread and writes formatted JSON (sender, date, content) to a file or displays inline. Reads API credentials from `~/.zuliprc`.

## Syntax

```
/zulip <zulip-url> [output-path]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `zulip-url` | Yes | Full Zulip thread URL from the browser address bar |
| `output-path` | No | File path to write JSON output. If omitted, prompts interactively. |

## Examples

```
# Fetch thread and write to file
/zulip https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/Subgroups.2C.20their.20carrier.20set /tmp/thread.json

# Fetch thread (will prompt for output destination)
/zulip https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/some.20topic

# Fetch thread anchored at a specific message
/zulip https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/some.20topic/near/604256516 /tmp/thread.json
```

## Output Format

Formatted JSON array written to the output path:

```json
[
  {
    "sender": "Alice Smith",
    "date": "2026-06-17T14:30:59Z",
    "content": "<p>Message content here...</p>"
  }
]
```

Note: `content` is raw HTML as returned by Zulip. No markdown conversion is performed.

## Credentials

Reads from `~/.zuliprc`:

```ini
[api]
email=your@email.com
key=your_api_key
site=https://yourorg.zulipchat.com
```

## Execution

Invoke the skill with the provided arguments:

```
skill: skill-zulip
args: $ARGUMENTS
```

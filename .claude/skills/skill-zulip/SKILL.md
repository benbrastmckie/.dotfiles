---
name: skill-zulip
description: Fetch a Zulip thread via API and write formatted JSON to a file. Invoke for /zulip command.
allowed-tools: Bash, AskUserQuestion
---

# Zulip Fetch Skill (Direct Execution)

Direct execution skill that fetches all messages from a Zulip chat thread and writes formatted JSON output (sender, date, content) to a target file. Reads credentials from ~/.zuliprc and parses the Zulip URL to extract channel and topic.

## Execution

### Step 1: Parse Arguments

Extract URL and optional output path from the arguments passed to this skill.

Run these bash commands to parse the arguments:

```bash
url=$(echo "$ARGUMENTS" | awk '{print $1}')
output_path=$(echo "$ARGUMENTS" | awk 'NF>=2{print $2}')
```

If `$url` is empty, print usage and stop:

```bash
if [ -z "$url" ]; then
  echo "Error: Usage: /zulip <zulip-url> [output-path]"
  echo "Example: /zulip https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/some.20topic"
  exit 1
fi
```

### Step 2: Validate Prerequisites

Check that the credentials file exists and all required tools are available:

```bash
zuliprc="$HOME/.zuliprc"

if [ ! -f "$zuliprc" ]; then
  echo "Error: ~/.zuliprc not found. Create it with:"
  echo "  [api]"
  echo "  email=your@email.com"
  echo "  key=your_api_key"
  echo "  site=https://yourorg.zulipchat.com"
  exit 1
fi

for tool in curl jq python3; do
  if ! which "$tool" >/dev/null 2>&1; then
    echo "Error: Required tool not found: $tool"
    exit 1
  fi
done
```

### Step 3: Read Credentials

Parse ~/.zuliprc to extract the API email, key, and site URL:

```bash
email=$(grep -oP '(?<=email=)\S+' "$zuliprc")
api_key=$(grep -oP '(?<=key=)\S+' "$zuliprc")
site=$(grep -oP '(?<=site=)\S+' "$zuliprc" | sed 's|/$||')

if [ -z "$email" ] || [ -z "$api_key" ] || [ -z "$site" ]; then
  echo "Error: ~/.zuliprc is missing required fields (email, key, site)"
  exit 1
fi
```

### Step 4: Parse Zulip URL

Extract the base URL, channel/stream segment, topic segment, and optional message anchor from the URL.

Note: Zulip uses `#narrow/channel/` in newer versions and `#narrow/stream/` in older ones — both must be handled.

```bash
base=$(echo "$url" | grep -oP 'https?://[^/#]+')
channel_raw=$(echo "$url" | grep -oP '(?<=#narrow/(?:channel|stream)/)[^/]+')
topic_raw=$(echo "$url" | grep -oP '(?<=/topic/)[^/]+')
near_id=$(echo "$url" | grep -oP '(?<=/near/)[0-9]+' || true)

if [ -z "$base" ] || [ -z "$channel_raw" ]; then
  echo "Error: Could not parse Zulip URL. Expected format:"
  echo "  https://REALM.zulipchat.com/#narrow/channel/ID-stream-name/topic/topic.20text"
  exit 1
fi

if [ -z "$topic_raw" ]; then
  echo "Error: URL does not contain a topic segment. Provide a thread URL (not just a channel URL)."
  exit 1
fi
```

### Step 5: Decode URL Components

Convert the raw URL segments into a usable stream name and topic string.

Zulip uses dot-encoding in URL fragments: `.20` means space, `.2C` means comma, etc. These are different from standard percent-encoding. The conversion is: `.XX` -> `%XX`, then standard URL-decode.

```bash
channel_slug=$(echo "$channel_raw" | sed 's/^[0-9]*-//')
stream_name=$(echo "$channel_slug" | tr '-' ' ')

topic=$(python3 -c "
import re, sys
from urllib.parse import unquote
raw = sys.argv[1]
pct = re.sub(r'\.([0-9A-Fa-f]{2})', lambda m: '%' + m.group(1), raw)
print(unquote(pct))
" "$topic_raw")

echo "Fetching thread: stream='$stream_name', topic='$topic'"
if [ -n "$near_id" ]; then
  echo "Anchor: message ID $near_id"
fi
```

### Step 6: Resolve Output Path

If no output path was provided in the arguments, prompt the user to choose where to send the output.

Use AskUserQuestion to present two choices:
- **Option 1**: Print JSON to the screen (stdout)
- **Option 2**: Write JSON to a file (user provides path)

Ask: "Where should the Zulip thread output go? Enter '1' to display inline, or '2' to write to a file."

If the user chooses option 2 (write to file), ask a follow-up question: "Enter output file path (e.g., /tmp/thread.json or ~/thread.json):"

Set `output_path` to the entered path, or set `use_stdout=true` if option 1 was chosen.

If `output_path` was already provided in the arguments (Step 1), skip this step entirely.

### Step 7: Fetch Messages

Build the narrow parameter, URL-encode it, and call the Zulip REST API.

```bash
narrow=$(python3 -c "
import json, sys
print(json.dumps([
  {'operator': 'stream', 'operand': sys.argv[1]},
  {'operator': 'topic', 'operand': sys.argv[2]}
]))
" "$stream_name" "$topic")

narrow_encoded=$(python3 -c "
from urllib.parse import quote
import sys
print(quote(sys.argv[1]))
" "$narrow")

anchor="${near_id:-newest}"

echo "Calling Zulip API..."
response=$(curl -s --user "$email:$api_key" \
  "${site}/api/v1/messages?anchor=${anchor}&num_before=5000&num_after=0&narrow=${narrow_encoded}")

api_result=$(echo "$response" | jq -r '.result' 2>/dev/null)
if [ "$api_result" != "success" ]; then
  api_msg=$(echo "$response" | jq -r '.msg' 2>/dev/null || echo "Unknown error")
  echo "Error: Zulip API returned error: $api_msg"
  exit 1
fi

msg_count=$(echo "$response" | jq '.messages | length' 2>/dev/null || echo 0)
echo "Fetched $msg_count messages."
```

### Step 8: Format and Write Output

Extract sender, date, and content from the API response and write to the destination.

Format each message as a JSON object with three fields: `sender` (full name), `date` (ISO 8601 date string from Unix timestamp), and `content` (raw HTML).

```bash
formatted=$(echo "$response" | jq '[.messages[] | {
  sender: .sender_full_name,
  date: (.timestamp | todate),
  content: .content
}]')
```

If `use_stdout` is true, or if `output_path` is still empty after Step 6, print `$formatted` directly to stdout.

Otherwise write to file:

```bash
mkdir -p "$(dirname "$output_path")"
echo "$formatted" > "$output_path"
```

### Step 9: Report Result

Print a completion summary. If output was written to a file:

```bash
echo ""
echo "Thread written to: $output_path"
echo "Messages: $msg_count"
echo "Stream: $stream_name"
echo "Topic: $topic"
```

If output was printed to stdout:

```bash
echo ""
echo "---"
echo "Stream: $stream_name | Topic: $topic | Messages: $msg_count"
```

---

## Error Handling

- **~/.zuliprc missing**: Print setup instructions, exit 1
- **Required tool missing** (curl/jq/python3): Print tool name, exit 1
- **URL missing or malformed**: Print usage example, exit 1
- **No topic segment in URL**: Print error explaining a thread URL is needed, exit 1
- **API returns non-success**: Print the API error message, exit 1
- **Empty response**: jq safely returns empty array `[]` — this is valid output
- **Output directory missing**: `mkdir -p $(dirname "$output_path")` before writing

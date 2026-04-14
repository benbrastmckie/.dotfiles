# CSV Investor Tracker Pattern

Reference for updating the CSV investor tracking spreadsheet from meeting file YAML frontmatter. The CSV file lives alongside meeting files in the same directory and provides a flat, sortable overview of all investor relationships.

## CSV Discovery

The CSV tracker is located in the same directory as the meeting files. To find it:

1. Get the directory of the meeting file being processed
2. Look for a `*.csv` file in that directory (typically named `{category}-spreadsheet.csv`, e.g., `VC-spreadsheet.csv`)
3. If no CSV exists, create one with the header row defined below

## Column Schema

22 columns in this exact order:

| # | Column | YAML Field | Type | Format Notes |
|---|--------|-----------|------|-------------|
| 1 | Investor | `investor_name` | string | Direct |
| 2 | Website | `website` | string | URL |
| 3 | Fund Size | `fund_size` | string | Direct (e.g., "$20M target") |
| 4 | Stage | `stage` | array | Join with `", "` |
| 5 | Geography | `geography` | string | Quote if contains commas |
| 6 | Focus | `focus` | string | Direct |
| 7 | Check Min | `check_size_min` | number | Raw integer, no `$` or commas |
| 8 | Check Max | `check_size_max` | number | Raw integer, no `$` or commas |
| 9 | Primary Contact | `primary_contact` | string | Direct |
| 10 | Contact Role | `primary_contact_role` | string | Direct |
| 11 | Pipeline Stage | `pipeline_stage` | string | Direct |
| 12 | Last Touchpoint | `last_touchpoint` | string | YYYY-MM-DD |
| 13 | Next Action | `next_action` | string | Quote if contains commas |
| 14 | Warm Intro | `warm_intro` | boolean | Lowercase: `true` or `false` |
| 15 | Referral Source | `referral_source` | string | Direct (empty string if none) |
| 16 | Fit Score | `fit_score` | number | Integer 1-5 |
| 17 | Likely Role | `likely_role` | string | Direct |
| 18 | Priority Action | `priority_action` | string | Quote if contains commas |
| 19 | Open Actions | `open_actions` | number | Count of open action items |
| 20 | Tags | `tags` | array | Join with `", "` |
| 21 | Meeting Count | *derived* | number | `len(meetings[])` |
| 22 | Last Meeting | *derived* | string | `meetings[-1].date` (YYYY-MM-DD) |

## Derived Columns

These columns are NOT stored in YAML frontmatter. Compute them from the `meetings[]` array:

- **Meeting Count**: Number of entries in the `meetings[]` array
- **Last Meeting**: The `date` field of the last (most recent) entry in `meetings[]`

## Fields NOT in CSV

These frontmatter fields are too detailed for the flat CSV format and exist only in the meeting file:

- `fund_number` -- fund identifier
- `structure` -- fund structure description
- `team[]` -- full team member list with bios
- `strengths[]` -- detailed strength descriptions
- `gaps[]` -- detailed gap descriptions
- `meetings[]` -- full meeting log (attendees, format, outcome, feedback)

## Array Encoding

YAML arrays are encoded as comma-space-separated strings in CSV:

| Direction | Rule | Example |
|-----------|------|---------|
| YAML to CSV | Join with `", "` | `["pre-seed", "seed"]` -> `"pre-seed, seed"` |
| CSV to YAML | Split on `", "` | `"ai-safety, mission-vc"` -> `["ai-safety", "mission-vc"]` |

**Affected columns**: Stage (4), Tags (20)

## CSV Quoting Rules

Standard RFC 4180 CSV quoting:

- Fields containing commas MUST be wrapped in double quotes
- Fields containing double quotes must escape them by doubling (`""`)
- Fields containing newlines must be wrapped in double quotes
- All other fields may be unquoted

**Commonly quoted fields**: Geography, Next Action, Priority Action, Likely Role (these frequently contain commas)

## Update Patterns

### New Meeting File Created

When a new meeting file is created (no existing row for this investor):

1. Parse YAML frontmatter from the meeting file
2. Compute derived columns from `meetings[]` array
3. Append a new row to the CSV with all 22 columns
4. Maintain sort order (see below)

### Existing Meeting File Updated (`--update` mode)

When an existing meeting file is updated (row already exists for this investor):

1. Parse YAML frontmatter from the meeting file
2. Find the existing row by matching column 1 (Investor) to `investor_name`
3. Replace all 22 column values with current frontmatter values
4. Recompute derived columns from updated `meetings[]` array
5. Maintain sort order

### Row Identification

Match rows by `investor_name` (column 1). This is the unique key. If the investor name changed, the old row must be removed and a new row added.

## Sort Order

Rows are sorted by **Last Touchpoint** (column 12) descending -- most recently contacted investors appear first. Re-sort after every insert or update.

## Example Row

Header:
```
Investor,Website,Fund Size,Stage,Geography,Focus,Check Min,Check Max,Primary Contact,Contact Role,Pipeline Stage,Last Touchpoint,Next Action,Warm Intro,Referral Source,Fit Score,Likely Role,Priority Action,Open Actions,Tags,Meeting Count,Last Meeting
```

Data row:
```
Halcyon Ventures,https://halcyonfutures.org/,$20M target,"pre-seed, seed","Santa Monica, CA",AI safety and security,250000,1500000,Ross Matican,Investor,post-meeting,2026-04-07,"Follow up with Ross Matican; clarify introductions offer",false,,4,syndicate participant / ecosystem connector,"Strengthen commercial case with concrete buyer value proposition",8,"ai-safety, mission-vc, pre-seed, ecosystem-connector",1,2026-04-07
```

## Sync Invariants

1. Every meeting file in the directory MUST have a corresponding CSV row
2. CSV row values MUST reflect the current state of the meeting file's frontmatter
3. Derived columns MUST be recomputed on every update (not cached)
4. After any meeting file change, the CSV sort order must be maintained

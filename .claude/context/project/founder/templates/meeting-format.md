# Investor Meeting File Template

Template for structured investor meeting files. Used by the meeting-agent to transform raw meeting notes into comprehensive investor profiles with YAML metadata and formatted analysis.

## Output File Format

**Location**: Same directory as the input notes file
**Naming**: `YYYY-MM-DD_slug.md`

### Slug Derivation Rules

1. Take the investor name (e.g., "Halcyon Ventures")
2. Drop generic suffixes: "Ventures", "Capital", "Partners", "Fund", "Group", "Management", "Advisors", "Holdings"
3. Lowercase the distinctive word(s)
4. Join multi-word names with hyphens (e.g., "Blue Ocean Capital" -> `blue-ocean`)
5. Date component is the date of the initial meeting

**Multiple meetings**: The filename retains the original date. The `meetings[]` array tracks all meetings. Do not create a new file for follow-up meetings with the same investor.

---

## Frontmatter Schema

```yaml
---
investor_name: "{string, required}"               # Official firm name
website: "{string, required}"                      # Firm website URL
fund_size: "{string, required}"                    # Free-form (e.g., "$20M target", "$25M")
fund_number: "{string, required}"                  # Which fund (e.g., "Fund I", "Fund III")
stage:                                             # array of strings, required
  - "{stage}"                                      # Values: "pre-seed", "seed", "series-a", etc.
geography: "{string, required}"                    # Location (e.g., "Santa Monica, CA")
focus: "{string, required}"                        # Investment thesis focus area
portfolio_size: "{string, required}"               # Free-form (e.g., "12+", "20-25 target")
check_size_min: {number, required}                 # Minimum check in USD (no $ sign)
check_size_max: {number, required}                 # Maximum check in USD (no $ sign)
structure: "{string, required}"                    # Fund structure (e.g., "Operator-first VC fund")
primary_contact: "{string, required}"              # Name of main contact person
primary_contact_role: "{string, required}"         # Role/title of primary contact
team:                                              # array of objects, required
  - name: "{string}"
    role: "{string}"
pipeline_stage: "{string, required}"               # See Pipeline Stage Values below
last_touchpoint: "{YYYY-MM-DD, required}"          # Date of last interaction
next_action: "{string, required}"                  # Next step to take
warm_intro: {boolean, required}                    # Whether there was a warm introduction
referral_source: "{string, required}"              # Who referred (empty string if none)
fit_score: {number, required}                      # 1-5 integer, see Fit Score Scale below
likely_role: "{string, required}"                  # Expected role in a round
strengths:                                         # array of strings, required
  - "{strength description}"
gaps:                                              # array of strings, required
  - "{gap description}"
meetings:                                          # array of objects, required
  - date: "{YYYY-MM-DD}"
    type: "{string}"                               # Values: "initial", "follow-up", "deep-dive", "partner-meeting"
    format: "{string}"                             # How meeting was conducted (e.g., "Slide-by-slide pitch deck review", "Video call")
    attendees_ours:
      - "{name}"
    attendees_theirs:
      - "{name}"                                   # Empty array [] if unknown
    outcome: "{string}"                            # Brief outcome summary
    core_feedback: "{string}"                      # One-line core feedback
open_actions: {number, required}                   # Count of open action items
priority_action: "{string, required}"              # Single highest-priority action
tags:                                              # array of strings, required
  - "{tag}"                                        # Lowercase, kebab-case categorical tags
---
```

### Pipeline Stage Values

| Value | Description |
|-------|-------------|
| `identified` | Investor identified, no contact yet |
| `outreach` | Initial outreach sent |
| `scheduled` | Meeting scheduled |
| `post-meeting` | Meeting completed, follow-up pending |
| `follow-up` | Active follow-up in progress |
| `active` | Ongoing relationship, multiple touchpoints |
| `passed` | Investor passed on opportunity |
| `committed` | Investor committed to invest |

### Fit Score Scale

| Score | Meaning |
|-------|---------|
| 1 | Poor fit -- fundamental misalignment |
| 2 | Weak fit -- significant gaps |
| 3 | Moderate fit -- some alignment, notable gaps |
| 4 | Strong fit -- good alignment, minor gaps |
| 5 | Excellent fit -- strong alignment across all dimensions |

### Field Source Classification

| Source | Fields |
|--------|--------|
| User-provided (from meeting notes) | `investor_name`, `primary_contact`, `meetings[]` (attendees, raw feedback), `next_action` |
| Web research required | `website`, `fund_size`, `fund_number`, `portfolio_size`, `check_size_min`, `check_size_max`, `structure`, `team[]`, `geography`, `focus` |
| Agent-computed (from analysis) | `fit_score`, `likely_role`, `strengths[]`, `gaps[]`, `open_actions`, `priority_action`, `tags[]` |
| Defaults | `warm_intro` (false), `referral_source` (""), `pipeline_stage` ("post-meeting") |

---

## Body Template

```markdown
# {Investor Name}

> {website URL}

## Investor Profile

| Field | Detail |
|-------|--------|
| Fund | {fund_size} ({fund_number}; additional context from research) |
| Structure | {stage description} |
| Geography | {geography} |
| Focus | {focus} |
| Portfolio size | {portfolio_size} |
| Check size | ${check_size_min formatted}-${check_size_max formatted} (note data confidence) |

{Optional **Note** block if data sources have caveats}

{Optional **Parent organization** block if complex fund structure}

**Team**:

- **{Name}** -- {Role}. {1-2 sentence bio from web research}.
{Repeat for each team member}

**Advisors**: {List notable advisors if found in research}.

**Thesis**: {2-3 sentence description of investment philosophy extracted from website/interviews}.

{Optional **Investment categories tracked**: bulleted list if investor categorizes their focus areas}

**Portfolio highlights**:

| Company | Focus | Raise | Relevance to {Our Company} |
|---------|-------|-------|---------------------------|
| {Company} | {Focus area} | {Raise amount} | {Why relevant} |

{Optional portfolio analysis paragraphs for particularly relevant companies}

{Optional **Comparable company** paragraph with valuation context}

## Relationship Status

| Field | Detail |
|-------|--------|
| Pipeline stage | {pipeline_stage description} |
| Primary contact | {primary_contact} ({rationale for choosing this contact}) |
| Last touchpoint | {date} -- {description} |
| Next action | {next_action} |

## Investor Fit Assessment

**Strengths**:
- {Strength with supporting evidence}

**Gaps**:
- {Gap with explanation of impact}

**Likely role**: {Prose paragraph explaining expected role in a funding round, with reasoning}.

## Meeting Log

### {YYYY-MM-DD} -- {Meeting Type}

**Attendees**: {Our attendees} ({Our Company}), {Their attendees} ({Investor Name})

**Format**: {How the meeting was conducted}

**Outcome**: {Summary of what happened and overall tone}

### Feedback by Theme

#### {Theme Name}

{Context paragraph explaining the theme}

- {Quoted or paraphrased feedback point}
- {Another feedback point}

{Repeat for each feedback theme}

{Optional **Feedback Comparison** table if multiple investors have been met}

## Action Items

| # | Action | Owner | Status | Source | Notes |
|---|--------|-------|--------|--------|-------|
| 1 | {Action description} | {Owner} | {NOT DONE/DONE/PARTIAL/UNKNOWN} | {Source} | {Notes} |

## Strategic Notes

**{Topic}**: {Analysis paragraph explaining strategic implications of meeting/feedback}.

{Repeat for each strategic insight}

{Optional ## Ecosystem Research -- if meeting referenced other entities worth researching}

{Optional ## Corrections -- if meeting identified errors in pitch materials}

---

## Raw Notes

The following sections preserve the complete original content of this document before refactoring.

### Source: Original File Content

{Complete original meeting notes as provided by the user, preserving all formatting}
```

---

## Section Guidance

| Section | Source | Notes |
|---------|--------|-------|
| Investor Profile | Web research + notes | Fund details, team bios, thesis require web research. Portfolio highlights require searching for portfolio companies. |
| Relationship Status | Notes + defaults | Pipeline stage defaults to "post-meeting" for new meetings. Primary contact comes from notes or best judgment. |
| Fit Assessment | Agent analysis | Synthesize strengths/gaps from profile research and meeting feedback. Fit score is agent's assessment. |
| Meeting Log | Notes (structured) | Transform raw notes into themed feedback sections. Quote or closely paraphrase the user's original words. |
| Action Items | Notes + analysis | Extract explicit action items from notes. Add agent-identified actions. All start as NOT DONE unless notes indicate completion. |
| Strategic Notes | Agent analysis | Higher-order analysis of what the meeting means for strategy. Cross-reference with other investors if applicable. |
| Ecosystem Research | Notes + web research | Only include if meeting references specific entities worth researching. |
| Corrections | Notes | Only include if meeting identified errors in existing materials. |
| Raw Notes | User input (verbatim) | Always include. Preserve the exact original content for reference. |

## Pre-Delivery Checklist

- [ ] All 27 frontmatter fields populated (no missing required fields)
- [ ] `meetings[]` array includes entry for this meeting with all 7 sub-fields
- [ ] `open_actions` count matches the number of NOT DONE action items
- [ ] `priority_action` matches the most important action item
- [ ] `last_touchpoint` matches the meeting date
- [ ] `tags[]` includes relevant categorical tags (lowercase, kebab-case)
- [ ] Team bios sourced from web research, not fabricated
- [ ] Portfolio highlights sourced from web research, not fabricated
- [ ] Raw Notes section preserves the complete original input
- [ ] File named correctly: `YYYY-MM-DD_slug.md`
